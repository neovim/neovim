#include "nvim/liveupdate.h"
#include "nvim/memline.h"
#include "nvim/api/private/helpers.h"
#include "nvim/msgpack_rpc/channel.h"

// Register a channel. Return True if the channel was added, or already added.
// Return False if the channel couldn't be added because the buffer is
// unloaded.
bool liveupdate_register(buf_T *buf, uint64_t channel_id) {
  // must fail if the buffer isn't loaded
  if (buf->b_ml.ml_mfp == NULL) {
    return false;
  }

  // count how many channels are currently watching the buffer
  int active_size = 0;
  if (buf->liveupdate_channels != NULL) {
    while (buf->liveupdate_channels[active_size] != LIVEUPDATE_NONE) {
      if (buf->liveupdate_channels[active_size] == channel_id) {
        // buffer is already registered ... nothing to do
        return true;
      }
      active_size++;
    }
  }

  // add the buffer to the active array and send the full buffer contents now
  uint64_t *newlist = xmalloc((active_size + 2) * sizeof channel_id);
  // copy items to the new array
  for (int i = 0; i < active_size; i++) {
    newlist[i] = buf->liveupdate_channels[i];
  }
  // put the new channel on the end
  newlist[active_size] = channel_id;
  // terminator
  newlist[active_size + 1] = LIVEUPDATE_NONE;
  // free the old list and put the new one in place
  if (active_size) {
    xfree(buf->liveupdate_channels);
  }
  buf->liveupdate_channels = newlist;

  // send through the full channel contents now
  Array linedata = ARRAY_DICT_INIT;
  size_t line_count = buf->b_ml.ml_line_count;
  linedata.size = line_count;
  linedata.items = xcalloc(sizeof(Object), line_count);
  for (size_t i = 0; i < line_count; i++) {
    linenr_T lnum = 1 + (linenr_T)i;

    const char *bufstr = (char *)ml_get_buf(buf, lnum, false);
    Object str = STRING_OBJ(cstr_to_string(bufstr));

    // Vim represents NULs as NLs, but this may confuse clients.
    strchrsub(str.data.string.data, '\n', '\0');

    linedata.items[i] = str;
  }

  Array args = ARRAY_DICT_INIT;
  args.size = 3;
  args.items = xcalloc(sizeof(Object), args.size);

  // the first argument is always the buffer number
  args.items[0] = INTEGER_OBJ(buf->handle);
  args.items[1] = ARRAY_OBJ(linedata);
  args.items[2] = BOOLEAN_OBJ(false);

  channel_send_event(channel_id, "LiveUpdateStart", args);
  return true;
}

void liveupdate_send_end(buf_T *buf, uint64_t channelid) {
    Array args = ARRAY_DICT_INIT;
    args.size = 1;
    args.items = xcalloc(sizeof(Object), args.size);
    args.items[0] = INTEGER_OBJ(buf->handle);
    channel_send_event(channelid, "LiveUpdateEnd", args);
}

void liveupdate_unregister(buf_T *buf, uint64_t channelid) {
  if (buf->liveupdate_channels == NULL) {
    return;
  }

  // does the channelid appear in the liveupdate_channels array?
  int found_active = 0;
  int active_size = 0;
  while (buf->liveupdate_channels[active_size] != LIVEUPDATE_NONE) {
    if (buf->liveupdate_channels[active_size] == channelid) {
      found_active++;
    }
    active_size += 1;
  }

  if (found_active) {
    // make a new copy of the active array without the channelid in it
    uint64_t *newlist = xmalloc((1 + active_size - found_active)
                                * sizeof channelid);
    int i = 0;
    int j = 0;
    for (; i < active_size; i++) {
      if (buf->liveupdate_channels[i] != channelid) {
        newlist[j] = buf->liveupdate_channels[i];
        j++;
      }
    }
    newlist[j] = LIVEUPDATE_NONE;
    xfree(buf->liveupdate_channels);
    buf->liveupdate_channels = newlist;

    liveupdate_send_end(buf, channelid);
  }
}

void liveupdate_unregister_all(buf_T *buf) {
  if (buf->liveupdate_channels != NULL) {
    for (int i = 0; buf->liveupdate_channels[i] != LIVEUPDATE_NONE; i++) {
      liveupdate_send_end(buf, buf->liveupdate_channels[i]);
    }
    xfree(buf->liveupdate_channels);
    buf->liveupdate_channels = NULL;
  }
}

void liveupdate_send_changes(buf_T *buf, linenr_T firstline, int64_t num_added,
                             int64_t num_removed) {
  // if one the channels doesn't work, put its ID here so we can remove it later
  uint64_t badchannelid = LIVEUPDATE_NONE;

  // notify each of the active channels
  if (buf->liveupdate_channels != NULL) {
    for (int i = 0; buf->liveupdate_channels[i] != LIVEUPDATE_NONE; i++) {
      uint64_t channelid = buf->liveupdate_channels[i];

      // send through the changes now channel contents now
      Array args = ARRAY_DICT_INIT;
      args.size = 4;
      args.items = xcalloc(sizeof(Object), args.size);

      // the first argument is always the buffer number
      args.items[0] = INTEGER_OBJ(buf->handle);

      // the first line that changed (zero-indexed)
      args.items[1] = INTEGER_OBJ(firstline - 1);

      // how many lines are being swapped out
      args.items[2] = INTEGER_OBJ(num_removed);

      // linedata of lines being swapped in
      Array linedata = ARRAY_DICT_INIT;
      if (num_added > 0) {
          linedata.size = num_added;
          linedata.items = xcalloc(sizeof(Object), num_added);
          for (int64_t i = 0; i < num_added; i++) {
            int64_t lnum = firstline + i;
            const char *bufstr = (char *)ml_get_buf(buf, (linenr_T)lnum, false);
            Object str = STRING_OBJ(cstr_to_string(bufstr));

            // Vim represents NULs as NLs, but this may confuse clients.
            strchrsub(str.data.string.data, '\n', '\0');

            linedata.items[i] = str;
          }
      }
      args.items[3] = ARRAY_OBJ(linedata);
      if (!channel_send_event(channelid, "LiveUpdate", args)) {
        // We can't unregister the channel while we're iterating over the
        // liveupdate_channels array, so we remember its ID to unregister it at
        // the end.
        badchannelid = channelid;
      }
    }
  }

  // We can only ever remove one dead channel at a time. This is OK because the
  // change notifications are so frequent that many dead channels will be
  // cleared up quickly.
  if (badchannelid != LIVEUPDATE_NONE) {
    ELOG("Disabling live updates for dead channel %llu", badchannelid);
    liveupdate_unregister(buf, badchannelid);
  }
}
