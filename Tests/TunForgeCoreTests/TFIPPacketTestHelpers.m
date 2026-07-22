//
//  TFIPPacketTestHelpers.m
//  TunForgeCoreTests
//

#import "TFIPPacketTestHelpers.h"

#include <arpa/inet.h>
#include <string.h>

static uint16_t tf_checksum(const void *data, size_t len) {
    const uint8_t *bytes = data;
    uint32_t sum = 0;
    size_t i = 0;
    for (; i + 1 < len; i += 2) {
        sum += ((uint16_t)bytes[i] << 8) | bytes[i + 1];
    }
    if (i < len) {
        sum += (uint16_t)bytes[i] << 8;
    }
    while (sum >> 16) {
        sum = (sum & 0xffffu) + (sum >> 16);
    }
    return (uint16_t)~sum;
}

NSData *TFIPPacketMakeTCPSegment(uint32_t srcAddr,
                                 uint32_t dstAddr,
                                 uint16_t srcPort,
                                 uint16_t dstPort,
                                 uint32_t seq,
                                 uint32_t ack,
                                 uint8_t flags,
                                 uint16_t window) {
    uint8_t buf[40];
    memset(buf, 0, sizeof(buf));

    // IPv4
    buf[0] = 0x45;
    buf[1] = 0;
    uint16_t totalLen = 40;
    buf[2] = (uint8_t)(totalLen >> 8);
    buf[3] = (uint8_t)(totalLen & 0xff);
    buf[8] = 64;  // TTL
    buf[9] = 6;   // TCP
    uint32_t srcN = htonl(srcAddr);
    uint32_t dstN = htonl(dstAddr);
    memcpy(buf + 12, &srcN, 4);
    memcpy(buf + 16, &dstN, 4);
    uint16_t ipCsum = tf_checksum(buf, 20);
    buf[10] = (uint8_t)(ipCsum >> 8);
    buf[11] = (uint8_t)(ipCsum & 0xff);

    // TCP
    buf[20] = (uint8_t)(srcPort >> 8);
    buf[21] = (uint8_t)(srcPort & 0xff);
    buf[22] = (uint8_t)(dstPort >> 8);
    buf[23] = (uint8_t)(dstPort & 0xff);
    uint32_t seqN = htonl(seq);
    uint32_t ackN = htonl(ack);
    memcpy(buf + 24, &seqN, 4);
    memcpy(buf + 28, &ackN, 4);
    buf[32] = 0x50; // data offset = 5 (20 bytes)
    buf[33] = flags;
    buf[34] = (uint8_t)(window >> 8);
    buf[35] = (uint8_t)(window & 0xff);

    // TCP checksum over pseudo-header + TCP
    uint8_t pseudo[12 + 20];
    memcpy(pseudo, &srcN, 4);
    memcpy(pseudo + 4, &dstN, 4);
    pseudo[8] = 0;
    pseudo[9] = 6;
    pseudo[10] = 0;
    pseudo[11] = 20;
    memcpy(pseudo + 12, buf + 20, 20);
    uint16_t tcpCsum = tf_checksum(pseudo, sizeof(pseudo));
    buf[36] = (uint8_t)(tcpCsum >> 8);
    buf[37] = (uint8_t)(tcpCsum & 0xff);

    return [NSData dataWithBytes:buf length:sizeof(buf)];
}

BOOL TFIPPacketParseTCP(NSData *packet,
                        uint32_t *srcAddr,
                        uint32_t *dstAddr,
                        uint16_t *srcPort,
                        uint16_t *dstPort,
                        uint32_t *seq,
                        uint32_t *ack,
                        uint8_t *flags) {
    if (packet.length < 40) {
        return NO;
    }
    const uint8_t *buf = packet.bytes;
    uint8_t ihl = (buf[0] & 0x0f) * 4;
    if (ihl < 20 || packet.length < (NSUInteger)ihl + 20) {
        return NO;
    }
    uint32_t srcN, dstN, seqN, ackN;
    memcpy(&srcN, buf + 12, 4);
    memcpy(&dstN, buf + 16, 4);
    const uint8_t *tcp = buf + ihl;
    if (srcAddr)
        *srcAddr = ntohl(srcN);
    if (dstAddr)
        *dstAddr = ntohl(dstN);
    if (srcPort)
        *srcPort = (uint16_t)((tcp[0] << 8) | tcp[1]);
    if (dstPort)
        *dstPort = (uint16_t)((tcp[2] << 8) | tcp[3]);
    memcpy(&seqN, tcp + 4, 4);
    memcpy(&ackN, tcp + 8, 4);
    if (seq)
        *seq = ntohl(seqN);
    if (ack)
        *ack = ntohl(ackN);
    if (flags)
        *flags = tcp[13];
    return YES;
}
