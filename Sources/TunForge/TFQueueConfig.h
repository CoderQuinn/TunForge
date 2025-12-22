//
//  TFTFQueueConfig.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TFQueueConfig : NSObject
/// Serial processing queue to use. If nil, a default queue is created.
@property (nonatomic, strong, readonly) dispatch_queue_t queue;

@property (nonatomic, assign, readonly) const void *queueKey;


+ (instancetype)configWithQueue:(dispatch_queue_t )queue queueKey:(const void *)queueKey;

- (instancetype)initWithQueue:(dispatch_queue_t )queue queueKey:(const void *)queueKey;

- (BOOL)isOnQueue;

@end

NS_ASSUME_NONNULL_END
