//
//  TFTCPConnectionPublicAPITests+Inbound.m
//  TunForgeCoreTests — inbound gate, receive paths, synthetic lwIP recv
//

#import "TFTCPConnectionPublicAPITests.h"
#import "TunForgeCore.h"
#import "TFTCPConnectionTestingAPI.h"

#import "lwip/pbuf.h"

@implementation TFTCPConnectionPublicAPITests (Inbound)

- (void)testSetInboundDeliveryEnabled_toggleNoopsWhenSame {
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        TFTCPConnection *conn = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [conn markActive];
        [conn setInboundDeliveryEnabled:NO];
        [conn setInboundDeliveryEnabled:NO];
        [conn setInboundDeliveryEnabled:YES];
        [conn setInboundDeliveryEnabled:YES];
        [conn abort];
    }];
}

- (void)testInboundDisabled_deliverReturnsErrMem_callerFreesPbuf {
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        TFTCPConnection *conn = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [conn markActive];
        [conn setInboundDeliveryEnabled:NO];
        struct pbuf *p = pbuf_alloc(PBUF_TRANSPORT, 4, PBUF_RAM);
        XCTAssertNotEqual(p, NULL);
        err_t r = TFTCPConnectionTestingDeliverInboundPbuf(conn, p);
        XCTAssertEqual(r, ERR_MEM);
        pbuf_free(p);
        [conn abort];
    }];
}

- (void)testOnReadable_compatibility_deliversPayload {
    XCTestExpectation *exp = [self expectationWithDescription:@"onReadable"];
    __block TFTCPConnection *connRef = nil;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        connRef = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [connRef markActive];
        [connRef setInboundDeliveryEnabled:YES];
        connRef.onReadable = ^(TFTCPConnection *c, NSData *data) {
            XCTAssertEqualObjects(data, [NSData dataWithBytes:"abc" length:3]);
            [exp fulfill];
        };
        struct pbuf *p = pbuf_alloc(PBUF_TRANSPORT, 3, PBUF_RAM);
        XCTAssertNotEqual(p, NULL);
        memcpy(p->payload, "abc", 3);
        err_t r = TFTCPConnectionTestingDeliverInboundPbuf(connRef, p);
        XCTAssertEqual(r, ERR_OK);
    }];
    [self waitForExpectationsWithTimeout:3 handler:nil];
    [TFGlobalScheduler.shared packetsPerformSync:^{
        [connRef abort];
    }];
}

- (void)testOnReadableBytes_completionFreesAndAllowsAck {
    XCTestExpectation *exp = [self expectationWithDescription:@"onReadableBytes"];
    __block TFTCPConnection *connRef = nil;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        connRef = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [connRef markActive];
        [connRef setInboundDeliveryEnabled:YES];
        connRef.onReadableBytes = ^(TFTCPConnection *c, const TFBytesSlice *slices, NSUInteger sliceCount,
                                     NSUInteger totalBytesLength, TFTCPReceiveGateCompletion completion) {
            XCTAssertEqual(totalBytesLength, 2UL);
            XCTAssertEqual(sliceCount, 1UL);
            XCTAssertNotEqual(slices[0].bytes, NULL);
            XCTAssertEqual(slices[0].length, 2UL);
            completion();
            [exp fulfill];
        };
        struct pbuf *p = pbuf_alloc(PBUF_TRANSPORT, 2, PBUF_RAM);
        XCTAssertNotEqual(p, NULL);
        memcpy(p->payload, "xy", 2);
        err_t r = TFTCPConnectionTestingDeliverInboundPbuf(connRef, p);
        XCTAssertEqual(r, ERR_OK);
    }];
    [self waitForExpectationsWithTimeout:3 handler:nil];
    [TFGlobalScheduler.shared packetsPerformSync:^{
        [connRef abort];
    }];
}

- (void)testAcknowledgeDeliveredBytes_withNoInflight_isNoOp {
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        TFTCPConnection *conn = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [conn markActive];
        [conn acknowledgeDeliveredBytes:100];
        [conn abort];
    }];
}

- (void)testSyntheticRecvErr_abortsConnection {
    XCTestExpectation *exp = [self expectationWithDescription:@"terminatedAfterRecvErr"];
    // Hold a strong ref across the wait: onTerminated is delivered asynchronously on the
    // connection's callback queue and captures self weakly, so the connection must outlive
    // the synchronous packets-queue block.
    __block TFTCPConnection *connRef = nil;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        connRef = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [connRef markActive];
        connRef.onTerminated = ^(TFTCPConnection *c, TFTCPConnectionTerminationReason reason) {
            XCTAssertEqual(reason, TFTCPConnectionTerminationReasonAbort);
            [exp fulfill];
        };
        struct pbuf *p = pbuf_alloc(PBUF_TRANSPORT, 1, PBUF_RAM);
        XCTAssertNotEqual(p, NULL);
        (void)TFTCPConnectionTestingDeliverInboundWithErr(connRef, p, ERR_BUF);
    }];
    [self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)testSyntheticFIN_invokesReadEOF {
    XCTestExpectation *exp = [self expectationWithDescription:@"readEOF"];
    __block TFTCPConnection *connRef = nil;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        connRef = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [connRef markActive];
        connRef.onReadEOF = ^(TFTCPConnection *c) {
            [exp fulfill];
        };
        err_t r = TFTCPConnectionTestingDeliverInboundPbuf(connRef, NULL);
        XCTAssertEqual(r, ERR_OK);
    }];
    [self waitForExpectationsWithTimeout:3 handler:nil];
    [TFGlobalScheduler.shared packetsPerformSync:^{
        [connRef abort];
    }];
}

- (void)testOnReadableBytes_partialThenFullAck_clearsInflight {
    XCTestExpectation *exp = [self expectationWithDescription:@"readable"];
    __block TFTCPConnection *connRef = nil;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        connRef = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [connRef markActive];
        [connRef setInboundDeliveryEnabled:YES];
        connRef.onReadableBytes = ^(TFTCPConnection *c, const TFBytesSlice *slices, NSUInteger sliceCount,
                                     NSUInteger totalBytesLength, TFTCPReceiveGateCompletion completion) {
            (void)c;
            (void)slices;
            (void)sliceCount;
            XCTAssertEqual(totalBytesLength, 4UL);
            completion();
            [exp fulfill];
        };
        struct pbuf *p = pbuf_alloc(PBUF_TRANSPORT, 4, PBUF_RAM);
        XCTAssertNotEqual(p, NULL);
        memcpy(p->payload, "abcd", 4);
        XCTAssertEqual(TFTCPConnectionTestingDeliverInboundPbuf(connRef, p), ERR_OK);
    }];
    [self waitForExpectationsWithTimeout:3 handler:nil];

    [TFGlobalScheduler.shared packetsPerformSync:^{
        XCTAssertEqual(TFTCPConnectionTestingInflightAckBytes(connRef), 4ULL);
        [connRef acknowledgeDeliveredBytes:2];
        XCTAssertEqual(TFTCPConnectionTestingInflightAckBytes(connRef), 2ULL);
        [connRef acknowledgeDeliveredBytes:2];
        XCTAssertEqual(TFTCPConnectionTestingInflightAckBytes(connRef), 0ULL);
        [connRef abort];
    }];
}

- (void)testOnReadableBytes_overAck_clampsToInflight {
    XCTestExpectation *exp = [self expectationWithDescription:@"readable"];
    __block TFTCPConnection *connRef = nil;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        connRef = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [connRef markActive];
        [connRef setInboundDeliveryEnabled:YES];
        connRef.onReadableBytes = ^(TFTCPConnection *c, const TFBytesSlice *slices, NSUInteger sliceCount,
                                     NSUInteger totalBytesLength, TFTCPReceiveGateCompletion completion) {
            (void)c;
            (void)slices;
            (void)sliceCount;
            (void)totalBytesLength;
            completion();
            [exp fulfill];
        };
        struct pbuf *p = pbuf_alloc(PBUF_TRANSPORT, 3, PBUF_RAM);
        XCTAssertNotEqual(p, NULL);
        memcpy(p->payload, "xyz", 3);
        XCTAssertEqual(TFTCPConnectionTestingDeliverInboundPbuf(connRef, p), ERR_OK);
    }];
    [self waitForExpectationsWithTimeout:3 handler:nil];

    [TFGlobalScheduler.shared packetsPerformSync:^{
        XCTAssertEqual(TFTCPConnectionTestingInflightAckBytes(connRef), 3ULL);
        [connRef acknowledgeDeliveredBytes:100];
        XCTAssertEqual(TFTCPConnectionTestingInflightAckBytes(connRef), 0ULL);
        [connRef abort];
    }];
}

- (void)testOnReadableBytes_doubleCompletion_isSafe {
    XCTestExpectation *exp = [self expectationWithDescription:@"readable"];
    __block TFTCPConnection *connRef = nil;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        connRef = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        [connRef markActive];
        [connRef setInboundDeliveryEnabled:YES];
        connRef.onReadableBytes = ^(TFTCPConnection *c, const TFBytesSlice *slices, NSUInteger sliceCount,
                                     NSUInteger totalBytesLength, TFTCPReceiveGateCompletion completion) {
            (void)c;
            (void)slices;
            (void)sliceCount;
            (void)totalBytesLength;
            completion();
            completion(); // programmer error; must not double-free
            [exp fulfill];
        };
        struct pbuf *p = pbuf_alloc(PBUF_TRANSPORT, 1, PBUF_RAM);
        XCTAssertNotEqual(p, NULL);
        memset(p->payload, 'z', 1);
        XCTAssertEqual(TFTCPConnectionTestingDeliverInboundPbuf(connRef, p), ERR_OK);
    }];
    [self waitForExpectationsWithTimeout:3 handler:nil];
    // Allow both completion hops to drain on packetsQueue.
    [TFGlobalScheduler.shared packetsPerformSync:^{
        [connRef abort];
    }];
}

- (void)testInboundBeforeMarkActive_returnsErrMem {
    [TFGlobalScheduler.shared packetsPerformSync:^{
        struct tcp_pcb *pcb = TFTCPConnectionTestingCreateSyntheticEstablishedPCB();
        XCTAssertNotEqual(pcb, NULL);
        TFTCPConnection *conn = [[TFTCPConnection alloc] initWithTCPPcb:pcb];
        // New + recvEnabled default NO
        struct pbuf *p = pbuf_alloc(PBUF_TRANSPORT, 2, PBUF_RAM);
        XCTAssertNotEqual(p, NULL);
        err_t r = TFTCPConnectionTestingDeliverInboundPbuf(conn, p);
        XCTAssertEqual(r, ERR_MEM);
        pbuf_free(p);
        [conn abort];
    }];
}

@end
