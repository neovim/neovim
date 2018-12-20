// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * message.c: functions for displaying messages on the command line
 */

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdarg.h>
#include <string.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/assert.h"
#include "nvim/message.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_docmd.h"
#include "nvim/fileio.h"
#include "nvim/func_attr.h"
#include "nvim/getchar.h"
#include "nvim/main.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/misc1.h"
#include "nvim/keymap.h"
#include "nvim/garray.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/normal.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/strings.h"
#include "nvim/ui.h"
#include "nvim/mouse.h"
#include "nvim/os/os.h"
#include "nvim/os/input.h"
#include "nvim/os/time.h"

/*
 * To be able to scroll back at the "more" and "hit-enter" prompts we need to
 * store the displayed text and remember where screen lines start.
 */
typedef struct msgchunk_S msgchunk_T;
struct msgchunk_S {
  msgchunk_T  *sb_next;
  msgchunk_T  *sb_prev;
  char sb_eol;                  /* TRUE when line ends after this text */
  int sb_msg_col;               /* column in which text starts */
  int sb_attr;                  /* text attributes */
  char_u sb_text[1];            /* text to be displayed, actually longer */
};

/* Magic chars used in confirm dialog strings */
#define DLG_BUTTON_SEP  '\n'
#define DLG_HOTKEY_CHAR '&'

static int confirm_msg_used = FALSE;            /* displaying confirm_msg */
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "message.c.generated.h"
#endif
static char_u   *confirm_msg = NULL;            /* ":confirm" message */
static char_u   *confirm_msg_tail;              /* tail of confirm_msg */

MessageHistoryEntry *first_msg_hist = NULL;
MessageHistoryEntry *last_msg_hist = NULL;
static int msg_hist_len = 0;

static FILE *verbose_fd = NULL;
static int verbose_did_open = FALSE;

/*
 * When writing messages to the screen, there are many different situations.
 * A number of variables is used to remember the current state:
 * msg_didany	    TRUE when messages were written since the last time the
 *		    user reacted to a prompt.
 *		    Reset: After hitting a key for the hit-return prompt,
 *		    hitting <CR> for the command line or input().
 *		    Set: When any message is written to the screen.
 * msg_didout	    TRUE when something was written to the current line.
 *		    Reset: When advancing to the next line, when the current
 *		    text can be overwritten.
 *		    Set: When any message is written to the screen.
 * msg_nowait	    No extra delay for the last drawn message.
 *		    Used in normal_cmd() before the mode message is drawn.
 * emsg_on_display  There was an error message recently.  Indicates that there
 *		    should be a delay before redrawing.
 * msg_scroll	    The next message should not overwrite the current one.
 * msg_scrolled	    How many lines the screen has been scrolled (because of
 *		    messages).  Used in update_screen() to scroll the screen
 *		    back.  Incremented each time the screen scrolls a line.
 * msg_scrolled_ign  TRUE when msg_scrolled is non-zero and msg_puts_attr()
 *		    writes something without scrolling should not make
 *		    need_wait_return to be set.  This is a hack to make ":ts"
 *		    work without an extra prompt.
 * lines_left	    Number of lines available for messages before the
 *		    more-prompt is to be given.  -1 when not set.
 * need_wait_return TRUE when the hit-return prompt is needed.
 *		    Reset: After giving the hit-return prompt, when the user
 *		    has answered some other prompt.
 *		    Set: When the ruler or typeahead display is overwritten,
 *		    scrolling the screen for some message.
 * keep_msg	    Message to be displayed after redrawing the screen, in
 *		    main_loop().
 *		    This is an allocated string or NULL when not used.
 */

/*
 * msg(s) - displays the string 's' on the status line
 * When terminal not initialized (yet) mch_errmsg(..) is used.
 * return TRUE if wait_return not called
 */
int msg(char_u *s)
{
  return msg_attr_keep(s, 0, FALSE);
}

/*
 * Like msg() but keep it silent when 'verbosefile' is set.
 */
int verb_msg(char_u *s)
{
  int n;

  verbose_enter();
  n = msg_attr_keep(s, 0, FALSE);
  verbose_leave();

  return n;
}

int msg_attr(const char *s, const int attr) FUNC_ATTR_NONNULL_ARG(1)
{
  return msg_attr_keep((char_u *)s, attr, false);
}

int
msg_attr_keep (
    char_u *s,
    int attr,
    int keep                   /* TRUE: set keep_msg if it doesn't scroll */
)
  FUNC_ATTR_NONNULL_ARG(1)
{
  static int entered = 0;
  int retval;
  char_u *buf = NULL;

  // Skip messages not match ":filter pattern".
  // Don't filter when there is an error.
  if (!emsg_on_display && message_filtered(s)) {
    return true;
  }

  if (attr == 0) {
    set_vim_var_string(VV_STATUSMSG, (char *) s, -1);
  }

  /*
   * It is possible that displaying a messages causes a problem (e.g.,
   * when redrawing the window), which causes another message, etc..	To
   * break this loop, limit the recursiveness to 3 levels.
   */
  if (entered >= 3)
    return TRUE;
  ++entered;

  /* Add message to history (unless it's a repeated kept message or a
   * truncated message) */
  if (s != keep_msg
      || (*s != '<'
          && last_msg_hist != NULL
          && last_msg_hist->msg != NULL
          && STRCMP(s, last_msg_hist->msg))) {
    add_msg_hist((const char *)s, -1, attr);
  }

  /* When displaying keep_msg, don't let msg_start() free it, caller must do
   * that. */
  if (s == keep_msg)
    keep_msg = NULL;

  /* Truncate the message if needed. */
  msg_start();
  buf = msg_strtrunc(s, FALSE);
  if (buf != NULL)
    s = buf;

  msg_outtrans_attr(s, attr);
  msg_clr_eos();
  retval = msg_end();

  if (keep && retval && vim_strsize(s) < (int)(Rows - cmdline_row - 1)
      * Columns + sc_col)
    set_keep_msg(s, 0);

  xfree(buf);
  --entered;
  return retval;
}

/*
 * Truncate a string such that it can be printed without causing a scroll.
 * Returns an allocated string or NULL when no truncating is done.
 */
char_u *
msg_strtrunc (
    char_u *s,
    int force                  /* always truncate */
)
{
  char_u      *buf = NULL;
  int len;
  int room;

  /* May truncate message to avoid a hit-return prompt */
  if ((!msg_scroll && !need_wait_return && shortmess(SHM_TRUNCALL)
       && !exmode_active && msg_silent == 0) || force) {
    len = vim_strsize(s);
    if (msg_scrolled != 0)
      /* Use all the columns. */
      room = (int)(Rows - msg_row) * Columns - 1;
    else
      /* Use up to 'showcmd' column. */
      room = (int)(Rows - msg_row - 1) * Columns + sc_col - 1;
    if (len > room && room > 0) {
      if (enc_utf8)
        /* may have up to 18 bytes per cell (6 per char, up to two
         * composing chars) */
        len = (room + 2) * 18;
      else if (enc_dbcs == DBCS_JPNU)
        /* may have up to 2 bytes per cell for euc-jp */
        len = (room + 2) * 2;
      else
        len = room + 2;
      buf = xmalloc(len);
      trunc_string(s, buf, room, len);
    }
  }
  return buf;
}

/*
 * Truncate a string "s" to "buf" with cell width "room".
 * "s" and "buf" may be equal.
 */
void trunc_string(char_u *s, char_u *buf, int room_in, int buflen)
{
  size_t room = room_in - 3;  // "..." takes 3 chars
  size_t half;
  size_t len = 0;
  int e;
  int i;
  int n;

  if (room_in < 3) {
    room = 0;
  }
  half = room / 2;

  /* First part: Start of the string. */
  for (e = 0; len < half && e < buflen; ++e) {
    if (s[e] == NUL) {
      /* text fits without truncating! */
      buf[e] = NUL;
      return;
    }
    n = ptr2cells(s + e);
    if (len + n > half) {
      break;
    }
    len += n;
    buf[e] = s[e];
    if (has_mbyte)
      for (n = (*mb_ptr2len)(s + e); --n > 0; ) {
        if (++e == buflen)
          break;
        buf[e] = s[e];
      }
  }

  // Last part: End of the string.
  half = i = (int)STRLEN(s);
  for (;;) {
    do {
      half = half - utf_head_off(s, s + half - 1) - 1;
    } while (half > 0 && utf_iscomposing(utf_ptr2char(s + half)));
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
      len = STRLEN(s);
      if (len >= (size_t)buflen) {
        len = buflen - 1;
      }
      len = len - e + 1;
      if (len < 1) {
        buf[e - 1] = NUL;
      } else {
        memmove(buf + e, s + e, len);
      }
    }
  } else if (e + 3 < buflen) {
    // set the middle and copy the last part
    memmove(buf + e, "...", (size_t)3);
    len = STRLEN(s + i) + 1;
    if (len >= (size_t)buflen - e - 3) {
      len = buflen - e - 3 - 1;
    }
    memmove(buf + e + 3, s + i, len);
    buf[e + 3 + len - 1] = NUL;
  } else {
    // can't fit in the "...", just truncate it
    buf[e - 1] = NUL;
  }
}

/*
 * Note: Caller of smgs() and smsg_attr() must check the resulting string is
 * shorter than IOSIZE!!!
 */

int smsg(char *s, ...)
  FUNC_ATTR_PRINTF(1, 2)
{
  va_list arglist;

  va_start(arglist, s);
  vim_vsnprintf((char *)IObuff, IOSIZE, s, arglist, NULL);
  va_end(arglist);
  return msg(IObuff);
}

int smsg_attr(int attr, char *s, ...)
  FUNC_ATTR_PRINTF(2, 3)
{
  va_list arglist;

  va_start(arglist, s);
  vim_vsnprintf((char *)IObuff, IOSIZE, s, arglist, NULL);
  va_end(arglist);
  return msg_attr((const char *)IObuff, attr);
}

/*
 * Remember the last sourcing name/lnum used in an error message, so that it
 * isn't printed each time when it didn't change.
 */
static int last_sourcing_lnum = 0;
static char_u   *last_sourcing_name = NULL;

/*
 * Reset the last used sourcing name/lnum.  Makes sure it is displayed again
 * for the next error message;
 */
void reset_last_sourcing(void)
{
  xfree(last_sourcing_name);
  last_sourcing_name = NULL;
  last_sourcing_lnum = 0;
}

/*
 * Return TRUE if "sourcing_name" differs from "last_sourcing_name".
 */
static int other_sourcing_name(void)
{
  if (sourcing_name != NULL) {
    if (last_sourcing_name != NULL)
      return STRCMP(sourcing_name, last_sourcing_name) != 0;
    return TRUE;
  }
  return FALSE;
}

/// Get the message about the source, as used for an error message
///
/// @return [allocated] String with room for one more character. NULL when no
///                     message is to be given.
static char *get_emsg_source(void)
  FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (sourcing_name != NULL && other_sourcing_name()) {
    const char *const p = _("Error detected while processing %s:");
    const size_t buf_len = STRLEN(sourcing_name) + strlen(p) + 1;
    char *const buf = xmalloc(buf_len);
    snprintf(buf, buf_len, p, sourcing_name);
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
  if (sourcing_name != NULL
      && (other_sourcing_name() || sourcing_lnum != last_sourcing_lnum)
      && sourcing_lnum != 0) {
    const char *const p = _("line %4ld:");
    const size_t buf_len = 20 + strlen(p);
    char *const buf = xmalloc(buf_len);
    snprintf(buf, buf_len, p, (long)sourcing_lnum);
    return buf;
  }
  return NULL;
}

/*
 * Display name and line number for the source of an error.
 * Remember the file name and line number, so that for the next error the info
 * is only displayed if it changed.
 */
void msg_source(int attr)
{
  no_wait_return++;
  char *p = get_emsg_source();
  if (p != NULL) {
    msg_attr(p, attr);
    xfree(p);
  }
  p = get_emsg_lnum();
  if (p != NULL) {
    msg_attr(p, HL_ATTR(HLF_N));
    xfree(p);
    last_sourcing_lnum = sourcing_lnum;      /* only once for each line */
  }

  /* remember the last sourcing name printed, also when it's empty */
  if (sourcing_name == NULL || other_sourcing_name()) {
    xfree(last_sourcing_name);
    if (sourcing_name == NULL)
      last_sourcing_name = NULL;
    else
      last_sourcing_name = vim_strsave(sourcing_name);
  }
  --no_wait_return;
}

/*
 * Return TRUE if not giving error messages right now:
 * If "emsg_off" is set: no error messages at the moment.
 * If "msg" is in 'debug': do error message but without side effects.
 * If "emsg_skip" is set: never do error messages.
 */
int emsg_not_now(void)
{
  if ((emsg_off > 0 && vim_strchr(p_debug, 'm') == NULL
       && vim_strchr(p_debug, 't') == NULL)
      || emsg_skip > 0
      )
    return TRUE;
  return FALSE;
}

/*
 * emsg() - display an error message
 *
 * Rings the bell, if appropriate, and calls message() to do the real work
 * When terminal not initialized (yet) mch_errmsg(..) is used.
 *
 * return TRUE if wait_return not called
 */
int emsg(const char_u *s_)
{
  const char *s = (const char *)s_;
  int attr;
  int ignore = false;
  int severe;

  // Skip this if not giving error messages at the moment.
  if (emsg_not_now()) {
    return true;
  }

  called_emsg = true;

  // If "emsg_severe" is TRUE: When an error exception is to be thrown,
  // prefer this message over previous messages for the same command.
  severe = emsg_severe;
  emsg_severe = false;

  if (!emsg_off || vim_strchr(p_debug, 't') != NULL) {
    /*
     * Cause a throw of an error exception if appropriate.  Don't display
     * the error message in this case.  (If no matching catch clause will
     * be found, the message will be displayed later on.)  "ignore" is set
     * when the message should be ignored completely (used for the
     * interrupt message).
     */
    if (cause_errthrow((char_u *)s, severe, &ignore) == true) {
      if (!ignore) {
        did_emsg++;
      }
      return true;
    }

    // set "v:errmsg", also when using ":silent! cmd"
    set_vim_var_string(VV_ERRMSG, s, -1);

    /*
     * When using ":silent! cmd" ignore error messages.
     * But do write it to the redirection file.
     */
    if (emsg_silent != 0) {
      if (!emsg_noredir) {
        msg_start();
        char *p = get_emsg_source();
        if (p != NULL) {
          const size_t p_len = strlen(p);
          p[p_len] = '\n';
          redir_write(p, p_len + 1);
          xfree(p);
        }
        p = get_emsg_lnum();
        if (p != NULL) {
          const size_t p_len = strlen(p);
          p[p_len] = '\n';
          redir_write(p, p_len + 1);
          xfree(p);
        }
        redir_write(s, strlen(s));
      }
      return true;
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
  msg_scroll++;               // don't overwrite a previous message
  attr = HL_ATTR(HLF_E);      // set highlight mode for error messages
  if (msg_scrolled != 0) {
    need_wait_return = true;  // needed in case emsg() is called after
  }                           // wait_return has reset need_wait_return
                              // and a redraw is expected because
                              // msg_scrolled is non-zero

  /*
   * Display name and line number for the source of the error.
   */
  msg_source(attr);

  // Display the error message itself.
  msg_nowait = false;  // Wait for this msg.
  return msg_attr(s, attr);
}

void emsg_invreg(int name)
{
  EMSG2(_("E354: Invalid register name: '%s'"), transchar(name));
}

/// Print an error message with unknown number of arguments
bool emsgf(const char *const fmt, ...)
  FUNC_ATTR_PRINTF(1, 2)
{
  bool ret;

  va_list ap;
  va_start(ap, fmt);
  ret = emsgfv(fmt, ap);
  va_end(ap);

  return ret;
}

/// Print an error message with unknown number of arguments
static bool emsgfv(const char *fmt, va_list ap)
{
  static char errbuf[IOSIZE];
  if (emsg_not_now()) {
    return true;
  }

  vim_vsnprintf(errbuf, sizeof(errbuf), fmt, ap, NULL);

  return emsg((const char_u *)errbuf);
}

/// Same as emsg(...), but abort on error when ABORT_ON_INTERNAL_ERROR is
/// defined. It is used for internal errors only, so that they can be
/// detected when fuzzing vim.
void iemsg(const char *s)
{
    emsg((char_u *)s);
#ifdef ABORT_ON_INTERNAL_ERROR
    abort();
#endif
}

/// Same as emsgf(...) but abort on error when ABORT_ON_INTERNAL_ERROR is
/// defined. It is used for internal errors only, so that they can be
/// detected when fuzzing vim.
void iemsgf(const char *s, ...)
{
    va_list ap;
    va_start(ap, s);
    (void)emsgfv(s, ap);
    va_end(ap);
#ifdef ABORT_ON_INTERNAL_ERROR
    abort();
#endif
}

/// Give an "Internal error" message.
void internal_error(char *where)
{
    IEMSG2(_(e_intern2), where);
}

static void msg_emsgf_event(void **argv)
{
  char *s = argv[0];
  (void)emsg((char_u *)s);
  xfree(s);
}

void msg_schedule_emsgf(const char *const fmt, ...)
  FUNC_ATTR_PRINTF(1, 2)
{
  va_list ap;
  va_start(ap, fmt);
  vim_vsnprintf((char *)IObuff, IOSIZE, fmt, ap, NULL);
  va_end(ap);

  char *s = xstrdup((char *)IObuff);
  loop_schedule(&main_loop, event_create(msg_emsgf_event, 1, s));
}

/*
 * Like msg(), but truncate to a single line if p_shm contains 't', or when
 * "force" is TRUE.  This truncates in another way as for normal messages.
 * Careful: The string may be changed by msg_may_trunc()!
 * Returns a pointer to the printed message, if wait_return() not called.
 */
char_u *msg_trunc_attr(char_u *s, int force, int attr)
{
  int n;

  // Add message to history before truncating.
  add_msg_hist((const char *)s, -1, attr);

  s = msg_may_trunc(force, s);

  msg_hist_off = true;
  n = msg_attr((const char *)s, attr);
  msg_hist_off = false;

  if (n)
    return s;
  return NULL;
}

/*
 * Check if message "s" should be truncated at the start (for filenames).
 * Return a pointer to where the truncated message starts.
 * Note: May change the message by replacing a character with '<'.
 */
char_u *msg_may_trunc(int force, char_u *s)
{
  int n;
  int room;

  room = (int)(Rows - cmdline_row - 1) * Columns + sc_col - 1;
  if ((force || (shortmess(SHM_TRUNC) && !exmode_active))
      && (n = (int)STRLEN(s) - room) > 0) {
    if (has_mbyte) {
      int size = vim_strsize(s);

      /* There may be room anyway when there are multibyte chars. */
      if (size <= room)
        return s;

      for (n = 0; size >= room; ) {
        size -= utf_ptr2cells(s + n);
        n += utfc_ptr2len(s + n);
      }
      --n;
    }
    s += n;
    *s = '<';
  }
  return s;
}

/// @param[in]  len  Length of s or -1.
static void add_msg_hist(const char *s, int len, int attr)
{
  if (msg_hist_off || msg_silent != 0)
    return;

  /* Don't let the message history get too big */
  while (msg_hist_len > MAX_MSG_HIST_LEN)
    (void)delete_first_msg();

  /* allocate an entry and add the message at the end of the history */
  struct msg_hist *p = xmalloc(sizeof(struct msg_hist));
  if (len < 0)
    len = (int)STRLEN(s);
  /* remove leading and trailing newlines */
  while (len > 0 && *s == '\n') {
    ++s;
    --len;
  }
  while (len > 0 && s[len - 1] == '\n') {
    len--;
  }
  p->msg = (char_u *)xmemdupz(s, (size_t)len);
  p->next = NULL;
  p->attr = attr;
  if (last_msg_hist != NULL)
    last_msg_hist->next = p;
  last_msg_hist = p;
  if (first_msg_hist == NULL)
    first_msg_hist = last_msg_hist;
  ++msg_hist_len;
}

/*
 * Delete the first (oldest) message from the history.
 * Returns FAIL if there are no messages.
 */
int delete_first_msg(void)
{
  struct msg_hist *p;

  if (msg_hist_len <= 0)
    return FAIL;
  p = first_msg_hist;
  first_msg_hist = p->next;
  if (first_msg_hist == NULL) {  /* history is becoming empty */
    assert(msg_hist_len == 1);
    last_msg_hist = NULL;
  }
  xfree(p->msg);
  xfree(p);
  --msg_hist_len;
  return OK;
}

/// :messages command implementation
void ex_messages(void *const eap_p)
  FUNC_ATTR_NONNULL_ALL
{
  const exarg_T *const eap = (const exarg_T *)eap_p;
  struct msg_hist *p;
  int c = 0;

  if (STRCMP(eap->arg, "clear") == 0) {
    int keep = eap->addr_count == 0 ? 0 : eap->line2;

    while (msg_hist_len > keep) {
      (void)delete_first_msg();
    }
    return;
  }

  if (*eap->arg != NUL) {
    EMSG(_(e_invarg));
    return;
  }

  msg_hist_off = true;

  p = first_msg_hist;

  if (eap->addr_count != 0) {
    // Count total messages
    for (; p != NULL && !got_int; p = p->next) {
      c++;
    }

    c -= eap->line2;

    // Skip without number of messages specified
    for (p = first_msg_hist; p != NULL && !got_int && c > 0; p = p->next, c--) {
    }
  }

  // Display what was not skipped.
  for (; p != NULL && !got_int; p = p->next) {
    if (p->msg != NULL) {
      msg_attr((const char *)p->msg, p->attr);
    }
  }

  msg_hist_off = false;
}

/*
 * Call this after prompting the user.  This will avoid a hit-return message
 * and a delay.
 */
void msg_end_prompt(void)
{
  need_wait_return = FALSE;
  emsg_on_display = FALSE;
  cmdline_row = msg_row;
  msg_col = 0;
  msg_clr_eos();
  lines_left = -1;
}

/// wait for the user to hit a key (normally a return)
///
/// if 'redraw' is true, redraw the entire screen NOT_VALID
/// if 'redraw' is false, do a normal redraw
/// if 'redraw' is -1, don't redraw at all
void wait_return(int redraw)
{
  int c;
  int oldState;
  int tmpState;
  int had_got_int;
  int save_Recording;
  FILE        *save_scriptout;

  if (redraw == true) {
    redraw_all_later(NOT_VALID);
  }

  /* If using ":silent cmd", don't wait for a return.  Also don't set
   * need_wait_return to do it later. */
  if (msg_silent != 0)
    return;

  /*
   * When inside vgetc(), we can't wait for a typed character at all.
   * With the global command (and some others) we only need one return at
   * the end. Adjust cmdline_row to avoid the next message overwriting the
   * last one.
   */
  if (vgetc_busy > 0)
    return;
  need_wait_return = TRUE;
  if (no_wait_return) {
    if (!exmode_active)
      cmdline_row = msg_row;
    return;
  }

  redir_off = TRUE;             /* don't redirect this message */
  oldState = State;
  if (quit_more) {
    c = CAR;                    /* just pretend CR was hit */
    quit_more = FALSE;
    got_int = FALSE;
  } else if (exmode_active) {
    MSG_PUTS(" ");              /* make sure the cursor is on the right line */
    c = CAR;                    /* no need for a return in ex mode */
    got_int = FALSE;
  } else {
    /* Make sure the hit-return prompt is on screen when 'guioptions' was
     * just changed. */
    screenalloc(false);

    State = HITRETURN;
    setmouse();
    cmdline_row = msg_row;
    // Avoid the sequence that the user types ":" at the hit-return prompt
    // to start an Ex command, but the file-changed dialog gets in the
    // way.
    if (need_check_timestamps) {
      check_timestamps(false);
    }

    hit_return_msg();

    do {
      /* Remember "got_int", if it is set vgetc() probably returns a
       * CTRL-C, but we need to loop then. */
      had_got_int = got_int;

      // Don't do mappings here, we put the character back in the
      // typeahead buffer.
      no_mapping++;

      // Temporarily disable Recording. If Recording is active, the
      // character will be recorded later, since it will be added to the
      // typebuf after the loop
      save_Recording = Recording;
      save_scriptout = scriptout;
      Recording = FALSE;
      scriptout = NULL;
      c = safe_vgetc();
      if (had_got_int && !global_busy) {
        got_int = false;
      }
      no_mapping--;
      Recording = save_Recording;
      scriptout = save_scriptout;


      /*
       * Allow scrolling back in the messages.
       * Also accept scroll-down commands when messages fill the screen,
       * to avoid that typing one 'j' too many makes the messages
       * disappear.
       */
      if (p_more) {
        if (c == 'b' || c == 'k' || c == 'u' || c == 'g'
            || c == K_UP || c == K_PAGEUP) {
          if (msg_scrolled > Rows)
            /* scroll back to show older messages */
            do_more_prompt(c);
          else {
            msg_didout = FALSE;
            c = K_IGNORE;
            msg_col =
              cmdmsg_rl ? Columns - 1 :
              0;
          }
          if (quit_more) {
            c = CAR;                            /* just pretend CR was hit */
            quit_more = FALSE;
            got_int = FALSE;
          } else if (c != K_IGNORE) {
            c = K_IGNORE;
            hit_return_msg();
          }
        } else if (msg_scrolled > Rows - 2
                   && (c == 'j' || c == 'd' || c == 'f'
                       || c == K_DOWN || c == K_PAGEDOWN))
          c = K_IGNORE;
      }
    } while ((had_got_int && c == Ctrl_C)
             || c == K_IGNORE
             || c == K_LEFTDRAG   || c == K_LEFTRELEASE
             || c == K_MIDDLEDRAG || c == K_MIDDLERELEASE
             || c == K_RIGHTDRAG  || c == K_RIGHTRELEASE
             || c == K_MOUSELEFT  || c == K_MOUSERIGHT
             || c == K_MOUSEDOWN  || c == K_MOUSEUP
             || (!mouse_has(MOUSE_RETURN)
                 && mouse_row < msg_row
                 && (c == K_LEFTMOUSE
                     || c == K_MIDDLEMOUSE
                     || c == K_RIGHTMOUSE
                     || c == K_X1MOUSE
                     || c == K_X2MOUSE))
             );
    os_breakcheck();
    /*
     * Avoid that the mouse-up event causes visual mode to start.
     */
    if (c == K_LEFTMOUSE || c == K_MIDDLEMOUSE || c == K_RIGHTMOUSE
        || c == K_X1MOUSE || c == K_X2MOUSE)
      (void)jump_to_mouse(MOUSE_SETPOS, NULL, 0);
    else if (vim_strchr((char_u *)"\r\n ", c) == NULL && c != Ctrl_C) {
      /* Put the character back in the typeahead buffer.  Don't use the
       * stuff buffer, because lmaps wouldn't work. */
      ins_char_typebuf(c);
      do_redraw = TRUE;             /* need a redraw even though there is
                                       typeahead */
    }
  }
  redir_off = FALSE;

  /*
   * If the user hits ':', '?' or '/' we get a command line from the next
   * line.
   */
  if (c == ':' || c == '?' || c == '/') {
    if (!exmode_active)
      cmdline_row = msg_row;
    skip_redraw = TRUE;             /* skip redraw once */
    do_redraw = FALSE;
  }

  /*
   * If the window size changed set_shellsize() will redraw the screen.
   * Otherwise the screen is only redrawn if 'redraw' is set and no ':'
   * typed.
   */
  tmpState = State;
  State = oldState;                 /* restore State before set_shellsize */
  setmouse();
  msg_check();
  need_wait_return = FALSE;
  did_wait_return = TRUE;
  emsg_on_display = FALSE;      /* can delete error message now */
  lines_left = -1;              /* reset lines_left at next msg_start() */
  reset_last_sourcing();
  if (keep_msg != NULL && vim_strsize(keep_msg) >=
      (Rows - cmdline_row - 1) * Columns + sc_col) {
    xfree(keep_msg);
    keep_msg = NULL;                /* don't redisplay message, it's too long */
  }

  if (tmpState == SETWSIZE) {       /* got resize event while in vgetc() */
    ui_refresh();
  } else if (!skip_redraw
             && (redraw == TRUE || (msg_scrolled != 0 && redraw != -1))) {
    redraw_later(VALID);
  }
}

/*
 * Write the hit-return prompt.
 */
static void hit_return_msg(void)
{
  int save_p_more = p_more;

  p_more = FALSE;       /* don't want see this message when scrolling back */
  if (msg_didout)       /* start on a new line */
    msg_putchar('\n');
  if (got_int)
    MSG_PUTS(_("Interrupt: "));

  MSG_PUTS_ATTR(_("Press ENTER or type command to continue"), HL_ATTR(HLF_R));
  if (!msg_use_printf()) {
    msg_clr_eos();
  }
  p_more = save_p_more;
}

/*
 * Set "keep_msg" to "s".  Free the old value and check for NULL pointer.
 */
void set_keep_msg(char_u *s, int attr)
{
  xfree(keep_msg);
  if (s != NULL && msg_silent == 0)
    keep_msg = vim_strsave(s);
  else
    keep_msg = NULL;
  keep_msg_more = FALSE;
  keep_msg_attr = attr;
}

/*
 * Prepare for outputting characters in the command line.
 */
void msg_start(void)
{
  int did_return = FALSE;

  if (!msg_silent) {
    xfree(keep_msg);
    keep_msg = NULL;                    /* don't display old message now */
  }

  if (need_clr_eos) {
    /* Halfway an ":echo" command and getting an (error) message: clear
     * any text from the command. */
    need_clr_eos = FALSE;
    msg_clr_eos();
  }

  if (!msg_scroll && full_screen) {     /* overwrite last message */
    msg_row = cmdline_row;
    msg_col =
      cmdmsg_rl ? Columns - 1 :
      0;
  } else if (msg_didout) {                /* start message on next line */
    msg_putchar('\n');
    did_return = TRUE;
    if (exmode_active != EXMODE_NORMAL)
      cmdline_row = msg_row;
  }
  if (!msg_didany || lines_left < 0)
    msg_starthere();
  if (msg_silent == 0) {
    msg_didout = FALSE;                     /* no output on current line yet */
  }

  // When redirecting, may need to start a new line.
  if (!did_return) {
    redir_write("\n", 1);
  }
}

/*
 * Note that the current msg position is where messages start.
 */
void msg_starthere(void)
{
  lines_left = cmdline_row;
  msg_didany = FALSE;
}

void msg_putchar(int c)
{
  msg_putchar_attr(c, 0);
}

void msg_putchar_attr(int c, int attr)
{
  char buf[MB_MAXBYTES + 1];

  if (IS_SPECIAL(c)) {
    buf[0] = (char)K_SPECIAL;
    buf[1] = (char)K_SECOND(c);
    buf[2] = (char)K_THIRD(c);
    buf[3] = NUL;
  } else {
    buf[utf_char2bytes(c, (char_u *)buf)] = NUL;
  }
  msg_puts_attr(buf, attr);
}

void msg_outnum(long n)
{
  char buf[20];

  snprintf(buf, sizeof(buf), "%ld", n);
  msg_puts(buf);
}

void msg_home_replace(char_u *fname)
{
  msg_home_replace_attr(fname, 0);
}

void msg_home_replace_hl(char_u *fname)
{
  msg_home_replace_attr(fname, HL_ATTR(HLF_D));
}

static void msg_home_replace_attr(char_u *fname, int attr)
{
  char_u      *name;

  name = home_replace_save(NULL, fname);
  msg_outtrans_attr(name, attr);
  xfree(name);
}

/*
 * Output 'len' characters in 'str' (including NULs) with translation
 * if 'len' is -1, output upto a NUL character.
 * Use attributes 'attr'.
 * Return the number of characters it takes on the screen.
 */
int msg_outtrans(char_u *str)
{
  return msg_outtrans_attr(str, 0);
}

int msg_outtrans_attr(char_u *str, int attr)
{
  return msg_outtrans_len_attr(str, (int)STRLEN(str), attr);
}

int msg_outtrans_len(char_u *str, int len)
{
  return msg_outtrans_len_attr(str, len, 0);
}

/*
 * Output one character at "p".  Return pointer to the next character.
 * Handles multi-byte characters.
 */
char_u *msg_outtrans_one(char_u *p, int attr)
{
  int l;

  if (has_mbyte && (l = (*mb_ptr2len)(p)) > 1) {
    msg_outtrans_len_attr(p, l, attr);
    return p + l;
  }
  msg_puts_attr((const char *)transchar_byte(*p), attr);
  return p + 1;
}

int msg_outtrans_len_attr(char_u *msgstr, int len, int attr)
{
  int retval = 0;
  const char *str = (const char *)msgstr;
  const char *plain_start = (const char *)msgstr;
  char_u *s;
  int mb_l;
  int c;

  /* if MSG_HIST flag set, add message to history */
  if (attr & MSG_HIST) {
    add_msg_hist(str, len, attr);
    attr &= ~MSG_HIST;
  }

  // If the string starts with a composing character first draw a space on
  // which the composing char can be drawn.
  if (enc_utf8 && utf_iscomposing(utf_ptr2char(msgstr))) {
    msg_puts_attr(" ", attr);
  }

  /*
   * Go over the string.  Special characters are translated and printed.
   * Normal characters are printed several at a time.
   */
  while (--len >= 0) {
    // Don't include composing chars after the end.
    mb_l = utfc_ptr2len_len((char_u *)str, len + 1);
    if (mb_l > 1) {
      c = utf_ptr2char((char_u *)str);
      if (vim_isprintc(c)) {
        // Printable multi-byte char: count the cells.
        retval += utf_ptr2cells((char_u *)str);
      } else {
        // Unprintable multi-byte char: print the printable chars so
        // far and the translation of the unprintable char.
        if (str > plain_start) {
          msg_puts_attr_len(plain_start, str - plain_start, attr);
        }
        plain_start = str + mb_l;
        msg_puts_attr((const char *)transchar(c),
                      (attr == 0 ? HL_ATTR(HLF_8) : attr));
        retval += char2cells(c);
      }
      len -= mb_l - 1;
      str += mb_l;
    } else {
      s = transchar_byte((uint8_t)(*str));
      if (s[1] != NUL) {
        // Unprintable char: print the printable chars so far and the
        // translation of the unprintable char.
        if (str > plain_start) {
          msg_puts_attr_len(plain_start, str - plain_start, attr);
        }
        plain_start = str + 1;
        msg_puts_attr((const char *)s, attr == 0 ? HL_ATTR(HLF_8) : attr);
        retval += (int)STRLEN(s);
      } else {
        retval++;
      }
      str++;
    }
  }

  if (str > plain_start) {
    // Print the printable chars at the end.
    msg_puts_attr_len(plain_start, str - plain_start, attr);
  }

  return retval;
}

void msg_make(char_u *arg)
{
  int i;
  static char_u *str = (char_u *)"eeffoc", *rs = (char_u *)"Plon#dqg#vxjduB";

  arg = skipwhite(arg);
  for (i = 5; *arg && i >= 0; --i)
    if (*arg++ != str[i])
      break;
  if (i < 0) {
    msg_putchar('\n');
    for (i = 0; rs[i]; ++i)
      msg_putchar(rs[i] - 3);
  }
}

/// Output the string 'str' upto a NUL character.
/// Return the number of characters it takes on the screen.
///
/// If K_SPECIAL is encountered, then it is taken in conjunction with the
/// following character and shown as <F1>, <S-Up> etc.  Any other character
/// which is not printable shown in <> form.
/// If 'from' is TRUE (lhs of a mapping), a space is shown as <Space>.
/// If a character is displayed in one of these special ways, is also
/// highlighted (its highlight name is '8' in the p_hl variable).
/// Otherwise characters are not highlighted.
/// This function is used to show mappings, where we want to see how to type
/// the character/string -- webb
int msg_outtrans_special(
    const char_u *strstart,
    int from               ///< true for LHS of a mapping
)
{
  if (strstart == NULL) {
    return 0;  // Do nothing.
  }
  const char_u *str = strstart;
  int retval = 0;
  int attr = HL_ATTR(HLF_8);

  while (*str != NUL) {
    const char *string;
    // Leading and trailing spaces need to be displayed in <> form.
    if ((str == strstart || str[1] == NUL) && *str == ' ') {
      string = "<Space>";
      str++;
    } else {
      string = str2special((const char **)&str, from, false);
    }
    const int len = vim_strsize((char_u *)string);
    // Highlight special keys
    msg_puts_attr(string, (len > 1
                           && (*mb_ptr2len)((char_u *)string) <= 1
                           ? attr : 0));
    retval += len;
  }
  return retval;
}

/// Convert string, replacing key codes with printables
///
/// Used for lhs or rhs of mappings.
///
/// @param[in]  str  String to convert.
/// @param[in]  replace_spaces  Convert spaces into `<Space>`, normally used fo
///                             lhs, but not rhs.
/// @param[in]  replace_lt  Convert `<` into `<lt>`.
///
/// @return [allocated] Converted string.
char *str2special_save(const char *const str, const bool replace_spaces,
                       const bool replace_lt)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_MALLOC
  FUNC_ATTR_NONNULL_RET
{
  garray_T ga;
  ga_init(&ga, 1, 40);

  const char *p = str;
  while (*p != NUL) {
    ga_concat(&ga, (const char_u *)str2special(&p, replace_spaces, replace_lt));
  }
  ga_append(&ga, NUL);
  return (char *)ga.ga_data;
}

/// Convert character, replacing key with printable representation.
///
/// @param[in,out]  sp  String to convert. Is advanced to the next key code.
/// @param[in]  replace_spaces  Convert spaces into <Space>, normally used for
///                             lhs, but not rhs.
/// @param[in]  replace_lt  Convert `<` into `<lt>`.
///
/// @return Converted key code, in a static buffer. Buffer is always one and the
///         same, so save converted string somewhere before running str2special
///         for the second time.
const char *str2special(const char **const sp, const bool replace_spaces,
                        const bool replace_lt)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET
{
  static char buf[7];

  // Try to un-escape a multi-byte character.  Return the un-escaped
  // string if it is a multi-byte character.
  const char *const p = mb_unescape(sp);
  if (p != NULL) {
    return p;
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

  if (!IS_SPECIAL(c)) {
    const int len = utf_ptr2len((const char_u *)str);

    // Check for an illegal byte.
    if (MB_BYTE2LEN((uint8_t)(*str)) > len) {
      transchar_nonprint((char_u *)buf, c);
      *sp = str + 1;
      return buf;
    }
    // Since 'special' is TRUE the multi-byte character 'c' will be
    // processed by get_special_key_name().
    c = utf_ptr2char((const char_u *)str);
    *sp = str + len;
  } else {
    *sp = str + 1;
  }

  // Make unprintable characters in <> form, also <M-Space> and <Tab>.
  if (special
      || char2cells(c) > 1
      || (replace_spaces && c == ' ')
      || (replace_lt && c == '<')) {
    return (const char *)get_special_key_name(c, modifiers);
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

/*
 * print line for :print or :list command
 */
void msg_prt_line(char_u *s, int list)
{
  int c;
  int col = 0;
  int n_extra = 0;
  int c_extra = 0;
  char_u      *p_extra = NULL;              /* init to make SASC shut up */
  int n;
  int attr = 0;
  char_u      *trail = NULL;
  int l;

  if (curwin->w_p_list)
    list = TRUE;

  /* find start of trailing whitespace */
  if (list && lcs_trail) {
    trail = s + STRLEN(s);
    while (trail > s && ascii_iswhite(trail[-1]))
      --trail;
  }

  /* output a space for an empty line, otherwise the line will be
   * overwritten */
  if (*s == NUL && !(list && lcs_eol != NUL))
    msg_putchar(' ');

  while (!got_int) {
    if (n_extra > 0) {
      n_extra--;
      if (c_extra) {
        c = c_extra;
      } else {
        assert(p_extra != NULL);
        c = *p_extra++;
      }
    } else if ((l = utfc_ptr2len(s)) > 1) {
      col += utf_ptr2cells(s);
      char buf[MB_MAXBYTES + 1];
      if (lcs_nbsp != NUL && list
          && (utf_ptr2char(s) == 160 || utf_ptr2char(s) == 0x202f)) {
        utf_char2bytes(lcs_nbsp, (char_u *)buf);
        buf[utfc_ptr2len((char_u *)buf)] = NUL;
      } else {
        memmove(buf, s, (size_t)l);
        buf[l] = NUL;
      }
      msg_puts(buf);
      s += l;
      continue;
    } else {
      attr = 0;
      c = *s++;
      if (c == TAB && (!list || lcs_tab1)) {
        /* tab amount depends on current column */
        n_extra = curbuf->b_p_ts - col % curbuf->b_p_ts - 1;
        if (!list) {
          c = ' ';
          c_extra = ' ';
        } else {
          c = lcs_tab1;
          c_extra = lcs_tab2;
          attr = HL_ATTR(HLF_8);
        }
      } else if (c == 160 && list && lcs_nbsp != NUL) {
        c = lcs_nbsp;
        attr = HL_ATTR(HLF_8);
      } else if (c == NUL && list && lcs_eol != NUL) {
        p_extra = (char_u *)"";
        c_extra = NUL;
        n_extra = 1;
        c = lcs_eol;
        attr = HL_ATTR(HLF_AT);
        s--;
      } else if (c != NUL && (n = byte2cells(c)) > 1) {
        n_extra = n - 1;
        p_extra = transchar_byte(c);
        c_extra = NUL;
        c = *p_extra++;
        /* Use special coloring to be able to distinguish <hex> from
         * the same in plain text. */
        attr = HL_ATTR(HLF_8);
      } else if (c == ' ' && trail != NULL && s > trail) {
        c = lcs_trail;
        attr = HL_ATTR(HLF_8);
      } else if (c == ' ' && list && lcs_space != NUL) {
        c = lcs_space;
        attr = HL_ATTR(HLF_8);
      }
    }

    if (c == NUL)
      break;

    msg_putchar_attr(c, attr);
    col++;
  }
  msg_clr_eos();
}

/*
 * Use screen_puts() to output one multi-byte character.
 * Return the pointer "s" advanced to the next character.
 */
static char_u *screen_puts_mbyte(char_u *s, int l, int attr)
{
  int cw;

  msg_didout = true;            // remember that line is not empty
  cw = utf_ptr2cells(s);
  if (cw > 1
      && (cmdmsg_rl ? msg_col <= 1 : msg_col == Columns - 1)) {
    // Doesn't fit, print a highlighted '>' to fill it up.
    msg_screen_putchar('>', HL_ATTR(HLF_AT));
    return s;
  }

  screen_puts_len(s, l, msg_row, msg_col, attr);
  if (cmdmsg_rl) {
    msg_col -= cw;
    if (msg_col == 0) {
      msg_col = Columns;
      ++msg_row;
    }
  } else {
    msg_col += cw;
    if (msg_col >= Columns) {
      msg_col = 0;
      ++msg_row;
    }
  }
  return s + l;
}

/*
 * Output a string to the screen at position msg_row, msg_col.
 * Update msg_row and msg_col for the next message.
 */
void msg_puts(const char *s)
{
  msg_puts_attr(s, 0);
}

void msg_puts_title(const char *s)
{
  msg_puts_attr(s, HL_ATTR(HLF_T));
}

/*
 * Show a message in such a way that it always fits in the line.  Cut out a
 * part in the middle and replace it with "..." when necessary.
 * Does not handle multi-byte characters!
 */
void msg_puts_long_attr(char_u *longstr, int attr)
{
  msg_puts_long_len_attr(longstr, (int)STRLEN(longstr), attr);
}

void msg_puts_long_len_attr(char_u *longstr, int len, int attr)
{
  int slen = len;
  int room;

  room = Columns - msg_col;
  if (len > room && room >= 20) {
    slen = (room - 3) / 2;
    msg_outtrans_len_attr(longstr, slen, attr);
    msg_puts_attr("...", HL_ATTR(HLF_8));
  }
  msg_outtrans_len_attr(longstr + len - slen, slen, attr);
}

/*
 * Basic function for writing a message with highlight attributes.
 */
void msg_puts_attr(const char *const s, const int attr)
{
  msg_puts_attr_len(s, -1, attr);
}

/// Write a message with highlight attributes
///
/// @param[in]  str  NUL-terminated message string.
/// @param[in]  len  Length of the string or -1.
/// @param[in]  attr  Highlight attribute.
void msg_puts_attr_len(const char *const str, const ptrdiff_t len, int attr)
  FUNC_ATTR_NONNULL_ALL
{
  assert(len < 0 || memchr(str, 0, len) == NULL);
  // If redirection is on, also write to the redirection file.
  redir_write(str, len);

  // Don't print anything when using ":silent cmd".
  if (msg_silent != 0) {
    return;
  }

  // if MSG_HIST flag set, add message to history
  if (attr & MSG_HIST) {
    add_msg_hist(str, (int)len, attr);
    attr &= ~MSG_HIST;
  }

  // When writing something to the screen after it has scrolled, requires a
  // wait-return prompt later.  Needed when scrolling, resetting
  // need_wait_return after some prompt, and then outputting something
  // without scrolling
  if (msg_scrolled != 0 && !msg_scrolled_ign) {
    need_wait_return = true;
  }
  msg_didany = true;  // remember that something was outputted

  // If there is no valid screen, use fprintf so we can see error messages.
  // If termcap is not active, we may be writing in an alternate console
  // window, cursor positioning may not work correctly (window size may be
  // different, e.g. for Win32 console) or we just don't know where the
  // cursor is.
  if (msg_use_printf()) {
    msg_puts_printf(str, len);
  } else {
    msg_puts_display((const char_u *)str, len, attr, false);
  }
}

/// Print a formatted message
///
/// Message printed is limited by #IOSIZE. Must not be used from inside
/// msg_puts_attr().
///
/// @param[in]  attr  Highlight attributes.
/// @param[in]  fmt  Format string.
void msg_printf_attr(const int attr, const char *const fmt, ...)
  FUNC_ATTR_NONNULL_ARG(2) FUNC_ATTR_PRINTF(2, 3)
{
  static char msgbuf[IOSIZE];

  va_list ap;
  va_start(ap, fmt);
  const size_t len = vim_vsnprintf(msgbuf, sizeof(msgbuf), fmt, ap, NULL);
  va_end(ap);

  msg_scroll = true;
  msg_puts_attr_len(msgbuf, (ptrdiff_t)len, attr);
}

/*
 * The display part of msg_puts_attr_len().
 * May be called recursively to display scroll-back text.
 */
static void msg_puts_display(const char_u *str, int maxlen, int attr,
                             int recurse)
{
  const char_u *s = str;
  const char_u *t_s = str;  // String from "t_s" to "s" is still todo.
  int t_col = 0;  // Screen cells todo, 0 when "t_s" not used.
  int l;
  int cw;
  const char_u *sb_str = str;
  int sb_col = msg_col;
  int wrap;
  int did_last_char;

  did_wait_return = false;
  while ((maxlen < 0 || (int)(s - str) < maxlen) && *s != NUL) {
    // We are at the end of the screen line when:
    // - When outputting a newline.
    // - When outputting a character in the last column.
    if (!recurse && msg_row >= Rows - 1
        && (*s == '\n' || (cmdmsg_rl
                           ? (msg_col <= 1
                              || (*s == TAB && msg_col <= 7)
                              || (utf_ptr2cells(s) > 1
                                  && msg_col <= 2))
                           : (msg_col + t_col >= Columns - 1
                              || (*s == TAB
                                  && msg_col + t_col >= ((Columns - 1) & ~7))
                              || (utf_ptr2cells(s) > 1
                                  && msg_col + t_col >= Columns - 2))))) {
      // The screen is scrolled up when at the last row (some terminals
      // scroll automatically, some don't.  To avoid problems we scroll
      // ourselves).
      if (t_col > 0) {
        // output postponed text
        t_puts(&t_col, t_s, s, attr);
      }

      /* When no more prompt and no more room, truncate here */
      if (msg_no_more && lines_left == 0)
        break;

      /* Scroll the screen up one line. */
      msg_scroll_up();

      msg_row = Rows - 2;
      if (msg_col >= Columns)           /* can happen after screen resize */
        msg_col = Columns - 1;

      // Display char in last column before showing more-prompt.
      if (*s >= ' ' && !cmdmsg_rl) {
        if (maxlen >= 0) {
          // Avoid including composing chars after the end.
          l = utfc_ptr2len_len(s, (int)((str + maxlen) - s));
        } else {
          l = utfc_ptr2len(s);
        }
        s = screen_puts_mbyte((char_u *)s, l, attr);
        did_last_char = true;
      } else {
        did_last_char = false;
      }

      if (p_more) {
        // Store text for scrolling back.
        store_sb_text((char_u **)&sb_str, (char_u *)s, attr, &sb_col, true);
      }

      inc_msg_scrolled();
      need_wait_return = true;       // may need wait_return in main()
      redraw_cmdline = true;
      if (cmdline_row > 0 && !exmode_active) {
        cmdline_row--;
      }

      /*
       * If screen is completely filled and 'more' is set then wait
       * for a character.
       */
      if (lines_left > 0)
        --lines_left;
      if (p_more && lines_left == 0 && State != HITRETURN
          && !msg_no_more && !exmode_active) {
        if (do_more_prompt(NUL))
          s = confirm_msg_tail;
        if (quit_more)
          return;
      }

      /* When we displayed a char in last column need to check if there
       * is still more. */
      if (did_last_char)
        continue;
    }

    wrap = *s == '\n'
           || msg_col + t_col >= Columns
           || (utf_ptr2cells(s) > 1
               && msg_col + t_col >= Columns - 1)
    ;
    if (t_col > 0 && (wrap || *s == '\r' || *s == '\b'
                      || *s == '\t' || *s == BELL)) {
      // Output any postponed text.
      t_puts(&t_col, t_s, s, attr);
    }

    if (wrap && p_more && !recurse) {
      // Store text for scrolling back.
      store_sb_text((char_u **)&sb_str, (char_u *)s, attr, &sb_col, true);
    }

    if (*s == '\n') {               /* go to next line */
      msg_didout = FALSE;           /* remember that line is empty */
      if (cmdmsg_rl)
        msg_col = Columns - 1;
      else
        msg_col = 0;
      if (++msg_row >= Rows)        /* safety check */
        msg_row = Rows - 1;
    } else if (*s == '\r') {      /* go to column 0 */
      msg_col = 0;
    } else if (*s == '\b') {      /* go to previous char */
      if (msg_col)
        --msg_col;
    } else if (*s == TAB) {       /* translate Tab into spaces */
      do {
        msg_screen_putchar(' ', attr);
      } while (msg_col & 7);
    } else if (*s == BELL) {  // beep (from ":sh")
      vim_beep(BO_SH);
    } else if (*s >= 0x20) {  // printable char
      cw = utf_ptr2cells(s);
      if (maxlen >= 0) {
        // avoid including composing chars after the end
        l = utfc_ptr2len_len(s, (int)((str + maxlen) - s));
      } else {
        l = utfc_ptr2len(s);
      }
      // When drawing from right to left or when a double-wide character
      // doesn't fit, draw a single character here.  Otherwise collect
      // characters and draw them all at once later.
      if (cmdmsg_rl || (cw > 1 && msg_col + t_col >= Columns - 1)) {
        if (l > 1) {
          s = screen_puts_mbyte((char_u *)s, l, attr) - 1;
        } else {
          msg_screen_putchar(*s, attr);
        }
      } else {
        /* postpone this character until later */
        if (t_col == 0)
          t_s = s;
        t_col += cw;
        s += l - 1;
      }
    }
    ++s;
  }

  // Output any postponed text.
  if (t_col > 0) {
    t_puts(&t_col, t_s, s, attr);
  }
  if (p_more && !recurse) {
    store_sb_text((char_u **)&sb_str, (char_u *)s, attr, &sb_col, false);
  }

  msg_check();
}

/// Return true when ":filter pattern" was used and "msg" does not match
/// "pattern".
bool message_filtered(char_u *msg)
{
  if (cmdmod.filter_regmatch.regprog == NULL) {
    return false;
  }

  bool match = vim_regexec(&cmdmod.filter_regmatch, msg, (colnr_T)0);
  return cmdmod.filter_force ? match : !match;
}

/// including horizontal separator
int msg_scrollsize(void)
{
  return msg_scrolled + p_ch + 1;
}

/*
 * Scroll the screen up one line for displaying the next message line.
 */
static void msg_scroll_up(void)
{
  if (dy_flags & DY_MSGSEP) {
    if (msg_scrolled == 0) {
      screen_fill(Rows-p_ch-1, Rows-p_ch, 0, (int)Columns,
                  fill_msgsep, fill_msgsep, HL_ATTR(HLF_MSGSEP));
    }
    int nscroll = MIN(msg_scrollsize()+1, Rows);
    screen_del_lines(Rows-nscroll, 1, Rows, 0, Columns);
  } else {
    screen_del_lines(0, 1, (int)Rows, 0, Columns);
  }
  // TODO(bfredl): when msgsep display is properly batched, this fill should be
  // eliminated.
  screen_fill(Rows-1, Rows, 0, (int)Columns, ' ', ' ', 0);
}

/*
 * Increment "msg_scrolled".
 */
static void inc_msg_scrolled(void)
{
  if (*get_vim_var_str(VV_SCROLLSTART) == NUL) {
    char *p = (char *) sourcing_name;
    char *tofree = NULL;

    // v:scrollstart is empty, set it to the script/function name and line
    // number
    if (p == NULL) {
      p = _("Unknown");
    } else {
      size_t len = strlen(p) + 40;
      tofree = xmalloc(len);
      vim_snprintf(tofree, len, _("%s line %" PRId64),
                   p, (int64_t) sourcing_lnum);
      p = tofree;
    }
    set_vim_var_string(VV_SCROLLSTART, p, -1);
    xfree(tofree);
  }
  msg_scrolled++;
  if (must_redraw < VALID) {
    must_redraw = VALID;
  }
}

static msgchunk_T *last_msgchunk = NULL;  // last displayed text

typedef enum {
  SB_CLEAR_NONE = 0,
  SB_CLEAR_ALL,
  SB_CLEAR_CMDLINE_BUSY,
  SB_CLEAR_CMDLINE_DONE
} sb_clear_T;

// When to clear text on next msg.
static sb_clear_T do_clear_sb_text = SB_CLEAR_NONE;

/// Store part of a printed message for displaying when scrolling back.
static void store_sb_text(
    char_u **sb_str,           // start of string
    char_u *s,                 // just after string
    int attr,
    int *sb_col,
    int finish                     // line ends
)
{
  msgchunk_T  *mp;

  if (do_clear_sb_text == SB_CLEAR_ALL
      || do_clear_sb_text == SB_CLEAR_CMDLINE_DONE) {
    clear_sb_text(do_clear_sb_text == SB_CLEAR_ALL);
    do_clear_sb_text = SB_CLEAR_NONE;
  }

  if (s > *sb_str) {
    mp = xmalloc((sizeof(msgchunk_T) + (s - *sb_str)));
    mp->sb_eol = finish;
    mp->sb_msg_col = *sb_col;
    mp->sb_attr = attr;
    memcpy(mp->sb_text, *sb_str, s - *sb_str);
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
  } else if (finish && last_msgchunk != NULL)
    last_msgchunk->sb_eol = TRUE;

  *sb_str = s;
  *sb_col = 0;
}

/*
 * Finished showing messages, clear the scroll-back text on the next message.
 */
void may_clear_sb_text(void)
{
  do_clear_sb_text = SB_CLEAR_ALL;
}

/// Starting to edit the command line, do not clear messages now.
void sb_text_start_cmdline(void)
{
  do_clear_sb_text = SB_CLEAR_CMDLINE_BUSY;
  msg_sb_eol();
}

/// Ending to edit the command line.  Clear old lines but the last one later.
void sb_text_end_cmdline(void)
{
  do_clear_sb_text = SB_CLEAR_CMDLINE_DONE;
}

/// Clear any text remembered for scrolling back.
/// When "all" is FALSE keep the last line.
/// Called when redrawing the screen.
void clear_sb_text(int all)
{
  msgchunk_T  *mp;
  msgchunk_T  **lastp;

  if (all) {
    lastp = &last_msgchunk;
  } else {
    if (last_msgchunk == NULL) {
      return;
    }
    lastp = &last_msgchunk->sb_prev;
  }

  while (*lastp != NULL) {
    mp = (*lastp)->sb_prev;
    xfree(*lastp);
    *lastp = mp;
  }
}

/*
 * "g<" command.
 */
void show_sb_text(void)
{
  msgchunk_T  *mp;

  /* Only show something if there is more than one line, otherwise it looks
   * weird, typing a command without output results in one line. */
  mp = msg_sb_start(last_msgchunk);
  if (mp == NULL || mp->sb_prev == NULL) {
    vim_beep(BO_MESS);
  } else {
    do_more_prompt('G');
    wait_return(FALSE);
  }
}

/*
 * Move to the start of screen line in already displayed text.
 */
static msgchunk_T *msg_sb_start(msgchunk_T *mps)
{
  msgchunk_T *mp = mps;

  while (mp != NULL && mp->sb_prev != NULL && !mp->sb_prev->sb_eol)
    mp = mp->sb_prev;
  return mp;
}

/*
 * Mark the last message chunk as finishing the line.
 */
void msg_sb_eol(void)
{
  if (last_msgchunk != NULL)
    last_msgchunk->sb_eol = TRUE;
}

/*
 * Display a screen line from previously displayed text at row "row".
 * Returns a pointer to the text for the next line (can be NULL).
 */
static msgchunk_T *disp_sb_line(int row, msgchunk_T *smp)
{
  msgchunk_T  *mp = smp;
  char_u      *p;

  for (;; ) {
    msg_row = row;
    msg_col = mp->sb_msg_col;
    p = mp->sb_text;
    if (*p == '\n')         /* don't display the line break */
      ++p;
    msg_puts_display(p, -1, mp->sb_attr, TRUE);
    if (mp->sb_eol || mp->sb_next == NULL)
      break;
    mp = mp->sb_next;
  }
  return mp->sb_next;
}

/*
 * Output any postponed text for msg_puts_attr_len().
 */
static void t_puts(int *t_col, const char_u *t_s, const char_u *s, int attr)
{
  // Output postponed text.
  msg_didout = true;  // Remember that line is not empty.
  screen_puts_len((char_u *)t_s, (int)(s - t_s), msg_row, msg_col, attr);
  msg_col += *t_col;
  *t_col = 0;
  /* If the string starts with a composing character don't increment the
   * column position for it. */
  if (enc_utf8 && utf_iscomposing(utf_ptr2char(t_s)))
    --msg_col;
  if (msg_col >= Columns) {
    msg_col = 0;
    ++msg_row;
  }
}

// Returns TRUE when messages should be printed to stdout/stderr:
//    - "batch mode" ("silent mode", -es/-Es)
//    - no UI and not embedded
int msg_use_printf(void)
{
  return !embedded_mode && !ui_active();
}

/// Print a message when there is no valid screen.
static void msg_puts_printf(const char *str, const ptrdiff_t maxlen)
{
  const char *s = str;
  char buf[4];
  char *p;

  while ((maxlen < 0 || s - str < maxlen) && *s != NUL) {
    if (!(silent_mode && p_verbose == 0)) {
      // NL --> CR NL translation (for Unix, not for "--version")
      p = &buf[0];
      if (*s == '\n' && !info_message) {
        *p++ = '\r';
      }
      *p++ = *s;
      *p = '\0';
      if (info_message) {
        mch_msg(buf);
      } else {
        mch_errmsg(buf);
      }
    }

    // primitive way to compute the current column
    if (cmdmsg_rl) {
      if (*s == '\r' || *s == '\n') {
        msg_col = Columns - 1;
      } else {
        msg_col--;
      }
    } else {
      if (*s == '\r' || *s == '\n') {
        msg_col = 0;
      } else {
        msg_col++;
      }
    }
    s++;
  }
  msg_didout = true;  // assume that line is not empty
}

/*
 * Show the more-prompt and handle the user response.
 * This takes care of scrolling back and displaying previously displayed text.
 * When at hit-enter prompt "typed_char" is the already typed character,
 * otherwise it's NUL.
 * Returns TRUE when jumping ahead to "confirm_msg_tail".
 */
static int do_more_prompt(int typed_char)
{
  static bool entered = false;
  int used_typed_char = typed_char;
  int oldState = State;
  int c;
  int retval = FALSE;
  int toscroll;
  msgchunk_T  *mp_last = NULL;
  msgchunk_T  *mp;
  int i;

  // We get called recursively when a timer callback outputs a message. In
  // that case don't show another prompt. Also when at the hit-Enter prompt
  // and nothing was typed.
  if (entered || (State == HITRETURN && typed_char == 0)) {
    return false;
  }
  entered = true;

  if (typed_char == 'G') {
    /* "g<": Find first line on the last page. */
    mp_last = msg_sb_start(last_msgchunk);
    for (i = 0; i < Rows - 2 && mp_last != NULL
         && mp_last->sb_prev != NULL; ++i)
      mp_last = msg_sb_start(mp_last->sb_prev);
  }

  State = ASKMORE;
  setmouse();
  if (typed_char == NUL)
    msg_moremsg(FALSE);
  for (;; ) {
    /*
     * Get a typed character directly from the user.
     */
    if (used_typed_char != NUL) {
      c = used_typed_char;              /* was typed at hit-enter prompt */
      used_typed_char = NUL;
    } else
      c = get_keystroke();


    toscroll = 0;
    switch (c) {
    case BS:                    /* scroll one line back */
    case K_BS:
    case 'k':
    case K_UP:
      toscroll = -1;
      break;

    case CAR:                   /* one extra line */
    case NL:
    case 'j':
    case K_DOWN:
      toscroll = 1;
      break;

    case 'u':                   /* Up half a page */
      toscroll = -(Rows / 2);
      break;

    case 'd':                   /* Down half a page */
      toscroll = Rows / 2;
      break;

    case 'b':                   /* one page back */
    case K_PAGEUP:
      toscroll = -(Rows - 1);
      break;

    case ' ':                   /* one extra page */
    case 'f':
    case K_PAGEDOWN:
    case K_LEFTMOUSE:
      toscroll = Rows - 1;
      break;

    case 'g':                   /* all the way back to the start */
      toscroll = -999999;
      break;

    case 'G':                   /* all the way to the end */
      toscroll = 999999;
      lines_left = 999999;
      break;

    case ':':                   /* start new command line */
      if (!confirm_msg_used) {
        /* Since got_int is set all typeahead will be flushed, but we
         * want to keep this ':', remember that in a special way. */
        typeahead_noflush(':');
        cmdline_row = Rows - 1;                 /* put ':' on this line */
        skip_redraw = TRUE;                     /* skip redraw once */
        need_wait_return = FALSE;               /* don't wait in main() */
      }
      FALLTHROUGH;
    case 'q':                   // quit
    case Ctrl_C:
    case ESC:
      if (confirm_msg_used) {
        /* Jump to the choices of the dialog. */
        retval = TRUE;
      } else {
        got_int = TRUE;
        quit_more = TRUE;
      }
      /* When there is some more output (wrapping line) display that
       * without another prompt. */
      lines_left = Rows - 1;
      break;

    default:                    /* no valid response */
      msg_moremsg(TRUE);
      continue;
    }

    if (toscroll != 0) {
      if (toscroll < 0) {
        /* go to start of last line */
        if (mp_last == NULL)
          mp = msg_sb_start(last_msgchunk);
        else if (mp_last->sb_prev != NULL)
          mp = msg_sb_start(mp_last->sb_prev);
        else
          mp = NULL;

        /* go to start of line at top of the screen */
        for (i = 0; i < Rows - 2 && mp != NULL && mp->sb_prev != NULL;
             ++i)
          mp = msg_sb_start(mp->sb_prev);

        if (mp != NULL && mp->sb_prev != NULL) {
          /* Find line to be displayed at top. */
          for (i = 0; i > toscroll; --i) {
            if (mp == NULL || mp->sb_prev == NULL)
              break;
            mp = msg_sb_start(mp->sb_prev);
            if (mp_last == NULL)
              mp_last = msg_sb_start(last_msgchunk);
            else
              mp_last = msg_sb_start(mp_last->sb_prev);
          }

          if (toscroll == -1
              && screen_ins_lines(0, 1, (int)Rows, 0, (int)Columns) == OK) {
            screen_fill(0, 1, 0, (int)Columns, ' ', ' ', 0);
            // display line at top
            (void)disp_sb_line(0, mp);
          } else {
            /* redisplay all lines */
            screenclear();
            for (i = 0; mp != NULL && i < Rows - 1; ++i) {
              mp = disp_sb_line(i, mp);
              ++msg_scrolled;
            }
          }
          toscroll = 0;
        }
      } else {
        /* First display any text that we scrolled back. */
        while (toscroll > 0 && mp_last != NULL) {
          /* scroll up, display line at bottom */
          msg_scroll_up();
          inc_msg_scrolled();
          screen_fill((int)Rows - 2, (int)Rows - 1, 0,
              (int)Columns, ' ', ' ', 0);
          mp_last = disp_sb_line((int)Rows - 2, mp_last);
          --toscroll;
        }
      }

      if (toscroll <= 0) {
        /* displayed the requested text, more prompt again */
        screen_fill((int)Rows - 1, (int)Rows, 0,
            (int)Columns, ' ', ' ', 0);
        msg_moremsg(FALSE);
        continue;
      }

      /* display more text, return to caller */
      lines_left = toscroll;
    }

    break;
  }

  /* clear the --more-- message */
  screen_fill((int)Rows - 1, (int)Rows, 0, (int)Columns, ' ', ' ', 0);
  State = oldState;
  setmouse();
  if (quit_more) {
    msg_row = Rows - 1;
    msg_col = 0;
  } else if (cmdmsg_rl) {
    msg_col = Columns - 1;
  }

  entered = false;
  return retval;
}

#if defined(USE_MCH_ERRMSG)

#ifdef mch_errmsg
# undef mch_errmsg
#endif
#ifdef mch_msg
# undef mch_msg
#endif

/*
 * Give an error message.  To be used when the screen hasn't been initialized
 * yet.  When stderr can't be used, collect error messages until the GUI has
 * started and they can be displayed in a message box.
 */
void mch_errmsg(const char *const str)
  FUNC_ATTR_NONNULL_ALL
{
#ifdef UNIX
  /* On Unix use stderr if it's a tty.
   * When not going to start the GUI also use stderr.
   * On Mac, when started from Finder, stderr is the console. */
  if (os_isatty(2)) {
    fprintf(stderr, "%s", str);
    return;
  }
#endif

  /* avoid a delay for a message that isn't there */
  emsg_on_display = FALSE;

  const size_t len = strlen(str) + 1;
  if (error_ga.ga_data == NULL) {
    ga_set_growsize(&error_ga, 80);
    error_ga.ga_itemsize = 1;
  }
  ga_grow(&error_ga, len);
  memmove(error_ga.ga_data + error_ga.ga_len, str, len);
#ifdef UNIX
  /* remove CR characters, they are displayed */
  {
    char_u      *p;

    p = (char_u *)error_ga.ga_data + error_ga.ga_len;
    for (;; ) {
      p = vim_strchr(p, '\r');
      if (p == NULL)
        break;
      *p = ' ';
    }
  }
#endif
  --len;              /* don't count the NUL at the end */
  error_ga.ga_len += len;
}

/*
 * Give a message.  To be used when the screen hasn't been initialized yet.
 * When there is no tty, collect messages until the GUI has started and they
 * can be displayed in a message box.
 */
void mch_msg(char *str)
{
#ifdef UNIX
  /* On Unix use stdout if we have a tty.  This allows "vim -h | more" and
   * uses mch_errmsg() when started from the desktop.
   * When not going to start the GUI also use stdout.
   * On Mac, when started from Finder, stderr is the console. */
  if (os_isatty(2)) {
    printf("%s", str);
    return;
  }
# endif
  mch_errmsg(str);
}
#endif /* USE_MCH_ERRMSG */

/*
 * Put a character on the screen at the current message position and advance
 * to the next position.  Only for printable ASCII!
 */
static void msg_screen_putchar(int c, int attr)
{
  msg_didout = TRUE;            /* remember that line is not empty */
  screen_putchar(c, msg_row, msg_col, attr);
  if (cmdmsg_rl) {
    if (--msg_col == 0) {
      msg_col = Columns;
      ++msg_row;
    }
  } else {
    if (++msg_col >= Columns) {
      msg_col = 0;
      ++msg_row;
    }
  }
}

void msg_moremsg(int full)
{
  int attr;
  char_u      *s = (char_u *)_("-- More --");

  attr = HL_ATTR(HLF_M);
  screen_puts(s, (int)Rows - 1, 0, attr);
  if (full)
    screen_puts((char_u *)
        _(" SPACE/d/j: screen/page/line down, b/u/k: up, q: quit "),
        (int)Rows - 1, vim_strsize(s), attr);
}

/*
 * Repeat the message for the current mode: ASKMORE, EXTERNCMD, CONFIRM or
 * exmode_active.
 */
void repeat_message(void)
{
  if (State == ASKMORE) {
    msg_moremsg(TRUE);          /* display --more-- message again */
    msg_row = Rows - 1;
  } else if (State == CONFIRM) {
    display_confirm_msg();      /* display ":confirm" message again */
    msg_row = Rows - 1;
  } else if (State == EXTERNCMD) {
    ui_cursor_goto(msg_row, msg_col);     /* put cursor back */
  } else if (State == HITRETURN || State == SETWSIZE) {
    if (msg_row == Rows - 1) {
      /* Avoid drawing the "hit-enter" prompt below the previous one,
       * overwrite it.  Esp. useful when regaining focus and a
       * FocusGained autocmd exists but didn't draw anything. */
      msg_didout = FALSE;
      msg_col = 0;
      msg_clr_eos();
    }
    hit_return_msg();
    msg_row = Rows - 1;
  }
}

/*
 * Clear from current message position to end of screen.
 * Skip this when ":silent" was used, no need to clear for redirection.
 */
void msg_clr_eos(void)
{
  if (msg_silent == 0)
    msg_clr_eos_force();
}

/*
 * Clear from current message position to end of screen.
 * Note: msg_col is not updated, so we remember the end of the message
 * for msg_check().
 */
void msg_clr_eos_force(void)
{
  if (cmdmsg_rl) {
    screen_fill(msg_row, msg_row + 1, 0, msg_col + 1, ' ', ' ', 0);
    screen_fill(msg_row + 1, (int)Rows, 0, (int)Columns, ' ', ' ', 0);
  } else {
    screen_fill(msg_row, msg_row + 1, msg_col, (int)Columns, ' ', ' ', 0);
    screen_fill(msg_row + 1, (int)Rows, 0, (int)Columns, ' ', ' ', 0);
  }
}

/*
 * Clear the command line.
 */
void msg_clr_cmdline(void)
{
  msg_row = cmdline_row;
  msg_col = 0;
  msg_clr_eos_force();
}

/*
 * end putting a message on the screen
 * call wait_return if the message does not fit in the available space
 * return TRUE if wait_return not called.
 */
int msg_end(void)
{
  /*
   * If the string is larger than the window,
   * or the ruler option is set and we run into it,
   * we have to redraw the window.
   * Do not do this if we are abandoning the file or editing the command line.
   */
  if (!exiting && need_wait_return && !(State & CMDLINE)) {
    wait_return(FALSE);
    return FALSE;
  }
  ui_flush();
  return TRUE;
}

/*
 * If the written message runs into the shown command or ruler, we have to
 * wait for hit-return and redraw the window later.
 */
void msg_check(void)
{
  if (msg_row == Rows - 1 && msg_col >= sc_col) {
    need_wait_return = TRUE;
    redraw_cmdline = TRUE;
  }
}

/*
 * May write a string to the redirection file.
 * When "maxlen" is -1 write the whole string, otherwise up to "maxlen" bytes.
 */
static void redir_write(const char *const str, const ptrdiff_t maxlen)
{
  const char_u *s = (char_u *)str;
  static int cur_col = 0;

  if (maxlen == 0) {
    return;
  }

  /* Don't do anything for displaying prompts and the like. */
  if (redir_off)
    return;

  /* If 'verbosefile' is set prepare for writing in that file. */
  if (*p_vfile != NUL && verbose_fd == NULL)
    verbose_open();

  if (redirecting()) {
    /* If the string doesn't start with CR or NL, go to msg_col */
    if (*s != '\n' && *s != '\r') {
      while (cur_col < msg_col) {
        if (capture_ga) {
          ga_concat_len(capture_ga, " ", 1);
        }
        if (redir_reg) {
          write_reg_contents(redir_reg, (char_u *)" ", 1, true);
        } else if (redir_vname) {
          var_redir_str((char_u *)" ", -1);
        } else if (redir_fd != NULL) {
          fputs(" ", redir_fd);
        }
        if (verbose_fd != NULL) {
          fputs(" ", verbose_fd);
        }
        cur_col++;
      }
    }

    size_t len = maxlen == -1 ? STRLEN(s) : (size_t)maxlen;
    if (capture_ga) {
      ga_concat_len(capture_ga, (const char *)str, len);
    }
    if (redir_reg) {
      write_reg_contents(redir_reg, s, len, true);
    }
    if (redir_vname) {
      var_redir_str((char_u *)s, maxlen);
    }

    // Write and adjust the current column.
    while (*s != NUL
           && (maxlen < 0 || (int)(s - (const char_u *)str) < maxlen)) {
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

    if (msg_silent != 0)        /* should update msg_col */
      msg_col = cur_col;
  }
}

int redirecting(void)
{
  return redir_fd != NULL || *p_vfile != NUL
         || redir_reg || redir_vname || capture_ga != NULL;
}

/*
 * Before giving verbose message.
 * Must always be called paired with verbose_leave()!
 */
void verbose_enter(void)
{
  if (*p_vfile != NUL)
    ++msg_silent;
}

/*
 * After giving verbose message.
 * Must always be called paired with verbose_enter()!
 */
void verbose_leave(void)
{
  if (*p_vfile != NUL)
    if (--msg_silent < 0)
      msg_silent = 0;
}

/*
 * Like verbose_enter() and set msg_scroll when displaying the message.
 */
void verbose_enter_scroll(void)
{
  if (*p_vfile != NUL)
    ++msg_silent;
  else
    /* always scroll up, don't overwrite */
    msg_scroll = TRUE;
}

/*
 * Like verbose_leave() and set cmdline_row when displaying the message.
 */
void verbose_leave_scroll(void)
{
  if (*p_vfile != NUL) {
    if (--msg_silent < 0)
      msg_silent = 0;
  } else
    cmdline_row = msg_row;
}

/*
 * Called when 'verbosefile' is set: stop writing to the file.
 */
void verbose_stop(void)
{
  if (verbose_fd != NULL) {
    fclose(verbose_fd);
    verbose_fd = NULL;
  }
  verbose_did_open = FALSE;
}

/*
 * Open the file 'verbosefile'.
 * Return FAIL or OK.
 */
int verbose_open(void)
{
  if (verbose_fd == NULL && !verbose_did_open) {
    /* Only give the error message once. */
    verbose_did_open = TRUE;

    verbose_fd = mch_fopen((char *)p_vfile, "a");
    if (verbose_fd == NULL) {
      EMSG2(_(e_notopen), p_vfile);
      return FAIL;
    }
  }
  return OK;
}

/*
 * Give a warning message (for searching).
 * Use 'w' highlighting and may repeat the message after redrawing
 */
void give_warning(char_u *message, bool hl) FUNC_ATTR_NONNULL_ARG(1)
{
  /* Don't do this for ":silent". */
  if (msg_silent != 0)
    return;

  /* Don't want a hit-enter prompt here. */
  ++no_wait_return;

  set_vim_var_string(VV_WARNINGMSG, (char *) message, -1);
  xfree(keep_msg);
  keep_msg = NULL;
  if (hl) {
    keep_msg_attr = HL_ATTR(HLF_W);
  } else {
    keep_msg_attr = 0;
  }
  if (msg_attr((const char *)message, keep_msg_attr) && msg_scrolled == 0) {
    set_keep_msg(message, keep_msg_attr);
  }
  msg_didout = false;  // Overwrite this message.
  msg_nowait = true;   // Don't wait for this message.
  msg_col = 0;

  --no_wait_return;
}

void give_warning2(char_u *const message, char_u *const a1, bool hl)
{
  vim_snprintf((char *)IObuff, IOSIZE, (char *)message, a1);
  give_warning(IObuff, hl);
}

/*
 * Advance msg cursor to column "col".
 */
void msg_advance(int col)
{
  if (msg_silent != 0) {        /* nothing to advance to */
    msg_col = col;              /* for redirection, may fill it up later */
    return;
  }
  if (col >= Columns)           /* not enough room */
    col = Columns - 1;
  if (cmdmsg_rl)
    while (msg_col > Columns - col)
      msg_putchar(' ');
  else
    while (msg_col < col)
      msg_putchar(' ');
}

/*
 * Used for "confirm()" function, and the :confirm command prefix.
 * Versions which haven't got flexible dialogs yet, and console
 * versions, get this generic handler which uses the command line.
 *
 * type  = one of:
 *	   VIM_QUESTION, VIM_INFO, VIM_WARNING, VIM_ERROR or VIM_GENERIC
 * title = title string (can be NULL for default)
 * (neither used in console dialogs at the moment)
 *
 * Format of the "buttons" string:
 * "Button1Name\nButton2Name\nButton3Name"
 * The first button should normally be the default/accept
 * The second button should be the 'Cancel' button
 * Other buttons- use your imagination!
 * A '&' in a button name becomes a shortcut, so each '&' should be before a
 * different letter.
 */
int
do_dialog (
    int type,
    char_u *title,
    char_u *message,
    char_u *buttons,
    int dfltbutton,
    char_u *textfield,          /* IObuff for inputdialog(), NULL
                                           otherwise */
    int ex_cmd                 /* when TRUE pressing : accepts default and starts
                               Ex command */
)
{
  int retval = 0;
  char_u      *hotkeys;
  int c;
  int i;

  if (silent_mode      // No dialogs in silent mode ("ex -s")
      || !ui_active()  // Without a UI Nvim waits for input forever.
      ) {
    return dfltbutton;  // return default option
  }


  int save_msg_silent = msg_silent;
  int oldState = State;

  msg_silent = 0;  // If dialog prompts for input, user needs to see it! #8788
  State = CONFIRM;
  setmouse();

  /*
   * Since we wait for a keypress, don't make the
   * user press RETURN as well afterwards.
   */
  ++no_wait_return;
  hotkeys = msg_show_console_dialog(message, buttons, dfltbutton);

  for (;; ) {
    /* Get a typed character directly from the user. */
    c = get_keystroke();
    switch (c) {
    case CAR:                 /* User accepts default option */
    case NL:
      retval = dfltbutton;
      break;
    case Ctrl_C:              /* User aborts/cancels */
    case ESC:
      retval = 0;
      break;
    default:                  /* Could be a hotkey? */
      if (c < 0) {            /* special keys are ignored here */
        continue;
      }
      if (c == ':' && ex_cmd) {
        retval = dfltbutton;
        ins_char_typebuf(':');
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
      if (hotkeys[i])
        break;
      /* No hotkey match, so keep waiting */
      continue;
    }
    break;
  }

  xfree(hotkeys);

  msg_silent = save_msg_silent;
  State = oldState;
  setmouse();
  --no_wait_return;
  msg_end_prompt();

  return retval;
}


/*
 * Copy one character from "*from" to "*to", taking care of multi-byte
 * characters.  Return the length of the character in bytes.
 */
static int
copy_char (
    char_u *from,
    char_u *to,
    int lowercase                  /* make character lower case */
)
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
#define HOTK_LEN (has_mbyte ? MB_MAXBYTES : 1)

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
static char_u * console_dialog_alloc(const char_u *message,
                                     char_u *buttons,
                                     bool has_hotkey[])
{
  int lenhotkey = HOTK_LEN;  // count first button
  has_hotkey[0] = false;

  // Compute the size of memory to allocate.
  int len = 0;
  int idx = 0;
  char_u *r = buttons;
  while (*r) {
    if (*r == DLG_BUTTON_SEP) {
      len += 3;                         // '\n' -> ', '; 'x' -> '(x)'
      lenhotkey += HOTK_LEN;            // each button needs a hotkey
      if (idx < HAS_HOTKEY_LEN - 1) {
        has_hotkey[++idx] = false;
      }
    } else if (*r == DLG_HOTKEY_CHAR) {
      r++;
      len++;                    // '&a' -> '[a]'
      if (idx < HAS_HOTKEY_LEN - 1) {
        has_hotkey[idx] = true;
      }
    }

    // Advance to the next character
    MB_PTR_ADV(r);
  }

  len += (int)(STRLEN(message)
                + 2                          // for the NL's
                + STRLEN(buttons)
                + 3);                        // for the ": " and NUL
  lenhotkey++;                               // for the NUL

  // If no hotkey is specified, first char is used.
  if (!has_hotkey[0]) {
    len += 2;                                // "x" -> "[x]"
  }


  // Now allocate space for the strings
  xfree(confirm_msg);
  confirm_msg = xmalloc(len);
  *confirm_msg = NUL;

  return xmalloc(lenhotkey);
}

/*
 * Format the dialog string, and display it at the bottom of
 * the screen. Return a string of hotkey chars (if defined) for
 * each 'button'. If a button has no hotkey defined, the first character of
 * the button is used.
 * The hotkeys can be multi-byte characters, but without combining chars.
 *
 * Returns an allocated string with hotkeys.
 */
static char_u *msg_show_console_dialog(char_u *message, char_u *buttons, int dfltbutton)
  FUNC_ATTR_NONNULL_RET
{
  bool has_hotkey[HAS_HOTKEY_LEN] = {false};
  char_u *hotk = console_dialog_alloc(message, buttons, has_hotkey);

  copy_hotkeys_and_msg(message, buttons, dfltbutton, has_hotkey, hotk);

  display_confirm_msg();
  return hotk;
}

/// Copies hotkeys & dialog message into the memory allocated for it
///
/// @param message Message which will be part of the confirm_msg
/// @param buttons String containing button names
/// @param default_button_idx Number of default button
/// @param has_hotkey An element in this array is true if corresponding button
///                   has a hotkey
/// @param[out] hotkeys_ptr Pointer to the memory location where hotkeys will be copied
static void copy_hotkeys_and_msg(const char_u *message, char_u *buttons,
                                 int default_button_idx, const bool has_hotkey[],
                                 char_u *hotkeys_ptr)
{
  *confirm_msg = '\n';
  STRCPY(confirm_msg + 1, message);

  char_u *msgp = confirm_msg + 1 + STRLEN(message);

  // Define first default hotkey. Keep the hotkey string NUL
  // terminated to avoid reading past the end.
  hotkeys_ptr[copy_char(buttons, hotkeys_ptr, TRUE)] = NUL;

  // Remember where the choices start, displaying starts here when
  // "hotkeys_ptr" typed at the more prompt.
  confirm_msg_tail = msgp;
  *msgp++ = '\n';

  bool first_hotkey = false;  // Is the first char of button a hotkey
  if (!has_hotkey[0]) {
    first_hotkey = true;     // If no hotkey is specified, first char is used
  }

  int idx = 0;
  char_u *r = buttons;
  while (*r) {
    if (*r == DLG_BUTTON_SEP) {
      *msgp++ = ',';
      *msgp++ = ' ';                    // '\n' -> ', '

      // Advance to next hotkey and set default hotkey
      hotkeys_ptr += (has_mbyte) ? STRLEN(hotkeys_ptr): 1;
      hotkeys_ptr[copy_char(r + 1, hotkeys_ptr, TRUE)] = NUL;

      if (default_button_idx) {
        default_button_idx--;
      }

      // If no hotkey is specified, first char is used.
      if (idx < HAS_HOTKEY_LEN - 1 && !has_hotkey[++idx]) {
        first_hotkey = true;
      }

    } else if (*r == DLG_HOTKEY_CHAR || first_hotkey) {
      if (*r == DLG_HOTKEY_CHAR) {
        ++r;
      }

      first_hotkey = false;
      if (*r == DLG_HOTKEY_CHAR) {                 // '&&a' -> '&a'
        *msgp++ = *r;
      } else {
        // '&a' -> '[a]'
        *msgp++ = (default_button_idx == 1) ? '[' : '(';
        msgp += copy_char(r, msgp, FALSE);
        *msgp++ = (default_button_idx == 1) ? ']' : ')';

        // redefine hotkey
        hotkeys_ptr[copy_char(r, hotkeys_ptr, TRUE)] = NUL;
      }
    } else {
      // everything else copy literally
      msgp += copy_char(r, msgp, FALSE);
    }

    // advance to the next character
    MB_PTR_ADV(r);
  }

  *msgp++ = ':';
  *msgp++ = ' ';
  *msgp = NUL;
}

/*
 * Display the ":confirm" message.  Also called when screen resized.
 */
void display_confirm_msg(void)
{
  // Avoid that 'q' at the more prompt truncates the message here.
  confirm_msg_used++;
  if (confirm_msg != NULL) {
    msg_puts_attr((const char *)confirm_msg, HL_ATTR(HLF_M));
  }
  confirm_msg_used--;
}

int vim_dialog_yesno(int type, char_u *title, char_u *message, int dflt)
{
  if (do_dialog(type,
          title == NULL ? (char_u *)_("Question") : title,
          message,
          (char_u *)_("&Yes\n&No"), dflt, NULL, FALSE) == 1)
    return VIM_YES;
  return VIM_NO;
}

int vim_dialog_yesnocancel(int type, char_u *title, char_u *message, int dflt)
{
  switch (do_dialog(type,
              title == NULL ? (char_u *)_("Question") : title,
              message,
              (char_u *)_("&Yes\n&No\n&Cancel"), dflt, NULL, FALSE)) {
  case 1: return VIM_YES;
  case 2: return VIM_NO;
  }
  return VIM_CANCEL;
}

int vim_dialog_yesnoallcancel(int type, char_u *title, char_u *message, int dflt)
{
  switch (do_dialog(type,
              title == NULL ? (char_u *)"Question" : title,
              message,
              (char_u *)_("&Yes\n&No\nSave &All\n&Discard All\n&Cancel"),
              dflt, NULL, FALSE)) {
  case 1: return VIM_YES;
  case 2: return VIM_NO;
  case 3: return VIM_ALL;
  case 4: return VIM_DISCARDALL;
  }
  return VIM_CANCEL;
}
