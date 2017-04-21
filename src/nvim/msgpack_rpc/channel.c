// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdbool.h>
#include <string.h>
#include <inttypes.h>

#include <uv.h>
#include <msgpack.h>

#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/api/ui.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/event/loop.h"
#include "nvim/event/libuv_process.h"
#include "nvim/event/rstream.h"
#include "nvim/event/wstream.h"
#include "nvim/event/socket.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/vim.h"
#include "nvim/main.h"
#include "nvim/ascii.h"
#include "nvim/memory.h"
#include "nvim/eval.h"
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

typedef enum {
  kChannelTypeSocket,
  kChannelTypeProc,
  kChannelTypeStdio
} ChannelType;

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
  bool closed;
  ChannelType type;
  msgpack_unpacker *unpacker;
  union {
    Stream stream;
    Process *proc;
    struct {
      Stream in;
      Stream out;
    } std;
  } data;
  uint64_t next_request_id;
  kvec_t(ChannelCallFrame *) call_stack;
  kvec_t(WBuffer *) delayed_notifications;
  MultiQueue *events;
} Channel;

typedef struct {
  Channel *channel;
  MsgpackRpcRequestHandler handler;
  Array args;
  uint64_t request_id;
} RequestEvent;

static PMap(uint64_t) *channels = NULL;
static PMap(cstr_t) *event_strings = NULL;
static msgpack_sbuffer out_buffer;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/channel.c.generated.h"
#endif

/// Initializes the module
void channel_init(void)
{
  channels = pmap_new(uint64_t)();
  event_strings = pmap_new(cstr_t)();
  msgpack_sbuffer_init(&out_buffer);
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

/// Creates an API channel by starting a process and connecting to its
/// stdin/stdout. stderr is handled by the job infrastructure.
///
/// @param argv The argument vector for the process. [consumed]
/// @return The channel id (> 0), on success.
///         0, on error.
uint64_t channel_from_process(Process *proc, uint64_t id)
{
  Channel *channel = register_channel(kChannelTypeProc, id, proc->events);
  incref(channel);  // process channels are only closed by the exit_cb
  channel->data.proc = proc;

  wstream_init(proc->in, 0);
  rstream_init(proc->out, 0);
  rstream_start(proc->out, parse_msgpack, channel);

  return channel->id;
}

/// Creates an API channel from a tcp/pipe socket connection
///
/// @param watcher The SocketWatcher ready to accept the connection
void channel_from_connection(SocketWatcher *watcher)
{
  Channel *channel = register_channel(kChannelTypeSocket, 0, NULL);
  socket_watcher_accept(watcher, &channel->data.stream);
  incref(channel);  // close channel only after the stream is closed
  channel->data.stream.internal_close_cb = close_cb;
  channel->data.stream.internal_data = channel;
  wstream_init(&channel->data.stream, 0);
  rstream_init(&channel->data.stream, CHANNEL_BUFFER_SIZE);
  rstream_start(&channel->data.stream, parse_msgpack, channel);
}

/// Sends event/arguments to channel
///
/// @param id The channel id. If 0, the event will be sent to all
///        channels that have subscribed to the event type
/// @param name The event name, an arbitrary string
/// @param args Array with event arguments
/// @return True if the event was sent successfully, false otherwise.
bool channel_send_event(uint64_t id, const char *name, Array args)
{
  Channel *channel = NULL;

  if (id && (!(channel = pmap_get(uint64_t)(channels, id))
            || channel->closed)) {
    api_free_array(args);
    return false;
  }

  if (channel) {
    if (channel->pending_requests) {
      // Pending request, queue the notification for later sending.
      const String method = cstr_as_string((char *)name);
      WBuffer *buffer = serialize_request(id, 0, method, args, &out_buffer, 1);
      kv_push(channel->delayed_notifications, buffer);
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
                         const char *method_name,
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
  ChannelCallFrame frame = { request_id, false, false, NIL };
  kv_push(channel->call_stack, &frame);
  channel->pending_requests++;
  LOOP_PROCESS_EVENTS_UNTIL(&main_loop, channel->events, -1, frame.returned);
  (void)kv_pop(channel->call_stack);
  channel->pending_requests--;

  if (frame.errored) {
    if (frame.result.type == kObjectTypeString) {
      api_set_error(err, Exception, "%s", frame.result.data.string.data);
    } else if (frame.result.type == kObjectTypeArray) {
      // Should be an error in the form [type, message]
      Array array = frame.result.data.array;
      if (array.size == 2 && array.items[0].type == kObjectTypeInteger
          && (array.items[0].data.integer == kErrorTypeException
              || array.items[0].data.integer == kErrorTypeValidation)
          && array.items[1].type == kObjectTypeString) {
        _api_set_error(err, (ErrorType)array.items[0].data.integer, "%s",
                       array.items[1].data.string.data);
      } else {
        api_set_error(err, Exception, "%s", "unknown error");
      }
    } else {
      api_set_error(err, Exception, "%s", "unknown error");
    }

    api_free_object(frame.result);
  }

  if (!channel->pending_requests) {
    send_delayed_notifications(channel);
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
void channel_from_stdio(void)
{
  Channel *channel = register_channel(kChannelTypeStdio, 0, NULL);
  incref(channel);  // stdio channels are only closed on exit
  // read stream
  rstream_init_fd(&main_loop, &channel->data.std.in, 0, CHANNEL_BUFFER_SIZE);
  rstream_start(&channel->data.std.in, parse_msgpack, channel);
  // write stream
  wstream_init_fd(&main_loop, &channel->data.std.out, 1, 0);
}

void channel_process_exit(uint64_t id, int status)
{
  Channel *channel = pmap_get(uint64_t)(channels, id);

  channel->closed = true;
  decref(channel);
}

static void parse_msgpack(Stream *stream, RBuffer *rbuf, size_t c, void *data,
    bool eof)
{
  Channel *channel = data;
  incref(channel);

  if (eof) {
    close_channel(channel);
    char buf[256];
    snprintf(buf, sizeof(buf), "ch %" PRIu64 " was closed by the client",
             channel->id);
    call_set_error(channel, buf);
    goto end;
  }

  size_t count = rbuffer_size(rbuf);
  DLOG("parsing %u bytes of msgpack data from Stream(%p)", count, stream);

  // Feed the unpacker with data
  msgpack_unpacker_reserve_buffer(channel->unpacker, count);
  rbuffer_read(rbuf, msgpack_unpacker_buffer(channel->unpacker), count);
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
        snprintf(buf, sizeof(buf),
                 "ch %" PRIu64 " returned a response with an unknown request "
                 "id. Ensure the client is properly synchronized",
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
               "ch %" PRIu64 " sent an invalid message, closed.",
               channel->id);
      call_set_error(channel, buf);
    }
    api_free_error(error);
    return;
  }

  // Retrieve the request handler
  MsgpackRpcRequestHandler handler;
  msgpack_object *method = msgpack_rpc_method(request);

  if (method) {
    handler = msgpack_rpc_get_handler_for(method->via.bin.ptr,
                                          method->via.bin.size);
  } else {
    handler.fn = msgpack_rpc_handle_missing_method;
    handler.async = true;
  }

  Array args = ARRAY_DICT_INIT;
  if (!msgpack_rpc_to_array(msgpack_rpc_args(request), &args)) {
    handler.fn = msgpack_rpc_handle_invalid_arguments;
    handler.async = true;
  }

  RequestEvent *event_data = xmalloc(sizeof(RequestEvent));
  event_data->channel = channel;
  event_data->handler = handler;
  event_data->args = args;
  event_data->request_id = request_id;
  incref(channel);
  if (handler.async) {
    on_request_event((void **)&event_data);
  } else {
    multiqueue_put(channel->events, on_request_event, 1, event_data);
  }
  api_free_error(error);
}

static void on_request_event(void **argv)
{
  RequestEvent *e = argv[0];
  Channel *channel = e->channel;
  MsgpackRpcRequestHandler handler = e->handler;
  Array args = e->args;
  uint64_t request_id = e->request_id;
  Error error = ERROR_INIT;
  Object result = handler.fn(channel->id, args, &error);
  if (request_id != NO_RESPONSE) {
    // send the response
    msgpack_packer response;
    msgpack_packer_init(&response, &out_buffer, msgpack_sbuffer_write);
    channel_write(channel, serialize_response(channel->id,
                                              request_id,
                                              &error,
                                              result,
                                              &out_buffer));
  } else {
    api_free_object(result);
  }
  api_free_array(args);
  decref(channel);
  xfree(e);
  api_free_error(error);
}

static bool channel_write(Channel *channel, WBuffer *buffer)
{
  bool success;

  if (channel->closed) {
    wstream_release_wbuffer(buffer);
    return false;
  }

  switch (channel->type) {
    case kChannelTypeSocket:
      success = wstream_write(&channel->data.stream, buffer);
      break;
    case kChannelTypeProc:
      success = wstream_write(channel->data.proc->in, buffer);
      break;
    case kChannelTypeStdio:
      success = wstream_write(&channel->data.std.out, buffer);
      break;
    default:
      abort();
  }

  if (!success) {
    // If the write failed for any reason, close the channel
    char buf[256];
    snprintf(buf,
             sizeof(buf),
             "Before returning from a RPC call, ch %" PRIu64 " was "
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
  api_free_error(e);
}

static void send_request(Channel *channel,
                         uint64_t id,
                         const char *name,
                         Array args)
{
  const String method = cstr_as_string((char *)name);
  channel_write(channel, serialize_request(channel->id,
                                           id,
                                           method,
                                           args,
                                           &out_buffer,
                                           1));
}

static void send_event(Channel *channel,
                       const char *name,
                       Array args)
{
  const String method = cstr_as_string((char *)name);
  channel_write(channel, serialize_request(channel->id,
                                           0,
                                           method,
                                           args,
                                           &out_buffer,
                                           1));
}

static void broadcast_event(const char *name, Array args)
{
  kvec_t(Channel *) subscribed = KV_INITIAL_VALUE;
  Channel *channel;

  map_foreach_value(channels, channel, {
    if (pmap_has(cstr_t)(channel->subscribed_events, name)) {
      kv_push(subscribed, channel);
    }
  });

  if (!kv_size(subscribed)) {
    api_free_array(args);
    goto end;
  }

  const String method = cstr_as_string((char *)name);
  WBuffer *buffer = serialize_request(0,
                                      0,
                                      method,
                                      args,
                                      &out_buffer,
                                      kv_size(subscribed));

  for (size_t i = 0; i < kv_size(subscribed); i++) {
    Channel *channel = kv_A(subscribed, i);
    if (channel->pending_requests) {
      kv_push(channel->delayed_notifications, buffer);
    } else {
      channel_write(channel, buffer);
    }
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
  xfree(event_string);
}

/// Close the channel streams/process and free the channel resources.
static void close_channel(Channel *channel)
{
  if (channel->closed) {
    return;
  }

  channel->closed = true;

  switch (channel->type) {
    case kChannelTypeSocket:
      stream_close(&channel->data.stream, NULL, NULL);
      break;
    case kChannelTypeProc:
      // Only close the rpc channel part,
      // there could be an error message on the stderr stream
      process_close_in(channel->data.proc);
      process_close_out(channel->data.proc);
      break;
    case kChannelTypeStdio:
      stream_close(&channel->data.std.in, NULL, NULL);
      stream_close(&channel->data.std.out, NULL, NULL);
      multiqueue_put(main_loop.fast_events, exit_event, 1, channel);
      return;
    default:
      abort();
  }

  decref(channel);
}

static void exit_event(void **argv)
{
  decref(argv[0]);

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
  kv_destroy(channel->delayed_notifications);
  if (channel->type != kChannelTypeProc) {
    multiqueue_free(channel->events);
  }
  xfree(channel);
}

static void close_cb(Stream *stream, void *data)
{
  decref(data);
}

static Channel *register_channel(ChannelType type, uint64_t id,
                                 MultiQueue *events)
{
  Channel *rv = xmalloc(sizeof(Channel));
  rv->events = events ? events : multiqueue_new_child(main_loop.events);
  rv->type = type;
  rv->refcount = 1;
  rv->closed = false;
  rv->unpacker = msgpack_unpacker_new(MSGPACK_UNPACKER_INIT_BUFFER_SIZE);
  rv->id = id > 0 ? id : next_chan_id++;
  rv->pending_requests = 0;
  rv->subscribed_events = pmap_new(cstr_t)();
  rv->next_request_id = 1;
  kv_init(rv->call_stack);
  kv_init(rv->delayed_notifications);
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
  ELOG("RPC: %s", msg);
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
                                  const String method,
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
                                   xfree);
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
                                   xfree);
  msgpack_sbuffer_clear(sbuffer);
  api_free_object(arg);
  return rv;
}

static void send_delayed_notifications(Channel* channel)
{
  for (size_t i = 0; i < kv_size(channel->delayed_notifications); i++) {
    WBuffer *buffer = kv_A(channel->delayed_notifications, i);
    channel_write(channel, buffer);
  }

  kv_size(channel->delayed_notifications) = 0;
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
#define REQ "[request]  "
#define RES "[response] "
#define NOT "[notify]   "
#define ERR "[error]    "

// Cannot define array with negative offsets, so this one is needed to be added
// to MSGPACK_UNPACK_\* values.
#define MUR_OFF 2

static const char *const msgpack_error_messages[] = {
  [MSGPACK_UNPACK_EXTRA_BYTES + MUR_OFF] = "extra bytes found",
  [MSGPACK_UNPACK_CONTINUE + MUR_OFF] = "incomplete string",
  [MSGPACK_UNPACK_PARSE_ERROR + MUR_OFF] = "parse error",
  [MSGPACK_UNPACK_NOMEM_ERROR + MUR_OFF] = "not enough memory",
};

static void log_server_msg(uint64_t channel_id,
                           msgpack_sbuffer *packed)
{
  msgpack_unpacked unpacked;
  msgpack_unpacked_init(&unpacked);
  DLOGN("RPC ->ch %" PRIu64 ": ", channel_id);
  const msgpack_unpack_return result =
      msgpack_unpack_next(&unpacked, packed->data, packed->size, NULL);
  switch (result) {
    case MSGPACK_UNPACK_SUCCESS: {
      uint64_t type = unpacked.data.via.array.ptr[0].via.u64;
      log_lock();
      FILE *f = open_log_file();
      fprintf(f, type ? (type == 1 ? RES : NOT) : REQ);
      log_msg_close(f, unpacked.data);
      msgpack_unpacked_destroy(&unpacked);
      break;
    }
    case MSGPACK_UNPACK_EXTRA_BYTES:
    case MSGPACK_UNPACK_CONTINUE:
    case MSGPACK_UNPACK_PARSE_ERROR:
    case MSGPACK_UNPACK_NOMEM_ERROR: {
      log_lock();
      FILE *f = open_log_file();
      fprintf(f, ERR);
      log_msg_close(f, (msgpack_object) {
          .type = MSGPACK_OBJECT_STR,
          .via.str = {
              .ptr = (char *)msgpack_error_messages[result + MUR_OFF],
              .size = (uint32_t)strlen(
                  msgpack_error_messages[result + MUR_OFF]),
          },
      });
      break;
    }
  }
}

static void log_client_msg(uint64_t channel_id,
                           bool is_request,
                           msgpack_object msg)
{
  DLOGN("RPC <-ch %" PRIu64 ": ", channel_id);
  log_lock();
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
  log_unlock();
}
#endif

