// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>

#include "nvim/ascii.h"
#include "nvim/autocmd.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_docmd.h"
#include "nvim/getchar.h"
#include "nvim/lib/kvec.h"
#include "nvim/log.h"
#include "nvim/main.h"
#include "nvim/option_defs.h"
#include "nvim/os/input.h"
#include "nvim/state.h"
#include "nvim/ui.h"
#include "nvim/vim.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "state.c.generated.h"
#endif


void state_enter(VimState *s)
{
  for (;;) {
    int check_result = s->check ? s->check(s) : 1;

    if (!check_result) {
      break;     // Terminate this state.
    } else if (check_result == -1) {
      continue;  // check() again.
    }
    // Execute this state.

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
      // Flush screen updates before blocking
      ui_flush();
      // Call `os_inchar` directly to block for events or user input without
      // consuming anything from `input_buffer`(os/input.c) or calling the
      // mapping engine.
      (void)os_inchar(NULL, 0, -1, 0, main_loop.events);
      // If an event was put into the queue, we send K_EVENT directly.
      key = !multiqueue_empty(main_loop.events)
            ? K_EVENT
            : safe_vgetc();
    }

    if (key == K_EVENT) {
      may_sync_undo();
    }

#if MIN_LOG_LEVEL <= DEBUG_LOG_LEVEL
    log_key(DEBUG_LOG_LEVEL, key);
#endif

    int execute_result = s->execute(s, key);
    if (!execute_result) {
      break;
    } else if (execute_result == -1) {
      goto getkey;
    }
  }
}

/// process events on main_loop, but interrupt if input is available
///
/// This should be used to handle K_EVENT in states accepting input
/// otherwise bursts of events can block break checking indefinitely.
void state_handle_k_event(void)
{
  while (true) {
    Event event = multiqueue_get(main_loop.events);
    if (event.handler) {
      event.handler(event.argv);
    }

    if (multiqueue_empty(main_loop.events)) {
      // don't breakcheck before return, caller should return to main-loop
      // and handle input already.
      return;
    }

    // TODO(bfredl): as an further micro-optimization, we could check whether
    // event.handler already checked input.
    os_breakcheck();
    if (input_available() || got_int) {
      return;
    }
  }
}


/// Return true if in the current mode we need to use virtual.
bool virtual_active(void)
{
  // While an operator is being executed we return "virtual_op", because
  // VIsual_active has already been reset, thus we can't check for "block"
  // being used.
  if (virtual_op != kNone) {
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

/// @returns[allocated] mode string
char *get_mode(void)
{
  char *buf = xcalloc(MODE_MAX_LENGTH, sizeof(char));

  if (VIsual_active) {
    if (VIsual_select) {
      buf[0] = (char)(VIsual_mode + 's' - 'v');
    } else {
      buf[0] = (char)VIsual_mode;
      if (restart_VIsual_select) {
        buf[1] = 's';
      }
    }
  } else if (State == HITRETURN || State == ASKMORE || State == SETWSIZE
             || State == CONFIRM) {
    buf[0] = 'r';
    if (State == ASKMORE) {
      buf[1] = 'm';
    } else if (State == CONFIRM) {
      buf[1] = '?';
    }
  } else if (State == EXTERNCMD) {
    buf[0] = '!';
  } else if (State & INSERT) {
    if (State & VREPLACE_FLAG) {
      buf[0] = 'R';
      buf[1] = 'v';
      if (ins_compl_active()) {
        buf[2] = 'c';
      } else if (ctrl_x_mode_not_defined_yet()) {
        buf[2] = 'x';
      }
    } else {
      if (State & REPLACE_FLAG) {
        buf[0] = 'R';
      } else {
        buf[0] = 'i';
      }
      if (ins_compl_active()) {
        buf[1] = 'c';
      } else if (ctrl_x_mode_not_defined_yet()) {
        buf[1] = 'x';
      }
    }
  } else if ((State & CMDLINE) || exmode_active) {
    buf[0] = 'c';
    if (exmode_active) {
      buf[1] = 'v';
    }
  } else if (State & TERM_FOCUS) {
    buf[0] = 't';
  } else {
    buf[0] = 'n';
    if (finish_op) {
      buf[1] = 'o';
      // to be able to detect force-linewise/blockwise/charwise operations
      buf[2] = (char)motion_force;
    } else if (restart_edit == 'I' || restart_edit == 'R'
               || restart_edit == 'V') {
      buf[1] = 'i';
      buf[2] = (char)restart_edit;
    } else if (curbuf->terminal) {
      buf[1] = 't';
    }
  }

  return buf;
}

/// Fires a ModeChanged autocmd.
void trigger_modechanged(void)
{
  if (!has_event(EVENT_MODECHANGED)) {
    return;
  }

  char *mode = get_mode();
  if (STRCMP(mode, last_mode) == 0) {
    xfree(mode);
    return;
  }

  save_v_event_T save_v_event;
  dict_T *v_event = get_v_event(&save_v_event);
  tv_dict_add_str(v_event, S_LEN("new_mode"), mode);
  tv_dict_add_str(v_event, S_LEN("old_mode"), last_mode);

  char_u *pat_pre = concat_str((char_u *)last_mode, (char_u *)":");
  char_u *pat = concat_str(pat_pre, (char_u *)mode);
  xfree(pat_pre);

  apply_autocmds(EVENT_MODECHANGED, pat, NULL, false, curbuf);
  xfree(last_mode);
  last_mode = mode;

  xfree(pat);
  restore_v_event(v_event, &save_v_event);
}
