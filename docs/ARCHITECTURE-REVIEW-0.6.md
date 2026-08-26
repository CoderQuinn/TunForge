# TunForge 0.6 Architecture Review

> **Scope**: `TunForgeCore` queue contracts, TCP accept/activate lifecycle, inbound credit, and testability
> **Branch context**: `feat-0.6.0` follow-up (contract hardening + regression suite)
> **Date**: 2026-07-22
> **Status**: P0 ownership / once-only / queue-key issues addressed in code; remaining items tracked below and in [`ARCHITECTURE.md`](./ARCHITECTURE.md)

---

## 1. Executive summary

TunForgeCore is a single global lwIP data plane behind `TFIPStack`, with host-injected executors:

| Queue | Role |
|--------|------|
| `packetsQueue` | All lwIP access + `TFTCPConnection` state mutations (strictly serial) |
| `connectionsQueue` | Stack-level accept delegate hop only |
| Per-connection `callbackQueue` | Property callbacks (`onActivated`, `onReadable*`, …), ordered per connection |

The 0.6 line clarified per-connection callbacks vs `connectionsQueue`, but several **contract holes** remained that could deadlock asserts, leak listen backlog, or double-free receive buffers. This review documents those holes, the fixes shipped with this change set, and the automated regression coverage that locks the contracts in place.

---

## 2. Intended contracts (source of truth)

### 2.1 Scheduler

1. Host must call `-[TFGlobalScheduler configureWithPacketsQueue:connectionsQueue:]` **once** before `TFIPStack` / connection use.
2. Configure binds `dispatch_queue_set_specific` keys so:
   - `TF_ASSERT_ON_PACKETS_QUEUE()` can detect context
   - `packetsPerformSync` / `Async` (and connections equivalents) take the “already on queue” fast path (avoids re-entrant `dispatch_sync` deadlock)
3. Reconfigure is a programmer error (`NSAssert`).

### 2.2 Accept → activate (two-phase)

```
SYN/ACK handshake completes
        │
        ▼
tunforge_accept (packetsQueue)
  tcp_backlog_delayed
  wrap PCB → TFTCPConnection (state = New, recvEnabled = NO)
        │
        ▼
connectionsPerformAsync
  didAcceptNewTCPConnection:handler:
        │
        ├─ handler(NO)  → abort (reject)
        └─ handler(YES) → ownership hand-off ONLY
                │
                ▼
          host markActive (packetsQueue)
                │
                ▼
          Active + onActivated; still need setInboundDeliveryEnabled:YES for payloads
```

Rules:

- Accept handler must be invoked **exactly once**; extra calls are ignored (warn).
- `handler(YES)` does **not** call `tcp_backlog_accepted` / does **not** fire `onActivated`.
- Without `markActive`, New-state poll timeout (~10s) aborts the connection.
- Mutating APIs remain on `packetsQueue`.

### 2.3 Inbound delivery

- `setInboundDeliveryEnabled:` is a lifecycle/flow gate, not inflight backpressure.
- Prefer `onReadableBytes`: host calls `completion` exactly once to free pbuf/slices, then `acknowledgeDeliveredBytes:` on `packetsQueue` to open lwIP window.
- `onReadable` copies and auto-ACKs (compatibility path).
- Over-ACK clamps to `inflightAckBytes`; under-ACK leaves window closed (by design).

### 2.4 Outbound

- `OutboundHandler` runs **synchronously** on the lwIP output path (`packetsQueue`).
- Must return quickly; must not block or re-enter TunForge synchronously.

---

## 3. Findings

### 3.1 Fixed in this change set

#### F1 — Queue-specific keys never bound (P0)

**Symptom**: `TFIsOnQueue` / packets-queue asserts always false; nested `packetsPerformSync` deadlocks.

**Fix**: `TFBindQueueSpecific` for packets + connections keys inside `configureWithPacketsQueue:connectionsQueue:`.

**Tests**: `TFGlobalSchedulerTests` (key binding, nested sync, async fast-path).

#### F2 — Accept handler not once-only (P0/P1)

**Symptom**: Host double-invoking handler could race reject vs keep.

**Fix**: `handlerConsumed` flag, mutated only on `packetsQueue`.

**Tests**: `testAccept_handlerTwice_secondIgnored`.

#### F3 — Accept docs vs activation semantics (P0)

**Symptom**: Hosts treated `handler(YES)` as “established”.

**Fix**: Header/README comments; explicit `markActive` second phase.

**Tests**: `testAccept_handlerYes_doesNotActivateUntilMarkActive`, happy-path markActive once.

#### F4 — Dropping New connection orphans PCB / backlog (P0)

**Symptom**: If host releases the connection (and never calls the handler) before timeout:

1. ObjC wrapper dies; `pcbRef.object` becomes nil
2. Poll sees no connection → previously returned without reclaim
3. `TF_BACKLOGPEND` never cleared → `accepts_pending` stuck → future accepts fail

**Fix**:

- `acceptPhaseRetain` self-retain while state == New (cleared on `markActive` / terminate)
- `terminateLocked` keeps a strong self across `onTerminated` hop before releasing the retain
- `tf_tcp_poll` aborts PCB if the ObjC wrapper is already gone

**Tests**: `testAccept_hostDropsConnectionWithoutHandler_newRetainKeepsAliveUntilTimeout`, New-timeout unit tests.

#### F5 — Zero-copy completion not once-guarded (P1)

**Symptom**: Double `completion()` → double `pbuf_free` / UAF.

**Fix**: `completionConsumed` on `packetsQueue` inside the completion hop.

**Tests**: `testOnReadableBytes_doubleCompletion_isSafe`.

#### F6 — Nil-delegate accept path used raw `tcp_abort` after wrap (P1)

**Symptom**: Delegate missing after `initWithTCPPcb:` still called `tcp_abort(newpcb)` instead of going through connection abort (callback detach / terminate).

**Fix**: `[connection abort]` on the nil-delegate path (this change set).

#### F7 — `gracefulClose` success path skipped callback detach (P1)

**Symptom**: On `tcp_close` → `ERR_OK`, code nulled `self.pcb` then `terminateLocked`, which skipped `clearCallbackLocked` when `pcb` was already nil. PCB may still be live (e.g. FIN_WAIT).

**Fix**: `clearCallbackLocked` while `pcb` is still non-null, then null and terminate (this change set).

#### F8 — Double `start` without `stop` leaked timer (P1)

**Symptom**: Second `start` created a new timer while `setupLocked` early-returned on `ready`.

**Fix**: Idempotent `start` when already `ready` with a live timer; cancel stray timer if present before rebuild (this change set).

### 3.2 Remaining (not blocking this PR)

| ID | Issue | Priority | Notes |
|----|--------|----------|--------|
| R1 | `TF_ASSERT_ON_PACKETS_QUEUE` is DEBUG-only | P0/P1 | Release relies on host discipline |
| R2 | Mutating API headers incomplete on queue affinity | P1 | Partially documented on `markActive` / class concurrency note |
| R3 | Scheduler configure-once / multi-suite isolation | P1 | Process-global; tests use `installOnce` |
| R4 | `nonatomic` callback properties / `alive` cross-queue races | P2 | ARM often “works”; still a C model race |
| R5 | pbuf pool pressure on `inputPacket` | P2 | TODO in code |
| R6 | IPv6 / info naming clarity | P2 | IPv4-only opts today |
| R7 | `inboundDisabled → enable` refused_data retry integration | P1 | Unit tests free pbuf themselves today |

Track in [`ARCHITECTURE.md`](./ARCHITECTURE.md) §5.

---

## 4. Fix inventory (code map)

| Area | Files |
|------|--------|
| Queue key bind | `TFGlobalScheduler.m` |
| Accept once + docs | `TFIPStack.m`, `TFIPStack.h`, `TFTCPConnection.h`, `README.md` |
| New-state retain / poll reclaim / completion once / gracefulClose | `TFTCPConnection.m` |
| Start idempotent / nil-delegate abort | `TFIPStack.m` |
| Test hooks | `TFTCPConnectionTestingAPI.h`, hooks in `TFTCPConnection.m` / `TFIPStack.m` |

---

## 5. Test matrix

### 5.1 Scheduler — `TFGlobalSchedulerTests`

| Test | Asserts |
|------|---------|
| `testPacketsQueueKey_isBoundInsidePacketsPerform` | Key visible on packets queue |
| `testConnectionsQueueKey_isBoundInsideConnectionsPerform` | Key visible on connections queue |
| `testNestedPacketsPerformSync_doesNotDeadlock` | Re-entrant sync depth 2 |
| `testNestedConnectionsPerformSync_doesNotDeadlock` | Same for connections |
| `testOffQueue_isNotReportedOnQueue` | Test thread not falsely on-queue |
| `testPacketsPerformAsync_onPacketsQueue_runsInline` | Fast path ordering |

### 5.2 Accept path — `TFIPStackAcceptTests` (real SYN/ACK/ACK)

| Test | Asserts |
|------|---------|
| `testAccept_delegateInvokedOnConnectionsQueue` | Delegate on connections key, not packets |
| `testAccept_handlerYes_doesNotActivateUntilMarkActive` | Write closed until `markActive`; then activates |
| `testAccept_handlerNo_abortsAndTerminates` | Abort reason |
| `testAccept_handlerTwice_secondIgnored` | First NO wins; second YES ignored |
| `testAccept_handlerYes_thenMarkActive_firesOnActivatedOnce` | Idempotent `markActive` |
| `testAccept_withoutMarkActive_newStateTimeoutAborts` | Accelerated New timeout |
| `testAccept_hostDropsConnectionWithoutHandler_newRetainKeepsAliveUntilTimeout` | Drop without handler still timeout-reclaims |
| `testAccept_nilDelegate_abortsWithoutNotifying` | No delegate → no accept callback; stack stays healthy |

Helpers: `TFIPPacketTestHelpers`, `TFIPStackTestingListenPort`.

### 5.3 Connection public API

| Suite | Coverage |
|-------|----------|
| `+Lifecycle` | info/alive, markActive idempotent, gracefulClose/abort terminate, onActivated once, New timeout, callback queue affinity, gracefulClose clears pcb |
| `+Inbound` | gate, onReadable, onReadableBytes + completion, ACK noop/partial/over, double completion, recv err, FIN/EOF, inbound before active |
| `+WriteSend` | write before/after active, u16 overflow, shutdownWrite, writable hint |

### 5.4 Stack lifecycle — `TFIPStackLifecycleTests`

| Test | Asserts |
|------|---------|
| `testStopThenStart_restoresListener` | Listen port 0 after stop; non-zero after start |
| `testDoubleStart_isIdempotent` | Second start keeps a single functional listener |
| `testStopThenStart_acceptPathStillWorks` | Full handshake accept after restart |

---

## 6. How to run

```bash
swift test --filter 'TFGlobalScheduler|TFIPStackAccept|TFIPStackLifecycle|TFTCPConnectionPublicAPI'
```

Or the full package:

```bash
swift test
```

Note: `TFGlobalScheduler` / `TFIPStack` are process-global. Core tests configure once via `TFTCPConnectionTestEnvironment installOnce`. Lifecycle tests that `stop` **must** `start` again before returning so sibling suites keep a live stack.

---

## 7. Host integration checklist

1. Configure scheduler queues before touching the stack.
2. Implement `didAcceptNewTCPConnection:handler:` on `connectionsQueue` expectations.
3. Call `handler` exactly once; `YES` then `markActive` when upstream is ready; `NO` to reject.
4. Enable inbound with `setInboundDeliveryEnabled:YES` when ready to receive.
5. Prefer `onReadableBytes` + exactly-once completion + `acknowledgeDeliveredBytes:`.
6. Keep `OutboundHandler` non-blocking.
7. All mutating connection/stack APIs on `packetsQueue`.

---

## 8. References

- [`ARCHITECTURE.md`](./ARCHITECTURE.md) — living contract + TODO board
- [`README.md`](../README.md) — public integration notes
- [`CHANGELOG.md`](../CHANGELOG.md) — release notes
