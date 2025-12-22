//
//  TFIPStack.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/13.
//

#import <Foundation/Foundation.h>

@class TFTCPSocket;


NS_ASSUME_NONNULL_BEGIN

/// Outbound IP packets handler.
/// `family` is AF_INET or AF_INET6, or other.
typedef void(^OutboundHandler)(NSArray<NSData * >* packets, NSArray<NSNumber *> *families);

@protocol TSIPStackDelegate <NSObject>

/// Called when a new inbound TCP connection is accepted.
- (void)didAcceptTCPSocket:(TFTCPSocket * _Nonnull)socket;

@end

@class TFIPv4setting, TFQueueConfig;

@interface TFIPStack : NSObject

/// Handler used to send raw IP packets out of the stack.
@property (nonatomic, copy, nullable) OutboundHandler outboundHandler;

@property (nonatomic, strong, nullable, readonly) TFIPv4setting *setting;

/// Delegate for inbound TCP connection events.
@property (nullable, nonatomic, weak) id<TSIPStackDelegate> delegate;

#pragma mark - Lifecycle

/// Create a new stack with the given config.

+ (instancetype)stackWithSetting:(TFIPv4setting *_Nullable)setting;

+ (instancetype)stack;

- (instancetype)initWithSetting:(TFIPv4setting *_Nullable)setting NS_DESIGNATED_INITIALIZER;

/// Suspend lwIP timeout processing.
/// Only valid when state is Running.
- (void)suspendTimer;

/// Resume lwIP timeout processing.
/// Transitions from Initialized or Suspended to Running.
- (void)resumeTimer;

// Ensure ref is invalidated even if caller forgets to teardown explicitly.
// Must happen on lwIP process queue to satisfy TFObjectRef threading contract.
- (void)teardown;

/// Check if stack is ready to process packets.
- (BOOL)isReady;

/// Check if stack is currently running.
- (BOOL)isRunning;

/// Inject a raw IP packet into the stack.
///
/// Threading:
/// - Safe to call from any thread.
/// - Processing is dispatched onto the stack's processQueue.
- (void)receivedPacket:(NSData *)packet;

@end

NS_ASSUME_NONNULL_END
