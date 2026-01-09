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

/// Return stable unique pointers for dispatch_queue_set/get_specific.
/// Using functions avoids Swift Concurrency warnings about imported global variables.
///

FOUNDATION_EXPORT const void *_Nonnull TFGetpacketsQueueKey(void);
FOUNDATION_EXPORT const void *_Nonnull TFGetConnectionsQueueKey(void);
FOUNDATION_EXPORT void TFAssertOnPACKETSQueue(const char *_Nonnull function,
                                              const char *_Nonnull file,
                                              int line);

#define TF_ASSERT_ON_PACKETS_QUEUE() TFAssertOnPACKETSQueue(__func__, __FILE__, __LINE__)

/// Bind a C-level specific key to a dispatch queue.
/// Swift must NOT call dispatch_queue_set_specific directly.
void TFBindQueueSpecific(dispatch_queue_t _Nonnull queue,
                         const void *_Nonnull key,
                         void *_Nullable value);

/// Check if current execution context is on the given queue.
BOOL TFIsOnQueue(const void *_Nonnull key);

/// Assertions (debug-only)
void TFAssertOnQueue(const void *_Nonnull key,
                     const char *_Nonnull function,
                     const char *_Nonnull file,
                     int line);

/// Returns YES if currently executing on the given queue, using the provided key.
static inline BOOL tf_on_specific_queue(const void *_Nonnull key) {
    return dispatch_get_specific(key) != NULL;
}

/// Performs block synchronously on the specified queue without deadlock if already on queue.
static inline void tf_perform_sync(dispatch_queue_t _Nonnull queue,
                                   const void *_Nonnull key,
                                   dispatch_block_t _Nonnull block) {
    if (tf_on_specific_queue(key)) {
        block();
    } else {
        dispatch_sync(queue, block);
    }
}

/// Performs block asynchronously on the specified queue, avoiding redundant hops if already on
/// queue.
static inline void tf_perform_async(dispatch_queue_t _Nonnull queue,
                                    const void *_Nonnull key,
                                    dispatch_block_t _Nonnull block) {
    if (tf_on_specific_queue(key)) {
        block();
    } else {
        dispatch_async(queue, block);
    }
}
