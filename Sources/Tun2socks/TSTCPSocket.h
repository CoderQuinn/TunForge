//
//  TSTCPSocket.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/13.
//
//

#import <Foundation/Foundation.h>
#include <netinet/in.h>
#include "lwip/tcp.h"
NS_ASSUME_NONNULL_BEGIN

@class TSTCPSocket;

@protocol TSTCPSocketDelegate <NSObject>

- (void)socketDidCloseLocally:(TSTCPSocket *)socket;

- (void)socketDidReset:(TSTCPSocket *)socket;

- (void)socketDidAbort:(TSTCPSocket *)socket;

- (void)socketDidClose:(TSTCPSocket *)socket;

- (void)socket:(TSTCPSocket *)socket didReadData:(NSData *)data;

- (void)socket:(TSTCPSocket *)socket didWriteDataOfLength:(NSUInteger)length;

@end

@interface TSTCPSocket : NSObject

@property (nonatomic, assign, readonly) struct in_addr sourceAddress;

@property (nonatomic, assign, readonly) struct in_addr destinationAddress;

@property (nonatomic, assign, readonly) UInt16 sourcePort;

@property (nonatomic, assign, readonly) UInt16 destinationPort;

- (instancetype)initWithTCPPcb:(struct tcp_pcb* _Nonnull)pcb queue:(dispatch_queue_t)queue;

- (void)setDelegate:(nullable id<TSTCPSocketDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
