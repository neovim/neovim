// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * eval.c: Expression evaluation.
 */

#include <math.h>

#include "auto/config.h"

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
#include "nvim/eval/userfunc.h"
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

#define DICT_MAXNEST 100        // maximum nesting of lists and dicts


static char *e_letunexp = N_("E18: Unexpected characters in :let");
static char *e_missbrac = N_("E111: Missing ']'");
static char *e_dictrange = N_("E719: Cannot use [:] with a Dictionary");
static char *e_illvar = N_("E461: Illegal variable name: %s");
static char *e_cannot_mod = N_("E995: Cannot modify existing variable");
static char *e_nowhitespace
  = N_("E274: No white space allowed before parenthesis");
static char *e_invalwindow = N_("E957: Invalid window number");
static char *e_lock_unlock = N_("E940: Cannot lock or unlock variable %s");
static char *e_write2 = N_("E80: Error while writing: %s");

// TODO(ZyX-I): move to eval/executor
static char *e_letwrong = N_("E734: Wrong variable type for %s=");

static char_u * const namespace_char = (char_u *)"abglstvw";

/// Variable used for g:
static ScopeDictDictItem globvars_var;

/*
 * Old Vim variables such as "v:version" are also available without the "v:".
 * Also in functions.  We need a special hashtable for them.
 */
static hashtab_T compat_hashtab;

/// Used for checking if local variables or arguments used in a lambda.
bool *eval_lavars_used = NULL;

/*
 * Array to hold the hashtab with variables local to each sourced script.
 * Each item holds a variable (nameless) that points to the dict_T.
 */
typedef struct {
  ScopeDictDictItem sv_var;
  dict_T sv_dict;
} scriptvar_T;

static garray_T ga_scripts = { 0, 0, sizeof(scriptvar_T *), 4, NULL };
#define SCRIPT_SV(id) (((scriptvar_T **)ga_scripts.ga_data)[(id) - 1])
#define SCRIPT_VARS(id) (SCRIPT_SV(id)->sv_dict.dv_hashtab)

static int echo_attr = 0;   // attributes used for ":echo"

// The names of packages that once were loaded are remembered.
static garray_T ga_loaded = { 0, 0, sizeof(char_u *), 4, NULL };

/*
 * Info used by a ":for" loop.
 */
typedef struct {
  int fi_semicolon;             // TRUE if ending in '; var]'
  int fi_varcount;              // nr of variables in the list
  listwatch_T fi_lw;            // keep an eye on the item used.
  list_T *fi_list;         // list being used
  int fi_bi;                    // index of blob
  blob_T *fi_blob;              // blob being used
} forinfo_T;

// values for vv_flags:
#define VV_COMPAT       1       // compatible, also used without "v:"
#define VV_RO           2       // read-only
#define VV_RO_SBX       4       // read-only in the sandbox

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
  char *vv_name;  ///< Name of the variable, without v:.
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
  VV(VV_FALSE,          "false",            VAR_BOOL, VV_RO),
  VV(VV_TRUE,           "true",             VAR_BOOL, VV_RO),
  VV(VV_NULL,           "null",             VAR_SPECIAL, VV_RO),
  VV(VV_NUMBERMAX,      "numbermax",        VAR_NUMBER, VV_RO),
  VV(VV_NUMBERMIN,      "numbermin",        VAR_NUMBER, VV_RO),
  VV(VV_NUMBERSIZE,     "numbersize",       VAR_NUMBER, VV_RO),
  VV(VV_VIM_DID_ENTER,  "vim_did_enter",    VAR_NUMBER, VV_RO),
  VV(VV_TESTING,        "testing",          VAR_NUMBER, 0),
  VV(VV_TYPE_NUMBER,    "t_number",         VAR_NUMBER, VV_RO),
  VV(VV_TYPE_STRING,    "t_string",         VAR_NUMBER, VV_RO),
  VV(VV_TYPE_FUNC,      "t_func",           VAR_NUMBER, VV_RO),
  VV(VV_TYPE_LIST,      "t_list",           VAR_NUMBER, VV_RO),
  VV(VV_TYPE_DICT,      "t_dict",           VAR_NUMBER, VV_RO),
  VV(VV_TYPE_FLOAT,     "t_float",          VAR_NUMBER, VV_RO),
  VV(VV_TYPE_BOOL,      "t_bool",           VAR_NUMBER, VV_RO),
  VV(VV_TYPE_BLOB,      "t_blob",           VAR_NUMBER, VV_RO),
  VV(VV_EVENT,          "event",            VAR_DICT, VV_RO),
  VV(VV_ECHOSPACE,      "echospace",        VAR_NUMBER, VV_RO),
  VV(VV_ARGV,           "argv",             VAR_LIST, VV_RO),
  VV(VV_COLLATE,        "collate",          VAR_STRING, VV_RO),
  VV(VV_EXITING,        "exiting",          VAR_NUMBER, VV_RO),
  // Neovim
  VV(VV_STDERR,         "stderr",           VAR_NUMBER, VV_RO),
  VV(VV_MSGPACK_TYPES,  "msgpack_types",    VAR_DICT, VV_RO),
  VV(VV__NULL_STRING,   "_null_string",     VAR_STRING, VV_RO),
  VV(VV__NULL_LIST,     "_null_list",       VAR_LIST, VV_RO),
  VV(VV__NULL_DICT,     "_null_dict",       VAR_DICT, VV_RO),
  VV(VV__NULL_BLOB,     "_null_blob",       VAR_BLOB, VV_RO),
  VV(VV_LUA,            "lua",              VAR_PARTIAL, VV_RO),
};
#undef VV

// shorthand
#define vv_type         vv_di.di_tv.v_type
#define vv_nr           vv_di.di_tv.vval.v_number
#define vv_bool         vv_di.di_tv.vval.v_bool
#define vv_special      vv_di.di_tv.vval.v_special
#define vv_float        vv_di.di_tv.vval.v_float
#define vv_str          vv_di.di_tv.vval.v_string
#define vv_list         vv_di.di_tv.vval.v_list
#define vv_dict         vv_di.di_tv.vval.v_dict
#define vv_blob         vv_di.di_tv.vval.v_blob
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
static PMap(uint64_t) timers = MAP_INIT;

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

  struct vimvar *p;

  init_var_dict(&globvardict, &globvars_var, VAR_DEF_SCOPE);
  init_var_dict(&vimvardict, &vimvars_var, VAR_SCOPE);
  vimvardict.dv_lock = VAR_FIXED;
  hash_init(&compat_hashtab);
  func_init();

  for (size_t i = 0; i < ARRAY_SIZE(vimvars); i++) {
    p = &vimvars[i];
    assert(STRLEN(p->vv_name) <= 16);
    STRCPY(p->vv_di.di_key, p->vv_name);
    if (p->vv_flags & VV_RO) {
      p->vv_di.di_flags = DI_FLAGS_RO | DI_FLAGS_FIX;
    } else if (p->vv_flags & VV_RO_SBX) {
      p->vv_di.di_flags = DI_FLAGS_RO_SBX | DI_FLAGS_FIX;
    } else {
      p->vv_di.di_flags = DI_FLAGS_FIX;
    }

    // add to v: scope dict, unless the value is not always available
    if (p->vv_type != VAR_UNKNOWN) {
      hash_add(&vimvarht, p->vv_di.di_key);
    }
    if (p->vv_flags & VV_COMPAT) {
      // add to compat scope dict
      hash_add(&compat_hashtab, p->vv_di.di_key);
    }
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
      abort();
    }
  }
  msgpack_types_dict->dv_lock = VAR_FIXED;

  set_vim_var_dict(VV_MSGPACK_TYPES, msgpack_types_dict);
  set_vim_var_dict(VV_COMPLETED_ITEM, tv_dict_alloc_lock(VAR_FIXED));

  set_vim_var_dict(VV_EVENT, tv_dict_alloc_lock(VAR_FIXED));
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
  set_vim_var_nr(VV_TYPE_BLOB,   VAR_TYPE_BLOB);

  set_vim_var_bool(VV_FALSE, kBoolVarFalse);
  set_vim_var_bool(VV_TRUE, kBoolVarTrue);
  set_vim_var_special(VV_NULL, kSpecialVarNull);
  set_vim_var_nr(VV_NUMBERMAX, VARNUMBER_MAX);
  set_vim_var_nr(VV_NUMBERMIN, VARNUMBER_MIN);
  set_vim_var_nr(VV_NUMBERSIZE, sizeof(varnumber_T) * 8);
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
  struct vimvar *p;

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
  hash_init(&vimvarht);    // garbage_collect() will access it
  hash_clear(&compat_hashtab);

  free_scriptnames();
  free_locales();

  // global variables
  vars_clear(&globvarht);

  // autoloaded script names
  ga_clear_strings(&ga_loaded);

  /* Script-local variables. First clear all the variables and in a second
   * loop free the scriptvar_T, because a variable in one script might hold
   * a reference to the whole scope of another script. */
  for (int i = 1; i <= ga_scripts.ga_len; ++i) {
    vars_clear(&SCRIPT_VARS(i));
  }
  for (int i = 1; i <= ga_scripts.ga_len; ++i) {
    xfree(SCRIPT_SV(i));
  }
  ga_clear(&ga_scripts);

  // unreferenced lists and dicts
  (void)garbage_collect(false);

  // functions not garbage collected
  free_all_functions();
}

#endif

/*
 * Set an internal variable to a string value. Creates the variable if it does
 * not already exist.
 */
void set_internal_string_var(const char *name, char_u *value)
  FUNC_ATTR_NONNULL_ARG(1)
{
  typval_T tv = {
    .v_type = VAR_STRING,
    .vval.v_string = value,
  };

  set_var(name, strlen(name), &tv, true);
}

static lval_T *redir_lval = NULL;
static garray_T redir_ga;  // Only valid when redir_lval is not NULL.
static char_u *redir_endp = NULL;
static char_u *redir_varname = NULL;

/// Start recording command output to a variable
/// Returns OK if successfully completed the setup.  FAIL otherwise.
///
/// @param append  append to an existing variable
int var_redir_start(char_u *name, int append)
{
  int save_emsg;
  int err;
  typval_T tv;

  // Catch a bad name early.
  if (!eval_isnamec1(*name)) {
    emsg(_(e_invarg));
    return FAIL;
  }

  // Make a copy of the name, it is used in redir_lval until redir ends.
  redir_varname = vim_strsave(name);

  redir_lval = xcalloc(1, sizeof(lval_T));

  // The output is stored in growarray "redir_ga" until redirection ends.
  ga_init(&redir_ga, (int)sizeof(char), 500);

  // Parse the variable name (can be a dict or list entry).
  redir_endp = get_lval(redir_varname, NULL, redir_lval, false, false,
                        0, FNE_CHECK_START);
  if (redir_endp == NULL || redir_lval->ll_name == NULL
      || *redir_endp != NUL) {
    clear_lval(redir_lval);
    if (redir_endp != NULL && *redir_endp != NUL) {
      // Trailing characters are present after the variable name
      emsg(_(e_trailing));
    } else {
      emsg(_(e_invarg));
    }
    redir_endp = NULL;      // don't store a value, only cleanup
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
    set_var_lval(redir_lval, redir_endp, &tv, true, false, ".");
  } else {
    set_var_lval(redir_lval, redir_endp, &tv, true, false, "=");
  }
  clear_lval(redir_lval);
  err = did_emsg;
  did_emsg |= save_emsg;
  if (err) {
    redir_endp = NULL;      // don't store a value, only cleanup
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

  if (redir_lval == NULL) {
    return;
  }

  if (value_len == -1) {
    len = (int)STRLEN(value);           // Append the entire string
  } else {
    len = value_len;                    // Append only "value_len" characters
  }

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
    // If there was no error: assign the text to the variable.
    if (redir_endp != NULL) {
      ga_append(&redir_ga, NUL);        // Append the trailing NUL.
      tv.v_type = VAR_STRING;
      tv.vval.v_string = redir_ga.ga_data;
      // Call get_lval() again, if it's inside a Dict or List it may
      // have changed.
      redir_endp = get_lval(redir_varname, NULL, redir_lval,
                            false, false, 0, FNE_CHECK_START);
      if (redir_endp != NULL && redir_lval->ll_name != NULL) {
        set_var_lval(redir_lval, redir_endp, &tv, false, false, ".");
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

void eval_diff(const char *const origfile, const char *const newfile, const char *const outfile)
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

void eval_patch(const char *const origfile, const char *const difffile, const char *const outfile)
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

/// Top level evaluation function, returning a boolean.
/// Sets "error" to TRUE if there was an error.
///
/// @param skip  only parse, don't execute
///
/// @return  TRUE or FALSE.
int eval_to_bool(char_u *arg, bool *error, char_u **nextcmd, int skip)
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
      semsg(_(e_invexpr2), start);
    }
  }
  return ret;
}

int eval_expr_typval(const typval_T *expr, typval_T *argv, int argc, typval_T *rettv)
  FUNC_ATTR_NONNULL_ARG(1, 2, 4)
{
  funcexe_T funcexe = FUNCEXE_INIT;

  if (expr->v_type == VAR_FUNC) {
    const char_u *const s = expr->vval.v_string;
    if (s == NULL || *s == NUL) {
      return FAIL;
    }
    funcexe.evaluate = true;
    if (call_func(s, -1, rettv, argc, argv, &funcexe) == FAIL) {
      return FAIL;
    }
  } else if (expr->v_type == VAR_PARTIAL) {
    partial_T *const partial = expr->vval.v_partial;
    const char_u *const s = partial_name(partial);
    if (s == NULL || *s == NUL) {
      return FAIL;
    }
    funcexe.evaluate = true;
    funcexe.partial = partial;
    if (call_func(s, -1, rettv, argc, argv, &funcexe) == FAIL) {
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
    if (*skipwhite(s) != NUL) {  // check for trailing chars after expr
      tv_clear(rettv);
      semsg(_(e_invexpr2), s);
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
char *eval_to_string_skip(const char *arg, const char **nextcmd, const bool skip)
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

/// Top level evaluation function, returning a string.
///
/// @param convert  when true convert a List into a sequence of lines and convert
///                 a Float to a String.
///
/// @return         pointer to allocated memory, or NULL for failure.
char_u *eval_to_string(char_u *arg, char_u **nextcmd, bool convert)
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
  char_u *retval;
  funccal_entry_T funccal_entry;

  save_funccal(&funccal_entry);
  if (use_sandbox) {
    sandbox++;
  }
  textlock++;
  retval = eval_to_string(arg, nextcmd, false);
  if (use_sandbox) {
    sandbox--;
  }
  textlock--;
  restore_funccal();
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
  char_u *p = skipwhite(expr);

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

// Top level evaluation function.
// Returns an allocated typval_T with the result.
// Returns NULL when there is an error.
typval_T *eval_expr(char_u *arg)
{
  typval_T *tv = xmalloc(sizeof(*tv));
  if (eval0(arg, tv, NULL, true) == FAIL) {
    XFREE_CLEAR(tv);
  }
  return tv;
}

/*
 * Prepare v: variable "idx" to be used.
 * Save the current typeval in "save_tv".
 * When not used yet add the variable to the v: hashtable.
 */
void prepare_vimvar(int idx, typval_T *save_tv)
{
  *save_tv = vimvars[idx].vv_tv;
  if (vimvars[idx].vv_type == VAR_UNKNOWN) {
    hash_add(&vimvarht, vimvars[idx].vv_di.di_key);
  }
}

/*
 * Restore v: variable "idx" to typeval "save_tv".
 * When no longer defined, remove the variable from the v: hashtable.
 */
void restore_vimvar(int idx, typval_T *save_tv)
{
  hashitem_T *hi;

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
  list_T *list = NULL;
  char_u *p = skipwhite(expr);

  // Set "v:val" to the bad word.
  prepare_vimvar(VV_VAL, &save_val);
  vimvars[VV_VAL].vv_type = VAR_STRING;
  vimvars[VV_VAL].vv_str = badword;
  if (p_verbose == 0) {
    ++emsg_off;
  }

  if (eval1(&p, &rettv, true) == OK) {
    if (rettv.v_type != VAR_LIST) {
      tv_clear(&rettv);
    } else {
      list = rettv.vval.v_list;
    }
  }

  if (p_verbose == 0) {
    --emsg_off;
  }
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
    emsg(_("E5700: Expression from 'spellsuggest' must yield lists with "
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
int call_vim_function(const char_u *func, int argc, typval_T *argv, typval_T *rettv)
  FUNC_ATTR_NONNULL_ALL
{
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
  funcexe_T funcexe = FUNCEXE_INIT;
  funcexe.firstline = curwin->w_cursor.lnum;
  funcexe.lastline = curwin->w_cursor.lnum;
  funcexe.evaluate = true;
  funcexe.partial = pt;
  ret = call_func(func, len, rettv, argc, argv, &funcexe);

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
varnumber_T call_func_retnr(const char_u *func, int argc, typval_T *argv)
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
char *call_func_retstr(const char *const func, int argc, typval_T *argv)
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

/// Prepare profiling for entering a child or something else that is not
/// counted for the script/function itself.
/// Should always be called in pair with prof_child_exit().
///
/// @param tm  place to store waittime
void prof_child_enter(proftime_T *tm)
{
  funccall_T *fc = get_current_funccal();

  if (fc != NULL && fc->func->uf_profiling) {
    fc->prof_child = profile_start();
  }

  script_prof_save(tm);
}

/// Take care of time spent in a child.
/// Should always be called after prof_child_enter().
///
/// @param tm  where waittime was stored
void prof_child_exit(proftime_T *tm)
{
  funccall_T *fc = get_current_funccal();

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
  int use_sandbox = was_set_insecurely(curwin, "foldexpr", OPT_LOCAL);

  ++emsg_off;
  if (use_sandbox) {
    ++sandbox;
  }
  ++textlock;
  *cp = NUL;
  if (eval0(arg, &tv, NULL, true) == FAIL) {
    retval = 0;
  } else {
    // If the result is a number, just return the number.
    if (tv.v_type == VAR_NUMBER) {
      retval = tv.vval.v_number;
    } else if (tv.v_type != VAR_STRING || tv.vval.v_string == NULL) {
      retval = 0;
    } else {
      // If the result is a string, check if there is a non-digit before
      // the number.
      char_u *s = tv.vval.v_string;
      if (!ascii_isdigit(*s) && *s != '-') {
        *cp = *s++;
      }
      retval = atol((char *)s);
    }
    tv_clear(&tv);
  }
  --emsg_off;
  if (use_sandbox) {
    --sandbox;
  }
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
static list_T *heredoc_get(exarg_T *eap, char_u *cmd)
{
  char_u *marker;
  char_u *p;
  int marker_indent_len = 0;
  int text_indent_len = 0;
  char_u *text_indent = NULL;

  if (eap->getline == NULL) {
    emsg(_("E991: cannot use =<< here"));
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
      emsg(_(e_trailing));
      return NULL;
    }
    *p = NUL;
    if (islower(*marker)) {
      emsg(_("E221: Marker cannot start with lower case letter"));
      return NULL;
    }
  } else {
    emsg(_("E172: Missing marker"));
    return NULL;
  }

  list_T *l = tv_list_alloc(0);
  for (;;) {
    int mi = 0;
    int ti = 0;

    char_u *theline = eap->getline(NUL, eap->cookie, 0, false);
    if (theline == NULL) {
      semsg(_("E990: Missing end marker '%s'"), marker);
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
  char_u *arg = eap->arg;
  char_u *expr = NULL;
  typval_T rettv;
  int i;
  int var_count = 0;
  int semicolon = 0;
  char_u op[2];
  char_u *argend;
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
      emsg(_(e_invarg));
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

    if (eap->skip) {
      ++emsg_skip;
    }
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

/// Assign the typevalue "tv" to the variable or variables at "arg_start".
/// Handles both "var" with any type and "[var, var; var]" with a list type.
/// When "op" is not NULL it points to a string with characters that
/// must appear after the variable(s).  Use "+", "-" or "." for add, subtract
/// or concatenate.
///
/// @param copy  copy values from "tv", don't move
/// @param semicolon  from skip_var_list()
/// @param var_count  from skip_var_list()
/// @param is_const  lock variables for :const
///
/// @return  OK or FAIL;
static int ex_let_vars(char_u *arg_start, typval_T *tv, int copy, int semicolon, int var_count,
                       int is_const, char_u *op)
{
  char_u *arg = arg_start;
  typval_T ltv;

  if (*arg != '[') {
    /*
     * ":let var = expr" or ":for var in list"
     */
    if (ex_let_one(arg, tv, copy, is_const, op, op) == NULL) {
      return FAIL;
    }
    return OK;
  }

  // ":let [v1, v2] = list" or ":for [v1, v2] in listlist"
  if (tv->v_type != VAR_LIST) {
    emsg(_(e_listreq));
    return FAIL;
  }
  list_T *const l = tv->vval.v_list;

  const int len = tv_list_len(l);
  if (semicolon == 0 && var_count < len) {
    emsg(_("E687: Less targets than List items"));
    return FAIL;
  }
  if (var_count - semicolon > len) {
    emsg(_("E688: More targets than List items"));
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
                     (const char_u *)",;]", op);
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

      arg = ex_let_one(skipwhite(arg + 1), &ltv, false, is_const, (char_u *)"]",
                       op);
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
static const char_u *skip_var_list(const char_u *arg, int *var_count, int *semicolon)
{
  const char_u *p;
  const char_u *s;

  if (*arg == '[') {
    // "[var, var]": find the matching ']'.
    p = arg;
    for (;; ) {
      p = skipwhite(p + 1);             // skip whites after '[', ';' or ','
      s = skip_var_one(p);
      if (s == p) {
        semsg(_(e_invarg2), p);
        return NULL;
      }
      ++*var_count;

      p = skipwhite(s);
      if (*p == ']') {
        break;
      } else if (*p == ';') {
        if (*semicolon == 1) {
          emsg(_("E452: Double ; in list of variables"));
          return NULL;
        }
        *semicolon = 1;
      } else if (*p != ',') {
        semsg(_(e_invarg2), p);
        return NULL;
      }
    }
    return p + 1;
  } else {
    return skip_var_one(arg);
  }
}

/*
 * Skip one (assignable) variable name, including @r, $VAR, &option, d.key,
 * l[idx].
 */
static const char_u *skip_var_one(const char_u *arg)
{
  if (*arg == '@' && arg[1] != NUL) {
    return arg + 2;
  }
  return find_name_end(*arg == '$' || *arg == '&' ? arg + 1 : arg,
                       NULL, NULL, FNE_INCL_BR | FNE_CHECK_START);
}

/*
 * List variables for hashtab "ht" with prefix "prefix".
 * If "empty" is TRUE also list NULL strings as empty strings.
 */
void list_hashtable_vars(hashtab_T *ht, const char *prefix, int empty, int *first)
{
  hashitem_T *hi;
  dictitem_T *di;
  int todo;

  todo = (int)ht->ht_used;
  for (hi = ht->ht_array; todo > 0 && !got_int; ++hi) {
    if (!HASHITEM_EMPTY(hi)) {
      todo--;
      di = TV_DICT_HI2DI(hi);
      char buf[IOSIZE];

      // apply :filter /pat/ to variable name
      xstrlcpy(buf, prefix, IOSIZE);
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
        emsg_severe = true;
        emsg(_(e_trailing));
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
          emsg_severe = true;
          semsg(_(e_invarg2), arg);
          break;
        }
        error = TRUE;
      } else {
        if (tofree != NULL) {
          name = tofree;
        }
        if (get_var_tv(name, len, &tv, NULL, true, false)
            == FAIL) {
          error = true;
        } else {
          // handle d.key, l[idx], f(expr)
          const char *const arg_subsc = arg;
          if (handle_subscript(&arg, &tv, true, true, (const char_u *)name,
                               (const char_u **)&name)
              == FAIL) {
            error = true;
          } else {
            if (arg == arg_subsc && len == 2 && name[1] == ':') {
              switch (*name) {
              case 'g':
                list_glob_vars(first); break;
              case 'b':
                list_buf_vars(first); break;
              case 'w':
                list_win_vars(first); break;
              case 't':
                list_tab_vars(first); break;
              case 'v':
                list_vim_vars(first); break;
              case 's':
                list_script_vars(first); break;
              case 'l':
                list_func_vars(first); break;
              default:
                semsg(_("E738: Can't list variables for %s"), name);
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
static char_u *ex_let_one(char_u *arg, typval_T *const tv, const bool copy, const bool is_const,
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
      emsg(_("E996: Cannot lock an environment variable"));
      return NULL;
    }
    // Find the end of the name.
    arg++;
    char *name = (char *)arg;
    len = get_env_len((const char_u **)&arg);
    if (len == 0) {
      semsg(_(e_invarg2), name - 1);
    } else {
      if (op != NULL && vim_strchr((char_u *)"+-*/%", *op) != NULL) {
        semsg(_(e_letwrong), op);
      } else if (endchars != NULL
                 && vim_strchr(endchars, *skipwhite(arg)) == NULL) {
        emsg(_(e_letunexp));
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
      emsg(_("E996: Cannot lock an option"));
      return NULL;
    }
    // Find the end of the name.
    char *const p = (char *)find_option_end((const char **)&arg, &opt_flags);
    if (p == NULL
        || (endchars != NULL
            && vim_strchr(endchars, *skipwhite((const char_u *)p)) == NULL)) {
      emsg(_(e_letunexp));
    } else {
      int opt_type;
      long numval;
      char *stringval = NULL;
      const char *s = NULL;

      const char c1 = *p;
      *p = NUL;

      varnumber_T n = tv_get_number(tv);
      if (tv->v_type != VAR_BOOL && tv->v_type != VAR_SPECIAL) {
        s = tv_get_string_chk(tv);  // != NULL if number or string.
      }
      if (s != NULL && op != NULL && *op != '=') {
        opt_type = get_option_value((char *)arg, &numval, (char_u **)&stringval,
                                    opt_flags);
        if ((opt_type == 1 && *op == '.')
            || (opt_type == 0 && *op != '.')) {
          semsg(_(e_letwrong), op);
          s = NULL;  // don't set the value
        } else {
          if (opt_type == 1) {  // number
            switch (*op) {
            case '+':
              n = numval + n; break;
            case '-':
              n = numval - n; break;
            case '*':
              n = numval * n; break;
            case '/':
              n = num_divide(numval, n); break;
            case '%':
              n = num_modulus(numval, n); break;
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
      if (s != NULL || tv->v_type == VAR_BOOL
          || tv->v_type == VAR_SPECIAL) {
        set_option_value((const char *)arg, n, s, opt_flags);
        arg_end = (char_u *)p;
      }
      *p = c1;
      xfree(stringval);
    }
    // ":let @r = expr": Set register contents.
  } else if (*arg == '@') {
    if (is_const) {
      emsg(_("E996: Cannot lock a register"));
      return NULL;
    }
    arg++;
    if (op != NULL && vim_strchr((char_u *)"+-*/%", *op) != NULL) {
      semsg(_(e_letwrong), op);
    } else if (endchars != NULL
               && vim_strchr(endchars, *skipwhite(arg + 1)) == NULL) {
      emsg(_(e_letunexp));
    } else {
      char_u *s;

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
        emsg(_(e_letunexp));
      } else {
        set_var_lval(&lv, p, tv, copy, is_const, (const char *)op);
        arg_end = p;
      }
    }
    clear_lval(&lv);
  } else {
    semsg(_(e_invarg2), arg);
  }

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
char_u *get_lval(char_u *const name, typval_T *const rettv, lval_T *const lp, const bool unlet,
                 const bool skip, const int flags, const int fne_flags)
  FUNC_ATTR_NONNULL_ARG(1, 3)
{
  dictitem_T *v;
  typval_T var1;
  typval_T var2;
  int empty1 = FALSE;
  listitem_T *ni;
  hashtab_T *ht = NULL;
  int quiet = flags & GLV_QUIET;

  // Clear everything in "lp".
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
    // Don't expand the name when we already know there is an error.
    if (unlet && !ascii_iswhite(*p) && !ends_excmd(*p)
        && *p != '[' && *p != '.') {
      emsg(_(e_trailing));
      return NULL;
    }

    lp->ll_exp_name = (char *)make_expanded_name(name, expr_start, expr_end,
                                                 p);
    lp->ll_name = lp->ll_exp_name;
    if (lp->ll_exp_name == NULL) {
      // Report an invalid expression in braces, unless the
      // expression evaluation has been cancelled due to an
      // aborting error, an interrupt, or an exception.
      if (!aborting() && !quiet) {
        emsg_severe = true;
        semsg(_(e_invarg2), name);
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
    semsg(_("E121: Undefined variable: %.*s"),
          (int)lp->ll_name_len, lp->ll_name);
  }
  if (v == NULL) {
    return NULL;
  }

  // Loop until no more [idx] or .key is following.
  lp->ll_tv = &v->di_tv;
  var1.v_type = VAR_UNKNOWN;
  var2.v_type = VAR_UNKNOWN;
  while (*p == '[' || (*p == '.' && lp->ll_tv->v_type == VAR_DICT)) {
    if (!(lp->ll_tv->v_type == VAR_LIST && lp->ll_tv->vval.v_list != NULL)
        && !(lp->ll_tv->v_type == VAR_DICT && lp->ll_tv->vval.v_dict != NULL)
        && !(lp->ll_tv->v_type == VAR_BLOB && lp->ll_tv->vval.v_blob != NULL)) {
      if (!quiet) {
        emsg(_("E689: Can only index a List, Dictionary or Blob"));
      }
      return NULL;
    }
    if (lp->ll_range) {
      if (!quiet) {
        emsg(_("E708: [:] must come last"));
      }
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
          emsg(_("E713: Cannot use empty key after ."));
        }
        return NULL;
      }
      p = key + len;
    } else {
      // Get the index [expr] or the first index [expr: ].
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
        p = skipwhite(p);
      }

      // Optionally get the second index [ :expr].
      if (*p == ':') {
        if (lp->ll_tv->v_type == VAR_DICT) {
          if (!quiet) {
            emsg(_(e_dictrange));
          }
          tv_clear(&var1);
          return NULL;
        }
        if (rettv != NULL
            && !(rettv->v_type == VAR_LIST && rettv->vval.v_list != NULL)
            && !(rettv->v_type == VAR_BLOB && rettv->vval.v_blob != NULL)) {
          if (!quiet) {
            emsg(_("E709: [:] requires a List or Blob value"));
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
        lp->ll_range = true;
      } else {
        lp->ll_range = false;
      }

      if (*p != ']') {
        if (!quiet) {
          emsg(_(e_missbrac));
        }
        tv_clear(&var1);
        tv_clear(&var2);
        return NULL;
      }

      // Skip to past ']'.
      p++;
    }

    if (lp->ll_tv->v_type == VAR_DICT) {
      if (len == -1) {
        // "[key]": get key from "var1"
        key = (char_u *)tv_get_string(&var1);  // is number or string
      }
      lp->ll_list = NULL;
      lp->ll_dict = lp->ll_tv->vval.v_dict;
      lp->ll_di = tv_dict_find(lp->ll_dict, (const char *)key, len);

      // When assigning to a scope dictionary check that a function and
      // variable name is valid (only variable name unless it is l: or
      // g: dictionary). Disallow overwriting a builtin function.
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
        semsg(e_illvar, "v:['lua']");
        return NULL;
      }

      if (lp->ll_di == NULL) {
        // Can't add "v:" or "a:" variable.
        if (lp->ll_dict == &vimvardict
            || &lp->ll_dict->dv_hashtab == get_funccal_args_ht()) {
          semsg(_(e_illvar), name);
          tv_clear(&var1);
          return NULL;
        }

        // Key does not exist in dict: may need to add it.
        if (*p == '[' || *p == '.' || unlet) {
          if (!quiet) {
            semsg(_(e_dictkey), key);
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
    } else if (lp->ll_tv->v_type == VAR_BLOB) {
      // Get the number and item for the only or first index of the List.
      if (empty1) {
        lp->ll_n1 = 0;
      } else {
        // Is number or string.
        lp->ll_n1 = (long)tv_get_number(&var1);
      }
      tv_clear(&var1);

      const int bloblen = tv_blob_len(lp->ll_tv->vval.v_blob);
      if (lp->ll_n1 < 0 || lp->ll_n1 > bloblen
          || (lp->ll_range && lp->ll_n1 == bloblen)) {
        if (!quiet) {
          semsg(_(e_blobidx), (int64_t)lp->ll_n1);
        }
        tv_clear(&var2);
        return NULL;
      }
      if (lp->ll_range && !lp->ll_empty2) {
        lp->ll_n2 = (long)tv_get_number(&var2);
        tv_clear(&var2);
        if (lp->ll_n2 < 0 || lp->ll_n2 >= bloblen || lp->ll_n2 < lp->ll_n1) {
          if (!quiet) {
            semsg(_(e_blobidx), (int64_t)lp->ll_n2);
          }
          return NULL;
        }
      }
      lp->ll_blob = lp->ll_tv->vval.v_blob;
      lp->ll_tv = NULL;
      break;
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
          semsg(_(e_listidx), (int64_t)lp->ll_n1);
        }
        return NULL;
      }

      // May need to find the item or absolute index for the second
      // index of a range.
      // When no index given: "lp->ll_empty2" is true.
      // Otherwise "lp->ll_n2" is set to the second index.
      if (lp->ll_range && !lp->ll_empty2) {
        lp->ll_n2 = (long)tv_get_number(&var2);  // Is number or string.
        tv_clear(&var2);
        if (lp->ll_n2 < 0) {
          ni = tv_list_find(lp->ll_list, lp->ll_n2);
          if (ni == NULL) {
            if (!quiet) {
              semsg(_(e_listidx), (int64_t)lp->ll_n2);
            }
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
            semsg(_(e_listidx), (int64_t)lp->ll_n2);
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
static void set_var_lval(lval_T *lp, char_u *endp, typval_T *rettv, int copy, const bool is_const,
                         const char *op)
{
  int cc;
  listitem_T *ri;
  dictitem_T *di;

  if (lp->ll_tv == NULL) {
    cc = *endp;
    *endp = NUL;
    if (lp->ll_blob != NULL) {
      if (op != NULL && *op != '=') {
        semsg(_(e_letwrong), op);
        return;
      }
      if (var_check_lock(lp->ll_blob->bv_lock, lp->ll_name, TV_CSTRING)) {
        return;
      }

      if (lp->ll_range && rettv->v_type == VAR_BLOB) {
        if (lp->ll_empty2) {
          lp->ll_n2 = tv_blob_len(lp->ll_blob) - 1;
        }

        if (lp->ll_n2 - lp->ll_n1 + 1 != tv_blob_len(rettv->vval.v_blob)) {
          emsg(_("E972: Blob value does not have the right number of bytes"));
          return;
        }
        if (lp->ll_empty2) {
          lp->ll_n2 = tv_blob_len(lp->ll_blob);
        }

        for (int il = lp->ll_n1, ir = 0; il <= lp->ll_n2; il++) {
          tv_blob_set(lp->ll_blob, il, tv_blob_get(rettv->vval.v_blob, ir++));
        }
      } else {
        bool error = false;
        const char_u val = tv_get_number_chk(rettv, &error);
        if (!error) {
          garray_T *const gap = &lp->ll_blob->bv_ga;

          // Allow for appending a byte.  Setting a byte beyond
          // the end is an error otherwise.
          if (lp->ll_n1 < gap->ga_len || lp->ll_n1 == gap->ga_len) {
            ga_grow(&lp->ll_blob->bv_ga, 1);
            tv_blob_set(lp->ll_blob, lp->ll_n1, val);
            if (lp->ll_n1 == gap->ga_len) {
              gap->ga_len++;
            }
          }
          // error for invalid range was already given in get_lval()
        }
      }
    } else if (op != NULL && *op != '=') {
      typval_T tv;

      if (is_const) {
        emsg(_(e_cannot_mod));
        *endp = cc;
        return;
      }

      // handle +=, -=, *=, /=, %= and .=
      di = NULL;
      if (get_var_tv(lp->ll_name, (int)STRLEN(lp->ll_name),
                     &tv, &di, true, false) == OK) {
        if ((di == NULL
             || (!var_check_ro(di->di_flags, lp->ll_name, TV_CSTRING)
                 && !tv_check_lock(&di->di_tv, lp->ll_name, TV_CSTRING)))
            && eexe_mod_op(&tv, rettv, op) == OK) {
          set_var(lp->ll_name, lp->ll_name_len, &tv, false);
        }
        tv_clear(&tv);
      }
    } else {
      set_var_const(lp->ll_name, lp->ll_name_len, rettv, copy, is_const);
    }
    *endp = cc;
  } else if (var_check_lock(lp->ll_newkey == NULL
                            ? lp->ll_tv->v_lock
                            : lp->ll_tv->vval.v_dict->dv_lock,
                            lp->ll_name, TV_CSTRING)) {
  } else if (lp->ll_range) {
    listitem_T *ll_li = lp->ll_li;
    int ll_n1 = lp->ll_n1;

    if (is_const) {
      emsg(_("E996: Cannot lock a range"));
      return;
    }

    // Check whether any of the list items is locked
    for (ri = tv_list_first(rettv->vval.v_list);
         ri != NULL && ll_li != NULL; ) {
      if (var_check_lock(TV_LIST_ITEM_TV(ll_li)->v_lock, lp->ll_name,
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
        eexe_mod_op(TV_LIST_ITEM_TV(lp->ll_li), TV_LIST_ITEM_TV(ri), op);
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
      emsg(_("E710: List value has more items than target"));
    } else if (lp->ll_empty2
               ? (lp->ll_li != NULL
                  && TV_LIST_ITEM_NEXT(lp->ll_list, lp->ll_li) != NULL)
               : lp->ll_n1 != lp->ll_n2) {
      emsg(_("E711: List value has not enough items"));
    }
  } else {
    typval_T oldtv = TV_INITIAL_VALUE;
    dict_T *dict = lp->ll_dict;
    bool watched = tv_dict_is_watched(dict);

    if (is_const) {
      emsg(_("E996: Cannot lock a list or dict"));
      return;
    }

    // Assign to a List or Dictionary item.
    if (lp->ll_newkey != NULL) {
      if (op != NULL && *op != '=') {
        semsg(_(e_letwrong), op);
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
        eexe_mod_op(lp->ll_tv, rettv, op);
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
      lp->ll_tv->v_lock = VAR_UNLOCKED;
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
  forinfo_T *fi = xcalloc(1, sizeof(forinfo_T));
  const char_u *expr;
  typval_T tv;
  list_T *l;

  *errp = true;  // Default: there is an error.

  expr = skip_var_list(arg, &fi->fi_varcount, &fi->fi_semicolon);
  if (expr == NULL) {
    return fi;
  }

  expr = skipwhite(expr);
  if (expr[0] != 'i' || expr[1] != 'n' || !ascii_iswhite(expr[2])) {
    emsg(_("E690: Missing \"in\" after :for"));
    return fi;
  }

  if (skip) {
    ++emsg_skip;
  }
  if (eval0(skipwhite(expr + 2), &tv, nextcmdp, !skip) == OK) {
    *errp = false;
    if (!skip) {
      if (tv.v_type == VAR_LIST) {
        l = tv.vval.v_list;
        if (l == NULL) {
          // a null list is like an empty list: do nothing
          tv_clear(&tv);
        } else {
          // No need to increment the refcount, it's already set for
          // the list being used in "tv".
          fi->fi_list = l;
          tv_list_watch_add(l, &fi->fi_lw);
          fi->fi_lw.lw_item = tv_list_first(l);
        }
      } else if (tv.v_type == VAR_BLOB) {
        fi->fi_bi = 0;
        if (tv.vval.v_blob != NULL) {
          typval_T btv;

          // Make a copy, so that the iteration still works when the
          // blob is changed.
          tv_blob_copy(&tv, &btv);
          fi->fi_blob = btv.vval.v_blob;
        }
        tv_clear(&tv);
      } else {
        emsg(_(e_listblobreq));
        tv_clear(&tv);
      }
    }
  }
  if (skip) {
    --emsg_skip;
  }

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

  if (fi->fi_blob != NULL) {
    if (fi->fi_bi >= tv_blob_len(fi->fi_blob)) {
      return false;
    }
    typval_T tv;
    tv.v_type = VAR_NUMBER;
    tv.v_lock = VAR_FIXED;
    tv.vval.v_number = tv_blob_get(fi->fi_blob, fi->fi_bi);
    fi->fi_bi++;
    return ex_let_vars(arg, &tv, true,
                       fi->fi_semicolon, fi->fi_varcount, false, NULL) == OK;
  }

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
  forinfo_T *fi = (forinfo_T *)fi_void;

  if (fi != NULL && fi->fi_list != NULL) {
    tv_list_watch_remove(fi->fi_list, &fi->fi_lw);
    tv_list_unref(fi->fi_list);
  }
  if (fi != NULL && fi->fi_blob != NULL) {
    tv_blob_unref(fi->fi_blob);
  }
  xfree(fi);
}


void set_context_for_expression(expand_T *xp, char_u *arg, cmdidx_T cmdidx)
  FUNC_ATTR_NONNULL_ALL
{
  int got_eq = FALSE;
  int c;
  char_u *p;

  if (cmdidx == CMD_let || cmdidx == CMD_const) {
    xp->xp_context = EXPAND_USER_VARS;
    if (vim_strpbrk(arg, (char_u *)"\"'+-*/%.=!?~|&$([<>,#") == NULL) {
      // ":let var1 var2 ...": find last space.
      for (p = arg + STRLEN(arg); p >= arg; ) {
        xp->xp_pattern = p;
        MB_PTR_BACK(arg, p);
        if (ascii_iswhite(*p)) {
          break;
        }
      }
      return;
    }
  } else {
    xp->xp_context = cmdidx == CMD_call ? EXPAND_FUNCTIONS
                                        : EXPAND_EXPRESSION;
  }
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
        if ((c == 'l' || c == 'g') && xp->xp_pattern[2] == ':') {
          xp->xp_pattern += 2;
        }
      }
    } else if (c == '$') {
      // environment variable
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
      // Function name can start with "<SNR>" and contain '#'.
      break;
    } else if (cmdidx != CMD_let || got_eq) {
      if (c == '"') {               // string
        while ((c = *++xp->xp_pattern) != NUL && c != '"') {
          if (c == '\\' && xp->xp_pattern[1] != NUL) {
            xp->xp_pattern++;
          }
        }
        xp->xp_context = EXPAND_NOTHING;
      } else if (c == '\'') {     // literal string
        // Trick: '' is like stopping and starting a literal string.
        while ((c = *++xp->xp_pattern) != NUL && c != '\'') {
        }
        xp->xp_context = EXPAND_NOTHING;
      } else if (c == '|') {
        if (xp->xp_pattern[1] == '|') {
          ++xp->xp_pattern;
          xp->xp_context = EXPAND_EXPRESSION;
        } else {
          xp->xp_context = EXPAND_COMMANDS;
        }
      } else {
        xp->xp_context = EXPAND_EXPRESSION;
      }
    } else {
      // Doesn't look like something valid, expand as an expression
      // anyway.
      xp->xp_context = EXPAND_EXPRESSION;
    }
    arg = xp->xp_pattern;
    if (*arg != NUL) {
      while ((c = *++arg) != NUL && (c == ' ' || c == '\t')) {
      }
    }
  }

  // ":exe one two" completes "two"
  if ((cmdidx == CMD_execute
       || cmdidx == CMD_echo
       || cmdidx == CMD_echon
       || cmdidx == CMD_echomsg)
      && xp->xp_context == EXPAND_EXPRESSION) {
    for (;;) {
      char_u *const n = skiptowhite(arg);

      if (n == arg || ascii_iswhite_or_nul(*skipwhite(n))) {
        break;
      }
      arg = skipwhite(n);
    }
  }

  xp->xp_pattern = arg;
}

/// ":unlet[!] var1 ... " command.
void ex_unlet(exarg_T *eap)
{
  ex_unletlock(eap, eap->arg, 0, do_unlet_var);
}

// TODO(ZyX-I): move to eval/ex_cmds

/// ":lockvar" and ":unlockvar" commands
void ex_lockvar(exarg_T *eap)
{
  char_u *arg = eap->arg;
  int deep = 2;

  if (eap->forceit) {
    deep = -1;
  } else if (ascii_isdigit(*arg)) {
    deep = getdigits_int(&arg, false, -1);
    arg = skipwhite(arg);
  }

  ex_unletlock(eap, arg, deep, do_lock_var);
}

// TODO(ZyX-I): move to eval/ex_cmds

/// Common parsing logic for :unlet, :lockvar and :unlockvar.
///
/// Invokes `callback` afterwards if successful and `eap->skip == false`.
///
/// @param[in]  eap  Ex command arguments for the command.
/// @param[in]  argstart  Start of the string argument for the command.
/// @param[in]  deep  Levels to (un)lock for :(un)lockvar, -1 to (un)lock
///                   everything.
/// @param[in]  callback  Appropriate handler for the command.
static void ex_unletlock(exarg_T *eap, char_u *argstart, int deep, ex_unletlock_callback callback)
  FUNC_ATTR_NONNULL_ALL
{
  char_u *arg = argstart;
  char_u *name_end;
  bool error = false;
  lval_T lv;

  do {
    if (*arg == '$') {
      lv.ll_name = (const char *)arg;
      lv.ll_tv = NULL;
      arg++;
      if (get_env_len((const char_u **)&arg) == 0) {
        semsg(_(e_invarg2), arg - 1);
        return;
      }
      if (!error && !eap->skip && callback(&lv, arg, eap, deep) == FAIL) {
        error = true;
      }
      name_end = arg;
    } else {
      // Parse the name and find the end.
      name_end = get_lval(arg, NULL, &lv, true, eap->skip || error,
                          0, FNE_CHECK_START);
      if (lv.ll_name == NULL) {
        error = true;  // error, but continue parsing.
      }
      if (name_end == NULL
          || (!ascii_iswhite(*name_end) && !ends_excmd(*name_end))) {
        if (name_end != NULL) {
          emsg_severe = true;
          emsg(_(e_trailing));
        }
        if (!(eap->skip || error)) {
          clear_lval(&lv);
        }
        break;
      }

      if (!error && !eap->skip && callback(&lv, name_end, eap, deep) == FAIL) {
        error = true;
      }

      if (!eap->skip) {
        clear_lval(&lv);
      }
    }
    arg = skipwhite(name_end);
  } while (!ends_excmd(*arg));

  eap->nextcmd = check_nextcmd(arg);
}

// TODO(ZyX-I): move to eval/ex_cmds

/// Unlet a variable indicated by `lp`.
///
/// @param[in]  lp  The lvalue.
/// @param[in]  name_end  End of the string argument for the command.
/// @param[in]  eap  Ex command arguments for :unlet.
/// @param[in]  deep  Unused.
///
/// @return OK on success, or FAIL on failure.
static int do_unlet_var(lval_T *lp, char_u *name_end, exarg_T *eap, int deep FUNC_ATTR_UNUSED)
  FUNC_ATTR_NONNULL_ALL
{
  int forceit = eap->forceit;
  int ret = OK;
  int cc;

  if (lp->ll_tv == NULL) {
    cc = *name_end;
    *name_end = NUL;

    // Environment variable, normal name or expanded name.
    if (*lp->ll_name == '$') {
      os_unsetenv(lp->ll_name + 1);
    } else if (do_unlet(lp->ll_name, lp->ll_name_len, forceit) == FAIL) {
      ret = FAIL;
    }
    *name_end = cc;
  } else if ((lp->ll_list != NULL
              // ll_list is not NULL when lvalue is not in a list, NULL lists
              // yield E689.
              && var_check_lock(tv_list_locked(lp->ll_list),
                                lp->ll_name,
                                lp->ll_name_len))
             || (lp->ll_dict != NULL
                 && var_check_lock(lp->ll_dict->dv_lock,
                                   lp->ll_name,
                                   lp->ll_name_len))) {
    return FAIL;
  } else if (lp->ll_range) {
    assert(lp->ll_list != NULL);
    // Delete a range of List items.
    listitem_T *const first_li = lp->ll_li;
    listitem_T *last_li = first_li;
    for (;;) {
      listitem_T *const li = TV_LIST_ITEM_NEXT(lp->ll_list, lp->ll_li);
      if (var_check_lock(TV_LIST_ITEM_TV(lp->ll_li)->v_lock,
                         lp->ll_name,
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
/// @param[in]  forceit  If true, do not complain if variable doesn’t exist.
///
/// @return OK if it existed, FAIL otherwise.
int do_unlet(const char *const name, const size_t name_len, const bool forceit)
  FUNC_ATTR_NONNULL_ALL
{
  const char *varname;
  dict_T *dict;
  hashtab_T *ht = find_var_ht_dict(name, name_len, &varname, &dict);

  if (ht != NULL && *varname != NUL) {
    dict_T *d = get_current_funccal_dict(ht);
    if (d == NULL) {
      if (ht == &globvarht) {
        d = &globvardict;
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
    }

    hashitem_T *hi = hash_find(ht, (const char_u *)varname);
    if (HASHITEM_EMPTY(hi)) {
      hi = find_hi_in_scoped_ht(name, &ht);
    }
    if (hi != NULL && !HASHITEM_EMPTY(hi)) {
      dictitem_T *const di = TV_DICT_HI2DI(hi);
      if (var_check_fixed(di->di_flags, name, TV_CSTRING)
          || var_check_ro(di->di_flags, name, TV_CSTRING)
          || var_check_lock(d->dv_lock, name, TV_CSTRING)) {
        return FAIL;
      }

      if (var_check_lock(d->dv_lock, name, TV_CSTRING)) {
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
  if (forceit) {
    return OK;
  }
  semsg(_("E108: No such variable: \"%s\""), name);
  return FAIL;
}

// TODO(ZyX-I): move to eval/ex_cmds

/// Lock or unlock variable indicated by `lp`.
///
/// Locks if `eap->cmdidx == CMD_lockvar`, unlocks otherwise.
///
/// @param[in]  lp  The lvalue.
/// @param[in]  name_end  Unused.
/// @param[in]  eap  Ex command arguments for :(un)lockvar.
/// @param[in]  deep  Levels to (un)lock, -1 to (un)lock everything.
///
/// @return OK on success, or FAIL on failure.
static int do_lock_var(lval_T *lp, char_u *name_end FUNC_ATTR_UNUSED, exarg_T *eap, int deep)
  FUNC_ATTR_NONNULL_ARG(1, 3)
{
  bool lock = eap->cmdidx == CMD_lockvar;
  int ret = OK;

  if (deep == 0) {  // Nothing to do.
    return OK;
  }

  if (lp->ll_tv == NULL) {
    if (*lp->ll_name == '$') {
      semsg(_(e_lock_unlock), lp->ll_name);
      ret = FAIL;
    } else {
      // Normal name or expanded name.
      dictitem_T *const di = find_var(lp->ll_name, lp->ll_name_len, NULL,
                                      true);
      if (di == NULL) {
        ret = FAIL;
      } else if ((di->di_flags & DI_FLAGS_FIX)
                 && di->di_tv.v_type != VAR_DICT
                 && di->di_tv.v_type != VAR_LIST) {
        // For historical reasons this error is not given for Lists and
        // Dictionaries. E.g. b: dictionary may be locked/unlocked.
        semsg(_(e_lock_unlock), lp->ll_name);
        ret = FAIL;
      } else {
        if (lock) {
          di->di_flags |= DI_FLAGS_LOCK;
        } else {
          di->di_flags &= ~DI_FLAGS_LOCK;
        }
        tv_item_lock(&di->di_tv, deep, lock, false);
      }
    }
  } else if (lp->ll_range) {
    listitem_T *li = lp->ll_li;

    // (un)lock a range of List items.
    while (li != NULL && (lp->ll_empty2 || lp->ll_n2 >= lp->ll_n1)) {
      tv_item_lock(TV_LIST_ITEM_TV(li), deep, lock, false);
      li = TV_LIST_ITEM_NEXT(lp->ll_list, li);
      lp->ll_n1++;
    }
  } else if (lp->ll_list != NULL) {
    // (un)lock a List item.
    tv_item_lock(TV_LIST_ITEM_TV(lp->ll_li), deep, lock, false);
  } else {
    // (un)lock a Dictionary item.
    tv_item_lock(&lp->ll_di->di_tv, deep, lock, false);
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


static char_u *varnamebuf = NULL;
static size_t varnamebuflen = 0;

/*
 * Function to concatenate a prefix and a variable name.
 */
char_u *cat_prefix_varname(int prefix, const char_u *name)
  FUNC_ATTR_NONNULL_ALL
{
  size_t len = STRLEN(name) + 3;

  if (len > varnamebuflen) {
    xfree(varnamebuf);
    len += 10;                          // some additional space
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
  static hashitem_T *hi;

  if (idx == 0) {
    gdone = bdone = wdone = vidx = 0;
    tdone = 0;
  }

  // Global variables
  if (gdone < globvarht.ht_used) {
    if (gdone++ == 0) {
      hi = globvarht.ht_array;
    } else {
      ++hi;
    }
    while (HASHITEM_EMPTY(hi)) {
      ++hi;
    }
    if (STRNCMP("g:", xp->xp_pattern, 2) == 0) {
      return cat_prefix_varname('g', hi->hi_key);
    }
    return hi->hi_key;
  }

  // b: variables
  // In cmdwin, the alternative buffer should be used.
  hashtab_T *ht = (cmdwin_type != 0 && get_cmdline_type() == NUL)
    ? &prevwin->w_buffer->b_vars->dv_hashtab
    : &curbuf->b_vars->dv_hashtab;
  if (bdone < ht->ht_used) {
    if (bdone++ == 0) {
      hi = ht->ht_array;
    } else {
      ++hi;
    }
    while (HASHITEM_EMPTY(hi)) {
      ++hi;
    }
    return cat_prefix_varname('b', hi->hi_key);
  }

  // w: variables
  // In cmdwin, the alternative window should be used.
  ht = (cmdwin_type != 0 && get_cmdline_type() == NUL)
    ? &prevwin->w_vars->dv_hashtab
    : &curwin->w_vars->dv_hashtab;
  if (wdone < ht->ht_used) {
    if (wdone++ == 0) {
      hi = ht->ht_array;
    } else {
      ++hi;
    }
    while (HASHITEM_EMPTY(hi)) {
      ++hi;
    }
    return cat_prefix_varname('w', hi->hi_key);
  }

  // t: variables
  ht = &curtab->tp_vars->dv_hashtab;
  if (tdone < ht->ht_used) {
    if (tdone++ == 0) {
      hi = ht->ht_array;
    } else {
      ++hi;
    }
    while (HASHITEM_EMPTY(hi)) {
      ++hi;
    }
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
static int pattern_match(char_u *pat, char_u *text, bool ic)
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

/// Handle a name followed by "(".  Both for just "name(arg)" and for
/// "expr->name(arg)".
//
/// @param arg  Points to "(", will be advanced
/// @param basetv  "expr" for "expr->name(arg)"
//
/// @return OK or FAIL.
static int eval_func(char_u **const arg, char_u *const name, const int name_len,
                     typval_T *const rettv, const bool evaluate, typval_T *const basetv)
  FUNC_ATTR_NONNULL_ARG(1, 2, 4)
{
  char_u *s = name;
  int len = name_len;

  if (!evaluate) {
    check_vars((const char *)s, len);
  }

  // If "s" is the name of a variable of type VAR_FUNC
  // use its contents.
  partial_T *partial;
  s = deref_func_name((const char *)s, &len, &partial, !evaluate);

  // Need to make a copy, in case evaluating the arguments makes
  // the name invalid.
  s = xmemdupz(s, len);

  // Invoke the function.
  funcexe_T funcexe = FUNCEXE_INIT;
  funcexe.firstline = curwin->w_cursor.lnum;
  funcexe.lastline = curwin->w_cursor.lnum;
  funcexe.evaluate = evaluate;
  funcexe.partial = partial;
  funcexe.basetv = basetv;
  int ret = get_func_tv(s, len, rettv, arg, &funcexe);

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
  return ret;
}

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
  char_u *p;
  const int did_emsg_before = did_emsg;
  const int called_emsg_before = called_emsg;

  p = skipwhite(arg);
  ret = eval1(&p, rettv, evaluate);
  if (ret == FAIL || !ends_excmd(*p)) {
    if (ret != FAIL) {
      tv_clear(rettv);
    }
    // Report the invalid expression unless the expression evaluation has
    // been cancelled due to an aborting error, an interrupt, or an
    // exception, or we already gave a more specific error.
    // Also check called_emsg for when using assert_fails().
    if (!aborting() && did_emsg == did_emsg_before
        && called_emsg == called_emsg_before) {
      semsg(_(e_invexpr2), arg);
    }
    ret = FAIL;
  }
  if (nextcmd != NULL) {
    *nextcmd = check_nextcmd(p);
  }

  return ret;
}

// TODO(ZyX-I): move to eval/expressions

/*
 * Handle top level expression:
 *      expr2 ? expr1 : expr1
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
  if (eval2(arg, rettv, evaluate) == FAIL) {
    return FAIL;
  }

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
    if (eval1(arg, rettv, evaluate && result) == FAIL) {  // recursive!
      return FAIL;
    }

    /*
     * Check for the ":".
     */
    if ((*arg)[0] != ':') {
      emsg(_("E109: Missing ':' after '?'"));
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
    if (evaluate && !result) {
      *rettv = var2;
    }
  }

  return OK;
}

// TODO(ZyX-I): move to eval/expressions

/*
 * Handle first level expression:
 *      expr2 || expr2 || expr2     logical OR
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
  if (eval3(arg, rettv, evaluate) == FAIL) {
    return FAIL;
  }

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
    if (eval3(arg, &var2, evaluate && !result) == FAIL) {
      return FAIL;
    }

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
 *      expr3 && expr3 && expr3     logical AND
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
  if (eval4(arg, rettv, evaluate) == FAIL) {
    return FAIL;
  }

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
    if (eval4(arg, &var2, evaluate && result) == FAIL) {
      return FAIL;
    }

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
 *      var1 == var2
 *      var1 =~ var2
 *      var1 != var2
 *      var1 !~ var2
 *      var1 > var2
 *      var1 >= var2
 *      var1 < var2
 *      var1 <= var2
 *      var1 is var2
 *      var1 isnot var2
 *
 * "arg" must point to the first non-white of the expression.
 * "arg" is advanced to the next non-white after the recognized expression.
 *
 * Return OK or FAIL.
 */
static int eval4(char_u **arg, typval_T *rettv, int evaluate)
{
  typval_T var2;
  char_u *p;
  exprtype_T type = EXPR_UNKNOWN;
  int len = 2;
  bool ic;

  /*
   * Get the first variable.
   */
  if (eval5(arg, rettv, evaluate) == FAIL) {
    return FAIL;
  }

  p = *arg;
  switch (p[0]) {
  case '=':
    if (p[1] == '=') {
      type = EXPR_EQUAL;
    } else if (p[1] == '~') {
      type = EXPR_MATCH;
    }
    break;
  case '!':
    if (p[1] == '=') {
      type = EXPR_NEQUAL;
    } else if (p[1] == '~') {
      type = EXPR_NOMATCH;
    }
    break;
  case '>':
    if (p[1] != '=') {
      type = EXPR_GREATER;
      len = 1;
    } else {
      type = EXPR_GEQUAL;
    }
    break;
  case '<':
    if (p[1] != '=') {
      type = EXPR_SMALLER;
      len = 1;
    } else {
      type = EXPR_SEQUAL;
    }
    break;
  case 'i':
    if (p[1] == 's') {
      if (p[2] == 'n' && p[3] == 'o' && p[4] == 't') {
        len = 5;
      }
      if (!isalnum(p[len]) && p[len] != '_') {
        type = len == 2 ? EXPR_IS : EXPR_ISNOT;
      }
    }
    break;
  }

  /*
   * If there is a comparative operator, use it.
   */
  if (type != EXPR_UNKNOWN) {
    // extra question mark appended: ignore case
    if (p[len] == '?') {
      ic = true;
      len++;
    } else if (p[len] == '#') {  // extra '#' appended: match case
      ic = false;
      len++;
    } else {  // nothing appended: use 'ignorecase'
      ic = p_ic;
    }

    // Get the second variable.
    *arg = skipwhite(p + len);
    if (eval5(arg, &var2, evaluate) == FAIL) {
      tv_clear(rettv);
      return FAIL;
    }
    if (evaluate) {
      const int ret = typval_compare(rettv, &var2, type, ic);

      tv_clear(&var2);
      return ret;
    }
  }

  return OK;
}

// TODO(ZyX-I): move to eval/expressions

/*
 * Handle fourth level expression:
 *      +       number addition
 *      -       number subtraction
 *      .       string concatenation
 *      ..      string concatenation
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
  char_u *p;

  /*
   * Get the first variable.
   */
  if (eval6(arg, rettv, evaluate, FALSE) == FAIL) {
    return FAIL;
  }

  /*
   * Repeat computing, until no '+', '-' or '.' is following.
   */
  for (;; ) {
    op = **arg;
    if (op != '+' && op != '-' && op != '.') {
      break;
    }

    if ((op != '+' || (rettv->v_type != VAR_LIST && rettv->v_type != VAR_BLOB))
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
      } else if (op == '+' && rettv->v_type == VAR_BLOB
                 && var2.v_type == VAR_BLOB) {
        const blob_T *const b1 = rettv->vval.v_blob;
        const blob_T *const b2 = var2.vval.v_blob;
        blob_T *const b = tv_blob_alloc();

        for (int i = 0; i < tv_blob_len(b1); i++) {
          ga_append(&b->bv_ga, tv_blob_get(b1, i));
        }
        for (int i = 0; i < tv_blob_len(b2); i++) {
          ga_append(&b->bv_ga, tv_blob_get(b2, i));
        }

        tv_clear(rettv);
        tv_blob_set_ret(rettv, b);
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
            // This can only happen for "list + non-list" or
            // "blob + non-blob".  For "non-list + ..." or
            // "something - ...", we returned before evaluating the
            // 2nd operand.
            tv_clear(rettv);
            tv_clear(&var2);
            return FAIL;
          }
          if (var2.v_type == VAR_FLOAT) {
            f1 = n1;
          }
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
          if (rettv->v_type == VAR_FLOAT) {
            f2 = n2;
          }
        }
        tv_clear(rettv);

        // If there is a float on either side the result is a float.
        if (rettv->v_type == VAR_FLOAT || var2.v_type == VAR_FLOAT) {
          if (op == '+') {
            f1 = f1 + f2;
          } else {
            f1 = f1 - f2;
          }
          rettv->v_type = VAR_FLOAT;
          rettv->vval.v_float = f1;
        } else {
          if (op == '+') {
            n1 = n1 + n2;
          } else {
            n1 = n1 - n2;
          }
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
  if (eval7(arg, rettv, evaluate, want_string) == FAIL) {
    return FAIL;
  }

  /*
   * Repeat computing, until no '*', '/' or '%' is following.
   */
  for (;; ) {
    op = **arg;
    if (op != '*' && op != '/' && op != '%') {
      break;
    }

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
    if (eval7(arg, &var2, evaluate, FALSE) == FAIL) {
      return FAIL;
    }

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
          emsg(_("E804: Cannot use '%' with Float"));
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

/// Handle sixth level expression:
///  number  number constant
///  0zFFFFFFFF  Blob constant
///  "string"  string constant
///  'string'  literal string constant
///  &option-name option value
///  @r   register contents
///  identifier  variable value
///  function()  function call
///  $VAR  environment variable
///  (expression) nested expression
///  [expr, expr] List
///  {key: val, key: val}  Dictionary
///  #{key: val, key: val}  Dictionary with literal keys
///
///  Also handle:
///  ! in front  logical NOT
///  - in front  unary minus
///  + in front  unary plus (ignored)
///  trailing []  subscript in String or List
///  trailing .name entry in Dictionary
///  trailing ->name()  method call
///
/// "arg" must point to the first non-white of the expression.
/// "arg" is advanced to the next non-white after the recognized expression.
///
/// @param want_string  after "." operator
///
/// @return  OK or FAIL.
static int eval7(char_u **arg, typval_T *rettv, int evaluate, int want_string)
{
  varnumber_T n;
  int len;
  char_u *s;
  const char_u *start_leader, *end_leader;
  int ret = OK;
  char_u *alias;

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
  case '9': {
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

      *arg += string2float((char *)*arg, &f);
      if (evaluate) {
        rettv->v_type = VAR_FLOAT;
        rettv->vval.v_float = f;
      }
    } else if (**arg == '0' && ((*arg)[1] == 'z' || (*arg)[1] == 'Z')) {
      blob_T *blob = NULL;
      // Blob constant: 0z0123456789abcdef
      if (evaluate) {
        blob = tv_blob_alloc();
      }
      char_u *bp;
      for (bp = *arg + 2; ascii_isxdigit(bp[0]); bp += 2) {
        if (!ascii_isxdigit(bp[1])) {
          if (blob != NULL) {
            emsg(_("E973: Blob literal should have an even number of hex "
                   "characters"));
            ga_clear(&blob->bv_ga);
            XFREE_CLEAR(blob);
          }
          ret = FAIL;
          break;
        }
        if (blob != NULL) {
          ga_append(&blob->bv_ga, (hex2nr(*bp) << 4) + hex2nr(*(bp + 1)));
        }
        if (bp[2] == '.' && ascii_isxdigit(bp[3])) {
          bp++;
        }
      }
      if (blob != NULL) {
        tv_blob_set_ret(rettv, blob);
      }
      *arg = bp;
    } else {
      // decimal, hex or octal number
      vim_str2nr(*arg, NULL, &len, STR2NR_ALL, &n, NULL, 0, true);
      if (len == 0) {
        semsg(_(e_invexpr2), *arg);
        ret = FAIL;
        break;
      }
      *arg += len;
      if (evaluate) {
        rettv->v_type = VAR_NUMBER;
        rettv->vval.v_number = n;
      }
    }
    break;
  }

  // String constant: "string".
  case '"':
    ret = get_string_tv(arg, rettv, evaluate);
    break;

  // Literal string constant: 'str''ing'.
  case '\'':
    ret = get_lit_string_tv(arg, rettv, evaluate);
    break;

  // List: [expr, expr]
  case '[':
    ret = get_list_tv(arg, rettv, evaluate);
    break;

  // Dictionary: #{key: val, key: val}
  case '#':
    if ((*arg)[1] == '{') {
      (*arg)++;
      ret = dict_get_tv(arg, rettv, evaluate, true);
    } else {
      ret = NOTDONE;
    }
    break;

  // Lambda: {arg, arg -> expr}
  // Dictionary: {'key': val, 'key': val}
  case '{':
    ret = get_lambda_tv(arg, rettv, evaluate);
    if (ret == NOTDONE) {
      ret = dict_get_tv(arg, rettv, evaluate, false);
    }
    break;

  // Option value: &name
  case '&':
    ret = get_option_tv((const char **)arg, rettv, evaluate);
    break;
  // Environment variable: $VAR.
  case '$':
    ret = get_env_tv(arg, rettv, evaluate);
    break;

  // Register contents: @r.
  case '@':
    ++*arg;
    if (evaluate) {
      rettv->v_type = VAR_STRING;
      rettv->vval.v_string = get_reg_contents(**arg, kGRegExprSrc);
    }
    if (**arg != NUL) {
      ++*arg;
    }
    break;

  // nested expression: (expression).
  case '(':
    *arg = skipwhite(*arg + 1);
    ret = eval1(arg, rettv, evaluate);                  // recursive!
    if (**arg == ')') {
      ++*arg;
    } else if (ret == OK) {
      emsg(_("E110: Missing ')'"));
      tv_clear(rettv);
      ret = FAIL;
    }
    break;

  default:
    ret = NOTDONE;
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
        ret = eval_func(arg, s, len, rettv, evaluate, NULL);
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
  // expr(expr), expr->name(expr)
  if (ret == OK) {
    ret = handle_subscript((const char **)arg, rettv, evaluate, true,
                           start_leader, &end_leader);
  }

  // Apply logical NOT and unary '-', from right to left, ignore '+'.
  if (ret == OK && evaluate && end_leader > start_leader) {
    ret = eval7_leader(rettv, start_leader, &end_leader);
  }
  return ret;
}

/// Apply the leading "!" and "-" before an eval7 expression to "rettv".
/// Adjusts "end_leaderp" until it is at "start_leader".
/// @return OK on success, FAIL on failure.
static int eval7_leader(typval_T *const rettv, const char_u *const start_leader,
                        const char_u **const end_leaderp)
  FUNC_ATTR_NONNULL_ALL
{
  const char_u *end_leader = *end_leaderp;
  int ret = OK;
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
      end_leader--;
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

  *end_leaderp = end_leader;
  return ret;
}

/// Call the function referred to in "rettv".
/// @param lua_funcname  If `rettv` refers to a v:lua function, this must point
///                      to the name of the Lua function to call (after the
///                      "v:lua." prefix).
/// @return OK on success, FAIL on failure.
static int call_func_rettv(char_u **const arg, typval_T *const rettv, const bool evaluate,
                           dict_T *const selfdict, typval_T *const basetv,
                           const char_u *const lua_funcname)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  partial_T *pt = NULL;
  typval_T functv;
  const char_u *funcname;
  bool is_lua = false;

  // need to copy the funcref so that we can clear rettv
  if (evaluate) {
    functv = *rettv;
    rettv->v_type = VAR_UNKNOWN;

    // Invoke the function.  Recursive!
    if (functv.v_type == VAR_PARTIAL) {
      pt = functv.vval.v_partial;
      is_lua = is_luafunc(pt);
      funcname = is_lua ? lua_funcname : partial_name(pt);
    } else {
      funcname = functv.vval.v_string;
    }
  } else {
    funcname = (char_u *)"";
  }

  funcexe_T funcexe = FUNCEXE_INIT;
  funcexe.firstline = curwin->w_cursor.lnum;
  funcexe.lastline = curwin->w_cursor.lnum;
  funcexe.evaluate = evaluate;
  funcexe.partial = pt;
  funcexe.selfdict = selfdict;
  funcexe.basetv = basetv;
  const int ret = get_func_tv(funcname, is_lua ? *arg - funcname : -1, rettv,
                              arg, &funcexe);

  // Clear the funcref afterwards, so that deleting it while
  // evaluating the arguments is possible (see test55).
  if (evaluate) {
    tv_clear(&functv);
  }

  return ret;
}

/// Evaluate "->method()".
/// @param verbose  if true, give error messages.
/// @note "*arg" points to the '-'.
/// @return FAIL or OK. @note "*arg" is advanced to after the ')'.
static int eval_lambda(char_u **const arg, typval_T *const rettv, const bool evaluate,
                       const bool verbose)
  FUNC_ATTR_NONNULL_ALL
{
  // Skip over the ->.
  *arg += 2;
  typval_T base = *rettv;
  rettv->v_type = VAR_UNKNOWN;

  int ret = get_lambda_tv(arg, rettv, evaluate);
  if (ret == NOTDONE) {
    return FAIL;
  } else if (**arg != '(') {
    if (verbose) {
      if (*skipwhite(*arg) == '(') {
        emsg(_(e_nowhitespace));
      } else {
        semsg(_(e_missingparen), "lambda");
      }
    }
    tv_clear(rettv);
    ret = FAIL;
  } else {
    ret = call_func_rettv(arg, rettv, evaluate, NULL, &base, NULL);
  }

  // Clear the funcref afterwards, so that deleting it while
  // evaluating the arguments is possible (see test55).
  if (evaluate) {
    tv_clear(&base);
  }

  return ret;
}

/// Evaluate "->method()" or "->v:lua.method()".
/// @note "*arg" points to the '-'.
/// @return FAIL or OK. "*arg" is advanced to after the ')'.
static int eval_method(char_u **const arg, typval_T *const rettv, const bool evaluate,
                       const bool verbose)
  FUNC_ATTR_NONNULL_ALL
{
  // Skip over the ->.
  *arg += 2;
  typval_T base = *rettv;
  rettv->v_type = VAR_UNKNOWN;

  // Locate the method name.
  int len;
  char_u *name = *arg;
  char_u *lua_funcname = NULL;
  if (STRNCMP(name, "v:lua.", 6) == 0) {
    lua_funcname = name + 6;
    *arg = (char_u *)skip_luafunc_name((const char *)lua_funcname);
    *arg = skipwhite(*arg);  // to detect trailing whitespace later
    len = *arg - lua_funcname;
  } else {
    char_u *alias;
    len = get_name_len((const char **)arg, (char **)&alias, evaluate, true);
    if (alias != NULL) {
      name = alias;
    }
  }

  int ret;
  if (len <= 0) {
    if (verbose) {
      if (lua_funcname == NULL) {
        emsg(_("E260: Missing name after ->"));
      } else {
        semsg(_(e_invexpr2), name);
      }
    }
    ret = FAIL;
  } else {
    if (**arg != '(') {
      if (verbose) {
        semsg(_(e_missingparen), name);
      }
      ret = FAIL;
    } else if (ascii_iswhite((*arg)[-1])) {
      if (verbose) {
        emsg(_(e_nowhitespace));
      }
      ret = FAIL;
    } else if (lua_funcname != NULL) {
      if (evaluate) {
        rettv->v_type = VAR_PARTIAL;
        rettv->vval.v_partial = vvlua_partial;
        rettv->vval.v_partial->pt_refcount++;
      }
      ret = call_func_rettv(arg, rettv, evaluate, NULL, &base, lua_funcname);
    } else {
      ret = eval_func(arg, name, len, rettv, evaluate, &base);
    }
  }

  // Clear the funcref afterwards, so that deleting it while
  // evaluating the arguments is possible (see test55).
  if (evaluate) {
    tv_clear(&base);
  }

  return ret;
}

// TODO(ZyX-I): move to eval/expressions

/// Evaluate an "[expr]" or "[expr:expr]" index.  Also "dict.key".
/// "*arg" points to the '[' or '.'.
/// Returns FAIL or OK. "*arg" is advanced to after the ']'.
///
/// @param verbose  give error messages
static int eval_index(char_u **arg, typval_T *rettv, int evaluate, int verbose)
{
  bool empty1 = false;
  bool empty2 = false;
  long n1, n2 = 0;
  ptrdiff_t len = -1;
  int range = false;
  char_u *key = NULL;

  switch (rettv->v_type) {
  case VAR_FUNC:
  case VAR_PARTIAL:
    if (verbose) {
      emsg(_("E695: Cannot index a Funcref"));
    }
    return FAIL;
  case VAR_FLOAT:
    if (verbose) {
      emsg(_(e_float_as_string));
    }
    return FAIL;
  case VAR_BOOL:
  case VAR_SPECIAL:
    if (verbose) {
      emsg(_("E909: Cannot index a special variable"));
    }
    return FAIL;
  case VAR_UNKNOWN:
    if (evaluate) {
      return FAIL;
    }
    FALLTHROUGH;
  case VAR_STRING:
  case VAR_NUMBER:
  case VAR_LIST:
  case VAR_DICT:
  case VAR_BLOB:
    break;
  }

  typval_T var1 = TV_INITIAL_VALUE;
  typval_T var2 = TV_INITIAL_VALUE;
  if (**arg == '.') {
    /*
     * dict.name
     */
    key = *arg + 1;
    for (len = 0; ASCII_ISALNUM(key[len]) || key[len] == '_'; ++len) {
    }
    if (len == 0) {
      return FAIL;
    }
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

    // Check for the ']'.
    if (**arg != ']') {
      if (verbose) {
        emsg(_(e_missbrac));
      }
      tv_clear(&var1);
      if (range) {
        tv_clear(&var2);
      }
      return FAIL;
    }
    *arg = skipwhite(*arg + 1);         // skip the ']'
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
    case VAR_BLOB:
      len = tv_blob_len(rettv->vval.v_blob);
      if (range) {
        // The resulting variable is a sub-blob.  If the indexes
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
          n2 = len - 1;
        }
        if (n1 >= len || n2 < 0 || n1 > n2) {
          tv_clear(rettv);
          rettv->v_type = VAR_BLOB;
          rettv->vval.v_blob = NULL;
        } else {
          blob_T *const blob = tv_blob_alloc();
          ga_grow(&blob->bv_ga, n2 - n1 + 1);
          blob->bv_ga.ga_len = n2 - n1 + 1;
          for (long i = n1; i <= n2; i++) {
            tv_blob_set(blob, i - n1, tv_blob_get(rettv->vval.v_blob, i));
          }
          tv_clear(rettv);
          tv_blob_set_ret(rettv, blob);
        }
      } else {
        // The resulting variable is a byte value.
        // If the index is too big or negative that is an error.
        if (n1 < 0) {
          n1 = len + n1;
        }
        if (n1 < len && n1 >= 0) {
          const int v = (int)tv_blob_get(rettv->vval.v_blob, n1);
          tv_clear(rettv);
          rettv->v_type = VAR_NUMBER;
          rettv->vval.v_number = v;
        } else {
          semsg(_(e_blobidx), (int64_t)n1);
        }
      }
      break;
    case VAR_LIST:
      len = tv_list_len(rettv->vval.v_list);
      if (n1 < 0) {
        n1 = len + n1;
      }
      if (!empty1 && (n1 < 0 || n1 >= len)) {
        // For a range we allow invalid values and return an empty
        // list.  A list index out of range is an error.
        if (!range) {
          if (verbose) {
            semsg(_(e_listidx), (int64_t)n1);
          }
          return FAIL;
        }
        n1 = len;
      }
      if (range) {
        list_T *l;
        listitem_T *item;

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
    case VAR_DICT: {
      if (range) {
        if (verbose) {
          emsg(_(e_dictrange));
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
        semsg(_(e_dictkey), key);
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
    case VAR_BOOL:
    case VAR_SPECIAL:
    case VAR_FUNC:
    case VAR_FLOAT:
    case VAR_PARTIAL:
    case VAR_UNKNOWN:
      break;  // Not evaluating, skipping over subscript
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
int get_option_tv(const char **const arg, typval_T *const rettv, const bool evaluate)
  FUNC_ATTR_NONNULL_ARG(1)
{
  long numval;
  char_u *stringval;
  int opt_type;
  int c;
  bool working = (**arg == '+');  // has("+option")
  int ret = OK;
  int opt_flags;

  // Isolate the option name and find its value.
  char *option_end = (char *)find_option_end(arg, &opt_flags);
  if (option_end == NULL) {
    if (rettv != NULL) {
      semsg(_("E112: Option name missing: %s"), *arg);
    }
    return FAIL;
  }

  if (!evaluate) {
    *arg = option_end;
    return OK;
  }

  c = *option_end;
  *option_end = NUL;
  opt_type = get_option_value(*arg, &numval,
                              rettv == NULL ? NULL : &stringval, opt_flags);

  if (opt_type == -3) {                 // invalid name
    if (rettv != NULL) {
      semsg(_("E113: Unknown option: %s"), *arg);
    }
    ret = FAIL;
  } else if (rettv != NULL) {
    if (opt_type == -2) {               // hidden string option
      rettv->v_type = VAR_STRING;
      rettv->vval.v_string = NULL;
    } else if (opt_type == -1) {      // hidden number option
      rettv->v_type = VAR_NUMBER;
      rettv->vval.v_number = 0;
    } else if (opt_type == 1) {       // number option
      rettv->v_type = VAR_NUMBER;
      rettv->vval.v_number = numval;
    } else {                          // string option
      rettv->v_type = VAR_STRING;
      rettv->vval.v_string = stringval;
    }
  } else if (working && (opt_type == -2 || opt_type == -1)) {
    ret = FAIL;
  }

  *option_end = c;                  // put back for error messages
  *arg = option_end;

  return ret;
}

/*
 * Allocate a variable for a string constant.
 * Return OK or FAIL.
 */
static int get_string_tv(char_u **arg, typval_T *rettv, int evaluate)
{
  char_u *p;
  unsigned int extra = 0;

  /*
   * Find the end of the string, skipping backslashed characters.
   */
  for (p = *arg + 1; *p != NUL && *p != '"'; MB_PTR_ADV(p)) {
    if (*p == '\\' && p[1] != NUL) {
      p++;
      // A "\<x>" form occupies at least 4 characters, and produces up
      // to 21 characters (3 * 6 for the char and 3 for a modifier):
      // reserve space for 18 extra.
      // Each byte in the char could be encoded as K_SPECIAL K_EXTRA x.
      if (*p == '<') {
        extra += 18;
      }
    }
  }

  if (*p != '"') {
    semsg(_("E114: Missing quote: %s"), *arg);
    return FAIL;
  }

  // If only parsing, set *arg and return here
  if (!evaluate) {
    *arg = p + 1;
    return OK;
  }

  /*
   * Copy the string into allocated memory, handling backslashed
   * characters.
   */
  const int len = (int)(p - *arg + extra);
  char_u *name = xmalloc(len);
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = name;

  for (p = *arg + 1; *p != NUL && *p != '"'; ) {
    if (*p == '\\') {
      switch (*++p) {
      case 'b':
        *name++ = BS; ++p; break;
      case 'e':
        *name++ = ESC; ++p; break;
      case 'f':
        *name++ = FF; ++p; break;
      case 'n':
        *name++ = NL; ++p; break;
      case 'r':
        *name++ = CAR; ++p; break;
      case 't':
        *name++ = TAB; ++p; break;

      case 'X':           // hex: "\x1", "\x12"
      case 'x':
      case 'u':           // Unicode: "\u0023"
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
          p++;
          // For "\u" store the number according to
          // 'encoding'.
          if (c != 'X') {
            name += utf_char2bytes(nr, name);
          } else {
            *name++ = nr;
          }
        }
        break;

      // octal: "\1", "\12", "\123"
      case '0':
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
        *name = *p++ - '0';
        if (*p >= '0' && *p <= '7') {
          *name = (*name << 3) + *p++ - '0';
          if (*p >= '0' && *p <= '7') {
            *name = (*name << 3) + *p++ - '0';
          }
        }
        ++name;
        break;

      // Special key, e.g.: "\<C-W>"
      case '<':
        extra = trans_special((const char_u **)&p, STRLEN(p), name, true, true);
        if (extra != 0) {
          name += extra;
          if (name >= rettv->vval.v_string + len) {
            iemsg("get_string_tv() used more space than allocated");
          }
          break;
        }
        FALLTHROUGH;

      default:
        MB_COPY_CHAR(p, name);
        break;
      }
    } else {
      MB_COPY_CHAR(p, name);
    }
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
  char_u *p;
  char_u *str;
  int reduce = 0;

  /*
   * Find the end of the string, skipping ''.
   */
  for (p = *arg + 1; *p != NUL; MB_PTR_ADV(p)) {
    if (*p == '\'') {
      if (p[1] != '\'') {
        break;
      }
      ++reduce;
      ++p;
    }
  }

  if (*p != '\'') {
    semsg(_("E115: Missing quote: %s"), *arg);
    return FAIL;
  }

  // If only parsing return after setting "*arg"
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
      if (p[1] != '\'') {
        break;
      }
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
  list_T *l = NULL;

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
      semsg(_("E696: Missing comma in List: %s"), *arg);
      goto failret;
    }
    *arg = skipwhite(*arg + 1);
  }

  if (**arg != ']') {
    semsg(_("E697: Missing end of List ']': %s"), *arg);
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

/// @param ic  ignore case
bool func_equal(typval_T *tv1, typval_T *tv2, bool ic)
{
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

/*
 * Garbage collection for lists and dictionaries.
 *
 * We use reference counts to be able to free most items right away when they
 * are no longer used.  But for composite items it's possible that it becomes
 * unused while the reference count is > 0: When there is a recursive
 * reference.  Example:
 *      :let l = [1, 2, 3]
 *      :let d = {9: l}
 *      :let l[1] = d
 *
 * Since this is quite unusual we handle this with garbage collection: every
 * once in a while find out which lists and dicts are not referenced from any
 * variable.
 *
 * Here is a good reference text about garbage collection (refers to Python
 * but it applies to all reference-counting mechanisms):
 *      http://python.ca/nas/python/gc/
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
  ABORTING(set_ref_in_previous_funccal)(copyID);

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
  ABORTING(set_ref_in_call_stack)(copyID);

  // named functions (matters for closures)
  ABORTING(set_ref_in_functions)(copyID);

  // Channels
  {
    Channel *data;
    map_foreach_value(&channels, data, {
      set_ref_in_callback_reader(&data->on_data, copyID, NULL, NULL);
      set_ref_in_callback_reader(&data->on_stderr, copyID, NULL, NULL);
      set_ref_in_callback(&data->on_exit, copyID, NULL, NULL);
    })
  }

  // Timers
  {
    timer_T *timer;
    map_foreach_value(&timers, timer, {
      set_ref_in_callback(&timer->callback, copyID, NULL, NULL);
    })
  }

  // function call arguments, if v:testing is set.
  ABORTING(set_ref_in_func_args)(copyID);

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
    //    This may call us back recursively.
    did_free = free_unref_funccal(copyID, testing) || did_free;
  } else if (p_verbose > 0) {
    verb_msg(_("Not enough memory to set references, garbage collection aborted!"));
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
        abort = abort || set_ref_in_item(&TV_DICT_HI2DI(hi)->di_tv, copyID, &ht_stack, list_stack);
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
bool set_ref_in_item(typval_T *tv, int copyID, ht_stack_T **ht_stack, list_stack_T **list_stack)
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
        ht_stack_T *const newitem = xmalloc(sizeof(ht_stack_T));
        newitem->ht = &dd->dv_hashtab;
        newitem->prev = *ht_stack;
        *ht_stack = newitem;
      }

      QUEUE *w = NULL;
      DictWatcher *watcher = NULL;
      QUEUE_FOREACH(w, &dd->watchers, {
          watcher = tv_dict_watcher_node_data(w);
          set_ref_in_callback(&watcher->callback, copyID, ht_stack, list_stack);
        })
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
        list_stack_T *const newitem = xmalloc(sizeof(list_stack_T));
        newitem->list = ll;
        newitem->prev = *list_stack;
        *list_stack = newitem;
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
  case VAR_BOOL:
  case VAR_SPECIAL:
  case VAR_FLOAT:
  case VAR_NUMBER:
  case VAR_STRING:
  case VAR_BLOB:
    break;
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


// Get the key for *{key: val} into "tv" and advance "arg".
// Return FAIL when there is no valid key.
static int get_literal_key(char_u **arg, typval_T *tv)
  FUNC_ATTR_NONNULL_ALL
{
  char_u *p;

  if (!ASCII_ISALNUM(**arg) && **arg != '_' && **arg != '-') {
    return FAIL;
  }
  for (p = *arg; ASCII_ISALNUM(*p) || *p == '_' || *p == '-'; p++) {
  }
  tv->v_type = VAR_STRING;
  tv->vval.v_string = vim_strnsave(*arg, p - *arg);

  *arg = skipwhite(p);
  return OK;
}

// Allocate a variable for a Dictionary and fill it from "*arg".
// "literal" is true for *{key: val}
// Return OK or FAIL.  Returns NOTDONE for {expr}.
static int dict_get_tv(char_u **arg, typval_T *rettv, int evaluate, bool literal)
{
  dict_T *d = NULL;
  typval_T tvkey;
  typval_T tv;
  char_u *key = NULL;
  dictitem_T *item;
  char_u *start = skipwhite(*arg + 1);
  char buf[NUMBUFLEN];

  /*
   * First check if it's not a curly-braces thing: {expr}.
   * Must do this without evaluating, otherwise a function may be called
   * twice.  Unfortunately this means we need to call eval1() twice for the
   * first item.
   * But {} is an empty Dictionary.
   */
  if (*start != '}') {
    if (eval1(&start, &tv, false) == FAIL) {    // recursive!
      return FAIL;
    }
    if (*skipwhite(start) == '}') {
      return NOTDONE;
    }
  }

  if (evaluate) {
    d = tv_dict_alloc();
  }
  tvkey.v_type = VAR_UNKNOWN;
  tv.v_type = VAR_UNKNOWN;

  *arg = skipwhite(*arg + 1);
  while (**arg != '}' && **arg != NUL) {
    if ((literal
         ? get_literal_key(arg, &tvkey)
         : eval1(arg, &tvkey, evaluate)) == FAIL) {  // recursive!
      goto failret;
    }
    if (**arg != ':') {
      semsg(_("E720: Missing colon in Dictionary: %s"), *arg);
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
        semsg(_("E721: Duplicate key in Dictionary: \"%s\""), key);
        tv_clear(&tvkey);
        tv_clear(&tv);
        goto failret;
      }
      item = tv_dict_item_alloc((const char *)key);
      item->di_tv = tv;
      item->di_tv.v_lock = VAR_UNLOCKED;
      if (tv_dict_add(d, item) == FAIL) {
        tv_dict_item_free(item);
      }
    }
    tv_clear(&tvkey);

    if (**arg == '}') {
      break;
    }
    if (**arg != ',') {
      semsg(_("E722: Missing comma in Dictionary: %s"), *arg);
      goto failret;
    }
    *arg = skipwhite(*arg + 1);
  }

  if (**arg != '}') {
    semsg(_("E723: Missing end of Dictionary '}': %s"), *arg);
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
  return (size_t)(s - text);
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
  int len;
  int cc;

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

/// Get the argument list for a given window
void get_arglist_as_rettv(aentry_T *arglist, int argcount, typval_T *rettv)
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
    ga_concat(gap, (char *)sourcing_name);
    if (sourcing_lnum > 0) {
      ga_concat(gap, " ");
    }
  }
  if (sourcing_lnum > 0) {
    vim_snprintf(buf, ARRAY_SIZE(buf), "line %" PRId64, (int64_t)sourcing_lnum);
    ga_concat(gap, buf);
  }
  if (sourcing_name != NULL || sourcing_lnum > 0) {
    ga_concat(gap, ": ");
  }
}

// Append "p[clen]" to "gap", escaping unprintable characters.
// Changes NL to \n, CR to \r, etc.
static void ga_concat_esc(garray_T *gap, const char_u *p, int clen)
  FUNC_ATTR_NONNULL_ALL
{
  char_u buf[NUMBUFLEN];

  if (clen > 1) {
    memmove(buf, p, clen);
    buf[clen] = NUL;
    ga_concat(gap, (char *)buf);
  } else {
    switch (*p) {
    case BS:
      ga_concat(gap, "\\b"); break;
    case ESC:
      ga_concat(gap, "\\e"); break;
    case FF:
      ga_concat(gap, "\\f"); break;
    case NL:
      ga_concat(gap, "\\n"); break;
    case TAB:
      ga_concat(gap, "\\t"); break;
    case CAR:
      ga_concat(gap, "\\r"); break;
    case '\\':
      ga_concat(gap, "\\\\"); break;
    default:
      if (*p < ' ') {
        vim_snprintf((char *)buf, NUMBUFLEN, "\\x%02x", *p);
        ga_concat(gap, (char *)buf);
      } else {
        ga_append(gap, *p);
      }
      break;
    }
  }
}

// Append "str" to "gap", escaping unprintable characters.
// Changes NL to \n, CR to \r, etc.
static void ga_concat_shorten_esc(garray_T *gap, const char_u *str)
  FUNC_ATTR_NONNULL_ARG(1)
{
  char_u buf[NUMBUFLEN];

  if (str == NULL) {
    ga_concat(gap, "NULL");
    return;
  }

  for (const char_u *p = str; *p != NUL; p++) {
    int same_len = 1;
    const char_u *s = p;
    const int c = mb_ptr2char_adv(&s);
    const int clen = s - p;
    while (*s != NUL && c == utf_ptr2char(s)) {
      same_len++;
      s += clen;
    }
    if (same_len > 20) {
      ga_concat(gap, "\\[");
      ga_concat_esc(gap, p, clen);
      ga_concat(gap, " occurs ");
      vim_snprintf((char *)buf, NUMBUFLEN, "%d", same_len);
      ga_concat(gap, (char *)buf);
      ga_concat(gap, " times]");
      p = s - 1;
    } else {
      ga_concat_esc(gap, p, clen);
    }
  }
}

// Fill "gap" with information about an assert error.
void fill_assert_error(garray_T *gap, typval_T *opt_msg_tv, char_u *exp_str, typval_T *exp_tv,
                       typval_T *got_tv, assert_type_T atype)
{
  char_u *tofree;

  if (opt_msg_tv->v_type != VAR_UNKNOWN) {
    tofree = (char_u *)encode_tv2echo(opt_msg_tv, NULL);
    ga_concat(gap, (char *)tofree);
    xfree(tofree);
    ga_concat(gap, ": ");
  }

  if (atype == ASSERT_MATCH || atype == ASSERT_NOTMATCH) {
    ga_concat(gap, "Pattern ");
  } else if (atype == ASSERT_NOTEQUAL) {
    ga_concat(gap, "Expected not equal to ");
  } else {
    ga_concat(gap, "Expected ");
  }

  if (exp_str == NULL) {
    tofree = (char_u *)encode_tv2string(exp_tv, NULL);
    ga_concat_shorten_esc(gap, tofree);
    xfree(tofree);
  } else {
    ga_concat_shorten_esc(gap, exp_str);
  }

  if (atype != ASSERT_NOTEQUAL) {
    if (atype == ASSERT_MATCH) {
      ga_concat(gap, " does not match ");
    } else if (atype == ASSERT_NOTMATCH) {
      ga_concat(gap, " does match ");
    } else {
      ga_concat(gap, " but got ");
    }
    tofree = (char_u *)encode_tv2string(got_tv, NULL);
    ga_concat_shorten_esc(gap, tofree);
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
  char line1[200];
  char line2[200];
  ptrdiff_t lineidx = 0;
  if (fd1 == NULL) {
    snprintf((char *)IObuff, IOSIZE, (char *)e_notread, fname1);
  } else {
    FILE *const fd2 = os_fopen(fname2, READBIN);
    if (fd2 == NULL) {
      fclose(fd1);
      snprintf((char *)IObuff, IOSIZE, (char *)e_notread, fname2);
    } else {
      int64_t linecount = 1;
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
        } else {
          line1[lineidx] = c1;
          line2[lineidx] = c2;
          lineidx++;
          if (c1 != c2) {
            snprintf((char *)IObuff, IOSIZE,
                     "difference at byte %" PRId64 ", line %" PRId64,
                     count, linecount);
            break;
          }
        }
        if (c1 == NL) {
          linecount++;
          lineidx = 0;
        } else if (lineidx + 2 == (ptrdiff_t)sizeof(line1)) {
          memmove(line1, line1 + 100, lineidx - 100);
          memmove(line2, line2 + 100, lineidx - 100);
          lineidx -= 100;
        }
      }
      fclose(fd1);
      fclose(fd2);
    }
  }
  if (IObuff[0] != NUL) {
    prepare_assert_error(&ga);
    if (argvars[2].v_type != VAR_UNKNOWN) {
      char *const tofree = encode_tv2echo(&argvars[2], NULL);
      ga_concat(&ga, tofree);
      xfree(tofree);
      ga_concat(&ga, ": ");
    }
    ga_concat(&ga, (char *)IObuff);
    if (lineidx > 0) {
      line1[lineidx] = NUL;
      line2[lineidx] = NUL;
      ga_concat(&ga, " after \"");
      ga_concat(&ga, line1);
      if (STRCMP(line1, line2) != 0) {
        ga_concat(&ga, "\" vs \"");
        ga_concat(&ga, line2);
      }
      ga_concat(&ga, "\"");
    }
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

  if (argvars[0].v_type == VAR_FLOAT
      || argvars[1].v_type == VAR_FLOAT
      || argvars[2].v_type == VAR_FLOAT) {
    const float_T flower = tv_get_float(&argvars[0]);
    const float_T fupper = tv_get_float(&argvars[1]);
    const float_T factual = tv_get_float(&argvars[2]);

    if (factual < flower || factual > fupper) {
      garray_T ga;
      prepare_assert_error(&ga);
      if (argvars[3].v_type != VAR_UNKNOWN) {
        char_u *const tofree = (char_u *)encode_tv2string(&argvars[3], NULL);
        ga_concat(&ga, (char *)tofree);
        xfree(tofree);
      } else {
        char msg[80];
        vim_snprintf(msg, sizeof(msg), "Expected range %g - %g, but got %g",
                     flower, fupper, factual);
        ga_concat(&ga, msg);
      }
      assert_error(&ga);
      ga_clear(&ga);
      return 1;
    }
  } else {
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
                   lower, upper);  // -V576
      fill_assert_error(&ga, &argvars[3], (char_u *)msg, NULL, &argvars[2],
                        ASSERT_INRANGE);
      assert_error(&ga);
      ga_clear(&ga);
      return 1;
    }
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
      && (argvars[0].v_type != VAR_BOOL
          || (argvars[0].vval.v_bool
              != (BoolVarValue)(is_true
                                ? kBoolVarTrue
                                : kBoolVarFalse)))) {
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
    ga_concat(&ga, "v:exception is not set");
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

static void assert_append_cmd_or_arg(garray_T *gap, typval_T *argvars, const char *cmd)
  FUNC_ATTR_NONNULL_ALL
{
  if (argvars[1].v_type != VAR_UNKNOWN && argvars[2].v_type != VAR_UNKNOWN) {
    char *const tofree = encode_tv2echo(&argvars[2], NULL);
    ga_concat(gap, tofree);
    xfree(tofree);
  } else {
    ga_concat(gap, cmd);
  }
}

int assert_beeps(typval_T *argvars, bool no_beep)
  FUNC_ATTR_NONNULL_ALL
{
  const char *const cmd = tv_get_string_chk(&argvars[0]);
  int ret = 0;

  called_vim_beep = false;
  suppress_errthrow = true;
  emsg_silent = false;
  do_cmdline_cmd(cmd);
  if (no_beep ? called_vim_beep : !called_vim_beep) {
    garray_T ga;
    prepare_assert_error(&ga);
    if (no_beep) {
      ga_concat(&ga, "command did beep: ");
    } else {
      ga_concat(&ga, "command did not beep: ");
    }
    ga_concat(&ga, cmd);
    assert_error(&ga);
    ga_clear(&ga);
    ret = 1;
  }

  suppress_errthrow = false;
  emsg_on_display = false;
  return ret;
}

int assert_fails(typval_T *argvars)
  FUNC_ATTR_NONNULL_ALL
{
  const char *const cmd = tv_get_string_chk(&argvars[0]);
  garray_T ga;
  int ret = 0;
  int save_trylevel = trylevel;

  // trylevel must be zero for a ":throw" command to be considered failed
  trylevel = 0;
  called_emsg = false;
  suppress_errthrow = true;
  emsg_silent = true;

  do_cmdline_cmd(cmd);
  if (!called_emsg) {
    prepare_assert_error(&ga);
    ga_concat(&ga, "command did not fail: ");
    assert_append_cmd_or_arg(&ga, argvars, cmd);
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
      ga_concat(&ga, ": ");
      assert_append_cmd_or_arg(&ga, argvars, cmd);
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
    emsg(_(e_invarg));
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

/// Find a window: When using a Window ID in any tab page, when using a number
/// in the current tab page.
win_T *find_win_by_nr_or_id(typval_T *vp)
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
  typval_T *expr;
  list_T *l = NULL;
  dictitem_T *di;
  hashtab_T *ht;
  hashitem_T *hi;
  dict_T *d = NULL;
  typval_T save_val;
  typval_T save_key;
  blob_T *b = NULL;
  int rem = false;
  int todo;
  char_u *ermsg = (char_u *)(map ? "map()" : "filter()");
  const char *const arg_errmsg = (map
                                  ? N_("map() argument")
                                  : N_("filter() argument"));
  int save_did_emsg;
  int idx = 0;

  if (argvars[0].v_type == VAR_BLOB) {
    tv_copy(&argvars[0], rettv);
    if ((b = argvars[0].vval.v_blob) == NULL) {
      return;
    }
  } else if (argvars[0].v_type == VAR_LIST) {
    tv_copy(&argvars[0], rettv);
    if ((l = argvars[0].vval.v_list) == NULL
        || (!map
            && var_check_lock(tv_list_locked(l), arg_errmsg, TV_TRANSLATE))) {
      return;
    }
  } else if (argvars[0].v_type == VAR_DICT) {
    tv_copy(&argvars[0], rettv);
    if ((d = argvars[0].vval.v_dict) == NULL
        || (!map && var_check_lock(d->dv_lock, arg_errmsg, TV_TRANSLATE))) {
      return;
    }
  } else {
    semsg(_(e_listdictblobarg), ermsg);
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
              && (var_check_lock(di->di_tv.v_lock, arg_errmsg, TV_TRANSLATE)
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
    } else if (argvars[0].v_type == VAR_BLOB) {
      vimvars[VV_KEY].vv_type = VAR_NUMBER;

      for (int i = 0; i < b->bv_ga.ga_len; i++) {
        typval_T tv;
        tv.v_type = VAR_NUMBER;
        const varnumber_T val = tv_blob_get(b, i);
        tv.vval.v_number = val;
        vimvars[VV_KEY].vv_nr = idx;
        if (filter_map_one(&tv, expr, map, &rem) == FAIL || did_emsg) {
          break;
        }
        if (tv.v_type != VAR_NUMBER) {
          emsg(_(e_invalblob));
          return;
        }
        if (map) {
          if (tv.vval.v_number != val) {
            tv_blob_set(b, i, tv.vval.v_number);
          }
        } else if (rem) {
          char_u *const p = (char_u *)argvars[0].vval.v_blob->bv_ga.ga_data;
          memmove(p + i, p + i + 1, (size_t)b->bv_ga.ga_len - i - 1);
          b->bv_ga.ga_len--;
          i--;
        }
        idx++;
      }
    } else {
      assert(argvars[0].v_type == VAR_LIST);
      vimvars[VV_KEY].vv_type = VAR_NUMBER;

      for (listitem_T *li = tv_list_first(l); li != NULL;) {
        if (map
            && var_check_lock(TV_LIST_ITEM_TV(li)->v_lock, arg_errmsg,
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
    rettv.v_lock = VAR_UNLOCKED;
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

void common_function(typval_T *argvars, typval_T *rettv, bool is_funcref, FunPtr fptr)
{
  char_u *s;
  char_u *name;
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
    // TODO(bfredl): do the entire nlua_is_table_from_lua dance
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
    semsg(_(e_invarg2), (use_string
                         ? tv_get_string(&argvars[0])
                         : (const char *)s));
    // Don't check an autoload name for existence here.
  } else if (trans_name != NULL
             && (is_funcref ? find_func(trans_name) == NULL
                            : !translated_function_exists((const char *)trans_name))) {
    semsg(_("E700: Unknown function: %s"), s);
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
          emsg(_("E922: expected a dict"));
          xfree(name);
          goto theend;
        }
        if (argvars[dict_idx].vval.v_dict == NULL) {
          dict_idx = 0;
        }
      }
      if (arg_idx > 0) {
        if (argvars[arg_idx].v_type != VAR_LIST) {
          emsg(_("E923: Second argument of function() must be "
                 "a list or a dict"));
          xfree(name);
          goto theend;
        }
        list = argvars[arg_idx].vval.v_list;
        if (tv_list_len(list) == 0) {
          arg_idx = 0;
        } else if (tv_list_len(list) > MAX_FUNC_ARGS) {
          emsg_funcname((char *)e_toomanyarg, s);
          xfree(name);
          goto theend;
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

  tv_dict_add_nr(dict, S_LEN("lastused"), buf->b_last_used);

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
linenr_T tv_get_lnum_buf(const typval_T *const tv, const buf_T *const buf)
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

void get_qf_loc_list(int is_qf, win_T *wp, typval_T *what_arg, typval_T *rettv)
{
  if (what_arg->v_type == VAR_UNKNOWN) {
    tv_list_alloc_ret(rettv, kListLenMayKnow);
    if (is_qf || wp != NULL) {
      (void)get_errorlist(NULL, wp, -1, 0, rettv->vval.v_list);
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
        emsg(_(e_dictreq));
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
  tv_dict_add_nr(dict, S_LEN("winbar"), 0);
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

/// Find window specified by "vp" in tabpage "tp".
///
/// @param tp  NULL for current tab page
win_T *find_win_by_nr(typval_T *vp, tabpage_T *tp)
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

/// getwinvar() and gettabwinvar()
///
/// @param off  1 for gettabwinvar()
void getwinvar(typval_T *argvars, typval_T *rettv, int off)
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
void get_user_input(const typval_T *const argvars, typval_T *const rettv, const bool inputdialog,
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
      emsg(_("E5050: {opts} must be the only argument"));
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
void dict_list(typval_T *const tv, typval_T *const rettv, const DictListType what)
{
  if (tv->v_type != VAR_DICT) {
    emsg(_(e_dictreq));
    return;
  }
  if (tv->vval.v_dict == NULL) {
    return;
  }

  tv_list_alloc_ret(rettv, tv_dict_len(tv->vval.v_dict));

  TV_DICT_ITER(tv->vval.v_dict, di, {
    typval_T tv_item = { .v_lock = VAR_UNLOCKED };

    switch (what) {
    case kDictListKeys:
      tv_item.v_type = VAR_STRING;
      tv_item.vval.v_string = vim_strsave(di->di_key);
      break;
    case kDictListValues:
      tv_copy(&di->di_tv, &tv_item);
      break;
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
    semsg(_(e_invarg2), "expected String or List");
    return NULL;
  }

  list_T *argl = cmd_tv->vval.v_list;
  int argc = tv_list_len(argl);
  if (!argc) {
    emsg(_(e_invarg));  // List must have at least one item.
    return NULL;
  }

  const char *arg0 = tv_get_string_chk(TV_LIST_ITEM_TV(tv_list_first(argl)));
  char *exe_resolved = NULL;
  if (!arg0 || !os_can_exe(arg0, &exe_resolved, true)) {
    if (arg0 && executable) {
      char buf[IOSIZE];
      snprintf(buf, sizeof(buf), "'%s' is not executable", arg0);
      semsg(_(e_invargNval), "cmd", buf);
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
void mapblock_fill_dict(dict_T *const dict, const mapblock_T *const mp, long buffer_value,
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
  tv_dict_add_nr(dict, S_LEN("script"), mp->m_noremap == REMAP_SCRIPT ? 1 : 0);
  tv_dict_add_nr(dict, S_LEN("expr"),  mp->m_expr ? 1 : 0);
  tv_dict_add_nr(dict, S_LEN("silent"), mp->m_silent ? 1 : 0);
  tv_dict_add_nr(dict, S_LEN("sid"), (varnumber_T)mp->m_script_ctx.sc_sid);
  tv_dict_add_nr(dict, S_LEN("lnum"), (varnumber_T)mp->m_script_ctx.sc_lnum);
  tv_dict_add_nr(dict, S_LEN("buffer"), (varnumber_T)buffer_value);
  tv_dict_add_nr(dict, S_LEN("nowait"), mp->m_nowait ? 1 : 0);
  tv_dict_add_allocated_str(dict, S_LEN("mode"), mapmode);
}

int matchadd_dict_arg(typval_T *tv, const char **conceal_char, win_T **win)
{
  dictitem_T *di;

  if (tv->v_type != VAR_DICT) {
    emsg(_(e_dictreq));
    return FAIL;
  }

  if ((di = tv_dict_find(tv->vval.v_dict, S_LEN("conceal"))) != NULL) {
    *conceal_char = tv_get_string(&di->di_tv);
  }

  if ((di = tv_dict_find(tv->vval.v_dict, S_LEN("window"))) != NULL) {
    *win = find_win_by_nr_or_id(&di->di_tv);
    if (*win == NULL) {
      emsg(_(e_invalwindow));
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
void set_buffer_lines(buf_T *buf, linenr_T lnum_arg, bool append, const typval_T *lines,
                      typval_T *rettv)
  FUNC_ATTR_NONNULL_ARG(4, 5)
{
  linenr_T lnum = lnum_arg + (append ? 1 : 0);
  const char *line = NULL;
  list_T *l = NULL;
  listitem_T *li = NULL;
  long added = 0;
  linenr_T append_lnum;
  buf_T *curbuf_save = NULL;
  win_T *curwin_save = NULL;
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
      int old_len = (int)STRLEN(ml_get(lnum));
      if (u_savesub(lnum) == OK
          && ml_replace(lnum, (char_u *)line, true) == OK) {
        inserted_bytes(lnum, 0, old_len, STRLEN(line));
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
    update_topline(curwin);
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
    win_T *save_curwin;
    tabpage_T *save_curtab;
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
    iter = vim_env_iter(ENV_SEPCHAR, dirs, iter, &dir, &dir_len);
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
void get_system_output_as_rettv(typval_T *argvars, typval_T *rettv, bool retlist)
{
  proftime_T wait_time;
  bool profiling = do_profiling == PROF_YES;

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;

  if (check_secure()) {
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

  set_vim_var_nr(VV_SHELL_ERROR, (long)status);

  if (res == NULL) {
    if (retlist) {
      // return an empty list when there's no output
      tv_list_alloc_ret(rettv, 0);
    } else {
      rettv->vval.v_string = (char_u *)xstrdup("");
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
    rettv->vval.v_string = (char_u *)res;
  }
}

bool callback_from_typval(Callback *const callback, typval_T *const arg)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  int r = OK;

  if (arg->v_type == VAR_PARTIAL && arg->vval.v_partial != NULL) {
    callback->data.partial = arg->vval.v_partial;
    callback->data.partial->pt_refcount++;
    callback->type = kCallbackPartial;
  } else if (arg->v_type == VAR_STRING
             && arg->vval.v_string != NULL
             && ascii_isdigit(*arg->vval.v_string)) {
    r = FAIL;
  } else if (arg->v_type == VAR_FUNC || arg->v_type == VAR_STRING) {
    char_u *name = arg->vval.v_string;
    if (name == NULL) {
      r = FAIL;
    } else if (*name == NUL) {
      callback->type = kCallbackNone;
      callback->data.funcref = NULL;
    } else {
      func_ref(name);
      callback->data.funcref = vim_strsave(name);
      callback->type = kCallbackFuncref;
    }
  } else if (nlua_is_table_from_lua(arg)) {
    char_u *name = nlua_register_table_as_callable(arg);

    if (name != NULL) {
      callback->data.funcref = vim_strsave(name);
      callback->type = kCallbackFuncref;
    } else {
      r = FAIL;
    }
  } else if (arg->v_type == VAR_SPECIAL
             || (arg->v_type == VAR_NUMBER && arg->vval.v_number == 0)) {
    callback->type = kCallbackNone;
    callback->data.funcref = NULL;
  } else {
    r = FAIL;
  }

  if (r == FAIL) {
    emsg(_("E921: Invalid callback argument"));
    return false;
  }
  return true;
}

bool callback_call(Callback *const callback, const int argcount_in, typval_T *const argvars_in,
                   typval_T *const rettv)
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

  funcexe_T funcexe = FUNCEXE_INIT;
  funcexe.firstline = curwin->w_cursor.lnum;
  funcexe.lastline = curwin->w_cursor.lnum;
  funcexe.evaluate = true;
  funcexe.partial = partial;
  return call_func(name, -1, rettv, argcount_in, argvars_in, &funcexe);
}

static bool set_ref_in_callback(Callback *callback, int copyID, ht_stack_T **ht_stack,
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

static bool set_ref_in_callback_reader(CallbackReader *reader, int copyID, ht_stack_T **ht_stack,
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
  return pmap_get(uint64_t)(&timers, xx);
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

  callback_put(&timer->callback, &di->di_tv);
}

void add_timer_info_all(typval_T *rettv)
{
  tv_list_alloc_ret(rettv, map_size(&timers));
  timer_T *timer;
  map_foreach_value(&timers, timer, {
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

uint64_t timer_start(const long timeout, const int repeat_count, const Callback *const callback)
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

  pmap_put(uint64_t)(&timers, timer->timer_id, timer);
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
  pmap_del(uint64_t)(&timers, timer->timer_id);
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
  map_foreach_value(&timers, timer, {
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
bool write_list(FileDescriptor *const fp, const list_T *const list, const bool binary)
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
  semsg(_(e_write2), os_strerror(error));
  return false;
}

/// Write a blob to file with descriptor `fp`.
///
/// @param[in]  fp  File to write to.
/// @param[in]  blob  Blob to write.
///
/// @return true on success, or false on failure.
bool write_blob(FileDescriptor *const fp, const blob_T *const blob)
  FUNC_ATTR_NONNULL_ARG(1)
{
  int error = 0;
  const int len = tv_blob_len(blob);
  if (len > 0) {
    const ptrdiff_t written = file_write(fp, blob->bv_ga.ga_data, (size_t)len);
    if (written < (ptrdiff_t)len) {
      error = (int)written;
      goto write_blob_error;
    }
  }
  error = file_flush(fp);
  if (error != 0) {
    goto write_blob_error;
  }
  return true;
write_blob_error:
  semsg(_(e_write2), os_strerror(error));
  return false;
}

/// Read a blob from a file `fd`.
///
/// @param[in]  fd  File to read from.
/// @param[in,out]  blob  Blob to write to.
///
/// @return true on success, or false on failure.
bool read_blob(FILE *const fd, blob_T *const blob)
  FUNC_ATTR_NONNULL_ALL
{
  FileInfo file_info;
  if (!os_fileinfo_fd(fileno(fd), &file_info)) {
    return false;
  }
  const int size = (int)os_fileinfo_size(&file_info);
  ga_grow(&blob->bv_ga, size);
  blob->bv_ga.ga_len = size;
  if (fread(blob->bv_ga.ga_data, 1, blob->bv_ga.ga_len, fd)
      < (size_t)blob->bv_ga.ga_len) {
    return false;
  }
  return true;
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
      semsg(_(e_nobufnr), tv->vval.v_number);
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
pos_T *var2fpos(const typval_T *const tv, const bool dollar_lnum, int *const ret_fnum)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  static pos_T pos;
  pos_T *pp;

  // Argument can be [lnum, col, coladd].
  if (tv->v_type == VAR_LIST) {
    list_T *l;
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
    if (name[1] == '0') {               // "w0": first visible line
      update_topline(curwin);
      // In silent Ex mode topline is zero, but that's not a valid line
      // number; use one instead.
      pos.lnum = curwin->w_topline > 0 ? curwin->w_topline : 1;
      return &pos;
    } else if (name[1] == '$') {      // "w$": last visible line
      validate_botline(curwin);
      // In silent Ex mode botline is zero, return zero then.
      pos.lnum = curwin->w_botline > 0 ? curwin->w_botline - 1 : 0;
      return &pos;
    }
  } else if (name[0] == '$') {        // last column or line
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
int get_id_len(const char **const arg)
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
int get_name_len(const char **const arg, char **alias, bool evaluate, bool verbose)
{
  int len;

  *alias = NULL;    // default to no alias

  if ((*arg)[0] == (char)K_SPECIAL && (*arg)[1] == (char)KS_EXTRA
      && (*arg)[2] == (char)KE_SNR) {
    // Hard coded <SNR>, already translated.
    *arg += 3;
    return get_id_len(arg) + 3;
  }
  len = eval_fname_script(*arg);
  if (len > 0) {
    // literal "<SID>", "s:" or "<SNR>"
    *arg += len;
  }

  // Find the end of the name; check for {} construction.
  char_u *expr_start;
  char_u *expr_end;
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
    semsg(_(e_invexpr2), *arg);
  }

  return len;
}

// Find the end of a variable or function name, taking care of magic braces.
// If "expr_start" is not NULL then "expr_start" and "expr_end" are set to the
// start and end of the first magic braces item.
// "flags" can have FNE_INCL_BR and FNE_CHECK_START.
// Return a pointer to just after the name.  Equal to "arg" if there is no
// valid name.
const char_u *find_name_end(const char_u *arg, const char_u **expr_start, const char_u **expr_end,
                            int flags)
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
      // slice "[n:]".  Also "xx:" is not a namespace. But {ns}: is.
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
 *                      "in_start"      ^
 *                      "expr_start"       ^
 *                      "expr_end"               ^
 *                      "in_end"                            ^
 *
 * Returns a new allocated string, which the caller must free.
 * Returns NULL for failure.
 */
static char_u *make_expanded_name(const char_u *in_start, char_u *expr_start, char_u *expr_end,
                                  char_u *in_end)
{
  char_u c1;
  char_u *retval = NULL;
  char_u *temp_result;
  char_u *nextcmd = NULL;

  if (expr_end == NULL || in_end == NULL) {
    return NULL;
  }
  *expr_start = NUL;
  *expr_end = NUL;
  c1 = *in_end;
  *in_end = NUL;

  temp_result = eval_to_string(expr_start + 1, &nextcmd, false);
  if (temp_result != NULL && nextcmd == NULL) {
    retval = xmalloc(STRLEN(temp_result) + (expr_start - in_start)
                     + (in_end - expr_end) + 1);
    STRCPY(retval, in_start);
    STRCAT(retval, temp_result);
    STRCAT(retval, expr_end + 1);
  }
  xfree(temp_result);

  *in_end = c1;                 // put char back for error messages
  *expr_start = '{';
  *expr_end = '}';

  if (retval != NULL) {
    temp_result = (char_u *)find_name_end(retval,
                                          (const char_u **)&expr_start,
                                          (const char_u **)&expr_end, 0);
    if (expr_start != NULL) {
      // Further expansion!
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
int eval_isnamec(int c)
{
  return ASCII_ISALNUM(c) || c == '_' || c == ':' || c == AUTOLOAD_CHAR;
}

/*
 * Return TRUE if character "c" can be used as the first character in a
 * variable or function name (excluding '{' and '}').
 */
int eval_isnamec1(int c)
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
  if (set_prevcount) {
    vimvars[VV_PREVCOUNT].vv_nr = vimvars[VV_COUNT].vv_nr;
  }
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

/// Set boolean v: {true, false} to the given value
///
/// @param[in]  idx  Index of variable to set.
/// @param[in]  val  Value to set to.
void set_vim_var_bool(const VimVarIndex idx, const BoolVarValue val)
{
  tv_clear(&vimvars[idx].vv_tv);
  vimvars[idx].vv_type = VAR_BOOL;
  vimvars[idx].vv_bool = val;
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
/// @param[in]  len  Length of that value or -1 in which case strlen() will be
///                  used.
void set_vim_var_string(const VimVarIndex idx, const char *const val, const ptrdiff_t len)
{
  tv_clear(&vimvars[idx].vv_di.di_tv);
  vimvars[idx].vv_type = VAR_STRING;
  if (val == NULL) {
    vimvars[idx].vv_str = NULL;
  } else if (len == -1) {
    vimvars[idx].vv_str = (char_u *)xstrdup(val);
  } else {
    vimvars[idx].vv_str = (char_u *)xstrndup(val, (size_t)len);
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

/// Set the v:argv list.
void set_argv_var(char **argv, int argc)
{
  list_T *l = tv_list_alloc(argc);
  int i;

  tv_list_set_lock(l, VAR_FIXED);
  for (i = 0; i < argc; i++) {
    tv_list_append_string(l, (const char *const)argv[i], -1);
    TV_LIST_ITEM_TV(tv_list_last(l))->v_lock = VAR_FIXED;
  }
  set_vim_var_list(VV_ARGV, l);
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
  if (oldval == NULL) {
    return vimvars[VV_EXCEPTION].vv_str;
  }

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
  if (oldval == NULL) {
    return vimvars[VV_THROWPOINT].vv_str;
  }

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
  char_u *oldval = vimvars[VV_CMDARG].vv_str;
  if (eap == NULL) {
    xfree(oldval);
    vimvars[VV_CMDARG].vv_str = oldarg;
    return NULL;
  }

  size_t len = 0;
  if (eap->force_bin == FORCE_BIN) {
    len = 6;
  } else if (eap->force_bin == FORCE_NOBIN) {
    len = 8;
  }

  if (eap->read_edit) {
    len += 7;
  }

  if (eap->force_ff != 0) {
    len += 10;  // " ++ff=unix"
  }
  if (eap->force_enc != 0) {
    len += STRLEN(eap->cmd + eap->force_enc) + 7;
  }
  if (eap->bad_char != 0) {
    len += 7 + 4;  // " ++bad=" + "keep" or "drop"
  }

  const size_t newval_len = len + 1;
  char_u *newval = xmalloc(newval_len);

  if (eap->force_bin == FORCE_BIN) {
    snprintf((char *)newval, newval_len, " ++bin");
  } else if (eap->force_bin == FORCE_NOBIN) {
    snprintf((char *)newval, newval_len, " ++nobin");
  } else {
    *newval = NUL;
  }

  if (eap->read_edit) {
    STRCAT(newval, " ++edit");
  }

  if (eap->force_ff != 0) {
    snprintf((char *)newval + STRLEN(newval), newval_len, " ++ff=%s",
             eap->force_ff == 'u' ? "unix" :
             eap->force_ff == 'd' ? "dos" : "mac");
  }
  if (eap->force_enc != 0) {
    snprintf((char *)newval + STRLEN(newval), newval_len, " ++enc=%s",
             eap->cmd + eap->force_enc);
  }
  if (eap->bad_char == BAD_KEEP) {
    STRCPY(newval + STRLEN(newval), " ++bad=keep");
  } else if (eap->bad_char == BAD_DROP) {
    STRCPY(newval + STRLEN(newval), " ++bad=drop");
  } else if (eap->bad_char != 0) {
    snprintf((char *)newval + STRLEN(newval), newval_len, " ++bad=%c",
             eap->bad_char);
  }
  vimvars[VV_CMDARG].vv_str = newval;
  return oldval;
}

/// Get the value of internal variable "name".
/// Return OK or FAIL.  If OK is returned "rettv" must be cleared.
///
/// @param len  length of "name"
/// @param rettv  NULL when only checking existence
/// @param dip  non-NULL when typval's dict item is needed
/// @param verbose  may give error message
/// @param no_autoload  do not use script autoloading
int get_var_tv(const char *name, int len, typval_T *rettv, dictitem_T **dip, int verbose,
               int no_autoload)
{
  int ret = OK;
  typval_T *tv = NULL;
  dictitem_T *v;

  v = find_var(name, (size_t)len, NULL, no_autoload);
  if (v != NULL) {
    tv = &v->di_tv;
    if (dip != NULL) {
      *dip = v;
    }
  }

  if (tv == NULL) {
    if (rettv != NULL && verbose) {
      semsg(_("E121: Undefined variable: %.*s"), len, name);
    }
    ret = FAIL;
  } else if (rettv != NULL) {
    tv_copy(tv, rettv);
  }

  return ret;
}

/// Check if variable "name[len]" is a local variable or an argument.
/// If so, "*eval_lavars_used" is set to true.
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
bool is_luafunc(partial_T *partial)
{
  return partial == vvlua_partial;
}

/// check if special v:lua value for calling lua functions
static bool tv_is_luafunc(typval_T *tv)
{
  return tv->v_type == VAR_PARTIAL && is_luafunc(tv->vval.v_partial);
}

/// Skips one character past the end of the name of a v:lua function.
/// @param p  Pointer to the char AFTER the "v:lua." prefix.
/// @return Pointer to the char one past the end of the function's name.
const char *skip_luafunc_name(const char *p)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  while (ASCII_ISALNUM(*p) || *p == '_' || *p == '.' || *p == '\'') {
    p++;
  }
  return p;
}

/// check the function name after "v:lua."
int check_luafunc_name(const char *const str, const bool paren)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  const char *const p = skip_luafunc_name(str);
  if (*p != (paren ? '(' : NUL)) {
    return 0;
  } else {
    return (int)(p-str);
  }
}

/// Handle:
/// - expr[expr], expr[expr:expr] subscript
/// - ".name" lookup
/// - function call with Funcref variable: func(expr)
/// - method call: var->method()
///
/// Can all be combined in any order: dict.func(expr)[idx]['func'](expr)->len()
///
/// @param evaluate  do more than finding the end
/// @param verbose  give error messages
/// @param start_leader  start of '!' and '-' prefixes
/// @param end_leaderp  end of '!' and '-' prefixes
int handle_subscript(const char **const arg, typval_T *rettv, int evaluate, int verbose,
                     const char_u *const start_leader, const char_u **const end_leaderp)
{
  int ret = OK;
  dict_T *selfdict = NULL;
  const char_u *lua_funcname = NULL;

  if (tv_is_luafunc(rettv)) {
    if (**arg != '.') {
      tv_clear(rettv);
      ret = FAIL;
    } else {
      (*arg)++;

      lua_funcname = (char_u *)(*arg);
      const int len = check_luafunc_name(*arg, true);
      if (len == 0) {
        tv_clear(rettv);
        ret = FAIL;
      }
      (*arg) += len;
    }
  }

  // "." is ".name" lookup when we found a dict.
  while (ret == OK
         && (((**arg == '[' || (**arg == '.' && rettv->v_type == VAR_DICT)
               || (**arg == '(' && (!evaluate || tv_is_func(*rettv))))
              && !ascii_iswhite(*(*arg - 1)))
             || (**arg == '-' && (*arg)[1] == '>'))) {
    if (**arg == '(') {
      ret = call_func_rettv((char_u **)arg, rettv, evaluate, selfdict, NULL,
                            lua_funcname);

      // Stop the expression evaluation when immediately aborting on
      // error, or when an interrupt occurred or an exception was thrown
      // but not caught.
      if (aborting()) {
        if (ret == OK) {
          tv_clear(rettv);
        }
        ret = FAIL;
      }
      tv_dict_unref(selfdict);
      selfdict = NULL;
    } else if (**arg == '-') {
      // Expression "-1.0->method()" applies the leader "-" before
      // applying ->.
      if (evaluate && *end_leaderp > start_leader) {
        ret = eval7_leader(rettv, start_leader, end_leaderp);
      }
      if (ret == OK) {
        if ((*arg)[2] == '{') {
          // expr->{lambda}()
          ret = eval_lambda((char_u **)arg, rettv, evaluate, verbose);
        } else {
          // expr->name()
          ret = eval_method((char_u **)arg, rettv, evaluate, verbose);
        }
      }
    } else {  // **arg == '[' || **arg == '.'
      tv_dict_unref(selfdict);
      if (rettv->v_type == VAR_DICT) {
        selfdict = rettv->vval.v_dict;
        if (selfdict != NULL) {
          ++selfdict->dv_refcount;
        }
      } else {
        selfdict = NULL;
      }
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

void set_selfdict(typval_T *const rettv, dict_T *const selfdict)
{
  // Don't do this when "dict.Func" is already a partial that was bound
  // explicitly (pt_auto is false).
  if (rettv->v_type == VAR_PARTIAL && !rettv->vval.v_partial->pt_auto
      && rettv->vval.v_partial->pt_dict != NULL) {
    return;
  }
  make_partial(selfdict, rettv);
}

// Find variable "name" in the list of variables.
// Return a pointer to it if found, NULL if not found.
// Careful: "a:0" variables don't have a name.
// When "htp" is not NULL we are writing to the variable, set "htp" to the
// hashtab_T used.
dictitem_T *find_var(const char *const name, const size_t name_len, hashtab_T **htp,
                     int no_autoload)
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

/// Find variable in hashtab.
/// When "varname" is empty returns curwin/curtab/etc vars dictionary.
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
dictitem_T *find_var_in_ht(hashtab_T *const ht, int htname, const char *const varname,
                           const size_t varname_len, int no_autoload)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  hashitem_T *hi;

  if (varname_len == 0) {
    // Must be something like "s:", otherwise "ht" would be NULL.
    switch (htname) {
    case 's':
      return (dictitem_T *)&SCRIPT_SV(current_sctx.sc_sid)->sv_var;
    case 'g':
      return (dictitem_T *)&globvars_var;
    case 'v':
      return (dictitem_T *)&vimvars_var;
    case 'b':
      return (dictitem_T *)&curbuf->b_bufvar;
    case 'w':
      return (dictitem_T *)&curwin->w_winvar;
    case 't':
      return (dictitem_T *)&curtab->tp_winvar;
    case 'l':
      return get_funccal_local_var();
    case 'a':
      return get_funccal_args_var();
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

/// Finds the dict (g:, l:, s:, …) and hashtable used for a variable.
///
/// @param[in]  name  Variable name, possibly with scope prefix.
/// @param[in]  name_len  Variable name length.
/// @param[out]  varname  Will be set to the start of the name without scope
///                       prefix.
/// @param[out]  d  Scope dictionary.
///
/// @return Scope hashtab, NULL if name is not valid.
static hashtab_T *find_var_ht_dict(const char *name, const size_t name_len, const char **varname,
                                   dict_T **d)
{
  hashitem_T *hi;
  funccall_T *funccal = get_funccal();
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

    if (funccal == NULL) {  // global variable
      *d = &globvardict;
    } else {  // l: variable
      *d = &funccal->l_vars;
    }
    goto end;
  }

  *varname = name + 2;
  if (*name == 'g') {  // global variable
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
  } else if (*name == 'a' && funccal != NULL) {  // function argument
    *d = &funccal->l_avars;
  } else if (*name == 'l' && funccal != NULL) {  // local variable
    *d = &funccal->l_vars;
  } else if (*name == 's'  // script variable
             && (current_sctx.sc_sid > 0 || current_sctx.sc_sid == SID_STR)
             && current_sctx.sc_sid <= ga_scripts.ga_len) {
    // For anonymous scripts without a script item, create one now so script vars can be used
    if (current_sctx.sc_sid == SID_STR) {
      new_script_item(NULL, &current_sctx.sc_sid);
    }
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
hashtab_T *find_var_ht(const char *name, const size_t name_len, const char **varname)
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
  dictitem_T *v;

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
  hashtab_T *ht;
  scriptvar_T *sv;

  ga_grow(&ga_scripts, (int)(id - ga_scripts.ga_len));
  {
    /* Re-allocating ga_data means that an ht_array pointing to
     * ht_smallarray becomes invalid.  We can recognize this: ht_mask is
     * at its init value.  Also reset "v_dict", it's always the same. */
    for (int i = 1; i <= ga_scripts.ga_len; ++i) {
      ht = &SCRIPT_VARS(i);
      if (ht->ht_mask == HT_INIT_SIZE - 1) {
        ht->ht_array = ht->ht_smallarray;
      }
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
void vars_clear_ext(hashtab_T *ht, int free_val)
{
  int todo;
  hashitem_T *hi;
  dictitem_T *v;

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
  dictitem_T *di = TV_DICT_HI2DI(hi);

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
static void list_one_var_a(const char *prefix, const char *name, const ptrdiff_t name_len,
                           const int type, const char *string, int *first)
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
    if (*string == '[') {
      ++string;
    }
  } else if (type == VAR_DICT) {
    msg_putchar('{');
    if (*string == '{') {
      ++string;
    }
  } else {
    msg_putchar(' ');
  }

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
void set_var(const char *name, const size_t name_len, typval_T *const tv, const bool copy)
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
static void set_var_const(const char *name, const size_t name_len, typval_T *const tv,
                          const bool copy, const bool is_const)
  FUNC_ATTR_NONNULL_ALL
{
  dictitem_T *v;
  hashtab_T *ht;
  dict_T *dict;

  const char *varname;
  ht = find_var_ht_dict(name, name_len, &varname, &dict);
  const bool watched = tv_dict_is_watched(dict);

  if (ht == NULL || *varname == NUL) {
    semsg(_(e_illvar), name);
    return;
  }
  v = find_var_in_ht(ht, 0, varname, name_len - (size_t)(varname - name), true);

  // Search in parent scope which is possible to reference from lambda
  if (v == NULL) {
    v = find_var_in_scoped_ht(name, name_len, true);
  }

  if (tv_is_func(*tv) && !var_check_func_name(name, v == NULL)) {
    return;
  }

  typval_T oldtv = TV_INITIAL_VALUE;
  if (v != NULL) {
    if (is_const) {
      emsg(_(e_cannot_mod));
      return;
    }

    // existing variable, need to clear the value
    if (var_check_ro(v->di_flags, name, name_len)
        || var_check_lock(v->di_tv.v_lock, name, name_len)) {
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
          // causes an error message the variable will already be set.
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
        semsg(_("E963: setting %s to value with wrong type"), name);
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
      semsg(_(e_illvar), name);
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
    v->di_tv.v_lock = VAR_UNLOCKED;
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
    // Like :lockvar! name: lock the value and what it contains, but only
    // if the reference count is up to one.  That locks only literal
    // values.
    tv_item_lock(&v->di_tv, DICT_MAXNEST, true, true);
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
bool var_check_ro(const int flags, const char *name, size_t name_len)
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

  semsg(_(error_message), (int)name_len, name);

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
bool var_check_fixed(const int flags, const char *name, size_t name_len)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (flags & DI_FLAGS_FIX) {
    if (name_len == TV_TRANSLATE) {
      name = _(name);
      name_len = strlen(name);
    } else if (name_len == TV_CSTRING) {
      name_len = strlen(name);
    }
    semsg(_("E795: Cannot delete variable %.*s"), (int)name_len, name);
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
    semsg(_("E704: Funcref variable name must start with a capital: %s"), name);
    return false;
  }
  // Don't allow hiding a function.  When "v" is not NULL we might be
  // assigning another function to the same var, the type is checked
  // below.
  if (new_var && function_exists(name, false)) {
    semsg(_("E705: Variable name conflicts with existing function: %s"),
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
      semsg(_(e_illvar), varname);
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
int var_item_copy(const vimconv_T *const conv, typval_T *const from, typval_T *const to,
                  const bool deep, const int copyID)
  FUNC_ATTR_NONNULL_ARG(2, 3)
{
  static int recurse = 0;
  int ret = OK;

  if (recurse >= DICT_MAXNEST) {
    emsg(_("E698: variable nested too deep for making a copy"));
    return FAIL;
  }
  ++recurse;

  switch (from->v_type) {
  case VAR_NUMBER:
  case VAR_FLOAT:
  case VAR_FUNC:
  case VAR_PARTIAL:
  case VAR_BOOL:
  case VAR_SPECIAL:
    tv_copy(from, to);
    break;
  case VAR_STRING:
    if (conv == NULL || conv->vc_type == CONV_NONE
        || from->vval.v_string == NULL) {
      tv_copy(from, to);
    } else {
      to->v_type = VAR_STRING;
      to->v_lock = VAR_UNLOCKED;
      if ((to->vval.v_string = string_convert((vimconv_T *)conv,
                                              from->vval.v_string,
                                              NULL))
          == NULL) {
        to->vval.v_string = (char_u *)xstrdup((char *)from->vval.v_string);
      }
    }
    break;
  case VAR_LIST:
    to->v_type = VAR_LIST;
    to->v_lock = VAR_UNLOCKED;
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
  case VAR_BLOB:
    tv_blob_copy(from, to);
    break;
  case VAR_DICT:
    to->v_type = VAR_DICT;
    to->v_lock = VAR_UNLOCKED;
    if (from->vval.v_dict == NULL) {
      to->vval.v_dict = NULL;
    } else if (copyID != 0 && from->vval.v_dict->dv_copyID == copyID) {
      // use the copy made earlier
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
 * ":echo expr1 ..."    print each argument separated with a space, add a
 *                      newline at the end.
 * ":echon expr1 ..."   print each argument plain.
 */
void ex_echo(exarg_T *eap)
{
  char_u *arg = eap->arg;
  typval_T rettv;
  bool atstart = true;
  bool need_clear = true;
  const int did_emsg_before = did_emsg;
  const int called_emsg_before = called_emsg;

  if (eap->skip) {
    ++emsg_skip;
  }
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
        if (!aborting() && did_emsg == did_emsg_before
            && called_emsg == called_emsg_before) {
          semsg(_(e_invexpr2), p);
        }
        need_clr_eos = false;
        break;
      }
      need_clr_eos = false;
    }

    if (!eap->skip) {
      if (atstart) {
        atstart = false;
        // Call msg_start() after eval1(), evaluating the expression
        // may cause a message to appear.
        if (eap->cmdidx == CMD_echo) {
          // Mark the saved text as finishing the line, so that what
          // follows is displayed on a new line when scrolling back
          // at the more prompt.
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
  echo_attr = syn_name2attr(eap->arg);
}

/*
 * ":execute expr1 ..." execute the result of an expression.
 * ":echomsg expr1 ..." Print a message
 * ":echoerr expr1 ..." Print an error
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

  if (eap->skip) {
    ++emsg_skip;
  }
  while (*arg != NUL && *arg != '|' && *arg != '\n') {
    ret = eval1_emsg(&arg, &rettv, !eap->skip);
    if (ret == FAIL) {
      break;
    }

    if (!eap->skip) {
      const char *const argstr = eap->cmdidx == CMD_execute
        ? tv_get_string(&rettv)
        : rettv.v_type == VAR_STRING
        ? encode_tv2echo(&rettv, NULL)
        : encode_tv2string(&rettv, NULL);
      const size_t len = strlen(argstr);
      ga_grow(&ga, len + 2);
      if (!GA_EMPTY(&ga)) {
        ((char_u *)(ga.ga_data))[ga.ga_len++] = ' ';
      }
      memcpy((char_u *)(ga.ga_data) + ga.ga_len, argstr, len + 1);
      if (eap->cmdidx != CMD_execute) {
        xfree((void *)argstr);
      }
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
      msg_attr(ga.ga_data, echo_attr);
      ui_flush();
    } else if (eap->cmdidx == CMD_echoerr) {
      // We don't want to abort following commands, restore did_emsg.
      save_did_emsg = did_emsg;
      msg_ext_set_kind("echoerr");
      emsg(ga.ga_data);
      if (!force_abort) {
        did_emsg = save_did_emsg;
      }
    } else if (eap->cmdidx == CMD_execute) {
      do_cmdline((char_u *)ga.ga_data,
                 eap->getline, eap->cookie, DOCMD_NOWAIT|DOCMD_VERBOSE);
    }
  }

  ga_clear(&ga);

  if (eap->skip) {
    --emsg_skip;
  }

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

/// Start profiling function "fp".
void func_do_profile(ufunc_T *fp)
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
  hashitem_T *hi;
  int todo;
  ufunc_T *fp;
  ufunc_T **sorttab;
  int st_len = 0;

  todo = (int)func_hashtab.ht_used;
  if (todo == 0) {
    return;         // nothing to dump
  }

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
          if (FUNCLINE(fp, i) == NULL) {
            continue;
          }
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

/// @param prefer_self  when equal print only self time
static void prof_sort_list(FILE *fd, ufunc_T **sorttab, int st_len, char *title, int prefer_self)
{
  int i;
  ufunc_T *fp;

  fprintf(fd, "FUNCTIONS SORTED ON %s TIME\n", title);
  fprintf(fd, "count  total (s)   self (s)  function\n");
  for (i = 0; i < 20 && i < st_len; ++i) {
    fp = sorttab[i];
    prof_func_line(fd, fp->uf_tm_count, &fp->uf_tm_total, &fp->uf_tm_self,
                   prefer_self);
    if (fp->uf_name[0] == K_SPECIAL) {
      fprintf(fd, " <SNR>%s()\n", fp->uf_name + 3);
    } else {
      fprintf(fd, " %s()\n", fp->uf_name);
    }
  }
  fprintf(fd, "\n");
}

/// Print the count and times for one function or function line.
///
/// @param prefer_self  when equal print only self time
static void prof_func_line(FILE *fd, int count, proftime_T *total, proftime_T *self,
                           int prefer_self)
{
  if (count > 0) {
    fprintf(fd, "%5d ", count);
    if (prefer_self && profile_equal(*total, *self)) {
      fprintf(fd, "           ");
    } else {
      fprintf(fd, "%s ", profile_msg(*total));
    }
    if (!prefer_self && profile_equal(*total, *self)) {
      fprintf(fd, "           ");
    } else {
      fprintf(fd, "%s ", profile_msg(*self));
    }
  } else {
    fprintf(fd, "                            ");
  }
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

/// Return the autoload script name for a function or variable name
/// Caller must make sure that "name" contains AUTOLOAD_CHAR.
///
/// @param[in]  name  Variable/function name.
/// @param[in]  name_len  Name length.
///
/// @return [allocated] autoload script name.
char *autoload_name(const char *const name, const size_t name_len)
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

/// If name has a package name try autoloading the script for it
///
/// @param[in]  name  Variable/function name.
/// @param[in]  name_len  Name length.
/// @param[in]  reload  If true, load script again when already loaded.
///
/// @return true if a package was loaded.
bool script_autoload(const char *const name, const size_t name_len, const bool reload)
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
    if (source_runtime(scriptname, 0) == OK) {
      ret = true;
    }
  }

  xfree(tofree);
  return ret;
}

/*
 * Called when starting to read a function line.
 * "sourcing_lnum" must be correct!
 * When skipping lines it may not actually be executed, but we won't find out
 * until later and we need to store the time now.
 */
void func_line_start(void *cookie)
{
  funccall_T *fcp = (funccall_T *)cookie;
  ufunc_T *fp = fcp->func;

  if (fp->uf_profiling && sourcing_lnum >= 1
      && sourcing_lnum <= fp->uf_lines.ga_len) {
    fp->uf_tml_idx = sourcing_lnum - 1;
    // Skip continuation lines.
    while (fp->uf_tml_idx > 0 && FUNCLINE(fp, fp->uf_tml_idx) == NULL) {
      fp->uf_tml_idx--;
    }
    fp->uf_tml_execed = false;
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
  funccall_T *fcp = (funccall_T *)cookie;
  ufunc_T *fp = fcp->func;

  if (fp->uf_profiling && fp->uf_tml_idx >= 0) {
    fp->uf_tml_execed = TRUE;
  }
}

/*
 * Called when done with a function line.
 */
void func_line_end(void *cookie)
{
  funccall_T *fcp = (funccall_T *)cookie;
  ufunc_T *fp = fcp->func;

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

static var_flavour_T var_flavour(char_u *varname)
{
  char_u *p = varname;

  if (ASCII_ISUPPER(*p)) {
    while (*(++p)) {
      if (ASCII_ISLOWER(*p)) {
        return VAR_FLAVOUR_SESSION;
      }
    }
    return VAR_FLAVOUR_SHADA;
  } else {
    return VAR_FLAVOUR_DEFAULT;
  }
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
const void *var_shada_iter(const void *const iter, const char **const name, typval_T *rettv,
                           var_flavour_T flavour)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(2, 3)
{
  const hashitem_T *hi;
  const hashitem_T *hifirst = globvarht.ht_array;
  const size_t hinum = (size_t)globvarht.ht_mask + 1;
  *name = NULL;
  if (iter == NULL) {
    hi = globvarht.ht_array;
    while ((size_t)(hi - hifirst) < hinum
           && (HASHITEM_EMPTY(hi)
               || !(var_flavour(hi->hi_key) & flavour))) {
      hi++;
    }
    if ((size_t)(hi - hifirst) == hinum) {
      return NULL;
    }
  } else {
    hi = (const hashitem_T *)iter;
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
  funccal_entry_T funccall_entry;

  save_funccal(&funccall_entry);
  set_var(name, strlen(name), &vartv, false);
  restore_funccal();
}

int store_session_globals(FILE *fd)
{
  TV_DICT_ITER(&globvardict, this_var, {
    if ((this_var->di_tv.v_type == VAR_NUMBER
         || this_var->di_tv.v_type == VAR_STRING)
        && var_flavour(this_var->di_key) == VAR_FLAVOUR_SESSION) {
      // Escape special characters with a backslash.  Turn a LF and
      // CR into \n and \r.
      char_u *const p = vim_strsave_escaped((const char_u *)tv_get_string(&this_var->di_tv),
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
    msg_puts(_("\n\tLast set from "));
    msg_puts((char *)p);
    if (last_set.script_ctx.sc_lnum > 0) {
      msg_puts(_(line_msg));
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

/// Adjust a filename, according to a string of modifiers.
/// *fnamep must be NUL terminated when called.  When returning, the length is
/// determined by *fnamelen.
/// Returns VALID_ flags or -1 for failure.
/// When there is an error, *fnamep is set to NULL.
///
/// @param src  string with modifiers
/// @param tilde_file  "~" is a file name, not $HOME
/// @param usedlen  characters after src that are used
/// @param fnamep  file name so far
/// @param bufp  buffer for allocated file name or NULL
/// @param fnamelen  length of fnamep
int modify_fname(char_u *src, bool tilde_file, size_t *usedlen, char_u **fnamep, char_u **bufp,
                 size_t *fnamelen)
{
  int valid = 0;
  char_u *tail;
  char_u *s, *p, *pbuf;
  char_u dirname[MAXPATHL];
  int c;
  int has_fullname = 0;

repeat:
  // ":p" - full path/file_name
  if (src[*usedlen] == ':' && src[*usedlen + 1] == 'p') {
    has_fullname = 1;

    valid |= VALID_PATH;
    *usedlen += 2;

    // Expand "~/path" for all systems and "~user/path" for Unix
    if ((*fnamep)[0] == '~'
#if !defined(UNIX)
        && ((*fnamep)[1] == '/'
# ifdef BACKSLASH_IN_FILENAME
            || (*fnamep)[1] == '\\'
# endif
            || (*fnamep)[1] == NUL)
#endif
        && !(tilde_file && (*fnamep)[1] == NUL)) {
      *fnamep = expand_env_save(*fnamep);
      xfree(*bufp);          // free any allocated file name
      *bufp = *fnamep;
      if (*fnamep == NULL) {
        return -1;
      }
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

    // FullName_save() is slow, don't use it when not needed.
    if (*p != NUL || !vim_isAbsName(*fnamep)) {
      *fnamep = (char_u *)FullName_save((char *)(*fnamep), *p != NUL);
      xfree(*bufp);          // free any allocated file name
      *bufp = *fnamep;
      if (*fnamep == NULL) {
        return -1;
      }
    }

    // Append a path separator to a directory.
    if (os_isdir(*fnamep)) {
      // Make room for one or two extra characters.
      *fnamep = vim_strnsave(*fnamep, STRLEN(*fnamep) + 2);
      xfree(*bufp);          // free any allocated file name
      *bufp = *fnamep;
      if (*fnamep == NULL) {
        return -1;
      }
      add_pathsep((char *)*fnamep);
    }
  }

  // ":." - path relative to the current directory
  // ":~" - path relative to the home directory
  // ":8" - shortname path - postponed till after
  while (src[*usedlen] == ':'
         && ((c = src[*usedlen + 1]) == '.' || c == '~' || c == '8')) {
    *usedlen += 2;
    if (c == '8') {
      continue;
    }
    pbuf = NULL;
    // Need full path first (use expand_env() to remove a "~/")
    if (!has_fullname) {
      if (c == '.' && **fnamep == '~') {
        p = pbuf = expand_env_save(*fnamep);
      } else {
        p = pbuf = (char_u *)FullName_save((char *)*fnamep, FALSE);
      }
    } else {
      p = *fnamep;
    }

    has_fullname = 0;

    if (p != NULL) {
      if (c == '.') {
        os_dirname(dirname, MAXPATHL);
        s = path_shorten_fname(p, dirname);
        if (s != NULL) {
          *fnamep = s;
          if (pbuf != NULL) {
            xfree(*bufp);               // free any allocated file name
            *bufp = pbuf;
            pbuf = NULL;
          }
        }
      } else {
        home_replace(NULL, p, dirname, MAXPATHL, true);
        // Only replace it when it starts with '~'
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

  // ":h" - head, remove "/file_name", can be repeated
  // Don't remove the first "/" or "c:\"
  while (src[*usedlen] == ':' && src[*usedlen + 1] == 'h') {
    valid |= VALID_HEAD;
    *usedlen += 2;
    s = get_past_head(*fnamep);
    while (tail > s && after_pathsep((char *)s, (char *)tail)) {
      MB_PTR_BACK(*fnamep, tail);
    }
    *fnamelen = (size_t)(tail - *fnamep);
    if (*fnamelen == 0) {
      // Result is empty.  Turn it into "." to make ":cd %:h" work.
      xfree(*bufp);
      *bufp = *fnamep = tail = vim_strsave((char_u *)".");
      *fnamelen = 1;
    } else {
      while (tail > s && !after_pathsep((char *)s, (char *)tail)) {
        MB_PTR_BACK(*fnamep, tail);
      }
    }
  }

  // ":8" - shortname
  if (src[*usedlen] == ':' && src[*usedlen + 1] == '8') {
    *usedlen += 2;
  }


  // ":t" - tail, just the basename
  if (src[*usedlen] == ':' && src[*usedlen + 1] == 't') {
    *usedlen += 2;
    *fnamelen -= (size_t)(tail - *fnamep);
    *fnamep = tail;
  }

  // ":e" - extension, can be repeated
  // ":r" - root, without extension, can be repeated
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

  // ":s?pat?foo?" - substitute
  // ":gs?pat?foo?" - global substitute
  if (src[*usedlen] == ':'
      && (src[*usedlen + 1] == 's'
          || (src[*usedlen + 1] == 'g' && src[*usedlen + 2] == 's'))) {
    int sep;
    char_u *flags;
    int didit = FALSE;

    flags = (char_u *)"";
    s = src + *usedlen + 2;
    if (src[*usedlen + 1] == 'g') {
      flags = (char_u *)"g";
      ++s;
    }

    sep = *s++;
    if (sep) {
      // find end of pattern
      p = vim_strchr(s, sep);
      if (p != NULL) {
        char_u *const pat = vim_strnsave(s, p - s);
        s = p + 1;
        // find end of substitution
        p = vim_strchr(s, sep);
        if (p != NULL) {
          char_u *const sub = vim_strnsave(s, p - s);
          char_u *const str = vim_strnsave(*fnamep, *fnamelen);
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
      // after using ":s", repeat all the modifiers
      if (didit) {
        goto repeat;
      }
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
char_u *do_string_sub(char_u *str, char_u *pat, char_u *sub, typval_T *expr, char_u *flags)
{
  int sublen;
  regmatch_T regmatch;
  int do_all;
  char_u *tail;
  char_u *end;
  garray_T ga;
  char_u *save_cpo;
  char_u *zero_width = NULL;

  // Make 'cpoptions' empty, so that the 'l' flag doesn't work here
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
      // Skip empty match except for first match.
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

      // copy the text up to where the match is
      int i = (int)(regmatch.startp[0] - tail);
      memmove((char_u *)ga.ga_data + ga.ga_len, tail, (size_t)i);
      // add the substituted text
      (void)vim_regsub(&regmatch, sub, expr, (char_u *)ga.ga_data
                       + ga.ga_len + i, true, true, false);
      ga.ga_len += i + sublen - 1;
      tail = regmatch.endp[0];
      if (*tail == NUL) {
        break;
      }
      if (!do_all) {
        break;
      }
    }

    if (ga.ga_data != NULL) {
      STRCPY((char *)ga.ga_data + ga.ga_len, tail);
    }

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
bool common_job_callbacks(dict_T *vopts, CallbackReader *on_stdout, CallbackReader *on_stderr,
                          Callback *on_exit)
{
  if (tv_dict_get_callback(vopts, S_LEN("on_stdout"), &on_stdout->cb)
      && tv_dict_get_callback(vopts, S_LEN("on_stderr"), &on_stderr->cb)
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
        emsg(_(e_invchanjob));
      } else {
        emsg(_(e_invchan));
      }
    }
    return NULL;
  }
  return data;
}


void script_host_eval(char *name, typval_T *argvars, typval_T *rettv)
{
  if (check_secure()) {
    return;
  }

  if (argvars[0].v_type != VAR_STRING) {
    emsg(_(e_invarg));
    return;
  }

  list_T *args = tv_list_alloc(1);
  tv_list_append_string(args, (const char *)argvars[0].vval.v_string, -1);
  *rettv = eval_call_provider(name, "eval", args, false);
}

/// @param discard  Clears the value returned by the provider and returns
///                 an empty typval_T.
typval_T eval_call_provider(char *provider, char *method, list_T *arguments, bool discard)
{
  if (!eval_has_provider(provider)) {
    semsg("E319: No \"%s\" provider found. Run \":checkhealth provider\"",
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
    .funccalp = (void *)get_current_funccal()
  };
  funccal_entry_T funccal_entry;
  save_funccal(&funccal_entry);
  provider_call_nesting++;

  typval_T argvars[3] = {
    { .v_type = VAR_STRING, .vval.v_string = (char_u *)method,
      .v_lock = VAR_UNLOCKED },
    { .v_type = VAR_LIST, .vval.v_list = arguments, .v_lock = VAR_UNLOCKED },
    { .v_type = VAR_UNKNOWN }
  };
  typval_T rettv = { .v_type = VAR_UNKNOWN, .v_lock = VAR_UNLOCKED };
  tv_list_ref(arguments);

  funcexe_T funcexe = FUNCEXE_INIT;
  funcexe.firstline = curwin->w_cursor.lnum;
  funcexe.lastline = curwin->w_cursor.lnum;
  funcexe.evaluate = true;
  (void)call_func((const char_u *)func, name_len, &rettv, 2, argvars, &funcexe);

  tv_list_unref(arguments);
  // Restore caller scope information
  restore_funccal();
  provider_caller_scope = saved_provider_caller_scope;
  provider_call_nesting--;
  assert(provider_call_nesting >= 0);

  if (discard) {
    tv_clear(&rettv);
  }

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
        semsg("provider: %s: missing required variable g:loaded_%s_provider",
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
      semsg("provider: %s: g:loaded_%s_provider=2 but %s is not defined",
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
      emsg(_("E5009: $VIMRUNTIME is empty or unset"));
    } else {
      bool rtp_ok = NULL != strstr((char *)p_rtp, vimruntime_env);
      if (rtp_ok) {
        semsg(_("E5009: Invalid $VIMRUNTIME: %s"), vimruntime_env);
      } else {
        emsg(_("E5009: Invalid 'runtimepath'"));
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
  ml_append(lnum, (char_u *)"", 0, false);
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

/// Compare "typ1" and "typ2".  Put the result in "typ1".
///
/// @param typ1  first operand
/// @param typ2  second operand
/// @param type  operator
/// @param ic  ignore case
int typval_compare(typval_T *typ1, typval_T *typ2, exprtype_T type, bool ic)
  FUNC_ATTR_NONNULL_ALL
{
  varnumber_T n1, n2;
  const bool type_is = type == EXPR_IS || type == EXPR_ISNOT;

  if (type_is && typ1->v_type != typ2->v_type) {
    // For "is" a different type always means false, for "notis"
    // it means true.
    n1 = type == EXPR_ISNOT;
  } else if (typ1->v_type == VAR_BLOB || typ2->v_type == VAR_BLOB) {
    if (type_is) {
      n1 = typ1->v_type == typ2->v_type
           && typ1->vval.v_blob == typ2->vval.v_blob;
      if (type == EXPR_ISNOT) {
        n1 = !n1;
      }
    } else if (typ1->v_type != typ2->v_type
               || (type != EXPR_EQUAL && type != EXPR_NEQUAL)) {
      if (typ1->v_type != typ2->v_type) {
        emsg(_("E977: Can only compare Blob with Blob"));
      } else {
        emsg(_(e_invalblob));
      }
      tv_clear(typ1);
      return FAIL;
    } else {
      // Compare two Blobs for being equal or unequal.
      n1 = tv_blob_equal(typ1->vval.v_blob, typ2->vval.v_blob);
      if (type == EXPR_NEQUAL) {
        n1 = !n1;
      }
    }
  } else if (typ1->v_type == VAR_LIST || typ2->v_type == VAR_LIST) {
    if (type_is) {
      n1 = typ1->v_type == typ2->v_type
           && typ1->vval.v_list == typ2->vval.v_list;
      if (type == EXPR_ISNOT) {
        n1 = !n1;
      }
    } else if (typ1->v_type != typ2->v_type
               || (type != EXPR_EQUAL && type != EXPR_NEQUAL)) {
      if (typ1->v_type != typ2->v_type) {
        emsg(_("E691: Can only compare List with List"));
      } else {
        emsg(_("E692: Invalid operation for List"));
      }
      tv_clear(typ1);
      return FAIL;
    } else {
      // Compare two Lists for being equal or unequal.
      n1 = tv_list_equal(typ1->vval.v_list, typ2->vval.v_list, ic, false);
      if (type == EXPR_NEQUAL) {
        n1 = !n1;
      }
    }
  } else if (typ1->v_type == VAR_DICT || typ2->v_type == VAR_DICT) {
    if (type_is) {
      n1 = typ1->v_type == typ2->v_type
           && typ1->vval.v_dict == typ2->vval.v_dict;
      if (type == EXPR_ISNOT) {
        n1 = !n1;
      }
    } else if (typ1->v_type != typ2->v_type
               || (type != EXPR_EQUAL && type != EXPR_NEQUAL)) {
      if (typ1->v_type != typ2->v_type) {
        emsg(_("E735: Can only compare Dictionary with Dictionary"));
      } else {
        emsg(_("E736: Invalid operation for Dictionary"));
      }
      tv_clear(typ1);
      return FAIL;
    } else {
      // Compare two Dictionaries for being equal or unequal.
      n1 = tv_dict_equal(typ1->vval.v_dict, typ2->vval.v_dict, ic, false);
      if (type == EXPR_NEQUAL) {
        n1 = !n1;
      }
    }
  } else if (tv_is_func(*typ1) || tv_is_func(*typ2)) {
    if (type != EXPR_EQUAL && type != EXPR_NEQUAL
        && type != EXPR_IS && type != EXPR_ISNOT) {
      emsg(_("E694: Invalid operation for Funcrefs"));
      tv_clear(typ1);
      return FAIL;
    }
    if ((typ1->v_type == VAR_PARTIAL && typ1->vval.v_partial == NULL)
        || (typ2->v_type == VAR_PARTIAL && typ2->vval.v_partial == NULL)) {
      // when a partial is NULL assume not equal
      n1 = false;
    } else if (type_is) {
      if (typ1->v_type == VAR_FUNC && typ2->v_type == VAR_FUNC) {
        // strings are considered the same if their value is
        // the same
        n1 = tv_equal(typ1, typ2, ic, false);
      } else if (typ1->v_type == VAR_PARTIAL && typ2->v_type == VAR_PARTIAL) {
        n1 = typ1->vval.v_partial == typ2->vval.v_partial;
      } else {
        n1 = false;
      }
    } else {
      n1 = tv_equal(typ1, typ2, ic, false);
    }
    if (type == EXPR_NEQUAL || type == EXPR_ISNOT) {
      n1 = !n1;
    }
  } else if ((typ1->v_type == VAR_FLOAT || typ2->v_type == VAR_FLOAT)
             && type != EXPR_MATCH && type != EXPR_NOMATCH) {
    // If one of the two variables is a float, compare as a float.
    // When using "=~" or "!~", always compare as string.
    const float_T f1 = tv_get_float(typ1);
    const float_T f2 = tv_get_float(typ2);
    n1 = false;
    switch (type) {
    case EXPR_IS:
    case EXPR_EQUAL:
      n1 = f1 == f2; break;
    case EXPR_ISNOT:
    case EXPR_NEQUAL:
      n1 = f1 != f2; break;
    case EXPR_GREATER:
      n1 = f1 > f2; break;
    case EXPR_GEQUAL:
      n1 = f1 >= f2; break;
    case EXPR_SMALLER:
      n1 = f1 < f2; break;
    case EXPR_SEQUAL:
      n1 = f1 <= f2; break;
    case EXPR_UNKNOWN:
    case EXPR_MATCH:
    case EXPR_NOMATCH:
      break;  // avoid gcc warning
    }
  } else if ((typ1->v_type == VAR_NUMBER || typ2->v_type == VAR_NUMBER)
             && type != EXPR_MATCH && type != EXPR_NOMATCH) {
    // If one of the two variables is a number, compare as a number.
    // When using "=~" or "!~", always compare as string.
    n1 = tv_get_number(typ1);
    n2 = tv_get_number(typ2);
    switch (type) {
    case EXPR_IS:
    case EXPR_EQUAL:
      n1 = n1 == n2; break;
    case EXPR_ISNOT:
    case EXPR_NEQUAL:
      n1 = n1 != n2; break;
    case EXPR_GREATER:
      n1 = n1 > n2; break;
    case EXPR_GEQUAL:
      n1 = n1 >= n2; break;
    case EXPR_SMALLER:
      n1 = n1 < n2; break;
    case EXPR_SEQUAL:
      n1 = n1 <= n2; break;
    case EXPR_UNKNOWN:
    case EXPR_MATCH:
    case EXPR_NOMATCH:
      break;  // avoid gcc warning
    }
  } else {
    char buf1[NUMBUFLEN];
    char buf2[NUMBUFLEN];
    const char *const s1 = tv_get_string_buf(typ1, buf1);
    const char *const s2 = tv_get_string_buf(typ2, buf2);
    int i;
    if (type != EXPR_MATCH && type != EXPR_NOMATCH) {
      i = mb_strcmp_ic(ic, s1, s2);
    } else {
      i = 0;
    }
    n1 = false;
    switch (type) {
    case EXPR_IS:
    case EXPR_EQUAL:
      n1 = i == 0; break;
    case EXPR_ISNOT:
    case EXPR_NEQUAL:
      n1 = i != 0; break;
    case EXPR_GREATER:
      n1 = i > 0; break;
    case EXPR_GEQUAL:
      n1 = i >= 0; break;
    case EXPR_SMALLER:
      n1 = i < 0; break;
    case EXPR_SEQUAL:
      n1 = i <= 0; break;

    case EXPR_MATCH:
    case EXPR_NOMATCH:
      n1 = pattern_match((char_u *)s2, (char_u *)s1, ic);
      if (type == EXPR_NOMATCH) {
        n1 = !n1;
      }
      break;
    case EXPR_UNKNOWN:
      break;  // avoid gcc warning
    }
  }
  tv_clear(typ1);
  typ1->v_type = VAR_NUMBER;
  typ1->vval.v_number = n1;
  return OK;
}

char *typval_tostring(typval_T *arg)
{
  if (arg == NULL) {
    return xstrdup("(does not exist)");
  }
  return encode_tv2string(arg, NULL);
}

bool var_exists(const char *var)
  FUNC_ATTR_NONNULL_ALL
{
  char *tofree;
  bool n = false;

  // get_name_len() takes care of expanding curly braces
  const char *name = var;
  const int len = get_name_len(&var, &tofree, true, false);
  if (len > 0) {
    typval_T tv;

    if (tofree != NULL) {
      name = tofree;
    }
    n = get_var_tv(name, len, &tv, NULL, false, true) == OK;
    if (n) {
      // Handle d.key, l[idx], f(expr).
      n = handle_subscript(&var, &tv, true, false, (const char_u *)name,
                           (const char_u **)&name)
          == OK;
      if (n) {
        tv_clear(&tv);
      }
    }
  }
  if (*var != NUL) {
    n = false;
  }

  xfree(tofree);
  return n;
}
