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
///
/// Use this instead of `onReadable` when you can process the received bytes
/// directly (e.g. parsing, forwarding, or encoding) without requiring an extra
/// copy into an `NSData` instance. This is the most efficient way to consume
/// inbound data at the bridge layer.
///
/// Lifecycle:
/// - The `bytes` pointers contained in each `TFBytesSlice` are only valid for
///   the duration of the handler invocation.
/// - You MUST call the provided `completion` block exactly once for each call
///   to this handler to signal that you are done with the slices.
/// - After `completion` returns, the underlying buffers may be reused or freed;
///   you MUST NOT read from or otherwise access `TFBytesSlice.bytes` beyond
///   that point.
/// - If you need to retain any data beyond the call, copy it before invoking
///   `completion`.
///
/// Thread safety:
/// - The handler is invoked on the connection's internal execution context
///   (e.g. its event-loop / lwIP callback thread).
/// - It should be treated as NOT thread-safe: if you share data structures
///   with other threads, you are responsible for any necessary synchronization.
/// - Do not block for long periods inside the handler; offload expensive work
///   to your own queue and copy the data if needed before returning.
@property (nullable, nonatomic, copy) TFTCPReadableBytesBatchHandler onReadableBytes;

/// Edge changes of sendbuf writability (driven by ERR_MEM / tcp_sent / poll).
@property (nullable, nonatomic, copy) TFTCPWritableChangedHandler onWritableChanged;

/// Peer ACKed sent data (tcp_sent); callback provides len (u16).
@property (nullable, nonatomic, copy) TFTCPSentBytesHandler onSentBytes;

@property (nonatomic, copy, nullable) TFTCPReadEOFHandler onReadEOF;

/// Termination callback (once).
@property (nullable, nonatomic, copy) TFTCPTerminatedHandler onTerminated;

- (instancetype)initWithTCPPcb:(struct tcp_pcb *)pcb;

- (instancetype)init NS_UNAVAILABLE;

/// One-time transition: marks the connection as established/active.
- (void)markActive;

/// Zero-copy style write API.
/// Unlike `writeData:`, this method does not create or retain an `NSData`
/// wrapper for the payload and can be used to avoid an extra copy at the
/// Objective-C/bridge layer when the bytes are already in contiguous memory.
///
/// @param bytes  Pointer to a readable buffer containing at least `length`
///               bytes. Must be non-NULL when `length > 0`.
/// @param length Number of bytes to attempt to enqueue for transmission.
///
/// @return The number of bytes accepted for transmission. This may be less
///         than `length` if the underlying send buffer cannot currently accept
///         more data (e.g. due to backpressure). A return value of `0`
///         typically indicates that no additional bytes can be written at
///         this time.
///
/// Thread-safety: This method is not inherently thread-safe. Callers must
/// invoke it from the same thread or dispatch queue that owns the
/// `TFTCPConnection` instance (typically the connection's event/callback
/// context).
- (NSUInteger)writeBytes:(const void *)bytes length:(NSUInteger)length;

- (NSUInteger)writeData:(NSData *)data;

// NOTE:
// Used only in precise-ACK, experimental unused.
- (void)ackRecvBytes:(NSUInteger)bytes;

- (void)setRecvEnabled:(BOOL)enabled;

/// Half-close (send FIN; closes the send direction).
- (void)shutdownWrite;

// Full close
- (void)gracefulClose;

/// Force abort (RST/ABRT).
- (void)abort;

@end

NS_ASSUME_NONNULL_END
