# TunForge Roadmap

This document describes internal engineering milestones.
APIs and timelines may evolve.

---

## 0.6.0 — Concurrency & Queue Model

Goal: finalize the execution model while keeping lwIP strictly serialized.

- `packetsQueue` remains strictly serialized
- connection callbacks become parallelized
- `TFTCPConnection` internal state remains `packetsQueue`-owned
- callback re-entrancy and lifecycle contracts documented
- callback hop paths minimized for performance

Out of scope:
- zero-copy redesign
- memory pooling

---

## 0.7.0 — Zero-Copy Hardening

Goal: make zero-copy receive stable under sustained high load.

- `TFBytesSlice` allocation optimization
- slice lifecycle enforcement and debug checks
- inflight ACK accounting validation
- zero-copy vs copied-path observability

Out of scope:
- concurrency model changes
- new protocols
