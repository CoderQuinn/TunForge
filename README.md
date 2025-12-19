# TunForge

Lightweight lwIP-based IP stack for iOS/macOS Network Extensions.

## Installation

```swift
.package(url: "https://github.com/CoderQuinn/TunForge", from: "0.0.4")
```

## Usage

```swift
import TunForge

let config = LWIPStackConfig.config(withQueue: queue, ipv4Settings: ipv4)
let stack = LWIPStack.defaultIPStack(with: config)

stack.outboundHandler = { packet, family in
    // Send packet to network
}

stack.receivedPacket(ipPacketData)
stack.resumeTimer()
```

### Swift Typealiases

```swift
class MyDelegate: NSObject, TSIPStackDelegate {
    func didAcceptTCPSocket(_ socket: TSTCPSocket) {
        socket.delegate = self
    }
}
```

## Requirements

- iOS 13.0+ / macOS 13.0+
- Swift 6.1+

## License

Apache License 2.0
