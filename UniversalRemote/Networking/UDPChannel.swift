import Foundation
import Network

/// Guards a continuation so it is resumed exactly once, whether the network
/// callback or the timeout fires first.
private final class ResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    /// Returns true exactly once, for whichever caller gets there first.
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}

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

    func start(timeout: TimeInterval = 5) async throws {
        let guardBox = ResumeGuard()
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            // The timer is never cancelled; if it fires after the callback won
            // the race, claim() returns false and it does nothing.
            queue.asyncAfter(deadline: .now() + timeout) {
                if guardBox.claim() { cont.resume(throwing: RemoteError.timeout) }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if guardBox.claim() { cont.resume() }
                case .failed(let error):
                    if guardBox.claim() { cont.resume(throwing: error) }
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    func send(_ data: Data) async throws {
        let guardBox = ResumeGuard()
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                guard guardBox.claim() else { return }
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            })
        }
    }

    /// Receive a single datagram, or throw `.timeout`.
    ///
    /// Implemented with a single continuation plus a timer rather than a task
    /// group: `receiveMessage` has no cancellation hook, so a task-group race
    /// would leave that child task suspended forever and deadlock the caller
    /// (which surfaced as a UI stuck on "Preparing hub…" with no error).
    func receive(timeout: TimeInterval = 5) async throws -> Data {
        let guardBox = ResumeGuard()
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            queue.asyncAfter(deadline: .now() + timeout) {
                if guardBox.claim() { cont.resume(throwing: RemoteError.timeout) }
            }

            connection.receiveMessage { content, _, _, error in
                guard guardBox.claim() else { return }
                if let error {
                    cont.resume(throwing: error)
                } else if let content, !content.isEmpty {
                    cont.resume(returning: content)
                } else {
                    cont.resume(throwing: RemoteError.noResponse)
                }
            }
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
