/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

#ifndef NEOVIM_VIM_H
# define NEOVIM_VIM_H

#include "types.h"

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

/*
 * Cygwin may have fchdir() in a newer release, but in most versions it
 * doesn't work well and avoiding it keeps the binary backward compatible.
 */

/* We may need to define the uint32_t on non-Unix system, but using the same
 * identifier causes conflicts.  Therefore use UINT32_T. */
# define UINT32_TYPEDEF uint32_t
#endif

#if !defined(UINT32_TYPEDEF)
# if defined(uint32_t)  /* this doesn't catch typedefs, unfortunately */
#  define UINT32_TYPEDEF uint32_t
# else
/* Fall back to assuming unsigned int is 32 bit.  If this is wrong then the
 * test in blowfish.c will fail. */
#  define UINT32_TYPEDEF unsigned int
# endif
#endif

/* user ID of root is usually zero, but not for everybody */
# define ROOT_UID 0


/* Can't use "PACKAGE" here, conflicts with a Perl include file. */
#ifndef VIMPACKAGE
# define VIMPACKAGE     "vim"
#endif

#include "os_unix_defs.h"       /* bring lots of system header files */

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
#ifdef BACKSLASH_IN_FILENAME
# define PATH_ESC_CHARS ((char_u *)" \t\n*?[{`%#'\"|!<")
#else
#  define PATH_ESC_CHARS ((char_u *)" \t\n*?[{`$\\%#'\"|!<")
#  define SHELL_ESC_CHARS ((char_u *)" \t\n*?[{`$\\%#'\"|!<>();&")
#endif

#define NUMBUFLEN 30        /* length of a buffer to store a number in ASCII */

/* Make sure long_u is big enough to hold a pointer.
 * On Win64, longs are 32 bits and pointers are 64 bits.
 * For printf() and scanf(), we need to take care of long_u specifically. */
/* Microsoft-specific. The __w64 keyword should be specified on any typedefs
 * that change size between 32-bit and 64-bit platforms.  For any such type,
 * __w64 should appear only on the 32-bit definition of the typedef.
 * Define __w64 as an empty token for everything but MSVC 7.x or later.
 */
#  define __w64
typedef unsigned long __w64 long_u;
typedef          long __w64 long_i;
# define SCANF_HEX_LONG_U       "%lx"
# define SCANF_DECIMAL_LONG_U   "%lu"
# define PRINTF_HEX_LONG_U      "0x%lx"
#define PRINTF_DECIMAL_LONG_U SCANF_DECIMAL_LONG_U

/*
 * Only systems which use configure will have SIZEOF_OFF_T and SIZEOF_LONG
 * defined, which is ok since those are the same systems which can have
 * varying sizes for off_t.  The other systems will continue to use "%ld" to
 * print off_t since off_t is simply a typedef to long for them.
 */
#if defined(SIZEOF_OFF_T) && (SIZEOF_OFF_T > SIZEOF_LONG)
# define LONG_LONG_OFF_T
#endif

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
typedef unsigned short u8char_T;    /* short should be 16 bits */
# else
#  if SIZEOF_INT >= 4
typedef unsigned int u8char_T;      /* int is 32 bits */
#  else
typedef unsigned long u8char_T;     /* long should be 32 bits or more */
#  endif
# endif

#include "ascii.h"
#include "keymap.h"
#include "term_defs.h"
#include "macros.h"

#include <errno.h>

#include <assert.h>

#ifdef HAVE_STDINT_H
# include <stdint.h>
#endif
#ifdef HAVE_INTTYPES_H
# include <inttypes.h>
#endif
#ifdef HAVE_WCTYPE_H
# include <wctype.h>
#endif
#ifdef HAVE_STDARG_H
# include <stdarg.h>
#endif

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

/*
 * flags for update_screen()
 * The higher the value, the higher the priority
 */
#define VALID                   10  /* buffer not changed, or changes marked
                                       with b_mod_* */
#define INVERTED                20  /* redisplay inverted part that changed */
#define INVERTED_ALL            25  /* redisplay whole inverted part */
#define REDRAW_TOP              30  /* display first w_upd_rows screen lines */
#define SOME_VALID              35  /* like NOT_VALID but may scroll */
#define NOT_VALID               40  /* buffer needs complete redraw */
#define CLEAR                   50  /* screen messed up, clear it */

/*
 * Flags for w_valid.
 * These are set when something in a window structure becomes invalid, except
 * when the cursor is moved.  Call check_cursor_moved() before testing one of
 * the flags.
 * These are reset when that thing has been updated and is valid again.
 *
 * Every function that invalidates one of these must call one of the
 * invalidate_* functions.
 *
 * w_valid is supposed to be used only in screen.c.  From other files, use the
 * functions that set or reset the flags.
 *
 * VALID_BOTLINE    VALID_BOTLINE_AP
 *     on		on		w_botline valid
 *     off		on		w_botline approximated
 *     off		off		w_botline not valid
 *     on		off		not possible
 */
#define VALID_WROW      0x01    /* w_wrow (window row) is valid */
#define VALID_WCOL      0x02    /* w_wcol (window col) is valid */
#define VALID_VIRTCOL   0x04    /* w_virtcol (file col) is valid */
#define VALID_CHEIGHT   0x08    /* w_cline_height and w_cline_folded valid */
#define VALID_CROW      0x10    /* w_cline_row is valid */
#define VALID_BOTLINE   0x20    /* w_botine and w_empty_rows are valid */
#define VALID_BOTLINE_AP 0x40   /* w_botine is approximated */
#define VALID_TOPLINE   0x80    /* w_topline is valid (for cursor position) */

/*
 * Terminal highlighting attribute bits.
 * Attributes above HL_ALL are used for syntax highlighting.
 */
#define HL_NORMAL               0x00
#define HL_INVERSE              0x01
#define HL_BOLD                 0x02
#define HL_ITALIC               0x04
#define HL_UNDERLINE            0x08
#define HL_UNDERCURL            0x10
#define HL_STANDOUT             0x20
#define HL_ALL                  0x3f

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

/* flags for b_flags */
#define BF_RECOVERED    0x01    /* buffer has been recovered */
#define BF_CHECK_RO     0x02    /* need to check readonly when loading file
                                   into buffer (set by ":e", may be reset by
                                   ":buf" */
#define BF_NEVERLOADED  0x04    /* file has never been loaded into buffer,
                                   many variables still need to be set */
#define BF_NOTEDITED    0x08    /* Set when file name is changed after
                                   starting to edit, reset when file is
                                   written out. */
#define BF_NEW          0x10    /* file didn't exist when editing started */
#define BF_NEW_W        0x20    /* Warned for BF_NEW and file created */
#define BF_READERR      0x40    /* got errors while reading the file */
#define BF_DUMMY        0x80    /* dummy buffer, only used internally */
#define BF_PRESERVED    0x100   /* ":preserve" was used */

/* Mask to check for flags that prevent normal writing */
#define BF_WRITE_MASK   (BF_NOTEDITED + BF_NEW + BF_READERR)

/*
 * values for xp_context when doing command line completion
 */
#define EXPAND_UNSUCCESSFUL     (-2)
#define EXPAND_OK               (-1)
#define EXPAND_NOTHING          0
#define EXPAND_COMMANDS         1
#define EXPAND_FILES            2
#define EXPAND_DIRECTORIES      3
#define EXPAND_SETTINGS         4
#define EXPAND_BOOL_SETTINGS    5
#define EXPAND_TAGS             6
#define EXPAND_OLD_SETTING      7
#define EXPAND_HELP             8
#define EXPAND_BUFFERS          9
#define EXPAND_EVENTS           10
#define EXPAND_MENUS            11
#define EXPAND_SYNTAX           12
#define EXPAND_HIGHLIGHT        13
#define EXPAND_AUGROUP          14
#define EXPAND_USER_VARS        15
#define EXPAND_MAPPINGS         16
#define EXPAND_TAGS_LISTFILES   17
#define EXPAND_FUNCTIONS        18
#define EXPAND_USER_FUNC        19
#define EXPAND_EXPRESSION       20
#define EXPAND_MENUNAMES        21
#define EXPAND_USER_COMMANDS    22
#define EXPAND_USER_CMD_FLAGS   23
#define EXPAND_USER_NARGS       24
#define EXPAND_USER_COMPLETE    25
#define EXPAND_ENV_VARS         26
#define EXPAND_LANGUAGE         27
#define EXPAND_COLORS           28
#define EXPAND_COMPILER         29
#define EXPAND_USER_DEFINED     30
#define EXPAND_USER_LIST        31
#define EXPAND_SHELLCMD         32
#define EXPAND_CSCOPE           33
#define EXPAND_SIGN             34
#define EXPAND_PROFILE          35
#define EXPAND_BEHAVE           36
#define EXPAND_FILETYPE         37
#define EXPAND_FILES_IN_PATH    38
#define EXPAND_OWNSYNTAX        39
#define EXPAND_LOCALES          40
#define EXPAND_HISTORY          41
#define EXPAND_USER             42
#define EXPAND_SYNTIME          43

/* Values for exmode_active (0 is no exmode) */
#define EXMODE_NORMAL           1
#define EXMODE_VIM              2

/* Values for nextwild() and ExpandOne().  See ExpandOne() for meaning. */
#define WILD_FREE               1
#define WILD_EXPAND_FREE        2
#define WILD_EXPAND_KEEP        3
#define WILD_NEXT               4
#define WILD_PREV               5
#define WILD_ALL                6
#define WILD_LONGEST            7
#define WILD_ALL_KEEP           8

#define WILD_LIST_NOTFOUND      1
#define WILD_HOME_REPLACE       2
#define WILD_USE_NL             4
#define WILD_NO_BEEP            8
#define WILD_ADD_SLASH          16
#define WILD_KEEP_ALL           32
#define WILD_SILENT             64
#define WILD_ESCAPE             128
#define WILD_ICASE              256

/* Flags for expand_wildcards() */
#define EW_DIR          0x01    /* include directory names */
#define EW_FILE         0x02    /* include file names */
#define EW_NOTFOUND     0x04    /* include not found names */
#define EW_ADDSLASH     0x08    /* append slash to directory name */
#define EW_KEEPALL      0x10    /* keep all matches */
#define EW_SILENT       0x20    /* don't print "1 returned" from shell */
#define EW_EXEC         0x40    /* executable files */
#define EW_PATH         0x80    /* search in 'path' too */
#define EW_ICASE        0x100   /* ignore case */
#define EW_NOERROR      0x200   /* no error for bad regexp */
#define EW_NOTWILD      0x400   /* add match with literal name if exists */
/* Note: mostly EW_NOTFOUND and EW_SILENT are mutually exclusive: EW_NOTFOUND
* is used when executing commands and EW_SILENT for interactive expanding. */

/* Flags for find_file_*() functions. */
#define FINDFILE_FILE   0       /* only files */
#define FINDFILE_DIR    1       /* only directories */
#define FINDFILE_BOTH   2       /* files and directories */

# define W_WINCOL(wp)   (wp->w_wincol)
# define W_WIDTH(wp)    (wp->w_width)
# define W_ENDCOL(wp)   (wp->w_wincol + wp->w_width)
# define W_VSEP_WIDTH(wp) (wp->w_vsep_width)
# define W_STATUS_HEIGHT(wp) (wp->w_status_height)
# define W_WINROW(wp)   (wp->w_winrow)

#ifdef NO_EXPANDPATH
# define gen_expand_wildcards mch_expand_wildcards
#endif

/* Values for the find_pattern_in_path() function args 'type' and 'action': */
#define FIND_ANY        1
#define FIND_DEFINE     2
#define CHECK_PATH      3

#define ACTION_SHOW     1
#define ACTION_GOTO     2
#define ACTION_SPLIT    3
#define ACTION_SHOW_ALL 4
# define ACTION_EXPAND  5

# define SST_MIN_ENTRIES 150    /* minimal size for state stack array */
#  define SST_MAX_ENTRIES 1000  /* maximal size for state stack array */
# define SST_FIX_STATES  7      /* size of sst_stack[]. */
# define SST_DIST        16     /* normal distance between entries */
# define SST_INVALID    (synstate_T *)-1        /* invalid syn_state pointer */

# define HL_CONTAINED   0x01    /* not used on toplevel */
# define HL_TRANSP      0x02    /* has no highlighting	*/
# define HL_ONELINE     0x04    /* match within one line only */
# define HL_HAS_EOL     0x08    /* end pattern that matches with $ */
# define HL_SYNC_HERE   0x10    /* sync point after this item (syncing only) */
# define HL_SYNC_THERE  0x20    /* sync point at current line (syncing only) */
# define HL_MATCH       0x40    /* use match ID instead of item ID */
# define HL_SKIPNL      0x80    /* nextgroup can skip newlines */
# define HL_SKIPWHITE   0x100   /* nextgroup can skip white space */
# define HL_SKIPEMPTY   0x200   /* nextgroup can skip empty lines */
# define HL_KEEPEND     0x400   /* end match always kept */
# define HL_EXCLUDENL   0x800   /* exclude NL from match */
# define HL_DISPLAY     0x1000  /* only used for displaying, not syncing */
# define HL_FOLD        0x2000  /* define fold */
# define HL_EXTEND      0x4000  /* ignore a keepend */
# define HL_MATCHCONT   0x8000  /* match continued from previous line */
# define HL_TRANS_CONT  0x10000 /* transparent item without contains arg */
# define HL_CONCEAL     0x20000 /* can be concealed */
# define HL_CONCEALENDS 0x40000 /* can be concealed */

/* Values for 'options' argument in do_search() and searchit() */
#define SEARCH_REV    0x01  /* go in reverse of previous dir. */
#define SEARCH_ECHO   0x02  /* echo the search command and handle options */
#define SEARCH_MSG    0x0c  /* give messages (yes, it's not 0x04) */
#define SEARCH_NFMSG  0x08  /* give all messages except not found */
#define SEARCH_OPT    0x10  /* interpret optional flags */
#define SEARCH_HIS    0x20  /* put search pattern in history */
#define SEARCH_END    0x40  /* put cursor at end of match */
#define SEARCH_NOOF   0x80  /* don't add offset to position */
#define SEARCH_START 0x100  /* start search without col offset */
#define SEARCH_MARK  0x200  /* set previous context mark */
#define SEARCH_KEEP  0x400  /* keep previous search pattern */
#define SEARCH_PEEK  0x800  /* peek for typed char, cancel search */

/* Values for find_ident_under_cursor() */
#define FIND_IDENT      1       /* find identifier (word) */
#define FIND_STRING     2       /* find any string (WORD) */
#define FIND_EVAL       4       /* include "->", "[]" and "." */

/* Values for file_name_in_line() */
#define FNAME_MESS      1       /* give error message */
#define FNAME_EXP       2       /* expand to path */
#define FNAME_HYP       4       /* check for hypertext link */
#define FNAME_INCL      8       /* apply 'includeexpr' */
#define FNAME_REL       16      /* ".." and "./" are relative to the (current)
                                   file instead of the current directory */

/* Values for buflist_getfile() */
#define GETF_SETMARK    0x01    /* set pcmark before jumping */
#define GETF_ALT        0x02    /* jumping to alternate file (not buf num) */
#define GETF_SWITCH     0x04    /* respect 'switchbuf' settings when jumping */

/* Values for buflist_new() flags */
#define BLN_CURBUF      1       /* May re-use curbuf for new buffer */
#define BLN_LISTED      2       /* Put new buffer in buffer list */
#define BLN_DUMMY       4       /* Allocating dummy buffer */

/* Values for in_cinkeys() */
#define KEY_OPEN_FORW   0x101
#define KEY_OPEN_BACK   0x102
#define KEY_COMPLETE    0x103   /* end of completion */

/* Values for "noremap" argument of ins_typebuf().  Also used for
 * map->m_noremap and menu->noremap[]. */
#define REMAP_YES       0       /* allow remapping */
#define REMAP_NONE      -1      /* no remapping */
#define REMAP_SCRIPT    -2      /* remap script-local mappings only */
#define REMAP_SKIP      -3      /* no remapping for first char */

/* Values for mch_call_shell() second argument */
#define SHELL_FILTER    1       /* filtering text */
#define SHELL_EXPAND    2       /* expanding wildcards */
#define SHELL_COOKED    4       /* set term to cooked mode */
#define SHELL_DOOUT     8       /* redirecting output */
#define SHELL_SILENT    16      /* don't print error returned by command */
#define SHELL_READ      32      /* read lines and insert into buffer */
#define SHELL_WRITE     64      /* write lines from buffer */

/* Values returned by mch_nodetype() */
#define NODE_NORMAL     0       /* file or directory, check with mch_isdir()*/
#define NODE_WRITABLE   1       /* something we can write to (character
                                   device, fifo, socket, ..) */
#define NODE_OTHER      2       /* non-writable thing (e.g., block device) */

/* Values for readfile() flags */
#define READ_NEW        0x01    /* read a file into a new buffer */
#define READ_FILTER     0x02    /* read filter output */
#define READ_STDIN      0x04    /* read from stdin */
#define READ_BUFFER     0x08    /* read from curbuf (converting stdin) */
#define READ_DUMMY      0x10    /* reading into a dummy buffer */
#define READ_KEEP_UNDO  0x20    /* keep undo info*/

/* Values for change_indent() */
#define INDENT_SET      1       /* set indent */
#define INDENT_INC      2       /* increase indent */
#define INDENT_DEC      3       /* decrease indent */

/* Values for flags argument for findmatchlimit() */
#define FM_BACKWARD     0x01    /* search backwards */
#define FM_FORWARD      0x02    /* search forwards */
#define FM_BLOCKSTOP    0x04    /* stop at start/end of block */
#define FM_SKIPCOMM     0x08    /* skip comments */

/* Values for action argument for do_buffer() */
#define DOBUF_GOTO      0       /* go to specified buffer */
#define DOBUF_SPLIT     1       /* split window and go to specified buffer */
#define DOBUF_UNLOAD    2       /* unload specified buffer(s) */
#define DOBUF_DEL       3       /* delete specified buffer(s) from buflist */
#define DOBUF_WIPE      4       /* delete specified buffer(s) really */

/* Values for start argument for do_buffer() */
#define DOBUF_CURRENT   0       /* "count" buffer from current buffer */
#define DOBUF_FIRST     1       /* "count" buffer from first buffer */
#define DOBUF_LAST      2       /* "count" buffer from last buffer */
#define DOBUF_MOD       3       /* "count" mod. buffer from current buffer */

/* Values for sub_cmd and which_pat argument for search_regcomp() */
/* Also used for which_pat argument for searchit() */
#define RE_SEARCH       0       /* save/use pat in/from search_pattern */
#define RE_SUBST        1       /* save/use pat in/from subst_pattern */
#define RE_BOTH         2       /* save pat in both patterns */
#define RE_LAST         2       /* use last used pattern if "pat" is NULL */

/* Second argument for vim_regcomp(). */
#define RE_MAGIC        1       /* 'magic' option */
#define RE_STRING       2       /* match in string instead of buffer text */
#define RE_STRICT       4       /* don't allow [abc] without ] */

/* values for reg_do_extmatch */
# define REX_SET        1       /* to allow \z\(...\), */
# define REX_USE        2       /* to allow \z\1 et al. */

/* Return values for fullpathcmp() */
/* Note: can use (fullpathcmp() & FPC_SAME) to check for equal files */
#define FPC_SAME        1       /* both exist and are the same file. */
#define FPC_DIFF        2       /* both exist and are different files. */
#define FPC_NOTX        4       /* both don't exist. */
#define FPC_DIFFX       6       /* one of them doesn't exist. */
#define FPC_SAMEX       7       /* both don't exist and file names are same. */

/* flags for do_ecmd() */
#define ECMD_HIDE       0x01    /* don't free the current buffer */
#define ECMD_SET_HELP   0x02    /* set b_help flag of (new) buffer before
                                   opening file */
#define ECMD_OLDBUF     0x04    /* use existing buffer if it exists */
#define ECMD_FORCEIT    0x08    /* ! used in Ex command */
#define ECMD_ADDBUF     0x10    /* don't edit, just add to buffer list */

/* for lnum argument in do_ecmd() */
#define ECMD_LASTL      (linenr_T)0     /* use last position in loaded file */
#define ECMD_LAST       (linenr_T)-1    /* use last position in all files */
#define ECMD_ONE        (linenr_T)1     /* use first line */

/* flags for do_cmdline() */
#define DOCMD_VERBOSE   0x01    /* included command in error message */
#define DOCMD_NOWAIT    0x02    /* don't call wait_return() and friends */
#define DOCMD_REPEAT    0x04    /* repeat exec. until getline() returns NULL */
#define DOCMD_KEYTYPED  0x08    /* don't reset KeyTyped */
#define DOCMD_EXCRESET  0x10    /* reset exception environment (for debugging)*/
#define DOCMD_KEEPLINE  0x20    /* keep typed line for repeating with "." */

/* flags for beginline() */
#define BL_WHITE        1       /* cursor on first non-white in the line */
#define BL_SOL          2       /* use 'sol' option */
#define BL_FIX          4       /* don't leave cursor on a NUL */

/* flags for mf_sync() */
#define MFS_ALL         1       /* also sync blocks with negative numbers */
#define MFS_STOP        2       /* stop syncing when a character is available */
#define MFS_FLUSH       4       /* flushed file to disk */
#define MFS_ZERO        8       /* only write block 0 */

/* flags for buf_copy_options() */
#define BCO_ENTER       1       /* going to enter the buffer */
#define BCO_ALWAYS      2       /* always copy the options */
#define BCO_NOHELP      4       /* don't touch the help related options */

/* flags for do_put() */
#define PUT_FIXINDENT   1       /* make indent look nice */
#define PUT_CURSEND     2       /* leave cursor after end of new text */
#define PUT_CURSLINE    4       /* leave cursor on last line of new text */
#define PUT_LINE        8       /* put register as lines */
#define PUT_LINE_SPLIT  16      /* split line for linewise register */
#define PUT_LINE_FORWARD 32     /* put linewise register below Visual sel. */

/* flags for set_indent() */
#define SIN_CHANGED     1       /* call changed_bytes() when line changed */
#define SIN_INSERT      2       /* insert indent before existing text */
#define SIN_UNDO        4       /* save line for undo before changing it */

/* flags for insertchar() */
#define INSCHAR_FORMAT  1       /* force formatting */
#define INSCHAR_DO_COM  2       /* format comments */
#define INSCHAR_CTRLV   4       /* char typed just after CTRL-V */
#define INSCHAR_NO_FEX  8       /* don't use 'formatexpr' */
#define INSCHAR_COM_LIST 16     /* format comments with list/2nd line indent */

/* flags for open_line() */
#define OPENLINE_DELSPACES  1   /* delete spaces after cursor */
#define OPENLINE_DO_COM     2   /* format comments */
#define OPENLINE_KEEPTRAIL  4   /* keep trailing spaces */
#define OPENLINE_MARKFIX    8   /* fix mark positions */
#define OPENLINE_COM_LIST  16   /* format comments with list/2nd line indent */

/*
 * There are four history tables:
 */
#define HIST_CMD        0       /* colon commands */
#define HIST_SEARCH     1       /* search commands */
#define HIST_EXPR       2       /* expressions (from entering = register) */
#define HIST_INPUT      3       /* input() lines */
#define HIST_DEBUG      4       /* debug commands */
#define HIST_COUNT      5       /* number of history tables */

/*
 * Flags for chartab[].
 */
#define CT_CELL_MASK    0x07    /* mask: nr of display cells (1, 2 or 4) */
#define CT_PRINT_CHAR   0x10    /* flag: set for printable chars */
#define CT_ID_CHAR      0x20    /* flag: set for ID chars */
#define CT_FNAME_CHAR   0x40    /* flag: set for file name chars */

/*
 * Values for do_tag().
 */
#define DT_TAG          1       /* jump to newer position or same tag again */
#define DT_POP          2       /* jump to older position */
#define DT_NEXT         3       /* jump to next match of same tag */
#define DT_PREV         4       /* jump to previous match of same tag */
#define DT_FIRST        5       /* jump to first match of same tag */
#define DT_LAST         6       /* jump to first match of same tag */
#define DT_SELECT       7       /* jump to selection from list */
#define DT_HELP         8       /* like DT_TAG, but no wildcards */
#define DT_JUMP         9       /* jump to new tag or selection from list */
#define DT_CSCOPE       10      /* cscope find command (like tjump) */
#define DT_LTAG         11      /* tag using location list */
#define DT_FREE         99      /* free cached matches */

/*
 * flags for find_tags().
 */
#define TAG_HELP        1       /* only search for help tags */
#define TAG_NAMES       2       /* only return name of tag */
#define TAG_REGEXP      4       /* use tag pattern as regexp */
#define TAG_NOIC        8       /* don't always ignore case */
# define TAG_CSCOPE     16      /* cscope tag */
#define TAG_VERBOSE     32      /* message verbosity */
#define TAG_INS_COMP    64      /* Currently doing insert completion */
#define TAG_KEEP_LANG   128     /* keep current language */

#define TAG_MANY        300     /* When finding many tags (for completion),
                                   find up to this many tags */

/*
 * Types of dialogs passed to do_vim_dialog().
 */
#define VIM_GENERIC     0
#define VIM_ERROR       1
#define VIM_WARNING     2
#define VIM_INFO        3
#define VIM_QUESTION    4
#define VIM_LAST_TYPE   4       /* sentinel value */

/*
 * Return values for functions like gui_yesnocancel()
 */
#define VIM_YES         2
#define VIM_NO          3
#define VIM_CANCEL      4
#define VIM_ALL         5
#define VIM_DISCARDALL  6

/*
 * arguments for win_split()
 */
#define WSP_ROOM        1       /* require enough room */
#define WSP_VERT        2       /* split vertically */
#define WSP_TOP         4       /* window at top-left of shell */
#define WSP_BOT         8       /* window at bottom-right of shell */
#define WSP_HELP        16      /* creating the help window */
#define WSP_BELOW       32      /* put new window below/right */
#define WSP_ABOVE       64      /* put new window above/left */
#define WSP_NEWLOC      128     /* don't copy location list */

/*
 * arguments for gui_set_shellsize()
 */
#define RESIZE_VERT     1       /* resize vertically */
#define RESIZE_HOR      2       /* resize horizontally */
#define RESIZE_BOTH     15      /* resize in both directions */

/*
 * flags for check_changed()
 */
#define CCGD_AW         1       /* do autowrite if buffer was changed */
#define CCGD_MULTWIN    2       /* check also when several wins for the buf */
#define CCGD_FORCEIT    4       /* ! used */
#define CCGD_ALLBUF     8       /* may write all buffers */
#define CCGD_EXCMD      16      /* may suggest using ! */

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
 * Events for autocommands.
 */
enum auto_event {
  EVENT_BUFADD = 0,             /* after adding a buffer to the buffer list */
  EVENT_BUFNEW,                 /* after creating any buffer */
  EVENT_BUFDELETE,              /* deleting a buffer from the buffer list */
  EVENT_BUFWIPEOUT,             /* just before really deleting a buffer */
  EVENT_BUFENTER,               /* after entering a buffer */
  EVENT_BUFFILEPOST,            /* after renaming a buffer */
  EVENT_BUFFILEPRE,             /* before renaming a buffer */
  EVENT_BUFLEAVE,               /* before leaving a buffer */
  EVENT_BUFNEWFILE,             /* when creating a buffer for a new file */
  EVENT_BUFREADPOST,            /* after reading a buffer */
  EVENT_BUFREADPRE,             /* before reading a buffer */
  EVENT_BUFREADCMD,             /* read buffer using command */
  EVENT_BUFUNLOAD,              /* just before unloading a buffer */
  EVENT_BUFHIDDEN,              /* just after buffer becomes hidden */
  EVENT_BUFWINENTER,            /* after showing a buffer in a window */
  EVENT_BUFWINLEAVE,            /* just after buffer removed from window */
  EVENT_BUFWRITEPOST,           /* after writing a buffer */
  EVENT_BUFWRITEPRE,            /* before writing a buffer */
  EVENT_BUFWRITECMD,            /* write buffer using command */
  EVENT_CMDWINENTER,            /* after entering the cmdline window */
  EVENT_CMDWINLEAVE,            /* before leaving the cmdline window */
  EVENT_COLORSCHEME,            /* after loading a colorscheme */
  EVENT_COMPLETEDONE,           /* after finishing insert complete */
  EVENT_FILEAPPENDPOST,         /* after appending to a file */
  EVENT_FILEAPPENDPRE,          /* before appending to a file */
  EVENT_FILEAPPENDCMD,          /* append to a file using command */
  EVENT_FILECHANGEDSHELL,       /* after shell command that changed file */
  EVENT_FILECHANGEDSHELLPOST,   /* after (not) reloading changed file */
  EVENT_FILECHANGEDRO,          /* before first change to read-only file */
  EVENT_FILEREADPOST,           /* after reading a file */
  EVENT_FILEREADPRE,            /* before reading a file */
  EVENT_FILEREADCMD,            /* read from a file using command */
  EVENT_FILETYPE,               /* new file type detected (user defined) */
  EVENT_FILEWRITEPOST,          /* after writing a file */
  EVENT_FILEWRITEPRE,           /* before writing a file */
  EVENT_FILEWRITECMD,           /* write to a file using command */
  EVENT_FILTERREADPOST,         /* after reading from a filter */
  EVENT_FILTERREADPRE,          /* before reading from a filter */
  EVENT_FILTERWRITEPOST,        /* after writing to a filter */
  EVENT_FILTERWRITEPRE,         /* before writing to a filter */
  EVENT_FOCUSGAINED,            /* got the focus */
  EVENT_FOCUSLOST,              /* lost the focus to another app */
  EVENT_GUIENTER,               /* after starting the GUI */
  EVENT_GUIFAILED,              /* after starting the GUI failed */
  EVENT_INSERTCHANGE,           /* when changing Insert/Replace mode */
  EVENT_INSERTENTER,            /* when entering Insert mode */
  EVENT_INSERTLEAVE,            /* when leaving Insert mode */
  EVENT_MENUPOPUP,              /* just before popup menu is displayed */
  EVENT_QUICKFIXCMDPOST,        /* after :make, :grep etc. */
  EVENT_QUICKFIXCMDPRE,         /* before :make, :grep etc. */
  EVENT_QUITPRE,                /* before :quit */
  EVENT_SESSIONLOADPOST,        /* after loading a session file */
  EVENT_STDINREADPOST,          /* after reading from stdin */
  EVENT_STDINREADPRE,           /* before reading from stdin */
  EVENT_SYNTAX,                 /* syntax selected */
  EVENT_TERMCHANGED,            /* after changing 'term' */
  EVENT_TERMRESPONSE,           /* after setting "v:termresponse" */
  EVENT_USER,                   /* user defined autocommand */
  EVENT_VIMENTER,               /* after starting Vim */
  EVENT_VIMLEAVE,               /* before exiting Vim */
  EVENT_VIMLEAVEPRE,            /* before exiting Vim and writing .viminfo */
  EVENT_VIMRESIZED,             /* after Vim window was resized */
  EVENT_WINENTER,               /* after entering a window */
  EVENT_WINLEAVE,               /* before leaving a window */
  EVENT_ENCODINGCHANGED,        /* after changing the 'encoding' option */
  EVENT_INSERTCHARPRE,          /* before inserting a char */
  EVENT_CURSORHOLD,             /* cursor in same position for a while */
  EVENT_CURSORHOLDI,            /* idem, in Insert mode */
  EVENT_FUNCUNDEFINED,          /* if calling a function which doesn't exist */
  EVENT_REMOTEREPLY,            /* upon string reception from a remote vim */
  EVENT_SWAPEXISTS,             /* found existing swap file */
  EVENT_SOURCEPRE,              /* before sourcing a Vim script */
  EVENT_SOURCECMD,              /* sourcing a Vim script using command */
  EVENT_SPELLFILEMISSING,       /* spell file missing */
  EVENT_CURSORMOVED,            /* cursor was moved */
  EVENT_CURSORMOVEDI,           /* cursor was moved in Insert mode */
  EVENT_TABLEAVE,               /* before leaving a tab page */
  EVENT_TABENTER,               /* after entering a tab page */
  EVENT_SHELLCMDPOST,           /* after ":!cmd" */
  EVENT_SHELLFILTERPOST,        /* after ":1,2!cmd", ":w !cmd", ":r !cmd". */
  EVENT_TEXTCHANGED,            /* text was modified */
  EVENT_TEXTCHANGEDI,           /* text was modified in Insert mode*/
  NUM_EVENTS                    /* MUST be the last one */
};

typedef enum auto_event event_T;

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
  , HLF_H           /* obsolete, ignored */
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
#define HL_FLAGS {'8', '@', 'd', 'e', 'h', 'i', 'l', 'm', 'M', \
                  'n', 'N', 'r', 's', 'S', 'c', 't', 'v', 'V', 'w', 'W', \
                  'f', 'F', 'A', 'C', 'D', 'T', '-', '>', \
                  'B', 'P', 'R', 'L', \
                  '+', '=', 'x', 'X', '*', '#', '_', '!', '.', 'o'}

/*
 * Boolean constants
 */
#ifndef TRUE
# define FALSE  0           /* note: this is an int, not a long! */
# define TRUE   1
#endif

#define MAYBE   2           /* sometimes used for a variant on TRUE */

#ifndef UINT32_T
typedef UINT32_TYPEDEF UINT32_T;
#endif

/*
 * Operator IDs; The order must correspond to opchars[] in ops.c!
 */
#define OP_NOP          0       /* no pending operation */
#define OP_DELETE       1       /* "d"  delete operator */
#define OP_YANK         2       /* "y"  yank operator */
#define OP_CHANGE       3       /* "c"  change operator */
#define OP_LSHIFT       4       /* "<"  left shift operator */
#define OP_RSHIFT       5       /* ">"  right shift operator */
#define OP_FILTER       6       /* "!"  filter operator */
#define OP_TILDE        7       /* "g~" switch case operator */
#define OP_INDENT       8       /* "="  indent operator */
#define OP_FORMAT       9       /* "gq" format operator */
#define OP_COLON        10      /* ":"  colon operator */
#define OP_UPPER        11      /* "gU" make upper case operator */
#define OP_LOWER        12      /* "gu" make lower case operator */
#define OP_JOIN         13      /* "J"  join operator, only for Visual mode */
#define OP_JOIN_NS      14      /* "gJ"  join operator, only for Visual mode */
#define OP_ROT13        15      /* "g?" rot-13 encoding */
#define OP_REPLACE      16      /* "r"  replace chars, only for Visual mode */
#define OP_INSERT       17      /* "I"  Insert column, only for Visual mode */
#define OP_APPEND       18      /* "A"  Append column, only for Visual mode */
#define OP_FOLD         19      /* "zf" define a fold */
#define OP_FOLDOPEN     20      /* "zo" open folds */
#define OP_FOLDOPENREC  21      /* "zO" open folds recursively */
#define OP_FOLDCLOSE    22      /* "zc" close folds */
#define OP_FOLDCLOSEREC 23      /* "zC" close folds recursively */
#define OP_FOLDDEL      24      /* "zd" delete folds */
#define OP_FOLDDELREC   25      /* "zD" delete folds recursively */
#define OP_FORMAT2      26      /* "gw" format operator, keeps cursor pos */
#define OP_FUNCTION     27      /* "g@" call 'operatorfunc' */

/*
 * Motion types, used for operators and for yank/delete registers.
 */
#define MCHAR   0               /* character-wise movement/register */
#define MLINE   1               /* line-wise movement/register */
#define MBLOCK  2               /* block-wise register */

#define MAUTO   0xff            /* Decide between MLINE/MCHAR */

/*
 * Minimum screen size
 */
#define MIN_COLUMNS     12      /* minimal columns for screen */
#define MIN_LINES       2       /* minimal lines for screen */
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

/* Size of the buffer used for tgetent().  Unfortunately this is largely
 * undocumented, some systems use 1024.  Using a buffer that is too small
 * causes a buffer overrun and a crash.  Use the maximum known value to stay
 * on the safe side. */
#define TBUFSZ 2048             /* buffer size for termcap entry */

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

/*
 * EMX doesn't have a global way of making open() use binary I/O.
 * Use O_BINARY for all open() calls.
 */
# define O_EXTRA    0

#ifndef O_NOFOLLOW
# define O_NOFOLLOW 0
#endif

#ifndef W_OK
# define W_OK 2         /* for systems that don't have W_OK in unistd.h */
#endif
#ifndef R_OK
# define R_OK 4         /* for systems that don't have R_OK in unistd.h */
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
#define STRMOVE(d, s)       mch_memmove((d), (s), STRLEN(s) + 1)

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

#ifdef HAVE_STRPBRK
# define vim_strpbrk(s, cs) (char_u *)strpbrk((char *)(s), (char *)(cs))
#endif

#define MSG(s)                      msg((char_u *)(s))
#define MSG_ATTR(s, attr)           msg_attr((char_u *)(s), (attr))
#define EMSG(s)                     emsg((char_u *)(s))
#define EMSG2(s, p)                 emsg2((char_u *)(s), (char_u *)(p))
#define EMSG3(s, p, q)              emsg3((char_u *)(s), (char_u *)(p), \
    (char_u *)(q))
#define EMSGN(s, n)                 emsgn((char_u *)(s), (long)(n))
#define EMSGU(s, n)                 emsgu((char_u *)(s), (long_u)(n))
#define OUT_STR(s)                  out_str((char_u *)(s))
#define OUT_STR_NF(s)               out_str_nf((char_u *)(s))
#define MSG_PUTS(s)                 msg_puts((char_u *)(s))
#define MSG_PUTS_ATTR(s, a)         msg_puts_attr((char_u *)(s), (a))
#define MSG_PUTS_TITLE(s)           msg_puts_title((char_u *)(s))
#define MSG_PUTS_LONG(s)            msg_puts_long_attr((char_u *)(s), 0)
#define MSG_PUTS_LONG_ATTR(s, a)    msg_puts_long_attr((char_u *)(s), (a))

/* Prefer using emsg3(), because perror() may send the output to the wrong
 * destination and mess up the screen. */
#ifdef HAVE_STRERROR
# define PERROR(msg)                (void)emsg3((char_u *)"%s: %s", \
    (char_u *)msg, (char_u *)strerror( \
        errno))
#else
# define PERROR(msg)                perror(msg)
#endif

typedef long linenr_T;                  /* line number type */
typedef int colnr_T;                    /* column number type */
typedef unsigned short disptick_T;      /* display tick type */

#define MAXLNUM (0x7fffffffL)           /* maximum (invalid) line number */

/*
 * Well, you won't believe it, but some S/390 machines ("host", now also known
 * as zServer) use 31 bit pointers. There are also some newer machines, that
 * use 64 bit pointers. I don't know how to distinguish between 31 and 64 bit
 * machines, so the best way is to assume 31 bits whenever we detect OS/390
 * Unix.
 * With this we restrict the maximum line length to 1073741823. I guess this is
 * not a real problem. BTW:  Longer lines are split.
 */
#if SIZEOF_INT >= 4
# ifdef __MVS__
#  define MAXCOL (0x3fffffffL)          /* maximum column number, 30 bits */
# else
#  define MAXCOL (0x7fffffffL)          /* maximum column number, 31 bits */
# endif
#else
# define MAXCOL (0x7fff)                /* maximum column number, 15 bits */
#endif

#define SHOWCMD_COLS 10                 /* columns needed by shown command */
#define STL_MAX_ITEM 80                 /* max nr of %<flag> in statusline */

typedef void        *vim_acl_T;         /* dummy to pass an ACL to a function */

/*
 * Include a prototype for mch_memmove(), it may not be in alloc.pro.
 */
#ifdef VIM_MEMMOVE
void mch_memmove(void *, void *, size_t);
#else
# ifndef mch_memmove
#  define mch_memmove(to, from, len) memmove(to, from, len)
# endif
#endif

/*
 * fnamecmp() is used to compare file names.
 * On some systems case in a file name does not matter, on others it does.
 * (this does not account for maximum name lengths and things like "../dir",
 * thus it is not 100% accurate!)
 */
#define fnamecmp(x, y) vim_fnamecmp((char_u *)(x), (char_u *)(y))
#define fnamencmp(x, y, n) vim_fnamencmp((char_u *)(x), (char_u *)(y), \
    (size_t)(n))

#ifdef HAVE_MEMSET
# define vim_memset(ptr, c, size)   memset((ptr), (c), (size))
#else
void *vim_memset(void *, int, size_t);
#endif

#ifdef HAVE_MEMCMP
# define vim_memcmp(p1, p2, len)   memcmp((p1), (p2), (len))
#else
# ifdef HAVE_BCMP
#  define vim_memcmp(p1, p2, len)   bcmp((p1), (p2), (len))
# else
int vim_memcmp(void *, void *, size_t);
#  define VIM_MEMCMP
# endif
#endif

#if defined(UNIX) || defined(FEAT_GUI) || defined(OS2) || defined(VMS) \
  || defined(FEAT_CLIENTSERVER)
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

/* Include option_defs.h before structs.h, because the number of window-local and
 * buffer-local options is used there. */
#include "option_defs.h"         /* options and default values */

/* Note that gui.h is included by structs.h */

#include "structs.h"        /* file that defines many structures */

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

/*
 * jump_to_mouse() returns one of first four these values, possibly with
 * some of the other three added.
 */
# define IN_UNKNOWN             0
# define IN_BUFFER              1
# define IN_STATUS_LINE         2       /* on status or command line */
# define IN_SEP_LINE            4       /* on vertical separator line */
# define IN_OTHER_WIN           8       /* in other window but can't go there */
# define CURSOR_MOVED           0x100
# define MOUSE_FOLD_CLOSE       0x200   /* clicked on '-' in fold column */
# define MOUSE_FOLD_OPEN        0x400   /* clicked on '+' in fold column */

/* flags for jump_to_mouse() */
# define MOUSE_FOCUS            0x01    /* need to stay in this window */
# define MOUSE_MAY_VIS          0x02    /* may start Visual mode */
# define MOUSE_DID_MOVE         0x04    /* only act when mouse has moved */
# define MOUSE_SETPOS           0x08    /* only set current mouse position */
# define MOUSE_MAY_STOP_VIS     0x10    /* may stop Visual mode */
# define MOUSE_RELEASED         0x20    /* button was released */

# if defined(UNIX) && defined(HAVE_GETTIMEOFDAY) && defined(HAVE_SYS_TIME_H)
#  define CHECK_DOUBLE_CLICK 1  /* Checking for double clicks ourselves. */
# endif


/* defines for eval_vars() */
#define VALID_PATH              1
#define VALID_HEAD              2

/* Defines for Vim variables.  These must match vimvars[] in eval.c! */
#define VV_COUNT        0
#define VV_COUNT1       1
#define VV_PREVCOUNT    2
#define VV_ERRMSG       3
#define VV_WARNINGMSG   4
#define VV_STATUSMSG    5
#define VV_SHELL_ERROR  6
#define VV_THIS_SESSION 7
#define VV_VERSION      8
#define VV_LNUM         9
#define VV_TERMRESPONSE 10
#define VV_FNAME        11
#define VV_LANG         12
#define VV_LC_TIME      13
#define VV_CTYPE        14
#define VV_CC_FROM      15
#define VV_CC_TO        16
#define VV_FNAME_IN     17
#define VV_FNAME_OUT    18
#define VV_FNAME_NEW    19
#define VV_FNAME_DIFF   20
#define VV_CMDARG       21
#define VV_FOLDSTART    22
#define VV_FOLDEND      23
#define VV_FOLDDASHES   24
#define VV_FOLDLEVEL    25
#define VV_PROGNAME     26
#define VV_SEND_SERVER  27
#define VV_DYING        28
#define VV_EXCEPTION    29
#define VV_THROWPOINT   30
#define VV_REG          31
#define VV_CMDBANG      32
#define VV_INSERTMODE   33
#define VV_VAL          34
#define VV_KEY          35
#define VV_PROFILING    36
#define VV_FCS_REASON   37
#define VV_FCS_CHOICE   38
#define VV_BEVAL_BUFNR  39
#define VV_BEVAL_WINNR  40
#define VV_BEVAL_LNUM   41
#define VV_BEVAL_COL    42
#define VV_BEVAL_TEXT   43
#define VV_SCROLLSTART  44
#define VV_SWAPNAME     45
#define VV_SWAPCHOICE   46
#define VV_SWAPCOMMAND  47
#define VV_CHAR         48
#define VV_MOUSE_WIN    49
#define VV_MOUSE_LNUM   50
#define VV_MOUSE_COL    51
#define VV_OP           52
#define VV_SEARCHFORWARD 53
#define VV_HLSEARCH     54
#define VV_OLDFILES     55
#define VV_WINDOWID     56
#define VV_LEN          57      /* number of v: vars */

typedef int VimClipboard;       /* This is required for the prototypes. */


#include "ex_cmds_defs.h"        /* Ex command defines */
#include "proto.h"          /* function prototypes */

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




#include "globals.h"        /* global variables and messages */



/*
 * If console dialog not supported, but GUI dialog is, use the GUI one.
 */

/*
 * Default filters for gui_mch_browse().
 * The filters are almost system independent.  Except for the difference
 * between "*" and "*.*" for MSDOS-like systems.
 * NOTE: Motif only uses the very first pattern.  Therefore
 * BROWSE_FILTER_DEFAULT should start with a "*" pattern.
 */

/* stop using fastcall for Borland */


/* Note: a NULL argument for vim_realloc() is not portable, don't use it. */
#if defined(MEM_PROFILE)
# define vim_realloc(ptr, size)  mem_realloc((ptr), (size))
#else
# define vim_realloc(ptr, size)  realloc((ptr), (size))
#endif

/*
 * The following macros stop display/event loop nesting at the wrong time.
 */

/*
 * Return byte length of character that starts with byte "b".
 * Returns 1 for a single-byte character.
 * MB_BYTE2LEN_CHECK() can be used to count a special key as one byte.
 * Don't call MB_BYTE2LEN(b) with b < 0 or b > 255!
 */
# define MB_BYTE2LEN(b)         mb_bytelen_tab[b]
# define MB_BYTE2LEN_CHECK(b)   (((b) < 0 || (b) > 255) ? 1 : mb_bytelen_tab[b])

/* properties used in enc_canon_table[] (first three mutually exclusive) */
# define ENC_8BIT       0x01
# define ENC_DBCS       0x02
# define ENC_UNICODE    0x04

# define ENC_ENDIAN_B   0x10        /* Unicode: Big endian */
# define ENC_ENDIAN_L   0x20        /* Unicode: Little endian */

# define ENC_2BYTE      0x40        /* Unicode: UCS-2 */
# define ENC_4BYTE      0x80        /* Unicode: UCS-4 */
# define ENC_2WORD      0x100       /* Unicode: UTF-16 */

# define ENC_LATIN1     0x200       /* Latin1 */
# define ENC_LATIN9     0x400       /* Latin9 */
# define ENC_MACROMAN   0x800       /* Mac Roman (not Macro Man! :-) */

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


/* values for vim_handle_signal() that are not a signal */
#define SIGNAL_BLOCK    -1
#define SIGNAL_UNBLOCK  -2
#if !defined(UNIX) && !defined(VMS) && !defined(OS2)
# define vim_handle_signal(x) 0
#endif

/* flags for skip_vimgrep_pat() */
#define VGR_GLOBAL      1
#define VGR_NOJUMP      2

/* behavior for bad character, "++bad=" argument */
#define BAD_REPLACE     '?'     /* replace it with '?' (default) */
#define BAD_KEEP        -1      /* leave it */
#define BAD_DROP        -2      /* erase it */

/* last argument for do_source() */
#define DOSO_NONE       0
#define DOSO_VIMRC      1       /* loading vimrc file */
#define DOSO_GVIMRC     2       /* loading gvimrc file */

/* flags for read_viminfo() and children */
#define VIF_WANT_INFO           1       /* load non-mark info */
#define VIF_WANT_MARKS          2       /* load file marks */
#define VIF_FORCEIT             4       /* overwrite info already read */
#define VIF_GET_OLDFILES        8       /* load v:oldfiles */

/* flags for buf_freeall() */
#define BFA_DEL         1       /* buffer is going to be deleted */
#define BFA_WIPE        2       /* buffer is going to be wiped out */
#define BFA_KEEP_UNDO   4       /* do not free undo information */

/* direction for nv_mousescroll() and ins_mousescroll() */
#define MSCR_DOWN       0       /* DOWN must be FALSE */
#define MSCR_UP         1
#define MSCR_LEFT       -1
#define MSCR_RIGHT      -2

#define KEYLEN_PART_KEY -1      /* keylen value for incomplete key-code */
#define KEYLEN_PART_MAP -2      /* keylen value for incomplete mapping */
#define KEYLEN_REMOVED  9999    /* keylen value for removed sequence */

/* Return values from win32_fileinfo(). */
#define FILEINFO_OK          0
#define FILEINFO_ENC_FAIL    1  /* enc_to_utf16() failed */
#define FILEINFO_READ_FAIL   2  /* CreateFile() failed */
#define FILEINFO_INFO_FAIL   3  /* GetFileInformationByHandle() failed */

/* Return value from get_option_value_strict */
#define SOPT_BOOL       0x01    /* Boolean option */
#define SOPT_NUM        0x02    /* Number option */
#define SOPT_STRING     0x04    /* String option */
#define SOPT_GLOBAL     0x08    /* Option has global value */
#define SOPT_WIN        0x10    /* Option has window-local value */
#define SOPT_BUF        0x20    /* Option has buffer-local value */
#define SOPT_UNSET      0x40    /* Option does not have local value set */

/* Option types for various functions in option.c */
#define SREQ_GLOBAL     0       /* Request global option */
#define SREQ_WIN        1       /* Request window-local option */
#define SREQ_BUF        2       /* Request buffer-local option */

/* Character used as separated in autoload function/variable names. */
#define AUTOLOAD_CHAR '#'

# define SET_NO_HLSEARCH(flag) no_hlsearch = (flag); set_vim_var_nr( \
    VV_HLSEARCH, !no_hlsearch)

#endif /* NEOVIM_VIM_H */
