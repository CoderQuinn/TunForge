import Foundation

/// Mock IPv4/TCP packet, only for demo
public struct MockPacket: Sendable {
    public let srcIP: String
    public let srcPort: UInt16
    public let dstIP: String
    public let dstPort: UInt16
    public let payload: Data

    public init(srcIP: String, srcPort: UInt16, dstIP: String, dstPort: UInt16, payload: Data) {
        self.srcIP = srcIP
        self.srcPort = srcPort
        self.dstIP = dstIP
        self.dstPort = dstPort
        self.payload = payload
    }
}
