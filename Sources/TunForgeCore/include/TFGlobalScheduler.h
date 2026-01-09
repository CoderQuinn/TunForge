//
//  TFGlobalScheduler.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/21.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * Global scheduler driving lwip execution and delegate dispatch
 * TFQueueConfig is injected by upper(swift) layer and frozen on first acquire.
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

/// Execute block on delegate queue
- (void)connectionsPerformSync:(dispatch_block_t _Nonnull)block;
- (void)connectionsPerformAsync:(dispatch_block_t _Nonnull)block;

@end

NS_ASSUME_NONNULL_END
