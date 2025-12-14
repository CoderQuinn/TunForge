// PacketBatcher.h
#import <Foundation/Foundation.h>
#include <stdint.h>
struct pbuf;
@class IPStackCore;

@interface PacketBatcher : NSObject
@property (nonatomic, weak) IPStackCore *stack;
@property (nonatomic, strong) NSMutableArray *pendingPackets; // NSValue(pointer)
@property (nonatomic, assign) uint32_t pendingBytes;
@property (nonatomic, assign) BOOL flushScheduled;

- (instancetype)initWithStack:(IPStackCore *)stack;
- (void)enqueuePbuf:(struct pbuf *)pbuf bytes:(uint32_t)bytes;
- (void)scheduleFlushOnQueue:(dispatch_queue_t)queue afterMs:(uint32_t)ms;
- (void)drainPendingIntoArray:(NSArray *__autoreleasing *)packets bytes:(uint32_t *)bytes;
@end
