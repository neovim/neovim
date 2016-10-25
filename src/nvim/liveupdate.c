#include "nvim/liveupdate.h"
#include "nvim/memline.h"
#include "nvim/api/private/helpers.h"
#include "nvim/msgpack_rpc/channel.h"

/*
 * Register a channel. Return True if the channel was added, or already added.
 * Return False if the channel couldn't be added because the buffer is
 * unloaded.
 */
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

    const char *bufstr = (char *) ml_get_buf(buf, lnum, false);
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
