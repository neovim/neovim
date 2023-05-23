// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdbool.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/extmark.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/win_config.h"
#include "nvim/ascii.h"
#include "nvim/buffer_defs.h"
#include "nvim/decoration.h"
#include "nvim/drawscreen.h"
#include "nvim/extmark_defs.h"
#include "nvim/globals.h"
#include "nvim/grid_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/macros.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/option.h"
#include "nvim/pos.h"
#include "nvim/syntax.h"
#include "nvim/ui.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/win_config.c.generated.h"
#endif

/// Open a new window.
///
/// Currently this is used to open floating and external windows.
/// Floats are windows that are drawn above the split layout, at some anchor
/// position in some other window. Floats can be drawn internally or by external
/// GUI with the |ui-multigrid| extension. External windows are only supported
/// with multigrid GUIs, and are displayed as separate top-level windows.
///
/// For a general overview of floats, see |api-floatwin|.
///
/// Exactly one of `external` and `relative` must be specified. The `width` and
/// `height` of the new window must be specified.
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
/// <pre>lua
///     vim.api.nvim_open_win(0, false,
///       {relative='win', row=3, col=3, width=12, height=3})
/// </pre>
///
/// Example (Lua): buffer-relative float (travels as buffer is scrolled)
/// <pre>lua
///     vim.api.nvim_open_win(0, false,
///       {relative='win', width=12, height=3, bufpos={100,10}})
/// </pre>
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
///   - win: |window-ID| for relative="win".
///   - anchor: Decides which corner of the float to place at (row,col):
///      - "NW" northwest (default)
///      - "NE" northeast
///      - "SW" southwest
///      - "SE" southeast
///   - width: Window width (in character cells). Minimum of 1.
///   - height: Window height (in character cells). Minimum of 1.
///   - bufpos: Places float relative to buffer text (only when
///               relative="win"). Takes a tuple of zero-indexed [line, column].
///               `row` and `col` if given are applied relative to this
///               position, else they default to:
///               - `row=1` and `col=0` if `anchor` is "NW" or "NE"
///               - `row=0` and `col=0` if `anchor` is "SW" or "SE"
///               (thus like a tooltip near the buffer text).
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
///      or an array. The string values are
///     - "none": No border (default).
///     - "single": A single line box.
///     - "double": A double line box.
///     - "rounded": Like "single", but with rounded corners ("╭" etc.).
///     - "solid": Adds padding by a single whitespace cell.
///     - "shadow": A drop shadow effect by blending with the background.
///     - If it is an array, it should have a length of eight or any divisor of
///     eight. The array will specifify the eight chars building up the border
///     in a clockwise fashion starting with the top-left corner. As an
///     example, the double box style could be specified as
///       [ "╔", "═" ,"╗", "║", "╝", "═", "╚", "║" ].
///     If the number of chars are less than eight, they will be repeated. Thus
///     an ASCII border could be specified as
///       [ "/", "-", \"\\\\\", "|" ],
///     or all chars the same as
///       [ "x" ].
///     An empty string can be used to turn off a specific border, for instance,
///       [ "", "", "", ">", "", "", "", "<" ]
///     will only make vertical borders but not horizontal ones.
///     By default, `FloatBorder` highlight is used, which links to `WinSeparator`
///     when not defined.  It could also be specified by character:
///       [ ["+", "MyCorner"], ["x", "MyBorder"] ].
///   - title: Title (optional) in window border, String or list.
///     List is [text, highlight] tuples. if is string the default
///     highlight group is `FloatTitle`.
///   - title_pos: Title position must set with title option.
///     value can be of `left` `center` `right` default is left.
///   - noautocmd: If true then no buffer-related autocommand events such as
///                  |BufEnter|, |BufLeave| or |BufWinEnter| may fire from
///                  calling this function.
///
/// @param[out] err Error details, if any
///
/// @return Window handle, or 0 on error
Window nvim_open_win(Buffer buffer, Boolean enter, Dict(float_config) *config, Error *err)
  FUNC_API_SINCE(6)
  FUNC_API_CHECK_TEXTLOCK
{
  FloatConfig fconfig = FLOAT_CONFIG_INIT;
  if (!parse_float_config(config, &fconfig, false, true, err)) {
    return 0;
  }
  win_T *wp = win_new_float(NULL, false, fconfig, err);
  if (!wp) {
    return 0;
  }
  if (enter) {
    win_enter(wp, false);
  }
  // autocmds in win_enter or win_set_buf below may close the window
  if (win_valid(wp) && buffer > 0) {
    win_set_buf(wp->handle, buffer, fconfig.noautocmd, err);
  }
  if (!win_valid(wp)) {
    api_set_error(err, kErrorTypeException, "Window was closed immediately");
    return 0;
  }

  if (fconfig.style == kWinStyleMinimal) {
    win_set_minimal_style(wp);
    didset_window_options(wp, true);
  }
  return wp->handle;
}

/// Configures window layout. Currently only for floating and external windows
/// (including changing a split window to those layouts).
///
/// When reconfiguring a floating window, absent option keys will not be
/// changed.  `row`/`col` and `relative` must be reconfigured together.
///
/// @see |nvim_open_win()|
///
/// @param      window  Window handle, or 0 for current window
/// @param      config  Map defining the window configuration,
///                     see |nvim_open_win()|
/// @param[out] err     Error details, if any
void nvim_win_set_config(Window window, Dict(float_config) *config, Error *err)
  FUNC_API_SINCE(6)
{
  win_T *win = find_window_by_handle(window, err);
  if (!win) {
    return;
  }
  bool new_float = !win->w_floating;
  // reuse old values, if not overridden
  FloatConfig fconfig = new_float ? FLOAT_CONFIG_INIT : win->w_float_config;

  if (!parse_float_config(config, &fconfig, !new_float, false, err)) {
    return;
  }
  if (new_float) {
    if (!win_new_float(win, false, fconfig, err)) {
      return;
    }
    redraw_later(win, UPD_NOT_VALID);
  } else {
    win_config_float(win, fconfig);
    win->w_pos_changed = true;
  }
  if (HAS_KEY(config->style)) {
    if (fconfig.style == kWinStyleMinimal) {
      win_set_minimal_style(win);
      didset_window_options(win, true);
    }
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
Dictionary nvim_win_get_config(Window window, Error *err)
  FUNC_API_SINCE(6)
{
  Dictionary rv = ARRAY_DICT_INIT;

  win_T *wp = find_window_by_handle(window, err);
  if (!wp) {
    return rv;
  }

  FloatConfig *config = &wp->w_float_config;

  PUT(rv, "focusable", BOOLEAN_OBJ(config->focusable));
  PUT(rv, "external", BOOLEAN_OBJ(config->external));

  if (wp->w_floating) {
    PUT(rv, "width", INTEGER_OBJ(config->width));
    PUT(rv, "height", INTEGER_OBJ(config->height));
    if (!config->external) {
      if (config->relative == kFloatRelativeWindow) {
        PUT(rv, "win", INTEGER_OBJ(config->window));
        if (config->bufpos.lnum >= 0) {
          Array pos = ARRAY_DICT_INIT;
          ADD(pos, INTEGER_OBJ(config->bufpos.lnum));
          ADD(pos, INTEGER_OBJ(config->bufpos.col));
          PUT(rv, "bufpos", ARRAY_OBJ(pos));
        }
      }
      PUT(rv, "anchor", CSTR_TO_OBJ(float_anchor_str[config->anchor]));
      PUT(rv, "row", FLOAT_OBJ(config->row));
      PUT(rv, "col", FLOAT_OBJ(config->col));
      PUT(rv, "zindex", INTEGER_OBJ(config->zindex));
    }
    if (config->border) {
      Array border = ARRAY_DICT_INIT;
      for (size_t i = 0; i < 8; i++) {
        Array tuple = ARRAY_DICT_INIT;

        String s = cstrn_to_string(config->border_chars[i], sizeof(schar_T));

        int hi_id = config->border_hl_ids[i];
        char *hi_name = syn_id2name(hi_id);
        if (hi_name[0]) {
          ADD(tuple, STRING_OBJ(s));
          ADD(tuple, CSTR_TO_OBJ(hi_name));
          ADD(border, ARRAY_OBJ(tuple));
        } else {
          ADD(border, STRING_OBJ(s));
        }
      }
      PUT(rv, "border", ARRAY_OBJ(border));
      if (config->title) {
        Array titles = ARRAY_DICT_INIT;
        VirtText title_datas = config->title_chunks;
        for (size_t i = 0; i < title_datas.size; i++) {
          Array tuple = ARRAY_DICT_INIT;
          ADD(tuple, CSTR_TO_OBJ(title_datas.items[i].text));
          if (title_datas.items[i].hl_id > 0) {
            ADD(tuple, CSTR_TO_OBJ(syn_id2name(title_datas.items[i].hl_id)));
          }
          ADD(titles, ARRAY_OBJ(tuple));
        }
        PUT(rv, "title", ARRAY_OBJ(titles));
        char *title_pos;
        if (config->title_pos == kAlignLeft) {
          title_pos = "left";
        } else if (config->title_pos == kAlignCenter) {
          title_pos = "center";
        } else {
          title_pos = "right";
        }
        PUT(rv, "title_pos", CSTR_TO_OBJ(title_pos));
      }
    }
  }

  const char *rel = (wp->w_floating && !config->external
                     ? float_relative_str[config->relative] : "");
  PUT(rv, "relative", CSTR_TO_OBJ(rel));

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

static bool parse_float_bufpos(Array bufpos, lpos_T *out)
{
  if (bufpos.size != 2
      || bufpos.items[0].type != kObjectTypeInteger
      || bufpos.items[1].type != kObjectTypeInteger) {
    return false;
  }
  out->lnum = (linenr_T)bufpos.items[0].data.integer;
  out->col = (colnr_T)bufpos.items[1].data.integer;
  return true;
}

static void parse_border_title(Object title, Object title_pos, FloatConfig *fconfig, Error *err)
{
  if (!parse_title_pos(title_pos, fconfig, err)) {
    return;
  }

  if (title.type == kObjectTypeString) {
    if (title.data.string.size == 0) {
      fconfig->title = false;
      return;
    }
    int hl_id = syn_check_group(S_LEN("FloatTitle"));
    kv_push(fconfig->title_chunks, ((VirtTextChunk){ .text = xstrdup(title.data.string.data),
                                                     .hl_id = hl_id }));
    fconfig->title_width = (int)mb_string2cells(title.data.string.data);
    fconfig->title = true;
    return;
  }

  if (title.type != kObjectTypeArray) {
    api_set_error(err, kErrorTypeValidation, "title must be string or array");
    return;
  }

  if (title.data.array.size == 0) {
    api_set_error(err, kErrorTypeValidation, "title cannot be an empty array");
    return;
  }

  fconfig->title_width = 0;
  fconfig->title_chunks = parse_virt_text(title.data.array, err, &fconfig->title_width);

  fconfig->title = true;
}

static bool parse_title_pos(Object title_pos, FloatConfig *fconfig, Error *err)
{
  if (!HAS_KEY(title_pos)) {
    fconfig->title_pos = kAlignLeft;
    return true;
  }

  if (title_pos.type != kObjectTypeString) {
    api_set_error(err, kErrorTypeValidation, "title_pos must be string");
    return false;
  }

  if (title_pos.data.string.size == 0) {
    fconfig->title_pos = kAlignLeft;
    return true;
  }

  char *pos = title_pos.data.string.data;

  if (strequal(pos, "left")) {
    fconfig->title_pos = kAlignLeft;
  } else if (strequal(pos, "center")) {
    fconfig->title_pos = kAlignCenter;
  } else if (strequal(pos, "right")) {
    fconfig->title_pos = kAlignRight;
  } else {
    api_set_error(err, kErrorTypeValidation, "invalid title_pos value");
    return false;
  }
  return true;
}

static void parse_border_style(Object style,  FloatConfig *fconfig, Error *err)
{
  struct {
    const char *name;
    schar_T chars[8];
    bool shadow_color;
  } defaults[] = {
    { "double", { "╔", "═", "╗", "║", "╝", "═", "╚", "║" }, false },
    { "single", { "┌", "─", "┐", "│", "┘", "─", "└", "│" }, false },
    { "shadow", { "", "", " ", " ", " ", " ", " ", "" }, true },
    { "rounded", { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }, false },
    { "solid", { " ", " ", " ", " ", " ", " ", " ", " " }, false },
    { NULL, { { NUL } }, false },
  };

  schar_T *chars = fconfig->border_chars;
  int *hl_ids = fconfig->border_hl_ids;

  fconfig->border = true;

  if (style.type == kObjectTypeArray) {
    Array arr = style.data.array;
    size_t size = arr.size;
    if (!size || size > 8 || (size & (size - 1))) {
      api_set_error(err, kErrorTypeValidation,
                    "invalid number of border chars");
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
      if (string.size
          && mb_string2cells_len(string.data, string.size) > 1) {
        api_set_error(err, kErrorTypeValidation,
                      "border chars must be one cell");
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
      api_set_error(err, kErrorTypeValidation,
                    "corner between used edges must be specified");
    }
  } else if (style.type == kObjectTypeString) {
    String str = style.data.string;
    if (str.size == 0 || strequal(str.data, "none")) {
      fconfig->border = false;
      // title does not work with border equal none
      fconfig->title = false;
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
    api_set_error(err, kErrorTypeValidation,
                  "invalid border style \"%s\"", str.data);
  }
}

static bool parse_float_config(Dict(float_config) *config, FloatConfig *fconfig, bool reconf,
                               bool new_win, Error *err)
{
  bool has_relative = false, relative_is_win = false;
  if (config->relative.type == kObjectTypeString) {
    // ignore empty string, to match nvim_win_get_config
    if (config->relative.data.string.size > 0) {
      if (!parse_float_relative(config->relative.data.string, &fconfig->relative)) {
        api_set_error(err, kErrorTypeValidation, "Invalid value of 'relative' key");
        return false;
      }

      if (!(HAS_KEY(config->row) && HAS_KEY(config->col)) && !HAS_KEY(config->bufpos)) {
        api_set_error(err, kErrorTypeValidation,
                      "'relative' requires 'row'/'col' or 'bufpos'");
        return false;
      }

      has_relative = true;
      fconfig->external = false;
      if (fconfig->relative == kFloatRelativeWindow) {
        relative_is_win = true;
        fconfig->bufpos.lnum = -1;
      }
    }
  } else if (HAS_KEY(config->relative)) {
    api_set_error(err, kErrorTypeValidation, "'relative' key must be String");
    return false;
  }

  if (config->anchor.type == kObjectTypeString) {
    if (!parse_float_anchor(config->anchor.data.string, &fconfig->anchor)) {
      api_set_error(err, kErrorTypeValidation, "Invalid value of 'anchor' key");
      return false;
    }
  } else if (HAS_KEY(config->anchor)) {
    api_set_error(err, kErrorTypeValidation, "'anchor' key must be String");
    return false;
  }

  if (HAS_KEY(config->row)) {
    if (!has_relative) {
      api_set_error(err, kErrorTypeValidation, "non-float cannot have 'row'");
      return false;
    } else if (config->row.type == kObjectTypeInteger) {
      fconfig->row = (double)config->row.data.integer;
    } else if (config->row.type == kObjectTypeFloat) {
      fconfig->row = config->row.data.floating;
    } else {
      api_set_error(err, kErrorTypeValidation,
                    "'row' key must be Integer or Float");
      return false;
    }
  }

  if (HAS_KEY(config->col)) {
    if (!has_relative) {
      api_set_error(err, kErrorTypeValidation, "non-float cannot have 'col'");
      return false;
    } else if (config->col.type == kObjectTypeInteger) {
      fconfig->col = (double)config->col.data.integer;
    } else if (config->col.type == kObjectTypeFloat) {
      fconfig->col = config->col.data.floating;
    } else {
      api_set_error(err, kErrorTypeValidation,
                    "'col' key must be Integer or Float");
      return false;
    }
  }

  if (HAS_KEY(config->bufpos)) {
    if (!has_relative) {
      api_set_error(err, kErrorTypeValidation, "non-float cannot have 'bufpos'");
      return false;
    } else if (config->bufpos.type == kObjectTypeArray) {
      if (!parse_float_bufpos(config->bufpos.data.array, &fconfig->bufpos)) {
        api_set_error(err, kErrorTypeValidation, "Invalid value of 'bufpos' key");
        return false;
      }

      if (!HAS_KEY(config->row)) {
        fconfig->row = (fconfig->anchor & kFloatAnchorSouth) ? 0 : 1;
      }
      if (!HAS_KEY(config->col)) {
        fconfig->col = 0;
      }
    } else {
      api_set_error(err, kErrorTypeValidation, "'bufpos' key must be Array");
      return false;
    }
  }

  if (config->width.type == kObjectTypeInteger && config->width.data.integer > 0) {
    fconfig->width = (int)config->width.data.integer;
  } else if (HAS_KEY(config->width)) {
    api_set_error(err, kErrorTypeValidation, "'width' key must be a positive Integer");
    return false;
  } else if (!reconf) {
    api_set_error(err, kErrorTypeValidation, "Must specify 'width'");
    return false;
  }

  if (config->height.type == kObjectTypeInteger && config->height.data.integer > 0) {
    fconfig->height = (int)config->height.data.integer;
  } else if (HAS_KEY(config->height)) {
    api_set_error(err, kErrorTypeValidation, "'height' key must be a positive Integer");
    return false;
  } else if (!reconf) {
    api_set_error(err, kErrorTypeValidation, "Must specify 'height'");
    return false;
  }

  if (relative_is_win) {
    fconfig->window = curwin->handle;
    if (config->win.type == kObjectTypeInteger || config->win.type == kObjectTypeWindow) {
      if (config->win.data.integer > 0) {
        fconfig->window = (Window)config->win.data.integer;
      }
    } else if (HAS_KEY(config->win)) {
      api_set_error(err, kErrorTypeValidation, "'win' key must be Integer or Window");
      return false;
    }
  } else {
    if (HAS_KEY(config->win)) {
      api_set_error(err, kErrorTypeValidation, "'win' key is only valid with relative='win'");
      return false;
    }
  }

  if (HAS_KEY(config->external)) {
    fconfig->external = api_object_to_bool(config->external, "'external' key", false, err);
    if (ERROR_SET(err)) {
      return false;
    }
    if (has_relative && fconfig->external) {
      api_set_error(err, kErrorTypeValidation,
                    "Only one of 'relative' and 'external' must be used");
      return false;
    }
    if (fconfig->external && !ui_has(kUIMultigrid)) {
      api_set_error(err, kErrorTypeValidation,
                    "UI doesn't support external windows");
      return false;
    }
  }

  if (!reconf && (!has_relative && !fconfig->external)) {
    api_set_error(err, kErrorTypeValidation,
                  "One of 'relative' and 'external' must be used");
    return false;
  }

  if (HAS_KEY(config->focusable)) {
    fconfig->focusable = api_object_to_bool(config->focusable, "'focusable' key", false, err);
    if (ERROR_SET(err)) {
      return false;
    }
  }

  if (config->zindex.type == kObjectTypeInteger && config->zindex.data.integer > 0) {
    fconfig->zindex = (int)config->zindex.data.integer;
  } else if (HAS_KEY(config->zindex)) {
    api_set_error(err, kErrorTypeValidation, "'zindex' key must be a positive Integer");
    return false;
  }

  if (HAS_KEY(config->title_pos)) {
    if (!HAS_KEY(config->title)) {
      api_set_error(err, kErrorTypeException, "title_pos requires title to be set");
      return false;
    }
  }

  if (HAS_KEY(config->title)) {
    // title only work with border
    if (!HAS_KEY(config->border) && !fconfig->border) {
      api_set_error(err, kErrorTypeException, "title requires border to be set");
      return false;
    }

    if (fconfig->title) {
      clear_virttext(&fconfig->title_chunks);
    }
    parse_border_title(config->title, config->title_pos, fconfig, err);
    if (ERROR_SET(err)) {
      return false;
    }
  }

  if (HAS_KEY(config->border)) {
    parse_border_style(config->border, fconfig, err);
    if (ERROR_SET(err)) {
      return false;
    }
  }

  if (config->style.type == kObjectTypeString) {
    if (config->style.data.string.data[0] == NUL) {
      fconfig->style = kWinStyleUnused;
    } else if (striequal(config->style.data.string.data, "minimal")) {
      fconfig->style = kWinStyleMinimal;
    } else {
      api_set_error(err, kErrorTypeValidation, "Invalid value of 'style' key");
    }
  } else if (HAS_KEY(config->style)) {
    api_set_error(err, kErrorTypeValidation, "'style' key must be String");
    return false;
  }

  if (HAS_KEY(config->noautocmd)) {
    if (!new_win) {
      api_set_error(err, kErrorTypeValidation, "Invalid key: 'noautocmd'");
      return false;
    }
    fconfig->noautocmd = api_object_to_bool(config->noautocmd, "'noautocmd' key", false, err);
    if (ERROR_SET(err)) {
      return false;
    }
  }

  return true;
}
