#import "TCPSocketStats.h"
#import <QuartzCore/QuartzCore.h>

@implementation TCPSocketStats

- (instancetype)init {
    if (self = [super init]) {
        _connectionTime = CACurrentMediaTime();
        _lastActivityTime = _connectionTime;
    }
    return self;
}

- (double)readThroughputBytesPerSec {
    double elapsed = self.lastActivityTime - self.connectionTime;
    return (elapsed > 0) ? (self.bytesRead / elapsed) : 0.0;
}

- (double)writeThroughputBytesPerSec {
    double elapsed = self.lastActivityTime - self.connectionTime;
    return (elapsed > 0) ? (self.bytesWritten / elapsed) : 0.0;
}

- (NSTimeInterval)idleDuration {
    return CACurrentMediaTime() - self.lastActivityTime;
}

- (void)reset {
    self.bytesRead = 0;
    self.bytesWritten = 0;
    self.packetsRead = 0;
    self.packetsWritten = 0;
    self.errors = 0;
    self.connectionTime = CACurrentMediaTime();
    self.lastActivityTime = self.connectionTime;
}

@end
