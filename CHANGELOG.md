# Changelog

## [0.6.0] — 2026-05-10

### Changed

- `TFTCPConnection` property callbacks are scheduled on a **per-connection serial** GCD queue so different connections can run callbacks in parallel while preserving per-connection ordering. `TFGlobalScheduler.connectionsQueue` remains for stack-level delegates (e.g. TCP accept).
- Documentation: clarify that `packetsQueue` / `connectionsQueue` are host-injected for executor alignment (e.g. SwiftNIO event loops); README architecture and integration notes use generic “host / embedding application” wording.
- Clarify TCP accept as a two-phase contract: `handler(YES)` is ownership hand-off only; host must call `markActive` to establish. `OutboundHandler` is documented as synchronous on `packetsQueue`.

### Fixed

- Bind `TFGlobalScheduler` queue-specific keys on configure so packets/connections affinity checks and re-entrant `performSync` fast paths work.
- Enforce accept-handler exactly-once on `packetsQueue`.
- Keep New-state connections alive (`acceptPhaseRetain`) and reclaim orphaned PCBs on poll so dropping an accept reference cannot leak listen backlog.
- Guard `onReadableBytes` completion against double-free.
- Make `TFIPStack.start` idempotent when already running; abort via connection wrapper when accept has no delegate.
- Detach lwIP callbacks on `gracefulClose` success before clearing the PCB pointer.

### Tests

- Expand `TunForgeCoreTests`: scheduler keys, full SYN accept path, New-timeout / host-drop reclaim, receive ACK clamp / double completion, stack stop/start restart.
- Architecture review: `docs/ARCHITECTURE-REVIEW-0.6.md`.

### Notes

- XCTest coverage for accept / scheduler / inbound credit is substantially broader than the initial 0.6.0 cut; Release builds still do not enforce packets-queue asserts (DEBUG-only).

## [0.5.1] — 2026-01-25

### Changed
- Align README with updated TCP activation and inbound delivery gating (`setInboundDeliveryEnabled`).
- Update receive credit method name in docs (`acknowledgeDeliveredBytes`).
- Clarify Swift-facing singleton access (`TFIPStack.shared` / `TFIPStack.default()`).

## [0.5.0] — 2026-01-21

### Changed
- API cleanup: clarify TCP receive ownership and activation semantics.
- Replace public receive toggling with explicit activation receive gate.
- TCP receive backpressure is now fully owned by `TFTCPConnection`; upper layers only credit consumed bytes.
- Document TCP receive credit flow, completion requirements, and `writeBytes` length limit.
- Refresh documentation and Swift convenience API references (`TFIPStack.shared`, `setOutboundHandler(_:)`).

## [0.4.0] — 2026-01-17

### Fixed
- Guard `outboundHandler` to avoid crash when unset.
- Make `TFIPStack` restartable by resetting `ready` and rebuilding `stackRef` on start.
- Reject oversized `writeData` calls to avoid implicit truncation.
- Adjust logging levels and add warnings for TCP errors/oversized writes.
- Remove high-frequency debug logs to reduce noise.

## [0.3.1] — 2026-01-15

### Fixed
- Fix TOCTOU race in TCP read/termination callbacks
- Prevent use-after-detach callback invocation
- Fix potential unbounded memory growth under high concurrency
- This release contains critical stability fixes and is strongly recommended.

## [0.3.0] — 2026-01-11

### Performance

- Introduce a zero-copy TCP receive path via `onReadableBytes`, avoiding intermediate `NSData` allocations for inbound data.
- Add `writeBytes:length:` to bypass `NSData` wrapping on the send path, reducing extra memory copies at the Objective-C bridge layer.

### API

- `TFTCPConnection` gains `onReadableBytes` (batch slices + completion) and `writeBytes:length:` for more efficient data handling.
- Existing `onReadable` remains for compatibility; prefer `onReadableBytes` in new integrations.

### Packaging & CI

- Tidy CI workflow YAML formatting and branches configuration.
- Align lwIP option wrappers to platform-specific headers and keep core semantics defined once.

## [0.2.0] — 2026-01-09

### Breaking Changes

- Public API/integration contract updated (0.1.x -> 0.2.x)
- `TFGlobalScheduler` must be configured once **before** the first `TFIPStack.defaultStack()` acquire
- All lwIP-facing calls (`start/stop/inputPacket`, and `TFTCPConnection.markActive/setInboundDeliveryEnabled`) must run on `TFGlobalScheduler.packetsQueue`
- `TFIPStackDelegate.didAcceptNewTCPConnection(...handler:)` is invoked on `connectionsQueue` and the `handler` must be called exactly once
- Accepted connections default to receive paused; upper layer must explicitly `markActive()` and `setInboundDeliveryEnabled(true)` when ready

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
