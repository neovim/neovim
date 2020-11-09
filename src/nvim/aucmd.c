// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/os/os.h"
#include "nvim/fileio.h"
#include "nvim/vim.h"
#include "nvim/main.h"
#include "nvim/mark.h"
#include "nvim/move.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/aucmd.h"
#include "nvim/eval.h"
#include "nvim/ex_getln.h"
#include "nvim/buffer.h"
#include "nvim/syntax.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "aucmd.c.generated.h"
#endif

void do_autocmd_uienter(uint64_t chanid, bool attached)
{
  static bool recursive = false;

  if (recursive) {
    return;  // disallow recursion
  }
  recursive = true;

  dict_T *dict = get_vim_var_dict(VV_EVENT);
  assert(chanid < VARNUMBER_MAX);
  tv_dict_add_nr(dict, S_LEN("chan"), (varnumber_T)chanid);
  tv_dict_set_keys_readonly(dict);
  apply_autocmds(attached ? EVENT_UIENTER : EVENT_UILEAVE,
                 NULL, NULL, false, curbuf);
  tv_dict_clear(dict);

  recursive = false;
}

static void focusgained_event(void **argv)
{
  bool *gainedp = argv[0];
  do_autocmd_focusgained(*gainedp);
  xfree(gainedp);
}
void aucmd_schedule_focusgained(bool gained)
{
  bool *gainedp = xmalloc(sizeof(*gainedp));
  *gainedp = gained;
  loop_schedule_deferred(&main_loop,
                         event_create(focusgained_event, 1, gainedp));
}

static void do_autocmd_focusgained(bool gained)
{
  static bool recursive = false;
  static Timestamp last_time = (time_t)0;
  bool need_redraw = false;

  if (recursive) {
    return;  // disallow recursion
  }
  recursive = true;
  need_redraw |= apply_autocmds((gained ? EVENT_FOCUSGAINED : EVENT_FOCUSLOST),
                                NULL, NULL, false, curbuf);

  // When activated: Check if any file was modified outside of Vim.
  // Only do this when not done within the last two seconds as:
  // 1. Some filesystems have modification time granularity in seconds. Fat32
  //    has a granularity of 2 seconds.
  // 2. We could get multiple notifications in a row.
  if (gained && last_time + (Timestamp)2000 < os_now()) {
    need_redraw = check_timestamps(true);
    last_time = os_now();
  }

  if (need_redraw) {
    // Something was executed, make sure the cursor is put back where it
    // belongs.
    need_wait_return = false;

    if (State & CMDLINE) {
      redrawcmdline();
    } else if ((State & NORMAL) || (State & INSERT)) {
      if (must_redraw != 0) {
        update_screen(0);
      }

      setcursor();
    }

    ui_flush();
  }

  if (need_maketitle) {
    maketitle();
  }

  recursive = false;
}

/// Checks if cursor has moved and triggers autocommand.
bool autocmd_check_cursor_moved(win_T *win, event_T event)
{
  bool has_event_value = has_event(event);
  bool result = false;

  if ((has_event_value || win->w_p_cole > 0)
      && !equalpos(win->w_last_cursormoved, win->w_cursor)) {

    if (event == EVENT_CURSORMOVED) {
      if (has_event_value) {
        result = apply_autocmds(event, NULL, NULL, false, win->w_buffer);
      }
    }
    else {  // event == EVENT_CURSORMOVEDI

      // Need to update the screen first, to make sure syntax
      // highlighting is correct after making a change (e.g., inserting
      // a "(".  The autocommand may also require a redraw, so it's done
      // again below, unfortunately.
      if (syntax_present(win) && must_redraw) {
        update_screen(0);
      }
      if (has_event_value) {
        // Make sure curswant is correct, an autocommand may call
        // getcurpos()
        update_curswant();
        apply_autocmds_save_undo(win, event);
      }

      result = true;
      win->w_last_cursormoved = win->w_cursor;
    }

    win->w_last_cursormoved = win->w_cursor;
  }

  return result;
}

/// Checks if text has changed and triggers autocommand.
bool autocmd_check_text_changed(buf_T *buf, event_T event)
{
  bool result = false;
  varnumber_T last_changedtick =
    event == EVENT_TEXTCHANGEDP ?
      buf->b_last_changedtick_pum :
      buf->b_last_changedtick;

  if (has_event(event)
      && last_changedtick != buf_get_changedtick(buf)) {

    if (event == EVENT_TEXTCHANGED) {
      result = apply_autocmds(event, NULL, NULL, false, buf);
      buf->b_last_changedtick = buf_get_changedtick(buf);
    }
    else {  // EVENT_TEXTCHANGEDI or EVENT_TEXTCHANGEDP

      // Trigger TextChanged P or I if changedtick differs.
      // TextChangedI will need to trigger for backwards compatibility,
      // thus use different b_last_changedtick* variables.
      aco_save_T aco;
      varnumber_T tick = buf_get_changedtick(buf);

      // save and restore curwin and buf, in case the autocmd changes them
      aucmd_prepbuf(&aco, buf);
      result = apply_autocmds(event, NULL, NULL, false, buf);
      aucmd_restbuf(&aco);

      if (event == EVENT_TEXTCHANGEDI) {
        buf->b_last_changedtick = buf_get_changedtick(buf);
      }
      else {  // event == EVENT_TEXTCHANGEDP
        buf->b_last_changedtick_pum = buf_get_changedtick(buf);
      }

      if (tick != buf_get_changedtick(buf)) {  // see ins_apply_autocmds()
        u_save(curwin->w_cursor.lnum,
              (linenr_T)(curwin->w_cursor.lnum + 1));
      }
    }
  }

  return result;
}

/// Checks if window has scrolled and triggers autocommand.
bool autocmd_check_window_scrolled(win_T *win)
{
  if (has_event(EVENT_WINSCROLLED) && win_did_scroll(win)) {
    do_autocmd_winscrolled(win);
    return true;
  }
  return false;
}

/// Trigger "event" and take care of fixing undo.
bool apply_autocmds_save_undo(win_T *win, event_T event)
{
  varnumber_T tick = buf_get_changedtick(win->w_buffer);
  bool result;

  result = apply_autocmds(event, NULL, NULL, false, win->w_buffer);

  // If u_savesub() was called then we are not prepared to start
  // a new line.  Call u_save() with no contents to fix that.
  if (tick != buf_get_changedtick(win->w_buffer)) {
    u_save(win->w_cursor.lnum, (linenr_T)(win->w_cursor.lnum + 1));
  }

  return result;
}

