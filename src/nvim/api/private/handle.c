// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <stdint.h>

#include "nvim/vim.h"
#include "nvim/map.h"
#include "nvim/api/private/handle.h"

#define HANDLE_INIT(name) name##_handles = pmap_new(handle_T)()

#define HANDLE_IMPL(type, name) \
  static PMap(handle_T) *name##_handles = NULL; /* NOLINT */ \
  \
  type *handle_get_##name(handle_T handle) \
  { \
    return pmap_get(handle_T)(name##_handles, handle); \
  } \
  \
  void handle_register_##name(type *name) \
  { \
    pmap_put(handle_T)(name##_handles, name->handle, name); \
  } \
  \
  void handle_unregister_##name(type *name) \
  { \
    pmap_del(handle_T)(name##_handles, name->handle); \
  }

HANDLE_IMPL(buf_T, buffer)
HANDLE_IMPL(win_T, window)
HANDLE_IMPL(tabpage_T, tabpage)

void handle_init(void)
{
  HANDLE_INIT(buffer);
  HANDLE_INIT(window);
  HANDLE_INIT(tabpage);
}
