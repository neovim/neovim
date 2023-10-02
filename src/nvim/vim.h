#ifndef NVIM_VIM_H
#define NVIM_VIM_H

#include "nvim/pos.h"
#include "nvim/types.h"

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

#define ROOT_UID 0

#include "nvim/gettext.h"
#include "nvim/keycodes.h"
#include "nvim/macros.h"

// special attribute addition: Put message in history
#define MSG_HIST                0x1000

// Values for State
//
// The lower bits up to 0x80 are used to distinguish normal/visual/op_pending
// /cmdline/insert/replace/terminal mode.  This is used for mapping.  If none
// of these bits are set, no mapping is done.  See the comment above do_map().
// The upper bits are used to distinguish between other states and variants of
// the base modes.

#define MODE_NORMAL          0x01    // Normal mode, command expected
#define MODE_VISUAL          0x02    // Visual mode - use get_real_state()
#define MODE_OP_PENDING      0x04    // Normal mode, operator is pending - use
                                     // get_real_state()
#define MODE_CMDLINE         0x08    // Editing the command line
#define MODE_INSERT          0x10    // Insert mode, also for Replace mode
#define MODE_LANGMAP         0x20    // Language mapping, can be combined with
                                     // MODE_INSERT and MODE_CMDLINE
#define MODE_SELECT          0x40    // Select mode, use get_real_state()
#define MODE_TERMINAL        0x80    // Terminal mode

#define MAP_ALL_MODES        0xff    // all mode bits used for mapping

#define REPLACE_FLAG         0x100   // Replace mode flag
#define MODE_REPLACE         (REPLACE_FLAG | MODE_INSERT)
#define VREPLACE_FLAG        0x200   // Virtual-replace mode flag
#define MODE_VREPLACE        (REPLACE_FLAG | VREPLACE_FLAG | MODE_INSERT)
#define MODE_LREPLACE        (REPLACE_FLAG | MODE_LANGMAP)

#define MODE_NORMAL_BUSY     (0x1000 | MODE_NORMAL)  // Normal mode, busy with a command
#define MODE_HITRETURN       (0x2000 | MODE_NORMAL)  // waiting for return or command
#define MODE_ASKMORE         0x3000  // Asking if you want --more--
#define MODE_SETWSIZE        0x4000  // window size has changed
#define MODE_EXTERNCMD       0x5000  // executing an external command
#define MODE_SHOWMATCH       (0x6000 | MODE_INSERT)  // show matching paren
#define MODE_CONFIRM         0x7000  // ":confirm" prompt

/// Directions.
typedef enum {
  kDirectionNotSet = 0,
  FORWARD = 1,
  BACKWARD = (-1),
  FORWARD_FILE = 3,
  BACKWARD_FILE = (-3),
} Direction;

// return values for functions
#if !(defined(OK) && (OK == 1))
// OK already defined to 1 in MacOS X curses, skip this
# define OK                     1
#endif
#define FAIL                    0
#define NOTDONE                 2   // not OK or FAIL but skipped

// Minimal size for block 0 of a swap file.
// NOTE: This depends on size of struct block0! It's not done with a sizeof(),
// because struct block0 is defined in memline.c (Sorry).
// The maximal block size is arbitrary.
#define MIN_SWAP_PAGE_SIZE 1048
#define MAX_SWAP_PAGE_SIZE 50000

#define STATUS_HEIGHT   1       // height of a status line under a window
#define QF_WINHEIGHT    10      // default height for quickfix window

// Buffer sizes

#ifndef CMDBUFFSIZE
# define CMDBUFFSIZE    256     // size of the command processing buffer
#endif

#define LSIZE       512         // max. size of a line in the tags file

#define DIALOG_MSG_SIZE 1000    // buffer size for dialog_msg()

enum { FOLD_TEXT_LEN = 51, };  //!< buffer size for get_foldtext()

// Maximum length of key sequence to be mapped.
// Must be able to hold an Amiga resize report.

#define MAXMAPLEN   50

// Size in bytes of the hash used in the undo file.
#define UNDO_HASH_SIZE 32

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

// Character used as separated in autoload function/variable names.
#define AUTOLOAD_CHAR '#'

#include "nvim/message.h"

// Prefer using semsg(), because perror() may send the output to the wrong
// destination and mess up the screen.
#define PERROR(msg) (void)semsg("%s: %s", (msg), strerror(errno))

#include "nvim/path.h"

// Enums need a typecast to be used as array index.
#define HL_ATTR(n)      hl_attr_active[(int)(n)]

/// Maximum number of bytes in a multi-byte character.  It can be one 32-bit
/// character of up to 6 bytes, or one 16-bit character of up to three bytes
/// plus six following composing characters of three bytes each.
#define MB_MAXBYTES    21

#ifndef MSWIN
/// Headless (no UI) error message handler.
# define os_errmsg(str)        fprintf(stderr, "%s", (str))
/// Headless (no UI) message handler.
# define os_msg(str)           printf("%s", (str))
#endif

#include "nvim/buffer_defs.h"    // buffer and windows
#include "nvim/ex_cmds_defs.h"   // Ex command defines
#include "nvim/globals.h"        // global variables and messages

// Lowest number used for window ID. Cannot have this many windows per tab.
#define LOWEST_WIN_ID 1000

// BSD is supposed to cover FreeBSD and similar systems.
#if (defined(BSD) || defined(__FreeBSD_kernel__)) \
  && (defined(S_ISCHR) || defined(S_IFCHR))
# define OPEN_CHR_FILES
#endif

// Replacement for nchar used by nv_replace().
#define REPLACE_CR_NCHAR    (-1)
#define REPLACE_NL_NCHAR    (-2)

#endif  // NVIM_VIM_H
