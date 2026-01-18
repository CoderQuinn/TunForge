//
//  tf_lwip_log.c
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/30.
//

#include "tf_lwip_log.h"
#include "lwip/opt.h"
#include "FLLogC.h"
#include <dispatch/dispatch.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

static FLLogCHandle g_lwip_log = NULL;
// Process-lifetime subsystem name. Typically set once via tf_log_init.
static const char *g_subsystem = NULL;
static bool s_enabled = false;
static tf_lwip_log_level_t s_level = TF_LWIP_LOG_LEVEL_WARN;

static inline bool tf_should_log(tf_lwip_log_level_t level) {
    if (!s_enabled || g_lwip_log == NULL)
        return false;
    if (s_level == TF_LWIP_LOG_LEVEL_OFF)
        return false;
    return level >= s_level;
}

static inline FLLogLevel tf_map_level(tf_lwip_log_level_t level) {
    switch (level) {
    case TF_LWIP_LOG_LEVEL_DEBUG:
        return FL_LOG_LEVEL_DEBUG;
    case TF_LWIP_LOG_LEVEL_INFO:
        return FL_LOG_LEVEL_INFO;
    case TF_LWIP_LOG_LEVEL_WARN:
        return FL_LOG_LEVEL_WARN;
    case TF_LWIP_LOG_LEVEL_ERROR:
        return FL_LOG_LEVEL_ERROR;
    case TF_LWIP_LOG_LEVEL_OFF:
    default:
        return FL_LOG_LEVEL_INFO;
    }
}

/*
 * Internal: create or return the lwIP logger.
 * Thread-safe, process-lifetime.
 */
static inline FLLogCHandle lwip_log(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const char *subsystem = g_subsystem ? g_subsystem : NULL;
        g_lwip_log = FLLogCCreate(subsystem, "TunForge.lwip");
    });
    return g_lwip_log;
}

void tf_log_init(const char *subsystem) {
    if (!subsystem) return;

    // Free old subsystem if re-initializing (though typically called once)
    if (g_subsystem) {
        free((void *)g_subsystem);
        g_subsystem = NULL;
    }
    g_subsystem = strdup(subsystem);
    if (!g_subsystem) {
        // Memory allocation failed, disable logging
        s_enabled = false;
        return;
    }
    s_enabled = true;
#if defined(TUNFORGE_LWIP_DEBUG_PROFILE)
    #if TUNFORGE_LWIP_DEBUG_PROFILE == 2
        s_level = TF_LWIP_LOG_LEVEL_DEBUG;
    #elif TUNFORGE_LWIP_DEBUG_PROFILE == 1
        s_level = TF_LWIP_LOG_LEVEL_WARN;
    #elif TUNFORGE_LWIP_DEBUG_PROFILE == 0
        s_level = TF_LWIP_LOG_LEVEL_OFF;
    #else
        s_level = TF_LWIP_LOG_LEVEL_WARN;
    #endif
#else
    s_level = TF_LWIP_LOG_LEVEL_WARN;
#endif
    (void)lwip_log();
}

void tf_log_set_level(tf_lwip_log_level_t level) {
    s_level = level;
}

tf_lwip_log_level_t tf_log_get_level(void) {
    return s_level;
}

void lwip_platform_log(const char *format, ...) {
    if (!format) return;
    if (!tf_should_log(TF_LWIP_LOG_LEVEL_INFO)) return;

    va_list ap;
    va_start(ap, format);
    FLLogCVLogfH(lwip_log(), tf_map_level(TF_LWIP_LOG_LEVEL_INFO), format, ap);
    va_end(ap);
}

void lwip_platform_assert(const char *expr, const char *file, int line) {
    if (!s_enabled || s_level == TF_LWIP_LOG_LEVEL_OFF) return;
    
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

