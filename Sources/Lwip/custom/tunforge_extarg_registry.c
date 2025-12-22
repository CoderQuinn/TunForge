//
//  tunforge_extarg_registry.c
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/22.
//

#include "tunforge_extarg_registry.h"
#include "tunforge_bridge.h"
#include "lwip/tcp.h"

static void
tunforge_extarg_destroy(u8_t id, void *arg)
{
    if (arg) {
        tf_objcref_unpin(arg);   // ⭐ 唯一 unpin 点
    }
}

static const struct tcp_ext_arg_callbacks tunforge_extarg_cbs = {
    .destroy = tunforge_extarg_destroy
};

static void
tunforge_tcp_bind(struct tcp_pcb *pcb, u8_t idx, void *ref)
{
    LWIP_ASSERT_CORE_LOCKED();
    LWIP_ASSERT("pcb", pcb != NULL);

    if (!ref) return;

    tf_objcref_pin(ref);  // pin

    tcp_ext_arg_set(pcb, idx, ref);
    tcp_ext_arg_set_callbacks(pcb, idx, &tunforge_extarg_cbs);
}

void tunforge_tcp_bind_stack(struct tcp_pcb *pcb, void *stackRef)
{
    tunforge_tcp_bind(pcb, TUNFORGE_STACK_EXTARG_IDX, stackRef);
}

void tunforge_tcp_bind_socket(struct tcp_pcb *pcb, void *socketRef)
{
    tunforge_tcp_bind(pcb, TUNFORGE_SOCKET_EXTARG_IDX, socketRef);
}

void *tunforge_tcp_get_stack(struct tcp_pcb *pcb)
{
    return pcb
        ? tcp_ext_arg_get(pcb, TUNFORGE_STACK_EXTARG_IDX)
        : NULL;
}

void *tunforge_tcp_get_socket(struct tcp_pcb *pcb)
{
    return pcb
        ? tcp_ext_arg_get(pcb, TUNFORGE_SOCKET_EXTARG_IDX)
        : NULL;
}
