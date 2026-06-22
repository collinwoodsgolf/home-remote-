import Foundation
import Network

/// Thin async wrapper around an NWConnection UDP socket. One request → one
/// response, which is exactly the Broadlink interaction model.
final class UDPChannel {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "udp.channel")

    init(host: String, port: UInt16) {
        let endpointHost = NWEndpoint.Host(host)
        let endpointPort = NWEndpoint.Port(rawValue: port)!
        connection = NWConnection(host: endpointHost, port: endpointPort, using: .udp)
    }

    /// Allow sending to the broadcast address (used for discovery).
    static func broadcast(port: UInt16) -> UDPChannel {
        UDPChannel(host: "255.255.255.255", port: port)
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    cont.resume()
                    self.connection.stateUpdateHandler = nil
                case .failed(let error):
                    cont.resume(throwing: error)
                    self.connection.stateUpdateHandler = nil
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            })
        }
    }

    /// Receive a single datagram, or throw on timeout.
    func receive(timeout: TimeInterval = 5) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
                    self.connection.receiveMessage { content, _, _, error in
                        if let error { cont.resume(throwing: error) }
                        else if let content { cont.resume(returning: content) }
                        else { cont.resume(throwing: RemoteError.noResponse) }
                    }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw RemoteError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Collect every datagram that arrives within the window (for discovery,
    /// where multiple hubs may answer a single broadcast).
    func receiveAll(window: TimeInterval) async -> [Data] {
        var packets: [Data] = []
        let deadline = Date().addingTimeInterval(window)
        while Date() < deadline {
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 { break }
            if let data = try? await receive(timeout: remaining) {
                packets.append(data)
            } else {
                break
            }
        }
        return packets
    }

    func cancel() {
        connection.cancel()
    }
}

enum RemoteError: LocalizedError {
    case timeout
    case noResponse
    case deviceError(code: Int)
    case notAuthenticated
    case cryptoFailure
    case noHubPaired
    case notLearned
    case invalidConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .timeout:                 return "The device did not respond in time."
        case .noResponse:              return "No response from the device."
        case .deviceError(let code):   return "The hub reported error code \(code)."
        case .notAuthenticated:        return "The hub has not been authenticated yet."
        case .cryptoFailure:           return "Encryption/decryption failed."
        case .noHubPaired:             return "No IR hub is paired. Add a hub in Settings."
        case .notLearned:              return "This button has no learned code yet."
        case .invalidConfiguration(let s): return s
        }
    }
}
