# TunForge
[![CI](https://github.com/CoderQuinn/TunForge/actions/workflows/ci.yml/badge.svg)](
https://github.com/CoderQuinn/TunForge/actions/workflows/ci.yml
)
![Release](https://img.shields.io/github/v/release/CoderQuinn/TunForge)
![License](https://img.shields.io/github/license/CoderQuinn/TunForge)
![Status](https://img.shields.io/badge/status-core_stable_(pre--1.0)-blue)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-lightgrey)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen)

Lightweight Tun2Socks TCP core for iOS/macOS.

Status: 0.2.1 — Core stabilized (pre‑1.0)

## Overview

- Tun2Socks‑style TCP interception built on lwIP for TUN-based VPN/proxy.
- Exposes connections as manageable socket-like objects.

## Highlights

- Transparent TCP interception from TUN
- Deterministic lifecycle across stack/connection
- Minimal callback API
- Zero-copy receive `onReadableBytes` and efficient send `writeBytes:length:`

## Non‑Goals (0.2.x)

- IPv6 support
- Full UDP proxying (fragmented only)
- Built‑in traffic metrics

## Installation (SPM)

```swift
.package(
    url: "https://github.com/CoderQuinn/TunForge",
    from: "0.2.1"
)
```

## Quick Use

- Configure `TFGlobalScheduler` with `packetsQueue` and `connectionsQueue` **before** the first `TFIPStack.defaultStack()`.
- Set `TFIPStack.delegate`; in `didAcceptNewTCPConnection`, call `handler(true)` exactly once.
- On `packetsQueue`: call `connection.markActive()` then `connection.setRecvEnabled(true)` to enable receive.
- Receive:
  - Prefer `onReadableBytes` (batch slices); call `completion()` when done.
  - Or use `onReadable` for compatibility (allocates & copies).
- Send: `writeBytes(_:length:)` (no extra wrapper) or `writeData(_:)`.
- Close: `shutdownWrite()` (half-close), `gracefulClose()`, or `abort()`.

## Requirements

- iOS 13.0+ / macOS 11.0+
- Swift 5.9+
- Network Extension entitlement

## Acknowledgements

- lwIP — Lightweight TCP/IP stack: https://www.nongnu.org/lwip/
- tun2socks (zhuhaow): https://github.com/zhuhaow/tun2socks

## License

Apache License 2.0

> TunForge is part of the QuantumLink VPN prototype.  
> Higher-level protocol routing (NetForge) is under active refinement.
