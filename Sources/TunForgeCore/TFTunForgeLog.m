//
//  TFTunForgeLog.m
//  TunForge
//
//  Created by MagicianQuinn on 2026/1/2.
//

#import "TFTunForgeLog.h"
#import "tf_lwip_log.h"
@import ForgeLogKitOC;
@import ForgeLogKitC;

/*
tunforge.core        // stack lifecycle
tunforge.lwip        // lwIP hook / tcp_input / timers
tunforge.tcp         // TFTCPConnection / socket
*/

@implementation TFTunForgeLog

static BOOL s_enabled = NO;
static FLLogOCHandle s_log;

+ (void)initializeLogging {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_enabled = YES;

        tf_log_init("TunForge.lwip");

        s_log = FLLogOCCreate(nil, @"TunForge.core");
        [self info:@"TunForge logging initialized"];
    });
}

+ (void)setEnabled:(BOOL)enabled {
    s_enabled = enabled;
}

+ (BOOL)isEnabled {
    return s_enabled && s_log != NULL;
}

+ (void)info:(NSString *)message {
    if (![self isEnabled])
        return;
    FLLogOCInfoH(s_log, message.UTF8String);
}

+ (void)debug:(NSString *)message {
    if (![self isEnabled])
        return;
    FLLogOCDebugH(s_log, message.UTF8String);
}

+ (void)warn:(NSString *)message {
    if (![self isEnabled])
        return;
    FLLogOCWarnH(s_log, message.UTF8String);
}

+ (void)error:(NSString *)message {
    if (![self isEnabled])
        return;
    FLLogOCErrorH(s_log, message.UTF8String);
}

@end
