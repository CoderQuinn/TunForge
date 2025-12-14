//
//  IPStackCore.h
//  TunForge
//
//  Core lwIP bridge without ABC or stats. Handles TUN I/O, batching, and callbacks.
//

#import <Foundation/Foundation.h>

@class TCPSocket;

NS_ASSUME_NONNULL_BEGIN

typedef void(^OutboundHandler)(NSData * _Nullable packet, int family);

@protocol IPStackMetricsBehavior <NSObject>
- (void)onPacketSentBytes:(uint32_t)bytes;
- (void)onBatchFlushedBytes:(uint32_t)bytes latency:(double)latency count:(NSUInteger)count;
- (void)onPacketReceivedBytes:(uint32_t)bytes;
// Optional: provide stats backing for snapshot
- (id)statsObject;
@end

@protocol IPStackDelegate <NSObject>
@required
- (void)didAcceptTCPSocket:(TCPSocket * _Nonnull)socket;
@optional
- (void)didUpdateSocketStats:(NSArray * _Nonnull)reports; // concrete type supplied by subclass
@end

@interface IPStackCore : NSObject

@property (nullable, nonatomic, weak) id<IPStackDelegate> delegate;
@property (nonatomic, copy) OutboundHandler outboundHandler;
@property (nonatomic, strong, readonly) dispatch_queue_t processQueue;
@property (nonatomic, strong) id<IPStackBehavior> behavior; // strategy for pacing/low-latency/metrics

// Default singleton instance
+ (instancetype)defaultIPStack;

- (instancetype)init;

// Configure IPv4 before setup: call immediately after init/create.
- (void)configureIPv4WithIP:(NSString *)ipAddress netmask:(NSString *)netmask gw:(NSString *)gateway;

- (void)suspendTimer;
- (void)resumeTimer;

- (void)receivedPacket:(NSData *)packet;
- (void)triggerFlushForDiagnostics;

// Queue assertions: helpful to verify lwIP serialization requirements
- (BOOL)isOnProcessQueue;
- (void)assertOnProcessQueue;

// Minimal status snapshot for quick diagnostics
typedef struct {
	uint64_t packetsReceived;
	uint64_t packetsSent;
	uint64_t bytesReceived;
	uint64_t bytesSent;
	uint64_t errorCount;
	double rxThroughputBytesPerSec;
	double txThroughputBytesPerSec;
} IPStackStatusSnapshot;

- (IPStackStatusSnapshot)statusSnapshot;

// Start/stop periodic per-socket stats reporting (optional no-op)
- (void)startStatsReportingWithInterval:(NSTimeInterval)intervalSeconds;
- (void)stopStatsReporting;

// Internal hooks for behavior extension
- (void)onPacketSentBytes:(uint32_t)bytes;
- (void)onBatchFlushedBytes:(uint32_t)bytes latency:(double)latency count:(NSUInteger)count;
- (void)onPacketReceivedBytes:(uint32_t)bytes;

@end

NS_ASSUME_NONNULL_END
