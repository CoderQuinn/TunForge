//
//  tf_lwip_log.c
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/30.
//

#include "tf_lwip_log.h"
#include "lwip/opt.h"
#include "FLLogC.h"
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

static FLLogCHandle g_lwip_log = NULL;

void tf_log_init(const char *subsystem) {
    if (!g_lwip_log) {
        g_lwip_log = FLLogCCreate(subsystem, "TunForge.lwip");
    }
}

static inline FLLogCHandle lwip_log(void) {
    if (!g_lwip_log) {
        g_lwip_log = FLLogCCreate(NULL, "TunForge.lwip");
    }
    return g_lwip_log;
}

void lwip_platform_log(const char *format, ...) {
    if (!format) return;

    va_list ap;
    va_start(ap, format);
    FLLogCVLogfH(lwip_log(), FL_LOG_LEVEL_INFO, format, ap);
    va_end(ap);
}

void lwip_platform_assert(const char *expr, const char *file, int line) {
    FLLogCLogfH(
        lwip_log(),
        FL_LOG_LEVEL_FAULT,
        "LWIP ASSERT FAILED: %s (%s:%d)",
        expr ? expr : "?",
        file ? file : "?",
        line
    );

#if LWIP_DEBUG
    __builtin_debugtrap();
#else
    abort();
#endif
}

