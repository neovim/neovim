// User defined function support

#include <assert.h>
#include <ctype.h>
#include <inttypes.h>
#include <lauxlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/debugger.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/encode.h"
#include "nvim/eval/funcs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/userfunc.h"
#include "nvim/eval/vars.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_eval_defs.h"
#include "nvim/ex_getln.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/getchar_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/hashtab.h"
#include "nvim/insexpand.h"
#include "nvim/keycodes.h"
#include "nvim/lua/executor.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option_vars.h"
#include "nvim/os/input.h"
#include "nvim/path.h"
#include "nvim/profile.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/runtime.h"
#include "nvim/search.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/vim_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/userfunc.c.generated.h"
#endif

/// structure used as item in "fc_defer"
typedef struct {
  char *dr_name;  ///< function name, allocated
  typval_T dr_argvars[MAX_FUNC_ARGS + 1];
  int dr_argcount;
} defer_T;

static hashtab_T func_hashtab;

// Used by get_func_tv()
static garray_T funcargs = GA_EMPTY_INIT_VALUE;

// pointer to funccal for currently active function
static funccall_T *current_funccal = NULL;

// Pointer to list of previously used funccal, still around because some
// item in it is still being used.
static funccall_T *previous_funccal = NULL;

static const char *e_funcexts = N_("E122: Function %s already exists, add ! to replace it");
static const char *e_funcdict = N_("E717: Dictionary entry already exists");
static const char *e_funcref = N_("E718: Funcref required");
static const char *e_nofunc = N_("E130: Unknown function: %s");
static const char e_function_list_was_modified[]
  = N_("E454: Function list was modified");
static const char e_function_nesting_too_deep[]
  = N_("E1058: Function nesting too deep");
static const char e_no_white_space_allowed_before_str_str[]
  = N_("E1068: No white space allowed before '%s': %s");
static const char e_missing_heredoc_end_marker_str[]
  = N_("E1145: Missing heredoc end marker: %s");
static const char e_cannot_use_partial_with_dictionary_for_defer[]
  = N_("E1300: Cannot use a partial with dictionary for :defer");

void func_init(void)
{
  hash_init(&func_hashtab);
}

/// Return the function hash table
hashtab_T *func_tbl_get(void)
{
  return &func_hashtab;
}

/// Get one function argument.
/// Return a pointer to after the type.
/// When something is wrong return "arg".
static char *one_function_arg(char *arg, garray_T *newargs, bool skip)
{
  char *p = arg;

  while (ASCII_ISALNUM(*p) || *p == '_') {
    p++;
  }
  if (arg == p || isdigit((uint8_t)(*arg))
      || (p - arg == 9 && strncmp(arg, "firstline", 9) == 0)
      || (p - arg == 8 && strncmp(arg, "lastline", 8) == 0)) {
    if (!skip) {
      semsg(_("E125: Illegal argument: %s"), arg);
    }
    return arg;
  }

  if (newargs != NULL) {
    ga_grow(newargs, 1);
    uint8_t c = (uint8_t)(*p);
    *p = NUL;
    char *arg_copy = xstrdup(arg);

    // Check for duplicate argument name.
    for (int i = 0; i < newargs->ga_len; i++) {
      if (strcmp(((char **)(newargs->ga_data))[i], arg_copy) == 0) {
        semsg(_("E853: Duplicate argument name: %s"), arg_copy);
        xfree(arg_copy);
        return arg;
      }
    }
    ((char **)(newargs->ga_data))[newargs->ga_len] = arg_copy;
    newargs->ga_len++;

    *p = (char)c;
  }

  return p;
}

/// Get function arguments.
static int get_function_args(char **argp, char endchar, garray_T *newargs, int *varargs,
                             garray_T *default_args, bool skip)
{
  bool mustend = false;
  char *arg = *argp;
  char *p = arg;

  if (newargs != NULL) {
    ga_init(newargs, (int)sizeof(char *), 3);
  }
  if (default_args != NULL) {
    ga_init(default_args, (int)sizeof(char *), 3);
  }

  if (varargs != NULL) {
    *varargs = false;
  }

  // Isolate the arguments: "arg1, arg2, ...)"
  bool any_default = false;
  while (*p != endchar) {
    if (p[0] == '.' && p[1] == '.' && p[2] == '.') {
      if (varargs != NULL) {
        *varargs = true;
      }
      p += 3;
      mustend = true;
    } else {
      arg = p;
      p = one_function_arg(p, newargs, skip);
      if (p == arg) {
        break;
      }

      if (*skipwhite(p) == '=' && default_args != NULL) {
        typval_T rettv;

        any_default = true;
        p = skipwhite(p) + 1;
        p = skipwhite(p);
        char *expr = p;
        if (eval1(&p, &rettv, NULL) != FAIL) {
          ga_grow(default_args, 1);

          // trim trailing whitespace
          while (p > expr && ascii_iswhite(p[-1])) {
            p--;
          }
          uint8_t c = (uint8_t)(*p);
          *p = NUL;
          expr = xstrdup(expr);
          ((char **)(default_args->ga_data))[default_args->ga_len] = expr;
          default_args->ga_len++;
          *p = (char)c;
        } else {
          mustend = true;
        }
      } else if (any_default) {
        emsg(_("E989: Non-default argument follows default argument"));
        mustend = true;
      }

      if (ascii_iswhite(*p) && *skipwhite(p) == ',') {
        // Be tolerant when skipping
        if (!skip) {
          semsg(_(e_no_white_space_allowed_before_str_str), ",", p);
          goto err_ret;
        }
        p = skipwhite(p);
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
        semsg(_(e_invarg2), *argp);
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
  if (default_args != NULL) {
    ga_clear_strings(default_args);
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
  ga_grow(&current_funccal->fc_ufuncs, 1);
  ((ufunc_T **)current_funccal->fc_ufuncs.ga_data)
  [current_funccal->fc_ufuncs.ga_len++] = fp;
}

static char lambda_name[8 + NUMBUFLEN];
static size_t lambda_namelen = 0;

/// @return  a name for a lambda.  Returned in static memory.
char *get_lambda_name(void)
{
  static int lambda_no = 0;

  int n = snprintf(lambda_name, sizeof(lambda_name), "<lambda>%d", ++lambda_no);
  if (n < 1) {
    lambda_namelen = 0;
  } else if (n >= (int)sizeof(lambda_name)) {
    lambda_namelen = sizeof(lambda_name) - 1;
  } else {
    lambda_namelen = (size_t)n;
  }

  return lambda_name;
}

/// Get the length of the last lambda name.
size_t get_lambda_name_len(void)
{
  return lambda_namelen;
}

/// Allocate a "ufunc_T" for a function called "name".
static ufunc_T *alloc_ufunc(const char *name, size_t namelen)
{
  size_t len = offsetof(ufunc_T, uf_name) + namelen + 1;
  ufunc_T *fp = xcalloc(1, len);
  STRCPY(fp->uf_name, name);
  fp->uf_namelen = namelen;

  if ((uint8_t)name[0] == K_SPECIAL) {
    len = namelen + 3;
    fp->uf_name_exp = xmalloc(len);
    snprintf(fp->uf_name_exp, len, "<SNR>%s", fp->uf_name + 3);
  }

  return fp;
}

/// Parse a lambda expression and get a Funcref from "*arg".
///
/// @return OK or FAIL.  Returns NOTDONE for dict or {expr}.
int get_lambda_tv(char **arg, typval_T *rettv, evalarg_T *evalarg)
{
  const bool evaluate = evalarg != NULL && (evalarg->eval_flags & EVAL_EVALUATE);
  garray_T newargs = GA_EMPTY_INIT_VALUE;
  garray_T *pnewargs;
  ufunc_T *fp = NULL;
  partial_T *pt = NULL;
  int varargs;
  bool *old_eval_lavars = eval_lavars_used;
  bool eval_lavars = false;
  char *tofree = NULL;

  // First, check if this is a lambda expression. "->" must exists.
  char *s = skipwhite(*arg + 1);
  int ret = get_function_args(&s, '-', NULL, NULL, NULL, true);
  if (ret == FAIL || *s != '>') {
    return NOTDONE;
  }

  // Parse the arguments again.
  if (evaluate) {
    pnewargs = &newargs;
  } else {
    pnewargs = NULL;
  }
  *arg = skipwhite(*arg + 1);
  ret = get_function_args(arg, '-', pnewargs, &varargs, NULL, false);
  if (ret == FAIL || **arg != '>') {
    goto errret;
  }

  // Set up a flag for checking local variables and arguments.
  if (evaluate) {
    eval_lavars_used = &eval_lavars;
  }

  // Get the start and the end of the expression.
  *arg = skipwhite((*arg) + 1);
  char *start = *arg;
  ret = skip_expr(arg, evalarg);
  char *end = *arg;
  if (ret == FAIL) {
    goto errret;
  }
  if (evalarg != NULL) {
    // avoid that the expression gets freed when another line break follows
    tofree = evalarg->eval_tofree;
    evalarg->eval_tofree = NULL;
  }

  *arg = skipwhite(*arg);
  if (**arg != '}') {
    semsg(_("E451: Expected }: %s"), *arg);
    goto errret;
  }
  (*arg)++;

  if (evaluate) {
    int flags = 0;
    garray_T newlines;

    char *name = get_lambda_name();
    size_t namelen = get_lambda_name_len();

    fp = alloc_ufunc(name, namelen);
    pt = xcalloc(1, sizeof(partial_T));

    ga_init(&newlines, (int)sizeof(char *), 1);
    ga_grow(&newlines, 1);

    // Add "return " before the expression.
    size_t len = (size_t)(7 + end - start + 1);
    char *p = xmalloc(len);
    ((char **)(newlines.ga_data))[newlines.ga_len++] = p;
    STRCPY(p, "return ");
    xmemcpyz(p + 7, start, (size_t)(end - start));
    if (strstr(p + 7, "a:") == NULL) {
      // No a: variables are used for sure.
      flags |= FC_NOARGS;
    }

    fp->uf_refcount = 1;
    hash_add(&func_hashtab, UF2HIKEY(fp));
    fp->uf_args = newargs;
    ga_init(&fp->uf_def_args, (int)sizeof(char *), 1);
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
    fp->uf_script_ctx.sc_lnum += SOURCING_LNUM - newlines.ga_len;

    pt->pt_func = fp;
    pt->pt_refcount = 1;
    rettv->vval.v_partial = pt;
    rettv->v_type = VAR_PARTIAL;
  }

  eval_lavars_used = old_eval_lavars;
  if (evalarg != NULL && evalarg->eval_tofree == NULL) {
    evalarg->eval_tofree = tofree;
  } else {
    xfree(tofree);
  }
  return OK;

errret:
  ga_clear_strings(&newargs);
  if (fp != NULL) {
    xfree(fp->uf_name_exp);
    xfree(fp);
  }
  xfree(pt);
  if (evalarg != NULL && evalarg->eval_tofree == NULL) {
    evalarg->eval_tofree = tofree;
  } else {
    xfree(tofree);
  }
  eval_lavars_used = old_eval_lavars;
  return FAIL;
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
/// @param[out]  found_var  If not NULL and a variable was found set it to true.
///
/// @return name of the function.
char *deref_func_name(const char *name, int *lenp, partial_T **const partialp, bool no_autoload,
                      bool *found_var)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  if (partialp != NULL) {
    *partialp = NULL;
  }

  dictitem_T *const v = find_var(name, (size_t)(*lenp), NULL, no_autoload);
  if (v == NULL) {
    return (char *)name;
  }
  typval_T *const tv = &v->di_tv;
  if (found_var != NULL) {
    *found_var = true;
  }

  if (tv->v_type == VAR_FUNC) {
    if (tv->vval.v_string == NULL) {  // just in case
      *lenp = 0;
      return "";
    }
    *lenp = (int)strlen(tv->vval.v_string);
    return tv->vval.v_string;
  }

  if (tv->v_type == VAR_PARTIAL) {
    partial_T *const pt = tv->vval.v_partial;
    if (pt == NULL) {  // just in case
      *lenp = 0;
      return "";
    }
    if (partialp != NULL) {
      *partialp = pt;
    }
    char *s = partial_name(pt);
    *lenp = (int)strlen(s);
    return s;
  }

  return (char *)name;
}

/// Give an error message with a function name.  Handle <SNR> things.
///
/// @param errmsg must be passed without translation (use N_() instead of _()).
/// @param name function name
void emsg_funcname(const char *errmsg, const char *name)
{
  char *p = (char *)name;

  if ((uint8_t)name[0] == K_SPECIAL && name[1] != NUL && name[2] != NUL) {
    p = concat_str("<SNR>", name + 3);
  }

  semsg(_(errmsg), p);

  if (p != name) {
    xfree(p);
  }
}

/// Get function arguments at "*arg" and advance it.
/// Return them in "*argvars[MAX_FUNC_ARGS + 1]" and the count in "argcount".
/// On failure FAIL is returned but the "argvars[argcount]" are still set.
static int get_func_arguments(char **arg, evalarg_T *const evalarg, int partial_argc,
                              typval_T *argvars, int *argcount)
{
  char *argp = *arg;
  int ret = OK;

  // Get the arguments.
  while (*argcount < MAX_FUNC_ARGS - partial_argc) {
    argp = skipwhite(argp + 1);             // skip the '(' or ','

    if (*argp == ')' || *argp == ',' || *argp == NUL) {
      break;
    }
    if (eval1(&argp, &argvars[*argcount], evalarg) == FAIL) {
      ret = FAIL;
      break;
    }
    (*argcount)++;
    if (*argp != ',') {
      break;
    }
  }

  argp = skipwhite(argp);
  if (*argp == ')') {
    argp++;
  } else {
    ret = FAIL;
  }
  *arg = argp;
  return ret;
}

/// Call a function and put the result in "rettv".
///
/// @param name  name of the function
/// @param len  length of "name" or -1 to use strlen()
/// @param arg  argument, pointing to the '('
/// @param funcexe  various values
///
/// @return  OK or FAIL.
int get_func_tv(const char *name, int len, typval_T *rettv, char **arg, evalarg_T *const evalarg,
                funcexe_T *funcexe)
{
  typval_T argvars[MAX_FUNC_ARGS + 1];          // vars for arguments
  int argcount = 0;                     // number of arguments found
  const bool evaluate = evalarg == NULL ? false : (evalarg->eval_flags & EVAL_EVALUATE);

  char *argp = *arg;
  int ret = get_func_arguments(&argp, evalarg,
                               (funcexe->fe_partial == NULL
                                ? 0
                                : funcexe->fe_partial->pt_argc),
                               argvars, &argcount);

  assert(ret == OK || ret == FAIL);  // suppress clang false positive
  if (ret == OK) {
    int i = 0;

    if (get_vim_var_nr(VV_TESTING)) {
      // Prepare for calling test_garbagecollect_now(), need to know
      // what variables are used on the call stack.
      if (funcargs.ga_itemsize == 0) {
        ga_init(&funcargs, (int)sizeof(typval_T *), 50);
      }
      for (i = 0; i < argcount; i++) {
        ga_grow(&funcargs, 1);
        ((typval_T **)funcargs.ga_data)[funcargs.ga_len++] = &argvars[i];
      }
    }
    ret = call_func(name, len, rettv, argcount, argvars, funcexe);

    funcargs.ga_len -= i;
  } else if (!aborting() && evaluate) {
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

#define FLEN_FIXED 40

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
static char *fname_trans_sid(const char *const name, char *const fname_buf, char **const tofree,
                             int *const error)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const char *script_name = name + eval_fname_script(name);
  if (script_name == name) {
    return (char *)name;  // no prefix
  }

  fname_buf[0] = (char)K_SPECIAL;
  fname_buf[1] = (char)KS_EXTRA;
  fname_buf[2] = KE_SNR;
  size_t fname_buflen = 3;
  if (!eval_fname_sid(name)) {  // "<SID>" or "s:"
    fname_buf[fname_buflen] = NUL;
  } else {
    if (current_sctx.sc_sid <= 0) {
      *error = FCERR_SCRIPT;
    } else {
      fname_buflen += (size_t)snprintf(fname_buf + fname_buflen,
                                       FLEN_FIXED + 1 - fname_buflen,
                                       "%" PRIdSCID "_",
                                       current_sctx.sc_sid);
    }
  }
  size_t fnamelen = fname_buflen + strlen(script_name);
  char *fname;
  if (fnamelen < FLEN_FIXED) {
    STRCPY(fname_buf + fname_buflen, script_name);
    fname = fname_buf;
  } else {
    fname = xmalloc(fnamelen + 1);
    *tofree = fname;
    snprintf(fname, fnamelen + 1, "%s%s", fname_buf, script_name);
  }
  return fname;
}

int get_func_arity(const char *name, int *required, int *optional, bool *varargs)
{
  int argcount = 0;
  int min_argcount = 0;

  const EvalFuncDef *fdef = find_internal_func(name);
  if (fdef != NULL) {
    argcount = fdef->max_argc;
    min_argcount = fdef->min_argc;
    *varargs = false;
  } else {
    char fname_buf[FLEN_FIXED + 1];
    char *tofree = NULL;
    int error = FCERR_NONE;

    // May need to translate <SNR>123_ to K_SNR.
    char *fname = fname_trans_sid(name, fname_buf, &tofree, &error);
    ufunc_T *ufunc = NULL;
    if (error == FCERR_NONE) {
      ufunc = find_func(fname);
    }
    xfree(tofree);

    if (ufunc == NULL) {
      return FAIL;
    }

    argcount = ufunc->uf_args.ga_len;
    min_argcount = ufunc->uf_args.ga_len - ufunc->uf_def_args.ga_len;
    *varargs = ufunc->uf_varargs;
  }

  *required = min_argcount;
  *optional = argcount - min_argcount;

  return OK;
}

/// Find a function by name, return pointer to it in ufuncs.
///
/// @return  NULL for unknown function.
ufunc_T *find_func(const char *name)
{
  hashitem_T *hi = hash_find(&func_hashtab, name);
  if (!HASHITEM_EMPTY(hi)) {
    return HI2UF(hi);
  }
  return NULL;
}

/// Copy the function name of "fp" to buffer "buf".
/// "buf" must be able to hold the function name plus three bytes.
/// Takes care of script-local function names.
static int cat_func_name(char *buf, size_t bufsize, ufunc_T *fp)
{
  int len = -1;
  size_t uflen = fp->uf_namelen;
  assert(uflen > 0);

  if ((uint8_t)fp->uf_name[0] == K_SPECIAL && uflen > 3) {
    len = snprintf(buf, bufsize, "<SNR>%s", fp->uf_name + 3);
  } else {
    len = snprintf(buf, bufsize, "%s", fp->uf_name);
  }

  assert(len > 0);
  return (len >= (int)bufsize) ? (int)bufsize - 1 : len;
}

/// Add a number variable "name" to dict "dp" with value "nr".
static void add_nr_var(dict_T *dp, dictitem_T *v, char *name, varnumber_T nr)
{
  STRCPY(v->di_key, name);
  v->di_flags = DI_FLAGS_RO | DI_FLAGS_FIX;
  hash_add(&dp->dv_hashtab, v->di_key);
  v->di_tv.v_type = VAR_NUMBER;
  v->di_tv.v_lock = VAR_FIXED;
  v->di_tv.vval.v_number = nr;
}

/// Free "fc"
static void free_funccal(funccall_T *fc)
{
  for (int i = 0; i < fc->fc_ufuncs.ga_len; i++) {
    ufunc_T *fp = ((ufunc_T **)(fc->fc_ufuncs.ga_data))[i];

    // When garbage collecting a funccall_T may be freed before the
    // function that references it, clear its uf_scoped field.
    // The function may have been redefined and point to another
    // funccal_T, don't clear it then.
    if (fp != NULL && fp->uf_scoped == fc) {
      fp->uf_scoped = NULL;
    }
  }
  ga_clear(&fc->fc_ufuncs);

  func_ptr_unref(fc->fc_func);
  xfree(fc);
}

/// Free "fc" and what it contains.
/// Can be called only when "fc" is kept beyond the period of it called,
/// i.e. after cleanup_function_call(fc).
static void free_funccal_contents(funccall_T *fc)
{
  // Free all l: variables.
  vars_clear(&fc->fc_l_vars.dv_hashtab);

  // Free all a: variables.
  vars_clear(&fc->fc_l_avars.dv_hashtab);

  // Free the a:000 variables.
  TV_LIST_ITER(&fc->fc_l_varlist, li, {
    tv_clear(TV_LIST_ITEM_TV(li));
  });

  free_funccal(fc);
}

/// Handle the last part of returning from a function: free the local hashtable.
/// Unless it is still in use by a closure.
static void cleanup_function_call(funccall_T *fc)
{
  bool may_free_fc = fc->fc_refcount <= 0;
  bool free_fc = true;

  current_funccal = fc->fc_caller;

  // Free all l: variables if not referred.
  if (may_free_fc && fc->fc_l_vars.dv_refcount == DO_NOT_FREE_CNT) {
    vars_clear(&fc->fc_l_vars.dv_hashtab);
  } else {
    free_fc = false;
  }

  // If the a:000 list and the l: and a: dicts are not referenced and
  // there is no closure using it, we can free the funccall_T and what's
  // in it.
  if (may_free_fc && fc->fc_l_avars.dv_refcount == DO_NOT_FREE_CNT) {
    vars_clear_ext(&fc->fc_l_avars.dv_hashtab, false);
  } else {
    free_fc = false;

    // Make a copy of the a: variables, since we didn't do that above.
    TV_DICT_ITER(&fc->fc_l_avars, di, {
      tv_copy(&di->di_tv, &di->di_tv);
    });
  }

  if (may_free_fc && fc->fc_l_varlist.lv_refcount   // NOLINT(runtime/deprecated)
      == DO_NOT_FREE_CNT) {
    fc->fc_l_varlist.lv_first = NULL;  // NOLINT(runtime/deprecated)
  } else {
    free_fc = false;

    // Make a copy of the a:000 items, since we didn't do that above.
    TV_LIST_ITER(&fc->fc_l_varlist, li, {
      tv_copy(TV_LIST_ITEM_TV(li), TV_LIST_ITEM_TV(li));
    });
  }

  if (free_fc) {
    free_funccal(fc);
  } else {
    static int made_copy = 0;

    // "fc" is still in use.  This can happen when returning "a:000",
    // assigning "l:" to a global variable or defining a closure.
    // Link "fc" in the list for garbage collection later.
    fc->fc_caller = previous_funccal;
    previous_funccal = fc;

    if (want_garbage_collect) {
      // If garbage collector is ready, clear count.
      made_copy = 0;
    } else if (++made_copy >= (int)((4096 * 1024) / sizeof(*fc))) {
      // We have made a lot of copies, worth 4 Mbyte.  This can happen
      // when repetitively calling a function that creates a reference to
      // itself somehow.  Call the garbage collector soon to avoid using
      // too much memory.
      made_copy = 0;
      want_garbage_collect = true;
    }
  }
}

/// Unreference "fc": decrement the reference count and free it when it
/// becomes zero.  "fp" is detached from "fc".
///
/// @param[in]   force   When true, we are exiting.
static void funccal_unref(funccall_T *fc, ufunc_T *fp, bool force)
{
  if (fc == NULL) {
    return;
  }

  fc->fc_refcount--;
  if (force ? fc->fc_refcount <= 0 : !fc_referenced(fc)) {
    for (funccall_T **pfc = &previous_funccal; *pfc != NULL; pfc = &(*pfc)->fc_caller) {
      if (fc == *pfc) {
        *pfc = fc->fc_caller;
        free_funccal_contents(fc);
        return;
      }
    }
  }
  for (int i = 0; i < fc->fc_ufuncs.ga_len; i++) {
    if (((ufunc_T **)(fc->fc_ufuncs.ga_data))[i] == fp) {
      ((ufunc_T **)(fc->fc_ufuncs.ga_data))[i] = NULL;
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
  if (HASHITEM_EMPTY(hi)) {
    return false;
  }

  hash_remove(&func_hashtab, hi);
  return true;
}

static void func_clear_items(ufunc_T *fp)
{
  ga_clear_strings(&(fp->uf_args));
  ga_clear_strings(&(fp->uf_def_args));
  ga_clear_strings(&(fp->uf_lines));

  if (fp->uf_flags & FC_LUAREF) {
    api_free_luaref(fp->uf_luaref);
    fp->uf_luaref = LUA_NOREF;
  }

  XFREE_CLEAR(fp->uf_tml_count);
  XFREE_CLEAR(fp->uf_tml_total);
  XFREE_CLEAR(fp->uf_tml_self);
}

/// Free all things that a function contains. Does not free the function
/// itself, use func_free() for that.
///
/// @param[in] force  When true, we are exiting.
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
/// @param[in] fp  The function to free.
static void func_free(ufunc_T *fp)
{
  // only remove it when not done already, otherwise we would remove a newer
  // version of the function
  if ((fp->uf_flags & (FC_DELETED | FC_REMOVED)) == 0) {
    func_remove(fp);
  }

  XFREE_CLEAR(fp->uf_name_exp);
  xfree(fp);
}

/// Free all things that a function contains and free the function itself.
///
/// @param[in] force  When true, we are exiting.
static void func_clear_free(ufunc_T *fp, bool force)
{
  func_clear(fp, force);
  func_free(fp);
}

/// Allocate a funccall_T, link it in current_funccal and fill in "fp" and "rettv".
/// Must be followed by one call to remove_funccal() or cleanup_function_call().
funccall_T *create_funccal(ufunc_T *fp, typval_T *rettv)
{
  funccall_T *fc = xcalloc(1, sizeof(funccall_T));
  fc->fc_caller = current_funccal;
  current_funccal = fc;
  fc->fc_func = fp;
  func_ptr_ref(fp);
  fc->fc_rettv = rettv;
  return fc;
}

/// Restore current_funccal.
void remove_funccal(void)
{
  funccall_T *fc = current_funccal;
  current_funccal = fc->fc_caller;
  free_funccal(fc);
}

/// Call a user function
///
/// @param fp  Function to call.
/// @param[in] argcount  Number of arguments.
/// @param argvars  Arguments.
/// @param[out] rettv  Return value.
/// @param[in] firstline  First line of range.
/// @param[in] lastline  Last line of range.
/// @param selfdict  Dict for "self" for dictionary functions.
void call_user_func(ufunc_T *fp, int argcount, typval_T *argvars, typval_T *rettv,
                    linenr_T firstline, linenr_T lastline, dict_T *selfdict)
  FUNC_ATTR_NONNULL_ARG(1, 3, 4)
{
  bool using_sandbox = false;
  static int depth = 0;
  dictitem_T *v;
  int fixvar_idx = 0;           // index in fc_fixvar[]
  bool islambda = false;
  char numbuf[NUMBUFLEN];
  char *name;
  size_t namelen;
  typval_T *tv_to_free[MAX_FUNC_ARGS];
  int tv_to_free_len = 0;
  proftime_T wait_start;
  proftime_T call_start;
  bool started_profiling = false;
  bool did_save_redo = false;
  save_redo_T save_redo;

  // If depth of calling is getting too high, don't execute the function
  if (depth >= p_mfd) {
    emsg(_("E132: Function call depth is higher than 'maxfuncdepth'"));
    rettv->v_type = VAR_NUMBER;
    rettv->vval.v_number = -1;
    return;
  }
  depth++;
  // Save search patterns and redo buffer.
  save_search_patterns();
  if (!ins_compl_active()) {
    saveRedobuff(&save_redo);
    did_save_redo = true;
  }
  fp->uf_calls++;
  // check for CTRL-C hit
  line_breakcheck();
  // prepare the funccall_T structure
  funccall_T *fc = create_funccal(fp, rettv);
  fc->fc_level = ex_nesting_level;
  // Check if this function has a breakpoint.
  fc->fc_breakpoint = dbg_find_breakpoint(false, fp->uf_name, 0);
  fc->fc_dbg_tick = debug_tick;
  // Set up fields for closure.
  ga_init(&fc->fc_ufuncs, sizeof(ufunc_T *), 1);

  if (strncmp(fp->uf_name, "<lambda>", 8) == 0) {
    islambda = true;
  }

  // Note about using fc->fc_fixvar[]: This is an array of FIXVAR_CNT variables
  // with names up to VAR_SHORT_LEN long.  This avoids having to alloc/free
  // each argument variable and saves a lot of time.
  //
  // Init l: variables.
  init_var_dict(&fc->fc_l_vars, &fc->fc_l_vars_var, VAR_DEF_SCOPE);
  if (selfdict != NULL) {
    // Set l:self to "selfdict".  Use "name" to avoid a warning from
    // some compiler that checks the destination size.
    v = (dictitem_T *)&fc->fc_fixvar[fixvar_idx++];
    name = (char *)v->di_key;
    STRCPY(name, "self");
    v->di_flags = DI_FLAGS_RO | DI_FLAGS_FIX;
    hash_add(&fc->fc_l_vars.dv_hashtab, v->di_key);
    v->di_tv.v_type = VAR_DICT;
    v->di_tv.v_lock = VAR_UNLOCKED;
    v->di_tv.vval.v_dict = selfdict;
    selfdict->dv_refcount++;
  }

  // Init a: variables, unless none found (in lambda).
  // Set a:0 to "argcount" less number of named arguments, if >= 0.
  // Set a:000 to a list with room for the "..." arguments.
  init_var_dict(&fc->fc_l_avars, &fc->fc_l_avars_var, VAR_SCOPE);
  if ((fp->uf_flags & FC_NOARGS) == 0) {
    add_nr_var(&fc->fc_l_avars, (dictitem_T *)&fc->fc_fixvar[fixvar_idx++], "0",
               (varnumber_T)(argcount >= fp->uf_args.ga_len
                             ? argcount - fp->uf_args.ga_len : 0));
  }
  fc->fc_l_avars.dv_lock = VAR_FIXED;
  if ((fp->uf_flags & FC_NOARGS) == 0) {
    // Use "name" to avoid a warning from some compiler that checks the
    // destination size.
    v = (dictitem_T *)&fc->fc_fixvar[fixvar_idx++];
    name = (char *)v->di_key;
    STRCPY(name, "000");
    v->di_flags = DI_FLAGS_RO | DI_FLAGS_FIX;
    hash_add(&fc->fc_l_avars.dv_hashtab, v->di_key);
    v->di_tv.v_type = VAR_LIST;
    v->di_tv.v_lock = VAR_FIXED;
    v->di_tv.vval.v_list = &fc->fc_l_varlist;
  }
  tv_list_init_static(&fc->fc_l_varlist);
  tv_list_set_lock(&fc->fc_l_varlist, VAR_FIXED);

  // Set a:firstline to "firstline" and a:lastline to "lastline".
  // Set a:name to named arguments.
  // Set a:N to the "..." arguments.
  // Skipped when no a: variables used (in lambda).
  if ((fp->uf_flags & FC_NOARGS) == 0) {
    add_nr_var(&fc->fc_l_avars, (dictitem_T *)&fc->fc_fixvar[fixvar_idx++],
               "firstline", (varnumber_T)firstline);
    add_nr_var(&fc->fc_l_avars, (dictitem_T *)&fc->fc_fixvar[fixvar_idx++],
               "lastline", (varnumber_T)lastline);
  }
  bool default_arg_err = false;
  for (int i = 0; i < argcount || i < fp->uf_args.ga_len; i++) {
    bool addlocal = false;
    bool isdefault = false;
    typval_T def_rettv;

    int ai = i - fp->uf_args.ga_len;
    if (ai < 0) {
      // named argument a:name
      name = FUNCARG(fp, i);
      if (islambda) {
        addlocal = true;
      }

      // evaluate named argument default expression
      isdefault = ai + fp->uf_def_args.ga_len >= 0 && i >= argcount;
      if (isdefault) {
        char *default_expr = NULL;
        def_rettv.v_type = VAR_NUMBER;
        def_rettv.vval.v_number = -1;

        default_expr = ((char **)(fp->uf_def_args.ga_data))
                       [ai + fp->uf_def_args.ga_len];
        if (eval1(&default_expr, &def_rettv, &EVALARG_EVALUATE) == FAIL) {
          default_arg_err = true;
          break;
        }
      }

      namelen = strlen(name);
    } else {
      if ((fp->uf_flags & FC_NOARGS) != 0) {
        // Bail out if no a: arguments used (in lambda).
        break;
      }
      // "..." argument a:1, a:2, etc.
      namelen = (size_t)snprintf(numbuf, sizeof(numbuf), "%d", ai + 1);
      name = numbuf;
    }
    if (fixvar_idx < FIXVAR_CNT && namelen <= VAR_SHORT_LEN) {
      v = (dictitem_T *)&fc->fc_fixvar[fixvar_idx++];
      v->di_flags = DI_FLAGS_RO | DI_FLAGS_FIX;
      STRCPY(v->di_key, name);
    } else {
      v = tv_dict_item_alloc_len(name, namelen);
      v->di_flags |= DI_FLAGS_RO | DI_FLAGS_FIX;
    }

    // Note: the values are copied directly to avoid alloc/free.
    // "argvars" must have VAR_FIXED for v_lock.
    v->di_tv = isdefault ? def_rettv : argvars[i];
    v->di_tv.v_lock = VAR_FIXED;

    if (isdefault) {
      // Need to free this later, no matter where it's stored.
      tv_to_free[tv_to_free_len++] = &v->di_tv;
    }

    if (addlocal) {
      // Named arguments can be accessed without the "a:" prefix in lambda
      // expressions. Add to the l: dict.
      tv_copy(&v->di_tv, &v->di_tv);
      hash_add(&fc->fc_l_vars.dv_hashtab, v->di_key);
    } else {
      hash_add(&fc->fc_l_avars.dv_hashtab, v->di_key);
    }

    if (ai >= 0 && ai < MAX_FUNC_ARGS) {
      listitem_T *li = &fc->fc_l_listitems[ai];

      *TV_LIST_ITEM_TV(li) = argvars[i];
      TV_LIST_ITEM_TV(li)->v_lock = VAR_FIXED;
      tv_list_append(&fc->fc_l_varlist, li);
    }
  }

  // Don't redraw while executing the function.
  RedrawingDisabled++;

  if (fp->uf_flags & FC_SANDBOX) {
    using_sandbox = true;
    sandbox++;
  }

  estack_push_ufunc(fp, 1);
  if (p_verbose >= 12) {
    no_wait_return++;
    verbose_enter_scroll();

    smsg(0, _("calling %s"), SOURCING_NAME);
    if (p_verbose >= 14) {
      msg_puts("(");
      for (int i = 0; i < argcount; i++) {
        if (i > 0) {
          msg_puts(", ");
        }
        if (argvars[i].v_type == VAR_NUMBER) {
          msg_outnum((int)argvars[i].vval.v_number);
        } else {
          // Do not want errors such as E724 here.
          emsg_off++;
          char *tofree = encode_tv2string(&argvars[i], NULL);
          emsg_off--;
          if (tofree != NULL) {
            char *s = tofree;
            char buf[MSG_BUF_LEN];
            if (vim_strsize(s) > MSG_BUF_CLEN) {
              trunc_string(s, buf, MSG_BUF_CLEN, sizeof(buf));
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
    no_wait_return--;
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
        || (fc->fc_caller != NULL && fc->fc_caller->fc_func->uf_profiling));

  if (func_or_func_caller_profiling) {
    fp->uf_tm_count++;
    call_start = profile_start();
    fp->uf_tm_children = profile_zero();
  }

  if (do_profiling_yes) {
    script_prof_save(&wait_start);
  }

  const sctx_T save_current_sctx = current_sctx;
  current_sctx = fp->uf_script_ctx;
  int save_did_emsg = did_emsg;
  did_emsg = false;

  if (default_arg_err && (fp->uf_flags & FC_ABORT)) {
    did_emsg = true;
  } else if (islambda) {
    char *p = *(char **)fp->uf_lines.ga_data + 7;

    // A Lambda always has the command "return {expr}".  It is much faster
    // to evaluate {expr} directly.
    ex_nesting_level++;
    eval1(&p, rettv, &EVALARG_EVALUATE);
    ex_nesting_level--;
  } else {
    // call do_cmdline() to execute the lines
    do_cmdline(NULL, get_func_line, (void *)fc,
               DOCMD_NOWAIT|DOCMD_VERBOSE|DOCMD_REPEAT);
  }

  // Invoke functions added with ":defer".
  handle_defer_one(current_funccal);

  RedrawingDisabled--;

  // when the function was aborted because of an error, return -1
  if ((did_emsg
       && (fp->uf_flags & FC_ABORT)) || rettv->v_type == VAR_UNKNOWN) {
    tv_clear(rettv);
    rettv->v_type = VAR_NUMBER;
    rettv->vval.v_number = -1;
  }

  if (func_or_func_caller_profiling) {
    call_start = profile_end(call_start);
    call_start = profile_sub_wait(wait_start, call_start);
    fp->uf_tm_total = profile_add(fp->uf_tm_total, call_start);
    fp->uf_tm_self = profile_self(fp->uf_tm_self, call_start,
                                  fp->uf_tm_children);
    if (fc->fc_caller != NULL && fc->fc_caller->fc_func->uf_profiling) {
      fc->fc_caller->fc_func->uf_tm_children =
        profile_add(fc->fc_caller->fc_func->uf_tm_children, call_start);
      fc->fc_caller->fc_func->uf_tml_children =
        profile_add(fc->fc_caller->fc_func->uf_tml_children, call_start);
    }
    if (started_profiling) {
      // make a ":profdel func" stop profiling the function
      fp->uf_profiling = false;
    }
  }

  // when being verbose, mention the return value
  if (p_verbose >= 12) {
    no_wait_return++;
    verbose_enter_scroll();

    if (aborting()) {
      smsg(0, _("%s aborted"), SOURCING_NAME);
    } else if (fc->fc_rettv->v_type == VAR_NUMBER) {
      smsg(0, _("%s returning #%" PRId64 ""),
           SOURCING_NAME, (int64_t)fc->fc_rettv->vval.v_number);
    } else {
      char buf[MSG_BUF_LEN];

      // The value may be very long.  Skip the middle part, so that we
      // have some idea how it starts and ends. smsg() would always
      // truncate it at the end. Don't want errors such as E724 here.
      emsg_off++;
      char *s = encode_tv2string(fc->fc_rettv, NULL);
      char *tofree = s;
      emsg_off--;
      if (s != NULL) {
        if (vim_strsize(s) > MSG_BUF_CLEN) {
          trunc_string(s, buf, MSG_BUF_CLEN, MSG_BUF_LEN);
          s = buf;
        }
        smsg(0, _("%s returning %s"), SOURCING_NAME, s);
        xfree(tofree);
      }
    }
    msg_puts("\n");  // don't overwrite this either

    verbose_leave_scroll();
    no_wait_return--;
  }

  estack_pop();
  current_sctx = save_current_sctx;
  if (do_profiling_yes) {
    script_prof_restore(&wait_start);
  }
  if (using_sandbox) {
    sandbox--;
  }

  if (p_verbose >= 12 && SOURCING_NAME != NULL) {
    no_wait_return++;
    verbose_enter_scroll();

    smsg(0, _("continuing in %s"), SOURCING_NAME);
    msg_puts("\n");  // don't overwrite this either

    verbose_leave_scroll();
    no_wait_return--;
  }

  did_emsg |= save_did_emsg;
  depth--;
  for (int i = 0; i < tv_to_free_len; i++) {
    tv_clear(tv_to_free[i]);
  }
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

/// There are two kinds of function names:
/// 1. ordinary names, function defined with :function
/// 2. numbered functions and lambdas
/// For the first we only count the name stored in func_hashtab as a reference,
/// using function() does not count as a reference, because the function is
/// looked up by name.
static bool func_name_refcount(const char *name)
{
  return isdigit((uint8_t)(*name)) || *name == '<';
}

/// Check the argument count for user function "fp".
/// @return  FCERR_UNKNOWN if OK, FCERR_TOOFEW or FCERR_TOOMANY otherwise.
static int check_user_func_argcount(ufunc_T *fp, int argcount)
  FUNC_ATTR_NONNULL_ALL
{
  const int regular_args = fp->uf_args.ga_len;

  if (argcount < regular_args - fp->uf_def_args.ga_len) {
    return FCERR_TOOFEW;
  } else if (!fp->uf_varargs && argcount > regular_args) {
    return FCERR_TOOMANY;
  }
  return FCERR_UNKNOWN;
}

/// Call a user function after checking the arguments.
static int call_user_func_check(ufunc_T *fp, int argcount, typval_T *argvars, typval_T *rettv,
                                funcexe_T *funcexe, dict_T *selfdict)
  FUNC_ATTR_NONNULL_ARG(1, 3, 4, 5)
{
  if (fp->uf_flags & FC_LUAREF) {
    return typval_exec_lua_callable(fp->uf_luaref, argcount, argvars, rettv);
  }

  if ((fp->uf_flags & FC_RANGE) && funcexe->fe_doesrange != NULL) {
    *funcexe->fe_doesrange = true;
  }
  int error = check_user_func_argcount(fp, argcount);
  if (error != FCERR_UNKNOWN) {
    return error;
  }
  if ((fp->uf_flags & FC_DICT) && selfdict == NULL) {
    error = FCERR_DICT;
  } else {
    // Call the user function.
    call_user_func(fp, argcount, argvars, rettv, funcexe->fe_firstline, funcexe->fe_lastline,
                   (fp->uf_flags & FC_DICT) ? selfdict : NULL);
    error = FCERR_NONE;
  }
  return error;
}

static funccal_entry_T *funccal_stack = NULL;

/// Save the current function call pointer, and set it to NULL.
/// Used when executing autocommands and for ":source".
void save_funccal(funccal_entry_T *entry)
{
  entry->top_funccal = current_funccal;
  entry->next = funccal_stack;
  funccal_stack = entry;
  current_funccal = NULL;
}

void restore_funccal(void)
{
  if (funccal_stack == NULL) {
    iemsg("INTERNAL: restore_funccal()");
  } else {
    current_funccal = funccal_stack->top_funccal;
    funccal_stack = funccal_stack->next;
  }
}

funccall_T *get_current_funccal(void)
{
  return current_funccal;
}

void set_current_funccal(funccall_T *fc)
{
  current_funccal = fc;
}

#if defined(EXITFREE)
void free_all_functions(void)
{
  hashitem_T *hi;
  ufunc_T *fp;
  uint64_t skipped = 0;
  uint64_t todo = 1;
  int changed;

  // Clean up the current_funccal chain and the funccal stack.
  while (current_funccal != NULL) {
    tv_clear(current_funccal->fc_rettv);
    cleanup_function_call(current_funccal);
    if (current_funccal == NULL && funccal_stack != NULL) {
      restore_funccal();
    }
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
          changed = func_hashtab.ht_changed;
          func_clear(fp, true);
          if (changed != func_hashtab.ht_changed) {
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

/// Checks if a builtin function with the given name exists.
///
/// @param[in]   name   name of the builtin function to check.
/// @param[in]   len    length of "name", or -1 for NUL terminated.
///
/// @return true if "name" looks like a builtin function name: starts with a
/// lower case letter and doesn't contain AUTOLOAD_CHAR or ':'.
static bool builtin_function(const char *name, int len)
{
  if (!ASCII_ISLOWER(name[0]) || name[1] == ':') {
    return false;
  }

  const char *p = (len == -1
                   ? strchr(name, AUTOLOAD_CHAR)
                   : memchr(name, AUTOLOAD_CHAR, (size_t)len));

  return p == NULL;
}

int func_call(char *name, typval_T *args, partial_T *partial, dict_T *selfdict, typval_T *rettv)
{
  typval_T argv[MAX_FUNC_ARGS + 1];
  int argc = 0;
  int r = 0;

  TV_LIST_ITER(args->vval.v_list, item, {
    if (argc == MAX_FUNC_ARGS - (partial == NULL ? 0 : partial->pt_argc)) {
      emsg(_("E699: Too many arguments"));
      goto func_call_skip_call;
    }
    // Make a copy of each argument.  This is needed to be able to set
    // v_lock to VAR_FIXED in the copy without changing the original list.
    tv_copy(TV_LIST_ITEM_TV(item), &argv[argc++]);
  });

  funcexe_T funcexe = FUNCEXE_INIT;
  funcexe.fe_firstline = curwin->w_cursor.lnum;
  funcexe.fe_lastline = curwin->w_cursor.lnum;
  funcexe.fe_evaluate = true;
  funcexe.fe_partial = partial;
  funcexe.fe_selfdict = selfdict;
  r = call_func(name, -1, rettv, argc, argv, &funcexe);

func_call_skip_call:
  // Free the arguments.
  while (argc > 0) {
    tv_clear(&argv[--argc]);
  }

  return r;
}

/// call the 'callback' function and return the result as a number.
/// Returns -2 when calling the function fails.  Uses argv[0] to argv[argc - 1]
/// for the function arguments. argv[argc] should have type VAR_UNKNOWN.
///
/// @param argcount  number of "argvars"
/// @param argvars   vars for arguments, must have "argcount" PLUS ONE elements!
varnumber_T callback_call_retnr(Callback *callback, int argcount, typval_T *argvars)
{
  typval_T rettv;
  if (!callback_call(callback, argcount, argvars, &rettv)) {
    return -2;
  }

  varnumber_T retval = tv_get_number_chk(&rettv, NULL);
  tv_clear(&rettv);
  return retval;
}

/// Give an error message for the result of a function.
/// Nothing if "error" is FCERR_NONE.
static void user_func_error(int error, const char *name, bool found_var)
  FUNC_ATTR_NONNULL_ARG(2)
{
  switch (error) {
  case FCERR_UNKNOWN:
    if (found_var) {
      semsg(_(e_not_callable_type_str), name);
    } else {
      emsg_funcname(e_unknown_function_str, name);
    }
    break;
  case FCERR_NOTMETHOD:
    emsg_funcname(N_("E276: Cannot use function as a method: %s"), name);
    break;
  case FCERR_DELETED:
    emsg_funcname(N_("E933: Function was deleted: %s"), name);
    break;
  case FCERR_TOOMANY:
    emsg_funcname(_(e_toomanyarg), name);
    break;
  case FCERR_TOOFEW:
    emsg_funcname(_(e_toofewarg), name);
    break;
  case FCERR_SCRIPT:
    emsg_funcname(N_("E120: Using <SID> not in a script context: %s"), name);
    break;
  case FCERR_DICT:
    emsg_funcname(N_("E725: Calling dict function without Dictionary: %s"), name);
    break;
  }
}

/// Used by call_func to add a method base (if any) to a function argument list
/// as the first argument. @see call_func
static void argv_add_base(typval_T *const basetv, typval_T **const argvars, int *const argcount,
                          typval_T *const new_argvars, int *const argv_base)
  FUNC_ATTR_NONNULL_ARG(2, 3, 4, 5)
{
  if (basetv != NULL) {
    // Method call: base->Method()
    memmove(&new_argvars[1], *argvars, sizeof(typval_T) * (size_t)(*argcount));
    new_argvars[0] = *basetv;
    (*argcount)++;
    *argvars = new_argvars;
    *argv_base = 1;
  }
}

/// Call a function with its resolved parameters
///
/// @param funcname  name of the function
/// @param len  length of "name" or -1 to use strlen()
/// @param rettv  [out] value goes here
/// @param argcount_in  number of "argvars"
/// @param argvars_in  vars for arguments, must have "argcount" PLUS ONE elements!
/// @param funcexe  more arguments
///
/// @return FAIL if function cannot be called, else OK (even if an error
///         occurred while executing the function! Set `msg_list` to capture
///         the error, see do_cmdline()).
int call_func(const char *funcname, int len, typval_T *rettv, int argcount_in, typval_T *argvars_in,
              funcexe_T *funcexe)
  FUNC_ATTR_NONNULL_ARG(1, 3, 5, 6)
{
  int ret = FAIL;
  int error = FCERR_NONE;
  ufunc_T *fp = NULL;
  char fname_buf[FLEN_FIXED + 1];
  char *tofree = NULL;
  char *fname = NULL;
  char *name = NULL;
  int argcount = argcount_in;
  typval_T *argvars = argvars_in;
  dict_T *selfdict = funcexe->fe_selfdict;
  typval_T argv[MAX_FUNC_ARGS + 1];  // used when "partial" or
                                     // "funcexe->fe_basetv" is not NULL
  int argv_clear = 0;
  int argv_base = 0;
  partial_T *partial = funcexe->fe_partial;

  // Initialize rettv so that it is safe for caller to invoke tv_clear(rettv)
  // even when call_func() returns FAIL.
  rettv->v_type = VAR_UNKNOWN;

  if (len <= 0) {
    len = (int)strlen(funcname);
  }
  if (partial != NULL) {
    fp = partial->pt_func;
  }
  if (fp == NULL) {
    // Make a copy of the name, if it comes from a funcref variable it could
    // be changed or deleted in the called function.
    name = xmemdupz(funcname, (size_t)len);
    fname = fname_trans_sid(name, fname_buf, &tofree, &error);
  }

  if (funcexe->fe_doesrange != NULL) {
    *funcexe->fe_doesrange = false;
  }

  if (partial != NULL) {
    // When the function has a partial with a dict and there is a dict
    // argument, use the dict argument. That is backwards compatible.
    // When the dict was bound explicitly use the one from the partial.
    if (partial->pt_dict != NULL && (selfdict == NULL || !partial->pt_auto)) {
      selfdict = partial->pt_dict;
    }
    if (error == FCERR_NONE && partial->pt_argc > 0) {
      for (argv_clear = 0; argv_clear < partial->pt_argc; argv_clear++) {
        if (argv_clear + argcount_in >= MAX_FUNC_ARGS) {
          error = FCERR_TOOMANY;
          goto theend;
        }
        tv_copy(&partial->pt_argv[argv_clear], &argv[argv_clear]);
      }
      for (int i = 0; i < argcount_in; i++) {
        argv[i + argv_clear] = argvars_in[i];
      }
      argvars = argv;
      argcount = partial->pt_argc + argcount_in;
    }
  }

  if (error == FCERR_NONE && funcexe->fe_evaluate) {
    // Skip "g:" before a function name.
    bool is_global = fp == NULL && fname[0] == 'g' && fname[1] == ':';
    char *rfname = is_global ? fname + 2 : fname;

    rettv->v_type = VAR_NUMBER;         // default rettv is number zero
    rettv->vval.v_number = 0;
    error = FCERR_UNKNOWN;

    if (is_luafunc(partial)) {
      if (len > 0) {
        error = FCERR_NONE;
        argv_add_base(funcexe->fe_basetv, &argvars, &argcount, argv, &argv_base);
        nlua_typval_call(funcname, (size_t)len, argvars, argcount, rettv);
      } else {
        // v:lua was called directly; show its name in the emsg
        XFREE_CLEAR(name);
        funcname = "v:lua";
      }
    } else if (fp != NULL || !builtin_function(rfname, -1)) {
      // User defined function.
      if (fp == NULL) {
        fp = find_func(rfname);
      }

      // Trigger FuncUndefined event, may load the function.
      if (fp == NULL
          && apply_autocmds(EVENT_FUNCUNDEFINED, rfname, rfname, true, NULL)
          && !aborting()) {
        // executed an autocommand, search for the function again
        fp = find_func(rfname);
      }
      // Try loading a package.
      if (fp == NULL && script_autoload(rfname, strlen(rfname), true) && !aborting()) {
        // Loaded a package, search for the function again.
        fp = find_func(rfname);
      }

      if (fp != NULL && (fp->uf_flags & FC_DELETED)) {
        error = FCERR_DELETED;
      } else if (fp != NULL) {
        if (funcexe->fe_argv_func != NULL) {
          // postponed filling in the arguments, do it now
          argcount = funcexe->fe_argv_func(argcount, argvars, argv_clear, fp);
        }

        argv_add_base(funcexe->fe_basetv, &argvars, &argcount, argv, &argv_base);

        error = call_user_func_check(fp, argcount, argvars, rettv, funcexe, selfdict);
      }
    } else if (funcexe->fe_basetv != NULL) {
      // expr->method(): Find the method name in the table, call its
      // implementation with the base as one of the arguments.
      error = call_internal_method(fname, argcount, argvars, rettv,
                                   funcexe->fe_basetv);
    } else {
      // Find the function name in the table, call its implementation.
      error = call_internal_func(fname, argcount, argvars, rettv);
    }
    // The function call (or "FuncUndefined" autocommand sequence) might
    // have been aborted by an error, an interrupt, or an explicitly thrown
    // exception that has not been caught so far.  This situation can be
    // tested for by calling aborting().  For an error in an internal
    // function or for the "E132" error in call_user_func(), however, the
    // throw point at which the "force_abort" flag (temporarily reset by
    // emsg()) is normally updated has not been reached yet. We need to
    // update that flag first to make aborting() reliable.
    update_force_abort();
  }
  if (error == FCERR_NONE) {
    ret = OK;
  }

theend:
  // Report an error unless the argument evaluation or function call has been
  // cancelled due to an aborting error, an interrupt, or an exception.
  if (!aborting()) {
    user_func_error(error, (name != NULL) ? name : funcname, funcexe->fe_found_var);
  }

  // clear the copies made from the partial
  while (argv_clear > 0) {
    tv_clear(&argv[--argv_clear + argv_base]);
  }

  xfree(tofree);
  xfree(name);

  return ret;
}

int call_simple_luafunc(const char *funcname, size_t len, typval_T *rettv)
  FUNC_ATTR_NONNULL_ALL
{
  rettv->v_type = VAR_NUMBER;  // default rettv is number zero
  rettv->vval.v_number = 0;

  typval_T argvars[1];
  argvars[0].v_type = VAR_UNKNOWN;
  nlua_typval_call(funcname, len, argvars, 0, rettv);
  return OK;
}

/// Call a function without arguments, partial or dict.
/// This is like call_func() when the call is only "FuncName()".
/// To be used by "expr" options.
/// Returns NOTDONE when the function could not be found.
///
/// @param funcname  name of the function
/// @param len       length of "name"
/// @param rettv     return value goes here
int call_simple_func(const char *funcname, size_t len, typval_T *rettv)
  FUNC_ATTR_NONNULL_ALL
{
  int ret = FAIL;

  rettv->v_type = VAR_NUMBER;  // default rettv is number zero
  rettv->vval.v_number = 0;

  // Make a copy of the name, an option can be changed in the function.
  char *name = xstrnsave(funcname, len);

  int error = FCERR_NONE;
  char *tofree = NULL;
  char fname_buf[FLEN_FIXED + 1];
  char *fname = fname_trans_sid(name, fname_buf, &tofree, &error);

  // Skip "g:" before a function name.
  bool is_global = fname[0] == 'g' && fname[1] == ':';
  char *rfname = is_global ? fname + 2 : fname;

  ufunc_T *fp = find_func(rfname);
  if (fp == NULL) {
    ret = NOTDONE;
  } else if (fp != NULL && (fp->uf_flags & FC_DELETED)) {
    error = FCERR_DELETED;
  } else if (fp != NULL) {
    typval_T argvars[1];
    argvars[0].v_type = VAR_UNKNOWN;
    funcexe_T funcexe = FUNCEXE_INIT;
    funcexe.fe_evaluate = true;

    error = call_user_func_check(fp, 0, argvars, rettv, &funcexe, NULL);
    if (error == FCERR_NONE) {
      ret = OK;
    }
  }

  user_func_error(error, name, false);
  xfree(tofree);
  xfree(name);

  return ret;
}

char *printable_func_name(ufunc_T *fp)
{
  return fp->uf_name_exp != NULL ? fp->uf_name_exp : fp->uf_name;
}

/// When "prev_ht_changed" does not equal "ht_changed" give an error and return
/// true.  Otherwise return false.
static int function_list_modified(const int prev_ht_changed)
{
  if (prev_ht_changed != func_hashtab.ht_changed) {
    emsg(_(e_function_list_was_modified));
    return true;
  }
  return false;
}

/// List the head of the function: "name(arg1, arg2)".
///
/// @param[in]  fp      Function pointer.
/// @param[in]  indent  Indent line.
/// @param[in]  force   Include bang "!" (i.e.: "function!").
static int list_func_head(ufunc_T *fp, bool indent, bool force)
{
  const int prev_ht_changed = func_hashtab.ht_changed;

  msg_start();

  // a callback at the more prompt may have deleted the function
  if (function_list_modified(prev_ht_changed)) {
    return FAIL;
  }

  if (indent) {
    msg_puts("   ");
  }
  msg_puts(force ? "function! " : "function ");
  if (fp->uf_name_exp != NULL) {
    msg_puts(fp->uf_name_exp);
  } else {
    msg_puts(fp->uf_name);
  }
  msg_putchar('(');
  int j;
  for (j = 0; j < fp->uf_args.ga_len; j++) {
    if (j) {
      msg_puts(", ");
    }
    msg_puts(FUNCARG(fp, j));
    if (j >= fp->uf_args.ga_len - fp->uf_def_args.ga_len) {
      msg_puts(" = ");
      msg_puts(((char **)(fp->uf_def_args.ga_data))
               [j - fp->uf_args.ga_len + fp->uf_def_args.ga_len]);
    }
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

  return OK;
}

/// Get a function name, translating "<SID>" and "<SNR>".
/// Also handles a Funcref in a List or Dict.
/// flags:
/// TFN_INT:         internal function name OK
/// TFN_QUIET:       be quiet
/// TFN_NO_AUTOLOAD: do not use script autoloading
/// TFN_NO_DEREF:    do not dereference a Funcref
/// Advances "pp" to just after the function name (if no error).
///
/// @param skip  only find the end, don't evaluate
/// @param fdp  return: info about dictionary used
/// @param partial  return: partial of a FuncRef
///
/// @return the function name in allocated memory, or NULL for failure.
char *trans_function_name(char **pp, bool skip, int flags, funcdict_T *fdp, partial_T **partial)
  FUNC_ATTR_NONNULL_ARG(1)
{
  char *name = NULL;
  int len;
  lval_T lv;

  if (fdp != NULL) {
    CLEAR_POINTER(fdp);
  }
  const char *start = *pp;

  // Check for hard coded <SNR>: already translated function ID (from a user
  // command).
  if ((uint8_t)(*pp)[0] == K_SPECIAL && (uint8_t)(*pp)[1] == KS_EXTRA && (*pp)[2] == KE_SNR) {
    *pp += 3;
    len = get_id_len((const char **)pp) + 3;
    return xmemdupz(start, (size_t)len);
  }

  // A name starting with "<SID>" or "<SNR>" is local to a script.  But
  // don't skip over "s:", get_lval() needs it for "s:dict.func".
  int lead = eval_fname_script(start);
  if (lead > 2) {
    start += lead;
  }

  // Note that TFN_ flags use the same values as GLV_ flags.
  const char *end = get_lval((char *)start, NULL, &lv, false, skip, flags | GLV_READ_ONLY,
                             lead > 2 ? 0 : FNE_CHECK_START);
  if (end == start) {
    if (!skip) {
      emsg(_("E129: Function name required"));
    }
    goto theend;
  }
  if (end == NULL || (lv.ll_tv != NULL && (lead > 2 || lv.ll_range))) {
    // Report an invalid expression in braces, unless the expression
    // evaluation has been cancelled due to an aborting error, an
    // interrupt, or an exception.
    if (!aborting()) {
      if (end != NULL) {
        semsg(_(e_invarg2), start);
      }
    } else {
      *pp = (char *)find_name_end(start, NULL, NULL, FNE_INCL_BR);
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
      name = xstrdup(lv.ll_tv->vval.v_string);
      *pp = (char *)end;
    } else if (lv.ll_tv->v_type == VAR_PARTIAL
               && lv.ll_tv->vval.v_partial != NULL) {
      if (is_luafunc(lv.ll_tv->vval.v_partial) && *end == '.') {
        len = check_luafunc_name(end + 1, true);
        if (len == 0) {
          semsg(e_invexpr2, "v:lua");
          goto theend;
        }
        name = xmallocz((size_t)len);
        memcpy(name, end + 1, (size_t)len);
        *pp = (char *)end + 1 + len;
      } else {
        name = xstrdup(partial_name(lv.ll_tv->vval.v_partial));
        *pp = (char *)end;
      }
      if (partial != NULL) {
        *partial = lv.ll_tv->vval.v_partial;
      }
    } else {
      if (!skip && !(flags & TFN_QUIET) && (fdp == NULL
                                            || lv.ll_dict == NULL
                                            || fdp->fd_newkey == NULL)) {
        emsg(_(e_funcref));
      } else {
        *pp = (char *)end;
      }
      name = NULL;
    }
    goto theend;
  }

  if (lv.ll_name == NULL) {
    // Error found, but continue after the function name.
    *pp = (char *)end;
    goto theend;
  }

  // Check if the name is a Funcref.  If so, use the value.
  if (lv.ll_exp_name != NULL) {
    len = (int)strlen(lv.ll_exp_name);
    name = deref_func_name(lv.ll_exp_name, &len, partial, flags & TFN_NO_AUTOLOAD, NULL);
    if (name == lv.ll_exp_name) {
      name = NULL;
    }
  } else if (!(flags & TFN_NO_DEREF)) {
    len = (int)(end - *pp);
    name = deref_func_name(*pp, &len, partial, flags & TFN_NO_AUTOLOAD, NULL);
    if (name == *pp) {
      name = NULL;
    }
  }
  if (name != NULL) {
    name = xstrdup(name);
    *pp = (char *)end;
    if (strncmp(name, "<SNR>", 5) == 0) {
      // Change "<SNR>" to the byte sequence.
      name[0] = (char)K_SPECIAL;
      name[1] = (char)KS_EXTRA;
      name[2] = KE_SNR;
      memmove(name + 3, name + 5, strlen(name + 5) + 1);
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
    len = (int)(end - lv.ll_name);
  }

  size_t sid_buflen = 0;
  char sid_buf[20];

  // Copy the function name to allocated memory.
  // Accept <SID>name() inside a script, translate into <SNR>123_name().
  // Accept <SNR>123_name() outside a script.
  if (skip) {
    lead = 0;  // do nothing
  } else if (lead > 0) {
    lead = 3;
    if ((lv.ll_exp_name != NULL && eval_fname_sid(lv.ll_exp_name))
        || eval_fname_sid(*pp)) {
      // It's "s:" or "<SID>".
      if (current_sctx.sc_sid <= 0) {
        emsg(_(e_usingsid));
        goto theend;
      }
      sid_buflen = (size_t)snprintf(sid_buf, sizeof(sid_buf), "%" PRIdSCID "_",
                                    current_sctx.sc_sid);
      lead += (int)sid_buflen;
    }
  } else if (!(flags & TFN_INT) && builtin_function(lv.ll_name, (int)lv.ll_name_len)) {
    semsg(_("E128: Function name must start with a capital or \"s:\": %s"),
          start);
    goto theend;
  }

  if (!skip && !(flags & TFN_QUIET) && !(flags & TFN_NO_DEREF)) {
    char *cp = xmemrchr(lv.ll_name, ':', lv.ll_name_len);

    if (cp != NULL && cp < end) {
      semsg(_("E884: Function name cannot contain a colon: %s"), start);
      goto theend;
    }
  }

  name = xmalloc((size_t)len + (size_t)lead + 1);
  if (!skip && lead > 0) {
    name[0] = (char)K_SPECIAL;
    name[1] = (char)KS_EXTRA;
    name[2] = KE_SNR;
    if (sid_buflen > 0) {  // If it's "<SID>"
      memcpy(name + 3, sid_buf, sid_buflen);
    }
  }
  memmove(name + lead, lv.ll_name, (size_t)len);
  name[lead + len] = NUL;
  *pp = (char *)end;

theend:
  clear_lval(&lv);
  return name;
}

/// If the "funcname" starts with "s:" or "<SID>", then expands it to the
/// current script ID and returns the expanded function name. The caller should
/// free the returned name. If not called from a script context or the function
/// name doesn't start with these prefixes, then returns NULL.
/// This doesn't check whether the script-local function exists or not.
char *get_scriptlocal_funcname(char *funcname)
{
  if (funcname == NULL) {
    return NULL;
  }

  if (strncmp(funcname, "s:", 2) != 0
      && strncmp(funcname, "<SID>", 5) != 0) {
    // The function name does not have a script-local prefix.
    return NULL;
  }

  if (!SCRIPT_ID_VALID(current_sctx.sc_sid)) {
    emsg(_(e_usingsid));
    return NULL;
  }

  char sid_buf[25];
  // Expand s: and <SID> prefix into <SNR>nr_<name>
  size_t sid_buflen = (size_t)snprintf(sid_buf, sizeof(sid_buf), "<SNR>%" PRIdSCID "_",
                                       current_sctx.sc_sid);
  const int off = *funcname == 's' ? 2 : 5;
  size_t newnamesize = sid_buflen + strlen(funcname + off) + 1;
  char *newname = xmalloc(newnamesize);
  snprintf(newname, newnamesize, "%s%s", sid_buf, funcname + off);

  return newname;
}

/// Call trans_function_name(), except that a lambda is returned as-is.
/// Returns the name in allocated memory.
char *save_function_name(char **name, bool skip, int flags, funcdict_T *fudi)
{
  char *p = *name;
  char *saved;

  if (strncmp(p, "<lambda>", 8) == 0) {
    p += 8;
    getdigits(&p, false, 0);
    saved = xmemdupz(*name, (size_t)(p - *name));
    if (fudi != NULL) {
      CLEAR_POINTER(fudi);
    }
  } else {
    saved = trans_function_name(&p, skip, flags, fudi, NULL);
  }
  *name = p;
  return saved;
}

/// List functions.
///
/// @param regmatch  When NULL, all of them.
///                  Otherwise functions matching "regmatch".
static void list_functions(regmatch_T *regmatch)
{
  const int prev_ht_changed = func_hashtab.ht_changed;
  size_t todo = func_hashtab.ht_used;
  const hashitem_T *const ht_array = func_hashtab.ht_array;

  for (const hashitem_T *hi = ht_array; todo > 0 && !got_int; hi++) {
    if (!HASHITEM_EMPTY(hi)) {
      ufunc_T *fp = HI2UF(hi);
      todo--;
      if (regmatch == NULL
          ? (!message_filtered(fp->uf_name)
             && !func_name_refcount(fp->uf_name))
          : (!isdigit((uint8_t)(*fp->uf_name))
             && vim_regexec(regmatch, fp->uf_name, 0))) {
        if (list_func_head(fp, false, false) == FAIL) {
          return;
        }
        if (function_list_modified(prev_ht_changed)) {
          return;
        }
      }
    }
  }
}

#define MAX_FUNC_NESTING 50

/// Read the body of a function, put every line in "newlines".
/// This stops at "endfunction".
/// "newlines" must already have been initialized.
static int get_function_body(exarg_T *eap, garray_T *newlines, char *line_arg_in,
                             char **line_to_free, bool show_block)
{
  bool saved_wait_return = need_wait_return;
  char *line_arg = line_arg_in;
  int indent = 2;
  int nesting = 0;
  char *skip_until = NULL;
  int ret = FAIL;
  bool is_heredoc = false;
  char *heredoc_trimmed = NULL;
  size_t heredoc_trimmedlen = 0;
  bool do_concat = true;

  while (true) {
    if (KeyTyped) {
      msg_scroll = true;
      saved_wait_return = false;
    }
    need_wait_return = false;

    char *theline;
    char *p;
    char *arg;

    if (line_arg != NULL) {
      // Use eap->arg, split up in parts by line breaks.
      theline = line_arg;
      p = vim_strchr(theline, '\n');
      if (p == NULL) {
        line_arg += strlen(line_arg);
      } else {
        *p = NUL;
        line_arg = p + 1;
      }
    } else {
      xfree(*line_to_free);
      if (eap->ea_getline == NULL) {
        theline = getcmdline(':', 0, indent, do_concat);
      } else {
        theline = eap->ea_getline(':', eap->cookie, indent, do_concat);
      }
      *line_to_free = theline;
    }
    if (KeyTyped) {
      lines_left = Rows - 1;
    }
    if (theline == NULL) {
      if (skip_until != NULL) {
        semsg(_(e_missing_heredoc_end_marker_str), skip_until);
      } else {
        emsg(_("E126: Missing :endfunction"));
      }
      goto theend;
    }
    if (show_block) {
      assert(indent >= 0);
      ui_ext_cmdline_block_append((size_t)indent, theline);
    }

    // Detect line continuation: SOURCING_LNUM increased more than one.
    linenr_T sourcing_lnum_off = get_sourced_lnum(eap->ea_getline, eap->cookie);
    if (SOURCING_LNUM < sourcing_lnum_off) {
      sourcing_lnum_off -= SOURCING_LNUM;
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
          || strncmp(theline, heredoc_trimmed, heredoc_trimmedlen) == 0) {
        if (heredoc_trimmed == NULL) {
          p = theline;
        } else if (is_heredoc) {
          p = skipwhite(theline) == theline ? theline : theline + heredoc_trimmedlen;
        } else {
          p = theline + heredoc_trimmedlen;
        }
        if (strcmp(p, skip_until) == 0) {
          XFREE_CLEAR(skip_until);
          XFREE_CLEAR(heredoc_trimmed);
          heredoc_trimmedlen = 0;
          do_concat = true;
          is_heredoc = false;
        }
      }
    } else {
      // skip ':' and blanks
      for (p = theline; ascii_iswhite(*p) || *p == ':'; p++) {}

      // Check for "endfunction".
      if (checkforcmd(&p, "endfunction", 4) && nesting-- == 0) {
        if (*p == '!') {
          p++;
        }
        char *nextcmd = NULL;
        if (*p == '|') {
          nextcmd = p + 1;
        } else if (line_arg != NULL && *skipwhite(line_arg) != NUL) {
          nextcmd = line_arg;
        } else if (*p != NUL && *p != '"' && p_verbose > 0) {
          swmsg(true, _("W22: Text found after :endfunction: %s"), p);
        }
        if (nextcmd != NULL) {
          // Another command follows. If the line came from "eap" we
          // can simply point into it, otherwise we need to change
          // "eap->cmdlinep".
          eap->nextcmd = nextcmd;
          if (*line_to_free != NULL) {
            xfree(*eap->cmdlinep);
            *eap->cmdlinep = *line_to_free;
            *line_to_free = NULL;
          }
        }
        break;
      }

      // Increase indent inside "if", "while", "for" and "try", decrease
      // at "end".
      if (indent > 2 && strncmp(p, "end", 3) == 0) {
        indent -= 2;
      } else if (strncmp(p, "if", 2) == 0
                 || strncmp(p, "wh", 2) == 0
                 || strncmp(p, "for", 3) == 0
                 || strncmp(p, "try", 3) == 0) {
        indent += 2;
      }

      // Check for defining a function inside this function.
      if (checkforcmd(&p, "function", 2)) {
        if (*p == '!') {
          p = skipwhite(p + 1);
        }
        p += eval_fname_script(p);
        xfree(trans_function_name(&p, true, 0, NULL, NULL));
        if (*skipwhite(p) == '(') {
          if (nesting == MAX_FUNC_NESTING - 1) {
            emsg(_(e_function_nesting_too_deep));
          } else {
            nesting++;
            indent += 2;
          }
        }
      }

      // Check for ":append", ":change", ":insert".
      p = skip_range(p, NULL);
      if ((p[0] == 'a' && (!ASCII_ISALPHA(p[1]) || p[1] == 'p'))
          || (p[0] == 'c'
              && (!ASCII_ISALPHA(p[1])
                  || (p[1] == 'h' && (!ASCII_ISALPHA(p[2])
                                      || (p[2] == 'a'
                                          && (strncmp(&p[3], "nge", 3) != 0
                                              || !ASCII_ISALPHA(p[6])))))))
          || (p[0] == 'i'
              && (!ASCII_ISALPHA(p[1]) || (p[1] == 'n'
                                           && (!ASCII_ISALPHA(p[2])
                                               || (p[2] == 's')))))) {
        skip_until = xmemdupz(".", 1);
      }

      // heredoc: Check for ":python <<EOF", ":lua <<EOF", etc.
      arg = skipwhite(skiptowhite(p));
      if (arg[0] == '<' && arg[1] == '<'
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
                  && (!ASCII_ISALPHA(p[2]) || p[2] == 's')))) {
        // ":python <<" continues until a dot, like ":append"
        p = skipwhite(arg + 2);
        if (strncmp(p, "trim", 4) == 0
            && (p[4] == NUL || ascii_iswhite(p[4]))) {
          // Ignore leading white space.
          p = skipwhite(p + 4);
          heredoc_trimmedlen = (size_t)(skipwhite(theline) - theline);
          heredoc_trimmed = xmemdupz(theline, heredoc_trimmedlen);
        }
        if (*p == NUL) {
          skip_until = xmemdupz(".", 1);
        } else {
          skip_until = xmemdupz(p, (size_t)(skiptowhite(p) - p));
        }
        do_concat = false;
        is_heredoc = true;
      }

      if (!is_heredoc) {
        // Check for ":let v =<< [trim] EOF"
        //       and ":let [a, b] =<< [trim] EOF"
        arg = p;
        if (checkforcmd(&arg, "let", 2)) {
          int var_count = 0;
          int semicolon = 0;
          arg = (char *)skip_var_list(arg, &var_count, &semicolon, true);
          if (arg != NULL) {
            arg = skipwhite(arg);
          }
          if (arg != NULL && strncmp(arg, "=<<", 3) == 0) {
            p = skipwhite(arg + 3);
            bool has_trim = false;
            while (true) {
              if (strncmp(p, "trim", 4) == 0
                  && (p[4] == NUL || ascii_iswhite(p[4]))) {
                // Ignore leading white space.
                p = skipwhite(p + 4);
                has_trim = true;
                continue;
              }
              if (strncmp(p, "eval", 4) == 0
                  && (p[4] == NUL || ascii_iswhite(p[4]))) {
                // Ignore leading white space.
                p = skipwhite(p + 4);
                continue;
              }
              break;
            }
            if (has_trim) {
              heredoc_trimmedlen = (size_t)(skipwhite(theline) - theline);
              heredoc_trimmed = xmemdupz(theline, heredoc_trimmedlen);
            }
            skip_until = xmemdupz(p, (size_t)(skiptowhite(p) - p));
            do_concat = false;
            is_heredoc = true;
          }
        }
      }
    }

    // Add the line to the function.
    ga_grow(newlines, 1 + (int)sourcing_lnum_off);

    // Copy the line to newly allocated memory.  get_one_sourceline()
    // allocates 250 bytes per line, this saves 80% on average.  The cost
    // is an extra alloc/free.
    p = xstrdup(theline);
    ((char **)(newlines->ga_data))[newlines->ga_len++] = p;

    // Add NULL lines for continuation lines, so that the line count is
    // equal to the index in the growarray.
    while (sourcing_lnum_off-- > 0) {
      ((char **)(newlines->ga_data))[newlines->ga_len++] = NULL;
    }

    // Check for end of eap->arg.
    if (line_arg != NULL && *line_arg == NUL) {
      line_arg = NULL;
    }
  }

  // Return OK when no error was detected.
  if (!did_emsg) {
    ret = OK;
  }

theend:
  xfree(skip_until);
  xfree(heredoc_trimmed);
  need_wait_return |= saved_wait_return;
  return ret;
}

/// ":function"
void ex_function(exarg_T *eap)
{
  char *line_to_free = NULL;
  char *arg;
  char *line_arg = NULL;
  garray_T newargs;
  garray_T default_args;
  garray_T newlines;
  int varargs = false;
  int flags = 0;
  ufunc_T *fp = NULL;
  bool free_fp = false;
  bool overwrite = false;
  funcdict_T fudi;
  static int func_nr = 0;           // number for nameless function
  hashtab_T *ht;
  bool show_block = false;

  // ":function" without argument: list functions.
  if (ends_excmd(*eap->arg)) {
    if (!eap->skip) {
      list_functions(NULL);
    }
    eap->nextcmd = check_nextcmd(eap->arg);
    return;
  }

  // ":function /pat": list functions matching pattern.
  if (*eap->arg == '/') {
    char *p = skip_regexp(eap->arg + 1, '/', true);
    if (!eap->skip) {
      regmatch_T regmatch;

      char c = *p;
      *p = NUL;
      regmatch.regprog = vim_regcomp(eap->arg + 1, RE_MAGIC);
      *p = c;
      if (regmatch.regprog != NULL) {
        regmatch.rm_ic = p_ic;
        list_functions(&regmatch);
        vim_regfree(regmatch.regprog);
      }
    }
    if (*p == '/') {
      p++;
    }
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
  char *p = eap->arg;
  char *name = save_function_name(&p, eap->skip, TFN_NO_AUTOLOAD, &fudi);
  int paren = (vim_strchr(p, '(') != NULL);
  if (name == NULL && (fudi.fd_dict == NULL || !paren) && !eap->skip) {
    // Return on an invalid expression in braces, unless the expression
    // evaluation has been cancelled due to an aborting error, an
    // interrupt, or an exception.
    if (!aborting()) {
      if (fudi.fd_newkey != NULL) {
        semsg(_(e_dictkey), fudi.fd_newkey);
      }
      xfree(fudi.fd_newkey);
      return;
    }
    eap->skip = true;
  }

  // An error in a function call during evaluation of an expression in magic
  // braces should not cause the function not to be defined.
  const int saved_did_emsg = did_emsg;
  did_emsg = false;

  //
  // ":function func" with only function name: list function.
  // If bang is given:
  //  - include "!" in function head
  //  - exclude line numbers from function body
  //
  if (!paren) {
    if (!ends_excmd(*skipwhite(p))) {
      semsg(_(e_trailing_arg), p);
      goto ret_free;
    }
    eap->nextcmd = check_nextcmd(p);
    if (eap->nextcmd != NULL) {
      *p = NUL;
    }
    if (!eap->skip && !got_int) {
      fp = find_func(name);
      if (fp != NULL) {
        // Check no function was added or removed from a callback, e.g. at
        // the more prompt.  "fp" may then be invalid.
        const int prev_ht_changed = func_hashtab.ht_changed;

        if (list_func_head(fp, !eap->forceit, eap->forceit) == OK) {
          for (int j = 0; j < fp->uf_lines.ga_len && !got_int; j++) {
            if (FUNCLINE(fp, j) == NULL) {
              continue;
            }
            msg_putchar('\n');
            if (!eap->forceit) {
              msg_outnum(j + 1);
              if (j < 9) {
                msg_putchar(' ');
              }
              if (j < 99) {
                msg_putchar(' ');
              }
              if (function_list_modified(prev_ht_changed)) {
                break;
              }
            }
            msg_prt_line(FUNCLINE(fp, j), false);
            line_breakcheck();  // show multiple lines at a time!
          }
          if (!got_int) {
            msg_putchar('\n');
            if (!function_list_modified(prev_ht_changed)) {
              msg_puts(eap->forceit ? "endfunction" : "   endfunction");
            }
          }
        }
      } else {
        emsg_funcname(N_("E123: Undefined function: %s"), name);
      }
    }
    goto ret_free;
  }

  // ":function name(arg1, arg2)" Define function.
  p = skipwhite(p);
  if (*p != '(') {
    if (!eap->skip) {
      semsg(_("E124: Missing '(': %s"), eap->arg);
      goto ret_free;
    }
    // attempt to continue by skipping some text
    if (vim_strchr(p, '(') != NULL) {
      p = vim_strchr(p, '(');
    }
  }
  p = skipwhite(p + 1);

  ga_init(&newargs, (int)sizeof(char *), 3);
  ga_init(&newlines, (int)sizeof(char *), 3);

  if (!eap->skip) {
    // Check the name of the function.  Unless it's a dictionary function
    // (that we are overwriting).
    if (name != NULL) {
      arg = name;
    } else {
      arg = fudi.fd_newkey;
    }
    if (arg != NULL && (fudi.fd_di == NULL || !tv_is_func(fudi.fd_di->di_tv))) {
      char *name_base = arg;
      if ((uint8_t)(*arg) == K_SPECIAL) {
        name_base = vim_strchr(arg, '_');
        if (name_base == NULL) {
          name_base = arg + 3;
        } else {
          name_base++;
        }
      }
      int i;
      for (i = 0; name_base[i] != NUL && (i == 0
                                          ? eval_isnamec1(name_base[i])
                                          : eval_isnamec(name_base[i])); i++) {}
      if (name_base[i] != NUL) {
        emsg_funcname(e_invarg2, arg);
        goto ret_free;
      }
    }
    // Disallow using the g: dict.
    if (fudi.fd_dict != NULL && fudi.fd_dict->dv_scope == VAR_DEF_SCOPE) {
      emsg(_("E862: Cannot use g: here"));
      goto ret_free;
    }
  }

  if (get_function_args(&p, ')', &newargs, &varargs,
                        &default_args, eap->skip) == FAIL) {
    goto errret_2;
  }

  if (KeyTyped && ui_has(kUICmdline)) {
    show_block = true;
    ui_ext_cmdline_block_append(0, eap->cmd);
  }

  // find extra arguments "range", "dict", "abort" and "closure"
  while (true) {
    p = skipwhite(p);
    if (strncmp(p, "range", 5) == 0) {
      flags |= FC_RANGE;
      p += 5;
    } else if (strncmp(p, "dict", 4) == 0) {
      flags |= FC_DICT;
      p += 4;
    } else if (strncmp(p, "abort", 5) == 0) {
      flags |= FC_ABORT;
      p += 5;
    } else if (strncmp(p, "closure", 7) == 0) {
      flags |= FC_CLOSURE;
      p += 7;
      if (current_funccal == NULL) {
        emsg_funcname(N_("E932: Closure function should not be at top level: %s"),
                      name == NULL ? "" : name);
        goto erret;
      }
    } else {
      break;
    }
  }

  // When there is a line break use what follows for the function body.
  // Makes 'exe "func Test()\n...\nendfunc"' work.
  if (*p == '\n') {
    line_arg = p + 1;
  } else if (*p != NUL && *p != '"' && !eap->skip && !did_emsg) {
    semsg(_(e_trailing_arg), p);
  }

  // Read the body of the function, until ":endfunction" is found.
  if (KeyTyped) {
    // Check if the function already exists, don't let the user type the
    // whole function before telling them it doesn't work!  For a script we
    // need to skip the body to be able to find what follows.
    if (!eap->skip && !eap->forceit) {
      if (fudi.fd_dict != NULL && fudi.fd_newkey == NULL) {
        emsg(_(e_funcdict));
      } else if (name != NULL && find_func(name) != NULL) {
        emsg_funcname(e_funcexts, name);
      }
    }

    if (!eap->skip && did_emsg) {
      goto erret;
    }

    if (!ui_has(kUICmdline)) {
      msg_putchar('\n');              // don't overwrite the function name
    }
    cmdline_row = msg_row;
  }

  // Save the starting line number.
  linenr_T sourcing_lnum_top = SOURCING_LNUM;

  // Do not define the function when getting the body fails and when skipping.
  if (get_function_body(eap, &newlines, line_arg, &line_to_free, show_block) == FAIL
      || eap->skip) {
    goto erret;
  }

  // If there are no errors, add the function
  size_t namelen = 0;
  if (fudi.fd_dict == NULL) {
    dictitem_T *v = find_var(name, strlen(name), &ht, false);
    if (v != NULL && v->di_tv.v_type == VAR_FUNC) {
      emsg_funcname(N_("E707: Function name conflicts with variable: %s"), name);
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
        goto errret_keep;
      }
      if (fp->uf_calls > 0) {
        emsg_funcname(N_("E127: Cannot redefine function %s: It is in use"), name);
        goto errret_keep;
      }
      if (fp->uf_refcount > 1) {
        // This function is referenced somewhere, don't redefine it but
        // create a new one.
        (fp->uf_refcount)--;
        fp->uf_flags |= FC_REMOVED;
        fp = NULL;
        overwrite = true;
      } else {
        char *exp_name = fp->uf_name_exp;
        // redefine existing function, keep the expanded name
        XFREE_CLEAR(name);
        fp->uf_name_exp = NULL;
        func_clear_items(fp);
        fp->uf_name_exp = exp_name;
        fp->uf_profiling = false;
        fp->uf_prof_initialized = false;
      }
    }
  } else {
    char numbuf[NUMBUFLEN];

    fp = NULL;
    if (fudi.fd_newkey == NULL && !eap->forceit) {
      emsg(_(e_funcdict));
      goto erret;
    }
    if (fudi.fd_di == NULL) {
      if (value_check_lock(fudi.fd_dict->dv_lock, eap->arg, TV_CSTRING)) {
        // Can't add a function to a locked dictionary
        goto erret;
      }
    } else if (value_check_lock(fudi.fd_di->di_tv.v_lock, eap->arg, TV_CSTRING)) {
      // Can't change an existing function if it is locked
      goto erret;
    }

    // Give the function a sequential number.  Can only be used with a
    // Funcref!
    xfree(name);
    namelen = (size_t)snprintf(numbuf, sizeof(numbuf), "%d", ++func_nr);
    name = xmemdupz(numbuf, namelen);
  }

  if (fp == NULL) {
    if (fudi.fd_dict == NULL && vim_strchr(name, AUTOLOAD_CHAR) != NULL) {
      // Check that the autoload name matches the script name.
      int j = FAIL;
      if (SOURCING_NAME != NULL) {
        char *scriptname = autoload_name(name, strlen(name));
        p = vim_strchr(scriptname, '/');
        int plen = (int)strlen(p);
        int slen = (int)strlen(SOURCING_NAME);
        if (slen > plen && path_fnamecmp(p, SOURCING_NAME + slen - plen) == 0) {
          j = OK;
        }
        xfree(scriptname);
      }
      if (j == FAIL) {
        semsg(_("E746: Function name does not match script file name: %s"),
              name);
        goto erret;
      }
    }

    if (namelen == 0) {
      namelen = strlen(name);
    }
    fp = alloc_ufunc(name, namelen);

    if (fudi.fd_dict != NULL) {
      if (fudi.fd_di == NULL) {
        // Add new dict entry
        fudi.fd_di = tv_dict_item_alloc(fudi.fd_newkey);
        if (tv_dict_add(fudi.fd_dict, fudi.fd_di) == FAIL) {
          xfree(fudi.fd_di);
          XFREE_CLEAR(fp);
          goto erret;
        }
      } else {
        // Overwrite existing dict entry.
        tv_clear(&fudi.fd_di->di_tv);
      }
      fudi.fd_di->di_tv.v_type = VAR_FUNC;
      fudi.fd_di->di_tv.vval.v_string = xmemdupz(name, namelen);

      // behave like "dict" was used
      flags |= FC_DICT;
    }

    // insert the new function in the function list
    if (overwrite) {
      hashitem_T *hi = hash_find(&func_hashtab, name);
      hi->hi_key = UF2HIKEY(fp);
    } else if (hash_add(&func_hashtab, UF2HIKEY(fp)) == FAIL) {
      free_fp = true;
      goto erret;
    }
    fp->uf_refcount = 1;
  }
  fp->uf_args = newargs;
  fp->uf_def_args = default_args;
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
  nlua_set_sctx(&fp->uf_script_ctx);

  goto ret_free;

erret:
  if (fp != NULL) {
    // these were set to "newargs" and "default_args", which are cleared below
    ga_init(&fp->uf_args, (int)sizeof(char *), 1);
    ga_init(&fp->uf_def_args, (int)sizeof(char *), 1);
  }
errret_2:
  if (fp != NULL) {
    XFREE_CLEAR(fp->uf_name_exp);
  }
  if (free_fp) {
    XFREE_CLEAR(fp);
  }
errret_keep:
  ga_clear_strings(&newargs);
  ga_clear_strings(&default_args);
  ga_clear_strings(&newlines);
ret_free:
  xfree(line_to_free);
  xfree(fudi.fd_newkey);
  xfree(name);
  did_emsg |= saved_did_emsg;
  if (show_block) {
    ui_ext_cmdline_block_leave();
  }
}

/// @return  5 if "p" starts with "<SID>" or "<SNR>" (ignoring case).
///          2 if "p" starts with "s:".
///          0 otherwise.
int eval_fname_script(const char *const p)
{
  // Use mb_strnicmp() because in Turkish comparing the "I" may not work with
  // the standard library function.
  if (p[0] == '<'
      && (mb_strnicmp(p + 1, "SID>", 4) == 0
          || mb_strnicmp(p + 1, "SNR>", 4) == 0)) {
    return 5;
  }
  if (p[0] == 's' && p[1] == ':') {
    return 2;
  }
  return 0;
}

bool translated_function_exists(const char *name)
{
  if (builtin_function(name, -1)) {
    return find_internal_func(name) != NULL;
  }
  return find_func(name) != NULL;
}

/// Check whether function with the given name exists
///
/// @param[in] name  Function name.
/// @param[in] no_deref  Whether to dereference a Funcref.
///
/// @return  true if it exists, false otherwise.
bool function_exists(const char *const name, bool no_deref)
{
  const char *nm = name;
  bool n = false;
  int flag = TFN_INT | TFN_QUIET | TFN_NO_AUTOLOAD;

  if (no_deref) {
    flag |= TFN_NO_DEREF;
  }
  char *const p = trans_function_name((char **)&nm, false, flag, NULL, NULL);
  nm = skipwhite(nm);

  // Only accept "funcname", "funcname ", "funcname (..." and
  // "funcname(...", not "funcname!...".
  if (p != NULL && (*nm == NUL || *nm == '(')) {
    n = translated_function_exists(p);
  }
  xfree(p);
  return n;
}

/// Function given to ExpandGeneric() to obtain the list of user defined
/// function names.
char *get_user_func_name(expand_T *xp, int idx)
{
  static size_t done;
  static int changed;
  static hashitem_T *hi;

  if (idx == 0) {
    done = 0;
    hi = func_hashtab.ht_array;
    changed = func_hashtab.ht_changed;
  }
  assert(hi);
  if (changed == func_hashtab.ht_changed && done < func_hashtab.ht_used) {
    if (done++ > 0) {
      hi++;
    }
    while (HASHITEM_EMPTY(hi)) {
      hi++;
    }
    ufunc_T *fp = HI2UF(hi);

    if ((fp->uf_flags & FC_DICT)
        || strncmp(fp->uf_name, "<lambda>", 8) == 0) {
      return "";       // don't show dict and lambda functions
    }

    if (fp->uf_namelen + 4 >= IOSIZE) {
      return fp->uf_name;  // Prevent overflow.
    }

    int len = cat_func_name(IObuff, IOSIZE, fp);
    if (xp->xp_context != EXPAND_USER_FUNC) {
      xstrlcpy(IObuff + len, "(", IOSIZE - (size_t)len);
      if (!fp->uf_varargs && GA_EMPTY(&fp->uf_args)) {
        len++;
        xstrlcpy(IObuff + len, ")", IOSIZE - (size_t)len);
      }
    }
    return IObuff;
  }
  return NULL;
}

/// ":delfunction {name}"
void ex_delfunction(exarg_T *eap)
{
  ufunc_T *fp = NULL;
  funcdict_T fudi;

  char *p = eap->arg;
  char *name = trans_function_name(&p, eap->skip, 0, &fudi, NULL);
  xfree(fudi.fd_newkey);
  if (name == NULL) {
    if (fudi.fd_dict != NULL && !eap->skip) {
      emsg(_(e_funcref));
    }
    return;
  }
  if (!ends_excmd(*skipwhite(p))) {
    xfree(name);
    semsg(_(e_trailing_arg), p);
    return;
  }
  eap->nextcmd = check_nextcmd(p);
  if (eap->nextcmd != NULL) {
    *p = NUL;
  }

  if (isdigit((uint8_t)(*name)) && fudi.fd_dict == NULL) {
    if (!eap->skip) {
      semsg(_(e_invarg2), eap->arg);
    }
    xfree(name);
    return;
  }
  if (!eap->skip) {
    fp = find_func(name);
  }
  xfree(name);

  if (!eap->skip) {
    if (fp == NULL) {
      if (!eap->forceit) {
        semsg(_(e_nofunc), eap->arg);
      }
      return;
    }
    if (fp->uf_calls > 0) {
      semsg(_("E131: Cannot delete function %s: It is in use"), eap->arg);
      return;
    }
    // check `uf_refcount > 2` because deleting a function should also reduce
    // the reference count, and 1 is the initial refcount.
    if (fp->uf_refcount > 2) {
      semsg(_("Cannot delete function %s: It is being used internally"),
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

/// Unreference a Function: decrement the reference count and free it when it
/// becomes zero.
void func_unref(char *name)
{
  if (name == NULL || !func_name_refcount(name)) {
    return;
  }

  ufunc_T *fp = find_func(name);
  if (fp == NULL && isdigit((uint8_t)(*name))) {
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
void func_ref(char *name)
{
  if (name == NULL || !func_name_refcount(name)) {
    return;
  }
  ufunc_T *fp = find_func(name);
  if (fp != NULL) {
    (fp->uf_refcount)++;
  } else if (isdigit((uint8_t)(*name))) {
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
  return ((fc->fc_l_varlist.lv_refcount  // NOLINT(runtime/deprecated)
           != DO_NOT_FREE_CNT)
          || fc->fc_l_vars.dv_refcount != DO_NOT_FREE_CNT
          || fc->fc_l_avars.dv_refcount != DO_NOT_FREE_CNT
          || fc->fc_refcount > 0);
}

/// @return true if items in "fc" do not have "copyID".  That means they are not
/// referenced from anywhere that is in use.
static bool can_free_funccal(funccall_T *fc, int copyID)
{
  return fc->fc_l_varlist.lv_copyID != copyID
         && fc->fc_l_vars.dv_copyID != copyID
         && fc->fc_l_avars.dv_copyID != copyID
         && fc->fc_copyID != copyID;
}

/// ":return [expr]"
void ex_return(exarg_T *eap)
{
  char *arg = eap->arg;
  typval_T rettv;
  bool returning = false;

  if (current_funccal == NULL) {
    emsg(_("E133: :return not inside a function"));
    return;
  }

  evalarg_T evalarg = { .eval_flags = eap->skip ? 0 : EVAL_EVALUATE };

  if (eap->skip) {
    emsg_skip++;
  }

  eap->nextcmd = NULL;
  if ((*arg != NUL && *arg != '|' && *arg != '\n')
      && eval0(arg, &rettv, eap, &evalarg) != FAIL) {
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

  // When skipping or the return gets pending, advance to the next command
  // in this line (!returning).  Otherwise, ignore the rest of the line.
  // Following lines will be ignored by get_func_line().
  if (returning) {
    eap->nextcmd = NULL;
  } else if (eap->nextcmd == NULL) {          // no argument
    eap->nextcmd = check_nextcmd(arg);
  }

  if (eap->skip) {
    emsg_skip--;
  }
  clear_evalarg(&evalarg, eap);
}

/// Lower level implementation of "call".  Only called when not skipping.
static int ex_call_inner(exarg_T *eap, char *name, char **arg, char *startarg,
                         const funcexe_T *const funcexe_init, evalarg_T *const evalarg)
{
  bool doesrange;
  bool failed = false;

  for (linenr_T lnum = eap->line1; lnum <= eap->line2; lnum++) {
    if (eap->addr_count > 0) {
      if (lnum > curbuf->b_ml.ml_line_count) {
        // If the function deleted lines or switched to another buffer
        // the line number may become invalid.
        emsg(_(e_invrange));
        break;
      }
      curwin->w_cursor.lnum = lnum;
      curwin->w_cursor.col = 0;
      curwin->w_cursor.coladd = 0;
    }
    *arg = startarg;

    funcexe_T funcexe = *funcexe_init;
    funcexe.fe_doesrange = &doesrange;
    typval_T rettv;
    rettv.v_type = VAR_UNKNOWN;  // tv_clear() uses this
    if (get_func_tv(name, -1, &rettv, arg, evalarg, &funcexe) == FAIL) {
      failed = true;
      break;
    }

    // Handle a function returning a Funcref, Dict or List.
    if (handle_subscript((const char **)arg, &rettv, &EVALARG_EVALUATE, true) == FAIL) {
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

  return failed;
}

/// Core part of ":defer func(arg)".  "arg" points to the "(" and is advanced.
///
/// @return  FAIL or OK.
static int ex_defer_inner(char *name, char **arg, const partial_T *const partial,
                          evalarg_T *const evalarg)
{
  typval_T argvars[MAX_FUNC_ARGS + 1];  // vars for arguments
  int partial_argc = 0;  // number of partial arguments
  int argcount = 0;  // number of arguments found

  if (current_funccal == NULL) {
    semsg(_(e_str_not_inside_function), "defer");
    return FAIL;
  }
  if (partial != NULL) {
    if (partial->pt_dict != NULL) {
      emsg(_(e_cannot_use_partial_with_dictionary_for_defer));
      return FAIL;
    }
    if (partial->pt_argc > 0) {
      partial_argc = partial->pt_argc;
      for (int i = 0; i < partial_argc; i++) {
        tv_copy(&partial->pt_argv[i], &argvars[i]);
      }
    }
  }
  int r = get_func_arguments(arg, evalarg, false, argvars + partial_argc, &argcount);
  argcount += partial_argc;

  if (r == OK) {
    if (builtin_function(name, -1)) {
      const EvalFuncDef *const fdef = find_internal_func(name);
      if (fdef == NULL) {
        emsg_funcname(e_unknown_function_str, name);
        r = FAIL;
      } else if (check_internal_func(fdef, argcount) == -1) {
        r = FAIL;
      }
    } else {
      ufunc_T *ufunc = find_func(name);
      // we tolerate an unknown function here, it might be defined later
      if (ufunc != NULL) {
        int error = check_user_func_argcount(ufunc, argcount);
        if (error != FCERR_UNKNOWN) {
          user_func_error(error, name, false);
          r = FAIL;
        }
      }
    }
  }

  if (r == FAIL) {
    while (--argcount >= 0) {
      tv_clear(&argvars[argcount]);
    }
    return FAIL;
  }
  add_defer(name, argcount, argvars);
  return OK;
}

/// Return true if currently inside a function call.
/// Give an error message and return false when not.
bool can_add_defer(void)
{
  if (get_current_funccal() == NULL) {
    semsg(_(e_str_not_inside_function), "defer");
    return false;
  }
  return true;
}

/// Add a deferred call for "name" with arguments "argvars[argcount]".
/// Consumes "argvars[]".
/// Caller must check that current_funccal is not NULL.
void add_defer(char *name, int argcount_arg, typval_T *argvars)
{
  char *saved_name = xstrdup(name);
  int argcount = argcount_arg;

  if (current_funccal->fc_defer.ga_itemsize == 0) {
    ga_init(&current_funccal->fc_defer, sizeof(defer_T), 10);
  }
  defer_T *dr = GA_APPEND_VIA_PTR(defer_T, &current_funccal->fc_defer);
  dr->dr_name = saved_name;
  dr->dr_argcount = argcount;
  while (argcount > 0) {
    argcount--;
    dr->dr_argvars[argcount] = argvars[argcount];
  }
}

/// Invoked after a function has finished: invoke ":defer" functions.
static void handle_defer_one(funccall_T *funccal)
{
  for (int idx = funccal->fc_defer.ga_len - 1; idx >= 0; idx--) {
    defer_T *dr = ((defer_T *)funccal->fc_defer.ga_data) + idx;

    if (dr->dr_name == NULL) {
      // already being called, can happen if function does ":qa"
      continue;
    }

    funcexe_T funcexe = { .fe_evaluate = true };

    typval_T rettv;
    rettv.v_type = VAR_UNKNOWN;     // tv_clear() uses this

    char *name = dr->dr_name;
    dr->dr_name = NULL;

    // If the deferred function is called after an exception, then only the
    // first statement in the function will be executed (because of the
    // exception).  So save and restore the try/catch/throw exception
    // state.
    exception_state_T estate;
    exception_state_save(&estate);
    exception_state_clear();

    call_func(name, -1, &rettv, dr->dr_argcount, dr->dr_argvars, &funcexe);

    exception_state_restore(&estate);

    tv_clear(&rettv);
    xfree(name);
    for (int i = dr->dr_argcount - 1; i >= 0; i--) {
      tv_clear(&dr->dr_argvars[i]);
    }
  }
  ga_clear(&funccal->fc_defer);
}

/// Called when exiting: call all defer functions.
void invoke_all_defer(void)
{
  for (funccall_T *fc = current_funccal; fc != NULL; fc = fc->fc_caller) {
    handle_defer_one(fc);
  }

  for (funccal_entry_T *fce = funccal_stack; fce != NULL; fce = fce->next) {
    for (funccall_T *fc = fce->top_funccal; fc != NULL; fc = fc->fc_caller) {
      handle_defer_one(fc);
    }
  }
}

/// ":1,25call func(arg1, arg2)" function call.
/// ":defer func(arg1, arg2)"    deferred function call.
void ex_call(exarg_T *eap)
{
  char *arg = eap->arg;
  bool failed = false;
  funcdict_T fudi;
  partial_T *partial = NULL;
  evalarg_T evalarg;

  fill_evalarg_from_eap(&evalarg, eap, eap->skip);
  if (eap->skip) {
    typval_T rettv;
    // trans_function_name() doesn't work well when skipping, use eval0()
    // instead to skip to any following command, e.g. for:
    //   :if 0 | call dict.foo().bar() | endif.
    emsg_skip++;
    if (eval0(eap->arg, &rettv, eap, &evalarg) != FAIL) {
      tv_clear(&rettv);
    }
    emsg_skip--;
    clear_evalarg(&evalarg, eap);
    return;
  }

  char *tofree = trans_function_name(&arg, false, TFN_INT, &fudi, &partial);
  if (fudi.fd_newkey != NULL) {
    // Still need to give an error message for missing key.
    semsg(_(e_dictkey), fudi.fd_newkey);
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
  int len = (int)strlen(tofree);
  bool found_var = false;
  char *name = deref_func_name(tofree, &len, partial != NULL ? NULL : &partial, false, &found_var);

  // Skip white space to allow ":call func ()".  Not good, but required for
  // backward compatibility.
  char *startarg = skipwhite(arg);

  if (*startarg != '(') {
    semsg(_(e_missingparen), eap->arg);
    goto end;
  }

  if (eap->cmdidx == CMD_defer) {
    arg = startarg;
    failed = ex_defer_inner(name, &arg, partial, &evalarg) == FAIL;
  } else {
    funcexe_T funcexe = FUNCEXE_INIT;
    funcexe.fe_partial = partial;
    funcexe.fe_selfdict = fudi.fd_dict;
    funcexe.fe_firstline = eap->line1;
    funcexe.fe_lastline = eap->line2;
    funcexe.fe_found_var = found_var;
    funcexe.fe_evaluate = true;
    failed = ex_call_inner(eap, name, &arg, startarg, &funcexe, &evalarg);
  }

  // When inside :try we need to check for following "| catch" or "| endtry".
  // Not when there was an error, but do check if an exception was thrown.
  if ((!aborting() || did_throw) && (!failed || eap->cstack->cs_trylevel > 0)) {
    // Check for trailing illegal characters and a following command.
    if (!ends_excmd(*arg)) {
      if (!failed && !aborting()) {
        emsg_severe = true;
        semsg(_(e_trailing_arg), arg);
      }
    } else {
      eap->nextcmd = check_nextcmd(arg);
    }
  }
  clear_evalarg(&evalarg, eap);

end:
  tv_dict_unref(fudi.fd_dict);
  xfree(tofree);
}

/// Return from a function.  Possibly makes the return pending.  Also called
/// for a pending return at the ":endtry" or after returning from an extra
/// do_cmdline().  "reanimate" is used in the latter case.
///
/// @param reanimate  used after returning from an extra do_cmdline().
/// @param is_cmd     set when called due to a ":return" command.
/// @param rettv      may point to a typval_T with the return rettv.
///
/// @return  true when the return can be carried out,
///          false when the return gets pending.
bool do_return(exarg_T *eap, bool reanimate, bool is_cmd, void *rettv)
{
  cstack_T *const cstack = eap->cstack;

  if (reanimate) {
    // Undo the return.
    current_funccal->fc_returned = false;
  }

  // Cleanup (and deactivate) conditionals, but stop when a try conditional
  // not in its finally clause (which then is to be executed next) is found.
  // In this case, make the ":return" pending for execution at the ":endtry".
  // Otherwise, return normally.
  int idx = cleanup_conditionals(eap->cstack, 0, true);
  if (idx >= 0) {
    cstack->cs_pending[idx] = CSTP_RETURN;

    if (!is_cmd && !reanimate) {
      // A pending return again gets pending.  "rettv" points to an
      // allocated variable with the rettv of the original ":return"'s
      // argument if present or is NULL else.
      cstack->cs_rettv[idx] = rettv;
    } else {
      // When undoing a return in order to make it pending, get the stored
      // return rettv.
      if (reanimate) {
        assert(current_funccal->fc_rettv);
        rettv = current_funccal->fc_rettv;
      }

      if (rettv != NULL) {
        // Store the value of the pending return.
        cstack->cs_rettv[idx] = xcalloc(1, sizeof(typval_T));
        *(typval_T *)cstack->cs_rettv[idx] = *(typval_T *)rettv;
      } else {
        cstack->cs_rettv[idx] = NULL;
      }

      if (reanimate) {
        // The pending return value could be overwritten by a ":return"
        // without argument in a finally clause; reset the default
        // return value.
        current_funccal->fc_rettv->v_type = VAR_NUMBER;
        current_funccal->fc_rettv->vval.v_number = 0;
      }
    }
    report_make_pending(CSTP_RETURN, rettv);
  } else {
    current_funccal->fc_returned = true;

    // If the return is carried out now, store the return value.  For
    // a return immediately after reanimation, the value is already
    // there.
    if (!reanimate && rettv != NULL) {
      tv_clear(current_funccal->fc_rettv);
      *current_funccal->fc_rettv = *(typval_T *)rettv;
      if (!is_cmd) {
        xfree(rettv);
      }
    }
  }

  return idx < 0;
}

/// Generate a return command for producing the value of "rettv".  The result
/// is an allocated string.  Used by report_pending() for verbose messages.
char *get_return_cmd(void *rettv)
{
  char *s = NULL;
  char *tofree = NULL;
  size_t slen = 0;

  if (rettv != NULL) {
    tofree = s = encode_tv2echo((typval_T *)rettv, NULL);
  }
  if (s == NULL) {
    s = "";
  } else {
    slen = strlen(s);
  }

  xstrlcpy(IObuff, ":return ", IOSIZE);
  xstrlcpy(IObuff + 8, s, IOSIZE - 8);
  size_t IObufflen = 8 + slen;
  if (IObufflen >= IOSIZE) {
    STRCPY(IObuff + IOSIZE - 4, "...");
    IObufflen = IOSIZE - 1;
  }
  xfree(tofree);
  return xstrnsave(IObuff, IObufflen);
}

/// Get next function line.
/// Called by do_cmdline() to get the next line.
///
/// @return  allocated string, or NULL for end of function.
char *get_func_line(int c, void *cookie, int indent, bool do_concat)
{
  funccall_T *fcp = (funccall_T *)cookie;
  ufunc_T *fp = fcp->fc_func;
  char *retval;

  // If breakpoints have been added/deleted need to check for it.
  if (fcp->fc_dbg_tick != debug_tick) {
    fcp->fc_breakpoint = dbg_find_breakpoint(false, fp->uf_name, SOURCING_LNUM);
    fcp->fc_dbg_tick = debug_tick;
  }
  if (do_profiling == PROF_YES) {
    func_line_end(cookie);
  }

  garray_T *gap = &fp->uf_lines;  // growarray with function lines
  if (((fp->uf_flags & FC_ABORT) && did_emsg && !aborted_in_try())
      || fcp->fc_returned) {
    retval = NULL;
  } else {
    // Skip NULL lines (continuation lines).
    while (fcp->fc_linenr < gap->ga_len
           && ((char **)(gap->ga_data))[fcp->fc_linenr] == NULL) {
      fcp->fc_linenr++;
    }
    if (fcp->fc_linenr >= gap->ga_len) {
      retval = NULL;
    } else {
      retval = xstrdup(((char **)(gap->ga_data))[fcp->fc_linenr++]);
      SOURCING_LNUM = fcp->fc_linenr;
      if (do_profiling == PROF_YES) {
        func_line_start(cookie);
      }
    }
  }

  // Did we encounter a breakpoint?
  if (fcp->fc_breakpoint != 0 && fcp->fc_breakpoint <= SOURCING_LNUM) {
    dbg_breakpoint(fp->uf_name, SOURCING_LNUM);
    // Find next breakpoint.
    fcp->fc_breakpoint = dbg_find_breakpoint(false, fp->uf_name, SOURCING_LNUM);
    fcp->fc_dbg_tick = debug_tick;
  }

  return retval;
}

/// @return  true if the currently active function should be ended, because a
///          return was encountered or an error occurred.  Used inside a ":while".
int func_has_ended(void *cookie)
{
  funccall_T *fcp = (funccall_T *)cookie;

  // Ignore the "abort" flag if the abortion behavior has been changed due to
  // an error inside a try conditional.
  return ((fcp->fc_func->uf_flags & FC_ABORT) && did_emsg && !aborted_in_try())
         || fcp->fc_returned;
}

/// @return  true if cookie indicates a function which "abort"s on errors.
int func_has_abort(void *cookie)
{
  return ((funccall_T *)cookie)->fc_func->uf_flags & FC_ABORT;
}

/// Turn "dict.Func" into a partial for "Func" bound to "dict".
/// Changes "rettv" in-place.
void make_partial(dict_T *const selfdict, typval_T *const rettv)
{
  char *tofree = NULL;
  ufunc_T *fp;
  char fname_buf[FLEN_FIXED + 1];
  int error;

  if (rettv->v_type == VAR_PARTIAL && rettv->vval.v_partial->pt_func != NULL) {
    fp = rettv->vval.v_partial->pt_func;
  } else {
    char *fname = rettv->v_type == VAR_FUNC || rettv->v_type == VAR_STRING
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

      // Partial: copy the function name, use selfdict and copy
      // args. Can't take over name or args, the partial might
      // be referenced elsewhere.
      if (ret_pt->pt_name != NULL) {
        pt->pt_name = xstrdup(ret_pt->pt_name);
        func_ref(pt->pt_name);
      } else {
        pt->pt_func = ret_pt->pt_func;
        func_ptr_ref(pt->pt_func);
      }
      if (ret_pt->pt_argc > 0) {
        size_t arg_size = sizeof(typval_T) * (size_t)ret_pt->pt_argc;
        pt->pt_argv = (typval_T *)xmalloc(arg_size);
        pt->pt_argc = ret_pt->pt_argc;
        for (int i = 0; i < pt->pt_argc; i++) {
          tv_copy(&ret_pt->pt_argv[i], &pt->pt_argv[i]);
        }
      }
      partial_unref(ret_pt);
    }
    rettv->v_type = VAR_PARTIAL;
    rettv->vval.v_partial = pt;
  }
}

/// @return  the name of the executed function.
char *func_name(void *cookie)
{
  return ((funccall_T *)cookie)->fc_func->uf_name;
}

/// @return  the address holding the next breakpoint line for a funccall cookie.
linenr_T *func_breakpoint(void *cookie)
{
  return &((funccall_T *)cookie)->fc_breakpoint;
}

/// @return  the address holding the debug tick for a funccall cookie.
int *func_dbg_tick(void *cookie)
{
  return &((funccall_T *)cookie)->fc_dbg_tick;
}

/// @return  the nesting level for a funccall cookie.
int func_level(void *cookie)
{
  return ((funccall_T *)cookie)->fc_level;
}

/// @return  true when a function was ended by a ":return" command.
int current_func_returned(void)
{
  return current_funccal->fc_returned;
}

bool free_unref_funccal(int copyID, int testing)
{
  bool did_free = false;
  bool did_free_funccal = false;

  for (funccall_T **pfc = &previous_funccal; *pfc != NULL;) {
    if (can_free_funccal(*pfc, copyID)) {
      funccall_T *fc = *pfc;
      *pfc = fc->fc_caller;
      free_funccal_contents(fc);
      did_free = true;
      did_free_funccal = true;
    } else {
      pfc = &(*pfc)->fc_caller;
    }
  }
  if (did_free_funccal) {
    // When a funccal was freed some more items might be garbage
    // collected, so run again.
    garbage_collect(testing);
  }
  return did_free;
}

// Get function call environment based on backtrace debug level
funccall_T *get_funccal(void)
{
  funccall_T *funccal = current_funccal;
  if (debug_backtrace_level > 0) {
    for (int i = 0; i < debug_backtrace_level; i++) {
      funccall_T *temp_funccal = funccal->fc_caller;
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

/// @return  hashtable used for local variables in the current funccal or
///          NULL if there is no current funccal.
hashtab_T *get_funccal_local_ht(void)
{
  if (current_funccal == NULL) {
    return NULL;
  }
  return &get_funccal()->fc_l_vars.dv_hashtab;
}

/// @return   the l: scope variable or
///           NULL if there is no current funccal.
dictitem_T *get_funccal_local_var(void)
{
  if (current_funccal == NULL) {
    return NULL;
  }
  return (dictitem_T *)&get_funccal()->fc_l_vars_var;
}

/// @return  the hashtable used for argument in the current funccal or
///          NULL if there is no current funccal.
hashtab_T *get_funccal_args_ht(void)
{
  if (current_funccal == NULL) {
    return NULL;
  }
  return &get_funccal()->fc_l_avars.dv_hashtab;
}

/// @return  the a: scope variable or
///          NULL if there is no current funccal.
dictitem_T *get_funccal_args_var(void)
{
  if (current_funccal == NULL) {
    return NULL;
  }
  return (dictitem_T *)&current_funccal->fc_l_avars_var;
}

/// List function variables, if there is a function.
void list_func_vars(int *first)
{
  if (current_funccal != NULL) {
    list_hashtable_vars(&current_funccal->fc_l_vars.dv_hashtab, "l:", false,
                        first);
  }
}

/// @return  if "ht" is the hashtable for local variables in the current
///          funccal, return the dict that contains it. Otherwise return NULL.
dict_T *get_current_funccal_dict(hashtab_T *ht)
{
  if (current_funccal != NULL && ht == &current_funccal->fc_l_vars.dv_hashtab) {
    return &current_funccal->fc_l_vars;
  }
  return NULL;
}

/// Search hashitem in parent scope.
hashitem_T *find_hi_in_scoped_ht(const char *name, hashtab_T **pht)
{
  if (current_funccal == NULL || current_funccal->fc_func->uf_scoped == NULL) {
    return NULL;
  }

  funccall_T *old_current_funccal = current_funccal;
  hashitem_T *hi = NULL;
  const size_t namelen = strlen(name);
  const char *varname;

  // Search in parent scope which is possible to reference from lambda
  current_funccal = current_funccal->fc_func->uf_scoped;
  while (current_funccal != NULL) {
    hashtab_T *ht = find_var_ht(name, namelen, &varname);
    if (ht != NULL && *varname != NUL) {
      hi = hash_find_len(ht, varname, namelen - (size_t)(varname - name));
      if (!HASHITEM_EMPTY(hi)) {
        *pht = ht;
        break;
      }
    }
    if (current_funccal == current_funccal->fc_func->uf_scoped) {
      break;
    }
    current_funccal = current_funccal->fc_func->uf_scoped;
  }
  current_funccal = old_current_funccal;

  return hi;
}

/// Search variable in parent scope.
dictitem_T *find_var_in_scoped_ht(const char *name, const size_t namelen, int no_autoload)
{
  if (current_funccal == NULL || current_funccal->fc_func->uf_scoped == NULL) {
    return NULL;
  }

  dictitem_T *v = NULL;
  funccall_T *old_current_funccal = current_funccal;
  const char *varname;

  // Search in parent scope which is possible to reference from lambda
  current_funccal = current_funccal->fc_func->uf_scoped;
  while (current_funccal) {
    hashtab_T *ht = find_var_ht(name, namelen, &varname);
    if (ht != NULL && *varname != NUL) {
      v = find_var_in_ht(ht, *name, varname,
                         namelen - (size_t)(varname - name), no_autoload);
      if (v != NULL) {
        break;
      }
    }
    if (current_funccal == current_funccal->fc_func->uf_scoped) {
      break;
    }
    current_funccal = current_funccal->fc_func->uf_scoped;
  }
  current_funccal = old_current_funccal;

  return v;
}

/// Set "copyID + 1" in previous_funccal and callers.
bool set_ref_in_previous_funccal(int copyID)
{
  for (funccall_T *fc = previous_funccal; fc != NULL;
       fc = fc->fc_caller) {
    fc->fc_copyID = copyID + 1;
    if (set_ref_in_ht(&fc->fc_l_vars.dv_hashtab, copyID + 1, NULL)
        || set_ref_in_ht(&fc->fc_l_avars.dv_hashtab, copyID + 1, NULL)
        || set_ref_in_list_items(&fc->fc_l_varlist, copyID + 1, NULL)) {
      return true;
    }
  }
  return false;
}

static bool set_ref_in_funccal(funccall_T *fc, int copyID)
{
  if (fc->fc_copyID != copyID) {
    fc->fc_copyID = copyID;
    if (set_ref_in_ht(&fc->fc_l_vars.dv_hashtab, copyID, NULL)
        || set_ref_in_ht(&fc->fc_l_avars.dv_hashtab, copyID, NULL)
        || set_ref_in_list_items(&fc->fc_l_varlist, copyID, NULL)
        || set_ref_in_func(NULL, fc->fc_func, copyID)) {
      return true;
    }
  }
  return false;
}

/// Set "copyID" in all local vars and arguments in the call stack.
bool set_ref_in_call_stack(int copyID)
{
  for (funccall_T *fc = current_funccal; fc != NULL;
       fc = fc->fc_caller) {
    if (set_ref_in_funccal(fc, copyID)) {
      return true;
    }
  }

  // Also go through the funccal_stack.
  for (funccal_entry_T *entry = funccal_stack; entry != NULL;
       entry = entry->next) {
    for (funccall_T *fc = entry->top_funccal; fc != NULL;
         fc = fc->fc_caller) {
      if (set_ref_in_funccal(fc, copyID)) {
        return true;
      }
    }
  }

  return false;
}

/// Set "copyID" in all functions available by name.
bool set_ref_in_functions(int copyID)
{
  int todo = (int)func_hashtab.ht_used;
  for (hashitem_T *hi = func_hashtab.ht_array; todo > 0 && !got_int; hi++) {
    if (!HASHITEM_EMPTY(hi)) {
      todo--;
      ufunc_T *fp = HI2UF(hi);
      if (!func_name_refcount(fp->uf_name)
          && set_ref_in_func(NULL, fp, copyID)) {
        return true;
      }
    }
  }
  return false;
}

/// Set "copyID" in all function arguments.
bool set_ref_in_func_args(int copyID)
{
  for (int i = 0; i < funcargs.ga_len; i++) {
    if (set_ref_in_item(((typval_T **)funcargs.ga_data)[i],
                        copyID, NULL, NULL)) {
      return true;
    }
  }
  return false;
}

/// Mark all lists and dicts referenced through function "name" with "copyID".
/// "list_stack" is used to add lists to be marked.  Can be NULL.
/// "ht_stack" is used to add hashtabs to be marked.  Can be NULL.
///
/// @return  true if setting references failed somehow.
bool set_ref_in_func(char *name, ufunc_T *fp_in, int copyID)
{
  ufunc_T *fp = fp_in;
  int error = FCERR_NONE;
  char fname_buf[FLEN_FIXED + 1];
  char *tofree = NULL;
  bool abort = false;
  if (name == NULL && fp_in == NULL) {
    return false;
  }

  if (fp_in == NULL) {
    char *fname = fname_trans_sid(name, fname_buf, &tofree, &error);
    fp = find_func(fname);
  }
  if (fp != NULL) {
    for (funccall_T *fc = fp->uf_scoped; fc != NULL; fc = fc->fc_func->uf_scoped) {
      abort = abort || set_ref_in_funccal(fc, copyID);
    }
  }
  xfree(tofree);
  return abort;
}

/// Registers a luaref as a lambda.
char *register_luafunc(LuaRef ref)
{
  char *name = get_lambda_name();
  size_t namelen = get_lambda_name_len();
  ufunc_T *fp = alloc_ufunc(name, namelen);

  fp->uf_refcount = 1;
  fp->uf_varargs = true;
  fp->uf_flags = FC_LUAREF;
  fp->uf_calls = 0;
  fp->uf_script_ctx = current_sctx;
  fp->uf_luaref = ref;

  hash_add(&func_hashtab, UF2HIKEY(fp));

  // coverity[leaked_storage]
  return fp->uf_name;
}
