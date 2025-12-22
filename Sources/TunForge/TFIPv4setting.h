//
//  TFIPv4setting.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TFIPv4setting : NSObject

/// Initial IPv4 settings. If nil, sensible defaults are used.
@property (nonatomic, copy, nullable) NSString *ipAddress;   // e.g., "240.0.0.1"
@property (nonatomic, copy, nullable) NSString *netmask;     // e.g., "255.0.0.0"
@property (nonatomic, copy, nullable) NSString *gateway;     // e.g., "240.0.0.254"

@end

NS_ASSUME_NONNULL_END
