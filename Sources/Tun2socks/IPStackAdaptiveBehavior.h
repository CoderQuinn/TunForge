//
//  IPStackAdaptiveBehavior.h
//  TunForge
//
//  Adaptive pacing/stats strategy injected into IPStackCore.
//

#import <Foundation/Foundation.h>
#import "IPStackCore.h"
#import "IPStackStats.h"
@class AeroBack;

@interface IPStackAdaptiveBehavior : NSObject<IPStackBehavior>
@property (nonatomic, strong, readonly) IPStackStats *stats;
@property (nonatomic, strong, readonly) AeroBack *abc;
@end
