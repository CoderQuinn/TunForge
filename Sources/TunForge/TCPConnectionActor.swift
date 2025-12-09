import Foundation
import Network

/// minimal actor that manages a NWConnection to local redirect target
public actor TCPConnectionActor {
    private var nwConn: NWConnection?
    private let queue = DispatchQueue(label: "TunForge.TCPConnection")
    private let dstHost: String
    private let dstPort: UInt16
    private let srcIP: String
    private let srcPort: UInt16

    public init(srcIP: String, srcPort: UInt16, dstIP: String, dstPort: UInt16) {
        self.srcIP = srcIP
        self.srcPort = srcPort
        dstHost = dstIP
        self.dstPort = dstPort
    }

    public func start() {
        if nwConn != nil { return }
        let host = NWEndpoint.Host(dstHost)
        guard let port = NWEndpoint.Port(rawValue: dstPort) else {
            return
        }

        nwConn = NWConnection(host: host, port: port, using: .tcp)
        nwConn?.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                TunForgeLogger.info("NWConnection ready to \(self.dstHost):\(self.dstPort)")
            case let .failed(err):
                TunForgeLogger.error("NWConnection failed: \(err)")
            default:
                break
            }
        }
        nwConn?.start(queue: queue)
        // start receive to keep connection alive and maybe read responses in future
        Task {
            self.receiveLoop()
        }
    }

    private func receiveLoop() {
        nwConn?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                TunForgeLogger.debug("Received from local server: \(data.count) bytes")
            }
            if isComplete || error != nil { /* handle close */ }
            // continue receiving
            Task { [weak self] in
                await self?.receiveLoop()
            }
        }
    }

    public func send(payload: Data) {
        guard let conn = nwConn else {
            TunForgeLogger.error("Connection not started, starting now")
            start()
            return
        }
        conn.send(content: payload, completion: .contentProcessed { err in
            if let e = err {
                TunForgeLogger.error("send error: \(e)")
            } else {
                TunForgeLogger.debug("sent \(payload.count) bytes")
            }
        })
    }

    public func stop() {
        nwConn?.cancel()
        nwConn = nil
    }
}
