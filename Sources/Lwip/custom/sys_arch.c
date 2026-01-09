/* sys_arch.c - lwIP system architecture for macOS/iOS NO_SYS builds */
#include "lwip/opt.h"

#if NO_SYS

#include "lwip/sys.h"
#include <mach/mach_time.h>

/*
 * sys_now()
 * ----------
 * Return time in milliseconds since boot (monotonic).
 *
 * lwIP requirements:
 *  - monotonic
 *  - millisecond resolution
 *  - wrap-around acceptable (u32_t)
 */
u32_t sys_now(void) {
    static uint64_t start_ticks = 0;
    static double ticks_to_ms = 0.0;
    
    if (start_ticks == 0) {
        mach_timebase_info_data_t timebase;
        mach_timebase_info(&timebase);
        start_ticks = mach_absolute_time();
        ticks_to_ms = (double)timebase.numer /
                     (timebase.denom * 1000000.0);
    }
    
    uint64_t elapsed = mach_absolute_time() - start_ticks;
    return (u32_t)((double)elapsed * ticks_to_ms);
}

u32_t sys_jiffies(void) {
    return sys_now();
}

#endif /* NO_SYS */

