import Foundation
import Network

/// Discovers Broadlink hubs on the local network with a UDP broadcast.
enum BroadlinkDiscovery {

    /// Broadcast a hello packet and gather every hub that answers within
    /// `window` seconds.
    static func scan(window: TimeInterval = 4) async -> [BroadlinkHubInfo] {
        guard let localIP = LocalNetwork.primaryIPv4Address() else { return [] }
        let packet = makeDiscoveryPacket(localIP: localIP, port: 0)

        let channel = UDPChannel.broadcast(port: 80)
        do {
            try await channel.start()
            try await channel.send(Data(packet))
        } catch {
            channel.cancel()
            return []
        }
        defer { channel.cancel() }

        let responses = await channel.receiveAll(window: window)
        var hubs: [String: BroadlinkHubInfo] = [:]
        for data in responses {
            if let hub = parseResponse([UInt8](data)) {
                hubs[hub.id] = hub
            }
        }
        return Array(hubs.values)
    }

    /// Unicast probe of a known IP. Sends the same hello packet directly to the
    /// host (no broadcast, so it works without the multicast entitlement) and
    /// fills in the host from the address we used.
    static func probe(host: String, timeout: TimeInterval = 3) async -> BroadlinkHubInfo? {
        let localIP = LocalNetwork.primaryIPv4Address() ?? "0.0.0.0"
        let packet = makeDiscoveryPacket(localIP: localIP, port: 0)
        let channel = UDPChannel(host: host, port: 80)
        do {
            try await channel.start(timeout: timeout)
            try await channel.send(Data(packet))
            let data = try await channel.receive(timeout: timeout)
            channel.cancel()
            guard var hub = parseResponse([UInt8](data)) else { return nil }
            hub.host = host   // trust the address we successfully reached
            return hub
        } catch {
            channel.cancel()
            return nil
        }
    }

    /// Sweep the local /24 with unicast probes — no multicast entitlement
    /// needed. Finds hubs even after the router hands them a new address.
    static func scanSubnet(concurrency: Int = 32, timeout: TimeInterval = 0.8) async -> [BroadlinkHubInfo] {
        guard let localIP = LocalNetwork.primaryIPv4Address() else { return [] }
        let parts = localIP.split(separator: ".")
        guard parts.count == 4 else { return [] }
        let prefix = parts[0...2].joined(separator: ".")

        var found: [String: BroadlinkHubInfo] = [:]
        var next = 1
        await withTaskGroup(of: BroadlinkHubInfo?.self) { group in
            func enqueue(_ i: Int) {
                group.addTask { await probe(host: "\(prefix).\(i)", timeout: timeout) }
            }
            while next <= 254 && next <= concurrency { enqueue(next); next += 1 }
            for await result in group {
                if let hub = result { found[hub.id] = hub }
                if next <= 254 { enqueue(next); next += 1 }
            }
        }
        return Array(found.values)
    }

    static func makeDiscoveryPacket(localIP: String, port: UInt16) -> [UInt8] {
        var packet = [UInt8](repeating: 0, count: 0x30)

        // Local time / timezone fields. Devices answer regardless of these, but
        // we populate them the way the reference protocol does.
        let now = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .weekday], from: Date())
        let year = now.year ?? 2024
        packet[0x0c] = UInt8(year & 0xff)
        packet[0x0d] = UInt8((year >> 8) & 0xff)
        packet[0x0e] = UInt8(now.minute ?? 0)
        packet[0x0f] = UInt8(now.hour ?? 0)
        packet[0x10] = UInt8(year % 100)
        packet[0x11] = UInt8(((now.weekday ?? 1) + 5) % 7 + 1) // Mon=1..Sun=7
        packet[0x12] = UInt8(now.day ?? 1)
        packet[0x13] = UInt8(now.month ?? 1)

        // Local IP (in order) and listening port so the hub can reply.
        let octets = localIP.split(separator: ".").compactMap { UInt8($0) }
        if octets.count == 4 {
            packet[0x18] = octets[0]
            packet[0x19] = octets[1]
            packet[0x1a] = octets[2]
            packet[0x1b] = octets[3]
        }
        packet[0x1c] = UInt8(port & 0xff)
        packet[0x1d] = UInt8(port >> 8)
        packet[0x26] = 6

        var checksum: UInt32 = 0xbeaf
        for b in packet { checksum = (checksum + UInt32(b)) & 0xffff }
        packet[0x20] = UInt8(checksum & 0xff)
        packet[0x21] = UInt8((checksum >> 8) & 0xff)
        return packet
    }

    static func parseResponse(_ resp: [UInt8]) -> BroadlinkHubInfo? {
        guard resp.count >= 0x40 else { return nil }
        let deviceType = Int(resp[0x34]) | (Int(resp[0x35]) << 8)
        let mac = Array(resp[0x3a..<0x40])
        let macString = mac.reversed().map { String(format: "%02x", $0) }.joined(separator: ":")

        // The hub's IP comes from the UDP source; if not available we fall back
        // to the device-reported address region. Discovery here records the
        // sender via the name field; host is filled by caller-side resolution.
        // Name (UTF-8, null-terminated) starts at 0x40 in many firmwares.
        var name = ""
        if resp.count > 0x40 {
            let nameBytes = Array(resp[0x40...]).prefix { $0 != 0 }
            name = String(decoding: nameBytes, as: UTF8.self)
        }
        if name.isEmpty { name = "Broadlink Hub" }

        // Source IP is embedded at 0x36..0x39 in the reply on RM4 firmwares.
        let host = "\(resp[0x36]).\(resp[0x37]).\(resp[0x38]).\(resp[0x39])"

        return BroadlinkHubInfo(id: macString, host: host, name: name,
                                deviceType: deviceType, mac: mac)
    }
}

/// Resolves the device's own LAN IPv4 address (needed so discovered hubs know
/// where to send their reply).
enum LocalNetwork {
    static func primaryIPv4Address() -> String? {
        var address: String?
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            let interface = current.pointee
            let family = interface.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                // Prefer WiFi (en0) on iOS.
                if name == "en0" {
                    var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr,
                                socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostBuffer, socklen_t(hostBuffer.count),
                                nil, 0, NI_NUMERICHOST)
                    address = String(cString: hostBuffer)
                }
            }
            ptr = interface.ifa_next
        }
        return address
    }
}
