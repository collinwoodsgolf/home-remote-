import Foundation

/// Finds Fire TV / Android TV devices on the local network by sweeping the
/// subnet for an open ADB port (5555). Used to re-locate the stick after the
/// router hands it a new address, so a stale IP self-heals like the hub does.
enum ADBDiscovery {
    static func scanSubnet(port: UInt16 = 5555, concurrency: Int = 32,
                           timeout: TimeInterval = 0.7) async -> [String] {
        guard let localIP = LocalNetwork.primaryIPv4Address() else { return [] }
        let parts = localIP.split(separator: ".")
        guard parts.count == 4 else { return [] }
        let prefix = parts[0...2].joined(separator: ".")

        var open: [String] = []
        var next = 1
        await withTaskGroup(of: String?.self) { group in
            func enqueue(_ i: Int) {
                let host = "\(prefix).\(i)"
                group.addTask {
                    let channel = TCPChannel(host: host, port: port)
                    do {
                        try await channel.start(timeout: timeout)
                        channel.cancel()
                        return host
                    } catch {
                        channel.cancel()
                        return nil
                    }
                }
            }
            while next <= 254 && next <= concurrency { enqueue(next); next += 1 }
            for await result in group {
                if let host = result { open.append(host) }
                if next <= 254 { enqueue(next); next += 1 }
            }
        }
        return open
    }
}
