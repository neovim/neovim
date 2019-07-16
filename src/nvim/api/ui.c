// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include "nvim/vim.h"
#include "nvim/ui.h"
#include "nvim/memory.h"
#include "nvim/map.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/api/ui.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/popupmnu.h"
#include "nvim/cursor_shape.h"
#include "nvim/highlight.h"
#include "nvim/screen.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/ui.c.generated.h"
# include "ui_events_remote.generated.h"
#endif

typedef struct {
  uint64_t channel_id;
  Array buffer;

  int hl_id;  // Current highlight for legacy put event.
  Integer cursor_row, cursor_col;  // Intended visible cursor position.

  // Position of legacy cursor, used both for drawing and visible user cursor.
  Integer client_row, client_col;
  bool wildmenu_active;
} UIData;

static PMap(uint64_t) *connected_uis = NULL;

void remote_ui_init(void)
  FUNC_API_NOEXPORT
{
  connected_uis = pmap_new(uint64_t)();
}

void remote_ui_disconnect(uint64_t channel_id)
  FUNC_API_NOEXPORT
{
  UI *ui = pmap_get(uint64_t)(connected_uis, channel_id);
  if (!ui) {
    return;
  }
  UIData *data = ui->data;
  api_free_array(data->buffer);  // Destroy pending screen updates.
  pmap_del(uint64_t)(connected_uis, channel_id);
  xfree(ui->data);
  ui->data = NULL;  // Flag UI as "stopped".
  ui_detach_impl(ui);
  xfree(ui);
}

/// Wait until ui has connected on stdio channel.
void remote_ui_wait_for_attach(void)
  FUNC_API_NOEXPORT
{
  Channel *channel = find_channel(CHAN_STDIO);
  if (!channel) {
    // this function should only be called in --embed mode, stdio channel
    // can be assumed.
    abort();
  }

  LOOP_PROCESS_EVENTS_UNTIL(&main_loop, channel->events, -1,
                            pmap_has(uint64_t)(connected_uis, CHAN_STDIO));
}

/// Activates UI events on the channel.
///
/// Entry point of all UI clients.  Allows |\-\-embed| to continue startup.
/// Implies that the client is ready to show the UI.  Adds the client to the
/// list of UIs. |nvim_list_uis()|
///
/// @note If multiple UI clients are attached, the global screen dimensions
///       degrade to the smallest client. E.g. if client A requests 80x40 but
///       client B requests 200x100, the global screen has size 80x40.
///
/// @param channel_id
/// @param width  Requested screen columns
/// @param height  Requested screen rows
/// @param options  |ui-option| map
/// @param[out] err Error details, if any
void nvim_ui_attach(uint64_t channel_id, Integer width, Integer height,
                    Dictionary options, Error *err)
  FUNC_API_SINCE(1) FUNC_API_REMOTE_ONLY
{
  if (pmap_has(uint64_t)(connected_uis, channel_id)) {
    api_set_error(err, kErrorTypeException,
                  "UI already attached to channel: %" PRId64, channel_id);
    return;
  }

  if (width <= 0 || height <= 0) {
    api_set_error(err, kErrorTypeValidation,
                  "Expected width > 0 and height > 0");
    return;
  }
  UI *ui = xcalloc(1, sizeof(UI));
  ui->width = (int)width;
  ui->height = (int)height;
  ui->rgb = true;
  ui->override = false;
  ui->grid_resize = remote_ui_grid_resize;
  ui->grid_clear = remote_ui_grid_clear;
  ui->grid_cursor_goto = remote_ui_grid_cursor_goto;
  ui->mode_info_set = remote_ui_mode_info_set;
  ui->update_menu = remote_ui_update_menu;
  ui->busy_start = remote_ui_busy_start;
  ui->busy_stop = remote_ui_busy_stop;
  ui->mouse_on = remote_ui_mouse_on;
  ui->mouse_off = remote_ui_mouse_off;
  ui->mode_change = remote_ui_mode_change;
  ui->grid_scroll = remote_ui_grid_scroll;
  ui->hl_attr_define = remote_ui_hl_attr_define;
  ui->hl_group_set = remote_ui_hl_group_set;
  ui->raw_line = remote_ui_raw_line;
  ui->bell = remote_ui_bell;
  ui->visual_bell = remote_ui_visual_bell;
  ui->default_colors_set = remote_ui_default_colors_set;
  ui->flush = remote_ui_flush;
  ui->suspend = remote_ui_suspend;
  ui->set_title = remote_ui_set_title;
  ui->set_icon = remote_ui_set_icon;
  ui->option_set = remote_ui_option_set;
  ui->win_scroll_over_start = remote_ui_win_scroll_over_start;
  ui->win_scroll_over_reset = remote_ui_win_scroll_over_reset;
  ui->event = remote_ui_event;
  ui->inspect = remote_ui_inspect;

  memset(ui->ui_ext, 0, sizeof(ui->ui_ext));

  for (size_t i = 0; i < options.size; i++) {
    ui_set_option(ui, true, options.items[i].key, options.items[i].value, err);
    if (ERROR_SET(err)) {
      xfree(ui);
      return;
    }
  }

  if (ui->ui_ext[kUIHlState] || ui->ui_ext[kUIMultigrid]) {
    ui->ui_ext[kUILinegrid] = true;
  }

  if (ui->ui_ext[kUIMessages]) {
    // This uses attribute indicies, so ext_linegrid is needed.
    ui->ui_ext[kUILinegrid] = true;
    // Cmdline uses the messages area, so it should be externalized too.
    ui->ui_ext[kUICmdline] = true;
  }

  UIData *data = xmalloc(sizeof(UIData));
  data->channel_id = channel_id;
  data->buffer = (Array)ARRAY_DICT_INIT;
  data->hl_id = 0;
  data->client_col = -1;
  data->wildmenu_active = false;
  ui->data = data;

  pmap_put(uint64_t)(connected_uis, channel_id, ui);
  ui_attach_impl(ui);
}

/// @deprecated
void ui_attach(uint64_t channel_id, Integer width, Integer height,
               Boolean enable_rgb, Error *err)
{
  Dictionary opts = ARRAY_DICT_INIT;
  PUT(opts, "rgb", BOOLEAN_OBJ(enable_rgb));
  nvim_ui_attach(channel_id, width, height, opts, err);
  api_free_dictionary(opts);
}

/// Deactivates UI events on the channel.
///
/// Removes the client from the list of UIs. |nvim_list_uis()|
///
/// @param channel_id
/// @param[out] err Error details, if any
void nvim_ui_detach(uint64_t channel_id, Error *err)
  FUNC_API_SINCE(1) FUNC_API_REMOTE_ONLY
{
  if (!pmap_has(uint64_t)(connected_uis, channel_id)) {
    api_set_error(err, kErrorTypeException,
                  "UI not attached to channel: %" PRId64, channel_id);
    return;
  }
  remote_ui_disconnect(channel_id);
}


void nvim_ui_try_resize(uint64_t channel_id, Integer width,
                        Integer height, Error *err)
  FUNC_API_SINCE(1) FUNC_API_REMOTE_ONLY
{
  if (!pmap_has(uint64_t)(connected_uis, channel_id)) {
    api_set_error(err, kErrorTypeException,
                  "UI not attached to channel: %" PRId64, channel_id);
    return;
  }

  if (width <= 0 || height <= 0) {
    api_set_error(err, kErrorTypeValidation,
                  "Expected width > 0 and height > 0");
    return;
  }

  UI *ui = pmap_get(uint64_t)(connected_uis, channel_id);
  ui->width = (int)width;
  ui->height = (int)height;
  ui_refresh();
}

void nvim_ui_set_option(uint64_t channel_id, String name,
                        Object value, Error *error)
  FUNC_API_SINCE(1) FUNC_API_REMOTE_ONLY
{
  if (!pmap_has(uint64_t)(connected_uis, channel_id)) {
    api_set_error(error, kErrorTypeException,
                  "UI not attached to channel: %" PRId64, channel_id);
    return;
  }
  UI *ui = pmap_get(uint64_t)(connected_uis, channel_id);

  ui_set_option(ui, false, name, value, error);
}

static void ui_set_option(UI *ui, bool init, String name, Object value,
                          Error *error)
{
  if (strequal(name.data, "override")) {
    if (value.type != kObjectTypeBoolean) {
      api_set_error(error, kErrorTypeValidation, "override must be a Boolean");
      return;
    }
    ui->override = value.data.boolean;
    return;
  }

  if (strequal(name.data, "rgb")) {
    if (value.type != kObjectTypeBoolean) {
      api_set_error(error, kErrorTypeValidation, "rgb must be a Boolean");
      return;
    }
    ui->rgb = value.data.boolean;
    // A little drastic, but only takes effect for legacy uis. For linegrid UI
    // only changes metadata for nvim_list_uis(), no refresh needed.
    if (!init && !ui->ui_ext[kUILinegrid]) {
      ui_refresh();
    }
    return;
  }

  // LEGACY: Deprecated option, use `ext_cmdline` instead.
  bool is_popupmenu = strequal(name.data, "popupmenu_external");

  for (UIExtension i = 0; i < kUIExtCount; i++) {
    if (strequal(name.data, ui_ext_names[i])
        || (i == kUIPopupmenu && is_popupmenu)) {
      if (value.type != kObjectTypeBoolean) {
        api_set_error(error, kErrorTypeValidation, "%s must be a Boolean",
                      name.data);
        return;
      }
      bool boolval = value.data.boolean;
      if (!init && i == kUILinegrid && boolval != ui->ui_ext[i]) {
        // There shouldn't be a reason for an UI to do this ever
        // so explicitly don't support this.
        api_set_error(error, kErrorTypeValidation,
                      "ext_linegrid option cannot be changed");
      }
      ui->ui_ext[i] = boolval;
      if (!init) {
        ui_set_ext_option(ui, i, boolval);
      }
      return;
    }
  }

  api_set_error(error, kErrorTypeValidation, "No such UI option: %s",
                name.data);
}

/// Tell Nvim to resize a grid. Triggers a grid_resize event with the requested
/// grid size or the maximum size if it exceeds size limits.
///
/// On invalid grid handle, fails with error.
///
/// @param channel_id
/// @param grid    The handle of the grid to be changed.
/// @param width   The new requested width.
/// @param height  The new requested height.
/// @param[out] err Error details, if any
void nvim_ui_try_resize_grid(uint64_t channel_id, Integer grid, Integer width,
                             Integer height, Error *err)
  FUNC_API_SINCE(6) FUNC_API_REMOTE_ONLY
{
  if (!pmap_has(uint64_t)(connected_uis, channel_id)) {
    api_set_error(err, kErrorTypeException,
                  "UI not attached to channel: %" PRId64, channel_id);
    return;
  }

  ui_grid_resize((handle_T)grid, (int)width, (int)height, err);
}

/// Pushes data into UI.UIData, to be consumed later by remote_ui_flush().
static void push_call(UI *ui, const char *name, Array args)
{
  Array call = ARRAY_DICT_INIT;
  UIData *data = ui->data;

  // To optimize data transfer(especially for "put"), we bundle adjacent
  // calls to same method together, so only add a new call entry if the last
  // method call is different from "name"
  if (kv_size(data->buffer)) {
    call = kv_A(data->buffer, kv_size(data->buffer) - 1).data.array;
  }

  if (!kv_size(call) || strcmp(kv_A(call, 0).data.string.data, name)) {
    call = (Array)ARRAY_DICT_INIT;
    ADD(data->buffer, ARRAY_OBJ(call));
    ADD(call, STRING_OBJ(cstr_to_string(name)));
  }

  ADD(call, ARRAY_OBJ(args));
  kv_A(data->buffer, kv_size(data->buffer) - 1).data.array = call;
}

static void remote_ui_grid_clear(UI *ui, Integer grid)
{
  Array args = ARRAY_DICT_INIT;
  if (ui->ui_ext[kUILinegrid]) {
    ADD(args, INTEGER_OBJ(grid));
  }
  const char *name = ui->ui_ext[kUILinegrid] ? "grid_clear" : "clear";
  push_call(ui, name, args);
}

static void remote_ui_grid_resize(UI *ui, Integer grid,
                                  Integer width, Integer height)
{
  Array args = ARRAY_DICT_INIT;
  if (ui->ui_ext[kUILinegrid]) {
    ADD(args, INTEGER_OBJ(grid));
  }
  ADD(args, INTEGER_OBJ(width));
  ADD(args, INTEGER_OBJ(height));
  const char *name = ui->ui_ext[kUILinegrid] ? "grid_resize" : "resize";
  push_call(ui, name, args);
}

static void remote_ui_grid_scroll(UI *ui, Integer grid, Integer top,
                                  Integer bot, Integer left, Integer right,
                                  Integer rows, Integer cols)
{
  if (ui->ui_ext[kUILinegrid]) {
    Array args = ARRAY_DICT_INIT;
    ADD(args, INTEGER_OBJ(grid));
    ADD(args, INTEGER_OBJ(top));
    ADD(args, INTEGER_OBJ(bot));
    ADD(args, INTEGER_OBJ(left));
    ADD(args, INTEGER_OBJ(right));
    ADD(args, INTEGER_OBJ(rows));
    ADD(args, INTEGER_OBJ(cols));
    push_call(ui, "grid_scroll", args);
  } else {
    Array args = ARRAY_DICT_INIT;
    ADD(args, INTEGER_OBJ(top));
    ADD(args, INTEGER_OBJ(bot-1));
    ADD(args, INTEGER_OBJ(left));
    ADD(args, INTEGER_OBJ(right-1));
    push_call(ui, "set_scroll_region", args);

    args = (Array)ARRAY_DICT_INIT;
    ADD(args, INTEGER_OBJ(rows));
    push_call(ui, "scroll", args);

    // some clients have "clear" being affected by scroll region,
    // so reset it.
    args = (Array)ARRAY_DICT_INIT;
    ADD(args, INTEGER_OBJ(0));
    ADD(args, INTEGER_OBJ(ui->height-1));
    ADD(args, INTEGER_OBJ(0));
    ADD(args, INTEGER_OBJ(ui->width-1));
    push_call(ui, "set_scroll_region", args);
  }
}

static void remote_ui_default_colors_set(UI *ui, Integer rgb_fg,
                                         Integer rgb_bg, Integer rgb_sp,
                                         Integer cterm_fg, Integer cterm_bg)
{
  if (!ui->ui_ext[kUITermColors]) {
    HL_SET_DEFAULT_COLORS(rgb_fg, rgb_bg, rgb_sp);
  }
  Array args = ARRAY_DICT_INIT;
  ADD(args, INTEGER_OBJ(rgb_fg));
  ADD(args, INTEGER_OBJ(rgb_bg));
  ADD(args, INTEGER_OBJ(rgb_sp));
  ADD(args, INTEGER_OBJ(cterm_fg));
  ADD(args, INTEGER_OBJ(cterm_bg));
  push_call(ui, "default_colors_set", args);

  // Deprecated
  if (!ui->ui_ext[kUILinegrid]) {
    args = (Array)ARRAY_DICT_INIT;
    ADD(args, INTEGER_OBJ(ui->rgb ? rgb_fg : cterm_fg - 1));
    push_call(ui, "update_fg", args);

    args = (Array)ARRAY_DICT_INIT;
    ADD(args, INTEGER_OBJ(ui->rgb ? rgb_bg : cterm_bg - 1));
    push_call(ui, "update_bg", args);

    args = (Array)ARRAY_DICT_INIT;
    ADD(args, INTEGER_OBJ(ui->rgb ? rgb_sp : -1));
    push_call(ui, "update_sp", args);
  }
}

static void remote_ui_hl_attr_define(UI *ui, Integer id, HlAttrs rgb_attrs,
                                     HlAttrs cterm_attrs, Array info)
{
  if (!ui->ui_ext[kUILinegrid]) {
    return;
  }
  Array args = ARRAY_DICT_INIT;

  ADD(args, INTEGER_OBJ(id));
  ADD(args, DICTIONARY_OBJ(hlattrs2dict(rgb_attrs, true)));
  ADD(args, DICTIONARY_OBJ(hlattrs2dict(cterm_attrs, false)));

  if (ui->ui_ext[kUIHlState]) {
    ADD(args, ARRAY_OBJ(copy_array(info)));
  } else {
    ADD(args, ARRAY_OBJ((Array)ARRAY_DICT_INIT));
  }

  push_call(ui, "hl_attr_define", args);
}

static void remote_ui_highlight_set(UI *ui, int id)
{
  Array args = ARRAY_DICT_INIT;
  UIData *data = ui->data;


  if (data->hl_id == id) {
    return;
  }
  data->hl_id = id;
  Dictionary hl = hlattrs2dict(syn_attr2entry(id), ui->rgb);

  ADD(args, DICTIONARY_OBJ(hl));
  push_call(ui, "highlight_set", args);
}

/// "true" cursor used only for input focus
static void remote_ui_grid_cursor_goto(UI *ui, Integer grid, Integer row,
                                       Integer col)
{
  if (ui->ui_ext[kUILinegrid]) {
    Array args = ARRAY_DICT_INIT;
    ADD(args, INTEGER_OBJ(grid));
    ADD(args, INTEGER_OBJ(row));
    ADD(args, INTEGER_OBJ(col));
    push_call(ui, "grid_cursor_goto", args);
  } else {
    UIData *data = ui->data;
    data->cursor_row = row;
    data->cursor_col = col;
    remote_ui_cursor_goto(ui, row, col);
  }
}

/// emulated cursor used both for drawing and for input focus
static void remote_ui_cursor_goto(UI *ui, Integer row, Integer col)
{
  UIData *data = ui->data;
  if (data->client_row == row && data->client_col == col) {
    return;
  }
  data->client_row = row;
  data->client_col = col;
  Array args = ARRAY_DICT_INIT;
  ADD(args, INTEGER_OBJ(row));
  ADD(args, INTEGER_OBJ(col));
  push_call(ui, "cursor_goto", args);
}

static void remote_ui_put(UI *ui, const char *cell)
{
  UIData *data = ui->data;
  data->client_col++;
  Array args = ARRAY_DICT_INIT;
  ADD(args, STRING_OBJ(cstr_to_string(cell)));
  push_call(ui, "put", args);
}

static void remote_ui_raw_line(UI *ui, Integer grid, Integer row,
                               Integer startcol, Integer endcol,
                               Integer clearcol, Integer clearattr,
                               LineFlags flags, const schar_T *chunk,
                               const sattr_T *attrs)
{
  UIData *data = ui->data;
  if (ui->ui_ext[kUILinegrid]) {
    Array args = ARRAY_DICT_INIT;
    ADD(args, INTEGER_OBJ(grid));
    ADD(args, INTEGER_OBJ(row));
    ADD(args, INTEGER_OBJ(startcol));
    Array cells = ARRAY_DICT_INIT;
    int repeat = 0;
    size_t ncells = (size_t)(endcol-startcol);
    int last_hl = -1;
    for (size_t i = 0; i < ncells; i++) {
      repeat++;
      if (i == ncells-1 || attrs[i] != attrs[i+1]
          || STRCMP(chunk[i], chunk[i+1])) {
        Array cell = ARRAY_DICT_INIT;
        ADD(cell, STRING_OBJ(cstr_to_string((const char *)chunk[i])));
        if (attrs[i] != last_hl || repeat > 1) {
          ADD(cell, INTEGER_OBJ(attrs[i]));
          last_hl = attrs[i];
        }
        if (repeat > 1) {
          ADD(cell, INTEGER_OBJ(repeat));
        }
        ADD(cells, ARRAY_OBJ(cell));
        repeat = 0;
      }
    }
    if (endcol < clearcol) {
      Array cell = ARRAY_DICT_INIT;
      ADD(cell, STRING_OBJ(cstr_to_string(" ")));
      ADD(cell, INTEGER_OBJ(clearattr));
      ADD(cell, INTEGER_OBJ(clearcol-endcol));
      ADD(cells, ARRAY_OBJ(cell));
    }
    ADD(args, ARRAY_OBJ(cells));

    push_call(ui, "grid_line", args);
  } else {
    for (int i = 0; i < endcol-startcol; i++) {
      remote_ui_cursor_goto(ui, row, startcol+i);
      remote_ui_highlight_set(ui, attrs[i]);
      remote_ui_put(ui, (const char *)chunk[i]);
      if (utf_ambiguous_width(utf_ptr2char(chunk[i]))) {
        data->client_col = -1;  // force cursor update
      }
    }
    if (endcol < clearcol) {
      remote_ui_cursor_goto(ui, row, endcol);
      remote_ui_highlight_set(ui, (int)clearattr);
      // legacy eol_clear was only ever used with cleared attributes
      // so be on the safe side
      if (clearattr == 0 && clearcol == Columns) {
        Array args = ARRAY_DICT_INIT;
        push_call(ui, "eol_clear", args);
      } else {
        for (Integer c = endcol; c < clearcol; c++) {
          remote_ui_put(ui, " ");
        }
      }
    }
  }
}

static void remote_ui_flush(UI *ui)
{
  UIData *data = ui->data;
  if (data->buffer.size > 0) {
    if (!ui->ui_ext[kUILinegrid]) {
      remote_ui_cursor_goto(ui, data->cursor_row, data->cursor_col);
    }
    push_call(ui, "flush", (Array)ARRAY_DICT_INIT);
    rpc_send_event(data->channel_id, "redraw", data->buffer);
    data->buffer = (Array)ARRAY_DICT_INIT;
  }
}

static Array translate_contents(UI *ui, Array contents)
{
  Array new_contents = ARRAY_DICT_INIT;
  for (size_t i = 0; i < contents.size; i++) {
    Array item = contents.items[i].data.array;
    Array new_item = ARRAY_DICT_INIT;
    int attr = (int)item.items[0].data.integer;
    if (attr) {
      Dictionary rgb_attrs = hlattrs2dict(syn_attr2entry(attr), ui->rgb);
      ADD(new_item, DICTIONARY_OBJ(rgb_attrs));
    } else {
      ADD(new_item, DICTIONARY_OBJ((Dictionary)ARRAY_DICT_INIT));
    }
    ADD(new_item, copy_object(item.items[1]));
    ADD(new_contents, ARRAY_OBJ(new_item));
  }
  return new_contents;
}

static Array translate_firstarg(UI *ui, Array args)
{
  Array new_args = ARRAY_DICT_INIT;
  Array contents = args.items[0].data.array;

  ADD(new_args, ARRAY_OBJ(translate_contents(ui, contents)));
  for (size_t i = 1; i < args.size; i++) {
    ADD(new_args, copy_object(args.items[i]));
  }
  return new_args;
}

static void remote_ui_event(UI *ui, char *name, Array args, bool *args_consumed)
{
  UIData *data = ui->data;
  if (!ui->ui_ext[kUILinegrid]) {
    // the representation of highlights in cmdline changed, translate back
    // never consumes args
    if (strequal(name, "cmdline_show")) {
      Array new_args = translate_firstarg(ui, args);
      push_call(ui, name, new_args);
      return;
    } else if (strequal(name, "cmdline_block_show")) {
      Array new_args = ARRAY_DICT_INIT;
      Array block = args.items[0].data.array;
      Array new_block = ARRAY_DICT_INIT;
      for (size_t i = 0; i < block.size; i++) {
        ADD(new_block,
            ARRAY_OBJ(translate_contents(ui, block.items[i].data.array)));
      }
      ADD(new_args, ARRAY_OBJ(new_block));
      push_call(ui, name, new_args);
      return;
    } else if (strequal(name, "cmdline_block_append")) {
      Array new_args = translate_firstarg(ui, args);
      push_call(ui, name, new_args);
      return;
    }
  }

  // Back-compat: translate popupmenu_xx to legacy wildmenu_xx.
  if (ui->ui_ext[kUIWildmenu]) {
    if (strequal(name, "popupmenu_show")) {
      data->wildmenu_active = (args.items[4].data.integer == -1)
                            || !ui->ui_ext[kUIPopupmenu];
      if (data->wildmenu_active) {
        Array new_args = ARRAY_DICT_INIT;
        Array items = args.items[0].data.array;
        Array new_items = ARRAY_DICT_INIT;
        for (size_t i = 0; i < items.size; i++) {
          ADD(new_items, copy_object(items.items[i].data.array.items[0]));
        }
        ADD(new_args, ARRAY_OBJ(new_items));
        push_call(ui, "wildmenu_show", new_args);
        if (args.items[1].data.integer != -1) {
          Array new_args2 = ARRAY_DICT_INIT;
          ADD(new_args2, args.items[1]);
          push_call(ui, "wildmenu_select", new_args);
        }
        return;
      }
    } else if (strequal(name, "popupmenu_select")) {
      if (data->wildmenu_active) {
        name = "wildmenu_select";
      }
    } else if (strequal(name, "popupmenu_hide")) {
      if (data->wildmenu_active) {
        name = "wildmenu_hide";
      }
    }
  }


  Array my_args = ARRAY_DICT_INIT;
  // Objects are currently single-reference
  // make a copy, but only if necessary
  if (*args_consumed) {
    for (size_t i = 0; i < args.size; i++) {
      ADD(my_args, copy_object(args.items[i]));
    }
  } else {
    my_args = args;
    *args_consumed = true;
  }
  push_call(ui, name, my_args);
}

static void remote_ui_inspect(UI *ui, Dictionary *info)
{
  UIData *data = ui->data;
  PUT(*info, "chan", INTEGER_OBJ((Integer)data->channel_id));
}
