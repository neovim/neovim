#include <stdbool.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/extmark.h"
#include "nvim/api/keysets_defs.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/tabpage.h"
#include "nvim/api/win_config.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/decoration.h"
#include "nvim/decoration_defs.h"
#include "nvim/drawscreen.h"
#include "nvim/eval/window.h"
#include "nvim/extmark_defs.h"
#include "nvim/globals.h"
#include "nvim/grid_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/win_config.c.generated.h"
#endif

/// Opens a new split window, or a floating window if `relative` is specified,
/// or an external window (managed by the UI) if `external` is specified.
///
/// Floats are windows that are drawn above the split layout, at some anchor
/// position in some other window. Floats can be drawn internally or by external
/// GUI with the |ui-multigrid| extension. External windows are only supported
/// with multigrid GUIs, and are displayed as separate top-level windows.
///
/// For a general overview of floats, see |api-floatwin|.
///
/// The `width` and `height` of the new window must be specified when opening
/// a floating window, but are optional for normal windows.
///
/// If `relative` and `external` are omitted, a normal "split" window is created.
/// The `win` property determines which window will be split. If no `win` is
/// provided or `win == 0`, a window will be created adjacent to the current window.
/// If -1 is provided, a top-level split will be created. `vertical` and `split` are
/// only valid for normal windows, and are used to control split direction. For `vertical`,
/// the exact direction is determined by |'splitright'| and |'splitbelow'|.
/// Split windows cannot have `bufpos`/`row`/`col`/`border`/`title`/`footer`
/// properties.
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
/// Example (Lua): window-relative float
///
/// ```lua
/// vim.api.nvim_open_win(0, false,
///   {relative='win', row=3, col=3, width=12, height=3})
/// ```
///
/// Example (Lua): buffer-relative float (travels as buffer is scrolled)
///
/// ```lua
/// vim.api.nvim_open_win(0, false,
///   {relative='win', width=12, height=3, bufpos={100,10}})
/// ```
///
/// Example (Lua): vertical split left of the current window
///
/// ```lua
/// vim.api.nvim_open_win(0, false, {
///   split = 'left',
///   win = 0
/// })
/// ```
///
/// @param buffer Buffer to display, or 0 for current buffer
/// @param enter  Enter the window (make it the current window)
/// @param config Map defining the window configuration. Keys:
///   - relative: Sets the window layout to "floating", placed at (row,col)
///                 coordinates relative to:
///      - "editor" The global editor grid
///      - "win"    Window given by the `win` field, or current window.
///      - "cursor" Cursor position in current window.
///      - "mouse"  Mouse position
///   - win: |window-ID| window to split, or relative window when creating a
///      float (relative="win").
///   - anchor: Decides which corner of the float to place at (row,col):
///      - "NW" northwest (default)
///      - "NE" northeast
///      - "SW" southwest
///      - "SE" southeast
///   - width: Window width (in character cells). Minimum of 1.
///   - height: Window height (in character cells). Minimum of 1.
///   - bufpos: Places float relative to buffer text (only when
///       relative="win"). Takes a tuple of zero-indexed `[line, column]`.
///       `row` and `col` if given are applied relative to this
///       position, else they default to:
///       - `row=1` and `col=0` if `anchor` is "NW" or "NE"
///       - `row=0` and `col=0` if `anchor` is "SW" or "SE"
///         (thus like a tooltip near the buffer text).
///   - row: Row position in units of "screen cell height", may be fractional.
///   - col: Column position in units of "screen cell width", may be
///            fractional.
///   - focusable: Enable focus by user actions (wincmds, mouse events).
///       Defaults to true. Non-focusable windows can be entered by
///       |nvim_set_current_win()|.
///   - external: GUI should display the window as an external
///       top-level window. Currently accepts no other positioning
///       configuration together with this.
///   - zindex: Stacking order. floats with higher `zindex` go on top on
///               floats with lower indices. Must be larger than zero. The
///               following screen elements have hard-coded z-indices:
///       - 100: insert completion popupmenu
///       - 200: message scrollback
///       - 250: cmdline completion popupmenu (when wildoptions+=pum)
///     The default value for floats are 50.  In general, values below 100 are
///     recommended, unless there is a good reason to overshadow builtin
///     elements.
///   - style: (optional) Configure the appearance of the window. Currently
///       only supports one value:
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
///   - border: Style of (optional) window border. This can either be a string
///     or an array. The string values are
///     - "none": No border (default).
///     - "single": A single line box.
///     - "double": A double line box.
///     - "rounded": Like "single", but with rounded corners ("╭" etc.).
///     - "solid": Adds padding by a single whitespace cell.
///     - "shadow": A drop shadow effect by blending with the background.
///     - If it is an array, it should have a length of eight or any divisor of
///       eight. The array will specify the eight chars building up the border
///       in a clockwise fashion starting with the top-left corner. As an
///       example, the double box style could be specified as:
///       ```
///       [ "╔", "═" ,"╗", "║", "╝", "═", "╚", "║" ].
///       ```
///       If the number of chars are less than eight, they will be repeated. Thus
///       an ASCII border could be specified as
///       ```
///       [ "/", "-", \"\\\\\", "|" ],
///       ```
///       or all chars the same as
///       ```
///       [ "x" ].
///       ```
///     An empty string can be used to turn off a specific border, for instance,
///     ```
///       [ "", "", "", ">", "", "", "", "<" ]
///     ```
///     will only make vertical borders but not horizontal ones.
///     By default, `FloatBorder` highlight is used, which links to `WinSeparator`
///     when not defined.  It could also be specified by character:
///     ```
///       [ ["+", "MyCorner"], ["x", "MyBorder"] ].
///     ```
///   - title: Title (optional) in window border, string or list.
///     List should consist of `[text, highlight]` tuples.
///     If string, the default highlight group is `FloatTitle`.
///   - title_pos: Title position. Must be set with `title` option.
///     Value can be one of "left", "center", or "right".
///     Default is `"left"`.
///   - footer: Footer (optional) in window border, string or list.
///     List should consist of `[text, highlight]` tuples.
///     If string, the default highlight group is `FloatFooter`.
///   - footer_pos: Footer position. Must be set with `footer` option.
///     Value can be one of "left", "center", or "right".
///     Default is `"left"`.
///   - noautocmd: If true then autocommands triggered from setting the
///     `buffer` to display are blocked (e.g: |BufEnter|, |BufLeave|,
///     |BufWinEnter|).
///   - fixed: If true when anchor is NW or SW, the float window
///            would be kept fixed even if the window would be truncated.
///   - hide: If true the floating window will be hidden.
///   - vertical: Split vertically |:vertical|.
///   - split: Split direction: "left", "right", "above", "below".
///
/// @param[out] err Error details, if any
///
/// @return Window handle, or 0 on error
Window nvim_open_win(Buffer buffer, Boolean enter, Dict(win_config) *config, Error *err)
  FUNC_API_SINCE(6) FUNC_API_TEXTLOCK_ALLOW_CMDWIN
{
#define HAS_KEY_X(d, key) HAS_KEY(d, win_config, key)
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return 0;
  }
  if ((cmdwin_type != 0 && enter) || buf == cmdwin_buf) {
    api_set_error(err, kErrorTypeException, "%s", e_cmdwin);
    return 0;
  }

  WinConfig fconfig = WIN_CONFIG_INIT;
  if (!parse_float_config(NULL, config, &fconfig, false, err)) {
    return 0;
  }

  bool is_split = HAS_KEY_X(config, split) || HAS_KEY_X(config, vertical);

  win_T *wp = NULL;
  tabpage_T *tp = curtab;
  if (is_split) {
    win_T *parent = NULL;
    if (config->win != -1) {
      parent = find_window_by_handle(fconfig.window, err);
      if (!parent) {
        // find_window_by_handle has already set the error
        return 0;
      } else if (parent->w_floating) {
        api_set_error(err, kErrorTypeException, "Cannot split a floating window");
        return 0;
      }
    }

    if (!check_split_disallowed_err(parent ? parent : curwin, err)) {
      return 0;  // error already set
    }

    if (HAS_KEY_X(config, vertical) && !HAS_KEY_X(config, split)) {
      if (config->vertical) {
        fconfig.split = p_spr ? kWinSplitRight : kWinSplitLeft;
      } else {
        fconfig.split = p_sb ? kWinSplitBelow : kWinSplitAbove;
      }
    }
    int flags = win_split_flags(fconfig.split, parent == NULL) | WSP_NOENTER;

    TRY_WRAP(err, {
      if (parent == NULL || parent == curwin) {
        wp = win_split_ins(0, flags, NULL, 0, NULL);
      } else {
        tp = win_find_tabpage(parent);
        switchwin_T switchwin;
        // `parent` is valid in `tp`, so switch_win should not fail.
        const int result = switch_win(&switchwin, parent, tp, true);
        assert(result == OK);
        (void)result;
        wp = win_split_ins(0, flags, NULL, 0, NULL);
        restore_win(&switchwin, true);
      }
    });
    if (wp) {
      wp->w_config = fconfig;
    }
  } else {
    wp = win_new_float(NULL, false, fconfig, err);
  }
  if (!wp) {
    if (!ERROR_SET(err)) {
      api_set_error(err, kErrorTypeException, "Failed to create window");
    }
    return 0;
  }

  // Autocommands may close `wp` or move it to another tabpage, so update and check `tp` after each
  // event. In each case, `wp` should already be valid in `tp`, so switch_win should not fail.
  // Also, autocommands may free the `buf` to switch to, so store a bufref to check.
  bufref_T bufref;
  set_bufref(&bufref, buf);
  switchwin_T switchwin;
  {
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
  if (tp && bufref_valid(&bufref) && buf != wp->w_buffer) {
    // win_set_buf temporarily makes `wp` the curwin to set the buffer.
    // If not entering `wp`, block Enter and Leave events. (cringe)
    const bool au_no_enter_leave = curwin != wp && !fconfig.noautocmd;
    if (au_no_enter_leave) {
      autocmd_no_enter++;
      autocmd_no_leave++;
    }
    win_set_buf(wp, buf, fconfig.noautocmd, err);
    if (!fconfig.noautocmd) {
      tp = win_find_tabpage(wp);
    }
    if (au_no_enter_leave) {
      autocmd_no_enter--;
      autocmd_no_leave--;
    }
  }
  if (!tp) {
    api_set_error(err, kErrorTypeException, "Window was closed immediately");
    return 0;
  }

  if (fconfig.style == kWinStyleMinimal) {
    win_set_minimal_style(wp);
    didset_window_options(wp, true);
  }
  return wp->handle;
#undef HAS_KEY_X
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

/// Configures window layout. Cannot be used to move the last window in a
/// tabpage to a different one.
///
/// When reconfiguring a window, absent option keys will not be changed.
/// `row`/`col` and `relative` must be reconfigured together.
///
/// @see |nvim_open_win()|
///
/// @param      window  Window handle, or 0 for current window
/// @param      config  Map defining the window configuration,
///                     see |nvim_open_win()|
/// @param[out] err     Error details, if any
void nvim_win_set_config(Window window, Dict(win_config) *config, Error *err)
  FUNC_API_SINCE(6)
{
#define HAS_KEY_X(d, key) HAS_KEY(d, win_config, key)
  win_T *win = find_window_by_handle(window, err);
  if (!win) {
    return;
  }
  tabpage_T *win_tp = win_find_tabpage(win);
  bool was_split = !win->w_floating;
  bool has_split = HAS_KEY_X(config, split);
  bool has_vertical = HAS_KEY_X(config, vertical);
  // reuse old values, if not overridden
  WinConfig fconfig = win->w_config;

  bool to_split = config->relative.size == 0
                  && !(HAS_KEY_X(config, external) ? config->external : fconfig.external)
                  && (has_split || has_vertical || was_split);

  if (!parse_float_config(win, config, &fconfig, !was_split || to_split, err)) {
    return;
  }
  if (was_split && !to_split) {
    if (!win_new_float(win, false, fconfig, err)) {
      return;
    }
    redraw_later(win, UPD_NOT_VALID);
  } else if (to_split) {
    win_T *parent = NULL;
    if (config->win != -1) {
      parent = find_window_by_handle(fconfig.window, err);
      if (!parent) {
        return;
      } else if (parent->w_floating) {
        api_set_error(err, kErrorTypeException, "Cannot split a floating window");
        return;
      }
    }

    WinSplit old_split = win_split_dir(win);
    if (has_vertical && !has_split) {
      if (config->vertical) {
        if (old_split == kWinSplitRight || p_spr) {
          fconfig.split = kWinSplitRight;
        } else {
          fconfig.split = kWinSplitLeft;
        }
      } else {
        if (old_split == kWinSplitBelow || p_sb) {
          fconfig.split = kWinSplitBelow;
        } else {
          fconfig.split = kWinSplitAbove;
        }
      }
    }
    win->w_config = fconfig;

    // If there's no "vertical" or "split" set, or if "split" is unchanged,
    // then we can just change the size of the window.
    if ((!has_vertical && !has_split)
        || (was_split && !HAS_KEY_X(config, win) && old_split == fconfig.split)) {
      if (HAS_KEY_X(config, width)) {
        win_setwidth_win(fconfig.width, win);
      }
      if (HAS_KEY_X(config, height)) {
        win_setheight_win(fconfig.height, win);
      }
      redraw_later(win, UPD_NOT_VALID);
      return;
    }

    if (!check_split_disallowed_err(win, err)) {
      return;  // error already set
    }
    // Can't move the cmdwin or its old curwin to a different tabpage.
    if ((win == cmdwin_win || win == cmdwin_old_curwin) && parent != NULL
        && win_find_tabpage(parent) != win_tp) {
      api_set_error(err, kErrorTypeException, "%s", e_cmdwin);
      return;
    }

    bool to_split_ok = false;
    // If we are moving curwin to another tabpage, switch windows *before* we remove it from the
    // window list or remove its frame (if non-floating), so it's valid for autocommands.
    const bool curwin_moving_tp
      = win == curwin && parent != NULL && win_tp != win_find_tabpage(parent);
    if (curwin_moving_tp) {
      if (was_split) {
        int dir;
        win_goto(winframe_find_altwin(win, &dir, NULL, NULL));
      } else {
        win_goto(win_float_find_altwin(win, NULL));
      }

      // Autocommands may have been a real nuisance and messed things up...
      if (curwin == win) {
        api_set_error(err, kErrorTypeException, "Failed to switch away from window %d",
                      win->handle);
        return;
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
      // If the window is the last in the tabpage or `fconfig.win` is
      // a handle to itself, we can't split it.
      if (win->w_frame->fr_parent == NULL) {
        // FIXME(willothy): if the window is the last in the tabpage but there is another tabpage
        // and the target window is in that other tabpage, should we move the window to that
        // tabpage and close the previous one, or just error?
        api_set_error(err, kErrorTypeException, "Cannot move last window");
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
            if (fconfig.split == kWinSplitAbove || fconfig.split == kWinSplitLeft) {
              neighbor = win->w_next;
            } else {
              neighbor = win->w_prev;
            }
          }
          // If the frame doesn't have a parent, the old frame
          // was the root frame and we need to create a top-level split.
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

    int flags = win_split_flags(fconfig.split, parent == NULL) | WSP_NOENTER;
    tabpage_T *const parent_tp = parent ? win_find_tabpage(parent) : curtab;

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
      return;
    }

    // If `win` moved tabpages and was the curwin of its old one, select a new curwin for it.
    if (win_tp != parent_tp && win_tp->tp_curwin == win) {
      win_tp->tp_curwin = altwin;
    }

    if (HAS_KEY_X(config, width)) {
      win_setwidth_win(fconfig.width, win);
    }
    if (HAS_KEY_X(config, height)) {
      win_setheight_win(fconfig.height, win);
    }
  } else {
    win_config_float(win, fconfig);
    win->w_pos_changed = true;
  }
  if (HAS_KEY_X(config, style)) {
    if (fconfig.style == kWinStyleMinimal) {
      win_set_minimal_style(win);
      didset_window_options(win, true);
    }
  }
#undef HAS_KEY_X
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

/// Gets window configuration.
///
/// The returned value may be given to |nvim_open_win()|.
///
/// `relative` is empty for normal windows.
///
/// @param      window Window handle, or 0 for current window
/// @param[out] err Error details, if any
/// @return     Map defining the window configuration, see |nvim_open_win()|
Dict(win_config) nvim_win_get_config(Window window, Arena *arena, Error *err)
  FUNC_API_SINCE(6)
{
  /// Keep in sync with FloatRelative in buffer_defs.h
  static const char *const float_relative_str[] = { "editor", "win", "cursor", "mouse" };

  /// Keep in sync with WinSplit in buffer_defs.h
  static const char *const win_split_str[] = { "left", "right", "above", "below" };

  Dict(win_config) rv = KEYDICT_INIT;

  win_T *wp = find_window_by_handle(window, err);
  if (!wp) {
    return rv;
  }

  WinConfig *config = &wp->w_config;

  PUT_KEY_X(rv, focusable, config->focusable);
  PUT_KEY_X(rv, external, config->external);
  PUT_KEY_X(rv, hide, config->hide);

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
  if (bordertext.type != kObjectTypeString && bordertext.type != kObjectTypeArray) {
    api_set_error(err, kErrorTypeValidation, "title/footer must be string or array");
    return;
  }

  if (bordertext.type == kObjectTypeArray && bordertext.data.array.size == 0) {
    api_set_error(err, kErrorTypeValidation, "title/footer cannot be an empty array");
    return;
  }

  bool *is_present;
  VirtText *chunks;
  int *width;
  int default_hl_id;
  switch (bordertext_type) {
  case kBorderTextTitle:
    if (fconfig->title) {
      clear_virttext(&fconfig->title_chunks);
    }

    is_present = &fconfig->title;
    chunks = &fconfig->title_chunks;
    width = &fconfig->title_width;
    default_hl_id = syn_check_group(S_LEN("FloatTitle"));
    break;
  case kBorderTextFooter:
    if (fconfig->footer) {
      clear_virttext(&fconfig->footer_chunks);
    }

    is_present = &fconfig->footer;
    chunks = &fconfig->footer_chunks;
    width = &fconfig->footer_width;
    default_hl_id = syn_check_group(S_LEN("FloatFooter"));
    break;
  }

  if (bordertext.type == kObjectTypeString) {
    if (bordertext.data.string.size == 0) {
      *is_present = false;
      return;
    }
    kv_push(*chunks, ((VirtTextChunk){ .text = xstrdup(bordertext.data.string.data),
                                       .hl_id = default_hl_id }));
    *width = (int)mb_string2cells(bordertext.data.string.data);
    *is_present = true;
    return;
  }

  *width = 0;
  *chunks = parse_virt_text(bordertext.data.array, err, width);

  *is_present = true;
}

static bool parse_bordertext_pos(String bordertext_pos, BorderTextType bordertext_type,
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
    *align = kAlignLeft;
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
    switch (bordertext_type) {
    case kBorderTextTitle:
      api_set_error(err, kErrorTypeValidation, "invalid title_pos value");
      break;
    case kBorderTextFooter:
      api_set_error(err, kErrorTypeValidation, "invalid footer_pos value");
      break;
    }
    return false;
  }
  return true;
}

static void parse_border_style(Object style, WinConfig *fconfig, Error *err)
{
  struct {
    const char *name;
    char chars[8][MAX_SCHAR_SIZE];
    bool shadow_color;
  } defaults[] = {
    { "double", { "╔", "═", "╗", "║", "╝", "═", "╚", "║" }, false },
    { "single", { "┌", "─", "┐", "│", "┘", "─", "└", "│" }, false },
    { "shadow", { "", "", " ", " ", " ", " ", " ", "" }, true },
    { "rounded", { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }, false },
    { "solid", { " ", " ", " ", " ", " ", " ", " ", " " }, false },
    { NULL, { { NUL } }, false },
  };

  char(*chars)[MAX_SCHAR_SIZE] = fconfig->border_chars;
  int *hl_ids = fconfig->border_hl_ids;

  fconfig->border = true;

  if (style.type == kObjectTypeArray) {
    Array arr = style.data.array;
    size_t size = arr.size;
    if (!size || size > 8 || (size & (size - 1))) {
      api_set_error(err, kErrorTypeValidation, "invalid number of border chars");
      return;
    }
    for (size_t i = 0; i < size; i++) {
      Object iytem = arr.items[i];
      String string;
      int hl_id = 0;
      if (iytem.type == kObjectTypeArray) {
        Array iarr = iytem.data.array;
        if (!iarr.size || iarr.size > 2) {
          api_set_error(err, kErrorTypeValidation, "invalid border char");
          return;
        }
        if (iarr.items[0].type != kObjectTypeString) {
          api_set_error(err, kErrorTypeValidation, "invalid border char");
          return;
        }
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
        api_set_error(err, kErrorTypeValidation, "invalid border char");
        return;
      }
      if (string.size && mb_string2cells_len(string.data, string.size) > 1) {
        api_set_error(err, kErrorTypeValidation, "border chars must be one cell");
        return;
      }
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
    if ((chars[7][0] && chars[1][0] && !chars[0][0])
        || (chars[1][0] && chars[3][0] && !chars[2][0])
        || (chars[3][0] && chars[5][0] && !chars[4][0])
        || (chars[5][0] && chars[7][0] && !chars[6][0])) {
      api_set_error(err, kErrorTypeValidation, "corner between used edges must be specified");
    }
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
    api_set_error(err, kErrorTypeValidation, "invalid border style \"%s\"", str.data);
  }
}

static void generate_api_error(win_T *wp, const char *attribute, Error *err)
{
  if (wp->w_floating) {
    api_set_error(err, kErrorTypeValidation,
                  "Missing 'relative' field when reconfiguring floating window %d",
                  wp->handle);
  } else {
    api_set_error(err, kErrorTypeValidation, "non-float cannot have '%s'", attribute);
  }
}

static bool parse_float_config(win_T *wp, Dict(win_config) *config, WinConfig *fconfig, bool reconf,
                               Error *err)
{
#define HAS_KEY_X(d, key) HAS_KEY(d, win_config, key)
  bool has_relative = false, relative_is_win = false, is_split = false;
  if (config->relative.size > 0) {
    if (!parse_float_relative(config->relative, &fconfig->relative)) {
      api_set_error(err, kErrorTypeValidation, "Invalid value of 'relative' key");
      return false;
    }

    if (config->relative.size > 0 && !(HAS_KEY_X(config, row) && HAS_KEY_X(config, col))
        && !HAS_KEY_X(config, bufpos)) {
      api_set_error(err, kErrorTypeValidation, "'relative' requires 'row'/'col' or 'bufpos'");
      return false;
    }

    has_relative = true;
    fconfig->external = false;
    if (fconfig->relative == kFloatRelativeWindow) {
      relative_is_win = true;
      fconfig->bufpos.lnum = -1;
    }
  } else if (!config->external) {
    if (HAS_KEY_X(config, vertical) || HAS_KEY_X(config, split)) {
      is_split = true;
    } else if (wp == NULL) {  // new win
      api_set_error(err, kErrorTypeValidation,
                    "Must specify 'relative' or 'external' when creating a float");
      return false;
    }
  }

  if (HAS_KEY_X(config, vertical)) {
    if (!is_split) {
      api_set_error(err, kErrorTypeValidation, "floating windows cannot have 'vertical'");
      return false;
    }
  }

  if (HAS_KEY_X(config, split)) {
    if (!is_split) {
      api_set_error(err, kErrorTypeValidation, "floating windows cannot have 'split'");
      return false;
    }
    if (!parse_config_split(config->split, &fconfig->split)) {
      api_set_error(err, kErrorTypeValidation, "Invalid value of 'split' key");
      return false;
    }
  }

  if (HAS_KEY_X(config, anchor)) {
    if (!parse_float_anchor(config->anchor, &fconfig->anchor)) {
      api_set_error(err, kErrorTypeValidation, "Invalid value of 'anchor' key");
      return false;
    }
  }

  if (HAS_KEY_X(config, row)) {
    if (!has_relative || is_split) {
      generate_api_error(wp, "row", err);
      return false;
    }
    fconfig->row = config->row;
  }

  if (HAS_KEY_X(config, col)) {
    if (!has_relative || is_split) {
      generate_api_error(wp, "col", err);
      return false;
    }
    fconfig->col = config->col;
  }

  if (HAS_KEY_X(config, bufpos)) {
    if (!has_relative || is_split) {
      generate_api_error(wp, "bufpos", err);
      return false;
    } else {
      if (!parse_float_bufpos(config->bufpos, &fconfig->bufpos)) {
        api_set_error(err, kErrorTypeValidation, "Invalid value of 'bufpos' key");
        return false;
      }

      if (!HAS_KEY_X(config, row)) {
        fconfig->row = (fconfig->anchor & kFloatAnchorSouth) ? 0 : 1;
      }
      if (!HAS_KEY_X(config, col)) {
        fconfig->col = 0;
      }
    }
  }

  if (HAS_KEY_X(config, width)) {
    if (config->width > 0) {
      fconfig->width = (int)config->width;
    } else {
      api_set_error(err, kErrorTypeValidation, "'width' key must be a positive Integer");
      return false;
    }
  } else if (!reconf && !is_split) {
    api_set_error(err, kErrorTypeValidation, "Must specify 'width'");
    return false;
  }

  if (HAS_KEY_X(config, height)) {
    if (config->height > 0) {
      fconfig->height = (int)config->height;
    } else {
      api_set_error(err, kErrorTypeValidation, "'height' key must be a positive Integer");
      return false;
    }
  } else if (!reconf && !is_split) {
    api_set_error(err, kErrorTypeValidation, "Must specify 'height'");
    return false;
  }

  if (relative_is_win || is_split) {
    if (reconf && relative_is_win) {
      win_T *target_win = find_window_by_handle(config->win, err);
      if (!target_win) {
        return false;
      }

      if (target_win == wp) {
        api_set_error(err, kErrorTypeException, "floating window cannot be relative to itself");
        return false;
      }
    }
    fconfig->window = curwin->handle;
    if (HAS_KEY_X(config, win)) {
      if (config->win > 0) {
        fconfig->window = config->win;
      }
    }
  } else if (HAS_KEY_X(config, win)) {
    if (has_relative) {
      api_set_error(err, kErrorTypeValidation,
                    "'win' key is only valid with relative='win' and relative=''");
      return false;
    } else if (!is_split) {
      api_set_error(err, kErrorTypeValidation,
                    "non-float with 'win' requires at least 'split' or 'vertical'");
      return false;
    }
  }

  if (HAS_KEY_X(config, external)) {
    fconfig->external = config->external;
    if (has_relative && fconfig->external) {
      api_set_error(err, kErrorTypeValidation,
                    "Only one of 'relative' and 'external' must be used");
      return false;
    }
    if (fconfig->external && !ui_has(kUIMultigrid)) {
      api_set_error(err, kErrorTypeValidation, "UI doesn't support external windows");
      return false;
    }
  }

  if (HAS_KEY_X(config, focusable)) {
    fconfig->focusable = config->focusable;
  }

  if (HAS_KEY_X(config, zindex)) {
    if (is_split) {
      api_set_error(err, kErrorTypeValidation, "non-float cannot have 'zindex'");
      return false;
    }
    if (config->zindex > 0) {
      fconfig->zindex = (int)config->zindex;
    } else {
      api_set_error(err, kErrorTypeValidation, "'zindex' key must be a positive Integer");
      return false;
    }
  }

  if (HAS_KEY_X(config, title)) {
    if (is_split) {
      api_set_error(err, kErrorTypeValidation, "non-float cannot have 'title'");
      return false;
    }
    // title only work with border
    if (!HAS_KEY_X(config, border) && !fconfig->border) {
      api_set_error(err, kErrorTypeException, "title requires border to be set");
      return false;
    }

    parse_bordertext(config->title, kBorderTextTitle, fconfig, err);
    if (ERROR_SET(err)) {
      return false;
    }

    // handles unset 'title_pos' same as empty string
    if (!parse_bordertext_pos(config->title_pos, kBorderTextTitle, fconfig, err)) {
      return false;
    }
  } else {
    if (HAS_KEY_X(config, title_pos)) {
      api_set_error(err, kErrorTypeException, "title_pos requires title to be set");
      return false;
    }
  }

  if (HAS_KEY_X(config, footer)) {
    if (is_split) {
      api_set_error(err, kErrorTypeValidation, "non-float cannot have 'footer'");
      return false;
    }
    // footer only work with border
    if (!HAS_KEY_X(config, border) && !fconfig->border) {
      api_set_error(err, kErrorTypeException, "footer requires border to be set");
      return false;
    }

    parse_bordertext(config->footer, kBorderTextFooter, fconfig, err);
    if (ERROR_SET(err)) {
      return false;
    }

    // handles unset 'footer_pos' same as empty string
    if (!parse_bordertext_pos(config->footer_pos, kBorderTextFooter, fconfig, err)) {
      return false;
    }
  } else {
    if (HAS_KEY_X(config, footer_pos)) {
      api_set_error(err, kErrorTypeException, "footer_pos requires footer to be set");
      return false;
    }
  }

  if (HAS_KEY_X(config, border)) {
    if (is_split) {
      api_set_error(err, kErrorTypeValidation, "non-float cannot have 'border'");
      return false;
    }
    parse_border_style(config->border, fconfig, err);
    if (ERROR_SET(err)) {
      return false;
    }
  }

  if (HAS_KEY_X(config, style)) {
    if (config->style.data[0] == NUL) {
      fconfig->style = kWinStyleUnused;
    } else if (striequal(config->style.data, "minimal")) {
      fconfig->style = kWinStyleMinimal;
    } else {
      api_set_error(err, kErrorTypeValidation, "Invalid value of 'style' key");
      return false;
    }
  }

  if (HAS_KEY_X(config, noautocmd)) {
    if (wp) {
      api_set_error(err, kErrorTypeValidation, "'noautocmd' cannot be used with existing windows");
      return false;
    }
    fconfig->noautocmd = config->noautocmd;
  }

  if (HAS_KEY_X(config, fixed)) {
    fconfig->fixed = config->fixed;
  }

  if (HAS_KEY_X(config, hide)) {
    fconfig->hide = config->hide;
  }

  return true;
#undef HAS_KEY_X
}
