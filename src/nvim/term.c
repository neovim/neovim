/*
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
 * primitive termcap support for Win32 included
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
#include <assert.h>
#include <errno.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/term.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/getchar.h"
#include "nvim/message.h"
#include "nvim/misc2.h"
#include "nvim/garray.h"
#include "nvim/keymap.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/mouse.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/popupmnu.h"
#include "nvim/screen.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/ui.h"
#include "nvim/window.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"
#include "nvim/os/input.h"


#undef tgetstr

/*
 * Here are the builtin termcap entries.  They are not stored as complete
 * structures with all entries, as such a structure is too big.
 *
 * The entries are compact, therefore they normally are included even when
 * HAVE_TGETENT is defined. When HAVE_TGETENT is defined, the builtin entries
 * can be accessed with "builtin_ansi", "builtin_debug", etc.
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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "term.c.generated.h"
#endif


static bool detected_8bit = false;       // detected 8-bit terminal

static struct builtin_term builtin_termcaps[] =
{
  // abstract UI pseudo termcap, based on vim's "builtin_gui" termcap
  {(int)KS_NAME, "abstract_ui"},
  {(int)KS_CE,   "\033|$"},
  {(int)KS_AL,   "\033|i"},
  {(int)KS_CAL,  "\033|%p1%dI"},
  {(int)KS_DL,   "\033|d"},
  {(int)KS_CDL,  "\033|%p1%dD"},
  {(int)KS_CS,   "\033|%p1%d;%p2%dR"},
  {(int)KS_CSV,  "\033|%p1%d;%p2%dV"},
  {(int)KS_CL,   "\033|C"},
  // attributes switched on with 'h', off with * 'H'
  {(int)KS_ME,   "\033|31H"},  // HL_ALL
  {(int)KS_MR,   "\033|1h"},   // HL_INVERSE
  {(int)KS_MD,   "\033|2h"},   // HL_BOLD
  {(int)KS_SE,   "\033|16H"},  // HL_STANDOUT
  {(int)KS_SO,   "\033|16h"},  // HL_STANDOUT
  {(int)KS_UE,   "\033|8H"},   // HL_UNDERLINE
  {(int)KS_US,   "\033|8h"},   // HL_UNDERLINE
  {(int)KS_CZR,  "\033|4H"},   // HL_ITALIC
  {(int)KS_CZH,  "\033|4h"},   // HL_ITALIC
  {(int)KS_VB,   "\033|f"},
  {(int)KS_MS,   "y"},
  {(int)KS_UT,   "y"},
  {(int)KS_LE,   "\b"},        // cursor-left = BS
  {(int)KS_ND,   "\014"},      // cursor-right = CTRL-L
  {(int)KS_CM,   "\033|%p1%d;%p2%dM"},
  // there are no key sequences here, for "abstract_ui" vim key codes are
  // parsed directly in input_enqueue()


#ifndef NO_BUILTIN_TCAPS

# if defined(ALL_BUILTIN_TCAPS)
  /*
   * Amiga console window, default for Amiga
   */
  {(int)KS_NAME,      "amiga"},
  {(int)KS_CE,        "\033[K"},
  {(int)KS_CD,        "\033[J"},
  {(int)KS_AL,        "\033[L"},
  {(int)KS_CAL,       "\033[%dL"},
  {(int)KS_DL,        "\033[M"},
  {(int)KS_CDL,       "\033[%dM"},
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
  {(int)KS_MS,        "y"},
  {(int)KS_UT,        "y"},             /* guessed */
  {(int)KS_LE,        "\b"},
  {(int)KS_CM,        "\033[%i%d;%dH"},
  {(int)KS_CRI,       "\033[%dC"},
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

# if defined(UNIX) || defined(ALL_BUILTIN_TCAPS) || defined(SOME_BUILTIN_TCAPS)
  /*
   * standard ANSI terminal, default for unix
   */
  {(int)KS_NAME,      "ansi"},
  {(int)KS_CE,        "\033[K"},
  {(int)KS_AL,        "\033[L"},
  {(int)KS_CAL,       "\033[%dL"},
  {(int)KS_DL,        "\033[M"},
  {(int)KS_CDL,       "\033[%dM"},
  {(int)KS_CL,        "\033[H\033[2J"},
  {(int)KS_ME,        "\033[0m"},
  {(int)KS_MR,        "\033[7m"},
  {(int)KS_MS,        "y"},
  {(int)KS_UT,        "y"},             /* guessed */
  {(int)KS_LE,        "\b"},
  {(int)KS_CM,        "\033[%i%d;%dH"},
  {(int)KS_CRI,       "\033[%dC"},
# endif

# if defined(ALL_BUILTIN_TCAPS)
  /*
   * These codes are valid when nansi.sys or equivalent has been installed.
   * Function keys on a PC are preceded with a NUL. These are converted into
   * K_NUL '\316' in os_inchar(), because we cannot handle NULs in key codes.
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
  {(int)KS_CAB,       "\033[4%dm"},     /* set background color */
  {(int)KS_CAF,       "\033[3%dm"},     /* set foreground color */
  {(int)KS_OP,        "\033[0m"},       /* reset colors */
  {(int)KS_MS,        "y"},
  {(int)KS_UT,        "y"},             /* guessed */
  {(int)KS_LE,        "\b"},
  {(int)KS_CM,        "\033[%i%d;%dH"},
  {(int)KS_CRI,       "\033[%dC"},
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


# if defined(WIN3264) || defined(ALL_BUILTIN_TCAPS)
  /*
   * These codes are valid for the Win32 Console .  The entries that start with
   * ESC | are translated into console calls in os_win32.c.  The function keys
   * are also translated in os_win32.c.
   */
  {(int)KS_NAME,      "win32"},
  {(int)KS_CE,        "\033|K"},        /* clear to end of line */
  {(int)KS_AL,        "\033|L"},        /* add new blank line */
  {(int)KS_CAL,       "\033|%dL"},      /* add number of new blank lines */
  {(int)KS_DL,        "\033|M"},        /* delete line */
  {(int)KS_CDL,       "\033|%dM"},      /* delete number of lines */
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
  {(int)KS_CAB,       "\033|%db"},      /* set background color */
  {(int)KS_CAF,       "\033|%df"},      /* set foreground color */

  {(int)KS_MS,        "y"},             /* save to move cur in reverse mode */
  {(int)KS_UT,        "y"},
  {(int)KS_LE,        "\b"},
  {(int)KS_CM,        "\033|%i%d;%dH"},  /* cursor motion */
  {(int)KS_VB,        "\033|B"},        /* visual bell */
  {(int)KS_TI,        "\033|S"},        /* put terminal in termcap mode */
  {(int)KS_TE,        "\033|E"},        /* out of termcap mode */
  {(int)KS_CS,        "\033|%i%d;%dr"},  /* scroll region */

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

# if defined(ALL_BUILTIN_TCAPS)
  /*
   * VT320 is working as an ANSI terminal compatible DEC terminal.
   * (it covers VT1x0, VT2x0 and VT3x0 up to VT320 on VMS as well)
   * Note: K_F1...K_F5 are for internal use, should not be defined.
   * TODO:- rewrite ESC[ codes to CSI
   *      - keyboard languages (CSI ? 26 n)
   */
  {(int)KS_NAME,      "vt320"},
  {(int)KS_CE,        "\033[K"},
  {(int)KS_AL,        "\033[L"},
  {(int)KS_CAL,       "\033[%dL"},
  {(int)KS_DL,        "\033[M"},
  {(int)KS_CDL,       "\033[%dM"},
  {(int)KS_CL,        "\033[H\033[2J"},
  {(int)KS_CD,        "\033[J"},
  {(int)KS_CCO,       "8"},                     /* allow 8 colors */
  {(int)KS_ME,        "\033[0m"},
  {(int)KS_MR,        "\033[7m"},
  {(int)KS_MD,        "\033[1m"},    /* bold mode */
  {(int)KS_SE,        "\033[22m"},  /* normal mode */
  {(int)KS_UE,        "\033[24m"},  /* exit underscore mode */
  {(int)KS_US,        "\033[4m"},    /* underscore mode */
  {(int)KS_CZH,       "\033[34;43m"},    /* italic mode: blue text on yellow */
  {(int)KS_CZR,       "\033[0m"},             /* italic mode end */
  {(int)KS_CAB,       "\033[4%dm"},         /* set background color (ANSI) */
  {(int)KS_CAF,       "\033[3%dm"},         /* set foreground color (ANSI) */
  {(int)KS_CSB,       "\033[102;%dm"},       /* set screen background color */
  {(int)KS_CSF,       "\033[101;%dm"},       /* set screen foreground color */
  {(int)KS_MS,        "y"},
  {(int)KS_UT,        "y"},
  {(int)KS_LE,        "\b"},
  {(int)KS_CM,        "\033[%i%d;%dH"},
  {(int)KS_CRI,       "\033[%dC"},
  {K_UP,              "\033[A"},
  {K_DOWN,            "\033[B"},
  {K_RIGHT,           "\033[C"},
  {K_LEFT,            "\033[D"},
  {K_F1,              "\033[11~"},
  {K_F2,              "\033[12~"},
  {K_F3,              "\033[13~"},
  {K_F4,              "\033[14~"},
  {K_F5,              "\033[15~"},
  {K_F6,              "\033[17~"},
  {K_F7,              "\033[18~"},
  {K_F8,              "\033[19~"},
  {K_F9,              "\033[20~"},
  {K_F10,             "\033[21~"},
  {K_F11,             "\033[23~"},
  {K_F12,             "\033[24~"},
  {K_F13,             "\033[25~"},
  {K_F14,             "\033[26~"},
  {K_F15,             "\033[28~"},       /* Help */
  {K_F16,             "\033[29~"},       /* Select */
  {K_F17,             "\033[31~"},
  {K_F18,             "\033[32~"},
  {K_F19,             "\033[33~"},
  {K_F20,             "\033[34~"},
  {K_INS,             "\033[2~"},
  {K_DEL,             "\033[3~"},
  {K_HOME,            "\033[1~"},
  {K_END,             "\033[4~"},
  {K_PAGEUP,          "\033[5~"},
  {K_PAGEDOWN,        "\033[6~"},
  {K_KPLUS,           "\033Ok"},   /* keypad plus */
  {K_KMINUS,          "\033Om"},   /* keypad minus */
  {K_KDIVIDE,         "\033Oo"},   /* keypad / */
  {K_KMULTIPLY,       "\033Oj"},   /* keypad * */
  {K_KENTER,          "\033OM"},   /* keypad Enter */
  {K_BS,              "\x7f"},          /* for some reason 0177 doesn't work */
# endif

# if defined(ALL_BUILTIN_TCAPS)
  /*
   * Ordinary vt52
   */
  {(int)KS_NAME,      "vt52"},
  {(int)KS_CE,        "\033K"},
  {(int)KS_CD,        "\033J"},
  {(int)KS_CM,        "\033Y%+ %+ "},
  {(int)KS_LE,        "\b"},
  {(int)KS_AL,        "\033T"},
  {(int)KS_DL,        "\033U"},
  {(int)KS_CL,        "\033H\033J"},
  {(int)KS_ME,        "\033SO"},
  {(int)KS_MR,        "\033S2"},
  {(int)KS_MS,        "y"},
# endif

# if defined(UNIX) || defined(ALL_BUILTIN_TCAPS) || defined(SOME_BUILTIN_TCAPS)
  {(int)KS_NAME,      "xterm"},
  {(int)KS_CE,        "\033[K"},
  {(int)KS_AL,        "\033[L"},
  {(int)KS_CAL,       "\033[%dL"},
  {(int)KS_DL,        "\033[M"},
  {(int)KS_CDL,       "\033[%dM"},
  {(int)KS_CS,        "\033[%i%d;%dr"},
  {(int)KS_CL,        "\033[H\033[2J"},
  {(int)KS_CD,        "\033[J"},
  {(int)KS_ME,        "\033[m"},
  {(int)KS_MR,        "\033[7m"},
  {(int)KS_MD,        "\033[1m"},
  {(int)KS_UE,        "\033[m"},
  {(int)KS_US,        "\033[4m"},
  {(int)KS_MS,        "y"},
  {(int)KS_UT,        "y"},
  {(int)KS_LE,        "\b"},
  {(int)KS_CM,        "\033[%i%d;%dH"},
  {(int)KS_SR,        "\033M"},
  {(int)KS_CRI,       "\033[%dC"},
  {(int)KS_KS,        "\033[?1h\033="},
  {(int)KS_KE,        "\033[?1l\033>"},
  {(int)KS_CIS,       "\033]1;"},
  {(int)KS_CIE,       "\007"},
  {(int)KS_TS,        "\033]2;"},
  {(int)KS_FS,        "\007"},
  {(int)KS_CWS,       "\033[8;%d;%dt"},
  {(int)KS_CWP,       "\033[3;%d;%dt"},
  {(int)KS_CRV,       "\033[>c"},
  {(int)KS_U7,        "\033[6n"},

  {K_UP,              "\033O*A"},
  {K_DOWN,            "\033O*B"},
  {K_RIGHT,           "\033O*C"},
  {K_LEFT,            "\033O*D"},
  /* An extra set of cursor keys for vt100 mode */
  {K_XUP,             "\033[1;*A"},
  {K_XDOWN,           "\033[1;*B"},
  {K_XRIGHT,          "\033[1;*C"},
  {K_XLEFT,           "\033[1;*D"},
  /* An extra set of function keys for vt100 mode */
  {K_XF1,             "\033O*P"},
  {K_XF2,             "\033O*Q"},
  {K_XF3,             "\033O*R"},
  {K_XF4,             "\033O*S"},
  {K_F1,              "\033[11;*~"},
  {K_F2,              "\033[12;*~"},
  {K_F3,              "\033[13;*~"},
  {K_F4,              "\033[14;*~"},
  {K_F5,              "\033[15;*~"},
  {K_F6,              "\033[17;*~"},
  {K_F7,              "\033[18;*~"},
  {K_F8,              "\033[19;*~"},
  {K_F9,              "\033[20;*~"},
  {K_F10,             "\033[21;*~"},
  {K_F11,             "\033[23;*~"},
  {K_F12,             "\033[24;*~"},
  {K_S_TAB,           "\033[Z"},
  {K_HELP,            "\033[28;*~"},
  {K_UNDO,            "\033[26;*~"},
  {K_INS,             "\033[2;*~"},
  {K_HOME,            "\033[1;*H"},
  /* {K_S_HOME,		"\033O2H"}, */
  /* {K_C_HOME,		"\033O5H"}, */
  {K_KHOME,           "\033[1;*~"},
  {K_XHOME,           "\033O*H"},         /* other Home */
  {K_ZHOME,           "\033[7;*~"},     /* other Home */
  {K_END,             "\033[1;*F"},
  /* {K_S_END,		"\033O2F"}, */
  /* {K_C_END,		"\033O5F"}, */
  {K_KEND,            "\033[4;*~"},
  {K_XEND,            "\033O*F"},         /* other End */
  {K_ZEND,            "\033[8;*~"},
  {K_PAGEUP,          "\033[5;*~"},
  {K_PAGEDOWN,        "\033[6;*~"},
  {K_KPLUS,           "\033O*k"},         /* keypad plus */
  {K_KMINUS,          "\033O*m"},         /* keypad minus */
  {K_KDIVIDE,         "\033O*o"},         /* keypad / */
  {K_KMULTIPLY,       "\033O*j"},         /* keypad * */
  {K_KENTER,          "\033O*M"},         /* keypad Enter */
  {K_KPOINT,          "\033O*n"},         /* keypad . */
  {K_KDEL,            "\033[3;*~"},     /* keypad Del */

  {BT_EXTRA_KEYS,   ""},
  {TERMCAP2KEY('k', '0'), "\033[10;*~"},   /* F0 */
  {TERMCAP2KEY('F', '3'), "\033[25;*~"},   /* F13 */
  /* F14 and F15 are missing, because they send the same codes as the undo
   * and help key, although they don't work on all keyboards. */
  {TERMCAP2KEY('F', '6'), "\033[29;*~"},   /* F16 */
  {TERMCAP2KEY('F', '7'), "\033[31;*~"},   /* F17 */
  {TERMCAP2KEY('F', '8'), "\033[32;*~"},   /* F18 */
  {TERMCAP2KEY('F', '9'), "\033[33;*~"},   /* F19 */
  {TERMCAP2KEY('F', 'A'), "\033[34;*~"},   /* F20 */

  {TERMCAP2KEY('F', 'B'), "\033[42;*~"},   /* F21 */
  {TERMCAP2KEY('F', 'C'), "\033[43;*~"},   /* F22 */
  {TERMCAP2KEY('F', 'D'), "\033[44;*~"},   /* F23 */
  {TERMCAP2KEY('F', 'E'), "\033[45;*~"},   /* F24 */
  {TERMCAP2KEY('F', 'F'), "\033[46;*~"},   /* F25 */
  {TERMCAP2KEY('F', 'G'), "\033[47;*~"},   /* F26 */
  {TERMCAP2KEY('F', 'H'), "\033[48;*~"},   /* F27 */
  {TERMCAP2KEY('F', 'I'), "\033[49;*~"},   /* F28 */
  {TERMCAP2KEY('F', 'J'), "\033[50;*~"},   /* F29 */
  {TERMCAP2KEY('F', 'K'), "\033[51;*~"},   /* F30 */

  {TERMCAP2KEY('F', 'L'), "\033[52;*~"},   /* F31 */
  {TERMCAP2KEY('F', 'M'), "\033[53;*~"},   /* F32 */
  {TERMCAP2KEY('F', 'N'), "\033[54;*~"},   /* F33 */
  {TERMCAP2KEY('F', 'O'), "\033[55;*~"},   /* F34 */
  {TERMCAP2KEY('F', 'P'), "\033[56;*~"},   /* F35 */
  {TERMCAP2KEY('F', 'Q'), "\033[57;*~"},   /* F36 */
  {TERMCAP2KEY('F', 'R'), "\033[58;*~"},   /* F37 */
# endif

# if defined(DEBUG) || defined(ALL_BUILTIN_TCAPS)
  /*
   * for debugging
   */
  {(int)KS_NAME,      "debug"},
  {(int)KS_CE,        "[CE]"},
  {(int)KS_CD,        "[CD]"},
  {(int)KS_AL,        "[AL]"},
  {(int)KS_CAL,       "[CAL%d]"},
  {(int)KS_DL,        "[DL]"},
  {(int)KS_CDL,       "[CDL%d]"},
  {(int)KS_CS,        "[%dCS%d]"},
  {(int)KS_CSV,       "[%dCSV%d]"},
  {(int)KS_CAB,       "[CAB%d]"},
  {(int)KS_CAF,       "[CAF%d]"},
  {(int)KS_CSB,       "[CSB%d]"},
  {(int)KS_CSF,       "[CSF%d]"},
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
  {(int)KS_CM,        "[%dCM%d]"},
  {(int)KS_SR,        "[SR]"},
  {(int)KS_CRI,       "[CRI%d]"},
  {(int)KS_VB,        "[VB]"},
  {(int)KS_KS,        "[KS]"},
  {(int)KS_KE,        "[KE]"},
  {(int)KS_TI,        "[TI]"},
  {(int)KS_TE,        "[TE]"},
  {(int)KS_CIS,       "[CIS]"},
  {(int)KS_CIE,       "[CIE]"},
  {(int)KS_TS,        "[TS]"},
  {(int)KS_FS,        "[FS]"},
  {(int)KS_CWS,       "[%dCWS%d]"},
  {(int)KS_CWP,       "[%dCWP%d]"},
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
  {(int)KS_CM,        "\033[%i%d;%dH"},

  /*
   * end marker
   */
  {(int)KS_NAME,      NULL}

};      /* end of builtin_termcaps */

/*
 * DEFAULT_TERM is used, when no terminal is specified with -T option or $TERM.
 */



#if defined(UNIX)
# define DEFAULT_TERM   (char_u *)"ansi"
#endif





#ifndef DEFAULT_TERM
# define DEFAULT_TERM   (char_u *)"dumb"
#endif

/// Sets up the terminal window for use.
///
/// This must be done after resetting full_screen, otherwise it may move the
/// cursor.
///
/// @remark We may call mch_exit() before calling this.
void term_init(void)
{
  Columns = 80;
  Rows = 24;

  // Prevent buffering output.
  // Output gets explicitly buffered and flushed by out_flush() at times like,
  // for example, when the user presses a key. Without this line, vim will not
  // render the screen correctly.
  setbuf(stdout, NULL);

  out_flush();

#ifdef MACOS_CONVERT
  mac_conv_init();
#endif
}

/*
 * Term_strings contains currently used terminal output strings.
 * It is initialized with the default values by parse_builtin_tcap().
 * The values can be changed by setting the option with the same name.
 */
char_u *(term_strings[(int)KS_LAST + 1]);

static bool need_gather = false;            // need to fill termleader[]

static struct builtin_term *find_builtin_term(char_u *term)
{
  struct builtin_term *p = builtin_termcaps;
  while (p->bt_string != NULL) {
    if (p->bt_entry == (int)KS_NAME) {
#ifdef UNIX
      if (STRCMP(p->bt_string, "xterm") == 0 && vim_is_xterm(term))
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
  char_u name[2];

  struct builtin_term *p = find_builtin_term(term);
  bool term_8bit = term_is_8bit(term);

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
          for (t = s; *t; ++t)
            if (term_7to8bit(t)) {
              *t = term_7to8bit(t);
              STRCPY(t + 1, t + 2);
            }
          term_strings[p->bt_entry] = s;
          set_term_option_alloced(&term_strings[p->bt_entry]);
        } else
          term_strings[p->bt_entry] = (char_u *)p->bt_string;
      }
    } else {
      name[0] = (char_u)KEY2TERMCAP0(p->bt_entry);
      name[1] = (char_u)KEY2TERMCAP1(p->bt_entry);
      if (find_termcode(name) == NULL)
        add_termcode(name, (char_u *)p->bt_string, term_8bit);
    }
  }
}

/*
 * Set terminal options for terminal "term".
 * Return OK if terminal 'term' was found in a termcap, FAIL otherwise.
 *
 * While doing this, until ttest(), some options may be NULL, be careful.
 */
int set_termname(char_u *term)
{
  int width = 0, height = 0;
  char_u      *error_msg = NULL;
  char_u      *bs_p, *del_p;

  /* In silect mode (ex -s) we don't use the 'term' option. */
  if (silent_mode)
    return OK;

  term = (uint8_t *)"abstract_ui";
  detected_8bit = false;                // reset 8-bit detection

  if (term_is_builtin(term)) {
    term += 8;
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
       /*
        * Use builtin termcap
        */
  {
    /*
     * search for 'term' in builtin_termcaps[]
     */
    struct builtin_term *termp = find_builtin_term(term);
    if (termp->bt_string == NULL) {             /* did not find it */

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
          mch_errmsg("    ");
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
        os_delay(2000L, true);
      }
      set_string_option_direct((char_u *)"term", -1, term,
          OPT_FREE, 0);
      display_errors();
    }
    out_flush();
    clear_termoptions();                    /* clear old options */
    parse_builtin_tcap(term);
  }

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

#if defined(UNIX)
  term_is_xterm = vim_is_xterm(term);
#endif

  ttest(TRUE);          /* make sure we have a valid set of terminal codes */

  full_screen = TRUE;           /* we can use termcap codes from now on */
  set_term_defaults();          /* use current values as defaults */

  /*
   * Initialize the terminal with the appropriate termcap codes.
   * Set the mouse and window title if possible.
   * Don't do this when starting, need to parse the .vimrc first, because it
   * may redefine t_TI etc.
   */
  if (starting != NO_SCREEN) {
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
  screen_resize(width, height);  // may change Rows
  if (starting != NO_SCREEN) {
    if (scroll_region)
      scroll_region_reset();                    /* In case Rows changed */
    check_map_keycodes();       /* check mappings for terminal codes used */

    {
      /*
       * Execute the TermChanged autocommands for each buffer that is
       * loaded.
       */
      buf_T *old_curbuf = curbuf;
      for (curbuf = firstbuf; curbuf != NULL; curbuf = curbuf->b_next) {
        if (curbuf->b_ml.ml_mfp != NULL)
          apply_autocmds(EVENT_TERMCHANGED, NULL, NULL, FALSE,
              curbuf);
      }
      if (buf_valid(old_curbuf))
        curbuf = old_curbuf;
    }
  }

  return OK;
}


#  define HMT_NORMAL    1
#  define HMT_NETTERM   2
#  define HMT_DEC       4
#  define HMT_URXVT     16
#  define HMT_SGR       32

void 
set_mouse_termcode (
    char_u n,                  /* KS_MOUSE, KS_NETTERM_MOUSE or KS_DEC_MOUSE */
    char_u *s
)
{
  char_u name[2] = { n, KE_FILLER };

  add_termcode(name, s, FALSE);
}

# if (defined(UNIX) && defined(FEAT_MOUSE_TTY))
void 
del_mouse_termcode (
    char_u n                  /* KS_MOUSE, KS_NETTERM_MOUSE or KS_DEC_MOUSE */
)
{
  char_u name[2] = { n, KE_FILLER };

  del_termcode(name);
}
# endif



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
  }

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

  if (sourcing_name == NULL) {
    EMSG2(_("E436: No \"%s\" entry in termcap"), name);
  }
  return FAIL;
}

static int term_is_builtin(char_u *name)
{
  return STRNCMP(name, "builtin_", (size_t)8) == 0;
}

/*
 * Return true if terminal "name" uses CSI instead of <Esc>[.
 * Assume that the terminal is using 8-bit controls when the name contains
 * "8bit", like in "xterm-8bit".
 */
bool term_is_8bit(char_u *name)
{
  return detected_8bit || strstr((char *)name, "8bit") != NULL;
}

/*
 * Translate terminal control chars from 7-bit to 8-bit:
 * <Esc>[ -> CSI
 * <Esc>] -> <M-C-]>
 * <Esc>O -> <M-C-O>
 */
static char_u term_7to8bit(char_u *p)
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


char_u *tltoa(unsigned long i)
{
  static char_u buf[16];
  char_u *p = buf + 15;
  *p = '\0';
  do {
    --p;
    *p = (char_u) (i % 10 + '0');
    i /= 10;
  } while (i > 0 && p > buf);
  return p;
}

/*
 * Set the terminal name and initialize the terminal options.
 * If "name" is NULL or empty, get the terminal name from the environment.
 * If that fails, use the default terminal name.
 */
void termcapinit(char_u *name)
{
  if (name != NULL && *name == NUL)
    name = NULL;            /* empty name is equal to no name */
  char_u *term = name;

  if (term == NULL)
    term = (char_u *)os_getenv("TERM");
  if (term == NULL || *term == NUL)
    term = DEFAULT_TERM;
  set_string_option_direct((char_u *)"term", -1, term, OPT_FREE, 0);

  /* Set the default terminal name. */
  set_string_default("term", term);
  set_string_default("ttytype", term);

  /*
   * Avoid using "term" here, because the next os_getenv() may overwrite it.
   */
  set_termname(T_NAME != NULL ? T_NAME : term);
}

/*
 * the number of calls to ui_write is reduced by using the buffer "out_buf"
 */
#  define OUT_SIZE      2047
// Add one to allow term_write() in os_win32.c to append a NUL
static char_u out_buf[OUT_SIZE + 1];
static int out_pos = 0;                 /* number of chars in out_buf */

// Clear the output buffer
void out_buf_clear(void)
{
  out_pos = 0;
}

/*
 * out_flush(): flush the output buffer
 */
void out_flush(void)
{
  int len = out_pos;
  out_pos = 0;
  ui_write(out_buf, len);
}

/*
 * Sometimes a byte out of a multi-byte character is written with out_char().
 * To avoid flushing half of the character, call this function first.
 */
void out_flush_check(void)
{
  if (enc_dbcs != 0 && out_pos >= OUT_SIZE - MB_MAXBYTES)
    out_flush();
}

/*
 * out_char(c): put a byte into the output buffer.
 *		Flush it if it becomes full.
 * This should not be used for outputting text on the screen (use functions
 * like msg_puts() and screen_putchar() for that).
 */
void out_char(char_u c)
{
#if defined(UNIX) || defined(MACOS_X_UNIX)
  if (c == '\n')        /* turn LF into CR-LF (CRMOD doesn't seem to do this) */
    out_char('\r');
#endif

  out_buf[out_pos++] = c;

  /* For testing we flush each time. */
  if (out_pos >= OUT_SIZE || p_wd)
    out_flush();
}


/*
 * out_char_nf(c): like out_char(), but don't flush when p_wd is set
 */
static void out_char_nf(char_u c)
{
#if defined(UNIX) || defined(MACOS_X_UNIX)
  if (c == '\n')        /* turn LF into CR-LF (CRMOD doesn't seem to do this) */
    out_char_nf('\r');
#endif

  out_buf[out_pos++] = c;

  if (out_pos >= OUT_SIZE)
    out_flush();
}

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
    while (*s)
      out_char_nf(*s++);

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
  char buf[32];
  snprintf(buf, sizeof(buf), "\033|%d;%dM", row, col);
  OUT_STR(buf);
}

void term_cursor_right(int i)
{
  abort();
}

void term_append_lines(int line_count)
{
  char buf[32];
  snprintf(buf, sizeof(buf), "\033|%dI", line_count);
  OUT_STR(buf);
}

void term_delete_lines(int line_count)
{
  char buf[32];
  snprintf(buf, sizeof(buf), "\033|%dD", line_count);
  OUT_STR(buf);
}

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
  need_gather = true;

  /* Set t_colors to the value of t_Co. */
  t_colors = atoi((char *)T_CCO);
}

/*
 * Check if the new shell size is valid, correct it if it's too small or way
 * too big.
 */
void check_shellsize(void)
{
  if (Rows < min_rows())        /* need room for one window and command line */
    Rows = min_rows();
  limit_screen_size();
}

/*
 * Limit Rows and Columns to avoid an overflow in Rows * Columns.
 */
void limit_screen_size(void)
{
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
void win_new_shellsize(void)
{
  static long old_Rows = 0;
  static long old_Columns = 0;

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
void shell_resized(void)
{
  ui_refresh();
}

/*
 * Check if the shell size changed.  Handle a resize.
 * When the size didn't change, nothing happens.
 */
void shell_resized_check(void)
{
  long old_Rows = Rows;
  long old_Columns = Columns;

  if (!exiting) {
    check_shellsize();
    if (old_Rows != Rows || old_Columns != Columns)
      shell_resized();
  }
}

/*
 * Return TRUE when saving and restoring the screen.
 */
int swapping_screen(void)
{
  return full_screen && *T_TI != NUL;
}

/*
 * By outputting the 'cursor very visible' termcap code, for some windowed
 * terminals this makes the screen scrolled to the correct position.
 * Used when starting Vim or returning from a shell.
 */
void scroll_start(void)
{
  if (*T_VS != NUL) {
    out_str(T_VS);
    out_str(T_VE);
    screen_start();                     /* don't know where cursor is now */
  }
}

/*
 * Enable the cursor.
 */
void cursor_on(void)
{
  ui_cursor_on();
}

/*
 * Disable the cursor.
 */
void cursor_off(void)
{
  ui_cursor_off();
}

/*
 * Set scrolling region for window 'wp'.
 * The region starts 'off' lines from the start of the window.
 * Also set the vertical scroll region for a vertically split window.  Always
 * the full width of the window, excluding the vertical separator.
 */
void scroll_region_set(win_T *wp, int off)
{
  char buf[32];

  snprintf(buf, sizeof(buf), "\033|%d;%dR", wp->w_winrow + wp->w_height - 1,
          wp->w_winrow + off);
  OUT_STR(buf);

  if (wp->w_width != Columns) {
    snprintf(buf, sizeof(buf), "\033|%d;%dV", wp->w_wincol + wp->w_width - 1,
          wp->w_wincol);
    OUT_STR(buf);
  }

  screen_start();                   /* don't know where cursor is now */
}

/*
 * Reset scrolling region to the whole screen.
 */
void scroll_region_reset(void)
{
  char buf[32];

  snprintf(buf, sizeof(buf), "\033|%d;%dR", (int)Rows - 1, 0);
  OUT_STR(buf);
  snprintf(buf, sizeof(buf), "\033|%d;%dV", (int)Columns - 1, 0);
  OUT_STR(buf);

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

static size_t tc_max_len = 0;  /* number of entries that termcodes[] can hold */
static size_t tc_len = 0;      /* current number of entries in termcodes[] */


void clear_termcodes(void)
{
  while (tc_len != 0)
    free(termcodes[--tc_len].code);
  free(termcodes);
  termcodes = NULL;
  tc_max_len = 0;


  need_gather = true;           // need to fill termleader[]
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
  size_t i, j;

  if (string == NULL || *string == NUL) {
    del_termcode(name);
    return;
  }

  char_u *s = vim_strsave(string);

  /* Change leading <Esc>[ to CSI, change <Esc>O to <M-O>. */
  if (flags != 0 && flags != ATC_FROM_TERM && term_7to8bit(string) != 0) {
    STRMOVE(s, s + 1);
    s[0] = term_7to8bit(string);
  }
  size_t len = STRLEN(s);

  need_gather = true;           // need to fill termleader[]

  /*
   * need to make space for more entries
   */
  if (tc_len == tc_max_len) {
    tc_max_len += 20;
    new_tc = xmalloc(tc_max_len * sizeof(struct termcode));
    for (i = 0; i < tc_len; ++i)
      new_tc[i] = termcodes[i];
    free(termcodes);
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
        if (flags == ATC_FROM_TERM
            && (j = termcode_star(termcodes[i].code, termcodes[i].len)) > 0) {
          /* Don't replace ESC[123;*X or ESC O*X with another when
           * invoked from got_code_from_term(). */
          assert(termcodes[i].len >= 0);
          if (len == (size_t)termcodes[i].len - j
              && STRNCMP(s, termcodes[i].code, len - 1) == 0
              && s[len - 1] == termcodes[i].code[termcodes[i].len - 1]) {
            /* They are equal but for the ";*": don't add it. */
            free(s);
            return;
          }
        } else {
          /* Replace old code. */
          free(termcodes[i].code);
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
  assert(len <= INT_MAX);
  termcodes[i].len = (int)len;

  /* For xterm we recognize special codes like "ESC[42;*X" and "ESC O*X" that
   * accept modifiers. */
  termcodes[i].modlen = 0;
  j = termcode_star(s, (int)len);
  if (j > 0)
    termcodes[i].modlen = (int)(len - 1 - j);
  ++tc_len;
}

/*
 * Check termcode "code[len]" for ending in ;*X, <Esc>O*X or <M-O>*X.
 * The "X" can be any character.
 * Return 0 if not found, 2 for ;*X and 1 for O*X and <M-O>*X.
 */
static unsigned int termcode_star(char_u *code, int len)
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
  for (size_t i = 0; i < tc_len; ++i)
    if (termcodes[i].name[0] == name[0] && termcodes[i].name[1] == name[1])
      return termcodes[i].code;
  return NULL;
}

char_u *get_termcode(size_t i)
{
  if (i >= tc_len)
    return NULL;
  return &termcodes[i].name[0];
}

void del_termcode(char_u *name)
{
  if (termcodes == NULL)        /* nothing there yet */
    return;

  need_gather = true;           // need to fill termleader[]

  for (size_t i = 0; i < tc_len; ++i)
    if (termcodes[i].name[0] == name[0] && termcodes[i].name[1] == name[1]) {
      del_termcode_idx(i);
      return;
    }
  /* not found. Give error message? */
}

static void del_termcode_idx(size_t idx)
{
  free(termcodes[idx].code);
  --tc_len;
  for (size_t i = idx; i < tc_len; ++i)
    termcodes[i] = termcodes[i + 1];
}

static linenr_T orig_topline = 0;
static int orig_topfill = 0;

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
  ssize_t i;
  size_t slen;
  char_u key;
  size_t dlen = 0;
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
  result = xmalloc(STRLEN(from) * 6 + 1);

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
          sprintf((char *)result + dlen, "%" PRId64, (int64_t)current_SID);
          dlen += STRLEN(result + dlen);
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
      } else {
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

  *bufp = xrealloc(result, dlen + 1);

  return *bufp;
}

/*
 * Find a termcode with keys 'src' (must be NUL terminated).
 * Return the index in termcodes[], or -1 if not found.
 */
ssize_t find_term_bykeys(char_u *src)
{
  size_t slen = STRLEN(src);

  for (size_t i = 0; i < tc_len; ++i) {
    assert(termcodes[i].len >= 0);
    if (slen == (size_t)termcodes[i].len
        && STRNCMP(termcodes[i].code, src, slen) == 0) {
      assert(i <= SSIZE_MAX);
      return (ssize_t)i;
    }
  }
  return -1;
}

/*
 * Show all termcodes (for ":set termcap")
 * This code looks a lot like showoptions(), but is different.
 */
void show_termcodes(void)
{
#define INC3 27     /* try to make three columns */
#define INC2 40     /* try to make two columns */
#define GAP 2       /* spaces between columns */

  if (tc_len == 0)          /* no terminal codes (must be GUI) */
    return;

  size_t *items = xmalloc(sizeof(size_t) * tc_len);

  /* Highlight title */
  MSG_PUTS_TITLE(_("\n--- Terminal keys ---"));

  /*
   * do the loop two times:
   * 1. display the short items (non-strings and short strings)
   * 2. display the medium items (medium length strings)
   * 3. display the long items (remaining strings)
   */
  for (int run = 1; run <= 3 && !got_int; ++run) {
    /*
     * collect the items in items[]
     */
    size_t item_count = 0;
    for (size_t i = 0; i < tc_len; i++) {
      int len = show_one_termcode(termcodes[i].name,
                                  termcodes[i].code, FALSE);
      if (len <= INC3 - GAP ? run == 1
          : len <= INC2 - GAP ? run == 2
          : run == 3)
        items[item_count++] = i;
    }

    /*
     * display the items
     */
    size_t rows, cols;
    if (run <= 2) {
      cols = (size_t)(Columns + GAP) / (run == 1 ? INC3 : INC2);
      if (cols == 0)
        cols = 1;
      rows = (item_count + cols - 1) / cols;
    } else      /* run == 3 */
      rows = item_count;
    for (size_t row = 0; row < rows && !got_int; ++row) {
      msg_putchar('\n');                        /* go to next line */
      if (got_int)                              /* 'q' typed in more */
        break;
      size_t col = 0;
      for (size_t i = row; i < item_count; i += rows) {
        assert(col <= INT_MAX);
        msg_col = (int)col;                     /* make columns */
        show_one_termcode(termcodes[items[i]].name,
                          termcodes[items[i]].code, TRUE);
        if (run == 2)
          col += INC2;
        else
          col += INC3;
      }
      out_flush();
      os_breakcheck();
    }
  }
  free(items);
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
  } else {
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
  ga_init(&ga, 1, 40);

  int cpo_bslash = (vim_strchr(p_cpo, CPO_BSLASH) != NULL);
  int cpo_special = (vim_strchr(p_cpo, CPO_SPECI) != NULL);
  int cpo_keycode = (vim_strchr(p_cpo, CPO_KEYCODE) == NULL);

  for (; *str; ++str) {
    int c = *str;
    if (c == K_SPECIAL && str[1] != NUL && str[2] != NUL) {
      int modifiers = 0;
      if (str[1] == KS_MODIFIER) {
        str++;
        modifiers = *++str;
        c = *++str;
      }
      if (cpo_special && cpo_keycode && c == K_SPECIAL && !modifiers) {
        /* try to find special key in termcodes */
        size_t i;
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
      ga_append(&ga, (char)c);
  }
  ga_append(&ga, NUL);
  return (char_u *)(ga.ga_data);
}

