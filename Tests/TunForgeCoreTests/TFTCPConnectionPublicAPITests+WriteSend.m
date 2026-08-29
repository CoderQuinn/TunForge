//
//  TFTCPConnectionPublicAPITests+WriteSend.m
//  TunForgeCoreTests — writeBytes / writeData / shutdownWrite / writable hint
//

#import "TFTCPConnectionPublicAPITests.h"
#import "TunForgeCore.h"
#import "TFTCPConnectionTestingAPI.h"

@implementation TFTCPConnectionPublicAPITests (WriteSend)

- (void)testWrite_beforeMarkActive_returnsClosed {
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        TFTCPConnection *conn = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        const char b[] = "x";
        TFTCPWriteResult r = [conn writeBytes:b length:1];
        XCTAssertEqual(r.status, TFTCPWriteClosed);
        XCTAssertEqual(r.written, 0UL);
        [conn abort];
    }];
}

- (void)testWrite_afterMarkActive_smallPayload_ok {
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        TFTCPConnection *conn = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [conn markActive];
        const char b[] = "hello";
        TFTCPWriteResult r = [conn writeBytes:b length:sizeof(b) - 1];
        XCTAssertEqual(r.status, TFTCPWriteOK);
        XCTAssertEqual(r.written, 5UL);
        [conn abort];
    }];
}

- (void)testWriteData_rejectsLengthOverU16 {
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        TFTCPConnection *conn = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [conn markActive];
        NSMutableData *d = [NSMutableData dataWithLength:(NSUInteger)UINT16_MAX + 1];
        TFTCPWriteResult r = [conn writeData:d];
        XCTAssertEqual(r.status, TFTCPWriteOverflow);
        XCTAssertEqual(r.written, 0UL);
        [conn abort];
    }];
}

- (void)testShutdownWrite_thenWriteReturnsClosed {
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        TFTCPConnection *conn = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [conn markActive];
        [conn shutdownWrite];
        const char b[] = "nope";
        TFTCPWriteResult r = [conn writeBytes:b length:4];
        XCTAssertEqual(r.status, TFTCPWriteClosed);
        [conn abort];
    }];
}

- (void)testOnWritableChanged_firesAfterSuccessfulWrite {
    XCTestExpectation *exp = [self expectationWithDescription:@"writable"];
    exp.assertForOverFulfill = NO;
    __block TFTCPConnection *connRef = nil;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        connRef = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [connRef markActive];
        connRef.onWritableChanged = ^(TFTCPConnection *c, BOOL writable) {
            (void)writable;
            [exp fulfill];
        };
        const char b[] = "ping";
        TFTCPWriteResult wr = [connRef writeBytes:b length:4];
        XCTAssertEqual(wr.status, TFTCPWriteOK);
    }];
    [self waitForExpectationsWithTimeout:3 handler:nil];
    [TFGlobalScheduler.shared packetsPerformSync:^{
        [connRef abort];
    }];
}

@end
