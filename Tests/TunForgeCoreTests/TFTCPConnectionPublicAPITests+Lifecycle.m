//
//  TFTCPConnectionPublicAPITests+Lifecycle.m
//  TunForgeCoreTests — lifecycle, activation, termination
//

#import "TFTCPConnectionPublicAPITests.h"
#import "TunForgeCore.h"
#import "TFTCPConnectionTestingAPI.h"
#import "TFQueueHelpers.h"

@implementation TFTCPConnectionPublicAPITests (Lifecycle)

- (void)testInit_exposesNonNilInfo {
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        TFTCPConnection *conn = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        XCTAssertNotNil(conn.info);
        XCTAssertTrue(conn.info.srcPort > 0);
        [conn abort];
    }];
}

- (void)testAliveWritable_initialState {
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        TFTCPConnection *conn = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        XCTAssertTrue(conn.alive);
        XCTAssertFalse(conn.writable);
        [conn abort];
    }];
}

- (void)testMarkActive_secondCallIsIgnored {
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        TFTCPConnection *conn = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [conn markActive];
        XCTAssertTrue(conn.alive);
        [conn markActive];
        XCTAssertTrue(conn.alive);
        [conn abort];
    }];
}

- (void)testGracefulClose_invokesOnTerminated {
    XCTestExpectation *exp = [self expectationWithDescription:@"terminated"];
    __block TFTCPConnection *connRef = nil;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        connRef = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [connRef markActive];
        connRef.onTerminated = ^(TFTCPConnection *c, TFTCPConnectionTerminationReason reason) {
            XCTAssertTrue(c == connRef);
            XCTAssertEqual(reason, TFTCPConnectionTerminationReasonClose);
            [exp fulfill];
        };
        [connRef gracefulClose];
    }];
    [self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)testAbort_invokesOnTerminatedWithAbortReason {
    XCTestExpectation *exp = [self expectationWithDescription:@"aborted"];
    __block TFTCPConnection *connRef = nil;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        connRef = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [connRef markActive];
        connRef.onTerminated = ^(TFTCPConnection *c, TFTCPConnectionTerminationReason reason) {
            XCTAssertTrue(c == connRef);
            XCTAssertEqual(reason, TFTCPConnectionTerminationReasonAbort);
            [exp fulfill];
        };
        [connRef abort];
    }];
    [self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)testOnActivated_firesOnceAfterMarkActive {
    XCTestExpectation *exp = [self expectationWithDescription:@"activated"];
    __block NSInteger fireCount = 0;
    __block TFTCPConnection *connRef = nil;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        connRef = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        connRef.onActivated = ^(TFTCPConnection *c) {
            fireCount++;
            [exp fulfill];
        };
        [connRef markActive];
    }];
    [self waitForExpectationsWithTimeout:3 handler:nil];
    XCTAssertEqual(fireCount, 1);
    [TFGlobalScheduler.shared packetsPerformSync:^{
        [connRef abort];
    }];
}

- (void)testNewStateTimeout_abortsWithoutMarkActive {
    XCTestExpectation *exp = [self expectationWithDescription:@"newTimeout"];
    __block TFTCPConnection *connRef = nil;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        connRef = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        connRef.onTerminated = ^(TFTCPConnection *c, TFTCPConnectionTerminationReason reason) {
            (void)c;
            XCTAssertEqual(reason, TFTCPConnectionTerminationReasonAbort);
            [exp fulfill];
        };
        TFTCPConnectionTestingAccelerateNewStateTimeout(connRef);
        err_t r = TFTCPConnectionTestingTriggerPoll(connRef);
        XCTAssertEqual(r, ERR_OK);
    }];
    [self waitForExpectationsWithTimeout:3 handler:nil];
    XCTAssertFalse(connRef.alive);
}

- (void)testOnActivated_runsOnPerConnectionQueueNotConnectionsQueue {
    XCTestExpectation *exp = [self expectationWithDescription:@"activatedQueue"];
    __block BOOL onConnections = YES;
    __block BOOL onPackets = YES;
    __block TFTCPConnection *connRef = nil;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        connRef = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        connRef.onActivated = ^(TFTCPConnection *c) {
            (void)c;
            onConnections = TFIsOnQueue(TFGetConnectionsQueueKey());
            onPackets = TFIsOnQueue(TFGetPacketsQueueKey());
            [exp fulfill];
        };
        [connRef markActive];
    }];
    [self waitForExpectationsWithTimeout:3 handler:nil];
    XCTAssertFalse(onConnections);
    XCTAssertFalse(onPackets);
    [TFGlobalScheduler.shared packetsPerformSync:^{
        [connRef abort];
    }];
}

- (void)testGracefulClose_clearsPCBPointer {
    XCTestExpectation *exp = [self expectationWithDescription:@"terminated"];
    __block TFTCPConnection *connRef = nil;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        connRef = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [connRef markActive];
        XCTAssertTrue(TFTCPConnectionTestingHasPCB(connRef));
        connRef.onTerminated = ^(TFTCPConnection *c, TFTCPConnectionTerminationReason reason) {
            (void)c;
            XCTAssertEqual(reason, TFTCPConnectionTerminationReasonClose);
            [exp fulfill];
        };
        [connRef gracefulClose];
        XCTAssertFalse(TFTCPConnectionTestingHasPCB(connRef));
    }];
    [self waitForExpectationsWithTimeout:3 handler:nil];
}

@end
