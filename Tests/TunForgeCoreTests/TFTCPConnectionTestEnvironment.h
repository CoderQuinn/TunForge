//
//  TFTCPConnectionTestEnvironment.h
//  TunForgeCoreTests
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TFTCPConnectionTestEnvironment : NSObject

/// Configures `TFGlobalScheduler` and starts `TFIPStack` once per process (must be called from test `setUp`).
+ (void)installOnce;

@end

NS_ASSUME_NONNULL_END
