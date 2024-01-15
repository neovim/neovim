#include <stdbool.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/extmark.h"
#include "nvim/api/keysets_defs.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/win_config.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/decoration.h"
#include "nvim/decoration_defs.h"
#include "nvim/drawscreen.h"
#include "nvim/globals.h"
#include "nvim/grid_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/option.h"
#include "nvim/pos_defs.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/window.h"
#include "nvim/winfloat.h"

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
///     eight. The array will specify the eight chars building up the border
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
///   - noautocmd: If true then no buffer-related autocommand events such as
///                  |BufEnter|, |BufLeave| or |BufWinEnter| may fire from
///                  calling this function.
///   - fixed: If true when anchor is NW or SW, the float window
///            would be kept fixed even if the window would be truncated.
///   - hide: If true the floating window will be hidden.
///
/// @param[out] err Error details, if any
///
/// @return Window handle, or 0 on error
Window nvim_open_win(Buffer buffer, Boolean enter, Dict(float_config) *config, Error *err)
  FUNC_API_SINCE(6)
  FUNC_API_TEXTLOCK_ALLOW_CMDWIN
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return 0;
  }
  if (cmdwin_type != 0 && (enter || buf == curbuf)) {
    api_set_error(err, kErrorTypeException, "%s", e_cmdwin);
    return 0;
  }

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
    Boolean noautocmd = !enter || fconfig.noautocmd;
    win_set_buf(wp, buf, noautocmd, err);
    if (!fconfig.noautocmd) {
      apply_autocmds(EVENT_WINNEW, NULL, NULL, false, buf);
    }
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
  if (HAS_KEY(config, float_config, style)) {
    if (fconfig.style == kWinStyleMinimal) {
      win_set_minimal_style(win);
      didset_window_options(win, true);
    }
  }
}

static Dictionary config_put_bordertext(Dictionary config, FloatConfig *fconfig,
                                        BorderTextType bordertext_type)
{
  VirtText vt;
  AlignTextPos align;
  char *field_name;
  char *field_pos_name;
  switch (bordertext_type) {
  case kBorderTextTitle:
    vt = fconfig->title_chunks;
    align = fconfig->title_pos;
    field_name = "title";
    field_pos_name = "title_pos";
    break;
  case kBorderTextFooter:
    vt = fconfig->footer_chunks;
    align = fconfig->footer_pos;
    field_name = "footer";
    field_pos_name = "footer_pos";
    break;
  }

  Array bordertext = virt_text_to_array(vt, true);
  PUT(config, field_name, ARRAY_OBJ(bordertext));

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
  PUT(config, field_pos_name, CSTR_TO_OBJ(pos));

  return config;
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
  /// Keep in sync with FloatRelative in buffer_defs.h
  static const char *const float_relative_str[] = { "editor", "win", "cursor", "mouse" };

  Dictionary rv = ARRAY_DICT_INIT;

  win_T *wp = find_window_by_handle(window, err);
  if (!wp) {
    return rv;
  }

  FloatConfig *config = &wp->w_float_config;

  PUT(rv, "focusable", BOOLEAN_OBJ(config->focusable));
  PUT(rv, "external", BOOLEAN_OBJ(config->external));
  PUT(rv, "hide", BOOLEAN_OBJ(config->hide));

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

        String s = cstrn_to_string(config->border_chars[i], MAX_SCHAR_SIZE);

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
        rv = config_put_bordertext(rv, config, kBorderTextTitle);
      }
      if (config->footer) {
        rv = config_put_bordertext(rv, config, kBorderTextFooter);
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

static void parse_bordertext(Object bordertext, BorderTextType bordertext_type,
                             FloatConfig *fconfig, Error *err)
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
                                 FloatConfig *fconfig, Error *err)
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

static void parse_border_style(Object style,  FloatConfig *fconfig, Error *err)
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

  char (*chars)[MAX_SCHAR_SIZE] = fconfig->border_chars;
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
    api_set_error(err, kErrorTypeValidation,
                  "invalid border style \"%s\"", str.data);
  }
}

static bool parse_float_config(Dict(float_config) *config, FloatConfig *fconfig, bool reconf,
                               bool new_win, Error *err)
{
#define HAS_KEY_X(d, key) HAS_KEY(d, float_config, key)
  bool has_relative = false, relative_is_win = false;
  // ignore empty string, to match nvim_win_get_config
  if (HAS_KEY_X(config, relative) && config->relative.size > 0) {
    if (!parse_float_relative(config->relative, &fconfig->relative)) {
      api_set_error(err, kErrorTypeValidation, "Invalid value of 'relative' key");
      return false;
    }

    if (!(HAS_KEY_X(config, row) && HAS_KEY_X(config, col)) && !HAS_KEY_X(config, bufpos)) {
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

  if (HAS_KEY_X(config, anchor)) {
    if (!parse_float_anchor(config->anchor, &fconfig->anchor)) {
      api_set_error(err, kErrorTypeValidation, "Invalid value of 'anchor' key");
      return false;
    }
  }

  if (HAS_KEY_X(config, row)) {
    if (!has_relative) {
      api_set_error(err, kErrorTypeValidation, "non-float cannot have 'row'");
      return false;
    }
    fconfig->row = config->row;
  }

  if (HAS_KEY_X(config, col)) {
    if (!has_relative) {
      api_set_error(err, kErrorTypeValidation, "non-float cannot have 'col'");
      return false;
    }
    fconfig->col = config->col;
  }

  if (HAS_KEY_X(config, bufpos)) {
    if (!has_relative) {
      api_set_error(err, kErrorTypeValidation, "non-float cannot have 'bufpos'");
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
  } else if (!reconf) {
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
  } else if (!reconf) {
    api_set_error(err, kErrorTypeValidation, "Must specify 'height'");
    return false;
  }

  if (relative_is_win) {
    fconfig->window = curwin->handle;
    if (HAS_KEY_X(config, win)) {
      if (config->win > 0) {
        fconfig->window = config->win;
      }
    }
  } else {
    if (HAS_KEY_X(config, win)) {
      api_set_error(err, kErrorTypeValidation, "'win' key is only valid with relative='win'");
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

  if (HAS_KEY_X(config, focusable)) {
    fconfig->focusable = config->focusable;
  }

  if (HAS_KEY_X(config, zindex)) {
    if (config->zindex > 0) {
      fconfig->zindex = (int)config->zindex;
    } else {
      api_set_error(err, kErrorTypeValidation, "'zindex' key must be a positive Integer");
      return false;
    }
  }

  if (HAS_KEY_X(config, title)) {
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
    if (!new_win) {
      api_set_error(err, kErrorTypeValidation, "Invalid key: 'noautocmd'");
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
