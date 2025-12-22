# Architecture

This document outlines the core architectural principles behind **TunForge**.

It exists to explain *why* the system is structured this way, not *how* it is implemented.

---

## Scope

TunForge is a **Tun2Socks-style TCP interception core** designed to be embedded
inside Network Extension–based VPN or proxy systems.

Its responsibility is limited to:
- intercepting inbound TCP connections from a TUN interface
- exposing them as socket-like objects
- managing TCP lifecycle deterministically

TunForge explicitly does **not** handle routing, proxy protocols, DNS,
UDP, or IPv6 (0.1.x series).

---

## Design Principles

The architecture is driven by a small set of non-negotiable principles:

- **Deterministic lifecycle ownership**
  TCP state ownership is explicit, centralized, and one-way.

- **Single-threaded execution model**
  All lwIP and TCP state is serialized to avoid locking and concurrency hazards.

- **Minimal abstraction surface**
  Only abstractions required for correctness and embeddability are introduced.

- **Embeddability over completeness**
  TunForge is a core component, not a standalone networking solution.

---

## Execution Model

- lwIP operates in **NO_SYS** mode
- All TCP/IP processing runs on a single internal queue
- Delegate callbacks are dispatched separately

This model prioritizes correctness and predictability over parallelism.

---

## TCP Interception

- No `listen()`-based sockets are used
- TCP connections originate from packets injected via a TUN interface
- Inbound connections are surfaced through a delegate interface

Each connection is represented as a managed socket abstraction
with a clearly defined lifecycle.

---

## Lifecycle and Teardown

- PCBs are never exposed directly
- Each TCP connection has a single owner
- Graceful close, half-close, and abort paths are explicitly defined
- All teardown paths converge on a unified destruction mechanism

This prevents implicit ownership and use-after-free errors.

---

## Non-Goals (0.1.x)

- Protocol completeness
- UDP or IPv6 support
- DNS interception
- Throughput optimization at the cost of complexity

Feature scope is intentionally constrained to protect architectural clarity.

---

## Stability Contract

As of **0.1.0**:
- The architectural model is considered stable
- Public APIs are safe to depend on (pre-1.0 semantics)
- Future changes are expected to preserve these principles

---

## Summary

TunForge prioritizes **correctness, determinism, and clarity** over feature count.

Any change that weakens these properties should be carefully justified.
