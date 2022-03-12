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

static Map(String, ApiRedrawWrapper) redraw_methods = MAP_INIT;

static void add_redraw_event_handler(String method, ApiRedrawWrapper handler)
{
  map_put(String, ApiRedrawWrapper)(&redraw_methods, method, handler);
}

void ui_client_init(uint64_t chan)
{
  Array args = ARRAY_DICT_INIT;
  int width = 80;
  int height = 25;
  Dictionary opts = ARRAY_DICT_INIT;

  PUT(opts, "rgb", BOOLEAN_OBJ(true));
  PUT(opts, "ext_linegrid", BOOLEAN_OBJ(true));
  PUT(opts, "ext_termcolors", BOOLEAN_OBJ(true));

  // TODO(bfredl): use the size of the client UI
  ADD(args, INTEGER_OBJ((int)width));
  ADD(args, INTEGER_OBJ((int)height));
  ADD(args, DICTIONARY_OBJ(opts));

  rpc_send_event(chan, "nvim_ui_attach", args);
  msgpack_rpc_add_redraw();  // GAME!
  ui_client_channel_id = chan;
}

/// Handler for "redraw" events sent by the NVIM server
///
/// This is just a stub. The mentioned functionality will be implemented.
///
/// This function will be called by handle_request (in msgpack_rpc/channle.c)
/// The individual ui_events sent by the server are individually handled
/// by their respective handlers defined in ui_events_redraw.generated.h
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
    char *method_name = call.items[0].data.string.data;

    fprintf(stderr, "%s: %zu\n", method_name, call.size-1);
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

/// @param name Redraw method name
/// @param name_len name size (includes terminating NUL)
ApiRedrawWrapper get_redraw_event_handler(const char *name, size_t name_len, Error *error)
{
  String m = { .data = (char *)name, .size = name_len };
  ApiRedrawWrapper rv =
    map_get(String, ApiRedrawWrapper)(&redraw_methods, m);

  if (!rv) {
    api_set_error(error, kErrorTypeException, "Invalid method: %.*s",
                  m.size > 0 ? (int)m.size : (int)sizeof("<empty>"),
                  m.size > 0 ? m.data : "<empty>");
  }
  return rv;
}

static HlAttrs redraw_dict2hlattrs(Dictionary redraw_dict, bool rgb)
{
  Error err = ERROR_INIT;
  Dict(highlight) dict = { 0 };
  if (!api_dict_to_keydict(&dict, KeyDict_highlight_get_field, redraw_dict, &err)) {
    // TODO(bfredl): log "err"
    return HLATTRS_INIT;
  }
  return dict2hlattrs(&dict, true, NULL, &err);
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
#include "ui_events_redraw.generated.h"
#endif

void ui_redraw_event_grid_line(Array args)
{
  Integer grid = args.items[0].data.integer;
  Integer row = args.items[1].data.integer;
  Integer startcol = args.items[2].data.integer;
  Array cells = args.items[3].data.array;
  Integer endcol, clearcol, clearattr;
  // TODO(hlpr98): Accomodate other LineFlags when included in grid_line
  LineFlags lineflags = 0;
  schar_T *chunk;
  sattr_T *attrs;
  size_t size_of_cells = cells.size;
  size_t no_of_cells = size_of_cells;
  endcol = startcol;

  // checking if clearcol > endcol
  if (!STRCMP(cells.items[size_of_cells-1].data.array
              .items[0].data.string.data, " ")
      && cells.items[size_of_cells-1].data.array.size == 3) {
    no_of_cells = size_of_cells - 1;
  }

  // getting endcol
  for (size_t i = 0; i < no_of_cells; i++) {
    endcol++;
    if (cells.items[i].data.array.size == 3) {
      endcol += cells.items[i].data.array.items[2].data.integer - 1;
    }
  }

  if (!STRCMP(cells.items[size_of_cells-1].data.array
              .items[0].data.string.data, " ")
      && cells.items[size_of_cells-1].data.array.size == 3) {
    clearattr = cells.items[size_of_cells-1].data.array.items[1].data.integer;
    clearcol = endcol + cells.items[size_of_cells-1].data.array
                                                      .items[2].data.integer;
  } else {
    clearattr = 0;
    clearcol = endcol;
  }

  size_t ncells = (size_t)(endcol - startcol);
  chunk = xmalloc(ncells * sizeof(schar_T) + 1);
  attrs = xmalloc(ncells * sizeof(sattr_T) + 1);

  size_t j = 0;
  size_t k = 0;
  for (size_t i = 0; i < no_of_cells; i++) {
    STRCPY(chunk[j++], cells.items[i].data.array.items[0].data.string.data);
    if (cells.items[i].data.array.size == 3) {
      // repeat present
      for (size_t i_intr = 1;
           i_intr < (size_t)cells.items[i].data.array.items[2].data.integer;
           i_intr++) {
        STRCPY(chunk[j++], cells.items[i].data.array.items[0].data.string.data);
        attrs[k++] = (sattr_T)cells.items[i].data.array.items[1].data.integer;
      }
    } else if (cells.items[i].data.array.size == 2) {
      // repeat = 1 but attrs != last_hl
      attrs[k++] = (sattr_T)cells.items[i].data.array.items[1].data.integer;
    }
    if (j > k) {
      // attrs == last_hl
      attrs[k] = attrs[k-1];
      k++;
    }
  }

  ui_call_raw_line(grid, row, startcol, endcol, clearcol, clearattr, lineflags,
                   (const schar_T *)chunk, (const sattr_T *)attrs);
}
