#import "AeroBack.h"
#import <QuartzCore/QuartzCore.h>
#import <os/lock.h>
#import <sys/sysctl.h>

static const CFTimeInterval kABTuneIntervalSeconds = 0.05; // min spacing between window tunes
static const uint32_t kABDefaultMinWindow = 4 * 1024;
static const uint32_t kABDefaultMaxWindow = 512 * 1024;
static const uint32_t kABDefaultMSS = 1460;
static uint32_t kABCachedCPUCores = 0;

static inline uint32_t _abClamp(uint32_t value, uint32_t minValue, uint32_t maxValue) {
    if (value < minValue) { return minValue; }
    if (value > maxValue) { return maxValue; }
    return value;
}

// QuickSelect for median: O(n) expected time, in-place on caller's buffer
static double _abQuickSelectMedian(double *arr, uint32_t n) {
    if (n == 0) return 0.0;
    if (n == 1) return arr[0];
    // For even n, average two middle elements
    uint32_t mid = n / 2;
    // Simple partition-based selection (in-place)
    uint32_t left = 0, right = n - 1;
    while (left < right) {
        double pivot = arr[right];
        uint32_t i = left;
        for (uint32_t j = left; j < right; j++) {
            if (arr[j] < pivot) {
                double t = arr[i]; arr[i] = arr[j]; arr[j] = t;
                i++;
            }
        }
        double t = arr[i]; arr[i] = arr[right]; arr[right] = t;
        if (i == mid) break;
        if (i < mid) left = i + 1;
        else right = i - 1;
    }
    if (n % 2 == 1) return arr[mid];
    // Even: find max of left half for average
    double maxLeft = arr[0];
    for (uint32_t i = 0; i < mid; i++) if (arr[i] > maxLeft) maxLeft = arr[i];
    return (maxLeft + arr[mid]) / 2.0;
}

static uint32_t _abGetCPUCores(void) {
    if (kABCachedCPUCores > 0) return kABCachedCPUCores;
    int cores = 0;
    size_t len = sizeof(cores);
    if (sysctlbyname("hw.ncpu", &cores, &len, NULL, 0) == 0 && cores > 0) {
        kABCachedCPUCores = (uint32_t)cores;
    } else {
        kABCachedCPUCores = 4; // fallback
    }
    return kABCachedCPUCores;
}

@interface AeroBack ()
{
    os_unfair_lock _lock;
    double _latencySamples[32];
}
@property (nonatomic) uint32_t sendWindowBytes;
@property (nonatomic) uint32_t inflightBytes;
@property (nonatomic) ABState state;
@property (nonatomic) id<ABStrategy> strategy;
@property (nonatomic) CFTimeInterval lastTuneTime;
@property (nonatomic) double maxRTTInternal;
@property (nonatomic) double medianRTTInternal;
@property (nonatomic) uint32_t latencyCount;
@property (nonatomic) uint32_t latencyIndex;
@property (nonatomic) uint32_t currentMSS;
@end

@implementation AeroBack

- (instancetype)initWithStrategy:(id<ABStrategy>)strategy {
    if (self = [super init]) {
        _lock = OS_UNFAIR_LOCK_INIT;
        _strategy = strategy;
        _currentMSS = kABDefaultMSS;
        _sendWindowBytes = [strategy initialWindow];
        _minWindow = MAX(2 * _currentMSS, kABDefaultMinWindow);
        _maxWindow = MAX(kABDefaultMaxWindow, 64 * _currentMSS);
        _state = ABStateStartup;
        _rttEWMA = 0;
        _minRTT = DBL_MAX;
        _lastTuneTime = 0;
        _maxRTTInternal = 0;
        _medianRTTInternal = 0;
        _latencyCount = 0;
        _latencyIndex = 0;
    }
    return self;
}

- (BOOL)canSendBytes:(uint32_t)bytes {
    os_unfair_lock_lock(&_lock);
    BOOL allowed = (_inflightBytes + bytes) <= _sendWindowBytes;
    os_unfair_lock_unlock(&_lock);
    return allowed;
}

- (void)onPacketSent:(uint32_t)bytes {
    os_unfair_lock_lock(&_lock);
    _inflightBytes += bytes;
    // Guard: ensure inflight doesn't exceed window (debug)
    if (_inflightBytes > _sendWindowBytes) {
        _inflightBytes = _sendWindowBytes; // clamp in production
    }
    os_unfair_lock_unlock(&_lock);
}

- (void)onPacketAcked:(uint32_t)bytes latency:(double)latency {
    os_unfair_lock_lock(&_lock);
    if (_inflightBytes >= bytes) {
        _inflightBytes -= bytes;
    } else {
        _inflightBytes = 0;
    }

    // RTT tracking with EWMA and minRTT.
    if (latency > 0) {
        _rttEWMA = (_rttEWMA == 0) ? latency : (0.9 * _rttEWMA + 0.1 * latency);
        _minRTT = MIN(_minRTT, latency);
        _maxRTTInternal = MAX(_maxRTTInternal, latency);
        // record in ring buffer
        _latencySamples[_latencyIndex++ % 32] = latency;
        if (_latencyCount < 32) { _latencyCount++; }
        // compute median with QuickSelect O(n) - use temp copy to preserve ring buffer
        double tmp[32];
        for (uint32_t i = 0; i < _latencyCount; i++) tmp[i] = _latencySamples[i];
        _medianRTTInternal = _abQuickSelectMedian(tmp, _latencyCount);
    }

    CFTimeInterval now = CACurrentMediaTime();
    double utilization = (_sendWindowBytes > 0) ? ((double)_inflightBytes / (double)_sendWindowBytes) : 0.0;
    BOOL shouldTune = (now - _lastTuneTime) >= kABTuneIntervalSeconds;
    // Proactive tune: trigger early if utilization extreme
    if (!shouldTune && (utilization >= 0.9 || utilization <= 0.3)) {
        shouldTune = YES;
    }
    if (!shouldTune) {
        os_unfair_lock_unlock(&_lock);
        return;
    }
    _lastTuneTime = now;

    // State transitions
    if (_state == ABStateStartup && _rttEWMA > (_minRTT * 1.25)) {
        _state = ABStateSteady;
    }
    if (_state == ABStateDrain && _inflightBytes <= (_sendWindowBytes / 2)) {
        _state = ABStateSteady;
    }

    // AIMD update via strategy
    uint32_t next = [_strategy onAckWithWindow:_sendWindowBytes acked:bytes mss:_currentMSS];
    _sendWindowBytes = _abClamp(next, _minWindow, _maxWindow);

    os_unfair_lock_unlock(&_lock);
}

- (void)onCongestionSignal {
    os_unfair_lock_lock(&_lock);
    uint32_t next = [_strategy onCongestionWithWindow:_sendWindowBytes mss:_currentMSS];
    _sendWindowBytes = _abClamp(next, _minWindow, _maxWindow);
    _state = ABStateDrain;
    _lastTuneTime = CACurrentMediaTime();
    os_unfair_lock_unlock(&_lock);
}

#pragma mark - Recommendations / Stats

- (double)medianRTT { return _medianRTTInternal; }
- (double)maxRTT { return _maxRTTInternal; }

- (uint32_t)recommendedFlushIntervalMs {
    os_unfair_lock_lock(&_lock);
    double rtt = (_rttEWMA > 0 ? _rttEWMA : (_minRTT < DBL_MAX ? _minRTT : 0.02));
    double med = (_medianRTTInternal > 0 ? _medianRTTInternal : rtt);
    uint32_t inflight = _inflightBytes;
    uint32_t window = _sendWindowBytes;
    os_unfair_lock_unlock(&_lock);
    // Base interval: smaller of EWMA and median; scale with utilization.
    double utilization = (window > 0) ? ((double)inflight / (double)window) : 0.0;
    double baseMs = MIN(rtt, med) * 1000.0 * 0.2; // 20% RTT
    double factor = 1.0 + utilization * 2.0; // be more aggressive with pacing when nearly full
    double ms = MIN(40.0, MAX(1.0, baseMs * factor));
    return (uint32_t)ms;
}

- (uint32_t)recommendedBatchThreshold {
    os_unfair_lock_lock(&_lock);
    double rtt = (_rttEWMA > 0 ? _rttEWMA : (_minRTT < DBL_MAX ? _minRTT : 0.02));
    double med = (_medianRTTInternal > 0 ? _medianRTTInternal : rtt);
    uint32_t cwnd = _sendWindowBytes;
    uint32_t inflight = _inflightBytes;
    uint32_t mss = _currentMSS;
    os_unfair_lock_unlock(&_lock);
    // Base threshold: proportional to latency; reduce when utilization high to contain queue.
    double utilization = (cwnd > 0) ? ((double)inflight / (double)cwnd) : 0.0;
    uint32_t byLatency = (uint32_t)MIN(64 * 1024, (MIN(rtt, med) * 1000.0) * 1024); // ~1KB per ms
    double reduce = 1.0 - MIN(0.7, utilization * 0.7); // up to 70% reduction near full
    uint32_t cap = cwnd / 4u;
    uint32_t threshold = _abClamp((uint32_t)(byLatency * reduce), mss, MAX(mss, cap));
    return threshold;
}

- (void)onStatsTick {
    // Decay maxRTT with floor relative to current EWMA
    os_unfair_lock_lock(&_lock);
    double floor = (_rttEWMA > 0) ? (_rttEWMA * 1.25) : 0.0;
    _maxRTTInternal = MAX(_maxRTTInternal * 0.97, floor);
    os_unfair_lock_unlock(&_lock);
}

- (void)onBatchAcked:(uint32_t)bytes averageLatency:(double)avgLatency maxLatency:(double)maxLatency {
    os_unfair_lock_lock(&_lock);
    // Treat avg as the primary latency input; use max for spike sensitivity.
    if (avgLatency > 0) {
        _rttEWMA = (_rttEWMA == 0) ? avgLatency : (0.9 * _rttEWMA + 0.1 * avgLatency);
        _minRTT = MIN(_minRTT, avgLatency);
    }
    if (maxLatency > 0) {
        _maxRTTInternal = MAX(_maxRTTInternal, maxLatency);
    }
    // State transitions can be influenced by spikes
    if (_state == ABStateStartup && _rttEWMA > (_minRTT * 1.25)) {
        _state = ABStateSteady;
    }
    // Drain exit remains based on inflight and cwnd ratio (checked in onPacketAcked)
    os_unfair_lock_unlock(&_lock);
}

- (uint32_t)recommendedMaxWorkers {
    os_unfair_lock_lock(&_lock);
    uint32_t cwnd = _sendWindowBytes;
    uint32_t mss = _currentMSS;
    os_unfair_lock_unlock(&_lock);
    uint32_t cores = _abGetCPUCores();
    uint32_t byCwnd = MAX(1, cwnd / (mss * 8));
    uint32_t workers = (uint32_t)MIN(MIN(cores, 8), byCwnd);
    return workers;
}

- (void)updateMSS:(uint32_t)mss {
    os_unfair_lock_lock(&_lock);
    _currentMSS = mss;
    _minWindow = MAX(2 * mss, kABDefaultMinWindow);
    _maxWindow = MAX(kABDefaultMaxWindow, 64 * mss);
    os_unfair_lock_unlock(&_lock);
}

@end
