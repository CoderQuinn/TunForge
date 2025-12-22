//
//  TFTCPSocket.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/13.
//

#import <Foundation/Foundation.h>
#import <netinet/in.h>

/* Forward declaration to make 'struct tcp_pcb' visible in Objective-C method
 * signatures without pulling in lwIP headers from public API.
 */
struct tcp_pcb;

NS_ASSUME_NONNULL_BEGIN

@class TFTCPSocket, TFQueueConfig, TFObjectRef;
typedef TFObjectRef TFTCPSocketRef;

/// TFTCPSocket connection states
typedef NS_ENUM(NSInteger, TFTCPSocketState) {
    TFTCPSocketStateIdle = 0,       // terminal / not usable
    TFTCPSocketStateActive,     // ESTABLISHED, I/O allowed
    TFTCPSocketStateClosing,    // close/reset in progress
};

typedef NS_ENUM(NSUInteger, TFTCPSocketTerminationReason) {
    TFTCPSocketTerminationReasonNone,
    TFTCPSocketTerminationReasonLocalClose,
    TFTCPSocketTerminationReasonRemoteClose,
    TFTCPSocketTerminationReasonReset,
    TFTCPSocketTerminationReasonAbort,
};

@protocol TSTCPSocketDelegate <NSObject>
@optional

/// Socket is ready for I/O (called once)
- (void)socketDidBecomeActive:(TFTCPSocket *)socket;

/// Data received
- (void)socket:(TFTCPSocket *)socket didReadData:(NSData *)data;

/// Data flushed to TCP send buffer
- (void)socket:(TFTCPSocket *)socket didWriteDataOfLength:(NSUInteger)length;

/// Socket terminated (exactly once)
- (void)socketDidClose:(TFTCPSocket *)socket
                reason:(TFTCPSocketTerminationReason)reason;

@end


@interface TFTCPSocket : NSObject

/// Local (source) IPv4 address as dotted decimal string (e.g., "192.168.1.1").
@property (nonatomic, copy, readonly) NSString *localAddress;

/// Remote (destination) IPv4 address as dotted decimal string.
@property (nonatomic, copy, readonly) NSString *remoteAddress;

/// Local (source) TCP port.
@property (nonatomic, assign, readonly) UInt16 localPort;

/// Remote (destination) TCP port.
@property (nonatomic, assign, readonly) UInt16 remotePort;

/// Delegate for socket events (weak to avoid retain cycles).
@property (nonatomic, weak) id<TSTCPSocketDelegate> delegate;

@property (nonatomic, strong, readonly) TFTCPSocketRef *socketRef;

/// Current socket state (thread-safe via processQueue)
@property (nonatomic, assign, readonly) TFTCPSocketState socketState;

@property (nonatomic, assign, readonly) TFTCPSocketTerminationReason terminationReason;

/// Graceful close timeout in milliseconds. Default 5000ms.
@property (nonatomic, assign) NSUInteger closeTimeoutMS;

#pragma mark - Lifecycle

- (instancetype)initWithTCPPcb:(struct tcp_pcb *)pcb delegate:(nullable id<TSTCPSocketDelegate>)delegate NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithTCPPcb:(struct tcp_pcb *)pcb;

- (instancetype)init NS_UNAVAILABLE;

#pragma mark - Socket Operations

/**
 * Write data to the TCP socket.
 *
 * Threading:
 * - Safe to call from any thread.
 * - Actual write is dispatched asynchronously onto the socket's internal serial queue.
 */
- (void)writeData:(NSData *)data;

/**
 * Close the TCP socket gracefully (FIN).
 *
 * Threading:
 * - Safe to call from any thread.
 * - Close operation is scheduled on the socket's internal serial queue.
 */
- (void)close;

/**
 * Abort the TCP socket immediately (RST).
 *
 * Threading:
 * - Safe to call from any thread.
 * - Reset operation is scheduled on the socket's internal serial queue.
 */
- (void)reset;

/**
 * Check whether the socket is still valid.
 * 
 * @return YES if socket is still alive (Active or Closing)
 *
 * Threading:
 * - Thread-safe: dispatches to processQueue for state read.
 */
- (BOOL)isValid;

/**
 * Check whether the socket is connected and ready for I/O.
 *
 * @return YES if state is Connected; NO otherwise.
 * 
 * Threading:
 * - Thread-safe: dispatches to processQueue for state read.
 */
- (BOOL)isConnected;

- (void)teardown;

@end

NS_ASSUME_NONNULL_END
