#ifndef NVIM_OS_OS_H
#define NVIM_OS_OS_H
#include <uv.h>

#include "nvim/vim.h"

/// Struct which encapsulates stat information.
typedef struct {
  // TODO(stefan991): make stat private
  uv_stat_t stat;
} FileInfo;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/fs.h.generated.h"
# include "os/mem.h.generated.h"
# include "os/env.h.generated.h"
# include "os/users.h.generated.h"
#endif
#endif  // NVIM_OS_OS_H
