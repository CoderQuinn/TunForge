//
//  TFObjectRef.m
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/22.
//

#import "TFObjectRef.h"
#import "TFQueueHelpers.h"

@interface TFObjectRef ()

@property (nonatomic, weak) NSObject *object;

@property (nonatomic, assign) BOOL alive;

@end

@implementation TFObjectRef

- (instancetype)initWithObject:(NSObject *)object {
    NSParameterAssert(object);
    if (self = [super init]) {
        _object = object;
        _alive = YES;
    }
    return self;
}

- (void)invalidate {
#if DEBUG
    TF_ASSERT_ON_PACKETS_QUEUE();
#endif
    _alive = NO;
    _object = nil;
}

- (void *)retainedVoidPointer {
    // Explicit ownership transfer to C / lwIP.
    return (__bridge_retained void *)self;
}

@end

void TFObjectRefRelease(void *arg) {
    if (!arg)
        return;

    // Balance __bridge_retained
    TFObjectRef *ref = (TFObjectRef *)CFBridgingRelease(arg);
    (void)ref;
}
