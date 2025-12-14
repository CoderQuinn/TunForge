//
//  IPStack.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/13.
//
//

#import <Foundation/Foundation.h>
#import "IPStackCore.h"

NS_ASSUME_NONNULL_BEGIN

@interface IPStack : IPStackCore

// Default singleton instance
+ (instancetype)defaultIPStack;

// Configure IPv4 before setup: call immediately after init/create.
// If not set, falls back to environment variables or defaults.
- (void)configureIPv4WithIP:(NSString *)ipAddress
				netmask:(NSString *)netmask
					gw:(NSString *)gateway;

- (void)suspendTimer;

- (void)resumeTimer;

- (void)receivedPacket:(NSData *)packet;

/// Trigger a manual flush of pending packets for diagnostics.
/// Safe to call from any thread; work is serialized on `processQueue`.
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

// Start/stop periodic per-socket stats reporting (logs + delegate callback if implemented)
- (void)startStatsReportingWithInterval:(NSTimeInterval)intervalSeconds;
- (void)stopStatsReporting;

@end

NS_ASSUME_NONNULL_END



