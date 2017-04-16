#include <assert.h>

#include "nvim/lib/kvec.h"

#include "nvim/ascii.h"
#include "nvim/state.h"
#include "nvim/vim.h"
#include "nvim/main.h"
#include "nvim/msgpack_rpc/status_event.h"
#include "nvim/getchar.h"
#include "nvim/option_defs.h"
#include "nvim/ui.h"
#include "nvim/os/input.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "state.c.generated.h"
#endif


void state_enter(VimState *s)
{
  for (;;) {
    int check_result = s->check ? s->check(s) : 1;

    if (!check_result) {
      break;
    } else if (check_result == -1) {
      continue;
    }

    int key;

getkey:
    if (char_avail() || using_script() || input_available()) {
      // Don't block for events if there's a character already available for
      // processing. Characters can come from mappings, scripts and other
      // sources, so this scenario is very common.
      key = safe_vgetc();
    } else if (!multiqueue_empty(main_loop.events)) {
      // Event was made available after the last multiqueue_process_events call
      key = K_EVENT;
    } else {
      input_enable_events();
      // Flush screen updates before blocking
      status_event_update_all();
      ui_flush();
      // Call `os_inchar` directly to block for events or user input without
      // consuming anything from `input_buffer`(os/input.c) or calling the
      // mapping engine. If an event was put into the queue, we send K_EVENT
      // directly.
      (void)os_inchar(NULL, 0, -1, 0);
      input_disable_events();
      key = !multiqueue_empty(main_loop.events) ? K_EVENT : safe_vgetc();
    }

    if (key == K_EVENT) {
      may_sync_undo();
    }

    int execute_result = s->execute(s, key);
    if (!execute_result) {
      break;
    } else if (execute_result == -1) {
      goto getkey;
    }
  }
}

/// Return TRUE if in the current mode we need to use virtual.
int virtual_active(void)
{
  // While an operator is being executed we return "virtual_op", because
  // VIsual_active has already been reset, thus we can't check for "block"
  // being used.
  if (virtual_op != MAYBE) {
    return virtual_op;
  }
  return ve_flags == VE_ALL
         || ((ve_flags & VE_BLOCK) && VIsual_active && VIsual_mode == Ctrl_V)
         || ((ve_flags & VE_INSERT) && (State & INSERT));
}

/// VISUAL, SELECTMODE and OP_PENDING State are never set, they are equal to
/// NORMAL State with a condition.  This function returns the real State.
int get_real_state(void)
{
  if (State & NORMAL) {
    if (VIsual_active) {
      if (VIsual_select) {
        return SELECTMODE;
      }
      return VISUAL;
    } else if (finish_op) {
      return OP_PENDING;
    }
  }
  return State;
}

