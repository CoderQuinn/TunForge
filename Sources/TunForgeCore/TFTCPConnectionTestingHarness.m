//
//  TFTCPConnectionTestingHarness.m
//  TunForge
//
//  Synthetic lwIP PCBs for unit tests (must run on packetsQueue).
//

#import "TFTCPConnectionTestingAPI.h"
#import "TFQueueHelpers.h"

#import "lwip/ip_addr.h"
#import "lwip/netif.h"
#import "lwip/priv/tcp_priv.h"
#import "lwip/tcp.h"

#import <stdlib.h>

struct tcp_pcb *TFTCPConnectionTestingCreateSyntheticEstablishedPCB(void) {
    TF_ASSERT_ON_PACKETS_QUEUE();

    for (int attempt = 0; attempt < 64; attempt++) {
        uint16_t localPort = (uint16_t)(38000 + (arc4random_uniform(20000)));
        struct tcp_pcb *pcb = tcp_new();
        if (!pcb) {
            return NULL;
        }

        ip_addr_t lip;
        IP_ADDR4(&lip, 198, 18, 0, 1);
        err_t e = tcp_bind(pcb, &lip, localPort);
        if (e != ERR_OK) {
            tcp_close(pcb);
            continue;
        }

        TCP_RMV(&tcp_bound_pcbs, pcb);

        pcb->state = ESTABLISHED;
        IP_ADDR4(&pcb->remote_ip, 198, 18, 0, 2);
        pcb->remote_port = (u16_t)(45000 + (localPort % 20000));
        pcb->snd_wnd = (tcpwnd_size_t)TCP_WND;

        struct netif *n = netif_default;
        if (n) {
            pcb->netif_idx = netif_get_index(n);
        }

        TCP_REG_ACTIVE(pcb);
        return pcb;
    }
    return NULL;
}
