#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Strategy interface for tuning the congestion window.
@protocol ABStrategy <NSObject>

/// Initial send window size in bytes.
- (uint32_t)initialWindow;

/// Called when ACKs arrive; returns the new window size in bytes.
- (uint32_t)onAckWithWindow:(uint32_t)window acked:(uint32_t)acked mss:(uint32_t)mss;

/// Called on congestion signal; returns the new window size in bytes.
- (uint32_t)onCongestionWithWindow:(uint32_t)window mss:(uint32_t)mss;

@end

NS_ASSUME_NONNULL_END
