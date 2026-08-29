# TunForge 契约与架构 TODO

> **角色**：TUN 用户态 TCP data plane core（lwIP raw API + ObjC 语义层）
> **公开定位**：低层 TCP 截获核心，不负责代理、路由、策略、DNS 或 UDP proxy
> **最后更新**：2026-08-29

---

## 1. 分层边界

```
Host / application layer
  Routing / policy / proxy / UDP handling
        │
        ▼
TunForge
  TunForge (Swift facade)
  TunForgeCore (neutral runtime + ObjC TCP semantic adapter)
  Lwip (C TCP/IP engine)
        │
        ▼
TUN device
```

| 层 | 责任 | 不拥有 |
|----|------|--------|
| `Lwip` | TCP/IP engine、pbuf、raw TCP callback | Objective-C lifecycle policy |
| `TunForgeCore` | `TunForgeLwIPRuntime` 的 init/netif/timer/raw I/O/serialization；`TFIPStack` + `TFTCPConnection` 的 TCP 生命周期和 backpressure | 代理协议、分流策略、socket、UDP session、tunnel state、DNS/FakeIP |
| `TunForge` | Swift-friendly aliases / convenience API | 新语义、新状态机 |
| Host | TUN I/O、executor 注入、代理/路由/策略、UDP 处理 | lwIP 内部状态 |

原则：`TunForgeCore` 是语义边界；Swift 层只能让调用更顺手，不能创造另一套生命周期模型。

---

## 2. 队列与并发契约

### `packetsQueue`

- 由 host 在首次使用 `TFGlobalScheduler` 前注入，之后冻结。
- 严格串行；所有 lwIP 访问、`TunForgeLwIPRuntime` / `TFIPStack` lifecycle 与 input、`TFTCPConnection` 状态修改都必须在此队列执行。
- `TF_ASSERT_ON_PACKETS_QUEUE()` 是契约断言，不是普通调试辅助。违反它代表调用方或内部 hop 设计错误。

### `connectionsQueue`

- 由 host 注入，用于 stack-level delegate hop。
- 当前主要承载 `TFIPStackDelegate.didAcceptNewTCPConnection(_:handler:)`。
- 不承载 `TFTCPConnection` property callbacks。

### per-connection callback queue

- 每个 `TFTCPConnection` 拥有一个专属串行 callback queue。
- 同一连接的 `onActivated` / `onReadable*` / `onWritableChanged` / `onSentBytes` / `onReadEOF` / `onTerminated` 保持顺序。
- 不同连接的 callback 可以并行执行。
- callback 内如需调用 mutating API，必须显式 hop 回 `packetsQueue`。

---

## 3. API 契约

### `TunForgeLwIPRuntime`

- 唯一职责是 process-global `lwip_init`、单 netif、timer、raw packet input/output 与串行 executor façade。
- `performSync` / `performAsync` 可从任意队列调用；`start` / `stop` / `inputPacket` 与 mutable property 必须在该串行域内调用，API 不自动 hop。
- 公开类型不暴露 `netif`、`pbuf`、PCB 等 lwIP C struct。
- runtime 不拥有 policy、socket、UDP session、tunnel state、DNS 或产品配置。
- lifecycle owner 必须唯一：使用兼容 `TFIPStack` 的 host 只能经 adapter 启停，不得独立启停底层 runtime。
- direct runtime start/stop 不安装 TCP listener；`TunForgeLwIPRuntimeTests` 覆盖 x10 重复启停与嵌套串行化。

### `TFIPStack`

- `TFIPStack` 是 neutral runtime 上的兼容 TCP adapter，不是可多实例化的 stack。
- `TFGlobalScheduler.configureWithPacketsQueue(_:connectionsQueue:)` 必须早于 `TunForgeLwIPRuntime.default()` / `TFIPStack.default()`。
- `start` / `stop` / `inputPacket` 必须在 `packetsQueue` 调用。
- `outboundHandler` 代理到 neutral runtime；runtime 从 lwIP output path 同步观察 pbuf 内容，并以 copied `Data`/`NSData` 交给 host；TunForge 不拥有 TUN 写入策略。
- `didAcceptNewTCPConnection` 的 handler 必须 exactly once。当前 `accept == false` 会 abort；`accept == true` 只表示 host 接收该对象，真正激活仍由 host 调 `markActive()` 完成。

### `TFTCPConnection`

- `alive` 只表示对象是否仍可安全访问；连接语义由内部 state 决定。
- `markActive()` 是唯一把 New 连接转为 Active 的入口，并触发 `tcp_backlog_accepted`。
- `setInboundDeliveryEnabled(_:)` 只控制 app-side inbound payload 是否交给上层；不能拿它表达 inflight backpressure。
- `onReadableBytes` 是主路径。handler 必须 exactly once 调用 completion 来释放 pbuf/slices；消费后必须在 `packetsQueue` 调 `acknowledgeDeliveredBytes(_:)` 归还 lwIP receive window。
- `onReadable` 是兼容路径，会 copy，并由内部自动 acknowledge。
- `writeBytes:length:` 要求 `0 < length <= UINT16_MAX`；超出是 programmer error。`writeData` 负责做长度保护。
- `shutdownWrite()` 只关闭 TunForge/lwIP send side，不推断 read side closure。
- `onReadEOF` 是 peer FIN 事件通知，不自动触发 full close。
- `gracefulClose()` 是显式 full close 请求；`abort()` 是强制 RST/abort。
- `onTerminated` 最多触发一次。

### Testing API

- `TFTCPConnectionTestingAPI.h` 与 `TFTCPConnectionTestingSupport.m` 只存在于
  `Tests/TunForgeCoreTests/` 并仅编入 test bundle，不是 supported public API。
- production `TunForgeCore` 不导出测试符号，也不为测试引入 lwIP private headers；test support
  只通过窄化的 private accessor 观察状态，并驱动真实 PCB 已注册的 receive / poll callback。

---

## 4. 集成边界

公开文档使用 generic host / embedding application 口径；具体产品集成细节只保留在本文件。

| 调用方 | API/契约 |
|--------|----------|
| Host TCP stack adapter | `TFIPStack.default()`, `inputPacket`, `outboundHandler`, accept delegate |
| Host flow/stream layer | `TFTCPConnection` read/write/EOF/termination callbacks |
| Host executor layer | 注入 `packetsQueue` / `connectionsQueue`，必要时映射到 SwiftNIO event loop |

数据流位置：DNS/FakeIP 与路由决策之后，host flow/proxy 之前。TunForge 不反向依赖上层产品。

---

## 5. 架构 TODO

### P0：契约收敛

- [x] **修复队列 specific key 绑定缺口**：`configureWithPacketsQueue:connectionsQueue:` 现在调用 `TFBindQueueSpecific` 绑定 packets/connections key，`tf_on_specific_queue()`、`TF_ASSERT_ON_PACKETS_QUEUE()` 与 `tf_perform_sync/async` 的“已在队列上”快路径恢复正常；新增 `TFGlobalSchedulerTests` 覆盖 key 绑定与同队列再次 sync 不死锁。
- [x] **统一 `OutboundHandler` 同步契约**：`TunForgeLwIPRuntime.h` 定义为“同步、运行在 serial lwIP output path，host 不得阻塞或做重活”；`TFIPStack` 保留兼容代理属性。
- [x] **accept handler exactly-once**：`tunforge_accept` 现在用 `packetsQueue` 上的 `handlerConsumed` 标志保证只生效一次，重复调用记录 warn 并忽略。
- [x] **统一 accept / `markActive()` 双阶段语义**：`handler(YES)` 定义为 ownership hand-off（不激活），`handler(NO)` reject/abort，真正激活由 `markActive()` 完成，未激活会在 New-state timeout 后 abort；`TFTCPAcceptHandler` / 协议注释 / `markActive` 注释 / README 已统一。
- [x] **New 态自持有 / accept drop 不泄漏 backlog**：`TFTCPConnection` 在 New 态通过 `acceptPhaseRetain` 自持有，直到 `markActive` / `terminate`；`tf_tcp_poll` 在 ObjC wrapper 已消失时 abort PCB。回归：`testAccept_hostDropsConnectionWithoutHandler_newRetainKeepsAliveUntilTimeout`。
- [x] **zero-copy completion once-guard**：`onReadableBytes` completion 重复调用会 warn 并忽略，避免 double `pbuf_free`。
- [x] 给所有 mutating public API 补齐“必须在 `packetsQueue` 调用”的头文件注释，明确 API 不会自动 hop，避免 Swift/host 侧误以为它们是线程安全入口。
- [x] 提取 opaque `TunForgeLwIPRuntime`：只拥有 init/netif/timer/raw I/O/serialization；`TFIPStack` 降为 TCP adapter 并保留兼容 API；direct runtime x10 start/stop 与 nested sync 有回归。
- [ ] 固化 zero-copy receive 契约文档：何时 `acknowledgeDeliveredBytes`、completion 与 ACK 顺序、欠 ACK 行为。
- [ ] 明确 `TFGlobalScheduler` 配置生命周期：配置一次、不可重配、测试/多 suite 场景如何隔离。
- [ ] **Release 构建队列亲和**：`TF_ASSERT_ON_PACKETS_QUEUE()` 目前仅 DEBUG 生效；需决定是否在 Release 保留 assert / 降级为日志。
- [x] **`gracefulClose` ESTABLISHED 路径**：close 成功路径先 `clearCallbackLocked` 再清空 `pcb`；回归 `testGracefulClose_clearsPCBPointer`。

### P1：测试与可验证性

- [x] 增加 `TFIPStack` accept-path 测试：delegate 在 `connectionsQueue`、handler exactly once、reject abort、accept 后必须 `markActive`、New-state timeout、host drop + retain（`TFIPStackAcceptTests`）。
- [x] 增加队列契约测试：connection callbacks 不在 `connectionsQueue`/`packetsQueue`；scheduler nested sync / async fast-path。
- [x] 增加 receive window 测试：partial ACK / over ACK clamp、double completion safe、inbound before `markActive` → `ERR_MEM`。
- [x] 拆清 Swift Testing 与 XCTest 混跑问题：两个 test target 均统一为 XCTest，
  `TunForgeCoreTests` 可稳定由 `swift test` 与独立 CI runner 执行。
- [x] 为 `TFIPStack.start/stop` 建回归测试：`TFIPStackLifecycleTests`（stop/start restore listener、double start idempotent、restart 后 accept）。
- [x] 增加 `inboundDisabled → enable` 后 lwIP `refused_data` 重试的集成测试：真实 `inputPacket` 路径验证首包保留、后续数据不追加、重新开启后首包交付及后续重传交付。

### P2：后续架构演进

- [ ] IPv6 支持评估：当前 core 文档和 `TFTCPConnectionInfo` 仍以 IPv4 字符串为主。
- [ ] zero-copy hardening：slice 生命周期断言、debug instrumentation、inflight ACK observability。
- [ ] pbuf pool pressure 策略：`inputPacket` 中已有 low-pool TODO，需要决定 drop/log/backpressure 机制。
- [ ] 公开文档与内部文档分层：README 保持 generic host wording，本文件保留 QuantumLink/host integration 细节。
- [ ] 视需要补一个 `CONTRACT.md` 或把本文件的契约章节升格为 public docs。
- [ ] callback property / `alive` 的跨队列数据竞争：handlers 为 `nonatomic, copy`，host 与 packetsQueue 并发改读仍是 C 内存模型 race。
- [x] `start` 重复调用：已 running 时 idempotent return，避免 timer 泄漏。

---

## 6. 已知非目标

- Full UDP proxy semantics
- Fragmented UDP reassembly
- DNS / FakeIP / routing policy
- SOCKS / HTTP / TLS 等应用层协议
- 业务统计、计费、策略引擎

这些由 host 或上层模块负责。

---

## 7. 链接

- [ARCHITECTURE-REVIEW-0.6](./ARCHITECTURE-REVIEW-0.6.md)
- [README](../README.md)
- [ROADMAP](../ROADMAP.md)
- [QuantumLink Architecture-Evolution](https://github.com/CoderQuinn/QuantumLink/blob/main/docs/Architecture-Evolution.md)
- [NetForge](https://github.com/CoderQuinn/NetForge)
