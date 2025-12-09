import Foundation
import TunForge

public struct FakeIPPacketGenerator {
    public let srcIP: String
    public let srcPort: UInt16
    public let dstIP: String
    public let dstPort: UInt16

    public init(srcIP: String = "10.0.0.2", srcPort: UInt16 = 12345,
                dstIP: String = "1.1.1.1", dstPort: UInt16 = 80)
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
