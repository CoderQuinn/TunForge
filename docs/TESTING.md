# TunForge Unit Test Governance

> **Status**: binding for contributors and CI  
> **Last updated**: 2026-07-22

This document defines how unit and regression tests are organized, what CI enforces, and what a PR that touches contracts must include.

---

## 1. Goals

1. Keep `swift test` **stable and deterministic** on macOS CI and locally.
2. Lock queue / accept / inbound **contracts** with automated regressions (not only manual host checks).
3. Avoid process-global scheduler/stack footguns across test targets.
4. Make CI status visible via README badges.

---

## 2. Framework policy (no mix inside a target)

| Target | Framework | Language | Owns |
|--------|-----------|----------|------|
| `TunForgeCoreTests` | **XCTest only** | Objective-C | Scheduler, `TFIPStack`, `TFTCPConnection`, accept/inbound/lifecycle |
| `TunForgeTests` | **XCTest only** | Swift | Swift facade / typealiases / pure Swift helpers |

**Do not** add Swift Testing (`import Testing` / `@Test`) to either target until the package deliberately migrates as a whole. Mixing XCTest and Swift Testing in one `swift test` invocation is allowed by the toolchain but is confusing for filtering, reporting, and governance — TunForge standardizes on XCTest.

Placeholder / empty “example” tests are forbidden. Every `test*` method must assert a contract or bug regression.

---

## 3. Layout & naming

```
Tests/
  TunForgeCoreTests/          # ObjC XCTest — semantic core
    TFTCPConnectionTestEnvironment.*   # process-once scheduler + stack bootstrap
    TFIPPacketTestHelpers.*            # raw IPv4/TCP craft/parse for accept path
    TFGlobalSchedulerTests.m
    TFIPStackAcceptTests.m
    TFIPStackLifecycleTests.m
    TFTCPConnectionPublicAPITests*.m   # principal + categories
  TunForgeTests/              # Swift XCTest — facade only
    TunForgeSwiftSurfaceTests.swift
```

**Naming**

- Files: `<TypeUnderTest><Aspect>Tests.m` / `.swift`
- Methods: `test<Behavior>_<condition>_<expectation>` when helpful  
  e.g. `testAccept_handlerYes_doesNotActivateUntilMarkActive`
- Categories (`+Inbound`, `+Lifecycle`, …) group public API surfaces; keep one principal `XCTestCase` subclass.

---

## 4. Process-global rules (critical)

`TFGlobalScheduler` and `TFIPStack` are **singletons**. Tests share one process.

1. **Configure once** via `[TFTCPConnectionTestEnvironment installOnce]` from Core `setUp`. Never call `configureWithPacketsQueue:connectionsQueue:` a second time in the same process.
2. **Leave the stack running**. Suites that call `stop` (e.g. lifecycle) **must** `start` again in `tearDown` so sibling suites still see a live listener.
3. **Swift facade tests** must not reconfigure the scheduler. Prefer pure Swift assertions that do not require `TFIPStack.default()` unless Core bootstrap has already run (order is not guaranteed — avoid depending on it).
4. **Strong-ref connections** across `waitForExpectations` when callbacks are async on per-connection queues.

---

## 5. Testing hooks policy

- `TFTCPConnectionTestingAPI.h` and harnesses under `Sources/TunForgeCore/` are **test-only unstable hooks**, not public API.
- Prefer hooks that stay in the same compilation unit as private state (poll / New-timeout / inflight ACK / listen port).
- Do not import lwIP private headers from the test target unless required for packet helpers; prefer Core-exported testing entry points.

---

## 6. Required coverage when changing contracts

| Change area | Must add / update |
|-------------|-------------------|
| Scheduler / queue keys | `TFGlobalSchedulerTests` |
| Accept / `markActive` / backlog | `TFIPStackAcceptTests` (+ packet helpers if handshake changes) |
| `start` / `stop` | `TFIPStackLifecycleTests` (must restore stack) |
| Inbound / ACK / completion | `TFTCPConnectionPublicAPITests+Inbound` |
| Close / abort / activate | `+Lifecycle` |
| Write / shutdown | `+WriteSend` |
| Swift facade | `TunForgeSwiftSurfaceTests` |

Document material contract changes in `docs/ARCHITECTURE.md` and, for release reviews, `docs/ARCHITECTURE-REVIEW-*.md`.

---

## 7. How to run

```bash
# Full local suite
./Scripts/run-tests.sh

# Fast unit-test gate
./Scripts/run-tests.sh unit

# TCP handshake / lifecycle regression gate
./Scripts/run-tests.sh regression

# Custom XCTest filter (backwards-compatible)
./Scripts/run-tests.sh TunForgeSwiftSurface
```

CI workflows:

- **CI** — Debug + Release builds (`.github/workflows/ci.yml`)
- **Lint** — clang-format + shellcheck (`.github/workflows/format-style.yml`)
- **Unit Tests** — `./Scripts/run-tests.sh unit` (`.github/workflows/unit-tests.yml`)
- **Regression Tests** — `./Scripts/run-tests.sh regression` (`.github/workflows/regression-tests.yml`)

Until the TCP lifecycle suites are available on `main`, the regression runner also executes the
Swift facade smoke suite so the gate is never a no-op.

---

## 8. PR checklist (unit tests)

- [ ] New/changed behavior has a failing-first regression or an assertion that would catch the bug.
- [ ] No new Swift Testing APIs in this package.
- [ ] No second `TFGlobalScheduler` configure; lifecycle tests restore `start`.
- [ ] Accept/inbound/close paths use `packetsQueue` / documented queues in the test body.
- [ ] `./Scripts/run-tests.sh unit` passes locally (or Unit Tests is green on the PR).
- [ ] Lifecycle/accept changes pass `./Scripts/run-tests.sh regression`.

---

## 9. Badges

README surfaces:

- **CI** — Debug + Release build status on `main`
- **Lint** — Objective-C/C formatting and shell-script lint status on `main`
- **Unit Tests** — dedicated unit-test workflow status on `main`
- **Regression Tests** — TCP handshake and stack lifecycle regression status on `main`
- **XCTest** — static policy badge linking here

---

## 10. References

- [`ARCHITECTURE.md`](./ARCHITECTURE.md)
- [`ARCHITECTURE-REVIEW-0.6.md`](./ARCHITECTURE-REVIEW-0.6.md)
- [`README.md`](../README.md)
