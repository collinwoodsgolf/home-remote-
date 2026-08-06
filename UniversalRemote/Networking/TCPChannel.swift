import Foundation
import Network

/// Async TCP socket with exact-length reads, which the ADB framing requires.
///
/// Like `UDPChannel`, timeouts are implemented with a single continuation plus
/// a timer instead of a task group — NWConnection's callbacks have no
/// cancellation hook, so racing them inside a task group leaves a child task
/// suspended forever and deadlocks the caller.
final class TCPChannel {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "tcp.channel")
    private var buffer = Data()

    init(host: String, port: UInt16) {
        connection = NWConnection(host: NWEndpoint.Host(host),
                                  port: NWEndpoint.Port(rawValue: port)!,
                                  using: .tcp)
    }

    func start(timeout: TimeInterval = 6) async throws {
        let guardBox = ResumeGuardTCP()
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let timer = DispatchWorkItem {
                if guardBox.claim() { cont.resume(throwing: RemoteError.timeout) }
            }
            queue.asyncAfter(deadline: .now() + timeout, execute: timer)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if guardBox.claim() { timer.cancel(); cont.resume() }
                case .failed(let error), .waiting(let error):
                    if guardBox.claim() { timer.cancel(); cont.resume(throwing: error) }
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    func send(_ data: Data) async throws {
        let guardBox = ResumeGuardTCP()
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                guard guardBox.claim() else { return }
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            })
        }
    }

    /// Read exactly `count` bytes, buffering any surplus for the next read.
    func readExactly(_ count: Int, timeout: TimeInterval = 6) async throws -> Data {
        while buffer.count < count {
            let chunk = try await receiveChunk(max: count - buffer.count, timeout: timeout)
            buffer.append(chunk)
        }
        let result = buffer.prefix(count)
        buffer.removeFirst(count)
        return Data(result)
    }

    private func receiveChunk(max: Int, timeout: TimeInterval) async throws -> Data {
        let guardBox = ResumeGuardTCP()
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            let timer = DispatchWorkItem {
                if guardBox.claim() { cont.resume(throwing: RemoteError.timeout) }
            }
            queue.asyncAfter(deadline: .now() + timeout, execute: timer)

            connection.receive(minimumIncompleteLength: 1, maximumLength: max) {
                content, _, isComplete, error in
                guard guardBox.claim() else { return }
                timer.cancel()
                if let error { cont.resume(throwing: error) }
                else if let content, !content.isEmpty { cont.resume(returning: content) }
                else if isComplete { cont.resume(throwing: RemoteError.noResponse) }
                else { cont.resume(throwing: RemoteError.noResponse) }
            }
        }
    }

    func cancel() { connection.cancel() }
}

/// Single-resume guard for the TCP continuations.
private final class ResumeGuardTCP: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
