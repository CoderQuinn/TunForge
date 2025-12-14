#import <Foundation/Foundation.h>
#include <netinet/in.h>

@class TCPSocketStats;

NS_ASSUME_NONNULL_BEGIN

@interface TCPSocketStatsReport : NSObject

@property (nonatomic, assign) NSUInteger identity;
@property (nonatomic, assign) uint16_t sourcePort;
@property (nonatomic, assign) uint16_t destinationPort;
@property (nonatomic, assign) uint32_t sourceAddressValue; // network byte order
@property (nonatomic, assign) uint32_t destinationAddressValue; // network byte order

@property (nonatomic, assign) uint64_t bytesRead;
@property (nonatomic, assign) uint64_t bytesWritten;
@property (nonatomic, assign) uint64_t packetsRead;
@property (nonatomic, assign) uint64_t packetsWritten;
@property (nonatomic, assign) uint64_t errors;

@property (nonatomic, assign) CFTimeInterval connectionTime;
@property (nonatomic, assign) CFTimeInterval lastActivityTime;
@property (nonatomic, assign) double readThroughput; // bytes/sec
@property (nonatomic, assign) double writeThroughput; // bytes/sec
@property (nonatomic, assign) NSTimeInterval idleDuration;

// Helper to get NSString representation of addresses
- (NSString *)sourceAddressString;
- (NSString *)destinationAddressString;

@end

NS_ASSUME_NONNULL_END
