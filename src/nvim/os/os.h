#pragma once

#include <stdbool.h>
#include <uv.h>

#include "nvim/buffer_defs.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/garray.h"
#include "nvim/os/fs_defs.h"
#include "nvim/os/stdpaths_defs.h"
#include "nvim/types.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/env.h.generated.h"
# include "os/fs.h.generated.h"
# include "os/mem.h.generated.h"
# include "os/stdpaths.h.generated.h"
# include "os/users.h.generated.h"
#endif

#define ENV_LOGFILE "NVIM_LOG_FILE"
#define ENV_NVIM "NVIM"
