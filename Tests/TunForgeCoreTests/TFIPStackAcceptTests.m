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
- (void)driveHandshakeExpectingAccept:(void (^)(TFTCPConnection *conn, TFTCPAcceptHandler handler))onAccept
                          expectation:(XCTestExpectation *)exp {
    self.acceptDelegate.onAccept = ^(TFTCPConnection *connection, TFTCPAcceptHandler handler) {
        onAccept(connection, handler);
        [exp fulfill];
    };

    const uint32_t peer = TFIPAddr(198, 18, 0, 2);
    const uint32_t local = TFIPAddr(198, 18, 0, 1);
    const uint16_t peerPort = 45000;
    const uint32_t peerISN = 1000;

    __block uint16_t listenPort = 0;
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
        for (NSData *p in self.outboundPackets) {
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
    XCTAssertNotNil(synAck, @"expected SYN-ACK from stack");

    uint32_t synAckSeq = 0;
    uint32_t synAckAck = 0;
    uint16_t synAckSrcPort = 0;
    XCTAssertTrue(TFIPPacketParseTCP(synAck, NULL, NULL, &synAckSrcPort, NULL, &synAckSeq, &synAckAck, NULL));
    XCTAssertEqual(synAckSrcPort, listenPort);
    XCTAssertEqual(synAckAck, peerISN + 1);

    [TFGlobalScheduler.shared packetsPerformSync:^{
        NSData *ack = TFIPPacketMakeTCPSegment(peer, local, peerPort, listenPort, peerISN + 1,
                                               synAckSeq + 1, kTFIPTCPFlagACK, 65535);
        [[TFIPStack defaultStack] inputPacket:ack];
    }];
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
    [self.outboundPackets removeAllObjects];
    [TFGlobalScheduler.shared packetsPerformSync:^{
        listenPort = TFIPStackTestingListenPort();
        XCTAssertGreaterThan(listenPort, 0);
        NSData *syn = TFIPPacketMakeTCPSegment(peer, local, peerPort, listenPort, peerISN, 0,
                                               kTFIPTCPFlagSYN, 65535);
        [[TFIPStack defaultStack] inputPacket:syn];
    }];

    NSData *synAck = nil;
    for (int i = 0; i < 20 && !synAck; i++) {
        for (NSData *p in self.outboundPackets) {
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
