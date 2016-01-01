#ifndef NVIM_OPTION_DEFS_H
#define NVIM_OPTION_DEFS_H

#include <stdbool.h>

#include "nvim/types.h"

// option_defs.h: definition of global variables for settable options

// Return value from get_option_value_strict */
#define SOPT_BOOL 0x01     // Boolean option
#define SOPT_NUM 0x02      // Number option
#define SOPT_STRING 0x04   // String option
#define SOPT_GLOBAL 0x08   // Option has global value
#define SOPT_WIN 0x10      // Option has window-local value
#define SOPT_BUF 0x20      // Option has buffer-local value
#define SOPT_UNSET 0x40    // Option does not have local value set

// Option types for various functions in option.c
#define SREQ_GLOBAL 0 // Request global option
#define SREQ_WIN 1    // Request window-local option
#define SREQ_BUF 2    // Request buffer-local option

/*
 * Default values for 'errorformat'.
 * The "%f|%l| %m" one is used for when the contents of the quickfix window is
 * written to a file.
 */
#define DFLT_EFM \
  "%*[^\"]\"%f\"%*\\D%l: %m,\"%f\"%*\\D%l: %m,%-G%f:%l: (Each undeclared identifier is reported only once,%-G%f:%l: for each function it appears in.),%-GIn file included from %f:%l:%c:,%-GIn file included from %f:%l:%c\\,,%-GIn file included from %f:%l:%c,%-GIn file included from %f:%l,%-G%*[ ]from %f:%l:%c,%-G%*[ ]from %f:%l:,%-G%*[ ]from %f:%l\\,,%-G%*[ ]from %f:%l,%f:%l:%c:%m,%f(%l):%m,%f:%l:%m,\"%f\"\\, line %l%*\\D%c%*[^ ] %m,%D%*\\a[%*\\d]: Entering directory %*[`']%f',%X%*\\a[%*\\d]: Leaving directory %*[`']%f',%D%*\\a: Entering directory %*[`']%f',%X%*\\a: Leaving directory %*[`']%f',%DMaking %*\\a in %f,%f|%l| %m"

#define DFLT_GREPFORMAT "%f:%l:%m,%f:%l%m,%f  %l%m"

/* default values for b_p_ff 'fileformat' and p_ffs 'fileformats' */
#define FF_DOS          "dos"
#define FF_MAC          "mac"
#define FF_UNIX         "unix"

#ifdef USE_CRNL
# define DFLT_FF        "dos"
# define DFLT_FFS_VIM   "dos,unix"
# define DFLT_FFS_VI    "dos,unix"      /* also autodetect in compatible mode */
#else
#  define DFLT_FF       "unix"
#  define DFLT_FFS_VIM  "unix,dos"
#   define DFLT_FFS_VI  ""
#endif


/* Possible values for 'encoding' */
# define ENC_UCSBOM     "ucs-bom"       /* check for BOM at start of file */

/* default value for 'encoding' */
# define ENC_DFLT       "utf-8"

/* end-of-line style */
#define EOL_UNKNOWN     -1      /* not defined yet */
#define EOL_UNIX        0       /* NL */
#define EOL_DOS         1       /* CR NL */
#define EOL_MAC         2       /* CR */

/* Formatting options for p_fo 'formatoptions' */
#define FO_WRAP         't'
#define FO_WRAP_COMS    'c'
#define FO_RET_COMS     'r'
#define FO_OPEN_COMS    'o'
#define FO_Q_COMS       'q'
#define FO_Q_NUMBER     'n'
#define FO_Q_SECOND     '2'
#define FO_INS_VI       'v'
#define FO_INS_LONG     'l'
#define FO_INS_BLANK    'b'
#define FO_MBYTE_BREAK  'm'     /* break before/after multi-byte char */
#define FO_MBYTE_JOIN   'M'     /* no space before/after multi-byte char */
#define FO_MBYTE_JOIN2  'B'     /* no space between multi-byte chars */
#define FO_ONE_LETTER   '1'
#define FO_WHITE_PAR    'w'     /* trailing white space continues paragr. */
#define FO_AUTO         'a'     /* automatic formatting */
#define FO_REMOVE_COMS  'j'     /* remove comment leaders when joining lines */

#define DFLT_FO_VI      "vt"
#define DFLT_FO_VIM     "tcqj"
#define FO_ALL          "tcroq2vlb1mMBn,awj"    /* for do_set() */

/* characters for the p_cpo option: */
#define CPO_ALTREAD     'a'     /* ":read" sets alternate file name */
#define CPO_ALTWRITE    'A'     /* ":write" sets alternate file name */
#define CPO_BAR         'b'     /* "\|" ends a mapping */
#define CPO_BSLASH      'B'     /* backslash in mapping is not special */
#define CPO_SEARCH      'c'
#define CPO_CONCAT      'C'     /* Don't concatenate sourced lines */
#define CPO_DOTTAG      'd'     /* "./tags" in 'tags' is in current dir */
#define CPO_DIGRAPH     'D'     /* No digraph after "r", "f", etc. */
#define CPO_EXECBUF     'e'
#define CPO_EMPTYREGION 'E'     /* operating on empty region is an error */
#define CPO_FNAMER      'f'     /* set file name for ":r file" */
#define CPO_FNAMEW      'F'     /* set file name for ":w file" */
#define CPO_INTMOD      'i'     /* interrupt a read makes buffer modified */
#define CPO_INDENT      'I'     /* remove auto-indent more often */
#define CPO_ENDOFSENT   'J'     /* need two spaces to detect end of sentence */
#define CPO_KEYCODE     'k'     /* don't recognize raw key code in mappings */
#define CPO_KOFFSET     'K'     /* don't wait for key code in mappings */
#define CPO_LITERAL     'l'     /* take char after backslash in [] literal */
#define CPO_LISTWM      'L'     /* 'list' changes wrapmargin */
#define CPO_SHOWMATCH   'm'
#define CPO_MATCHBSL    'M'     /* "%" ignores use of backslashes */
#define CPO_NUMCOL      'n'     /* 'number' column also used for text */
#define CPO_LINEOFF     'o'
#define CPO_OVERNEW     'O'     /* silently overwrite new file */
#define CPO_LISP        'p'     /* 'lisp' indenting */
#define CPO_FNAMEAPP    'P'     /* set file name for ":w >>file" */
#define CPO_JOINCOL     'q'     /* with "3J" use column after first join */
#define CPO_REDO        'r'
#define CPO_REMMARK     'R'     /* remove marks when filtering */
#define CPO_BUFOPT      's'
#define CPO_BUFOPTGLOB  'S'
#define CPO_TAGPAT      't'
#define CPO_UNDO        'u'     /* "u" undoes itself */
#define CPO_BACKSPACE   'v'     /* "v" keep deleted text */
#define CPO_FWRITE      'W'     /* "w!" doesn't overwrite readonly files */
#define CPO_ESC         'x'
#define CPO_REPLCNT     'X'     /* "R" with a count only deletes chars once */
#define CPO_YANK        'y'
#define CPO_KEEPRO      'Z'     /* don't reset 'readonly' on ":w!" */
#define CPO_DOLLAR      '$'
#define CPO_FILTER      '!'
#define CPO_MATCH       '%'
#define CPO_PLUS        '+'     /* ":write file" resets 'modified' */
#define CPO_SPECI       '<'     /* don't recognize <> in mappings */
#define CPO_REGAPPEND   '>'     /* insert NL when appending to a register */
#define CPO_SCOLON      ';'     /* using "," and ";" will skip over char if
                                 * cursor would not move */
/* default values for Vim and Vi */
#define CPO_VIM         "aABceFs"
#define CPO_VI          "aAbBcCdDeEfFiIJkKlLmMnoOpPqrRsStuvWxXyZ$!%+<>;"

/* characters for p_ww option: */
#define WW_ALL          "bshl<>[],~"

/* characters for p_mouse option: */
#define MOUSE_NORMAL    'n'             /* use mouse in Normal mode */
#define MOUSE_VISUAL    'v'             /* use mouse in Visual/Select mode */
#define MOUSE_INSERT    'i'             /* use mouse in Insert mode */
#define MOUSE_COMMAND   'c'             /* use mouse in Command-line mode */
#define MOUSE_HELP      'h'             /* use mouse in help buffers */
#define MOUSE_RETURN    'r'             /* use mouse for hit-return message */
#define MOUSE_A         "nvich"         /* used for 'a' flag */
#define MOUSE_ALL       "anvichr"       /* all possible characters */
#define MOUSE_NONE      ' '             /* don't use Visual selection */
#define MOUSE_NONEF     'x'             /* forced modeless selection */

#define COCU_ALL        "nvic"          /* flags for 'concealcursor' */

/* characters for p_shm option: */
#define SHM_RO          'r'             /* readonly */
#define SHM_MOD         'm'             /* modified */
#define SHM_FILE        'f'             /* (file 1 of 2) */
#define SHM_LAST        'i'             /* last line incomplete */
#define SHM_TEXT        'x'             /* tx instead of textmode */
#define SHM_LINES       'l'             /* "L" instead of "lines" */
#define SHM_NEW         'n'             /* "[New]" instead of "[New file]" */
#define SHM_WRI         'w'             /* "[w]" instead of "written" */
#define SHM_A           "rmfixlnw"      /* represented by 'a' flag */
#define SHM_WRITE       'W'             /* don't use "written" at all */
#define SHM_TRUNC       't'             /* trunctate file messages */
#define SHM_TRUNCALL    'T'             /* trunctate all messages */
#define SHM_OVER        'o'             /* overwrite file messages */
#define SHM_OVERALL     'O'             /* overwrite more messages */
#define SHM_SEARCH      's'             /* no search hit bottom messages */
#define SHM_ATTENTION   'A'             /* no ATTENTION messages */
#define SHM_INTRO       'I'             /* intro messages */
#define SHM_COMPLETIONMENU 'c'          // completion menu messages
#define SHM_ALL         "rmfixlnwaWtToOsAIc" /* all possible flags for 'shm' */

/* characters for p_go: */
#define GO_ASEL         'a'             /* autoselect */
#define GO_ASELML       'A'             /* autoselect modeless selection */
#define GO_BOT          'b'             /* use bottom scrollbar */
#define GO_CONDIALOG    'c'             /* use console dialog */
#define GO_TABLINE      'e'             /* may show tabline */
#define GO_FORG         'f'             /* start GUI in foreground */
#define GO_GREY         'g'             /* use grey menu items */
#define GO_HORSCROLL    'h'             /* flexible horizontal scrolling */
#define GO_ICON         'i'             /* use Vim icon */
#define GO_LEFT         'l'             /* use left scrollbar */
#define GO_VLEFT        'L'             /* left scrollbar with vert split */
#define GO_MENUS        'm'             /* use menu bar */
#define GO_NOSYSMENU    'M'             /* don't source system menu */
#define GO_POINTER      'p'             /* pointer enter/leave callbacks */
#define GO_ASELPLUS     'P'             /* autoselectPlus */
#define GO_RIGHT        'r'             /* use right scrollbar */
#define GO_VRIGHT       'R'             /* right scrollbar with vert split */
#define GO_TOOLBAR      'T'             /* add toolbar */
#define GO_FOOTER       'F'             /* add footer */
#define GO_VERTICAL     'v'             /* arrange dialog buttons vertically */
#define GO_ALL          "aAbcefFghilmMprTv" /* all possible flags for 'go' */

/* flags for 'comments' option */
#define COM_NEST        'n'             /* comments strings nest */
#define COM_BLANK       'b'             /* needs blank after string */
#define COM_START       's'             /* start of comment */
#define COM_MIDDLE      'm'             /* middle of comment */
#define COM_END         'e'             /* end of comment */
#define COM_AUTO_END    'x'             /* last char of end closes comment */
#define COM_FIRST       'f'             /* first line comment only */
#define COM_LEFT        'l'             /* left adjusted */
#define COM_RIGHT       'r'             /* right adjusted */
#define COM_NOBACK      'O'             /* don't use for "O" command */
#define COM_ALL         "nbsmexflrO"    /* all flags for 'comments' option */
#define COM_MAX_LEN     50              /* maximum length of a part */

/* flags for 'statusline' option */
#define STL_FILEPATH    'f'             /* path of file in buffer */
#define STL_FULLPATH    'F'             /* full path of file in buffer */
#define STL_FILENAME    't'             /* last part (tail) of file path */
#define STL_COLUMN      'c'             /* column og cursor*/
#define STL_VIRTCOL     'v'             /* virtual column */
#define STL_VIRTCOL_ALT 'V'             /* - with 'if different' display */
#define STL_LINE        'l'             /* line number of cursor */
#define STL_NUMLINES    'L'             /* number of lines in buffer */
#define STL_BUFNO       'n'             /* current buffer number */
#define STL_KEYMAP      'k'             /* 'keymap' when active */
#define STL_OFFSET      'o'             /* offset of character under cursor*/
#define STL_OFFSET_X    'O'             /* - in hexadecimal */
#define STL_BYTEVAL     'b'             /* byte value of character */
#define STL_BYTEVAL_X   'B'             /* - in hexadecimal */
#define STL_ROFLAG      'r'             /* readonly flag */
#define STL_ROFLAG_ALT  'R'             /* - other display */
#define STL_HELPFLAG    'h'             /* window is showing a help file */
#define STL_HELPFLAG_ALT 'H'            /* - other display */
#define STL_FILETYPE    'y'             /* 'filetype' */
#define STL_FILETYPE_ALT 'Y'            /* - other display */
#define STL_PREVIEWFLAG 'w'             /* window is showing the preview buf */
#define STL_PREVIEWFLAG_ALT 'W'         /* - other display */
#define STL_MODIFIED    'm'             /* modified flag */
#define STL_MODIFIED_ALT 'M'            /* - other display */
#define STL_QUICKFIX    'q'             /* quickfix window description */
#define STL_PERCENTAGE  'p'             /* percentage through file */
#define STL_ALTPERCENT  'P'             /* percentage as TOP BOT ALL or NN% */
#define STL_ARGLISTSTAT 'a'             /* argument list status as (x of y) */
#define STL_PAGENUM     'N'             /* page number (when printing)*/
#define STL_VIM_EXPR    '{'             /* start of expression to substitute */
#define STL_MIDDLEMARK  '='             /* separation between left and right */
#define STL_TRUNCMARK   '<'             /* truncation mark if line is too long*/
#define STL_USER_HL     '*'             /* highlight from (User)1..9 or 0 */
#define STL_HIGHLIGHT   '#'             /* highlight name */
#define STL_TABPAGENR   'T'             /* tab page label nr */
#define STL_TABCLOSENR  'X'             /* tab page close nr */
#define STL_ALL         ((char_u *) "fFtcvVlLknoObBrRhHmYyWwMqpPaN{#")

/* flags used for parsed 'wildmode' */
#define WIM_FULL        1
#define WIM_LONGEST     2
#define WIM_LIST        4

/* arguments for can_bs() */
#define BS_INDENT       'i'     /* "Indent" */
#define BS_EOL          'o'     /* "eOl" */
#define BS_START        's'     /* "Start" */

#define LISPWORD_VALUE \
  "defun,define,defmacro,set!,lambda,if,case,let,flet,let*,letrec,do,do*,define-syntax,let-syntax,letrec-syntax,destructuring-bind,defpackage,defparameter,defstruct,deftype,defvar,do-all-symbols,do-external-symbols,do-symbols,dolist,dotimes,ecase,etypecase,eval-when,labels,macrolet,multiple-value-bind,multiple-value-call,multiple-value-prog1,multiple-value-setq,prog1,progv,typecase,unless,unwind-protect,when,with-input-from-string,with-open-file,with-open-stream,with-output-to-string,with-package-iterator,define-condition,handler-bind,handler-case,restart-bind,restart-case,with-simple-restart,store-value,use-value,muffle-warning,abort,continue,with-slots,with-slots*,with-accessors,with-accessors*,defclass,defmethod,print-unreadable-object"

/*
 * The following are actual variables for the options
 */

EXTERN long p_aleph;            /* 'aleph' */
EXTERN bool p_acd;              /* 'autochdir' */
EXTERN char_u   *p_ambw;        /* 'ambiwidth' */
EXTERN bool p_ar;                /* 'autoread' */
EXTERN bool p_aw;                /* 'autowrite' */
EXTERN bool p_awa;               /* 'autowriteall' */
EXTERN char_u   *p_bs;          /* 'backspace' */
EXTERN char_u   *p_bg;          /* 'background' */
EXTERN bool p_bk;                /* 'backup' */
EXTERN char_u   *p_bkc;         /* 'backupcopy' */
EXTERN unsigned int bkc_flags;  ///< flags from 'backupcopy'
#ifdef IN_OPTION_C
static char *(p_bkc_values[]) =
{"yes", "auto", "no", "breaksymlink", "breakhardlink", NULL};
#endif
# define BKC_YES                0x001
# define BKC_AUTO               0x002
# define BKC_NO                 0x004
# define BKC_BREAKSYMLINK       0x008
# define BKC_BREAKHARDLINK      0x010
EXTERN char_u   *p_bdir;        /* 'backupdir' */
EXTERN char_u   *p_bex;         /* 'backupext' */
EXTERN char_u   *p_bo;          // 'belloff'
EXTERN unsigned bo_flags;
# ifdef IN_OPTION_C
static char *(p_bo_values[]) = {"all", "backspace", "cursor", "complete",
  "copy", "ctrlg", "error", "esc", "ex",
  "hangul", "insertmode", "lang", "mess",
  "showmatch", "operator", "register", "shell",
  "spell", "wildmode", NULL};
# endif

// values for the 'belloff' option
#define BO_ALL    0x0001
#define BO_BS     0x0002
#define BO_CRSR   0x0004
#define BO_COMPL  0x0008
#define BO_COPY   0x0010
#define BO_CTRLG  0x0020
#define BO_ERROR  0x0040
#define BO_ESC    0x0080
#define BO_EX     0x0100
#define BO_HANGUL 0x0200
#define BO_IM     0x0400
#define BO_LANG   0x0800
#define BO_MESS   0x1000
#define BO_MATCH  0x2000
#define BO_OPER   0x4000
#define BO_REG    0x8000
#define BO_SH     0x10000
#define BO_SPELL  0x20000
#define BO_WILD   0x40000

EXTERN char_u   *p_bsk;         /* 'backupskip' */
EXTERN char_u   *p_breakat;     /* 'breakat' */
EXTERN char_u   *p_cmp;         /* 'casemap' */
EXTERN unsigned cmp_flags;
# ifdef IN_OPTION_C
static char *(p_cmp_values[]) = {"internal", "keepascii", NULL};
# endif
# define CMP_INTERNAL           0x001
# define CMP_KEEPASCII          0x002
EXTERN char_u   *p_enc;         /* 'encoding' */
EXTERN bool p_deco;              /* 'delcombine' */
EXTERN char_u   *p_ccv;         /* 'charconvert' */
EXTERN char_u   *p_cedit;       /* 'cedit' */
EXTERN char_u   *p_cb;          /* 'clipboard' */
EXTERN unsigned cb_flags;
#ifdef IN_OPTION_C
static char *(p_cb_values[]) = {"unnamed", "unnamedplus", NULL};
#endif
# define CB_UNNAMED             0x001
# define CB_UNNAMEDPLUS         0x002
# define CB_UNNAMEDMASK         (CB_UNNAMED | CB_UNNAMEDPLUS)
EXTERN long p_cwh;              /* 'cmdwinheight' */
EXTERN long p_ch;               /* 'cmdheight' */
EXTERN bool p_confirm;           /* 'confirm' */
EXTERN bool p_cp;                /* 'compatible' */
EXTERN char_u   *p_cot;         /* 'completeopt' */
EXTERN long p_ph;               /* 'pumheight' */
EXTERN char_u   *p_cpo;         /* 'cpoptions' */
EXTERN char_u   *p_csprg;       /* 'cscopeprg' */
EXTERN bool p_csre;              /* 'cscoperelative' */
EXTERN char_u   *p_csqf;        /* 'cscopequickfix' */
#  define       CSQF_CMDS   "sgdctefi"
#  define       CSQF_FLAGS  "+-0"
EXTERN bool p_cst;               /* 'cscopetag' */
EXTERN long p_csto;             /* 'cscopetagorder' */
EXTERN long p_cspc;             /* 'cscopepathcomp' */
EXTERN bool p_csverbose;         /* 'cscopeverbose' */
EXTERN char_u   *p_debug;       /* 'debug' */
EXTERN char_u   *p_def;         /* 'define' */
EXTERN char_u   *p_inc;
EXTERN char_u   *p_dip;         /* 'diffopt' */
EXTERN char_u   *p_dex;         /* 'diffexpr' */
EXTERN char_u   *p_dict;        /* 'dictionary' */
EXTERN bool p_dg;                /* 'digraph' */
EXTERN char_u   *p_dir;         /* 'directory' */
EXTERN char_u   *p_dy;          /* 'display' */
EXTERN unsigned dy_flags;
#ifdef IN_OPTION_C
static char *(p_dy_values[]) = {"lastline", "uhex", NULL};
#endif
#define DY_LASTLINE             0x001
#define DY_UHEX                 0x002
EXTERN bool p_ed;                /* 'edcompatible' */
EXTERN char_u   *p_ead;         /* 'eadirection' */
EXTERN bool p_ea;               /* 'equalalways' */
EXTERN char_u   *p_ep;          /* 'equalprg' */
EXTERN bool p_eb;                /* 'errorbells' */
EXTERN char_u   *p_ef;          /* 'errorfile' */
EXTERN char_u   *p_efm;         /* 'errorformat' */
EXTERN char_u   *p_gefm;        /* 'grepformat' */
EXTERN char_u   *p_gp;          /* 'grepprg' */
EXTERN char_u   *p_ei;          /* 'eventignore' */
EXTERN bool p_ek;                /* 'esckeys' */
EXTERN bool p_exrc;              /* 'exrc' */
EXTERN char_u   *p_fencs;       /* 'fileencodings' */
EXTERN char_u   *p_ffs;         /* 'fileformats' */
EXTERN bool p_fic;              ///< 'fileignorecase'
EXTERN char_u   *p_fcl;         /* 'foldclose' */
EXTERN long p_fdls;             /* 'foldlevelstart' */
EXTERN char_u   *p_fdo;         /* 'foldopen' */
EXTERN unsigned fdo_flags;
# ifdef IN_OPTION_C
static char *(p_fdo_values[]) = {"all", "block", "hor", "mark", "percent",
                                 "quickfix", "search", "tag", "insert",
                                 "undo", "jump", NULL};
# endif
# define FDO_ALL                0x001
# define FDO_BLOCK              0x002
# define FDO_HOR                0x004
# define FDO_MARK               0x008
# define FDO_PERCENT            0x010
# define FDO_QUICKFIX           0x020
# define FDO_SEARCH             0x040
# define FDO_TAG                0x080
# define FDO_INSERT             0x100
# define FDO_UNDO               0x200
# define FDO_JUMP               0x400
EXTERN char_u   *p_fp;          /* 'formatprg' */
#ifdef HAVE_FSYNC
EXTERN bool p_fs;                /* 'fsync' */
#endif
EXTERN bool p_gd;                /* 'gdefault' */
EXTERN char_u   *p_pdev;        /* 'printdevice' */
EXTERN char_u   *p_penc;        /* 'printencoding' */
EXTERN char_u   *p_pexpr;       /* 'printexpr' */
EXTERN char_u   *p_pmfn;        /* 'printmbfont' */
EXTERN char_u   *p_pmcs;        /* 'printmbcharset' */
EXTERN char_u   *p_pfn;         /* 'printfont' */
EXTERN char_u   *p_popt;        /* 'printoptions' */
EXTERN char_u   *p_header;      /* 'printheader' */
EXTERN bool p_prompt;            /* 'prompt' */
EXTERN char_u   *p_guicursor;   /* 'guicursor' */
EXTERN char_u   *p_hf;          /* 'helpfile' */
EXTERN long p_hh;               /* 'helpheight' */
EXTERN char_u   *p_hlg;         /* 'helplang' */
EXTERN bool p_hid;               /* 'hidden' */
/* Use P_HID to check if a buffer is to be hidden when it is no longer
 * visible in a window. */
# define P_HID(buf) (buf_hide(buf))
EXTERN char_u   *p_hl;          /* 'highlight' */
EXTERN bool p_hls;               /* 'hlsearch' */
EXTERN long p_hi;               /* 'history' */
EXTERN bool p_hkmap;             /* 'hkmap' */
EXTERN bool p_hkmapp;            /* 'hkmapp' */
EXTERN bool p_fkmap;             /* 'fkmap' */
EXTERN bool p_altkeymap;         /* 'altkeymap' */
EXTERN bool p_arshape;           /* 'arabicshape' */
EXTERN bool p_icon;              /* 'icon' */
EXTERN char_u   *p_iconstring;  /* 'iconstring' */
EXTERN bool p_ic;                /* 'ignorecase' */
EXTERN bool p_is;                /* 'incsearch' */
EXTERN bool p_im;                /* 'insertmode' */
EXTERN char_u   *p_isf;         /* 'isfname' */
EXTERN char_u   *p_isi;         /* 'isident' */
EXTERN char_u   *p_isp;         /* 'isprint' */
EXTERN bool p_js;                /* 'joinspaces' */
EXTERN char_u   *p_kp;          /* 'keywordprg' */
EXTERN char_u   *p_km;          /* 'keymodel' */
EXTERN char_u   *p_langmap;     /* 'langmap'*/
EXTERN bool p_lnr;               /* 'langnoremap'*/
EXTERN char_u   *p_lm;          /* 'langmenu' */
EXTERN char_u   *p_lispwords;   /* 'lispwords' */
EXTERN long p_ls;               /* 'laststatus' */
EXTERN long p_stal;             /* 'showtabline' */
EXTERN char_u   *p_lcs;         /* 'listchars' */

EXTERN bool p_lz;                /* 'lazyredraw' */
EXTERN bool p_lpl;               /* 'loadplugins' */
EXTERN bool p_magic;             /* 'magic' */
EXTERN char_u   *p_mef;         /* 'makeef' */
EXTERN char_u   *p_mp;          /* 'makeprg' */
EXTERN char_u   *p_cc;          /* 'colorcolumn' */
EXTERN bool p_cc_cols[256];      /* array for 'colorcolumn' columns */
EXTERN long p_mat;              /* 'matchtime' */
EXTERN long p_mco;              /* 'maxcombine' */
EXTERN long p_mfd;              /* 'maxfuncdepth' */
EXTERN long p_mmd;              /* 'maxmapdepth' */
EXTERN long p_mm;               /* 'maxmem' */
EXTERN long p_mmp;              /* 'maxmempattern' */
EXTERN long p_mmt;              /* 'maxmemtot' */
EXTERN long p_mis;              /* 'menuitems' */
EXTERN char_u   *p_msm;         /* 'mkspellmem' */
EXTERN long p_mls;              /* 'modelines' */
EXTERN char_u   *p_mouse;       /* 'mouse' */
EXTERN char_u   *p_mousem;      /* 'mousemodel' */
EXTERN long p_mouset;           /* 'mousetime' */
EXTERN bool p_more;              /* 'more' */
EXTERN char_u   *p_opfunc;      /* 'operatorfunc' */
EXTERN char_u   *p_para;        /* 'paragraphs' */
EXTERN bool p_paste;             /* 'paste' */
EXTERN char_u   *p_pt;          /* 'pastetoggle' */
EXTERN char_u   *p_pex;         /* 'patchexpr' */
EXTERN char_u   *p_pm;          /* 'patchmode' */
EXTERN char_u   *p_path;        /* 'path' */
EXTERN char_u   *p_cdpath;      /* 'cdpath' */
EXTERN long p_rdt;              /* 'redrawtime' */
EXTERN bool p_remap;             /* 'remap' */
EXTERN long p_re;               /* 'regexpengine' */
EXTERN long p_report;           /* 'report' */
EXTERN long p_pvh;              /* 'previewheight' */
EXTERN bool p_ari;               /* 'allowrevins' */
EXTERN bool p_ri;                /* 'revins' */
EXTERN bool p_ru;                /* 'ruler' */
EXTERN char_u   *p_ruf;         /* 'rulerformat' */
EXTERN char_u   *p_rtp;         /* 'runtimepath' */
EXTERN long p_sj;               /* 'scrolljump' */
EXTERN long p_so;               /* 'scrolloff' */
EXTERN char_u   *p_sbo;         /* 'scrollopt' */
EXTERN char_u   *p_sections;    /* 'sections' */
EXTERN bool p_secure;            /* 'secure' */
EXTERN char_u   *p_sel;         /* 'selection' */
EXTERN char_u   *p_slm;         /* 'selectmode' */
EXTERN char_u   *p_ssop;        /* 'sessionoptions' */
EXTERN unsigned ssop_flags;
# ifdef IN_OPTION_C
/* Also used for 'viewoptions'! */
static char *(p_ssop_values[]) = {"buffers", "winpos", "resize", "winsize",
                                  "localoptions", "options", "help", "blank",
                                  "globals", "slash", "unix",
                                  "sesdir", "curdir", "folds", "cursor",
                                  "tabpages", NULL};
# endif
# define SSOP_BUFFERS           0x001
# define SSOP_WINPOS            0x002
# define SSOP_RESIZE            0x004
# define SSOP_WINSIZE           0x008
# define SSOP_LOCALOPTIONS      0x010
# define SSOP_OPTIONS           0x020
# define SSOP_HELP              0x040
# define SSOP_BLANK             0x080
# define SSOP_GLOBALS           0x100
# define SSOP_SLASH             0x200
# define SSOP_UNIX              0x400
# define SSOP_SESDIR            0x800
# define SSOP_CURDIR            0x1000
# define SSOP_FOLDS             0x2000
# define SSOP_CURSOR            0x4000
# define SSOP_TABPAGES          0x8000
EXTERN char_u   *p_sh;          /* 'shell' */
EXTERN char_u   *p_shcf;        /* 'shellcmdflag' */
EXTERN char_u   *p_sp;          /* 'shellpipe' */
EXTERN char_u   *p_shq;         /* 'shellquote' */
EXTERN char_u   *p_sxq;         /* 'shellxquote' */
EXTERN char_u   *p_sxe;         /* 'shellxescape' */
EXTERN char_u   *p_srr;         /* 'shellredir' */
EXTERN bool p_stmp;              /* 'shelltemp' */
#ifdef BACKSLASH_IN_FILENAME
EXTERN bool p_ssl;               /* 'shellslash' */
#endif
EXTERN char_u   *p_stl;         /* 'statusline' */
EXTERN bool p_sr;                /* 'shiftround' */
EXTERN char_u   *p_shm;         /* 'shortmess' */
EXTERN char_u   *p_sbr;         /* 'showbreak' */
EXTERN bool p_sc;                /* 'showcmd' */
EXTERN bool p_sft;               /* 'showfulltag' */
EXTERN bool p_sm;                /* 'showmatch' */
EXTERN bool p_smd;               /* 'showmode' */
EXTERN long p_ss;               /* 'sidescroll' */
EXTERN long p_siso;             /* 'sidescrolloff' */
EXTERN bool p_scs;               /* 'smartcase' */
EXTERN bool p_sta;               /* 'smarttab' */
EXTERN bool p_sb;                /* 'splitbelow' */
EXTERN long p_tpm;              /* 'tabpagemax' */
EXTERN char_u   *p_tal;         /* 'tabline' */
EXTERN char_u   *p_sps;         /* 'spellsuggest' */
EXTERN bool p_spr;               /* 'splitright' */
EXTERN bool p_sol;               /* 'startofline' */
EXTERN char_u   *p_su;          /* 'suffixes' */
EXTERN char_u   *p_sws;         /* 'swapsync' */
EXTERN char_u   *p_swb;         /* 'switchbuf' */
EXTERN unsigned swb_flags;
#ifdef IN_OPTION_C
static char *(p_swb_values[]) = {"useopen", "usetab", "split", "newtab", NULL};
#endif
#define SWB_USEOPEN             0x001
#define SWB_USETAB              0x002
#define SWB_SPLIT               0x004
#define SWB_NEWTAB              0x008
EXTERN bool p_tbs;               /* 'tagbsearch' */
EXTERN long p_tl;               /* 'taglength' */
EXTERN bool p_tr;                /* 'tagrelative' */
EXTERN char_u   *p_tags;        /* 'tags' */
EXTERN bool p_tgst;              /* 'tagstack' */
EXTERN bool p_tbidi;             /* 'termbidi' */
EXTERN bool p_terse;             /* 'terse' */
EXTERN bool p_to;                /* 'tildeop' */
EXTERN bool p_timeout;           /* 'timeout' */
EXTERN long p_tm;               /* 'timeoutlen' */
EXTERN bool p_title;             /* 'title' */
EXTERN long p_titlelen;         /* 'titlelen' */
EXTERN char_u   *p_titleold;    /* 'titleold' */
EXTERN char_u   *p_titlestring; /* 'titlestring' */
EXTERN char_u   *p_tsr;         /* 'thesaurus' */
EXTERN bool p_ttimeout;          /* 'ttimeout' */
EXTERN long p_ttm;              /* 'ttimeoutlen' */
EXTERN char_u   *p_udir;        /* 'undodir' */
EXTERN long p_ul;               /* 'undolevels' */
EXTERN long p_ur;               /* 'undoreload' */
EXTERN long p_uc;               /* 'updatecount' */
EXTERN long p_ut;               /* 'updatetime' */
EXTERN char_u   *p_fcs;         /* 'fillchar' */
EXTERN char_u   *p_shada;       /* 'shada' */
EXTERN char_u   *p_vdir;        /* 'viewdir' */
EXTERN char_u   *p_vop;         /* 'viewoptions' */
EXTERN unsigned vop_flags;      /* uses SSOP_ flags */
EXTERN bool p_vb;                /* 'visualbell' */
EXTERN char_u   *p_ve;          /* 'virtualedit' */
EXTERN unsigned ve_flags;
# ifdef IN_OPTION_C
static char *(p_ve_values[]) = {"block", "insert", "all", "onemore", NULL};
# endif
# define VE_BLOCK       5       /* includes "all" */
# define VE_INSERT      6       /* includes "all" */
# define VE_ALL         4
# define VE_ONEMORE     8
EXTERN long p_verbose;          /* 'verbose' */
#ifdef IN_OPTION_C
char_u  *p_vfile = (char_u *)""; /* used before options are initialized */
#else
extern char_u   *p_vfile;       /* 'verbosefile' */
#endif
EXTERN bool p_warn;              /* 'warn' */
EXTERN char_u   *p_wop;         /* 'wildoptions' */
EXTERN long p_window;           /* 'window' */
EXTERN char_u   *p_wak;         /* 'winaltkeys' */
EXTERN char_u   *p_wig;         /* 'wildignore' */
EXTERN char_u   *p_ww;          /* 'whichwrap' */
EXTERN long p_wc;               /* 'wildchar' */
EXTERN long p_wcm;              /* 'wildcharm' */
EXTERN bool p_wic;              ///< 'wildignorecase'
EXTERN char_u   *p_wim;         /* 'wildmode' */
EXTERN bool p_wmnu;              /* 'wildmenu' */
EXTERN long p_wh;               /* 'winheight' */
EXTERN long p_wmh;              /* 'winminheight' */
EXTERN long p_wmw;              /* 'winminwidth' */
EXTERN long p_wiw;              /* 'winwidth' */
EXTERN bool p_ws;               /* 'wrapscan' */
EXTERN bool p_write;             /* 'write' */
EXTERN bool p_wa;                /* 'writeany' */
EXTERN bool p_wb;                /* 'writebackup' */
EXTERN long p_wd;               /* 'writedelay' */

EXTERN bool p_force_on;          ///< options that cannot be turned off.
EXTERN bool p_force_off;         ///< options that cannot be turned on.

/*
 * "indir" values for buffer-local opions.
 * These need to be defined globally, so that the BV_COUNT can be used with
 * b_p_scriptID[].
 */
enum {
  BV_AI = 0
  , BV_AR
  , BV_BH
  , BV_BKC
  , BV_BT
  , BV_EFM
  , BV_GP
  , BV_MP
  , BV_BIN
  , BV_BL
  , BV_BOMB
  , BV_CI
  , BV_CIN
  , BV_CINK
  , BV_CINO
  , BV_CINW
  , BV_CM
  , BV_CMS
  , BV_COM
  , BV_CPT
  , BV_DICT
  , BV_TSR
  , BV_CFU
  , BV_DEF
  , BV_INC
  , BV_EOL
  , BV_FIXEOL
  , BV_EP
  , BV_ET
  , BV_FENC
  , BV_BEXPR
  , BV_FEX
  , BV_FF
  , BV_FLP
  , BV_FO
  , BV_FT
  , BV_IMI
  , BV_IMS
  , BV_INDE
  , BV_INDK
  , BV_INEX
  , BV_INF
  , BV_ISK
  , BV_KMAP
  , BV_KP
  , BV_LISP
  , BV_LW
  , BV_MA
  , BV_ML
  , BV_MOD
  , BV_MPS
  , BV_NF
  , BV_OFU
  , BV_PATH
  , BV_PI
  , BV_QE
  , BV_RO
  , BV_SI
  , BV_SMC
  , BV_SYN
  , BV_SPC
  , BV_SPF
  , BV_SPL
  , BV_STS
  , BV_SUA
  , BV_SW
  , BV_SWF
  , BV_TAGS
  , BV_TS
  , BV_TW
  , BV_TX
  , BV_UDF
  , BV_UL
  , BV_WM
  , BV_COUNT        /* must be the last one */
};

/*
 * "indir" values for window-local options.
 * These need to be defined globally, so that the WV_COUNT can be used in the
 * window structure.
 */
enum {
  WV_LIST = 0
  , WV_ARAB
  , WV_COCU
  , WV_COLE
  , WV_CRBIND
  , WV_BRI
  , WV_BRIOPT
  , WV_DIFF
  , WV_FDC
  , WV_FEN
  , WV_FDI
  , WV_FDL
  , WV_FDM
  , WV_FML
  , WV_FDN
  , WV_FDE
  , WV_FDT
  , WV_FMR
  , WV_LBR
  , WV_NU
  , WV_RNU
  , WV_NUW
  , WV_PVW
  , WV_RL
  , WV_RLC
  , WV_SCBIND
  , WV_SCROLL
  , WV_SPELL
  , WV_CUC
  , WV_CUL
  , WV_CC
  , WV_STL
  , WV_WFH
  , WV_WFW
  , WV_WRAP
  , WV_COUNT        /* must be the last one */
};

/* Value for b_p_ul indicating the global value must be used. */
#define NO_LOCAL_UNDOLEVEL -123456

#endif // NVIM_OPTION_DEFS_H
