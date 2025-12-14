#import "TCPSocketStatsReport.h"
#import <arpa/inet.h>

@implementation TCPSocketStatsReport

- (NSString *)sourceAddressString {
    struct in_addr addr;
    addr.s_addr = _sourceAddressValue;
    char buf[INET_ADDRSTRLEN];
    if (inet_ntop(AF_INET, &addr, buf, sizeof(buf))) {
        return [NSString stringWithUTF8String:buf];
    }
    return @"0.0.0.0";
}

- (NSString *)destinationAddressString {
    struct in_addr addr;
    addr.s_addr = _destinationAddressValue;
    char buf[INET_ADDRSTRLEN];
    if (inet_ntop(AF_INET, &addr, buf, sizeof(buf))) {
        return [NSString stringWithUTF8String:buf];
    }
    return @"0.0.0.0";
}

@end
