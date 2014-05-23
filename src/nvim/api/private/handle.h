#ifndef NVIM_API_HANDLE_H
#define NVIM_API_HANDLE_H

#include "nvim/vim.h"

#define HANDLE_DECLS(type, name)                                              \
  type *handle_get_##name(uint64_t handle);                                   \
  void handle_register_##name(type *name);                                    \
  void handle_unregister_##name(type *name);

void handle_init(void);

#endif  // NVIM_API_HANDLE_H

