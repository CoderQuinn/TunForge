//
//  LWTCPSocket.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/13.
//

#import <Foundation/Foundation.h>
#import <netinet/in.h>

NS_ASSUME_NONNULL_BEGIN

@class LWTCPSocket;

@protocol TSTCPSocketDelegate <NSObject>

@optional

/// Remote peer performed a half-close (FIN) on read side.
- (void)socketDidShutdownRead:(LWTCPSocket *)socket;

/// Connection was reset (RST).
- (void)socketDidReset:(LWTCPSocket *)socket;

/// Connection was aborted due to fatal error.
- (void)socketDidAbort:(LWTCPSocket *)socket;

/// Connection closed (graceful or after reset).
- (void)socketDidClose:(LWTCPSocket *)socket;

/// Data received from remote peer.
- (void)socket:(LWTCPSocket *)socket didReadData:(NSData *)data;

/// Data successfully written to TCP send buffer.
- (void)socket:(LWTCPSocket *)socket didWriteDataOfLength:(NSUInteger)length;

@end

@interface LWTCPSocket : NSObject

/// Local (source) IPv4 address as dotted decimal string (e.g., "192.168.1.1").
@property (nonatomic, copy, readonly) NSString *sourceAddress;

/// Remote (destination) IPv4 address as dotted decimal string (e.g., "192.168.1.1").
@property (nonatomic, copy, readonly) NSString *destinationAddress;

/// Local (source) TCP port.
@property (nonatomic, assign, readonly) UInt16 sourcePort;

/// Remote (destination) TCP port.
@property (nonatomic, assign, readonly) UInt16 destinationPort;

/// Delegate for socket events (weak to avoid retain cycles).
@property (nonatomic, weak) id<TSTCPSocketDelegate> delegate;

/// Queue on which delegate callbacks are dispatched.
/// If nil, callbacks default to main queue.
@property (nonatomic, strong, nullable) dispatch_queue_t delegateQueue;

/// Designated initializer.
///
/// @param pcb   lwIP tcp_pcb (must be non-NULL)
/// @param queue Dedicated serial queue for all lwIP interactions
- (instancetype)initWithTCPPcb:(struct tcp_pcb *)pcb
                         queue:(dispatch_queue_t)queue
                      delegate:(id<TSTCPSocketDelegate>)delegate
                 delegateQueue:(dispatch_queue_t)delegateQueue NS_DESIGNATED_INITIALIZER;

/// Designated initializer.
///
/// @param pcb   lwIP tcp_pcb (must be non-NULL)
/// @param queue Dedicated serial queue for all lwIP interactions
- (instancetype)initWithTCPPcb:(struct tcp_pcb *)pcb
                         queue:(dispatch_queue_t)queue;

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
 * Threading:
 * - This method synchronously queries the socket state on the internal serial queue.
 */
- (BOOL)isValid;

/**
 * Check whether the socket is connected.
 *
 * Threading:
 * - This method synchronously queries the socket state on the internal serial queue.
 */
- (BOOL)isConnected;

#pragma mark - Debug / Safety

/// Returns YES if the caller is currently executing on the socket's internal queue.
- (BOOL)isOnSocketQueue;

/// Asserts that the caller is executing on the socket's internal queue.
/// Intended for internal consistency checks and debug builds.
- (void)assertOnSocketQueue;

@end

NS_ASSUME_NONNULL_END
