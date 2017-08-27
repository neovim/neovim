// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/api/ui.h"
#include "nvim/channel.h"
#include "nvim/msgpack_rpc/channel.h"

PMap(uint64_t) *channels = NULL;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "channel.c.generated.h"
#endif
/// Teardown the module
void channel_teardown(void)
{
  if (!channels) {
    return;
  }

  Channel *channel;

  map_foreach_value(channels, channel, {
    (void)channel;  // close_channel(channel);
  });
}

/// Initializes the module
void channel_init(void)
{
  channels = pmap_new(uint64_t)();
  rpc_init();
  remote_ui_init();
}

void channel_incref(Channel *channel)
{
  channel->refcount++;
}

void channel_decref(Channel *channel)
{
  if (!(--channel->refcount)) {
    multiqueue_put(main_loop.fast_events, free_channel_event, 1, channel);
  }
}

static void free_channel_event(void **argv)
{
  Channel *channel = argv[0];
  if (channel->is_rpc) {
    rpc_free(channel);
  }

  callback_free(&channel->on_stdout);
  callback_free(&channel->on_stderr);
  callback_free(&channel->on_exit);

  pmap_del(uint64_t)(channels, channel->id);
  multiqueue_free(channel->events);
  xfree(channel);
}
