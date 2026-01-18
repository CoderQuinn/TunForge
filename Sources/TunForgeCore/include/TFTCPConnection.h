//
//  TFTCPConnection.h
//  TunForge
//
//  Created by MagicianQuinn on 2026/1/1.
//

/*
 *
 Fact                           Meaning
 Local send open / closed       Whether I can still send data
 Local receive open / closed    Whether I can still receive data
 Peer send open / closed        Whether the peer can still send data
 Peer receive open / closed     Whether the peer can still receive data
 *
 */
#import <Foundation/Foundation.h>

struct tcp_pcb;
@class TFObjectRef;
@class TFTCPConnectionInfo, TFTCPConnection;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TFTCPConnectionTerminationReason) {
    TFTCPConnectionTerminationReasonNone = 0,
    TFTCPConnectionTerminationReasonClose,
    TFTCPConnectionTerminationReasonReset,
    TFTCPConnectionTerminationReasonAbort,
    TFTCPConnectionTerminationReasonDestroyed // ext destroy
};

typedef NS_ENUM(NSUInteger, TFTCPWriteStatus) {
    TFTCPWriteOK,
    TFTCPWriteWouldBlock,
    TFTCPWriteClosed,
    TFTCPWriteError
};

typedef struct {
    NSUInteger written;
    TFTCPWriteStatus status;
} TFTCPWriteResult;

typedef struct {
    const void *bytes;
    NSUInteger length;
} TFBytesSlice;
typedef void (^TFTCPReadableBytesCompletion)(void);

typedef void (^TFTCPBecameActiveHandler)(TFTCPConnection *conn);
typedef void (^TFTCPReadableHandler)(TFTCPConnection *conn, NSData *data);
typedef void (^TFTCPReadableBytesBatchHandler)(TFTCPConnection *conn,
                                               const TFBytesSlice *slices,
                                               NSUInteger sliceCount,
                                               NSUInteger totalBytesLength,
                                               TFTCPReadableBytesCompletion completion);
typedef void (^TFTCPWritableChangedHandler)(TFTCPConnection *conn, BOOL writable);
typedef void (^TFTCPSentBytesHandler)(TFTCPConnection *conn, NSUInteger sentBytes);
typedef void (^TFTCPReadEOFHandler)(TFTCPConnection *conn);
typedef void (^TFTCPTerminatedHandler)(TFTCPConnection *conn,
                                       TFTCPConnectionTerminationReason reason);

@interface TFTCPConnection : NSObject

@property (nonatomic, strong, readonly) TFTCPConnectionInfo *info;
@property (nonatomic, assign, readonly) BOOL alive;
@property (nonatomic, assign, readonly) BOOL writable;

/// "Connection is ready for I/O" (fires once).
/// Fired after markActive succeeds.
@property (nullable, nonatomic, copy) TFTCPBecameActiveHandler onBecameActive;

/// Compatibility path. Will allocate & copy.
/// Prefer onReadableBytes for zero-additional-copy at the bridge layer.
@property (nullable, nonatomic, copy) TFTCPReadableHandler onReadable;

/// Zero-copy receive path. Invoked with one or more contiguous byte slices that
/// are owned by the connection's internal receive buffer.
@property (nullable, nonatomic, copy) TFTCPReadableBytesBatchHandler onReadableBytes;

/// Edge changes of sendbuf writability (driven by ERR_MEM / tcp_sent / poll).
@property (nullable, nonatomic, copy) TFTCPWritableChangedHandler onWritableChanged;

/// Peer ACKed sent data (tcp_sent); callback provides len (u16).
@property (nullable, nonatomic, copy) TFTCPSentBytesHandler onSentBytes;

@property (nullable, nonatomic, copy) TFTCPReadEOFHandler onReadEOF;

/// Termination callback (once).
@property (nullable, nonatomic, copy) TFTCPTerminatedHandler onTerminated;

- (instancetype)initWithTCPPcb:(struct tcp_pcb *)pcb;

- (instancetype)init NS_UNAVAILABLE;

/// One-time transition: marks the connection as established/active.
- (void)markActive;

/// Zero-copy style write API.
/// NOTE:
/// Caller MUST ensure length <= UINT16_MAX (65535).
- (TFTCPWriteResult)writeBytes:(const void *)bytes length:(NSUInteger)length;

- (TFTCPWriteResult)writeData:(NSData *)data;

// Precise receive-window credit (ACK) to lwIP.
// MUST call this after bytes are copied/enqueued in user-space.
- (void)creditReceiveWindow:(NSUInteger)bytes;

- (void)setReceiveEnabled:(BOOL)enabled;

/// Half-close (send FIN; closes the send direction).
- (void)shutdownWrite;

// Full close
- (void)gracefulClose;

/// Force abort (RST/ABRT).
- (void)abort;

@end

NS_ASSUME_NONNULL_END
