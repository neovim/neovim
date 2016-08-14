#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/message.h"
#include "nvim/ex_cmds.h"
#include "nvim/fileio.h"
#include "nvim/option.h"
#include "nvim/memline.h"
#include "nvim/macros.h"
#include "nvim/move.h"
#include "nvim/misc1.h"
#include "nvim/window.h"
#include "nvim/buffer_defs.h"
#include "nvim/message_pane.h"
#include "nvim/os/time.h"

#define MSGPANE_SEP_FILL '-'
#define MSGPANE_SEP (char_u *)"-- "
#define MSGPANE_SEP_LEN STRLEN(MSGPANE_SEP)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "message_pane.c.generated.h"
#endif


static buf_T *msgpane_buf = NULL;
static MessagePaneEntry *history[MAX_MSGPANE_HIST];
static int history_len = 0;


/// Return true if the message pane exists.
static bool msgpane_exists(void)
{
  return msgpane_buf != NULL && buf_valid(msgpane_buf);
}

/// Create a message pane buffer.
static bool msgpane_create(void)
{
  if (msgpane_exists()) {
    return true;
  }

  msgpane_buf = buflist_new((char_u *)"nvim://messages", NULL, 1, BLN_LISTED);
  if (msgpane_buf == NULL) {
    return false;
  }

  msgpane_buf->b_messages = true;
  return msgpane_exists();
}

/// Scroll to the bottom in each window displaying the message pane if the
/// cursor is on the last line.
static void scroll_to_bottom(bool force)
{
  win_T *oldwin = curwin;
  linenr_T lnum;
  int lines_height;

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->w_buffer->b_messages) {
      // Note: we are checking the cursor's line _after_ adding a new line.
      if (force || wp->w_cursor.lnum >= wp->w_buffer->b_ml.ml_line_count - 1) {
        lnum = wp->w_buffer->b_ml.ml_line_count;
        wp->w_cursor.lnum = lnum;
        wp->w_cursor.col = 0;

        if (wp->w_p_wrap) {
          lines_height = 0;

          while (lnum > 0 && lines_height < wp->w_height) {
            lines_height += plines_win_nofill(wp, lnum--, false);
          }

          if (lines_height > wp->w_height) {
            lnum++;
          }
        } else if (wp->w_height > lnum) {
          lnum = 0;
        } else {
          lnum -= wp->w_height;
        }

        /// Note: There is scroll_cursor_bot() in move.c but I can't get it to
        /// do what I want.
        set_topline(wp, lnum + 1);

        curwin = wp;
        update_topline();
        validate_cursor();
        curwin = oldwin;
      }
    }
  }

  curwin = oldwin;
}

/// Open a message pane window.
bool msgpane_open(void)
{
  bool win_exists = false;
  bool pane_exists = msgpane_exists();

  if (!p_msgpane) {
    return false;
  }

  if (!pane_exists) {
    if (!msgpane_create()) {
      return false;
    }

    // There are messages from before the creation of the message pane.
    if (first_msg_hist != NULL && history_len == 0) {
      // Temporarily NULL msgpane_buf while filling the history.
      buf_T *msgpane = msgpane_buf;
      msgpane_buf = NULL;
      MessageHistoryEntry *p;

      for (p = first_msg_hist; p != NULL; p = p->next) {
        if (p->msg != NULL && *p->msg != NUL) {
          msgpane_add_msg(p->msg, p->attr);
        }
      }

      msgpane_buf = msgpane;
    }
  }

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer->b_messages == true) {
      win_exists = true;
      break;
    }
  }

  if (!win_exists) {
    // Create a window to display the message buffer.
    msg_silent++;
    block_autocmds();

    if (win_split((int)p_cwh, WSP_BOT) == FAIL) {
      beep_flush();
      unblock_autocmds();
      msg_silent--;
      return false;
    }

    set_curbuf(msgpane_buf, DOBUF_SPLIT);
    WITH_BUFFER(msgpane_buf, {
      set_option_value((char_u *)"bt", 0L, (char_u *)"nofile", OPT_LOCAL);
      set_option_value((char_u *)"bh", 0L, (char_u *)"hide", OPT_LOCAL);
      set_option_value((char_u *)"swf", 0L, NULL, OPT_LOCAL);
      set_option_value((char_u *)"nu", 0L, NULL, OPT_LOCAL);
      set_option_value((char_u *)"fen", 0L, NULL, OPT_LOCAL);
      set_option_value((char_u *)"cc", 0L, (char_u *)"", OPT_LOCAL);
      set_option_value((char_u *)"ma", 0L, NULL, OPT_LOCAL);
      set_option_value((char_u *)"wfh", 1L, NULL, OPT_LOCAL);
    });
    RESET_BINDING(curwin);
    unblock_autocmds();

    if (!pane_exists) {
      for (int i = 0; i < history_len; i++) {
        msgpane_add_buffer_line(history[i]->msg);
      }
    }

    set_option_value((char_u *)"ft", 0L, (char_u *)"msgpane", OPT_LOCAL);

    scroll_to_bottom(true);
    msg_silent--;
  }

  return true;
}


/// Highlight attribute for a message line.
int msgpane_line_attr(linenr_T lnum)
{
  if (lnum > 0 && lnum <= history_len) {
    return history[lnum - 1]->attr;
  }

  return 0;
}


/// Check if the line is a separator.
bool msgpane_line_is_sep(linenr_T lnum) {
  if (lnum > 0 && lnum <= history_len) {
    char_u *msg = history[lnum - 1]->msg;
    return (STRNCMP(msg, MSGPANE_SEP, MSGPANE_SEP_LEN) == 0
            && STRLEN(msg) > MSGPANE_SEP_LEN);
  }
  return false;
}


/// Fill window line with the message's time and dashes up to a maximum of 512
/// characters.  Time is displayed using the 24hr format with milliseconds as
/// the fractional unit.
///
/// @param line Pointer to an allocated string.
/// @param lnum Line number.
/// @param width Width of the line, including string terminator.
void msgpane_line_sep_fill(char_u *line, linenr_T lnum, int width) {
  if (lnum <= 0 || lnum > history_len || width < 1) {
    return;
  }

  double timestamp_f = history[lnum - 1]->timestamp;
  time_t timestamp = (time_t)timestamp_f;
  time_t ms = (time_t)((timestamp_f - (double)timestamp) * 1000);

  struct tm msgtime;
  struct tm *dt = os_localtime_r(&timestamp, &msgtime);

  strftime((char *)line, (size_t)width, (char *)" @ %T", dt);
  int len = vim_snprintf((char *)line, (size_t)width,
                         (char *)"%s.%03d ", line, ms);

  while (len <= width) {
    line[len++] = MSGPANE_SEP_FILL;
  }

  line[width] = NUL;
}


/// Add a line to the message pane buffer.
static void msgpane_add_buffer_line(char_u *msg)
{
  linenr_T lnum;

  if (!msgpane_exists()) {
    return;
  }

  int save_w_redr_type = curwin->w_redr_type;
  int save_w_lines_valid = curwin->w_lines_valid;
  int save_must_redraw = must_redraw;

  WITH_BUFFER(msgpane_buf, {
    if (bufempty()) {
      lnum = 1;
      ml_replace(1, msg, 1);
      changed_lines(1, 0, 2, 1);
    } else {
      lnum = msgpane_buf->b_ml.ml_line_count;

      if (lnum == MAX_MSGPANE_HIST) {
        ml_delete(1, 0);
        deleted_lines(1, 1);
        lnum--;
      }

      ml_append(lnum, msg, 0, false);
      appended_lines(lnum, 1);
    }
  });

  if (msgpane_buf->b_nwindows == 0) {
    // Since the message pane buffer wasn't actually in any windows, but
    // WITH_BUFFER() temporarily made it `curbuf`, undo the effects of
    // `redraw_win_later()`.  Otherwise, it will look like lines are
    // disappearing in the actual `curbuf`.
    curwin->w_redr_type = save_w_redr_type;
    curwin->w_lines_valid = save_w_lines_valid;
    must_redraw = save_must_redraw;
  }
}


/// Add a line to the message pane.
void msgpane_add_msg(char_u *msg, int attr)
{
  if (*msg == NUL || (curbuf->b_messages && STRCMP(msg, _(e_modifiable)) == 0)
      || (STRNCMP(msg, MSGPANE_SEP, MSGPANE_SEP_LEN) && history_len > 0
          && STRCMP(history[history_len - 1]->msg, msg) == 0
          && history[history_len - 1]->attr == attr)) {
    return;
  }

  MessagePaneEntry *entry = xmalloc(sizeof(MessagePaneEntry));
  entry->msg = vim_strsave(msg);
  entry->attr = attr;
  entry->timestamp = os_timef();

  if (history_len >= MAX_MSGPANE_HIST) {
    history_len = MAX_MSGPANE_HIST - 1;
    xfree(history[0]->msg);
    xfree(history[0]);

    for (int i = 1; i < MAX_MSGPANE_HIST; i++) {
      history[i - 1] = history[i];
    }
  }

  history[history_len] = entry;
  history_len++;
  msgpane_add_buffer_line(entry->msg);
  scroll_to_bottom(false);
}
