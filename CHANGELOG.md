# Changelog

Summary of notable changes. Versions follow SemVer.

## 0.2 — 2025-12-16
- Swift-first API; ObjC kept as internal bridge
- Unified logging via C→Swift bridge (`TFLog*` → `TunForgeLogger`)
- Renames: `TCPSocket` → `TSTCPSocket`, `IPStack` → `TSIPStack`
- Thread-safety improvements across lwIP queues

## 0.1 — 2025-12-13
- Initial lwIP integration and TCP socket support
- Basic Objective-C wrappers and SwiftPM setup

For older details, see Git history.
