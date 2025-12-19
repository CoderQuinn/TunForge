//
//  LWIPStackConfig.m
//  TunForge
//

#import "LWIPStackConfig.h"

@implementation IPv4Settings
@end

@implementation LWIPStackConfig

+ (instancetype)configWithQueue:(dispatch_queue_t)queue
                      ipv4Settings:(IPv4Settings *)ipv4Settings {
     LWIPStackConfig *cfg = [LWIPStackConfig new];
     cfg.processQueue = queue;
     cfg.ipv4Settings = ipv4Settings;
     return cfg;
}

@end
