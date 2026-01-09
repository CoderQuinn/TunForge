//
//  TFTCPConnectionInfo.h
//  TunForge
//
//  Created by MagicianQuinn on 2026/1/1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TFTCPConnectionInfo : NSObject

/// dotted decimal string (e.g., "192.168.1.1").
@property (nonatomic, copy, readonly) NSString *srcIP;

@property (nonatomic, copy, readonly) NSString *dstIP;

@property (nonatomic, assign, readonly) UInt16 srcPort;

@property (nonatomic, assign, readonly) UInt16 dstPort;

- (instancetype)initWithSrcIP:(NSString *)srcIP
                      srcPort:(UInt16)srcPort
                        dstIP:(NSString *)dstIP
                      dstPort:(UInt16)dstPort NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
