//
//  TFTCPConnection.h
//  TunForge
//
//  Created by MagicianQuinn on 2026/1/1.
//

/*
 Terminology (lwIP perspective):

 Local  = lwIP / TunForge side
 Peer   = App side (TUN client)

 Note:
 lwIP only handles communication with the App side (Peer), and does not interact with or manage the real server's TCP lifecycle, which is fully handled by upper layers (e.g. NetForge).
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
    TFTCPWriteOverflow,
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

typedef void (^TFTCPReceiveGateCompletion)(void);

typedef void (^TFTCPActivatedHandler)(TFTCPConnection *conn);

typedef void (^TFTCPReadableBytesBatchHandler)(TFTCPConnection *conn,
                                               const TFBytesSlice *slices,
                                               NSUInteger sliceCount,
                                               NSUInteger totalBytesLength,
                                               TFTCPReceiveGateCompletion completion);

typedef void (^TFTCPReadableHandler)(TFTCPConnection *conn, NSData *data);
typedef void (^TFTCPWritableChangedHandler)(TFTCPConnection *conn, BOOL writable);
typedef void (^TFTCPSentBytesHandler)(TFTCPConnection *conn, NSUInteger sentBytes);
typedef void (^TFTCPReadEOFHandler)(TFTCPConnection *conn);
typedef void (^TFTCPTerminatedHandler)(TFTCPConnection *conn,
                                       TFTCPConnectionTerminationReason reason);

@interface TFTCPConnection : NSObject

@property (nonatomic, strong, readonly) TFTCPConnectionInfo *info;
@property (nonatomic, assign, readonly) BOOL alive;
@property (nonatomic, assign, readonly) BOOL writable;

/// Fired exactly once after the TCP connection becomes active.
/// “Inbound delivery is gated via setInboundDeliveryEnabled, typically driven by Flow backpressure.
/// to allow inbound data delivery from lwIP.
@property (nullable, nonatomic, copy) TFTCPActivatedHandler onActivated;

/// Compatibility path. Will allocate & copy.
/// Prefer onReadableBytes for zero-additional-copy at the bridge layer.
@property (nullable, nonatomic, copy) TFTCPReadableHandler onReadable;

/// Zero-copy receive path.
/// `completion` MUST be called exactly once to release internal buffers.
@property (nullable, nonatomic, copy) TFTCPReadableBytesBatchHandler onReadableBytes;

/// lwIP send-buffer writability changes
/// (i.e. ability to send data *to the Peer / App* via lwIP TCP).
@property (nullable, nonatomic, copy) TFTCPWritableChangedHandler onWritableChanged;

/// Peer ACKed sent data (tcp_sent); callback provides len (u16).
@property (nullable, nonatomic, copy) TFTCPSentBytesHandler onSentBytes;

@property (nullable, nonatomic, copy) TFTCPReadEOFHandler onReadEOF;

/// Termination callback (once).
@property (nullable, nonatomic, copy) TFTCPTerminatedHandler onTerminated;

- (instancetype)initWithTCPPcb:(struct tcp_pcb *)pcb;

- (instancetype)init NS_UNAVAILABLE;

// Marks the connection as active, accepting the lwIP TCP connection
// and allowing data delivery to upper layers.
- (void)markActive;

/// Controls whether inbound payloads from app are delivered to upper layers.
/// Flow-control gate only; does not affect TCP state or send FIN.
- (void)setInboundDeliveryEnabled:(BOOL)enabled;

/// Zero-copy style write API.
/// NOTE:
// Contract: caller MUST ensure length <= UINT16_MAX, length > 0
- (TFTCPWriteResult)writeBytes:(const void *)bytes length:(NSUInteger)length;

// Writes data to TCP connection, similar to writeBytes, but takes NSData as input.
// Ensures that data length is within bounds (<= UINT16_MAX).
- (TFTCPWriteResult)writeData:(NSData *)data;

/// Half-close (Shut down send side).
- (void)shutdownWrite;

// Full close
- (void)gracefulClose;

/// Force abort (RST/ABRT).
- (void)abort;

@end

NS_ASSUME_NONNULL_END
