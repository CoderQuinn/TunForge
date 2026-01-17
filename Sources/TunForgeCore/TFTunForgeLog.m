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
static TFTunForgeLogLevel s_level = TFTunForgeLogLevelWarn;

static inline BOOL tf_should_log(TFTunForgeLogLevel level) {
    if (s_level == TFTunForgeLogLevelOff)
        return NO;
    if (!s_enabled || s_log == NULL)
        return NO;
    return level >= s_level;
}

+ (void)initializeLogging {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_enabled = YES;
        s_level = TFTunForgeLogLevelWarn;

        tf_log_init("TunForge.lwip");

        s_log = FLLogOCCreate(nil, @"TunForge.core");
        [self info:@"TunForge logging initialized"];
    });
}

+ (void)setEnabled:(BOOL)enabled {
    s_enabled = enabled;
}

+ (void)setLevel:(TFTunForgeLogLevel)level {
    s_level = level;
}

+ (TFTunForgeLogLevel)level {
    return s_level;
}

+ (void)info:(NSString *)message {
    if (!tf_should_log(TFTunForgeLogLevelInfo))
        return;
    FLLogOCInfoH(s_log, message.UTF8String);
}

+ (void)debug:(NSString *)message {
    if (!tf_should_log(TFTunForgeLogLevelDebug))
        return;
    FLLogOCDebugH(s_log, message.UTF8String);
}

+ (void)warn:(NSString *)message {
    if (!tf_should_log(TFTunForgeLogLevelWarn))
        return;
    FLLogOCWarnH(s_log, message.UTF8String);
}

+ (void)error:(NSString *)message {
    if (!tf_should_log(TFTunForgeLogLevelError))
        return;
    FLLogOCErrorH(s_log, message.UTF8String);
}

@end
