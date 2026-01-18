//
//  TFTCPConnection.m
//  TunForge
//
//  Created by MagicianQuinn on 2026/1/1.
//
//

/*
 *
 * Rule 1:
 * `alive` is used only to determine whether the object can still be accessed safely.
 *
 * Rule 2:
 * `state` is used only to determine which actions are permitted in the current phase.
 *
 * Rule 3:
 * When `alive == NO`, `state` has no semantic meaning.
 *
 * Rule 4:
 * `TCPConnection` does not infer closure from read/write/FIN/EOF events.
 *
 */

#import "TFTCPConnection.h"
#import "TFGlobalScheduler.h"
#import "TFObjectRef.h"
#import "TFQueueHelpers.h"
#import "TFTCPConnectionInfo.h"
#import "TFTunForgeLog.h"
#import "TFWeakifyStrongify.h"

#import "lwip/err.h"
#import "lwip/pbuf.h"
#import "lwip/tcp.h"

#import <arpa/inet.h>
#import <netinet/in.h>

#pragma mark - Helpers

static inline NSString *tf_ipv4_to_string(uint32 addr_network_order) {
    struct in_addr addr;
    addr.s_addr = addr_network_order;
    const char *cStr = inet_ntoa(addr);
    return cStr ? [NSString stringWithUTF8String:cStr] : @"0.0.0.0";
}

static inline u16_t tf_tcp_min_write_ready_bytes(const struct tcp_pcb *pcb) {
    // Pure hint. Keep it small to avoid "stuck writable==NO" under small sndbuf.
    // Prefer ">= 2 * mss" rather than 4*mss (4*mss can be too strict for small pipes).
    if (!pcb)
        return 0;
    u16_t mss = pcb->mss;
    if (mss == 0)
        mss = TCP_MSS; // fallback
    return (u16_t)(2 * mss);
}

static inline BOOL tf_tcp_write_ready(struct tcp_pcb *pcb) {
    if (!pcb)
        return NO;
#ifdef TCP_SNDLOWAT
    return tcp_sndbuf(pcb) >= TCP_SNDLOWAT;
#else
    return tcp_sndbuf(pcb) >= tf_tcp_min_write_ready_bytes(pcb);
#endif
}


#pragma mark - LwIP raw declarations

static err_t tf_tcp_recv(void *arg, struct tcp_pcb *pcb, struct pbuf *p, err_t err);
static err_t tf_tcp_sent(void *arg, struct tcp_pcb *pcb, u16_t len);
static err_t tf_tcp_poll(void *arg, struct tcp_pcb *pcb);
static void tf_tcp_err(void *arg, err_t err);

#if LWIP_TCP_PCB_NUM_EXT_ARGS
static void tf_tcp_extarg_destroy(u8_t ID, void *arg);
static const struct tcp_ext_arg_callbacks tf_tcp_extarg_cbs;
#endif

#pragma mark - TFTCPConnection()

typedef NS_ENUM(NSInteger, TFTCPConnectionState) {
    TFTCPConnectionNew = 0, // accepted from lwIP but not established to backlog yet
    TFTCPConnectionActive,
    TFTCPConnectionClosing,
    TFTCPConnectionClosed
};

@interface TFTCPConnection ()

@property (nonatomic, assign) struct tcp_pcb *pcb;
@property (nonatomic, strong) TFObjectRef *pcbRef;

@property (nonatomic, assign) BOOL alive;
@property (nonatomic, assign) BOOL writable;

@property (nonatomic, assign) BOOL readEOFFlag;  // peer FIN observed (p == NULL)
@property (nonatomic, assign) BOOL writeFINFlag; // local shutdownWrite called

@property (nonatomic, assign) TFTCPConnectionState state;
@property (nonatomic, assign) TFTCPConnectionTerminationReason terminationReason;

@property (nonatomic, assign) BOOL didNotifyActive;
@property (nonatomic, assign) BOOL didNotifyTerminated;

@property (nonatomic, assign) BOOL pendingClose;
@property (nonatomic, assign) BOOL recvEnabled;

@end

@implementation TFTCPConnection

- (instancetype)init {
    NSAssert(NO, @"Use initWithTCPPcb:");
    return nil;
}

- (instancetype)initWithTCPPcb:(struct tcp_pcb *)pcb {
    NSParameterAssert(pcb);
    if (self = [super init]) {
        _pcb = pcb;
        _alive = YES;
        _writable = NO;
        _didNotifyActive = NO;
        _didNotifyTerminated = NO;
        _terminationReason = TFTCPConnectionTerminationReasonNone;
        _state = TFTCPConnectionNew;
        _pendingClose = NO;
        _recvEnabled = NO;

        NSString *localIP = nil;
        NSString *remoteIP = nil;
#if LWIP_IPV4
        localIP = tf_ipv4_to_string(pcb->remote_ip.addr);
        remoteIP = tf_ipv4_to_string(pcb->local_ip.addr);
#endif
        localIP = localIP ?: @"0.0.0.0";
        remoteIP = remoteIP ?: @"0.0.0.0";
        UInt16 localPort = pcb->remote_port;
        UInt16 remotePort = pcb->local_port;

        _info = [[TFTCPConnectionInfo alloc] initWithSrcIP:localIP
                                                   srcPort:localPort
                                                     dstIP:remoteIP
                                                   dstPort:remotePort];

        [self setupPcb];
    }
    return self;
}

#pragma mark - Setup

- (void)setupPcb {
    TF_ASSERT_ON_PACKETS_QUEUE();
    struct tcp_pcb *pcb = self.pcb;
    if (!pcb)
        return;

    self.pcbRef = [[TFObjectRef alloc] initWithObject:self];
    void *arg = [self.pcbRef retainedVoidPointer];

    tcp_arg(pcb, (__bridge void *)self.pcbRef);
    tcp_recv(pcb, tf_tcp_recv);
    tcp_sent(pcb, tf_tcp_sent);
    tcp_poll(pcb, tf_tcp_poll, 2);
    tcp_err(pcb, tf_tcp_err);

#if LWIP_TCP_PCB_NUM_EXT_ARGS
    tcp_ext_arg_set_callbacks(pcb, TUNFORGE_TCP_EXTARG_ID, &tf_tcp_extarg_cbs);
    tcp_ext_arg_set(pcb, TUNFORGE_TCP_EXTARG_ID, arg);
#endif
}

#pragma mark - Public

- (void)markActive {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (!self.alive || !self.pcb)
        return;
    if (self.state != TFTCPConnectionNew)
        return;

    self.state = TFTCPConnectionActive;

    tcp_backlog_accepted(self.pcb);

    [TFTunForgeLog info:@"TCP connection established"];
    [self notifyActiveOnceLocked];
}

- (void)setReceiveEnabled:(BOOL)enabled {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (_recvEnabled == enabled)
        return;
    _recvEnabled = enabled;
}

//// Precise ACK to lwIP (recv window credit)
- (void)creditReceiveWindow:(NSUInteger)bytes {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (bytes == 0)
        return;

    if (!self.alive || !self.pcb)
        return;

    if (self.state != TFTCPConnectionActive)
        return;
    
    // Safety: lwIP tcp_recved takes u16_t
    while (bytes > 0) {
        u16_t chunk = (u16_t)MIN(bytes, (NSUInteger)UINT16_MAX);
        tcp_recved(self.pcb, chunk);

        bytes -= chunk;
    }
}

- (TFTCPWriteResult)writeBytes:(const void *)bytes length:(NSUInteger)length {
    TF_ASSERT_ON_PACKETS_QUEUE();

    // Contract: caller MUST ensure length <= UINT16_MAX
    if (!bytes || length == 0) {
        return (TFTCPWriteResult){.written = 0, .status = TFTCPWriteOK};
    }

    if (length > UINT16_MAX) {
        // Programming error, not runtime backpressure
        [TFTunForgeLog error:@"writeBytes length exceeds UINT16_MAX; truncate"];
        assert(0 && "writeBytes length exceeds u16 limit");
        length = UINT16_MAX; // defensive in release
    }

    if (!self.alive || !self.pcb || self.state != TFTCPConnectionActive || self.writeFINFlag) {
        return (TFTCPWriteResult){.written = 0, .status = TFTCPWriteClosed};
    }

    err_t err = tcp_write(self.pcb, bytes, (u16_t)length, TCP_WRITE_FLAG_COPY);

    if (err == ERR_OK) {
        tcp_output(self.pcb);
        [self updateWritableLocked:tf_tcp_write_ready(self.pcb)];
        return (TFTCPWriteResult){.written = length, .status = TFTCPWriteOK};
    }

    if (err == ERR_MEM) {
        [self updateWritableLocked:NO];
        return (TFTCPWriteResult){.written = 0, .status = TFTCPWriteWouldBlock};
    }

    // Other errors are fatal
    [self abortLocked:TFTCPConnectionTerminationReasonAbort];
    return (TFTCPWriteResult){.written = 0, .status = TFTCPWriteError};
}

- (TFTCPWriteResult)writeData:(NSData *)data {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (data.length > UINT16_MAX) {
        [TFTunForgeLog warn:@"writeData length exceeds UINT16_MAX; reject send"];
        return (TFTCPWriteResult){.written = 0, .status = TFTCPWriteError};
    }
    return [self writeBytes:data.bytes length:data.length];
}

- (void)shutdownWrite {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (!self.alive || !self.pcb)
        return;
    if (self.state == TFTCPConnectionClosed)
        return;

    if (self.writeFINFlag)
        return;
    self.writeFINFlag = YES;

    [TFTunForgeLog info:@"TCP shutdownWrite (FIN)"];

#if LWIP_TCP
    // Shut TX only.
    tcp_shutdown(self.pcb, 0, 1);
    tcp_output(self.pcb);
#endif
}

- (void)gracefulClose {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (!self.alive)
        return;
    if (!self.pcb) {
        [self terminateLocked:TFTCPConnectionTerminationReasonClose];
        return;
    }

    [TFTunForgeLog info:@"TCP gracefulClose requested"];
    [self tryGracefulCloseLocked];
}

- (void)abort {
    TF_ASSERT_ON_PACKETS_QUEUE();

    [self abortLocked:TFTCPConnectionTerminationReasonAbort];
}

#pragma mark - Private

- (void)tryGracefulCloseLocked {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (!self.alive)
        return;
    if (!self.pcb) {
        [self terminateLocked:TFTCPConnectionTerminationReasonClose];
        return;
    }
    if (self.state == TFTCPConnectionClosed)
        return;

    self.state = TFTCPConnectionClosing;

    err_t err = tcp_close(self.pcb);
    switch (err) {
    case ERR_OK:
        // After tcp_close, pcb may be freed by lwIP; never touch it again.
        self.pcb = NULL;
        self.pendingClose = NO;
        [self terminateLocked:TFTCPConnectionTerminationReasonClose];
        break;

    case ERR_MEM:
        // lwIP couldn't close now (unsent data). Retry in poll.
        self.pendingClose = YES;
        break;

    default:
        [self abortLocked:TFTCPConnectionTerminationReasonAbort];
        break;
    }
}

- (void)abortLocked:(TFTCPConnectionTerminationReason)reason {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (!self.alive)
        return;
    if (self.state == TFTCPConnectionClosed)
        return;

    self.state = TFTCPConnectionClosing;
    [TFTunForgeLog warn:@"TCP connection aborted"];

    if (self.pcb) {
        [self clearCallbackLocked];

        struct tcp_pcb *pcb = self.pcb;
        self.pcb = NULL;
        tcp_abort(pcb);
    }

    [self terminateLocked:reason];
}

- (void)handlerReadEOFLocked {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (self.readEOFFlag)
        return;
    self.readEOFFlag = YES;

    [TFTunForgeLog info:@"TCP recv FIN (EOF)"];

    TFTCPReadEOFHandler onReadEOFCopy = self.onReadEOF;
    if (!onReadEOFCopy)
        return;

    weakify(self);
    [TFGlobalScheduler.shared connectionsPerformAsync:^{
        strongify(self);
        if (!self || !self.alive)
            return;

        if (onReadEOFCopy)
            onReadEOFCopy(self);
    }];
}

- (void)terminateLocked:(TFTCPConnectionTerminationReason)reason {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (self.didNotifyTerminated)
        return;
    self.didNotifyTerminated = YES;

    // Always detach callbacks to avoid any future lwIP invocation into stale arg.
    if (self.pcb) {
        [self clearCallbackLocked];
    }

    self.alive = NO;
    self.state = TFTCPConnectionClosed;
    self.terminationReason = reason;
    self.pendingClose = NO;

    [TFTunForgeLog info:[NSString stringWithFormat:@"TCP terminated, reason=%ld", (long)reason]];

    TFTCPTerminatedHandler onTerminatedCopy = self.onTerminated;
    if (!onTerminatedCopy)
        return;

    weakify(self);
    [TFGlobalScheduler.shared connectionsPerformAsync:^{
        strongify(self);
        if (!self) {
            return;
        }

        if (onTerminatedCopy)
            onTerminatedCopy(self, reason);
    }];
}

#pragma mark - Internal helpers

- (void)clearCallbackLocked {
    TF_ASSERT_ON_PACKETS_QUEUE();

    struct tcp_pcb *pcb = self.pcb;
    if (pcb) {
        tcp_arg(pcb, NULL);
        tcp_recv(pcb, NULL);
        tcp_sent(pcb, NULL);
        tcp_poll(pcb, NULL, 0);
        tcp_err(pcb, NULL);

    }

    if (self.pcbRef) {
        [self.pcbRef invalidate];
    }
}

- (void)notifyActiveOnceLocked {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (self.didNotifyActive)
        return;
    self.didNotifyActive = YES;

    TFTCPBecameActiveHandler onBecameActiveCopy = self.onBecameActive;
    if (!onBecameActiveCopy)
        return;

    weakify(self);
    [TFGlobalScheduler.shared connectionsPerformAsync:^{
        strongify(self);
        if (!self || !self.alive)
            return;

        if (onBecameActiveCopy)
            onBecameActiveCopy(self);
    }];
}

- (void)updateWritableLocked:(BOOL)newValue {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (self.writable == newValue)
        return;
    self.writable = newValue;

    TFTCPWritableChangedHandler onWritableChangedCopy = self.onWritableChanged;
    if (!onWritableChangedCopy)
        return;

    weakify(self);
    [TFGlobalScheduler.shared connectionsPerformAsync:^{
        strongify(self);
        if (!self || !self.alive)
            return;

        if (onWritableChangedCopy)
            onWritableChangedCopy(self, newValue);
    }];
}

#pragma mark - Alive guard via tcp_ext_arg (optional)

#if LWIP_TCP_PCB_NUM_EXT_ARGS

- (void)receivedPcbDestroyed {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (self.didNotifyTerminated)
        return;

    // pcb already destroyed by lwIP
    self.pcb = NULL;
    [self terminateLocked:TFTCPConnectionTerminationReasonDestroyed];
}

static void tf_tcp_extarg_destroy(u8_t ID, void *arg) {
    TF_ASSERT_ON_PACKETS_QUEUE();
    LWIP_UNUSED_ARG(ID);

    if (!arg)
        return;

    TFObjectRef *ref = (__bridge TFObjectRef *)arg;
    if (!ref)
        return;

    NSObject *obj = ref.object;
    [ref invalidate];

    if ([obj isKindOfClass:[TFTCPConnection class]]) {
        [(TFTCPConnection *)obj receivedPcbDestroyed];
    }

    TFObjectRefRelease(arg);
}

static const struct tcp_ext_arg_callbacks tf_tcp_extarg_cbs = {.destroy = tf_tcp_extarg_destroy};

#endif

#pragma mark - lwIP raw callbacks

static inline TFTCPConnection *tf_conn_from_arg(void *arg) {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (!arg)
        return nil;
    if (![(__bridge id)arg isKindOfClass:[TFObjectRef class]])
        return nil;

    TFObjectRef *ref = (__bridge TFObjectRef *)arg;
    if (!ref.alive)
        return nil;

    id obj = ref.object;
    if (!obj || ![obj isKindOfClass:[TFTCPConnection class]])
        return nil;

    return (TFTCPConnection *)obj;
}

static err_t tf_tcp_recv(void *arg, struct tcp_pcb *pcb, struct pbuf *p, err_t err) {
    TF_ASSERT_ON_PACKETS_QUEUE();

    TFTCPConnection *conn = tf_conn_from_arg(arg);
    if (!conn || !conn.alive) {
        if (p)
            pbuf_free(p);
        return ERR_OK;
    }

    if (err != ERR_OK) {
        if (p)
            pbuf_free(p);
        [TFTunForgeLog warn:[NSString stringWithFormat:@"tcp_recv err=%d", (int)err]];
        [conn abortLocked:TFTCPConnectionTerminationReasonAbort];
        return ERR_OK;
    }

    if (p == NULL) {
        // Peer FIN observed: event only (Rule 4: do not infer close).
        [conn handlerReadEOFLocked];
        return ERR_OK;
    }

    const u16_t tot = p->tot_len;
    if (tot == 0) {
        pbuf_free(p);
        return ERR_OK;
    }

    // Backpressure: refuse delivery WITHOUT freeing pbuf.
    // lwIP will retry later when recvEnabled becomes true.
    if (!conn.recvEnabled) {
        return ERR_MEM;
    }

    // IMPORTANT:
    // Do NOT call tcp_recved here.
    // Upper layer calls -creditReceiveWindow: after it has copied/enqueued bytes.

    TFTCPReadableBytesBatchHandler onReadableBytesCopy = conn.onReadableBytes;
    if (onReadableBytesCopy) {
        NSUInteger sliceCnt = 0;
        for (struct pbuf *q = p; q; q = q->next) {
            sliceCnt++;
        }

        TFBytesSlice *slices = (TFBytesSlice *)malloc(sizeof(TFBytesSlice) * sliceCnt);
        if (!slices) {
            // fallback: drop safely
            pbuf_free(p);
            return ERR_OK;
        }

        struct pbuf *q = p;
        for (NSUInteger i = 0; i < sliceCnt; i++) {
            slices[i].bytes = q->payload;
            slices[i].length = q->len;
            q = q->next;
        }

        weakify(conn);
        [TFGlobalScheduler.shared connectionsPerformAsync:^{
            strongify(conn);
            if (!conn || !conn.alive || !onReadableBytesCopy) {
                // must free even if handler gone
                [TFGlobalScheduler.shared packetsPerformAsync:^{
                    free(slices);
                    pbuf_free(p);
                }];
                return;
            }

            onReadableBytesCopy(conn, slices, sliceCnt, tot, ^{
                [TFGlobalScheduler.shared packetsPerformAsync:^{
                    free(slices);
                    pbuf_free(p);
                }];
            });
        }];

        return ERR_OK;
    } else if (conn.onReadable) {
        // Copy bytes out first.
        void *buf = malloc(tot);
        if (!buf) {
            pbuf_free(p);
            return ERR_OK;
        }

        pbuf_copy_partial(p, buf, tot, 0);
        NSData *data = [[NSData alloc] initWithBytesNoCopy:buf length:tot freeWhenDone:YES];

        TFTCPReadableHandler onReadableCopy = conn.onReadable;
        weakify(conn);
        [TFGlobalScheduler.shared connectionsPerformAsync:^{
            strongify(conn);
            if (!conn || !conn.alive)
                return;

            if (onReadableCopy)
                onReadableCopy(conn, data);
        }];
    }

    pbuf_free(p);
    return ERR_OK;
}

static err_t tf_tcp_sent(void *arg, struct tcp_pcb *pcb, u16_t len) {
    TF_ASSERT_ON_PACKETS_QUEUE();

    TFTCPConnection *conn = tf_conn_from_arg(arg);
    if (!conn || !conn.alive)
        return ERR_OK;

    // Observer-only hint
    [conn updateWritableLocked:tf_tcp_write_ready(pcb)];

    TFTCPSentBytesHandler onSentBytesCopy = conn.onSentBytes;
    if (onSentBytesCopy) {
        weakify(conn);
        [TFGlobalScheduler.shared connectionsPerformAsync:^{
            strongify(conn);
            if (!conn || !conn.alive)
                return;

            if (onSentBytesCopy)
                onSentBytesCopy(conn, len);
        }];
    }

    return ERR_OK;
}

static err_t tf_tcp_poll(void *arg, struct tcp_pcb *pcb) {
    TF_ASSERT_ON_PACKETS_QUEUE();

    TFTCPConnection *conn = tf_conn_from_arg(arg);
    if (!conn || !conn.alive)
        return ERR_OK;

    // Optional observer-only hint
    [conn updateWritableLocked:tf_tcp_write_ready(pcb)];

    // Close retry (only if user requested graceful close and lwIP deferred it)
    if (conn.pendingClose && conn.pcb == pcb) {
        [conn tryGracefulCloseLocked];
    }

    return ERR_OK;
}

static void tf_tcp_err(void *arg, err_t err) {
    TF_ASSERT_ON_PACKETS_QUEUE();

    TFTCPConnection *conn = tf_conn_from_arg(arg);
    if (!conn || !conn.alive)
        return;

    // pcb is already invalid/free at this point.
    conn.pcb = NULL;

    TFTCPConnectionTerminationReason reason = (err == ERR_RST)
                                                  ? TFTCPConnectionTerminationReasonReset
                                                  : TFTCPConnectionTerminationReasonAbort;

    const char *errStr = lwip_strerr(err);
    [TFTunForgeLog warn:[NSString stringWithFormat:@"tcp_err err=%d (%s)",
                                                      (int)err,
                                                      errStr ? errStr : "?"]];
    [conn terminateLocked:reason];
}

@end
