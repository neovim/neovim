#ifndef NVIM_API_PRIVATE_HANDLE_H
#define NVIM_API_PRIVATE_HANDLE_H

#include "nvim/vim.h"
#include "nvim/buffer_defs.h"
#include "nvim/api/private/defs.h"

#define HANDLE_DECLS(type, name) \
  type *handle_get_##name(handle_T handle); \
  void handle_register_##name(type *name); \
  void handle_unregister_##name(type *name);

// handle_get_buffer handle_register_buffer, handle_unregister_buffer
HANDLE_DECLS(buf_T, buffer)
// handle_get_window handle_register_window, handle_unregister_window
HANDLE_DECLS(win_T, window)
// handle_get_tabpage handle_register_tabpage, handle_unregister_tabpage
HANDLE_DECLS(tabpage_T, tabpage)

void handle_init(void);


#endif  // NVIM_API_PRIVATE_HANDLE_H

