// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/highlight.h"
#include "nvim/log.h"
#include "nvim/map.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/screen.h"
#include "nvim/ui.h"
#include "nvim/ui_client.h"
#include "nvim/vim.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui_client.c.generated.h"

# include "ui_events_client.generated.h"
#endif

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
  ui_client_channel_id = chan;
}

UIClientHandler ui_client_get_redraw_handler(const char *name, size_t name_len, Error *error)
{
  int hash = ui_client_handler_hash(name, name_len);
  if (hash < 0) {
    return (UIClientHandler){ NULL, NULL };
  }
  return event_handlers[hash];
}

/// Placeholder for _sync_ requests with 'redraw' method name
///
/// async 'redraw' events, which are expected when nvim acts as an ui client.
/// get handled in msgpack_rpc/unpacker.c and directly dispatched to handlers
/// of specific ui events, like ui_client_event_grid_resize and so on.
Object handle_ui_client_redraw(uint64_t channel_id, Array args, Arena *arena, Error *error)
{
  api_set_error(error, kErrorTypeValidation, "'redraw' cannot be sent as a request");
  return NIL;
}

/// run the main thread in ui client mode
///
/// This is just a stub. the full version will handle input, resizing, etc
void ui_client_execute(uint64_t chan)
  FUNC_ATTR_NORETURN
{
  while (true) {
    loop_poll_events(&main_loop, -1);
    multiqueue_process_events(resize_events);
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

void ui_client_event_grid_resize(Array args)
{
  if (args.size < 3
      || args.items[0].type != kObjectTypeInteger
      || args.items[1].type != kObjectTypeInteger
      || args.items[2].type != kObjectTypeInteger) {
    ELOG("Error handling ui event 'grid_resize'");
    return;
  }

  Integer grid = args.items[0].data.integer;
  Integer width = args.items[1].data.integer;
  Integer height = args.items[2].data.integer;
  ui_call_grid_resize(grid, width, height);

  if (grid_line_buf_size < (size_t)width) {
    xfree(grid_line_buf_char);
    xfree(grid_line_buf_attr);
    grid_line_buf_size = (size_t)width;
    grid_line_buf_char = xmalloc(grid_line_buf_size * sizeof(schar_T));
    grid_line_buf_attr = xmalloc(grid_line_buf_size * sizeof(sattr_T));
  }
}

void ui_client_event_grid_line(Array args)
  FUNC_ATTR_NORETURN
{
  abort();  // unreachable
}

void ui_client_event_raw_line(GridLineEvent *g)
{
  int grid = g->args[0], row = g->args[1], startcol = g->args[2];
  Integer endcol = startcol + g->coloff;
  Integer clearcol = endcol + g->clear_width;

  // TODO(hlpr98): Accommodate other LineFlags when included in grid_line
  LineFlags lineflags = 0;

  ui_call_raw_line(grid, row, startcol, endcol, clearcol, g->cur_attr, lineflags,
                   (const schar_T *)grid_line_buf_char, grid_line_buf_attr);
}
