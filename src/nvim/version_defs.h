#ifndef NVIM_VERSION_DEFS_H
#define NVIM_VERSION_DEFS_H

// VIM - Vi IMproved    by Bram Moolenaar
//
// Do ":help uganda"  in Vim to read copying and usage conditions.
// Do ":help credits" in Vim to see a list of people who contributed.

#define STR_(x) #x
#define STR(x) STR_(x)

//
// Nvim version identifiers
//
#ifndef NVIM_VERSION_MAJOR
#define NVIM_VERSION_MAJOR 0
#endif
#ifndef NVIM_VERSION_MINOR
#define NVIM_VERSION_MINOR 0
#endif
#ifndef NVIM_VERSION_PATCH
#define NVIM_VERSION_PATCH 0
#endif
#ifndef NVIM_VERSION_PRERELEASE
#define NVIM_VERSION_PRERELEASE "?"
#endif
#ifndef NVIM_VERSION_BUILD
#define NVIM_VERSION_BUILD "?"
#endif
#ifndef NVIM_VERSION_COMMIT
#define NVIM_VERSION_COMMIT "?"
#endif
#ifndef NVIM_VERSION_CFLAGS
#define NVIM_VERSION_CFLAGS "?"
#endif
#ifndef NVIM_VERSION_BUILD_TYPE
#define NVIM_VERSION_BUILD_TYPE "?"
#endif
// for the startup-screen
#define NVIM_VERSION_MEDIUM STR(NVIM_VERSION_MAJOR) "." STR(NVIM_VERSION_MINOR)
// for the ":version" command and "nvim -h"
#define NVIM_VERSION_LONG "NVIM " NVIM_VERSION_MEDIUM "." STR(NVIM_VERSION_PATCH) NVIM_VERSION_PRERELEASE NVIM_VERSION_BUILD

//
// Vim version number, name, etc. Patchlevel is defined in version.c.
//
#define VIM_VERSION_MAJOR                7
#define VIM_VERSION_MINOR                4
#define VIM_VERSION_100     (VIM_VERSION_MAJOR * 100 + VIM_VERSION_MINOR)

// used for the runtime directory name
#define VIM_VERSION_NODOT       "vim74"
// swap file compatibility (max. length is 6 chars)
#define VIM_VERSION_SHORT       "7.4"

#endif  // NVIM_VERSION_DEFS_H
