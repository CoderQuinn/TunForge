//
//  IPStackCore.m
//  TunForge
//
//  Minimal lwIP bridge without ABC/stats.
//

#import "IPStackCore.h"
#import "TCPSocket.h"
#import "PacketBatcher.h"
#import <QuartzCore/QuartzCore.h>

// C bridge functions exposed from Swift in TunForge target
extern void TFLogInfo(const char *msg);
extern void TFLogDebug(const char *msg);
extern void TFLogError(const char *msg);
extern void TFLogWarning(const char *msg);
extern void TFLogVerbose(const char *msg);
#include "lwip/init.h"
#include "lwip/tcp.h"
#include "lwip/timeouts.h"
#include "lwip/netif.h"
#include <sys/socket.h>
#include <arpa/inet.h>

@interface IPStackCore ()

@property (nonatomic, strong) dispatch_queue_t processQueue;
@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic, assign) struct tcp_pcb *listenPcb;
@property (nonatomic, assign) struct netif *defaultInterface;
@property (nonatomic, strong) PacketBatcher *batcher;

// IPv4 overrides
@property (nonatomic, copy) NSString *configuredIP;
@property (nonatomic, copy) NSString *configuredNetmask;
@property (nonatomic, copy) NSString *configuredGateway;

@end

@interface IPStackNoOpBehavior : NSObject<IPStackBehavior>
@property (nonatomic, assign) BOOL lowLatency;
@end

@implementation IPStackCore

#pragma mark - C callbacks forward declarations
static err_t packetOutput(struct netif *netif, struct pbuf *p, const ip4_addr_t *ipaddr);
static err_t tcpAcceptCallback(void *arg, struct tcp_pcb *newpcb, err_t err);

#pragma mark - Lifecycle

- (instancetype)init
{
    if (self = [super init]) {
        self.processQueue = dispatch_queue_create("tun2socks.IPStackCore.queue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(self.processQueue, (__bridge const void *)(self.processQueue), (__bridge void *)(self.processQueue), NULL);
        self.batcher = [[PacketBatcher alloc] initWithStack:self];
        self.configuredIP = @"192.18.0.1";
        self.configuredNetmask = @"255.255.255.0";
        self.configuredGateway = @"192.168.0.1";
        self.behavior = [IPStackNoOpBehavior new];
        [self setup];
    }
    return self;
}

#pragma mark - Setup

- (void)configureIPv4WithIP:(NSString *)ipAddress netmask:(NSString *)netmask gw:(NSString *)gateway
{
    self.configuredIP = [ipAddress copy];
    self.configuredNetmask = [netmask copy];
    self.configuredGateway = [gateway copy];
}

- (void)setup
{
    lwip_init();

    static struct netif netif_instance;
    ip4_addr_t ipaddr, netmask, gw;
    const char *cfg_ip = [self.configuredIP UTF8String];
    const char *cfg_netmask = [self.configuredNetmask UTF8String];
    const char *cfg_gw = [self.configuredGateway UTF8String];
    struct in_addr addr, nm, g;
    if (cfg_ip && inet_aton(cfg_ip, &addr)) {
        IP4_ADDR(&ipaddr, (addr.s_addr) & 0xFF, (addr.s_addr >> 8) & 0xFF, (addr.s_addr >> 16) & 0xFF, (addr.s_addr >> 24) & 0xFF);
    } else {
        IP4_ADDR(&ipaddr, 192, 18, 0, 1);
    }
    if (cfg_netmask && inet_aton(cfg_netmask, &nm)) {
        IP4_ADDR(&netmask, (nm.s_addr) & 0xFF, (nm.s_addr >> 8) & 0xFF, (nm.s_addr >> 16) & 0xFF, (nm.s_addr >> 24) & 0xFF);
    } else {
        IP4_ADDR(&netmask, 255, 255, 255, 0);
    }
    if (cfg_gw && inet_aton(cfg_gw, &g)) {
        IP4_ADDR(&gw, (g.s_addr) & 0xFF, (g.s_addr >> 8) & 0xFF, (g.s_addr >> 16) & 0xFF, (g.s_addr >> 24) & 0xFF);
    } else {
        IP4_ADDR(&gw, 192, 168, 0, 1);
    }

    self.defaultInterface = netif_add(&netif_instance, &ipaddr, &netmask, &gw, NULL, NULL, ip_input);
    if (!self.defaultInterface) {
        TFLogError("[IPStack] Failed to initialize network interface");
        return;
    }
    self.defaultInterface->state = (__bridge void *)self;
    self.defaultInterface->output = packetOutput;
    netif_set_default(self.defaultInterface);
    netif_set_up(self.defaultInterface);
    netif_set_link_up(self.defaultInterface);

    self.listenPcb = tcp_new();
    if (!self.listenPcb) {
        TFLogError("[IPStack] Failed to create TCP PCB");
        return;
    }

    err_t err = tcp_bind(self.listenPcb, IP_ADDR_ANY, 0);
    if (err != ERR_OK) {
        char buf[128];
        snprintf(buf, sizeof(buf), "[IPStack] Failed to bind TCP PCB: %d", err);
        TFLogError(buf);
        tcp_close(self.listenPcb);
        self.listenPcb = NULL;
        return;
    }

    self.listenPcb = tcp_listen_with_backlog(self.listenPcb, TCP_DEFAULT_LISTEN_BACKLOG);
    if (!self.listenPcb) {
        TFLogError("[IPStack] Failed to set TCP PCB to listen state");
        return;
    }

    tcp_arg(self.listenPcb, (__bridge void *)self);
    tcp_accept(self.listenPcb, tcpAcceptCallback);

    TFLogInfo("[IPStack] Network stack initialized successfully");
}

#pragma mark - Timer

- (void)checkTimeouts { sys_check_timeouts(); }
- (void)restartTimeouts { sys_restart_timeouts(); }

- (void)suspendTimer
{
    if (self.timer != nil) {
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
}

- (void)resumeTimer
{
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.processQueue);
    uint64_t defaultInterval = 250; // tcp_tmr interval
    dispatch_source_set_timer(self.timer, DISPATCH_TIME_NOW, defaultInterval * NSEC_PER_MSEC, 1 * NSEC_PER_MSEC);
    __weak __typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.timer, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf checkTimeouts];
    });
    [self restartTimeouts];
    dispatch_resume(self.timer);
}

#pragma mark - Public entry

- (void)receivedPacket:(NSData *)packet
{
    [self assertOnProcessQueue];
    if (!packet || packet.length == 0) { return; }
    if (packet.length > UINT16_MAX) { return; }
    if (!self.defaultInterface) { return; }

    struct pbuf *packetBuffer = pbuf_alloc(PBUF_RAW, packet.length, PBUF_POOL);
    if (!packetBuffer) { return; }
    memcpy(packetBuffer->payload, packet.bytes, packet.length);

    err_t err = self.defaultInterface->input(packetBuffer, self.defaultInterface);
    if (err != ERR_OK) {
        pbuf_free(packetBuffer);
        return;
    }
    [self onPacketReceivedBytes:(uint32_t)packet.length];
}

- (void)triggerFlushForDiagnostics
{
    dispatch_async(self.processQueue, ^{
        [self flushPendingLocked];
    });
}

#pragma mark - Hooks default impl

- (uint32_t)recommendedBatchThreshold
{
    return (self.behavior != nil) ? [self.behavior recommendedBatchThreshold] : 0;
}

- (uint32_t)recommendedFlushIntervalMs
{
    return (self.behavior != nil) ? [self.behavior recommendedFlushIntervalMs] : 0;
}

- (BOOL)isLowLatencyModeEnabled
{
    return (self.behavior != nil) ? [self.behavior isLowLatencyModeEnabled] : NO;
}

- (void)setLowLatencyModeEnabled:(BOOL)enabled
{
    if (self.behavior != nil) {
        [self.behavior setLowLatencyModeEnabled:enabled];
    }
}

- (void)onPacketSentBytes:(uint32_t)bytes
{
    if (self.behavior != nil) {
        [self.behavior onPacketSentBytes:bytes];
    }
}

- (void)onBatchFlushedBytes:(uint32_t)bytes latency:(double)latency count:(NSUInteger)count
{
    if (self.behavior != nil) {
        [self.behavior onBatchFlushedBytes:bytes latency:latency count:count];
    }
}

- (void)onPacketReceivedBytes:(uint32_t)bytes
{
    if (self.behavior != nil) {
        [self.behavior onPacketReceivedBytes:bytes];
    }
}

#pragma mark - Internals

- (void)sendOutPacket:(struct pbuf *)pbuf
{
    if (!pbuf) { return; }
    uint16_t totalLength = pbuf->tot_len;
    uint8_t *bytes = (uint8_t *)malloc(sizeof(uint8_t) * totalLength);
    if (!bytes) { return; }
    pbuf_copy_partial(pbuf, bytes, totalLength, 0);
    NSData *packet = [[NSData alloc] initWithBytesNoCopy:bytes length:totalLength freeWhenDone:YES];
    if (self.outboundHandler != nil) {
        self.outboundHandler(packet, AF_INET);
    }
}

- (void)flushPendingLocked
{
    [self assertOnProcessQueue];
    if (self.batcher.pendingPackets.count == 0) {
        self.batcher.flushScheduled = NO;
        return;
    }
    NSArray *toFlush = nil; uint32_t bytesTotal = 0;
    [self.batcher drainPendingIntoArray:&toFlush bytes:&bytesTotal];
    CFTimeInterval start = CACurrentMediaTime();
    for (NSValue *val in toFlush) {
        struct pbuf *p = (struct pbuf *)val.pointerValue;
        [self sendOutPacket:p];
        pbuf_free(p);
    }
    double latency = CACurrentMediaTime() - start;
    [self onBatchFlushedBytes:bytesTotal latency:latency count:toFlush.count];
    self.batcher.flushScheduled = NO;
}

#pragma mark - Queue assertions

- (BOOL)isOnProcessQueue
{
    void *key = (__bridge void *)(self.processQueue);
    return dispatch_get_specific(key) == key;
}

- (void)assertOnProcessQueue
{
    dispatch_assert_queue(self.processQueue);
}

#pragma mark - tcp callbacks

- (err_t)didAcceptTcpPcb:(struct tcp_pcb *)pcb error:(err_t)err
{
    if (err != ERR_OK) { return err; }
    if (!pcb) { return ERR_ARG; }
    tcp_backlog_accepted(pcb);
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(didAcceptTCPSocket:)]) {
        TCPSocket *socket = [[TCPSocket alloc] initWithTCPPcb:pcb queue:self.processQueue];
        if (!socket) {
            tcp_abort(pcb);
            return ERR_ABRT;
        }
        [self.delegate didAcceptTCPSocket:socket];
    } else {
        tcp_abort(pcb);
        return ERR_ABRT;
    }
    return ERR_OK;
}

static err_t tcpAcceptCallback(void *arg, struct tcp_pcb *newpcb, err_t err)
{
    IPStackCore *stack = (__bridge IPStackCore *)arg;
    return [stack didAcceptTcpPcb:newpcb error:err];
}

static err_t packetOutput(struct netif *netif, struct pbuf *p, const ip4_addr_t *ipaddr)
{
    if (!p) { return ERR_ARG; }
    IPStackCore *stack = (__bridge IPStackCore *)(netif->state);
    if (stack == nil) { return ERR_ARG; }
    uint32_t bytes = p->tot_len;
    pbuf_ref(p);
    dispatch_async(stack.processQueue, ^{
        [stack onPacketSentBytes:bytes];
        [stack.batcher enqueuePbuf:p bytes:bytes];
        uint32_t ms = [stack recommendedFlushIntervalMs];
        if (!stack.batcher.flushScheduled) {
            [stack.batcher scheduleFlushOnQueue:stack.processQueue afterMs:ms];
        }
    });
    return ERR_OK;
}

@end

@implementation IPStackNoOpBehavior
- (uint32_t)recommendedBatchThreshold { return 0; }
- (uint32_t)recommendedFlushIntervalMs { return 0; }
- (BOOL)isLowLatencyModeEnabled { return self.lowLatency; }
- (void)setLowLatencyModeEnabled:(BOOL)enabled { self.lowLatency = enabled; }
- (void)onPacketSentBytes:(uint32_t)bytes { (void)bytes; }
- (void)onBatchFlushedBytes:(uint32_t)bytes latency:(double)latency count:(NSUInteger)count { (void)bytes; (void)latency; (void)count; }
- (void)onPacketReceivedBytes:(uint32_t)bytes { (void)bytes; }
@end
