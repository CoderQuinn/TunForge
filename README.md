# TunForge
[![CI](https://github.com/CoderQuinn/TunForge/actions/workflows/ci.yml/badge.svg)](
https://github.com/CoderQuinn/TunForge/actions/workflows/ci.yml
)
![License](https://img.shields.io/github/license/CoderQuinn/TunForge)
![Status](https://img.shields.io/badge/status-core_stable_(pre--1.0)-blue)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-lightgrey)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen)

Lightweight Tun2Socks TCP core for iOS/macOS.

### Background

TunForge is the fulfillment of an earlier commitment made in
[YYTun2Socks](https://github.com/CoderQuinn/YYTun2Socks).

The original YYTun2Socks project was an early, immature exploration
of tun2socks-style TCP interception on iOS.
At the time, the implementation suffered from unclear boundaries
and limited lifecycle control.

TunForge revisits the same problem space with a clean-slate design,
clear responsibility boundaries, and a production-oriented mindset.

## Overview

- Tun2Socks‑style TCP interception built on lwIP for TUN-based VPN/proxy.
- Exposes connections as manageable socket-like objects.

## Highlights

- Transparent TCP interception from TUN
- Deterministic lifecycle across stack/connection
- Minimal callback API
- Zero-copy receive `onReadableBytes` and efficient send `writeBytes:length:`

## Scope & Roadmap

TunForge is a low-level user-space networking data plane.

Planned evolution focuses on:
- TCP lifecycle robustness
- IPv4 / IPv6 parity
- ICMP support (e.g. ping, basic diagnostics)
- Minimal IPv4 control-plane protocols when required

Explicitly out of scope (no short- or mid-term plan):
- Full UDP proxying semantics
- Fragmented UDP handling
- Application-layer protocols (HTTP / SOCKS)
- Traffic metrics or accounting

Fragmented UDP is intentionally excluded due to its
high complexity and low practical return in typical VPN scenarios.

TunForge aims to be boring, predictable, and correct.

## UDP Handling Policy

TunForge does not implement full UDP proxying.

- Non-fragmented UDP packets are handled via direct/bypass paths
  for maximum performance and simplicity.
- Fragmented UDP packets are intentionally not supported.

In practice, fragmented UDP traffic is rare in modern VPN scenarios,
while its reassembly complexity and memory cost are high.
The cost–benefit tradeoff does not justify implementation.

Higher-level components (such as NetForge) are responsible for
UDP direct/bypass handling and application-layer proxy logic.

## Installation (SPM)

```swift
.package(
    url: "https://github.com/CoderQuinn/TunForge",
    from: "0.2.2"
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
