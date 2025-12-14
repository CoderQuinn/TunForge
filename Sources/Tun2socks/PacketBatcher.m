// PacketBatcher.m
#import "PacketBatcher.h"
#import "IPStackCore.h"
#include "lwip/pbuf.h"

@interface IPStackCore (Batching)
- (void)flushPendingLocked;
@end

@implementation PacketBatcher

- (instancetype)initWithStack:(IPStackCore *)stack {
    if (self = [super init]) {
        _stack = stack;
        _pendingPackets = [NSMutableArray array];
        _pendingBytes = 0;
        _flushScheduled = NO;
    }
    return self;
}

- (void)enqueuePbuf:(struct pbuf *)pbuf bytes:(uint32_t)bytes {
    [self.pendingPackets addObject:[NSValue valueWithPointer:pbuf]];
    self.pendingBytes += bytes;
}

- (void)scheduleFlushOnQueue:(dispatch_queue_t)queue afterMs:(uint32_t)ms {
    if ([self.stack isLowLatencyModeEnabled]) {
        self.flushScheduled = YES;
        dispatch_async(queue, ^{
            [self.stack flushPendingLocked];
        });
        return;
    }

    uint32_t threshold = [self.stack recommendedBatchThreshold];
    uint32_t totalBytes = self.pendingBytes;

    // If we already have enough bytes, flush immediately to cut latency
    if (threshold > 0 && totalBytes >= threshold) {
        self.flushScheduled = YES;
        dispatch_async(queue, ^{
            [self.stack flushPendingLocked];
        });
        return;
    }

    // Otherwise, use provided interval fallback to strategy if zero
    uint32_t intervalMs = (ms > 0) ? ms : [self.stack recommendedFlushIntervalMs];
    self.flushScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)intervalMs * NSEC_PER_MSEC), queue, ^{
        [self.stack flushPendingLocked];
    });
}

- (void)drainPendingIntoArray:(NSArray *__autoreleasing *)packets bytes:(uint32_t *)bytes {
    *packets = [self.pendingPackets copy];
    [self.pendingPackets removeAllObjects];
    *bytes = self.pendingBytes;
    self.pendingBytes = 0;
}

@end
