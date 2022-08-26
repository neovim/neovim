#ifndef NVIM_OS_OS_H
#define NVIM_OS_OS_H

#include <stdbool.h>
#include <uv.h>

#include "nvim/os/fs_defs.h"
#include "nvim/os/stdpaths_defs.h"
#include "nvim/vim.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/env.h.generated.h"
# include "os/fs.h.generated.h"
# include "os/mem.h.generated.h"
# include "os/stdpaths.h.generated.h"
# include "os/users.h.generated.h"
#endif

#define ENV_LOGFILE "NVIM_LOG_FILE"
#define ENV_NVIM "NVIM"

#endif  // NVIM_OS_OS_H
