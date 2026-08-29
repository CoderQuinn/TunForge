//
//  TFIPStack.h
//  TunForge
//
//  Created by MagicianQuinn on 2026/1/1.
//

#import <Foundation/Foundation.h>

@class TFTCPConnectionInfo, TFTCPConnection;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Outbound
/// Outbound raw IP packet handler.
///
/// Invoked **synchronously** from the lwIP output path while running on
/// `TFGlobalScheduler.packetsQueue`. The handler MUST return quickly and MUST NOT block,
/// perform heavy work, or re-enter TunForge synchronously: doing so stalls lwIP timers and
/// every other connection. If the host needs to do expensive work, copy the packets and hop
/// to its own executor.
typedef void (^OutboundHandler)(NSArray<NSData *> *packets, NSArray<NSNumber *> *families);

/// Accept decision for an inbound TCP connection.
///
/// - `accept == YES`: ownership hand-off only. The connection is NOT activated yet; the host
///   MUST subsequently call `-[TFTCPConnection markActive]` (e.g. once the upstream is ready),
///   otherwise the connection aborts on a New-state timeout.
/// - `accept == NO`: reject the connection (aborts immediately).
///
/// Calling the handler more than once is a programmer error; only the first call takes effect.
typedef void (^TFTCPAcceptHandler)(BOOL accept);

#pragma mark - Delegate

@protocol TFIPStackDelegate <NSObject>

/// Inbound TCP connection notification.
///
/// IMPORTANT:
/// - Called asynchronously on the `connectionsQueue`.
/// - The handler MUST be called exactly once (extra calls are ignored).
/// - `handler(YES)` accepts ownership but does not activate; call `markActive` to establish.
- (void)didAcceptNewTCPConnection:(TFTCPConnection *)connection handler:(TFTCPAcceptHandler)handler;

@end

#pragma mark - TFIPStack

/// TFIPStack
///
/// DESIGN CONTRACT
/// ----------------
/// TunForge runs a single global lwIP runtime.
///
/// - TFIPStack is NOT a per-instance TCP/IP stack.
/// - Multiple active stacks are forbidden.
/// - Violating this is a programmer error.
/// - Mutable properties and mutating methods do not hop queues automatically; the host must
///   access them on `TFGlobalScheduler.packetsQueue`.
@interface TFIPStack : NSObject

+ (instancetype)defaultStack;

- (instancetype)init NS_UNAVAILABLE;

/// Outbound raw IP packet handler. Set on `TFGlobalScheduler.packetsQueue`.
@property (nullable, nonatomic, copy) OutboundHandler outboundHandler;

/// Stack-level accept delegate. Set on `TFGlobalScheduler.packetsQueue`.
@property (nullable, nonatomic, weak) id<TFIPStackDelegate> delegate;

/// Starts the global lwIP runtime. Must run on `TFGlobalScheduler.packetsQueue`.
- (void)start;

/// Stops the global lwIP runtime. Must run on `TFGlobalScheduler.packetsQueue`.
- (void)stop;

/// Injects a raw IP packet into lwIP. Must run on `TFGlobalScheduler.packetsQueue`.
- (void)inputPacket:(nonnull NSData *)packet;

@end

NS_ASSUME_NONNULL_END
