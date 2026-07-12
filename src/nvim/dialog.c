// dialog.c: user prompts and console dialogs (yes/no, number, confirm()).

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/dialog.h"
#include "nvim/ex_getln.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
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

#include "dialog.c.generated.h"  // IWYU pragma: export

// Magic chars used in confirm dialog strings
enum {
  DLG_BUTTON_SEP = '\n',
  DLG_HOTKEY_CHAR = '&',
};

char *confirm_msg = NULL;      // ":confirm" message
char *confirm_buttons = NULL;  // ":confirm" buttons sent to cmdline as prompt

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
  snprintf(IObuff, IOSIZE, _("%s (y/n)?"), str);
  char *prompt = xstrdup(IObuff);

  int r = ' ';
  while (r != 'y' && r != 'n') {
    // same highlighting as for wait_return()
    r = prompt_for_input(prompt, HLF_R, true, NULL);
    if (r == Ctrl_C || r == ESC) {
      r = 'n';
      if (!ui_has(kUIMessages)) {
        msg_putchar(r);
      }
    }
  }

  need_wait_return = msg_scrolled;
  no_wait_return--;
  State = save_State;
  setmouse();
  xfree(prompt);

  return r;
}

/// Ask the user for input through a cmdline prompt.
///
/// @param one_key Return from cmdline after one key press.
/// @param mouse_used When not NULL, allow using the mouse to press a number.
int prompt_for_input(char *prompt, int hl_id, bool one_key, bool *mouse_used)
{
  int ret = one_key ? ESC : 0;
  char *kmsg = keep_msg ? xstrdup(keep_msg) : NULL;

  if (prompt == NULL) {
    if (mouse_used != NULL) {
      prompt = _("Type number and <Enter> or click with the mouse (q or empty cancels): ");
    } else {
      prompt = _("Type number and <Enter> (q or empty cancels): ");
    }
  }

  cmdline_row = msg_row;
  ui_flush();

  no_mapping++;  // don't map prompt input
  allow_keys++;  // allow special keys
  char *resp = getcmdline_prompt(-1, prompt, hl_id, EXPAND_NOTHING, NULL,
                                 CALLBACK_NONE, one_key, mouse_used);
  allow_keys--;
  no_mapping--;

  if (resp) {
    ret = one_key ? (int)(*resp) : atoi(resp);
    xfree(resp);
  }

  if (kmsg != NULL) {
    set_keep_msg(kmsg, keep_msg_hl_id);
    xfree(kmsg);
  }

  return ret;
}

/// Used for "confirm()" function, and the :confirm command prefix.
/// Versions which haven't got flexible dialogs yet, and console
/// versions, get this generic handler which uses the command line.
///
/// type  = one of:
///         VIM_QUESTION, VIM_INFO, VIM_WARNING, VIM_ERROR or VIM_GENERIC
/// title = title string (can be NULL for default)
/// (neither used in console dialogs at the moment)
///
/// Format of the "buttons" string:
/// "Button1Name\nButton2Name\nButton3Name"
/// The first button should normally be the default/accept
/// The second button should be the 'Cancel' button
/// Other buttons- use your imagination!
/// A '&' in a button name becomes a shortcut, so each '&' should be before a
/// different letter.
///
/// @param textfiel  IObuff for inputdialog(), NULL otherwise
/// @param ex_cmd  when true pressing : accepts default and starts Ex command
/// @returns 0 if cancelled, otherwise the nth button (1-indexed).
int do_dialog(int type, const char *title, const char *message, const char *buttons, int dfltbutton,
              const char *textfield, int ex_cmd)
{
  int retval = 0;
  int i;

  if (silent_mode) {  // No dialogs in silent mode ("ex -s")
    return dfltbutton;  // return default option
  }

  int save_msg_silent = msg_silent;
  int oldState = State;

  msg_silent = 0;  // If dialog prompts for input, user needs to see it! #8788

  // Since we wait for a keypress, don't make the
  // user press RETURN as well afterwards.
  no_wait_return++;
  char *hotkeys = msg_show_console_dialog(message, buttons, dfltbutton);

  while (true) {
    // Without a UI Nvim waits for input forever.
    if (!ui_active() && !input_available()) {
      retval = dfltbutton;
      break;
    }

    // Get a typed character directly from the user.
    int c = prompt_for_input(confirm_buttons, HLF_M, true, NULL);
    switch (c) {
    case CAR:                 // User accepts default option
    case NUL:
      retval = dfltbutton;
      break;
    case Ctrl_C:              // User aborts/cancels
    case ESC:
      retval = 0;
      break;
    default:                  // Could be a hotkey?
      if (c < 0) {            // special keys are ignored here
        msg_didout = msg_didany = false;
        continue;
      }
      if (c == ':' && ex_cmd) {
        retval = dfltbutton;
        ins_typebuf(":", REMAP_YES, 0, false, false);
        break;
      }

      // Make the character lowercase, as chars in "hotkeys" are.
      c = mb_tolower(c);
      retval = 1;
      for (i = 0; hotkeys[i]; i++) {
        if (utf_ptr2char(hotkeys + i) == c) {
          break;
        }
        i += utfc_ptr2len(hotkeys + i) - 1;
        retval++;
      }
      if (hotkeys[i]) {
        break;
      }
      // No hotkey match, so keep waiting
      msg_didout = msg_didany = false;
      continue;
    }
    break;
  }

  xfree(hotkeys);
  xfree(confirm_msg);
  confirm_msg = NULL;

  msg_silent = save_msg_silent;
  State = oldState;
  setmouse();
  no_wait_return--;
  msg_end_prompt();

  return retval;
}

/// Copy one character from "*from" to "*to", taking care of multi-byte
/// characters.  Return the length of the character in bytes.
///
/// @param lowercase  make character lower case
static int copy_char(const char *from, char *to, bool lowercase)
  FUNC_ATTR_NONNULL_ALL
{
  if (lowercase) {
    int c = mb_tolower(utf_ptr2char(from));
    return utf_char2bytes(c, to);
  }
  int len = utfc_ptr2len(from);
  memmove(to, from, (size_t)len);
  return len;
}

#define HAS_HOTKEY_LEN 30
#define HOTK_LEN MB_MAXBYTES

/// Allocates memory for dialog string & for storing hotkeys
///
/// Finds the size of memory required for the confirm_msg & for storing hotkeys
/// and then allocates the memory for them.
/// has_hotkey array is also filled-up.
///
/// @param message Message which will be part of the confirm_msg
/// @param buttons String containing button names
/// @param[out] has_hotkey An element in this array is set to true if
///                        corresponding button has a hotkey
///
/// @return Pointer to memory allocated for storing hotkeys
static char *console_dialog_alloc(const char *message, const char *buttons, bool has_hotkey[])
{
  int lenhotkey = HOTK_LEN;  // count first button
  has_hotkey[0] = false;

  // Compute the size of memory to allocate.
  int msg_len = 0;
  int button_len = 0;
  int idx = 0;
  const char *r = buttons;
  while (*r) {
    if (*r == DLG_BUTTON_SEP) {
      button_len += 3;                  // '\n' -> ', '; 'x' -> '(x)'
      lenhotkey += HOTK_LEN;            // each button needs a hotkey
      if (idx < HAS_HOTKEY_LEN - 1) {
        has_hotkey[++idx] = false;
      }
    } else if (*r == DLG_HOTKEY_CHAR) {
      r++;
      button_len++;                     // '&a' -> '[a]'
      if (idx < HAS_HOTKEY_LEN - 1) {
        has_hotkey[idx] = true;
      }
    }

    // Advance to the next character
    MB_PTR_ADV(r);
  }

  msg_len += (int)strlen(message) + 3;     // for the NL's and NUL
  button_len += (int)strlen(buttons) + 3;  // for the ": " and NUL
  lenhotkey++;                             // for the NUL

  // If no hotkey is specified, first char is used.
  if (!has_hotkey[0]) {
    button_len += 2;                       // "x" -> "[x]"
  }

  // Now allocate space for the strings
  confirm_msg = xmalloc((size_t)msg_len);
  snprintf(confirm_msg, (size_t)msg_len, ui_has(kUIMessages) ? "%s" : "\n%s\n", message);

  xfree(confirm_buttons);
  confirm_buttons = xmalloc((size_t)button_len);

  return xmalloc((size_t)lenhotkey);
}

/// Format the dialog string, and display it at the bottom of
/// the screen. Return a string of hotkey chars (if defined) for
/// each 'button'. If a button has no hotkey defined, the first character of
/// the button is used.
/// The hotkeys can be multi-byte characters, but without combining chars.
///
/// @return  an allocated string with hotkeys.
static char *msg_show_console_dialog(const char *message, const char *buttons, int dfltbutton)
  FUNC_ATTR_NONNULL_RET
{
  bool has_hotkey[HAS_HOTKEY_LEN] = { false };
  char *hotk = console_dialog_alloc(message, buttons, has_hotkey);

  copy_confirm_hotkeys(buttons, dfltbutton, has_hotkey, hotk);

  display_confirm_msg();
  return hotk;
}

/// Copies hotkeys into the memory allocated for it
///
/// @param buttons String containing button names
/// @param default_button_idx Number of default button
/// @param has_hotkey An element in this array is true if corresponding button
///                   has a hotkey
/// @param[out] hotkeys_ptr Pointer to the memory location where hotkeys will be copied
static void copy_confirm_hotkeys(const char *buttons, int default_button_idx,
                                 const bool has_hotkey[], char *hotkeys_ptr)
{
  // Define first default hotkey. Keep the hotkey string NUL
  // terminated to avoid reading past the end.
  hotkeys_ptr[copy_char(buttons, hotkeys_ptr, true)] = NUL;

  bool first_hotkey = false;  // Is the first char of button a hotkey
  if (!has_hotkey[0]) {
    first_hotkey = true;     // If no hotkey is specified, first char is used
  }

  // Remember where the choices start, sent as prompt to cmdline.
  char *msgp = confirm_buttons;

  int idx = 0;
  const char *r = buttons;
  while (*r) {
    if (*r == DLG_BUTTON_SEP) {
      *msgp++ = ',';
      *msgp++ = ' ';                    // '\n' -> ', '

      // Advance to next hotkey and set default hotkey
      hotkeys_ptr += strlen(hotkeys_ptr);
      hotkeys_ptr[copy_char(r + 1, hotkeys_ptr, true)] = NUL;

      if (default_button_idx) {
        default_button_idx--;
      }

      // If no hotkey is specified, first char is used.
      if (idx < HAS_HOTKEY_LEN - 1 && !has_hotkey[++idx]) {
        first_hotkey = true;
      }
    } else if (*r == DLG_HOTKEY_CHAR || first_hotkey) {
      if (*r == DLG_HOTKEY_CHAR) {
        r++;
      }

      first_hotkey = false;
      if (*r == DLG_HOTKEY_CHAR) {                 // '&&a' -> '&a'
        *msgp++ = *r;
      } else {
        // '&a' -> '[a]'
        *msgp++ = (default_button_idx == 1) ? '[' : '(';
        msgp += copy_char(r, msgp, false);
        *msgp++ = (default_button_idx == 1) ? ']' : ')';

        // redefine hotkey
        hotkeys_ptr[copy_char(r, hotkeys_ptr, true)] = NUL;
      }
    } else {
      // everything else copy literally
      msgp += copy_char(r, msgp, false);
    }

    // advance to the next character
    MB_PTR_ADV(r);
  }

  *msgp++ = ':';
  *msgp++ = ' ';
  *msgp = NUL;
}

int vim_dialog_yesno(int type, char *title, char *message, int dflt)
{
  if (do_dialog(type,
                title == NULL ? _("Question") : title,
                message,
                _("&Yes\n&No"), dflt, NULL, false) == 1) {
    return VIM_YES;
  }
  return VIM_NO;
}

int vim_dialog_yesnocancel(int type, char *title, char *message, int dflt)
{
  switch (do_dialog(type,
                    title == NULL ? _("Question") : title,
                    message,
                    _("&Yes\n&No\n&Cancel"), dflt, NULL, false)) {
  case 1:
    return VIM_YES;
  case 2:
    return VIM_NO;
  }
  return VIM_CANCEL;
}

int vim_dialog_yesnoallcancel(int type, char *title, char *message, int dflt)
{
  switch (do_dialog(type,
                    title == NULL ? "Question" : title,
                    message,
                    _("&Yes\n&No\nSave &All\n&Discard All\n&Cancel"),
                    dflt, NULL, false)) {
  case 1:
    return VIM_YES;
  case 2:
    return VIM_NO;
  case 3:
    return VIM_ALL;
  case 4:
    return VIM_DISCARDALL;
  }
  return VIM_CANCEL;
}
