//
//  TFTCPConnectionInfo.m
//  TunForge
//
//  Created by MagicianQuinn on 2026/1/1.
//

#import "TFTCPConnectionInfo.h"

@implementation TFTCPConnectionInfo

- (instancetype)initWithSrcIP:(NSString *)srcIP
                      srcPort:(UInt16)srcPort
                        dstIP:(NSString *)dstIP
                      dstPort:(UInt16)dstPort {
    if (self = [super init]) {
        _srcIP = srcIP.copy;
        _srcPort = srcPort;
        _dstIP = dstIP.copy;
        _dstPort = dstPort;
    }
    return self;
}

@end
