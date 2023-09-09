#ifndef NVIM_OS_OS_DEFS_H
#define NVIM_OS_OS_DEFS_H

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>

// Note: Some systems need both string.h and strings.h (Savage).
#include <string.h>
#ifdef HAVE_STRINGS_H
# include <strings.h>
#endif

#ifdef MSWIN
# include "nvim/os/win_defs.h"
#else
# include "nvim/os/unix_defs.h"
#endif

#ifdef BACKSLASH_IN_FILENAME
# define BACKSLASH_IN_FILENAME_BOOL true
#else
# define BACKSLASH_IN_FILENAME_BOOL false
#endif

#if !defined(NAME_MAX) && defined(_XOPEN_NAME_MAX)
# define NAME_MAX _XOPEN_NAME_MAX
#endif

#define BASENAMELEN (NAME_MAX - 5)

// Use the system path length if it makes sense.
#define DEFAULT_MAXPATHL 4096
#if defined(PATH_MAX) && (PATH_MAX > DEFAULT_MAXPATHL)
# define MAXPATHL PATH_MAX
#else
# define MAXPATHL DEFAULT_MAXPATHL
#endif

// Command-processing buffer. Use large buffers for all platforms.
#define CMDBUFFSIZE 1024

/// Converts libuv error (negative int) to error description string.
#define os_strerror uv_strerror

/// Converts system error code to libuv error code.
#define os_translate_sys_error uv_translate_sys_error

#ifdef MSWIN
# define os_strtok strtok_s
#else
# define os_strtok strtok_r
#endif

// stat macros
#ifndef S_ISDIR
# ifdef S_IFDIR
#  define S_ISDIR(m)    (((m)& S_IFMT) == S_IFDIR)
# else
#  define S_ISDIR(m)    0
# endif
#endif
#ifndef S_ISREG
# ifdef S_IFREG
#  define S_ISREG(m)    (((m)& S_IFMT) == S_IFREG)
# else
#  define S_ISREG(m)    0
# endif
#endif
#ifndef S_ISBLK
# ifdef S_IFBLK
#  define S_ISBLK(m)    (((m)& S_IFMT) == S_IFBLK)
# else
#  define S_ISBLK(m)    0
# endif
#endif
#ifndef S_ISSOCK
# ifdef S_IFSOCK
#  define S_ISSOCK(m)   (((m)& S_IFMT) == S_IFSOCK)
# else
#  define S_ISSOCK(m)   0
# endif
#endif
#ifndef S_ISFIFO
# ifdef S_IFIFO
#  define S_ISFIFO(m)   (((m)& S_IFMT) == S_IFIFO)
# else
#  define S_ISFIFO(m)   0
# endif
#endif
#ifndef S_ISCHR
# ifdef S_IFCHR
#  define S_ISCHR(m)    (((m)& S_IFMT) == S_IFCHR)
# else
#  define S_ISCHR(m)    0
# endif
#endif
#ifndef S_ISLNK
# ifdef S_IFLNK
#  define S_ISLNK(m)    (((m)& S_IFMT) == S_IFLNK)
# else
#  define S_ISLNK(m)    0
# endif
#endif

#endif  // NVIM_OS_OS_DEFS_H
