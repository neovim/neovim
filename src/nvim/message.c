// message.c: functions for displaying messages on the command line

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <uv.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/channel.h"
#include "nvim/charset.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/event/defs.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/indent.h"
#include "nvim/input.h"
#include "nvim/keycodes.h"
#include "nvim/log.h"
#include "nvim/main.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"
#include "nvim/pos_defs.h"
#include "nvim/regexp.h"
#include "nvim/runtime.h"
#include "nvim/runtime_defs.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_compositor.h"
#include "nvim/ui_defs.h"
#include "nvim/vim_defs.h"

// To be able to scroll back at the "more" and "hit-enter" prompts we need to
// store the displayed text and remember where screen lines start.
typedef struct msgchunk_S msgchunk_T;
struct msgchunk_S {
  msgchunk_T *sb_next;
  msgchunk_T *sb_prev;
  char sb_eol;                  // true when line ends after this text
  int sb_msg_col;               // column in which text starts
  int sb_hl_id;                 // text highlight id
  char sb_text[];               // text to be displayed
};

// Magic chars used in confirm dialog strings
enum {
  DLG_BUTTON_SEP = '\n',
  DLG_HOTKEY_CHAR = '&',
};

static int confirm_msg_used = false;            // displaying confirm_msg
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "message.c.generated.h"
#endif
static char *confirm_msg = NULL;            // ":confirm" message
static char *confirm_buttons;               // ":confirm" buttons sent to cmdline as prompt

MessageHistoryEntry *msg_hist_last = NULL;          // Last message (extern for unittest)
static MessageHistoryEntry *msg_hist_first = NULL;  // First message
static MessageHistoryEntry *msg_hist_temp = NULL;   // First potentially temporary message
static int msg_hist_len = 0;
static int msg_hist_max = 500;  // The default max value is 500

// args in 'messagesopt' option
#define MESSAGES_OPT_HIT_ENTER "hit-enter"
#define MESSAGES_OPT_WAIT "wait:"
#define MESSAGES_OPT_HISTORY "history:"

// The default is "hit-enter,history:500"
static int msg_flags = kOptMoptFlagHitEnter | kOptMoptFlagHistory;
static int msg_wait = 0;

static FILE *verbose_fd = NULL;
static bool verbose_did_open = false;

bool keep_msg_more = false;    // keep_msg was set by msgmore()

// When writing messages to the screen, there are many different situations.
// A number of variables is used to remember the current state:
// msg_didany       true when messages were written since the last time the
//                  user reacted to a prompt.
//                  Reset: After hitting a key for the hit-return prompt,
//                  hitting <CR> for the command line or input().
//                  Set: When any message is written to the screen.
// msg_didout       true when something was written to the current line.
//                  Reset: When advancing to the next line, when the current
//                  text can be overwritten.
//                  Set: When any message is written to the screen.
// msg_nowait       No extra delay for the last drawn message.
//                  Used in normal_cmd() before the mode message is drawn.
// emsg_on_display  There was an error message recently.  Indicates that there
//                  should be a delay before redrawing.
// msg_scroll       The next message should not overwrite the current one.
// msg_scrolled     How many lines the screen has been scrolled (because of
//                  messages).  Used in update_screen() to scroll the screen
//                  back.  Incremented each time the screen scrolls a line.
// msg_scrolled_ign  true when msg_scrolled is non-zero and msg_puts_hl()
//                  writes something without scrolling should not make
//                  need_wait_return to be set.  This is a hack to make ":ts"
//                  work without an extra prompt.
// lines_left       Number of lines available for messages before the
//                  more-prompt is to be given.  -1 when not set.
// need_wait_return true when the hit-return prompt is needed.
//                  Reset: After giving the hit-return prompt, when the user
//                  has answered some other prompt.
//                  Set: When the ruler or typeahead display is overwritten,
//                  scrolling the screen for some message.
// keep_msg         Message to be displayed after redrawing the screen, in
//                  Normal mode main loop.
//                  This is an allocated string or NULL when not used.

// Extended msg state, currently used for external UIs with ext_messages
static const char *msg_ext_kind = NULL;
static Array *msg_ext_chunks = NULL;
static garray_T msg_ext_last_chunk = GA_INIT(sizeof(char), 40);
static sattr_T msg_ext_last_attr = -1;
static int msg_ext_last_hl_id;

static bool msg_ext_history = false;  ///< message was added to history

static int msg_grid_pos_at_flush = 0;

static void ui_ext_msg_set_pos(int row, bool scrolled)
{
  char buf[MAX_SCHAR_SIZE];
  size_t size = schar_get(buf, curwin->w_p_fcs_chars.msgsep);
  ui_call_msg_set_pos(msg_grid.handle, row, scrolled,
                      (String){ .data = buf, .size = size }, msg_grid.zindex,
                      (int)msg_grid.comp_index);
  msg_grid.pending_comp_index_update = false;
}

void msg_grid_set_pos(int row, bool scrolled)
{
  if (!msg_grid.throttled) {
    ui_ext_msg_set_pos(row, scrolled);
    msg_grid_pos_at_flush = row;
  }
  msg_grid_pos = row;
  if (msg_grid.chars) {
    msg_grid_adj.row_offset = -row;
  }
}

bool msg_use_grid(void)
{
  return default_grid.chars && !ui_has(kUIMessages);
}

void msg_grid_validate(void)
{
  grid_assign_handle(&msg_grid);
  bool should_alloc = msg_use_grid();
  int max_rows = Rows - (int)p_ch;
  if (should_alloc && (msg_grid.rows != Rows || msg_grid.cols != Columns
                       || !msg_grid.chars)) {
    // TODO(bfredl): eventually should be set to "invalid". I e all callers
    // will use the grid including clear to EOS if necessary.
    grid_alloc(&msg_grid, Rows, Columns, false, true);
    msg_grid.zindex = kZIndexMessages;

    xfree(msg_grid.dirty_col);
    msg_grid.dirty_col = xcalloc((size_t)Rows, sizeof(*msg_grid.dirty_col));

    // Tricky: allow resize while pager or ex mode is active
    int pos = (State & MODE_ASKMORE) ? 0 : MAX(max_rows - msg_scrolled, 0);
    msg_grid.throttled = false;  // don't throttle in 'cmdheight' area
    msg_grid_set_pos(pos, msg_scrolled);
    ui_comp_put_grid(&msg_grid, pos, 0, msg_grid.rows, msg_grid.cols,
                     false, true);
    ui_call_grid_resize(msg_grid.handle, msg_grid.cols, msg_grid.rows);

    msg_scrolled_at_flush = msg_scrolled;
    msg_grid.mouse_enabled = false;
    msg_grid_adj.target = &msg_grid;
  } else if (!should_alloc && msg_grid.chars) {
    ui_comp_remove_grid(&msg_grid);
    grid_free(&msg_grid);
    XFREE_CLEAR(msg_grid.dirty_col);
    ui_call_grid_destroy(msg_grid.handle);
    msg_grid.throttled = false;
    msg_grid_adj.row_offset = 0;
    msg_grid_adj.target = &default_grid;
    redraw_cmdline = true;
  } else if (msg_grid.chars && !msg_scrolled && msg_grid_pos != max_rows) {
    int diff = msg_grid_pos - max_rows;
    msg_grid_set_pos(max_rows, false);
    if (diff > 0) {
      grid_clear(&msg_grid_adj, Rows - diff, Rows, 0, Columns, HL_ATTR(HLF_MSG));
    }
  }

  if (msg_grid.chars && !msg_scrolled && cmdline_row < msg_grid_pos) {
    // TODO(bfredl): this should already be the case, but fails in some
    // "batched" executions where compute_cmdrow() use stale positions or
    // something.
    cmdline_row = msg_grid_pos;
  }
}

/// Like msg() but keep it silent when 'verbosefile' is set.
int verb_msg(const char *s)
{
  verbose_enter();
  int n = msg_keep(s, 0, false, false);
  verbose_leave();

  return n;
}

/// Displays the string 's' on the status line
/// When terminal not initialized (yet) printf("%s", ..) is used.
///
/// @return  true if wait_return() not called
bool msg(const char *s, const int hl_id)
  FUNC_ATTR_NONNULL_ARG(1)
{
  return msg_keep(s, hl_id, false, false);
}

/// Similar to msg_outtrans_len, but support newlines and tabs.
void msg_multiline(String str, int hl_id, bool check_int, bool hist, bool *need_clear)
  FUNC_ATTR_NONNULL_ALL
{
  const char *s = str.data;
  const char *chunk = s;
  while ((size_t)(s - str.data) < str.size) {
    if (check_int && got_int) {
      return;
    }
    if (*s == '\n' || *s == TAB || *s == '\r') {
      // Print all chars before the delimiter
      msg_outtrans_len(chunk, (int)(s - chunk), hl_id, hist);

      if (*s != TAB && *need_clear) {
        msg_clr_eos();
        *need_clear = false;
      }
      msg_putchar_hl((uint8_t)(*s), hl_id);
      chunk = s + 1;
    }
    s++;
  }

  // Print the rest of the message
  msg_outtrans_len(chunk, (int)(str.size - (size_t)(chunk - str.data)), hl_id, hist);
}

// Avoid starting a new message for each chunk and adding message to history in msg_keep().
static bool is_multihl = false;

/// Print message chunks, each with their own highlight ID.
///
/// @param hl_msg Message chunks
/// @param kind Message kind (can be NULL to avoid setting kind)
/// @param history Whether to add message to history
/// @param err Whether to print message as an error
void msg_multihl(HlMessage hl_msg, const char *kind, bool history, bool err)
{
  no_wait_return++;
  msg_start();
  msg_clr_eos();
  bool need_clear = false;
  msg_ext_history = history;
  if (kind != NULL) {
    msg_ext_set_kind(kind);
  }
  is_multihl = true;
  msg_ext_skip_flush = true;
  for (uint32_t i = 0; i < kv_size(hl_msg); i++) {
    HlMessageChunk chunk = kv_A(hl_msg, i);
    if (err) {
      emsg_multiline(chunk.text.data, kind, chunk.hl_id, true);
    } else {
      msg_multiline(chunk.text, chunk.hl_id, true, false, &need_clear);
    }
    assert(!ui_has(kUIMessages) || kind == NULL || msg_ext_kind == kind);
  }
  if (history && kv_size(hl_msg)) {
    msg_hist_add_multihl(hl_msg, false);
  }
  msg_ext_skip_flush = false;
  is_multihl = false;
  no_wait_return--;
  msg_end();
}

/// @param keep set keep_msg if it doesn't scroll
bool msg_keep(const char *s, int hl_id, bool keep, bool multiline)
  FUNC_ATTR_NONNULL_ALL
{
  static int entered = 0;

  if (keep && multiline) {
    // Not implemented. 'multiline' is only used by nvim-added messages,
    // which should avoid 'keep' behavior (just show the message at
    // the correct time already).
    abort();
  }

  // Skip messages not match ":filter pattern".
  // Don't filter when there is an error.
  if (!emsg_on_display && message_filtered(s)) {
    return true;
  }

  if (hl_id == 0) {
    set_vim_var_string(VV_STATUSMSG, s, -1);
  }

  // It is possible that displaying a messages causes a problem (e.g.,
  // when redrawing the window), which causes another message, etc..    To
  // break this loop, limit the recursiveness to 3 levels.
  if (entered >= 3) {
    return true;
  }
  entered++;

  // Add message to history unless it's a multihl, repeated kept or truncated message.
  if (!is_multihl
      && (s != keep_msg
          || (*s != '<' && msg_hist_last != NULL
              && strcmp(s, msg_hist_last->msg.items[0].text.data) != 0))) {
    msg_hist_add(s, -1, hl_id);
  }

  if (!is_multihl) {
    msg_start();
  }
  // Truncate the message if needed.
  char *buf = msg_strtrunc(s, false);
  if (buf != NULL) {
    s = buf;
  }

  bool need_clear = true;
  if (multiline) {
    msg_multiline(cstr_as_string(s), hl_id, false, false, &need_clear);
  } else {
    msg_outtrans(s, hl_id, false);
  }
  if (need_clear) {
    msg_clr_eos();
  }
  bool retval = true;
  if (!is_multihl) {
    retval = msg_end();
  }

  if (keep && retval && vim_strsize(s) < (Rows - cmdline_row - 1) * Columns + sc_col) {
    set_keep_msg(s, 0);
  }

  need_fileinfo = false;

  xfree(buf);
  entered--;
  return retval;
}

/// Truncate a string such that it can be printed without causing a scroll.
///
/// @return  an allocated string or NULL when no truncating is done.
///
/// @param force  always truncate
char *msg_strtrunc(const char *s, int force)
{
  char *buf = NULL;

  // May truncate message to avoid a hit-return prompt
  if ((!msg_scroll && !need_wait_return && shortmess(SHM_TRUNCALL)
       && !exmode_active && msg_silent == 0 && !ui_has(kUIMessages))
      || force) {
    int room;
    int len = vim_strsize(s);
    if (msg_scrolled != 0) {
      // Use all the columns.
      room = (Rows - msg_row) * Columns - 1;
    } else {
      // Use up to 'showcmd' column.
      room = (Rows - msg_row - 1) * Columns + sc_col - 1;
    }
    if (len > room && room > 0) {
      // may have up to 18 bytes per cell (6 per char, up to two
      // composing chars)
      len = (room + 2) * 18;
      buf = xmalloc((size_t)len);
      trunc_string(s, buf, room, len);
    }
  }
  return buf;
}

/// Truncate a string "s" to "buf" with cell width "room".
/// "s" and "buf" may be equal.
void trunc_string(const char *s, char *buf, int room_in, int buflen)
{
  int room = room_in - 3;  // "..." takes 3 chars
  int len = 0;
  int e;
  int i;
  int n;

  if (*s == NUL) {
    if (buflen > 0) {
      *buf = NUL;
    }
    return;
  }

  if (room_in < 3) {
    room = 0;
  }
  int half = room / 2;

  // First part: Start of the string.
  for (e = 0; len < half && e < buflen; e++) {
    if (s[e] == NUL) {
      // text fits without truncating!
      buf[e] = NUL;
      return;
    }
    n = ptr2cells(s + e);
    if (len + n > half) {
      break;
    }
    len += n;
    buf[e] = s[e];
    for (n = utfc_ptr2len(s + e); --n > 0;) {
      if (++e == buflen) {
        break;
      }
      buf[e] = s[e];
    }
  }

  // Last part: End of the string.
  half = i = (int)strlen(s);
  while (true) {
    half = half - utf_head_off(s, s + half - 1) - 1;
    n = ptr2cells(s + half);
    if (len + n > room || half == 0) {
      break;
    }
    len += n;
    i = half;
  }

  if (i <= e + 3) {
    // text fits without truncating
    if (s != buf) {
      len = (int)strlen(s);
      if (len >= buflen) {
        len = buflen - 1;
      }
      len = len - e + 1;
      if (len < 1) {
        buf[e - 1] = NUL;
      } else {
        memmove(buf + e, s + e, (size_t)len);
      }
    }
  } else if (e + 3 < buflen) {
    // set the middle and copy the last part
    memmove(buf + e, "...", 3);
    len = (int)strlen(s + i) + 1;
    if (len >= buflen - e - 3) {
      len = buflen - e - 3 - 1;
    }
    memmove(buf + e + 3, s + i, (size_t)len);
    buf[e + 3 + len - 1] = NUL;
  } else {
    // can't fit in the "...", just truncate it
    buf[buflen - 1] = NUL;
  }
}

/// Shows a printf-style message with highlight id.
///
/// Note: Caller must check the resulting string is shorter than IOSIZE!!!
///
/// @see semsg
/// @see swmsg
///
/// @param s printf-style format message
int smsg(int hl_id, const char *s, ...)
  FUNC_ATTR_PRINTF(2, 3)
{
  va_list arglist;

  va_start(arglist, s);
  vim_vsnprintf(IObuff, IOSIZE, s, arglist);
  va_end(arglist);
  return msg(IObuff, hl_id);
}

int smsg_keep(int hl_id, const char *s, ...)
  FUNC_ATTR_PRINTF(2, 3)
{
  va_list arglist;

  va_start(arglist, s);
  vim_vsnprintf(IObuff, IOSIZE, s, arglist);
  va_end(arglist);
  return msg_keep(IObuff, hl_id, true, false);
}

// Remember the last sourcing name/lnum used in an error message, so that it
// isn't printed each time when it didn't change.
static int last_sourcing_lnum = 0;
static char *last_sourcing_name = NULL;

/// Reset the last used sourcing name/lnum.  Makes sure it is displayed again
/// for the next error message;
void reset_last_sourcing(void)
{
  XFREE_CLEAR(last_sourcing_name);
  last_sourcing_lnum = 0;
}

/// @return  true if "SOURCING_NAME" differs from "last_sourcing_name".
static bool other_sourcing_name(void)
{
  if (SOURCING_NAME != NULL) {
    if (last_sourcing_name != NULL) {
      return strcmp(SOURCING_NAME, last_sourcing_name) != 0;
    }
    return true;
  }
  return false;
}

/// Get the message about the source, as used for an error message
///
/// @return [allocated] String with room for one more character. NULL when no
///                     message is to be given.
static char *get_emsg_source(void)
  FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (SOURCING_NAME != NULL && other_sourcing_name()) {
    char *sname = estack_sfile(ESTACK_NONE);
    char *tofree = sname;

    if (sname == NULL) {
      sname = SOURCING_NAME;
    }

    const char *const p = _("Error in %s:");
    const size_t buf_len = strlen(sname) + strlen(p) + 1;
    char *const buf = xmalloc(buf_len);
    snprintf(buf, buf_len, p, sname);
    xfree(tofree);
    return buf;
  }
  return NULL;
}

/// Get the message about the source lnum, as used for an error message.
///
/// @return [allocated] String with room for one more character. NULL when no
///                     message is to be given.
static char *get_emsg_lnum(void)
  FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT
{
  // lnum is 0 when executing a command from the command line
  // argument, we don't want a line number then
  if (SOURCING_NAME != NULL
      && (other_sourcing_name() || SOURCING_LNUM != last_sourcing_lnum)
      && SOURCING_LNUM != 0) {
    const char *const p = _("line %4" PRIdLINENR ":");
    const size_t buf_len = 20 + strlen(p);
    char *const buf = xmalloc(buf_len);
    snprintf(buf, buf_len, p, SOURCING_LNUM);
    return buf;
  }
  return NULL;
}

/// Display name and line number for the source of an error.
/// Remember the file name and line number, so that for the next error the info
/// is only displayed if it changed.
void msg_source(int hl_id)
{
  static bool recursive = false;

  // Bail out if something called here causes an error.
  if (recursive) {
    return;
  }
  recursive = true;

  no_wait_return++;
  char *p = get_emsg_source();
  if (p != NULL) {
    msg_scroll = true;  // this will take more than one line
    msg(p, hl_id);
    xfree(p);
  }
  p = get_emsg_lnum();
  if (p != NULL) {
    msg(p, HLF_N);
    xfree(p);
    last_sourcing_lnum = SOURCING_LNUM;      // only once for each line
  }

  // remember the last sourcing name printed, also when it's empty
  if (SOURCING_NAME == NULL || other_sourcing_name()) {
    XFREE_CLEAR(last_sourcing_name);
    if (SOURCING_NAME != NULL) {
      last_sourcing_name = xstrdup(SOURCING_NAME);
      if (!redirecting()) {
        msg_putchar_hl('\n', hl_id);
      }
    }
  }
  no_wait_return--;

  recursive = false;
}

/// @return  true if not giving error messages right now:
///            If "emsg_off" is set: no error messages at the moment.
///            If "msg" is in 'debug': do error message but without side effects.
///            If "emsg_skip" is set: never do error messages.
int emsg_not_now(void)
{
  if ((emsg_off > 0 && vim_strchr(p_debug, 'm') == NULL
       && vim_strchr(p_debug, 't') == NULL)
      || emsg_skip > 0) {
    return true;
  }
  return false;
}

bool emsg_multiline(const char *s, const char *kind, int hl_id, bool multiline)
{
  bool ignore = false;

  // Skip this if not giving error messages at the moment.
  if (emsg_not_now()) {
    return true;
  }

  called_emsg++;

  // If "emsg_severe" is true: When an error exception is to be thrown,
  // prefer this message over previous messages for the same command.
  bool severe = emsg_severe;
  emsg_severe = false;

  if (!emsg_off || vim_strchr(p_debug, 't') != NULL) {
    // Cause a throw of an error exception if appropriate.  Don't display
    // the error message in this case.  (If no matching catch clause will
    // be found, the message will be displayed later on.)  "ignore" is set
    // when the message should be ignored completely (used for the
    // interrupt message).
    if (cause_errthrow(s, multiline, severe, &ignore)) {
      if (!ignore) {
        did_emsg++;
      }
      return true;
    }

    if (in_assert_fails && emsg_assert_fails_msg == NULL) {
      emsg_assert_fails_msg = xstrdup(s);
      emsg_assert_fails_lnum = SOURCING_LNUM;
      xfree(emsg_assert_fails_context);
      emsg_assert_fails_context = xstrdup(SOURCING_NAME == NULL ? "" : SOURCING_NAME);
    }

    // set "v:errmsg", also when using ":silent! cmd"
    set_vim_var_string(VV_ERRMSG, s, -1);

    // When using ":silent! cmd" ignore error messages.
    // But do write it to the redirection file.
    if (emsg_silent != 0) {
      if (!emsg_noredir) {
        msg_start();
        char *p = get_emsg_source();
        if (p != NULL) {
          const size_t p_len = strlen(p);
          p[p_len] = '\n';
          redir_write(p, (ptrdiff_t)p_len + 1);
          xfree(p);
        }
        p = get_emsg_lnum();
        if (p != NULL) {
          const size_t p_len = strlen(p);
          p[p_len] = '\n';
          redir_write(p, (ptrdiff_t)p_len + 1);
          xfree(p);
        }
        redir_write(s, (ptrdiff_t)strlen(s));
      }

      // Log (silent) errors as debug messages.
      if (SOURCING_NAME != NULL && SOURCING_LNUM != 0) {
        DLOG("(:silent) %s (%s (line %" PRIdLINENR "))",
             s, SOURCING_NAME, SOURCING_LNUM);
      } else {
        DLOG("(:silent) %s", s);
      }

      return true;
    }

    // Log editor errors as INFO.
    if (SOURCING_NAME != NULL && SOURCING_LNUM != 0) {
      ILOG("%s (%s (line %" PRIdLINENR "))", s, SOURCING_NAME, SOURCING_LNUM);
    } else {
      ILOG("%s", s);
    }

    ex_exitval = 1;

    // Reset msg_silent, an error causes messages to be switched back on.
    msg_silent = 0;
    cmd_silent = false;

    if (global_busy) {        // break :global command
      global_busy++;
    }

    if (p_eb) {
      beep_flush();           // also includes flush_buffers()
    } else {
      flush_buffers(FLUSH_MINIMAL);  // flush internal buffers
    }
    did_emsg++;               // flag for DoOneCmd()
  }

  emsg_on_display = true;     // remember there is an error message
  if (msg_scrolled != 0) {
    need_wait_return = true;  // needed in case emsg() is called after
  }                           // wait_return() has reset need_wait_return
                              // and a redraw is expected because
                              // msg_scrolled is non-zero
  msg_ext_set_kind(kind);

  // Display name and line number for the source of the error.
  msg_scroll = true;
  bool save_msg_skip_flush = msg_ext_skip_flush;
  msg_ext_skip_flush = true;
  msg_source(hl_id);

  // Display the error message itself.
  msg_nowait = false;  // Wait for this msg.
  int rv = msg_keep(s, hl_id, false, multiline);
  msg_ext_skip_flush = save_msg_skip_flush;
  return rv;
}

/// emsg() - display an error message
///
/// Rings the bell, if appropriate, and calls message() to do the real work
/// When terminal not initialized (yet) fprintf(stderr, "%s", ..) is used.
///
/// @return true if wait_return() not called
bool emsg(const char *s)
{
  return emsg_multiline(s, "emsg", HLF_E, false);
}

void emsg_invreg(int name)
{
  semsg(_("E354: Invalid register name: '%s'"), transchar_buf(NULL, name));
}

/// Print an error message with unknown number of arguments
///
/// @return whether the message was displayed
bool semsg(const char *const fmt, ...)
  FUNC_ATTR_PRINTF(1, 2)
{
  bool ret;

  va_list ap;
  va_start(ap, fmt);
  ret = semsgv(fmt, ap);
  va_end(ap);

  return ret;
}

#define MULTILINE_BUFSIZE 8192

bool semsg_multiline(const char *kind, const char *const fmt, ...)
{
  bool ret;
  va_list ap;

  static char errbuf[MULTILINE_BUFSIZE];
  if (emsg_not_now()) {
    return true;
  }

  va_start(ap, fmt);
  vim_vsnprintf(errbuf, sizeof(errbuf), fmt, ap);
  va_end(ap);

  ret = emsg_multiline(errbuf, kind, HLF_E, true);

  return ret;
}

/// Print an error message with unknown number of arguments
static bool semsgv(const char *fmt, va_list ap)
{
  static char errbuf[IOSIZE];
  if (emsg_not_now()) {
    return true;
  }

  vim_vsnprintf(errbuf, sizeof(errbuf), fmt, ap);

  return emsg(errbuf);
}

/// Same as emsg(...), but abort on error when ABORT_ON_INTERNAL_ERROR is
/// defined. It is used for internal errors only, so that they can be
/// detected when fuzzing vim.
void iemsg(const char *s)
{
  if (emsg_not_now()) {
    return;
  }

  emsg(s);
#ifdef ABORT_ON_INTERNAL_ERROR
  set_vim_var_string(VV_ERRMSG, s, -1);
  msg_putchar('\n');  // avoid overwriting the error message
  ui_flush();
  abort();
#endif
}

/// Same as semsg(...) but abort on error when ABORT_ON_INTERNAL_ERROR is
/// defined. It is used for internal errors only, so that they can be
/// detected when fuzzing vim.
void siemsg(const char *s, ...)
{
  if (emsg_not_now()) {
    return;
  }

  va_list ap;
  va_start(ap, s);
  semsgv(s, ap);
  va_end(ap);
#ifdef ABORT_ON_INTERNAL_ERROR
  msg_putchar('\n');  // avoid overwriting the error message
  ui_flush();
  abort();
#endif
}

/// Give an "Internal error" message.
void internal_error(const char *where)
{
  siemsg(_(e_intern2), where);
}

static void msg_semsg_event(void **argv)
{
  char *s = argv[0];
  emsg(s);
  xfree(s);
}

void msg_schedule_semsg(const char *const fmt, ...)
  FUNC_ATTR_PRINTF(1, 2)
{
  va_list ap;
  va_start(ap, fmt);
  vim_vsnprintf(IObuff, IOSIZE, fmt, ap);
  va_end(ap);

  char *s = xstrdup(IObuff);
  loop_schedule_deferred(&main_loop, event_create(msg_semsg_event, s));
}

static void msg_semsg_multiline_event(void **argv)
{
  char *s = argv[0];
  emsg_multiline(s, "emsg", HLF_E, true);
  xfree(s);
}

void msg_schedule_semsg_multiline(const char *const fmt, ...)
{
  va_list ap;
  va_start(ap, fmt);
  vim_vsnprintf(IObuff, IOSIZE, fmt, ap);
  va_end(ap);

  char *s = xstrdup(IObuff);
  loop_schedule_deferred(&main_loop, event_create(msg_semsg_multiline_event, s));
}

/// Like msg(), but truncate to a single line if p_shm contains 't', or when
/// "force" is true.  This truncates in another way as for normal messages.
/// Careful: The string may be changed by msg_may_trunc()!
///
/// @return  a pointer to the printed message, if wait_return() not called.
char *msg_trunc(char *s, bool force, int hl_id)
{
  // Add message to history before truncating.
  msg_hist_add(s, -1, hl_id);

  char *ts = msg_may_trunc(force, s);

  msg_hist_off = true;
  bool n = msg(ts, hl_id);
  msg_hist_off = false;

  if (n) {
    return ts;
  }
  return NULL;
}

/// Check if message "s" should be truncated at the start (for filenames).
///
/// @return  a pointer to where the truncated message starts.
///
/// @note: May change the message by replacing a character with '<'.
char *msg_may_trunc(bool force, char *s)
{
  if (ui_has(kUIMessages)) {
    return s;
  }

  int room = (Rows - cmdline_row - 1) * Columns + sc_col - 1;
  if ((force || (shortmess(SHM_TRUNC) && !exmode_active))
      && (int)strlen(s) - room > 0) {
    int size = vim_strsize(s);

    // There may be room anyway when there are multibyte chars.
    if (size <= room) {
      return s;
    }
    int n;
    for (n = 0; size >= room;) {
      size -= utf_ptr2cells(s + n);
      n += utfc_ptr2len(s + n);
    }
    n--;
    s += n;
    *s = '<';
  }
  return s;
}

void hl_msg_free(HlMessage hl_msg)
{
  for (size_t i = 0; i < kv_size(hl_msg); i++) {
    xfree(kv_A(hl_msg, i).text.data);
  }
  kv_destroy(hl_msg);
}

/// Add the message at the end of the history
///
/// @param[in]  len  Length of s or -1.
static void msg_hist_add(const char *s, int len, int hl_id)
{
  String text = { .size = len < 0 ? strlen(s) : (size_t)len };
  // Remove leading and trailing newlines.
  while (text.size > 0 && *s == '\n') {
    text.size--;
    s++;
  }
  while (text.size > 0 && s[text.size - 1] == '\n') {
    text.size--;
  }
  if (text.size == 0) {
    return;
  }
  text.data = xmemdupz(s, text.size);

  HlMessage msg = KV_INITIAL_VALUE;
  kv_push(msg, ((HlMessageChunk){ text, hl_id }));
  msg_hist_add_multihl(msg, false);
}

static bool do_clear_hist_temp = true;

static void msg_hist_add_multihl(HlMessage msg, bool temp)
{
  if (do_clear_hist_temp) {
    msg_hist_clear_temp();
    do_clear_hist_temp = false;
  }

  if (msg_hist_off || msg_silent != 0) {
    hl_msg_free(msg);
    return;
  }

  // Allocate an entry and add the message at the end of the history.
  MessageHistoryEntry *entry = xmalloc(sizeof(MessageHistoryEntry));
  entry->msg = msg;
  entry->temp = temp;
  entry->kind = msg_ext_kind;
  entry->prev = msg_hist_last;
  entry->next = NULL;
  // NOTE: this does not encode if the message was actually appended to the
  // previous entry in the message history. However append is currently only
  // true for :echon, which is stored in the history as a temporary entry for
  // "g<" where it is guaranteed to be after the entry it was appended to.
  entry->append = msg_ext_append;

  if (msg_hist_first == NULL) {
    msg_hist_first = entry;
  }
  if (msg_hist_last != NULL) {
    msg_hist_last->next = entry;
  }
  if (msg_hist_temp == NULL) {
    msg_hist_temp = entry;
  }

  msg_hist_len += !temp;
  msg_hist_last = entry;
  msg_ext_history = true;
  msg_hist_clear(msg_hist_max);
}

static void msg_hist_free_msg(MessageHistoryEntry *entry)
{
  if (entry->next == NULL) {
    msg_hist_last = entry->prev;
  } else {
    entry->next->prev = entry->prev;
  }
  if (entry->prev == NULL) {
    msg_hist_first = entry->next;
  } else {
    entry->prev->next = entry->next;
  }
  if (entry == msg_hist_temp) {
    msg_hist_temp = entry->next;
  }
  hl_msg_free(entry->msg);
  xfree(entry);
}

/// Delete oldest messages from the history until there are "keep" messages.
void msg_hist_clear(int keep)
{
  while (msg_hist_len > keep || (keep == 0 && msg_hist_first != NULL)) {
    msg_hist_len -= !msg_hist_first->temp;
    msg_hist_free_msg(msg_hist_first);
  }
}

void msg_hist_clear_temp(void)
{
  while (msg_hist_temp != NULL) {
    MessageHistoryEntry *next = msg_hist_temp->next;
    if (msg_hist_temp->temp) {
      msg_hist_free_msg(msg_hist_temp);
    }
    msg_hist_temp = next;
  }
}

int messagesopt_changed(void)
{
  int messages_flags_new = 0;
  int messages_wait_new = 0;
  int messages_history_new = 0;

  char *p = p_mopt;
  while (*p != NUL) {
    if (strnequal(p, S_LEN(MESSAGES_OPT_HIT_ENTER))) {
      p += STRLEN_LITERAL(MESSAGES_OPT_HIT_ENTER);
      messages_flags_new |= kOptMoptFlagHitEnter;
    } else if (strnequal(p, S_LEN(MESSAGES_OPT_WAIT))
               && ascii_isdigit(p[STRLEN_LITERAL(MESSAGES_OPT_WAIT)])) {
      p += STRLEN_LITERAL(MESSAGES_OPT_WAIT);
      messages_wait_new = getdigits_int(&p, false, INT_MAX);
      messages_flags_new |= kOptMoptFlagWait;
    } else if (strnequal(p, S_LEN(MESSAGES_OPT_HISTORY))
               && ascii_isdigit(p[STRLEN_LITERAL(MESSAGES_OPT_HISTORY)])) {
      p += STRLEN_LITERAL(MESSAGES_OPT_HISTORY);
      messages_history_new = getdigits_int(&p, false, INT_MAX);
      messages_flags_new |= kOptMoptFlagHistory;
    }

    if (*p != ',' && *p != NUL) {
      return FAIL;
    }
    if (*p == ',') {
      p++;
    }
  }

  // Either "wait" or "hit-enter" is required
  if (!(messages_flags_new & (kOptMoptFlagHitEnter | kOptMoptFlagWait))) {
    return FAIL;
  }

  // "history" must be set
  if (!(messages_flags_new & kOptMoptFlagHistory)) {
    return FAIL;
  }

  assert(messages_history_new >= 0);
  // "history" must be <= 10000
  if (messages_history_new > 10000) {
    return FAIL;
  }

  assert(messages_wait_new >= 0);
  // "wait" must be <= 10000
  if (messages_wait_new > 10000) {
    return FAIL;
  }

  msg_flags = messages_flags_new;
  msg_wait = messages_wait_new;

  msg_hist_max = messages_history_new;
  msg_hist_clear(msg_hist_max);

  return OK;
}

/// :messages command implementation
void ex_messages(exarg_T *eap)
  FUNC_ATTR_NONNULL_ALL
{
  if (strcmp(eap->arg, "clear") == 0) {
    msg_hist_clear(eap->addr_count ? eap->line2 : 0);
    return;
  }

  if (*eap->arg != NUL) {
    emsg(_(e_invarg));
    return;
  }

  Array entries = ARRAY_DICT_INIT;
  MessageHistoryEntry *p = eap->skip ? msg_hist_temp : msg_hist_first;
  int skip = eap->addr_count ? (msg_hist_len - eap->line2) : 0;
  for (; p != NULL; p = p->next) {
    // Skip over count or temporary "g<" messages.
    if ((p->temp && !eap->skip) || skip-- > 0) {
      continue;
    }
    if (ui_has(kUIMessages) && !msg_silent) {
      Array entry = ARRAY_DICT_INIT;
      ADD(entry, CSTR_TO_OBJ(p->kind));
      Array content = ARRAY_DICT_INIT;
      for (uint32_t i = 0; i < kv_size(p->msg); i++) {
        HlMessageChunk chunk = kv_A(p->msg, i);
        Array content_entry = ARRAY_DICT_INIT;
        ADD(content_entry, INTEGER_OBJ(chunk.hl_id ? syn_id2attr(chunk.hl_id) : 0));
        ADD(content_entry, STRING_OBJ(copy_string(chunk.text, NULL)));
        ADD(content_entry, INTEGER_OBJ(chunk.hl_id));
        ADD(content, ARRAY_OBJ(content_entry));
      }
      ADD(entry, ARRAY_OBJ(content));
      ADD(entry, BOOLEAN_OBJ(p->append));
      ADD(entries, ARRAY_OBJ(entry));
    }
    if (redirecting() || !ui_has(kUIMessages)) {
      msg_silent += ui_has(kUIMessages);
      msg_multihl(p->msg, p->kind, false, false);
      msg_silent -= ui_has(kUIMessages);
    }
  }
  if (kv_size(entries) > 0) {
    ui_call_msg_history_show(entries, eap->skip != 0);
    api_free_array(entries);
  }
}

/// Call this after prompting the user.  This will avoid a hit-return message
/// and a delay.
void msg_end_prompt(void)
{
  need_wait_return = false;
  emsg_on_display = false;
  cmdline_row = msg_row;
  msg_col = 0;
  msg_clr_eos();
  lines_left = -1;
}

/// Wait for the user to hit a key (normally Enter)
///
/// @param redraw  if true, redraw the entire screen UPD_NOT_VALID
///                if false, do a normal redraw
///                if -1, don't redraw at all
void wait_return(int redraw)
{
  int c;
  int had_got_int;
  FILE *save_scriptout;

  if (redraw == true) {
    redraw_all_later(UPD_NOT_VALID);
  }

  if (ui_has(kUIMessages)) {
    prompt_for_input("Press any key to continue", HLF_M, true, NULL);
    return;
  }

  // If using ":silent cmd", don't wait for a return.  Also don't set
  // need_wait_return to do it later.
  if (msg_silent != 0) {
    return;
  }

  if (headless_mode && !ui_active()) {
    return;
  }

  // When inside vgetc(), we can't wait for a typed character at all.
  // With the global command (and some others) we only need one return at
  // the end. Adjust cmdline_row to avoid the next message overwriting the
  // last one.
  if (vgetc_busy > 0) {
    return;
  }
  need_wait_return = true;
  if (no_wait_return) {
    if (!exmode_active) {
      cmdline_row = msg_row;
    }
    return;
  }

  redir_off = true;             // don't redirect this message
  int oldState = State;
  if (quit_more) {
    c = CAR;                    // just pretend CR was hit
    quit_more = false;
    got_int = false;
  } else if (exmode_active) {
    msg_puts(" ");              // make sure the cursor is on the right line
    c = CAR;                    // no need for a return in ex mode
    got_int = false;
  } else {
    State = MODE_HITRETURN;
    setmouse();
    cmdline_row = msg_row;
    // Avoid the sequence that the user types ":" at the hit-return prompt
    // to start an Ex command, but the file-changed dialog gets in the
    // way.
    if (need_check_timestamps) {
      check_timestamps(false);
    }

    // if cmdheight=0, we need to scroll in the first line of msg_grid upon the screen
    if (p_ch == 0 && !ui_has(kUIMessages) && !msg_scrolled) {
      msg_grid_validate();
      msg_scroll_up(false, true);
      msg_scrolled++;
      cmdline_row = Rows - 1;
    }

    if (msg_flags & kOptMoptFlagHitEnter) {
      hit_return_msg(true);

      do {
        // Remember "got_int", if it is set vgetc() probably returns a
        // CTRL-C, but we need to loop then.
        had_got_int = got_int;

        // Don't do mappings here, we put the character back in the
        // typeahead buffer.
        no_mapping++;
        allow_keys++;

        // Temporarily disable Recording. If Recording is active, the
        // character will be recorded later, since it will be added to the
        // typebuf after the loop
        const int save_reg_recording = reg_recording;
        save_scriptout = scriptout;
        reg_recording = 0;
        scriptout = NULL;
        c = safe_vgetc();
        if (had_got_int && !global_busy) {
          got_int = false;
        }
        no_mapping--;
        allow_keys--;
        reg_recording = save_reg_recording;
        scriptout = save_scriptout;

        // Allow scrolling back in the messages.
        // Also accept scroll-down commands when messages fill the screen,
        // to avoid that typing one 'j' too many makes the messages
        // disappear.
        if (p_more) {
          if (c == 'b' || c == 'k' || c == 'u' || c == 'g'
              || c == K_UP || c == K_PAGEUP) {
            if (msg_scrolled > Rows) {
              // scroll back to show older messages
              do_more_prompt(c);
            } else {
              msg_didout = false;
              c = K_IGNORE;
              msg_col = 0;
            }
            if (quit_more) {
              c = CAR;  // just pretend CR was hit
              quit_more = false;
              got_int = false;
            } else if (c != K_IGNORE) {
              c = K_IGNORE;
              hit_return_msg(false);
            }
          } else if (msg_scrolled > Rows - 2
                     && (c == 'j' || c == 'd' || c == 'f'
                         || c == K_DOWN || c == K_PAGEDOWN)) {
            c = K_IGNORE;
          }
        }
      } while ((had_got_int && c == Ctrl_C)
               || c == K_IGNORE
               || c == K_LEFTDRAG || c == K_LEFTRELEASE
               || c == K_MIDDLEDRAG || c == K_MIDDLERELEASE
               || c == K_RIGHTDRAG || c == K_RIGHTRELEASE
               || c == K_MOUSELEFT || c == K_MOUSERIGHT
               || c == K_MOUSEDOWN || c == K_MOUSEUP
               || c == K_MOUSEMOVE);
      os_breakcheck();

      // Avoid that the mouse-up event causes visual mode to start.
      if (c == K_LEFTMOUSE || c == K_MIDDLEMOUSE || c == K_RIGHTMOUSE
          || c == K_X1MOUSE || c == K_X2MOUSE) {
        jump_to_mouse(MOUSE_SETPOS, NULL, 0);
      } else if (vim_strchr("\r\n ", c) == NULL && c != Ctrl_C) {
        // Put the character back in the typeahead buffer.  Don't use the
        // stuff buffer, because lmaps wouldn't work.
        ins_char_typebuf(vgetc_char, vgetc_mod_mask, true);
        do_redraw = true;  // need a redraw even though there is typeahead
      }
    } else {
      c = CAR;
      // Wait to allow the user to verify the output.
      do_sleep(msg_wait, true);
    }
  }
  redir_off = false;

  // If the user hits ':', '?' or '/' we get a command line from the next
  // line.
  if (c == ':' || c == '?' || c == '/') {
    if (!exmode_active) {
      cmdline_row = msg_row;
    }
    skip_redraw = true;  // skip redraw once
    do_redraw = false;
  }

  // If the screen size changed screen_resize() will redraw the screen.
  // Otherwise the screen is only redrawn if 'redraw' is set and no ':'
  // typed.
  int tmpState = State;
  State = oldState;  // restore State before screen_resize()
  setmouse();
  msg_check();
  need_wait_return = false;
  did_wait_return = true;
  emsg_on_display = false;      // can delete error message now
  lines_left = -1;              // reset lines_left at next msg_start()
  reset_last_sourcing();
  if (keep_msg != NULL && vim_strsize(keep_msg) >=
      (Rows - cmdline_row - 1) * Columns + sc_col) {
    XFREE_CLEAR(keep_msg);          // don't redisplay message, it's too long
  }

  if (tmpState == MODE_SETWSIZE) {       // got resize event while in vgetc()
    ui_refresh();
  } else if (!skip_redraw) {
    if (redraw == true || (msg_scrolled != 0 && redraw != -1)) {
      redraw_later(curwin, UPD_VALID);
    }
  }
}

/// Write the hit-return prompt.
///
/// @param newline_sb  if starting a new line, add it to the scrollback.
static void hit_return_msg(bool newline_sb)
{
  int save_p_more = p_more;

  if (!newline_sb) {
    p_more = false;
  }
  if (msg_didout) {     // start on a new line
    msg_putchar('\n');
  }
  p_more = false;       // don't want to see this message when scrolling back
  if (got_int) {
    msg_puts(_("Interrupt: "));
  }

  msg_puts_hl(_("Press ENTER or type command to continue"), HLF_R, false);
  if (!msg_use_printf()) {
    msg_clr_eos();
  }
  p_more = save_p_more;
}

/// Set "keep_msg" to "s".  Free the old value and check for NULL pointer.
void set_keep_msg(const char *s, int hl_id)
{
  // Kept message is not cleared and re-emitted with ext_messages: #20416.
  if (ui_has(kUIMessages)) {
    return;
  }

  xfree(keep_msg);
  if (s != NULL && msg_silent == 0) {
    keep_msg = xstrdup(s);
  } else {
    keep_msg = NULL;
  }
  keep_msg_more = false;
  keep_msg_hl_id = hl_id;
}

/// Return true if printing messages should currently be done.
bool messaging(void)
{
  // TODO(bfredl): with general support for "async" messages with p_ch,
  // this should be re-enabled.
  return !(p_lz && char_avail() && !KeyTyped) && (p_ch > 0 || ui_has(kUIMessages));
}

void msgmore(int n)
{
  int pn;

  if (global_busy           // no messages now, wait until global is finished
      || !messaging()) {      // 'lazyredraw' set, don't do messages now
    return;
  }

  // We don't want to overwrite another important message, but do overwrite
  // a previous "more lines" or "fewer lines" message, so that "5dd" and
  // then "put" reports the last action.
  if (keep_msg != NULL && !keep_msg_more) {
    return;
  }

  pn = abs(n);

  if (pn > p_report) {
    if (n > 0) {
      vim_snprintf(msg_buf, MSG_BUF_LEN,
                   NGETTEXT("%d more line", "%d more lines", pn),
                   pn);
    } else {
      vim_snprintf(msg_buf, MSG_BUF_LEN,
                   NGETTEXT("%d line less", "%d fewer lines", pn),
                   pn);
    }
    if (got_int) {
      xstrlcat(msg_buf, _(" (Interrupted)"), MSG_BUF_LEN);
    }
    if (msg(msg_buf, 0)) {
      set_keep_msg(msg_buf, 0);
      keep_msg_more = true;
    }
  }
}

void msg_ext_set_kind(const char *msg_kind)
{
  // Don't change the label of an existing batch:
  msg_ext_ui_flush();

  // TODO(bfredl): would be nice to avoid dynamic scoping, but that would
  // need refactoring the msg_ interface to not be "please pretend nvim is
  // a terminal for a moment"
  msg_ext_kind = msg_kind;
}

/// Prepare for outputting characters in the command line.
void msg_start(void)
{
  bool did_return = false;

  msg_row = MAX(msg_row, cmdline_row);

  if (!msg_silent) {
    XFREE_CLEAR(keep_msg);              // don't display old message now
    need_fileinfo = false;
  }

  if (need_clr_eos || (p_ch == 0 && redrawing_cmdline)) {
    // Halfway an ":echo" command and getting an (error) message: clear
    // any text from the command.
    need_clr_eos = false;
    msg_clr_eos();
  }

  // if cmdheight=0, we need to scroll in the first line of msg_grid upon the screen
  if (p_ch == 0 && !ui_has(kUIMessages) && !msg_scrolled) {
    msg_grid_validate();
    msg_scroll_up(false, true);
    msg_scrolled++;
    cmdline_row = Rows - 1;
  }

  if (!msg_scroll && full_screen) {     // overwrite last message
    msg_row = cmdline_row;
    msg_col = 0;
  } else if (msg_didout || (p_ch == 0 && !ui_has(kUIMessages))) {  // start message on next line
    msg_putchar('\n');
    did_return = true;
    cmdline_row = msg_row;
  }
  if (!msg_didany || lines_left < 0) {
    msg_starthere();
  }
  if (msg_silent == 0) {
    msg_didout = false;                     // no output on current line yet
  }

  if (ui_has(kUIMessages)) {
    msg_ext_ui_flush();
  }

  // When redirecting, may need to start a new line.
  if (!did_return) {
    redir_write("\n", 1);
  }
}

/// Note that the current msg position is where messages start.
void msg_starthere(void)
{
  lines_left = cmdline_row;
  msg_didany = false;
}

void msg_putchar(int c)
{
  msg_putchar_hl(c, 0);
}

void msg_putchar_hl(int c, int hl_id)
{
  char buf[MB_MAXCHAR + 1];

  if (IS_SPECIAL(c)) {
    buf[0] = (char)K_SPECIAL;
    buf[1] = (char)K_SECOND(c);
    buf[2] = (char)K_THIRD(c);
    buf[3] = NUL;
  } else {
    buf[utf_char2bytes(c, buf)] = NUL;
  }
  msg_puts_hl(buf, hl_id, false);
}

void msg_outnum(int n)
{
  char buf[20];

  snprintf(buf, sizeof(buf), "%d", n);
  msg_puts(buf);
}

void msg_home_replace(const char *fname)
{
  msg_home_replace_hl(fname, 0);
}

static void msg_home_replace_hl(const char *fname, int hl_id)
{
  char *name = home_replace_save(NULL, fname);
  msg_outtrans(name, hl_id, false);
  xfree(name);
}

/// Output "len" characters in "str" (including NULs) with translation
/// if "len" is -1, output up to a NUL character. Use highlight "hl_id".
///
/// @return  the number of characters it takes on the screen.
int msg_outtrans(const char *str, int hl_id, bool hist)
{
  return *str == NUL ? 0 : msg_outtrans_len(str, (int)strlen(str), hl_id, hist);
}

/// Output one character at "p".
/// Handles multi-byte characters.
///
/// @return  pointer to the next character.
const char *msg_outtrans_one(const char *p, int hl_id, bool hist)
{
  int l;

  if ((l = utfc_ptr2len(p)) > 1) {
    msg_outtrans_len(p, l, hl_id, hist);
    return p + l;
  }
  msg_puts_hl(transchar_byte_buf(NULL, (uint8_t)(*p)), hl_id, hist);
  return p + 1;
}

int msg_outtrans_len(const char *msgstr, int len, int hl_id, bool hist)
{
  int retval = 0;
  const char *str = msgstr;
  const char *plain_start = msgstr;
  char *s;
  int c;
  int save_got_int = got_int;

  // Only quit when got_int was set in here.
  got_int = false;

  if (hist) {
    msg_hist_add(str, len, hl_id);
  }

  // When drawing over the command line no need to clear it later or remove
  // the mode message.
  if (msg_silent == 0 && len > 0 && msg_row >= cmdline_row && msg_col == 0) {
    clear_cmdline = false;
    mode_displayed = false;
  }

  // Go over the string.  Special characters are translated and printed.
  // Normal characters are printed several at a time.
  while (--len >= 0 && !got_int) {
    // Don't include composing chars after the end.
    int mb_l = utfc_ptr2len_len(str, len + 1);
    if (mb_l > 1) {
      c = utf_ptr2char(str);
      if (vim_isprintc(c)) {
        // Printable multi-byte char: count the cells.
        retval += utf_ptr2cells(str);
      } else {
        // Unprintable multi-byte char: print the printable chars so
        // far and the translation of the unprintable char.
        if (str > plain_start) {
          msg_puts_len(plain_start, str - plain_start, hl_id, hist);
        }
        plain_start = str + mb_l;
        msg_puts_hl(transchar_buf(NULL, c), hl_id == 0 ? HLF_8 : hl_id, false);
        retval += char2cells(c);
      }
      len -= mb_l - 1;
      str += mb_l;
    } else {
      s = transchar_byte_buf(NULL, (uint8_t)(*str));
      if (s[1] != NUL) {
        // Unprintable char: print the printable chars so far and the
        // translation of the unprintable char.
        if (str > plain_start) {
          msg_puts_len(plain_start, str - plain_start, hl_id, hist);
        }
        plain_start = str + 1;
        msg_puts_hl(s, hl_id == 0 ? HLF_8 : hl_id, false);
        retval += (int)strlen(s);
      } else {
        retval++;
      }
      str++;
    }
  }

  if ((str > plain_start || plain_start == msgstr) && !got_int) {
    // Print the printable chars at the end (or emit empty string).
    msg_puts_len(plain_start, str - plain_start, hl_id, hist);
  }

  got_int |= save_got_int;

  return retval;
}

void msg_make(const char *arg)
{
  int i;
  static const char *str = "eeffoc";
  static const char *rs = "Plon#dqg#vxjduB";

  arg = skipwhite(arg);
  for (i = 5; *arg && i >= 0; i--) {
    if (*arg++ != str[i]) {
      break;
    }
  }
  if (i < 0) {
    msg_putchar('\n');
    for (i = 0; rs[i]; i++) {
      msg_putchar(rs[i] - 3);
    }
  }
}

/// Output the string 'str' up to a NUL character.
/// Return the number of characters it takes on the screen.
///
/// If K_SPECIAL is encountered, then it is taken in conjunction with the
/// following character and shown as <F1>, <S-Up> etc.  Any other character
/// which is not printable shown in <> form.
/// If 'from' is true (lhs of a mapping), a space is shown as <Space>.
/// If a character is displayed in one of these special ways, is also
/// highlighted (its highlight name is '8' in the p_hl variable).
/// Otherwise characters are not highlighted.
/// This function is used to show mappings, where we want to see how to type
/// the character/string -- webb
///
/// @param from  true for LHS of a mapping
/// @param maxlen  screen columns, 0 for unlimited
int msg_outtrans_special(const char *strstart, bool from, int maxlen)
{
  if (strstart == NULL) {
    return 0;  // Do nothing.
  }
  const char *str = strstart;
  int retval = 0;
  int hl_id = HLF_8;

  while (*str != NUL) {
    const char *text;
    // Leading and trailing spaces need to be displayed in <> form.
    if ((str == strstart || str[1] == NUL) && *str == ' ') {
      text = "<Space>";
      str++;
    } else {
      text = str2special(&str, from, false);
    }
    if (text[0] != NUL && text[1] == NUL) {
      // single-byte character or illegal byte
      text = transchar_byte_buf(NULL, (uint8_t)text[0]);
    }
    const int len = vim_strsize(text);
    if (maxlen > 0 && retval + len >= maxlen) {
      break;
    }
    // Highlight special keys
    msg_puts_hl(text, (len > 1 && utfc_ptr2len(text) <= 1 ? hl_id : 0), false);
    retval += len;
  }
  return retval;
}

/// Convert string, replacing key codes with printables
///
/// Used for lhs or rhs of mappings.
///
/// @param[in]  str  String to convert.
/// @param[in]  replace_spaces  Convert spaces into `<Space>`, normally used for
///                             lhs of mapping and keytrans(), but not rhs.
/// @param[in]  replace_lt  Convert `<` into `<lt>`.
///
/// @return [allocated] Converted string.
char *str2special_save(const char *const str, const bool replace_spaces, const bool replace_lt)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_MALLOC
  FUNC_ATTR_NONNULL_RET
{
  garray_T ga;
  ga_init(&ga, 1, 40);

  const char *p = str;
  while (*p != NUL) {
    ga_concat(&ga, str2special(&p, replace_spaces, replace_lt));
  }
  ga_append(&ga, NUL);
  return (char *)ga.ga_data;
}

/// Convert string, replacing key codes with printables
///
/// Used for lhs or rhs of mappings.
///
/// @param[in]  str  String to convert.
/// @param[in]  replace_spaces  Convert spaces into `<Space>`, normally used for
///                             lhs of mapping and keytrans(), but not rhs.
/// @param[in]  replace_lt  Convert `<` into `<lt>`.
///
/// @return [allocated] Converted string.
char *str2special_arena(const char *str, bool replace_spaces, bool replace_lt, Arena *arena)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_MALLOC
  FUNC_ATTR_NONNULL_RET
{
  const char *p = str;
  size_t len = 0;
  while (*p) {
    len += strlen(str2special(&p, replace_spaces, replace_lt));
  }

  char *buf = arena_alloc(arena, len + 1, false);
  size_t pos = 0;
  p = str;
  while (*p) {
    const char *s = str2special(&p, replace_spaces, replace_lt);
    size_t s_len = strlen(s);
    memcpy(buf + pos, s, s_len);
    pos += s_len;
  }
  buf[pos] = NUL;
  return buf;
}

/// Convert character, replacing key with printable representation.
///
/// @param[in,out]  sp  String to convert. Is advanced to the next key code.
/// @param[in]  replace_spaces  Convert spaces into `<Space>`, normally used for
///                             lhs of mapping and keytrans(), but not rhs.
/// @param[in]  replace_lt  Convert `<` into `<lt>`.
///
/// @return Converted key code, in a static buffer. Buffer is always one and the
///         same, so save converted string somewhere before running str2special
///         for the second time.
///         On illegal byte return a string with only that byte.
const char *str2special(const char **const sp, const bool replace_spaces, const bool replace_lt)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET
{
  static char buf[7];

  {
    // Try to un-escape a multi-byte character.  Return the un-escaped
    // string if it is a multi-byte character.
    const char *const p = mb_unescape(sp);
    if (p != NULL) {
      return p;
    }
  }

  const char *str = *sp;
  int c = (uint8_t)(*str);
  int modifiers = 0;
  bool special = false;
  if (c == K_SPECIAL && str[1] != NUL && str[2] != NUL) {
    if ((uint8_t)str[1] == KS_MODIFIER) {
      modifiers = (uint8_t)str[2];
      str += 3;
      c = (uint8_t)(*str);
    }
    if (c == K_SPECIAL && str[1] != NUL && str[2] != NUL) {
      c = TO_SPECIAL((uint8_t)str[1], (uint8_t)str[2]);
      str += 2;
    }
    if (IS_SPECIAL(c) || modifiers) {  // Special key.
      special = true;
    }
  }

  if (!IS_SPECIAL(c) && MB_BYTE2LEN(c) > 1) {
    *sp = str;
    // Try to un-escape a multi-byte character after modifiers.
    const char *p = mb_unescape(sp);
    if (p != NULL) {
      // Since 'special' is true the multi-byte character 'c' will be
      // processed by get_special_key_name().
      c = utf_ptr2char(p);
    } else {
      // illegal byte
      *sp = str + 1;
    }
  } else {
    // single-byte character, NUL or illegal byte
    *sp = str + (*str == NUL ? 0 : 1);
  }

  // Make special keys and C0 control characters in <> form, also <M-Space>.
  if (special
      || c < ' '
      || (replace_spaces && c == ' ')
      || (replace_lt && c == '<')) {
    return get_special_key_name(c, modifiers);
  }
  buf[0] = (char)c;
  buf[1] = NUL;
  return buf;
}

/// Convert string, replacing key codes with printables
///
/// @param[in]  str  String to convert.
/// @param[out]  buf  Buffer to save results to.
/// @param[in]  len  Buffer length.
void str2specialbuf(const char *sp, char *buf, size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  while (*sp) {
    const char *s = str2special(&sp, false, false);
    const size_t s_len = strlen(s);
    if (len <= s_len) {
      break;
    }
    memcpy(buf, s, s_len);
    buf += s_len;
    len -= s_len;
  }
  *buf = NUL;
}

/// print line for :print or :list command
void msg_prt_line(const char *s, bool list)
{
  schar_T sc;
  int col = 0;
  int n_extra = 0;
  schar_T sc_extra = 0;
  schar_T sc_final = 0;
  const char *p_extra = NULL;  // init to make SASC shut up. ASCII only!
  int n;
  int hl_id = 0;
  const char *lead = NULL;
  bool in_multispace = false;
  int multispace_pos = 0;
  const char *trail = NULL;
  int l;

  if (curwin->w_p_list) {
    list = true;
  }

  if (list) {
    // find start of trailing whitespace
    if (curwin->w_p_lcs_chars.trail) {
      trail = s + strlen(s);
      while (trail > s && ascii_iswhite(trail[-1])) {
        trail--;
      }
    }
    // find end of leading whitespace
    if (curwin->w_p_lcs_chars.lead || curwin->w_p_lcs_chars.leadmultispace != NULL) {
      lead = s;
      while (ascii_iswhite(lead[0])) {
        lead++;
      }
      // in a line full of spaces all of them are treated as trailing
      if (*lead == NUL) {
        lead = NULL;
      }
    }
  }

  // output a space for an empty line, otherwise the line will be overwritten
  if (*s == NUL && !(list && curwin->w_p_lcs_chars.eol != NUL)) {
    msg_putchar(' ');
  }

  while (!got_int) {
    if (n_extra > 0) {
      n_extra--;
      if (n_extra == 0 && sc_final) {
        sc = sc_final;
      } else if (sc_extra) {
        sc = sc_extra;
      } else {
        assert(p_extra != NULL);
        sc = schar_from_ascii((unsigned char)(*p_extra++));
      }
    } else if ((l = utfc_ptr2len(s)) > 1) {
      col += utf_ptr2cells(s);
      char buf[MB_MAXBYTES + 1];
      if (l >= MB_MAXBYTES) {
        xstrlcpy(buf, "?", sizeof(buf));
      } else if (curwin->w_p_lcs_chars.nbsp != NUL && list
                 && (utf_ptr2char(s) == 160 || utf_ptr2char(s) == 0x202f)) {
        schar_get(buf, curwin->w_p_lcs_chars.nbsp);
      } else {
        memmove(buf, s, (size_t)l);
        buf[l] = NUL;
      }
      msg_puts(buf);
      s += l;
      continue;
    } else {
      hl_id = 0;
      int c = (uint8_t)(*s++);
      if (c >= 0x80) {  // Illegal byte
        col += utf_char2cells(c);
        msg_putchar(c);
        continue;
      }
      sc_extra = NUL;
      sc_final = NUL;
      if (list) {
        in_multispace = c == ' ' && (*s == ' '
                                     || (col > 0 && s[-2] == ' '));
        if (!in_multispace) {
          multispace_pos = 0;
        }
      }
      if (c == TAB && (!list || curwin->w_p_lcs_chars.tab1)) {
        // tab amount depends on current column
        n_extra = tabstop_padding(col, curbuf->b_p_ts,
                                  curbuf->b_p_vts_array) - 1;
        if (!list) {
          sc = schar_from_ascii(' ');
          sc_extra = schar_from_ascii(' ');
        } else {
          sc = (n_extra == 0 && curwin->w_p_lcs_chars.tab3)
               ? curwin->w_p_lcs_chars.tab3
               : curwin->w_p_lcs_chars.tab1;
          sc_extra = curwin->w_p_lcs_chars.tab2;
          sc_final = curwin->w_p_lcs_chars.tab3;
          hl_id = HLF_0;
        }
      } else if (c == NUL && list && curwin->w_p_lcs_chars.eol != NUL) {
        p_extra = "";
        n_extra = 1;
        sc = curwin->w_p_lcs_chars.eol;
        hl_id = HLF_AT;
        s--;
      } else if (c != NUL && (n = byte2cells(c)) > 1) {
        n_extra = n - 1;
        p_extra = transchar_byte_buf(NULL, c);
        sc = schar_from_ascii(*p_extra++);
        // Use special coloring to be able to distinguish <hex> from
        // the same in plain text.
        hl_id = HLF_0;
      } else if (c == ' ') {
        if (lead != NULL && s <= lead && in_multispace
            && curwin->w_p_lcs_chars.leadmultispace != NULL) {
          sc = curwin->w_p_lcs_chars.leadmultispace[multispace_pos++];
          if (curwin->w_p_lcs_chars.leadmultispace[multispace_pos] == NUL) {
            multispace_pos = 0;
          }
          hl_id = HLF_0;
        } else if (lead != NULL && s <= lead && curwin->w_p_lcs_chars.lead != NUL) {
          sc = curwin->w_p_lcs_chars.lead;
          hl_id = HLF_0;
        } else if (trail != NULL && s > trail) {
          sc = curwin->w_p_lcs_chars.trail;
          hl_id = HLF_0;
        } else if (in_multispace
                   && curwin->w_p_lcs_chars.multispace != NULL) {
          sc = curwin->w_p_lcs_chars.multispace[multispace_pos++];
          if (curwin->w_p_lcs_chars.multispace[multispace_pos] == NUL) {
            multispace_pos = 0;
          }
          hl_id = HLF_0;
        } else if (list && curwin->w_p_lcs_chars.space != NUL) {
          sc = curwin->w_p_lcs_chars.space;
          hl_id = HLF_0;
        } else {
          sc = schar_from_ascii(' ');  // SPACE!
        }
      } else {
        sc = schar_from_ascii(c);
      }
    }

    if (sc == NUL) {
      break;
    }

    // TODO(bfredl): this is such baloney. need msg_put_schar
    char buf[MAX_SCHAR_SIZE];
    schar_get(buf, sc);
    msg_puts_hl(buf, hl_id, false);
    col++;
  }
  msg_clr_eos();
}

/// Output a string to the screen at position msg_row, msg_col.
/// Update msg_row and msg_col for the next message.
void msg_puts(const char *s)
{
  msg_puts_hl(s, 0, false);
}

void msg_puts_title(const char *s)
{
  msg_puts_hl(s, HLF_T, false);
}

/// Show a message in such a way that it always fits in the line.  Cut out a
/// part in the middle and replace it with "..." when necessary.
/// Does not handle multi-byte characters!
void msg_outtrans_long(const char *longstr, int hl_id)
{
  int len = (int)strlen(longstr);
  int slen = len;
  int room = Columns - msg_col;
  if (!ui_has(kUIMessages) && len > room && room >= 20) {
    slen = (room - 3) / 2;
    msg_outtrans_len(longstr, slen, hl_id, false);
    msg_puts_hl("...", HLF_8, false);
  }
  msg_outtrans_len(longstr + len - slen, slen, hl_id, false);
}

/// Basic function for writing a message with highlight id.
void msg_puts_hl(const char *const s, const int hl_id, const bool hist)
{
  msg_puts_len(s, -1, hl_id, hist);
}

/// Write a message with highlight id.
///
/// @param[in]  str  NUL-terminated message string.
/// @param[in]  len  Length of the string or -1.
/// @param[in]  hl_id  Highlight id.
void msg_puts_len(const char *const str, const ptrdiff_t len, int hl_id, bool hist)
  FUNC_ATTR_NONNULL_ALL
{
  assert(len < 0 || memchr(str, 0, (size_t)len) == NULL);
  // If redirection is on, also write to the redirection file.
  redir_write(str, len);

  // Don't print anything when using ":silent cmd" or empty message.
  if (msg_silent != 0 || *str == NUL) {
    if (*str == NUL && ui_has(kUIMessages)) {
      ui_call_msg_show(cstr_as_string("empty"), (Array)ARRAY_DICT_INIT, false, false, false);
    }
    return;
  }

  if (hist) {
    msg_hist_add(str, (int)len, hl_id);
  }

  // When writing something to the screen after it has scrolled, requires a
  // wait-return prompt later.  Needed when scrolling, resetting
  // need_wait_return after some prompt, and then outputting something
  // without scrolling
  // Not needed when only using CR to move the cursor.
  bool overflow = !ui_has(kUIMessages) && msg_scrolled > (p_ch == 0 ? 1 : 0);

  if (overflow && !msg_scrolled_ign && strcmp(str, "\r") != 0) {
    need_wait_return = true;
  }
  msg_didany = true;  // remember that something was outputted

  // If there is no valid screen, use fprintf so we can see error messages.
  // If termcap is not active, we may be writing in an alternate console
  // window, cursor positioning may not work correctly (window size may be
  // different, e.g. for Win32 console) or we just don't know where the
  // cursor is.
  if (msg_use_printf()) {
    int saved_msg_col = msg_col;
    msg_puts_printf(str, len);
    if (headless_mode) {
      msg_col = saved_msg_col;
    }
  }
  if (!msg_use_printf() || (headless_mode && default_grid.chars)) {
    msg_puts_display(str, (int)len, hl_id, false);
  }

  need_fileinfo = false;
}

static void msg_ext_emit_chunk(void)
{
  if (msg_ext_chunks == NULL) {
    msg_ext_init_chunks();
  }
  // Color was changed or a message flushed, end current chunk.
  if (msg_ext_last_attr == -1) {
    return;  // no chunk
  }
  Array chunk = ARRAY_DICT_INIT;
  ADD(chunk, INTEGER_OBJ(msg_ext_last_attr));
  msg_ext_last_attr = -1;
  String text = ga_take_string(&msg_ext_last_chunk);
  ADD(chunk, STRING_OBJ(text));
  ADD(chunk, INTEGER_OBJ(msg_ext_last_hl_id));
  ADD(*msg_ext_chunks, ARRAY_OBJ(chunk));
}

/// The display part of msg_puts_len().
/// May be called recursively to display scroll-back text.
static void msg_puts_display(const char *str, int maxlen, int hl_id, int recurse)
{
  const char *s = str;
  const char *sb_str = str;
  int sb_col = msg_col;
  int attr = hl_id ? syn_id2attr(hl_id) : 0;

  did_wait_return = false;

  if (ui_has(kUIMessages)) {
    if (attr != msg_ext_last_attr) {
      msg_ext_emit_chunk();
      msg_ext_last_attr = attr;
      msg_ext_last_hl_id = hl_id;
    }
    // Concat pieces with the same highlight
    size_t len = maxlen < 0 ? strlen(str) : strnlen(str, (size_t)maxlen);
    ga_concat_len(&msg_ext_last_chunk, str, len);

    // Find last newline in the message and calculate the current message column
    const char *lastline = strrchr(str, '\n');
    maxlen -= (int)(lastline ? (lastline - str) : 0);
    const char *p = lastline ? lastline + 1 : str;
    int col = (int)(maxlen < 0 ? mb_string2cells(p) : mb_string2cells_len(p, (size_t)(maxlen)));
    msg_col = (lastline ? 0 : msg_col) + col;

    return;
  }

  int print_attr = hl_combine_attr(HL_ATTR(HLF_MSG), attr);
  msg_grid_validate();

  cmdline_was_last_drawn = redrawing_cmdline;

  int msg_row_pending = -1;

  while (true) {
    if (msg_col >= Columns) {
      if (p_more && !recurse) {
        // Store text for scrolling back.
        store_sb_text(&sb_str, s, hl_id, &sb_col, true);
      }
      if (msg_no_more && lines_left == 0) {
        break;
      }

      msg_col = 0;
      msg_row++;
      msg_didout = false;
    }

    if (msg_row >= Rows) {
      msg_row = Rows - 1;

      // When no more prompt and no more room, truncate here
      if (msg_no_more && lines_left == 0) {
        break;
      }

      if (!recurse) {
        if (msg_row_pending >= 0) {
          msg_line_flush();
          msg_row_pending = -1;
        }

        // Scroll the screen up one line.
        msg_scroll_up(true, false);

        inc_msg_scrolled();
        need_wait_return = true;       // may need wait_return() in main()
        redraw_cmdline = true;
        if (cmdline_row > 0 && !exmode_active) {
          cmdline_row--;
        }

        // If screen is completely filled and 'more' is set then wait
        // for a character.
        if (lines_left > 0) {
          lines_left--;
        }

        if (p_more && lines_left == 0 && State != MODE_HITRETURN
            && !msg_no_more && !exmode_active) {
          if (do_more_prompt(NUL)) {
            s = confirm_buttons;
          }
          if (quit_more) {
            return;
          }
        }
      }
    }

    if (!((maxlen < 0 || (int)(s - str) < maxlen) && *s != NUL)) {
      break;
    }

    if (msg_row != msg_row_pending && ((uint8_t)(*s) >= 0x20 || *s == TAB)) {
      // TODO(bfredl): this logic is messier that it has to be. What
      // messages really want is its own private linebuf_char buffer.
      if (msg_row_pending >= 0) {
        msg_line_flush();
      }
      grid_line_start(&msg_grid_adj, msg_row);
      msg_row_pending = msg_row;
    }

    if ((uint8_t)(*s) >= 0x20) {  // printable char
      int cw = utf_ptr2cells(s);
      // avoid including composing chars after the end
      int l = (maxlen >= 0) ? utfc_ptr2len_len(s, (int)((str + maxlen) - s)) : utfc_ptr2len(s);

      if (cw > 1 && (msg_col == Columns - 1)) {
        // Doesn't fit, print a highlighted '>' to fill it up.
        grid_line_puts(msg_col, ">", 1, HL_ATTR(HLF_AT));
        cw = 1;
      } else {
        grid_line_puts(msg_col, s, l, print_attr);
        s += l;
      }
      msg_didout = true;  // remember that line is not empty
      msg_col += cw;
    } else {
      char c = *s++;
      if (c == '\n') {  // go to next line
        msg_didout = false;  // remember that line is empty
        msg_col = 0;
        msg_row++;
        if (p_more && !recurse) {
          // Store text for scrolling back.
          store_sb_text(&sb_str, s, hl_id, &sb_col, true);
        }
      } else if (c == '\r') {  // go to column 0
        msg_col = 0;
      } else if (c == '\b') {  // go to previous char
        if (msg_col) {
          msg_col--;
        }
      } else if (c == TAB) {  // translate Tab into spaces
        do {
          grid_line_puts(msg_col, " ", 1, print_attr);
          msg_col += 1;

          if (msg_col == Columns) {
            break;
          }
        } while (msg_col & 7);
      } else if (c == BELL) {  // beep (from ":sh")
        vim_beep(kOptBoFlagShell);
      }
    }
  }

  if (msg_row_pending >= 0) {
    msg_line_flush();
  }
  msg_cursor_goto(msg_row, msg_col);

  if (p_more && !recurse) {
    store_sb_text(&sb_str, s, hl_id, &sb_col, false);
  }

  msg_check();
}

void msg_line_flush(void)
{
  if (cmdmsg_rl) {
    grid_line_mirror(msg_grid.cols);
  }
  grid_line_flush_if_valid_row();
}

void msg_cursor_goto(int row, int col)
{
  if (cmdmsg_rl) {
    col = Columns - 1 - col;
  }
  ScreenGrid *grid = grid_adjust(&msg_grid_adj, &row, &col);
  ui_grid_cursor_goto(grid->handle, row, col);
}

/// @return  true when ":filter pattern" was used and "msg" does not match
///          "pattern".
bool message_filtered(const char *msg)
{
  if (cmdmod.cmod_filter_regmatch.regprog == NULL) {
    return false;
  }

  bool match = vim_regexec(&cmdmod.cmod_filter_regmatch, msg, 0);
  return cmdmod.cmod_filter_force ? match : !match;
}

/// including horizontal separator
int msg_scrollsize(void)
{
  return msg_scrolled + (int)p_ch + ((p_ch > 0 || msg_scrolled > 1) ? 1 : 0);
}

bool msg_do_throttle(void)
{
  return msg_use_grid() && !(rdb_flags & kOptRdbFlagNothrottle);
}

/// Scroll the screen up one line for displaying the next message line.
void msg_scroll_up(bool may_throttle, bool zerocmd)
{
  if (may_throttle && msg_do_throttle()) {
    msg_grid.throttled = true;
  }
  msg_did_scroll = true;
  if (msg_grid_pos > 0) {
    msg_grid_set_pos(msg_grid_pos - 1, !zerocmd);

    // When displaying the first line with cmdheight=0, we need to draw over
    // the existing last line of the screen.
    if (zerocmd && msg_grid.chars) {
      grid_clear_line(&msg_grid, msg_grid.line_offset[0], msg_grid.cols, false);
    }
  } else {
    grid_del_lines(&msg_grid, 0, 1, msg_grid.rows, 0, msg_grid.cols);
    memmove(msg_grid.dirty_col, msg_grid.dirty_col + 1,
            (size_t)(msg_grid.rows - 1) * sizeof(*msg_grid.dirty_col));
    msg_grid.dirty_col[msg_grid.rows - 1] = 0;
  }

  grid_clear(&msg_grid_adj, Rows - 1, Rows, 0, Columns, HL_ATTR(HLF_MSG));
}

/// Send throttled message output to UI clients
///
/// The way message.c uses the grid_xx family of functions is quite inefficient
/// relative to the "gridline" UI protocol used by TUI and modern clients.
/// For instance scrolling is done one line at a time. By throttling drawing
/// on the message grid, we can coalesce scrolling to a single grid_scroll
/// per screen update.
///
/// NB: The bookkeeping is quite messy, and rests on a bunch of poorly
/// documented assumptions. For instance that the message area always grows
/// while being throttled, messages are only being output on the last line
/// etc.
///
/// Probably message scrollback storage should be reimplemented as a
/// file_buffer, and message scrolling in TUI be reimplemented as a modal
/// floating window. Then we get throttling "for free" using standard
/// redraw_later code paths.
void msg_scroll_flush(void)
{
  if (msg_grid.throttled) {
    msg_grid.throttled = false;
    int pos_delta = msg_grid_pos_at_flush - msg_grid_pos;
    assert(pos_delta >= 0);
    int delta = MIN(msg_scrolled - msg_scrolled_at_flush, msg_grid.rows);

    if (pos_delta > 0) {
      ui_ext_msg_set_pos(msg_grid_pos, true);
    }

    int to_scroll = delta - pos_delta - msg_grid_scroll_discount;
    assert(to_scroll >= 0);

    // TODO(bfredl): msg_grid_pos should be 0 already when starting scrolling
    // but this sometimes fails in "headless" message printing.
    if (to_scroll > 0 && msg_grid_pos == 0) {
      ui_call_grid_scroll(msg_grid.handle, 0, Rows, 0, Columns, to_scroll, 0);
    }

    for (int i = MAX(Rows - MAX(delta, 1), 0); i < Rows; i++) {
      int row = i - msg_grid_pos;
      assert(row >= 0);
      ui_line(&msg_grid, row, false, 0, msg_grid.dirty_col[row], msg_grid.cols,
              HL_ATTR(HLF_MSG), false);
      msg_grid.dirty_col[row] = 0;
    }
  }
  msg_scrolled_at_flush = msg_scrolled;
  msg_grid_scroll_discount = 0;
  msg_grid_pos_at_flush = msg_grid_pos;
}

void msg_reset_scroll(void)
{
  if (ui_has(kUIMessages)) {
    return;
  }
  // TODO(bfredl): some duplicate logic with update_screen(). Later on
  // we should properly disentangle message clear with full screen redraw.
  msg_grid.throttled = false;
  // TODO(bfredl): risk for extra flicker i e with
  // "nvim -o has_swap also_has_swap"
  msg_grid_set_pos(Rows - (int)p_ch, false);
  clear_cmdline = true;
  if (msg_grid.chars) {
    // non-displayed part of msg_grid is considered invalid.
    for (int i = 0; i < MIN(msg_scrollsize(), msg_grid.rows); i++) {
      grid_clear_line(&msg_grid, msg_grid.line_offset[i],
                      msg_grid.cols, false);
    }
  }
  msg_scrolled = 0;
  msg_scrolled_at_flush = 0;
  msg_grid_scroll_discount = 0;
}

void msg_ui_refresh(void)
{
  if (ui_has(kUIMultigrid) && msg_grid.chars) {
    ui_call_grid_resize(msg_grid.handle, msg_grid.cols, msg_grid.rows);
    ui_ext_msg_set_pos(msg_grid_pos, msg_scrolled);
  }
}

void msg_ui_flush(void)
{
  if (ui_has(kUIMultigrid) && msg_grid.chars && msg_grid.pending_comp_index_update) {
    ui_ext_msg_set_pos(msg_grid_pos, msg_scrolled);
  }
}

/// Increment "msg_scrolled".
static void inc_msg_scrolled(void)
{
  if (*get_vim_var_str(VV_SCROLLSTART) == NUL) {
    char *p = SOURCING_NAME;
    char *tofree = NULL;

    // v:scrollstart is empty, set it to the script/function name and line
    // number
    if (p == NULL) {
      p = _("Unknown");
    } else {
      size_t len = strlen(p) + 40;
      tofree = xmalloc(len);
      vim_snprintf(tofree, len, _("%s line %" PRId64),
                   p, (int64_t)SOURCING_LNUM);
      p = tofree;
    }
    set_vim_var_string(VV_SCROLLSTART, p, -1);
    xfree(tofree);
  }
  msg_scrolled++;
  set_must_redraw(UPD_VALID);
}

static msgchunk_T *last_msgchunk = NULL;  // last displayed text

typedef enum {
  SB_CLEAR_NONE = 0,
  SB_CLEAR_ALL,
  SB_CLEAR_CMDLINE_BUSY,
  SB_CLEAR_CMDLINE_DONE,
} sb_clear_T;

// When to clear text on next msg.
static sb_clear_T do_clear_sb_text = SB_CLEAR_NONE;

/// Store part of a printed message for displaying when scrolling back.
///
/// @param sb_str  start of string
/// @param s  just after string
/// @param finish  line ends
static void store_sb_text(const char **sb_str, const char *s, int hl_id, int *sb_col, int finish)
{
  msgchunk_T *mp;

  if (do_clear_sb_text == SB_CLEAR_ALL
      || do_clear_sb_text == SB_CLEAR_CMDLINE_DONE) {
    clear_sb_text(do_clear_sb_text == SB_CLEAR_ALL);
    msg_sb_eol();  // prevent messages from overlapping
    if (do_clear_sb_text == SB_CLEAR_CMDLINE_DONE && s > *sb_str && **sb_str == '\n') {
      (*sb_str)++;
    }
    do_clear_sb_text = SB_CLEAR_NONE;
  }

  if (s > *sb_str) {
    mp = xmalloc(offsetof(msgchunk_T, sb_text) + (size_t)(s - *sb_str) + 1);
    mp->sb_eol = (char)finish;
    mp->sb_msg_col = *sb_col;
    mp->sb_hl_id = hl_id;
    memcpy(mp->sb_text, *sb_str, (size_t)(s - *sb_str));
    mp->sb_text[s - *sb_str] = NUL;

    if (last_msgchunk == NULL) {
      last_msgchunk = mp;
      mp->sb_prev = NULL;
    } else {
      mp->sb_prev = last_msgchunk;
      last_msgchunk->sb_next = mp;
      last_msgchunk = mp;
    }
    mp->sb_next = NULL;
  } else if (finish && last_msgchunk != NULL) {
    last_msgchunk->sb_eol = true;
  }

  *sb_str = s;
  *sb_col = 0;
}

/// Finished showing messages, clear the scroll-back text on the next message.
void may_clear_sb_text(void)
{
  do_clear_sb_text = SB_CLEAR_ALL;
  do_clear_hist_temp = true;
}

/// Starting to edit the command line: do not clear messages now.
void sb_text_start_cmdline(void)
{
  if (do_clear_sb_text == SB_CLEAR_CMDLINE_BUSY) {
    // Invoking command line recursively: the previous-level command line
    // doesn't need to be remembered as it will be redrawn when returning
    // to that level.
    sb_text_restart_cmdline();
  } else {
    msg_sb_eol();
    do_clear_sb_text = SB_CLEAR_CMDLINE_BUSY;
  }
}

/// Redrawing the command line: clear the last unfinished line.
void sb_text_restart_cmdline(void)
{
  // Needed when returning from nested command line.
  do_clear_sb_text = SB_CLEAR_CMDLINE_BUSY;

  if (last_msgchunk == NULL || last_msgchunk->sb_eol) {
    // No unfinished line: don't clear anything.
    return;
  }

  msgchunk_T *tofree = msg_sb_start(last_msgchunk);
  last_msgchunk = tofree->sb_prev;
  if (last_msgchunk != NULL) {
    last_msgchunk->sb_next = NULL;
  }
  while (tofree != NULL) {
    msgchunk_T *tofree_next = tofree->sb_next;
    xfree(tofree);
    tofree = tofree_next;
  }
}

/// Ending to edit the command line: clear old lines but the last one later.
void sb_text_end_cmdline(void)
{
  do_clear_sb_text = SB_CLEAR_CMDLINE_DONE;
}

/// Clear any text remembered for scrolling back.
/// When "all" is false keep the last line.
/// Called when redrawing the screen.
void clear_sb_text(bool all)
{
  msgchunk_T *mp;
  msgchunk_T **lastp;

  if (all) {
    lastp = &last_msgchunk;
  } else {
    if (last_msgchunk == NULL) {
      return;
    }
    lastp = &msg_sb_start(last_msgchunk)->sb_prev;
  }

  while (*lastp != NULL) {
    mp = (*lastp)->sb_prev;
    xfree(*lastp);
    *lastp = mp;
  }
}

/// "g<" command.
void show_sb_text(void)
{
  if (ui_has(kUIMessages)) {
    exarg_T ea = { .arg = "", .skip = true };
    ex_messages(&ea);
    return;
  }
  // Only show something if there is more than one line, otherwise it looks
  // weird, typing a command without output results in one line.
  msgchunk_T *mp = msg_sb_start(last_msgchunk);
  if (mp == NULL || mp->sb_prev == NULL) {
    vim_beep(kOptBoFlagMess);
  } else {
    do_more_prompt('G');
    wait_return(false);
  }
}

/// Move to the start of screen line in already displayed text.
static msgchunk_T *msg_sb_start(msgchunk_T *mps)
{
  msgchunk_T *mp = mps;

  while (mp != NULL && mp->sb_prev != NULL && !mp->sb_prev->sb_eol) {
    mp = mp->sb_prev;
  }
  return mp;
}

/// Mark the last message chunk as finishing the line.
void msg_sb_eol(void)
{
  if (last_msgchunk != NULL) {
    last_msgchunk->sb_eol = true;
  }
}

/// Display a screen line from previously displayed text at row "row".
///
/// @return  a pointer to the text for the next line (can be NULL).
static msgchunk_T *disp_sb_line(int row, msgchunk_T *smp)
{
  msgchunk_T *mp = smp;

  while (true) {
    msg_row = row;
    msg_col = mp->sb_msg_col;
    char *p = mp->sb_text;
    msg_puts_display(p, -1, mp->sb_hl_id, true);
    if (mp->sb_eol || mp->sb_next == NULL) {
      break;
    }
    mp = mp->sb_next;
  }

  return mp->sb_next;
}

/// @return  true when messages should be printed to stdout/stderr:
///          - "batch mode" ("silent mode", -es/-Es/-l)
///          - no UI and not embedded
int msg_use_printf(void)
{
  return !embedded_mode && !ui_active();
}

/// Print a message when there is no valid screen.
static void msg_puts_printf(const char *str, const ptrdiff_t maxlen)
{
  const char *s = str;
  char buf[7];
  char *p;

  if (on_print.type != kCallbackNone) {
    typval_T argv[1];
    argv[0].v_type = VAR_STRING;
    argv[0].v_lock = VAR_UNLOCKED;
    argv[0].vval.v_string = (char *)str;
    typval_T rettv = TV_INITIAL_VALUE;
    callback_call(&on_print, 1, argv, &rettv);
    tv_clear(&rettv);
    return;
  }

  while ((maxlen < 0 || s - str < maxlen) && *s != NUL) {
    int len = utf_ptr2len(s);
    if (!(silent_mode && p_verbose == 0)) {
      // NL --> CR NL translation (for Unix, not for "--version")
      p = &buf[0];
      if (*s == '\n' && !info_message) {
        *p++ = '\r';
      }
      memcpy(p, s, (size_t)len);
      *(p + len) = NUL;
      if (info_message) {
        printf("%s", buf);
      } else {
        fprintf(stderr, "%s", buf);
      }
    }

    int cw = utf_char2cells(utf_ptr2char(s));
    // primitive way to compute the current column
    if (*s == '\r' || *s == '\n') {
      msg_col = 0;
      msg_didout = false;
    } else {
      msg_col += cw;
      msg_didout = true;
    }
    s += len;
  }
}

/// Show the more-prompt and handle the user response.
/// This takes care of scrolling back and displaying previously displayed text.
/// When at hit-enter prompt "typed_char" is the already typed character,
/// otherwise it's NUL.
///
/// @return  true when jumping ahead to "confirm_buttons".
static bool do_more_prompt(int typed_char)
{
  static bool entered = false;
  int used_typed_char = typed_char;
  int oldState = State;
  int c;
  bool retval = false;
  bool to_redraw = false;
  msgchunk_T *mp_last = NULL;
  msgchunk_T *mp;

  // If headless mode is enabled and no input is required, this variable
  // will be true. However If server mode is enabled, the message "--more--"
  // should be displayed.
  bool no_need_more = headless_mode && !embedded_mode && !ui_active();

  // We get called recursively when a timer callback outputs a message. In
  // that case don't show another prompt. Also when at the hit-Enter prompt
  // and nothing was typed.
  if (no_need_more || entered || (State == MODE_HITRETURN && typed_char == 0)) {
    return false;
  }
  entered = true;

  if (typed_char == 'G') {
    // "g<": Find first line on the last page.
    mp_last = msg_sb_start(last_msgchunk);
    for (int i = 0; i < Rows - 2 && mp_last != NULL
         && mp_last->sb_prev != NULL; i++) {
      mp_last = msg_sb_start(mp_last->sb_prev);
    }
  }

  State = MODE_ASKMORE;
  setmouse();
  if (typed_char == NUL) {
    msg_moremsg(false);
  }
  while (true) {
    // Get a typed character directly from the user.
    if (used_typed_char != NUL) {
      c = used_typed_char;              // was typed at hit-enter prompt
      used_typed_char = NUL;
    } else {
      c = get_keystroke(resize_events);
    }

    int toscroll = 0;
    switch (c) {
    case BS:                    // scroll one line back
    case K_BS:
    case 'k':
    case K_UP:
      toscroll = -1;
      break;

    case CAR:                   // one extra line
    case NL:
    case 'j':
    case K_DOWN:
      toscroll = 1;
      break;

    case 'u':                   // Up half a page
      toscroll = -(Rows / 2);
      break;

    case 'd':                   // Down half a page
      toscroll = Rows / 2;
      break;

    case 'b':                   // one page back
    case K_PAGEUP:
      toscroll = -(Rows - 1);
      break;

    case ' ':                   // one extra page
    case 'f':
    case K_PAGEDOWN:
    case K_LEFTMOUSE:
      toscroll = Rows - 1;
      break;

    case 'g':                   // all the way back to the start
      toscroll = -999999;
      break;

    case 'G':                   // all the way to the end
      toscroll = 999999;
      lines_left = 999999;
      break;

    case ':':                   // start new command line
      if (!confirm_msg_used) {
        // Since got_int is set all typeahead will be flushed, but we
        // want to keep this ':', remember that in a special way.
        typeahead_noflush(':');
        cmdline_row = Rows - 1;                 // put ':' on this line
        skip_redraw = true;                     // skip redraw once
        need_wait_return = false;               // don't wait in main()
      }
      FALLTHROUGH;
    case 'q':                   // quit
    case Ctrl_C:
    case ESC:
      if (confirm_msg_used) {
        // Jump to the choices of the dialog.
        retval = true;
      } else {
        got_int = true;
        quit_more = true;
      }
      // When there is some more output (wrapping line) display that
      // without another prompt.
      lines_left = Rows - 1;
      break;

    case K_EVENT:
      // only resize_events are processed here
      // Attempt to redraw the screen. sb_text doesn't support reflow
      // so this only really works for vertical resize.
      multiqueue_process_events(resize_events);
      to_redraw = true;
      break;

    default:                    // no valid response
      msg_moremsg(true);
      continue;
    }

    // code assumes we only do one at a time
    assert((toscroll == 0) || !to_redraw);

    if (toscroll != 0 || to_redraw) {
      if (toscroll < 0 || to_redraw) {
        // go to start of last line
        if (mp_last == NULL) {
          mp = msg_sb_start(last_msgchunk);
        } else if (mp_last->sb_prev != NULL) {
          mp = msg_sb_start(mp_last->sb_prev);
        } else {
          mp = NULL;
        }

        // go to start of line at top of the screen
        for (int i = 0; i < Rows - 2 && mp != NULL && mp->sb_prev != NULL; i++) {
          mp = msg_sb_start(mp->sb_prev);
        }

        if (mp != NULL && (mp->sb_prev != NULL || to_redraw)) {
          // Find line to be displayed at top
          for (int i = 0; i > toscroll; i--) {
            if (mp == NULL || mp->sb_prev == NULL) {
              break;
            }
            mp = msg_sb_start(mp->sb_prev);
            if (mp_last == NULL) {
              mp_last = msg_sb_start(last_msgchunk);
            } else {
              mp_last = msg_sb_start(mp_last->sb_prev);
            }
          }

          if (toscroll == -1 && !to_redraw) {
            grid_ins_lines(&msg_grid, 0, 1, Rows, 0, Columns);
            grid_clear(&msg_grid_adj, 0, 1, 0, Columns, HL_ATTR(HLF_MSG));
            // display line at top
            disp_sb_line(0, mp);
          } else {
            // redisplay all lines
            // TODO(bfredl): this case is not optimized (though only concerns
            // event fragmentation, not unnecessary scroll events).
            grid_clear(&msg_grid_adj, 0, Rows, 0, Columns, HL_ATTR(HLF_MSG));
            for (int i = 0; mp != NULL && i < Rows - 1; i++) {
              mp = disp_sb_line(i, mp);
              msg_scrolled++;
            }
            to_redraw = false;
          }
          toscroll = 0;
        }
      } else {
        // First display any text that we scrolled back.
        // if p_ch=0 we need to allocate a line for "press enter" messages!
        if (cmdline_row >= Rows && !ui_has(kUIMessages)) {
          msg_scroll_up(true, false);
          msg_scrolled++;
        }
        while (toscroll > 0 && mp_last != NULL) {
          if (msg_do_throttle() && !msg_grid.throttled) {
            // Tricky: we redraw at one line higher than usual. Therefore
            // the non-flushed area is one line larger.
            msg_scrolled_at_flush--;
            msg_grid_scroll_discount++;
          }
          // scroll up, display line at bottom
          msg_scroll_up(true, false);
          inc_msg_scrolled();
          grid_clear(&msg_grid_adj, Rows - 2, Rows - 1, 0, Columns, HL_ATTR(HLF_MSG));
          mp_last = disp_sb_line(Rows - 2, mp_last);
          toscroll--;
        }
      }

      if (toscroll <= 0) {
        // displayed the requested text, more prompt again
        grid_clear(&msg_grid_adj, Rows - 1, Rows, 0, Columns, HL_ATTR(HLF_MSG));
        msg_moremsg(false);
        continue;
      }

      // display more text, return to caller
      lines_left = toscroll;
    }

    break;
  }

  // clear the --more-- message
  grid_clear(&msg_grid_adj, Rows - 1, Rows, 0, Columns, HL_ATTR(HLF_MSG));
  redraw_cmdline = true;
  clear_cmdline = false;
  mode_displayed = false;

  State = oldState;
  setmouse();
  if (quit_more) {
    msg_row = Rows - 1;
    msg_col = 0;
  }

  entered = false;
  return retval;
}

void msg_moremsg(bool full)
{
  int attr = hl_combine_attr(HL_ATTR(HLF_MSG), HL_ATTR(HLF_M));
  grid_line_start(&msg_grid_adj, Rows - 1);
  int len = grid_line_puts(0, _("-- More --"), -1, attr);
  if (full) {
    len += grid_line_puts(len, _(" SPACE/d/j: screen/page/line down, b/u/k: up, q: quit "),
                          -1, attr);
  }
  grid_line_cursor_goto(len);
  grid_line_flush();
}

/// Repeat the message for the current mode: MODE_ASKMORE, MODE_EXTERNCMD,
/// confirm() prompt or exmode_active.
void repeat_message(void)
{
  if (ui_has(kUIMessages)) {
    return;
  }

  if (State == MODE_ASKMORE) {
    msg_moremsg(true);          // display --more-- message again
    msg_row = Rows - 1;
  } else if (State == MODE_CMDLINE && confirm_msg != NULL) {
    display_confirm_msg();      // display ":confirm" message again
    msg_row = Rows - 1;
  } else if (State == MODE_EXTERNCMD) {
    ui_cursor_goto(msg_row, msg_col);     // put cursor back
  } else if (State == MODE_HITRETURN || State == MODE_SETWSIZE) {
    if (msg_row == Rows - 1) {
      // Avoid drawing the "hit-enter" prompt below the previous one,
      // overwrite it.  Esp. useful when regaining focus and a
      // FocusGained autocmd exists but didn't draw anything.
      msg_didout = false;
      msg_col = 0;
      msg_clr_eos();
    }
    hit_return_msg(false);
    msg_row = Rows - 1;
  }
}

/// Clear from current message position to end of screen.
/// Skip this when ":silent" was used, no need to clear for redirection.
void msg_clr_eos(void)
{
  if (msg_silent == 0) {
    msg_clr_eos_force();
  }
}

/// Clear from current message position to end of screen.
/// Note: msg_col is not updated, so we remember the end of the message
/// for msg_check().
void msg_clr_eos_force(void)
{
  if (ui_has(kUIMessages)) {
    return;
  }
  int msg_startcol = (cmdmsg_rl) ? 0 : msg_col;
  int msg_endcol = (cmdmsg_rl) ? Columns - msg_col : Columns;

  // TODO(bfredl): ugly, this state should already been validated at this
  // point. But msg_clr_eos() is called in a lot of places.
  if (msg_grid.chars && msg_row < msg_grid_pos) {
    msg_grid_validate();
    if (msg_row < msg_grid_pos) {
      msg_row = msg_grid_pos;
    }
  }

  grid_clear(&msg_grid_adj, msg_row, msg_row + 1, msg_startcol, msg_endcol, HL_ATTR(HLF_MSG));
  grid_clear(&msg_grid_adj, msg_row + 1, Rows, 0, Columns, HL_ATTR(HLF_MSG));

  redraw_cmdline = true;  // overwritten the command line
  if (msg_row < Rows - 1 || msg_col == 0) {
    clear_cmdline = false;  // command line has been cleared
    mode_displayed = false;  // mode cleared or overwritten
  }
}

/// Clear the command line.
void msg_clr_cmdline(void)
{
  msg_row = cmdline_row;
  msg_col = 0;
  msg_clr_eos_force();
}

/// end putting a message on the screen
/// call wait_return() if the message does not fit in the available space
///
/// @return  true if wait_return() not called.
bool msg_end(void)
{
  // If the string is larger than the window,
  // or the ruler option is set and we run into it,
  // we have to redraw the window.
  // Do not do this if we are abandoning the file or editing the command line.
  if (!exiting && need_wait_return && !(State & MODE_CMDLINE)) {
    wait_return(false);
    return false;
  }

  // NOTE: ui_flush() used to be called here. This had to be removed, as it
  // inhibited substantial performance improvements. It is assumed that relevant
  // callers invoke ui_flush() before going into CPU busywork, or restricted
  // event processing after displaying a message to the user.
  msg_ext_ui_flush();
  return true;
}

/// Clear "msg_ext_chunks" before flushing so that ui_flush() does not re-emit
/// the same message recursively.
static Array *msg_ext_init_chunks(void)
{
  Array *tofree = msg_ext_chunks;
  msg_ext_chunks = xcalloc(1, sizeof(*msg_ext_chunks));
  msg_col = 0;
  return tofree;
}

void msg_ext_ui_flush(void)
{
  if (!ui_has(kUIMessages)) {
    msg_ext_kind = NULL;
    return;
  } else if (msg_ext_skip_flush) {
    return;
  }

  msg_ext_emit_chunk();
  if (msg_ext_chunks->size > 0) {
    Array *tofree = msg_ext_init_chunks();
    ui_call_msg_show(cstr_as_string(msg_ext_kind), *tofree, msg_ext_overwrite, msg_ext_history,
                     msg_ext_append);
    if (msg_ext_history) {
      api_free_array(*tofree);
    } else {
      // Add to history as temporary message for "g<".
      HlMessage msg = KV_INITIAL_VALUE;
      for (size_t i = 0; i < kv_size(*tofree); i++) {
        Object *chunk = kv_A(*tofree, i).data.array.items;
        kv_push(msg, ((HlMessageChunk){ chunk[1].data.string, (int)chunk[2].data.integer }));
        xfree(chunk);
      }
      xfree(tofree->items);
      msg_hist_add_multihl(msg, true);
    }
    xfree(tofree);
    msg_ext_overwrite = false;
    msg_ext_history = false;
    msg_ext_append = false;
    msg_ext_kind = NULL;
  }
}

void msg_ext_flush_showmode(void)
{
  // Showmode messages doesn't interrupt normal message flow, so we use
  // separate event. Still reuse the same chunking logic, for simplicity.
  // This is called unconditionally; check if we are emitting, or have
  // emitted non-empty "content".
  static bool clear = false;
  if (ui_has(kUIMessages) && (msg_ext_last_attr != -1 || clear)) {
    clear = msg_ext_last_attr != -1;
    msg_ext_emit_chunk();
    Array *tofree = msg_ext_init_chunks();
    ui_call_msg_showmode(*tofree);
    api_free_array(*tofree);
    xfree(tofree);
  }
}

/// If the written message runs into the shown command or ruler, we have to
/// wait for hit-return and redraw the window later.
void msg_check(void)
{
  if (ui_has(kUIMessages)) {
    return;
  }
  if (msg_row == Rows - 1 && msg_col >= sc_col) {
    need_wait_return = true;
    redraw_cmdline = true;
  }
}

/// May write a string to the redirection file.
///
/// @param maxlen  if -1, write the whole string, otherwise up to "maxlen" bytes.
static void redir_write(const char *const str, const ptrdiff_t maxlen)
{
  const char *s = str;
  static int cur_col = 0;

  if (maxlen == 0) {
    return;
  }

  // Don't do anything for displaying prompts and the like.
  if (redir_off) {
    return;
  }

  // If 'verbosefile' is set prepare for writing in that file.
  if (*p_vfile != NUL && verbose_fd == NULL) {
    verbose_open();
  }

  if (redirecting()) {
    // If the string doesn't start with CR or NL, go to msg_col
    if (*s != '\n' && *s != '\r') {
      while (cur_col < msg_col) {
        if (capture_ga) {
          ga_concat_len(capture_ga, " ", 1);
        }
        if (redir_reg) {
          write_reg_contents(redir_reg, " ", 1, true);
        } else if (redir_vname) {
          var_redir_str(" ", -1);
        } else if (redir_fd != NULL) {
          fputs(" ", redir_fd);
        }
        if (verbose_fd != NULL) {
          fputs(" ", verbose_fd);
        }
        cur_col++;
      }
    }

    size_t len = maxlen == -1 ? strlen(s) : (size_t)maxlen;
    if (capture_ga) {
      ga_concat_len(capture_ga, str, len);
    }
    if (redir_reg) {
      write_reg_contents(redir_reg, s, (ssize_t)len, true);
    }
    if (redir_vname) {
      var_redir_str(s, (int)maxlen);
    }

    // Write and adjust the current column.
    while (*s != NUL
           && (maxlen < 0 || (int)(s - str) < maxlen)) {
      if (!redir_reg && !redir_vname && !capture_ga) {
        if (redir_fd != NULL) {
          putc(*s, redir_fd);
        }
      }
      if (verbose_fd != NULL) {
        putc(*s, verbose_fd);
      }
      if (*s == '\r' || *s == '\n') {
        cur_col = 0;
      } else if (*s == '\t') {
        cur_col += (8 - cur_col % 8);
      } else {
        cur_col++;
      }
      s++;
    }

    if (msg_silent != 0) {      // should update msg_col
      msg_col = cur_col;
    }
  }
}

int redirecting(void)
{
  return redir_fd != NULL || *p_vfile != NUL
         || redir_reg || redir_vname || capture_ga != NULL;
}

// Save and restore message kind when emitting a verbose message.
static const char *pre_verbose_kind = NULL;
static const char *verbose_kind = "verbose";

/// Before giving verbose message.
/// Must always be called paired with verbose_leave()!
void verbose_enter(void)
{
  if (*p_vfile != NUL) {
    msg_silent++;
  }
  if (msg_ext_kind != verbose_kind) {
    pre_verbose_kind = msg_ext_kind;
  }
  msg_ext_set_kind("verbose");
}

/// After giving verbose message.
/// Must always be called paired with verbose_enter()!
void verbose_leave(void)
{
  if (*p_vfile != NUL) {
    if (--msg_silent < 0) {
      msg_silent = 0;
    }
  }
  if (pre_verbose_kind != NULL) {
    msg_ext_set_kind(pre_verbose_kind);
    pre_verbose_kind = NULL;
  }
}

/// Like verbose_enter() and set msg_scroll when displaying the message.
void verbose_enter_scroll(void)
{
  verbose_enter();
  if (*p_vfile == NUL) {
    // always scroll up, don't overwrite
    msg_scroll = true;
  }
}

/// Like verbose_leave() and set cmdline_row when displaying the message.
void verbose_leave_scroll(void)
{
  verbose_leave();
  if (*p_vfile == NUL) {
    cmdline_row = msg_row;
  }
}

/// Called when 'verbosefile' is set: stop writing to the file.
void verbose_stop(void)
{
  if (verbose_fd != NULL) {
    fclose(verbose_fd);
    verbose_fd = NULL;
  }
  verbose_did_open = false;
}

/// Open the file 'verbosefile'.
///
/// @return  FAIL or OK.
int verbose_open(void)
{
  if (verbose_fd == NULL && !verbose_did_open) {
    // Only give the error message once.
    verbose_did_open = true;

    verbose_fd = os_fopen(p_vfile, "a");
    if (verbose_fd == NULL) {
      semsg(_(e_notopen), p_vfile);
      return FAIL;
    }
  }
  return OK;
}

/// Give a warning message (for searching).
/// Use 'w' highlighting and may repeat the message after redrawing
void give_warning(const char *message, bool hl)
  FUNC_ATTR_NONNULL_ARG(1)
{
  // Don't do this for ":silent".
  if (msg_silent != 0) {
    return;
  }

  // Don't want a hit-enter prompt here.
  no_wait_return++;

  set_vim_var_string(VV_WARNINGMSG, message, -1);
  XFREE_CLEAR(keep_msg);
  if (hl) {
    keep_msg_hl_id = HLF_W;
  } else {
    keep_msg_hl_id = 0;
  }

  if (msg_ext_kind == NULL) {
    msg_ext_set_kind("wmsg");
  }

  if (msg(message, keep_msg_hl_id) && msg_scrolled == 0) {
    set_keep_msg(message, keep_msg_hl_id);
  }
  msg_didout = false;  // Overwrite this message.
  msg_nowait = true;   // Don't wait for this message.
  msg_col = 0;

  no_wait_return--;
}

/// Shows a warning, with optional highlighting.
///
/// @param hl enable highlighting
/// @param fmt printf-style format message
///
/// @see smsg
/// @see semsg
void swmsg(bool hl, const char *const fmt, ...)
  FUNC_ATTR_PRINTF(2, 3)
{
  va_list args;

  va_start(args, fmt);
  vim_vsnprintf(IObuff, IOSIZE, fmt, args);
  va_end(args);

  give_warning(IObuff, hl);
}

/// Advance msg cursor to column "col".
void msg_advance(int col)
{
  if (msg_silent != 0) {        // nothing to advance to
    msg_col = col;              // for redirection, may fill it up later
    return;
  }
  col = MIN(col, Columns - 1);  // not enough room
  while (msg_col < col) {
    msg_putchar(' ');
  }
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
        ins_char_typebuf(':', 0, false);
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
  snprintf(confirm_msg, (size_t)msg_len, "\n%s\n", message);

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

/// Display the ":confirm" message.  Also called when screen resized.
void display_confirm_msg(void)
{
  // Avoid that 'q' at the more prompt truncates the message here.
  confirm_msg_used++;
  if (confirm_msg != NULL) {
    msg_ext_set_kind("confirm");
    msg_puts_hl(confirm_msg, HLF_M, false);
  }
  confirm_msg_used--;
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

/// Check if there should be a delay to allow the user to see a message.
///
/// Used before clearing or redrawing the screen or the command line.
void msg_check_for_delay(bool check_msg_scroll)
{
  if ((emsg_on_display || (check_msg_scroll && msg_scroll))
      && !did_wait_return && emsg_silent == 0 && !in_assert_fails && !ui_has(kUIMessages)) {
    ui_flush();
    os_delay(1006, true);
    emsg_on_display = false;
    if (check_msg_scroll) {
      msg_scroll = false;
    }
  }
}
