#ifndef NVIM_VIML_PARSER_COMMAND_ARGUMENTS_H_
#define NVIM_VIML_PARSER_COMMAND_ARGUMENTS_H_

typedef enum {
  kArgExpression,    // :let a={expr}
  kArgExpressions,   // :echo {expr1}[ {expr2}]
  kArgFlags,         // :map {<nowait><expr><buffer><silent><unique>}
  kArgNumber,        // :resize -1
  kArgNumbers,       // :menu 1.2.3
  kArgUNumber,       // :sign place {id} line={lnum} name=name buffer={nr}
  kArgUNumbers,      // :dig e: {num1} a: {num2}
  kArgString,        // :sign place 10 line=11 name={name} buffer=1
  // Note the difference: you cannot use backtics in :autocmd, but can in :e
  kArgPattern,       // :autocmd BufEnter {pattern} :echo 'HERE'
  kArgGlob,          // :e {glob}
  kArgRegex,         // :s/{reg}/\="abc"/g
  kArgReplacement,   // :s/.*/{repl}/g
  kArgLines,         // :py << EOF\n{str}\n{str2}EOF, :append\n{str}\n.
  kArgGaStrings,     // :function arguments
  kArgStrings,       // :dig digraphs
  kArgAssignLhs,     // :let {lhs} = [1, 2]
  kArgMenuName,      // :amenu File.Edit :browse edit<CR>
  kArgAuEvents,      // :au {event1}[,{event2}] * :echo 'HERE'
  kArgAddress,       // :copy {address}
  kArgCmdComplete,   // :command -complete={complete}
  kArgArgs,          // for commands with subcommands
  kArgChar,          // :mark {char}
  kArgColumn,        // column (in syntax error)
  kArgColor,         // Color (in :highlight)
  kArgSynGroups,     // Syntax groups (in :syn)
  kArgSynPattern,    // Syntax pattern (:syn match /pattern/)
  kArgSynPatterns,   // List of syntax patterns (:syn region end=/1/ end=/2/ …)
} CommandArgType;

#define ARGS_NO       { 0 }
#define ARGS_MODIFIER ARGS_NO
#define ARGS_DO       ARGS_NO
#define ARGS_APPEND   { kArgLines }
#define ARGS_MAP      { kArgFlags, kArgString, kArgString, kArgExpression }
#define ARGS_MENU     { kArgFlags, kArgString, kArgUNumbers, kArgMenuName, \
                        kArgString, kArgString }
#define ARGS_CLEAR    { kArgFlags }
#define ARGS_E        { kArgString, kArgGlob }
#define ARGS_OPEN     { kArgString, kArgRegex }
#define ARGS_SO       { kArgPattern }
#define ARGS_AU       { kArgString, kArgAuEvents, kArgPattern, kArgFlags }
#define ARGS_NAME     { kArgString }
#define ARGS_UNMAP    { kArgFlags, kArgString }
#define ARGS_UNMENU   { kArgMenuName }
#define ARGS_BREAK    { kArgFlags, kArgPattern }
#define ARGS_NUMBER   { kArgNumber }
#define ARGS_EXPR     { kArgExpression }
#define ARGS_REG      { kArgRegex }
#define ARGS_CLIST    { kArgNumber, kArgNumber }
#define ARGS_ADDR     { kArgAddress }
#define ARGS_CMD      { kArgFlags, kArgCmdComplete, kArgString, kArgString }
#define ARGS_SUBCMD   { kArgArgs }
#define ARGS_CSTAG    { kArgString }
#define ARGS_DIG      { kArgStrings, kArgUNumbers }
#define ARGS_DOAU     { kArgFlags, kArgString, kArgAuEvents, kArgString }
#define ARGS_EXPRS    { kArgExpressions }
#define ARGS_LOCKVAR  { kArgExpressions, kArgUNumber }
#define ARGS_EXIT     { kArgString, kArgGlob }
#define ARGS_WN       { kArgString, kArgGlob }
#define ARGS_FOR      { kArgString, kArgAssignLhs, kArgExpression }
#define ARGS_LET      { kArgFlags, kArgAssignLhs, kArgExpression }
#define ARGS_FUNC     { kArgRegex, kArgAssignLhs, kArgGaStrings, kArgFlags }
#define ARGS_G        { kArgFlags, kArgRegex }
#define ARGS_SHELL    { kArgString }
#define ARGS_HELP     { kArgString, kArgString }
#define ARGS_HELPG    { kArgRegex, kArgString }
#define ARGS_HT       { kArgFlags }
#define ARGS_HI       { kArgFlags,  kArgString, kArgString,  kArgFlags, \
                        kArgString, kArgString, kArgFlags,   kArgColor, \
                        kArgColor,  kArgFlags,  kArgString,  kArgColor, \
                        kArgColor,  kArgColor }
#define ARGS_HIST     { kArgFlags, kArgNumber, kArgNumber }
#define ARGS_LANG     { kArgFlags, kArgString }
#define ARGS_RESIZE   { kArgFlags, kArgNumber }
#define ARGS_VIMG     { kArgFlags, kArgRegex, kArgString, kArgGlob }
#define ARGS_MARK     { kArgChar }
#define ARGS_POPUP    { kArgMenuName }
#define ARGS_SIMALT   { kArgString }
#define ARGS_LATER    { kArgFlags, kArgUNumber }
#define ARGS_MATCH    { kArgString, kArgRegex }
#define ARGS_MT       { kArgMenuName, kArgString, kArgMenuName, kArgString }
#define ARGS_NORMAL   { kArgString }
#define ARGS_W        { kArgFlags, kArgString }
#define ARGS_UP       { kArgFlags }
#define ARGS_REDIR    { kArgFlags, kArgString, kArgAssignLhs }
#define ARGS_S        { kArgRegex, kArgReplacement, kArgFlags }
#define ARGS_SET      { kArgStrings, kArgUNumbers, kArgNumbers, kArgUNumbers, \
                        kArgNumbers, kArgStrings }
#define ARGS_FT       { kArgFlags }
#define ARGS_SLEEP    { kArgUNumber }
#define ARGS_SNIFF    { kArgString, kArgString, kArgString, kArgString }
#define ARGS_SORT     { kArgFlags, kArgRegex }
#define ARGS_SYNTIME  { kArgFlags }
#define ARGS_2INTS    { kArgFlags, kArgNumber, kArgNumber }
#define ARGS_WINCMD   { kArgChar }
#define ARGS_Z        { kArgChar, kArgUNumber, kArgUNumber }
#define ARGS_GUI      { kArgFlags }
#define ARGS_MKS      { kArgFlags }
#define ARGS_LOADVIEW { kArgChar }
#define ARGS_LKMAP    { kArgGaStrings, kArgGaStrings, kArgGaStrings }
#define ARGS_ERROR    { kArgString, kArgString, kArgColumn }
#define ARGS_USER     { kArgString }

// ++opt flags
#define FLAG_OPT_FF_MASK      0x0003
#define VAL_OPT_FF_USEOPT     0x0000
#define VAL_OPT_FF_DOS        0x0001
#define VAL_OPT_FF_UNIX       0x0002
#define VAL_OPT_FF_MAC        0x0003
#define FLAG_OPT_BIN_USE_FLAG 0x0004
#define FLAG_OPT_BIN          0x0008
#define FLAG_OPT_EDIT         0x0010
#define FLAG_OPT_BAD_USE_FLAG 0x0020
#define SHIFT_OPT_BAD         6
#define FLAG_OPT_BAD_MASK     (0x001FF << SHIFT_OPT_BAD)
#define VAL_OPT_BAD_KEEP      (0x00100 << SHIFT_OPT_BAD)
#define VAL_OPT_BAD_DROP      (0x001FF << SHIFT_OPT_BAD)
// :gui/:gvim: -g/-b flag
#define FLAG_OPT_GUI_USE_FLAG 0x0200
#define FLAG_OPT_GUI_FORK     0x0400
// :write/:update
#define FLAG_OPT_W_APPEND     0x0800

#define CHAR_TO_VAL_OPT_BAD(c) (((uint_least32_t) c) << SHIFT_OPT_BAD)
#define VAL_OPT_BAD_TO_CHAR(f) ((char) ((f >> SHIFT_OPT_BAD) & 0xFF))

// Constants to index arguments in CommandNode
#define ARG_NO_ARGS -1

// :append/:insert
enum {
  ARG_APPEND_LINES  = 0,
};

// :*map/:*abbrev
enum {
  ARG_MAP_FLAGS     = 0,
  ARG_MAP_LHS,
  ARG_MAP_RHS,
  ARG_MAP_EXPR,
};

#define FLAG_MAP_BUFFER    0x01
#define FLAG_MAP_NOWAIT    0x02
#define FLAG_MAP_SILENT    0x04
#define FLAG_MAP_SPECIAL   0x08
#define FLAG_MAP_SCRIPT    0x10
#define FLAG_MAP_EXPR      0x20
#define FLAG_MAP_UNIQUE    0x40

// :*menu
enum {
  ARG_MENU_FLAGS    = 0,
  ARG_MENU_ICON,
  ARG_MENU_PRI,
  ARG_MENU_NAME,
  ARG_MENU_TEXT,
  ARG_MENU_RHS,
};

#define FLAG_MENU_SILENT   0x01
#define FLAG_MENU_SPECIAL  0x02
#define FLAG_MENU_SCRIPT   0x04
#define FLAG_MENU_DISABLE  0x08
#define FLAG_MENU_ENABLE   0x10

// :*mapclear/:*abclear
enum {
  ARG_CLEAR_BUFFER  = 0,
};

// :aboveleft and friends
#define ARG_MODIFIER_CMD   ARG_NO_ARGS

// :argdo/:bufdo
#define ARG_DO_CMD         ARG_NO_ARGS

// :args/:e, also for :open
enum {
  ARG_E_EXPR        = 0,
  ARG_E_FILES,
};

// :open
enum {
  ARG_OPEN_FILE     = 0,
  ARG_OPEN_REGEX,
};

// :argadd/:argdelete/:source
enum {
  ARG_SO_FILES      = 0,
};

// :au
enum {
  ARG_AU_GROUP      = 0,
  ARG_AU_EVENTS,
  ARG_AU_PATTERNS,
  ARG_AU_NESTED,
};

// :aug/:behave/:colorscheme
enum {
  ARG_NAME_NAME     = 0,
};

// :*unmap/:*unabbrev
enum {
  ARG_UNMAP_BUFFER  = 0,
  ARG_UNMAP_LHS,
};

// :*unmenu
enum {
  ARG_UNMENU_LHS    = 0,
};

// :breakadd/:breakdel/:profile/:profdel
// lnum is recorded in range
enum {
  ARG_BREAK_TYPE    = 0,
  ARG_BREAK_NAME,
};

typedef enum {
  kBreakInFunction,
  kBreakInFile,
  kBreakHere,
  kProfileStart,
  kProfilePause,
  kProfileContinue,
} BreakType;

// :[lc](add)?buffer
enum {
  ARG_NUMBER_NUMBER = 0
};

// :caddexpr/:laddexpr/:call
enum {
  ARG_EXPR_EXPR     = 0,
};

// :catch/:djump
enum {
  ARG_REG_REG       = 0,
};

// :clist
enum {
  ARG_CLIST_FIRST   = 0,
  ARG_CLIST_LAST,
};

// :copy/:move
enum {
  ARG_ADDR_ADDR     = 0,
};

// :command
enum {
  ARG_CMD_FLAGS     = 0,
  ARG_CMD_COMPLETE,
  ARG_CMD_NAME,
  ARG_CMD_COMMAND
};

#define FLAG_CMD_NARGS_MASK  0x007U
#define VAL_CMD_NARGS_NO     0x000U
#define VAL_CMD_NARGS_ONE    0x001U
#define VAL_CMD_NARGS_ANY    0x002U
#define VAL_CMD_NARGS_Q      0x003U
#define VAL_CMD_NARGS_P      0x004U
// Number is recorded in count
#define FLAG_CMD_RANGE_MASK  0x018U
#define VAL_CMD_RANGE_NO     0x000U
#define VAL_CMD_RANGE_CUR    0x008U
#define VAL_CMD_RANGE_ALL    0x010U
// Count (specified in -range)
#define VAL_CMD_RANGE_COUNT  0x018U
#define FLAG_CMD_BANG        0x040U
#define FLAG_CMD_BAR         0x080U
#define FLAG_CMD_REGISTER    0x100U
#define FLAG_CMD_BUFFER      0x200U
// Count (specified in -count: additionally allows count as a first argument)
#define FLAG_CMD_COUNT_MASK  0xC00U
#define VAL_CMD_COUNT_NO     0x000U
#define VAL_CMD_COUNT_EMPTY  0x400U
#define VAL_CMD_COUNT_COUNT  0x800U

// :cscope/:sign/:syntax
enum {
  ARG_SUBCMD        = 0,
};

// :syntax

typedef enum {
  kSynCase = 0,
  kSynClear,
  kSynCluster,
  kSynConceal,
  kSynEnable,
  kSynInclude,
  kSynKeyword,
  kSynList,
  kSynManual,
  kSynMatch,
  kSynOn,
  kSynOff,
  kSynRegion,
  kSynReset,
  kSynSpell,
  kSynSync,
} SynArgType;

enum {
  SYN_ARG_CASE_FLAGS = 0,
};
// Boolean flag (match|ignore).
#define SYN_ARGS_CASE { kArgFlags }

enum {
  SYN_ARG_CLUSTER_NAME = 0,
  SYN_ARG_CLUSTER_CONTAINS,
  SYN_ARG_CLUSTER_ADD,
  SYN_ARG_CLUSTER_REMOVE,
};
#define SYN_ARGS_CLUSTER { kArgString, kArgSynGroups, kArgSynGroups, \
                           kArgSynGroups }

enum {
  SYN_ARG_CONCEAL_FLAGS = 0,
};
// Boolean flag (on|off).
#define SYN_ARGS_CONCEAL { kArgFlags }

enum {
  SYN_ARG_INCLUDE_CLUSTER = 0,
  SYN_ARG_INCLUDE_FILE,
};
#define SYN_ARGS_INCLUDE { kArgString, kArgPattern }

// :syn-keyword+:syn-match+:syn-region flags
#define FLAG_SYN_MAIN_CONCEAL        0x0001
#define FLAG_SYN_MAIN_TRANSPARENT    0x0002
#define FLAG_SYN_MAIN_SKIPWHITE      0x0004
#define FLAG_SYN_MAIN_SKIPNL         0x0008
#define FLAG_SYN_MAIN_SKIPEMPTY      0x0010
#define FLAG_SYN_MAIN_ONELINE        0x0020
#define FLAG_SYN_MAIN_FOLD           0x0040
#define FLAG_SYN_MAIN_DISPLAY        0x0080
#define FLAG_SYN_MAIN_CONTAINED      0x0100

// :syn-match+:syn-region flags
#define FLAG_SYN_MR_EXTEND           0x0200
#define FLAG_SYN_MR_EXCLUDENL        0x0400

// :syn-region-specific flags
#define FLAG_SYN_REGION_CONCEALENDS  0x0800
#define FLAG_SYN_REGION_KEEPEND      0x1000

// :syn-sync-specific flags
#define FLAG_SYN_SYNC_FROMSTART      0x2000
#define FLAG_SYN_SYNC_HASMINLINES    0x4000
#define FLAG_SYN_SYNC_HASMAXLINES    0x8000
#define FLAG_SYN_SYNC_HASLINEBREAKS 0x10000L

enum {
  SYN_ARG_KEYWORD_GROUP = 0,
  SYN_ARG_KEYWORD_FLAGS,
  SYN_ARG_KEYWORD_CCHAR,
  SYN_ARG_KEYWORD_CONTAINS,
  SYN_ARG_KEYWORD_CONTAINEDIN,
  SYN_ARG_KEYWORD_NEXTGROUP,
  SYN_ARG_KEYWORD_KEYWORDS,
};
#define SYN_ARGS_KEYWORD { kArgString, kArgFlags, kArgString, \
                           kArgSynGroups, kArgSynGroups, kArgSynGroups, \
                           kArgGaStrings }

#define SYN_ARG_FLAGS_OFFSET       0
#define SYN_ARG_CCHAR_OFFSET       1
#define SYN_ARG_CONTAINS_OFFSET    2
#define SYN_ARG_CONTAINEDIN_OFFSET 3
#define SYN_ARG_NEXTGROUP_OFFSET   4
#define SYN_ARG_GROUPHERE_OFFSET   5
#define SYN_ARG_GROUPTHERE_OFFSET  6

enum {
  SYN_ARG_LIST_GROUPS = 0,
};
#define SYN_ARGS_LIST { kArgSynGroups }

enum {
  SYN_ARG_CLEAR_GROUPS = 0,
};
#define SYN_ARGS_CLEAR { kArgSynGroups }

enum {
  SYN_ARG_MATCH_GROUP = 0,
  SYN_ARG_MATCH_FLAGS,
  SYN_ARG_MATCH_CCHAR,
  SYN_ARG_MATCH_CONTAINS,
  SYN_ARG_MATCH_CONTAINEDIN,
  SYN_ARG_MATCH_NEXTGROUP,
  SYN_ARG_MATCH_GROUPHERE,
  SYN_ARG_MATCH_GROUPTHERE,
  SYN_ARG_MATCH_REGEX,
};
#define SYN_ARGS_MATCH { kArgString, kArgFlags, kArgString, \
                         kArgSynGroups, kArgSynGroups, kArgSynGroups, \
                         kArgString, kArgString, \
                         kArgSynPattern }

enum {
  SYN_ARG_REGION_GROUP = 0,
  SYN_ARG_REGION_FLAGS,
  SYN_ARG_REGION_CCHAR,
  SYN_ARG_REGION_CONTAINS,
  SYN_ARG_REGION_CONTAINEDIN,
  SYN_ARG_REGION_NEXTGROUP,
  SYN_ARG_REGION_GROUPHERE,
  SYN_ARG_REGION_GROUPTHERE,
  SYN_ARG_REGION_MATCHGROUP,
  SYN_ARG_REGION_STARTREG,
  SYN_ARG_REGION_ENDREG,
  SYN_ARG_REGION_SKIPREG,
};
#define SYN_ARGS_REGION { kArgString, kArgFlags, kArgString, \
                          kArgSynGroups, kArgSynGroups, kArgSynGroups, \
                          kArgString, kArgString, \
                          kArgString, \
                          kArgSynPatterns, kArgSynPatterns, kArgSynPatterns }

enum {
  SYN_ARG_SPELL_FLAGS = 0,
};
#define SYN_ARGS_SPELL { kArgFlags }

#define VAL_SYN_SPELL_TOPLEVEL   0x0
#define VAL_SYN_SPELL_NOTOPLEVEL 0x1
#define VAL_SYN_SPELL_DEFAULT    0x2

enum {
  SYN_ARG_SYNC_FLAGS = 0,
  SYN_ARG_SYNC_CCOMMENT,
  SYN_ARG_SYNC_MAXLINES,
  SYN_ARG_SYNC_MINLINES,
  SYN_ARG_SYNC_LINEBREAKS,
  SYN_ARG_SYNC_REGEX,
  SYN_ARG_SYNC_CMD,
};
#define SYN_ARGS_SYNC { kArgFlags, kArgString, \
                        kArgUNumber, kArgUNumber, kArgUNumber, \
                        kArgRegex, kArgArgs }

// :sign

typedef enum {
  kSignDefine = 0,
  kSignUndefine,
  kSignList,
  kSignPlace,
  kSignUnplace,
  kSignJump,
} SignArgType;

#define SIGN_ARG_DEFINE_NAME   0
#define SIGN_ARG_DEFINE_ICON   1
#define SIGN_ARG_DEFINE_LINEHL 2
#define SIGN_ARG_DEFINE_TEXT   3
#define SIGN_ARG_DEFINE_TEXTHL 4

#define SIGN_ARGS_DEFINE { kArgString, kArgString, kArgString, kArgString, \
                           kArgString }

#define SIGN_ARG_UNDEFINE_NAME 0

#define SIGN_ARGS_UNDEFINE { kArgString }

#define SIGN_ARG_LIST_NAME 0

#define SIGN_ARGS_LIST { kArgString }

#define SIGN_ARG_PLACE_ID     0
#define SIGN_ARG_PLACE_FILE   1
#define SIGN_ARG_PLACE_BUFFER 2
#define SIGN_ARG_PLACE_NAME   3
#define SIGN_ARG_PLACE_LINE   4

#define SIGN_ARGS_PLACE { kArgNumber, kArgString, kArgUNumber, kArgString, \
                          kArgUNumber }

#define SIGN_ARG_JUMP_ID     0
#define SIGN_ARG_JUMP_FILE   1
#define SIGN_ARG_JUMP_BUFFER 2

#define SIGN_ARGS_JUMP { kArgNumber, kArgString, kArgUNumber }

#define SIGN_ARG_UNPLACE_ID     0
#define SIGN_ARG_UNPLACE_FILE   1
#define SIGN_ARG_UNPLACE_BUFFER 2

#define SIGN_ARGS_UNPLACE { kArgNumber, kArgString, kArgUNumber }

#define SYN_SCOPE_KEYWORD 0x01
#define SYN_SCOPE_MATCH   0x02
#define SYN_SCOPE_REGION  0x04
#define SYN_SCOPE_SYNC    0x08

#define SYN_SCOPE_MAIN (SYN_SCOPE_KEYWORD|SYN_SCOPE_MATCH|SYN_SCOPE_REGION)
#define SYN_SCOPE_MR   (SYN_SCOPE_MATCH|SYN_SCOPE_REGION)

// :cscope
typedef enum {
  kCscopeAdd = 0,
  kCscopeFind,
  kCscopeHelp,
  kCscopeKill,
  kCscopeReset,
  kCscopeShow,
} CscopeArgType;
#define CSCOPE_ARG_ADD_PATH     0
#define CSCOPE_ARG_ADD_PRE_PATH 1
#define CSCOPE_ARG_ADD_FLAGS    2
#define CSCOPE_ARGS_ADD { kArgString, kArgString, kArgString }

// Note: numbers are exactly those cs_create_cmd uses
typedef enum {
  kCscopeFindSymbol = 0,
  kCscopeFindDefinition = 1,
  kCscopeFindCallees = 2,
  kCscopeFindCallers = 3,
  kCscopeFindText = 4,
  kCscopeFindEgrep = 6,
  kCscopeFindFile = 7,
  kCscopeFindIncluders = 8,
} CscopeSearchType;
#define CSCOPE_ARG_FIND_TYPE    0
#define CSCOPE_ARG_FIND_NAME    1
#define CSCOPE_ARGS_FIND { kArgFlags, kArgString }

// :cstag
enum {
  ARG_CSTAG_TAG     = 0,
};

// :digraphs
enum {
  ARG_DIG_DIGRAPHS  = 0,
  ARG_DIG_CHARS,
};

// :doautocmd/:doautoall
enum {
  ARG_DOAU_NOMDLINE = 0,
  ARG_DOAU_GROUP,
  ARG_DOAU_EVENTS,
  ARG_DOAU_FNAME,
};

// :echo*/:execute
enum {
  ARG_EXPRS_EXPRS   = 0,
  // :lockvar
  ARG_LOCKVAR_DEPTH,
};

// :exit
enum {
  ARG_EXIT_EXPR     = 0,
  ARG_EXIT_FILES,
};

// :wnext/:wNext/:wprevious
enum {
  ARG_WN_EXPR       = 0,
  ARG_WN_FILES,
};

// :for
enum {
  ARG_FOR_STR       = 0,
  ARG_FOR_LHS,
  ARG_FOR_RHS,
};

// :let
enum {
  ARG_LET_ASS_TYPE  = 0,
  ARG_LET_LHS,
  ARG_LET_RHS,
};

typedef enum {
  VAL_LET_NO_ASS    = 0,
  VAL_LET_ASSIGN,
  VAL_LET_ADD,
  VAL_LET_SUBTRACT,
  VAL_LET_APPEND,
} LetAssignmentType;

// :func
enum {
  ARG_FUNC_REG      = 0,
  ARG_FUNC_NAME,
  ARG_FUNC_ARGS,
  ARG_FUNC_FLAGS,
};

#define FLAG_FUNC_VARARGS  0x01
#define FLAG_FUNC_RANGE    0x02
#define FLAG_FUNC_ABORT    0x04
#define FLAG_FUNC_DICT     0x08

// :global
enum {
  ARG_G_FLAGS       = 0,
  ARG_G_REG,
};

#define FLAG_G_RE_SUBST    0x01
#define FLAG_G_RE_SEARCH   0x02

// :grep/:make/:!
enum {
  ARG_SHELL_ARGS    = 0,
};

// :help
enum {
  ARG_HELP_TOPIC    = 0,
  ARG_HELP_LANG,
};

// :helpg/:lhelpg
enum {
  ARG_HELPG_REG     = 0,
  ARG_HELPG_LANG,
};

// :helptags
enum {
  ARG_HT_MAIN       = 0,
};

// :highlight
enum {
  ARG_HI_FLAGS      = 0,
  ARG_HI_GROUP,
  ARG_HI_TGT_GROUP,
  ARG_HI_TERM,
  ARG_HI_START,
  ARG_HI_STOP,
  ARG_HI_CTERM,
  ARG_HI_CTERMFG,
  ARG_HI_CTERMBG,
  ARG_HI_GUI,
  ARG_HI_FONT,
  ARG_HI_GUIFG,
  ARG_HI_GUIBG,
  ARG_HI_GUISP,
};

#define FLAG_HI_TERM_BOLD      0x01
#define FLAG_HI_TERM_UNDERLINE 0x02
#define FLAG_HI_TERM_UNDERCURL 0x04
#define FLAG_HI_TERM_REVERSE   0x08
#define FLAG_HI_TERM_ITALIC    0x10
#define FLAG_HI_TERM_STANDOUT  0x20
#define FLAG_HI_TERM_NONE      0x40

#define FLAG_HI_COLOR_SOME     (0x01<<24)
#define FLAG_HI_COLOR_NONE     (0x02<<24)
#define FLAG_HI_COLOR_BG       (0x04<<24)
#define FLAG_HI_COLOR_FG       (0x08<<24)

#define FLAG_HI_DEFAULT    0x01
#define FLAG_HI_CLEAR      0x02
#define FLAG_HI_LINK       0x04

// :history
enum {
  ARG_HIST_FLAGS    = 0,
  ARG_HIST_FIRST,
  ARG_HIST_LAST,
};

#define FLAG_HIST_CMD      0x01
#define FLAG_HIST_SEARCH   0x02
#define FLAG_HIST_EXPR     0x04
#define FLAG_HIST_INPUT    0x08
#define FLAG_HIST_DEBUG    0x10
#define FLAG_HIST_DEFAULT  0x20
#define FLAG_HIST_ALL (FLAG_HIST_CMD\
                       |FLAG_HIST_SEARCH\
                       |FLAG_HIST_EXPR\
                       |FLAG_HIST_INPUT\
                       |FLAG_HIST_DEBUG)

// :language
enum {
  ARG_LANG_TYPE     = 0,
  ARG_LANG_LANG,
};

typedef enum {
  VAL_LANG_ALL,
  VAL_LANG_MESSAGES,
  VAL_LANG_CTYPE,
  VAL_LANG_TIME,
} LocaleType;

// :resize
enum {
  ARG_RESIZE_FLAGS  = 0,
  ARG_RESIZE_NUMBER,
};

// :*vimgrep*
enum {
  ARG_VIMG_FLAGS    = 0,
  ARG_VIMG_REG,
};

#define FLAG_VIMG_EVERY    0x01
#define FLAG_VIMG_NOJUMP   0x02

// :k/:mark
enum {
  ARG_MARK_CHAR     = 0,
};

// :popup
enum {
  ARG_POPUP_NAME    = 0,
};

// :simalt
enum {
  ARG_SIMALT_KEYS   = 0,
};

// :earlier/:later
enum {
  ARG_LATER_FLAGS   = 0,
  ARG_LATER_COUNT
};

#define FLAG_LATER_TYPE_MASK  0x07
#define VAL_LATER_COUNT       0x00
#define VAL_LATER_SECONDS     0x01
#define VAL_LATER_MINUTES     0x02
#define VAL_LATER_HOURS       0x03
#define VAL_LATER_DAYS        0x04
#define VAL_LATER_FILE        0x05

// :match
enum {
  ARG_MATCH_GROUP   = 0,
  ARG_MATCH_REG,
};

// :menutranslate
enum {
  ARG_MT_FROM_ITEM  = 0,
  ARG_MT_FROM_TEXT,
  ARG_MT_TO_ITEM,
  ARG_MT_TO_TEXT,
};

// :normal
enum {
  ARG_NORMAL_STR    = 0,
};

// :write/:read/:update
enum {
  ARG_W_APPEND      = 0,
  ARG_W_SHELL,
};
// ARG_W_SHELL: not for :update

// :redir
enum {
  ARG_REDIR_FLAGS   = 0,
  ARG_REDIR_FILE,
  ARG_REDIR_VAR,
};

#define FLAG_REDIR_REG_MASK 0x0FF
#define FLAG_REDIR_APPEND   0x100

// :substitute
enum {
  ARG_S_REG         = 0,
  ARG_S_REP,
  ARG_S_FLAGS,
};

#define FLAG_S_KEEP        0x001U
#define FLAG_S_CONFIRM     0x002U
#define FLAG_S_NOERR       0x004U
#define FLAG_S_G           0x008U
#define FLAG_S_G_REVERSE   0x010U
#define FLAG_S_IC          0x020U
#define FLAG_S_NOIC        0x040U
#define FLAG_S_COUNT       0x080U
#define FLAG_S_PRINT       0x100U
#define FLAG_S_PRINT_LNR   0x200U
#define FLAG_S_PRINT_LIST  0x400U
#define FLAG_S_R           0x800U
#define FLAG_S_RE_SUBST   0x1000U
#define FLAG_S_RE_SEARCH  0x2000U
#define FLAG_S_SUB_PREV   0x4000U

// :set
enum {
  ARG_SET_OPTIONS   = 0,
  ARG_SET_FLAGSS,
  ARG_SET_INDEXES,
  ARG_SET_KEYS,
  ARG_SET_IVALUES,
  ARG_SET_VALUES,
};

/// Set boolean value to true
#define FLAG_SET_SET       0x001
/// Set boolean value to false
#define FLAG_SET_UNSET     0x002
/// Show option value
#define FLAG_SET_SHOW      0x004
/// Invert boolean option value
#define FLAG_SET_INVERT    0x008
/// Set option value to default
#define FLAG_SET_DEFAULT   0x010
/// When setting option value to default use Vi default
#define FLAG_SET_VI        0x020
/// When setting option value to default use Vim default
#define FLAG_SET_VIM       0x040
/// Assign number or string option
#define FLAG_SET_ASSIGN    0x080
/// Append string to the option value (set +=)
#define FLAG_SET_APPEND    0x100
/// Prepend string to the option value (set ^=)
#define FLAG_SET_PREPEND   0x200
/// Remove string from the option value (set -=)
#define FLAG_SET_REMOVE    0x400
/// Set option value to global option value (set <)
#define FLAG_SET_GLOBAL    0x800
/// Set if current option has an integer value (for printer)
#define FLAG_SET_IVALUE   0x1000

// :filetype
enum {
  ARG_FT_FLAGS      = 0,
};

#define FLAG_FT_ON         0x01
#define FLAG_FT_OFF        0x02
#define FLAG_FT_DETECT     0x04
#define FLAG_FT_PLUGIN     0x08
#define FLAG_FT_INDENT     0x10

// :sign
// FIXME

// :sleep
enum {
  ARG_SLEEP_MULT    = 0,
};

// :sniff
enum {
  ARG_SNIFF_CMD     = 0,
  ARG_SNIFF_SYMBOL,
  ARG_SNIFF_DEF,
  ARG_SNIFF_MSG,
};

// :sort
enum {
  ARG_SORT_FLAGS    = 0,
  ARG_SORT_REG,
};

#define FLAG_SORT_IC        0x01U
#define FLAG_SORT_DECIMAL   0x02U
#define FLAG_SORT_HEX       0x04U
#define FLAG_SORT_OCTAL     0x08U
#define FLAG_SORT_KEEPFST   0x10U
#define FLAG_SORT_USEMATCH  0x20U
#define FLAG_SORT_RE_SEARCH 0x40U

// :syn
// FIXME

// :syntime
enum {
  ARG_SYNTIME_ACTION= 0,
};

#define VAL_SYNTIME_ON     0x01
#define VAL_SYNTIME_OFF    0x02
#define VAL_SYNTIME_CLEAR  0x03
#define VAL_SYNTIME_REPORT 0x04

// :winsize/:winpos
enum {
  ARG_2INTS_FLAGS = 0,
  ARG_2INTS_NUM1,
  ARG_2INTS_NUM2,
};

// :wincmd
enum {
  ARG_WINCMD_CHAR   = 0,
};

// :z
enum {
  ARG_Z_KIND        = 0,
  ARG_Z_BIGNESS,
  ARG_Z_MULTIPLIER,
};

// :gui/:gvim
enum {
  ARG_GUI_FG        = 0,
};

// :mkspell
enum {
  ARG_MKS_ASCII     = 0,
};

// :loadview
enum {
  ARG_LOADVIEW_NR   = 0,
};

// :loadkeymap
enum {
  ARG_LKMAP_LHSS    = 0,
  ARG_LKMAP_RHSS,
  ARG_LKMAP_COMS,
};

// syntax error
enum {
  ARG_ERROR_LINESTR = 0,
  ARG_ERROR_MESSAGE,
  ARG_ERROR_OFFSET,
};

// User-defined commands
enum {
  ARG_USER_ARG      = 0,
};

#endif  // NVIM_VIML_PARSER_COMMAND_ARGUMENTS_H_
