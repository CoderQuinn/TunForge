//
//  TFQueueHelpers.m
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/23.
//

#import "TFQueueHelpers.h"

void TFBindQueueSpecific(dispatch_queue_t queue, const void *key, void *value) {
    dispatch_queue_set_specific(queue, key, value, NULL);
}

BOOL TFIsOnQueue(const void *key) {
    return dispatch_get_specific(key) != NULL;
}

void TFAssertOnQueue(const void *key, const char *function, const char *file, int line) {
#if DEBUG
    if (!TFIsOnQueue(key)) {
        NSLog(@"[TFQueueAssert] ❌ Wrong queue in %s (%s:%d)", function, file, line);
        abort();
    }
#endif
}

// Use static storage addresses as unique keys.
const void *TFGetpacketsQueueKey(void) {
    static uint8_t kProcessKey;
    return &kProcessKey;
}

const void *TFGetConnectionsQueueKey(void) {
    static uint8_t kDelegateKey;
    return &kDelegateKey;
}

void TFAssertOnPACKETSQueue(const char *function, const char *file, int line) {
#if DEBUG
    NSCAssert(TFIsOnQueue(TFGetpacketsQueueKey()),
              @"Must be used on packets process queue (%s:%d %s)",
              file,
              line,
              function);
#endif
}
