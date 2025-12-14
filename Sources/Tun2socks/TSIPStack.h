//
//
//  TSIPStack.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/13.
//
//

#import <Foundation/Foundation.h>

@class TSTCPSocket;

NS_ASSUME_NONNULL_BEGIN

typedef void(^OutboundHandler)(NSData * _Nullable packet, int family);

@protocol TSIPStackDelegate <NSObject>
@required
- (void)didAcceptTCPSocket:(TSTCPSocket * _Nonnull)socket;
@end

@interface TSIPStack : NSObject

@property (nullable, nonatomic, weak) id<TSIPStackDelegate> delegate;
@property (nonatomic, copy) OutboundHandler outboundHandler;
@property (nonatomic, strong, readonly) dispatch_queue_t processQueue;

+ (instancetype)defaultIPStack;
- (instancetype)init;

// Configure IPv4 before setup: call immediately after init/create.
- (void)configureIPv4WithIP:(NSString *)ipAddress netmask:(NSString *)netmask gw:(NSString *)gateway;

- (void)suspendTimer;
- (void)resumeTimer;

- (void)receivedPacket:(NSData *)packet;

- (BOOL)isOnProcessQueue;
- (void)assertOnProcessQueue;

@end

NS_ASSUME_NONNULL_END



