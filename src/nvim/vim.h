/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

#ifndef NVIM_VIM_H
# define NVIM_VIM_H

#include "nvim/types.h"

/* Included when ported to cmake */
/* This is needed to replace TRUE/FALSE macros by true/false from c99 */
#include <stdbool.h>
/* Some defines from the old feature.h */
#define SESSION_FILE "Session.vim"
#define MAX_MSG_HIST_LEN 200
#define SYS_OPTWIN_FILE "$VIMRUNTIME/optwin.vim"
#define RUNTIME_DIRNAME "runtime"
/* end */

/* ============ the header file puzzle (ca. 50-100 pieces) ========= */

#ifdef HAVE_CONFIG_H    /* GNU autoconf (or something else) was here */
# include "auto/config.h"
# define HAVE_PATHDEF

/*
 * Check if configure correctly managed to find sizeof(int).  If this failed,
 * it becomes zero.  This is likely a problem of not being able to run the
 * test program.  Other items from configure may also be wrong then!
 */
# if (SIZEOF_INT == 0)
Error: configure did not run properly.Check auto/config.log.
# endif
#endif

/* user ID of root is usually zero, but not for everybody */
#define ROOT_UID 0


/* Can't use "PACKAGE" here, conflicts with a Perl include file. */
#ifndef VIMPACKAGE
# define VIMPACKAGE     "vim"
#endif

#include "nvim/os_unix_defs.h"       /* bring lots of system header files */

# ifdef HAVE_LOCALE_H
#  include <locale.h>
# endif

/*
 * Maximum length of a path (for non-unix systems) Make it a bit long, to stay
 * on the safe side.  But not too long to put on the stack.
 */
#ifndef MAXPATHL
# ifdef MAXPATHLEN
#  define MAXPATHL  MAXPATHLEN
# else
#  define MAXPATHL  256
# endif
#endif

#define NUMBUFLEN 30        /* length of a buffer to store a number in ASCII */

// Make sure long_u is big enough to hold a pointer.
// On Win64, longs are 32 bits and pointers are 64 bits.
// For printf() and scanf(), we need to take care of long_u specifically.
typedef unsigned long long_u;

/*
 * The characters and attributes cached for the screen.
 */
typedef char_u schar_T;
typedef unsigned short sattr_T;
# define MAX_TYPENR 65535

/*
 * The u8char_T can hold one decoded UTF-8 character.
 * We normally use 32 bits now, since some Asian characters don't fit in 16
 * bits.  u8char_T is only used for displaying, it could be 16 bits to save
 * memory.
 */
# ifdef UNICODE16
typedef uint16_t u8char_T;
# else
typedef uint32_t u8char_T;
# endif

#include "nvim/ascii.h"
#include "nvim/keymap.h"
#include "nvim/term_defs.h"
#include "nvim/macros.h"

#include <errno.h>

#include <assert.h>

#include <inttypes.h>
#include <wctype.h>
#include <stdarg.h>

#if defined(HAVE_SYS_SELECT_H) && \
  (!defined(HAVE_SYS_TIME_H) || defined(SYS_SELECT_WITH_SYS_TIME))
# include <sys/select.h>
#endif

/* ================ end of the header file puzzle =============== */

#ifdef HAVE_WORKING_LIBINTL
#  include <libintl.h>
#  define _(x) gettext((char *)(x))
// XXX do we actually need this?
#  ifdef gettext_noop
#    define N_(x) gettext_noop(x)
#  else
#    define N_(x) x
#  endif
#else
#  define _(x) ((char *)(x))
#  define N_(x) x
#  define bindtextdomain(x, y) /* empty */
#  define bind_textdomain_codeset(x, y) /* empty */
#  define textdomain(x) /* empty */
#endif

/* special attribute addition: Put message in history */
#define MSG_HIST                0x1000

/*
 * values for State
 *
 * The lower bits up to 0x20 are used to distinguish normal/visual/op_pending
 * and cmdline/insert+replace mode.  This is used for mapping.  If none of
 * these bits are set, no mapping is done.
 * The upper bits are used to distinguish between other states.
 */
#define NORMAL          0x01    /* Normal mode, command expected */
#define VISUAL          0x02    /* Visual mode - use get_real_state() */
#define OP_PENDING      0x04    /* Normal mode, operator is pending - use
                                   get_real_state() */
#define CMDLINE         0x08    /* Editing command line */
#define INSERT          0x10    /* Insert mode */
#define LANGMAP         0x20    /* Language mapping, can be combined with
                                   INSERT and CMDLINE */

#define REPLACE_FLAG    0x40    /* Replace mode flag */
#define REPLACE         (REPLACE_FLAG + INSERT)
# define VREPLACE_FLAG  0x80    /* Virtual-replace mode flag */
# define VREPLACE       (REPLACE_FLAG + VREPLACE_FLAG + INSERT)
#define LREPLACE        (REPLACE_FLAG + LANGMAP)

#define NORMAL_BUSY     (0x100 + NORMAL) /* Normal mode, busy with a command */
#define HITRETURN       (0x200 + NORMAL) /* waiting for return or command */
#define ASKMORE         0x300   /* Asking if you want --more-- */
#define SETWSIZE        0x400   /* window size has changed */
#define ABBREV          0x500   /* abbreviation instead of mapping */
#define EXTERNCMD       0x600   /* executing an external command */
#define SHOWMATCH       (0x700 + INSERT) /* show matching paren */
#define CONFIRM         0x800   /* ":confirm" prompt */
#define SELECTMODE      0x1000  /* Select mode, only for mappings */

#define MAP_ALL_MODES   (0x3f | SELECTMODE)     /* all mode bits used for
                                                 * mapping */

/* directions */
#define FORWARD                 1
#define BACKWARD                (-1)
#define FORWARD_FILE            3
#define BACKWARD_FILE           (-3)

/* return values for functions */
#if !(defined(OK) && (OK == 1))
/* OK already defined to 1 in MacOS X curses, skip this */
# define OK                     1
#endif
#define FAIL                    0
#define NOTDONE                 2   /* not OK or FAIL but skipped */


/*
 * values for xp_context when doing command line completion
 */
enum {
  EXPAND_UNSUCCESSFUL = -2,
  EXPAND_OK = -1,
  EXPAND_NOTHING = 0,
  EXPAND_COMMANDS,
  EXPAND_FILES,
  EXPAND_DIRECTORIES,
  EXPAND_SETTINGS,
  EXPAND_BOOL_SETTINGS,
  EXPAND_TAGS,
  EXPAND_OLD_SETTING,
  EXPAND_HELP,
  EXPAND_BUFFERS,
  EXPAND_EVENTS,
  EXPAND_MENUS,
  EXPAND_SYNTAX,
  EXPAND_HIGHLIGHT,
  EXPAND_AUGROUP,
  EXPAND_USER_VARS,
  EXPAND_MAPPINGS,
  EXPAND_TAGS_LISTFILES,
  EXPAND_FUNCTIONS,
  EXPAND_USER_FUNC,
  EXPAND_EXPRESSION,
  EXPAND_MENUNAMES,
  EXPAND_USER_COMMANDS,
  EXPAND_USER_CMD_FLAGS,
  EXPAND_USER_NARGS,
  EXPAND_USER_COMPLETE,
  EXPAND_ENV_VARS,
  EXPAND_LANGUAGE,
  EXPAND_COLORS,
  EXPAND_COMPILER,
  EXPAND_USER_DEFINED,
  EXPAND_USER_LIST,
  EXPAND_SHELLCMD,
  EXPAND_CSCOPE,
  EXPAND_SIGN,
  EXPAND_PROFILE,
  EXPAND_BEHAVE,
  EXPAND_FILETYPE,
  EXPAND_FILES_IN_PATH,
  EXPAND_OWNSYNTAX,
  EXPAND_LOCALES,
  EXPAND_HISTORY,
  EXPAND_USER,
  EXPAND_SYNTIME,
};

/* Values for exmode_active (0 is no exmode) */
#define EXMODE_NORMAL           1
#define EXMODE_VIM              2

#ifdef NO_EXPANDPATH
# define gen_expand_wildcards mch_expand_wildcards
#endif


/*
 * arguments for gui_set_shellsize()
 */
#define RESIZE_VERT     1       /* resize vertically */
#define RESIZE_HOR      2       /* resize horizontally */
#define RESIZE_BOTH     15      /* resize in both directions */

/*
 * "flags" values for option-setting functions.
 * When OPT_GLOBAL and OPT_LOCAL are both missing, set both local and global
 * values, get local value.
 */
#define OPT_FREE        1       /* free old value if it was allocated */
#define OPT_GLOBAL      2       /* use global value */
#define OPT_LOCAL       4       /* use local value */
#define OPT_MODELINE    8       /* option in modeline */
#define OPT_WINONLY     16      /* only set window-local options */
#define OPT_NOWIN       32      /* don't set window-local options */

/* Magic chars used in confirm dialog strings */
#define DLG_BUTTON_SEP  '\n'
#define DLG_HOTKEY_CHAR '&'

/* Values for "starting" */
#define NO_SCREEN       2       /* no screen updating yet */
#define NO_BUFFERS      1       /* not all buffers loaded yet */
/*			0	   not starting anymore */

/* Values for swap_exists_action: what to do when swap file already exists */
#define SEA_NONE        0       /* don't use dialog */
#define SEA_DIALOG      1       /* use dialog when possible */
#define SEA_QUIT        2       /* quit editing the file */
#define SEA_RECOVER     3       /* recover the file */

/*
 * Minimal size for block 0 of a swap file.
 * NOTE: This depends on size of struct block0! It's not done with a sizeof(),
 * because struct block0 is defined in memline.c (Sorry).
 * The maximal block size is arbitrary.
 */
#define MIN_SWAP_PAGE_SIZE 1048
#define MAX_SWAP_PAGE_SIZE 50000

/* Special values for current_SID. */
#define SID_MODELINE    -1      /* when using a modeline */
#define SID_CMDARG      -2      /* for "--cmd" argument */
#define SID_CARG        -3      /* for "-c" argument */
#define SID_ENV         -4      /* for sourcing environment variable */
#define SID_ERROR       -5      /* option was reset because of an error */
#define SID_NONE        -6      /* don't set scriptID */

/*
 * Values for index in highlight_attr[].
 * When making changes, also update HL_FLAGS below!  And update the default
 * value of 'highlight' in option.c.
 */
typedef enum {
  HLF_8 = 0         /* Meta & special keys listed with ":map", text that is
                       displayed different from what it is */
  , HLF_AT          /* @ and ~ characters at end of screen, characters that
                       don't really exist in the text */
  , HLF_D           /* directories in CTRL-D listing */
  , HLF_E           /* error messages */
  , HLF_I           /* incremental search */
  , HLF_L           /* last search string */
  , HLF_M           /* "--More--" message */
  , HLF_CM          /* Mode (e.g., "-- INSERT --") */
  , HLF_N           /* line number for ":number" and ":#" commands */
  , HLF_CLN         /* current line number */
  , HLF_R           /* return to continue message and yes/no questions */
  , HLF_S           /* status lines */
  , HLF_SNC         /* status lines of not-current windows */
  , HLF_C           /* column to separate vertically split windows */
  , HLF_T           /* Titles for output from ":set all", ":autocmd" etc. */
  , HLF_V           /* Visual mode */
  , HLF_VNC         /* Visual mode, autoselecting and not clipboard owner */
  , HLF_W           /* warning messages */
  , HLF_WM          /* Wildmenu highlight */
  , HLF_FL          /* Folded line */
  , HLF_FC          /* Fold column */
  , HLF_ADD         /* Added diff line */
  , HLF_CHD         /* Changed diff line */
  , HLF_DED         /* Deleted diff line */
  , HLF_TXD         /* Text Changed in diff line */
  , HLF_CONCEAL     /* Concealed text */
  , HLF_SC          /* Sign column */
  , HLF_SPB         /* SpellBad */
  , HLF_SPC         /* SpellCap */
  , HLF_SPR         /* SpellRare */
  , HLF_SPL         /* SpellLocal */
  , HLF_PNI         /* popup menu normal item */
  , HLF_PSI         /* popup menu selected item */
  , HLF_PSB         /* popup menu scrollbar */
  , HLF_PST         /* popup menu scrollbar thumb */
  , HLF_TP          /* tabpage line */
  , HLF_TPS         /* tabpage line selected */
  , HLF_TPF         /* tabpage line filler */
  , HLF_CUC         /* 'cursurcolumn' */
  , HLF_CUL         /* 'cursurline' */
  , HLF_MC          /* 'colorcolumn' */
  , HLF_COUNT       /* MUST be the last one */
} hlf_T;

/* The HL_FLAGS must be in the same order as the HLF_ enums!
 * When changing this also adjust the default for 'highlight'. */
#define HL_FLAGS {'8', '@', 'd', 'e', 'i', 'l', 'm', 'M', 'n', 'N', 'r', 's', \
                  'S', 'c', 't', 'v', 'V', 'w', 'W', 'f', 'F', 'A', 'C', 'D', \
                  'T', '-', '>', 'B', 'P', 'R', 'L', '+', '=', 'x', 'X', '*', \
                  '#', '_', '!', '.', 'o'}

/*
 * Boolean constants
 */
#ifndef TRUE
# define FALSE  0           /* note: this is an int, not a long! */
# define TRUE   1
#endif

#define MAYBE   2           /* sometimes used for a variant on TRUE */

/*
 * Motion types, used for operators and for yank/delete registers.
 */
#define MCHAR   0               /* character-wise movement/register */
#define MLINE   1               /* line-wise movement/register */
#define MBLOCK  2               /* block-wise register */

#define MAUTO   0xff            /* Decide between MLINE/MCHAR */

#define STATUS_HEIGHT   1       /* height of a status line under a window */
#define QF_WINHEIGHT    10      /* default height for quickfix window */

/*
 * Buffer sizes
 */
#ifndef CMDBUFFSIZE
# define CMDBUFFSIZE    256     /* size of the command processing buffer */
#endif

#define LSIZE       512         /* max. size of a line in the tags file */

#define IOSIZE     (1024+1)     /* file i/o and sprintf buffer size */

#define DIALOG_MSG_SIZE 1000    /* buffer size for dialog_msg() */

# define MSG_BUF_LEN 480        /* length of buffer for small messages */
# define MSG_BUF_CLEN  (MSG_BUF_LEN / 6)    /* cell length (worst case: utf-8
                                               takes 6 bytes for one cell) */


/*
 * Maximum length of key sequence to be mapped.
 * Must be able to hold an Amiga resize report.
 */
#define MAXMAPLEN   50

/* Size in bytes of the hash used in the undo file. */
#define UNDO_HASH_SIZE 32

#ifdef HAVE_FCNTL_H
# include <fcntl.h>
#endif

#ifdef BINARY_FILE_IO
# define WRITEBIN   "wb"        /* no CR-LF translation */
# define READBIN    "rb"
# define APPENDBIN  "ab"
#else
# define WRITEBIN   "w"
# define READBIN    "r"
# define APPENDBIN  "a"
#endif

#ifndef O_NOFOLLOW
# define O_NOFOLLOW 0
#endif

/*
 * defines to avoid typecasts from (char_u *) to (char *) and back
 * (vim_strchr() and vim_strrchr() are now in alloc.c)
 */
#define STRLEN(s)           strlen((char *)(s))
#define STRCPY(d, s)        strcpy((char *)(d), (char *)(s))
#define STRNCPY(d, s, n)    strncpy((char *)(d), (char *)(s), (size_t)(n))
#define STRCMP(d, s)        strcmp((char *)(d), (char *)(s))
#define STRNCMP(d, s, n)    strncmp((char *)(d), (char *)(s), (size_t)(n))
#ifdef HAVE_STRCASECMP
# define STRICMP(d, s)      strcasecmp((char *)(d), (char *)(s))
#else
# ifdef HAVE_STRICMP
#  define STRICMP(d, s)     stricmp((char *)(d), (char *)(s))
# else
#  define STRICMP(d, s)     vim_stricmp((char *)(d), (char *)(s))
# endif
#endif

/* Like strcpy() but allows overlapped source and destination. */
#define STRMOVE(d, s)       memmove((d), (s), STRLEN(s) + 1)

#ifdef HAVE_STRNCASECMP
# define STRNICMP(d, s, n)  strncasecmp((char *)(d), (char *)(s), (size_t)(n))
#else
# ifdef HAVE_STRNICMP
#  define STRNICMP(d, s, n) strnicmp((char *)(d), (char *)(s), (size_t)(n))
# else
#  define STRNICMP(d, s, n) vim_strnicmp((char *)(d), (char *)(s), (size_t)(n))
# endif
#endif

/* We need to call mb_stricmp() even when we aren't dealing with a multi-byte
 * encoding because mb_stricmp() takes care of all ascii and non-ascii
 * encodings, including characters with umlauts in latin1, etc., while
 * STRICMP() only handles the system locale version, which often does not
 * handle non-ascii properly. */

# define MB_STRICMP(d, s)       mb_strnicmp((char_u *)(d), (char_u *)(s), \
    (int)MAXCOL)
# define MB_STRNICMP(d, s, n)   mb_strnicmp((char_u *)(d), (char_u *)(s), \
    (int)(n))

#define STRCAT(d, s)        strcat((char *)(d), (char *)(s))
#define STRNCAT(d, s, n)    strncat((char *)(d), (char *)(s), (size_t)(n))

# define vim_strpbrk(s, cs) (char_u *)strpbrk((char *)(s), (char *)(cs))

#define MSG(s)                      msg((char_u *)(s))
#define MSG_ATTR(s, attr)           msg_attr((char_u *)(s), (attr))
#define EMSG(s)                     emsg((char_u *)(s))
#define EMSG2(s, p)                 emsg2((char_u *)(s), (char_u *)(p))
#define EMSG3(s, p, q)              emsg3((char_u *)(s), (char_u *)(p), \
    (char_u *)(q))
#define EMSGN(s, n)                 emsgn((char_u *)(s), (int64_t)(n))
#define EMSGU(s, n)                 emsgu((char_u *)(s), (uint64_t)(n))
#define OUT_STR(s)                  out_str((char_u *)(s))
#define OUT_STR_NF(s)               out_str_nf((char_u *)(s))
#define MSG_PUTS(s)                 msg_puts((char_u *)(s))
#define MSG_PUTS_ATTR(s, a)         msg_puts_attr((char_u *)(s), (a))
#define MSG_PUTS_TITLE(s)           msg_puts_title((char_u *)(s))
#define MSG_PUTS_LONG(s)            msg_puts_long_attr((char_u *)(s), 0)
#define MSG_PUTS_LONG_ATTR(s, a)    msg_puts_long_attr((char_u *)(s), (a))

/* Prefer using emsg3(), because perror() may send the output to the wrong
 * destination and mess up the screen. */
#define PERROR(msg) \
  (void) emsg3((char_u *) "%s: %s", (char_u *)msg, (char_u *)strerror(errno))

typedef long linenr_T;                  /* line number type */
typedef int colnr_T;                    /* column number type */
typedef unsigned short disptick_T;      /* display tick type */

#define MAXLNUM (0x7fffffffL)           /* maximum (invalid) line number */
#define MAXCOL (0x7fffffffL)          /* maximum column number, 31 bits */

#define SHOWCMD_COLS 10                 /* columns needed by shown command */
#define STL_MAX_ITEM 80                 /* max nr of %<flag> in statusline */

typedef void        *vim_acl_T;         /* dummy to pass an ACL to a function */

/*
 * fnamecmp() is used to compare file names.
 * On some systems case in a file name does not matter, on others it does.
 * (this does not account for maximum name lengths and things like "../dir",
 * thus it is not 100% accurate!)
 */
#define fnamecmp(x, y) vim_fnamecmp((char_u *)(x), (char_u *)(y))
#define fnamencmp(x, y, n) vim_fnamencmp((char_u *)(x), (char_u *)(y), \
    (size_t)(n))

#if defined(UNIX) || defined(FEAT_GUI)
# define USE_INPUT_BUF
#endif

#ifndef EINTR
# define read_eintr(fd, buf, count) vim_read((fd), (buf), (count))
# define write_eintr(fd, buf, count) vim_write((fd), (buf), (count))
#endif

# define vim_read(fd, buf, count)   read((fd), (char *)(buf), (size_t) (count))
# define vim_write(fd, buf, count)  write((fd), (char *)(buf), (size_t) (count))

/*
 * Enums need a typecast to be used as array index (for Ultrix).
 */
#define hl_attr(n)      highlight_attr[(int)(n)]
#define term_str(n)     term_strings[(int)(n)]

/*
 * vim_iswhite() is used for "^" and the like. It differs from isspace()
 * because it doesn't include <CR> and <LF> and the like.
 */
#define vim_iswhite(x)  ((x) == ' ' || (x) == '\t')

/*
 * EXTERN is only defined in main.c.  That's where global variables are
 * actually defined and initialized.
 */
#ifndef EXTERN
# define EXTERN extern
# define INIT(x)
#else
# ifndef INIT
#  define INIT(x) x
#  define DO_INIT
# endif
#endif

# define MAX_MCO        6       /* maximum value for 'maxcombine' */

/* Maximum number of bytes in a multi-byte character.  It can be one 32-bit
 * character of up to 6 bytes, or one 16-bit character of up to three bytes
 * plus six following composing characters of three bytes each. */
# define MB_MAXBYTES    21

typedef struct timeval proftime_T;

/* Values for "do_profiling". */
#define PROF_NONE       0       /* profiling not started */
#define PROF_YES        1       /* profiling busy */
#define PROF_PAUSED     2       /* profiling paused */


/* Codes for mouse button events in lower three bits: */
# define MOUSE_LEFT     0x00
# define MOUSE_MIDDLE   0x01
# define MOUSE_RIGHT    0x02
# define MOUSE_RELEASE  0x03

/* bit masks for modifiers: */
# define MOUSE_SHIFT    0x04
# define MOUSE_ALT      0x08
# define MOUSE_CTRL     0x10

/* mouse buttons that are handled like a key press (GUI only) */
/* Note that the scroll wheel keys are inverted: MOUSE_5 scrolls lines up but
 * the result of this is that the window moves down, similarly MOUSE_6 scrolls
 * columns left but the window moves right. */
# define MOUSE_4        0x100   /* scroll wheel down */
# define MOUSE_5        0x200   /* scroll wheel up */

# define MOUSE_X1       0x300 /* Mouse-button X1 (6th) */
# define MOUSE_X2       0x400 /* Mouse-button X2 */

# define MOUSE_6        0x500   /* scroll wheel left */
# define MOUSE_7        0x600   /* scroll wheel right */

/* 0x20 is reserved by xterm */
# define MOUSE_DRAG_XTERM   0x40

# define MOUSE_DRAG     (0x40 | MOUSE_RELEASE)

/* Lowest button code for using the mouse wheel (xterm only) */
# define MOUSEWHEEL_LOW         0x60

# define MOUSE_CLICK_MASK       0x03

# define NUM_MOUSE_CLICKS(code) \
  (((unsigned)((code) & 0xC0) >> 6) + 1)

# define SET_NUM_MOUSE_CLICKS(code, num) \
  (code) = ((code) & 0x3f) | ((((num) - 1) & 3) << 6)

/* Added to mouse column for GUI when 'mousefocus' wants to give focus to a
 * window by simulating a click on its status line.  We could use up to 128 *
 * 128 = 16384 columns, now it's reduced to 10000. */
# define MOUSE_COLOFF 10000

# if defined(UNIX) && defined(HAVE_GETTIMEOFDAY) && defined(HAVE_SYS_TIME_H)
#  define CHECK_DOUBLE_CLICK 1  /* Checking for double clicks ourselves. */
# endif



typedef int VimClipboard;       /* This is required for the prototypes. */


#include "nvim/buffer_defs.h"         /* buffer and windows */
#include "nvim/ex_cmds_defs.h"        /* Ex command defines */
#include "nvim/proto.h"          /* function prototypes */

/* This has to go after the include of proto.h, as proto/gui.pro declares
 * functions of these names. The declarations would break if the defines had
 * been seen at that stage.  But it must be before globals.h, where error_ga
 * is declared. */
#if !defined(FEAT_GUI_W32) && !defined(FEAT_GUI_X11) \
  && !defined(FEAT_GUI_GTK) && !defined(FEAT_GUI_MAC)
# define mch_errmsg(str)        fprintf(stderr, "%s", (str))
# define display_errors()       fflush(stderr)
# define mch_msg(str)           printf("%s", (str))
#else
# define USE_MCH_ERRMSG
#endif




#include "nvim/globals.h"        /* global variables and messages */


# ifdef USE_ICONV
#  ifndef EILSEQ
#   define EILSEQ 123
#  endif
#  ifdef DYNAMIC_ICONV
/* On Win32 iconv.dll is dynamically loaded. */
#   define ICONV_ERRNO (*iconv_errno())
#   define ICONV_E2BIG  7
#   define ICONV_EINVAL 22
#   define ICONV_EILSEQ 42
#  else
#   define ICONV_ERRNO errno
#   define ICONV_E2BIG  E2BIG
#   define ICONV_EINVAL EINVAL
#   define ICONV_EILSEQ EILSEQ
#  endif
# endif


/* ISSYMLINK(mode) tests if a file is a symbolic link. */
#if (defined(S_IFMT) && defined(S_IFLNK)) || defined(S_ISLNK)
# define HAVE_ISSYMLINK
# if defined(S_IFMT) && defined(S_IFLNK)
#  define ISSYMLINK(mode) (((mode) & S_IFMT) == S_IFLNK)
# else
#  define ISSYMLINK(mode) S_ISLNK(mode)
# endif
#endif

#define SIGN_BYTE 1         /* byte value used where sign is displayed;
                               attribute value is sign type */


#  define X_DISPLAY     xterm_dpy


# undef NBDEBUG
# define nbdebug(a)






/* Return values from win32_fileinfo(). */
#define FILEINFO_OK          0
#define FILEINFO_ENC_FAIL    1  /* enc_to_utf16() failed */
#define FILEINFO_READ_FAIL   2  /* CreateFile() failed */
#define FILEINFO_INFO_FAIL   3  /* GetFileInformationByHandle() failed */


# define SET_NO_HLSEARCH(flag) no_hlsearch = (flag); set_vim_var_nr( \
    VV_HLSEARCH, !no_hlsearch)

#endif /* NVIM_VIM_H */
