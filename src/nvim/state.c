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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "state.c.generated.h"
#endif


void state_enter(VimState *s)
{
  // a string to save the command.
  // TODO: temporary, we'll get it directly from the cmdline in the future
  char_u live_cmd[255] = ""; //TODO : check size
  int i = 0;

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

    // append key to cmd_line, ignoring DEL. Other ignored char will be
    // parsed when cmdline will be gotten directly
    if(key == K_DEL || key == K_KDEL || key == K_BS) {
      if(i != 0) i--;
      live_cmd[i] = '\0';
    } else { // Not the good way of doing things
      live_cmd[i++] = (char_u)key;
      live_cmd[i] = '\0';
    }

    if (key == K_EVENT)
      may_sync_undo();

    int execute_result = s->execute(s, key);

    // close buffer and windows if we leave the live_sub mode
    if (!LIVE_MODE) {
      if (livebuf != NULL) {
        close_windows(livebuf, false);
        close_buffer(NULL, livebuf, DOBUF_WIPE, false);
      }
      update_screen(0);
    }

    if (!execute_result) {
      break;
    } else if (execute_result == -1) {
      goto getkey;
    } else if (LIVE_MODE == 1 && is_live(live_cmd) == 1){ // compute a live action
      do_cmdline(live_cmd, NULL, NULL, DOCMD_KEEPLINE);
    }

  }
}