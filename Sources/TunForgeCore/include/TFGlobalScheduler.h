//
//  TFGlobalScheduler.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/21.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * Global scheduler driving lwIP execution and stack-level delegate dispatch.
 *
 * Both queues are supplied by the embedding host via `configureWithPacketsQueue:
 * connectionsQueue:` and are frozen on first acquire. Typical intent is to hop work onto
 * executors aligned with the host runtime (e.g. SwiftNIO `EventLoop`–bound queues) while
 * keeping lwIP strictly on `packetsQueue`.
 *
 * packetsQueue — lwIP + `TFTCPConnection` state (strictly serialized).
 *
 * connectionsQueue — stack-level delegate path only (e.g. `TFIPStack` accept → host);
 * not used for per-connection `TFTCPConnection` property callbacks (each connection uses
 * its own serial GCD queue for those).
 */
@interface TFGlobalScheduler : NSObject

@property (nonatomic, strong, readonly) dispatch_queue_t packetsQueue;
@property (nonatomic, strong, readonly) dispatch_queue_t connectionsQueue;

+ (instancetype)shared;

/// Configure queues ONCE before first acquire.
- (void)configureWithPacketsQueue:(dispatch_queue_t)packetsQueue
                 connectionsQueue:(dispatch_queue_t)connectionsQueue;

/// Execute block on lwIP process queue.
- (void)packetsPerformAsync:(dispatch_block_t _Nonnull)block;
- (void)packetsPerformSync:(dispatch_block_t _Nonnull)block;

/// Execute block on the stack-level `connectionsQueue` (e.g. accept delegate), not on a
/// per-TFTCPConnection callback queue.
- (void)connectionsPerformSync:(dispatch_block_t _Nonnull)block;
- (void)connectionsPerformAsync:(dispatch_block_t _Nonnull)block;

@end

NS_ASSUME_NONNULL_END
