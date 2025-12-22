//
//  TFObjectRef.m
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/22.
//



#import "TFObjectRef.h"
#import "TFGlobalScheduler.h"

@interface TFObjectRef()

@property (atomic, assign) BOOL alive;

@end

@implementation TFObjectRef

- (instancetype)initWithObject:(NSObject *)object {
    if (self = [super init]) {
        _object = object;
        _alive = YES;
    }
    return  self;
}

- (void)invalidate {
    TF_ASSERT_ON_LWIP_QUEUE();
    
    self.alive = NO;
    self.object = nil;
}

@end
