import Foundation
import Network
import TunForge

public final class LocalTCPServer: @unchecked Sendable {
    private let serverQueue = DispatchQueue(label: "LocalTCPServerQueue")
    private var listener: NWListener?
    private let port: UInt16

    public init(port: UInt16) {
        self.port = port
    }

    public func start() {
        do {
            listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            TunForgeLogger.error("Failed to start listener: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] conn in
            conn.start(queue: self?.serverQueue ?? .main)
            // ensure we don't capture `self` strongly in this escaping handler
            self?.serverQueue.async {
                [weak self] in
                self?.handle(conn)
            }
        }

        listener?.start(queue: .main)
        TunForgeLogger.info("Local TCP server listening on 127.0.0.1:\(port)")
    }

    private func handle(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                let s = String(decoding: data, as: UTF8.self)
                TunForgeLogger.info("Server received: \(s.trimmingCharacters(in: .newlines))")
            }
            if isComplete || error != nil {
                conn.cancel()
                return
            }
            // continue receive — call back into self weakly
            self?.handle(conn)
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }
}
