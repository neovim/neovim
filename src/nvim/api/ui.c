// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/ui.h"
#include "nvim/channel.h"
#include "nvim/cursor_shape.h"
#include "nvim/highlight.h"
#include "nvim/map.h"
#include "nvim/memory.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/option.h"
#include "nvim/popupmnu.h"
#include "nvim/screen.h"
#include "nvim/ui.h"
#include "nvim/vim.h"
#include "nvim/window.h"

typedef struct {
  uint64_t channel_id;

#define UI_BUF_SIZE 4096  ///< total buffer size for pending msgpack data.
  /// guaranteed size available for each new event (so packing of simple events
  /// and the header of grid_line will never fail)
#define EVENT_BUF_SIZE 256
  char buf[UI_BUF_SIZE];  ///< buffer of packed but not yet sent msgpack data
  char *buf_wptr;  ///< write head of buffer
  const char *cur_event;  ///< name of current event (might get multiple arglists)
  Array call_buf;  ///< buffer for constructing a single arg list (max 16 elements!)

  // state for write_cb, while packing a single arglist to msgpack. This
  // might fail due to buffer overflow.
  size_t pack_totlen;
  bool buf_overflow;
  char *temp_buf;

  // We start packing the two outermost msgpack arrays before knowing the total
  // number of elements. Thus track the location where array size will need
  // to be written in the msgpack buffer, once the specific array is finished.
  char *nevents_pos;
  char *ncalls_pos;
  uint32_t nevents;  ///< number of distinct events (top-level args to "redraw"
  uint32_t ncalls;  ///< number of calls made to the current event (plus one for the name!)
  bool flushed_events;  ///< events where sent to client without "flush" event

  int hl_id;  // Current highlight for legacy put event.
  Integer cursor_row, cursor_col;  // Intended visible cursor position.

  // Position of legacy cursor, used both for drawing and visible user cursor.
  Integer client_row, client_col;
  bool wildmenu_active;
} UIData;

#define BUF_POS(data) ((size_t)((data)->buf_wptr - (data)->buf))

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/ui.c.generated.h"
# include "ui_events_remote.generated.h"
#endif

static PMap(uint64_t) connected_uis = MAP_INIT;

#define mpack_w(b, byte) *(*b)++ = (char)(byte);
static void mpack_w2(char **b, uint32_t v)
{
  *(*b)++ = (char)((v >> 8) & 0xff);
  *(*b)++ = (char)(v & 0xff);
}

static void mpack_w4(char **b, uint32_t v)
{
  *(*b)++ = (char)((v >> 24) & 0xff);
  *(*b)++ = (char)((v >> 16) & 0xff);
  *(*b)++ = (char)((v >> 8) & 0xff);
  *(*b)++ = (char)(v & 0xff);
}

static void mpack_uint(char **buf, uint32_t val)
{
  if (val > 0xffff) {
    mpack_w(buf, 0xce);
    mpack_w4(buf, val);
  } else if (val > 0xff) {
    mpack_w(buf, 0xcd);
    mpack_w2(buf, val);
  } else if (val > 0x7f) {
    mpack_w(buf, 0xcc);
    mpack_w(buf, val);
  } else {
    mpack_w(buf, val);
  }
}

static void mpack_array(char **buf, uint32_t len)
{
  if (len < 0x10) {
    mpack_w(buf, 0x90 | len);
  } else if (len < 0x10000) {
    mpack_w(buf, 0xdc);
    mpack_w2(buf, len);
  } else {
    mpack_w(buf, 0xdd);
    mpack_w4(buf, len);
  }
}

static char *mpack_array_dyn16(char **buf)
{
  mpack_w(buf, 0xdc);
  char *pos = *buf;
  mpack_w2(buf, 0xFFEF);
  return pos;
}

static void mpack_str(char **buf, const char *str)
{
  assert(sizeof(schar_T) - 1 < 0x20);
  size_t len = STRLEN(str);
  mpack_w(buf, 0xa0 | len);
  memcpy(*buf, str, len);
  *buf += len;
}

void remote_ui_disconnect(uint64_t channel_id)
{
  UI *ui = pmap_get(uint64_t)(&connected_uis, channel_id);
  if (!ui) {
    return;
  }
  UIData *data = ui->data;
  kv_destroy(data->call_buf);
  pmap_del(uint64_t)(&connected_uis, channel_id);
  xfree(data);
  ui->data = NULL;  // Flag UI as "stopped".
  ui_detach_impl(ui, channel_id);
  xfree(ui);
}

/// Wait until ui has connected on stdio channel.
void remote_ui_wait_for_attach(void)
{
  Channel *channel = find_channel(CHAN_STDIO);
  if (!channel) {
    // this function should only be called in --embed mode, stdio channel
    // can be assumed.
    abort();
  }

  LOOP_PROCESS_EVENTS_UNTIL(&main_loop, channel->events, -1,
                            pmap_has(uint64_t)(&connected_uis, CHAN_STDIO));
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
void nvim_ui_attach(uint64_t channel_id, Integer width, Integer height, Dictionary options,
                    Error *err)
  FUNC_API_SINCE(1) FUNC_API_REMOTE_ONLY
{
  if (pmap_has(uint64_t)(&connected_uis, channel_id)) {
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
  ui->pum_nlines = 0;
  ui->pum_pos = false;
  ui->pum_width = 0.0;
  ui->pum_height = 0.0;
  ui->pum_row = -1.0;
  ui->pum_col = -1.0;
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
  ui->msg_set_pos = remote_ui_msg_set_pos;
  ui->event = remote_ui_event;
  ui->inspect = remote_ui_inspect;

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

  UIData *data = xmalloc(sizeof(UIData));
  data->channel_id = channel_id;
  data->cur_event = NULL;
  data->hl_id = 0;
  data->client_col = -1;
  data->nevents_pos = NULL;
  data->nevents = 0;
  data->flushed_events = false;
  data->ncalls_pos = NULL;
  data->ncalls = 0;
  data->buf_wptr = data->buf;
  data->temp_buf = NULL;
  data->wildmenu_active = false;
  data->call_buf = (Array)ARRAY_DICT_INIT;
  kv_ensure_space(data->call_buf, 16);
  ui->data = data;

  pmap_put(uint64_t)(&connected_uis, channel_id, ui);
  ui_attach_impl(ui, channel_id);
}

/// @deprecated
void ui_attach(uint64_t channel_id, Integer width, Integer height, Boolean enable_rgb, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
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
  if (!pmap_has(uint64_t)(&connected_uis, channel_id)) {
    api_set_error(err, kErrorTypeException,
                  "UI not attached to channel: %" PRId64, channel_id);
    return;
  }
  remote_ui_disconnect(channel_id);
}

void nvim_ui_try_resize(uint64_t channel_id, Integer width, Integer height, Error *err)
  FUNC_API_SINCE(1) FUNC_API_REMOTE_ONLY
{
  if (!pmap_has(uint64_t)(&connected_uis, channel_id)) {
    api_set_error(err, kErrorTypeException,
                  "UI not attached to channel: %" PRId64, channel_id);
    return;
  }

  if (width <= 0 || height <= 0) {
    api_set_error(err, kErrorTypeValidation,
                  "Expected width > 0 and height > 0");
    return;
  }

  UI *ui = pmap_get(uint64_t)(&connected_uis, channel_id);
  ui->width = (int)width;
  ui->height = (int)height;
  ui_refresh();
}

void nvim_ui_set_option(uint64_t channel_id, String name, Object value, Error *error)
  FUNC_API_SINCE(1) FUNC_API_REMOTE_ONLY
{
  if (!pmap_has(uint64_t)(&connected_uis, channel_id)) {
    api_set_error(error, kErrorTypeException,
                  "UI not attached to channel: %" PRId64, channel_id);
    return;
  }
  UI *ui = pmap_get(uint64_t)(&connected_uis, channel_id);

  ui_set_option(ui, false, name, value, error);
}

static void ui_set_option(UI *ui, bool init, String name, Object value, Error *error)
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

  if (strequal(name.data, "term_name")) {
    if (value.type != kObjectTypeString) {
      api_set_error(error, kErrorTypeValidation, "term_name must be a String");
      return;
    }
    set_tty_option("term", string_to_cstr(value.data.string));
    return;
  }

  if (strequal(name.data, "term_colors")) {
    if (value.type != kObjectTypeInteger) {
      api_set_error(error, kErrorTypeValidation, "term_colors must be a Integer");
      return;
    }
    t_colors = (int)value.data.integer;
    return;
  }

  if (strequal(name.data, "term_background")) {
    if (value.type != kObjectTypeString) {
      api_set_error(error, kErrorTypeValidation, "term_background must be a String");
      return;
    }
    set_tty_background(value.data.string.data);
    return;
  }

  if (strequal(name.data, "stdin_fd")) {
    if (value.type != kObjectTypeInteger || value.data.integer < 0) {
      api_set_error(error, kErrorTypeValidation, "stdin_fd must be a non-negative Integer");
      return;
    }

    if (starting != NO_SCREEN) {
      api_set_error(error, kErrorTypeValidation,
                    "stdin_fd can only be used with first attached ui");
      return;
    }

    stdin_fd = (int)value.data.integer;
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
void nvim_ui_try_resize_grid(uint64_t channel_id, Integer grid, Integer width, Integer height,
                             Error *err)
  FUNC_API_SINCE(6) FUNC_API_REMOTE_ONLY
{
  if (!pmap_has(uint64_t)(&connected_uis, channel_id)) {
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

/// Tells Nvim the number of elements displaying in the popumenu, to decide
/// <PageUp> and <PageDown> movement.
///
/// @param channel_id
/// @param height  Popupmenu height, must be greater than zero.
/// @param[out] err Error details, if any
void nvim_ui_pum_set_height(uint64_t channel_id, Integer height, Error *err)
  FUNC_API_SINCE(6) FUNC_API_REMOTE_ONLY
{
  if (!pmap_has(uint64_t)(&connected_uis, channel_id)) {
    api_set_error(err, kErrorTypeException,
                  "UI not attached to channel: %" PRId64, channel_id);
    return;
  }

  if (height <= 0) {
    api_set_error(err, kErrorTypeValidation, "Expected pum height > 0");
    return;
  }

  UI *ui = pmap_get(uint64_t)(&connected_uis, channel_id);
  if (!ui->ui_ext[kUIPopupmenu]) {
    api_set_error(err, kErrorTypeValidation,
                  "It must support the ext_popupmenu option");
    return;
  }

  ui->pum_nlines = (int)height;
}

/// Tells Nvim the geometry of the popumenu, to align floating windows with an
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
  if (!pmap_has(uint64_t)(&connected_uis, channel_id)) {
    api_set_error(err, kErrorTypeException,
                  "UI not attached to channel: %" PRId64, channel_id);
    return;
  }

  UI *ui = pmap_get(uint64_t)(&connected_uis, channel_id);
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

static void flush_event(UIData *data)
{
  if (data->cur_event) {
    mpack_w2(&data->ncalls_pos, data->ncalls);
    data->cur_event = NULL;
  }
  if (!data->nevents_pos) {
    assert(BUF_POS(data) == 0);
    char **buf = &data->buf_wptr;
    // [2, "redraw", [...]]
    mpack_array(buf, 3);
    mpack_uint(buf, 2);
    mpack_str(buf, "redraw");
    data->nevents_pos = mpack_array_dyn16(buf);
  }
}

static inline int write_cb(void *vdata, const char *buf, size_t len)
{
  UIData *data = (UIData *)vdata;
  if (!buf) {
    return 0;
  }

  data->pack_totlen += len;
  if (!data->temp_buf && UI_BUF_SIZE - BUF_POS(data) < len) {
    data->buf_overflow = true;
    return 0;
  }

  memcpy(data->buf_wptr, buf, len);
  data->buf_wptr += len;

  return 0;
}

static bool prepare_call(UI *ui, const char *name)
{
  UIData *data = ui->data;

  if (BUF_POS(data) > UI_BUF_SIZE - EVENT_BUF_SIZE) {
    remote_ui_flush_buf(ui);
  }

  // To optimize data transfer(especially for "grid_line"), we bundle adjacent
  // calls to same method together, so only add a new call entry if the last
  // method call is different from "name"

  if (!data->cur_event || !strequal(data->cur_event, name)) {
    flush_event(data);
    data->cur_event = name;
    char **buf = &data->buf_wptr;
    data->ncalls_pos = mpack_array_dyn16(buf);
    mpack_str(buf, name);
    data->nevents++;
    data->ncalls = 1;
    return true;
  }

  return false;
}

/// Pushes data into UI.UIData, to be consumed later by remote_ui_flush().
static void push_call(UI *ui, const char *name, Array args)
{
  UIData *data = ui->data;
  bool pending = data->nevents_pos;
  char *buf_pos_save = data->buf_wptr;

  bool new_event = prepare_call(ui, name);

  msgpack_packer pac;
  data->pack_totlen = 0;
  data->buf_overflow = false;
  msgpack_packer_init(&pac, data, write_cb);
  msgpack_rpc_from_array(args, &pac);
  if (data->buf_overflow) {
    data->buf_wptr = buf_pos_save;
    if (new_event) {
      data->cur_event = NULL;
      data->nevents--;
    }
    if (pending) {
      remote_ui_flush_buf(ui);
    }

    if (data->pack_totlen > UI_BUF_SIZE - strlen(name) - 20) {
      // TODO(bfredl): manually testable by setting UI_BUF_SIZE to 1024 (mode_info_set)
      data->temp_buf = xmalloc(20 + strlen(name) + data->pack_totlen);
      data->buf_wptr = data->temp_buf;
      char **buf = &data->buf_wptr;
      mpack_array(buf, 3);
      mpack_uint(buf, 2);
      mpack_str(buf, "redraw");
      mpack_array(buf, 1);
      mpack_array(buf, 2);
      mpack_str(buf, name);
    } else {
      prepare_call(ui, name);
    }
    data->pack_totlen = 0;
    data->buf_overflow = false;
    msgpack_rpc_from_array(args, &pac);

    if (data->temp_buf) {
      size_t size = (size_t)(data->buf_wptr - data->temp_buf);
      WBuffer *buf = wstream_new_buffer(data->temp_buf, size, 1, xfree);
      rpc_write_raw(data->channel_id, buf);
      data->temp_buf = NULL;
      data->buf_wptr = data->buf;
      data->nevents_pos = NULL;
    }
  }
  data->ncalls++;
}

static void remote_ui_grid_clear(UI *ui, Integer grid)
{
  UIData *data = ui->data;
  Array args = data->call_buf;
  if (ui->ui_ext[kUILinegrid]) {
    ADD_C(args, INTEGER_OBJ(grid));
  }
  const char *name = ui->ui_ext[kUILinegrid] ? "grid_clear" : "clear";
  push_call(ui, name, args);
}

static void remote_ui_grid_resize(UI *ui, Integer grid, Integer width, Integer height)
{
  UIData *data = ui->data;
  Array args = data->call_buf;
  if (ui->ui_ext[kUILinegrid]) {
    ADD_C(args, INTEGER_OBJ(grid));
  }
  ADD_C(args, INTEGER_OBJ(width));
  ADD_C(args, INTEGER_OBJ(height));
  const char *name = ui->ui_ext[kUILinegrid] ? "grid_resize" : "resize";
  push_call(ui, name, args);
}

static void remote_ui_grid_scroll(UI *ui, Integer grid, Integer top, Integer bot, Integer left,
                                  Integer right, Integer rows, Integer cols)
{
  UIData *data = ui->data;
  if (ui->ui_ext[kUILinegrid]) {
    Array args = data->call_buf;
    ADD_C(args, INTEGER_OBJ(grid));
    ADD_C(args, INTEGER_OBJ(top));
    ADD_C(args, INTEGER_OBJ(bot));
    ADD_C(args, INTEGER_OBJ(left));
    ADD_C(args, INTEGER_OBJ(right));
    ADD_C(args, INTEGER_OBJ(rows));
    ADD_C(args, INTEGER_OBJ(cols));
    push_call(ui, "grid_scroll", args);
  } else {
    Array args = data->call_buf;
    ADD_C(args, INTEGER_OBJ(top));
    ADD_C(args, INTEGER_OBJ(bot - 1));
    ADD_C(args, INTEGER_OBJ(left));
    ADD_C(args, INTEGER_OBJ(right - 1));
    push_call(ui, "set_scroll_region", args);

    args = data->call_buf;
    ADD_C(args, INTEGER_OBJ(rows));
    push_call(ui, "scroll", args);

    // some clients have "clear" being affected by scroll region,
    // so reset it.
    args = data->call_buf;
    ADD_C(args, INTEGER_OBJ(0));
    ADD_C(args, INTEGER_OBJ(ui->height - 1));
    ADD_C(args, INTEGER_OBJ(0));
    ADD_C(args, INTEGER_OBJ(ui->width - 1));
    push_call(ui, "set_scroll_region", args);
  }
}

static void remote_ui_default_colors_set(UI *ui, Integer rgb_fg, Integer rgb_bg, Integer rgb_sp,
                                         Integer cterm_fg, Integer cterm_bg)
{
  if (!ui->ui_ext[kUITermColors]) {
    HL_SET_DEFAULT_COLORS(rgb_fg, rgb_bg, rgb_sp);
  }
  UIData *data = ui->data;
  Array args = data->call_buf;
  ADD_C(args, INTEGER_OBJ(rgb_fg));
  ADD_C(args, INTEGER_OBJ(rgb_bg));
  ADD_C(args, INTEGER_OBJ(rgb_sp));
  ADD_C(args, INTEGER_OBJ(cterm_fg));
  ADD_C(args, INTEGER_OBJ(cterm_bg));
  push_call(ui, "default_colors_set", args);

  // Deprecated
  if (!ui->ui_ext[kUILinegrid]) {
    args = data->call_buf;
    ADD_C(args, INTEGER_OBJ(ui->rgb ? rgb_fg : cterm_fg - 1));
    push_call(ui, "update_fg", args);

    args = data->call_buf;
    ADD_C(args, INTEGER_OBJ(ui->rgb ? rgb_bg : cterm_bg - 1));
    push_call(ui, "update_bg", args);

    args = data->call_buf;
    ADD_C(args, INTEGER_OBJ(ui->rgb ? rgb_sp : -1));
    push_call(ui, "update_sp", args);
  }
}

static void remote_ui_hl_attr_define(UI *ui, Integer id, HlAttrs rgb_attrs, HlAttrs cterm_attrs,
                                     Array info)
{
  if (!ui->ui_ext[kUILinegrid]) {
    return;
  }

  UIData *data = ui->data;
  Array args = data->call_buf;
  ADD_C(args, INTEGER_OBJ(id));
  MAXSIZE_TEMP_DICT(rgb, 16);
  MAXSIZE_TEMP_DICT(cterm, 16);
  ADD_C(args, DICTIONARY_OBJ(hlattrs2dict(&rgb, rgb_attrs, true)));
  ADD_C(args, DICTIONARY_OBJ(hlattrs2dict(&cterm, cterm_attrs, false)));

  if (ui->ui_ext[kUIHlState]) {
    ADD_C(args, ARRAY_OBJ(info));
  } else {
    ADD_C(args, ARRAY_OBJ((Array)ARRAY_DICT_INIT));
  }

  push_call(ui, "hl_attr_define", args);
}

static void remote_ui_highlight_set(UI *ui, int id)
{
  UIData *data = ui->data;
  Array args = data->call_buf;

  if (data->hl_id == id) {
    return;
  }
  data->hl_id = id;
  MAXSIZE_TEMP_DICT(dict, 16);
  ADD_C(args, DICTIONARY_OBJ(hlattrs2dict(&dict, syn_attr2entry(id), ui->rgb)));
  push_call(ui, "highlight_set", args);
}

/// "true" cursor used only for input focus
static void remote_ui_grid_cursor_goto(UI *ui, Integer grid, Integer row, Integer col)
{
  if (ui->ui_ext[kUILinegrid]) {
    UIData *data = ui->data;
    Array args = data->call_buf;
    ADD_C(args, INTEGER_OBJ(grid));
    ADD_C(args, INTEGER_OBJ(row));
    ADD_C(args, INTEGER_OBJ(col));
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
  Array args = data->call_buf;
  ADD_C(args, INTEGER_OBJ(row));
  ADD_C(args, INTEGER_OBJ(col));
  push_call(ui, "cursor_goto", args);
}

static void remote_ui_put(UI *ui, const char *cell)
{
  UIData *data = ui->data;
  data->client_col++;
  Array args = data->call_buf;
  ADD_C(args, STRING_OBJ(cstr_as_string((char *)cell)));
  push_call(ui, "put", args);
}

static void remote_ui_raw_line(UI *ui, Integer grid, Integer row, Integer startcol, Integer endcol,
                               Integer clearcol, Integer clearattr, LineFlags flags,
                               const schar_T *chunk, const sattr_T *attrs)
{
  UIData *data = ui->data;
  if (ui->ui_ext[kUILinegrid]) {
    prepare_call(ui, "grid_line");
    data->ncalls++;

    char **buf = &data->buf_wptr;
    mpack_array(buf, 4);
    mpack_uint(buf, (uint32_t)grid);
    mpack_uint(buf, (uint32_t)row);
    mpack_uint(buf, (uint32_t)startcol);
    char *lenpos = mpack_array_dyn16(buf);

    uint32_t repeat = 0;
    size_t ncells = (size_t)(endcol - startcol);
    int last_hl = -1;
    uint32_t nelem = 0;
    for (size_t i = 0; i < ncells; i++) {
      repeat++;
      if (i == ncells - 1 || attrs[i] != attrs[i + 1]
          || STRCMP(chunk[i], chunk[i + 1])) {
        if (UI_BUF_SIZE - BUF_POS(data) < 2 * (1 + 2 + sizeof(schar_T) + 5 + 5)) {
          // close to overflowing the redraw buffer. finish this event,
          // flush, and start a new "grid_line" event at the current position.
          // For simplicity leave place for the final "clear" element
          // as well, hence the factor of 2 in the check.
          mpack_w2(&lenpos, nelem);
          remote_ui_flush_buf(ui);

          prepare_call(ui, "grid_line");
          data->ncalls++;
          mpack_array(buf, 4);
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
        mpack_str(buf, (const char *)chunk[i]);
        if (csize >= 2) {
          mpack_uint(buf, (uint32_t)attrs[i]);
          if (csize >= 3) {
            mpack_uint(buf, repeat);
          }
        }
        last_hl = attrs[i];
        repeat = 0;
      }
    }
    if (endcol < clearcol) {
      nelem++;
      mpack_array(buf, 3);
      mpack_str(buf, " ");
      mpack_uint(buf, (uint32_t)clearattr);
      mpack_uint(buf, (uint32_t)(clearcol - endcol));
    }
    mpack_w2(&lenpos, nelem);
  } else {
    for (int i = 0; i < endcol - startcol; i++) {
      remote_ui_cursor_goto(ui, row, startcol + i);
      remote_ui_highlight_set(ui, attrs[i]);
      remote_ui_put(ui, (const char *)chunk[i]);
      if (utf_ambiguous_width(utf_ptr2char((char *)chunk[i]))) {
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

/// Flush the internal packing buffer to the client.
///
/// This might happen multiple times before the actual ui_flush, if the
/// total redraw size is large!
static void remote_ui_flush_buf(UI *ui)
{
  UIData *data = ui->data;
  if (!data->nevents_pos) {
    return;
  }
  if (data->cur_event) {
    flush_event(data);
  }
  mpack_w2(&data->nevents_pos, data->nevents);
  data->nevents = 0;
  data->nevents_pos = NULL;

  // TODO(bfredl): elide copy by a length one free-list like the arena
  size_t size = BUF_POS(data);
  WBuffer *buf = wstream_new_buffer(xmemdup(data->buf, size), size, 1, xfree);
  rpc_write_raw(data->channel_id, buf);
  data->buf_wptr = data->buf;
  // we have sent events to the client, but possibly not yet the final "flush"
  // event.
  data->flushed_events = true;
}

/// An intentional flush (vsync) when Nvim is finished redrawing the screen
///
/// Clients can know this happened by a final "flush" event at the end of the
/// "redraw" batch.
static void remote_ui_flush(UI *ui)
{
  UIData *data = ui->data;
  if (data->nevents > 0 || data->flushed_events) {
    if (!ui->ui_ext[kUILinegrid]) {
      remote_ui_cursor_goto(ui, data->cursor_row, data->cursor_col);
    }
    push_call(ui, "flush", (Array)ARRAY_DICT_INIT);
    remote_ui_flush_buf(ui);
    data->flushed_events = false;
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
      Dictionary rgb_attrs = hlattrs2dict(NULL, syn_attr2entry(attr), ui->rgb);
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

static void remote_ui_event(UI *ui, char *name, Array args)
{
  UIData *data = ui->data;
  if (!ui->ui_ext[kUILinegrid]) {
    // the representation of highlights in cmdline changed, translate back
    // never consumes args
    if (strequal(name, "cmdline_show")) {
      Array new_args = translate_firstarg(ui, args);
      push_call(ui, name, new_args);
      api_free_array(new_args);
      return;
    } else if (strequal(name, "cmdline_block_show")) {
      Array new_args = data->call_buf;
      Array block = args.items[0].data.array;
      Array new_block = ARRAY_DICT_INIT;
      for (size_t i = 0; i < block.size; i++) {
        ADD(new_block,
            ARRAY_OBJ(translate_contents(ui, block.items[i].data.array)));
      }
      ADD_C(new_args, ARRAY_OBJ(new_block));
      push_call(ui, name, new_args);
      api_free_array(new_block);
      return;
    } else if (strequal(name, "cmdline_block_append")) {
      Array new_args = translate_firstarg(ui, args);
      push_call(ui, name, new_args);
      api_free_array(new_args);
      return;
    }
  }

  // Back-compat: translate popupmenu_xx to legacy wildmenu_xx.
  if (ui->ui_ext[kUIWildmenu]) {
    if (strequal(name, "popupmenu_show")) {
      data->wildmenu_active = (args.items[4].data.integer == -1)
                              || !ui->ui_ext[kUIPopupmenu];
      if (data->wildmenu_active) {
        Array new_args = data->call_buf;
        Array items = args.items[0].data.array;
        Array new_items = ARRAY_DICT_INIT;
        for (size_t i = 0; i < items.size; i++) {
          ADD(new_items, copy_object(items.items[i].data.array.items[0]));
        }
        ADD_C(new_args, ARRAY_OBJ(new_items));
        push_call(ui, "wildmenu_show", new_args);
        api_free_array(new_items);
        if (args.items[1].data.integer != -1) {
          Array new_args2 = data->call_buf;
          ADD_C(new_args2, args.items[1]);
          push_call(ui, "wildmenu_select", new_args2);
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

  push_call(ui, name, args);
}

static void remote_ui_inspect(UI *ui, Dictionary *info)
{
  UIData *data = ui->data;
  PUT(*info, "chan", INTEGER_OBJ((Integer)data->channel_id));
}
