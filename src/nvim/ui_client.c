// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdbool.h>
#include <stdint.h>
#include <assert.h>

#include "nvim/vim.h"
#include "nvim/log.h"
#include "nvim/map.h"
#include "nvim/ui_client.h"
#include "nvim/api/private/helpers.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/ui.h"
#include "nvim/highlight.h"
#include "nvim/screen.h"

static Map(String, UIClientHandler) ui_client_handlers = MAP_INIT;

// Temporary buffer for converting a single grid_line event
static size_t buf_size = 0;
static schar_T *buf_char = NULL;
static sattr_T *buf_attr = NULL;

static void add_ui_client_event_handler(String method, UIClientHandler handler)
{
  map_put(String, UIClientHandler)(&ui_client_handlers, method, handler);
}

void ui_client_init(uint64_t chan)
{
  Array args = ARRAY_DICT_INIT;
  int width = Columns;
  int height = Rows;
  Dictionary opts = ARRAY_DICT_INIT;

  PUT(opts, "rgb", BOOLEAN_OBJ(true));
  PUT(opts, "ext_linegrid", BOOLEAN_OBJ(true));
  PUT(opts, "ext_termcolors", BOOLEAN_OBJ(true));

  ADD(args, INTEGER_OBJ((int)width));
  ADD(args, INTEGER_OBJ((int)height));
  ADD(args, DICTIONARY_OBJ(opts));

  rpc_send_event(chan, "nvim_ui_attach", args);
  msgpack_rpc_add_redraw();  // GAME!
  // TODO(bfredl): use a keyset instead
  ui_client_methods_table_init();
  ui_client_channel_id = chan;
}

/// Handler for "redraw" events sent by the NVIM server
///
/// This function will be called by handle_request (in msgpack_rpc/channel.c)
/// The individual ui_events sent by the server are individually handled
/// by their respective handlers defined in ui_events_client.generated.h
///
/// @note The "flush" event is called only once and only after handling all
///       the other events
/// @param channel_id: The id of the rpc channel
/// @param uidata: The dense array containing the ui_events sent by the server
/// @param[out] err Error details, if any
Object ui_client_handle_redraw(uint64_t channel_id, Array args, Error *error)
{
  for (size_t i = 0; i < args.size; i++) {
    Array call = args.items[i].data.array;
    String name = call.items[0].data.string;

    UIClientHandler handler = map_get(String, UIClientHandler)(&ui_client_handlers, name);
    if (!handler) {
      ELOG("No ui client handler for %s", name.size ? name.data : "<empty>");
      continue;
    }

    // fprintf(stderr, "%s: %zu\n", name.data, call.size-1);
    DLOG("Invoke ui client handler for %s", name.data);
    for (size_t j = 1; j < call.size; j++) {
      handler(call.items[j].data.array);
    }
  }

  return NIL;
}

/// run the main thread in ui client mode
///
/// This is just a stub. the full version will handle input, resizing, etc
void ui_client_execute(uint64_t chan)
{
  while (true) {
    loop_poll_events(&main_loop, -1);
  }

  getout(0);
}

static HlAttrs ui_client_dict2hlattrs(Dictionary d, bool rgb)
{
  Error err = ERROR_INIT;
  Dict(highlight) dict = { 0 };
  if (!api_dict_to_keydict(&dict, KeyDict_highlight_get_field, d, &err)) {
    // TODO(bfredl): log "err"
    return HLATTRS_INIT;
  }
  return dict2hlattrs(&dict, true, NULL, &err);
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
#include "ui_events_client.generated.h"
#endif

void ui_client_event_grid_resize(Array args)
{
  // TODO: typesafe!
  Integer grid = args.items[0].data.integer;
  Integer width = args.items[1].data.integer;
  Integer height = args.items[2].data.integer;
  ui_call_grid_resize(grid, width, height);

  if (buf_size < (size_t)width) {
    xfree(buf_char);
    xfree(buf_attr);
    buf_size = (size_t)width;
    buf_char = xmalloc(buf_size * sizeof(schar_T));
    buf_attr = xmalloc(buf_size * sizeof(sattr_T));
  }
}

void ui_client_event_grid_line(Array args)
{
  if (args.size < 4
      || args.items[0].type != kObjectTypeInteger
      || args.items[1].type != kObjectTypeInteger
      || args.items[2].type != kObjectTypeInteger
      || args.items[3].type != kObjectTypeArray) {
    goto error;
  }

  Integer grid = args.items[0].data.integer;
  Integer row = args.items[1].data.integer;
  Integer startcol = args.items[2].data.integer;
  Array cells = args.items[3].data.array;

  Integer endcol, clearcol;
  // TODO(hlpr98): Accomodate other LineFlags when included in grid_line
  LineFlags lineflags = 0;
  endcol = startcol;

  size_t j = 0;
  int cur_attr = 0;
  int clear_attr = 0;
  int clear_width = 0;
  for (size_t i = 0; i < cells.size; i++) {
    if (cells.items[i].type != kObjectTypeArray) {
      goto error;
    }
    Array cell = cells.items[i].data.array;

    if (cell.size < 1 || cell.items[0].type != kObjectTypeString) {
      goto error;
    }
    String sstring = cell.items[0].data.string;

    char *schar = sstring.data;
    int repeat = 1;
    if (cell.size >= 2) {
      if (cell.items[1].type != kObjectTypeInteger
          || cell.items[1].data.integer < 0) {
        goto error;
      }
      cur_attr = (int)cell.items[1].data.integer;
    }

    if (cell.size >= 3) {
      if (cell.items[2].type != kObjectTypeInteger
          || cell.items[2].data.integer < 0) {
        goto error;
      }
      repeat = (int)cell.items[2].data.integer;
    }

    if (i == cells.size - 1 && sstring.size == 1 && sstring.data[0] == ' ' && repeat > 1) {
      clear_width = repeat;
      break;
    }

    for (int r = 0; r < repeat; r++) {
      if (j >= buf_size) {
        goto error;  // _YIKES_
      }
      STRCPY(buf_char[j], schar);
      buf_attr[j++] = cur_attr;
    }
  }

  endcol = startcol + (int)j;
  clearcol = endcol + clear_width;
  clear_attr = cur_attr;

  ui_call_raw_line(grid, row, startcol, endcol, clearcol, clear_attr, lineflags,
                   buf_char, buf_attr);
  return;

error:
    ELOG("malformatted 'grid_line' event");
}
