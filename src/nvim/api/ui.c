#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/api/ui.h"
#include "nvim/assert_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/channel.h"
#include "nvim/channel_defs.h"
#include "nvim/eval.h"
#include "nvim/event/defs.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/event/wstream.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/macros_defs.h"
#include "nvim/main.h"
#include "nvim/map_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/msgpack_rpc/channel_defs.h"
#include "nvim/msgpack_rpc/packer.h"
#include "nvim/msgpack_rpc/packer_defs.h"
#include "nvim/option.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"

#define BUF_POS(ui) ((size_t)((ui)->packer.ptr - (ui)->packer.startptr))

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/ui.c.generated.h"
# include "ui_events_remote.generated.h"  // IWYU pragma: export
#endif

static PMap(uint64_t) connected_uis = MAP_INIT;

static char *mpack_array_dyn16(char **buf)
{
  mpack_w(buf, 0xdc);
  char *pos = *buf;
  mpack_w2(buf, 0xFFEF);
  return pos;
}

static void mpack_str_small(char **buf, const char *str, size_t len)
{
  assert(len < 0x20);
  mpack_w(buf, 0xa0 | len);
  memcpy(*buf, str, len);
  *buf += len;
}

static void remote_ui_destroy(RemoteUI *ui)
  FUNC_ATTR_NONNULL_ALL
{
  xfree(ui->packer.startptr);
  XFREE_CLEAR(ui->term_name);
  xfree(ui);
}

void remote_ui_disconnect(uint64_t channel_id)
{
  RemoteUI *ui = pmap_get(uint64_t)(&connected_uis, channel_id);
  if (!ui) {
    return;
  }
  pmap_del(uint64_t)(&connected_uis, channel_id, NULL);
  ui_detach_impl(ui, channel_id);
  remote_ui_destroy(ui);
}

#ifdef EXITFREE
void remote_ui_free_all_mem(void)
{
  RemoteUI *ui;
  map_foreach_value(&connected_uis, ui, {
    remote_ui_destroy(ui);
  });
  map_destroy(uint64_t, &connected_uis);
}
#endif

/// Wait until UI has connected.
///
/// @param only_stdio UI is expected to connect on stdio.
void remote_ui_wait_for_attach(bool only_stdio)
{
  if (only_stdio) {
    Channel *channel = find_channel(CHAN_STDIO);
    if (!channel) {
      // `only_stdio` implies --embed mode, thus stdio channel can be assumed.
      abort();
    }

    LOOP_PROCESS_EVENTS_UNTIL(&main_loop, channel->events, -1,
                              map_has(uint64_t, &connected_uis, CHAN_STDIO));
  } else {
    LOOP_PROCESS_EVENTS_UNTIL(&main_loop, main_loop.events, -1,
                              ui_active());
  }
}

/// Activates UI events on the channel.
///
/// Entry point of all UI clients.  Allows |--embed| to continue startup.
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
void nvim_ui_attach(uint64_t channel_id, Integer width, Integer height, Dict options, Error *err)
  FUNC_API_SINCE(1) FUNC_API_REMOTE_ONLY
{
  if (map_has(uint64_t, &connected_uis, channel_id)) {
    api_set_error(err, kErrorTypeException,
                  "UI already attached to channel: %" PRId64, channel_id);
    return;
  }

  if (width <= 0 || height <= 0) {
    api_set_error(err, kErrorTypeValidation,
                  "Expected width > 0 and height > 0");
    return;
  }
  RemoteUI *ui = xcalloc(1, sizeof(RemoteUI));
  ui->width = (int)width;
  ui->height = (int)height;
  ui->pum_row = -1.0;
  ui->pum_col = -1.0;
  ui->rgb = true;
  CLEAR_FIELD(ui->ui_ext);

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
    // This uses attribute indices, so ext_linegrid is needed.
    ui->ui_ext[kUILinegrid] = true;
    // Cmdline uses the messages area, so it should be externalized too.
    ui->ui_ext[kUICmdline] = true;
  }

  ui->channel_id = channel_id;
  ui->cur_event = NULL;
  ui->hl_id = 0;
  ui->client_col = -1;
  ui->nevents_pos = NULL;
  ui->nevents = 0;
  ui->flushed_events = false;
  ui->ncalls_pos = NULL;
  ui->ncalls = 0;
  ui->ncells_pending = 0;
  ui->packer = (PackerBuffer) {
    .startptr = NULL,
    .ptr = NULL,
    .endptr = NULL,
    .packer_flush = ui_flush_callback,
    .anydata = ui,
  };
  ui->wildmenu_active = false;

  pmap_put(uint64_t)(&connected_uis, channel_id, ui);
  ui_attach_impl(ui, channel_id);

  may_trigger_vim_suspend_resume(false);
}

/// @deprecated
void ui_attach(uint64_t channel_id, Integer width, Integer height, Boolean enable_rgb, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  MAXSIZE_TEMP_DICT(opts, 1);
  PUT_C(opts, "rgb", BOOLEAN_OBJ(enable_rgb));
  nvim_ui_attach(channel_id, width, height, opts, err);
}

/// Tells the nvim server if focus was gained or lost by the GUI
void nvim_ui_set_focus(uint64_t channel_id, Boolean gained, Error *error)
  FUNC_API_SINCE(11) FUNC_API_REMOTE_ONLY
{
  if (!map_has(uint64_t, &connected_uis, channel_id)) {
    api_set_error(error, kErrorTypeException,
                  "UI not attached to channel: %" PRId64, channel_id);
    return;
  }

  if (gained) {
    may_trigger_vim_suspend_resume(false);
  }

  do_autocmd_focusgained((bool)gained);
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
  if (!map_has(uint64_t, &connected_uis, channel_id)) {
    api_set_error(err, kErrorTypeException,
                  "UI not attached to channel: %" PRId64, channel_id);
    return;
  }
  remote_ui_disconnect(channel_id);
}

// TODO(bfredl): use me to detach a specific ui from the server
void remote_ui_stop(RemoteUI *ui)
{
}

void nvim_ui_try_resize(uint64_t channel_id, Integer width, Integer height, Error *err)
  FUNC_API_SINCE(1) FUNC_API_REMOTE_ONLY
{
  if (!map_has(uint64_t, &connected_uis, channel_id)) {
    api_set_error(err, kErrorTypeException,
                  "UI not attached to channel: %" PRId64, channel_id);
    return;
  }

  if (width <= 0 || height <= 0) {
    api_set_error(err, kErrorTypeValidation,
                  "Expected width > 0 and height > 0");
    return;
  }

  RemoteUI *ui = pmap_get(uint64_t)(&connected_uis, channel_id);
  ui->width = (int)width;
  ui->height = (int)height;
  ui_refresh();
}

void nvim_ui_set_option(uint64_t channel_id, String name, Object value, Error *error)
  FUNC_API_SINCE(1) FUNC_API_REMOTE_ONLY
{
  if (!map_has(uint64_t, &connected_uis, channel_id)) {
    api_set_error(error, kErrorTypeException,
                  "UI not attached to channel: %" PRId64, channel_id);
    return;
  }
  RemoteUI *ui = pmap_get(uint64_t)(&connected_uis, channel_id);

  ui_set_option(ui, false, name, value, error);
}

static void ui_set_option(RemoteUI *ui, bool init, String name, Object value, Error *err)
{
  if (strequal(name.data, "override")) {
    VALIDATE_T("override", kObjectTypeBoolean, value.type, {
      return;
    });
    ui->override = value.data.boolean;
    return;
  }

  if (strequal(name.data, "rgb")) {
    VALIDATE_T("rgb", kObjectTypeBoolean, value.type, {
      return;
    });
    ui->rgb = value.data.boolean;
    // A little drastic, but only takes effect for legacy uis. For linegrid UI
    // only changes metadata for nvim_list_uis(), no refresh needed.
    if (!init && !ui->ui_ext[kUILinegrid]) {
      ui_refresh();
    }
    return;
  }

  if (strequal(name.data, "term_name")) {
    VALIDATE_T("term_name", kObjectTypeString, value.type, {
      return;
    });
    set_tty_option("term", string_to_cstr(value.data.string));
    ui->term_name = string_to_cstr(value.data.string);
    return;
  }

  if (strequal(name.data, "term_colors")) {
    VALIDATE_T("term_colors", kObjectTypeInteger, value.type, {
      return;
    });
    t_colors = (int)value.data.integer;
    ui->term_colors = (int)value.data.integer;
    return;
  }

  if (strequal(name.data, "stdin_fd")) {
    VALIDATE_T("stdin_fd", kObjectTypeInteger, value.type, {
      return;
    });
    VALIDATE_INT((value.data.integer >= 0), "stdin_fd", value.data.integer, {
      return;
    });
    VALIDATE((starting == NO_SCREEN), "%s", "stdin_fd can only be used with first attached UI", {
      return;
    });

    stdin_fd = (int)value.data.integer;
    return;
  }

  if (strequal(name.data, "stdin_tty")) {
    VALIDATE_T("stdin_tty", kObjectTypeBoolean, value.type, {
      return;
    });
    stdin_isatty = value.data.boolean;
    ui->stdin_tty = value.data.boolean;
    return;
  }

  if (strequal(name.data, "stdout_tty")) {
    VALIDATE_T("stdout_tty", kObjectTypeBoolean, value.type, {
      return;
    });
    stdout_isatty = value.data.boolean;
    ui->stdout_tty = value.data.boolean;
    return;
  }

  // LEGACY: Deprecated option, use `ext_cmdline` instead.
  bool is_popupmenu = strequal(name.data, "popupmenu_external");

  for (UIExtension i = 0; i < kUIExtCount; i++) {
    if (strequal(name.data, ui_ext_names[i])
        || (i == kUIPopupmenu && is_popupmenu)) {
      VALIDATE_EXP((value.type == kObjectTypeBoolean), name.data, "Boolean",
                   api_typename(value.type), {
        return;
      });
      bool boolval = value.data.boolean;
      if (!init && i == kUILinegrid && boolval != ui->ui_ext[i]) {
        // There shouldn't be a reason for a UI to do this ever
        // so explicitly don't support this.
        api_set_error(err, kErrorTypeValidation, "ext_linegrid option cannot be changed");
      }
      ui->ui_ext[i] = boolval;
      if (!init) {
        ui_set_ext_option(ui, i, boolval);
      }
      return;
    }
  }

  api_set_error(err, kErrorTypeValidation, "No such UI option: %s", name.data);
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
void nvim_ui_try_resize_grid(uint64_t channel_id, Integer grid, Integer width, Integer height,
                             Error *err)
  FUNC_API_SINCE(6) FUNC_API_REMOTE_ONLY
{
  if (!map_has(uint64_t, &connected_uis, channel_id)) {
    api_set_error(err, kErrorTypeException,
                  "UI not attached to channel: %" PRId64, channel_id);
    return;
  }

  if (grid == DEFAULT_GRID_HANDLE) {
    nvim_ui_try_resize(channel_id, width, height, err);
  } else {
    ui_grid_resize((handle_T)grid, (int)width, (int)height, err);
  }
}

/// Tells Nvim the number of elements displaying in the popupmenu, to decide
/// [<PageUp>] and [<PageDown>] movement.
///
/// @param channel_id
/// @param height  Popupmenu height, must be greater than zero.
/// @param[out] err Error details, if any
void nvim_ui_pum_set_height(uint64_t channel_id, Integer height, Error *err)
  FUNC_API_SINCE(6) FUNC_API_REMOTE_ONLY
{
  if (!map_has(uint64_t, &connected_uis, channel_id)) {
    api_set_error(err, kErrorTypeException,
                  "UI not attached to channel: %" PRId64, channel_id);
    return;
  }

  if (height <= 0) {
    api_set_error(err, kErrorTypeValidation, "Expected pum height > 0");
    return;
  }

  RemoteUI *ui = pmap_get(uint64_t)(&connected_uis, channel_id);
  if (!ui->ui_ext[kUIPopupmenu]) {
    api_set_error(err, kErrorTypeValidation,
                  "It must support the ext_popupmenu option");
    return;
  }

  ui->pum_nlines = (int)height;
}

/// Tells Nvim the geometry of the popupmenu, to align floating windows with an
/// external popup menu.
///
/// Note that this method is not to be confused with |nvim_ui_pum_set_height()|,
/// which sets the number of visible items in the popup menu, while this
/// function sets the bounding box of the popup menu, including visual
/// elements such as borders and sliders. Floats need not use the same font
/// size, nor be anchored to exact grid corners, so one can set floating-point
/// numbers to the popup menu geometry.
///
/// @param channel_id
/// @param width   Popupmenu width.
/// @param height  Popupmenu height.
/// @param row     Popupmenu row.
/// @param col     Popupmenu height.
/// @param[out] err Error details, if any.
void nvim_ui_pum_set_bounds(uint64_t channel_id, Float width, Float height, Float row, Float col,
                            Error *err)
  FUNC_API_SINCE(7) FUNC_API_REMOTE_ONLY
{
  if (!map_has(uint64_t, &connected_uis, channel_id)) {
    api_set_error(err, kErrorTypeException,
                  "UI not attached to channel: %" PRId64, channel_id);
    return;
  }

  RemoteUI *ui = pmap_get(uint64_t)(&connected_uis, channel_id);
  if (!ui->ui_ext[kUIPopupmenu]) {
    api_set_error(err, kErrorTypeValidation,
                  "UI must support the ext_popupmenu option");
    return;
  }

  if (width <= 0) {
    api_set_error(err, kErrorTypeValidation, "Expected width > 0");
    return;
  } else if (height <= 0) {
    api_set_error(err, kErrorTypeValidation, "Expected height > 0");
    return;
  }

  ui->pum_row = (double)row;
  ui->pum_col = (double)col;
  ui->pum_width = (double)width;
  ui->pum_height = (double)height;
  ui->pum_pos = true;
}

/// Tells Nvim when a terminal event has occurred
///
/// The following terminal events are supported:
///
///   - "termresponse": The terminal sent an OSC or DCS response sequence to
///                     Nvim. The payload is the received response. Sets
///                     |v:termresponse| and fires |TermResponse|.
///
/// @param channel_id
/// @param event Event name
/// @param value Event payload
/// @param[out] err Error details, if any.
void nvim_ui_term_event(uint64_t channel_id, String event, Object value, Error *err)
  FUNC_API_SINCE(12) FUNC_API_REMOTE_ONLY
{
  if (strequal("termresponse", event.data)) {
    if (value.type != kObjectTypeString) {
      api_set_error(err, kErrorTypeValidation, "termresponse must be a string");
      return;
    }

    const String termresponse = value.data.string;
    set_vim_var_string(VV_TERMRESPONSE, termresponse.data, (ptrdiff_t)termresponse.size);
    apply_autocmds_group(EVENT_TERMRESPONSE, NULL, NULL, false, AUGROUP_ALL, NULL, NULL, &value);
  }
}

static void flush_event(RemoteUI *ui)
{
  if (ui->cur_event) {
    mpack_w2(&ui->ncalls_pos, 1 + ui->ncalls);
    ui->cur_event = NULL;
    ui->ncalls_pos = NULL;
    ui->ncalls = 0;
  }
}

static void ui_alloc_buf(RemoteUI *ui)
{
  ui->packer.startptr = alloc_block();
  ui->packer.ptr = ui->packer.startptr;
  ui->packer.endptr = ui->packer.startptr + UI_BUF_SIZE;
}

static void prepare_call(RemoteUI *ui, const char *name)
{
  if (ui->packer.startptr
      && (BUF_POS(ui) > UI_BUF_SIZE - EVENT_BUF_SIZE || ui->ncells_pending >= 500)) {
    ui_flush_buf(ui);
  }

  if (ui->packer.startptr == NULL) {
    ui_alloc_buf(ui);
  }

  // To optimize data transfer (especially for "grid_line"), we bundle adjacent
  // calls to same method together, so only add a new call entry if the last
  // method call is different from "name"

  if (!ui->cur_event || !strequal(ui->cur_event, name)) {
    char **buf = &ui->packer.ptr;
    if (!ui->nevents_pos) {
      // [2, "redraw", [...]]
      mpack_array(buf, 3);
      mpack_uint(buf, 2);
      mpack_str_small(buf, S_LEN("redraw"));
      ui->nevents_pos = mpack_array_dyn16(buf);
      assert(ui->cur_event == NULL);
    }
    flush_event(ui);
    ui->cur_event = name;
    ui->ncalls_pos = mpack_array_dyn16(buf);
    mpack_str_small(buf, name, strlen(name));
    ui->nevents++;
    ui->ncalls = 1;
  } else {
    ui->ncalls++;
  }
}

/// Pushes data into RemoteUI, to be consumed later by remote_ui_flush().
static void push_call(RemoteUI *ui, const char *name, Array args)
{
  prepare_call(ui, name);
  mpack_object_array(args, &ui->packer);
}

static void ui_flush_callback(PackerBuffer *packer)
{
  RemoteUI *ui = packer->anydata;
  ui_flush_buf(ui);
  ui_alloc_buf(ui);
}

void remote_ui_grid_clear(RemoteUI *ui, Integer grid)
{
  MAXSIZE_TEMP_ARRAY(args, 1);
  if (ui->ui_ext[kUILinegrid]) {
    ADD_C(args, INTEGER_OBJ(grid));
  }
  const char *name = ui->ui_ext[kUILinegrid] ? "grid_clear" : "clear";
  push_call(ui, name, args);
}

void remote_ui_grid_resize(RemoteUI *ui, Integer grid, Integer width, Integer height)
{
  MAXSIZE_TEMP_ARRAY(args, 3);
  if (ui->ui_ext[kUILinegrid]) {
    ADD_C(args, INTEGER_OBJ(grid));
  } else {
    ui->client_col = -1;  // force cursor update
  }
  ADD_C(args, INTEGER_OBJ(width));
  ADD_C(args, INTEGER_OBJ(height));
  const char *name = ui->ui_ext[kUILinegrid] ? "grid_resize" : "resize";
  push_call(ui, name, args);
}

void remote_ui_grid_scroll(RemoteUI *ui, Integer grid, Integer top, Integer bot, Integer left,
                           Integer right, Integer rows, Integer cols)
{
  if (ui->ui_ext[kUILinegrid]) {
    MAXSIZE_TEMP_ARRAY(args, 7);
    ADD_C(args, INTEGER_OBJ(grid));
    ADD_C(args, INTEGER_OBJ(top));
    ADD_C(args, INTEGER_OBJ(bot));
    ADD_C(args, INTEGER_OBJ(left));
    ADD_C(args, INTEGER_OBJ(right));
    ADD_C(args, INTEGER_OBJ(rows));
    ADD_C(args, INTEGER_OBJ(cols));
    push_call(ui, "grid_scroll", args);
  } else {
    MAXSIZE_TEMP_ARRAY(args, 4);
    ADD_C(args, INTEGER_OBJ(top));
    ADD_C(args, INTEGER_OBJ(bot - 1));
    ADD_C(args, INTEGER_OBJ(left));
    ADD_C(args, INTEGER_OBJ(right - 1));
    push_call(ui, "set_scroll_region", args);

    kv_size(args) = 0;
    ADD_C(args, INTEGER_OBJ(rows));
    push_call(ui, "scroll", args);

    // some clients have "clear" being affected by scroll region, so reset it.
    kv_size(args) = 0;
    ADD_C(args, INTEGER_OBJ(0));
    ADD_C(args, INTEGER_OBJ(ui->height - 1));
    ADD_C(args, INTEGER_OBJ(0));
    ADD_C(args, INTEGER_OBJ(ui->width - 1));
    push_call(ui, "set_scroll_region", args);
  }
}

void remote_ui_default_colors_set(RemoteUI *ui, Integer rgb_fg, Integer rgb_bg, Integer rgb_sp,
                                  Integer cterm_fg, Integer cterm_bg)
{
  if (!ui->ui_ext[kUITermColors]) {
    HL_SET_DEFAULT_COLORS(rgb_fg, rgb_bg, rgb_sp);
  }
  MAXSIZE_TEMP_ARRAY(args, 5);
  ADD_C(args, INTEGER_OBJ(rgb_fg));
  ADD_C(args, INTEGER_OBJ(rgb_bg));
  ADD_C(args, INTEGER_OBJ(rgb_sp));
  ADD_C(args, INTEGER_OBJ(cterm_fg));
  ADD_C(args, INTEGER_OBJ(cterm_bg));
  push_call(ui, "default_colors_set", args);

  // Deprecated
  if (!ui->ui_ext[kUILinegrid]) {
    kv_size(args) = 0;
    ADD_C(args, INTEGER_OBJ(ui->rgb ? rgb_fg : cterm_fg - 1));
    push_call(ui, "update_fg", args);

    kv_size(args) = 0;
    ADD_C(args, INTEGER_OBJ(ui->rgb ? rgb_bg : cterm_bg - 1));
    push_call(ui, "update_bg", args);

    kv_size(args) = 0;
    ADD_C(args, INTEGER_OBJ(ui->rgb ? rgb_sp : -1));
    push_call(ui, "update_sp", args);
  }
}

void remote_ui_hl_attr_define(RemoteUI *ui, Integer id, HlAttrs rgb_attrs, HlAttrs cterm_attrs,
                              Array info)
{
  if (!ui->ui_ext[kUILinegrid]) {
    return;
  }

  MAXSIZE_TEMP_ARRAY(args, 4);
  ADD_C(args, INTEGER_OBJ(id));
  MAXSIZE_TEMP_DICT(rgb, HLATTRS_DICT_SIZE);
  MAXSIZE_TEMP_DICT(cterm, HLATTRS_DICT_SIZE);
  hlattrs2dict(&rgb, NULL, rgb_attrs, true, false);
  hlattrs2dict(&cterm, NULL, rgb_attrs, false, false);

  // URLs are not added in hlattrs2dict since they are used only by UIs and not by the highlight
  // system. So we add them here.
  if (rgb_attrs.url >= 0) {
    const char *url = hl_get_url((uint32_t)rgb_attrs.url);
    PUT_C(rgb, "url", CSTR_AS_OBJ(url));
  }

  ADD_C(args, DICT_OBJ(rgb));
  ADD_C(args, DICT_OBJ(cterm));

  if (ui->ui_ext[kUIHlState]) {
    ADD_C(args, ARRAY_OBJ(info));
  } else {
    ADD_C(args, ARRAY_OBJ((Array)ARRAY_DICT_INIT));
  }

  push_call(ui, "hl_attr_define", args);
}

void remote_ui_highlight_set(RemoteUI *ui, int id)
{
  if (ui->hl_id == id) {
    return;
  }

  ui->hl_id = id;
  MAXSIZE_TEMP_DICT(dict, HLATTRS_DICT_SIZE);
  hlattrs2dict(&dict, NULL, syn_attr2entry(id), ui->rgb, false);
  MAXSIZE_TEMP_ARRAY(args, 1);
  ADD_C(args, DICT_OBJ(dict));
  push_call(ui, "highlight_set", args);
}

/// "true" cursor used only for input focus
void remote_ui_grid_cursor_goto(RemoteUI *ui, Integer grid, Integer row, Integer col)
{
  if (ui->ui_ext[kUILinegrid]) {
    MAXSIZE_TEMP_ARRAY(args, 3);
    ADD_C(args, INTEGER_OBJ(grid));
    ADD_C(args, INTEGER_OBJ(row));
    ADD_C(args, INTEGER_OBJ(col));
    push_call(ui, "grid_cursor_goto", args);
  } else {
    ui->cursor_row = row;
    ui->cursor_col = col;
    remote_ui_cursor_goto(ui, row, col);
  }
}

/// emulated cursor used both for drawing and for input focus
void remote_ui_cursor_goto(RemoteUI *ui, Integer row, Integer col)
{
  if (ui->client_row == row && ui->client_col == col) {
    return;
  }
  ui->client_row = row;
  ui->client_col = col;
  MAXSIZE_TEMP_ARRAY(args, 2);
  ADD_C(args, INTEGER_OBJ(row));
  ADD_C(args, INTEGER_OBJ(col));
  push_call(ui, "cursor_goto", args);
}

void remote_ui_put(RemoteUI *ui, const char *cell)
{
  ui->client_col++;
  MAXSIZE_TEMP_ARRAY(args, 1);
  ADD_C(args, CSTR_AS_OBJ(cell));
  push_call(ui, "put", args);
}

void remote_ui_raw_line(RemoteUI *ui, Integer grid, Integer row, Integer startcol, Integer endcol,
                        Integer clearcol, Integer clearattr, LineFlags flags, const schar_T *chunk,
                        const sattr_T *attrs)
{
  // If MAX_SCHAR_SIZE is made larger, we need to refactor implementation below
  // to not only use FIXSTR (only up to 0x20 bytes)
  STATIC_ASSERT(MAX_SCHAR_SIZE - 1 < 0x20, "SCHAR doesn't fit in fixstr");

  if (ui->ui_ext[kUILinegrid]) {
    prepare_call(ui, "grid_line");

    char **buf = &ui->packer.ptr;
    mpack_array(buf, 5);
    mpack_uint(buf, (uint32_t)grid);
    mpack_uint(buf, (uint32_t)row);
    mpack_uint(buf, (uint32_t)startcol);
    char *lenpos = mpack_array_dyn16(buf);

    uint32_t repeat = 0;
    size_t ncells = (size_t)(endcol - startcol);
    int last_hl = -1;
    uint32_t nelem = 0;
    bool was_space = false;
    for (size_t i = 0; i < ncells; i++) {
      repeat++;
      if (i == ncells - 1 || attrs[i] != attrs[i + 1] || chunk[i] != chunk[i + 1]) {
        if (
            // Close to overflowing the redraw buffer. Finish this event, flush,
            // and start a new "grid_line" event at the current position.
            // For simplicity leave place for the final "clear" element as well,
            // hence the factor of 2 in the check.
            UI_BUF_SIZE - BUF_POS(ui) < 2 * (1 + 2 + MAX_SCHAR_SIZE + 5 + 5) + 1
            // Also if there is a lot of packed cells, pass them off to the UI to
            // let it start processing them.
            || ui->ncells_pending >= 500) {
          // If the last chunk was all spaces, add an empty clearing chunk,
          // so it's clear that the last chunk wasn't a clearing chunk.
          if (was_space) {
            nelem++;
            ui->ncells_pending += 1;
            mpack_array(buf, 3);
            mpack_str_small(buf, S_LEN(" "));
            mpack_uint(buf, (uint32_t)clearattr);
            mpack_uint(buf, 0);
          }
          mpack_w2(&lenpos, nelem);
          // We only ever set the wrap field on the final "grid_line" event for the line.
          mpack_bool(buf, false);
          ui_flush_buf(ui);

          prepare_call(ui, "grid_line");
          mpack_array(buf, 5);
          mpack_uint(buf, (uint32_t)grid);
          mpack_uint(buf, (uint32_t)row);
          mpack_uint(buf, (uint32_t)startcol + (uint32_t)i - repeat + 1);
          lenpos = mpack_array_dyn16(buf);
          nelem = 0;
          last_hl = -1;
        }
        uint32_t csize = (repeat > 1) ? 3 : ((attrs[i] != last_hl) ? 2 : 1);
        nelem++;
        mpack_array(buf, csize);
        char *size_byte = (*buf)++;
        size_t len = schar_get_adv(buf, chunk[i]);
        *size_byte = (char)(0xa0 | len);
        if (csize >= 2) {
          mpack_uint(buf, (uint32_t)attrs[i]);
          if (csize >= 3) {
            mpack_uint(buf, repeat);
          }
        }
        ui->ncells_pending += MIN(repeat, 2);
        last_hl = attrs[i];
        repeat = 0;
        was_space = chunk[i] == schar_from_ascii(' ');
      }
    }
    // If the last chunk was all spaces, add a clearing chunk even if there are
    // no more cells to clear, so there is no ambiguity about what to clear.
    if (endcol < clearcol || was_space) {
      nelem++;
      ui->ncells_pending += 1;
      mpack_array(buf, 3);
      mpack_str_small(buf, S_LEN(" "));
      mpack_uint(buf, (uint32_t)clearattr);
      mpack_uint(buf, (uint32_t)(clearcol - endcol));
    }
    mpack_w2(&lenpos, nelem);
    mpack_bool(buf, flags & kLineFlagWrap);
  } else {
    for (int i = 0; i < endcol - startcol; i++) {
      remote_ui_cursor_goto(ui, row, startcol + i);
      remote_ui_highlight_set(ui, attrs[i]);
      char sc_buf[MAX_SCHAR_SIZE];
      schar_get(sc_buf, chunk[i]);
      remote_ui_put(ui, sc_buf);
      if (utf_ambiguous_width(sc_buf)) {
        ui->client_col = -1;  // force cursor update
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

/// Flush the internal packing buffer to the client.
///
/// This might happen multiple times before the actual ui_flush, if the
/// total redraw size is large!
static void ui_flush_buf(RemoteUI *ui)
{
  if (!ui->packer.startptr || !BUF_POS(ui)) {
    return;
  }

  flush_event(ui);
  if (ui->nevents_pos != NULL) {
    mpack_w2(&ui->nevents_pos, ui->nevents);
    ui->nevents = 0;
    ui->nevents_pos = NULL;
  }

  WBuffer *buf = wstream_new_buffer(ui->packer.startptr, BUF_POS(ui), 1, free_block);
  rpc_write_raw(ui->channel_id, buf);

  ui->packer.startptr = NULL;
  ui->packer.ptr = NULL;

  // we have sent events to the client, but possibly not yet the final "flush" event.
  ui->flushed_events = true;
  ui->ncells_pending = 0;
}

/// An intentional flush (vsync) when Nvim is finished redrawing the screen
///
/// Clients can know this happened by a final "flush" event at the end of the
/// "redraw" batch.
void remote_ui_flush(RemoteUI *ui)
{
  if (ui->nevents > 0 || ui->flushed_events) {
    if (!ui->ui_ext[kUILinegrid]) {
      remote_ui_cursor_goto(ui, ui->cursor_row, ui->cursor_col);
    }
    push_call(ui, "flush", (Array)ARRAY_DICT_INIT);
    ui_flush_buf(ui);
    ui->flushed_events = false;
  }
}

static Array translate_contents(RemoteUI *ui, Array contents, Arena *arena)
{
  Array new_contents = arena_array(arena, contents.size);
  for (size_t i = 0; i < contents.size; i++) {
    Array item = contents.items[i].data.array;
    Array new_item = arena_array(arena, 2);
    int attr = (int)item.items[0].data.integer;
    if (attr) {
      Dict rgb_attrs = arena_dict(arena, HLATTRS_DICT_SIZE);
      hlattrs2dict(&rgb_attrs, NULL, syn_attr2entry(attr), ui->rgb, false);
      ADD_C(new_item, DICT_OBJ(rgb_attrs));
    } else {
      ADD_C(new_item, DICT_OBJ((Dict)ARRAY_DICT_INIT));
    }
    ADD_C(new_item, item.items[1]);
    ADD_C(new_contents, ARRAY_OBJ(new_item));
  }
  return new_contents;
}

static Array translate_firstarg(RemoteUI *ui, Array args, Arena *arena)
{
  Array new_args = arena_array(arena, args.size);
  Array contents = args.items[0].data.array;

  ADD_C(new_args, ARRAY_OBJ(translate_contents(ui, contents, arena)));
  for (size_t i = 1; i < args.size; i++) {
    ADD_C(new_args, args.items[i]);
  }
  return new_args;
}

void remote_ui_event(RemoteUI *ui, char *name, Array args)
{
  Arena arena = ARENA_EMPTY;
  if (!ui->ui_ext[kUILinegrid]) {
    // the representation of highlights in cmdline changed, translate back
    // never consumes args
    if (strequal(name, "cmdline_show")) {
      Array new_args = translate_firstarg(ui, args, &arena);
      push_call(ui, name, new_args);
      goto free_ret;
    } else if (strequal(name, "cmdline_block_show")) {
      Array block = args.items[0].data.array;
      Array new_block = arena_array(&arena, block.size);
      for (size_t i = 0; i < block.size; i++) {
        ADD_C(new_block, ARRAY_OBJ(translate_contents(ui, block.items[i].data.array, &arena)));
      }
      MAXSIZE_TEMP_ARRAY(new_args, 1);
      ADD_C(new_args, ARRAY_OBJ(new_block));
      push_call(ui, name, new_args);
      goto free_ret;
    } else if (strequal(name, "cmdline_block_append")) {
      Array new_args = translate_firstarg(ui, args, &arena);
      push_call(ui, name, new_args);
      goto free_ret;
    }
  }

  // Back-compat: translate popupmenu_xx to legacy wildmenu_xx.
  if (ui->ui_ext[kUIWildmenu]) {
    if (strequal(name, "popupmenu_show")) {
      ui->wildmenu_active = (args.items[4].data.integer == -1)
                            || !ui->ui_ext[kUIPopupmenu];
      if (ui->wildmenu_active) {
        Array items = args.items[0].data.array;
        Array new_items = arena_array(&arena, items.size);
        for (size_t i = 0; i < items.size; i++) {
          ADD_C(new_items, items.items[i].data.array.items[0]);
        }
        MAXSIZE_TEMP_ARRAY(new_args, 1);
        ADD_C(new_args, ARRAY_OBJ(new_items));
        push_call(ui, "wildmenu_show", new_args);
        if (args.items[1].data.integer != -1) {
          kv_size(new_args) = 0;
          ADD_C(new_args, args.items[1]);
          push_call(ui, "wildmenu_select", new_args);
        }
        goto free_ret;
      }
    } else if (strequal(name, "popupmenu_select")) {
      if (ui->wildmenu_active) {
        name = "wildmenu_select";
      }
    } else if (strequal(name, "popupmenu_hide")) {
      if (ui->wildmenu_active) {
        name = "wildmenu_hide";
      }
    }
  }

  push_call(ui, name, args);
  return;

free_ret:
  arena_mem_free(arena_finish(&arena));
}
