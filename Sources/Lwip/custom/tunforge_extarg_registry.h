//
//  tunforge_extarg_registry.h
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/22.
//

#ifndef tunforge_extarg_registry_h
#define tunforge_extarg_registry_h
/* Forward declaration to avoid pulling tcp.h while lwipopts.h is parsed. */
struct tcp_pcb;

/* ===== ext arg indices ===== */
#define TUNFORGE_STACK_EXTARG_IDX   0
#define TUNFORGE_SOCKET_EXTARG_IDX  1

/* ===== bind ===== */
void tunforge_tcp_bind_stack(struct tcp_pcb *pcb, void *stackRef);
void tunforge_tcp_bind_socket(struct tcp_pcb *pcb, void *socketRef);

/* ===== get ===== */
void *tunforge_tcp_get_stack(struct tcp_pcb *pcb);

// NOTE: currently unused.
// Reserved for future lwIP-side socket introspection / debugging.
void *tunforge_tcp_get_socket(struct tcp_pcb *pcb);

#endif /* tunforge_extarg_registry_h */
