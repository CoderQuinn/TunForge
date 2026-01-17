//  lwipopts_macos.h
//  TunForge
#ifndef LWIPOPTS_MACOS_H
#define LWIPOPTS_MACOS_H

/*
 * TunForge lwIP Platform Tuning: macOS
 *
 * Scope:
 *  - Sizing, memory, and buffering ONLY
 *  - No lwIP semantic options
 *  - No TunForge policy / hooks
 *
 */

/* ================================================================
 * Memory / allocator
 * ================================================================ */
#define MEM_LIBC_MALLOC  0
#define MEMP_MEM_MALLOC  0
#define MEM_ALIGNMENT    8
#define MEM_SIZE         (64 * 1024 * 1024)  // 64MB is a reasonable cap for memory usage

/* ================================================================
 * TCP receive window
 * ================================================================ */
#define LWIP_WND_SCALE   1
#define TCP_RCV_SCALE    4                  // 2^4 = 16; window is TCP_WND * 16 when scaling is enabled
#define TCP_WND          65535              // Max u16 value; with scale=4 this is 65535 * 16 ≈ 1 MB window

/* ================================================================
 * TCP send buffering
 * ================================================================ */
#define TCP_SND_BUF      (8 * 1024 * 1024)  // 8MB send buffer for smooth downlink
#define TCP_SNDLOWAT     (4 * TCP_MSS)      // Set low water mark to 4 * MSS

/* ================================================================
 * PCB / segment limits
 * ================================================================ */
#define MEMP_NUM_TCP_PCB 512
#ifndef MEMP_NUM_TCP_SEG
#  ifdef TCP_SND_QUEUELEN
#    define MEMP_NUM_TCP_SEG (TCP_SND_QUEUELEN + 1) // Ensure sufficient segment buffers
#  else
#    define MEMP_NUM_TCP_SEG 1024                   // Fallback: conservative default
#  endif
#endif

/* ================================================================
 * pbuf pool
 * ================================================================ */
#define PBUF_POOL_SIZE   2048                // Increased to handle more bursts of data
#define PBUF_POOL_BUFSIZE LWIP_MEM_ALIGN_SIZE(TCP_MSS + 40) // Account for TCP headers

/* ================================================================
 * TCP behavior
 * ================================================================ */
#define TCP_MAXRTX       8                   // Maximum retransmits before considering a failure
#define TCP_SYNMAXRTX    4                   // Maximum SYN retransmits
#define TCP_TTL          64                  // Default Time-To-Live for TCP packets

#endif /* LWIPOPTS_MACOS_H */

