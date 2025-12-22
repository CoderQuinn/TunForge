//
//  TFGlobalScheduler.m
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/21.
//

#import "TFGlobalScheduler.h"
#import "TFQueueHelpers.h"
#include "lwip/timeouts.h"
#include "lwip/init.h"
#import <os/lock.h>

@interface TFGlobalScheduler() {
    os_unfair_lock _configLock;
}

@property (nonatomic, strong) TFQueueConfig *processTFQueueConfig;
@property (nonatomic, strong) TFQueueConfig *delegateTFQueueConfig;

@property (nonatomic, strong) dispatch_source_t timer;
@property (atomic, assign) NSInteger acquireCount;
@property (atomic, assign) BOOL configured;

@end

@implementation TFGlobalScheduler

- (instancetype)init {
    NSAssert(NO, @"Use +shared");
    return nil;
}

- (instancetype)initPrivate
{
    self = [super init];
    if (self) {
        
        lwip_init();
        _configLock = OS_UNFAIR_LOCK_INIT;
        _acquireCount = 0;
        _configured = NO;
    }
    return self;
}

static TFGlobalScheduler *_instance;
+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] initPrivate];
    });
    return _instance;
}

#pragma mark - Public

- (void)configureWithProcessTFQueueConfig:(TFQueueConfig *)processQueue
                    delegateTFQueueConfig:(nullable TFQueueConfig *)delegateQueue {
    NSParameterAssert(processQueue);
    os_unfair_lock_lock(&_configLock);
    
    @try {
        NSAssert(!self.configured,
                 @"TFGlobalScheduler can only be configured once");
        NSAssert(self.acquireCount == 0,
                 @"Cannot configure after scheduler has started");
        
        self.processTFQueueConfig = processQueue;
        self.delegateTFQueueConfig = delegateQueue;
        self.configured = YES;
    } @finally {
        os_unfair_lock_unlock(&_configLock);
    }

}

- (void)acquire {
    NSAssert(self.configured,
              @"TFGlobalScheduler must be configured before acquire");
    
    [self processPerformSync:^{
        self.acquireCount += 1;
        if (self.acquireCount == 1) {
            [self startTimer];
        }
    }];
}

- (void)relinquish {
    if (!self.configured) {
        return;
    }
    
    [self processPerformSync:^{
        if (self.acquireCount <= 0) {
            return;
        }
        
        self.acquireCount -= 1;
        
        if (self.acquireCount == 0) {
            [self stopTimer];
        }
    }];
}

- (void)processPerformAsync:(dispatch_block_t _Nonnull)block {
    NSAssert(self.processTFQueueConfig, @"Scheduler not configured");
    NSAssert(block != nil, @"process block must not be nil");
    tf_perform_async(self.processTFQueueConfig.queue, self.processTFQueueConfig.queueKey, block);
}

- (void)processPerformSync:(dispatch_block_t _Nonnull)block {
    NSAssert(self.processTFQueueConfig, @"Scheduler not configured");
    NSAssert(block != nil, @"process block must not be nil");
    tf_perform_sync(self.processTFQueueConfig.queue, self.processTFQueueConfig.queueKey, block);
}

- (void)delegatePerformAsync:(dispatch_block_t _Nonnull)block {
    NSAssert(block != nil, @"delegate block must not be nil");

    if(self.delegateTFQueueConfig) {
        tf_perform_async(self.delegateTFQueueConfig.queue, self.delegateTFQueueConfig.queueKey, block);
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

#pragma mark - Private timer

- (void)startTimer {
    NSAssert(self.timer == nil, @"lwIP timer already running");
    
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.processTFQueueConfig.queue);
#ifdef TCP_TMR_INTERVAL
    uint64_t interval = TCP_TMR_INTERVAL; // tcp_tmr interval
#else
    uint64_t interval = 250; // Default tcp_tmr_interval in ms
#endif
    
    dispatch_source_set_timer(self.timer, DISPATCH_TIME_NOW, interval * NSEC_PER_MSEC, 1 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(self.timer, ^{
        sys_check_timeouts();
    });
    // Reset lwIP timeout state for a fresh lifecycle
    sys_restart_timeouts();
    dispatch_resume(self.timer);
}

- (void)stopTimer {
    if (!self.timer) {
        return;
    }
    
    dispatch_source_cancel(self.timer);
    self.timer = nil;
}

@end
