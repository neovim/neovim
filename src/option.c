/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * Code to handle user-settable options. This is all pretty much table-
 * driven. Checklist for adding a new option:
 * - Put it in the options array below (copy an existing entry).
 * - For a global option: Add a variable for it in option_defs.h.
 * - For a buffer or window local option:
 *   - Add a PV_XX entry to the enum below.
 *   - Add a variable to the window or buffer struct in structs.h.
 *   - For a window option, add some code to copy_winopt().
 *   - For a buffer option, add some code to buf_copy_options().
 *   - For a buffer string option, add code to check_buf_options().
 * - If it's a numeric option, add any necessary bounds checks to do_set().
 * - If it's a list of flags, add some code in do_set(), search for WW_ALL.
 * - When adding an option with expansion (P_EXPAND), but with a different
 *   default for Vi and Vim (no P_VI_DEF), add some code at VIMEXP.
 * - Add documentation!  One line in doc/help.txt, full description in
 *   options.txt, and any other related places.
 * - Add an entry in runtime/optwin.vim.
 * When making changes:
 * - Adjust the help for the option in doc/option.txt.
 * - When an entry has the P_VIM flag, or is lacking the P_VI_DEF flag, add a
 *   comment at the help for the 'compatible' option.
 */

#define IN_OPTION_C
#include "vim.h"
#include "option.h"
#include "blowfish.h"
#include "buffer.h"
#include "charset.h"
#include "diff.h"
#include "digraph.h"
#include "eval.h"
#include "ex_cmds2.h"
#include "ex_docmd.h"
#include "ex_getln.h"
#include "fileio.h"
#include "fold.h"
#include "getchar.h"
#include "hardcopy.h"
#include "mbyte.h"
#include "memfile.h"
#include "memline.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"
#include "garray.h"
#include "move.h"
#include "normal.h"
#include "os_unix.h"
#include "regexp.h"
#include "screen.h"
#include "spell.h"
#include "syntax.h"
#include "term.h"
#include "ui.h"
#include "undo.h"
#include "window.h"

/*
 * The options that are local to a window or buffer have "indir" set to one of
 * these values.  Special values:
 * PV_NONE: global option.
 * PV_WIN is added: window-local option
 * PV_BUF is added: buffer-local option
 * PV_BOTH is added: global option which also has a local value.
 */
#define PV_BOTH 0x1000
#define PV_WIN  0x2000
#define PV_BUF  0x4000
#define PV_MASK 0x0fff
#define OPT_WIN(x)  (idopt_T)(PV_WIN + (int)(x))
#define OPT_BUF(x)  (idopt_T)(PV_BUF + (int)(x))
#define OPT_BOTH(x) (idopt_T)(PV_BOTH + (int)(x))

/*
 * Definition of the PV_ values for buffer-local options.
 * The BV_ values are defined in option_defs.h.
 */
#define PV_AI           OPT_BUF(BV_AI)
#define PV_AR           OPT_BOTH(OPT_BUF(BV_AR))
# define PV_BH          OPT_BUF(BV_BH)
# define PV_BT          OPT_BUF(BV_BT)
# define PV_EFM         OPT_BOTH(OPT_BUF(BV_EFM))
# define PV_GP          OPT_BOTH(OPT_BUF(BV_GP))
# define PV_MP          OPT_BOTH(OPT_BUF(BV_MP))
#define PV_BIN          OPT_BUF(BV_BIN)
#define PV_BL           OPT_BUF(BV_BL)
# define PV_BOMB        OPT_BUF(BV_BOMB)
#define PV_CI           OPT_BUF(BV_CI)
# define PV_CIN         OPT_BUF(BV_CIN)
# define PV_CINK        OPT_BUF(BV_CINK)
# define PV_CINO        OPT_BUF(BV_CINO)
# define PV_CINW        OPT_BUF(BV_CINW)
#define PV_CM           OPT_BOTH(OPT_BUF(BV_CM))
# define PV_CMS         OPT_BUF(BV_CMS)
# define PV_COM         OPT_BUF(BV_COM)
# define PV_CPT         OPT_BUF(BV_CPT)
# define PV_DICT        OPT_BOTH(OPT_BUF(BV_DICT))
# define PV_TSR         OPT_BOTH(OPT_BUF(BV_TSR))
# define PV_CFU         OPT_BUF(BV_CFU)
# define PV_DEF         OPT_BOTH(OPT_BUF(BV_DEF))
# define PV_INC         OPT_BOTH(OPT_BUF(BV_INC))
#define PV_EOL          OPT_BUF(BV_EOL)
#define PV_EP           OPT_BOTH(OPT_BUF(BV_EP))
#define PV_ET           OPT_BUF(BV_ET)
# define PV_FENC        OPT_BUF(BV_FENC)
# define PV_FEX         OPT_BUF(BV_FEX)
#define PV_FF           OPT_BUF(BV_FF)
#define PV_FLP          OPT_BUF(BV_FLP)
#define PV_FO           OPT_BUF(BV_FO)
# define PV_FT          OPT_BUF(BV_FT)
#define PV_IMI          OPT_BUF(BV_IMI)
#define PV_IMS          OPT_BUF(BV_IMS)
# define PV_INDE        OPT_BUF(BV_INDE)
# define PV_INDK        OPT_BUF(BV_INDK)
# define PV_INEX        OPT_BUF(BV_INEX)
#define PV_INF          OPT_BUF(BV_INF)
#define PV_ISK          OPT_BUF(BV_ISK)
# define PV_KEY         OPT_BUF(BV_KEY)
# define PV_KMAP        OPT_BUF(BV_KMAP)
#define PV_KP           OPT_BOTH(OPT_BUF(BV_KP))
# define PV_LISP        OPT_BUF(BV_LISP)
#define PV_MA           OPT_BUF(BV_MA)
#define PV_ML           OPT_BUF(BV_ML)
#define PV_MOD          OPT_BUF(BV_MOD)
#define PV_MPS          OPT_BUF(BV_MPS)
#define PV_NF           OPT_BUF(BV_NF)
# define PV_OFU         OPT_BUF(BV_OFU)
#define PV_PATH         OPT_BOTH(OPT_BUF(BV_PATH))
#define PV_PI           OPT_BUF(BV_PI)
# define PV_QE          OPT_BUF(BV_QE)
#define PV_RO           OPT_BUF(BV_RO)
# define PV_SI          OPT_BUF(BV_SI)
#ifndef SHORT_FNAME
# define PV_SN          OPT_BUF(BV_SN)
#endif
# define PV_SMC         OPT_BUF(BV_SMC)
# define PV_SYN         OPT_BUF(BV_SYN)
# define PV_SPC         OPT_BUF(BV_SPC)
# define PV_SPF         OPT_BUF(BV_SPF)
# define PV_SPL         OPT_BUF(BV_SPL)
#define PV_STS          OPT_BUF(BV_STS)
# define PV_SUA         OPT_BUF(BV_SUA)
#define PV_SW           OPT_BUF(BV_SW)
#define PV_SWF          OPT_BUF(BV_SWF)
#define PV_TAGS         OPT_BOTH(OPT_BUF(BV_TAGS))
#define PV_TS           OPT_BUF(BV_TS)
#define PV_TW           OPT_BUF(BV_TW)
#define PV_TX           OPT_BUF(BV_TX)
# define PV_UDF         OPT_BUF(BV_UDF)
#define PV_WM           OPT_BUF(BV_WM)

/*
 * Definition of the PV_ values for window-local options.
 * The WV_ values are defined in option_defs.h.
 */
#define PV_LIST         OPT_WIN(WV_LIST)
# define PV_ARAB        OPT_WIN(WV_ARAB)
# define PV_DIFF        OPT_WIN(WV_DIFF)
# define PV_FDC         OPT_WIN(WV_FDC)
# define PV_FEN         OPT_WIN(WV_FEN)
# define PV_FDI         OPT_WIN(WV_FDI)
# define PV_FDL         OPT_WIN(WV_FDL)
# define PV_FDM         OPT_WIN(WV_FDM)
# define PV_FML         OPT_WIN(WV_FML)
# define PV_FDN         OPT_WIN(WV_FDN)
#  define PV_FDE        OPT_WIN(WV_FDE)
#  define PV_FDT        OPT_WIN(WV_FDT)
# define PV_FMR         OPT_WIN(WV_FMR)
# define PV_LBR         OPT_WIN(WV_LBR)
#define PV_NU           OPT_WIN(WV_NU)
#define PV_RNU          OPT_WIN(WV_RNU)
# define PV_NUW         OPT_WIN(WV_NUW)
# define PV_PVW         OPT_WIN(WV_PVW)
# define PV_RL          OPT_WIN(WV_RL)
# define PV_RLC         OPT_WIN(WV_RLC)
# define PV_SCBIND      OPT_WIN(WV_SCBIND)
#define PV_SCROLL       OPT_WIN(WV_SCROLL)
# define PV_SPELL       OPT_WIN(WV_SPELL)
# define PV_CUC         OPT_WIN(WV_CUC)
# define PV_CUL         OPT_WIN(WV_CUL)
# define PV_CC          OPT_WIN(WV_CC)
# define PV_STL         OPT_BOTH(OPT_WIN(WV_STL))
#define PV_UL           OPT_BOTH(OPT_BUF(BV_UL))
# define PV_WFH         OPT_WIN(WV_WFH)
# define PV_WFW         OPT_WIN(WV_WFW)
#define PV_WRAP         OPT_WIN(WV_WRAP)
# define PV_CRBIND      OPT_WIN(WV_CRBIND)
# define PV_COCU        OPT_WIN(WV_COCU)
# define PV_COLE        OPT_WIN(WV_COLE)

/* WV_ and BV_ values get typecasted to this for the "indir" field */
typedef enum {
  PV_NONE = 0,
  PV_MAXVAL = 0xffff      /* to avoid warnings for value out of range */
} idopt_T;

/*
 * Options local to a window have a value local to a buffer and global to all
 * buffers.  Indicate this by setting "var" to VAR_WIN.
 */
#define VAR_WIN ((char_u *)-1)

/*
 * These are the global values for options which are also local to a buffer.
 * Only to be used in option.c!
 */
static int p_ai;
static int p_bin;
static int p_bomb;
static char_u   *p_bh;
static char_u   *p_bt;
static int p_bl;
static int p_ci;
static int p_cin;
static char_u   *p_cink;
static char_u   *p_cino;
static char_u   *p_cinw;
static char_u   *p_com;
static char_u   *p_cms;
static char_u   *p_cpt;
static char_u   *p_cfu;
static char_u   *p_ofu;
static int p_eol;
static int p_et;
static char_u   *p_fenc;
static char_u   *p_ff;
static char_u   *p_fo;
static char_u   *p_flp;
static char_u   *p_ft;
static long p_iminsert;
static long p_imsearch;
static char_u   *p_inex;
static char_u   *p_inde;
static char_u   *p_indk;
static char_u   *p_fex;
static int p_inf;
static char_u   *p_isk;
static char_u   *p_key;
static int p_lisp;
static int p_ml;
static int p_ma;
static int p_mod;
static char_u   *p_mps;
static char_u   *p_nf;
static int p_pi;
static char_u   *p_qe;
static int p_ro;
static int p_si;
#ifndef SHORT_FNAME
static int p_sn;
#endif
static long p_sts;
static char_u   *p_sua;
static long p_sw;
static int p_swf;
static long p_smc;
static char_u   *p_syn;
static char_u   *p_spc;
static char_u   *p_spf;
static char_u   *p_spl;
static long p_ts;
static long p_tw;
static int p_tx;
static int p_udf;
static long p_wm;
static char_u   *p_keymap;

/* Saved values for when 'bin' is set. */
static int p_et_nobin;
static int p_ml_nobin;
static long p_tw_nobin;
static long p_wm_nobin;

/* Saved values for when 'paste' is set */
static long p_tw_nopaste;
static long p_wm_nopaste;
static long p_sts_nopaste;
static int p_ai_nopaste;

struct vimoption {
  char        *fullname;        /* full option name */
  char        *shortname;       /* permissible abbreviation */
  long_u flags;                 /* see below */
  char_u      *var;             /* global option: pointer to variable;
                                * window-local option: VAR_WIN;
                                * buffer-local option: global value */
  idopt_T indir;                /* global option: PV_NONE;
                                 * local option: indirect option index */
  char_u      *def_val[2];      /* default values for variable (vi and vim) */
  scid_T scriptID;              /* script in which the option was last set */
# define SCRIPTID_INIT , 0
};

#define VI_DEFAULT  0       /* def_val[VI_DEFAULT] is Vi default value */
#define VIM_DEFAULT 1       /* def_val[VIM_DEFAULT] is Vim default value */

/*
 * Flags
 */
#define P_BOOL          0x01    /* the option is boolean */
#define P_NUM           0x02    /* the option is numeric */
#define P_STRING        0x04    /* the option is a string */
#define P_ALLOCED       0x08    /* the string option is in allocated memory,
                                   must use free_string_option() when
                                   assigning new value. Not set if default is
                                   the same. */
#define P_EXPAND        0x10    /* environment expansion.  NOTE: P_EXPAND can
                                   never be used for local or hidden options! */
#define P_NODEFAULT     0x40    /* don't set to default value */
#define P_DEF_ALLOCED   0x80    /* default value is in allocated memory, must
                                    use vim_free() when assigning new value */
#define P_WAS_SET       0x100   /* option has been set/reset */
#define P_NO_MKRC       0x200   /* don't include in :mkvimrc output */
#define P_VI_DEF        0x400   /* Use Vi default for Vim */
#define P_VIM           0x800   /* Vim option, reset when 'cp' set */

/* when option changed, what to display: */
#define P_RSTAT         0x1000  /* redraw status lines */
#define P_RWIN          0x2000  /* redraw current window */
#define P_RBUF          0x4000  /* redraw current buffer */
#define P_RALL          0x6000  /* redraw all windows */
#define P_RCLR          0x7000  /* clear and redraw all */

#define P_COMMA         0x8000  /* comma separated list */
#define P_NODUP         0x10000L /* don't allow duplicate strings */
#define P_FLAGLIST      0x20000L /* list of single-char flags */

#define P_SECURE        0x40000L /* cannot change in modeline or secure mode */
#define P_GETTEXT       0x80000L /* expand default value with _() */
#define P_NOGLOB       0x100000L /* do not use local value for global vimrc */
#define P_NFNAME       0x200000L /* only normal file name chars allowed */
#define P_INSECURE     0x400000L /* option was set from a modeline */
#define P_PRI_MKRC     0x800000L /* priority for :mkvimrc (setting option has
                                    side effects) */
#define P_NO_ML       0x1000000L /* not allowed in modeline */
#define P_CURSWANT    0x2000000L /* update curswant required; not needed when
                                  * there is a redraw flag */

#define ISK_LATIN1  (char_u *)"@,48-57,_,192-255"

/* 'isprint' for latin1 is also used for MS-Windows cp1252, where 0x80 is used
 * for the currency sign. */
# define ISP_LATIN1 (char_u *)"@,161-255"

/* The 16 bit MS-DOS version is low on space, make the string as short as
 * possible when compiling with few features. */
#if defined(FEAT_DIFF) || defined(FEAT_FOLDING) || defined(FEAT_SPELL) \
  || defined(FEAT_VERTSPLIT) || defined(FEAT_CLIPBOARD) \
  || defined(FEAT_INS_EXPAND) || defined(FEAT_SYN_HL) || defined(FEAT_CONCEAL)
# define HIGHLIGHT_INIT \
  "8:SpecialKey,@:NonText,d:Directory,e:ErrorMsg,i:IncSearch,l:Search,m:MoreMsg,M:ModeMsg,n:LineNr,N:CursorLineNr,r:Question,s:StatusLine,S:StatusLineNC,c:VertSplit,t:Title,v:Visual,V:VisualNOS,w:WarningMsg,W:WildMenu,f:Folded,F:FoldColumn,A:DiffAdd,C:DiffChange,D:DiffDelete,T:DiffText,>:SignColumn,-:Conceal,B:SpellBad,P:SpellCap,R:SpellRare,L:SpellLocal,+:Pmenu,=:PmenuSel,x:PmenuSbar,X:PmenuThumb,*:TabLine,#:TabLineSel,_:TabLineFill,!:CursorColumn,.:CursorLine,o:ColorColumn"
#else
# define HIGHLIGHT_INIT \
  "8:SpecialKey,@:NonText,d:Directory,e:ErrorMsg,i:IncSearch,l:Search,m:MoreMsg,M:ModeMsg,n:LineNr,N:CursorLineNr,r:Question,s:StatusLine,S:StatusLineNC,t:Title,v:Visual,w:WarningMsg,W:WildMenu,>:SignColumn,*:TabLine,#:TabLineSel,_:TabLineFill"
#endif

/*
 * options[] is initialized here.
 * The order of the options MUST be alphabetic for ":set all" and findoption().
 * All option names MUST start with a lowercase letter (for findoption()).
 * Exception: "t_" options are at the end.
 * The options with a NULL variable are 'hidden': a set command for them is
 * ignored and they are not printed.
 */
static struct vimoption
  options[] =
{
  {"aleph",       "al",   P_NUM|P_VI_DEF|P_CURSWANT,
   (char_u *)&p_aleph, PV_NONE,
   {
     (char_u *)224L,
     (char_u *)0L
   } SCRIPTID_INIT},
  {"antialias",   "anti", P_BOOL|P_VI_DEF|P_VIM|P_RCLR,
   (char_u *)NULL, PV_NONE,
   {(char_u *)FALSE, (char_u *)FALSE}
   SCRIPTID_INIT},
  {"arabic",      "arab", P_BOOL|P_VI_DEF|P_VIM|P_CURSWANT,
   (char_u *)VAR_WIN, PV_ARAB,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"arabicshape", "arshape", P_BOOL|P_VI_DEF|P_VIM|P_RCLR,
   (char_u *)&p_arshape, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"allowrevins", "ari",  P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_ari, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"altkeymap",   "akm",  P_BOOL|P_VI_DEF,
   (char_u *)&p_altkeymap, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"ambiwidth",  "ambw",  P_STRING|P_VI_DEF|P_RCLR,
   (char_u *)&p_ambw, PV_NONE,
   {(char_u *)"single", (char_u *)0L}
   SCRIPTID_INIT},
  {"autochdir",  "acd",   P_BOOL|P_VI_DEF,
   (char_u *)&p_acd, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"autoindent",  "ai",   P_BOOL|P_VI_DEF,
   (char_u *)&p_ai, PV_AI,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"autoprint",   "ap",   P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"autoread",    "ar",   P_BOOL|P_VI_DEF,
   (char_u *)&p_ar, PV_AR,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"autowrite",   "aw",   P_BOOL|P_VI_DEF,
   (char_u *)&p_aw, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"autowriteall","awa",  P_BOOL|P_VI_DEF,
   (char_u *)&p_awa, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"background",  "bg",   P_STRING|P_VI_DEF|P_RCLR,
   (char_u *)&p_bg, PV_NONE,
   {
     (char_u *)"light",
     (char_u *)0L
   } SCRIPTID_INIT},
  {"backspace",   "bs",   P_STRING|P_VI_DEF|P_VIM|P_COMMA|P_NODUP,
   (char_u *)&p_bs, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"backup",      "bk",   P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_bk, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"backupcopy",  "bkc",  P_STRING|P_VIM|P_COMMA|P_NODUP,
   (char_u *)&p_bkc, PV_NONE,
#ifdef UNIX
   {(char_u *)"yes", (char_u *)"auto"}
#else
   {(char_u *)"auto", (char_u *)"auto"}
#endif
   SCRIPTID_INIT},
  {"backupdir",   "bdir", P_STRING|P_EXPAND|P_VI_DEF|P_COMMA|P_NODUP|P_SECURE,
   (char_u *)&p_bdir, PV_NONE,
   {(char_u *)DFLT_BDIR, (char_u *)0L} SCRIPTID_INIT},
  {"backupext",   "bex",  P_STRING|P_VI_DEF|P_NFNAME,
   (char_u *)&p_bex, PV_NONE,
   {
     (char_u *)"~",
     (char_u *)0L
   } SCRIPTID_INIT},
  {"backupskip",  "bsk",  P_STRING|P_VI_DEF|P_COMMA,
   (char_u *)&p_bsk, PV_NONE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"beautify",    "bf",   P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"binary",      "bin",  P_BOOL|P_VI_DEF|P_RSTAT,
   (char_u *)&p_bin, PV_BIN,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"bioskey",     "biosk",P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"bomb",        NULL,   P_BOOL|P_NO_MKRC|P_VI_DEF|P_RSTAT,
   (char_u *)&p_bomb, PV_BOMB,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"breakat",     "brk",  P_STRING|P_VI_DEF|P_RALL|P_FLAGLIST,
   (char_u *)&p_breakat, PV_NONE,
   {(char_u *)" \t!@*-+;:,./?", (char_u *)0L}
   SCRIPTID_INIT},
  {"browsedir",   "bsdir",P_STRING|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)0L, (char_u *)0L}
   SCRIPTID_INIT},
  {"bufhidden",   "bh",   P_STRING|P_ALLOCED|P_VI_DEF|P_NOGLOB,
   (char_u *)&p_bh, PV_BH,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"buflisted",   "bl",   P_BOOL|P_VI_DEF|P_NOGLOB,
   (char_u *)&p_bl, PV_BL,
   {(char_u *)1L, (char_u *)0L}
   SCRIPTID_INIT},
  {"buftype",     "bt",   P_STRING|P_ALLOCED|P_VI_DEF|P_NOGLOB,
   (char_u *)&p_bt, PV_BT,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"casemap",     "cmp",   P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_cmp, PV_NONE,
   {(char_u *)"internal,keepascii", (char_u *)0L}
   SCRIPTID_INIT},
  {"cdpath",      "cd",   P_STRING|P_EXPAND|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_cdpath, PV_NONE,
   {(char_u *)",,", (char_u *)0L}
   SCRIPTID_INIT},
  {"cedit",       NULL,   P_STRING,
   (char_u *)&p_cedit, PV_NONE,
   {(char_u *)"", (char_u *)CTRL_F_STR}
   SCRIPTID_INIT},
  {"charconvert",  "ccv", P_STRING|P_VI_DEF|P_SECURE,
   (char_u *)&p_ccv, PV_NONE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"cindent",     "cin",  P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_cin, PV_CIN,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"cinkeys",     "cink", P_STRING|P_ALLOCED|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_cink, PV_CINK,
   {(char_u *)"0{,0},0),:,0#,!^F,o,O,e", (char_u *)0L}
   SCRIPTID_INIT},
  {"cinoptions",  "cino", P_STRING|P_ALLOCED|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_cino, PV_CINO,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"cinwords",    "cinw", P_STRING|P_ALLOCED|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_cinw, PV_CINW,
   {(char_u *)"if,else,while,do,for,switch",
    (char_u *)0L}
   SCRIPTID_INIT},
  {"clipboard",   "cb",   P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)NULL, PV_NONE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"cmdheight",   "ch",   P_NUM|P_VI_DEF|P_RALL,
   (char_u *)&p_ch, PV_NONE,
   {(char_u *)1L, (char_u *)0L} SCRIPTID_INIT},
  {"cmdwinheight", "cwh", P_NUM|P_VI_DEF,
   (char_u *)&p_cwh, PV_NONE,
   {(char_u *)7L, (char_u *)0L} SCRIPTID_INIT},
  {"colorcolumn", "cc",   P_STRING|P_VI_DEF|P_COMMA|P_NODUP|P_RWIN,
   (char_u *)VAR_WIN, PV_CC,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"columns",     "co",   P_NUM|P_NODEFAULT|P_NO_MKRC|P_VI_DEF|P_RCLR,
   (char_u *)&Columns, PV_NONE,
   {(char_u *)80L, (char_u *)0L} SCRIPTID_INIT},
  {"comments",    "com",  P_STRING|P_ALLOCED|P_VI_DEF|P_COMMA|P_NODUP|
   P_CURSWANT,
   (char_u *)&p_com, PV_COM,
   {(char_u *)"s1:/*,mb:*,ex:*/,://,b:#,:%,:XCOMM,n:>,fb:-",
    (char_u *)0L}
   SCRIPTID_INIT},
  {"commentstring", "cms", P_STRING|P_ALLOCED|P_VI_DEF|P_CURSWANT,
   (char_u *)&p_cms, PV_CMS,
   {(char_u *)"/*%s*/", (char_u *)0L}
   SCRIPTID_INIT},
  /* P_PRI_MKRC isn't needed here, optval_default()
   * always returns TRUE for 'compatible' */
  {"compatible",  "cp",   P_BOOL|P_RALL,
   (char_u *)&p_cp, PV_NONE,
   {(char_u *)TRUE, (char_u *)FALSE} SCRIPTID_INIT},
  {"complete",    "cpt",  P_STRING|P_ALLOCED|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_cpt, PV_CPT,
   {(char_u *)".,w,b,u,t,i", (char_u *)0L}
   SCRIPTID_INIT},
  {"concealcursor","cocu", P_STRING|P_ALLOCED|P_RWIN|P_VI_DEF,
   (char_u *)VAR_WIN, PV_COCU,
   {(char_u *)"", (char_u *)NULL}
   SCRIPTID_INIT},
  {"conceallevel","cole", P_NUM|P_RWIN|P_VI_DEF,
   (char_u *)VAR_WIN, PV_COLE,
   {(char_u *)0L, (char_u *)0L}
   SCRIPTID_INIT},
  {"completefunc", "cfu", P_STRING|P_ALLOCED|P_VI_DEF|P_SECURE,
   (char_u *)&p_cfu, PV_CFU,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"completeopt",   "cot",  P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_cot, PV_NONE,
   {(char_u *)"menu,preview", (char_u *)0L}
   SCRIPTID_INIT},
  {"confirm",     "cf",   P_BOOL|P_VI_DEF,
   (char_u *)&p_confirm, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"conskey",     "consk",P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"copyindent",  "ci",   P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_ci, PV_CI,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"cpoptions",   "cpo",  P_STRING|P_VIM|P_RALL|P_FLAGLIST,
   (char_u *)&p_cpo, PV_NONE,
   {(char_u *)CPO_VI, (char_u *)CPO_VIM}
   SCRIPTID_INIT},
  {"cryptmethod", "cm",   P_STRING|P_ALLOCED|P_VI_DEF,
   (char_u *)&p_cm, PV_CM,
   {(char_u *)"zip", (char_u *)0L}
   SCRIPTID_INIT},
  {"cscopepathcomp", "cspc", P_NUM|P_VI_DEF|P_VIM,
   (char_u *)&p_cspc, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"cscopeprg",   "csprg", P_STRING|P_EXPAND|P_VI_DEF|P_SECURE,
   (char_u *)&p_csprg, PV_NONE,
   {(char_u *)"cscope", (char_u *)0L}
   SCRIPTID_INIT},
  {"cscopequickfix", "csqf", P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_csqf, PV_NONE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"cscoperelative", "csre", P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_csre, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"cscopetag",   "cst",  P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_cst, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"cscopetagorder", "csto", P_NUM|P_VI_DEF|P_VIM,
   (char_u *)&p_csto, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"cscopeverbose", "csverb", P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_csverbose, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"cursorbind",  "crb",  P_BOOL|P_VI_DEF,
   (char_u *)VAR_WIN, PV_CRBIND,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"cursorcolumn", "cuc", P_BOOL|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_CUC,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"cursorline",   "cul", P_BOOL|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_CUL,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"debug",       NULL,   P_STRING|P_VI_DEF,
   (char_u *)&p_debug, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"define",      "def",  P_STRING|P_ALLOCED|P_VI_DEF|P_CURSWANT,
   (char_u *)&p_def, PV_DEF,
   {(char_u *)"^\\s*#\\s*define", (char_u *)0L}
   SCRIPTID_INIT},
  {"delcombine", "deco",  P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_deco, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"dictionary",  "dict", P_STRING|P_EXPAND|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_dict, PV_DICT,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"diff",        NULL,   P_BOOL|P_VI_DEF|P_RWIN|P_NOGLOB,
   (char_u *)VAR_WIN, PV_DIFF,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"diffexpr",    "dex",  P_STRING|P_VI_DEF|P_SECURE|P_CURSWANT,
   (char_u *)&p_dex, PV_NONE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"diffopt",     "dip",  P_STRING|P_ALLOCED|P_VI_DEF|P_RWIN|P_COMMA|P_NODUP,
   (char_u *)&p_dip, PV_NONE,
   {(char_u *)"filler", (char_u *)NULL}
   SCRIPTID_INIT},
  {"digraph",     "dg",   P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_dg, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"directory",   "dir",  P_STRING|P_EXPAND|P_VI_DEF|P_COMMA|P_NODUP|P_SECURE,
   (char_u *)&p_dir, PV_NONE,
   {(char_u *)DFLT_DIR, (char_u *)0L} SCRIPTID_INIT},
  {"display",     "dy",   P_STRING|P_VI_DEF|P_COMMA|P_RALL|P_NODUP,
   (char_u *)&p_dy, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"eadirection", "ead",  P_STRING|P_VI_DEF,
   (char_u *)&p_ead, PV_NONE,
   {(char_u *)"both", (char_u *)0L}
   SCRIPTID_INIT},
  {"edcompatible","ed",   P_BOOL|P_VI_DEF,
   (char_u *)&p_ed, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"encoding",    "enc",  P_STRING|P_VI_DEF|P_RCLR|P_NO_ML,
   (char_u *)&p_enc, PV_NONE,
   {(char_u *)ENC_DFLT, (char_u *)0L}
   SCRIPTID_INIT},
  {"endofline",   "eol",  P_BOOL|P_NO_MKRC|P_VI_DEF|P_RSTAT,
   (char_u *)&p_eol, PV_EOL,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"equalalways", "ea",   P_BOOL|P_VI_DEF|P_RALL,
   (char_u *)&p_ea, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"equalprg",    "ep",   P_STRING|P_EXPAND|P_VI_DEF|P_SECURE,
   (char_u *)&p_ep, PV_EP,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"errorbells",  "eb",   P_BOOL|P_VI_DEF,
   (char_u *)&p_eb, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"errorfile",   "ef",   P_STRING|P_EXPAND|P_VI_DEF|P_SECURE,
   (char_u *)&p_ef, PV_NONE,
   {(char_u *)DFLT_ERRORFILE, (char_u *)0L}
   SCRIPTID_INIT},
  {"errorformat", "efm",  P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_efm, PV_EFM,
   {(char_u *)DFLT_EFM, (char_u *)0L}
   SCRIPTID_INIT},
  {"esckeys",     "ek",   P_BOOL|P_VIM,
   (char_u *)&p_ek, PV_NONE,
   {(char_u *)FALSE, (char_u *)TRUE} SCRIPTID_INIT},
  {"eventignore", "ei",   P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_ei, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"expandtab",   "et",   P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_et, PV_ET,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"exrc",        "ex",   P_BOOL|P_VI_DEF|P_SECURE,
   (char_u *)&p_exrc, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"fileencoding","fenc", P_STRING|P_ALLOCED|P_VI_DEF|P_RSTAT|P_RBUF|P_NO_MKRC,
   (char_u *)&p_fenc, PV_FENC,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"fileencodings","fencs", P_STRING|P_VI_DEF|P_COMMA,
   (char_u *)&p_fencs, PV_NONE,
   {(char_u *)"ucs-bom", (char_u *)0L}
   SCRIPTID_INIT},
  {"fileformat",  "ff",   P_STRING|P_ALLOCED|P_VI_DEF|P_RSTAT|P_NO_MKRC|
   P_CURSWANT,
   (char_u *)&p_ff, PV_FF,
   {(char_u *)DFLT_FF, (char_u *)0L} SCRIPTID_INIT},
  {"fileformats", "ffs",  P_STRING|P_VIM|P_COMMA|P_NODUP,
   (char_u *)&p_ffs, PV_NONE,
   {(char_u *)DFLT_FFS_VI, (char_u *)DFLT_FFS_VIM}
   SCRIPTID_INIT},
  {"fileignorecase", "fic", P_BOOL|P_VI_DEF,
   (char_u *)&p_fic, PV_NONE,
   {
#ifdef CASE_INSENSITIVE_FILENAME
     (char_u *)TRUE,
#else
     (char_u *)FALSE,
#endif
     (char_u *)0L
   } SCRIPTID_INIT},
  {"filetype",    "ft",   P_STRING|P_ALLOCED|P_VI_DEF|P_NOGLOB|P_NFNAME,
   (char_u *)&p_ft, PV_FT,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"fillchars",   "fcs",  P_STRING|P_VI_DEF|P_RALL|P_COMMA|P_NODUP,
   (char_u *)&p_fcs, PV_NONE,
   {(char_u *)"vert:|,fold:-", (char_u *)0L}
   SCRIPTID_INIT},
  {"fkmap",       "fk",   P_BOOL|P_VI_DEF,
   (char_u *)&p_fkmap, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"flash",       "fl",   P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"foldclose",   "fcl",  P_STRING|P_VI_DEF|P_COMMA|P_NODUP|P_RWIN,
   (char_u *)&p_fcl, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"foldcolumn",  "fdc",  P_NUM|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_FDC,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"foldenable",  "fen",  P_BOOL|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_FEN,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"foldexpr",    "fde",  P_STRING|P_ALLOCED|P_VIM|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_FDE,
   {(char_u *)"0", (char_u *)NULL}
   SCRIPTID_INIT},
  {"foldignore",  "fdi",  P_STRING|P_ALLOCED|P_VIM|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_FDI,
   {(char_u *)"#", (char_u *)NULL} SCRIPTID_INIT},
  {"foldlevel",   "fdl",  P_NUM|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_FDL,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"foldlevelstart","fdls", P_NUM|P_VI_DEF|P_CURSWANT,
   (char_u *)&p_fdls, PV_NONE,
   {(char_u *)-1L, (char_u *)0L} SCRIPTID_INIT},
  {"foldmarker",  "fmr",  P_STRING|P_ALLOCED|P_VIM|P_VI_DEF|
   P_RWIN|P_COMMA|P_NODUP,
   (char_u *)VAR_WIN, PV_FMR,
   {(char_u *)"{{{,}}}", (char_u *)NULL}
   SCRIPTID_INIT},
  {"foldmethod",  "fdm",  P_STRING|P_ALLOCED|P_VIM|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_FDM,
   {(char_u *)"manual", (char_u *)NULL} SCRIPTID_INIT},
  {"foldminlines","fml",  P_NUM|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_FML,
   {(char_u *)1L, (char_u *)0L} SCRIPTID_INIT},
  {"foldnestmax", "fdn",  P_NUM|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_FDN,
   {(char_u *)20L, (char_u *)0L} SCRIPTID_INIT},
  {"foldopen",    "fdo",  P_STRING|P_VI_DEF|P_COMMA|P_NODUP|P_CURSWANT,
   (char_u *)&p_fdo, PV_NONE,
   {(char_u *)"block,hor,mark,percent,quickfix,search,tag,undo",
    (char_u *)0L} SCRIPTID_INIT},
  {"foldtext",    "fdt",  P_STRING|P_ALLOCED|P_VIM|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_FDT,
   {(char_u *)"foldtext()", (char_u *)NULL}
   SCRIPTID_INIT},
  {"formatexpr", "fex",   P_STRING|P_ALLOCED|P_VI_DEF|P_VIM,
   (char_u *)&p_fex, PV_FEX,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"formatoptions","fo",  P_STRING|P_ALLOCED|P_VIM|P_FLAGLIST,
   (char_u *)&p_fo, PV_FO,
   {(char_u *)DFLT_FO_VI, (char_u *)DFLT_FO_VIM}
   SCRIPTID_INIT},
  {"formatlistpat","flp", P_STRING|P_ALLOCED|P_VI_DEF,
   (char_u *)&p_flp, PV_FLP,
   {(char_u *)"^\\s*\\d\\+[\\]:.)}\\t ]\\s*",
    (char_u *)0L} SCRIPTID_INIT},
  {"formatprg",   "fp",   P_STRING|P_EXPAND|P_VI_DEF|P_SECURE,
   (char_u *)&p_fp, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"fsync",       "fs",   P_BOOL|P_SECURE|P_VI_DEF,
#ifdef HAVE_FSYNC
   (char_u *)&p_fs, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L}
#else
   (char_u *)NULL, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L}
#endif
   SCRIPTID_INIT},
  {"gdefault",    "gd",   P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_gd, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"graphic",     "gr",   P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"grepformat",  "gfm",  P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_gefm, PV_NONE,
   {(char_u *)DFLT_GREPFORMAT, (char_u *)0L}
   SCRIPTID_INIT},
  {"grepprg",     "gp",   P_STRING|P_EXPAND|P_VI_DEF|P_SECURE,
   (char_u *)&p_gp, PV_GP,
   {
#  ifdef UNIX
     /* Add an extra file name so that grep will always
      * insert a file name in the match line. */
     (char_u *)"grep -n $* /dev/null",
#  else
     (char_u *)"grep -n ",
#  endif
     (char_u *)0L
   }
   SCRIPTID_INIT},
  {"guicursor",    "gcr",  P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
#ifdef CURSOR_SHAPE
   (char_u *)&p_guicursor, PV_NONE,
   {
     (char_u *)"n-v-c:block,o:hor50,i-ci:hor15,r-cr:hor30,sm:block",
     (char_u *)0L
   }
#else
   (char_u *)NULL, PV_NONE,
   {(char_u *)NULL, (char_u *)0L}
#endif
   SCRIPTID_INIT},
  {"guifont",     "gfn",  P_STRING|P_VI_DEF|P_RCLR|P_COMMA|P_NODUP,
   (char_u *)NULL, PV_NONE,
   {(char_u *)NULL, (char_u *)0L}
   SCRIPTID_INIT},
  {"guifontset",  "gfs",  P_STRING|P_VI_DEF|P_RCLR|P_COMMA,
   (char_u *)NULL, PV_NONE,
   {(char_u *)NULL, (char_u *)0L}
   SCRIPTID_INIT},
  {"guifontwide", "gfw",  P_STRING|P_VI_DEF|P_RCLR|P_COMMA|P_NODUP,
   (char_u *)NULL, PV_NONE,
   {(char_u *)NULL, (char_u *)0L}
   SCRIPTID_INIT},
  {"guiheadroom", "ghr",  P_NUM|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)50L, (char_u *)0L} SCRIPTID_INIT},
  {"guioptions",  "go",   P_STRING|P_VI_DEF|P_RALL|P_FLAGLIST,
   (char_u *)NULL, PV_NONE,
   {(char_u *)NULL, (char_u *)0L}
   SCRIPTID_INIT},
  {"guipty",      NULL,   P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"guitablabel",  "gtl", P_STRING|P_VI_DEF|P_RWIN,
   (char_u *)NULL, PV_NONE,
   {(char_u *)NULL, (char_u *)0L}
   SCRIPTID_INIT},
  {"guitabtooltip",  "gtt", P_STRING|P_VI_DEF|P_RWIN,
   (char_u *)NULL, PV_NONE,
   {(char_u *)NULL, (char_u *)0L}
   SCRIPTID_INIT},
  {"hardtabs",    "ht",   P_NUM|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"helpfile",    "hf",   P_STRING|P_EXPAND|P_VI_DEF|P_SECURE,
   (char_u *)&p_hf, PV_NONE,
   {(char_u *)DFLT_HELPFILE, (char_u *)0L}
   SCRIPTID_INIT},
  {"helpheight",  "hh",   P_NUM|P_VI_DEF,
   (char_u *)&p_hh, PV_NONE,
   {(char_u *)20L, (char_u *)0L} SCRIPTID_INIT},
  {"helplang",    "hlg",  P_STRING|P_VI_DEF|P_COMMA,
   (char_u *)&p_hlg, PV_NONE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"hidden",      "hid",  P_BOOL|P_VI_DEF,
   (char_u *)&p_hid, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"highlight",   "hl",   P_STRING|P_VI_DEF|P_RCLR|P_COMMA|P_NODUP,
   (char_u *)&p_hl, PV_NONE,
   {(char_u *)HIGHLIGHT_INIT, (char_u *)0L}
   SCRIPTID_INIT},
  {"history",     "hi",   P_NUM|P_VIM,
   (char_u *)&p_hi, PV_NONE,
   {(char_u *)0L, (char_u *)20L} SCRIPTID_INIT},
  {"hkmap",       "hk",   P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_hkmap, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"hkmapp",      "hkp",  P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_hkmapp, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"hlsearch",    "hls",  P_BOOL|P_VI_DEF|P_VIM|P_RALL,
   (char_u *)&p_hls, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"icon",        NULL,   P_BOOL|P_VI_DEF,
   (char_u *)&p_icon, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"iconstring",  NULL,   P_STRING|P_VI_DEF,
   (char_u *)&p_iconstring, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"ignorecase",  "ic",   P_BOOL|P_VI_DEF,
   (char_u *)&p_ic, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"imactivatefunc","imaf",P_STRING|P_VI_DEF|P_SECURE,
   (char_u *)NULL, PV_NONE,
   {(char_u *)NULL, (char_u *)0L}
   SCRIPTID_INIT},
  {"imactivatekey","imak",P_STRING|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"imcmdline",   "imc",  P_BOOL|P_VI_DEF,
#ifdef USE_IM_CONTROL
   (char_u *)&p_imcmdline, PV_NONE,
#else
   (char_u *)NULL, PV_NONE,
#endif
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"imdisable",   "imd",  P_BOOL|P_VI_DEF,
#ifdef USE_IM_CONTROL
   (char_u *)&p_imdisable, PV_NONE,
#else
   (char_u *)NULL, PV_NONE,
#endif
   {(char_u *)FALSE, (char_u *)0L}
   SCRIPTID_INIT},
  {"iminsert",    "imi",  P_NUM|P_VI_DEF,
   (char_u *)&p_iminsert, PV_IMI,
#ifdef B_IMODE_IM
   {(char_u *)B_IMODE_IM, (char_u *)0L}
#else
   {(char_u *)B_IMODE_NONE, (char_u *)0L}
#endif
   SCRIPTID_INIT},
  {"imsearch",    "ims",  P_NUM|P_VI_DEF,
   (char_u *)&p_imsearch, PV_IMS,
#ifdef B_IMODE_IM
   {(char_u *)B_IMODE_IM, (char_u *)0L}
#else
   {(char_u *)B_IMODE_NONE, (char_u *)0L}
#endif
   SCRIPTID_INIT},
  {"imstatusfunc","imsf",P_STRING|P_VI_DEF|P_SECURE,
   (char_u *)NULL, PV_NONE,
   {(char_u *)NULL, (char_u *)0L}
   SCRIPTID_INIT},
  {"include",     "inc",  P_STRING|P_ALLOCED|P_VI_DEF,
   (char_u *)&p_inc, PV_INC,
   {(char_u *)"^\\s*#\\s*include", (char_u *)0L}
   SCRIPTID_INIT},
  {"includeexpr", "inex", P_STRING|P_ALLOCED|P_VI_DEF,
   (char_u *)&p_inex, PV_INEX,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"incsearch",   "is",   P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_is, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"indentexpr", "inde",  P_STRING|P_ALLOCED|P_VI_DEF|P_VIM,
   (char_u *)&p_inde, PV_INDE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"indentkeys", "indk",  P_STRING|P_ALLOCED|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_indk, PV_INDK,
   {(char_u *)"0{,0},:,0#,!^F,o,O,e", (char_u *)0L}
   SCRIPTID_INIT},
  {"infercase",   "inf",  P_BOOL|P_VI_DEF,
   (char_u *)&p_inf, PV_INF,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"insertmode",  "im",   P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_im, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"isfname",     "isf",  P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_isf, PV_NONE,
   {
#ifdef BACKSLASH_IN_FILENAME
     /* Excluded are: & and ^ are special in cmd.exe
     * ( and ) are used in text separating fnames */
     (char_u *)"@,48-57,/,\\,.,-,_,+,,,#,$,%,{,},[,],:,@-@,!,~,=",
#else
     (char_u *)"@,48-57,/,.,-,_,+,,,#,$,%,~,=",
#endif
     (char_u *)0L
   } SCRIPTID_INIT},
  {"isident",     "isi",  P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_isi, PV_NONE,
   {
     (char_u *)"@,48-57,_,192-255",
     (char_u *)0L
   } SCRIPTID_INIT},
  {"iskeyword",   "isk",  P_STRING|P_ALLOCED|P_VIM|P_COMMA|P_NODUP,
   (char_u *)&p_isk, PV_ISK,
   {
     (char_u *)"@,48-57,_",
     ISK_LATIN1
   } SCRIPTID_INIT},
  {"isprint",     "isp",  P_STRING|P_VI_DEF|P_RALL|P_COMMA|P_NODUP,
   (char_u *)&p_isp, PV_NONE,
   {
#if defined(MSDOS) || defined(MSWIN) || defined(OS2) \
     || (defined(MACOS) && !defined(MACOS_X)) \
     || defined(VMS)
     (char_u *)"@,~-255",
#else
     ISP_LATIN1,
#endif
     (char_u *)0L
   } SCRIPTID_INIT},
  {"joinspaces",  "js",   P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_js, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"key",         NULL,   P_STRING|P_ALLOCED|P_VI_DEF|P_NO_MKRC,
   (char_u *)&p_key, PV_KEY,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"keymap",      "kmp",  P_STRING|P_ALLOCED|P_VI_DEF|P_RBUF|P_RSTAT|P_NFNAME|
   P_PRI_MKRC,
   (char_u *)&p_keymap, PV_KMAP,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"keymodel",    "km",   P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_km, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"keywordprg",  "kp",   P_STRING|P_EXPAND|P_VI_DEF|P_SECURE,
   (char_u *)&p_kp, PV_KP,
   {
#  ifdef USEMAN_S
     (char_u *)"man -s",
#  else
     (char_u *)"man",
#  endif
     (char_u *)0L
   } SCRIPTID_INIT},
  {"langmap",     "lmap", P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_langmap, PV_NONE,
   {(char_u *)"",                               /* unmatched } */
    (char_u *)0L} SCRIPTID_INIT},
  {"langmenu",    "lm",   P_STRING|P_VI_DEF|P_NFNAME,
   (char_u *)&p_lm, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"laststatus",  "ls",   P_NUM|P_VI_DEF|P_RALL,
   (char_u *)&p_ls, PV_NONE,
   {(char_u *)1L, (char_u *)0L} SCRIPTID_INIT},
  {"lazyredraw",  "lz",   P_BOOL|P_VI_DEF,
   (char_u *)&p_lz, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"linebreak",   "lbr",  P_BOOL|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_LBR,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"lines",       NULL,   P_NUM|P_NODEFAULT|P_NO_MKRC|P_VI_DEF|P_RCLR,
   (char_u *)&Rows, PV_NONE,
   {
     (char_u *)24L,
     (char_u *)0L
   } SCRIPTID_INIT},
  {"linespace",   "lsp",  P_NUM|P_VI_DEF|P_RCLR,
   (char_u *)NULL, PV_NONE,
   {(char_u *)0L, (char_u *)0L}
   SCRIPTID_INIT},
  {"lisp",        NULL,   P_BOOL|P_VI_DEF,
   (char_u *)&p_lisp, PV_LISP,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"lispwords",   "lw",   P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_lispwords, PV_NONE,
   {(char_u *)LISPWORD_VALUE, (char_u *)0L}
   SCRIPTID_INIT},
  {"list",        NULL,   P_BOOL|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_LIST,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"listchars",   "lcs",  P_STRING|P_VI_DEF|P_RALL|P_COMMA|P_NODUP,
   (char_u *)&p_lcs, PV_NONE,
   {(char_u *)"eol:$", (char_u *)0L} SCRIPTID_INIT},
  {"loadplugins", "lpl",  P_BOOL|P_VI_DEF,
   (char_u *)&p_lpl, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"magic",       NULL,   P_BOOL|P_VI_DEF,
   (char_u *)&p_magic, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"makeef",      "mef",  P_STRING|P_EXPAND|P_VI_DEF|P_SECURE,
   (char_u *)&p_mef, PV_NONE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"makeprg",     "mp",   P_STRING|P_EXPAND|P_VI_DEF|P_SECURE,
   (char_u *)&p_mp, PV_MP,
   {(char_u *)"make", (char_u *)0L}
   SCRIPTID_INIT},
  {"matchpairs",  "mps",  P_STRING|P_ALLOCED|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_mps, PV_MPS,
   {(char_u *)"(:),{:},[:]", (char_u *)0L}
   SCRIPTID_INIT},
  {"matchtime",   "mat",  P_NUM|P_VI_DEF,
   (char_u *)&p_mat, PV_NONE,
   {(char_u *)5L, (char_u *)0L} SCRIPTID_INIT},
  {"maxcombine",  "mco",  P_NUM|P_VI_DEF|P_CURSWANT,
   (char_u *)&p_mco, PV_NONE,
   {(char_u *)2, (char_u *)0L} SCRIPTID_INIT},
  {"maxfuncdepth", "mfd", P_NUM|P_VI_DEF,
   (char_u *)&p_mfd, PV_NONE,
   {(char_u *)100L, (char_u *)0L} SCRIPTID_INIT},
  {"maxmapdepth", "mmd",  P_NUM|P_VI_DEF,
   (char_u *)&p_mmd, PV_NONE,
   {(char_u *)1000L, (char_u *)0L} SCRIPTID_INIT},
  {"maxmem",      "mm",   P_NUM|P_VI_DEF,
   (char_u *)&p_mm, PV_NONE,
   {(char_u *)DFLT_MAXMEM, (char_u *)0L}
   SCRIPTID_INIT},
  {"maxmempattern","mmp", P_NUM|P_VI_DEF,
   (char_u *)&p_mmp, PV_NONE,
   {(char_u *)1000L, (char_u *)0L} SCRIPTID_INIT},
  {"maxmemtot",   "mmt",  P_NUM|P_VI_DEF,
   (char_u *)&p_mmt, PV_NONE,
   {(char_u *)DFLT_MAXMEMTOT, (char_u *)0L}
   SCRIPTID_INIT},
  {"menuitems",   "mis",  P_NUM|P_VI_DEF,
   (char_u *)&p_mis, PV_NONE,
   {(char_u *)25L, (char_u *)0L} SCRIPTID_INIT},
  {"mesg",        NULL,   P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"mkspellmem",  "msm",  P_STRING|P_VI_DEF|P_EXPAND|P_SECURE,
   (char_u *)&p_msm, PV_NONE,
   {(char_u *)"460000,2000,500", (char_u *)0L}
   SCRIPTID_INIT},
  {"modeline",    "ml",   P_BOOL|P_VIM,
   (char_u *)&p_ml, PV_ML,
   {(char_u *)FALSE, (char_u *)TRUE} SCRIPTID_INIT},
  {"modelines",   "mls",  P_NUM|P_VI_DEF,
   (char_u *)&p_mls, PV_NONE,
   {(char_u *)5L, (char_u *)0L} SCRIPTID_INIT},
  {"modifiable",  "ma",   P_BOOL|P_VI_DEF|P_NOGLOB,
   (char_u *)&p_ma, PV_MA,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"modified",    "mod",  P_BOOL|P_NO_MKRC|P_VI_DEF|P_RSTAT,
   (char_u *)&p_mod, PV_MOD,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"more",        NULL,   P_BOOL|P_VIM,
   (char_u *)&p_more, PV_NONE,
   {(char_u *)FALSE, (char_u *)TRUE} SCRIPTID_INIT},
  {"mouse",       NULL,   P_STRING|P_VI_DEF|P_FLAGLIST,
   (char_u *)&p_mouse, PV_NONE,
   {
     (char_u *)"",
     (char_u *)0L
   } SCRIPTID_INIT},
  {"mousefocus",   "mousef", P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"mousehide",   "mh",   P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"mousemodel",  "mousem", P_STRING|P_VI_DEF,
   (char_u *)&p_mousem, PV_NONE,
   {
     (char_u *)"extend",
     (char_u *)0L
   } SCRIPTID_INIT},
  {"mouseshape",  "mouses",  P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)NULL, PV_NONE,
   {(char_u *)NULL, (char_u *)0L}
   SCRIPTID_INIT},
  {"mousetime",   "mouset",   P_NUM|P_VI_DEF,
   (char_u *)&p_mouset, PV_NONE,
   {(char_u *)500L, (char_u *)0L} SCRIPTID_INIT},
  {"mzquantum",  "mzq",   P_NUM,
   (char_u *)NULL, PV_NONE,
   {(char_u *)100L, (char_u *)100L} SCRIPTID_INIT},
  {"novice",      NULL,   P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"nrformats",   "nf",   P_STRING|P_ALLOCED|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_nf, PV_NF,
   {(char_u *)"octal,hex", (char_u *)0L}
   SCRIPTID_INIT},
  {"number",      "nu",   P_BOOL|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_NU,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"numberwidth", "nuw",  P_NUM|P_RWIN|P_VIM,
   (char_u *)VAR_WIN, PV_NUW,
   {(char_u *)8L, (char_u *)4L} SCRIPTID_INIT},
  {"omnifunc",    "ofu",  P_STRING|P_ALLOCED|P_VI_DEF|P_SECURE,
   (char_u *)&p_ofu, PV_OFU,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"open",        NULL,   P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"opendevice",  "odev", P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)FALSE, (char_u *)FALSE}
   SCRIPTID_INIT},
  {"operatorfunc", "opfunc", P_STRING|P_VI_DEF|P_SECURE,
   (char_u *)&p_opfunc, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"optimize",    "opt",  P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"osfiletype",  "oft",  P_STRING|P_ALLOCED|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"paragraphs",  "para", P_STRING|P_VI_DEF,
   (char_u *)&p_para, PV_NONE,
   {(char_u *)"IPLPPPQPP TPHPLIPpLpItpplpipbp",
    (char_u *)0L} SCRIPTID_INIT},
  {"paste",       NULL,   P_BOOL|P_VI_DEF|P_PRI_MKRC,
   (char_u *)&p_paste, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"pastetoggle", "pt",   P_STRING|P_VI_DEF,
   (char_u *)&p_pt, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"patchexpr",   "pex",  P_STRING|P_VI_DEF|P_SECURE,
   (char_u *)&p_pex, PV_NONE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"patchmode",   "pm",   P_STRING|P_VI_DEF|P_NFNAME,
   (char_u *)&p_pm, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"path",        "pa",   P_STRING|P_EXPAND|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_path, PV_PATH,
   {
     (char_u *)".,/usr/include,,",
     (char_u *)0L
   } SCRIPTID_INIT},
  {"preserveindent", "pi", P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_pi, PV_PI,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"previewheight", "pvh", P_NUM|P_VI_DEF,
   (char_u *)&p_pvh, PV_NONE,
   {(char_u *)12L, (char_u *)0L} SCRIPTID_INIT},
  {"previewwindow", "pvw", P_BOOL|P_VI_DEF|P_RSTAT|P_NOGLOB,
   (char_u *)VAR_WIN, PV_PVW,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"printdevice", "pdev", P_STRING|P_VI_DEF|P_SECURE,
   (char_u *)&p_pdev, PV_NONE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"printencoding", "penc", P_STRING|P_VI_DEF,
   (char_u *)&p_penc, PV_NONE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"printexpr", "pexpr",  P_STRING|P_VI_DEF,
   (char_u *)&p_pexpr, PV_NONE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"printfont", "pfn",    P_STRING|P_VI_DEF,
   (char_u *)&p_pfn, PV_NONE,
   {
     (char_u *)"courier",
     (char_u *)0L
   }
   SCRIPTID_INIT},
  {"printheader", "pheader",  P_STRING|P_VI_DEF|P_GETTEXT,
   (char_u *)&p_header, PV_NONE,
   {(char_u *)N_("%<%f%h%m%=Page %N"), (char_u *)0L}
   SCRIPTID_INIT},
  {"printmbcharset", "pmbcs",  P_STRING|P_VI_DEF,
   (char_u *)&p_pmcs, PV_NONE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"printmbfont", "pmbfn",  P_STRING|P_VI_DEF,
   (char_u *)&p_pmfn, PV_NONE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"printoptions", "popt", P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_popt, PV_NONE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"prompt",      NULL,   P_BOOL|P_VI_DEF,
   (char_u *)&p_prompt, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"pumheight",   "ph",   P_NUM|P_VI_DEF,
   (char_u *)&p_ph, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"quoteescape", "qe",   P_STRING|P_ALLOCED|P_VI_DEF,
   (char_u *)&p_qe, PV_QE,
   {(char_u *)"\\", (char_u *)0L}
   SCRIPTID_INIT},
  {"readonly",    "ro",   P_BOOL|P_VI_DEF|P_RSTAT|P_NOGLOB,
   (char_u *)&p_ro, PV_RO,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"redraw",      NULL,   P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"redrawtime",  "rdt",  P_NUM|P_VI_DEF,
   (char_u *)&p_rdt, PV_NONE,
   {(char_u *)2000L, (char_u *)0L} SCRIPTID_INIT},
  {"regexpengine", "re",  P_NUM|P_VI_DEF,
   (char_u *)&p_re, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"relativenumber", "rnu", P_BOOL|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_RNU,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"remap",       NULL,   P_BOOL|P_VI_DEF,
   (char_u *)&p_remap, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"report",      NULL,   P_NUM|P_VI_DEF,
   (char_u *)&p_report, PV_NONE,
   {(char_u *)2L, (char_u *)0L} SCRIPTID_INIT},
  {"restorescreen", "rs", P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"revins",      "ri",   P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_ri, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"rightleft",   "rl",   P_BOOL|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_RL,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"rightleftcmd", "rlc", P_STRING|P_ALLOCED|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_RLC,
   {(char_u *)"search", (char_u *)NULL}
   SCRIPTID_INIT},
  {"ruler",       "ru",   P_BOOL|P_VI_DEF|P_VIM|P_RSTAT,
   (char_u *)&p_ru, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"rulerformat", "ruf",  P_STRING|P_VI_DEF|P_ALLOCED|P_RSTAT,
   (char_u *)&p_ruf, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"runtimepath", "rtp",  P_STRING|P_VI_DEF|P_EXPAND|P_COMMA|P_NODUP|P_SECURE,
   (char_u *)&p_rtp, PV_NONE,
   {(char_u *)DFLT_RUNTIMEPATH, (char_u *)0L}
   SCRIPTID_INIT},
  {"scroll",      "scr",  P_NUM|P_NO_MKRC|P_VI_DEF,
   (char_u *)VAR_WIN, PV_SCROLL,
   {(char_u *)12L, (char_u *)0L} SCRIPTID_INIT},
  {"scrollbind",  "scb",  P_BOOL|P_VI_DEF,
   (char_u *)VAR_WIN, PV_SCBIND,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"scrolljump",  "sj",   P_NUM|P_VI_DEF|P_VIM,
   (char_u *)&p_sj, PV_NONE,
   {(char_u *)1L, (char_u *)0L} SCRIPTID_INIT},
  {"scrolloff",   "so",   P_NUM|P_VI_DEF|P_VIM|P_RALL,
   (char_u *)&p_so, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"scrollopt",   "sbo",  P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_sbo, PV_NONE,
   {(char_u *)"ver,jump", (char_u *)0L}
   SCRIPTID_INIT},
  {"sections",    "sect", P_STRING|P_VI_DEF,
   (char_u *)&p_sections, PV_NONE,
   {(char_u *)"SHNHH HUnhsh", (char_u *)0L}
   SCRIPTID_INIT},
  {"secure",      NULL,   P_BOOL|P_VI_DEF|P_SECURE,
   (char_u *)&p_secure, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"selection",   "sel",  P_STRING|P_VI_DEF,
   (char_u *)&p_sel, PV_NONE,
   {(char_u *)"inclusive", (char_u *)0L}
   SCRIPTID_INIT},
  {"selectmode",  "slm",  P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_slm, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"sessionoptions", "ssop", P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_ssop, PV_NONE,
   {(char_u *)"blank,buffers,curdir,folds,help,options,tabpages,winsize",
    (char_u *)0L}
   SCRIPTID_INIT},
  {"shell",       "sh",   P_STRING|P_EXPAND|P_VI_DEF|P_SECURE,
   (char_u *)&p_sh, PV_NONE,
   {
#     if defined(ARCHIE)
     (char_u *)"gos",
#     else
     (char_u *)"sh",
#     endif
     (char_u *)0L
   } SCRIPTID_INIT},
  {"shellcmdflag","shcf", P_STRING|P_VI_DEF|P_SECURE,
   (char_u *)&p_shcf, PV_NONE,
   {
     (char_u *)"-c",
     (char_u *)0L
   } SCRIPTID_INIT},
  {"shellpipe",   "sp",   P_STRING|P_VI_DEF|P_SECURE,
   (char_u *)&p_sp, PV_NONE,
   {
#if defined(UNIX) || defined(OS2)
# ifdef ARCHIE
     (char_u *)"2>",
# else
     (char_u *)"| tee",
# endif
#else
     (char_u *)">",
#endif
     (char_u *)0L
   }
   SCRIPTID_INIT},
  {"shellquote",  "shq",  P_STRING|P_VI_DEF|P_SECURE,
   (char_u *)&p_shq, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"shellredir",  "srr",  P_STRING|P_VI_DEF|P_SECURE,
   (char_u *)&p_srr, PV_NONE,
   {(char_u *)">", (char_u *)0L} SCRIPTID_INIT},
  {"shellslash",  "ssl",   P_BOOL|P_VI_DEF,
#ifdef BACKSLASH_IN_FILENAME
   (char_u *)&p_ssl, PV_NONE,
#else
   (char_u *)NULL, PV_NONE,
#endif
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"shelltemp",   "stmp", P_BOOL,
   (char_u *)&p_stmp, PV_NONE,
   {(char_u *)FALSE, (char_u *)TRUE} SCRIPTID_INIT},
  {"shelltype",   "st",   P_NUM|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"shellxquote", "sxq",  P_STRING|P_VI_DEF|P_SECURE,
   (char_u *)&p_sxq, PV_NONE,
   {
     (char_u *)"",
     (char_u *)0L
   } SCRIPTID_INIT},
  {"shellxescape", "sxe", P_STRING|P_VI_DEF|P_SECURE,
   (char_u *)&p_sxe, PV_NONE,
   {
     (char_u *)"",
     (char_u *)0L
   } SCRIPTID_INIT},
  {"shiftround",  "sr",   P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_sr, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"shiftwidth",  "sw",   P_NUM|P_VI_DEF,
   (char_u *)&p_sw, PV_SW,
   {(char_u *)8L, (char_u *)0L} SCRIPTID_INIT},
  {"shortmess",   "shm",  P_STRING|P_VIM|P_FLAGLIST,
   (char_u *)&p_shm, PV_NONE,
   {(char_u *)"", (char_u *)"filnxtToO"}
   SCRIPTID_INIT},
  {"shortname",   "sn",   P_BOOL|P_VI_DEF,
#ifdef SHORT_FNAME
   (char_u *)NULL, PV_NONE,
#else
   (char_u *)&p_sn, PV_SN,
#endif
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"showbreak",   "sbr",  P_STRING|P_VI_DEF|P_RALL,
   (char_u *)&p_sbr, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"showcmd",     "sc",   P_BOOL|P_VIM,
   (char_u *)&p_sc, PV_NONE,
   {(char_u *)FALSE,
#ifdef UNIX
    (char_u *)FALSE
#else
      (char_u *) TRUE
#endif
   } SCRIPTID_INIT},
  {"showfulltag", "sft",  P_BOOL|P_VI_DEF,
   (char_u *)&p_sft, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"showmatch",   "sm",   P_BOOL|P_VI_DEF,
   (char_u *)&p_sm, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"showmode",    "smd",  P_BOOL|P_VIM,
   (char_u *)&p_smd, PV_NONE,
   {(char_u *)FALSE, (char_u *)TRUE} SCRIPTID_INIT},
  {"showtabline", "stal", P_NUM|P_VI_DEF|P_RALL,
   (char_u *)&p_stal, PV_NONE,
   {(char_u *)1L, (char_u *)0L} SCRIPTID_INIT},
  {"sidescroll",  "ss",   P_NUM|P_VI_DEF,
   (char_u *)&p_ss, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"sidescrolloff", "siso", P_NUM|P_VI_DEF|P_VIM|P_RBUF,
   (char_u *)&p_siso, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"slowopen",    "slow", P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"smartcase",   "scs",  P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_scs, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"smartindent", "si",   P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_si, PV_SI,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"smarttab",    "sta",  P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_sta, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"softtabstop", "sts",  P_NUM|P_VI_DEF|P_VIM,
   (char_u *)&p_sts, PV_STS,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"sourceany",   NULL,   P_BOOL|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"spell",       NULL,   P_BOOL|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_SPELL,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"spellcapcheck", "spc", P_STRING|P_ALLOCED|P_VI_DEF|P_RBUF,
   (char_u *)&p_spc, PV_SPC,
   {(char_u *)"[.?!]\\_[\\])'\"	 ]\\+", (char_u *)0L}
   SCRIPTID_INIT},
  {"spellfile",   "spf",  P_STRING|P_EXPAND|P_ALLOCED|P_VI_DEF|P_SECURE|P_COMMA,
   (char_u *)&p_spf, PV_SPF,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"spelllang",   "spl",  P_STRING|P_ALLOCED|P_VI_DEF|P_COMMA|P_RBUF|P_EXPAND,
   (char_u *)&p_spl, PV_SPL,
   {(char_u *)"en", (char_u *)0L}
   SCRIPTID_INIT},
  {"spellsuggest", "sps", P_STRING|P_VI_DEF|P_EXPAND|P_SECURE|P_COMMA,
   (char_u *)&p_sps, PV_NONE,
   {(char_u *)"best", (char_u *)0L}
   SCRIPTID_INIT},
  {"splitbelow",  "sb",   P_BOOL|P_VI_DEF,
   (char_u *)&p_sb, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"splitright",  "spr",  P_BOOL|P_VI_DEF,
   (char_u *)&p_spr, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"startofline", "sol",  P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_sol, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"statusline","stl",  P_STRING|P_VI_DEF|P_ALLOCED|P_RSTAT,
   (char_u *)&p_stl, PV_STL,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"suffixes",    "su",   P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_su, PV_NONE,
   {(char_u *)".bak,~,.o,.h,.info,.swp,.obj",
    (char_u *)0L} SCRIPTID_INIT},
  {"suffixesadd", "sua",  P_STRING|P_VI_DEF|P_ALLOCED|P_COMMA|P_NODUP,
   (char_u *)&p_sua, PV_SUA,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"swapfile",    "swf",  P_BOOL|P_VI_DEF|P_RSTAT,
   (char_u *)&p_swf, PV_SWF,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"swapsync",    "sws",  P_STRING|P_VI_DEF,
   (char_u *)&p_sws, PV_NONE,
   {(char_u *)"fsync", (char_u *)0L} SCRIPTID_INIT},
  {"switchbuf",   "swb",  P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_swb, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"synmaxcol",   "smc",  P_NUM|P_VI_DEF|P_RBUF,
   (char_u *)&p_smc, PV_SMC,
   {(char_u *)3000L, (char_u *)0L}
   SCRIPTID_INIT},
  {"syntax",      "syn",  P_STRING|P_ALLOCED|P_VI_DEF|P_NOGLOB|P_NFNAME,
   (char_u *)&p_syn, PV_SYN,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"tabline",     "tal",  P_STRING|P_VI_DEF|P_RALL,
   (char_u *)&p_tal, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"tabpagemax",  "tpm",  P_NUM|P_VI_DEF,
   (char_u *)&p_tpm, PV_NONE,
   {(char_u *)10L, (char_u *)0L} SCRIPTID_INIT},
  {"tabstop",     "ts",   P_NUM|P_VI_DEF|P_RBUF,
   (char_u *)&p_ts, PV_TS,
   {(char_u *)8L, (char_u *)0L} SCRIPTID_INIT},
  {"tagbsearch",  "tbs",   P_BOOL|P_VI_DEF,
   (char_u *)&p_tbs, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L}
   SCRIPTID_INIT},
  {"taglength",   "tl",   P_NUM|P_VI_DEF,
   (char_u *)&p_tl, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"tagrelative", "tr",   P_BOOL|P_VIM,
   (char_u *)&p_tr, PV_NONE,
   {(char_u *)FALSE, (char_u *)TRUE} SCRIPTID_INIT},
  {"tags",        "tag",  P_STRING|P_EXPAND|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_tags, PV_TAGS,
   {
     (char_u *)"./tags,tags",
     (char_u *)0L
   } SCRIPTID_INIT},
  {"tagstack",    "tgst", P_BOOL|P_VI_DEF,
   (char_u *)&p_tgst, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"term",        NULL,   P_STRING|P_EXPAND|P_NODEFAULT|P_NO_MKRC|P_VI_DEF|
   P_RALL,
   (char_u *)&T_NAME, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"termbidi", "tbidi",   P_BOOL|P_VI_DEF,
   (char_u *)&p_tbidi, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"termencoding", "tenc", P_STRING|P_VI_DEF|P_RCLR,
   (char_u *)&p_tenc, PV_NONE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"terse",       NULL,   P_BOOL|P_VI_DEF,
   (char_u *)&p_terse, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"textauto",    "ta",   P_BOOL|P_VIM,
   (char_u *)&p_ta, PV_NONE,
   {(char_u *)DFLT_TEXTAUTO, (char_u *)TRUE}
   SCRIPTID_INIT},
  {"textmode",    "tx",   P_BOOL|P_VI_DEF|P_NO_MKRC,
   (char_u *)&p_tx, PV_TX,
   {
#ifdef USE_CRNL
     (char_u *)TRUE,
#else
     (char_u *)FALSE,
#endif
     (char_u *)0L
   } SCRIPTID_INIT},
  {"textwidth",   "tw",   P_NUM|P_VI_DEF|P_VIM|P_RBUF,
   (char_u *)&p_tw, PV_TW,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"thesaurus",   "tsr",  P_STRING|P_EXPAND|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_tsr, PV_TSR,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"tildeop",     "top",  P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_to, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"timeout",     "to",   P_BOOL|P_VI_DEF,
   (char_u *)&p_timeout, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"timeoutlen",  "tm",   P_NUM|P_VI_DEF,
   (char_u *)&p_tm, PV_NONE,
   {(char_u *)1000L, (char_u *)0L} SCRIPTID_INIT},
  {"title",       NULL,   P_BOOL|P_VI_DEF,
   (char_u *)&p_title, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"titlelen",    NULL,   P_NUM|P_VI_DEF,
   (char_u *)&p_titlelen, PV_NONE,
   {(char_u *)85L, (char_u *)0L} SCRIPTID_INIT},
  {"titleold",    NULL,   P_STRING|P_VI_DEF|P_GETTEXT|P_SECURE|P_NO_MKRC,
   (char_u *)&p_titleold, PV_NONE,
   {(char_u *)N_("Thanks for flying Vim"),
    (char_u *)0L}
   SCRIPTID_INIT},
  {"titlestring", NULL,   P_STRING|P_VI_DEF,
   (char_u *)&p_titlestring, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"ttimeout",    NULL,   P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_ttimeout, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"ttimeoutlen", "ttm",  P_NUM|P_VI_DEF,
   (char_u *)&p_ttm, PV_NONE,
   {(char_u *)-1L, (char_u *)0L} SCRIPTID_INIT},
  {"ttybuiltin",  "tbi",  P_BOOL|P_VI_DEF,
   (char_u *)&p_tbi, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"ttyfast",     "tf",   P_BOOL|P_NO_MKRC|P_VI_DEF,
   (char_u *)&p_tf, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"ttymouse",    "ttym", P_STRING|P_NODEFAULT|P_NO_MKRC|P_VI_DEF,
#if defined(FEAT_MOUSE) && (defined(UNIX) || defined(VMS))
   (char_u *)&p_ttym, PV_NONE,
#else
   (char_u *)NULL, PV_NONE,
#endif
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"ttyscroll",   "tsl",  P_NUM|P_VI_DEF,
   (char_u *)&p_ttyscroll, PV_NONE,
   {(char_u *)999L, (char_u *)0L} SCRIPTID_INIT},
  {"ttytype",     "tty",  P_STRING|P_EXPAND|P_NODEFAULT|P_NO_MKRC|P_VI_DEF|
   P_RALL,
   (char_u *)&T_NAME, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"undodir",     "udir", P_STRING|P_EXPAND|P_COMMA|P_NODUP|P_SECURE|P_VI_DEF,
   (char_u *)&p_udir, PV_NONE,
   {(char_u *)".", (char_u *)0L}
   SCRIPTID_INIT},
  {"undofile",    "udf",  P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_udf, PV_UDF,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"undolevels",  "ul",   P_NUM|P_VI_DEF,
   (char_u *)&p_ul, PV_UL,
   {
#if defined(UNIX) || defined(WIN3264) || defined(OS2) || defined(VMS)
     (char_u *)1000L,
#else
     (char_u *)100L,
#endif
     (char_u *)0L
   } SCRIPTID_INIT},
  {"undoreload",  "ur",   P_NUM|P_VI_DEF,
   (char_u *)&p_ur, PV_NONE,
   { (char_u *)10000L, (char_u *)0L} SCRIPTID_INIT},
  {"updatecount", "uc",   P_NUM|P_VI_DEF,
   (char_u *)&p_uc, PV_NONE,
   {(char_u *)200L, (char_u *)0L} SCRIPTID_INIT},
  {"updatetime",  "ut",   P_NUM|P_VI_DEF,
   (char_u *)&p_ut, PV_NONE,
   {(char_u *)4000L, (char_u *)0L} SCRIPTID_INIT},
  {"verbose",     "vbs",  P_NUM|P_VI_DEF,
   (char_u *)&p_verbose, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"verbosefile", "vfile", P_STRING|P_EXPAND|P_VI_DEF|P_SECURE,
   (char_u *)&p_vfile, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"viewdir",     "vdir", P_STRING|P_EXPAND|P_VI_DEF|P_SECURE,
   (char_u *)&p_vdir, PV_NONE,
   {(char_u *)DFLT_VDIR, (char_u *)0L}
   SCRIPTID_INIT},
  {"viewoptions", "vop",  P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_vop, PV_NONE,
   {(char_u *)"folds,options,cursor", (char_u *)0L}
   SCRIPTID_INIT},
  {"viminfo",     "vi",   P_STRING|P_COMMA|P_NODUP|P_SECURE,
   (char_u *)&p_viminfo, PV_NONE,
   {(char_u *)"", (char_u *)"'100,<50,s10,h"}
   SCRIPTID_INIT},
  {"virtualedit", "ve",   P_STRING|P_COMMA|P_NODUP|P_VI_DEF|P_VIM|P_CURSWANT,
   (char_u *)&p_ve, PV_NONE,
   {(char_u *)"", (char_u *)""}
   SCRIPTID_INIT},
  {"visualbell",  "vb",   P_BOOL|P_VI_DEF,
   (char_u *)&p_vb, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"w300",        NULL,   P_NUM|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"w1200",       NULL,   P_NUM|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"w9600",       NULL,   P_NUM|P_VI_DEF,
   (char_u *)NULL, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"warn",        NULL,   P_BOOL|P_VI_DEF,
   (char_u *)&p_warn, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"weirdinvert", "wiv",  P_BOOL|P_VI_DEF|P_RCLR,
   (char_u *)&p_wiv, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"whichwrap",   "ww",   P_STRING|P_VIM|P_COMMA|P_FLAGLIST,
   (char_u *)&p_ww, PV_NONE,
   {(char_u *)"", (char_u *)"b,s"} SCRIPTID_INIT},
  {"wildchar",    "wc",   P_NUM|P_VIM,
   (char_u *)&p_wc, PV_NONE,
   {(char_u *)(long)Ctrl_E, (char_u *)(long)TAB}
   SCRIPTID_INIT},
  {"wildcharm",   "wcm",  P_NUM|P_VI_DEF,
   (char_u *)&p_wcm, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"wildignore",  "wig",  P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_wig, PV_NONE,
   {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},
  {"wildignorecase", "wic", P_BOOL|P_VI_DEF,
   (char_u *)&p_wic, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"wildmenu",    "wmnu", P_BOOL|P_VI_DEF,
   (char_u *)&p_wmnu, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"wildmode",    "wim",  P_STRING|P_VI_DEF|P_COMMA|P_NODUP,
   (char_u *)&p_wim, PV_NONE,
   {(char_u *)"full", (char_u *)0L} SCRIPTID_INIT},
  {"wildoptions", "wop",  P_STRING|P_VI_DEF,
   (char_u *)&p_wop, PV_NONE,
   {(char_u *)"", (char_u *)0L}
   SCRIPTID_INIT},
  {"winaltkeys",  "wak",  P_STRING|P_VI_DEF,
   (char_u *)&p_wak, PV_NONE,
   {(char_u *)"menu", (char_u *)0L}
   SCRIPTID_INIT},
  {"window",      "wi",   P_NUM|P_VI_DEF,
   (char_u *)&p_window, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"winheight",   "wh",   P_NUM|P_VI_DEF,
   (char_u *)&p_wh, PV_NONE,
   {(char_u *)1L, (char_u *)0L} SCRIPTID_INIT},
  {"winfixheight", "wfh", P_BOOL|P_VI_DEF|P_RSTAT,
   (char_u *)VAR_WIN, PV_WFH,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"winfixwidth", "wfw", P_BOOL|P_VI_DEF|P_RSTAT,
   (char_u *)VAR_WIN, PV_WFW,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"winminheight", "wmh", P_NUM|P_VI_DEF,
   (char_u *)&p_wmh, PV_NONE,
   {(char_u *)1L, (char_u *)0L} SCRIPTID_INIT},
  {"winminwidth", "wmw", P_NUM|P_VI_DEF,
   (char_u *)&p_wmw, PV_NONE,
   {(char_u *)1L, (char_u *)0L} SCRIPTID_INIT},
  {"winwidth",   "wiw",   P_NUM|P_VI_DEF,
   (char_u *)&p_wiw, PV_NONE,
   {(char_u *)20L, (char_u *)0L} SCRIPTID_INIT},
  {"wrap",        NULL,   P_BOOL|P_VI_DEF|P_RWIN,
   (char_u *)VAR_WIN, PV_WRAP,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"wrapmargin",  "wm",   P_NUM|P_VI_DEF,
   (char_u *)&p_wm, PV_WM,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},
  {"wrapscan",    "ws",   P_BOOL|P_VI_DEF,
   (char_u *)&p_ws, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"write",       NULL,   P_BOOL|P_VI_DEF,
   (char_u *)&p_write, PV_NONE,
   {(char_u *)TRUE, (char_u *)0L} SCRIPTID_INIT},
  {"writeany",    "wa",   P_BOOL|P_VI_DEF,
   (char_u *)&p_wa, PV_NONE,
   {(char_u *)FALSE, (char_u *)0L} SCRIPTID_INIT},
  {"writebackup", "wb",   P_BOOL|P_VI_DEF|P_VIM,
   (char_u *)&p_wb, PV_NONE,
   {
     (char_u *)TRUE,
     (char_u *)0L
   } SCRIPTID_INIT},
  {"writedelay",  "wd",   P_NUM|P_VI_DEF,
   (char_u *)&p_wd, PV_NONE,
   {(char_u *)0L, (char_u *)0L} SCRIPTID_INIT},

  /* terminal output codes */
#define p_term(sss, vvv)   {sss, NULL, P_STRING|P_VI_DEF|P_RALL|P_SECURE, \
                            (char_u *)&vvv, PV_NONE, \
                            {(char_u *)"", (char_u *)0L} SCRIPTID_INIT},

  p_term("t_AB", T_CAB)
  p_term("t_AF", T_CAF)
  p_term("t_AL", T_CAL)
  p_term("t_al", T_AL)
  p_term("t_bc", T_BC)
  p_term("t_cd", T_CD)
  p_term("t_ce", T_CE)
  p_term("t_cl", T_CL)
  p_term("t_cm", T_CM)
  p_term("t_Co", T_CCO)
  p_term("t_CS", T_CCS)
  p_term("t_cs", T_CS)
  p_term("t_CV", T_CSV)
  p_term("t_ut", T_UT)
  p_term("t_da", T_DA)
  p_term("t_db", T_DB)
  p_term("t_DL", T_CDL)
  p_term("t_dl", T_DL)
  p_term("t_fs", T_FS)
  p_term("t_IE", T_CIE)
  p_term("t_IS", T_CIS)
  p_term("t_ke", T_KE)
  p_term("t_ks", T_KS)
  p_term("t_le", T_LE)
  p_term("t_mb", T_MB)
  p_term("t_md", T_MD)
  p_term("t_me", T_ME)
  p_term("t_mr", T_MR)
  p_term("t_ms", T_MS)
  p_term("t_nd", T_ND)
  p_term("t_op", T_OP)
  p_term("t_RI", T_CRI)
  p_term("t_RV", T_CRV)
  p_term("t_u7", T_U7)
  p_term("t_Sb", T_CSB)
  p_term("t_Sf", T_CSF)
  p_term("t_se", T_SE)
  p_term("t_so", T_SO)
  p_term("t_sr", T_SR)
  p_term("t_ts", T_TS)
  p_term("t_te", T_TE)
  p_term("t_ti", T_TI)
  p_term("t_ue", T_UE)
  p_term("t_us", T_US)
  p_term("t_vb", T_VB)
  p_term("t_ve", T_VE)
  p_term("t_vi", T_VI)
  p_term("t_vs", T_VS)
  p_term("t_WP", T_CWP)
  p_term("t_WS", T_CWS)
  p_term("t_SI", T_CSI)
  p_term("t_EI", T_CEI)
  p_term("t_xs", T_XS)
  p_term("t_ZH", T_CZH)
  p_term("t_ZR", T_CZR)

  /* terminal key codes are not in here */

  /* end marker */
  {
    NULL, NULL, 0, NULL, PV_NONE, {NULL, NULL} SCRIPTID_INIT
  }
};

#define PARAM_COUNT (sizeof(options) / sizeof(struct vimoption))

static char *(p_ambw_values[]) = {"single", "double", NULL};
static char *(p_bg_values[]) = {"light", "dark", NULL};
static char *(p_nf_values[]) = {"octal", "hex", "alpha", NULL};
static char *(p_ff_values[]) = {FF_UNIX, FF_DOS, FF_MAC, NULL};
static char *(p_cm_values[]) = {"zip", "blowfish", NULL};
static char *(p_wop_values[]) = {"tagfile", NULL};
static char *(p_wak_values[]) = {"yes", "menu", "no", NULL};
static char *(p_mousem_values[]) =
{"extend", "popup", "popup_setpos", "mac", NULL};
static char *(p_sel_values[]) = {"inclusive", "exclusive", "old", NULL};
static char *(p_slm_values[]) = {"mouse", "key", "cmd", NULL};
static char *(p_km_values[]) = {"startsel", "stopsel", NULL};
static char *(p_scbopt_values[]) = {"ver", "hor", "jump", NULL};
static char *(p_debug_values[]) = {"msg", "throw", "beep", NULL};
static char *(p_ead_values[]) = {"both", "ver", "hor", NULL};
static char *(p_buftype_values[]) =
{"nofile", "nowrite", "quickfix", "help", "acwrite", NULL};
static char *(p_bufhidden_values[]) = {"hide", "unload", "delete", "wipe", NULL};
static char *(p_bs_values[]) = {"indent", "eol", "start", NULL};
static char *(p_fdm_values[]) = {"manual", "expr", "marker", "indent", "syntax",
                                 "diff",
                                 NULL};
static char *(p_fcl_values[]) = {"all", NULL};
static char *(p_cot_values[]) = {"menu", "menuone", "longest", "preview", NULL};

static void set_option_default(int, int opt_flags, int compatible);
static void set_options_default(int opt_flags);
static char_u *term_bg_default(void);
static void did_set_option(int opt_idx, int opt_flags, int new_value);
static char_u *illegal_char(char_u *, int);
static int string_to_key(char_u *arg);
static char_u *check_cedit(void);
static void did_set_title(int icon);
static char_u *option_expand(int opt_idx, char_u *val);
static void didset_options(void);
static void check_string_option(char_u **pp);
static long_u *insecure_flag(int opt_idx, int opt_flags);
static void set_string_option_global(int opt_idx, char_u **varp);
static char_u *set_string_option(int opt_idx, char_u *value,
                                 int opt_flags);
static char_u *did_set_string_option(int opt_idx, char_u **varp,
                                     int new_value_alloced,
                                     char_u *oldval, char_u *errbuf,
                                     int opt_flags);
static char_u *set_chars_option(char_u **varp);
static int int_cmp(const void *a, const void *b);
static char_u *compile_cap_prog(synblock_T *synblock);
static void set_option_scriptID_idx(int opt_idx, int opt_flags, int id);
static char_u *set_bool_option(int opt_idx, char_u *varp, int value,
                               int opt_flags);
static char_u *set_num_option(int opt_idx, char_u *varp, long value,
                              char_u *errbuf, size_t errbuflen,
                              int opt_flags);
static void check_redraw(long_u flags);
static int findoption(char_u *);
static int find_key_option(char_u *);
static void showoptions(int all, int opt_flags);
static int optval_default(struct vimoption *, char_u *varp);
static void showoneopt(struct vimoption *, int opt_flags);
static int put_setstring(FILE *fd, char *cmd, char *name, char_u **valuep,
                         int expand);
static int put_setnum(FILE *fd, char *cmd, char *name, long *valuep);
static int put_setbool(FILE *fd, char *cmd, char *name, int value);
static int istermoption(struct vimoption *);
static char_u *get_varp_scope(struct vimoption *p, int opt_flags);
static char_u *get_varp(struct vimoption *);
static void option_value2string(struct vimoption *, int opt_flags);
static int wc_use_keyname(char_u *varp, long *wcp);
static void langmap_init(void);
static void langmap_set(void);
static void paste_option_changed(void);
static void compatible_set(void);
static void fill_breakat_flags(void);
static int opt_strings_flags(char_u *val, char **values,
                             unsigned *flagp,
                             int list);
static int check_opt_strings(char_u *val, char **values, int);
static int check_opt_wim(void);

/*
 * Initialize the options, first part.
 *
 * Called only once from main(), just after creating the first buffer.
 */
void set_init_1(void)          {
  char_u      *p;
  int opt_idx;
  long_u n;

  langmap_init();

  /* Be Vi compatible by default */
  p_cp = TRUE;

  /* Use POSIX compatibility when $VIM_POSIX is set. */
  if (mch_getenv((char_u *)"VIM_POSIX") != NULL) {
    set_string_default("cpo", (char_u *)CPO_ALL);
    set_string_default("shm", (char_u *)"A");
  }

  /*
   * Find default value for 'shell' option.
   * Don't use it if it is empty.
   */
  if (((p = mch_getenv((char_u *)"SHELL")) != NULL && *p != NUL)
      )
    set_string_default("sh", p);

  /*
   * Set the default for 'backupskip' to include environment variables for
   * temp files.
   */
  {
# ifdef UNIX
    static char     *(names[4]) = {"", "TMPDIR", "TEMP", "TMP"};
# else
    static char     *(names[3]) = {"TMPDIR", "TEMP", "TMP"};
# endif
    int len;
    garray_T ga;
    int mustfree;

    ga_init2(&ga, 1, 100);
    for (n = 0; n < (long)(sizeof(names) / sizeof(char *)); ++n) {
      mustfree = FALSE;
# ifdef UNIX
      if (*names[n] == NUL)
        p = (char_u *)"/tmp";
      else
# endif
      p = vim_getenv((char_u *)names[n], &mustfree);
      if (p != NULL && *p != NUL) {
        /* First time count the NUL, otherwise count the ','. */
        len = (int)STRLEN(p) + 3;
        if (ga_grow(&ga, len) == OK) {
          if (ga.ga_len > 0)
            STRCAT(ga.ga_data, ",");
          STRCAT(ga.ga_data, p);
          add_pathsep(ga.ga_data);
          STRCAT(ga.ga_data, "*");
          ga.ga_len += len;
        }
      }
      if (mustfree)
        vim_free(p);
    }
    if (ga.ga_data != NULL) {
      set_string_default("bsk", ga.ga_data);
      vim_free(ga.ga_data);
    }
  }

  /*
   * 'maxmemtot' and 'maxmem' may have to be adjusted for available memory
   */
  opt_idx = findoption((char_u *)"maxmemtot");
  if (opt_idx >= 0) {
#if !defined(HAVE_AVAIL_MEM) && !defined(HAVE_TOTAL_MEM)
    if (options[opt_idx].def_val[VI_DEFAULT] == (char_u *)0L)
#endif
    {
#ifdef HAVE_AVAIL_MEM
      /* Use amount of memory available at this moment. */
      n = (mch_avail_mem(FALSE) >> 1);
#else
# ifdef HAVE_TOTAL_MEM
      /* Use amount of memory available to Vim. */
      n = (mch_total_mem(FALSE) >> 1);
# else
      n = (0x7fffffff >> 11);
# endif
#endif
      options[opt_idx].def_val[VI_DEFAULT] = (char_u *)n;
      opt_idx = findoption((char_u *)"maxmem");
      if (opt_idx >= 0) {
#if !defined(HAVE_AVAIL_MEM) && !defined(HAVE_TOTAL_MEM)
        if ((long)options[opt_idx].def_val[VI_DEFAULT] > (long)n
            || (long)options[opt_idx].def_val[VI_DEFAULT] == 0L)
#endif
        options[opt_idx].def_val[VI_DEFAULT] = (char_u *)n;
      }
    }
  }


  {
    char_u  *cdpath;
    char_u  *buf;
    int i;
    int j;
    int mustfree = FALSE;

    /* Initialize the 'cdpath' option's default value. */
    cdpath = vim_getenv((char_u *)"CDPATH", &mustfree);
    if (cdpath != NULL) {
      buf = alloc((unsigned)((STRLEN(cdpath) << 1) + 2));
      if (buf != NULL) {
        buf[0] = ',';               /* start with ",", current dir first */
        j = 1;
        for (i = 0; cdpath[i] != NUL; ++i) {
          if (vim_ispathlistsep(cdpath[i]))
            buf[j++] = ',';
          else {
            if (cdpath[i] == ' ' || cdpath[i] == ',')
              buf[j++] = '\\';
            buf[j++] = cdpath[i];
          }
        }
        buf[j] = NUL;
        opt_idx = findoption((char_u *)"cdpath");
        if (opt_idx >= 0) {
          options[opt_idx].def_val[VI_DEFAULT] = buf;
          options[opt_idx].flags |= P_DEF_ALLOCED;
        } else
          vim_free(buf);           /* cannot happen */
      }
      if (mustfree)
        vim_free(cdpath);
    }
  }

#if defined(FEAT_POSTSCRIPT) && (defined(MSWIN) || defined(OS2) || \
  defined(VMS) || defined(EBCDIC) || defined(MAC) || defined(hpux))
  /* Set print encoding on platforms that don't default to latin1 */
  set_string_default("penc",
      (char_u *)"hp-roman8"
      );
#endif

  /* 'printexpr' must be allocated to be able to evaluate it. */
  set_string_default(
      "pexpr",
      (char_u *)
      "system('lpr' . (&printdevice == '' ? '' : ' -P' . &printdevice) . ' ' . v:fname_in) . delete(v:fname_in) + v:shell_error"
      );

  /*
   * Set all the options (except the terminal options) to their default
   * value.  Also set the global value for local options.
   */
  set_options_default(0);


  curbuf->b_p_initialized = TRUE;
  curbuf->b_p_ar = -1;          /* no local 'autoread' value */
  curbuf->b_p_ul = NO_LOCAL_UNDOLEVEL;
  check_buf_options(curbuf);
  check_win_options(curwin);
  check_options();

  /* Must be before option_expand(), because that one needs vim_isIDc() */
  didset_options();

  /* Use the current chartab for the generic chartab. */
  init_spell_chartab();

  /*
   * initialize the table for 'breakat'.
   */
  fill_breakat_flags();

  /*
   * Expand environment variables and things like "~" for the defaults.
   * If option_expand() returns non-NULL the variable is expanded.  This can
   * only happen for non-indirect options.
   * Also set the default to the expanded value, so ":set" does not list
   * them.
   * Don't set the P_ALLOCED flag, because we don't want to free the
   * default.
   */
  for (opt_idx = 0; !istermoption(&options[opt_idx]); opt_idx++) {
    if ((options[opt_idx].flags & P_GETTEXT)
        && options[opt_idx].var != NULL)
      p = (char_u *)_(*(char **)options[opt_idx].var);
    else
      p = option_expand(opt_idx, NULL);
    if (p != NULL && (p = vim_strsave(p)) != NULL) {
      *(char_u **)options[opt_idx].var = p;
      /* VIMEXP
       * Defaults for all expanded options are currently the same for Vi
       * and Vim.  When this changes, add some code here!  Also need to
       * split P_DEF_ALLOCED in two.
       */
      if (options[opt_idx].flags & P_DEF_ALLOCED)
        vim_free(options[opt_idx].def_val[VI_DEFAULT]);
      options[opt_idx].def_val[VI_DEFAULT] = p;
      options[opt_idx].flags |= P_DEF_ALLOCED;
    }
  }

  /* Initialize the highlight_attr[] table. */
  highlight_changed();

  save_file_ff(curbuf);         /* Buffer is unchanged */

  /* Parse default for 'wildmode'  */
  check_opt_wim();

  /* Detect use of mlterm.
   * Mlterm is a terminal emulator akin to xterm that has some special
   * abilities (bidi namely).
   * NOTE: mlterm's author is being asked to 'set' a variable
   *       instead of an environment variable due to inheritance.
   */
  if (mch_getenv((char_u *)"MLTERM") != NULL)
    set_option_value((char_u *)"tbidi", 1L, NULL, 0);

  /* Parse default for 'fillchars'. */
  (void)set_chars_option(&p_fcs);


#  ifdef MACOS_CONVERT
  /* Moved to os_mac_conv.c to avoid dependency problems. */
  mac_lang_init();
#  endif

  /* enc_locale() will try to find the encoding of the current locale. */
  p = enc_locale();
  if (p != NULL) {
    char_u *save_enc;

    /* Try setting 'encoding' and check if the value is valid.
     * If not, go back to the default "latin1". */
    save_enc = p_enc;
    p_enc = p;
    if (STRCMP(p_enc, "gb18030") == 0) {
      /* We don't support "gb18030", but "cp936" is a good substitute
       * for practical purposes, thus use that.  It's not an alias to
       * still support conversion between gb18030 and utf-8. */
      p_enc = vim_strsave((char_u *)"cp936");
      vim_free(p);
    }
    if (mb_init() == NULL) {
      opt_idx = findoption((char_u *)"encoding");
      if (opt_idx >= 0) {
        options[opt_idx].def_val[VI_DEFAULT] = p_enc;
        options[opt_idx].flags |= P_DEF_ALLOCED;
      }

#if defined(MSDOS) || defined(MSWIN) || defined(OS2) || defined(MACOS) \
      || defined(VMS)
      if (STRCMP(p_enc, "latin1") == 0
          || enc_utf8
          ) {
        /* Adjust the default for 'isprint' and 'iskeyword' to match
         * latin1.  Also set the defaults for when 'nocompatible' is
         * set. */
        set_string_option_direct((char_u *)"isp", -1,
            ISP_LATIN1, OPT_FREE, SID_NONE);
        set_string_option_direct((char_u *)"isk", -1,
            ISK_LATIN1, OPT_FREE, SID_NONE);
        opt_idx = findoption((char_u *)"isp");
        if (opt_idx >= 0)
          options[opt_idx].def_val[VIM_DEFAULT] = ISP_LATIN1;
        opt_idx = findoption((char_u *)"isk");
        if (opt_idx >= 0)
          options[opt_idx].def_val[VIM_DEFAULT] = ISK_LATIN1;
        (void)init_chartab();
      }
#endif

    } else   {
      vim_free(p_enc);
      p_enc = save_enc;
    }
  }

  /* Set the default for 'helplang'. */
  set_helplang_default(get_mess_lang());
}

/*
 * Set an option to its default value.
 * This does not take care of side effects!
 */
static void 
set_option_default (
    int opt_idx,
    int opt_flags,                  /* OPT_FREE, OPT_LOCAL and/or OPT_GLOBAL */
    int compatible                 /* use Vi default value */
)
{
  char_u      *varp;            /* pointer to variable for current option */
  int dvi;                      /* index in def_val[] */
  long_u flags;
  long_u      *flagsp;
  int both = (opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0;

  varp = get_varp_scope(&(options[opt_idx]), both ? OPT_LOCAL : opt_flags);
  flags = options[opt_idx].flags;
  if (varp != NULL) {       /* skip hidden option, nothing to do for it */
    dvi = ((flags & P_VI_DEF) || compatible) ? VI_DEFAULT : VIM_DEFAULT;
    if (flags & P_STRING) {
      /* Use set_string_option_direct() for local options to handle
       * freeing and allocating the value. */
      if (options[opt_idx].indir != PV_NONE)
        set_string_option_direct(NULL, opt_idx,
            options[opt_idx].def_val[dvi], opt_flags, 0);
      else {
        if ((opt_flags & OPT_FREE) && (flags & P_ALLOCED))
          free_string_option(*(char_u **)(varp));
        *(char_u **)varp = options[opt_idx].def_val[dvi];
        options[opt_idx].flags &= ~P_ALLOCED;
      }
    } else if (flags & P_NUM)   {
      if (options[opt_idx].indir == PV_SCROLL)
        win_comp_scroll(curwin);
      else {
        *(long *)varp = (long)(long_i)options[opt_idx].def_val[dvi];
        /* May also set global value for local option. */
        if (both)
          *(long *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL) =
            *(long *)varp;
      }
    } else   {  /* P_BOOL */
      /* the cast to long is required for Manx C, long_i is needed for
       * MSVC */
      *(int *)varp = (int)(long)(long_i)options[opt_idx].def_val[dvi];
#ifdef UNIX
      /* 'modeline' defaults to off for root */
      if (options[opt_idx].indir == PV_ML && getuid() == ROOT_UID)
        *(int *)varp = FALSE;
#endif
      /* May also set global value for local option. */
      if (both)
        *(int *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL) =
          *(int *)varp;
    }

    /* The default value is not insecure. */
    flagsp = insecure_flag(opt_idx, opt_flags);
    *flagsp = *flagsp & ~P_INSECURE;
  }

  set_option_scriptID_idx(opt_idx, opt_flags, current_SID);
}

/*
 * Set all options (except terminal options) to their default value.
 */
static void 
set_options_default (
    int opt_flags                  /* OPT_FREE, OPT_LOCAL and/or OPT_GLOBAL */
)
{
  int i;
  win_T       *wp;
  tabpage_T   *tp;

  for (i = 0; !istermoption(&options[i]); i++)
    if (!(options[i].flags & P_NODEFAULT))
      set_option_default(i, opt_flags, p_cp);

  /* The 'scroll' option must be computed for all windows. */
  FOR_ALL_TAB_WINDOWS(tp, wp)
  win_comp_scroll(wp);
}

/*
 * Set the Vi-default value of a string option.
 * Used for 'sh', 'backupskip' and 'term'.
 */
void set_string_default(char *name, char_u *val)
{
  char_u      *p;
  int opt_idx;

  p = vim_strsave(val);
  if (p != NULL) {              /* we don't want a NULL */
    opt_idx = findoption((char_u *)name);
    if (opt_idx >= 0) {
      if (options[opt_idx].flags & P_DEF_ALLOCED)
        vim_free(options[opt_idx].def_val[VI_DEFAULT]);
      options[opt_idx].def_val[VI_DEFAULT] = p;
      options[opt_idx].flags |= P_DEF_ALLOCED;
    }
  }
}

/*
 * Set the Vi-default value of a number option.
 * Used for 'lines' and 'columns'.
 */
void set_number_default(char *name, long val)
{
  int opt_idx;

  opt_idx = findoption((char_u *)name);
  if (opt_idx >= 0)
    options[opt_idx].def_val[VI_DEFAULT] = (char_u *)(long_i)val;
}

#if defined(EXITFREE) || defined(PROTO)
/*
 * Free all options.
 */
void free_all_options(void)          {
  int i;

  for (i = 0; !istermoption(&options[i]); i++) {
    if (options[i].indir == PV_NONE) {
      /* global option: free value and default value. */
      if (options[i].flags & P_ALLOCED && options[i].var != NULL)
        free_string_option(*(char_u **)options[i].var);
      if (options[i].flags & P_DEF_ALLOCED)
        free_string_option(options[i].def_val[VI_DEFAULT]);
    } else if (options[i].var != VAR_WIN
               && (options[i].flags & P_STRING))
      /* buffer-local option: free global value */
      free_string_option(*(char_u **)options[i].var);
  }
}

#endif


/*
 * Initialize the options, part two: After getting Rows and Columns and
 * setting 'term'.
 */
void set_init_2(void)          {
  int idx;

  /*
   * 'scroll' defaults to half the window height. Note that this default is
   * wrong when the window height changes.
   */
  set_number_default("scroll", (long)((long_u)Rows >> 1));
  idx = findoption((char_u *)"scroll");
  if (idx >= 0 && !(options[idx].flags & P_WAS_SET))
    set_option_default(idx, OPT_LOCAL, p_cp);
  comp_col();

  /*
   * 'window' is only for backwards compatibility with Vi.
   * Default is Rows - 1.
   */
  if (!option_was_set((char_u *)"window"))
    p_window = Rows - 1;
  set_number_default("window", Rows - 1);

  /* For DOS console the default is always black. */
  /*
   * If 'background' wasn't set by the user, try guessing the value,
   * depending on the terminal name.  Only need to check for terminals
   * with a dark background, that can handle color.
   */
  idx = findoption((char_u *)"bg");
  if (idx >= 0 && !(options[idx].flags & P_WAS_SET)
      && *term_bg_default() == 'd') {
    set_string_option_direct(NULL, idx, (char_u *)"dark", OPT_FREE, 0);
    /* don't mark it as set, when starting the GUI it may be
     * changed again */
    options[idx].flags &= ~P_WAS_SET;
  }

#ifdef CURSOR_SHAPE
  parse_shape_opt(SHAPE_CURSOR);   /* set cursor shapes from 'guicursor' */
#endif
  (void)parse_printoptions();       /* parse 'printoptions' default value */
}

/*
 * Return "dark" or "light" depending on the kind of terminal.
 * This is just guessing!  Recognized are:
 * "linux"	    Linux console
 * "screen.linux"   Linux console with screen
 * "cygwin"	    Cygwin shell
 * "putty"	    Putty program
 * We also check the COLORFGBG environment variable, which is set by
 * rxvt and derivatives. This variable contains either two or three
 * values separated by semicolons; we want the last value in either
 * case. If this value is 0-6 or 8, our background is dark.
 */
static char_u *term_bg_default(void)                     {
  char_u      *p;

  if (STRCMP(T_NAME, "linux") == 0
      || STRCMP(T_NAME, "screen.linux") == 0
      || STRCMP(T_NAME, "cygwin") == 0
      || STRCMP(T_NAME, "putty") == 0
      || ((p = mch_getenv((char_u *)"COLORFGBG")) != NULL
          && (p = vim_strrchr(p, ';')) != NULL
          && ((p[1] >= '0' && p[1] <= '6') || p[1] == '8')
          && p[2] == NUL))
    return (char_u *)"dark";
  return (char_u *)"light";
}

/*
 * Initialize the options, part three: After reading the .vimrc
 */
void set_init_3(void)          {
#if defined(UNIX) || defined(OS2) || defined(WIN3264)
  /*
   * Set 'shellpipe' and 'shellredir', depending on the 'shell' option.
   * This is done after other initializations, where 'shell' might have been
   * set, but only if they have not been set before.
   */
  char_u  *p;
  int idx_srr;
  int do_srr;
  int idx_sp;
  int do_sp;

  idx_srr = findoption((char_u *)"srr");
  if (idx_srr < 0)
    do_srr = FALSE;
  else
    do_srr = !(options[idx_srr].flags & P_WAS_SET);
  idx_sp = findoption((char_u *)"sp");
  if (idx_sp < 0)
    do_sp = FALSE;
  else
    do_sp = !(options[idx_sp].flags & P_WAS_SET);

  /*
   * Isolate the name of the shell:
   * - Skip beyond any path.  E.g., "/usr/bin/csh -f" -> "csh -f".
   * - Remove any argument.  E.g., "csh -f" -> "csh".
   * But don't allow a space in the path, so that this works:
   *   "/usr/bin/csh --rcfile ~/.cshrc"
   * But don't do that for Windows, it's common to have a space in the path.
   */
  p = skiptowhite(p_sh);
  if (*p == NUL) {
    /* No white space, use the tail. */
    p = vim_strsave(gettail(p_sh));
  } else   {
    char_u  *p1, *p2;

    /* Find the last path separator before the space. */
    p1 = p_sh;
    for (p2 = p_sh; p2 < p; mb_ptr_adv(p2))
      if (vim_ispathsep(*p2))
        p1 = p2 + 1;
    p = vim_strnsave(p1, (int)(p - p1));
  }
  if (p != NULL) {
    /*
     * Default for p_sp is "| tee", for p_srr is ">".
     * For known shells it is changed here to include stderr.
     */
    if (       fnamecmp(p, "csh") == 0
               || fnamecmp(p, "tcsh") == 0
               ) {
      if (do_sp) {
        p_sp = (char_u *)"|& tee";
        options[idx_sp].def_val[VI_DEFAULT] = p_sp;
      }
      if (do_srr) {
        p_srr = (char_u *)">&";
        options[idx_srr].def_val[VI_DEFAULT] = p_srr;
      }
    } else if (       fnamecmp(p, "sh") == 0
                      || fnamecmp(p, "ksh") == 0
                      || fnamecmp(p, "mksh") == 0
                      || fnamecmp(p, "pdksh") == 0
                      || fnamecmp(p, "zsh") == 0
                      || fnamecmp(p, "zsh-beta") == 0
                      || fnamecmp(p, "bash") == 0
                      ) {
      if (do_sp) {
        p_sp = (char_u *)"2>&1| tee";
        options[idx_sp].def_val[VI_DEFAULT] = p_sp;
      }
      if (do_srr) {
        p_srr = (char_u *)">%s 2>&1";
        options[idx_srr].def_val[VI_DEFAULT] = p_srr;
      }
    }
    vim_free(p);
  }
#endif


  set_title_defaults();
}

/*
 * When 'helplang' is still at its default value, set it to "lang".
 * Only the first two characters of "lang" are used.
 */
void set_helplang_default(char_u *lang)
{
  int idx;

  if (lang == NULL || STRLEN(lang) < 2)         /* safety check */
    return;
  idx = findoption((char_u *)"hlg");
  if (idx >= 0 && !(options[idx].flags & P_WAS_SET)) {
    if (options[idx].flags & P_ALLOCED)
      free_string_option(p_hlg);
    p_hlg = vim_strsave(lang);
    if (p_hlg == NULL)
      p_hlg = empty_option;
    else {
      /* zh_CN becomes "cn", zh_TW becomes "tw". */
      if (STRNICMP(p_hlg, "zh_", 3) == 0 && STRLEN(p_hlg) >= 5) {
        p_hlg[0] = TOLOWER_ASC(p_hlg[3]);
        p_hlg[1] = TOLOWER_ASC(p_hlg[4]);
      }
      p_hlg[2] = NUL;
    }
    options[idx].flags |= P_ALLOCED;
  }
}


/*
 * 'title' and 'icon' only default to true if they have not been set or reset
 * in .vimrc and we can read the old value.
 * When 'title' and 'icon' have been reset in .vimrc, we won't even check if
 * they can be reset.  This reduces startup time when using X on a remote
 * machine.
 */
void set_title_defaults(void)          {
  int idx1;
  long val;

  /*
   * If GUI is (going to be) used, we can always set the window title and
   * icon name.  Saves a bit of time, because the X11 display server does
   * not need to be contacted.
   */
  idx1 = findoption((char_u *)"title");
  if (idx1 >= 0 && !(options[idx1].flags & P_WAS_SET)) {
    val = mch_can_restore_title();
    options[idx1].def_val[VI_DEFAULT] = (char_u *)(long_i)val;
    p_title = val;
  }
  idx1 = findoption((char_u *)"icon");
  if (idx1 >= 0 && !(options[idx1].flags & P_WAS_SET)) {
    val = mch_can_restore_icon();
    options[idx1].def_val[VI_DEFAULT] = (char_u *)(long_i)val;
    p_icon = val;
  }
}

/*
 * Parse 'arg' for option settings.
 *
 * 'arg' may be IObuff, but only when no errors can be present and option
 * does not need to be expanded with option_expand().
 * "opt_flags":
 * 0 for ":set"
 * OPT_GLOBAL   for ":setglobal"
 * OPT_LOCAL    for ":setlocal" and a modeline
 * OPT_MODELINE for a modeline
 * OPT_WINONLY  to only set window-local options
 * OPT_NOWIN	to skip setting window-local options
 *
 * returns FAIL if an error is detected, OK otherwise
 */
int 
do_set (
    char_u *arg,               /* option string (may be written to!) */
    int opt_flags
)
{
  int opt_idx;
  char_u      *errmsg;
  char_u errbuf[80];
  char_u      *startarg;
  int prefix;           /* 1: nothing, 0: "no", 2: "inv" in front of name */
  int nextchar;                     /* next non-white char after option name */
  int afterchar;                    /* character just after option name */
  int len;
  int i;
  long value;
  int key;
  long_u flags;                     /* flags for current option */
  char_u      *varp = NULL;         /* pointer to variable for current option */
  int did_show = FALSE;             /* already showed one value */
  int adding;                       /* "opt+=arg" */
  int prepending;                   /* "opt^=arg" */
  int removing;                     /* "opt-=arg" */
  int cp_val = 0;
  char_u key_name[2];

  if (*arg == NUL) {
    showoptions(0, opt_flags);
    did_show = TRUE;
    goto theend;
  }

  while (*arg != NUL) {         /* loop to process all options */
    errmsg = NULL;
    startarg = arg;             /* remember for error message */

    if (STRNCMP(arg, "all", 3) == 0 && !isalpha(arg[3])
        && !(opt_flags & OPT_MODELINE)) {
      /*
       * ":set all"  show all options.
       * ":set all&" set all options to their default value.
       */
      arg += 3;
      if (*arg == '&') {
        ++arg;
        /* Only for :set command set global value of local options. */
        set_options_default(OPT_FREE | opt_flags);
      } else   {
        showoptions(1, opt_flags);
        did_show = TRUE;
      }
    } else if (STRNCMP(arg, "termcap",
                   7) == 0 && !(opt_flags & OPT_MODELINE))   {
      showoptions(2, opt_flags);
      show_termcodes();
      did_show = TRUE;
      arg += 7;
    } else   {
      prefix = 1;
      if (STRNCMP(arg, "no", 2) == 0 && STRNCMP(arg, "novice", 6) != 0) {
        prefix = 0;
        arg += 2;
      } else if (STRNCMP(arg, "inv", 3) == 0)   {
        prefix = 2;
        arg += 3;
      }

      /* find end of name */
      key = 0;
      if (*arg == '<') {
        nextchar = 0;
        opt_idx = -1;
        /* look out for <t_>;> */
        if (arg[1] == 't' && arg[2] == '_' && arg[3] && arg[4])
          len = 5;
        else {
          len = 1;
          while (arg[len] != NUL && arg[len] != '>')
            ++len;
        }
        if (arg[len] != '>') {
          errmsg = e_invarg;
          goto skip;
        }
        arg[len] = NUL;                             /* put NUL after name */
        if (arg[1] == 't' && arg[2] == '_')         /* could be term code */
          opt_idx = findoption(arg + 1);
        arg[len++] = '>';                           /* restore '>' */
        if (opt_idx == -1)
          key = find_key_option(arg + 1);
      } else   {
        len = 0;
        /*
         * The two characters after "t_" may not be alphanumeric.
         */
        if (arg[0] == 't' && arg[1] == '_' && arg[2] && arg[3])
          len = 4;
        else
          while (ASCII_ISALNUM(arg[len]) || arg[len] == '_')
            ++len;
        nextchar = arg[len];
        arg[len] = NUL;                             /* put NUL after name */
        opt_idx = findoption(arg);
        arg[len] = nextchar;                        /* restore nextchar */
        if (opt_idx == -1)
          key = find_key_option(arg);
      }

      /* remember character after option name */
      afterchar = arg[len];

      /* skip white space, allow ":set ai  ?" */
      while (vim_iswhite(arg[len]))
        ++len;

      adding = FALSE;
      prepending = FALSE;
      removing = FALSE;
      if (arg[len] != NUL && arg[len + 1] == '=') {
        if (arg[len] == '+') {
          adding = TRUE;                        /* "+=" */
          ++len;
        } else if (arg[len] == '^')   {
          prepending = TRUE;                    /* "^=" */
          ++len;
        } else if (arg[len] == '-')   {
          removing = TRUE;                      /* "-=" */
          ++len;
        }
      }
      nextchar = arg[len];

      if (opt_idx == -1 && key == 0) {          /* found a mismatch: skip */
        errmsg = (char_u *)N_("E518: Unknown option");
        goto skip;
      }

      if (opt_idx >= 0) {
        if (options[opt_idx].var == NULL) {         /* hidden option: skip */
          /* Only give an error message when requesting the value of
           * a hidden option, ignore setting it. */
          if (vim_strchr((char_u *)"=:!&<", nextchar) == NULL
              && (!(options[opt_idx].flags & P_BOOL)
                  || nextchar == '?'))
            errmsg = (char_u *)N_("E519: Option not supported");
          goto skip;
        }

        flags = options[opt_idx].flags;
        varp = get_varp_scope(&(options[opt_idx]), opt_flags);
      } else   {
        flags = P_STRING;
        if (key < 0) {
          key_name[0] = KEY2TERMCAP0(key);
          key_name[1] = KEY2TERMCAP1(key);
        } else   {
          key_name[0] = KS_KEY;
          key_name[1] = (key & 0xff);
        }
      }

      /* Skip all options that are not window-local (used when showing
       * an already loaded buffer in a window). */
      if ((opt_flags & OPT_WINONLY)
          && (opt_idx < 0 || options[opt_idx].var != VAR_WIN))
        goto skip;

      /* Skip all options that are window-local (used for :vimgrep). */
      if ((opt_flags & OPT_NOWIN) && opt_idx >= 0
          && options[opt_idx].var == VAR_WIN)
        goto skip;

      /* Disallow changing some options from modelines. */
      if (opt_flags & OPT_MODELINE) {
        if (flags & (P_SECURE | P_NO_ML)) {
          errmsg = (char_u *)_("E520: Not allowed in a modeline");
          goto skip;
        }
        /* In diff mode some options are overruled.  This avoids that
         * 'foldmethod' becomes "marker" instead of "diff" and that
         * "wrap" gets set. */
        if (curwin->w_p_diff
            && opt_idx >= 0              /* shut up coverity warning */
            && (options[opt_idx].indir == PV_FDM
                || options[opt_idx].indir == PV_WRAP))
          goto skip;
      }

#ifdef HAVE_SANDBOX
      /* Disallow changing some options in the sandbox */
      if (sandbox != 0 && (flags & P_SECURE)) {
        errmsg = (char_u *)_(e_sandbox);
        goto skip;
      }
#endif

      if (vim_strchr((char_u *)"?=:!&<", nextchar) != NULL) {
        arg += len;
        cp_val = p_cp;
        if (nextchar == '&' && arg[1] == 'v' && arg[2] == 'i') {
          if (arg[3] == 'm') {          /* "opt&vim": set to Vim default */
            cp_val = FALSE;
            arg += 3;
          } else   {                    /* "opt&vi": set to Vi default */
            cp_val = TRUE;
            arg += 2;
          }
        }
        if (vim_strchr((char_u *)"?!&<", nextchar) != NULL
            && arg[1] != NUL && !vim_iswhite(arg[1])) {
          errmsg = e_trailing;
          goto skip;
        }
      }

      /*
       * allow '=' and ':' as MSDOS command.com allows only one
       * '=' character per "set" command line. grrr. (jw)
       */
      if (nextchar == '?'
          || (prefix == 1
              && vim_strchr((char_u *)"=:&<", nextchar) == NULL
              && !(flags & P_BOOL))) {
        /*
         * print value
         */
        if (did_show)
          msg_putchar('\n');                /* cursor below last one */
        else {
          gotocmdline(TRUE);                /* cursor at status line */
          did_show = TRUE;                  /* remember that we did a line */
        }
        if (opt_idx >= 0) {
          showoneopt(&options[opt_idx], opt_flags);
          if (p_verbose > 0) {
            /* Mention where the option was last set. */
            if (varp == options[opt_idx].var)
              last_set_msg(options[opt_idx].scriptID);
            else if ((int)options[opt_idx].indir & PV_WIN)
              last_set_msg(curwin->w_p_scriptID[
                    (int)options[opt_idx].indir & PV_MASK]);
            else if ((int)options[opt_idx].indir & PV_BUF)
              last_set_msg(curbuf->b_p_scriptID[
                    (int)options[opt_idx].indir & PV_MASK]);
          }
        } else   {
          char_u          *p;

          p = find_termcode(key_name);
          if (p == NULL) {
            errmsg = (char_u *)N_("E846: Key code not set");
            goto skip;
          } else
            (void)show_one_termcode(key_name, p, TRUE);
        }
        if (nextchar != '?'
            && nextchar != NUL && !vim_iswhite(afterchar))
          errmsg = e_trailing;
      } else   {
        if (flags & P_BOOL) {                       /* boolean */
          if (nextchar == '=' || nextchar == ':') {
            errmsg = e_invarg;
            goto skip;
          }

          /*
           * ":set opt!": invert
           * ":set opt&": reset to default value
           * ":set opt<": reset to global value
           */
          if (nextchar == '!')
            value = *(int *)(varp) ^ 1;
          else if (nextchar == '&')
            value = (int)(long)(long_i)options[opt_idx].def_val[
              ((flags & P_VI_DEF) || cp_val)
              ?  VI_DEFAULT : VIM_DEFAULT];
          else if (nextchar == '<') {
            /* For 'autoread' -1 means to use global value. */
            if ((int *)varp == &curbuf->b_p_ar
                && opt_flags == OPT_LOCAL)
              value = -1;
            else
              value = *(int *)get_varp_scope(&(options[opt_idx]),
                  OPT_GLOBAL);
          } else   {
            /*
             * ":set invopt": invert
             * ":set opt" or ":set noopt": set or reset
             */
            if (nextchar != NUL && !vim_iswhite(afterchar)) {
              errmsg = e_trailing;
              goto skip;
            }
            if (prefix == 2)                    /* inv */
              value = *(int *)(varp) ^ 1;
            else
              value = prefix;
          }

          errmsg = set_bool_option(opt_idx, varp, (int)value,
              opt_flags);
        } else   {                                  /* numeric or string */
          if (vim_strchr((char_u *)"=:&<", nextchar) == NULL
              || prefix != 1) {
            errmsg = e_invarg;
            goto skip;
          }

          if (flags & P_NUM) {                      /* numeric */
            /*
             * Different ways to set a number option:
             * &	    set to default value
             * <	    set to global value
             * <xx>	    accept special key codes for 'wildchar'
             * c	    accept any non-digit for 'wildchar'
             * [-]0-9   set number
             * other    error
             */
            ++arg;
            if (nextchar == '&')
              value = (long)(long_i)options[opt_idx].def_val[
                ((flags & P_VI_DEF) || cp_val)
                ?  VI_DEFAULT : VIM_DEFAULT];
            else if (nextchar == '<') {
              /* For 'undolevels' NO_LOCAL_UNDOLEVEL means to
               * use the global value. */
              if ((long *)varp == &curbuf->b_p_ul
                  && opt_flags == OPT_LOCAL)
                value = NO_LOCAL_UNDOLEVEL;
              else
                value = *(long *)get_varp_scope(
                    &(options[opt_idx]), OPT_GLOBAL);
            } else if (((long *)varp == &p_wc
                        || (long *)varp == &p_wcm)
                       && (*arg == '<'
                           || *arg == '^'
                           || ((!arg[1] || vim_iswhite(arg[1]))
                               && !VIM_ISDIGIT(*arg)))) {
              value = string_to_key(arg);
              if (value == 0 && (long *)varp != &p_wcm) {
                errmsg = e_invarg;
                goto skip;
              }
            }
            /* allow negative numbers (for 'undolevels') */
            else if (*arg == '-' || VIM_ISDIGIT(*arg)) {
              i = 0;
              if (*arg == '-')
                i = 1;
#ifdef HAVE_STRTOL
              value = strtol((char *)arg, NULL, 0);
              if (arg[i] == '0' && TOLOWER_ASC(arg[i + 1]) == 'x')
                i += 2;
#else
              value = atol((char *)arg);
#endif
              while (VIM_ISDIGIT(arg[i]))
                ++i;
              if (arg[i] != NUL && !vim_iswhite(arg[i])) {
                errmsg = e_invarg;
                goto skip;
              }
            } else   {
              errmsg = (char_u *)N_("E521: Number required after =");
              goto skip;
            }

            if (adding)
              value = *(long *)varp + value;
            if (prepending)
              value = *(long *)varp * value;
            if (removing)
              value = *(long *)varp - value;
            errmsg = set_num_option(opt_idx, varp, value,
                errbuf, sizeof(errbuf), opt_flags);
          } else if (opt_idx >= 0)   {                      /* string */
            char_u      *save_arg = NULL;
            char_u      *s = NULL;
            char_u      *oldval;                /* previous value if *varp */
            char_u      *newval;
            char_u      *origval;
            unsigned newlen;
            int comma;
            int bs;
            int new_value_alloced;                      /* new string option
                                                           was allocated */

            /* When using ":set opt=val" for a global option
             * with a local value the local value will be
             * reset, use the global value here. */
            if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0
                && ((int)options[opt_idx].indir & PV_BOTH))
              varp = options[opt_idx].var;

            /* The old value is kept until we are sure that the
             * new value is valid. */
            oldval = *(char_u **)varp;
            if (nextchar == '&') {              /* set to default val */
              newval = options[opt_idx].def_val[
                ((flags & P_VI_DEF) || cp_val)
                ?  VI_DEFAULT : VIM_DEFAULT];
              if ((char_u **)varp == &p_bg) {
                /* guess the value of 'background' */
                newval = term_bg_default();
              }

              /* expand environment variables and ~ (since the
               * default value was already expanded, only
               * required when an environment variable was set
               * later */
              if (newval == NULL)
                newval = empty_option;
              else {
                s = option_expand(opt_idx, newval);
                if (s == NULL)
                  s = newval;
                newval = vim_strsave(s);
              }
              new_value_alloced = TRUE;
            } else if (nextchar == '<')   {             /* set to global val */
              newval = vim_strsave(*(char_u **)get_varp_scope(
                      &(options[opt_idx]), OPT_GLOBAL));
              new_value_alloced = TRUE;
            } else   {
              ++arg;                    /* jump to after the '=' or ':' */

              /*
               * Set 'keywordprg' to ":help" if an empty
               * value was passed to :set by the user.
               * Misuse errbuf[] for the resulting string.
               */
              if (varp == (char_u *)&p_kp
                  && (*arg == NUL || *arg == ' ')) {
                STRCPY(errbuf, ":help");
                save_arg = arg;
                arg = errbuf;
              }
              /*
               * Convert 'backspace' number to string, for
               * adding, prepending and removing string.
               */
              else if (varp == (char_u *)&p_bs
                       && VIM_ISDIGIT(**(char_u **)varp)) {
                i = getdigits((char_u **)varp);
                switch (i) {
                case 0:
                  *(char_u **)varp = empty_option;
                  break;
                case 1:
                  *(char_u **)varp = vim_strsave(
                      (char_u *)"indent,eol");
                  break;
                case 2:
                  *(char_u **)varp = vim_strsave(
                      (char_u *)"indent,eol,start");
                  break;
                }
                vim_free(oldval);
                oldval = *(char_u **)varp;
              }
              /*
               * Convert 'whichwrap' number to string, for
               * backwards compatibility with Vim 3.0.
               * Misuse errbuf[] for the resulting string.
               */
              else if (varp == (char_u *)&p_ww
                       && VIM_ISDIGIT(*arg)) {
                *errbuf = NUL;
                i = getdigits(&arg);
                if (i & 1)
                  STRCAT(errbuf, "b,");
                if (i & 2)
                  STRCAT(errbuf, "s,");
                if (i & 4)
                  STRCAT(errbuf, "h,l,");
                if (i & 8)
                  STRCAT(errbuf, "<,>,");
                if (i & 16)
                  STRCAT(errbuf, "[,],");
                if (*errbuf != NUL)                     /* remove trailing , */
                  errbuf[STRLEN(errbuf) - 1] = NUL;
                save_arg = arg;
                arg = errbuf;
              }
              /*
               * Remove '>' before 'dir' and 'bdir', for
               * backwards compatibility with version 3.0
               */
              else if (  *arg == '>'
                         && (varp == (char_u *)&p_dir
                             || varp == (char_u *)&p_bdir)) {
                ++arg;
              }

              /* When setting the local value of a global
               * option, the old value may be the global value. */
              if (((int)options[opt_idx].indir & PV_BOTH)
                  && (opt_flags & OPT_LOCAL))
                origval = *(char_u **)get_varp(
                    &options[opt_idx]);
              else
                origval = oldval;

              /*
               * Copy the new string into allocated memory.
               * Can't use set_string_option_direct(), because
               * we need to remove the backslashes.
               */
              /* get a bit too much */
              newlen = (unsigned)STRLEN(arg) + 1;
              if (adding || prepending || removing)
                newlen += (unsigned)STRLEN(origval) + 1;
              newval = alloc(newlen);
              if (newval == NULL)                /* out of mem, don't change */
                break;
              s = newval;

              /*
               * Copy the string, skip over escaped chars.
               * For MS-DOS and WIN32 backslashes before normal
               * file name characters are not removed, and keep
               * backslash at start, for "\\machine\path", but
               * do remove it for "\\\\machine\\path".
               * The reverse is found in ExpandOldSetting().
               */
              while (*arg && !vim_iswhite(*arg)) {
                if (*arg == '\\' && arg[1] != NUL
#ifdef BACKSLASH_IN_FILENAME
                    && !((flags & P_EXPAND)
                         && vim_isfilec(arg[1])
                         && (arg[1] != '\\'
                             || (s == newval
                                 && arg[2] != '\\')))
#endif
                    )
                  ++arg;                        /* remove backslash */
                if (has_mbyte
                    && (i = (*mb_ptr2len)(arg)) > 1) {
                  /* copy multibyte char */
                  mch_memmove(s, arg, (size_t)i);
                  arg += i;
                  s += i;
                } else
                  *s++ = *arg++;
              }
              *s = NUL;

              /*
               * Expand environment variables and ~.
               * Don't do it when adding without inserting a
               * comma.
               */
              if (!(adding || prepending || removing)
                  || (flags & P_COMMA)) {
                s = option_expand(opt_idx, newval);
                if (s != NULL) {
                  vim_free(newval);
                  newlen = (unsigned)STRLEN(s) + 1;
                  if (adding || prepending || removing)
                    newlen += (unsigned)STRLEN(origval) + 1;
                  newval = alloc(newlen);
                  if (newval == NULL)
                    break;
                  STRCPY(newval, s);
                }
              }

              /* locate newval[] in origval[] when removing it
               * and when adding to avoid duplicates */
              i = 0;                    /* init for GCC */
              if (removing || (flags & P_NODUP)) {
                i = (int)STRLEN(newval);
                bs = 0;
                for (s = origval; *s; ++s) {
                  if ((!(flags & P_COMMA)
                       || s == origval
                       || (s[-1] == ',' && !(bs & 1)))
                      && STRNCMP(s, newval, i) == 0
                      && (!(flags & P_COMMA)
                          || s[i] == ','
                          || s[i] == NUL))
                    break;
                  /* Count backslashes.  Only a comma with an
                   * even number of backslashes before it is
                   * recognized as a separator */
                  if (s > origval && s[-1] == '\\')
                    ++bs;
                  else
                    bs = 0;
                }

                /* do not add if already there */
                if ((adding || prepending) && *s) {
                  prepending = FALSE;
                  adding = FALSE;
                  STRCPY(newval, origval);
                }
              }

              /* concatenate the two strings; add a ',' if
               * needed */
              if (adding || prepending) {
                comma = ((flags & P_COMMA) && *origval != NUL
                         && *newval != NUL);
                if (adding) {
                  i = (int)STRLEN(origval);
                  mch_memmove(newval + i + comma, newval,
                      STRLEN(newval) + 1);
                  mch_memmove(newval, origval, (size_t)i);
                } else   {
                  i = (int)STRLEN(newval);
                  STRMOVE(newval + i + comma, origval);
                }
                if (comma)
                  newval[i] = ',';
              }

              /* Remove newval[] from origval[]. (Note: "i" has
               * been set above and is used here). */
              if (removing) {
                STRCPY(newval, origval);
                if (*s) {
                  /* may need to remove a comma */
                  if (flags & P_COMMA) {
                    if (s == origval) {
                      /* include comma after string */
                      if (s[i] == ',')
                        ++i;
                    } else   {
                      /* include comma before string */
                      --s;
                      ++i;
                    }
                  }
                  STRMOVE(newval + (s - origval), s + i);
                }
              }

              if (flags & P_FLAGLIST) {
                /* Remove flags that appear twice. */
                for (s = newval; *s; ++s)
                  if ((!(flags & P_COMMA) || *s != ',')
                      && vim_strchr(s + 1, *s) != NULL) {
                    STRMOVE(s, s + 1);
                    --s;
                  }
              }

              if (save_arg != NULL)                 /* number for 'whichwrap' */
                arg = save_arg;
              new_value_alloced = TRUE;
            }

            /* Set the new value. */
            *(char_u **)(varp) = newval;

            /* Handle side effects, and set the global value for
             * ":set" on local options. */
            errmsg = did_set_string_option(opt_idx, (char_u **)varp,
                new_value_alloced, oldval, errbuf, opt_flags);

            /* If error detected, print the error message. */
            if (errmsg != NULL)
              goto skip;
          } else   {                /* key code option */
            char_u      *p;

            if (nextchar == '&') {
              if (add_termcap_entry(key_name, TRUE) == FAIL)
                errmsg = (char_u *)N_("E522: Not found in termcap");
            } else   {
              ++arg;               /* jump to after the '=' or ':' */
              for (p = arg; *p && !vim_iswhite(*p); ++p)
                if (*p == '\\' && p[1] != NUL)
                  ++p;
              nextchar = *p;
              *p = NUL;
              add_termcode(key_name, arg, FALSE);
              *p = nextchar;
            }
            if (full_screen)
              ttest(FALSE);
            redraw_all_later(CLEAR);
          }
        }

        if (opt_idx >= 0)
          did_set_option(opt_idx, opt_flags,
              !prepending && !adding && !removing);
      }

skip:
      /*
       * Advance to next argument.
       * - skip until a blank found, taking care of backslashes
       * - skip blanks
       * - skip one "=val" argument (for hidden options ":set gfn =xx")
       */
      for (i = 0; i < 2; ++i) {
        while (*arg != NUL && !vim_iswhite(*arg))
          if (*arg++ == '\\' && *arg != NUL)
            ++arg;
        arg = skipwhite(arg);
        if (*arg != '=')
          break;
      }
    }

    if (errmsg != NULL) {
      vim_strncpy(IObuff, (char_u *)_(errmsg), IOSIZE - 1);
      i = (int)STRLEN(IObuff) + 2;
      if (i + (arg - startarg) < IOSIZE) {
        /* append the argument with the error */
        STRCAT(IObuff, ": ");
        mch_memmove(IObuff + i, startarg, (arg - startarg));
        IObuff[i + (arg - startarg)] = NUL;
      }
      /* make sure all characters are printable */
      trans_characters(IObuff, IOSIZE);

      ++no_wait_return;         /* wait_return done later */
      emsg(IObuff);             /* show error highlighted */
      --no_wait_return;

      return FAIL;
    }

    arg = skipwhite(arg);
  }

theend:
  if (silent_mode && did_show) {
    /* After displaying option values in silent mode. */
    silent_mode = FALSE;
    info_message = TRUE;        /* use mch_msg(), not mch_errmsg() */
    msg_putchar('\n');
    cursor_on();                /* msg_start() switches it off */
    out_flush();
    silent_mode = TRUE;
    info_message = FALSE;       /* use mch_msg(), not mch_errmsg() */
  }

  return OK;
}

/*
 * Call this when an option has been given a new value through a user command.
 * Sets the P_WAS_SET flag and takes care of the P_INSECURE flag.
 */
static void 
did_set_option (
    int opt_idx,
    int opt_flags,              /* possibly with OPT_MODELINE */
    int new_value              /* value was replaced completely */
)
{
  long_u      *p;

  options[opt_idx].flags |= P_WAS_SET;

  /* When an option is set in the sandbox, from a modeline or in secure mode
   * set the P_INSECURE flag.  Otherwise, if a new value is stored reset the
   * flag. */
  p = insecure_flag(opt_idx, opt_flags);
  if (secure
#ifdef HAVE_SANDBOX
      || sandbox != 0
#endif
      || (opt_flags & OPT_MODELINE))
    *p = *p | P_INSECURE;
  else if (new_value)
    *p = *p & ~P_INSECURE;
}

static char_u *illegal_char(char_u *errbuf, int c)
{
  if (errbuf == NULL)
    return (char_u *)"";
  sprintf((char *)errbuf, _("E539: Illegal character <%s>"),
      (char *)transchar(c));
  return errbuf;
}

/*
 * Convert a key name or string into a key value.
 * Used for 'wildchar' and 'cedit' options.
 */
static int string_to_key(char_u *arg)
{
  if (*arg == '<')
    return find_key_option(arg + 1);
  if (*arg == '^')
    return Ctrl_chr(arg[1]);
  return *arg;
}

/*
 * Check value of 'cedit' and set cedit_key.
 * Returns NULL if value is OK, error message otherwise.
 */
static char_u *check_cedit(void)                     {
  int n;

  if (*p_cedit == NUL)
    cedit_key = -1;
  else {
    n = string_to_key(p_cedit);
    if (vim_isprintc(n))
      return e_invarg;
    cedit_key = n;
  }
  return NULL;
}

/*
 * When changing 'title', 'titlestring', 'icon' or 'iconstring', call
 * maketitle() to create and display it.
 * When switching the title or icon off, call mch_restore_title() to get
 * the old value back.
 */
static void 
did_set_title (
    int icon                   /* Did set icon instead of title */
)
{
  if (starting != NO_SCREEN
      ) {
    maketitle();
    if (icon) {
      if (!p_icon)
        mch_restore_title(2);
    } else   {
      if (!p_title)
        mch_restore_title(1);
    }
  }
}

/*
 * set_options_bin -  called when 'bin' changes value.
 */
void 
set_options_bin (
    int oldval,
    int newval,
    int opt_flags                  /* OPT_LOCAL and/or OPT_GLOBAL */
)
{
  /*
   * The option values that are changed when 'bin' changes are
   * copied when 'bin is set and restored when 'bin' is reset.
   */
  if (newval) {
    if (!oldval) {              /* switched on */
      if (!(opt_flags & OPT_GLOBAL)) {
        curbuf->b_p_tw_nobin = curbuf->b_p_tw;
        curbuf->b_p_wm_nobin = curbuf->b_p_wm;
        curbuf->b_p_ml_nobin = curbuf->b_p_ml;
        curbuf->b_p_et_nobin = curbuf->b_p_et;
      }
      if (!(opt_flags & OPT_LOCAL)) {
        p_tw_nobin = p_tw;
        p_wm_nobin = p_wm;
        p_ml_nobin = p_ml;
        p_et_nobin = p_et;
      }
    }

    if (!(opt_flags & OPT_GLOBAL)) {
      curbuf->b_p_tw = 0;       /* no automatic line wrap */
      curbuf->b_p_wm = 0;       /* no automatic line wrap */
      curbuf->b_p_ml = 0;       /* no modelines */
      curbuf->b_p_et = 0;       /* no expandtab */
    }
    if (!(opt_flags & OPT_LOCAL)) {
      p_tw = 0;
      p_wm = 0;
      p_ml = FALSE;
      p_et = FALSE;
      p_bin = TRUE;             /* needed when called for the "-b" argument */
    }
  } else if (oldval)   {        /* switched off */
    if (!(opt_flags & OPT_GLOBAL)) {
      curbuf->b_p_tw = curbuf->b_p_tw_nobin;
      curbuf->b_p_wm = curbuf->b_p_wm_nobin;
      curbuf->b_p_ml = curbuf->b_p_ml_nobin;
      curbuf->b_p_et = curbuf->b_p_et_nobin;
    }
    if (!(opt_flags & OPT_LOCAL)) {
      p_tw = p_tw_nobin;
      p_wm = p_wm_nobin;
      p_ml = p_ml_nobin;
      p_et = p_et_nobin;
    }
  }
}

/*
 * Find the parameter represented by the given character (eg ', :, ", or /),
 * and return its associated value in the 'viminfo' string.
 * Only works for number parameters, not for 'r' or 'n'.
 * If the parameter is not specified in the string or there is no following
 * number, return -1.
 */
int get_viminfo_parameter(int type)
{
  char_u  *p;

  p = find_viminfo_parameter(type);
  if (p != NULL && VIM_ISDIGIT(*p))
    return atoi((char *)p);
  return -1;
}

/*
 * Find the parameter represented by the given character (eg ''', ':', '"', or
 * '/') in the 'viminfo' option and return a pointer to the string after it.
 * Return NULL if the parameter is not specified in the string.
 */
char_u *find_viminfo_parameter(int type)
{
  char_u  *p;

  for (p = p_viminfo; *p; ++p) {
    if (*p == type)
      return p + 1;
    if (*p == 'n')                  /* 'n' is always the last one */
      break;
    p = vim_strchr(p, ',');         /* skip until next ',' */
    if (p == NULL)                  /* hit the end without finding parameter */
      break;
  }
  return NULL;
}

/*
 * Expand environment variables for some string options.
 * These string options cannot be indirect!
 * If "val" is NULL expand the current value of the option.
 * Return pointer to NameBuff, or NULL when not expanded.
 */
static char_u *option_expand(int opt_idx, char_u *val)
{
  /* if option doesn't need expansion nothing to do */
  if (!(options[opt_idx].flags & P_EXPAND) || options[opt_idx].var == NULL)
    return NULL;

  /* If val is longer than MAXPATHL no meaningful expansion can be done,
   * expand_env() would truncate the string. */
  if (val != NULL && STRLEN(val) > MAXPATHL)
    return NULL;

  if (val == NULL)
    val = *(char_u **)options[opt_idx].var;

  /*
   * Expanding this with NameBuff, expand_env() must not be passed IObuff.
   * Escape spaces when expanding 'tags', they are used to separate file
   * names.
   * For 'spellsuggest' expand after "file:".
   */
  expand_env_esc(val, NameBuff, MAXPATHL,
      (char_u **)options[opt_idx].var == &p_tags, FALSE,
      (char_u **)options[opt_idx].var == &p_sps ? (char_u *)"file:" :
      NULL);
  if (STRCMP(NameBuff, val) == 0)     /* they are the same */
    return NULL;

  return NameBuff;
}

/*
 * After setting various option values: recompute variables that depend on
 * option values.
 */
static void didset_options(void)                 {
  /* initialize the table for 'iskeyword' et.al. */
  (void)init_chartab();

  (void)opt_strings_flags(p_cmp, p_cmp_values, &cmp_flags, TRUE);
  (void)opt_strings_flags(p_bkc, p_bkc_values, &bkc_flags, TRUE);
  (void)opt_strings_flags(p_ssop, p_ssop_values, &ssop_flags, TRUE);
  (void)opt_strings_flags(p_vop, p_ssop_values, &vop_flags, TRUE);
  (void)opt_strings_flags(p_fdo, p_fdo_values, &fdo_flags, TRUE);
  (void)opt_strings_flags(p_dy, p_dy_values, &dy_flags, TRUE);
  (void)opt_strings_flags(p_ve, p_ve_values, &ve_flags, TRUE);
#if defined(FEAT_MOUSE) && (defined(UNIX) || defined(VMS))
  (void)opt_strings_flags(p_ttym, p_ttym_values, &ttym_flags, FALSE);
#endif
  (void)spell_check_msm();
  (void)spell_check_sps();
  (void)compile_cap_prog(curwin->w_s);
  /* set cedit_key */
  (void)check_cedit();
}

/*
 * Check for string options that are NULL (normally only termcap options).
 */
void check_options(void)          {
  int opt_idx;

  for (opt_idx = 0; options[opt_idx].fullname != NULL; opt_idx++)
    if ((options[opt_idx].flags & P_STRING) && options[opt_idx].var != NULL)
      check_string_option((char_u **)get_varp(&(options[opt_idx])));
}

/*
 * Check string options in a buffer for NULL value.
 */
void check_buf_options(buf_T *buf)
{
  check_string_option(&buf->b_p_bh);
  check_string_option(&buf->b_p_bt);
  check_string_option(&buf->b_p_fenc);
  check_string_option(&buf->b_p_ff);
  check_string_option(&buf->b_p_def);
  check_string_option(&buf->b_p_inc);
  check_string_option(&buf->b_p_inex);
  check_string_option(&buf->b_p_inde);
  check_string_option(&buf->b_p_indk);
  check_string_option(&buf->b_p_cm);
  check_string_option(&buf->b_p_fex);
  check_string_option(&buf->b_p_key);
  check_string_option(&buf->b_p_kp);
  check_string_option(&buf->b_p_mps);
  check_string_option(&buf->b_p_fo);
  check_string_option(&buf->b_p_flp);
  check_string_option(&buf->b_p_isk);
  check_string_option(&buf->b_p_com);
  check_string_option(&buf->b_p_cms);
  check_string_option(&buf->b_p_nf);
  check_string_option(&buf->b_p_qe);
  check_string_option(&buf->b_p_syn);
  check_string_option(&buf->b_s.b_p_spc);
  check_string_option(&buf->b_s.b_p_spf);
  check_string_option(&buf->b_s.b_p_spl);
  check_string_option(&buf->b_p_sua);
  check_string_option(&buf->b_p_cink);
  check_string_option(&buf->b_p_cino);
  parse_cino(buf);
  check_string_option(&buf->b_p_ft);
  check_string_option(&buf->b_p_cinw);
  check_string_option(&buf->b_p_cpt);
  check_string_option(&buf->b_p_cfu);
  check_string_option(&buf->b_p_ofu);
  check_string_option(&buf->b_p_keymap);
  check_string_option(&buf->b_p_gp);
  check_string_option(&buf->b_p_mp);
  check_string_option(&buf->b_p_efm);
  check_string_option(&buf->b_p_ep);
  check_string_option(&buf->b_p_path);
  check_string_option(&buf->b_p_tags);
  check_string_option(&buf->b_p_dict);
  check_string_option(&buf->b_p_tsr);
}

/*
 * Free the string allocated for an option.
 * Checks for the string being empty_option. This may happen if we're out of
 * memory, vim_strsave() returned NULL, which was replaced by empty_option by
 * check_options().
 * Does NOT check for P_ALLOCED flag!
 */
void free_string_option(char_u *p)
{
  if (p != empty_option)
    vim_free(p);
}

void clear_string_option(char_u **pp)
{
  if (*pp != empty_option)
    vim_free(*pp);
  *pp = empty_option;
}

static void check_string_option(char_u **pp)
{
  if (*pp == NULL)
    *pp = empty_option;
}

/*
 * Mark a terminal option as allocated, found by a pointer into term_strings[].
 */
void set_term_option_alloced(char_u **p)
{
  int opt_idx;

  for (opt_idx = 1; options[opt_idx].fullname != NULL; opt_idx++)
    if (options[opt_idx].var == (char_u *)p) {
      options[opt_idx].flags |= P_ALLOCED;
      return;
    }
  return;   /* cannot happen: didn't find it! */
}

/*
 * Return TRUE when option "opt" was set from a modeline or in secure mode.
 * Return FALSE when it wasn't.
 * Return -1 for an unknown option.
 */
int was_set_insecurely(char_u *opt, int opt_flags)
{
  int idx = findoption(opt);
  long_u  *flagp;

  if (idx >= 0) {
    flagp = insecure_flag(idx, opt_flags);
    return (*flagp & P_INSECURE) != 0;
  }
  EMSG2(_(e_intern2), "was_set_insecurely()");
  return -1;
}

/*
 * Get a pointer to the flags used for the P_INSECURE flag of option
 * "opt_idx".  For some local options a local flags field is used.
 */
static long_u *insecure_flag(int opt_idx, int opt_flags)
{
  if (opt_flags & OPT_LOCAL)
    switch ((int)options[opt_idx].indir) {
    case PV_STL:        return &curwin->w_p_stl_flags;
    case PV_FDE:        return &curwin->w_p_fde_flags;
    case PV_FDT:        return &curwin->w_p_fdt_flags;
    case PV_INDE:       return &curbuf->b_p_inde_flags;
    case PV_FEX:        return &curbuf->b_p_fex_flags;
    case PV_INEX:       return &curbuf->b_p_inex_flags;
    }

  /* Nothing special, return global flags field. */
  return &options[opt_idx].flags;
}

static void redraw_titles(void);

/*
 * Redraw the window title and/or tab page text later.
 */
static void redraw_titles(void) {
  need_maketitle = TRUE;
  redraw_tabline = TRUE;
}

/*
 * Set a string option to a new value (without checking the effect).
 * The string is copied into allocated memory.
 * if ("opt_idx" == -1) "name" is used, otherwise "opt_idx" is used.
 * When "set_sid" is zero set the scriptID to current_SID.  When "set_sid" is
 * SID_NONE don't set the scriptID.  Otherwise set the scriptID to "set_sid".
 */
void 
set_string_option_direct (
    char_u *name,
    int opt_idx,
    char_u *val,
    int opt_flags,                  /* OPT_FREE, OPT_LOCAL and/or OPT_GLOBAL */
    int set_sid
)
{
  char_u      *s;
  char_u      **varp;
  int both = (opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0;
  int idx = opt_idx;

  if (idx == -1) {              /* use name */
    idx = findoption(name);
    if (idx < 0) {      /* not found (should not happen) */
      EMSG2(_(e_intern2), "set_string_option_direct()");
      return;
    }
  }

  if (options[idx].var == NULL)         /* can't set hidden option */
    return;

  s = vim_strsave(val);
  if (s != NULL) {
    varp = (char_u **)get_varp_scope(&(options[idx]),
        both ? OPT_LOCAL : opt_flags);
    if ((opt_flags & OPT_FREE) && (options[idx].flags & P_ALLOCED))
      free_string_option(*varp);
    *varp = s;

    /* For buffer/window local option may also set the global value. */
    if (both)
      set_string_option_global(idx, varp);

    options[idx].flags |= P_ALLOCED;

    /* When setting both values of a global option with a local value,
    * make the local value empty, so that the global value is used. */
    if (((int)options[idx].indir & PV_BOTH) && both) {
      free_string_option(*varp);
      *varp = empty_option;
    }
    if (set_sid != SID_NONE)
      set_option_scriptID_idx(idx, opt_flags,
          set_sid == 0 ? current_SID : set_sid);
  }
}

/*
 * Set global value for string option when it's a local option.
 */
static void 
set_string_option_global (
    int opt_idx,                    /* option index */
    char_u **varp             /* pointer to option variable */
)
{
  char_u      **p, *s;

  /* the global value is always allocated */
  if (options[opt_idx].var == VAR_WIN)
    p = (char_u **)GLOBAL_WO(varp);
  else
    p = (char_u **)options[opt_idx].var;
  if (options[opt_idx].indir != PV_NONE
      && p != varp
      && (s = vim_strsave(*varp)) != NULL) {
    free_string_option(*p);
    *p = s;
  }
}

/*
 * Set a string option to a new value, and handle the effects.
 *
 * Returns NULL on success or error message on error.
 */
static char_u *
set_string_option (
    int opt_idx,
    char_u *value,
    int opt_flags                  /* OPT_LOCAL and/or OPT_GLOBAL */
)
{
  char_u      *s;
  char_u      **varp;
  char_u      *oldval;
  char_u      *r = NULL;

  if (options[opt_idx].var == NULL)     /* don't set hidden option */
    return NULL;

  s = vim_strsave(value);
  if (s != NULL) {
    varp = (char_u **)get_varp_scope(&(options[opt_idx]),
        (opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0
        ? (((int)options[opt_idx].indir & PV_BOTH)
           ? OPT_GLOBAL : OPT_LOCAL)
        : opt_flags);
    oldval = *varp;
    *varp = s;
    if ((r = did_set_string_option(opt_idx, varp, TRUE, oldval, NULL,
             opt_flags)) == NULL)
      did_set_option(opt_idx, opt_flags, TRUE);
  }
  return r;
}

/*
 * Handle string options that need some action to perform when changed.
 * Returns NULL for success, or an error message for an error.
 */
static char_u *
did_set_string_option (
    int opt_idx,                            /* index in options[] table */
    char_u **varp,                     /* pointer to the option variable */
    int new_value_alloced,                  /* new value was allocated */
    char_u *oldval,                    /* previous value of the option */
    char_u *errbuf,                    /* buffer for errors, or NULL */
    int opt_flags                          /* OPT_LOCAL and/or OPT_GLOBAL */
)
{
  char_u      *errmsg = NULL;
  char_u      *s, *p;
  int did_chartab = FALSE;
  char_u      **gvarp;
  long_u free_oldval = (options[opt_idx].flags & P_ALLOCED);

  /* Get the global option to compare with, otherwise we would have to check
   * two values for all local options. */
  gvarp = (char_u **)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL);

  /* Disallow changing some options from secure mode */
  if ((secure
#ifdef HAVE_SANDBOX
       || sandbox != 0
#endif
       ) && (options[opt_idx].flags & P_SECURE)) {
    errmsg = e_secure;
  }
  /* Check for a "normal" file name in some options.  Disallow a path
   * separator (slash and/or backslash), wildcards and characters that are
   * often illegal in a file name. */
  else if ((options[opt_idx].flags & P_NFNAME)
           && vim_strpbrk(*varp, (char_u *)"/\\*?[|<>") != NULL) {
    errmsg = e_invarg;
  }
  /* 'term' */
  else if (varp == &T_NAME) {
    if (T_NAME[0] == NUL)
      errmsg = (char_u *)N_("E529: Cannot set 'term' to empty string");
    else if (set_termname(T_NAME) == FAIL)
      errmsg = (char_u *)N_("E522: Not found in termcap");
    else
      /* Screen colors may have changed. */
      redraw_later_clear();
  }
  /* 'backupcopy' */
  else if (varp == &p_bkc) {
    if (opt_strings_flags(p_bkc, p_bkc_values, &bkc_flags, TRUE) != OK)
      errmsg = e_invarg;
    if (((bkc_flags & BKC_AUTO) != 0)
        + ((bkc_flags & BKC_YES) != 0)
        + ((bkc_flags & BKC_NO) != 0) != 1) {
      /* Must have exactly one of "auto", "yes"  and "no". */
      (void)opt_strings_flags(oldval, p_bkc_values, &bkc_flags, TRUE);
      errmsg = e_invarg;
    }
  }
  /* 'backupext' and 'patchmode' */
  else if (varp == &p_bex || varp == &p_pm) {
    if (STRCMP(*p_bex == '.' ? p_bex + 1 : p_bex,
            *p_pm == '.' ? p_pm + 1 : p_pm) == 0)
      errmsg = (char_u *)N_("E589: 'backupext' and 'patchmode' are equal");
  }
  /*
   * 'isident', 'iskeyword', 'isprint or 'isfname' option: refill chartab[]
   * If the new option is invalid, use old value.  'lisp' option: refill
   * chartab[] for '-' char
   */
  else if (  varp == &p_isi
             || varp == &(curbuf->b_p_isk)
             || varp == &p_isp
             || varp == &p_isf) {
    if (init_chartab() == FAIL) {
      did_chartab = TRUE;           /* need to restore it below */
      errmsg = e_invarg;            /* error in value */
    }
  }
  /* 'helpfile' */
  else if (varp == &p_hf) {
    /* May compute new values for $VIM and $VIMRUNTIME */
    if (didset_vim) {
      vim_setenv((char_u *)"VIM", (char_u *)"");
      didset_vim = FALSE;
    }
    if (didset_vimruntime) {
      vim_setenv((char_u *)"VIMRUNTIME", (char_u *)"");
      didset_vimruntime = FALSE;
    }
  }
  /* 'colorcolumn' */
  else if (varp == &curwin->w_p_cc)
    errmsg = check_colorcolumn(curwin);

  /* 'helplang' */
  else if (varp == &p_hlg) {
    /* Check for "", "ab", "ab,cd", etc. */
    for (s = p_hlg; *s != NUL; s += 3) {
      if (s[1] == NUL || ((s[2] != ',' || s[3] == NUL) && s[2] != NUL)) {
        errmsg = e_invarg;
        break;
      }
      if (s[2] == NUL)
        break;
    }
  }
  /* 'highlight' */
  else if (varp == &p_hl) {
    if (highlight_changed() == FAIL)
      errmsg = e_invarg;        /* invalid flags */
  }
  /* 'nrformats' */
  else if (gvarp == &p_nf) {
    if (check_opt_strings(*varp, p_nf_values, TRUE) != OK)
      errmsg = e_invarg;
  }
  /* 'sessionoptions' */
  else if (varp == &p_ssop) {
    if (opt_strings_flags(p_ssop, p_ssop_values, &ssop_flags, TRUE) != OK)
      errmsg = e_invarg;
    if ((ssop_flags & SSOP_CURDIR) && (ssop_flags & SSOP_SESDIR)) {
      /* Don't allow both "sesdir" and "curdir". */
      (void)opt_strings_flags(oldval, p_ssop_values, &ssop_flags, TRUE);
      errmsg = e_invarg;
    }
  }
  /* 'viewoptions' */
  else if (varp == &p_vop) {
    if (opt_strings_flags(p_vop, p_ssop_values, &vop_flags, TRUE) != OK)
      errmsg = e_invarg;
  }
  /* 'scrollopt' */
  else if (varp == &p_sbo) {
    if (check_opt_strings(p_sbo, p_scbopt_values, TRUE) != OK)
      errmsg = e_invarg;
  }
  /* 'ambiwidth' */
  else if (varp == &p_ambw) {
    if (check_opt_strings(p_ambw, p_ambw_values, FALSE) != OK)
      errmsg = e_invarg;
    else if (set_chars_option(&p_lcs) != NULL)
      errmsg = (char_u *)_("E834: Conflicts with value of 'listchars'");
    else if (set_chars_option(&p_fcs) != NULL)
      errmsg = (char_u *)_("E835: Conflicts with value of 'fillchars'");
  }
  /* 'background' */
  else if (varp == &p_bg) {
    if (check_opt_strings(p_bg, p_bg_values, FALSE) == OK) {
      int dark = (*p_bg == 'd');

      init_highlight(FALSE, FALSE);

      if (dark != (*p_bg == 'd')
          && get_var_value((char_u *)"g:colors_name") != NULL) {
        /* The color scheme must have set 'background' back to another
         * value, that's not what we want here.  Disable the color
         * scheme and set the colors again. */
        do_unlet((char_u *)"g:colors_name", TRUE);
        free_string_option(p_bg);
        p_bg = vim_strsave((char_u *)(dark ? "dark" : "light"));
        check_string_option(&p_bg);
        init_highlight(FALSE, FALSE);
      }
    } else
      errmsg = e_invarg;
  }
  /* 'wildmode' */
  else if (varp == &p_wim) {
    if (check_opt_wim() == FAIL)
      errmsg = e_invarg;
  }
  /* 'wildoptions' */
  else if (varp == &p_wop) {
    if (check_opt_strings(p_wop, p_wop_values, TRUE) != OK)
      errmsg = e_invarg;
  }
  /* 'winaltkeys' */
  else if (varp == &p_wak) {
    if (*p_wak == NUL
        || check_opt_strings(p_wak, p_wak_values, FALSE) != OK)
      errmsg = e_invarg;
  }
  /* 'eventignore' */
  else if (varp == &p_ei) {
    if (check_ei() == FAIL)
      errmsg = e_invarg;
  }
  /* 'encoding' and 'fileencoding' */
  else if (varp == &p_enc || gvarp == &p_fenc || varp == &p_tenc) {
    if (gvarp == &p_fenc) {
      if (!curbuf->b_p_ma && opt_flags != OPT_GLOBAL)
        errmsg = e_modifiable;
      else if (vim_strchr(*varp, ',') != NULL)
        /* No comma allowed in 'fileencoding'; catches confusing it
         * with 'fileencodings'. */
        errmsg = e_invarg;
      else {
        /* May show a "+" in the title now. */
        redraw_titles();
        /* Add 'fileencoding' to the swap file. */
        ml_setflags(curbuf);
      }
    }
    if (errmsg == NULL) {
      /* canonize the value, so that STRCMP() can be used on it */
      p = enc_canonize(*varp);
      if (p != NULL) {
        vim_free(*varp);
        *varp = p;
      }
      if (varp == &p_enc) {
        errmsg = mb_init();
        redraw_titles();
      }
    }


    if (errmsg == NULL) {
      /* When 'keymap' is used and 'encoding' changes, reload the keymap
       * (with another encoding). */
      if (varp == &p_enc && *curbuf->b_p_keymap != NUL)
        (void)keymap_init();

      /* When 'termencoding' is not empty and 'encoding' changes or when
       * 'termencoding' changes, need to setup for keyboard input and
       * display output conversion. */
      if (((varp == &p_enc && *p_tenc != NUL) || varp == &p_tenc)) {
        convert_setup(&input_conv, p_tenc, p_enc);
        convert_setup(&output_conv, p_enc, p_tenc);
      }

    }
  } else if (varp == &p_penc)   {
    /* Canonize printencoding if VIM standard one */
    p = enc_canonize(p_penc);
    if (p != NULL) {
      vim_free(p_penc);
      p_penc = p;
    } else   {
      /* Ensure lower case and '-' for '_' */
      for (s = p_penc; *s != NUL; s++) {
        if (*s == '_')
          *s = '-';
        else
          *s = TOLOWER_ASC(*s);
      }
    }
  } else if (varp == &curbuf->b_p_keymap)   {
    /* load or unload key mapping tables */
    errmsg = keymap_init();

    if (errmsg == NULL) {
      if (*curbuf->b_p_keymap != NUL) {
        /* Installed a new keymap, switch on using it. */
        curbuf->b_p_iminsert = B_IMODE_LMAP;
        if (curbuf->b_p_imsearch != B_IMODE_USE_INSERT)
          curbuf->b_p_imsearch = B_IMODE_LMAP;
      } else   {
        /* Cleared the keymap, may reset 'iminsert' and 'imsearch'. */
        if (curbuf->b_p_iminsert == B_IMODE_LMAP)
          curbuf->b_p_iminsert = B_IMODE_NONE;
        if (curbuf->b_p_imsearch == B_IMODE_LMAP)
          curbuf->b_p_imsearch = B_IMODE_USE_INSERT;
      }
      if ((opt_flags & OPT_LOCAL) == 0) {
        set_iminsert_global();
        set_imsearch_global();
      }
      status_redraw_curbuf();
    }
  }
  /* 'fileformat' */
  else if (gvarp == &p_ff) {
    if (!curbuf->b_p_ma && !(opt_flags & OPT_GLOBAL))
      errmsg = e_modifiable;
    else if (check_opt_strings(*varp, p_ff_values, FALSE) != OK)
      errmsg = e_invarg;
    else {
      /* may also change 'textmode' */
      if (get_fileformat(curbuf) == EOL_DOS)
        curbuf->b_p_tx = TRUE;
      else
        curbuf->b_p_tx = FALSE;
      redraw_titles();
      /* update flag in swap file */
      ml_setflags(curbuf);
      /* Redraw needed when switching to/from "mac": a CR in the text
       * will be displayed differently. */
      if (get_fileformat(curbuf) == EOL_MAC || *oldval == 'm')
        redraw_curbuf_later(NOT_VALID);
    }
  }
  /* 'fileformats' */
  else if (varp == &p_ffs) {
    if (check_opt_strings(p_ffs, p_ff_values, TRUE) != OK)
      errmsg = e_invarg;
    else {
      /* also change 'textauto' */
      if (*p_ffs == NUL)
        p_ta = FALSE;
      else
        p_ta = TRUE;
    }
  }
  /* 'cryptkey' */
  else if (gvarp == &p_key) {
    /* Make sure the ":set" command doesn't show the new value in the
     * history. */
    remove_key_from_history();
    if (STRCMP(curbuf->b_p_key, oldval) != 0)
      /* Need to update the swapfile. */
      ml_set_crypt_key(curbuf, oldval, get_crypt_method(curbuf));
  } else if (gvarp == &p_cm)   {
    if (opt_flags & OPT_LOCAL)
      p = curbuf->b_p_cm;
    else
      p = p_cm;
    if (check_opt_strings(p, p_cm_values, TRUE) != OK)
      errmsg = e_invarg;
    else if (get_crypt_method(curbuf) > 0 && blowfish_self_test() == FAIL)
      errmsg = e_invarg;
    else {
      /* When setting the global value to empty, make it "zip". */
      if (*p_cm == NUL) {
        if (new_value_alloced)
          free_string_option(p_cm);
        p_cm = vim_strsave((char_u *)"zip");
        new_value_alloced = TRUE;
      }

      /* Need to update the swapfile when the effective method changed.
       * Set "s" to the effective old value, "p" to the effective new
       * method and compare. */
      if ((opt_flags & OPT_LOCAL) && *oldval == NUL)
        s = p_cm;          /* was previously using the global value */
      else
        s = oldval;
      if (*curbuf->b_p_cm == NUL)
        p = p_cm;          /* is now using the global value */
      else
        p = curbuf->b_p_cm;
      if (STRCMP(s, p) != 0)
        ml_set_crypt_key(curbuf, curbuf->b_p_key,
            crypt_method_from_string(s));

      /* If the global value changes need to update the swapfile for all
       * buffers using that value. */
      if ((opt_flags & OPT_GLOBAL) && STRCMP(p_cm, oldval) != 0) {
        buf_T   *buf;

        for (buf = firstbuf; buf != NULL; buf = buf->b_next)
          if (buf != curbuf && *buf->b_p_cm == NUL)
            ml_set_crypt_key(buf, buf->b_p_key,
                crypt_method_from_string(oldval));
      }
    }
  }
  /* 'matchpairs' */
  else if (gvarp == &p_mps) {
    if (has_mbyte) {
      for (p = *varp; *p != NUL; ++p) {
        int x2 = -1;
        int x3 = -1;

        if (*p != NUL)
          p += mb_ptr2len(p);
        if (*p != NUL)
          x2 = *p++;
        if (*p != NUL) {
          x3 = mb_ptr2char(p);
          p += mb_ptr2len(p);
        }
        if (x2 != ':' || x3 == -1 || (*p != NUL && *p != ',')) {
          errmsg = e_invarg;
          break;
        }
        if (*p == NUL)
          break;
      }
    } else   {
      /* Check for "x:y,x:y" */
      for (p = *varp; *p != NUL; p += 4) {
        if (p[1] != ':' || p[2] == NUL || (p[3] != NUL && p[3] != ',')) {
          errmsg = e_invarg;
          break;
        }
        if (p[3] == NUL)
          break;
      }
    }
  }
  /* 'comments' */
  else if (gvarp == &p_com) {
    for (s = *varp; *s; ) {
      while (*s && *s != ':') {
        if (vim_strchr((char_u *)COM_ALL, *s) == NULL
            && !VIM_ISDIGIT(*s) && *s != '-') {
          errmsg = illegal_char(errbuf, *s);
          break;
        }
        ++s;
      }
      if (*s++ == NUL)
        errmsg = (char_u *)N_("E524: Missing colon");
      else if (*s == ',' || *s == NUL)
        errmsg = (char_u *)N_("E525: Zero length string");
      if (errmsg != NULL)
        break;
      while (*s && *s != ',') {
        if (*s == '\\' && s[1] != NUL)
          ++s;
        ++s;
      }
      s = skip_to_option_part(s);
    }
  }
  /* 'listchars' */
  else if (varp == &p_lcs) {
    errmsg = set_chars_option(varp);
  }
  /* 'fillchars' */
  else if (varp == &p_fcs) {
    errmsg = set_chars_option(varp);
  }
  /* 'cedit' */
  else if (varp == &p_cedit) {
    errmsg = check_cedit();
  }
  /* 'verbosefile' */
  else if (varp == &p_vfile) {
    verbose_stop();
    if (*p_vfile != NUL && verbose_open() == FAIL)
      errmsg = e_invarg;
  }
  /* 'viminfo' */
  else if (varp == &p_viminfo) {
    for (s = p_viminfo; *s; ) {
      /* Check it's a valid character */
      if (vim_strchr((char_u *)"!\"%'/:<@cfhnrs", *s) == NULL) {
        errmsg = illegal_char(errbuf, *s);
        break;
      }
      if (*s == 'n') {          /* name is always last one */
        break;
      } else if (*s == 'r')   { /* skip until next ',' */
        while (*++s && *s != ',')
          ;
      } else if (*s == '%')   {
        /* optional number */
        while (vim_isdigit(*++s))
          ;
      } else if (*s == '!' || *s == 'h' || *s == 'c')
        ++s;                    /* no extra chars */
      else {                    /* must have a number */
        while (vim_isdigit(*++s))
          ;

        if (!VIM_ISDIGIT(*(s - 1))) {
          if (errbuf != NULL) {
            sprintf((char *)errbuf,
                _("E526: Missing number after <%s>"),
                transchar_byte(*(s - 1)));
            errmsg = errbuf;
          } else
            errmsg = (char_u *)"";
          break;
        }
      }
      if (*s == ',')
        ++s;
      else if (*s) {
        if (errbuf != NULL)
          errmsg = (char_u *)N_("E527: Missing comma");
        else
          errmsg = (char_u *)"";
        break;
      }
    }
    if (*p_viminfo && errmsg == NULL && get_viminfo_parameter('\'') < 0)
      errmsg = (char_u *)N_("E528: Must specify a ' value");
  }
  /* terminal options */
  else if (istermoption(&options[opt_idx]) && full_screen) {
    /* ":set t_Co=0" and ":set t_Co=1" do ":set t_Co=" */
    if (varp == &T_CCO) {
      int colors = atoi((char *)T_CCO);

      /* Only reinitialize colors if t_Co value has really changed to
       * avoid expensive reload of colorscheme if t_Co is set to the
       * same value multiple times. */
      if (colors != t_colors) {
        t_colors = colors;
        if (t_colors <= 1) {
          if (new_value_alloced)
            vim_free(T_CCO);
          T_CCO = empty_option;
        }
        /* We now have a different color setup, initialize it again. */
        init_highlight(TRUE, FALSE);
      }
    }
    ttest(FALSE);
    if (varp == &T_ME) {
      out_str(T_ME);
      redraw_later(CLEAR);
    }
  }
  /* 'showbreak' */
  else if (varp == &p_sbr) {
    for (s = p_sbr; *s; ) {
      if (ptr2cells(s) != 1)
        errmsg = (char_u *)N_("E595: contains unprintable or wide character");
      mb_ptr_adv(s);
    }
  }


#ifdef CURSOR_SHAPE
  /* 'guicursor' */
  else if (varp == &p_guicursor)
    errmsg = parse_shape_opt(SHAPE_CURSOR);
#endif


  else if (varp == &p_popt)
    errmsg = parse_printoptions();
  else if (varp == &p_pmfn)
    errmsg = parse_printmbfont();

  /* 'langmap' */
  else if (varp == &p_langmap)
    langmap_set();

  /* 'breakat' */
  else if (varp == &p_breakat)
    fill_breakat_flags();

  /* 'titlestring' and 'iconstring' */
  else if (varp == &p_titlestring || varp == &p_iconstring) {
    int flagval = (varp == &p_titlestring) ? STL_IN_TITLE : STL_IN_ICON;

    /* NULL => statusline syntax */
    if (vim_strchr(*varp, '%') && check_stl_option(*varp) == NULL)
      stl_syntax |= flagval;
    else
      stl_syntax &= ~flagval;
    did_set_title(varp == &p_iconstring);

  }



#if defined(FEAT_MOUSE_TTY) && (defined(UNIX) || defined(VMS))
  /* 'ttymouse' */
  else if (varp == &p_ttym) {
    /* Switch the mouse off before changing the escape sequences used for
     * that. */
    mch_setmouse(FALSE);
    if (opt_strings_flags(p_ttym, p_ttym_values, &ttym_flags, FALSE) != OK)
      errmsg = e_invarg;
    else
      check_mouse_termcode();
    if (termcap_active)
      setmouse();               /* may switch it on again */
  }
#endif

  /* 'selection' */
  else if (varp == &p_sel) {
    if (*p_sel == NUL
        || check_opt_strings(p_sel, p_sel_values, FALSE) != OK)
      errmsg = e_invarg;
  }
  /* 'selectmode' */
  else if (varp == &p_slm) {
    if (check_opt_strings(p_slm, p_slm_values, TRUE) != OK)
      errmsg = e_invarg;
  }
  /* 'keymodel' */
  else if (varp == &p_km) {
    if (check_opt_strings(p_km, p_km_values, TRUE) != OK)
      errmsg = e_invarg;
    else {
      km_stopsel = (vim_strchr(p_km, 'o') != NULL);
      km_startsel = (vim_strchr(p_km, 'a') != NULL);
    }
  }
  /* 'mousemodel' */
  else if (varp == &p_mousem) {
    if (check_opt_strings(p_mousem, p_mousem_values, FALSE) != OK)
      errmsg = e_invarg;
  }
  /* 'switchbuf' */
  else if (varp == &p_swb) {
    if (opt_strings_flags(p_swb, p_swb_values, &swb_flags, TRUE) != OK)
      errmsg = e_invarg;
  }
  /* 'debug' */
  else if (varp == &p_debug) {
    if (check_opt_strings(p_debug, p_debug_values, TRUE) != OK)
      errmsg = e_invarg;
  }
  /* 'display' */
  else if (varp == &p_dy) {
    if (opt_strings_flags(p_dy, p_dy_values, &dy_flags, TRUE) != OK)
      errmsg = e_invarg;
    else
      (void)init_chartab();

  }
  /* 'eadirection' */
  else if (varp == &p_ead) {
    if (check_opt_strings(p_ead, p_ead_values, FALSE) != OK)
      errmsg = e_invarg;
  }
  /* When 'spelllang' or 'spellfile' is set and there is a window for this
   * buffer in which 'spell' is set load the wordlists. */
  else if (varp == &(curbuf->b_s.b_p_spl) || varp == &(curbuf->b_s.b_p_spf)) {
    win_T       *wp;
    int l;

    if (varp == &(curbuf->b_s.b_p_spf)) {
      l = (int)STRLEN(curbuf->b_s.b_p_spf);
      if (l > 0 && (l < 4 || STRCMP(curbuf->b_s.b_p_spf + l - 4,
                        ".add") != 0))
        errmsg = e_invarg;
    }

    if (errmsg == NULL) {
      FOR_ALL_WINDOWS(wp)
      if (wp->w_buffer == curbuf && wp->w_p_spell) {
        errmsg = did_set_spelllang(wp);
        break;
      }
    }
  }
  /* When 'spellcapcheck' is set compile the regexp program. */
  else if (varp == &(curwin->w_s->b_p_spc)) {
    errmsg = compile_cap_prog(curwin->w_s);
  }
  /* 'spellsuggest' */
  else if (varp == &p_sps) {
    if (spell_check_sps() != OK)
      errmsg = e_invarg;
  }
  /* 'mkspellmem' */
  else if (varp == &p_msm) {
    if (spell_check_msm() != OK)
      errmsg = e_invarg;
  }
  /* When 'bufhidden' is set, check for valid value. */
  else if (gvarp == &p_bh) {
    if (check_opt_strings(curbuf->b_p_bh, p_bufhidden_values, FALSE) != OK)
      errmsg = e_invarg;
  }
  /* When 'buftype' is set, check for valid value. */
  else if (gvarp == &p_bt) {
    if (check_opt_strings(curbuf->b_p_bt, p_buftype_values, FALSE) != OK)
      errmsg = e_invarg;
    else {
      if (curwin->w_status_height) {
        curwin->w_redr_status = TRUE;
        redraw_later(VALID);
      }
      curbuf->b_help = (curbuf->b_p_bt[0] == 'h');
      redraw_titles();
    }
  }
  /* 'statusline' or 'rulerformat' */
  else if (gvarp == &p_stl || varp == &p_ruf) {
    int wid;

    if (varp == &p_ruf)         /* reset ru_wid first */
      ru_wid = 0;
    s = *varp;
    if (varp == &p_ruf && *s == '%') {
      /* set ru_wid if 'ruf' starts with "%99(" */
      if (*++s == '-')          /* ignore a '-' */
        s++;
      wid = getdigits(&s);
      if (wid && *s == '(' && (errmsg = check_stl_option(p_ruf)) == NULL)
        ru_wid = wid;
      else
        errmsg = check_stl_option(p_ruf);
    }
    /* check 'statusline' only if it doesn't start with "%!" */
    else if (varp == &p_ruf || s[0] != '%' || s[1] != '!')
      errmsg = check_stl_option(s);
    if (varp == &p_ruf && errmsg == NULL)
      comp_col();
  }
  /* check if it is a valid value for 'complete' -- Acevedo */
  else if (gvarp == &p_cpt) {
    for (s = *varp; *s; ) {
      while (*s == ',' || *s == ' ')
        s++;
      if (!*s)
        break;
      if (vim_strchr((char_u *)".wbuksid]tU", *s) == NULL) {
        errmsg = illegal_char(errbuf, *s);
        break;
      }
      if (*++s != NUL && *s != ',' && *s != ' ') {
        if (s[-1] == 'k' || s[-1] == 's') {
          /* skip optional filename after 'k' and 's' */
          while (*s && *s != ',' && *s != ' ') {
            if (*s == '\\')
              ++s;
            ++s;
          }
        } else   {
          if (errbuf != NULL) {
            sprintf((char *)errbuf,
                _("E535: Illegal character after <%c>"),
                *--s);
            errmsg = errbuf;
          } else
            errmsg = (char_u *)"";
          break;
        }
      }
    }
  }
  /* 'completeopt' */
  else if (varp == &p_cot) {
    if (check_opt_strings(p_cot, p_cot_values, TRUE) != OK)
      errmsg = e_invarg;
  }
  /* 'pastetoggle': translate key codes like in a mapping */
  else if (varp == &p_pt) {
    if (*p_pt) {
      (void)replace_termcodes(p_pt, &p, TRUE, TRUE, FALSE);
      if (p != NULL) {
        if (new_value_alloced)
          free_string_option(p_pt);
        p_pt = p;
        new_value_alloced = TRUE;
      }
    }
  }
  /* 'backspace' */
  else if (varp == &p_bs) {
    if (VIM_ISDIGIT(*p_bs)) {
      if (*p_bs >'2' || p_bs[1] != NUL)
        errmsg = e_invarg;
    } else if (check_opt_strings(p_bs, p_bs_values, TRUE) != OK)
      errmsg = e_invarg;
  }
  /* 'casemap' */
  else if (varp == &p_cmp) {
    if (opt_strings_flags(p_cmp, p_cmp_values, &cmp_flags, TRUE) != OK)
      errmsg = e_invarg;
  }
  /* 'diffopt' */
  else if (varp == &p_dip) {
    if (diffopt_changed() == FAIL)
      errmsg = e_invarg;
  }
  /* 'foldmethod' */
  else if (gvarp == &curwin->w_allbuf_opt.wo_fdm) {
    if (check_opt_strings(*varp, p_fdm_values, FALSE) != OK
        || *curwin->w_p_fdm == NUL)
      errmsg = e_invarg;
    else {
      foldUpdateAll(curwin);
      if (foldmethodIsDiff(curwin))
        newFoldLevel();
    }
  }
  /* 'foldexpr' */
  else if (varp == &curwin->w_p_fde) {
    if (foldmethodIsExpr(curwin))
      foldUpdateAll(curwin);
  }
  /* 'foldmarker' */
  else if (gvarp == &curwin->w_allbuf_opt.wo_fmr) {
    p = vim_strchr(*varp, ',');
    if (p == NULL)
      errmsg = (char_u *)N_("E536: comma required");
    else if (p == *varp || p[1] == NUL)
      errmsg = e_invarg;
    else if (foldmethodIsMarker(curwin))
      foldUpdateAll(curwin);
  }
  /* 'commentstring' */
  else if (gvarp == &p_cms) {
    if (**varp != NUL && strstr((char *)*varp, "%s") == NULL)
      errmsg = (char_u *)N_("E537: 'commentstring' must be empty or contain %s");
  }
  /* 'foldopen' */
  else if (varp == &p_fdo) {
    if (opt_strings_flags(p_fdo, p_fdo_values, &fdo_flags, TRUE) != OK)
      errmsg = e_invarg;
  }
  /* 'foldclose' */
  else if (varp == &p_fcl) {
    if (check_opt_strings(p_fcl, p_fcl_values, TRUE) != OK)
      errmsg = e_invarg;
  }
  /* 'foldignore' */
  else if (gvarp == &curwin->w_allbuf_opt.wo_fdi) {
    if (foldmethodIsIndent(curwin))
      foldUpdateAll(curwin);
  }
  /* 'virtualedit' */
  else if (varp == &p_ve) {
    if (opt_strings_flags(p_ve, p_ve_values, &ve_flags, TRUE) != OK)
      errmsg = e_invarg;
    else if (STRCMP(p_ve, oldval) != 0) {
      /* Recompute cursor position in case the new 've' setting
       * changes something. */
      validate_virtcol();
      coladvance(curwin->w_virtcol);
    }
  } else if (varp == &p_csqf)   {
    if (p_csqf != NULL) {
      p = p_csqf;
      while (*p != NUL) {
        if (vim_strchr((char_u *)CSQF_CMDS, *p) == NULL
            || p[1] == NUL
            || vim_strchr((char_u *)CSQF_FLAGS, p[1]) == NULL
            || (p[2] != NUL && p[2] != ',')) {
          errmsg = e_invarg;
          break;
        } else if (p[2] == NUL)
          break;
        else
          p += 3;
      }
    }
  }
  /* 'cinoptions' */
  else if (gvarp == &p_cino) {
    /* TODO: recognize errors */
    parse_cino(curbuf);
  }
  /* Options that are a list of flags. */
  else {
    p = NULL;
    if (varp == &p_ww)
      p = (char_u *)WW_ALL;
    if (varp == &p_shm)
      p = (char_u *)SHM_ALL;
    else if (varp == &(p_cpo))
      p = (char_u *)CPO_ALL;
    else if (varp == &(curbuf->b_p_fo))
      p = (char_u *)FO_ALL;
    else if (varp == &curwin->w_p_cocu)
      p = (char_u *)COCU_ALL;
    else if (varp == &p_mouse) {
      p = (char_u *)MOUSE_ALL;
    }
    if (p != NULL) {
      for (s = *varp; *s; ++s)
        if (vim_strchr(p, *s) == NULL) {
          errmsg = illegal_char(errbuf, *s);
          break;
        }
    }
  }

  /*
   * If error detected, restore the previous value.
   */
  if (errmsg != NULL) {
    if (new_value_alloced)
      free_string_option(*varp);
    *varp = oldval;
    /*
     * When resetting some values, need to act on it.
     */
    if (did_chartab)
      (void)init_chartab();
    if (varp == &p_hl)
      (void)highlight_changed();
  } else   {
    /* Remember where the option was set. */
    set_option_scriptID_idx(opt_idx, opt_flags, current_SID);
    /*
     * Free string options that are in allocated memory.
     * Use "free_oldval", because recursiveness may change the flags under
     * our fingers (esp. init_highlight()).
     */
    if (free_oldval)
      free_string_option(oldval);
    if (new_value_alloced)
      options[opt_idx].flags |= P_ALLOCED;
    else
      options[opt_idx].flags &= ~P_ALLOCED;

    if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0
        && ((int)options[opt_idx].indir & PV_BOTH)) {
      /* global option with local value set to use global value; free
       * the local value and make it empty */
      p = get_varp_scope(&(options[opt_idx]), OPT_LOCAL);
      free_string_option(*(char_u **)p);
      *(char_u **)p = empty_option;
    }
    /* May set global value for local option. */
    else if (!(opt_flags & OPT_LOCAL) && opt_flags != OPT_GLOBAL)
      set_string_option_global(opt_idx, varp);

    /*
     * Trigger the autocommand only after setting the flags.
     */
    /* When 'syntax' is set, load the syntax of that name */
    if (varp == &(curbuf->b_p_syn)) {
      apply_autocmds(EVENT_SYNTAX, curbuf->b_p_syn,
          curbuf->b_fname, TRUE, curbuf);
    } else if (varp == &(curbuf->b_p_ft))   {
      /* 'filetype' is set, trigger the FileType autocommand */
      did_filetype = TRUE;
      apply_autocmds(EVENT_FILETYPE, curbuf->b_p_ft,
          curbuf->b_fname, TRUE, curbuf);
    }
    if (varp == &(curwin->w_s->b_p_spl)) {
      char_u fname[200];
      char_u      *q = curwin->w_s->b_p_spl;

      /* Skip the first name if it is "cjk". */
      if (STRNCMP(q, "cjk,", 4) == 0)
        q += 4;

      /*
       * Source the spell/LANG.vim in 'runtimepath'.
       * They could set 'spellcapcheck' depending on the language.
       * Use the first name in 'spelllang' up to '_region' or
       * '.encoding'.
       */
      for (p = q; *p != NUL; ++p)
        if (vim_strchr((char_u *)"_.,", *p) != NULL)
          break;
      vim_snprintf((char *)fname, 200, "spell/%.*s.vim", (int)(p - q), q);
      source_runtime(fname, TRUE);
    }
  }

  if (varp == &p_mouse) {
    if (*p_mouse == NUL)
      mch_setmouse(FALSE);          /* switch mouse off */
    else
      setmouse();                   /* in case 'mouse' changed */
  }

  if (curwin->w_curswant != MAXCOL
      && (options[opt_idx].flags & (P_CURSWANT | P_RCLR)) != 0)
    curwin->w_set_curswant = TRUE;

  check_redraw(options[opt_idx].flags);

  return errmsg;
}

/*
 * Simple int comparison function for use with qsort()
 */
static int int_cmp(const void *a, const void *b)
{
  return *(const int *)a - *(const int *)b;
}

/*
 * Handle setting 'colorcolumn' or 'textwidth' in window "wp".
 * Returns error message, NULL if it's OK.
 */
char_u *check_colorcolumn(win_T *wp)
{
  char_u      *s;
  int col;
  int count = 0;
  int color_cols[256];
  int i;
  int j = 0;

  if (wp->w_buffer == NULL)
    return NULL;      /* buffer was closed */

  for (s = wp->w_p_cc; *s != NUL && count < 255; ) {
    if (*s == '-' || *s == '+') {
      /* -N and +N: add to 'textwidth' */
      col = (*s == '-') ? -1 : 1;
      ++s;
      if (!VIM_ISDIGIT(*s))
        return e_invarg;
      col = col * getdigits(&s);
      if (wp->w_buffer->b_p_tw == 0)
        goto skip;          /* 'textwidth' not set, skip this item */
      col += wp->w_buffer->b_p_tw;
      if (col < 0)
        goto skip;
    } else if (VIM_ISDIGIT(*s))
      col = getdigits(&s);
    else
      return e_invarg;
    color_cols[count++] = col - 1;      /* 1-based to 0-based */
skip:
    if (*s == NUL)
      break;
    if (*s != ',')
      return e_invarg;
    if (*++s == NUL)
      return e_invarg;        /* illegal trailing comma as in "set cc=80," */
  }

  vim_free(wp->w_p_cc_cols);
  if (count == 0)
    wp->w_p_cc_cols = NULL;
  else {
    wp->w_p_cc_cols = (int *)alloc((unsigned)sizeof(int) * (count + 1));
    if (wp->w_p_cc_cols != NULL) {
      /* sort the columns for faster usage on screen redraw inside
       * win_line() */
      qsort(color_cols, count, sizeof(int), int_cmp);

      for (i = 0; i < count; ++i)
        /* skip duplicates */
        if (j == 0 || wp->w_p_cc_cols[j - 1] != color_cols[i])
          wp->w_p_cc_cols[j++] = color_cols[i];
      wp->w_p_cc_cols[j] = -1;        /* end marker */
    }
  }

  return NULL;    /* no error */
}

/*
 * Handle setting 'listchars' or 'fillchars'.
 * Returns error message, NULL if it's OK.
 */
static char_u *set_chars_option(char_u **varp)
{
  int round, i, len, entries;
  char_u      *p, *s;
  int c1, c2 = 0;
  struct charstab {
    int     *cp;
    char    *name;
  };
  static struct charstab filltab[] =
  {
    {&fill_stl,     "stl"},
    {&fill_stlnc,   "stlnc"},
    {&fill_vert,    "vert"},
    {&fill_fold,    "fold"},
    {&fill_diff,    "diff"},
  };
  static struct charstab lcstab[] =
  {
    {&lcs_eol,      "eol"},
    {&lcs_ext,      "extends"},
    {&lcs_nbsp,     "nbsp"},
    {&lcs_prec,     "precedes"},
    {&lcs_tab2,     "tab"},
    {&lcs_trail,    "trail"},
    {&lcs_conceal,  "conceal"},
  };
  struct charstab *tab;

  if (varp == &p_lcs) {
    tab = lcstab;
    entries = sizeof(lcstab) / sizeof(struct charstab);
  } else   {
    tab = filltab;
    entries = sizeof(filltab) / sizeof(struct charstab);
  }

  /* first round: check for valid value, second round: assign values */
  for (round = 0; round <= 1; ++round) {
    if (round > 0) {
      /* After checking that the value is valid: set defaults: space for
       * 'fillchars', NUL for 'listchars' */
      for (i = 0; i < entries; ++i)
        if (tab[i].cp != NULL)
          *(tab[i].cp) = (varp == &p_lcs ? NUL : ' ');
      if (varp == &p_lcs)
        lcs_tab1 = NUL;
      else
        fill_diff = '-';
    }
    p = *varp;
    while (*p) {
      for (i = 0; i < entries; ++i) {
        len = (int)STRLEN(tab[i].name);
        if (STRNCMP(p, tab[i].name, len) == 0
            && p[len] == ':'
            && p[len + 1] != NUL) {
          s = p + len + 1;
          c1 = mb_ptr2char_adv(&s);
          if (mb_char2cells(c1) > 1)
            continue;
          if (tab[i].cp == &lcs_tab2) {
            if (*s == NUL)
              continue;
            c2 = mb_ptr2char_adv(&s);
            if (mb_char2cells(c2) > 1)
              continue;
          }
          if (*s == ',' || *s == NUL) {
            if (round) {
              if (tab[i].cp == &lcs_tab2) {
                lcs_tab1 = c1;
                lcs_tab2 = c2;
              } else if (tab[i].cp != NULL)
                *(tab[i].cp) = c1;

            }
            p = s;
            break;
          }
        }
      }

      if (i == entries)
        return e_invarg;
      if (*p == ',')
        ++p;
    }
  }

  return NULL;          /* no error */
}

/*
 * Check validity of options with the 'statusline' format.
 * Return error message or NULL.
 */
char_u *check_stl_option(char_u *s)
{
  int itemcnt = 0;
  int groupdepth = 0;
  static char_u errbuf[80];

  while (*s && itemcnt < STL_MAX_ITEM) {
    /* Check for valid keys after % sequences */
    while (*s && *s != '%')
      s++;
    if (!*s)
      break;
    s++;
    if (*s != '%' && *s != ')')
      ++itemcnt;
    if (*s == '%' || *s == STL_TRUNCMARK || *s == STL_MIDDLEMARK) {
      s++;
      continue;
    }
    if (*s == ')') {
      s++;
      if (--groupdepth < 0)
        break;
      continue;
    }
    if (*s == '-')
      s++;
    while (VIM_ISDIGIT(*s))
      s++;
    if (*s == STL_USER_HL)
      continue;
    if (*s == '.') {
      s++;
      while (*s && VIM_ISDIGIT(*s))
        s++;
    }
    if (*s == '(') {
      groupdepth++;
      continue;
    }
    if (vim_strchr(STL_ALL, *s) == NULL) {
      return illegal_char(errbuf, *s);
    }
    if (*s == '{') {
      s++;
      while (*s != '}' && *s)
        s++;
      if (*s != '}')
        return (char_u *)N_("E540: Unclosed expression sequence");
    }
  }
  if (itemcnt >= STL_MAX_ITEM)
    return (char_u *)N_("E541: too many items");
  if (groupdepth != 0)
    return (char_u *)N_("E542: unbalanced groups");
  return NULL;
}


/*
 * Set curbuf->b_cap_prog to the regexp program for 'spellcapcheck'.
 * Return error message when failed, NULL when OK.
 */
static char_u *compile_cap_prog(synblock_T *synblock)
{
  regprog_T   *rp = synblock->b_cap_prog;
  char_u      *re;

  if (*synblock->b_p_spc == NUL)
    synblock->b_cap_prog = NULL;
  else {
    /* Prepend a ^ so that we only match at one column */
    re = concat_str((char_u *)"^", synblock->b_p_spc);
    if (re != NULL) {
      synblock->b_cap_prog = vim_regcomp(re, RE_MAGIC);
      vim_free(re);
      if (synblock->b_cap_prog == NULL) {
        synblock->b_cap_prog = rp;         /* restore the previous program */
        return e_invarg;
      }
    }
  }

  vim_regfree(rp);
  return NULL;
}

/*
 * Set the scriptID for an option, taking care of setting the buffer- or
 * window-local value.
 */
static void set_option_scriptID_idx(int opt_idx, int opt_flags, int id)
{
  int both = (opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0;
  int indir = (int)options[opt_idx].indir;

  /* Remember where the option was set.  For local options need to do that
   * in the buffer or window structure. */
  if (both || (opt_flags & OPT_GLOBAL) || (indir & (PV_BUF|PV_WIN)) == 0)
    options[opt_idx].scriptID = id;
  if (both || (opt_flags & OPT_LOCAL)) {
    if (indir & PV_BUF)
      curbuf->b_p_scriptID[indir & PV_MASK] = id;
    else if (indir & PV_WIN)
      curwin->w_p_scriptID[indir & PV_MASK] = id;
  }
}

/*
 * Set the value of a boolean option, and take care of side effects.
 * Returns NULL for success, or an error message for an error.
 */
static char_u *
set_bool_option (
    int opt_idx,                            /* index in options[] table */
    char_u *varp,                      /* pointer to the option variable */
    int value,                              /* new value */
    int opt_flags                          /* OPT_LOCAL and/or OPT_GLOBAL */
)
{
  int old_value = *(int *)varp;

  /* Disallow changing some options from secure mode */
  if ((secure
#ifdef HAVE_SANDBOX
       || sandbox != 0
#endif
       ) && (options[opt_idx].flags & P_SECURE))
    return e_secure;

  *(int *)varp = value;             /* set the new value */
  /* Remember where the option was set. */
  set_option_scriptID_idx(opt_idx, opt_flags, current_SID);


  /* May set global value for local option. */
  if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0)
    *(int *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL) = value;

  /*
   * Handle side effects of changing a bool option.
   */

  /* 'compatible' */
  if ((int *)varp == &p_cp) {
    compatible_set();
  }
  /* 'undofile' */
  else if ((int *)varp == &curbuf->b_p_udf || (int *)varp == &p_udf) {
    /* Only take action when the option was set. When reset we do not
     * delete the undo file, the option may be set again without making
     * any changes in between. */
    if (curbuf->b_p_udf || p_udf) {
      char_u hash[UNDO_HASH_SIZE];
      buf_T       *save_curbuf = curbuf;

      for (curbuf = firstbuf; curbuf != NULL; curbuf = curbuf->b_next) {
        /* When 'undofile' is set globally: for every buffer, otherwise
         * only for the current buffer: Try to read in the undofile,
         * if one exists, the buffer wasn't changed and the buffer was
         * loaded */
        if ((curbuf == save_curbuf
             || (opt_flags & OPT_GLOBAL) || opt_flags == 0)
            && !curbufIsChanged() && curbuf->b_ml.ml_mfp != NULL) {
          u_compute_hash(hash);
          u_read_undo(NULL, hash, curbuf->b_fname);
        }
      }
      curbuf = save_curbuf;
    }
  } else if ((int *)varp == &curbuf->b_p_ro)   {
    /* when 'readonly' is reset globally, also reset readonlymode */
    if (!curbuf->b_p_ro && (opt_flags & OPT_LOCAL) == 0)
      readonlymode = FALSE;

    /* when 'readonly' is set may give W10 again */
    if (curbuf->b_p_ro)
      curbuf->b_did_warn = FALSE;

    redraw_titles();
  }
  /* when 'modifiable' is changed, redraw the window title */
  else if ((int *)varp == &curbuf->b_p_ma) {
    redraw_titles();
  }
  /* when 'endofline' is changed, redraw the window title */
  else if ((int *)varp == &curbuf->b_p_eol) {
    redraw_titles();
  }
  /* when 'bomb' is changed, redraw the window title and tab page text */
  else if ((int *)varp == &curbuf->b_p_bomb) {
    redraw_titles();
  }
  /* when 'bin' is set also set some other options */
  else if ((int *)varp == &curbuf->b_p_bin) {
    set_options_bin(old_value, curbuf->b_p_bin, opt_flags);
    redraw_titles();
  }
  /* when 'buflisted' changes, trigger autocommands */
  else if ((int *)varp == &curbuf->b_p_bl && old_value != curbuf->b_p_bl) {
    apply_autocmds(curbuf->b_p_bl ? EVENT_BUFADD : EVENT_BUFDELETE,
        NULL, NULL, TRUE, curbuf);
  }
  /* when 'swf' is set, create swapfile, when reset remove swapfile */
  else if ((int *)varp == &curbuf->b_p_swf) {
    if (curbuf->b_p_swf && p_uc)
      ml_open_file(curbuf);                     /* create the swap file */
    else
      /* no need to reset curbuf->b_may_swap, ml_open_file() will check
       * buf->b_p_swf */
      mf_close_file(curbuf, TRUE);              /* remove the swap file */
  }
  /* when 'terse' is set change 'shortmess' */
  else if ((int *)varp == &p_terse) {
    char_u  *p;

    p = vim_strchr(p_shm, SHM_SEARCH);

    /* insert 's' in p_shm */
    if (p_terse && p == NULL) {
      STRCPY(IObuff, p_shm);
      STRCAT(IObuff, "s");
      set_string_option_direct((char_u *)"shm", -1, IObuff, OPT_FREE, 0);
    }
    /* remove 's' from p_shm */
    else if (!p_terse && p != NULL)
      STRMOVE(p, p + 1);
  }
  /* when 'paste' is set or reset also change other options */
  else if ((int *)varp == &p_paste) {
    paste_option_changed();
  }
  /* when 'insertmode' is set from an autocommand need to do work here */
  else if ((int *)varp == &p_im) {
    if (p_im) {
      if ((State & INSERT) == 0)
        need_start_insertmode = TRUE;
      stop_insert_mode = FALSE;
    } else   {
      need_start_insertmode = FALSE;
      stop_insert_mode = TRUE;
      if (restart_edit != 0 && mode_displayed)
        clear_cmdline = TRUE;           /* remove "(insert)" */
      restart_edit = 0;
    }
  }
  /* when 'ignorecase' is set or reset and 'hlsearch' is set, redraw */
  else if ((int *)varp == &p_ic && p_hls) {
    redraw_all_later(SOME_VALID);
  }
  /* when 'hlsearch' is set or reset: reset no_hlsearch */
  else if ((int *)varp == &p_hls) {
    SET_NO_HLSEARCH(FALSE);
  }
  /* when 'scrollbind' is set: snapshot the current position to avoid a jump
   * at the end of normal_cmd() */
  else if ((int *)varp == &curwin->w_p_scb) {
    if (curwin->w_p_scb) {
      do_check_scrollbind(FALSE);
      curwin->w_scbind_pos = curwin->w_topline;
    }
  }
  /* There can be only one window with 'previewwindow' set. */
  else if ((int *)varp == &curwin->w_p_pvw) {
    if (curwin->w_p_pvw) {
      win_T       *win;

      for (win = firstwin; win != NULL; win = win->w_next)
        if (win->w_p_pvw && win != curwin) {
          curwin->w_p_pvw = FALSE;
          return (char_u *)N_("E590: A preview window already exists");
        }
    }
  }
  /* when 'textmode' is set or reset also change 'fileformat' */
  else if ((int *)varp == &curbuf->b_p_tx) {
    set_fileformat(curbuf->b_p_tx ? EOL_DOS : EOL_UNIX, opt_flags);
  }
  /* when 'textauto' is set or reset also change 'fileformats' */
  else if ((int *)varp == &p_ta)
    set_string_option_direct((char_u *)"ffs", -1,
        p_ta ? (char_u *)DFLT_FFS_VIM : (char_u *)"",
        OPT_FREE | opt_flags, 0);

  /*
   * When 'lisp' option changes include/exclude '-' in
   * keyword characters.
   */
  else if (varp == (char_u *)&(curbuf->b_p_lisp)) {
    (void)buf_init_chartab(curbuf, FALSE);          /* ignore errors */
  }
  /* when 'title' changed, may need to change the title; same for 'icon' */
  else if ((int *)varp == &p_title) {
    did_set_title(FALSE);
  } else if ((int *)varp == &p_icon)   {
    did_set_title(TRUE);
  } else if ((int *)varp == &curbuf->b_changed)   {
    if (!value)
      save_file_ff(curbuf);             /* Buffer is unchanged */
    redraw_titles();
    modified_was_set = value;
  }

#ifdef BACKSLASH_IN_FILENAME
  else if ((int *)varp == &p_ssl) {
    if (p_ssl) {
      psepc = '/';
      psepcN = '\\';
      pseps[0] = '/';
    } else   {
      psepc = '\\';
      psepcN = '/';
      pseps[0] = '\\';
    }

    /* need to adjust the file name arguments and buffer names. */
    buflist_slash_adjust();
    alist_slash_adjust();
    scriptnames_slash_adjust();
  }
#endif

  /* If 'wrap' is set, set w_leftcol to zero. */
  else if ((int *)varp == &curwin->w_p_wrap) {
    if (curwin->w_p_wrap)
      curwin->w_leftcol = 0;
  } else if ((int *)varp == &p_ea)   {
    if (p_ea && !old_value)
      win_equal(curwin, FALSE, 0);
  } else if ((int *)varp == &p_wiv)   {
    /*
     * When 'weirdinvert' changed, set/reset 't_xs'.
     * Then set 'weirdinvert' according to value of 't_xs'.
     */
    if (p_wiv && !old_value)
      T_XS = (char_u *)"y";
    else if (!p_wiv && old_value)
      T_XS = empty_option;
    p_wiv = (*T_XS != NUL);
  } else if ((int *)varp == &p_acd)   {
    /* Change directories when the 'acd' option is set now. */
    DO_AUTOCHDIR
  }
  /* 'diff' */
  else if ((int *)varp == &curwin->w_p_diff) {
    /* May add or remove the buffer from the list of diff buffers. */
    diff_buf_adjust(curwin);
    if (foldmethodIsDiff(curwin))
      foldUpdateAll(curwin);
  }

#ifdef USE_IM_CONTROL
  /* 'imdisable' */
  else if ((int *)varp == &p_imdisable) {
    /* Only de-activate it here, it will be enabled when changing mode. */
    if (p_imdisable)
      im_set_active(FALSE);
    else if (State & INSERT)
      /* When the option is set from an autocommand, it may need to take
       * effect right away. */
      im_set_active(curbuf->b_p_iminsert == B_IMODE_IM);
  }
#endif

  /* 'spell' */
  else if ((int *)varp == &curwin->w_p_spell) {
    if (curwin->w_p_spell) {
      char_u      *errmsg = did_set_spelllang(curwin);
      if (errmsg != NULL)
        EMSG(_(errmsg));
    }
  } else if ((int *)varp == &p_altkeymap)   {
    if (old_value != p_altkeymap) {
      if (!p_altkeymap) {
        p_hkmap = p_fkmap;
        p_fkmap = 0;
      } else   {
        p_fkmap = p_hkmap;
        p_hkmap = 0;
      }
      (void)init_chartab();
    }
  }

  /*
   * In case some second language keymapping options have changed, check
   * and correct the setting in a consistent way.
   */

  /*
   * If hkmap or fkmap are set, reset Arabic keymapping.
   */
  if ((p_hkmap || p_fkmap) && p_altkeymap) {
    p_altkeymap = p_fkmap;
    curwin->w_p_arab = FALSE;
    (void)init_chartab();
  }

  /*
   * If hkmap set, reset Farsi keymapping.
   */
  if (p_hkmap && p_altkeymap) {
    p_altkeymap = 0;
    p_fkmap = 0;
    curwin->w_p_arab = FALSE;
    (void)init_chartab();
  }

  /*
   * If fkmap set, reset Hebrew keymapping.
   */
  if (p_fkmap && !p_altkeymap) {
    p_altkeymap = 1;
    p_hkmap = 0;
    curwin->w_p_arab = FALSE;
    (void)init_chartab();
  }

  if ((int *)varp == &curwin->w_p_arab) {
    if (curwin->w_p_arab) {
      /*
       * 'arabic' is set, handle various sub-settings.
       */
      if (!p_tbidi) {
        /* set rightleft mode */
        if (!curwin->w_p_rl) {
          curwin->w_p_rl = TRUE;
          changed_window_setting();
        }

        /* Enable Arabic shaping (major part of what Arabic requires) */
        if (!p_arshape) {
          p_arshape = TRUE;
          redraw_later_clear();
        }
      }

      /* Arabic requires a utf-8 encoding, inform the user if its not
       * set. */
      if (STRCMP(p_enc, "utf-8") != 0) {
        static char *w_arabic = N_(
            "W17: Arabic requires UTF-8, do ':set encoding=utf-8'");

        msg_source(hl_attr(HLF_W));
        MSG_ATTR(_(w_arabic), hl_attr(HLF_W));
        set_vim_var_string(VV_WARNINGMSG, (char_u *)_(w_arabic), -1);
      }

      /* set 'delcombine' */
      p_deco = TRUE;

      /* Force-set the necessary keymap for arabic */
      set_option_value((char_u *)"keymap", 0L, (char_u *)"arabic",
          OPT_LOCAL);
      p_altkeymap = 0;
      p_hkmap = 0;
      p_fkmap = 0;
      (void)init_chartab();
    } else   {
      /*
       * 'arabic' is reset, handle various sub-settings.
       */
      if (!p_tbidi) {
        /* reset rightleft mode */
        if (curwin->w_p_rl) {
          curwin->w_p_rl = FALSE;
          changed_window_setting();
        }

        /* 'arabicshape' isn't reset, it is a global option and
         * another window may still need it "on". */
      }

      /* 'delcombine' isn't reset, it is a global option and another
       * window may still want it "on". */

      /* Revert to the default keymap */
      curbuf->b_p_iminsert = B_IMODE_NONE;
      curbuf->b_p_imsearch = B_IMODE_USE_INSERT;
    }
  }


  /*
   * End of handling side effects for bool options.
   */

  options[opt_idx].flags |= P_WAS_SET;

  comp_col();                       /* in case 'ruler' or 'showcmd' changed */
  if (curwin->w_curswant != MAXCOL
      && (options[opt_idx].flags & (P_CURSWANT | P_RCLR)) != 0)
    curwin->w_set_curswant = TRUE;
  check_redraw(options[opt_idx].flags);

  return NULL;
}

/*
 * Set the value of a number option, and take care of side effects.
 * Returns NULL for success, or an error message for an error.
 */
static char_u *
set_num_option (
    int opt_idx,                            /* index in options[] table */
    char_u *varp,                      /* pointer to the option variable */
    long value,                             /* new value */
    char_u *errbuf,                    /* buffer for error messages */
    size_t errbuflen,                       /* length of "errbuf" */
    int opt_flags                          /* OPT_LOCAL, OPT_GLOBAL and
                                           OPT_MODELINE */
)
{
  char_u      *errmsg = NULL;
  long old_value = *(long *)varp;
  long old_Rows = Rows;                 /* remember old Rows */
  long old_Columns = Columns;           /* remember old Columns */
  long        *pp = (long *)varp;

  /* Disallow changing some options from secure mode. */
  if ((secure
#ifdef HAVE_SANDBOX
       || sandbox != 0
#endif
       ) && (options[opt_idx].flags & P_SECURE))
    return e_secure;

  *pp = value;
  /* Remember where the option was set. */
  set_option_scriptID_idx(opt_idx, opt_flags, current_SID);

  if (curbuf->b_p_sw < 0) {
    errmsg = e_positive;
    curbuf->b_p_sw = curbuf->b_p_ts;
  }

  /*
   * Number options that need some action when changed
   */
  if (pp == &p_wh || pp == &p_hh) {
    if (p_wh < 1) {
      errmsg = e_positive;
      p_wh = 1;
    }
    if (p_wmh > p_wh) {
      errmsg = e_winheight;
      p_wh = p_wmh;
    }
    if (p_hh < 0) {
      errmsg = e_positive;
      p_hh = 0;
    }

    /* Change window height NOW */
    if (lastwin != firstwin) {
      if (pp == &p_wh && curwin->w_height < p_wh)
        win_setheight((int)p_wh);
      if (pp == &p_hh && curbuf->b_help && curwin->w_height < p_hh)
        win_setheight((int)p_hh);
    }
  }
  /* 'winminheight' */
  else if (pp == &p_wmh) {
    if (p_wmh < 0) {
      errmsg = e_positive;
      p_wmh = 0;
    }
    if (p_wmh > p_wh) {
      errmsg = e_winheight;
      p_wmh = p_wh;
    }
    win_setminheight();
  } else if (pp == &p_wiw)   {
    if (p_wiw < 1) {
      errmsg = e_positive;
      p_wiw = 1;
    }
    if (p_wmw > p_wiw) {
      errmsg = e_winwidth;
      p_wiw = p_wmw;
    }

    /* Change window width NOW */
    if (lastwin != firstwin && curwin->w_width < p_wiw)
      win_setwidth((int)p_wiw);
  }
  /* 'winminwidth' */
  else if (pp == &p_wmw) {
    if (p_wmw < 0) {
      errmsg = e_positive;
      p_wmw = 0;
    }
    if (p_wmw > p_wiw) {
      errmsg = e_winwidth;
      p_wmw = p_wiw;
    }
    win_setminheight();
  }
  /* (re)set last window status line */
  else if (pp == &p_ls) {
    last_status(FALSE);
  }
  /* (re)set tab page line */
  else if (pp == &p_stal) {
    shell_new_rows();           /* recompute window positions and heights */
  }
  /* 'foldlevel' */
  else if (pp == &curwin->w_p_fdl) {
    if (curwin->w_p_fdl < 0)
      curwin->w_p_fdl = 0;
    newFoldLevel();
  }
  /* 'foldminlines' */
  else if (pp == &curwin->w_p_fml) {
    foldUpdateAll(curwin);
  }
  /* 'foldnestmax' */
  else if (pp == &curwin->w_p_fdn) {
    if (foldmethodIsSyntax(curwin) || foldmethodIsIndent(curwin))
      foldUpdateAll(curwin);
  }
  /* 'foldcolumn' */
  else if (pp == &curwin->w_p_fdc) {
    if (curwin->w_p_fdc < 0) {
      errmsg = e_positive;
      curwin->w_p_fdc = 0;
    } else if (curwin->w_p_fdc > 12)   {
      errmsg = e_invarg;
      curwin->w_p_fdc = 12;
    }
  }
  /* 'shiftwidth' or 'tabstop' */
  else if (pp == &curbuf->b_p_sw || pp == &curbuf->b_p_ts) {
    if (foldmethodIsIndent(curwin))
      foldUpdateAll(curwin);
    /* When 'shiftwidth' changes, or it's zero and 'tabstop' changes:
     * parse 'cinoptions'. */
    if (pp == &curbuf->b_p_sw || curbuf->b_p_sw == 0)
      parse_cino(curbuf);
  }
  /* 'maxcombine' */
  else if (pp == &p_mco) {
    if (p_mco > MAX_MCO)
      p_mco = MAX_MCO;
    else if (p_mco < 0)
      p_mco = 0;
    screenclear();          /* will re-allocate the screen */
  } else if (pp == &curbuf->b_p_iminsert)   {
    if (curbuf->b_p_iminsert < 0 || curbuf->b_p_iminsert > B_IMODE_LAST) {
      errmsg = e_invarg;
      curbuf->b_p_iminsert = B_IMODE_NONE;
    }
    p_iminsert = curbuf->b_p_iminsert;
    if (termcap_active)         /* don't do this in the alternate screen */
      showmode();
    /* Show/unshow value of 'keymap' in status lines. */
    status_redraw_curbuf();
  } else if (pp == &p_window)   {
    if (p_window < 1)
      p_window = 1;
    else if (p_window >= Rows)
      p_window = Rows - 1;
  } else if (pp == &curbuf->b_p_imsearch)   {
    if (curbuf->b_p_imsearch < -1 || curbuf->b_p_imsearch > B_IMODE_LAST) {
      errmsg = e_invarg;
      curbuf->b_p_imsearch = B_IMODE_NONE;
    }
    p_imsearch = curbuf->b_p_imsearch;
  }
  /* if 'titlelen' has changed, redraw the title */
  else if (pp == &p_titlelen) {
    if (p_titlelen < 0) {
      errmsg = e_positive;
      p_titlelen = 85;
    }
    if (starting != NO_SCREEN && old_value != p_titlelen)
      need_maketitle = TRUE;
  }
  /* if p_ch changed value, change the command line height */
  else if (pp == &p_ch) {
    if (p_ch < 1) {
      errmsg = e_positive;
      p_ch = 1;
    }
    if (p_ch > Rows - min_rows() + 1)
      p_ch = Rows - min_rows() + 1;

    /* Only compute the new window layout when startup has been
     * completed. Otherwise the frame sizes may be wrong. */
    if (p_ch != old_value && full_screen
        )
      command_height();
  }
  /* when 'updatecount' changes from zero to non-zero, open swap files */
  else if (pp == &p_uc) {
    if (p_uc < 0) {
      errmsg = e_positive;
      p_uc = 100;
    }
    if (p_uc && !old_value)
      ml_open_files();
  } else if (pp == &curwin->w_p_cole)   {
    if (curwin->w_p_cole < 0) {
      errmsg = e_positive;
      curwin->w_p_cole = 0;
    } else if (curwin->w_p_cole > 3)   {
      errmsg = e_invarg;
      curwin->w_p_cole = 3;
    }
  }
  /* sync undo before 'undolevels' changes */
  else if (pp == &p_ul) {
    /* use the old value, otherwise u_sync() may not work properly */
    p_ul = old_value;
    u_sync(TRUE);
    p_ul = value;
  } else if (pp == &curbuf->b_p_ul)   {
    /* use the old value, otherwise u_sync() may not work properly */
    curbuf->b_p_ul = old_value;
    u_sync(TRUE);
    curbuf->b_p_ul = value;
  }
  /* 'numberwidth' must be positive */
  else if (pp == &curwin->w_p_nuw) {
    if (curwin->w_p_nuw < 1) {
      errmsg = e_positive;
      curwin->w_p_nuw = 1;
    }
    if (curwin->w_p_nuw > 10) {
      errmsg = e_invarg;
      curwin->w_p_nuw = 10;
    }
    curwin->w_nrwidth_line_count = 0;
  } else if (pp == &curbuf->b_p_tw)   {
    if (curbuf->b_p_tw < 0) {
      errmsg = e_positive;
      curbuf->b_p_tw = 0;
    }
    {
      win_T       *wp;
      tabpage_T   *tp;

      FOR_ALL_TAB_WINDOWS(tp, wp)
      check_colorcolumn(wp);
    }
  }

  /*
   * Check the bounds for numeric options here
   */
  if (Rows < min_rows() && full_screen) {
    if (errbuf != NULL) {
      vim_snprintf((char *)errbuf, errbuflen,
          _("E593: Need at least %d lines"), min_rows());
      errmsg = errbuf;
    }
    Rows = min_rows();
  }
  if (Columns < MIN_COLUMNS && full_screen) {
    if (errbuf != NULL) {
      vim_snprintf((char *)errbuf, errbuflen,
          _("E594: Need at least %d columns"), MIN_COLUMNS);
      errmsg = errbuf;
    }
    Columns = MIN_COLUMNS;
  }
  limit_screen_size();


  /*
   * If the screen (shell) height has been changed, assume it is the
   * physical screenheight.
   */
  if (old_Rows != Rows || old_Columns != Columns) {
    /* Changing the screen size is not allowed while updating the screen. */
    if (updating_screen)
      *pp = old_value;
    else if (full_screen
             )
      set_shellsize((int)Columns, (int)Rows, TRUE);
    else {
      /* Postpone the resizing; check the size and cmdline position for
       * messages. */
      check_shellsize();
      if (cmdline_row > Rows - p_ch && Rows > p_ch)
        cmdline_row = Rows - p_ch;
    }
    if (p_window >= Rows || !option_was_set((char_u *)"window"))
      p_window = Rows - 1;
  }

  if (curbuf->b_p_ts <= 0) {
    errmsg = e_positive;
    curbuf->b_p_ts = 8;
  }
  if (p_tm < 0) {
    errmsg = e_positive;
    p_tm = 0;
  }
  if ((curwin->w_p_scr <= 0
       || (curwin->w_p_scr > curwin->w_height
           && curwin->w_height > 0))
      && full_screen) {
    if (pp == &(curwin->w_p_scr)) {
      if (curwin->w_p_scr != 0)
        errmsg = e_scroll;
      win_comp_scroll(curwin);
    }
    /* If 'scroll' became invalid because of a side effect silently adjust
     * it. */
    else if (curwin->w_p_scr <= 0)
      curwin->w_p_scr = 1;
    else     /* curwin->w_p_scr > curwin->w_height */
      curwin->w_p_scr = curwin->w_height;
  }
  if (p_hi < 0) {
    errmsg = e_positive;
    p_hi = 0;
  }
  if (p_re < 0 || p_re > 2) {
    errmsg = e_invarg;
    p_re = 0;
  }
  if (p_report < 0) {
    errmsg = e_positive;
    p_report = 1;
  }
  if ((p_sj < -100 || p_sj >= Rows) && full_screen) {
    if (Rows != old_Rows)       /* Rows changed, just adjust p_sj */
      p_sj = Rows / 2;
    else {
      errmsg = e_scroll;
      p_sj = 1;
    }
  }
  if (p_so < 0 && full_screen) {
    errmsg = e_scroll;
    p_so = 0;
  }
  if (p_siso < 0 && full_screen) {
    errmsg = e_positive;
    p_siso = 0;
  }
  if (p_cwh < 1) {
    errmsg = e_positive;
    p_cwh = 1;
  }
  if (p_ut < 0) {
    errmsg = e_positive;
    p_ut = 2000;
  }
  if (p_ss < 0) {
    errmsg = e_positive;
    p_ss = 0;
  }

  /* May set global value for local option. */
  if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0)
    *(long *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL) = *pp;

  options[opt_idx].flags |= P_WAS_SET;

  comp_col();                       /* in case 'columns' or 'ls' changed */
  if (curwin->w_curswant != MAXCOL
      && (options[opt_idx].flags & (P_CURSWANT | P_RCLR)) != 0)
    curwin->w_set_curswant = TRUE;
  check_redraw(options[opt_idx].flags);

  return errmsg;
}

/*
 * Called after an option changed: check if something needs to be redrawn.
 */
static void check_redraw(long_u flags)
{
  /* Careful: P_RCLR and P_RALL are a combination of other P_ flags */
  int doclear = (flags & P_RCLR) == P_RCLR;
  int all = ((flags & P_RALL) == P_RALL || doclear);

  if ((flags & P_RSTAT) || all)         /* mark all status lines dirty */
    status_redraw_all();

  if ((flags & P_RBUF) || (flags & P_RWIN) || all)
    changed_window_setting();
  if (flags & P_RBUF)
    redraw_curbuf_later(NOT_VALID);
  if (doclear)
    redraw_all_later(CLEAR);
  else if (all)
    redraw_all_later(NOT_VALID);
}

/*
 * Find index for option 'arg'.
 * Return -1 if not found.
 */
static int findoption(char_u *arg)
{
  int opt_idx;
  char            *s, *p;
  static short quick_tab[27] = {0, 0};          /* quick access table */
  int is_term_opt;

  /*
   * For first call: Initialize the quick-access table.
   * It contains the index for the first option that starts with a certain
   * letter.  There are 26 letters, plus the first "t_" option.
   */
  if (quick_tab[1] == 0) {
    p = options[0].fullname;
    for (opt_idx = 1; (s = options[opt_idx].fullname) != NULL; opt_idx++) {
      if (s[0] != p[0]) {
        if (s[0] == 't' && s[1] == '_')
          quick_tab[26] = opt_idx;
        else
          quick_tab[CharOrdLow(s[0])] = opt_idx;
      }
      p = s;
    }
  }

  /*
   * Check for name starting with an illegal character.
   */
  if (arg[0] < 'a' || arg[0] > 'z')
    return -1;

  is_term_opt = (arg[0] == 't' && arg[1] == '_');
  if (is_term_opt)
    opt_idx = quick_tab[26];
  else
    opt_idx = quick_tab[CharOrdLow(arg[0])];
  for (; (s = options[opt_idx].fullname) != NULL; opt_idx++) {
    if (STRCMP(arg, s) == 0)                        /* match full name */
      break;
  }
  if (s == NULL && !is_term_opt) {
    opt_idx = quick_tab[CharOrdLow(arg[0])];
    for (; options[opt_idx].fullname != NULL; opt_idx++) {
      s = options[opt_idx].shortname;
      if (s != NULL && STRCMP(arg, s) == 0)         /* match short name */
        break;
      s = NULL;
    }
  }
  if (s == NULL)
    opt_idx = -1;
  return opt_idx;
}

/*
 * Get the value for an option.
 *
 * Returns:
 * Number or Toggle option: 1, *numval gets value.
 *	     String option: 0, *stringval gets allocated string.
 * Hidden Number or Toggle option: -1.
 *	     hidden String option: -2.
 *		   unknown option: -3.
 */
int 
get_option_value (
    char_u *name,
    long *numval,
    char_u **stringval,            /* NULL when only checking existence */
    int opt_flags
)
{
  int opt_idx;
  char_u      *varp;

  opt_idx = findoption(name);
  if (opt_idx < 0)                  /* unknown option */
    return -3;

  varp = get_varp_scope(&(options[opt_idx]), opt_flags);

  if (options[opt_idx].flags & P_STRING) {
    if (varp == NULL)                       /* hidden option */
      return -2;
    if (stringval != NULL) {
      /* never return the value of the crypt key */
      if ((char_u **)varp == &curbuf->b_p_key
          && **(char_u **)(varp) != NUL)
        *stringval = vim_strsave((char_u *)"*****");
      else
        *stringval = vim_strsave(*(char_u **)(varp));
    }
    return 0;
  }

  if (varp == NULL)                 /* hidden option */
    return -1;
  if (options[opt_idx].flags & P_NUM)
    *numval = *(long *)varp;
  else {
    /* Special case: 'modified' is b_changed, but we also want to consider
     * it set when 'ff' or 'fenc' changed. */
    if ((int *)varp == &curbuf->b_changed)
      *numval = curbufIsChanged();
    else
      *numval = *(int *)varp;
  }
  return 1;
}


/*
 * Set the value of option "name".
 * Use "string" for string options, use "number" for other options.
 *
 * Returns NULL on success or error message on error.
 */
char_u *
set_option_value (
    char_u *name,
    long number,
    char_u *string,
    int opt_flags                  /* OPT_LOCAL or 0 (both) */
)
{
  int opt_idx;
  char_u      *varp;
  long_u flags;

  opt_idx = findoption(name);
  if (opt_idx < 0)
    EMSG2(_("E355: Unknown option: %s"), name);
  else {
    flags = options[opt_idx].flags;
#ifdef HAVE_SANDBOX
    /* Disallow changing some options in the sandbox */
    if (sandbox > 0 && (flags & P_SECURE)) {
      EMSG(_(e_sandbox));
      return NULL;
    }
#endif
    if (flags & P_STRING)
      return set_string_option(opt_idx, string, opt_flags);
    else {
      varp = get_varp_scope(&(options[opt_idx]), opt_flags);
      if (varp != NULL) {       /* hidden option is not changed */
        if (number == 0 && string != NULL) {
          int idx;

          /* Either we are given a string or we are setting option
           * to zero. */
          for (idx = 0; string[idx] == '0'; ++idx)
            ;
          if (string[idx] != NUL || idx == 0) {
            /* There's another character after zeros or the string
             * is empty.  In both cases, we are trying to set a
             * num option using a string. */
            EMSG3(_("E521: Number required: &%s = '%s'"),
                name, string);
            return NULL;                 /* do nothing as we hit an error */

          }
        }
        if (flags & P_NUM)
          return set_num_option(opt_idx, varp, number,
              NULL, 0, opt_flags);
        else
          return set_bool_option(opt_idx, varp, (int)number,
              opt_flags);
      }
    }
  }
  return NULL;
}

/*
 * Get the terminal code for a terminal option.
 * Returns NULL when not found.
 */
char_u *get_term_code(char_u *tname)
{
  int opt_idx;
  char_u  *varp;

  if (tname[0] != 't' || tname[1] != '_' ||
      tname[2] == NUL || tname[3] == NUL)
    return NULL;
  if ((opt_idx = findoption(tname)) >= 0) {
    varp = get_varp(&(options[opt_idx]));
    if (varp != NULL)
      varp = *(char_u **)(varp);
    return varp;
  }
  return find_termcode(tname + 2);
}

char_u *get_highlight_default(void)              {
  int i;

  i = findoption((char_u *)"hl");
  if (i >= 0)
    return options[i].def_val[VI_DEFAULT];
  return (char_u *)NULL;
}

char_u *get_encoding_default(void)              {
  int i;

  i = findoption((char_u *)"enc");
  if (i >= 0)
    return options[i].def_val[VI_DEFAULT];
  return (char_u *)NULL;
}

/*
 * Translate a string like "t_xx", "<t_xx>" or "<S-Tab>" to a key number.
 */
static int find_key_option(char_u *arg)
{
  int key;
  int modifiers;

  /*
   * Don't use get_special_key_code() for t_xx, we don't want it to call
   * add_termcap_entry().
   */
  if (arg[0] == 't' && arg[1] == '_' && arg[2] && arg[3])
    key = TERMCAP2KEY(arg[2], arg[3]);
  else {
    --arg;                          /* put arg at the '<' */
    modifiers = 0;
    key = find_special_key(&arg, &modifiers, TRUE, TRUE);
    if (modifiers)                  /* can't handle modifiers here */
      key = 0;
  }
  return key;
}

/*
 * if 'all' == 0: show changed options
 * if 'all' == 1: show all normal options
 * if 'all' == 2: show all terminal options
 */
static void 
showoptions (
    int all,
    int opt_flags                  /* OPT_LOCAL and/or OPT_GLOBAL */
)
{
  struct vimoption    *p;
  int col;
  int isterm;
  char_u              *varp;
  struct vimoption    **items;
  int item_count;
  int run;
  int row, rows;
  int cols;
  int i;
  int len;

#define INC 20
#define GAP 3

  items = (struct vimoption **)alloc((unsigned)(sizeof(struct vimoption *) *
                                                PARAM_COUNT));
  if (items == NULL)
    return;

  /* Highlight title */
  if (all == 2)
    MSG_PUTS_TITLE(_("\n--- Terminal codes ---"));
  else if (opt_flags & OPT_GLOBAL)
    MSG_PUTS_TITLE(_("\n--- Global option values ---"));
  else if (opt_flags & OPT_LOCAL)
    MSG_PUTS_TITLE(_("\n--- Local option values ---"));
  else
    MSG_PUTS_TITLE(_("\n--- Options ---"));

  /*
   * do the loop two times:
   * 1. display the short items
   * 2. display the long items (only strings and numbers)
   */
  for (run = 1; run <= 2 && !got_int; ++run) {
    /*
     * collect the items in items[]
     */
    item_count = 0;
    for (p = &options[0]; p->fullname != NULL; p++) {
      varp = NULL;
      isterm = istermoption(p);
      if (opt_flags != 0) {
        if (p->indir != PV_NONE && !isterm)
          varp = get_varp_scope(p, opt_flags);
      } else
        varp = get_varp(p);
      if (varp != NULL
          && ((all == 2 && isterm)
              || (all == 1 && !isterm)
              || (all == 0 && !optval_default(p, varp)))) {
        if (p->flags & P_BOOL)
          len = 1;                      /* a toggle option fits always */
        else {
          option_value2string(p, opt_flags);
          len = (int)STRLEN(p->fullname) + vim_strsize(NameBuff) + 1;
        }
        if ((len <= INC - GAP && run == 1) ||
            (len > INC - GAP && run == 2))
          items[item_count++] = p;
      }
    }

    /*
     * display the items
     */
    if (run == 1) {
      cols = (Columns + GAP - 3) / INC;
      if (cols == 0)
        cols = 1;
      rows = (item_count + cols - 1) / cols;
    } else      /* run == 2 */
      rows = item_count;
    for (row = 0; row < rows && !got_int; ++row) {
      msg_putchar('\n');                        /* go to next line */
      if (got_int)                              /* 'q' typed in more */
        break;
      col = 0;
      for (i = row; i < item_count; i += rows) {
        msg_col = col;                          /* make columns */
        showoneopt(items[i], opt_flags);
        col += INC;
      }
      out_flush();
      ui_breakcheck();
    }
  }
  vim_free(items);
}

/*
 * Return TRUE if option "p" has its default value.
 */
static int optval_default(struct vimoption *p, char_u *varp)
{
  int dvi;

  if (varp == NULL)
    return TRUE;            /* hidden option is always at default */
  dvi = ((p->flags & P_VI_DEF) || p_cp) ? VI_DEFAULT : VIM_DEFAULT;
  if (p->flags & P_NUM)
    return *(long *)varp == (long)(long_i)p->def_val[dvi];
  if (p->flags & P_BOOL)
    /* the cast to long is required for Manx C, long_i is
     * needed for MSVC */
    return *(int *)varp == (int)(long)(long_i)p->def_val[dvi];
  /* P_STRING */
  return STRCMP(*(char_u **)varp, p->def_val[dvi]) == 0;
}

/*
 * showoneopt: show the value of one option
 * must not be called with a hidden option!
 */
static void 
showoneopt (
    struct vimoption *p,
    int opt_flags                          /* OPT_LOCAL or OPT_GLOBAL */
)
{
  char_u      *varp;
  int save_silent = silent_mode;

  silent_mode = FALSE;
  info_message = TRUE;          /* use mch_msg(), not mch_errmsg() */

  varp = get_varp_scope(p, opt_flags);

  /* for 'modified' we also need to check if 'ff' or 'fenc' changed. */
  if ((p->flags & P_BOOL) && ((int *)varp == &curbuf->b_changed
                              ? !curbufIsChanged() : !*(int *)varp))
    MSG_PUTS("no");
  else if ((p->flags & P_BOOL) && *(int *)varp < 0)
    MSG_PUTS("--");
  else
    MSG_PUTS("  ");
  MSG_PUTS(p->fullname);
  if (!(p->flags & P_BOOL)) {
    msg_putchar('=');
    /* put value string in NameBuff */
    option_value2string(p, opt_flags);
    msg_outtrans(NameBuff);
  }

  silent_mode = save_silent;
  info_message = FALSE;
}

/*
 * Write modified options as ":set" commands to a file.
 *
 * There are three values for "opt_flags":
 * OPT_GLOBAL:		   Write global option values and fresh values of
 *			   buffer-local options (used for start of a session
 *			   file).
 * OPT_GLOBAL + OPT_LOCAL: Idem, add fresh values of window-local options for
 *			   curwin (used for a vimrc file).
 * OPT_LOCAL:		   Write buffer-local option values for curbuf, fresh
 *			   and local values for window-local options of
 *			   curwin.  Local values are also written when at the
 *			   default value, because a modeline or autocommand
 *			   may have set them when doing ":edit file" and the
 *			   user has set them back at the default or fresh
 *			   value.
 *			   When "local_only" is TRUE, don't write fresh
 *			   values, only local values (for ":mkview").
 * (fresh value = value used for a new buffer or window for a local option).
 *
 * Return FAIL on error, OK otherwise.
 */
int makeset(FILE *fd, int opt_flags, int local_only)
{
  struct vimoption    *p;
  char_u              *varp;                    /* currently used value */
  char_u              *varp_fresh;              /* local value */
  char_u              *varp_local = NULL;       /* fresh value */
  char                *cmd;
  int round;
  int pri;

  /*
   * The options that don't have a default (terminal name, columns, lines)
   * are never written.  Terminal options are also not written.
   * Do the loop over "options[]" twice: once for options with the
   * P_PRI_MKRC flag and once without.
   */
  for (pri = 1; pri >= 0; --pri) {
    for (p = &options[0]; !istermoption(p); p++)
      if (!(p->flags & P_NO_MKRC)
          && !istermoption(p)
          && ((pri == 1) == ((p->flags & P_PRI_MKRC) != 0))) {
        /* skip global option when only doing locals */
        if (p->indir == PV_NONE && !(opt_flags & OPT_GLOBAL))
          continue;

        /* Do not store options like 'bufhidden' and 'syntax' in a vimrc
         * file, they are always buffer-specific. */
        if ((opt_flags & OPT_GLOBAL) && (p->flags & P_NOGLOB))
          continue;

        /* Global values are only written when not at the default value. */
        varp = get_varp_scope(p, opt_flags);
        if ((opt_flags & OPT_GLOBAL) && optval_default(p, varp))
          continue;

        round = 2;
        if (p->indir != PV_NONE) {
          if (p->var == VAR_WIN) {
            /* skip window-local option when only doing globals */
            if (!(opt_flags & OPT_LOCAL))
              continue;
            /* When fresh value of window-local option is not at the
             * default, need to write it too. */
            if (!(opt_flags & OPT_GLOBAL) && !local_only) {
              varp_fresh = get_varp_scope(p, OPT_GLOBAL);
              if (!optval_default(p, varp_fresh)) {
                round = 1;
                varp_local = varp;
                varp = varp_fresh;
              }
            }
          }
        }

        /* Round 1: fresh value for window-local options.
         * Round 2: other values */
        for (; round <= 2; varp = varp_local, ++round) {
          if (round == 1 || (opt_flags & OPT_GLOBAL))
            cmd = "set";
          else
            cmd = "setlocal";

          if (p->flags & P_BOOL) {
            if (put_setbool(fd, cmd, p->fullname, *(int *)varp) == FAIL)
              return FAIL;
          } else if (p->flags & P_NUM)   {
            if (put_setnum(fd, cmd, p->fullname, (long *)varp) == FAIL)
              return FAIL;
          } else   {    /* P_STRING */
            int do_endif = FALSE;

            /* Don't set 'syntax' and 'filetype' again if the value is
             * already right, avoids reloading the syntax file. */
            if (
              p->indir == PV_SYN
              ||
              p->indir == PV_FT
              ) {
              if (fprintf(fd, "if &%s != '%s'", p->fullname,
                      *(char_u **)(varp)) < 0
                  || put_eol(fd) < 0)
                return FAIL;
              do_endif = TRUE;
            }
            if (put_setstring(fd, cmd, p->fullname, (char_u **)varp,
                    (p->flags & P_EXPAND) != 0) == FAIL)
              return FAIL;
            if (do_endif) {
              if (put_line(fd, "endif") == FAIL)
                return FAIL;
            }
          }
        }
      }
  }
  return OK;
}

/*
 * Generate set commands for the local fold options only.  Used when
 * 'sessionoptions' or 'viewoptions' contains "folds" but not "options".
 */
int makefoldset(FILE *fd)
{
  if (put_setstring(fd, "setlocal", "fdm", &curwin->w_p_fdm, FALSE) == FAIL
      || put_setstring(fd, "setlocal", "fde", &curwin->w_p_fde, FALSE)
      == FAIL
      || put_setstring(fd, "setlocal", "fmr", &curwin->w_p_fmr, FALSE)
      == FAIL
      || put_setstring(fd, "setlocal", "fdi", &curwin->w_p_fdi, FALSE)
      == FAIL
      || put_setnum(fd, "setlocal", "fdl", &curwin->w_p_fdl) == FAIL
      || put_setnum(fd, "setlocal", "fml", &curwin->w_p_fml) == FAIL
      || put_setnum(fd, "setlocal", "fdn", &curwin->w_p_fdn) == FAIL
      || put_setbool(fd, "setlocal", "fen", curwin->w_p_fen) == FAIL
      )
    return FAIL;

  return OK;
}

static int put_setstring(FILE *fd, char *cmd, char *name, char_u **valuep, int expand)
{
  char_u      *s;
  char_u      *buf;

  if (fprintf(fd, "%s %s=", cmd, name) < 0)
    return FAIL;
  if (*valuep != NULL) {
    /* Output 'pastetoggle' as key names.  For other
     * options some characters have to be escaped with
     * CTRL-V or backslash */
    if (valuep == &p_pt) {
      s = *valuep;
      while (*s != NUL)
        if (put_escstr(fd, str2special(&s, FALSE), 2) == FAIL)
          return FAIL;
    } else if (expand)   {
      buf = alloc(MAXPATHL);
      if (buf == NULL)
        return FAIL;
      home_replace(NULL, *valuep, buf, MAXPATHL, FALSE);
      if (put_escstr(fd, buf, 2) == FAIL) {
        vim_free(buf);
        return FAIL;
      }
      vim_free(buf);
    } else if (put_escstr(fd, *valuep, 2) == FAIL)
      return FAIL;
  }
  if (put_eol(fd) < 0)
    return FAIL;
  return OK;
}

static int put_setnum(FILE *fd, char *cmd, char *name, long *valuep)
{
  long wc;

  if (fprintf(fd, "%s %s=", cmd, name) < 0)
    return FAIL;
  if (wc_use_keyname((char_u *)valuep, &wc)) {
    /* print 'wildchar' and 'wildcharm' as a key name */
    if (fputs((char *)get_special_key_name((int)wc, 0), fd) < 0)
      return FAIL;
  } else if (fprintf(fd, "%ld", *valuep) < 0)
    return FAIL;
  if (put_eol(fd) < 0)
    return FAIL;
  return OK;
}

static int put_setbool(FILE *fd, char *cmd, char *name, int value)
{
  if (value < 0)        /* global/local option using global value */
    return OK;
  if (fprintf(fd, "%s %s%s", cmd, value ? "" : "no", name) < 0
      || put_eol(fd) < 0)
    return FAIL;
  return OK;
}

/*
 * Clear all the terminal options.
 * If the option has been allocated, free the memory.
 * Terminal options are never hidden or indirect.
 */
void clear_termoptions(void)          {
  /*
   * Reset a few things before clearing the old options. This may cause
   * outputting a few things that the terminal doesn't understand, but the
   * screen will be cleared later, so this is OK.
   */
  mch_setmouse(FALSE);              /* switch mouse off */
  mch_restore_title(3);             /* restore window titles */
  stoptermcap();                        /* stop termcap mode */

  free_termoptions();
}

void free_termoptions(void)          {
  struct vimoption   *p;

  for (p = &options[0]; p->fullname != NULL; p++)
    if (istermoption(p)) {
      if (p->flags & P_ALLOCED)
        free_string_option(*(char_u **)(p->var));
      if (p->flags & P_DEF_ALLOCED)
        free_string_option(p->def_val[VI_DEFAULT]);
      *(char_u **)(p->var) = empty_option;
      p->def_val[VI_DEFAULT] = empty_option;
      p->flags &= ~(P_ALLOCED|P_DEF_ALLOCED);
    }
  clear_termcodes();
}

/*
 * Free the string for one term option, if it was allocated.
 * Set the string to empty_option and clear allocated flag.
 * "var" points to the option value.
 */
void free_one_termoption(char_u *var)
{
  struct vimoption   *p;

  for (p = &options[0]; p->fullname != NULL; p++)
    if (p->var == var) {
      if (p->flags & P_ALLOCED)
        free_string_option(*(char_u **)(p->var));
      *(char_u **)(p->var) = empty_option;
      p->flags &= ~P_ALLOCED;
      break;
    }
}

/*
 * Set the terminal option defaults to the current value.
 * Used after setting the terminal name.
 */
void set_term_defaults(void)          {
  struct vimoption   *p;

  for (p = &options[0]; p->fullname != NULL; p++) {
    if (istermoption(p) && p->def_val[VI_DEFAULT] != *(char_u **)(p->var)) {
      if (p->flags & P_DEF_ALLOCED) {
        free_string_option(p->def_val[VI_DEFAULT]);
        p->flags &= ~P_DEF_ALLOCED;
      }
      p->def_val[VI_DEFAULT] = *(char_u **)(p->var);
      if (p->flags & P_ALLOCED) {
        p->flags |= P_DEF_ALLOCED;
        p->flags &= ~P_ALLOCED;          /* don't free the value now */
      }
    }
  }
}

/*
 * return TRUE if 'p' starts with 't_'
 */
static int istermoption(struct vimoption *p)
{
  return p->fullname[0] == 't' && p->fullname[1] == '_';
}

/*
 * Compute columns for ruler and shown command. 'sc_col' is also used to
 * decide what the maximum length of a message on the status line can be.
 * If there is a status line for the last window, 'sc_col' is independent
 * of 'ru_col'.
 */

#define COL_RULER 17        /* columns needed by standard ruler */

void comp_col(void)          {
  int last_has_status = (p_ls == 2 || (p_ls == 1 && firstwin != lastwin));

  sc_col = 0;
  ru_col = 0;
  if (p_ru) {
    ru_col = (ru_wid ? ru_wid : COL_RULER) + 1;
    /* no last status line, adjust sc_col */
    if (!last_has_status)
      sc_col = ru_col;
  }
  if (p_sc) {
    sc_col += SHOWCMD_COLS;
    if (!p_ru || last_has_status)           /* no need for separating space */
      ++sc_col;
  }
  sc_col = Columns - sc_col;
  ru_col = Columns - ru_col;
  if (sc_col <= 0)              /* screen too narrow, will become a mess */
    sc_col = 1;
  if (ru_col <= 0)
    ru_col = 1;
}

/*
 * Unset local option value, similar to ":set opt<".
 */
void unset_global_local_option(char_u *name, void *from)
{
  struct vimoption *p;
  int opt_idx;
  buf_T       *buf = (buf_T *)from;

  opt_idx = findoption(name);
  p = &(options[opt_idx]);

  switch ((int)p->indir) {
  /* global option with local value: use local value if it's been set */
  case PV_EP:
    clear_string_option(&buf->b_p_ep);
    break;
  case PV_KP:
    clear_string_option(&buf->b_p_kp);
    break;
  case PV_PATH:
    clear_string_option(&buf->b_p_path);
    break;
  case PV_AR:
    buf->b_p_ar = -1;
    break;
  case PV_TAGS:
    clear_string_option(&buf->b_p_tags);
    break;
  case PV_DEF:
    clear_string_option(&buf->b_p_def);
    break;
  case PV_INC:
    clear_string_option(&buf->b_p_inc);
    break;
  case PV_DICT:
    clear_string_option(&buf->b_p_dict);
    break;
  case PV_TSR:
    clear_string_option(&buf->b_p_tsr);
    break;
  case PV_EFM:
    clear_string_option(&buf->b_p_efm);
    break;
  case PV_GP:
    clear_string_option(&buf->b_p_gp);
    break;
  case PV_MP:
    clear_string_option(&buf->b_p_mp);
    break;
  case PV_CM:
    clear_string_option(&buf->b_p_cm);
    break;
  case PV_STL:
    clear_string_option(&((win_T *)from)->w_p_stl);
    break;
  case PV_UL:
    buf->b_p_ul = NO_LOCAL_UNDOLEVEL;
    break;
  }
}

/*
 * Get pointer to option variable, depending on local or global scope.
 */
static char_u *get_varp_scope(struct vimoption *p, int opt_flags)
{
  if ((opt_flags & OPT_GLOBAL) && p->indir != PV_NONE) {
    if (p->var == VAR_WIN)
      return (char_u *)GLOBAL_WO(get_varp(p));
    return p->var;
  }
  if ((opt_flags & OPT_LOCAL) && ((int)p->indir & PV_BOTH)) {
    switch ((int)p->indir) {
    case PV_EFM:  return (char_u *)&(curbuf->b_p_efm);
    case PV_GP:   return (char_u *)&(curbuf->b_p_gp);
    case PV_MP:   return (char_u *)&(curbuf->b_p_mp);
    case PV_EP:   return (char_u *)&(curbuf->b_p_ep);
    case PV_KP:   return (char_u *)&(curbuf->b_p_kp);
    case PV_PATH: return (char_u *)&(curbuf->b_p_path);
    case PV_AR:   return (char_u *)&(curbuf->b_p_ar);
    case PV_TAGS: return (char_u *)&(curbuf->b_p_tags);
    case PV_DEF:  return (char_u *)&(curbuf->b_p_def);
    case PV_INC:  return (char_u *)&(curbuf->b_p_inc);
    case PV_DICT: return (char_u *)&(curbuf->b_p_dict);
    case PV_TSR:  return (char_u *)&(curbuf->b_p_tsr);
    case PV_CM:   return (char_u *)&(curbuf->b_p_cm);
    case PV_STL:  return (char_u *)&(curwin->w_p_stl);
    case PV_UL:   return (char_u *)&(curbuf->b_p_ul);
    }
    return NULL;     /* "cannot happen" */
  }
  return get_varp(p);
}

/*
 * Get pointer to option variable.
 */
static char_u *get_varp(struct vimoption *p)
{
  /* hidden option, always return NULL */
  if (p->var == NULL)
    return NULL;

  switch ((int)p->indir) {
  case PV_NONE:   return p->var;

  /* global option with local value: use local value if it's been set */
  case PV_EP:     return *curbuf->b_p_ep != NUL
           ? (char_u *)&curbuf->b_p_ep : p->var;
  case PV_KP:     return *curbuf->b_p_kp != NUL
           ? (char_u *)&curbuf->b_p_kp : p->var;
  case PV_PATH:   return *curbuf->b_p_path != NUL
           ? (char_u *)&(curbuf->b_p_path) : p->var;
  case PV_AR:     return curbuf->b_p_ar >= 0
           ? (char_u *)&(curbuf->b_p_ar) : p->var;
  case PV_TAGS:   return *curbuf->b_p_tags != NUL
           ? (char_u *)&(curbuf->b_p_tags) : p->var;
  case PV_DEF:    return *curbuf->b_p_def != NUL
           ? (char_u *)&(curbuf->b_p_def) : p->var;
  case PV_INC:    return *curbuf->b_p_inc != NUL
           ? (char_u *)&(curbuf->b_p_inc) : p->var;
  case PV_DICT:   return *curbuf->b_p_dict != NUL
           ? (char_u *)&(curbuf->b_p_dict) : p->var;
  case PV_TSR:    return *curbuf->b_p_tsr != NUL
           ? (char_u *)&(curbuf->b_p_tsr) : p->var;
  case PV_EFM:    return *curbuf->b_p_efm != NUL
           ? (char_u *)&(curbuf->b_p_efm) : p->var;
  case PV_GP:     return *curbuf->b_p_gp != NUL
           ? (char_u *)&(curbuf->b_p_gp) : p->var;
  case PV_MP:     return *curbuf->b_p_mp != NUL
           ? (char_u *)&(curbuf->b_p_mp) : p->var;
  case PV_CM:     return *curbuf->b_p_cm != NUL
           ? (char_u *)&(curbuf->b_p_cm) : p->var;
  case PV_STL:    return *curwin->w_p_stl != NUL
           ? (char_u *)&(curwin->w_p_stl) : p->var;
  case PV_UL:     return curbuf->b_p_ul != NO_LOCAL_UNDOLEVEL
           ? (char_u *)&(curbuf->b_p_ul) : p->var;

  case PV_ARAB:   return (char_u *)&(curwin->w_p_arab);
  case PV_LIST:   return (char_u *)&(curwin->w_p_list);
  case PV_SPELL:  return (char_u *)&(curwin->w_p_spell);
  case PV_CUC:    return (char_u *)&(curwin->w_p_cuc);
  case PV_CUL:    return (char_u *)&(curwin->w_p_cul);
  case PV_CC:     return (char_u *)&(curwin->w_p_cc);
  case PV_DIFF:   return (char_u *)&(curwin->w_p_diff);
  case PV_FDC:    return (char_u *)&(curwin->w_p_fdc);
  case PV_FEN:    return (char_u *)&(curwin->w_p_fen);
  case PV_FDI:    return (char_u *)&(curwin->w_p_fdi);
  case PV_FDL:    return (char_u *)&(curwin->w_p_fdl);
  case PV_FDM:    return (char_u *)&(curwin->w_p_fdm);
  case PV_FML:    return (char_u *)&(curwin->w_p_fml);
  case PV_FDN:    return (char_u *)&(curwin->w_p_fdn);
  case PV_FDE:    return (char_u *)&(curwin->w_p_fde);
  case PV_FDT:    return (char_u *)&(curwin->w_p_fdt);
  case PV_FMR:    return (char_u *)&(curwin->w_p_fmr);
  case PV_NU:     return (char_u *)&(curwin->w_p_nu);
  case PV_RNU:    return (char_u *)&(curwin->w_p_rnu);
  case PV_NUW:    return (char_u *)&(curwin->w_p_nuw);
  case PV_WFH:    return (char_u *)&(curwin->w_p_wfh);
  case PV_WFW:    return (char_u *)&(curwin->w_p_wfw);
  case PV_PVW:    return (char_u *)&(curwin->w_p_pvw);
  case PV_RL:     return (char_u *)&(curwin->w_p_rl);
  case PV_RLC:    return (char_u *)&(curwin->w_p_rlc);
  case PV_SCROLL: return (char_u *)&(curwin->w_p_scr);
  case PV_WRAP:   return (char_u *)&(curwin->w_p_wrap);
  case PV_LBR:    return (char_u *)&(curwin->w_p_lbr);
  case PV_SCBIND: return (char_u *)&(curwin->w_p_scb);
  case PV_CRBIND: return (char_u *)&(curwin->w_p_crb);
  case PV_COCU:    return (char_u *)&(curwin->w_p_cocu);
  case PV_COLE:    return (char_u *)&(curwin->w_p_cole);

  case PV_AI:     return (char_u *)&(curbuf->b_p_ai);
  case PV_BIN:    return (char_u *)&(curbuf->b_p_bin);
  case PV_BOMB:   return (char_u *)&(curbuf->b_p_bomb);
  case PV_BH:     return (char_u *)&(curbuf->b_p_bh);
  case PV_BT:     return (char_u *)&(curbuf->b_p_bt);
  case PV_BL:     return (char_u *)&(curbuf->b_p_bl);
  case PV_CI:     return (char_u *)&(curbuf->b_p_ci);
  case PV_CIN:    return (char_u *)&(curbuf->b_p_cin);
  case PV_CINK:   return (char_u *)&(curbuf->b_p_cink);
  case PV_CINO:   return (char_u *)&(curbuf->b_p_cino);
  case PV_CINW:   return (char_u *)&(curbuf->b_p_cinw);
  case PV_COM:    return (char_u *)&(curbuf->b_p_com);
  case PV_CMS:    return (char_u *)&(curbuf->b_p_cms);
  case PV_CPT:    return (char_u *)&(curbuf->b_p_cpt);
  case PV_CFU:    return (char_u *)&(curbuf->b_p_cfu);
  case PV_OFU:    return (char_u *)&(curbuf->b_p_ofu);
  case PV_EOL:    return (char_u *)&(curbuf->b_p_eol);
  case PV_ET:     return (char_u *)&(curbuf->b_p_et);
  case PV_FENC:   return (char_u *)&(curbuf->b_p_fenc);
  case PV_FF:     return (char_u *)&(curbuf->b_p_ff);
  case PV_FT:     return (char_u *)&(curbuf->b_p_ft);
  case PV_FO:     return (char_u *)&(curbuf->b_p_fo);
  case PV_FLP:    return (char_u *)&(curbuf->b_p_flp);
  case PV_IMI:    return (char_u *)&(curbuf->b_p_iminsert);
  case PV_IMS:    return (char_u *)&(curbuf->b_p_imsearch);
  case PV_INF:    return (char_u *)&(curbuf->b_p_inf);
  case PV_ISK:    return (char_u *)&(curbuf->b_p_isk);
  case PV_INEX:   return (char_u *)&(curbuf->b_p_inex);
  case PV_INDE:   return (char_u *)&(curbuf->b_p_inde);
  case PV_INDK:   return (char_u *)&(curbuf->b_p_indk);
  case PV_FEX:    return (char_u *)&(curbuf->b_p_fex);
  case PV_KEY:    return (char_u *)&(curbuf->b_p_key);
  case PV_LISP:   return (char_u *)&(curbuf->b_p_lisp);
  case PV_ML:     return (char_u *)&(curbuf->b_p_ml);
  case PV_MPS:    return (char_u *)&(curbuf->b_p_mps);
  case PV_MA:     return (char_u *)&(curbuf->b_p_ma);
  case PV_MOD:    return (char_u *)&(curbuf->b_changed);
  case PV_NF:     return (char_u *)&(curbuf->b_p_nf);
  case PV_PI:     return (char_u *)&(curbuf->b_p_pi);
  case PV_QE:     return (char_u *)&(curbuf->b_p_qe);
  case PV_RO:     return (char_u *)&(curbuf->b_p_ro);
  case PV_SI:     return (char_u *)&(curbuf->b_p_si);
#ifndef SHORT_FNAME
  case PV_SN:     return (char_u *)&(curbuf->b_p_sn);
#endif
  case PV_STS:    return (char_u *)&(curbuf->b_p_sts);
  case PV_SUA:    return (char_u *)&(curbuf->b_p_sua);
  case PV_SWF:    return (char_u *)&(curbuf->b_p_swf);
  case PV_SMC:    return (char_u *)&(curbuf->b_p_smc);
  case PV_SYN:    return (char_u *)&(curbuf->b_p_syn);
  case PV_SPC:    return (char_u *)&(curwin->w_s->b_p_spc);
  case PV_SPF:    return (char_u *)&(curwin->w_s->b_p_spf);
  case PV_SPL:    return (char_u *)&(curwin->w_s->b_p_spl);
  case PV_SW:     return (char_u *)&(curbuf->b_p_sw);
  case PV_TS:     return (char_u *)&(curbuf->b_p_ts);
  case PV_TW:     return (char_u *)&(curbuf->b_p_tw);
  case PV_TX:     return (char_u *)&(curbuf->b_p_tx);
  case PV_UDF:    return (char_u *)&(curbuf->b_p_udf);
  case PV_WM:     return (char_u *)&(curbuf->b_p_wm);
  case PV_KMAP:   return (char_u *)&(curbuf->b_p_keymap);
  default:        EMSG(_("E356: get_varp ERROR"));
  }
  /* always return a valid pointer to avoid a crash! */
  return (char_u *)&(curbuf->b_p_wm);
}

/*
 * Get the value of 'equalprg', either the buffer-local one or the global one.
 */
char_u *get_equalprg(void)              {
  if (*curbuf->b_p_ep == NUL)
    return p_ep;
  return curbuf->b_p_ep;
}

/*
 * Copy options from one window to another.
 * Used when splitting a window.
 */
void win_copy_options(win_T *wp_from, win_T *wp_to)
{
  copy_winopt(&wp_from->w_onebuf_opt, &wp_to->w_onebuf_opt);
  copy_winopt(&wp_from->w_allbuf_opt, &wp_to->w_allbuf_opt);
  /* Is this right? */
  wp_to->w_farsi = wp_from->w_farsi;
}

/*
 * Copy the options from one winopt_T to another.
 * Doesn't free the old option values in "to", use clear_winopt() for that.
 * The 'scroll' option is not copied, because it depends on the window height.
 * The 'previewwindow' option is reset, there can be only one preview window.
 */
void copy_winopt(winopt_T *from, winopt_T *to)
{
  to->wo_arab = from->wo_arab;
  to->wo_list = from->wo_list;
  to->wo_nu = from->wo_nu;
  to->wo_rnu = from->wo_rnu;
  to->wo_nuw = from->wo_nuw;
  to->wo_rl  = from->wo_rl;
  to->wo_rlc = vim_strsave(from->wo_rlc);
  to->wo_stl = vim_strsave(from->wo_stl);
  to->wo_wrap = from->wo_wrap;
  to->wo_wrap_save = from->wo_wrap_save;
  to->wo_lbr = from->wo_lbr;
  to->wo_scb = from->wo_scb;
  to->wo_scb_save = from->wo_scb_save;
  to->wo_crb = from->wo_crb;
  to->wo_crb_save = from->wo_crb_save;
  to->wo_spell = from->wo_spell;
  to->wo_cuc = from->wo_cuc;
  to->wo_cul = from->wo_cul;
  to->wo_cc = vim_strsave(from->wo_cc);
  to->wo_diff = from->wo_diff;
  to->wo_diff_saved = from->wo_diff_saved;
  to->wo_cocu = vim_strsave(from->wo_cocu);
  to->wo_cole = from->wo_cole;
  to->wo_fdc = from->wo_fdc;
  to->wo_fdc_save = from->wo_fdc_save;
  to->wo_fen = from->wo_fen;
  to->wo_fen_save = from->wo_fen_save;
  to->wo_fdi = vim_strsave(from->wo_fdi);
  to->wo_fml = from->wo_fml;
  to->wo_fdl = from->wo_fdl;
  to->wo_fdl_save = from->wo_fdl_save;
  to->wo_fdm = vim_strsave(from->wo_fdm);
  to->wo_fdm_save = from->wo_diff_saved
                    ? vim_strsave(from->wo_fdm_save) : empty_option;
  to->wo_fdn = from->wo_fdn;
  to->wo_fde = vim_strsave(from->wo_fde);
  to->wo_fdt = vim_strsave(from->wo_fdt);
  to->wo_fmr = vim_strsave(from->wo_fmr);
  check_winopt(to);             /* don't want NULL pointers */
}

/*
 * Check string options in a window for a NULL value.
 */
void check_win_options(win_T *win)
{
  check_winopt(&win->w_onebuf_opt);
  check_winopt(&win->w_allbuf_opt);
}

/*
 * Check for NULL pointers in a winopt_T and replace them with empty_option.
 */
void check_winopt(winopt_T *wop)
{
  check_string_option(&wop->wo_fdi);
  check_string_option(&wop->wo_fdm);
  check_string_option(&wop->wo_fdm_save);
  check_string_option(&wop->wo_fde);
  check_string_option(&wop->wo_fdt);
  check_string_option(&wop->wo_fmr);
  check_string_option(&wop->wo_rlc);
  check_string_option(&wop->wo_stl);
  check_string_option(&wop->wo_cc);
  check_string_option(&wop->wo_cocu);
}

/*
 * Free the allocated memory inside a winopt_T.
 */
void clear_winopt(winopt_T *wop)
{
  clear_string_option(&wop->wo_fdi);
  clear_string_option(&wop->wo_fdm);
  clear_string_option(&wop->wo_fdm_save);
  clear_string_option(&wop->wo_fde);
  clear_string_option(&wop->wo_fdt);
  clear_string_option(&wop->wo_fmr);
  clear_string_option(&wop->wo_rlc);
  clear_string_option(&wop->wo_stl);
  clear_string_option(&wop->wo_cc);
  clear_string_option(&wop->wo_cocu);
}

/*
 * Copy global option values to local options for one buffer.
 * Used when creating a new buffer and sometimes when entering a buffer.
 * flags:
 * BCO_ENTER	We will enter the buf buffer.
 * BCO_ALWAYS	Always copy the options, but only set b_p_initialized when
 *		appropriate.
 * BCO_NOHELP	Don't copy the values to a help buffer.
 */
void buf_copy_options(buf_T *buf, int flags)
{
  int should_copy = TRUE;
  char_u      *save_p_isk = NULL;           /* init for GCC */
  int dont_do_help;
  int did_isk = FALSE;

  /*
   * Don't do anything if the buffer is invalid.
   */
  if (buf == NULL || !buf_valid(buf))
    return;

  /*
   * Skip this when the option defaults have not been set yet.  Happens when
   * main() allocates the first buffer.
   */
  if (p_cpo != NULL) {
    /*
     * Always copy when entering and 'cpo' contains 'S'.
     * Don't copy when already initialized.
     * Don't copy when 'cpo' contains 's' and not entering.
     * 'S'	BCO_ENTER  initialized	's'  should_copy
     * yes	  yes	       X	 X	TRUE
     * yes	  no	      yes	 X	FALSE
     * no	   X	      yes	 X	FALSE
     *  X	  no	      no	yes	FALSE
     *  X	  no	      no	no	TRUE
     * no	  yes	      no	 X	TRUE
     */
    if ((vim_strchr(p_cpo, CPO_BUFOPTGLOB) == NULL || !(flags & BCO_ENTER))
        && (buf->b_p_initialized
            || (!(flags & BCO_ENTER)
                && vim_strchr(p_cpo, CPO_BUFOPT) != NULL)))
      should_copy = FALSE;

    if (should_copy || (flags & BCO_ALWAYS)) {
      /* Don't copy the options specific to a help buffer when
      * BCO_NOHELP is given or the options were initialized already
      * (jumping back to a help file with CTRL-T or CTRL-O) */
      dont_do_help = ((flags & BCO_NOHELP) && buf->b_help)
                     || buf->b_p_initialized;
      if (dont_do_help) {               /* don't free b_p_isk */
        save_p_isk = buf->b_p_isk;
        buf->b_p_isk = NULL;
      }
      /*
       * Always free the allocated strings.
       * If not already initialized, set 'readonly' and copy 'fileformat'.
       */
      if (!buf->b_p_initialized) {
        free_buf_options(buf, TRUE);
        buf->b_p_ro = FALSE;                    /* don't copy readonly */
        buf->b_p_tx = p_tx;
        buf->b_p_fenc = vim_strsave(p_fenc);
        buf->b_p_ff = vim_strsave(p_ff);
        buf->b_p_bh = empty_option;
        buf->b_p_bt = empty_option;
      } else
        free_buf_options(buf, FALSE);

      buf->b_p_ai = p_ai;
      buf->b_p_ai_nopaste = p_ai_nopaste;
      buf->b_p_sw = p_sw;
      buf->b_p_tw = p_tw;
      buf->b_p_tw_nopaste = p_tw_nopaste;
      buf->b_p_tw_nobin = p_tw_nobin;
      buf->b_p_wm = p_wm;
      buf->b_p_wm_nopaste = p_wm_nopaste;
      buf->b_p_wm_nobin = p_wm_nobin;
      buf->b_p_bin = p_bin;
      buf->b_p_bomb = p_bomb;
      buf->b_p_et = p_et;
      buf->b_p_et_nobin = p_et_nobin;
      buf->b_p_ml = p_ml;
      buf->b_p_ml_nobin = p_ml_nobin;
      buf->b_p_inf = p_inf;
      buf->b_p_swf = p_swf;
      buf->b_p_cpt = vim_strsave(p_cpt);
      buf->b_p_cfu = vim_strsave(p_cfu);
      buf->b_p_ofu = vim_strsave(p_ofu);
      buf->b_p_sts = p_sts;
      buf->b_p_sts_nopaste = p_sts_nopaste;
#ifndef SHORT_FNAME
      buf->b_p_sn = p_sn;
#endif
      buf->b_p_com = vim_strsave(p_com);
      buf->b_p_cms = vim_strsave(p_cms);
      buf->b_p_fo = vim_strsave(p_fo);
      buf->b_p_flp = vim_strsave(p_flp);
      buf->b_p_nf = vim_strsave(p_nf);
      buf->b_p_mps = vim_strsave(p_mps);
      buf->b_p_si = p_si;
      buf->b_p_ci = p_ci;
      buf->b_p_cin = p_cin;
      buf->b_p_cink = vim_strsave(p_cink);
      buf->b_p_cino = vim_strsave(p_cino);
      /* Don't copy 'filetype', it must be detected */
      buf->b_p_ft = empty_option;
      buf->b_p_pi = p_pi;
      buf->b_p_cinw = vim_strsave(p_cinw);
      buf->b_p_lisp = p_lisp;
      /* Don't copy 'syntax', it must be set */
      buf->b_p_syn = empty_option;
      buf->b_p_smc = p_smc;
      buf->b_s.b_p_spc = vim_strsave(p_spc);
      (void)compile_cap_prog(&buf->b_s);
      buf->b_s.b_p_spf = vim_strsave(p_spf);
      buf->b_s.b_p_spl = vim_strsave(p_spl);
      buf->b_p_inde = vim_strsave(p_inde);
      buf->b_p_indk = vim_strsave(p_indk);
      buf->b_p_fex = vim_strsave(p_fex);
      buf->b_p_key = vim_strsave(p_key);
      buf->b_p_sua = vim_strsave(p_sua);
      buf->b_p_keymap = vim_strsave(p_keymap);
      buf->b_kmap_state |= KEYMAP_INIT;
      /* This isn't really an option, but copying the langmap and IME
      * state from the current buffer is better than resetting it. */
      buf->b_p_iminsert = p_iminsert;
      buf->b_p_imsearch = p_imsearch;

      /* options that are normally global but also have a local value
       * are not copied, start using the global value */
      buf->b_p_ar = -1;
      buf->b_p_ul = NO_LOCAL_UNDOLEVEL;
      buf->b_p_gp = empty_option;
      buf->b_p_mp = empty_option;
      buf->b_p_efm = empty_option;
      buf->b_p_ep = empty_option;
      buf->b_p_kp = empty_option;
      buf->b_p_path = empty_option;
      buf->b_p_tags = empty_option;
      buf->b_p_def = empty_option;
      buf->b_p_inc = empty_option;
      buf->b_p_inex = vim_strsave(p_inex);
      buf->b_p_dict = empty_option;
      buf->b_p_tsr = empty_option;
      buf->b_p_qe = vim_strsave(p_qe);
      buf->b_p_cm = empty_option;
      buf->b_p_udf = p_udf;

      /*
       * Don't copy the options set by ex_help(), use the saved values,
       * when going from a help buffer to a non-help buffer.
       * Don't touch these at all when BCO_NOHELP is used and going from
       * or to a help buffer.
       */
      if (dont_do_help)
        buf->b_p_isk = save_p_isk;
      else {
        buf->b_p_isk = vim_strsave(p_isk);
        did_isk = TRUE;
        buf->b_p_ts = p_ts;
        buf->b_help = FALSE;
        if (buf->b_p_bt[0] == 'h')
          clear_string_option(&buf->b_p_bt);
        buf->b_p_ma = p_ma;
      }
    }

    /*
     * When the options should be copied (ignoring BCO_ALWAYS), set the
     * flag that indicates that the options have been initialized.
     */
    if (should_copy)
      buf->b_p_initialized = TRUE;
  }

  check_buf_options(buf);           /* make sure we don't have NULLs */
  if (did_isk)
    (void)buf_init_chartab(buf, FALSE);
}

/*
 * Reset the 'modifiable' option and its default value.
 */
void reset_modifiable(void)          {
  int opt_idx;

  curbuf->b_p_ma = FALSE;
  p_ma = FALSE;
  opt_idx = findoption((char_u *)"ma");
  if (opt_idx >= 0)
    options[opt_idx].def_val[VI_DEFAULT] = FALSE;
}

/*
 * Set the global value for 'iminsert' to the local value.
 */
void set_iminsert_global(void)          {
  p_iminsert = curbuf->b_p_iminsert;
}

/*
 * Set the global value for 'imsearch' to the local value.
 */
void set_imsearch_global(void)          {
  p_imsearch = curbuf->b_p_imsearch;
}

static int expand_option_idx = -1;
static char_u expand_option_name[5] = {'t', '_', NUL, NUL, NUL};
static int expand_option_flags = 0;

void 
set_context_in_set_cmd (
    expand_T *xp,
    char_u *arg,
    int opt_flags                  /* OPT_GLOBAL and/or OPT_LOCAL */
)
{
  int nextchar;
  long_u flags = 0;             /* init for GCC */
  int opt_idx = 0;              /* init for GCC */
  char_u      *p;
  char_u      *s;
  int is_term_option = FALSE;
  int key;

  expand_option_flags = opt_flags;

  xp->xp_context = EXPAND_SETTINGS;
  if (*arg == NUL) {
    xp->xp_pattern = arg;
    return;
  }
  p = arg + STRLEN(arg) - 1;
  if (*p == ' ' && *(p - 1) != '\\') {
    xp->xp_pattern = p + 1;
    return;
  }
  while (p > arg) {
    s = p;
    /* count number of backslashes before ' ' or ',' */
    if (*p == ' ' || *p == ',') {
      while (s > arg && *(s - 1) == '\\')
        --s;
    }
    /* break at a space with an even number of backslashes */
    if (*p == ' ' && ((p - s) & 1) == 0) {
      ++p;
      break;
    }
    --p;
  }
  if (STRNCMP(p, "no", 2) == 0 && STRNCMP(p, "novice", 6) != 0) {
    xp->xp_context = EXPAND_BOOL_SETTINGS;
    p += 2;
  }
  if (STRNCMP(p, "inv", 3) == 0) {
    xp->xp_context = EXPAND_BOOL_SETTINGS;
    p += 3;
  }
  xp->xp_pattern = arg = p;
  if (*arg == '<') {
    while (*p != '>')
      if (*p++ == NUL)              /* expand terminal option name */
        return;
    key = get_special_key_code(arg + 1);
    if (key == 0) {                 /* unknown name */
      xp->xp_context = EXPAND_NOTHING;
      return;
    }
    nextchar = *++p;
    is_term_option = TRUE;
    expand_option_name[2] = KEY2TERMCAP0(key);
    expand_option_name[3] = KEY2TERMCAP1(key);
  } else   {
    if (p[0] == 't' && p[1] == '_') {
      p += 2;
      if (*p != NUL)
        ++p;
      if (*p == NUL)
        return;                 /* expand option name */
      nextchar = *++p;
      is_term_option = TRUE;
      expand_option_name[2] = p[-2];
      expand_option_name[3] = p[-1];
    } else   {
      /* Allow * wildcard */
      while (ASCII_ISALNUM(*p) || *p == '_' || *p == '*')
        p++;
      if (*p == NUL)
        return;
      nextchar = *p;
      *p = NUL;
      opt_idx = findoption(arg);
      *p = nextchar;
      if (opt_idx == -1 || options[opt_idx].var == NULL) {
        xp->xp_context = EXPAND_NOTHING;
        return;
      }
      flags = options[opt_idx].flags;
      if (flags & P_BOOL) {
        xp->xp_context = EXPAND_NOTHING;
        return;
      }
    }
  }
  /* handle "-=" and "+=" */
  if ((nextchar == '-' || nextchar == '+' || nextchar == '^') && p[1] == '=') {
    ++p;
    nextchar = '=';
  }
  if ((nextchar != '=' && nextchar != ':')
      || xp->xp_context == EXPAND_BOOL_SETTINGS) {
    xp->xp_context = EXPAND_UNSUCCESSFUL;
    return;
  }
  if (xp->xp_context != EXPAND_BOOL_SETTINGS && p[1] == NUL) {
    xp->xp_context = EXPAND_OLD_SETTING;
    if (is_term_option)
      expand_option_idx = -1;
    else
      expand_option_idx = opt_idx;
    xp->xp_pattern = p + 1;
    return;
  }
  xp->xp_context = EXPAND_NOTHING;
  if (is_term_option || (flags & P_NUM))
    return;

  xp->xp_pattern = p + 1;

  if (flags & P_EXPAND) {
    p = options[opt_idx].var;
    if (p == (char_u *)&p_bdir
        || p == (char_u *)&p_dir
        || p == (char_u *)&p_path
        || p == (char_u *)&p_rtp
        || p == (char_u *)&p_cdpath
        || p == (char_u *)&p_vdir
        ) {
      xp->xp_context = EXPAND_DIRECTORIES;
      if (p == (char_u *)&p_path
          || p == (char_u *)&p_cdpath
          )
        xp->xp_backslash = XP_BS_THREE;
      else
        xp->xp_backslash = XP_BS_ONE;
    } else   {
      xp->xp_context = EXPAND_FILES;
      /* for 'tags' need three backslashes for a space */
      if (p == (char_u *)&p_tags)
        xp->xp_backslash = XP_BS_THREE;
      else
        xp->xp_backslash = XP_BS_ONE;
    }
  }

  /* For an option that is a list of file names, find the start of the
   * last file name. */
  for (p = arg + STRLEN(arg) - 1; p > xp->xp_pattern; --p) {
    /* count number of backslashes before ' ' or ',' */
    if (*p == ' ' || *p == ',') {
      s = p;
      while (s > xp->xp_pattern && *(s - 1) == '\\')
        --s;
      if ((*p == ' ' && (xp->xp_backslash == XP_BS_THREE && (p - s) < 3))
          || (*p == ',' && (flags & P_COMMA) && ((p - s) & 1) == 0)) {
        xp->xp_pattern = p + 1;
        break;
      }
    }

    /* for 'spellsuggest' start at "file:" */
    if (options[opt_idx].var == (char_u *)&p_sps
        && STRNCMP(p, "file:", 5) == 0) {
      xp->xp_pattern = p + 5;
      break;
    }
  }

  return;
}

int ExpandSettings(expand_T *xp, regmatch_T *regmatch, int *num_file, char_u ***file)
{
  int num_normal = 0;               /* Nr of matching non-term-code settings */
  int num_term = 0;                 /* Nr of matching terminal code settings */
  int opt_idx;
  int match;
  int count = 0;
  char_u      *str;
  int loop;
  int is_term_opt;
  char_u name_buf[MAX_KEY_NAME_LEN];
  static char *(names[]) = {"all", "termcap"};
  int ic = regmatch->rm_ic;             /* remember the ignore-case flag */

  /* do this loop twice:
   * loop == 0: count the number of matching options
   * loop == 1: copy the matching options into allocated memory
   */
  for (loop = 0; loop <= 1; ++loop) {
    regmatch->rm_ic = ic;
    if (xp->xp_context != EXPAND_BOOL_SETTINGS) {
      for (match = 0; match < (int)(sizeof(names) / sizeof(char *));
           ++match)
        if (vim_regexec(regmatch, (char_u *)names[match], (colnr_T)0)) {
          if (loop == 0)
            num_normal++;
          else
            (*file)[count++] = vim_strsave((char_u *)names[match]);
        }
    }
    for (opt_idx = 0; (str = (char_u *)options[opt_idx].fullname) != NULL;
         opt_idx++) {
      if (options[opt_idx].var == NULL)
        continue;
      if (xp->xp_context == EXPAND_BOOL_SETTINGS
          && !(options[opt_idx].flags & P_BOOL))
        continue;
      is_term_opt = istermoption(&options[opt_idx]);
      if (is_term_opt && num_normal > 0)
        continue;
      match = FALSE;
      if (vim_regexec(regmatch, str, (colnr_T)0)
          || (options[opt_idx].shortname != NULL
              && vim_regexec(regmatch,
                  (char_u *)options[opt_idx].shortname, (colnr_T)0)))
        match = TRUE;
      else if (is_term_opt) {
        name_buf[0] = '<';
        name_buf[1] = 't';
        name_buf[2] = '_';
        name_buf[3] = str[2];
        name_buf[4] = str[3];
        name_buf[5] = '>';
        name_buf[6] = NUL;
        if (vim_regexec(regmatch, name_buf, (colnr_T)0)) {
          match = TRUE;
          str = name_buf;
        }
      }
      if (match) {
        if (loop == 0) {
          if (is_term_opt)
            num_term++;
          else
            num_normal++;
        } else
          (*file)[count++] = vim_strsave(str);
      }
    }
    /*
     * Check terminal key codes, these are not in the option table
     */
    if (xp->xp_context != EXPAND_BOOL_SETTINGS  && num_normal == 0) {
      for (opt_idx = 0; (str = get_termcode(opt_idx)) != NULL; opt_idx++) {
        if (!isprint(str[0]) || !isprint(str[1]))
          continue;

        name_buf[0] = 't';
        name_buf[1] = '_';
        name_buf[2] = str[0];
        name_buf[3] = str[1];
        name_buf[4] = NUL;

        match = FALSE;
        if (vim_regexec(regmatch, name_buf, (colnr_T)0))
          match = TRUE;
        else {
          name_buf[0] = '<';
          name_buf[1] = 't';
          name_buf[2] = '_';
          name_buf[3] = str[0];
          name_buf[4] = str[1];
          name_buf[5] = '>';
          name_buf[6] = NUL;

          if (vim_regexec(regmatch, name_buf, (colnr_T)0))
            match = TRUE;
        }
        if (match) {
          if (loop == 0)
            num_term++;
          else
            (*file)[count++] = vim_strsave(name_buf);
        }
      }

      /*
       * Check special key names.
       */
      regmatch->rm_ic = TRUE;                   /* ignore case here */
      for (opt_idx = 0; (str = get_key_name(opt_idx)) != NULL; opt_idx++) {
        name_buf[0] = '<';
        STRCPY(name_buf + 1, str);
        STRCAT(name_buf, ">");

        if (vim_regexec(regmatch, name_buf, (colnr_T)0)) {
          if (loop == 0)
            num_term++;
          else
            (*file)[count++] = vim_strsave(name_buf);
        }
      }
    }
    if (loop == 0) {
      if (num_normal > 0)
        *num_file = num_normal;
      else if (num_term > 0)
        *num_file = num_term;
      else
        return OK;
      *file = (char_u **)alloc((unsigned)(*num_file * sizeof(char_u *)));
      if (*file == NULL) {
        *file = (char_u **)"";
        return FAIL;
      }
    }
  }
  return OK;
}

int ExpandOldSetting(int *num_file, char_u ***file)
{
  char_u  *var = NULL;          /* init for GCC */
  char_u  *buf;

  *num_file = 0;
  *file = (char_u **)alloc((unsigned)sizeof(char_u *));
  if (*file == NULL)
    return FAIL;

  /*
   * For a terminal key code expand_option_idx is < 0.
   */
  if (expand_option_idx < 0) {
    var = find_termcode(expand_option_name + 2);
    if (var == NULL)
      expand_option_idx = findoption(expand_option_name);
  }

  if (expand_option_idx >= 0) {
    /* put string of option value in NameBuff */
    option_value2string(&options[expand_option_idx], expand_option_flags);
    var = NameBuff;
  } else if (var == NULL)
    var = (char_u *)"";

  /* A backslash is required before some characters.  This is the reverse of
   * what happens in do_set(). */
  buf = vim_strsave_escaped(var, escape_chars);

  if (buf == NULL) {
    vim_free(*file);
    *file = NULL;
    return FAIL;
  }

#ifdef BACKSLASH_IN_FILENAME
  /* For MS-Windows et al. we don't double backslashes at the start and
   * before a file name character. */
  for (var = buf; *var != NUL; mb_ptr_adv(var))
    if (var[0] == '\\' && var[1] == '\\'
        && expand_option_idx >= 0
        && (options[expand_option_idx].flags & P_EXPAND)
        && vim_isfilec(var[2])
        && (var[2] != '\\' || (var == buf && var[4] != '\\')))
      STRMOVE(var, var + 1);
#endif

  *file[0] = buf;
  *num_file = 1;
  return OK;
}

/*
 * Get the value for the numeric or string option *opp in a nice format into
 * NameBuff[].  Must not be called with a hidden option!
 */
static void 
option_value2string (
    struct vimoption *opp,
    int opt_flags                          /* OPT_GLOBAL and/or OPT_LOCAL */
)
{
  char_u      *varp;

  varp = get_varp_scope(opp, opt_flags);

  if (opp->flags & P_NUM) {
    long wc = 0;

    if (wc_use_keyname(varp, &wc))
      STRCPY(NameBuff, get_special_key_name((int)wc, 0));
    else if (wc != 0)
      STRCPY(NameBuff, transchar((int)wc));
    else
      sprintf((char *)NameBuff, "%ld", *(long *)varp);
  } else   { /* P_STRING */
    varp = *(char_u **)(varp);
    if (varp == NULL)                       /* just in case */
      NameBuff[0] = NUL;
    /* don't show the actual value of 'key', only that it's set */
    else if (opp->var == (char_u *)&p_key && *varp)
      STRCPY(NameBuff, "*****");
    else if (opp->flags & P_EXPAND)
      home_replace(NULL, varp, NameBuff, MAXPATHL, FALSE);
    /* Translate 'pastetoggle' into special key names */
    else if ((char_u **)opp->var == &p_pt)
      str2specialbuf(p_pt, NameBuff, MAXPATHL);
    else
      vim_strncpy(NameBuff, varp, MAXPATHL - 1);
  }
}

/*
 * Return TRUE if "varp" points to 'wildchar' or 'wildcharm' and it can be
 * printed as a keyname.
 * "*wcp" is set to the value of the option if it's 'wildchar' or 'wildcharm'.
 */
static int wc_use_keyname(char_u *varp, long *wcp)
{
  if (((long *)varp == &p_wc) || ((long *)varp == &p_wcm)) {
    *wcp = *(long *)varp;
    if (IS_SPECIAL(*wcp) || find_special_key_in_table((int)*wcp) >= 0)
      return TRUE;
  }
  return FALSE;
}

/*
 * Any character has an equivalent 'langmap' character.  This is used for
 * keyboards that have a special language mode that sends characters above
 * 128 (although other characters can be translated too).  The "to" field is a
 * Vim command character.  This avoids having to switch the keyboard back to
 * ASCII mode when leaving Insert mode.
 *
 * langmap_mapchar[] maps any of 256 chars to an ASCII char used for Vim
 * commands.
 * When FEAT_MBYTE is defined langmap_mapga.ga_data is a sorted table of
 * langmap_entry_T.  This does the same as langmap_mapchar[] for characters >=
 * 256.
 */
/*
 * With multi-byte support use growarray for 'langmap' chars >= 256
 */
typedef struct {
  int from;
  int to;
} langmap_entry_T;

static garray_T langmap_mapga;
static void langmap_set_entry(int from, int to);

/*
 * Search for an entry in "langmap_mapga" for "from".  If found set the "to"
 * field.  If not found insert a new entry at the appropriate location.
 */
static void langmap_set_entry(int from, int to)
{
  langmap_entry_T *entries = (langmap_entry_T *)(langmap_mapga.ga_data);
  int a = 0;
  int b = langmap_mapga.ga_len;

  /* Do a binary search for an existing entry. */
  while (a != b) {
    int i = (a + b) / 2;
    int d = entries[i].from - from;

    if (d == 0) {
      entries[i].to = to;
      return;
    }
    if (d < 0)
      a = i + 1;
    else
      b = i;
  }

  if (ga_grow(&langmap_mapga, 1) != OK)
    return;      /* out of memory */

  /* insert new entry at position "a" */
  entries = (langmap_entry_T *)(langmap_mapga.ga_data) + a;
  mch_memmove(entries + 1, entries,
      (langmap_mapga.ga_len - a) * sizeof(langmap_entry_T));
  ++langmap_mapga.ga_len;
  entries[0].from = from;
  entries[0].to = to;
}

/*
 * Apply 'langmap' to multi-byte character "c" and return the result.
 */
int langmap_adjust_mb(int c)
{
  langmap_entry_T *entries = (langmap_entry_T *)(langmap_mapga.ga_data);
  int a = 0;
  int b = langmap_mapga.ga_len;

  while (a != b) {
    int i = (a + b) / 2;
    int d = entries[i].from - c;

    if (d == 0)
      return entries[i].to;        /* found matching entry */
    if (d < 0)
      a = i + 1;
    else
      b = i;
  }
  return c;    /* no entry found, return "c" unmodified */
}

static void langmap_init(void)                 {
  int i;

  for (i = 0; i < 256; i++)
    langmap_mapchar[i] = i;      /* we init with a one-to-one map */
  ga_init2(&langmap_mapga, sizeof(langmap_entry_T), 8);
}

/*
 * Called when langmap option is set; the language map can be
 * changed at any time!
 */
static void langmap_set(void)                 {
  char_u  *p;
  char_u  *p2;
  int from, to;

  ga_clear(&langmap_mapga);                 /* clear the previous map first */
  langmap_init();                           /* back to one-to-one map */

  for (p = p_langmap; p[0] != NUL; ) {
    for (p2 = p; p2[0] != NUL && p2[0] != ',' && p2[0] != ';';
         mb_ptr_adv(p2)) {
      if (p2[0] == '\\' && p2[1] != NUL)
        ++p2;
    }
    if (p2[0] == ';')
      ++p2;                 /* abcd;ABCD form, p2 points to A */
    else
      p2 = NULL;            /* aAbBcCdD form, p2 is NULL */
    while (p[0]) {
      if (p[0] == ',') {
        ++p;
        break;
      }
      if (p[0] == '\\' && p[1] != NUL)
        ++p;
      from = (*mb_ptr2char)(p);
      to = NUL;
      if (p2 == NULL) {
        mb_ptr_adv(p);
        if (p[0] != ',') {
          if (p[0] == '\\')
            ++p;
          to = (*mb_ptr2char)(p);
        }
      } else   {
        if (p2[0] != ',') {
          if (p2[0] == '\\')
            ++p2;
          to = (*mb_ptr2char)(p2);
        }
      }
      if (to == NUL) {
        EMSG2(_("E357: 'langmap': Matching character missing for %s"),
            transchar(from));
        return;
      }

      if (from >= 256)
        langmap_set_entry(from, to);
      else
        langmap_mapchar[from & 255] = to;

      /* Advance to next pair */
      mb_ptr_adv(p);
      if (p2 != NULL) {
        mb_ptr_adv(p2);
        if (*p == ';') {
          p = p2;
          if (p[0] != NUL) {
            if (p[0] != ',') {
              EMSG2(_(
                      "E358: 'langmap': Extra characters after semicolon: %s"),
                  p);
              return;
            }
            ++p;
          }
          break;
        }
      }
    }
  }
}

/*
 * Return TRUE if format option 'x' is in effect.
 * Take care of no formatting when 'paste' is set.
 */
int has_format_option(int x)
{
  if (p_paste)
    return FALSE;
  return vim_strchr(curbuf->b_p_fo, x) != NULL;
}

/*
 * Return TRUE if "x" is present in 'shortmess' option, or
 * 'shortmess' contains 'a' and "x" is present in SHM_A.
 */
int shortmess(int x)
{
  return p_shm != NULL &&
         (   vim_strchr(p_shm, x) != NULL
             || (vim_strchr(p_shm, 'a') != NULL
                 && vim_strchr((char_u *)SHM_A, x) != NULL));
}

/*
 * paste_option_changed() - Called after p_paste was set or reset.
 */
static void paste_option_changed(void)                 {
  static int old_p_paste = FALSE;
  static int save_sm = 0;
  static int save_ru = 0;
  static int save_ri = 0;
  static int save_hkmap = 0;
  buf_T       *buf;

  if (p_paste) {
    /*
     * Paste switched from off to on.
     * Save the current values, so they can be restored later.
     */
    if (!old_p_paste) {
      /* save options for each buffer */
      for (buf = firstbuf; buf != NULL; buf = buf->b_next) {
        buf->b_p_tw_nopaste = buf->b_p_tw;
        buf->b_p_wm_nopaste = buf->b_p_wm;
        buf->b_p_sts_nopaste = buf->b_p_sts;
        buf->b_p_ai_nopaste = buf->b_p_ai;
      }

      /* save global options */
      save_sm = p_sm;
      save_ru = p_ru;
      save_ri = p_ri;
      save_hkmap = p_hkmap;
      /* save global values for local buffer options */
      p_tw_nopaste = p_tw;
      p_wm_nopaste = p_wm;
      p_sts_nopaste = p_sts;
      p_ai_nopaste = p_ai;
    }

    /*
     * Always set the option values, also when 'paste' is set when it is
     * already on.
     */
    /* set options for each buffer */
    for (buf = firstbuf; buf != NULL; buf = buf->b_next) {
      buf->b_p_tw = 0;              /* textwidth is 0 */
      buf->b_p_wm = 0;              /* wrapmargin is 0 */
      buf->b_p_sts = 0;             /* softtabstop is 0 */
      buf->b_p_ai = 0;              /* no auto-indent */
    }

    /* set global options */
    p_sm = 0;                       /* no showmatch */
    if (p_ru)
      status_redraw_all();          /* redraw to remove the ruler */
    p_ru = 0;                       /* no ruler */
    p_ri = 0;                       /* no reverse insert */
    p_hkmap = 0;                    /* no Hebrew keyboard */
    /* set global values for local buffer options */
    p_tw = 0;
    p_wm = 0;
    p_sts = 0;
    p_ai = 0;
  }
  /*
   * Paste switched from on to off: Restore saved values.
   */
  else if (old_p_paste) {
    /* restore options for each buffer */
    for (buf = firstbuf; buf != NULL; buf = buf->b_next) {
      buf->b_p_tw = buf->b_p_tw_nopaste;
      buf->b_p_wm = buf->b_p_wm_nopaste;
      buf->b_p_sts = buf->b_p_sts_nopaste;
      buf->b_p_ai = buf->b_p_ai_nopaste;
    }

    /* restore global options */
    p_sm = save_sm;
    if (p_ru != save_ru)
      status_redraw_all();          /* redraw to draw the ruler */
    p_ru = save_ru;
    p_ri = save_ri;
    p_hkmap = save_hkmap;
    /* set global values for local buffer options */
    p_tw = p_tw_nopaste;
    p_wm = p_wm_nopaste;
    p_sts = p_sts_nopaste;
    p_ai = p_ai_nopaste;
  }

  old_p_paste = p_paste;
}

/*
 * vimrc_found() - Called when a ".vimrc" or "VIMINIT" has been found.
 *
 * Reset 'compatible' and set the values for options that didn't get set yet
 * to the Vim defaults.
 * Don't do this if the 'compatible' option has been set or reset before.
 * When "fname" is not NULL, use it to set $"envname" when it wasn't set yet.
 */
void vimrc_found(char_u *fname, char_u *envname)
{
  int opt_idx;
  int dofree = FALSE;
  char_u      *p;

  if (!option_was_set((char_u *)"cp")) {
    p_cp = FALSE;
    for (opt_idx = 0; !istermoption(&options[opt_idx]); opt_idx++)
      if (!(options[opt_idx].flags & (P_WAS_SET|P_VI_DEF)))
        set_option_default(opt_idx, OPT_FREE, FALSE);
    didset_options();
  }

  if (fname != NULL) {
    p = vim_getenv(envname, &dofree);
    if (p == NULL) {
      /* Set $MYVIMRC to the first vimrc file found. */
      p = FullName_save(fname, FALSE);
      if (p != NULL) {
        vim_setenv(envname, p);
        vim_free(p);
      }
    } else if (dofree)
      vim_free(p);
  }
}

/*
 * Set 'compatible' on or off.  Called for "-C" and "-N" command line arg.
 */
void change_compatible(int on)
{
  int opt_idx;

  if (p_cp != on) {
    p_cp = on;
    compatible_set();
  }
  opt_idx = findoption((char_u *)"cp");
  if (opt_idx >= 0)
    options[opt_idx].flags |= P_WAS_SET;
}

/*
 * Return TRUE when option "name" has been set.
 * Only works correctly for global options.
 */
int option_was_set(char_u *name)
{
  int idx;

  idx = findoption(name);
  if (idx < 0)          /* unknown option */
    return FALSE;
  if (options[idx].flags & P_WAS_SET)
    return TRUE;
  return FALSE;
}

/*
 * Reset the flag indicating option "name" was set.
 */
void reset_option_was_set(char_u *name)
{
  int idx = findoption(name);

  if (idx >= 0)
    options[idx].flags &= ~P_WAS_SET;
}

/*
 * compatible_set() - Called when 'compatible' has been set or unset.
 *
 * When 'compatible' set: Set all relevant options (those that have the P_VIM)
 * flag) to a Vi compatible value.
 * When 'compatible' is unset: Set all options that have a different default
 * for Vim (without the P_VI_DEF flag) to that default.
 */
static void compatible_set(void)                 {
  int opt_idx;

  for (opt_idx = 0; !istermoption(&options[opt_idx]); opt_idx++)
    if (       ((options[opt_idx].flags & P_VIM) && p_cp)
               || (!(options[opt_idx].flags & P_VI_DEF) && !p_cp))
      set_option_default(opt_idx, OPT_FREE, p_cp);
  didset_options();
}

/*
 * fill_breakat_flags() -- called when 'breakat' changes value.
 */
static void fill_breakat_flags(void)                 {
  char_u      *p;
  int i;

  for (i = 0; i < 256; i++)
    breakat_flags[i] = FALSE;

  if (p_breakat != NULL)
    for (p = p_breakat; *p; p++)
      breakat_flags[*p] = TRUE;
}

/*
 * Check an option that can be a range of string values.
 *
 * Return OK for correct value, FAIL otherwise.
 * Empty is always OK.
 */
static int 
check_opt_strings (
    char_u *val,
    char **values,
    int list                   /* when TRUE: accept a list of values */
)
{
  return opt_strings_flags(val, values, NULL, list);
}

/*
 * Handle an option that can be a range of string values.
 * Set a flag in "*flagp" for each string present.
 *
 * Return OK for correct value, FAIL otherwise.
 * Empty is always OK.
 */
static int 
opt_strings_flags (
    char_u *val,               /* new value */
    char **values,           /* array of valid string values */
    unsigned *flagp,
    int list                       /* when TRUE: accept a list of values */
)
{
  int i;
  int len;
  unsigned new_flags = 0;

  while (*val) {
    for (i = 0;; ++i) {
      if (values[i] == NULL)            /* val not found in values[] */
        return FAIL;

      len = (int)STRLEN(values[i]);
      if (STRNCMP(values[i], val, len) == 0
          && ((list && val[len] == ',') || val[len] == NUL)) {
        val += len + (val[len] == ',');
        new_flags |= (1 << i);
        break;                  /* check next item in val list */
      }
    }
  }
  if (flagp != NULL)
    *flagp = new_flags;

  return OK;
}

/*
 * Read the 'wildmode' option, fill wim_flags[].
 */
static int check_opt_wim(void)                {
  char_u new_wim_flags[4];
  char_u      *p;
  int i;
  int idx = 0;

  for (i = 0; i < 4; ++i)
    new_wim_flags[i] = 0;

  for (p = p_wim; *p; ++p) {
    for (i = 0; ASCII_ISALPHA(p[i]); ++i)
      ;
    if (p[i] != NUL && p[i] != ',' && p[i] != ':')
      return FAIL;
    if (i == 7 && STRNCMP(p, "longest", 7) == 0)
      new_wim_flags[idx] |= WIM_LONGEST;
    else if (i == 4 && STRNCMP(p, "full", 4) == 0)
      new_wim_flags[idx] |= WIM_FULL;
    else if (i == 4 && STRNCMP(p, "list", 4) == 0)
      new_wim_flags[idx] |= WIM_LIST;
    else
      return FAIL;
    p += i;
    if (*p == NUL)
      break;
    if (*p == ',') {
      if (idx == 3)
        return FAIL;
      ++idx;
    }
  }

  /* fill remaining entries with last flag */
  while (idx < 3) {
    new_wim_flags[idx + 1] = new_wim_flags[idx];
    ++idx;
  }

  /* only when there are no errors, wim_flags[] is changed */
  for (i = 0; i < 4; ++i)
    wim_flags[i] = new_wim_flags[i];
  return OK;
}

/*
 * Check if backspacing over something is allowed.
 */
int 
can_bs (
    int what                   /* BS_INDENT, BS_EOL or BS_START */
)
{
  switch (*p_bs) {
  case '2':       return TRUE;
  case '1':       return what != BS_START;
  case '0':       return FALSE;
  }
  return vim_strchr(p_bs, what) != NULL;
}

/*
 * Save the current values of 'fileformat' and 'fileencoding', so that we know
 * the file must be considered changed when the value is different.
 */
void save_file_ff(buf_T *buf)
{
  buf->b_start_ffc = *buf->b_p_ff;
  buf->b_start_eol = buf->b_p_eol;
  buf->b_start_bomb = buf->b_p_bomb;

  /* Only use free/alloc when necessary, they take time. */
  if (buf->b_start_fenc == NULL
      || STRCMP(buf->b_start_fenc, buf->b_p_fenc) != 0) {
    vim_free(buf->b_start_fenc);
    buf->b_start_fenc = vim_strsave(buf->b_p_fenc);
  }
}

/*
 * Return TRUE if 'fileformat' and/or 'fileencoding' has a different value
 * from when editing started (save_file_ff() called).
 * Also when 'endofline' was changed and 'binary' is set, or when 'bomb' was
 * changed and 'binary' is not set.
 * When "ignore_empty" is true don't consider a new, empty buffer to be
 * changed.
 */
int file_ff_differs(buf_T *buf, int ignore_empty)
{
  /* In a buffer that was never loaded the options are not valid. */
  if (buf->b_flags & BF_NEVERLOADED)
    return FALSE;
  if (ignore_empty
      && (buf->b_flags & BF_NEW)
      && buf->b_ml.ml_line_count == 1
      && *ml_get_buf(buf, (linenr_T)1, FALSE) == NUL)
    return FALSE;
  if (buf->b_start_ffc != *buf->b_p_ff)
    return TRUE;
  if (buf->b_p_bin && buf->b_start_eol != buf->b_p_eol)
    return TRUE;
  if (!buf->b_p_bin && buf->b_start_bomb != buf->b_p_bomb)
    return TRUE;
  if (buf->b_start_fenc == NULL)
    return *buf->b_p_fenc != NUL;
  return STRCMP(buf->b_start_fenc, buf->b_p_fenc) != 0;
}

/*
 * return OK if "p" is a valid fileformat name, FAIL otherwise.
 */
int check_ff_value(char_u *p)
{
  return check_opt_strings(p, p_ff_values, FALSE);
}

/*
 * Return the effective shiftwidth value for current buffer, using the
 * 'tabstop' value when 'shiftwidth' is zero.
 */
long get_sw_value(buf_T *buf)
{
  return buf->b_p_sw ? buf->b_p_sw : buf->b_p_ts;
}

/*
 * Return the effective softtabstop value for the current buffer, using the
 * 'tabstop' value when 'softtabstop' is negative.
 */
long get_sts_value(void)          {
  return curbuf->b_p_sts < 0 ? get_sw_value(curbuf) : curbuf->b_p_sts;
}

/*
 * Check matchpairs option for "*initc".
 * If there is a match set "*initc" to the matching character and "*findc" to
 * the opposite character.  Set "*backwards" to the direction.
 * When "switchit" is TRUE swap the direction.
 */
void find_mps_values(int *initc, int *findc, int *backwards, int switchit)
{
  char_u      *ptr;

  ptr = curbuf->b_p_mps;
  while (*ptr != NUL) {
    if (has_mbyte) {
      char_u *prev;

      if (mb_ptr2char(ptr) == *initc) {
        if (switchit) {
          *findc = *initc;
          *initc = mb_ptr2char(ptr + mb_ptr2len(ptr) + 1);
          *backwards = TRUE;
        } else   {
          *findc = mb_ptr2char(ptr + mb_ptr2len(ptr) + 1);
          *backwards = FALSE;
        }
        return;
      }
      prev = ptr;
      ptr += mb_ptr2len(ptr) + 1;
      if (mb_ptr2char(ptr) == *initc) {
        if (switchit) {
          *findc = *initc;
          *initc = mb_ptr2char(prev);
          *backwards = FALSE;
        } else   {
          *findc = mb_ptr2char(prev);
          *backwards = TRUE;
        }
        return;
      }
      ptr += mb_ptr2len(ptr);
    } else   {
      if (*ptr == *initc) {
        if (switchit) {
          *backwards = TRUE;
          *findc = *initc;
          *initc = ptr[2];
        } else   {
          *backwards = FALSE;
          *findc = ptr[2];
        }
        return;
      }
      ptr += 2;
      if (*ptr == *initc) {
        if (switchit) {
          *backwards = FALSE;
          *findc = *initc;
          *initc = ptr[-2];
        } else   {
          *backwards = TRUE;
          *findc =  ptr[-2];
        }
        return;
      }
      ++ptr;
    }
    if (*ptr == ',')
      ++ptr;
  }
}
