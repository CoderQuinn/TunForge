//
//  TFIPPacketTestHelpers.h
//  TunForgeCoreTests — craft minimal IPv4 TCP segments for accept-path tests
//

#import <Foundation/Foundation.h>
#import <stdint.h>

NS_ASSUME_NONNULL_BEGIN

/// Build a raw IPv4+TCP segment (20+20 bytes, no options). Addresses/ports in host order.
FOUNDATION_EXPORT NSData *TFIPPacketMakeTCPSegment(uint32_t srcAddr,
                                                   uint32_t dstAddr,
                                                   uint16_t srcPort,
                                                   uint16_t dstPort,
                                                   uint32_t seq,
                                                   uint32_t ack,
                                                   uint8_t flags,
                                                   uint16_t window);

/// Build a raw IPv4+TCP segment with payload (20+20 byte headers, no options).
/// Addresses/ports are in host order.
FOUNDATION_EXPORT NSData *TFIPPacketMakeTCPSegmentWithPayload(uint32_t srcAddr,
                                                              uint32_t dstAddr,
                                                              uint16_t srcPort,
                                                              uint16_t dstPort,
                                                              uint32_t seq,
                                                              uint32_t ack,
                                                              uint8_t flags,
                                                              uint16_t window,
                                                              NSData *payload);

/// Parse IPv4+TCP header fields from a raw packet (host order). Returns NO if too short.
FOUNDATION_EXPORT BOOL TFIPPacketParseTCP(NSData *packet,
                                          uint32_t *_Nullable srcAddr,
                                          uint32_t *_Nullable dstAddr,
                                          uint16_t *_Nullable srcPort,
                                          uint16_t *_Nullable dstPort,
                                          uint32_t *_Nullable seq,
                                          uint32_t *_Nullable ack,
                                          uint8_t *_Nullable flags);

NS_ASSUME_NONNULL_END
