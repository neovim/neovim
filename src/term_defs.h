/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

/*
 * This file contains the defines for the machine dependent escape sequences
 * that the editor needs to perform various operations. All of the sequences
 * here are optional, except "cm" (cursor motion).
 */


/*
 * Index of the termcap codes in the term_strings array.
 */
enum SpecialKey {
  KS_NAME = 0,  /* name of this terminal entry */
  KS_CE,        /* clear to end of line */
  KS_AL,        /* add new blank line */
  KS_CAL,       /* add number of blank lines */
  KS_DL,        /* delete line */
  KS_CDL,       /* delete number of lines */
  KS_CS,        /* scroll region */
  KS_CL,        /* clear screen */
  KS_CD,        /* clear to end of display */
  KS_UT,        /* clearing uses current background color */
  KS_DA,        /* text may be scrolled down from up */
  KS_DB,        /* text may be scrolled up from down */
  KS_VI,        /* cursor invisible */
  KS_VE,        /* cursor visible */
  KS_VS,        /* cursor very visible */
  KS_ME,        /* normal mode */
  KS_MR,        /* reverse mode */
  KS_MD,        /* bold mode */
  KS_SE,        /* normal mode */
  KS_SO,        /* standout mode */
  KS_CZH,       /* italic mode start */
  KS_CZR,       /* italic mode end */
  KS_UE,        /* exit underscore (underline) mode */
  KS_US,        /* underscore (underline) mode */
  KS_UCE,       /* exit undercurl mode */
  KS_UCS,       /* undercurl mode */
  KS_MS,        /* save to move cur in reverse mode */
  KS_CM,        /* cursor motion */
  KS_SR,        /* scroll reverse (backward) */
  KS_CRI,       /* cursor number of chars right */
  KS_VB,        /* visual bell */
  KS_KS,        /* put term in "keypad transmit" mode */
  KS_KE,        /* out of "keypad transmit" mode */
  KS_TI,        /* put terminal in termcap mode */
  KS_TE,        /* out of termcap mode */
  KS_BC,        /* backspace character (cursor left) */
  KS_CCS,       /* cur is relative to scroll region */
  KS_CCO,       /* number of colors */
  KS_CSF,       /* set foreground color */
  KS_CSB,       /* set background color */
  KS_XS,        /* standout not erased by overwriting (hpterm) */
  KS_MB,        /* blink mode */
  KS_CAF,       /* set foreground color (ANSI) */
  KS_CAB,       /* set background color (ANSI) */
  KS_LE,        /* cursor left (mostly backspace) */
  KS_ND,        /* cursor right */
  KS_CIS,       /* set icon text start */
  KS_CIE,       /* set icon text end */
  KS_TS,        /* set window title start (to status line)*/
  KS_FS,        /* set window title end (from status line) */
  KS_CWP,       /* set window position in pixels */
  KS_CWS,       /* set window size in characters */
  KS_CRV,       /* request version string */
  KS_CSI,       /* start insert mode (bar cursor) */
  KS_CEI,       /* end insert mode (block cursor) */
  KS_CSV,       /* scroll region vertical */
  KS_OP,        /* original color pair */
  KS_U7         /* request cursor position */
};

#define KS_LAST     KS_U7

/*
 * the terminal capabilities are stored in this array
 * IMPORTANT: When making changes, note the following:
 * - there should be an entry for each code in the builtin termcaps
 * - there should be an option for each code in option.c
 * - there should be code in term.c to obtain the value from the termcap
 */

extern char_u *(term_strings[]);    /* current terminal strings */

/*
 * strings used for terminal
 */
#define T_NAME  (term_str(KS_NAME))     /* terminal name */
#define T_CE    (term_str(KS_CE))       /* clear to end of line */
#define T_AL    (term_str(KS_AL))       /* add new blank line */
#define T_CAL   (term_str(KS_CAL))      /* add number of blank lines */
#define T_DL    (term_str(KS_DL))       /* delete line */
#define T_CDL   (term_str(KS_CDL))      /* delete number of lines */
#define T_CS    (term_str(KS_CS))       /* scroll region */
#define T_CSV   (term_str(KS_CSV))      /* scroll region vertical */
#define T_CL    (term_str(KS_CL))       /* clear screen */
#define T_CD    (term_str(KS_CD))       /* clear to end of display */
#define T_UT    (term_str(KS_UT))       /* clearing uses background color */
#define T_DA    (term_str(KS_DA))       /* text may be scrolled down from up */
#define T_DB    (term_str(KS_DB))       /* text may be scrolled up from down */
#define T_VI    (term_str(KS_VI))       /* cursor invisible */
#define T_VE    (term_str(KS_VE))       /* cursor visible */
#define T_VS    (term_str(KS_VS))       /* cursor very visible */
#define T_ME    (term_str(KS_ME))       /* normal mode */
#define T_MR    (term_str(KS_MR))       /* reverse mode */
#define T_MD    (term_str(KS_MD))       /* bold mode */
#define T_SE    (term_str(KS_SE))       /* normal mode */
#define T_SO    (term_str(KS_SO))       /* standout mode */
#define T_CZH   (term_str(KS_CZH))      /* italic mode start */
#define T_CZR   (term_str(KS_CZR))      /* italic mode end */
#define T_UE    (term_str(KS_UE))       /* exit underscore (underline) mode */
#define T_US    (term_str(KS_US))       /* underscore (underline) mode */
#define T_UCE   (term_str(KS_UCE))      /* exit undercurl mode */
#define T_UCS   (term_str(KS_UCS))      /* undercurl mode */
#define T_MS    (term_str(KS_MS))       /* save to move cur in reverse mode */
#define T_CM    (term_str(KS_CM))       /* cursor motion */
#define T_SR    (term_str(KS_SR))       /* scroll reverse (backward) */
#define T_CRI   (term_str(KS_CRI))      /* cursor number of chars right */
#define T_VB    (term_str(KS_VB))       /* visual bell */
#define T_KS    (term_str(KS_KS))       /* put term in "keypad transmit" mode */
#define T_KE    (term_str(KS_KE))       /* out of "keypad transmit" mode */
#define T_TI    (term_str(KS_TI))       /* put terminal in termcap mode */
#define T_TE    (term_str(KS_TE))       /* out of termcap mode */
#define T_BC    (term_str(KS_BC))       /* backspace character */
#define T_CCS   (term_str(KS_CCS))      /* cur is relative to scroll region */
#define T_CCO   (term_str(KS_CCO))      /* number of colors */
#define T_CSF   (term_str(KS_CSF))      /* set foreground color */
#define T_CSB   (term_str(KS_CSB))      /* set background color */
#define T_XS    (term_str(KS_XS))       /* standout not erased by overwriting */
#define T_MB    (term_str(KS_MB))       /* blink mode */
#define T_CAF   (term_str(KS_CAF))      /* set foreground color (ANSI) */
#define T_CAB   (term_str(KS_CAB))      /* set background color (ANSI) */
#define T_LE    (term_str(KS_LE))       /* cursor left */
#define T_ND    (term_str(KS_ND))       /* cursor right */
#define T_CIS   (term_str(KS_CIS))      /* set icon text start */
#define T_CIE   (term_str(KS_CIE))      /* set icon text end */
#define T_TS    (term_str(KS_TS))       /* set window title start */
#define T_FS    (term_str(KS_FS))       /* set window title end */
#define T_CWP   (term_str(KS_CWP))      /* window position */
#define T_CWS   (term_str(KS_CWS))      /* window size */
#define T_CSI   (term_str(KS_CSI))      /* start insert mode */
#define T_CEI   (term_str(KS_CEI))      /* end insert mode */
#define T_CRV   (term_str(KS_CRV))      /* request version string */
#define T_OP    (term_str(KS_OP))       /* original color pair */
#define T_U7    (term_str(KS_U7))       /* request cursor position */

#define TMODE_COOK  0   /* terminal mode for external cmds and Ex mode */
#define TMODE_SLEEP 1   /* terminal mode for sleeping (cooked but no echo) */
#define TMODE_RAW   2   /* terminal mode for Normal and Insert mode */
