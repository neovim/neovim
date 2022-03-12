// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdbool.h>
#include <stdint.h>
#include <assert.h>

#include "nvim/vim.h"
#include "nvim/ui_client.h"
#include "nvim/api/private/helpers.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/ui.h"

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
