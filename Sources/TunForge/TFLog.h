//
//  TFLog.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/15.
//  Unified logging header
//

#import <Foundation/Foundation.h>

#pragma mark - Module Log Macros

/**
 * Unified module log format: [ModuleName][InstancePointer] message
 * Usage:
 * TFLogModuleInfo(@"TSIPStack", @"Initialized with IP=%@", ip);
 */
#define TFLogModuleInfo(module, fmt, ...)    TFLogInfo([[NSString stringWithFormat:@"[%@][%p] " fmt, module, self, ##__VA_ARGS__] UTF8String])
#define TFLogModuleDebug(module, fmt, ...)   TFLogDebug([[NSString stringWithFormat:@"[%@][%p] " fmt, module, self, ##__VA_ARGS__] UTF8String])
#define TFLogModuleWarn(module, fmt, ...)    TFLogWarning([[NSString stringWithFormat:@"[%@][%p] " fmt, module, self, ##__VA_ARGS__] UTF8String])
#define TFLogModuleError(module, fmt, ...)   TFLogError([[NSString stringWithFormat:@"[%@][%p] " fmt, module, self, ##__VA_ARGS__] UTF8String])
#define TFLogModuleVerbose(module, fmt, ...) TFLogVerbose([[NSString stringWithFormat:@"[%@][%p] " fmt, module, self, ##__VA_ARGS__] UTF8String])

#pragma mark - C Log Functions

/// Low-level C logging functions used by macros above.
/// Declared here for compile-time visibility across Objective-C units.
void TFLogInfo(const char *msg);
void TFLogDebug(const char *msg);
void TFLogError(const char *msg);
void TFLogWarning(const char *msg);
void TFLogVerbose(const char *msg);
