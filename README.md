# TunForge

**Lightweight lwIP-based IP stack for iOS/macOS VPN and Network Extensions.**

A Swift-friendly Objective‑C API over the lightweight IP (lwIP) stack, designed for Network Extensions on Apple platforms.

## Features

- ✅ **Direct ObjC → Swift mapping** - Zero overhead, pure interoperability
- ✅ **TCP connection management** - Full TCP state machine with delegate callbacks
- ✅ **Thread-safe** - Internal serial queue for lwIP processing
- ✅ **Lightweight** - Zero external dependencies (uses os.log for NE-safe logging)

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/CoderQuinn/TunForge", from: "0.0.4")
]
```

Or add via Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/CoderQuinn/TunForge`
3. Select version `0.0.4` or later

## Quick Start

### Basic Usage (Swift)

```swift
import TunForge

// Build configuration (applied only once at first access)
let queue = DispatchQueue(label: "com.example.lwip")
let ipv4 = IPv4Settings(ipAddress: "240.0.0.2", netmask: "255.0.0.0", gateway: "240.0.0.1")
let config = LWIPStackConfig.config(withQueue: queue, ipv4Settings: ipv4)

// Create or get the singleton (config effective only on first call)
let stack = LWIPStack.defaultIPStack(with: config)

// Handle outbound packets
stack.outboundHandler = { packet, family in
    guard let packet else { return }
    // Send IP packet to the real network interface
    sendToNetwork(packet)
}

// Inject inbound packets from your TUN/source
stack.receivedPacket(ipPacketData)

// Drive lwIP timers (call once to start the periodic timer)
stack.resumeTimer()
```

Notes:
- Configuration is init-only: subsequent calls to `defaultIPStack(with:)` ignore the config if the singleton already exists.
- If you are fine with defaults, you can use `LWIPStack.defaultIPStack()` directly.

### TCP Socket Handling (Swift)

```swift
import TunForge

class MyStackDelegate: NSObject, TSIPStackDelegate {
    func didAcceptTCPSocket(_ socket: LWTCPSocket) {
        print("New TCP connection: \(socket.destinationAddress):\(socket.destinationPort)")
        socket.delegate = self as? TSTCPSocketDelegate
        socket.delegateQueue = .main
    }
}

let queue = DispatchQueue(label: "com.example.lwip")
let cfg = LWIPStackConfig.config(withQueue: queue, ipv4Settings: nil)
let stack = LWIPStack.defaultIPStack(with: cfg)
stack.delegate = MyStackDelegate()
```

## Architecture

```
┌─────────────────────────────────┐
│   Public API (ObjC, Swift-ready)│
│   - LWIPStack (singleton)       │
│   - LWTCPSocket (connections)   │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│   lwIP Stack (C)                │
│   - TCP/IP processing           │
│   - Packet routing              │
│   - Timer management            │
└──────────────────────────────────┘
```

## Requirements

- **iOS**: 13.0+
- **macOS**: 13.0+
- **Swift**: 6.1+
- **Xcode**: 15.0+

## Limitations

- IPv4 only (Fragmented UDP/IPv6 support planned)
- Single network interface
- No DHCP server

## Roadmap

- [ ] IPv6 support
- [ ] Traffic statistics and connection management
- [ ] Fragmented UDP

## Contributing

Contributions welcome! Please open an issue or PR.

## License

Apache License2.0. See [LICENSE](LICENSE) for details.

## Credits

Built on top of [lwIP](https://savannah.nongnu.org/projects/lwip/) - A Lightweight TCP/IP stack.

## Migration Notes (0.0.4)

- Swift wrapper module removed. Import `TunForge` directly (Objective‑C target is Swift‑ready).
- Removed Swift typealiases `IPStack` and `TCPSocket`. Use `LWIPStack` and `LWTCPSocket`.
- IPv4 and queue configuration is now init-only via `LWIPStackConfig`/`IPv4Settings` and applied on first `defaultIPStack(with:)`.
