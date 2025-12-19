# Changelog

Summary of notable changes. Versions follow SemVer.

## 0.0.4 — 2025-12-19
- Breaking: Removed Swift wrapper target/module (移除 Swift 封装层). Public API is the Objective‑C target `TunForge`, importable from Swift.
- Breaking: Removed Swift typealiases `IPStack` and `TCPSocket`. Use `LWIPStack` and `LWTCPSocket` directly.
- Target rename: `TunForgeCore` merged/renamed to `TunForge` (ObjC target exposed as the product).
- Configuration model finalized: `+defaultIPStackWithConfig:` is the designated initializer; `+defaultIPStack` remains a convenience.
- Init-only configuration: apply `LWIPStackConfig` with optional `IPv4Settings` only on first singleton creation. Subsequent calls ignore config.
- Removed preconfiguration and instance IPv4 setters: `+configureDefaultProcessQueue:`, `+configureDefaultIPv4WithIP:netmask:gw:` and `-configureIPv4WithIP:netmask:gw:`.
- Timer: Fixed/resumed periodic lwIP timeout processing via `resumeTimer` implementation.
- CI: Updated to build only the `TunForge` target.
- Docs: README updated to use `import TunForge`, new config flow, and delegate‑only sockets.

## 0.0.3 — 2025-12-19
- **Breaking**: Direct ObjC mapping - removed Swift wrapper layers
- `IPStack` now typealias to `LWIPStack` (ObjC)
- `TCPSocket` now typealias to `LWTCPSocket` (ObjC)
- Fixed IP address byte order handling (ntohl)
- Improved README with comprehensive examples
- Updated minimum iOS version to 13.0
- Fixed directory name: Untils → Utils

## 0.0.2 — 2025-12-16
- Swift-first API; ObjC kept as internal bridge
- Unified logging via C→Swift bridge (`TFLog*` → `TunForgeLogger`)
- Renames: `TCPSocket` → `LWTCPSocket`, `IPStack` → `LWIPStack`
- Thread-safety improvements across lwIP queues

## 0.0.1 — 2025-12-13
- Initial lwIP integration and TCP socket support
- Basic Objective-C wrappers and SwiftPM setup

For older details, see Git history.
