import Foundation
import Network

/// A discovered Broadlink IR/RF bridge (RM4 Mini, RM Pro, etc.). `id` is the
/// MAC string and is what `Device.hubID` references.
struct BroadlinkHubInfo: Codable, Identifiable, Hashable {
    var id: String          // MAC as "aa:bb:cc:dd:ee:ff"
    var host: String        // LAN IP
    var name: String
    var deviceType: Int     // reported devtype, decides protocol generation
    var mac: [UInt8]        // raw, in response order (resp[0x3a:0x40])

    /// RM4-generation hardware uses a 2-byte length preamble in the command
    /// payload; the original RM mini / RM Pro do not.
    var usesV4Framing: Bool {
        BroadlinkHub.v4DeviceTypes.contains(deviceType) || deviceType >= 0x5000
    }
}

/// Speaks the Broadlink UDP protocol: discovery, the AES auth handshake, IR
/// transmission, and IR learning. All IR remotes in the app (projector, AC,
/// fan, speaker) are driven through one of these.
actor BroadlinkHub {
    let info: BroadlinkHubInfo

    // Encryption state. Starts at the well-known default key; replaced by the
    // session key returned from auth().
    private var key: [UInt8] = BroadlinkHub.defaultKey
    private let iv: [UInt8] = BroadlinkHub.defaultIV
    private var deviceID: [UInt8] = [0, 0, 0, 0]
    private var count: UInt16 = UInt16.random(in: 0..<0x7fff)
    private var authenticated = false

    init(info: BroadlinkHubInfo) {
        self.info = info
    }

    // MARK: - Public API

    /// Authenticate only if we don't already hold a valid session key.
    func authenticateIfNeeded() async throws {
        if authenticated { return }
        try await authenticate()
    }

    func authenticate() async throws {
        // The auth command is always encrypted with the factory-default key, so
        // reset state in case this hub was authenticated earlier in the session.
        key = BroadlinkHub.defaultKey
        deviceID = [0, 0, 0, 0]

        var payload = [UInt8](repeating: 0, count: 0x50)
        for i in 0x04...0x12 { payload[i] = 0x31 }   // 15 bytes of "1"
        payload[0x1e] = 0x01
        payload[0x2d] = 0x01
        let name: [UInt8] = Array("Test 1".utf8)
        for (i, b) in name.enumerated() { payload[0x30 + i] = b }

        let response = try await sendPacket(command: 0x65, payload: payload)
        guard response.count > 0x38 else { throw RemoteError.noResponse }
        let enc = Array(response[0x38...])
        guard let decrypted = AESCBC.decrypt(enc, key: BroadlinkHub.defaultKey, iv: iv) else {
            throw RemoteError.cryptoFailure
        }
        deviceID = Array(decrypted[0x00..<0x04])
        key = Array(decrypted[0x04..<0x14])
        authenticated = true
    }

    /// Transmit a previously learned IR code (raw Broadlink IR blob).
    func sendIR(_ data: [UInt8]) async throws {
        try ensureAuthenticated()
        _ = try await sendCommand(0x02, data: data)
    }

    /// Put the hub into IR-learning mode (point your physical remote at it).
    func enterLearning() async throws {
        try ensureAuthenticated()
        _ = try await sendCommand(0x03)
    }

    /// Read back the IR code captured since `enterLearning()`. Throws
    /// `.notLearned` until the hub has actually received a burst.
    func readLearnedCode() async throws -> [UInt8] {
        try ensureAuthenticated()
        let payload = try await sendCommand(0x04)
        guard !payload.isEmpty else { throw RemoteError.notLearned }
        return payload
    }

    // MARK: - Command framing (rmmini vs rm4)

    /// Wraps a sub-command in the RM payload format, sends it as a 0x6a packet,
    /// and returns the decrypted inner payload.
    private func sendCommand(_ command: UInt8, data: [UInt8] = []) async throws -> [UInt8] {
        var payload: [UInt8]
        if info.usesV4Framing {
            let length = UInt16(data.count + 4)
            payload = [UInt8(length & 0xff), UInt8(length >> 8), command, 0, 0, 0]
            payload.append(contentsOf: data)
        } else {
            payload = [command, 0, 0, 0]
            payload.append(contentsOf: data)
        }

        let response = try await sendPacket(command: 0x6a, payload: payload)
        guard response.count > 0x38 else { throw RemoteError.noResponse }
        let enc = Array(response[0x38...])
        guard let decrypted = AESCBC.decrypt(enc, key: key, iv: iv) else {
            throw RemoteError.cryptoFailure
        }
        if info.usesV4Framing {
            guard decrypted.count >= 2 else { return [] }
            let pLen = Int(decrypted[0]) | (Int(decrypted[1]) << 8)
            let end = min(pLen + 2, decrypted.count)
            guard end > 0x06 else { return [] }
            return Array(decrypted[0x06..<end])
        } else {
            guard decrypted.count > 0x04 else { return [] }
            return Array(decrypted[0x04...])
        }
    }

    // MARK: - Low-level packet exchange

    private func sendPacket(command: UInt8, payload: [UInt8]) async throws -> [UInt8] {
        count = (count &+ 1) | 0x8000

        var header = [UInt8](repeating: 0, count: 0x38)
        let magic: [UInt8] = [0x5a, 0xa5, 0xaa, 0x55, 0x5a, 0xa5, 0xaa, 0x55]
        for (i, b) in magic.enumerated() { header[i] = b }

        header[0x24] = UInt8(info.deviceType & 0xff)
        header[0x25] = UInt8((info.deviceType >> 8) & 0xff)
        header[0x26] = command
        header[0x28] = UInt8(count & 0xff)
        header[0x29] = UInt8(count >> 8)

        // MAC is stored in response order; the wire wants it reversed.
        let macReversed = Array(info.mac.reversed())
        for i in 0..<6 { header[0x2a + i] = macReversed[i] }
        for i in 0..<4 { header[0x30 + i] = deviceID[i] }

        // Payload checksum
        var pChecksum: UInt32 = 0xbeaf
        for b in payload { pChecksum = (pChecksum + UInt32(b)) & 0xffff }
        header[0x34] = UInt8(pChecksum & 0xff)
        header[0x35] = UInt8((pChecksum >> 8) & 0xff)

        // Pad payload to a 16-byte boundary and encrypt
        var padded = payload
        let padding = (16 - payload.count % 16) % 16
        padded.append(contentsOf: [UInt8](repeating: 0, count: padding))
        guard let encrypted = AESCBC.encrypt(padded, key: key, iv: iv) else {
            throw RemoteError.cryptoFailure
        }

        var packet = header + encrypted

        // Whole-packet checksum
        var checksum: UInt32 = 0xbeaf
        for b in packet { checksum = (checksum + UInt32(b)) & 0xffff }
        packet[0x20] = UInt8(checksum & 0xff)
        packet[0x21] = UInt8((checksum >> 8) & 0xff)

        let channel = UDPChannel(host: info.host, port: 80)
        try await channel.start()
        defer { channel.cancel() }
        try await channel.send(Data(packet))
        let response = [UInt8](try await channel.receive(timeout: 6))

        // Bytes 0x22..0x23 carry an error code (0 == ok).
        if response.count > 0x23 {
            let code = Int(response[0x22]) | (Int(response[0x23]) << 8)
            if code != 0 { throw RemoteError.deviceError(code: code) }
        }
        return response
    }

    private func ensureAuthenticated() throws {
        if !authenticated { throw RemoteError.notAuthenticated }
    }

    // MARK: - Constants

    static let defaultKey: [UInt8] = [
        0x09, 0x76, 0x28, 0x34, 0x3f, 0xe9, 0x9e, 0x23,
        0x76, 0x5c, 0x15, 0x13, 0xac, 0xcf, 0x8b, 0x02
    ]
    static let defaultIV: [UInt8] = [
        0x56, 0x2e, 0x17, 0x99, 0x6d, 0x09, 0x3d, 0x28,
        0xdd, 0xb3, 0xba, 0x69, 0x5a, 0x2e, 0x6f, 0x58
    ]

    /// Known RM4-generation device types that use the v4 framing. Anything
    /// reporting a type >= 0x5000 is also treated as v4 (covers newer SKUs).
    static let v4DeviceTypes: Set<Int> = [
        0x51da, 0x5f36, 0x6026, 0x6184, 0x61a2, 0x649b, 0x653c, 0x520b, 0x520d
    ]
}
