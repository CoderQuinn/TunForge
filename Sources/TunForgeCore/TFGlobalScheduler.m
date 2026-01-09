//
//  TFGlobalScheduler.m
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/21.
//

#import "TFGlobalScheduler.h"
#import "TFQueueHelpers.h"
#import <os/lock.h>

@interface TFGlobalScheduler () {
    os_unfair_lock _configLock;
}

@property (nonatomic, strong) dispatch_queue_t packetsQueue;
@property (nonatomic, strong) dispatch_queue_t connectionsQueue;
@property (atomic, assign) BOOL configured;

@end

@implementation TFGlobalScheduler

- (instancetype)init {
    NSAssert(NO, @"Use +shared");
    return nil;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _configLock = OS_UNFAIR_LOCK_INIT;
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

/// Configure queues ONCE before first acquire.
- (void)configureWithPacketsQueue:(dispatch_queue_t)packetsQueue
                 connectionsQueue:(dispatch_queue_t)connectionsQueue {
    os_unfair_lock_lock(&_configLock);

    @try {
        NSAssert(!self.configured, @"TFGlobalScheduler can only be configured once");

        self.packetsQueue = packetsQueue;
        self.connectionsQueue = connectionsQueue;
        self.configured = YES;
    } @finally {
        os_unfair_lock_unlock(&_configLock);
    }
}

- (void)packetsPerformAsync:(dispatch_block_t _Nonnull)block {
    NSAssert(self.packetsQueue, @"Scheduler not configured");
    NSAssert(block != nil, @"process block must not be nil");
    tf_perform_async(self.packetsQueue, TFGetPacketsQueueKey(), block);
}

- (void)packetsPerformSync:(dispatch_block_t _Nonnull)block {
    NSAssert(self.packetsQueue, @"Scheduler not configured");
    NSAssert(block != nil, @"process block must not be nil");
    tf_perform_sync(self.packetsQueue, TFGetPacketsQueueKey(), block);
}

- (void)connectionsPerformSync:(dispatch_block_t _Nonnull)block {
    NSAssert(block != nil, @"delegate block must not be nil");
    NSAssert(self.connectionsQueue, @"Scheduler not configured");
    tf_perform_sync(self.connectionsQueue, TFGetConnectionsQueueKey(), block);
}

- (void)connectionsPerformAsync:(dispatch_block_t _Nonnull)block {
    NSAssert(block != nil, @"delegate block must not be nil");
    NSAssert(self.connectionsQueue, @"Scheduler not configured");

    tf_perform_async(self.connectionsQueue, TFGetConnectionsQueueKey(), block);
}

@end
