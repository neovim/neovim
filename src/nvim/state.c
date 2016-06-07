#include <assert.h>

#include "nvim/lib/kvec.h"

#include "nvim/state.h"
#include "nvim/vim.h"
#include "nvim/getchar.h"
#include "nvim/ui.h"
#include "nvim/os/input.h"

#include "nvim/ex_getln.h"
#include "nvim/ex_docmd.h"
#include "nvim/window.h"
#include "nvim/buffer.h"
#include "nvim/ascii.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "state.c.generated.h"
#endif


void state_enter(VimState *s)
{
  // a string to save the command.

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
    } else if (!queue_empty(loop.events)) {
      // Event was made available after the last queue_process_events call
      key = K_EVENT;
    } else {
      input_enable_events();
      // Flush screen updates before blocking
      ui_flush();
      // Call `os_inchar` directly to block for events or user input without
      // consuming anything from `input_buffer`(os/input.c) or calling the
      // mapping engine. If an event was put into the queue, we send K_EVENT
      // directly.
      (void)os_inchar(NULL, 0, -1, 0);
      input_disable_events();
      key = !queue_empty(loop.events) ? K_EVENT : safe_vgetc();
    }

    if (key == K_EVENT)
      may_sync_undo();

    int execute_result = s->execute(s, key);

    // close buffer and windows if we leave the live_sub mode
    // and undo
    if (p_sub && LIVE_MODE && (key == ESC || key == Ctrl_C) && is_live(access_cmdline())) {
      LIVE_MODE = 0;
      do_cmdline_cmd(":u");
      finish_live_cmd(NORMAL, NULL, 0, 0, 0);
      //normal_enter(true, true);
      // TODO : a temporary solution to get back to a normal state
      do_cmdline((char_u *)":s/a/a", NULL, NULL, 0);
      redraw_later(SOME_VALID);
      return;
    }
    if (!execute_result) {
      break;
    } else if (execute_result == -1) {
      goto getkey;
    } else if (p_sub && LIVE_MODE == 1 && is_live(access_cmdline())){
      // compute a live action
      do_cmdline(access_cmdline(), NULL, NULL, DOCMD_KEEPLINE);
    }
  }
}
