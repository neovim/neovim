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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/ui.c.generated.h"
#endif

typedef struct {
  uint64_t channel_id;
  Array buffer;
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
  // destroy pending screen updates
  api_free_array(data->buffer);
  pmap_del(uint64_t)(connected_uis, channel_id);
  xfree(ui->data);
  ui_detach_impl(ui);
  xfree(ui);
}

void nvim_ui_attach(uint64_t channel_id, Integer width, Integer height,
                    Dictionary options, Error *err)
    FUNC_API_NOEVAL
{
  if (pmap_has(uint64_t)(connected_uis, channel_id)) {
    api_set_error(err, Exception, _("UI already attached for channel"));
    return;
  }

  if (width <= 0 || height <= 0) {
    api_set_error(err, Validation,
                  _("Expected width > 0 and height > 0"));
    return;
  }
  UI *ui = xcalloc(1, sizeof(UI));
  ui->width = (int)width;
  ui->height = (int)height;
  ui->rgb = true;
  ui->pum_external = false;
  ui->resize = remote_ui_resize;
  ui->clear = remote_ui_clear;
  ui->eol_clear = remote_ui_eol_clear;
  ui->cursor_goto = remote_ui_cursor_goto;
  ui->update_menu = remote_ui_update_menu;
  ui->busy_start = remote_ui_busy_start;
  ui->busy_stop = remote_ui_busy_stop;
  ui->mouse_on = remote_ui_mouse_on;
  ui->mouse_off = remote_ui_mouse_off;
  ui->mode_change = remote_ui_mode_change;
  ui->set_scroll_region = remote_ui_set_scroll_region;
  ui->scroll = remote_ui_scroll;
  ui->highlight_set = remote_ui_highlight_set;
  ui->put = remote_ui_put;
  ui->bell = remote_ui_bell;
  ui->visual_bell = remote_ui_visual_bell;
  ui->update_fg = remote_ui_update_fg;
  ui->update_bg = remote_ui_update_bg;
  ui->update_sp = remote_ui_update_sp;
  ui->flush = remote_ui_flush;
  ui->suspend = remote_ui_suspend;
  ui->set_title = remote_ui_set_title;
  ui->set_icon = remote_ui_set_icon;
  ui->event = remote_ui_event;

  for (size_t i = 0; i < options.size; i++) {
    ui_set_option(ui, options.items[i].key, options.items[i].value, err);
    if (err->set) {
      xfree(ui);
      return;
    }
  }

  UIData *data = xmalloc(sizeof(UIData));
  data->channel_id = channel_id;
  data->buffer = (Array)ARRAY_DICT_INIT;
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

void nvim_ui_detach(uint64_t channel_id, Error *err)
    FUNC_API_NOEVAL
{
  if (!pmap_has(uint64_t)(connected_uis, channel_id)) {
    api_set_error(err, Exception, _("UI is not attached for channel"));
    return;
  }
  remote_ui_disconnect(channel_id);
}


void nvim_ui_try_resize(uint64_t channel_id, Integer width,
                        Integer height, Error *err)
    FUNC_API_NOEVAL
{
  if (!pmap_has(uint64_t)(connected_uis, channel_id)) {
    api_set_error(err, Exception, _("UI is not attached for channel"));
    return;
  }

  if (width <= 0 || height <= 0) {
    api_set_error(err, Validation,
                  _("Expected width > 0 and height > 0"));
    return;
  }

  UI *ui = pmap_get(uint64_t)(connected_uis, channel_id);
  ui->width = (int)width;
  ui->height = (int)height;
  ui_refresh();
}

void nvim_ui_set_option(uint64_t channel_id, String name,
                        Object value, Error *error)
    FUNC_API_NOEVAL
{
  if (!pmap_has(uint64_t)(connected_uis, channel_id)) {
    api_set_error(error, Exception, _("UI is not attached for channel"));
    return;
  }
  UI *ui = pmap_get(uint64_t)(connected_uis, channel_id);

  ui_set_option(ui, name, value, error);
  if (!error->set) {
    ui_refresh();
  }
}

static void ui_set_option(UI *ui, String name, Object value, Error *error) {
  if (strcmp(name.data, "rgb") == 0) {
    if (value.type != kObjectTypeBoolean) {
      api_set_error(error, Validation, _("rgb must be a Boolean"));
      return;
    }
    ui->rgb = value.data.boolean;
  } else if (strcmp(name.data, "popupmenu_external") == 0) {
    if (value.type != kObjectTypeBoolean) {
      api_set_error(error, Validation,
                    _("popupmenu_external must be a Boolean"));
      return;
    }
    ui->pum_external = value.data.boolean;
  } else {
    api_set_error(error, Validation, _("No such ui option"));
  }
}

static void push_call(UI *ui, char *name, Array args)
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

static void remote_ui_resize(UI *ui, int width, int height)
{
  Array args = ARRAY_DICT_INIT;
  ADD(args, INTEGER_OBJ(width));
  ADD(args, INTEGER_OBJ(height));
  push_call(ui, "resize", args);
}

static void remote_ui_clear(UI *ui)
{
  Array args = ARRAY_DICT_INIT;
  push_call(ui, "clear", args);
}

static void remote_ui_eol_clear(UI *ui)
{
  Array args = ARRAY_DICT_INIT;
  push_call(ui, "eol_clear", args);
}

static void remote_ui_cursor_goto(UI *ui, int row, int col)
{
  Array args = ARRAY_DICT_INIT;
  ADD(args, INTEGER_OBJ(row));
  ADD(args, INTEGER_OBJ(col));
  push_call(ui, "cursor_goto", args);
}

static void remote_ui_update_menu(UI *ui)
{
  Array args = ARRAY_DICT_INIT;
  push_call(ui, "update_menu", args);
}

static void remote_ui_busy_start(UI *ui)
{
  Array args = ARRAY_DICT_INIT;
  push_call(ui, "busy_start", args);
}

static void remote_ui_busy_stop(UI *ui)
{
  Array args = ARRAY_DICT_INIT;
  push_call(ui, "busy_stop", args);
}

static void remote_ui_mouse_on(UI *ui)
{
  Array args = ARRAY_DICT_INIT;
  push_call(ui, "mouse_on", args);
}

static void remote_ui_mouse_off(UI *ui)
{
  Array args = ARRAY_DICT_INIT;
  push_call(ui, "mouse_off", args);
}

static void remote_ui_mode_change(UI *ui, int mode)
{
  Array args = ARRAY_DICT_INIT;
  if (mode == INSERT) {
    ADD(args, STRING_OBJ(cstr_to_string("insert")));
  } else if (mode == REPLACE) {
    ADD(args, STRING_OBJ(cstr_to_string("replace")));
  } else if (mode == CMDLINE) {
    ADD(args, STRING_OBJ(cstr_to_string("cmdline")));
  } else {
    assert(mode == NORMAL);
    ADD(args, STRING_OBJ(cstr_to_string("normal")));
  }
  push_call(ui, "mode_change", args);
}

static void remote_ui_set_scroll_region(UI *ui, int top, int bot, int left,
                                        int right)
{
  Array args = ARRAY_DICT_INIT;
  ADD(args, INTEGER_OBJ(top));
  ADD(args, INTEGER_OBJ(bot));
  ADD(args, INTEGER_OBJ(left));
  ADD(args, INTEGER_OBJ(right));
  push_call(ui, "set_scroll_region", args);
}

static void remote_ui_scroll(UI *ui, int count)
{
  Array args = ARRAY_DICT_INIT;
  ADD(args, INTEGER_OBJ(count));
  push_call(ui, "scroll", args);
}

static void remote_ui_highlight_set(UI *ui, HlAttrs attrs)
{
  Array args = ARRAY_DICT_INIT;
  Dictionary hl = ARRAY_DICT_INIT;

  if (attrs.bold) {
    PUT(hl, "bold", BOOLEAN_OBJ(true));
  }

  if (attrs.underline) {
    PUT(hl, "underline", BOOLEAN_OBJ(true));
  }

  if (attrs.undercurl) {
    PUT(hl, "undercurl", BOOLEAN_OBJ(true));
  }

  if (attrs.italic) {
    PUT(hl, "italic", BOOLEAN_OBJ(true));
  }

  if (attrs.reverse) {
    PUT(hl, "reverse", BOOLEAN_OBJ(true));
  }

  if (attrs.foreground != -1) {
    PUT(hl, "foreground", INTEGER_OBJ(attrs.foreground));
  }

  if (attrs.background != -1) {
    PUT(hl, "background", INTEGER_OBJ(attrs.background));
  }

  if (attrs.special != -1) {
    PUT(hl, "special", INTEGER_OBJ(attrs.special));
  }

  ADD(args, DICTIONARY_OBJ(hl));
  push_call(ui, "highlight_set", args);
}

static void remote_ui_put(UI *ui, uint8_t *data, size_t size)
{
  Array args = ARRAY_DICT_INIT;
  String str = { .data = xmemdupz(data, size), .size = size };
  ADD(args, STRING_OBJ(str));
  push_call(ui, "put", args);
}

static void remote_ui_bell(UI *ui)
{
  Array args = ARRAY_DICT_INIT;
  push_call(ui, "bell", args);
}

static void remote_ui_visual_bell(UI *ui)
{
  Array args = ARRAY_DICT_INIT;
  push_call(ui, "visual_bell", args);
}

static void remote_ui_update_fg(UI *ui, int fg)
{
  Array args = ARRAY_DICT_INIT;
  ADD(args, INTEGER_OBJ(fg));
  push_call(ui, "update_fg", args);
}

static void remote_ui_update_bg(UI *ui, int bg)
{
  Array args = ARRAY_DICT_INIT;
  ADD(args, INTEGER_OBJ(bg));
  push_call(ui, "update_bg", args);
}

static void remote_ui_update_sp(UI *ui, int sp)
{
  Array args = ARRAY_DICT_INIT;
  ADD(args, INTEGER_OBJ(sp));
  push_call(ui, "update_sp", args);
}

static void remote_ui_flush(UI *ui)
{
  UIData *data = ui->data;
  channel_send_event(data->channel_id, "redraw", data->buffer);
  data->buffer = (Array)ARRAY_DICT_INIT;
}

static void remote_ui_suspend(UI *ui)
{
  Array args = ARRAY_DICT_INIT;
  push_call(ui, "suspend", args);
}

static void remote_ui_set_title(UI *ui, char *title)
{
  Array args = ARRAY_DICT_INIT;
  ADD(args, STRING_OBJ(cstr_to_string(title)));
  push_call(ui, "set_title", args);
}

static void remote_ui_set_icon(UI *ui, char *icon)
{
  Array args = ARRAY_DICT_INIT;
  ADD(args, STRING_OBJ(cstr_to_string(icon)));
  push_call(ui, "set_icon", args);
}

static void remote_ui_event(UI *ui, char *name, Array args, bool *args_consumed)
{
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
