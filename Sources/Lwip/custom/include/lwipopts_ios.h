//  lwipopts_ios.h
//  TunForge
#ifndef LWIPOPTS_IOS_H
#define LWIPOPTS_IOS_H

/*
 * TunForge lwIP Platform Tuning: iOS
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
#define MEM_SIZE       (16 * 1024 * 1024)

/* ================================================================
 * TCP receive window
 * ================================================================ */
#define LWIP_WND_SCALE 0
#define TCP_RCV_SCALE  0
#define TCP_WND        (32 * 1024)

/* ================================================================
 * TCP send buffering
 * ================================================================ */
#define TCP_SND_BUF    (16 * 1024)
#define TCP_SNDLOWAT   (2 * TCP_MSS)


/* ================================================================
 * PCB / segment limits
 * ================================================================ */
#define MEMP_NUM_TCP_PCB  256
#define MEMP_NUM_TCP_SEG  1024


/* ================================================================
 * pbuf pool
 * ================================================================ */
#define PBUF_POOL_SIZE  512
#define PBUF_POOL_BUFSIZE LWIP_MEM_ALIGN_SIZE(TCP_MSS + 40)

#endif /* LWIPOPTS_IOS_H */
