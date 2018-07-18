#ifndef NVIM_OS_OS_DEFS_H
#define NVIM_OS_OS_DEFS_H

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>

#ifdef WIN32
# include "nvim/os/win_defs.h"
#else
# include "nvim/os/unix_defs.h"
#endif

#define BASENAMELEN (NAME_MAX - 5)

// Use the system path length if it makes sense.
#if defined(PATH_MAX) && (PATH_MAX > 1024)
# define MAXPATHL PATH_MAX
#else
# define MAXPATHL 1024
#endif

// Command-processing buffer. Use large buffers for all platforms.
#define CMDBUFFSIZE 1024

// Note: Some systems need both string.h and strings.h (Savage).  However,
// some systems can't handle both, only use string.h in that case.
#include <string.h>
#if defined(HAVE_STRINGS_H) && !defined(NO_STRINGS_WITH_STRING_H)
# include <strings.h>
#endif

/// Function to convert libuv error to char * error description
///
/// negative libuv error codes are returned by a number of os functions.
#define os_strerror uv_strerror

#ifdef WIN32
# define os_strtok strtok_s
#else
# define os_strtok strtok_r
#endif

#endif  // NVIM_OS_OS_DEFS_H
