#include <assert.h>
#include <stdbool.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/extmark.h"
#include "nvim/api/keysets_defs.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/api/win_config.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/decoration_defs.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval/window.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/globals.h"
#include "nvim/highlight_group.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/pos_defs.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_compositor.h"
#include "nvim/ui_defs.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"
#include "nvim/winfloat.h"

#include "api/win_config.c.generated.h"

#define HAS_KEY_X(d, key) HAS_KEY(d, win_config, key)

/// Opens a new split window, floating window, or external window.
///
/// - Specify `relative` to create a floating window. Floats are drawn over the split layout,
///   relative to a position in some other window. See |api-floatwin|.
///   - Floats must specify `width` and `height`.
/// - Specify `external` to create an external window. External windows are displayed as separate
///   top-level windows managed by the |ui-multigrid| UI (not Nvim).
/// - If `relative` and `external` are omitted, a normal "split" window is created.
///   - The `win` key decides which window to split. If nil or 0, the split will be adjacent to
///     the current window. If -1, a top-level split will be created.
///   - Use `vertical` and `split` to control split direction. For `vertical`, the exact direction
///     is determined by 'splitright' and 'splitbelow'.
///   - Split windows cannot have `bufpos`, `row`, `col`, `border`, `title`, `footer`.
///
/// With relative=editor (row=0,col=0) refers to the top-left corner of the
/// screen-grid and (row=Lines-1,col=Columns-1) refers to the bottom-right
/// corner. Fractional values are allowed, but the builtin implementation
/// (used by non-multigrid UIs) will always round down to nearest integer.
///
/// Out-of-bounds values, and configurations that make the float not fit inside
/// the main editor, are allowed. The builtin implementation truncates values
/// so floats are fully within the main screen grid. External GUIs
/// could let floats hover outside of the main window like a tooltip, but
/// this should not be used to specify arbitrary WM screen positions.
///
/// Examples:
///
/// ```lua
/// -- Window-relative float with 'statusline' enabled:
/// local w1 = vim.api.nvim_open_win(0, false,
///   {relative='win', row=3, col=3, width=40, height=4})
/// vim.wo[w1].statusline = vim.o.statusline
///
/// -- Buffer-relative float (travels as buffer is scrolled):
/// vim.api.nvim_open_win(0, false,
///   {relative='win', width=40, height=4, bufpos={100,10}})
///
/// -- Vertical split left of the current window:
/// vim.api.nvim_open_win(0, false, { split = 'left', win = 0, })
/// ```
///
/// @param buf Buffer to display, or 0 for current buffer
/// @param enter  Enter the window (make it the current window)
/// @param config Map defining the window configuration. Keys:
///   - anchor: Decides which corner of the float to place at (row,col):
///      - "NW" northwest (default)
///      - "NE" northeast
///      - "SW" southwest
///      - "SE" southeast
///   - border: (`string|string[]`) (defaults to 'winborder' option) Window border. The string form
///     accepts the same values as the 'winborder' option. The array form must have a length of
///     eight or any divisor of eight, specifying the chars that form the border in a clockwise
///     fashion starting from the top-left corner. For example, the double-box style can be
///     specified as:
///     ```
///     [ "╔", "═" ,"╗", "║", "╝", "═", "╚", "║" ].
///     ```
///     If fewer than eight chars are given, they will be repeated. An ASCII border could be
///     specified as:
///     ```
///     [ "/", "-", \"\\\\\", "|" ],
///     ```
///     Or one char for all sides:
///     ```
///     [ "x" ].
///     ```
///     Empty string can be used to hide a specific border. This example will show only vertical
///     borders, not horizontal:
///     ```
///     [ "", "", "", ">", "", "", "", "<" ]
///     ```
///     By default, |hl-FloatBorder| highlight is used, which links to |hl-WinSeparator| when not
///     defined. Each border side can specify an optional highlight:
///     ```
///     [ ["+", "MyCorner"], ["x", "MyBorder"] ].
///     ```
///   - bufpos: Places float relative to buffer text (only when
///       relative="win"). Takes a tuple of zero-indexed `[line, column]`.
///       `row` and `col` if given are applied relative to this
///       position, else they default to:
///       - `row=1` and `col=0` if `anchor` is "NW" or "NE"
///       - `row=0` and `col=0` if `anchor` is "SW" or "SE"
///         (thus like a tooltip near the buffer text).
///   - col: Column position in units of screen cell width, may be fractional.
///   - drag: When true, dragging the title or footer area moves the window.
///       If "resize" is false, dragging any border or corner also moves it.
///       Dragging a non-editor-relative float converts it to editor-relative.
///       Default false.
///   - dragall: When true, dragging the content area moves the window.
///       If neither "drag" nor "resize" is set, dragging the border also moves the window.
///       Default false.
///   - external: GUI should display the window as an external
///       top-level window. Currently accepts no other positioning
///       configuration together with this.
///   - fixed: If true when anchor is NW or SW, the float window
///            would be kept fixed even if the window would be truncated.
///   - focusable: Enable focus by user actions (wincmds, mouse events).
///       Defaults to true. Non-focusable windows can be entered by
///       |nvim_set_current_win()|, or, when the `mouse` field is set to true,
///       by mouse events. See |focusable|.
///   - footer: (optional) Footer in window border, string or list.
///       List should consist of `[text, highlight]` tuples.
///       If string, or a tuple lacks a highlight, the default highlight group is `FloatFooter`.
///   - footer_pos: Footer position. Must be set with `footer` option.
///       Value can be one of "left", "center", or "right".
///       Default is `"left"`.
///   - height: Window height (in character cells). Minimum of 1.
///   - hide: If true the floating window will be hidden and the cursor will be invisible when
///           focused on it.
///   - mouse: Specify how this window interacts with mouse events.
///       Defaults to `focusable` value.
///       - If false, mouse events pass through this window.
///       - If true, mouse events interact with this window normally.
///   - noautocmd: Block all autocommands for the duration of the call. Cannot be changed by
///     |nvim_win_set_config()|.
///   - relative: Sets the window layout to "floating", placed at (row,col)
///                 coordinates relative to:
///      - "cursor"     Cursor position in current window.
///      - "editor"     The global editor grid.
///      - "laststatus" 'laststatus' if present, or last row.
///      - "mouse"      Mouse position.
///      - "tabline"    Tabline if present, or first row.
///      - "win"        Window given by the `win` field, or current window.
///   - resize: When true, dragging the border or corners resizes the window.
///       When "drag" is also true, title and footer regions remain move handles.
///       When "drag" is false, title and footer regions resize like the rest of the border.
///       Has no effect without a border. Default false.
///   - row: Row position in units of "screen cell height", may be fractional.
///   - split: Split direction: "left", "right", "above", "below".
///   - style: (optional) Configure the appearance of the window:
///       - ""         No special style.
///       - "minimal"  Nvim will display the window with many UI options
///                    disabled. This is useful when displaying a temporary
///                    float where the text should not be edited. Disables
///                    'number', 'relativenumber', 'cursorline', 'cursorcolumn',
///                    'foldcolumn', 'spell' and 'list' options. 'signcolumn'
///                    is changed to `auto` and 'colorcolumn' is cleared.
///                    'statuscolumn' is changed to empty. The end-of-buffer
///                     region is hidden by setting `eob` flag of
///                    'fillchars' to a space char, and clearing the
///                    |hl-EndOfBuffer| region in 'winhighlight'.
///   - title: (optional) Title in window border, string or list.
///       List should consist of `[text, highlight]` tuples.
///       If string, or a tuple lacks a highlight, the default highlight group is `FloatTitle`.
///   - title_pos: Title position. Must be set with `title` option.
///       Value can be one of "left", "center", or "right".
///       Default is `"left"`.
///   - vertical: Split vertically |:vertical|.
///   - width: Window width (in character cells). Minimum of 1.
///   - win: |window-ID| target window. Can be in a different tab page. Determines the window to
///       split (negative values act like |:topleft|, |:botright|), the relative window for a
///       `relative="win"` float, or just the target tab page (inferred from the window) for others.
///   - zindex: (positive integer, default: 50) Stacking order. Floats with higher `zindex` overlay
///     floats with lower indices. Below 100 is recommended, unless there is a good reason to
///     overshadow builtin elements. The cursor is dimmed if an unfocused float above the cursor
///     exceeds the zindex of the current window by 50. These screen elements have hard-coded
///     z-indices:
///       - 100: |ins-completion-menu| popupmenu
///       - 200: message scrollback (|pager|)
///       - 250: |cmdline-completion| popupmenu (wildoptions=pum)
///   - _cmdline_offset: (EXPERIMENTAL) When provided, anchor the |cmdline-completion|
///     popupmenu to this window, with an offset in screen cell width.
///
/// @param[out] err Error details, if any
///
/// @return |window-ID|, or 0 on error
Window nvim_open_win(Buffer buf, Boolean enter, Dict(win_config) *config, Error *err)
  FUNC_API_SINCE(6) FUNC_API_TEXTLOCK_ALLOW_CMDWIN
{
  buf_T *b = find_buffer_by_handle(buf, err);
  if (!b) {
    return 0;
  }
  if ((cmdwin_type != 0 && enter) || b == cmdwin_buf) {
    api_set_error(err, kErrorTypeException, "%s", e_cmdwin);
    return 0;
  }

  WinConfig fconfig = WIN_CONFIG_INIT;
  if (!parse_win_config(NULL, config, &fconfig, false, err)) {
    return 0;
  }

  bool is_split = HAS_KEY_X(config, split) || HAS_KEY_X(config, vertical);
  Window rv = 0;
  if (fconfig.noautocmd) {
    block_autocmds();
  }

  win_T *wp = NULL;
  tabpage_T *tp = curtab;
  assert(curwin != NULL);
  win_T *parent = config->win == 0 ? curwin : NULL;
  if (config->win > 0) {
    parent = find_window_by_handle(fconfig.window, err);
    if (!parent) {
      // find_window_by_handle has already set the error
      goto cleanup;
    } else if (is_split && parent->w_floating) {
      api_set_error(err, kErrorTypeException, "Cannot split a floating window");
      goto cleanup;
    }
    tp = win_find_tabpage(parent);
  }
  if (is_split) {
    if (!check_split_disallowed_err(parent ? parent : curwin, err)) {
      goto cleanup;  // error already set
    }

    if (HAS_KEY_X(config, vertical) && !HAS_KEY_X(config, split)) {
      if (config->vertical) {
        fconfig.split = p_spr ? kWinSplitRight : kWinSplitLeft;
      } else {
        fconfig.split = p_sb ? kWinSplitBelow : kWinSplitAbove;
      }
    }
    int flags = win_split_flags(fconfig.split, parent == NULL) | WSP_NOENTER;
    int size = (flags & WSP_VERT) ? fconfig.width : fconfig.height;

    TRY_WRAP(err, {
      if (parent == NULL || parent == curwin) {
        wp = win_split_ins(size, flags, NULL, 0, NULL);
      } else {
        switchwin_T switchwin;
        // `parent` is valid in `tp`, so switch_win should not fail.
        const int result = switch_win(&switchwin, parent, tp, true);
        assert(result == OK);
        (void)result;
        wp = win_split_ins(size, flags, NULL, 0, NULL);
        restore_win(&switchwin, true);
      }
    });
    if (wp) {
      wp->w_config = fconfig;
      if (size > 0) {
        // Without room for the requested size, window sizes may have been equalized instead.
        // If the size differs from what was requested, try to set it again now.
        if ((flags & WSP_VERT) && wp->w_width != size) {
          win_setwidth_win(size, wp);
        } else if (!(flags & WSP_VERT) && wp->w_height != size) {
          win_setheight_win(size, wp);
        }
      }
    }
  } else {
    // Unlike check_split_disallowed_err, ignore `split_disallowed`, as opening a float shouldn't
    // mess with the frame structure. Still check `b_locked_split` to avoid opening more windows
    // into a closing buffer, though.
    if (curwin->w_buffer->b_locked_split) {  // Can't instead check `buf` in case win_set_buf fails!
      api_set_error(err, kErrorTypeException, "E1159: Cannot open a float when closing the buffer");
      goto cleanup;
    }
    wp = win_new_float(NULL, false, fconfig, err);
  }
  if (!wp) {
    if (!ERROR_SET(err)) {
      api_set_error(err, kErrorTypeException, "Failed to create window");
    }
    goto cleanup;
  }

  if (fconfig._cmdline_offset < INT_MAX) {
    cmdline_win = wp;
  }

  // Autocommands may close `wp` or move it to another tabpage, so update and check `tp` after each
  // event. In each case, `wp` should already be valid in `tp`, so switch_win should not fail.
  // Also, autocommands may free the `buf` to switch to, so store a bufref to check.
  bufref_T bufref;
  set_bufref(&bufref, b);
  if (!fconfig.noautocmd) {
    switchwin_T switchwin;
    const int result = switch_win_noblock(&switchwin, wp, tp, true);
    assert(result == OK);
    (void)result;
    if (apply_autocmds(EVENT_WINNEW, NULL, NULL, false, curbuf)) {
      tp = win_find_tabpage(wp);
    }
    restore_win_noblock(&switchwin, true);
  }
  if (tp && enter) {
    goto_tabpage_win(tp, wp);
    tp = win_find_tabpage(wp);
  }
  if (tp && bufref_valid(&bufref) && b != wp->w_buffer) {
    // win_set_buf temporarily makes `wp` the curwin to set the buffer.
    // If not entering `wp`, block Enter and Leave events. (cringe)
    const bool au_no_enter_leave = curwin != wp && !fconfig.noautocmd;
    if (au_no_enter_leave) {
      autocmd_no_enter++;
      autocmd_no_leave++;
    }
    win_set_buf(wp, b, err);
    if (!fconfig.noautocmd) {
      tp = win_find_tabpage(wp);
    }
    if (au_no_enter_leave) {
      autocmd_no_enter--;
      autocmd_no_leave--;
    }
  }
  if (!tp) {
    api_clear_error(err);  // may have been set by win_set_buf
    api_set_error(err, kErrorTypeException, "Window was closed immediately");
    goto cleanup;
  }

  if (fconfig.style == kWinStyleMinimal) {
    win_set_minimal_style(wp);
    didset_window_options(wp, true);
    changed_window_setting(wp);
  }
  rv = wp->handle;

cleanup:
  if (fconfig.noautocmd) {
    unblock_autocmds();
  }
  return rv;
}

static WinSplit win_split_dir(win_T *win)
{
  if (win->w_frame == NULL || win->w_frame->fr_parent == NULL) {
    return kWinSplitLeft;
  }

  char layout = win->w_frame->fr_parent->fr_layout;
  if (layout == FR_COL) {
    return win->w_frame->fr_next ? kWinSplitAbove : kWinSplitBelow;
  } else {
    return win->w_frame->fr_next ? kWinSplitLeft : kWinSplitRight;
  }
}

static int win_split_flags(WinSplit split, bool toplevel)
{
  int flags = 0;
  if (split == kWinSplitAbove || split == kWinSplitBelow) {
    flags |= WSP_HOR;
  } else {
    flags |= WSP_VERT;
  }
  if (split == kWinSplitAbove || split == kWinSplitLeft) {
    flags |= toplevel ? WSP_TOP : WSP_ABOVE;
  } else {
    flags |= toplevel ? WSP_BOT : WSP_BELOW;
  }
  return flags;
}

/// Checks if window `wp` can be moved to tabpage `tp`.
static bool win_can_move_tp(win_T *wp, tabpage_T *tp, Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  if (one_window(wp, tp == curtab ? NULL : tp)) {
    api_set_error(err, kErrorTypeException, "Cannot move last non-floating window");
    return false;
  }
  // Like closing, moving windows between tabpages makes win_valid return false. Helpful when e.g:
  // walking the window list, as w_next/w_prev can unexpectedly refer to windows in another tabpage!
  // Check related locks, in case they were set to avoid checking win_valid.
  if (win_locked(wp)) {
    api_set_error(err, kErrorTypeException, "Cannot move window to another tabpage whilst in use");
    return false;
  }
  if (window_layout_locked_err(CMD_SIZE, err)) {
    return false;  // error already set
  }
  if (textlock || expr_map_locked()) {
    api_set_error(err, kErrorTypeException, "%s", e_textlock);
    return false;
  }
  if (is_aucmd_win(wp)) {
    api_set_error(err, kErrorTypeException, "Cannot move autocmd window to another tabpage");
    return false;
  }
  // Can't move the cmdwin or its old curwin to a different tabpage.
  if (wp == cmdwin_win || wp == cmdwin_old_curwin) {
    api_set_error(err, kErrorTypeException, "%s", e_cmdwin);
    return false;
  }
  return true;
}

static win_T *win_find_altwin(win_T *win, tabpage_T *tp)
  FUNC_ATTR_NONNULL_ALL
{
  if (win->w_floating) {
    return win_float_find_altwin(win, tp == curtab ? NULL : tp);
  } else {
    int dir;
    return winframe_find_altwin(win, &dir, tp == curtab ? NULL : tp, NULL);
  }
}

/// Configures `win` into a split, also moving it to another tabpage if requested.
static bool win_config_split(win_T *win, const Dict(win_config) *config, WinConfig *fconfig,
                             Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  bool was_split = !win->w_floating;
  bool has_split = HAS_KEY_X(config, split);
  bool has_vertical = HAS_KEY_X(config, vertical);
  WinSplit old_split = win_split_dir(win);
  if (has_vertical && !has_split) {
    if (config->vertical) {
      fconfig->split = (old_split == kWinSplitRight || p_spr) ? kWinSplitRight : kWinSplitLeft;
    } else {
      fconfig->split = (old_split == kWinSplitBelow || p_sb) ? kWinSplitBelow : kWinSplitAbove;
    }
  }

  // If there's no "vertical" or "split" set, or if "split" is unchanged, then we can just change
  // the size of the window.
  if ((!has_vertical && !has_split)
      || (was_split && !HAS_KEY_X(config, win) && old_split == fconfig->split)) {
    goto resize;
  }

  win_T *parent = NULL;
  tabpage_T *parent_tp = NULL;
  if (config->win == 0) {
    parent = curwin;
    parent_tp = curtab;
  } else if (config->win > 0) {
    parent = find_window_by_handle(fconfig->window, err);
    if (!parent) {
      return false;  // error already set
    }
    parent_tp = win_find_tabpage(parent);
  }

  tabpage_T *win_tp = win_find_tabpage(win);
  if (parent) {
    if (parent->w_floating) {
      api_set_error(err, kErrorTypeException, "Cannot split a floating window");
      return false;
    }
    if (win_tp != parent_tp && !win_can_move_tp(win, win_tp, err)) {
      return false;  // error already set
    }
  }

  if (!check_split_disallowed_err(win, err)) {
    return false;  // error already set
  }

  bool to_split_ok = false;
  // If we are moving curwin to another tabpage, switch windows *before* we remove it from the
  // window list or remove its frame (if non-floating), so it's valid for autocommands.
  const bool curwin_moving_tp = win == curwin && parent && win_tp != parent_tp;
  if (curwin_moving_tp) {
    win_T *altwin = win_find_altwin(win, win_tp);
    assert(altwin);  // win_can_move_tp ensures `win` is not the only window
    win_goto(altwin);

    // Autocommands may have been a real nuisance and messed things up...
    if (curwin == win) {
      api_set_error(err, kErrorTypeException, "Failed to switch away from window %d", win->handle);
      return false;
    }
    win_tp = win_find_tabpage(win);
    if (!win_tp || !win_valid_any_tab(parent)) {
      api_set_error(err, kErrorTypeException, "Windows to split were closed");
      goto restore_curwin;
    }
    if (was_split == win->w_floating || parent->w_floating) {
      api_set_error(err, kErrorTypeException, "Floating state of windows to split changed");
      goto restore_curwin;
    }
  }

  int dir = 0;
  frame_T *unflat_altfr = NULL;
  win_T *altwin = NULL;

  if (was_split) {
    // If the window is the last in the tabpage or `fconfig.win` is a handle to itself, we can't
    // split it.
    if (win->w_frame->fr_parent == NULL) {
      // FIXME(willothy): if the window is the last in the tabpage but there is another tabpage and
      // the target window is in that other tabpage, should we move the window to that tabpage and
      // close the previous one, or just error?
      api_set_error(err, kErrorTypeException, "Cannot move last non-floating window");
      goto restore_curwin;
    } else if (parent != NULL && parent->handle == win->handle) {
      int n_frames = 0;
      for (frame_T *fr = win->w_frame->fr_parent->fr_child; fr != NULL; fr = fr->fr_next) {
        n_frames++;
      }

      win_T *neighbor = NULL;

      if (n_frames > 2) {
        // There are three or more windows in the frame, we need to split a neighboring window.
        frame_T *frame = win->w_frame->fr_parent;

        if (frame->fr_parent) {
          //   ┌──────────────┐
          //   │      A       │
          //   ├────┬────┬────┤
          //   │ B  │ C  │ D  │
          //   └────┴────┴────┘
          //          ||
          //          \/
          // ┌───────────────────┐
          // │         A         │
          // ├─────────┬─────────┤
          // │         │    C    │
          // │    B    ├─────────┤
          // │         │    D    │
          // └─────────┴─────────┘
          if (fconfig->split == kWinSplitAbove || fconfig->split == kWinSplitLeft) {
            neighbor = win->w_next;
          } else {
            neighbor = win->w_prev;
          }
        }
        // If the frame doesn't have a parent, the old frame was the root frame and we need to
        // create a top-level split.
        altwin = winframe_remove(win, &dir, win_tp == curtab ? NULL : win_tp, &unflat_altfr);
      } else if (n_frames == 2) {
        // There are two windows in the frame, we can just rotate it.
        altwin = winframe_remove(win, &dir, win_tp == curtab ? NULL : win_tp, &unflat_altfr);
        neighbor = altwin;
      } else {
        // There is only one window in the frame, we can't split it.
        api_set_error(err, kErrorTypeException, "Cannot split window into itself");
        goto restore_curwin;
      }
      // Set the parent to whatever the correct neighbor window was determined to be.
      parent = neighbor;
    } else {
      altwin = winframe_remove(win, &dir, win_tp == curtab ? NULL : win_tp, &unflat_altfr);
    }
  } else {
    altwin = win_float_find_altwin(win, win_tp == curtab ? NULL : win_tp);
  }

  win_remove(win, win_tp == curtab ? NULL : win_tp);
  if (win_tp == curtab) {
    last_status(false);  // may need to remove last status line
    win_comp_pos();  // recompute window positions
  }

  int flags = win_split_flags(fconfig->split, parent == NULL) | WSP_NOENTER;
  parent_tp = parent ? win_find_tabpage(parent) : curtab;

  TRY_WRAP(err, {
    const bool need_switch = parent != NULL && parent != curwin;
    switchwin_T switchwin;
    if (need_switch) {
      // `parent` is valid in its tabpage, so switch_win should not fail.
      const int result = switch_win(&switchwin, parent, parent_tp, true);
      (void)result;
      assert(result == OK);
    }
    to_split_ok = win_split_ins(0, flags, win, 0, unflat_altfr) != NULL;
    if (!to_split_ok) {
      // Restore `win` to the window list now, so it's valid for restore_win (if used).
      win_append(win->w_prev, win, win_tp == curtab ? NULL : win_tp);
    }
    if (need_switch) {
      restore_win(&switchwin, true);
    }
  });
  if (!to_split_ok) {
    if (was_split) {
      // win_split_ins doesn't change sizes or layout if it fails to insert an existing window, so
      // just undo winframe_remove.
      winframe_restore(win, dir, unflat_altfr);
    }
    if (!ERROR_SET(err)) {
      api_set_error(err, kErrorTypeException, "Failed to move window %d into split", win->handle);
    }

restore_curwin:
    // If `win` was the original curwin, and autocommands didn't move it outside of curtab, be a
    // good citizen and try to return to it.
    if (curwin_moving_tp && win_valid(win)) {
      win_goto(win);
    }
    return false;
  }

  // If `win` moved tabpages and was the curwin of its old one, select a new curwin for it.
  if (win_tp != parent_tp && win_tp->tp_curwin == win) {
    win_tp->tp_curwin = altwin;
  }

resize:
  if (HAS_KEY_X(config, width)) {
    win_setwidth_win(fconfig->width, win);
  }
  if (HAS_KEY_X(config, height)) {
    win_setheight_win(fconfig->height, win);
  }

  // Merge configs now. If previously a float, clear fields irrelevant to splits that `fconfig` may
  // have shallowly copied; don't free them as win_split_ins handled that. If already a split,
  // clearing isn't needed, as parse_win_config shouldn't allow setting irrelevant fields.
  if (!was_split) {
    clear_float_config(fconfig, false);
  }
  merge_win_config(&win->w_config, *fconfig);
  return true;
}

/// Configures `win` into a float, also moving it to another tabpage if requested.
static bool win_config_float_tp(win_T *win, const Dict(win_config) *config,
                                const WinConfig *fconfig, Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  tabpage_T *win_tp = win_find_tabpage(win);
  win_T *parent = win;
  tabpage_T *parent_tp = win_tp;
  if (HAS_KEY_X(config, win)) {
    parent = find_window_by_handle(fconfig->window, err);
    if (!parent) {
      return false;  // error already set
    }
    parent_tp = win_find_tabpage(parent);
  }

  bool curwin_moving_tp = false;
  win_T *altwin = NULL;

  if (win_tp != parent_tp) {
    if (!win_can_move_tp(win, win_tp, err)) {
      return false;  // error already set
    }
    altwin = win_find_altwin(win, win_tp);
    assert(altwin);  // win_can_move_tp ensures `win` is not the only window

    // If we are moving curwin to another tabpage, switch windows *before* we remove it from the
    // window list or remove its frame (if non-floating), so it's valid for autocommands.
    if (curwin == win) {
      curwin_moving_tp = true;
      win_goto(altwin);

      // Autocommands may have been a real nuisance and messed things up...
      if (curwin == win) {
        api_set_error(err, kErrorTypeException, "Failed to switch away from window %d",
                      win->handle);
        return false;
      }
      win_tp = win_find_tabpage(win);
      parent_tp = win_find_tabpage(parent);

      if (!win_tp || !parent_tp) {
        api_set_error(err, kErrorTypeException, "Target windows were closed");
        goto restore_curwin;
      }
      if (win_tp != parent_tp && !win_can_move_tp(win, win_tp, err)) {
        goto restore_curwin;  // error already set
      }
      altwin = win_find_altwin(win, win_tp);
      assert(altwin);  // win_can_move_tp ensures `win` is not the only window
    }
  }

  // Convert the window to a float if needed.
  if (!win->w_floating) {
    if (!win_new_float(win, false, *fconfig, err)) {
restore_curwin:
      // If `win` was the original curwin, and autocommands didn't move it outside of curtab, be a
      // good citizen and try to return to it.
      if (curwin_moving_tp && win_valid(win)) {
        win_goto(win);
      }
      return false;
    }
    redraw_later(win, UPD_NOT_VALID);
  }

  if (win_tp != parent_tp) {
    win_remove(win, win_tp == curtab ? NULL : win_tp);
    tabpage_T *append_tp = parent_tp == curtab ? NULL : parent_tp;
    win_append(lastwin_nofloating(append_tp), win, append_tp);

    // If `win` was the curwin of its old tabpage, select a new curwin for it.
    if (win_tp != curtab && win_tp->tp_curwin == win) {
      win_tp->tp_curwin = altwin;
    }

    // Remove grid if present. More reliable than checking curtab, as tabpage_check_windows may not
    // run when temporarily switching tabpages, meaning grids may be stale from another tabpage!
    // (e.g: switch_win_noblock with no_display=true)
    ui_comp_remove_grid(&win->w_grid_alloc);

    // Redraw tabline, update window's hl attribs, etc. Set must_redraw here, as redraw_later might
    // not if w_redr_type >= UPD_NOT_VALID was set in the old tabpage.
    redraw_later(win, UPD_NOT_VALID);
    set_must_redraw(UPD_NOT_VALID);
  }

  win_config_float(win, *fconfig);
  return true;
}

/// Reconfigures the layout and properties of a window.
///
/// - Updates only the given keys; unspecified (`nil`) keys will not be changed.
/// - Can move a window to another tabpage.
/// - Can transform a window to/from a float.
/// - Keys `row` / `col` / `relative` must be specified together.
/// - Cannot move the last window in a tabpage to a different one.
///
/// Example: to convert a floating window to a "normal" split window, specify the `win` field:
///
/// ```lua
/// vim.api.nvim_win_set_config(0, { split = 'above', win = vim.fn.win_getid(1), })
/// ```
///
/// @see |nvim_open_win()|
///
/// @param      win  |window-ID|, or 0 for current window
/// @param      config  Map defining the window configuration, see [nvim_open_win()]
/// @param[out] err     Error details, if any
void nvim_win_set_config(Window win, Dict(win_config) *config, Error *err)
  FUNC_API_SINCE(6)
{
  win_T *w = find_window_by_handle(win, err);
  if (!w) {
    return;
  }

  bool was_split = !w->w_floating;
  bool has_split = HAS_KEY_X(config, split);
  bool has_vertical = HAS_KEY_X(config, vertical);
  WinStyle old_style = w->w_config.style;
  // reuse old values, if not overridden
  WinConfig fconfig = w->w_config;

  bool to_split = config->relative.size == 0
                  && !(HAS_KEY_X(config, external) && config->external)
                  && (has_split || has_vertical || was_split);

  if (!parse_win_config(w, config, &fconfig, !was_split || to_split, err)) {
    return;
  }

  if (to_split) {
    if (!win_config_split(w, config, &fconfig, err)) {
      return;
    }
  } else {
    if (!win_config_float_tp(w, config, &fconfig, err)) {
      return;
    }
  }

  if (fconfig.style == kWinStyleMinimal && old_style != fconfig.style) {
    win_set_minimal_style(w);
    didset_window_options(w, true);
    changed_window_setting(w);
  }
  if (fconfig._cmdline_offset < INT_MAX) {
    cmdline_win = w;
  } else if (w == cmdline_win && fconfig._cmdline_offset == INT_MAX) {
    cmdline_win = NULL;
  }
}

#define PUT_KEY_X(d, key, value) PUT_KEY(d, win_config, key, value)
static void config_put_bordertext(Dict(win_config) *config, WinConfig *fconfig,
                                  BorderTextType bordertext_type, Arena *arena)
{
  VirtText vt;
  AlignTextPos align;
  switch (bordertext_type) {
  case kBorderTextTitle:
    vt = fconfig->title_chunks;
    align = fconfig->title_pos;
    break;
  case kBorderTextFooter:
    vt = fconfig->footer_chunks;
    align = fconfig->footer_pos;
    break;
  }

  Array bordertext = virt_text_to_array(vt, true, arena);

  char *pos;
  switch (align) {
  case kAlignLeft:
    pos = "left";
    break;
  case kAlignCenter:
    pos = "center";
    break;
  case kAlignRight:
    pos = "right";
    break;
  }

  switch (bordertext_type) {
  case kBorderTextTitle:
    PUT_KEY_X(*config, title, ARRAY_OBJ(bordertext));
    PUT_KEY_X(*config, title_pos, cstr_as_string(pos));
    break;
  case kBorderTextFooter:
    PUT_KEY_X(*config, footer, ARRAY_OBJ(bordertext));
    PUT_KEY_X(*config, footer_pos, cstr_as_string(pos));
  }
}

/// Gets window configuration in the form of a dict which can be passed as the `config` parameter of
/// |nvim_open_win()|.
///
/// For non-floating windows, `relative` is empty.
///
/// @param      win |window-ID|, or 0 for current window
/// @param[out] err Error details, if any
/// @return     Map defining the window configuration, see |nvim_open_win()|
Dict(win_config) nvim_win_get_config(Window win, Arena *arena, Error *err)
  FUNC_API_SINCE(6)
{
  /// Keep in sync with FloatRelative in buffer_defs.h
  static const char *const float_relative_str[] = {
    "editor", "win", "cursor", "mouse", "tabline", "laststatus"
  };

  /// Keep in sync with WinSplit in buffer_defs.h
  static const char *const win_split_str[] = { "left", "right", "above", "below" };

  /// Keep in sync with WinStyle in buffer_defs.h
  static const char *const win_style_str[] = { "", "minimal" };

  Dict(win_config) rv = KEYDICT_INIT;

  win_T *wp = find_window_by_handle(win, err);
  if (!wp) {
    return rv;
  }

  WinConfig *config = &wp->w_config;

  PUT_KEY_X(rv, focusable, config->focusable);
  PUT_KEY_X(rv, external, config->external);
  PUT_KEY_X(rv, hide, config->hide);
  PUT_KEY_X(rv, mouse, config->mouse);
  PUT_KEY_X(rv, style, cstr_as_string(win_style_str[config->style]));
  PUT_KEY_X(rv, drag, config->drag);
  PUT_KEY_X(rv, dragall, config->dragall);
  PUT_KEY_X(rv, resize, config->resize);

  if (wp->w_floating) {
    PUT_KEY_X(rv, width, config->width);
    PUT_KEY_X(rv, height, config->height);
    if (!config->external) {
      if (config->relative == kFloatRelativeWindow) {
        PUT_KEY_X(rv, win, config->window);
        if (config->bufpos.lnum >= 0) {
          Array pos = arena_array(arena, 2);
          ADD_C(pos, INTEGER_OBJ(config->bufpos.lnum));
          ADD_C(pos, INTEGER_OBJ(config->bufpos.col));
          PUT_KEY_X(rv, bufpos, pos);
        }
      }
      PUT_KEY_X(rv, anchor, cstr_as_string(float_anchor_str[config->anchor]));
      PUT_KEY_X(rv, row, config->row);
      PUT_KEY_X(rv, col, config->col);
      PUT_KEY_X(rv, zindex, config->zindex);
    }
    if (config->border) {
      Array border = arena_array(arena, 8);
      for (size_t i = 0; i < 8; i++) {
        String s = cstrn_as_string(config->border_chars[i], MAX_SCHAR_SIZE);

        int hi_id = config->border_hl_ids[i];
        char *hi_name = syn_id2name(hi_id);
        if (hi_name[0]) {
          Array tuple = arena_array(arena, 2);
          ADD_C(tuple, STRING_OBJ(s));
          ADD_C(tuple, CSTR_AS_OBJ(hi_name));
          ADD_C(border, ARRAY_OBJ(tuple));
        } else {
          ADD_C(border, STRING_OBJ(s));
        }
      }
      PUT_KEY_X(rv, border, ARRAY_OBJ(border));
      if (config->title) {
        config_put_bordertext(&rv, config, kBorderTextTitle, arena);
      }
      if (config->footer) {
        config_put_bordertext(&rv, config, kBorderTextFooter, arena);
      }
    } else {
      PUT_KEY_X(rv, border, STRING_OBJ(cstr_as_string("none")));
    }
  } else if (!config->external) {
    PUT_KEY_X(rv, width, wp->w_width);
    PUT_KEY_X(rv, height, wp->w_height);
    WinSplit split = win_split_dir(wp);
    PUT_KEY_X(rv, split, cstr_as_string(win_split_str[split]));
  }

  const char *rel = (wp->w_floating && !config->external
                     ? float_relative_str[config->relative] : "");
  PUT_KEY_X(rv, relative, cstr_as_string(rel));
  if (config->_cmdline_offset < INT_MAX) {
    PUT_KEY_X(rv, _cmdline_offset, config->_cmdline_offset);
  }

  return rv;
}

static bool parse_float_anchor(String anchor, FloatAnchor *out)
{
  if (anchor.size == 0) {
    *out = (FloatAnchor)0;
  }
  char *str = anchor.data;
  if (striequal(str, "NW")) {
    *out = 0;  //  NW is the default
  } else if (striequal(str, "NE")) {
    *out = kFloatAnchorEast;
  } else if (striequal(str, "SW")) {
    *out = kFloatAnchorSouth;
  } else if (striequal(str, "SE")) {
    *out = kFloatAnchorSouth | kFloatAnchorEast;
  } else {
    return false;
  }
  return true;
}

static bool parse_float_relative(String relative, FloatRelative *out)
{
  char *str = relative.data;
  if (striequal(str, "editor")) {
    *out = kFloatRelativeEditor;
  } else if (striequal(str, "win")) {
    *out = kFloatRelativeWindow;
  } else if (striequal(str, "cursor")) {
    *out = kFloatRelativeCursor;
  } else if (striequal(str, "mouse")) {
    *out = kFloatRelativeMouse;
  } else if (striequal(str, "tabline")) {
    *out = kFloatRelativeTabline;
  } else if (striequal(str, "laststatus")) {
    *out = kFloatRelativeLaststatus;
  } else {
    return false;
  }
  return true;
}

static bool parse_config_split(String split, WinSplit *out)
{
  char *str = split.data;
  if (striequal(str, "left")) {
    *out = kWinSplitLeft;
  } else if (striequal(str, "right")) {
    *out = kWinSplitRight;
  } else if (striequal(str, "above")) {
    *out = kWinSplitAbove;
  } else if (striequal(str, "below")) {
    *out = kWinSplitBelow;
  } else {
    return false;
  }
  return true;
}

static bool parse_float_bufpos(Array bufpos, lpos_T *out)
{
  if (bufpos.size != 2 || bufpos.items[0].type != kObjectTypeInteger
      || bufpos.items[1].type != kObjectTypeInteger) {
    return false;
  }
  out->lnum = (linenr_T)bufpos.items[0].data.integer;
  out->col = (colnr_T)bufpos.items[1].data.integer;
  return true;
}

static void parse_bordertext(Object bordertext, BorderTextType bordertext_type, WinConfig *fconfig,
                             Error *err)
{
  VALIDATE_EXP(!(bordertext.type != kObjectTypeString && bordertext.type != kObjectTypeArray),
               "title/footer", "String or Array", api_typename(bordertext.type), {
    return;
  });

  VALIDATE_EXP(!(bordertext.type == kObjectTypeArray && bordertext.data.array.size == 0),
               "title/footer", "non-empty Array", NULL, {
    return;
  });

  bool *is_present;
  VirtText *chunks;
  int *width;
  switch (bordertext_type) {
  case kBorderTextTitle:
    is_present = &fconfig->title;
    chunks = &fconfig->title_chunks;
    width = &fconfig->title_width;
    break;
  case kBorderTextFooter:
    is_present = &fconfig->footer;
    chunks = &fconfig->footer_chunks;
    width = &fconfig->footer_width;
    break;
  }

  if (bordertext.type == kObjectTypeString) {
    if (bordertext.data.string.size == 0) {
      *is_present = false;
      return;
    }
    kv_init(*chunks);
    kv_push(*chunks, ((VirtTextChunk){ .text = xstrdup(bordertext.data.string.data),
                                       .hl_id = -1 }));
    *width = (int)mb_string2cells(bordertext.data.string.data);
    *is_present = true;
    return;
  }

  *width = 0;
  *chunks = parse_virt_text(bordertext.data.array, err, width);

  *is_present = true;
}

static bool parse_bordertext_pos(win_T *wp, String bordertext_pos, BorderTextType bordertext_type,
                                 WinConfig *fconfig, Error *err)
{
  AlignTextPos *align;
  switch (bordertext_type) {
  case kBorderTextTitle:
    align = &fconfig->title_pos;
    break;
  case kBorderTextFooter:
    align = &fconfig->footer_pos;
    break;
  }

  if (bordertext_pos.size == 0) {
    if (!wp) {
      *align = kAlignLeft;
    }
    return true;
  }

  char *pos = bordertext_pos.data;

  if (strequal(pos, "left")) {
    *align = kAlignLeft;
  } else if (strequal(pos, "center")) {
    *align = kAlignCenter;
  } else if (strequal(pos, "right")) {
    *align = kAlignRight;
  } else {
    VALIDATE_S(false, (bordertext_type == kBorderTextTitle ? "title_pos" : "footer_pos"), pos, {
      return false;
    });
  }
  return true;
}

void parse_border_style(Object style, WinConfig *fconfig, Error *err)
{
  struct {
    const char *name;
    char chars[8][MAX_SCHAR_SIZE];
    bool shadow_color;
  } defaults[] = {
    { opt_winborder_values[1], { "╔", "═", "╗", "║", "╝", "═", "╚", "║" }, false },
    { opt_winborder_values[2], { "┌", "─", "┐", "│", "┘", "─", "└", "│" }, false },
    { opt_winborder_values[3], { "", "", " ", " ", " ", " ", " ", "" }, true },
    { opt_winborder_values[4], { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }, false },
    { opt_winborder_values[5], { " ", " ", " ", " ", " ", " ", " ", " " }, false },
    { opt_winborder_values[6], { "┏", "━", "┓", "┃", "┛", "━", "┗", "┃" }, false },
    { NULL, { { NUL } }, false },
  };

  char(*chars)[MAX_SCHAR_SIZE] = fconfig->border_chars;
  int *hl_ids = fconfig->border_hl_ids;

  fconfig->border = true;

  if (style.type == kObjectTypeArray) {
    Array arr = style.data.array;
    size_t size = arr.size;
    VALIDATE_EXP(!(!size || size > 8 || (size & (size - 1))),
                 "border", "1, 2, 4, or 8 chars", NULL, {
      return;
    });
    for (size_t i = 0; i < size; i++) {
      Object iytem = arr.items[i];
      String string;
      int hl_id = 0;
      if (iytem.type == kObjectTypeArray) {
        Array iarr = iytem.data.array;
        VALIDATE_EXP(!(!iarr.size || iarr.size > 2), "border", "1 or 2-item Array", NULL, {
          return;
        });
        VALIDATE_EXP(iarr.items[0].type == kObjectTypeString, "border", "Array of Strings", NULL, {
          return;
        });
        string = iarr.items[0].data.string;
        if (iarr.size == 2) {
          hl_id = object_to_hl_id(iarr.items[1], "border char highlight", err);
          if (ERROR_SET(err)) {
            return;
          }
        }
      } else if (iytem.type == kObjectTypeString) {
        string = iytem.data.string;
      } else {
        VALIDATE_EXP(false, "border", "String or Array", api_typename(iytem.type), {
          return;
        });
      }
      VALIDATE_EXP(!(string.size && mb_string2cells_len(string.data, string.size) > 1),
                   "border", "only one-cell chars", NULL, {
        return;
      });
      size_t len = MIN(string.size, sizeof(*chars) - 1);
      if (len) {
        memcpy(chars[i], string.data, len);
      }
      chars[i][len] = NUL;
      hl_ids[i] = hl_id;
    }
    while (size < 8) {
      memcpy(chars + size, chars, sizeof(*chars) * size);
      memcpy(hl_ids + size, hl_ids, sizeof(*hl_ids) * size);
      size <<= 1;
    }
    VALIDATE_EXP(!((chars[7][0] && chars[1][0] && !chars[0][0])
                   || (chars[1][0] && chars[3][0] && !chars[2][0])
                   || (chars[3][0] && chars[5][0] && !chars[4][0])
                   || (chars[5][0] && chars[7][0] && !chars[6][0])), "border",
                 "corner char between edge chars", NULL, {
      return;
    });
  } else if (style.type == kObjectTypeString) {
    String str = style.data.string;
    if (str.size == 0 || strequal(str.data, "none")) {
      fconfig->border = false;
      // border text does not work with border equal none
      fconfig->title = false;
      fconfig->footer = false;
      return;
    }
    for (size_t i = 0; defaults[i].name; i++) {
      if (strequal(str.data, defaults[i].name)) {
        memcpy(chars, defaults[i].chars, sizeof(defaults[i].chars));
        memset(hl_ids, 0, 8 * sizeof(*hl_ids));
        if (defaults[i].shadow_color) {
          int hl_blend = SYN_GROUP_STATIC("FloatShadow");
          int hl_through = SYN_GROUP_STATIC("FloatShadowThrough");
          hl_ids[2] = hl_through;
          hl_ids[3] = hl_blend;
          hl_ids[4] = hl_blend;
          hl_ids[5] = hl_blend;
          hl_ids[6] = hl_through;
        }
        return;
      }
    }
    VALIDATE_S(false, "border", str.data, {
      return;
    });
  }
}

static void generate_api_error(win_T *wp, const char *attribute, Error *err)
{
  if (wp != NULL && wp->w_floating) {
    api_set_error(err, kErrorTypeValidation,
                  "Required: 'relative' when reconfiguring floating window %d",
                  wp->handle);
  } else {
    VALIDATE_CON(false, attribute, "non-float window", {});
  }
}

/// Parses a border style name or custom (comma-separated) style.
bool parse_winborder(WinConfig *fconfig, char *border_opt, Error *err)
{
  if (!fconfig) {
    return false;
  }
  Object style = OBJECT_INIT;

  if (strchr(border_opt, ',')) {
    Array border_chars = ARRAY_DICT_INIT;
    char *p = border_opt;
    char part[MAX_SCHAR_SIZE] = { 0 };
    int count = 0;

    while (*p != NUL) {
      if (count >= 8) {
        api_free_array(border_chars);
        return false;
      }

      size_t part_len = copy_option_part(&p, part, sizeof(part), ",");
      if (part_len == 0 || part[0] == NUL) {
        api_free_array(border_chars);
        return false;
      }

      String str = cstr_to_string(part);
      ADD(border_chars, STRING_OBJ(str));
      count++;
    }

    if (count != 8) {
      api_free_array(border_chars);
      return false;
    }

    style = ARRAY_OBJ(border_chars);
  } else {
    style = CSTR_TO_OBJ(border_opt);
  }

  parse_border_style(style, fconfig, err);
  api_free_object(style);
  return !ERROR_SET(err);
}

static bool parse_win_config(win_T *wp, Dict(win_config) *config, WinConfig *fconfig, bool reconf,
                             Error *err)
{
  bool has_relative = false, relative_is_win = false, is_split = false;
  if (config->relative.size > 0) {
    VALIDATE_S(parse_float_relative(config->relative, &fconfig->relative),
               "relative", config->relative.data, {
      goto fail;
    });

    VALIDATE_R(!(config->relative.size > 0 && !(HAS_KEY_X(config, row) && HAS_KEY_X(config, col))
                 && !HAS_KEY_X(config, bufpos)), "'relative' requires 'row'/'col' or 'bufpos'", {
      goto fail;
    });

    has_relative = true;
    fconfig->external = false;
    if (fconfig->relative == kFloatRelativeWindow) {
      relative_is_win = true;
      fconfig->bufpos.lnum = -1;
    }
  } else if (!config->external) {
    if (HAS_KEY_X(config, vertical) || HAS_KEY_X(config, split)) {
      is_split = true;
      fconfig->external = false;
    } else if (wp == NULL) {  // new win
      VALIDATE_R(false, "'relative' or 'external' when creating a float", {
        goto fail;
      });
    }
  }

  VALIDATE_CON(!(HAS_KEY_X(config, vertical) && !is_split), "vertical", "floating windows", {
    goto fail;
  });

  VALIDATE_CON(!(HAS_KEY_X(config, split) && !is_split), "split", "floating windows", {
    goto fail;
  });

  if (HAS_KEY_X(config, split)) {
    VALIDATE_CON(is_split, "split", "floating windows", {
      goto fail;
    });
    VALIDATE_S(parse_config_split(config->split, &fconfig->split), "split", config->split.data, {
      goto fail;
    });
  }

  if (HAS_KEY_X(config, anchor)) {
    VALIDATE_S(parse_float_anchor(config->anchor, &fconfig->anchor),
               "anchor", config->anchor.data, {
      goto fail;
    });
  }

  if (HAS_KEY_X(config, row)) {
    if (!has_relative || is_split) {
      generate_api_error(wp, "row", err);
      goto fail;
    }
    fconfig->row = config->row;
  }

  if (HAS_KEY_X(config, col)) {
    if (!has_relative || is_split) {
      generate_api_error(wp, "col", err);
      goto fail;
    }
    fconfig->col = config->col;
  }

  if (HAS_KEY_X(config, bufpos)) {
    if (!has_relative || is_split) {
      generate_api_error(wp, "bufpos", err);
      goto fail;
    } else {
      VALIDATE_EXP(parse_float_bufpos(config->bufpos, &fconfig->bufpos),
                   "bufpos", "[row, col] array", NULL, {
        goto fail;
      });

      if (!HAS_KEY_X(config, row)) {
        fconfig->row = (fconfig->anchor & kFloatAnchorSouth) ? 0 : 1;
      }
      if (!HAS_KEY_X(config, col)) {
        fconfig->col = 0;
      }
    }
  }

  if (HAS_KEY_X(config, width)) {
    VALIDATE_EXP((config->width > 0), "width", "positive Integer", NULL, {
      goto fail;
    });
    fconfig->width = (int)config->width;
  } else if (!reconf && !is_split) {
    VALIDATE_R(false, "width", {
      goto fail;
    });
  }

  if (HAS_KEY_X(config, height)) {
    VALIDATE_EXP((config->height > 0), "height", "positive Integer", NULL, {
      goto fail;
    });
    fconfig->height = (int)config->height;
  } else if (!reconf && !is_split) {
    VALIDATE_R(false, "height", {
      goto fail;
    });
  }

  if (HAS_KEY_X(config, external)) {
    fconfig->external = config->external;
    VALIDATE_CON(!(has_relative && fconfig->external), "relative", "external", {
      goto fail;
    });
    if (fconfig->external && !ui_has(kUIMultigrid)) {
      api_set_error(err, kErrorTypeValidation, "UI doesn't support external windows");
      goto fail;
    }
  }

  VALIDATE_CON(!(HAS_KEY_X(config, win) && fconfig->external), "win", "external window", {
    goto fail;
  });

  if (relative_is_win || (HAS_KEY_X(config, win) && !is_split && wp && wp->w_floating
                          && fconfig->relative == kFloatRelativeWindow)) {
    // When relative=win is given, missing win field means win=0.
    win_T *target_win = find_window_by_handle(config->win, err);
    if (!target_win) {
      goto fail;
    }
    if (target_win == wp) {
      api_set_error(err, kErrorTypeException, "floating window cannot be relative to itself");
      goto fail;
    }
    fconfig->window = target_win->handle;
  } else {
    // Handle is not validated here, as win_config_split can accept negative values.
    if (HAS_KEY_X(config, win)) {
      VALIDATE_R(!(!is_split && !has_relative && (!wp || !wp->w_floating)),
                 "non-float with 'win' requires 'split' or 'vertical'", {
        goto fail;
      });

      fconfig->window = config->win;
    }
    // Resolve, but skip validating. E.g: win_config_split accepts negative "win".
    if (fconfig->window == 0) {
      fconfig->window = curwin->handle;
    }
  }

  if (HAS_KEY_X(config, focusable)) {
    fconfig->focusable = config->focusable;
    fconfig->mouse = config->focusable;
  }

  if (HAS_KEY_X(config, mouse)) {
    fconfig->mouse = config->mouse;
  }

  if (HAS_KEY_X(config, zindex)) {
    VALIDATE_CON(!is_split, "zindex", "non-float window", {
      goto fail;
    });
    VALIDATE_EXP((config->zindex > 0), "zindex", "positive Integer", NULL, {
      goto fail;
    });
    fconfig->zindex = (int)config->zindex;
  }

  if (HAS_KEY_X(config, title)) {
    VALIDATE_CON(!is_split, "title", "non-float window", {
      goto fail;
    });

    parse_bordertext(config->title, kBorderTextTitle, fconfig, err);
    if (ERROR_SET(err)) {
      goto fail;
    }

    // handles unset 'title_pos' same as empty string
    if (!parse_bordertext_pos(wp, config->title_pos, kBorderTextTitle, fconfig, err)) {
      goto fail;
    }
  } else {
    VALIDATE_R(!HAS_KEY_X(config, title_pos), "'title' requires 'title_pos'", {
      goto fail;
    });
  }

  if (HAS_KEY_X(config, footer)) {
    VALIDATE_CON(!is_split, "footer", "non-float window", {
      goto fail;
    });

    parse_bordertext(config->footer, kBorderTextFooter, fconfig, err);
    if (ERROR_SET(err)) {
      goto fail;
    }

    // handles unset 'footer_pos' same as empty string
    if (!parse_bordertext_pos(wp, config->footer_pos, kBorderTextFooter, fconfig, err)) {
      goto fail;
    }
  } else {
    VALIDATE_R(!HAS_KEY_X(config, footer_pos), "'footer' requires 'footer_pos'", {
      goto fail;
    });
  }

  Object border_style = OBJECT_INIT;
  if (HAS_KEY_X(config, border)) {
    VALIDATE_CON(!is_split, "border", "non-float window", {
      goto fail;
    });
    border_style = config->border;
    if (border_style.type != kObjectTypeNil) {
      parse_border_style(border_style, fconfig, err);
      if (ERROR_SET(err)) {
        goto fail;
      }
    }
  } else if (*p_winborder != NUL && (wp == NULL || !wp->w_floating)
             && !parse_winborder(fconfig, p_winborder, err)) {
    goto fail;
  }

  if (HAS_KEY_X(config, style)) {
    if (config->style.data[0] == NUL) {
      fconfig->style = kWinStyleUnused;
    } else if (striequal(config->style.data, "minimal")) {
      fconfig->style = kWinStyleMinimal;
    } else {
      VALIDATE_S(false, "style", config->style.data, {
        goto fail;
      });
    }
  }

  if (HAS_KEY_X(config, noautocmd)) {
    if (wp && config->noautocmd != fconfig->noautocmd) {
      api_set_error(err, kErrorTypeValidation, "'noautocmd' cannot be changed on existing window");
      goto fail;
    }
    fconfig->noautocmd = config->noautocmd;
  }

  if (HAS_KEY_X(config, fixed)) {
    fconfig->fixed = config->fixed;
  }

  if (HAS_KEY_X(config, hide)) {
    fconfig->hide = config->hide;
  }

  if (HAS_KEY_X(config, _cmdline_offset)) {
    fconfig->_cmdline_offset = (int)config->_cmdline_offset;
  }

  if (HAS_KEY_X(config, drag)) {
    fconfig->drag = config->drag;
  }

  if (HAS_KEY_X(config, dragall)) {
    fconfig->dragall = config->dragall;
  }

  if (HAS_KEY_X(config, resize)) {
    fconfig->resize = config->resize;
  }
  return true;

fail:
  merge_win_config(fconfig, wp != NULL ? wp->w_config : WIN_CONFIG_INIT);
  return false;
}
