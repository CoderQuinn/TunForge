//
//  TSIPStack.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/13.
//

#import <Foundation/Foundation.h>

@class TSTCPSocket;

NS_ASSUME_NONNULL_BEGIN

/// Outbound IP packet handler.
/// `family` is AF_INET or AF_INET6, or other.
typedef void(^OutboundHandler)(NSData * _Nullable packet, int family);

@protocol TSIPStackDelegate <NSObject>

/// Called when a new inbound TCP connection is accepted.
- (void)didAcceptTCPSocket:(TSTCPSocket * _Nonnull)socket;

@end

@interface TSIPStack : NSObject

/// Delegate for inbound TCP connection events.
@property (nullable, nonatomic, weak) id<TSIPStackDelegate> delegate;

/// Queue on which delegate callbacks are dispatched.
/// If nil, callbacks default to main queue.
@property (nonatomic, strong, nullable) dispatch_queue_t delegateQueue;

/// Handler used to send raw IP packets out of the stack.
@property (nonatomic, copy) OutboundHandler outboundHandler;

/// Dedicated serial queue for all lwIP / IP stack processing.
@property (nonatomic, strong, readonly) dispatch_queue_t processQueue;

#pragma mark - Lifecycle

/// Shared singleton instance.
+ (instancetype)defaultIPStack;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

#pragma mark - Configuration

/// Configure IPv4 parameters before the stack becomes active.
/// Intended for virtual network setups (e.g. 192.168.0.0/16).
- (void)configureIPv4WithIP:(NSString *)ipAddress
                    netmask:(NSString *)netmask
                         gw:(NSString *)gateway;

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
