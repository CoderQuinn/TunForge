//
//  IPStack.m
//  TunForge
//
//  Adaptive subclass: adds ABC + stats atop IPStackCore.
//

#import "IPStack.h"
#import "TCPSocket.h"
#import "TCPSocketStatsReport.h"
#import "IPStackAdaptiveBehavior.h"
#import "Algorithms/AeroBack.h" // needed for behaviorImpl property access

// C bridge functions exposed from Swift in TunForge target
extern void TFLogInfo(const char *msg);

@interface IPStack ()
@property (nonatomic, strong) dispatch_source_t statsTimer;
@property (nonatomic, strong) IPStackAdaptiveBehavior *behaviorImpl;
@end

@implementation IPStack
static IPStack *_shared = nil;

+(instancetype)defaultIPStack
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[IPStack alloc] init];
    });
    return _shared;
}

- (instancetype)init
{
    if (self = [super init]) {
        _behaviorImpl = [[IPStackAdaptiveBehavior alloc] init];
        self.behavior = _behaviorImpl;
    }
    return self;
}

#pragma mark - Public passthroughs

- (void)configureIPv4WithIP:(NSString *)ipAddress netmask:(NSString *)netmask gw:(NSString *)gateway
{ [super configureIPv4WithIP:ipAddress netmask:netmask gw:gateway]; }

- (void)suspendTimer { [super suspendTimer]; }
- (void)resumeTimer { [super resumeTimer]; }
- (void)receivedPacket:(NSData *)packet { [super receivedPacket:packet]; }
- (void)triggerFlushForDiagnostics { [super triggerFlushForDiagnostics]; }
- (BOOL)isOnProcessQueue { return [super isOnProcessQueue]; }
- (void)assertOnProcessQueue { [super assertOnProcessQueue]; }

#pragma mark - Stats reporting

- (void)stopStatsReporting
{
    if (self.statsTimer != nil) {
        dispatch_source_cancel(self.statsTimer);
        self.statsTimer = nil;
    }
}

- (void)startStatsReportingWithInterval:(NSTimeInterval)intervalSeconds
{
    if (intervalSeconds <= 0) { intervalSeconds = 15.0; }
    [self stopStatsReporting];
    self.statsTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.processQueue);
    uint64_t intervalNanos = (uint64_t)(intervalSeconds * NSEC_PER_SEC);
    dispatch_source_set_timer(self.statsTimer, DISPATCH_TIME_NOW + intervalNanos, intervalNanos, 1 * NSEC_PER_MSEC);

    __weak __typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.statsTimer, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { return; }

        [strongSelf.behaviorImpl.abc onStatsTick];

        NSArray<TCPSocketStatsReport *> *reports = [TCPSocket allSocketStatsReports];
        if (reports.count == 0) { return; }

        uint64_t bytesRead = 0, bytesWritten = 0, packetsRead = 0, packetsWritten = 0, errors = 0;
        for (TCPSocketStatsReport *r in reports) {
            bytesRead += r.bytesRead;
            bytesWritten += r.bytesWritten;
            packetsRead += r.packetsRead;
            packetsWritten += r.packetsWritten;
            errors += r.errors;
        }

        char buf[256];
        snprintf(buf, sizeof(buf), "[IPStack] sockets=%lu bytesR=%llu bytesW=%llu pktsR=%llu pktsW=%llu errors=%llu",
                 (unsigned long)reports.count,
                 bytesRead,
                 bytesWritten,
                 packetsRead,
                 packetsWritten,
                 errors);
        TFLogInfo(buf);

        if (strongSelf.delegate != nil && [strongSelf.delegate respondsToSelector:@selector(didUpdateSocketStats:)]) {
            [strongSelf.delegate didUpdateSocketStats:reports];
        }
    });

    dispatch_resume(self.statsTimer);
}

// Behavior-driven pacing/stats handled by behaviorImpl

#pragma mark - Stats snapshot

- (IPStackStatusSnapshot)statusSnapshot
{
    IPStackStatusSnapshot snap;
    snap.packetsReceived = self.behaviorImpl.stats.packetsReceived;
    snap.packetsSent = self.behaviorImpl.stats.packetsSent;
    snap.bytesReceived = self.behaviorImpl.stats.bytesReceived;
    snap.bytesSent = self.behaviorImpl.stats.bytesSent;
    snap.errorCount = self.behaviorImpl.stats.errorCount;
    snap.rxThroughputBytesPerSec = [self.behaviorImpl.stats receiveThroughputBytesPerSec];
    snap.txThroughputBytesPerSec = [self.behaviorImpl.stats sendThroughputBytesPerSec];
    return snap;
}

@end
