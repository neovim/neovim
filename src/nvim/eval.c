// eval.c: Expression evaluation.

#include <assert.h>
#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <uv.h>

#include "auto/config.h"
#include "nvim/api/private/converter.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/channel.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cmdhist.h"
#include "nvim/cursor.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/eval/encode.h"
#include "nvim/eval/executor.h"
#include "nvim/eval/gc.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/userfunc.h"
#include "nvim/eval/vars.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/event/process.h"
#include "nvim/event/time.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_getln.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid_defs.h"
#include "nvim/hashtab.h"
#include "nvim/highlight_group.h"
#include "nvim/insexpand.h"
#include "nvim/keycodes.h"
#include "nvim/lib/queue_defs.h"
#include "nvim/lua/executor.h"
#include "nvim/macros_defs.h"
#include "nvim/main.h"
#include "nvim/map_defs.h"
#include "nvim/mark.h"
#include "nvim/mark_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/msgpack_rpc/channel_defs.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/optionstr.h"
#include "nvim/os/fileio.h"
#include "nvim/os/fs.h"
#include "nvim/os/fs_defs.h"
#include "nvim/os/lang.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/shell.h"
#include "nvim/os/stdpaths_defs.h"
#include "nvim/path.h"
#include "nvim/pos_defs.h"
#include "nvim/profile.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/runtime.h"
#include "nvim/runtime_defs.h"
#include "nvim/search.h"
#include "nvim/strings.h"
#include "nvim/tag.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_compositor.h"
#include "nvim/ui_defs.h"
#include "nvim/usercmd.h"
#include "nvim/version.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

// TODO(ZyX-I): Remove DICT_MAXNEST, make users be non-recursive instead

#define DICT_MAXNEST 100        // maximum nesting of lists and dicts

static const char *e_missbrac = N_("E111: Missing ']'");
static const char *e_list_end = N_("E697: Missing end of List ']': %s");
static const char e_cannot_slice_dictionary[]
  = N_("E719: Cannot slice a Dictionary");
static const char e_cannot_index_special_variable[]
  = N_("E909: Cannot index a special variable");
static const char *e_nowhitespace
  = N_("E274: No white space allowed before parenthesis");
static const char *e_write2 = N_("E80: Error while writing: %s");
static const char e_cannot_index_a_funcref[]
  = N_("E695: Cannot index a Funcref");
static const char e_variable_nested_too_deep_for_making_copy[]
  = N_("E698: Variable nested too deep for making a copy");
static const char e_string_list_or_blob_required[]
  = N_("E1098: String, List or Blob required");
static const char e_expression_too_recursive_str[]
  = N_("E1169: Expression too recursive: %s");
static const char e_dot_can_only_be_used_on_dictionary_str[]
  = N_("E1203: Dot can only be used on a dictionary: %s");
static const char e_empty_function_name[]
  = N_("E1192: Empty function name");
static const char e_argument_of_str_must_be_list_string_dictionary_or_blob[]
  = N_("E1250: Argument of %s must be a List, String, Dictionary or Blob");

static char * const namespace_char = "abglstvw";

/// Variable used for g:
static ScopeDictDictItem globvars_var;

/// Old Vim variables such as "v:version" are also available without the "v:".
/// Also in functions.  We need a special hashtable for them.
static hashtab_T compat_hashtab;

/// Used for checking if local variables or arguments used in a lambda.
bool *eval_lavars_used = NULL;

#define SCRIPT_SV(id) (SCRIPT_ITEM(id)->sn_vars)
#define SCRIPT_VARS(id) (SCRIPT_SV(id)->sv_dict.dv_hashtab)

static int echo_attr = 0;   // attributes used for ":echo"

/// Info used by a ":for" loop.
typedef struct {
  int fi_semicolon;             // true if ending in '; var]'
  int fi_varcount;              // nr of variables in the list
  listwatch_T fi_lw;            // keep an eye on the item used.
  list_T *fi_list;              // list being used
  int fi_bi;                    // index of blob
  blob_T *fi_blob;              // blob being used
  char *fi_string;            // copy of string being used
  int fi_byte_idx;              // byte index in fi_string
} forinfo_T;

// values for vv_flags:
#define VV_COMPAT       1       // compatible, also used without "v:"
#define VV_RO           2       // read-only
#define VV_RO_SBX       4       // read-only in the sandbox

#define VV(idx, name, type, flags) \
  [idx] = { \
    .vv_name = (name), \
    .vv_di = { \
      .di_tv = { .v_type = (type) }, \
      .di_flags = 0, \
      .di_key = { 0 }, \
    }, \
    .vv_flags = (flags), \
  }

#define VIMVAR_KEY_LEN 16  // Maximum length of the key of v:variables

// Array to hold the value of v: variables.
// The value is in a dictitem, so that it can also be used in the v: scope.
// The reason to use this table anyway is for very quick access to the
// variables with the VV_ defines.
static struct vimvar {
  char *vv_name;  ///< Name of the variable, without v:.
  TV_DICTITEM_STRUCT(VIMVAR_KEY_LEN + 1) vv_di;  ///< Value and name for key (max 16 chars).
  char vv_flags;  ///< Flags: #VV_COMPAT, #VV_RO, #VV_RO_SBX.
} vimvars[] = {
  // VV_ tails differing from upcased string literals:
  // VV_CC_FROM "charconvert_from"
  // VV_CC_TO "charconvert_to"
  // VV_SEND_SERVER "servername"
  // VV_REG "register"
  // VV_OP "operator"
  VV(VV_COUNT,            "count",            VAR_NUMBER, VV_RO),
  VV(VV_COUNT1,           "count1",           VAR_NUMBER, VV_RO),
  VV(VV_PREVCOUNT,        "prevcount",        VAR_NUMBER, VV_RO),
  VV(VV_ERRMSG,           "errmsg",           VAR_STRING, 0),
  VV(VV_WARNINGMSG,       "warningmsg",       VAR_STRING, 0),
  VV(VV_STATUSMSG,        "statusmsg",        VAR_STRING, 0),
  VV(VV_SHELL_ERROR,      "shell_error",      VAR_NUMBER, VV_RO),
  VV(VV_THIS_SESSION,     "this_session",     VAR_STRING, 0),
  VV(VV_VERSION,          "version",          VAR_NUMBER, VV_COMPAT + VV_RO),
  VV(VV_LNUM,             "lnum",             VAR_NUMBER, VV_RO_SBX),
  VV(VV_TERMRESPONSE,     "termresponse",     VAR_STRING, VV_RO),
  VV(VV_TERMREQUEST,      "termrequest",      VAR_STRING, VV_RO),
  VV(VV_FNAME,            "fname",            VAR_STRING, VV_RO),
  VV(VV_LANG,             "lang",             VAR_STRING, VV_RO),
  VV(VV_LC_TIME,          "lc_time",          VAR_STRING, VV_RO),
  VV(VV_CTYPE,            "ctype",            VAR_STRING, VV_RO),
  VV(VV_CC_FROM,          "charconvert_from", VAR_STRING, VV_RO),
  VV(VV_CC_TO,            "charconvert_to",   VAR_STRING, VV_RO),
  VV(VV_FNAME_IN,         "fname_in",         VAR_STRING, VV_RO),
  VV(VV_FNAME_OUT,        "fname_out",        VAR_STRING, VV_RO),
  VV(VV_FNAME_NEW,        "fname_new",        VAR_STRING, VV_RO),
  VV(VV_FNAME_DIFF,       "fname_diff",       VAR_STRING, VV_RO),
  VV(VV_CMDARG,           "cmdarg",           VAR_STRING, VV_RO),
  VV(VV_FOLDSTART,        "foldstart",        VAR_NUMBER, VV_RO_SBX),
  VV(VV_FOLDEND,          "foldend",          VAR_NUMBER, VV_RO_SBX),
  VV(VV_FOLDDASHES,       "folddashes",       VAR_STRING, VV_RO_SBX),
  VV(VV_FOLDLEVEL,        "foldlevel",        VAR_NUMBER, VV_RO_SBX),
  VV(VV_PROGNAME,         "progname",         VAR_STRING, VV_RO),
  VV(VV_SEND_SERVER,      "servername",       VAR_STRING, VV_RO),
  VV(VV_DYING,            "dying",            VAR_NUMBER, VV_RO),
  VV(VV_EXCEPTION,        "exception",        VAR_STRING, VV_RO),
  VV(VV_THROWPOINT,       "throwpoint",       VAR_STRING, VV_RO),
  VV(VV_REG,              "register",         VAR_STRING, VV_RO),
  VV(VV_CMDBANG,          "cmdbang",          VAR_NUMBER, VV_RO),
  VV(VV_INSERTMODE,       "insertmode",       VAR_STRING, VV_RO),
  VV(VV_VAL,              "val",              VAR_UNKNOWN, VV_RO),
  VV(VV_KEY,              "key",              VAR_UNKNOWN, VV_RO),
  VV(VV_PROFILING,        "profiling",        VAR_NUMBER, VV_RO),
  VV(VV_FCS_REASON,       "fcs_reason",       VAR_STRING, VV_RO),
  VV(VV_FCS_CHOICE,       "fcs_choice",       VAR_STRING, 0),
  VV(VV_BEVAL_BUFNR,      "beval_bufnr",      VAR_NUMBER, VV_RO),
  VV(VV_BEVAL_WINNR,      "beval_winnr",      VAR_NUMBER, VV_RO),
  VV(VV_BEVAL_WINID,      "beval_winid",      VAR_NUMBER, VV_RO),
  VV(VV_BEVAL_LNUM,       "beval_lnum",       VAR_NUMBER, VV_RO),
  VV(VV_BEVAL_COL,        "beval_col",        VAR_NUMBER, VV_RO),
  VV(VV_BEVAL_TEXT,       "beval_text",       VAR_STRING, VV_RO),
  VV(VV_SCROLLSTART,      "scrollstart",      VAR_STRING, 0),
  VV(VV_SWAPNAME,         "swapname",         VAR_STRING, VV_RO),
  VV(VV_SWAPCHOICE,       "swapchoice",       VAR_STRING, 0),
  VV(VV_SWAPCOMMAND,      "swapcommand",      VAR_STRING, VV_RO),
  VV(VV_CHAR,             "char",             VAR_STRING, 0),
  VV(VV_MOUSE_WIN,        "mouse_win",        VAR_NUMBER, 0),
  VV(VV_MOUSE_WINID,      "mouse_winid",      VAR_NUMBER, 0),
  VV(VV_MOUSE_LNUM,       "mouse_lnum",       VAR_NUMBER, 0),
  VV(VV_MOUSE_COL,        "mouse_col",        VAR_NUMBER, 0),
  VV(VV_OP,               "operator",         VAR_STRING, VV_RO),
  VV(VV_SEARCHFORWARD,    "searchforward",    VAR_NUMBER, 0),
  VV(VV_HLSEARCH,         "hlsearch",         VAR_NUMBER, 0),
  VV(VV_OLDFILES,         "oldfiles",         VAR_LIST, 0),
  VV(VV_WINDOWID,         "windowid",         VAR_NUMBER, VV_RO_SBX),
  VV(VV_PROGPATH,         "progpath",         VAR_STRING, VV_RO),
  VV(VV_COMPLETED_ITEM,   "completed_item",   VAR_DICT, 0),
  VV(VV_OPTION_NEW,       "option_new",       VAR_STRING, VV_RO),
  VV(VV_OPTION_OLD,       "option_old",       VAR_STRING, VV_RO),
  VV(VV_OPTION_OLDLOCAL,  "option_oldlocal",  VAR_STRING, VV_RO),
  VV(VV_OPTION_OLDGLOBAL, "option_oldglobal", VAR_STRING, VV_RO),
  VV(VV_OPTION_COMMAND,   "option_command",   VAR_STRING, VV_RO),
  VV(VV_OPTION_TYPE,      "option_type",      VAR_STRING, VV_RO),
  VV(VV_ERRORS,           "errors",           VAR_LIST, 0),
  VV(VV_FALSE,            "false",            VAR_BOOL, VV_RO),
  VV(VV_TRUE,             "true",             VAR_BOOL, VV_RO),
  VV(VV_NULL,             "null",             VAR_SPECIAL, VV_RO),
  VV(VV_NUMBERMAX,        "numbermax",        VAR_NUMBER, VV_RO),
  VV(VV_NUMBERMIN,        "numbermin",        VAR_NUMBER, VV_RO),
  VV(VV_NUMBERSIZE,       "numbersize",       VAR_NUMBER, VV_RO),
  VV(VV_VIM_DID_ENTER,    "vim_did_enter",    VAR_NUMBER, VV_RO),
  VV(VV_TESTING,          "testing",          VAR_NUMBER, 0),
  VV(VV_TYPE_NUMBER,      "t_number",         VAR_NUMBER, VV_RO),
  VV(VV_TYPE_STRING,      "t_string",         VAR_NUMBER, VV_RO),
  VV(VV_TYPE_FUNC,        "t_func",           VAR_NUMBER, VV_RO),
  VV(VV_TYPE_LIST,        "t_list",           VAR_NUMBER, VV_RO),
  VV(VV_TYPE_DICT,        "t_dict",           VAR_NUMBER, VV_RO),
  VV(VV_TYPE_FLOAT,       "t_float",          VAR_NUMBER, VV_RO),
  VV(VV_TYPE_BOOL,        "t_bool",           VAR_NUMBER, VV_RO),
  VV(VV_TYPE_BLOB,        "t_blob",           VAR_NUMBER, VV_RO),
  VV(VV_EVENT,            "event",            VAR_DICT, VV_RO),
  VV(VV_ECHOSPACE,        "echospace",        VAR_NUMBER, VV_RO),
  VV(VV_ARGV,             "argv",             VAR_LIST, VV_RO),
  VV(VV_COLLATE,          "collate",          VAR_STRING, VV_RO),
  VV(VV_EXITING,          "exiting",          VAR_NUMBER, VV_RO),
  VV(VV_MAXCOL,           "maxcol",           VAR_NUMBER, VV_RO),
  // Neovim
  VV(VV_STDERR,           "stderr",           VAR_NUMBER, VV_RO),
  VV(VV_MSGPACK_TYPES,    "msgpack_types",    VAR_DICT, VV_RO),
  VV(VV__NULL_STRING,     "_null_string",     VAR_STRING, VV_RO),
  VV(VV__NULL_LIST,       "_null_list",       VAR_LIST, VV_RO),
  VV(VV__NULL_DICT,       "_null_dict",       VAR_DICT, VV_RO),
  VV(VV__NULL_BLOB,       "_null_blob",       VAR_BLOB, VV_RO),
  VV(VV_LUA,              "lua",              VAR_PARTIAL, VV_RO),
  VV(VV_RELNUM,           "relnum",           VAR_NUMBER, VV_RO),
  VV(VV_VIRTNUM,          "virtnum",          VAR_NUMBER, VV_RO),
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

/// Enum used by filter(), map(), mapnew() and foreach()
typedef enum {
  FILTERMAP_FILTER,
  FILTERMAP_MAP,
  FILTERMAP_MAPNEW,
  FILTERMAP_FOREACH,
} filtermap_T;

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

dict_T *get_v_event(save_v_event_T *sve)
{
  dict_T *v_event = get_vim_var_dict(VV_EVENT);

  if (v_event->dv_hashtab.ht_used > 0) {
    // recursive use of v:event, save, make empty and restore later
    sve->sve_did_save = true;
    sve->sve_hashtab = v_event->dv_hashtab;
    hash_init(&v_event->dv_hashtab);
  } else {
    sve->sve_did_save = false;
  }
  return v_event;
}

void restore_v_event(dict_T *v_event, save_v_event_T *sve)
{
  tv_dict_free_contents(v_event);
  if (sve->sve_did_save) {
    v_event->dv_hashtab = sve->sve_hashtab;
  } else {
    hash_init(&v_event->dv_hashtab);
  }
}

/// @return  "n1" divided by "n2", taking care of dividing by zero.
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
  } else if (n1 == VARNUMBER_MIN && n2 == -1) {
    // specific case: trying to do VARNUMBAR_MIN / -1 results in a positive
    // number that doesn't fit in varnumber_T and causes an FPE
    result = VARNUMBER_MAX;
  } else {
    result = n1 / n2;
  }

  return result;
}

/// @return  "n1" modulus "n2", taking care of dividing by zero.
varnumber_T num_modulus(varnumber_T n1, varnumber_T n2)
  FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  // Give an error when n2 is 0?
  return (n2 == 0) ? 0 : (n1 % n2);
}

/// Initialize the global and v: variables.
void eval_init(void)
{
  vimvars[VV_VERSION].vv_nr = VIM_VERSION_100;

  init_var_dict(&globvardict, &globvars_var, VAR_DEF_SCOPE);
  init_var_dict(&vimvardict, &vimvars_var, VAR_SCOPE);
  vimvardict.dv_lock = VAR_FIXED;
  hash_init(&compat_hashtab);
  func_init();

  for (size_t i = 0; i < ARRAY_SIZE(vimvars); i++) {
    struct vimvar *p = &vimvars[i];
    assert(strlen(p->vv_name) <= VIMVAR_KEY_LEN);
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
  set_vim_var_nr(VV_SEARCHFORWARD, 1);
  set_vim_var_nr(VV_HLSEARCH, 1);
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
  set_vim_var_nr(VV_MAXCOL, MAXCOL);

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
static void evalvars_clear(void)
{
  for (size_t i = 0; i < ARRAY_SIZE(vimvars); i++) {
    struct vimvar *p = &vimvars[i];
    if (p->vv_di.di_tv.v_type == VAR_STRING) {
      XFREE_CLEAR(p->vv_str);
    } else if (p->vv_di.di_tv.v_type == VAR_LIST) {
      tv_list_unref(p->vv_list);
      p->vv_list = NULL;
    }
  }

  partial_unref(vvlua_partial);
  vimvars[VV_LUA].vv_partial = vvlua_partial = NULL;

  hash_clear(&vimvarht);
  hash_init(&vimvarht);    // garbage_collect() will access it
  hash_clear(&compat_hashtab);

  // global variables
  vars_clear(&globvarht);

  // Script-local variables. Clear all the variables here.
  // The scriptvar_T is cleared later in free_scriptnames(), because a
  // variable in one script might hold a reference to the whole scope of
  // another script.
  for (int i = 1; i <= script_items.ga_len; i++) {
    vars_clear(&SCRIPT_VARS(i));
  }
}

void eval_clear(void)
{
  evalvars_clear();
  free_scriptnames();  // must come after evalvars_clear().
# ifdef HAVE_WORKING_LIBINTL
  free_locales();
# endif

  // autoloaded script names
  free_autoload_scriptnames();

  // unreferenced lists and dicts
  garbage_collect(false);

  // functions not garbage collected
  free_all_functions();
}

#endif

/// Set an internal variable to a string value. Creates the variable if it does
/// not already exist.
void set_internal_string_var(const char *name, char *value)  // NOLINT(readability-non-const-parameter)
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
static char *redir_endp = NULL;
static char *redir_varname = NULL;

/// Start recording command output to a variable
///
/// @param append  append to an existing variable
///
/// @return  OK if successfully completed the setup.  FAIL otherwise.
int var_redir_start(char *name, bool append)
{
  // Catch a bad name early.
  if (!eval_isnamec1(*name)) {
    emsg(_(e_invarg));
    return FAIL;
  }

  // Make a copy of the name, it is used in redir_lval until redir ends.
  redir_varname = xstrdup(name);

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
      semsg(_(e_trailing_arg), redir_endp);
    } else {
      semsg(_(e_invarg2), name);
    }
    redir_endp = NULL;      // don't store a value, only cleanup
    var_redir_stop();
    return FAIL;
  }

  // check if we can write to the variable: set it to or append an empty
  // string
  const int called_emsg_before = called_emsg;
  did_emsg = false;
  typval_T tv;
  tv.v_type = VAR_STRING;
  tv.vval.v_string = "";
  if (append) {
    set_var_lval(redir_lval, redir_endp, &tv, true, false, ".");
  } else {
    set_var_lval(redir_lval, redir_endp, &tv, true, false, "=");
  }
  clear_lval(redir_lval);
  if (called_emsg > called_emsg_before) {
    redir_endp = NULL;      // don't store a value, only cleanup
    var_redir_stop();
    return FAIL;
  }

  return OK;
}

/// Append "value[value_len]" to the variable set by var_redir_start().
/// The actual appending is postponed until redirection ends, because the value
/// appended may in fact be the string we write to, changing it may cause freed
/// memory to be used:
///   :redir => foo
///   :let foo
///   :redir END
void var_redir_str(const char *value, int value_len)
{
  if (redir_lval == NULL) {
    return;
  }

  int len;
  if (value_len == -1) {
    len = (int)strlen(value);           // Append the entire string
  } else {
    len = value_len;                    // Append only "value_len" characters
  }

  ga_grow(&redir_ga, len);
  memmove((char *)redir_ga.ga_data + redir_ga.ga_len, value, (size_t)len);
  redir_ga.ga_len += len;
}

/// Stop redirecting command output to a variable.
/// Frees the allocated memory.
void var_redir_stop(void)
{
  if (redir_lval != NULL) {
    // If there was no error: assign the text to the variable.
    if (redir_endp != NULL) {
      ga_append(&redir_ga, NUL);        // Append the trailing NUL.
      typval_T tv;
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
  const sctx_T saved_sctx = current_sctx;

  set_vim_var_string(VV_CC_FROM, enc_from, -1);
  set_vim_var_string(VV_CC_TO, enc_to, -1);
  set_vim_var_string(VV_FNAME_IN, fname_from, -1);
  set_vim_var_string(VV_FNAME_OUT, fname_to, -1);
  sctx_T *ctx = get_option_sctx(kOptCharconvert);
  if (ctx != NULL) {
    current_sctx = *ctx;
  }

  bool err = false;
  if (eval_to_bool(p_ccv, &err, NULL, false)) {
    err = true;
  }

  set_vim_var_string(VV_CC_FROM, NULL, -1);
  set_vim_var_string(VV_CC_TO, NULL, -1);
  set_vim_var_string(VV_FNAME_IN, NULL, -1);
  set_vim_var_string(VV_FNAME_OUT, NULL, -1);
  current_sctx = saved_sctx;

  if (err) {
    return FAIL;
  }
  return OK;
}

void eval_diff(const char *const origfile, const char *const newfile, const char *const outfile)
{
  const sctx_T saved_sctx = current_sctx;
  set_vim_var_string(VV_FNAME_IN, origfile, -1);
  set_vim_var_string(VV_FNAME_NEW, newfile, -1);
  set_vim_var_string(VV_FNAME_OUT, outfile, -1);

  sctx_T *ctx = get_option_sctx(kOptDiffexpr);
  if (ctx != NULL) {
    current_sctx = *ctx;
  }

  // errors are ignored
  typval_T *tv = eval_expr(p_dex, NULL);
  tv_free(tv);

  set_vim_var_string(VV_FNAME_IN, NULL, -1);
  set_vim_var_string(VV_FNAME_NEW, NULL, -1);
  set_vim_var_string(VV_FNAME_OUT, NULL, -1);
  current_sctx = saved_sctx;
}

void eval_patch(const char *const origfile, const char *const difffile, const char *const outfile)
{
  const sctx_T saved_sctx = current_sctx;
  set_vim_var_string(VV_FNAME_IN, origfile, -1);
  set_vim_var_string(VV_FNAME_DIFF, difffile, -1);
  set_vim_var_string(VV_FNAME_OUT, outfile, -1);

  sctx_T *ctx = get_option_sctx(kOptPatchexpr);
  if (ctx != NULL) {
    current_sctx = *ctx;
  }

  // errors are ignored
  typval_T *tv = eval_expr(p_pex, NULL);
  tv_free(tv);

  set_vim_var_string(VV_FNAME_IN, NULL, -1);
  set_vim_var_string(VV_FNAME_DIFF, NULL, -1);
  set_vim_var_string(VV_FNAME_OUT, NULL, -1);
  current_sctx = saved_sctx;
}

void fill_evalarg_from_eap(evalarg_T *evalarg, exarg_T *eap, bool skip)
{
  *evalarg = (evalarg_T){ .eval_flags = skip ? 0 : EVAL_EVALUATE };

  if (eap == NULL) {
    return;
  }

  if (getline_equal(eap->ea_getline, eap->cookie, getsourceline)) {
    evalarg->eval_getline = eap->ea_getline;
    evalarg->eval_cookie = eap->cookie;
  }
}

/// Top level evaluation function, returning a boolean.
/// Sets "error" to true if there was an error.
///
/// @param skip  only parse, don't execute
///
/// @return  true or false.
bool eval_to_bool(char *arg, bool *error, exarg_T *eap, bool skip)
{
  typval_T tv;
  bool retval = false;
  evalarg_T evalarg;

  fill_evalarg_from_eap(&evalarg, eap, skip);

  if (skip) {
    emsg_skip++;
  }
  if (eval0(arg, &tv, eap, &evalarg) == FAIL) {
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
  clear_evalarg(&evalarg, eap);

  return retval;
}

/// Call eval1() and give an error message if not done at a lower level.
static int eval1_emsg(char **arg, typval_T *rettv, exarg_T *eap)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  const char *const start = *arg;
  const int did_emsg_before = did_emsg;
  const int called_emsg_before = called_emsg;
  evalarg_T evalarg;

  fill_evalarg_from_eap(&evalarg, eap, eap != NULL && eap->skip);

  const int ret = eval1(arg, rettv, &evalarg);
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
  clear_evalarg(&evalarg, eap);
  return ret;
}

/// @return  whether a typval is a valid expression to pass to eval_expr_typval()
///          or eval_expr_to_bool().  An empty string returns false;
bool eval_expr_valid_arg(const typval_T *const tv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_CONST
{
  return tv->v_type != VAR_UNKNOWN
         && (tv->v_type != VAR_STRING || (tv->vval.v_string != NULL && *tv->vval.v_string != NUL));
}

/// Evaluate an expression, which can be a function, partial or string.
/// Pass arguments "argv[argc]".
/// Return the result in "rettv" and OK or FAIL.
///
/// @param want_func  if true, treat a string as a function name, not an expression
int eval_expr_typval(const typval_T *expr, bool want_func, typval_T *argv, int argc,
                     typval_T *rettv)
  FUNC_ATTR_NONNULL_ALL
{
  char buf[NUMBUFLEN];
  funcexe_T funcexe = FUNCEXE_INIT;

  if (expr->v_type == VAR_PARTIAL) {
    partial_T *const partial = expr->vval.v_partial;
    if (partial == NULL) {
      return FAIL;
    }
    const char *const s = partial_name(partial);
    if (s == NULL || *s == NUL) {
      return FAIL;
    }
    funcexe.fe_evaluate = true;
    funcexe.fe_partial = partial;
    if (call_func(s, -1, rettv, argc, argv, &funcexe) == FAIL) {
      return FAIL;
    }
  } else if (expr->v_type == VAR_FUNC || want_func) {
    const char *const s = (expr->v_type == VAR_FUNC
                           ? expr->vval.v_string
                           : tv_get_string_buf_chk(expr, buf));
    if (s == NULL || *s == NUL) {
      return FAIL;
    }
    funcexe.fe_evaluate = true;
    if (call_func(s, -1, rettv, argc, argv, &funcexe) == FAIL) {
      return FAIL;
    }
  } else {
    char *s = (char *)tv_get_string_buf_chk(expr, buf);
    if (s == NULL) {
      return FAIL;
    }
    s = skipwhite(s);
    if (eval1_emsg(&s, rettv, NULL) == FAIL) {
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

  if (eval_expr_typval(expr, false, &argv, 0, &rettv) == FAIL) {
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
/// @param[in]  skip  If true, only do parsing to nextcmd without reporting
///                   errors or actually evaluating anything.
///
/// @return [allocated] string result of evaluation or NULL in case of error or
///                     when skipping.
char *eval_to_string_skip(char *arg, exarg_T *eap, const bool skip)
  FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_WARN_UNUSED_RESULT
{
  typval_T tv;
  char *retval;
  evalarg_T evalarg;

  fill_evalarg_from_eap(&evalarg, eap, skip);
  if (skip) {
    emsg_skip++;
  }
  if (eval0(arg, &tv, eap, &evalarg) == FAIL || skip) {
    retval = NULL;
  } else {
    retval = xstrdup(tv_get_string(&tv));
    tv_clear(&tv);
  }
  if (skip) {
    emsg_skip--;
  }
  clear_evalarg(&evalarg, eap);

  return retval;
}

/// Skip over an expression at "*pp".
///
/// @return  FAIL for an error, OK otherwise.
int skip_expr(char **pp, evalarg_T *const evalarg)
{
  const int save_flags = evalarg == NULL ? 0 : evalarg->eval_flags;

  // Don't evaluate the expression.
  if (evalarg != NULL) {
    evalarg->eval_flags &= ~EVAL_EVALUATE;
  }

  *pp = skipwhite(*pp);
  typval_T rettv;
  int res = eval1(pp, &rettv, NULL);

  if (evalarg != NULL) {
    evalarg->eval_flags = save_flags;
  }

  return res;
}

/// Convert "tv" to a string.
///
/// @param convert  when true convert a List into a sequence of lines
///                 and a Dict into a textual representation of the Dict.
///
/// @return  an allocated string.
static char *typval2string(typval_T *tv, bool convert)
{
  if (convert && tv->v_type == VAR_LIST) {
    garray_T ga;
    ga_init(&ga, (int)sizeof(char), 80);
    if (tv->vval.v_list != NULL) {
      tv_list_join(&ga, tv->vval.v_list, "\n");
      if (tv_list_len(tv->vval.v_list) > 0) {
        ga_append(&ga, NL);
      }
    }
    ga_append(&ga, NUL);
    return (char *)ga.ga_data;
  } else if (convert && tv->v_type == VAR_DICT) {
    return encode_tv2string(tv, NULL);
  }
  return xstrdup(tv_get_string(tv));
}

/// Top level evaluation function, returning a string.
///
/// @param convert  when true convert a List into a sequence of lines.
///
/// @return  pointer to allocated memory, or NULL for failure.
char *eval_to_string(char *arg, bool convert)
{
  typval_T tv;
  char *retval;

  if (eval0(arg, &tv, NULL, &EVALARG_EVALUATE) == FAIL) {
    retval = NULL;
  } else {
    retval = typval2string(&tv, convert);
    tv_clear(&tv);
  }
  clear_evalarg(&EVALARG_EVALUATE, NULL);

  return retval;
}

/// Call eval_to_string() without using current local variables and using
/// textlock.
///
/// @param use_sandbox  when true, use the sandbox.
char *eval_to_string_safe(char *arg, const bool use_sandbox)
{
  char *retval;
  funccal_entry_T funccal_entry;

  save_funccal(&funccal_entry);
  if (use_sandbox) {
    sandbox++;
  }
  textlock++;
  retval = eval_to_string(arg, false);
  if (use_sandbox) {
    sandbox--;
  }
  textlock--;
  restore_funccal();
  return retval;
}

/// Top level evaluation function, returning a number.
/// Evaluates "expr" silently.
///
/// @return  -1 for an error.
varnumber_T eval_to_number(char *expr)
{
  typval_T rettv;
  varnumber_T retval;
  char *p = skipwhite(expr);

  emsg_off++;

  if (eval1(&p, &rettv, &EVALARG_EVALUATE) == FAIL) {
    retval = -1;
  } else {
    retval = tv_get_number_chk(&rettv, NULL);
    tv_clear(&rettv);
  }
  emsg_off--;

  return retval;
}

/// Top level evaluation function.
///
/// @return  an allocated typval_T with the result or
///          NULL when there is an error.
typval_T *eval_expr(char *arg, exarg_T *eap)
{
  typval_T *tv = xmalloc(sizeof(*tv));
  evalarg_T evalarg;

  fill_evalarg_from_eap(&evalarg, eap, eap != NULL && eap->skip);

  if (eval0(arg, tv, eap, &evalarg) == FAIL) {
    XFREE_CLEAR(tv);
  }

  clear_evalarg(&evalarg, eap);
  return tv;
}

/// List Vim variables.
void list_vim_vars(int *first)
{
  list_hashtable_vars(&vimvarht, "v:", false, first);
}

/// List script-local variables, if there is a script.
void list_script_vars(int *first)
{
  if (current_sctx.sc_sid > 0 && current_sctx.sc_sid <= script_items.ga_len) {
    list_hashtable_vars(&SCRIPT_VARS(current_sctx.sc_sid), "s:", false, first);
  }
}

bool is_vimvarht(const hashtab_T *ht)
{
  return ht == &vimvarht;
}

bool is_compatht(const hashtab_T *ht)
{
  return ht == &compat_hashtab;
}

/// Prepare v: variable "idx" to be used.
/// Save the current typeval in "save_tv" and clear it.
/// When not used yet add the variable to the v: hashtable.
void prepare_vimvar(int idx, typval_T *save_tv)
{
  *save_tv = vimvars[idx].vv_tv;
  vimvars[idx].vv_str = NULL;  // don't free it now
  if (vimvars[idx].vv_type == VAR_UNKNOWN) {
    hash_add(&vimvarht, vimvars[idx].vv_di.di_key);
  }
}

/// Restore v: variable "idx" to typeval "save_tv".
/// Note that the v: variable must have been cleared already.
/// When no longer defined, remove the variable from the v: hashtable.
void restore_vimvar(int idx, typval_T *save_tv)
{
  vimvars[idx].vv_tv = *save_tv;
  if (vimvars[idx].vv_type != VAR_UNKNOWN) {
    return;
  }

  hashitem_T *hi = hash_find(&vimvarht, vimvars[idx].vv_di.di_key);
  if (HASHITEM_EMPTY(hi)) {
    internal_error("restore_vimvar()");
  } else {
    hash_remove(&vimvarht, hi);
  }
}

/// Evaluate an expression to a list with suggestions.
/// For the "expr:" part of 'spellsuggest'.
///
/// @return  NULL when there is an error.
list_T *eval_spell_expr(char *badword, char *expr)
{
  typval_T save_val;
  typval_T rettv;
  list_T *list = NULL;
  char *p = skipwhite(expr);
  const sctx_T saved_sctx = current_sctx;

  // Set "v:val" to the bad word.
  prepare_vimvar(VV_VAL, &save_val);
  vimvars[VV_VAL].vv_type = VAR_STRING;
  vimvars[VV_VAL].vv_str = badword;
  if (p_verbose == 0) {
    emsg_off++;
  }
  sctx_T *ctx = get_option_sctx(kOptSpellsuggest);
  if (ctx != NULL) {
    current_sctx = *ctx;
  }

  if (eval1(&p, &rettv, &EVALARG_EVALUATE) == OK) {
    if (rettv.v_type != VAR_LIST) {
      tv_clear(&rettv);
    } else {
      list = rettv.vval.v_list;
    }
  }

  if (p_verbose == 0) {
    emsg_off--;
  }
  restore_vimvar(VV_VAL, &save_val);
  current_sctx = saved_sctx;

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
  return (int)tv_list_find_nr(list, -1, NULL);
}

/// Call some Vim script function and return the result in "*rettv".
/// Uses argv[0] to argv[argc - 1] for the function arguments. argv[argc]
/// should have type VAR_UNKNOWN.
///
/// @return  OK or FAIL.
int call_vim_function(const char *func, int argc, typval_T *argv, typval_T *rettv)
  FUNC_ATTR_NONNULL_ALL
{
  int ret;
  int len = (int)strlen(func);
  partial_T *pt = NULL;

  if (len >= 6 && !memcmp(func, "v:lua.", 6)) {
    func += 6;
    len = check_luafunc_name(func, false);
    if (len == 0) {
      ret = FAIL;
      goto fail;
    }
    pt = vvlua_partial;
  }

  rettv->v_type = VAR_UNKNOWN;  // tv_clear() uses this.
  funcexe_T funcexe = FUNCEXE_INIT;
  funcexe.fe_firstline = curwin->w_cursor.lnum;
  funcexe.fe_lastline = curwin->w_cursor.lnum;
  funcexe.fe_evaluate = true;
  funcexe.fe_partial = pt;
  ret = call_func(func, len, rettv, argc, argv, &funcexe);

fail:
  if (ret == FAIL) {
    tv_clear(rettv);
  }

  return ret;
}

/// Call Vim script function and return the result as a string.
/// Uses "argv[0]" to "argv[argc - 1]" for the function arguments. "argv[argc]"
/// should have type VAR_UNKNOWN.
///
/// @param[in]  func  Function name.
/// @param[in]  argc  Number of arguments.
/// @param[in]  argv  Array with typval_T arguments.
///
/// @return [allocated] NULL when calling function fails, allocated string
///                     otherwise.
void *call_func_retstr(const char *const func, int argc, typval_T *argv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_MALLOC
{
  typval_T rettv;
  // All arguments are passed as strings, no conversion to number.
  if (call_vim_function(func, argc, argv, &rettv)
      == FAIL) {
    return NULL;
  }

  char *const retval = xstrdup(tv_get_string(&rettv));
  tv_clear(&rettv);
  return retval;
}

/// Call Vim script function and return the result as a List.
/// Uses "argv" and "argc" as call_func_retstr().
///
/// @param[in]  func  Function name.
/// @param[in]  argc  Number of arguments.
/// @param[in]  argv  Array with typval_T arguments.
///
/// @return [allocated] NULL when calling function fails or return tv is not a
///                     List, allocated List otherwise.
void *call_func_retlist(const char *func, int argc, typval_T *argv)
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

/// Evaluate 'foldexpr'.  Returns the foldlevel, and any character preceding
/// it in "*cp".  Doesn't give error messages.
int eval_foldexpr(win_T *wp, int *cp)
{
  const sctx_T saved_sctx = current_sctx;
  const bool use_sandbox = was_set_insecurely(wp, kOptFoldexpr, OPT_LOCAL);

  char *arg = wp->w_p_fde;
  current_sctx = wp->w_p_script_ctx[WV_FDE].script_ctx;

  emsg_off++;
  if (use_sandbox) {
    sandbox++;
  }
  textlock++;
  *cp = NUL;

  typval_T tv;
  varnumber_T retval;
  if (eval0(arg, &tv, NULL, &EVALARG_EVALUATE) == FAIL) {
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
      char *s = tv.vval.v_string;
      if (*s != NUL && !ascii_isdigit(*s) && *s != '-') {
        *cp = (uint8_t)(*s++);
      }
      retval = atol(s);
    }
    tv_clear(&tv);
  }

  emsg_off--;
  if (use_sandbox) {
    sandbox--;
  }
  textlock--;
  clear_evalarg(&EVALARG_EVALUATE, NULL);
  current_sctx = saved_sctx;

  return (int)retval;
}

/// Evaluate 'foldtext', returning an Array or a String (NULL_STRING on failure).
Object eval_foldtext(win_T *wp)
{
  const bool use_sandbox = was_set_insecurely(wp, kOptFoldtext, OPT_LOCAL);
  char *arg = wp->w_p_fdt;
  funccal_entry_T funccal_entry;

  save_funccal(&funccal_entry);
  if (use_sandbox) {
    sandbox++;
  }
  textlock++;

  typval_T tv;
  Object retval;
  if (eval0(arg, &tv, NULL, &EVALARG_EVALUATE) == FAIL) {
    retval = STRING_OBJ(NULL_STRING);
  } else {
    if (tv.v_type == VAR_LIST) {
      retval = vim_to_object(&tv, NULL, false);
    } else {
      retval = STRING_OBJ(cstr_to_string(tv_get_string(&tv)));
    }
    tv_clear(&tv);
  }
  clear_evalarg(&EVALARG_EVALUATE, NULL);

  if (use_sandbox) {
    sandbox--;
  }
  textlock--;
  restore_funccal();

  return retval;
}

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
char *get_lval(char *const name, typval_T *const rettv, lval_T *const lp, const bool unlet,
               const bool skip, const int flags, const int fne_flags)
  FUNC_ATTR_NONNULL_ARG(1, 3)
{
  bool empty1 = false;
  int quiet = flags & GLV_QUIET;

  // Clear everything in "lp".
  CLEAR_POINTER(lp);

  if (skip) {
    // When skipping just find the end of the name.
    lp->ll_name = name;
    return (char *)find_name_end(name, NULL, NULL, FNE_INCL_BR | fne_flags);
  }

  // Find the end of the name.
  char *expr_start;
  char *expr_end;
  char *p = (char *)find_name_end(name, (const char **)&expr_start,
                                  (const char **)&expr_end,
                                  fne_flags);
  if (expr_start != NULL) {
    // Don't expand the name when we already know there is an error.
    if (unlet && !ascii_iswhite(*p) && !ends_excmd(*p)
        && *p != '[' && *p != '.') {
      semsg(_(e_trailing_arg), p);
      return NULL;
    }

    lp->ll_exp_name = make_expanded_name(name, expr_start, expr_end, p);
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
    lp->ll_name = name;
    lp->ll_name_len = (size_t)(p - lp->ll_name);
  }

  // Without [idx] or .key we are done.
  if ((*p != '[' && *p != '.') || lp->ll_name == NULL) {
    return p;
  }

  hashtab_T *ht = NULL;

  // Only pass &ht when we would write to the variable, it prevents autoload
  // as well.
  dictitem_T *v = find_var(lp->ll_name, lp->ll_name_len,
                           (flags & GLV_READ_ONLY) ? NULL : &ht,
                           flags & GLV_NO_AUTOLOAD);
  if (v == NULL && !quiet) {
    semsg(_("E121: Undefined variable: %.*s"),
          (int)lp->ll_name_len, lp->ll_name);
  }
  if (v == NULL) {
    return NULL;
  }

  lp->ll_tv = &v->di_tv;

  if (tv_is_luafunc(lp->ll_tv)) {
    // For v:lua just return a pointer to the "." after the "v:lua".
    // If the caller is trans_function_name() it will check for a Lua function name.
    return p;
  }

  // Loop until no more [idx] or .key is following.
  typval_T var1;
  var1.v_type = VAR_UNKNOWN;
  typval_T var2;
  var2.v_type = VAR_UNKNOWN;
  while (*p == '[' || (*p == '.' && p[1] != '=' && p[1] != '.')) {
    if (*p == '.' && lp->ll_tv->v_type != VAR_DICT) {
      if (!quiet) {
        semsg(_(e_dot_can_only_be_used_on_dictionary_str), name);
      }
      return NULL;
    }
    if (lp->ll_tv->v_type != VAR_LIST
        && lp->ll_tv->v_type != VAR_DICT
        && lp->ll_tv->v_type != VAR_BLOB) {
      if (!quiet) {
        emsg(_("E689: Can only index a List, Dictionary or Blob"));
      }
      return NULL;
    }

    // a NULL list/blob works like an empty list/blob, allocate one now.
    if (lp->ll_tv->v_type == VAR_LIST && lp->ll_tv->vval.v_list == NULL) {
      tv_list_alloc_ret(lp->ll_tv, kListLenUnknown);
    } else if (lp->ll_tv->v_type == VAR_BLOB && lp->ll_tv->vval.v_blob == NULL) {
      tv_blob_alloc_ret(lp->ll_tv);
    }

    if (lp->ll_range) {
      if (!quiet) {
        emsg(_("E708: [:] must come last"));
      }
      return NULL;
    }

    int len = -1;
    char *key = NULL;
    if (*p == '.') {
      key = p + 1;
      for (len = 0; ASCII_ISALNUM(key[len]) || key[len] == '_'; len++) {}
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
        if (eval1(&p, &var1, &EVALARG_EVALUATE) == FAIL) {  // Recursive!
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
            emsg(_(e_cannot_slice_dictionary));
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
          // Recursive!
          if (eval1(&p, &var2, &EVALARG_EVALUATE) == FAIL) {
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
        key = (char *)tv_get_string(&var1);  // is number or string
      }
      lp->ll_list = NULL;
      lp->ll_dict = lp->ll_tv->vval.v_dict;
      lp->ll_di = tv_dict_find(lp->ll_dict, key, len);

      // When assigning to a scope dictionary check that a function and
      // variable name is valid (only variable name unless it is l: or
      // g: dictionary). Disallow overwriting a builtin function.
      if (rettv != NULL && lp->ll_dict->dv_scope != 0) {
        char prevval;
        if (len != -1) {
          prevval = key[len];
          key[len] = NUL;
        } else {
          prevval = 0;  // Avoid compiler warning.
        }
        bool wrong = ((lp->ll_dict->dv_scope == VAR_DEF_SCOPE
                       && tv_is_func(*rettv)
                       && var_wrong_func_name(key, lp->ll_di == NULL))
                      || !valid_varname(key));
        if (len != -1) {
          key[len] = prevval;
        }
        if (wrong) {
          tv_clear(&var1);
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
          lp->ll_newkey = xstrdup(key);
        } else {
          lp->ll_newkey = xmemdupz(key, (size_t)len);
        }
        tv_clear(&var1);
        break;
        // existing variable, need to check if it can be changed
      } else if (!(flags & GLV_READ_ONLY)
                 && (var_check_ro(lp->ll_di->di_flags, name, (size_t)(p - name))
                     || var_check_lock(lp->ll_di->di_flags, name, (size_t)(p - name)))) {
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
        lp->ll_n1 = (int)tv_get_number(&var1);
      }
      tv_clear(&var1);

      const int bloblen = tv_blob_len(lp->ll_tv->vval.v_blob);
      if (tv_blob_check_index(bloblen, lp->ll_n1, quiet) == FAIL) {
        tv_clear(&var2);
        return NULL;
      }
      if (lp->ll_range && !lp->ll_empty2) {
        lp->ll_n2 = (int)tv_get_number(&var2);
        tv_clear(&var2);
        if (tv_blob_check_range(bloblen, lp->ll_n1, lp->ll_n2, quiet) == FAIL) {
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
        lp->ll_n1 = (int)tv_get_number(&var1);
      }
      tv_clear(&var1);

      lp->ll_dict = NULL;
      lp->ll_list = lp->ll_tv->vval.v_list;
      lp->ll_li = tv_list_check_range_index_one(lp->ll_list, &lp->ll_n1, quiet);
      if (lp->ll_li == NULL) {
        tv_clear(&var2);
        return NULL;
      }

      // May need to find the item or absolute index for the second
      // index of a range.
      // When no index given: "lp->ll_empty2" is true.
      // Otherwise "lp->ll_n2" is set to the second index.
      if (lp->ll_range && !lp->ll_empty2) {
        lp->ll_n2 = (int)tv_get_number(&var2);  // Is number or string.
        tv_clear(&var2);
        if (tv_list_check_range_index_two(lp->ll_list,
                                          &lp->ll_n1, lp->ll_li,
                                          &lp->ll_n2, quiet) == FAIL) {
          return NULL;
        }
      }

      lp->ll_tv = TV_LIST_ITEM_TV(lp->ll_li);
    }
  }

  tv_clear(&var1);
  return p;
}

/// Clear lval "lp" that was filled by get_lval().
void clear_lval(lval_T *lp)
{
  xfree(lp->ll_exp_name);
  xfree(lp->ll_newkey);
}

/// Set a variable that was parsed by get_lval() to "rettv".
///
/// @param endp  points to just after the parsed name.
/// @param op    NULL, "+" for "+=", "-" for "-=", "*" for "*=", "/" for "/=",
///              "%" for "%=", "." for ".=" or "=" for "=".
void set_var_lval(lval_T *lp, char *endp, typval_T *rettv, bool copy, const bool is_const,
                  const char *op)
{
  int cc;
  dictitem_T *di;

  if (lp->ll_tv == NULL) {
    cc = (uint8_t)(*endp);
    *endp = NUL;
    if (lp->ll_blob != NULL) {
      if (op != NULL && *op != '=') {
        semsg(_(e_letwrong), op);
        return;
      }
      if (value_check_lock(lp->ll_blob->bv_lock, lp->ll_name, TV_CSTRING)) {
        return;
      }

      if (lp->ll_range && rettv->v_type == VAR_BLOB) {
        if (lp->ll_empty2) {
          lp->ll_n2 = tv_blob_len(lp->ll_blob) - 1;
        }

        if (tv_blob_set_range(lp->ll_blob, lp->ll_n1, lp->ll_n2, rettv) == FAIL) {
          return;
        }
      } else {
        bool error = false;
        const char val = (char)tv_get_number_chk(rettv, &error);
        if (!error) {
          tv_blob_set_append(lp->ll_blob, lp->ll_n1, (uint8_t)val);
        }
      }
    } else if (op != NULL && *op != '=') {
      typval_T tv;

      if (is_const) {
        emsg(_(e_cannot_mod));
        *endp = (char)cc;
        return;
      }

      // handle +=, -=, *=, /=, %= and .=
      di = NULL;
      if (eval_variable(lp->ll_name, (int)strlen(lp->ll_name),
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
    *endp = (char)cc;
  } else if (value_check_lock(lp->ll_newkey == NULL
                              ? lp->ll_tv->v_lock
                              : lp->ll_tv->vval.v_dict->dv_lock,
                              lp->ll_name, TV_CSTRING)) {
    // Skip
  } else if (lp->ll_range) {
    if (is_const) {
      emsg(_("E996: Cannot lock a range"));
      return;
    }

    tv_list_assign_range(lp->ll_list, rettv->vval.v_list,
                         lp->ll_n1, lp->ll_n2, lp->ll_empty2, op, lp->ll_name);
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
        semsg(_(e_dictkey), lp->ll_newkey);
        return;
      }
      if (tv_dict_wrong_func_name(lp->ll_tv->vval.v_dict, rettv, lp->ll_newkey)) {
        return;
      }

      // Need to add an item to the Dictionary.
      di = tv_dict_item_alloc(lp->ll_newkey);
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
        tv_dict_watcher_notify(dict, lp->ll_newkey, lp->ll_tv, NULL);
      } else {
        dictitem_T *di_ = lp->ll_di;
        assert(di_->di_key != NULL);
        tv_dict_watcher_notify(dict, di_->di_key, lp->ll_tv, &oldtv);
        tv_clear(&oldtv);
      }
    }
  }
}

/// Evaluate the expression used in a ":for var in expr" command.
/// "arg" points to "var".
///
/// @param[out] *errp  set to true for an error, false otherwise;
///
/// @return  a pointer that holds the info.  Null when there is an error.
void *eval_for_line(const char *arg, bool *errp, exarg_T *eap, evalarg_T *const evalarg)
{
  forinfo_T *fi = xcalloc(1, sizeof(forinfo_T));
  typval_T tv;
  list_T *l;
  const bool skip = !(evalarg->eval_flags & EVAL_EVALUATE);

  *errp = true;  // Default: there is an error.

  const char *expr = skip_var_list(arg, &fi->fi_varcount, &fi->fi_semicolon, false);
  if (expr == NULL) {
    return fi;
  }

  expr = skipwhite(expr);
  if (expr[0] != 'i' || expr[1] != 'n'
      || !(expr[2] == NUL || ascii_iswhite(expr[2]))) {
    emsg(_("E690: Missing \"in\" after :for"));
    return fi;
  }

  if (skip) {
    emsg_skip++;
  }
  expr = skipwhite(expr + 2);
  if (eval0((char *)expr, &tv, eap, evalarg) == OK) {
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
          tv_blob_copy(tv.vval.v_blob, &btv);
          fi->fi_blob = btv.vval.v_blob;
        }
        tv_clear(&tv);
      } else if (tv.v_type == VAR_STRING) {
        fi->fi_byte_idx = 0;
        fi->fi_string = tv.vval.v_string;
        tv.vval.v_string = NULL;
        if (fi->fi_string == NULL) {
          fi->fi_string = xstrdup("");
        }
      } else {
        emsg(_(e_string_list_or_blob_required));
        tv_clear(&tv);
      }
    }
  }
  if (skip) {
    emsg_skip--;
  }

  return fi;
}

/// Use the first item in a ":for" list.  Advance to the next.
/// Assign the values to the variable (list).  "arg" points to the first one.
///
/// @return  true when a valid item was found, false when at end of list or
///          something wrong.
bool next_for_item(void *fi_void, char *arg)
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
    return ex_let_vars(arg, &tv, true, fi->fi_semicolon, fi->fi_varcount, false, NULL) == OK;
  }

  if (fi->fi_string != NULL) {
    const int len = utfc_ptr2len(fi->fi_string + fi->fi_byte_idx);
    if (len == 0) {
      return false;
    }
    typval_T tv;
    tv.v_type = VAR_STRING;
    tv.v_lock = VAR_FIXED;
    tv.vval.v_string = xmemdupz(fi->fi_string + fi->fi_byte_idx, (size_t)len);
    fi->fi_byte_idx += len;
    const int result
      = ex_let_vars(arg, &tv, true, fi->fi_semicolon, fi->fi_varcount, false, NULL) == OK;
    xfree(tv.vval.v_string);
    return result;
  }

  listitem_T *item = fi->fi_lw.lw_item;
  if (item == NULL) {
    return false;
  }
  fi->fi_lw.lw_item = TV_LIST_ITEM_NEXT(fi->fi_list, item);
  return (ex_let_vars(arg, TV_LIST_ITEM_TV(item), true,
                      fi->fi_semicolon, fi->fi_varcount, false, NULL) == OK);
}

/// Free the structure used to store info used by ":for".
void free_for_info(void *fi_void)
{
  forinfo_T *fi = (forinfo_T *)fi_void;

  if (fi == NULL) {
    return;
  }
  if (fi->fi_list != NULL) {
    tv_list_watch_remove(fi->fi_list, &fi->fi_lw);
    tv_list_unref(fi->fi_list);
  } else if (fi->fi_blob != NULL) {
    tv_blob_unref(fi->fi_blob);
  } else {
    xfree(fi->fi_string);
  }
  xfree(fi);
}

void set_context_for_expression(expand_T *xp, char *arg, cmdidx_T cmdidx)
  FUNC_ATTR_NONNULL_ALL
{
  bool got_eq = false;

  if (cmdidx == CMD_let || cmdidx == CMD_const) {
    xp->xp_context = EXPAND_USER_VARS;
    if (strpbrk(arg, "\"'+-*/%.=!?~|&$([<>,#") == NULL) {
      // ":let var1 var2 ...": find last space.
      for (char *p = arg + strlen(arg); p >= arg;) {
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
  while ((xp->xp_pattern = strpbrk(arg, "\"'+-*/%.=!?~|&$([<>,#")) != NULL) {
    int c = (uint8_t)(*xp->xp_pattern);
    if (c == '&') {
      c = (uint8_t)xp->xp_pattern[1];
      if (c == '&') {
        xp->xp_pattern++;
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
      got_eq = true;
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
        while ((c = (uint8_t)(*++xp->xp_pattern)) != NUL && c != '"') {
          if (c == '\\' && xp->xp_pattern[1] != NUL) {
            xp->xp_pattern++;
          }
        }
        xp->xp_context = EXPAND_NOTHING;
      } else if (c == '\'') {     // literal string
        // Trick: '' is like stopping and starting a literal string.
        while ((c = (uint8_t)(*++xp->xp_pattern)) != NUL && c != '\'') {}
        xp->xp_context = EXPAND_NOTHING;
      } else if (c == '|') {
        if (xp->xp_pattern[1] == '|') {
          xp->xp_pattern++;
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
      while ((c = (uint8_t)(*++arg)) != NUL && (c == ' ' || c == '\t')) {}
    }
  }

  // ":exe one two" completes "two"
  if ((cmdidx == CMD_execute
       || cmdidx == CMD_echo
       || cmdidx == CMD_echon
       || cmdidx == CMD_echomsg)
      && xp->xp_context == EXPAND_EXPRESSION) {
    while (true) {
      char *const n = skiptowhite(arg);

      if (n == arg || ascii_iswhite_or_nul(*skipwhite(n))) {
        break;
      }
      arg = skipwhite(n);
    }
  }

  xp->xp_pattern = arg;
}

/// Delete all "menutrans_" variables.
void del_menutrans_vars(void)
{
  hash_lock(&globvarht);
  HASHTAB_ITER(&globvarht, hi, {
    if (strncmp(hi->hi_key, "menutrans_", 10) == 0) {
      delete_var(&globvarht, hi);
    }
  });
  hash_unlock(&globvarht);
}

/// Local string buffer for the next two functions to store a variable name
/// with its prefix. Allocated in cat_prefix_varname(), freed later in
/// get_user_var_name().

static char *varnamebuf = NULL;
static size_t varnamebuflen = 0;

/// Function to concatenate a prefix and a variable name.
char *cat_prefix_varname(int prefix, const char *name)
  FUNC_ATTR_NONNULL_ALL
{
  size_t len = strlen(name) + 3;

  if (len > varnamebuflen) {
    xfree(varnamebuf);
    len += 10;                          // some additional space
    varnamebuf = xmalloc(len);
    varnamebuflen = len;
  }
  *varnamebuf = (char)prefix;
  varnamebuf[1] = ':';
  STRCPY(varnamebuf + 2, name);
  return varnamebuf;
}

/// Function given to ExpandGeneric() to obtain the list of user defined
/// (global/buffer/window/built-in) variable names.
char *get_user_var_name(expand_T *xp, int idx)
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
      hi++;
    }
    while (HASHITEM_EMPTY(hi)) {
      hi++;
    }
    if (strncmp("g:", xp->xp_pattern, 2) == 0) {
      return cat_prefix_varname('g', hi->hi_key);
    }
    return hi->hi_key;
  }

  // b: variables
  const hashtab_T *ht = &prevwin_curwin()->w_buffer->b_vars->dv_hashtab;
  if (bdone < ht->ht_used) {
    if (bdone++ == 0) {
      hi = ht->ht_array;
    } else {
      hi++;
    }
    while (HASHITEM_EMPTY(hi)) {
      hi++;
    }
    return cat_prefix_varname('b', hi->hi_key);
  }

  // w: variables
  ht = &prevwin_curwin()->w_vars->dv_hashtab;
  if (wdone < ht->ht_used) {
    if (wdone++ == 0) {
      hi = ht->ht_array;
    } else {
      hi++;
    }
    while (HASHITEM_EMPTY(hi)) {
      hi++;
    }
    return cat_prefix_varname('w', hi->hi_key);
  }

  // t: variables
  ht = &curtab->tp_vars->dv_hashtab;
  if (tdone < ht->ht_used) {
    if (tdone++ == 0) {
      hi = ht->ht_array;
    } else {
      hi++;
    }
    while (HASHITEM_EMPTY(hi)) {
      hi++;
    }
    return cat_prefix_varname('t', hi->hi_key);
  }

  // v: variables
  if (vidx < ARRAY_SIZE(vimvars)) {
    return cat_prefix_varname('v', vimvars[vidx++].vv_name);
  }

  XFREE_CLEAR(varnamebuf);
  varnamebuflen = 0;
  return NULL;
}

/// Does not use 'cpo' and always uses 'magic'.
///
/// @return  true if "pat" matches "text".
int pattern_match(const char *pat, const char *text, bool ic)
{
  int matches = 0;
  regmatch_T regmatch;

  // avoid 'l' flag in 'cpoptions'
  char *save_cpo = p_cpo;
  p_cpo = empty_string_option;
  regmatch.regprog = vim_regcomp(pat, RE_MAGIC + RE_STRING);
  if (regmatch.regprog != NULL) {
    regmatch.rm_ic = ic;
    matches = vim_regexec_nl(&regmatch, text, 0);
    vim_regfree(regmatch.regprog);
  }
  p_cpo = save_cpo;
  return matches;
}

/// Handle a name followed by "(".  Both for just "name(arg)" and for
/// "expr->name(arg)".
///
/// @param arg  Points to "(", will be advanced
/// @param basetv  "expr" for "expr->name(arg)"
///
/// @return OK or FAIL.
static int eval_func(char **const arg, evalarg_T *const evalarg, char *const name,
                     const int name_len, typval_T *const rettv, const int flags,
                     typval_T *const basetv)
  FUNC_ATTR_NONNULL_ARG(1, 3, 5)
{
  const bool evaluate = flags & EVAL_EVALUATE;
  char *s = name;
  int len = name_len;
  bool found_var = false;

  if (!evaluate) {
    check_vars(s, (size_t)len);
  }

  // If "s" is the name of a variable of type VAR_FUNC
  // use its contents.
  partial_T *partial;
  s = deref_func_name(s, &len, &partial, !evaluate, &found_var);

  // Need to make a copy, in case evaluating the arguments makes
  // the name invalid.
  s = xmemdupz(s, (size_t)len);

  // Invoke the function.
  funcexe_T funcexe = FUNCEXE_INIT;
  funcexe.fe_firstline = curwin->w_cursor.lnum;
  funcexe.fe_lastline = curwin->w_cursor.lnum;
  funcexe.fe_evaluate = evaluate;
  funcexe.fe_partial = partial;
  funcexe.fe_basetv = basetv;
  funcexe.fe_found_var = found_var;
  int ret = get_func_tv(s, len, rettv, arg, evalarg, &funcexe);

  xfree(s);

  // If evaluate is false rettv->v_type was not set in
  // get_func_tv, but it's needed in handle_subscript() to parse
  // what follows. So set it here.
  if (rettv->v_type == VAR_UNKNOWN && !evaluate && **arg == '(') {
    rettv->vval.v_string = (char *)tv_empty_string;
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

/// After using "evalarg" filled from "eap": free the memory.
void clear_evalarg(evalarg_T *evalarg, exarg_T *eap)
{
  if (evalarg == NULL) {
    return;
  }

  if (evalarg->eval_tofree != NULL) {
    if (eap != NULL) {
      // We may need to keep the original command line, e.g. for
      // ":let" it has the variable names.  But we may also need the
      // new one, "nextcmd" points into it.  Keep both.
      xfree(eap->cmdline_tofree);
      eap->cmdline_tofree = *eap->cmdlinep;
      *eap->cmdlinep = evalarg->eval_tofree;
    } else {
      xfree(evalarg->eval_tofree);
    }
    evalarg->eval_tofree = NULL;
  }
}

/// The "evaluate" argument: When false, the argument is only parsed but not
/// executed.  The function may return OK, but the rettv will be of type
/// VAR_UNKNOWN.  The function still returns FAIL for a syntax error.

/// Handle zero level expression.
/// This calls eval1() and handles error message and nextcmd.
/// Put the result in "rettv" when returning OK and "evaluate" is true.
/// Note: "rettv.v_lock" is not set.
///
/// @param evalarg  can be NULL, &EVALARG_EVALUATE or a pointer.
///
/// @return OK or FAIL.
int eval0(char *arg, typval_T *rettv, exarg_T *eap, evalarg_T *const evalarg)
{
  const int did_emsg_before = did_emsg;
  const int called_emsg_before = called_emsg;
  bool end_error = false;

  char *p = skipwhite(arg);
  int ret = eval1(&p, rettv, evalarg);

  if (ret != FAIL) {
    end_error = !ends_excmd(*p);
  }
  if (ret == FAIL || end_error) {
    if (ret != FAIL) {
      tv_clear(rettv);
    }
    // Report the invalid expression unless the expression evaluation has
    // been cancelled due to an aborting error, an interrupt, or an
    // exception, or we already gave a more specific error.
    // Also check called_emsg for when using assert_fails().
    if (!aborting()
        && did_emsg == did_emsg_before
        && called_emsg == called_emsg_before) {
      if (end_error) {
        semsg(_(e_trailing_arg), p);
      } else {
        semsg(_(e_invexpr2), arg);
      }
    }

    if (eap != NULL && p != NULL) {
      // Some of the expression may not have been consumed.
      // Only execute a next command if it cannot be a "||" operator.
      // The next command may be "catch".
      char *nextcmd = check_nextcmd(p);
      if (nextcmd != NULL && *nextcmd != '|') {
        eap->nextcmd = nextcmd;
      }
    }
    return FAIL;
  }

  if (eap != NULL) {
    eap->nextcmd = check_nextcmd(p);
  }

  return ret;
}

/// Handle top level expression:
///      expr2 ? expr1 : expr1
///      expr2 ?? expr1
///
/// "arg" must point to the first non-white of the expression.
/// "arg" is advanced to the next non-white after the recognized expression.
///
/// Note: "rettv.v_lock" is not set.
///
/// @return  OK or FAIL.
int eval1(char **arg, typval_T *rettv, evalarg_T *const evalarg)
{
  // Get the first variable.
  if (eval2(arg, rettv, evalarg) == FAIL) {
    return FAIL;
  }

  char *p = *arg;
  if (*p == '?') {
    const bool op_falsy = p[1] == '?';
    evalarg_T *evalarg_used = evalarg;
    evalarg_T local_evalarg;
    if (evalarg == NULL) {
      local_evalarg = (evalarg_T){ .eval_flags = 0 };
      evalarg_used = &local_evalarg;
    }
    const int orig_flags = evalarg_used->eval_flags;
    const bool evaluate = evalarg_used->eval_flags & EVAL_EVALUATE;

    bool result = false;
    if (evaluate) {
      bool error = false;

      if (op_falsy) {
        result = tv2bool(rettv);
      } else if (tv_get_number_chk(rettv, &error) != 0) {
        result = true;
      }
      if (error || !op_falsy || !result) {
        tv_clear(rettv);
      }
      if (error) {
        return FAIL;
      }
    }

    // Get the second variable.  Recursive!
    if (op_falsy) {
      (*arg)++;
    }
    *arg = skipwhite(*arg + 1);
    evalarg_used->eval_flags = (op_falsy ? !result : result)
                               ? orig_flags : (orig_flags & ~EVAL_EVALUATE);
    typval_T var2;
    if (eval1(arg, &var2, evalarg_used) == FAIL) {
      evalarg_used->eval_flags = orig_flags;
      return FAIL;
    }
    if (!op_falsy || !result) {
      *rettv = var2;
    }

    if (!op_falsy) {
      // Check for the ":".
      p = *arg;
      if (*p != ':') {
        emsg(_("E109: Missing ':' after '?'"));
        if (evaluate && result) {
          tv_clear(rettv);
        }
        evalarg_used->eval_flags = orig_flags;
        return FAIL;
      }

      // Get the third variable.  Recursive!
      *arg = skipwhite(*arg + 1);
      evalarg_used->eval_flags = !result ? orig_flags : (orig_flags & ~EVAL_EVALUATE);
      if (eval1(arg, &var2, evalarg_used) == FAIL) {
        if (evaluate && result) {
          tv_clear(rettv);
        }
        evalarg_used->eval_flags = orig_flags;
        return FAIL;
      }
      if (evaluate && !result) {
        *rettv = var2;
      }
    }

    if (evalarg == NULL) {
      clear_evalarg(&local_evalarg, NULL);
    } else {
      evalarg->eval_flags = orig_flags;
    }
  }

  return OK;
}

/// Handle first level expression:
///      expr2 || expr2 || expr2     logical OR
///
/// "arg" must point to the first non-white of the expression.
/// "arg" is advanced to the next non-white after the recognized expression.
///
/// @return  OK or FAIL.
static int eval2(char **arg, typval_T *rettv, evalarg_T *const evalarg)
{
  // Get the first variable.
  if (eval3(arg, rettv, evalarg) == FAIL) {
    return FAIL;
  }

  // Handle the  "||" operator.
  char *p = *arg;
  if (p[0] == '|' && p[1] == '|') {
    evalarg_T *evalarg_used = evalarg;
    evalarg_T local_evalarg;
    if (evalarg == NULL) {
      local_evalarg = (evalarg_T){ .eval_flags = 0 };
      evalarg_used = &local_evalarg;
    }
    const int orig_flags = evalarg_used->eval_flags;
    const bool evaluate = evalarg_used->eval_flags & EVAL_EVALUATE;

    bool result = false;

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

    // Repeat until there is no following "||".
    while (p[0] == '|' && p[1] == '|') {
      // Get the second variable.
      *arg = skipwhite(*arg + 2);
      evalarg_used->eval_flags = !result ? orig_flags : (orig_flags & ~EVAL_EVALUATE);
      typval_T var2;
      if (eval3(arg, &var2, evalarg_used) == FAIL) {
        return FAIL;
      }

      // Compute the result.
      if (evaluate && !result) {
        bool error = false;
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

      p = *arg;
    }

    if (evalarg == NULL) {
      clear_evalarg(&local_evalarg, NULL);
    } else {
      evalarg->eval_flags = orig_flags;
    }
  }

  return OK;
}

/// Handle second level expression:
///      expr3 && expr3 && expr3     logical AND
///
/// @param arg  must point to the first non-white of the expression.
///             `arg` is advanced to the next non-white after the recognized expression.
///
/// @return  OK or FAIL.
static int eval3(char **arg, typval_T *rettv, evalarg_T *const evalarg)
{
  // Get the first variable.
  if (eval4(arg, rettv, evalarg) == FAIL) {
    return FAIL;
  }

  char *p = *arg;
  // Handle the "&&" operator.
  if (p[0] == '&' && p[1] == '&') {
    evalarg_T *evalarg_used = evalarg;
    evalarg_T local_evalarg;
    if (evalarg == NULL) {
      local_evalarg = (evalarg_T){ .eval_flags = 0 };
      evalarg_used = &local_evalarg;
    }
    const int orig_flags = evalarg_used->eval_flags;
    const bool evaluate = evalarg_used->eval_flags & EVAL_EVALUATE;

    bool result = true;

    if (evaluate) {
      bool error = false;
      if (tv_get_number_chk(rettv, &error) == 0) {
        result = false;
      }
      tv_clear(rettv);
      if (error) {
        return FAIL;
      }
    }

    // Repeat until there is no following "&&".
    while (p[0] == '&' && p[1] == '&') {
      // Get the second variable.
      *arg = skipwhite(*arg + 2);
      evalarg_used->eval_flags = result ? orig_flags : (orig_flags & ~EVAL_EVALUATE);
      typval_T var2;
      if (eval4(arg, &var2, evalarg_used) == FAIL) {
        return FAIL;
      }

      // Compute the result.
      if (evaluate && result) {
        bool error = false;
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

      p = *arg;
    }

    if (evalarg == NULL) {
      clear_evalarg(&local_evalarg, NULL);
    } else {
      evalarg->eval_flags = orig_flags;
    }
  }

  return OK;
}

/// Handle third level expression:
///      var1 == var2
///      var1 =~ var2
///      var1 != var2
///      var1 !~ var2
///      var1 > var2
///      var1 >= var2
///      var1 < var2
///      var1 <= var2
///      var1 is var2
///      var1 isnot var2
///
/// "arg" must point to the first non-white of the expression.
/// "arg" is advanced to the next non-white after the recognized expression.
///
/// @return  OK or FAIL.
static int eval4(char **arg, typval_T *rettv, evalarg_T *const evalarg)
{
  typval_T var2;
  exprtype_T type = EXPR_UNKNOWN;
  int len = 2;

  // Get the first variable.
  if (eval5(arg, rettv, evalarg) == FAIL) {
    return FAIL;
  }

  char *p = *arg;
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
      if (!isalnum((uint8_t)p[len]) && p[len] != '_') {
        type = len == 2 ? EXPR_IS : EXPR_ISNOT;
      }
    }
    break;
  }

  // If there is a comparative operator, use it.
  if (type != EXPR_UNKNOWN) {
    bool ic;
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
    if (eval5(arg, &var2, evalarg) == FAIL) {
      tv_clear(rettv);
      return FAIL;
    }
    if (evalarg != NULL && (evalarg->eval_flags & EVAL_EVALUATE)) {
      const int ret = typval_compare(rettv, &var2, type, ic);

      tv_clear(&var2);
      return ret;
    }
  }

  return OK;
}

/// Make a copy of blob "tv1" and append blob "tv2".
static void eval_addblob(typval_T *tv1, typval_T *tv2)
{
  const blob_T *const b1 = tv1->vval.v_blob;
  const blob_T *const b2 = tv2->vval.v_blob;
  blob_T *const b = tv_blob_alloc();

  for (int i = 0; i < tv_blob_len(b1); i++) {
    ga_append(&b->bv_ga, tv_blob_get(b1, i));
  }
  for (int i = 0; i < tv_blob_len(b2); i++) {
    ga_append(&b->bv_ga, tv_blob_get(b2, i));
  }

  tv_clear(tv1);
  tv_blob_set_ret(tv1, b);
}

/// Make a copy of list "tv1" and append list "tv2".
static int eval_addlist(typval_T *tv1, typval_T *tv2)
{
  typval_T var3;
  // Concatenate Lists.
  if (tv_list_concat(tv1->vval.v_list, tv2->vval.v_list, &var3) == FAIL) {
    tv_clear(tv1);
    tv_clear(tv2);
    return FAIL;
  }
  tv_clear(tv1);
  *tv1 = var3;
  return OK;
}

/// Handle fourth level expression:
///      +       number addition, concatenation of list or blob
///      -       number subtraction
///      .       string concatenation
///      ..      string concatenation
///
/// @param arg  must point to the first non-white of the expression.
///             `arg` is advanced to the next non-white after the recognized expression.
///
/// @return  OK or FAIL.
static int eval5(char **arg, typval_T *rettv, evalarg_T *const evalarg)
{
  // Get the first variable.
  if (eval6(arg, rettv, evalarg, false) == FAIL) {
    return FAIL;
  }

  // Repeat computing, until no '+', '-' or '.' is following.
  while (true) {
    int op = (uint8_t)(**arg);
    bool concat = op == '.';
    if (op != '+' && op != '-' && !concat) {
      break;
    }

    const bool evaluate = evalarg == NULL ? 0 : (evalarg->eval_flags & EVAL_EVALUATE);
    if ((op != '+' || (rettv->v_type != VAR_LIST && rettv->v_type != VAR_BLOB))
        && (op == '.' || rettv->v_type != VAR_FLOAT) && evaluate) {
      // For "list + ...", an illegal use of the first operand as
      // a number cannot be determined before evaluating the 2nd
      // operand: if this is also a list, all is ok.
      // For "something . ...", "something - ..." or "non-list + ...",
      // we know that the first operand needs to be a string or number
      // without evaluating the 2nd operand.  So check before to avoid
      // side effects after an error.
      if ((op == '.' && !tv_check_str(rettv)) || (op != '.' && !tv_check_num(rettv))) {
        tv_clear(rettv);
        return FAIL;
      }
    }

    // Get the second variable.
    if (op == '.' && *(*arg + 1) == '.') {  // ..string concatenation
      (*arg)++;
    }
    *arg = skipwhite(*arg + 1);
    typval_T var2;
    if (eval6(arg, &var2, evalarg, op == '.') == FAIL) {
      tv_clear(rettv);
      return FAIL;
    }

    if (evaluate) {
      // Compute the result.
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
        char *p = concat_str(s1, s2);
        tv_clear(rettv);
        rettv->v_type = VAR_STRING;
        rettv->vval.v_string = p;
      } else if (op == '+' && rettv->v_type == VAR_BLOB && var2.v_type == VAR_BLOB) {
        eval_addblob(rettv, &var2);
      } else if (op == '+' && rettv->v_type == VAR_LIST && var2.v_type == VAR_LIST) {
        if (eval_addlist(rettv, &var2) == FAIL) {
          return FAIL;
        }
      } else {
        bool error = false;
        varnumber_T n1, n2;
        float_T f1 = 0;
        float_T f2 = 0;

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
            f1 = (float_T)n1;
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
            f2 = (float_T)n2;
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

/// Handle fifth level expression:
///  - *  number multiplication
///  - /  number division
///  - %  number modulo
///
/// @param[in,out]  arg  Points to the first non-whitespace character of the
///                      expression.  Is advanced to the next non-whitespace
///                      character after the recognized expression.
/// @param[out]  rettv  Location where result is saved.
/// @param[in]  want_string  True if "." is string_concatenation, otherwise
///                          float
/// @return  OK or FAIL.
static int eval6(char **arg, typval_T *rettv, evalarg_T *const evalarg, bool want_string)
  FUNC_ATTR_NO_SANITIZE_UNDEFINED
{
  bool use_float = false;

  // Get the first variable.
  if (eval7(arg, rettv, evalarg, want_string) == FAIL) {
    return FAIL;
  }

  // Repeat computing, until no '*', '/' or '%' is following.
  while (true) {
    int op = (uint8_t)(**arg);
    if (op != '*' && op != '/' && op != '%') {
      break;
    }

    varnumber_T n1, n2;
    float_T f1 = 0;
    float_T f2 = 0;
    bool error = false;
    const bool evaluate = evalarg == NULL ? 0 : (evalarg->eval_flags & EVAL_EVALUATE);
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

    // Get the second variable.
    *arg = skipwhite(*arg + 1);
    typval_T var2;
    if (eval7(arg, &var2, evalarg, false) == FAIL) {
      return FAIL;
    }

    if (evaluate) {
      if (var2.v_type == VAR_FLOAT) {
        if (!use_float) {
          f1 = (float_T)n1;
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
          f2 = (float_T)n2;
        }
      }

      // Compute the result.
      // When either side is a float the result is a float.
      if (use_float) {
        if (op == '*') {
          f1 = f1 * f2;
        } else if (op == '/') {
          // uncrustify:off

          // Division by zero triggers error from AddressSanitizer
          f1 = (f2 == 0 ? (
#ifdef NAN
              f1 == 0 ? (float_T)NAN :
#endif
              (f1 > 0 ? (float_T)INFINITY : (float_T)-INFINITY)) : f1 / f2);

          // uncrustify:on
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
static int eval7(char **arg, typval_T *rettv, evalarg_T *const evalarg, bool want_string)
{
  const bool evaluate = evalarg != NULL && (evalarg->eval_flags & EVAL_EVALUATE);
  int ret = OK;
  static int recurse = 0;

  // Initialise variable so that tv_clear() can't mistake this for a
  // string and free a string that isn't there.
  rettv->v_type = VAR_UNKNOWN;

  // Skip '!', '-' and '+' characters.  They are handled later.
  const char *start_leader = *arg;
  while (**arg == '!' || **arg == '-' || **arg == '+') {
    *arg = skipwhite(*arg + 1);
  }
  const char *end_leader = *arg;

  // Limit recursion to 1000 levels.  At least at 10000 we run out of stack
  // and crash.  With MSVC the stack is smaller.
  if (recurse ==
#ifdef _MSC_VER
      300
#else
      1000
#endif
      ) {
    semsg(_(e_expression_too_recursive_str), *arg);
    return FAIL;
  }
  recurse++;

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
    ret = eval_number(arg, rettv, evaluate, want_string);

    // Apply prefixed "-" and "+" now.  Matters especially when
    // "->" follows.
    if (ret == OK && evaluate && end_leader > start_leader) {
      ret = eval7_leader(rettv, true, start_leader, &end_leader);
    }
    break;

  // String constant: "string".
  case '"':
    ret = eval_string(arg, rettv, evaluate, false);
    break;

  // Literal string constant: 'str''ing'.
  case '\'':
    ret = eval_lit_string(arg, rettv, evaluate, false);
    break;

  // List: [expr, expr]
  case '[':
    ret = eval_list(arg, rettv, evalarg);
    break;

  // Dictionary: #{key: val, key: val}
  case '#':
    if ((*arg)[1] == '{') {
      (*arg)++;
      ret = eval_dict(arg, rettv, evalarg, true);
    } else {
      ret = NOTDONE;
    }
    break;

  // Lambda: {arg, arg -> expr}
  // Dictionary: {'key': val, 'key': val}
  case '{':
    ret = get_lambda_tv(arg, rettv, evalarg);
    if (ret == NOTDONE) {
      ret = eval_dict(arg, rettv, evalarg, false);
    }
    break;

  // Option value: &name
  case '&':
    ret = eval_option((const char **)arg, rettv, evaluate);
    break;
  // Environment variable: $VAR.
  // Interpolated string: $"string" or $'string'.
  case '$':
    if ((*arg)[1] == '"' || (*arg)[1] == '\'') {
      ret = eval_interp_string(arg, rettv, evaluate);
    } else {
      ret = eval_env_var(arg, rettv, evaluate);
    }
    break;

  // Register contents: @r.
  case '@':
    (*arg)++;
    if (evaluate) {
      rettv->v_type = VAR_STRING;
      rettv->vval.v_string = get_reg_contents(**arg, kGRegExprSrc);
    }
    if (**arg != NUL) {
      (*arg)++;
    }
    break;

  // nested expression: (expression).
  case '(':
    *arg = skipwhite(*arg + 1);

    ret = eval1(arg, rettv, evalarg);  // recursive!
    if (**arg == ')') {
      (*arg)++;
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
    char *s = *arg;
    char *alias;
    int len = get_name_len((const char **)arg, &alias, evaluate, true);
    if (alias != NULL) {
      s = alias;
    }

    if (len <= 0) {
      ret = FAIL;
    } else {
      const int flags = evalarg == NULL ? 0 : evalarg->eval_flags;
      if (*skipwhite(*arg) == '(') {
        // "name(..."  recursive!
        *arg = skipwhite(*arg);
        ret = eval_func(arg, evalarg, s, len, rettv, flags, NULL);
      } else if (evaluate) {
        // get value of variable
        ret = eval_variable(s, len, rettv, NULL, true, false);
      } else {
        // skip the name
        check_vars(s, (size_t)len);
        // If evaluate is false rettv->v_type was not set, but it's needed
        // in handle_subscript() to parse v:lua, so set it here.
        if (rettv->v_type == VAR_UNKNOWN && !evaluate && strnequal(s, "v:lua.", 6)) {
          rettv->v_type = VAR_PARTIAL;
          rettv->vval.v_partial = vvlua_partial;
          rettv->vval.v_partial->pt_refcount++;
        }
        ret = OK;
      }
    }
    xfree(alias);
  }

  *arg = skipwhite(*arg);

  // Handle following '[', '(' and '.' for expr[expr], expr.name,
  // expr(expr), expr->name(expr)
  if (ret == OK) {
    ret = handle_subscript((const char **)arg, rettv, evalarg, true);
  }

  // Apply logical NOT and unary '-', from right to left, ignore '+'.
  if (ret == OK && evaluate && end_leader > start_leader) {
    ret = eval7_leader(rettv, false, start_leader, &end_leader);
  }

  recurse--;
  return ret;
}

/// Apply the leading "!" and "-" before an eval7 expression to "rettv".
/// Adjusts "end_leaderp" until it is at "start_leader".
///
/// @param numeric_only  if true only handle "+" and "-".
///
/// @return  OK on success, FAIL on failure.
static int eval7_leader(typval_T *const rettv, const bool numeric_only,
                        const char *const start_leader, const char **const end_leaderp)
  FUNC_ATTR_NONNULL_ALL
{
  const char *end_leader = *end_leaderp;
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
        if (numeric_only) {
          end_leader++;
          break;
        }
        if (rettv->v_type == VAR_FLOAT) {
          f = !(bool)f;
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
/// @return  OK on success, FAIL on failure.
static int call_func_rettv(char **const arg, evalarg_T *const evalarg, typval_T *const rettv,
                           const bool evaluate, dict_T *const selfdict, typval_T *const basetv,
                           const char *const lua_funcname)
  FUNC_ATTR_NONNULL_ARG(1, 3)
{
  partial_T *pt = NULL;
  typval_T functv;
  const char *funcname;
  bool is_lua = false;
  int ret;

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
      if (funcname == NULL || *funcname == NUL) {
        emsg(_(e_empty_function_name));
        ret = FAIL;
        goto theend;
      }
    }
  } else {
    funcname = "";
  }

  funcexe_T funcexe = FUNCEXE_INIT;
  funcexe.fe_firstline = curwin->w_cursor.lnum;
  funcexe.fe_lastline = curwin->w_cursor.lnum;
  funcexe.fe_evaluate = evaluate;
  funcexe.fe_partial = pt;
  funcexe.fe_selfdict = selfdict;
  funcexe.fe_basetv = basetv;
  ret = get_func_tv(funcname, is_lua ? (int)(*arg - funcname) : -1, rettv,
                    arg, evalarg, &funcexe);

theend:
  // Clear the funcref afterwards, so that deleting it while
  // evaluating the arguments is possible (see test55).
  if (evaluate) {
    tv_clear(&functv);
  }

  return ret;
}

/// Evaluate "->method()".
///
/// @param verbose  if true, give error messages.
/// @param *arg     points to the '-'.
///
/// @return  FAIL or OK.
///
/// @note "*arg" is advanced to after the ')'.
static int eval_lambda(char **const arg, typval_T *const rettv, evalarg_T *const evalarg,
                       const bool verbose)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  const bool evaluate = evalarg != NULL && (evalarg->eval_flags & EVAL_EVALUATE);
  // Skip over the ->.
  *arg += 2;
  typval_T base = *rettv;
  rettv->v_type = VAR_UNKNOWN;

  int ret = get_lambda_tv(arg, rettv, evalarg);
  if (ret != OK) {
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
    ret = call_func_rettv(arg, evalarg, rettv, evaluate, NULL, &base, NULL);
  }

  // Clear the funcref afterwards, so that deleting it while
  // evaluating the arguments is possible (see test55).
  if (evaluate) {
    tv_clear(&base);
  }

  return ret;
}

/// Evaluate "->method()" or "->v:lua.method()".
///
/// @param *arg  points to the '-'.
///
/// @return  FAIL or OK. "*arg" is advanced to after the ')'.
static int eval_method(char **const arg, typval_T *const rettv, evalarg_T *const evalarg,
                       const bool verbose)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  const bool evaluate = evalarg != NULL && (evalarg->eval_flags & EVAL_EVALUATE);

  // Skip over the ->.
  *arg += 2;
  typval_T base = *rettv;
  rettv->v_type = VAR_UNKNOWN;

  // Locate the method name.
  int len;
  char *name = *arg;
  char *lua_funcname = NULL;
  if (strnequal(name, "v:lua.", 6)) {
    lua_funcname = name + 6;
    *arg = (char *)skip_luafunc_name(lua_funcname);
    *arg = skipwhite(*arg);  // to detect trailing whitespace later
    len = (int)(*arg - lua_funcname);
  } else {
    char *alias;
    len = get_name_len((const char **)arg, &alias, evaluate, true);
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
      ret = call_func_rettv(arg, evalarg, rettv, evaluate, NULL, &base, lua_funcname);
    } else {
      ret = eval_func(arg, evalarg, name, len, rettv, evaluate ? EVAL_EVALUATE : 0, &base);
    }
  }

  // Clear the funcref afterwards, so that deleting it while
  // evaluating the arguments is possible (see test55).
  if (evaluate) {
    tv_clear(&base);
  }

  return ret;
}

/// Evaluate an "[expr]" or "[expr:expr]" index.  Also "dict.key".
/// "*arg" points to the '[' or '.'.
///
/// @param verbose  give error messages
///
/// @returns FAIL or OK. "*arg" is advanced to after the ']'.
static int eval_index(char **arg, typval_T *rettv, evalarg_T *const evalarg, bool verbose)
{
  const bool evaluate = evalarg != NULL && (evalarg->eval_flags & EVAL_EVALUATE);
  bool empty1 = false;
  bool empty2 = false;
  bool range = false;
  const char *key = NULL;
  ptrdiff_t keylen = -1;

  if (check_can_index(rettv, evaluate, verbose) == FAIL) {
    return FAIL;
  }

  typval_T var1 = TV_INITIAL_VALUE;
  typval_T var2 = TV_INITIAL_VALUE;
  if (**arg == '.') {
    // dict.name
    key = *arg + 1;
    for (keylen = 0; eval_isdictc(key[keylen]); keylen++) {}
    if (keylen == 0) {
      return FAIL;
    }
    *arg = skipwhite(key + keylen);
  } else {
    // something[idx]
    //
    // Get the (first) variable from inside the [].
    *arg = skipwhite(*arg + 1);
    if (**arg == ':') {
      empty1 = true;
    } else if (eval1(arg, &var1, evalarg) == FAIL) {  // Recursive!
      return FAIL;
    } else if (evaluate && !tv_check_str(&var1)) {
      // Not a number or string.
      tv_clear(&var1);
      return FAIL;
    }

    // Get the second variable from inside the [:].
    if (**arg == ':') {
      range = true;
      *arg = skipwhite(*arg + 1);
      if (**arg == ']') {
        empty2 = true;
      } else if (eval1(arg, &var2, evalarg) == FAIL) {  // Recursive!
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
    int res = eval_index_inner(rettv, range,
                               empty1 ? NULL : &var1, empty2 ? NULL : &var2, false,
                               key, keylen, verbose);
    if (!empty1) {
      tv_clear(&var1);
    }
    if (range) {
      tv_clear(&var2);
    }
    return res;
  }
  return OK;
}

/// Check if "rettv" can have an [index] or [sli:ce]
static int check_can_index(typval_T *rettv, bool evaluate, bool verbose)
{
  switch (rettv->v_type) {
  case VAR_FUNC:
  case VAR_PARTIAL:
    if (verbose) {
      emsg(_(e_cannot_index_a_funcref));
    }
    return FAIL;
  case VAR_FLOAT:
    if (verbose) {
      emsg(_(e_using_float_as_string));
    }
    return FAIL;
  case VAR_BOOL:
  case VAR_SPECIAL:
    if (verbose) {
      emsg(_(e_cannot_index_special_variable));
    }
    return FAIL;
  case VAR_UNKNOWN:
    if (evaluate) {
      emsg(_(e_cannot_index_special_variable));
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
  return OK;
}

/// slice() function
void f_slice(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (check_can_index(argvars, true, false) != OK) {
    return;
  }

  tv_copy(argvars, rettv);
  eval_index_inner(rettv, true, argvars + 1,
                   argvars[2].v_type == VAR_UNKNOWN ? NULL : argvars + 2,
                   true, NULL, 0, false);
}

/// Apply index or range to "rettv".
///
/// @param var1  the first index, NULL for [:expr].
/// @param var2  the second index, NULL for [expr] and [expr: ]
/// @param exclusive  true for slice(): second index is exclusive, use character
///                                     index for string.
/// Alternatively, "key" is not NULL, then key[keylen] is the dict index.
static int eval_index_inner(typval_T *rettv, bool is_range, typval_T *var1, typval_T *var2,
                            bool exclusive, const char *key, ptrdiff_t keylen, bool verbose)
{
  varnumber_T n1 = 0;
  varnumber_T n2 = 0;
  if (var1 != NULL && rettv->v_type != VAR_DICT) {
    n1 = tv_get_number(var1);
  }

  if (is_range) {
    if (rettv->v_type == VAR_DICT) {
      if (verbose) {
        emsg(_(e_cannot_slice_dictionary));
      }
      return FAIL;
    }
    if (var2 != NULL) {
      n2 = tv_get_number(var2);
    } else {
      n2 = VARNUMBER_MAX;
    }
  }

  switch (rettv->v_type) {
  case VAR_BOOL:
  case VAR_SPECIAL:
  case VAR_FUNC:
  case VAR_FLOAT:
  case VAR_PARTIAL:
  case VAR_UNKNOWN:
    break;  // Not evaluating, skipping over subscript

  case VAR_NUMBER:
  case VAR_STRING: {
    const char *const s = tv_get_string(rettv);
    char *v;
    int len = (int)strlen(s);
    if (exclusive) {
      if (is_range) {
        v = string_slice(s, n1, n2, exclusive);
      } else {
        v = char_from_string(s, n1);
      }
    } else if (is_range) {
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
        v = xmemdupz(s + n1, (size_t)n2 - (size_t)n1 + 1);
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
    rettv->vval.v_string = v;
    break;
  }

  case VAR_BLOB:
    tv_blob_slice_or_index(rettv->vval.v_blob, is_range, n1, n2, exclusive, rettv);
    break;

  case VAR_LIST:
    if (var1 == NULL) {
      n1 = 0;
    }
    if (var2 == NULL) {
      n2 = VARNUMBER_MAX;
    }
    if (tv_list_slice_or_index(rettv->vval.v_list,
                               is_range, n1, n2, exclusive, rettv, verbose) == FAIL) {
      return FAIL;
    }
    break;

  case VAR_DICT: {
    if (key == NULL) {
      key = tv_get_string_chk(var1);
      if (key == NULL) {
        return FAIL;
      }
    }

    dictitem_T *const item = tv_dict_find(rettv->vval.v_dict, key, keylen);

    if (item == NULL && verbose) {
      if (keylen > 0) {
        semsg(_(e_dictkey_len), keylen, key);
      } else {
        semsg(_(e_dictkey), key);
      }
    }
    if (item == NULL || tv_is_luafunc(&item->di_tv)) {
      return FAIL;
    }

    typval_T tmp;
    tv_copy(&item->di_tv, &tmp);
    tv_clear(rettv);
    *rettv = tmp;
    break;
  }
  }
  return OK;
}

/// Get an option value
///
/// @param[in,out] arg  Points to the '&' or '+' before the option name. Is
///                      advanced to the character after the option name.
/// @param[out] rettv  Location where result is saved.
/// @param[in] evaluate  If not true, rettv is not populated.
///
/// @return  OK or FAIL.
int eval_option(const char **const arg, typval_T *const rettv, const bool evaluate)
  FUNC_ATTR_NONNULL_ARG(1)
{
  const bool working = (**arg == '+');  // has("+option")
  OptIndex opt_idx;
  int scope;

  // Isolate the option name and find its value.
  char *const option_end = (char *)find_option_var_end(arg, &opt_idx, &scope);

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

  char c = *option_end;
  *option_end = NUL;

  int ret = OK;
  bool is_tty_opt = is_tty_option(*arg);

  if (opt_idx == kOptInvalid && !is_tty_opt) {
    // Only give error if result is going to be used.
    if (rettv != NULL) {
      semsg(_("E113: Unknown option: %s"), *arg);
    }

    ret = FAIL;
  } else if (rettv != NULL) {
    OptVal value = is_tty_opt ? get_tty_option(*arg) : get_option_value(opt_idx, scope);
    assert(value.type != kOptValTypeNil);

    *rettv = optval_as_tv(value, true);
  } else if (working && !is_tty_opt && is_option_hidden(opt_idx)) {
    ret = FAIL;
  }

  *option_end = c;                  // put back for error messages
  *arg = option_end;

  return ret;
}

/// Allocate a variable for a number constant.  Also deals with "0z" for blob.
///
/// @return  OK or FAIL.
static int eval_number(char **arg, typval_T *rettv, bool evaluate, bool want_string)
{
  char *p = skipdigits(*arg + 1);
  bool get_float = false;

  // We accept a float when the format matches
  // "[0-9]\+\.[0-9]\+\([eE][+-]\?[0-9]\+\)\?".  This is very
  // strict to avoid backwards compatibility problems.
  // Don't look for a float after the "." operator, so that
  // ":let vers = 1.2.3" doesn't fail.
  if (!want_string && p[0] == '.' && ascii_isdigit(p[1])) {
    get_float = true;
    p = skipdigits(p + 2);
    if (*p == 'e' || *p == 'E') {
      p++;
      if (*p == '-' || *p == '+') {
        p++;
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
    *arg += string2float(*arg, &f);
    if (evaluate) {
      rettv->v_type = VAR_FLOAT;
      rettv->vval.v_float = f;
    }
  } else if (**arg == '0' && ((*arg)[1] == 'z' || (*arg)[1] == 'Z')) {
    // Blob constant: 0z0123456789abcdef
    blob_T *blob = NULL;
    if (evaluate) {
      blob = tv_blob_alloc();
    }
    char *bp;
    for (bp = *arg + 2; ascii_isxdigit(bp[0]); bp += 2) {
      if (!ascii_isxdigit(bp[1])) {
        if (blob != NULL) {
          emsg(_("E973: Blob literal should have an even number of hex characters"));
          ga_clear(&blob->bv_ga);
          XFREE_CLEAR(blob);
        }
        return FAIL;
      }
      if (blob != NULL) {
        ga_append(&blob->bv_ga, (uint8_t)((hex2nr(*bp) << 4) + hex2nr(*(bp + 1))));
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
    int len;
    varnumber_T n;
    vim_str2nr(*arg, NULL, &len, STR2NR_ALL, &n, NULL, 0, true, NULL);
    if (len == 0) {
      if (evaluate) {
        semsg(_(e_invexpr2), *arg);
      }
      return FAIL;
    }
    *arg += len;
    if (evaluate) {
      rettv->v_type = VAR_NUMBER;
      rettv->vval.v_number = n;
    }
  }
  return OK;
}

/// Evaluate a string constant and put the result in "rettv".
/// "*arg" points to the double quote or to after it when "interpolate" is true.
/// When "interpolate" is true reduce "{{" to "{", reduce "}}" to "}" and stop
/// at a single "{".
///
/// @return  OK or FAIL.
static int eval_string(char **arg, typval_T *rettv, bool evaluate, bool interpolate)
{
  char *p;
  const char *const arg_end = *arg + strlen(*arg);
  unsigned extra = interpolate ? 1 : 0;
  const int off = interpolate ? 0 : 1;

  // Find the end of the string, skipping backslashed characters.
  for (p = *arg + off; *p != NUL && *p != '"'; MB_PTR_ADV(p)) {
    if (*p == '\\' && p[1] != NUL) {
      p++;
      // A "\<x>" form occupies at least 4 characters, and produces up
      // to 9 characters (6 for the char and 3 for a modifier):
      // reserve space for 5 extra.
      if (*p == '<') {
        int modifiers = 0;
        int flags = FSK_KEYCODE | FSK_IN_STRING;

        extra += 5;

        // Skip to the '>' to avoid using '{' inside for string
        // interpolation.
        if (p[1] != '*') {
          flags |= FSK_SIMPLIFY;
        }
        if (find_special_key((const char **)&p, (size_t)(arg_end - p),
                             &modifiers, flags, NULL) != 0) {
          p--;  // leave "p" on the ">"
        }
      }
    } else if (interpolate && (*p == '{' || *p == '}')) {
      if (*p == '{' && p[1] != '{') {  // start of expression
        break;
      }
      p++;
      if (p[-1] == '}' && *p != '}') {  // single '}' is an error
        semsg(_(e_stray_closing_curly_str), *arg);
        return FAIL;
      }
      extra--;  // "{{" becomes "{", "}}" becomes "}"
    }
  }

  if (*p != '"' && !(interpolate && *p == '{')) {
    semsg(_("E114: Missing quote: %s"), *arg);
    return FAIL;
  }

  // If only parsing, set *arg and return here
  if (!evaluate) {
    *arg = p + off;
    return OK;
  }

  // Copy the string into allocated memory, handling backslashed
  // characters.
  rettv->v_type = VAR_STRING;
  const int len = (int)(p - *arg + extra);
  rettv->vval.v_string = xmalloc((size_t)len);
  char *end = rettv->vval.v_string;

  for (p = *arg + off; *p != NUL && *p != '"';) {
    if (*p == '\\') {
      switch (*++p) {
      case 'b':
        *end++ = BS; ++p; break;
      case 'e':
        *end++ = ESC; ++p; break;
      case 'f':
        *end++ = FF; ++p; break;
      case 'n':
        *end++ = NL; ++p; break;
      case 'r':
        *end++ = CAR; ++p; break;
      case 't':
        *end++ = TAB; ++p; break;

      case 'X':           // hex: "\x1", "\x12"
      case 'x':
      case 'u':           // Unicode: "\u0023"
      case 'U':
        if (ascii_isxdigit(p[1])) {
          int n, nr;
          int c = toupper((uint8_t)(*p));

          if (c == 'X') {
            n = 2;
          } else if (*p == 'u') {
            n = 4;
          } else {
            n = 8;
          }
          nr = 0;
          while (--n >= 0 && ascii_isxdigit(p[1])) {
            p++;
            nr = (nr << 4) + hex2nr(*p);
          }
          p++;
          // For "\u" store the number according to
          // 'encoding'.
          if (c != 'X') {
            end += utf_char2bytes(nr, end);
          } else {
            *end++ = (char)nr;
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
        *end = (char)(*p++ - '0');
        if (*p >= '0' && *p <= '7') {
          *end = (char)((*end << 3) + *p++ - '0');
          if (*p >= '0' && *p <= '7') {
            *end = (char)((*end << 3) + *p++ - '0');
          }
        }
        end++;
        break;

      // Special key, e.g.: "\<C-W>"
      case '<': {
        int flags = FSK_KEYCODE | FSK_IN_STRING;

        if (p[1] != '*') {
          flags |= FSK_SIMPLIFY;
        }
        extra = trans_special((const char **)&p, (size_t)(arg_end - p),
                              end, flags, false, NULL);
        if (extra != 0) {
          end += extra;
          if (end >= rettv->vval.v_string + len) {
            iemsg("eval_string() used more space than allocated");
          }
          break;
        }
      }
        FALLTHROUGH;

      default:
        mb_copy_char((const char **)&p, &end);
        break;
      }
    } else {
      if (interpolate && (*p == '{' || *p == '}')) {
        if (*p == '{' && p[1] != '{') {  // start of expression
          break;
        }
        p++;  // reduce "{{" to "{" and "}}" to "}"
      }
      mb_copy_char((const char **)&p, &end);
    }
  }
  *end = NUL;
  if (*p == '"' && !interpolate) {
    p++;
  }
  *arg = p;

  return OK;
}

/// Allocate a variable for a 'str''ing' constant.
/// When "interpolate" is true reduce "{{" to "{" and stop at a single "{".
///
/// @return  OK when a "rettv" was set to the string.
///          FAIL on error, "rettv" is not set.
static int eval_lit_string(char **arg, typval_T *rettv, bool evaluate, bool interpolate)
{
  char *p;
  int reduce = interpolate ? -1 : 0;
  const int off = interpolate ? 0 : 1;

  // Find the end of the string, skipping ''.
  for (p = *arg + off; *p != NUL; MB_PTR_ADV(p)) {
    if (*p == '\'') {
      if (p[1] != '\'') {
        break;
      }
      reduce++;
      p++;
    } else if (interpolate) {
      if (*p == '{') {
        if (p[1] != '{') {
          break;
        }
        p++;
        reduce++;
      } else if (*p == '}') {
        p++;
        if (*p != '}') {
          semsg(_(e_stray_closing_curly_str), *arg);
          return FAIL;
        }
        reduce++;
      }
    }
  }

  if (*p != '\'' && !(interpolate && *p == '{')) {
    semsg(_("E115: Missing quote: %s"), *arg);
    return FAIL;
  }

  // If only parsing return after setting "*arg"
  if (!evaluate) {
    *arg = p + off;
    return OK;
  }

  // Copy the string into allocated memory, handling '' to ' reduction and
  // any expressions.
  char *str = xmalloc((size_t)((p - *arg) - reduce));
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = str;

  for (p = *arg + off; *p != NUL;) {
    if (*p == '\'') {
      if (p[1] != '\'') {
        break;
      }
      p++;
    } else if (interpolate && (*p == '{' || *p == '}')) {
      if (*p == '{' && p[1] != '{') {
        break;
      }
      p++;
    }
    mb_copy_char((const char **)&p, &str);
  }
  *str = NUL;
  *arg = p + off;

  return OK;
}

/// Evaluate a single or double quoted string possibly containing expressions.
/// "arg" points to the '$'.  The result is put in "rettv".
///
/// @return  OK or FAIL.
int eval_interp_string(char **arg, typval_T *rettv, bool evaluate)
{
  int ret = OK;

  garray_T ga;
  ga_init(&ga, 1, 80);

  // *arg is on the '$' character, move it to the first string character.
  (*arg)++;
  const int quote = (uint8_t)(**arg);
  (*arg)++;

  while (true) {
    typval_T tv;
    // Get the string up to the matching quote or to a single '{'.
    // "arg" is advanced to either the quote or the '{'.
    if (quote == '"') {
      ret = eval_string(arg, &tv, evaluate, true);
    } else {
      ret = eval_lit_string(arg, &tv, evaluate, true);
    }
    if (ret == FAIL) {
      break;
    }
    if (evaluate) {
      ga_concat(&ga, tv.vval.v_string);
      tv_clear(&tv);
    }

    if (**arg != '{') {
      // found terminating quote
      (*arg)++;
      break;
    }
    char *p = eval_one_expr_in_str(*arg, &ga, evaluate);
    if (p == NULL) {
      ret = FAIL;
      break;
    }
    *arg = p;
  }

  rettv->v_type = VAR_STRING;
  if (ret != FAIL && evaluate) {
    ga_append(&ga, NUL);
  }
  rettv->vval.v_string = ga.ga_data;
  return OK;
}

/// @return  the function name of the partial.
char *partial_name(partial_T *pt)
  FUNC_ATTR_PURE
{
  if (pt != NULL) {
    if (pt->pt_name != NULL) {
      return pt->pt_name;
    }
    if (pt->pt_func != NULL) {
      return pt->pt_func->uf_name;
    }
  }
  return "";
}

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

/// Unreference a closure: decrement the reference count and free it when it
/// becomes zero.
void partial_unref(partial_T *pt)
{
  if (pt == NULL) {
    return;
  }

  if (--pt->pt_refcount <= 0) {
    partial_free(pt);
  }
}

/// Allocate a variable for a List and fill it from "*arg".
///
/// @param arg  "*arg" points to the "[".
/// @return  OK or FAIL.
static int eval_list(char **arg, typval_T *rettv, evalarg_T *const evalarg)
{
  const bool evaluate = evalarg == NULL ? false : evalarg->eval_flags & EVAL_EVALUATE;
  list_T *l = NULL;

  if (evaluate) {
    l = tv_list_alloc(kListLenShouldKnow);
  }

  *arg = skipwhite(*arg + 1);
  while (**arg != ']' && **arg != NUL) {
    typval_T tv;
    if (eval1(arg, &tv, evalarg) == FAIL) {  // Recursive!
      goto failret;
    }
    if (evaluate) {
      tv.v_lock = VAR_UNLOCKED;
      tv_list_append_owned_tv(l, tv);
    }

    // the comma must come after the value
    bool had_comma = **arg == ',';
    if (had_comma) {
      *arg = skipwhite(*arg + 1);
    }

    if (**arg == ']') {
      break;
    }

    if (!had_comma) {
      semsg(_("E696: Missing comma in List: %s"), *arg);
      goto failret;
    }
  }

  if (**arg != ']') {
    semsg(_(e_list_end), *arg);
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
  // empty and NULL function name considered the same
  char *s1 = tv1->v_type == VAR_FUNC ? tv1->vval.v_string : partial_name(tv1->vval.v_partial);
  if (s1 != NULL && *s1 == NUL) {
    s1 = NULL;
  }
  char *s2 = tv2->v_type == VAR_FUNC ? tv2->vval.v_string : partial_name(tv2->vval.v_partial);
  if (s2 != NULL && *s2 == NUL) {
    s2 = NULL;
  }
  if (s1 == NULL || s2 == NULL) {
    if (s1 != s2) {
      return false;
    }
  } else if (strcmp(s1, s2) != 0) {
    return false;
  }

  // empty dict and NULL dict is different
  dict_T *d1 = tv1->v_type == VAR_FUNC ? NULL : tv1->vval.v_partial->pt_dict;
  dict_T *d2 = tv2->v_type == VAR_FUNC ? NULL : tv2->vval.v_partial->pt_dict;
  if (d1 == NULL || d2 == NULL) {
    if (d1 != d2) {
      return false;
    }
  } else if (!tv_dict_equal(d1, d2, ic, true)) {
    return false;
  }

  // empty list and no list considered the same
  int a1 = tv1->v_type == VAR_FUNC ? 0 : tv1->vval.v_partial->pt_argc;
  int a2 = tv2->v_type == VAR_FUNC ? 0 : tv2->vval.v_partial->pt_argc;
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

/// Garbage collection for lists and dictionaries.
///
/// We use reference counts to be able to free most items right away when they
/// are no longer used.  But for composite items it's possible that it becomes
/// unused while the reference count is > 0: When there is a recursive
/// reference.  Example:
///      :let l = [1, 2, 3]
///      :let d = {9: l}
///      :let l[1] = d
///
/// Since this is quite unusual we handle this with garbage collection: every
/// once in a while find out which lists and dicts are not referenced from any
/// variable.
///
/// Here is a good reference text about garbage collection (refers to Python
/// but it applies to all reference-counting mechanisms):
///      http://python.ca/nas/python/gc/

/// Do garbage collection for lists and dicts.
///
/// @param testing  true if called from test_garbagecollect_now().
///
/// @return  true if some memory was freed.
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

  // The execution stack can grow big, limit the size.
  if (exestack.ga_maxlen - exestack.ga_len > 500) {
    // Keep 150% of the current size, with a minimum of the growth size.
    int n = exestack.ga_len / 2;
    if (n < exestack.ga_growsize) {
      n = exestack.ga_growsize;
    }

    // Don't make it bigger though.
    if (exestack.ga_len + n < exestack.ga_maxlen) {
      size_t new_len = (size_t)exestack.ga_itemsize * (size_t)(exestack.ga_len + n);
      char *pp = xrealloc(exestack.ga_data, new_len);
      exestack.ga_maxlen = exestack.ga_len + n;
      exestack.ga_data = pp;
    }
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
  for (int i = 1; i <= script_items.ga_len; i++) {
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
    ABORTING(set_ref_in_callback)(&buf->b_prompt_callback, copyID, NULL, NULL);
    ABORTING(set_ref_in_callback)(&buf->b_prompt_interrupt, copyID, NULL, NULL);
    ABORTING(set_ref_in_callback)(&buf->b_cfu_cb, copyID, NULL, NULL);
    ABORTING(set_ref_in_callback)(&buf->b_ofu_cb, copyID, NULL, NULL);
    ABORTING(set_ref_in_callback)(&buf->b_tsrfu_cb, copyID, NULL, NULL);
    ABORTING(set_ref_in_callback)(&buf->b_tfu_cb, copyID, NULL, NULL);
  }

  // 'completefunc', 'omnifunc' and 'thesaurusfunc' callbacks
  ABORTING(set_ref_in_insexpand_funcs)(copyID);

  // 'operatorfunc' callback
  ABORTING(set_ref_in_opfunc)(copyID);

  // 'tagfunc' callback
  ABORTING(set_ref_in_tagfunc)(copyID);

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    // window-local variables
    ABORTING(set_ref_in_item)(&wp->w_winvar.di_tv, copyID, NULL, NULL);
    // window jump list (ShaDa additional data)
    for (int i = 0; i < wp->w_jumplistlen; i++) {
      ABORTING(set_ref_in_fmark)(wp->w_jumplist[i].fmark, copyID);
    }
  }
  // window-local variables in autocmd windows
  for (int i = 0; i < AUCMD_WIN_COUNT; i++) {
    if (aucmd_win[i].auc_win != NULL) {
      ABORTING(set_ref_in_item)(&aucmd_win[i].auc_win->w_winvar.di_tv, copyID, NULL, NULL);
    }
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
    for (int i = 0; i < HIST_COUNT; i++) {
      const void *iter = NULL;
      do {
        histentry_T hist;
        iter = hist_iter(iter, (uint8_t)i, false, &hist);
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
/// @note  This function may only be called from garbage_collect().
///
/// @param copyID  Free lists/dictionaries that don't have this ID.
///
/// @return  true, if something was freed.
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
  while (true) {
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
bool set_ref_in_list_items(list_T *l, int copyID, ht_stack_T **ht_stack)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  bool abort = false;
  list_stack_T *list_stack = NULL;

  list_T *cur_l = l;
  while (true) {
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
        abort = set_ref_in_list_items(ll, copyID, ht_stack);
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
/// @return  true if setting references failed somehow.
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
/// @return  true if setting references failed somehow.
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
/// @return  true if setting references failed somehow.
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

/// Get the key for #{key: val} into "tv" and advance "arg".
///
/// @return  FAIL when there is no valid key.
static int get_literal_key(char **arg, typval_T *tv)
  FUNC_ATTR_NONNULL_ALL
{
  char *p;

  if (!ASCII_ISALNUM(**arg) && **arg != '_' && **arg != '-') {
    return FAIL;
  }
  for (p = *arg; ASCII_ISALNUM(*p) || *p == '_' || *p == '-'; p++) {}
  tv->v_type = VAR_STRING;
  tv->vval.v_string = xmemdupz(*arg, (size_t)(p - *arg));

  *arg = skipwhite(p);
  return OK;
}

/// Allocate a variable for a Dictionary and fill it from "*arg".
///
/// @param arg  "*arg" points to the "{".
/// @param literal  true for #{key: val}
///
/// @return  OK or FAIL.  Returns NOTDONE for {expr}.
static int eval_dict(char **arg, typval_T *rettv, evalarg_T *const evalarg, bool literal)
{
  const bool evaluate = evalarg == NULL ? false : evalarg->eval_flags & EVAL_EVALUATE;
  typval_T tv;
  char *key = NULL;
  char *curly_expr = skipwhite(*arg + 1);
  char buf[NUMBUFLEN];

  // First check if it's not a curly-braces expression: {expr}.
  // Must do this without evaluating, otherwise a function may be called
  // twice.  Unfortunately this means we need to call eval1() twice for the
  // first item.
  // "{}" is an empty Dictionary.
  // "#{abc}" is never a curly-braces expression.
  if (*curly_expr != '}'
      && !literal
      && eval1(&curly_expr, &tv, NULL) == OK
      && *skipwhite(curly_expr) == '}') {
    return NOTDONE;
  }

  dict_T *d = NULL;
  if (evaluate) {
    d = tv_dict_alloc();
  }
  typval_T tvkey;
  tvkey.v_type = VAR_UNKNOWN;
  tv.v_type = VAR_UNKNOWN;

  *arg = skipwhite(*arg + 1);
  while (**arg != '}' && **arg != NUL) {
    if ((literal
         ? get_literal_key(arg, &tvkey)
         : eval1(arg, &tvkey, evalarg)) == FAIL) {  // recursive!
      goto failret;
    }
    if (**arg != ':') {
      semsg(_("E720: Missing colon in Dictionary: %s"), *arg);
      tv_clear(&tvkey);
      goto failret;
    }
    if (evaluate) {
      key = (char *)tv_get_string_buf_chk(&tvkey, buf);
      if (key == NULL) {
        // "key" is NULL when tv_get_string_buf_chk() gave an errmsg
        tv_clear(&tvkey);
        goto failret;
      }
    }

    *arg = skipwhite(*arg + 1);
    if (eval1(arg, &tv, evalarg) == FAIL) {  // Recursive!
      if (evaluate) {
        tv_clear(&tvkey);
      }
      goto failret;
    }
    if (evaluate) {
      dictitem_T *item = tv_dict_find(d, key, -1);
      if (item != NULL) {
        semsg(_("E721: Duplicate key in Dictionary: \"%s\""), key);
        tv_clear(&tvkey);
        tv_clear(&tv);
        goto failret;
      }
      item = tv_dict_item_alloc(key);
      item->di_tv = tv;
      item->di_tv.v_lock = VAR_UNLOCKED;
      if (tv_dict_add(d, item) == FAIL) {
        tv_dict_item_free(item);
      }
    }
    tv_clear(&tvkey);

    // the comma must come after the value
    bool had_comma = **arg == ',';
    if (had_comma) {
      *arg = skipwhite(*arg + 1);
    }

    if (**arg == '}') {
      break;
    }
    if (!had_comma) {
      semsg(_("E722: Missing comma in Dictionary: %s"), *arg);
      goto failret;
    }
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
/// @param[in] text  String to convert.
/// @param[out] ret_value  Location where conversion result is saved.
///
/// @return  Length of the text that was consumed.
size_t string2float(const char *const text, float_T *const ret_value)
  FUNC_ATTR_NONNULL_ALL
{
  // MS-Windows does not deal with "inf" and "nan" properly
  if (STRNICMP(text, "inf", 3) == 0) {
    *ret_value = (float_T)INFINITY;
    return 3;
  }
  if (STRNICMP(text, "-inf", 3) == 0) {
    *ret_value = (float_T)(-INFINITY);
    return 4;
  }
  if (STRNICMP(text, "nan", 3) == 0) {
    *ret_value = (float_T)NAN;
    return 3;
  }
  char *s = NULL;
  *ret_value = strtod(text, &s);
  return (size_t)(s - text);
}

/// Get the value of an environment variable.
///
/// If the environment variable was not set, silently assume it is empty.
///
/// @param arg  Points to the '$'.  It is advanced to after the name.
///
/// @return  FAIL if the name is invalid.
static int eval_env_var(char **arg, typval_T *rettv, int evaluate)
{
  (*arg)++;
  char *name = *arg;
  int len = get_env_len((const char **)arg);

  if (evaluate) {
    if (len == 0) {
      return FAIL;  // Invalid empty name.
    }
    int cc = (int)name[len];
    name[len] = NUL;
    // First try vim_getenv(), fast for normal environment vars.
    char *string = vim_getenv(name);
    if (string == NULL || *string == NUL) {
      xfree(string);

      // Next try expanding things like $VIM and ${HOME}.
      string = expand_env_save(name - 1);
      if (string != NULL && *string == '$') {
        XFREE_CLEAR(string);
      }
    }
    name[len] = (char)cc;
    rettv->v_type = VAR_STRING;
    rettv->vval.v_string = string;
    rettv->v_lock = VAR_UNLOCKED;
  }

  return OK;
}

/// Add an assert error to v:errors.
void assert_error(garray_T *gap)
{
  struct vimvar *vp = &vimvars[VV_ERRORS];

  if (vp->vv_type != VAR_LIST || vimvars[VV_ERRORS].vv_list == NULL) {
    // Make sure v:errors is a list.
    set_vim_var_list(VV_ERRORS, tv_list_alloc(1));
  }
  tv_list_append_string(vimvars[VV_ERRORS].vv_list, gap->ga_data, (ptrdiff_t)gap->ga_len);
}

/// Implementation of map(), filter(), foreach() for a Dict.  Apply "expr" to
/// every item in Dict "d" and return the result in "rettv".
static void filter_map_dict(dict_T *d, filtermap_T filtermap, const char *func_name,
                            const char *arg_errmsg, typval_T *expr, typval_T *rettv)
{
  if (filtermap == FILTERMAP_MAPNEW) {
    rettv->v_type = VAR_DICT;
    rettv->vval.v_dict = NULL;
  }
  if (d == NULL
      || (filtermap == FILTERMAP_FILTER
          && value_check_lock(d->dv_lock, arg_errmsg, TV_TRANSLATE))) {
    return;
  }

  dict_T *d_ret = NULL;

  if (filtermap == FILTERMAP_MAPNEW) {
    tv_dict_alloc_ret(rettv);
    d_ret = rettv->vval.v_dict;
  }

  vimvars[VV_KEY].vv_type = VAR_STRING;

  const VarLockStatus prev_lock = d->dv_lock;
  if (d->dv_lock == VAR_UNLOCKED) {
    d->dv_lock = VAR_LOCKED;
  }
  hash_lock(&d->dv_hashtab);
  TV_DICT_ITER(d, di, {
    if (filtermap == FILTERMAP_MAP
        && (value_check_lock(di->di_tv.v_lock, arg_errmsg, TV_TRANSLATE)
            || var_check_ro(di->di_flags, arg_errmsg, TV_TRANSLATE))) {
      break;
    }
    vimvars[VV_KEY].vv_str = xstrdup(di->di_key);
    typval_T newtv;
    bool rem;
    int r = filter_map_one(&di->di_tv, expr, filtermap, &newtv, &rem);
    tv_clear(&vimvars[VV_KEY].vv_tv);
    if (r == FAIL || did_emsg) {
      tv_clear(&newtv);
      break;
    }
    if (filtermap == FILTERMAP_MAP) {
      // map(): replace the dict item value
      tv_clear(&di->di_tv);
      newtv.v_lock = VAR_UNLOCKED;
      di->di_tv = newtv;
    } else if (filtermap == FILTERMAP_MAPNEW) {
      // mapnew(): add the item value to the new dict
      r = tv_dict_add_tv(d_ret, di->di_key, strlen(di->di_key), &newtv);
      tv_clear(&newtv);
      if (r == FAIL) {
        break;
      }
    } else if (filtermap == FILTERMAP_FILTER && rem) {
      // filter(false): remove the item from the dict
      if (var_check_fixed(di->di_flags, arg_errmsg, TV_TRANSLATE)
          || var_check_ro(di->di_flags, arg_errmsg, TV_TRANSLATE)) {
        break;
      }
      tv_dict_item_remove(d, di);
    }
  });
  hash_unlock(&d->dv_hashtab);
  d->dv_lock = prev_lock;
}

/// Implementation of map(), filter(), foreach() for a Blob.
static void filter_map_blob(blob_T *blob_arg, filtermap_T filtermap, typval_T *expr,
                            const char *arg_errmsg, typval_T *rettv)
{
  if (filtermap == FILTERMAP_MAPNEW) {
    rettv->v_type = VAR_BLOB;
    rettv->vval.v_blob = NULL;
  }
  blob_T *b = blob_arg;
  if (b == NULL
      || (filtermap == FILTERMAP_FILTER
          && value_check_lock(b->bv_lock, arg_errmsg, TV_TRANSLATE))) {
    return;
  }

  blob_T *b_ret = b;

  if (filtermap == FILTERMAP_MAPNEW) {
    tv_blob_copy(b, rettv);
    b_ret = rettv->vval.v_blob;
  }

  vimvars[VV_KEY].vv_type = VAR_NUMBER;

  const VarLockStatus prev_lock = b->bv_lock;
  if (b->bv_lock == 0) {
    b->bv_lock = VAR_LOCKED;
  }

  for (int i = 0, idx = 0; i < b->bv_ga.ga_len; i++) {
    const varnumber_T val = tv_blob_get(b, i);
    typval_T tv = {
      .v_type = VAR_NUMBER,
      .v_lock = VAR_UNLOCKED,
      .vval.v_number = val,
    };
    vimvars[VV_KEY].vv_nr = idx;
    typval_T newtv;
    bool rem;
    if (filter_map_one(&tv, expr, filtermap, &newtv, &rem) == FAIL
        || did_emsg) {
      break;
    }
    if (filtermap != FILTERMAP_FOREACH) {
      if (newtv.v_type != VAR_NUMBER && newtv.v_type != VAR_BOOL) {
        tv_clear(&newtv);
        emsg(_(e_invalblob));
        break;
      }
      if (filtermap != FILTERMAP_FILTER) {
        if (newtv.vval.v_number != val) {
          tv_blob_set(b_ret, i, (uint8_t)newtv.vval.v_number);
        }
      } else if (rem) {
        char *const p = (char *)blob_arg->bv_ga.ga_data;
        memmove(p + i, p + i + 1, (size_t)(b->bv_ga.ga_len - i - 1));
        b->bv_ga.ga_len--;
        i--;
      }
    }
    idx++;
  }

  b->bv_lock = prev_lock;
}

/// Implementation of map(), filter(), foreach() for a String.
static void filter_map_string(const char *str, filtermap_T filtermap, typval_T *expr,
                              typval_T *rettv)
{
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;

  vimvars[VV_KEY].vv_type = VAR_NUMBER;

  garray_T ga;
  ga_init(&ga, (int)sizeof(char), 80);
  int len = 0;
  int idx = 0;
  for (const char *p = str; *p != NUL; p += len) {
    len = utfc_ptr2len(p);
    typval_T tv = {
      .v_type = VAR_STRING,
      .v_lock = VAR_UNLOCKED,
      .vval.v_string = xmemdupz(p, (size_t)len),
    };

    vimvars[VV_KEY].vv_nr = idx;
    typval_T newtv;
    bool rem;
    if (filter_map_one(&tv, expr, filtermap, &newtv, &rem) == FAIL
        || did_emsg) {
      tv_clear(&newtv);
      tv_clear(&tv);
      break;
    }
    if (filtermap == FILTERMAP_MAP || filtermap == FILTERMAP_MAPNEW) {
      if (newtv.v_type != VAR_STRING) {
        tv_clear(&newtv);
        tv_clear(&tv);
        emsg(_(e_stringreq));
        break;
      } else {
        ga_concat(&ga, newtv.vval.v_string);
      }
    } else if (filtermap == FILTERMAP_FOREACH || !rem) {
      ga_concat(&ga, tv.vval.v_string);
    }

    tv_clear(&newtv);
    tv_clear(&tv);

    idx++;
  }
  ga_append(&ga, NUL);
  rettv->vval.v_string = ga.ga_data;
}

/// Implementation of map(), filter(), foreach() for a List.  Apply "expr" to
/// every item in List "l" and return the result in "rettv".
static void filter_map_list(list_T *l, filtermap_T filtermap, const char *func_name,
                            const char *arg_errmsg, typval_T *expr, typval_T *rettv)
{
  if (filtermap == FILTERMAP_MAPNEW) {
    rettv->v_type = VAR_LIST;
    rettv->vval.v_list = NULL;
  }
  if (l == NULL
      || (filtermap == FILTERMAP_FILTER
          && value_check_lock(tv_list_locked(l), arg_errmsg, TV_TRANSLATE))) {
    return;
  }

  list_T *l_ret = NULL;

  if (filtermap == FILTERMAP_MAPNEW) {
    tv_list_alloc_ret(rettv, kListLenUnknown);
    l_ret = rettv->vval.v_list;
  }

  vimvars[VV_KEY].vv_type = VAR_NUMBER;

  const VarLockStatus prev_lock = tv_list_locked(l);
  if (tv_list_locked(l) == VAR_UNLOCKED) {
    tv_list_set_lock(l, VAR_LOCKED);
  }

  int idx = 0;
  for (listitem_T *li = tv_list_first(l); li != NULL;) {
    if (filtermap == FILTERMAP_MAP
        && value_check_lock(TV_LIST_ITEM_TV(li)->v_lock, arg_errmsg, TV_TRANSLATE)) {
      break;
    }
    vimvars[VV_KEY].vv_nr = idx;
    typval_T newtv;
    bool rem;
    if (filter_map_one(TV_LIST_ITEM_TV(li), expr, filtermap, &newtv, &rem) == FAIL) {
      break;
    }
    if (did_emsg) {
      tv_clear(&newtv);
      break;
    }
    if (filtermap == FILTERMAP_MAP) {
      // map(): replace the list item value
      tv_clear(TV_LIST_ITEM_TV(li));
      newtv.v_lock = VAR_UNLOCKED;
      *TV_LIST_ITEM_TV(li) = newtv;
    } else if (filtermap == FILTERMAP_MAPNEW) {
      // mapnew(): append the list item value
      tv_list_append_owned_tv(l_ret, newtv);
    }
    if (filtermap == FILTERMAP_FILTER && rem) {
      li = tv_list_item_remove(l, li);
    } else {
      li = TV_LIST_ITEM_NEXT(l, li);
    }
    idx++;
  }

  tv_list_set_lock(l, prev_lock);
}

/// Implementation of map(), filter() and foreach().
static void filter_map(typval_T *argvars, typval_T *rettv, filtermap_T filtermap)
{
  const char *const func_name = (filtermap == FILTERMAP_MAP
                                 ? "map()"
                                 : (filtermap == FILTERMAP_MAPNEW
                                    ? "mapnew()"
                                    : (filtermap == FILTERMAP_FILTER
                                       ? "filter()"
                                       : "foreach()")));
  const char *const arg_errmsg = (filtermap == FILTERMAP_MAP
                                  ? N_("map() argument")
                                  : (filtermap == FILTERMAP_MAPNEW
                                     ? N_("mapnew() argument")
                                     : (filtermap == FILTERMAP_FILTER
                                        ? N_("filter() argument")
                                        : N_("foreach() argument"))));

  // map(), filter(), foreach() return the first argument, also on failure.
  if (filtermap != FILTERMAP_MAPNEW && argvars[0].v_type != VAR_STRING) {
    tv_copy(&argvars[0], rettv);
  }

  if (argvars[0].v_type != VAR_BLOB
      && argvars[0].v_type != VAR_LIST
      && argvars[0].v_type != VAR_DICT
      && argvars[0].v_type != VAR_STRING) {
    semsg(_(e_argument_of_str_must_be_list_string_dictionary_or_blob), func_name);
    return;
  }

  typval_T *expr = &argvars[1];
  // On type errors, the preceding call has already displayed an error
  // message.  Avoid a misleading error message for an empty string that
  // was not passed as argument.
  if (expr->v_type == VAR_UNKNOWN) {
    return;
  }

  typval_T save_val;
  prepare_vimvar(VV_VAL, &save_val);

  // We reset "did_emsg" to be able to detect whether an error
  // occurred during evaluation of the expression.
  int save_did_emsg = did_emsg;
  did_emsg = false;

  typval_T save_key;
  prepare_vimvar(VV_KEY, &save_key);
  if (argvars[0].v_type == VAR_DICT) {
    filter_map_dict(argvars[0].vval.v_dict, filtermap, func_name,
                    arg_errmsg, expr, rettv);
  } else if (argvars[0].v_type == VAR_BLOB) {
    filter_map_blob(argvars[0].vval.v_blob, filtermap, expr, arg_errmsg, rettv);
  } else if (argvars[0].v_type == VAR_STRING) {
    filter_map_string(tv_get_string(&argvars[0]), filtermap, expr, rettv);
  } else {
    assert(argvars[0].v_type == VAR_LIST);
    filter_map_list(argvars[0].vval.v_list, filtermap, func_name,
                    arg_errmsg, expr, rettv);
  }

  restore_vimvar(VV_KEY, &save_key);
  restore_vimvar(VV_VAL, &save_val);

  did_emsg |= save_did_emsg;
}

/// Handle one item for map(), filter(), foreach().
/// Sets v:val to "tv".  Caller must set v:key.
///
/// @param tv     original value
/// @param expr   callback
/// @param newtv  for map() an mapnew(): new value
/// @param remp   for filter(): remove flag
static int filter_map_one(typval_T *tv, typval_T *expr, const filtermap_T filtermap,
                          typval_T *newtv, bool *remp)
  FUNC_ATTR_NONNULL_ALL
{
  typval_T argv[3];
  int retval = FAIL;

  tv_copy(tv, &vimvars[VV_VAL].vv_tv);

  newtv->v_type = VAR_UNKNOWN;
  if (filtermap == FILTERMAP_FOREACH && expr->v_type == VAR_STRING) {
    // foreach() is not limited to an expression
    do_cmdline_cmd(expr->vval.v_string);
    if (!did_emsg) {
      retval = OK;
    }
    goto theend;
  }

  argv[0] = vimvars[VV_KEY].vv_tv;
  argv[1] = vimvars[VV_VAL].vv_tv;
  if (eval_expr_typval(expr, false, argv, 2, newtv) == FAIL) {
    goto theend;
  }
  if (filtermap == FILTERMAP_FILTER) {
    bool error = false;

    // filter(): when expr is zero remove the item
    *remp = (tv_get_number_chk(newtv, &error) == 0);
    tv_clear(newtv);
    // On type error, nothing has been removed; return FAIL to stop the
    // loop.  The error message was given by tv_get_number_chk().
    if (error) {
      goto theend;
    }
  } else if (filtermap == FILTERMAP_FOREACH) {
    tv_clear(newtv);
  }
  retval = OK;
theend:
  tv_clear(&vimvars[VV_VAL].vv_tv);
  return retval;
}

/// "filter()" function
void f_filter(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  filter_map(argvars, rettv, FILTERMAP_FILTER);
}

/// "map()" function
void f_map(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  filter_map(argvars, rettv, FILTERMAP_MAP);
}

/// "mapnew()" function
void f_mapnew(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  filter_map(argvars, rettv, FILTERMAP_MAPNEW);
}

/// "foreach()" function
void f_foreach(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  filter_map(argvars, rettv, FILTERMAP_FOREACH);
}

/// "function()" function
/// "funcref()" function
void common_function(typval_T *argvars, typval_T *rettv, bool is_funcref)
{
  char *s;
  char *name;
  bool use_string = false;
  partial_T *arg_pt = NULL;
  char *trans_name = NULL;

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
    s = (char *)tv_get_string(&argvars[0]);
    use_string = true;
  }

  if ((use_string && vim_strchr(s, AUTOLOAD_CHAR) == NULL) || is_funcref) {
    name = s;
    trans_name = save_function_name(&name, false,
                                    TFN_INT | TFN_QUIET | TFN_NO_AUTOLOAD | TFN_NO_DEREF, NULL);
    if (*name != NUL) {
      s = NULL;
    }
  }
  if (s == NULL || *s == NUL || (use_string && ascii_isdigit(*s))
      || (is_funcref && trans_name == NULL)) {
    semsg(_(e_invarg2), (use_string ? tv_get_string(&argvars[0]) : s));
    // Don't check an autoload name for existence here.
  } else if (trans_name != NULL
             && (is_funcref
                 ? find_func(trans_name) == NULL
                 : !translated_function_exists(trans_name))) {
    semsg(_("E700: Unknown function: %s"), s);
  } else {
    int dict_idx = 0;
    int arg_idx = 0;
    list_T *list = NULL;
    if (strncmp(s, "s:", 2) == 0 || strncmp(s, "<SID>", 5) == 0) {
      // Expand s: and <SID> into <SNR>nr_, so that the function can
      // also be called from another script. Using trans_function_name()
      // would also work, but some plugins depend on the name being
      // printable text.
      name = get_scriptlocal_funcname(s);
    } else {
      name = xstrdup(s);
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
        if (tv_check_for_dict_arg(argvars, dict_idx) == FAIL) {
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
          emsg_funcname(e_toomanyarg, s);
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
        pt->pt_argv = xmalloc(sizeof(pt->pt_argv[0]) * (size_t)pt->pt_argc);
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

/// Get the line number from Vimscript object
///
/// @note Unlike tv_get_lnum(), this one supports only "$" special string.
///
/// @param[in] tv   Object to get value from. Is expected to be a number or
///                 a special string "$".
/// @param[in] buf  Buffer to take last line number from in case tv is "$". May
///                 be NULL, in this case "$" results in zero return.
///
/// @return  Line number or 0 in case of error.
linenr_T tv_get_lnum_buf(const typval_T *const tv, const buf_T *const buf)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (tv->v_type == VAR_STRING
      && tv->vval.v_string != NULL
      && tv->vval.v_string[0] == '$'
      && tv->vval.v_string[1] == NUL
      && buf != NULL) {
    return buf->b_ml.ml_line_count;
  }
  return (linenr_T)tv_get_number_chk(tv, NULL);
}

/// This function is used by f_input() and f_inputdialog() functions. The third
/// argument to f_input() specifies the type of completion to use at the
/// prompt. The third argument to f_inputdialog() specifies the value to return
/// when the user cancels the prompt.
void get_user_input(const typval_T *const argvars, typval_T *const rettv, const bool inputdialog,
                    const bool secret)
  FUNC_ATTR_NONNULL_ALL
{
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;

  const char *prompt;
  const char *defstr = "";
  typval_T *cancelreturn = NULL;
  typval_T cancelreturn_strarg2 = TV_INITIAL_VALUE;
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
    dictitem_T *cancelreturn_di = tv_dict_find(dict, S_LEN("cancelreturn"));
    if (cancelreturn_di != NULL) {
      cancelreturn = &cancelreturn_di->di_tv;
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
        const char *const strarg2 = tv_get_string_buf_chk(&argvars[2], cancelreturn_buf);
        if (strarg2 == NULL) {
          return;
        }
        if (inputdialog) {
          cancelreturn_strarg2.v_type = VAR_STRING;
          cancelreturn_strarg2.vval.v_string = (char *)strarg2;
          cancelreturn = &cancelreturn_strarg2;
        } else {
          xp_name = strarg2;
        }
      }
    }
  }

  int xp_type = EXPAND_NOTHING;
  char *xp_arg = NULL;
  if (xp_name != NULL) {
    // input() with a third argument: completion
    const int xp_namelen = (int)strlen(xp_name);

    uint32_t argt = 0;
    if (parse_compl_arg(xp_name, xp_namelen, &xp_type,
                        &argt, &xp_arg) == FAIL) {
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
      p = lastnl + 1;
      msg_start();
      msg_clr_eos();
      msg_puts_len(prompt, p - prompt, echo_attr);
      msg_didout = false;
      msg_starthere();
    }
  }
  cmdline_row = msg_row;

  stuffReadbuffSpec(defstr);

  const int save_ex_normal_busy = ex_normal_busy;
  ex_normal_busy = 0;
  rettv->vval.v_string = getcmdline_prompt(secret ? NUL : '@', p, echo_attr, xp_type, xp_arg,
                                           input_callback);
  ex_normal_busy = save_ex_normal_busy;
  callback_free(&input_callback);

  if (rettv->vval.v_string == NULL && cancelreturn != NULL) {
    tv_copy(cancelreturn, rettv);
  }

  xfree(xp_arg);

  // Since the user typed this, no need to wait for return.
  need_wait_return = false;
  msg_didout = false;
  cmd_silent = cmd_silent_save;
}

/// Builds a process argument vector from a Vimscript object (typval_T).
///
/// @param[in]  cmd_tv      Vimscript object
/// @param[out] cmd         Returns the command or executable name.
/// @param[out] executable  Returns `false` if argv[0] is not executable.
///
/// @return  Result of `shell_build_argv()` if `cmd_tv` is a String.
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
  char **argv = xcalloc((size_t)argc + 1, sizeof(char *));
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

void return_register(int regname, typval_T *rettv)
{
  char buf[2] = { (char)regname, 0 };

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = xstrdup(buf);
}

void screenchar_adjust(ScreenGrid **grid, int *row, int *col)
{
  // TODO(bfredl): this is a hack for legacy tests which use screenchar()
  // to check printed messages on the screen (but not floats etc
  // as these are not legacy features). If the compositor is refactored to
  // have its own buffer, this should just read from it instead.
  msg_scroll_flush();

  *grid = ui_comp_get_grid_at_coord(*row, *col);

  // Make `row` and `col` relative to the grid
  *row -= (*grid)->comp_row;
  *col -= (*grid)->comp_col;
}

/// "stdpath()" helper for list results
void get_xdg_var_list(const XDGVarType xdg, typval_T *rettv)
  FUNC_ATTR_NONNULL_ALL
{
  list_T *const list = tv_list_alloc(kListLenShouldKnow);
  rettv->v_type = VAR_LIST;
  rettv->vval.v_list = list;
  tv_list_ref(list);
  char *const dirs = stdpaths_get_xdg_var(xdg);
  if (dirs == NULL) {
    return;
  }
  const void *iter = NULL;
  const char *appname = get_appname();
  do {
    size_t dir_len;
    const char *dir;
    iter = vim_env_iter(ENV_SEPCHAR, dirs, iter, &dir, &dir_len);
    if (dir != NULL && dir_len > 0) {
      char *dir_with_nvim = xmemdupz(dir, dir_len);
      dir_with_nvim = concat_fnames_realloc(dir_with_nvim, appname, true);
      tv_list_append_allocated_string(list, dir_with_nvim);
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

/// os_system wrapper. Handles 'verbose', :profile, and v:shell_error.
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
  char *input = save_tv_as_string(&argvars[1], &input_len, false, false);
  if (input_len < 0) {
    assert(input == NULL);
    return;
  }

  // get shell command to execute
  bool executable = true;
  char **argv = tv_to_argv(&argvars[0], NULL, &executable);
  if (!argv) {
    if (!executable) {
      set_vim_var_nr(VV_SHELL_ERROR, -1);
    }
    xfree(input);
    return;  // Already did emsg.
  }

  if (p_verbose > 3) {
    char *cmdstr = shell_argv_to_str(argv);
    verbose_enter_scroll();
    smsg(0, _("Executing command: \"%s\""), cmdstr);
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
  int status = os_system(argv, input, (size_t)input_len, &res, &nread);

  if (profiling) {
    prof_child_exit(&wait_time);
  }

  xfree(input);

  set_vim_var_nr(VV_SHELL_ERROR, status);

  if (res == NULL) {
    if (retlist) {
      // return an empty list when there's no output
      tv_list_alloc_ret(rettv, 0);
    } else {
      rettv->vval.v_string = xstrdup("");
    }
    return;
  }

  if (retlist) {
    int keepempty = 0;
    if (argvars[1].v_type != VAR_UNKNOWN && argvars[2].v_type != VAR_UNKNOWN) {
      keepempty = (int)tv_get_number(&argvars[2]);
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
    for (char *s = res; *s; s++) {
      if (s[0] == CAR && s[1] == NL) {
        s++;
      }

      *d++ = *s;
    }

    *d = NUL;
#endif
    rettv->vval.v_string = res;
  }
}

/// Get a callback from "arg".  It can be a Funcref or a function name.
bool callback_from_typval(Callback *const callback, const typval_T *const arg)
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
    char *name = arg->vval.v_string;
    if (name == NULL) {
      r = FAIL;
    } else if (*name == NUL) {
      callback->type = kCallbackNone;
      callback->data.funcref = NULL;
    } else {
      callback->data.funcref = NULL;
      if (arg->v_type == VAR_STRING) {
        callback->data.funcref = get_scriptlocal_funcname(name);
      }
      if (callback->data.funcref == NULL) {
        callback->data.funcref = xstrdup(name);
      }
      func_ref(callback->data.funcref);
      callback->type = kCallbackFuncref;
    }
  } else if (nlua_is_table_from_lua(arg)) {
    // TODO(tjdvries): UnifiedCallback
    char *name = nlua_register_table_as_callable(arg);

    if (name != NULL) {
      callback->data.funcref = xstrdup(name);
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

static int callback_depth = 0;

int get_callback_depth(void)
{
  return callback_depth;
}

/// @return  whether the callback could be called.
bool callback_call(Callback *const callback, const int argcount_in, typval_T *const argvars_in,
                   typval_T *const rettv)
  FUNC_ATTR_NONNULL_ALL
{
  if (callback_depth > p_mfd) {
    emsg(_(e_command_too_recursive));
    return false;
  }

  partial_T *partial;
  char *name;
  Array args = ARRAY_DICT_INIT;
  Object rv;
  switch (callback->type) {
  case kCallbackFuncref:
    name = callback->data.funcref;
    int len = (int)strlen(name);
    if (len >= 6 && !memcmp(name, "v:lua.", 6)) {
      name += 6;
      len = check_luafunc_name(name, false);
      if (len == 0) {
        return false;
      }
      partial = vvlua_partial;
    } else {
      partial = NULL;
    }
    break;

  case kCallbackPartial:
    partial = callback->data.partial;
    name = partial_name(partial);
    break;

  case kCallbackLua:
    rv = nlua_call_ref(callback->data.luaref, NULL, args, kRetNilBool, NULL, NULL);
    return LUARET_TRUTHY(rv);

  case kCallbackNone:
    return false;
    break;
  }

  funcexe_T funcexe = FUNCEXE_INIT;
  funcexe.fe_firstline = curwin->w_cursor.lnum;
  funcexe.fe_lastline = curwin->w_cursor.lnum;
  funcexe.fe_evaluate = true;
  funcexe.fe_partial = partial;

  callback_depth++;
  int ret = call_func(name, -1, rettv, argcount_in, argvars_in, &funcexe);
  callback_depth--;
  return ret;
}

bool set_ref_in_callback(Callback *callback, int copyID, ht_stack_T **ht_stack,
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

  case kCallbackLua:
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
  return pmap_get(uint64_t)(&timers, (uint64_t)xx);
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
    if (!timer->stopped || timer->refcount > 1) {
      add_timer_info(rettv, timer);
    }
  })
}

/// invoked on the main loop
void timer_due_cb(TimeWatcher *tw, void *data)
{
  timer_T *timer = (timer_T *)data;
  int save_did_emsg = did_emsg;
  const int called_emsg_before = called_emsg;
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

  callback_call(&timer->callback, 1, argv, &rettv);

  // Handle error message
  if (called_emsg > called_emsg_before && did_emsg) {
    timer->emsg_count++;
    if (did_throw) {
      discard_current_exception();
    }
  }
  did_emsg = save_did_emsg;
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

uint64_t timer_start(const int64_t timeout, const int repeat_count, const Callback *const callback)
{
  timer_T *timer = xmalloc(sizeof *timer);
  timer->refcount = 1;
  timer->stopped = false;
  timer->paused = false;
  timer->emsg_count = 0;
  timer->repeat_count = repeat_count;
  timer->timeout = timeout;
  timer->timer_id = (int)last_timer_id++;
  timer->callback = *callback;

  time_watcher_init(&main_loop, &timer->tw, timer);
  timer->tw.events = multiqueue_new_child(main_loop.events);
  // if main loop is blocked, don't queue up multiple events
  timer->tw.blockable = true;
  time_watcher_start(&timer->tw, timer_due_cb, (uint64_t)timeout, (uint64_t)timeout);

  pmap_put(uint64_t)(&timers, (uint64_t)timer->timer_id, timer);
  return (uint64_t)timer->timer_id;
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

/// This will be run on the main loop after the last timer_due_cb, so at this
/// point it is safe to free the callback.
static void timer_close_cb(TimeWatcher *tw, void *data)
{
  timer_T *timer = (timer_T *)data;
  multiqueue_free(timer->tw.events);
  callback_free(&timer->callback);
  pmap_del(uint64_t)(&timers, (uint64_t)timer->timer_id, NULL);
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

/// Read blob from file "fd".
/// Caller has allocated a blob in "rettv".
///
/// @param[in]  fd  File to read from.
/// @param[in,out]  rettv  Blob to write to.
/// @param[in]  offset  Read the file from the specified offset.
/// @param[in]  size  Read the specified size, or -1 if no limit.
///
/// @return  OK on success, or FAIL on failure.
int read_blob(FILE *const fd, typval_T *rettv, off_T offset, off_T size_arg)
  FUNC_ATTR_NONNULL_ALL
{
  blob_T *const blob = rettv->vval.v_blob;
  FileInfo file_info;
  if (!os_fileinfo_fd(fileno(fd), &file_info)) {
    return FAIL;  // can't read the file, error
  }

  int whence;
  off_T size = size_arg;
  const off_T file_size = (off_T)os_fileinfo_size(&file_info);
  if (offset >= 0) {
    // The size defaults to the whole file.  If a size is given it is
    // limited to not go past the end of the file.
    if (size == -1 || (size > file_size - offset && !S_ISCHR(file_info.stat.st_mode))) {
      // size may become negative, checked below
      size = (off_T)os_fileinfo_size(&file_info) - offset;
    }
    whence = SEEK_SET;
  } else {
    // limit the offset to not go before the start of the file
    if (-offset > file_size && !S_ISCHR(file_info.stat.st_mode)) {
      offset = -file_size;
    }
    // Size defaults to reading until the end of the file.
    if (size == -1 || size > -offset) {
      size = -offset;
    }
    whence = SEEK_END;
  }
  if (size <= 0) {
    return OK;
  }
  if (offset != 0 && vim_fseek(fd, offset, whence) != 0) {
    return OK;
  }

  ga_grow(&blob->bv_ga, (int)size);
  blob->bv_ga.ga_len = (int)size;
  if (fread(blob->bv_ga.ga_data, 1, (size_t)blob->bv_ga.ga_len, fd)
      < (size_t)blob->bv_ga.ga_len) {
    // An empty blob is returned on error.
    tv_blob_free(rettv->vval.v_blob);
    rettv->vval.v_blob = NULL;
    return FAIL;
  }
  return OK;
}

/// Saves a typval_T as a string.
///
/// For lists or buffers, replaces NLs with NUL and separates items with NLs.
///
/// @param[in]  tv   Value to store as a string.
/// @param[out] len  Length of the resulting string or -1 on error.
/// @param[in]  endnl If true, the output will end in a newline (if a list).
/// @param[in]  crlf  If true, list items will be joined with CRLF (if a list).
/// @returns an allocated string if `tv` represents a Vimscript string, list, or
///          number; NULL otherwise.
char *save_tv_as_string(typval_T *tv, ptrdiff_t *const len, bool endnl, bool crlf)
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
      *len = (ptrdiff_t)strlen(ret);
      return xmemdupz(ret, (size_t)(*len));
    } else {
      *len = -1;
      return NULL;
    }
  }

  if (tv->v_type == VAR_NUMBER) {  // Treat number as a buffer-id.
    buf_T *buf = buflist_findnr((int)tv->vval.v_number);
    if (buf) {
      for (linenr_T lnum = 1; lnum <= buf->b_ml.ml_line_count; lnum++) {
        for (char *p = ml_get_buf(buf, lnum); *p != NUL; p++) {
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

    char *ret = xmalloc((size_t)(*len) + 1);
    char *end = ret;
    for (linenr_T lnum = 1; lnum <= buf->b_ml.ml_line_count; lnum++) {
      for (char *p = ml_get_buf(buf, lnum); *p != NUL; p++) {
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
    *len += (ptrdiff_t)strlen(tv_get_string(TV_LIST_ITEM_TV(li))) + (crlf ? 2 : 1);
  });

  if (*len == 0) {
    return NULL;
  }

  char *ret = xmalloc((size_t)(*len) + (endnl ? (crlf ? 2 : 1) : 0));
  char *end = ret;
  TV_LIST_ITER_CONST(list, li, {
    for (const char *s = tv_get_string(TV_LIST_ITEM_TV(li)); *s != NUL; s++) {
      *end++ = (*s == '\n') ? NUL : *s;
    }
    if (endnl || TV_LIST_ITEM_NEXT(list, li) != NULL) {
      if (crlf) {
        *end++ = '\r';
      }
      *end++ = '\n';
    }
  });
  *end = NUL;
  *len = end - ret;
  return ret;
}

/// Convert the specified byte index of line 'lnum' in buffer 'buf' to a
/// character index.  Works only for loaded buffers. Returns -1 on failure.
/// The index of the first byte and the first character is zero.
int buf_byteidx_to_charidx(buf_T *buf, linenr_T lnum, int byteidx)
{
  if (buf == NULL || buf->b_ml.ml_mfp == NULL) {
    return -1;
  }

  if (lnum > buf->b_ml.ml_line_count) {
    lnum = buf->b_ml.ml_line_count;
  }

  char *str = ml_get_buf(buf, lnum);

  if (*str == NUL) {
    return 0;
  }

  // count the number of characters
  char *t = str;
  int count;
  for (count = 0; *t != NUL && t <= str + byteidx; count++) {
    t += utfc_ptr2len(t);
  }

  // In insert mode, when the cursor is at the end of a non-empty line,
  // byteidx points to the NUL character immediately past the end of the
  // string. In this case, add one to the character count.
  if (*t == NUL && byteidx != 0 && t == str + byteidx) {
    count++;
  }

  return count - 1;
}

/// Convert the specified character index of line 'lnum' in buffer 'buf' to a
/// byte index.  Works only for loaded buffers.
/// The index of the first byte and the first character is zero.
///
/// @return  -1 on failure.
int buf_charidx_to_byteidx(buf_T *buf, linenr_T lnum, int charidx)
{
  if (buf == NULL || buf->b_ml.ml_mfp == NULL) {
    return -1;
  }

  if (lnum > buf->b_ml.ml_line_count) {
    lnum = buf->b_ml.ml_line_count;
  }

  char *str = ml_get_buf(buf, lnum);

  // Convert the character offset to a byte offset
  char *t = str;
  while (*t != NUL && --charidx > 0) {
    t += utfc_ptr2len(t);
  }

  return (int)(t - str);
}

/// Translate a Vimscript object into a position
///
/// Accepts VAR_LIST and VAR_STRING objects. Does not give an error for invalid
/// type.
///
/// @param[in]  tv  Object to translate.
/// @param[in]  dollar_lnum  True when "$" is last line.
/// @param[out]  ret_fnum  Set to fnum for marks.
/// @param[in]  charcol  True to return character column.
///
/// @return Pointer to position or NULL in case of error (e.g. invalid type).
pos_T *var2fpos(const typval_T *const tv, const bool dollar_lnum, int *const ret_fnum,
                const bool charcol)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  static pos_T pos;

  // Argument can be [lnum, col, coladd].
  if (tv->v_type == VAR_LIST) {
    bool error = false;

    list_T *l = tv->vval.v_list;
    if (l == NULL) {
      return NULL;
    }

    // Get the line number.
    pos.lnum = (linenr_T)tv_list_find_nr(l, 0, &error);
    if (error || pos.lnum <= 0 || pos.lnum > curbuf->b_ml.ml_line_count) {
      // Invalid line number.
      return NULL;
    }

    // Get the column number.
    pos.col = (colnr_T)tv_list_find_nr(l, 1, &error);
    if (error) {
      return NULL;
    }
    int len;
    if (charcol) {
      len = mb_charlen(ml_get(pos.lnum));
    } else {
      len = ml_get_len(pos.lnum);
    }

    // We accept "$" for the column number: last column.
    listitem_T *li = tv_list_find(l, 1);
    if (li != NULL && TV_LIST_ITEM_TV(li)->v_type == VAR_STRING
        && TV_LIST_ITEM_TV(li)->vval.v_string != NULL
        && strcmp(TV_LIST_ITEM_TV(li)->vval.v_string, "$") == 0) {
      pos.col = len + 1;
    }

    // Accept a position up to the NUL after the line.
    if (pos.col == 0 || (int)pos.col > len + 1) {
      // Invalid column number.
      return NULL;
    }
    pos.col--;

    // Get the virtual offset.  Defaults to zero.
    pos.coladd = (colnr_T)tv_list_find_nr(l, 2, &error);
    if (error) {
      pos.coladd = 0;
    }

    return &pos;
  }

  const char *const name = tv_get_string_chk(tv);
  if (name == NULL) {
    return NULL;
  }

  pos.lnum = 0;
  if (name[0] == '.') {
    // cursor
    pos = curwin->w_cursor;
  } else if (name[0] == 'v' && name[1] == NUL) {
    // Visual start
    if (VIsual_active) {
      pos = VIsual;
    } else {
      pos = curwin->w_cursor;
    }
  } else if (name[0] == '\'') {
    // mark
    int mname = (uint8_t)name[1];
    const fmark_T *const fm = mark_get(curbuf, curwin, NULL, kMarkAll, mname);
    if (fm == NULL || fm->mark.lnum <= 0) {
      return NULL;
    }
    pos = fm->mark;
    // Vimscript behavior, only provide fnum if mark is global.
    *ret_fnum = ASCII_ISUPPER(mname) || ascii_isdigit(mname) ? fm->fnum : *ret_fnum;
  }
  if (pos.lnum != 0) {
    if (charcol) {
      pos.col = buf_byteidx_to_charidx(curbuf, pos.lnum, pos.col);
    }
    return &pos;
  }

  pos.coladd = 0;

  if (name[0] == 'w' && dollar_lnum) {
    // the "w_valid" flags are not reset when moving the cursor, but they
    // do matter for update_topline() and validate_botline().
    check_cursor_moved(curwin);

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
      if (charcol) {
        pos.col = (colnr_T)mb_charlen(get_cursor_line_ptr());
      } else {
        pos.col = get_cursor_line_len();
      }
    }
    return &pos;
  }
  return NULL;
}

/// Convert list in "arg" into position "posp" and optional file number "fnump".
/// When "fnump" is NULL there is no file number, only 3 items: [lnum, col, off]
/// Note that the column is passed on as-is, the caller may want to decrement
/// it to use 1 for the first column.
///
/// @param charcol  if true, use the column as the character index instead of the
///                 byte index.
///
/// @return  FAIL when conversion is not possible, doesn't check the position for
///          validity.
int list2fpos(typval_T *arg, pos_T *posp, int *fnump, colnr_T *curswantp, bool charcol)
{
  list_T *l;

  // List must be: [fnum, lnum, col, coladd, curswant], where "fnum" is only
  // there when "fnump" isn't NULL; "coladd" and "curswant" are optional.
  if (arg->v_type != VAR_LIST
      || (l = arg->vval.v_list) == NULL
      || tv_list_len(l) < (fnump == NULL ? 2 : 3)
      || tv_list_len(l) > (fnump == NULL ? 4 : 5)) {
    return FAIL;
  }

  int i = 0;
  int n;
  if (fnump != NULL) {
    n = (int)tv_list_find_nr(l, i++, NULL);  // fnum
    if (n < 0) {
      return FAIL;
    }
    if (n == 0) {
      n = curbuf->b_fnum;  // Current buffer.
    }
    *fnump = n;
  }

  n = (int)tv_list_find_nr(l, i++, NULL);  // lnum
  if (n < 0) {
    return FAIL;
  }
  posp->lnum = n;

  n = (int)tv_list_find_nr(l, i++, NULL);  // col
  if (n < 0) {
    return FAIL;
  }
  // If character position is specified, then convert to byte position
  // If the line number is zero use the cursor line.
  if (charcol) {
    // Get the text for the specified line in a loaded buffer
    buf_T *buf = buflist_findnr(fnump == NULL ? curbuf->b_fnum : *fnump);
    if (buf == NULL || buf->b_ml.ml_mfp == NULL) {
      return FAIL;
    }
    n = buf_charidx_to_byteidx(buf,
                               posp->lnum == 0 ? curwin->w_cursor.lnum : posp->lnum,
                               n) + 1;
  }
  posp->col = n;

  n = (int)tv_list_find_nr(l, i, NULL);  // off
  if (n < 0) {
    posp->coladd = 0;
  } else {
    posp->coladd = n;
  }

  if (curswantp != NULL) {
    *curswantp = (colnr_T)tv_list_find_nr(l, i + 1, NULL);  // curswant
  }

  return OK;
}

/// Get the length of an environment variable name.
/// Advance "arg" to the first character after the name.
///
/// @return  0 for error.
int get_env_len(const char **arg)
{
  const char *p;
  for (p = *arg; vim_isIDc((uint8_t)(*p)); p++) {}
  if (p == *arg) {  // No name found.
    return 0;
  }

  int len = (int)(p - *arg);
  *arg = p;
  return len;
}

/// Get the length of the name of a function or internal variable.
///
/// @param arg  is advanced to the first non-white character after the name.
///
/// @return  0 if something is wrong.
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
          || (len == 1 && vim_strchr(namespace_char, (uint8_t)(**arg)) == NULL)) {
        break;
      }
    }
  }
  if (p == *arg) {  // no name found
    return 0;
  }

  len = (int)(p - *arg);
  *arg = skipwhite(p);

  return len;
}

/// Get the length of the name of a variable or function.
/// Only the name is recognized, does not handle ".key" or "[idx]".
///
/// @param arg  is advanced to the first non-white character after the name.
///             If the name contains 'magic' {}'s, expand them and return the
///             expanded name in an allocated string via 'alias' - caller must free.
///
/// @return  -1 if curly braces expansion failed or
///           0 if something else is wrong.
int get_name_len(const char **const arg, char **alias, bool evaluate, bool verbose)
{
  *alias = NULL;    // default to no alias

  if ((*arg)[0] == (char)K_SPECIAL && (*arg)[1] == (char)KS_EXTRA
      && (*arg)[2] == (char)KE_SNR) {
    // Hard coded <SNR>, already translated.
    *arg += 3;
    return get_id_len(arg) + 3;
  }
  int len = eval_fname_script(*arg);
  if (len > 0) {
    // literal "<SID>", "s:" or "<SNR>"
    *arg += len;
  }

  // Find the end of the name; check for {} construction.
  char *expr_start;
  char *expr_end;
  const char *p = find_name_end((*arg), (const char **)&expr_start, (const char **)&expr_end,
                                len > 0 ? 0 : FNE_CHECK_START);
  if (expr_start != NULL) {
    if (!evaluate) {
      len += (int)(p - *arg);
      *arg = skipwhite(p);
      return len;
    }

    // Include any <SID> etc in the expanded string:
    // Thus the -len here.
    char *temp_string = make_expanded_name(*arg - len, expr_start, expr_end, (char *)p);
    if (temp_string == NULL) {
      return -1;
    }
    *alias = temp_string;
    *arg = skipwhite(p);
    return (int)strlen(temp_string);
  }

  len += get_id_len(arg);
  // Only give an error when there is something, otherwise it will be
  // reported at a higher level.
  if (len == 0 && verbose && **arg != NUL) {
    semsg(_(e_invexpr2), *arg);
  }

  return len;
}

/// Find the end of a variable or function name, taking care of magic braces.
///
/// @param expr_start  if not NULL, then `expr_start` and `expr_end` are set to the
///                    start and end of the first magic braces item.
///
/// @param flags  can have FNE_INCL_BR and FNE_CHECK_START.
///
/// @return  a pointer to just after the name.  Equal to "arg" if there is no
///          valid name.
const char *find_name_end(const char *arg, const char **expr_start, const char **expr_end,
                          int flags)
{
  if (expr_start != NULL) {
    *expr_start = NULL;
    *expr_end = NULL;
  }

  // Quick check for valid starting character.
  if ((flags & FNE_CHECK_START) && !eval_isnamec1(*arg) && *arg != '{') {
    return arg;
  }

  int mb_nest = 0;
  int br_nest = 0;
  int len;

  const char *p;
  for (p = arg; *p != NUL
       && (eval_isnamec(*p)
           || *p == '{'
           || ((flags & FNE_INCL_BR) && (*p == '['
                                         || (*p == '.' && eval_isdictc(p[1]))))
           || mb_nest != 0
           || br_nest != 0); MB_PTR_ADV(p)) {
    if (*p == '\'') {
      // skip over 'string' to avoid counting [ and ] inside it.
      for (p = p + 1; *p != NUL && *p != '\''; MB_PTR_ADV(p)) {}
      if (*p == NUL) {
        break;
      }
    } else if (*p == '"') {
      // skip over "str\"ing" to avoid counting [ and ] inside it.
      for (p = p + 1; *p != NUL && *p != '"'; MB_PTR_ADV(p)) {
        if (*p == '\\' && p[1] != NUL) {
          p++;
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
          || (len == 1 && vim_strchr(namespace_char, (uint8_t)(*arg)) == NULL)) {
        break;
      }
    }

    if (mb_nest == 0) {
      if (*p == '[') {
        br_nest++;
      } else if (*p == ']') {
        br_nest--;
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

/// Expands out the 'magic' {}'s in a variable/function name.
/// Note that this can call itself recursively, to deal with
/// constructs like foo{bar}{baz}{bam}
/// The four pointer arguments point to "foo{expre}ss{ion}bar"
///                      "in_start"      ^
///                      "expr_start"       ^
///                      "expr_end"               ^
///                      "in_end"                            ^
///
/// @return  a new allocated string, which the caller must free or
///          NULL for failure.
static char *make_expanded_name(const char *in_start, char *expr_start, char *expr_end,
                                char *in_end)
{
  if (expr_end == NULL || in_end == NULL) {
    return NULL;
  }

  char *retval = NULL;

  *expr_start = NUL;
  *expr_end = NUL;
  char c1 = *in_end;
  *in_end = NUL;

  char *temp_result = eval_to_string(expr_start + 1, false);
  if (temp_result != NULL) {
    retval = xmalloc(strlen(temp_result) + (size_t)(expr_start - in_start)
                     + (size_t)(in_end - expr_end) + 1);
    STRCPY(retval, in_start);
    STRCAT(retval, temp_result);
    STRCAT(retval, expr_end + 1);
  }
  xfree(temp_result);

  *in_end = c1;                 // put char back for error messages
  *expr_start = '{';
  *expr_end = '}';

  if (retval != NULL) {
    temp_result = (char *)find_name_end(retval,
                                        (const char **)&expr_start,
                                        (const char **)&expr_end, 0);
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

/// @return  true if character "c" can be used in a variable or function name.
///          Does not include '{' or '}' for magic braces.
bool eval_isnamec(int c)
{
  return ASCII_ISALNUM(c) || c == '_' || c == ':' || c == AUTOLOAD_CHAR;
}

/// @return  true if character "c" can be used as the first character in a
///          variable or function name (excluding '{' and '}').
bool eval_isnamec1(int c)
{
  return ASCII_ISALPHA(c) || c == '_';
}

/// @return  true if character "c" can be used as the first character of a
///          dictionary key.
bool eval_isdictc(int c)
{
  return ASCII_ISALNUM(c) || c == '_';
}

/// Get typval_T v: variable value.
typval_T *get_vim_var_tv(int idx)
{
  return &vimvars[idx].vv_tv;
}

/// Get number v: variable value.
varnumber_T get_vim_var_nr(int idx) FUNC_ATTR_PURE
{
  return vimvars[idx].vv_nr;
}

/// Get string v: variable value.  Uses a static buffer, can only be used once.
/// If the String variable has never been set, return an empty string.
/// Never returns NULL.
char *get_vim_var_str(int idx)
  FUNC_ATTR_PURE FUNC_ATTR_NONNULL_RET
{
  return (char *)tv_get_string(&vimvars[idx].vv_tv);
}

/// Get List v: variable value.  Caller must take care of reference count when
/// needed.
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

/// Set v:char to character "c".
void set_vim_var_char(int c)
{
  char buf[MB_MAXCHAR + 1];

  buf[utf_char2bytes(c, buf)] = NUL;
  set_vim_var_string(VV_CHAR, buf, -1);
}

/// Set v:count to "count" and v:count1 to "count1".
///
/// @param set_prevcount  if true, first set v:prevcount from v:count.
void set_vcount(int64_t count, int64_t count1, bool set_prevcount)
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
    vimvars[idx].vv_str = xstrdup(val);
  } else {
    vimvars[idx].vv_str = xstrndup(val, (size_t)len);
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
  if (val == NULL) {
    return;
  }

  val->dv_refcount++;
  // Set readonly
  tv_dict_set_keys_readonly(val);
}

/// Set v:variable to tv.
///
/// @param[in]  idx  Index of variable to set.
/// @param[in]  val  Value to set to. Will be copied.
void set_vim_var_tv(const VimVarIndex idx, typval_T *const tv)
{
  tv_clear(&vimvars[idx].vv_di.di_tv);
  tv_copy(tv, &vimvars[idx].vv_di.di_tv);
}

/// Set the v:argv list.
void set_argv_var(char **argv, int argc)
{
  list_T *l = tv_list_alloc(argc);

  tv_list_set_lock(l, VAR_FIXED);
  for (int i = 0; i < argc; i++) {
    tv_list_append_string(l, (const char *const)argv[i], -1);
    TV_LIST_ITEM_TV(tv_list_last(l))->v_lock = VAR_FIXED;
  }
  set_vim_var_list(VV_ARGV, l);
}

/// Set v:register if needed.
void set_reg_var(int c)
{
  char regname;

  if (c == 0 || c == ' ') {
    regname = '"';
  } else {
    regname = (char)c;
  }
  // Avoid free/alloc when the value is already right.
  if (vimvars[VV_REG].vv_str == NULL || vimvars[VV_REG].vv_str[0] != c) {
    set_vim_var_string(VV_REG, &regname, 1);
  }
}

/// Get or set v:exception.  If "oldval" == NULL, return the current value.
/// Otherwise, restore the value to "oldval" and return NULL.
/// Must always be called in pairs to save and restore v:exception!  Does not
/// take care of memory allocations.
char *v_exception(char *oldval)
{
  if (oldval == NULL) {
    return vimvars[VV_EXCEPTION].vv_str;
  }

  vimvars[VV_EXCEPTION].vv_str = oldval;
  return NULL;
}

/// Get or set v:throwpoint.  If "oldval" == NULL, return the current value.
/// Otherwise, restore the value to "oldval" and return NULL.
/// Must always be called in pairs to save and restore v:throwpoint!  Does not
/// take care of memory allocations.
char *v_throwpoint(char *oldval)
{
  if (oldval == NULL) {
    return vimvars[VV_THROWPOINT].vv_str;
  }

  vimvars[VV_THROWPOINT].vv_str = oldval;
  return NULL;
}

/// Set v:cmdarg.
/// If "eap" != NULL, use "eap" to generate the value and return the old value.
/// If "oldarg" != NULL, restore the value to "oldarg" and return NULL.
/// Must always be called in pairs!
char *set_cmdarg(exarg_T *eap, char *oldarg)
{
  char *oldval = vimvars[VV_CMDARG].vv_str;
  if (eap == NULL) {
    goto error;
  }

  size_t len = 0;
  if (eap->force_bin == FORCE_BIN) {
    len += 6;  // " ++bin"
  } else if (eap->force_bin == FORCE_NOBIN) {
    len += 8;  // " ++nobin"
  }

  if (eap->read_edit) {
    len += 7;  // " ++edit"
  }

  if (eap->force_ff != 0) {
    len += 10;  // " ++ff=unix"
  }
  if (eap->force_enc != 0) {
    len += strlen(eap->cmd + eap->force_enc) + 7;
  }
  if (eap->bad_char != 0) {
    len += 7 + 4;  // " ++bad=" + "keep" or "drop"
  }
  if (eap->mkdir_p != 0) {
    len += 4;  // " ++p"
  }

  const size_t newval_len = len + 1;
  char *newval = xmalloc(newval_len);
  size_t xlen = 0;
  int rc = 0;

  if (eap->force_bin == FORCE_BIN) {
    rc = snprintf(newval, newval_len, " ++bin");
  } else if (eap->force_bin == FORCE_NOBIN) {
    rc = snprintf(newval, newval_len, " ++nobin");
  } else {
    *newval = NUL;
  }
  if (rc < 0) {
    goto error;
  }
  xlen += (size_t)rc;

  if (eap->read_edit) {
    rc = snprintf(newval + xlen, newval_len - xlen, " ++edit");
    if (rc < 0) {
      goto error;
    }
    xlen += (size_t)rc;
  }

  if (eap->force_ff != 0) {
    rc = snprintf(newval + xlen,
                  newval_len - xlen,
                  " ++ff=%s",
                  eap->force_ff == 'u' ? "unix"
                                       : eap->force_ff == 'd' ? "dos" : "mac");
    if (rc < 0) {
      goto error;
    }
    xlen += (size_t)rc;
  }
  if (eap->force_enc != 0) {
    rc = snprintf(newval + (xlen), newval_len - xlen, " ++enc=%s", eap->cmd + eap->force_enc);
    if (rc < 0) {
      goto error;
    }
    xlen += (size_t)rc;
  }

  if (eap->bad_char == BAD_KEEP) {
    rc = snprintf(newval + xlen, newval_len - xlen, " ++bad=keep");
    if (rc < 0) {
      goto error;
    }
    xlen += (size_t)rc;
  } else if (eap->bad_char == BAD_DROP) {
    rc = snprintf(newval + xlen, newval_len - xlen, " ++bad=drop");
    if (rc < 0) {
      goto error;
    }
    xlen += (size_t)rc;
  } else if (eap->bad_char != 0) {
    rc = snprintf(newval + xlen, newval_len - xlen, " ++bad=%c", eap->bad_char);
    if (rc < 0) {
      goto error;
    }
    xlen += (size_t)rc;
  }

  if (eap->mkdir_p != 0) {
    rc = snprintf(newval + xlen, newval_len - xlen, " ++p");
    if (rc < 0) {
      goto error;
    }
    xlen += (size_t)rc;
  }
  assert(xlen <= newval_len);

  vimvars[VV_CMDARG].vv_str = newval;
  return oldval;

error:
  xfree(oldval);
  vimvars[VV_CMDARG].vv_str = oldarg;
  return NULL;
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
  FUNC_ATTR_PURE
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
  while (ASCII_ISALNUM(*p) || *p == '_' || *p == '-' || *p == '.' || *p == '\'') {
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
  }
  return (int)(p - str);
}

/// Return the character "str[index]" where "index" is the character index,
/// including composing characters.
/// If "index" is out of range NULL is returned.
char *char_from_string(const char *str, varnumber_T index)
{
  varnumber_T nchar = index;

  if (str == NULL) {
    return NULL;
  }
  size_t slen = strlen(str);

  // do the same as for a list: a negative index counts from the end
  if (index < 0) {
    int clen = 0;

    for (size_t nbyte = 0; nbyte < slen; clen++) {
      nbyte += (size_t)utfc_ptr2len(str + nbyte);
    }
    nchar = clen + index;
    if (nchar < 0) {
      // unlike list: index out of range results in empty string
      return NULL;
    }
  }

  size_t nbyte = 0;
  for (; nchar > 0 && nbyte < slen; nchar--) {
    nbyte += (size_t)utfc_ptr2len(str + nbyte);
  }
  if (nbyte >= slen) {
    return NULL;
  }
  return xmemdupz(str + nbyte, (size_t)utfc_ptr2len(str + nbyte));
}

/// Get the byte index for character index "idx" in string "str" with length
/// "str_len".  Composing characters are included.
/// If going over the end return "str_len".
/// If "idx" is negative count from the end, -1 is the last character.
/// When going over the start return -1.
static ssize_t char_idx2byte(const char *str, size_t str_len, varnumber_T idx)
{
  varnumber_T nchar = idx;
  size_t nbyte = 0;

  if (nchar >= 0) {
    while (nchar > 0 && nbyte < str_len) {
      nbyte += (size_t)utfc_ptr2len(str + nbyte);
      nchar--;
    }
  } else {
    nbyte = str_len;
    while (nchar < 0 && nbyte > 0) {
      nbyte--;
      nbyte -= (size_t)utf_head_off(str, str + nbyte);
      nchar++;
    }
    if (nchar < 0) {
      return -1;
    }
  }
  return (ssize_t)nbyte;
}

/// Return the slice "str[first : last]" using character indexes.  Composing
/// characters are included.
///
/// @param exclusive  true for slice().
///
/// Return NULL when the result is empty.
char *string_slice(const char *str, varnumber_T first, varnumber_T last, bool exclusive)
{
  if (str == NULL) {
    return NULL;
  }
  size_t slen = strlen(str);
  ssize_t start_byte = char_idx2byte(str, slen, first);
  if (start_byte < 0) {
    start_byte = 0;  // first index very negative: use zero
  }
  ssize_t end_byte;
  if ((last == -1 && !exclusive) || last == VARNUMBER_MAX) {
    end_byte = (ssize_t)slen;
  } else {
    end_byte = char_idx2byte(str, slen, last);
    if (!exclusive && end_byte >= 0 && end_byte < (ssize_t)slen) {
      // end index is inclusive
      end_byte += utfc_ptr2len(str + end_byte);
    }
  }

  if (start_byte >= (ssize_t)slen || end_byte <= start_byte) {
    return NULL;
  }
  return xmemdupz(str + start_byte, (size_t)(end_byte - start_byte));
}

/// Handle:
/// - expr[expr], expr[expr:expr] subscript
/// - ".name" lookup
/// - function call with Funcref variable: func(expr)
/// - method call: var->method()
///
/// Can all be combined in any order: dict.func(expr)[idx]['func'](expr)->len()
///
/// @param verbose  give error messages
/// @param start_leader  start of '!' and '-' prefixes
/// @param end_leaderp  end of '!' and '-' prefixes
int handle_subscript(const char **const arg, typval_T *rettv, evalarg_T *const evalarg,
                     bool verbose)
{
  const bool evaluate = evalarg != NULL && (evalarg->eval_flags & EVAL_EVALUATE);
  int ret = OK;
  dict_T *selfdict = NULL;
  const char *lua_funcname = NULL;

  if (tv_is_luafunc(rettv)) {
    if (!evaluate) {
      tv_clear(rettv);
    }

    if (**arg != '.') {
      tv_clear(rettv);
      ret = FAIL;
    } else {
      (*arg)++;

      lua_funcname = *arg;
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
      ret = call_func_rettv((char **)arg, evalarg, rettv, evaluate, selfdict, NULL, lua_funcname);

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
      if ((*arg)[2] == '{') {
        // expr->{lambda}()
        ret = eval_lambda((char **)arg, rettv, evalarg, verbose);
      } else {
        // expr->name()
        ret = eval_method((char **)arg, rettv, evalarg, verbose);
      }
    } else {  // **arg == '[' || **arg == '.'
      tv_dict_unref(selfdict);
      if (rettv->v_type == VAR_DICT) {
        selfdict = rettv->vval.v_dict;
        if (selfdict != NULL) {
          selfdict->dv_refcount++;
        }
      } else {
        selfdict = NULL;
      }
      if (eval_index((char **)arg, rettv, evalarg, verbose) == FAIL) {
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

/// Find variable "name" in the list of variables.
/// Careful: "a:0" variables don't have a name.
/// When "htp" is not NULL we are writing to the variable, set "htp" to the
/// hashtab_T used.
///
/// @return  a pointer to it if found, NULL if not found.
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

  hashitem_T *hi = hash_find_len(ht, varname, varname_len);
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
/// Assigns SID if s: scope is accessed from Lua or anonymous Vimscript. #15994
///
/// @param[in]  name  Variable name, possibly with scope prefix.
/// @param[in]  name_len  Variable name length.
/// @param[out]  varname  Will be set to the start of the name without scope
///                       prefix.
/// @param[out]  d  Scope dictionary.
///
/// @return Scope hashtab, NULL if name is not valid.
hashtab_T *find_var_ht_dict(const char *name, const size_t name_len, const char **varname,
                            dict_T **d)
{
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
    hashitem_T *hi = hash_find_len(&compat_hashtab, name, name_len);
    if (!HASHITEM_EMPTY(hi)) {
      return &compat_hashtab;
    }

    if (funccal == NULL) {  // global variable
      *d = &globvardict;
    } else {  // l: variable
      *d = &funccal->fc_l_vars;
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
    *d = &funccal->fc_l_avars;
  } else if (*name == 'l' && funccal != NULL) {  // local variable
    *d = &funccal->fc_l_vars;
  } else if (*name == 's'  // script variable
             && (current_sctx.sc_sid > 0 || current_sctx.sc_sid == SID_STR
                 || current_sctx.sc_sid == SID_LUA)
             && current_sctx.sc_sid <= script_items.ga_len) {
    // For anonymous scripts without a script item, create one now so script vars can be used
    if (current_sctx.sc_sid == SID_LUA) {
      // try to resolve lua filename & line no so it can be shown in lastset messages.
      nlua_set_sctx(&current_sctx);
      if (current_sctx.sc_sid != SID_LUA) {
        // Great we have valid location. Now here this out we'll create a new
        // script context with the name and lineno of this one. why ?
        // for behavioral consistency. With this different anonymous exec from
        // same file can't access each others script local stuff. We need to do
        // this all other cases except this will act like that otherwise.
        const LastSet last_set = (LastSet){
          .script_ctx = current_sctx,
          .channel_id = LUA_INTERNAL_CALL,
        };
        bool should_free;
        // should_free is ignored as script_sctx will be resolved to a fnmae
        // & new_script_item will consume it.
        char *sc_name = get_scriptname(last_set, &should_free);
        new_script_item(sc_name, &current_sctx.sc_sid);
      }
    }
    if (current_sctx.sc_sid == SID_STR || current_sctx.sc_sid == SID_LUA) {
      // Create SID if s: scope is accessed from Lua or anon Vimscript. #15994
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

/// Allocate a new hashtab for a sourced script.  It will be used while
/// sourcing this script and when executing functions defined in the script.
void new_script_vars(scid_T id)
{
  scriptvar_T *sv = xcalloc(1, sizeof(scriptvar_T));
  init_var_dict(&sv->sv_dict, &sv->sv_var, VAR_SCOPE);
  SCRIPT_ITEM(id)->sn_vars = sv;
}

/// Initialize dictionary "dict" as a scope and set variable "dict_var" to
/// point to it.
void init_var_dict(dict_T *dict, ScopeDictDictItem *dict_var, ScopeType scope)
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

/// Unreference a dictionary initialized by init_var_dict().
void unref_var_dict(dict_T *dict)
{
  // Now the dict needs to be freed if no one else is using it, go back to
  // normal reference counting.
  dict->dv_refcount -= DO_NOT_FREE_CNT - 1;
  tv_dict_unref(dict);
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
    emsg(_(e_variable_nested_too_deep_for_making_copy));
    return FAIL;
  }
  recurse++;

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
        to->vval.v_string = xstrdup(from->vval.v_string);
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
    tv_blob_copy(from->vval.v_blob, to);
    break;
  case VAR_DICT:
    to->v_type = VAR_DICT;
    to->v_lock = VAR_UNLOCKED;
    if (from->vval.v_dict == NULL) {
      to->vval.v_dict = NULL;
    } else if (copyID != 0 && from->vval.v_dict->dv_copyID == copyID) {
      // use the copy made earlier
      to->vval.v_dict = from->vval.v_dict->dv_copydict;
      to->vval.v_dict->dv_refcount++;
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
  recurse--;
  return ret;
}

/// ":echo expr1 ..."    print each argument separated with a space, add a
///                      newline at the end.
/// ":echon expr1 ..."   print each argument plain.
void ex_echo(exarg_T *eap)
{
  char *arg = eap->arg;
  typval_T rettv;
  bool atstart = true;
  bool need_clear = true;
  const int did_emsg_before = did_emsg;
  const int called_emsg_before = called_emsg;
  evalarg_T evalarg;

  fill_evalarg_from_eap(&evalarg, eap, eap->skip);

  if (eap->skip) {
    emsg_skip++;
  }
  while (*arg != NUL && *arg != '|' && *arg != '\n' && !got_int) {
    // If eval1() causes an error message the text from the command may
    // still need to be cleared. E.g., "echo 22,44".
    need_clr_eos = true;

    {
      char *p = arg;
      if (eval1(&arg, &rettv, &evalarg) == FAIL) {
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
          if (!msg_didout) {
            // Mark the saved text as finishing the line, so that what
            // follows is displayed on a new line when scrolling back
            // at the more prompt.
            msg_sb_eol();
          }
          msg_start();
        }
      } else if (eap->cmdidx == CMD_echo) {
        msg_puts_attr(" ", echo_attr);
      }
      char *tofree = encode_tv2echo(&rettv, NULL);
      if (*tofree != NUL) {
        msg_ext_set_kind("echo");
        msg_multiline(tofree, echo_attr, true, &need_clear);
      }
      xfree(tofree);
    }
    tv_clear(&rettv);
    arg = skipwhite(arg);
  }
  eap->nextcmd = check_nextcmd(arg);
  clear_evalarg(&evalarg, eap);

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

/// ":echohl {name}".
void ex_echohl(exarg_T *eap)
{
  echo_attr = syn_name2attr(eap->arg);
}

/// ":execute expr1 ..." execute the result of an expression.
/// ":echomsg expr1 ..." Print a message
/// ":echoerr expr1 ..." Print an error
/// Each gets spaces around each argument and a newline at the end for
/// echo commands
void ex_execute(exarg_T *eap)
{
  char *arg = eap->arg;
  typval_T rettv;
  int ret = OK;
  garray_T ga;

  ga_init(&ga, 1, 80);

  if (eap->skip) {
    emsg_skip++;
  }
  while (*arg != NUL && *arg != '|' && *arg != '\n') {
    ret = eval1_emsg(&arg, &rettv, eap);
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
      ga_grow(&ga, (int)len + 2);
      if (!GA_EMPTY(&ga)) {
        ((char *)(ga.ga_data))[ga.ga_len++] = ' ';
      }
      memcpy((char *)(ga.ga_data) + ga.ga_len, argstr, len + 1);
      if (eap->cmdidx != CMD_execute) {
        xfree((void *)argstr);
      }
      ga.ga_len += (int)len;
    }

    tv_clear(&rettv);
    arg = skipwhite(arg);
  }

  if (ret != FAIL && ga.ga_data != NULL) {
    if (eap->cmdidx == CMD_echomsg) {
      msg_ext_set_kind("echomsg");
      msg(ga.ga_data, echo_attr);
    } else if (eap->cmdidx == CMD_echoerr) {
      // We don't want to abort following commands, restore did_emsg.
      int save_did_emsg = did_emsg;
      msg_ext_set_kind("echoerr");
      emsg_multiline(ga.ga_data, true);
      if (!force_abort) {
        did_emsg = save_did_emsg;
      }
    } else if (eap->cmdidx == CMD_execute) {
      do_cmdline(ga.ga_data, eap->ea_getline, eap->cookie, DOCMD_NOWAIT|DOCMD_VERBOSE);
    }
  }

  ga_clear(&ga);

  if (eap->skip) {
    emsg_skip--;
  }

  eap->nextcmd = check_nextcmd(arg);
}

/// Skip over the name of an option variable: "&option", "&g:option" or "&l:option".
///
/// @param[in,out]  arg       Points to the "&" or '+' when called, to "option" when returning.
/// @param[out]     opt_idxp  Set to option index in options[] table.
/// @param[out]     scope     Set to option scope.
///
/// @return NULL when no option name found. Otherwise pointer to the char after the option name.
const char *find_option_var_end(const char **const arg, OptIndex *const opt_idxp, int *const scope)
{
  const char *p = *arg;

  p++;
  if (*p == 'g' && p[1] == ':') {
    *scope = OPT_GLOBAL;
    p += 2;
  } else if (*p == 'l' && p[1] == ':') {
    *scope = OPT_LOCAL;
    p += 2;
  } else {
    *scope = 0;
  }

  const char *end = find_option_end(p, opt_idxp);
  *arg = end == NULL ? *arg : p;
  return end;
}

var_flavour_T var_flavour(char *varname)
  FUNC_ATTR_PURE
{
  char *p = varname;

  if (ASCII_ISUPPER(*p)) {
    while (*(++p)) {
      if (ASCII_ISLOWER(*p)) {
        return VAR_FLAVOUR_SESSION;
      }
    }
    return VAR_FLAVOUR_SHADA;
  }
  return VAR_FLAVOUR_DEFAULT;
}

void var_set_global(const char *const name, typval_T vartv)
{
  funccal_entry_T funccall_entry;

  save_funccal(&funccall_entry);
  set_var(name, strlen(name), &vartv, false);
  restore_funccal();
}

/// Display script name where an item was last set.
/// Should only be invoked when 'verbose' is non-zero.
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
  if (last_set.script_ctx.sc_sid == 0) {
    return;
  }

  bool should_free;
  char *p = get_scriptname(last_set, &should_free);

  verbose_enter();
  msg_puts(_("\n\tLast set from "));
  msg_puts(p);
  if (last_set.script_ctx.sc_lnum > 0) {
    msg_puts(_(line_msg));
    msg_outnum(last_set.script_ctx.sc_lnum);
  }
  if (should_free) {
    xfree(p);
  }
  verbose_leave();
}

// reset v:option_new, v:option_old, v:option_oldlocal, v:option_oldglobal,
// v:option_type, and v:option_command.
void reset_v_option_vars(void)
{
  set_vim_var_string(VV_OPTION_NEW, NULL, -1);
  set_vim_var_string(VV_OPTION_OLD, NULL, -1);
  set_vim_var_string(VV_OPTION_OLDLOCAL, NULL, -1);
  set_vim_var_string(VV_OPTION_OLDGLOBAL, NULL, -1);
  set_vim_var_string(VV_OPTION_COMMAND, NULL, -1);
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
int modify_fname(char *src, bool tilde_file, size_t *usedlen, char **fnamep, char **bufp,
                 size_t *fnamelen)
{
  int valid = 0;
  char *s, *p, *pbuf;
  char dirname[MAXPATHL];
  bool has_fullname = false;
  bool has_homerelative = false;

repeat:
  // ":p" - full path/file_name
  if (src[*usedlen] == ':' && src[*usedlen + 1] == 'p') {
    has_fullname = true;

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
      *fnamep = FullName_save(*fnamep, *p != NUL);
      xfree(*bufp);          // free any allocated file name
      *bufp = *fnamep;
      if (*fnamep == NULL) {
        return -1;
      }
    }

    // Append a path separator to a directory.
    if (os_isdir(*fnamep)) {
      // Make room for one or two extra characters.
      *fnamep = xstrnsave(*fnamep, strlen(*fnamep) + 2);
      xfree(*bufp);          // free any allocated file name
      *bufp = *fnamep;
      add_pathsep(*fnamep);
    }
  }

  int c;

  // ":." - path relative to the current directory
  // ":~" - path relative to the home directory
  // ":8" - shortname path - postponed till after
  while (src[*usedlen] == ':'
         && ((c = (uint8_t)src[*usedlen + 1]) == '.' || c == '~' || c == '8')) {
    *usedlen += 2;
    if (c == '8') {
      continue;
    }
    pbuf = NULL;
    // Need full path first (use expand_env() to remove a "~/")
    if (!has_fullname && !has_homerelative) {
      if (**fnamep == '~') {
        p = pbuf = expand_env_save(*fnamep);
      } else {
        p = pbuf = FullName_save(*fnamep, false);
      }
    } else {
      p = *fnamep;
    }

    has_fullname = false;

    if (p != NULL) {
      if (c == '.') {
        os_dirname(dirname, MAXPATHL);
        if (has_homerelative) {
          s = xstrdup(dirname);
          home_replace(NULL, s, dirname, MAXPATHL, true);
          xfree(s);
        }
        size_t namelen = strlen(dirname);

        // Do not call shorten_fname() here since it removes the prefix
        // even though the path does not have a prefix.
        if (path_fnamencmp(p, dirname, namelen) == 0) {
          p += namelen;
          if (vim_ispathsep(*p)) {
            while (*p && vim_ispathsep(*p)) {
              p++;
            }
            *fnamep = p;
            if (pbuf != NULL) {
              // free any allocated file name
              xfree(*bufp);
              *bufp = pbuf;
              pbuf = NULL;
            }
          }
        }
      } else {
        home_replace(NULL, p, dirname, MAXPATHL, true);
        // Only replace it when it starts with '~'
        if (*dirname == '~') {
          s = xstrdup(dirname);
          assert(s != NULL);  // suppress clang "Argument with 'nonnull' attribute passed null"
          *fnamep = s;
          xfree(*bufp);
          *bufp = s;
          has_homerelative = true;
        }
      }
      xfree(pbuf);
    }
  }

  char *tail = path_tail(*fnamep);
  *fnamelen = strlen(*fnamep);

  // ":h" - head, remove "/file_name", can be repeated
  // Don't remove the first "/" or "c:\"
  while (src[*usedlen] == ':' && src[*usedlen + 1] == 'h') {
    valid |= VALID_HEAD;
    *usedlen += 2;
    s = get_past_head(*fnamep);
    while (tail > s && after_pathsep(s, tail)) {
      MB_PTR_BACK(*fnamep, tail);
    }
    *fnamelen = (size_t)(tail - *fnamep);
    if (*fnamelen == 0) {
      // Result is empty.  Turn it into "." to make ":cd %:h" work.
      xfree(*bufp);
      *bufp = *fnamep = tail = xstrdup(".");
      *fnamelen = 1;
    } else {
      while (tail > s && !after_pathsep(s, tail)) {
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
    // find a '.' in the tail:
    // - for second :e: before the current fname
    // - otherwise: The last '.'
    const bool is_second_e = *fnamep > tail;
    if (src[*usedlen + 1] == 'e' && is_second_e) {
      s = (*fnamep) - 2;
    } else {
      s = (*fnamep) + *fnamelen - 1;
    }

    for (; s > tail; s--) {
      if (s[0] == '.') {
        break;
      }
    }
    if (src[*usedlen + 1] == 'e') {
      if (s > tail || (0 && is_second_e && s == tail)) {
        // we stopped at a '.' (so anchor to &'.' + 1)
        char *newstart = s + 1;
        size_t distance_stepped_back = (size_t)(*fnamep - newstart);
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
    bool didit = false;

    char *flags = "";
    s = src + *usedlen + 2;
    if (src[*usedlen + 1] == 'g') {
      flags = "g";
      s++;
    }

    int sep = (uint8_t)(*s++);
    if (sep) {
      // find end of pattern
      p = vim_strchr(s, sep);
      if (p != NULL) {
        char *const pat = xmemdupz(s, (size_t)(p - s));
        s = p + 1;
        // find end of substitution
        p = vim_strchr(s, sep);
        if (p != NULL) {
          char *const sub = xmemdupz(s, (size_t)(p - s));
          char *const str = xmemdupz(*fnamep, *fnamelen);
          *usedlen = (size_t)(p + 1 - src);
          s = do_string_sub(str, pat, sub, NULL, flags);
          *fnamep = s;
          *fnamelen = strlen(s);
          xfree(*bufp);
          *bufp = s;
          didit = true;
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
    c = (uint8_t)(*fnamep)[*fnamelen];
    if (c != NUL) {
      (*fnamep)[*fnamelen] = NUL;
    }
    p = vim_strsave_shellescape(*fnamep, false, false);
    if (c != NUL) {
      (*fnamep)[*fnamelen] = (char)c;
    }
    xfree(*bufp);
    *bufp = *fnamep = p;
    *fnamelen = strlen(p);
    *usedlen += 2;
  }

  return valid;
}

/// Perform a substitution on "str" with pattern "pat" and substitute "sub".
/// When "sub" is NULL "expr" is used, must be a VAR_FUNC or VAR_PARTIAL.
/// "flags" can be "g" to do a global substitute.
///
/// @return  an allocated string, NULL for error.
char *do_string_sub(char *str, char *pat, char *sub, typval_T *expr, const char *flags)
{
  regmatch_T regmatch;
  garray_T ga;
  char *zero_width = NULL;

  // Make 'cpoptions' empty, so that the 'l' flag doesn't work here
  char *save_cpo = p_cpo;
  p_cpo = empty_string_option;

  ga_init(&ga, 1, 200);

  int do_all = (flags[0] == 'g');

  regmatch.rm_ic = p_ic;
  regmatch.regprog = vim_regcomp(pat, RE_MAGIC + RE_STRING);
  if (regmatch.regprog != NULL) {
    int sublen;
    char *tail = str;
    char *end = str + strlen(str);
    while (vim_regexec_nl(&regmatch, str, (colnr_T)(tail - str))) {
      // Skip empty match except for first match.
      if (regmatch.startp[0] == regmatch.endp[0]) {
        if (zero_width == regmatch.startp[0]) {
          // avoid getting stuck on a match with an empty string
          int i = utfc_ptr2len(tail);
          memmove((char *)ga.ga_data + ga.ga_len, tail, (size_t)i);
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
      sublen = vim_regsub(&regmatch, sub, expr, tail, 0, REGSUB_MAGIC);
      if (sublen <= 0) {
        ga_clear(&ga);
        break;
      }
      ga_grow(&ga, (int)((end - tail) + sublen -
                         (regmatch.endp[0] - regmatch.startp[0])));

      // copy the text up to where the match is
      int i = (int)(regmatch.startp[0] - tail);
      memmove((char *)ga.ga_data + ga.ga_len, tail, (size_t)i);
      // add the substituted text
      vim_regsub(&regmatch, sub, expr,
                 (char *)ga.ga_data + ga.ga_len + i, sublen,
                 REGSUB_COPY | REGSUB_MAGIC);
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

  char *ret = xstrdup(ga.ga_data == NULL ? str : ga.ga_data);
  ga_clear(&ga);
  if (p_cpo == empty_string_option) {
    p_cpo = save_cpo;
  } else {
    // Darn, evaluating {sub} expression or {expr} changed the value.
    // If it's still empty it was changed and restored, need to restore in
    // the complicated way.
    if (*p_cpo == NUL) {
      set_option_value_give_err(kOptCpoptions, CSTR_AS_OPTVAL(save_cpo), 0);
    }
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
  tv_list_append_string(args, argvars[0].vval.v_string, -1);
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
      .vval.v_number = 0
    };
  }

  char func[256];
  int name_len = snprintf(func, sizeof(func), "provider#%s#Call", provider);

  // Save caller scope information
  struct caller_scope saved_provider_caller_scope = provider_caller_scope;
  provider_caller_scope = (struct caller_scope) {
    .script_ctx = current_sctx,
    .es_entry = ((estack_T *)exestack.ga_data)[exestack.ga_len - 1],
    .autocmd_fname = autocmd_fname,
    .autocmd_match = autocmd_match,
    .autocmd_fname_full = autocmd_fname_full,
    .autocmd_bufnr = autocmd_bufnr,
    .funccalp = (void *)get_current_funccal()
  };
  funccal_entry_T funccal_entry;
  save_funccal(&funccal_entry);
  provider_call_nesting++;

  typval_T argvars[3] = {
    { .v_type = VAR_STRING, .vval.v_string = method,
      .v_lock = VAR_UNLOCKED },
    { .v_type = VAR_LIST, .vval.v_list = arguments, .v_lock = VAR_UNLOCKED },
    { .v_type = VAR_UNKNOWN }
  };
  typval_T rettv = { .v_type = VAR_UNKNOWN, .v_lock = VAR_UNLOCKED };
  tv_list_ref(arguments);

  funcexe_T funcexe = FUNCEXE_INIT;
  funcexe.fe_firstline = curwin->w_cursor.lnum;
  funcexe.fe_lastline = curwin->w_cursor.lnum;
  funcexe.fe_evaluate = true;
  call_func(func, name_len, &rettv, 2, argvars, &funcexe);

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
      && !strequal(feat, "python3")
      && !strequal(feat, "python3_compiled")
      && !strequal(feat, "python3_dynamic")
      && !strequal(feat, "perl")
      && !strequal(feat, "ruby")
      && !strequal(feat, "node")) {
    // Avoid autoload for non-provider has() features.
    return false;
  }

  char name[32];  // Normalized: "python3_compiled" => "python3".
  snprintf(name, sizeof(name), "%s", feat);
  strchrsub(name, '_', '\0');  // Chop any "_xx" suffix.

  char buf[256];
  typval_T tv;
  // Get the g:loaded_xx_provider variable.
  int len = snprintf(buf, sizeof(buf), "g:loaded_%s_provider", name);
  if (eval_variable(buf, len, &tv, NULL, false, true) == FAIL) {
    // Trigger autoload once.
    len = snprintf(buf, sizeof(buf), "provider#%s#bogus", name);
    script_autoload(buf, (size_t)len, false);

    // Retry the (non-autoload-style) variable.
    len = snprintf(buf, sizeof(buf), "g:loaded_%s_provider", name);
    if (eval_variable(buf, len, &tv, NULL, false, true) == FAIL) {
      // Show a hint if Call() is defined but g:loaded_xx_provider is missing.
      snprintf(buf, sizeof(buf), "provider#%s#Call", name);
      if (!!find_func(buf) && p_lpl) {
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
    if (!find_func(buf)) {
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
  if (SOURCING_NAME) {
    snprintf(buf, bufsize, "%s:%" PRIdLINENR, SOURCING_NAME, SOURCING_LNUM);
  } else {
    snprintf(buf, bufsize, "?");
  }
}

void invoke_prompt_callback(void)
{
  typval_T rettv;
  typval_T argv[2];
  linenr_T lnum = curbuf->b_ml.ml_line_count;

  // Add a new line for the prompt before invoking the callback, so that
  // text can always be inserted above the last line.
  ml_append(lnum, "", 0, false);
  appended_lines_mark(lnum, 1);
  curwin->w_cursor.lnum = lnum + 1;
  curwin->w_cursor.col = 0;

  if (curbuf->b_prompt_callback.type == kCallbackNone) {
    return;
  }
  char *text = ml_get(lnum);
  char *prompt = prompt_text();
  if (strlen(text) >= strlen(prompt)) {
    text += strlen(prompt);
  }
  argv[0].v_type = VAR_STRING;
  argv[0].vval.v_string = xstrdup(text);
  argv[1].v_type = VAR_UNKNOWN;

  callback_call(&curbuf->b_prompt_callback, 1, argv, &rettv);
  tv_clear(&argv[0]);
  tv_clear(&rettv);
}

/// @return  true when the interrupt callback was invoked.
bool invoke_prompt_interrupt(void)
{
  typval_T rettv;
  typval_T argv[1];

  if (curbuf->b_prompt_interrupt.type == kCallbackNone) {
    return false;
  }
  argv[0].v_type = VAR_UNKNOWN;

  got_int = false;  // don't skip executing commands
  int ret = callback_call(&curbuf->b_prompt_interrupt, 0, argv, &rettv);
  tv_clear(&rettv);
  return ret != FAIL;
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
    // For "is" a different type always means false, for "isnot"
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
      // When both partials are NULL, then they are equal.
      // Otherwise they are not equal.
      n1 = (typ1->vval.v_partial == typ2->vval.v_partial);
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
      n1 = pattern_match(s2, s1, ic);
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

/// Convert any type to a string, never give an error.
/// When "quotes" is true add quotes to a string.
/// Returns an allocated string.
char *typval_tostring(typval_T *arg, bool quotes)
{
  if (arg == NULL) {
    return xstrdup("(does not exist)");
  }
  if (!quotes && arg->v_type == VAR_STRING) {
    return xstrdup(arg->vval.v_string == NULL ? "" : arg->vval.v_string);
  }
  return encode_tv2string(arg, NULL);
}
