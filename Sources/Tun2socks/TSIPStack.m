//
//  TSIPStack.m
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/15.
//

#import "TSIPStack.h"
#import "TSTCPSocket.h"
#import "TFLog.h"
#include "lwip/init.h"
#include "lwip/tcp.h"
#include "lwip/timeouts.h"
#include "lwip/netif.h"
#include <arpa/inet.h>

@interface TSIPStack ()

// Serial queue for processing all IP stack events
@property (nonatomic, strong) dispatch_queue_t processQueue;
// Timer for lwIP timeouts
@property (nonatomic, strong) dispatch_source_t timer;
// TCP PCB for listening
@property (nonatomic, assign) struct tcp_pcb *listenPcb;
// Default network interface
@property (nonatomic, assign) struct netif *defaultInterface;

// IPv4 configuration
@property (nonatomic, copy) NSString *configuredIP;
@property (nonatomic, copy) NSString *configuredNetmask;
@property (nonatomic, copy) NSString *configuredGateway;

@end

@implementation TSIPStack

static TSIPStack *_sharedInstance = nil;

#pragma mark - Singleton

+ (instancetype)defaultIPStack {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[TSIPStack alloc] initPrivate];
    });
    return _sharedInstance;
}

- (instancetype)initPrivate {
    if (self = [super init]) {
        self.processQueue = dispatch_queue_create("tun2socks.IPStack.queue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(self.processQueue, (__bridge const void *)(self.processQueue), (__bridge void *)(self.processQueue), NULL);

        self.configuredIP = @"192.168.0.1";
        self.configuredNetmask = @"255.255.0.0";
        self.configuredGateway = @"192.168.0.254";

        [self setup];
    }
    return self;
}

- (instancetype)init {
    NSAssert(NO, @"❌ Use +[TSIPStack defaultIPStack] instead of init");
    return nil;
}


- (void)configureIPv4WithIP:(NSString *)ipAddress netmask:(NSString *)netmask gw:(NSString *)gateway {
    self.configuredIP = [ipAddress copy];
    self.configuredNetmask = [netmask copy];
    self.configuredGateway = [gateway copy];
}

#pragma mark - lwIP Setup

- (void)setup {
    lwip_init();
    static struct netif netif_instance;
    ip4_addr_t ipaddr, netmask, gw;

    // Convert string IP addresses to ip4_addr_t
    const char *cfg_ip = [self.configuredIP UTF8String];
    const char *cfg_netmask = [self.configuredNetmask UTF8String];
    const char *cfg_gw = [self.configuredGateway UTF8String];
    struct in_addr addr, nm, g;

    if (cfg_ip && inet_aton(cfg_ip, &addr)) {
        IP4_ADDR(&ipaddr, (addr.s_addr)&0xFF, (addr.s_addr>>8)&0xFF, (addr.s_addr>>16)&0xFF, (addr.s_addr>>24)&0xFF);
    } else {
        IP4_ADDR(&ipaddr, 192,168,0,1);
    }

    if (cfg_netmask && inet_aton(cfg_netmask, &nm)) {
        IP4_ADDR(&netmask, (nm.s_addr)&0xFF, (nm.s_addr>>8)&0xFF, (nm.s_addr>>16)&0xFF, (nm.s_addr>>24)&0xFF);
    } else {
        IP4_ADDR(&netmask, 255,255,0,0);
    }

    if (cfg_gw && inet_aton(cfg_gw, &g)) {
        IP4_ADDR(&gw, (g.s_addr)&0xFF, (g.s_addr>>8)&0xFF, (g.s_addr>>16)&0xFF, (g.s_addr>>24)&0xFF);
    } else {
        IP4_ADDR(&gw, 192,168,0,254);
    }

    // Add default network interface
    self.defaultInterface = netif_add(&netif_instance, &ipaddr, &netmask, &gw, NULL, NULL, ip_input);
    if (!self.defaultInterface) {
        TFLogModuleError(@"TSIPStack", @"Failed to initialize network interface");
        return;
    }
    self.defaultInterface->state = (__bridge void *)self;
    self.defaultInterface->output = packetOutput;
    netif_set_default(self.defaultInterface);
    netif_set_up(self.defaultInterface);
    netif_set_link_up(self.defaultInterface);

    // Create listening PCB
    self.listenPcb = tcp_new();
    if (!self.listenPcb) {
        TFLogModuleError(@"TSIPStack", @"Failed to create TCP PCB");
        return;
    }

    err_t err = tcp_bind(self.listenPcb, IP_ADDR_ANY, 0);
    if (err != ERR_OK) {
        TFLogModuleError(@"TSIPStack", @"TCP PCB bind failed: %d", err);
        tcp_close(self.listenPcb);
        self.listenPcb = NULL;
        return;
    }

    self.listenPcb = tcp_listen_with_backlog(self.listenPcb, TCP_DEFAULT_LISTEN_BACKLOG);
    if (!self.listenPcb) {
        TFLogModuleError(@"TSIPStack", @"TCP PCB listen failed");
        return;
    }

    tcp_arg(self.listenPcb, (__bridge void *)self);
    tcp_accept(self.listenPcb, tcpAcceptCallback);

    TFLogModuleInfo(@"TSIPStack", @"Network stack initialized, virtual network: %@/%@", self.configuredIP, self.configuredNetmask);
}

#pragma mark - Timer

- (void)checkTimeouts {
    sys_check_timeouts();
}

- (void)restartTimeouts {
    sys_restart_timeouts();
}

- (void)suspendTimer {
    if (self.timer) {
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
}

- (void)resumeTimer {
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.processQueue);
#ifdef TCP_TMR_INTERVAL
    uint64_t defaultInterval = TCP_TMR_INTERVAL; // tcp_tmr interval
#else
    uint64_t defaultInterval = 250
#endif
    uint64_t interval = 250; // Default tcp_tmr_interval in ms
    dispatch_source_set_timer(self.timer, DISPATCH_TIME_NOW, interval * NSEC_PER_MSEC, 1 * NSEC_PER_MSEC);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.timer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf checkTimeouts];
    });
    [self restartTimeouts];
    dispatch_resume(self.timer);
}

#pragma mark - Packet Reception

- (void)receivedPacket:(NSData *)packet {
    [self assertOnProcessQueue];
    if (!packet || packet.length == 0) return;
    if (packet.length > UINT16_MAX) return;
    if (!self.defaultInterface) return;

    struct pbuf *pbufPacket = pbuf_alloc(PBUF_RAW, packet.length, PBUF_POOL);
    if (!pbufPacket) {
        TFLogModuleError(@"TSIPStack", @"pbuf_alloc failed for %lu bytes", (unsigned long)packet.length);
        return;
    }
    memcpy(pbufPacket->payload, packet.bytes, packet.length);

    err_t err = self.defaultInterface->input(pbufPacket, self.defaultInterface);
    if (err != ERR_OK) { pbuf_free(pbufPacket); }
}

#pragma mark - Queue Assertion

- (BOOL)isOnProcessQueue {
    void *key = (__bridge void *)self.processQueue;
    return dispatch_get_specific(key) == key;
}

- (void)assertOnProcessQueue {
    dispatch_assert_queue(self.processQueue);
}

#pragma mark - TCP Accept Handling

- (err_t)didAcceptTcpPcb:(struct tcp_pcb *)pcb error:(err_t)err {
    if (err != ERR_OK || !pcb) return ERR_ARG;
    tcp_backlog_accepted(pcb);

    if (self.delegate && [self.delegate respondsToSelector:@selector(didAcceptTCPSocket:)]) {
        TSTCPSocket *socket = [[TSTCPSocket alloc] initWithTCPPcb:pcb queue:self.processQueue];
        // TODO: set delegate and delegateQueue
        if (!socket) { tcp_abort(pcb); return ERR_ABRT; }
        dispatch_async(self.delegateQueue ?: dispatch_get_main_queue(), ^{
            [self.delegate didAcceptTCPSocket:socket];
        });
    } else {
        tcp_abort(pcb);
        return ERR_ABRT;
    }
    return ERR_OK;
}

static err_t tcpAcceptCallback(void *arg, struct tcp_pcb *newpcb, err_t err) {
    TSIPStack *stack = (__bridge TSIPStack *)arg;
    return [stack didAcceptTcpPcb:newpcb error:err];
}

#pragma mark - Packet Output

static err_t packetOutput(struct netif *netif, struct pbuf *p, const ip4_addr_t *ipaddr) {
    if (!p)
        return ERR_ARG;
    
    TSIPStack *stack = (__bridge TSIPStack *)(netif->state);
    if (!stack)
        return ERR_ARG;

    dispatch_async(stack.processQueue, ^{
        [stack sendOutPacket:p];
        pbuf_free(p);
    });
    return ERR_OK;
}

- (void)sendOutPacket:(struct pbuf *)pbuf {
    [self assertOnProcessQueue];
    if (!pbuf)
        return;

    uint16_t totalLength = pbuf->tot_len;
    uint8_t *bytes = malloc(totalLength);
    if (!bytes) {
        TFLogModuleError(@"TSIPStack", @"malloc failed for %d bytes", totalLength);
        return;
    }
    pbuf_copy_partial(pbuf, bytes, totalLength, 0);

    NSData *packet = [[NSData alloc] initWithBytesNoCopy:bytes length:totalLength freeWhenDone:YES];
    if (self.outboundHandler) {
        self.outboundHandler(packet, AF_INET);
    }
}

@end
