//
//  TFIPStackAcceptTests.m
//  TunForgeCoreTests — accept-path / two-phase markActive / handler once-only
//

#import <XCTest/XCTest.h>

#import "TunForgeCore.h"
#import "TFQueueHelpers.h"
#import "TFTCPConnectionTestingAPI.h"
#import "TFTCPConnectionTestEnvironment.h"
#import "TFIPPacketTestHelpers.h"

#include "lwip/opt.h"

enum {
    kTFIPTCPFlagFIN = 0x01,
    kTFIPTCPFlagSYN = 0x02,
    kTFIPTCPFlagRST = 0x04,
    kTFIPTCPFlagPSH = 0x08,
    kTFIPTCPFlagACK = 0x10,
};

static uint32_t TFIPAddr(uint8_t a, uint8_t b, uint8_t c, uint8_t d) {
    return ((uint32_t)a << 24) | ((uint32_t)b << 16) | ((uint32_t)c << 8) | (uint32_t)d;
}

@interface TFIPStackAcceptTestDelegate : NSObject <TFIPStackDelegate>
@property (nonatomic, copy, nullable) void (^onAccept)(TFTCPConnection *connection, TFTCPAcceptHandler handler);
@property (nonatomic, assign) BOOL sawConnectionsQueue;
@property (nonatomic, assign) BOOL sawPacketsQueue;
@end

@interface TFIPStackAcceptWeakConnectionBox : NSObject
@property (nonatomic, weak, nullable) TFTCPConnection *connection;
@end

@implementation TFIPStackAcceptWeakConnectionBox
@end

@implementation TFIPStackAcceptTestDelegate
- (void)didAcceptNewTCPConnection:(TFTCPConnection *)connection handler:(TFTCPAcceptHandler)handler {
    self.sawConnectionsQueue = TFIsOnQueue(TFGetConnectionsQueueKey());
    self.sawPacketsQueue = TFIsOnQueue(TFGetPacketsQueueKey());
    if (self.onAccept) {
        self.onAccept(connection, handler);
    }
}
@end

@interface TFIPStackAcceptTests : XCTestCase
@property (nonatomic, strong) TFIPStackAcceptTestDelegate *acceptDelegate;
@property (nonatomic, strong) NSMutableArray<NSData *> *outboundPackets;
@end

@implementation TFIPStackAcceptTests

- (void)setUp {
    [super setUp];
    [TFTCPConnectionTestEnvironment installOnce];
    self.outboundPackets = [NSMutableArray array];
    self.acceptDelegate = [[TFIPStackAcceptTestDelegate alloc] init];

    __weak typeof(self) weakSelf = self;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        TFIPStack *stack = [TFIPStack defaultStack];
        stack.delegate = weakSelf.acceptDelegate;
        stack.outboundHandler = ^(NSArray<NSData *> *packets, NSArray<NSNumber *> *families) {
            (void)families;
            __strong typeof(weakSelf) self = weakSelf;
            if (!self)
                return;
            [self.outboundPackets addObjectsFromArray:packets];
        };
    }];
}

- (NSArray<NSData *> *)outboundPacketsSnapshot {
    __block NSArray<NSData *> *snapshot = nil;
    [TFGlobalScheduler.shared packetsPerformSync:^{
        snapshot = [self.outboundPackets copy];
    }];
    return snapshot;
}

- (void)clearOutboundPackets {
    [TFGlobalScheduler.shared packetsPerformSync:^{
        [self.outboundPackets removeAllObjects];
    }];
}

- (void)tearDown {
    [TFGlobalScheduler.shared packetsPerformSync:^{
        TFIPStack *stack = [TFIPStack defaultStack];
        stack.delegate = nil;
        stack.outboundHandler = nil;
    }];
    self.acceptDelegate = nil;
    self.outboundPackets = nil;
    [super tearDown];
}

/// Drive SYN → SYN/ACK → ACK through the default stack; fulfill when accept fires.
- (void)driveHandshakeFromPeerPort:(uint16_t)peerPort
                           peerISN:(uint32_t)peerISN
                   expectingAccept:(void (^)(TFTCPConnection *conn,
                                              TFTCPAcceptHandler handler))onAccept
                       expectation:(XCTestExpectation *)exp {
    self.acceptDelegate.onAccept = ^(TFTCPConnection *connection, TFTCPAcceptHandler handler) {
        onAccept(connection, handler);
        [exp fulfill];
    };

    const uint32_t peer = TFIPAddr(198, 18, 0, 2);
    const uint32_t local = TFIPAddr(198, 18, 0, 1);

    __block uint16_t listenPort = 0;
    [self clearOutboundPackets];
    [TFGlobalScheduler.shared packetsPerformSync:^{
        listenPort = TFIPStackTestingListenPort();
        XCTAssertGreaterThan(listenPort, 0);

        NSData *syn = TFIPPacketMakeTCPSegment(peer, local, peerPort, listenPort, peerISN, 0,
                                               kTFIPTCPFlagSYN, 65535);
        [[TFIPStack defaultStack] inputPacket:syn];
    }];

    // Wait briefly for SYN-ACK (outboundHandler is sync on packetsQueue, so it should
    // already be present after the sync block — but keep a short poll for safety).
    NSData *synAck = nil;
    for (int i = 0; i < 20 && !synAck; i++) {
        for (NSData *p in [self outboundPacketsSnapshot]) {
            uint8_t flags = 0;
            uint16_t destinationPort = 0;
            if (TFIPPacketParseTCP(p, NULL, NULL, NULL, &destinationPort, NULL, NULL, &flags) &&
                destinationPort == peerPort &&
                (flags & kTFIPTCPFlagSYN) && (flags & kTFIPTCPFlagACK)) {
                synAck = p;
                break;
            }
        }
        if (!synAck) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }
    }
    XCTAssertNotNil(synAck, @"expected SYN-ACK from stack");

    uint32_t synAckSeq = 0;
    uint32_t synAckAck = 0;
    uint16_t synAckSrcPort = 0;
    uint16_t synAckDstPort = 0;
    XCTAssertTrue(TFIPPacketParseTCP(synAck, NULL, NULL, &synAckSrcPort, &synAckDstPort,
                                     &synAckSeq, &synAckAck, NULL));
    XCTAssertEqual(synAckSrcPort, listenPort);
    XCTAssertEqual(synAckDstPort, peerPort);
    XCTAssertEqual(synAckAck, peerISN + 1);

    [TFGlobalScheduler.shared packetsPerformSync:^{
        NSData *ack = TFIPPacketMakeTCPSegment(peer, local, peerPort, listenPort, peerISN + 1,
                                               synAckSeq + 1, kTFIPTCPFlagACK, 65535);
        [[TFIPStack defaultStack] inputPacket:ack];
    }];
}

- (void)driveHandshakeExpectingAccept:(void (^)(TFTCPConnection *conn,
                                                 TFTCPAcceptHandler handler))onAccept
                          expectation:(XCTestExpectation *)exp {
    [self driveHandshakeFromPeerPort:45000
                             peerISN:1000
                     expectingAccept:onAccept
                         expectation:exp];
}

- (void)testAccept_delegateInvokedOnConnectionsQueue {
    XCTestExpectation *exp = [self expectationWithDescription:@"accept"];
    [self driveHandshakeExpectingAccept:^(TFTCPConnection *conn, TFTCPAcceptHandler handler) {
        XCTAssertTrue(self.acceptDelegate.sawConnectionsQueue);
        XCTAssertFalse(self.acceptDelegate.sawPacketsQueue);
        handler(NO);
        (void)conn;
    }
                            expectation:exp];
    [self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)testAccept_handlerYes_doesNotActivateUntilMarkActive {
    XCTestExpectation *acceptExp = [self expectationWithDescription:@"accept"];
    XCTestExpectation *activatedExp = [self expectationWithDescription:@"activated"];
    activatedExp.inverted = YES;

    __block TFTCPConnection *connRef = nil;
    [self driveHandshakeExpectingAccept:^(TFTCPConnection *conn, TFTCPAcceptHandler handler) {
        connRef = conn;
        conn.onActivated = ^(TFTCPConnection *c) {
            (void)c;
            [activatedExp fulfill];
        };
        handler(YES);
        // Still New: writes must be closed until markActive.
        [TFGlobalScheduler.shared packetsPerformSync:^{
            const char b[] = "x";
            TFTCPWriteResult r = [conn writeBytes:b length:1];
            XCTAssertEqual(r.status, TFTCPWriteClosed);
        }];
    }
                            expectation:acceptExp];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertNotNil(connRef);

    XCTestExpectation *realActivated = [self expectationWithDescription:@"markActive"];
    [TFGlobalScheduler.shared packetsPerformSync:^{
        connRef.onActivated = ^(TFTCPConnection *c) {
            (void)c;
            [realActivated fulfill];
        };
        [connRef markActive];
    }];
    [self waitForExpectationsWithTimeout:3 handler:nil];

    [TFGlobalScheduler.shared packetsPerformSync:^{
        [connRef abort];
    }];
}

- (void)testAccept_handlerNo_abortsAndTerminates {
    XCTestExpectation *acceptExp = [self expectationWithDescription:@"accept"];
    XCTestExpectation *termExp = [self expectationWithDescription:@"terminated"];
    __block TFTCPConnection *connRef = nil;

    [self driveHandshakeExpectingAccept:^(TFTCPConnection *conn, TFTCPAcceptHandler handler) {
        connRef = conn;
        conn.onTerminated = ^(TFTCPConnection *c, TFTCPConnectionTerminationReason reason) {
            (void)c;
            XCTAssertEqual(reason, TFTCPConnectionTerminationReasonAbort);
            [termExp fulfill];
        };
        handler(NO);
    }
                            expectation:acceptExp];

    [self waitForExpectationsWithTimeout:3 handler:nil];
    XCTAssertFalse(connRef.alive);
}

- (void)testAccept_handlerTwice_secondIgnored {
    XCTestExpectation *acceptExp = [self expectationWithDescription:@"accept"];
    XCTestExpectation *termExp = [self expectationWithDescription:@"terminated"];
    termExp.assertForOverFulfill = YES;
    __block TFTCPConnection *connRef = nil;

    [self driveHandshakeExpectingAccept:^(TFTCPConnection *conn, TFTCPAcceptHandler handler) {
        connRef = conn;
        conn.onTerminated = ^(TFTCPConnection *c, TFTCPConnectionTerminationReason reason) {
            (void)c;
            XCTAssertEqual(reason, TFTCPConnectionTerminationReasonAbort);
            [termExp fulfill];
        };
        handler(NO);
        handler(YES); // must not resurrect
    }
                            expectation:acceptExp];

    [self waitForExpectationsWithTimeout:3 handler:nil];
    XCTAssertFalse(connRef.alive);
}

- (void)testAccept_handlerYes_thenMarkActive_firesOnActivatedOnce {
    XCTestExpectation *acceptExp = [self expectationWithDescription:@"accept"];
    XCTestExpectation *activatedExp = [self expectationWithDescription:@"activated"];
    __block NSInteger fires = 0;
    __block TFTCPConnection *connRef = nil;

    [self driveHandshakeExpectingAccept:^(TFTCPConnection *conn, TFTCPAcceptHandler handler) {
        connRef = conn;
        conn.onActivated = ^(TFTCPConnection *c) {
            (void)c;
            fires++;
            [activatedExp fulfill];
        };
        handler(YES);
        [TFGlobalScheduler.shared packetsPerformSync:^{
            [conn markActive];
            [conn markActive];
        }];
    }
                            expectation:acceptExp];

    [self waitForExpectationsWithTimeout:3 handler:nil];
    XCTAssertEqual(fires, 1);

    [TFGlobalScheduler.shared packetsPerformSync:^{
        [connRef abort];
    }];
}

- (void)testInboundDisabled_realInputBoundsRefusedDataAndRetriesAfterEnable {
    XCTestExpectation *acceptExp = [self expectationWithDescription:@"accept"];
    XCTestExpectation *firstDeliveryExp = [self expectationWithDescription:@"first delivery"];
    XCTestExpectation *secondDeliveryExp = [self expectationWithDescription:@"retransmitted delivery"];
    firstDeliveryExp.assertForOverFulfill = YES;
    secondDeliveryExp.assertForOverFulfill = YES;

    const uint32_t peer = TFIPAddr(198, 18, 0, 2);
    const uint32_t local = TFIPAddr(198, 18, 0, 1);
    const uint16_t peerPort = 45333;
    const uint32_t peerISN = 5000;
    NSData *firstPayload = [@"slow" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *secondPayload = [@"more" dataUsingEncoding:NSUTF8StringEncoding];

    __block TFTCPConnection *connRef = nil;
    __block NSInteger deliveryCount = 0;
    [self driveHandshakeFromPeerPort:peerPort
                             peerISN:peerISN
                     expectingAccept:^(TFTCPConnection *conn, TFTCPAcceptHandler handler) {
                         connRef = conn;
                         conn.onReadableBytes = ^(TFTCPConnection *c,
                                                  const TFBytesSlice *slices,
                                                  NSUInteger sliceCount,
                                                  NSUInteger totalBytesLength,
                                                  TFTCPReceiveGateCompletion completion) {
                             NSMutableData *received =
                                 [NSMutableData dataWithCapacity:totalBytesLength];
                             for (NSUInteger index = 0; index < sliceCount; index++) {
                                 [received appendBytes:slices[index].bytes
                                                length:slices[index].length];
                             }

                             deliveryCount++;
                             if (deliveryCount == 1) {
                                 XCTAssertEqualObjects(received, firstPayload);
                                 [firstDeliveryExp fulfill];
                             } else if (deliveryCount == 2) {
                                 XCTAssertEqualObjects(received, secondPayload);
                                 [secondDeliveryExp fulfill];
                             } else {
                                 XCTFail(@"unexpected extra inbound delivery");
                             }

                             completion();
                             [TFGlobalScheduler.shared packetsPerformSync:^{
                                 [c acknowledgeDeliveredBytes:totalBytesLength];
                             }];
                         };
                         handler(YES);
                         [TFGlobalScheduler.shared packetsPerformSync:^{
                             [conn markActive];
                             // Keep the lifecycle gate disabled while the first two data
                             // segments enter the real input path.
                             [conn setInboundDeliveryEnabled:NO];
                         }];
                     }
                         expectation:acceptExp];
    [self waitForExpectations:@[ acceptExp ] timeout:3];

    uint32_t synAckSeq = 0;
    uint16_t listenPort = 0;
    for (NSData *packet in [self outboundPacketsSnapshot]) {
        uint16_t destinationPort = 0;
        uint8_t flags = 0;
        if (TFIPPacketParseTCP(packet, NULL, NULL, &listenPort, &destinationPort, &synAckSeq,
                              NULL, &flags) &&
            destinationPort == peerPort && (flags & kTFIPTCPFlagSYN) &&
            (flags & kTFIPTCPFlagACK)) {
            break;
        }
        listenPort = 0;
    }
    XCTAssertGreaterThan(listenPort, 0);

    NSData *firstSegment = TFIPPacketMakeTCPSegmentWithPayload(
        peer, local, peerPort, listenPort, peerISN + 1, synAckSeq + 1,
        kTFIPTCPFlagACK | kTFIPTCPFlagPSH, 65535, firstPayload);
    NSData *secondSegment = TFIPPacketMakeTCPSegmentWithPayload(
        peer, local, peerPort, listenPort, peerISN + 1 + (uint32_t)firstPayload.length,
        synAckSeq + 1, kTFIPTCPFlagACK | kTFIPTCPFlagPSH, 65535, secondPayload);

    [TFGlobalScheduler.shared packetsPerformSync:^{
        [[TFIPStack defaultStack] inputPacket:firstSegment];
        XCTAssertEqual(TFTCPConnectionTestingRefusedDataLength(connRef), firstPayload.length);
        XCTAssertEqual(deliveryCount, 0);

        // lwIP retries the retained first payload, sees the gate is still closed, and drops
        // the new data segment for TCP retransmission instead of growing refused_data.
        [[TFIPStack defaultStack] inputPacket:secondSegment];
        XCTAssertEqual(TFTCPConnectionTestingRefusedDataLength(connRef), firstPayload.length);
        XCTAssertEqual(deliveryCount, 0);

        [connRef setInboundDeliveryEnabled:YES];
        XCTAssertEqual(TFTCPConnectionTestingRetryRefusedData(connRef), ERR_OK);
        XCTAssertEqual(TFTCPConnectionTestingRefusedDataLength(connRef), 0UL);
    }];
    [self waitForExpectations:@[ firstDeliveryExp ] timeout:3];

    // Model the peer retransmission after the first refused payload has been accepted.
    [TFGlobalScheduler.shared packetsPerformSync:^{
        [[TFIPStack defaultStack] inputPacket:secondSegment];
    }];
    [self waitForExpectations:@[ secondDeliveryExp ] timeout:3];
    XCTAssertEqual(deliveryCount, 2);

    [TFGlobalScheduler.shared packetsPerformSync:^{
        [connRef abort];
    }];
}

- (void)testAccept_withoutMarkActive_newStateTimeoutAborts {
    XCTestExpectation *acceptExp = [self expectationWithDescription:@"accept"];
    XCTestExpectation *termExp = [self expectationWithDescription:@"newTimeout"];
    __block TFTCPConnection *connRef = nil;

    [self driveHandshakeExpectingAccept:^(TFTCPConnection *conn, TFTCPAcceptHandler handler) {
        connRef = conn;
        conn.onTerminated = ^(TFTCPConnection *c, TFTCPConnectionTerminationReason reason) {
            (void)c;
            XCTAssertEqual(reason, TFTCPConnectionTerminationReasonAbort);
            [termExp fulfill];
        };
        handler(YES);
        [TFGlobalScheduler.shared packetsPerformSync:^{
            TFTCPConnectionTestingAccelerateNewStateTimeout(conn);
            err_t r = TFTCPConnectionTestingTriggerPoll(conn);
            XCTAssertEqual(r, ERR_OK);
        }];
    }
                            expectation:acceptExp];

    [self waitForExpectationsWithTimeout:3 handler:nil];
    XCTAssertFalse(connRef.alive);
}

- (void)testAccept_hostDropsConnectionWithoutHandler_newRetainKeepsAliveUntilTimeout {
    // Regression: dropping the accept reference must not orphan the PCB/backlog.
    // New-state self-retain keeps the object alive so timeout can reclaim.
    XCTestExpectation *acceptExp = [self expectationWithDescription:@"accept"];
    XCTestExpectation *termExp = [self expectationWithDescription:@"timeoutReclaim"];

    __block __weak TFTCPConnection *weakConn = nil;
    [self driveHandshakeExpectingAccept:^(TFTCPConnection *conn, TFTCPAcceptHandler handler) {
        (void)handler; // intentionally never called
        weakConn = conn;
        conn.onTerminated = ^(TFTCPConnection *c, TFTCPConnectionTerminationReason reason) {
            (void)c;
            XCTAssertEqual(reason, TFTCPConnectionTerminationReasonAbort);
            [termExp fulfill];
        };
        // Drop strong refs from the host side; New-state retain must keep it alive.
    }
                            expectation:acceptExp];

    [self waitForExpectations:@[ acceptExp ] timeout:3];

    // Allow the accept async hop / autorelease pools to settle, then prove the object
    // is still alive via New-state retain (weakConn non-nil).
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    XCTAssertNotNil(weakConn, @"New-state retain must keep the connection alive");

    [TFGlobalScheduler.shared packetsPerformSync:^{
        TFTCPConnection *conn = weakConn;
        XCTAssertNotNil(conn);
        TFTCPConnectionTestingAccelerateNewStateTimeout(conn);
        (void)TFTCPConnectionTestingTriggerPoll(conn);
    }];

    [self waitForExpectations:@[ termExp ] timeout:3];
}

- (void)testAccept_droppedConnectionsTimeoutWithoutShrinkingBacklogUnderLoad {
    const NSUInteger backlogCapacity = (NSUInteger)TCP_DEFAULT_LISTEN_BACKLOG;
    const uint16_t firstPeerPort = 46000;
    const uint16_t overflowPeerPort = (uint16_t)(firstPeerPort + backlogCapacity);
    NSMutableArray<TFIPStackAcceptWeakConnectionBox *> *connectionBoxes =
        [NSMutableArray arrayWithCapacity:backlogCapacity];
    NSMutableArray<XCTestExpectation *> *terminationExpectations =
        [NSMutableArray arrayWithCapacity:backlogCapacity];

    // Fill the listener's delayed-accept backlog with host-dropped New connections.
    // The only strong ownership after each callback returns must be the connection's
    // New-state self-retain; no handler or markActive call is made.
    for (NSUInteger index = 0; index < backlogCapacity; index++) {
        XCTestExpectation *acceptExp =
            [self expectationWithDescription:[NSString stringWithFormat:@"accept-%lu",
                                                                          (unsigned long)index]];
        XCTestExpectation *termExp =
            [self expectationWithDescription:[NSString stringWithFormat:@"timeout-%lu",
                                                                          (unsigned long)index]];
        [terminationExpectations addObject:termExp];

        TFIPStackAcceptWeakConnectionBox *box = [[TFIPStackAcceptWeakConnectionBox alloc] init];
        [connectionBoxes addObject:box];
        uint16_t peerPort = (uint16_t)(firstPeerPort + index);
        uint32_t peerISN = 1000u + (uint32_t)(index * 4u);

        [self driveHandshakeFromPeerPort:peerPort
                                 peerISN:peerISN
                         expectingAccept:^(TFTCPConnection *conn, TFTCPAcceptHandler handler) {
                             (void)handler;
                             box.connection = conn;
                             conn.onTerminated = ^(TFTCPConnection *c,
                                                   TFTCPConnectionTerminationReason reason) {
                                 (void)c;
                                 XCTAssertEqual(reason, TFTCPConnectionTerminationReasonAbort);
                                 [termExp fulfill];
                             };
                         }
                             expectation:acceptExp];
        [self waitForExpectations:@[ acceptExp ] timeout:3];
        XCTAssertNotNil(box.connection,
                        @"New-state self-retain must survive host drop at index %lu",
                        (unsigned long)index);
    }

    // Prove the test actually reached the configured backlog limit: one more SYN must
    // not allocate a PCB or emit SYN-ACK while all delayed accepts remain outstanding.
    const uint32_t peer = TFIPAddr(198, 18, 0, 2);
    const uint32_t local = TFIPAddr(198, 18, 0, 1);
    const uint32_t overflowPeerISN = 9000;
    __block uint16_t listenPort = 0;
    [self clearOutboundPackets];
    [TFGlobalScheduler.shared packetsPerformSync:^{
        listenPort = TFIPStackTestingListenPort();
        NSData *syn = TFIPPacketMakeTCPSegment(peer, local, overflowPeerPort, listenPort,
                                               overflowPeerISN, 0, kTFIPTCPFlagSYN, 65535);
        [[TFIPStack defaultStack] inputPacket:syn];
    }];

    BOOL emittedOverflowSynAck = NO;
    for (NSData *packet in [self outboundPacketsSnapshot]) {
        uint16_t destinationPort = 0;
        uint8_t flags = 0;
        if (TFIPPacketParseTCP(packet, NULL, NULL, NULL, &destinationPort, NULL, NULL, &flags) &&
            destinationPort == overflowPeerPort && (flags & kTFIPTCPFlagSYN) &&
            (flags & kTFIPTCPFlagACK)) {
            emittedOverflowSynAck = YES;
            break;
        }
    }
    XCTAssertFalse(emittedOverflowSynAck, @"backlog must be full before timeout reclamation");

    // Accelerate every New-state timeout. tcp_abort must return every delayed-accept
    // slot, otherwise the final handshake below will still be rejected as backlog-full.
    [TFGlobalScheduler.shared packetsPerformSync:^{
        for (TFIPStackAcceptWeakConnectionBox *box in connectionBoxes) {
            TFTCPConnection *connection = box.connection;
            XCTAssertNotNil(connection);
            TFTCPConnectionTestingAccelerateNewStateTimeout(connection);
            XCTAssertEqual(TFTCPConnectionTestingTriggerPoll(connection), ERR_OK);
        }
    }];
    [self waitForExpectations:terminationExpectations timeout:10];

    XCTestExpectation *recoveredAcceptExp =
        [self expectationWithDescription:@"accept-after-backlog-timeout"];
    [self driveHandshakeFromPeerPort:overflowPeerPort
                             peerISN:overflowPeerISN
                     expectingAccept:^(TFTCPConnection *conn, TFTCPAcceptHandler handler) {
                         XCTAssertTrue(conn.alive);
                         handler(NO);
                     }
                         expectation:recoveredAcceptExp];
    [self waitForExpectations:@[ recoveredAcceptExp ] timeout:3];
}

- (void)testAccept_nilDelegate_abortsWithoutNotifying {
    XCTestExpectation *acceptExp = [self expectationWithDescription:@"shouldNotAccept"];
    acceptExp.inverted = YES;
    self.acceptDelegate.onAccept = ^(TFTCPConnection *connection, TFTCPAcceptHandler handler) {
        (void)connection;
        (void)handler;
        [acceptExp fulfill];
    };

    [TFGlobalScheduler.shared packetsPerformSync:^{
        [TFIPStack defaultStack].delegate = nil;
    }];

    const uint32_t peer = TFIPAddr(198, 18, 0, 2);
    const uint32_t local = TFIPAddr(198, 18, 0, 1);
    const uint16_t peerPort = 45222;
    const uint32_t peerISN = 3000;

    __block uint16_t listenPort = 0;
    [self clearOutboundPackets];
    [TFGlobalScheduler.shared packetsPerformSync:^{
        listenPort = TFIPStackTestingListenPort();
        XCTAssertGreaterThan(listenPort, 0);
        NSData *syn = TFIPPacketMakeTCPSegment(peer, local, peerPort, listenPort, peerISN, 0,
                                               kTFIPTCPFlagSYN, 65535);
        [[TFIPStack defaultStack] inputPacket:syn];
    }];

    NSData *synAck = nil;
    for (int i = 0; i < 20 && !synAck; i++) {
        for (NSData *p in [self outboundPacketsSnapshot]) {
            uint8_t flags = 0;
            if (TFIPPacketParseTCP(p, NULL, NULL, NULL, NULL, NULL, NULL, &flags) &&
                (flags & kTFIPTCPFlagSYN) && (flags & kTFIPTCPFlagACK)) {
                synAck = p;
                break;
            }
        }
        if (!synAck) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }
    }
    XCTAssertNotNil(synAck);
    uint32_t synAckSeq = 0;
    XCTAssertTrue(TFIPPacketParseTCP(synAck, NULL, NULL, NULL, NULL, &synAckSeq, NULL, NULL));

    [TFGlobalScheduler.shared packetsPerformSync:^{
        NSData *ack = TFIPPacketMakeTCPSegment(peer, local, peerPort, listenPort, peerISN + 1,
                                               synAckSeq + 1, kTFIPTCPFlagACK, 65535);
        [[TFIPStack defaultStack] inputPacket:ack];
    }];

    [self waitForExpectationsWithTimeout:0.5 handler:nil];

    // Stack must remain usable for subsequent accepts.
    [TFGlobalScheduler.shared packetsPerformSync:^{
        [TFIPStack defaultStack].delegate = self.acceptDelegate;
        XCTAssertGreaterThan(TFIPStackTestingListenPort(), 0);
    }];
}

@end
