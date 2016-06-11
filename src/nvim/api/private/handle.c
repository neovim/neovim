#include <assert.h>
#include <stdint.h>

#include "nvim/vim.h"
#include "nvim/map.h"
#include "nvim/api/private/handle.h"

#define HANDLE_INIT(name) name##_handles = pmap_new(uint64_t)()

#define HANDLE_IMPL(type, name) \
  static PMap(uint64_t) *name##_handles = NULL; \
  \
  type *handle_get_##name(uint64_t handle) \
  { \
    return pmap_get(uint64_t)(name##_handles, handle); \
  } \
  \
  void handle_register_##name(type *name) \
  { \
    assert(!name->handle); \
    name->handle = next_handle++; \
    pmap_put(uint64_t)(name##_handles, name->handle, name); \
  } \
  \
  void handle_unregister_##name(type *name) \
  { \
    pmap_del(uint64_t)(name##_handles, name->handle); \
  }

static uint64_t next_handle = 1;

HANDLE_IMPL(buf_T, buffer)
HANDLE_IMPL(win_T, window)
HANDLE_IMPL(tabpage_T, tabpage)

void handle_init(void)
{
  HANDLE_INIT(buffer);
  HANDLE_INIT(window);
  HANDLE_INIT(tabpage);
}
