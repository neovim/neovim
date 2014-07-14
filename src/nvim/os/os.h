#ifndef NVIM_OS_OS_H
#define NVIM_OS_OS_H

#include <stdbool.h>
#include <uv.h>

#include "nvim/os/fs_defs.h"
#include "nvim/vim.h"

#ifdef WIN32
# include "nvim/os/win_defs.h"
#else
# include "nvim/os/unix_defs.h"
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/fs.h.generated.h"
# include "os/mem.h.generated.h"
# include "os/env.h.generated.h"
# include "os/users.h.generated.h"
#endif

#endif  // NVIM_OS_OS_H
