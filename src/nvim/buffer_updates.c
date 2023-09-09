// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <inttypes.h>
#include <stdbool.h>
#include <stddef.h>

#include "klib/kvec.h"
#include "lauxlib.h"
#include "nvim/api/buffer.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/assert.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/buffer_updates.h"
#include "nvim/extmark.h"
#include "nvim/globals.h"
#include "nvim/log.h"
#include "nvim/lua/executor.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/pos.h"
#include "nvim/types.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "buffer_updates.c.generated.h"  // IWYU pragma: export
#endif

// Register a channel. Return True if the channel was added, or already added.
// Return False if the channel couldn't be added because the buffer is
// unloaded.
bool buf_updates_register(buf_T *buf, uint64_t channel_id, BufUpdateCallbacks cb, bool send_buffer)
{
  // must fail if the buffer isn't loaded
  if (buf->b_ml.ml_mfp == NULL) {
    return false;
  }

  if (channel_id == LUA_INTERNAL_CALL) {
    kv_push(buf->update_callbacks, cb);
    if (cb.utf_sizes) {
      buf->update_need_codepoints = true;
    }
    return true;
  }

  // count how many channels are currently watching the buffer
  size_t size = kv_size(buf->update_channels);
  for (size_t i = 0; i < size; i++) {
    if (kv_A(buf->update_channels, i) == channel_id) {
      // buffer is already registered ... nothing to do
      return true;
    }
  }

  // append the channelid to the list
  kv_push(buf->update_channels, channel_id);

  if (send_buffer) {
    Array args = ARRAY_DICT_INIT;
    args.size = 6;
    args.items = xcalloc(args.size, sizeof(Object));

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
      linedata.items = xcalloc(line_count, sizeof(Object));

      buf_collect_lines(buf, line_count, 1, 0, true, &linedata, NULL, NULL);
    }

    args.items[4] = ARRAY_OBJ(linedata);
    args.items[5] = BOOLEAN_OBJ(false);

    rpc_send_event(channel_id, "nvim_buf_lines_event", args);
    api_free_array(args);  // TODO(bfredl): no
  } else {
    buf_updates_changedtick_single(buf, channel_id);
  }

  return true;
}

bool buf_updates_active(buf_T *buf)
  FUNC_ATTR_PURE
{
  return kv_size(buf->update_channels) || kv_size(buf->update_callbacks);
}

void buf_updates_send_end(buf_T *buf, uint64_t channelid)
{
  MAXSIZE_TEMP_ARRAY(args, 1);
  ADD_C(args, BUFFER_OBJ(buf->handle));
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

void buf_free_callbacks(buf_T *buf)
{
  kv_destroy(buf->update_channels);
  for (size_t i = 0; i < kv_size(buf->update_callbacks); i++) {
    buffer_update_callbacks_free(kv_A(buf->update_callbacks, i));
  }
  kv_destroy(buf->update_callbacks);
}

void buf_updates_unload(buf_T *buf, bool can_reload)
{
  size_t size = kv_size(buf->update_channels);
  if (size) {
    for (size_t i = 0; i < size; i++) {
      buf_updates_send_end(buf, kv_A(buf->update_channels, i));
    }
    kv_destroy(buf->update_channels);
    kv_init(buf->update_channels);
  }

  size_t j = 0;
  for (size_t i = 0; i < kv_size(buf->update_callbacks); i++) {
    BufUpdateCallbacks cb = kv_A(buf->update_callbacks, i);
    LuaRef thecb = LUA_NOREF;

    bool keep = false;
    if (can_reload && cb.on_reload != LUA_NOREF) {
      keep = true;
      thecb = cb.on_reload;
    } else if (cb.on_detach != LUA_NOREF) {
      thecb = cb.on_detach;
    }

    if (thecb != LUA_NOREF) {
      Array args = ARRAY_DICT_INIT;
      Object items[1];
      args.size = 1;
      args.items = items;

      // the first argument is always the buffer handle
      args.items[0] = BUFFER_OBJ(buf->handle);

      TEXTLOCK_WRAP({
        nlua_call_ref(thecb, keep ? "reload" : "detach", args, false, NULL);
      });
    }

    if (keep) {
      kv_A(buf->update_callbacks, j++) = kv_A(buf->update_callbacks, i);
    } else {
      buffer_update_callbacks_free(cb);
    }
  }
  kv_size(buf->update_callbacks) = j;
  if (kv_size(buf->update_callbacks) == 0) {
    kv_destroy(buf->update_callbacks);
    kv_init(buf->update_callbacks);
  }
}

void buf_updates_send_changes(buf_T *buf, linenr_T firstline, int64_t num_added,
                              int64_t num_removed)
{
  size_t deleted_codepoints, deleted_codeunits;
  size_t deleted_bytes = ml_flush_deleted_bytes(buf, &deleted_codepoints,
                                                &deleted_codeunits);

  if (!buf_updates_active(buf)) {
    return;
  }

  // Don't send b:changedtick during 'inccommand' preview if "buf" is the current buffer.
  bool send_tick = !(cmdpreview && buf == curbuf);

  // if one the channels doesn't work, put its ID here so we can remove it later
  uint64_t badchannelid = 0;

  // notify each of the active channels
  for (size_t i = 0; i < kv_size(buf->update_channels); i++) {
    uint64_t channelid = kv_A(buf->update_channels, i);

    // send through the changes now channel contents now
    Array args = ARRAY_DICT_INIT;
    args.size = 6;
    args.items = xcalloc(args.size, sizeof(Object));

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
      linedata.items = xcalloc((size_t)num_added, sizeof(Object));
      buf_collect_lines(buf, (size_t)num_added, firstline, 0, true, &linedata,
                        NULL, NULL);
    }
    args.items[4] = ARRAY_OBJ(linedata);
    args.items[5] = BOOLEAN_OBJ(false);
    if (!rpc_send_event(channelid, "nvim_buf_lines_event", args)) {
      // We can't unregister the channel while we're iterating over the
      // update_channels array, so we remember its ID to unregister it at
      // the end.
      badchannelid = channelid;
    }
    api_free_array(args);  // TODO(bfredl): no
  }

  // We can only ever remove one dead channel at a time. This is OK because the
  // change notifications are so frequent that many dead channels will be
  // cleared up quickly.
  if (badchannelid != 0) {
    ELOG("Disabling buffer updates for dead channel %" PRIu64, badchannelid);
    buf_updates_unregister(buf, badchannelid);
  }

  // notify each of the active channels
  size_t j = 0;
  for (size_t i = 0; i < kv_size(buf->update_callbacks); i++) {
    BufUpdateCallbacks cb = kv_A(buf->update_callbacks, i);
    bool keep = true;
    if (cb.on_lines != LUA_NOREF && (cb.preview || !cmdpreview)) {
      Array args = ARRAY_DICT_INIT;
      Object items[8];
      args.size = 6;  // may be increased to 8 below
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

      // byte count of previous contents
      args.items[5] = INTEGER_OBJ((Integer)deleted_bytes);
      if (cb.utf_sizes) {
        args.size = 8;
        args.items[6] = INTEGER_OBJ((Integer)deleted_codepoints);
        args.items[7] = INTEGER_OBJ((Integer)deleted_codeunits);
      }

      Object res;
      TEXTLOCK_WRAP({
        res = nlua_call_ref(cb.on_lines, "lines", args, false, NULL);
      });

      if (res.type == kObjectTypeBoolean && res.data.boolean == true) {
        buffer_update_callbacks_free(cb);
        keep = false;
      }
    }
    if (keep) {
      kv_A(buf->update_callbacks, j++) = kv_A(buf->update_callbacks, i);
    }
  }
  kv_size(buf->update_callbacks) = j;
}

void buf_updates_send_splice(buf_T *buf, int start_row, colnr_T start_col, bcount_t start_byte,
                             int old_row, colnr_T old_col, bcount_t old_byte, int new_row,
                             colnr_T new_col, bcount_t new_byte)
{
  if (!buf_updates_active(buf)
      || (old_byte == 0 && new_byte == 0)) {
    return;
  }

  // notify each of the active callbacks
  size_t j = 0;
  for (size_t i = 0; i < kv_size(buf->update_callbacks); i++) {
    BufUpdateCallbacks cb = kv_A(buf->update_callbacks, i);
    bool keep = true;
    if (cb.on_bytes != LUA_NOREF && (cb.preview || !cmdpreview)) {
      MAXSIZE_TEMP_ARRAY(args, 11);

      // the first argument is always the buffer handle
      ADD_C(args, BUFFER_OBJ(buf->handle));

      // next argument is b:changedtick
      ADD_C(args, INTEGER_OBJ(buf_get_changedtick(buf)));

      ADD_C(args, INTEGER_OBJ(start_row));
      ADD_C(args, INTEGER_OBJ(start_col));
      ADD_C(args, INTEGER_OBJ(start_byte));
      ADD_C(args, INTEGER_OBJ(old_row));
      ADD_C(args, INTEGER_OBJ(old_col));
      ADD_C(args, INTEGER_OBJ(old_byte));
      ADD_C(args, INTEGER_OBJ(new_row));
      ADD_C(args, INTEGER_OBJ(new_col));
      ADD_C(args, INTEGER_OBJ(new_byte));

      Object res;
      TEXTLOCK_WRAP({
        res = nlua_call_ref(cb.on_bytes, "bytes", args, false, NULL);
      });

      if (res.type == kObjectTypeBoolean && res.data.boolean == true) {
        buffer_update_callbacks_free(cb);
        keep = false;
      }
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
      MAXSIZE_TEMP_ARRAY(args, 2);

      // the first argument is always the buffer handle
      ADD_C(args, BUFFER_OBJ(buf->handle));

      // next argument is b:changedtick
      ADD_C(args, INTEGER_OBJ(buf_get_changedtick(buf)));

      Object res;
      TEXTLOCK_WRAP({
        res = nlua_call_ref(cb.on_changedtick, "changedtick", args, false, NULL);
      });

      if (res.type == kObjectTypeBoolean && res.data.boolean == true) {
        buffer_update_callbacks_free(cb);
        keep = false;
      }
    }
    if (keep) {
      kv_A(buf->update_callbacks, j++) = kv_A(buf->update_callbacks, i);
    }
  }
  kv_size(buf->update_callbacks) = j;
}

void buf_updates_changedtick_single(buf_T *buf, uint64_t channel_id)
{
  MAXSIZE_TEMP_ARRAY(args, 2);

  // the first argument is always the buffer handle
  ADD_C(args, BUFFER_OBJ(buf->handle));

  // next argument is b:changedtick
  ADD_C(args, INTEGER_OBJ(buf_get_changedtick(buf)));

  // don't try and clean up dead channels here
  rpc_send_event(channel_id, "nvim_buf_changedtick_event", args);
}

void buffer_update_callbacks_free(BufUpdateCallbacks cb)
{
  api_free_luaref(cb.on_lines);
  api_free_luaref(cb.on_bytes);
  api_free_luaref(cb.on_changedtick);
  api_free_luaref(cb.on_reload);
  api_free_luaref(cb.on_detach);
}
