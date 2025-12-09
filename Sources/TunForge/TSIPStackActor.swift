import Foundation

/// Minimal stack actor: 接收 TUNPacket，按 (src,dst) key 建立/复用 TCPConnectionActor
public actor TSIPStackActor {
    public struct Configuration: Sendable {
        public let redirectHost: String
        public let redirectPort: UInt16
        public let maxConnections: Int

        public init(redirectHost: String = "127.0.0.1",
                    redirectPort: UInt16 = 1208,
                    maxConnections: Int = 200)
        {
            self.redirectHost = redirectHost
            self.redirectPort = redirectPort
            self.maxConnections = maxConnections
        }
    }

    private let config: Configuration
    private var connections: [String: TCPConnectionActor] = [:]

    public init(configuration: Configuration = Configuration()) {
        config = configuration
        TunForgeLogger.info("TSIPStackActor init redirect -> \(config.redirectHost):\(config.redirectPort)")
    }

    public func start() async {
        TunForgeLogger.info("TSIPStackActor started")
    }

    /// Entry point: feed from TUN (fake or real)
    public func inputPacket(_ pkt: MockPacket) async {
        // key five tuple
        let key = "\(pkt.srcIP):\(pkt.srcPort)-\(pkt.dstIP):\(pkt.dstPort)"
        if let conn = connections[key] {
            await conn.send(payload: pkt.payload)
            return
        }

        // a new conn
        guard connections.count < config.maxConnections else {
            TunForgeLogger.error("Max connections reached, drop packet")
            return
        }
        let conn = TCPConnectionActor(srcIP: pkt.srcIP,
                                      srcPort: pkt.srcPort,
                                      dstIP: config.redirectHost,
                                      dstPort: config.redirectPort)
        connections[key] = conn
        await conn.start()
        await conn.send(payload: pkt.payload)
    }
}
