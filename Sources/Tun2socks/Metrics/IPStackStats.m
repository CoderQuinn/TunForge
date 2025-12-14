#import "IPStackStats.h"
#import <QuartzCore/QuartzCore.h>

@implementation IPStackStats

- (instancetype)init {
    if (self = [super init]) {
        _startTime = CACurrentMediaTime();
        _lastUpdateTime = _startTime;
    }
    return self;
}

- (double)receiveThroughputBytesPerSec {
    double elapsed = self.lastUpdateTime - self.startTime;
    return (elapsed > 0) ? (self.bytesReceived / elapsed) : 0.0;
}

- (double)sendThroughputBytesPerSec {
    double elapsed = self.lastUpdateTime - self.startTime;
    return (elapsed > 0) ? (self.bytesSent / elapsed) : 0.0;
}

- (double)errorRate {
    uint64_t total = self.packetsReceived + self.packetsSent;
    return (total > 0) ? ((double)self.errorCount / (double)total) : 0.0;
}

- (void)reset {
    self.packetsReceived = 0;
    self.packetsSent = 0;
    self.bytesReceived = 0;
    self.bytesSent = 0;
    self.errorCount = 0;
    self.startTime = CACurrentMediaTime();
    self.lastUpdateTime = self.startTime;
}

@end
