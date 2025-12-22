//
//  TFObjectRef.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// TFObjectRef is a stable ObjC object whose pointer is stored in lwIP as void*.
/// It does NOT retain TFIPStack. Instead it uses weak nil + alive gate.
///
/// Threading contract:
/// - All retainIfAlive/releaseRef/invalidate operations MUST happen on lwIP process queue.

@interface TFObjectRef : NSObject

/// Unsafe pointer to the stack (only valid when alive == YES).
@property (atomic, weak, nullable) NSObject *object;

/// Logical liveness flag. Once NO, stack must never be used.
@property (atomic, assign, readonly) BOOL alive;

/// Create a new ref for the given stack. Owner holds one refcnt initially.
- (instancetype)initWithObject:(NSObject *)object NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;


/// Invalidate ref (sets alive=NO and stack=nil).
- (void)invalidate;

@end

NS_ASSUME_NONNULL_END
