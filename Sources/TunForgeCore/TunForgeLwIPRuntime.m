//
//  TunForgeLwIPRuntime.m
//  TunForge
//

#import "TunForgeLwIPRuntime.h"

#import "TFGlobalScheduler.h"
#import "TFObjectRef.h"
#import "TFQueueHelpers.h"
#import "TFTunForgeLog.h"

#import "lwip/err.h"
#import "lwip/init.h"
#import "lwip/ip.h"
#import "lwip/ip4_addr.h"
#import "lwip/netif.h"
#import "lwip/timeouts.h"

#import <netinet/in.h>

static struct netif tunforge_runtime_netif;

static err_t tunforge_runtime_output(struct netif *netif, struct pbuf *p, const ip4_addr_t *ipaddr);
static err_t tunforge_runtime_netif_init(struct netif *netif);
static void tunforge_runtime_netif_setup(void *state);

@interface TunForgeLwIPRuntime ()

@property (nonatomic, assign) void *state;
@property (nonatomic, assign, readwrite, getter=isRunning) BOOL running;
@property (nonatomic, strong) TFObjectRef *runtimeRef;
@property (nonatomic, strong) dispatch_source_t timer;

@end

@implementation TunForgeLwIPRuntime

static TunForgeLwIPRuntime *_runtime;

+ (instancetype)defaultRuntime {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _runtime = [[self alloc] initPrivate];
    });
    return _runtime;
}

- (instancetype)init {
    NSAssert(NO, @"Use +defaultRuntime");
    return nil;
}

- (instancetype)initPrivate {
    if (self = [super init]) {
        [TFGlobalScheduler.shared packetsPerformSync:^{
            _runtimeRef = [[TFObjectRef alloc] initWithObject:self];
            lwip_init();
            memset(&tunforge_runtime_netif, 0, sizeof(tunforge_runtime_netif));
        }];
    }
    return self;
}

- (void)dealloc {
    NSAssert(self.runtimeRef == nil, @"runtimeRef should be nil");
    NSAssert(self.timer == nil, @"timer should be nil");
    NSAssert(self.state == NULL, @"state should be NULL");
}

- (void)performSync:(dispatch_block_t)block {
    NSParameterAssert(block);
    [TFGlobalScheduler.shared packetsPerformSync:block];
}

- (void)performAsync:(dispatch_block_t)block {
    NSParameterAssert(block);
    [TFGlobalScheduler.shared packetsPerformAsync:block];
}

- (void)start {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (self.running && self.timer) {
        [TFTunForgeLog info:@"TunForgeLwIPRuntime start ignored (already running)"];
        return;
    }
    if (self.timer) {
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }

    if (!self.runtimeRef || !self.runtimeRef.alive) {
        self.runtimeRef = [[TFObjectRef alloc] initWithObject:self];
    }

    dispatch_source_t timer = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_TIMER, 0, 0, TFGlobalScheduler.shared.packetsQueue);
    dispatch_source_set_timer(
        timer, DISPATCH_TIME_NOW, (uint64_t)TCP_TMR_INTERVAL * NSEC_PER_MSEC, 0);
    dispatch_source_set_event_handler(timer, ^{
        sys_check_timeouts();
    });

    sys_restart_timeouts();
    dispatch_resume(timer);
    self.timer = timer;

    [self setupLocked];
}

- (void)stop {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (self.timer) {
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }

    [self.runtimeRef invalidate];
    self.runtimeRef = nil;
    self.running = NO;

    if (tunforge_runtime_netif.state == self.state) {
        netif_set_down(&tunforge_runtime_netif);
        netif_remove(&tunforge_runtime_netif);
        tunforge_runtime_netif.state = NULL;
    }

    if (self.state) {
        TFObjectRefRelease(self.state);
        self.state = NULL;
    }
}

- (void)inputPacket:(NSData *)packet {
    TF_ASSERT_ON_PACKETS_QUEUE();

    NSUInteger packetLength = packet.length;
    if (packetLength == 0 || packetLength > UINT16_MAX || !self.running || !self.runtimeRef.alive ||
        !tunforge_runtime_netif.input) {
        return;
    }

    u16_t length = (u16_t)packetLength;
    struct pbuf *pbuf = pbuf_alloc(PBUF_RAW, length, PBUF_POOL);
    if (!pbuf) {
        [TFTunForgeLog warn:@"pbuf_alloc failed"];
        return;
    }

    err_t err = pbuf_take(pbuf, packet.bytes, length);
    if (err != ERR_OK) {
        pbuf_free(pbuf);
        return;
    }

    err = tunforge_runtime_netif.input(pbuf, &tunforge_runtime_netif);
    if (err != ERR_OK) {
        [TFTunForgeLog warn:@"netif->input failed"];
        pbuf_free(pbuf);
    }
}

- (void)outputPacket:(struct pbuf *)pbuf {
    TF_ASSERT_ON_PACKETS_QUEUE();
    if (!pbuf)
        return;

    u16_t length = pbuf->tot_len;
    OutboundHandler handler = self.outboundHandler;
    if (length < 20 || !handler) {
        return;
    }

    NSMutableData *data = [NSMutableData dataWithLength:length];
    u16_t copied = pbuf_copy_partial(pbuf, data.mutableBytes, length, 0);
    if (copied != length) {
        [TFTunForgeLog
            warn:[NSString
                     stringWithFormat:@"pbuf_copy_partial copied %u/%u bytes", copied, length]];
        return;
    }

    handler(@[ data ], @[ @(AF_INET) ]);
}

- (void)setupLocked {
    TF_ASSERT_ON_PACKETS_QUEUE();
    if (self.running)
        return;

    void *state = [self.runtimeRef retainedVoidPointer];
    self.state = state;

    tunforge_runtime_netif_setup(state);
    tunforge_runtime_netif.state = state;
    tunforge_runtime_netif.output = tunforge_runtime_output;
    netif_set_default(&tunforge_runtime_netif);
    self.running = YES;

    [TFTunForgeLog info:@"lwIP runtime netif added / up / default"];
}

static TunForgeLwIPRuntime *get_runtime_from_arg(void *arg) {
    TF_ASSERT_ON_PACKETS_QUEUE();
    if (!arg || ![(__bridge TFObjectRef *)arg isKindOfClass:[TFObjectRef class]]) {
        return nil;
    }

    TFObjectRef *ref = (__bridge TFObjectRef *)arg;
    if (!ref.alive || ![ref.object isKindOfClass:[TunForgeLwIPRuntime class]]) {
        return nil;
    }
    return (TunForgeLwIPRuntime *)ref.object;
}

static err_t tunforge_runtime_output(struct netif *netif,
                                     struct pbuf *p,
                                     const ip4_addr_t *ipaddr) {
    TF_ASSERT_ON_PACKETS_QUEUE();
    LWIP_UNUSED_ARG(ipaddr);

    TunForgeLwIPRuntime *runtime = get_runtime_from_arg(netif->state);
    if (!runtime)
        return ERR_OK;

    [runtime outputPacket:p];
    return ERR_OK;
}

static err_t tunforge_runtime_netif_init(struct netif *netif) {
    TF_ASSERT_ON_PACKETS_QUEUE();

    netif->name[0] = 'T';
    netif->name[1] = 'F';
    netif->mtu = TUNFORGE_NETIF_IPV4_MTU;
    netif->flags = NETIF_FLAG_UP | NETIF_FLAG_LINK_UP;
    netif->output = tunforge_runtime_output;
    return ERR_OK;
}

static void tunforge_runtime_netif_setup(void *state) {
    TF_ASSERT_ON_PACKETS_QUEUE();

    ip4_addr_t ip, mask, gateway;
    IP4_ADDR(&ip, 198, 18, 0, 1);
    IP4_ADDR(&mask, 255, 255, 0, 0);
    IP4_ADDR(&gateway, 0, 0, 0, 0);

    struct netif *result = netif_add(&tunforge_runtime_netif,
                                     &ip,
                                     &mask,
                                     &gateway,
                                     state,
                                     tunforge_runtime_netif_init,
                                     ip_input);
    LWIP_ASSERT("netif_add failed", result != NULL);
    LWIP_ASSERT("netif->input is NULL", tunforge_runtime_netif.input != NULL);

    netif_set_up(&tunforge_runtime_netif);
    netif_set_link_up(&tunforge_runtime_netif);
    netif_set_default(&tunforge_runtime_netif);
}

@end
