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

/// Parse IPv4+TCP header fields from a raw packet (host order). Returns NO if too short.
FOUNDATION_EXPORT BOOL TFIPPacketParseTCP(NSData *packet,
                                          uint32_t *srcAddr,
                                          uint32_t *dstAddr,
                                          uint16_t *srcPort,
                                          uint16_t *dstPort,
                                          uint32_t *seq,
                                          uint32_t *ack,
                                          uint8_t *flags);

NS_ASSUME_NONNULL_END
