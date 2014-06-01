#include <string.h>

#include <uv.h>
#include <msgpack.h>

#include "nvim/api/private/helpers.h"
#include "nvim/os/channel.h"
#include "nvim/os/rstream.h"
#include "nvim/os/rstream_defs.h"
#include "nvim/os/wstream.h"
#include "nvim/os/wstream_defs.h"
#include "nvim/os/job.h"
#include "nvim/os/job_defs.h"
#include "nvim/os/msgpack_rpc.h"
#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/map.h"
#include "nvim/lib/kvec.h"

typedef struct {
  uint64_t id;
  PMap(cstr_t) *subscribed_events;
  bool is_job;
  msgpack_unpacker *unpacker;
  msgpack_sbuffer *sbuffer;
  union {
    int job_id;
    struct {
      RStream *read;
      WStream *write;
      uv_stream_t *uv;
    } streams;
  } data;
} Channel;

static uint64_t next_id = 1;
static PMap(uint64_t) *channels = NULL;
static PMap(cstr_t) *event_strings = NULL;
static msgpack_sbuffer msgpack_event_buffer;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/channel.c.generated.h"
#endif

/// Initializes the module
void channel_init()
{
  channels = pmap_new(uint64_t)();
  event_strings = pmap_new(cstr_t)();
  msgpack_sbuffer_init(&msgpack_event_buffer);
}

/// Teardown the module
void channel_teardown()
{
  if (!channels) {
    return;
  }

  Channel *channel;

  map_foreach_value(channels, channel, {
    close_channel(channel);
  });
}

/// Creates an API channel by starting a job and connecting to its
/// stdin/stdout. stderr is forwarded to the editor error stream.
///
/// @param argv The argument vector for the process
void channel_from_job(char **argv)
{
  Channel *channel = register_channel();
  channel->is_job = true;
  channel->data.job_id = job_start(argv, channel, job_out, job_err, NULL);
}

/// Creates an API channel from a libuv stream representing a tcp or
/// pipe/socket client connection
///
/// @param stream The established connection
void channel_from_stream(uv_stream_t *stream)
{
  Channel *channel = register_channel();
  stream->data = NULL;
  channel->is_job = false;
  // read stream
  channel->data.streams.read = rstream_new(parse_msgpack, 1024, channel, true);
  rstream_set_stream(channel->data.streams.read, stream);
  rstream_start(channel->data.streams.read);
  // write stream
  channel->data.streams.write = wstream_new(1024 * 1024);
  wstream_set_stream(channel->data.streams.write, stream);
  channel->data.streams.uv = stream;
}

/// Sends event/data to channel
///
/// @param id The channel id. If 0, the event will be sent to all
///        channels that have subscribed to the event type
/// @param type The event type, an arbitrary string
/// @param obj The event data
/// @return True if the data was sent successfully, false otherwise.
bool channel_send_event(uint64_t id, char *type, typval_T *data)
{
  Channel *channel = NULL;

  if (id > 0) {
    if (!(channel = pmap_get(uint64_t)(channels, id))) {
      return false;
    }
    send_event(channel, type, data);
  } else {
    broadcast_event(type, data);
  }

  return true;
}

/// Subscribes to event broadcasts
///
/// @param id The channel id
/// @param event The event type string
void channel_subscribe(uint64_t id, char *event)
{
  Channel *channel;

  if (!(channel = pmap_get(uint64_t)(channels, id))) {
    return;
  }

  char *event_string = pmap_get(cstr_t)(event_strings, event);

  if (!event_string) {
    event_string = xstrdup(event);
    pmap_put(cstr_t)(event_strings, event_string, event_string);
  }

  pmap_put(cstr_t)(channel->subscribed_events, event_string, event_string);
}

/// Unsubscribes to event broadcasts
///
/// @param id The channel id
/// @param event The event type string
void channel_unsubscribe(uint64_t id, char *event)
{
  Channel *channel;

  if (!(channel = pmap_get(uint64_t)(channels, id))) {
    return;
  }

  unsubscribe(channel, event);
}

static void job_out(RStream *rstream, void *data, bool eof)
{
  Job *job = data;
  parse_msgpack(rstream, job_data(job), eof);
}

static void job_err(RStream *rstream, void *data, bool eof)
{
  // TODO(tarruda): plugin error messages should be sent to the error buffer
}

static void parse_msgpack(RStream *rstream, void *data, bool eof)
{
  Channel *channel = data;

  if (eof) {
    close_channel(channel);
    return;
  }

  uint32_t count = rstream_available(rstream);

  // Feed the unpacker with data
  msgpack_unpacker_reserve_buffer(channel->unpacker, count);
  rstream_read(rstream, msgpack_unpacker_buffer(channel->unpacker), count);
  msgpack_unpacker_buffer_consumed(channel->unpacker, count);

  msgpack_unpacked unpacked;
  msgpack_unpacked_init(&unpacked);

  // Deserialize everything we can.
  while (msgpack_unpacker_next(channel->unpacker, &unpacked)) {
    // Each object is a new msgpack-rpc request and requires an empty response
    msgpack_packer response;
    msgpack_packer_init(&response, channel->sbuffer, msgpack_sbuffer_write);
    // Perform the call
    msgpack_rpc_call(channel->id, &unpacked.data, &response);
    wstream_write(channel->data.streams.write,
                  wstream_new_buffer(channel->sbuffer->data,
                                     channel->sbuffer->size,
                                     true));

    // Clear the buffer for future calls
    msgpack_sbuffer_clear(channel->sbuffer);
  }
}

static void send_event(Channel *channel, char *type, typval_T *data)
{
  wstream_write(channel->data.streams.write, serialize_event(type, data));
}

static void broadcast_event(char *type, typval_T *data)
{
  kvec_t(Channel *) subscribed;
  kv_init(subscribed);
  Channel *channel;

  map_foreach_value(channels, channel, {
    if (pmap_has(cstr_t)(channel->subscribed_events, type)) {
      kv_push(Channel *, subscribed, channel);
    }
  });

  if (!kv_size(subscribed)) {
    goto end;
  }

  WBuffer *buffer = serialize_event(type, data);

  for (size_t i = 0; i < kv_size(subscribed); i++) {
    wstream_write(kv_A(subscribed, i)->data.streams.write, buffer);
  }

end:
  kv_destroy(subscribed);
}

static void unsubscribe(Channel *channel, char *event)
{
  char *event_string = pmap_get(cstr_t)(event_strings, event);
  pmap_del(cstr_t)(channel->subscribed_events, event_string);

  map_foreach_value(channels, channel, {
    if (pmap_has(cstr_t)(channel->subscribed_events, event_string)) {
      return;
    }
  });

  // Since the string is no longer used by other channels, release it's memory
  pmap_del(cstr_t)(event_strings, event_string);
  free(event_string);
}

static void close_channel(Channel *channel)
{
  pmap_del(uint64_t)(channels, channel->id);
  msgpack_sbuffer_free(channel->sbuffer);
  msgpack_unpacker_free(channel->unpacker);

  if (channel->is_job) {
    job_stop(channel->data.job_id);
  } else {
    rstream_free(channel->data.streams.read);
    wstream_free(channel->data.streams.write);
    uv_close((uv_handle_t *)channel->data.streams.uv, close_cb);
  }

  // Unsubscribe from all events
  char *event_string;
  map_foreach_value(channel->subscribed_events, event_string, {
    unsubscribe(channel, event_string);
  });

  pmap_free(cstr_t)(channel->subscribed_events);
  free(channel);
}

static void close_cb(uv_handle_t *handle)
{
  free(handle->data);
  free(handle);
}

static WBuffer *serialize_event(char *type, typval_T *data)
{
  String event_type = {.size = strnlen(type, EVENT_MAXLEN), .data = type};
  Object event_data = vim_to_object(data);
  msgpack_packer packer;
  msgpack_packer_init(&packer, &msgpack_event_buffer, msgpack_sbuffer_write);
  msgpack_rpc_notification(event_type, event_data, &packer);
  WBuffer *rv = wstream_new_buffer(msgpack_event_buffer.data,
                                   msgpack_event_buffer.size,
                                   true);
  msgpack_rpc_free_object(event_data);
  msgpack_sbuffer_clear(&msgpack_event_buffer);

  return rv;
}

static Channel *register_channel()
{
  Channel *rv = xmalloc(sizeof(Channel));
  rv->unpacker = msgpack_unpacker_new(MSGPACK_UNPACKER_INIT_BUFFER_SIZE);
  rv->sbuffer = msgpack_sbuffer_new();
  rv->id = next_id++;
  rv->subscribed_events = pmap_new(cstr_t)();
  pmap_put(uint64_t)(channels, rv->id, rv);
  return rv;
}
