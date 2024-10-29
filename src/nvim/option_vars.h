#pragma once

#include "nvim/macros_defs.h"
#include "nvim/os/os_defs.h"
#include "nvim/sign_defs.h"
#include "nvim/types_defs.h"

// option_vars.h: definition of global variables for settable options

#define HIGHLIGHT_INIT \
  "8:SpecialKey,~:EndOfBuffer,z:TermCursor,Z:TermCursorNC,@:NonText,d:Directory,e:ErrorMsg," \
  "i:IncSearch,l:Search,y:CurSearch,m:MoreMsg,M:ModeMsg,n:LineNr,a:LineNrAbove,b:LineNrBelow," \
  "N:CursorLineNr,G:CursorLineSign,O:CursorLineFold,r:Question,s:StatusLine,S:StatusLineNC," \
  "c:VertSplit,t:Title,v:Visual,V:VisualNOS,w:WarningMsg,W:WildMenu,f:Folded,F:FoldColumn," \
  "A:DiffAdd,C:DiffChange,D:DiffDelete,T:DiffText,>:SignColumn,-:Conceal,B:SpellBad,P:SpellCap," \
  "R:SpellRare,L:SpellLocal,+:Pmenu,=:PmenuSel,k:PmenuMatch,<:PmenuMatchSel,[:PmenuKind," \
  "]:PmenuKindSel,{:PmenuExtra,}:PmenuExtraSel,x:PmenuSbar,X:PmenuThumb,*:TabLine,#:TabLineSel," \
  "_:TabLineFill,!:CursorColumn,.:CursorLine,o:ColorColumn,q:QuickFixLine,z:StatusLineTerm," \
  "Z:StatusLineTermNC,g:MsgArea,0:Whitespace,I:NormalNC"

// Default values for 'errorformat'.
// The "%f|%l| %m" one is used for when the contents of the quickfix window is
// written to a file.
#ifdef MSWIN
# define DFLT_EFM \
  "%f(%l): %t%*\\D%n: %m,%f(%l\\,%c): %t%*\\D%n: %m,%f(%l) \\=: %t%*\\D%n: %m,%*[^\"]\"%f\"%*\\D%l: %m,%f(%l) \\=: %m,%*[^ ] %f %l: %m,%f:%l:%c:%m,%f(%l):%m,%f:%l:%m,%f|%l| %m"
#else
# define DFLT_EFM \
  "%*[^\"]\"%f\"%*\\D%l: %m,\"%f\"%*\\D%l: %m,%-Gg%\\?make[%*\\d]: *** [%f:%l:%m,%-Gg%\\?make: *** [%f:%l:%m,%-G%f:%l: (Each undeclared identifier is reported only once,%-G%f:%l: for each function it appears in.),%-GIn file included from %f:%l:%c:,%-GIn file included from %f:%l:%c\\,,%-GIn file included from %f:%l:%c,%-GIn file included from %f:%l,%-G%*[ ]from %f:%l:%c,%-G%*[ ]from %f:%l:,%-G%*[ ]from %f:%l\\,,%-G%*[ ]from %f:%l,%f:%l:%c:%m,%f(%l):%m,%f:%l:%m,\"%f\"\\, line %l%*\\D%c%*[^ ] %m,%D%*\\a[%*\\d]: Entering directory %*[`']%f',%X%*\\a[%*\\d]: Leaving directory %*[`']%f',%D%*\\a: Entering directory %*[`']%f',%X%*\\a: Leaving directory %*[`']%f',%DMaking %*\\a in %f,%f|%l| %m"
#endif

#define DFLT_GREPFORMAT "%f:%l:%m,%f:%l%m,%f  %l%m"

// default values for b_p_ff 'fileformat' and p_ffs 'fileformats'
#define FF_DOS          "dos"
#define FF_MAC          "mac"
#define FF_UNIX         "unix"

#ifdef USE_CRNL
# define DFLT_FF        "dos"
# define DFLT_FFS_VIM   "dos,unix"
# define DFLT_FFS_VI    "dos,unix"      // also autodetect in compatible mode
#else
# define DFLT_FF       "unix"
# define DFLT_FFS_VIM  "unix,dos"
# define DFLT_FFS_VI  ""
#endif

// Possible values for 'encoding'
#define ENC_UCSBOM     "ucs-bom"       // check for BOM at start of file

// default value for 'encoding'
#define ENC_DFLT       "utf-8"

// end-of-line style
#define EOL_UNKNOWN     (-1)    // not defined yet
#define EOL_UNIX        0       // NL
#define EOL_DOS         1       // CR NL
#define EOL_MAC         2       // CR

// Formatting options for p_fo 'formatoptions'
#define FO_WRAP         't'
#define FO_WRAP_COMS    'c'
#define FO_RET_COMS     'r'
#define FO_OPEN_COMS    'o'
#define FO_NO_OPEN_COMS '/'
#define FO_Q_COMS       'q'
#define FO_Q_NUMBER     'n'
#define FO_Q_SECOND     '2'
#define FO_INS_VI       'v'
#define FO_INS_LONG     'l'
#define FO_INS_BLANK    'b'
#define FO_MBYTE_BREAK  'm'     // break before/after multi-byte char
#define FO_MBYTE_JOIN   'M'     // no space before/after multi-byte char
#define FO_MBYTE_JOIN2  'B'     // no space between multi-byte chars
#define FO_ONE_LETTER   '1'
#define FO_WHITE_PAR    'w'     // trailing white space continues paragr.
#define FO_AUTO         'a'     // automatic formatting
#define FO_RIGOROUS_TW  ']'     // respect textwidth rigorously
#define FO_REMOVE_COMS  'j'     // remove comment leaders when joining lines
#define FO_PERIOD_ABBR  'p'     // don't break a single space after a period

#define DFLT_FO_VI      "vt"
#define DFLT_FO_VIM     "tcqj"
#define FO_ALL          "tcro/q2vlb1mMBn,aw]jp"   // for do_set()

#define MAX_MCO  6  // fixed value for 'maxcombine'

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
#define CPO_FNAMEAPP    'P'     // set file name for ":w >>file"
#define CPO_JOINCOL     'q'     // with "3J" use column after first join
#define CPO_REDO        'r'
#define CPO_REMMARK     'R'     // remove marks when filtering
#define CPO_BUFOPT      's'
#define CPO_BUFOPTGLOB  'S'
#define CPO_TAGPAT      't'     // tag pattern is used for "n"
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

// characters for p_ww option:
#define WW_ALL          "bshl<>[]~"

// characters for p_mouse option:
#define MOUSE_NORMAL    'n'             // use mouse in Normal mode
#define MOUSE_VISUAL    'v'             // use mouse in Visual/Select mode
#define MOUSE_INSERT    'i'             // use mouse in Insert mode
#define MOUSE_COMMAND   'c'             // use mouse in Command-line mode
#define MOUSE_HELP      'h'             // use mouse in help buffers
#define MOUSE_RETURN    'r'             // use mouse for hit-return message
#define MOUSE_A         "nvich"         // used for 'a' flag
#define MOUSE_ALL       "anvichr"       // all possible characters
#define MOUSE_NONE      ' '             // don't use Visual selection
#define MOUSE_NONEF     'x'             // forced modeless selection

// default vertical and horizontal mouse scroll values.
// Note: This should be in sync with the default mousescroll option.
#define MOUSESCROLL_VERT_DFLT   3
#define MOUSESCROLL_HOR_DFLT    6

#define COCU_ALL        "nvic"          // flags for 'concealcursor'

/// characters for p_shm option:
enum {
  SHM_RO             = 'r',  ///< Readonly.
  SHM_MOD            = 'm',  ///< Modified.
  SHM_LINES          = 'l',  ///< "L" instead of "lines".
  SHM_WRI            = 'w',  ///< "[w]" instead of "written".
  SHM_ABBREVIATIONS  = 'a',  ///< Use abbreviations from #SHM_ALL_ABBREVIATIONS.
  SHM_WRITE          = 'W',  ///< Don't use "written" at all.
  SHM_TRUNC          = 't',  ///< Truncate file messages.
  SHM_TRUNCALL       = 'T',  ///< Truncate all messages.
  SHM_OVER           = 'o',  ///< Overwrite file messages.
  SHM_OVERALL        = 'O',  ///< Overwrite more messages.
  SHM_SEARCH         = 's',  ///< No search hit bottom messages.
  SHM_ATTENTION      = 'A',  ///< No ATTENTION messages.
  SHM_INTRO          = 'I',  ///< Intro messages.
  SHM_COMPLETIONMENU = 'c',  ///< Completion menu messages.
  SHM_COMPLETIONSCAN = 'C',  ///< Completion scanning messages.
  SHM_RECORDING      = 'q',  ///< No recording message.
  SHM_FILEINFO       = 'F',  ///< No file info messages.
  SHM_SEARCHCOUNT    = 'S',  ///< No search stats: '[1/10]'
};
/// Represented by 'a' flag.
#define SHM_ALL_ABBREVIATIONS ((char[]) { \
    SHM_RO, SHM_MOD, SHM_LINES, SHM_WRI, \
    0 })

// characters for p_go:
#define GO_ASEL         'a'             // autoselect
#define GO_ASELML       'A'             // autoselect modeless selection
#define GO_BOT          'b'             // use bottom scrollbar
#define GO_CONDIALOG    'c'             // use console dialog
#define GO_DARKTHEME    'd'             // use dark theme variant
#define GO_TABLINE      'e'             // may show tabline
#define GO_FORG         'f'             // start GUI in foreground
#define GO_GREY         'g'             // use grey menu items
#define GO_HORSCROLL    'h'             // flexible horizontal scrolling
#define GO_ICON         'i'             // use Vim icon
#define GO_LEFT         'l'             // use left scrollbar
#define GO_VLEFT        'L'             // left scrollbar with vert split
#define GO_MENUS        'm'             // use menu bar
#define GO_NOSYSMENU    'M'             // don't source system menu
#define GO_POINTER      'p'             // pointer enter/leave callbacks
#define GO_ASELPLUS     'P'             // autoselectPlus
#define GO_RIGHT        'r'             // use right scrollbar
#define GO_VRIGHT       'R'             // right scrollbar with vert split
#define GO_TOOLBAR      'T'             // add toolbar
#define GO_FOOTER       'F'             // add footer
#define GO_VERTICAL     'v'             // arrange dialog buttons vertically
#define GO_KEEPWINSIZE  'k'             // keep GUI window size
#define GO_ALL "!aAbcdefFghilLmMpPrRtTvk"  // all possible flags for 'go'

// flags for 'comments' option
#define COM_NEST        'n'             // comments strings nest
#define COM_BLANK       'b'             // needs blank after string
#define COM_START       's'             // start of comment
#define COM_MIDDLE      'm'             // middle of comment
#define COM_END         'e'             // end of comment
#define COM_AUTO_END    'x'             // last char of end closes comment
#define COM_FIRST       'f'             // first line comment only
#define COM_LEFT        'l'             // left adjusted
#define COM_RIGHT       'r'             // right adjusted
#define COM_NOBACK      'O'             // don't use for "O" command
#define COM_ALL         "nbsmexflrO"    // all flags for 'comments' option
#define COM_MAX_LEN     50              // maximum length of a part

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
  STL_SHOWCMD         = 'S',  ///< 'showcmd' buffer
  STL_FOLDCOL         = 'C',  ///< Fold column for 'statuscolumn'
  STL_SIGNCOL         = 's',  ///< Sign column for 'statuscolumn'
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
#define STL_ALL ((char[]) { \
    STL_FILEPATH, STL_FULLPATH, STL_FILENAME, STL_COLUMN, STL_VIRTCOL, \
    STL_VIRTCOL_ALT, STL_LINE, STL_NUMLINES, STL_BUFNO, STL_KEYMAP, STL_OFFSET, \
    STL_OFFSET_X, STL_BYTEVAL, STL_BYTEVAL_X, STL_ROFLAG, STL_ROFLAG_ALT, \
    STL_HELPFLAG, STL_HELPFLAG_ALT, STL_FILETYPE, STL_FILETYPE_ALT, \
    STL_PREVIEWFLAG, STL_PREVIEWFLAG_ALT, STL_MODIFIED, STL_MODIFIED_ALT, \
    STL_QUICKFIX, STL_PERCENTAGE, STL_ALTPERCENT, STL_ARGLISTSTAT, STL_PAGENUM, \
    STL_SHOWCMD, STL_FOLDCOL, STL_SIGNCOL, STL_VIM_EXPR, STL_SEPARATE, \
    STL_TRUNCMARK, STL_USER_HL, STL_HIGHLIGHT, STL_TABPAGENR, STL_TABCLOSENR, \
    STL_CLICK_FUNC, STL_TABPAGENR, STL_TABCLOSENR, STL_CLICK_FUNC, \
    0, })

// flags used for parsed 'wildmode'
#define WIM_FULL        0x01
#define WIM_LONGEST     0x02
#define WIM_LIST        0x04
#define WIM_BUFLASTUSED 0x08

// arguments for can_bs()
// each defined char should be unique over all values
// except for BS_START, that intentionally also matches BS_NOSTOP
// because BS_NOSTOP behaves exactly the same except it
// does not stop at the start of the insert point
#define BS_INDENT       'i'     // "Indent"
#define BS_EOL          'l'     // "eoL"
#define BS_START        's'     // "Start"
#define BS_NOSTOP       'p'     // "nostoP

// flags for the 'culopt' option
#define CULOPT_LINE     0x01    // Highlight complete line
#define CULOPT_SCRLINE  0x02    // Highlight screen line
#define CULOPT_NBR      0x04    // Highlight Number column

#define LISPWORD_VALUE \
  "defun,define,defmacro,set!,lambda,if,case,let,flet,let*,letrec,do,do*,define-syntax,let-syntax,letrec-syntax,destructuring-bind,defpackage,defparameter,defstruct,deftype,defvar,do-all-symbols,do-external-symbols,do-symbols,dolist,dotimes,ecase,etypecase,eval-when,labels,macrolet,multiple-value-bind,multiple-value-call,multiple-value-prog1,multiple-value-setq,prog1,progv,typecase,unless,unwind-protect,when,with-input-from-string,with-open-file,with-open-stream,with-output-to-string,with-package-iterator,define-condition,handler-bind,handler-case,restart-bind,restart-case,with-simple-restart,store-value,use-value,muffle-warning,abort,continue,with-slots,with-slots*,with-accessors,with-accessors*,defclass,defmethod,print-unreadable-object"

// When a string option is NULL, it is set to empty_string_option,
// to avoid having to check for NULL everywhere.
//
// TODO(famiu): Remove this when refcounted strings are used for string options.
EXTERN char empty_string_option[] INIT( = "");

// The following are actual variables for the options

EXTERN char *p_ambw;             ///< 'ambiwidth'
EXTERN int p_acd;                ///< 'autochdir'
EXTERN int p_ai;                 ///< 'autoindent'
EXTERN int p_bin;                ///< 'binary'
EXTERN int p_bomb;               ///< 'bomb'
EXTERN int p_bl;                 ///< 'buflisted'
EXTERN int p_cin;                ///< 'cindent'
EXTERN OptInt p_channel;         ///< 'channel'
EXTERN char *p_cink;             ///< 'cinkeys'
EXTERN char *p_cinsd;            ///< 'cinscopedecls'
EXTERN char *p_cinw;             ///< 'cinwords'
EXTERN char *p_cfu;              ///< 'completefunc'
EXTERN char *p_ofu;              ///< 'omnifunc'
EXTERN char *p_tsrfu;            ///< 'thesaurusfunc'
EXTERN int p_ci;                 ///< 'copyindent'
EXTERN int p_ar;                 ///< 'autoread'
EXTERN int p_aw;                 ///< 'autowrite'
EXTERN int p_awa;                ///< 'autowriteall'
EXTERN char *p_bs;               ///< 'backspace'
EXTERN char *p_bg;               ///< 'background'
EXTERN int p_bk;                 ///< 'backup'
EXTERN char *p_bkc;              ///< 'backupcopy'
EXTERN unsigned bkc_flags;       ///< flags from 'backupcopy'
#define BKC_YES                0x001
#define BKC_AUTO               0x002
#define BKC_NO                 0x004
#define BKC_BREAKSYMLINK       0x008
#define BKC_BREAKHARDLINK      0x010
EXTERN char *p_bdir;             ///< 'backupdir'
EXTERN char *p_bex;              ///< 'backupext'
EXTERN char *p_bo;               ///< 'belloff'
EXTERN char breakat_flags[256];  ///< which characters are in 'breakat'
EXTERN unsigned bo_flags;

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
#define BO_TERM   0x40000
#define BO_WILD   0x80000

EXTERN char *p_bsk;             ///< 'backupskip'
EXTERN char *p_breakat;         ///< 'breakat'
EXTERN char *p_bh;              ///< 'bufhidden'
EXTERN char *p_bt;              ///< 'buftype'
EXTERN char *p_cmp;             ///< 'casemap'
EXTERN unsigned cmp_flags;
#define CMP_INTERNAL            0x001
#define CMP_KEEPASCII           0x002
EXTERN char *p_enc;             ///< 'encoding'
EXTERN int p_deco;              ///< 'delcombine'
EXTERN char *p_ccv;             ///< 'charconvert'
EXTERN char *p_cino;            ///< 'cinoptions'
EXTERN char *p_cedit;           ///< 'cedit'
EXTERN char *p_cb;              ///< 'clipboard'
EXTERN unsigned cb_flags;
#define CB_UNNAMED              0x001
#define CB_UNNAMEDPLUS          0x002
#define CB_UNNAMEDMASK          (CB_UNNAMED | CB_UNNAMEDPLUS)
EXTERN OptInt p_cwh;            ///< 'cmdwinheight'
EXTERN OptInt p_ch;             ///< 'cmdheight'
EXTERN char *p_cms;             ///< 'commentstring'
EXTERN char *p_cpt;             ///< 'complete'
EXTERN OptInt p_columns;        ///< 'columns'
EXTERN int p_confirm;           ///< 'confirm'
EXTERN char *p_cia;             ///< 'completeitemalign'
EXTERN unsigned cia_flags;      ///<  order flags of 'completeitemalign'
EXTERN char *p_cot;             ///< 'completeopt'
EXTERN unsigned cot_flags;      ///< flags from 'completeopt'
// Keep in sync with p_cot_values in optionstr.c
#define COT_MENU        0x001
#define COT_MENUONE     0x002
#define COT_ANY_MENU    0x003  // combination of menu flags
#define COT_LONGEST     0x004  // false: insert full match,
                               // true: insert longest prefix
#define COT_PREVIEW     0x008
#define COT_POPUP       0x010
#define COT_ANY_PREVIEW 0x018  // combination of preview flags
#define COT_NOINSERT    0x020  // false: select & insert, true: noinsert
#define COT_NOSELECT    0x040  // false: select & insert, true: noselect
#define COT_FUZZY       0x080  // true: fuzzy match enabled
#ifdef BACKSLASH_IN_FILENAME
EXTERN char *p_csl;             ///< 'completeslash'
#endif
EXTERN OptInt p_pb;             ///< 'pumblend'
EXTERN OptInt p_ph;             ///< 'pumheight'
EXTERN OptInt p_pw;             ///< 'pumwidth'
EXTERN char *p_com;             ///< 'comments'
EXTERN char *p_cpo;             ///< 'cpoptions'
EXTERN char *p_debug;           ///< 'debug'
EXTERN char *p_def;             ///< 'define'
EXTERN char *p_inc;
EXTERN char *p_dip;             ///< 'diffopt'
EXTERN char *p_dex;             ///< 'diffexpr'
EXTERN char *p_dict;            ///< 'dictionary'
EXTERN int p_dg;                ///< 'digraph'
EXTERN char *p_dir;             ///< 'directory'
EXTERN char *p_dy;              ///< 'display'
EXTERN unsigned dy_flags;
#define DY_LASTLINE             0x001
#define DY_TRUNCATE             0x002
#define DY_UHEX                 0x004
// legacy flag, not used
#define DY_MSGSEP               0x008
EXTERN char *p_ead;             ///< 'eadirection'
EXTERN int p_emoji;             ///< 'emoji'
EXTERN int p_ea;                ///< 'equalalways'
EXTERN char *p_ep;              ///< 'equalprg'
EXTERN int p_eb;                ///< 'errorbells'
EXTERN char *p_ef;              ///< 'errorfile'
EXTERN char *p_efm;             ///< 'errorformat'
EXTERN char *p_gefm;            ///< 'grepformat'
EXTERN char *p_gp;              ///< 'grepprg'
EXTERN int p_eof;               ///< 'endoffile'
EXTERN int p_eol;               ///< 'endofline'
EXTERN char *p_ei;              ///< 'eventignore'
EXTERN int p_et;                ///< 'expandtab'
EXTERN int p_exrc;              ///< 'exrc'
EXTERN char *p_fenc;            ///< 'fileencoding'
EXTERN char *p_fencs;           ///< 'fileencodings'
EXTERN char *p_ff;              ///< 'fileformat'
EXTERN char *p_ffs;             ///< 'fileformats'
EXTERN int p_fic;               ///< 'fileignorecase'
EXTERN char *p_ft;              ///< 'filetype'
EXTERN char *p_fcs;             ///< 'fillchar'
EXTERN char *p_fexpr;           ///< 'findexpr'
EXTERN int p_fixeol;            ///< 'fixendofline'
EXTERN char *p_fcl;             ///< 'foldclose'
EXTERN OptInt p_fdls;           ///< 'foldlevelstart'
EXTERN char *p_fdo;             ///< 'foldopen'
EXTERN unsigned fdo_flags;
#define FDO_ALL                0x001
#define FDO_BLOCK              0x002
#define FDO_HOR                0x004
#define FDO_MARK               0x008
#define FDO_PERCENT            0x010
#define FDO_QUICKFIX           0x020
#define FDO_SEARCH             0x040
#define FDO_TAG                0x080
#define FDO_INSERT             0x100
#define FDO_UNDO               0x200
#define FDO_JUMP               0x400
EXTERN char *p_fex;             ///< 'formatexpr'
EXTERN char *p_flp;             ///< 'formatlistpat'
EXTERN char *p_fo;              ///< 'formatoptions'
EXTERN char *p_fp;              ///< 'formatprg'
EXTERN int p_fs;                ///< 'fsync'
EXTERN int p_gd;                ///< 'gdefault'
EXTERN char *p_guicursor;       ///< 'guicursor'
EXTERN char *p_guifont;         ///< 'guifont'
EXTERN char *p_guifontwide;     ///< 'guifontwide'
EXTERN char *p_hf;              ///< 'helpfile'
EXTERN OptInt p_hh;             ///< 'helpheight'
EXTERN char *p_hlg;             ///< 'helplang'
EXTERN int p_hid;               ///< 'hidden'
EXTERN char *p_hl;              ///< 'highlight'
EXTERN int p_hls;               ///< 'hlsearch'
EXTERN OptInt p_hi;             ///< 'history'
EXTERN int p_arshape;           ///< 'arabicshape'
EXTERN int p_icon;              ///< 'icon'
EXTERN char *p_iconstring;      ///< 'iconstring'
EXTERN int p_ic;                ///< 'ignorecase'
EXTERN OptInt p_iminsert;       ///< 'iminsert'
EXTERN OptInt p_imsearch;       ///< 'imsearch'
EXTERN int p_inf;               ///< 'infercase'
EXTERN char *p_inex;            ///< 'includeexpr'
EXTERN int p_is;                ///< 'incsearch'
EXTERN char *p_inde;            ///< 'indentexpr'
EXTERN char *p_indk;            ///< 'indentkeys'
EXTERN char *p_icm;             ///< 'inccommand'
EXTERN char *p_isf;             ///< 'isfname'
EXTERN char *p_isi;             ///< 'isident'
EXTERN char *p_isk;             ///< 'iskeyword'
EXTERN char *p_isp;             ///< 'isprint'
EXTERN int p_js;                ///< 'joinspaces'
EXTERN char *p_jop;             ///< 'jumpooptions'
EXTERN unsigned jop_flags;
#define JOP_STACK               0x01
#define JOP_VIEW                0x02
#define JOP_CLEAN               0x04
EXTERN char *p_keymap;          ///< 'keymap'
EXTERN char *p_kp;              ///< 'keywordprg'
EXTERN char *p_km;              ///< 'keymodel'
EXTERN char *p_langmap;         ///< 'langmap'
EXTERN int p_lnr;               ///< 'langnoremap'
EXTERN int p_lrm;               ///< 'langremap'
EXTERN char *p_lm;              ///< 'langmenu'
EXTERN OptInt p_lines;          ///< 'lines'
EXTERN OptInt p_linespace;      ///< 'linespace'
EXTERN int p_lisp;              ///< 'lisp'
EXTERN char *p_lop;             ///< 'lispoptions'
EXTERN char *p_lispwords;       ///< 'lispwords'
EXTERN OptInt p_ls;             ///< 'laststatus'
EXTERN OptInt p_stal;           ///< 'showtabline'
EXTERN char *p_lcs;             ///< 'listchars'

EXTERN int p_lz;                ///< 'lazyredraw'
EXTERN int p_lpl;               ///< 'loadplugins'
EXTERN int p_magic;             ///< 'magic'
EXTERN char *p_menc;            ///< 'makeencoding'
EXTERN char *p_mef;             ///< 'makeef'
EXTERN char *p_mp;              ///< 'makeprg'
EXTERN char *p_mps;             ///< 'matchpairs'
EXTERN OptInt p_mat;            ///< 'matchtime'
EXTERN OptInt p_mfd;            ///< 'maxfuncdepth'
EXTERN OptInt p_mmd;            ///< 'maxmapdepth'
EXTERN OptInt p_mmp;            ///< 'maxmempattern'
EXTERN OptInt p_mis;            ///< 'menuitems'
EXTERN char *p_msm;             ///< 'mkspellmem'
EXTERN int p_ml;                ///< 'modeline'
EXTERN int p_mle;               ///< 'modelineexpr'
EXTERN OptInt p_mls;            ///< 'modelines'
EXTERN int p_ma;                ///< 'modifiable'
EXTERN int p_mod;               ///< 'modified'
EXTERN char *p_mouse;           ///< 'mouse'
EXTERN char *p_mousem;          ///< 'mousemodel'
EXTERN int p_mousemev;          ///< 'mousemoveevent'
EXTERN int p_mousef;            ///< 'mousefocus'
EXTERN int p_mh;                ///< 'mousehide'
EXTERN char *p_mousescroll;     ///< 'mousescroll'
EXTERN OptInt p_mousescroll_vert INIT( = MOUSESCROLL_VERT_DFLT);
EXTERN OptInt p_mousescroll_hor INIT( = MOUSESCROLL_HOR_DFLT);
EXTERN OptInt p_mouset;         ///< 'mousetime'
EXTERN int p_more;              ///< 'more'
EXTERN char *p_nf;              ///< 'nrformats'
EXTERN char *p_opfunc;          ///< 'operatorfunc'
EXTERN char *p_para;            ///< 'paragraphs'
EXTERN int p_paste;             ///< 'paste'
EXTERN char *p_pex;             ///< 'patchexpr'
EXTERN char *p_pm;              ///< 'patchmode'
EXTERN char *p_path;            ///< 'path'
EXTERN char *p_cdpath;          ///< 'cdpath'
EXTERN int p_pi;                ///< 'preserveindent'
EXTERN OptInt p_pyx;            ///< 'pyxversion'
EXTERN char *p_qe;              ///< 'quoteescape'
EXTERN int p_ro;                ///< 'readonly'
EXTERN char *p_rdb;             ///< 'redrawdebug'
EXTERN unsigned rdb_flags;
#define RDB_COMPOSITOR          0x001
#define RDB_NOTHROTTLE          0x002
#define RDB_INVALID             0x004
#define RDB_NODELTA             0x008
#define RDB_LINE                0x010
#define RDB_FLUSH               0x020
#define RDB_INTERSECT           0x040

EXTERN OptInt p_rdt;            ///< 'redrawtime'
EXTERN OptInt p_re;             ///< 'regexpengine'
EXTERN OptInt p_report;         ///< 'report'
EXTERN OptInt p_pvh;            ///< 'previewheight'
EXTERN int p_ari;               ///< 'allowrevins'
EXTERN int p_ri;                ///< 'revins'
EXTERN int p_ru;                ///< 'ruler'
EXTERN char *p_ruf;             ///< 'rulerformat'
EXTERN char *p_pp;              ///< 'packpath'
EXTERN char *p_qftf;            ///< 'quickfixtextfunc'
EXTERN char *p_rtp;             ///< 'runtimepath'
EXTERN OptInt p_scbk;           ///< 'scrollback'
EXTERN OptInt p_sj;             ///< 'scrolljump'
EXTERN OptInt p_so;             ///< 'scrolloff'
EXTERN char *p_sbo;             ///< 'scrollopt'
EXTERN char *p_sections;        ///< 'sections'
EXTERN int p_secure;            ///< 'secure'
EXTERN char *p_sel;             ///< 'selection'
EXTERN char *p_slm;             ///< 'selectmode'
EXTERN char *p_ssop;            ///< 'sessionoptions'
EXTERN unsigned ssop_flags;

#define SSOP_BUFFERS            0x001
#define SSOP_WINPOS             0x002
#define SSOP_RESIZE             0x004
#define SSOP_WINSIZE            0x008
#define SSOP_LOCALOPTIONS       0x010
#define SSOP_OPTIONS            0x020
#define SSOP_HELP               0x040
#define SSOP_BLANK              0x080
#define SSOP_GLOBALS            0x100
#define SSOP_SLASH              0x200  // Deprecated, always set.
#define SSOP_UNIX               0x400  // Deprecated, always set.
#define SSOP_SESDIR             0x800
#define SSOP_CURDIR             0x1000
#define SSOP_FOLDS              0x2000
#define SSOP_CURSOR             0x4000
#define SSOP_TABPAGES           0x8000
#define SSOP_TERMINAL           0x10000
#define SSOP_SKIP_RTP           0x20000

EXTERN char *p_sh;              ///< 'shell'
EXTERN char *p_shcf;            ///< 'shellcmdflag'
EXTERN char *p_sp;              ///< 'shellpipe'
EXTERN char *p_shq;             ///< 'shellquote'
EXTERN char *p_sxq;             ///< 'shellxquote'
EXTERN char *p_sxe;             ///< 'shellxescape'
EXTERN char *p_srr;             ///< 'shellredir'
EXTERN int p_stmp;              ///< 'shelltemp'
#ifdef BACKSLASH_IN_FILENAME
EXTERN int p_ssl;               ///< 'shellslash'
#endif
EXTERN char *p_stl;             ///< 'statusline'
EXTERN char *p_wbr;             ///< 'winbar'
EXTERN int p_sr;                ///< 'shiftround'
EXTERN OptInt p_sw;             ///< 'shiftwidth'
EXTERN char *p_shm;             ///< 'shortmess'
EXTERN char *p_sbr;             ///< 'showbreak'
EXTERN int p_sc;                ///< 'showcmd'
EXTERN char *p_sloc;            ///< 'showcmdloc'
EXTERN int p_sft;               ///< 'showfulltag'
EXTERN int p_sm;                ///< 'showmatch'
EXTERN int p_smd;               ///< 'showmode'
EXTERN OptInt p_ss;             ///< 'sidescroll'
EXTERN OptInt p_siso;           ///< 'sidescrolloff'
EXTERN int p_scs;               ///< 'smartcase'
EXTERN int p_si;                ///< 'smartindent'
EXTERN int p_sta;               ///< 'smarttab'
EXTERN OptInt p_sts;            ///< 'softtabstop'
EXTERN int p_sb;                ///< 'splitbelow'
EXTERN char *p_sua;             ///< 'suffixesadd'
EXTERN int p_swf;               ///< 'swapfile'
EXTERN OptInt p_smc;            ///< 'synmaxcol'
EXTERN OptInt p_tpm;            ///< 'tabpagemax'
EXTERN char *p_tal;             ///< 'tabline'
EXTERN char *p_tpf;             ///< 'termpastefilter'
EXTERN unsigned tpf_flags;      ///< flags from 'termpastefilter'
#define TPF_BS                  0x001
#define TPF_HT                  0x002
#define TPF_FF                  0x004
#define TPF_ESC                 0x008
#define TPF_DEL                 0x010
#define TPF_C0                  0x020
#define TPF_C1                  0x040
EXTERN char *p_tfu;             ///< 'tagfunc'
EXTERN char *p_spc;             ///< 'spellcapcheck'
EXTERN char *p_spf;             ///< 'spellfile'
EXTERN char *p_spl;             ///< 'spelllang'
EXTERN char *p_spo;             ///< 'spelloptions'
EXTERN unsigned spo_flags;
EXTERN char *p_sps;             ///< 'spellsuggest'
EXTERN int p_spr;               ///< 'splitright'
EXTERN int p_sol;               ///< 'startofline'
EXTERN char *p_su;              ///< 'suffixes'
EXTERN char *p_swb;             ///< 'switchbuf'
EXTERN unsigned swb_flags;
// Keep in sync with p_swb_values in optionstr.c
#define SWB_USEOPEN             0x001
#define SWB_USETAB              0x002
#define SWB_SPLIT               0x004
#define SWB_NEWTAB              0x008
#define SWB_VSPLIT              0x010
#define SWB_USELAST             0x020
EXTERN char *p_spk;             ///< 'splitkeep'
EXTERN char *p_syn;             ///< 'syntax'
EXTERN char *p_tcl;             ///< 'tabclose'
EXTERN unsigned tcl_flags;      ///< flags from 'tabclose'
#define TCL_LEFT                0x001
#define TCL_USELAST             0x002
EXTERN OptInt p_ts;             ///< 'tabstop'
EXTERN int p_tbs;               ///< 'tagbsearch'
EXTERN char *p_tc;              ///< 'tagcase'
EXTERN unsigned tc_flags;       ///< flags from 'tagcase'
#define TC_FOLLOWIC             0x01
#define TC_IGNORE               0x02
#define TC_MATCH                0x04
#define TC_FOLLOWSCS            0x08
#define TC_SMART                0x10
EXTERN OptInt p_tl;             ///< 'taglength'
EXTERN int p_tr;                ///< 'tagrelative'
EXTERN char *p_tags;            ///< 'tags'
EXTERN int p_tgst;              ///< 'tagstack'
EXTERN int p_tbidi;             ///< 'termbidi'
EXTERN OptInt p_tw;             ///< 'textwidth'
EXTERN int p_to;                ///< 'tildeop'
EXTERN int p_timeout;           ///< 'timeout'
EXTERN OptInt p_tm;             ///< 'timeoutlen'
EXTERN int p_title;             ///< 'title'
EXTERN OptInt p_titlelen;       ///< 'titlelen'
EXTERN char *p_titleold;        ///< 'titleold'
EXTERN char *p_titlestring;     ///< 'titlestring'
EXTERN char *p_tsr;             ///< 'thesaurus'
EXTERN int p_tgc;               ///< 'termguicolors'
EXTERN int p_ttimeout;          ///< 'ttimeout'
EXTERN OptInt p_ttm;            ///< 'ttimeoutlen'
EXTERN char *p_udir;            ///< 'undodir'
EXTERN int p_udf;               ///< 'undofile'
EXTERN OptInt p_ul;             ///< 'undolevels'
EXTERN OptInt p_ur;             ///< 'undoreload'
EXTERN OptInt p_uc;             ///< 'updatecount'
EXTERN OptInt p_ut;             ///< 'updatetime'
EXTERN char *p_shada;           ///< 'shada'
EXTERN char *p_shadafile;       ///< 'shadafile'
EXTERN int p_termsync;          ///< 'termsync'
EXTERN char *p_vsts;            ///< 'varsofttabstop'
EXTERN char *p_vts;             ///< 'vartabstop'
EXTERN char *p_vdir;            ///< 'viewdir'
EXTERN char *p_vop;             ///< 'viewoptions'
EXTERN unsigned vop_flags;      ///< uses SSOP_ flags
EXTERN int p_vb;                ///< 'visualbell'
EXTERN char *p_ve;              ///< 'virtualedit'
EXTERN unsigned ve_flags;
#define VE_BLOCK       5U       // includes "all"
#define VE_INSERT      6U       // includes "all"
#define VE_ALL         4U
#define VE_ONEMORE     8U
#define VE_NONE        16U      // "none"
#define VE_NONEU       32U      // "NONE"
EXTERN OptInt p_verbose;        ///< 'verbose'
#ifdef IN_OPTION_C
char *p_vfile = empty_string_option;  ///< used before options are initialized
#else
extern char *p_vfile;           ///< 'verbosefile'
#endif
EXTERN int p_warn;              ///< 'warn'
EXTERN char *p_wop;             ///< 'wildoptions'
EXTERN unsigned wop_flags;
#define WOP_FUZZY               0x01
#define WOP_TAGFILE             0x02
#define WOP_PUM                 0x04
EXTERN OptInt p_window;         ///< 'window'
EXTERN char *p_wak;             ///< 'winaltkeys'
EXTERN char *p_wig;             ///< 'wildignore'
EXTERN char *p_ww;              ///< 'whichwrap'
EXTERN OptInt p_wc;             ///< 'wildchar'
EXTERN OptInt p_wcm;            ///< 'wildcharm'
EXTERN int p_wic;               ///< 'wildignorecase'
EXTERN char *p_wim;             ///< 'wildmode'
EXTERN int p_wmnu;              ///< 'wildmenu'
EXTERN OptInt p_wh;             ///< 'winheight'
EXTERN OptInt p_wmh;            ///< 'winminheight'
EXTERN OptInt p_wmw;            ///< 'winminwidth'
EXTERN OptInt p_wiw;            ///< 'winwidth'
EXTERN OptInt p_wm;             ///< 'wrapmargin'
EXTERN int p_ws;                ///< 'wrapscan'
EXTERN int p_write;             ///< 'write'
EXTERN int p_wa;                ///< 'writeany'
EXTERN int p_wb;                ///< 'writebackup'
EXTERN OptInt p_wd;             ///< 'writedelay'
EXTERN int p_cdh;               ///< 'cdhome'

// Value for b_p_ul indicating the global value must be used.
#define NO_LOCAL_UNDOLEVEL (-123456)

#define ERR_BUFLEN 80

#define SB_MAX 100000  // Maximum 'scrollback' value.

#define MAX_NUMBERWIDTH 20      // used for 'numberwidth'

// Maximum 'statuscolumn' width: number + sign + fold columns
#define MAX_STCWIDTH MAX_NUMBERWIDTH + SIGN_SHOW_MAX * SIGN_WIDTH + 9

#define TABSTOP_MAX 9999

#define SCL_NO  -1  // 'signcolumn' set to "no"
#define SCL_NUM -2  // 'signcolumn' set to "number"
