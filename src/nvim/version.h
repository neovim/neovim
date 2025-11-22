#pragma once

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"

// defined in version.c
extern char *Version;
extern char *longVersion;
#ifndef NDEBUG
extern char *version_cflags;
#endif

//
// Vim version number, name, etc. Patchlevel is defined in version.c.
//

// swap file compatibility (max. length is 6 chars)
#define VIM_VERSION_SHORT "8.1"

#include "version.h.generated.h"
