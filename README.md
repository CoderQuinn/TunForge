# TunForge

**Lightweight IP stack for iOS/macOS on lwIP.**

## Quick Start
- Add via SwiftPM: `.package(url: "https://github.com/CoderQuinn/TunForg", from: "0.0.2")`
- Import and configure:
```swift
import TunForge

let stack = LWIPStack.default()
stack.configureIPv4(withIP: "10.0.0.2", netmask: "255.255.255.0", gateway: "10.0.0.1")
stack.outboundHandler = { packet, family in /* send out */ }
```

## What It Is
- Swift-first API; Objective-C used internally to bridge lwIP (C)
- TCP sockets with event callbacks (`TSTCPSocketDelegate`)
- Thread-safe processing on dedicated queues

## Platform
- iOS 15+, macOS 13+

## Limitations
- IPv4-only; UDP/IPv6 planned
- Single interface; no DHCP

## Changelog
See [CHANGELOG.md](CHANGELOG.md) for releases.
