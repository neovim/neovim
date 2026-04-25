#pragma once

#include <stddef.h>
#include <stdint.h>
#include <uv.h>

#include "nvim/cmdexpand_defs.h"
#include "nvim/garray_defs.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/stdpaths_defs.h"
#include "nvim/types_defs.h"

// True if when running in a test environment ($NVIM_TEST).
// TODO(justinmk): Can we use v:testing instead?
EXTERN bool nvim_testing INIT( = false);
extern char *default_vim_dir;
extern char *default_vimruntime_dir;
extern char *default_lib_dir;

// IWYU pragma: begin_exports
#include "os/env.h.generated.h"
#include "os/mem.h.generated.h"
#include "os/stdpaths.h.generated.h"
#include "os/users.h.generated.h"
// IWYU pragma: end_exports

#define ENV_LOGFILE "NVIM_LOG_FILE"
#define ENV_NVIM "NVIM"
