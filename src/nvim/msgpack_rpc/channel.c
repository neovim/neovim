#include <stdbool.h>
#include <string.h>
#include <inttypes.h>

#include <uv.h>
#include <msgpack.h>

#include "nvim/lib/klist.h"

#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/msgpack_rpc/remote_ui.h"
#include "nvim/os/event.h"
#include "nvim/os/rstream.h"
#include "nvim/os/rstream_defs.h"
#include "nvim/os/wstream.h"
#include "nvim/os/wstream_defs.h"
#include "nvim/os/job.h"
#include "nvim/os/job_defs.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/memory.h"
#include "nvim/os_unix.h"
#include "nvim/message.h"
#include "nvim/map.h"
#include "nvim/log.h"
#include "nvim/misc1.h"
#include "nvim/lib/kvec.h"

#define CHANNEL_BUFFER_SIZE 0xffff

#if MIN_LOG_LEVEL > DEBUG_LOG_LEVEL
#define log_client_msg(...)
#define log_server_msg(...)
#endif

typedef struct {
  uint64_t request_id;
  bool returned, errored;
  Object result;
} ChannelCallFrame;

typedef struct {
  uint64_t id;
  size_t refcount;
  size_t pending_requests;
  PMap(cstr_t) *subscribed_events;
  bool is_job, closed;
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
} Channel;

typedef struct {
  Channel *channel;
  MsgpackRpcRequestHandler handler;
  Array args;
  uint64_t request_id;
} RequestEvent;

typedef struct {
  Channel *channel;
  String method;
  Array args;
} DelayedNotification;

#define _noop(x)
KMEMPOOL_INIT(RequestEventPool, RequestEvent, _noop)
KLIST_INIT(DelayedNotification, DelayedNotification, _noop)

static kmempool_t(RequestEventPool) *request_event_pool = NULL;
static klist_t(DelayedNotification) *delayed_notifications = NULL;
static uint64_t next_id = 1;
static PMap(uint64_t) *channels = NULL;
static PMap(cstr_t) *event_strings = NULL;
static msgpack_sbuffer out_buffer;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/channel.c.generated.h"
#endif

/// Initializes the module
void channel_init(void)
{
  request_event_pool = kmp_init(RequestEventPool);
  delayed_notifications = kl_init(DelayedNotification);
  channels = pmap_new(uint64_t)();
  event_strings = pmap_new(cstr_t)();
  msgpack_sbuffer_init(&out_buffer);

  if (embedded_mode) {
    channel_from_stdio();
  }

  remote_ui_init();
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
/// @param argv The argument vector for the process. [consumed]
/// @return The channel id (> 0), on success.
///         0, on error.
uint64_t channel_from_job(char **argv)
{
  Channel *channel = register_channel();
  channel->is_job = true;
  incref(channel);  // job channels are only closed by the exit_cb

  int status;
  JobOptions opts = JOB_OPTIONS_INIT;
  opts.argv = argv;
  opts.data = channel;
  opts.stdout_cb = job_out;
  opts.stderr_cb = job_err;
  opts.exit_cb = job_exit;
  channel->data.job = job_start(opts, &status);

  if (status <= 0) {
    if (status == 0) {  // Two decrefs needed if status == 0.
      decref(channel);  // Only one needed if status < 0,
    }                   // because exit_cb will do the second one.
    decref(channel);
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
                                           rbuffer_new(CHANNEL_BUFFER_SIZE),
                                           channel);
  rstream_set_stream(channel->data.streams.read, stream);
  rstream_start(channel->data.streams.read);
  // write stream
  channel->data.streams.write = wstream_new(0);
  wstream_set_stream(channel->data.streams.write, stream);
  channel->data.streams.uv = stream;
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

  if (id && (!(channel = pmap_get(uint64_t)(channels, id))
            || channel->closed)) {
    api_free_array(args);
    return false;
  }

  if (channel) {
    if (channel->pending_requests) {
      DelayedNotification p = {
        .channel = channel,
        .method = cstr_to_string(name),
        .args = args
      };
      // Pending request, queue the notification for sending later
      *kl_pushp(DelayedNotification, delayed_notifications) = p;
    } else {
      send_event(channel, name, args);
    }
  }  else {
    // TODO(tarruda): Implement event broadcasting in vimscript
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

  if (!(channel = pmap_get(uint64_t)(channels, id)) || channel->closed) {
    api_set_error(err, Exception, _("Invalid channel \"%" PRIu64 "\""), id);
    api_free_array(args);
    return NIL;
  }

  incref(channel);
  uint64_t request_id = channel->next_request_id++;
  // Send the msgpack-rpc request
  send_request(channel, request_id, method_name, args);

  // Push the frame
  ChannelCallFrame frame = {request_id, false, false, NIL};
  kv_push(ChannelCallFrame *, channel->call_stack, &frame);
  channel->pending_requests++;
  event_poll_until(-1, frame.returned);
  (void)kv_pop(channel->call_stack);
  channel->pending_requests--;

  if (frame.errored) {
    api_set_error(err, Exception, "%s", frame.result.data.string.data);
    api_free_object(frame.result);
  }

  if (!channel->pending_requests) {
    send_delayed_notifications();
  }

  decref(channel);

  return frame.errored ? NIL : frame.result;
}

/// Subscribes to event broadcasts
///
/// @param id The channel id
/// @param event The event type string
void channel_subscribe(uint64_t id, char *event)
{
  Channel *channel;

  if (!(channel = pmap_get(uint64_t)(channels, id)) || channel->closed) {
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

  if (!(channel = pmap_get(uint64_t)(channels, id)) || channel->closed) {
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

  if (!(channel = pmap_get(uint64_t)(channels, id)) || channel->closed) {
    return false;
  }

  close_channel(channel);
  return true;
}

/// Creates an API channel from stdin/stdout. This is used when embedding
/// Neovim
static void channel_from_stdio(void)
{
  Channel *channel = register_channel();
  incref(channel);  // stdio channels are only closed on exit
  channel->is_job = false;
  // read stream
  channel->data.streams.read = rstream_new(parse_msgpack,
                                           rbuffer_new(CHANNEL_BUFFER_SIZE),
                                           channel);
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

  while ((count = rstream_pending(rstream))) {
    size_t read = rstream_read(rstream, buf, sizeof(buf) - 1);
    buf[read] = NUL;
    ELOG("Channel %" PRIu64 " stderr: %s", channel->id, buf);
  }
}

static void job_exit(Job *job, void *data)
{
  decref(data);
}

static void parse_msgpack(RStream *rstream, void *data, bool eof)
{
  Channel *channel = data;
  incref(channel);

  if (eof) {
    close_channel(channel);
    call_set_error(channel, "Channel was closed by the client");
    goto end;
  }

  size_t count = rstream_pending(rstream);
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
    bool is_response = is_rpc_response(&unpacked.data);
    log_client_msg(channel->id, !is_response, unpacked.data);

    if (is_response) {
      if (is_valid_rpc_response(&unpacked.data, channel)) {
        complete_call(&unpacked.data, channel);
      } else {
        char buf[256];
        snprintf(buf,
                 sizeof(buf),
                 "Channel %" PRIu64 " returned a response that doesn't have "
                 "a matching request id. Ensure the client is properly "
                 "synchronized",
                 channel->id);
        call_set_error(channel, buf);
      }
      msgpack_unpacked_destroy(&unpacked);
      // Bail out from this event loop iteration
      goto end;
    }

    handle_request(channel, &unpacked.data);
  }

  if (result == MSGPACK_UNPACK_NOMEM_ERROR) {
    mch_errmsg(e_outofmem);
    mch_errmsg("\n");
    decref(channel);
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
  decref(channel);
}

static void handle_request(Channel *channel, msgpack_object *request)
  FUNC_ATTR_NONNULL_ALL
{
  uint64_t request_id;
  Error error = ERROR_INIT;
  msgpack_rpc_validate(&request_id, request, &error);

  if (error.set) {
    // Validation failed, send response with error
    if (channel_write(channel,
                      serialize_response(channel->id,
                                         request_id,
                                         &error,
                                         NIL,
                                         &out_buffer))) {
      char buf[256];
      snprintf(buf, sizeof(buf),
               "Channel %" PRIu64 " sent an invalid message, closed.",
               channel->id);
      call_set_error(channel, buf);
    }
    return;
  }

  // Retrieve the request handler
  MsgpackRpcRequestHandler handler;
  msgpack_object method = request->via.array.ptr[2];

  if (method.type == MSGPACK_OBJECT_BIN || method.type == MSGPACK_OBJECT_STR) {
    handler = msgpack_rpc_get_handler_for(method.via.bin.ptr,
                                          method.via.bin.size);
  } else {
    handler.fn = msgpack_rpc_handle_missing_method;
    handler.defer = false;
  }

  Array args = ARRAY_DICT_INIT;
  msgpack_rpc_to_array(request->via.array.ptr + 3, &args);
  bool defer = (!kv_size(channel->call_stack) && handler.defer);
  RequestEvent *event_data = kmp_alloc(RequestEventPool, request_event_pool);
  event_data->channel = channel;
  event_data->handler = handler;
  event_data->args = args;
  event_data->request_id = request_id;
  incref(channel);
  event_push((Event) {
    .handler = on_request_event,
    .data = event_data
  }, defer);
}

static void on_request_event(Event event)
{
  RequestEvent *e = event.data;
  Channel *channel = e->channel;
  MsgpackRpcRequestHandler handler = e->handler;
  Array args = e->args;
  uint64_t request_id = e->request_id;
  Error error = ERROR_INIT;
  Object result = handler.fn(channel->id, request_id, args, &error);
  // send the response
  msgpack_packer response;
  msgpack_packer_init(&response, &out_buffer, msgpack_sbuffer_write);
  channel_write(channel, serialize_response(channel->id,
                                            request_id,
                                            &error,
                                            result,
                                            &out_buffer));
  // All arguments were freed already, but we still need to free the array
  free(args.items);
  decref(channel);
  kmp_free(RequestEventPool, request_event_pool, e);
}

static bool channel_write(Channel *channel, WBuffer *buffer)
{
  bool success;

  if (channel->closed) {
    return false;
  }

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
  channel_write(channel, serialize_response(channel->id,
                                            id,
                                            &e,
                                            NIL,
                                            &out_buffer));
}

static void send_request(Channel *channel,
                         uint64_t id,
                         char *name,
                         Array args)
{
  String method = {.size = strlen(name), .data = name};
  channel_write(channel, serialize_request(channel->id,
                                           id,
                                           method,
                                           args,
                                           &out_buffer,
                                           1));
}

static void send_event(Channel *channel,
                       char *name,
                       Array args)
{
  String method = {.size = strlen(name), .data = name};
  channel_write(channel, serialize_request(channel->id,
                                           0,
                                           method,
                                           args,
                                           &out_buffer,
                                           1));
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
                                      0,
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

/// Close the channel streams/job and free the channel resources.
static void close_channel(Channel *channel)
{
  if (channel->closed) {
    return;
  }

  channel->closed = true;

  if (channel->is_job) {
    if (channel->data.job) {
      job_stop(channel->data.job);
    }
  } else {
    rstream_free(channel->data.streams.read);
    wstream_free(channel->data.streams.write);
    uv_handle_t *handle = (uv_handle_t *)channel->data.streams.uv;
    if (handle) {
      uv_close(handle, close_cb);
    } else {
      event_push((Event) { .handler = on_stdio_close, .data = channel }, false);
    }
  }

  decref(channel);
}

static void on_stdio_close(Event e)
{
  decref(e.data);

  if (!exiting) {
    mch_exit(0);
  }
}

static void free_channel(Channel *channel)
{
  remote_ui_disconnect(channel->id);
  pmap_del(uint64_t)(channels, channel->id);
  msgpack_unpacker_free(channel->unpacker);

  // Unsubscribe from all events
  char *event_string;
  map_foreach_value(channel->subscribed_events, event_string, {
    unsubscribe(channel, event_string);
  });

  pmap_free(cstr_t)(channel->subscribed_events);
  kv_destroy(channel->call_stack);
  free(channel);
}

static void close_cb(uv_handle_t *handle)
{
  free(handle->data);
  free(handle);
}

static Channel *register_channel(void)
{
  Channel *rv = xmalloc(sizeof(Channel));
  rv->refcount = 1;
  rv->closed = false;
  rv->unpacker = msgpack_unpacker_new(MSGPACK_UNPACKER_INIT_BUFFER_SIZE);
  rv->id = next_id++;
  rv->pending_requests = 0;
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
  return kv_size(channel->call_stack) && response_id
    == kv_A(channel->call_stack, kv_size(channel->call_stack) - 1)->request_id;
}

static void complete_call(msgpack_object *obj, Channel *channel)
{
  ChannelCallFrame *frame = kv_A(channel->call_stack,
                             kv_size(channel->call_stack) - 1);
  frame->returned = true;
  frame->errored = obj->via.array.ptr[2].type != MSGPACK_OBJECT_NIL;

  if (frame->errored) {
    msgpack_rpc_to_object(&obj->via.array.ptr[2], &frame->result);
  } else {
    msgpack_rpc_to_object(&obj->via.array.ptr[3], &frame->result);
  }
}

static void call_set_error(Channel *channel, char *msg)
{
  ELOG("Msgpack-RPC error: %s", msg);
  for (size_t i = 0; i < kv_size(channel->call_stack); i++) {
    ChannelCallFrame *frame = kv_A(channel->call_stack, i);
    frame->returned = true;
    frame->errored = true;
    frame->result = STRING_OBJ(cstr_to_string(msg));
  }

  close_channel(channel);
}

static WBuffer *serialize_request(uint64_t channel_id,
                                  uint64_t request_id,
                                  String method,
                                  Array args,
                                  msgpack_sbuffer *sbuffer,
                                  size_t refcount)
{
  msgpack_packer pac;
  msgpack_packer_init(&pac, sbuffer, msgpack_sbuffer_write);
  msgpack_rpc_serialize_request(request_id, method, args, &pac);
  log_server_msg(channel_id, sbuffer);
  WBuffer *rv = wstream_new_buffer(xmemdup(sbuffer->data, sbuffer->size),
                                   sbuffer->size,
                                   refcount,
                                   free);
  msgpack_sbuffer_clear(sbuffer);
  api_free_array(args);
  return rv;
}

static WBuffer *serialize_response(uint64_t channel_id,
                                   uint64_t response_id,
                                   Error *err,
                                   Object arg,
                                   msgpack_sbuffer *sbuffer)
{
  msgpack_packer pac;
  msgpack_packer_init(&pac, sbuffer, msgpack_sbuffer_write);
  msgpack_rpc_serialize_response(response_id, err, arg, &pac);
  log_server_msg(channel_id, sbuffer);
  WBuffer *rv = wstream_new_buffer(xmemdup(sbuffer->data, sbuffer->size),
                                   sbuffer->size,
                                   1,  // responses only go though 1 channel
                                   free);
  msgpack_sbuffer_clear(sbuffer);
  api_free_object(arg);
  return rv;
}

static void send_delayed_notifications(void)
{
  DelayedNotification p;

  while (kl_shift(DelayedNotification, delayed_notifications, &p) == 0) {
    if (p.channel) {
      send_event(p.channel, p.method.data, p.args);
    } else {
      broadcast_event(p.method.data, p.args);
    }
    free(p.method.data);
  }
}

static void incref(Channel *channel)
{
  channel->refcount++;
}

static void decref(Channel *channel)
{
  if (!(--channel->refcount)) {
    free_channel(channel);
  }
}

#if MIN_LOG_LEVEL <= DEBUG_LOG_LEVEL
#define REQ "[request]      "
#define RES "[response]     "
#define NOT "[notification] "

static void log_server_msg(uint64_t channel_id,
                           msgpack_sbuffer *packed)
{
  msgpack_unpacked unpacked;
  msgpack_unpacked_init(&unpacked);
  msgpack_unpack_next(&unpacked, packed->data, packed->size, NULL);
  uint64_t type = unpacked.data.via.array.ptr[0].via.u64;
  DLOGN("[msgpack-rpc] nvim -> client(%" PRIu64 ") ", channel_id);
  FILE *f = open_log_file();
  fprintf(f, type ? (type == 1 ? RES : NOT) : REQ);
  log_msg_close(f, unpacked.data);
  msgpack_unpacked_destroy(&unpacked);
}

static void log_client_msg(uint64_t channel_id,
                           bool is_request,
                           msgpack_object msg)
{
  DLOGN("[msgpack-rpc] client(%" PRIu64 ") -> nvim ", channel_id);
  FILE *f = open_log_file();
  fprintf(f, is_request ? REQ : RES);
  log_msg_close(f, msg);
}

static void log_msg_close(FILE *f, msgpack_object msg)
{
  msgpack_object_print(f, msg);
  fputc('\n', f);
  fflush(f);
  fclose(f);
}
#endif

