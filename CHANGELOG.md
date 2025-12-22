# Changelog

## [0.1.0] — 2025-12-22

### Core Architecture Stabilized

- 🧠 Frozen lifecycle model for stack / socket / lwIP PCB
- 🔒 Deterministic ownership via a unified lifecycle binding mechanism
- 🧵 Explicit scheduling semantics with a single lwIP process queue
- 🔌 Transparent TCP interception considered stable and reusable
- 📦 Public API deemed safe to depend on (pre-1.0)

This release marks the transition from experimental code to a stable TCP core.

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
