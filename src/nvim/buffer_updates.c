// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/buffer_updates.h"
#include "nvim/memline.h"
#include "nvim/api/private/helpers.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/lua/executor.h"
#include "nvim/assert.h"
#include "nvim/buffer.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "buffer_updates.c.generated.h"
#endif

// Register a channel. Return True if the channel was added, or already added.
// Return False if the channel couldn't be added because the buffer is
// unloaded.
bool buf_updates_register(buf_T *buf, uint64_t channel_id,
                          BufUpdateCallbacks cb, bool send_buffer)
{
  // must fail if the buffer isn't loaded
  if (buf->b_ml.ml_mfp == NULL) {
    return false;
  }

  if (channel_id == LUA_INTERNAL_CALL) {
    kv_push(buf->update_callbacks, cb);
    return true;
  }

  // count how many channels are currently watching the buffer
  size_t size = kv_size(buf->update_channels);
  if (size) {
    for (size_t i = 0; i < size; i++) {
      if (kv_A(buf->update_channels, i) == channel_id) {
        // buffer is already registered ... nothing to do
        return true;
      }
    }
  }

  // append the channelid to the list
  kv_push(buf->update_channels, channel_id);

  if (send_buffer) {
    Array args = ARRAY_DICT_INIT;
    args.size = 6;
    args.items = xcalloc(sizeof(Object), args.size);

    // the first argument is always the buffer handle
    args.items[0] = BUFFER_OBJ(buf->handle);
    args.items[1] = INTEGER_OBJ(buf_get_changedtick(buf));
    // the first line that changed (zero-indexed)
    args.items[2] = INTEGER_OBJ(0);
    // the last line that was changed
    args.items[3] = INTEGER_OBJ(-1);
    Array linedata = ARRAY_DICT_INIT;

    // collect buffer contents

    STATIC_ASSERT(SIZE_MAX >= MAXLNUM, "size_t smaller than MAXLNUM");
    size_t line_count = (size_t)buf->b_ml.ml_line_count;

    if (line_count >= 1) {
      linedata.size = line_count;
      linedata.items = xcalloc(sizeof(Object), line_count);

      buf_collect_lines(buf, line_count, 1, true, &linedata, NULL);
    }

    args.items[4] = ARRAY_OBJ(linedata);
    args.items[5] = BOOLEAN_OBJ(false);

    rpc_send_event(channel_id, "nvim_buf_lines_event", args);
  } else {
    buf_updates_changedtick_single(buf, channel_id);
  }

  return true;
}

bool buf_updates_active(buf_T *buf)
{
    return kv_size(buf->update_channels) || kv_size(buf->update_callbacks);
}

void buf_updates_send_end(buf_T *buf, uint64_t channelid)
{
    Array args = ARRAY_DICT_INIT;
    args.size = 1;
    args.items = xcalloc(sizeof(Object), args.size);
    args.items[0] = BUFFER_OBJ(buf->handle);
    rpc_send_event(channelid, "nvim_buf_detach_event", args);
}

void buf_updates_unregister(buf_T *buf, uint64_t channelid)
{
  size_t size = kv_size(buf->update_channels);
  if (!size) {
    return;
  }

  // go through list backwards and remove the channel id each time it appears
  // (it should never appear more than once)
  size_t j = 0;
  size_t found = 0;
  for (size_t i = 0; i < size; i++) {
    if (kv_A(buf->update_channels, i) == channelid) {
      found++;
    } else {
      // copy item backwards into prior slot if needed
      if (i != j) {
        kv_A(buf->update_channels, j) = kv_A(buf->update_channels, i);
      }
      j++;
    }
  }

  if (found) {
    // remove X items from the end of the array
    buf->update_channels.size -= found;

    // make a new copy of the active array without the channelid in it
    buf_updates_send_end(buf, channelid);

    if (found == size) {
      kv_destroy(buf->update_channels);
      kv_init(buf->update_channels);
    }
  }
}

void buf_updates_unregister_all(buf_T *buf)
{
  size_t size = kv_size(buf->update_channels);
  if (size) {
    for (size_t i = 0; i < size; i++) {
      buf_updates_send_end(buf, kv_A(buf->update_channels, i));
    }
    kv_destroy(buf->update_channels);
    kv_init(buf->update_channels);
  }

  for (size_t i = 0; i < kv_size(buf->update_callbacks); i++) {
    BufUpdateCallbacks cb = kv_A(buf->update_callbacks, i);
    if (cb.on_detach != LUA_NOREF) {
      Array args = ARRAY_DICT_INIT;
      Object items[1];
      args.size = 1;
      args.items = items;

      // the first argument is always the buffer handle
      args.items[0] = BUFFER_OBJ(buf->handle);

      textlock++;
      executor_exec_lua_cb(cb.on_detach, "detach", args, false);
      textlock--;
    }
    free_update_callbacks(cb);
  }
  kv_destroy(buf->update_callbacks);
  kv_init(buf->update_callbacks);
}

void buf_updates_send_changes(buf_T *buf,
                              linenr_T firstline,
                              int64_t num_added,
                              int64_t num_removed,
                              bool send_tick)
{
  if (!buf_updates_active(buf)) {
    return;
  }

  // if one the channels doesn't work, put its ID here so we can remove it later
  uint64_t badchannelid = 0;

  // notify each of the active channels
  for (size_t i = 0; i < kv_size(buf->update_channels); i++) {
    uint64_t channelid = kv_A(buf->update_channels, i);

    // send through the changes now channel contents now
    Array args = ARRAY_DICT_INIT;
    args.size = 6;
    args.items = xcalloc(sizeof(Object), args.size);

    // the first argument is always the buffer handle
    args.items[0] = BUFFER_OBJ(buf->handle);

    // next argument is b:changedtick
    args.items[1] = send_tick ? INTEGER_OBJ(buf_get_changedtick(buf)) : NIL;

    // the first line that changed (zero-indexed)
    args.items[2] = INTEGER_OBJ(firstline - 1);

    // the last line that was changed
    args.items[3] = INTEGER_OBJ(firstline - 1 + num_removed);

    // linedata of lines being swapped in
    Array linedata = ARRAY_DICT_INIT;
    if (num_added > 0) {
        STATIC_ASSERT(SIZE_MAX >= MAXLNUM, "size_t smaller than MAXLNUM");
        linedata.size = (size_t)num_added;
        linedata.items = xcalloc(sizeof(Object), (size_t)num_added);
        buf_collect_lines(buf, (size_t)num_added, firstline, true, &linedata,
                          NULL);
    }
    args.items[4] = ARRAY_OBJ(linedata);
    args.items[5] = BOOLEAN_OBJ(false);
    if (!rpc_send_event(channelid, "nvim_buf_lines_event", args)) {
      // We can't unregister the channel while we're iterating over the
      // update_channels array, so we remember its ID to unregister it at
      // the end.
      badchannelid = channelid;
    }
  }

  // We can only ever remove one dead channel at a time. This is OK because the
  // change notifications are so frequent that many dead channels will be
  // cleared up quickly.
  if (badchannelid != 0) {
    ELOG("Disabling buffer updates for dead channel %"PRIu64, badchannelid);
    buf_updates_unregister(buf, badchannelid);
  }

  // notify each of the active channels
  size_t j = 0;
  for (size_t i = 0; i < kv_size(buf->update_callbacks); i++) {
    BufUpdateCallbacks cb = kv_A(buf->update_callbacks, i);
    bool keep = true;
    if (cb.on_lines != LUA_NOREF) {
      Array args = ARRAY_DICT_INIT;
      Object items[5];
      args.size = 5;
      args.items = items;

      // the first argument is always the buffer handle
      args.items[0] = BUFFER_OBJ(buf->handle);

      // next argument is b:changedtick
      args.items[1] = send_tick ? INTEGER_OBJ(buf_get_changedtick(buf)) : NIL;

      // the first line that changed (zero-indexed)
      args.items[2] = INTEGER_OBJ(firstline - 1);

      // the last line that was changed
      args.items[3] = INTEGER_OBJ(firstline - 1 + num_removed);

      // the last line in the updated range
      args.items[4] = INTEGER_OBJ(firstline - 1 + num_added);

      textlock++;
      Object res = executor_exec_lua_cb(cb.on_lines, "lines", args, true);
      textlock--;

      if (res.type == kObjectTypeBoolean && res.data.boolean == true) {
        free_update_callbacks(cb);
        keep = false;
      }
      api_free_object(res);
    }
    if (keep) {
      kv_A(buf->update_callbacks, j++) = kv_A(buf->update_callbacks, i);
    }
  }
  kv_size(buf->update_callbacks) = j;
}

void buf_updates_changedtick(buf_T *buf)
{
  // notify each of the active channels
  for (size_t i = 0; i < kv_size(buf->update_channels); i++) {
    uint64_t channel_id = kv_A(buf->update_channels, i);
    buf_updates_changedtick_single(buf, channel_id);
  }
  size_t j = 0;
  for (size_t i = 0; i < kv_size(buf->update_callbacks); i++) {
    BufUpdateCallbacks cb = kv_A(buf->update_callbacks, i);
    bool keep = true;
    if (cb.on_changedtick != LUA_NOREF) {
      Array args = ARRAY_DICT_INIT;
      Object items[2];
      args.size = 2;
      args.items = items;

      // the first argument is always the buffer handle
      args.items[0] = BUFFER_OBJ(buf->handle);

      // next argument is b:changedtick
      args.items[1] = INTEGER_OBJ(buf_get_changedtick(buf));

      textlock++;
      Object res = executor_exec_lua_cb(cb.on_changedtick, "changedtick",
                                        args, true);
      textlock--;

      if (res.type == kObjectTypeBoolean && res.data.boolean == true) {
        free_update_callbacks(cb);
        keep = false;
      }
      api_free_object(res);
    }
    if (keep) {
      kv_A(buf->update_callbacks, j++) = kv_A(buf->update_callbacks, i);
    }
  }
  kv_size(buf->update_callbacks) = j;
}

void buf_updates_changedtick_single(buf_T *buf, uint64_t channel_id)
{
    Array args = ARRAY_DICT_INIT;
    args.size = 2;
    args.items = xcalloc(sizeof(Object), args.size);

    // the first argument is always the buffer handle
    args.items[0] = BUFFER_OBJ(buf->handle);

    // next argument is b:changedtick
    args.items[1] = INTEGER_OBJ(buf_get_changedtick(buf));

    // don't try and clean up dead channels here
    rpc_send_event(channel_id, "nvim_buf_changedtick_event", args);
}

static void free_update_callbacks(BufUpdateCallbacks cb)
{
  executor_free_luaref(cb.on_lines);
  executor_free_luaref(cb.on_changedtick);
}
