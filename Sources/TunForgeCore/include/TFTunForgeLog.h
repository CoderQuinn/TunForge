//
//  TFTunForgeLog.h
//  TunForge
//
//  Created by MagicianQuinn on 2026/1/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TFTunForgeLog : NSObject

/// Call once by upper layer (App / Extension)
+ (void)initializeLogging;

/// OC side logs
+ (void)info:(NSString *)message;
+ (void)debug:(NSString *)message;
+ (void)warn:(NSString *)message;
+ (void)error:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
