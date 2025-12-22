# TunForge

**Lightweight Tun2Socks TCP core for iOS / macOS**

TunForge is a lightweight **Tun2Socks-style TCP interception core** built on lwIP, designed for Network Extension–based VPN and proxy applications on Apple platforms.

It provides **transparent TCP interception, deterministic lifecycle management, and a minimal socket abstraction**, intended to be embedded as a low-level transport component.

> **Status**: `0.1.0` — Core architecture stabilized (pre-1.0)

---

## Overview

TunForge is **not** a full VPN or proxy solution.

It focuses exclusively on the **TCP interception layer**: capturing inbound TCP connections from a TUN interface and exposing them as manageable socket-like objects for upper-layer routing and proxy logic.

---

## Non-Goals (0.1.x)

The following are intentionally out of scope:

- IPv6 support
- Full UDP proxying  
  (only fragmented UDP paths are handled; non-fragmented packets bypass)
- DNS interception (UDP / TCP / DoH / DoT)
- Traffic statistics or metrics

These constraints are deliberate and may be revisited in later versions.

---

## Installation

TunForge is distributed via **Swift Package Manager**.

Add the repository to your project dependencies and pin it to version `0.1.0` or later.

```swift
.package(
    url: "https://github.com/CoderQuinn/TunForge",
    from: "0.1.0"
)
```

## Example (Illustrative)

The following snippet illustrates the **integration surface only**.
It is not a complete or standalone example.

```swift
let stack = TFIPStack.stack()
stack.outboundHandler = { packets, _ in
    /* write packets back to TUN */
}
```

---

## Requirements

- iOS 13.0+ / macOS 11.0+
- Swift 5.3+
- Network Extension entitlement

---

## License

Apache License 2.0
