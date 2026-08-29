//
//  TunForgeLwIPRuntime.h
//  TunForge
//
//  Neutral ownership boundary for the process-global lwIP core.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Raw IP packets emitted by lwIP.
///
/// Invoked synchronously on the runtime's serial executor. The handler must return quickly,
/// must not block, and must not synchronously re-enter the runtime.
typedef void (^OutboundHandler)(NSArray<NSData *> *packets, NSArray<NSNumber *> *families);

/// Opaque, process-global lwIP runtime.
///
/// The runtime owns only lwIP initialization, one virtual netif, timers, raw packet input/output,
/// and access to the serial lwIP executor. It does not own TCP policy, sockets, UDP sessions,
/// tunnel state, DNS, or product configuration.
///
/// Lifecycle ownership is exclusive: hosts that use the compatibility `TFIPStack` adapter must
/// call lifecycle methods through that adapter and must not independently start or stop this
/// runtime.
///
/// `performSync:` and `performAsync:` may be called from any queue. Mutable properties and the
/// lifecycle/input methods must run inside one of those blocks (or otherwise already be on
/// `TFGlobalScheduler.packetsQueue`); they do not hop queues automatically.
@interface TunForgeLwIPRuntime : NSObject

/// The sole process-global runtime.
+ (instancetype)defaultRuntime;

- (instancetype)init NS_UNAVAILABLE;

/// Whether the netif and timer are active. Read on the runtime's serial executor.
@property (nonatomic, assign, readonly, getter=isRunning) BOOL running;

/// Raw IP output callback. Set on the runtime's serial executor.
@property (nullable, nonatomic, copy) OutboundHandler outboundHandler;

/// Executes work on the serial lwIP executor. Safe to call from any queue and safe to nest.
- (void)performSync:(dispatch_block_t)block;

/// Executes work on the serial lwIP executor. Safe to call from any queue.
- (void)performAsync:(dispatch_block_t)block;

/// Starts the netif and timer. Must run on the runtime's serial executor. Idempotent.
- (void)start;

/// Stops the timer and removes the netif. Must run on the runtime's serial executor. Idempotent.
- (void)stop;

/// Injects one raw IPv4 packet. Must run on the runtime's serial executor.
- (void)inputPacket:(NSData *)packet;

@end

NS_ASSUME_NONNULL_END
