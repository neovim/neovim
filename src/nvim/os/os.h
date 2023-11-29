#pragma once

#include <stddef.h>  // IWYU pragma: keep
#include <stdint.h>  // IWYU pragma: keep
#include <uv.h>  // IWYU pragma: keep

#include "nvim/buffer_defs.h"  // IWYU pragma: keep
#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/garray_defs.h"  // IWYU pragma: keep
#include "nvim/os/os_defs.h"  // IWYU pragma: export
#include "nvim/os/stdpaths_defs.h"  // IWYU pragma: keep

#define HAVE_PATHDEF

// Some file names are stored in pathdef.c, which is generated from the
// Makefile to make their value depend on the Makefile.
#ifdef HAVE_PATHDEF
extern char *default_vim_dir;
extern char *default_vimruntime_dir;
extern char *default_lib_dir;
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
// IWYU pragma: begin_exports
# include "os/env.h.generated.h"
# include "os/mem.h.generated.h"
# include "os/stdpaths.h.generated.h"
# include "os/users.h.generated.h"
// IWYU pragma: end_exports
#endif

#define ENV_LOGFILE "NVIM_LOG_FILE"
#define ENV_NVIM "NVIM"
