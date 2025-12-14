/* Minimal arch/cc.h for macOS/iOS ports used by SPM build */
#ifndef LWIP_HDR_ARCH_CC_H
#define LWIP_HDR_ARCH_CC_H

#include <stdint.h>
#include <inttypes.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <limits.h>


/* Provide platform diagnostics and assert hooks expected by lwIP */
#ifndef LWIP_PLATFORM_DIAG
#define LWIP_PLATFORM_DIAG(x) do { fprintf(stderr, "%s\n", x); } while(0)
#endif

#ifndef LWIP_PLATFORM_ASSERT
#define LWIP_PLATFORM_ASSERT(x) do { fprintf(stderr, "LWIP ASSERT: %s\n", x); abort(); } while(0)
#endif

#endif /* LWIP_HDR_ARCH_CC_H */
