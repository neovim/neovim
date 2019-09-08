// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * eval.c: Expression evaluation.
 */

#include <math.h>

#ifdef HAVE_LOCALE_H
# include <locale.h>
#endif

#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/change.h"
#include "nvim/channel.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/eval/encode.h"
#include "nvim/eval/executor.h"
#include "nvim/eval/gc.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/ex_session.h"
#include "nvim/fileio.h"
#include "nvim/getchar.h"
#include "nvim/lua/executor.h"
#include "nvim/mark.h"
#include "nvim/memline.h"
#include "nvim/misc1.h"
#include "nvim/move.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/shell.h"
#include "nvim/path.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/sign.h"
#include "nvim/syntax.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/version.h"
#include "nvim/window.h"


// TODO(ZyX-I): Remove DICT_MAXNEST, make users be non-recursive instead

#define DICT_MAXNEST 100        /* maximum nesting of lists and dicts */

// Character used as separator in autoload function/variable names.
#define AUTOLOAD_CHAR '#'


static char *e_letunexp = N_("E18: Unexpected characters in :let");
static char *e_missbrac = N_("E111: Missing ']'");
static char *e_funcexts = N_(
    "E122: Function %s already exists, add ! to replace it");
static char *e_funcdict = N_("E717: Dictionary entry already exists");
static char *e_funcref = N_("E718: Funcref required");
static char *e_dictrange = N_("E719: Cannot use [:] with a Dictionary");
static char *e_nofunc = N_("E130: Unknown function: %s");
static char *e_illvar = N_("E461: Illegal variable name: %s");
static char *e_cannot_mod = N_("E995: Cannot modify existing variable");

// TODO(ZyX-I): move to eval/executor
static char *e_letwrong = N_("E734: Wrong variable type for %s=");

static char_u * const namespace_char = (char_u *)"abglstvw";

/// Variable used for g:
static ScopeDictDictItem globvars_var;

/// g: value
#define globvarht globvardict.dv_hashtab

/*
 * Old Vim variables such as "v:version" are also available without the "v:".
 * Also in functions.  We need a special hashtable for them.
 */
static hashtab_T compat_hashtab;

hashtab_T func_hashtab;

// Used for checking if local variables or arguments used in a lambda.
static int *eval_lavars_used = NULL;

/*
 * Array to hold the hashtab with variables local to each sourced script.
 * Each item holds a variable (nameless) that points to the dict_T.
 */
typedef struct {
  ScopeDictDictItem sv_var;
  dict_T sv_dict;
} scriptvar_T;

static garray_T ga_scripts = {0, 0, sizeof(scriptvar_T *), 4, NULL};
#define SCRIPT_SV(id) (((scriptvar_T **)ga_scripts.ga_data)[(id) - 1])
#define SCRIPT_VARS(id) (SCRIPT_SV(id)->sv_dict.dv_hashtab)

static int echo_attr = 0;   /* attributes used for ":echo" */

// flags used in uf_flags
#define FC_ABORT    0x01          // abort function on error
#define FC_RANGE    0x02          // function accepts range
#define FC_DICT     0x04          // Dict function, uses "self"
#define FC_CLOSURE  0x08          // closure, uses outer scope variables
#define FC_DELETED  0x10          // :delfunction used while uf_refcount > 0
#define FC_REMOVED  0x20          // function redefined while uf_refcount > 0
#define FC_SANDBOX  0x40          // function defined in the sandbox

// The names of packages that once were loaded are remembered.
static garray_T ga_loaded = { 0, 0, sizeof(char_u *), 4, NULL };

#define FUNCARG(fp, j)  ((char_u **)(fp->uf_args.ga_data))[j]
#define FUNCLINE(fp, j) ((char_u **)(fp->uf_lines.ga_data))[j]

/// Short variable name length
#define VAR_SHORT_LEN 20
/// Number of fixed variables used for arguments
#define FIXVAR_CNT 12

struct funccall_S {
  ufunc_T *func;  ///< Function being called.
  int linenr;  ///< Next line to be executed.
  int returned;  ///< ":return" used.
  /// Fixed variables for arguments.
  TV_DICTITEM_STRUCT(VAR_SHORT_LEN + 1) fixvar[FIXVAR_CNT];
  dict_T l_vars;  ///< l: local function variables.
  ScopeDictDictItem l_vars_var;  ///< Variable for l: scope.
  dict_T l_avars;  ///< a: argument variables.
  ScopeDictDictItem l_avars_var;  ///< Variable for a: scope.
  list_T l_varlist;  ///< List for a:000.
  listitem_T l_listitems[MAX_FUNC_ARGS];  ///< List items for a:000.
  typval_T *rettv;  ///< Return value.
  linenr_T breakpoint;  ///< Next line with breakpoint or zero.
  int dbg_tick;  ///< Debug_tick when breakpoint was set.
  int level;  ///< Top nesting level of executed function.
  proftime_T prof_child;  ///< Time spent in a child.
  funccall_T *caller;  ///< Calling function or NULL.
  int fc_refcount;  ///< Number of user functions that reference this funccall.
  int fc_copyID;  ///< CopyID used for garbage collection.
  garray_T fc_funcs;  ///< List of ufunc_T* which keep a reference to "func".
};

/*
 * Info used by a ":for" loop.
 */
typedef struct {
  int fi_semicolon;             /* TRUE if ending in '; var]' */
  int fi_varcount;              /* nr of variables in the list */
  listwatch_T fi_lw;            /* keep an eye on the item used. */
  list_T      *fi_list;         /* list being used */
} forinfo_T;

/* values for vv_flags: */
#define VV_COMPAT       1       /* compatible, also used without "v:" */
#define VV_RO           2       /* read-only */
#define VV_RO_SBX       4       /* read-only in the sandbox */

#define VV(idx, name, type, flags) \
  [idx] = { \
    .vv_name = name, \
    .vv_di = { \
      .di_tv = { .v_type = type }, \
      .di_flags = 0, \
      .di_key = { 0 }, \
    }, \
    .vv_flags = flags, \
  }

// Array to hold the value of v: variables.
// The value is in a dictitem, so that it can also be used in the v: scope.
// The reason to use this table anyway is for very quick access to the
// variables with the VV_ defines.
static struct vimvar {
  char        *vv_name;  ///< Name of the variable, without v:.
  TV_DICTITEM_STRUCT(17) vv_di;  ///< Value and name for key (max 16 chars).
  char vv_flags;  ///< Flags: #VV_COMPAT, #VV_RO, #VV_RO_SBX.
} vimvars[] =
{
  // VV_ tails differing from upcased string literals:
  // VV_CC_FROM "charconvert_from"
  // VV_CC_TO "charconvert_to"
  // VV_SEND_SERVER "servername"
  // VV_REG "register"
  // VV_OP "operator"
  VV(VV_COUNT,          "count",            VAR_NUMBER, VV_RO),
  VV(VV_COUNT1,         "count1",           VAR_NUMBER, VV_RO),
  VV(VV_PREVCOUNT,      "prevcount",        VAR_NUMBER, VV_RO),
  VV(VV_ERRMSG,         "errmsg",           VAR_STRING, 0),
  VV(VV_WARNINGMSG,     "warningmsg",       VAR_STRING, 0),
  VV(VV_STATUSMSG,      "statusmsg",        VAR_STRING, 0),
  VV(VV_SHELL_ERROR,    "shell_error",      VAR_NUMBER, VV_RO),
  VV(VV_THIS_SESSION,   "this_session",     VAR_STRING, 0),
  VV(VV_VERSION,        "version",          VAR_NUMBER, VV_COMPAT+VV_RO),
  VV(VV_LNUM,           "lnum",             VAR_NUMBER, VV_RO_SBX),
  VV(VV_TERMRESPONSE,   "termresponse",     VAR_STRING, VV_RO),
  VV(VV_FNAME,          "fname",            VAR_STRING, VV_RO),
  VV(VV_LANG,           "lang",             VAR_STRING, VV_RO),
  VV(VV_LC_TIME,        "lc_time",          VAR_STRING, VV_RO),
  VV(VV_CTYPE,          "ctype",            VAR_STRING, VV_RO),
  VV(VV_CC_FROM,        "charconvert_from", VAR_STRING, VV_RO),
  VV(VV_CC_TO,          "charconvert_to",   VAR_STRING, VV_RO),
  VV(VV_FNAME_IN,       "fname_in",         VAR_STRING, VV_RO),
  VV(VV_FNAME_OUT,      "fname_out",        VAR_STRING, VV_RO),
  VV(VV_FNAME_NEW,      "fname_new",        VAR_STRING, VV_RO),
  VV(VV_FNAME_DIFF,     "fname_diff",       VAR_STRING, VV_RO),
  VV(VV_CMDARG,         "cmdarg",           VAR_STRING, VV_RO),
  VV(VV_FOLDSTART,      "foldstart",        VAR_NUMBER, VV_RO_SBX),
  VV(VV_FOLDEND,        "foldend",          VAR_NUMBER, VV_RO_SBX),
  VV(VV_FOLDDASHES,     "folddashes",       VAR_STRING, VV_RO_SBX),
  VV(VV_FOLDLEVEL,      "foldlevel",        VAR_NUMBER, VV_RO_SBX),
  VV(VV_PROGNAME,       "progname",         VAR_STRING, VV_RO),
  VV(VV_SEND_SERVER,    "servername",       VAR_STRING, VV_RO),
  VV(VV_DYING,          "dying",            VAR_NUMBER, VV_RO),
  VV(VV_EXCEPTION,      "exception",        VAR_STRING, VV_RO),
  VV(VV_THROWPOINT,     "throwpoint",       VAR_STRING, VV_RO),
  VV(VV_STDERR,         "stderr",           VAR_NUMBER, VV_RO),
  VV(VV_REG,            "register",         VAR_STRING, VV_RO),
  VV(VV_CMDBANG,        "cmdbang",          VAR_NUMBER, VV_RO),
  VV(VV_INSERTMODE,     "insertmode",       VAR_STRING, VV_RO),
  VV(VV_VAL,            "val",              VAR_UNKNOWN, VV_RO),
  VV(VV_KEY,            "key",              VAR_UNKNOWN, VV_RO),
  VV(VV_PROFILING,      "profiling",        VAR_NUMBER, VV_RO),
  VV(VV_FCS_REASON,     "fcs_reason",       VAR_STRING, VV_RO),
  VV(VV_FCS_CHOICE,     "fcs_choice",       VAR_STRING, 0),
  VV(VV_BEVAL_BUFNR,    "beval_bufnr",      VAR_NUMBER, VV_RO),
  VV(VV_BEVAL_WINNR,    "beval_winnr",      VAR_NUMBER, VV_RO),
  VV(VV_BEVAL_WINID,    "beval_winid",      VAR_NUMBER, VV_RO),
  VV(VV_BEVAL_LNUM,     "beval_lnum",       VAR_NUMBER, VV_RO),
  VV(VV_BEVAL_COL,      "beval_col",        VAR_NUMBER, VV_RO),
  VV(VV_BEVAL_TEXT,     "beval_text",       VAR_STRING, VV_RO),
  VV(VV_SCROLLSTART,    "scrollstart",      VAR_STRING, 0),
  VV(VV_SWAPNAME,       "swapname",         VAR_STRING, VV_RO),
  VV(VV_SWAPCHOICE,     "swapchoice",       VAR_STRING, 0),
  VV(VV_SWAPCOMMAND,    "swapcommand",      VAR_STRING, VV_RO),
  VV(VV_CHAR,           "char",             VAR_STRING, 0),
  VV(VV_MOUSE_WIN,      "mouse_win",        VAR_NUMBER, 0),
  VV(VV_MOUSE_WINID,    "mouse_winid",      VAR_NUMBER, 0),
  VV(VV_MOUSE_LNUM,     "mouse_lnum",       VAR_NUMBER, 0),
  VV(VV_MOUSE_COL,      "mouse_col",        VAR_NUMBER, 0),
  VV(VV_OP,             "operator",         VAR_STRING, VV_RO),
  VV(VV_SEARCHFORWARD,  "searchforward",    VAR_NUMBER, 0),
  VV(VV_HLSEARCH,       "hlsearch",         VAR_NUMBER, 0),
  VV(VV_OLDFILES,       "oldfiles",         VAR_LIST, 0),
  VV(VV_WINDOWID,       "windowid",         VAR_NUMBER, VV_RO_SBX),
  VV(VV_PROGPATH,       "progpath",         VAR_STRING, VV_RO),
  VV(VV_COMPLETED_ITEM, "completed_item",   VAR_DICT, VV_RO),
  VV(VV_OPTION_NEW,     "option_new",       VAR_STRING, VV_RO),
  VV(VV_OPTION_OLD,     "option_old",       VAR_STRING, VV_RO),
  VV(VV_OPTION_TYPE,    "option_type",      VAR_STRING, VV_RO),
  VV(VV_ERRORS,         "errors",           VAR_LIST, 0),
  VV(VV_MSGPACK_TYPES,  "msgpack_types",    VAR_DICT, VV_RO),
  VV(VV_EVENT,          "event",            VAR_DICT, VV_RO),
  VV(VV_FALSE,          "false",            VAR_SPECIAL, VV_RO),
  VV(VV_TRUE,           "true",             VAR_SPECIAL, VV_RO),
  VV(VV_NULL,           "null",             VAR_SPECIAL, VV_RO),
  VV(VV__NULL_LIST,     "_null_list",       VAR_LIST, VV_RO),
  VV(VV__NULL_DICT,     "_null_dict",       VAR_DICT, VV_RO),
  VV(VV_VIM_DID_ENTER,  "vim_did_enter",    VAR_NUMBER, VV_RO),
  VV(VV_TESTING,        "testing",          VAR_NUMBER, 0),
  VV(VV_TYPE_NUMBER,    "t_number",         VAR_NUMBER, VV_RO),
  VV(VV_TYPE_STRING,    "t_string",         VAR_NUMBER, VV_RO),
  VV(VV_TYPE_FUNC,      "t_func",           VAR_NUMBER, VV_RO),
  VV(VV_TYPE_LIST,      "t_list",           VAR_NUMBER, VV_RO),
  VV(VV_TYPE_DICT,      "t_dict",           VAR_NUMBER, VV_RO),
  VV(VV_TYPE_FLOAT,     "t_float",          VAR_NUMBER, VV_RO),
  VV(VV_TYPE_BOOL,      "t_bool",           VAR_NUMBER, VV_RO),
  VV(VV_ECHOSPACE,      "echospace",        VAR_NUMBER, VV_RO),
  VV(VV_EXITING,        "exiting",          VAR_NUMBER, VV_RO),
  VV(VV_LUA,            "lua",              VAR_PARTIAL, VV_RO),
};
#undef VV

/* shorthand */
#define vv_type         vv_di.di_tv.v_type
#define vv_nr           vv_di.di_tv.vval.v_number
#define vv_special      vv_di.di_tv.vval.v_special
#define vv_float        vv_di.di_tv.vval.v_float
#define vv_str          vv_di.di_tv.vval.v_string
#define vv_list         vv_di.di_tv.vval.v_list
#define vv_dict         vv_di.di_tv.vval.v_dict
#define vv_partial      vv_di.di_tv.vval.v_partial
#define vv_tv           vv_di.di_tv

/// Variable used for v:
static ScopeDictDictItem vimvars_var;

static partial_T *vvlua_partial;

/// v: hashtab
#define vimvarht  vimvardict.dv_hashtab

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval.c.generated.h"
#endif

static uint64_t last_timer_id = 1;
static PMap(uint64_t) *timers = NULL;

static const char *const msgpack_type_names[] = {
  [kMPNil] = "nil",
  [kMPBoolean] = "boolean",
  [kMPInteger] = "integer",
  [kMPFloat] = "float",
  [kMPString] = "string",
  [kMPBinary] = "binary",
  [kMPArray] = "array",
  [kMPMap] = "map",
  [kMPExt] = "ext",
};
const list_T *eval_msgpack_type_lists[] = {
  [kMPNil] = NULL,
  [kMPBoolean] = NULL,
  [kMPInteger] = NULL,
  [kMPFloat] = NULL,
  [kMPString] = NULL,
  [kMPBinary] = NULL,
  [kMPArray] = NULL,
  [kMPMap] = NULL,
  [kMPExt] = NULL,
};

// Return "n1" divided by "n2", taking care of dividing by zero.
varnumber_T num_divide(varnumber_T n1, varnumber_T n2)
  FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  varnumber_T result;

  if (n2 == 0) {  // give an error message?
    if (n1 == 0) {
      result = VARNUMBER_MIN;  // similar to NaN
    } else if (n1 < 0) {
      result = -VARNUMBER_MAX;
    } else {
      result = VARNUMBER_MAX;
    }
  } else {
    result = n1 / n2;
  }

  return result;
}

// Return "n1" modulus "n2", taking care of dividing by zero.
varnumber_T num_modulus(varnumber_T n1, varnumber_T n2)
  FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  // Give an error when n2 is 0?
  return (n2 == 0) ? 0 : (n1 % n2);
}

/*
 * Initialize the global and v: variables.
 */
void eval_init(void)
{
  vimvars[VV_VERSION].vv_nr = VIM_VERSION_100;

  timers = pmap_new(uint64_t)();
  struct vimvar   *p;

  init_var_dict(&globvardict, &globvars_var, VAR_DEF_SCOPE);
  init_var_dict(&vimvardict, &vimvars_var, VAR_SCOPE);
  vimvardict.dv_lock = VAR_FIXED;
  hash_init(&compat_hashtab);
  hash_init(&func_hashtab);

  for (size_t i = 0; i < ARRAY_SIZE(vimvars); i++) {
    p = &vimvars[i];
    assert(STRLEN(p->vv_name) <= 16);
    STRCPY(p->vv_di.di_key, p->vv_name);
    if (p->vv_flags & VV_RO)
      p->vv_di.di_flags = DI_FLAGS_RO | DI_FLAGS_FIX;
    else if (p->vv_flags & VV_RO_SBX)
      p->vv_di.di_flags = DI_FLAGS_RO_SBX | DI_FLAGS_FIX;
    else
      p->vv_di.di_flags = DI_FLAGS_FIX;

    /* add to v: scope dict, unless the value is not always available */
    if (p->vv_type != VAR_UNKNOWN)
      hash_add(&vimvarht, p->vv_di.di_key);
    if (p->vv_flags & VV_COMPAT)
      /* add to compat scope dict */
      hash_add(&compat_hashtab, p->vv_di.di_key);
  }
  vimvars[VV_VERSION].vv_nr = VIM_VERSION_100;

  dict_T *const msgpack_types_dict = tv_dict_alloc();
  for (size_t i = 0; i < ARRAY_SIZE(msgpack_type_names); i++) {
    list_T *const type_list = tv_list_alloc(0);
    tv_list_set_lock(type_list, VAR_FIXED);
    tv_list_ref(type_list);
    dictitem_T *const di = tv_dict_item_alloc(msgpack_type_names[i]);
    di->di_flags |= DI_FLAGS_RO|DI_FLAGS_FIX;
    di->di_tv = (typval_T) {
      .v_type = VAR_LIST,
      .vval = { .v_list = type_list, },
    };
    eval_msgpack_type_lists[i] = type_list;
    if (tv_dict_add(msgpack_types_dict, di) == FAIL) {
      // There must not be duplicate items in this dictionary by definition.
      assert(false);
    }
  }
  msgpack_types_dict->dv_lock = VAR_FIXED;

  set_vim_var_dict(VV_MSGPACK_TYPES, msgpack_types_dict);
  set_vim_var_dict(VV_COMPLETED_ITEM, tv_dict_alloc());

  dict_T *v_event = tv_dict_alloc();
  v_event->dv_lock = VAR_FIXED;
  set_vim_var_dict(VV_EVENT, v_event);
  set_vim_var_list(VV_ERRORS, tv_list_alloc(kListLenUnknown));
  set_vim_var_nr(VV_STDERR,   CHAN_STDERR);
  set_vim_var_nr(VV_SEARCHFORWARD, 1L);
  set_vim_var_nr(VV_HLSEARCH, 1L);
  set_vim_var_nr(VV_COUNT1, 1);
  set_vim_var_nr(VV_TYPE_NUMBER, VAR_TYPE_NUMBER);
  set_vim_var_nr(VV_TYPE_STRING, VAR_TYPE_STRING);
  set_vim_var_nr(VV_TYPE_FUNC,   VAR_TYPE_FUNC);
  set_vim_var_nr(VV_TYPE_LIST,   VAR_TYPE_LIST);
  set_vim_var_nr(VV_TYPE_DICT,   VAR_TYPE_DICT);
  set_vim_var_nr(VV_TYPE_FLOAT,  VAR_TYPE_FLOAT);
  set_vim_var_nr(VV_TYPE_BOOL,   VAR_TYPE_BOOL);

  set_vim_var_special(VV_FALSE, kSpecialVarFalse);
  set_vim_var_special(VV_TRUE, kSpecialVarTrue);
  set_vim_var_special(VV_NULL, kSpecialVarNull);
  set_vim_var_special(VV_EXITING, kSpecialVarNull);

  set_vim_var_nr(VV_ECHOSPACE,    sc_col - 1);

  vimvars[VV_LUA].vv_type = VAR_PARTIAL;
  vvlua_partial = xcalloc(1, sizeof(partial_T));
  vimvars[VV_LUA].vv_partial = vvlua_partial;
  // this value shouldn't be printed, but if it is, do not crash
  vvlua_partial->pt_name = xmallocz(0);
  vvlua_partial->pt_refcount++;

  set_reg_var(0);  // default for v:register is not 0 but '"'
}

#if defined(EXITFREE)
void eval_clear(void)
{
  struct vimvar   *p;

  for (size_t i = 0; i < ARRAY_SIZE(vimvars); i++) {
    p = &vimvars[i];
    if (p->vv_di.di_tv.v_type == VAR_STRING) {
      XFREE_CLEAR(p->vv_str);
    } else if (p->vv_di.di_tv.v_type == VAR_LIST) {
      tv_list_unref(p->vv_list);
      p->vv_list = NULL;
    }
  }
  hash_clear(&vimvarht);
  hash_init(&vimvarht);    /* garbage_collect() will access it */
  hash_clear(&compat_hashtab);

  free_scriptnames();
  free_locales();

  /* global variables */
  vars_clear(&globvarht);

  /* autoloaded script names */
  ga_clear_strings(&ga_loaded);

  /* Script-local variables. First clear all the variables and in a second
   * loop free the scriptvar_T, because a variable in one script might hold
   * a reference to the whole scope of another script. */
  for (int i = 1; i <= ga_scripts.ga_len; ++i)
    vars_clear(&SCRIPT_VARS(i));
  for (int i = 1; i <= ga_scripts.ga_len; ++i)
    xfree(SCRIPT_SV(i));
  ga_clear(&ga_scripts);

  // unreferenced lists and dicts
  (void)garbage_collect(false);

  // functions
  free_all_functions();
}

#endif

/*
 * Return the name of the executed function.
 */
char_u *func_name(void *cookie)
{
  return ((funccall_T *)cookie)->func->uf_name;
}

/*
 * Return the address holding the next breakpoint line for a funccall cookie.
 */
linenr_T *func_breakpoint(void *cookie)
{
  return &((funccall_T *)cookie)->breakpoint;
}

/*
 * Return the address holding the debug tick for a funccall cookie.
 */
int *func_dbg_tick(void *cookie)
{
  return &((funccall_T *)cookie)->dbg_tick;
}

/*
 * Return the nesting level for a funccall cookie.
 */
int func_level(void *cookie)
{
  return ((funccall_T *)cookie)->level;
}

/* pointer to funccal for currently active function */
funccall_T *current_funccal = NULL;

// Pointer to list of previously used funccal, still around because some
// item in it is still being used.
funccall_T *previous_funccal = NULL;

/*
 * Return TRUE when a function was ended by a ":return" command.
 */
int current_func_returned(void)
{
  return current_funccal->returned;
}

/*
 * Set an internal variable to a string value. Creates the variable if it does
 * not already exist.
 */
void set_internal_string_var(char_u *name, char_u *value)
{
  const typval_T tv = {
    .v_type = VAR_STRING,
    .vval.v_string = value,
  };

  set_var((const char *)name, STRLEN(name), (typval_T *)&tv, true);
}

static lval_T   *redir_lval = NULL;
static garray_T redir_ga;  // Only valid when redir_lval is not NULL.
static char_u *redir_endp = NULL;
static char_u   *redir_varname = NULL;

/*
 * Start recording command output to a variable
 * Returns OK if successfully completed the setup.  FAIL otherwise.
 */
int
var_redir_start(
    char_u *name,
    int append                     /* append to an existing variable */
)
{
  int save_emsg;
  int err;
  typval_T tv;

  /* Catch a bad name early. */
  if (!eval_isnamec1(*name)) {
    EMSG(_(e_invarg));
    return FAIL;
  }

  /* Make a copy of the name, it is used in redir_lval until redir ends. */
  redir_varname = vim_strsave(name);

  redir_lval = xcalloc(1, sizeof(lval_T));

  /* The output is stored in growarray "redir_ga" until redirection ends. */
  ga_init(&redir_ga, (int)sizeof(char), 500);

  // Parse the variable name (can be a dict or list entry).
  redir_endp = (char_u *)get_lval(redir_varname, NULL, redir_lval, false, false,
                                  0, FNE_CHECK_START);
  if (redir_endp == NULL || redir_lval->ll_name == NULL
      || *redir_endp != NUL) {
    clear_lval(redir_lval);
    if (redir_endp != NULL && *redir_endp != NUL)
      /* Trailing characters are present after the variable name */
      EMSG(_(e_trailing));
    else
      EMSG(_(e_invarg));
    redir_endp = NULL;      /* don't store a value, only cleanup */
    var_redir_stop();
    return FAIL;
  }

  /* check if we can write to the variable: set it to or append an empty
   * string */
  save_emsg = did_emsg;
  did_emsg = FALSE;
  tv.v_type = VAR_STRING;
  tv.vval.v_string = (char_u *)"";
  if (append) {
    set_var_lval(redir_lval, redir_endp, &tv, true, false, (char_u *)".");
  } else {
    set_var_lval(redir_lval, redir_endp, &tv, true, false, (char_u *)"=");
  }
  clear_lval(redir_lval);
  err = did_emsg;
  did_emsg |= save_emsg;
  if (err) {
    redir_endp = NULL;      /* don't store a value, only cleanup */
    var_redir_stop();
    return FAIL;
  }

  return OK;
}

/*
 * Append "value[value_len]" to the variable set by var_redir_start().
 * The actual appending is postponed until redirection ends, because the value
 * appended may in fact be the string we write to, changing it may cause freed
 * memory to be used:
 *   :redir => foo
 *   :let foo
 *   :redir END
 */
void var_redir_str(char_u *value, int value_len)
{
  int len;

  if (redir_lval == NULL)
    return;

  if (value_len == -1)
    len = (int)STRLEN(value);           /* Append the entire string */
  else
    len = value_len;                    /* Append only "value_len" characters */

  ga_grow(&redir_ga, len);
  memmove((char *)redir_ga.ga_data + redir_ga.ga_len, value, len);
  redir_ga.ga_len += len;
}

/*
 * Stop redirecting command output to a variable.
 * Frees the allocated memory.
 */
void var_redir_stop(void)
{
  typval_T tv;

  if (redir_lval != NULL) {
    /* If there was no error: assign the text to the variable. */
    if (redir_endp != NULL) {
      ga_append(&redir_ga, NUL);        /* Append the trailing NUL. */
      tv.v_type = VAR_STRING;
      tv.vval.v_string = redir_ga.ga_data;
      // Call get_lval() again, if it's inside a Dict or List it may
      // have changed.
      redir_endp = (char_u *)get_lval(redir_varname, NULL, redir_lval,
                                      false, false, 0, FNE_CHECK_START);
      if (redir_endp != NULL && redir_lval->ll_name != NULL) {
        set_var_lval(redir_lval, redir_endp, &tv, false, false, (char_u *)".");
      }
      clear_lval(redir_lval);
    }

    // free the collected output
    XFREE_CLEAR(redir_ga.ga_data);

    XFREE_CLEAR(redir_lval);
  }
  XFREE_CLEAR(redir_varname);
}

int eval_charconvert(const char *const enc_from, const char *const enc_to,
                     const char *const fname_from, const char *const fname_to)
{
  bool err = false;

  set_vim_var_string(VV_CC_FROM, enc_from, -1);
  set_vim_var_string(VV_CC_TO, enc_to, -1);
  set_vim_var_string(VV_FNAME_IN, fname_from, -1);
  set_vim_var_string(VV_FNAME_OUT, fname_to, -1);
  if (eval_to_bool(p_ccv, &err, NULL, false)) {
    err = true;
  }
  set_vim_var_string(VV_CC_FROM, NULL, -1);
  set_vim_var_string(VV_CC_TO, NULL, -1);
  set_vim_var_string(VV_FNAME_IN, NULL, -1);
  set_vim_var_string(VV_FNAME_OUT, NULL, -1);

  if (err) {
    return FAIL;
  }
  return OK;
}

int eval_printexpr(const char *const fname, const char *const args)
{
  bool err = false;

  set_vim_var_string(VV_FNAME_IN, fname, -1);
  set_vim_var_string(VV_CMDARG, args, -1);
  if (eval_to_bool(p_pexpr, &err, NULL, false)) {
    err = true;
  }
  set_vim_var_string(VV_FNAME_IN, NULL, -1);
  set_vim_var_string(VV_CMDARG, NULL, -1);

  if (err) {
    os_remove(fname);
    return FAIL;
  }
  return OK;
}

void eval_diff(const char *const origfile, const char *const newfile,
               const char *const outfile)
{
  bool err = false;

  set_vim_var_string(VV_FNAME_IN, origfile, -1);
  set_vim_var_string(VV_FNAME_NEW, newfile, -1);
  set_vim_var_string(VV_FNAME_OUT, outfile, -1);
  (void)eval_to_bool(p_dex, &err, NULL, FALSE);
  set_vim_var_string(VV_FNAME_IN, NULL, -1);
  set_vim_var_string(VV_FNAME_NEW, NULL, -1);
  set_vim_var_string(VV_FNAME_OUT, NULL, -1);
}

void eval_patch(const char *const origfile, const char *const difffile,
                const char *const outfile)
{
  bool err = false;

  set_vim_var_string(VV_FNAME_IN, origfile, -1);
  set_vim_var_string(VV_FNAME_DIFF, difffile, -1);
  set_vim_var_string(VV_FNAME_OUT, outfile, -1);
  (void)eval_to_bool(p_pex, &err, NULL, FALSE);
  set_vim_var_string(VV_FNAME_IN, NULL, -1);
  set_vim_var_string(VV_FNAME_DIFF, NULL, -1);
  set_vim_var_string(VV_FNAME_OUT, NULL, -1);
}

/*
 * Top level evaluation function, returning a boolean.
 * Sets "error" to TRUE if there was an error.
 * Return TRUE or FALSE.
 */
int
eval_to_bool(
    char_u *arg,
    bool *error,
    char_u **nextcmd,
    int skip                   /* only parse, don't execute */
)
{
  typval_T tv;
  bool retval = false;

  if (skip) {
    emsg_skip++;
  }
  if (eval0(arg, &tv, nextcmd, !skip) == FAIL) {
    *error = true;
  } else {
    *error = false;
    if (!skip) {
      retval = (tv_get_number_chk(&tv, error) != 0);
      tv_clear(&tv);
    }
  }
  if (skip) {
    emsg_skip--;
  }

  return retval;
}

// Call eval1() and give an error message if not done at a lower level.
static int eval1_emsg(char_u **arg, typval_T *rettv, bool evaluate)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  const char_u *const start = *arg;
  const int did_emsg_before = did_emsg;
  const int called_emsg_before = called_emsg;

  const int ret = eval1(arg, rettv, evaluate);
  if (ret == FAIL) {
    // Report the invalid expression unless the expression evaluation has
    // been cancelled due to an aborting error, an interrupt, or an
    // exception, or we already gave a more specific error.
    // Also check called_emsg for when using assert_fails().
    if (!aborting()
        && did_emsg == did_emsg_before
        && called_emsg == called_emsg_before) {
      emsgf(_(e_invexpr2), start);
    }
  }
  return ret;
}

int eval_expr_typval(const typval_T *expr, typval_T *argv,
                     int argc, typval_T *rettv)
  FUNC_ATTR_NONNULL_ARG(1, 2, 4)
{
  int dummy;

  if (expr->v_type == VAR_FUNC) {
    const char_u *const s = expr->vval.v_string;
    if (s == NULL || *s == NUL) {
      return FAIL;
    }
    if (call_func(s, (int)STRLEN(s), rettv, argc, argv, NULL,
                  0L, 0L, &dummy, true, NULL, NULL) == FAIL) {
      return FAIL;
    }
  } else if (expr->v_type == VAR_PARTIAL) {
    partial_T *const partial = expr->vval.v_partial;
    const char_u *const s = partial_name(partial);
    if (s == NULL || *s == NUL) {
      return FAIL;
    }
    if (call_func(s, (int)STRLEN(s), rettv, argc, argv, NULL,
                  0L, 0L, &dummy, true, partial, NULL) == FAIL) {
      return FAIL;
    }
  } else {
    char buf[NUMBUFLEN];
    char_u *s = (char_u *)tv_get_string_buf_chk(expr, buf);
    if (s == NULL) {
      return FAIL;
    }
    s = skipwhite(s);
    if (eval1_emsg(&s, rettv, true) == FAIL) {
      return FAIL;
    }
    if (*s != NUL) {  // check for trailing chars after expr
      tv_clear(rettv);
      emsgf(_(e_invexpr2), s);
      return FAIL;
    }
  }
  return OK;
}

/// Like eval_to_bool() but using a typval_T instead of a string.
/// Works for string, funcref and partial.
bool eval_expr_to_bool(const typval_T *expr, bool *error)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  typval_T argv, rettv;

  if (eval_expr_typval(expr, &argv, 0, &rettv) == FAIL) {
    *error = true;
    return false;
  }
  const bool res = (tv_get_number_chk(&rettv, error) != 0);
  tv_clear(&rettv);
  return res;
}

/// Top level evaluation function, returning a string
///
/// @param[in]  arg  String to evaluate.
/// @param  nextcmd  Pointer to the start of the next Ex command.
/// @param[in]  skip  If true, only do parsing to nextcmd without reporting
///                   errors or actually evaluating anything.
///
/// @return [allocated] string result of evaluation or NULL in case of error or
///                     when skipping.
char *eval_to_string_skip(const char *arg, const char **nextcmd,
                          const bool skip)
  FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_WARN_UNUSED_RESULT
{
  typval_T tv;
  char *retval;

  if (skip) {
    emsg_skip++;
  }
  if (eval0((char_u *)arg, &tv, (char_u **)nextcmd, !skip) == FAIL || skip) {
    retval = NULL;
  } else {
    retval = xstrdup(tv_get_string(&tv));
    tv_clear(&tv);
  }
  if (skip) {
    emsg_skip--;
  }

  return retval;
}

/*
 * Skip over an expression at "*pp".
 * Return FAIL for an error, OK otherwise.
 */
int skip_expr(char_u **pp)
{
  typval_T rettv;

  *pp = skipwhite(*pp);
  return eval1(pp, &rettv, FALSE);
}

/*
 * Top level evaluation function, returning a string.
 * When "convert" is TRUE convert a List into a sequence of lines and convert
 * a Float to a String.
 * Return pointer to allocated memory, or NULL for failure.
 */
char_u *eval_to_string(char_u *arg, char_u **nextcmd, int convert)
{
  typval_T tv;
  char *retval;
  garray_T ga;

  if (eval0(arg, &tv, nextcmd, true) == FAIL) {
    retval = NULL;
  } else {
    if (convert && tv.v_type == VAR_LIST) {
      ga_init(&ga, (int)sizeof(char), 80);
      if (tv.vval.v_list != NULL) {
        tv_list_join(&ga, tv.vval.v_list, "\n");
        if (tv_list_len(tv.vval.v_list) > 0) {
          ga_append(&ga, NL);
        }
      }
      ga_append(&ga, NUL);
      retval = (char *)ga.ga_data;
    } else if (convert && tv.v_type == VAR_FLOAT) {
      char numbuf[NUMBUFLEN];
      vim_snprintf(numbuf, NUMBUFLEN, "%g", tv.vval.v_float);
      retval = xstrdup(numbuf);
    } else {
      retval = xstrdup(tv_get_string(&tv));
    }
    tv_clear(&tv);
  }

  return (char_u *)retval;
}

/*
 * Call eval_to_string() without using current local variables and using
 * textlock.  When "use_sandbox" is TRUE use the sandbox.
 */
char_u *eval_to_string_safe(char_u *arg, char_u **nextcmd, int use_sandbox)
{
  char_u      *retval;
  void        *save_funccalp;

  save_funccalp = save_funccal();
  if (use_sandbox)
    ++sandbox;
  ++textlock;
  retval = eval_to_string(arg, nextcmd, FALSE);
  if (use_sandbox)
    --sandbox;
  --textlock;
  restore_funccal(save_funccalp);
  return retval;
}

/*
 * Top level evaluation function, returning a number.
 * Evaluates "expr" silently.
 * Returns -1 for an error.
 */
varnumber_T eval_to_number(char_u *expr)
{
  typval_T rettv;
  varnumber_T retval;
  char_u      *p = skipwhite(expr);

  ++emsg_off;

  if (eval1(&p, &rettv, true) == FAIL) {
    retval = -1;
  } else {
    retval = tv_get_number_chk(&rettv, NULL);
    tv_clear(&rettv);
  }
  --emsg_off;

  return retval;
}


/*
 * Prepare v: variable "idx" to be used.
 * Save the current typeval in "save_tv".
 * When not used yet add the variable to the v: hashtable.
 */
static void prepare_vimvar(int idx, typval_T *save_tv)
{
  *save_tv = vimvars[idx].vv_tv;
  if (vimvars[idx].vv_type == VAR_UNKNOWN)
    hash_add(&vimvarht, vimvars[idx].vv_di.di_key);
}

/*
 * Restore v: variable "idx" to typeval "save_tv".
 * When no longer defined, remove the variable from the v: hashtable.
 */
static void restore_vimvar(int idx, typval_T *save_tv)
{
  hashitem_T  *hi;

  vimvars[idx].vv_tv = *save_tv;
  if (vimvars[idx].vv_type == VAR_UNKNOWN) {
    hi = hash_find(&vimvarht, vimvars[idx].vv_di.di_key);
    if (HASHITEM_EMPTY(hi)) {
      internal_error("restore_vimvar()");
    } else {
      hash_remove(&vimvarht, hi);
    }
  }
}

/// If there is a window for "curbuf", make it the current window.
void find_win_for_curbuf(void)
{
  for (wininfo_T *wip = curbuf->b_wininfo; wip != NULL; wip = wip->wi_next) {
    if (wip->wi_win != NULL) {
      curwin = wip->wi_win;
      break;
    }
  }
}

/*
 * Evaluate an expression to a list with suggestions.
 * For the "expr:" part of 'spellsuggest'.
 * Returns NULL when there is an error.
 */
list_T *eval_spell_expr(char_u *badword, char_u *expr)
{
  typval_T save_val;
  typval_T rettv;
  list_T      *list = NULL;
  char_u      *p = skipwhite(expr);

  // Set "v:val" to the bad word.
  prepare_vimvar(VV_VAL, &save_val);
  vimvars[VV_VAL].vv_type = VAR_STRING;
  vimvars[VV_VAL].vv_str = badword;
  if (p_verbose == 0)
    ++emsg_off;

  if (eval1(&p, &rettv, true) == OK) {
    if (rettv.v_type != VAR_LIST) {
      tv_clear(&rettv);
    } else {
      list = rettv.vval.v_list;
    }
  }

  if (p_verbose == 0)
    --emsg_off;
  restore_vimvar(VV_VAL, &save_val);

  return list;
}

/// Get spell word from an entry from spellsuggest=expr:
///
/// Entry in question is supposed to be a list (to be checked by the caller)
/// with two items: a word and a score represented as an unsigned number
/// (whether it actually is unsigned is not checked).
///
/// Used to get the good word and score from the eval_spell_expr() result.
///
/// @param[in]  list  List to get values from.
/// @param[out]  ret_word  Suggested word. Not initialized if return value is
///                        -1.
///
/// @return -1 in case of error, score otherwise.
int get_spellword(list_T *const list, const char **ret_word)
{
  if (tv_list_len(list) != 2) {
    EMSG(_("E5700: Expression from 'spellsuggest' must yield lists with "
           "exactly two values"));
    return -1;
  }
  *ret_word = tv_list_find_str(list, 0);
  if (*ret_word == NULL) {
    return -1;
  }
  return tv_list_find_nr(list, -1, NULL);
}


// Call some vim script function and return the result in "*rettv".
// Uses argv[0] to argv[argc-1] for the function arguments. argv[argc]
// should have type VAR_UNKNOWN.
//
// Return OK or FAIL.
int call_vim_function(
    const char_u *func,
    int argc,
    typval_T *argv,
    typval_T *rettv
)
  FUNC_ATTR_NONNULL_ALL
{
  int doesrange;
  int ret;
  int len = (int)STRLEN(func);
  partial_T *pt = NULL;

  if (len >= 6 && !memcmp(func, "v:lua.", 6)) {
    func += 6;
    len = check_luafunc_name((const char *)func, false);
    if (len == 0) {
      ret = FAIL;
      goto fail;
    }
    pt = vvlua_partial;
  }

  rettv->v_type = VAR_UNKNOWN;  // tv_clear() uses this.
  ret = call_func(func, len, rettv, argc, argv, NULL,
                  curwin->w_cursor.lnum, curwin->w_cursor.lnum,
                  &doesrange, true, pt, NULL);

fail:
  if (ret == FAIL) {
    tv_clear(rettv);
  }

  return ret;
}
/// Call Vim script function and return the result as a number
///
/// @param[in]  func  Function name.
/// @param[in]  argc  Number of arguments.
/// @param[in]  argv  Array with typval_T arguments.
///
/// @return -1 when calling function fails, result of function otherwise.
varnumber_T call_func_retnr(const char_u *func, int argc,
                            typval_T *argv)
  FUNC_ATTR_NONNULL_ALL
{
  typval_T rettv;
  varnumber_T retval;

  if (call_vim_function(func, argc, argv, &rettv) == FAIL) {
    return -1;
  }
  retval = tv_get_number_chk(&rettv, NULL);
  tv_clear(&rettv);
  return retval;
}
/// Call Vim script function and return the result as a string
///
/// @param[in]  func  Function name.
/// @param[in]  argc  Number of arguments.
/// @param[in]  argv  Array with typval_T arguments.
///
/// @return [allocated] NULL when calling function fails, allocated string
///                     otherwise.
char *call_func_retstr(const char *const func, int argc,
                       typval_T *argv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_MALLOC
{
  typval_T rettv;
  // All arguments are passed as strings, no conversion to number.
  if (call_vim_function((const char_u *)func, argc, argv, &rettv)
      == FAIL) {
    return NULL;
  }

  char *const retval = xstrdup(tv_get_string(&rettv));
  tv_clear(&rettv);
  return retval;
}
/// Call Vim script function and return the result as a List
///
/// @param[in]  func  Function name.
/// @param[in]  argc  Number of arguments.
/// @param[in]  argv  Array with typval_T arguments.
///
/// @return [allocated] NULL when calling function fails or return tv is not a
///                     List, allocated List otherwise.
void *call_func_retlist(const char_u *func, int argc, typval_T *argv)
  FUNC_ATTR_NONNULL_ALL
{
  typval_T rettv;

  // All arguments are passed as strings, no conversion to number.
  if (call_vim_function(func, argc, argv, &rettv) == FAIL) {
    return NULL;
  }

  if (rettv.v_type != VAR_LIST) {
    tv_clear(&rettv);
    return NULL;
  }

  return rettv.vval.v_list;
}

/*
 * Save the current function call pointer, and set it to NULL.
 * Used when executing autocommands and for ":source".
 */
void *save_funccal(void)
{
  funccall_T *fc = current_funccal;

  current_funccal = NULL;
  return (void *)fc;
}

void restore_funccal(void *vfc)
{
  funccall_T *fc = (funccall_T *)vfc;

  current_funccal = fc;
}

/*
 * Prepare profiling for entering a child or something else that is not
 * counted for the script/function itself.
 * Should always be called in pair with prof_child_exit().
 */
void prof_child_enter(proftime_T *tm /* place to store waittime */
                      )
{
  funccall_T *fc = current_funccal;

  if (fc != NULL && fc->func->uf_profiling) {
    fc->prof_child = profile_start();
  }

  script_prof_save(tm);
}

/*
 * Take care of time spent in a child.
 * Should always be called after prof_child_enter().
 */
void prof_child_exit(proftime_T *tm /* where waittime was stored */
                     )
{
  funccall_T *fc = current_funccal;

  if (fc != NULL && fc->func->uf_profiling) {
    fc->prof_child = profile_end(fc->prof_child);
    // don't count waiting time
    fc->prof_child = profile_sub_wait(*tm, fc->prof_child);
    fc->func->uf_tm_children =
      profile_add(fc->func->uf_tm_children, fc->prof_child);
    fc->func->uf_tml_children =
      profile_add(fc->func->uf_tml_children, fc->prof_child);
  }
  script_prof_restore(tm);
}


/*
 * Evaluate 'foldexpr'.  Returns the foldlevel, and any character preceding
 * it in "*cp".  Doesn't give error messages.
 */
int eval_foldexpr(char_u *arg, int *cp)
{
  typval_T tv;
  varnumber_T retval;
  char_u      *s;
  int use_sandbox = was_set_insecurely((char_u *)"foldexpr",
      OPT_LOCAL);

  ++emsg_off;
  if (use_sandbox)
    ++sandbox;
  ++textlock;
  *cp = NUL;
  if (eval0(arg, &tv, NULL, TRUE) == FAIL)
    retval = 0;
  else {
    /* If the result is a number, just return the number. */
    if (tv.v_type == VAR_NUMBER)
      retval = tv.vval.v_number;
    else if (tv.v_type != VAR_STRING || tv.vval.v_string == NULL)
      retval = 0;
    else {
      /* If the result is a string, check if there is a non-digit before
       * the number. */
      s = tv.vval.v_string;
      if (!ascii_isdigit(*s) && *s != '-')
        *cp = *s++;
      retval = atol((char *)s);
    }
    tv_clear(&tv);
  }
  --emsg_off;
  if (use_sandbox)
    --sandbox;
  --textlock;

  return (int)retval;
}

// ":cons[t] var = expr1" define constant
// ":cons[t] [name1, name2, ...] = expr1" define constants unpacking list
// ":cons[t] [name, ..., ; lastname] = expr" define constants unpacking list
void ex_const(exarg_T *eap)
{
  ex_let_const(eap, true);
}

// Get a list of lines from a HERE document. The here document is a list of
// lines surrounded by a marker.
//     cmd << {marker}
//       {line1}
//       {line2}
//       ....
//     {marker}
//
// The {marker} is a string. If the optional 'trim' word is supplied before the
// marker, then the leading indentation before the lines (matching the
// indentation in the 'cmd' line) is stripped.
// Returns a List with {lines} or NULL.
static list_T *
heredoc_get(exarg_T *eap, char_u *cmd)
{
  char_u *marker;
  char_u *p;
  int marker_indent_len = 0;
  int text_indent_len = 0;
  char_u *text_indent = NULL;

  if (eap->getline == NULL) {
    EMSG(_("E991: cannot use =<< here"));
    return NULL;
  }

  // Check for the optional 'trim' word before the marker
  cmd = skipwhite(cmd);
  if (STRNCMP(cmd, "trim", 4) == 0
      && (cmd[4] == NUL || ascii_iswhite(cmd[4]))) {
    cmd = skipwhite(cmd + 4);

    // Trim the indentation from all the lines in the here document.
    // The amount of indentation trimmed is the same as the indentation of
    // the first line after the :let command line.  To find the end marker
    // the indent of the :let command line is trimmed.
    p = *eap->cmdlinep;
    while (ascii_iswhite(*p)) {
      p++;
      marker_indent_len++;
    }
    text_indent_len = -1;
  }

  // The marker is the next word.
  if (*cmd != NUL && *cmd != '"') {
    marker = skipwhite(cmd);
    p = skiptowhite(marker);
    if (*skipwhite(p) != NUL && *skipwhite(p) != '"') {
      EMSG(_(e_trailing));
      return NULL;
    }
    *p = NUL;
    if (islower(*marker)) {
      EMSG(_("E221: Marker cannot start with lower case letter"));
      return NULL;
    }
  } else {
    EMSG(_("E172: Missing marker"));
    return NULL;
  }

  list_T *l = tv_list_alloc(0);
  for (;;) {
    int mi = 0;
    int ti = 0;

    char_u *theline = eap->getline(NUL, eap->cookie, 0, false);
    if (theline == NULL) {
      EMSG2(_("E990: Missing end marker '%s'"), marker);
      break;
    }

    // with "trim": skip the indent matching the :let line to find the
    // marker
    if (marker_indent_len > 0
        && STRNCMP(theline, *eap->cmdlinep, marker_indent_len) == 0) {
        mi = marker_indent_len;
    }
    if (STRCMP(marker, theline + mi) == 0) {
      xfree(theline);
      break;
    }
    if (text_indent_len == -1 && *theline != NUL) {
        // set the text indent from the first line.
        p = theline;
        text_indent_len = 0;
        while (ascii_iswhite(*p)) {
            p++;
            text_indent_len++;
        }
        text_indent = vim_strnsave(theline, text_indent_len);
    }
    // with "trim": skip the indent matching the first line
    if (text_indent != NULL) {
        for (ti = 0; ti < text_indent_len; ti++) {
            if (theline[ti] != text_indent[ti]) {
                break;
            }
        }
    }

    tv_list_append_string(l, (char *)(theline + ti), -1);
    xfree(theline);
  }
  xfree(text_indent);

  return l;
}

// ":let" list all variable values
// ":let var1 var2" list variable values
// ":let var = expr" assignment command.
// ":let var += expr" assignment command.
// ":let var -= expr" assignment command.
// ":let var *= expr" assignment command.
// ":let var /= expr" assignment command.
// ":let var %= expr" assignment command.
// ":let var .= expr" assignment command.
// ":let var ..= expr" assignment command.
// ":let [var1, var2] = expr" unpack list.
// ":let [name, ..., ; lastname] = expr" unpack list.
void ex_let(exarg_T *eap)
{
  ex_let_const(eap, false);
}

static void ex_let_const(exarg_T *eap, const bool is_const)
{
  char_u      *arg = eap->arg;
  char_u      *expr = NULL;
  typval_T rettv;
  int i;
  int var_count = 0;
  int semicolon = 0;
  char_u op[2];
  char_u      *argend;
  int first = TRUE;

  argend = (char_u *)skip_var_list(arg, &var_count, &semicolon);
  if (argend == NULL) {
    return;
  }
  if (argend > arg && argend[-1] == '.') {  // For var.='str'.
    argend--;
  }
  expr = skipwhite(argend);
  if (*expr != '=' && !((vim_strchr((char_u *)"+-*/%.", *expr) != NULL
                         && expr[1] == '=') || STRNCMP(expr, "..=", 3) == 0)) {
    // ":let" without "=": list variables
    if (*arg == '[') {
      EMSG(_(e_invarg));
    } else if (!ends_excmd(*arg)) {
      // ":let var1 var2"
      arg = (char_u *)list_arg_vars(eap, (const char *)arg, &first);
    } else if (!eap->skip) {
      // ":let"
      list_glob_vars(&first);
      list_buf_vars(&first);
      list_win_vars(&first);
      list_tab_vars(&first);
      list_script_vars(&first);
      list_func_vars(&first);
      list_vim_vars(&first);
    }
    eap->nextcmd = check_nextcmd(arg);
  } else if (expr[0] == '=' && expr[1] == '<' && expr[2] == '<') {
    // HERE document
    list_T *l = heredoc_get(eap, expr + 3);
    if (l != NULL) {
      tv_list_set_ret(&rettv, l);
      if (!eap->skip) {
        op[0] = '=';
        op[1] = NUL;
        (void)ex_let_vars(eap->arg, &rettv, false, semicolon, var_count,
                          is_const, op);
      }
      tv_clear(&rettv);
    }
  } else {
    op[0] = '=';
    op[1] = NUL;
    if (*expr != '=') {
      if (vim_strchr((char_u *)"+-*/%.", *expr) != NULL) {
        op[0] = *expr;  // +=, -=, *=, /=, %= or .=
        if (expr[0] == '.' && expr[1] == '.') {  // ..=
          expr++;
        }
      }
      expr = skipwhite(expr + 2);
    } else {
      expr = skipwhite(expr + 1);
    }

    if (eap->skip)
      ++emsg_skip;
    i = eval0(expr, &rettv, &eap->nextcmd, !eap->skip);
    if (eap->skip) {
      if (i != FAIL) {
        tv_clear(&rettv);
      }
      emsg_skip--;
    } else if (i != FAIL) {
      (void)ex_let_vars(eap->arg, &rettv, false, semicolon, var_count,
                        is_const, op);
      tv_clear(&rettv);
    }
  }
}

/*
 * Assign the typevalue "tv" to the variable or variables at "arg_start".
 * Handles both "var" with any type and "[var, var; var]" with a list type.
 * When "nextchars" is not NULL it points to a string with characters that
 * must appear after the variable(s).  Use "+", "-" or "." for add, subtract
 * or concatenate.
 * Returns OK or FAIL;
 */
static int
ex_let_vars(
    char_u *arg_start,
    typval_T *tv,
    int copy,                       // copy values from "tv", don't move
    int semicolon,                  // from skip_var_list()
    int var_count,                  // from skip_var_list()
    int is_const,                   // lock variables for :const
    char_u *nextchars
)
{
  char_u *arg = arg_start;
  typval_T ltv;

  if (*arg != '[') {
    /*
     * ":let var = expr" or ":for var in list"
     */
    if (ex_let_one(arg, tv, copy, is_const, nextchars, nextchars) == NULL) {
      return FAIL;
    }
    return OK;
  }

  // ":let [v1, v2] = list" or ":for [v1, v2] in listlist"
  if (tv->v_type != VAR_LIST) {
    EMSG(_(e_listreq));
    return FAIL;
  }
  list_T *const l = tv->vval.v_list;

  const int len = tv_list_len(l);
  if (semicolon == 0 && var_count < len) {
    EMSG(_("E687: Less targets than List items"));
    return FAIL;
  }
  if (var_count - semicolon > len) {
    EMSG(_("E688: More targets than List items"));
    return FAIL;
  }
  // List l may actually be NULL, but it should fail with E688 or even earlier
  // if you try to do ":let [] = v:_null_list".
  assert(l != NULL);

  listitem_T *item = tv_list_first(l);
  size_t rest_len = tv_list_len(l);
  while (*arg != ']') {
    arg = skipwhite(arg + 1);
    arg = ex_let_one(arg, TV_LIST_ITEM_TV(item), true, is_const,
                     (const char_u *)",;]", nextchars);
    if (arg == NULL) {
      return FAIL;
    }
    rest_len--;

    item = TV_LIST_ITEM_NEXT(l, item);
    arg = skipwhite(arg);
    if (*arg == ';') {
      /* Put the rest of the list (may be empty) in the var after ';'.
       * Create a new list for this. */
      list_T *const rest_list = tv_list_alloc(rest_len);
      while (item != NULL) {
        tv_list_append_tv(rest_list, TV_LIST_ITEM_TV(item));
        item = TV_LIST_ITEM_NEXT(l, item);
      }

      ltv.v_type = VAR_LIST;
      ltv.v_lock = VAR_UNLOCKED;
      ltv.vval.v_list = rest_list;
      tv_list_ref(rest_list);

      arg = ex_let_one(skipwhite(arg + 1), &ltv, false, is_const,
                       (char_u *)"]", nextchars);
      tv_clear(&ltv);
      if (arg == NULL) {
        return FAIL;
      }
      break;
    } else if (*arg != ',' && *arg != ']') {
      internal_error("ex_let_vars()");
      return FAIL;
    }
  }

  return OK;
}

/*
 * Skip over assignable variable "var" or list of variables "[var, var]".
 * Used for ":let varvar = expr" and ":for varvar in expr".
 * For "[var, var]" increment "*var_count" for each variable.
 * for "[var, var; var]" set "semicolon".
 * Return NULL for an error.
 */
static const char_u *skip_var_list(const char_u *arg, int *var_count,
                                   int *semicolon)
{
  const char_u *p;
  const char_u *s;

  if (*arg == '[') {
    /* "[var, var]": find the matching ']'. */
    p = arg;
    for (;; ) {
      p = skipwhite(p + 1);             /* skip whites after '[', ';' or ',' */
      s = skip_var_one(p);
      if (s == p) {
        EMSG2(_(e_invarg2), p);
        return NULL;
      }
      ++*var_count;

      p = skipwhite(s);
      if (*p == ']')
        break;
      else if (*p == ';') {
        if (*semicolon == 1) {
          EMSG(_("Double ; in list of variables"));
          return NULL;
        }
        *semicolon = 1;
      } else if (*p != ',') {
        EMSG2(_(e_invarg2), p);
        return NULL;
      }
    }
    return p + 1;
  } else
    return skip_var_one(arg);
}

/*
 * Skip one (assignable) variable name, including @r, $VAR, &option, d.key,
 * l[idx].
 */
static const char_u *skip_var_one(const char_u *arg)
{
  if (*arg == '@' && arg[1] != NUL)
    return arg + 2;
  return find_name_end(*arg == '$' || *arg == '&' ? arg + 1 : arg,
      NULL, NULL, FNE_INCL_BR | FNE_CHECK_START);
}

/*
 * List variables for hashtab "ht" with prefix "prefix".
 * If "empty" is TRUE also list NULL strings as empty strings.
 */
static void list_hashtable_vars(hashtab_T *ht, const char *prefix, int empty,
                                int *first)
{
  hashitem_T  *hi;
  dictitem_T  *di;
  int todo;

  todo = (int)ht->ht_used;
  for (hi = ht->ht_array; todo > 0 && !got_int; ++hi) {
    if (!HASHITEM_EMPTY(hi)) {
      todo--;
      di = TV_DICT_HI2DI(hi);
      char buf[IOSIZE];

      // apply :filter /pat/ to variable name
      xstrlcpy(buf, prefix, IOSIZE - 1);
      xstrlcat(buf, (char *)di->di_key, IOSIZE);
      if (message_filtered((char_u *)buf)) {
        continue;
      }

      if (empty || di->di_tv.v_type != VAR_STRING
          || di->di_tv.vval.v_string != NULL) {
        list_one_var(di, prefix, first);
      }
    }
  }
}

/*
 * List global variables.
 */
static void list_glob_vars(int *first)
{
  list_hashtable_vars(&globvarht, "", true, first);
}

/*
 * List buffer variables.
 */
static void list_buf_vars(int *first)
{
  list_hashtable_vars(&curbuf->b_vars->dv_hashtab, "b:", true, first);
}

/*
 * List window variables.
 */
static void list_win_vars(int *first)
{
  list_hashtable_vars(&curwin->w_vars->dv_hashtab, "w:", true, first);
}

/*
 * List tab page variables.
 */
static void list_tab_vars(int *first)
{
  list_hashtable_vars(&curtab->tp_vars->dv_hashtab, "t:", true, first);
}

/*
 * List Vim variables.
 */
static void list_vim_vars(int *first)
{
  list_hashtable_vars(&vimvarht, "v:", false, first);
}

// List script-local variables, if there is a script.
static void list_script_vars(int *first)
{
  if (current_sctx.sc_sid > 0 && current_sctx.sc_sid <= ga_scripts.ga_len) {
    list_hashtable_vars(&SCRIPT_VARS(current_sctx.sc_sid), "s:", false, first);
  }
}

/*
 * List function variables, if there is a function.
 */
static void list_func_vars(int *first)
{
  if (current_funccal != NULL) {
    list_hashtable_vars(&current_funccal->l_vars.dv_hashtab, "l:", false,
                        first);
  }
}

/*
 * List variables in "arg".
 */
static const char *list_arg_vars(exarg_T *eap, const char *arg, int *first)
{
  int error = FALSE;
  int len;
  const char *name;
  const char *name_start;
  typval_T tv;

  while (!ends_excmd(*arg) && !got_int) {
    if (error || eap->skip) {
      arg = (const char *)find_name_end((char_u *)arg, NULL, NULL,
                                        FNE_INCL_BR | FNE_CHECK_START);
      if (!ascii_iswhite(*arg) && !ends_excmd(*arg)) {
        emsg_severe = TRUE;
        EMSG(_(e_trailing));
        break;
      }
    } else {
      // get_name_len() takes care of expanding curly braces
      name_start = name = arg;
      char *tofree;
      len = get_name_len(&arg, &tofree, true, true);
      if (len <= 0) {
        /* This is mainly to keep test 49 working: when expanding
         * curly braces fails overrule the exception error message. */
        if (len < 0 && !aborting()) {
          emsg_severe = TRUE;
          EMSG2(_(e_invarg2), arg);
          break;
        }
        error = TRUE;
      } else {
        if (tofree != NULL) {
          name = tofree;
        }
        if (get_var_tv((const char *)name, len, &tv, NULL, true, false)
            == FAIL) {
          error = true;
        } else {
          // handle d.key, l[idx], f(expr)
          const char *const arg_subsc = arg;
          if (handle_subscript(&arg, &tv, true, true) == FAIL) {
            error = true;
          } else {
            if (arg == arg_subsc && len == 2 && name[1] == ':') {
              switch (*name) {
              case 'g': list_glob_vars(first); break;
              case 'b': list_buf_vars(first); break;
              case 'w': list_win_vars(first); break;
              case 't': list_tab_vars(first); break;
              case 'v': list_vim_vars(first); break;
              case 's': list_script_vars(first); break;
              case 'l': list_func_vars(first); break;
              default:
                EMSG2(_("E738: Can't list variables for %s"), name);
              }
            } else {
              char *const s = encode_tv2echo(&tv, NULL);
              const char *const used_name = (arg == arg_subsc
                                             ? name
                                             : name_start);
              const ptrdiff_t name_size = (used_name == tofree
                                           ? (ptrdiff_t)strlen(used_name)
                                           : (arg - used_name));
              list_one_var_a("", used_name, name_size,
                             tv.v_type, s == NULL ? "" : s, first);
              xfree(s);
            }
            tv_clear(&tv);
          }
        }
      }

      xfree(tofree);
    }

    arg = (const char *)skipwhite((const char_u *)arg);
  }

  return arg;
}

// TODO(ZyX-I): move to eval/ex_cmds

/// Set one item of `:let var = expr` or `:let [v1, v2] = list` to its value
///
/// @param[in]  arg  Start of the variable name.
/// @param[in]  tv  Value to assign to the variable.
/// @param[in]  copy  If true, copy value from `tv`.
/// @param[in]  endchars  Valid characters after variable name or NULL.
/// @param[in]  op  Operation performed: *op is `+`, `-`, `.` for `+=`, etc.
///                 NULL for `=`.
///
/// @return a pointer to the char just after the var name or NULL in case of
///         error.
static char_u *ex_let_one(char_u *arg, typval_T *const tv,
                          const bool copy, const bool is_const,
                          const char_u *const endchars, const char_u *const op)
  FUNC_ATTR_NONNULL_ARG(1, 2) FUNC_ATTR_WARN_UNUSED_RESULT
{
  char_u *arg_end = NULL;
  int len;
  int opt_flags;
  char_u *tofree = NULL;

  /*
   * ":let $VAR = expr": Set environment variable.
   */
  if (*arg == '$') {
    if (is_const) {
      EMSG(_("E996: Cannot lock an environment variable"));
      return NULL;
    }
    // Find the end of the name.
    arg++;
    char *name = (char *)arg;
    len = get_env_len((const char_u **)&arg);
    if (len == 0) {
      EMSG2(_(e_invarg2), name - 1);
    } else {
      if (op != NULL && vim_strchr((char_u *)"+-*/%", *op) != NULL) {
        EMSG2(_(e_letwrong), op);
      } else if (endchars != NULL
                 && vim_strchr(endchars, *skipwhite(arg)) == NULL) {
        EMSG(_(e_letunexp));
      } else if (!check_secure()) {
        const char c1 = name[len];
        name[len] = NUL;
        const char *p = tv_get_string_chk(tv);
        if (p != NULL && op != NULL && *op == '.') {
          char *s = vim_getenv(name);

          if (s != NULL) {
            tofree = concat_str((const char_u *)s, (const char_u *)p);
            p = (const char *)tofree;
            xfree(s);
          }
        }
        if (p != NULL) {
          os_setenv(name, p, 1);
          if (STRICMP(name, "HOME") == 0) {
            init_homedir();
          } else if (didset_vim && STRICMP(name, "VIM") == 0) {
            didset_vim = false;
          } else if (didset_vimruntime
                     && STRICMP(name, "VIMRUNTIME") == 0) {
            didset_vimruntime = false;
          }
          arg_end = arg;
        }
        name[len] = c1;
        xfree(tofree);
      }
    }
  // ":let &option = expr": Set option value.
  // ":let &l:option = expr": Set local option value.
  // ":let &g:option = expr": Set global option value.
  } else if (*arg == '&') {
    if (is_const) {
      EMSG(_("E996: Cannot lock an option"));
      return NULL;
    }
    // Find the end of the name.
    char *const p = (char *)find_option_end((const char **)&arg, &opt_flags);
    if (p == NULL
        || (endchars != NULL
            && vim_strchr(endchars, *skipwhite((const char_u *)p)) == NULL)) {
      EMSG(_(e_letunexp));
    } else {
      int opt_type;
      long numval;
      char *stringval = NULL;

      const char c1 = *p;
      *p = NUL;

      varnumber_T n = tv_get_number(tv);
      const char *s = tv_get_string_chk(tv);  // != NULL if number or string.
      if (s != NULL && op != NULL && *op != '=') {
        opt_type = get_option_value(arg, &numval, (char_u **)&stringval,
                                    opt_flags);
        if ((opt_type == 1 && *op == '.')
            || (opt_type == 0 && *op != '.')) {
          EMSG2(_(e_letwrong), op);
          s = NULL;  // don't set the value
        } else {
          if (opt_type == 1) {  // number
            switch (*op) {
              case '+': n = numval + n; break;
              case '-': n = numval - n; break;
              case '*': n = numval * n; break;
              case '/': n = num_divide(numval, n); break;
              case '%': n = num_modulus(numval, n); break;
            }
          } else if (opt_type == 0 && stringval != NULL) {  // string
            char *const oldstringval = stringval;
            stringval = (char *)concat_str((const char_u *)stringval,
                                           (const char_u *)s);
            xfree(oldstringval);
            s = stringval;
          }
        }
      }
      if (s != NULL) {
        set_option_value((const char *)arg, n, s, opt_flags);
        arg_end = (char_u *)p;
      }
      *p = c1;
      xfree(stringval);
    }
  // ":let @r = expr": Set register contents.
  } else if (*arg == '@') {
    if (is_const) {
      EMSG(_("E996: Cannot lock a register"));
      return NULL;
    }
    arg++;
    if (op != NULL && vim_strchr((char_u *)"+-*/%", *op) != NULL) {
      emsgf(_(e_letwrong), op);
    } else if (endchars != NULL
               && vim_strchr(endchars, *skipwhite(arg + 1)) == NULL) {
      EMSG(_(e_letunexp));
    } else {
      char_u      *s;

      char_u *ptofree = NULL;
      const char *p = tv_get_string_chk(tv);
      if (p != NULL && op != NULL && *op == '.') {
        s = get_reg_contents(*arg == '@' ? '"' : *arg, kGRegExprSrc);
        if (s != NULL) {
          ptofree = concat_str(s, (const char_u *)p);
          p = (const char *)ptofree;
          xfree(s);
        }
      }
      if (p != NULL) {
        write_reg_contents(*arg == '@' ? '"' : *arg,
                           (const char_u *)p, STRLEN(p), false);
        arg_end = arg + 1;
      }
      xfree(ptofree);
    }
  }
  /*
   * ":let var = expr": Set internal variable.
   * ":let {expr} = expr": Idem, name made with curly braces
   */
  else if (eval_isnamec1(*arg) || *arg == '{') {
    lval_T lv;

    char_u *const p = get_lval(arg, tv, &lv, false, false, 0, FNE_CHECK_START);
    if (p != NULL && lv.ll_name != NULL) {
      if (endchars != NULL && vim_strchr(endchars, *skipwhite(p)) == NULL) {
        EMSG(_(e_letunexp));
      } else {
        set_var_lval(&lv, p, tv, copy, is_const, op);
        arg_end = p;
      }
    }
    clear_lval(&lv);
  } else
    EMSG2(_(e_invarg2), arg);

  return arg_end;
}

// TODO(ZyX-I): move to eval/executor

/// Get an lvalue
///
/// Lvalue may be
/// - variable: "name", "na{me}"
/// - dictionary item: "dict.key", "dict['key']"
/// - list item: "list[expr]"
/// - list slice: "list[expr:expr]"
///
/// Indexing only works if trying to use it with an existing List or Dictionary.
///
/// @param[in]  name  Name to parse.
/// @param  rettv  Pointer to the value to be assigned or NULL.
/// @param[out]  lp  Lvalue definition. When evaluation errors occur `->ll_name`
///                  is NULL.
/// @param[in]  unlet  True if using `:unlet`. This results in slightly
///                    different behaviour when something is wrong; must end in
///                    space or cmd separator.
/// @param[in]  skip  True when skipping.
/// @param[in]  flags  @see GetLvalFlags.
/// @param[in]  fne_flags  Flags for find_name_end().
///
/// @return A pointer to just after the name, including indexes. Returns NULL
///         for a parsing error, but it is still needed to free items in lp.
char_u *get_lval(char_u *const name, typval_T *const rettv,
                 lval_T *const lp, const bool unlet, const bool skip,
                 const int flags, const int fne_flags)
  FUNC_ATTR_NONNULL_ARG(1, 3)
{
  dictitem_T  *v;
  typval_T var1;
  typval_T var2;
  int empty1 = FALSE;
  listitem_T  *ni;
  hashtab_T   *ht;
  int quiet = flags & GLV_QUIET;

  /* Clear everything in "lp". */
  memset(lp, 0, sizeof(lval_T));

  if (skip) {
    // When skipping just find the end of the name.
    lp->ll_name = (const char *)name;
    return (char_u *)find_name_end((const char_u *)name, NULL, NULL,
                                   FNE_INCL_BR | fne_flags);
  }

  // Find the end of the name.
  char_u *expr_start;
  char_u *expr_end;
  char_u *p = (char_u *)find_name_end(name,
                                      (const char_u **)&expr_start,
                                      (const char_u **)&expr_end,
                                      fne_flags);
  if (expr_start != NULL) {
    /* Don't expand the name when we already know there is an error. */
    if (unlet && !ascii_iswhite(*p) && !ends_excmd(*p)
        && *p != '[' && *p != '.') {
      EMSG(_(e_trailing));
      return NULL;
    }

    lp->ll_exp_name = (char *)make_expanded_name(name, expr_start, expr_end,
                                                 (char_u *)p);
    lp->ll_name = lp->ll_exp_name;
    if (lp->ll_exp_name == NULL) {
      /* Report an invalid expression in braces, unless the
       * expression evaluation has been cancelled due to an
       * aborting error, an interrupt, or an exception. */
      if (!aborting() && !quiet) {
        emsg_severe = TRUE;
        EMSG2(_(e_invarg2), name);
        return NULL;
      }
      lp->ll_name_len = 0;
    } else {
      lp->ll_name_len = strlen(lp->ll_name);
    }
  } else {
    lp->ll_name = (const char *)name;
    lp->ll_name_len = (size_t)((const char *)p - lp->ll_name);
  }

  // Without [idx] or .key we are done.
  if ((*p != '[' && *p != '.') || lp->ll_name == NULL) {
    return p;
  }

  // Only pass &ht when we would write to the variable, it prevents autoload
  // as well.
  v = find_var(lp->ll_name, lp->ll_name_len,
               (flags & GLV_READ_ONLY) ? NULL : &ht,
               flags & GLV_NO_AUTOLOAD);
  if (v == NULL && !quiet) {
    emsgf(_("E121: Undefined variable: %.*s"),
          (int)lp->ll_name_len, lp->ll_name);
  }
  if (v == NULL) {
    return NULL;
  }

  /*
   * Loop until no more [idx] or .key is following.
   */
  lp->ll_tv = &v->di_tv;
  var1.v_type = VAR_UNKNOWN;
  var2.v_type = VAR_UNKNOWN;
  while (*p == '[' || (*p == '.' && lp->ll_tv->v_type == VAR_DICT)) {
    if (!(lp->ll_tv->v_type == VAR_LIST && lp->ll_tv->vval.v_list != NULL)
        && !(lp->ll_tv->v_type == VAR_DICT
             && lp->ll_tv->vval.v_dict != NULL)) {
      if (!quiet)
        EMSG(_("E689: Can only index a List or Dictionary"));
      return NULL;
    }
    if (lp->ll_range) {
      if (!quiet)
        EMSG(_("E708: [:] must come last"));
      return NULL;
    }

    int len = -1;
    char_u *key = NULL;
    if (*p == '.') {
      key = p + 1;
      for (len = 0; ASCII_ISALNUM(key[len]) || key[len] == '_'; len++) {
      }
      if (len == 0) {
        if (!quiet) {
          EMSG(_("E713: Cannot use empty key after ."));
        }
        return NULL;
      }
      p = key + len;
    } else {
      /* Get the index [expr] or the first index [expr: ]. */
      p = skipwhite(p + 1);
      if (*p == ':') {
        empty1 = true;
      } else {
        empty1 = false;
        if (eval1(&p, &var1, true) == FAIL) {  // Recursive!
          return NULL;
        }
        if (!tv_check_str(&var1)) {
          // Not a number or string.
          tv_clear(&var1);
          return NULL;
        }
      }

      /* Optionally get the second index [ :expr]. */
      if (*p == ':') {
        if (lp->ll_tv->v_type == VAR_DICT) {
          if (!quiet) {
            EMSG(_(e_dictrange));
          }
          tv_clear(&var1);
          return NULL;
        }
        if (rettv != NULL && (rettv->v_type != VAR_LIST
                              || rettv->vval.v_list == NULL)) {
          if (!quiet) {
            EMSG(_("E709: [:] requires a List value"));
          }
          tv_clear(&var1);
          return NULL;
        }
        p = skipwhite(p + 1);
        if (*p == ']') {
          lp->ll_empty2 = true;
        } else {
          lp->ll_empty2 = false;
          if (eval1(&p, &var2, true) == FAIL) {  // Recursive!
            tv_clear(&var1);
            return NULL;
          }
          if (!tv_check_str(&var2)) {
            // Not a number or string.
            tv_clear(&var1);
            tv_clear(&var2);
            return NULL;
          }
        }
        lp->ll_range = TRUE;
      } else
        lp->ll_range = FALSE;

      if (*p != ']') {
        if (!quiet) {
          EMSG(_(e_missbrac));
        }
        tv_clear(&var1);
        tv_clear(&var2);
        return NULL;
      }

      /* Skip to past ']'. */
      ++p;
    }

    if (lp->ll_tv->v_type == VAR_DICT) {
      if (len == -1) {
        // "[key]": get key from "var1"
        key = (char_u *)tv_get_string(&var1);  // is number or string
      }
      lp->ll_list = NULL;
      lp->ll_dict = lp->ll_tv->vval.v_dict;
      lp->ll_di = tv_dict_find(lp->ll_dict, (const char *)key, len);

      /* When assigning to a scope dictionary check that a function and
       * variable name is valid (only variable name unless it is l: or
       * g: dictionary). Disallow overwriting a builtin function. */
      if (rettv != NULL && lp->ll_dict->dv_scope != 0) {
        int prevval;
        int wrong;

        if (len != -1) {
          prevval = key[len];
          key[len] = NUL;
        } else {
          prevval = 0;  // Avoid compiler warning.
        }
        wrong = ((lp->ll_dict->dv_scope == VAR_DEF_SCOPE
                  && tv_is_func(*rettv)
                  && !var_check_func_name((const char *)key, lp->ll_di == NULL))
                 || !valid_varname((const char *)key));
        if (len != -1) {
          key[len] = prevval;
        }
        if (wrong) {
          return NULL;
        }
      }

      if (lp->ll_di != NULL && tv_is_luafunc(&lp->ll_di->di_tv)
          && len == -1 && rettv == NULL) {
        tv_clear(&var1);
        EMSG2(e_illvar, "v:['lua']");
        return NULL;
      }

      if (lp->ll_di == NULL) {
        // Can't add "v:" or "a:" variable.
        if (lp->ll_dict == &vimvardict
            || &lp->ll_dict->dv_hashtab == get_funccal_args_ht()) {
          EMSG2(_(e_illvar), name);
          tv_clear(&var1);
          return NULL;
        }

        // Key does not exist in dict: may need to add it.
        if (*p == '[' || *p == '.' || unlet) {
          if (!quiet) {
            emsgf(_(e_dictkey), key);
          }
          tv_clear(&var1);
          return NULL;
        }
        if (len == -1) {
          lp->ll_newkey = vim_strsave(key);
        } else {
          lp->ll_newkey = vim_strnsave(key, len);
        }
        tv_clear(&var1);
        break;
      // existing variable, need to check if it can be changed
      } else if (!(flags & GLV_READ_ONLY) && var_check_ro(lp->ll_di->di_flags,
                                                          (const char *)name,
                                                          (size_t)(p - name))) {
        tv_clear(&var1);
        return NULL;
      }

      tv_clear(&var1);
      lp->ll_tv = &lp->ll_di->di_tv;
    } else {
      // Get the number and item for the only or first index of the List.
      if (empty1) {
        lp->ll_n1 = 0;
      } else {
        // Is number or string.
        lp->ll_n1 = (long)tv_get_number(&var1);
      }
      tv_clear(&var1);

      lp->ll_dict = NULL;
      lp->ll_list = lp->ll_tv->vval.v_list;
      lp->ll_li = tv_list_find(lp->ll_list, lp->ll_n1);
      if (lp->ll_li == NULL) {
        if (lp->ll_n1 < 0) {
          lp->ll_n1 = 0;
          lp->ll_li = tv_list_find(lp->ll_list, lp->ll_n1);
        }
      }
      if (lp->ll_li == NULL) {
        tv_clear(&var2);
        if (!quiet) {
          EMSGN(_(e_listidx), lp->ll_n1);
        }
        return NULL;
      }

      /*
       * May need to find the item or absolute index for the second
       * index of a range.
       * When no index given: "lp->ll_empty2" is TRUE.
       * Otherwise "lp->ll_n2" is set to the second index.
       */
      if (lp->ll_range && !lp->ll_empty2) {
        lp->ll_n2 = (long)tv_get_number(&var2);  // Is number or string.
        tv_clear(&var2);
        if (lp->ll_n2 < 0) {
          ni = tv_list_find(lp->ll_list, lp->ll_n2);
          if (ni == NULL) {
            if (!quiet)
              EMSGN(_(e_listidx), lp->ll_n2);
            return NULL;
          }
          lp->ll_n2 = tv_list_idx_of_item(lp->ll_list, ni);
        }

        // Check that lp->ll_n2 isn't before lp->ll_n1.
        if (lp->ll_n1 < 0) {
          lp->ll_n1 = tv_list_idx_of_item(lp->ll_list, lp->ll_li);
        }
        if (lp->ll_n2 < lp->ll_n1) {
          if (!quiet) {
            EMSGN(_(e_listidx), lp->ll_n2);
          }
          return NULL;
        }
      }

      lp->ll_tv = TV_LIST_ITEM_TV(lp->ll_li);
    }
  }

  tv_clear(&var1);
  return p;
}

// TODO(ZyX-I): move to eval/executor

/*
 * Clear lval "lp" that was filled by get_lval().
 */
void clear_lval(lval_T *lp)
{
  xfree(lp->ll_exp_name);
  xfree(lp->ll_newkey);
}

// TODO(ZyX-I): move to eval/executor

/*
 * Set a variable that was parsed by get_lval() to "rettv".
 * "endp" points to just after the parsed name.
 * "op" is NULL, "+" for "+=", "-" for "-=", "*" for "*=", "/" for "/=",
 * "%" for "%=", "." for ".=" or "=" for "=".
 */
static void set_var_lval(lval_T *lp, char_u *endp, typval_T *rettv,
                         int copy, const bool is_const, const char_u *op)
{
  int cc;
  listitem_T  *ri;
  dictitem_T  *di;

  if (lp->ll_tv == NULL) {
    cc = *endp;
    *endp = NUL;
    if (op != NULL && *op != '=') {
      typval_T tv;

      if (is_const) {
        EMSG(_(e_cannot_mod));
        *endp = cc;
        return;
      }

      // handle +=, -=, *=, /=, %= and .=
      di = NULL;
      if (get_var_tv((const char *)lp->ll_name, (int)STRLEN(lp->ll_name),
                     &tv, &di, true, false) == OK) {
        if ((di == NULL
             || (!var_check_ro(di->di_flags, (const char *)lp->ll_name,
                               TV_CSTRING)
                 && !tv_check_lock(di->di_tv.v_lock, (const char *)lp->ll_name,
                                   TV_CSTRING)))
            && eexe_mod_op(&tv, rettv, (const char *)op) == OK) {
          set_var(lp->ll_name, lp->ll_name_len, &tv, false);
        }
        tv_clear(&tv);
      }
    } else {
      set_var_const(lp->ll_name, lp->ll_name_len, rettv, copy, is_const);
    }
    *endp = cc;
  } else if (tv_check_lock(lp->ll_newkey == NULL
                           ? lp->ll_tv->v_lock
                           : lp->ll_tv->vval.v_dict->dv_lock,
                           (const char *)lp->ll_name, TV_CSTRING)) {
  } else if (lp->ll_range) {
    listitem_T *ll_li = lp->ll_li;
    int ll_n1 = lp->ll_n1;

    if (is_const) {
      EMSG(_("E996: Cannot lock a range"));
      return;
    }

    // Check whether any of the list items is locked
    for (ri = tv_list_first(rettv->vval.v_list);
         ri != NULL && ll_li != NULL; ) {
      if (tv_check_lock(TV_LIST_ITEM_TV(ll_li)->v_lock,
                        (const char *)lp->ll_name,
                        TV_CSTRING)) {
        return;
      }
      ri = TV_LIST_ITEM_NEXT(rettv->vval.v_list, ri);
      if (ri == NULL || (!lp->ll_empty2 && lp->ll_n2 == ll_n1)) {
        break;
      }
      ll_li = TV_LIST_ITEM_NEXT(lp->ll_list, ll_li);
      ll_n1++;
    }

    /*
     * Assign the List values to the list items.
     */
    for (ri = tv_list_first(rettv->vval.v_list); ri != NULL; ) {
      if (op != NULL && *op != '=') {
        eexe_mod_op(TV_LIST_ITEM_TV(lp->ll_li), TV_LIST_ITEM_TV(ri),
                    (const char *)op);
      } else {
        tv_clear(TV_LIST_ITEM_TV(lp->ll_li));
        tv_copy(TV_LIST_ITEM_TV(ri), TV_LIST_ITEM_TV(lp->ll_li));
      }
      ri = TV_LIST_ITEM_NEXT(rettv->vval.v_list, ri);
      if (ri == NULL || (!lp->ll_empty2 && lp->ll_n2 == lp->ll_n1)) {
        break;
      }
      assert(lp->ll_li != NULL);
      if (TV_LIST_ITEM_NEXT(lp->ll_list, lp->ll_li) == NULL) {
        // Need to add an empty item.
        tv_list_append_number(lp->ll_list, 0);
        // ll_li may have become invalid after append, don’t use it.
        lp->ll_li = tv_list_last(lp->ll_list);  // Valid again.
      } else {
        lp->ll_li = TV_LIST_ITEM_NEXT(lp->ll_list, lp->ll_li);
      }
      lp->ll_n1++;
    }
    if (ri != NULL) {
      EMSG(_("E710: List value has more items than target"));
    } else if (lp->ll_empty2
               ? (lp->ll_li != NULL
                  && TV_LIST_ITEM_NEXT(lp->ll_list, lp->ll_li) != NULL)
               : lp->ll_n1 != lp->ll_n2) {
      EMSG(_("E711: List value has not enough items"));
    }
  } else {
    typval_T oldtv = TV_INITIAL_VALUE;
    dict_T *dict = lp->ll_dict;
    bool watched = tv_dict_is_watched(dict);

    if (is_const) {
      EMSG(_("E996: Cannot lock a list or dict"));
      return;
    }

    // Assign to a List or Dictionary item.
    if (lp->ll_newkey != NULL) {
      if (op != NULL && *op != '=') {
        EMSG2(_(e_letwrong), op);
        return;
      }

      // Need to add an item to the Dictionary.
      di = tv_dict_item_alloc((const char *)lp->ll_newkey);
      if (tv_dict_add(lp->ll_tv->vval.v_dict, di) == FAIL) {
        xfree(di);
        return;
      }
      lp->ll_tv = &di->di_tv;
    } else {
      if (watched) {
        tv_copy(lp->ll_tv, &oldtv);
      }

      if (op != NULL && *op != '=') {
        eexe_mod_op(lp->ll_tv, rettv, (const char *)op);
        goto notify;
      } else {
        tv_clear(lp->ll_tv);
      }
    }

    // Assign the value to the variable or list item.
    if (copy) {
      tv_copy(rettv, lp->ll_tv);
    } else {
      *lp->ll_tv = *rettv;
      lp->ll_tv->v_lock = 0;
      tv_init(rettv);
    }

notify:
    if (watched) {
      if (oldtv.v_type == VAR_UNKNOWN) {
        assert(lp->ll_newkey != NULL);
        tv_dict_watcher_notify(dict, (char *)lp->ll_newkey, lp->ll_tv, NULL);
      } else {
        dictitem_T *di_ = lp->ll_di;
        assert(di_->di_key != NULL);
        tv_dict_watcher_notify(dict, (char *)di_->di_key, lp->ll_tv, &oldtv);
        tv_clear(&oldtv);
      }
    }
  }
}

// TODO(ZyX-I): move to eval/ex_cmds

/*
 * Evaluate the expression used in a ":for var in expr" command.
 * "arg" points to "var".
 * Set "*errp" to TRUE for an error, FALSE otherwise;
 * Return a pointer that holds the info.  Null when there is an error.
 */
void *eval_for_line(const char_u *arg, bool *errp, char_u **nextcmdp, int skip)
{
  forinfo_T   *fi = xcalloc(1, sizeof(forinfo_T));
  const char_u *expr;
  typval_T tv;
  list_T      *l;

  *errp = true;  // Default: there is an error.

  expr = skip_var_list(arg, &fi->fi_varcount, &fi->fi_semicolon);
  if (expr == NULL)
    return fi;

  expr = skipwhite(expr);
  if (expr[0] != 'i' || expr[1] != 'n' || !ascii_iswhite(expr[2])) {
    EMSG(_("E690: Missing \"in\" after :for"));
    return fi;
  }

  if (skip)
    ++emsg_skip;
  if (eval0(skipwhite(expr + 2), &tv, nextcmdp, !skip) == OK) {
    *errp = false;
    if (!skip) {
      l = tv.vval.v_list;
      if (tv.v_type != VAR_LIST) {
        EMSG(_(e_listreq));
        tv_clear(&tv);
      } else if (l == NULL) {
        // a null list is like an empty list: do nothing
        tv_clear(&tv);
      } else {
        /* No need to increment the refcount, it's already set for the
         * list being used in "tv". */
        fi->fi_list = l;
        tv_list_watch_add(l, &fi->fi_lw);
        fi->fi_lw.lw_item = tv_list_first(l);
      }
    }
  }
  if (skip)
    --emsg_skip;

  return fi;
}

// TODO(ZyX-I): move to eval/ex_cmds

/*
 * Use the first item in a ":for" list.  Advance to the next.
 * Assign the values to the variable (list).  "arg" points to the first one.
 * Return TRUE when a valid item was found, FALSE when at end of list or
 * something wrong.
 */
bool next_for_item(void *fi_void, char_u *arg)
{
  forinfo_T *fi = (forinfo_T *)fi_void;

  listitem_T *item = fi->fi_lw.lw_item;
  if (item == NULL) {
    return false;
  } else {
    fi->fi_lw.lw_item = TV_LIST_ITEM_NEXT(fi->fi_list, item);
    return (ex_let_vars(arg, TV_LIST_ITEM_TV(item), true,
                        fi->fi_semicolon, fi->fi_varcount, false, NULL) == OK);
  }
}

// TODO(ZyX-I): move to eval/ex_cmds

/*
 * Free the structure used to store info used by ":for".
 */
void free_for_info(void *fi_void)
{
  forinfo_T    *fi = (forinfo_T *)fi_void;

  if (fi != NULL && fi->fi_list != NULL) {
    tv_list_watch_remove(fi->fi_list, &fi->fi_lw);
    tv_list_unref(fi->fi_list);
  }
  xfree(fi);
}


void set_context_for_expression(expand_T *xp, char_u *arg, cmdidx_T cmdidx)
{
  int got_eq = FALSE;
  int c;
  char_u      *p;

  if (cmdidx == CMD_let || cmdidx == CMD_const) {
    xp->xp_context = EXPAND_USER_VARS;
    if (vim_strpbrk(arg, (char_u *)"\"'+-*/%.=!?~|&$([<>,#") == NULL) {
      /* ":let var1 var2 ...": find last space. */
      for (p = arg + STRLEN(arg); p >= arg; ) {
        xp->xp_pattern = p;
        MB_PTR_BACK(arg, p);
        if (ascii_iswhite(*p)) {
          break;
        }
      }
      return;
    }
  } else
    xp->xp_context = cmdidx == CMD_call ? EXPAND_FUNCTIONS
                     : EXPAND_EXPRESSION;
  while ((xp->xp_pattern = vim_strpbrk(arg,
              (char_u *)"\"'+-*/%.=!?~|&$([<>,#")) != NULL) {
    c = *xp->xp_pattern;
    if (c == '&') {
      c = xp->xp_pattern[1];
      if (c == '&') {
        ++xp->xp_pattern;
        xp->xp_context = cmdidx != CMD_let || got_eq
                         ? EXPAND_EXPRESSION : EXPAND_NOTHING;
      } else if (c != ' ') {
        xp->xp_context = EXPAND_SETTINGS;
        if ((c == 'l' || c == 'g') && xp->xp_pattern[2] == ':')
          xp->xp_pattern += 2;

      }
    } else if (c == '$') {
      /* environment variable */
      xp->xp_context = EXPAND_ENV_VARS;
    } else if (c == '=') {
      got_eq = TRUE;
      xp->xp_context = EXPAND_EXPRESSION;
    } else if (c == '#'
               && xp->xp_context == EXPAND_EXPRESSION) {
      // Autoload function/variable contains '#'
      break;
    } else if ((c == '<' || c == '#')
               && xp->xp_context == EXPAND_FUNCTIONS
               && vim_strchr(xp->xp_pattern, '(') == NULL) {
      /* Function name can start with "<SNR>" and contain '#'. */
      break;
    } else if (cmdidx != CMD_let || got_eq) {
      if (c == '"') {               /* string */
        while ((c = *++xp->xp_pattern) != NUL && c != '"')
          if (c == '\\' && xp->xp_pattern[1] != NUL)
            ++xp->xp_pattern;
        xp->xp_context = EXPAND_NOTHING;
      } else if (c == '\'') {     /* literal string */
        /* Trick: '' is like stopping and starting a literal string. */
        while ((c = *++xp->xp_pattern) != NUL && c != '\'')
          /* skip */;
        xp->xp_context = EXPAND_NOTHING;
      } else if (c == '|') {
        if (xp->xp_pattern[1] == '|') {
          ++xp->xp_pattern;
          xp->xp_context = EXPAND_EXPRESSION;
        } else
          xp->xp_context = EXPAND_COMMANDS;
      } else
        xp->xp_context = EXPAND_EXPRESSION;
    } else
      /* Doesn't look like something valid, expand as an expression
       * anyway. */
      xp->xp_context = EXPAND_EXPRESSION;
    arg = xp->xp_pattern;
    if (*arg != NUL)
      while ((c = *++arg) != NUL && (c == ' ' || c == '\t'))
        /* skip */;
  }
  xp->xp_pattern = arg;
}

// TODO(ZyX-I): move to eval/ex_cmds

/*
 * ":1,25call func(arg1, arg2)"	function call.
 */
void ex_call(exarg_T *eap)
{
  char_u      *arg = eap->arg;
  char_u      *startarg;
  char_u      *name;
  char_u      *tofree;
  int len;
  typval_T rettv;
  linenr_T lnum;
  int doesrange;
  bool failed = false;
  funcdict_T fudi;
  partial_T *partial = NULL;

  if (eap->skip) {
    // trans_function_name() doesn't work well when skipping, use eval0()
    // instead to skip to any following command, e.g. for:
    //   :if 0 | call dict.foo().bar() | endif.
    emsg_skip++;
    if (eval0(eap->arg, &rettv, &eap->nextcmd, false) != FAIL) {
      tv_clear(&rettv);
    }
    emsg_skip--;
    return;
  }

  tofree = trans_function_name(&arg, false, TFN_INT, &fudi, &partial);
  if (fudi.fd_newkey != NULL) {
    // Still need to give an error message for missing key.
    EMSG2(_(e_dictkey), fudi.fd_newkey);
    xfree(fudi.fd_newkey);
  }
  if (tofree == NULL) {
    return;
  }

  // Increase refcount on dictionary, it could get deleted when evaluating
  // the arguments.
  if (fudi.fd_dict != NULL) {
    fudi.fd_dict->dv_refcount++;
  }

  // If it is the name of a variable of type VAR_FUNC or VAR_PARTIAL use its
  // contents. For VAR_PARTIAL get its partial, unless we already have one
  // from trans_function_name().
  len = (int)STRLEN(tofree);
  name = deref_func_name((const char *)tofree, &len,
                         partial != NULL ? NULL : &partial, false);

  // Skip white space to allow ":call func ()".  Not good, but required for
  // backward compatibility.
  startarg = skipwhite(arg);
  rettv.v_type = VAR_UNKNOWN;  // tv_clear() uses this.

  if (*startarg != '(') {
    EMSG2(_("E107: Missing parentheses: %s"), eap->arg);
    goto end;
  }

  lnum = eap->line1;
  for (; lnum <= eap->line2; lnum++) {
    if (eap->addr_count > 0) {  // -V560
      if (lnum > curbuf->b_ml.ml_line_count) {
        // If the function deleted lines or switched to another buffer
        // the line number may become invalid.
        EMSG(_(e_invrange));
        break;
      }
      curwin->w_cursor.lnum = lnum;
      curwin->w_cursor.col = 0;
      curwin->w_cursor.coladd = 0;
    }
    arg = startarg;
    if (get_func_tv(name, (int)STRLEN(name), &rettv, &arg,
                    eap->line1, eap->line2, &doesrange,
                    true, partial, fudi.fd_dict) == FAIL) {
      failed = true;
      break;
    }

    // Handle a function returning a Funcref, Dictionary or List.
    if (handle_subscript((const char **)&arg, &rettv, true, true)
        == FAIL) {
      failed = true;
      break;
    }

    tv_clear(&rettv);
    if (doesrange) {
      break;
    }

    // Stop when immediately aborting on error, or when an interrupt
    // occurred or an exception was thrown but not caught.
    // get_func_tv() returned OK, so that the check for trailing
    // characters below is executed.
    if (aborting()) {
      break;
    }
  }

  if (!failed) {
    // Check for trailing illegal characters and a following command.
    if (!ends_excmd(*arg)) {
      emsg_severe = TRUE;
      EMSG(_(e_trailing));
    } else {
      eap->nextcmd = check_nextcmd(arg);
    }
  }

end:
  tv_dict_unref(fudi.fd_dict);
  xfree(tofree);
}

// TODO(ZyX-I): move to eval/ex_cmds

/*
 * ":unlet[!] var1 ... " command.
 */
void ex_unlet(exarg_T *eap)
{
  ex_unletlock(eap, eap->arg, 0);
}

// TODO(ZyX-I): move to eval/ex_cmds

/*
 * ":lockvar" and ":unlockvar" commands
 */
void ex_lockvar(exarg_T *eap)
{
  char_u      *arg = eap->arg;
  int deep = 2;

  if (eap->forceit) {
    deep = -1;
  } else if (ascii_isdigit(*arg)) {
    deep = getdigits_int(&arg, false, -1);
    arg = skipwhite(arg);
  }

  ex_unletlock(eap, arg, deep);
}

// TODO(ZyX-I): move to eval/ex_cmds

/*
 * ":unlet", ":lockvar" and ":unlockvar" are quite similar.
 */
static void ex_unletlock(exarg_T *eap, char_u *argstart, int deep)
{
  char_u      *arg = argstart;
  bool error = false;
  lval_T lv;

  do {
    if (*arg == '$') {
      const char *name = (char *)++arg;

      if (get_env_len((const char_u **)&arg) == 0) {
        EMSG2(_(e_invarg2), name - 1);
        return;
      }
      os_unsetenv(name);
      arg = skipwhite(arg);
      continue;
    }

    // Parse the name and find the end.
    char_u *const name_end = (char_u *)get_lval(arg, NULL, &lv, true,
                                                eap->skip || error,
                                                0, FNE_CHECK_START);
    if (lv.ll_name == NULL) {
      error = true;  // error, but continue parsing.
    }
    if (name_end == NULL || (!ascii_iswhite(*name_end)
                             && !ends_excmd(*name_end))) {
      if (name_end != NULL) {
        emsg_severe = TRUE;
        EMSG(_(e_trailing));
      }
      if (!(eap->skip || error))
        clear_lval(&lv);
      break;
    }

    if (!error && !eap->skip) {
      if (eap->cmdidx == CMD_unlet) {
        if (do_unlet_var(&lv, name_end, eap->forceit) == FAIL)
          error = TRUE;
      } else {
        if (do_lock_var(&lv, name_end, deep,
                        eap->cmdidx == CMD_lockvar) == FAIL) {
          error = true;
        }
      }
    }

    if (!eap->skip)
      clear_lval(&lv);

    arg = skipwhite(name_end);
  } while (!ends_excmd(*arg));

  eap->nextcmd = check_nextcmd(arg);
}

// TODO(ZyX-I): move to eval/ex_cmds

static int do_unlet_var(lval_T *const lp, char_u *const name_end, int forceit)
{
  int ret = OK;
  int cc;

  if (lp->ll_tv == NULL) {
    cc = *name_end;
    *name_end = NUL;

    // Normal name or expanded name.
    if (do_unlet(lp->ll_name, lp->ll_name_len, forceit) == FAIL) {
      ret = FAIL;
    }
    *name_end = cc;
  } else if ((lp->ll_list != NULL
              // ll_list is not NULL when lvalue is not in a list, NULL lists
              // yield E689.
              && tv_check_lock(tv_list_locked(lp->ll_list),
                               (const char *)lp->ll_name,
                               lp->ll_name_len))
             || (lp->ll_dict != NULL
                 && tv_check_lock(lp->ll_dict->dv_lock,
                                  (const char *)lp->ll_name,
                                  lp->ll_name_len))) {
    return FAIL;
  } else if (lp->ll_range) {
    assert(lp->ll_list != NULL);
    // Delete a range of List items.
    listitem_T *const first_li = lp->ll_li;
    listitem_T *last_li = first_li;
    for (;;) {
      listitem_T *const li = TV_LIST_ITEM_NEXT(lp->ll_list, lp->ll_li);
      if (tv_check_lock(TV_LIST_ITEM_TV(lp->ll_li)->v_lock,
                        (const char *)lp->ll_name,
                        lp->ll_name_len)) {
        return false;
      }
      lp->ll_li = li;
      lp->ll_n1++;
      if (lp->ll_li == NULL || (!lp->ll_empty2 && lp->ll_n2 < lp->ll_n1)) {
        break;
      } else {
        last_li = lp->ll_li;
      }
    }
    tv_list_remove_items(lp->ll_list, first_li, last_li);
  } else {
    if (lp->ll_list != NULL) {
      // unlet a List item.
      tv_list_item_remove(lp->ll_list, lp->ll_li);
    } else {
      // unlet a Dictionary item.
      dict_T *d = lp->ll_dict;
      assert(d != NULL);
      dictitem_T *di = lp->ll_di;
      bool watched = tv_dict_is_watched(d);
      char *key = NULL;
      typval_T oldtv;

      if (watched) {
        tv_copy(&di->di_tv, &oldtv);
        // need to save key because dictitem_remove will free it
        key = xstrdup((char *)di->di_key);
      }

      tv_dict_item_remove(d, di);

      if (watched) {
        tv_dict_watcher_notify(d, key, NULL, &oldtv);
        tv_clear(&oldtv);
        xfree(key);
      }
    }
  }

  return ret;
}

// TODO(ZyX-I): move to eval/ex_cmds

/// unlet a variable
///
/// @param[in]  name  Variable name to unlet.
/// @param[in]  name_len  Variable name length.
/// @param[in]  fonceit  If true, do not complain if variable doesn’t exist.
///
/// @return OK if it existed, FAIL otherwise.
int do_unlet(const char *const name, const size_t name_len, const int forceit)
  FUNC_ATTR_NONNULL_ALL
{
  const char *varname;
  dict_T *dict;
  hashtab_T *ht = find_var_ht_dict(name, name_len, &varname, &dict);

  if (ht != NULL && *varname != NUL) {
    dict_T *d;
    if (ht == &globvarht) {
      d = &globvardict;
    } else if (current_funccal != NULL
               && ht == &current_funccal->l_vars.dv_hashtab) {
      d = &current_funccal->l_vars;
    } else if (ht == &compat_hashtab) {
        d = &vimvardict;
    } else {
      dictitem_T *const di = find_var_in_ht(ht, *name, "", 0, false);
      d = di->di_tv.vval.v_dict;
    }
    if (d == NULL) {
      internal_error("do_unlet()");
      return FAIL;
    }
    hashitem_T *hi = hash_find(ht, (const char_u *)varname);
    if (HASHITEM_EMPTY(hi)) {
      hi = find_hi_in_scoped_ht((const char *)name, &ht);
    }
    if (hi != NULL && !HASHITEM_EMPTY(hi)) {
      dictitem_T *const di = TV_DICT_HI2DI(hi);
      if (var_check_fixed(di->di_flags, (const char *)name, TV_CSTRING)
          || var_check_ro(di->di_flags, (const char *)name, TV_CSTRING)
          || tv_check_lock(d->dv_lock, (const char *)name, TV_CSTRING)) {
        return FAIL;
      }

      if (tv_check_lock(d->dv_lock, (const char *)name, TV_CSTRING)) {
        return FAIL;
      }

      typval_T oldtv;
      bool watched = tv_dict_is_watched(dict);

      if (watched) {
        tv_copy(&di->di_tv, &oldtv);
      }

      delete_var(ht, hi);

      if (watched) {
        tv_dict_watcher_notify(dict, varname, NULL, &oldtv);
        tv_clear(&oldtv);
      }
      return OK;
    }
  }
  if (forceit)
    return OK;
  EMSG2(_("E108: No such variable: \"%s\""), name);
  return FAIL;
}

// TODO(ZyX-I): move to eval/ex_cmds

/*
 * Lock or unlock variable indicated by "lp".
 * "deep" is the levels to go (-1 for unlimited);
 * "lock" is TRUE for ":lockvar", FALSE for ":unlockvar".
 */
static int do_lock_var(lval_T *lp, char_u *const name_end, const int deep,
                       const bool lock)
{
  int ret = OK;

  if (deep == 0) {  // Nothing to do.
    return OK;
  }

  if (lp->ll_tv == NULL) {
    // Normal name or expanded name.
    dictitem_T *const di = find_var(
        (const char *)lp->ll_name, lp->ll_name_len, NULL,
        true);
    if (di == NULL) {
      ret = FAIL;
    } else if ((di->di_flags & DI_FLAGS_FIX)
               && di->di_tv.v_type != VAR_DICT
               && di->di_tv.v_type != VAR_LIST) {
      // For historical reasons this error is not given for Lists and
      // Dictionaries. E.g. b: dictionary may be locked/unlocked.
      emsgf(_("E940: Cannot lock or unlock variable %s"), lp->ll_name);
    } else {
      if (lock) {
        di->di_flags |= DI_FLAGS_LOCK;
      } else {
        di->di_flags &= ~DI_FLAGS_LOCK;
      }
      tv_item_lock(&di->di_tv, deep, lock);
    }
  } else if (lp->ll_range) {
    listitem_T    *li = lp->ll_li;

    /* (un)lock a range of List items. */
    while (li != NULL && (lp->ll_empty2 || lp->ll_n2 >= lp->ll_n1)) {
      tv_item_lock(TV_LIST_ITEM_TV(li), deep, lock);
      li = TV_LIST_ITEM_NEXT(lp->ll_list, li);
      lp->ll_n1++;
    }
  } else if (lp->ll_list != NULL) {
    // (un)lock a List item.
    tv_item_lock(TV_LIST_ITEM_TV(lp->ll_li), deep, lock);
  } else {
    // (un)lock a Dictionary item.
    tv_item_lock(&lp->ll_di->di_tv, deep, lock);
  }

  return ret;
}

/*
 * Delete all "menutrans_" variables.
 */
void del_menutrans_vars(void)
{
  hash_lock(&globvarht);
  HASHTAB_ITER(&globvarht, hi, {
    if (STRNCMP(hi->hi_key, "menutrans_", 10) == 0) {
      delete_var(&globvarht, hi);
    }
  });
  hash_unlock(&globvarht);
}

/*
 * Local string buffer for the next two functions to store a variable name
 * with its prefix. Allocated in cat_prefix_varname(), freed later in
 * get_user_var_name().
 */


static char_u   *varnamebuf = NULL;
static size_t varnamebuflen = 0;

/*
 * Function to concatenate a prefix and a variable name.
 */
static char_u *cat_prefix_varname(int prefix, char_u *name)
{
  size_t len = STRLEN(name) + 3;

  if (len > varnamebuflen) {
    xfree(varnamebuf);
    len += 10;                          /* some additional space */
    varnamebuf = xmalloc(len);
    varnamebuflen = len;
  }
  *varnamebuf = prefix;
  varnamebuf[1] = ':';
  STRCPY(varnamebuf + 2, name);
  return varnamebuf;
}

/*
 * Function given to ExpandGeneric() to obtain the list of user defined
 * (global/buffer/window/built-in) variable names.
 */
char_u *get_user_var_name(expand_T *xp, int idx)
{
  static size_t gdone;
  static size_t bdone;
  static size_t wdone;
  static size_t tdone;
  static size_t vidx;
  static hashitem_T   *hi;
  hashtab_T           *ht;

  if (idx == 0) {
    gdone = bdone = wdone = vidx = 0;
    tdone = 0;
  }

  /* Global variables */
  if (gdone < globvarht.ht_used) {
    if (gdone++ == 0)
      hi = globvarht.ht_array;
    else
      ++hi;
    while (HASHITEM_EMPTY(hi))
      ++hi;
    if (STRNCMP("g:", xp->xp_pattern, 2) == 0)
      return cat_prefix_varname('g', hi->hi_key);
    return hi->hi_key;
  }

  /* b: variables */
  ht = &curbuf->b_vars->dv_hashtab;
  if (bdone < ht->ht_used) {
    if (bdone++ == 0)
      hi = ht->ht_array;
    else
      ++hi;
    while (HASHITEM_EMPTY(hi))
      ++hi;
    return cat_prefix_varname('b', hi->hi_key);
  }

  /* w: variables */
  ht = &curwin->w_vars->dv_hashtab;
  if (wdone < ht->ht_used) {
    if (wdone++ == 0)
      hi = ht->ht_array;
    else
      ++hi;
    while (HASHITEM_EMPTY(hi))
      ++hi;
    return cat_prefix_varname('w', hi->hi_key);
  }

  /* t: variables */
  ht = &curtab->tp_vars->dv_hashtab;
  if (tdone < ht->ht_used) {
    if (tdone++ == 0)
      hi = ht->ht_array;
    else
      ++hi;
    while (HASHITEM_EMPTY(hi))
      ++hi;
    return cat_prefix_varname('t', hi->hi_key);
  }

  // v: variables
  if (vidx < ARRAY_SIZE(vimvars)) {
    return cat_prefix_varname('v', (char_u *)vimvars[vidx++].vv_name);
  }

  XFREE_CLEAR(varnamebuf);
  varnamebuflen = 0;
  return NULL;
}

// TODO(ZyX-I): move to eval/expressions

/// Return TRUE if "pat" matches "text".
/// Does not use 'cpo' and always uses 'magic'.
static int pattern_match(char_u *pat, char_u *text, int ic)
{
  int matches = 0;
  regmatch_T regmatch;

  // avoid 'l' flag in 'cpoptions'
  char_u *save_cpo = p_cpo;
  p_cpo = (char_u *)"";
  regmatch.regprog = vim_regcomp(pat, RE_MAGIC + RE_STRING);
  if (regmatch.regprog != NULL) {
    regmatch.rm_ic = ic;
    matches = vim_regexec_nl(&regmatch, text, (colnr_T)0);
    vim_regfree(regmatch.regprog);
  }
  p_cpo = save_cpo;
  return matches;
}

/*
 * types for expressions.
 */
typedef enum {
  TYPE_UNKNOWN = 0,
  TYPE_EQUAL,         // ==
  TYPE_NEQUAL,        // !=
  TYPE_GREATER,       // >
  TYPE_GEQUAL,        // >=
  TYPE_SMALLER,       // <
  TYPE_SEQUAL,        // <=
  TYPE_MATCH,         // =~
  TYPE_NOMATCH,       // !~
} exptype_T;

// TODO(ZyX-I): move to eval/expressions

/*
 * The "evaluate" argument: When FALSE, the argument is only parsed but not
 * executed.  The function may return OK, but the rettv will be of type
 * VAR_UNKNOWN.  The function still returns FAIL for a syntax error.
 */

/*
 * Handle zero level expression.
 * This calls eval1() and handles error message and nextcmd.
 * Put the result in "rettv" when returning OK and "evaluate" is TRUE.
 * Note: "rettv.v_lock" is not set.
 * Return OK or FAIL.
 */
int eval0(char_u *arg, typval_T *rettv, char_u **nextcmd, int evaluate)
{
  int ret;
  char_u      *p;

  p = skipwhite(arg);
  ret = eval1(&p, rettv, evaluate);
  if (ret == FAIL || !ends_excmd(*p)) {
    if (ret != FAIL) {
      tv_clear(rettv);
    }
    // Report the invalid expression unless the expression evaluation has
    // been cancelled due to an aborting error, an interrupt, or an
    // exception.
    if (!aborting()) {
      emsgf(_(e_invexpr2), arg);
    }
    ret = FAIL;
  }
  if (nextcmd != NULL)
    *nextcmd = check_nextcmd(p);

  return ret;
}

// TODO(ZyX-I): move to eval/expressions

/*
 * Handle top level expression:
 *	expr2 ? expr1 : expr1
 *
 * "arg" must point to the first non-white of the expression.
 * "arg" is advanced to the next non-white after the recognized expression.
 *
 * Note: "rettv.v_lock" is not set.
 *
 * Return OK or FAIL.
 */
int eval1(char_u **arg, typval_T *rettv, int evaluate)
{
  int result;
  typval_T var2;

  /*
   * Get the first variable.
   */
  if (eval2(arg, rettv, evaluate) == FAIL)
    return FAIL;

  if ((*arg)[0] == '?') {
    result = FALSE;
    if (evaluate) {
      bool error = false;

      if (tv_get_number_chk(rettv, &error) != 0) {
        result = true;
      }
      tv_clear(rettv);
      if (error) {
        return FAIL;
      }
    }

    /*
     * Get the second variable.
     */
    *arg = skipwhite(*arg + 1);
    if (eval1(arg, rettv, evaluate && result) == FAIL)     /* recursive! */
      return FAIL;

    /*
     * Check for the ":".
     */
    if ((*arg)[0] != ':') {
      EMSG(_("E109: Missing ':' after '?'"));
      if (evaluate && result) {
        tv_clear(rettv);
      }
      return FAIL;
    }

    /*
     * Get the third variable.
     */
    *arg = skipwhite(*arg + 1);
    if (eval1(arg, &var2, evaluate && !result) == FAIL) {  // Recursive!
      if (evaluate && result) {
        tv_clear(rettv);
      }
      return FAIL;
    }
    if (evaluate && !result)
      *rettv = var2;
  }

  return OK;
}

// TODO(ZyX-I): move to eval/expressions

/*
 * Handle first level expression:
 *	expr2 || expr2 || expr2	    logical OR
 *
 * "arg" must point to the first non-white of the expression.
 * "arg" is advanced to the next non-white after the recognized expression.
 *
 * Return OK or FAIL.
 */
static int eval2(char_u **arg, typval_T *rettv, int evaluate)
{
  typval_T var2;
  long result;
  int first;
  bool error = false;

  /*
   * Get the first variable.
   */
  if (eval3(arg, rettv, evaluate) == FAIL)
    return FAIL;

  /*
   * Repeat until there is no following "||".
   */
  first = TRUE;
  result = FALSE;
  while ((*arg)[0] == '|' && (*arg)[1] == '|') {
    if (evaluate && first) {
      if (tv_get_number_chk(rettv, &error) != 0) {
        result = true;
      }
      tv_clear(rettv);
      if (error) {
        return FAIL;
      }
      first = false;
    }

    /*
     * Get the second variable.
     */
    *arg = skipwhite(*arg + 2);
    if (eval3(arg, &var2, evaluate && !result) == FAIL)
      return FAIL;

    /*
     * Compute the result.
     */
    if (evaluate && !result) {
      if (tv_get_number_chk(&var2, &error) != 0) {
        result = true;
      }
      tv_clear(&var2);
      if (error) {
        return FAIL;
      }
    }
    if (evaluate) {
      rettv->v_type = VAR_NUMBER;
      rettv->vval.v_number = result;
    }
  }

  return OK;
}

// TODO(ZyX-I): move to eval/expressions

/*
 * Handle second level expression:
 *	expr3 && expr3 && expr3	    logical AND
 *
 * "arg" must point to the first non-white of the expression.
 * "arg" is advanced to the next non-white after the recognized expression.
 *
 * Return OK or FAIL.
 */
static int eval3(char_u **arg, typval_T *rettv, int evaluate)
{
  typval_T var2;
  long result;
  int first;
  bool error = false;

  /*
   * Get the first variable.
   */
  if (eval4(arg, rettv, evaluate) == FAIL)
    return FAIL;

  /*
   * Repeat until there is no following "&&".
   */
  first = TRUE;
  result = TRUE;
  while ((*arg)[0] == '&' && (*arg)[1] == '&') {
    if (evaluate && first) {
      if (tv_get_number_chk(rettv, &error) == 0) {
        result = false;
      }
      tv_clear(rettv);
      if (error) {
        return FAIL;
      }
      first = false;
    }

    /*
     * Get the second variable.
     */
    *arg = skipwhite(*arg + 2);
    if (eval4(arg, &var2, evaluate && result) == FAIL)
      return FAIL;

    /*
     * Compute the result.
     */
    if (evaluate && result) {
      if (tv_get_number_chk(&var2, &error) == 0) {
        result = false;
      }
      tv_clear(&var2);
      if (error) {
        return FAIL;
      }
    }
    if (evaluate) {
      rettv->v_type = VAR_NUMBER;
      rettv->vval.v_number = result;
    }
  }

  return OK;
}

// TODO(ZyX-I): move to eval/expressions

/*
 * Handle third level expression:
 *	var1 == var2
 *	var1 =~ var2
 *	var1 != var2
 *	var1 !~ var2
 *	var1 > var2
 *	var1 >= var2
 *	var1 < var2
 *	var1 <= var2
 *	var1 is var2
 *	var1 isnot var2
 *
 * "arg" must point to the first non-white of the expression.
 * "arg" is advanced to the next non-white after the recognized expression.
 *
 * Return OK or FAIL.
 */
static int eval4(char_u **arg, typval_T *rettv, int evaluate)
{
  typval_T var2;
  char_u      *p;
  int i;
  exptype_T type = TYPE_UNKNOWN;
  int type_is = FALSE;              /* TRUE for "is" and "isnot" */
  int len = 2;
  varnumber_T n1, n2;
  int ic;

  /*
   * Get the first variable.
   */
  if (eval5(arg, rettv, evaluate) == FAIL)
    return FAIL;

  p = *arg;
  switch (p[0]) {
  case '=':   if (p[1] == '=')
      type = TYPE_EQUAL;
    else if (p[1] == '~')
      type = TYPE_MATCH;
    break;
  case '!':   if (p[1] == '=')
      type = TYPE_NEQUAL;
    else if (p[1] == '~')
      type = TYPE_NOMATCH;
    break;
  case '>':   if (p[1] != '=') {
      type = TYPE_GREATER;
      len = 1;
  } else
      type = TYPE_GEQUAL;
    break;
  case '<':   if (p[1] != '=') {
      type = TYPE_SMALLER;
      len = 1;
  } else
      type = TYPE_SEQUAL;
    break;
  case 'i':   if (p[1] == 's') {
      if (p[2] == 'n' && p[3] == 'o' && p[4] == 't') {
        len = 5;
      }
      if (!isalnum(p[len]) && p[len] != '_') {
        type = len == 2 ? TYPE_EQUAL : TYPE_NEQUAL;
        type_is = TRUE;
      }
  }
    break;
  }

  /*
   * If there is a comparative operator, use it.
   */
  if (type != TYPE_UNKNOWN) {
    /* extra question mark appended: ignore case */
    if (p[len] == '?') {
      ic = TRUE;
      ++len;
    }
    /* extra '#' appended: match case */
    else if (p[len] == '#') {
      ic = FALSE;
      ++len;
    }
    /* nothing appended: use 'ignorecase' */
    else
      ic = p_ic;

    /*
     * Get the second variable.
     */
    *arg = skipwhite(p + len);
    if (eval5(arg, &var2, evaluate) == FAIL) {
      tv_clear(rettv);
      return FAIL;
    }

    if (evaluate) {
      if (type_is && rettv->v_type != var2.v_type) {
        /* For "is" a different type always means FALSE, for "notis"
         * it means TRUE. */
        n1 = (type == TYPE_NEQUAL);
      } else if (rettv->v_type == VAR_LIST || var2.v_type == VAR_LIST) {
        if (type_is) {
          n1 = (rettv->v_type == var2.v_type
                && rettv->vval.v_list == var2.vval.v_list);
          if (type == TYPE_NEQUAL)
            n1 = !n1;
        } else if (rettv->v_type != var2.v_type
                   || (type != TYPE_EQUAL && type != TYPE_NEQUAL)) {
          if (rettv->v_type != var2.v_type) {
            EMSG(_("E691: Can only compare List with List"));
          } else {
            EMSG(_("E692: Invalid operation for List"));
          }
          tv_clear(rettv);
          tv_clear(&var2);
          return FAIL;
        } else {
          // Compare two Lists for being equal or unequal.
          n1 = tv_list_equal(rettv->vval.v_list, var2.vval.v_list, ic, false);
          if (type == TYPE_NEQUAL) {
            n1 = !n1;
          }
        }
      } else if (rettv->v_type == VAR_DICT || var2.v_type == VAR_DICT) {
        if (type_is) {
          n1 = (rettv->v_type == var2.v_type
                && rettv->vval.v_dict == var2.vval.v_dict);
          if (type == TYPE_NEQUAL)
            n1 = !n1;
        } else if (rettv->v_type != var2.v_type
                   || (type != TYPE_EQUAL && type != TYPE_NEQUAL)) {
          if (rettv->v_type != var2.v_type)
            EMSG(_("E735: Can only compare Dictionary with Dictionary"));
          else
            EMSG(_("E736: Invalid operation for Dictionary"));
          tv_clear(rettv);
          tv_clear(&var2);
          return FAIL;
        } else {
          // Compare two Dictionaries for being equal or unequal.
          n1 = tv_dict_equal(rettv->vval.v_dict, var2.vval.v_dict,
                             ic, false);
          if (type == TYPE_NEQUAL) {
            n1 = !n1;
          }
        }
      } else if (tv_is_func(*rettv) || tv_is_func(var2)) {
        if (type != TYPE_EQUAL && type != TYPE_NEQUAL) {
          EMSG(_("E694: Invalid operation for Funcrefs"));
          tv_clear(rettv);
          tv_clear(&var2);
          return FAIL;
        }
        if ((rettv->v_type == VAR_PARTIAL
             && rettv->vval.v_partial == NULL)
            || (var2.v_type == VAR_PARTIAL
                && var2.vval.v_partial == NULL)) {
            // when a partial is NULL assume not equal
            n1 = false;
        } else if (type_is) {
          if (rettv->v_type == VAR_FUNC && var2.v_type == VAR_FUNC) {
            // strings are considered the same if their value is
            // the same
            n1 = tv_equal(rettv, &var2, ic, false);
          } else if (rettv->v_type == VAR_PARTIAL
                     && var2.v_type == VAR_PARTIAL) {
            n1 = (rettv->vval.v_partial == var2.vval.v_partial);
          } else {
            n1 = false;
          }
        } else {
          n1 = tv_equal(rettv, &var2, ic, false);
        }
        if (type == TYPE_NEQUAL) {
          n1 = !n1;
        }
      }
      /*
       * If one of the two variables is a float, compare as a float.
       * When using "=~" or "!~", always compare as string.
       */
      else if ((rettv->v_type == VAR_FLOAT || var2.v_type == VAR_FLOAT)
               && type != TYPE_MATCH && type != TYPE_NOMATCH) {
        float_T f1, f2;

        if (rettv->v_type == VAR_FLOAT) {
          f1 = rettv->vval.v_float;
        } else {
          f1 = tv_get_number(rettv);
        }
        if (var2.v_type == VAR_FLOAT) {
          f2 = var2.vval.v_float;
        } else {
          f2 = tv_get_number(&var2);
        }
        n1 = false;
        switch (type) {
          case TYPE_EQUAL:    n1 = (f1 == f2); break;
          case TYPE_NEQUAL:   n1 = (f1 != f2); break;
          case TYPE_GREATER:  n1 = (f1 > f2); break;
          case TYPE_GEQUAL:   n1 = (f1 >= f2); break;
          case TYPE_SMALLER:  n1 = (f1 < f2); break;
          case TYPE_SEQUAL:   n1 = (f1 <= f2); break;
          case TYPE_UNKNOWN:
          case TYPE_MATCH:
          case TYPE_NOMATCH:  break;
        }
      }
      /*
       * If one of the two variables is a number, compare as a number.
       * When using "=~" or "!~", always compare as string.
       */
      else if ((rettv->v_type == VAR_NUMBER || var2.v_type == VAR_NUMBER)
               && type != TYPE_MATCH && type != TYPE_NOMATCH) {
        n1 = tv_get_number(rettv);
        n2 = tv_get_number(&var2);
        switch (type) {
          case TYPE_EQUAL:    n1 = (n1 == n2); break;
          case TYPE_NEQUAL:   n1 = (n1 != n2); break;
          case TYPE_GREATER:  n1 = (n1 > n2); break;
          case TYPE_GEQUAL:   n1 = (n1 >= n2); break;
          case TYPE_SMALLER:  n1 = (n1 < n2); break;
          case TYPE_SEQUAL:   n1 = (n1 <= n2); break;
          case TYPE_UNKNOWN:
          case TYPE_MATCH:
          case TYPE_NOMATCH:  break;
        }
      } else {
        char buf1[NUMBUFLEN];
        char buf2[NUMBUFLEN];
        const char *const s1 = tv_get_string_buf(rettv, buf1);
        const char *const s2 = tv_get_string_buf(&var2, buf2);
        if (type != TYPE_MATCH && type != TYPE_NOMATCH) {
          i = mb_strcmp_ic((bool)ic, s1, s2);
        } else {
          i = 0;
        }
        n1 = false;
        switch (type) {
          case TYPE_EQUAL:    n1 = (i == 0); break;
          case TYPE_NEQUAL:   n1 = (i != 0); break;
          case TYPE_GREATER:  n1 = (i > 0); break;
          case TYPE_GEQUAL:   n1 = (i >= 0); break;
          case TYPE_SMALLER:  n1 = (i < 0); break;
          case TYPE_SEQUAL:   n1 = (i <= 0); break;

          case TYPE_MATCH:
          case TYPE_NOMATCH: {
            n1 = pattern_match((char_u *)s2, (char_u *)s1, ic);
            if (type == TYPE_NOMATCH) {
              n1 = !n1;
            }
            break;
          }
          case TYPE_UNKNOWN: break;  // Avoid gcc warning.
        }
      }
      tv_clear(rettv);
      tv_clear(&var2);
      rettv->v_type = VAR_NUMBER;
      rettv->vval.v_number = n1;
    }
  }

  return OK;
}

// TODO(ZyX-I): move to eval/expressions

/*
 * Handle fourth level expression:
 *	+	number addition
 *	-	number subtraction
 *	.	string concatenation
 *	..	string concatenation
 *
 * "arg" must point to the first non-white of the expression.
 * "arg" is advanced to the next non-white after the recognized expression.
 *
 * Return OK or FAIL.
 */
static int eval5(char_u **arg, typval_T *rettv, int evaluate)
{
  typval_T var2;
  typval_T var3;
  int op;
  varnumber_T n1, n2;
  float_T f1 = 0, f2 = 0;
  char_u      *p;

  /*
   * Get the first variable.
   */
  if (eval6(arg, rettv, evaluate, FALSE) == FAIL)
    return FAIL;

  /*
   * Repeat computing, until no '+', '-' or '.' is following.
   */
  for (;; ) {
    op = **arg;
    if (op != '+' && op != '-' && op != '.')
      break;

    if ((op != '+' || rettv->v_type != VAR_LIST)
        && (op == '.' || rettv->v_type != VAR_FLOAT)) {
      // For "list + ...", an illegal use of the first operand as
      // a number cannot be determined before evaluating the 2nd
      // operand: if this is also a list, all is ok.
      // For "something . ...", "something - ..." or "non-list + ...",
      // we know that the first operand needs to be a string or number
      // without evaluating the 2nd operand.  So check before to avoid
      // side effects after an error.
      if (evaluate && !tv_check_str(rettv)) {
        tv_clear(rettv);
        return FAIL;
      }
    }

    /*
     * Get the second variable.
     */
    if (op == '.' && *(*arg + 1) == '.') {  // ..string concatenation
      (*arg)++;
    }
    *arg = skipwhite(*arg + 1);
    if (eval6(arg, &var2, evaluate, op == '.') == FAIL) {
      tv_clear(rettv);
      return FAIL;
    }

    if (evaluate) {
      /*
       * Compute the result.
       */
      if (op == '.') {
        char buf1[NUMBUFLEN];
        char buf2[NUMBUFLEN];
        // s1 already checked
        const char *const s1 = tv_get_string_buf(rettv, buf1);
        const char *const s2 = tv_get_string_buf_chk(&var2, buf2);
        if (s2 == NULL) {  // Type error?
          tv_clear(rettv);
          tv_clear(&var2);
          return FAIL;
        }
        p = concat_str((const char_u *)s1, (const char_u *)s2);
        tv_clear(rettv);
        rettv->v_type = VAR_STRING;
        rettv->vval.v_string = p;
      } else if (op == '+' && rettv->v_type == VAR_LIST
                 && var2.v_type == VAR_LIST) {
        // Concatenate Lists.
        if (tv_list_concat(rettv->vval.v_list, var2.vval.v_list, &var3)
            == FAIL) {
          tv_clear(rettv);
          tv_clear(&var2);
          return FAIL;
        }
        tv_clear(rettv);
        *rettv = var3;
      } else {
        bool error = false;

        if (rettv->v_type == VAR_FLOAT) {
          f1 = rettv->vval.v_float;
          n1 = 0;
        } else {
          n1 = tv_get_number_chk(rettv, &error);
          if (error) {
            /* This can only happen for "list + non-list".  For
             * "non-list + ..." or "something - ...", we returned
             * before evaluating the 2nd operand. */
            tv_clear(rettv);
            return FAIL;
          }
          if (var2.v_type == VAR_FLOAT)
            f1 = n1;
        }
        if (var2.v_type == VAR_FLOAT) {
          f2 = var2.vval.v_float;
          n2 = 0;
        } else {
          n2 = tv_get_number_chk(&var2, &error);
          if (error) {
            tv_clear(rettv);
            tv_clear(&var2);
            return FAIL;
          }
          if (rettv->v_type == VAR_FLOAT)
            f2 = n2;
        }
        tv_clear(rettv);

        /* If there is a float on either side the result is a float. */
        if (rettv->v_type == VAR_FLOAT || var2.v_type == VAR_FLOAT) {
          if (op == '+')
            f1 = f1 + f2;
          else
            f1 = f1 - f2;
          rettv->v_type = VAR_FLOAT;
          rettv->vval.v_float = f1;
        } else {
          if (op == '+')
            n1 = n1 + n2;
          else
            n1 = n1 - n2;
          rettv->v_type = VAR_NUMBER;
          rettv->vval.v_number = n1;
        }
      }
      tv_clear(&var2);
    }
  }
  return OK;
}

// TODO(ZyX-I): move to eval/expressions

/// Handle fifth level expression:
///  - *  number multiplication
///  - /  number division
///  - %  number modulo
///
/// @param[in,out]  arg  Points to the first non-whitespace character of the
///                      expression.  Is advanced to the next non-whitespace
///                      character after the recognized expression.
/// @param[out]  rettv  Location where result is saved.
/// @param[in]  evaluate  If not true, rettv is not populated.
/// @param[in]  want_string  True if "." is string_concatenation, otherwise
///                          float
/// @return  OK or FAIL.
static int eval6(char_u **arg, typval_T *rettv, int evaluate, int want_string)
  FUNC_ATTR_NO_SANITIZE_UNDEFINED
{
  typval_T var2;
  int op;
  varnumber_T n1, n2;
  bool use_float = false;
  float_T f1 = 0, f2 = 0;
  bool error = false;

  /*
   * Get the first variable.
   */
  if (eval7(arg, rettv, evaluate, want_string) == FAIL)
    return FAIL;

  /*
   * Repeat computing, until no '*', '/' or '%' is following.
   */
  for (;; ) {
    op = **arg;
    if (op != '*' && op != '/' && op != '%')
      break;

    if (evaluate) {
      if (rettv->v_type == VAR_FLOAT) {
        f1 = rettv->vval.v_float;
        use_float = true;
        n1 = 0;
      } else {
        n1 = tv_get_number_chk(rettv, &error);
      }
      tv_clear(rettv);
      if (error) {
        return FAIL;
      }
    } else {
      n1 = 0;
    }

    /*
     * Get the second variable.
     */
    *arg = skipwhite(*arg + 1);
    if (eval7(arg, &var2, evaluate, FALSE) == FAIL)
      return FAIL;

    if (evaluate) {
      if (var2.v_type == VAR_FLOAT) {
        if (!use_float) {
          f1 = n1;
          use_float = true;
        }
        f2 = var2.vval.v_float;
        n2 = 0;
      } else {
        n2 = tv_get_number_chk(&var2, &error);
        tv_clear(&var2);
        if (error) {
          return FAIL;
        }
        if (use_float) {
          f2 = n2;
        }
      }

      /*
       * Compute the result.
       * When either side is a float the result is a float.
       */
      if (use_float) {
        if (op == '*') {
          f1 = f1 * f2;
        } else if (op == '/') {
          // Division by zero triggers error from AddressSanitizer
          f1 = (f2 == 0
                ? (
#ifdef NAN
                    f1 == 0
                    ? NAN
                    :
#endif
                    (f1 > 0
                     ? INFINITY
                     : -INFINITY)
                )
                : f1 / f2);
        } else {
          EMSG(_("E804: Cannot use '%' with Float"));
          return FAIL;
        }
        rettv->v_type = VAR_FLOAT;
        rettv->vval.v_float = f1;
      } else {
        if (op == '*') {
          n1 = n1 * n2;
        } else if (op == '/') {
          n1 = num_divide(n1, n2);
        } else {
          n1 = num_modulus(n1, n2);
        }
        rettv->v_type = VAR_NUMBER;
        rettv->vval.v_number = n1;
      }
    }
  }

  return OK;
}

// TODO(ZyX-I): move to eval/expressions

// Handle sixth level expression:
//  number  number constant
//  "string"  string constant
//  'string'  literal string constant
//  &option-name option value
//  @r   register contents
//  identifier  variable value
//  function()  function call
//  $VAR  environment variable
//  (expression) nested expression
//  [expr, expr] List
//  {key: val, key: val}  Dictionary
//
//  Also handle:
//  ! in front  logical NOT
//  - in front  unary minus
//  + in front  unary plus (ignored)
//  trailing []  subscript in String or List
//  trailing .name entry in Dictionary
//
// "arg" must point to the first non-white of the expression.
// "arg" is advanced to the next non-white after the recognized expression.
//
// Return OK or FAIL.
static int eval7(
    char_u **arg,
    typval_T *rettv,
    int evaluate,
    int want_string                 // after "." operator
)
{
  varnumber_T n;
  int len;
  char_u      *s;
  char_u      *start_leader, *end_leader;
  int ret = OK;
  char_u      *alias;

  // Initialise variable so that tv_clear() can't mistake this for a
  // string and free a string that isn't there.
  rettv->v_type = VAR_UNKNOWN;

  // Skip '!', '-' and '+' characters.  They are handled later.
  start_leader = *arg;
  while (**arg == '!' || **arg == '-' || **arg == '+') {
    *arg = skipwhite(*arg + 1);
  }
  end_leader = *arg;

  switch (**arg) {
  // Number constant.
  case '0':
  case '1':
  case '2':
  case '3':
  case '4':
  case '5':
  case '6':
  case '7':
  case '8':
  case '9':
  {
    char_u *p = skipdigits(*arg + 1);
    int get_float = false;

    // We accept a float when the format matches
    // "[0-9]\+\.[0-9]\+\([eE][+-]\?[0-9]\+\)\?".  This is very
    // strict to avoid backwards compatibility problems.
    // Don't look for a float after the "." operator, so that
    // ":let vers = 1.2.3" doesn't fail.
    if (!want_string && p[0] == '.' && ascii_isdigit(p[1])) {
      get_float = true;
      p = skipdigits(p + 2);
      if (*p == 'e' || *p == 'E') {
        ++p;
        if (*p == '-' || *p == '+') {
          ++p;
        }
        if (!ascii_isdigit(*p)) {
          get_float = false;
        } else {
          p = skipdigits(p + 1);
        }
      }
      if (ASCII_ISALPHA(*p) || *p == '.') {
        get_float = false;
      }
    }
    if (get_float) {
      float_T f;

      *arg += string2float((char *) *arg, &f);
      if (evaluate) {
        rettv->v_type = VAR_FLOAT;
        rettv->vval.v_float = f;
      }
    } else {
      vim_str2nr(*arg, NULL, &len, STR2NR_ALL, &n, NULL, 0);
      *arg += len;
      if (evaluate) {
        rettv->v_type = VAR_NUMBER;
        rettv->vval.v_number = n;
      }
    }
    break;
  }

  // String constant: "string".
  case '"':   ret = get_string_tv(arg, rettv, evaluate);
    break;

  // Literal string constant: 'str''ing'.
  case '\'':  ret = get_lit_string_tv(arg, rettv, evaluate);
    break;

  // List: [expr, expr]
  case '[':   ret = get_list_tv(arg, rettv, evaluate);
    break;

  // Lambda: {arg, arg -> expr}
  // Dictionary: {key: val, key: val}
  case '{':   ret = get_lambda_tv(arg, rettv, evaluate);
              if (ret == NOTDONE) {
                ret = dict_get_tv(arg, rettv, evaluate);
              }
    break;

  // Option value: &name
  case '&': {
    ret = get_option_tv((const char **)arg, rettv, evaluate);
    break;
  }
  // Environment variable: $VAR.
  case '$':   ret = get_env_tv(arg, rettv, evaluate);
    break;

  // Register contents: @r.
  case '@':   ++*arg;
    if (evaluate) {
      rettv->v_type = VAR_STRING;
      rettv->vval.v_string = get_reg_contents(**arg, kGRegExprSrc);
    }
    if (**arg != NUL) {
      ++*arg;
    }
    break;

  // nested expression: (expression).
  case '(':   *arg = skipwhite(*arg + 1);
    ret = eval1(arg, rettv, evaluate);                  // recursive!
    if (**arg == ')') {
      ++*arg;
    } else if (ret == OK) {
      EMSG(_("E110: Missing ')'"));
      tv_clear(rettv);
      ret = FAIL;
    }
    break;

  default:    ret = NOTDONE;
    break;
  }

  if (ret == NOTDONE) {
    // Must be a variable or function name.
    // Can also be a curly-braces kind of name: {expr}.
    s = *arg;
    len = get_name_len((const char **)arg, (char **)&alias, evaluate, true);
    if (alias != NULL) {
      s = alias;
    }

    if (len <= 0) {
      ret = FAIL;
    } else {
      if (**arg == '(') {               // recursive!
        partial_T *partial;

        if (!evaluate) {
          check_vars((const char *)s, len);
        }

        // If "s" is the name of a variable of type VAR_FUNC
        // use its contents.
        s = deref_func_name((const char *)s, &len, &partial, !evaluate);

        // Need to make a copy, in case evaluating the arguments makes
        // the name invalid.
        s = xmemdupz(s, len);

        // Invoke the function.
        ret = get_func_tv(s, len, rettv, arg,
                          curwin->w_cursor.lnum, curwin->w_cursor.lnum,
                          &len, evaluate, partial, NULL);

        xfree(s);

        // If evaluate is false rettv->v_type was not set in
        // get_func_tv, but it's needed in handle_subscript() to parse
        // what follows. So set it here.
        if (rettv->v_type == VAR_UNKNOWN && !evaluate && **arg == '(') {
          rettv->vval.v_string = (char_u *)tv_empty_string;
          rettv->v_type = VAR_FUNC;
        }

        // Stop the expression evaluation when immediately
        // aborting on error, or when an interrupt occurred or
        // an exception was thrown but not caught.
        if (evaluate && aborting()) {
          if (ret == OK) {
            tv_clear(rettv);
          }
          ret = FAIL;
        }
      } else if (evaluate) {
        ret = get_var_tv((const char *)s, len, rettv, NULL, true, false);
      } else {
        check_vars((const char *)s, len);
        ret = OK;
      }
    }
    xfree(alias);
  }

  *arg = skipwhite(*arg);

  // Handle following '[', '(' and '.' for expr[expr], expr.name,
  // expr(expr).
  if (ret == OK) {
    ret = handle_subscript((const char **)arg, rettv, evaluate, true);
  }

  // Apply logical NOT and unary '-', from right to left, ignore '+'.
  if (ret == OK && evaluate && end_leader > start_leader) {
    bool error = false;
    varnumber_T val = 0;
    float_T f = 0.0;

    if (rettv->v_type == VAR_FLOAT) {
      f = rettv->vval.v_float;
    } else {
      val = tv_get_number_chk(rettv, &error);
    }
    if (error) {
      tv_clear(rettv);
      ret = FAIL;
    } else {
      while (end_leader > start_leader) {
        --end_leader;
        if (*end_leader == '!') {
          if (rettv->v_type == VAR_FLOAT) {
            f = !f;
          } else {
            val = !val;
          }
        } else if (*end_leader == '-') {
          if (rettv->v_type == VAR_FLOAT) {
            f = -f;
          } else {
            val = -val;
          }
        }
      }
      if (rettv->v_type == VAR_FLOAT) {
        tv_clear(rettv);
        rettv->vval.v_float = f;
      } else {
        tv_clear(rettv);
        rettv->v_type = VAR_NUMBER;
        rettv->vval.v_number = val;
      }
    }
  }

  return ret;
}

// TODO(ZyX-I): move to eval/expressions

/*
 * Evaluate an "[expr]" or "[expr:expr]" index.  Also "dict.key".
 * "*arg" points to the '[' or '.'.
 * Returns FAIL or OK. "*arg" is advanced to after the ']'.
 */
static int
eval_index(
    char_u **arg,
    typval_T *rettv,
    int evaluate,
    int verbose                    /* give error messages */
)
{
  bool empty1 = false;
  bool empty2 = false;
  long n1, n2 = 0;
  ptrdiff_t len = -1;
  int range = false;
  char_u      *key = NULL;

  switch (rettv->v_type) {
    case VAR_FUNC:
    case VAR_PARTIAL: {
      if (verbose) {
        EMSG(_("E695: Cannot index a Funcref"));
      }
      return FAIL;
    }
    case VAR_FLOAT: {
      if (verbose) {
        EMSG(_(e_float_as_string));
      }
      return FAIL;
    }
    case VAR_SPECIAL: {
      if (verbose) {
        EMSG(_("E909: Cannot index a special variable"));
      }
      return FAIL;
    }
    case VAR_UNKNOWN: {
      if (evaluate) {
        return FAIL;
      }
      FALLTHROUGH;
    }
    case VAR_STRING:
    case VAR_NUMBER:
    case VAR_LIST:
    case VAR_DICT: {
      break;
    }
  }

  typval_T var1 = TV_INITIAL_VALUE;
  typval_T var2 = TV_INITIAL_VALUE;
  if (**arg == '.') {
    /*
     * dict.name
     */
    key = *arg + 1;
    for (len = 0; ASCII_ISALNUM(key[len]) || key[len] == '_'; ++len)
      ;
    if (len == 0)
      return FAIL;
    *arg = skipwhite(key + len);
  } else {
    /*
     * something[idx]
     *
     * Get the (first) variable from inside the [].
     */
    *arg = skipwhite(*arg + 1);
    if (**arg == ':') {
      empty1 = true;
    } else if (eval1(arg, &var1, evaluate) == FAIL) {  // Recursive!
      return FAIL;
    } else if (evaluate && !tv_check_str(&var1)) {
      // Not a number or string.
      tv_clear(&var1);
      return FAIL;
    }

    /*
     * Get the second variable from inside the [:].
     */
    if (**arg == ':') {
      range = TRUE;
      *arg = skipwhite(*arg + 1);
      if (**arg == ']') {
        empty2 = true;
      } else if (eval1(arg, &var2, evaluate) == FAIL) {  // Recursive!
        if (!empty1) {
          tv_clear(&var1);
        }
        return FAIL;
      } else if (evaluate && !tv_check_str(&var2)) {
        // Not a number or string.
        if (!empty1) {
          tv_clear(&var1);
        }
        tv_clear(&var2);
        return FAIL;
      }
    }

    /* Check for the ']'. */
    if (**arg != ']') {
      if (verbose) {
        EMSG(_(e_missbrac));
      }
      tv_clear(&var1);
      if (range) {
        tv_clear(&var2);
      }
      return FAIL;
    }
    *arg = skipwhite(*arg + 1);         /* skip the ']' */
  }

  if (evaluate) {
    n1 = 0;
    if (!empty1 && rettv->v_type != VAR_DICT && !tv_is_luafunc(rettv)) {
      n1 = tv_get_number(&var1);
      tv_clear(&var1);
    }
    if (range) {
      if (empty2) {
        n2 = -1;
      } else {
        n2 = tv_get_number(&var2);
        tv_clear(&var2);
      }
    }

    switch (rettv->v_type) {
      case VAR_NUMBER:
      case VAR_STRING: {
        const char *const s = tv_get_string(rettv);
        char *v;
        len = (ptrdiff_t)strlen(s);
        if (range) {
          // The resulting variable is a substring.  If the indexes
          // are out of range the result is empty.
          if (n1 < 0) {
            n1 = len + n1;
            if (n1 < 0) {
              n1 = 0;
            }
          }
          if (n2 < 0) {
            n2 = len + n2;
          } else if (n2 >= len) {
            n2 = len;
          }
          if (n1 >= len || n2 < 0 || n1 > n2) {
            v = NULL;
          } else {
            v = xmemdupz(s + n1, (size_t)(n2 - n1 + 1));
          }
        } else {
          // The resulting variable is a string of a single
          // character.  If the index is too big or negative the
          // result is empty.
          if (n1 >= len || n1 < 0) {
            v = NULL;
          } else {
            v = xmemdupz(s + n1, 1);
          }
        }
        tv_clear(rettv);
        rettv->v_type = VAR_STRING;
        rettv->vval.v_string = (char_u *)v;
        break;
      }
      case VAR_LIST: {
        len = tv_list_len(rettv->vval.v_list);
        if (n1 < 0) {
          n1 = len + n1;
        }
        if (!empty1 && (n1 < 0 || n1 >= len)) {
          // For a range we allow invalid values and return an empty
          // list.  A list index out of range is an error.
          if (!range) {
            if (verbose) {
              EMSGN(_(e_listidx), n1);
            }
            return FAIL;
          }
          n1 = len;
        }
        if (range) {
          list_T      *l;
          listitem_T  *item;

          if (n2 < 0) {
            n2 = len + n2;
          } else if (n2 >= len) {
            n2 = len - 1;
          }
          if (!empty2 && (n2 < 0 || n2 + 1 < n1)) {
            n2 = -1;
          }
          l = tv_list_alloc(n2 - n1 + 1);
          item = tv_list_find(rettv->vval.v_list, n1);
          while (n1++ <= n2) {
            tv_list_append_tv(l, TV_LIST_ITEM_TV(item));
            item = TV_LIST_ITEM_NEXT(rettv->vval.v_list, item);
          }
          tv_clear(rettv);
          tv_list_set_ret(rettv, l);
        } else {
          tv_copy(TV_LIST_ITEM_TV(tv_list_find(rettv->vval.v_list, n1)), &var1);
          tv_clear(rettv);
          *rettv = var1;
        }
        break;
      }
      case VAR_DICT: {
        if (range) {
          if (verbose) {
            EMSG(_(e_dictrange));
          }
          if (len == -1) {
            tv_clear(&var1);
          }
          return FAIL;
        }

        if (len == -1) {
          key = (char_u *)tv_get_string_chk(&var1);
          if (key == NULL) {
            tv_clear(&var1);
            return FAIL;
          }
        }

        dictitem_T *const item = tv_dict_find(rettv->vval.v_dict,
                                              (const char *)key, len);

        if (item == NULL && verbose) {
          emsgf(_(e_dictkey), key);
        }
        if (len == -1) {
          tv_clear(&var1);
        }
        if (item == NULL || tv_is_luafunc(&item->di_tv)) {
          return FAIL;
        }

        tv_copy(&item->di_tv, &var1);
        tv_clear(rettv);
        *rettv = var1;
        break;
      }
      case VAR_SPECIAL:
      case VAR_FUNC:
      case VAR_FLOAT:
      case VAR_PARTIAL:
      case VAR_UNKNOWN: {
        break;  // Not evaluating, skipping over subscript
      }
    }
  }

  return OK;
}

// TODO(ZyX-I): move to eval/executor

/// Get an option value
///
/// @param[in,out]  arg  Points to the '&' or '+' before the option name. Is
///                      advanced to the character after the option name.
/// @param[out]  rettv  Location where result is saved.
/// @param[in]  evaluate  If not true, rettv is not populated.
///
/// @return OK or FAIL.
int get_option_tv(const char **const arg, typval_T *const rettv,
                  const bool evaluate)
  FUNC_ATTR_NONNULL_ARG(1)
{
  long numval;
  char_u      *stringval;
  int opt_type;
  int c;
  bool working = (**arg == '+');  // has("+option")
  int ret = OK;
  int opt_flags;

  // Isolate the option name and find its value.
  char *option_end = (char *)find_option_end(arg, &opt_flags);
  if (option_end == NULL) {
    if (rettv != NULL) {
      EMSG2(_("E112: Option name missing: %s"), *arg);
    }
    return FAIL;
  }

  if (!evaluate) {
    *arg = option_end;
    return OK;
  }

  c = *option_end;
  *option_end = NUL;
  opt_type = get_option_value((char_u *)(*arg), &numval,
                              rettv == NULL ? NULL : &stringval, opt_flags);

  if (opt_type == -3) {                 /* invalid name */
    if (rettv != NULL)
      EMSG2(_("E113: Unknown option: %s"), *arg);
    ret = FAIL;
  } else if (rettv != NULL)   {
    if (opt_type == -2) {               /* hidden string option */
      rettv->v_type = VAR_STRING;
      rettv->vval.v_string = NULL;
    } else if (opt_type == -1) {      /* hidden number option */
      rettv->v_type = VAR_NUMBER;
      rettv->vval.v_number = 0;
    } else if (opt_type == 1) {       /* number option */
      rettv->v_type = VAR_NUMBER;
      rettv->vval.v_number = numval;
    } else {                          /* string option */
      rettv->v_type = VAR_STRING;
      rettv->vval.v_string = stringval;
    }
  } else if (working && (opt_type == -2 || opt_type == -1))
    ret = FAIL;

  *option_end = c;                  /* put back for error messages */
  *arg = option_end;

  return ret;
}

/*
 * Allocate a variable for a string constant.
 * Return OK or FAIL.
 */
static int get_string_tv(char_u **arg, typval_T *rettv, int evaluate)
{
  char_u      *p;
  char_u      *name;
  unsigned int extra = 0;

  /*
   * Find the end of the string, skipping backslashed characters.
   */
  for (p = *arg + 1; *p != NUL && *p != '"'; MB_PTR_ADV(p)) {
    if (*p == '\\' && p[1] != NUL) {
      ++p;
      /* A "\<x>" form occupies at least 4 characters, and produces up
       * to 6 characters: reserve space for 2 extra */
      if (*p == '<')
        extra += 2;
    }
  }

  if (*p != '"') {
    EMSG2(_("E114: Missing quote: %s"), *arg);
    return FAIL;
  }

  /* If only parsing, set *arg and return here */
  if (!evaluate) {
    *arg = p + 1;
    return OK;
  }

  /*
   * Copy the string into allocated memory, handling backslashed
   * characters.
   */
  name = xmalloc(p - *arg + extra);
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = name;

  for (p = *arg + 1; *p != NUL && *p != '"'; ) {
    if (*p == '\\') {
      switch (*++p) {
      case 'b': *name++ = BS; ++p; break;
      case 'e': *name++ = ESC; ++p; break;
      case 'f': *name++ = FF; ++p; break;
      case 'n': *name++ = NL; ++p; break;
      case 'r': *name++ = CAR; ++p; break;
      case 't': *name++ = TAB; ++p; break;

      case 'X':           /* hex: "\x1", "\x12" */
      case 'x':
      case 'u':           /* Unicode: "\u0023" */
      case 'U':
        if (ascii_isxdigit(p[1])) {
          int n, nr;
          int c = toupper(*p);

          if (c == 'X') {
            n = 2;
          } else if (*p == 'u') {
            n = 4;
          } else {
            n = 8;
          }
          nr = 0;
          while (--n >= 0 && ascii_isxdigit(p[1])) {
            ++p;
            nr = (nr << 4) + hex2nr(*p);
          }
          ++p;
          /* For "\u" store the number according to
           * 'encoding'. */
          if (c != 'X') {
            name += utf_char2bytes(nr, name);
          } else {
            *name++ = nr;
          }
        }
        break;

      /* octal: "\1", "\12", "\123" */
      case '0':
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7': *name = *p++ - '0';
        if (*p >= '0' && *p <= '7') {
          *name = (*name << 3) + *p++ - '0';
          if (*p >= '0' && *p <= '7')
            *name = (*name << 3) + *p++ - '0';
        }
        ++name;
        break;

      // Special key, e.g.: "\<C-W>"
      case '<':
        extra = trans_special((const char_u **)&p, STRLEN(p), name, true, true);
        if (extra != 0) {
          name += extra;
          break;
        }
        FALLTHROUGH;

      default:  MB_COPY_CHAR(p, name);
        break;
      }
    } else
      MB_COPY_CHAR(p, name);

  }
  *name = NUL;
  if (*p != NUL) {  // just in case
    p++;
  }
  *arg = p;

  return OK;
}

/*
 * Allocate a variable for a 'str''ing' constant.
 * Return OK or FAIL.
 */
static int get_lit_string_tv(char_u **arg, typval_T *rettv, int evaluate)
{
  char_u      *p;
  char_u      *str;
  int reduce = 0;

  /*
   * Find the end of the string, skipping ''.
   */
  for (p = *arg + 1; *p != NUL; MB_PTR_ADV(p)) {
    if (*p == '\'') {
      if (p[1] != '\'')
        break;
      ++reduce;
      ++p;
    }
  }

  if (*p != '\'') {
    EMSG2(_("E115: Missing quote: %s"), *arg);
    return FAIL;
  }

  /* If only parsing return after setting "*arg" */
  if (!evaluate) {
    *arg = p + 1;
    return OK;
  }

  /*
   * Copy the string into allocated memory, handling '' to ' reduction.
   */
  str = xmalloc((p - *arg) - reduce);
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = str;

  for (p = *arg + 1; *p != NUL; ) {
    if (*p == '\'') {
      if (p[1] != '\'')
        break;
      ++p;
    }
    MB_COPY_CHAR(p, str);
  }
  *str = NUL;
  *arg = p + 1;

  return OK;
}

/// @return the function name of the partial.
char_u *partial_name(partial_T *pt)
{
  if (pt->pt_name != NULL) {
    return pt->pt_name;
  }
  return pt->pt_func->uf_name;
}

// TODO(ZyX-I): Move to eval/typval.h

static void partial_free(partial_T *pt)
{
  for (int i = 0; i < pt->pt_argc; i++) {
    tv_clear(&pt->pt_argv[i]);
  }
  xfree(pt->pt_argv);
  tv_dict_unref(pt->pt_dict);
  if (pt->pt_name != NULL) {
    func_unref(pt->pt_name);
    xfree(pt->pt_name);
  } else {
    func_ptr_unref(pt->pt_func);
  }
  xfree(pt);
}

// TODO(ZyX-I): Move to eval/typval.h

/// Unreference a closure: decrement the reference count and free it when it
/// becomes zero.
void partial_unref(partial_T *pt)
{
  if (pt != NULL && --pt->pt_refcount <= 0) {
    partial_free(pt);
  }
}

/// Allocate a variable for a List and fill it from "*arg".
/// Return OK or FAIL.
static int get_list_tv(char_u **arg, typval_T *rettv, int evaluate)
{
  list_T      *l = NULL;

  if (evaluate) {
    l = tv_list_alloc(kListLenShouldKnow);
  }

  *arg = skipwhite(*arg + 1);
  while (**arg != ']' && **arg != NUL) {
    typval_T tv;
    if (eval1(arg, &tv, evaluate) == FAIL) {  // Recursive!
      goto failret;
    }
    if (evaluate) {
      tv.v_lock = VAR_UNLOCKED;
      tv_list_append_owned_tv(l, tv);
    }

    if (**arg == ']') {
      break;
    }
    if (**arg != ',') {
      emsgf(_("E696: Missing comma in List: %s"), *arg);
      goto failret;
    }
    *arg = skipwhite(*arg + 1);
  }

  if (**arg != ']') {
    emsgf(_("E697: Missing end of List ']': %s"), *arg);
failret:
    if (evaluate) {
      tv_list_free(l);
    }
    return FAIL;
  }

  *arg = skipwhite(*arg + 1);
  if (evaluate) {
    tv_list_set_ret(rettv, l);
  }

  return OK;
}

bool func_equal(
    typval_T *tv1,
    typval_T *tv2,
    bool ic         // ignore case
) {
  char_u *s1, *s2;
  dict_T *d1, *d2;
  int a1, a2;

  // empty and NULL function name considered the same
  s1 = tv1->v_type == VAR_FUNC ? tv1->vval.v_string
                     : partial_name(tv1->vval.v_partial);
  if (s1 != NULL && *s1 == NUL) {
    s1 = NULL;
  }
  s2 = tv2->v_type == VAR_FUNC ? tv2->vval.v_string
                     : partial_name(tv2->vval.v_partial);
  if (s2 != NULL && *s2 == NUL) {
    s2 = NULL;
  }
  if (s1 == NULL || s2 == NULL) {
    if (s1 != s2) {
      return false;
    }
  } else if (STRCMP(s1, s2) != 0) {
    return false;
  }

  // empty dict and NULL dict is different
  d1 = tv1->v_type == VAR_FUNC ? NULL : tv1->vval.v_partial->pt_dict;
  d2 = tv2->v_type == VAR_FUNC ? NULL : tv2->vval.v_partial->pt_dict;
  if (d1 == NULL || d2 == NULL) {
    if (d1 != d2) {
      return false;
    }
  } else if (!tv_dict_equal(d1, d2, ic, true)) {
    return false;
  }

  // empty list and no list considered the same
  a1 = tv1->v_type == VAR_FUNC ? 0 : tv1->vval.v_partial->pt_argc;
  a2 = tv2->v_type == VAR_FUNC ? 0 : tv2->vval.v_partial->pt_argc;
  if (a1 != a2) {
    return false;
  }
  for (int i = 0; i < a1; i++) {
    if (!tv_equal(tv1->vval.v_partial->pt_argv + i,
                  tv2->vval.v_partial->pt_argv + i, ic, true)) {
      return false;
    }
  }
  return true;
}

/// Get next (unique) copy ID
///
/// Used for traversing nested structures e.g. when serializing them or garbage
/// collecting.
int get_copyID(void)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  // CopyID for recursively traversing lists and dicts
  //
  // This value is needed to avoid endless recursiveness. Last bit is used for
  // previous_funccal and normally ignored when comparing.
  static int current_copyID = 0;
  current_copyID += COPYID_INC;
  return current_copyID;
}

// Used by get_func_tv()
static garray_T funcargs = GA_EMPTY_INIT_VALUE;

/*
 * Garbage collection for lists and dictionaries.
 *
 * We use reference counts to be able to free most items right away when they
 * are no longer used.  But for composite items it's possible that it becomes
 * unused while the reference count is > 0: When there is a recursive
 * reference.  Example:
 *	:let l = [1, 2, 3]
 *	:let d = {9: l}
 *	:let l[1] = d
 *
 * Since this is quite unusual we handle this with garbage collection: every
 * once in a while find out which lists and dicts are not referenced from any
 * variable.
 *
 * Here is a good reference text about garbage collection (refers to Python
 * but it applies to all reference-counting mechanisms):
 *	http://python.ca/nas/python/gc/
 */

/// Do garbage collection for lists and dicts.
///
/// @param testing  true if called from test_garbagecollect_now().
/// @returns        true if some memory was freed.
bool garbage_collect(bool testing)
{
  bool abort = false;
#define ABORTING(func) abort = abort || func

  if (!testing) {
    // Only do this once.
    want_garbage_collect = false;
    may_garbage_collect = false;
    garbage_collect_at_exit = false;
  }

  // We advance by two (COPYID_INC) because we add one for items referenced
  // through previous_funccal.
  const int copyID = get_copyID();

  // 1. Go through all accessible variables and mark all lists and dicts
  // with copyID.

  // Don't free variables in the previous_funccal list unless they are only
  // referenced through previous_funccal.  This must be first, because if
  // the item is referenced elsewhere the funccal must not be freed.
  for (funccall_T *fc = previous_funccal; fc != NULL; fc = fc->caller) {
    fc->fc_copyID = copyID + 1;
    ABORTING(set_ref_in_ht)(&fc->l_vars.dv_hashtab, copyID + 1, NULL);
    ABORTING(set_ref_in_ht)(&fc->l_avars.dv_hashtab, copyID + 1, NULL);
  }

  // script-local variables
  for (int i = 1; i <= ga_scripts.ga_len; ++i) {
    ABORTING(set_ref_in_ht)(&SCRIPT_VARS(i), copyID, NULL);
  }

  FOR_ALL_BUFFERS(buf) {
    // buffer-local variables
    ABORTING(set_ref_in_item)(&buf->b_bufvar.di_tv, copyID, NULL, NULL);
    // buffer marks (ShaDa additional data)
    ABORTING(set_ref_in_fmark)(buf->b_last_cursor, copyID);
    ABORTING(set_ref_in_fmark)(buf->b_last_insert, copyID);
    ABORTING(set_ref_in_fmark)(buf->b_last_change, copyID);
    for (size_t i = 0; i < NMARKS; i++) {
      ABORTING(set_ref_in_fmark)(buf->b_namedm[i], copyID);
    }
    // buffer change list (ShaDa additional data)
    for (int i = 0; i < buf->b_changelistlen; i++) {
      ABORTING(set_ref_in_fmark)(buf->b_changelist[i], copyID);
    }
    // buffer ShaDa additional data
    ABORTING(set_ref_dict)(buf->additional_data, copyID);

    // buffer callback functions
    set_ref_in_callback(&buf->b_prompt_callback, copyID, NULL, NULL);
    set_ref_in_callback(&buf->b_prompt_interrupt, copyID, NULL, NULL);
  }

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    // window-local variables
    ABORTING(set_ref_in_item)(&wp->w_winvar.di_tv, copyID, NULL, NULL);
    // window jump list (ShaDa additional data)
    for (int i = 0; i < wp->w_jumplistlen; i++) {
      ABORTING(set_ref_in_fmark)(wp->w_jumplist[i].fmark, copyID);
    }
  }
  if (aucmd_win != NULL) {
    ABORTING(set_ref_in_item)(&aucmd_win->w_winvar.di_tv, copyID, NULL, NULL);
  }

  // registers (ShaDa additional data)
  {
    const void *reg_iter = NULL;
    do {
      yankreg_T reg;
      char name = NUL;
      bool is_unnamed = false;
      reg_iter = op_global_reg_iter(reg_iter, &name, &reg, &is_unnamed);
      if (name != NUL) {
        ABORTING(set_ref_dict)(reg.additional_data, copyID);
      }
    } while (reg_iter != NULL);
  }

  // global marks (ShaDa additional data)
  {
    const void *mark_iter = NULL;
    do {
      xfmark_T fm;
      char name = NUL;
      mark_iter = mark_global_iter(mark_iter, &name, &fm);
      if (name != NUL) {
        ABORTING(set_ref_dict)(fm.fmark.additional_data, copyID);
      }
    } while (mark_iter != NULL);
  }

  // tabpage-local variables
  FOR_ALL_TABS(tp) {
    ABORTING(set_ref_in_item)(&tp->tp_winvar.di_tv, copyID, NULL, NULL);
  }

  // global variables
  ABORTING(set_ref_in_ht)(&globvarht, copyID, NULL);

  // function-local variables
  for (funccall_T *fc = current_funccal; fc != NULL; fc = fc->caller) {
    fc->fc_copyID = copyID;
    ABORTING(set_ref_in_ht)(&fc->l_vars.dv_hashtab, copyID, NULL);
    ABORTING(set_ref_in_ht)(&fc->l_avars.dv_hashtab, copyID, NULL);
  }

  // named functions (matters for closures)
  ABORTING(set_ref_in_functions(copyID));

  // Channels
  {
    Channel *data;
    map_foreach_value(channels, data, {
      set_ref_in_callback_reader(&data->on_data, copyID, NULL, NULL);
      set_ref_in_callback_reader(&data->on_stderr, copyID, NULL, NULL);
      set_ref_in_callback(&data->on_exit, copyID, NULL, NULL);
    })
  }

  // Timers
  {
    timer_T *timer;
    map_foreach_value(timers, timer, {
      set_ref_in_callback(&timer->callback, copyID, NULL, NULL);
    })
  }

  // function call arguments, if v:testing is set.
  for (int i = 0; i < funcargs.ga_len; i++) {
    ABORTING(set_ref_in_item)(((typval_T **)funcargs.ga_data)[i],
                              copyID, NULL, NULL);
  }

  // v: vars
  ABORTING(set_ref_in_ht)(&vimvarht, copyID, NULL);

  // history items (ShaDa additional elements)
  if (p_hi) {
    for (uint8_t i = 0; i < HIST_COUNT; i++) {
      const void *iter = NULL;
      do {
        histentry_T hist;
        iter = hist_iter(iter, i, false, &hist);
        if (hist.hisstr != NULL) {
          ABORTING(set_ref_list)(hist.additional_elements, copyID);
        }
      } while (iter != NULL);
    }
  }

  // previously used search/substitute patterns (ShaDa additional data)
  {
    SearchPattern pat;
    get_search_pattern(&pat);
    ABORTING(set_ref_dict)(pat.additional_data, copyID);
    get_substitute_pattern(&pat);
    ABORTING(set_ref_dict)(pat.additional_data, copyID);
  }

  // previously used replacement string
  {
    SubReplacementString sub;
    sub_get_replacement(&sub);
    ABORTING(set_ref_list)(sub.additional_elements, copyID);
  }

  ABORTING(set_ref_in_quickfix)(copyID);

  bool did_free = false;
  if (!abort) {
    // 2. Free lists and dictionaries that are not referenced.
    did_free = free_unref_items(copyID);

    // 3. Check if any funccal can be freed now.
    bool did_free_funccal = false;
    for (funccall_T **pfc = &previous_funccal; *pfc != NULL;) {
      if (can_free_funccal(*pfc, copyID)) {
        funccall_T *fc = *pfc;
        *pfc = fc->caller;
        free_funccal(fc, true);
        did_free = true;
        did_free_funccal = true;
      } else {
        pfc = &(*pfc)->caller;
      }
    }
    if (did_free_funccal) {
      // When a funccal was freed some more items might be garbage
      // collected, so run again.
      (void)garbage_collect(testing);
    }
  } else if (p_verbose > 0) {
    verb_msg(_(
        "Not enough memory to set references, garbage collection aborted!"));
  }
#undef ABORTING
  return did_free;
}

/// Free lists and dictionaries that are no longer referenced.
///
/// @note This function may only be called from garbage_collect().
///
/// @param copyID Free lists/dictionaries that don't have this ID.
/// @return true, if something was freed.
static int free_unref_items(int copyID)
{
  bool did_free = false;

  // Let all "free" functions know that we are here. This means no
  // dictionaries, lists, or jobs are to be freed, because we will
  // do that here.
  tv_in_free_unref_items = true;

  // PASS 1: free the contents of the items. We don't free the items
  // themselves yet, so that it is possible to decrement refcount counters.

  // Go through the list of dicts and free items without the copyID.
  // Don't free dicts that are referenced internally.
  for (dict_T *dd = gc_first_dict; dd != NULL; dd = dd->dv_used_next) {
    if ((dd->dv_copyID & COPYID_MASK) != (copyID & COPYID_MASK)) {
      // Free the Dictionary and ordinary items it contains, but don't
      // recurse into Lists and Dictionaries, they will be in the list
      // of dicts or list of lists.
      tv_dict_free_contents(dd);
      did_free = true;
    }
  }

  // Go through the list of lists and free items without the copyID.
  // But don't free a list that has a watcher (used in a for loop), these
  // are not referenced anywhere.
  for (list_T *ll = gc_first_list; ll != NULL; ll = ll->lv_used_next) {
    if ((tv_list_copyid(ll) & COPYID_MASK) != (copyID & COPYID_MASK)
        && !tv_list_has_watchers(ll)) {
      // Free the List and ordinary items it contains, but don't recurse
      // into Lists and Dictionaries, they will be in the list of dicts
      // or list of lists.
      tv_list_free_contents(ll);
      did_free = true;
    }
  }

  // PASS 2: free the items themselves.
  dict_T *dd_next;
  for (dict_T *dd = gc_first_dict; dd != NULL; dd = dd_next) {
    dd_next = dd->dv_used_next;
    if ((dd->dv_copyID & COPYID_MASK) != (copyID & COPYID_MASK)) {
      tv_dict_free_dict(dd);
    }
  }

  list_T *ll_next;
  for (list_T *ll = gc_first_list; ll != NULL; ll = ll_next) {
    ll_next = ll->lv_used_next;
    if ((ll->lv_copyID & COPYID_MASK) != (copyID & COPYID_MASK)
        && !tv_list_has_watchers(ll)) {
      // Free the List and ordinary items it contains, but don't recurse
      // into Lists and Dictionaries, they will be in the list of dicts
      // or list of lists.
      tv_list_free_list(ll);
    }
  }
  tv_in_free_unref_items = false;
  return did_free;
}

/// Mark all lists and dicts referenced through hashtab "ht" with "copyID".
///
/// @param ht            Hashtab content will be marked.
/// @param copyID        New mark for lists and dicts.
/// @param list_stack    Used to add lists to be marked. Can be NULL.
///
/// @returns             true if setting references failed somehow.
bool set_ref_in_ht(hashtab_T *ht, int copyID, list_stack_T **list_stack)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  bool abort = false;
  ht_stack_T *ht_stack = NULL;

  hashtab_T *cur_ht = ht;
  for (;;) {
    if (!abort) {
      // Mark each item in the hashtab.  If the item contains a hashtab
      // it is added to ht_stack, if it contains a list it is added to
      // list_stack.
      HASHTAB_ITER(cur_ht, hi, {
        abort = abort || set_ref_in_item(
            &TV_DICT_HI2DI(hi)->di_tv, copyID, &ht_stack, list_stack);
      });
    }

    if (ht_stack == NULL) {
      break;
    }

    // take an item from the stack
    cur_ht = ht_stack->ht;
    ht_stack_T *tempitem = ht_stack;
    ht_stack = ht_stack->prev;
    xfree(tempitem);
  }

  return abort;
}

/// Mark all lists and dicts referenced through list "l" with "copyID".
///
/// @param l             List content will be marked.
/// @param copyID        New mark for lists and dicts.
/// @param ht_stack      Used to add hashtabs to be marked. Can be NULL.
///
/// @returns             true if setting references failed somehow.
bool set_ref_in_list(list_T *l, int copyID, ht_stack_T **ht_stack)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  bool abort = false;
  list_stack_T *list_stack = NULL;

  list_T *cur_l = l;
  for (;;) {
    // Mark each item in the list.  If the item contains a hashtab
    // it is added to ht_stack, if it contains a list it is added to
    // list_stack.
    TV_LIST_ITER(cur_l, li, {
      if (abort) {
        break;
      }
      abort = set_ref_in_item(TV_LIST_ITEM_TV(li), copyID, ht_stack,
                              &list_stack);
    });

    if (list_stack == NULL) {
      break;
    }

    // take an item from the stack
    cur_l = list_stack->list;
    list_stack_T *tempitem = list_stack;
    list_stack = list_stack->prev;
    xfree(tempitem);
  }

  return abort;
}

/// Mark all lists and dicts referenced through typval "tv" with "copyID".
///
/// @param tv            Typval content will be marked.
/// @param copyID        New mark for lists and dicts.
/// @param ht_stack      Used to add hashtabs to be marked. Can be NULL.
/// @param list_stack    Used to add lists to be marked. Can be NULL.
///
/// @returns             true if setting references failed somehow.
bool set_ref_in_item(typval_T *tv, int copyID, ht_stack_T **ht_stack,
                     list_stack_T **list_stack)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  bool abort = false;

  switch (tv->v_type) {
    case VAR_DICT: {
      dict_T *dd = tv->vval.v_dict;
      if (dd != NULL && dd->dv_copyID != copyID) {
        // Didn't see this dict yet.
        dd->dv_copyID = copyID;
        if (ht_stack == NULL) {
          abort = set_ref_in_ht(&dd->dv_hashtab, copyID, list_stack);
        } else {
          ht_stack_T *newitem = try_malloc(sizeof(ht_stack_T));
          if (newitem == NULL) {
            abort = true;
          } else {
            newitem->ht = &dd->dv_hashtab;
            newitem->prev = *ht_stack;
            *ht_stack = newitem;
          }
        }

        QUEUE *w = NULL;
        DictWatcher *watcher = NULL;
        QUEUE_FOREACH(w, &dd->watchers) {
          watcher = tv_dict_watcher_node_data(w);
          set_ref_in_callback(&watcher->callback, copyID, ht_stack, list_stack);
        }
      }
      break;
    }

    case VAR_LIST: {
      list_T *ll = tv->vval.v_list;
      if (ll != NULL && ll->lv_copyID != copyID) {
        // Didn't see this list yet.
        ll->lv_copyID = copyID;
        if (list_stack == NULL) {
          abort = set_ref_in_list(ll, copyID, ht_stack);
        } else {
          list_stack_T *newitem = try_malloc(sizeof(list_stack_T));
          if (newitem == NULL) {
            abort = true;
          } else {
            newitem->list = ll;
            newitem->prev = *list_stack;
            *list_stack = newitem;
          }
        }
      }
      break;
    }

    case VAR_PARTIAL: {
      partial_T *pt = tv->vval.v_partial;

      // A partial does not have a copyID, because it cannot contain itself.
      if (pt != NULL) {
        abort = set_ref_in_func(pt->pt_name, pt->pt_func, copyID);
        if (pt->pt_dict != NULL) {
          typval_T dtv;

          dtv.v_type = VAR_DICT;
          dtv.vval.v_dict = pt->pt_dict;
          abort = abort || set_ref_in_item(&dtv, copyID, ht_stack, list_stack);
        }

        for (int i = 0; i < pt->pt_argc; i++) {
          abort = abort || set_ref_in_item(&pt->pt_argv[i], copyID,
                                           ht_stack, list_stack);
        }
      }
      break;
    }
    case VAR_FUNC:
      abort = set_ref_in_func(tv->vval.v_string, NULL, copyID);
      break;
    case VAR_UNKNOWN:
    case VAR_SPECIAL:
    case VAR_FLOAT:
    case VAR_NUMBER:
    case VAR_STRING: {
      break;
    }
  }
  return abort;
}

/// Set "copyID" in all functions available by name.
bool set_ref_in_functions(int copyID)
{
  int todo;
  hashitem_T *hi = NULL;
  bool abort = false;
  ufunc_T *fp;

  todo = (int)func_hashtab.ht_used;
  for (hi = func_hashtab.ht_array; todo > 0 && !got_int; hi++) {
    if (!HASHITEM_EMPTY(hi)) {
      todo--;
      fp = HI2UF(hi);
      if (!func_name_refcount(fp->uf_name)) {
        abort = abort || set_ref_in_func(NULL, fp, copyID);
      }
    }
  }
  return abort;
}



/// Mark all lists and dicts referenced in given mark
///
/// @returns true if setting references failed somehow.
static inline bool set_ref_in_fmark(fmark_T fm, int copyID)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (fm.additional_data != NULL
      && fm.additional_data->dv_copyID != copyID) {
    fm.additional_data->dv_copyID = copyID;
    return set_ref_in_ht(&fm.additional_data->dv_hashtab, copyID, NULL);
  }
  return false;
}

/// Mark all lists and dicts referenced in given list and the list itself
///
/// @returns true if setting references failed somehow.
static inline bool set_ref_list(list_T *list, int copyID)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (list != NULL) {
    typval_T tv = (typval_T) {
      .v_type = VAR_LIST,
      .vval = { .v_list = list }
    };
    return set_ref_in_item(&tv, copyID, NULL, NULL);
  }
  return false;
}

/// Mark all lists and dicts referenced in given dict and the dict itself
///
/// @returns true if setting references failed somehow.
static inline bool set_ref_dict(dict_T *dict, int copyID)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (dict != NULL) {
    typval_T tv = (typval_T) {
      .v_type = VAR_DICT,
      .vval = { .v_dict = dict }
    };
    return set_ref_in_item(&tv, copyID, NULL, NULL);
  }
  return false;
}

static bool set_ref_in_funccal(funccall_T *fc, int copyID)
{
  bool abort = false;

  if (fc->fc_copyID != copyID) {
    fc->fc_copyID = copyID;
    abort = abort || set_ref_in_ht(&fc->l_vars.dv_hashtab, copyID, NULL);
    abort = abort || set_ref_in_ht(&fc->l_avars.dv_hashtab, copyID, NULL);
    abort = abort || set_ref_in_func(NULL, fc->func, copyID);
  }
  return abort;
}

/*
 * Allocate a variable for a Dictionary and fill it from "*arg".
 * Return OK or FAIL.  Returns NOTDONE for {expr}.
 */
static int dict_get_tv(char_u **arg, typval_T *rettv, int evaluate)
{
  dict_T      *d = NULL;
  typval_T tvkey;
  typval_T tv;
  char_u      *key = NULL;
  dictitem_T  *item;
  char_u      *start = skipwhite(*arg + 1);
  char buf[NUMBUFLEN];

  /*
   * First check if it's not a curly-braces thing: {expr}.
   * Must do this without evaluating, otherwise a function may be called
   * twice.  Unfortunately this means we need to call eval1() twice for the
   * first item.
   * But {} is an empty Dictionary.
   */
  if (*start != '}') {
    if (eval1(&start, &tv, FALSE) == FAIL)      /* recursive! */
      return FAIL;
    if (*start == '}')
      return NOTDONE;
  }

  if (evaluate) {
    d = tv_dict_alloc();
  }
  tvkey.v_type = VAR_UNKNOWN;
  tv.v_type = VAR_UNKNOWN;

  *arg = skipwhite(*arg + 1);
  while (**arg != '}' && **arg != NUL) {
    if (eval1(arg, &tvkey, evaluate) == FAIL)           /* recursive! */
      goto failret;
    if (**arg != ':') {
      EMSG2(_("E720: Missing colon in Dictionary: %s"), *arg);
      tv_clear(&tvkey);
      goto failret;
    }
    if (evaluate) {
      key = (char_u *)tv_get_string_buf_chk(&tvkey, buf);
      if (key == NULL) {
        // "key" is NULL when tv_get_string_buf_chk() gave an errmsg
        tv_clear(&tvkey);
        goto failret;
      }
    }

    *arg = skipwhite(*arg + 1);
    if (eval1(arg, &tv, evaluate) == FAIL) {  // Recursive!
      if (evaluate) {
        tv_clear(&tvkey);
      }
      goto failret;
    }
    if (evaluate) {
      item = tv_dict_find(d, (const char *)key, -1);
      if (item != NULL) {
        EMSG2(_("E721: Duplicate key in Dictionary: \"%s\""), key);
        tv_clear(&tvkey);
        tv_clear(&tv);
        goto failret;
      }
      item = tv_dict_item_alloc((const char *)key);
      item->di_tv = tv;
      item->di_tv.v_lock = 0;
      if (tv_dict_add(d, item) == FAIL) {
        tv_dict_item_free(item);
      }
    }
    tv_clear(&tvkey);

    if (**arg == '}')
      break;
    if (**arg != ',') {
      EMSG2(_("E722: Missing comma in Dictionary: %s"), *arg);
      goto failret;
    }
    *arg = skipwhite(*arg + 1);
  }

  if (**arg != '}') {
    EMSG2(_("E723: Missing end of Dictionary '}': %s"), *arg);
failret:
    if (d != NULL) {
      tv_dict_free(d);
    }
    return FAIL;
  }

  *arg = skipwhite(*arg + 1);
  if (evaluate) {
    tv_dict_set_ret(rettv, d);
  }

  return OK;
}

/// Get function arguments.
static int get_function_args(char_u **argp, char_u endchar, garray_T *newargs,
                             int *varargs, bool skip)
{
  bool    mustend = false;
  char_u  *arg = *argp;
  char_u  *p = arg;
  int     c;
  int     i;

  if (newargs != NULL) {
    ga_init(newargs, (int)sizeof(char_u *), 3);
  }

  if (varargs != NULL) {
    *varargs = false;
  }

  // Isolate the arguments: "arg1, arg2, ...)"
  while (*p != endchar) {
    if (p[0] == '.' && p[1] == '.' && p[2] == '.') {
      if (varargs != NULL) {
        *varargs = true;
      }
      p += 3;
      mustend = true;
    } else {
      arg = p;
      while (ASCII_ISALNUM(*p) || *p == '_') {
        p++;
      }
      if (arg == p || isdigit(*arg)
          || (p - arg == 9 && STRNCMP(arg, "firstline", 9) == 0)
          || (p - arg == 8 && STRNCMP(arg, "lastline", 8) == 0)) {
        if (!skip) {
          EMSG2(_("E125: Illegal argument: %s"), arg);
        }
        break;
      }
      if (newargs != NULL) {
        ga_grow(newargs, 1);
        c = *p;
        *p = NUL;
        arg = vim_strsave(arg);

        // Check for duplicate argument name.
        for (i = 0; i < newargs->ga_len; i++) {
          if (STRCMP(((char_u **)(newargs->ga_data))[i], arg) == 0) {
            EMSG2(_("E853: Duplicate argument name: %s"), arg);
            xfree(arg);
            goto err_ret;
          }
        }
        ((char_u **)(newargs->ga_data))[newargs->ga_len] = arg;
        newargs->ga_len++;

        *p = c;
      }
      if (*p == ',') {
        p++;
      } else {
        mustend = true;
      }
    }
    p = skipwhite(p);
    if (mustend && *p != endchar) {
      if (!skip) {
        EMSG2(_(e_invarg2), *argp);
      }
      break;
    }
  }
  if (*p != endchar) {
    goto err_ret;
  }
  p++;  // skip "endchar"

  *argp = p;
  return OK;

err_ret:
  if (newargs != NULL) {
    ga_clear_strings(newargs);
  }
  return FAIL;
}

/// Register function "fp" as using "current_funccal" as its scope.
static void register_closure(ufunc_T *fp)
{
  if (fp->uf_scoped == current_funccal) {
    // no change
    return;
  }
  funccal_unref(fp->uf_scoped, fp, false);
  fp->uf_scoped = current_funccal;
  current_funccal->fc_refcount++;
  ga_grow(&current_funccal->fc_funcs, 1);
  ((ufunc_T **)current_funccal->fc_funcs.ga_data)
    [current_funccal->fc_funcs.ga_len++] = fp;
}

/// Parse a lambda expression and get a Funcref from "*arg".
///
/// @return OK or FAIL.  Returns NOTDONE for dict or {expr}.
static int get_lambda_tv(char_u **arg, typval_T *rettv, bool evaluate)
{
  garray_T   newargs = GA_EMPTY_INIT_VALUE;
  garray_T   *pnewargs;
  ufunc_T    *fp = NULL;
  int        varargs;
  int        ret;
  char_u     *start = skipwhite(*arg + 1);
  char_u     *s, *e;
  static int lambda_no = 0;
  int        *old_eval_lavars = eval_lavars_used;
  int        eval_lavars = false;

  // First, check if this is a lambda expression. "->" must exists.
  ret = get_function_args(&start, '-', NULL, NULL, true);
  if (ret == FAIL || *start != '>') {
    return NOTDONE;
  }

  // Parse the arguments again.
  if (evaluate) {
    pnewargs = &newargs;
  } else {
    pnewargs = NULL;
  }
  *arg = skipwhite(*arg + 1);
  ret = get_function_args(arg, '-', pnewargs, &varargs, false);
  if (ret == FAIL || **arg != '>') {
    goto errret;
  }

  // Set up a flag for checking local variables and arguments.
  if (evaluate) {
    eval_lavars_used = &eval_lavars;
  }

  // Get the start and the end of the expression.
  *arg = skipwhite(*arg + 1);
  s = *arg;
  ret = skip_expr(arg);
  if (ret == FAIL) {
    goto errret;
  }
  e = *arg;
  *arg = skipwhite(*arg);
  if (**arg != '}') {
    goto errret;
  }
  (*arg)++;

  if (evaluate) {
    int len, flags = 0;
    char_u *p;
    char_u name[20];
    partial_T *pt;
    garray_T newlines;

    lambda_no++;
    snprintf((char *)name, sizeof(name), "<lambda>%d", lambda_no);

    fp = xcalloc(1, offsetof(ufunc_T, uf_name) + STRLEN(name) + 1);
    pt = xcalloc(1, sizeof(partial_T));

    ga_init(&newlines, (int)sizeof(char_u *), 1);
    ga_grow(&newlines, 1);

    // Add "return " before the expression.
    len = 7 + e - s + 1;
    p = (char_u *)xmalloc(len);
    ((char_u **)(newlines.ga_data))[newlines.ga_len++] = p;
    STRCPY(p, "return ");
    STRLCPY(p + 7, s, e - s + 1);

    fp->uf_refcount = 1;
    STRCPY(fp->uf_name, name);
    hash_add(&func_hashtab, UF2HIKEY(fp));
    fp->uf_args = newargs;
    fp->uf_lines = newlines;
    if (current_funccal != NULL && eval_lavars) {
      flags |= FC_CLOSURE;
      register_closure(fp);
    } else {
      fp->uf_scoped = NULL;
    }

    if (prof_def_func()) {
      func_do_profile(fp);
    }
    if (sandbox) {
      flags |= FC_SANDBOX;
    }
    fp->uf_varargs = true;
    fp->uf_flags = flags;
    fp->uf_calls = 0;
    fp->uf_script_ctx = current_sctx;
    fp->uf_script_ctx.sc_lnum += sourcing_lnum - newlines.ga_len;

    pt->pt_func = fp;
    pt->pt_refcount = 1;
    rettv->vval.v_partial = pt;
    rettv->v_type = VAR_PARTIAL;
  }

  eval_lavars_used = old_eval_lavars;
  return OK;

errret:
  ga_clear_strings(&newargs);
  xfree(fp);
  eval_lavars_used = old_eval_lavars;
  return FAIL;
}

/// Convert the string to a floating point number
///
/// This uses strtod().  setlocale(LC_NUMERIC, "C") has been used earlier to
/// make sure this always uses a decimal point.
///
/// @param[in]  text  String to convert.
/// @param[out]  ret_value  Location where conversion result is saved.
///
/// @return Length of the text that was consumed.
size_t string2float(const char *const text, float_T *const ret_value)
  FUNC_ATTR_NONNULL_ALL
{
  char *s = NULL;

  // MS-Windows does not deal with "inf" and "nan" properly
  if (STRNICMP(text, "inf", 3) == 0) {
    *ret_value = INFINITY;
    return 3;
  }
  if (STRNICMP(text, "-inf", 3) == 0) {
    *ret_value = -INFINITY;
    return 4;
  }
  if (STRNICMP(text, "nan", 3) == 0) {
    *ret_value = NAN;
    return 3;
  }
  *ret_value = strtod(text, &s);
  return (size_t) (s - text);
}

/// Get the value of an environment variable.
///
/// If the environment variable was not set, silently assume it is empty.
///
/// @param arg Points to the '$'.  It is advanced to after the name.
/// @return FAIL if the name is invalid.
///
static int get_env_tv(char_u **arg, typval_T *rettv, int evaluate)
{
  char_u *name;
  char_u *string = NULL;
  int     len;
  int     cc;

  ++*arg;
  name = *arg;
  len = get_env_len((const char_u **)arg);

  if (evaluate) {
    if (len == 0) {
      return FAIL;  // Invalid empty name.
    }
    cc = name[len];
    name[len] = NUL;
    // First try vim_getenv(), fast for normal environment vars.
    string = (char_u *)vim_getenv((char *)name);
    if (string == NULL || *string == NUL) {
      xfree(string);

      // Next try expanding things like $VIM and ${HOME}.
      string = expand_env_save(name - 1);
      if (string != NULL && *string == '$') {
        XFREE_CLEAR(string);
      }
    }
    name[len] = cc;
    rettv->v_type = VAR_STRING;
    rettv->vval.v_string = string;
  }

  return OK;
}

/// Return name of the function corresponding to `name`
///
/// If `name` points to variable that is either a function or partial then
/// corresponding function name is returned. Otherwise it returns `name` itself.
///
/// @param[in]  name  Function name to check.
/// @param[in,out]  lenp  Location where length of the returned name is stored.
///                       Must be set to the length of the `name` argument.
/// @param[out]  partialp  Location where partial will be stored if found
///                        function appears to be a partial. May be NULL if this
///                        is not needed.
/// @param[in]  no_autoload  If true, do not source autoload scripts if function
///                          was not found.
///
/// @return name of the function.
static char_u *deref_func_name(const char *name, int *lenp,
                               partial_T **const partialp, bool no_autoload)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  if (partialp != NULL) {
    *partialp = NULL;
  }

  dictitem_T *const v = find_var(name, (size_t)(*lenp), NULL, no_autoload);
  if (v != NULL && v->di_tv.v_type == VAR_FUNC) {
    if (v->di_tv.vval.v_string == NULL) {  // just in case
      *lenp = 0;
      return (char_u *)"";
    }
    *lenp = (int)STRLEN(v->di_tv.vval.v_string);
    return v->di_tv.vval.v_string;
  }

  if (v != NULL && v->di_tv.v_type == VAR_PARTIAL) {
    partial_T *const pt = v->di_tv.vval.v_partial;

    if (pt == NULL) {  // just in case
      *lenp = 0;
      return (char_u *)"";
    }
    if (partialp != NULL) {
      *partialp = pt;
    }
    char_u *s = partial_name(pt);
    *lenp = (int)STRLEN(s);
    return s;
  }

  return (char_u *)name;
}

/*
 * Allocate a variable for the result of a function.
 * Return OK or FAIL.
 */
static int
get_func_tv(
    const char_u *name,     // name of the function
    int len,                // length of "name"
    typval_T *rettv,
    char_u **arg,           // argument, pointing to the '('
    linenr_T firstline,     // first line of range
    linenr_T lastline,      // last line of range
    int *doesrange,         // return: function handled range
    int evaluate,
    partial_T *partial,     // for extra arguments
    dict_T *selfdict        // Dictionary for "self"
)
{
  char_u      *argp;
  int ret = OK;
  typval_T argvars[MAX_FUNC_ARGS + 1];          /* vars for arguments */
  int argcount = 0;                     /* number of arguments found */

  /*
   * Get the arguments.
   */
  argp = *arg;
  while (argcount < MAX_FUNC_ARGS - (partial == NULL ? 0 : partial->pt_argc)) {
    argp = skipwhite(argp + 1);             // skip the '(' or ','
    if (*argp == ')' || *argp == ',' || *argp == NUL) {
      break;
    }
    if (eval1(&argp, &argvars[argcount], evaluate) == FAIL) {
      ret = FAIL;
      break;
    }
    ++argcount;
    if (*argp != ',')
      break;
  }
  if (*argp == ')')
    ++argp;
  else
    ret = FAIL;

  if (ret == OK) {
    int i = 0;

    if (get_vim_var_nr(VV_TESTING)) {
      // Prepare for calling garbagecollect_for_testing(), need to know
      // what variables are used on the call stack.
      if (funcargs.ga_itemsize == 0) {
        ga_init(&funcargs, (int)sizeof(typval_T *), 50);
      }
      for (i = 0; i < argcount; i++) {
        ga_grow(&funcargs, 1);
        ((typval_T **)funcargs.ga_data)[funcargs.ga_len++] = &argvars[i];
      }
    }
    ret = call_func(name, len, rettv, argcount, argvars, NULL,
                    firstline, lastline, doesrange, evaluate,
                    partial, selfdict);

    funcargs.ga_len -= i;
  } else if (!aborting()) {
    if (argcount == MAX_FUNC_ARGS) {
      emsg_funcname(N_("E740: Too many arguments for function %s"), name);
    } else {
      emsg_funcname(N_("E116: Invalid arguments for function %s"), name);
    }
  }

  while (--argcount >= 0) {
    tv_clear(&argvars[argcount]);
  }

  *arg = skipwhite(argp);
  return ret;
}

typedef enum {
  ERROR_UNKNOWN = 0,
  ERROR_TOOMANY,
  ERROR_TOOFEW,
  ERROR_SCRIPT,
  ERROR_DICT,
  ERROR_NONE,
  ERROR_OTHER,
  ERROR_BOTH,
  ERROR_DELETED,
} FnameTransError;

#define FLEN_FIXED 40

/// In a script transform script-local names into actually used names
///
/// Transforms "<SID>" and "s:" prefixes to `K_SNR {N}` (e.g. K_SNR "123") and
/// "<SNR>" prefix to `K_SNR`. Uses `fname_buf` buffer that is supposed to have
/// #FLEN_FIXED + 1 length when it fits, otherwise it allocates memory.
///
/// @param[in]  name  Name to transform.
/// @param  fname_buf  Buffer to save resulting function name to, if it fits.
///                    Must have at least #FLEN_FIXED + 1 length.
/// @param[out]  tofree  Location where pointer to an allocated memory is saved
///                      in case result does not fit into fname_buf.
/// @param[out]  error  Location where error type is saved, @see
///                     FnameTransError.
///
/// @return transformed name: either `fname_buf` or a pointer to an allocated
///         memory.
static char_u *fname_trans_sid(const char_u *const name,
                               char_u *const fname_buf,
                               char_u **const tofree, int *const error)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  char_u *fname;
  const int llen = eval_fname_script((const char *)name);
  if (llen > 0) {
    fname_buf[0] = K_SPECIAL;
    fname_buf[1] = KS_EXTRA;
    fname_buf[2] = (int)KE_SNR;
    int i = 3;
    if (eval_fname_sid((const char *)name)) {  // "<SID>" or "s:"
      if (current_sctx.sc_sid <= 0) {
        *error = ERROR_SCRIPT;
      } else {
        snprintf((char *)fname_buf + 3, FLEN_FIXED + 1, "%" PRId64 "_",
                 (int64_t)current_sctx.sc_sid);
        i = (int)STRLEN(fname_buf);
      }
    }
    if (i + STRLEN(name + llen) < FLEN_FIXED) {
      STRCPY(fname_buf + i, name + llen);
      fname = fname_buf;
    } else {
      fname = xmalloc(i + STRLEN(name + llen) + 1);
      *tofree = fname;
      memmove(fname, fname_buf, (size_t)i);
      STRCPY(fname + i, name + llen);
    }
  } else {
    fname = (char_u *)name;
  }

  return fname;
}

/// Mark all lists and dicts referenced through function "name" with "copyID".
/// "list_stack" is used to add lists to be marked.  Can be NULL.
/// "ht_stack" is used to add hashtabs to be marked.  Can be NULL.
///
/// @return true if setting references failed somehow.
bool set_ref_in_func(char_u *name, ufunc_T *fp_in, int copyID)
{
  ufunc_T *fp = fp_in;
  funccall_T *fc;
  int error = ERROR_NONE;
  char_u fname_buf[FLEN_FIXED + 1];
  char_u *tofree = NULL;
  char_u *fname;
  bool abort = false;
  if (name == NULL && fp_in == NULL) {
    return false;
  }

  if (fp_in == NULL) {
    fname = fname_trans_sid(name, fname_buf, &tofree, &error);
    fp = find_func(fname);
  }
  if (fp != NULL) {
    for (fc = fp->uf_scoped; fc != NULL; fc = fc->func->uf_scoped) {
      abort = abort || set_ref_in_funccal(fc, copyID);
    }
  }
  xfree(tofree);
  return abort;
}

/// Call a function with its resolved parameters
///
/// "argv_func", when not NULL, can be used to fill in arguments only when the
/// invoked function uses them. It is called like this:
///   new_argcount = argv_func(current_argcount, argv, called_func_argcount)
///
/// @return FAIL if function cannot be called, else OK (even if an error
///         occurred while executing the function! Set `msg_list` to capture
///         the error, see do_cmdline()).
int
call_func(
    const char_u *funcname,         // name of the function
    int len,                        // length of "name"
    typval_T *rettv,                // [out] value goes here
    int argcount_in,                // number of "argvars"
    typval_T *argvars_in,           // vars for arguments, must have "argcount"
                                    // PLUS ONE elements!
    ArgvFunc argv_func,             // function to fill in argvars
    linenr_T firstline,             // first line of range
    linenr_T lastline,              // last line of range
    int *doesrange,                 // [out] function handled range
    bool evaluate,
    partial_T *partial,             // optional, can be NULL
    dict_T *selfdict_in             // Dictionary for "self"
)
  FUNC_ATTR_NONNULL_ARG(1, 3, 5, 9)
{
  int ret = FAIL;
  int error = ERROR_NONE;
  ufunc_T *fp;
  char_u fname_buf[FLEN_FIXED + 1];
  char_u *tofree = NULL;
  char_u *fname;
  char_u *name;
  int argcount = argcount_in;
  typval_T *argvars = argvars_in;
  dict_T *selfdict = selfdict_in;
  typval_T argv[MAX_FUNC_ARGS + 1];  // used when "partial" is not NULL
  int argv_clear = 0;

  // Initialize rettv so that it is safe for caller to invoke clear_tv(rettv)
  // even when call_func() returns FAIL.
  rettv->v_type = VAR_UNKNOWN;

  // Make a copy of the name, if it comes from a funcref variable it could
  // be changed or deleted in the called function.
  name = vim_strnsave(funcname, len);

  fname = fname_trans_sid(name, fname_buf, &tofree, &error);

  *doesrange = false;

  if (partial != NULL) {
    // When the function has a partial with a dict and there is a dict
    // argument, use the dict argument. That is backwards compatible.
    // When the dict was bound explicitly use the one from the partial.
    if (partial->pt_dict != NULL
        && (selfdict_in == NULL || !partial->pt_auto)) {
      selfdict = partial->pt_dict;
    }
    if (error == ERROR_NONE && partial->pt_argc > 0) {
      for (argv_clear = 0; argv_clear < partial->pt_argc; argv_clear++) {
        tv_copy(&partial->pt_argv[argv_clear], &argv[argv_clear]);
      }
      for (int i = 0; i < argcount_in; i++) {
        argv[i + argv_clear] = argvars_in[i];
      }
      argvars = argv;
      argcount = partial->pt_argc + argcount_in;
    }
  }

  if (error == ERROR_NONE && evaluate) {
    char_u *rfname = fname;

    /* Ignore "g:" before a function name. */
    if (fname[0] == 'g' && fname[1] == ':') {
      rfname = fname + 2;
    }

    rettv->v_type = VAR_NUMBER;         /* default rettv is number zero */
    rettv->vval.v_number = 0;
    error = ERROR_UNKNOWN;

    if (partial == vvlua_partial) {
      if (len > 0) {
        error = ERROR_NONE;
        executor_call_lua((const char *)funcname, len,
                          argvars, argcount, rettv);
      }
    } else if (!builtin_function((const char *)rfname, -1)) {
      // User defined function.
      if (partial != NULL && partial->pt_func != NULL) {
        fp = partial->pt_func;
      } else {
        fp = find_func(rfname);
      }

      // Trigger FuncUndefined event, may load the function.
      if (fp == NULL
          && apply_autocmds(EVENT_FUNCUNDEFINED, rfname, rfname, TRUE, NULL)
          && !aborting()) {
        /* executed an autocommand, search for the function again */
        fp = find_func(rfname);
      }
      // Try loading a package.
      if (fp == NULL && script_autoload((const char *)rfname, STRLEN(rfname),
                                        true) && !aborting()) {
        // Loaded a package, search for the function again.
        fp = find_func(rfname);
      }

      if (fp != NULL && (fp->uf_flags & FC_DELETED)) {
        error = ERROR_DELETED;
      } else if (fp != NULL) {
        if (argv_func != NULL) {
          argcount = argv_func(argcount, argvars, fp->uf_args.ga_len);
        }
        if (fp->uf_flags & FC_RANGE) {
          *doesrange = true;
        }
        if (argcount < fp->uf_args.ga_len) {
          error = ERROR_TOOFEW;
        } else if (!fp->uf_varargs && argcount > fp->uf_args.ga_len) {
          error = ERROR_TOOMANY;
        } else if ((fp->uf_flags & FC_DICT) && selfdict == NULL) {
          error = ERROR_DICT;
        } else {
          // Call the user function.
          call_user_func(fp, argcount, argvars, rettv, firstline, lastline,
                         (fp->uf_flags & FC_DICT) ? selfdict : NULL);
          error = ERROR_NONE;
        }
      }
    } else {
      // Find the function name in the table, call its implementation.
      const VimLFuncDef *const fdef = find_internal_func((const char *)fname);
      if (fdef != NULL) {
        if (argcount < fdef->min_argc) {
          error = ERROR_TOOFEW;
        } else if (argcount > fdef->max_argc) {
          error = ERROR_TOOMANY;
        } else {
          argvars[argcount].v_type = VAR_UNKNOWN;
          fdef->func(argvars, rettv, fdef->data);
          error = ERROR_NONE;
        }
      }
    }
    /*
     * The function call (or "FuncUndefined" autocommand sequence) might
     * have been aborted by an error, an interrupt, or an explicitly thrown
     * exception that has not been caught so far.  This situation can be
     * tested for by calling aborting().  For an error in an internal
     * function or for the "E132" error in call_user_func(), however, the
     * throw point at which the "force_abort" flag (temporarily reset by
     * emsg()) is normally updated has not been reached yet. We need to
     * update that flag first to make aborting() reliable.
     */
    update_force_abort();
  }
  if (error == ERROR_NONE)
    ret = OK;

  /*
   * Report an error unless the argument evaluation or function call has been
   * cancelled due to an aborting error, an interrupt, or an exception.
   */
  if (!aborting()) {
    switch (error) {
    case ERROR_UNKNOWN:
      emsg_funcname(N_("E117: Unknown function: %s"), name);
      break;
    case ERROR_DELETED:
      emsg_funcname(N_("E933: Function was deleted: %s"), name);
      break;
    case ERROR_TOOMANY:
      emsg_funcname(_(e_toomanyarg), name);
      break;
    case ERROR_TOOFEW:
      emsg_funcname(N_("E119: Not enough arguments for function: %s"),
          name);
      break;
    case ERROR_SCRIPT:
      emsg_funcname(N_("E120: Using <SID> not in a script context: %s"),
          name);
      break;
    case ERROR_DICT:
      emsg_funcname(N_("E725: Calling dict function without Dictionary: %s"),
          name);
      break;
    }
  }

  while (argv_clear > 0) {
    tv_clear(&argv[--argv_clear]);
  }
  xfree(tofree);
  xfree(name);

  return ret;
}

/// Give an error message with a function name.  Handle <SNR> things.
///
/// @param ermsg must be passed without translation (use N_() instead of _()).
/// @param name function name
static void emsg_funcname(char *ermsg, const char_u *name)
{
  char_u *p;

  if (*name == K_SPECIAL) {
    p = concat_str((char_u *)"<SNR>", name + 3);
  } else {
    p = (char_u *)name;
  }

  EMSG2(_(ermsg), p);

  if (p != name) {
    xfree(p);
  }
}

/// Get the argument list for a given window
void get_arglist_as_rettv(aentry_T *arglist, int argcount,
                          typval_T *rettv)
{
  tv_list_alloc_ret(rettv, argcount);
  if (arglist != NULL) {
    for (int idx = 0; idx < argcount; idx++) {
      tv_list_append_string(rettv->vval.v_list,
                            (const char *)alist_name(&arglist[idx]), -1);
    }
  }
}

// Prepare "gap" for an assert error and add the sourcing position.
void prepare_assert_error(garray_T *gap)
{
  char buf[NUMBUFLEN];

  ga_init(gap, 1, 100);
  if (sourcing_name != NULL) {
    ga_concat(gap, sourcing_name);
    if (sourcing_lnum > 0) {
      ga_concat(gap, (char_u *)" ");
    }
  }
  if (sourcing_lnum > 0) {
    vim_snprintf(buf, ARRAY_SIZE(buf), "line %" PRId64, (int64_t)sourcing_lnum);
    ga_concat(gap, (char_u *)buf);
  }
  if (sourcing_name != NULL || sourcing_lnum > 0) {
    ga_concat(gap, (char_u *)": ");
  }
}

// Append "str" to "gap", escaping unprintable characters.
// Changes NL to \n, CR to \r, etc.
static void ga_concat_esc(garray_T *gap, char_u *str)
{
  char_u *p;
  char_u buf[NUMBUFLEN];

  if (str == NULL) {
    ga_concat(gap, (char_u *)"NULL");
    return;
  }

  for (p = str; *p != NUL; p++) {
    switch (*p) {
      case BS: ga_concat(gap, (char_u *)"\\b"); break;
      case ESC: ga_concat(gap, (char_u *)"\\e"); break;
      case FF: ga_concat(gap, (char_u *)"\\f"); break;
      case NL: ga_concat(gap, (char_u *)"\\n"); break;
      case TAB: ga_concat(gap, (char_u *)"\\t"); break;
      case CAR: ga_concat(gap, (char_u *)"\\r"); break;
      case '\\': ga_concat(gap, (char_u *)"\\\\"); break;
      default:
        if (*p < ' ') {
          vim_snprintf((char *)buf, NUMBUFLEN, "\\x%02x", *p);
          ga_concat(gap, buf);
        } else {
          ga_append(gap, *p);
        }
        break;
    }
  }
}

// Fill "gap" with information about an assert error.
void fill_assert_error(garray_T *gap, typval_T *opt_msg_tv,
                       char_u *exp_str, typval_T *exp_tv,
                       typval_T *got_tv, assert_type_T atype)
{
  char_u *tofree;

  if (opt_msg_tv->v_type != VAR_UNKNOWN) {
    tofree = (char_u *)encode_tv2echo(opt_msg_tv, NULL);
    ga_concat(gap, tofree);
    xfree(tofree);
    ga_concat(gap, (char_u *)": ");
  }

  if (atype == ASSERT_MATCH || atype == ASSERT_NOTMATCH) {
    ga_concat(gap, (char_u *)"Pattern ");
  } else if (atype == ASSERT_NOTEQUAL) {
    ga_concat(gap, (char_u *)"Expected not equal to ");
  } else {
    ga_concat(gap, (char_u *)"Expected ");
  }

  if (exp_str == NULL) {
    tofree = (char_u *)encode_tv2string(exp_tv, NULL);
    ga_concat_esc(gap, tofree);
    xfree(tofree);
  } else {
    ga_concat_esc(gap, exp_str);
  }

  if (atype != ASSERT_NOTEQUAL) {
    if (atype == ASSERT_MATCH) {
      ga_concat(gap, (char_u *)" does not match ");
    } else if (atype == ASSERT_NOTMATCH) {
      ga_concat(gap, (char_u *)" does match ");
    } else {
      ga_concat(gap, (char_u *)" but got ");
    }
    tofree = (char_u *)encode_tv2string(got_tv, NULL);
    ga_concat_esc(gap, tofree);
    xfree(tofree);
  }
}

// Add an assert error to v:errors.
void assert_error(garray_T *gap)
{
  struct vimvar *vp = &vimvars[VV_ERRORS];

  if (vp->vv_type != VAR_LIST || vimvars[VV_ERRORS].vv_list == NULL) {
    // Make sure v:errors is a list.
    set_vim_var_list(VV_ERRORS, tv_list_alloc(1));
  }
  tv_list_append_string(vimvars[VV_ERRORS].vv_list,
                        (const char *)gap->ga_data, (ptrdiff_t)gap->ga_len);
}

int assert_equal_common(typval_T *argvars, assert_type_T atype)
  FUNC_ATTR_NONNULL_ALL
{
  garray_T ga;

  if (tv_equal(&argvars[0], &argvars[1], false, false)
      != (atype == ASSERT_EQUAL)) {
    prepare_assert_error(&ga);
    fill_assert_error(&ga, &argvars[2], NULL,
                      &argvars[0], &argvars[1], atype);
    assert_error(&ga);
    ga_clear(&ga);
    return 1;
  }
  return 0;
}

int assert_equalfile(typval_T *argvars)
  FUNC_ATTR_NONNULL_ALL
{
  char buf1[NUMBUFLEN];
  char buf2[NUMBUFLEN];
  const char *const fname1 = tv_get_string_buf_chk(&argvars[0], buf1);
  const char *const fname2 = tv_get_string_buf_chk(&argvars[1], buf2);
  garray_T ga;

  if (fname1 == NULL || fname2 == NULL) {
    return 0;
  }

  IObuff[0] = NUL;
  FILE *const fd1 = os_fopen(fname1, READBIN);
  if (fd1 == NULL) {
    snprintf((char *)IObuff, IOSIZE, (char *)e_notread, fname1);
  } else {
    FILE *const fd2 = os_fopen(fname2, READBIN);
    if (fd2 == NULL) {
      fclose(fd1);
      snprintf((char *)IObuff, IOSIZE, (char *)e_notread, fname2);
    } else {
      for (int64_t count = 0; ; count++) {
        const int c1 = fgetc(fd1);
        const int c2 = fgetc(fd2);
        if (c1 == EOF) {
          if (c2 != EOF) {
            STRCPY(IObuff, "first file is shorter");
          }
          break;
        } else if (c2 == EOF) {
          STRCPY(IObuff, "second file is shorter");
          break;
        } else if (c1 != c2) {
          snprintf((char *)IObuff, IOSIZE,
                   "difference at byte %" PRId64, count);
          break;
        }
      }
      fclose(fd1);
      fclose(fd2);
    }
  }
  if (IObuff[0] != NUL) {
    prepare_assert_error(&ga);
    ga_concat(&ga, IObuff);
    assert_error(&ga);
    ga_clear(&ga);
    return 1;
  }
  return 0;
}

int assert_inrange(typval_T *argvars)
  FUNC_ATTR_NONNULL_ALL
{
  bool error = false;
  const varnumber_T lower = tv_get_number_chk(&argvars[0], &error);
  const varnumber_T upper = tv_get_number_chk(&argvars[1], &error);
  const varnumber_T actual = tv_get_number_chk(&argvars[2], &error);

  if (error) {
    return 0;
  }
  if (actual < lower || actual > upper) {
    garray_T ga;
    prepare_assert_error(&ga);

    char msg[55];
    vim_snprintf(msg, sizeof(msg),
                 "range %" PRIdVARNUMBER " - %" PRIdVARNUMBER ",",
                 lower, upper);
    fill_assert_error(&ga, &argvars[3], (char_u *)msg, NULL, &argvars[2],
                      ASSERT_INRANGE);
    assert_error(&ga);
    ga_clear(&ga);
    return 1;
  }
  return 0;
}

// Common for assert_true() and assert_false().
int assert_bool(typval_T *argvars, bool is_true)
  FUNC_ATTR_NONNULL_ALL
{
  bool error = false;
  garray_T ga;

  if ((argvars[0].v_type != VAR_NUMBER
       || (tv_get_number_chk(&argvars[0], &error) == 0) == is_true
       || error)
      && (argvars[0].v_type != VAR_SPECIAL
          || (argvars[0].vval.v_special
              != (SpecialVarValue) (is_true
                                    ? kSpecialVarTrue
                                    : kSpecialVarFalse)))) {
    prepare_assert_error(&ga);
    fill_assert_error(&ga, &argvars[1],
                      (char_u *)(is_true ? "True" : "False"),
                      NULL, &argvars[0], ASSERT_OTHER);
    assert_error(&ga);
    ga_clear(&ga);
    return 1;
  }
  return 0;
}

int assert_exception(typval_T *argvars)
  FUNC_ATTR_NONNULL_ALL
{
  garray_T ga;

  const char *const error = tv_get_string_chk(&argvars[0]);
  if (vimvars[VV_EXCEPTION].vv_str == NULL) {
    prepare_assert_error(&ga);
    ga_concat(&ga, (char_u *)"v:exception is not set");
    assert_error(&ga);
    ga_clear(&ga);
    return 1;
  } else if (error != NULL
             && strstr((char *)vimvars[VV_EXCEPTION].vv_str, error) == NULL) {
    prepare_assert_error(&ga);
    fill_assert_error(&ga, &argvars[1], NULL, &argvars[0],
                      &vimvars[VV_EXCEPTION].vv_tv, ASSERT_OTHER);
    assert_error(&ga);
    ga_clear(&ga);
    return 1;
  }
  return 0;
}

int assert_fails(typval_T *argvars)
  FUNC_ATTR_NONNULL_ALL
{
  const char *const cmd = tv_get_string_chk(&argvars[0]);
  garray_T    ga;
  int ret = 0;
  int         save_trylevel = trylevel;

  // trylevel must be zero for a ":throw" command to be considered failed
  trylevel = 0;
  called_emsg = false;
  suppress_errthrow = true;
  emsg_silent = true;

  do_cmdline_cmd(cmd);
  if (!called_emsg) {
    prepare_assert_error(&ga);
    ga_concat(&ga, (const char_u *)"command did not fail: ");
    if (argvars[1].v_type != VAR_UNKNOWN
        && argvars[2].v_type != VAR_UNKNOWN) {
      char *const tofree = encode_tv2echo(&argvars[2], NULL);
      ga_concat(&ga, (char_u *)tofree);
      xfree(tofree);
    } else {
      ga_concat(&ga, (const char_u *)cmd);
    }
    assert_error(&ga);
    ga_clear(&ga);
    ret = 1;
  } else if (argvars[1].v_type != VAR_UNKNOWN) {
    char buf[NUMBUFLEN];
    const char *const error = tv_get_string_buf_chk(&argvars[1], buf);

    if (error == NULL
        || strstr((char *)vimvars[VV_ERRMSG].vv_str, error) == NULL) {
      prepare_assert_error(&ga);
      fill_assert_error(&ga, &argvars[2], NULL, &argvars[1],
                        &vimvars[VV_ERRMSG].vv_tv, ASSERT_OTHER);
      assert_error(&ga);
      ga_clear(&ga);
      ret = 1;
    }
  }

  trylevel = save_trylevel;
  called_emsg = false;
  suppress_errthrow = false;
  emsg_silent = false;
  emsg_on_display = false;
  set_vim_var_string(VV_ERRMSG, NULL, 0);
  return ret;
}

int assert_match_common(typval_T *argvars, assert_type_T atype)
  FUNC_ATTR_NONNULL_ALL
{
  char buf1[NUMBUFLEN];
  char buf2[NUMBUFLEN];
  const char *const pat = tv_get_string_buf_chk(&argvars[0], buf1);
  const char *const text = tv_get_string_buf_chk(&argvars[1], buf2);

  if (pat == NULL || text == NULL) {
    EMSG(_(e_invarg));
  } else if (pattern_match((char_u *)pat, (char_u *)text, false)
             != (atype == ASSERT_MATCH)) {
    garray_T ga;
    prepare_assert_error(&ga);
    fill_assert_error(&ga, &argvars[2], NULL, &argvars[0], &argvars[1], atype);
    assert_error(&ga);
    ga_clear(&ga);
    return 1;
  }
  return 0;
}

int func_call(char_u *name, typval_T *args, partial_T *partial,
              dict_T *selfdict, typval_T *rettv)
{
  typval_T argv[MAX_FUNC_ARGS + 1];
  int argc = 0;
  int dummy;
  int r = 0;

  TV_LIST_ITER(args->vval.v_list, item, {
    if (argc == MAX_FUNC_ARGS - (partial == NULL ? 0 : partial->pt_argc)) {
      EMSG(_("E699: Too many arguments"));
      goto func_call_skip_call;
    }
    // Make a copy of each argument.  This is needed to be able to set
    // v_lock to VAR_FIXED in the copy without changing the original list.
    tv_copy(TV_LIST_ITEM_TV(item), &argv[argc++]);
  });

  r = call_func(name, (int)STRLEN(name), rettv, argc, argv, NULL,
                curwin->w_cursor.lnum, curwin->w_cursor.lnum,
                &dummy, true, partial, selfdict);

func_call_skip_call:
  // Free the arguments.
  while (argc > 0) {
    tv_clear(&argv[--argc]);
  }

  return r;
}

/// Find a window: When using a Window ID in any tab page, when using a number
/// in the current tab page.
win_T * find_win_by_nr_or_id(typval_T *vp)
{
  int nr = (int)tv_get_number_chk(vp, NULL);

  if (nr >= LOWEST_WIN_ID) {
    return win_id2wp(vp);
  }

  return find_win_by_nr(vp, NULL);
}

/*
 * Implementation of map() and filter().
 */
void filter_map(typval_T *argvars, typval_T *rettv, int map)
{
  typval_T    *expr;
  list_T      *l = NULL;
  dictitem_T  *di;
  hashtab_T   *ht;
  hashitem_T  *hi;
  dict_T      *d = NULL;
  typval_T save_val;
  typval_T save_key;
  int rem = false;
  int todo;
  char_u *ermsg = (char_u *)(map ? "map()" : "filter()");
  const char *const arg_errmsg = (map
                                  ? N_("map() argument")
                                  : N_("filter() argument"));
  int save_did_emsg;
  int idx = 0;

  if (argvars[0].v_type == VAR_LIST) {
    tv_copy(&argvars[0], rettv);
    if ((l = argvars[0].vval.v_list) == NULL
        || (!map && tv_check_lock(tv_list_locked(l), arg_errmsg,
                                  TV_TRANSLATE))) {
      return;
    }
  } else if (argvars[0].v_type == VAR_DICT) {
    tv_copy(&argvars[0], rettv);
    if ((d = argvars[0].vval.v_dict) == NULL
        || (!map && tv_check_lock(d->dv_lock, arg_errmsg, TV_TRANSLATE))) {
      return;
    }
  } else {
    EMSG2(_(e_listdictarg), ermsg);
    return;
  }

  expr = &argvars[1];
  // On type errors, the preceding call has already displayed an error
  // message.  Avoid a misleading error message for an empty string that
  // was not passed as argument.
  if (expr->v_type != VAR_UNKNOWN) {
    prepare_vimvar(VV_VAL, &save_val);

    // We reset "did_emsg" to be able to detect whether an error
    // occurred during evaluation of the expression.
    save_did_emsg = did_emsg;
    did_emsg = FALSE;

    prepare_vimvar(VV_KEY, &save_key);
    if (argvars[0].v_type == VAR_DICT) {
      vimvars[VV_KEY].vv_type = VAR_STRING;

      ht = &d->dv_hashtab;
      hash_lock(ht);
      todo = (int)ht->ht_used;
      for (hi = ht->ht_array; todo > 0; ++hi) {
        if (!HASHITEM_EMPTY(hi)) {
          --todo;

          di = TV_DICT_HI2DI(hi);
          if (map
              && (tv_check_lock(di->di_tv.v_lock, arg_errmsg, TV_TRANSLATE)
                  || var_check_ro(di->di_flags, arg_errmsg, TV_TRANSLATE))) {
            break;
          }

          vimvars[VV_KEY].vv_str = vim_strsave(di->di_key);
          int r = filter_map_one(&di->di_tv, expr, map, &rem);
          tv_clear(&vimvars[VV_KEY].vv_tv);
          if (r == FAIL || did_emsg) {
            break;
          }
          if (!map && rem) {
            if (var_check_fixed(di->di_flags, arg_errmsg, TV_TRANSLATE)
                || var_check_ro(di->di_flags, arg_errmsg, TV_TRANSLATE)) {
              break;
            }
            tv_dict_item_remove(d, di);
          }
        }
      }
      hash_unlock(ht);
    } else {
      assert(argvars[0].v_type == VAR_LIST);
      vimvars[VV_KEY].vv_type = VAR_NUMBER;

      for (listitem_T *li = tv_list_first(l); li != NULL;) {
        if (map
            && tv_check_lock(TV_LIST_ITEM_TV(li)->v_lock, arg_errmsg,
                             TV_TRANSLATE)) {
          break;
        }
        vimvars[VV_KEY].vv_nr = idx;
        if (filter_map_one(TV_LIST_ITEM_TV(li), expr, map, &rem) == FAIL
            || did_emsg) {
          break;
        }
        if (!map && rem) {
          li = tv_list_item_remove(l, li);
        } else {
          li = TV_LIST_ITEM_NEXT(l, li);
        }
        idx++;
      }
    }

    restore_vimvar(VV_KEY, &save_key);
    restore_vimvar(VV_VAL, &save_val);

    did_emsg |= save_did_emsg;
  }
}

static int filter_map_one(typval_T *tv, typval_T *expr, int map, int *remp)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  typval_T rettv;
  typval_T argv[3];
  int retval = FAIL;

  tv_copy(tv, &vimvars[VV_VAL].vv_tv);
  argv[0] = vimvars[VV_KEY].vv_tv;
  argv[1] = vimvars[VV_VAL].vv_tv;
  if (eval_expr_typval(expr, argv, 2, &rettv) == FAIL) {
    goto theend;
  }
  if (map) {
    // map(): replace the list item value.
    tv_clear(tv);
    rettv.v_lock = 0;
    *tv = rettv;
  } else {
    bool error = false;

    // filter(): when expr is zero remove the item
    *remp = (tv_get_number_chk(&rettv, &error) == 0);
    tv_clear(&rettv);
    // On type error, nothing has been removed; return FAIL to stop the
    // loop.  The error message was given by tv_get_number_chk().
    if (error) {
      goto theend;
    }
  }
  retval = OK;
theend:
  tv_clear(&vimvars[VV_VAL].vv_tv);
  return retval;
}

void common_function(typval_T *argvars, typval_T *rettv,
                     bool is_funcref, FunPtr fptr)
{
  char_u      *s;
  char_u      *name;
  bool use_string = false;
  partial_T *arg_pt = NULL;
  char_u *trans_name = NULL;

  if (argvars[0].v_type == VAR_FUNC) {
    // function(MyFunc, [arg], dict)
    s = argvars[0].vval.v_string;
  } else if (argvars[0].v_type == VAR_PARTIAL
             && argvars[0].vval.v_partial != NULL) {
    // function(dict.MyFunc, [arg])
    arg_pt = argvars[0].vval.v_partial;
    s = partial_name(arg_pt);
  } else {
    // function('MyFunc', [arg], dict)
    s = (char_u *)tv_get_string(&argvars[0]);
    use_string = true;
  }

  if ((use_string && vim_strchr(s, AUTOLOAD_CHAR) == NULL) || is_funcref) {
    name = s;
    trans_name = trans_function_name(&name, false,
                                     TFN_INT | TFN_QUIET | TFN_NO_AUTOLOAD
                                     | TFN_NO_DEREF, NULL, NULL);
    if (*name != NUL) {
      s = NULL;
    }
  }
  if (s == NULL || *s == NUL || (use_string && ascii_isdigit(*s))
      || (is_funcref && trans_name == NULL)) {
    emsgf(_(e_invarg2), (use_string
                         ? tv_get_string(&argvars[0])
                         : (const char *)s));
    // Don't check an autoload name for existence here.
  } else if (trans_name != NULL
             && (is_funcref ? find_func(trans_name) == NULL
                 : !translated_function_exists((const char *)trans_name))) {
    emsgf(_("E700: Unknown function: %s"), s);
  } else {
    int dict_idx = 0;
    int arg_idx = 0;
    list_T *list = NULL;
    if (STRNCMP(s, "s:", 2) == 0 || STRNCMP(s, "<SID>", 5) == 0) {
      char sid_buf[25];
      int off = *s == 's' ? 2 : 5;

      // Expand s: and <SID> into <SNR>nr_, so that the function can
      // also be called from another script. Using trans_function_name()
      // would also work, but some plugins depend on the name being
      // printable text.
      snprintf(sid_buf, sizeof(sid_buf), "<SNR>%" PRId64 "_",
               (int64_t)current_sctx.sc_sid);
      name = xmalloc(STRLEN(sid_buf) + STRLEN(s + off) + 1);
      STRCPY(name, sid_buf);
      STRCAT(name, s + off);
    } else {
      name = vim_strsave(s);
    }

    if (argvars[1].v_type != VAR_UNKNOWN) {
      if (argvars[2].v_type != VAR_UNKNOWN) {
        // function(name, [args], dict)
        arg_idx = 1;
        dict_idx = 2;
      } else if (argvars[1].v_type == VAR_DICT) {
        // function(name, dict)
        dict_idx = 1;
      } else {
        // function(name, [args])
        arg_idx = 1;
      }
      if (dict_idx > 0) {
        if (argvars[dict_idx].v_type != VAR_DICT) {
          EMSG(_("E922: expected a dict"));
          xfree(name);
          goto theend;
        }
        if (argvars[dict_idx].vval.v_dict == NULL) {
          dict_idx = 0;
        }
      }
      if (arg_idx > 0) {
        if (argvars[arg_idx].v_type != VAR_LIST) {
          EMSG(_("E923: Second argument of function() must be "
                 "a list or a dict"));
          xfree(name);
          goto theend;
        }
        list = argvars[arg_idx].vval.v_list;
        if (tv_list_len(list) == 0) {
          arg_idx = 0;
        }
      }
    }
    if (dict_idx > 0 || arg_idx > 0 || arg_pt != NULL || is_funcref) {
      partial_T *const pt = xcalloc(1, sizeof(*pt));

      // result is a VAR_PARTIAL
      if (arg_idx > 0 || (arg_pt != NULL && arg_pt->pt_argc > 0)) {
        const int arg_len = (arg_pt == NULL ? 0 : arg_pt->pt_argc);
        const int lv_len = tv_list_len(list);

        pt->pt_argc = arg_len + lv_len;
        pt->pt_argv = xmalloc(sizeof(pt->pt_argv[0]) * pt->pt_argc);
        int i = 0;
        for (; i < arg_len; i++) {
          tv_copy(&arg_pt->pt_argv[i], &pt->pt_argv[i]);
        }
        if (lv_len > 0) {
          TV_LIST_ITER(list, li, {
            tv_copy(TV_LIST_ITEM_TV(li), &pt->pt_argv[i++]);
          });
        }
      }

      // For "function(dict.func, [], dict)" and "func" is a partial
      // use "dict". That is backwards compatible.
      if (dict_idx > 0) {
        // The dict is bound explicitly, pt_auto is false
        pt->pt_dict = argvars[dict_idx].vval.v_dict;
        (pt->pt_dict->dv_refcount)++;
      } else if (arg_pt != NULL) {
        // If the dict was bound automatically the result is also
        // bound automatically.
        pt->pt_dict = arg_pt->pt_dict;
        pt->pt_auto = arg_pt->pt_auto;
        if (pt->pt_dict != NULL) {
          (pt->pt_dict->dv_refcount)++;
        }
      }

      pt->pt_refcount = 1;
      if (arg_pt != NULL && arg_pt->pt_func != NULL) {
        pt->pt_func = arg_pt->pt_func;
        func_ptr_ref(pt->pt_func);
        xfree(name);
      } else if (is_funcref) {
        pt->pt_func = find_func(trans_name);
        func_ptr_ref(pt->pt_func);
        xfree(name);
      } else {
        pt->pt_name = name;
        func_ref(name);
      }

      rettv->v_type = VAR_PARTIAL;
      rettv->vval.v_partial = pt;
    } else {
      // result is a VAR_FUNC
      rettv->v_type = VAR_FUNC;
      rettv->vval.v_string = name;
      func_ref(name);
    }
  }
theend:
  xfree(trans_name);
}

/// Returns buffer options, variables and other attributes in a dictionary.
dict_T *get_buffer_info(buf_T *buf)
{
  dict_T *const dict = tv_dict_alloc();

  tv_dict_add_nr(dict, S_LEN("bufnr"), buf->b_fnum);
  tv_dict_add_str(dict, S_LEN("name"),
                  buf->b_ffname != NULL ? (const char *)buf->b_ffname : "");
  tv_dict_add_nr(dict, S_LEN("lnum"),
                 buf == curbuf ? curwin->w_cursor.lnum : buflist_findlnum(buf));
  tv_dict_add_nr(dict, S_LEN("linecount"), buf->b_ml.ml_line_count);
  tv_dict_add_nr(dict, S_LEN("loaded"), buf->b_ml.ml_mfp != NULL);
  tv_dict_add_nr(dict, S_LEN("listed"), buf->b_p_bl);
  tv_dict_add_nr(dict, S_LEN("changed"), bufIsChanged(buf));
  tv_dict_add_nr(dict, S_LEN("changedtick"), buf_get_changedtick(buf));
  tv_dict_add_nr(dict, S_LEN("hidden"),
                 buf->b_ml.ml_mfp != NULL && buf->b_nwindows == 0);

  // Get a reference to buffer variables
  tv_dict_add_dict(dict, S_LEN("variables"), buf->b_vars);

  // List of windows displaying this buffer
  list_T *const windows = tv_list_alloc(kListLenMayKnow);
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->w_buffer == buf) {
      tv_list_append_number(windows, (varnumber_T)wp->handle);
    }
  }
  tv_dict_add_list(dict, S_LEN("windows"), windows);

  if (buf->b_signlist != NULL) {
    // List of signs placed in this buffer
    tv_dict_add_list(dict, S_LEN("signs"), get_buffer_signs(buf));
  }

  return dict;
}

/// Get the line number from VimL object
///
/// @note Unlike tv_get_lnum(), this one supports only "$" special string.
///
/// @param[in]  tv  Object to get value from. Is expected to be a number or
///                 a special string "$".
/// @param[in]  buf  Buffer to take last line number from in case tv is "$". May
///                  be NULL, in this case "$" results in zero return.
///
/// @return Line number or 0 in case of error.
linenr_T tv_get_lnum_buf(const typval_T *const tv,
                         const buf_T *const buf)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (tv->v_type == VAR_STRING
      && tv->vval.v_string != NULL
      && tv->vval.v_string[0] == '$'
      && buf != NULL) {
    return buf->b_ml.ml_line_count;
  }
  return tv_get_number_chk(tv, NULL);
}

void get_qf_loc_list(int is_qf, win_T *wp, typval_T *what_arg,
                     typval_T *rettv)
{
  if (what_arg->v_type == VAR_UNKNOWN) {
    tv_list_alloc_ret(rettv, kListLenMayKnow);
    if (is_qf || wp != NULL) {
      (void)get_errorlist(NULL, wp, -1, rettv->vval.v_list);
    }
  } else {
    tv_dict_alloc_ret(rettv);
    if (is_qf || wp != NULL) {
      if (what_arg->v_type == VAR_DICT) {
        dict_T *d = what_arg->vval.v_dict;

        if (d != NULL) {
          qf_get_properties(wp, d, rettv->vval.v_dict);
        }
      } else {
        EMSG(_(e_dictreq));
      }
    }
  }
}

/// Returns information (variables, options, etc.) about a tab page
/// as a dictionary.
dict_T *get_tabpage_info(tabpage_T *tp, int tp_idx)
{
  dict_T *const dict = tv_dict_alloc();

  tv_dict_add_nr(dict, S_LEN("tabnr"), tp_idx);

  list_T *const l = tv_list_alloc(kListLenMayKnow);
  FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
    tv_list_append_number(l, (varnumber_T)wp->handle);
  }
  tv_dict_add_list(dict, S_LEN("windows"), l);

  // Make a reference to tabpage variables
  tv_dict_add_dict(dict, S_LEN("variables"), tp->tp_vars);

  return dict;
}

/// Returns information about a window as a dictionary.
dict_T *get_win_info(win_T *wp, int16_t tpnr, int16_t winnr)
{
  dict_T *const dict = tv_dict_alloc();

  tv_dict_add_nr(dict, S_LEN("tabnr"), tpnr);
  tv_dict_add_nr(dict, S_LEN("winnr"), winnr);
  tv_dict_add_nr(dict, S_LEN("winid"), wp->handle);
  tv_dict_add_nr(dict, S_LEN("height"), wp->w_height);
  tv_dict_add_nr(dict, S_LEN("winrow"), wp->w_winrow + 1);
  tv_dict_add_nr(dict, S_LEN("topline"), wp->w_topline);
  tv_dict_add_nr(dict, S_LEN("botline"), wp->w_botline - 1);
  tv_dict_add_nr(dict, S_LEN("width"), wp->w_width);
  tv_dict_add_nr(dict, S_LEN("bufnr"), wp->w_buffer->b_fnum);
  tv_dict_add_nr(dict, S_LEN("wincol"), wp->w_wincol + 1);

  tv_dict_add_nr(dict, S_LEN("terminal"), bt_terminal(wp->w_buffer));
  tv_dict_add_nr(dict, S_LEN("quickfix"), bt_quickfix(wp->w_buffer));
  tv_dict_add_nr(dict, S_LEN("loclist"),
                 (bt_quickfix(wp->w_buffer) && wp->w_llist_ref != NULL));

  // Add a reference to window variables
  tv_dict_add_dict(dict, S_LEN("variables"), wp->w_vars);

  return dict;
}

// Find window specified by "vp" in tabpage "tp".
win_T *
find_win_by_nr(
    typval_T *vp,
    tabpage_T *tp         /* NULL for current tab page */
)
{
  int nr = (int)tv_get_number_chk(vp, NULL);

  if (nr < 0) {
    return NULL;
  }

  if (nr == 0) {
    return curwin;
  }

  // This method accepts NULL as an alias for curtab.
  if (tp == NULL) {
     tp = curtab;
  }

  FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
    if (nr >= LOWEST_WIN_ID) {
      if (wp->handle == nr) {
        return wp;
      }
    } else if (--nr <= 0) {
      return wp;
    }
  }
  return NULL;
}

/// Find window specified by "wvp" in tabpage "tvp".
win_T *find_tabwin(typval_T *wvp, typval_T *tvp)
{
  win_T *wp = NULL;
  tabpage_T *tp = NULL;

  if (wvp->v_type != VAR_UNKNOWN) {
    if (tvp->v_type != VAR_UNKNOWN) {
      long n = tv_get_number(tvp);
      if (n >= 0) {
        tp = find_tabpage(n);
      }
    } else {
      tp = curtab;
    }

    if (tp != NULL) {
      wp = find_win_by_nr(wvp, tp);
    }
  } else {
    wp = curwin;
  }

  return wp;
}

/*
 * getwinvar() and gettabwinvar()
 */
void
getwinvar(
    typval_T *argvars,
    typval_T *rettv,
    int off                    /* 1 for gettabwinvar() */
)
{
  win_T *win, *oldcurwin;
  dictitem_T *v;
  tabpage_T *tp = NULL;
  tabpage_T *oldtabpage = NULL;
  bool done = false;

  if (off == 1) {
    tp = find_tabpage((int)tv_get_number_chk(&argvars[0], NULL));
  } else {
    tp = curtab;
  }
  win = find_win_by_nr(&argvars[off], tp);
  const char *varname = tv_get_string_chk(&argvars[off + 1]);

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;

  emsg_off++;
  if (win != NULL && varname != NULL) {
    // Set curwin to be our win, temporarily.  Also set the tabpage,
    // otherwise the window is not valid. Only do this when needed,
    // autocommands get blocked.
    bool need_switch_win = tp != curtab || win != curwin;
    if (!need_switch_win
        || switch_win(&oldcurwin, &oldtabpage, win, tp, true) == OK) {
      if (*varname == '&') {
        if (varname[1] == NUL) {
          // get all window-local options in a dict
          dict_T *opts = get_winbuf_options(false);

          if (opts != NULL) {
            tv_dict_set_ret(rettv, opts);
            done = true;
          }
        } else if (get_option_tv(&varname, rettv, 1) == OK) {
          // window-local-option
          done = true;
        }
      } else {
        // Look up the variable.
        // Let getwinvar({nr}, "") return the "w:" dictionary.
        v = find_var_in_ht(&win->w_vars->dv_hashtab, 'w', varname,
                           strlen(varname), false);
        if (v != NULL) {
          tv_copy(&v->di_tv, rettv);
          done = true;
        }
      }
    }

    if (need_switch_win) {
      // restore previous notion of curwin
      restore_win(oldcurwin, oldtabpage, true);
    }
  }
  emsg_off--;

  if (!done && argvars[off + 2].v_type != VAR_UNKNOWN) {
    // use the default return value
    tv_copy(&argvars[off + 2], rettv);
  }
}

/*
 * This function is used by f_input() and f_inputdialog() functions. The third
 * argument to f_input() specifies the type of completion to use at the
 * prompt. The third argument to f_inputdialog() specifies the value to return
 * when the user cancels the prompt.
 */
void get_user_input(const typval_T *const argvars,
                    typval_T *const rettv,
                    const bool inputdialog,
                    const bool secret)
  FUNC_ATTR_NONNULL_ALL
{
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;

  const char *prompt = "";
  const char *defstr = "";
  const char *cancelreturn = NULL;
  const char *xp_name = NULL;
  Callback input_callback = { .type = kCallbackNone };
  char prompt_buf[NUMBUFLEN];
  char defstr_buf[NUMBUFLEN];
  char cancelreturn_buf[NUMBUFLEN];
  char xp_name_buf[NUMBUFLEN];
  char def[1] = { 0 };
  if (argvars[0].v_type == VAR_DICT) {
    if (argvars[1].v_type != VAR_UNKNOWN) {
      EMSG(_("E5050: {opts} must be the only argument"));
      return;
    }
    dict_T *const dict = argvars[0].vval.v_dict;
    prompt = tv_dict_get_string_buf_chk(dict, S_LEN("prompt"), prompt_buf, "");
    if (prompt == NULL) {
      return;
    }
    defstr = tv_dict_get_string_buf_chk(dict, S_LEN("default"), defstr_buf, "");
    if (defstr == NULL) {
      return;
    }
    cancelreturn = tv_dict_get_string_buf_chk(dict, S_LEN("cancelreturn"),
                                              cancelreturn_buf, def);
    if (cancelreturn == NULL) {  // error
      return;
    }
    if (*cancelreturn == NUL) {
      cancelreturn = NULL;
    }
    xp_name = tv_dict_get_string_buf_chk(dict, S_LEN("completion"),
                                         xp_name_buf, def);
    if (xp_name == NULL) {  // error
      return;
    }
    if (xp_name == def) {  // default to NULL
      xp_name = NULL;
    }
    if (!tv_dict_get_callback(dict, S_LEN("highlight"), &input_callback)) {
      return;
    }
  } else {
    prompt = tv_get_string_buf_chk(&argvars[0], prompt_buf);
    if (prompt == NULL) {
      return;
    }
    if (argvars[1].v_type != VAR_UNKNOWN) {
      defstr = tv_get_string_buf_chk(&argvars[1], defstr_buf);
      if (defstr == NULL) {
        return;
      }
      if (argvars[2].v_type != VAR_UNKNOWN) {
        const char *const arg2 = tv_get_string_buf_chk(&argvars[2],
                                                       cancelreturn_buf);
        if (arg2 == NULL) {
          return;
        }
        if (inputdialog) {
          cancelreturn = arg2;
        } else {
          xp_name = arg2;
        }
      }
    }
  }

  int xp_type = EXPAND_NOTHING;
  char *xp_arg = NULL;
  if (xp_name != NULL) {
    // input() with a third argument: completion
    const int xp_namelen = (int)strlen(xp_name);

    uint32_t argt;
    if (parse_compl_arg((char_u *)xp_name, xp_namelen, &xp_type,
                        &argt, (char_u **)&xp_arg) == FAIL) {
      return;
    }
  }

  const bool cmd_silent_save = cmd_silent;

  cmd_silent = false;  // Want to see the prompt.
  // Only the part of the message after the last NL is considered as
  // prompt for the command line, unlsess cmdline is externalized
  const char *p = prompt;
  if (!ui_has(kUICmdline)) {
    const char *lastnl = strrchr(prompt, '\n');
    if (lastnl != NULL) {
      p = lastnl+1;
      msg_start();
      msg_clr_eos();
      msg_puts_attr_len(prompt, p - prompt, echo_attr);
      msg_didout = false;
      msg_starthere();
    }
  }
  cmdline_row = msg_row;

  stuffReadbuffSpec(defstr);

  const int save_ex_normal_busy = ex_normal_busy;
  ex_normal_busy = 0;
  rettv->vval.v_string =
    (char_u *)getcmdline_prompt(secret ? NUL : '@', p, echo_attr,
                                xp_type, xp_arg, input_callback);
  ex_normal_busy = save_ex_normal_busy;
  callback_free(&input_callback);

  if (rettv->vval.v_string == NULL && cancelreturn != NULL) {
    rettv->vval.v_string = (char_u *)xstrdup(cancelreturn);
  }

  xfree(xp_arg);

  // Since the user typed this, no need to wait for return.
  need_wait_return = false;
  msg_didout = false;
  cmd_silent = cmd_silent_save;
}

/// Turn a dictionary into a list
///
/// @param[in]  tv  Dictionary to convert. Is checked for actually being
///                 a dictionary, will give an error if not.
/// @param[out]  rettv  Location where result will be saved.
/// @param[in]  what  What to save in rettv.
void dict_list(typval_T *const tv, typval_T *const rettv,
               const DictListType what)
{
  if (tv->v_type != VAR_DICT) {
    EMSG(_(e_dictreq));
    return;
  }
  if (tv->vval.v_dict == NULL) {
    return;
  }

  tv_list_alloc_ret(rettv, tv_dict_len(tv->vval.v_dict));

  TV_DICT_ITER(tv->vval.v_dict, di, {
    typval_T tv_item = { .v_lock = VAR_UNLOCKED };

    switch (what) {
      case kDictListKeys: {
        tv_item.v_type = VAR_STRING;
        tv_item.vval.v_string = vim_strsave(di->di_key);
        break;
      }
      case kDictListValues: {
        tv_copy(&di->di_tv, &tv_item);
        break;
      }
      case kDictListItems: {
        // items()
        list_T *const sub_l = tv_list_alloc(2);
        tv_item.v_type = VAR_LIST;
        tv_item.vval.v_list = sub_l;
        tv_list_ref(sub_l);

        tv_list_append_owned_tv(sub_l, (typval_T) {
          .v_type = VAR_STRING,
          .v_lock = VAR_UNLOCKED,
          .vval.v_string = (char_u *)xstrdup((const char *)di->di_key),
        });

        tv_list_append_tv(sub_l, &di->di_tv);

        break;
      }
    }

    tv_list_append_owned_tv(rettv->vval.v_list, tv_item);
  });
}

/// Builds a process argument vector from a VimL object (typval_T).
///
/// @param[in]  cmd_tv      VimL object
/// @param[out] cmd         Returns the command or executable name.
/// @param[out] executable  Returns `false` if argv[0] is not executable.
///
/// @returns Result of `shell_build_argv()` if `cmd_tv` is a String.
///          Else, string values of `cmd_tv` copied to a (char **) list with
///          argv[0] resolved to full path ($PATHEXT-resolved on Windows).
char **tv_to_argv(typval_T *cmd_tv, const char **cmd, bool *executable)
{
  if (cmd_tv->v_type == VAR_STRING) {  // String => "shell semantics".
    const char *cmd_str = tv_get_string(cmd_tv);
    if (cmd) {
      *cmd = cmd_str;
    }
    return shell_build_argv(cmd_str, NULL);
  }

  if (cmd_tv->v_type != VAR_LIST) {
    EMSG2(_(e_invarg2), "expected String or List");
    return NULL;
  }

  list_T *argl = cmd_tv->vval.v_list;
  int argc = tv_list_len(argl);
  if (!argc) {
    EMSG(_(e_invarg));  // List must have at least one item.
    return NULL;
  }

  const char *arg0 = tv_get_string_chk(TV_LIST_ITEM_TV(tv_list_first(argl)));
  char *exe_resolved = NULL;
  if (!arg0 || !os_can_exe(arg0, &exe_resolved, true)) {
    if (arg0 && executable) {
      char buf[IOSIZE];
      snprintf(buf, sizeof(buf), "'%s' is not executable", arg0);
      EMSG3(_(e_invargNval), "cmd", buf);
      *executable = false;
    }
    return NULL;
  }

  if (cmd) {
    *cmd = exe_resolved;
  }

  // Build the argument vector
  int i = 0;
  char **argv = xcalloc(argc + 1, sizeof(char *));
  TV_LIST_ITER_CONST(argl, arg, {
    const char *a = tv_get_string_chk(TV_LIST_ITEM_TV(arg));
    if (!a) {
      // Did emsg in tv_get_string_chk; just deallocate argv.
      shell_free_argv(argv);
      xfree(exe_resolved);
      return NULL;
    }
    argv[i++] = xstrdup(a);
  });
  // Replace argv[0] with absolute path. The only reason for this is to make
  // $PATHEXT work on Windows with jobstart([…]). #9569
  xfree(argv[0]);
  argv[0] = exe_resolved;

  return argv;
}

/// Fill a dictionary with all applicable maparg() like dictionaries
///
/// @param  dict  The dictionary to be filled
/// @param  mp  The maphash that contains the mapping information
/// @param  buffer_value  The "buffer" value
/// @param  compatible  True for compatible with old maparg() dict
void mapblock_fill_dict(dict_T *const dict,
                        const mapblock_T *const mp,
                        long buffer_value,
                        bool compatible)
  FUNC_ATTR_NONNULL_ALL
{
  char *const lhs = str2special_save((const char *)mp->m_keys,
                                     compatible, !compatible);
  char *const mapmode = map_mode_to_chars(mp->m_mode);
  varnumber_T noremap_value;

  if (compatible) {
    // Keep old compatible behavior
    // This is unable to determine whether a mapping is a <script> mapping
    noremap_value = !!mp->m_noremap;
  } else {
    // Distinguish between <script> mapping
    // If it's not a <script> mapping, check if it's a noremap
    noremap_value = mp->m_noremap == REMAP_SCRIPT ? 2 : !!mp->m_noremap;
  }

  if (compatible) {
    tv_dict_add_str(dict, S_LEN("rhs"), (const char *)mp->m_orig_str);
  } else {
    tv_dict_add_allocated_str(dict, S_LEN("rhs"),
                              str2special_save((const char *)mp->m_str, false,
                                               true));
  }
  tv_dict_add_allocated_str(dict, S_LEN("lhs"), lhs);
  tv_dict_add_nr(dict, S_LEN("noremap"), noremap_value);
  tv_dict_add_nr(dict, S_LEN("expr"),  mp->m_expr ? 1 : 0);
  tv_dict_add_nr(dict, S_LEN("silent"), mp->m_silent ? 1 : 0);
  tv_dict_add_nr(dict, S_LEN("sid"), (varnumber_T)mp->m_script_ctx.sc_sid);
  tv_dict_add_nr(dict, S_LEN("lnum"), (varnumber_T)mp->m_script_ctx.sc_lnum);
  tv_dict_add_nr(dict, S_LEN("buffer"), (varnumber_T)buffer_value);
  tv_dict_add_nr(dict, S_LEN("nowait"), mp->m_nowait ? 1 : 0);
  tv_dict_add_allocated_str(dict, S_LEN("mode"), mapmode);
}

int matchadd_dict_arg(typval_T *tv, const char **conceal_char,
                      win_T **win)
{
  dictitem_T *di;

  if (tv->v_type != VAR_DICT) {
    EMSG(_(e_dictreq));
    return FAIL;
  }

  if ((di = tv_dict_find(tv->vval.v_dict, S_LEN("conceal"))) != NULL) {
    *conceal_char = tv_get_string(&di->di_tv);
  }

  if ((di = tv_dict_find(tv->vval.v_dict, S_LEN("window"))) != NULL) {
    *win = find_win_by_nr_or_id(&di->di_tv);
    if (*win == NULL) {
      EMSG(_("E957: Invalid window number"));
      return FAIL;
    }
  }

  return OK;
}

void return_register(int regname, typval_T *rettv)
{
  char_u buf[2] = { regname, 0 };

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = vim_strsave(buf);
}

void screenchar_adjust_grid(ScreenGrid **grid, int *row, int *col)
{
  // TODO(bfredl): this is a hack for legacy tests which use screenchar()
  // to check printed messages on the screen (but not floats etc
  // as these are not legacy features). If the compositor is refactored to
  // have its own buffer, this should just read from it instead.
  msg_scroll_flush();
  if (msg_grid.chars && msg_grid.comp_index > 0 && *row >= msg_grid.comp_row
      && *row < (msg_grid.Rows + msg_grid.comp_row)
      && *col < msg_grid.Columns) {
    *grid = &msg_grid;
    *row -= msg_grid.comp_row;
  }
}

/// Set line or list of lines in buffer "buf".
void set_buffer_lines(buf_T *buf, linenr_T lnum_arg, bool append,
                      const typval_T *lines, typval_T *rettv)
  FUNC_ATTR_NONNULL_ARG(4, 5)
{
  linenr_T lnum = lnum_arg + (append ? 1 : 0);
  const char *line = NULL;
  list_T      *l = NULL;
  listitem_T  *li = NULL;
  long        added = 0;
  linenr_T append_lnum;
  buf_T       *curbuf_save = NULL;
  win_T       *curwin_save = NULL;
  const bool is_curbuf = buf == curbuf;

  // When using the current buffer ml_mfp will be set if needed.  Useful when
  // setline() is used on startup.  For other buffers the buffer must be
  // loaded.
  if (buf == NULL || (!is_curbuf && buf->b_ml.ml_mfp == NULL) || lnum < 1) {
    rettv->vval.v_number = 1;  // FAIL
    return;
  }

  if (!is_curbuf) {
    curbuf_save = curbuf;
    curwin_save = curwin;
    curbuf = buf;
    find_win_for_curbuf();
  }

  if (append) {
    // appendbufline() uses the line number below which we insert
    append_lnum = lnum - 1;
  } else {
    // setbufline() uses the line number above which we insert, we only
    // append if it's below the last line
    append_lnum = curbuf->b_ml.ml_line_count;
  }

  if (lines->v_type == VAR_LIST) {
    l = lines->vval.v_list;
    li = tv_list_first(l);
  } else {
    line = tv_get_string_chk(lines);
  }

  // Default result is zero == OK.
  for (;; ) {
    if (lines->v_type == VAR_LIST) {
      // List argument, get next string.
      if (li == NULL) {
        break;
      }
      line = tv_get_string_chk(TV_LIST_ITEM_TV(li));
      li = TV_LIST_ITEM_NEXT(l, li);
    }

    rettv->vval.v_number = 1;  // FAIL
    if (line == NULL || lnum > curbuf->b_ml.ml_line_count + 1) {
      break;
    }

    // When coming here from Insert mode, sync undo, so that this can be
    // undone separately from what was previously inserted.
    if (u_sync_once == 2) {
      u_sync_once = 1;  // notify that u_sync() was called
      u_sync(true);
    }

    if (!append && lnum <= curbuf->b_ml.ml_line_count) {
      // Existing line, replace it.
      if (u_savesub(lnum) == OK
          && ml_replace(lnum, (char_u *)line, true) == OK) {
        changed_bytes(lnum, 0);
        if (is_curbuf && lnum == curwin->w_cursor.lnum) {
          check_cursor_col();
        }
        rettv->vval.v_number = 0;  // OK
      }
    } else if (added > 0 || u_save(lnum - 1, lnum) == OK) {
      // append the line.
      added++;
      if (ml_append(lnum - 1, (char_u *)line, 0, false) == OK) {
        rettv->vval.v_number = 0;  // OK
      }
    }

    if (l == NULL) {  // only one string argument
      break;
    }
    lnum++;
  }

  if (added > 0) {
    appended_lines_mark(append_lnum, added);

    // Only adjust the cursor for buffers other than the current, unless it
    // is the current window. For curbuf and other windows it has been done
    // in mark_adjust_internal().
    FOR_ALL_TAB_WINDOWS(tp, wp) {
      if (wp->w_buffer == buf
          && (wp->w_buffer != curbuf || wp == curwin)
          && wp->w_cursor.lnum > append_lnum) {
        wp->w_cursor.lnum += added;
      }
    }
    check_cursor_col();
    update_topline();
  }

  if (!is_curbuf) {
     curbuf = curbuf_save;
     curwin = curwin_save;
  }
}

/*
 * "setwinvar()" and "settabwinvar()" functions
 */

void setwinvar(typval_T *argvars, typval_T *rettv, int off)
{
  if (check_secure()) {
    return;
  }

  tabpage_T *tp = NULL;
  if (off == 1) {
    tp = find_tabpage((int)tv_get_number_chk(&argvars[0], NULL));
  } else {
    tp = curtab;
  }
  win_T *const win = find_win_by_nr(&argvars[off], tp);
  const char *varname = tv_get_string_chk(&argvars[off + 1]);
  typval_T *varp = &argvars[off + 2];

  if (win != NULL && varname != NULL && varp != NULL) {
    win_T       *save_curwin;
    tabpage_T   *save_curtab;
    bool need_switch_win = tp != curtab || win != curwin;
    if (!need_switch_win
        || switch_win(&save_curwin, &save_curtab, win, tp, true) == OK) {
      if (*varname == '&') {
        long numval;
        bool error = false;

        varname++;
        numval = tv_get_number_chk(varp, &error);
        char nbuf[NUMBUFLEN];
        const char *const strval = tv_get_string_buf_chk(varp, nbuf);
        if (!error && strval != NULL) {
          set_option_value(varname, numval, strval, OPT_LOCAL);
        }
      } else {
        const size_t varname_len = strlen(varname);
        char *const winvarname = xmalloc(varname_len + 3);
        memcpy(winvarname, "w:", 2);
        memcpy(winvarname + 2, varname, varname_len + 1);
        set_var(winvarname, varname_len + 2, varp, true);
        xfree(winvarname);
      }
    }
    if (need_switch_win) {
      restore_win(save_curwin, save_curtab, true);
    }
  }
}

/// "stdpath()" helper for list results
void get_xdg_var_list(const XDGVarType xdg, typval_T *rettv)
  FUNC_ATTR_NONNULL_ALL
{
  const void *iter = NULL;
  list_T *const list = tv_list_alloc(kListLenShouldKnow);
  rettv->v_type = VAR_LIST;
  rettv->vval.v_list = list;
  tv_list_ref(list);
  char *const dirs = stdpaths_get_xdg_var(xdg);
  if (dirs == NULL) {
    return;
  }
  do {
    size_t dir_len;
    const char *dir;
    iter = vim_env_iter(':', dirs, iter, &dir, &dir_len);
    if (dir != NULL && dir_len > 0) {
      char *dir_with_nvim = xmemdupz(dir, dir_len);
      dir_with_nvim = concat_fnames_realloc(dir_with_nvim, "nvim", true);
      tv_list_append_string(list, dir_with_nvim, strlen(dir_with_nvim));
      xfree(dir_with_nvim);
    }
  } while (iter != NULL);
  xfree(dirs);
}

static list_T *string_to_list(const char *str, size_t len, const bool keepempty)
{
  if (!keepempty && str[len - 1] == NL) {
    len--;
  }
  list_T *const list = tv_list_alloc(kListLenMayKnow);
  encode_list_write(list, str, len);
  return list;
}

// os_system wrapper. Handles 'verbose', :profile, and v:shell_error.
void get_system_output_as_rettv(typval_T *argvars, typval_T *rettv,
                                bool retlist)
{
  proftime_T wait_time;
  bool profiling = do_profiling == PROF_YES;

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;

  if (check_restricted() || check_secure()) {
    return;
  }

  // get input to the shell command (if any), and its length
  ptrdiff_t input_len;
  char *input = save_tv_as_string(&argvars[1], &input_len, false);
  if (input_len < 0) {
    assert(input == NULL);
    return;
  }

  // get shell command to execute
  bool executable = true;
  char **argv = tv_to_argv(&argvars[0], NULL, &executable);
  if (!argv) {
    if (!executable) {
      set_vim_var_nr(VV_SHELL_ERROR, (long)-1);
    }
    xfree(input);
    return;  // Already did emsg.
  }

  if (p_verbose > 3) {
    char *cmdstr = shell_argv_to_str(argv);
    verbose_enter_scroll();
    smsg(_("Executing command: \"%s\""), cmdstr);
    msg_puts("\n\n");
    verbose_leave_scroll();
    xfree(cmdstr);
  }

  if (profiling) {
    prof_child_enter(&wait_time);
  }

  // execute the command
  size_t nread = 0;
  char *res = NULL;
  int status = os_system(argv, input, input_len, &res, &nread);

  if (profiling) {
    prof_child_exit(&wait_time);
  }

  xfree(input);

  set_vim_var_nr(VV_SHELL_ERROR, (long) status);

  if (res == NULL) {
    if (retlist) {
      // return an empty list when there's no output
      tv_list_alloc_ret(rettv, 0);
    } else {
      rettv->vval.v_string = (char_u *) xstrdup("");
    }
    return;
  }

  if (retlist) {
    int keepempty = 0;
    if (argvars[1].v_type != VAR_UNKNOWN && argvars[2].v_type != VAR_UNKNOWN) {
      keepempty = tv_get_number(&argvars[2]);
    }
    rettv->vval.v_list = string_to_list(res, nread, (bool)keepempty);
    tv_list_ref(rettv->vval.v_list);
    rettv->v_type = VAR_LIST;

    xfree(res);
  } else {
    // res may contain several NULs before the final terminating one.
    // Replace them with SOH (1) like in get_cmd_output() to avoid truncation.
    memchrsub(res, NUL, 1, nread);
#ifdef USE_CRNL
    // translate <CR><NL> into <NL>
    char *d = res;
    for (char *s = res; *s; ++s) {
      if (s[0] == CAR && s[1] == NL) {
        ++s;
      }

      *d++ = *s;
    }

    *d = NUL;
#endif
    rettv->vval.v_string = (char_u *) res;
  }
}

bool callback_from_typval(Callback *const callback, typval_T *const arg)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (arg->v_type == VAR_PARTIAL && arg->vval.v_partial != NULL) {
    callback->data.partial = arg->vval.v_partial;
    callback->data.partial->pt_refcount++;
    callback->type = kCallbackPartial;
  } else if (arg->v_type == VAR_FUNC || arg->v_type == VAR_STRING) {
    char_u *name = arg->vval.v_string;
    func_ref(name);
    callback->data.funcref = vim_strsave(name);
    callback->type = kCallbackFuncref;
  } else if (arg->v_type == VAR_NUMBER && arg->vval.v_number == 0) {
    callback->type = kCallbackNone;
  } else {
    EMSG(_("E921: Invalid callback argument"));
    return false;
  }
  return true;
}

bool callback_call(Callback *const callback, const int argcount_in,
                   typval_T *const argvars_in, typval_T *const rettv)
  FUNC_ATTR_NONNULL_ALL
{
  partial_T *partial;
  char_u *name;
  switch (callback->type) {
    case kCallbackFuncref:
      name = callback->data.funcref;
      partial = NULL;
      break;

    case kCallbackPartial:
      partial = callback->data.partial;
      name = partial_name(partial);
      break;

    case kCallbackNone:
      return false;
      break;

    default:
      abort();
  }

  int dummy;
  return call_func(name, (int)STRLEN(name), rettv, argcount_in, argvars_in,
                   NULL, curwin->w_cursor.lnum, curwin->w_cursor.lnum, &dummy,
                   true, partial, NULL);
}

static bool set_ref_in_callback(Callback *callback, int copyID,
                                ht_stack_T **ht_stack,
                                list_stack_T **list_stack)
{
  typval_T tv;
  switch (callback->type) {
    case kCallbackFuncref:
    case kCallbackNone:
      break;

    case kCallbackPartial:
      tv.v_type = VAR_PARTIAL;
      tv.vval.v_partial = callback->data.partial;
      return set_ref_in_item(&tv, copyID, ht_stack, list_stack);
      break;


    default:
      abort();
  }
  return false;
}

static bool set_ref_in_callback_reader(CallbackReader *reader, int copyID,
                                       ht_stack_T **ht_stack,
                                       list_stack_T **list_stack)
{
  if (set_ref_in_callback(&reader->cb, copyID, ht_stack, list_stack)) {
    return true;
  }

  if (reader->self) {
    typval_T tv;
    tv.v_type = VAR_DICT;
    tv.vval.v_dict = reader->self;
    return set_ref_in_item(&tv, copyID, ht_stack, list_stack);
  }
  return false;
}

timer_T *find_timer_by_nr(varnumber_T xx)
{
    return pmap_get(uint64_t)(timers, xx);
}

void add_timer_info(typval_T *rettv, timer_T *timer)
{
  list_T *list = rettv->vval.v_list;
  dict_T *dict = tv_dict_alloc();

  tv_list_append_dict(list, dict);
  tv_dict_add_nr(dict, S_LEN("id"), timer->timer_id);
  tv_dict_add_nr(dict, S_LEN("time"), timer->timeout);
  tv_dict_add_nr(dict, S_LEN("paused"), timer->paused);

  tv_dict_add_nr(dict, S_LEN("repeat"),
                 (timer->repeat_count < 0 ? -1 : timer->repeat_count));

  dictitem_T *di = tv_dict_item_alloc("callback");
  if (tv_dict_add(dict, di) == FAIL) {
    xfree(di);
    return;
  }

  if (timer->callback.type == kCallbackPartial) {
    di->di_tv.v_type = VAR_PARTIAL;
    di->di_tv.vval.v_partial = timer->callback.data.partial;
    timer->callback.data.partial->pt_refcount++;
  } else if (timer->callback.type == kCallbackFuncref) {
    di->di_tv.v_type = VAR_FUNC;
    di->di_tv.vval.v_string = vim_strsave(timer->callback.data.funcref);
  }
}

void add_timer_info_all(typval_T *rettv)
{
  tv_list_alloc_ret(rettv, timers->table->n_occupied);
  timer_T *timer;
  map_foreach_value(timers, timer, {
    if (!timer->stopped) {
      add_timer_info(rettv, timer);
    }
  })
}

// invoked on the main loop
void timer_due_cb(TimeWatcher *tw, void *data)
{
  timer_T *timer = (timer_T *)data;
  int save_did_emsg = did_emsg;
  int save_called_emsg = called_emsg;
  const bool save_ex_pressedreturn = get_pressedreturn();

  if (timer->stopped || timer->paused) {
    return;
  }

  timer->refcount++;
  // if repeat was negative repeat forever
  if (timer->repeat_count >= 0 && --timer->repeat_count == 0) {
    timer_stop(timer);
  }

  typval_T argv[2] = { TV_INITIAL_VALUE, TV_INITIAL_VALUE };
  argv[0].v_type = VAR_NUMBER;
  argv[0].vval.v_number = timer->timer_id;
  typval_T rettv = TV_INITIAL_VALUE;
  called_emsg = false;

  callback_call(&timer->callback, 1, argv, &rettv);

  // Handle error message
  if (called_emsg && did_emsg) {
    timer->emsg_count++;
    if (current_exception != NULL) {
      discard_current_exception();
    }
  }
  did_emsg = save_did_emsg;
  called_emsg = save_called_emsg;
  set_pressedreturn(save_ex_pressedreturn);

  if (timer->emsg_count >= 3) {
    timer_stop(timer);
  }

  tv_clear(&rettv);

  if (!timer->stopped && timer->timeout == 0) {
    // special case: timeout=0 means the callback will be
    // invoked again on the next event loop tick.
    // we don't use uv_idle_t to not spin the event loop
    // when the main loop is blocked.
    time_watcher_start(&timer->tw, timer_due_cb, 0, 0);
  }
  timer_decref(timer);
}

uint64_t timer_start(const long timeout,
                     const int repeat_count,
                     const Callback *const callback)
{
  timer_T *timer = xmalloc(sizeof *timer);
  timer->refcount = 1;
  timer->stopped = false;
  timer->paused = false;
  timer->emsg_count = 0;
  timer->repeat_count = repeat_count;
  timer->timeout = timeout;
  timer->timer_id = last_timer_id++;
  timer->callback = *callback;

  time_watcher_init(&main_loop, &timer->tw, timer);
  timer->tw.events = multiqueue_new_child(main_loop.events);
  // if main loop is blocked, don't queue up multiple events
  timer->tw.blockable = true;
  time_watcher_start(&timer->tw, timer_due_cb, timeout, timeout);

  pmap_put(uint64_t)(timers, timer->timer_id, timer);
  return timer->timer_id;
}

void timer_stop(timer_T *timer)
{
  if (timer->stopped) {
    // avoid double free
    return;
  }
  timer->stopped = true;
  time_watcher_stop(&timer->tw);
  time_watcher_close(&timer->tw, timer_close_cb);
}

// This will be run on the main loop after the last timer_due_cb, so at this
// point it is safe to free the callback.
static void timer_close_cb(TimeWatcher *tw, void *data)
{
  timer_T *timer = (timer_T *)data;
  multiqueue_free(timer->tw.events);
  callback_free(&timer->callback);
  pmap_del(uint64_t)(timers, timer->timer_id);
  timer_decref(timer);
}

static void timer_decref(timer_T *timer)
{
  if (--timer->refcount == 0) {
    xfree(timer);
  }
}

void timer_stop_all(void)
{
  timer_T *timer;
  map_foreach_value(timers, timer, {
    timer_stop(timer);
  })
}

void timer_teardown(void)
{
  timer_stop_all();
}

/// Write "list" of strings to file "fd".
///
/// @param  fp  File to write to.
/// @param[in]  list  List to write.
/// @param[in]  binary  Whether to write in binary mode.
///
/// @return true in case of success, false otherwise.
bool write_list(FileDescriptor *const fp, const list_T *const list,
                const bool binary)
  FUNC_ATTR_NONNULL_ARG(1)
{
  int error = 0;
  TV_LIST_ITER_CONST(list, li, {
    const char *const s = tv_get_string_chk(TV_LIST_ITEM_TV(li));
    if (s == NULL) {
      return false;
    }
    const char *hunk_start = s;
    for (const char *p = hunk_start;; p++) {
      if (*p == NUL || *p == NL) {
        if (p != hunk_start) {
          const ptrdiff_t written = file_write(fp, hunk_start,
                                               (size_t)(p - hunk_start));
          if (written < 0) {
            error = (int)written;
            goto write_list_error;
          }
        }
        if (*p == NUL) {
          break;
        } else {
          hunk_start = p + 1;
          const ptrdiff_t written = file_write(fp, (char[]){ NUL }, 1);
          if (written < 0) {
            error = (int)written;
            break;
          }
        }
      }
    }
    if (!binary || TV_LIST_ITEM_NEXT(list, li) != NULL) {
      const ptrdiff_t written = file_write(fp, "\n", 1);
      if (written < 0) {
        error = (int)written;
        goto write_list_error;
      }
    }
  });
  if ((error = file_flush(fp)) != 0) {
    goto write_list_error;
  }
  return true;
write_list_error:
  emsgf(_("E80: Error while writing: %s"), os_strerror(error));
  return false;
}

/// Saves a typval_T as a string.
///
/// For lists or buffers, replaces NLs with NUL and separates items with NLs.
///
/// @param[in]  tv   Value to store as a string.
/// @param[out] len  Length of the resulting string or -1 on error.
/// @param[in]  endnl If true, the output will end in a newline (if a list).
/// @returns an allocated string if `tv` represents a VimL string, list, or
///          number; NULL otherwise.
char *save_tv_as_string(typval_T *tv, ptrdiff_t *const len, bool endnl)
  FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  *len = 0;
  if (tv->v_type == VAR_UNKNOWN) {
    return NULL;
  }

  // For other types, let tv_get_string_buf_chk() get the value or
  // print an error.
  if (tv->v_type != VAR_LIST && tv->v_type != VAR_NUMBER) {
    const char *ret = tv_get_string_chk(tv);
    if (ret) {
      *len = strlen(ret);
      return xmemdupz(ret, (size_t)(*len));
    } else {
      *len = -1;
      return NULL;
    }
  }

  if (tv->v_type == VAR_NUMBER) {  // Treat number as a buffer-id.
    buf_T *buf = buflist_findnr(tv->vval.v_number);
    if (buf) {
      for (linenr_T lnum = 1; lnum <= buf->b_ml.ml_line_count; lnum++) {
        for (char_u *p = ml_get_buf(buf, lnum, false); *p != NUL; p++) {
          *len += 1;
        }
        *len += 1;
      }
    } else {
      EMSGN(_(e_nobufnr), tv->vval.v_number);
      *len = -1;
      return NULL;
    }

    if (*len == 0) {
      return NULL;
    }

    char *ret = xmalloc(*len + 1);
    char *end = ret;
    for (linenr_T lnum = 1; lnum <= buf->b_ml.ml_line_count; lnum++) {
      for (char_u *p = ml_get_buf(buf, lnum, false); *p != NUL; p++) {
        *end++ = (*p == '\n') ? NUL : *p;
      }
      *end++ = '\n';
    }
    *end = NUL;
    *len = end - ret;
    return ret;
  }

  assert(tv->v_type == VAR_LIST);
  // Pre-calculate the resulting length.
  list_T *list = tv->vval.v_list;
  TV_LIST_ITER_CONST(list, li, {
    *len += strlen(tv_get_string(TV_LIST_ITEM_TV(li))) + 1;
  });

  if (*len == 0) {
    return NULL;
  }

  char *ret = xmalloc(*len + endnl);
  char *end = ret;
  TV_LIST_ITER_CONST(list, li, {
    for (const char *s = tv_get_string(TV_LIST_ITEM_TV(li)); *s != NUL; s++) {
      *end++ = (*s == '\n') ? NUL : *s;
    }
    if (endnl || TV_LIST_ITEM_NEXT(list, li) != NULL) {
      *end++ = '\n';
    }
  });
  *end = NUL;
  *len = end - ret;
  return ret;
}

/// Translate a VimL object into a position
///
/// Accepts VAR_LIST and VAR_STRING objects. Does not give an error for invalid
/// type.
///
/// @param[in]  tv  Object to translate.
/// @param[in]  dollar_lnum  True when "$" is last line.
/// @param[out]  ret_fnum  Set to fnum for marks.
///
/// @return Pointer to position or NULL in case of error (e.g. invalid type).
pos_T *var2fpos(const typval_T *const tv, const int dollar_lnum,
                int *const ret_fnum)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  static pos_T pos;
  pos_T               *pp;

  // Argument can be [lnum, col, coladd].
  if (tv->v_type == VAR_LIST) {
    list_T          *l;
    int len;
    bool error = false;
    listitem_T *li;

    l = tv->vval.v_list;
    if (l == NULL) {
      return NULL;
    }

    // Get the line number.
    pos.lnum = tv_list_find_nr(l, 0L, &error);
    if (error || pos.lnum <= 0 || pos.lnum > curbuf->b_ml.ml_line_count) {
      // Invalid line number.
      return NULL;
    }

    // Get the column number.
    pos.col = tv_list_find_nr(l, 1L, &error);
    if (error) {
      return NULL;
    }
    len = (long)STRLEN(ml_get(pos.lnum));

    // We accept "$" for the column number: last column.
    li = tv_list_find(l, 1L);
    if (li != NULL && TV_LIST_ITEM_TV(li)->v_type == VAR_STRING
        && TV_LIST_ITEM_TV(li)->vval.v_string != NULL
        && STRCMP(TV_LIST_ITEM_TV(li)->vval.v_string, "$") == 0) {
      pos.col = len + 1;
    }

    // Accept a position up to the NUL after the line.
    if (pos.col == 0 || (int)pos.col > len + 1) {
      // Invalid column number.
      return NULL;
    }
    pos.col--;

    // Get the virtual offset.  Defaults to zero.
    pos.coladd = tv_list_find_nr(l, 2L, &error);
    if (error) {
      pos.coladd = 0;
    }

    return &pos;
  }

  const char *const name = tv_get_string_chk(tv);
  if (name == NULL) {
    return NULL;
  }
  if (name[0] == '.') {  // Cursor.
    return &curwin->w_cursor;
  }
  if (name[0] == 'v' && name[1] == NUL) {  // Visual start.
    if (VIsual_active) {
      return &VIsual;
    }
    return &curwin->w_cursor;
  }
  if (name[0] == '\'') {  // Mark.
    pp = getmark_buf_fnum(curbuf, (uint8_t)name[1], false, ret_fnum);
    if (pp == NULL || pp == (pos_T *)-1 || pp->lnum <= 0) {
      return NULL;
    }
    return pp;
  }

  pos.coladd = 0;

  if (name[0] == 'w' && dollar_lnum) {
    pos.col = 0;
    if (name[1] == '0') {               /* "w0": first visible line */
      update_topline();
      // In silent Ex mode topline is zero, but that's not a valid line
      // number; use one instead.
      pos.lnum = curwin->w_topline > 0 ? curwin->w_topline : 1;
      return &pos;
    } else if (name[1] == '$') {      /* "w$": last visible line */
      validate_botline();
      // In silent Ex mode botline is zero, return zero then.
      pos.lnum = curwin->w_botline > 0 ? curwin->w_botline - 1 : 0;
      return &pos;
    }
  } else if (name[0] == '$') {        /* last column or line */
    if (dollar_lnum) {
      pos.lnum = curbuf->b_ml.ml_line_count;
      pos.col = 0;
    } else {
      pos.lnum = curwin->w_cursor.lnum;
      pos.col = (colnr_T)STRLEN(get_cursor_line_ptr());
    }
    return &pos;
  }
  return NULL;
}

/*
 * Convert list in "arg" into a position and optional file number.
 * When "fnump" is NULL there is no file number, only 3 items.
 * Note that the column is passed on as-is, the caller may want to decrement
 * it to use 1 for the first column.
 * Return FAIL when conversion is not possible, doesn't check the position for
 * validity.
 */
int list2fpos(typval_T *arg, pos_T *posp, int *fnump, colnr_T *curswantp)
{
  list_T *l;
  long i = 0;
  long n;

  // List must be: [fnum, lnum, col, coladd, curswant], where "fnum" is only
  // there when "fnump" isn't NULL; "coladd" and "curswant" are optional.
  if (arg->v_type != VAR_LIST
      || (l = arg->vval.v_list) == NULL
      || tv_list_len(l) < (fnump == NULL ? 2 : 3)
      || tv_list_len(l) > (fnump == NULL ? 4 : 5)) {
    return FAIL;
  }

  if (fnump != NULL) {
    n = tv_list_find_nr(l, i++, NULL);  // fnum
    if (n < 0) {
      return FAIL;
    }
    if (n == 0) {
      n = curbuf->b_fnum;  // Current buffer.
    }
    *fnump = n;
  }

  n = tv_list_find_nr(l, i++, NULL);  // lnum
  if (n < 0) {
    return FAIL;
  }
  posp->lnum = n;

  n = tv_list_find_nr(l, i++, NULL);  // col
  if (n < 0) {
    return FAIL;
  }
  posp->col = n;

  n = tv_list_find_nr(l, i, NULL);  // off
  if (n < 0) {
    posp->coladd = 0;
  } else {
    posp->coladd = n;
  }

  if (curswantp != NULL) {
    *curswantp = tv_list_find_nr(l, i + 1, NULL);  // curswant
  }

  return OK;
}

/*
 * Get the length of an environment variable name.
 * Advance "arg" to the first character after the name.
 * Return 0 for error.
 */
static int get_env_len(const char_u **arg)
{
  int len;

  const char_u *p;
  for (p = *arg; vim_isIDc(*p); p++) {
  }
  if (p == *arg) {  // No name found.
    return 0;
  }

  len = (int)(p - *arg);
  *arg = p;
  return len;
}

// Get the length of the name of a function or internal variable.
// "arg" is advanced to the first non-white character after the name.
// Return 0 if something is wrong.
static int get_id_len(const char **const arg)
{
  int len;

  // Find the end of the name.
  const char *p;
  for (p = *arg; eval_isnamec(*p); p++) {
    if (*p == ':') {
      // "s:" is start of "s:var", but "n:" is not and can be used in
      // slice "[n:]". Also "xx:" is not a namespace.
      len = (int)(p - *arg);
      if (len > 1
          || (len == 1 && vim_strchr(namespace_char, **arg) == NULL)) {
        break;
      }
    }
  }
  if (p == *arg) {  // no name found
    return 0;
  }

  len = (int)(p - *arg);
  *arg = (const char *)skipwhite((const char_u *)p);

  return len;
}

/*
 * Get the length of the name of a variable or function.
 * Only the name is recognized, does not handle ".key" or "[idx]".
 * "arg" is advanced to the first non-white character after the name.
 * Return -1 if curly braces expansion failed.
 * Return 0 if something else is wrong.
 * If the name contains 'magic' {}'s, expand them and return the
 * expanded name in an allocated string via 'alias' - caller must free.
 */
int get_name_len(const char **const arg,
                 char **alias,
                 int evaluate,
                 int verbose)
{
  int len;

  *alias = NULL;    /* default to no alias */

  if ((*arg)[0] == (char)K_SPECIAL && (*arg)[1] == (char)KS_EXTRA
      && (*arg)[2] == (char)KE_SNR) {
    // Hard coded <SNR>, already translated.
    *arg += 3;
    return get_id_len(arg) + 3;
  }
  len = eval_fname_script(*arg);
  if (len > 0) {
    /* literal "<SID>", "s:" or "<SNR>" */
    *arg += len;
  }

  // Find the end of the name; check for {} construction.
  char_u      *expr_start;
  char_u      *expr_end;
  const char *p = (const char *)find_name_end((char_u *)(*arg),
                                              (const char_u **)&expr_start,
                                              (const char_u **)&expr_end,
                                              len > 0 ? 0 : FNE_CHECK_START);
  if (expr_start != NULL) {
    if (!evaluate) {
      len += (int)(p - *arg);
      *arg = (const char *)skipwhite((const char_u *)p);
      return len;
    }

    /*
     * Include any <SID> etc in the expanded string:
     * Thus the -len here.
     */
    char_u *temp_string = make_expanded_name((char_u *)(*arg) - len, expr_start,
                                             expr_end, (char_u *)p);
    if (temp_string == NULL) {
      return -1;
    }
    *alias = (char *)temp_string;
    *arg = (const char *)skipwhite((const char_u *)p);
    return (int)STRLEN(temp_string);
  }

  len += get_id_len(arg);
  // Only give an error when there is something, otherwise it will be
  // reported at a higher level.
  if (len == 0 && verbose && **arg != NUL) {
    EMSG2(_(e_invexpr2), *arg);
  }

  return len;
}

// Find the end of a variable or function name, taking care of magic braces.
// If "expr_start" is not NULL then "expr_start" and "expr_end" are set to the
// start and end of the first magic braces item.
// "flags" can have FNE_INCL_BR and FNE_CHECK_START.
// Return a pointer to just after the name.  Equal to "arg" if there is no
// valid name.
static const char_u *find_name_end(const char_u *arg, const char_u **expr_start,
                                   const char_u **expr_end, int flags)
{
  int mb_nest = 0;
  int br_nest = 0;
  int len;

  if (expr_start != NULL) {
    *expr_start = NULL;
    *expr_end = NULL;
  }

  // Quick check for valid starting character.
  if ((flags & FNE_CHECK_START) && !eval_isnamec1(*arg) && *arg != '{') {
    return arg;
  }

  const char_u *p;
  for (p = arg; *p != NUL
       && (eval_isnamec(*p)
           || *p == '{'
           || ((flags & FNE_INCL_BR) && (*p == '[' || *p == '.'))
           || mb_nest != 0
           || br_nest != 0); MB_PTR_ADV(p)) {
    if (*p == '\'') {
      // skip over 'string' to avoid counting [ and ] inside it.
      for (p = p + 1; *p != NUL && *p != '\''; MB_PTR_ADV(p)) {
      }
      if (*p == NUL) {
        break;
      }
    } else if (*p == '"') {
      // skip over "str\"ing" to avoid counting [ and ] inside it.
      for (p = p + 1; *p != NUL && *p != '"'; MB_PTR_ADV(p)) {
        if (*p == '\\' && p[1] != NUL) {
          ++p;
        }
      }
      if (*p == NUL) {
        break;
      }
    } else if (br_nest == 0 && mb_nest == 0 && *p == ':') {
      // "s:" is start of "s:var", but "n:" is not and can be used in
      // slice "[n:]".  Also "xx:" is not a namespace. But {ns}: is. */
      len = (int)(p - arg);
      if ((len > 1 && p[-1] != '}')
          || (len == 1 && vim_strchr(namespace_char, *arg) == NULL)) {
        break;
      }
    }

    if (mb_nest == 0) {
      if (*p == '[') {
        ++br_nest;
      } else if (*p == ']') {
        --br_nest;
      }
    }

    if (br_nest == 0) {
      if (*p == '{') {
        mb_nest++;
        if (expr_start != NULL && *expr_start == NULL) {
          *expr_start = p;
        }
      } else if (*p == '}') {
        mb_nest--;
        if (expr_start != NULL && mb_nest == 0 && *expr_end == NULL) {
          *expr_end = p;
        }
      }
    }
  }

  return p;
}

/*
 * Expands out the 'magic' {}'s in a variable/function name.
 * Note that this can call itself recursively, to deal with
 * constructs like foo{bar}{baz}{bam}
 * The four pointer arguments point to "foo{expre}ss{ion}bar"
 *			"in_start"      ^
 *			"expr_start"	   ^
 *			"expr_end"		 ^
 *			"in_end"			    ^
 *
 * Returns a new allocated string, which the caller must free.
 * Returns NULL for failure.
 */
static char_u *make_expanded_name(const char_u *in_start, char_u *expr_start,
                                  char_u *expr_end, char_u *in_end)
{
  char_u c1;
  char_u      *retval = NULL;
  char_u      *temp_result;
  char_u      *nextcmd = NULL;

  if (expr_end == NULL || in_end == NULL)
    return NULL;
  *expr_start = NUL;
  *expr_end = NUL;
  c1 = *in_end;
  *in_end = NUL;

  temp_result = eval_to_string(expr_start + 1, &nextcmd, FALSE);
  if (temp_result != NULL && nextcmd == NULL) {
    retval = xmalloc(STRLEN(temp_result) + (expr_start - in_start)
                     + (in_end - expr_end) + 1);
    STRCPY(retval, in_start);
    STRCAT(retval, temp_result);
    STRCAT(retval, expr_end + 1);
  }
  xfree(temp_result);

  *in_end = c1;                 /* put char back for error messages */
  *expr_start = '{';
  *expr_end = '}';

  if (retval != NULL) {
    temp_result = (char_u *)find_name_end(retval,
                                          (const char_u **)&expr_start,
                                          (const char_u **)&expr_end, 0);
    if (expr_start != NULL) {
      /* Further expansion! */
      temp_result = make_expanded_name(retval, expr_start,
          expr_end, temp_result);
      xfree(retval);
      retval = temp_result;
    }
  }

  return retval;
}

/*
 * Return TRUE if character "c" can be used in a variable or function name.
 * Does not include '{' or '}' for magic braces.
 */
static int eval_isnamec(int c)
{
  return ASCII_ISALNUM(c) || c == '_' || c == ':' || c == AUTOLOAD_CHAR;
}

/*
 * Return TRUE if character "c" can be used as the first character in a
 * variable or function name (excluding '{' and '}').
 */
static int eval_isnamec1(int c)
{
  return ASCII_ISALPHA(c) || c == '_';
}

/*
 * Get number v: variable value.
 */
varnumber_T get_vim_var_nr(int idx) FUNC_ATTR_PURE
{
  return vimvars[idx].vv_nr;
}

// Get string v: variable value.  Uses a static buffer, can only be used once.
// If the String variable has never been set, return an empty string.
// Never returns NULL;
char_u *get_vim_var_str(int idx) FUNC_ATTR_PURE FUNC_ATTR_NONNULL_RET
{
  return (char_u *)tv_get_string(&vimvars[idx].vv_tv);
}

/*
 * Get List v: variable value.  Caller must take care of reference count when
 * needed.
 */
list_T *get_vim_var_list(int idx) FUNC_ATTR_PURE
{
  return vimvars[idx].vv_list;
}

/// Get Dictionary v: variable value.  Caller must take care of reference count
/// when needed.
dict_T *get_vim_var_dict(int idx) FUNC_ATTR_PURE
{
  return vimvars[idx].vv_dict;
}

/*
 * Set v:char to character "c".
 */
void set_vim_var_char(int c)
{
  char buf[MB_MAXBYTES + 1];

  buf[utf_char2bytes(c, (char_u *)buf)] = NUL;
  set_vim_var_string(VV_CHAR, buf, -1);
}

/*
 * Set v:count to "count" and v:count1 to "count1".
 * When "set_prevcount" is TRUE first set v:prevcount from v:count.
 */
void set_vcount(long count, long count1, int set_prevcount)
{
  if (set_prevcount)
    vimvars[VV_PREVCOUNT].vv_nr = vimvars[VV_COUNT].vv_nr;
  vimvars[VV_COUNT].vv_nr = count;
  vimvars[VV_COUNT1].vv_nr = count1;
}

/// Set number v: variable to the given value
///
/// @param[in]  idx  Index of variable to set.
/// @param[in]  val  Value to set to.
void set_vim_var_nr(const VimVarIndex idx, const varnumber_T val)
{
  tv_clear(&vimvars[idx].vv_tv);
  vimvars[idx].vv_type = VAR_NUMBER;
  vimvars[idx].vv_nr = val;
}

/// Set special v: variable to the given value
///
/// @param[in]  idx  Index of variable to set.
/// @param[in]  val  Value to set to.
void set_vim_var_special(const VimVarIndex idx, const SpecialVarValue val)
{
  tv_clear(&vimvars[idx].vv_tv);
  vimvars[idx].vv_type = VAR_SPECIAL;
  vimvars[idx].vv_special = val;
}

/// Set string v: variable to the given string
///
/// @param[in]  idx  Index of variable to set.
/// @param[in]  val  Value to set to. Will be copied.
/// @param[in]  len  Legth of that value or -1 in which case strlen() will be
///                  used.
void set_vim_var_string(const VimVarIndex idx, const char *const val,
                        const ptrdiff_t len)
{
  tv_clear(&vimvars[idx].vv_di.di_tv);
  vimvars[idx].vv_type = VAR_STRING;
  if (val == NULL) {
    vimvars[idx].vv_str = NULL;
  } else if (len == -1) {
    vimvars[idx].vv_str = (char_u *) xstrdup(val);
  } else {
    vimvars[idx].vv_str = (char_u *) xstrndup(val, (size_t) len);
  }
}

/// Set list v: variable to the given list
///
/// @param[in]  idx  Index of variable to set.
/// @param[in,out]  val  Value to set to. Reference count will be incremented.
void set_vim_var_list(const VimVarIndex idx, list_T *const val)
{
  tv_clear(&vimvars[idx].vv_di.di_tv);
  vimvars[idx].vv_type = VAR_LIST;
  vimvars[idx].vv_list = val;
  if (val != NULL) {
    tv_list_ref(val);
  }
}

/// Set Dictionary v: variable to the given dictionary
///
/// @param[in]  idx  Index of variable to set.
/// @param[in,out]  val  Value to set to. Reference count will be incremented.
///                      Also keys of the dictionary will be made read-only.
void set_vim_var_dict(const VimVarIndex idx, dict_T *const val)
{
  tv_clear(&vimvars[idx].vv_di.di_tv);
  vimvars[idx].vv_type = VAR_DICT;
  vimvars[idx].vv_dict = val;

  if (val != NULL) {
    val->dv_refcount++;
    // Set readonly
    tv_dict_set_keys_readonly(val);
  }
}

/*
 * Set v:register if needed.
 */
void set_reg_var(int c)
{
  char regname;

  if (c == 0 || c == ' ') {
    regname = '"';
  } else {
    regname = c;
  }
  // Avoid free/alloc when the value is already right.
  if (vimvars[VV_REG].vv_str == NULL || vimvars[VV_REG].vv_str[0] != c) {
    set_vim_var_string(VV_REG, &regname, 1);
  }
}

/*
 * Get or set v:exception.  If "oldval" == NULL, return the current value.
 * Otherwise, restore the value to "oldval" and return NULL.
 * Must always be called in pairs to save and restore v:exception!  Does not
 * take care of memory allocations.
 */
char_u *v_exception(char_u *oldval)
{
  if (oldval == NULL)
    return vimvars[VV_EXCEPTION].vv_str;

  vimvars[VV_EXCEPTION].vv_str = oldval;
  return NULL;
}

/*
 * Get or set v:throwpoint.  If "oldval" == NULL, return the current value.
 * Otherwise, restore the value to "oldval" and return NULL.
 * Must always be called in pairs to save and restore v:throwpoint!  Does not
 * take care of memory allocations.
 */
char_u *v_throwpoint(char_u *oldval)
{
  if (oldval == NULL)
    return vimvars[VV_THROWPOINT].vv_str;

  vimvars[VV_THROWPOINT].vv_str = oldval;
  return NULL;
}

/*
 * Set v:cmdarg.
 * If "eap" != NULL, use "eap" to generate the value and return the old value.
 * If "oldarg" != NULL, restore the value to "oldarg" and return NULL.
 * Must always be called in pairs!
 */
char_u *set_cmdarg(exarg_T *eap, char_u *oldarg)
{
  char_u      *oldval;
  char_u      *newval;

  oldval = vimvars[VV_CMDARG].vv_str;
  if (eap == NULL) {
    xfree(oldval);
    vimvars[VV_CMDARG].vv_str = oldarg;
    return NULL;
  }

  size_t len = 0;
  if (eap->force_bin == FORCE_BIN)
    len = 6;
  else if (eap->force_bin == FORCE_NOBIN)
    len = 8;

  if (eap->read_edit)
    len += 7;

  if (eap->force_ff != 0)
    len += STRLEN(eap->cmd + eap->force_ff) + 6;
  if (eap->force_enc != 0)
    len += STRLEN(eap->cmd + eap->force_enc) + 7;
  if (eap->bad_char != 0)
    len += 7 + 4;      /* " ++bad=" + "keep" or "drop" */

  newval = xmalloc(len + 1);

  if (eap->force_bin == FORCE_BIN)
    sprintf((char *)newval, " ++bin");
  else if (eap->force_bin == FORCE_NOBIN)
    sprintf((char *)newval, " ++nobin");
  else
    *newval = NUL;

  if (eap->read_edit)
    STRCAT(newval, " ++edit");

  if (eap->force_ff != 0)
    sprintf((char *)newval + STRLEN(newval), " ++ff=%s",
        eap->cmd + eap->force_ff);
  if (eap->force_enc != 0)
    sprintf((char *)newval + STRLEN(newval), " ++enc=%s",
        eap->cmd + eap->force_enc);
  if (eap->bad_char == BAD_KEEP)
    STRCPY(newval + STRLEN(newval), " ++bad=keep");
  else if (eap->bad_char == BAD_DROP)
    STRCPY(newval + STRLEN(newval), " ++bad=drop");
  else if (eap->bad_char != 0)
    sprintf((char *)newval + STRLEN(newval), " ++bad=%c", eap->bad_char);
  vimvars[VV_CMDARG].vv_str = newval;
  return oldval;
}

/*
 * Get the value of internal variable "name".
 * Return OK or FAIL.
 */
int get_var_tv(
    const char *name,
    int len,           // length of "name"
    typval_T *rettv,   // NULL when only checking existence
    dictitem_T **dip,  // non-NULL when typval's dict item is needed
    int verbose,       // may give error message
    int no_autoload    // do not use script autoloading
)
{
  int ret = OK;
  typval_T    *tv = NULL;
  dictitem_T  *v;

  v = find_var(name, (size_t)len, NULL, no_autoload);
  if (v != NULL) {
    tv = &v->di_tv;
    if (dip != NULL) {
      *dip = v;
    }
  }

  if (tv == NULL) {
    if (rettv != NULL && verbose) {
      emsgf(_("E121: Undefined variable: %.*s"), len, name);
    }
    ret = FAIL;
  } else if (rettv != NULL) {
    tv_copy(tv, rettv);
  }

  return ret;
}

/// Check if variable "name[len]" is a local variable or an argument.
/// If so, "*eval_lavars_used" is set to TRUE.
static void check_vars(const char *name, size_t len)
{
  if (eval_lavars_used == NULL) {
    return;
  }

  const char *varname;
  hashtab_T *ht = find_var_ht(name, len, &varname);

  if (ht == get_funccal_local_ht() || ht == get_funccal_args_ht()) {
    if (find_var(name, len, NULL, true) != NULL) {
      *eval_lavars_used = true;
    }
  }
}

/// check if special v:lua value for calling lua functions
static bool tv_is_luafunc(typval_T *tv)
{
  return tv->v_type == VAR_PARTIAL && tv->vval.v_partial == vvlua_partial;
}

/// check the function name after "v:lua."
static int check_luafunc_name(const char *str, bool paren)
{
  const char *p = str;
  while (ASCII_ISALNUM(*p) || *p == '_' || *p == '.') {
    p++;
  }
  if (*p != (paren ? '(' : NUL)) {
    return 0;
  } else {
    return (int)(p-str);
  }
}

/// Handle expr[expr], expr[expr:expr] subscript and .name lookup.
/// Also handle function call with Funcref variable: func(expr)
/// Can all be combined: dict.func(expr)[idx]['func'](expr)
int
handle_subscript(
    const char **const arg,
    typval_T *rettv,
    int evaluate,                   /* do more than finding the end */
    int verbose                    /* give error messages */
)
{
  int ret = OK;
  dict_T      *selfdict = NULL;
  const char_u *s;
  int len;
  typval_T functv;
  int slen = 0;
  bool lua = false;

  if (tv_is_luafunc(rettv)) {
    if (**arg != '.') {
      tv_clear(rettv);
      ret = FAIL;
    } else {
      (*arg)++;

      lua = true;
      s = (char_u *)(*arg);
      slen = check_luafunc_name(*arg, true);
      if (slen == 0) {
        tv_clear(rettv);
        ret = FAIL;
      }
      (*arg) += slen;
    }
  }


  while (ret == OK
         && (**arg == '['
             || (**arg == '.' && rettv->v_type == VAR_DICT)
             || (**arg == '(' && (!evaluate || tv_is_func(*rettv))))
         && !ascii_iswhite(*(*arg - 1))) {
    if (**arg == '(') {
      partial_T *pt = NULL;
      // need to copy the funcref so that we can clear rettv
      if (evaluate) {
        functv = *rettv;
        rettv->v_type = VAR_UNKNOWN;

        // Invoke the function.  Recursive!
        if (functv.v_type == VAR_PARTIAL) {
          pt = functv.vval.v_partial;
          if (!lua) {
            s = partial_name(pt);
          }
        } else {
          s = functv.vval.v_string;
        }
      } else {
        s = (char_u *)"";
      }
      ret = get_func_tv(s, lua ? slen : (int)STRLEN(s), rettv, (char_u **)arg,
                        curwin->w_cursor.lnum, curwin->w_cursor.lnum,
                        &len, evaluate, pt, selfdict);

      // Clear the funcref afterwards, so that deleting it while
      // evaluating the arguments is possible (see test55).
      if (evaluate) {
        tv_clear(&functv);
      }

      /* Stop the expression evaluation when immediately aborting on
       * error, or when an interrupt occurred or an exception was thrown
       * but not caught. */
      if (aborting()) {
        if (ret == OK) {
          tv_clear(rettv);
        }
        ret = FAIL;
      }
      tv_dict_unref(selfdict);
      selfdict = NULL;
    } else {  // **arg == '[' || **arg == '.'
      tv_dict_unref(selfdict);
      if (rettv->v_type == VAR_DICT) {
        selfdict = rettv->vval.v_dict;
        if (selfdict != NULL)
          ++selfdict->dv_refcount;
      } else
        selfdict = NULL;
      if (eval_index((char_u **)arg, rettv, evaluate, verbose) == FAIL) {
        tv_clear(rettv);
        ret = FAIL;
      }
    }
  }

  // Turn "dict.Func" into a partial for "Func" bound to "dict".
  if (selfdict != NULL && tv_is_func(*rettv)) {
    set_selfdict(rettv, selfdict);
  }

  tv_dict_unref(selfdict);
  return ret;
}

void set_selfdict(typval_T *rettv, dict_T *selfdict)
{
  // Don't do this when "dict.Func" is already a partial that was bound
  // explicitly (pt_auto is false).
  if (rettv->v_type == VAR_PARTIAL && !rettv->vval.v_partial->pt_auto
      && rettv->vval.v_partial->pt_dict != NULL) {
    return;
  }
  char_u *fname;
  char_u *tofree = NULL;
  ufunc_T *fp;
  char_u fname_buf[FLEN_FIXED + 1];
  int error;

  if (rettv->v_type == VAR_PARTIAL && rettv->vval.v_partial->pt_func != NULL) {
    fp = rettv->vval.v_partial->pt_func;
  } else {
    fname = rettv->v_type == VAR_FUNC || rettv->v_type == VAR_STRING
                                      ? rettv->vval.v_string
                                      : rettv->vval.v_partial->pt_name;
    // Translate "s:func" to the stored function name.
    fname = fname_trans_sid(fname, fname_buf, &tofree, &error);
    fp = find_func(fname);
    xfree(tofree);
  }

  // Turn "dict.Func" into a partial for "Func" with "dict".
  if (fp != NULL && (fp->uf_flags & FC_DICT)) {
    partial_T *pt = (partial_T *)xcalloc(1, sizeof(partial_T));
    pt->pt_refcount = 1;
    pt->pt_dict = selfdict;
    (selfdict->dv_refcount)++;
    pt->pt_auto = true;
    if (rettv->v_type == VAR_FUNC || rettv->v_type == VAR_STRING) {
      // Just a function: Take over the function name and use selfdict.
      pt->pt_name = rettv->vval.v_string;
    } else {
      partial_T *ret_pt = rettv->vval.v_partial;
      int i;

      // Partial: copy the function name, use selfdict and copy
      // args. Can't take over name or args, the partial might
      // be referenced elsewhere.
      if (ret_pt->pt_name != NULL) {
        pt->pt_name = vim_strsave(ret_pt->pt_name);
        func_ref(pt->pt_name);
      } else {
        pt->pt_func = ret_pt->pt_func;
        func_ptr_ref(pt->pt_func);
      }
      if (ret_pt->pt_argc > 0) {
        size_t arg_size = sizeof(typval_T) * ret_pt->pt_argc;
        pt->pt_argv = (typval_T *)xmalloc(arg_size);
        pt->pt_argc = ret_pt->pt_argc;
        for (i = 0; i < pt->pt_argc; i++) {
          tv_copy(&ret_pt->pt_argv[i], &pt->pt_argv[i]);
        }
      }
      partial_unref(ret_pt);
    }
    rettv->v_type = VAR_PARTIAL;
    rettv->vval.v_partial = pt;
  }
}

// Find variable "name" in the list of variables.
// Return a pointer to it if found, NULL if not found.
// Careful: "a:0" variables don't have a name.
// When "htp" is not NULL we are writing to the variable, set "htp" to the
// hashtab_T used.
dictitem_T *find_var(const char *const name, const size_t name_len,
                     hashtab_T **htp, int no_autoload)
{
  const char *varname;
  hashtab_T *const ht = find_var_ht(name, name_len, &varname);
  if (htp != NULL) {
    *htp = ht;
  }
  if (ht == NULL) {
    return NULL;
  }
  dictitem_T *const ret = find_var_in_ht(ht, *name,
                                         varname,
                                         name_len - (size_t)(varname - name),
                                         no_autoload || htp != NULL);
  if (ret != NULL) {
    return ret;
  }

  // Search in parent scope for lambda
  return find_var_in_scoped_ht(name, name_len, no_autoload || htp != NULL);
}

/// Find variable in hashtab
///
/// @param[in]  ht  Hashtab to find variable in.
/// @param[in]  htname  Hashtab name (first character).
/// @param[in]  varname  Variable name.
/// @param[in]  varname_len  Variable name length.
/// @param[in]  no_autoload  If true then autoload scripts will not be sourced
///                          if autoload variable was not found.
///
/// @return pointer to the dictionary item with the found variable or NULL if it
///         was not found.
dictitem_T *find_var_in_ht(hashtab_T *const ht,
                           int htname,
                           const char *const varname,
                           const size_t varname_len,
                           int no_autoload)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  hashitem_T  *hi;

  if (varname_len == 0) {
    // Must be something like "s:", otherwise "ht" would be NULL.
    switch (htname) {
      case 's': return (dictitem_T *)&SCRIPT_SV(current_sctx.sc_sid)->sv_var;
      case 'g': return (dictitem_T *)&globvars_var;
      case 'v': return (dictitem_T *)&vimvars_var;
      case 'b': return (dictitem_T *)&curbuf->b_bufvar;
      case 'w': return (dictitem_T *)&curwin->w_winvar;
      case 't': return (dictitem_T *)&curtab->tp_winvar;
      case 'l': return (current_funccal == NULL
                        ? NULL : (dictitem_T *)&current_funccal->l_vars_var);
      case 'a': return (current_funccal == NULL
                        ? NULL : (dictitem_T *)&get_funccal()->l_avars_var);
    }
    return NULL;
  }

  hi = hash_find_len(ht, varname, varname_len);
  if (HASHITEM_EMPTY(hi)) {
    // For global variables we may try auto-loading the script.  If it
    // worked find the variable again.  Don't auto-load a script if it was
    // loaded already, otherwise it would be loaded every time when
    // checking if a function name is a Funcref variable.
    if (ht == &globvarht && !no_autoload) {
      // Note: script_autoload() may make "hi" invalid. It must either
      // be obtained again or not used.
      if (!script_autoload(varname, varname_len, false) || aborting()) {
        return NULL;
      }
      hi = hash_find_len(ht, varname, varname_len);
    }
    if (HASHITEM_EMPTY(hi)) {
      return NULL;
    }
  }
  return TV_DICT_HI2DI(hi);
}

// Get function call environment based on backtrace debug level
static funccall_T *get_funccal(void)
{
  funccall_T *funccal = current_funccal;
  if (debug_backtrace_level > 0) {
    for (int i = 0; i < debug_backtrace_level; i++) {
      funccall_T *temp_funccal = funccal->caller;
      if (temp_funccal) {
        funccal = temp_funccal;
      } else {
        // backtrace level overflow. reset to max
        debug_backtrace_level = i;
      }
    }
  }

  return funccal;
}

/// Return the hashtable used for argument in the current funccal.
/// Return NULL if there is no current funccal.
static hashtab_T *get_funccal_args_ht(void)
{
  if (current_funccal == NULL) {
    return NULL;
  }
  return &get_funccal()->l_avars.dv_hashtab;
}

/// Return the hashtable used for local variables in the current funccal.
/// Return NULL if there is no current funccal.
static hashtab_T *get_funccal_local_ht(void)
{
  if (current_funccal == NULL) {
    return NULL;
  }
  return &get_funccal()->l_vars.dv_hashtab;
}

/// Finds the dict (g:, l:, s:, …) and hashtable used for a variable.
///
/// @param[in]  name  Variable name, possibly with scope prefix.
/// @param[in]  name_len  Variable name length.
/// @param[out]  varname  Will be set to the start of the name without scope
///                       prefix.
/// @param[out]  d  Scope dictionary.
///
/// @return Scope hashtab, NULL if name is not valid.
static hashtab_T *find_var_ht_dict(const char *name, const size_t name_len,
                                   const char **varname, dict_T **d)
{
  hashitem_T *hi;
  *d = NULL;

  if (name_len == 0) {
    return NULL;
  }
  if (name_len == 1 || name[1] != ':') {
    // name has implicit scope
    if (name[0] == ':' || name[0] == AUTOLOAD_CHAR) {
      // The name must not start with a colon or #.
      return NULL;
    }
    *varname = name;

    // "version" is "v:version" in all scopes
    hi = hash_find_len(&compat_hashtab, name, name_len);
    if (!HASHITEM_EMPTY(hi)) {
      return &compat_hashtab;
    }

    if (current_funccal == NULL) {
      *d = &globvardict;
    } else {
      *d = &get_funccal()->l_vars;  // l: variable
    }
    goto end;
  }

  *varname = name + 2;
  if (*name == 'g') {                           // global variable
    *d = &globvardict;
  } else if (name_len > 2
             && (memchr(name + 2, ':', name_len - 2) != NULL
                 || memchr(name + 2, AUTOLOAD_CHAR, name_len - 2) != NULL)) {
    // There must be no ':' or '#' in the rest of the name if g: was not used
    return NULL;
  }

  if (*name == 'b') {  // buffer variable
    *d = curbuf->b_vars;
  } else if (*name == 'w') {  // window variable
    *d = curwin->w_vars;
  } else if (*name == 't') {  // tab page variable
    *d = curtab->tp_vars;
  } else if (*name == 'v') {  // v: variable
    *d = &vimvardict;
  } else if (*name == 'a' && current_funccal != NULL) {  // function argument
    *d = &get_funccal()->l_avars;
  } else if (*name == 'l' && current_funccal != NULL) {  // local variable
    *d = &get_funccal()->l_vars;
  } else if (*name == 's'  // script variable
             && current_sctx.sc_sid > 0
             && current_sctx.sc_sid <= ga_scripts.ga_len) {
    *d = &SCRIPT_SV(current_sctx.sc_sid)->sv_dict;
  }

end:
  return *d ? &(*d)->dv_hashtab : NULL;
}

/// Find the hashtable used for a variable
///
/// @param[in]  name  Variable name, possibly with scope prefix.
/// @param[in]  name_len  Variable name length.
/// @param[out]  varname  Will be set to the start of the name without scope
///                       prefix.
///
/// @return Scope hashtab, NULL if name is not valid.
static hashtab_T *find_var_ht(const char *name, const size_t name_len,
                              const char **varname)
{
  dict_T *d;
  return find_var_ht_dict(name, name_len, varname, &d);
}

/*
 * Get the string value of a (global/local) variable.
 * Note: see tv_get_string() for how long the pointer remains valid.
 * Returns NULL when it doesn't exist.
 */
char_u *get_var_value(const char *const name)
{
  dictitem_T  *v;

  v = find_var(name, strlen(name), NULL, false);
  if (v == NULL) {
    return NULL;
  }
  return (char_u *)tv_get_string(&v->di_tv);
}

/*
 * Allocate a new hashtab for a sourced script.  It will be used while
 * sourcing this script and when executing functions defined in the script.
 */
void new_script_vars(scid_T id)
{
  hashtab_T   *ht;
  scriptvar_T *sv;

  ga_grow(&ga_scripts, (int)(id - ga_scripts.ga_len));
  {
    /* Re-allocating ga_data means that an ht_array pointing to
     * ht_smallarray becomes invalid.  We can recognize this: ht_mask is
     * at its init value.  Also reset "v_dict", it's always the same. */
    for (int i = 1; i <= ga_scripts.ga_len; ++i) {
      ht = &SCRIPT_VARS(i);
      if (ht->ht_mask == HT_INIT_SIZE - 1)
        ht->ht_array = ht->ht_smallarray;
      sv = SCRIPT_SV(i);
      sv->sv_var.di_tv.vval.v_dict = &sv->sv_dict;
    }

    while (ga_scripts.ga_len < id) {
      sv = SCRIPT_SV(ga_scripts.ga_len + 1) = xcalloc(1, sizeof(scriptvar_T));
      init_var_dict(&sv->sv_dict, &sv->sv_var, VAR_SCOPE);
      ++ga_scripts.ga_len;
    }
  }
}

/*
 * Initialize dictionary "dict" as a scope and set variable "dict_var" to
 * point to it.
 */
void init_var_dict(dict_T *dict, ScopeDictDictItem *dict_var, int scope)
{
  hash_init(&dict->dv_hashtab);
  dict->dv_lock = VAR_UNLOCKED;
  dict->dv_scope = scope;
  dict->dv_refcount = DO_NOT_FREE_CNT;
  dict->dv_copyID = 0;
  dict_var->di_tv.vval.v_dict = dict;
  dict_var->di_tv.v_type = VAR_DICT;
  dict_var->di_tv.v_lock = VAR_FIXED;
  dict_var->di_flags = DI_FLAGS_RO | DI_FLAGS_FIX;
  dict_var->di_key[0] = NUL;
  QUEUE_INIT(&dict->watchers);
}

/*
 * Unreference a dictionary initialized by init_var_dict().
 */
void unref_var_dict(dict_T *dict)
{
  /* Now the dict needs to be freed if no one else is using it, go back to
   * normal reference counting. */
  dict->dv_refcount -= DO_NOT_FREE_CNT - 1;
  tv_dict_unref(dict);
}

/*
 * Clean up a list of internal variables.
 * Frees all allocated variables and the value they contain.
 * Clears hashtab "ht", does not free it.
 */
void vars_clear(hashtab_T *ht)
{
  vars_clear_ext(ht, TRUE);
}

/*
 * Like vars_clear(), but only free the value if "free_val" is TRUE.
 */
static void vars_clear_ext(hashtab_T *ht, int free_val)
{
  int todo;
  hashitem_T  *hi;
  dictitem_T  *v;

  hash_lock(ht);
  todo = (int)ht->ht_used;
  for (hi = ht->ht_array; todo > 0; ++hi) {
    if (!HASHITEM_EMPTY(hi)) {
      --todo;

      // Free the variable.  Don't remove it from the hashtab,
      // ht_array might change then.  hash_clear() takes care of it
      // later.
      v = TV_DICT_HI2DI(hi);
      if (free_val) {
        tv_clear(&v->di_tv);
      }
      if (v->di_flags & DI_FLAGS_ALLOC) {
        xfree(v);
      }
    }
  }
  hash_clear(ht);
  ht->ht_used = 0;
}

/*
 * Delete a variable from hashtab "ht" at item "hi".
 * Clear the variable value and free the dictitem.
 */
static void delete_var(hashtab_T *ht, hashitem_T *hi)
{
  dictitem_T  *di = TV_DICT_HI2DI(hi);

  hash_remove(ht, hi);
  tv_clear(&di->di_tv);
  xfree(di);
}

/*
 * List the value of one internal variable.
 */
static void list_one_var(dictitem_T *v, const char *prefix, int *first)
{
  char *const s = encode_tv2echo(&v->di_tv, NULL);
  list_one_var_a(prefix, (const char *)v->di_key, STRLEN(v->di_key),
                 v->di_tv.v_type, (s == NULL ? "" : s), first);
  xfree(s);
}

/// @param[in]  name_len  Length of the name. May be -1, in this case strlen()
///                       will be used.
/// @param[in,out]  first  When true clear rest of screen and set to false.
static void list_one_var_a(const char *prefix, const char *name,
                           const ptrdiff_t name_len, const int type,
                           const char *string, int *first)
{
  // don't use msg() or msg_attr() to avoid overwriting "v:statusmsg"
  msg_start();
  msg_puts(prefix);
  if (name != NULL) {  // "a:" vars don't have a name stored
    msg_puts_attr_len(name, name_len, 0);
  }
  msg_putchar(' ');
  msg_advance(22);
  if (type == VAR_NUMBER) {
    msg_putchar('#');
  } else if (type == VAR_FUNC || type == VAR_PARTIAL) {
    msg_putchar('*');
  } else if (type == VAR_LIST) {
    msg_putchar('[');
    if (*string == '[')
      ++string;
  } else if (type == VAR_DICT) {
    msg_putchar('{');
    if (*string == '{')
      ++string;
  } else
    msg_putchar(' ');

  msg_outtrans((char_u *)string);

  if (type == VAR_FUNC || type == VAR_PARTIAL) {
    msg_puts("()");
  }
  if (*first) {
    msg_clr_eos();
    *first = FALSE;
  }
}

/// Set variable to the given value
///
/// If the variable already exists, the value is updated. Otherwise the variable
/// is created.
///
/// @param[in]  name  Variable name to set.
/// @param[in]  name_len  Length of the variable name.
/// @param  tv  Variable value.
/// @param[in]  copy  True if value in tv is to be copied.
void set_var(const char *name, const size_t name_len, typval_T *const tv,
             const bool copy)
  FUNC_ATTR_NONNULL_ALL
{
  set_var_const(name, name_len, tv, copy, false);
}

/// Set variable to the given value
///
/// If the variable already exists, the value is updated. Otherwise the variable
/// is created.
///
/// @param[in]  name  Variable name to set.
/// @param[in]  name_len  Length of the variable name.
/// @param  tv  Variable value.
/// @param[in]  copy  True if value in tv is to be copied.
/// @param[in]  is_const  True if value in tv is to be locked.
static void set_var_const(const char *name, const size_t name_len,
                          typval_T *const tv, const bool copy,
                          const bool is_const)
  FUNC_ATTR_NONNULL_ALL
{
  dictitem_T  *v;
  hashtab_T   *ht;
  dict_T *dict;

  const char *varname;
  ht = find_var_ht_dict(name, name_len, &varname, &dict);
  const bool watched = tv_dict_is_watched(dict);

  if (ht == NULL || *varname == NUL) {
    EMSG2(_(e_illvar), name);
    return;
  }
  v = find_var_in_ht(ht, 0, varname, name_len - (size_t)(varname - name), true);

  // Search in parent scope which is possible to reference from lambda
  if (v == NULL) {
    v = find_var_in_scoped_ht((const char *)name, name_len, true);
  }

  if (tv_is_func(*tv) && !var_check_func_name(name, v == NULL)) {
    return;
  }

  typval_T oldtv = TV_INITIAL_VALUE;
  if (v != NULL) {
    if (is_const) {
      EMSG(_(e_cannot_mod));
      return;
    }

    // existing variable, need to clear the value
    if (var_check_ro(v->di_flags, name, name_len)
        || tv_check_lock(v->di_tv.v_lock, name, name_len)) {
      return;
    }

    // Handle setting internal v: variables separately where needed to
    // prevent changing the type.
    if (ht == &vimvarht) {
      if (v->di_tv.v_type == VAR_STRING) {
        XFREE_CLEAR(v->di_tv.vval.v_string);
        if (copy || tv->v_type != VAR_STRING) {
          const char *const val = tv_get_string(tv);

          // Careful: when assigning to v:errmsg and tv_get_string()
          // causes an error message the variable will alrady be set.
          if (v->di_tv.vval.v_string == NULL) {
            v->di_tv.vval.v_string = (char_u *)xstrdup(val);
          }
        } else {
          // Take over the string to avoid an extra alloc/free.
          v->di_tv.vval.v_string = tv->vval.v_string;
          tv->vval.v_string = NULL;
        }
        return;
      } else if (v->di_tv.v_type == VAR_NUMBER) {
        v->di_tv.vval.v_number = tv_get_number(tv);
        if (strcmp(varname, "searchforward") == 0) {
          set_search_direction(v->di_tv.vval.v_number ? '/' : '?');
        } else if (strcmp(varname, "hlsearch") == 0) {
          no_hlsearch = !v->di_tv.vval.v_number;
          redraw_all_later(SOME_VALID);
        }
        return;
      } else if (v->di_tv.v_type != tv->v_type) {
        EMSG2(_("E963: setting %s to value with wrong type"), name);
        return;
      }
    }

    if (watched) {
      tv_copy(&v->di_tv, &oldtv);
    }
    tv_clear(&v->di_tv);
  } else {  // Add a new variable.
    // Can't add "v:" or "a:" variable.
    if (ht == &vimvarht || ht == get_funccal_args_ht()) {
      emsgf(_(e_illvar), name);
      return;
    }

    // Make sure the variable name is valid.
    if (!valid_varname(varname)) {
      return;
    }

    // Make sure dict is valid
    assert(dict != NULL);

    v = xmalloc(sizeof(dictitem_T) + strlen(varname));
    STRCPY(v->di_key, varname);
    if (tv_dict_add(dict, v) == FAIL) {
      xfree(v);
      return;
    }
    v->di_flags = DI_FLAGS_ALLOC;
    if (is_const) {
      v->di_flags |= DI_FLAGS_LOCK;
    }
  }

  if (copy || tv->v_type == VAR_NUMBER || tv->v_type == VAR_FLOAT) {
    tv_copy(tv, &v->di_tv);
  } else {
    v->di_tv = *tv;
    v->di_tv.v_lock = 0;
    tv_init(tv);
  }

  if (watched) {
    if (oldtv.v_type == VAR_UNKNOWN) {
      tv_dict_watcher_notify(dict, (char *)v->di_key, &v->di_tv, NULL);
    } else {
      tv_dict_watcher_notify(dict, (char *)v->di_key, &v->di_tv, &oldtv);
      tv_clear(&oldtv);
    }
  }

  if (is_const) {
    v->di_tv.v_lock |= VAR_LOCKED;
  }
}

/// Check whether variable is read-only (DI_FLAGS_RO, DI_FLAGS_RO_SBX)
///
/// Also gives an error message.
///
/// @param[in]  flags  di_flags attribute value.
/// @param[in]  name  Variable name, for use in error message.
/// @param[in]  name_len  Variable name length. Use #TV_TRANSLATE to translate
///                       variable name and compute the length. Use #TV_CSTRING
///                       to compute the length with strlen() without
///                       translating.
///
///                       Both #TV_… values are used for optimization purposes:
///                       variable name with its length is needed only in case
///                       of error, when no error occurs computing them is
///                       a waste of CPU resources. This especially applies to
///                       gettext.
///
/// @return True if variable is read-only: either always or in sandbox when
///         sandbox is enabled, false otherwise.
bool var_check_ro(const int flags, const char *name,
                  size_t name_len)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  const char *error_message = NULL;
  if (flags & DI_FLAGS_RO) {
    error_message = _(e_readonlyvar);
  } else if ((flags & DI_FLAGS_RO_SBX) && sandbox) {
    error_message = N_("E794: Cannot set variable in the sandbox: \"%.*s\"");
  }

  if (error_message == NULL) {
    return false;
  }
  if (name_len == TV_TRANSLATE) {
    name = _(name);
    name_len = strlen(name);
  } else if (name_len == TV_CSTRING) {
    name_len = strlen(name);
  }

  emsgf(_(error_message), (int)name_len, name);

  return true;
}

/// Check whether variable is fixed (DI_FLAGS_FIX)
///
/// Also gives an error message.
///
/// @param[in]  flags  di_flags attribute value.
/// @param[in]  name  Variable name, for use in error message.
/// @param[in]  name_len  Variable name length. Use #TV_TRANSLATE to translate
///                       variable name and compute the length. Use #TV_CSTRING
///                       to compute the length with strlen() without
///                       translating.
///
///                       Both #TV_… values are used for optimization purposes:
///                       variable name with its length is needed only in case
///                       of error, when no error occurs computing them is
///                       a waste of CPU resources. This especially applies to
///                       gettext.
///
/// @return True if variable is fixed, false otherwise.
bool var_check_fixed(const int flags, const char *name,
                     size_t name_len)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (flags & DI_FLAGS_FIX) {
    if (name_len == TV_TRANSLATE) {
      name = _(name);
      name_len = strlen(name);
    } else if (name_len == TV_CSTRING) {
      name_len = strlen(name);
    }
    EMSG3(_("E795: Cannot delete variable %.*s"), (int)name_len, name);
    return true;
  }
  return false;
}

// TODO(ZyX-I): move to eval/expressions

/// Check if name is a valid name to assign funcref to
///
/// @param[in]  name  Possible function/funcref name.
/// @param[in]  new_var  True if it is a name for a variable.
///
/// @return false in case of error, true in case of success. Also gives an
///         error message if appropriate.
bool var_check_func_name(const char *const name, const bool new_var)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  // Allow for w: b: s: and t:.
  if (!(vim_strchr((char_u *)"wbst", name[0]) != NULL && name[1] == ':')
      && !ASCII_ISUPPER((name[0] != NUL && name[1] == ':') ? name[2]
                                                           : name[0])) {
    EMSG2(_("E704: Funcref variable name must start with a capital: %s"), name);
    return false;
  }
  // Don't allow hiding a function.  When "v" is not NULL we might be
  // assigning another function to the same var, the type is checked
  // below.
  if (new_var && function_exists((const char *)name, false)) {
    EMSG2(_("E705: Variable name conflicts with existing function: %s"),
          name);
    return false;
  }
  return true;
}

// TODO(ZyX-I): move to eval/expressions

/// Check if a variable name is valid
///
/// @param[in]  varname  Variable name to check.
///
/// @return false when variable name is not valid, true when it is. Also gives
///         an error message if appropriate.
bool valid_varname(const char *varname)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  for (const char *p = varname; *p != NUL; p++) {
    if (!eval_isnamec1((int)(uint8_t)(*p))
        && (p == varname || !ascii_isdigit(*p))
        && *p != AUTOLOAD_CHAR) {
      emsgf(_(e_illvar), varname);
      return false;
    }
  }
  return true;
}

/// Make a copy of an item
///
/// Lists and Dictionaries are also copied.
///
/// @param[in]  conv  If not NULL, convert all copied strings.
/// @param[in]  from  Value to copy.
/// @param[out]  to  Location where to copy to.
/// @param[in]  deep  If true, use copy the container and all of the contained
///                   containers (nested).
/// @param[in]  copyID  If non-zero then when container is referenced more then
///                     once then copy of it that was already done is used. E.g.
///                     when copying list `list = [list2, list2]` (`list[0] is
///                     list[1]`) var_item_copy with zero copyID will emit
///                     a copy with (`copy[0] isnot copy[1]`), with non-zero it
///                     will emit a copy with (`copy[0] is copy[1]`) like in the
///                     original list. Not used when deep is false.
int var_item_copy(const vimconv_T *const conv,
                  typval_T *const from,
                  typval_T *const to,
                  const bool deep,
                  const int copyID)
  FUNC_ATTR_NONNULL_ARG(2, 3)
{
  static int recurse = 0;
  int ret = OK;

  if (recurse >= DICT_MAXNEST) {
    EMSG(_("E698: variable nested too deep for making a copy"));
    return FAIL;
  }
  ++recurse;

  switch (from->v_type) {
  case VAR_NUMBER:
  case VAR_FLOAT:
  case VAR_FUNC:
  case VAR_PARTIAL:
  case VAR_SPECIAL:
    tv_copy(from, to);
    break;
  case VAR_STRING:
    if (conv == NULL || conv->vc_type == CONV_NONE
        || from->vval.v_string == NULL) {
      tv_copy(from, to);
    } else {
      to->v_type = VAR_STRING;
      to->v_lock = 0;
      if ((to->vval.v_string = string_convert((vimconv_T *)conv,
                                              from->vval.v_string,
                                              NULL))
          == NULL) {
        to->vval.v_string = (char_u *) xstrdup((char *) from->vval.v_string);
      }
    }
    break;
  case VAR_LIST:
    to->v_type = VAR_LIST;
    to->v_lock = 0;
    if (from->vval.v_list == NULL) {
      to->vval.v_list = NULL;
    } else if (copyID != 0 && tv_list_copyid(from->vval.v_list) == copyID) {
      // Use the copy made earlier.
      to->vval.v_list = tv_list_latest_copy(from->vval.v_list);
      tv_list_ref(to->vval.v_list);
    } else {
      to->vval.v_list = tv_list_copy(conv, from->vval.v_list, deep, copyID);
    }
    if (to->vval.v_list == NULL && from->vval.v_list != NULL) {
      ret = FAIL;
    }
    break;
  case VAR_DICT:
    to->v_type = VAR_DICT;
    to->v_lock = 0;
    if (from->vval.v_dict == NULL)
      to->vval.v_dict = NULL;
    else if (copyID != 0 && from->vval.v_dict->dv_copyID == copyID) {
      /* use the copy made earlier */
      to->vval.v_dict = from->vval.v_dict->dv_copydict;
      ++to->vval.v_dict->dv_refcount;
    } else {
      to->vval.v_dict = tv_dict_copy(conv, from->vval.v_dict, deep, copyID);
    }
    if (to->vval.v_dict == NULL && from->vval.v_dict != NULL) {
      ret = FAIL;
    }
    break;
  case VAR_UNKNOWN:
    internal_error("var_item_copy(UNKNOWN)");
    ret = FAIL;
  }
  --recurse;
  return ret;
}

/*
 * ":echo expr1 ..."	print each argument separated with a space, add a
 *			newline at the end.
 * ":echon expr1 ..."	print each argument plain.
 */
void ex_echo(exarg_T *eap)
{
  char_u      *arg = eap->arg;
  typval_T rettv;
  bool atstart = true;
  bool need_clear = true;
  const int did_emsg_before = did_emsg;

  if (eap->skip)
    ++emsg_skip;
  while (*arg != NUL && *arg != '|' && *arg != '\n' && !got_int) {
    // If eval1() causes an error message the text from the command may
    // still need to be cleared. E.g., "echo 22,44".
    need_clr_eos = true;

    {
      char_u *p = arg;
      if (eval1(&arg, &rettv, !eap->skip) == FAIL) {
        // Report the invalid expression unless the expression evaluation
        // has been cancelled due to an aborting error, an interrupt, or an
        // exception.
        if (!aborting() && did_emsg == did_emsg_before) {
          EMSG2(_(e_invexpr2), p);
        }
        need_clr_eos = false;
        break;
      }
      need_clr_eos = false;
    }

    if (!eap->skip) {
      if (atstart) {
        atstart = false;
        /* Call msg_start() after eval1(), evaluating the expression
         * may cause a message to appear. */
        if (eap->cmdidx == CMD_echo) {
          /* Mark the saved text as finishing the line, so that what
           * follows is displayed on a new line when scrolling back
           * at the more prompt. */
          msg_sb_eol();
          msg_start();
        }
      } else if (eap->cmdidx == CMD_echo) {
        msg_puts_attr(" ", echo_attr);
      }
      char *tofree = encode_tv2echo(&rettv, NULL);
      if (*tofree != NUL) {
        msg_ext_set_kind("echo");
        msg_multiline_attr(tofree, echo_attr, true, &need_clear);
      }
      xfree(tofree);
    }
    tv_clear(&rettv);
    arg = skipwhite(arg);
  }
  eap->nextcmd = check_nextcmd(arg);

  if (eap->skip) {
    emsg_skip--;
  } else {
    // remove text that may still be there from the command
    if (need_clear) {
      msg_clr_eos();
    }
    if (eap->cmdidx == CMD_echo) {
      msg_end();
    }
  }
}

/*
 * ":echohl {name}".
 */
void ex_echohl(exarg_T *eap)
{
  int id;

  id = syn_name2id(eap->arg);
  if (id == 0)
    echo_attr = 0;
  else
    echo_attr = syn_id2attr(id);
}

/*
 * ":execute expr1 ..."	execute the result of an expression.
 * ":echomsg expr1 ..."	Print a message
 * ":echoerr expr1 ..."	Print an error
 * Each gets spaces around each argument and a newline at the end for
 * echo commands
 */
void ex_execute(exarg_T *eap)
{
  char_u *arg = eap->arg;
  typval_T rettv;
  int ret = OK;
  garray_T ga;
  int save_did_emsg;

  ga_init(&ga, 1, 80);

  if (eap->skip)
    ++emsg_skip;
  while (*arg != NUL && *arg != '|' && *arg != '\n') {
    ret = eval1_emsg(&arg, &rettv, !eap->skip);
    if (ret == FAIL) {
      break;
    }

    if (!eap->skip) {
      const char *const argstr = tv_get_string(&rettv);
      const size_t len = strlen(argstr);
      ga_grow(&ga, len + 2);
      if (!GA_EMPTY(&ga)) {
        ((char_u *)(ga.ga_data))[ga.ga_len++] = ' ';
      }
      memcpy((char_u *)(ga.ga_data) + ga.ga_len, argstr, len + 1);
      ga.ga_len += len;
    }

    tv_clear(&rettv);
    arg = skipwhite(arg);
  }

  if (ret != FAIL && ga.ga_data != NULL) {
    if (eap->cmdidx == CMD_echomsg || eap->cmdidx == CMD_echoerr) {
      // Mark the already saved text as finishing the line, so that what
      // follows is displayed on a new line when scrolling back at the
      // more prompt.
      msg_sb_eol();
    }

    if (eap->cmdidx == CMD_echomsg) {
      msg_ext_set_kind("echomsg");
      MSG_ATTR(ga.ga_data, echo_attr);
      ui_flush();
    } else if (eap->cmdidx == CMD_echoerr) {
      /* We don't want to abort following commands, restore did_emsg. */
      save_did_emsg = did_emsg;
      msg_ext_set_kind("echoerr");
      EMSG((char_u *)ga.ga_data);
      if (!force_abort)
        did_emsg = save_did_emsg;
    } else if (eap->cmdidx == CMD_execute)
      do_cmdline((char_u *)ga.ga_data,
          eap->getline, eap->cookie, DOCMD_NOWAIT|DOCMD_VERBOSE);
  }

  ga_clear(&ga);

  if (eap->skip)
    --emsg_skip;

  eap->nextcmd = check_nextcmd(arg);
}

/*
 * Skip over the name of an option: "&option", "&g:option" or "&l:option".
 * "arg" points to the "&" or '+' when called, to "option" when returning.
 * Returns NULL when no option name found.  Otherwise pointer to the char
 * after the option name.
 */
static const char *find_option_end(const char **const arg, int *const opt_flags)
{
  const char *p = *arg;

  ++p;
  if (*p == 'g' && p[1] == ':') {
    *opt_flags = OPT_GLOBAL;
    p += 2;
  } else if (*p == 'l' && p[1] == ':') {
    *opt_flags = OPT_LOCAL;
    p += 2;
  } else {
    *opt_flags = 0;
  }

  if (!ASCII_ISALPHA(*p)) {
    return NULL;
  }
  *arg = p;

  if (p[0] == 't' && p[1] == '_' && p[2] != NUL && p[3] != NUL) {
    p += 4;  // t_xx/termcap option
  } else {
    while (ASCII_ISALPHA(*p)) {
      p++;
    }
  }
  return p;
}

/*
 * ":function"
 */
void ex_function(exarg_T *eap)
{
  char_u      *theline;
  char_u      *line_to_free = NULL;
  int c;
  int saved_did_emsg;
  int saved_wait_return = need_wait_return;
  char_u      *name = NULL;
  char_u      *p;
  char_u      *arg;
  char_u      *line_arg = NULL;
  garray_T newargs;
  garray_T newlines;
  int varargs = false;
  int flags = 0;
  ufunc_T     *fp;
  bool overwrite = false;
  int indent;
  int nesting;
  dictitem_T  *v;
  funcdict_T fudi;
  static int func_nr = 0;           /* number for nameless function */
  int paren;
  hashtab_T   *ht;
  int todo;
  hashitem_T  *hi;
  linenr_T sourcing_lnum_off;
  linenr_T sourcing_lnum_top;
  bool is_heredoc = false;
  char_u *skip_until = NULL;
  char_u *heredoc_trimmed = NULL;
  bool show_block = false;
  bool do_concat = true;

  /*
   * ":function" without argument: list functions.
   */
  if (ends_excmd(*eap->arg)) {
    if (!eap->skip) {
      todo = (int)func_hashtab.ht_used;
      for (hi = func_hashtab.ht_array; todo > 0 && !got_int; ++hi) {
        if (!HASHITEM_EMPTY(hi)) {
          --todo;
          fp = HI2UF(hi);
          if (message_filtered(fp->uf_name)) {
            continue;
          }
          if (!func_name_refcount(fp->uf_name)) {
            list_func_head(fp, false, false);
          }
        }
      }
    }
    eap->nextcmd = check_nextcmd(eap->arg);
    return;
  }

  /*
   * ":function /pat": list functions matching pattern.
   */
  if (*eap->arg == '/') {
    p = skip_regexp(eap->arg + 1, '/', TRUE, NULL);
    if (!eap->skip) {
      regmatch_T regmatch;

      c = *p;
      *p = NUL;
      regmatch.regprog = vim_regcomp(eap->arg + 1, RE_MAGIC);
      *p = c;
      if (regmatch.regprog != NULL) {
        regmatch.rm_ic = p_ic;

        todo = (int)func_hashtab.ht_used;
        for (hi = func_hashtab.ht_array; todo > 0 && !got_int; ++hi) {
          if (!HASHITEM_EMPTY(hi)) {
            --todo;
            fp = HI2UF(hi);
            if (!isdigit(*fp->uf_name)
                && vim_regexec(&regmatch, fp->uf_name, 0))
              list_func_head(fp, false, false);
          }
        }
        vim_regfree(regmatch.regprog);
      }
    }
    if (*p == '/')
      ++p;
    eap->nextcmd = check_nextcmd(p);
    return;
  }

  // Get the function name.  There are these situations:
  // func        function name
  //             "name" == func, "fudi.fd_dict" == NULL
  // dict.func   new dictionary entry
  //             "name" == NULL, "fudi.fd_dict" set,
  //             "fudi.fd_di" == NULL, "fudi.fd_newkey" == func
  // dict.func   existing dict entry with a Funcref
  //             "name" == func, "fudi.fd_dict" set,
  //             "fudi.fd_di" set, "fudi.fd_newkey" == NULL
  // dict.func   existing dict entry that's not a Funcref
  //             "name" == NULL, "fudi.fd_dict" set,
  //             "fudi.fd_di" set, "fudi.fd_newkey" == NULL
  // s:func      script-local function name
  // g:func      global function name, same as "func"
  p = eap->arg;
  name = trans_function_name(&p, eap->skip, TFN_NO_AUTOLOAD, &fudi, NULL);
  paren = (vim_strchr(p, '(') != NULL);
  if (name == NULL && (fudi.fd_dict == NULL || !paren) && !eap->skip) {
    /*
     * Return on an invalid expression in braces, unless the expression
     * evaluation has been cancelled due to an aborting error, an
     * interrupt, or an exception.
     */
    if (!aborting()) {
      if (fudi.fd_newkey != NULL) {
        EMSG2(_(e_dictkey), fudi.fd_newkey);
      }
      xfree(fudi.fd_newkey);
      return;
    } else
      eap->skip = TRUE;
  }

  /* An error in a function call during evaluation of an expression in magic
   * braces should not cause the function not to be defined. */
  saved_did_emsg = did_emsg;
  did_emsg = FALSE;

  //
  // ":function func" with only function name: list function.
  // If bang is given:
  //  - include "!" in function head
  //  - exclude line numbers from function body
  //
  if (!paren) {
    if (!ends_excmd(*skipwhite(p))) {
      EMSG(_(e_trailing));
      goto ret_free;
    }
    eap->nextcmd = check_nextcmd(p);
    if (eap->nextcmd != NULL)
      *p = NUL;
    if (!eap->skip && !got_int) {
      fp = find_func(name);
      if (fp != NULL) {
        list_func_head(fp, !eap->forceit, eap->forceit);
        for (int j = 0; j < fp->uf_lines.ga_len && !got_int; j++) {
          if (FUNCLINE(fp, j) == NULL) {
            continue;
          }
          msg_putchar('\n');
          if (!eap->forceit) {
            msg_outnum((long)j + 1);
            if (j < 9) {
              msg_putchar(' ');
            }
            if (j < 99) {
              msg_putchar(' ');
            }
          }
          msg_prt_line(FUNCLINE(fp, j), false);
          ui_flush();                  // show a line at a time
          os_breakcheck();
        }
        if (!got_int) {
          msg_putchar('\n');
          msg_puts(eap->forceit ? "endfunction" : "   endfunction");
        }
      } else
        emsg_funcname(N_("E123: Undefined function: %s"), name);
    }
    goto ret_free;
  }

  /*
   * ":function name(arg1, arg2)" Define function.
   */
  p = skipwhite(p);
  if (*p != '(') {
    if (!eap->skip) {
      EMSG2(_("E124: Missing '(': %s"), eap->arg);
      goto ret_free;
    }
    /* attempt to continue by skipping some text */
    if (vim_strchr(p, '(') != NULL)
      p = vim_strchr(p, '(');
  }
  p = skipwhite(p + 1);

  ga_init(&newargs, (int)sizeof(char_u *), 3);
  ga_init(&newlines, (int)sizeof(char_u *), 3);

  if (!eap->skip) {
    /* Check the name of the function.  Unless it's a dictionary function
     * (that we are overwriting). */
    if (name != NULL)
      arg = name;
    else
      arg = fudi.fd_newkey;
    if (arg != NULL && (fudi.fd_di == NULL || !tv_is_func(fudi.fd_di->di_tv))) {
      int j = (*arg == K_SPECIAL) ? 3 : 0;
      while (arg[j] != NUL && (j == 0 ? eval_isnamec1(arg[j])
                               : eval_isnamec(arg[j])))
        ++j;
      if (arg[j] != NUL)
        emsg_funcname((char *)e_invarg2, arg);
    }
    /* Disallow using the g: dict. */
    if (fudi.fd_dict != NULL && fudi.fd_dict->dv_scope == VAR_DEF_SCOPE)
      EMSG(_("E862: Cannot use g: here"));
  }

  if (get_function_args(&p, ')', &newargs, &varargs, eap->skip) == FAIL) {
    goto errret_2;
  }

  if (KeyTyped && ui_has(kUICmdline)) {
    show_block = true;
    ui_ext_cmdline_block_append(0, (const char *)eap->cmd);
  }

  // find extra arguments "range", "dict", "abort" and "closure"
  for (;; ) {
    p = skipwhite(p);
    if (STRNCMP(p, "range", 5) == 0) {
      flags |= FC_RANGE;
      p += 5;
    } else if (STRNCMP(p, "dict", 4) == 0) {
      flags |= FC_DICT;
      p += 4;
    } else if (STRNCMP(p, "abort", 5) == 0) {
      flags |= FC_ABORT;
      p += 5;
    } else if (STRNCMP(p, "closure", 7) == 0) {
      flags |= FC_CLOSURE;
      p += 7;
      if (current_funccal == NULL) {
        emsg_funcname(N_
                      ("E932: Closure function should not be at top level: %s"),
                      name == NULL ? (char_u *)"" : name);
        goto erret;
      }
    } else {
      break;
    }
  }

  /* When there is a line break use what follows for the function body.
   * Makes 'exe "func Test()\n...\nendfunc"' work. */
  if (*p == '\n') {
    line_arg = p + 1;
  } else if (*p != NUL && *p != '"' && !eap->skip && !did_emsg) {
    EMSG(_(e_trailing));
  }

  /*
   * Read the body of the function, until ":endfunction" is found.
   */
  if (KeyTyped) {
    /* Check if the function already exists, don't let the user type the
     * whole function before telling him it doesn't work!  For a script we
     * need to skip the body to be able to find what follows. */
    if (!eap->skip && !eap->forceit) {
      if (fudi.fd_dict != NULL && fudi.fd_newkey == NULL)
        EMSG(_(e_funcdict));
      else if (name != NULL && find_func(name) != NULL)
        emsg_funcname(e_funcexts, name);
    }

    if (!eap->skip && did_emsg)
      goto erret;

    if (!ui_has(kUICmdline)) {
      msg_putchar('\n');              // don't overwrite the function name
    }
    cmdline_row = msg_row;
  }

  // Save the starting line number.
  sourcing_lnum_top = sourcing_lnum;

  indent = 2;
  nesting = 0;
  for (;; ) {
    if (KeyTyped) {
      msg_scroll = true;
      saved_wait_return = false;
    }
    need_wait_return = false;

    if (line_arg != NULL) {
      /* Use eap->arg, split up in parts by line breaks. */
      theline = line_arg;
      p = vim_strchr(theline, '\n');
      if (p == NULL)
        line_arg += STRLEN(line_arg);
      else {
        *p = NUL;
        line_arg = p + 1;
      }
    } else {
      xfree(line_to_free);
      if (eap->getline == NULL) {
        theline = getcmdline(':', 0L, indent, do_concat);
      } else {
        theline = eap->getline(':', eap->cookie, indent, do_concat);
      }
      line_to_free = theline;
    }
    if (KeyTyped) {
      lines_left = Rows - 1;
    }
    if (theline == NULL) {
      EMSG(_("E126: Missing :endfunction"));
      goto erret;
    }
    if (show_block) {
      assert(indent >= 0);
      ui_ext_cmdline_block_append((size_t)indent, (const char *)theline);
    }

    // Detect line continuation: sourcing_lnum increased more than one.
    sourcing_lnum_off = get_sourced_lnum(eap->getline, eap->cookie);
    if (sourcing_lnum < sourcing_lnum_off) {
        sourcing_lnum_off -= sourcing_lnum;
    } else {
      sourcing_lnum_off = 0;
    }

    if (skip_until != NULL) {
      // Don't check for ":endfunc" between
      // * ":append" and "."
      // * ":python <<EOF" and "EOF"
      // * ":let {var-name} =<< [trim] {marker}" and "{marker}"
      if (heredoc_trimmed == NULL
          || (is_heredoc && skipwhite(theline) == theline)
          || STRNCMP(theline, heredoc_trimmed,
                     STRLEN(heredoc_trimmed)) == 0) {
        if (heredoc_trimmed == NULL) {
          p = theline;
        } else if (is_heredoc) {
          p = skipwhite(theline) == theline
            ? theline : theline + STRLEN(heredoc_trimmed);
        } else {
          p = theline + STRLEN(heredoc_trimmed);
        }
        if (STRCMP(p, skip_until) == 0) {
          XFREE_CLEAR(skip_until);
          XFREE_CLEAR(heredoc_trimmed);
          do_concat = true;
          is_heredoc = false;
        }
      }
    } else {
      /* skip ':' and blanks*/
      for (p = theline; ascii_iswhite(*p) || *p == ':'; ++p)
        ;

      /* Check for "endfunction". */
      if (checkforcmd(&p, "endfunction", 4) && nesting-- == 0) {
        if (*p == '!') {
          p++;
        }
        char_u *nextcmd = NULL;
        if (*p == '|') {
          nextcmd = p + 1;
        } else if (line_arg != NULL && *skipwhite(line_arg) != NUL) {
          nextcmd = line_arg;
        } else if (*p != NUL && *p != '"' && p_verbose > 0) {
          give_warning2((char_u *)_("W22: Text found after :endfunction: %s"),
                        p, true);
        }
        if (nextcmd != NULL) {
          // Another command follows. If the line came from "eap" we
          // can simply point into it, otherwise we need to change
          // "eap->cmdlinep".
          eap->nextcmd = nextcmd;
          if (line_to_free != NULL) {
            xfree(*eap->cmdlinep);
            *eap->cmdlinep = line_to_free;
            line_to_free = NULL;
          }
        }
        break;
      }

      /* Increase indent inside "if", "while", "for" and "try", decrease
       * at "end". */
      if (indent > 2 && STRNCMP(p, "end", 3) == 0)
        indent -= 2;
      else if (STRNCMP(p, "if", 2) == 0
               || STRNCMP(p, "wh", 2) == 0
               || STRNCMP(p, "for", 3) == 0
               || STRNCMP(p, "try", 3) == 0)
        indent += 2;

      /* Check for defining a function inside this function. */
      if (checkforcmd(&p, "function", 2)) {
        if (*p == '!') {
          p = skipwhite(p + 1);
        }
        p += eval_fname_script((const char *)p);
        xfree(trans_function_name(&p, true, 0, NULL, NULL));
        if (*skipwhite(p) == '(') {
          nesting++;
          indent += 2;
        }
      }

      // Check for ":append", ":change", ":insert".
      p = skip_range(p, NULL);
      if ((p[0] == 'a' && (!ASCII_ISALPHA(p[1]) || p[1] == 'p'))
          || (p[0] == 'c'
              && (!ASCII_ISALPHA(p[1])
                  || (p[1] == 'h' && (!ASCII_ISALPHA(p[2])
                                      || (p[2] == 'a'
                                          && (STRNCMP(&p[3], "nge", 3) != 0
                                              || !ASCII_ISALPHA(p[6])))))))
          || (p[0] == 'i'
              && (!ASCII_ISALPHA(p[1]) || (p[1] == 'n'
                                           && (!ASCII_ISALPHA(p[2])
                                               || (p[2] == 's')))))) {
        skip_until = vim_strsave((char_u *)".");
      }

      // heredoc: Check for ":python <<EOF", ":lua <<EOF", etc.
      arg = skipwhite(skiptowhite(p));
      if (arg[0] == '<' && arg[1] =='<'
          && ((p[0] == 'p' && p[1] == 'y'
               && (!ASCII_ISALNUM(p[2]) || p[2] == 't'
                   || ((p[2] == '3' || p[2] == 'x')
                       && !ASCII_ISALPHA(p[3]))))
              || (p[0] == 'p' && p[1] == 'e'
                  && (!ASCII_ISALPHA(p[2]) || p[2] == 'r'))
              || (p[0] == 't' && p[1] == 'c'
                  && (!ASCII_ISALPHA(p[2]) || p[2] == 'l'))
              || (p[0] == 'l' && p[1] == 'u' && p[2] == 'a'
                  && !ASCII_ISALPHA(p[3]))
              || (p[0] == 'r' && p[1] == 'u' && p[2] == 'b'
                  && (!ASCII_ISALPHA(p[3]) || p[3] == 'y'))
              || (p[0] == 'm' && p[1] == 'z'
                  && (!ASCII_ISALPHA(p[2]) || p[2] == 's'))
              )) {
        /* ":python <<" continues until a dot, like ":append" */
        p = skipwhite(arg + 2);
        if (*p == NUL)
          skip_until = vim_strsave((char_u *)".");
        else
          skip_until = vim_strsave(p);
      }

      // Check for ":let v =<< [trim] EOF"
      //       and ":let [a, b] =<< [trim] EOF"
      arg = skipwhite(skiptowhite(p));
      if (*arg == '[') {
        arg = vim_strchr(arg, ']');
      }
      if (arg != NULL) {
        arg = skipwhite(skiptowhite(arg));
        if (arg[0] == '='
            && arg[1] == '<'
            && arg[2] =='<'
            && (p[0] == 'l'
                && p[1] == 'e'
                && (!ASCII_ISALNUM(p[2])
                    || (p[2] == 't' && !ASCII_ISALNUM(p[3]))))) {
          p = skipwhite(arg + 3);
          if (STRNCMP(p, "trim", 4) == 0) {
            // Ignore leading white space.
            p = skipwhite(p + 4);
            heredoc_trimmed =
              vim_strnsave(theline, (int)(skipwhite(theline) - theline));
          }
          skip_until = vim_strnsave(p, (int)(skiptowhite(p) - p));
          do_concat = false;
          is_heredoc = true;
        }
      }
    }

    /* Add the line to the function. */
    ga_grow(&newlines, 1 + sourcing_lnum_off);

    /* Copy the line to newly allocated memory.  get_one_sourceline()
     * allocates 250 bytes per line, this saves 80% on average.  The cost
     * is an extra alloc/free. */
    p = vim_strsave(theline);
    ((char_u **)(newlines.ga_data))[newlines.ga_len++] = p;

    /* Add NULL lines for continuation lines, so that the line count is
     * equal to the index in the growarray.   */
    while (sourcing_lnum_off-- > 0)
      ((char_u **)(newlines.ga_data))[newlines.ga_len++] = NULL;

    /* Check for end of eap->arg. */
    if (line_arg != NULL && *line_arg == NUL)
      line_arg = NULL;
  }

  /* Don't define the function when skipping commands or when an error was
   * detected. */
  if (eap->skip || did_emsg)
    goto erret;

  /*
   * If there are no errors, add the function
   */
  if (fudi.fd_dict == NULL) {
    v = find_var((const char *)name, STRLEN(name), &ht, false);
    if (v != NULL && v->di_tv.v_type == VAR_FUNC) {
      emsg_funcname(N_("E707: Function name conflicts with variable: %s"),
          name);
      goto erret;
    }

    fp = find_func(name);
    if (fp != NULL) {
      // Function can be replaced with "function!" and when sourcing the
      // same script again, but only once.
      if (!eap->forceit
          && (fp->uf_script_ctx.sc_sid != current_sctx.sc_sid
              || fp->uf_script_ctx.sc_seq == current_sctx.sc_seq)) {
        emsg_funcname(e_funcexts, name);
        goto erret;
      }
      if (fp->uf_calls > 0) {
        emsg_funcname(N_("E127: Cannot redefine function %s: It is in use"),
            name);
        goto erret;
      }
      if (fp->uf_refcount > 1) {
        // This function is referenced somewhere, don't redefine it but
        // create a new one.
        (fp->uf_refcount)--;
        fp->uf_flags |= FC_REMOVED;
        fp = NULL;
        overwrite = true;
      } else {
        // redefine existing function
        XFREE_CLEAR(name);
        func_clear_items(fp);
        fp->uf_profiling = false;
        fp->uf_prof_initialized = false;
      }
    }
  } else {
    char numbuf[20];

    fp = NULL;
    if (fudi.fd_newkey == NULL && !eap->forceit) {
      EMSG(_(e_funcdict));
      goto erret;
    }
    if (fudi.fd_di == NULL) {
      if (tv_check_lock(fudi.fd_dict->dv_lock, (const char *)eap->arg,
                        TV_CSTRING)) {
        // Can't add a function to a locked dictionary
        goto erret;
      }
    } else if (tv_check_lock(fudi.fd_di->di_tv.v_lock, (const char *)eap->arg,
                             TV_CSTRING)) {
      // Can't change an existing function if it is locked
      goto erret;
    }

    /* Give the function a sequential number.  Can only be used with a
     * Funcref! */
    xfree(name);
    sprintf(numbuf, "%d", ++func_nr);
    name = vim_strsave((char_u *)numbuf);
  }

  if (fp == NULL) {
    if (fudi.fd_dict == NULL && vim_strchr(name, AUTOLOAD_CHAR) != NULL) {
      int slen, plen;
      char_u  *scriptname;

      /* Check that the autoload name matches the script name. */
      int j = FAIL;
      if (sourcing_name != NULL) {
        scriptname = (char_u *)autoload_name((const char *)name, STRLEN(name));
        p = vim_strchr(scriptname, '/');
        plen = (int)STRLEN(p);
        slen = (int)STRLEN(sourcing_name);
        if (slen > plen && fnamecmp(p,
                sourcing_name + slen - plen) == 0)
          j = OK;
        xfree(scriptname);
      }
      if (j == FAIL) {
        EMSG2(_(
                "E746: Function name does not match script file name: %s"),
            name);
        goto erret;
      }
    }

    fp = xcalloc(1, offsetof(ufunc_T, uf_name) + STRLEN(name) + 1);

    if (fudi.fd_dict != NULL) {
      if (fudi.fd_di == NULL) {
        // Add new dict entry
        fudi.fd_di = tv_dict_item_alloc((const char *)fudi.fd_newkey);
        if (tv_dict_add(fudi.fd_dict, fudi.fd_di) == FAIL) {
          xfree(fudi.fd_di);
          xfree(fp);
          goto erret;
        }
      } else {
        // Overwrite existing dict entry.
        tv_clear(&fudi.fd_di->di_tv);
      }
      fudi.fd_di->di_tv.v_type = VAR_FUNC;
      fudi.fd_di->di_tv.vval.v_string = vim_strsave(name);

      /* behave like "dict" was used */
      flags |= FC_DICT;
    }

    /* insert the new function in the function list */
    STRCPY(fp->uf_name, name);
    if (overwrite) {
      hi = hash_find(&func_hashtab, name);
      hi->hi_key = UF2HIKEY(fp);
    } else if (hash_add(&func_hashtab, UF2HIKEY(fp)) == FAIL) {
      xfree(fp);
      goto erret;
    }
    fp->uf_refcount = 1;
  }
  fp->uf_args = newargs;
  fp->uf_lines = newlines;
  if ((flags & FC_CLOSURE) != 0) {
    register_closure(fp);
  } else {
    fp->uf_scoped = NULL;
  }
  if (prof_def_func()) {
    func_do_profile(fp);
  }
  fp->uf_varargs = varargs;
  if (sandbox) {
    flags |= FC_SANDBOX;
  }
  fp->uf_flags = flags;
  fp->uf_calls = 0;
  fp->uf_script_ctx = current_sctx;
  fp->uf_script_ctx.sc_lnum += sourcing_lnum_top;

  goto ret_free;

erret:
  ga_clear_strings(&newargs);
errret_2:
  ga_clear_strings(&newlines);
ret_free:
  xfree(skip_until);
  xfree(line_to_free);
  xfree(fudi.fd_newkey);
  xfree(name);
  did_emsg |= saved_did_emsg;
  need_wait_return |= saved_wait_return;
  if (show_block) {
    ui_ext_cmdline_block_leave();
  }
}  // NOLINT(readability/fn_size)

/// Get a function name, translating "<SID>" and "<SNR>".
/// Also handles a Funcref in a List or Dictionary.
/// flags:
/// TFN_INT:         internal function name OK
/// TFN_QUIET:       be quiet
/// TFN_NO_AUTOLOAD: do not use script autoloading
/// TFN_NO_DEREF:    do not dereference a Funcref
/// Advances "pp" to just after the function name (if no error).
///
/// @return the function name in allocated memory, or NULL for failure.
static char_u *
trans_function_name(
    char_u **pp,
    bool skip,                     // only find the end, don't evaluate
    int flags,
    funcdict_T *fdp,               // return: info about dictionary used
    partial_T **partial            // return: partial of a FuncRef
)
  FUNC_ATTR_NONNULL_ARG(1)
{
  char_u      *name = NULL;
  const char_u *start;
  const char_u *end;
  int lead;
  int len;
  lval_T lv;

  if (fdp != NULL)
    memset(fdp, 0, sizeof(funcdict_T));
  start = *pp;

  /* Check for hard coded <SNR>: already translated function ID (from a user
   * command). */
  if ((*pp)[0] == K_SPECIAL && (*pp)[1] == KS_EXTRA
      && (*pp)[2] == (int)KE_SNR) {
    *pp += 3;
    len = get_id_len((const char **)pp) + 3;
    return (char_u *)xmemdupz(start, len);
  }

  /* A name starting with "<SID>" or "<SNR>" is local to a script.  But
   * don't skip over "s:", get_lval() needs it for "s:dict.func". */
  lead = eval_fname_script((const char *)start);
  if (lead > 2) {
    start += lead;
  }

  // Note that TFN_ flags use the same values as GLV_ flags.
  end = get_lval((char_u *)start, NULL, &lv, false, skip, flags | GLV_READ_ONLY,
                 lead > 2 ? 0 : FNE_CHECK_START);
  if (end == start) {
    if (!skip)
      EMSG(_("E129: Function name required"));
    goto theend;
  }
  if (end == NULL || (lv.ll_tv != NULL && (lead > 2 || lv.ll_range))) {
    /*
     * Report an invalid expression in braces, unless the expression
     * evaluation has been cancelled due to an aborting error, an
     * interrupt, or an exception.
     */
    if (!aborting()) {
      if (end != NULL) {
        emsgf(_(e_invarg2), start);
      }
    } else {
      *pp = (char_u *)find_name_end(start, NULL, NULL, FNE_INCL_BR);
    }
    goto theend;
  }

  if (lv.ll_tv != NULL) {
    if (fdp != NULL) {
      fdp->fd_dict = lv.ll_dict;
      fdp->fd_newkey = lv.ll_newkey;
      lv.ll_newkey = NULL;
      fdp->fd_di = lv.ll_di;
    }
    if (lv.ll_tv->v_type == VAR_FUNC && lv.ll_tv->vval.v_string != NULL) {
      name = vim_strsave(lv.ll_tv->vval.v_string);
      *pp = (char_u *)end;
    } else if (lv.ll_tv->v_type == VAR_PARTIAL
               && lv.ll_tv->vval.v_partial != NULL) {
      if (lv.ll_tv->vval.v_partial == vvlua_partial && *end == '.') {
        len = check_luafunc_name((const char *)end+1, true);
        if (len == 0) {
          EMSG2(e_invexpr2, "v:lua");
          goto theend;
        }
        name = xmallocz(len);
        memcpy(name, end+1, len);
        *pp = (char_u *)end+1+len;
      } else {
        name = vim_strsave(partial_name(lv.ll_tv->vval.v_partial));
        *pp = (char_u *)end;
      }
      if (partial != NULL) {
        *partial = lv.ll_tv->vval.v_partial;
      }
    } else {
      if (!skip && !(flags & TFN_QUIET) && (fdp == NULL
                                            || lv.ll_dict == NULL
                                            || fdp->fd_newkey == NULL)) {
        EMSG(_(e_funcref));
      } else {
        *pp = (char_u *)end;
      }
      name = NULL;
    }
    goto theend;
  }

  if (lv.ll_name == NULL) {
    // Error found, but continue after the function name.
    *pp = (char_u *)end;
    goto theend;
  }

  /* Check if the name is a Funcref.  If so, use the value. */
  if (lv.ll_exp_name != NULL) {
    len = (int)strlen(lv.ll_exp_name);
    name = deref_func_name(lv.ll_exp_name, &len, partial,
                           flags & TFN_NO_AUTOLOAD);
    if ((const char *)name == lv.ll_exp_name) {
      name = NULL;
    }
  } else if (!(flags & TFN_NO_DEREF)) {
    len = (int)(end - *pp);
    name = deref_func_name((const char *)(*pp), &len, partial,
                           flags & TFN_NO_AUTOLOAD);
    if (name == *pp) {
      name = NULL;
    }
  }
  if (name != NULL) {
    name = vim_strsave(name);
    *pp = (char_u *)end;
    if (strncmp((char *)name, "<SNR>", 5) == 0) {
      // Change "<SNR>" to the byte sequence.
      name[0] = K_SPECIAL;
      name[1] = KS_EXTRA;
      name[2] = (int)KE_SNR;
      memmove(name + 3, name + 5, strlen((char *)name + 5) + 1);
    }
    goto theend;
  }

  if (lv.ll_exp_name != NULL) {
    len = (int)strlen(lv.ll_exp_name);
    if (lead <= 2 && lv.ll_name == lv.ll_exp_name
        && lv.ll_name_len >= 2 && memcmp(lv.ll_name, "s:", 2) == 0) {
      // When there was "s:" already or the name expanded to get a
      // leading "s:" then remove it.
      lv.ll_name += 2;
      lv.ll_name_len -= 2;
      len -= 2;
      lead = 2;
    }
  } else {
    // Skip over "s:" and "g:".
    if (lead == 2 || (lv.ll_name[0] == 'g' && lv.ll_name[1] == ':')) {
      lv.ll_name += 2;
      lv.ll_name_len -= 2;
    }
    len = (int)((const char *)end - lv.ll_name);
  }

  size_t sid_buf_len = 0;
  char sid_buf[20];

  // Copy the function name to allocated memory.
  // Accept <SID>name() inside a script, translate into <SNR>123_name().
  // Accept <SNR>123_name() outside a script.
  if (skip) {
    lead = 0;  // do nothing
  } else if (lead > 0) {
    lead = 3;
    if ((lv.ll_exp_name != NULL && eval_fname_sid(lv.ll_exp_name))
        || eval_fname_sid((const char *)(*pp))) {
      // It's "s:" or "<SID>".
      if (current_sctx.sc_sid <= 0) {
        EMSG(_(e_usingsid));
        goto theend;
      }
      sid_buf_len = snprintf(sid_buf, sizeof(sid_buf),
                             "%" PRIdSCID "_", current_sctx.sc_sid);
      lead += sid_buf_len;
    }
  } else if (!(flags & TFN_INT)
             && builtin_function(lv.ll_name, lv.ll_name_len)) {
    EMSG2(_("E128: Function name must start with a capital or \"s:\": %s"),
          start);
    goto theend;
  }

  if (!skip && !(flags & TFN_QUIET) && !(flags & TFN_NO_DEREF)) {
    char_u *cp = xmemrchr(lv.ll_name, ':', lv.ll_name_len);

    if (cp != NULL && cp < end) {
      EMSG2(_("E884: Function name cannot contain a colon: %s"), start);
      goto theend;
    }
  }

  name = xmalloc(len + lead + 1);
  if (!skip && lead > 0) {
    name[0] = K_SPECIAL;
    name[1] = KS_EXTRA;
    name[2] = (int)KE_SNR;
    if (sid_buf_len > 0) {  // If it's "<SID>"
      memcpy(name + 3, sid_buf, sid_buf_len);
    }
  }
  memmove(name + lead, lv.ll_name, len);
  name[lead + len] = NUL;
  *pp = (char_u *)end;

theend:
  clear_lval(&lv);
  return name;
}

/*
 * Return 5 if "p" starts with "<SID>" or "<SNR>" (ignoring case).
 * Return 2 if "p" starts with "s:".
 * Return 0 otherwise.
 */
static int eval_fname_script(const char *const p)
{
  // Use mb_strnicmp() because in Turkish comparing the "I" may not work with
  // the standard library function.
  if (p[0] == '<'
      && (mb_strnicmp((char_u *)p + 1, (char_u *)"SID>", 4) == 0
          || mb_strnicmp((char_u *)p + 1, (char_u *)"SNR>", 4) == 0)) {
    return 5;
  }
  if (p[0] == 's' && p[1] == ':') {
    return 2;
  }
  return 0;
}

/// Check whether function name starts with <SID> or s:
///
/// @warning Only works for names previously checked by eval_fname_script(), if
///          it returned non-zero.
///
/// @param[in]  name  Name to check.
///
/// @return true if it starts with <SID> or s:, false otherwise.
static inline bool eval_fname_sid(const char *const name)
  FUNC_ATTR_PURE FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_WARN_UNUSED_RESULT
  FUNC_ATTR_NONNULL_ALL
{
  return *name == 's' || TOUPPER_ASC(name[2]) == 'I';
}

/// List the head of the function: "name(arg1, arg2)".
///
/// @param[in]  fp      Function pointer.
/// @param[in]  indent  Indent line.
/// @param[in]  force   Include bang "!" (i.e.: "function!").
static void list_func_head(ufunc_T *fp, int indent, bool force)
{
  msg_start();
  if (indent)
    MSG_PUTS("   ");
  MSG_PUTS(force ? "function! " : "function ");
  if (fp->uf_name[0] == K_SPECIAL) {
    MSG_PUTS_ATTR("<SNR>", HL_ATTR(HLF_8));
    msg_puts((const char *)fp->uf_name + 3);
  } else {
    msg_puts((const char *)fp->uf_name);
  }
  msg_putchar('(');
  int j;
  for (j = 0; j < fp->uf_args.ga_len; j++) {
    if (j) {
      msg_puts(", ");
    }
    msg_puts((const char *)FUNCARG(fp, j));
  }
  if (fp->uf_varargs) {
    if (j) {
      msg_puts(", ");
    }
    msg_puts("...");
  }
  msg_putchar(')');
  if (fp->uf_flags & FC_ABORT) {
    msg_puts(" abort");
  }
  if (fp->uf_flags & FC_RANGE) {
    msg_puts(" range");
  }
  if (fp->uf_flags & FC_DICT) {
    msg_puts(" dict");
  }
  if (fp->uf_flags & FC_CLOSURE) {
    msg_puts(" closure");
  }
  msg_clr_eos();
  if (p_verbose > 0) {
    last_set_msg(fp->uf_script_ctx);
  }
}

/// Find a function by name, return pointer to it in ufuncs.
/// @return NULL for unknown function.
static ufunc_T *find_func(const char_u *name)
{
  hashitem_T  *hi;

  hi = hash_find(&func_hashtab, name);
  if (!HASHITEM_EMPTY(hi))
    return HI2UF(hi);
  return NULL;
}

#if defined(EXITFREE)
void free_all_functions(void)
{
  hashitem_T  *hi;
  ufunc_T     *fp;
  uint64_t skipped = 0;
  uint64_t todo = 1;
  uint64_t used;

  // Clean up the call stack.
  while (current_funccal != NULL) {
    tv_clear(current_funccal->rettv);
    cleanup_function_call(current_funccal);
  }

  // First clear what the functions contain. Since this may lower the
  // reference count of a function, it may also free a function and change
  // the hash table. Restart if that happens.
  while (todo > 0) {
    todo = func_hashtab.ht_used;
    for (hi = func_hashtab.ht_array; todo > 0; hi++) {
      if (!HASHITEM_EMPTY(hi)) {
        // Only free functions that are not refcounted, those are
        // supposed to be freed when no longer referenced.
        fp = HI2UF(hi);
        if (func_name_refcount(fp->uf_name)) {
          skipped++;
        } else {
          used = func_hashtab.ht_used;
          func_clear(fp, true);
          if (used != func_hashtab.ht_used) {
            skipped = 0;
            break;
          }
        }
        todo--;
      }
    }
  }

  // Now actually free the functions. Need to start all over every time,
  // because func_free() may change the hash table.
  skipped = 0;
  while (func_hashtab.ht_used > skipped) {
    todo = func_hashtab.ht_used;
    for (hi = func_hashtab.ht_array; todo > 0; hi++) {
      if (!HASHITEM_EMPTY(hi)) {
        todo--;
        // Only free functions that are not refcounted, those are
        // supposed to be freed when no longer referenced.
        fp = HI2UF(hi);
        if (func_name_refcount(fp->uf_name)) {
          skipped++;
        } else {
          func_free(fp);
          skipped = 0;
          break;
        }
      }
    }
  }
  if (skipped == 0) {
    hash_clear(&func_hashtab);
  }
}

#endif

bool translated_function_exists(const char *name)
{
  if (builtin_function(name, -1)) {
    return find_internal_func((char *)name) != NULL;
  }
  return find_func((const char_u *)name) != NULL;
}

/// Check whether function with the given name exists
///
/// @param[in]  name  Function name.
/// @param[in]  no_deref  Whether to dereference a Funcref.
///
/// @return True if it exists, false otherwise.
bool function_exists(const char *const name, bool no_deref)
{
  const char_u *nm = (const char_u *)name;
  bool n = false;
  int flag = TFN_INT | TFN_QUIET | TFN_NO_AUTOLOAD;

  if (no_deref) {
    flag |= TFN_NO_DEREF;
  }
  char *const p = (char *)trans_function_name((char_u **)&nm, false, flag, NULL,
                                              NULL);
  nm = skipwhite(nm);

  /* Only accept "funcname", "funcname ", "funcname (..." and
   * "funcname(...", not "funcname!...". */
  if (p != NULL && (*nm == NUL || *nm == '(')) {
    n = translated_function_exists(p);
  }
  xfree(p);
  return n;
}

/// Checks if a builtin function with the given name exists.
///
/// @param[in]   name   name of the builtin function to check.
/// @param[in]   len    length of "name", or -1 for NUL terminated.
///
/// @return true if "name" looks like a builtin function name: starts with a
/// lower case letter and doesn't contain AUTOLOAD_CHAR.
static bool builtin_function(const char *name, int len)
{
  if (!ASCII_ISLOWER(name[0])) {
    return false;
  }

  const char *p = (len == -1
                   ? strchr(name, AUTOLOAD_CHAR)
                   : memchr(name, AUTOLOAD_CHAR, (size_t)len));

  return p == NULL;
}

/*
 * Start profiling function "fp".
 */
static void func_do_profile(ufunc_T *fp)
{
  int len = fp->uf_lines.ga_len;

  if (!fp->uf_prof_initialized) {
    if (len == 0) {
      len = 1;  // avoid getting error for allocating zero bytes
    }
    fp->uf_tm_count = 0;
    fp->uf_tm_self = profile_zero();
    fp->uf_tm_total = profile_zero();

    if (fp->uf_tml_count == NULL) {
      fp->uf_tml_count = xcalloc(len, sizeof(int));
    }

    if (fp->uf_tml_total == NULL) {
      fp->uf_tml_total = xcalloc(len, sizeof(proftime_T));
    }

    if (fp->uf_tml_self == NULL) {
      fp->uf_tml_self = xcalloc(len, sizeof(proftime_T));
    }

    fp->uf_tml_idx = -1;
    fp->uf_prof_initialized = true;
  }

  fp->uf_profiling = TRUE;
}

/*
 * Dump the profiling results for all functions in file "fd".
 */
void func_dump_profile(FILE *fd)
{
  hashitem_T  *hi;
  int todo;
  ufunc_T     *fp;
  ufunc_T     **sorttab;
  int st_len = 0;

  todo = (int)func_hashtab.ht_used;
  if (todo == 0)
    return;         /* nothing to dump */

  sorttab = xmalloc(sizeof(ufunc_T *) * todo);

  for (hi = func_hashtab.ht_array; todo > 0; ++hi) {
    if (!HASHITEM_EMPTY(hi)) {
      --todo;
      fp = HI2UF(hi);
      if (fp->uf_prof_initialized) {
        sorttab[st_len++] = fp;

        if (fp->uf_name[0] == K_SPECIAL) {
          fprintf(fd, "FUNCTION  <SNR>%s()\n", fp->uf_name + 3);
        } else {
          fprintf(fd, "FUNCTION  %s()\n", fp->uf_name);
        }
        if (fp->uf_script_ctx.sc_sid != 0) {
          bool should_free;
          const LastSet last_set = (LastSet){
            .script_ctx = fp->uf_script_ctx,
              .channel_id = 0,
          };
          char_u *p = get_scriptname(last_set, &should_free);
          fprintf(fd, "    Defined: %s:%" PRIdLINENR "\n",
                  p, fp->uf_script_ctx.sc_lnum);
          if (should_free) {
            xfree(p);
          }
        }
        if (fp->uf_tm_count == 1) {
          fprintf(fd, "Called 1 time\n");
        } else {
          fprintf(fd, "Called %d times\n", fp->uf_tm_count);
        }
        fprintf(fd, "Total time: %s\n", profile_msg(fp->uf_tm_total));
        fprintf(fd, " Self time: %s\n", profile_msg(fp->uf_tm_self));
        fprintf(fd, "\n");
        fprintf(fd, "count  total (s)   self (s)\n");

        for (int i = 0; i < fp->uf_lines.ga_len; ++i) {
          if (FUNCLINE(fp, i) == NULL)
            continue;
          prof_func_line(fd, fp->uf_tml_count[i],
              &fp->uf_tml_total[i], &fp->uf_tml_self[i], TRUE);
          fprintf(fd, "%s\n", FUNCLINE(fp, i));
        }
        fprintf(fd, "\n");
      }
    }
  }

  if (st_len > 0) {
    qsort((void *)sorttab, (size_t)st_len, sizeof(ufunc_T *),
        prof_total_cmp);
    prof_sort_list(fd, sorttab, st_len, "TOTAL", FALSE);
    qsort((void *)sorttab, (size_t)st_len, sizeof(ufunc_T *),
        prof_self_cmp);
    prof_sort_list(fd, sorttab, st_len, "SELF", TRUE);
  }

  xfree(sorttab);
}

static void
prof_sort_list(
    FILE *fd,
    ufunc_T **sorttab,
    int st_len,
    char *title,
    int prefer_self                /* when equal print only self time */
)
{
  int i;
  ufunc_T     *fp;

  fprintf(fd, "FUNCTIONS SORTED ON %s TIME\n", title);
  fprintf(fd, "count  total (s)   self (s)  function\n");
  for (i = 0; i < 20 && i < st_len; ++i) {
    fp = sorttab[i];
    prof_func_line(fd, fp->uf_tm_count, &fp->uf_tm_total, &fp->uf_tm_self,
        prefer_self);
    if (fp->uf_name[0] == K_SPECIAL)
      fprintf(fd, " <SNR>%s()\n", fp->uf_name + 3);
    else
      fprintf(fd, " %s()\n", fp->uf_name);
  }
  fprintf(fd, "\n");
}

/*
 * Print the count and times for one function or function line.
 */
static void prof_func_line(
    FILE        *fd,
    int count,
    proftime_T  *total,
    proftime_T  *self,
    int prefer_self                 /* when equal print only self time */
    )
{
  if (count > 0) {
    fprintf(fd, "%5d ", count);
    if (prefer_self && profile_equal(*total, *self))
      fprintf(fd, "           ");
    else
      fprintf(fd, "%s ", profile_msg(*total));
    if (!prefer_self && profile_equal(*total, *self))
      fprintf(fd, "           ");
    else
      fprintf(fd, "%s ", profile_msg(*self));
  } else
    fprintf(fd, "                            ");
}

/*
 * Compare function for total time sorting.
 */
static int prof_total_cmp(const void *s1, const void *s2)
{
  ufunc_T *p1 = *(ufunc_T **)s1;
  ufunc_T *p2 = *(ufunc_T **)s2;
  return profile_cmp(p1->uf_tm_total, p2->uf_tm_total);
}

/*
 * Compare function for self time sorting.
 */
static int prof_self_cmp(const void *s1, const void *s2)
{
  ufunc_T *p1 = *(ufunc_T **)s1;
  ufunc_T *p2 = *(ufunc_T **)s2;
  return profile_cmp(p1->uf_tm_self, p2->uf_tm_self);
}


/// If name has a package name try autoloading the script for it
///
/// @param[in]  name  Variable/function name.
/// @param[in]  name_len  Name length.
/// @param[in]  reload  If true, load script again when already loaded.
///
/// @return true if a package was loaded.
static bool script_autoload(const char *const name, const size_t name_len,
                            const bool reload)
{
  // If there is no '#' after name[0] there is no package name.
  const char *p = memchr(name, AUTOLOAD_CHAR, name_len);
  if (p == NULL || p == name) {
    return false;
  }

  bool ret = false;
  char *tofree = autoload_name(name, name_len);
  char *scriptname = tofree;

  // Find the name in the list of previously loaded package names.  Skip
  // "autoload/", it's always the same.
  int i = 0;
  for (; i < ga_loaded.ga_len; i++) {
    if (STRCMP(((char **)ga_loaded.ga_data)[i] + 9, scriptname + 9) == 0) {
      break;
    }
  }
  if (!reload && i < ga_loaded.ga_len) {
    ret = false;  // Was loaded already.
  } else {
    // Remember the name if it wasn't loaded already.
    if (i == ga_loaded.ga_len) {
      GA_APPEND(char *, &ga_loaded, scriptname);
      tofree = NULL;
    }

    // Try loading the package from $VIMRUNTIME/autoload/<name>.vim
    if (source_runtime((char_u *)scriptname, 0) == OK) {
      ret = true;
    }
  }

  xfree(tofree);
  return ret;
}

/// Return the autoload script name for a function or variable name
/// Caller must make sure that "name" contains AUTOLOAD_CHAR.
///
/// @param[in]  name  Variable/function name.
/// @param[in]  name_len  Name length.
///
/// @return [allocated] autoload script name.
static char *autoload_name(const char *const name, const size_t name_len)
  FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT
{
  // Get the script file name: replace '#' with '/', append ".vim".
  char *const scriptname = xmalloc(name_len + sizeof("autoload/.vim"));
  memcpy(scriptname, "autoload/", sizeof("autoload/") - 1);
  memcpy(scriptname + sizeof("autoload/") - 1, name, name_len);
  size_t auchar_idx = 0;
  for (size_t i = sizeof("autoload/") - 1;
       i - sizeof("autoload/") + 1 < name_len;
       i++) {
    if (scriptname[i] == AUTOLOAD_CHAR) {
      scriptname[i] = '/';
      auchar_idx = i;
    }
  }
  memcpy(scriptname + auchar_idx, ".vim", sizeof(".vim"));

  return scriptname;
}


/*
 * Function given to ExpandGeneric() to obtain the list of user defined
 * function names.
 */
char_u *get_user_func_name(expand_T *xp, int idx)
{
  static size_t done;
  static hashitem_T   *hi;
  ufunc_T             *fp;

  if (idx == 0) {
    done = 0;
    hi = func_hashtab.ht_array;
  }
  assert(hi);
  if (done < func_hashtab.ht_used) {
    if (done++ > 0)
      ++hi;
    while (HASHITEM_EMPTY(hi))
      ++hi;
    fp = HI2UF(hi);

    if ((fp->uf_flags & FC_DICT)
        || STRNCMP(fp->uf_name, "<lambda>", 8) == 0) {
      return (char_u *)"";       // don't show dict and lambda functions
    }

    if (STRLEN(fp->uf_name) + 4 >= IOSIZE) {
      return fp->uf_name;  // Prevent overflow.
    }

    cat_func_name(IObuff, fp);
    if (xp->xp_context != EXPAND_USER_FUNC) {
      STRCAT(IObuff, "(");
      if (!fp->uf_varargs && GA_EMPTY(&fp->uf_args))
        STRCAT(IObuff, ")");
    }
    return IObuff;
  }
  return NULL;
}


/*
 * Copy the function name of "fp" to buffer "buf".
 * "buf" must be able to hold the function name plus three bytes.
 * Takes care of script-local function names.
 */
static void cat_func_name(char_u *buf, ufunc_T *fp)
{
  if (fp->uf_name[0] == K_SPECIAL) {
    STRCPY(buf, "<SNR>");
    STRCAT(buf, fp->uf_name + 3);
  } else
    STRCPY(buf, fp->uf_name);
}

/// There are two kinds of function names:
/// 1. ordinary names, function defined with :function
/// 2. numbered functions and lambdas
/// For the first we only count the name stored in func_hashtab as a reference,
/// using function() does not count as a reference, because the function is
/// looked up by name.
static bool func_name_refcount(char_u *name)
{
  return isdigit(*name) || *name == '<';
}

/// ":delfunction {name}"
void ex_delfunction(exarg_T *eap)
{
  ufunc_T     *fp = NULL;
  char_u      *p;
  char_u      *name;
  funcdict_T fudi;

  p = eap->arg;
  name = trans_function_name(&p, eap->skip, 0, &fudi, NULL);
  xfree(fudi.fd_newkey);
  if (name == NULL) {
    if (fudi.fd_dict != NULL && !eap->skip)
      EMSG(_(e_funcref));
    return;
  }
  if (!ends_excmd(*skipwhite(p))) {
    xfree(name);
    EMSG(_(e_trailing));
    return;
  }
  eap->nextcmd = check_nextcmd(p);
  if (eap->nextcmd != NULL)
    *p = NUL;

  if (!eap->skip)
    fp = find_func(name);
  xfree(name);

  if (!eap->skip) {
    if (fp == NULL) {
      if (!eap->forceit) {
        EMSG2(_(e_nofunc), eap->arg);
      }
      return;
    }
    if (fp->uf_calls > 0) {
      EMSG2(_("E131: Cannot delete function %s: It is in use"), eap->arg);
      return;
    }
    // check `uf_refcount > 2` because deleting a function should also reduce
    // the reference count, and 1 is the initial refcount.
    if (fp->uf_refcount > 2) {
      EMSG2(_("Cannot delete function %s: It is being used internally"),
          eap->arg);
      return;
    }

    if (fudi.fd_dict != NULL) {
      // Delete the dict item that refers to the function, it will
      // invoke func_unref() and possibly delete the function.
      tv_dict_item_remove(fudi.fd_dict, fudi.fd_di);
    } else {
      // A normal function (not a numbered function or lambda) has a
      // refcount of 1 for the entry in the hashtable.  When deleting
      // it and the refcount is more than one, it should be kept.
      // A numbered function or lambda should be kept if the refcount is
      // one or more.
      if (fp->uf_refcount > (func_name_refcount(fp->uf_name) ? 0 : 1)) {
        // Function is still referenced somewhere. Don't free it but
        // do remove it from the hashtable.
        if (func_remove(fp)) {
          fp->uf_refcount--;
        }
        fp->uf_flags |= FC_DELETED;
      } else {
        func_clear_free(fp, false);
      }
    }
  }
}

/// Remove the function from the function hashtable.  If the function was
/// deleted while it still has references this was already done.
///
/// @return true if the entry was deleted, false if it wasn't found.
static bool func_remove(ufunc_T *fp)
{
  hashitem_T *hi = hash_find(&func_hashtab, UF2HIKEY(fp));

  if (!HASHITEM_EMPTY(hi)) {
    hash_remove(&func_hashtab, hi);
    return true;
  }

  return false;
}

static void func_clear_items(ufunc_T *fp)
{
  ga_clear_strings(&(fp->uf_args));
  ga_clear_strings(&(fp->uf_lines));

  XFREE_CLEAR(fp->uf_tml_count);
  XFREE_CLEAR(fp->uf_tml_total);
  XFREE_CLEAR(fp->uf_tml_self);
}

/// Free all things that a function contains. Does not free the function
/// itself, use func_free() for that.
///
/// param[in]        force        When true, we are exiting.
static void func_clear(ufunc_T *fp, bool force)
{
  if (fp->uf_cleared) {
    return;
  }
  fp->uf_cleared = true;

  // clear this function
  func_clear_items(fp);
  funccal_unref(fp->uf_scoped, fp, force);
}

/// Free a function and remove it from the list of functions. Does not free
/// what a function contains, call func_clear() first.
///
/// param[in]        fp        The function to free.
static void func_free(ufunc_T *fp)
{
  // only remove it when not done already, otherwise we would remove a newer
  // version of the function
  if ((fp->uf_flags & (FC_DELETED | FC_REMOVED)) == 0) {
    func_remove(fp);
  }
  xfree(fp);
}

/// Free all things that a function contains and free the function itself.
///
/// param[in]        force        When true, we are exiting.
static void func_clear_free(ufunc_T *fp, bool force)
{
  func_clear(fp, force);
  func_free(fp);
}

/*
 * Unreference a Function: decrement the reference count and free it when it
 * becomes zero.
 */
void func_unref(char_u *name)
{
  ufunc_T *fp = NULL;

  if (name == NULL || !func_name_refcount(name)) {
    return;
  }

  fp = find_func(name);
  if (fp == NULL && isdigit(*name)) {
#ifdef EXITFREE
    if (!entered_free_all_mem) {
      internal_error("func_unref()");
      abort();
    }
#else
      internal_error("func_unref()");
      abort();
#endif
  }
  func_ptr_unref(fp);
}

/// Unreference a Function: decrement the reference count and free it when it
/// becomes zero.
/// Unreference user function, freeing it if needed
///
/// Decrements the reference count and frees when it becomes zero.
///
/// @param  fp  Function to unreference.
void func_ptr_unref(ufunc_T *fp)
{
  if (fp != NULL && --fp->uf_refcount <= 0) {
    // Only delete it when it's not being used. Otherwise it's done
    // when "uf_calls" becomes zero.
    if (fp->uf_calls == 0) {
      func_clear_free(fp, false);
    }
  }
}

/// Count a reference to a Function.
void func_ref(char_u *name)
{
  ufunc_T *fp;

  if (name == NULL || !func_name_refcount(name)) {
    return;
  }
  fp = find_func(name);
  if (fp != NULL) {
    (fp->uf_refcount)++;
  } else if (isdigit(*name)) {
    // Only give an error for a numbered function.
    // Fail silently, when named or lambda function isn't found.
    internal_error("func_ref()");
  }
}

/// Count a reference to a Function.
void func_ptr_ref(ufunc_T *fp)
{
  if (fp != NULL) {
    (fp->uf_refcount)++;
  }
}

/// Check whether funccall is still referenced outside
///
/// It is supposed to be referenced if either it is referenced itself or if l:,
/// a: or a:000 are referenced as all these are statically allocated within
/// funccall structure.
static inline bool fc_referenced(const funccall_T *const fc)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
  FUNC_ATTR_NONNULL_ALL
{
  return ((fc->l_varlist.lv_refcount  // NOLINT(runtime/deprecated)
           != DO_NOT_FREE_CNT)
          || fc->l_vars.dv_refcount != DO_NOT_FREE_CNT
          || fc->l_avars.dv_refcount != DO_NOT_FREE_CNT
          || fc->fc_refcount > 0);
}

/// Call a user function
///
/// @param  fp  Function to call.
/// @param[in]  argcount  Number of arguments.
/// @param  argvars  Arguments.
/// @param[out]  rettv  Return value.
/// @param[in]  firstline  First line of range.
/// @param[in]  lastline  Last line of range.
/// @param  selfdict  Dictionary for "self" for dictionary functions.
void call_user_func(ufunc_T *fp, int argcount, typval_T *argvars,
                    typval_T *rettv, linenr_T firstline, linenr_T lastline,
                    dict_T *selfdict)
  FUNC_ATTR_NONNULL_ARG(1, 3, 4)
{
  char_u      *save_sourcing_name;
  linenr_T save_sourcing_lnum;
  bool using_sandbox = false;
  funccall_T  *fc;
  int save_did_emsg;
  static int depth = 0;
  dictitem_T  *v;
  int fixvar_idx = 0;           /* index in fixvar[] */
  int ai;
  bool islambda = false;
  char_u numbuf[NUMBUFLEN];
  char_u      *name;
  proftime_T wait_start;
  proftime_T call_start;
  int started_profiling = false;
  bool did_save_redo = false;
  save_redo_T save_redo;

  /* If depth of calling is getting too high, don't execute the function */
  if (depth >= p_mfd) {
    EMSG(_("E132: Function call depth is higher than 'maxfuncdepth'"));
    rettv->v_type = VAR_NUMBER;
    rettv->vval.v_number = -1;
    return;
  }
  ++depth;
  // Save search patterns and redo buffer.
  save_search_patterns();
  if (!ins_compl_active()) {
    saveRedobuff(&save_redo);
    did_save_redo = true;
  }
  ++fp->uf_calls;
  // check for CTRL-C hit
  line_breakcheck();
  // prepare the funccall_T structure
  fc = xmalloc(sizeof(funccall_T));
  fc->caller = current_funccal;
  current_funccal = fc;
  fc->func = fp;
  fc->rettv = rettv;
  rettv->vval.v_number = 0;
  fc->linenr = 0;
  fc->returned = FALSE;
  fc->level = ex_nesting_level;
  /* Check if this function has a breakpoint. */
  fc->breakpoint = dbg_find_breakpoint(FALSE, fp->uf_name, (linenr_T)0);
  fc->dbg_tick = debug_tick;

  // Set up fields for closure.
  fc->fc_refcount = 0;
  fc->fc_copyID = 0;
  ga_init(&fc->fc_funcs, sizeof(ufunc_T *), 1);
  func_ptr_ref(fp);

  if (STRNCMP(fp->uf_name, "<lambda>", 8) == 0) {
    islambda = true;
  }

  // Note about using fc->fixvar[]: This is an array of FIXVAR_CNT variables
  // with names up to VAR_SHORT_LEN long.  This avoids having to alloc/free
  // each argument variable and saves a lot of time.
  //
  // Init l: variables.
  init_var_dict(&fc->l_vars, &fc->l_vars_var, VAR_DEF_SCOPE);
  if (selfdict != NULL) {
    // Set l:self to "selfdict".  Use "name" to avoid a warning from
    // some compiler that checks the destination size.
    v = (dictitem_T *)&fc->fixvar[fixvar_idx++];
#ifndef __clang_analyzer__
    name = v->di_key;
    STRCPY(name, "self");
#endif
    v->di_flags = DI_FLAGS_RO | DI_FLAGS_FIX;
    tv_dict_add(&fc->l_vars, v);
    v->di_tv.v_type = VAR_DICT;
    v->di_tv.v_lock = 0;
    v->di_tv.vval.v_dict = selfdict;
    ++selfdict->dv_refcount;
  }

  /*
   * Init a: variables.
   * Set a:0 to "argcount".
   * Set a:000 to a list with room for the "..." arguments.
   */
  init_var_dict(&fc->l_avars, &fc->l_avars_var, VAR_SCOPE);
  add_nr_var(&fc->l_avars, (dictitem_T *)&fc->fixvar[fixvar_idx++], "0",
             (varnumber_T)(argcount - fp->uf_args.ga_len));
  fc->l_avars.dv_lock = VAR_FIXED;
  // Use "name" to avoid a warning from some compiler that checks the
  // destination size.
  v = (dictitem_T *)&fc->fixvar[fixvar_idx++];
#ifndef __clang_analyzer__
  name = v->di_key;
  STRCPY(name, "000");
#endif
  v->di_flags = DI_FLAGS_RO | DI_FLAGS_FIX;
  tv_dict_add(&fc->l_avars, v);
  v->di_tv.v_type = VAR_LIST;
  v->di_tv.v_lock = VAR_FIXED;
  v->di_tv.vval.v_list = &fc->l_varlist;
  tv_list_init_static(&fc->l_varlist);
  tv_list_set_lock(&fc->l_varlist, VAR_FIXED);

  // Set a:firstline to "firstline" and a:lastline to "lastline".
  // Set a:name to named arguments.
  // Set a:N to the "..." arguments.
  add_nr_var(&fc->l_avars, (dictitem_T *)&fc->fixvar[fixvar_idx++],
             "firstline", (varnumber_T)firstline);
  add_nr_var(&fc->l_avars, (dictitem_T *)&fc->fixvar[fixvar_idx++],
             "lastline", (varnumber_T)lastline);
  for (int i = 0; i < argcount; i++) {
    bool addlocal = false;

    ai = i - fp->uf_args.ga_len;
    if (ai < 0) {
      // named argument a:name
      name = FUNCARG(fp, i);
      if (islambda) {
        addlocal = true;
      }
    } else {
      // "..." argument a:1, a:2, etc.
      snprintf((char *)numbuf, sizeof(numbuf), "%d", ai + 1);
      name = numbuf;
    }
    if (fixvar_idx < FIXVAR_CNT && STRLEN(name) <= VAR_SHORT_LEN) {
      v = (dictitem_T *)&fc->fixvar[fixvar_idx++];
      v->di_flags = DI_FLAGS_RO | DI_FLAGS_FIX;
    } else {
      v = xmalloc(sizeof(dictitem_T) + STRLEN(name));
      v->di_flags = DI_FLAGS_RO | DI_FLAGS_FIX | DI_FLAGS_ALLOC;
    }
    STRCPY(v->di_key, name);

    // Note: the values are copied directly to avoid alloc/free.
    // "argvars" must have VAR_FIXED for v_lock.
    v->di_tv = argvars[i];
    v->di_tv.v_lock = VAR_FIXED;

    if (addlocal) {
      // Named arguments can be accessed without the "a:" prefix in lambda
      // expressions. Add to the l: dict.
      tv_copy(&v->di_tv, &v->di_tv);
      tv_dict_add(&fc->l_vars, v);
    } else {
      tv_dict_add(&fc->l_avars, v);
    }

    if (ai >= 0 && ai < MAX_FUNC_ARGS) {
      tv_list_append(&fc->l_varlist, &fc->l_listitems[ai]);
      *TV_LIST_ITEM_TV(&fc->l_listitems[ai]) = argvars[i];
      TV_LIST_ITEM_TV(&fc->l_listitems[ai])->v_lock = VAR_FIXED;
    }
  }

  /* Don't redraw while executing the function. */
  ++RedrawingDisabled;
  save_sourcing_name = sourcing_name;
  save_sourcing_lnum = sourcing_lnum;
  sourcing_lnum = 1;

  if (fp->uf_flags & FC_SANDBOX) {
    using_sandbox = true;
    sandbox++;
  }

  // need space for new sourcing_name:
  // * save_sourcing_name
  // * "["number"].." or "function "
  // * "<SNR>" + fp->uf_name - 3
  // * terminating NUL
  size_t len = (save_sourcing_name == NULL ? 0 : STRLEN(save_sourcing_name))
               + STRLEN(fp->uf_name) + 27;
  sourcing_name = xmalloc(len);
  {
    if (save_sourcing_name != NULL
        && STRNCMP(save_sourcing_name, "function ", 9) == 0) {
      vim_snprintf((char *)sourcing_name,
                   len,
                   "%s[%" PRId64 "]..",
                   save_sourcing_name,
                   (int64_t)save_sourcing_lnum);
    } else {
      STRCPY(sourcing_name, "function ");
    }
    cat_func_name(sourcing_name + STRLEN(sourcing_name), fp);

    if (p_verbose >= 12) {
      ++no_wait_return;
      verbose_enter_scroll();

      smsg(_("calling %s"), sourcing_name);
      if (p_verbose >= 14) {
        msg_puts("(");
        for (int i = 0; i < argcount; i++) {
          if (i > 0) {
            msg_puts(", ");
          }
          if (argvars[i].v_type == VAR_NUMBER) {
            msg_outnum((long)argvars[i].vval.v_number);
          } else {
            // Do not want errors such as E724 here.
            emsg_off++;
            char *tofree = encode_tv2string(&argvars[i], NULL);
            emsg_off--;
            if (tofree != NULL) {
              char *s = tofree;
              char buf[MSG_BUF_LEN];
              if (vim_strsize((char_u *)s) > MSG_BUF_CLEN) {
                trunc_string((char_u *)s, (char_u *)buf, MSG_BUF_CLEN,
                             sizeof(buf));
                s = buf;
              }
              msg_puts(s);
              xfree(tofree);
            }
          }
        }
        msg_puts(")");
      }
      msg_puts("\n");  // don't overwrite this either

      verbose_leave_scroll();
      --no_wait_return;
    }
  }

  const bool do_profiling_yes = do_profiling == PROF_YES;

  bool func_not_yet_profiling_but_should =
    do_profiling_yes
    && !fp->uf_profiling && has_profiling(false, fp->uf_name, NULL);

  if (func_not_yet_profiling_but_should) {
    started_profiling = true;
    func_do_profile(fp);
  }

  bool func_or_func_caller_profiling =
    do_profiling_yes
    && (fp->uf_profiling
        || (fc->caller != NULL && fc->caller->func->uf_profiling));

  if (func_or_func_caller_profiling) {
    ++fp->uf_tm_count;
    call_start = profile_start();
    fp->uf_tm_children = profile_zero();
  }

  if (do_profiling_yes) {
    script_prof_save(&wait_start);
  }

  const sctx_T save_current_sctx = current_sctx;
  current_sctx = fp->uf_script_ctx;
  save_did_emsg = did_emsg;
  did_emsg = FALSE;

  /* call do_cmdline() to execute the lines */
  do_cmdline(NULL, get_func_line, (void *)fc,
      DOCMD_NOWAIT|DOCMD_VERBOSE|DOCMD_REPEAT);

  --RedrawingDisabled;

  // when the function was aborted because of an error, return -1
  if ((did_emsg
       && (fp->uf_flags & FC_ABORT)) || rettv->v_type == VAR_UNKNOWN) {
    tv_clear(rettv);
    rettv->v_type = VAR_NUMBER;
    rettv->vval.v_number = -1;
  }

  if (func_or_func_caller_profiling) {
    call_start = profile_end(call_start);
    call_start = profile_sub_wait(wait_start, call_start);  // -V614
    fp->uf_tm_total = profile_add(fp->uf_tm_total, call_start);
    fp->uf_tm_self = profile_self(fp->uf_tm_self, call_start,
        fp->uf_tm_children);
    if (fc->caller != NULL && fc->caller->func->uf_profiling) {
      fc->caller->func->uf_tm_children =
        profile_add(fc->caller->func->uf_tm_children, call_start);
      fc->caller->func->uf_tml_children =
        profile_add(fc->caller->func->uf_tml_children, call_start);
    }
    if (started_profiling) {
      // make a ":profdel func" stop profiling the function
      fp->uf_profiling = false;
    }
  }

  /* when being verbose, mention the return value */
  if (p_verbose >= 12) {
    ++no_wait_return;
    verbose_enter_scroll();

    if (aborting())
      smsg(_("%s aborted"), sourcing_name);
    else if (fc->rettv->v_type == VAR_NUMBER)
      smsg(_("%s returning #%" PRId64 ""),
           sourcing_name, (int64_t)fc->rettv->vval.v_number);
    else {
      char_u buf[MSG_BUF_LEN];

      // The value may be very long.  Skip the middle part, so that we
      // have some idea how it starts and ends. smsg() would always
      // truncate it at the end. Don't want errors such as E724 here.
      emsg_off++;
      char_u *s = (char_u *) encode_tv2string(fc->rettv, NULL);
      char_u *tofree = s;
      emsg_off--;
      if (s != NULL) {
        if (vim_strsize(s) > MSG_BUF_CLEN) {
          trunc_string(s, buf, MSG_BUF_CLEN, MSG_BUF_LEN);
          s = buf;
        }
        smsg(_("%s returning %s"), sourcing_name, s);
        xfree(tofree);
      }
    }
    msg_puts("\n");  // don't overwrite this either

    verbose_leave_scroll();
    --no_wait_return;
  }

  xfree(sourcing_name);
  sourcing_name = save_sourcing_name;
  sourcing_lnum = save_sourcing_lnum;
  current_sctx = save_current_sctx;
  if (do_profiling_yes) {
    script_prof_restore(&wait_start);
  }
  if (using_sandbox) {
    sandbox--;
  }

  if (p_verbose >= 12 && sourcing_name != NULL) {
    ++no_wait_return;
    verbose_enter_scroll();

    smsg(_("continuing in %s"), sourcing_name);
    msg_puts("\n");  // don't overwrite this either

    verbose_leave_scroll();
    --no_wait_return;
  }

  did_emsg |= save_did_emsg;
  depth--;

  cleanup_function_call(fc);

  if (--fp->uf_calls <= 0 && fp->uf_refcount <= 0) {
    // Function was unreferenced while being used, free it now.
    func_clear_free(fp, false);
  }
  // restore search patterns and redo buffer
  if (did_save_redo) {
    restoreRedobuff(&save_redo);
  }
  restore_search_patterns();
}

/// Unreference "fc": decrement the reference count and free it when it
/// becomes zero.  "fp" is detached from "fc".
///
/// @param[in]   force   When true, we are exiting.
static void funccal_unref(funccall_T *fc, ufunc_T *fp, bool force)
{
  funccall_T **pfc;
  int i;

  if (fc == NULL) {
    return;
  }

  fc->fc_refcount--;
  if (force ? fc->fc_refcount <= 0 : !fc_referenced(fc)) {
    for (pfc = &previous_funccal; *pfc != NULL; pfc = &(*pfc)->caller) {
      if (fc == *pfc) {
        *pfc = fc->caller;
        free_funccal(fc, true);
        return;
      }
    }
  }
  for (i = 0; i < fc->fc_funcs.ga_len; i++) {
    if (((ufunc_T **)(fc->fc_funcs.ga_data))[i] == fp) {
      ((ufunc_T **)(fc->fc_funcs.ga_data))[i] = NULL;
    }
  }
}

/// @return true if items in "fc" do not have "copyID".  That means they are not
/// referenced from anywhere that is in use.
static int can_free_funccal(funccall_T *fc, int copyID)
{
  return fc->l_varlist.lv_copyID != copyID
         && fc->l_vars.dv_copyID != copyID
         && fc->l_avars.dv_copyID != copyID
         && fc->fc_copyID != copyID;
}

/*
 * Free "fc" and what it contains.
 */
static void
free_funccal(
    funccall_T *fc,
    int free_val              /* a: vars were allocated */
)
{
  for (int i = 0; i < fc->fc_funcs.ga_len; i++) {
    ufunc_T *fp = ((ufunc_T **)(fc->fc_funcs.ga_data))[i];

    // When garbage collecting a funccall_T may be freed before the
    // function that references it, clear its uf_scoped field.
    // The function may have been redefined and point to another
    // funccal_T, don't clear it then.
    if (fp != NULL && fp->uf_scoped == fc) {
      fp->uf_scoped = NULL;
    }
  }
  ga_clear(&fc->fc_funcs);

  // The a: variables typevals may not have been allocated, only free the
  // allocated variables.
  vars_clear_ext(&fc->l_avars.dv_hashtab, free_val);

  // Free all l: variables.
  vars_clear(&fc->l_vars.dv_hashtab);

  // Free the a:000 variables if they were allocated.
  if (free_val) {
    TV_LIST_ITER(&fc->l_varlist, li, {
      tv_clear(TV_LIST_ITEM_TV(li));
    });
  }

  func_ptr_unref(fc->func);
  xfree(fc);
}

/// Handle the last part of returning from a function: free the local hashtable.
/// Unless it is still in use by a closure.
static void cleanup_function_call(funccall_T *fc)
{
  current_funccal = fc->caller;

  // If the a:000 list and the l: and a: dicts are not referenced and there
  // is no closure using it, we can free the funccall_T and what's in it.
  if (!fc_referenced(fc)) {
    free_funccal(fc, false);
  } else {
    // "fc" is still in use.  This can happen when returning "a:000",
    // assigning "l:" to a global variable or defining a closure.
    // Link "fc" in the list for garbage collection later.
    fc->caller = previous_funccal;
    previous_funccal = fc;

    // Make a copy of the a: variables, since we didn't do that above.
    TV_DICT_ITER(&fc->l_avars, di, {
      tv_copy(&di->di_tv, &di->di_tv);
    });

    // Make a copy of the a:000 items, since we didn't do that above.
    TV_LIST_ITER(&fc->l_varlist, li, {
      tv_copy(TV_LIST_ITEM_TV(li), TV_LIST_ITEM_TV(li));
    });
  }
}

/*
 * Add a number variable "name" to dict "dp" with value "nr".
 */
static void add_nr_var(dict_T *dp, dictitem_T *v, char *name, varnumber_T nr)
{
#ifndef __clang_analyzer__
  STRCPY(v->di_key, name);
#endif
  v->di_flags = DI_FLAGS_RO | DI_FLAGS_FIX;
  tv_dict_add(dp, v);
  v->di_tv.v_type = VAR_NUMBER;
  v->di_tv.v_lock = VAR_FIXED;
  v->di_tv.vval.v_number = nr;
}

/*
 * ":return [expr]"
 */
void ex_return(exarg_T *eap)
{
  char_u      *arg = eap->arg;
  typval_T rettv;
  int returning = FALSE;

  if (current_funccal == NULL) {
    EMSG(_("E133: :return not inside a function"));
    return;
  }

  if (eap->skip)
    ++emsg_skip;

  eap->nextcmd = NULL;
  if ((*arg != NUL && *arg != '|' && *arg != '\n')
      && eval0(arg, &rettv, &eap->nextcmd, !eap->skip) != FAIL) {
    if (!eap->skip) {
      returning = do_return(eap, false, true, &rettv);
    } else {
      tv_clear(&rettv);
    }
  } else if (!eap->skip) {  // It's safer to return also on error.
    // In return statement, cause_abort should be force_abort.
    update_force_abort();

    // Return unless the expression evaluation has been cancelled due to an
    // aborting error, an interrupt, or an exception.
    if (!aborting()) {
      returning = do_return(eap, false, true, NULL);
    }
  }

  /* When skipping or the return gets pending, advance to the next command
   * in this line (!returning).  Otherwise, ignore the rest of the line.
   * Following lines will be ignored by get_func_line(). */
  if (returning)
    eap->nextcmd = NULL;
  else if (eap->nextcmd == NULL)            /* no argument */
    eap->nextcmd = check_nextcmd(arg);

  if (eap->skip)
    --emsg_skip;
}

/*
 * Return from a function.  Possibly makes the return pending.  Also called
 * for a pending return at the ":endtry" or after returning from an extra
 * do_cmdline().  "reanimate" is used in the latter case.  "is_cmd" is set
 * when called due to a ":return" command.  "rettv" may point to a typval_T
 * with the return rettv.  Returns TRUE when the return can be carried out,
 * FALSE when the return gets pending.
 */
int do_return(exarg_T *eap, int reanimate, int is_cmd, void *rettv)
{
  int idx;
  cstack_T *const cstack = eap->cstack;

  if (reanimate)
    /* Undo the return. */
    current_funccal->returned = FALSE;

  /*
   * Cleanup (and inactivate) conditionals, but stop when a try conditional
   * not in its finally clause (which then is to be executed next) is found.
   * In this case, make the ":return" pending for execution at the ":endtry".
   * Otherwise, return normally.
   */
  idx = cleanup_conditionals(eap->cstack, 0, TRUE);
  if (idx >= 0) {
    cstack->cs_pending[idx] = CSTP_RETURN;

    if (!is_cmd && !reanimate)
      /* A pending return again gets pending.  "rettv" points to an
       * allocated variable with the rettv of the original ":return"'s
       * argument if present or is NULL else. */
      cstack->cs_rettv[idx] = rettv;
    else {
      /* When undoing a return in order to make it pending, get the stored
       * return rettv. */
      if (reanimate) {
        assert(current_funccal->rettv);
        rettv = current_funccal->rettv;
      }

      if (rettv != NULL) {
        /* Store the value of the pending return. */
        cstack->cs_rettv[idx] = xcalloc(1, sizeof(typval_T));
        *(typval_T *)cstack->cs_rettv[idx] = *(typval_T *)rettv;
      } else
        cstack->cs_rettv[idx] = NULL;

      if (reanimate) {
        /* The pending return value could be overwritten by a ":return"
         * without argument in a finally clause; reset the default
         * return value. */
        current_funccal->rettv->v_type = VAR_NUMBER;
        current_funccal->rettv->vval.v_number = 0;
      }
    }
    report_make_pending(CSTP_RETURN, rettv);
  } else {
    current_funccal->returned = TRUE;

    /* If the return is carried out now, store the return value.  For
     * a return immediately after reanimation, the value is already
     * there. */
    if (!reanimate && rettv != NULL) {
      tv_clear(current_funccal->rettv);
      *current_funccal->rettv = *(typval_T *)rettv;
      if (!is_cmd)
        xfree(rettv);
    }
  }

  return idx < 0;
}

/*
 * Generate a return command for producing the value of "rettv".  The result
 * is an allocated string.  Used by report_pending() for verbose messages.
 */
char_u *get_return_cmd(void *rettv)
{
  char_u *s = NULL;
  char_u *tofree = NULL;

  if (rettv != NULL) {
    tofree = s = (char_u *) encode_tv2echo((typval_T *) rettv, NULL);
  }
  if (s == NULL) {
    s = (char_u *)"";
  }

  STRCPY(IObuff, ":return ");
  STRLCPY(IObuff + 8, s, IOSIZE - 8);
  if (STRLEN(s) + 8 >= IOSIZE)
    STRCPY(IObuff + IOSIZE - 4, "...");
  xfree(tofree);
  return vim_strsave(IObuff);
}

/*
 * Get next function line.
 * Called by do_cmdline() to get the next line.
 * Returns allocated string, or NULL for end of function.
 */
char_u *get_func_line(int c, void *cookie, int indent, bool do_concat)
{
  funccall_T  *fcp = (funccall_T *)cookie;
  ufunc_T     *fp = fcp->func;
  char_u      *retval;
  garray_T    *gap;    /* growarray with function lines */

  /* If breakpoints have been added/deleted need to check for it. */
  if (fcp->dbg_tick != debug_tick) {
    fcp->breakpoint = dbg_find_breakpoint(FALSE, fp->uf_name,
        sourcing_lnum);
    fcp->dbg_tick = debug_tick;
  }
  if (do_profiling == PROF_YES)
    func_line_end(cookie);

  gap = &fp->uf_lines;
  if (((fp->uf_flags & FC_ABORT) && did_emsg && !aborted_in_try())
      || fcp->returned)
    retval = NULL;
  else {
    /* Skip NULL lines (continuation lines). */
    while (fcp->linenr < gap->ga_len
           && ((char_u **)(gap->ga_data))[fcp->linenr] == NULL)
      ++fcp->linenr;
    if (fcp->linenr >= gap->ga_len)
      retval = NULL;
    else {
      retval = vim_strsave(((char_u **)(gap->ga_data))[fcp->linenr++]);
      sourcing_lnum = fcp->linenr;
      if (do_profiling == PROF_YES)
        func_line_start(cookie);
    }
  }

  /* Did we encounter a breakpoint? */
  if (fcp->breakpoint != 0 && fcp->breakpoint <= sourcing_lnum) {
    dbg_breakpoint(fp->uf_name, sourcing_lnum);
    /* Find next breakpoint. */
    fcp->breakpoint = dbg_find_breakpoint(FALSE, fp->uf_name,
        sourcing_lnum);
    fcp->dbg_tick = debug_tick;
  }

  return retval;
}

/*
 * Called when starting to read a function line.
 * "sourcing_lnum" must be correct!
 * When skipping lines it may not actually be executed, but we won't find out
 * until later and we need to store the time now.
 */
void func_line_start(void *cookie)
{
  funccall_T  *fcp = (funccall_T *)cookie;
  ufunc_T     *fp = fcp->func;

  if (fp->uf_profiling && sourcing_lnum >= 1
      && sourcing_lnum <= fp->uf_lines.ga_len) {
    fp->uf_tml_idx = sourcing_lnum - 1;
    /* Skip continuation lines. */
    while (fp->uf_tml_idx > 0 && FUNCLINE(fp, fp->uf_tml_idx) == NULL)
      --fp->uf_tml_idx;
    fp->uf_tml_execed = FALSE;
    fp->uf_tml_start = profile_start();
    fp->uf_tml_children = profile_zero();
    fp->uf_tml_wait = profile_get_wait();
  }
}

/*
 * Called when actually executing a function line.
 */
void func_line_exec(void *cookie)
{
  funccall_T  *fcp = (funccall_T *)cookie;
  ufunc_T     *fp = fcp->func;

  if (fp->uf_profiling && fp->uf_tml_idx >= 0)
    fp->uf_tml_execed = TRUE;
}

/*
 * Called when done with a function line.
 */
void func_line_end(void *cookie)
{
  funccall_T  *fcp = (funccall_T *)cookie;
  ufunc_T     *fp = fcp->func;

  if (fp->uf_profiling && fp->uf_tml_idx >= 0) {
    if (fp->uf_tml_execed) {
      ++fp->uf_tml_count[fp->uf_tml_idx];
      fp->uf_tml_start = profile_end(fp->uf_tml_start);
      fp->uf_tml_start = profile_sub_wait(fp->uf_tml_wait, fp->uf_tml_start);
      fp->uf_tml_total[fp->uf_tml_idx] =
        profile_add(fp->uf_tml_total[fp->uf_tml_idx], fp->uf_tml_start);
      fp->uf_tml_self[fp->uf_tml_idx] =
        profile_self(fp->uf_tml_self[fp->uf_tml_idx], fp->uf_tml_start,
          fp->uf_tml_children);
    }
    fp->uf_tml_idx = -1;
  }
}

/*
 * Return TRUE if the currently active function should be ended, because a
 * return was encountered or an error occurred.  Used inside a ":while".
 */
int func_has_ended(void *cookie)
{
  funccall_T  *fcp = (funccall_T *)cookie;

  /* Ignore the "abort" flag if the abortion behavior has been changed due to
   * an error inside a try conditional. */
  return ((fcp->func->uf_flags & FC_ABORT) && did_emsg && !aborted_in_try())
         || fcp->returned;
}

/*
 * return TRUE if cookie indicates a function which "abort"s on errors.
 */
int func_has_abort(void *cookie)
{
  return ((funccall_T *)cookie)->func->uf_flags & FC_ABORT;
}

static var_flavour_T var_flavour(char_u *varname)
{
  char_u *p = varname;

  if (ASCII_ISUPPER(*p)) {
    while (*(++p))
      if (ASCII_ISLOWER(*p)) {
        return VAR_FLAVOUR_SESSION;
      }
    return VAR_FLAVOUR_SHADA;
  } else {
    return VAR_FLAVOUR_DEFAULT;
  }
}

/// Search hashitem in parent scope.
hashitem_T *find_hi_in_scoped_ht(const char *name, hashtab_T **pht)
{
  if (current_funccal == NULL || current_funccal->func->uf_scoped == NULL) {
    return NULL;
  }

  funccall_T *old_current_funccal = current_funccal;
  hashitem_T *hi = NULL;
  const size_t namelen = strlen(name);
  const char *varname;

  // Search in parent scope which is possible to reference from lambda
  current_funccal = current_funccal->func->uf_scoped;
  while (current_funccal != NULL) {
    hashtab_T *ht = find_var_ht(name, namelen, &varname);
    if (ht != NULL && *varname != NUL) {
      hi = hash_find_len(ht, varname, namelen - (varname - name));
      if (!HASHITEM_EMPTY(hi)) {
        *pht = ht;
        break;
      }
    }
    if (current_funccal == current_funccal->func->uf_scoped) {
      break;
    }
    current_funccal = current_funccal->func->uf_scoped;
  }
  current_funccal = old_current_funccal;

  return hi;
}

/// Search variable in parent scope.
dictitem_T *find_var_in_scoped_ht(const char *name, const size_t namelen,
                                  int no_autoload)
{
  if (current_funccal == NULL || current_funccal->func->uf_scoped == NULL) {
    return NULL;
  }

  dictitem_T *v = NULL;
  funccall_T *old_current_funccal = current_funccal;
  const char *varname;

  // Search in parent scope which is possible to reference from lambda
  current_funccal = current_funccal->func->uf_scoped;
  while (current_funccal) {
    hashtab_T *ht = find_var_ht(name, namelen, &varname);
    if (ht != NULL && *varname != NUL) {
      v = find_var_in_ht(ht, *name, varname,
                         namelen - (size_t)(varname - name), no_autoload);
      if (v != NULL) {
        break;
      }
    }
    if (current_funccal == current_funccal->func->uf_scoped) {
      break;
    }
    current_funccal = current_funccal->func->uf_scoped;
  }
  current_funccal = old_current_funccal;

  return v;
}

/// Iterate over global variables
///
/// @warning No modifications to global variable dictionary must be performed
///          while iteration is in progress.
///
/// @param[in]   iter   Iterator. Pass NULL to start iteration.
/// @param[out]  name   Variable name.
/// @param[out]  rettv  Variable value.
///
/// @return Pointer that needs to be passed to next `var_shada_iter` invocation
///         or NULL to indicate that iteration is over.
const void *var_shada_iter(const void *const iter, const char **const name,
                           typval_T *rettv, var_flavour_T flavour)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(2, 3)
{
  const hashitem_T *hi;
  const hashitem_T *hifirst = globvarht.ht_array;
  const size_t hinum = (size_t) globvarht.ht_mask + 1;
  *name = NULL;
  if (iter == NULL) {
    hi = globvarht.ht_array;
    while ((size_t) (hi - hifirst) < hinum
           && (HASHITEM_EMPTY(hi)
               || !(var_flavour(hi->hi_key) & flavour))) {
      hi++;
    }
    if ((size_t) (hi - hifirst) == hinum) {
      return NULL;
    }
  } else {
    hi = (const hashitem_T *) iter;
  }
  *name = (char *)TV_DICT_HI2DI(hi)->di_key;
  tv_copy(&TV_DICT_HI2DI(hi)->di_tv, rettv);
  while ((size_t)(++hi - hifirst) < hinum) {
    if (!HASHITEM_EMPTY(hi) && (var_flavour(hi->hi_key) & flavour)) {
      return hi;
    }
  }
  return NULL;
}

void var_set_global(const char *const name, typval_T vartv)
{
  funccall_T *const saved_current_funccal = current_funccal;
  current_funccal = NULL;
  set_var(name, strlen(name), &vartv, false);
  current_funccal = saved_current_funccal;
}

int store_session_globals(FILE *fd)
{
  TV_DICT_ITER(&globvardict, this_var, {
    if ((this_var->di_tv.v_type == VAR_NUMBER
         || this_var->di_tv.v_type == VAR_STRING)
        && var_flavour(this_var->di_key) == VAR_FLAVOUR_SESSION) {
      // Escape special characters with a backslash.  Turn a LF and
      // CR into \n and \r.
      char_u *const p = vim_strsave_escaped(
          (const char_u *)tv_get_string(&this_var->di_tv),
          (const char_u *)"\\\"\n\r");
      for (char_u *t = p; *t != NUL; t++) {
        if (*t == '\n') {
          *t = 'n';
        } else if (*t == '\r') {
          *t = 'r';
        }
      }
      if ((fprintf(fd, "let %s = %c%s%c",
                   this_var->di_key,
                   ((this_var->di_tv.v_type == VAR_STRING) ? '"'
                    : ' '),
                   p,
                   ((this_var->di_tv.v_type == VAR_STRING) ? '"'
                    : ' ')) < 0)
          || put_eol(fd) == FAIL) {
        xfree(p);
        return FAIL;
      }
      xfree(p);
    } else if (this_var->di_tv.v_type == VAR_FLOAT
               && var_flavour(this_var->di_key) == VAR_FLAVOUR_SESSION) {
      float_T f = this_var->di_tv.vval.v_float;
      int sign = ' ';

      if (f < 0) {
        f = -f;
        sign = '-';
      }
      if ((fprintf(fd, "let %s = %c%f", this_var->di_key, sign, f) < 0)
          || put_eol(fd) == FAIL) {
        return FAIL;
      }
    }
  });
  return OK;
}

/*
 * Display script name where an item was last set.
 * Should only be invoked when 'verbose' is non-zero.
 */
void last_set_msg(sctx_T script_ctx)
{
  const LastSet last_set = (LastSet){
    .script_ctx = script_ctx,
    .channel_id = 0,
  };
  option_last_set_msg(last_set);
}

/// Displays where an option was last set.
///
/// Should only be invoked when 'verbose' is non-zero.
void option_last_set_msg(LastSet last_set)
{
  if (last_set.script_ctx.sc_sid != 0) {
    bool should_free;
    char_u *p = get_scriptname(last_set, &should_free);
    verbose_enter();
    MSG_PUTS(_("\n\tLast set from "));
    MSG_PUTS(p);
    if (last_set.script_ctx.sc_lnum > 0) {
      MSG_PUTS(_(line_msg));
      msg_outnum((long)last_set.script_ctx.sc_lnum);
    }
    if (should_free) {
      xfree(p);
    }
    verbose_leave();
  }
}

// reset v:option_new, v:option_old and v:option_type
void reset_v_option_vars(void)
{
  set_vim_var_string(VV_OPTION_NEW,  NULL, -1);
  set_vim_var_string(VV_OPTION_OLD,  NULL, -1);
  set_vim_var_string(VV_OPTION_TYPE, NULL, -1);
}

/*
 * Adjust a filename, according to a string of modifiers.
 * *fnamep must be NUL terminated when called.  When returning, the length is
 * determined by *fnamelen.
 * Returns VALID_ flags or -1 for failure.
 * When there is an error, *fnamep is set to NULL.
 */
int
modify_fname(
    char_u *src,              // string with modifiers
    bool tilde_file,          // "~" is a file name, not $HOME
    size_t *usedlen,          // characters after src that are used
    char_u **fnamep,          // file name so far
    char_u **bufp,            // buffer for allocated file name or NULL
    size_t *fnamelen          // length of fnamep
)
{
  int valid = 0;
  char_u      *tail;
  char_u      *s, *p, *pbuf;
  char_u dirname[MAXPATHL];
  int c;
  int has_fullname = 0;

repeat:
  /* ":p" - full path/file_name */
  if (src[*usedlen] == ':' && src[*usedlen + 1] == 'p') {
    has_fullname = 1;

    valid |= VALID_PATH;
    *usedlen += 2;

    /* Expand "~/path" for all systems and "~user/path" for Unix */
    if ((*fnamep)[0] == '~'
#if !defined(UNIX)
        && ((*fnamep)[1] == '/'
# ifdef BACKSLASH_IN_FILENAME
            || (*fnamep)[1] == '\\'
# endif
            || (*fnamep)[1] == NUL)
#endif
        && !(tilde_file && (*fnamep)[1] == NUL)
        ) {
      *fnamep = expand_env_save(*fnamep);
      xfree(*bufp);          /* free any allocated file name */
      *bufp = *fnamep;
      if (*fnamep == NULL)
        return -1;
    }

    // When "/." or "/.." is used: force expansion to get rid of it.
    for (p = *fnamep; *p != NUL; MB_PTR_ADV(p)) {
      if (vim_ispathsep(*p)
          && p[1] == '.'
          && (p[2] == NUL
              || vim_ispathsep(p[2])
              || (p[2] == '.'
                  && (p[3] == NUL || vim_ispathsep(p[3]))))) {
        break;
      }
    }

    /* FullName_save() is slow, don't use it when not needed. */
    if (*p != NUL || !vim_isAbsName(*fnamep)) {
      *fnamep = (char_u *)FullName_save((char *)*fnamep, *p != NUL);
      xfree(*bufp);          /* free any allocated file name */
      *bufp = *fnamep;
      if (*fnamep == NULL)
        return -1;
    }

    /* Append a path separator to a directory. */
    if (os_isdir(*fnamep)) {
      /* Make room for one or two extra characters. */
      *fnamep = vim_strnsave(*fnamep, STRLEN(*fnamep) + 2);
      xfree(*bufp);          /* free any allocated file name */
      *bufp = *fnamep;
      if (*fnamep == NULL)
        return -1;
      add_pathsep((char *)*fnamep);
    }
  }

  /* ":." - path relative to the current directory */
  /* ":~" - path relative to the home directory */
  /* ":8" - shortname path - postponed till after */
  while (src[*usedlen] == ':'
         && ((c = src[*usedlen + 1]) == '.' || c == '~' || c == '8')) {
    *usedlen += 2;
    if (c == '8') {
      continue;
    }
    pbuf = NULL;
    /* Need full path first (use expand_env() to remove a "~/") */
    if (!has_fullname) {
      if (c == '.' && **fnamep == '~')
        p = pbuf = expand_env_save(*fnamep);
      else
        p = pbuf = (char_u *)FullName_save((char *)*fnamep, FALSE);
    } else
      p = *fnamep;

    has_fullname = 0;

    if (p != NULL) {
      if (c == '.') {
        os_dirname(dirname, MAXPATHL);
        s = path_shorten_fname(p, dirname);
        if (s != NULL) {
          *fnamep = s;
          if (pbuf != NULL) {
            xfree(*bufp);               /* free any allocated file name */
            *bufp = pbuf;
            pbuf = NULL;
          }
        }
      } else {
        home_replace(NULL, p, dirname, MAXPATHL, TRUE);
        /* Only replace it when it starts with '~' */
        if (*dirname == '~') {
          s = vim_strsave(dirname);
          *fnamep = s;
          xfree(*bufp);
          *bufp = s;
        }
      }
      xfree(pbuf);
    }
  }

  tail = path_tail(*fnamep);
  *fnamelen = STRLEN(*fnamep);

  /* ":h" - head, remove "/file_name", can be repeated  */
  /* Don't remove the first "/" or "c:\" */
  while (src[*usedlen] == ':' && src[*usedlen + 1] == 'h') {
    valid |= VALID_HEAD;
    *usedlen += 2;
    s = get_past_head(*fnamep);
    while (tail > s && after_pathsep((char *)s, (char *)tail)) {
      MB_PTR_BACK(*fnamep, tail);
    }
    *fnamelen = (size_t)(tail - *fnamep);
    if (*fnamelen == 0) {
      /* Result is empty.  Turn it into "." to make ":cd %:h" work. */
      xfree(*bufp);
      *bufp = *fnamep = tail = vim_strsave((char_u *)".");
      *fnamelen = 1;
    } else {
      while (tail > s && !after_pathsep((char *)s, (char *)tail)) {
        MB_PTR_BACK(*fnamep, tail);
      }
    }
  }

  /* ":8" - shortname  */
  if (src[*usedlen] == ':' && src[*usedlen + 1] == '8') {
    *usedlen += 2;
  }


  /* ":t" - tail, just the basename */
  if (src[*usedlen] == ':' && src[*usedlen + 1] == 't') {
    *usedlen += 2;
    *fnamelen -= (size_t)(tail - *fnamep);
    *fnamep = tail;
  }

  /* ":e" - extension, can be repeated */
  /* ":r" - root, without extension, can be repeated */
  while (src[*usedlen] == ':'
         && (src[*usedlen + 1] == 'e' || src[*usedlen + 1] == 'r')) {
    /* find a '.' in the tail:
     * - for second :e: before the current fname
     * - otherwise: The last '.'
     */
    const bool is_second_e = *fnamep > tail;
    if (src[*usedlen + 1] == 'e' && is_second_e) {
      s = *fnamep - 2;
    } else {
      s = *fnamep + *fnamelen - 1;
    }

    for (; s > tail; s--) {
      if (s[0] == '.') {
        break;
      }
    }
    if (src[*usedlen + 1] == 'e') {
      if (s > tail || (0 && is_second_e && s == tail)) {
        // we stopped at a '.' (so anchor to &'.' + 1)
        char_u *newstart = s + 1;
        size_t distance_stepped_back = *fnamep - newstart;
        *fnamelen += distance_stepped_back;
        *fnamep = newstart;
      } else if (*fnamep <= tail) {
        *fnamelen = 0;
      }
    } else {
      // :r - Remove one extension
      //
      // Ensure that `s` doesn't go before `*fnamep`,
      // since then we're taking too many roots:
      //
      // "path/to/this.file.ext" :e:e:r:r
      //          ^    ^-------- *fnamep
      //          +------------- tail
      //
      // Also ensure `s` doesn't go before `tail`,
      // since then we're taking too many roots again:
      //
      // "path/to/this.file.ext" :r:r:r
      //  ^       ^------------- tail
      //  +--------------------- *fnamep
      if (s > MAX(tail, *fnamep)) {
        *fnamelen = (size_t)(s - *fnamep);
      }
    }
    *usedlen += 2;
  }

  /* ":s?pat?foo?" - substitute */
  /* ":gs?pat?foo?" - global substitute */
  if (src[*usedlen] == ':'
      && (src[*usedlen + 1] == 's'
          || (src[*usedlen + 1] == 'g' && src[*usedlen + 2] == 's'))) {
    char_u      *str;
    char_u      *pat;
    char_u      *sub;
    int sep;
    char_u      *flags;
    int didit = FALSE;

    flags = (char_u *)"";
    s = src + *usedlen + 2;
    if (src[*usedlen + 1] == 'g') {
      flags = (char_u *)"g";
      ++s;
    }

    sep = *s++;
    if (sep) {
      /* find end of pattern */
      p = vim_strchr(s, sep);
      if (p != NULL) {
        pat = vim_strnsave(s, (int)(p - s));
        s = p + 1;
        /* find end of substitution */
        p = vim_strchr(s, sep);
        if (p != NULL) {
          sub = vim_strnsave(s, (int)(p - s));
          str = vim_strnsave(*fnamep, *fnamelen);
          *usedlen = (size_t)(p + 1 - src);
          s = do_string_sub(str, pat, sub, NULL, flags);
          *fnamep = s;
          *fnamelen = STRLEN(s);
          xfree(*bufp);
          *bufp = s;
          didit = TRUE;
          xfree(sub);
          xfree(str);
        }
        xfree(pat);
      }
      /* after using ":s", repeat all the modifiers */
      if (didit)
        goto repeat;
    }
  }

  if (src[*usedlen] == ':' && src[*usedlen + 1] == 'S') {
    // vim_strsave_shellescape() needs a NUL terminated string.
    c = (*fnamep)[*fnamelen];
    if (c != NUL) {
      (*fnamep)[*fnamelen] = NUL;
    }
    p = vim_strsave_shellescape(*fnamep, false, false);
    if (c != NUL) {
      (*fnamep)[*fnamelen] = c;
    }
    xfree(*bufp);
    *bufp = *fnamep = p;
    *fnamelen = STRLEN(p);
    *usedlen += 2;
  }

  return valid;
}

/// Perform a substitution on "str" with pattern "pat" and substitute "sub".
/// When "sub" is NULL "expr" is used, must be a VAR_FUNC or VAR_PARTIAL.
/// "flags" can be "g" to do a global substitute.
/// Returns an allocated string, NULL for error.
char_u *do_string_sub(char_u *str, char_u *pat, char_u *sub,
                      typval_T *expr, char_u *flags)
{
  int sublen;
  regmatch_T regmatch;
  int do_all;
  char_u      *tail;
  char_u      *end;
  garray_T ga;
  char_u      *save_cpo;
  char_u      *zero_width = NULL;

  /* Make 'cpoptions' empty, so that the 'l' flag doesn't work here */
  save_cpo = p_cpo;
  p_cpo = empty_option;

  ga_init(&ga, 1, 200);

  do_all = (flags[0] == 'g');

  regmatch.rm_ic = p_ic;
  regmatch.regprog = vim_regcomp(pat, RE_MAGIC + RE_STRING);
  if (regmatch.regprog != NULL) {
    tail = str;
    end = str + STRLEN(str);
    while (vim_regexec_nl(&regmatch, str, (colnr_T)(tail - str))) {
      /* Skip empty match except for first match. */
      if (regmatch.startp[0] == regmatch.endp[0]) {
        if (zero_width == regmatch.startp[0]) {
          // avoid getting stuck on a match with an empty string
          int i = utfc_ptr2len(tail);
          memmove((char_u *)ga.ga_data + ga.ga_len, tail, (size_t)i);
          ga.ga_len += i;
          tail += i;
          continue;
        }
        zero_width = regmatch.startp[0];
      }

      // Get some space for a temporary buffer to do the substitution
      // into.  It will contain:
      // - The text up to where the match is.
      // - The substituted text.
      // - The text after the match.
      sublen = vim_regsub(&regmatch, sub, expr, tail, false, true, false);
      ga_grow(&ga, (int)((end - tail) + sublen -
                     (regmatch.endp[0] - regmatch.startp[0])));

      /* copy the text up to where the match is */
      int i = (int)(regmatch.startp[0] - tail);
      memmove((char_u *)ga.ga_data + ga.ga_len, tail, (size_t)i);
      // add the substituted text
      (void)vim_regsub(&regmatch, sub, expr, (char_u *)ga.ga_data
                       + ga.ga_len + i, true, true, false);
      ga.ga_len += i + sublen - 1;
      tail = regmatch.endp[0];
      if (*tail == NUL)
        break;
      if (!do_all)
        break;
    }

    if (ga.ga_data != NULL)
      STRCPY((char *)ga.ga_data + ga.ga_len, tail);

    vim_regfree(regmatch.regprog);
  }

  char_u *ret = vim_strsave(ga.ga_data == NULL ? str : (char_u *)ga.ga_data);
  ga_clear(&ga);
  if (p_cpo == empty_option) {
    p_cpo = save_cpo;
  } else {
    // Darn, evaluating {sub} expression or {expr} changed the value.
    free_string_option(save_cpo);
  }

  return ret;
}

/// common code for getting job callbacks for jobstart, termopen and rpcstart
///
/// @return true/false on success/failure.
bool common_job_callbacks(dict_T *vopts,
                          CallbackReader *on_stdout,
                          CallbackReader *on_stderr,
                          Callback *on_exit)
{
  if (tv_dict_get_callback(vopts, S_LEN("on_stdout"), &on_stdout->cb)
      &&tv_dict_get_callback(vopts, S_LEN("on_stderr"), &on_stderr->cb)
      && tv_dict_get_callback(vopts, S_LEN("on_exit"), on_exit)) {
    on_stdout->buffered = tv_dict_get_number(vopts, "stdout_buffered");
    on_stderr->buffered = tv_dict_get_number(vopts, "stderr_buffered");
    if (on_stdout->buffered && on_stdout->cb.type == kCallbackNone) {
      on_stdout->self = vopts;
    }
    if (on_stderr->buffered && on_stderr->cb.type == kCallbackNone) {
      on_stderr->self = vopts;
    }
    vopts->dv_refcount++;
    return true;
  }

  callback_reader_free(on_stdout);
  callback_reader_free(on_stderr);
  callback_free(on_exit);
  return false;
}


Channel *find_job(uint64_t id, bool show_error)
{
  Channel *data = find_channel(id);
  if (!data || data->streamtype != kChannelStreamProc
      || process_is_stopped(&data->stream.proc)) {
    if (show_error) {
      if (data && data->streamtype != kChannelStreamProc) {
        EMSG(_(e_invchanjob));
      } else {
        EMSG(_(e_invchan));
      }
    }
    return NULL;
  }
  return data;
}


void script_host_eval(char *name, typval_T *argvars, typval_T *rettv)
{
  if (check_restricted() || check_secure()) {
    return;
  }

  if (argvars[0].v_type != VAR_STRING) {
    EMSG(_(e_invarg));
    return;
  }

  list_T *args = tv_list_alloc(1);
  tv_list_append_string(args, (const char *)argvars[0].vval.v_string, -1);
  *rettv = eval_call_provider(name, "eval", args);
}

typval_T eval_call_provider(char *provider, char *method, list_T *arguments)
{
  if (!eval_has_provider(provider)) {
    emsgf("E319: No \"%s\" provider found. Run \":checkhealth provider\"",
          provider);
    return (typval_T){
      .v_type = VAR_NUMBER,
      .v_lock = VAR_UNLOCKED,
      .vval.v_number = (varnumber_T)0
    };
  }

  char func[256];
  int name_len = snprintf(func, sizeof(func), "provider#%s#Call", provider);

  // Save caller scope information
  struct caller_scope saved_provider_caller_scope = provider_caller_scope;
  provider_caller_scope = (struct caller_scope) {
    .script_ctx = current_sctx,
    .sourcing_name = sourcing_name,
    .sourcing_lnum = sourcing_lnum,
    .autocmd_fname = autocmd_fname,
    .autocmd_match = autocmd_match,
    .autocmd_bufnr = autocmd_bufnr,
    .funccalp = save_funccal()
  };
  provider_call_nesting++;

  typval_T argvars[3] = {
    {.v_type = VAR_STRING, .vval.v_string = (uint8_t *)method, .v_lock = 0},
    {.v_type = VAR_LIST, .vval.v_list = arguments, .v_lock = 0},
    {.v_type = VAR_UNKNOWN}
  };
  typval_T rettv = { .v_type = VAR_UNKNOWN, .v_lock = VAR_UNLOCKED };
  tv_list_ref(arguments);

  int dummy;
  (void)call_func((const char_u *)func,
                  name_len,
                  &rettv,
                  2,
                  argvars,
                  NULL,
                  curwin->w_cursor.lnum,
                  curwin->w_cursor.lnum,
                  &dummy,
                  true,
                  NULL,
                  NULL);

  tv_list_unref(arguments);
  // Restore caller scope information
  restore_funccal(provider_caller_scope.funccalp);
  provider_caller_scope = saved_provider_caller_scope;
  provider_call_nesting--;
  assert(provider_call_nesting >= 0);

  return rettv;
}

/// Checks if provider for feature `feat` is enabled.
bool eval_has_provider(const char *feat)
{
  if (!strequal(feat, "clipboard")
      && !strequal(feat, "python")
      && !strequal(feat, "python3")
      && !strequal(feat, "python_compiled")
      && !strequal(feat, "python_dynamic")
      && !strequal(feat, "python3_compiled")
      && !strequal(feat, "python3_dynamic")
      && !strequal(feat, "perl")
      && !strequal(feat, "ruby")
      && !strequal(feat, "node")) {
    // Avoid autoload for non-provider has() features.
    return false;
  }

  char name[32];  // Normalized: "python_compiled" => "python".
  snprintf(name, sizeof(name), "%s", feat);
  strchrsub(name, '_', '\0');  // Chop any "_xx" suffix.

  char buf[256];
  typval_T tv;
  // Get the g:loaded_xx_provider variable.
  int len = snprintf(buf, sizeof(buf), "g:loaded_%s_provider", name);
  if (get_var_tv(buf, len, &tv, NULL, false, true) == FAIL) {
    // Trigger autoload once.
    len = snprintf(buf, sizeof(buf), "provider#%s#bogus", name);
    script_autoload(buf, len, false);

    // Retry the (non-autoload-style) variable.
    len = snprintf(buf, sizeof(buf), "g:loaded_%s_provider", name);
    if (get_var_tv(buf, len, &tv, NULL, false, true) == FAIL) {
      // Show a hint if Call() is defined but g:loaded_xx_provider is missing.
      snprintf(buf, sizeof(buf), "provider#%s#Call", name);
      if (!!find_func((char_u *)buf) && p_lpl) {
        emsgf("provider: %s: missing required variable g:loaded_%s_provider",
              name, name);
      }
      return false;
    }
  }

  bool ok = (tv.v_type == VAR_NUMBER)
    ? 2 == tv.vval.v_number  // Value of 2 means "loaded and working".
    : false;

  if (ok) {
    // Call() must be defined if provider claims to be working.
    snprintf(buf, sizeof(buf), "provider#%s#Call", name);
    if (!find_func((char_u *)buf)) {
      emsgf("provider: %s: g:loaded_%s_provider=2 but %s is not defined",
            name, name, buf);
      ok = false;
    }
  }

  return ok;
}

/// Writes "<sourcing_name>:<sourcing_lnum>" to `buf[bufsize]`.
void eval_fmt_source_name_line(char *buf, size_t bufsize)
{
  if (sourcing_name) {
    snprintf(buf, bufsize, "%s:%" PRIdLINENR, sourcing_name, sourcing_lnum);
  } else {
    snprintf(buf, bufsize, "?");
  }
}

/// ":checkhealth [plugins]"
void ex_checkhealth(exarg_T *eap)
{
  bool found = !!find_func((char_u *)"health#check");
  if (!found
      && script_autoload("health#check", sizeof("health#check") - 1, false)) {
    found = !!find_func((char_u *)"health#check");
  }
  if (!found) {
    const char *vimruntime_env = os_getenv("VIMRUNTIME");
    if (vimruntime_env == NULL) {
      EMSG(_("E5009: $VIMRUNTIME is empty or unset"));
    } else {
      bool rtp_ok = NULL != strstr((char *)p_rtp, vimruntime_env);
      if (rtp_ok) {
        EMSG2(_("E5009: Invalid $VIMRUNTIME: %s"), vimruntime_env);
      } else {
        EMSG(_("E5009: Invalid 'runtimepath'"));
      }
    }
    return;
  }

  size_t bufsize = STRLEN(eap->arg) + sizeof("call health#check('')");
  char *buf = xmalloc(bufsize);
  snprintf(buf, bufsize, "call health#check('%s')", eap->arg);

  do_cmdline_cmd(buf);

  xfree(buf);
}

void invoke_prompt_callback(void)
{
    typval_T rettv;
    typval_T argv[2];
    char_u *text;
    char_u *prompt;
    linenr_T lnum = curbuf->b_ml.ml_line_count;

    // Add a new line for the prompt before invoking the callback, so that
    // text can always be inserted above the last line.
    ml_append(lnum, (char_u  *)"", 0, false);
    curwin->w_cursor.lnum = lnum + 1;
    curwin->w_cursor.col = 0;

    if (curbuf->b_prompt_callback.type == kCallbackNone) {
      return;
    }
    text = ml_get(lnum);
    prompt = prompt_text();
    if (STRLEN(text) >= STRLEN(prompt)) {
      text += STRLEN(prompt);
    }
    argv[0].v_type = VAR_STRING;
    argv[0].vval.v_string = vim_strsave(text);
    argv[1].v_type = VAR_UNKNOWN;

    callback_call(&curbuf->b_prompt_callback, 1, argv, &rettv);
    tv_clear(&argv[0]);
    tv_clear(&rettv);
}

// Return true When the interrupt callback was invoked.
bool invoke_prompt_interrupt(void)
{
    typval_T rettv;
    typval_T argv[1];

    if (curbuf->b_prompt_interrupt.type == kCallbackNone) {
      return false;
    }
    argv[0].v_type = VAR_UNKNOWN;

    got_int = false;  // don't skip executing commands
    callback_call(&curbuf->b_prompt_interrupt, 0, argv, &rettv);
    tv_clear(&rettv);
    return true;
}
