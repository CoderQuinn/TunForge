//
//  TFIPStack.m
//  TunForge
//
//  TCP semantic adapter over the neutral TunForgeLwIPRuntime.
//

#import "TFIPStack.h"

#import "TFGlobalScheduler.h"
#import "TFObjectRef.h"
#import "TFQueueHelpers.h"
#import "TFTCPConnection.h"
#import "TFTunForgeLog.h"
#import "TFWeakifyStrongify.h"
#import "TunForgeLwIPRuntime.h"

#import "lwip/err.h"
#import "lwip/tcp.h"

static err_t tunforge_accept(void *arg, struct tcp_pcb *newpcb, err_t err);

@interface TFIPStack ()

@property (nonatomic, assign) void *state;
@property (nonatomic, strong) TFObjectRef *stackRef;
@property (nonatomic, assign) struct tcp_pcb *listener;
@property (nonatomic, strong) TunForgeLwIPRuntime *runtime;

@end

@implementation TFIPStack

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
}

- (instancetype)initPrivate {
    if (self = [super init]) {
        [TFGlobalScheduler.shared packetsPerformSync:^{
            _runtime = [TunForgeLwIPRuntime defaultRuntime];
            _stackRef = [[TFObjectRef alloc] initWithObject:self];
        }];
    }
    return self;
}

- (void)dealloc {
    NSAssert(self.stackRef == nil, @"stackRef should be nil");
    NSAssert(self.listener == NULL, @"listener should be NULL");
    NSAssert(self.state == NULL, @"state should be NULL");
}

- (OutboundHandler)outboundHandler {
    return self.runtime.outboundHandler;
}

- (void)setOutboundHandler:(OutboundHandler)outboundHandler {
    self.runtime.outboundHandler = outboundHandler;
}

- (void)start {
    TF_ASSERT_ON_PACKETS_QUEUE();

    [self.runtime start];
    if (self.listener) {
        [TFTunForgeLog info:@"TFIPStack start ignored (TCP adapter already running)"];
        return;
    }

    if (!self.stackRef || !self.stackRef.alive) {
        self.stackRef = [[TFObjectRef alloc] initWithObject:self];
    }
    [self setupTCPListenerLocked];
}

- (void)stop {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (self.listener) {
        tcp_arg(self.listener, NULL);
        tcp_accept(self.listener, NULL);
        tcp_close(self.listener);
        self.listener = NULL;
    }

    [self.stackRef invalidate];
    self.stackRef = nil;

    if (self.state) {
        TFObjectRefRelease(self.state);
        self.state = NULL;
    }

    [self.runtime stop];
}

- (void)inputPacket:(NSData *)packet {
    TF_ASSERT_ON_PACKETS_QUEUE();
    [self.runtime inputPacket:packet];
}

- (void)setupTCPListenerLocked {
    TF_ASSERT_ON_PACKETS_QUEUE();
    if (self.listener)
        return;

    NSAssert(self.runtime.running, @"lwIP runtime must be running before TCP adapter setup");

    void *state = [self.stackRef retainedVoidPointer];
    self.state = state;

    struct tcp_pcb *pcb = tcp_new();
    NSAssert(pcb != NULL, @"tcp_new failed");

    err_t err = tcp_bind(pcb, IP_ADDR_ANY, 0);
    NSAssert(err == ERR_OK, @"tcp_bind failed");

    struct tcp_pcb *listener =
        tcp_listen_with_backlog_and_err(pcb, TCP_DEFAULT_LISTEN_BACKLOG, &err);
    NSAssert(listener != NULL && err == ERR_OK, @"tcp_listen_with_backlog failed");

    tcp_arg(listener, state);
    tcp_accept(listener, tunforge_accept);
    self.listener = listener;

    [TFTunForgeLog info:@"TFIPStack TCP adapter listening"];
}

static TFIPStack *get_stack_from_arg(void *arg) {
    TF_ASSERT_ON_PACKETS_QUEUE();

    if (!arg || ![(__bridge TFObjectRef *)arg isKindOfClass:[TFObjectRef class]]) {
        return nil;
    }

    TFObjectRef *ref = (__bridge TFObjectRef *)arg;
    if (!ref.alive || ![ref.object isKindOfClass:[TFIPStack class]]) {
        return nil;
    }
    return (TFIPStack *)ref.object;
}

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
        [connection abort];
        return ERR_ABRT;
    }

    __block BOOL handlerConsumed = NO;
    TFTCPAcceptHandler handler = ^(BOOL accept) {
        [TFGlobalScheduler.shared packetsPerformAsync:^{
            if (handlerConsumed) {
                [TFTunForgeLog warn:@"TCP accept handler invoked more than once; ignoring"];
                return;
            }
            handlerConsumed = YES;

            if (!accept) {
                [connection abort];
            }
        }];
    };

    weakify(stack);
    [TFGlobalScheduler.shared connectionsPerformAsync:^{
        strongify(stack);
        [delegate didAcceptNewTCPConnection:connection handler:handler];
    }];

    return ERR_OK;
}

@end
