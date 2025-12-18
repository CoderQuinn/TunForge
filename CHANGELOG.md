# Changelog

Summary of notable changes. Versions follow SemVer.

## 0.0.3 — 2025-12-19
- **Breaking**: Direct ObjC mapping - removed Swift wrapper layers
- `IPStack` now typealias to `LWIPStack` (ObjC)
- `TCPSocket` now typealias to `LWTCPSocket` (ObjC)
- Fixed IP address byte order handling (ntohl)
- Improved README with comprehensive examples
- Updated minimum iOS version to 13.0
- Fixed directory name: Untils → Utils
- Updated CocoaLumberjack API usage

## 0.0.2 — 2025-12-16
- Swift-first API; ObjC kept as internal bridge
- Unified logging via C→Swift bridge (`TFLog*` → `TunForgeLogger`)
- Renames: `TCPSocket` → `LWTCPSocket`, `IPStack` → `LWIPStack`
- Thread-safety improvements across lwIP queues

## 0.0.1 — 2025-12-13
- Initial lwIP integration and TCP socket support
- Basic Objective-C wrappers and SwiftPM setup

For older details, see Git history.
