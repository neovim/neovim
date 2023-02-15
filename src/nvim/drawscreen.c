// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// drawscreen.c: Code for updating all the windows on the screen.
// This is the top level, drawline.c is the middle and grid.c/screen.c the lower level.

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
#include <stdbool.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/ascii.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand.h"
#include "nvim/decoration.h"
#include "nvim/decoration_provider.h"
#include "nvim/diff.h"
#include "nvim/drawline.h"
#include "nvim/drawscreen.h"
#include "nvim/ex_getln.h"
#include "nvim/extmark_defs.h"
#include "nvim/fold.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/highlight_group.h"
#include "nvim/insexpand.h"
#include "nvim/match.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/plines.h"
#include "nvim/popupmenu.h"
#include "nvim/pos.h"
#include "nvim/profile.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/statusline.h"
#include "nvim/syntax.h"
#include "nvim/terminal.h"
#include "nvim/types.h"
#include "nvim/ui.h"
#include "nvim/ui_compositor.h"
#include "nvim/version.h"
#include "nvim/vim.h"
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

static char *provider_err = NULL;

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
/// default_grid.Columns to access items in default_grid.chars[].  Use Rows
/// and Columns for positioning text etc. where the final size of the screen is
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
  check_for_delay(false);

  if (starting == NO_SCREEN || default_grid.chars == NULL) {
    return;
  }

  // blank out the default grid
  for (int i = 0; i < default_grid.rows; i++) {
    grid_clear_line(&default_grid, default_grid.line_offset[i],
                    default_grid.cols, true);
    default_grid.line_wraps[i] = false;
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
  int max_p_ch = Rows - min_rows() + 1;
  if (!ui_has(kUIMessages) && p_ch > 0 && p_ch > max_p_ch) {
    p_ch = max_p_ch ? max_p_ch : 1;
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
    invalidate_botline();

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

/// Redraw the parts of the screen that is marked for redraw.
///
/// Most code shouldn't call this directly, rather use redraw_later() and
/// and redraw_all_later() to mark parts of the screen as needing a redraw.
int update_screen(void)
{
  static bool did_intro = false;
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

  updating_screen = 1;

  display_tick++;  // let syntax code know we're in a next round of
                   // display updating

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
                        msg_grid.cols, false);
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
    grid_fill(&default_grid, Rows - (int)p_ch, Rows, 0, Columns, ' ', ' ', 0);
  }

  ui_comp_set_screen_valid(true);

  DecorProviders providers;
  decor_providers_start(&providers, &provider_err);

  // "start" callback could have changed highlights for global elements
  if (win_check_ns_hl(NULL)) {
    redraw_cmdline = true;
    redraw_tabline = true;
  }

  if (clear_cmdline) {          // going to clear cmdline (done below)
    check_for_delay(false);
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

  // Correct stored syntax highlighting info for changes in each displayed
  // buffer.  Each buffer must only be done once.
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    update_window_hl(wp, type >= UPD_NOT_VALID || hl_changed);

    buf_T *buf = wp->w_buffer;
    if (buf->b_mod_set) {
      if (buf->b_mod_tick_syn < display_tick
          && syntax_present(wp)) {
        syn_stack_apply_changes(buf);
        buf->b_mod_tick_syn = display_tick;
      }

      if (buf->b_mod_tick_decor < display_tick) {
        decor_providers_invoke_buf(buf, &providers, &provider_err);
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
      win_update(wp, &providers);
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

  // Reset b_mod_set flags.  Going through all windows is probably faster
  // than going through all buffers (there could be many buffers).
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    wp->w_buffer->b_mod_set = false;
  }

  updating_screen = 0;

  // Clear or redraw the command line.  Done last, because scrolling may
  // mess up the command line.
  if (clear_cmdline || redraw_cmdline || redraw_mode) {
    showmode();
  }

  // May put up an introductory message when not editing a file
  if (!did_intro) {
    maybe_intro_message();
  }
  did_intro = true;

  decor_providers_invoke_end(&providers, &provider_err);
  kvi_destroy(providers);

  // either cmdline is cleared, not drawn or mode is last drawn
  cmdline_was_last_drawn = false;
  return OK;
}

static void win_border_redr_title(win_T *wp, ScreenGrid *grid, int col)
{
  VirtText title_chunks = wp->w_float_config.title_chunks;

  for (size_t i = 0; i < title_chunks.size; i++) {
    char *text = title_chunks.items[i].text;
    int cell = (int)mb_string2cells(text);
    int hl_id = title_chunks.items[i].hl_id;
    int attr = hl_id ? syn_id2attr(hl_id) : 0;
    grid_puts(grid, text, 0, col, attr);
    col += cell;
  }
}

static void win_redr_border(win_T *wp)
{
  wp->w_redr_border = false;
  if (!(wp->w_floating && wp->w_float_config.border)) {
    return;
  }

  ScreenGrid *grid = &wp->w_grid_alloc;

  schar_T *chars = wp->w_float_config.border_chars;
  int *attrs = wp->w_float_config.border_attr;

  int *adj = wp->w_border_adj;
  int irow = wp->w_height_inner + wp->w_winbar_height, icol = wp->w_width_inner;

  if (adj[0]) {
    grid_puts_line_start(grid, 0);
    if (adj[3]) {
      grid_put_schar(grid, 0, 0, chars[0], attrs[0]);
    }

    for (int i = 0; i < icol; i++) {
      grid_put_schar(grid, 0, i + adj[3], chars[1], attrs[1]);
    }

    if (wp->w_float_config.title) {
      int title_col = 0;
      int title_width = wp->w_float_config.title_width;
      AlignTextPos title_pos = wp->w_float_config.title_pos;

      if (title_pos == kAlignCenter) {
        title_col = (icol - title_width) / 2 + 1;
      } else {
        title_col = title_pos == kAlignLeft ? 1 : icol - title_width + 1;
      }

      win_border_redr_title(wp, grid, title_col);
    }
    if (adj[1]) {
      grid_put_schar(grid, 0, icol + adj[3], chars[2], attrs[2]);
    }
    grid_puts_line_flush(false);
  }

  for (int i = 0; i < irow; i++) {
    if (adj[3]) {
      grid_puts_line_start(grid, i + adj[0]);
      grid_put_schar(grid, i + adj[0], 0, chars[7], attrs[7]);
      grid_puts_line_flush(false);
    }
    if (adj[1]) {
      int ic = (i == 0 && !adj[0] && chars[2][0]) ? 2 : 3;
      grid_puts_line_start(grid, i + adj[0]);
      grid_put_schar(grid, i + adj[0], icol + adj[3], chars[ic], attrs[ic]);
      grid_puts_line_flush(false);
    }
  }

  if (adj[2]) {
    grid_puts_line_start(grid, irow + adj[0]);
    if (adj[3]) {
      grid_put_schar(grid, irow + adj[0], 0, chars[6], attrs[6]);
    }
    for (int i = 0; i < icol; i++) {
      int ic = (i == 0 && !adj[3] && chars[6][0]) ? 6 : 5;
      grid_put_schar(grid, irow + adj[0], i + adj[3], chars[ic], attrs[ic]);
    }
    if (adj[1]) {
      grid_put_schar(grid, irow + adj[0], icol + adj[3], chars[4], attrs[4]);
    }
    grid_puts_line_flush(false);
  }
}

/// Show current cursor info in ruler and various other places
///
/// @param always  if false, only show ruler if position has changed.
void show_cursor_info(bool always)
{
  if (!always && !redrawing()) {
    return;
  }

  win_check_ns_hl(curwin);
  if ((*p_stl != NUL || *curwin->w_p_stl != NUL)
      && (curwin->w_status_height || global_stl_height())) {
    redraw_custom_statusline(curwin);
  } else {
    win_redr_ruler(curwin, always);
  }
  if (*p_wbr != NUL || *curwin->w_p_wbr != NUL) {
    win_redr_winbar(curwin);
  }

  if (need_maketitle
      || (p_icon && (stl_syntax & STL_IN_ICON))
      || (p_title && (stl_syntax & STL_IN_TITLE))) {
    maketitle();
  }

  win_check_ns_hl(NULL);
  // Redraw the tab pages line if needed.
  if (redraw_tabline) {
    draw_tabline();
  }
}

static void redraw_win_signcol(win_T *wp)
{
  // If we can compute a change in the automatic sizing of the sign column
  // under 'signcolumn=auto:X' and signs currently placed in the buffer, better
  // figuring it out here so we can redraw the entire screen for it.
  int scwidth = wp->w_scwidth;
  wp->w_scwidth = win_signcol_count(wp);
  if (wp->w_scwidth != scwidth) {
    changed_line_abv_curs_win(wp);
  }
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
  int hl;
  int c = fillchar_vsep(wp, &hl);
  grid_fill(&default_grid, wp->w_winrow, W_ENDROW(wp),
            W_ENDCOL(wp), W_ENDCOL(wp) + 1, c, ' ', hl);
}

/// Draw the horizontal separator below window "wp"
static void draw_hsep_win(win_T *wp)
{
  if (!wp->w_hsep_height) {
    return;
  }

  // draw the horizontal separator below this window
  int hl;
  int c = fillchar_hsep(wp, &hl);
  grid_fill(&default_grid, W_ENDROW(wp), W_ENDROW(wp) + 1,
            wp->w_wincol, W_ENDCOL(wp), c, c, hl);
}

/// Get the separator connector for specified window corner of window "wp"
static int get_corner_sep_connector(win_T *wp, WindowCorner corner)
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
  if (!(win_at_top || win_at_left)) {
    grid_putchar(&default_grid, get_corner_sep_connector(wp, WC_TOP_LEFT),
                 wp->w_winrow - 1, wp->w_wincol - 1, hl);
  }
  if (!(win_at_top || win_at_right)) {
    grid_putchar(&default_grid, get_corner_sep_connector(wp, WC_TOP_RIGHT),
                 wp->w_winrow - 1, W_ENDCOL(wp), hl);
  }
  if (!(win_at_bottom || win_at_left)) {
    grid_putchar(&default_grid, get_corner_sep_connector(wp, WC_BOTTOM_LEFT),
                 W_ENDROW(wp), wp->w_wincol - 1, hl);
  }
  if (!(win_at_bottom || win_at_right)) {
    grid_putchar(&default_grid, get_corner_sep_connector(wp, WC_BOTTOM_RIGHT),
                 W_ENDROW(wp), W_ENDCOL(wp), hl);
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
///                       wp->w_redraw_top and wp->w_redr_bot.
///                     - continue redrawing when syntax status is invalid.
///                  4. if scrolled up, update lines at the bottom.
/// This results in three areas that may need updating:
/// top: from first row to top_end (when scrolled down)
/// mid: from mid_start to mid_end (update inversion or changed text)
/// bot: from bot_start to last row (when scrolled up)
static void win_update(win_T *wp, DecorProviders *providers)
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
    // TODO(bfredl): should only be implied for CLEAR, not NOT_VALID!
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

  decor_redraw_reset(buf, &decor_state);

  DecorProviders line_providers;
  decor_providers_invoke_win(wp, providers, &line_providers, &provider_err);

  redraw_win_signcol(wp);

  init_search_hl(wp, &screen_search_hl);

  // Force redraw when width of 'number' or 'relativenumber' column
  // changes.
  int nrwidth = (wp->w_p_nu || wp->w_p_rnu || *wp->w_p_stc) ? number_width(wp) : 0;
  if (wp->w_nrwidth != nrwidth) {
    type = UPD_NOT_VALID;
    wp->w_nrwidth = nrwidth;

    if (buf->terminal) {
      terminal_check_size(buf->terminal);
    }
  } else if (buf->b_mod_set
             && buf->b_mod_xlines != 0
             && wp->w_redraw_top != 0) {
    // When there are both inserted/deleted lines and specific lines to be
    // redrawn, w_redraw_top and w_redraw_bot may be invalid, just redraw
    // everything (only happens when redrawing is off for while).
    type = UPD_NOT_VALID;
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
          if (mod_top < 1) {
            mod_top = 1;
          }
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
    if (mod_top != 0 && hasAnyFolding(wp)) {
      linenr_T lnumt, lnumb;

      // A change in a line can cause lines above it to become folded or
      // unfolded.  Find the top most buffer line that may be affected.
      // If the line was previously folded and displayed, get the first
      // line of that fold.  If the line is folded now, get the first
      // folded line.  Use the minimum of these two.

      // Find last valid w_lines[] entry above mod_top.  Set lnumt to
      // the line below it.  If there is no valid entry, use w_topline.
      // Find the first valid w_lines[] entry below mod_bot.  Set lnumb
      // to this line.  If there is no valid entry, use MAXLNUM.
      lnumt = wp->w_topline;
      lnumb = MAXLNUM;
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

      (void)hasFoldingWin(wp, mod_top, &mod_top, NULL, true, NULL);
      if (mod_top > lnumt) {
        mod_top = lnumt;
      }

      // Now do the same for the bottom line (one above mod_bot).
      mod_bot--;
      (void)hasFoldingWin(wp, mod_bot, NULL, &mod_bot, true, NULL);
      mod_bot++;
      if (mod_bot < lnumb) {
        mod_bot = lnumb;
      }
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

    // When line numbers are displayed need to redraw all lines below
    // inserted/deleted lines.
    if (mod_top != 0 && buf->b_mod_xlines != 0 && wp->w_p_nu) {
      mod_bot = MAXLNUM;
    }
  }

  wp->w_redraw_top = 0;  // reset for next time
  wp->w_redraw_bot = 0;

  // When only displaying the lines at the top, set top_end.  Used when
  // window has scrolled down for msg_scrolled.
  if (type == UPD_REDRAW_TOP) {
    long j = 0;
    for (int i = 0; i < wp->w_lines_valid; i++) {
      j += wp->w_lines[i].wl_size;
      if (j >= wp->w_upd_rows) {
        top_end = (int)j;
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
      long j;
      if (hasAnyFolding(wp)) {
        linenr_T ln;

        // count the number of lines we are off, counting a sequence
        // of folded lines as one
        j = 0;
        for (ln = wp->w_topline; ln < wp->w_lines[0].wl_lnum; ln++) {
          j++;
          if (j >= wp->w_grid.rows - 2) {
            break;
          }
          (void)hasFoldingWin(wp, ln, NULL, &ln, true, NULL);
        }
      } else {
        j = wp->w_lines[0].wl_lnum - wp->w_topline;
      }
      if (j < wp->w_grid.rows - 2) {               // not too far off
        int i = plines_m_win(wp, wp->w_topline, wp->w_lines[0].wl_lnum - 1);
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
      long j = -1;
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
          for (;;) {
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
            wp->w_lines[0].wl_size = (uint16_t)(plines_win_nofill(wp, wp->w_topline, true)
                                                + wp->w_topfill);
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
        if (wp->w_old_cursor_lnum < from) {
          from = wp->w_old_cursor_lnum;
        }
        if (wp->w_old_cursor_lnum > to) {
          to = wp->w_old_cursor_lnum;
        }
        if (wp->w_old_visual_lnum < from) {
          from = wp->w_old_visual_lnum;
        }
        if (wp->w_old_visual_lnum > to) {
          to = wp->w_old_visual_lnum;
        }
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
          if (wp->w_old_visual_lnum > to) {
            to = wp->w_old_visual_lnum;
          }
          if (VIsual.lnum < from) {
            from = VIsual.lnum;
          }
          if (VIsual.lnum > to) {
            to = VIsual.lnum;
          }
        }
      }

      // If in block mode and changed column or curwin->w_curswant:
      // update all lines.
      // First compute the actual start and end column.
      if (VIsual_mode == Ctrl_V) {
        colnr_T fromc, toc;
        unsigned int save_ve_flags = curwin->w_ve_flags;

        if (curwin->w_p_lbr) {
          curwin->w_ve_flags = VE_ALL;
        }

        getvcols(wp, &VIsual, &curwin->w_cursor, &fromc, &toc);
        toc++;
        curwin->w_ve_flags = save_ve_flags;
        // Highlight to the end of the line, unless 'virtualedit' has
        // "block".
        if (curwin->w_curswant == MAXCOL) {
          if (get_ve_flags() & VE_BLOCK) {
            pos_T pos;
            int cursor_above = curwin->w_cursor.lnum < VIsual.lnum;

            // Need to find the longest line.
            toc = 0;
            pos.coladd = 0;
            for (pos.lnum = curwin->w_cursor.lnum;
                 cursor_above ? pos.lnum <= VIsual.lnum : pos.lnum >= VIsual.lnum;
                 pos.lnum += cursor_above ? 1 : -1) {
              colnr_T t;

              pos.col = (colnr_T)strlen(ml_get_buf(wp->w_buffer, pos.lnum, false));
              getvvcol(wp, &pos, NULL, NULL, &t);
              if (toc < t) {
                toc = t;
              }
            }
            toc++;
          } else {
            toc = MAXCOL;
          }
        }

        if (fromc != wp->w_old_cursor_fcol
            || toc != wp->w_old_cursor_lcol) {
          if (from > VIsual.lnum) {
            from = VIsual.lnum;
          }
          if (to < VIsual.lnum) {
            to = VIsual.lnum;
          }
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
    if (from < wp->w_topline) {
      from = wp->w_topline;
    }

    // If we know the value of w_botline, use it to restrict the update to
    // the lines that are visible in the window.
    if (wp->w_valid & VALID_BOTLINE) {
      if (from >= wp->w_botline) {
        from = wp->w_botline - 1;
      }
      if (to >= wp->w_botline) {
        to = wp->w_botline - 1;
      }
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
    if (cursorline_fi.fi_level > 0 && cursorline_fi.fi_lines > 0) {
      wp->w_cursorline = cursorline_fi.fi_lnum;
    }
  }

  win_check_ns_hl(wp);

  // Update all the window rows.
  int idx = 0;                    // first entry in w_lines[].wl_size
  int row = 0;                    // current window row to display
  int srow = 0;                   // starting row of the current line
  linenr_T lnum = wp->w_topline;  // first line shown in window

  bool eof = false;             // if true, we hit the end of the file
  bool didline = false;         // if true, we finished the last line
  for (;;) {
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
                            && buf->b_mod_xlines != 0)))))
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
          long j = idx;
          for (l = lnum; l < mod_bot; l++) {
            if (hasFoldingWin(wp, l, NULL, &l, true, NULL)) {
              new_rows++;
            } else if (l == wp->w_topline) {
              new_rows += plines_win_nofill(wp, l, true) + wp->w_topfill;
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
              for (;;) {
                // stop at last valid entry in w_lines[]
                if (i >= wp->w_lines_valid) {
                  wp->w_lines_valid = (int)j;
                  break;
                }
                wp->w_lines[j] = wp->w_lines[i];
                // stop at a line that won't fit
                if (x + (int)wp->w_lines[j].wl_size
                    > wp->w_grid.rows) {
                  wp->w_lines_valid = (int)j + 1;
                  break;
                }
                x += wp->w_lines[j++].wl_size;
                i++;
              }
              if (bot_start > x) {
                bot_start = x;
              }
            } else {       // j > i
                           // move entries in w_lines[] downwards
              j -= i;
              wp->w_lines_valid += (linenr_T)j;
              if (wp->w_lines_valid > wp->w_grid.rows) {
                wp->w_lines_valid = wp->w_grid.rows;
              }
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
      foldinfo_T foldinfo = wp->w_p_cul && lnum == wp->w_cursor.lnum ?
                            cursorline_fi : fold_info(wp, lnum);

      if (foldinfo.fi_lines == 0
          && idx < wp->w_lines_valid
          && wp->w_lines[idx].wl_valid
          && wp->w_lines[idx].wl_lnum == lnum
          && lnum > wp->w_topline
          && !(dy_flags & (DY_LASTLINE | DY_TRUNCATE))
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

        // Display one line
        row = win_line(wp, lnum, srow,
                       foldinfo.fi_lines ? srow : wp->w_grid.rows,
                       mod_top == 0, false, foldinfo, &line_providers, &provider_err);

        if (foldinfo.fi_lines == 0) {
          wp->w_lines[idx].wl_folded = false;
          wp->w_lines[idx].wl_lastlnum = lnum;
          did_update = DID_LINE;
          syntax_last_parsed = lnum;
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
      if (wp->w_p_rnu && wp->w_last_cursor_lnum_rnu != wp->w_cursor.lnum) {
        // 'relativenumber' set and cursor moved vertically: The
        // text doesn't need to be drawn, but the number column does.
        foldinfo_T info = wp->w_p_cul && lnum == wp->w_cursor.lnum ?
                          cursorline_fi : fold_info(wp, lnum);
        (void)win_line(wp, lnum, srow, wp->w_grid.rows, true, true,
                       info, &line_providers, &provider_err);
      }

      // This line does not need to be drawn, advance to the next one.
      row += wp->w_lines[idx++].wl_size;
      if (row > wp->w_grid.rows) {  // past end of screen
        break;
      }
      lnum = wp->w_lines[idx - 1].wl_lastlnum + 1;
      did_update = DID_NONE;
    }

    // 'statuscolumn' width has changed or errored, start from the top.
    if (wp->w_redr_statuscol) {
      wp->w_redr_statuscol = false;
      idx = 0;
      row = 0;
      lnum = wp->w_topline;
      wp->w_lines_valid = 0;
      wp->w_valid &= ~VALID_WCOL;
      decor_providers_invoke_win(wp, providers, &line_providers, &provider_err);
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

  if (idx > wp->w_lines_valid) {
    wp->w_lines_valid = idx;
  }

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
    } else if (dy_flags & DY_TRUNCATE) {      // 'display' has "truncate"
      int scr_row = wp->w_grid.rows - 1;
      int symbol = wp->w_p_fcs_chars.lastline;
      char fillbuf[12];  // 2 characters of 6 bytes
      int charlen = utf_char2bytes(symbol, &fillbuf[0]);
      utf_char2bytes(symbol, &fillbuf[charlen]);

      // Last line isn't finished: Display "@@@" in the last screen line.
      grid_puts_len(&wp->w_grid, fillbuf, MIN(wp->w_grid.cols, 2) * charlen, scr_row, 0, at_attr);
      grid_fill(&wp->w_grid, scr_row, scr_row + 1, 2, wp->w_grid.cols, symbol, ' ', at_attr);
      set_empty_rows(wp, srow);
      wp->w_botline = lnum;
    } else if (dy_flags & DY_LASTLINE) {      // 'display' has "lastline"
      int start_col = wp->w_grid.cols - 3;
      int symbol = wp->w_p_fcs_chars.lastline;

      // Last line isn't finished: Display "@@@" at the end.
      grid_fill(&wp->w_grid, wp->w_grid.rows - 1, wp->w_grid.rows,
                MAX(start_col, 0), wp->w_grid.cols, symbol, symbol, at_attr);
      set_empty_rows(wp, srow);
      wp->w_botline = lnum;
    } else {
      win_draw_end(wp, wp->w_p_fcs_chars.lastline, ' ', true, srow, wp->w_grid.rows, HLF_AT);
      set_empty_rows(wp, srow);
      wp->w_botline = lnum;
    }
  } else {
    if (eof) {  // we hit the end of the file
      wp->w_botline = buf->b_ml.ml_line_count + 1;
      long j = win_get_fill(wp, wp->w_botline);
      if (j > 0 && !wp->w_botfill && row < wp->w_grid.rows) {
        // Display filler text below last line. win_line() will check
        // for ml_line_count+1 and only draw filler lines
        foldinfo_T info = { 0 };
        row = win_line(wp, wp->w_botline, row, wp->w_grid.rows,
                       false, false, info, &line_providers, &provider_err);
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

    win_draw_end(wp, wp->w_p_fcs_chars.eob, ' ', false, MAX(lastline, row), wp->w_grid.rows,
                 HLF_EOB);
    set_empty_rows(wp, row);
  }

  kvi_destroy(line_providers);

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
      if (must_redraw != 0) {
        // Don't update for changes in buffer again.
        int mod_set = curbuf->b_mod_set;
        curbuf->b_mod_set = false;
        win_update(curwin, providers);
        must_redraw = 0;
        curbuf->b_mod_set = mod_set;
      }
      recursive = false;
    }
  }

  // restore got_int, unless CTRL-C was hit while redrawing
  if (!got_int) {
    got_int = save_got_int;
  }
}

/// Redraw a window later, with wp->w_redr_type >= type.
///
/// Set must_redraw only if not already set to a higher value.
/// e.g. if must_redraw is UPD_CLEAR, type UPD_NOT_VALID will do nothing.
void redraw_later(win_T *wp, int type)
  FUNC_ATTR_NONNULL_ALL
{
  if (!exiting && wp->w_redr_type < type) {
    wp->w_redr_type = type;
    if (type >= UPD_NOT_VALID) {
      wp->w_lines_valid = 0;
    }
    if (must_redraw < type) {   // must_redraw is the maximum of all windows
      must_redraw = type;
    }
  }
}

/// Mark all windows to be redrawn later.
void redraw_all_later(int type)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    redraw_later(wp, type);
  }
  // This may be needed when switching tabs.
  if (must_redraw < type) {
    must_redraw = type;
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

void redraw_buf_range_later(buf_T *buf,  linenr_T firstline, linenr_T lastline)
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
      if (must_redraw < UPD_VALID) {
        must_redraw = UPD_VALID;
      }
    }
  }
}

/// Mark all status lines and window bars for redraw; used after first :cd
void status_redraw_all(void)
{
  bool is_stl_global = global_stl_height() != 0;

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if ((!is_stl_global && wp->w_status_height) || (is_stl_global && wp == curwin)
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
