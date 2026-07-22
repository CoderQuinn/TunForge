//
//  TFGlobalSchedulerTests.m
//  TunForgeCoreTests — queue-specific key binding and re-entrant sync safety
//

#import <XCTest/XCTest.h>

#import "TunForgeCore.h"
#import "TFQueueHelpers.h"
#import "TFTCPConnectionTestEnvironment.h"

@interface TFGlobalSchedulerTests : XCTestCase
@end

@implementation TFGlobalSchedulerTests

- (void)setUp {
    [super setUp];
    [TFTCPConnectionTestEnvironment installOnce];
}

- (void)testPacketsQueueKey_isBoundInsidePacketsPerform {
    __block BOOL onQueueInside = NO;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        onQueueInside = TFIsOnQueue(TFGetPacketsQueueKey());
    }];
    XCTAssertTrue(onQueueInside, @"packets key must be bound to packetsQueue");
}

- (void)testConnectionsQueueKey_isBoundInsideConnectionsPerform {
    __block BOOL onQueueInside = NO;
    [TFGlobalScheduler.shared connectionsPerformSync:^{
        onQueueInside = TFIsOnQueue(TFGetConnectionsQueueKey());
    }];
    XCTAssertTrue(onQueueInside, @"connections key must be bound to connectionsQueue");
}

- (void)testNestedPacketsPerformSync_doesNotDeadlock {
    __block NSInteger depth = 0;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        depth++;
        // Re-entrant sync on the same serial queue must run inline (no dispatch_sync).
        [TFGlobalScheduler.shared packetsPerformSync:^{
            depth++;
        }];
    }];
    XCTAssertEqual(depth, 2);
}

- (void)testNestedConnectionsPerformSync_doesNotDeadlock {
    __block NSInteger depth = 0;
    [TFGlobalScheduler.shared connectionsPerformSync:^{
        depth++;
        [TFGlobalScheduler.shared connectionsPerformSync:^{
            depth++;
        }];
    }];
    XCTAssertEqual(depth, 2);
}

- (void)testOffQueue_isNotReportedOnQueue {
    XCTAssertFalse(TFIsOnQueue(TFGetPacketsQueueKey()),
                   @"test thread must not be reported as on packetsQueue");
    XCTAssertFalse(TFIsOnQueue(TFGetConnectionsQueueKey()),
                   @"test thread must not be reported as on connectionsQueue");
}

- (void)testPacketsPerformAsync_onPacketsQueue_runsInline {
    __block NSInteger order = 0;
    __block NSInteger asyncSaw = 0;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        order = 1;
        [TFGlobalScheduler.shared packetsPerformAsync:^{
            // Already on packetsQueue → fast path runs inline before async returns.
            asyncSaw = order;
            order = 2;
        }];
        XCTAssertEqual(asyncSaw, 1);
        XCTAssertEqual(order, 2);
    }];
}

@end
