#pragma once

// Some defines from the old feature.h
#define SESSION_FILE "Session.vim"
#define MAX_MSG_HIST_LEN 200
#define SYS_OPTWIN_FILE "$VIMRUNTIME/optwin.vim"
#define RUNTIME_DIRNAME "runtime"

#include "auto/config.h"

// Check if configure correctly managed to find sizeof(int).  If this failed,
// it becomes zero.  This is likely a problem of not being able to run the
// test program.  Other items from configure may also be wrong then!
#if (SIZEOF_INT == 0)
# error Configure did not run properly.
#endif

// bring lots of system header files
#include "nvim/os/os_defs.h"  // IWYU pragma: keep

/// length of a buffer to store a number in ASCII (64 bits binary + NUL)
enum { NUMBUFLEN = 65, };

#define MAX_TYPENR 65535

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
