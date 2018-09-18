// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>

#include "nvim/lib/kvec.h"

#include "nvim/ascii.h"
#include "nvim/log.h"
#include "nvim/state.h"
#include "nvim/vim.h"
#include "nvim/main.h"
#include "nvim/getchar.h"
#include "nvim/option_defs.h"
#include "nvim/ui.h"
#include "nvim/os/input.h"
#include "nvim/ex_docmd.h"
#include "nvim/edit.h"

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
      input_enable_events();
      // Flush screen updates before blocking
      ui_flush();
      // Call `os_inchar` directly to block for events or user input without
      // consuming anything from `input_buffer`(os/input.c) or calling the
      // mapping engine.
      (void)os_inchar(NULL, 0, -1, 0);
      input_disable_events();
      // If an event was put into the queue, we send K_EVENT directly.
      key = !multiqueue_empty(main_loop.events)
            ? K_EVENT
            : safe_vgetc();
    }

    if (key == K_EVENT) {
      may_sync_undo();
    }

#if MIN_LOG_LEVEL <= DEBUG_LOG_LEVEL
    char *keyname = key == K_EVENT
                    ? "K_EVENT" : (char *)get_special_key_name(key, mod_mask);
    DLOG("input: %s", keyname);
#endif

    int execute_result = s->execute(s, key);
    if (!execute_result) {
      break;
    } else if (execute_result == -1) {
      goto getkey;
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
  char *buf = xcalloc(3, sizeof(char));

  if (VIsual_active) {
    if (VIsual_select) {
      buf[0] = (char)(VIsual_mode + 's' - 'v');
    } else {
      buf[0] = (char)VIsual_mode;
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
    } else {
      if (State & REPLACE_FLAG) {
        buf[0] = 'R';
      } else {
        buf[0] = 'i';
      }
      if (ins_compl_active()) {
        buf[1] = 'c';
      } else if (ctrl_x_mode == 1) {
        buf[1] = 'x';
      }
    }
  } else if ((State & CMDLINE) || exmode_active) {
    buf[0] = 'c';
    if (exmode_active == EXMODE_VIM) {
      buf[1] = 'v';
    } else if (exmode_active == EXMODE_NORMAL) {
      buf[1] = 'e';
    }
  } else if (State & TERM_FOCUS) {
    buf[0] = 't';
  } else {
    buf[0] = 'n';
    if (finish_op) {
      buf[1] = 'o';
    }
  }

  return buf;
}
