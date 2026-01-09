# TunForge

**Lightweight Tun2Socks TCP core for iOS / macOS**

TunForge is a lightweight **Tun2Socks-style TCP interception core** built on lwIP, designed for Network Extension–based VPN and proxy applications on Apple platforms.

It provides **transparent TCP interception, deterministic lifecycle management, and a minimal socket abstraction**, intended to be embedded as a low-level transport component.

> **Status**: `0.2.0` — Core architecture stabilized (pre-1.0)

---

## Overview

TunForge is **not** a full VPN or proxy solution.

It focuses exclusively on the **TCP interception layer**: capturing inbound TCP connections from a TUN interface and exposing them as manageable socket-like objects for upper-layer routing and proxy logic.

---

## Non-Goals (0.2.x)

The following are intentionally out of scope:

- IPv6 support
- Full UDP proxying  
  (only fragmented UDP paths are handled; non-fragmented packets bypass)
- Traffic statistics or metrics

These constraints are deliberate and may be revisited in later versions.

---

## Installation

TunForge is distributed via **Swift Package Manager**.

Add the repository to your project dependencies and pin it to version `0.2.0` or later.

```swift
.package(
    url: "https://github.com/CoderQuinn/TunForge",
    from: "0.2.0"
)
```

## Minimal Integration (Swift)

TunForge is designed to be embedded in a Network Extension tunnel/proxy.

Key rules:

- You must configure `TFGlobalScheduler` **before** the first `TFIPStack.defaultStack()` acquire.
- All `TFIPStack` and lwIP-facing calls must run on `packetsQueue`.
- `TFIPStackDelegate` is invoked on `connectionsQueue` and its `handler` must be called exactly once.

```swift
import Foundation
import TunForgeCore
import TunForge // optional: adds Swift helpers (e.g. setOutboundHandler)

final class TunForgeCoreDriver: NSObject, TFIPStackDelegate {
    private let scheduler = TFGlobalScheduler.shared()
    private let packetsQueue = DispatchQueue(label: "tunforge.packets")
    private let connectionsQueue = DispatchQueue(label: "tunforge.connections")

    private var stack: TFIPStack?

    func start(writeToTun: @escaping (_ packets: [Data], _ families: [Int32]) -> Void) {
        // Required for internal queue assertions.
        TFBindQueueSpecific(
            packetsQueue,
            TFGetPacketsQueueKey(),
            UnsafeMutableRawPointer(mutating: TFGetPacketsQueueKey())
        )
        TFBindQueueSpecific(
            connectionsQueue,
            TFGetConnectionsQueueKey(),
            UnsafeMutableRawPointer(mutating: TFGetConnectionsQueueKey())
        )

        // Must be done once, before using TFIPStack.
        scheduler.configure(withPacketsQueue: packetsQueue, connectionsQueue: connectionsQueue)

        let stack = TFIPStack.defaultStack()
        self.stack = stack

        stack.delegate = self
        stack.setOutboundHandler { packets, families in
            // families is currently AF_INET for IPv4.
            writeToTun(packets, families)
        }

        scheduler.packetsPerformAsync {
            stack.start()
        }
    }

    func inputPacketFromTun(_ packet: Data) {
        guard let stack else { return }
        scheduler.packetsPerformAsync {
            stack.inputPacket(packet)
        }
    }

  // MARK: - TFIPStackDelegate (runs on connectionsQueue)

    func didAcceptNewTCPConnection(
        _ connection: TFTCPConnection,
        handler: @escaping (Bool) -> Void
    ) {
        // Configure callbacks (invoked on connectionsQueue).
        connection.onReadable = { conn, data in
            // Handle upstream bytes (e.g. forward to your proxy transport).
            _ = (conn, data)
        }

        connection.onTerminated = { conn, reason in
            _ = (conn, reason)
        }

        // MUST be called exactly once.
        handler(true)

        // Finish backlog establishment and enable receive on packetsQueue.
        scheduler.packetsPerformAsync {
            connection.markActive()
            connection.setRecvEnabled(true)
        }
    }
}
```

---

## Requirements

- iOS 13.0+ / macOS 11.0+
- Swift 5.9+
- Network Extension entitlement

---

## License

Apache License 2.0
