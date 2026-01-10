/* Auto platform-selecting lwipopts.h
 *
 * This wrapper selects platform-specific lwIP options from
 * lwipopts_ios.h or lwipopts_macos.h.
 *
 * Package.swift defines LWIP_IOS or LWIP_MACOS via cSettings.
 *
 * TunForge policy:
 *  - Keep platform sizing / tuning in lwipopts_ios.h / lwipopts_macos.h
 *  - Keep TunForge patch toggles, hooks, and markers HERE
 *  - Keep lwIP core semantic macros defined exactly once
 *  - Avoid deep buffering in Release by default (Balanced tier)
 */

#ifndef LWIP_HDR_LWIPOPTS_H
#define LWIP_HDR_LWIPOPTS_H

/* ================================================================
 * TunForge Global Configuration Knobs
 * ================================================================ */

/*
 * TUNFORGE_LWIP_DEBUG_PROFILE
 *   0 -> Production (no lwIP debug output)
 *   1 -> Stable diagnostics (warnings only)
 *   2 -> Deep protocol debugging
 */
#ifndef TUNFORGE_LWIP_DEBUG_PROFILE
#define TUNFORGE_LWIP_DEBUG_PROFILE 1
#endif

/* ================================================================
 * lwIP Core / System Semantics (DEFINED ONCE)
 * ================================================================ */

#define NO_SYS                  1
#define LWIP_TCPIP_TIMEOUT      0
#define SYS_LIGHTWEIGHT_PROT    0
#define LWIP_TCPIP_CORE_LOCKING 0

#define LWIP_IPV4               1
#define LWIP_IPV6               0
#define LWIP_TCP                1
#define LWIP_UDP                0
#define LWIP_ICMP               0
#define LWIP_RAW                1
#define LWIP_ARP                0
#define LWIP_DHCP               0
#define LWIP_DNS                0
#define LWIP_IGMP               0

#define TCP_MSS                 1460
#define TCP_QUEUE_OOSEQ         1
#define TCP_TMR_INTERVAL        250
#define TCP_MSL                 15000UL

#define IP_REASSEMBLY           1
#define IP_FRAG                 1

#define LWIP_CALLBACK_API       1
#define TCP_LISTEN_BACKLOG      1
#define LWIP_SOCKET             0
#define LWIP_NETCONN            0

#define LWIP_NETIF_LOOPBACK     0
#define LWIP_HAVE_LOOPIF        0


/* ================================================================
 * Platform-Specific Sizing / Tuning
 * ================================================================ */
#if defined(LWIP_IOS)
  #include "lwipopts_ios.h"
#elif defined(LWIP_MACOS)
  #include "lwipopts_macos.h"
#else
  /* Fallback to macOS tuning for desktop builds */
  #include "lwipopts_macos.h"
#endif


/* ================================================================
 * Derived / Computed Parameters
 * ================================================================ */

#define TCP_SND_QUEUELEN        (2 * (TCP_SND_BUF / TCP_MSS))
#define MEMP_NUM_TCP_PCB_LISTEN 32


/* ================================================================
 * TunForge Policy / Hooks / Extension Args
 * ================================================================ */

#define LWIP_TUNFORGE_TCP_HOOK   1
#define LWIP_TUNFORGE_IP_HOOK    1

#define TUNFORGE_NETIF_IPV4_MTU  1500

#define LWIP_TCP_PCB_NUM_EXT_ARGS 1

#define TUNFORGE_TCP_EXTARG_ID        0

#define LWIP_TCP_KEEPALIVE       1
#define TCP_KEEPCNT_DEFAULT      3


/* ================================================================
 * Debug / Logging Configuration (Visibility ONLY)
 * ================================================================ */

#define LWIP_STATS 0

#if TUNFORGE_LWIP_DEBUG_PROFILE == 0

#define LWIP_DEBUG 0

#elif TUNFORGE_LWIP_DEBUG_PROFILE == 1

#define LWIP_DEBUG 1
#define LWIP_DBG_MIN_LEVEL LWIP_DBG_LEVEL_WARNING

#define TCP_RST_DEBUG    LWIP_DBG_ON
#define TCP_QLEN_DEBUG   LWIP_DBG_ON
#define TCP_OOSEQ_DEBUG  LWIP_DBG_ON

#undef TCP_DEBUG
#undef TCP_INPUT_DEBUG
#undef TCP_OUTPUT_DEBUG
#undef TCP_WND_DEBUG
#undef TCP_RTO_DEBUG
#undef TCP_CWND_DEBUG
#undef TCP_FR_DEBUG
#undef IP_DEBUG
#undef NETIF_DEBUG

#elif TUNFORGE_LWIP_DEBUG_PROFILE == 2

#define LWIP_DEBUG 1
#define LWIP_DBG_MIN_LEVEL LWIP_DBG_LEVEL_ALL

#define TCP_DEBUG         LWIP_DBG_ON
#define TCP_INPUT_DEBUG   LWIP_DBG_ON
#define TCP_OUTPUT_DEBUG  LWIP_DBG_ON
#define TCP_RST_DEBUG     LWIP_DBG_ON
#define TCP_QLEN_DEBUG    LWIP_DBG_ON
#define TCP_OOSEQ_DEBUG   LWIP_DBG_ON
#define TCP_FR_DEBUG      LWIP_DBG_ON
#define TCP_RTO_DEBUG     LWIP_DBG_ON
#define TCP_CWND_DEBUG    LWIP_DBG_ON
#define TCP_WND_DEBUG     LWIP_DBG_ON
#define IP_DEBUG          LWIP_DBG_ON
#define NETIF_DEBUG       LWIP_DBG_OFF

#else
#error "Invalid TUNFORGE_LWIP_DEBUG_PROFILE"
#endif

#define LWIP_ASSERT_ON 1

/* ================================================================
 * Cross-File Validation & Safety Checks
 * ================================================================ */

/* Window scaling sanity */
#if LWIP_WND_SCALE
  #ifndef TCP_RCV_SCALE
    #error "LWIP_WND_SCALE=1 but TCP_RCV_SCALE not defined by platform config"
  #endif
  #if TCP_RCV_SCALE > 14
    #error "TCP_RCV_SCALE must be <= 14"
  #endif
  #if (TCP_WND >> TCP_RCV_SCALE) > 0xFFFF
    #error "TCP_WND too large for TCP_RCV_SCALE (window field overflow)"
  #endif
#endif

#endif /* LWIP_HDR_LWIPOPTS_H */

