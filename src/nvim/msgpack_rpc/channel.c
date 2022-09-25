// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <inttypes.h>
#include <msgpack.h>
#include <stdbool.h>
#include <string.h>
#include <uv.h>

#include "klib/kvec.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/ui.h"
#include "nvim/api/vim.h"
#include "nvim/ascii.h"
#include "nvim/channel.h"
#include "nvim/eval.h"
#include "nvim/event/libuv_process.h"
#include "nvim/event/loop.h"
#include "nvim/event/rstream.h"
#include "nvim/event/socket.h"
#include "nvim/event/wstream.h"
#include "nvim/log.h"
#include "nvim/main.h"
#include "nvim/map.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/msgpack_rpc/unpacker.h"
#include "nvim/os/input.h"
#include "nvim/os_unix.h"
#include "nvim/ui.h"
#include "nvim/vim.h"

#if MIN_LOG_LEVEL > LOGLVL_DBG
# define log_client_msg(...)
# define log_server_msg(...)
#endif

static PMap(cstr_t) event_strings = MAP_INIT;
static msgpack_sbuffer out_buffer;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/channel.c.generated.h"
#endif

void rpc_init(void)
{
  ch_before_blocking_events = multiqueue_new_child(main_loop.events);
  msgpack_sbuffer_init(&out_buffer);
}

void rpc_start(Channel *channel)
{
  channel_incref(channel);
  channel->is_rpc = true;
  RpcState *rpc = &channel->rpc;
  rpc->closed = false;
  rpc->unpacker = xcalloc(1, sizeof *rpc->unpacker);
  unpacker_init(rpc->unpacker);
  rpc->next_request_id = 1;
  rpc->info = (Dictionary)ARRAY_DICT_INIT;
  kv_init(rpc->call_stack);

  if (channel->streamtype != kChannelStreamInternal) {
    Stream *out = channel_outstream(channel);
#if MIN_LOG_LEVEL <= LOGLVL_DBG
    Stream *in = channel_instream(channel);
    DLOG("rpc ch %" PRIu64 " in-stream=%p out-stream=%p", channel->id,
         (void *)in, (void *)out);
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
Object rpc_send_call(uint64_t id, const char *method_name, Array args, ArenaMem *result_mem,
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
  uint32_t request_id = rpc->next_request_id++;
  // Send the msgpack-rpc request
  send_request(channel, request_id, method_name, args);

  // Push the frame
  ChannelCallFrame frame = { request_id, false, false, NIL, NULL };
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

    // frame.result was allocated in an arena
    arena_mem_free(frame.result_mem);
    frame.result_mem = NULL;
  }

  channel_decref(channel);

  *result_mem = frame.result_mem;

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

  char *event_string = pmap_get(cstr_t)(&event_strings, event);

  if (!event_string) {
    event_string = xstrdup(event);
    pmap_put(cstr_t)(&event_strings, event_string, event_string);
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

static void receive_msgpack(Stream *stream, RBuffer *rbuf, size_t c, void *data, bool eof)
{
  Channel *channel = data;
  channel_incref(channel);

  if (eof) {
    channel_close(channel->id, kChannelPartRpc, NULL);
    char buf[256];
    snprintf(buf, sizeof(buf), "ch %" PRIu64 " was closed by the client",
             channel->id);
    chan_close_with_error(channel, buf, LOGLVL_INF);
    goto end;
  }

  DLOG("ch %" PRIu64 ": parsing %zu bytes from msgpack Stream: %p",
       channel->id, rbuffer_size(rbuf), (void *)stream);

  Unpacker *p = channel->rpc.unpacker;
  size_t size = 0;
  p->read_ptr = rbuffer_read_ptr(rbuf, &size);
  p->read_size = size;
  parse_msgpack(channel);
  size_t consumed = size - p->read_size;
  rbuffer_consumed_compact(rbuf, consumed);

end:
  channel_decref(channel);
}

static void parse_msgpack(Channel *channel)
{
  Unpacker *p = channel->rpc.unpacker;
  while (unpacker_advance(p)) {
    if (p->type == kMessageTypeRedrawEvent) {
      if (p->grid_line_event) {
        ui_client_event_raw_line(p->grid_line_event);
      } else if (p->ui_handler.fn != NULL && p->result.type == kObjectTypeArray) {
        p->ui_handler.fn(p->result.data.array);
        arena_mem_free(arena_finish(&p->arena));
      }
    } else if (p->type == kMessageTypeResponse) {
      ChannelCallFrame *frame = kv_last(channel->rpc.call_stack);
      if (p->request_id != frame->request_id) {
        char buf[256];
        snprintf(buf, sizeof(buf),
                 "ch %" PRIu64 " returned a response with an unknown request "
                 "id. Ensure the client is properly synchronized",
                 channel->id);
        chan_close_with_error(channel, buf, LOGLVL_ERR);
      }
      frame->returned = true;
      frame->errored = (p->error.type != kObjectTypeNil);

      if (frame->errored) {
        frame->result = p->error;
        // TODO(bfredl): p->result should not even be decoded
        // api_free_object(p->result);
      } else {
        frame->result = p->result;
      }
      frame->result_mem = arena_finish(&p->arena);
    } else {
      log_client_msg(channel->id, p->type == kMessageTypeRequest, p->handler.name);

      Object res = p->result;
      if (p->result.type != kObjectTypeArray) {
        chan_close_with_error(channel, "msgpack-rpc request args has to be an array", LOGLVL_ERR);
        return;
      }
      Array arg = res.data.array;
      handle_request(channel, p, arg);
    }
  }

  if (unpacker_closed(p)) {
    chan_close_with_error(channel, p->unpack_error.msg, LOGLVL_ERR);
    api_clear_error(&p->unpack_error);
  }
}

/// Handles requests and notifications received on the channel.
static void handle_request(Channel *channel, Unpacker *p, Array args)
  FUNC_ATTR_NONNULL_ALL
{
  assert(p->type == kMessageTypeRequest || p->type == kMessageTypeNotification);

  if (!p->handler.fn) {
    send_error(channel, p->type, p->request_id, p->unpack_error.msg);
    api_clear_error(&p->unpack_error);
    arena_mem_free(arena_finish(&p->arena));
    return;
  }

  RequestEvent *evdata = xmalloc(sizeof(RequestEvent));
  evdata->type = p->type;
  evdata->channel = channel;
  evdata->handler = p->handler;
  evdata->args = args;
  evdata->used_mem = p->arena;
  p->arena = (Arena)ARENA_EMPTY;
  evdata->request_id = p->request_id;
  channel_incref(channel);
  if (p->handler.fast) {
    bool is_get_mode = p->handler.fn == handle_nvim_get_mode;

    if (is_get_mode && !input_blocking()) {
      // Defer the event to a special queue used by os/input.c. #6247
      multiqueue_put(ch_before_blocking_events, request_event, 1, evdata);
    } else {
      // Invoke immediately.
      request_event((void **)&evdata);
    }
  } else {
    bool is_resize = p->handler.fn == handle_nvim_ui_try_resize;
    if (is_resize) {
      Event ev = event_create_oneshot(event_create(request_event, 1, evdata),
                                      2);
      multiqueue_put_event(channel->events, ev);
      multiqueue_put_event(resize_events, ev);
    } else {
      multiqueue_put(channel->events, request_event, 1, evdata);
      DLOG("RPC: scheduled %.*s", (int)p->method_name_len, p->handler.name);
    }
  }
}

/// Handles a message, depending on the type:
///   - Request: invokes method and writes the response (or error).
///   - Notification: invokes method (emits `nvim_error_event` on error).
static void request_event(void **argv)
{
  RequestEvent *e = argv[0];
  Channel *channel = e->channel;
  MsgpackRpcRequestHandler handler = e->handler;
  Error error = ERROR_INIT;
  if (channel->rpc.closed) {
    // channel was closed, abort any pending requests
    goto free_ret;
  }

  Object result = handler.fn(channel->id, e->args, &e->used_mem, &error);
  if (e->type == kMessageTypeRequest || ERROR_SET(&error)) {
    // Send the response.
    msgpack_packer response;
    msgpack_packer_init(&response, &out_buffer, msgpack_sbuffer_write);
    channel_write(channel, serialize_response(channel->id,
                                              e->type,
                                              e->request_id,
                                              &error,
                                              result,
                                              &out_buffer));
  }
  if (!handler.arena_return) {
    api_free_object(result);
  }

free_ret:
  // e->args (and possibly result) are allocated in an arena
  arena_mem_free(arena_finish(&e->used_mem));
  channel_decref(channel);
  xfree(e);
  api_clear_error(&error);
}

bool rpc_write_raw(uint64_t id, WBuffer *buffer)
{
  Channel *channel = find_rpc_channel(id);
  if (!channel) {
    wstream_release_wbuffer(buffer);
    return false;
  }

  return channel_write(channel, buffer);
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
    chan_close_with_error(channel, buf, LOGLVL_ERR);
  }

  return success;
}

static void internal_read_event(void **argv)
{
  Channel *channel = argv[0];
  WBuffer *buffer = argv[1];
  Unpacker *p = channel->rpc.unpacker;

  p->read_ptr = buffer->data;
  p->read_size = buffer->size;
  parse_msgpack(channel);

  if (p->read_size) {
    // This should not happen, as WBuffer is one single serialized message.
    if (!channel->rpc.closed) {
      chan_close_with_error(channel, "internal channel: internal error", LOGLVL_ERR);
    }
  }

  channel_decref(channel);
  wstream_release_wbuffer(buffer);
}

static void send_error(Channel *chan, MessageType type, uint32_t id, char *err)
{
  Error e = ERROR_INIT;
  api_set_error(&e, kErrorTypeException, "%s", err);
  channel_write(chan, serialize_response(chan->id,
                                         type,
                                         id,
                                         &e,
                                         NIL,
                                         &out_buffer));
  api_clear_error(&e);
}

static void send_request(Channel *channel, uint32_t id, const char *name, Array args)
{
  const String method = cstr_as_string((char *)name);
  channel_write(channel, serialize_request(channel->id,
                                           id,
                                           method,
                                           args,
                                           &out_buffer,
                                           1));
}

static void send_event(Channel *channel, const char *name, Array args)
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

  map_foreach_value(&channels, channel, {
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
    Channel *c = kv_A(subscribed, i);
    channel_write(c, buffer);
  }

end:
  kv_destroy(subscribed);
}

static void unsubscribe(Channel *channel, char *event)
{
  char *event_string = pmap_get(cstr_t)(&event_strings, event);
  if (!event_string) {
    WLOG("RPC: ch %" PRIu64 ": tried to unsubscribe unknown event '%s'",
         channel->id, event);
    return;
  }
  pmap_del(cstr_t)(channel->rpc.subscribed_events, event_string);

  map_foreach_value(&channels, channel, {
    if (channel->is_rpc
        && pmap_has(cstr_t)(channel->rpc.subscribed_events, event_string)) {
      return;
    }
  });

  // Since the string is no longer used by other channels, release it's memory
  pmap_del(cstr_t)(&event_strings, event_string);
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

  if (channel->streamtype == kChannelStreamStdio
      || channel->id == ui_client_channel_id) {
    multiqueue_put(main_loop.fast_events, exit_event, 0);
  }
}

static void exit_delay_cb(uv_timer_t *handle)
{
  uv_timer_stop(&main_loop.exit_delay_timer);
  multiqueue_put(main_loop.fast_events, exit_event, 0);
}

static void exit_event(void **argv)
{
  if (exit_need_delay) {
    uv_timer_start(&main_loop.exit_delay_timer, exit_delay_cb, 0, 0);
    return;
  }

  if (!exiting) {
    os_exit(0);
  }
}

void rpc_free(Channel *channel)
{
  remote_ui_disconnect(channel->id);
  unpacker_teardown(channel->rpc.unpacker);
  xfree(channel->rpc.unpacker);

  // Unsubscribe from all events
  char *event_string;
  map_foreach_value(channel->rpc.subscribed_events, event_string, {
    unsubscribe(channel, event_string);
  });

  pmap_destroy(cstr_t)(channel->rpc.subscribed_events);
  kv_destroy(channel->rpc.call_stack);
  api_free_dictionary(channel->rpc.info);
}

static void chan_close_with_error(Channel *channel, char *msg, int loglevel)
{
  LOG(loglevel, "RPC: %s", msg);
  for (size_t i = 0; i < kv_size(channel->rpc.call_stack); i++) {
    ChannelCallFrame *frame = kv_A(channel->rpc.call_stack, i);
    frame->returned = true;
    frame->errored = true;
    frame->result = STRING_OBJ(cstr_to_string(msg));
  }

  channel_close(channel->id, kChannelPartRpc, NULL);
}

static WBuffer *serialize_request(uint64_t channel_id, uint32_t request_id, const String method,
                                  Array args, msgpack_sbuffer *sbuffer, size_t refcount)
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

static WBuffer *serialize_response(uint64_t channel_id, MessageType type, uint32_t response_id,
                                   Error *err, Object arg, msgpack_sbuffer *sbuffer)
{
  msgpack_packer pac;
  msgpack_packer_init(&pac, sbuffer, msgpack_sbuffer_write);
  if (ERROR_SET(err) && type == kMessageTypeNotification) {
    Array args = ARRAY_DICT_INIT;
    ADD(args, INTEGER_OBJ(err->type));
    ADD(args, STRING_OBJ(cstr_to_string(err->msg)));
    msgpack_rpc_serialize_request(0, cstr_as_string("nvim_error_event"),
                                  args, &pac);
    api_free_array(args);
  } else {
    msgpack_rpc_serialize_response(response_id, err, arg, &pac);
  }
  log_server_msg(channel_id, sbuffer);
  WBuffer *rv = wstream_new_buffer(xmemdup(sbuffer->data, sbuffer->size),
                                   sbuffer->size,
                                   1,  // responses only go though 1 channel
                                   xfree);
  msgpack_sbuffer_clear(sbuffer);
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
  return copy_dictionary(chan->rpc.info, NULL);
}

const char *rpc_client_name(Channel *chan)
{
  if (!chan->is_rpc) {
    return NULL;
  }
  Dictionary info = chan->rpc.info;
  for (size_t i = 0; i < info.size; i++) {
    if (strequal("name", info.items[i].key.data)
        && info.items[i].value.type == kObjectTypeString) {
      return info.items[i].value.data.string.data;
    }
  }

  return NULL;
}

#if MIN_LOG_LEVEL <= LOGLVL_DBG
# define REQ "[request]  "
# define RES "[response] "
# define NOT "[notify]   "
# define ERR "[error]    "

// Cannot define array with negative offsets, so this one is needed to be added
// to MSGPACK_UNPACK_\* values.
# define MUR_OFF 2

static const char *const msgpack_error_messages[] = {
  [MSGPACK_UNPACK_EXTRA_BYTES + MUR_OFF] = "extra bytes found",
  [MSGPACK_UNPACK_CONTINUE + MUR_OFF] = "incomplete string",
  [MSGPACK_UNPACK_PARSE_ERROR + MUR_OFF] = "parse error",
  [MSGPACK_UNPACK_NOMEM_ERROR + MUR_OFF] = "not enough memory",
};

static void log_server_msg(uint64_t channel_id, msgpack_sbuffer *packed)
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
    msgpack_object_print(f, unpacked.data);
    log_close(f);
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
    fprintf(f, "%s", msgpack_error_messages[result + MUR_OFF]);
    log_close(f);
    break;
  }
  }
}

static void log_client_msg(uint64_t channel_id, bool is_request, const char *name)
{
  DLOGN("RPC <-ch %" PRIu64 ": ", channel_id);
  log_lock();
  FILE *f = open_log_file();
  fprintf(f, "%s: %s", is_request ? REQ : RES, name);
  log_close(f);
}

static void log_close(FILE *f)
{
  fputc('\n', f);
  fflush(f);
  fclose(f);
  log_unlock();
}
#endif
