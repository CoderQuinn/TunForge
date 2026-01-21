//
//  TFTunForgeLog.h
//  TunForge
//
//  Created by MagicianQuinn on 2026/1/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TFTunForgeLog : NSObject

typedef NS_ENUM(NSUInteger, TFTunForgeLogLevel) {
    TFTunForgeLogLevelDebug = 0,
    TFTunForgeLogLevelInfo = 1,
    TFTunForgeLogLevelWarn = 2,
    TFTunForgeLogLevelError = 3,
    TFTunForgeLogLevelOff = 4
};

/// Call once by upper layer (App / Extension)
+ (void)initializeLogging;

/// Default level is Warn.
+ (void)setLevel:(TFTunForgeLogLevel)level;
+ (TFTunForgeLogLevel)level;

/// OC side logs
+ (void)info:(NSString *)message;
+ (void)debug:(NSString *)message;
+ (void)warn:(NSString *)message;
+ (void)error:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
