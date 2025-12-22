//
//  TFTCPSocket.m
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/13.
//

#import "TFTCPSocket.h"
#import "TFLog.h"
#import "TFIPStack.h" // for keys
#import "TFQueueHelpers.h"
#import "TFGlobalScheduler.h"
#import "TFObjectRef.h"
#include "lwipopts.h"
#include "lwip/tcp.h"
#include <string.h>
#include <arpa/inet.h>

#pragma mark - C healper
static inline TFTCPSocket *tf_socket_from_arg(void *arg) {
    if (!arg) return NULL;
    TFTCPSocketRef *ref = (__bridge TFTCPSocketRef *)arg;
    if (!ref.alive) return NULL;
    id obj = ref.object;
    if (!obj || ![obj isKindOfClass:[TFTCPSocket class]]) return NULL;
    return (TFTCPSocket *)obj;
}


@interface TFTCPSocket ()

@property (nonatomic, assign) struct tcp_pcb *pcb;

@property (nonatomic, strong) TFTCPSocketRef *socketRef;

// Internal writable state
@property (nonatomic, assign) TFTCPSocketState socketState;

@property (nonatomic, assign) TFTCPSocketTerminationReason terminationReason;

@property (nonatomic, assign) BOOL isTerminated;

@property (nonatomic, assign) BOOL didNotifyClose;

@end

@implementation TFTCPSocket

#pragma mark - Lifecycle
- (instancetype)initWithTCPPcb:(struct tcp_pcb *)pcb
                  delegate:(nullable id<TSTCPSocketDelegate>)delegate
{
    if (self = [super init])
    {
        if (!pcb ) {
            TFLogModuleError(@"TFTCPSocket", @"Init failed: NULL pcb or queue");
            return nil;
        }

        _pcb = pcb;
        _delegate = delegate;
        _isTerminated = NO;
   
        // Direct state assignment during init (before dispatch context setup)
        _closeTimeoutMS = 5000;  // 默认5秒超时
        
        // A: create stable ref BEFORE wiring lwIP callbacks
        _socketRef = [[TFObjectRef alloc] initWithObject:self];
        
        // intercepted flow perspective
        _localPort = pcb->remote_port;
        _localAddress = [self formatIPAddress:pcb->remote_ip.addr];

        _remotePort = pcb->local_port;
        _remoteAddress = [self formatIPAddress:pcb->local_ip.addr];
        
        [self setupTCPPCB];
        _socketState = TFTCPSocketStateActive;
        // Now on processTFQueueConfig context after setupTCPPCB
        TFLogModuleInfo(@"TFTCPSocket", @"Initialized successfully");
    }
    return self;
}

- (instancetype)initWithTCPPcb:(struct tcp_pcb *)pcb {
    return [self initWithTCPPcb:pcb delegate:nil];
}

- (void)dealloc {
    NSAssert(self.pcb == NULL, @"TFTCPSocket deallocated with active pcb");
}

#pragma mark - Queue Helpers

- (void)performAsync:(dispatch_block_t _Nonnull)block {
    [TFGlobalScheduler.shared processPerformAsync:block];
}

- (void)performSync:(dispatch_block_t _Nonnull)block {
    [TFGlobalScheduler.shared processPerformSync:block];
}

- (void)delegatePerformAsync:(dispatch_block_t _Nonnull)block {
    [TFGlobalScheduler.shared delegatePerformAsync:block];
}

- (void)assertOnProcessQueue {
    NSAssert([TFGlobalScheduler.shared.processTFQueueConfig isOnQueue], @"Must be on process queue");
}

#pragma mark - State Management

+ (NSString *)stateNameForState:(TFTCPSocketState)state {
    switch (state) {
        case TFTCPSocketStateIdle:        return @"Idle";
        case TFTCPSocketStateActive:     return @"Active";
        case TFTCPSocketStateClosing:    return @"Closing";
        default:
            return @"Idle";
    }
}

- (NSString *)currentStateName {
    return [TFTCPSocket stateNameForState:self.socketState];
}

#pragma mark - LwIP Setup

- (void)setupTCPPCB {
    if (!self.pcb) {
        TFLogModuleError(@"TFTCPSocket", @"setupTCPPCB called with NULL pcb");
        return;
    }
    
    // A: tcp_arg is only a fast-path borrowed pointer to socketRef
    // Lifetime will be unified later via tcp_ext_arg destroy
    tcp_arg(self.pcb, (__bridge void *)self.socketRef);
    
    tcp_recv(self.pcb, tcp_recv_callback);
    tcp_sent(self.pcb, tcp_sent_callback);
    tcp_err(self.pcb, tcp_err_callback);
    TFLogModuleDebug(@"TFTCPSocket", @"TCP pcb callbacks set");
}

- (void)clearTCPPCB {
    TF_ASSERT_ON_LWIP_QUEUE();
    
    if (!self.pcb) return;
    tcp_arg(self.pcb, NULL);
    tcp_recv(self.pcb, NULL);
    tcp_sent(self.pcb, NULL);
    tcp_err(self.pcb, NULL);
}

#pragma mark - Private Methods

- (void)freezeTerminationReason:(TFTCPSocketTerminationReason)reason {
     if (self.terminationReason != TFTCPSocketTerminationReasonNone) {
         return;
     }
     self.terminationReason = reason;
}

- (NSString *)formatIPAddress:(uint32_t)addr {
    // Convert from network byte order to host byte order
    uint32_t hostAddr = ntohl(addr);
    uint8_t *bytes = (uint8_t *)&hostAddr;
    return [NSString stringWithFormat:@"%d.%d.%d.%d", bytes[0], bytes[1], bytes[2], bytes[3]];
}

- (void)cleanupWithTerminationReason:(TFTCPSocketTerminationReason)reason {
    TF_ASSERT_ON_LWIP_QUEUE();
    
    if(self.isTerminated) return;
    self.isTerminated = YES;
    
    // 1. Reason for termination of freeze (write only once)
    [self freezeTerminationReason:reason];
    
    // 2. Transition to appropriate intermediate state
    // stay in Closing until delegate notified
    self.socketState = TFTCPSocketStateClosing;

    // 3. Clear all lwIP callbacks to prevent future invocations
    [self clearTCPPCB];
    
    // 4. CRITICAL: invalidate ref immediately so any late lwIP callback fast-fails
    [self.socketRef invalidate];
    // (do NOT nil here; ext_arg destroy will unpin)
    
    // 5. close lwip
    struct tcp_pcb *pcb = self.pcb;
    self.pcb = NULL;
    
    if(!pcb) return;
    
    if (reason == TFTCPSocketTerminationReasonAbort || reason == TFTCPSocketTerminationReasonReset) {
        tcp_abort(pcb);
    } else {
        // Graceful close with timeout
        err_t error = tcp_close(pcb);
        if (error != ERR_OK) {
            tcp_abort(pcb);
        }
    }
}

- (void)notifyDelegate:(TFTCPSocketTerminationReason)terminationReason {
    TF_ASSERT_ON_LWIP_QUEUE();
    
    if (self.didNotifyClose) return;
    self.didNotifyClose = YES;
    
    id<TSTCPSocketDelegate> delegate = self.delegate;
    if(!delegate) {
        self.socketState = TFTCPSocketStateIdle;
        return;
    }
    
    [self delegatePerformAsync:^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(socketDidClose:reason:)]) {
            [self.delegate socketDidClose:self reason:terminationReason];
        }
    }];
    
    self.socketState = TFTCPSocketStateIdle;
}

- (void)writeDataInternal:(NSData *)data {
    TF_ASSERT_ON_LWIP_QUEUE();
    
    // State check
    if (self.socketState != TFTCPSocketStateActive) {
        TFLogModuleWarn(@"TFTCPSocket", @"Cannot write in state: %@", [self currentStateName]);
        return;
    }

    if (!self.pcb || !data || data.length == 0) return;

    if (data.length > UINT16_MAX) {
        TFLogModuleError(@"TFTCPSocket", @"Data too large: %lu bytes", (unsigned long)data.length);
        [self closeInternal];
        return;
    }

    const void *dataptr = data.bytes;
    UInt16 length = (UInt16)data.length;

    err_t error = tcp_write(self.pcb, dataptr, length, TCP_WRITE_FLAG_COPY);
    if (error != ERR_OK) {
        TFLogModuleError(@"TFTCPSocket", @"tcp_write failed: %d", error);
        [self closeInternal];
        return;
    }

    error = tcp_output(self.pcb);
    if (error != ERR_OK) {
        TFLogModuleError(@"TFTCPSocket", @"tcp_output failed: %d", error);
    }
}

- (void)closeInternal {
    TF_ASSERT_ON_LWIP_QUEUE();
    
    TFTCPSocketState currentState = self.socketState;
    
    if (currentState != TFTCPSocketStateActive) {
        TFLogModuleDebug(@"TFTCPSocket", @"Close ignored in state: %@", [self currentStateName]);
        return;
    }
    
    if (!self.pcb) return;
    
    [self cleanupWithTerminationReason:TFTCPSocketTerminationReasonLocalClose];
    [self notifyDelegate:self.terminationReason];
}

- (void)resetInternal {
    TF_ASSERT_ON_LWIP_QUEUE();
    
    if (self.socketState != TFTCPSocketStateActive) {
        TFLogModuleDebug(@"TFTCPSocket", @"Reset called on closed socket");
        return;
    }
    
    [self cleanupWithTerminationReason:TFTCPSocketTerminationReasonAbort];
    [self notifyDelegate:self.terminationReason];
}

#pragma mark - Public API

/**
 * Thread-safe write method. Executes on the socket's queue.
 */
- (void)writeData:(NSData *)data {
    [self performAsync:^{
        [self writeDataInternal:data];
    }];
}

/**
 * Thread-safe close method. Executes on the socket's queue.
 */
- (void)close {
    [self performAsync:^{
        [self closeInternal];
    }];
}

/**
 * Thread-safe reset method. Executes on the socket's queue.
 */
- (void)reset {
    [self performAsync:^{
        [self resetInternal];
    }];
}

/**
 * Thread-safe validity check. Executes on the socket's queue.
 */
- (BOOL)isValid {
    // Thread-safe read via processTFQueueConfig
    __block BOOL valid = NO;
    [self performSync:^{
        valid = self.socketState != TFTCPSocketStateIdle;
    }];
    return valid;
}

/**
 * Thread-safe connection check. Executes on the socket's queue.
 */
- (BOOL)isConnected {
    // Thread-safe read via processTFQueueConfig
    __block BOOL connected = NO;
    [self performSync:^{
        connected = self.socketState == TFTCPSocketStateActive;
    }];
    return connected;
}

/// teardown is a forced destroy path
- (void)teardown {
    TF_ASSERT_ON_LWIP_QUEUE();
    [self.socketRef invalidate];
    [self cleanupWithTerminationReason:TFTCPSocketTerminationReasonAbort];
    [self notifyDelegate:self.terminationReason];
}

#pragma mark - lwIP Callbacks

- (void)handleError:(err_t)error {
    TF_ASSERT_ON_LWIP_QUEUE();
    
    TFLogModuleWarn(@"TFTCPSocket",
        @"lwIP error received: %d, aborting socket", error);
    TFTCPSocketTerminationReason reason;
    switch (error) {
        case ERR_RST:
            reason = TFTCPSocketTerminationReasonReset;
            break;
        default:
            reason = TFTCPSocketTerminationReasonAbort;
            break;
    }
    [self cleanupWithTerminationReason:reason];
    [self notifyDelegate:self.terminationReason];
}

- (void)handleSentBytes:(NSUInteger)length {
    TF_ASSERT_ON_LWIP_QUEUE();
    if (self.delegate && [self.delegate respondsToSelector:@selector(socket:didWriteDataOfLength:)]) {
        [self delegatePerformAsync:^{
            [self.delegate socket:self didWriteDataOfLength:length];
        }];
    }
}

- (void)handleReceivedPbuf:(struct pbuf *)pbuf {
    TF_ASSERT_ON_LWIP_QUEUE();
    if (!pbuf) {
        if (self.pcb) {
            tcp_recved(self.pcb, 0);
        }
        
        // FIN from remote
        [self cleanupWithTerminationReason:TFTCPSocketTerminationReasonRemoteClose];
        [self notifyDelegate:self.terminationReason];
        
        return;
    }

    uint16_t totalLength = pbuf->tot_len;
    NSMutableData *packetData = [NSMutableData dataWithLength:totalLength];
    if (!packetData) {
        TFLogModuleError(@"TFTCPSocket", @"Failed to allocate data for %d bytes", totalLength);
        pbuf_free(pbuf);
        return;
    }

    pbuf_copy_partial(pbuf, packetData.mutableBytes, totalLength, 0);
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(socket:didReadData:)]) {
        [self delegatePerformAsync:^{
            [self.delegate socket:self didReadData:packetData.copy];
        }];
    }

    if (self.pcb) {
        tcp_recved(self.pcb, totalLength);
    }

    // pbuf is released by the recv callback after asynchronous handling
}

#pragma mark - C Callbacks

static err_t tcp_recv_callback(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err) {
    TFTCPSocket *socket = tf_socket_from_arg(arg);
    if (!socket) {
        if (p) { pbuf_free(p); }
        tcp_abort(tpcb);
        return ERR_ABRT;
    }
    
    if (p) { pbuf_ref(p); }
    [TFGlobalScheduler.shared processPerformAsync:^{
        [socket handleReceivedPbuf:p];
        if (p) { pbuf_free(p); }
    }];
    return ERR_OK;
}

static err_t tcp_sent_callback(void *arg, struct tcp_pcb *tpcb, u16_t len) {
    TFTCPSocket *socket = tf_socket_from_arg(arg);
    if (!socket) {
        tcp_abort(tpcb);
        return ERR_ABRT;
    }
    
    [TFGlobalScheduler.shared processPerformAsync:^{
        [socket handleSentBytes:len];
    }];
    return ERR_OK;
}

static void tcp_err_callback(void *arg, err_t err) {
    TFTCPSocket *socket = tf_socket_from_arg(arg);
    if (!socket) {
        return;
    }
    
    [TFGlobalScheduler.shared processPerformAsync:^{
        [socket handleError:err];
    }];
}

@end
