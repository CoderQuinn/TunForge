//
//  TFIPStack.m
//  TunForge
//
//  Created by MagicianQuinn on 2026/1/1.
//

#import "TFIPStack.h"
#import "TFGlobalScheduler.h"
#import "TFObjectRef.h"
#import "TFQueueHelpers.h"
#import "TFTCPConnection.h"
#import "TFTunForgeLog.h"
#import "TFWeakifyStrongify.h"

#import "lwip/err.h"
#import "lwip/init.h"
#import "lwip/ip4_addr.h"
#import "lwip/netif.h"
#import "lwip/tcp.h"
#import "lwip/timeouts.h"
#import <netinet/in.h>

#pragma mark - Lwip forward declarations

static struct netif tunforge_virtual_netif;

static err_t tunforge_accept(void *arg, struct tcp_pcb *newpcb, err_t err);

static err_t tunforge_output(struct netif *netif, struct pbuf *p, const ip4_addr_t *ipaddr);

static err_t tunforge_netif_init(struct netif *netif);

static void tunforge_netif_setup(void *state);

@interface TFIPStack ()

@property (nonatomic, assign) void *state;
@property (nonatomic, assign) BOOL ready;

@property (nonatomic, strong) TFObjectRef *stackRef;
@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic, assign) struct tcp_pcb *listener;

@end

@implementation TFIPStack

#pragma mark - Lifecycle

static TFIPStack *_stack;

+ (instancetype)defaultStack {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _stack = [[self alloc] initPrivate];
    });
    return _stack;
}

- (instancetype)init {
    NSAssert(NO, @"Use +defaultStack");
    return nil;
};

- (instancetype)initPrivate {
    if (self = [super init]) {
        [TFGlobalScheduler.shared packetsPerformSync:^{
            _stackRef = [[TFObjectRef alloc] initWithObject:self];
            lwip_init();
            memset(&tunforge_virtual_netif, 0, sizeof(tunforge_virtual_netif));
        }];
    }
    return self;
}

- (void)dealloc {
    NSAssert(self.stackRef == nil, @"stackRef should be nil");
    NSAssert(self.timer == nil, @"timer should be nil");
    NSAssert(self.listener == NULL, @"listener should be NULL");
    NSAssert(self.state == NULL, @"state should be NULL");
}

#pragma mark - Public
- (void)start {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (!self.stackRef || !self.stackRef.alive) {
        self.stackRef = [[TFObjectRef alloc] initWithObject:self];
    }

    [TFTunForgeLog info:@"TFIPStack start"];

    dispatch_queue_t queue = TFGlobalScheduler.shared.packetsQueue;
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(
        timer, DISPATCH_TIME_NOW, (uint64_t)TCP_TMR_INTERVAL * NSEC_PER_MSEC, 0);
    dispatch_source_set_event_handler(timer, ^{
        sys_check_timeouts();
    });

    sys_restart_timeouts();
    dispatch_resume(timer);

    self.timer = timer;

    [self setupLockedOnLWIPQueue];
}

- (void)stop {
    TF_ASSERT_ON_PACKETS_QUEUE();
    [TFTunForgeLog info:@"TFIPStack stop"];
    
    if (self.timer) {
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }

    [self.stackRef invalidate];
    self.stackRef = nil;
    self.ready = NO;

    if (self.listener) {
        tcp_arg(self.listener, NULL);
        tcp_accept(self.listener, NULL);
        tcp_close(self.listener);
        self.listener = NULL;
    }

    if (tunforge_virtual_netif.state == self.state) {
        netif_set_down(&tunforge_virtual_netif);
        netif_remove(&tunforge_virtual_netif);
        tunforge_virtual_netif.state = NULL;
    }

    if (self.state) {
        TFObjectRefRelease(self.state);
        self.state = NULL;
    }
}

#pragma mark - I/O
/// Input(TUN -> LwIP)
- (void)inputPacket:(nonnull NSData *)packet {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (!packet) {
        return;
    }

    u16_t len = packet.length;
    if (len == 0 || len > UINT16_MAX) {
        return;
    }

    if (!self.stackRef.alive)
        return;
    if (!self.ready)
        return;

    if (!tunforge_virtual_netif.input)
        return;

    // TODO:
    //    if (pbuf_pool_low()) {
    //        // drop + log
    //        return;
    //    }

    struct pbuf *pbuf = pbuf_alloc(PBUF_RAW, len, PBUF_POOL);
    if (!pbuf) {
        [TFTunForgeLog warn:@"pbuf_alloc failed"];
        return;
    }

    err_t err = pbuf_take(pbuf, packet.bytes, len);
    if (err != ERR_OK) {
        pbuf_free(pbuf);
        return;
    }

    err = tunforge_virtual_netif.input(pbuf, &tunforge_virtual_netif);
    if (err != ERR_OK) {
        [TFTunForgeLog warn:@"netif->input failed"];
        pbuf_free(pbuf);
    }
}

/// Output(LwIP -> TUN)
- (void)outputPacket:(struct pbuf *)pbuf {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (!pbuf)
        return;

    u16_t len = pbuf->tot_len;
    if (len < 20)
        return;

    NSMutableData *data = [NSMutableData dataWithLength:len];
    pbuf_copy_partial(pbuf, data.mutableBytes, len, 0);

    NSArray *packets = @[ data ];
    NSArray *families = @[ @(AF_INET) ];

    OutboundHandler handler = self.outboundHandler;
    if (!handler) {
        [TFTunForgeLog warn:@"Outbound handler is not set; drop output packet"];
        return;
    }
    handler(packets, families);
}

#pragma mark - setup once

- (void)setupLockedOnLWIPQueue {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (self.ready)
        return;
    self.ready = YES;

    [TFTunForgeLog info:@"lwIP initialized"];

    // setup netif
    void *state = [self.stackRef retainedVoidPointer];
    self.state = state;

    tunforge_netif_setup(state);
    tunforge_virtual_netif.state = state;
    tunforge_virtual_netif.output = tunforge_output;
    netif_set_default(&tunforge_virtual_netif);

    // setup listener
    struct tcp_pcb *pcb = tcp_new();
    NSAssert(pcb != NULL, @"tcp_new failed");

    err_t err = tcp_bind(pcb, IP_ADDR_ANY, 0);
    NSAssert(err == ERR_OK, @"tcp_bind failed");

    struct tcp_pcb *lpcb = tcp_listen_with_backlog_and_err(pcb, TCP_DEFAULT_LISTEN_BACKLOG, &err);
    NSAssert(err == ERR_OK, @"tcp_listen_with_backlog failed");

    tcp_arg(lpcb, state);
    tcp_accept(lpcb, tunforge_accept);

    self.listener = lpcb;
}

#pragma mark - Helpers

static TFIPStack *get_stack_from_arg(void *arg) {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (!arg || ![(__bridge TFObjectRef *)arg isKindOfClass:[TFObjectRef class]]) {
        return NULL;
    }

    TFObjectRef *ref = (__bridge TFObjectRef *)arg;
    if (!ref || !ref.alive) {
        return NULL;
    }

    return (TFIPStack *)ref.object;
}

#pragma mark - lwip bridge (lwIP -> ObjC)

static err_t tunforge_output(struct netif *netif, struct pbuf *p, const ip4_addr_t *ipaddr) {
    TF_ASSERT_ON_PACKETS_QUEUE();

    LWIP_UNUSED_ARG(ipaddr);

    TFIPStack *stack = get_stack_from_arg(netif->state);
    if (!stack)
        return ERR_OK;

    [stack outputPacket:p];
    return ERR_OK;
}

static err_t tunforge_netif_init(struct netif *netif) {
    TF_ASSERT_ON_PACKETS_QUEUE();

    netif->name[0] = 'T';
    netif->name[1] = 'F';

    netif->mtu = TUNFORGE_NETIF_IPV4_MTU;
    netif->flags = NETIF_FLAG_UP | NETIF_FLAG_LINK_UP;

    netif->output = tunforge_output;

    return ERR_OK;
}

static void tunforge_netif_setup(void *state) {
    TF_ASSERT_ON_PACKETS_QUEUE();
    // NOTE:
    // These addresses are only to satisfy lwIP internal checks.
    ip4_addr_t ip, mask, gw;
    IP4_ADDR(&ip, 198, 18, 0, 1);
    IP4_ADDR(&mask, 255, 255, 0, 0);
    IP4_ADDR(&gw, 0, 0, 0, 0);

    struct netif *ret =
        netif_add(&tunforge_virtual_netif, &ip, &mask, &gw, state, tunforge_netif_init, ip_input);
    LWIP_ASSERT("netif_add failed", ret != NULL);
    LWIP_ASSERT("netif->input is NULL", tunforge_virtual_netif.input != NULL);

    netif_set_up(&tunforge_virtual_netif);
    netif_set_link_up(&tunforge_virtual_netif);

    netif_set_default(&tunforge_virtual_netif);

    [TFTunForgeLog info:@"lwIP netif added / up / default"];
}

#pragma mark - Accept bridge (lwIP -> ObjC)
static err_t tunforge_accept(void *arg, struct tcp_pcb *newpcb, err_t err) {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (err != ERR_OK || !newpcb)
        return ERR_ABRT;

    tcp_backlog_delayed(newpcb);

    TFIPStack *stack = get_stack_from_arg(arg);
    if (!stack) {
        tcp_abort(newpcb);
        return ERR_ABRT;
    }

    TFTCPConnection *connection = [[TFTCPConnection alloc] initWithTCPPcb:newpcb];
    if (!connection) {
        [TFTunForgeLog warn:@"TCP accept: connection init failed"];
        tcp_abort(newpcb);
        return ERR_ABRT;
    }

    id<TFIPStackDelegate> delegate = stack.delegate;
    if (!delegate || ![delegate respondsToSelector:@selector(didAcceptNewTCPConnection:handler:)]) {
        tcp_abort(newpcb);
        return ERR_ABRT;
    }

    weakify(stack);
    [TFGlobalScheduler.shared connectionsPerformAsync:^{
        strongify(stack);
        [delegate didAcceptNewTCPConnection:connection
                                    handler:^(BOOL accept) {
                                        [TFGlobalScheduler.shared packetsPerformAsync:^{
                                            if (!stack || !newpcb)
                                                return;
                                            if (!accept) {
                                                tcp_abort(newpcb);
                                            }
                                        }];
                                    }];
    }];

    return ERR_OK;
}

@end
