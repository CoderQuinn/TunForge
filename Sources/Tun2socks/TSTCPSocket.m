//
//  TSTCPSocket.m
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/13.
//

#import "TSTCPSocket.h"
#import "TFLog.h"
#include "lwip/tcp.h"
#include <string.h>

@interface TSTCPSocket ()
@property (nonatomic, assign) struct tcp_pcb *pcb;
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@implementation TSTCPSocket

#pragma mark - Lifecycle

- (instancetype)initWithTCPPcb:(struct tcp_pcb *)pcb
                         queue:(dispatch_queue_t)queue
                      delegate:(id<TSTCPSocketDelegate>)delegate
                 delegateQueue:(dispatch_queue_t)delegateQueue
{
    if (self = [super init])
    {
        if (!pcb || !queue) {
            TFLogModuleError(@"TSTCPSocket", @"Init failed: NULL pcb or queue");
            return nil;
        }

        _pcb = pcb;
        _queue = queue;
        _delegate = delegate;
        _delegateQueue = delegateQueue;

        _sourcePort = pcb->remote_port;
        struct in_addr srcIP = {pcb->remote_ip.addr};
        _sourceAddress = srcIP;

        _destinationPort = pcb->local_port;
        struct in_addr dstIP = {pcb->local_ip.addr};
        _destinationAddress = dstIP;

        [self setupTCPPCB];
        TFLogModuleInfo(@"TSTCPSocket", @"Initialized successfully");
    }
    return self;
}

- (instancetype)initWithTCPPcb:(struct tcp_pcb *)pcb queue:(dispatch_queue_t)queue {
    return [self initWithTCPPcb:pcb queue:queue delegate:nil delegateQueue:nil];
}

- (void)dealloc {
    if (self.pcb) {
        tcp_arg(self.pcb, NULL);
        tcp_recv(self.pcb, NULL);
        tcp_sent(self.pcb, NULL);
        tcp_err(self.pcb, NULL);
        TFLogModuleDebug(@"TSTCPSocket", @"Deallocated");
    }
}

#pragma mark - Queue Assertion

- (void)assertOnQueue {
#if DEBUG
    dispatch_assert_queue(self.queue);
#endif
}

#pragma mark - LwIP Setup

- (void)setupTCPPCB {
    if (!self.pcb) {
        TFLogModuleError(@"TSTCPSocket", @"setupTCPPCB called with NULL pcb");
        return;
    }

    tcp_arg(self.pcb, (__bridge void *)(self));
    tcp_recv(self.pcb, tcp_recv_callback);
    tcp_sent(self.pcb, tcp_sent_callback);
    tcp_err(self.pcb, tcp_err_callback);
    TFLogModuleDebug(@"TSTCPSocket", @"TCP pcb callbacks set");
}

#pragma mark - Private Methods

- (void)cleanupWithAbort:(BOOL)abort notifyDelegate:(BOOL)notify {
    [self assertOnQueue];

    if (!self.pcb) return;

    tcp_arg(self.pcb, NULL);
    tcp_recv(self.pcb, NULL);
    tcp_sent(self.pcb, NULL);
    tcp_err(self.pcb, NULL);

    if (abort) {
        tcp_abort(self.pcb);
        TFLogModuleWarn(@"TSTCPSocket", @"Connection aborted");
    } else {
        err_t error = tcp_close(self.pcb);
        if (error != ERR_OK) {
            TFLogModuleError(@"TSTCPSocket", @"tcp_close failed: %d, aborting instead", error);
            tcp_abort(self.pcb);
        }
    }

    if (notify && self.delegate && [self.delegate respondsToSelector:@selector(socketDidClose:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate socketDidClose:self];
        });
    }

    self.pcb = NULL;
}

- (void)writeDataInternal:(NSData *)data {
    [self assertOnQueue];

    if (!self.pcb || !data || data.length == 0) return;

    if (data.length > UINT16_MAX) {
        TFLogModuleError(@"TSTCPSocket", @"Data too large: %lu bytes", (unsigned long)data.length);
        [self closeInternal];
        return;
    }

    const void *dataptr = data.bytes;
    UInt16 length = (UInt16)data.length;

    err_t error = tcp_write(self.pcb, dataptr, length, TCP_WRITE_FLAG_COPY);
    if (error != ERR_OK) {
        TFLogModuleError(@"TSTCPSocket", @"tcp_write failed: %d", error);
        [self closeInternal];
        return;
    }

    error = tcp_output(self.pcb);
    if (error != ERR_OK) {
        TFLogModuleError(@"TSTCPSocket", @"tcp_output failed: %d", error);
    }
}

- (void)closeInternal {
    [self assertOnQueue];
    if (!self.pcb) return;
    [self cleanupWithAbort:NO notifyDelegate:YES];
}

- (void)resetInternal {
    [self assertOnQueue];
    if (!self.pcb) return;
    [self cleanupWithAbort:YES notifyDelegate:YES];
}

#pragma mark - Public API

/**
 * Thread-safe write method. Executes on the socket's queue.
 */
- (void)writeData:(NSData *)data {
    dispatch_async(self.queue, ^{
        [self writeDataInternal:data];
    });
}

/**
 * Thread-safe close method. Executes on the socket's queue.
 */
- (void)close {
    dispatch_async(self.queue, ^{
        [self closeInternal];
    });
}

/**
 * Thread-safe reset method. Executes on the socket's queue.
 */
- (void)reset {
    dispatch_async(self.queue, ^{
        [self resetInternal];
    });
}

/**
 * Thread-safe validity check. Executes on the socket's queue.
 */
- (BOOL)isValid {
    __block BOOL valid;
    dispatch_sync(self.queue, ^{
        valid = self.pcb != NULL;
    });
    return valid;
}

/**
 * Thread-safe connection check. Executes on the socket's queue.
 */
- (BOOL)isConnected {
    __block BOOL connected;
    dispatch_sync(self.queue, ^{
        connected = (self.pcb != NULL) && (self.pcb->state != CLOSED);
    });
    return connected;
}

#pragma mark - lwIP Callbacks

- (void)handleError:(err_t)error {
    [self assertOnQueue];
    self.pcb = NULL;

    switch (error) {
        case ERR_RST:
            TFLogModuleWarn(@"TSTCPSocket", @"Connection reset by peer");
            if (self.delegate && [self.delegate respondsToSelector:@selector(socketDidReset:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate socketDidReset:self];
                });
            }
            break;
        case ERR_ABRT:
            TFLogModuleError(@"TSTCPSocket", @"Connection aborted");
            if (self.delegate && [self.delegate respondsToSelector:@selector(socketDidAbort:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate socketDidAbort:self];
                });
            }
            break;
        case ERR_CLSD:
            TFLogModuleInfo(@"TSTCPSocket", @"Connection closed");
            if (self.delegate && [self.delegate respondsToSelector:@selector(socketDidClose:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate socketDidClose:self];
                });
            }
            break;
        default:
            TFLogModuleError(@"TSTCPSocket", @"Unknown error: %d", error);
            break;
    }
}

- (void)handleSentBytes:(NSUInteger)length {
    [self assertOnQueue];
    if (self.delegate && [self.delegate respondsToSelector:@selector(socket:didWriteDataOfLength:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate socket:self didWriteDataOfLength:length];
        });
    }
}

- (void)handleReceivedPbuf:(struct pbuf *)pbuf {
    [self assertOnQueue];

    if (!pbuf) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(socketDidShutdownRead:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate socketDidShutdownRead:self];
            });
        }
        return;
    }

    uint16_t totalLength = pbuf->tot_len;
    NSMutableData *packetData = [NSMutableData dataWithLength:totalLength];
    if (!packetData) {
        TFLogModuleError(@"TSTCPSocket", @"Failed to allocate data for %d bytes", totalLength);
        pbuf_free(pbuf);
        return;
    }

    pbuf_copy_partial(pbuf, packetData.mutableBytes, totalLength, 0);

    if (self.delegate && [self.delegate respondsToSelector:@selector(socket:didReadData:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate socket:self didReadData:packetData];
        });
    }

    if (self.pcb) {
        tcp_recved(self.pcb, totalLength);
    }

    pbuf_free(pbuf);
}

#pragma mark - C Callbacks

static err_t tcp_recv_callback(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err) {
    if (!arg) { if (p) pbuf_free(p); tcp_abort(tpcb); return ERR_ABRT; }
    TSTCPSocket *socket = (__bridge TSTCPSocket *)arg;
    if (!socket) { if (p) pbuf_free(p); tcp_abort(tpcb); return ERR_ABRT; }

    dispatch_async(socket.queue, ^{
        [socket handleReceivedPbuf:p];
    });
    return ERR_OK;
}

static err_t tcp_sent_callback(void *arg, struct tcp_pcb *tpcb, u16_t len) {
    if (!arg) { tcp_abort(tpcb); return ERR_ABRT; }
    TSTCPSocket *socket = (__bridge TSTCPSocket *)arg;
    if (!socket) { tcp_abort(tpcb); return ERR_ABRT; }

    dispatch_async(socket.queue, ^{
        [socket handleSentBytes:len];
    });
    return ERR_OK;
}

static void tcp_err_callback(void *arg, err_t err) {
    if (!arg) return;
    TSTCPSocket *socket = (__bridge TSTCPSocket *)arg;
    if (socket) {
        dispatch_async(socket.queue, ^{
            [socket handleError:err];
        });
    }
}

@end
