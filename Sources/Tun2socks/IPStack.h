//
//
//  IPStack.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/13.
//
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
- (void)didUpdateSocketStats:(NSArray * _Nonnull)reports;
@end

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

@interface IPStack : NSObject

@property (nullable, nonatomic, weak) id<IPStackDelegate> delegate;
@property (nonatomic, copy) OutboundHandler outboundHandler;
@property (nonatomic, strong, readonly) dispatch_queue_t processQueue;
@property (nonatomic, strong) id<IPStackMetricsBehavior> behavior; // metrics hook

+ (instancetype)defaultIPStack;
- (instancetype)init;

// Configure IPv4 before setup: call immediately after init/create.
- (void)configureIPv4WithIP:(NSString *)ipAddress netmask:(NSString *)netmask gw:(NSString *)gateway;

- (void)suspendTimer;
- (void)resumeTimer;

- (void)receivedPacket:(NSData *)packet;
- (void)triggerFlushForDiagnostics;

- (BOOL)isOnProcessQueue;
- (void)assertOnProcessQueue;

- (IPStackStatusSnapshot)statusSnapshot;
- (void)startStatsReportingWithInterval:(NSTimeInterval)intervalSeconds; // currently no-op
- (void)stopStatsReporting; // currently no-op

@end

NS_ASSUME_NONNULL_END



