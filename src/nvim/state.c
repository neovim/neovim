#include <stdbool.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/drawscreen.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/event/defs.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/ex_getln.h"
#include "nvim/getchar.h"
#include "nvim/globals.h"
#include "nvim/insexpand.h"
#include "nvim/keycodes.h"
#include "nvim/log.h"
#include "nvim/macros_defs.h"
#include "nvim/main.h"
#include "nvim/memory.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/os/input.h"
#include "nvim/state.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "state.c.generated.h"
#endif

void state_enter(VimState *s)
  FUNC_ATTR_NONNULL_ALL
{
  while (true) {
    int check_result = s->check ? s->check(s) : 1;

    if (!check_result) {
      break;     // Terminate this state.
    } else if (check_result == -1) {
      continue;  // check() again.
    }
    // Execute this state.

    int key;

getkey:
    // Apply mappings first by calling vpeekc() directly.
    // - If vpeekc() returns non-NUL, there is a character already available for processing, so
    //   don't block for events. vgetc() may still block, in case of an incomplete UTF-8 sequence.
    // - If vpeekc() returns NUL, vgetc() will block, and there are three cases:
    //   - There is no input available.
    //   - All of available input maps to an empty string.
    //   - There is an incomplete mapping.
    //   A blocking wait for a character should only be done in the third case, which is the only
    //   case of the three where typebuf.tb_len > 0 after vpeekc() returns NUL.
    if (vpeekc() != NUL || typebuf.tb_len > 0) {
      key = safe_vgetc();
    } else if (!multiqueue_empty(main_loop.events)) {
      // No input available and processing events may take time, flush now.
      ui_flush();
      // Event was made available after the last multiqueue_process_events call
      key = K_EVENT;
    } else {
      // Ensure the screen is fully updated before blocking for input. Because of the duality of
      // redraw_later, this can't be done in command-line or when waiting for "Press ENTER".
      // In many of those cases the redraw is expected AFTER the key press, while normally it should
      // update the screen immediately.
      if (must_redraw != 0 && !need_wait_return && (State & MODE_CMDLINE) == 0) {
        update_screen();
        setcursor();  // put cursor back where it belongs
      }
      // Flush screen updates before blocking.
      ui_flush();
      // Call `input_get` directly to block for events or user input without consuming anything from
      // `os/input.c:input_buffer` or calling the mapping engine.
      input_get(NULL, 0, -1, typebuf.tb_change_cnt, main_loop.events);
      // If an event was put into the queue, we send K_EVENT directly.
      if (!input_available() && !multiqueue_empty(main_loop.events)) {
        key = K_EVENT;
      } else {
        goto getkey;
      }
    }

    if (key == K_EVENT) {
      // An event handler may use the value of reg_executing.
      // Clear it if it should be cleared when getting the next character.
      check_end_reg_executing(true);
      may_sync_undo();
    }

#ifdef NVIM_LOG_DEBUG
    char *keyname = key == K_EVENT ? "K_EVENT" : get_special_key_name(key, mod_mask);
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
bool virtual_active(win_T *wp)
{
  unsigned cur_ve_flags = get_ve_flags(wp);

  // While an operator is being executed we return "virtual_op", because
  // VIsual_active has already been reset, thus we can't check for "block"
  // being used.
  if (virtual_op != kNone) {
    return virtual_op;
  }
  return cur_ve_flags == kOptVeFlagAll
         || ((cur_ve_flags & kOptVeFlagBlock) && VIsual_active && VIsual_mode == Ctrl_V)
         || ((cur_ve_flags & kOptVeFlagInsert) && (State & MODE_INSERT));
}

/// MODE_VISUAL, MODE_SELECT and MODE_OP_PENDING State are never set, they are
/// equal to MODE_NORMAL State with a condition.  This function returns the real
/// State.
int get_real_state(void)
{
  if (State & MODE_NORMAL) {
    if (VIsual_active) {
      if (VIsual_select) {
        return MODE_SELECT;
      }
      return MODE_VISUAL;
    } else if (finish_op) {
      return MODE_OP_PENDING;
    }
  }
  return State;
}

/// Returns the current mode as a string in "buf[MODE_MAX_LENGTH]", NUL
/// terminated.
/// The first character represents the major mode, the following ones the minor
/// ones.
void get_mode(char *buf)
  FUNC_ATTR_NONNULL_ALL
{
  int i = 0;

  if (State == MODE_HITRETURN || State == MODE_ASKMORE
      || State == MODE_SETWSIZE || State == MODE_CONFIRM) {
    buf[i++] = 'r';
    if (State == MODE_ASKMORE) {
      buf[i++] = 'm';
    } else if (State == MODE_CONFIRM) {
      buf[i++] = '?';
    }
  } else if (State == MODE_EXTERNCMD) {
    buf[i++] = '!';
  } else if (State & MODE_INSERT) {
    if (State & VREPLACE_FLAG) {
      buf[i++] = 'R';
      buf[i++] = 'v';
    } else {
      if (State & REPLACE_FLAG) {
        buf[i++] = 'R';
      } else {
        buf[i++] = 'i';
      }
    }
    if (ins_compl_active()) {
      buf[i++] = 'c';
    } else if (ctrl_x_mode_not_defined_yet()) {
      buf[i++] = 'x';
    }
  } else if ((State & MODE_CMDLINE) || exmode_active) {
    buf[i++] = 'c';
    if (exmode_active) {
      buf[i++] = 'v';
    }
    if ((State & MODE_CMDLINE) && cmdline_overstrike()) {
      buf[i++] = 'r';
    }
  } else if (State & MODE_TERMINAL) {
    buf[i++] = 't';
  } else if (VIsual_active) {
    if (VIsual_select) {
      buf[i++] = (char)(VIsual_mode + 's' - 'v');
    } else {
      buf[i++] = (char)VIsual_mode;
      if (restart_VIsual_select) {
        buf[i++] = 's';
      }
    }
  } else {
    buf[i++] = 'n';
    if (finish_op) {
      buf[i++] = 'o';
      // to be able to detect force-linewise/blockwise/charwise operations
      buf[i++] = (char)motion_force;
    } else if (curbuf->terminal) {
      buf[i++] = 't';
      if (restart_edit == 'I') {
        buf[i++] = 'T';
      }
    } else if (restart_edit == 'I' || restart_edit == 'R' || restart_edit == 'V') {
      buf[i++] = 'i';
      buf[i++] = (char)restart_edit;
    }
  }

  buf[i] = NUL;
}

/// Fires a ModeChanged autocmd if appropriate.
void may_trigger_modechanged(void)
{
  // Skip this when got_int is set, the autocommand will not be executed.
  // Better trigger it next time.
  if (!has_event(EVENT_MODECHANGED) || got_int) {
    return;
  }

  char curr_mode[MODE_MAX_LENGTH];
  char pattern_buf[2 * MODE_MAX_LENGTH];

  get_mode(curr_mode);
  if (strcmp(curr_mode, last_mode) == 0) {
    return;
  }

  save_v_event_T save_v_event;
  dict_T *v_event = get_v_event(&save_v_event);
  tv_dict_add_str(v_event, S_LEN("new_mode"), curr_mode);
  tv_dict_add_str(v_event, S_LEN("old_mode"), last_mode);
  tv_dict_set_keys_readonly(v_event);

  // concatenate modes in format "old_mode:new_mode"
  vim_snprintf(pattern_buf, sizeof(pattern_buf), "%s:%s", last_mode, curr_mode);

  apply_autocmds(EVENT_MODECHANGED, pattern_buf, NULL, false, curbuf);
  STRCPY(last_mode, curr_mode);

  restore_v_event(v_event, &save_v_event);
}

/// When true in a safe state when starting to wait for a character.
static bool was_safe = false;

/// Return whether currently it is safe, assuming it was safe before (high level
/// state didn't change).
static bool is_safe_now(void)
{
  return stuff_empty()
         && typebuf.tb_len == 0
         && !using_script()
         && !global_busy
         && !debug_mode;
}

/// Trigger SafeState if currently in a safe state, that is "safe" is true and
/// there is no typeahead.
void may_trigger_safestate(bool safe)
{
  bool is_safe = safe && is_safe_now();

  if (was_safe != is_safe) {
    // Only log when the state changes, otherwise it happens at nearly
    // every key stroke.
    DLOG(is_safe ? "SafeState: Start triggering" : "SafeState: Stop triggering");
  }
  if (is_safe) {
    apply_autocmds(EVENT_SAFESTATE, NULL, NULL, false, curbuf);
  }
  was_safe = is_safe;
}

/// Something changed which causes the state possibly to be unsafe, e.g. a
/// character was typed.  It will remain unsafe until the next call to
/// may_trigger_safestate().
void state_no_longer_safe(const char *reason)
{
  if (was_safe && reason != NULL) {
    DLOG("SafeState reset: %s", reason);
  }
  was_safe = false;
}

bool get_was_safe_state(void)
{
  return was_safe;
}
