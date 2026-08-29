# TunForge

[![CI](https://github.com/CoderQuinn/TunForge/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/CoderQuinn/TunForge/actions/workflows/ci.yml)
[![Lint](https://github.com/CoderQuinn/TunForge/actions/workflows/format-style.yml/badge.svg?branch=main)](https://github.com/CoderQuinn/TunForge/actions/workflows/format-style.yml)
[![Unit Tests](https://github.com/CoderQuinn/TunForge/actions/workflows/unit-tests.yml/badge.svg?branch=main)](https://github.com/CoderQuinn/TunForge/actions/workflows/unit-tests.yml)
[![Regression Tests](https://github.com/CoderQuinn/TunForge/actions/workflows/regression-tests.yml/badge.svg?branch=main)](https://github.com/CoderQuinn/TunForge/actions/workflows/regression-tests.yml)
[![XCTest](https://img.shields.io/badge/unit%20tests-XCTest-blue)](docs/TESTING.md)
![License](https://img.shields.io/github/license/CoderQuinn/TunForge)
![Status](https://img.shields.io/badge/status-core_stable_(pre--1.0)-blue)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-blue)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen)

Lightweight tun2socks-style TCP data plane for iOS / macOS.

TunForge is a low-level, user-space TCP interception core built on lwIP,
designed for deterministic lifecycle control and predictable backpressure
in TUN-based VPN / proxy environments.

## Background

TunForge is the fulfillment of an earlier commitment made in [YYTun2Socks](https://github.com/CoderQuinn/YYTun2Socks).

The original YYTun2Socks project was an early, immature exploration of tun2socks-style TCP interception on iOS.
At the time, the implementation suffered from unclear boundaries and limited lifecycle control.

TunForge revisits the same problem space with a clean-slate design, clear responsibility boundaries, and a production-oriented mindset.

## What TunForge Is

TunForge is intentionally boring.

It focuses exclusively on:

- TCP interception from TUN
- Correct TCP lifecycle semantics
- Explicit flow control and backpressure
- Minimal, verifiable callback surface

TunForge is not a proxy, protocol router, or VPN product by itself.

## Design Principles

- **TCP-first, TCP-only (by design)**
  UDP is not part of the core data plane.

- **Deterministic lifecycle**
  No inferred closure, no hidden state transitions.

- **Explicit flow control**
  Upper layers must explicitly:
  - enable inbound delivery
  - acknowledge delivered bytes
  - manage half-close / full-close

- **Minimal API surface**
  Fewer callbacks, clearer contracts.

- **Zero-copy where it matters**
  `onReadableBytes` exposes lwIP buffers directly with explicit release.

## Core Capabilities

- Transparent TCP interception from TUN (lwIP raw API)
- Per-connection lifecycle state machine
- Backpressure-aware receive gating
- Zero-copy receive path (`onReadableBytes`)
- Efficient send path (`writeBytes:length:`)
- Clear separation between:
  - lwIP execution (`packetsQueue`)
  - stack-level delegate hops (`connectionsQueue`)
  - per-connection user callbacks (dedicated serial queues)

## Explicit Non-Goals

TunForge does not aim to provide:

- Full UDP proxy semantics
- Fragmented UDP reassembly
- Application-layer protocols (HTTP / SOCKS / TLS)
- Traffic accounting, statistics, or policy engines

These belong to higher-level layers.

## UDP Handling Policy

TunForge does not implement general UDP proxying.

- Non-fragmented UDP packets may pass through direct / bypass paths.
- Fragmented UDP packets are intentionally unsupported.

Fragmented UDP adds significant complexity and memory cost,
while providing little practical value in modern VPN scenarios.

Higher-level components in the embedding application are responsible for
UDP routing, proxying, and protocol-specific behavior.

## Architecture Positioning

```
┌──────────────────────────────┐
│   Host / application layer    │
│  Routing / policy / proxy    │
│  (SOCKS, HTTP, TLS, etc.)   │
│  UDP direct / bypass         │
└──────────────▲───────────────┘
               │
┌──────────────┴───────────────┐
│           TunForge           │
│     TCP Data Plane Core      │
│  - TCP lifecycle             │
│  - Backpressure              │
│  - Zero-copy receive         │
│  - Flow abstraction          │
└──────────────▲───────────────┘
               │
┌──────────────┴───────────────┐
│             lwIP             │
│   User-space TCP/IP stack    │
│   (IPv4 / IPv6 / ICMP)       │
└──────────────▲───────────────┘
               │
┌──────────────┴───────────────┐
│              TUN             │
│   OS Virtual Network Device  │
└──────────────────────────────┘

```

TunForge is a foundation layer, not a feature layer.

## Installation (Swift Package Manager)

```swift
.package(
    url: "https://github.com/CoderQuinn/TunForge",
    from: "0.6.0"
)
```

## Quick Usage Notes

- Configure `TFGlobalScheduler` before accessing `TFIPStack`. The host typically maps `packetsQueue` and `connectionsQueue` onto executors that match its runtime (for example a SwiftNIO `EventLoop`–bound dispatch queue): lwIP and `TFTCPConnection` state stay on `packetsQueue`; stack-level delegate work (e.g. `didAcceptNewTCPConnection`) uses `connectionsQueue`.
- All lwIP interaction runs on `packetsQueue`.
- `TFTCPConnection` property callbacks run on a **per-connection serial** GCD queue (distinct connections run in parallel). The injected `connectionsQueue` is only for stack-level work (e.g. `didAcceptNewTCPConnection`), not for those per-connection property callbacks.
- In `didAcceptNewTCPConnection`, call the accept handler exactly once: `handler(true)` hands off ownership (it does **not** activate), `handler(false)` rejects.
- After accepting, call `markActive()` explicitly to establish the connection (e.g. once upstream is ready); otherwise it aborts on a New-state timeout.
- Use `setInboundDeliveryEnabled(_:)` to control receive flow.
- After consuming inbound data, call `acknowledgeDeliveredBytes(_:)`.
- Close explicitly via `shutdownWrite()`, `gracefulClose()`, or `abort()`.

TunForge assumes the caller is disciplined.

## Roadmap (Pre-1.0)

### Current Focus (0.6.x)

- Harden TCP lifecycle invariants
- Strengthen backpressure correctness
- Internal cleanup and API tightening
- Per-connection serial callback queues (parallel across connections)
- Improved documentation of contracts and invariants

### Planned (Pre-1.0)

- IPv4 / IPv6 parity
- ICMP basics (e.g. ping, diagnostics)
- Further lifecycle edge-case hardening

### Explicitly Deferred

- Full UDP proxy semantics
- Application-layer protocols
- Metrics, accounting, or analytics

## Testing

Unit tests are **XCTest-only** (Core ObjC + Swift facade). See [docs/TESTING.md](./docs/TESTING.md) for layout, process-global rules, and PR checklist.

```bash
./Scripts/run-tests.sh unit
./Scripts/run-tests.sh regression
# Or run everything:
./Scripts/run-tests.sh all
```

Automation is split into independent [CI](https://github.com/CoderQuinn/TunForge/actions/workflows/ci.yml), [Lint](https://github.com/CoderQuinn/TunForge/actions/workflows/format-style.yml), [Unit Tests](https://github.com/CoderQuinn/TunForge/actions/workflows/unit-tests.yml), and [Regression Tests](https://github.com/CoderQuinn/TunForge/actions/workflows/regression-tests.yml) gates.

## Status

TunForge is pre-1.0 but core-stable.

APIs may still evolve, but the architectural direction is fixed:
a small, predictable TCP data plane.

## Acknowledgements

- lwIP — Lightweight TCP/IP stack
  https://www.nongnu.org/lwip/

- tun2socks (zhuhaow)
  https://github.com/zhuhaow/tun2socks

## License

Apache License 2.0

> TunForge is a foundation layer.
> Higher-level routing and protocol logic live outside this repository
> by design.

See [ROADMAP.md](./ROADMAP.md) for planned internal milestones.
