//
//  TFIPStack.h
//  TunForge
//
//  Created by MagicianQuinn on 2026/1/1.
//

#import <Foundation/Foundation.h>

@class TFTCPConnectionInfo, TFTCPConnection;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Outbound
/// Outbound raw IP packet handler.
///
/// Called from lwIP output path.
/// Execution is asynchronous.
typedef void (^OutboundHandler)(NSArray<NSData *> *packets, NSArray<NSNumber *> *families);

#pragma mark - Delegate

@protocol TFIPStackDelegate <NSObject>

/// Inbound TCP connection notification.
///
/// IMPORTANT:
/// - This is called asynchronously on the delegate queue.
/// - The handler MUST be called exactly once.
- (void)didAcceptNewTCPConnection:(TFTCPConnection *)connection
                          handler:(void (^)(BOOL accept))handler;

@end

#pragma mark - TFIPStack

/// TFIPStack
///
/// DESIGN CONTRACT
/// ----------------
/// TunForge runs a single global lwIP runtime.
///
/// - TFIPStack is NOT a per-instance TCP/IP stack.
/// - Multiple active stacks are forbidden.
/// - Violating this is a programmer error.
@interface TFIPStack : NSObject

+ (instancetype)defaultStack;

- (instancetype)init NS_UNAVAILABLE;

/// Outbound raw IP packet handler.
@property (nullable, nonatomic, copy) OutboundHandler outboundHandler;

@property (nullable, nonatomic, weak) id<TFIPStackDelegate> delegate;

- (void)start;

- (void)stop;

/// Inject a raw IP packet into lwIP.
- (void)inputPacket:(nonnull NSData *)packet;

@end

NS_ASSUME_NONNULL_END
