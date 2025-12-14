//
//  IPStackAdaptiveBehavior.m
//  TunForge
//
//  Implements ABC + stats as an IPStackBehavior.
//

#import "IPStackAdaptiveBehavior.h"
#import "Algorithms/AeroBack.h"
#import "Algorithms/ABRenoStrategy.h"
#import <QuartzCore/QuartzCore.h>

@interface IPStackAdaptiveBehavior ()
@property (nonatomic, strong) IPStackStats *stats;
@property (nonatomic, strong) AeroBack *abc;
@property (nonatomic, assign) BOOL lowLatencyMode;
@end

@implementation IPStackAdaptiveBehavior

- (instancetype)init
{
    if (self = [super init]) {
        _stats = [[IPStackStats alloc] init];
        _abc = [[AeroBack alloc] initWithStrategy:[ABRenoStrategy new]];
        _lowLatencyMode = NO;
    }
    return self;
}

- (uint32_t)recommendedBatchThreshold
{
    if (self.lowLatencyMode) { return 0; }
    return [self.abc recommendedBatchThreshold];
}

- (uint32_t)recommendedFlushIntervalMs
{
    if (self.lowLatencyMode) { return 0; }
    return [self.abc recommendedFlushIntervalMs];
}

- (BOOL)isLowLatencyModeEnabled { return self.lowLatencyMode; }
- (void)setLowLatencyModeEnabled:(BOOL)enabled { self.lowLatencyMode = enabled; }
- (void)onPacketSentBytes:(uint32_t)bytes { [self.abc onPacketSent:bytes]; }

- (void)onBatchFlushedBytes:(uint32_t)bytes latency:(double)latency count:(NSUInteger)count
{
    [self.abc onBatchAcked:bytes averageLatency:latency maxLatency:latency];
    self.stats.packetsSent += count;
    self.stats.bytesSent += bytes;
    self.stats.lastUpdateTime = CACurrentMediaTime();
}

- (void)onPacketReceivedBytes:(uint32_t)bytes
{
    self.stats.packetsReceived++;
    self.stats.bytesReceived += bytes;
    self.stats.lastUpdateTime = CACurrentMediaTime();
}

@end
