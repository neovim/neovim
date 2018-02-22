#ifndef NVIM_OPTION_DEFS_H
#define NVIM_OPTION_DEFS_H

#include "nvim/types.h"
#include "nvim/macros.h"  // For EXTERN

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
#define SREQ_GLOBAL 0  // Request global option value
#define SREQ_WIN 1     // Request window-local option value
#define SREQ_BUF 2     // Request buffer-local option value

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

// characters for the p_cpo option:
#define CPO_ALTREAD     'a'     // ":read" sets alternate file name
#define CPO_ALTWRITE    'A'     // ":write" sets alternate file name
#define CPO_BAR         'b'     // "\|" ends a mapping
#define CPO_BSLASH      'B'     // backslash in mapping is not special
#define CPO_SEARCH      'c'
#define CPO_CONCAT      'C'     // Don't concatenate sourced lines
#define CPO_DOTTAG      'd'     // "./tags" in 'tags' is in current dir
#define CPO_DIGRAPH     'D'     // No digraph after "r", "f", etc.
#define CPO_EXECBUF     'e'
#define CPO_EMPTYREGION 'E'     // operating on empty region is an error
#define CPO_FNAMER      'f'     // set file name for ":r file"
#define CPO_FNAMEW      'F'     // set file name for ":w file"
#define CPO_INTMOD      'i'     // interrupt a read makes buffer modified
#define CPO_INDENT      'I'     // remove auto-indent more often
#define CPO_ENDOFSENT   'J'     // need two spaces to detect end of sentence
#define CPO_KOFFSET     'K'     // don't wait for key code in mappings
#define CPO_LITERAL     'l'     // take char after backslash in [] literal
#define CPO_LISTWM      'L'     // 'list' changes wrapmargin
#define CPO_SHOWMATCH   'm'
#define CPO_MATCHBSL    'M'     // "%" ignores use of backslashes
#define CPO_NUMCOL      'n'     // 'number' column also used for text
#define CPO_LINEOFF     'o'
#define CPO_OVERNEW     'O'     // silently overwrite new file
#define CPO_LISP        'p'     // 'lisp' indenting
#define CPO_FNAMEAPP    'P'     // set file name for ":w >>file"
#define CPO_JOINCOL     'q'     // with "3J" use column after first join
#define CPO_REDO        'r'
#define CPO_REMMARK     'R'     // remove marks when filtering
#define CPO_BUFOPT      's'
#define CPO_BUFOPTGLOB  'S'
#define CPO_TAGPAT      't'
#define CPO_UNDO        'u'     // "u" undoes itself
#define CPO_BACKSPACE   'v'     // "v" keep deleted text
#define CPO_FWRITE      'W'     // "w!" doesn't overwrite readonly files
#define CPO_ESC         'x'
#define CPO_REPLCNT     'X'     // "R" with a count only deletes chars once
#define CPO_YANK        'y'
#define CPO_KEEPRO      'Z'     // don't reset 'readonly' on ":w!"
#define CPO_DOLLAR      '$'
#define CPO_FILTER      '!'
#define CPO_MATCH       '%'
#define CPO_PLUS        '+'     // ":write file" resets 'modified'
#define CPO_REGAPPEND   '>'     // insert NL when appending to a register
#define CPO_SCOLON      ';'     // using "," and ";" will skip over char if
                                // cursor would not move
#define CPO_CHANGEW     '_'     // "cw" special-case
// default values for Vim and Vi
#define CPO_VIM         "aABceFs_"
#define CPO_VI          "aAbBcCdDeEfFiIJKlLmMnoOpPqrRsStuvWxXyZ$!%+>;_"

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

/// characters for p_shm option:
enum {
  SHM_RO             = 'r',  ///< Readonly.
  SHM_MOD            = 'm',  ///< Modified.
  SHM_FILE           = 'f',  ///< (file 1 of 2)
  SHM_LAST           = 'i',  ///< Last line incomplete.
  SHM_TEXT           = 'x',  ///< Tx instead of textmode.
  SHM_LINES          = 'l',  ///< "L" instead of "lines".
  SHM_NEW            = 'n',  ///< "[New]" instead of "[New file]".
  SHM_WRI            = 'w',  ///< "[w]" instead of "written".
  SHM_ABBREVIATIONS  = 'a',  ///< Use abbreviations from #SHM_ALL_ABBREVIATIONS.
  SHM_WRITE          = 'W',  ///< Don't use "written" at all.
  SHM_TRUNC          = 't',  ///< Trunctate file messages.
  SHM_TRUNCALL       = 'T',  ///< Trunctate all messages.
  SHM_OVER           = 'o',  ///< Overwrite file messages.
  SHM_OVERALL        = 'O',  ///< Overwrite more messages.
  SHM_SEARCH         = 's',  ///< No search hit bottom messages.
  SHM_ATTENTION      = 'A',  ///< No ATTENTION messages.
  SHM_INTRO          = 'I',  ///< Intro messages.
  SHM_COMPLETIONMENU = 'c',  ///< Completion menu messages.
  SHM_RECORDING      = 'q',  ///< Short recording message.
  SHM_FILEINFO       = 'F',  ///< No file info messages.
};
/// Represented by 'a' flag.
#define SHM_ALL_ABBREVIATIONS ((char_u[]) { \
  SHM_RO, SHM_MOD, SHM_FILE, SHM_LAST, SHM_TEXT, SHM_LINES, SHM_NEW, SHM_WRI, \
  0, \
})
/// All possible flags for 'shm'.
#define SHM_ALL ((char_u[]) { \
  SHM_RO, SHM_MOD, SHM_FILE, SHM_LAST, SHM_TEXT, SHM_LINES, SHM_NEW, SHM_WRI, \
  SHM_ABBREVIATIONS, SHM_WRITE, SHM_TRUNC, SHM_TRUNCALL, SHM_OVER, \
  SHM_OVERALL, SHM_SEARCH, SHM_ATTENTION, SHM_INTRO, SHM_COMPLETIONMENU, \
  SHM_RECORDING, SHM_FILEINFO, \
  0, \
})

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

/// 'statusline' option flags
enum {
  STL_FILEPATH        = 'f',  ///< Path of file in buffer.
  STL_FULLPATH        = 'F',  ///< Full path of file in buffer.
  STL_FILENAME        = 't',  ///< Last part (tail) of file path.
  STL_COLUMN          = 'c',  ///< Column og cursor.
  STL_VIRTCOL         = 'v',  ///< Virtual column.
  STL_VIRTCOL_ALT     = 'V',  ///< - with 'if different' display.
  STL_LINE            = 'l',  ///< Line number of cursor.
  STL_NUMLINES        = 'L',  ///< Number of lines in buffer.
  STL_BUFNO           = 'n',  ///< Current buffer number.
  STL_KEYMAP          = 'k',  ///< 'keymap' when active.
  STL_OFFSET          = 'o',  ///< Offset of character under cursor.
  STL_OFFSET_X        = 'O',  ///< - in hexadecimal.
  STL_BYTEVAL         = 'b',  ///< Byte value of character.
  STL_BYTEVAL_X       = 'B',  ///< - in hexadecimal.
  STL_ROFLAG          = 'r',  ///< Readonly flag.
  STL_ROFLAG_ALT      = 'R',  ///< - other display.
  STL_HELPFLAG        = 'h',  ///< Window is showing a help file.
  STL_HELPFLAG_ALT    = 'H',  ///< - other display.
  STL_FILETYPE        = 'y',  ///< 'filetype'.
  STL_FILETYPE_ALT    = 'Y',  ///< - other display.
  STL_PREVIEWFLAG     = 'w',  ///< Window is showing the preview buf.
  STL_PREVIEWFLAG_ALT = 'W',  ///< - other display.
  STL_MODIFIED        = 'm',  ///< Modified flag.
  STL_MODIFIED_ALT    = 'M',  ///< - other display.
  STL_QUICKFIX        = 'q',  ///< Quickfix window description.
  STL_PERCENTAGE      = 'p',  ///< Percentage through file.
  STL_ALTPERCENT      = 'P',  ///< Percentage as TOP BOT ALL or NN%.
  STL_ARGLISTSTAT     = 'a',  ///< Argument list status as (x of y).
  STL_PAGENUM         = 'N',  ///< Page number (when printing).
  STL_VIM_EXPR        = '{',  ///< Start of expression to substitute.
  STL_SEPARATE        = '=',  ///< Separation between alignment sections.
  STL_TRUNCMARK       = '<',  ///< Truncation mark if line is too long.
  STL_USER_HL         = '*',  ///< Highlight from (User)1..9 or 0.
  STL_HIGHLIGHT       = '#',  ///< Highlight name.
  STL_TABPAGENR       = 'T',  ///< Tab page label nr.
  STL_TABCLOSENR      = 'X',  ///< Tab page close nr.
  STL_CLICK_FUNC      = '@',  ///< Click region start.
};
/// C string containing all 'statusline' option flags
#define STL_ALL ((char_u[]) { \
  STL_FILEPATH, STL_FULLPATH, STL_FILENAME, STL_COLUMN, STL_VIRTCOL, \
  STL_VIRTCOL_ALT, STL_LINE, STL_NUMLINES, STL_BUFNO, STL_KEYMAP, STL_OFFSET, \
  STL_OFFSET_X, STL_BYTEVAL, STL_BYTEVAL_X, STL_ROFLAG, STL_ROFLAG_ALT, \
  STL_HELPFLAG, STL_HELPFLAG_ALT, STL_FILETYPE, STL_FILETYPE_ALT, \
  STL_PREVIEWFLAG, STL_PREVIEWFLAG_ALT, STL_MODIFIED, STL_MODIFIED_ALT, \
  STL_QUICKFIX, STL_PERCENTAGE, STL_ALTPERCENT, STL_ARGLISTSTAT, STL_PAGENUM, \
  STL_VIM_EXPR, STL_SEPARATE, STL_TRUNCMARK, STL_USER_HL, STL_HIGHLIGHT, \
  STL_TABPAGENR, STL_TABCLOSENR, STL_CLICK_FUNC, \
  0, \
})

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

EXTERN long p_aleph;            // 'aleph'
EXTERN int p_acd;               // 'autochdir'
EXTERN char_u   *p_ambw;        // 'ambiwidth'
EXTERN int p_ar;                // 'autoread'
EXTERN int p_aw;                // 'autowrite'
EXTERN int p_awa;               // 'autowriteall'
EXTERN char_u   *p_bs;          // 'backspace'
EXTERN char_u   *p_bg;          // 'background'
EXTERN int p_bk;                // 'backup'
EXTERN char_u   *p_bkc;         // 'backupcopy'
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
EXTERN int p_deco;              /* 'delcombine' */
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
EXTERN long p_cwh;              // 'cmdwinheight'
EXTERN long p_ch;               // 'cmdheight'
EXTERN int p_confirm;           // 'confirm'
EXTERN int p_cp;                // 'compatible'
EXTERN char_u   *p_cot;         // 'completeopt'
EXTERN long p_ph;               // 'pumheight'
EXTERN char_u   *p_cpo;         // 'cpoptions'
EXTERN char_u   *p_csprg;       // 'cscopeprg'
EXTERN int p_csre;              // 'cscoperelative'
EXTERN char_u   *p_csqf;        // 'cscopequickfix'
#  define       CSQF_CMDS   "sgdctefia"
#  define       CSQF_FLAGS  "+-0"
EXTERN int p_cst;               /* 'cscopetag' */
EXTERN long p_csto;             /* 'cscopetagorder' */
EXTERN long p_cspc;             /* 'cscopepathcomp' */
EXTERN int p_csverbose;         /* 'cscopeverbose' */
EXTERN char_u   *p_debug;       /* 'debug' */
EXTERN char_u   *p_def;         /* 'define' */
EXTERN char_u   *p_inc;
EXTERN char_u   *p_dip;         /* 'diffopt' */
EXTERN char_u   *p_dex;         /* 'diffexpr' */
EXTERN char_u   *p_dict;        /* 'dictionary' */
EXTERN int p_dg;                /* 'digraph' */
EXTERN char_u   *p_dir;         /* 'directory' */
EXTERN char_u   *p_dy;          /* 'display' */
EXTERN unsigned dy_flags;
#ifdef IN_OPTION_C
static char *(p_dy_values[]) = { "lastline", "truncate", "uhex", "msgsep",
                                  NULL };
#endif
#define DY_LASTLINE             0x001
#define DY_TRUNCATE             0x002
#define DY_UHEX                 0x004
#define DY_MSGSEP               0x008
EXTERN int p_ed;                // 'edcompatible'
EXTERN int p_emoji;             // 'emoji'
EXTERN char_u   *p_ead;         // 'eadirection'
EXTERN int p_ea;                // 'equalalways'
EXTERN char_u   *p_ep;          // 'equalprg'
EXTERN int p_eb;                // 'errorbells'
EXTERN char_u   *p_ef;          // 'errorfile'
EXTERN char_u   *p_efm;         // 'errorformat'
EXTERN char_u   *p_gefm;        // 'grepformat'
EXTERN char_u   *p_gp;          // 'grepprg'
EXTERN char_u   *p_ei;          // 'eventignore'
EXTERN int p_exrc;              // 'exrc'
EXTERN char_u   *p_fencs;       // 'fileencodings'
EXTERN char_u   *p_ffs;         // 'fileformats'
EXTERN int p_fic;               // 'fileignorecase'
EXTERN char_u   *p_fcl;         // 'foldclose'
EXTERN long p_fdls;             // 'foldlevelstart'
EXTERN char_u   *p_fdo;         // 'foldopen'
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
EXTERN char_u   *p_fp;          // 'formatprg'
EXTERN int p_fs;                // 'fsync'
EXTERN int p_gd;                // 'gdefault'
EXTERN char_u   *p_pdev;        // 'printdevice'
EXTERN char_u   *p_penc;        // 'printencoding'
EXTERN char_u   *p_pexpr;       // 'printexpr'
EXTERN char_u   *p_pmfn;        // 'printmbfont'
EXTERN char_u   *p_pmcs;        // 'printmbcharset'
EXTERN char_u   *p_pfn;         // 'printfont'
EXTERN char_u   *p_popt;        // 'printoptions'
EXTERN char_u   *p_header;      // 'printheader'
EXTERN int p_prompt;            // 'prompt'
EXTERN char_u   *p_guicursor;   // 'guicursor'
EXTERN char_u   *p_guifont;     // 'guifont'
EXTERN char_u   *p_guifontset;  // 'guifontset'
EXTERN char_u   *p_guifontwide;  // 'guifontwide'
EXTERN char_u   *p_hf;          // 'helpfile'
EXTERN long p_hh;               // 'helpheight'
EXTERN char_u   *p_hlg;         // 'helplang'
EXTERN int p_hid;               // 'hidden'
EXTERN char_u   *p_hl;          // 'highlight'
EXTERN int p_hls;               // 'hlsearch'
EXTERN long p_hi;               // 'history'
EXTERN int p_hkmap;             // 'hkmap'
EXTERN int p_hkmapp;            // 'hkmapp'
EXTERN int p_fkmap;             // 'fkmap'
EXTERN int p_altkeymap;         // 'altkeymap'
EXTERN int p_arshape;           // 'arabicshape'
EXTERN int p_icon;              // 'icon'
EXTERN char_u   *p_iconstring;  // 'iconstring'
EXTERN int p_ic;                // 'ignorecase'
EXTERN int p_is;                // 'incsearch'
EXTERN char_u   *p_icm;         // 'inccommand'
EXTERN int p_im;                // 'insertmode'
EXTERN char_u   *p_isf;         // 'isfname'
EXTERN char_u   *p_isi;         // 'isident'
EXTERN char_u   *p_isp;         // 'isprint'
EXTERN int p_js;                // 'joinspaces'
EXTERN char_u   *p_kp;          // 'keywordprg'
EXTERN char_u   *p_km;          // 'keymodel'
EXTERN char_u   *p_langmap;     // 'langmap'
EXTERN int p_lnr;               // 'langnoremap'
EXTERN int p_lrm;               // 'langremap'
EXTERN char_u   *p_lm;          // 'langmenu'
EXTERN long     *p_linespace;   // 'linespace'
EXTERN char_u   *p_lispwords;   // 'lispwords'
EXTERN long p_ls;               // 'laststatus'
EXTERN long p_stal;             // 'showtabline'
EXTERN char_u   *p_lcs;         // 'listchars'

EXTERN int p_lz;                // 'lazyredraw'
EXTERN int p_lpl;               // 'loadplugins'
EXTERN int p_magic;             // 'magic'
EXTERN char_u   *p_menc;        // 'makeencoding'
EXTERN char_u   *p_mef;         // 'makeef'
EXTERN char_u   *p_mp;          // 'makeprg'
EXTERN char_u   *p_cc;          // 'colorcolumn'
EXTERN int p_cc_cols[256];      // array for 'colorcolumn' columns
EXTERN long p_mat;              // 'matchtime'
EXTERN long p_mco;              // 'maxcombine'
EXTERN long p_mfd;              // 'maxfuncdepth'
EXTERN long p_mmd;              // 'maxmapdepth'
EXTERN long p_mm;               // 'maxmem'
EXTERN long p_mmp;              // 'maxmempattern'
EXTERN long p_mmt;              // 'maxmemtot'
EXTERN long p_mis;              // 'menuitems'
EXTERN char_u   *p_msm;         // 'mkspellmem'
EXTERN long p_mls;              // 'modelines'
EXTERN char_u   *p_mouse;       // 'mouse'
EXTERN char_u   *p_mousem;      // 'mousemodel'
EXTERN long p_mouset;           // 'mousetime'
EXTERN int p_more;              // 'more'
EXTERN char_u   *p_opfunc;      // 'operatorfunc'
EXTERN char_u   *p_para;        // 'paragraphs'
EXTERN int p_paste;             // 'paste'
EXTERN char_u   *p_pt;          // 'pastetoggle'
EXTERN char_u   *p_pex;         // 'patchexpr'
EXTERN char_u   *p_pm;          // 'patchmode'
EXTERN char_u   *p_path;        // 'path'
EXTERN char_u   *p_cdpath;      // 'cdpath'
EXTERN long p_rdt;              // 'redrawtime'
EXTERN int p_remap;             // 'remap'
EXTERN long p_re;               // 'regexpengine'
EXTERN long p_report;           // 'report'
EXTERN long p_pvh;              // 'previewheight'
EXTERN int p_ari;               // 'allowrevins'
EXTERN int p_ri;                // 'revins'
EXTERN int p_ru;                // 'ruler'
EXTERN char_u   *p_ruf;         // 'rulerformat'
EXTERN char_u   *p_pp;          // 'packpath'
EXTERN char_u   *p_rtp;         // 'runtimepath'
EXTERN long p_scbk;             // 'scrollback'
EXTERN long p_sj;               // 'scrolljump'
EXTERN long p_so;               // 'scrolloff'
EXTERN char_u   *p_sbo;         // 'scrollopt'
EXTERN char_u   *p_sections;    // 'sections'
EXTERN int p_secure;            // 'secure'
EXTERN char_u   *p_sel;         // 'selection'
EXTERN char_u   *p_slm;         // 'selectmode'
EXTERN char_u   *p_ssop;        // 'sessionoptions'
EXTERN unsigned ssop_flags;
# ifdef IN_OPTION_C
/* Also used for 'viewoptions'! */
static char *(p_ssop_values[]) = {"buffers", "winpos", "resize", "winsize",
                                  "localoptions", "options", "help", "blank",
                                  "globals", "slash", "unix",
                                  "sesdir", "curdir", "folds", "cursor",
                                  "tabpages", NULL };
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

EXTERN char_u   *p_sh;          // 'shell'
EXTERN char_u   *p_shcf;        // 'shellcmdflag'
EXTERN char_u   *p_sp;          // 'shellpipe'
EXTERN char_u   *p_shq;         // 'shellquote'
EXTERN char_u   *p_sxq;         // 'shellxquote'
EXTERN char_u   *p_sxe;         // 'shellxescape'
EXTERN char_u   *p_srr;         // 'shellredir'
EXTERN int p_stmp;              // 'shelltemp'
#ifdef BACKSLASH_IN_FILENAME
EXTERN int p_ssl;               // 'shellslash'
#endif
EXTERN char_u   *p_stl;         // 'statusline'
EXTERN int p_sr;                // 'shiftround'
EXTERN char_u   *p_shm;         // 'shortmess'
EXTERN char_u   *p_sbr;         // 'showbreak'
EXTERN int p_sc;                // 'showcmd'
EXTERN int p_sft;               // 'showfulltag'
EXTERN int p_sm;                // 'showmatch'
EXTERN int p_smd;               // 'showmode'
EXTERN long p_ss;               // 'sidescroll'
EXTERN long p_siso;             // 'sidescrolloff'
EXTERN int p_scs;               // 'smartcase'
EXTERN int p_sta;               // 'smarttab'
EXTERN int p_sb;                // 'splitbelow'
EXTERN long p_tpm;              // 'tabpagemax'
EXTERN char_u   *p_tal;         // 'tabline'
EXTERN char_u   *p_sps;         // 'spellsuggest'
EXTERN int p_spr;               // 'splitright'
EXTERN int p_sol;               // 'startofline'
EXTERN char_u   *p_su;          // 'suffixes'
EXTERN char_u   *p_swb;         // 'switchbuf'
EXTERN unsigned swb_flags;
#ifdef IN_OPTION_C
static char *(p_swb_values[]) =
  { "useopen", "usetab", "split", "newtab", "vsplit", NULL };
#endif
#define SWB_USEOPEN             0x001
#define SWB_USETAB              0x002
#define SWB_SPLIT               0x004
#define SWB_NEWTAB              0x008
#define SWB_VSPLIT              0x010
EXTERN int p_tbs;               ///< 'tagbsearch'
EXTERN char_u *p_tc;            ///< 'tagcase'
EXTERN unsigned tc_flags;       ///< flags from 'tagcase'
#ifdef IN_OPTION_C
static char *(p_tc_values[]) =
  { "followic", "ignore", "match", "followscs", "smart", NULL };
#endif
#define TC_FOLLOWIC             0x01
#define TC_IGNORE               0x02
#define TC_MATCH                0x04
#define TC_FOLLOWSCS            0x08
#define TC_SMART                0x10
EXTERN long p_tl;               ///< 'taglength'
EXTERN int p_tr;                ///< 'tagrelative'
EXTERN char_u *p_tags;          ///< 'tags'
EXTERN int p_tgst;              ///< 'tagstack'
EXTERN int p_tbidi;             ///< 'termbidi'
EXTERN int p_terse;             ///< 'terse'
EXTERN int p_to;                ///< 'tildeop'
EXTERN int p_timeout;           ///< 'timeout'
EXTERN long p_tm;               ///< 'timeoutlen'
EXTERN int p_title;             ///< 'title'
EXTERN long p_titlelen;         ///< 'titlelen'
EXTERN char_u *p_titleold;      ///< 'titleold'
EXTERN char_u *p_titlestring;   ///< 'titlestring'
EXTERN char_u *p_tsr;           ///< 'thesaurus'
EXTERN int p_tgc;               ///< 'termguicolors'
EXTERN int p_ttimeout;          ///< 'ttimeout'
EXTERN long p_ttm;              ///< 'ttimeoutlen'
EXTERN char_u *p_udir;          ///< 'undodir'
EXTERN long p_ul;               ///< 'undolevels'
EXTERN long p_ur;               ///< 'undoreload'
EXTERN long p_uc;               ///< 'updatecount'
EXTERN long p_ut;               ///< 'updatetime'
EXTERN char_u *p_fcs;           ///< 'fillchar'
EXTERN char_u *p_shada;         ///< 'shada'
EXTERN char_u *p_vdir;          ///< 'viewdir'
EXTERN char_u *p_vop;           ///< 'viewoptions'
EXTERN unsigned vop_flags;      ///< uses SSOP_ flags
EXTERN int p_vb;                ///< 'visualbell'
EXTERN char_u *p_ve;            ///< 'virtualedit'
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
EXTERN int p_warn;              // 'warn'
EXTERN char_u   *p_wop;         // 'wildoptions'
EXTERN long p_window;           // 'window'
EXTERN char_u   *p_wak;         // 'winaltkeys'
EXTERN char_u   *p_wig;         // 'wildignore'
EXTERN char_u   *p_ww;          // 'whichwrap'
EXTERN long p_wc;               // 'wildchar'
EXTERN long p_wcm;              // 'wildcharm'
EXTERN int p_wic;               // 'wildignorecase'
EXTERN char_u   *p_wim;         // 'wildmode'
EXTERN int p_wmnu;              // 'wildmenu'
EXTERN long p_wh;               // 'winheight'
EXTERN long p_wmh;              // 'winminheight'
EXTERN long p_wmw;              // 'winminwidth'
EXTERN long p_wiw;              // 'winwidth'
EXTERN int p_ws;                // 'wrapscan'
EXTERN int p_write;             // 'write'
EXTERN int p_wa;                // 'writeany'
EXTERN int p_wb;                // 'writebackup'
EXTERN long p_wd;               // 'writedelay'

EXTERN int p_force_on;          ///< options that cannot be turned off.
EXTERN int p_force_off;         ///< options that cannot be turned on.

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
  , BV_CHANNEL
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
  , BV_FP
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
  , BV_MENC
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
  , BV_SCBK
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
  , BV_TC
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
  , WV_SCL
  , WV_WINHL
  , WV_COUNT        // must be the last one
};

/* Value for b_p_ul indicating the global value must be used. */
#define NO_LOCAL_UNDOLEVEL -123456

#define SB_MAX 100000  // Maximum 'scrollback' value.

#endif // NVIM_OPTION_DEFS_H
