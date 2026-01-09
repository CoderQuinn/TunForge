//
//  TFObjectRef.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// TFObjectRef is a retained bridge object for passing ObjC references into lwIP.
///
/// Ownership contract:
/// - Owner creates TFObjectRef normally.
/// - Call `retainedVoidPointer` and pass it into lwIP as `void *`.
/// - lwIP MUST call `TFObjectRefRelease(void *)` exactly once
///   when the lifetime ends (e.g. tcp_ext_arg destroy).
///
/// Semantics:
/// - `alive` is a logical liveness gate.
/// - `object` is weak and becomes nil after `invalidate`.
///
/// Threading:
/// - `invalidate` MUST be called on lwIP process queue.
@interface TFObjectRef : NSObject

/// Weak reference to the target object (valid only when alive == YES).
@property (nonatomic, weak, readonly, nullable) NSObject *object;

/// Logical liveness flag.
@property (nonatomic, assign, readonly) BOOL alive;

/// Designated initializer.
- (instancetype)initWithObject:(NSObject *)object NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Mark ref as invalid (does NOT free the ref itself).
- (void)invalidate;

/// Returns a retained void * pointer to pass into C.
/// This pointer MUST be released via TFObjectRefRelease().
- (void *)retainedVoidPointer;

@end

/// Release function to be called from C destroy callbacks.
/// Balances `retainedVoidPointer`.
FOUNDATION_EXPORT void TFObjectRefRelease(void *arg);

NS_ASSUME_NONNULL_END
