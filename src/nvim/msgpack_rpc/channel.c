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
#include "nvim/channel.h"
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
#include "nvim/os/input.h"

#if MIN_LOG_LEVEL > DEBUG_LOG_LEVEL
#define log_client_msg(...)
#define log_server_msg(...)
#endif

static PMap(cstr_t) *event_strings = NULL;
static msgpack_sbuffer out_buffer;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/channel.c.generated.h"
#endif

void rpc_init(void)
{
  ch_before_blocking_events = multiqueue_new_child(main_loop.events);
  event_strings = pmap_new(cstr_t)();
  msgpack_sbuffer_init(&out_buffer);
}


void rpc_start(Channel *channel)
{
  channel_incref(channel);
  channel->is_rpc = true;
  RpcState *rpc = &channel->rpc;
  rpc->closed = false;
  rpc->unpacker = msgpack_unpacker_new(MSGPACK_UNPACKER_INIT_BUFFER_SIZE);
  rpc->subscribed_events = pmap_new(cstr_t)();
  rpc->next_request_id = 1;
  rpc->info = (Dictionary)ARRAY_DICT_INIT;
  kv_init(rpc->call_stack);

  if (channel->streamtype != kChannelStreamInternal) {
    Stream *out = channel_outstream(channel);
#if MIN_LOG_LEVEL <= DEBUG_LOG_LEVEL
    Stream *in = channel_instream(channel);
    DLOG("rpc ch %" PRIu64 " in-stream=%p out-stream=%p", channel->id, in, out);
#endif

    rstream_start(out, receive_msgpack, channel);
  }
}


static Channel *find_rpc_channel(uint64_t id)
{
  Channel *chan = find_channel(id);
  if (!chan || !chan->is_rpc || chan->rpc.closed) {
    return NULL;
  }
  return chan;
}

/// Publishes an event to a channel.
///
/// @param id Channel id. 0 means "broadcast to all subscribed channels"
/// @param name Event name (application-defined)
/// @param args Array of event arguments
/// @return True if the event was sent successfully, false otherwise.
bool rpc_send_event(uint64_t id, const char *name, Array args)
{
  Channel *channel = NULL;

  if (id && (!(channel = find_rpc_channel(id)))) {
    api_free_array(args);
    return false;
  }

  if (channel) {
    send_event(channel, name, args);
  }  else {
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
Object rpc_send_call(uint64_t id,
                     const char *method_name,
                     Array args,
                     Error *err)
{
  Channel *channel = NULL;

  if (!(channel = find_rpc_channel(id))) {
    api_set_error(err, kErrorTypeException, "Invalid channel: %" PRIu64, id);
    api_free_array(args);
    return NIL;
  }

  channel_incref(channel);
  RpcState *rpc = &channel->rpc;
  uint64_t request_id = rpc->next_request_id++;
  // Send the msgpack-rpc request
  send_request(channel, request_id, method_name, args);

  // Push the frame
  ChannelCallFrame frame = { request_id, false, false, NIL };
  kv_push(rpc->call_stack, &frame);
  LOOP_PROCESS_EVENTS_UNTIL(&main_loop, channel->events, -1, frame.returned);
  (void)kv_pop(rpc->call_stack);

  if (frame.errored) {
    if (frame.result.type == kObjectTypeString) {
      api_set_error(err, kErrorTypeException, "%s",
                    frame.result.data.string.data);
    } else if (frame.result.type == kObjectTypeArray) {
      // Should be an error in the form [type, message]
      Array array = frame.result.data.array;
      if (array.size == 2 && array.items[0].type == kObjectTypeInteger
          && (array.items[0].data.integer == kErrorTypeException
              || array.items[0].data.integer == kErrorTypeValidation)
          && array.items[1].type == kObjectTypeString) {
        api_set_error(err, (ErrorType)array.items[0].data.integer, "%s",
                      array.items[1].data.string.data);
      } else {
        api_set_error(err, kErrorTypeException, "%s", "unknown error");
      }
    } else {
      api_set_error(err, kErrorTypeException, "%s", "unknown error");
    }

    api_free_object(frame.result);
  }

  channel_decref(channel);

  return frame.errored ? NIL : frame.result;
}

/// Subscribes to event broadcasts
///
/// @param id The channel id
/// @param event The event type string
void rpc_subscribe(uint64_t id, char *event)
{
  Channel *channel;

  if (!(channel = find_rpc_channel(id))) {
    abort();
  }

  char *event_string = pmap_get(cstr_t)(event_strings, event);

  if (!event_string) {
    event_string = xstrdup(event);
    pmap_put(cstr_t)(event_strings, event_string, event_string);
  }

  pmap_put(cstr_t)(channel->rpc.subscribed_events, event_string, event_string);
}

/// Unsubscribes to event broadcasts
///
/// @param id The channel id
/// @param event The event type string
void rpc_unsubscribe(uint64_t id, char *event)
{
  Channel *channel;

  if (!(channel = find_rpc_channel(id))) {
    abort();
  }

  unsubscribe(channel, event);
}

static void receive_msgpack(Stream *stream, RBuffer *rbuf, size_t c,
                            void *data, bool eof)
{
  Channel *channel = data;
  channel_incref(channel);

  if (eof) {
    channel_close(channel->id, kChannelPartRpc, NULL);
    char buf[256];
    snprintf(buf, sizeof(buf), "ch %" PRIu64 " was closed by the client",
             channel->id);
    call_set_error(channel, buf, WARN_LOG_LEVEL);
    goto end;
  }

  size_t count = rbuffer_size(rbuf);
  DLOG("ch %" PRIu64 ": parsing %zu bytes from msgpack Stream: %p",
       channel->id, count, stream);

  // Feed the unpacker with data
  msgpack_unpacker_reserve_buffer(channel->rpc.unpacker, count);
  rbuffer_read(rbuf, msgpack_unpacker_buffer(channel->rpc.unpacker), count);
  msgpack_unpacker_buffer_consumed(channel->rpc.unpacker, count);

  parse_msgpack(channel);

end:
  channel_decref(channel);
}

static void parse_msgpack(Channel *channel)
{
  msgpack_unpacked unpacked;
  msgpack_unpacked_init(&unpacked);
  msgpack_unpack_return result;

  // Deserialize everything we can.
  while ((result = msgpack_unpacker_next(channel->rpc.unpacker, &unpacked)) ==
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
        call_set_error(channel, buf, ERROR_LOG_LEVEL);
      }
      msgpack_unpacked_destroy(&unpacked);
      // Bail out from this event loop iteration
      return;
    }

    handle_request(channel, &unpacked.data);
  }

  if (result == MSGPACK_UNPACK_NOMEM_ERROR) {
    mch_errmsg(e_outofmem);
    mch_errmsg("\n");
    channel_decref(channel);
    preserve_exit();
  }

  if (result == MSGPACK_UNPACK_PARSE_ERROR) {
    // See src/msgpack/unpack_template.h in msgpack source tree for
    // causes for this error(search for 'goto _failed')
    //
    // A not so uncommon cause for this might be deserializing objects with
    // a high nesting level: msgpack will break when its internal parse stack
    // size exceeds MSGPACK_EMBED_STACK_SIZE (defined as 32 by default)
    send_error(channel, 0, "Invalid msgpack payload. "
                           "This error can also happen when deserializing "
                           "an object with high level of nesting");
  }
}


static void handle_request(Channel *channel, msgpack_object *request)
  FUNC_ATTR_NONNULL_ALL
{
  uint64_t request_id;
  Error error = ERROR_INIT;
  msgpack_rpc_validate(&request_id, request, &error);

  if (ERROR_SET(&error)) {
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
      call_set_error(channel, buf, ERROR_LOG_LEVEL);
    }
    api_clear_error(&error);
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

  RequestEvent *evdata = xmalloc(sizeof(RequestEvent));
  evdata->channel = channel;
  evdata->handler = handler;
  evdata->args = args;
  evdata->request_id = request_id;
  channel_incref(channel);
  if (handler.async) {
    bool is_get_mode = handler.fn == handle_nvim_get_mode;

    if (is_get_mode && !input_blocking()) {
      // Defer the event to a special queue used by os/input.c. #6247
      multiqueue_put(ch_before_blocking_events, on_request_event, 1, evdata);
    } else {
      // Invoke immediately.
      on_request_event((void **)&evdata);
    }
  } else {
    multiqueue_put(channel->events, on_request_event, 1, evdata);
  }
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
  channel_decref(channel);
  xfree(e);
  api_clear_error(&error);
}

static bool channel_write(Channel *channel, WBuffer *buffer)
{
  bool success;

  if (channel->rpc.closed) {
    wstream_release_wbuffer(buffer);
    return false;
  }

  if (channel->streamtype == kChannelStreamInternal) {
    channel_incref(channel);
    CREATE_EVENT(channel->events, internal_read_event, 2, channel, buffer);
    success = true;
  } else {
    Stream *in = channel_instream(channel);
    success = wstream_write(in, buffer);
  }


  if (!success) {
    // If the write failed for any reason, close the channel
    char buf[256];
    snprintf(buf,
             sizeof(buf),
             "ch %" PRIu64 ": stream write failed. "
             "RPC canceled; closing channel",
             channel->id);
    call_set_error(channel, buf, ERROR_LOG_LEVEL);
  }

  return success;
}

static void internal_read_event(void **argv)
{
  Channel *channel = argv[0];
  WBuffer *buffer = argv[1];

  msgpack_unpacker_reserve_buffer(channel->rpc.unpacker, buffer->size);
  memcpy(msgpack_unpacker_buffer(channel->rpc.unpacker),
         buffer->data, buffer->size);
  msgpack_unpacker_buffer_consumed(channel->rpc.unpacker, buffer->size);

  parse_msgpack(channel);

  channel_decref(channel);
  wstream_release_wbuffer(buffer);
}

static void send_error(Channel *channel, uint64_t id, char *err)
{
  Error e = ERROR_INIT;
  api_set_error(&e, kErrorTypeException, "%s", err);
  channel_write(channel, serialize_response(channel->id,
                                            id,
                                            &e,
                                            NIL,
                                            &out_buffer));
  api_clear_error(&e);
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
    if (channel->is_rpc
        && pmap_has(cstr_t)(channel->rpc.subscribed_events, name)) {
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
    channel_write(channel, buffer);
  }

end:
  kv_destroy(subscribed);
}

static void unsubscribe(Channel *channel, char *event)
{
  char *event_string = pmap_get(cstr_t)(event_strings, event);
  pmap_del(cstr_t)(channel->rpc.subscribed_events, event_string);

  map_foreach_value(channels, channel, {
    if (channel->is_rpc
        && pmap_has(cstr_t)(channel->rpc.subscribed_events, event_string)) {
      return;
    }
  });

  // Since the string is no longer used by other channels, release it's memory
  pmap_del(cstr_t)(event_strings, event_string);
  xfree(event_string);
}


/// Mark rpc state as closed, and release its reference to the channel.
/// Don't call this directly, call channel_close(id, kChannelPartRpc, &error)
void rpc_close(Channel *channel)
{
  if (channel->rpc.closed) {
    return;
  }

  channel->rpc.closed = true;
  channel_decref(channel);

  if (channel->streamtype == kChannelStreamStdio) {
    multiqueue_put(main_loop.fast_events, exit_event, 0);
  }
}

static void exit_event(void **argv)
{
  if (!exiting) {
    mch_exit(0);
  }
}

void rpc_free(Channel *channel)
{
  remote_ui_disconnect(channel->id);
  msgpack_unpacker_free(channel->rpc.unpacker);

  // Unsubscribe from all events
  char *event_string;
  map_foreach_value(channel->rpc.subscribed_events, event_string, {
    unsubscribe(channel, event_string);
  });

  pmap_free(cstr_t)(channel->rpc.subscribed_events);
  kv_destroy(channel->rpc.call_stack);
  api_free_dictionary(channel->rpc.info);
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
  if (kv_size(channel->rpc.call_stack) == 0) {
    return false;
  }

  // Must be equal to the frame at the stack's bottom
  ChannelCallFrame *frame = kv_last(channel->rpc.call_stack);
  return response_id == frame->request_id;
}

static void complete_call(msgpack_object *obj, Channel *channel)
{
  ChannelCallFrame *frame = kv_last(channel->rpc.call_stack);
  frame->returned = true;
  frame->errored = obj->via.array.ptr[2].type != MSGPACK_OBJECT_NIL;

  if (frame->errored) {
    msgpack_rpc_to_object(&obj->via.array.ptr[2], &frame->result);
  } else {
    msgpack_rpc_to_object(&obj->via.array.ptr[3], &frame->result);
  }
}

static void call_set_error(Channel *channel, char *msg, int loglevel)
{
  LOG(loglevel, "RPC: %s", msg);
  for (size_t i = 0; i < kv_size(channel->rpc.call_stack); i++) {
    ChannelCallFrame *frame = kv_A(channel->rpc.call_stack, i);
    frame->returned = true;
    frame->errored = true;
    api_free_object(frame->result);
    frame->result = STRING_OBJ(cstr_to_string(msg));
  }

  channel_close(channel->id, kChannelPartRpc, NULL);
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

void rpc_set_client_info(uint64_t id, Dictionary info)
{
  Channel *chan = find_rpc_channel(id);
  if (!chan) {
    abort();
  }

  api_free_dictionary(chan->rpc.info);
  chan->rpc.info = info;
  channel_info_changed(chan, false);
}

Dictionary rpc_client_info(Channel *chan)
{
  return copy_dictionary(chan->rpc.info);
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

