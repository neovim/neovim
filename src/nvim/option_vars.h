#pragma once

#include "nvim/macros_defs.h"
#include "nvim/os/os_defs.h"
#include "nvim/sign_defs.h"
#include "nvim/statusline_defs.h"
#include "nvim/types_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "option_vars.generated.h"  // NOLINT(build/include_defs)
#endif

// option_vars.h: definition of global variables for settable options

#define HIGHLIGHT_INIT \
  "8:SpecialKey,~:EndOfBuffer,z:TermCursor,@:NonText,d:Directory,e:ErrorMsg," \
  "i:IncSearch,l:Search,y:CurSearch,m:MoreMsg,M:ModeMsg,n:LineNr,a:LineNrAbove,b:LineNrBelow," \
  "N:CursorLineNr,G:CursorLineSign,O:CursorLineFold,r:Question,s:StatusLine,S:StatusLineNC," \
  "c:VertSplit,t:Title,v:Visual,V:VisualNOS,w:WarningMsg,W:WildMenu,f:Folded,F:FoldColumn," \
  "A:DiffAdd,C:DiffChange,D:DiffDelete,T:DiffText,>:SignColumn,-:Conceal,B:SpellBad,P:SpellCap," \
  "R:SpellRare,L:SpellLocal,+:Pmenu,=:PmenuSel,k:PmenuMatch,<:PmenuMatchSel,[:PmenuKind," \
  "]:PmenuKindSel,{:PmenuExtra,}:PmenuExtraSel,x:PmenuSbar,X:PmenuThumb,*:TabLine,#:TabLineSel," \
  "_:TabLineFill,!:CursorColumn,.:CursorLine,o:ColorColumn,q:QuickFixLine,z:StatusLineTerm," \
  "Z:StatusLineTermNC,g:MsgArea,h:ComplMatchIns,0:Whitespace,I:NormalNC"

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

// arguments for can_bs()
// each defined char should be unique over all values
// except for BS_START, that intentionally also matches BS_NOSTOP
// because BS_NOSTOP behaves exactly the same except it
// does not stop at the start of the insert point
#define BS_INDENT       'i'     // "Indent"
#define BS_EOL          'l'     // "eoL"
#define BS_START        's'     // "Start"
#define BS_NOSTOP       'p'     // "nostoP

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
EXTERN char *p_bdir;             ///< 'backupdir'
EXTERN char *p_bex;              ///< 'backupext'
EXTERN char *p_bo;               ///< 'belloff'
EXTERN char breakat_flags[256];  ///< which characters are in 'breakat'
EXTERN unsigned bo_flags;
EXTERN char *p_bsk;             ///< 'backupskip'
EXTERN char *p_breakat;         ///< 'breakat'
EXTERN char *p_bh;              ///< 'bufhidden'
EXTERN char *p_bt;              ///< 'buftype'
EXTERN char *p_cmp;             ///< 'casemap'
EXTERN unsigned cmp_flags;
EXTERN char *p_enc;             ///< 'encoding'
EXTERN int p_deco;              ///< 'delcombine'
EXTERN char *p_ccv;             ///< 'charconvert'
EXTERN char *p_cino;            ///< 'cinoptions'
EXTERN char *p_cedit;           ///< 'cedit'
EXTERN char *p_cb;              ///< 'clipboard'
EXTERN unsigned cb_flags;
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
EXTERN char *p_ffu;             ///< 'findfunc'
EXTERN int p_fixeol;            ///< 'fixendofline'
EXTERN char *p_fcl;             ///< 'foldclose'
EXTERN OptInt p_fdls;           ///< 'foldlevelstart'
EXTERN char *p_fdo;             ///< 'foldopen'
EXTERN unsigned fdo_flags;
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
EXTERN OptInt p_mco;            ///< 'maxcombine'
EXTERN OptInt p_mfd;            ///< 'maxfuncdepth'
EXTERN OptInt p_mmd;            ///< 'maxmapdepth'
EXTERN OptInt p_mmp;            ///< 'maxmempattern'
EXTERN OptInt p_mis;            ///< 'menuitems'
EXTERN char *p_mopt;            ///< 'messagesopt'
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
EXTERN char *p_spk;             ///< 'splitkeep'
EXTERN char *p_syn;             ///< 'syntax'
EXTERN char *p_tcl;             ///< 'tabclose'
EXTERN unsigned tcl_flags;      ///< flags from 'tabclose'
EXTERN OptInt p_ts;             ///< 'tabstop'
EXTERN int p_tbs;               ///< 'tagbsearch'
EXTERN char *p_tc;              ///< 'tagcase'
EXTERN unsigned tc_flags;       ///< flags from 'tagcase'
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
EXTERN unsigned vop_flags;      ///< uses OptSsopFlags
EXTERN int p_vb;                ///< 'visualbell'
EXTERN char *p_ve;              ///< 'virtualedit'
EXTERN unsigned ve_flags;
EXTERN OptInt p_verbose;        ///< 'verbose'
#ifdef IN_OPTION_C
char *p_vfile = empty_string_option;  ///< used before options are initialized
#else
extern char *p_vfile;           ///< 'verbosefile'
#endif
EXTERN int p_warn;              ///< 'warn'
EXTERN char *p_wop;             ///< 'wildoptions'
EXTERN unsigned wop_flags;
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
