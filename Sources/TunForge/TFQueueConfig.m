//
//  TFQueueConfig.m
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/21.
//

#import "TFQueueConfig.h"

@interface TFQueueConfig()

@property (nonatomic, strong) dispatch_queue_t queue;

@property (nonatomic, assign) const void *queueKey;

@end

@implementation TFQueueConfig

+ (instancetype)configWithQueue:(dispatch_queue_t )queue queueKey:(const void *)queueKey {
    return [[self alloc] initWithQueue:queue queueKey:queueKey];
}

- (instancetype)initWithQueue:(dispatch_queue_t )queue queueKey:(const void *)queueKey {
    if (self = [super init]) {
         _queue = queue;
         _queueKey     = queueKey;
         dispatch_queue_set_specific(queue,
                                     queueKey,
                                     (__bridge void *)queue,
                                     NULL);
    }
    return self;
}

- (BOOL)isOnQueue {
    return dispatch_get_specific(self.queueKey) == (__bridge void * _Nullable)(self.queue);
}

@end

