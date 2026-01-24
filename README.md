# TunForge
[![CI](https://github.com/CoderQuinn/TunForge/actions/workflows/ci.yml/badge.svg)](
https://github.com/CoderQuinn/TunForge/actions/workflows/ci.yml
)
![License](https://img.shields.io/github/license/CoderQuinn/TunForge)
![Status](https://img.shields.io/badge/status-core_stable_(pre--1.0)-blue)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-blue)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen)

Lightweight Tun2Socks-style TCP transport core for iOS/macOS.

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

- Transparent TCP interception from TUN (lwIP-based)
- Explicit and deterministic TCP lifecycle (no implicit closure)
- Directional FIN / EOF semantics (no inferred shutdown)
- Explicit backpressure via receive/write gating
- Minimal, contract-driven callback API
- Zero-copy receive via `onReadableBytes` and efficient send via `writeBytes:length:`

## Design Principles (0.6.x)

TunForge enforces a strict transport model:

- **Liveness is explicit**  
  `alive` determines whether an object may be accessed safely.  
  When `alive == false`, all other state is semantically invalid.

- **State controls permissions, not existence**  
  Connection state determines which actions are allowed, never whether
  the object is still alive.

- **FIN / EOF are directional events**  
  They never imply full connection closure.

- **No implicit behavior**  
  TCP closure, half-close, and backpressure transitions are always
  explicit and initiated by upper layers.

These constraints intentionally remove flexibility in favor of
predictability and correctness.

## Scope & Roadmap

TunForge is a low-level user-space networking data plane.

Focus areas:
- TCP lifecycle robustness
- IPv4 / IPv6 parity
- ICMP support (basic diagnostics)

Out of scope:
- Full UDP proxy semantics
- Fragmented UDP handling
- Application-layer protocols (HTTP / SOCKS)
- Traffic metrics or accounting

TunForge aims to be boring, predictable, and correct.

## UDP Handling Policy

TunForge does not implement full UDP proxying.

- Non-fragmented UDP packets follow direct/bypass paths.
- Fragmented UDP packets are not supported.

Higher-level components (such as NetForge) are responsible for
UDP direct/bypass handling and application-layer proxy logic.

## Installation (SPM)

```swift
.package(
    url: "https://github.com/CoderQuinn/TunForge",
  from: "0.6.0"
)
```

## Quick Use

- Swift convenience: use `TFIPStack.shared` as the shared singleton (alias of `default()`), and `setOutboundHandler(_:)` for Swift-native packet arrays.
- Configure `TFGlobalScheduler` with `packetsQueue` and `connectionsQueue` **before** the first `TFIPStack.defaultStack()`.
- Set `TFIPStack.delegate`; in `didAcceptNewTCPConnection`, call `handler(true)` exactly once.
- Call `connection.markActive()` on `packetsQueue` to accept the TCP connection.
- Inbound delivery is gated explicitly; receive callbacks are only invoked when enabled.
- Receive:
    - Prefer `onReadableBytes` (batch slices); call `completion()` exactly once to release internal buffers.
- Send: `writeBytes(_:length:)` (no extra wrapper, length <= 65535) or `writeData(_:)` (rejects > 65535 bytes).
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
