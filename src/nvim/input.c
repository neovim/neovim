// input.c: high level functions for prompting the user or input
// like yes/no or number prompts.

#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/ex_getln.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/input.h"
#include "nvim/keycodes.h"
#include "nvim/math.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/os/input.h"
#include "nvim/state_defs.h"
#include "nvim/ui.h"
#include "nvim/vim_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "input.c.generated.h"  // IWYU pragma: export
#endif

/// Ask for a reply from the user, a 'y' or a 'n', with prompt "str" (which
/// should have been translated already).
///
/// No other characters are accepted, the message is repeated until a valid
/// reply is entered or <C-c> is hit.
///
/// @param[in]  str  Prompt: question to ask user. Is always followed by " (y/n)?".
///
/// @return 'y' or 'n'. Last is also what will be returned in case of interrupt.
int ask_yesno(const char *const str)
{
  const int save_State = State;

  no_wait_return++;
  State = MODE_CONFIRM;  // Mouse behaves like with :confirm.
  setmouse();  // Disable mouse in xterm.
  snprintf(IObuff, IOSIZE, _("%s (y/n)?"), str);
  char *prompt = xstrdup(IObuff);

  int r = ' ';
  while (r != 'y' && r != 'n') {
    // same highlighting as for wait_return()
    r = prompt_for_key(prompt, HLF_R);
    if (r == Ctrl_C || r == ESC) {
      r = 'n';
      if (!ui_has(kUIMessages)) {
        msg_putchar(r);
      }
    }
  }

  no_wait_return--;
  State = save_State;
  setmouse();
  xfree(prompt);

  return r;
}

/// Get a key stroke directly from the user.
///
/// Ignores mouse clicks and scrollbar events, except a click for the left
/// button (used at the more prompt).
/// Doesn't use vgetc(), because it syncs undo and eats mapped characters.
/// Disadvantage: typeahead is ignored.
/// Translates the interrupt character for unix to ESC.
int get_keystroke(MultiQueue *events)
{
  uint8_t *buf = NULL;
  int buflen = 150;
  int len = 0;
  int n;
  int save_mapped_ctrl_c = mapped_ctrl_c;

  mapped_ctrl_c = 0;        // mappings are not used here
  while (true) {
    // flush output before waiting
    ui_flush();
    // Leave some room for check_termcode() to insert a key code into (max
    // 5 chars plus NUL).  And fix_input_buffer() can triple the number of
    // bytes.
    int maxlen = (buflen - 6 - len) / 3;
    if (buf == NULL) {
      buf = xmalloc((size_t)buflen);
    } else if (maxlen < 10) {
      // Need some more space. This might happen when receiving a long
      // escape sequence.
      buflen += 100;
      buf = xrealloc(buf, (size_t)buflen);
      maxlen = (buflen - 6 - len) / 3;
    }

    // First time: blocking wait.  Second time: wait up to 100ms for a
    // terminal code to complete.
    n = input_get(buf + len, maxlen, len == 0 ? -1 : 100, 0, events);
    if (n > 0) {
      // Replace zero and K_SPECIAL by a special key code.
      n = fix_input_buffer(buf + len, n);
      len += n;
    }

    if (n > 0) {  // found a termcode: adjust length
      len = n;
    }
    if (len == 0) {  // nothing typed yet
      continue;
    }

    // Handle modifier and/or special key code.
    n = buf[0];
    if (n == K_SPECIAL) {
      n = TO_SPECIAL(buf[1], buf[2]);
      if (buf[1] == KS_MODIFIER
          || n == K_IGNORE
          || (is_mouse_key(n) && n != K_LEFTMOUSE)) {
        if (buf[1] == KS_MODIFIER) {
          mod_mask = buf[2];
        }
        len -= 3;
        if (len > 0) {
          memmove(buf, buf + 3, (size_t)len);
        }
        continue;
      }
      break;
    }
    if (MB_BYTE2LEN(n) > len) {
      // more bytes to get.
      continue;
    }
    buf[len >= buflen ? buflen - 1 : len] = NUL;
    n = utf_ptr2char((char *)buf);
    break;
  }
  xfree(buf);

  mapped_ctrl_c = save_mapped_ctrl_c;
  return n;
}

/// Output messages, set cmdline_row and save potential "keep_msg",
/// which is otherwise lost to msg_start() in gotocmdline().
static char *prepare_prompt(void)
{
  ui_flush();
  cmdline_row = msg_row;
  return keep_msg ? xstrdup(keep_msg) : NULL;
}

/// Ask the user to enter a number.
///
/// When "mouse_used" is not NULL allow using the mouse and in that case return
/// the line number.
int prompt_for_number(char *prompt, bool *mouse_used)
{
  if (prompt == NULL) {
    if (mouse_used != NULL) {
      prompt = _("Type number and <Enter> or click with the mouse (q or empty cancels):");
    } else {
      prompt = _("Type number and <Enter> (q or empty cancels):");
    }
  }

  int ret = 0;
  char *kmsg = prepare_prompt();

  while (ret == 0) {
    char *resp = getcmdline_prompt(-1, prompt, 0, EXPAND_NOTHING, NULL,
                                   CALLBACK_NONE, false, mouse_used);
    need_wait_return = false;
    msg_didany = false;
    msg_didout = false;

    if (resp == NULL || *resp == NUL || (mouse_used && *mouse_used)) {
      xfree(resp);
      break;
    }

    ret = atoi(resp);
    xfree(resp);
  }

  if (kmsg != NULL) {
    set_keep_msg(kmsg, keep_msg_hl_id);
    xfree(kmsg);
  }

  return ret;
}

/// Ask the user to enter a key.
int prompt_for_key(char *prompt, int hl_id)
{
  int ret = ESC;
  char *kmsg = prepare_prompt();
  char *resp = getcmdline_prompt(-1, prompt, hl_id, EXPAND_NOTHING, NULL,
                                 CALLBACK_NONE, true, NULL);
  need_wait_return = msg_scrolled;
  if (resp != NULL) {
    ret = (int)(*resp);
    xfree(resp);
  }

  if (kmsg != NULL) {
    set_keep_msg(kmsg, keep_msg_hl_id);
    xfree(kmsg);
  }

  return ret;
}
