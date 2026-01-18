//
//  tf_lwip_log.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/30.
//
//  lwIP <-> ForgeLogKitC bridge
//

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
	TF_LWIP_LOG_LEVEL_DEBUG = 0,
	TF_LWIP_LOG_LEVEL_INFO = 1,
	TF_LWIP_LOG_LEVEL_WARN = 2,
	TF_LWIP_LOG_LEVEL_ERROR = 3,
	TF_LWIP_LOG_LEVEL_OFF = 4
} tf_lwip_log_level_t;

/// Call once before lwIP / TunForge initialization.
void tf_log_init(const char *subsystem);

/// Default level is Warn.
void tf_log_set_level(tf_lwip_log_level_t level);
tf_lwip_log_level_t tf_log_get_level(void);

/// lwIP platform log (LWIP_PLATFORM_DIAG).
void lwip_platform_log(const char *format, ...);

/// lwIP assert hook (LWIP_PLATFORM_ASSERT).
void lwip_platform_assert(const char *expr, const char *file, int line);

#ifdef __cplusplus
}
#endif
