//
//  TFTCPConnectionTestEnvironment.m
//  TunForgeCoreTests
//

#import "TFTCPConnectionTestEnvironment.h"
#import "TunForgeCore.h"

@implementation TFTCPConnectionTestEnvironment

+ (void)installOnce {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_t pq = dispatch_queue_create("tunforge.unittest.packets", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_t cq = dispatch_queue_create("tunforge.unittest.connections", DISPATCH_QUEUE_SERIAL);
        [[TFGlobalScheduler shared] configureWithPacketsQueue:pq connectionsQueue:cq];

        [TFGlobalScheduler.shared packetsPerformSync:^{
            (void)[TFIPStack defaultStack];
            [[TFIPStack defaultStack] start];
        }];
    });
}

@end
