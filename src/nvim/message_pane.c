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

  if (!pane_exists && !msgpane_create()) {
    return false;
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

    set_option_value((char_u *)"ft", 0L, (char_u *)"msgpane_buf", OPT_LOCAL);

    if (!pane_exists) {
      for (int i = 0; i < history_len; i++) {
        msgpane_add_buffer_line(history[i]->msg);
      }
    }

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


/// Add a line to the message pane buffer.
static void msgpane_add_buffer_line(char_u *msg)
{
  linenr_T lnum;

  if (!msgpane_exists()) {
    return;
  }

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
}


/// Add a line to the message pane.
void msgpane_add_msg(char_u *msg, int attr)
{
  if (curbuf->b_messages && STRCMP(msg, _(e_modifiable)) == 0) {
    return;
  }

  MessagePaneEntry *entry = xmalloc(sizeof(MessagePaneEntry));
  entry->msg = vim_strsave(msg);
  entry->attr = attr;

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
