//
//  TFQueueHelpers.h
//  TunForge
//
//  Lightweight helpers for dispatch queue detection and conditional sync/async.
//  Centralizes logic to avoid duplication across modules.
//
//  Created by MagicianQuinn on 2025/12/20.
//

#import <Foundation/Foundation.h>

/// Public dispatch-specific keys used to tag queues for fast detection.
extern const void * _Nonnull TFProcessQueueKey;
extern const void * _Nonnull TFDelegateQueueKey;

/// Returns YES if currently executing on the given queue, using the provided key.
static inline BOOL tf_on_specific_queue(dispatch_queue_t _Nonnull queue, const void * _Nonnull key) {
    return dispatch_get_specific(key) == (__bridge void * _Nullable)(queue);
}

/// Returns YES if currently executing on the stack's processQueue.
static inline BOOL tf_on_process_queue(dispatch_queue_t _Nonnull queue) {
    return tf_on_specific_queue(queue, TFProcessQueueKey);
}

/// Returns YES if currently executing on the stack's delegateQueue.
static inline BOOL tf_on_delegate_queue(dispatch_queue_t _Nonnull queue) {
    return tf_on_specific_queue(queue, TFDelegateQueueKey);
}

/// Performs block synchronously on the specified queue without deadlock if already on queue.
static inline void tf_perform_sync(dispatch_queue_t _Nonnull queue, const void * _Nonnull key, dispatch_block_t _Nonnull block) {
    if (tf_on_specific_queue(queue, key)) {
        block();
    } else {
        dispatch_sync(queue, block);
    }
}

/// Performs block asynchronously on the specified queue, avoiding redundant hops if already on queue.
static inline void tf_perform_async(dispatch_queue_t _Nonnull queue, const void * _Nonnull key, dispatch_block_t _Nonnull block) {
    if (tf_on_specific_queue(queue, key)) {
        block();
    } else {
        dispatch_async(queue, block);
    }
}
