/* Auto platform-selecting lwipopts.h
 *
 * This wrapper picks platform-specific lwIP options provided in
 * lwipopts_ios.h or lwipopts_macos.h. Package.swift defines
 * LWIP_IOS or LWIP_MACOS via cSettings.
 *
 * TunForge policy:
 *  - Keep platform sizing/tuning in lwipopts_ios.h / lwipopts_macos.h
 *  - Keep TunForge patch toggles and hook/marker configuration HERE
 *  - Avoid redefining lwIP core macros in multiple places
 */

#ifndef LWIP_HDR_LWIPOPTS_H
#define LWIP_HDR_LWIPOPTS_H

/* ================================================================
 * Select platform-specific base options
 * ================================================================ */
#if defined(LWIP_IOS)
  #include "lwipopts_ios.h"
#elif defined(LWIP_MACOS)
  #include "lwipopts_macos.h"
#else
  /* Fallback to macOS options */
  #include "lwipopts_macos.h"
#endif

#include "tunforge_bridge.h"
#include "tunforge_extarg_registry.h"

/* ================================================================
 * TunForge transparent TCP patch configuration (ext_arg strategy)
 * ================================================================ */

/* Enable TunForge transparent passive TCP hook (tcp_input interception). */
#ifndef LWIP_TUNFORGE_TRANSPARENT_TCP
#define LWIP_TUNFORGE_TRANSPARENT_TCP 1
#endif

#if LWIP_TUNFORGE_TRANSPARENT_TCP

/* ===== TunForge TCP ext_arg allocation strategy =====
 *
 * TunForge uses ONE ext_arg slot to mark "transparent passive TCP" PCBs.
 *
 * Strategy:
 *  - Do NOT hardcode index 0
 *  - Use the LAST available ext_arg slot
 *  - Extend LWIP_TCP_PCB_NUM_EXT_ARGS only if needed
 *
 * This minimizes conflicts with:
 *  - lwIP internal features
 *  - third-party lwIP extensions
 *  - future lwIP upgrades
 */

#ifndef LWIP_TCP_PCB_NUM_EXT_ARGS
#define LWIP_TCP_PCB_NUM_EXT_ARGS 2
#else
#if LWIP_TCP_PCB_NUM_EXT_ARGS < 2
#undef LWIP_TCP_PCB_NUM_EXT_ARGS
#define LWIP_TCP_PCB_NUM_EXT_ARGS 2
#endif
#endif

/* ===== TunForge hooks =====
 *
 * Avoid macro redefinition:
 *  - If integrator already defines LWIP_HOOK_TCP_NEW_PCB, we respect it.
 *  - Otherwise, we provide a default that forwards to TunForge symbol.
 *
 * This is important because lwIP's LWIP_HOOK_FILENAME mechanism can also
 * define hooks; we should not collide.
 */

/* Forward declare tcp_pcb so prototypes have a visible type. */
struct tcp_pcb;

/* Called when TunForge creates a new SYN_RCVD PCB from tcp_input() interception. */
#ifndef LWIP_HOOK_TCP_NEW_PCB
extern void tunforge_on_new_tcp_pcb(struct tcp_pcb *pcb);
#define LWIP_HOOK_TCP_NEW_PCB(pcb) tunforge_on_new_tcp_pcb(pcb)
#endif

/* Called when a TunForge-marked PCB transitions to ESTABLISHED in tcp_process(). */
#ifndef LWIP_HOOK_TUNFORGE_TCP_ESTABLISHED
extern void tunforge_on_tcp_established(struct tcp_pcb *pcb);
#define LWIP_HOOK_TUNFORGE_TCP_ESTABLISHED(pcb) tunforge_on_tcp_established(pcb)
#endif

#endif /* LWIP_TUNFORGE_TRANSPARENT_TCP */

#endif /* LWIP_HDR_LWIPOPTS_H */
