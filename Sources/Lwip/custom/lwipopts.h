/* Auto platform-selecting lwipopts.h
   This wrapper picks platform-specific lwip options provided in
   lwipopts_ios.h or lwipopts_macos.h. Package.swift defines
   LWIP_IOS or LWIP_MACOS via cSettings. */

#ifndef LWIP_HDR_LWIPOPTS_H
#define LWIP_HDR_LWIPOPTS_H

#if defined(LWIP_IOS)
#include "lwipopts_ios.h"
#elif defined(LWIP_MACOS)
#include "lwipopts_macos.h"
#else
/* Fallback to macOS options */
#include "lwipopts_macos.h"
#endif

#endif /* LWIP_HDR_LWIPOPTS_H */
