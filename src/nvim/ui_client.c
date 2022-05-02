// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/api/private/helpers.h"
#include "nvim/eval.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/globals.h"
#include "nvim/highlight.h"
#include "nvim/log.h"
#include "nvim/main.h"
#include "nvim/memory.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/ui.h"
#include "nvim/ui_client.h"

// uncrustify:off
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui_client.c.generated.h"
# include "ui_events_client.generated.h"
#endif
// uncrustify:on

uint64_t ui_client_start_server(int argc, char **argv)
{
  varnumber_T exit_status;
  char **args = xmalloc(((size_t)(2 + argc)) * sizeof(char *));
  int args_idx = 0;
  args[args_idx++] = xstrdup((const char *)get_vim_var_str(VV_PROGPATH));
  args[args_idx++] = xstrdup("--embed");
  for (int i = 1; i < argc; i++) {
    args[args_idx++] = xstrdup(argv[i]);
  }
  args[args_idx++] = NULL;

  Channel *channel = channel_job_start(args, CALLBACK_READER_INIT,
                                       CALLBACK_READER_INIT, CALLBACK_NONE,
                                       false, true, true, false, kChannelStdinPipe,
                                       NULL, 0, 0, NULL, &exit_status);
  if (ui_client_forward_stdin) {
    close(0);
    dup(2);
  }

  return channel->id;
}

void ui_client_run(bool remote_ui)
  FUNC_ATTR_NORETURN
{
  ui_builtin_start();

  loop_poll_events(&main_loop, 1);

  Array args = ARRAY_DICT_INIT;
  Dictionary opts = ARRAY_DICT_INIT;

  PUT(opts, "rgb", BOOLEAN_OBJ(true));
  PUT(opts, "ext_linegrid", BOOLEAN_OBJ(true));
  PUT(opts, "ext_termcolors", BOOLEAN_OBJ(true));

  if (ui_client_termname) {
    PUT(opts, "term_name", STRING_OBJ(cstr_as_string(ui_client_termname)));
  }
  if (ui_client_bg_respose != kNone) {
    bool is_dark = (ui_client_bg_respose == kTrue);
    PUT(opts, "term_background", STRING_OBJ(cstr_as_string(is_dark ? "dark" : "light")));
  }
  PUT(opts, "term_colors", INTEGER_OBJ(t_colors));
  if (!remote_ui) {
    PUT(opts, "stdin_tty", BOOLEAN_OBJ(stdin_isatty));
    PUT(opts, "stdout_tty", BOOLEAN_OBJ(stdout_isatty));
    if (ui_client_forward_stdin) {
      PUT(opts, "stdin_fd", INTEGER_OBJ(UI_CLIENT_STDIN_FD));
    }
  }

  ADD(args, INTEGER_OBJ(Columns));
  ADD(args, INTEGER_OBJ(Rows));
  ADD(args, DICTIONARY_OBJ(opts));

  rpc_send_event(ui_client_channel_id, "nvim_ui_attach", args);
  ui_client_attached = true;

  // os_exit() will be invoked when the client channel detaches
  while (true) {
    LOOP_PROCESS_EVENTS(&main_loop, resize_events, -1);
  }
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

static HlAttrs ui_client_dict2hlattrs(Dictionary d, bool rgb)
{
  Error err = ERROR_INIT;
  Dict(highlight) dict = { 0 };
  if (!api_dict_to_keydict(&dict, KeyDict_highlight_get_field, d, &err)) {
    // TODO(bfredl): log "err"
    return HLATTRS_INIT;
  }
  return dict2hlattrs(&dict, rgb, NULL, &err);
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
