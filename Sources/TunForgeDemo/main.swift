import Foundation
import TunForge

let stack = TSIPStackActor(configuration: .init(redirectHost: "127.0.0.1", redirectPort: 1209))

// local tcp server to receive redirected flows
let localServer = LocalTCPServer(port: 1209)
localServer.start()

Task {
    await stack.start()
}

// fake packet generator
let gen = FakeIPPacketGenerator(srcIP: "10.0.0.2", srcPort: 12345, dstIP: "1.1.1.1", dstPort: 80)

// timer tick
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    Task {
        let pkt = await MainActor.run {
            gen.build(payloadString: "Hello Fake TCP\n")
        }
        await stack.inputPacket(pkt)
    }
}

RunLoop.current.run()
