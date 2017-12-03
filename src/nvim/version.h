#ifndef NVIM_VERSION_H
#define NVIM_VERSION_H

#include "nvim/ex_cmds_defs.h"

// defined in version.c
extern char* Version;
extern char* longVersion;

//
// Vim version number, name, etc. Patchlevel is defined in version.c.
//
#define VIM_VERSION_MAJOR                8
#define VIM_VERSION_MINOR                0
#define VIM_VERSION_100     (VIM_VERSION_MAJOR * 100 + VIM_VERSION_MINOR)

// used for the runtime directory name
#define VIM_VERSION_NODOT       "vim80"
// swap file compatibility (max. length is 6 chars)
#define VIM_VERSION_SHORT       "8.0"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "version.h.generated.h"
#endif
#endif  // NVIM_VERSION_H
