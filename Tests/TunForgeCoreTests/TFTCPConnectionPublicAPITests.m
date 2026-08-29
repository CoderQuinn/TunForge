//
//  TFTCPConnectionPublicAPITests.m
//  TunForgeCoreTests
//
//  Principal XCTestCase: shared `-setUp` only. Concrete `test*` methods live in
//  TFTCPConnectionPublicAPITests+*.m category files.
//

#import "TFTCPConnectionPublicAPITests.h"
#import "TFTCPConnectionTestEnvironment.h"

@implementation TFTCPConnectionPublicAPITests

- (void)setUp {
    [super setUp];
    [TFTCPConnectionTestEnvironment installOnce];
}

@end
