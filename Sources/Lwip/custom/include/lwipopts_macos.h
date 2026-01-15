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
#define MEM_SIZE       (32 * 1024 * 1024)


/* ================================================================
 * TCP receive window
 * ================================================================ */
#define LWIP_WND_SCALE 0
#define TCP_RCV_SCALE  0
#define TCP_WND        (64 * 1024 - 1)


/* ================================================================
 * TCP send buffering
 * ================================================================ */
#define TCP_SND_BUF    (64 * 1024 - 1)
#define TCP_SNDLOWAT   (2 * TCP_MSS)


/* ================================================================
 * PCB / segment limits
 * ================================================================ */
#define MEMP_NUM_TCP_PCB  512
#define MEMP_NUM_TCP_SEG  2048

/* ================================================================
 * pbuf pool
 * ================================================================ */
#define PBUF_POOL_SIZE  1024
#define PBUF_POOL_BUFSIZE LWIP_MEM_ALIGN_SIZE(TCP_MSS + 40)

#endif /* LWIPOPTS_MACOS_H */
