#import <Foundation/Foundation.h>
#import "ABStrategy.h"

typedef NS_ENUM(NSUInteger, ABState) {
    ABStateStartup,
    ABStateSteady,
    ABStateDrain
};

NS_ASSUME_NONNULL_BEGIN

/// Adaptive congestion/backpressure controller used between lwIP and TUN.
@interface AeroBack : NSObject

@property (nonatomic, readonly) uint32_t sendWindowBytes;
@property (nonatomic, readonly) uint32_t inflightBytes;
@property (nonatomic, readonly) ABState state;

@property (nonatomic) uint32_t minWindow;
@property (nonatomic) uint32_t maxWindow;

@property (nonatomic) double rttEWMA;
@property (nonatomic) double minRTT;
@property (nonatomic, readonly) double medianRTT;
@property (nonatomic, readonly) double maxRTT;

/// Recommended flush pacing interval in milliseconds based on window utilization and RTT.
- (uint32_t)recommendedFlushIntervalMs;

/// Recommended batch threshold (bytes) based on RTT and estimated queue depth.
- (uint32_t)recommendedBatchThreshold;

/// Recommended max parallel workers for flush based on cwnd/MSS.
- (uint32_t)recommendedMaxWorkers;

/// Update MSS to recalibrate min/max window bounds.
- (void)updateMSS:(uint32_t)mss;

- (instancetype)initWithStrategy:(id<ABStrategy>)strategy;

/// Return YES if sending `bytes` would stay within the congestion window.
- (BOOL)canSendBytes:(uint32_t)bytes;

/// Called before a packet is handed to the downstream path.
- (void)onPacketSent:(uint32_t)bytes;

/// Called when that packet has drained / been flushed.
- (void)onPacketAcked:(uint32_t)bytes latency:(double)latency;

/// Called when a batch has drained; provides aggregate stats.
- (void)onBatchAcked:(uint32_t)bytes averageLatency:(double)avgLatency maxLatency:(double)maxLatency;

/// Called on congestion signals (e.g., drop/backpressure/ECN).
- (void)onCongestionSignal;

/// Tick to decay EWMA/queue metrics at low overhead; call ~every 5-10ms.
- (void)onStatsTick;

@end

NS_ASSUME_NONNULL_END
