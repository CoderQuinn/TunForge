//
//  TFIPStackLifecycleTests.m
//  TunForgeCoreTests — start/stop restart and double-start idempotency
//

#import <XCTest/XCTest.h>

#import "TunForgeCore.h"
#import "TFTCPConnectionTestingAPI.h"
#import "TFTCPConnectionTestEnvironment.h"
#import "TFIPPacketTestHelpers.h"

enum {
    kTFIPTCPFlagSYN = 0x02,
    kTFIPTCPFlagACK = 0x10,
};

static uint32_t TFIPLifeAddr(uint8_t a, uint8_t b, uint8_t c, uint8_t d) {
    return ((uint32_t)a << 24) | ((uint32_t)b << 16) | ((uint32_t)c << 8) | (uint32_t)d;
}

@interface TFIPStackLifecycleAcceptDelegate : NSObject <TFIPStackDelegate>
@property (nonatomic, copy, nullable) void (^onAccept)(TFTCPConnection *connection, TFTCPAcceptHandler handler);
@end

@implementation TFIPStackLifecycleAcceptDelegate
- (void)didAcceptNewTCPConnection:(TFTCPConnection *)connection handler:(TFTCPAcceptHandler)handler {
    if (self.onAccept) {
        self.onAccept(connection, handler);
    }
}
@end

@interface TFIPStackLifecycleTests : XCTestCase
@property (nonatomic, strong) NSMutableArray<NSData *> *outboundPackets;
@property (nonatomic, strong) TFIPStackLifecycleAcceptDelegate *acceptDelegate;
@end

@implementation TFIPStackLifecycleTests

- (void)setUp {
    [super setUp];
    [TFTCPConnectionTestEnvironment installOnce];
    self.outboundPackets = [NSMutableArray array];
    self.acceptDelegate = [[TFIPStackLifecycleAcceptDelegate alloc] init];

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
    // Always leave the global stack running for sibling test suites.
    [TFGlobalScheduler.shared packetsPerformSync:^{
        TFIPStack *stack = [TFIPStack defaultStack];
        if (TFIPStackTestingListenPort() == 0) {
            [stack start];
        }
        stack.delegate = nil;
        stack.outboundHandler = nil;
    }];
    self.acceptDelegate = nil;
    self.outboundPackets = nil;
    [super tearDown];
}

- (void)testStopThenStart_restoresListener {
    [TFGlobalScheduler.shared packetsPerformSync:^{
        TFIPStack *stack = [TFIPStack defaultStack];
        XCTAssertGreaterThan(TFIPStackTestingListenPort(), 0);

        [stack stop];
        XCTAssertEqual(TFIPStackTestingListenPort(), 0);

        [stack start];
        XCTAssertGreaterThan(TFIPStackTestingListenPort(), 0);
    }];
}

- (void)testDoubleStart_isIdempotent {
    [TFGlobalScheduler.shared packetsPerformSync:^{
        TFIPStack *stack = [TFIPStack defaultStack];
        uint16_t portBefore = TFIPStackTestingListenPort();
        XCTAssertGreaterThan(portBefore, 0);

        [stack start];
        [stack start];

        uint16_t portAfter = TFIPStackTestingListenPort();
        XCTAssertEqual(portAfter, portBefore);
        XCTAssertGreaterThan(portAfter, 0);
    }];
}

- (void)testStopThenStart_acceptPathStillWorks {
    XCTestExpectation *acceptExp = [self expectationWithDescription:@"acceptAfterRestart"];
    __block TFTCPConnection *connRef = nil;

    [TFGlobalScheduler.shared packetsPerformSync:^{
        TFIPStack *stack = [TFIPStack defaultStack];
        [stack stop];
        [stack start];
        // Re-bind after restart (setUp bindings are fine, but stop clears readiness).
        stack.delegate = self.acceptDelegate;
    }];

    self.acceptDelegate.onAccept = ^(TFTCPConnection *connection, TFTCPAcceptHandler handler) {
        connRef = connection;
        handler(YES);
        [TFGlobalScheduler.shared packetsPerformSync:^{
            [connection markActive];
        }];
        [acceptExp fulfill];
    };

    const uint32_t peer = TFIPLifeAddr(198, 18, 0, 2);
    const uint32_t local = TFIPLifeAddr(198, 18, 0, 1);
    const uint16_t peerPort = 45111;
    const uint32_t peerISN = 2000;

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

    [self waitForExpectationsWithTimeout:3 handler:nil];
    XCTAssertNotNil(connRef);
    XCTAssertTrue(connRef.alive);

    [TFGlobalScheduler.shared packetsPerformSync:^{
        [connRef abort];
    }];
}

@end
