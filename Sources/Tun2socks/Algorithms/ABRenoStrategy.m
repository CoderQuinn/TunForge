#import "ABRenoStrategy.h"

@implementation ABRenoStrategy

- (uint32_t)initialWindow {
    // Start with a moderate window to avoid bursts.
    return 16 * 1024; // 16 KB
}

- (uint32_t)onAckWithWindow:(uint32_t)window acked:(uint32_t)acked mss:(uint32_t)mss {
    // Reno-style additive increase: cwnd += (MSS^2 / cwnd) per acked MSS-equivalent.
    double cwnd = (double)window;
    double mssD = (double)mss;
    double segments = MAX(1.0, acked / mssD);
    double deltaPerSeg = (mssD * mssD) / cwnd;
    double minDelta = mssD / 8.0; // avoid stalling growth when cwnd is large
    double delta = MAX(deltaPerSeg, minDelta) * segments;
    cwnd += delta;
    return (uint32_t)cwnd;
}

- (uint32_t)onCongestionWithWindow:(uint32_t)window mss:(uint32_t)mss {
    double mssD = (double)mss;
    double next = MAX(2.0 * mssD, (double)window * 0.5); // multiplicative decrease
    return (uint32_t)next;
}

@end
