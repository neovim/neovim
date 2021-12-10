// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * misc1.c: functions that didn't seem to fit elsewhere
 */

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/buffer_updates.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/event/stream.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/func_attr.h"
#include "nvim/garray.h"
#include "nvim/getchar.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/main.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/shell.h"
#include "nvim/os/signal.h"
#include "nvim/os/time.h"
#include "nvim/os_unix.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/state.h"
#include "nvim/strings.h"
#include "nvim/tag.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/vim.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "misc1.c.generated.h"
#endif

/// Ask for a reply from the user, 'y' or 'n'
///
/// No other characters are accepted, the message is repeated until a valid
/// reply is entered or <C-c> is hit.
///
/// @param[in]  str  Prompt: question to ask user. Is always followed by
///                  " (y/n)?".
/// @param[in]  direct  Determines what function to use to get user input. If
///                     true then ui_inchar() will be used, otherwise vgetc().
///                     I.e. when direct is true then characters are obtained
///                     directly from the user without buffers involved.
///
/// @return 'y' or 'n'. Last is also what will be returned in case of interrupt.
int ask_yesno(const char *const str, const bool direct)
{
  const int save_State = State;

  no_wait_return++;
  State = CONFIRM;  // Mouse behaves like with :confirm.
  setmouse();  // Disable mouse in xterm.
  no_mapping++;

  int r = ' ';
  while (r != 'y' && r != 'n') {
    // Same highlighting as for wait_return.
    smsg_attr(HL_ATTR(HLF_R), "%s (y/n)?", str);
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

  return r;
}

/*
 * Return TRUE if "c" is a mouse key.
 */
int is_mouse_key(int c)
{
  return c == K_LEFTMOUSE
         || c == K_LEFTMOUSE_NM
         || c == K_LEFTDRAG
         || c == K_LEFTRELEASE
         || c == K_LEFTRELEASE_NM
         || c == K_MOUSEMOVE
         || c == K_MIDDLEMOUSE
         || c == K_MIDDLEDRAG
         || c == K_MIDDLERELEASE
         || c == K_RIGHTMOUSE
         || c == K_RIGHTDRAG
         || c == K_RIGHTRELEASE
         || c == K_MOUSEDOWN
         || c == K_MOUSEUP
         || c == K_MOUSELEFT
         || c == K_MOUSERIGHT
         || c == K_X1MOUSE
         || c == K_X1DRAG
         || c == K_X1RELEASE
         || c == K_X2MOUSE
         || c == K_X2DRAG
         || c == K_X2RELEASE;
}

/*
 * Get a key stroke directly from the user.
 * Ignores mouse clicks and scrollbar events, except a click for the left
 * button (used at the more prompt).
 * Doesn't use vgetc(), because it syncs undo and eats mapped characters.
 * Disadvantage: typeahead is ignored.
 * Translates the interrupt character for unix to ESC.
 */
int get_keystroke(MultiQueue *events)
{
  char_u *buf = NULL;
  int buflen = 150;
  int maxlen;
  int len = 0;
  int n;
  int save_mapped_ctrl_c = mapped_ctrl_c;
  int waited = 0;

  mapped_ctrl_c = 0;        // mappings are not used here
  for (;;) {
    // flush output before waiting
    ui_flush();
    // Leave some room for check_termcode() to insert a key code into (max
    // 5 chars plus NUL).  And fix_input_buffer() can triple the number of
    // bytes.
    maxlen = (buflen - 6 - len) / 3;
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
    n = os_inchar(buf + len, maxlen, len == 0 ? -1L : 100L, 0, events);
    if (n > 0) {
      // Replace zero and CSI by a special key code.
      n = fix_input_buffer(buf + len, n);
      len += n;
      waited = 0;
    } else if (len > 0) {
      ++waited;             // keep track of the waiting time
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
    n = utf_ptr2char(buf);
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
int get_number(int colon, int *mouse_used)
{
  int n = 0;
  int c;
  int typed = 0;

  if (mouse_used != NULL) {
    *mouse_used = FALSE;
  }

  // When not printing messages, the user won't know what to type, return a
  // zero (as if CR was hit).
  if (msg_silent != 0) {
    return 0;
  }

  no_mapping++;
  for (;;) {
    ui_cursor_goto(msg_row, msg_col);
    c = safe_vgetc();
    if (ascii_isdigit(c)) {
      n = n * 10 + c - '0';
      msg_putchar(c);
      ++typed;
    } else if (c == K_DEL || c == K_KDEL || c == K_BS || c == Ctrl_H) {
      if (typed > 0) {
        msg_puts("\b \b");
        --typed;
      }
      n /= 10;
    } else if (mouse_used != NULL && c == K_LEFTMOUSE) {
      *mouse_used = TRUE;
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
  return n;
}

/*
 * Ask the user to enter a number.
 * When "mouse_used" is not NULL allow using the mouse and in that case return
 * the line number.
 */
int prompt_for_number(int *mouse_used)
{
  int i;
  int save_cmdline_row;
  int save_State;

  // When using ":silent" assume that <CR> was entered.
  if (mouse_used != NULL) {
    msg_puts(_("Type number and <Enter> or click with the mouse "
               "(q or empty cancels): "));
  } else {
    msg_puts(_("Type number and <Enter> (q or empty cancels): "));
  }

  /* Set the state such that text can be selected/copied/pasted and we still
   * get mouse events. */
  save_cmdline_row = cmdline_row;
  cmdline_row = 0;
  save_State = State;
  State = ASKMORE;  // prevents a screen update when using a timer
  // May show different mouse shape.
  setmouse();

  i = get_number(TRUE, mouse_used);
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

/// os_call_shell() wrapper. Handles 'verbose', :profile, and v:shell_error.
/// Invalidates cached tags.
///
/// @return shell command exit code
int call_shell(char_u *cmd, ShellOpts opts, char_u *extra_shell_arg)
{
  int retval;
  proftime_T wait_time;

  if (p_verbose > 3) {
    verbose_enter();
    smsg(_("Executing command: \"%s\""), cmd == NULL ? p_sh : cmd);
    msg_putchar('\n');
    verbose_leave();
  }

  if (do_profiling == PROF_YES) {
    prof_child_enter(&wait_time);
  }

  if (*p_sh == NUL) {
    emsg(_(e_shellempty));
    retval = -1;
  } else {
    // The external command may update a tags file, clear cached tags.
    tag_freematch();

    retval = os_call_shell(cmd, opts, extra_shell_arg);
  }

  set_vim_var_nr(VV_SHELL_ERROR, (varnumber_T)retval);
  if (do_profiling == PROF_YES) {
    prof_child_exit(&wait_time);
  }

  return retval;
}

/// Get the stdout of an external command.
/// If "ret_len" is NULL replace NUL characters with NL. When "ret_len" is not
/// NULL store the length there.
///
/// @param  cmd      command to execute
/// @param  infile   optional input file name
/// @param  flags    can be kShellOptSilent or 0
/// @param  ret_len  length of the stdout
///
/// @return an allocated string, or NULL for error.
char_u *get_cmd_output(char_u *cmd, char_u *infile, ShellOpts flags, size_t *ret_len)
{
  char_u *buffer = NULL;

  if (check_secure()) {
    return NULL;
  }

  // get a name for the temp file
  char_u *tempname = vim_tempname();
  if (tempname == NULL) {
    emsg(_(e_notmp));
    return NULL;
  }

  // Add the redirection stuff
  char_u *command = make_filter_cmd(cmd, infile, tempname);

  /*
   * Call the shell to execute the command (errors are ignored).
   * Don't check timestamps here.
   */
  ++no_check_timestamps;
  call_shell(command, kShellOptDoOut | kShellOptExpand | flags, NULL);
  --no_check_timestamps;

  xfree(command);

  // read the names from the file into memory
  FILE *fd = os_fopen((char *)tempname, READBIN);

  if (fd == NULL) {
    semsg(_(e_notopen), tempname);
    goto done;
  }

  fseek(fd, 0L, SEEK_END);
  size_t len = (size_t)ftell(fd);  // get size of temp file
  fseek(fd, 0L, SEEK_SET);

  buffer = xmalloc(len + 1);
  size_t i = fread((char *)buffer, 1, len, fd);
  fclose(fd);
  os_remove((char *)tempname);
  if (i != len) {
    semsg(_(e_notread), tempname);
    XFREE_CLEAR(buffer);
  } else if (ret_len == NULL) {
    // Change NUL into SOH, otherwise the string is truncated.
    for (i = 0; i < len; ++i) {
      if (buffer[i] == NUL) {
        buffer[i] = 1;
      }
    }

    buffer[len] = NUL;          // make sure the buffer is terminated
  } else {
    *ret_len = len;
  }

done:
  xfree(tempname);
  return buffer;
}
