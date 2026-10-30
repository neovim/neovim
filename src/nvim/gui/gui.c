// Nvim's built-in GUI (`nvim --gui`): a UI in the same process as the
// editor. It is attached like a remote UI (a RemoteUI with `gui` set, with
// `ext_linegrid`, `ext_multigrid`, and `ext_messages`, `ext_cmdline`,
// `ext_popupmenu`: the GUI shows those itself), but its events are not packed for a channel:
// api/ui.c hands them here as Nvim's own values (push_call), the lines as
// Nvim's cells (raw_line), and they go straight to the GUI's thread
// (gui/qt, through gui/bridge.h). The GUI calls back with keys, the mouse,
// Lua and Ex commands, queued to the editor thread on the main loop.
//
// biscide's runtime (runtime/lua/biscide) talks to the GUI through
// `vim._gui_send(kind, payload)`, a function this file gives Lua.

#include <assert.h>
#include <lauxlib.h>
#include <lua.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/ascii_defs.h"
#include "nvim/event/defs.h"
#include "nvim/eval/vars.h"
#include "nvim/event/loop.h"
#include "nvim/ex_docmd.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/gui/bridge.h"
#include "nvim/gui/gui.h"
#include "nvim/lua/converter.h"
#include "nvim/lua/executor.h"
#include "nvim/main.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"

#include "gui/gui.c.generated.h"

/// The size of the editor's own screen: room for any window a GUI floats
/// (the GUI places the windows itself).
enum {
  GUI_COLUMNS = 400,
  GUI_ROWS = 600,  ///< a card's window is as tall as its part
};

static RemoteUI *gui_ui = NULL;

/// Whether the GUI is attached.
bool gui_active(void)
{
  return gui_ui != NULL;
}

// ---- Nvim's values as the GUI's ----

static void to_gui(Object o, GuiValue *out);

static void to_gui_array(Array a, GuiValue *out)
{
  out->type = kGuiArray;
  out->data.array.size = a.size;
  out->data.array.items = a.size ? xcalloc(a.size, sizeof(GuiValue)) : NULL;
  for (size_t i = 0; i < a.size; i++) {
    to_gui(a.items[i], &out->data.array.items[i]);
  }
}

static void to_gui(Object o, GuiValue *out)
{
  switch (o.type) {
  case kObjectTypeNil:
    out->type = kGuiNil;
    break;
  case kObjectTypeBoolean:
    out->type = kGuiBool;
    out->data.boolean = o.data.boolean;
    break;
  case kObjectTypeInteger:
  case kObjectTypeBuffer:
  case kObjectTypeWindow:
  case kObjectTypeTabpage:
    out->type = kGuiInt;
    out->data.integer = o.data.integer;
    break;
  case kObjectTypeFloat:
    out->type = kGuiFloat;
    out->data.floating = o.data.floating;
    break;
  case kObjectTypeString:
    out->type = kGuiString;
    out->data.string.data = o.data.string.data ? o.data.string.data : "";
    out->data.string.size = o.data.string.size;
    break;
  case kObjectTypeArray:
    to_gui_array(o.data.array, out);
    break;
  case kObjectTypeDict: {
    Dict d = o.data.dict;
    out->type = kGuiMap;
    out->data.map.size = d.size;
    out->data.map.items = d.size ? xcalloc(d.size, sizeof(GuiPair)) : NULL;
    for (size_t i = 0; i < d.size; i++) {
      GuiPair *p = &out->data.map.items[i];
      p->key.type = kGuiString;
      p->key.data.string.data = d.items[i].key.data ? d.items[i].key.data : "";
      p->key.data.string.size = d.items[i].key.size;
      to_gui(d.items[i].value, &p->value);
    }
    break;
  }
  default:
    out->type = kGuiNil;
  }
}

/// Frees what to_gui allocated (the strings stay Nvim's).
static void free_gui(GuiValue *v)
{
  if (v->type == kGuiArray) {
    for (size_t i = 0; i < v->data.array.size; i++) {
      free_gui(&v->data.array.items[i]);
    }
    xfree(v->data.array.items);
  } else if (v->type == kGuiMap) {
    for (size_t i = 0; i < v->data.map.size; i++) {
      free_gui(&v->data.map.items[i].value);
    }
    xfree(v->data.map.items);
  }
}

/// The GUI's value as Nvim's (copied: it may be used on another thread).
static Object from_gui(const GuiValue *v)
{
  switch (v->type) {
  case kGuiBool:
    return BOOLEAN_OBJ(v->data.boolean);
  case kGuiInt:
    return INTEGER_OBJ(v->data.integer);
  case kGuiFloat:
    return FLOAT_OBJ(v->data.floating);
  case kGuiString:
    return STRING_OBJ(cbuf_to_string(v->data.string.data, v->data.string.size));
  case kGuiArray: {
    Array a = ARRAY_DICT_INIT;
    for (size_t i = 0; i < v->data.array.size; i++) {
      kv_push(a, from_gui(&v->data.array.items[i]));
    }
    return ARRAY_OBJ(a);
  }
  case kGuiMap: {
    Dict d = ARRAY_DICT_INIT;
    for (size_t i = 0; i < v->data.map.size; i++) {
      const GuiValue *k = &v->data.map.items[i].key;
      String key = k->type == kGuiString ? cbuf_to_string(k->data.string.data, k->data.string.size)
                                         : cstr_to_string("");
      kv_push(d, ((KeyValuePair){ .key = key, .value = from_gui(&v->data.map.items[i].value) }));
    }
    return DICT_OBJ(d);
  }
  default:
    return NIL;
  }
}

// ---- Nvim → the GUI: its UI events ----

/// An event of a GUI UI (api/ui.c's push_call), straight to the GUI.
void gui_ui_call(const char *name, Array args)
{
  GuiValue v;
  to_gui_array(args, &v);
  guiq_event(name, &v);
  free_gui(&v);
}

/// A line of a grid (api/ui.c's raw_line), as `grid_line` has it: runs of
/// cells of one character and highlight, the cleared rest last.
void gui_ui_raw_line(Integer grid, Integer row, Integer startcol, Integer endcol, Integer clearcol,
                     Integer clearattr, LineFlags flags, const schar_T *chunk, const sattr_T *attrs)
{
  size_t ncells = (size_t)(endcol - startcol);
  // Each run: [text, hl, repeat]; the texts live in `texts`.
  size_t cap = ncells + 1;
  GuiValue *cells = xcalloc(cap, sizeof(GuiValue));
  GuiValue *parts = xcalloc(cap * 3, sizeof(GuiValue));
  char *texts = xcalloc(cap, MAX_SCHAR_SIZE);
  size_t n = 0;
  size_t repeat = 0;
  for (size_t i = 0; i < ncells; i++) {
    repeat++;
    if (i == ncells - 1 || attrs[i] != attrs[i + 1] || chunk[i] != chunk[i + 1]) {
      char *t = texts + n * MAX_SCHAR_SIZE;
      size_t len = schar_get(t, chunk[i]);
      GuiValue *p = &parts[n * 3];
      p[0] = (GuiValue){ .type = kGuiString, .data.string = { t, len } };
      p[1] = (GuiValue){ .type = kGuiInt, .data.integer = attrs[i] };
      p[2] = (GuiValue){ .type = kGuiInt, .data.integer = (int64_t)repeat };
      cells[n] = (GuiValue){ .type = kGuiArray, .data.array = { p, 3 } };
      n++;
      repeat = 0;
    }
  }
  if (endcol < clearcol) {
    char *t = texts + n * MAX_SCHAR_SIZE;
    t[0] = ' ';
    GuiValue *p = &parts[n * 3];
    p[0] = (GuiValue){ .type = kGuiString, .data.string = { t, 1 } };
    p[1] = (GuiValue){ .type = kGuiInt, .data.integer = clearattr };
    p[2] = (GuiValue){ .type = kGuiInt, .data.integer = clearcol - endcol };
    cells[n] = (GuiValue){ .type = kGuiArray, .data.array = { p, 3 } };
    n++;
  }
  GuiValue args[5] = {
    { .type = kGuiInt, .data.integer = grid },
    { .type = kGuiInt, .data.integer = row },
    { .type = kGuiInt, .data.integer = startcol },
    { .type = kGuiArray, .data.array = { cells, n } },
    { .type = kGuiBool, .data.boolean = (flags & kLineFlagWrap) != 0 },
  };
  GuiValue line = { .type = kGuiArray, .data.array = { args, 5 } };
  guiq_event("grid_line", &line);
  xfree(texts);
  xfree(parts);
  xfree(cells);
}

/// The end of a batch: the GUI paints.
void gui_ui_flush(void)
{
  GuiValue none = { .type = kGuiArray, .data.array = { NULL, 0 } };
  guiq_event("flush", &none);
}

// ---- Lua → the GUI ----

/// `vim._gui_send(kind, payload)`: a payload for the GUI (biscide's lanes,
/// its tree, its pickers, the messages panel).
static int gui_lua_send(lua_State *L)
{
  const char *kind = luaL_checkstring(L, 1);
  lua_settop(L, 2);
  Arena arena = ARENA_EMPTY;
  Error err = ERROR_INIT;
  Object payload = nlua_pop_Object(L, false, &arena, &err);
  if (ERROR_SET(&err)) {
    arena_mem_free(arena_finish(&arena));
    lua_pushstring(L, err.msg);
    api_clear_error(&err);
    return lua_error(L);
  }
  GuiValue v;
  to_gui(payload, &v);
  guiq_send(kind, &v);
  free_gui(&v);
  arena_mem_free(arena_finish(&arena));
  return 0;
}

// ---- The GUI → Nvim (any thread; run on the editor's) ----

static void input_event(void **argv)
{
  String keys = { .data = argv[0], .size = (size_t)argv[1] };
  nvim_input(0, keys);
  xfree(argv[0]);
}

void gui_input(const char *keys, size_t len)
{
  char *copy = xmemdupz(keys, len);
  loop_schedule_fast(&main_loop, event_create(input_event, copy, (void *)len));
}

static void mouse_event(void **argv)
{
  Error err = ERROR_INIT;
  int64_t *pos = argv[3];
  nvim_input_mouse(cstr_as_string(argv[0]), cstr_as_string(argv[1]), cstr_as_string(argv[2]),
                   pos[0], pos[1], pos[2], &err);
  api_clear_error(&err);
  xfree(argv[0]);
  xfree(argv[1]);
  xfree(argv[2]);
  xfree(pos);
}

void gui_input_mouse(const char *button, const char *action, const char *modifier, int64_t grid,
                     int64_t row, int64_t col)
{
  int64_t *pos = xmalloc(3 * sizeof(int64_t));
  pos[0] = grid;
  pos[1] = row;
  pos[2] = col;
  loop_schedule_fast(&main_loop, event_create(mouse_event, xstrdup(button), xstrdup(action),
                                              xstrdup(modifier ? modifier : ""), pos));
}

static void lua_event(void **argv)
{
  String code = { .data = argv[0], .size = strlen(argv[0]) };
  Object *args = argv[1];
  Arena arena = ARENA_EMPTY;
  Error err = ERROR_INIT;
  nlua_exec(code, "@gui", args->type == kObjectTypeArray ? args->data.array : (Array)ARRAY_DICT_INIT,
            kRetNilBool, &arena, &err);
  if (ERROR_SET(&err)) {
    semsg("gui: %s", err.msg);
    api_clear_error(&err);
  }
  arena_mem_free(arena_finish(&arena));
  api_free_object(*args);
  xfree(args);
  xfree(argv[0]);
}

void gui_exec_lua(const char *code, const GuiValue *args)
{
  Object *copy = xmalloc(sizeof(Object));
  *copy = args ? from_gui(args) : ARRAY_OBJ((Array)ARRAY_DICT_INIT);
  // Not a fast event: Lua may open windows, change buffers (as an RPC
  // request does).
  loop_schedule_deferred(&main_loop, event_create(lua_event, xstrdup(code), copy));
}

static void command_event(void **argv)
{
  do_cmdline_cmd(argv[0]);
  xfree(argv[0]);
}

void gui_command(const char *cmd)
{
  loop_schedule_deferred(&main_loop, event_create(command_event, xstrdup(cmd)));
}

// ---- Starting and stopping ----

/// Starts the GUI and attaches it as a UI of the editor; false (with
/// `error`) when it cannot be.
bool gui_start(char *error, size_t errlen)
{
  GuiStartOptions opts = { .progpath = get_vim_var_str(VV_PROGPATH) };
  if (!guiq_start(&opts, error, errlen)) {
    return false;
  }

  // biscide's runtime knows it runs in the GUI, and how to reach it.
  lua_State *L = get_global_lstate();
  lua_getglobal(L, "vim");
  lua_pushcfunction(L, gui_lua_send);
  lua_setfield(L, -2, "_gui_send");
  lua_getfield(L, -1, "g");
  lua_pushboolean(L, true);
  lua_setfield(L, -2, "biscide");
  lua_pop(L, 2);
  // The files and folders given, as given: plugins may rename their buffers
  // (a folder's to a file explorer's URL) before biscide reads them.
  if (luaL_dostring(L, "vim.g.biscide_argv = vim.fn.argv()") != 0) {
    lua_pop(L, 1);
  }

  RemoteUI *ui = xcalloc(1, sizeof(RemoteUI));
  ui->gui = true;
  ui->rgb = true;
  ui->width = GUI_COLUMNS;
  ui->height = GUI_ROWS;
  ui->ui_ext[kUILinegrid] = true;
  ui->ui_ext[kUIMultigrid] = true;
  // Messages, the command line and the popup menu are the GUI's to show
  // (its status line, its messages panel), not rows of a grid.
  ui->ui_ext[kUIMessages] = true;
  ui->ui_ext[kUICmdline] = true;
  ui->ui_ext[kUIPopupmenu] = true;
  ui->channel_id = 0;
  ui->client_col = -1;
  ui->hl_id = -1;
  gui_ui = ui;
  ui_attach_impl(ui, 0);
  return true;
}

/// Nvim exits: the GUI's thread is let go.
void gui_stop(void)
{
  if (gui_ui) {
    guiq_stop();
  }
}

#ifndef NVIM_GUI
// Built without the GUI (ENABLE_GUI off): `--gui` says so.

bool guiq_start(const GuiStartOptions *opts, char *error, size_t errlen)
{
  snprintf(error, errlen, "this Nvim was built without its GUI (cmake -D ENABLE_GUI=ON)");
  return false;
}

void guiq_stop(void)
{
}

void guiq_event(const char *name, const GuiValue *args)
{
}

void guiq_send(const char *kind, const GuiValue *payload)
{
}
#endif
