#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Lock-free stats: all updates must be on socket's serial queue (caller's responsibility)
@interface TCPSocketStats : NSObject

@property (nonatomic, assign) uint64_t bytesRead;
@property (nonatomic, assign) uint64_t bytesWritten;
@property (nonatomic, assign) uint64_t packetsRead;
@property (nonatomic, assign) uint64_t packetsWritten;
@property (nonatomic, assign) uint64_t errors;
@property (nonatomic, assign) CFTimeInterval connectionTime;
@property (nonatomic, assign) CFTimeInterval lastActivityTime;

// Derived metrics (computed on-demand)
- (double)readThroughputBytesPerSec;
- (double)writeThroughputBytesPerSec;
- (NSTimeInterval)idleDuration; // time since last activity

- (void)reset;

@end

NS_ASSUME_NONNULL_END
