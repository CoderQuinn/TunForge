//
//  TFTCPConnectionTestingAPI.h
//  TunForge
//
//  Unstable hooks used only by TunForgeCoreTests. Not part of the supported public API.
//

#import <Foundation/Foundation.h>

#include "lwip/err.h"

@class TFTCPConnection;
struct pbuf;
struct tcp_pcb;

/// Allocates a synthetic `ESTABLISHED` PCB for unit tests. Must run on `packetsQueue`.
struct tcp_pcb *_Nullable TFTCPConnectionTestingCreateSyntheticEstablishedPCB(void);

/// Mirrors lwIP `tcp_recv` with `err == ERR_OK` (synthetic inbound data). Must run on `packetsQueue`.
FOUNDATION_EXPORT err_t TFTCPConnectionTestingDeliverInboundPbuf(TFTCPConnection *conn, struct pbuf *p);

/// Same as `TFTCPConnectionTestingDeliverInboundPbuf` but supplies a synthetic lwIP `err` (e.g. `ERR_BUF`).
FOUNDATION_EXPORT err_t TFTCPConnectionTestingDeliverInboundWithErr(TFTCPConnection *conn, struct pbuf *p,
                                                                    err_t lwerr);
