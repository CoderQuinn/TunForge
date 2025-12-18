# TunForge

**Lightweight lwIP-based IP stack for iOS/macOS VPN and Network Extensions.**

A Swift-friendly wrapper around the lightweight IP (lwIP) stack, designed for building VPN clients, packet tunnel providers, and network extensions on Apple platforms.

## Features

- ✅ **Direct ObjC → Swift mapping** - Zero overhead, pure interoperability
- ✅ **TCP connection management** - Full TCP state machine with delegate callbacks
- ✅ **Thread-safe** - Internal serial queue for lwIP processing
- ✅ **Lightweight** - Minimal dependencies (CocoaLumberjack for logging)

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/CoderQuinn/TunForge", from: "0.0.3")
]
```

Or add via Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/CoderQuinn/TunForge`
3. Select version `0.0.3` or later

## Quick Start

### Basic Usage

```swift
import TunForge

// Get the IP stack singleton
let stack = IPStack.defaultIPStack()

// Configure virtual network
stack.configureIPv4(
    withIP: "240.0.0.2", 
    netmask: "255.0.0.0", 
    gateway: "240.0.0.1"
)

// Handle outbound packets
stack.outboundHandler = { packet, family in
    // Send IP packet to real network
    sendToNetwork(packet)
}

// Inject inbound packets
stack.receivedPacket(ipPacketData)

// Start processing
stack.resumeTimer()
```

### TCP Socket Handling

```swift
// Set up delegate
class MyStackDelegate: NSObject, TSIPStackDelegate {
    func didAcceptTCPSocket(_ socket: TCPSocket) {
        print("New TCP connection: \(socket.destinationAddress):\(socket.destinationPort)")
        
        socket.delegate = self
        socket.delegateQueue = .main
    }
}

stack.delegate = MyStackDelegate()
```

## Architecture

```
┌─────────────────────────────────┐
│   Swift Layer (Public API)      │
│   - IPStack (typealias)          │
│   - TCPSocket (typealias)        │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│   ObjC Bridge Layer              │
│   - LWIPStack (singleton)        │
│   - LWTCPSocket (connections)    │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│   lwIP Stack (C)                 │
│   - TCP/IP processing            │
│   - Packet routing               │
│   - Timer management             │
└──────────────────────────────────┘
```

## Requirements

- **iOS**: 13.0+
- **macOS**: 13.0+
- **Swift**: 6.1+
- **Xcode**: 15.0+

## Limitations

- IPv4 only (UDP/IPv6 support planned)
- Single network interface
- No DHCP server

## Roadmap

- [ ] IPv6 support
- [ ] Traffic statistics and connection management

## Contributing

Contributions welcome! Please open an issue or PR.

## License

Apache License2.0. See [LICENSE](LICENSE) for details.

## Credits

Built on top of [lwIP](https://savannah.nongnu.org/projects/lwip/) - A Lightweight TCP/IP stack.
