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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "state.c.generated.h"
#endif

static const char* state_desc = NULL;

/// TODO: allow to change modestr, like nx for normal additional
int state_vgetc(const char* desc)
{
  if (char_avail() || using_script() || input_available()) {
    // Don't block for events if there's a character already available for
    // processing. Characters can come from mappings, scripts and other
    // sources, so this scenario is very common.
    return safe_vgetc();
  } else if (!multiqueue_empty(main_loop.events)) {
    // Event was made available after the last multiqueue_process_events call
    return K_EVENT;
  } else {
    input_enable_events();
    const char* save_desc = state_desc;
    state_desc = desc;
    // Flush screen updates before blocking
    ui_flush();
    // Call `os_inchar` directly to block for events or user input without
    // consuming anything from `input_buffer`(os/input.c) or calling the
    // mapping engine.
    (void)os_inchar(NULL, 0, -1, 0);
    state_desc = save_desc;
    input_disable_events();
    // If an event was put into the queue, we send K_EVENT directly.
    return !multiqueue_empty(main_loop.events)
           ? K_EVENT
           : safe_vgetc();
  }
}

void state_process_events(const char* desc)
{
  const char* save_desc = state_desc;
  state_desc = desc;
  multiqueue_process_events(main_loop.events);
  state_desc = save_desc;
}


void state_enter(VimState *s)
{
  // TODO(bfredl): add test for recursively invoking input()
  // in the middle of getchar(), which neeeds this logic
  const char* save_desc = state_desc;
  state_desc = NULL;
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
    key = state_vgetc(NULL);
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
  state_desc = save_desc;
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

/// @returns[allocated] mode string
char *get_mode(void)
{
  if (state_desc) {
    return xstrdup(state_desc);
  }

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
    } else if (State & REPLACE_FLAG) {
      buf[0] = 'R';
    } else {
      buf[0] = 'i';
    }
  } else if (State & CMDLINE) {
    buf[0] = 'c';
    if (exmode_active) {
      buf[1] = 'v';
    }
  } else if (exmode_active) {
    buf[0] = 'c';
    buf[1] = 'e';
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
