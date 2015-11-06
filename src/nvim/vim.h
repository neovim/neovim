/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

#ifndef NVIM_VIM_H
#define NVIM_VIM_H

#include "nvim/types.h"
#include "nvim/pos.h"  // for linenr_T, MAXCOL, etc...

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

#include "nvim/os/os_defs.h"       /* bring lots of system header files */

#define NUMBUFLEN 30        /* length of a buffer to store a number in ASCII */

# define MAX_TYPENR 65535

#include "nvim/keymap.h"
#include "nvim/macros.h"




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
#define TERM_FOCUS      0x2000  // Terminal focus mode

// all mode bits used for mapping
#define MAP_ALL_MODES   (0x3f | SELECTMODE | TERM_FOCUS)

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
  EXPAND_USER_ADDR_TYPE,
};





/*
 * Minimal size for block 0 of a swap file.
 * NOTE: This depends on size of struct block0! It's not done with a sizeof(),
 * because struct block0 is defined in memline.c (Sorry).
 * The maximal block size is arbitrary.
 */
#define MIN_SWAP_PAGE_SIZE 1048
#define MAX_SWAP_PAGE_SIZE 50000



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

#define DIALOG_MSG_SIZE 1000    /* buffer size for dialog_msg() */

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
#define STRLCPY(d, s, n)    xstrlcpy((char *)(d), (char *)(s), (size_t)(n))
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

#define SHOWCMD_COLS 10                 /* columns needed by shown command */
#define STL_MAX_ITEM 80                 /* max nr of %<flag> in statusline */

/*
 * fnamecmp() is used to compare file names.
 * On some systems case in a file name does not matter, on others it does.
 * (this does not account for maximum name lengths and things like "../dir",
 * thus it is not 100% accurate!)
 */
#define fnamecmp(x, y) vim_fnamecmp((char_u *)(x), (char_u *)(y))
#define fnamencmp(x, y, n) vim_fnamencmp((char_u *)(x), (char_u *)(y), \
    (size_t)(n))

/*
 * Enums need a typecast to be used as array index (for Ultrix).
 */
#define hl_attr(n)      highlight_attr[(int)(n)]
#define term_str(n)     term_strings[(int)(n)]

/* Maximum number of bytes in a multi-byte character.  It can be one 32-bit
 * character of up to 6 bytes, or one 16-bit character of up to three bytes
 * plus six following composing characters of three bytes each. */
#define MB_MAXBYTES    21

/* This has to go after the include of proto.h, as proto/gui.pro declares
 * functions of these names. The declarations would break if the defines had
 * been seen at that stage.  But it must be before globals.h, where error_ga
 * is declared. */
#define mch_errmsg(str)        fprintf(stderr, "%s", (str))
#define display_errors()       fflush(stderr)
#define mch_msg(str)           printf("%s", (str))

#include "nvim/globals.h"        /* global variables and messages */
#include "nvim/buffer_defs.h"         /* buffer and windows */
#include "nvim/ex_cmds_defs.h"        /* Ex command defines */

# define SET_NO_HLSEARCH(flag) no_hlsearch = (flag); set_vim_var_nr( \
    VV_HLSEARCH, !no_hlsearch && p_hls)

#endif /* NVIM_VIM_H */
