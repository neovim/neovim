/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */
/*
 *
 * term.c: functions for controlling the terminal
 *
 * primitive termcap support for Amiga, MSDOS, and Win32 included
 *
 * NOTE: padding and variable substitution is not performed,
 * when compiling without HAVE_TGETENT, we use tputs() and tgoto() dummies.
 */

/*
 * Some systems have a prototype for tgetstr() with (char *) instead of
 * (char **). This define removes that prototype. We include our own prototype
 * below.
 */

#define tgetstr tgetstr_defined_wrong
#include "vim.h"
#include "term.h"
#include "buffer.h"
#include "charset.h"
#include "edit.h"
#include "eval.h"
#include "ex_getln.h"
#include "fileio.h"
#include "getchar.h"
#include "message.h"
#include "misc2.h"
#include "garray.h"
#include "move.h"
#include "normal.h"
#include "option.h"
#include "os_unix.h"
#include "popupmnu.h"
#include "screen.h"
#include "syntax.h"
#include "ui.h"
#include "window.h"

#ifdef HAVE_TGETENT
# ifdef HAVE_TERMIOS_H
#  include <termios.h>      /* seems to be required for some Linux */
# endif
# ifdef HAVE_TERMCAP_H
#  include <termcap.h>
# endif

/*
 * A few linux systems define outfuntype in termcap.h to be used as the third
 * argument for tputs().
 */
#   define TPUTSFUNCAST (int (*)())
#endif

#undef tgetstr

/*
 * Here are the builtin termcap entries.  They are not stored as complete
 * structures with all entries, as such a structure is too big.
 *
 * The entries are compact, therefore they normally are included even when
 * HAVE_TGETENT is defined. When HAVE_TGETENT is defined, the builtin entries
 * can be accessed with "builtin_amiga", "builtin_ansi", "builtin_debug", etc.
 *
 * Each termcap is a list of builtin_term structures. It always starts with
 * KS_NAME, which separates the entries.  See parse_builtin_tcap() for all
 * details.
 * bt_entry is either a KS_xxx code (>= 0), or a K_xxx code.
 *
 * Entries marked with "guessed" may be wrong.
 */
struct builtin_term {
  int bt_entry;
  char        *bt_string;
};

/* start of keys that are not directly used by Vim but can be mapped */
#define BT_EXTRA_KEYS   0x101

static struct builtin_term *find_builtin_term(char_u *name);
static void parse_builtin_tcap(char_u *s);
static void term_color(char_u *s, int n);
static void gather_termleader(void);
static void req_codes_from_term(void);
static void req_more_codes_from_term(void);
static void got_code_from_term(char_u *code, int len);
static void check_for_codes_from_term(void);
#if defined(FEAT_GUI) \
  || (defined(FEAT_MOUSE) && (!defined(UNIX) || defined(FEAT_MOUSE_XTERM) \
  || defined(FEAT_MOUSE_GPM) || defined(FEAT_SYSMOUSE)))
static int get_bytes_from_buf(char_u *, char_u *, int);
#endif
static void del_termcode_idx(int idx);
static int term_is_builtin(char_u *name);
static int term_7to8bit(char_u *p);
static void switch_to_8bit(void);

#ifdef HAVE_TGETENT
static char_u *tgetent_error(char_u *, char_u *);

/*
 * Here is our own prototype for tgetstr(), any prototypes from the include
 * files have been disabled by the define at the start of this file.
 */
char            *tgetstr(char *, char **);

/* Change this to "if 1" to debug what happens with termresponse. */
#   define LOG_TR(msg)
/* Request Terminal Version status: */
#  define CRV_GET       1       /* send T_CRV when switched to RAW mode */
#  define CRV_SENT      2       /* did send T_CRV, waiting for answer */
#  define CRV_GOT       3       /* received T_CRV response */
static int crv_status = CRV_GET;
/* Request Cursor position report: */
#  define U7_GET        1       /* send T_U7 when switched to RAW mode */
#  define U7_SENT       2       /* did send T_U7, waiting for answer */
#  define U7_GOT        3       /* received T_U7 response */
static int u7_status = U7_GET;

/*
 * Don't declare these variables if termcap.h contains them.
 * Autoconf checks if these variables should be declared extern (not all
 * systems have them).
 * Some versions define ospeed to be speed_t, but that is incompatible with
 * BSD, where ospeed is short and speed_t is long.
 */
# ifndef HAVE_OSPEED
#  ifdef OSPEED_EXTERN
extern short ospeed;
#   else
short ospeed;
#   endif
# endif
# ifndef HAVE_UP_BC_PC
#  ifdef UP_BC_PC_EXTERN
extern char *UP, *BC, PC;
#  else
char *UP, *BC, PC;
#  endif
# endif

# define TGETSTR(s, p)  vim_tgetstr((s), (p))
# define TGETENT(b, t)  tgetent((char *)(b), (char *)(t))
static char_u *vim_tgetstr(char *s, char_u **pp);
#endif /* HAVE_TGETENT */

static int detected_8bit = FALSE;       /* detected 8-bit terminal */

static struct builtin_term builtin_termcaps[] =
{


#ifndef NO_BUILTIN_TCAPS

# if defined(AMIGA) || defined(ALL_BUILTIN_TCAPS)
  /*
   * Amiga console window, default for Amiga
   */
  {(int)KS_NAME,      "amiga"},
  {(int)KS_CE,        "\033[K"},
  {(int)KS_CD,        "\033[J"},
  {(int)KS_AL,        "\033[L"},
#  ifdef TERMINFO
  {(int)KS_CAL,       "\033[%p1%dL"},
#  else
  {(int)KS_CAL,       "\033[%dL"},
#  endif
  {(int)KS_DL,        "\033[M"},
#  ifdef TERMINFO
  {(int)KS_CDL,       "\033[%p1%dM"},
#  else
  {(int)KS_CDL,       "\033[%dM"},
#  endif
  {(int)KS_CL,        "\014"},
  {(int)KS_VI,        "\033[0 p"},
  {(int)KS_VE,        "\033[1 p"},
  {(int)KS_ME,        "\033[0m"},
  {(int)KS_MR,        "\033[7m"},
  {(int)KS_MD,        "\033[1m"},
  {(int)KS_SE,        "\033[0m"},
  {(int)KS_SO,        "\033[33m"},
  {(int)KS_US,        "\033[4m"},
  {(int)KS_UE,        "\033[0m"},
  {(int)KS_CZH,       "\033[3m"},
  {(int)KS_CZR,       "\033[0m"},
#if defined(__MORPHOS__) || defined(__AROS__)
  {(int)KS_CCO,       "8"},             /* allow 8 colors */
#  ifdef TERMINFO
  {(int)KS_CAB,       "\033[4%p1%dm"},  /* set background color */
  {(int)KS_CAF,       "\033[3%p1%dm"},  /* set foreground color */
#  else
  {(int)KS_CAB,       "\033[4%dm"},     /* set background color */
  {(int)KS_CAF,       "\033[3%dm"},     /* set foreground color */
#  endif
  {(int)KS_OP,        "\033[m"},        /* reset colors */
#endif
  {(int)KS_MS,        "y"},
  {(int)KS_UT,        "y"},             /* guessed */
  {(int)KS_LE,        "\b"},
#  ifdef TERMINFO
  {(int)KS_CM,        "\033[%i%p1%d;%p2%dH"},
#  else
  {(int)KS_CM,        "\033[%i%d;%dH"},
#  endif
#if defined(__MORPHOS__)
  {(int)KS_SR,        "\033M"},
#endif
#  ifdef TERMINFO
  {(int)KS_CRI,       "\033[%p1%dC"},
#  else
  {(int)KS_CRI,       "\033[%dC"},
#  endif
  {K_UP,              "\233A"},
  {K_DOWN,            "\233B"},
  {K_LEFT,            "\233D"},
  {K_RIGHT,           "\233C"},
  {K_S_UP,            "\233T"},
  {K_S_DOWN,          "\233S"},
  {K_S_LEFT,          "\233 A"},
  {K_S_RIGHT,         "\233 @"},
  {K_S_TAB,           "\233Z"},
  {K_F1,              "\233\060~"},  /* some compilers don't dig "\2330" */
  {K_F2,              "\233\061~"},
  {K_F3,              "\233\062~"},
  {K_F4,              "\233\063~"},
  {K_F5,              "\233\064~"},
  {K_F6,              "\233\065~"},
  {K_F7,              "\233\066~"},
  {K_F8,              "\233\067~"},
  {K_F9,              "\233\070~"},
  {K_F10,             "\233\071~"},
  {K_S_F1,            "\233\061\060~"},
  {K_S_F2,            "\233\061\061~"},
  {K_S_F3,            "\233\061\062~"},
  {K_S_F4,            "\233\061\063~"},
  {K_S_F5,            "\233\061\064~"},
  {K_S_F6,            "\233\061\065~"},
  {K_S_F7,            "\233\061\066~"},
  {K_S_F8,            "\233\061\067~"},
  {K_S_F9,            "\233\061\070~"},
  {K_S_F10,           "\233\061\071~"},
  {K_HELP,            "\233?~"},
  {K_INS,             "\233\064\060~"},         /* 101 key keyboard */
  {K_PAGEUP,          "\233\064\061~"},         /* 101 key keyboard */
  {K_PAGEDOWN,        "\233\064\062~"},         /* 101 key keyboard */
  {K_HOME,            "\233\064\064~"},         /* 101 key keyboard */
  {K_END,             "\233\064\065~"},         /* 101 key keyboard */

  {BT_EXTRA_KEYS,     ""},
  {TERMCAP2KEY('#', '2'), "\233\065\064~"},     /* shifted home key */
  {TERMCAP2KEY('#', '3'), "\233\065\060~"},     /* shifted insert key */
  {TERMCAP2KEY('*', '7'), "\233\065\065~"},     /* shifted end key */
# endif

# if defined(__BEOS__) || defined(ALL_BUILTIN_TCAPS)
  /*
   * almost standard ANSI terminal, default for bebox
   */
  {(int)KS_NAME,      "beos-ansi"},
  {(int)KS_CE,        "\033[K"},
  {(int)KS_CD,        "\033[J"},
  {(int)KS_AL,        "\033[L"},
#  ifdef TERMINFO
  {(int)KS_CAL,       "\033[%p1%dL"},
#  else
  {(int)KS_CAL,       "\033[%dL"},
#  endif
  {(int)KS_DL,        "\033[M"},
#  ifdef TERMINFO
  {(int)KS_CDL,       "\033[%p1%dM"},
#  else
  {(int)KS_CDL,       "\033[%dM"},
#  endif
#ifdef BEOS_PR_OR_BETTER
#  ifdef TERMINFO
  {(int)KS_CS,        "\033[%i%p1%d;%p2%dr"},
#  else
  {(int)KS_CS,        "\033[%i%d;%dr"},         /* scroll region */
#  endif
#endif
  {(int)KS_CL,        "\033[H\033[2J"},
#ifdef notyet
  {(int)KS_VI,        "[VI]"},   /* cursor invisible, VT320: CSI ? 25 l */
  {(int)KS_VE,        "[VE]"},   /* cursor visible, VT320: CSI ? 25 h */
#endif
  {(int)KS_ME,        "\033[m"},        /* normal mode */
  {(int)KS_MR,        "\033[7m"},       /* reverse */
  {(int)KS_MD,        "\033[1m"},       /* bold */
  {(int)KS_SO,        "\033[31m"},      /* standout mode: red */
  {(int)KS_SE,        "\033[m"},        /* standout end */
  {(int)KS_CZH,       "\033[35m"},      /* italic: purple */
  {(int)KS_CZR,       "\033[m"},        /* italic end */
  {(int)KS_US,        "\033[4m"},       /* underscore mode */
  {(int)KS_UE,        "\033[m"},        /* underscore end */
  {(int)KS_CCO,       "8"},             /* allow 8 colors */
#  ifdef TERMINFO
  {(int)KS_CAB,       "\033[4%p1%dm"},  /* set background color */
  {(int)KS_CAF,       "\033[3%p1%dm"},  /* set foreground color */
#  else
  {(int)KS_CAB,       "\033[4%dm"},     /* set background color */
  {(int)KS_CAF,       "\033[3%dm"},     /* set foreground color */
#  endif
  {(int)KS_OP,        "\033[m"},        /* reset colors */
  {(int)KS_MS,        "y"},             /* safe to move cur in reverse mode */
  {(int)KS_UT,        "y"},             /* guessed */
  {(int)KS_LE,        "\b"},
#  ifdef TERMINFO
  {(int)KS_CM,        "\033[%i%p1%d;%p2%dH"},
#  else
  {(int)KS_CM,        "\033[%i%d;%dH"},
#  endif
  {(int)KS_SR,        "\033M"},
#  ifdef TERMINFO
  {(int)KS_CRI,       "\033[%p1%dC"},
#  else
  {(int)KS_CRI,       "\033[%dC"},
#  endif
#if defined(BEOS_DR8)
  {(int)KS_DB,        ""},              /* hack! see screen.c */
#endif

  {K_UP,              "\033[A"},
  {K_DOWN,            "\033[B"},
  {K_LEFT,            "\033[D"},
  {K_RIGHT,           "\033[C"},
# endif

# if defined(UNIX) || defined(ALL_BUILTIN_TCAPS) || \
  defined(SOME_BUILTIN_TCAPS) || defined(__EMX__)
  /*
   * standard ANSI terminal, default for unix
   */
  {(int)KS_NAME,      "ansi"},
  {(int)KS_CE,        IF_EB("\033[K", ESC_STR "[K")},
  {(int)KS_AL,        IF_EB("\033[L", ESC_STR "[L")},
#  ifdef TERMINFO
  {(int)KS_CAL,       IF_EB("\033[%p1%dL", ESC_STR "[%p1%dL")},
#  else
  {(int)KS_CAL,       IF_EB("\033[%dL", ESC_STR "[%dL")},
#  endif
  {(int)KS_DL,        IF_EB("\033[M", ESC_STR "[M")},
#  ifdef TERMINFO
  {(int)KS_CDL,       IF_EB("\033[%p1%dM", ESC_STR "[%p1%dM")},
#  else
  {(int)KS_CDL,       IF_EB("\033[%dM", ESC_STR "[%dM")},
#  endif
  {(int)KS_CL,        IF_EB("\033[H\033[2J", ESC_STR "[H" ESC_STR_nc "[2J")},
  {(int)KS_ME,        IF_EB("\033[0m", ESC_STR "[0m")},
  {(int)KS_MR,        IF_EB("\033[7m", ESC_STR "[7m")},
  {(int)KS_MS,        "y"},
  {(int)KS_UT,        "y"},             /* guessed */
  {(int)KS_LE,        "\b"},
#  ifdef TERMINFO
  {(int)KS_CM,        IF_EB("\033[%i%p1%d;%p2%dH", ESC_STR "[%i%p1%d;%p2%dH")},
#  else
  {(int)KS_CM,        IF_EB("\033[%i%d;%dH", ESC_STR "[%i%d;%dH")},
#  endif
#  ifdef TERMINFO
  {(int)KS_CRI,       IF_EB("\033[%p1%dC", ESC_STR "[%p1%dC")},
#  else
  {(int)KS_CRI,       IF_EB("\033[%dC", ESC_STR "[%dC")},
#  endif
# endif

# if defined(MSDOS) || defined(ALL_BUILTIN_TCAPS) || defined(__EMX__)
  /*
   * These codes are valid when nansi.sys or equivalent has been installed.
   * Function keys on a PC are preceded with a NUL. These are converted into
   * K_NUL '\316' in mch_inchar(), because we cannot handle NULs in key codes.
   * CTRL-arrow is used instead of SHIFT-arrow.
   */
  {(int)KS_NAME,      "pcansi"},
  {(int)KS_DL,        "\033[M"},
  {(int)KS_AL,        "\033[L"},
  {(int)KS_CE,        "\033[K"},
  {(int)KS_CL,        "\033[2J"},
  {(int)KS_ME,        "\033[0m"},
  {(int)KS_MR,        "\033[5m"},       /* reverse: black on lightgrey */
  {(int)KS_MD,        "\033[1m"},       /* bold: white text */
  {(int)KS_SE,        "\033[0m"},       /* standout end */
  {(int)KS_SO,        "\033[31m"},      /* standout: white on blue */
  {(int)KS_CZH,       "\033[34;43m"},   /* italic mode: blue text on yellow */
  {(int)KS_CZR,       "\033[0m"},       /* italic mode end */
  {(int)KS_US,        "\033[36;41m"},   /* underscore mode: cyan text on red */
  {(int)KS_UE,        "\033[0m"},       /* underscore mode end */
  {(int)KS_CCO,       "8"},             /* allow 8 colors */
#  ifdef TERMINFO
  {(int)KS_CAB,       "\033[4%p1%dm"},  /* set background color */
  {(int)KS_CAF,       "\033[3%p1%dm"},  /* set foreground color */
#  else
  {(int)KS_CAB,       "\033[4%dm"},     /* set background color */
  {(int)KS_CAF,       "\033[3%dm"},     /* set foreground color */
#  endif
  {(int)KS_OP,        "\033[0m"},       /* reset colors */
  {(int)KS_MS,        "y"},
  {(int)KS_UT,        "y"},             /* guessed */
  {(int)KS_LE,        "\b"},
#  ifdef TERMINFO
  {(int)KS_CM,        "\033[%i%p1%d;%p2%dH"},
#  else
  {(int)KS_CM,        "\033[%i%d;%dH"},
#  endif
#  ifdef TERMINFO
  {(int)KS_CRI,       "\033[%p1%dC"},
#  else
  {(int)KS_CRI,       "\033[%dC"},
#  endif
  {K_UP,              "\316H"},
  {K_DOWN,            "\316P"},
  {K_LEFT,            "\316K"},
  {K_RIGHT,           "\316M"},
  {K_S_LEFT,          "\316s"},
  {K_S_RIGHT,         "\316t"},
  {K_F1,              "\316;"},
  {K_F2,              "\316<"},
  {K_F3,              "\316="},
  {K_F4,              "\316>"},
  {K_F5,              "\316?"},
  {K_F6,              "\316@"},
  {K_F7,              "\316A"},
  {K_F8,              "\316B"},
  {K_F9,              "\316C"},
  {K_F10,             "\316D"},
  {K_F11,             "\316\205"},      /* guessed */
  {K_F12,             "\316\206"},      /* guessed */
  {K_S_F1,            "\316T"},
  {K_S_F2,            "\316U"},
  {K_S_F3,            "\316V"},
  {K_S_F4,            "\316W"},
  {K_S_F5,            "\316X"},
  {K_S_F6,            "\316Y"},
  {K_S_F7,            "\316Z"},
  {K_S_F8,            "\316["},
  {K_S_F9,            "\316\\"},
  {K_S_F10,           "\316]"},
  {K_S_F11,           "\316\207"},      /* guessed */
  {K_S_F12,           "\316\210"},      /* guessed */
  {K_INS,             "\316R"},
  {K_DEL,             "\316S"},
  {K_HOME,            "\316G"},
  {K_END,             "\316O"},
  {K_PAGEDOWN,        "\316Q"},
  {K_PAGEUP,          "\316I"},
# endif


# if defined(WIN3264) || defined(ALL_BUILTIN_TCAPS) || defined(__EMX__)
  /*
   * These codes are valid for the Win32 Console .  The entries that start with
   * ESC | are translated into console calls in os_win32.c.  The function keys
   * are also translated in os_win32.c.
   */
  {(int)KS_NAME,      "win32"},
  {(int)KS_CE,        "\033|K"},        /* clear to end of line */
  {(int)KS_AL,        "\033|L"},        /* add new blank line */
#  ifdef TERMINFO
  {(int)KS_CAL,       "\033|%p1%dL"},   /* add number of new blank lines */
#  else
  {(int)KS_CAL,       "\033|%dL"},      /* add number of new blank lines */
#  endif
  {(int)KS_DL,        "\033|M"},        /* delete line */
#  ifdef TERMINFO
  {(int)KS_CDL,       "\033|%p1%dM"},   /* delete number of lines */
#  else
  {(int)KS_CDL,       "\033|%dM"},      /* delete number of lines */
#  endif
  {(int)KS_CL,        "\033|J"},        /* clear screen */
  {(int)KS_CD,        "\033|j"},        /* clear to end of display */
  {(int)KS_VI,        "\033|v"},        /* cursor invisible */
  {(int)KS_VE,        "\033|V"},        /* cursor visible */

  {(int)KS_ME,        "\033|0m"},       /* normal */
  {(int)KS_MR,        "\033|112m"},     /* reverse: black on lightgray */
  {(int)KS_MD,        "\033|15m"},      /* bold: white on black */
  {(int)KS_SO,        "\033|31m"},      /* standout: white on blue */
  {(int)KS_SE,        "\033|0m"},       /* standout end */
  {(int)KS_CZH,       "\033|225m"},     /* italic: blue text on yellow */
  {(int)KS_CZR,       "\033|0m"},       /* italic end */
  {(int)KS_US,        "\033|67m"},      /* underscore: cyan text on red */
  {(int)KS_UE,        "\033|0m"},       /* underscore end */
  {(int)KS_CCO,       "16"},            /* allow 16 colors */
#  ifdef TERMINFO
  {(int)KS_CAB,       "\033|%p1%db"},   /* set background color */
  {(int)KS_CAF,       "\033|%p1%df"},   /* set foreground color */
#  else
  {(int)KS_CAB,       "\033|%db"},      /* set background color */
  {(int)KS_CAF,       "\033|%df"},      /* set foreground color */
#  endif

  {(int)KS_MS,        "y"},             /* save to move cur in reverse mode */
  {(int)KS_UT,        "y"},
  {(int)KS_LE,        "\b"},
#  ifdef TERMINFO
  {(int)KS_CM,        "\033|%i%p1%d;%p2%dH"},  /* cursor motion */
#  else
  {(int)KS_CM,        "\033|%i%d;%dH"},  /* cursor motion */
#  endif
  {(int)KS_VB,        "\033|B"},        /* visual bell */
  {(int)KS_TI,        "\033|S"},        /* put terminal in termcap mode */
  {(int)KS_TE,        "\033|E"},        /* out of termcap mode */
#  ifdef TERMINFO
  {(int)KS_CS,        "\033|%i%p1%d;%p2%dr"},  /* scroll region */
#  else
  {(int)KS_CS,        "\033|%i%d;%dr"},  /* scroll region */
#  endif

  {K_UP,              "\316H"},
  {K_DOWN,            "\316P"},
  {K_LEFT,            "\316K"},
  {K_RIGHT,           "\316M"},
  {K_S_UP,            "\316\304"},
  {K_S_DOWN,          "\316\317"},
  {K_S_LEFT,          "\316\311"},
  {K_C_LEFT,          "\316s"},
  {K_S_RIGHT,         "\316\313"},
  {K_C_RIGHT,         "\316t"},
  {K_S_TAB,           "\316\017"},
  {K_F1,              "\316;"},
  {K_F2,              "\316<"},
  {K_F3,              "\316="},
  {K_F4,              "\316>"},
  {K_F5,              "\316?"},
  {K_F6,              "\316@"},
  {K_F7,              "\316A"},
  {K_F8,              "\316B"},
  {K_F9,              "\316C"},
  {K_F10,             "\316D"},
  {K_F11,             "\316\205"},
  {K_F12,             "\316\206"},
  {K_S_F1,            "\316T"},
  {K_S_F2,            "\316U"},
  {K_S_F3,            "\316V"},
  {K_S_F4,            "\316W"},
  {K_S_F5,            "\316X"},
  {K_S_F6,            "\316Y"},
  {K_S_F7,            "\316Z"},
  {K_S_F8,            "\316["},
  {K_S_F9,            "\316\\"},
  {K_S_F10,           "\316]"},
  {K_S_F11,           "\316\207"},
  {K_S_F12,           "\316\210"},
  {K_INS,             "\316R"},
  {K_DEL,             "\316S"},
  {K_HOME,            "\316G"},
  {K_S_HOME,          "\316\302"},
  {K_C_HOME,          "\316w"},
  {K_END,             "\316O"},
  {K_S_END,           "\316\315"},
  {K_C_END,           "\316u"},
  {K_PAGEDOWN,        "\316Q"},
  {K_PAGEUP,          "\316I"},
  {K_KPLUS,           "\316N"},
  {K_KMINUS,          "\316J"},
  {K_KMULTIPLY,       "\316\067"},
  {K_K0,              "\316\332"},
  {K_K1,              "\316\336"},
  {K_K2,              "\316\342"},
  {K_K3,              "\316\346"},
  {K_K4,              "\316\352"},
  {K_K5,              "\316\356"},
  {K_K6,              "\316\362"},
  {K_K7,              "\316\366"},
  {K_K8,              "\316\372"},
  {K_K9,              "\316\376"},
# endif

# if defined(VMS) || defined(ALL_BUILTIN_TCAPS)
  /*
   * VT320 is working as an ANSI terminal compatible DEC terminal.
   * (it covers VT1x0, VT2x0 and VT3x0 up to VT320 on VMS as well)
   * Note: K_F1...K_F5 are for internal use, should not be defined.
   * TODO:- rewrite ESC[ codes to CSI
   *      - keyboard languages (CSI ? 26 n)
   */
  {(int)KS_NAME,      "vt320"},
  {(int)KS_CE,        IF_EB("\033[K", ESC_STR "[K")},
  {(int)KS_AL,        IF_EB("\033[L", ESC_STR "[L")},
#  ifdef TERMINFO
  {(int)KS_CAL,       IF_EB("\033[%p1%dL", ESC_STR "[%p1%dL")},
#  else
  {(int)KS_CAL,       IF_EB("\033[%dL", ESC_STR "[%dL")},
#  endif
  {(int)KS_DL,        IF_EB("\033[M", ESC_STR "[M")},
#  ifdef TERMINFO
  {(int)KS_CDL,       IF_EB("\033[%p1%dM", ESC_STR "[%p1%dM")},
#  else
  {(int)KS_CDL,       IF_EB("\033[%dM", ESC_STR "[%dM")},
#  endif
  {(int)KS_CL,        IF_EB("\033[H\033[2J", ESC_STR "[H" ESC_STR_nc "[2J")},
  {(int)KS_CD,        IF_EB("\033[J", ESC_STR "[J")},
  {(int)KS_CCO,       "8"},                     /* allow 8 colors */
  {(int)KS_ME,        IF_EB("\033[0m", ESC_STR "[0m")},
  {(int)KS_MR,        IF_EB("\033[7m", ESC_STR "[7m")},
  {(int)KS_MD,        IF_EB("\033[1m", ESC_STR "[1m")},    /* bold mode */
  {(int)KS_SE,        IF_EB("\033[22m", ESC_STR "[22m")},  /* normal mode */
  {(int)KS_UE,        IF_EB("\033[24m", ESC_STR "[24m")},  /* exit underscore mode */
  {(int)KS_US,        IF_EB("\033[4m", ESC_STR "[4m")},    /* underscore mode */
  {(int)KS_CZH,       IF_EB("\033[34;43m", ESC_STR "[34;43m")},    /* italic mode: blue text on yellow */
  {(int)KS_CZR,       IF_EB("\033[0m", ESC_STR "[0m")},             /* italic mode end */
  {(int)KS_CAB,       IF_EB("\033[4%dm", ESC_STR "[4%dm")},         /* set background color (ANSI) */
  {(int)KS_CAF,       IF_EB("\033[3%dm", ESC_STR "[3%dm")},         /* set foreground color (ANSI) */
  {(int)KS_CSB,       IF_EB("\033[102;%dm", ESC_STR "[102;%dm")},       /* set screen background color */
  {(int)KS_CSF,       IF_EB("\033[101;%dm", ESC_STR "[101;%dm")},       /* set screen foreground color */
  {(int)KS_MS,        "y"},
  {(int)KS_UT,        "y"},
  {(int)KS_LE,        "\b"},
#  ifdef TERMINFO
  {(int)KS_CM,        IF_EB("\033[%i%p1%d;%p2%dH",
       ESC_STR "[%i%p1%d;%p2%dH")},
#  else
  {(int)KS_CM,        IF_EB("\033[%i%d;%dH", ESC_STR "[%i%d;%dH")},
#  endif
#  ifdef TERMINFO
  {(int)KS_CRI,       IF_EB("\033[%p1%dC", ESC_STR "[%p1%dC")},
#  else
  {(int)KS_CRI,       IF_EB("\033[%dC", ESC_STR "[%dC")},
#  endif
  {K_UP,              IF_EB("\033[A", ESC_STR "[A")},
  {K_DOWN,            IF_EB("\033[B", ESC_STR "[B")},
  {K_RIGHT,           IF_EB("\033[C", ESC_STR "[C")},
  {K_LEFT,            IF_EB("\033[D", ESC_STR "[D")},
  {K_F1,              IF_EB("\033[11~", ESC_STR "[11~")},
  {K_F2,              IF_EB("\033[12~", ESC_STR "[12~")},
  {K_F3,              IF_EB("\033[13~", ESC_STR "[13~")},
  {K_F4,              IF_EB("\033[14~", ESC_STR "[14~")},
  {K_F5,              IF_EB("\033[15~", ESC_STR "[15~")},
  {K_F6,              IF_EB("\033[17~", ESC_STR "[17~")},
  {K_F7,              IF_EB("\033[18~", ESC_STR "[18~")},
  {K_F8,              IF_EB("\033[19~", ESC_STR "[19~")},
  {K_F9,              IF_EB("\033[20~", ESC_STR "[20~")},
  {K_F10,             IF_EB("\033[21~", ESC_STR "[21~")},
  {K_F11,             IF_EB("\033[23~", ESC_STR "[23~")},
  {K_F12,             IF_EB("\033[24~", ESC_STR "[24~")},
  {K_F13,             IF_EB("\033[25~", ESC_STR "[25~")},
  {K_F14,             IF_EB("\033[26~", ESC_STR "[26~")},
  {K_F15,             IF_EB("\033[28~", ESC_STR "[28~")},       /* Help */
  {K_F16,             IF_EB("\033[29~", ESC_STR "[29~")},       /* Select */
  {K_F17,             IF_EB("\033[31~", ESC_STR "[31~")},
  {K_F18,             IF_EB("\033[32~", ESC_STR "[32~")},
  {K_F19,             IF_EB("\033[33~", ESC_STR "[33~")},
  {K_F20,             IF_EB("\033[34~", ESC_STR "[34~")},
  {K_INS,             IF_EB("\033[2~", ESC_STR "[2~")},
  {K_DEL,             IF_EB("\033[3~", ESC_STR "[3~")},
  {K_HOME,            IF_EB("\033[1~", ESC_STR "[1~")},
  {K_END,             IF_EB("\033[4~", ESC_STR "[4~")},
  {K_PAGEUP,          IF_EB("\033[5~", ESC_STR "[5~")},
  {K_PAGEDOWN,        IF_EB("\033[6~", ESC_STR "[6~")},
  {K_KPLUS,           IF_EB("\033Ok", ESC_STR "Ok")},   /* keypad plus */
  {K_KMINUS,          IF_EB("\033Om", ESC_STR "Om")},   /* keypad minus */
  {K_KDIVIDE,         IF_EB("\033Oo", ESC_STR "Oo")},   /* keypad / */
  {K_KMULTIPLY,       IF_EB("\033Oj", ESC_STR "Oj")},   /* keypad * */
  {K_KENTER,          IF_EB("\033OM", ESC_STR "OM")},   /* keypad Enter */
  {K_BS,              "\x7f"},          /* for some reason 0177 doesn't work */
# endif

# if defined(ALL_BUILTIN_TCAPS) || defined(__MINT__)
  /*
   * Ordinary vt52
   */
  {(int)KS_NAME,      "vt52"},
  {(int)KS_CE,        IF_EB("\033K", ESC_STR "K")},
  {(int)KS_CD,        IF_EB("\033J", ESC_STR "J")},
  {(int)KS_CM,        IF_EB("\033Y%+ %+ ", ESC_STR "Y%+ %+ ")},
  {(int)KS_LE,        "\b"},
  {(int)KS_AL,        IF_EB("\033T", ESC_STR "T")},
  {(int)KS_DL,        IF_EB("\033U", ESC_STR "U")},
  {(int)KS_CL,        IF_EB("\033H\033J", ESC_STR "H" ESC_STR_nc "J")},
  {(int)KS_ME,        IF_EB("\033SO", ESC_STR "SO")},
  {(int)KS_MR,        IF_EB("\033S2", ESC_STR "S2")},
  {(int)KS_MS,        "y"},
# endif

# if defined(UNIX) || defined(ALL_BUILTIN_TCAPS) || \
  defined(SOME_BUILTIN_TCAPS) || defined(__EMX__)
  {(int)KS_NAME,      "xterm"},
  {(int)KS_CE,        IF_EB("\033[K", ESC_STR "[K")},
  {(int)KS_AL,        IF_EB("\033[L", ESC_STR "[L")},
#  ifdef TERMINFO
  {(int)KS_CAL,       IF_EB("\033[%p1%dL", ESC_STR "[%p1%dL")},
#  else
  {(int)KS_CAL,       IF_EB("\033[%dL", ESC_STR "[%dL")},
#  endif
  {(int)KS_DL,        IF_EB("\033[M", ESC_STR "[M")},
#  ifdef TERMINFO
  {(int)KS_CDL,       IF_EB("\033[%p1%dM", ESC_STR "[%p1%dM")},
#  else
  {(int)KS_CDL,       IF_EB("\033[%dM", ESC_STR "[%dM")},
#  endif
#  ifdef TERMINFO
  {(int)KS_CS,        IF_EB("\033[%i%p1%d;%p2%dr",
       ESC_STR "[%i%p1%d;%p2%dr")},
#  else
  {(int)KS_CS,        IF_EB("\033[%i%d;%dr", ESC_STR "[%i%d;%dr")},
#  endif
  {(int)KS_CL,        IF_EB("\033[H\033[2J", ESC_STR "[H" ESC_STR_nc "[2J")},
  {(int)KS_CD,        IF_EB("\033[J", ESC_STR "[J")},
  {(int)KS_ME,        IF_EB("\033[m", ESC_STR "[m")},
  {(int)KS_MR,        IF_EB("\033[7m", ESC_STR "[7m")},
  {(int)KS_MD,        IF_EB("\033[1m", ESC_STR "[1m")},
  {(int)KS_UE,        IF_EB("\033[m", ESC_STR "[m")},
  {(int)KS_US,        IF_EB("\033[4m", ESC_STR "[4m")},
  {(int)KS_MS,        "y"},
  {(int)KS_UT,        "y"},
  {(int)KS_LE,        "\b"},
#  ifdef TERMINFO
  {(int)KS_CM,        IF_EB("\033[%i%p1%d;%p2%dH",
       ESC_STR "[%i%p1%d;%p2%dH")},
#  else
  {(int)KS_CM,        IF_EB("\033[%i%d;%dH", ESC_STR "[%i%d;%dH")},
#  endif
  {(int)KS_SR,        IF_EB("\033M", ESC_STR "M")},
#  ifdef TERMINFO
  {(int)KS_CRI,       IF_EB("\033[%p1%dC", ESC_STR "[%p1%dC")},
#  else
  {(int)KS_CRI,       IF_EB("\033[%dC", ESC_STR "[%dC")},
#  endif
  {(int)KS_KS,        IF_EB("\033[?1h\033=", ESC_STR "[?1h" ESC_STR_nc "=")},
  {(int)KS_KE,        IF_EB("\033[?1l\033>", ESC_STR "[?1l" ESC_STR_nc ">")},
#  ifdef FEAT_XTERM_SAVE
  {(int)KS_TI,        IF_EB("\0337\033[?47h", ESC_STR "7" ESC_STR_nc "[?47h")},
  {(int)KS_TE,        IF_EB("\033[2J\033[?47l\0338",
       ESC_STR "[2J" ESC_STR_nc "[?47l" ESC_STR_nc "8")},
#  endif
  {(int)KS_CIS,       IF_EB("\033]1;", ESC_STR "]1;")},
  {(int)KS_CIE,       "\007"},
  {(int)KS_TS,        IF_EB("\033]2;", ESC_STR "]2;")},
  {(int)KS_FS,        "\007"},
#  ifdef TERMINFO
  {(int)KS_CWS,       IF_EB("\033[8;%p1%d;%p2%dt",
       ESC_STR "[8;%p1%d;%p2%dt")},
  {(int)KS_CWP,       IF_EB("\033[3;%p1%d;%p2%dt",
       ESC_STR "[3;%p1%d;%p2%dt")},
#  else
  {(int)KS_CWS,       IF_EB("\033[8;%d;%dt", ESC_STR "[8;%d;%dt")},
  {(int)KS_CWP,       IF_EB("\033[3;%d;%dt", ESC_STR "[3;%d;%dt")},
#  endif
  {(int)KS_CRV,       IF_EB("\033[>c", ESC_STR "[>c")},
  {(int)KS_U7,        IF_EB("\033[6n", ESC_STR "[6n")},

  {K_UP,              IF_EB("\033O*A", ESC_STR "O*A")},
  {K_DOWN,            IF_EB("\033O*B", ESC_STR "O*B")},
  {K_RIGHT,           IF_EB("\033O*C", ESC_STR "O*C")},
  {K_LEFT,            IF_EB("\033O*D", ESC_STR "O*D")},
  /* An extra set of cursor keys for vt100 mode */
  {K_XUP,             IF_EB("\033[1;*A", ESC_STR "[1;*A")},
  {K_XDOWN,           IF_EB("\033[1;*B", ESC_STR "[1;*B")},
  {K_XRIGHT,          IF_EB("\033[1;*C", ESC_STR "[1;*C")},
  {K_XLEFT,           IF_EB("\033[1;*D", ESC_STR "[1;*D")},
  /* An extra set of function keys for vt100 mode */
  {K_XF1,             IF_EB("\033O*P", ESC_STR "O*P")},
  {K_XF2,             IF_EB("\033O*Q", ESC_STR "O*Q")},
  {K_XF3,             IF_EB("\033O*R", ESC_STR "O*R")},
  {K_XF4,             IF_EB("\033O*S", ESC_STR "O*S")},
  {K_F1,              IF_EB("\033[11;*~", ESC_STR "[11;*~")},
  {K_F2,              IF_EB("\033[12;*~", ESC_STR "[12;*~")},
  {K_F3,              IF_EB("\033[13;*~", ESC_STR "[13;*~")},
  {K_F4,              IF_EB("\033[14;*~", ESC_STR "[14;*~")},
  {K_F5,              IF_EB("\033[15;*~", ESC_STR "[15;*~")},
  {K_F6,              IF_EB("\033[17;*~", ESC_STR "[17;*~")},
  {K_F7,              IF_EB("\033[18;*~", ESC_STR "[18;*~")},
  {K_F8,              IF_EB("\033[19;*~", ESC_STR "[19;*~")},
  {K_F9,              IF_EB("\033[20;*~", ESC_STR "[20;*~")},
  {K_F10,             IF_EB("\033[21;*~", ESC_STR "[21;*~")},
  {K_F11,             IF_EB("\033[23;*~", ESC_STR "[23;*~")},
  {K_F12,             IF_EB("\033[24;*~", ESC_STR "[24;*~")},
  {K_S_TAB,           IF_EB("\033[Z", ESC_STR "[Z")},
  {K_HELP,            IF_EB("\033[28;*~", ESC_STR "[28;*~")},
  {K_UNDO,            IF_EB("\033[26;*~", ESC_STR "[26;*~")},
  {K_INS,             IF_EB("\033[2;*~", ESC_STR "[2;*~")},
  {K_HOME,            IF_EB("\033[1;*H", ESC_STR "[1;*H")},
  /* {K_S_HOME,		IF_EB("\033O2H", ESC_STR "O2H")}, */
  /* {K_C_HOME,		IF_EB("\033O5H", ESC_STR "O5H")}, */
  {K_KHOME,           IF_EB("\033[1;*~", ESC_STR "[1;*~")},
  {K_XHOME,           IF_EB("\033O*H", ESC_STR "O*H")},         /* other Home */
  {K_ZHOME,           IF_EB("\033[7;*~", ESC_STR "[7;*~")},     /* other Home */
  {K_END,             IF_EB("\033[1;*F", ESC_STR "[1;*F")},
  /* {K_S_END,		IF_EB("\033O2F", ESC_STR "O2F")}, */
  /* {K_C_END,		IF_EB("\033O5F", ESC_STR "O5F")}, */
  {K_KEND,            IF_EB("\033[4;*~", ESC_STR "[4;*~")},
  {K_XEND,            IF_EB("\033O*F", ESC_STR "O*F")},         /* other End */
  {K_ZEND,            IF_EB("\033[8;*~", ESC_STR "[8;*~")},
  {K_PAGEUP,          IF_EB("\033[5;*~", ESC_STR "[5;*~")},
  {K_PAGEDOWN,        IF_EB("\033[6;*~", ESC_STR "[6;*~")},
  {K_KPLUS,           IF_EB("\033O*k", ESC_STR "O*k")},         /* keypad plus */
  {K_KMINUS,          IF_EB("\033O*m", ESC_STR "O*m")},         /* keypad minus */
  {K_KDIVIDE,         IF_EB("\033O*o", ESC_STR "O*o")},         /* keypad / */
  {K_KMULTIPLY,       IF_EB("\033O*j", ESC_STR "O*j")},         /* keypad * */
  {K_KENTER,          IF_EB("\033O*M", ESC_STR "O*M")},         /* keypad Enter */
  {K_KPOINT,          IF_EB("\033O*n", ESC_STR "O*n")},         /* keypad . */
  {K_KDEL,            IF_EB("\033[3;*~", ESC_STR "[3;*~")},     /* keypad Del */

  {BT_EXTRA_KEYS,   ""},
  {TERMCAP2KEY('k', '0'), IF_EB("\033[10;*~", ESC_STR "[10;*~")},   /* F0 */
  {TERMCAP2KEY('F', '3'), IF_EB("\033[25;*~", ESC_STR "[25;*~")},   /* F13 */
  /* F14 and F15 are missing, because they send the same codes as the undo
   * and help key, although they don't work on all keyboards. */
  {TERMCAP2KEY('F', '6'), IF_EB("\033[29;*~", ESC_STR "[29;*~")},   /* F16 */
  {TERMCAP2KEY('F', '7'), IF_EB("\033[31;*~", ESC_STR "[31;*~")},   /* F17 */
  {TERMCAP2KEY('F', '8'), IF_EB("\033[32;*~", ESC_STR "[32;*~")},   /* F18 */
  {TERMCAP2KEY('F', '9'), IF_EB("\033[33;*~", ESC_STR "[33;*~")},   /* F19 */
  {TERMCAP2KEY('F', 'A'), IF_EB("\033[34;*~", ESC_STR "[34;*~")},   /* F20 */

  {TERMCAP2KEY('F', 'B'), IF_EB("\033[42;*~", ESC_STR "[42;*~")},   /* F21 */
  {TERMCAP2KEY('F', 'C'), IF_EB("\033[43;*~", ESC_STR "[43;*~")},   /* F22 */
  {TERMCAP2KEY('F', 'D'), IF_EB("\033[44;*~", ESC_STR "[44;*~")},   /* F23 */
  {TERMCAP2KEY('F', 'E'), IF_EB("\033[45;*~", ESC_STR "[45;*~")},   /* F24 */
  {TERMCAP2KEY('F', 'F'), IF_EB("\033[46;*~", ESC_STR "[46;*~")},   /* F25 */
  {TERMCAP2KEY('F', 'G'), IF_EB("\033[47;*~", ESC_STR "[47;*~")},   /* F26 */
  {TERMCAP2KEY('F', 'H'), IF_EB("\033[48;*~", ESC_STR "[48;*~")},   /* F27 */
  {TERMCAP2KEY('F', 'I'), IF_EB("\033[49;*~", ESC_STR "[49;*~")},   /* F28 */
  {TERMCAP2KEY('F', 'J'), IF_EB("\033[50;*~", ESC_STR "[50;*~")},   /* F29 */
  {TERMCAP2KEY('F', 'K'), IF_EB("\033[51;*~", ESC_STR "[51;*~")},   /* F30 */

  {TERMCAP2KEY('F', 'L'), IF_EB("\033[52;*~", ESC_STR "[52;*~")},   /* F31 */
  {TERMCAP2KEY('F', 'M'), IF_EB("\033[53;*~", ESC_STR "[53;*~")},   /* F32 */
  {TERMCAP2KEY('F', 'N'), IF_EB("\033[54;*~", ESC_STR "[54;*~")},   /* F33 */
  {TERMCAP2KEY('F', 'O'), IF_EB("\033[55;*~", ESC_STR "[55;*~")},   /* F34 */
  {TERMCAP2KEY('F', 'P'), IF_EB("\033[56;*~", ESC_STR "[56;*~")},   /* F35 */
  {TERMCAP2KEY('F', 'Q'), IF_EB("\033[57;*~", ESC_STR "[57;*~")},   /* F36 */
  {TERMCAP2KEY('F', 'R'), IF_EB("\033[58;*~", ESC_STR "[58;*~")},   /* F37 */
# endif

# if defined(UNIX) || defined(ALL_BUILTIN_TCAPS)
  /*
   * iris-ansi for Silicon Graphics machines.
   */
  {(int)KS_NAME,      "iris-ansi"},
  {(int)KS_CE,        "\033[K"},
  {(int)KS_CD,        "\033[J"},
  {(int)KS_AL,        "\033[L"},
#  ifdef TERMINFO
  {(int)KS_CAL,       "\033[%p1%dL"},
#  else
  {(int)KS_CAL,       "\033[%dL"},
#  endif
  {(int)KS_DL,        "\033[M"},
#  ifdef TERMINFO
  {(int)KS_CDL,       "\033[%p1%dM"},
#  else
  {(int)KS_CDL,       "\033[%dM"},
#  endif
  {(int)KS_CL,        "\033[H\033[2J"},
  {(int)KS_VE,        "\033[9/y\033[12/y"},     /* These aren't documented */
  {(int)KS_VS,        "\033[10/y\033[=1h\033[=2l"},   /* These aren't documented */
  {(int)KS_TI,        "\033[=6h"},
  {(int)KS_TE,        "\033[=6l"},
  {(int)KS_SE,        "\033[21;27m"},
  {(int)KS_SO,        "\033[1;7m"},
  {(int)KS_ME,        "\033[m"},
  {(int)KS_MR,        "\033[7m"},
  {(int)KS_MD,        "\033[1m"},
  {(int)KS_CCO,       "8"},                     /* allow 8 colors */
  {(int)KS_CZH,       "\033[3m"},               /* italic mode on */
  {(int)KS_CZR,       "\033[23m"},              /* italic mode off */
  {(int)KS_US,        "\033[4m"},               /* underline on */
  {(int)KS_UE,        "\033[24m"},              /* underline off */
#  ifdef TERMINFO
  {(int)KS_CAB,       "\033[4%p1%dm"},      /* set background color (ANSI) */
  {(int)KS_CAF,       "\033[3%p1%dm"},      /* set foreground color (ANSI) */
  {(int)KS_CSB,       "\033[102;%p1%dm"},   /* set screen background color */
  {(int)KS_CSF,       "\033[101;%p1%dm"},   /* set screen foreground color */
#  else
  {(int)KS_CAB,       "\033[4%dm"},         /* set background color (ANSI) */
  {(int)KS_CAF,       "\033[3%dm"},         /* set foreground color (ANSI) */
  {(int)KS_CSB,       "\033[102;%dm"},      /* set screen background color */
  {(int)KS_CSF,       "\033[101;%dm"},      /* set screen foreground color */
#  endif
  {(int)KS_MS,        "y"},             /* guessed */
  {(int)KS_UT,        "y"},             /* guessed */
  {(int)KS_LE,        "\b"},
#  ifdef TERMINFO
  {(int)KS_CM,        "\033[%i%p1%d;%p2%dH"},
#  else
  {(int)KS_CM,        "\033[%i%d;%dH"},
#  endif
  {(int)KS_SR,        "\033M"},
#  ifdef TERMINFO
  {(int)KS_CRI,       "\033[%p1%dC"},
#  else
  {(int)KS_CRI,       "\033[%dC"},
#  endif
  {(int)KS_CIS,       "\033P3.y"},
  {(int)KS_CIE,       "\234"},      /* ST "String Terminator" */
  {(int)KS_TS,        "\033P1.y"},
  {(int)KS_FS,        "\234"},      /* ST "String Terminator" */
#  ifdef TERMINFO
  {(int)KS_CWS,       "\033[203;%p1%d;%p2%d/y"},
  {(int)KS_CWP,       "\033[205;%p1%d;%p2%d/y"},
#  else
  {(int)KS_CWS,       "\033[203;%d;%d/y"},
  {(int)KS_CWP,       "\033[205;%d;%d/y"},
#  endif
  {K_UP,              "\033[A"},
  {K_DOWN,            "\033[B"},
  {K_LEFT,            "\033[D"},
  {K_RIGHT,           "\033[C"},
  {K_S_UP,            "\033[161q"},
  {K_S_DOWN,          "\033[164q"},
  {K_S_LEFT,          "\033[158q"},
  {K_S_RIGHT,         "\033[167q"},
  {K_F1,              "\033[001q"},
  {K_F2,              "\033[002q"},
  {K_F3,              "\033[003q"},
  {K_F4,              "\033[004q"},
  {K_F5,              "\033[005q"},
  {K_F6,              "\033[006q"},
  {K_F7,              "\033[007q"},
  {K_F8,              "\033[008q"},
  {K_F9,              "\033[009q"},
  {K_F10,             "\033[010q"},
  {K_F11,             "\033[011q"},
  {K_F12,             "\033[012q"},
  {K_S_F1,            "\033[013q"},
  {K_S_F2,            "\033[014q"},
  {K_S_F3,            "\033[015q"},
  {K_S_F4,            "\033[016q"},
  {K_S_F5,            "\033[017q"},
  {K_S_F6,            "\033[018q"},
  {K_S_F7,            "\033[019q"},
  {K_S_F8,            "\033[020q"},
  {K_S_F9,            "\033[021q"},
  {K_S_F10,           "\033[022q"},
  {K_S_F11,           "\033[023q"},
  {K_S_F12,           "\033[024q"},
  {K_INS,             "\033[139q"},
  {K_HOME,            "\033[H"},
  {K_END,             "\033[146q"},
  {K_PAGEUP,          "\033[150q"},
  {K_PAGEDOWN,        "\033[154q"},
# endif

# if defined(DEBUG) || defined(ALL_BUILTIN_TCAPS)
  /*
   * for debugging
   */
  {(int)KS_NAME,      "debug"},
  {(int)KS_CE,        "[CE]"},
  {(int)KS_CD,        "[CD]"},
  {(int)KS_AL,        "[AL]"},
#  ifdef TERMINFO
  {(int)KS_CAL,       "[CAL%p1%d]"},
#  else
  {(int)KS_CAL,       "[CAL%d]"},
#  endif
  {(int)KS_DL,        "[DL]"},
#  ifdef TERMINFO
  {(int)KS_CDL,       "[CDL%p1%d]"},
#  else
  {(int)KS_CDL,       "[CDL%d]"},
#  endif
#  ifdef TERMINFO
  {(int)KS_CS,        "[%p1%dCS%p2%d]"},
#  else
  {(int)KS_CS,        "[%dCS%d]"},
#  endif
#   ifdef TERMINFO
  {(int)KS_CSV,       "[%p1%dCSV%p2%d]"},
#   else
  {(int)KS_CSV,       "[%dCSV%d]"},
#   endif
#  ifdef TERMINFO
  {(int)KS_CAB,       "[CAB%p1%d]"},
  {(int)KS_CAF,       "[CAF%p1%d]"},
  {(int)KS_CSB,       "[CSB%p1%d]"},
  {(int)KS_CSF,       "[CSF%p1%d]"},
#  else
  {(int)KS_CAB,       "[CAB%d]"},
  {(int)KS_CAF,       "[CAF%d]"},
  {(int)KS_CSB,       "[CSB%d]"},
  {(int)KS_CSF,       "[CSF%d]"},
#  endif
  {(int)KS_OP,        "[OP]"},
  {(int)KS_LE,        "[LE]"},
  {(int)KS_CL,        "[CL]"},
  {(int)KS_VI,        "[VI]"},
  {(int)KS_VE,        "[VE]"},
  {(int)KS_VS,        "[VS]"},
  {(int)KS_ME,        "[ME]"},
  {(int)KS_MR,        "[MR]"},
  {(int)KS_MB,        "[MB]"},
  {(int)KS_MD,        "[MD]"},
  {(int)KS_SE,        "[SE]"},
  {(int)KS_SO,        "[SO]"},
  {(int)KS_UE,        "[UE]"},
  {(int)KS_US,        "[US]"},
  {(int)KS_UCE,       "[UCE]"},
  {(int)KS_UCS,       "[UCS]"},
  {(int)KS_MS,        "[MS]"},
  {(int)KS_UT,        "[UT]"},
#  ifdef TERMINFO
  {(int)KS_CM,        "[%p1%dCM%p2%d]"},
#  else
  {(int)KS_CM,        "[%dCM%d]"},
#  endif
  {(int)KS_SR,        "[SR]"},
#  ifdef TERMINFO
  {(int)KS_CRI,       "[CRI%p1%d]"},
#  else
  {(int)KS_CRI,       "[CRI%d]"},
#  endif
  {(int)KS_VB,        "[VB]"},
  {(int)KS_KS,        "[KS]"},
  {(int)KS_KE,        "[KE]"},
  {(int)KS_TI,        "[TI]"},
  {(int)KS_TE,        "[TE]"},
  {(int)KS_CIS,       "[CIS]"},
  {(int)KS_CIE,       "[CIE]"},
  {(int)KS_TS,        "[TS]"},
  {(int)KS_FS,        "[FS]"},
#  ifdef TERMINFO
  {(int)KS_CWS,       "[%p1%dCWS%p2%d]"},
  {(int)KS_CWP,       "[%p1%dCWP%p2%d]"},
#  else
  {(int)KS_CWS,       "[%dCWS%d]"},
  {(int)KS_CWP,       "[%dCWP%d]"},
#  endif
  {(int)KS_CRV,       "[CRV]"},
  {(int)KS_U7,        "[U7]"},
  {K_UP,              "[KU]"},
  {K_DOWN,            "[KD]"},
  {K_LEFT,            "[KL]"},
  {K_RIGHT,           "[KR]"},
  {K_XUP,             "[xKU]"},
  {K_XDOWN,           "[xKD]"},
  {K_XLEFT,           "[xKL]"},
  {K_XRIGHT,          "[xKR]"},
  {K_S_UP,            "[S-KU]"},
  {K_S_DOWN,          "[S-KD]"},
  {K_S_LEFT,          "[S-KL]"},
  {K_C_LEFT,          "[C-KL]"},
  {K_S_RIGHT,         "[S-KR]"},
  {K_C_RIGHT,         "[C-KR]"},
  {K_F1,              "[F1]"},
  {K_XF1,             "[xF1]"},
  {K_F2,              "[F2]"},
  {K_XF2,             "[xF2]"},
  {K_F3,              "[F3]"},
  {K_XF3,             "[xF3]"},
  {K_F4,              "[F4]"},
  {K_XF4,             "[xF4]"},
  {K_F5,              "[F5]"},
  {K_F6,              "[F6]"},
  {K_F7,              "[F7]"},
  {K_F8,              "[F8]"},
  {K_F9,              "[F9]"},
  {K_F10,             "[F10]"},
  {K_F11,             "[F11]"},
  {K_F12,             "[F12]"},
  {K_S_F1,            "[S-F1]"},
  {K_S_XF1,           "[S-xF1]"},
  {K_S_F2,            "[S-F2]"},
  {K_S_XF2,           "[S-xF2]"},
  {K_S_F3,            "[S-F3]"},
  {K_S_XF3,           "[S-xF3]"},
  {K_S_F4,            "[S-F4]"},
  {K_S_XF4,           "[S-xF4]"},
  {K_S_F5,            "[S-F5]"},
  {K_S_F6,            "[S-F6]"},
  {K_S_F7,            "[S-F7]"},
  {K_S_F8,            "[S-F8]"},
  {K_S_F9,            "[S-F9]"},
  {K_S_F10,           "[S-F10]"},
  {K_S_F11,           "[S-F11]"},
  {K_S_F12,           "[S-F12]"},
  {K_HELP,            "[HELP]"},
  {K_UNDO,            "[UNDO]"},
  {K_BS,              "[BS]"},
  {K_INS,             "[INS]"},
  {K_KINS,            "[KINS]"},
  {K_DEL,             "[DEL]"},
  {K_KDEL,            "[KDEL]"},
  {K_HOME,            "[HOME]"},
  {K_S_HOME,          "[C-HOME]"},
  {K_C_HOME,          "[C-HOME]"},
  {K_KHOME,           "[KHOME]"},
  {K_XHOME,           "[XHOME]"},
  {K_ZHOME,           "[ZHOME]"},
  {K_END,             "[END]"},
  {K_S_END,           "[C-END]"},
  {K_C_END,           "[C-END]"},
  {K_KEND,            "[KEND]"},
  {K_XEND,            "[XEND]"},
  {K_ZEND,            "[ZEND]"},
  {K_PAGEUP,          "[PAGEUP]"},
  {K_PAGEDOWN,        "[PAGEDOWN]"},
  {K_KPAGEUP,         "[KPAGEUP]"},
  {K_KPAGEDOWN,       "[KPAGEDOWN]"},
  {K_MOUSE,           "[MOUSE]"},
  {K_KPLUS,           "[KPLUS]"},
  {K_KMINUS,          "[KMINUS]"},
  {K_KDIVIDE,         "[KDIVIDE]"},
  {K_KMULTIPLY,       "[KMULTIPLY]"},
  {K_KENTER,          "[KENTER]"},
  {K_KPOINT,          "[KPOINT]"},
  {K_K0,              "[K0]"},
  {K_K1,              "[K1]"},
  {K_K2,              "[K2]"},
  {K_K3,              "[K3]"},
  {K_K4,              "[K4]"},
  {K_K5,              "[K5]"},
  {K_K6,              "[K6]"},
  {K_K7,              "[K7]"},
  {K_K8,              "[K8]"},
  {K_K9,              "[K9]"},
# endif

#endif /* NO_BUILTIN_TCAPS */

  /*
   * The most minimal terminal: only clear screen and cursor positioning
   * Always included.
   */
  {(int)KS_NAME,      "dumb"},
  {(int)KS_CL,        "\014"},
#ifdef TERMINFO
  {(int)KS_CM,        IF_EB("\033[%i%p1%d;%p2%dH",
       ESC_STR "[%i%p1%d;%p2%dH")},
#else
  {(int)KS_CM,        IF_EB("\033[%i%d;%dH", ESC_STR "[%i%d;%dH")},
#endif

  /*
   * end marker
   */
  {(int)KS_NAME,      NULL}

};      /* end of builtin_termcaps */

/*
 * DEFAULT_TERM is used, when no terminal is specified with -T option or $TERM.
 */



#if defined(UNIX) && !defined(__MINT__)
# define DEFAULT_TERM   (char_u *)"ansi"
#endif





#ifndef DEFAULT_TERM
# define DEFAULT_TERM   (char_u *)"dumb"
#endif

/*
 * Term_strings contains currently used terminal output strings.
 * It is initialized with the default values by parse_builtin_tcap().
 * The values can be changed by setting the option with the same name.
 */
char_u *(term_strings[(int)KS_LAST + 1]);

static int need_gather = FALSE;             /* need to fill termleader[] */
static char_u termleader[256 + 1];          /* for check_termcode() */
static int check_for_codes = FALSE;         /* check for key code response */

static struct builtin_term *find_builtin_term(char_u *term)
{
  struct builtin_term *p;

  p = builtin_termcaps;
  while (p->bt_string != NULL) {
    if (p->bt_entry == (int)KS_NAME) {
#ifdef UNIX
      if (STRCMP(p->bt_string, "iris-ansi") == 0 && vim_is_iris(term))
        return p;
      else if (STRCMP(p->bt_string, "xterm") == 0 && vim_is_xterm(term))
        return p;
      else
#endif
      if (STRCMP(term, p->bt_string) == 0)
        return p;
    }
    ++p;
  }
  return p;
}

/*
 * Parsing of the builtin termcap entries.
 * Caller should check if 'name' is a valid builtin term.
 * The terminal's name is not set, as this is already done in termcapinit().
 */
static void parse_builtin_tcap(char_u *term)
{
  struct builtin_term     *p;
  char_u name[2];
  int term_8bit;

  p = find_builtin_term(term);
  term_8bit = term_is_8bit(term);

  /* Do not parse if builtin term not found */
  if (p->bt_string == NULL)
    return;

  for (++p; p->bt_entry != (int)KS_NAME && p->bt_entry != BT_EXTRA_KEYS; ++p) {
    if ((int)p->bt_entry >= 0) {        /* KS_xx entry */
      /* Only set the value if it wasn't set yet. */
      if (term_strings[p->bt_entry] == NULL
          || term_strings[p->bt_entry] == empty_option) {
        /* 8bit terminal: use CSI instead of <Esc>[ */
        if (term_8bit && term_7to8bit((char_u *)p->bt_string) != 0) {
          char_u  *s, *t;

          s = vim_strsave((char_u *)p->bt_string);
          if (s != NULL) {
            for (t = s; *t; ++t)
              if (term_7to8bit(t)) {
                *t = term_7to8bit(t);
                STRCPY(t + 1, t + 2);
              }
            term_strings[p->bt_entry] = s;
            set_term_option_alloced(&term_strings[p->bt_entry]);
          }
        } else
          term_strings[p->bt_entry] = (char_u *)p->bt_string;
      }
    } else   {
      name[0] = KEY2TERMCAP0((int)p->bt_entry);
      name[1] = KEY2TERMCAP1((int)p->bt_entry);
      if (find_termcode(name) == NULL)
        add_termcode(name, (char_u *)p->bt_string, term_8bit);
    }
  }
}
static void set_color_count(int nr);

/*
 * Set number of colors.
 * Store it as a number in t_colors.
 * Store it as a string in T_CCO (using nr_colors[]).
 */
static void set_color_count(int nr)
{
  char_u nr_colors[20];                 /* string for number of colors */

  t_colors = nr;
  if (t_colors > 1)
    sprintf((char *)nr_colors, "%d", t_colors);
  else
    *nr_colors = NUL;
  set_string_option_direct((char_u *)"t_Co", -1, nr_colors, OPT_FREE, 0);
}

#ifdef HAVE_TGETENT
static char *(key_names[]) =
{
  /* Do this one first, it may cause a screen redraw. */
  "Co",
  "ku", "kd", "kr", "kl",
# ifdef ARCHIE
  "su", "sd",           /* Termcap code made up! */
# endif
  "#2", "#4", "%i", "*7",
  "k1", "k2", "k3", "k4", "k5", "k6",
  "k7", "k8", "k9", "k;", "F1", "F2",
  "%1", "&8", "kb", "kI", "kD", "kh",
  "@7", "kP", "kN", "K1", "K3", "K4", "K5", "kB",
  NULL
};
#endif

/*
 * Set terminal options for terminal "term".
 * Return OK if terminal 'term' was found in a termcap, FAIL otherwise.
 *
 * While doing this, until ttest(), some options may be NULL, be careful.
 */
int set_termname(char_u *term)
{
  struct builtin_term *termp;
#ifdef HAVE_TGETENT
  int builtin_first = p_tbi;
  int try;
  int termcap_cleared = FALSE;
#endif
  int width = 0, height = 0;
  char_u      *error_msg = NULL;
  char_u      *bs_p, *del_p;

  /* In silect mode (ex -s) we don't use the 'term' option. */
  if (silent_mode)
    return OK;

  detected_8bit = FALSE;                /* reset 8-bit detection */

  if (term_is_builtin(term)) {
    term += 8;
#ifdef HAVE_TGETENT
    builtin_first = 1;
#endif
  }

  /*
   * If HAVE_TGETENT is not defined, only the builtin termcap is used, otherwise:
   *   If builtin_first is TRUE:
   *     0. try builtin termcap
   *     1. try external termcap
   *     2. if both fail default to a builtin terminal
   *   If builtin_first is FALSE:
   *     1. try external termcap
   *     2. try builtin termcap, if both fail default to a builtin terminal
   */
#ifdef HAVE_TGETENT
  for (try = builtin_first ? 0 : 1; try < 3; ++try) {
    /*
     * Use external termcap
     */
    if (try == 1) {
      char_u          *p;
      static char_u tstrbuf[TBUFSZ];
      int i;
      char_u tbuf[TBUFSZ];
      char_u          *tp;
      static struct {
        enum SpecialKey dest;                     /* index in term_strings[] */
        char *name;                               /* termcap name for string */
      } string_names[] =
      {   {KS_CE, "ce"}, {KS_AL, "al"}, {KS_CAL,"AL"},
          {KS_DL, "dl"}, {KS_CDL,"DL"}, {KS_CS, "cs"},
          {KS_CL, "cl"}, {KS_CD, "cd"},
          {KS_VI, "vi"}, {KS_VE, "ve"}, {KS_MB, "mb"},
          {KS_VS, "vs"}, {KS_ME, "me"}, {KS_MR, "mr"},
          {KS_MD, "md"}, {KS_SE, "se"}, {KS_SO, "so"},
          {KS_CZH,"ZH"}, {KS_CZR,"ZR"}, {KS_UE, "ue"},
          {KS_US, "us"}, {KS_UCE, "Ce"}, {KS_UCS, "Cs"},
          {KS_CM, "cm"}, {KS_SR, "sr"},
          {KS_CRI,"RI"}, {KS_VB, "vb"}, {KS_KS, "ks"},
          {KS_KE, "ke"}, {KS_TI, "ti"}, {KS_TE, "te"},
          {KS_BC, "bc"}, {KS_CSB,"Sb"}, {KS_CSF,"Sf"},
          {KS_CAB,"AB"}, {KS_CAF,"AF"}, {KS_LE, "le"},
          {KS_ND, "nd"}, {KS_OP, "op"}, {KS_CRV, "RV"},
          {KS_CIS, "IS"}, {KS_CIE, "IE"},
          {KS_TS, "ts"}, {KS_FS, "fs"},
          {KS_CWP, "WP"}, {KS_CWS, "WS"},
          {KS_CSI, "SI"}, {KS_CEI, "EI"},
          {KS_U7, "u7"},
          {(enum SpecialKey)0, NULL}};

      /*
       * If the external termcap does not have a matching entry, try the
       * builtin ones.
       */
      if ((error_msg = tgetent_error(tbuf, term)) == NULL) {
        tp = tstrbuf;
        if (!termcap_cleared) {
          clear_termoptions();                  /* clear old options */
          termcap_cleared = TRUE;
        }

        /* get output strings */
        for (i = 0; string_names[i].name != NULL; ++i) {
          if (term_str(string_names[i].dest) == NULL
              || term_str(string_names[i].dest) == empty_option)
            term_str(string_names[i].dest) =
              TGETSTR(string_names[i].name, &tp);
        }

        /* tgetflag() returns 1 if the flag is present, 0 if not and
         * possibly -1 if the flag doesn't exist. */
        if ((T_MS == NULL || T_MS == empty_option)
            && tgetflag("ms") > 0)
          T_MS = (char_u *)"y";
        if ((T_XS == NULL || T_XS == empty_option)
            && tgetflag("xs") > 0)
          T_XS = (char_u *)"y";
        if ((T_DB == NULL || T_DB == empty_option)
            && tgetflag("db") > 0)
          T_DB = (char_u *)"y";
        if ((T_DA == NULL || T_DA == empty_option)
            && tgetflag("da") > 0)
          T_DA = (char_u *)"y";
        if ((T_UT == NULL || T_UT == empty_option)
            && tgetflag("ut") > 0)
          T_UT = (char_u *)"y";


        /*
         * get key codes
         */
        for (i = 0; key_names[i] != NULL; ++i) {
          if (find_termcode((char_u *)key_names[i]) == NULL) {
            p = TGETSTR(key_names[i], &tp);
            /* if cursor-left == backspace, ignore it (televideo
             * 925) */
            if (p != NULL
                && (*p != Ctrl_H
                    || key_names[i][0] != 'k'
                    || key_names[i][1] != 'l'))
              add_termcode((char_u *)key_names[i], p, FALSE);
          }
        }

        if (height == 0)
          height = tgetnum("li");
        if (width == 0)
          width = tgetnum("co");

        /*
         * Get number of colors (if not done already).
         */
        if (term_str(KS_CCO) == NULL
            || term_str(KS_CCO) == empty_option)
          set_color_count(tgetnum("Co"));

# ifndef hpux
        BC = (char *)TGETSTR("bc", &tp);
        UP = (char *)TGETSTR("up", &tp);
        p = TGETSTR("pc", &tp);
        if (p)
          PC = *p;
# endif /* hpux */
      }
    } else          /* try == 0 || try == 2 */
#endif /* HAVE_TGETENT */
       /*
        * Use builtin termcap
        */
  {
#ifdef HAVE_TGETENT
    /*
     * If builtin termcap was already used, there is no need to search
     * for the builtin termcap again, quit now.
     */
    if (try == 2 && builtin_first && termcap_cleared)
      break;
#endif
    /*
     * search for 'term' in builtin_termcaps[]
     */
    termp = find_builtin_term(term);
    if (termp->bt_string == NULL) {             /* did not find it */
#ifdef HAVE_TGETENT
      /*
       * If try == 0, first try the external termcap. If that is not
       * found we'll get back here with try == 2.
       * If termcap_cleared is set we used the external termcap,
       * don't complain about not finding the term in the builtin
       * termcap.
       */
      if (try == 0)                             /* try external one */
        continue;
      if (termcap_cleared)                      /* found in external termcap */
        break;
#endif

      mch_errmsg("\r\n");
      if (error_msg != NULL) {
        mch_errmsg((char *)error_msg);
        mch_errmsg("\r\n");
      }
      mch_errmsg("'");
      mch_errmsg((char *)term);
      mch_errmsg(_("' not known. Available builtin terminals are:"));
      mch_errmsg("\r\n");
      for (termp = &(builtin_termcaps[0]); termp->bt_string != NULL;
           ++termp) {
        if (termp->bt_entry == (int)KS_NAME) {
#ifdef HAVE_TGETENT
          mch_errmsg("    builtin_");
#else
          mch_errmsg("    ");
#endif
          mch_errmsg(termp->bt_string);
          mch_errmsg("\r\n");
        }
      }
      /* when user typed :set term=xxx, quit here */
      if (starting != NO_SCREEN) {
        screen_start();                 /* don't know where cursor is now */
        wait_return(TRUE);
        return FAIL;
      }
      term = DEFAULT_TERM;
      mch_errmsg(_("defaulting to '"));
      mch_errmsg((char *)term);
      mch_errmsg("'\r\n");
      if (emsg_silent == 0) {
        screen_start();                 /* don't know where cursor is now */
        out_flush();
        ui_delay(2000L, TRUE);
      }
      set_string_option_direct((char_u *)"term", -1, term,
          OPT_FREE, 0);
      display_errors();
    }
    out_flush();
#ifdef HAVE_TGETENT
    if (!termcap_cleared) {
#endif
    clear_termoptions();                    /* clear old options */
#ifdef HAVE_TGETENT
    termcap_cleared = TRUE;
  }
#endif
    parse_builtin_tcap(term);
  }
#ifdef HAVE_TGETENT
}
#endif

  /*
   * special: There is no info in the termcap about whether the cursor
   * positioning is relative to the start of the screen or to the start of the
   * scrolling region.  We just guess here. Only msdos pcterm is known to do it
   * relative.
   */
  if (STRCMP(term, "pcterm") == 0)
    T_CCS = (char_u *)"yes";
  else
    T_CCS = empty_option;

#ifdef UNIX
  /*
   * Any "stty" settings override the default for t_kb from the termcap.
   * This is in os_unix.c, because it depends a lot on the version of unix that
   * is being used.
   * Don't do this when the GUI is active, it uses "t_kb" and "t_kD" directly.
   */
  get_stty();
#endif

  /*
   * If the termcap has no entry for 'bs' and/or 'del' and the ioctl() also
   * didn't work, use the default CTRL-H
   * The default for t_kD is DEL, unless t_kb is DEL.
   * The vim_strsave'd strings are probably lost forever, well it's only two
   * bytes.  Don't do this when the GUI is active, it uses "t_kb" and "t_kD"
   * directly.
   */
  {
    bs_p = find_termcode((char_u *)"kb");
    del_p = find_termcode((char_u *)"kD");
    if (bs_p == NULL || *bs_p == NUL)
      add_termcode((char_u *)"kb", (bs_p = (char_u *)CTRL_H_STR), FALSE);
    if ((del_p == NULL || *del_p == NUL) &&
        (bs_p == NULL || *bs_p != DEL))
      add_termcode((char_u *)"kD", (char_u *)DEL_STR, FALSE);
  }

#if defined(UNIX) || defined(VMS)
  term_is_xterm = vim_is_xterm(term);
#endif

# if defined(UNIX) || defined(VMS)
  /*
   * For Unix, set the 'ttymouse' option to the type of mouse to be used.
   * The termcode for the mouse is added as a side effect in option.c.
   */
  {
    char_u  *p;

    p = (char_u *)"";
    if (use_xterm_like_mouse(term)) {
      if (use_xterm_mouse())
        p = NULL;               /* keep existing value, might be "xterm2" */
      else
        p = (char_u *)"xterm";
    }
    if (p != NULL) {
      set_option_value((char_u *)"ttym", 0L, p, 0);
      /* Reset the WAS_SET flag, 'ttymouse' can be set to "sgr" or
       * "xterm2" in check_termcode(). */
      reset_option_was_set((char_u *)"ttym");
    }
    if (p == NULL
        )
      check_mouse_termcode();           /* set mouse termcode anyway */
  }
# else
  set_mouse_termcode(KS_MOUSE, (char_u *)"\233M");
# endif


#ifdef USE_TERM_CONSOLE
  /* DEFAULT_TERM indicates that it is the machine console. */
  if (STRCMP(term, DEFAULT_TERM) != 0)
    term_console = FALSE;
  else {
    term_console = TRUE;
  }
#endif

#if defined(UNIX) || defined(VMS)
  /*
   * 'ttyfast' is default on for xterm, iris-ansi and a few others.
   */
  if (vim_is_fastterm(term))
    p_tf = TRUE;
#endif
#ifdef USE_TERM_CONSOLE
  /*
   * 'ttyfast' is default on consoles
   */
  if (term_console)
    p_tf = TRUE;
#endif

  ttest(TRUE);          /* make sure we have a valid set of terminal codes */

  full_screen = TRUE;           /* we can use termcap codes from now on */
  set_term_defaults();          /* use current values as defaults */
  LOG_TR("setting crv_status to CRV_GET");
  crv_status = CRV_GET;         /* Get terminal version later */

  /*
   * Initialize the terminal with the appropriate termcap codes.
   * Set the mouse and window title if possible.
   * Don't do this when starting, need to parse the .vimrc first, because it
   * may redefine t_TI etc.
   */
  if (starting != NO_SCREEN) {
    starttermcap();             /* may change terminal mode */
    setmouse();                 /* may start using the mouse */
    maketitle();                /* may display window title */
  }

  /* display initial screen after ttest() checking. jw. */
  if (width <= 0 || height <= 0) {
    /* termcap failed to report size */
    /* set defaults, in case ui_get_shellsize() also fails */
    width = 80;
    height = 24;            /* most terminals are 24 lines */
  }
  set_shellsize(width, height, FALSE);          /* may change Rows */
  if (starting != NO_SCREEN) {
    if (scroll_region)
      scroll_region_reset();                    /* In case Rows changed */
    check_map_keycodes();       /* check mappings for terminal codes used */

    {
      buf_T       *old_curbuf;

      /*
       * Execute the TermChanged autocommands for each buffer that is
       * loaded.
       */
      old_curbuf = curbuf;
      for (curbuf = firstbuf; curbuf != NULL; curbuf = curbuf->b_next) {
        if (curbuf->b_ml.ml_mfp != NULL)
          apply_autocmds(EVENT_TERMCHANGED, NULL, NULL, FALSE,
              curbuf);
      }
      if (buf_valid(old_curbuf))
        curbuf = old_curbuf;
    }
  }

  may_req_termresponse();

  return OK;
}


#  define HMT_NORMAL    1
#  define HMT_NETTERM   2
#  define HMT_DEC       4
#  define HMT_JSBTERM   8
#  define HMT_PTERM     16
#  define HMT_URXVT     32
#  define HMT_SGR       64
static int has_mouse_termcode = 0;

void 
set_mouse_termcode (
    int n,                  /* KS_MOUSE, KS_NETTERM_MOUSE or KS_DEC_MOUSE */
    char_u *s
)
{
  char_u name[2];

  name[0] = n;
  name[1] = KE_FILLER;
  add_termcode(name, s, FALSE);
#   ifdef FEAT_MOUSE_JSB
  if (n == KS_JSBTERM_MOUSE)
    has_mouse_termcode |= HMT_JSBTERM;
  else
#   endif
  if (n == KS_NETTERM_MOUSE)
    has_mouse_termcode |= HMT_NETTERM;
  else if (n == KS_DEC_MOUSE)
    has_mouse_termcode |= HMT_DEC;
  else if (n == KS_URXVT_MOUSE)
    has_mouse_termcode |= HMT_URXVT;
  else if (n == KS_SGR_MOUSE)
    has_mouse_termcode |= HMT_SGR;
  else
    has_mouse_termcode |= HMT_NORMAL;
}

# if ((defined(UNIX) || defined(VMS) || defined(OS2)) \
  && defined(FEAT_MOUSE_TTY)) || defined(PROTO)
void 
del_mouse_termcode (
    int n                  /* KS_MOUSE, KS_NETTERM_MOUSE or KS_DEC_MOUSE */
)
{
  char_u name[2];

  name[0] = n;
  name[1] = KE_FILLER;
  del_termcode(name);
#   ifdef FEAT_MOUSE_JSB
  if (n == KS_JSBTERM_MOUSE)
    has_mouse_termcode &= ~HMT_JSBTERM;
  else
#   endif
  if (n == KS_NETTERM_MOUSE)
    has_mouse_termcode &= ~HMT_NETTERM;
  else if (n == KS_DEC_MOUSE)
    has_mouse_termcode &= ~HMT_DEC;
  else if (n == KS_URXVT_MOUSE)
    has_mouse_termcode &= ~HMT_URXVT;
  else if (n == KS_SGR_MOUSE)
    has_mouse_termcode &= ~HMT_SGR;
  else
    has_mouse_termcode &= ~HMT_NORMAL;
}
# endif

#ifdef HAVE_TGETENT
/*
 * Call tgetent()
 * Return error message if it fails, NULL if it's OK.
 */
static char_u *tgetent_error(char_u *tbuf, char_u *term)
{
  int i;

  i = TGETENT(tbuf, term);
  if (i < 0                 /* -1 is always an error */
# ifdef TGETENT_ZERO_ERR
      || i == 0             /* sometimes zero is also an error */
# endif
      ) {
    /* On FreeBSD tputs() gets a SEGV after a tgetent() which fails.  Call
     * tgetent() with the always existing "dumb" entry to avoid a crash or
     * hang. */
    (void)TGETENT(tbuf, "dumb");

    if (i < 0)
# ifdef TGETENT_ZERO_ERR
      return (char_u *)_("E557: Cannot open termcap file");
    if (i == 0)
# endif
#ifdef TERMINFO
      return (char_u *)_("E558: Terminal entry not found in terminfo");
#else
      return (char_u *)_("E559: Terminal entry not found in termcap");
#endif
  }
  return NULL;
}

/*
 * Some versions of tgetstr() have been reported to return -1 instead of NULL.
 * Fix that here.
 */
static char_u *vim_tgetstr(char *s, char_u **pp)
{
  char        *p;

  p = tgetstr(s, (char **)pp);
  if (p == (char *)-1)
    p = NULL;
  return (char_u *)p;
}
#endif /* HAVE_TGETENT */

#if defined(HAVE_TGETENT) && (defined(UNIX) || defined(__EMX__) || \
  defined(VMS) || defined(MACOS_X))
/*
 * Get Columns and Rows from the termcap. Used after a window signal if the
 * ioctl() fails. It doesn't make sense to call tgetent each time if the "co"
 * and "li" entries never change. But on some systems this works.
 * Errors while getting the entries are ignored.
 */
void 
getlinecol (
    long *cp,        /* pointer to columns */
    long *rp        /* pointer to rows */
)
{
  char_u tbuf[TBUFSZ];

  if (T_NAME != NULL && *T_NAME != NUL &&
      tgetent_error(tbuf, T_NAME) == NULL) {
    if (*cp == 0)
      *cp = tgetnum("co");
    if (*rp == 0)
      *rp = tgetnum("li");
  }
}
#endif /* defined(HAVE_TGETENT) && defined(UNIX) */

/*
 * Get a string entry from the termcap and add it to the list of termcodes.
 * Used for <t_xx> special keys.
 * Give an error message for failure when not sourcing.
 * If force given, replace an existing entry.
 * Return FAIL if the entry was not found, OK if the entry was added.
 */
int add_termcap_entry(char_u *name, int force)
{
  char_u  *term;
  int key;
  struct builtin_term *termp;
#ifdef HAVE_TGETENT
  char_u  *string;
  int i;
  int builtin_first;
  char_u tbuf[TBUFSZ];
  char_u tstrbuf[TBUFSZ];
  char_u  *tp = tstrbuf;
  char_u  *error_msg = NULL;
#endif

  /*
   * If the GUI is running or will start in a moment, we only support the keys
   * that the GUI can produce.
   */

  if (!force && find_termcode(name) != NULL)        /* it's already there */
    return OK;

  term = T_NAME;
  if (term == NULL || *term == NUL)         /* 'term' not defined yet */
    return FAIL;

  if (term_is_builtin(term)) {              /* name starts with "builtin_" */
    term += 8;
#ifdef HAVE_TGETENT
    builtin_first = TRUE;
#endif
  }
#ifdef HAVE_TGETENT
  else
    builtin_first = p_tbi;
#endif

#ifdef HAVE_TGETENT
  /*
   * We can get the entry from the builtin termcap and from the external one.
   * If 'ttybuiltin' is on or the terminal name starts with "builtin_", try
   * builtin termcap first.
   * If 'ttybuiltin' is off, try external termcap first.
   */
  for (i = 0; i < 2; ++i) {
    if (!builtin_first == i)
#endif
  /*
   * Search in builtin termcap
   */
  {
    termp = find_builtin_term(term);
    if (termp->bt_string != NULL) {             /* found it */
      key = TERMCAP2KEY(name[0], name[1]);
      while (termp->bt_entry != (int)KS_NAME) {
        if ((int)termp->bt_entry == key) {
          add_termcode(name, (char_u *)termp->bt_string,
              term_is_8bit(term));
          return OK;
        }
        ++termp;
      }
    }
  }
#ifdef HAVE_TGETENT
  else {
    /*
     * Search in external termcap
     */
    error_msg = tgetent_error(tbuf, term);
    if (error_msg == NULL) {
      string = TGETSTR((char *)name, &tp);
      if (string != NULL && *string != NUL) {
        add_termcode(name, string, FALSE);
        return OK;
      }
    }
  }
}
#endif

  if (sourcing_name == NULL) {
#ifdef HAVE_TGETENT
    if (error_msg != NULL)
      EMSG(error_msg);
    else
#endif
    EMSG2(_("E436: No \"%s\" entry in termcap"), name);
  }
  return FAIL;
}

static int term_is_builtin(char_u *name)
{
  return STRNCMP(name, "builtin_", (size_t)8) == 0;
}

/*
 * Return TRUE if terminal "name" uses CSI instead of <Esc>[.
 * Assume that the terminal is using 8-bit controls when the name contains
 * "8bit", like in "xterm-8bit".
 */
int term_is_8bit(char_u *name)
{
  return detected_8bit || strstr((char *)name, "8bit") != NULL;
}

/*
 * Translate terminal control chars from 7-bit to 8-bit:
 * <Esc>[ -> CSI
 * <Esc>] -> <M-C-]>
 * <Esc>O -> <M-C-O>
 */
static int term_7to8bit(char_u *p)
{
  if (*p == ESC) {
    if (p[1] == '[')
      return CSI;
    if (p[1] == ']')
      return 0x9d;
    if (p[1] == 'O')
      return 0x8f;
  }
  return 0;
}


#if !defined(HAVE_TGETENT) || defined(AMIGA) || defined(PROTO)

char_u *tltoa(unsigned long i)
{
  static char_u buf[16];
  char_u      *p;

  p = buf + 15;
  *p = '\0';
  do {
    --p;
    *p = (char_u) (i % 10 + '0');
    i /= 10;
  } while (i > 0 && p > buf);
  return p;
}
#endif

#ifndef HAVE_TGETENT

/*
 * minimal tgoto() implementation.
 * no padding and we only parse for %i %d and %+char
 */
static char *tgoto(char *, int, int);

static char *tgoto(char *cm, int x, int y)
{
  static char buf[30];
  char *p, *s, *e;

  if (!cm)
    return "OOPS";
  e = buf + 29;
  for (s = buf; s < e && *cm; cm++) {
    if (*cm != '%') {
      *s++ = *cm;
      continue;
    }
    switch (*++cm) {
    case 'd':
      p = (char *)tltoa((unsigned long)y);
      y = x;
      while (*p)
        *s++ = *p++;
      break;
    case 'i':
      x++;
      y++;
      break;
    case '+':
      *s++ = (char)(*++cm + y);
      y = x;
      break;
    case '%':
      *s++ = *cm;
      break;
    default:
      return "OOPS";
    }
  }
  *s = '\0';
  return buf;
}

#endif /* HAVE_TGETENT */

/*
 * Set the terminal name and initialize the terminal options.
 * If "name" is NULL or empty, get the terminal name from the environment.
 * If that fails, use the default terminal name.
 */
void termcapinit(char_u *name)
{
  char_u      *term;

  if (name != NULL && *name == NUL)
    name = NULL;            /* empty name is equal to no name */
  term = name;

  if (term == NULL)
    term = mch_getenv((char_u *)"TERM");
  if (term == NULL || *term == NUL)
    term = DEFAULT_TERM;
  set_string_option_direct((char_u *)"term", -1, term, OPT_FREE, 0);

  /* Set the default terminal name. */
  set_string_default("term", term);
  set_string_default("ttytype", term);

  /*
   * Avoid using "term" here, because the next mch_getenv() may overwrite it.
   */
  set_termname(T_NAME != NULL ? T_NAME : term);
}

/*
 * the number of calls to ui_write is reduced by using the buffer "out_buf"
 */
#  define OUT_SIZE      2047
/* Add one to allow mch_write() in os_win32.c to append a NUL */
static char_u out_buf[OUT_SIZE + 1];
static int out_pos = 0;                 /* number of chars in out_buf */

/*
 * out_flush(): flush the output buffer
 */
void out_flush(void)          {
  int len;

  if (out_pos != 0) {
    /* set out_pos to 0 before ui_write, to avoid recursiveness */
    len = out_pos;
    out_pos = 0;
    ui_write(out_buf, len);
  }
}

/*
 * Sometimes a byte out of a multi-byte character is written with out_char().
 * To avoid flushing half of the character, call this function first.
 */
void out_flush_check(void)          {
  if (enc_dbcs != 0 && out_pos >= OUT_SIZE - MB_MAXBYTES)
    out_flush();
}

/*
 * out_char(c): put a byte into the output buffer.
 *		Flush it if it becomes full.
 * This should not be used for outputting text on the screen (use functions
 * like msg_puts() and screen_putchar() for that).
 */
void out_char(unsigned c)
{
#if defined(UNIX) || defined(VMS) || defined(AMIGA) || defined(MACOS_X_UNIX)
  if (c == '\n')        /* turn LF into CR-LF (CRMOD doesn't seem to do this) */
    out_char('\r');
#endif

  out_buf[out_pos++] = c;

  /* For testing we flush each time. */
  if (out_pos >= OUT_SIZE || p_wd)
    out_flush();
}

static void out_char_nf(unsigned);

/*
 * out_char_nf(c): like out_char(), but don't flush when p_wd is set
 */
static void out_char_nf(unsigned c)
{
#if defined(UNIX) || defined(VMS) || defined(AMIGA) || defined(MACOS_X_UNIX)
  if (c == '\n')        /* turn LF into CR-LF (CRMOD doesn't seem to do this) */
    out_char_nf('\r');
#endif

  out_buf[out_pos++] = c;

  if (out_pos >= OUT_SIZE)
    out_flush();
}

#if defined(FEAT_TITLE) || defined(FEAT_MOUSE_TTY) || defined(FEAT_GUI) \
  || defined(FEAT_TERMRESPONSE) || defined(PROTO)
/*
 * A never-padding out_str.
 * use this whenever you don't want to run the string through tputs.
 * tputs above is harmless, but tputs from the termcap library
 * is likely to strip off leading digits, that it mistakes for padding
 * information, and "%i", "%d", etc.
 * This should only be used for writing terminal codes, not for outputting
 * normal text (use functions like msg_puts() and screen_putchar() for that).
 */
void out_str_nf(char_u *s)
{
  if (out_pos > OUT_SIZE - 20)    /* avoid terminal strings being split up */
    out_flush();
  while (*s)
    out_char_nf(*s++);

  /* For testing we write one string at a time. */
  if (p_wd)
    out_flush();
}
#endif

/*
 * out_str(s): Put a character string a byte at a time into the output buffer.
 * If HAVE_TGETENT is defined use the termcap parser. (jw)
 * This should only be used for writing terminal codes, not for outputting
 * normal text (use functions like msg_puts() and screen_putchar() for that).
 */
void out_str(char_u *s)
{
  if (s != NULL && *s) {
    /* avoid terminal strings being split up */
    if (out_pos > OUT_SIZE - 20)
      out_flush();
#ifdef HAVE_TGETENT
    tputs((char *)s, 1, TPUTSFUNCAST out_char_nf);
#else
    while (*s)
      out_char_nf(*s++);
#endif

    /* For testing we write one string at a time. */
    if (p_wd)
      out_flush();
  }
}

/*
 * cursor positioning using termcap parser. (jw)
 */
void term_windgoto(int row, int col)
{
  OUT_STR(tgoto((char *)T_CM, col, row));
}

void term_cursor_right(int i)
{
  OUT_STR(tgoto((char *)T_CRI, 0, i));
}

void term_append_lines(int line_count)
{
  OUT_STR(tgoto((char *)T_CAL, 0, line_count));
}

void term_delete_lines(int line_count)
{
  OUT_STR(tgoto((char *)T_CDL, 0, line_count));
}

#if defined(HAVE_TGETENT) || defined(PROTO)
void term_set_winpos(int x, int y)
{
  /* Can't handle a negative value here */
  if (x < 0)
    x = 0;
  if (y < 0)
    y = 0;
  OUT_STR(tgoto((char *)T_CWP, y, x));
}

void term_set_winsize(int width, int height)
{
  OUT_STR(tgoto((char *)T_CWS, height, width));
}
#endif

void term_fg_color(int n)
{
  /* Use "AF" termcap entry if present, "Sf" entry otherwise */
  if (*T_CAF)
    term_color(T_CAF, n);
  else if (*T_CSF)
    term_color(T_CSF, n);
}

void term_bg_color(int n)
{
  /* Use "AB" termcap entry if present, "Sb" entry otherwise */
  if (*T_CAB)
    term_color(T_CAB, n);
  else if (*T_CSB)
    term_color(T_CSB, n);
}

static void term_color(char_u *s, int n)
{
  char buf[20];
  int i = 2;    /* index in s[] just after <Esc>[ or CSI */

  /* Special handling of 16 colors, because termcap can't handle it */
  /* Also accept "\e[3%dm" for TERMINFO, it is sometimes used */
  /* Also accept CSI instead of <Esc>[ */
  if (n >= 8 && t_colors >= 16
      && ((s[0] == ESC && s[1] == '[') || (s[0] == CSI && (i = 1) == 1))
      && s[i] != NUL
      && (STRCMP(s + i + 1, "%p1%dm") == 0
          || STRCMP(s + i + 1, "%dm") == 0)
      && (s[i] == '3' || s[i] == '4')) {
    const char *fmt =
#ifdef TERMINFO
        "%s%s%%p1%%dm";
#else
        "%s%s%%dm";
#endif
    sprintf(buf,
        fmt,
        i == 2 ? IF_EB("\033[", ESC_STR "[") : "\233",
        s[i] == '3' ? (n >= 16 ? "38;5;" : "9")
        : (n >= 16 ? "48;5;" : "10"));
    OUT_STR(tgoto(buf, 0, n >= 16 ? n : n - 8));
  } else
    OUT_STR(tgoto((char *)s, 0, n));
}

#if (defined(FEAT_TITLE) && (defined(UNIX) || defined(OS2) || defined(VMS) || \
  defined(MACOS_X))) || defined(PROTO)
/*
 * Generic function to set window title, using t_ts and t_fs.
 */
void term_settitle(char_u *title)
{
  /* t_ts takes one argument: column in status line */
  OUT_STR(tgoto((char *)T_TS, 0, 0));   /* set title start */
  out_str_nf(title);
  out_str(T_FS);                        /* set title end */
  out_flush();
}
#endif

/*
 * Make sure we have a valid set or terminal options.
 * Replace all entries that are NULL by empty_option
 */
void ttest(int pairs)
{
  check_options();                  /* make sure no options are NULL */

  /*
   * MUST have "cm": cursor motion.
   */
  if (*T_CM == NUL)
    EMSG(_("E437: terminal capability \"cm\" required"));

  /*
   * if "cs" defined, use a scroll region, it's faster.
   */
  if (*T_CS != NUL)
    scroll_region = TRUE;
  else
    scroll_region = FALSE;

  if (pairs) {
    /*
     * optional pairs
     */
    /* TP goes to normal mode for TI (invert) and TB (bold) */
    if (*T_ME == NUL)
      T_ME = T_MR = T_MD = T_MB = empty_option;
    if (*T_SO == NUL || *T_SE == NUL)
      T_SO = T_SE = empty_option;
    if (*T_US == NUL || *T_UE == NUL)
      T_US = T_UE = empty_option;
    if (*T_CZH == NUL || *T_CZR == NUL)
      T_CZH = T_CZR = empty_option;

    /* T_VE is needed even though T_VI is not defined */
    if (*T_VE == NUL)
      T_VI = empty_option;

    /* if 'mr' or 'me' is not defined use 'so' and 'se' */
    if (*T_ME == NUL) {
      T_ME = T_SE;
      T_MR = T_SO;
      T_MD = T_SO;
    }

    /* if 'so' or 'se' is not defined use 'mr' and 'me' */
    if (*T_SO == NUL) {
      T_SE = T_ME;
      if (*T_MR == NUL)
        T_SO = T_MD;
      else
        T_SO = T_MR;
    }

    /* if 'ZH' or 'ZR' is not defined use 'mr' and 'me' */
    if (*T_CZH == NUL) {
      T_CZR = T_ME;
      if (*T_MR == NUL)
        T_CZH = T_MD;
      else
        T_CZH = T_MR;
    }

    /* "Sb" and "Sf" come in pairs */
    if (*T_CSB == NUL || *T_CSF == NUL) {
      T_CSB = empty_option;
      T_CSF = empty_option;
    }

    /* "AB" and "AF" come in pairs */
    if (*T_CAB == NUL || *T_CAF == NUL) {
      T_CAB = empty_option;
      T_CAF = empty_option;
    }

    /* if 'Sb' and 'AB' are not defined, reset "Co" */
    if (*T_CSB == NUL && *T_CAB == NUL)
      free_one_termoption(T_CCO);

    /* Set 'weirdinvert' according to value of 't_xs' */
    p_wiv = (*T_XS != NUL);
  }
  need_gather = TRUE;

  /* Set t_colors to the value of t_Co. */
  t_colors = atoi((char *)T_CCO);
}

#if (defined(FEAT_GUI) && (defined(FEAT_MENU) || !defined(USE_ON_FLY_SCROLL))) \
  || defined(PROTO)
/*
 * Represent the given long_u as individual bytes, with the most significant
 * byte first, and store them in dst.
 */
void add_long_to_buf(long_u val, char_u *dst)
{
  int i;
  int shift;

  for (i = 1; i <= (int)sizeof(long_u); i++) {
    shift = 8 * (sizeof(long_u) - i);
    dst[i - 1] = (char_u) ((val >> shift) & 0xff);
  }
}

static int get_long_from_buf(char_u *buf, long_u *val);

/*
 * Interpret the next string of bytes in buf as a long integer, with the most
 * significant byte first.  Note that it is assumed that buf has been through
 * inchar(), so that NUL and K_SPECIAL will be represented as three bytes each.
 * Puts result in val, and returns the number of bytes read from buf
 * (between sizeof(long_u) and 2 * sizeof(long_u)), or -1 if not enough bytes
 * were present.
 */
static int get_long_from_buf(char_u *buf, long_u *val)
{
  int len;
  char_u bytes[sizeof(long_u)];
  int i;
  int shift;

  *val = 0;
  len = get_bytes_from_buf(buf, bytes, (int)sizeof(long_u));
  if (len != -1) {
    for (i = 0; i < (int)sizeof(long_u); i++) {
      shift = 8 * (sizeof(long_u) - 1 - i);
      *val += (long_u)bytes[i] << shift;
    }
  }
  return len;
}
#endif

#if defined(FEAT_GUI) \
  || (defined(FEAT_MOUSE) && (!defined(UNIX) || defined(FEAT_MOUSE_XTERM) \
  || defined(FEAT_MOUSE_GPM) || defined(FEAT_SYSMOUSE)))
/*
 * Read the next num_bytes bytes from buf, and store them in bytes.  Assume
 * that buf has been through inchar().	Returns the actual number of bytes used
 * from buf (between num_bytes and num_bytes*2), or -1 if not enough bytes were
 * available.
 */
static int get_bytes_from_buf(char_u *buf, char_u *bytes, int num_bytes)
{
  int len = 0;
  int i;
  char_u c;

  for (i = 0; i < num_bytes; i++) {
    if ((c = buf[len++]) == NUL)
      return -1;
    if (c == K_SPECIAL) {
      if (buf[len] == NUL || buf[len + 1] == NUL)           /* cannot happen? */
        return -1;
      if (buf[len++] == (int)KS_ZERO)
        c = NUL;
      /* else it should be KS_SPECIAL; when followed by KE_FILLER c is
       * K_SPECIAL, or followed by KE_CSI and c must be CSI. */
      if (buf[len++] == (int)KE_CSI)
        c = CSI;
    } else if (c == CSI && buf[len] == KS_EXTRA
               && buf[len + 1] == (int)KE_CSI)
      /* CSI is stored as CSI KS_SPECIAL KE_CSI to avoid confusion with
       * the start of a special key, see add_to_input_buf_csi(). */
      len += 2;
    bytes[i] = c;
  }
  return len;
}
#endif

/*
 * Check if the new shell size is valid, correct it if it's too small or way
 * too big.
 */
void check_shellsize(void)          {
  if (Rows < min_rows())        /* need room for one window and command line */
    Rows = min_rows();
  limit_screen_size();
}

/*
 * Limit Rows and Columns to avoid an overflow in Rows * Columns.
 */
void limit_screen_size(void)          {
  if (Columns < MIN_COLUMNS)
    Columns = MIN_COLUMNS;
  else if (Columns > 10000)
    Columns = 10000;
  if (Rows > 1000)
    Rows = 1000;
}

/*
 * Invoked just before the screen structures are going to be (re)allocated.
 */
void win_new_shellsize(void)          {
  static int old_Rows = 0;
  static int old_Columns = 0;

  if (old_Rows != Rows || old_Columns != Columns)
    ui_new_shellsize();
  if (old_Rows != Rows) {
    /* if 'window' uses the whole screen, keep it using that */
    if (p_window == old_Rows - 1 || old_Rows == 0)
      p_window = Rows - 1;
    old_Rows = Rows;
    shell_new_rows();           /* update window sizes */
  }
  if (old_Columns != Columns) {
    old_Columns = Columns;
    shell_new_columns();        /* update window sizes */
  }
}

/*
 * Call this function when the Vim shell has been resized in any way.
 * Will obtain the current size and redraw (also when size didn't change).
 */
void shell_resized(void)          {
  set_shellsize(0, 0, FALSE);
}

/*
 * Check if the shell size changed.  Handle a resize.
 * When the size didn't change, nothing happens.
 */
void shell_resized_check(void)          {
  int old_Rows = Rows;
  int old_Columns = Columns;

  if (!exiting
      ) {
    (void)ui_get_shellsize();
    check_shellsize();
    if (old_Rows != Rows || old_Columns != Columns)
      shell_resized();
  }
}

/*
 * Set size of the Vim shell.
 * If 'mustset' is TRUE, we must set Rows and Columns, do not get the real
 * window size (this is used for the :win command).
 * If 'mustset' is FALSE, we may try to get the real window size and if
 * it fails use 'width' and 'height'.
 */
void set_shellsize(int width, int height, int mustset)
{
  static int busy = FALSE;

  /*
   * Avoid recursiveness, can happen when setting the window size causes
   * another window-changed signal.
   */
  if (busy)
    return;

  if (width < 0 || height < 0)      /* just checking... */
    return;

  if (State == HITRETURN || State == SETWSIZE) {
    /* postpone the resizing */
    State = SETWSIZE;
    return;
  }

  /* curwin->w_buffer can be NULL when we are closing a window and the
   * buffer has already been closed and removing a scrollbar causes a resize
   * event. Don't resize then, it will happen after entering another buffer.
   */
  if (curwin->w_buffer == NULL)
    return;

  ++busy;


  if (mustset || (ui_get_shellsize() == FAIL && height != 0)) {
    Rows = height;
    Columns = width;
    check_shellsize();
    ui_set_shellsize(mustset);
  } else
    check_shellsize();

  /* The window layout used to be adjusted here, but it now happens in
   * screenalloc() (also invoked from screenclear()).  That is because the
   * "busy" check above may skip this, but not screenalloc(). */

  if (State != ASKMORE && State != EXTERNCMD && State != CONFIRM)
    screenclear();
  else
    screen_start();         /* don't know where cursor is now */

  if (starting != NO_SCREEN) {
    maketitle();
    changed_line_abv_curs();
    invalidate_botline();

    /*
     * We only redraw when it's needed:
     * - While at the more prompt or executing an external command, don't
     *   redraw, but position the cursor.
     * - While editing the command line, only redraw that.
     * - in Ex mode, don't redraw anything.
     * - Otherwise, redraw right now, and position the cursor.
     * Always need to call update_screen() or screenalloc(), to make
     * sure Rows/Columns and the size of ScreenLines[] is correct!
     */
    if (State == ASKMORE || State == EXTERNCMD || State == CONFIRM
        || exmode_active) {
      screenalloc(FALSE);
      repeat_message();
    } else   {
      if (curwin->w_p_scb)
        do_check_scrollbind(TRUE);
      if (State & CMDLINE) {
        update_screen(NOT_VALID);
        redrawcmdline();
      } else   {
        update_topline();
        if (pum_visible()) {
          redraw_later(NOT_VALID);
          ins_compl_show_pum();           /* This includes the redraw. */
        } else
          update_screen(NOT_VALID);
        if (redrawing())
          setcursor();
      }
    }
    cursor_on();            /* redrawing may have switched it off */
  }
  out_flush();
  --busy;
}

/*
 * Set the terminal to TMODE_RAW (for Normal mode) or TMODE_COOK (for external
 * commands and Ex mode).
 */
void settmode(int tmode)
{

  if (full_screen) {
    /*
     * When returning after calling a shell we want to really set the
     * terminal to raw mode, even though we think it already is, because
     * the shell program may have reset the terminal mode.
     * When we think the terminal is normal, don't try to set it to
     * normal again, because that causes problems (logout!) on some
     * machines.
     */
    if (tmode != TMODE_COOK || cur_tmode != TMODE_COOK) {
      {
        /* May need to check for T_CRV response and termcodes, it
         * doesn't work in Cooked mode, an external program may get
         * them. */
        if (tmode != TMODE_RAW && (crv_status == CRV_SENT
                                   || u7_status == U7_SENT))
          (void)vpeekc_nomap();
        check_for_codes_from_term();
      }
      if (tmode != TMODE_RAW)
        mch_setmouse(FALSE);                    /* switch mouse off */
      out_flush();
      mch_settmode(tmode);          /* machine specific function */
      cur_tmode = tmode;
      if (tmode == TMODE_RAW)
        setmouse();                             /* may switch mouse on */
      out_flush();
    }
    may_req_termresponse();
  }
}

void starttermcap(void)          {
  if (full_screen && !termcap_active) {
    out_str(T_TI);                      /* start termcap mode */
    out_str(T_KS);                      /* start "keypad transmit" mode */
    out_flush();
    termcap_active = TRUE;
    screen_start();                     /* don't know where cursor is now */
    {
      may_req_termresponse();
      /* Immediately check for a response.  If t_Co changes, we don't
       * want to redraw with wrong colors first. */
      if (crv_status != CRV_GET)
        check_for_codes_from_term();
    }
  }
}

void stoptermcap(void)          {
  screen_stop_highlight();
  reset_cterm_colors();
  if (termcap_active) {
    {
      /* May need to discard T_CRV or T_U7 response. */
      if (crv_status == CRV_SENT || u7_status == U7_SENT) {
# ifdef UNIX
        /* Give the terminal a chance to respond. */
        mch_delay(100L, FALSE);
# endif
# ifdef TCIFLUSH
        /* Discard data received but not read. */
        if (exiting)
          tcflush(fileno(stdin), TCIFLUSH);
# endif
      }
      /* Check for termcodes first, otherwise an external program may
       * get them. */
      check_for_codes_from_term();
    }
    out_str(T_KE);                      /* stop "keypad transmit" mode */
    out_flush();
    termcap_active = FALSE;
    cursor_on();                        /* just in case it is still off */
    out_str(T_TE);                      /* stop termcap mode */
    screen_start();                     /* don't know where cursor is now */
    out_flush();
  }
}

/*
 * Request version string (for xterm) when needed.
 * Only do this after switching to raw mode, otherwise the result will be
 * echoed.
 * Only do this after startup has finished, to avoid that the response comes
 * while executing "-c !cmd" or even after "-c quit".
 * Only do this after termcap mode has been started, otherwise the codes for
 * the cursor keys may be wrong.
 * Only do this when 'esckeys' is on, otherwise the response causes trouble in
 * Insert mode.
 * On Unix only do it when both output and input are a tty (avoid writing
 * request to terminal while reading from a file).
 * The result is caught in check_termcode().
 */
void may_req_termresponse(void)          {
  if (crv_status == CRV_GET
      && cur_tmode == TMODE_RAW
      && starting == 0
      && termcap_active
      && p_ek
# ifdef UNIX
      && isatty(1)
      && isatty(read_cmd_fd)
# endif
      && *T_CRV != NUL) {
    LOG_TR("Sending CRV");
    out_str(T_CRV);
    crv_status = CRV_SENT;
    /* check for the characters now, otherwise they might be eaten by
     * get_keystroke() */
    out_flush();
    (void)vpeekc_nomap();
  }
}

/*
 * Check how the terminal treats ambiguous character width (UAX #11).
 * First, we move the cursor to (1, 0) and print a test ambiguous character
 * \u25bd (WHITE DOWN-POINTING TRIANGLE) and query current cursor position.
 * If the terminal treats \u25bd as single width, the position is (1, 1),
 * or if it is treated as double width, that will be (1, 2).
 * This function has the side effect that changes cursor position, so
 * it must be called immediately after entering termcap mode.
 */
void may_req_ambiguous_char_width(void)          {
  if (u7_status == U7_GET
      && cur_tmode == TMODE_RAW
      && termcap_active
      && p_ek
#  ifdef UNIX
      && isatty(1)
      && isatty(read_cmd_fd)
#  endif
      && *T_U7 != NUL
      && !option_was_set((char_u *)"ambiwidth")) {
    char_u buf[16];

    LOG_TR("Sending U7 request");
    /* Do this in the second row.  In the first row the returned sequence
     * may be CSI 1;2R, which is the same as <S-F3>. */
    term_windgoto(1, 0);
    buf[mb_char2bytes(0x25bd, buf)] = 0;
    out_str(buf);
    out_str(T_U7);
    u7_status = U7_SENT;
    term_windgoto(0, 0);
    out_str((char_u *)"  ");
    term_windgoto(0, 0);
    /* check for the characters now, otherwise they might be eaten by
     * get_keystroke() */
    out_flush();
    (void)vpeekc_nomap();
  }
}

# ifdef DEBUG_TERMRESPONSE
static void log_tr(char *msg)                 {
  static FILE *fd_tr = NULL;
  static proftime_T start;
  proftime_T now;

  if (fd_tr == NULL) {
    fd_tr = fopen("termresponse.log", "w");
    profile_start(&start);
  }
  now = start;
  profile_end(&now);
  fprintf(fd_tr, "%s: %s %s\n",
      profile_msg(&now),
      must_redraw == NOT_VALID ? "NV"
      : must_redraw == CLEAR ? "CL" : "  ",
      msg);
}

# endif

/*
 * Return TRUE when saving and restoring the screen.
 */
int swapping_screen(void)         {
  return full_screen && *T_TI != NUL;
}

/*
 * setmouse() - switch mouse on/off depending on current mode and 'mouse'
 */
void setmouse(void)          {
  int checkfor;


  /* be quick when mouse is off */
  if (*p_mouse == NUL || has_mouse_termcode == 0)
    return;

  /* don't switch mouse on when not in raw mode (Ex mode) */
  if (cur_tmode != TMODE_RAW) {
    mch_setmouse(FALSE);
    return;
  }

  if (VIsual_active)
    checkfor = MOUSE_VISUAL;
  else if (State == HITRETURN || State == ASKMORE || State == SETWSIZE)
    checkfor = MOUSE_RETURN;
  else if (State & INSERT)
    checkfor = MOUSE_INSERT;
  else if (State & CMDLINE)
    checkfor = MOUSE_COMMAND;
  else if (State == CONFIRM || State == EXTERNCMD)
    checkfor = ' ';     /* don't use mouse for ":confirm" or ":!cmd" */
  else
    checkfor = MOUSE_NORMAL;        /* assume normal mode */

  if (mouse_has(checkfor))
    mch_setmouse(TRUE);
  else
    mch_setmouse(FALSE);
}

/*
 * Return TRUE if
 * - "c" is in 'mouse', or
 * - 'a' is in 'mouse' and "c" is in MOUSE_A, or
 * - the current buffer is a help file and 'h' is in 'mouse' and we are in a
 *   normal editing mode (not at hit-return message).
 */
int mouse_has(int c)
{
  char_u      *p;

  for (p = p_mouse; *p; ++p)
    switch (*p) {
    case 'a': if (vim_strchr((char_u *)MOUSE_A, c) != NULL)
        return TRUE;
      break;
    case MOUSE_HELP: if (c != MOUSE_RETURN && curbuf->b_help)
        return TRUE;
      break;
    default: if (c == *p) return TRUE; break;
    }
  return FALSE;
}

/*
 * Return TRUE when 'mousemodel' is set to "popup" or "popup_setpos".
 */
int mouse_model_popup(void)         {
  return p_mousem[0] == 'p';
}

/*
 * By outputting the 'cursor very visible' termcap code, for some windowed
 * terminals this makes the screen scrolled to the correct position.
 * Used when starting Vim or returning from a shell.
 */
void scroll_start(void)          {
  if (*T_VS != NUL) {
    out_str(T_VS);
    out_str(T_VE);
    screen_start();                     /* don't know where cursor is now */
  }
}

static int cursor_is_off = FALSE;

/*
 * Enable the cursor.
 */
void cursor_on(void)          {
  if (cursor_is_off) {
    out_str(T_VE);
    cursor_is_off = FALSE;
  }
}

/*
 * Disable the cursor.
 */
void cursor_off(void)          {
  if (full_screen) {
    if (!cursor_is_off)
      out_str(T_VI);                /* disable cursor */
    cursor_is_off = TRUE;
  }
}

#if defined(CURSOR_SHAPE) || defined(PROTO)
/*
 * Set cursor shape to match Insert mode.
 */
void term_cursor_shape(void)          {
  static int showing_insert_mode = MAYBE;

  if (!full_screen || *T_CSI == NUL || *T_CEI == NUL)
    return;

  if (State & INSERT) {
    if (showing_insert_mode != TRUE)
      out_str(T_CSI);               /* Insert mode cursor */
    showing_insert_mode = TRUE;
  } else   {
    if (showing_insert_mode != FALSE)
      out_str(T_CEI);               /* non-Insert mode cursor */
    showing_insert_mode = FALSE;
  }
}

#endif

/*
 * Set scrolling region for window 'wp'.
 * The region starts 'off' lines from the start of the window.
 * Also set the vertical scroll region for a vertically split window.  Always
 * the full width of the window, excluding the vertical separator.
 */
void scroll_region_set(win_T *wp, int off)
{
  OUT_STR(tgoto((char *)T_CS, W_WINROW(wp) + wp->w_height - 1,
          W_WINROW(wp) + off));
  if (*T_CSV != NUL && wp->w_width != Columns)
    OUT_STR(tgoto((char *)T_CSV, W_WINCOL(wp) + wp->w_width - 1,
            W_WINCOL(wp)));
  screen_start();                   /* don't know where cursor is now */
}

/*
 * Reset scrolling region to the whole screen.
 */
void scroll_region_reset(void)          {
  OUT_STR(tgoto((char *)T_CS, (int)Rows - 1, 0));
  if (*T_CSV != NUL)
    OUT_STR(tgoto((char *)T_CSV, (int)Columns - 1, 0));
  screen_start();                   /* don't know where cursor is now */
}

/*
 * List of terminal codes that are currently recognized.
 */

static struct termcode {
  char_u name[2];           /* termcap name of entry */
  char_u  *code;            /* terminal code (in allocated memory) */
  int len;                  /* STRLEN(code) */
  int modlen;               /* length of part before ";*~". */
} *termcodes = NULL;

static int tc_max_len = 0;  /* number of entries that termcodes[] can hold */
static int tc_len = 0;      /* current number of entries in termcodes[] */

static int termcode_star(char_u *code, int len);

void clear_termcodes(void)          {
  while (tc_len > 0)
    vim_free(termcodes[--tc_len].code);
  vim_free(termcodes);
  termcodes = NULL;
  tc_max_len = 0;

#ifdef HAVE_TGETENT
  BC = (char *)empty_option;
  UP = (char *)empty_option;
  PC = NUL;                     /* set pad character to NUL */
  ospeed = 0;
#endif

  need_gather = TRUE;           /* need to fill termleader[] */
}

#define ATC_FROM_TERM 55

/*
 * Add a new entry to the list of terminal codes.
 * The list is kept alphabetical for ":set termcap"
 * "flags" is TRUE when replacing 7-bit by 8-bit controls is desired.
 * "flags" can also be ATC_FROM_TERM for got_code_from_term().
 */
void add_termcode(char_u *name, char_u *string, int flags)
{
  struct termcode *new_tc;
  int i, j;
  char_u          *s;
  int len;

  if (string == NULL || *string == NUL) {
    del_termcode(name);
    return;
  }

  s = vim_strsave(string);
  if (s == NULL)
    return;

  /* Change leading <Esc>[ to CSI, change <Esc>O to <M-O>. */
  if (flags != 0 && flags != ATC_FROM_TERM && term_7to8bit(string) != 0) {
    STRMOVE(s, s + 1);
    s[0] = term_7to8bit(string);
  }
  len = (int)STRLEN(s);

  need_gather = TRUE;           /* need to fill termleader[] */

  /*
   * need to make space for more entries
   */
  if (tc_len == tc_max_len) {
    tc_max_len += 20;
    new_tc = (struct termcode *)alloc(
        (unsigned)(tc_max_len * sizeof(struct termcode)));
    if (new_tc == NULL) {
      tc_max_len -= 20;
      return;
    }
    for (i = 0; i < tc_len; ++i)
      new_tc[i] = termcodes[i];
    vim_free(termcodes);
    termcodes = new_tc;
  }

  /*
   * Look for existing entry with the same name, it is replaced.
   * Look for an existing entry that is alphabetical higher, the new entry
   * is inserted in front of it.
   */
  for (i = 0; i < tc_len; ++i) {
    if (termcodes[i].name[0] < name[0])
      continue;
    if (termcodes[i].name[0] == name[0]) {
      if (termcodes[i].name[1] < name[1])
        continue;
      /*
       * Exact match: May replace old code.
       */
      if (termcodes[i].name[1] == name[1]) {
        if (flags == ATC_FROM_TERM && (j = termcode_star(
                                           termcodes[i].code,
                                           termcodes[i].len)) > 0) {
          /* Don't replace ESC[123;*X or ESC O*X with another when
           * invoked from got_code_from_term(). */
          if (len == termcodes[i].len - j
              && STRNCMP(s, termcodes[i].code, len - 1) == 0
              && s[len - 1]
              == termcodes[i].code[termcodes[i].len - 1]) {
            /* They are equal but for the ";*": don't add it. */
            vim_free(s);
            return;
          }
        } else   {
          /* Replace old code. */
          vim_free(termcodes[i].code);
          --tc_len;
          break;
        }
      }
    }
    /*
     * Found alphabetical larger entry, move rest to insert new entry
     */
    for (j = tc_len; j > i; --j)
      termcodes[j] = termcodes[j - 1];
    break;
  }

  termcodes[i].name[0] = name[0];
  termcodes[i].name[1] = name[1];
  termcodes[i].code = s;
  termcodes[i].len = len;

  /* For xterm we recognize special codes like "ESC[42;*X" and "ESC O*X" that
   * accept modifiers. */
  termcodes[i].modlen = 0;
  j = termcode_star(s, len);
  if (j > 0)
    termcodes[i].modlen = len - 1 - j;
  ++tc_len;
}

/*
 * Check termcode "code[len]" for ending in ;*X, <Esc>O*X or <M-O>*X.
 * The "X" can be any character.
 * Return 0 if not found, 2 for ;*X and 1 for O*X and <M-O>*X.
 */
static int termcode_star(char_u *code, int len)
{
  /* Shortest is <M-O>*X.  With ; shortest is <CSI>1;*X */
  if (len >= 3 && code[len - 2] == '*') {
    if (len >= 5 && code[len - 3] == ';')
      return 2;
    if ((len >= 4 && code[len - 3] == 'O') || code[len - 3] == 'O' + 128)
      return 1;
  }
  return 0;
}

char_u *find_termcode(char_u *name)
{
  int i;

  for (i = 0; i < tc_len; ++i)
    if (termcodes[i].name[0] == name[0] && termcodes[i].name[1] == name[1])
      return termcodes[i].code;
  return NULL;
}

char_u *get_termcode(int i)
{
  if (i >= tc_len)
    return NULL;
  return &termcodes[i].name[0];
}

void del_termcode(char_u *name)
{
  int i;

  if (termcodes == NULL)        /* nothing there yet */
    return;

  need_gather = TRUE;           /* need to fill termleader[] */

  for (i = 0; i < tc_len; ++i)
    if (termcodes[i].name[0] == name[0] && termcodes[i].name[1] == name[1]) {
      del_termcode_idx(i);
      return;
    }
  /* not found. Give error message? */
}

static void del_termcode_idx(int idx)
{
  int i;

  vim_free(termcodes[idx].code);
  --tc_len;
  for (i = idx; i < tc_len; ++i)
    termcodes[i] = termcodes[i + 1];
}

/*
 * Called when detected that the terminal sends 8-bit codes.
 * Convert all 7-bit codes to their 8-bit equivalent.
 */
static void switch_to_8bit(void)                 {
  int i;
  int c;

  /* Only need to do something when not already using 8-bit codes. */
  if (!term_is_8bit(T_NAME)) {
    for (i = 0; i < tc_len; ++i) {
      c = term_7to8bit(termcodes[i].code);
      if (c != 0) {
        STRMOVE(termcodes[i].code + 1, termcodes[i].code + 2);
        termcodes[i].code[0] = c;
      }
    }
    need_gather = TRUE;                 /* need to fill termleader[] */
  }
  detected_8bit = TRUE;
  LOG_TR("Switching to 8 bit");
}

#ifdef CHECK_DOUBLE_CLICK
static linenr_T orig_topline = 0;
static int orig_topfill = 0;
#endif
#if (defined(FEAT_WINDOWS) && defined(CHECK_DOUBLE_CLICK)) || defined(PROTO)
/*
 * Checking for double clicks ourselves.
 * "orig_topline" is used to avoid detecting a double-click when the window
 * contents scrolled (e.g., when 'scrolloff' is non-zero).
 */
/*
 * Set orig_topline.  Used when jumping to another window, so that a double
 * click still works.
 */
void set_mouse_topline(win_T *wp)
{
  orig_topline = wp->w_topline;
  orig_topfill = wp->w_topfill;
}
#endif

/*
 * Check if typebuf.tb_buf[] contains a terminal key code.
 * Check from typebuf.tb_buf[typebuf.tb_off] to typebuf.tb_buf[typebuf.tb_off
 * + max_offset].
 * Return 0 for no match, -1 for partial match, > 0 for full match.
 * Return KEYLEN_REMOVED when a key code was deleted.
 * With a match, the match is removed, the replacement code is inserted in
 * typebuf.tb_buf[] and the number of characters in typebuf.tb_buf[] is
 * returned.
 * When "buf" is not NULL, buf[bufsize] is used instead of typebuf.tb_buf[].
 * "buflen" is then the length of the string in buf[] and is updated for
 * inserts and deletes.
 */
int check_termcode(int max_offset, char_u *buf, int bufsize, int *buflen)
{
  char_u      *tp;
  char_u      *p;
  int slen = 0;                 /* init for GCC */
  int modslen;
  int len;
  int retval = 0;
  int offset;
  char_u key_name[2];
  int modifiers;
  int key;
  int new_slen;
  int extra;
  char_u string[MAX_KEY_CODE_LEN + 1];
  int i, j;
  int idx = 0;
# if !defined(UNIX) || defined(FEAT_MOUSE_XTERM) || defined(FEAT_GUI) \
  || defined(FEAT_MOUSE_GPM) || defined(FEAT_SYSMOUSE)
  char_u bytes[6];
  int num_bytes;
# endif
  int mouse_code = 0;               /* init for GCC */
  int is_click, is_drag;
  int wheel_code = 0;
  int current_button;
  static int held_button = MOUSE_RELEASE;
  static int orig_num_clicks = 1;
  static int orig_mouse_code = 0x0;
# ifdef CHECK_DOUBLE_CLICK
  static int orig_mouse_col = 0;
  static int orig_mouse_row = 0;
  static struct timeval orig_mouse_time = {0, 0};
  /* time of previous mouse click */
  struct timeval mouse_time;            /* time of current mouse click */
  long timediff;                        /* elapsed time in msec */
# endif
  int cpo_koffset;

  cpo_koffset = (vim_strchr(p_cpo, CPO_KOFFSET) != NULL);

  /*
   * Speed up the checks for terminal codes by gathering all first bytes
   * used in termleader[].  Often this is just a single <Esc>.
   */
  if (need_gather)
    gather_termleader();

  /*
   * Check at several positions in typebuf.tb_buf[], to catch something like
   * "x<Up>" that can be mapped. Stop at max_offset, because characters
   * after that cannot be used for mapping, and with @r commands
   * typebuf.tb_buf[] can become very long.
   * This is used often, KEEP IT FAST!
   */
  for (offset = 0; offset < max_offset; ++offset) {
    if (buf == NULL) {
      if (offset >= typebuf.tb_len)
        break;
      tp = typebuf.tb_buf + typebuf.tb_off + offset;
      len = typebuf.tb_len - offset;            /* length of the input */
    } else   {
      if (offset >= *buflen)
        break;
      tp = buf + offset;
      len = *buflen - offset;
    }

    /*
     * Don't check characters after K_SPECIAL, those are already
     * translated terminal chars (avoid translating ~@^Hx).
     */
    if (*tp == K_SPECIAL) {
      offset += 2;              /* there are always 2 extra characters */
      continue;
    }

    /*
     * Skip this position if the character does not appear as the first
     * character in term_strings. This speeds up a lot, since most
     * termcodes start with the same character (ESC or CSI).
     */
    i = *tp;
    for (p = termleader; *p && *p != i; ++p)
      ;
    if (*p == NUL)
      continue;

    /*
     * Skip this position if p_ek is not set and tp[0] is an ESC and we
     * are in Insert mode.
     */
    if (*tp == ESC && !p_ek && (State & INSERT))
      continue;

    key_name[0] = NUL;          /* no key name found yet */
    key_name[1] = NUL;          /* no key name found yet */
    modifiers = 0;              /* no modifiers yet */

    {
      for (idx = 0; idx < tc_len; ++idx) {
        /*
         * Ignore the entry if we are not at the start of
         * typebuf.tb_buf[]
         * and there are not enough characters to make a match.
         * But only when the 'K' flag is in 'cpoptions'.
         */
        slen = termcodes[idx].len;
        if (cpo_koffset && offset && len < slen)
          continue;
        if (STRNCMP(termcodes[idx].code, tp,
                (size_t)(slen > len ? len : slen)) == 0) {
          if (len < slen)                       /* got a partial sequence */
            return -1;                          /* need to get more chars */

          /*
           * When found a keypad key, check if there is another key
           * that matches and use that one.  This makes <Home> to be
           * found instead of <kHome> when they produce the same
           * key code.
           */
          if (termcodes[idx].name[0] == 'K'
              && VIM_ISDIGIT(termcodes[idx].name[1])) {
            for (j = idx + 1; j < tc_len; ++j)
              if (termcodes[j].len == slen &&
                  STRNCMP(termcodes[idx].code,
                      termcodes[j].code, slen) == 0) {
                idx = j;
                break;
              }
          }

          key_name[0] = termcodes[idx].name[0];
          key_name[1] = termcodes[idx].name[1];
          break;
        }

        /*
         * Check for code with modifier, like xterm uses:
         * <Esc>[123;*X  (modslen == slen - 3)
         * Also <Esc>O*X and <M-O>*X (modslen == slen - 2).
         * When there is a modifier the * matches a number.
         * When there is no modifier the ;* or * is omitted.
         */
        if (termcodes[idx].modlen > 0) {
          modslen = termcodes[idx].modlen;
          if (cpo_koffset && offset && len < modslen)
            continue;
          if (STRNCMP(termcodes[idx].code, tp,
                  (size_t)(modslen > len ? len : modslen)) == 0) {
            int n;

            if (len <= modslen)                 /* got a partial sequence */
              return -1;                        /* need to get more chars */

            if (tp[modslen] == termcodes[idx].code[slen - 1])
              slen = modslen + 1;               /* no modifiers */
            else if (tp[modslen] != ';' && modslen == slen - 3)
              continue;                 /* no match */
            else {
              /* Skip over the digits, the final char must
               * follow. */
              for (j = slen - 2; j < len && isdigit(tp[j]); ++j)
                ;
              ++j;
              if (len < j)                      /* got a partial sequence */
                return -1;                      /* need to get more chars */
              if (tp[j - 1] != termcodes[idx].code[slen - 1])
                continue;                       /* no match */

              /* Match!  Convert modifier bits. */
              n = atoi((char *)tp + slen - 2) - 1;
              if (n & 1)
                modifiers |= MOD_MASK_SHIFT;
              if (n & 2)
                modifiers |= MOD_MASK_ALT;
              if (n & 4)
                modifiers |= MOD_MASK_CTRL;
              if (n & 8)
                modifiers |= MOD_MASK_META;

              slen = j;
            }
            key_name[0] = termcodes[idx].name[0];
            key_name[1] = termcodes[idx].name[1];
            break;
          }
        }
      }
    }

    if (key_name[0] == NUL
        /* URXVT mouse uses <ESC>[#;#;#M, but we are matching <ESC>[ */
        || key_name[0] == KS_URXVT_MOUSE
        || u7_status == U7_SENT
        ) {
      /* Check for some responses from terminal start with "<Esc>[" or
       * CSI.
       *
       * - xterm version string: <Esc>[>{x};{vers};{y}c
       *   Also eat other possible responses to t_RV, rxvt returns
       *   "<Esc>[?1;2c". Also accept CSI instead of <Esc>[.
       *   mrxvt has been reported to have "+" in the version. Assume
       *   the escape sequence ends with a letter or one of "{|}~".
       *
       * - cursor position report: <Esc>[{row};{col}R
       *   The final byte is 'R'. now it is only used for checking for
       *   ambiguous-width character state.
       */
      p = tp[0] == CSI ? tp + 1 : tp + 2;
      if ((*T_CRV != NUL || *T_U7 != NUL)
          && ((tp[0] == ESC && tp[1] == '[' && len >= 3)
              || (tp[0] == CSI && len >= 2))
          && (VIM_ISDIGIT(*p) || *p == '>' || *p == '?')) {
        j = 0;
        extra = 0;
        for (i = 2 + (tp[0] != CSI); i < len
             && !(tp[i] >= '{' && tp[i] <= '~')
             && !ASCII_ISALPHA(tp[i]); ++i)
          if (tp[i] == ';' && ++j == 1)
            extra = i + 1;
        if (i == len) {
          LOG_TR("Not enough characters for CRV");
          return -1;
        }

        /* Eat it when it has 2 arguments and ends in 'R'. Ignore it
         * when u7_status is not "sent", <S-F3> sends something
         * similar. */
        if (j == 1 && tp[i] == 'R' && u7_status == U7_SENT) {
          char *aw = NULL;

          LOG_TR("Received U7 status");
          u7_status = U7_GOT;
          did_cursorhold = TRUE;
          if (extra > 0)
            extra = atoi((char *)tp + extra);
          if (extra == 2)
            aw = "single";
          else if (extra == 3)
            aw = "double";
          if (aw != NULL && STRCMP(aw, p_ambw) != 0) {
            /* Setting the option causes a screen redraw. Do that
             * right away if possible, keeping any messages. */
            set_option_value((char_u *)"ambw", 0L, (char_u *)aw, 0);
#ifdef DEBUG_TERMRESPONSE
            {
              char buf[100];
              int r = redraw_asap(CLEAR);

              sprintf(buf, "set 'ambiwidth', redraw_asap(): %d",
                  r);
              log_tr(buf);
            }
#else
            redraw_asap(CLEAR);
#endif
          }
          key_name[0] = (int)KS_EXTRA;
          key_name[1] = (int)KE_IGNORE;
          slen = i + 1;
        } else
        /* eat it when at least one digit and ending in 'c' */
        if (*T_CRV != NUL && i > 2 + (tp[0] != CSI) && tp[i] == 'c') {
          LOG_TR("Received CRV");
          crv_status = CRV_GOT;
          did_cursorhold = TRUE;

          /* If this code starts with CSI, you can bet that the
           * terminal uses 8-bit codes. */
          if (tp[0] == CSI)
            switch_to_8bit();

          /* rxvt sends its version number: "20703" is 2.7.3.
           * Ignore it for when the user has set 'term' to xterm,
           * even though it's an rxvt. */
          if (extra > 0)
            extra = atoi((char *)tp + extra);
          if (extra > 20000)
            extra = 0;

          if (tp[1 + (tp[0] != CSI)] == '>' && j == 2) {
            /* Only set 'ttymouse' automatically if it was not set
             * by the user already. */
            if (!option_was_set((char_u *)"ttym")) {
# ifdef TTYM_SGR
              if (extra >= 277)
                set_option_value((char_u *)"ttym", 0L,
                    (char_u *)"sgr", 0);
              else
# endif
              /* if xterm version >= 95 use mouse dragging */
              if (extra >= 95)
                set_option_value((char_u *)"ttym", 0L,
                    (char_u *)"xterm2", 0);
            }

            /* if xterm version >= 141 try to get termcap codes */
            if (extra >= 141) {
              LOG_TR("Enable checking for XT codes");
              check_for_codes = TRUE;
              need_gather = TRUE;
              req_codes_from_term();
            }
          }
          set_vim_var_string(VV_TERMRESPONSE, tp, i + 1);
          apply_autocmds(EVENT_TERMRESPONSE,
              NULL, NULL, FALSE, curbuf);
          key_name[0] = (int)KS_EXTRA;
          key_name[1] = (int)KE_IGNORE;
          slen = i + 1;
        }
      }
      /* Check for '<Esc>P1+r<hex bytes><Esc>\'.  A "0" instead of the
       * "1" means an invalid request. */
      else if (check_for_codes
               && ((tp[0] == ESC && tp[1] == 'P' && len >= 2)
                   || tp[0] == DCS)) {
        j = 1 + (tp[0] != DCS);
        for (i = j; i < len; ++i)
          if ((tp[i] == ESC && tp[i + 1] == '\\' && i + 1 < len)
              || tp[i] == STERM) {
            if (i - j >= 3 && tp[j + 1] == '+' && tp[j + 2] == 'r')
              got_code_from_term(tp + j, i);
            key_name[0] = (int)KS_EXTRA;
            key_name[1] = (int)KE_IGNORE;
            slen = i + 1 + (tp[i] == ESC);
            break;
          }

        if (i == len) {
          LOG_TR("not enough characters for XT");
          return -1;                    /* not enough characters */
        }
      }
    }

    if (key_name[0] == NUL)
      continue;             /* No match at this position, try next one */

    /* We only get here when we have a complete termcode match */

    /*
     * If it is a mouse click, get the coordinates.
     */
    if (key_name[0] == KS_MOUSE
# ifdef FEAT_MOUSE_JSB
        || key_name[0] == KS_JSBTERM_MOUSE
# endif
        || key_name[0] == KS_NETTERM_MOUSE
        || key_name[0] == KS_DEC_MOUSE
        || key_name[0] == KS_URXVT_MOUSE
        || key_name[0] == KS_SGR_MOUSE
        ) {
      is_click = is_drag = FALSE;

# if !defined(UNIX) || defined(FEAT_MOUSE_XTERM) || defined(FEAT_GUI) \
      || defined(FEAT_MOUSE_GPM) || defined(FEAT_SYSMOUSE)
      if (key_name[0] == (int)KS_MOUSE) {
        /*
         * For xterm and MSDOS we get "<t_mouse>scr", where
         *  s == encoded button state:
         *	   0x20 = left button down
         *	   0x21 = middle button down
         *	   0x22 = right button down
         *	   0x23 = any button release
         *	   0x60 = button 4 down (scroll wheel down)
         *	   0x61 = button 5 down (scroll wheel up)
         *	add 0x04 for SHIFT
         *	add 0x08 for ALT
         *	add 0x10 for CTRL
         *	add 0x20 for mouse drag (0x40 is drag with left button)
         *  c == column + ' ' + 1 == column + 33
         *  r == row + ' ' + 1 == row + 33
         *
         * The coordinates are passed on through global variables.
         * Ugly, but this avoids trouble with mouse clicks at an
         * unexpected moment and allows for mapping them.
         */
        for (;; ) {
          {
            num_bytes = get_bytes_from_buf(tp + slen, bytes, 3);
            if (num_bytes == -1)                /* not enough coordinates */
              return -1;
            mouse_code = bytes[0];
            mouse_col = bytes[1] - ' ' - 1;
            mouse_row = bytes[2] - ' ' - 1;
          }
          slen += num_bytes;

          /* If the following bytes is also a mouse code and it has
           * the same code, dump this one and get the next.  This
           * makes dragging a whole lot faster. */
          j = termcodes[idx].len;
          if (STRNCMP(tp, tp + slen, (size_t)j) == 0
              && tp[slen + j] == mouse_code
              && tp[slen + j + 1] != NUL
              && tp[slen + j + 2] != NUL
              )
            slen += j;
          else
            break;
        }
      }

      if (key_name[0] == KS_URXVT_MOUSE
          || key_name[0] == KS_SGR_MOUSE) {
        for (;; ) {
          /* URXVT 1015 mouse reporting mode:
           * Almost identical to xterm mouse mode, except the values
           * are decimal instead of bytes.
           *
           * \033[%d;%d;%dM
           *		  ^-- row
           *	       ^----- column
           *	    ^-------- code
           *
           * SGR 1006 mouse reporting mode:
           * Almost identical to xterm mouse mode, except the values
           * are decimal instead of bytes.
           *
           * \033[<%d;%d;%dM
           *		   ^-- row
           *	        ^----- column
           *	     ^-------- code
           *
           * \033[<%d;%d;%dm        : mouse release event
           *		   ^-- row
           *	        ^----- column
           *	     ^-------- code
           */
          p = tp + slen;

          mouse_code = getdigits(&p);
          if (*p++ != ';')
            return -1;

          /* when mouse reporting is SGR, add 32 to mouse code */
          if (key_name[0] == KS_SGR_MOUSE)
            mouse_code += 32;

          mouse_col = getdigits(&p) - 1;
          if (*p++ != ';')
            return -1;

          mouse_row = getdigits(&p) - 1;
          if (key_name[0] == KS_SGR_MOUSE && *p == 'm')
            mouse_code |= MOUSE_RELEASE;
          else if (*p != 'M')
            return -1;
          p++;

          slen += (int)(p - (tp + slen));

          /* skip this one if next one has same code (like xterm
           * case) */
          j = termcodes[idx].len;
          if (STRNCMP(tp, tp + slen, (size_t)j) == 0) {
            int slen2;
            int cmd_complete = 0;

            /* check if the command is complete by looking for the
             * 'M' */
            for (slen2 = slen; slen2 < len; slen2++) {
              if (tp[slen2] == 'M'
                  || (key_name[0] == KS_SGR_MOUSE
                      && tp[slen2] == 'm')) {
                cmd_complete = 1;
                break;
              }
            }
            p += j;
            if (cmd_complete && getdigits(&p) == mouse_code) {
              slen += j;               /* skip the \033[ */
              continue;
            }
          }
          break;
        }
      }

      if (key_name[0] == (int)KS_MOUSE
          || key_name[0] == (int)KS_URXVT_MOUSE
          || key_name[0] == KS_SGR_MOUSE
          ) {
        /*
         * Handle mouse events.
         * Recognize the xterm mouse wheel, but not in the GUI, the
         * Linux console with GPM and the MS-DOS or Win32 console
         * (multi-clicks use >= 0x60).
         */
        if (mouse_code >= MOUSEWHEEL_LOW
            ) {
          /* Keep the mouse_code before it's changed, so that we
           * remember that it was a mouse wheel click. */
          wheel_code = mouse_code;
        } else if (held_button == MOUSE_RELEASE
                   && (mouse_code == 0x23 || mouse_code == 0x24)) {
          /* Apparently used by rxvt scroll wheel. */
          wheel_code = mouse_code - 0x23 + MOUSEWHEEL_LOW;
        }

#   if defined(UNIX) && defined(FEAT_MOUSE_TTY)
        else if (use_xterm_mouse() > 1) {
          if (mouse_code & MOUSE_DRAG_XTERM)
            mouse_code |= MOUSE_DRAG;
        }
#   endif
      }
# endif /* !UNIX || FEAT_MOUSE_XTERM */
      if (key_name[0] == (int)KS_NETTERM_MOUSE) {
        int mc, mr;

        /* expect a rather limited sequence like: balancing {
         * \033}6,45\r
         * '6' is the row, 45 is the column
         */
        p = tp + slen;
        mr = getdigits(&p);
        if (*p++ != ',')
          return -1;
        mc = getdigits(&p);
        if (*p++ != '\r')
          return -1;

        mouse_col = mc - 1;
        mouse_row = mr - 1;
        mouse_code = MOUSE_LEFT;
        slen += (int)(p - (tp + slen));
      }
# ifdef FEAT_MOUSE_JSB
      if (key_name[0] == (int)KS_JSBTERM_MOUSE) {
        int mult, val, iter, button, status;

        /* JSBTERM Input Model
         * \033[0~zw uniq escape sequence
         * (L-x)  Left button pressed - not pressed x not reporting
         * (M-x)  Middle button pressed - not pressed x not reporting
         * (R-x)  Right button pressed - not pressed x not reporting
         * (SDmdu)  Single , Double click, m mouse move d button down
         *						   u button up
         *  ###   X cursor position padded to 3 digits
         *  ###   Y cursor position padded to 3 digits
         * (s-x)  SHIFT key pressed - not pressed x not reporting
         * (c-x)  CTRL key pressed - not pressed x not reporting
         * \033\\ terminating sequence
         */

        p = tp + slen;
        button = mouse_code = 0;
        switch (*p++) {
        case 'L': button = 1; break;
        case '-': break;
        case 'x': break;             /* ignore sequence */
        default:  return -1;             /* Unknown Result */
        }
        switch (*p++) {
        case 'M': button |= 2; break;
        case '-': break;
        case 'x': break;             /* ignore sequence */
        default:  return -1;             /* Unknown Result */
        }
        switch (*p++) {
        case 'R': button |= 4; break;
        case '-': break;
        case 'x': break;             /* ignore sequence */
        default:  return -1;             /* Unknown Result */
        }
        status = *p++;
        for (val = 0, mult = 100, iter = 0; iter < 3; iter++,
             mult /= 10, p++)
          if (*p >= '0' && *p <= '9')
            val += (*p - '0') * mult;
          else
            return -1;
        mouse_col = val;
        for (val = 0, mult = 100, iter = 0; iter < 3; iter++,
             mult /= 10, p++)
          if (*p >= '0' && *p <= '9')
            val += (*p - '0') * mult;
          else
            return -1;
        mouse_row = val;
        switch (*p++) {
        case 's': button |= 8; break;              /* SHIFT key Pressed */
        case '-': break;              /* Not Pressed */
        case 'x': break;              /* Not Reporting */
        default:  return -1;             /* Unknown Result */
        }
        switch (*p++) {
        case 'c': button |= 16; break;              /* CTRL key Pressed */
        case '-': break;              /* Not Pressed */
        case 'x': break;              /* Not Reporting */
        default:  return -1;             /* Unknown Result */
        }
        if (*p++ != '\033')
          return -1;
        if (*p++ != '\\')
          return -1;
        switch (status) {
        case 'D':             /* Double Click */
        case 'S':             /* Single Click */
          if (button & 1) mouse_code |= MOUSE_LEFT;
          if (button & 2) mouse_code |= MOUSE_MIDDLE;
          if (button & 4) mouse_code |= MOUSE_RIGHT;
          if (button & 8) mouse_code |= MOUSE_SHIFT;
          if (button & 16) mouse_code |= MOUSE_CTRL;
          break;
        case 'm':             /* Mouse move */
          if (button & 1) mouse_code |= MOUSE_LEFT;
          if (button & 2) mouse_code |= MOUSE_MIDDLE;
          if (button & 4) mouse_code |= MOUSE_RIGHT;
          if (button & 8) mouse_code |= MOUSE_SHIFT;
          if (button & 16) mouse_code |= MOUSE_CTRL;
          if ((button & 7) != 0) {
            held_button = mouse_code;
            mouse_code |= MOUSE_DRAG;
          }
          is_drag = TRUE;
          showmode();
          break;
        case 'd':             /* Button Down */
          if (button & 1) mouse_code |= MOUSE_LEFT;
          if (button & 2) mouse_code |= MOUSE_MIDDLE;
          if (button & 4) mouse_code |= MOUSE_RIGHT;
          if (button & 8) mouse_code |= MOUSE_SHIFT;
          if (button & 16) mouse_code |= MOUSE_CTRL;
          break;
        case 'u':             /* Button Up */
          if (button & 1)
            mouse_code |= MOUSE_LEFT | MOUSE_RELEASE;
          if (button & 2)
            mouse_code |= MOUSE_MIDDLE | MOUSE_RELEASE;
          if (button & 4)
            mouse_code |= MOUSE_RIGHT | MOUSE_RELEASE;
          if (button & 8)
            mouse_code |= MOUSE_SHIFT;
          if (button & 16)
            mouse_code |= MOUSE_CTRL;
          break;
        default: return -1;             /* Unknown Result */
        }

        slen += (p - (tp + slen));
      }
# endif /* FEAT_MOUSE_JSB */
      if (key_name[0] == (int)KS_DEC_MOUSE) {
        /* The DEC Locator Input Model
         * Netterm delivers the code sequence:
         *  \033[2;4;24;80&w  (left button down)
         *  \033[3;0;24;80&w  (left button up)
         *  \033[6;1;24;80&w  (right button down)
         *  \033[7;0;24;80&w  (right button up)
         * CSI Pe ; Pb ; Pr ; Pc ; Pp & w
         * Pe is the event code
         * Pb is the button code
         * Pr is the row coordinate
         * Pc is the column coordinate
         * Pp is the third coordinate (page number)
         * Pe, the event code indicates what event caused this report
         *    The following event codes are defined:
         *    0 - request, the terminal received an explicit request
         *	 for a locator report, but the locator is unavailable
         *    1 - request, the terminal received an explicit request
         *	 for a locator report
         *    2 - left button down
         *    3 - left button up
         *    4 - middle button down
         *    5 - middle button up
         *    6 - right button down
         *    7 - right button up
         *    8 - fourth button down
         *    9 - fourth button up
         *    10 - locator outside filter rectangle
         * Pb, the button code, ASCII decimal 0-15 indicating which
         *   buttons are down if any. The state of the four buttons
         *   on the locator correspond to the low four bits of the
         *   decimal value,
         *   "1" means button depressed
         *   0 - no buttons down,
         *   1 - right,
         *   2 - middle,
         *   4 - left,
         *   8 - fourth
         * Pr is the row coordinate of the locator position in the page,
         *   encoded as an ASCII decimal value.
         *   If Pr is omitted, the locator position is undefined
         *   (outside the terminal window for example).
         * Pc is the column coordinate of the locator position in the
         *   page, encoded as an ASCII decimal value.
         *   If Pc is omitted, the locator position is undefined
         *   (outside the terminal window for example).
         * Pp is the page coordinate of the locator position
         *   encoded as an ASCII decimal value.
         *   The page coordinate may be omitted if the locator is on
         *   page one (the default).  We ignore it anyway.
         */
        int Pe, Pb, Pr, Pc;

        p = tp + slen;

        /* get event status */
        Pe = getdigits(&p);
        if (*p++ != ';')
          return -1;

        /* get button status */
        Pb = getdigits(&p);
        if (*p++ != ';')
          return -1;

        /* get row status */
        Pr = getdigits(&p);
        if (*p++ != ';')
          return -1;

        /* get column status */
        Pc = getdigits(&p);

        /* the page parameter is optional */
        if (*p == ';') {
          p++;
          (void)getdigits(&p);
        }
        if (*p++ != '&')
          return -1;
        if (*p++ != 'w')
          return -1;

        mouse_code = 0;
        switch (Pe) {
        case  0: return -1;         /* position request while unavailable */
        case  1:         /* a response to a locator position request includes
                            the status of all buttons */
          Pb &= 7;                  /* mask off and ignore fourth button */
          if (Pb & 4)
            mouse_code  = MOUSE_LEFT;
          if (Pb & 2)
            mouse_code  = MOUSE_MIDDLE;
          if (Pb & 1)
            mouse_code  = MOUSE_RIGHT;
          if (Pb) {
            held_button = mouse_code;
            mouse_code |= MOUSE_DRAG;
            WantQueryMouse = TRUE;
          }
          is_drag = TRUE;
          showmode();
          break;
        case  2: mouse_code = MOUSE_LEFT;
          WantQueryMouse = TRUE;
          break;
        case  3: mouse_code = MOUSE_RELEASE | MOUSE_LEFT;
          break;
        case  4: mouse_code = MOUSE_MIDDLE;
          WantQueryMouse = TRUE;
          break;
        case  5: mouse_code = MOUSE_RELEASE | MOUSE_MIDDLE;
          break;
        case  6: mouse_code = MOUSE_RIGHT;
          WantQueryMouse = TRUE;
          break;
        case  7: mouse_code = MOUSE_RELEASE | MOUSE_RIGHT;
          break;
        case  8: return -1;         /* fourth button down */
        case  9: return -1;         /* fourth button up */
        case 10: return -1;         /* mouse outside of filter rectangle */
        default: return -1;         /* should never occur */
        }

        mouse_col = Pc - 1;
        mouse_row = Pr - 1;

        slen += (int)(p - (tp + slen));
      }

      /* Interpret the mouse code */
      current_button = (mouse_code & MOUSE_CLICK_MASK);
      if (current_button == MOUSE_RELEASE
          && wheel_code == 0
          ) {
        /*
         * If we get a mouse drag or release event when
         * there is no mouse button held down (held_button ==
         * MOUSE_RELEASE), produce a K_IGNORE below.
         * (can happen when you hold down two buttons
         * and then let them go, or click in the menu bar, but not
         * on a menu, and drag into the text).
         */
        if ((mouse_code & MOUSE_DRAG) == MOUSE_DRAG)
          is_drag = TRUE;
        current_button = held_button;
      } else if (wheel_code == 0)   {
# ifdef CHECK_DOUBLE_CLICK
        {
          /*
           * Compute the time elapsed since the previous mouse click.
           */
          gettimeofday(&mouse_time, NULL);
          timediff = (mouse_time.tv_usec
                      - orig_mouse_time.tv_usec) / 1000;
          if (timediff < 0)
            --orig_mouse_time.tv_sec;
          timediff += (mouse_time.tv_sec
                       - orig_mouse_time.tv_sec) * 1000;
          orig_mouse_time = mouse_time;
          if (mouse_code == orig_mouse_code
              && timediff < p_mouset
              && orig_num_clicks != 4
              && orig_mouse_col == mouse_col
              && orig_mouse_row == mouse_row
              && ((orig_topline == curwin->w_topline
                   && orig_topfill == curwin->w_topfill
                   )
                  /* Double click in tab pages line also works
                   * when window contents changes. */
                  || (mouse_row == 0 && firstwin->w_winrow > 0)
                  )
              )
            ++orig_num_clicks;
          else
            orig_num_clicks = 1;
          orig_mouse_col = mouse_col;
          orig_mouse_row = mouse_row;
          orig_topline = curwin->w_topline;
          orig_topfill = curwin->w_topfill;
        }
# else
        orig_num_clicks = NUM_MOUSE_CLICKS(mouse_code);
# endif
        is_click = TRUE;
        orig_mouse_code = mouse_code;
      }
      if (!is_drag)
        held_button = mouse_code & MOUSE_CLICK_MASK;

      /*
       * Translate the actual mouse event into a pseudo mouse event.
       * First work out what modifiers are to be used.
       */
      if (orig_mouse_code & MOUSE_SHIFT)
        modifiers |= MOD_MASK_SHIFT;
      if (orig_mouse_code & MOUSE_CTRL)
        modifiers |= MOD_MASK_CTRL;
      if (orig_mouse_code & MOUSE_ALT)
        modifiers |= MOD_MASK_ALT;
      if (orig_num_clicks == 2)
        modifiers |= MOD_MASK_2CLICK;
      else if (orig_num_clicks == 3)
        modifiers |= MOD_MASK_3CLICK;
      else if (orig_num_clicks == 4)
        modifiers |= MOD_MASK_4CLICK;

      /* Work out our pseudo mouse event */
      key_name[0] = (int)KS_EXTRA;
      if (wheel_code != 0) {
        if (wheel_code & MOUSE_CTRL)
          modifiers |= MOD_MASK_CTRL;
        if (wheel_code & MOUSE_ALT)
          modifiers |= MOD_MASK_ALT;
        key_name[1] = (wheel_code & 1)
                      ? (int)KE_MOUSEUP : (int)KE_MOUSEDOWN;
      } else
        key_name[1] = get_pseudo_mouse_code(current_button,
            is_click, is_drag);
    }


    /*
     * Change <xHome> to <Home>, <xUp> to <Up>, etc.
     */
    key = handle_x_keys(TERMCAP2KEY(key_name[0], key_name[1]));

    /*
     * Add any modifier codes to our string.
     */
    new_slen = 0;               /* Length of what will replace the termcode */
    if (modifiers != 0) {
      /* Some keys have the modifier included.  Need to handle that here
       * to make mappings work. */
      key = simplify_key(key, &modifiers);
      if (modifiers != 0) {
        string[new_slen++] = K_SPECIAL;
        string[new_slen++] = (int)KS_MODIFIER;
        string[new_slen++] = modifiers;
      }
    }

    /* Finally, add the special key code to our string */
    key_name[0] = KEY2TERMCAP0(key);
    key_name[1] = KEY2TERMCAP1(key);
    if (key_name[0] == KS_KEY) {
      /* from ":set <M-b>=xx" */
      if (has_mbyte)
        new_slen += (*mb_char2bytes)(key_name[1], string + new_slen);
      else
        string[new_slen++] = key_name[1];
    } else if (new_slen == 0 && key_name[0] == KS_EXTRA
               && key_name[1] == KE_IGNORE) {
      /* Do not put K_IGNORE into the buffer, do return KEYLEN_REMOVED
       * to indicate what happened. */
      retval = KEYLEN_REMOVED;
    } else   {
      string[new_slen++] = K_SPECIAL;
      string[new_slen++] = key_name[0];
      string[new_slen++] = key_name[1];
    }
    string[new_slen] = NUL;
    extra = new_slen - slen;
    if (buf == NULL) {
      if (extra < 0)
        /* remove matched chars, taking care of noremap */
        del_typebuf(-extra, offset);
      else if (extra > 0)
        /* insert the extra space we need */
        ins_typebuf(string + slen, REMAP_YES, offset, FALSE, FALSE);

      /*
       * Careful: del_typebuf() and ins_typebuf() may have reallocated
       * typebuf.tb_buf[]!
       */
      mch_memmove(typebuf.tb_buf + typebuf.tb_off + offset, string,
          (size_t)new_slen);
    } else   {
      if (extra < 0)
        /* remove matched characters */
        mch_memmove(buf + offset, buf + offset - extra,
            (size_t)(*buflen + offset + extra));
      else if (extra > 0) {
        /* Insert the extra space we need.  If there is insufficient
         * space return -1. */
        if (*buflen + extra + new_slen >= bufsize)
          return -1;
        mch_memmove(buf + offset + extra, buf + offset,
            (size_t)(*buflen - offset));
      }
      mch_memmove(buf + offset, string, (size_t)new_slen);
      *buflen = *buflen + extra + new_slen;
    }
    return retval == 0 ? (len + extra + offset) : retval;
  }

  LOG_TR("normal character");

  return 0;                         /* no match found */
}

/*
 * Replace any terminal code strings in from[] with the equivalent internal
 * vim representation.	This is used for the "from" and "to" part of a
 * mapping, and the "to" part of a menu command.
 * Any strings like "<C-UP>" are also replaced, unless 'cpoptions' contains
 * '<'.
 * K_SPECIAL by itself is replaced by K_SPECIAL KS_SPECIAL KE_FILLER.
 *
 * The replacement is done in result[] and finally copied into allocated
 * memory. If this all works well *bufp is set to the allocated memory and a
 * pointer to it is returned. If something fails *bufp is set to NULL and from
 * is returned.
 *
 * CTRL-V characters are removed.  When "from_part" is TRUE, a trailing CTRL-V
 * is included, otherwise it is removed (for ":map xx ^V", maps xx to
 * nothing).  When 'cpoptions' does not contain 'B', a backslash can be used
 * instead of a CTRL-V.
 */
char_u *
replace_termcodes (
    char_u *from,
    char_u **bufp,
    int from_part,
    int do_lt,                      /* also translate <lt> */
    int special                    /* always accept <key> notation */
)
{
  int i;
  int slen;
  int key;
  int dlen = 0;
  char_u      *src;
  int do_backslash;             /* backslash is a special character */
  int do_special;               /* recognize <> key codes */
  int do_key_code;              /* recognize raw key codes */
  char_u      *result;          /* buffer for resulting string */

  do_backslash = (vim_strchr(p_cpo, CPO_BSLASH) == NULL);
  do_special = (vim_strchr(p_cpo, CPO_SPECI) == NULL) || special;
  do_key_code = (vim_strchr(p_cpo, CPO_KEYCODE) == NULL);

  /*
   * Allocate space for the translation.  Worst case a single character is
   * replaced by 6 bytes (shifted special key), plus a NUL at the end.
   */
  result = alloc((unsigned)STRLEN(from) * 6 + 1);
  if (result == NULL) {         /* out of memory */
    *bufp = NULL;
    return from;
  }

  src = from;

  /*
   * Check for #n at start only: function key n
   */
  if (from_part && src[0] == '#' && VIM_ISDIGIT(src[1])) {  /* function key */
    result[dlen++] = K_SPECIAL;
    result[dlen++] = 'k';
    if (src[1] == '0')
      result[dlen++] = ';';             /* #0 is F10 is "k;" */
    else
      result[dlen++] = src[1];          /* #3 is F3 is "k3" */
    src += 2;
  }

  /*
   * Copy each byte from *from to result[dlen]
   */
  while (*src != NUL) {
    /*
     * If 'cpoptions' does not contain '<', check for special key codes,
     * like "<C-S-LeftMouse>"
     */
    if (do_special && (do_lt || STRNCMP(src, "<lt>", 4) != 0)) {
      /*
       * Replace <SID> by K_SNR <script-nr> _.
       * (room: 5 * 6 = 30 bytes; needed: 3 + <nr> + 1 <= 14)
       */
      if (STRNICMP(src, "<SID>", 5) == 0) {
        if (current_SID <= 0)
          EMSG(_(e_usingsid));
        else {
          src += 5;
          result[dlen++] = K_SPECIAL;
          result[dlen++] = (int)KS_EXTRA;
          result[dlen++] = (int)KE_SNR;
          sprintf((char *)result + dlen, "%ld", (long)current_SID);
          dlen += (int)STRLEN(result + dlen);
          result[dlen++] = '_';
          continue;
        }
      }

      slen = trans_special(&src, result + dlen, TRUE);
      if (slen) {
        dlen += slen;
        continue;
      }
    }

    /*
     * If 'cpoptions' does not contain 'k', see if it's an actual key-code.
     * Note that this is also checked after replacing the <> form.
     * Single character codes are NOT replaced (e.g. ^H or DEL), because
     * it could be a character in the file.
     */
    if (do_key_code) {
      i = find_term_bykeys(src);
      if (i >= 0) {
        result[dlen++] = K_SPECIAL;
        result[dlen++] = termcodes[i].name[0];
        result[dlen++] = termcodes[i].name[1];
        src += termcodes[i].len;
        /* If terminal code matched, continue after it. */
        continue;
      }
    }

    if (do_special) {
      char_u      *p, *s, len;

      /*
       * Replace <Leader> by the value of "mapleader".
       * Replace <LocalLeader> by the value of "maplocalleader".
       * If "mapleader" or "maplocalleader" isn't set use a backslash.
       */
      if (STRNICMP(src, "<Leader>", 8) == 0) {
        len = 8;
        p = get_var_value((char_u *)"g:mapleader");
      } else if (STRNICMP(src, "<LocalLeader>", 13) == 0)   {
        len = 13;
        p = get_var_value((char_u *)"g:maplocalleader");
      } else   {
        len = 0;
        p = NULL;
      }
      if (len != 0) {
        /* Allow up to 8 * 6 characters for "mapleader". */
        if (p == NULL || *p == NUL || STRLEN(p) > 8 * 6)
          s = (char_u *)"\\";
        else
          s = p;
        while (*s != NUL)
          result[dlen++] = *s++;
        src += len;
        continue;
      }
    }

    /*
     * Remove CTRL-V and ignore the next character.
     * For "from" side the CTRL-V at the end is included, for the "to"
     * part it is removed.
     * If 'cpoptions' does not contain 'B', also accept a backslash.
     */
    key = *src;
    if (key == Ctrl_V || (do_backslash && key == '\\')) {
      ++src;                                    /* skip CTRL-V or backslash */
      if (*src == NUL) {
        if (from_part)
          result[dlen++] = key;
        break;
      }
    }

    /* skip multibyte char correctly */
    for (i = (*mb_ptr2len)(src); i > 0; --i) {
      /*
       * If the character is K_SPECIAL, replace it with K_SPECIAL
       * KS_SPECIAL KE_FILLER.
       * If compiled with the GUI replace CSI with K_CSI.
       */
      if (*src == K_SPECIAL) {
        result[dlen++] = K_SPECIAL;
        result[dlen++] = KS_SPECIAL;
        result[dlen++] = KE_FILLER;
      } else
        result[dlen++] = *src;
      ++src;
    }
  }
  result[dlen] = NUL;

  /*
   * Copy the new string to allocated memory.
   * If this fails, just return from.
   */
  if ((*bufp = vim_strsave(result)) != NULL)
    from = *bufp;
  vim_free(result);
  return from;
}

/*
 * Find a termcode with keys 'src' (must be NUL terminated).
 * Return the index in termcodes[], or -1 if not found.
 */
int find_term_bykeys(char_u *src)
{
  int i;
  int slen = (int)STRLEN(src);

  for (i = 0; i < tc_len; ++i) {
    if (slen == termcodes[i].len
        && STRNCMP(termcodes[i].code, src, (size_t)slen) == 0)
      return i;
  }
  return -1;
}

/*
 * Gather the first characters in the terminal key codes into a string.
 * Used to speed up check_termcode().
 */
static void gather_termleader(void)                 {
  int i;
  int len = 0;

  if (check_for_codes)
    termleader[len++] = DCS;        /* the termcode response starts with DCS
                                       in 8-bit mode */
  termleader[len] = NUL;

  for (i = 0; i < tc_len; ++i)
    if (vim_strchr(termleader, termcodes[i].code[0]) == NULL) {
      termleader[len++] = termcodes[i].code[0];
      termleader[len] = NUL;
    }

  need_gather = FALSE;
}

/*
 * Show all termcodes (for ":set termcap")
 * This code looks a lot like showoptions(), but is different.
 */
void show_termcodes(void)          {
  int col;
  int         *items;
  int item_count;
  int run;
  int row, rows;
  int cols;
  int i;
  int len;

#define INC3 27     /* try to make three columns */
#define INC2 40     /* try to make two columns */
#define GAP 2       /* spaces between columns */

  if (tc_len == 0)          /* no terminal codes (must be GUI) */
    return;
  items = (int *)alloc((unsigned)(sizeof(int) * tc_len));
  if (items == NULL)
    return;

  /* Highlight title */
  MSG_PUTS_TITLE(_("\n--- Terminal keys ---"));

  /*
   * do the loop two times:
   * 1. display the short items (non-strings and short strings)
   * 2. display the medium items (medium length strings)
   * 3. display the long items (remaining strings)
   */
  for (run = 1; run <= 3 && !got_int; ++run) {
    /*
     * collect the items in items[]
     */
    item_count = 0;
    for (i = 0; i < tc_len; i++) {
      len = show_one_termcode(termcodes[i].name,
          termcodes[i].code, FALSE);
      if (len <= INC3 - GAP ? run == 1
          : len <= INC2 - GAP ? run == 2
          : run == 3)
        items[item_count++] = i;
    }

    /*
     * display the items
     */
    if (run <= 2) {
      cols = (Columns + GAP) / (run == 1 ? INC3 : INC2);
      if (cols == 0)
        cols = 1;
      rows = (item_count + cols - 1) / cols;
    } else      /* run == 3 */
      rows = item_count;
    for (row = 0; row < rows && !got_int; ++row) {
      msg_putchar('\n');                        /* go to next line */
      if (got_int)                              /* 'q' typed in more */
        break;
      col = 0;
      for (i = row; i < item_count; i += rows) {
        msg_col = col;                          /* make columns */
        show_one_termcode(termcodes[items[i]].name,
            termcodes[items[i]].code, TRUE);
        if (run == 2)
          col += INC2;
        else
          col += INC3;
      }
      out_flush();
      ui_breakcheck();
    }
  }
  vim_free(items);
}

/*
 * Show one termcode entry.
 * Output goes into IObuff[]
 */
int show_one_termcode(char_u *name, char_u *code, int printit)
{
  char_u      *p;
  int len;

  if (name[0] > '~') {
    IObuff[0] = ' ';
    IObuff[1] = ' ';
    IObuff[2] = ' ';
    IObuff[3] = ' ';
  } else   {
    IObuff[0] = 't';
    IObuff[1] = '_';
    IObuff[2] = name[0];
    IObuff[3] = name[1];
  }
  IObuff[4] = ' ';

  p = get_special_key_name(TERMCAP2KEY(name[0], name[1]), 0);
  if (p[1] != 't')
    STRCPY(IObuff + 5, p);
  else
    IObuff[5] = NUL;
  len = (int)STRLEN(IObuff);
  do
    IObuff[len++] = ' ';
  while (len < 17);
  IObuff[len] = NUL;
  if (code == NULL)
    len += 4;
  else
    len += vim_strsize(code);

  if (printit) {
    msg_puts(IObuff);
    if (code == NULL)
      msg_puts((char_u *)"NULL");
    else
      msg_outtrans(code);
  }
  return len;
}

/*
 * For Xterm >= 140 compiled with OPT_TCAP_QUERY: Obtain the actually used
 * termcap codes from the terminal itself.
 * We get them one by one to avoid a very long response string.
 */
static int xt_index_in = 0;
static int xt_index_out = 0;

static void req_codes_from_term(void)                 {
  xt_index_out = 0;
  xt_index_in = 0;
  req_more_codes_from_term();
}

static void req_more_codes_from_term(void)                 {
  char buf[11];
  int old_idx = xt_index_out;

  /* Don't do anything when going to exit. */
  if (exiting)
    return;

  /* Send up to 10 more requests out than we received.  Avoid sending too
   * many, there can be a buffer overflow somewhere. */
  while (xt_index_out < xt_index_in + 10 && key_names[xt_index_out] != NULL) {
# ifdef DEBUG_TERMRESPONSE
    char dbuf[100];

    sprintf(dbuf, "Requesting XT %d: %s",
        xt_index_out, key_names[xt_index_out]);
    log_tr(dbuf);
# endif
    sprintf(buf, "\033P+q%02x%02x\033\\",
        key_names[xt_index_out][0], key_names[xt_index_out][1]);
    out_str_nf((char_u *)buf);
    ++xt_index_out;
  }

  /* Send the codes out right away. */
  if (xt_index_out != old_idx)
    out_flush();
}

/*
 * Decode key code response from xterm: '<Esc>P1+r<name>=<string><Esc>\'.
 * A "0" instead of the "1" indicates a code that isn't supported.
 * Both <name> and <string> are encoded in hex.
 * "code" points to the "0" or "1".
 */
static void got_code_from_term(char_u *code, int len)
{
#define XT_LEN 100
  char_u name[3];
  char_u str[XT_LEN];
  int i;
  int j = 0;
  int c;

  /* A '1' means the code is supported, a '0' means it isn't.
   * When half the length is > XT_LEN we can't use it.
   * Our names are currently all 2 characters. */
  if (code[0] == '1' && code[7] == '=' && len / 2 < XT_LEN) {
    /* Get the name from the response and find it in the table. */
    name[0] = hexhex2nr(code + 3);
    name[1] = hexhex2nr(code + 5);
    name[2] = NUL;
    for (i = 0; key_names[i] != NULL; ++i) {
      if (STRCMP(key_names[i], name) == 0) {
        xt_index_in = i;
        break;
      }
    }
# ifdef DEBUG_TERMRESPONSE
    {
      char buf[100];

      sprintf(buf, "Received XT %d: %s", xt_index_in, (char *)name);
      log_tr(buf);
    }
# endif
    if (key_names[i] != NULL) {
      for (i = 8; (c = hexhex2nr(code + i)) >= 0; i += 2)
        str[j++] = c;
      str[j] = NUL;
      if (name[0] == 'C' && name[1] == 'o') {
        /* Color count is not a key code. */
        i = atoi((char *)str);
        if (i != t_colors) {
          /* Nr of colors changed, initialize highlighting and
           * redraw everything.  This causes a redraw, which usually
           * clears the message.  Try keeping the message if it
           * might work. */
          set_keep_msg_from_hist();
          set_color_count(i);
          init_highlight(TRUE, FALSE);
#ifdef DEBUG_TERMRESPONSE
          {
            char buf[100];
            int r = redraw_asap(CLEAR);

            sprintf(buf, "Received t_Co, redraw_asap(): %d", r);
            log_tr(buf);
          }
#else
          redraw_asap(CLEAR);
#endif
        }
      } else   {
        /* First delete any existing entry with the same code. */
        i = find_term_bykeys(str);
        if (i >= 0)
          del_termcode_idx(i);
        add_termcode(name, str, ATC_FROM_TERM);
      }
    }
  }

  /* May request more codes now that we received one. */
  ++xt_index_in;
  req_more_codes_from_term();
}

/*
 * Check if there are any unanswered requests and deal with them.
 * This is called before starting an external program or getting direct
 * keyboard input.  We don't want responses to be send to that program or
 * handled as typed text.
 */
static void check_for_codes_from_term(void)                 {
  int c;

  /* If no codes requested or all are answered, no need to wait. */
  if (xt_index_out == 0 || xt_index_out == xt_index_in)
    return;

  /* Vgetc() will check for and handle any response.
   * Keep calling vpeekc() until we don't get any responses. */
  ++no_mapping;
  ++allow_keys;
  for (;; ) {
    c = vpeekc();
    if (c == NUL)           /* nothing available */
      break;

    /* If a response is recognized it's replaced with K_IGNORE, must read
     * it from the input stream.  If there is no K_IGNORE we can't do
     * anything, break here (there might be some responses further on, but
     * we don't want to throw away any typed chars). */
    if (c != K_SPECIAL && c != K_IGNORE)
      break;
    c = vgetc();
    if (c != K_IGNORE) {
      vungetc(c);
      break;
    }
  }
  --no_mapping;
  --allow_keys;
}

/*
 * Translate an internal mapping/abbreviation representation into the
 * corresponding external one recognized by :map/:abbrev commands;
 * respects the current B/k/< settings of 'cpoption'.
 *
 * This function is called when expanding mappings/abbreviations on the
 * command-line, and for building the "Ambiguous mapping..." error message.
 *
 * It uses a growarray to build the translation string since the
 * latter can be wider than the original description. The caller has to
 * free the string afterwards.
 *
 * Returns NULL when there is a problem.
 */
char_u *
translate_mapping (
    char_u *str,
    int expmap              /* TRUE when expanding mappings on command-line */
)
{
  garray_T ga;
  int c;
  int modifiers;
  int cpo_bslash;
  int cpo_special;
  int cpo_keycode;

  ga_init(&ga);
  ga.ga_itemsize = 1;
  ga.ga_growsize = 40;

  cpo_bslash = (vim_strchr(p_cpo, CPO_BSLASH) != NULL);
  cpo_special = (vim_strchr(p_cpo, CPO_SPECI) != NULL);
  cpo_keycode = (vim_strchr(p_cpo, CPO_KEYCODE) == NULL);

  for (; *str; ++str) {
    c = *str;
    if (c == K_SPECIAL && str[1] != NUL && str[2] != NUL) {
      modifiers = 0;
      if (str[1] == KS_MODIFIER) {
        str++;
        modifiers = *++str;
        c = *++str;
      }
      if (cpo_special && cpo_keycode && c == K_SPECIAL && !modifiers) {
        int i;

        /* try to find special key in termcodes */
        for (i = 0; i < tc_len; ++i)
          if (termcodes[i].name[0] == str[1]
              && termcodes[i].name[1] == str[2])
            break;
        if (i < tc_len) {
          ga_concat(&ga, termcodes[i].code);
          str += 2;
          continue;           /* for (str) */
        }
      }
      if (c == K_SPECIAL && str[1] != NUL && str[2] != NUL) {
        if (expmap && cpo_special) {
          ga_clear(&ga);
          return NULL;
        }
        c = TO_SPECIAL(str[1], str[2]);
        if (c == K_ZERO)                /* display <Nul> as ^@ */
          c = NUL;
        str += 2;
      }
      if (IS_SPECIAL(c) || modifiers) {         /* special key */
        if (expmap && cpo_special) {
          ga_clear(&ga);
          return NULL;
        }
        ga_concat(&ga, get_special_key_name(c, modifiers));
        continue;         /* for (str) */
      }
    }
    if (c == ' ' || c == '\t' || c == Ctrl_J || c == Ctrl_V
        || (c == '<' && !cpo_special) || (c == '\\' && !cpo_bslash))
      ga_append(&ga, cpo_bslash ? Ctrl_V : '\\');
    if (c)
      ga_append(&ga, c);
  }
  ga_append(&ga, NUL);
  return (char_u *)(ga.ga_data);
}

