//
//  TFGlobalScheduler.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/21.
//

#import <Foundation/Foundation.h>
#import "TFQueueConfig.h"

NS_ASSUME_NONNULL_BEGIN

#define TF_ASSERT_ON_LWIP_QUEUE() \
    NSAssert([TFGlobalScheduler.shared.processTFQueueConfig isOnQueue], \
             @"TFObjectRef must be used on lwIP process queue")

/*
 * Global scheduler driving lwip execution and delegate dispatch
 * TFQueueConfig is injected by upper(swift) layer and frozen on first acquire.
 */
@interface TFGlobalScheduler : NSObject

// Queue for lwIP core execution (sys_check_timeouts, tcp/ip input).
@property (nonatomic, strong, readonly) TFQueueConfig *processTFQueueConfig;

/*
 * Queue for delegate callbacks (optional).
 * If nil, callbacks will be dispatched onto main queue.
 */
@property (nonatomic, strong, readonly, nullable) TFQueueConfig *delegateTFQueueConfig;

/// Current acquire count(diagnostics / assertions only).
@property (atomic, readonly) NSInteger acquireCount;

+ (instancetype)shared;

/// Configure queues ONCE before first acquire.
- (void)configureWithProcessTFQueueConfig:(TFQueueConfig *)processQueue
                   delegateTFQueueConfig:(nullable TFQueueConfig *)delegateQueue;


/// acquire / relinquish form a reference-counted runtime gate.
/// They are NOT related to object lifetime or ARC.

/// Acquire lwIP scheduler (0 -> 1 starts timer).
- (void)acquire;

/// Release lwIP scheduler (1 -> 0 stops timer).
- (void)relinquish;

/// Execute block on lwIP process queue.
- (void)processPerformAsync:(dispatch_block_t _Nonnull)block;
- (void)processPerformSync:(dispatch_block_t _Nonnull)block;

/// Execute block on delegate queue (or main queue if not configured).
- (void)delegatePerformAsync:(dispatch_block_t _Nonnull)block;

@end

NS_ASSUME_NONNULL_END
