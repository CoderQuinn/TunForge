TFTCPConnection（A-route / lwIP-only credit）

TFTCPConnection 是 TunForge 中 lwIP → 上层 Flow 的 TCP 语义桥接对象。
它把 lwIP raw callbacks 封装为一个 线程隔离、可组合、具备“暂停接收 / 发送可写提示”语义 的连接抽象。

A-route 核心：
接收窗口 credit（tcp_recved）由 lwIP recv callback 内部直接完成；
上层只通过 setRecvEnabled 控制“是否允许 lwIP 继续投递 pbuf”（用 ERR_MEM 让 lwIP 重试）。

1. 设计目标

将 lwIP 回调驱动模型转换为上层可控的事件模型

明确区分：

accept ≠ established（上层必须显式 markActive()）

half-close ≠ full close（FIN 只表示读侧 EOF，不推导 close）

提供单一、可验证的背压信号：

receive-side：setRecvEnabled(false) 让 lwIP 暂停投递

send-side：writable 边沿提示（ERR_MEM / tcp_sent / poll）

在 pcb 生命周期之外提供 ObjC 侧 alive guard（避免 use-after-free）

不引入锁 / 抢占；所有 lwIP 操作严格在 packets queue

2. 连接视角（方向语义）

lwIP pcb 语义：

pcb->remote_*：对端（发起连接的一端）

pcb->local_* ：本端（被连接的一端）

TunForge 上层（Flow/Proxy）使用“连接方向语义”组织 key/info。
为避免误解，建议对外暴露使用 local/peer 或明确标注字段含义。

3. 生命周期模型
3.1 状态机（内部）

New → markActive() → Active → Closing → Closed

状态机仅用于内部行为约束

不直接暴露给上层

3.2 alive guard

alive == NO 表示 pcb 已不可再触碰：

tcp_err（pcb 已被 lwIP 释放）

tcp_ext_arg.destroy（可选）

本地主动 terminate / abort

之后任何 lwIP API 调用都应被拒绝。

4. accept ≠ established

lwIP accept 并不等于“可 I/O”。
上层 Flow 完成装配后必须显式调用：

markActive()

它将：

tcp_backlog_accepted(pcb)

触发 onBecameActive（一次）

5. 数据接收（Receive Path）
5.1 onReadable（copy + immediate tcp_recved）

当 lwIP 收到数据 pbuf：

若 recvEnabled == false：返回 ERR_MEM，不消费 pbuf，让 lwIP 稍后重试（暂停投递）

若允许接收：

copy 数据到 NSData

立刻 tcp_recved(pcb, tot)

free pbuf

异步触发 onReadable(conn, data)

这意味着：
上层 queue 只是 safety buffer，不控制 TCP window。
背压只通过 recvEnabled 控制“是否允许 lwIP 把数据交给上层”。

5.2 EOF / half-close（FIN）

当 p == NULL（对端 FIN）：

触发 onReadEOF

仅表示 读方向 EOF，不推导连接关闭

6. 数据发送（Send Path）
6.1 写入模型

writeData: 采用 copy-write

内部按 u16 分片调用 tcp_write + tcp_output

ERR_MEM 表示 sendbuf 满（事实背压），停止本次写入并更新 writable = NO

6.2 send-side backpressure（提示信号）

writable 是 sendbuf 边沿提示，不是严格 gate

来源：

ERR_MEM → writable = NO

tcp_sent / poll → writable 重新计算为 YES/NO

7. 关闭语义

shutdownWrite：发送 FIN，关闭写方向

gracefulClose：tcp_close，若 ERR_MEM 则 poll 重试

abort：强制中止（RST/abort）

8. TerminationReason（对外解释）

当前对外 reason：

Close / Reset / Abort / Destroyed

用于解释“为何结束”，不驱动状态机推导。

9. pcb 生命周期绑定（tcp_ext_arg，可选）

启用时通过 destroy callback：

lwIP 回收 pcb → alive=NO → Terminated(Destroyed)

防止 use-after-free / dangling pointer。

10. 线程与并发模型

所有 lwIP 操作：packets queue

所有上层回调：connectionsPerformAsync（delegate queue）

不使用锁

不允许跨队列直接触碰 pcb

12. 一句话总结（A-route）

TFTCPConnection 是一个“线程隔离、事件化”的 TCP 连接抽象：
接收窗口由 lwIP 内部维护，上层只控制‘是否允许投递’；发送侧提供 sendbuf 可写提示。
