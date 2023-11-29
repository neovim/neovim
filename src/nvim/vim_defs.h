#pragma once

#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

// Some defines from the old feature.h
#define SESSION_FILE "Session.vim"
#define MAX_MSG_HIST_LEN 200
#define SYS_OPTWIN_FILE "$VIMRUNTIME/optwin.vim"
#define RUNTIME_DIRNAME "runtime"

#include "auto/config.h"
#define HAVE_PATHDEF

// Some file names are stored in pathdef.c, which is generated from the
// Makefile to make their value depend on the Makefile.
#ifdef HAVE_PATHDEF
extern char *default_vim_dir;
extern char *default_vimruntime_dir;
extern char *default_lib_dir;
#endif

// Check if configure correctly managed to find sizeof(int).  If this failed,
// it becomes zero.  This is likely a problem of not being able to run the
// test program.  Other items from configure may also be wrong then!
#if (SIZEOF_INT == 0)
# error Configure did not run properly.
#endif

#include "nvim/os/os_defs.h"       // bring lots of system header files

/// length of a buffer to store a number in ASCII (64 bits binary + NUL)
enum { NUMBUFLEN = 65, };

#define MAX_TYPENR 65535

#include "nvim/gettext.h"
#include "nvim/keycodes.h"
#include "nvim/macros_defs.h"

/// Directions.
typedef enum {
  kDirectionNotSet = 0,
  FORWARD = 1,
  BACKWARD = -1,
  FORWARD_FILE = 3,
  BACKWARD_FILE = -3,
} Direction;

// return values for functions
#if !(defined(OK) && (OK == 1))
// OK already defined to 1 in MacOS X curses, skip this
# define OK                     1
#endif
#define FAIL                    0
#define NOTDONE                 2   // not OK or FAIL but skipped

#define CLEAR_FIELD(field)  memset(&(field), 0, sizeof(field))
#define CLEAR_POINTER(ptr)  memset((ptr), 0, sizeof(*(ptr)))

// (vim_strchr() is now in strings.c)

#ifndef HAVE_STRNLEN
# define strnlen xstrnlen  // Older versions of SunOS may not have strnlen
#endif

#define STRCPY(d, s)        strcpy((char *)(d), (char *)(s))  // NOLINT(runtime/printf)
#ifdef HAVE_STRCASECMP
# define STRICMP(d, s)      strcasecmp((char *)(d), (char *)(s))
#else
# ifdef HAVE_STRICMP
#  define STRICMP(d, s)     stricmp((char *)(d), (char *)(s))
# else
#  define STRICMP(d, s)     vim_stricmp((char *)(d), (char *)(s))
# endif
#endif

// Like strcpy() but allows overlapped source and destination.
#define STRMOVE(d, s)       memmove((d), (s), strlen(s) + 1)

#ifdef HAVE_STRNCASECMP
# define STRNICMP(d, s, n)  strncasecmp((char *)(d), (char *)(s), (size_t)(n))
#else
# ifdef HAVE_STRNICMP
#  define STRNICMP(d, s, n) strnicmp((char *)(d), (char *)(s), (size_t)(n))
# else
#  define STRNICMP(d, s, n) vim_strnicmp((char *)(d), (char *)(s), (size_t)(n))
# endif
#endif

#define STRCAT(d, s)        strcat((char *)(d), (char *)(s))  // NOLINT(runtime/printf)

// BSD is supposed to cover FreeBSD and similar systems.
#if (defined(BSD) || defined(__FreeBSD_kernel__)) \
  && (defined(S_ISCHR) || defined(S_IFCHR))
# define OPEN_CHR_FILES
#endif
