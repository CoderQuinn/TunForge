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

/// Call once before lwIP / TunForge initialization.
void tf_log_init(const char *subsystem);

/// lwIP platform log (LWIP_PLATFORM_DIAG).
void lwip_platform_log(const char *format, ...);

/// lwIP assert hook (LWIP_PLATFORM_ASSERT).
void lwip_platform_assert(const char *expr, const char *file, int line);

#ifdef __cplusplus
}
#endif
