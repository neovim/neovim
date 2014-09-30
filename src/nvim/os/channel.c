#include <stdbool.h>
#include <string.h>
#include <inttypes.h>

#include <uv.h>
#include <msgpack.h>

#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/os/channel.h"
#include "nvim/os/event.h"
#include "nvim/os/rstream.h"
#include "nvim/os/rstream_defs.h"
#include "nvim/os/wstream.h"
#include "nvim/os/wstream_defs.h"
#include "nvim/os/job.h"
#include "nvim/os/job_defs.h"
#include "nvim/os/msgpack_rpc.h"
#include "nvim/os/msgpack_rpc_helpers.h"
#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/memory.h"
#include "nvim/os_unix.h"
#include "nvim/message.h"
#include "nvim/term.h"
#include "nvim/map.h"
#include "nvim/log.h"
#include "nvim/misc1.h"
#include "nvim/lib/kvec.h"

#define CHANNEL_BUFFER_SIZE 0xffff

typedef struct {
  uint64_t request_id;
  bool errored;
  Object result;
} ChannelCallFrame;

typedef struct {
  uint64_t id;
  PMap(cstr_t) *subscribed_events;
  bool is_job, enabled;
  msgpack_unpacker *unpacker;
  union {
    Job *job;
    struct {
      RStream *read;
      WStream *write;
      uv_stream_t *uv;
    } streams;
  } data;
  uint64_t next_request_id;
  kvec_t(ChannelCallFrame *) call_stack;
  size_t rpc_call_level;
} Channel;

static uint64_t next_id = 1;
static PMap(uint64_t) *channels = NULL;
static PMap(cstr_t) *event_strings = NULL;
static msgpack_sbuffer out_buffer;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/channel.c.generated.h"
#endif

/// Initializes the module
void channel_init(void)
{
  channels = pmap_new(uint64_t)();
  event_strings = pmap_new(cstr_t)();
  msgpack_sbuffer_init(&out_buffer);

  if (embedded_mode) {
    channel_from_stdio();
  }
}

/// Teardown the module
void channel_teardown(void)
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
/// @return The channel id
uint64_t channel_from_job(char **argv)
{
  Channel *channel = register_channel();
  channel->is_job = true;

  int status;
  channel->data.job = job_start(argv,
                                channel,
                                job_out,
                                job_err,
                                NULL,
                                0,
                                &status);

  if (status <= 0) {
    close_channel(channel);
    return 0;
  }

  return channel->id;
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
  channel->data.streams.read = rstream_new(parse_msgpack,
                                           CHANNEL_BUFFER_SIZE,
                                           channel,
                                           NULL);
  rstream_set_stream(channel->data.streams.read, stream);
  rstream_start(channel->data.streams.read);
  // write stream
  channel->data.streams.write = wstream_new(0);
  wstream_set_stream(channel->data.streams.write, stream);
  channel->data.streams.uv = stream;
}

bool channel_exists(uint64_t id)
{
  Channel *channel;
  return (channel = pmap_get(uint64_t)(channels, id)) != NULL
    && channel->enabled;
}

/// Sends event/arguments to channel
///
/// @param id The channel id. If 0, the event will be sent to all
///        channels that have subscribed to the event type
/// @param name The event name, an arbitrary string
/// @param args Array with event arguments
/// @return True if the event was sent successfully, false otherwise.
bool channel_send_event(uint64_t id, char *name, Array args)
{
  Channel *channel = NULL;

  if (id > 0) {
    if (!(channel = pmap_get(uint64_t)(channels, id)) || !channel->enabled) {
      api_free_array(args);
      return false;
    }
    send_event(channel, name, args);
  } else {
    broadcast_event(name, args);
  }

  return true;
}

/// Sends a method call to a channel
///
/// @param id The channel id
/// @param method_name The method name, an arbitrary string
/// @param args Array with method arguments
/// @param[out] error True if the return value is an error
/// @return Whatever the remote method returned
Object channel_send_call(uint64_t id,
                         char *method_name,
                         Array args,
                         Error *err)
{
  Channel *channel = NULL;

  if (!(channel = pmap_get(uint64_t)(channels, id)) || !channel->enabled) {
    api_set_error(err, Exception, _("Invalid channel \"%" PRIu64 "\""), id);
    api_free_array(args);
    return NIL;
  }

  if (kv_size(channel->call_stack) > 20) {
    // 20 stack depth is more than anyone should ever need for RPC calls
    api_set_error(err,
                  Exception,
                  _("Channel %" PRIu64 " crossed maximum stack depth"),
                  channel->id);
    api_free_array(args);
    return NIL;
  }

  uint64_t request_id = channel->next_request_id++;
  // Send the msgpack-rpc request
  send_request(channel, request_id, method_name, args);

  EventSource channel_source = channel->is_job
    ? job_event_source(channel->data.job)
    : rstream_event_source(channel->data.streams.read);
  EventSource sources[] = {channel_source, NULL};

  // Push the frame
  ChannelCallFrame frame = {request_id, false, NIL};
  kv_push(ChannelCallFrame *, channel->call_stack, &frame);
  size_t size = kv_size(channel->call_stack);

  do {
    event_poll(-1, sources);
  } while (
      // Continue running if ...
      channel->enabled &&  // the channel is still enabled
      kv_size(channel->call_stack) >= size);  // the call didn't return

  if (frame.errored) {
    api_set_error(err, Exception, "%s", frame.result.data.string.data);
    return NIL;
  }

  return frame.result;
}

/// Subscribes to event broadcasts
///
/// @param id The channel id
/// @param event The event type string
void channel_subscribe(uint64_t id, char *event)
{
  Channel *channel;

  if (!(channel = pmap_get(uint64_t)(channels, id)) || !channel->enabled) {
    abort();
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

  if (!(channel = pmap_get(uint64_t)(channels, id)) || !channel->enabled) {
    abort();
  }

  unsubscribe(channel, event);
}

/// Closes a channel
///
/// @param id The channel id
/// @return true if successful, false otherwise
bool channel_close(uint64_t id)
{
  Channel *channel;

  if (!(channel = pmap_get(uint64_t)(channels, id)) || !channel->enabled) {
    return false;
  }

  channel_kill(channel);
  channel->enabled = false;
  return true;
}

/// Creates an API channel from stdin/stdout. This is used when embedding
/// Neovim
static void channel_from_stdio(void)
{
  Channel *channel = register_channel();
  channel->is_job = false;
  // read stream
  channel->data.streams.read = rstream_new(parse_msgpack,
                                           CHANNEL_BUFFER_SIZE,
                                           channel,
                                           NULL);
  rstream_set_file(channel->data.streams.read, 0);
  rstream_start(channel->data.streams.read);
  // write stream
  channel->data.streams.write = wstream_new(0);
  wstream_set_file(channel->data.streams.write, 1);
  channel->data.streams.uv = NULL;
}

static void job_out(RStream *rstream, void *data, bool eof)
{
  Job *job = data;
  parse_msgpack(rstream, job_data(job), eof);
}

static void job_err(RStream *rstream, void *data, bool eof)
{
  size_t count;
  char buf[256];
  Channel *channel = job_data(data);

  while ((count = rstream_available(rstream))) {
    size_t read = rstream_read(rstream, buf, sizeof(buf) - 1);
    buf[read] = NUL;
    ELOG("Channel %" PRIu64 " stderr: %s", channel->id, buf);
  }
}

static void parse_msgpack(RStream *rstream, void *data, bool eof)
{
  Channel *channel = data;
  channel->rpc_call_level++;

  if (eof) {
    char buf[256];
    snprintf(buf,
             sizeof(buf),
             "Before returning from a RPC call, channel %" PRIu64 " was "
             "closed by the client",
             channel->id);
    call_set_error(channel, buf);
    goto end;
  }

  uint32_t count = rstream_available(rstream);
  DLOG("Feeding the msgpack parser with %u bytes of data from RStream(%p)",
       count,
       rstream);

  // Feed the unpacker with data
  msgpack_unpacker_reserve_buffer(channel->unpacker, count);
  rstream_read(rstream, msgpack_unpacker_buffer(channel->unpacker), count);
  msgpack_unpacker_buffer_consumed(channel->unpacker, count);

  msgpack_unpacked unpacked;
  msgpack_unpacked_init(&unpacked);
  msgpack_unpack_return result;

  // Deserialize everything we can.
  while ((result = msgpack_unpacker_next(channel->unpacker, &unpacked)) ==
      MSGPACK_UNPACK_SUCCESS) {
    if (kv_size(channel->call_stack) && is_rpc_response(&unpacked.data)) {
      if (is_valid_rpc_response(&unpacked.data, channel)) {
        call_stack_pop(&unpacked.data, channel);
      } else {
        char buf[256];
        snprintf(buf,
                 sizeof(buf),
                 "Channel %" PRIu64 " returned a response that doesn't have "
                 " a matching id for the current RPC call. Ensure the client "
                 " is properly synchronized",
                 channel->id);
        call_set_error(channel, buf);
      }
      msgpack_unpacked_destroy(&unpacked);
      // Bail out from this event loop iteration
      goto end;
    }

    // Perform the call
    WBuffer *resp = msgpack_rpc_call(channel->id, &unpacked.data, &out_buffer);
    // write the response
    if (!channel_write(channel, resp)) {
      goto end;
    }
  }

  if (result == MSGPACK_UNPACK_NOMEM_ERROR) {
    OUT_STR(e_outofmem);
    out_char('\n');
    preserve_exit();
  }

  if (result == MSGPACK_UNPACK_PARSE_ERROR) {
    // See src/msgpack/unpack_template.h in msgpack source tree for
    // causes for this error(search for 'goto _failed')
    //
    // A not so uncommon cause for this might be deserializing objects with
    // a high nesting level: msgpack will break when it's internal parse stack
    // size exceeds MSGPACK_EMBED_STACK_SIZE(defined as 32 by default)
    send_error(channel, 0, "Invalid msgpack payload. "
                           "This error can also happen when deserializing "
                           "an object with high level of nesting");
  }

end:
  channel->rpc_call_level--;
  if (!channel->enabled && !kv_size(channel->call_stack)) {
    // Now it's safe to destroy the channel
    close_channel(channel);
  }
}

static bool channel_write(Channel *channel, WBuffer *buffer)
{
  bool success;

  if (channel->is_job) {
    success = job_write(channel->data.job, buffer);
  } else {
    success = wstream_write(channel->data.streams.write, buffer);
  }

  if (!success) {
    // If the write failed for any reason, close the channel
    char buf[256];
    snprintf(buf,
             sizeof(buf),
             "Before returning from a RPC call, channel %" PRIu64 " was "
             "closed due to a failed write",
             channel->id);
    call_set_error(channel, buf);
  }

  return success;
}

static void send_error(Channel *channel, uint64_t id, char *err)
{
  Error e = ERROR_INIT;
  api_set_error(&e, Exception, "%s", err);
  channel_write(channel, serialize_response(id, &e, NIL, &out_buffer));
}

static void send_request(Channel *channel,
                         uint64_t id,
                         char *name,
                         Array args)
{
  String method = {.size = strlen(name), .data = name};
  channel_write(channel, serialize_request(id, method, args, &out_buffer, 1));
}

static void send_event(Channel *channel,
                       char *name,
                       Array args)
{
  String method = {.size = strlen(name), .data = name};
  channel_write(channel, serialize_request(0, method, args, &out_buffer, 1));
}

static void broadcast_event(char *name, Array args)
{
  kvec_t(Channel *) subscribed;
  kv_init(subscribed);
  Channel *channel;

  map_foreach_value(channels, channel, {
    if (pmap_has(cstr_t)(channel->subscribed_events, name)) {
      kv_push(Channel *, subscribed, channel);
    }
  });

  if (!kv_size(subscribed)) {
    api_free_array(args);
    goto end;
  }

  String method = {.size = strlen(name), .data = name};
  WBuffer *buffer = serialize_request(0,
                                      method,
                                      args,
                                      &out_buffer,
                                      kv_size(subscribed));

  for (size_t i = 0; i < kv_size(subscribed); i++) {
    channel_write(kv_A(subscribed, i), buffer);
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
  msgpack_unpacker_free(channel->unpacker);

  // Unsubscribe from all events
  char *event_string;
  map_foreach_value(channel->subscribed_events, event_string, {
    unsubscribe(channel, event_string);
  });

  pmap_free(cstr_t)(channel->subscribed_events);
  kv_destroy(channel->call_stack);
  channel_kill(channel);

  free(channel);
}

static void channel_kill(Channel *channel)
{
  if (channel->is_job) {
    if (channel->data.job) {
      job_stop(channel->data.job);
    }
  } else {
    rstream_free(channel->data.streams.read);
    wstream_free(channel->data.streams.write);
    if (channel->data.streams.uv) {
      uv_close((uv_handle_t *)channel->data.streams.uv, close_cb);
    } else {
      // When the stdin channel closes, it's time to go
      mch_exit(0);
    }
  }
}

static void close_cb(uv_handle_t *handle)
{
  free(handle->data);
  free(handle);
}

static Channel *register_channel(void)
{
  Channel *rv = xmalloc(sizeof(Channel));
  rv->enabled = true;
  rv->rpc_call_level = 0;
  rv->unpacker = msgpack_unpacker_new(MSGPACK_UNPACKER_INIT_BUFFER_SIZE);
  rv->id = next_id++;
  rv->subscribed_events = pmap_new(cstr_t)();
  rv->next_request_id = 1;
  kv_init(rv->call_stack);
  pmap_put(uint64_t)(channels, rv->id, rv);
  return rv;
}

static bool is_rpc_response(msgpack_object *obj)
{
  return obj->type == MSGPACK_OBJECT_ARRAY
      && obj->via.array.size == 4
      && obj->via.array.ptr[0].type == MSGPACK_OBJECT_POSITIVE_INTEGER
      && obj->via.array.ptr[0].via.u64 == 1
      && obj->via.array.ptr[1].type == MSGPACK_OBJECT_POSITIVE_INTEGER;
}

static bool is_valid_rpc_response(msgpack_object *obj, Channel *channel)
{
  uint64_t response_id = obj->via.array.ptr[1].via.u64;
  // Must be equal to the frame at the stack's bottom
  return response_id == kv_A(channel->call_stack,
                             kv_size(channel->call_stack) - 1)->request_id;
}

static void call_stack_pop(msgpack_object *obj, Channel *channel)
{
  ChannelCallFrame *frame = kv_pop(channel->call_stack);
  frame->errored = obj->via.array.ptr[2].type != MSGPACK_OBJECT_NIL;

  if (frame->errored) {
    msgpack_rpc_to_object(&obj->via.array.ptr[2], &frame->result);
  } else {
    msgpack_rpc_to_object(&obj->via.array.ptr[3], &frame->result);
  }
}

static void call_set_error(Channel *channel, char *msg)
{
  for (size_t i = 0; i < kv_size(channel->call_stack); i++) {
    ChannelCallFrame *frame = kv_pop(channel->call_stack);
    frame->errored = true;
    frame->result = STRING_OBJ(cstr_to_string(msg));
  }

  channel->enabled = false;
}
