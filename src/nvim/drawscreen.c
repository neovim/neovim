// drawscreen.c: Code for updating all the windows on the screen.
// This is the top level, drawline.c is the middle and grid.c the lower level.

// update_screen() is the function that updates all windows and status lines.
// It is called from the main loop when must_redraw is non-zero.  It may be
// called from other places when an immediate screen update is needed.
//
// The part of the buffer that is displayed in a window is set with:
// - w_topline (first buffer line in window)
// - w_topfill (filler lines above the first line)
// - w_leftcol (leftmost window cell in window),
// - w_skipcol (skipped window cells of first line)
//
// Commands that only move the cursor around in a window, do not need to take
// action to update the display.  The main loop will check if w_topline is
// valid and update it (scroll the window) when needed.
//
// Commands that scroll a window change w_topline and must call
// check_cursor() to move the cursor into the visible part of the window, and
// call redraw_later(wp, UPD_VALID) to have the window displayed by update_screen()
// later.
//
// Commands that change text in the buffer must call changed_bytes() or
// changed_lines() to mark the area that changed and will require updating
// later.  The main loop will call update_screen(), which will update each
// window that shows the changed buffer.  This assumes text above the change
// can remain displayed as it is.  Text after the change may need updating for
// scrolling, folding and syntax highlighting.
//
// Commands that change how a window is displayed (e.g., setting 'list') or
// invalidate the contents of a window in another way (e.g., change fold
// settings), must call redraw_later(wp, UPD_NOT_VALID) to have the whole window
// redisplayed by update_screen() later.
//
// Commands that change how a buffer is displayed (e.g., setting 'tabstop')
// must call redraw_curbuf_later(UPD_NOT_VALID) to have all the windows for the
// buffer redisplayed by update_screen() later.
//
// Commands that change highlighting and possibly cause a scroll too must call
// redraw_later(wp, UPD_SOME_VALID) to update the whole window but still use
// scrolling to avoid redrawing everything.  But the length of displayed lines
// must not change, use UPD_NOT_VALID then.
//
// Commands that move the window position must call redraw_later(wp, UPD_NOT_VALID).
// TODO(neovim): should minimize redrawing by scrolling when possible.
//
// Commands that change everything (e.g., resizing the screen) must call
// redraw_all_later(UPD_NOT_VALID) or redraw_all_later(UPD_CLEAR).
//
// Things that are handled indirectly:
// - When messages scroll the screen up, msg_scrolled will be set and
//   update_screen() called to redraw.

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand.h"
#include "nvim/cursor.h"
#include "nvim/decoration.h"
#include "nvim/decoration_defs.h"
#include "nvim/decoration_provider.h"
#include "nvim/diff.h"
#include "nvim/digraph.h"
#include "nvim/drawline.h"
#include "nvim/drawscreen.h"
#include "nvim/eval.h"
#include "nvim/ex_getln.h"
#include "nvim/fold.h"
#include "nvim/fold_defs.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/grid_defs.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/insexpand.h"
#include "nvim/marktree_defs.h"
#include "nvim/match.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/normal_defs.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/os/os_defs.h"
#include "nvim/plines.h"
#include "nvim/popupmenu.h"
#include "nvim/pos_defs.h"
#include "nvim/profile.h"
#include "nvim/regexp.h"
#include "nvim/search.h"
#include "nvim/spell.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/statusline.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/terminal.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_compositor.h"
#include "nvim/ui_defs.h"
#include "nvim/version.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

/// corner value flags for hsep_connected and vsep_connected
typedef enum {
  WC_TOP_LEFT = 0,
  WC_TOP_RIGHT,
  WC_BOTTOM_LEFT,
  WC_BOTTOM_RIGHT,
} WindowCorner;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "drawscreen.c.generated.h"
#endif

static bool redraw_popupmenu = false;
static bool msg_grid_invalid = false;
static bool resizing_autocmd = false;

/// Check if the cursor line needs to be redrawn because of 'concealcursor'.
///
/// When cursor is moved at the same time, both lines will be redrawn regardless.
void conceal_check_cursor_line(void)
{
  bool should_conceal = conceal_cursor_line(curwin);
  if (curwin->w_p_cole <= 0 || conceal_cursor_used == should_conceal) {
    return;
  }

  redrawWinline(curwin, curwin->w_cursor.lnum);
  // Need to recompute cursor column, e.g., when starting Visual mode
  // without concealing.
  curs_columns(curwin, true);
}

/// Resize default_grid to Rows and Columns.
///
/// Allocate default_grid.chars[] and other grid arrays.
///
/// There may be some time between setting Rows and Columns and (re)allocating
/// default_grid arrays.  This happens when starting up and when
/// (manually) changing the screen size.  Always use default_grid.rows and
/// default_grid.cols to access items in default_grid.chars[].  Use Rows and
/// Columns for positioning text etc. where the final size of the screen is
/// needed.
///
/// @return  whether resizing has been done
bool default_grid_alloc(void)
{
  static bool resizing = false;

  // It's possible that we produce an out-of-memory message below, which
  // will cause this function to be called again.  To break the loop, just
  // return here.
  if (resizing) {
    return false;
  }
  resizing = true;

  // Allocation of the screen buffers is done only when the size changes and
  // when Rows and Columns have been set and we have started doing full
  // screen stuff.
  if ((default_grid.chars != NULL
       && Rows == default_grid.rows
       && Columns == default_grid.cols)
      || Rows == 0
      || Columns == 0
      || (!full_screen && default_grid.chars == NULL)) {
    resizing = false;
    return false;
  }

  // We're changing the size of the screen.
  // - Allocate new arrays for default_grid
  // - Move lines from the old arrays into the new arrays, clear extra
  //   lines (unless the screen is going to be cleared).
  // - Free the old arrays.
  //
  // If anything fails, make grid arrays NULL, so we don't do anything!
  // Continuing with the old arrays may result in a crash, because the
  // size is wrong.

  grid_alloc(&default_grid, Rows, Columns, true, true);

  stl_clear_click_defs(tab_page_click_defs, tab_page_click_defs_size);
  tab_page_click_defs = stl_alloc_click_defs(tab_page_click_defs, Columns,
                                             &tab_page_click_defs_size);

  default_grid.comp_height = Rows;
  default_grid.comp_width = Columns;

  default_grid.row_offset = 0;
  default_grid.col_offset = 0;
  default_grid.handle = DEFAULT_GRID_HANDLE;

  resizing = false;
  return true;
}

void screenclear(void)
{
  msg_check_for_delay(false);

  if (starting == NO_SCREEN || default_grid.chars == NULL) {
    return;
  }

  // blank out the default grid
  for (int i = 0; i < default_grid.rows; i++) {
    grid_clear_line(&default_grid, default_grid.line_offset[i],
                    default_grid.cols, true);
  }

  ui_call_grid_clear(1);  // clear the display
  ui_comp_set_screen_valid(true);

  ns_hl_fast = -1;

  clear_cmdline = false;
  mode_displayed = false;

  redraw_all_later(UPD_NOT_VALID);
  redraw_cmdline = true;
  redraw_tabline = true;
  redraw_popupmenu = true;
  pum_invalidate();
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_floating) {
      wp->w_redr_type = UPD_CLEAR;
    }
  }
  if (must_redraw == UPD_CLEAR) {
    must_redraw = UPD_NOT_VALID;  // no need to clear again
  }
  compute_cmdrow();
  msg_row = cmdline_row;  // put cursor on last line for messages
  msg_col = 0;
  msg_scrolled = 0;  // can't scroll back
  msg_didany = false;
  msg_didout = false;
  if (HL_ATTR(HLF_MSG) > 0 && msg_use_grid() && msg_grid.chars) {
    grid_invalidate(&msg_grid);
    msg_grid_validate();
    msg_grid_invalid = false;
    clear_cmdline = true;
  }
}

/// Set dimensions of the Nvim application "screen".
void screen_resize(int width, int height)
{
  // Avoid recursiveness, can happen when setting the window size causes
  // another window-changed signal.
  if (updating_screen || resizing_screen) {
    return;
  }

  if (width < 0 || height < 0) {    // just checking...
    return;
  }

  if (State == MODE_HITRETURN || State == MODE_SETWSIZE) {
    // postpone the resizing
    State = MODE_SETWSIZE;
    return;
  }

  resizing_screen = true;

  Rows = height;
  Columns = width;
  check_screensize();
  if (!ui_has(kUIMessages)) {
    // clamp 'cmdheight'
    int max_p_ch = Rows - min_rows(curtab) + 1;
    if (p_ch > 0 && p_ch > max_p_ch) {
      p_ch = MAX(max_p_ch, 1);
      curtab->tp_ch_used = p_ch;
    }
    // clamp 'cmdheight' for other tab pages
    FOR_ALL_TABS(tp) {
      if (tp == curtab) {
        continue;  // already set above
      }
      int max_tp_ch = Rows - min_rows(tp) + 1;
      if (tp->tp_ch_used > 0 && tp->tp_ch_used > max_tp_ch) {
        tp->tp_ch_used = MAX(max_tp_ch, 1);
      }
    }
  }
  height = Rows;
  width = Columns;
  p_lines = Rows;
  p_columns = Columns;

  ui_call_grid_resize(1, width, height);

  int retry_count = 0;
  resizing_autocmd = true;

  // In rare cases, autocommands may have altered Rows or Columns,
  // so retry to check if we need to allocate the screen again.
  while (default_grid_alloc()) {
    // win_new_screensize will recompute floats position, but tell the
    // compositor to not redraw them yet
    ui_comp_set_screen_valid(false);
    if (msg_grid.chars) {
      msg_grid_invalid = true;
    }

    RedrawingDisabled++;

    win_new_screensize();      // fit the windows in the new sized screen

    comp_col();           // recompute columns for shown command and ruler

    RedrawingDisabled--;

    // Do not apply autocommands more than 3 times to avoid an endless loop
    // in case applying autocommands always changes Rows or Columns.
    if (++retry_count > 3) {
      break;
    }

    apply_autocmds(EVENT_VIMRESIZED, NULL, NULL, false, curbuf);
  }

  resizing_autocmd = false;
  redraw_all_later(UPD_CLEAR);

  if (State != MODE_ASKMORE && State != MODE_EXTERNCMD && State != MODE_CONFIRM) {
    screenclear();
  }

  if (starting != NO_SCREEN) {
    maketitle();

    changed_line_abv_curs();
    invalidate_botline(curwin);

    // We only redraw when it's needed:
    // - While at the more prompt or executing an external command, don't
    //   redraw, but position the cursor.
    // - While editing the command line, only redraw that. TODO: lies
    // - in Ex mode, don't redraw anything.
    // - Otherwise, redraw right now, and position the cursor.
    if (State == MODE_ASKMORE || State == MODE_EXTERNCMD || State == MODE_CONFIRM
        || exmode_active) {
      if (msg_grid.chars) {
        msg_grid_validate();
      }
      // TODO(bfredl): sometimes messes up the output. Implement clear+redraw
      // also for the pager? (or: what if the pager was just a modal window?)
      ui_comp_set_screen_valid(true);
      repeat_message();
    } else {
      if (curwin->w_p_scb) {
        do_check_scrollbind(true);
      }
      if (State & MODE_CMDLINE) {
        redraw_popupmenu = false;
        update_screen();
        redrawcmdline();
        if (pum_drawn()) {
          cmdline_pum_display(false);
        }
      } else {
        update_topline(curwin);
        if (pum_drawn()) {
          // TODO(bfredl): ins_compl_show_pum wants to redraw the screen first.
          // For now make sure the nested update_screen() won't redraw the
          // pum at the old position. Try to untangle this later.
          redraw_popupmenu = false;
          ins_compl_show_pum();
        }
        update_screen();
        if (redrawing()) {
          setcursor();
        }
      }
    }
    ui_flush();
  }
  resizing_screen = false;
}

/// Check if the new Nvim application "screen" dimensions are valid.
/// Correct it if it's too small or way too big.
void check_screensize(void)
{
  // Limit Rows and Columns to avoid an overflow in Rows * Columns.
  // need room for one window and command line
  Rows = MIN(MAX(Rows, min_rows_for_all_tabpages()), 1000);
  Columns = MIN(MAX(Columns, MIN_COLUMNS), 10000);
}

/// Return true if redrawing should currently be done.
bool redrawing(void)
{
  return !RedrawingDisabled
         && !(p_lz && char_avail() && !KeyTyped && !do_redraw);
}

/// Redraw the parts of the screen that is marked for redraw.
///
/// Most code shouldn't call this directly, rather use redraw_later() and
/// and redraw_all_later() to mark parts of the screen as needing a redraw.
int update_screen(void)
{
  static bool still_may_intro = true;
  if (still_may_intro) {
    if (!may_show_intro()) {
      redraw_later(firstwin, UPD_NOT_VALID);
      still_may_intro = false;
    }
  }

  bool is_stl_global = global_stl_height() > 0;

  // Don't do anything if the screen structures are (not yet) valid.
  // A VimResized autocmd can invoke redrawing in the middle of a resize,
  // which would bypass the checks in screen_resize for popupmenu etc.
  if (resizing_autocmd || !default_grid.chars) {
    return FAIL;
  }

  // May have postponed updating diffs.
  if (need_diff_redraw) {
    diff_redraw(true);
  }

  // Postpone the redrawing when it's not needed and when being called
  // recursively.
  if (!redrawing() || updating_screen) {
    return FAIL;
  }

  int type = must_redraw;

  // must_redraw is reset here, so that when we run into some weird
  // reason to redraw while busy redrawing (e.g., asynchronous
  // scrolling), or update_topline() in win_update() will cause a
  // scroll, or a decoration provider requires a redraw, the screen
  // will be redrawn later or in win_update().
  must_redraw = 0;

  updating_screen = true;

  display_tick++;  // let syntax code know we're in a next round of
                   // display updating

  // glyph cache full, very rare
  if (schar_cache_clear_if_full()) {
    // must use CLEAR, as the contents of screen buffers cannot be
    // compared to their previous state here.
    // TODO(bfredl): if start to cache schar_T values in places (like fcs/lcs)
    // we need to revalidate these here as well!
    type = MAX(type, UPD_CLEAR);
  }

  // Tricky: vim code can reset msg_scrolled behind our back, so need
  // separate bookkeeping for now.
  if (msg_did_scroll) {
    msg_did_scroll = false;
    msg_scrolled_at_flush = 0;
  }

  if (type >= UPD_CLEAR || !default_grid.valid) {
    ui_comp_set_screen_valid(false);
  }

  // if the screen was scrolled up when displaying a message, scroll it down
  if (msg_scrolled || msg_grid_invalid) {
    clear_cmdline = true;
    int valid = MAX(Rows - msg_scrollsize(), 0);
    if (msg_grid.chars) {
      // non-displayed part of msg_grid is considered invalid.
      for (int i = 0; i < MIN(msg_scrollsize(), msg_grid.rows); i++) {
        grid_clear_line(&msg_grid, msg_grid.line_offset[i],
                        msg_grid.cols, i < p_ch);
      }
    }
    msg_grid.throttled = false;
    bool was_invalidated = false;

    // UPD_CLEAR is already handled
    if (type == UPD_NOT_VALID && !ui_has(kUIMultigrid) && msg_scrolled) {
      was_invalidated = ui_comp_set_screen_valid(false);
      for (int i = valid; i < Rows - p_ch; i++) {
        grid_clear_line(&default_grid, default_grid.line_offset[i],
                        Columns, false);
      }
      FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
        if (wp->w_floating) {
          continue;
        }
        if (W_ENDROW(wp) > valid) {
          // TODO(bfredl): too pessimistic. type could be UPD_NOT_VALID
          // only because windows that are above the separator.
          wp->w_redr_type = MAX(wp->w_redr_type, UPD_NOT_VALID);
        }
        if (!is_stl_global && W_ENDROW(wp) + wp->w_status_height > valid) {
          wp->w_redr_status = true;
        }
      }
      if (is_stl_global && Rows - p_ch - 1 > valid) {
        curwin->w_redr_status = true;
      }
    }
    msg_grid_set_pos(Rows - (int)p_ch, false);
    msg_grid_invalid = false;
    if (was_invalidated) {
      // screen was only invalid for the msgarea part.
      // @TODO(bfredl): using the same "valid" flag
      // for both messages and floats moving is bit of a mess.
      ui_comp_set_screen_valid(true);
    }
    msg_scrolled = 0;
    msg_scrolled_at_flush = 0;
    msg_grid_scroll_discount = 0;
    need_wait_return = false;
  }

  win_ui_flush(true);
  msg_ext_check_clear();

  // reset cmdline_row now (may have been changed temporarily)
  compute_cmdrow();

  bool hl_changed = false;
  // Check for changed highlighting
  if (need_highlight_changed) {
    highlight_changed();
    hl_changed = true;
  }

  if (type == UPD_CLEAR) {          // first clear screen
    screenclear();  // will reset clear_cmdline
                    // and set UPD_NOT_VALID for each window
    cmdline_screen_cleared();   // clear external cmdline state
    type = UPD_NOT_VALID;
    // must_redraw may be set indirectly, avoid another redraw later
    must_redraw = 0;
  } else if (!default_grid.valid) {
    grid_invalidate(&default_grid);
    default_grid.valid = true;
  }

  // might need to clear space on default_grid for the message area.
  if (type == UPD_NOT_VALID && clear_cmdline && !ui_has(kUIMessages)) {
    grid_clear(&default_grid, Rows - (int)p_ch, Rows, 0, Columns, 0);
  }

  ui_comp_set_screen_valid(true);

  decor_providers_start();

  // "start" callback could have changed highlights for global elements
  if (win_check_ns_hl(NULL)) {
    redraw_cmdline = true;
    redraw_tabline = true;
  }

  if (clear_cmdline) {          // going to clear cmdline (done below)
    msg_check_for_delay(false);
  }

  // Force redraw when width of 'number' or 'relativenumber' column
  // changes.
  // TODO(bfredl): special casing curwin here is SÅ JÄVLA BULL.
  // Either this should be done for all windows or not at all.
  if (curwin->w_redr_type < UPD_NOT_VALID
      && curwin->w_nrwidth != ((curwin->w_p_nu || curwin->w_p_rnu || *curwin->w_p_stc)
                               ? number_width(curwin) : 0)) {
    curwin->w_redr_type = UPD_NOT_VALID;
  }

  // Redraw the tab pages line if needed.
  if (redraw_tabline || type >= UPD_NOT_VALID) {
    update_window_hl(curwin, type >= UPD_NOT_VALID);
    FOR_ALL_TABS(tp) {
      if (tp != curtab) {
        update_window_hl(tp->tp_curwin, type >= UPD_NOT_VALID);
      }
    }
    draw_tabline();
  }

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    // Correct stored syntax highlighting info for changes in each displayed
    // buffer.  Each buffer must only be done once.
    update_window_hl(wp, type >= UPD_NOT_VALID || hl_changed);

    buf_T *buf = wp->w_buffer;
    if (buf->b_mod_set) {
      if (buf->b_mod_tick_syn < display_tick
          && syntax_present(wp)) {
        syn_stack_apply_changes(buf);
        buf->b_mod_tick_syn = display_tick;
      }

      if (buf->b_mod_tick_decor < display_tick) {
        decor_providers_invoke_buf(buf);
        buf->b_mod_tick_decor = display_tick;
      }
    }
  }

  // Go from top to bottom through the windows, redrawing the ones that need it.
  bool did_one = false;
  screen_search_hl.rm.regprog = NULL;

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_redr_type == UPD_CLEAR && wp->w_floating && wp->w_grid_alloc.chars) {
      grid_invalidate(&wp->w_grid_alloc);
      wp->w_redr_type = UPD_NOT_VALID;
    }

    win_check_ns_hl(wp);

    // reallocate grid if needed.
    win_grid_alloc(wp);

    if (wp->w_redr_border || wp->w_redr_type >= UPD_NOT_VALID) {
      win_redr_border(wp);
    }

    if (wp->w_redr_type != 0) {
      if (!did_one) {
        did_one = true;
        start_search_hl();
      }
      win_update(wp);
    }

    // redraw status line and window bar after the window to minimize cursor movement
    if (wp->w_redr_status) {
      win_redr_winbar(wp);
      win_redr_status(wp);
    }
  }

  end_search_hl();

  // May need to redraw the popup menu.
  if (pum_drawn() && must_redraw_pum) {
    win_check_ns_hl(curwin);
    pum_redraw();
  }

  win_check_ns_hl(NULL);

  // Reset b_mod_set and b_signcols.resized flags.  Going through all windows is
  // probably faster than going through all buffers (there could be many buffers).
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    wp->w_buffer->b_mod_set = false;
    wp->w_buffer->b_signcols.resized = false;
  }

  updating_screen = false;

  // Clear or redraw the command line.  Done last, because scrolling may
  // mess up the command line.
  if (clear_cmdline || redraw_cmdline || redraw_mode) {
    showmode();
  }

  // May put up an introductory message when not editing a file
  if (still_may_intro) {
    intro_message(false);
  }

  decor_providers_invoke_end();

  // either cmdline is cleared, not drawn or mode is last drawn
  cmdline_was_last_drawn = false;
  return OK;
}

/// Prepare for 'hlsearch' highlighting.
void start_search_hl(void)
{
  if (!p_hls || no_hlsearch) {
    return;
  }

  end_search_hl();  // just in case it wasn't called before
  last_pat_prog(&screen_search_hl.rm);
  // Set the time limit to 'redrawtime'.
  screen_search_hl.tm = profile_setlimit(p_rdt);
}

/// Clean up for 'hlsearch' highlighting.
void end_search_hl(void)
{
  if (screen_search_hl.rm.regprog == NULL) {
    return;
  }

  vim_regfree(screen_search_hl.rm.regprog);
  screen_search_hl.rm.regprog = NULL;
}

static void win_redr_bordertext(win_T *wp, VirtText vt, int col, BorderTextType bt)
{
  for (size_t i = 0; i < kv_size(vt);) {
    int attr = -1;
    char *text = next_virt_text_chunk(vt, &i, &attr);
    if (text == NULL) {
      break;
    }
    if (attr == -1) {  // No highlight specified.
      attr = wp->w_ns_hl_attr[bt == kBorderTextTitle ? HLF_BTITLE : HLF_BFOOTER];
    }
    attr = hl_apply_winblend(wp, attr);
    col += grid_line_puts(col, text, -1, attr);
  }
}

int win_get_bordertext_col(int total_col, int text_width, AlignTextPos align)
{
  switch (align) {
  case kAlignLeft:
    return 1;
  case kAlignCenter:
    return MAX((total_col - text_width) / 2 + 1, 1);
  case kAlignRight:
    return MAX(total_col - text_width + 1, 1);
  }
  UNREACHABLE;
}

static void win_redr_border(win_T *wp)
{
  wp->w_redr_border = false;
  if (!(wp->w_floating && wp->w_config.border)) {
    return;
  }

  ScreenGrid *grid = &wp->w_grid_alloc;

  schar_T chars[8];
  for (int i = 0; i < 8; i++) {
    chars[i] = schar_from_str(wp->w_config.border_chars[i]);
  }
  int *attrs = wp->w_config.border_attr;

  int *adj = wp->w_border_adj;
  int irow = wp->w_height_inner + wp->w_winbar_height;
  int icol = wp->w_width_inner;

  if (adj[0]) {
    grid_line_start(grid, 0);
    if (adj[3]) {
      grid_line_put_schar(0, chars[0], attrs[0]);
    }

    for (int i = 0; i < icol; i++) {
      grid_line_put_schar(i + adj[3], chars[1], attrs[1]);
    }

    if (wp->w_config.title) {
      int title_col = win_get_bordertext_col(icol, wp->w_config.title_width,
                                             wp->w_config.title_pos);
      win_redr_bordertext(wp, wp->w_config.title_chunks, title_col, kBorderTextTitle);
    }
    if (adj[1]) {
      grid_line_put_schar(icol + adj[3], chars[2], attrs[2]);
    }
    grid_line_flush();
  }

  for (int i = 0; i < irow; i++) {
    if (adj[3]) {
      grid_line_start(grid, i + adj[0]);
      grid_line_put_schar(0, chars[7], attrs[7]);
      grid_line_flush();
    }
    if (adj[1]) {
      int ic = (i == 0 && !adj[0] && chars[2]) ? 2 : 3;
      grid_line_start(grid, i + adj[0]);
      grid_line_put_schar(icol + adj[3], chars[ic], attrs[ic]);
      grid_line_flush();
    }
  }

  if (adj[2]) {
    grid_line_start(grid, irow + adj[0]);
    if (adj[3]) {
      grid_line_put_schar(0, chars[6], attrs[6]);
    }

    for (int i = 0; i < icol; i++) {
      int ic = (i == 0 && !adj[3] && chars[6]) ? 6 : 5;
      grid_line_put_schar(i + adj[3], chars[ic], attrs[ic]);
    }

    if (wp->w_config.footer) {
      int footer_col = win_get_bordertext_col(icol, wp->w_config.footer_width,
                                              wp->w_config.footer_pos);
      win_redr_bordertext(wp, wp->w_config.footer_chunks, footer_col, kBorderTextFooter);
    }
    if (adj[1]) {
      grid_line_put_schar(icol + adj[3], chars[4], attrs[4]);
    }
    grid_line_flush();
  }
}

/// Set cursor to its position in the current window.
void setcursor(void)
{
  setcursor_mayforce(curwin, false);
}

/// Set cursor to its position in the current window.
/// @param force  when true, also when not redrawing.
void setcursor_mayforce(win_T *wp, bool force)
{
  if (force || redrawing()) {
    validate_cursor(wp);

    ScreenGrid *grid = &wp->w_grid;
    int row = wp->w_wrow;
    int col = wp->w_wcol;
    if (wp->w_p_rl) {
      // With 'rightleft' set and the cursor on a double-wide character,
      // position it on the leftmost column.
      char *cursor = ml_get_buf(wp->w_buffer, wp->w_cursor.lnum) + wp->w_cursor.col;
      col = wp->w_width_inner - wp->w_wcol - ((utf_ptr2cells(cursor) == 2
                                               && vim_isprintc(utf_ptr2char(cursor))) ? 2 : 1);
    }

    grid_adjust(&grid, &row, &col);
    ui_grid_cursor_goto(grid->handle, row, col);
  }
}

/// Show current cursor info in ruler and various other places
///
/// @param always  if false, only show ruler if position has changed.
void show_cursor_info_later(bool force)
{
  int state = get_real_state();
  int empty_line = (State & MODE_INSERT) == 0
                   && *ml_get_buf(curwin->w_buffer, curwin->w_cursor.lnum) == NUL;

  // Only draw when something changed.
  validate_virtcol(curwin);
  if (force
      || curwin->w_cursor.lnum != curwin->w_stl_cursor.lnum
      || curwin->w_cursor.col != curwin->w_stl_cursor.col
      || curwin->w_virtcol != curwin->w_stl_virtcol
      || curwin->w_cursor.coladd != curwin->w_stl_cursor.coladd
      || curwin->w_topline != curwin->w_stl_topline
      || curwin->w_buffer->b_ml.ml_line_count != curwin->w_stl_line_count
      || curwin->w_topfill != curwin->w_stl_topfill
      || empty_line != curwin->w_stl_empty
      || reg_recording != curwin->w_stl_recording
      || state != curwin->w_stl_state
      || (VIsual_active && VIsual_mode != curwin->w_stl_visual_mode)) {
    if (curwin->w_status_height || global_stl_height()) {
      curwin->w_redr_status = true;
    } else {
      redraw_cmdline = true;
    }

    if (*p_wbr != NUL || *curwin->w_p_wbr != NUL) {
      curwin->w_redr_status = true;
    }

    if ((p_icon && (stl_syntax & STL_IN_ICON))
        || (p_title && (stl_syntax & STL_IN_TITLE))) {
      need_maketitle = true;
    }
  }

  curwin->w_stl_cursor = curwin->w_cursor;
  curwin->w_stl_virtcol = curwin->w_virtcol;
  curwin->w_stl_empty = (char)empty_line;
  curwin->w_stl_topline = curwin->w_topline;
  curwin->w_stl_line_count = curwin->w_buffer->b_ml.ml_line_count;
  curwin->w_stl_topfill = curwin->w_topfill;
  curwin->w_stl_recording = reg_recording;
  curwin->w_stl_state = state;
  if (VIsual_active) {
    curwin->w_stl_visual_mode = VIsual_mode;
  }
}

/// @return true when postponing displaying the mode message: when not redrawing
/// or inside a mapping.
bool skip_showmode(void)
{
  // Call char_avail() only when we are going to show something, because it
  // takes a bit of time.  redrawing() may also call char_avail().
  if (global_busy || msg_silent != 0 || !redrawing() || (char_avail() && !KeyTyped)) {
    redraw_mode = true;  // show mode later
    return true;
  }
  return false;
}

/// Show the current mode and ruler.
///
/// If clear_cmdline is true, clear the rest of the cmdline.
/// If clear_cmdline is false there may be a message there that needs to be
/// cleared only if a mode is shown.
/// If redraw_mode is true show or clear the mode.
/// @return the length of the message (0 if no message).
int showmode(void)
{
  int length = 0;

  if (ui_has(kUIMessages) && clear_cmdline) {
    msg_ext_clear(true);
  }

  // Don't make non-flushed message part of the showmode.
  msg_ext_ui_flush();

  msg_grid_validate();

  bool do_mode = ((p_smd && msg_silent == 0)
                  && ((State & MODE_TERMINAL)
                      || (State & MODE_INSERT)
                      || restart_edit != NUL
                      || VIsual_active));

  bool can_show_mode = (p_ch != 0 || ui_has(kUIMessages));
  if ((do_mode || reg_recording != 0) && can_show_mode) {
    if (skip_showmode()) {
      return 0;  // show mode later
    }

    bool nwr_save = need_wait_return;

    // wait a bit before overwriting an important message
    msg_check_for_delay(false);

    // if the cmdline is more than one line high, erase top lines
    bool need_clear = clear_cmdline;
    if (clear_cmdline && cmdline_row < Rows - 1) {
      msg_clr_cmdline();  // will reset clear_cmdline
    }

    // Position on the last line in the window, column 0
    msg_pos_mode();
    int hl_id = HLF_CM;  // Highlight mode

    // When the screen is too narrow to show the entire mode message,
    // avoid scrolling and truncate instead.
    msg_no_more = true;
    int save_lines_left = lines_left;
    lines_left = 0;

    if (do_mode) {
      msg_puts_hl("--", hl_id, false);
      // CTRL-X in Insert mode
      if (edit_submode != NULL && !shortmess(SHM_COMPLETIONMENU)) {
        // These messages can get long, avoid a wrap in a narrow window.
        // Prefer showing edit_submode_extra. With external messages there
        // is no imposed limit.
        if (ui_has(kUIMessages)) {
          length = INT_MAX;
        } else {
          length = (Rows - msg_row) * Columns - 3;
        }
        if (edit_submode_extra != NULL) {
          length -= vim_strsize(edit_submode_extra);
        }
        if (length > 0) {
          if (edit_submode_pre != NULL) {
            length -= vim_strsize(edit_submode_pre);
          }
          if (length - vim_strsize(edit_submode) > 0) {
            if (edit_submode_pre != NULL) {
              msg_puts_hl(edit_submode_pre, hl_id, false);
            }
            msg_puts_hl(edit_submode, hl_id, false);
          }
          if (edit_submode_extra != NULL) {
            msg_puts_hl(" ", hl_id, false);  // Add a space in between.
            int sub_id = edit_submode_highl < HLF_COUNT ? (int)edit_submode_highl : hl_id;
            msg_puts_hl(edit_submode_extra, sub_id, false);
          }
        }
      } else {
        if (State & MODE_TERMINAL) {
          msg_puts_hl(_(" TERMINAL"), hl_id, false);
        } else if (State & VREPLACE_FLAG) {
          msg_puts_hl(_(" VREPLACE"), hl_id, false);
        } else if (State & REPLACE_FLAG) {
          msg_puts_hl(_(" REPLACE"), hl_id, false);
        } else if (State & MODE_INSERT) {
          if (p_ri) {
            msg_puts_hl(_(" REVERSE"), hl_id, false);
          }
          msg_puts_hl(_(" INSERT"), hl_id, false);
        } else if (restart_edit == 'I' || restart_edit == 'i'
                   || restart_edit == 'a' || restart_edit == 'A') {
          if (curbuf->terminal) {
            msg_puts_hl(_(" (terminal)"), hl_id, false);
          } else {
            msg_puts_hl(_(" (insert)"), hl_id, false);
          }
        } else if (restart_edit == 'R') {
          msg_puts_hl(_(" (replace)"), hl_id, false);
        } else if (restart_edit == 'V') {
          msg_puts_hl(_(" (vreplace)"), hl_id, false);
        }
        if (State & MODE_LANGMAP) {
          if (curwin->w_p_arab) {
            msg_puts_hl(_(" Arabic"), hl_id, false);
          } else if (get_keymap_str(curwin, " (%s)", NameBuff, MAXPATHL)) {
            msg_puts_hl(NameBuff, hl_id, false);
          }
        }
        if ((State & MODE_INSERT) && p_paste) {
          msg_puts_hl(_(" (paste)"), hl_id, false);
        }

        if (VIsual_active) {
          char *p;

          // Don't concatenate separate words to avoid translation
          // problems.
          switch ((VIsual_select ? 4 : 0)
                  + (VIsual_mode == Ctrl_V) * 2
                  + (VIsual_mode == 'V')) {
          case 0:
            p = N_(" VISUAL"); break;
          case 1:
            p = N_(" VISUAL LINE"); break;
          case 2:
            p = N_(" VISUAL BLOCK"); break;
          case 4:
            p = N_(" SELECT"); break;
          case 5:
            p = N_(" SELECT LINE"); break;
          default:
            p = N_(" SELECT BLOCK"); break;
          }
          msg_puts_hl(_(p), hl_id, false);
        }
        msg_puts_hl(" --", hl_id, false);
      }

      need_clear = true;
    }
    if (reg_recording != 0
        && edit_submode == NULL             // otherwise it gets too long
        ) {
      recording_mode(hl_id);
      need_clear = true;
    }

    mode_displayed = true;
    if (need_clear || clear_cmdline || redraw_mode) {
      msg_clr_eos();
    }
    msg_didout = false;                 // overwrite this message
    length = msg_col;
    msg_col = 0;
    msg_no_more = false;
    lines_left = save_lines_left;
    need_wait_return = nwr_save;        // never ask for hit-return for this
  } else if (clear_cmdline && msg_silent == 0) {
    // Clear the whole command line.  Will reset "clear_cmdline".
    msg_clr_cmdline();
  } else if (redraw_mode) {
    msg_pos_mode();
    msg_clr_eos();
  }

  // NB: also handles clearing the showmode if it was empty or disabled
  msg_ext_flush_showmode();

  // In Visual mode the size of the selected area must be redrawn.
  if (VIsual_active) {
    clear_showcmd();
  }

  // If the current or last window has no status line and global statusline is disabled,
  // the ruler is after the mode message and must be redrawn
  win_T *ruler_win = curwin->w_status_height == 0 ? curwin : lastwin_nofloating();
  if (redrawing() && ruler_win->w_status_height == 0 && global_stl_height() == 0
      && !(p_ch == 0 && !ui_has(kUIMessages))) {
    if (!ui_has(kUIMessages)) {
      grid_line_start(&msg_grid_adj, Rows - 1);
    }
    win_redr_ruler(ruler_win);
    if (!ui_has(kUIMessages)) {
      grid_line_flush();
    }
  }

  redraw_cmdline = false;
  redraw_mode = false;
  clear_cmdline = false;

  return length;
}

/// Position for a mode message.
static void msg_pos_mode(void)
{
  msg_col = 0;
  msg_row = Rows - 1;
}

/// Delete mode message.  Used when ESC is typed which is expected to end
/// Insert mode (but Insert mode didn't end yet!).
/// Caller should check "mode_displayed".
void unshowmode(bool force)
{
  // Don't delete it right now, when not redrawing or inside a mapping.
  if (!redrawing() || (!force && char_avail() && !KeyTyped)) {
    redraw_cmdline = true;  // delete mode later
  } else {
    clearmode();
  }
}

// Clear the mode message.
void clearmode(void)
{
  const int save_msg_row = msg_row;
  const int save_msg_col = msg_col;

  msg_ext_ui_flush();
  msg_pos_mode();
  if (reg_recording != 0) {
    recording_mode(HLF_CM);
  }
  msg_clr_eos();
  msg_ext_flush_showmode();

  msg_col = save_msg_col;
  msg_row = save_msg_row;
}

static void recording_mode(int hl_id)
{
  if (shortmess(SHM_RECORDING)) {
    return;
  }

  msg_puts_hl(_("recording"), hl_id, false);
  char s[4];
  snprintf(s, ARRAY_SIZE(s), " @%c", reg_recording);
  msg_puts_hl(s, hl_id, false);
}

#define COL_RULER 17        // columns needed by standard ruler

/// Compute columns for ruler and shown command. 'sc_col' is also used to
/// decide what the maximum length of a message on the status line can be.
/// If there is a status line for the last window, 'sc_col' is independent
/// of 'ru_col'.
void comp_col(void)
{
  bool last_has_status = last_stl_height(false) > 0;

  sc_col = 0;
  ru_col = 0;
  if (p_ru) {
    ru_col = (ru_wid ? ru_wid : COL_RULER) + 1;
    // no last status line, adjust sc_col
    if (!last_has_status) {
      sc_col = ru_col;
    }
  }
  if (p_sc && *p_sloc == 'l') {
    sc_col += SHOWCMD_COLS;
    if (!p_ru || last_has_status) {         // no need for separating space
      sc_col++;
    }
  }
  assert(sc_col >= 0
         && INT_MIN + sc_col <= Columns);
  sc_col = Columns - sc_col;
  assert(ru_col >= 0
         && INT_MIN + ru_col <= Columns);
  ru_col = Columns - ru_col;
  if (sc_col <= 0) {            // screen too narrow, will become a mess
    sc_col = 1;
  }
  if (ru_col <= 0) {
    ru_col = 1;
  }
  set_vim_var_nr(VV_ECHOSPACE, sc_col - 1);
}

/// Redraw entire window "wp" if "auto" 'signcolumn' width has changed.
static bool win_redraw_signcols(win_T *wp)
{
  buf_T *buf = wp->w_buffer;

  if (!buf->b_signcols.autom
      && (*wp->w_p_stc != NUL || (wp->w_maxscwidth > 1 && wp->w_minscwidth != wp->w_maxscwidth))) {
    buf->b_signcols.autom = true;
    buf_signcols_count_range(buf, 0, buf->b_ml.ml_line_count, MAXLNUM, kFalse);
  }

  while (buf->b_signcols.max > 0 && buf->b_signcols.count[buf->b_signcols.max - 1] == 0) {
    buf->b_signcols.resized = true;
    buf->b_signcols.max--;
  }

  int width = MIN(wp->w_maxscwidth, buf->b_signcols.max);
  bool rebuild_stc = buf->b_signcols.resized && *wp->w_p_stc != NUL;

  if (rebuild_stc) {
    wp->w_nrwidth_line_count = 0;
  } else if (wp->w_minscwidth == 0 && wp->w_maxscwidth == 1) {
    width = buf_meta_total(buf, kMTMetaSignText) > 0;
  }

  int scwidth = wp->w_scwidth;
  wp->w_scwidth = MAX(MAX(0, wp->w_minscwidth), width);
  return (wp->w_scwidth != scwidth || rebuild_stc);
}

/// Check if horizontal separator of window "wp" at specified window corner is connected to the
/// horizontal separator of another window
/// Assumes global statusline is enabled
static bool hsep_connected(win_T *wp, WindowCorner corner)
{
  bool before = (corner == WC_TOP_LEFT || corner == WC_BOTTOM_LEFT);
  int sep_row = (corner == WC_TOP_LEFT || corner == WC_TOP_RIGHT)
                ? wp->w_winrow - 1 : W_ENDROW(wp);
  frame_T *fr = wp->w_frame;

  while (fr->fr_parent != NULL) {
    if (fr->fr_parent->fr_layout == FR_ROW && (before ? fr->fr_prev : fr->fr_next) != NULL) {
      fr = before ? fr->fr_prev : fr->fr_next;
      break;
    }
    fr = fr->fr_parent;
  }
  if (fr->fr_parent == NULL) {
    return false;
  }
  while (fr->fr_layout != FR_LEAF) {
    fr = fr->fr_child;
    if (fr->fr_parent->fr_layout == FR_ROW && before) {
      while (fr->fr_next != NULL) {
        fr = fr->fr_next;
      }
    } else {
      while (fr->fr_next != NULL && frame2win(fr)->w_winrow + fr->fr_height < sep_row) {
        fr = fr->fr_next;
      }
    }
  }

  return (sep_row == fr->fr_win->w_winrow - 1 || sep_row == W_ENDROW(fr->fr_win));
}

/// Check if vertical separator of window "wp" at specified window corner is connected to the
/// vertical separator of another window
static bool vsep_connected(win_T *wp, WindowCorner corner)
{
  bool before = (corner == WC_TOP_LEFT || corner == WC_TOP_RIGHT);
  int sep_col = (corner == WC_TOP_LEFT || corner == WC_BOTTOM_LEFT)
                ? wp->w_wincol - 1 : W_ENDCOL(wp);
  frame_T *fr = wp->w_frame;

  while (fr->fr_parent != NULL) {
    if (fr->fr_parent->fr_layout == FR_COL && (before ? fr->fr_prev : fr->fr_next) != NULL) {
      fr = before ? fr->fr_prev : fr->fr_next;
      break;
    }
    fr = fr->fr_parent;
  }
  if (fr->fr_parent == NULL) {
    return false;
  }
  while (fr->fr_layout != FR_LEAF) {
    fr = fr->fr_child;
    if (fr->fr_parent->fr_layout == FR_COL && before) {
      while (fr->fr_next != NULL) {
        fr = fr->fr_next;
      }
    } else {
      while (fr->fr_next != NULL && frame2win(fr)->w_wincol + fr->fr_width < sep_col) {
        fr = fr->fr_next;
      }
    }
  }

  return (sep_col == fr->fr_win->w_wincol - 1 || sep_col == W_ENDCOL(fr->fr_win));
}

/// Draw the vertical separator right of window "wp"
static void draw_vsep_win(win_T *wp)
{
  if (!wp->w_vsep_width) {
    return;
  }

  // draw the vertical separator right of this window
  for (int row = wp->w_winrow; row < W_ENDROW(wp); row++) {
    grid_line_start(&default_grid, row);
    grid_line_put_schar(W_ENDCOL(wp), wp->w_p_fcs_chars.vert, win_hl_attr(wp, HLF_C));
    grid_line_flush();
  }
}

/// Draw the horizontal separator below window "wp"
static void draw_hsep_win(win_T *wp)
{
  if (!wp->w_hsep_height) {
    return;
  }

  // draw the horizontal separator below this window
  grid_line_start(&default_grid, W_ENDROW(wp));
  grid_line_fill(wp->w_wincol, W_ENDCOL(wp), wp->w_p_fcs_chars.horiz, win_hl_attr(wp, HLF_C));
  grid_line_flush();
}

/// Get the separator connector for specified window corner of window "wp"
static schar_T get_corner_sep_connector(win_T *wp, WindowCorner corner)
{
  // It's impossible for windows to be connected neither vertically nor horizontally
  // So if they're not vertically connected, assume they're horizontally connected
  if (vsep_connected(wp, corner)) {
    if (hsep_connected(wp, corner)) {
      return wp->w_p_fcs_chars.verthoriz;
    } else if (corner == WC_TOP_LEFT || corner == WC_BOTTOM_LEFT) {
      return wp->w_p_fcs_chars.vertright;
    } else {
      return wp->w_p_fcs_chars.vertleft;
    }
  } else if (corner == WC_TOP_LEFT || corner == WC_TOP_RIGHT) {
    return wp->w_p_fcs_chars.horizdown;
  } else {
    return wp->w_p_fcs_chars.horizup;
  }
}

/// Draw separator connecting characters on the corners of window "wp"
static void draw_sep_connectors_win(win_T *wp)
{
  // Don't draw separator connectors unless global statusline is enabled and the window has
  // either a horizontal or vertical separator
  if (global_stl_height() == 0 || !(wp->w_hsep_height == 1 || wp->w_vsep_width == 1)) {
    return;
  }

  int hl = win_hl_attr(wp, HLF_C);

  // Determine which edges of the screen the window is located on so we can avoid drawing separators
  // on corners contained in those edges
  bool win_at_top;
  bool win_at_bottom = wp->w_hsep_height == 0;
  bool win_at_left;
  bool win_at_right = wp->w_vsep_width == 0;
  frame_T *frp;

  for (frp = wp->w_frame; frp->fr_parent != NULL; frp = frp->fr_parent) {
    if (frp->fr_parent->fr_layout == FR_COL && frp->fr_prev != NULL) {
      break;
    }
  }
  win_at_top = frp->fr_parent == NULL;
  for (frp = wp->w_frame; frp->fr_parent != NULL; frp = frp->fr_parent) {
    if (frp->fr_parent->fr_layout == FR_ROW && frp->fr_prev != NULL) {
      break;
    }
  }
  win_at_left = frp->fr_parent == NULL;

  // Draw the appropriate separator connector in every corner where drawing them is necessary
  // Make sure not to send cursor position updates to ui.
  bool top_left = !(win_at_top || win_at_left);
  bool top_right = !(win_at_top || win_at_right);
  bool bot_left = !(win_at_bottom || win_at_left);
  bool bot_right = !(win_at_bottom || win_at_right);

  if (top_left) {
    grid_line_start(&default_grid, wp->w_winrow - 1);
    grid_line_put_schar(wp->w_wincol - 1, get_corner_sep_connector(wp, WC_TOP_LEFT), hl);
    grid_line_flush();
  }
  if (top_right) {
    grid_line_start(&default_grid, wp->w_winrow - 1);
    grid_line_put_schar(W_ENDCOL(wp), get_corner_sep_connector(wp, WC_TOP_RIGHT), hl);
    grid_line_flush();
  }
  if (bot_left) {
    grid_line_start(&default_grid, W_ENDROW(wp));
    grid_line_put_schar(wp->w_wincol - 1, get_corner_sep_connector(wp, WC_BOTTOM_LEFT), hl);
    grid_line_flush();
  }
  if (bot_right) {
    grid_line_start(&default_grid, W_ENDROW(wp));
    grid_line_put_schar(W_ENDCOL(wp), get_corner_sep_connector(wp, WC_BOTTOM_RIGHT), hl);
    grid_line_flush();
  }
}

/// Update a single window.
///
/// This may cause the windows below it also to be redrawn (when clearing the
/// screen or scrolling lines).
///
/// How the window is redrawn depends on wp->w_redr_type.  Each type also
/// implies the one below it.
/// UPD_NOT_VALID    redraw the whole window
/// UPD_SOME_VALID   redraw the whole window but do scroll when possible
/// UPD_REDRAW_TOP   redraw the top w_upd_rows window lines, otherwise like UPD_VALID
/// UPD_INVERTED     redraw the changed part of the Visual area
/// UPD_INVERTED_ALL redraw the whole Visual area
/// UPD_VALID        1. scroll up/down to adjust for a changed w_topline
///                  2. update lines at the top when scrolled down
///                  3. redraw changed text:
///                     - if wp->w_buffer->b_mod_set set, update lines between
///                       b_mod_top and b_mod_bot.
///                     - if wp->w_redraw_top non-zero, redraw lines between
///                       wp->w_redraw_top and wp->w_redraw_bot.
///                     - continue redrawing when syntax status is invalid.
///                  4. if scrolled up, update lines at the bottom.
/// This results in three areas that may need updating:
/// top: from first row to top_end (when scrolled down)
/// mid: from mid_start to mid_end (update inversion or changed text)
/// bot: from bot_start to last row (when scrolled up)
static void win_update(win_T *wp)
{
  int top_end = 0;              // Below last row of the top area that needs
                                // updating.  0 when no top area updating.
  int mid_start = 999;          // first row of the mid area that needs
                                // updating.  999 when no mid area updating.
  int mid_end = 0;              // Below last row of the mid area that needs
                                // updating.  0 when no mid area updating.
  int bot_start = 999;          // first row of the bot area that needs
                                // updating.  999 when no bot area updating
  bool scrolled_down = false;   // true when scrolled down when w_topline got smaller a bit
  bool top_to_mod = false;      // redraw above mod_top

  int bot_scroll_start = 999;   // first line that needs to be redrawn due to
                                // scrolling. only used for EOB

  static bool recursive = false;  // being called recursively

  // Remember what happened to the previous line.
  enum {
    DID_NONE = 1,  // didn't update a line
    DID_LINE = 2,  // updated a normal line
    DID_FOLD = 3,  // updated a folded line
  } did_update = DID_NONE;

  linenr_T syntax_last_parsed = 0;              // last parsed text line
  linenr_T mod_top = 0;
  linenr_T mod_bot = 0;

  int type = wp->w_redr_type;

  if (type >= UPD_NOT_VALID) {
    wp->w_redr_status = true;
    wp->w_lines_valid = 0;
  }

  // Window is zero-height: Only need to draw the separator
  if (wp->w_grid.rows == 0) {
    // draw the horizontal separator below this window
    draw_hsep_win(wp);
    draw_sep_connectors_win(wp);
    wp->w_redr_type = 0;
    return;
  }

  // Window is zero-width: Only need to draw the separator.
  if (wp->w_grid.cols == 0) {
    // draw the vertical separator right of this window
    draw_vsep_win(wp);
    draw_sep_connectors_win(wp);
    wp->w_redr_type = 0;
    return;
  }

  buf_T *buf = wp->w_buffer;

  // reset got_int, otherwise regexp won't work
  int save_got_int = got_int;
  got_int = 0;
  // Set the time limit to 'redrawtime'.
  proftime_T syntax_tm = profile_setlimit(p_rdt);
  syn_set_timeout(&syntax_tm);

  win_extmark_arr.size = 0;

  decor_redraw_reset(wp, &decor_state);

  decor_providers_invoke_win(wp);

  FOR_ALL_WINDOWS_IN_TAB(win, curtab) {
    if (win->w_buffer == wp->w_buffer && win_redraw_signcols(win)) {
      win->w_lines_valid = 0;
      changed_line_abv_curs_win(win);
      redraw_later(win, UPD_NOT_VALID);
    }
  }

  init_search_hl(wp, &screen_search_hl);

  // Make sure skipcol is valid, it depends on various options and the window
  // width.
  if (wp->w_skipcol > 0 && wp->w_width_inner > win_col_off(wp)) {
    int w = 0;
    int width1 = wp->w_width_inner - win_col_off(wp);
    int width2 = width1 + win_col_off2(wp);
    int add = width1;

    while (w < wp->w_skipcol) {
      if (w > 0) {
        add = width2;
      }
      w += add;
    }
    if (w != wp->w_skipcol) {
      // always round down, the higher value may not be valid
      wp->w_skipcol = w - add;
    }
  }

  const int nrwidth_before = wp->w_nrwidth;
  int nrwidth_new = (wp->w_p_nu || wp->w_p_rnu || *wp->w_p_stc) ? number_width(wp) : 0;
  // Force redraw when width of 'number' or 'relativenumber' column changes.
  if (wp->w_nrwidth != nrwidth_new) {
    type = UPD_NOT_VALID;
    changed_line_abv_curs_win(wp);
    wp->w_nrwidth = nrwidth_new;
  } else {
    // Set mod_top to the first line that needs displaying because of
    // changes.  Set mod_bot to the first line after the changes.
    mod_top = wp->w_redraw_top;
    if (wp->w_redraw_bot != 0) {
      mod_bot = wp->w_redraw_bot + 1;
    } else {
      mod_bot = 0;
    }
    if (buf->b_mod_set) {
      if (mod_top == 0 || mod_top > buf->b_mod_top) {
        mod_top = buf->b_mod_top;
        // Need to redraw lines above the change that may be included
        // in a pattern match.
        if (syntax_present(wp)) {
          mod_top -= buf->b_s.b_syn_sync_linebreaks;
          mod_top = MAX(mod_top, 1);
        }
      }
      if (mod_bot == 0 || mod_bot < buf->b_mod_bot) {
        mod_bot = buf->b_mod_bot;
      }

      // When 'hlsearch' is on and using a multi-line search pattern, a
      // change in one line may make the Search highlighting in a
      // previous line invalid.  Simple solution: redraw all visible
      // lines above the change.
      // Same for a match pattern.
      if (screen_search_hl.rm.regprog != NULL
          && re_multiline(screen_search_hl.rm.regprog)) {
        top_to_mod = true;
      } else {
        const matchitem_T *cur = wp->w_match_head;
        while (cur != NULL) {
          if (cur->mit_match.regprog != NULL
              && re_multiline(cur->mit_match.regprog)) {
            top_to_mod = true;
            break;
          }
          cur = cur->mit_next;
        }
      }
    }

    if (search_hl_has_cursor_lnum > 0) {
      // CurSearch was used last time, need to redraw the line with it to
      // avoid having two matches highlighted with CurSearch.
      if (mod_top == 0 || mod_top > search_hl_has_cursor_lnum) {
        mod_top = search_hl_has_cursor_lnum;
      }
      if (mod_bot == 0 || mod_bot < search_hl_has_cursor_lnum + 1) {
        mod_bot = search_hl_has_cursor_lnum + 1;
      }
    }

    if (mod_top != 0 && hasAnyFolding(wp)) {
      // A change in a line can cause lines above it to become folded or
      // unfolded.  Find the top most buffer line that may be affected.
      // If the line was previously folded and displayed, get the first
      // line of that fold.  If the line is folded now, get the first
      // folded line.  Use the minimum of these two.

      // Find last valid w_lines[] entry above mod_top.  Set lnumt to
      // the line below it.  If there is no valid entry, use w_topline.
      // Find the first valid w_lines[] entry below mod_bot.  Set lnumb
      // to this line.  If there is no valid entry, use MAXLNUM.
      linenr_T lnumt = wp->w_topline;
      linenr_T lnumb = MAXLNUM;
      for (int i = 0; i < wp->w_lines_valid; i++) {
        if (wp->w_lines[i].wl_valid) {
          if (wp->w_lines[i].wl_lastlnum < mod_top) {
            lnumt = wp->w_lines[i].wl_lastlnum + 1;
          }
          if (lnumb == MAXLNUM && wp->w_lines[i].wl_lnum >= mod_bot) {
            lnumb = wp->w_lines[i].wl_lnum;
            // When there is a fold column it might need updating
            // in the next line ("J" just above an open fold).
            if (compute_foldcolumn(wp, 0) > 0) {
              lnumb++;
            }
          }
        }
      }

      hasFolding(wp, mod_top, &mod_top, NULL);
      mod_top = MIN(mod_top, lnumt);

      // Now do the same for the bottom line (one above mod_bot).
      mod_bot--;
      hasFolding(wp, mod_bot, NULL, &mod_bot);
      mod_bot++;
      mod_bot = MAX(mod_bot, lnumb);
    }

    // When a change starts above w_topline and the end is below
    // w_topline, start redrawing at w_topline.
    // If the end of the change is above w_topline: do like no change was
    // made, but redraw the first line to find changes in syntax.
    if (mod_top != 0 && mod_top < wp->w_topline) {
      if (mod_bot > wp->w_topline) {
        mod_top = wp->w_topline;
      } else if (syntax_present(wp)) {
        top_end = 1;
      }
    }
  }

  wp->w_redraw_top = 0;  // reset for next time
  wp->w_redraw_bot = 0;
  search_hl_has_cursor_lnum = 0;

  // When only displaying the lines at the top, set top_end.  Used when
  // window has scrolled down for msg_scrolled.
  if (type == UPD_REDRAW_TOP) {
    int j = 0;
    for (int i = 0; i < wp->w_lines_valid; i++) {
      j += wp->w_lines[i].wl_size;
      if (j >= wp->w_upd_rows) {
        top_end = j;
        break;
      }
    }
    if (top_end == 0) {
      // not found (cannot happen?): redraw everything
      type = UPD_NOT_VALID;
    } else {
      // top area defined, the rest is UPD_VALID
      type = UPD_VALID;
    }
  }

  // If there are no changes on the screen that require a complete redraw,
  // handle three cases:
  // 1: we are off the top of the screen by a few lines: scroll down
  // 2: wp->w_topline is below wp->w_lines[0].wl_lnum: may scroll up
  // 3: wp->w_topline is wp->w_lines[0].wl_lnum: find first entry in
  //    w_lines[] that needs updating.
  if ((type == UPD_VALID || type == UPD_SOME_VALID
       || type == UPD_INVERTED || type == UPD_INVERTED_ALL)
      && !wp->w_botfill && !wp->w_old_botfill) {
    if (mod_top != 0
        && wp->w_topline == mod_top
        && (!wp->w_lines[0].wl_valid
            || wp->w_topline == wp->w_lines[0].wl_lnum)) {
      // w_topline is the first changed line and window is not scrolled,
      // the scrolling from changed lines will be done further down.
    } else if (wp->w_lines[0].wl_valid
               && (wp->w_topline < wp->w_lines[0].wl_lnum
                   || (wp->w_topline == wp->w_lines[0].wl_lnum
                       && wp->w_topfill > wp->w_old_topfill))) {
      // New topline is above old topline: May scroll down.
      int j;
      if (hasAnyFolding(wp)) {
        // count the number of lines we are off, counting a sequence
        // of folded lines as one
        j = 0;
        for (linenr_T ln = wp->w_topline; ln < wp->w_lines[0].wl_lnum; ln++) {
          j++;
          if (j >= wp->w_grid.rows - 2) {
            break;
          }
          hasFolding(wp, ln, NULL, &ln);
        }
      } else {
        j = wp->w_lines[0].wl_lnum - wp->w_topline;
      }
      if (j < wp->w_grid.rows - 2) {               // not too far off
        int i = plines_m_win(wp, wp->w_topline, wp->w_lines[0].wl_lnum - 1, wp->w_height_inner);
        // insert extra lines for previously invisible filler lines
        if (wp->w_lines[0].wl_lnum != wp->w_topline) {
          i += win_get_fill(wp, wp->w_lines[0].wl_lnum) - wp->w_old_topfill;
        }
        if (i != 0 && i < wp->w_grid.rows - 2) {  // less than a screen off
          // Try to insert the correct number of lines.
          // If not the last window, delete the lines at the bottom.
          // win_ins_lines may fail when the terminal can't do it.
          win_scroll_lines(wp, 0, i);
          bot_scroll_start = 0;
          if (wp->w_lines_valid != 0) {
            // Need to update rows that are new, stop at the
            // first one that scrolled down.
            top_end = i;
            scrolled_down = true;

            // Move the entries that were scrolled, disable
            // the entries for the lines to be redrawn.
            if ((wp->w_lines_valid += (linenr_T)j) > wp->w_grid.rows) {
              wp->w_lines_valid = wp->w_grid.rows;
            }
            int idx;
            for (idx = wp->w_lines_valid; idx - j >= 0; idx--) {
              wp->w_lines[idx] = wp->w_lines[idx - j];
            }
            while (idx >= 0) {
              wp->w_lines[idx--].wl_valid = false;
            }
          }
        } else {
          mid_start = 0;  // redraw all lines
        }
      } else {
        mid_start = 0;  // redraw all lines
      }
    } else {
      // New topline is at or below old topline: May scroll up.
      // When topline didn't change, find first entry in w_lines[] that
      // needs updating.

      // try to find wp->w_topline in wp->w_lines[].wl_lnum
      int j = -1;
      int row = 0;
      for (int i = 0; i < wp->w_lines_valid; i++) {
        if (wp->w_lines[i].wl_valid
            && wp->w_lines[i].wl_lnum == wp->w_topline) {
          j = i;
          break;
        }
        row += wp->w_lines[i].wl_size;
      }
      if (j == -1) {
        // if wp->w_topline is not in wp->w_lines[].wl_lnum redraw all
        // lines
        mid_start = 0;
      } else {
        // Try to delete the correct number of lines.
        // wp->w_topline is at wp->w_lines[i].wl_lnum.

        // If the topline didn't change, delete old filler lines,
        // otherwise delete filler lines of the new topline...
        if (wp->w_lines[0].wl_lnum == wp->w_topline) {
          row += wp->w_old_topfill;
        } else {
          row += win_get_fill(wp, wp->w_topline);
        }
        // ... but don't delete new filler lines.
        row -= wp->w_topfill;
        if (row > 0) {
          win_scroll_lines(wp, 0, -row);
          bot_start = wp->w_grid.rows - row;
          bot_scroll_start = bot_start;
        }
        if ((row == 0 || bot_start < 999) && wp->w_lines_valid != 0) {
          // Skip the lines (below the deleted lines) that are still
          // valid and don't need redrawing.    Copy their info
          // upwards, to compensate for the deleted lines.  Set
          // bot_start to the first row that needs redrawing.
          bot_start = 0;
          int idx = 0;
          while (true) {
            wp->w_lines[idx] = wp->w_lines[j];
            // stop at line that didn't fit, unless it is still
            // valid (no lines deleted)
            if (row > 0 && bot_start + row
                + (int)wp->w_lines[j].wl_size > wp->w_grid.rows) {
              wp->w_lines_valid = idx + 1;
              break;
            }
            bot_start += wp->w_lines[idx++].wl_size;

            // stop at the last valid entry in w_lines[].wl_size
            if (++j >= wp->w_lines_valid) {
              wp->w_lines_valid = idx;
              break;
            }
          }

          // Correct the first entry for filler lines at the top
          // when it won't get updated below.
          if (win_may_fill(wp) && bot_start > 0) {
            int n = plines_win_nofill(wp, wp->w_topline, false) + wp->w_topfill
                    - adjust_plines_for_skipcol(wp);
            n = MIN(n, wp->w_height_inner);
            wp->w_lines[0].wl_size = (uint16_t)n;
          }
        }
      }
    }

    // When starting redraw in the first line, redraw all lines.
    if (mid_start == 0) {
      mid_end = wp->w_grid.rows;
    }
  } else {
    // Not UPD_VALID or UPD_INVERTED: redraw all lines.
    mid_start = 0;
    mid_end = wp->w_grid.rows;
  }

  if (type == UPD_SOME_VALID) {
    // UPD_SOME_VALID: redraw all lines.
    mid_start = 0;
    mid_end = wp->w_grid.rows;
    type = UPD_NOT_VALID;
  }

  // check if we are updating or removing the inverted part
  if ((VIsual_active && buf == curwin->w_buffer)
      || (wp->w_old_cursor_lnum != 0 && type != UPD_NOT_VALID)) {
    linenr_T from, to;

    if (VIsual_active) {
      if (VIsual_mode != wp->w_old_visual_mode || type == UPD_INVERTED_ALL) {
        // If the type of Visual selection changed, redraw the whole
        // selection.  Also when the ownership of the X selection is
        // gained or lost.
        if (curwin->w_cursor.lnum < VIsual.lnum) {
          from = curwin->w_cursor.lnum;
          to = VIsual.lnum;
        } else {
          from = VIsual.lnum;
          to = curwin->w_cursor.lnum;
        }
        // redraw more when the cursor moved as well
        from = MIN(MIN(from, wp->w_old_cursor_lnum), wp->w_old_visual_lnum);
        to = MAX(MAX(to, wp->w_old_cursor_lnum), wp->w_old_visual_lnum);
      } else {
        // Find the line numbers that need to be updated: The lines
        // between the old cursor position and the current cursor
        // position.  Also check if the Visual position changed.
        if (curwin->w_cursor.lnum < wp->w_old_cursor_lnum) {
          from = curwin->w_cursor.lnum;
          to = wp->w_old_cursor_lnum;
        } else {
          from = wp->w_old_cursor_lnum;
          to = curwin->w_cursor.lnum;
          if (from == 0) {              // Visual mode just started
            from = to;
          }
        }

        if (VIsual.lnum != wp->w_old_visual_lnum
            || VIsual.col != wp->w_old_visual_col) {
          if (wp->w_old_visual_lnum < from
              && wp->w_old_visual_lnum != 0) {
            from = wp->w_old_visual_lnum;
          }
          to = MAX(MAX(to, wp->w_old_visual_lnum), VIsual.lnum);
          from = MIN(from, VIsual.lnum);
        }
      }

      // If in block mode and changed column or curwin->w_curswant:
      // update all lines.
      // First compute the actual start and end column.
      if (VIsual_mode == Ctrl_V) {
        colnr_T fromc, toc;
        unsigned save_ve_flags = curwin->w_ve_flags;

        if (curwin->w_p_lbr) {
          curwin->w_ve_flags = kOptVeFlagAll;
        }

        getvcols(wp, &VIsual, &curwin->w_cursor, &fromc, &toc);
        toc++;
        curwin->w_ve_flags = save_ve_flags;
        // Highlight to the end of the line, unless 'virtualedit' has
        // "block".
        if (curwin->w_curswant == MAXCOL) {
          if (get_ve_flags(curwin) & kOptVeFlagBlock) {
            pos_T pos;
            int cursor_above = curwin->w_cursor.lnum < VIsual.lnum;

            // Need to find the longest line.
            toc = 0;
            pos.coladd = 0;
            for (pos.lnum = curwin->w_cursor.lnum;
                 cursor_above ? pos.lnum <= VIsual.lnum : pos.lnum >= VIsual.lnum;
                 pos.lnum += cursor_above ? 1 : -1) {
              colnr_T t;

              pos.col = (colnr_T)strlen(ml_get_buf(wp->w_buffer, pos.lnum));
              getvvcol(wp, &pos, NULL, NULL, &t);
              toc = MAX(toc, t);
            }
            toc++;
          } else {
            toc = MAXCOL;
          }
        }

        if (fromc != wp->w_old_cursor_fcol
            || toc != wp->w_old_cursor_lcol) {
          from = MIN(from, VIsual.lnum);
          to = MAX(to, VIsual.lnum);
        }
        wp->w_old_cursor_fcol = fromc;
        wp->w_old_cursor_lcol = toc;
      }
    } else {
      // Use the line numbers of the old Visual area.
      if (wp->w_old_cursor_lnum < wp->w_old_visual_lnum) {
        from = wp->w_old_cursor_lnum;
        to = wp->w_old_visual_lnum;
      } else {
        from = wp->w_old_visual_lnum;
        to = wp->w_old_cursor_lnum;
      }
    }

    // There is no need to update lines above the top of the window.
    from = MAX(from, wp->w_topline);

    // If we know the value of w_botline, use it to restrict the update to
    // the lines that are visible in the window.
    if (wp->w_valid & VALID_BOTLINE) {
      from = MIN(from, wp->w_botline - 1);
      to = MIN(to, wp->w_botline - 1);
    }

    // Find the minimal part to be updated.
    // Watch out for scrolling that made entries in w_lines[] invalid.
    // E.g., CTRL-U makes the first half of w_lines[] invalid and sets
    // top_end; need to redraw from top_end to the "to" line.
    // A middle mouse click with a Visual selection may change the text
    // above the Visual area and reset wl_valid, do count these for
    // mid_end (in srow).
    if (mid_start > 0) {
      linenr_T lnum = wp->w_topline;
      int idx = 0;
      int srow = 0;
      if (scrolled_down) {
        mid_start = top_end;
      } else {
        mid_start = 0;
      }
      while (lnum < from && idx < wp->w_lines_valid) {          // find start
        if (wp->w_lines[idx].wl_valid) {
          mid_start += wp->w_lines[idx].wl_size;
        } else if (!scrolled_down) {
          srow += wp->w_lines[idx].wl_size;
        }
        idx++;
        if (idx < wp->w_lines_valid && wp->w_lines[idx].wl_valid) {
          lnum = wp->w_lines[idx].wl_lnum;
        } else {
          lnum++;
        }
      }
      srow += mid_start;
      mid_end = wp->w_grid.rows;
      for (; idx < wp->w_lines_valid; idx++) {                  // find end
        if (wp->w_lines[idx].wl_valid
            && wp->w_lines[idx].wl_lnum >= to + 1) {
          // Only update until first row of this line
          mid_end = srow;
          break;
        }
        srow += wp->w_lines[idx].wl_size;
      }
    }
  }

  if (VIsual_active && buf == curwin->w_buffer) {
    wp->w_old_visual_mode = (char)VIsual_mode;
    wp->w_old_cursor_lnum = curwin->w_cursor.lnum;
    wp->w_old_visual_lnum = VIsual.lnum;
    wp->w_old_visual_col = VIsual.col;
    wp->w_old_curswant = curwin->w_curswant;
  } else {
    wp->w_old_visual_mode = 0;
    wp->w_old_cursor_lnum = 0;
    wp->w_old_visual_lnum = 0;
    wp->w_old_visual_col = 0;
  }

  foldinfo_T cursorline_fi = { 0 };
  wp->w_cursorline = win_cursorline_standout(wp) ? wp->w_cursor.lnum : 0;
  if (wp->w_p_cul) {
    // Make sure that the cursorline on a closed fold is redrawn
    cursorline_fi = fold_info(wp, wp->w_cursor.lnum);
    if (cursorline_fi.fi_level != 0 && cursorline_fi.fi_lines > 0) {
      wp->w_cursorline = cursorline_fi.fi_lnum;
    }
  }

  win_check_ns_hl(wp);

  spellvars_T spv = { 0 };
  linenr_T lnum = wp->w_topline;  // first line shown in window
  // Initialize spell related variables for the first drawn line.
  if (spell_check_window(wp)) {
    spv.spv_has_spell = true;
    spv.spv_unchanged = mod_top == 0;
  }

  // Update all the window rows.
  int idx = 0;                    // first entry in w_lines[].wl_size
  int row = 0;                    // current window row to display
  int srow = 0;                   // starting row of the current line

  bool eof = false;             // if true, we hit the end of the file
  bool didline = false;         // if true, we finished the last line
  while (true) {
    // stop updating when reached the end of the window (check for _past_
    // the end of the window is at the end of the loop)
    if (row == wp->w_grid.rows) {
      didline = true;
      break;
    }

    // stop updating when hit the end of the file
    if (lnum > buf->b_ml.ml_line_count) {
      eof = true;
      break;
    }

    // Remember the starting row of the line that is going to be dealt
    // with.  It is used further down when the line doesn't fit.
    srow = row;

    // Update a line when it is in an area that needs updating, when it
    // has changes or w_lines[idx] is invalid.
    // "bot_start" may be halfway a wrapped line after using
    // win_scroll_lines(), check if the current line includes it.
    // When syntax folding is being used, the saved syntax states will
    // already have been updated, we can't see where the syntax state is
    // the same again, just update until the end of the window.
    if (row < top_end
        || (row >= mid_start && row < mid_end)
        || top_to_mod
        || idx >= wp->w_lines_valid
        || (row + wp->w_lines[idx].wl_size > bot_start)
        || (mod_top != 0
            && (lnum == mod_top
                || (lnum >= mod_top
                    && (lnum < mod_bot
                        || did_update == DID_FOLD
                        || (did_update == DID_LINE
                            && syntax_present(wp)
                            && ((foldmethodIsSyntax(wp)
                                 && hasAnyFolding(wp))
                                || syntax_check_changed(lnum)))
                        // match in fixed position might need redraw
                        // if lines were inserted or deleted
                        || (wp->w_match_head != NULL
                            && buf->b_mod_set && buf->b_mod_xlines != 0)))))
        || lnum == wp->w_cursorline
        || lnum == wp->w_last_cursorline) {
      if (lnum == mod_top) {
        top_to_mod = false;
      }

      // When at start of changed lines: May scroll following lines
      // up or down to minimize redrawing.
      // Don't do this when the change continues until the end.
      // Don't scroll when dollar_vcol >= 0, keep the "$".
      // Don't scroll when redrawing the top, scrolled already above.
      if (lnum == mod_top
          && mod_bot != MAXLNUM
          && !(dollar_vcol >= 0 && mod_bot == mod_top + 1)
          && row >= top_end) {
        int old_rows = 0;
        linenr_T l;
        int i;

        // Count the old number of window rows, using w_lines[], which
        // should still contain the sizes for the lines as they are
        // currently displayed.
        for (i = idx; i < wp->w_lines_valid; i++) {
          // Only valid lines have a meaningful wl_lnum.  Invalid
          // lines are part of the changed area.
          if (wp->w_lines[i].wl_valid
              && wp->w_lines[i].wl_lnum == mod_bot) {
            break;
          }
          old_rows += wp->w_lines[i].wl_size;
          if (wp->w_lines[i].wl_valid
              && wp->w_lines[i].wl_lastlnum + 1 == mod_bot) {
            // Must have found the last valid entry above mod_bot.
            // Add following invalid entries.
            i++;
            while (i < wp->w_lines_valid
                   && !wp->w_lines[i].wl_valid) {
              old_rows += wp->w_lines[i++].wl_size;
            }
            break;
          }
        }

        if (i >= wp->w_lines_valid) {
          // We can't find a valid line below the changed lines,
          // need to redraw until the end of the window.
          // Inserting/deleting lines has no use.
          bot_start = 0;
          bot_scroll_start = 0;
        } else {
          int new_rows = 0;
          // Able to count old number of rows: Count new window
          // rows, and may insert/delete lines
          int j = idx;
          for (l = lnum; l < mod_bot; l++) {
            if (hasFolding(wp, l, NULL, &l)) {
              new_rows++;
            } else if (l == wp->w_topline) {
              int n = plines_win_nofill(wp, l, false) + wp->w_topfill
                      - adjust_plines_for_skipcol(wp);
              n = MIN(n, wp->w_height_inner);
              new_rows += n;
            } else {
              new_rows += plines_win(wp, l, true);
            }
            j++;
            if (new_rows > wp->w_grid.rows - row - 2) {
              // it's getting too much, must redraw the rest
              new_rows = 9999;
              break;
            }
          }
          int xtra_rows = new_rows - old_rows;
          if (xtra_rows < 0) {
            // May scroll text up.  If there is not enough
            // remaining text or scrolling fails, must redraw the
            // rest.  If scrolling works, must redraw the text
            // below the scrolled text.
            if (row - xtra_rows >= wp->w_grid.rows - 2) {
              mod_bot = MAXLNUM;
            } else {
              win_scroll_lines(wp, row, xtra_rows);
              bot_start = wp->w_grid.rows + xtra_rows;
              bot_scroll_start = bot_start;
            }
          } else if (xtra_rows > 0) {
            // May scroll text down.  If there is not enough
            // remaining text of scrolling fails, must redraw the
            // rest.
            if (row + xtra_rows >= wp->w_grid.rows - 2) {
              mod_bot = MAXLNUM;
            } else {
              win_scroll_lines(wp, row + old_rows, xtra_rows);
              bot_scroll_start = 0;
              if (top_end > row + old_rows) {
                // Scrolled the part at the top that requires
                // updating down.
                top_end += xtra_rows;
              }
            }
          }

          // When not updating the rest, may need to move w_lines[]
          // entries.
          if (mod_bot != MAXLNUM && i != j) {
            if (j < i) {
              int x = row + new_rows;

              // move entries in w_lines[] upwards
              while (true) {
                // stop at last valid entry in w_lines[]
                if (i >= wp->w_lines_valid) {
                  wp->w_lines_valid = j;
                  break;
                }
                wp->w_lines[j] = wp->w_lines[i];
                // stop at a line that won't fit
                if (x + (int)wp->w_lines[j].wl_size
                    > wp->w_grid.rows) {
                  wp->w_lines_valid = j + 1;
                  break;
                }
                x += wp->w_lines[j++].wl_size;
                i++;
              }
              bot_start = MIN(bot_start, x);
            } else {       // j > i
                           // move entries in w_lines[] downwards
              j -= i;
              wp->w_lines_valid += (linenr_T)j;
              wp->w_lines_valid = MIN(wp->w_lines_valid, wp->w_grid.rows);
              for (i = wp->w_lines_valid; i - j >= idx; i--) {
                wp->w_lines[i] = wp->w_lines[i - j];
              }

              // The w_lines[] entries for inserted lines are
              // now invalid, but wl_size may be used above.
              // Reset to zero.
              while (i >= idx) {
                wp->w_lines[i].wl_size = 0;
                wp->w_lines[i--].wl_valid = false;
              }
            }
          }
        }
      }

      // When lines are folded, display one line for all of them.
      // Otherwise, display normally (can be several display lines when
      // 'wrap' is on).
      foldinfo_T foldinfo = wp->w_p_cul && lnum == wp->w_cursor.lnum
                            ? cursorline_fi : fold_info(wp, lnum);

      if (foldinfo.fi_lines == 0
          && idx < wp->w_lines_valid
          && wp->w_lines[idx].wl_valid
          && wp->w_lines[idx].wl_lnum == lnum
          && lnum > wp->w_topline
          && !(dy_flags & (kOptDyFlagLastline | kOptDyFlagTruncate))
          && srow + wp->w_lines[idx].wl_size > wp->w_grid.rows
          && win_get_fill(wp, lnum) == 0) {
        // This line is not going to fit.  Don't draw anything here,
        // will draw "@  " lines below.
        row = wp->w_grid.rows + 1;
      } else {
        prepare_search_hl(wp, &screen_search_hl, lnum);
        // Let the syntax stuff know we skipped a few lines.
        if (syntax_last_parsed != 0 && syntax_last_parsed + 1 < lnum
            && syntax_present(wp)) {
          syntax_end_parsing(wp, syntax_last_parsed + 1);
        }

        bool display_buf_line = (foldinfo.fi_lines == 0 || *wp->w_p_fdt == NUL);

        // Display one line
        spellvars_T zero_spv = { 0 };
        row = win_line(wp, lnum, srow, wp->w_grid.rows, 0,
                       display_buf_line ? &spv : &zero_spv, foldinfo);

        if (display_buf_line) {
          syntax_last_parsed = lnum;
        } else {
          spv.spv_capcol_lnum = 0;
        }

        if (foldinfo.fi_lines == 0) {
          wp->w_lines[idx].wl_folded = false;
          wp->w_lines[idx].wl_lastlnum = lnum;
          did_update = DID_LINE;
        } else {
          foldinfo.fi_lines--;
          wp->w_lines[idx].wl_folded = true;
          wp->w_lines[idx].wl_lastlnum = lnum + foldinfo.fi_lines;
          did_update = DID_FOLD;
        }
      }

      wp->w_lines[idx].wl_lnum = lnum;
      wp->w_lines[idx].wl_valid = true;

      if (row > wp->w_grid.rows) {         // past end of grid
        // we may need the size of that too long line later on
        if (dollar_vcol == -1) {
          wp->w_lines[idx].wl_size = (uint16_t)plines_win(wp, lnum, true);
        }
        idx++;
        break;
      }
      if (dollar_vcol == -1) {
        wp->w_lines[idx].wl_size = (uint16_t)(row - srow);
      }
      idx++;
      lnum += foldinfo.fi_lines + 1;
    } else {
      // If:
      // - 'number' is set and below inserted/deleted lines, or
      // - 'relativenumber' is set and cursor moved vertically,
      // the text doesn't need to be redrawn, but the number column does.
      if ((wp->w_p_nu && mod_top != 0 && lnum >= mod_bot
           && buf->b_mod_set && buf->b_mod_xlines != 0)
          || (wp->w_p_rnu && wp->w_last_cursor_lnum_rnu != wp->w_cursor.lnum)) {
        foldinfo_T info = wp->w_p_cul && lnum == wp->w_cursor.lnum
                          ? cursorline_fi : fold_info(wp, lnum);
        win_line(wp, lnum, srow, wp->w_grid.rows, wp->w_lines[idx].wl_size, &spv, info);
      }

      // This line does not need to be drawn, advance to the next one.
      row += wp->w_lines[idx++].wl_size;
      if (row > wp->w_grid.rows) {  // past end of screen
        break;
      }
      lnum = wp->w_lines[idx - 1].wl_lastlnum + 1;
      did_update = DID_NONE;
      spv.spv_capcol_lnum = 0;
    }

    // 'statuscolumn' width has changed or errored, start from the top.
    if (wp->w_redr_statuscol) {
redr_statuscol:
      wp->w_redr_statuscol = false;
      idx = 0;
      row = 0;
      lnum = wp->w_topline;
      wp->w_lines_valid = 0;
      wp->w_valid &= ~VALID_WCOL;
      decor_redraw_reset(wp, &decor_state);
      decor_providers_invoke_win(wp);
      continue;
    }

    if (lnum > buf->b_ml.ml_line_count) {
      eof = true;
      break;
    }
  }
  // End of loop over all window lines.

  // Now that the window has been redrawn with the old and new cursor line,
  // update w_last_cursorline.
  wp->w_last_cursorline = wp->w_cursorline;

  wp->w_last_cursor_lnum_rnu = wp->w_p_rnu ? wp->w_cursor.lnum : 0;

  wp->w_lines_valid = MAX(wp->w_lines_valid, idx);

  // Let the syntax stuff know we stop parsing here.
  if (syntax_last_parsed != 0 && syntax_present(wp)) {
    syntax_end_parsing(wp, syntax_last_parsed + 1);
  }

  const linenr_T old_botline = wp->w_botline;

  // If we didn't hit the end of the file, and we didn't finish the last
  // line we were working on, then the line didn't fit.
  wp->w_empty_rows = 0;
  wp->w_filler_rows = 0;
  if (!eof && !didline) {
    int at_attr = hl_combine_attr(win_bg_attr(wp), win_hl_attr(wp, HLF_AT));
    if (lnum == wp->w_topline) {
      // Single line that does not fit!
      // Don't overwrite it, it can be edited.
      wp->w_botline = lnum + 1;
    } else if (win_get_fill(wp, lnum) >= wp->w_grid.rows - srow) {
      // Window ends in filler lines.
      wp->w_botline = lnum;
      wp->w_filler_rows = wp->w_grid.rows - srow;
    } else if (dy_flags & kOptDyFlagTruncate) {      // 'display' has "truncate"
      // Last line isn't finished: Display "@@@" in the last screen line.
      grid_line_start(&wp->w_grid, wp->w_grid.rows - 1);
      grid_line_fill(0, MIN(wp->w_grid.cols, 3), wp->w_p_fcs_chars.lastline, at_attr);
      grid_line_fill(3, wp->w_grid.cols, schar_from_ascii(' '), at_attr);
      grid_line_flush();
      set_empty_rows(wp, srow);
      wp->w_botline = lnum;
    } else if (dy_flags & kOptDyFlagLastline) {      // 'display' has "lastline"
      // Last line isn't finished: Display "@@@" at the end.
      // If this would split a doublewidth char in two, we need to display "@@@@" instead
      grid_line_start(&wp->w_grid, wp->w_grid.rows - 1);
      int width = grid_line_getchar(MAX(wp->w_grid.cols - 3, 0), NULL) == NUL ? 4 : 3;
      grid_line_fill(MAX(wp->w_grid.cols - width, 0), wp->w_grid.cols,
                     wp->w_p_fcs_chars.lastline, at_attr);
      grid_line_flush();
      set_empty_rows(wp, srow);
      wp->w_botline = lnum;
    } else {
      win_draw_end(wp, wp->w_p_fcs_chars.lastline, true, srow,
                   wp->w_grid.rows, HLF_AT);
      set_empty_rows(wp, srow);
      wp->w_botline = lnum;
    }
  } else {
    if (eof) {  // we hit the end of the file
      wp->w_botline = buf->b_ml.ml_line_count + 1;
      int j = win_get_fill(wp, wp->w_botline);
      if (j > 0 && !wp->w_botfill && row < wp->w_grid.rows) {
        // Display filler text below last line. win_line() will check
        // for ml_line_count+1 and only draw filler lines
        spellvars_T zero_spv = { 0 };
        foldinfo_T zero_foldinfo = { 0 };
        row = win_line(wp, wp->w_botline, row, wp->w_grid.rows, 0, &zero_spv, zero_foldinfo);
        if (wp->w_redr_statuscol) {
          eof = false;
          goto redr_statuscol;
        }
      }
    } else if (dollar_vcol == -1) {
      wp->w_botline = lnum;
    }

    // Make sure the rest of the screen is blank.
    // write the "eob" character from 'fillchars' to rows that aren't part
    // of the file.
    // TODO(bfredl): just keep track of the valid EOB area from last redraw?
    int lastline = bot_scroll_start;
    if (mid_end >= row) {
      lastline = MIN(lastline, mid_start);
    }
    // if (mod_bot > buf->b_ml.ml_line_count + 1) {
    if (mod_bot > buf->b_ml.ml_line_count) {
      lastline = 0;
    }

    win_draw_end(wp, wp->w_p_fcs_chars.eob, false, MAX(lastline, row),
                 wp->w_grid.rows,
                 HLF_EOB);
    set_empty_rows(wp, row);
  }

  if (wp->w_redr_type >= UPD_REDRAW_TOP) {
    draw_vsep_win(wp);
    draw_hsep_win(wp);
    draw_sep_connectors_win(wp);
  }
  syn_set_timeout(NULL);

  // Reset the type of redrawing required, the window has been updated.
  wp->w_redr_type = 0;
  wp->w_old_topfill = wp->w_topfill;
  wp->w_old_botfill = wp->w_botfill;

  // Send win_extmarks if needed
  for (size_t n = 0; n < kv_size(win_extmark_arr); n++) {
    ui_call_win_extmark(wp->w_grid_alloc.handle, wp->handle,
                        kv_A(win_extmark_arr, n).ns_id, (Integer)kv_A(win_extmark_arr, n).mark_id,
                        kv_A(win_extmark_arr, n).win_row, kv_A(win_extmark_arr, n).win_col);
  }

  if (dollar_vcol == -1) {
    // There is a trick with w_botline.  If we invalidate it on each
    // change that might modify it, this will cause a lot of expensive
    // calls to plines_win() in update_topline() each time.  Therefore the
    // value of w_botline is often approximated, and this value is used to
    // compute the value of w_topline.  If the value of w_botline was
    // wrong, check that the value of w_topline is correct (cursor is on
    // the visible part of the text).  If it's not, we need to redraw
    // again.  Mostly this just means scrolling up a few lines, so it
    // doesn't look too bad.  Only do this for the current window (where
    // changes are relevant).
    wp->w_valid |= VALID_BOTLINE;
    wp->w_viewport_invalid = true;
    if (wp == curwin && wp->w_botline != old_botline && !recursive) {
      recursive = true;
      curwin->w_valid &= ~VALID_TOPLINE;
      update_topline(curwin);  // may invalidate w_botline again
      // New redraw either due to updated topline or reset skipcol.
      if (must_redraw != 0) {
        // Don't update for changes in buffer again.
        int mod_set = curbuf->b_mod_set;
        curbuf->b_mod_set = false;
        curs_columns(curwin, true);
        win_update(curwin);
        must_redraw = 0;
        curbuf->b_mod_set = mod_set;
      }
      recursive = false;
    }
  }

  if (nrwidth_before != wp->w_nrwidth && buf->terminal) {
    terminal_check_size(buf->terminal);
  }

  // restore got_int, unless CTRL-C was hit while redrawing
  if (!got_int) {
    got_int = save_got_int;
  }
}

/// Scroll `line_count` lines at 'row' in window 'wp'.
///
/// Positive `line_count` means scrolling down, so that more space is available
/// at 'row'. Negative `line_count` implies deleting lines at `row`.
void win_scroll_lines(win_T *wp, int row, int line_count)
{
  if (!redrawing() || line_count == 0) {
    return;
  }

  // No lines are being moved, just draw over the entire area
  if (row + abs(line_count) >= wp->w_grid.rows) {
    return;
  }

  if (line_count < 0) {
    grid_del_lines(&wp->w_grid, row, -line_count,
                   wp->w_grid.rows, 0, wp->w_grid.cols);
  } else {
    grid_ins_lines(&wp->w_grid, row, line_count,
                   wp->w_grid.rows, 0, wp->w_grid.cols);
  }
}

/// Clear lines near the end of the window and mark the unused lines with "c1".
/// When "draw_margin" is true, then draw the sign/fold/number columns.
void win_draw_end(win_T *wp, schar_T c1, bool draw_margin, int startrow, int endrow, hlf_T hl)
{
  assert(hl >= 0 && hl < HLF_COUNT);
  for (int row = startrow; row < endrow; row++) {
    grid_line_start(&wp->w_grid, row);

    int n = 0;
    if (draw_margin) {
      // draw the fold column
      int fdc = MAX(0, compute_foldcolumn(wp, 0));
      n = grid_line_fill(n, n + fdc, schar_from_ascii(' '), win_hl_attr(wp, HLF_FC));

      // draw the sign column
      n = grid_line_fill(n, n + wp->w_scwidth, schar_from_ascii(' '), win_hl_attr(wp, HLF_FC));

      // draw the number column
      if ((wp->w_p_nu || wp->w_p_rnu) && vim_strchr(p_cpo, CPO_NUMCOL) == NULL) {
        int width = number_width(wp) + 1;
        n = grid_line_fill(n, n + width, schar_from_ascii(' '), win_hl_attr(wp, HLF_N));
      }
    }

    int attr = hl_combine_attr(win_bg_attr(wp), win_hl_attr(wp, (int)hl));

    if (n < wp->w_grid.cols) {
      grid_line_put_schar(n, c1, 0);  // base attr is inherited from clear
      n++;
    }

    grid_line_clear_end(n, wp->w_grid.cols, attr);

    if (wp->w_p_rl) {
      grid_line_mirror();
    }
    grid_line_flush();
  }
}

/// Compute the width of the foldcolumn.  Based on 'foldcolumn' and how much
/// space is available for window "wp", minus "col".
int compute_foldcolumn(win_T *wp, int col)
{
  int fdc = win_fdccol_count(wp);
  int wmw = wp == curwin && p_wmw == 0 ? 1 : (int)p_wmw;
  int wwidth = wp->w_grid.cols;

  return MIN(fdc, wwidth - (col + wmw));
}

/// Return the width of the 'number' and 'relativenumber' column.
/// Caller may need to check if 'number' or 'relativenumber' is set.
/// Otherwise it depends on 'numberwidth' and the line count.
int number_width(win_T *wp)
{
  linenr_T lnum;

  if (wp->w_p_rnu && !wp->w_p_nu) {
    // cursor line shows "0"
    lnum = wp->w_height_inner;
  } else {
    // cursor line shows absolute line number
    lnum = wp->w_buffer->b_ml.ml_line_count;
  }

  if (lnum == wp->w_nrwidth_line_count) {
    return wp->w_nrwidth_width;
  }
  wp->w_nrwidth_line_count = lnum;

  // reset for 'statuscolumn'
  if (*wp->w_p_stc != NUL) {
    wp->w_statuscol_line_count = 0;  // make sure width is re-estimated
    wp->w_nrwidth_width = (wp->w_p_nu || wp->w_p_rnu) * (int)wp->w_p_nuw;
    return wp->w_nrwidth_width;
  }

  int n = 0;
  do {
    lnum /= 10;
    n++;
  } while (lnum > 0);

  // 'numberwidth' gives the minimal width plus one
  n = MAX(n, (int)wp->w_p_nuw - 1);

  // If 'signcolumn' is set to 'number' and there is a sign to display, then
  // the minimal width for the number column is 2.
  if (n < 2 && buf_meta_total(wp->w_buffer, kMTMetaSignText) && wp->w_minscwidth == SCL_NUM) {
    n = 2;
  }

  wp->w_nrwidth_width = n;
  return n;
}

/// Redraw a window later, with wp->w_redr_type >= type.
///
/// Set must_redraw only if not already set to a higher value.
/// e.g. if must_redraw is UPD_CLEAR, type UPD_NOT_VALID will do nothing.
void redraw_later(win_T *wp, int type)
{
  // curwin may have been set to NULL when exiting
  assert(wp != NULL || exiting);
  if (!exiting && !redraw_not_allowed && wp->w_redr_type < type) {
    wp->w_redr_type = type;
    if (type >= UPD_NOT_VALID) {
      wp->w_lines_valid = 0;
    }
    must_redraw = MAX(must_redraw, type);  // must_redraw is the maximum of all windows
  }
}

/// Mark all windows to be redrawn later.
void redraw_all_later(int type)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    redraw_later(wp, type);
  }
  // This may be needed when switching tabs.
  set_must_redraw(type);
}

/// Set "must_redraw" to "type" unless it already has a higher value
/// or it is currently not allowed.
void set_must_redraw(int type)
{
  if (!redraw_not_allowed) {
    must_redraw = MAX(must_redraw, type);
  }
}

void screen_invalidate_highlights(void)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    redraw_later(wp, UPD_NOT_VALID);
    wp->w_grid_alloc.valid = false;
  }
}

/// Mark all windows that are editing the current buffer to be updated later.
void redraw_curbuf_later(int type)
{
  redraw_buf_later(curbuf, type);
}

void redraw_buf_later(buf_T *buf, int type)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer == buf) {
      redraw_later(wp, type);
    }
  }
}

void redraw_buf_line_later(buf_T *buf, linenr_T line, bool force)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer == buf) {
      redrawWinline(wp, MIN(line, buf->b_ml.ml_line_count));
      if (force && line > buf->b_ml.ml_line_count) {
        wp->w_redraw_bot = line;
      }
    }
  }
}

void redraw_buf_range_later(buf_T *buf, linenr_T firstline, linenr_T lastline)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer == buf
        && lastline >= wp->w_topline && firstline < wp->w_botline) {
      if (wp->w_redraw_top == 0 || wp->w_redraw_top > firstline) {
        wp->w_redraw_top = firstline;
      }
      if (wp->w_redraw_bot == 0 || wp->w_redraw_bot < lastline) {
        wp->w_redraw_bot = lastline;
      }
      redraw_later(wp, UPD_VALID);
    }
  }
}

/// called when the status bars for the buffer 'buf' need to be updated
void redraw_buf_status_later(buf_T *buf)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer == buf
        && (wp->w_status_height
            || (wp == curwin && global_stl_height())
            || wp->w_winbar_height)) {
      wp->w_redr_status = true;
      set_must_redraw(UPD_VALID);
    }
  }
}

/// Mark all status lines and window bars for redraw; used after first :cd
void status_redraw_all(void)
{
  bool is_stl_global = global_stl_height() != 0;

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if ((!is_stl_global && wp->w_status_height) || wp == curwin
        || wp->w_winbar_height) {
      wp->w_redr_status = true;
      redraw_later(wp, UPD_VALID);
    }
  }
}

/// Marks all status lines and window bars of the current buffer for redraw.
void status_redraw_curbuf(void)
{
  status_redraw_buf(curbuf);
}

/// Marks all status lines and window bars of the given buffer for redraw.
void status_redraw_buf(buf_T *buf)
{
  bool is_stl_global = global_stl_height() != 0;

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer == buf && ((!is_stl_global && wp->w_status_height)
                                || (is_stl_global && wp == curwin) || wp->w_winbar_height)) {
      wp->w_redr_status = true;
      redraw_later(wp, UPD_VALID);
    }
  }
  // Redraw the ruler if it is in the command line and was not marked for redraw above
  if (p_ru && !curwin->w_status_height && !curwin->w_redr_status) {
    redraw_cmdline = true;
    redraw_later(curwin, UPD_VALID);
  }
}

/// Redraw all status lines that need to be redrawn.
void redraw_statuslines(void)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_redr_status) {
      win_check_ns_hl(wp);
      win_redr_winbar(wp);
      win_redr_status(wp);
    }
  }

  win_check_ns_hl(NULL);
  if (redraw_tabline) {
    draw_tabline();
  }
}

/// Redraw all status lines at the bottom of frame "frp".
void win_redraw_last_status(const frame_T *frp)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (frp->fr_layout == FR_LEAF) {
    frp->fr_win->w_redr_status = true;
  } else if (frp->fr_layout == FR_ROW) {
    FOR_ALL_FRAMES(frp, frp->fr_child) {
      win_redraw_last_status(frp);
    }
  } else {
    assert(frp->fr_layout == FR_COL);
    frp = frp->fr_child;
    while (frp->fr_next != NULL) {
      frp = frp->fr_next;
    }
    win_redraw_last_status(frp);
  }
}

/// Changed something in the current window, at buffer line "lnum", that
/// requires that line and possibly other lines to be redrawn.
/// Used when entering/leaving Insert mode with the cursor on a folded line.
/// Used to remove the "$" from a change command.
/// Note that when also inserting/deleting lines w_redraw_top and w_redraw_bot
/// may become invalid and the whole window will have to be redrawn.
void redrawWinline(win_T *wp, linenr_T lnum)
  FUNC_ATTR_NONNULL_ALL
{
  if (lnum >= wp->w_topline
      && lnum < wp->w_botline) {
    if (wp->w_redraw_top == 0 || wp->w_redraw_top > lnum) {
      wp->w_redraw_top = lnum;
    }
    if (wp->w_redraw_bot == 0 || wp->w_redraw_bot < lnum) {
      wp->w_redraw_bot = lnum;
    }
    redraw_later(wp, UPD_VALID);
  }
}

/// Return true if the cursor line in window "wp" may be concealed, according
/// to the 'concealcursor' option.
bool conceal_cursor_line(const win_T *wp)
  FUNC_ATTR_NONNULL_ALL
{
  int c;

  if (*wp->w_p_cocu == NUL) {
    return false;
  }
  if (get_real_state() & MODE_VISUAL) {
    c = 'v';
  } else if (State & MODE_INSERT) {
    c = 'i';
  } else if (State & MODE_NORMAL) {
    c = 'n';
  } else if (State & MODE_CMDLINE) {
    c = 'c';
  } else {
    return false;
  }
  return vim_strchr(wp->w_p_cocu, c) != NULL;
}

/// Whether cursorline is drawn in a special way
///
/// If true, both old and new cursorline will need to be redrawn when moving cursor within windows.
bool win_cursorline_standout(const win_T *wp)
  FUNC_ATTR_NONNULL_ALL
{
  return wp->w_p_cul || (wp->w_p_cole > 0 && !conceal_cursor_line(wp));
}
