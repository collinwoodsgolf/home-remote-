import Foundation

/// A small ADB client: enough of the protocol to connect, authenticate with
/// our RSA key, and run shell commands (so we can fire `input keyevent N` at a
/// Fire TV). Not a general-purpose ADB implementation.
actor ADBClient {
    private let host: String
    private let port: UInt16
    private var channel: TCPChannel?
    private var connected = false
    private var localID: UInt32 = 1

    // ADB command codes
    private static let CNXN: UInt32 = 0x4e584e43
    private static let AUTH: UInt32 = 0x48545541
    private static let OPEN: UInt32 = 0x4e45504f
    private static let OKAY: UInt32 = 0x59414b4f
    private static let WRTE: UInt32 = 0x45545257
    private static let CLSE: UInt32 = 0x45534c43

    private static let authToken: UInt32 = 1
    private static let authSignature: UInt32 = 2
    private static let authRSAPublicKey: UInt32 = 3

    init(host: String, port: UInt16 = 5555) {
        self.host = host
        self.port = port
    }

    /// Establish (or reuse) an authenticated ADB session. On first-ever connect
    /// the Fire TV shows an "Allow USB debugging?" prompt that the user must
    /// accept; once accepted our key is remembered.
    func connect() async throws {
        if connected { return }
        let channel = TCPChannel(host: host, port: port)
        try await channel.start()
        self.channel = channel

        // CNXN: announce ourselves as a host.
        let connectPayload = Data("host::features=shell_v2,cmd\0".utf8)
        try await send(command: Self.CNXN, arg0: 0x01000001, arg1: 256 * 1024, payload: connectPayload)

        var triedSignature = false
        while true {
            let (cmd, arg0, _, payload) = try await readMessage()
            switch cmd {
            case Self.CNXN:
                connected = true
                return
            case Self.AUTH where arg0 == Self.authToken:
                if !triedSignature {
                    triedSignature = true
                    let signature = try ADBKey.sign(token: payload)
                    try await send(command: Self.AUTH, arg0: Self.authSignature, arg1: 0, payload: signature)
                } else {
                    // Signature rejected → offer the public key for approval.
                    let pubkey = try ADBKey.androidPublicKey()
                    try await send(command: Self.AUTH, arg0: Self.authRSAPublicKey, arg1: 0, payload: pubkey)
                }
            default:
                continue
            }
        }
    }

    /// Run a shell command, returning its stdout text. If the cached socket
    /// has died (stick went to sleep, network blip, lease renewal), tears the
    /// session down and retries once on a fresh connection so the first press
    /// after a sleep self-heals instead of failing until an app restart.
    @discardableResult
    func shell(_ command: String) async throws -> String {
        do {
            return try await runShell(command)
        } catch {
            disconnect()
            return try await runShell(command)
        }
    }

    private func runShell(_ command: String) async throws -> String {
        if !connected { try await connect() }
        localID &+= 1
        let stream = localID
        let destination = Data("shell:\(command)\0".utf8)
        try await send(command: Self.OPEN, arg0: stream, arg1: 0, payload: destination)

        var output = Data()
        var remoteID: UInt32 = 0
        while true {
            let (cmd, arg0, arg1, payload) = try await readMessage()
            switch cmd {
            case Self.OKAY:
                remoteID = arg0
            case Self.WRTE:
                output.append(payload)
                remoteID = arg0
                // Acknowledge so the device keeps sending / can close.
                try await send(command: Self.OKAY, arg0: stream, arg1: remoteID, payload: Data())
            case Self.CLSE:
                try? await send(command: Self.CLSE, arg0: stream, arg1: arg1, payload: Data())
                return String(decoding: output, as: UTF8.self)
            default:
                break
            }
        }
    }

    func disconnect() {
        channel?.cancel()
        channel = nil
        connected = false
    }

    // MARK: - Wire format

    private func send(command: UInt32, arg0: UInt32, arg1: UInt32, payload: Data) async throws {
        guard let channel else { throw RemoteError.noResponse }
        var message = Data()
        func appendLE(_ value: UInt32) {
            message.append(UInt8(value & 0xff))
            message.append(UInt8((value >> 8) & 0xff))
            message.append(UInt8((value >> 16) & 0xff))
            message.append(UInt8((value >> 24) & 0xff))
        }
        let checksum = payload.reduce(UInt32(0)) { $0 &+ UInt32($1) }
        appendLE(command)
        appendLE(arg0)
        appendLE(arg1)
        appendLE(UInt32(payload.count))
        appendLE(checksum)
        appendLE(command ^ 0xffffffff)
        message.append(payload)
        try await channel.send(message)
    }

    private func readMessage() async throws -> (UInt32, UInt32, UInt32, Data) {
        guard let channel else { throw RemoteError.noResponse }
        let header = try await channel.readExactly(24)
        func readLE(_ offset: Int) -> UInt32 {
            UInt32(header[offset]) |
            (UInt32(header[offset + 1]) << 8) |
            (UInt32(header[offset + 2]) << 16) |
            (UInt32(header[offset + 3]) << 24)
        }
        let command = readLE(0)
        let arg0 = readLE(4)
        let arg1 = readLE(8)
        let length = Int(readLE(12))
        var payload = Data()
        if length > 0 {
            payload = try await channel.readExactly(length)
        }
        return (command, arg0, arg1, payload)
    }
}
