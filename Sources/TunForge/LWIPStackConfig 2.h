//
//  LWIPStackConfig.h
//  TunForge
//
//  Configuration for LWIPStack singleton initialization.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IPv4Settings : NSObject
/// Initial IPv4 settings. If nil, sensible defaults are used.
@property (nonatomic, copy, nullable) NSString *ipAddress;   // e.g., "240.0.0.1"
@property (nonatomic, copy, nullable) NSString *netmask;     // e.g., "240.0.0.0"
@property (nonatomic, copy, nullable) NSString *gateway;     // e.g., "240.0.0.254"

@end

@interface LWIPStackConfig : NSObject

/// Serial processing queue to use. If nil, a default queue is created.
@property (nonatomic, strong, nullable) dispatch_queue_t processQueue;

/// Optional IPv4 settings to apply during initialization.
@property (nonatomic, strong, nullable) IPv4Settings *ipv4Settings;


/// Convenience constructor with optional components.
+ (instancetype)configWithQueue:(dispatch_queue_t _Nullable)queue
                  ipv4Settings:(IPv4Settings * _Nullable)ipv4Settings;

@end

NS_ASSUME_NONNULL_END
