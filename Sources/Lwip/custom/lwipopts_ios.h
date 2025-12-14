//  lwipopts_ios.h
//  TunForge
//

#ifndef LWIPOPTS_IOS_H
#define LWIPOPTS_IOS_H

/* ================= System ================= */
#define NO_SYS                 1   /* No OS abstraction layer */
#define SYS_LIGHTWEIGHT_PROT   0   /* No lightweight protection */
#define LWIP_TCPIP_CORE_LOCKING 0  /* Not needed in NO_SYS */

/* ================= Memory ================= */
#define MEM_LIBC_MALLOC        1
#define MEMP_MEM_MALLOC        1
#define MEM_SIZE               (6 * 1024 * 1024)   /* 6 MB */

/* ================= Protocols ================= */
#define LWIP_IPV4              1
#define LWIP_IPV6              0
#define LWIP_TCP               1
#define LWIP_UDP               0
#define LWIP_ICMP              0
#define LWIP_RAW               1
#define LWIP_ARP               0
#define LWIP_DHCP              0
#define LWIP_DNS               0
#define LWIP_IGMP              0

/* ================= TCP ================= */
#define TCP_MSS                1460
#define TCP_WND                (32 * 1024)          /* fit u16_t */
#define TCP_SND_BUF            (24 * 1024)
#define TCP_QUEUE_OOSEQ        0    /* Disable OOO queue to limit memory */
#define TCP_TMR_INTERVAL       250  /* TCP timer interval in ms */

/* TCP control blocks */
#define MEMP_NUM_TCP_PCB       128
#define MEMP_NUM_TCP_PCB_LISTEN 8
#define MEMP_NUM_TCP_SEG       256

/* ================= pbuf ================= */
#define PBUF_POOL_SIZE         768
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

#endif /* LWIPOPTS_IOS_H */
