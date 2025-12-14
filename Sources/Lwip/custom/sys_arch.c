/* sys_arch.c - lwIP system architecture for macOS/iOS NO_SYS builds */
#include "lwip/opt.h"

#if NO_SYS

#include "lwip/sys.h"
#include <sys/time.h>

/* Get current time in milliseconds since boot (monotonic) */
u32_t sys_now(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (u32_t)((tv.tv_sec * 1000) + (tv.tv_usec / 1000));
}

/* Get current time in jiffies (same as sys_now for NO_SYS) */
u32_t sys_jiffies(void) {
    return sys_now();
}

#endif /* NO_SYS */
