#include <assert.h>
#include <inttypes.h>
#include <msgpack/object.h>
#include <msgpack/sbuffer.h>
#include <msgpack/unpack.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/ui.h"
#include "nvim/channel.h"
#include "nvim/channel_defs.h"
#include "nvim/event/defs.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/event/process.h"
#include "nvim/event/rstream.h"
#include "nvim/event/wstream.h"
#include "nvim/globals.h"
#include "nvim/log.h"
#include "nvim/main.h"
#include "nvim/map_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/msgpack_rpc/channel_defs.h"
#include "nvim/msgpack_rpc/packer.h"
#include "nvim/msgpack_rpc/unpacker.h"
#include "nvim/os/input.h"
#include "nvim/rbuffer.h"
#include "nvim/rbuffer_defs.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_client.h"

#ifdef NVIM_LOG_DEBUG
# define REQ "[request]  "
# define RES "[response] "
# define NOT "[notify]   "
# define ERR "[error]    "

# define SEND "->"
# define RECV "<-"

static void log_request(char *dir, uint64_t channel_id, uint32_t req_id, const char *name)
{
  DLOGN("RPC %s %" PRIu64 ": %s id=%u: %s\n", dir, channel_id, REQ, req_id, name);
}

static void log_response(char *dir, uint64_t channel_id, char *kind, uint32_t req_id)
{
  DLOGN("RPC %s %" PRIu64 ": %s id=%u\n", dir, channel_id, kind, req_id);
}

static void log_notify(char *dir, uint64_t channel_id, const char *name)
{
  DLOGN("RPC %s %" PRIu64 ": %s %s\n", dir, channel_id, NOT, name);
}

#else
# define log_request(...)
# define log_response(...)
# define log_notify(...)
#endif

static Set(cstr_t) event_strings = SET_INIT;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/channel.c.generated.h"
#endif

void rpc_init(void)
{
  ch_before_blocking_events = multiqueue_new_child(main_loop.events);
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
#ifdef NVIM_LOG_DEBUG
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
    return false;
  }

  log_notify(SEND, channel ? channel->id : 0, name);
  if (channel) {
    serialize_request(&channel, 1, 0, name, args);
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
    return NIL;
  }

  channel_incref(channel);
  RpcState *rpc = &channel->rpc;
  uint32_t request_id = rpc->next_request_id++;
  // Send the msgpack-rpc request
  serialize_request(&channel, 1, request_id, method_name, args);

  log_request(SEND, channel->id, request_id, method_name);

  // Push the frame
  ChannelCallFrame frame = { request_id, false, false, NIL, NULL };
  kv_push(rpc->call_stack, &frame);
  LOOP_PROCESS_EVENTS_UNTIL(&main_loop, channel->events, -1, frame.returned || rpc->closed);
  (void)kv_pop(rpc->call_stack);

  if (rpc->closed) {
    api_set_error(err, kErrorTypeException, "Invalid channel: %" PRIu64, id);
    channel_decref(channel);
    return NIL;
  }

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

  const char **key_alloc = NULL;
  if (set_put_ref(cstr_t, &event_strings, event, &key_alloc)) {
    *key_alloc = xstrdup(event);
  }

  set_put(cstr_t, channel->rpc.subscribed_events, *key_alloc);
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

  if (!unpacker_closed(p)) {
    size_t consumed = size - p->read_size;
    rbuffer_consumed_compact(rbuf, consumed);
  }

end:
  channel_decref(channel);
}

static ChannelCallFrame *find_call_frame(RpcState *rpc, uint32_t request_id)
{
  for (size_t i = 0; i < kv_size(rpc->call_stack); i++) {
    ChannelCallFrame *frame = kv_Z(rpc->call_stack, i);
    if (frame->request_id == request_id) {
      return frame;
    }
  }
  return NULL;
}

static void parse_msgpack(Channel *channel)
{
  Unpacker *p = channel->rpc.unpacker;
  while (unpacker_advance(p)) {
    if (p->type == kMessageTypeRedrawEvent) {
      // When exiting, ui_client_stop() has already been called, so don't handle UI events.
      if (ui_client_channel_id && !exiting) {
        if (p->grid_line_event) {
          ui_client_event_raw_line(p->grid_line_event);
        } else if (p->ui_handler.fn != NULL && p->result.type == kObjectTypeArray) {
          p->ui_handler.fn(p->result.data.array);
        }
      }
      arena_mem_free(arena_finish(&p->arena));
    } else if (p->type == kMessageTypeResponse) {
      ChannelCallFrame *frame = channel->rpc.client_type == kClientTypeMsgpackRpc
                                ? find_call_frame(&channel->rpc, p->request_id)
                                : kv_last(channel->rpc.call_stack);
      if (frame == NULL || p->request_id != frame->request_id) {
        char buf[256];
        snprintf(buf, sizeof(buf),
                 "ch %" PRIu64 " (type=%" PRIu32 ") returned a response with an unknown request "
                 "id %" PRIu32 ". Ensure the client is properly synchronized",
                 channel->id, (unsigned)channel->rpc.client_type, p->request_id);
        chan_close_with_error(channel, buf, LOGLVL_ERR);
        return;
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
      log_response(RECV, channel->id, frame->errored ? ERR : RES, p->request_id);
    } else {
      if (p->type == kMessageTypeNotification) {
        log_notify(RECV, channel->id, p->handler.name);
      } else {
        log_request(RECV, channel->id, p->request_id, p->handler.name);
      }

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
    send_error(channel, p->handler, p->type, p->request_id, p->unpack_error.msg);
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
      multiqueue_put(ch_before_blocking_events, request_event, evdata);
    } else {
      // Invoke immediately.
      request_event((void **)&evdata);
    }
  } else {
    bool is_resize = p->handler.fn == handle_nvim_ui_try_resize;
    if (is_resize) {
      Event ev = event_create_oneshot(event_create(request_event, evdata), 2);
      multiqueue_put_event(channel->events, ev);
      multiqueue_put_event(resize_events, ev);
    } else {
      multiqueue_put(channel->events, request_event, evdata);
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
    serialize_response(channel, e->handler, e->type, e->request_id, &error, &result);
  }
  if (handler.ret_alloc) {
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
    CREATE_EVENT(channel->events, internal_read_event, channel, buffer);
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

static void send_error(Channel *chan, MsgpackRpcRequestHandler handler, MessageType type,
                       uint32_t id, char *err)
{
  Error e = ERROR_INIT;
  api_set_error(&e, kErrorTypeException, "%s", err);
  serialize_response(chan, handler, type, id, &e, &NIL);
  api_clear_error(&e);
}

static void broadcast_event(const char *name, Array args)
{
  kvec_withinit_t(Channel *, 4) subscribed = KV_INITIAL_VALUE;
  kvi_init(subscribed);
  Channel *channel;

  map_foreach_value(&channels, channel, {
    if (channel->is_rpc
        && set_has(cstr_t, channel->rpc.subscribed_events, name)) {
      kv_push(subscribed, channel);
    }
  });

  if (kv_size(subscribed)) {
    serialize_request(subscribed.items, kv_size(subscribed), 0, name, args);
  }

  kvi_destroy(subscribed);
}

static void unsubscribe(Channel *channel, char *event)
{
  if (!set_has(cstr_t, &event_strings, event)) {
    WLOG("RPC: ch %" PRIu64 ": tried to unsubscribe unknown event '%s'",
         channel->id, event);
    return;
  }
  set_del(cstr_t, channel->rpc.subscribed_events, event);
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
      || (channel->id == ui_client_channel_id && channel->streamtype != kChannelStreamProc)) {
    if (channel->streamtype == kChannelStreamStdio) {
      // Avoid hanging when there are no other UIs and a prompt is triggered on exit.
      remote_ui_disconnect(channel->id);
    }
    exit_from_channel(0);
  }
}

void rpc_free(Channel *channel)
{
  remote_ui_disconnect(channel->id);
  unpacker_teardown(channel->rpc.unpacker);
  xfree(channel->rpc.unpacker);

  set_destroy(cstr_t, channel->rpc.subscribed_events);
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
    frame->result = CSTR_TO_OBJ(msg);
  }

  channel_close(channel->id, kChannelPartRpc, NULL);
}

static void serialize_request(Channel **chans, size_t nchans, uint32_t request_id,
                              const char *method, Array args)
{
  PackerBuffer packer;
  packer_buffer_init_channels(chans, nchans, &packer);

  mpack_array(&packer.ptr, request_id ? 4 : 3);
  mpack_w(&packer.ptr, request_id ? 0 : 2);

  if (request_id) {
    mpack_uint(&packer.ptr, request_id);
  }

  mpack_str(cstr_as_string(method), &packer);
  mpack_object_array(args, &packer);

  packer_buffer_finish_channels(&packer);
}

void serialize_response(Channel *channel, MsgpackRpcRequestHandler handler, MessageType type,
                        uint32_t response_id, Error *err, Object *arg)
{
  if (ERROR_SET(err) && type == kMessageTypeNotification) {
    if (handler.fn == handle_nvim_paste) {
      // TODO(bfredl): this is pretty much ad-hoc. maybe TUI and UI:s should be
      // allowed to ask nvim to just scream directly in the users face
      // instead of sending nvim_error_event, in general.
      semsg("paste: %s", err->msg);
      api_clear_error(err);
    } else {
      MAXSIZE_TEMP_ARRAY(args, 2);
      ADD_C(args, INTEGER_OBJ(err->type));
      ADD_C(args, CSTR_AS_OBJ(err->msg));
      serialize_request(&channel, 1, 0, "nvim_error_event", args);
    }
    return;
  }

  PackerBuffer packer;
  packer_buffer_init_channels(&channel, 1, &packer);

  mpack_array(&packer.ptr, 4);
  mpack_w(&packer.ptr, 1);
  mpack_uint(&packer.ptr, response_id);

  if (ERROR_SET(err)) {
    // error represented by a [type, message] array
    mpack_array(&packer.ptr, 2);
    mpack_integer(&packer.ptr, err->type);
    mpack_str(cstr_as_string(err->msg), &packer);
    // Nil result
    mpack_nil(&packer.ptr);
  } else {
    // Nil error
    mpack_nil(&packer.ptr);
    // Return value
    mpack_object(arg, &packer);
  }

  packer_buffer_finish_channels(&packer);

  log_response(SEND, channel->id, ERROR_SET(err) ? ERR : RES, response_id);
}

static void packer_buffer_init_channels(Channel **chans, size_t nchans, PackerBuffer *packer)
{
  packer->startptr = alloc_block();
  packer->ptr = packer->startptr;
  packer->endptr = packer->startptr + ARENA_BLOCK_SIZE;
  packer->packer_flush = channel_flush_callback;
  packer->anydata = chans;
  packer->anylen = nchans;
}

static void packer_buffer_finish_channels(PackerBuffer *packer)
{
  size_t len = (size_t)(packer->ptr - packer->startptr);
  if (len > 0) {
    WBuffer *buf = wstream_new_buffer(packer->startptr, len, packer->anylen, free_block);
    Channel **chans = packer->anydata;
    for (size_t i = 0; i < packer->anylen; i++) {
      channel_write(chans[i], buf);
    }
  } else {
    free_block(packer->startptr);
  }
}

static void channel_flush_callback(PackerBuffer *packer)
{
  packer_buffer_finish_channels(packer);
  packer_buffer_init_channels(packer->anydata, packer->anylen, packer);
}

void rpc_set_client_info(uint64_t id, Dictionary info)
{
  Channel *chan = find_rpc_channel(id);
  if (!chan) {
    abort();
  }

  api_free_dictionary(chan->rpc.info);
  chan->rpc.info = info;

  // Parse "type" on "info" and set "client_type"
  const char *type = get_client_info(chan, "type");
  if (type == NULL || strequal(type, "remote")) {
    chan->rpc.client_type = kClientTypeRemote;
  } else if (strequal(type, "msgpack-rpc")) {
    chan->rpc.client_type = kClientTypeMsgpackRpc;
  } else if (strequal(type, "ui")) {
    chan->rpc.client_type = kClientTypeUi;
  } else if (strequal(type, "embedder")) {
    chan->rpc.client_type = kClientTypeEmbedder;
  } else if (strequal(type, "host")) {
    chan->rpc.client_type = kClientTypeHost;
  } else if (strequal(type, "plugin")) {
    chan->rpc.client_type = kClientTypePlugin;
  } else {
    chan->rpc.client_type = kClientTypeUnknown;
  }

  channel_info_changed(chan, false);
}

Dictionary rpc_client_info(Channel *chan)
{
  return copy_dictionary(chan->rpc.info, NULL);
}

const char *get_client_info(Channel *chan, const char *key)
  FUNC_ATTR_NONNULL_ALL
{
  if (!chan->is_rpc) {
    return NULL;
  }
  Dictionary info = chan->rpc.info;
  for (size_t i = 0; i < info.size; i++) {
    if (strequal(key, info.items[i].key.data)
        && info.items[i].value.type == kObjectTypeString) {
      return info.items[i].value.data.string.data;
    }
  }

  return NULL;
}

#ifdef EXITFREE
void rpc_free_all_mem(void)
{
  cstr_t key;
  set_foreach(&event_strings, key, {
    xfree((void *)key);
  });
  set_destroy(cstr_t, &event_strings);

  multiqueue_free(ch_before_blocking_events);
}
#endif
