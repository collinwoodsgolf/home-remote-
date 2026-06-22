import Foundation
import Network

/// Async TCP socket with exact-length reads, which the ADB framing requires.
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
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    self.connection.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            cont.resume()
                            self.connection.stateUpdateHandler = nil
                        case .failed(let error), .waiting(let error):
                            cont.resume(throwing: error)
                            self.connection.stateUpdateHandler = nil
                        default: break
                        }
                    }
                    self.connection.start(queue: self.queue)
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw RemoteError.timeout
            }
            try await group.next()
            group.cancelAll()
        }
    }

    func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
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
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
                    self.connection.receive(minimumIncompleteLength: 1, maximumLength: max) {
                        content, _, isComplete, error in
                        if let error { cont.resume(throwing: error) }
                        else if let content, !content.isEmpty { cont.resume(returning: content) }
                        else if isComplete { cont.resume(throwing: RemoteError.noResponse) }
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

    func cancel() { connection.cancel() }
}
