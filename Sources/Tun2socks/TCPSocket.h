//
//  TCPSocket.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/13.
//
//

#import <Foundation/Foundation.h>
#include <netinet/in.h>
#include "lwip/tcp.h"
#import "TCPSocketStatsReport.h"

@protocol TCPSocketDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface TCPSocket : NSObject

@property (nonatomic, assign, readonly) struct in_addr sourceAddress;

@property (nonatomic, assign, readonly) struct in_addr destinationAddress;

@property (nonatomic, assign, readonly) UInt16 sourcePort;

@property (nonatomic, assign, readonly) UInt16 destinationPort;

- (instancetype)initWithTCPPcb:(struct tcp_pcb* _Nonnull)pcb queue:(dispatch_queue_t)queue;

- (void)setDelegate:(nullable id<TCPSocketDelegate>)delegate;

// Snapshot all current sockets' stats (thread-safe)
+ (NSArray<TCPSocketStatsReport *> *)allSocketStatsReports;

@end

@protocol TCPSocketDelegate <NSObject>

- (void)socketDidCloseLocally:(TCPSocket *)socket;

- (void)socketDidReset:(TCPSocket *)socket;

- (void)socketDidAbort:(TCPSocket *)socket;

- (void)socketDidClose:(TCPSocket *)socket;

- (void)socket:(TCPSocket *)socket didReadData:(NSData *)data;

- (void)socket:(TCPSocket *)socket didWriteDataOfLength:(NSUInteger)length;

@end

NS_ASSUME_NONNULL_END
