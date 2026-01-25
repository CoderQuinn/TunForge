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
#define TCP_RCV_SCALE    4                  // 2^4 = 16 (16MB receive window)
#define TCP_WND          65535               // Max u16 value, corresponds to 16MB with scaling

#define TCP_RCV_WND      (1024 * 1024)
#define TCP_RCV_BUF      (1024 * 1024)
#define TCP_RCVLOWAT     (2 * TCP_MSS)      // Set low water mark to 2 * MSS

/* ================================================================
 * TCP send buffering
 * ================================================================ */
#define TCP_SND_BUF      (512 * 1024)
#define TCP_SNDLOWAT     (2 * TCP_MSS)      // Set low water mark to 2 * MSS

/* ================================================================
 * PCB / segment limits
 * ================================================================ */
#define MEMP_NUM_TCP_PCB 512
#define MEMP_NUM_TCP_SEG    ((TCP_SND_BUF / TCP_MSS) * 2)

/* ================================================================
 * pbuf pool
 * ================================================================ */
#define PBUF_POOL_SIZE   2048                // Increased to handle more bursts of data
#define PBUF_POOL_BUFSIZE LWIP_MEM_ALIGN_SIZE(TCP_MSS + 40) // Account for TCP headers

/* ================================================================
 * TCP behavior
 * ================================================================ */
#define TCP_KEEPIDLE    7200  
#define TCP_KEEPINTVL   75
#define TCP_KEEPCNT     9

#define TCP_MAXRTX       8                   // Maximum retransmits before considering a failure
#define TCP_SYNMAXRTX    4                   // Maximum SYN retransmits
#define TCP_TTL          64                  // Default Time-To-Live for TCP packets

#endif /* LWIPOPTS_MACOS_H */

