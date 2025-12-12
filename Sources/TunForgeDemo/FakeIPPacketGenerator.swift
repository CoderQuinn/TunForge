import Foundation
import TunForge

public struct FakeIPPacketGenerator {
    public let srcIP: String
    public let srcPort: UInt16
    public let dstIP: String
    public let dstPort: UInt16

    public init(srcIP: String, srcPort: UInt16,
                dstIP: String, dstPort: UInt16)
    {
        self.srcIP = srcIP
        self.srcPort = srcPort
        self.dstIP = dstIP
        self.dstPort = dstPort
    }

    public func build(payloadString: String) -> MockPacket {
        let d = Data(payloadString.utf8)
        return MockPacket(srcIP: srcIP, srcPort: srcPort, dstIP: dstIP, dstPort: dstPort, payload: d)
    }
}
