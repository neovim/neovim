// input.c: high level functions for prompting the user or input
// like yes/no or number prompts.

#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/input.h"
#include "nvim/keycodes.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/os/input.h"
#include "nvim/state_defs.h"
#include "nvim/ui.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "input.c.generated.h"  // IWYU pragma: export
#endif

/// Ask for a reply from the user, a 'y' or a 'n', with prompt "str" (which
/// should have been translated already).
///
/// No other characters are accepted, the message is repeated until a valid
/// reply is entered or <C-c> is hit.
///
/// @param[in]  str  Prompt: question to ask user. Is always followed by
///                  " (y/n)?".
/// @param[in]  direct  Determines what function to use to get user input. If
///                     true then os_inchar() will be used, otherwise vgetc().
///                     I.e. when direct is true then characters are obtained
///                     directly from the user without buffers involved.
///
/// @return 'y' or 'n'. Last is also what will be returned in case of interrupt.
int ask_yesno(const char *const str, const bool direct)
{
  const int save_State = State;

  no_wait_return++;
  State = MODE_CONFIRM;  // Mouse behaves like with :confirm.
  setmouse();  // Disable mouse in xterm.
  no_mapping++;
  allow_keys++;  // no mapping here, but recognize keys

  int r = ' ';
  while (r != 'y' && r != 'n') {
    // same highlighting as for wait_return()
    smsg(HL_ATTR(HLF_R), "%s (y/n)?", str);
    if (direct) {
      r = get_keystroke(NULL);
    } else {
      r = plain_vgetc();
    }
    if (r == Ctrl_C || r == ESC) {
      r = 'n';
    }
    msg_putchar(r);  // Show what you typed.
    ui_flush();
  }
  no_wait_return--;
  State = save_State;
  setmouse();
  no_mapping--;
  allow_keys--;

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
    n = os_inchar(buf + len, maxlen, len == 0 ? -1 : 100, 0, events);
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

/// Get a number from the user.
/// When "mouse_used" is not NULL allow using the mouse.
///
/// @param colon  allow colon to abort
int get_number(int colon, bool *mouse_used)
{
  int n = 0;
  int typed = 0;

  if (mouse_used != NULL) {
    *mouse_used = false;
  }

  // When not printing messages, the user won't know what to type, return a
  // zero (as if CR was hit).
  if (msg_silent != 0) {
    return 0;
  }

  no_mapping++;
  allow_keys++;  // no mapping here, but recognize keys
  while (true) {
    ui_cursor_goto(msg_row, msg_col);
    int c = safe_vgetc();
    if (ascii_isdigit(c)) {
      if (n > INT_MAX / 10) {
        return 0;
      }
      n = n * 10 + c - '0';
      msg_putchar(c);
      typed++;
    } else if (c == K_DEL || c == K_KDEL || c == K_BS || c == Ctrl_H) {
      if (typed > 0) {
        msg_puts("\b \b");
        typed--;
      }
      n /= 10;
    } else if (mouse_used != NULL && c == K_LEFTMOUSE) {
      *mouse_used = true;
      n = mouse_row + 1;
      break;
    } else if (n == 0 && c == ':' && colon) {
      stuffcharReadbuff(':');
      if (!exmode_active) {
        cmdline_row = msg_row;
      }
      skip_redraw = true;           // skip redraw once
      do_redraw = false;
      break;
    } else if (c == Ctrl_C || c == ESC || c == 'q') {
      n = 0;
      break;
    } else if (c == CAR || c == NL) {
      break;
    }
  }
  no_mapping--;
  allow_keys--;
  return n;
}

/// Ask the user to enter a number.
///
/// When "mouse_used" is not NULL allow using the mouse and in that case return
/// the line number.
int prompt_for_number(bool *mouse_used)
{
  // When using ":silent" assume that <CR> was entered.
  if (mouse_used != NULL) {
    msg_puts(_("Type number and <Enter> or click with the mouse "
               "(q or empty cancels): "));
  } else {
    msg_puts(_("Type number and <Enter> (q or empty cancels): "));
  }

  // Set the state such that text can be selected/copied/pasted and we still
  // get mouse events.
  int save_cmdline_row = cmdline_row;
  cmdline_row = 0;
  int save_State = State;
  State = MODE_ASKMORE;  // prevents a screen update when using a timer
  // May show different mouse shape.
  setmouse();

  int i = get_number(true, mouse_used);
  if (KeyTyped) {
    // don't call wait_return() now
    if (msg_row > 0) {
      cmdline_row = msg_row - 1;
    }
    need_wait_return = false;
    msg_didany = false;
    msg_didout = false;
  } else {
    cmdline_row = save_cmdline_row;
  }
  State = save_State;
  // May need to restore mouse shape.
  setmouse();

  return i;
}
