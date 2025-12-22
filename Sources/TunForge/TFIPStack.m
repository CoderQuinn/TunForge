//
//  TFIPStack.m
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/15.
//

#import "TFIPStack.h"
#import "TFTCPSocket.h"
#import "TFGlobalScheduler.h"
#import "TFLog.h"
#import "TFQueueHelpers.h"
#import "TFIPv4setting.h"
#import "TFObjectRef.h"
#include "lwip/tcp.h"
#include "lwip/timeouts.h"
#include "lwip/netif.h"
#include <arpa/inet.h>

typedef TFObjectRef TFStackRef;

#pragma mark - lwIP HOOK Implementations


// Forward declare packet output hook used in setup
static err_t packetOutput(struct netif *netif, struct pbuf *p, const ip4_addr_t *ipaddr);

/**
 * TunForge hook called when a new TCP PCB is created in SYN_RCVD state.
 * This happens during transparent TCP interception in tunforge_tcp_input_syn().
 */
void tunforge_on_new_tcp_pcb(struct tcp_pcb *pcb) {
    if (!pcb) return;

    char msg[256];
    snprintf(msg, sizeof(msg), "[TFIPStack][hook] New TCP PCB in SYN_RCVD: %s:%d <- %s:%d (ISS:%u, RCV:%u)",
             ipaddr_ntoa(&pcb->local_ip), pcb->local_port,
             ipaddr_ntoa(&pcb->remote_ip), pcb->remote_port,
             pcb->snd_nxt, pcb->rcv_nxt);
    TFLogInfo(msg);
}

/**
 * TunForge hook called when a transparent TCP connection transitions to ESTABLISHED.
 * This is where we hand off the connection to the delegate.
 *
 * CRITICAL: This is called directly from lwIP's tcp_process() in the lwIP context.
 * We MUST synchronously set up the socket before returning, otherwise tcp_receive()
 * will be called without proper callbacks registered.
 */
void tunforge_on_tcp_established(struct tcp_pcb *pcb) {
    if (!pcb) {
        TFLogError("[TFIPStack][hook] NULL pcb in established callback");
        return;
    }

    {
        char msg[200];
        snprintf(msg, sizeof(msg), "[TFIPStack][hook] ESTABLISHED: %s:%d -> %s:%d",
                 ipaddr_ntoa(&pcb->local_ip), pcb->local_port,
                 ipaddr_ntoa(&pcb->remote_ip), pcb->remote_port);
        TFLogInfo(msg);
    }
    
    // IMPORTANT: ext_arg now stores TFObjectRef* (NOT TFIPStack*).
    TFObjectRef *ref = (__bridge TFObjectRef *)tunforge_tcp_get_stack(pcb);
    if (!ref || !ref.alive) {
        TFLogError("[TFIPStack][hook] No valid stack ref for established connection (ext_arg missing/invalid)");
        tcp_abort(pcb);
        return;
    }
    
    TFIPStack *stack = (TFIPStack *)ref.object;
    if (!stack || ![stack isKindOfClass:[TFIPStack class]]) {
        TFLogError("[TFIPStack][hook] Stack already released (ref.stack == nil)");
        tcp_abort(pcb);
        return;
    }
    
    __weak id<TSIPStackDelegate> delegate = stack.delegate;
    
    // Create socket with optional initial delegate
    TFTCPSocket *socket = [[TFTCPSocket alloc] initWithTCPPcb:pcb];
    if (!socket || !socket.socketRef) {
        char msg[160];
        snprintf(msg, sizeof(msg), "[TFIPStack][hook] Failed to create TFTCPSocket for %s:%d",
                 ipaddr_ntoa(&pcb->remote_ip), pcb->remote_port);
        TFLogError(msg);
        tcp_abort(pcb);
        return;
    }
    
    tunforge_tcp_bind_socket(pcb, (__bridge void *)socket.socketRef);
    
    TFLogInfo("[TFIPStack][hook] TFTCPSocket created (callbacks registered)");
    
    // Check delegate availability
    if (!delegate) {
        // Delegate not available: schedule socket to close after timeout to prevent resource leak
        TFLogInfo("[TFIPStack][hook] Auto-closing socket: no delegate");
        
        [TFGlobalScheduler.shared processPerformAsync:^{
            [socket close];
        }];

        return;
    }
    
    if (![delegate respondsToSelector:@selector(didAcceptTCPSocket:)]) {
        TFLogWarning("[TFIPStack][hook] Delegate missing didAcceptTCPSocket:");
        [TFGlobalScheduler.shared processPerformAsync:^{
            [socket close];
        }];
        return;
    }
    
    TFLogInfo("[TFIPStack][hook] Handing socket to delegate");
    
    [TFGlobalScheduler.shared delegatePerformAsync:^{
        [delegate didAcceptTCPSocket:socket];
        
        if([socket.delegate respondsToSelector:@selector(socketDidBecomeActive:)]) {
            [socket.delegate socketDidBecomeActive:socket];
        }
    }];
}

@interface TFIPStack ()

// Default network interface
@property (nonatomic, assign) struct netif *defaultInterface;

/// Stable reference stored in lwIP (netif->state / tcp_ext_arg) instead of bridging self.
@property (nonatomic, strong) TFStackRef *stackRef;

// Per-instance netif storage
@property (nonatomic) struct netif netifStorage;

@property (nonatomic, strong) TFIPv4setting *setting;

@end

@implementation TFIPStack

#pragma mark - Lifecycle

+ (instancetype)stackWithSetting:(TFIPv4setting *_Nullable)setting {
    return [[self alloc] initWithSetting:setting];
}

+ (instancetype)stack {
    return [self stackWithSetting:nil];
}

/// Create a new stack with the given config.
- (instancetype)initWithSetting:(TFIPv4setting *_Nullable)setting {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    if(!setting) {
        setting = [[TFIPv4setting alloc] init];
        setting.ipAddress = @"240.0.0.1";
        setting.netmask = @"240.0.0.0";
        setting.gateway = @"240.0.0.254";
    }
    _setting = setting;

    @try {
        [self setup];
        TFLogModuleInfo(@"TFIPStack", @"State: Initializing -> Initialized");
    } @catch (NSException *exception) {
        TFLogModuleError(@"TFIPStack", @"Setup failed: %@", exception);
    }
    return self;
}

- (instancetype)init {
    return [self initWithSetting:nil];
}

- (void)dealloc {
    NSAssert(self.stackRef == nil,
             @"TFIPStack dealloc without teardown");
}

#pragma mark - lwIP Setup

- (void)setup {
    // Use per-instance storage to avoid dangling pointers
    ip4_addr_t ipaddr, netmask, gw;
    
    // Convert string IP addresses to ip4_addr_t
    const char *cfg_ip = self.setting.ipAddress.UTF8String;
    const char *cfg_netmask = self.setting.netmask.UTF8String;
    const char *cfg_gw = self.setting.gateway.UTF8String;
    struct in_addr addr, nm, g;

    if (cfg_ip && inet_aton(cfg_ip, &addr)) {
        ip4_addr_set_u32(&ipaddr, addr.s_addr);
    } else {
        IP4_ADDR(&ipaddr, 240,0,0,1);
    }

    if (cfg_netmask && inet_aton(cfg_netmask, &nm)) {
        ip4_addr_set_u32(&netmask, nm.s_addr);
    } else {
        IP4_ADDR(&netmask, 240,0,0,0);
    }

    if (cfg_gw && inet_aton(cfg_gw, &g)) {
        ip4_addr_set_u32(&gw, g.s_addr);
    } else {
        IP4_ADDR(&gw, 240,0,0,254);
    }

    // Add default network interface
    struct netif *interface = netif_add(&(_netifStorage), &ipaddr, &netmask, &gw, NULL, NULL, ip_input);
    if (!interface) {
        TFLogModuleError(@"TFIPStack", @"Failed to initialize network interface");
        return;
    }
    
    self.stackRef = [[TFObjectRef alloc] initWithObject:self];
    interface->state = (__bridge void *)self.stackRef;
    
    interface->output = packetOutput;
    interface->mtu = 1500;
    interface->flags = NETIF_FLAG_BROADCAST | NETIF_FLAG_ETHARP | NETIF_FLAG_LINK_UP;
    netif_set_default(interface);
    netif_set_up(interface);
    netif_set_link_up(interface);
    
    self.defaultInterface = interface;

    TFLogModuleInfo(@"TFIPStack", @"Network stack initialized");
}

#pragma mark - Public
- (void)suspendTimer {
    [TFGlobalScheduler.shared processPerformAsync:^{
        [self suspendTimerInternal];
    }];
}

- (void)resumeTimer {
    [TFGlobalScheduler.shared processPerformAsync:^{
        [self resumeTimerInternal];
    }];
}

- (void)teardown {
    TF_ASSERT_ON_LWIP_QUEUE();
    
    if (self.defaultInterface) {
        // Stop lwIP from calling into this stack
        netif_set_down(self.defaultInterface);
        netif_remove(self.defaultInterface);
        self.defaultInterface->state = NULL;
        self.defaultInterface = NULL;
    }
    
    [self.stackRef invalidate];

}

- (BOOL)isReady {
    // Thread-safe read via processQueue
    __block BOOL ready = NO;
    [TFGlobalScheduler.shared processPerformSync:^{
        ready = self.defaultInterface != NULL;
    }];
    return ready;
}

/// Running means lwIP global scheduler is active
- (BOOL)isRunning {
    // Thread-safe read via processQueue
    __block BOOL running = NO;
    [TFGlobalScheduler.shared processPerformSync:^{
        running = TFGlobalScheduler.shared.acquireCount > 0;
    }];
    return running;
}

- (void)receivedPacket:(NSData *)packet {
    [TFGlobalScheduler.shared processPerformAsync:^{
        if (!packet || packet.length == 0) return;
        if (packet.length > UINT16_MAX) return;
        
        [self receivedPacketInternal:packet];
    }];
}

#pragma mark - private
- (void)suspendTimerInternal {
    [TFGlobalScheduler.shared relinquish];
}

- (void)resumeTimerInternal {
    [TFGlobalScheduler.shared acquire];
}

- (void)receivedPacketInternal:(NSData *)packet {
    // State check with detailed logging

    if (!self.defaultInterface) return;

    struct pbuf *pbufPacket = pbuf_alloc(PBUF_RAW, packet.length, PBUF_POOL);
    if (!pbufPacket) {
        TFLogModuleError(@"TFIPStack", @"pbuf_alloc failed for %lu bytes", (unsigned long)packet.length);
        return;
    }
    if (pbuf_take(pbufPacket, packet.bytes, packet.length) != ERR_OK) {
        TFLogModuleError(@"TFIPStack", @"pbuf_take failed for %lu bytes", (unsigned long)packet.length);
        pbuf_free(pbufPacket);
        return;
    }

    err_t err = self.defaultInterface->input(pbufPacket, self.defaultInterface);
    if (err != ERR_OK) { pbuf_free(pbufPacket); }
}

// (Queue configuration was previously exposed; now only pre-start configuration is supported.)

#pragma mark - Packet Output

static err_t packetOutput(struct netif *netif, struct pbuf *p, const ip4_addr_t *ipaddr) {
    if (!p)
        return ERR_ARG;
    
    // netif->state stores TFStackRef*
    TFObjectRef *ref = (__bridge TFObjectRef *)netif->state;
    if(!ref || !ref.alive || !ref.object || ![ref.object isKindOfClass:[TFIPStack class]]) return ERR_ARG;
    
    TFIPStack *stack = (TFIPStack *)ref.object;
    [stack sendOutPacket:p];
    return ERR_OK;
}

- (void)sendOutPacket:(struct pbuf *)pbuf {
    if (!pbuf)
        return;

    uint16_t totalLength = pbuf->tot_len;
    uint8_t *bytes = malloc(totalLength);
    if (!bytes) {
        TFLogModuleError(@"TFIPStack", @"malloc failed for %d bytes", totalLength);
        return;
    }
    pbuf_copy_partial(pbuf, bytes, totalLength, 0);

    NSData *packet = [[NSData alloc] initWithBytesNoCopy:bytes length:totalLength freeWhenDone:YES];
    NSArray *packets = @[packet];
    NSArray *versions = @[@(AF_INET)];
    if (self.outboundHandler) {
        self.outboundHandler(packets, versions);
    }
}

@end
