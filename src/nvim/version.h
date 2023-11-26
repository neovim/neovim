#pragma once

#include "nvim/ex_cmds_defs.h"
#include "nvim/macros.h"

// defined in version.c
extern char *Version;
extern char *longVersion;
#ifndef NDEBUG
extern char *version_cflags;
#endif

//
// Vim version number, name, etc. Patchlevel is defined in version.c.
//

// Values that change for a new release
#define VIM_VERSION_MAJOR                8
#define VIM_VERSION_MINOR                1

// Values based on the above
#define VIM_VERSION_MAJOR_STR STR(VIM_VERSION_MAJOR)
#define VIM_VERSION_MINOR_STR STR(VIM_VERSION_MINOR)
#define VIM_VERSION_100     (VIM_VERSION_MAJOR * 100 + VIM_VERSION_MINOR)

// used for the runtime directory name
#define VIM_VERSION_NODOT "vim" VIM_VERSION_MAJOR_STR VIM_VERSION_MINOR_STR
// swap file compatibility (max. length is 6 chars)
#define VIM_VERSION_SHORT VIM_VERSION_MAJOR_STR "." VIM_VERSION_MINOR_STR

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "version.h.generated.h"
#endif
