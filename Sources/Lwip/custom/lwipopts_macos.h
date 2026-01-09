//  lwipopts_macos.h
//  TunForge
//

#ifndef LWIPOPTS_MACOS_H
#define LWIPOPTS_MACOS_H

/* ================= System ================= */
#define NO_SYS                 1
#define SYS_LIGHTWEIGHT_PROT   0
#define LWIP_TCPIP_CORE_LOCKING 0

/* ================= Memory ================= */
#define MEM_LIBC_MALLOC        1
#define MEMP_MEM_MALLOC        1
#define MEM_SIZE               (32 * 1024 * 1024)   /* 32 MB */

/* ================= Protocols ================= */
#define LWIP_IPV4              1
#define LWIP_IPV6              0
#define LWIP_TCP               1
#define LWIP_UDP               1
#define LWIP_ICMP              0
#define LWIP_RAW               1
#define LWIP_ARP               0
#define LWIP_DHCP              0
#define LWIP_DNS               0
#define LWIP_IGMP              0

/* ================= TCP ================= */
#define TCP_MSS                1460
#define TCP_WND                (64 * 1024 - 1024)   /* fit u16_t */
#define TCP_SND_BUF            (32 * 1024)
#define TCP_QUEUE_OOSEQ        1   /* macOS 可以开 */
#define TCP_TMR_INTERVAL       250

/* TCP control blocks */
#define MEMP_NUM_TCP_PCB       512
#define MEMP_NUM_TCP_PCB_LISTEN 32
#define MEMP_NUM_TCP_SEG       2048

/* ================= pbuf ================= */
#define PBUF_POOL_SIZE         2048
#define PBUF_POOL_BUFSIZE      2048

/* ================= IP ================= */
#define IP_REASSEMBLY          0
#define IP_FRAG                1

/* ================= API ================= */
#define LWIP_SOCKET            0
#define LWIP_NETCONN           0

/* ================= Loopback ================= */
#define LWIP_HAVE_LOOPIF       0
#define LWIP_NETIF_LOOPBACK    0

/* ================= Stats / Debug ================= */
#define LWIP_STATS             0
#define LWIP_DEBUG             0

/* Misc: avoid byteorder redefs; RNG for DNS if enabled */
#define LWIP_DONT_PROVIDE_BYTEORDER_FUNCTIONS 1
#include <stdlib.h>
#define LWIP_RAND() ((u32_t)arc4random())

#endif /* LWIPOPTS_MACOS_H */
