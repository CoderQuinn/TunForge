//
//  TFTCPConnectionTestingSupport.m
//  TunForgeCoreTests
//

#import "TFTCPConnectionTestingAPI.h"

#import "TFIPStack.h"
#import "TFObjectRef.h"
#import "TFQueueHelpers.h"
#import "TFTCPConnection.h"

#import "lwip/ip_addr.h"
#import "lwip/netif.h"
#import "lwip/priv/tcp_priv.h"
#import "lwip/sys.h"
#import "lwip/tcp.h"

#import <stdlib.h>

// The production classes synthesize these accessors in their implementation-only class
// extensions. Declaring them in the test bundle lets tests inspect the registered lwIP
// callbacks without compiling test functions or private lwIP headers into TunForgeCore.
@interface TFTCPConnection (TunForgeCoreTests)
@property (nonatomic, assign) struct tcp_pcb *pcb;
@property (nonatomic, assign) u32_t newStateStartMs;
@property (nonatomic, assign) uint64_t inflightAckBytes;
@end

@interface TFIPStack (TunForgeCoreTests)
@property (nonatomic, assign) struct tcp_pcb *listener;
@end

struct tcp_pcb *TFTCPConnectionTestingCreateSyntheticEstablishedPCB(void) {
    TF_ASSERT_ON_PACKETS_QUEUE();

    for (int attempt = 0; attempt < 64; attempt++) {
        uint16_t localPort = (uint16_t)(38000 + arc4random_uniform(20000));
        struct tcp_pcb *pcb = tcp_new();
        if (!pcb) {
            return NULL;
        }

        ip_addr_t localIP;
        IP_ADDR4(&localIP, 198, 18, 0, 1);
        err_t err = tcp_bind(pcb, &localIP, localPort);
        if (err != ERR_OK) {
            tcp_close(pcb);
            continue;
        }

        TCP_RMV(&tcp_bound_pcbs, pcb);

        pcb->state = ESTABLISHED;
        IP_ADDR4(&pcb->remote_ip, 198, 18, 0, 2);
        pcb->remote_port = (u16_t)(45000 + (localPort % 20000));
        pcb->snd_wnd = (tcpwnd_size_t)TCP_WND;

        struct netif *netif = netif_default;
        if (netif) {
            pcb->netif_idx = netif_get_index(netif);
        }

        TCP_REG_ACTIVE(pcb);
        return pcb;
    }
    return NULL;
}

err_t TFTCPConnectionTestingDeliverInboundPbuf(TFTCPConnection *conn, struct pbuf *p) {
    return TFTCPConnectionTestingDeliverInboundWithErr(conn, p, ERR_OK);
}

err_t TFTCPConnectionTestingDeliverInboundWithErr(TFTCPConnection *conn,
                                                  struct pbuf *p,
                                                  err_t lwerr) {
    TF_ASSERT_ON_PACKETS_QUEUE();
    if (!conn) {
        return ERR_ARG;
    }

    struct tcp_pcb *pcb = conn.pcb;
    if (!pcb || !conn.alive || !pcb->recv) {
        return ERR_ARG;
    }
    return pcb->recv(pcb->callback_arg, pcb, p, lwerr);
}

void TFTCPConnectionTestingAccelerateNewStateTimeout(TFTCPConnection *conn) {
    TF_ASSERT_ON_PACKETS_QUEUE();
    if (!conn) {
        return;
    }
    conn.newStateStartMs = sys_now() - 20000u;
}

err_t TFTCPConnectionTestingTriggerPoll(TFTCPConnection *conn) {
    TF_ASSERT_ON_PACKETS_QUEUE();
    if (!conn) {
        return ERR_ARG;
    }

    struct tcp_pcb *pcb = conn.pcb;
    if (!pcb || !pcb->poll) {
        return ERR_ARG;
    }
    return pcb->poll(pcb->callback_arg, pcb);
}

err_t TFTCPConnectionTestingTriggerError(TFTCPConnection *conn, err_t lwerr) {
    TF_ASSERT_ON_PACKETS_QUEUE();
    if (!conn) {
        return ERR_ARG;
    }

    struct tcp_pcb *pcb = conn.pcb;
    if (!pcb || !pcb->errf) {
        return ERR_ARG;
    }

    tcp_err_fn errCallback = pcb->errf;
    void *callbackArg = pcb->callback_arg;
    void *retainedExtArg = NULL;

#if LWIP_TCP_PCB_NUM_EXT_ARGS
    retainedExtArg = tcp_ext_arg_get(pcb, TUNFORGE_TCP_EXTARG_ID);
    tcp_ext_arg_set_callbacks(pcb, TUNFORGE_TCP_EXTARG_ID, NULL);
    tcp_ext_arg_set(pcb, TUNFORGE_TCP_EXTARG_ID, NULL);
#endif

    // lwIP error callbacks receive no PCB because the PCB has already been freed. Detach the
    // callback first so tcp_abort performs only the normal list/resource cleanup, then invoke
    // the production-registered callback with the requested synthetic error.
    tcp_err(pcb, NULL);
    tcp_arg(pcb, NULL);
    tcp_abort(pcb);
    errCallback(callbackArg, lwerr);

    if (retainedExtArg) {
        TFObjectRefRelease(retainedExtArg);
    }
    return ERR_OK;
}

NSUInteger TFTCPConnectionTestingRefusedDataLength(TFTCPConnection *conn) {
    TF_ASSERT_ON_PACKETS_QUEUE();
    struct tcp_pcb *pcb = conn ? conn.pcb : NULL;
    return (pcb && pcb->refused_data) ? pcb->refused_data->tot_len : 0;
}

err_t TFTCPConnectionTestingRetryRefusedData(TFTCPConnection *conn) {
    TF_ASSERT_ON_PACKETS_QUEUE();
    struct tcp_pcb *pcb = conn ? conn.pcb : NULL;
    if (!pcb || !pcb->refused_data) {
        return ERR_ARG;
    }
    return tcp_process_refused_data(pcb);
}

uint64_t TFTCPConnectionTestingInflightAckBytes(TFTCPConnection *conn) {
    TF_ASSERT_ON_PACKETS_QUEUE();
    return conn ? conn.inflightAckBytes : 0;
}

uint16_t TFIPStackTestingListenPort(void) {
    TF_ASSERT_ON_PACKETS_QUEUE();
    struct tcp_pcb *listener = [TFIPStack defaultStack].listener;
    return listener ? listener->local_port : 0;
}

BOOL TFTCPConnectionTestingHasPCB(TFTCPConnection *conn) {
    TF_ASSERT_ON_PACKETS_QUEUE();
    return conn ? conn.pcb != NULL : NO;
}
