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
FOUNDATION_EXPORT struct tcp_pcb *_Nullable TFTCPConnectionTestingCreateSyntheticEstablishedPCB(
    void);

/// Mirrors lwIP `tcp_recv` with `err == ERR_OK` (synthetic inbound data). Must run on `packetsQueue`.
FOUNDATION_EXPORT err_t TFTCPConnectionTestingDeliverInboundPbuf(TFTCPConnection *_Nonnull conn,
                                                                 struct pbuf *_Nullable p);

/// Same as `TFTCPConnectionTestingDeliverInboundPbuf` but supplies a synthetic lwIP `err` (e.g. `ERR_BUF`).
FOUNDATION_EXPORT err_t TFTCPConnectionTestingDeliverInboundWithErr(TFTCPConnection *_Nonnull conn,
                                                                    struct pbuf *_Nullable p,
                                                                    err_t lwerr);

/// Forces New-state reject timeout on the next poll (sets start time far in the past).
/// Must run on `packetsQueue`.
FOUNDATION_EXPORT void TFTCPConnectionTestingAccelerateNewStateTimeout(
    TFTCPConnection *_Nonnull conn);

/// Invokes the connection's lwIP poll callback once. Must run on `packetsQueue`.
FOUNDATION_EXPORT err_t TFTCPConnectionTestingTriggerPoll(TFTCPConnection *_Nonnull conn);

/// Current zero-copy / compatibility-path inflight ACK counter. Must run on `packetsQueue`.
FOUNDATION_EXPORT uint64_t TFTCPConnectionTestingInflightAckBytes(TFTCPConnection *_Nonnull conn);

/// Listen PCB local port for the default `TFIPStack`, or 0 if not ready. Must run on `packetsQueue`.
FOUNDATION_EXPORT uint16_t TFIPStackTestingListenPort(void);

/// YES if the connection still holds a non-NULL PCB pointer. Must run on `packetsQueue`.
FOUNDATION_EXPORT BOOL TFTCPConnectionTestingHasPCB(TFTCPConnection *_Nonnull conn);
