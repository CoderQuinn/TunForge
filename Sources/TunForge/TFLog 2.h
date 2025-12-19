//
//  TFLog.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/15.
//  Unified logging header
//

#import <Foundation/Foundation.h>

// Swift C bridge functions
extern void TFLogInfo(const char *msg);
extern void TFLogDebug(const char *msg);
extern void TFLogError(const char *msg);
extern void TFLogWarning(const char *msg);
extern void TFLogVerbose(const char *msg);

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
