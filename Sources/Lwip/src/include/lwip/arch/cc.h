// arch/cc.h
#ifndef LWIP_ARCH_CC_H
#define LWIP_ARCH_CC_H

#include "tf_lwip_log.h"

#ifdef __cplusplus
extern "C" {
#endif

void lwip_platform_log(const char *format, ...);
void lwip_platform_assert(const char *expr, const char *file, int line);

#ifdef __cplusplus
}
#endif

/* ============================================================
 * Diagnostics (log visibility only)
 * ============================================================ */

#if LWIP_DEBUG
  #define LWIP_PLATFORM_DIAG(x) lwip_platform_log x
#else
  #define LWIP_PLATFORM_DIAG(x)
#endif

/* ============================================================
 * Assertions (MUST ALWAYS EXIST)
 * ============================================================ */

#ifndef LWIP_PLATFORM_ASSERT
  #define LWIP_PLATFORM_ASSERT(x) \
      lwip_platform_assert(x, __FILE__, __LINE__)
#endif

#endif /* LWIP_ARCH_CC_H */

