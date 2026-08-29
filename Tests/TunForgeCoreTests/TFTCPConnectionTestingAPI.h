//
//  TFTCPConnectionTestingAPI.h
//  TunForgeCoreTests
//
//  Unstable hooks compiled only into the test bundle.
//

#import <Foundation/Foundation.h>

#include "lwip/err.h"

@class TFTCPConnection;
struct pbuf;
struct tcp_pcb;

/// Allocates a synthetic `ESTABLISHED` PCB for unit tests. Must run on `packetsQueue`.
FOUNDATION_EXPORT struct tcp_pcb *_Nullable TFTCPConnectionTestingCreateSyntheticEstablishedPCB(
    void);

/// Mirrors the connection's registered lwIP receive callback with `err == ERR_OK`.
/// Must run on `packetsQueue`.
FOUNDATION_EXPORT err_t TFTCPConnectionTestingDeliverInboundPbuf(TFTCPConnection *_Nonnull conn,
                                                                 struct pbuf *_Nullable p);

/// Same as `TFTCPConnectionTestingDeliverInboundPbuf` but supplies a synthetic lwIP `err`.
FOUNDATION_EXPORT err_t TFTCPConnectionTestingDeliverInboundWithErr(TFTCPConnection *_Nonnull conn,
                                                                    struct pbuf *_Nullable p,
                                                                    err_t lwerr);

/// Forces New-state reject timeout on the next poll. Must run on `packetsQueue`.
FOUNDATION_EXPORT void TFTCPConnectionTestingAccelerateNewStateTimeout(
    TFTCPConnection *_Nonnull conn);

/// Invokes the connection's registered lwIP poll callback once. Must run on `packetsQueue`.
FOUNDATION_EXPORT err_t TFTCPConnectionTestingTriggerPoll(TFTCPConnection *_Nonnull conn);

/// Frees the synthetic PCB as lwIP would before invoking its registered error callback.
/// Must run on `packetsQueue`.
FOUNDATION_EXPORT err_t TFTCPConnectionTestingTriggerError(TFTCPConnection *_Nonnull conn,
                                                           err_t lwerr);

/// Current zero-copy / compatibility-path inflight ACK counter. Must run on `packetsQueue`.
FOUNDATION_EXPORT uint64_t TFTCPConnectionTestingInflightAckBytes(TFTCPConnection *_Nonnull conn);

/// Listen PCB local port for the default `TFIPStack`, or 0 if not ready. Must run on
/// `packetsQueue`.
FOUNDATION_EXPORT uint16_t TFIPStackTestingListenPort(void);

/// YES if the connection still holds a non-NULL PCB pointer. Must run on `packetsQueue`.
FOUNDATION_EXPORT BOOL TFTCPConnectionTestingHasPCB(TFTCPConnection *_Nonnull conn);
