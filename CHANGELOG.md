# Changelog

## [0.2.0] — 2026-01-09

### Breaking Changes

- Public API/integration contract updated (0.1.x -> 0.2.x)
- `TFGlobalScheduler` must be configured once **before** the first `TFIPStack.defaultStack()` acquire
- All lwIP-facing calls (`start/stop/inputPacket`, and `TFTCPConnection.markActive/setRecvEnabled`) must run on `TFGlobalScheduler.packetsQueue`
- `TFIPStackDelegate.didAcceptNewTCPConnection(...handler:)` is invoked on `connectionsQueue` and the `handler` must be called exactly once
- Accepted connections default to receive paused; upper layer must explicitly `markActive()` and `setRecvEnabled(true)` when ready

### Packaging & Docs

- Update SPM metadata and dependency lockfile
- Refresh README: version badge/status, install snippet, and Swift requirement alignment
- Minor warning cleanup (Swift adapter + ObjC nullability annotations)
- Document a minimal integration skeleton for the updated API

## [0.1.0] — 2025-12-22

### Experimental (Pre-1.0)

-  Introduced the core lifecycle model for stack / socket / lwIP PCB
-  Unified ownership/lifecycle binding to reduce accidental misuse
-  Defined explicit scheduling semantics with a single lwIP process queue
-  Working TCP interception core, but APIs and integration contract were still evolving
-  Public API was experimental and subject to change

This release introduced the architecture, but should be treated as experimental.

---

## [0.0.5] — 2025-12-20

### Stability & Reliability

- Graceful connection close with configurable timeout (default 5s)
- Half-close support (independent FIN handling)
- Automatic socket cleanup when no delegate is present
- Improved logging with connection-level context
- API cleanup and removal of unused configuration

---

## [0.0.4] — 2025-12-19

### Swift API & Modularization

- Swift-friendly type aliases (`TSIPStack`, `TSTCPSocket`)
- Modular targets:
  - TunForgeCore (Objective-C)
  - TunForge (Swift)
- Improved configuration boundaries

---

## [0.0.3] — 2025-12-19

### Direct Integration

- Direct Objective-C API without wrapper layers

---

## [0.0.2] — 2025-12-16

### Foundation

- Unified logging system
- Thread-safety guarantees

---

## [0.0.1] — 2025-12-13

### Initial Release

- Working lwIP integration for Network Extensions
