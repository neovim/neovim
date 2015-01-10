#include <stdbool.h>
#include <stdlib.h>
#include <assert.h>

#include <uv.h>

#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/buffer_defs.h"
#include "nvim/fileio.h"
#include "nvim/fswatch.h"
#include "nvim/lib/klist.h"
#include "nvim/lib/khash.h"
#include "nvim/os/fs_defs.h"
#include "nvim/os/event.h"

// Apparentely, the destruction mechanism is not very well implemented in klist.
// Proper resource handling will be done manually
#define _destroy(x)
KLIST_INIT(Watcher, Watcher, _destroy)
#undef _destroy

static klist_t(Watcher)* watchers_list = NULL;

KHASH_MAP_INIT_STR(EventTable, int)
khash_t(EventTable)* event_lookup = NULL;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "fswatch.c.generated.h"
#endif

typedef struct {
    buf_T* buffer;
    khiter_t lookup_iter;
    uv_fs_event_t* handle;
} EvtData;

static void check_callback(Event evt)
{
  EvtData* data = (EvtData*) evt.data;
  (void) buf_check_timestamp(data->buffer, false);

  if ((kh_value(event_lookup, data->lookup_iter) & UV_RENAME) &&
      os_file_exists(data->buffer->b_ffname)) {
    fswatch_delete_buffer(data->buffer);
    fswatch_add_buffer(data->buffer);
  }

  kh_value(event_lookup, data->lookup_iter) = 0;
  free(data);
}

static void fs_event_callback(uv_fs_event_t* handle,
                                    const char* filename,
                                    int events,
                                    int status)
{
  // we need to retrieve the full path for buflist_findname
  char path[1024];
  size_t size = 1023;
  uv_fs_event_getpath(handle, path, &size);
  path[++size] = '\0';

  khiter_t value = kh_get(EventTable, event_lookup, path);
  if (value == kh_end(event_lookup)
      || kh_value(event_lookup, value) == 0)
  {
    int dummy_ret;
    value = kh_put(EventTable, event_lookup, path, &dummy_ret);
    kh_value(event_lookup, value) = events;

    buf_T* buf = buflist_findname((char_u*)path);
    if (buf == NULL) {
      return;
    }

    EvtData* evt_data = malloc(sizeof(EvtData));
    evt_data->buffer = buf;
    // TODO(doppioandante): is value always valid?
    evt_data->lookup_iter = value;
    evt_data->handle = handle;

    Event evt = {
      .data = (void*) evt_data,
      .handler = check_callback,
    };
    event_push(evt, false);
  } else {
    kh_value(event_lookup, value) &= events;
  }
}

static bool find_node_before(klist_t(Watcher)* kl,
                             buf_T* buffer,
                             kliter_t(Watcher)** node)
{
  kliter_t(Watcher)* prev = NULL;
  kliter_t(Watcher)* it = kl_begin(kl);

  for (size_t i = 0; i < kl->size; i++) {
    if (kl_val(it).buffer == buffer) {
      if (node != NULL)
        *node = prev;
      return true;
    }

    prev = it;
    it = kl_next(it);
  }

  return false;
}

static bool find_associated_watcher(buf_T* buffer, Watcher* w)
{
  assert(watchers_list != NULL);

  kliter_t(Watcher)* it = kl_begin(watchers_list);

  for (size_t i = 0; i < watchers_list->size; i++) {
    if (kl_val(it).buffer == buffer) {
      if (w != NULL)
        *w = kl_val(it);
      return true;
    }

    it = kl_next(it);
  }

  return false;
}

static bool remove_associated_watcher(buf_T* buffer, Watcher* w)
{
  assert(watchers_list != NULL);

  kliter_t(Watcher)* it = NULL;
  if (find_node_before(watchers_list, buffer, &it)) {
    if (it == NULL) {  // the element is the head, use shift
      kl_shift(Watcher, watchers_list, w);
    } else {
      kl_iter_remove_next(Watcher, watchers_list, it, w);
    }

    return true;
  }

  return false;
}

void fswatch_init(void) {
  watchers_list = kl_init(Watcher);
  event_lookup = kh_init(EventTable);
}

// called on application exiting
void fswatch_teardown(void) {
  Watcher w;

  while (kl_shift(Watcher, watchers_list, &w) == 0) {
    free_watcher(&w);
  }

  kl_destroy(Watcher, watchers_list);
  kh_destroy(EventTable, event_lookup);
}

bool fswatch_add_buffer(buf_T *buffer) {
  // We check first if the buffer is already register
  // In that case, we just enable its watcher
  {
    Watcher w;
    if (find_associated_watcher(buffer, &w)) {
     return fswatch_enable_watcher(&w, true);
    }
  }

  uv_fs_event_t *event_handle = try_malloc(sizeof(uv_fs_event_t));

  if (event_handle == NULL) {  // malloc failed
    return false;
  }

  if (uv_fs_event_init(uv_default_loop(), event_handle) != 0) {
    return false;
  }

  Watcher w = {
    .buffer = buffer,
    .handle = event_handle,
  };

  assert(watchers_list != NULL);
  Watcher* new_element = kl_pushp(Watcher, watchers_list);
  *new_element = w;

  return fswatch_enable_watcher(new_element, true);
}

static bool fswatch_enable_watcher(Watcher* watcher, bool state)
{
  if (uv_is_active((uv_handle_t*) watcher->handle) != state) {
    int res;
    if (state) {
      res = uv_fs_event_start(
            watcher->handle,
            fs_event_callback,
            (const char*)watcher->buffer->b_ffname,
            UV_FS_EVENT_RECURSIVE);

    } else {
      res = uv_fs_event_stop(watcher->handle);
    }

    return res == 0;  // success
  }

  // success if the final state is the desired one
  return true;
}

void fswatch_delete_buffer(buf_T* buffer) {
  Watcher w;
  if (remove_associated_watcher(buffer, &w)) {
    free_watcher(&w);
  }

  khiter_t value = kh_get(EventTable, event_lookup, (char*)buffer->b_ffname);
  if (value != kh_end(event_lookup))
  {
    kh_del(EventTable, event_lookup, value);
  }
}

bool fswatch_enable_watcher_on(buf_T* buffer, bool state) {
  Watcher w;
  if (find_associated_watcher(buffer, &w)) {
    return fswatch_enable_watcher(&w, state);
  }

  return false;
}

static void free_watcher(Watcher* watcher) {
  uv_close((uv_handle_t*) watcher->handle, NULL);
  free(watcher->handle);
}

