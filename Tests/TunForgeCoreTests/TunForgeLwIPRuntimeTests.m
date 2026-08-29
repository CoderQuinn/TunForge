//
//  TunForgeLwIPRuntimeTests.m
//  TunForgeCoreTests
//

#import <XCTest/XCTest.h>

#import "TunForgeCore.h"
#import "TFTCPConnectionTestingAPI.h"
#import "TFTCPConnectionTestEnvironment.h"

@interface TunForgeLwIPRuntimeTests : XCTestCase
@end

@implementation TunForgeLwIPRuntimeTests

- (void)setUp {
    [super setUp];
    [TFTCPConnectionTestEnvironment installOnce];
}

- (void)tearDown {
    // Leave the compatibility TCP adapter running for sibling test suites.
    [[TunForgeLwIPRuntime defaultRuntime] performSync:^{
        TFIPStack *stack = [TFIPStack defaultStack];
        if (TFIPStackTestingListenPort() == 0) {
            [stack start];
        }
        stack.delegate = nil;
        stack.outboundHandler = nil;
    }];
    [super tearDown];
}

- (void)testDirectRuntime_startStopIsRepeatableWithoutTCPAdapter {
    TunForgeLwIPRuntime *runtime = [TunForgeLwIPRuntime defaultRuntime];

    [runtime performSync:^{
        TFIPStack *stack = [TFIPStack defaultStack];
        [stack stop];
        XCTAssertFalse(runtime.running);
        XCTAssertEqual(TFIPStackTestingListenPort(), 0);

        for (NSUInteger iteration = 0; iteration < 10; iteration++) {
            [runtime start];
            [runtime start];
            XCTAssertTrue(runtime.running);
            XCTAssertEqual(TFIPStackTestingListenPort(),
                           0,
                           @"neutral runtime must not install the TCP adapter");

            [runtime stop];
            [runtime stop];
            XCTAssertFalse(runtime.running);
            XCTAssertEqual(TFIPStackTestingListenPort(), 0);
        }

        [stack start];
        XCTAssertTrue(runtime.running);
        XCTAssertGreaterThan(TFIPStackTestingListenPort(), 0);
    }];
}

- (void)testSerializationFacade_isQueueBoundAndNestedSyncSafe {
    TunForgeLwIPRuntime *runtime = [TunForgeLwIPRuntime defaultRuntime];
    __block NSUInteger syncCount = 0;

    [runtime performSync:^{
        XCTAssertTrue(TFIsOnQueue(TFGetPacketsQueueKey()));
        syncCount++;
        [runtime performSync:^{
            XCTAssertTrue(TFIsOnQueue(TFGetPacketsQueueKey()));
            syncCount++;
        }];
    }];
    XCTAssertEqual(syncCount, 2UL);

    XCTestExpectation *asyncExp = [self expectationWithDescription:@"runtime async"];
    [runtime performAsync:^{
        XCTAssertTrue(TFIsOnQueue(TFGetPacketsQueueKey()));
        [asyncExp fulfill];
    }];
    [self waitForExpectations:@[ asyncExp ] timeout:3];
}

@end
