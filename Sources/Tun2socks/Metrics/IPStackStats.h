#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Lock-free stats: all updates must be on a single serial queue (caller's responsibility)
@interface IPStackStats : NSObject

@property (nonatomic, assign) uint64_t packetsReceived;
@property (nonatomic, assign) uint64_t packetsSent;
@property (nonatomic, assign) uint64_t bytesReceived;
@property (nonatomic, assign) uint64_t bytesSent;
@property (nonatomic, assign) uint64_t errorCount;
@property (nonatomic, assign) CFTimeInterval startTime;
@property (nonatomic, assign) CFTimeInterval lastUpdateTime;

// Derived metrics (computed on-demand)
- (double)receiveThroughputBytesPerSec;
- (double)sendThroughputBytesPerSec;
- (double)errorRate; // errors per packet

- (void)reset;

@end

NS_ASSUME_NONNULL_END
