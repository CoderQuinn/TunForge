//
//  LWIPStack.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/13.
//

#import <Foundation/Foundation.h>

@class LWTCPSocket;

NS_ASSUME_NONNULL_BEGIN

/// Outbound IP packet handler.
/// `family` is AF_INET or AF_INET6, or other.
typedef void(^OutboundHandler)(NSData * _Nullable packet, int family);

@protocol TSIPStackDelegate <NSObject>

/// Called when a new inbound TCP connection is accepted.
- (void)didAcceptTCPSocket:(LWTCPSocket * _Nonnull)socket;

@end

@class LWIPStackConfig, IPv4Settings;

@interface LWIPStack : NSObject

/// Delegate for inbound TCP connection events.
@property (nullable, nonatomic, weak) id<TSIPStackDelegate> delegate;

/// Queue on which delegate callbacks are dispatched.
/// If nil, callbacks default to main queue.
@property (nonatomic, strong, nullable) dispatch_queue_t delegateQueue;

/// Handler used to send raw IP packets out of the stack.
@property (nonatomic, copy) OutboundHandler outboundHandler;

@property (nonatomic, strong, readonly) LWIPStackConfig *config;
/// Exposed as read-only; mutated internally.
@property (nonatomic, strong, readonly) dispatch_queue_t processQueue;
/// Dedicated serial queue for all lwIP / IP stack processing.
@property (nonatomic, strong, readonly) IPv4Settings *ipv4Settings;

#pragma mark - Lifecycle

/// Shared singleton instance.
+ (instancetype)defaultIPStack;

/// Returns the singleton, applying the config only on first call.
/// - If the singleton already exists, the config is ignored and the existing instance is returned.
+ (instancetype)defaultIPStackWithConfig:(LWIPStackConfig *)config;

+ (instancetype)defaultIPStackWithProcessQueue:(dispatch_queue_t)queue;

+ (instancetype)defaultIPStackWithIPv4Settings:(IPv4Settings *)ipv4Settings;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

#pragma mark - Runtime Control

/// Suspend lwIP timeout processing.
- (void)suspendTimer;

/// Resume lwIP timeout processing.
- (void)resumeTimer;

#pragma mark - Packet Injection

/// Inject a raw IP packet into the stack.
///
/// Threading:
/// - Safe to call from any thread.
/// - Processing is dispatched onto the stack's processQueue.
- (void)receivedPacket:(NSData *)packet;

#pragma mark - Debug / Safety

/// Returns YES if the caller is currently executing on processQueue.
- (BOOL)isOnProcessQueue;

/// Asserts that the caller is executing on processQueue.
/// Intended for internal consistency checks and debug builds.
- (void)assertOnProcessQueue;

@end

NS_ASSUME_NONNULL_END
