//
//  tunforge_bridge.c
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/22.
//

#include "tunforge_bridge.h"
#include <CoreFoundation/CoreFoundation.h>

void tf_objcref_pin(void *ref) {
    if (!ref) return;
    CFRetain(ref);
}

void tf_objcref_unpin(void *ref) {
    if (!ref) return;
    CFRelease(ref);
}
