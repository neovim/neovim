#pragma once

#include <stddef.h>  // IWYU pragma: keep
#include <stdint.h>  // IWYU pragma: keep
#include <uv.h>  // IWYU pragma: keep

#include "nvim/buffer_defs.h"  // IWYU pragma: keep
#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/garray_defs.h"  // IWYU pragma: keep
#include "nvim/os/os_defs.h"  // IWYU pragma: export
#include "nvim/os/stdpaths_defs.h"  // IWYU pragma: keep

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/env.h.generated.h"
# include "os/mem.h.generated.h"
# include "os/stdpaths.h.generated.h"
# include "os/users.h.generated.h"
#endif

#define ENV_LOGFILE "NVIM_LOG_FILE"
#define ENV_NVIM "NVIM"
