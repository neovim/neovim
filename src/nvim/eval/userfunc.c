// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// User defined function support

#include "nvim/ascii.h"
#include "nvim/charset.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/eval/encode.h"
#include "nvim/eval/userfunc.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/getchar.h"
#include "nvim/globals.h"
#include "nvim/lua/executor.h"
#include "nvim/misc1.h"
#include "nvim/os/input.h"
#include "nvim/regexp.h"
#include "nvim/search.h"
#include "nvim/ui.h"
#include "nvim/vim.h"

// flags used in uf_flags
#define FC_ABORT    0x01          // abort function on error
#define FC_RANGE    0x02          // function accepts range
#define FC_DICT     0x04          // Dict function, uses "self"
#define FC_CLOSURE  0x08          // closure, uses outer scope variables
#define FC_DELETED  0x10          // :delfunction used while uf_refcount > 0
#define FC_REMOVED  0x20          // function redefined while uf_refcount > 0
#define FC_SANDBOX  0x40          // function defined in the sandbox
#define FC_DEAD     0x80          // function kept only for reference to dfunc
#define FC_EXPORT   0x100         // "export def Func()"
#define FC_NOARGS   0x200         // no a: variables in lambda
#define FC_VIM9     0x400         // defined in vim9 script file
#define FC_CFUNC    0x800         // C function extension

#ifdef INCLUDE_GENERATED_DECLARATIONS
#include "eval/userfunc.c.generated.h"
#endif

hashtab_T func_hashtab;

// Used by get_func_tv()
static garray_T funcargs = GA_EMPTY_INIT_VALUE;

// pointer to funccal for currently active function
static funccall_T *current_funccal = NULL;

// Pointer to list of previously used funccal, still around because some
// item in it is still being used.
static funccall_T *previous_funccal = NULL;

static char *e_funcexts = N_(
    "E122: Function %s already exists, add ! to replace it");
static char *e_funcdict = N_("E717: Dictionary entry already exists");
static char *e_funcref = N_("E718: Funcref required");
static char *e_nofunc = N_("E130: Unknown function: %s");

void func_init(void)
{
    hash_init(&func_hashtab);
}

/// Get function arguments.
static int get_function_args(char_u **argp, char_u endchar, garray_T *newargs,
                             int *varargs, garray_T *default_args, bool skip)
{
  bool    mustend = false;
  char_u  *arg = *argp;
  char_u  *p = arg;
  int     c;
  int     i;

  if (newargs != NULL) {
    ga_init(newargs, (int)sizeof(char_u *), 3);
  }
  if (default_args != NULL) {
    ga_init(default_args, (int)sizeof(char_u *), 3);
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
      if (*skipwhite(p) == '=' && default_args != NULL) {
        typval_T rettv;

        any_default = true;
        p = skipwhite(p) + 1;
        p = skipwhite(p);
        char_u *expr = p;
        if (eval1(&p, &rettv, false) != FAIL) {
          ga_grow(default_args, 1);

          // trim trailing whitespace
          while (p > expr && ascii_iswhite(p[-1])) {
            p--;
          }
          c = *p;
          *p = NUL;
          expr = vim_strsave(expr);
          ((char_u **)(default_args->ga_data))
            [default_args->ga_len] = expr;
          default_args->ga_len++;
          *p = c;
        } else {
          mustend = true;
        }
      } else if (any_default) {
        EMSG(_("E989: Non-default argument follows default argument"));
        mustend = true;
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
  ga_grow(&current_funccal->fc_funcs, 1);
  ((ufunc_T **)current_funccal->fc_funcs.ga_data)
    [current_funccal->fc_funcs.ga_len++] = fp;
}


/// Get a name for a lambda.  Returned in static memory.
char_u * get_lambda_name(void)
{
    static char_u   name[30];
    static int      lambda_no = 0;

    snprintf((char *)name, sizeof(name), "<lambda>%d", ++lambda_no);
    return name;
}

/// Parse a lambda expression and get a Funcref from "*arg".
///
/// @return OK or FAIL.  Returns NOTDONE for dict or {expr}.
int get_lambda_tv(char_u **arg, typval_T *rettv, bool evaluate)
{
  garray_T   newargs = GA_EMPTY_INIT_VALUE;
  garray_T   *pnewargs;
  ufunc_T    *fp = NULL;
  partial_T *pt = NULL;
  int        varargs;
  int        ret;
  char_u     *start = skipwhite(*arg + 1);
  char_u     *s, *e;
  bool       *old_eval_lavars = eval_lavars_used;
  bool       eval_lavars = false;

  // First, check if this is a lambda expression. "->" must exists.
  ret = get_function_args(&start, '-', NULL, NULL, NULL, true);
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
  ret = get_function_args(arg, '-', pnewargs, &varargs, NULL, false);
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
    garray_T newlines;

    char_u *name = get_lambda_name();

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
    if (strstr((char *)p + 7, "a:") == NULL) {
      // No a: variables are used for sure.
      flags |= FC_NOARGS;
    }

    fp->uf_refcount = 1;
    STRCPY(fp->uf_name, name);
    hash_add(&func_hashtab, UF2HIKEY(fp));
    fp->uf_args = newargs;
    ga_init(&fp->uf_def_args, (int)sizeof(char_u *), 1);
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
  xfree(pt);
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
///
/// @return name of the function.
char_u *deref_func_name(const char *name, int *lenp,
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

/// Give an error message with a function name.  Handle <SNR> things.
///
/// @param ermsg must be passed without translation (use N_() instead of _()).
/// @param name function name
void emsg_funcname(char *ermsg, const char_u *name)
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

/*
 * Allocate a variable for the result of a function.
 * Return OK or FAIL.
 */
int
get_func_tv(
    const char_u *name,     // name of the function
    int len,                // length of "name" or -1 to use strlen()
    typval_T *rettv,
    char_u **arg,           // argument, pointing to the '('
    funcexe_T *funcexe      // various values
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
  while (argcount < MAX_FUNC_ARGS
         - (funcexe->partial == NULL ? 0 : funcexe->partial->pt_argc)) {
    argp = skipwhite(argp + 1);             // skip the '(' or ','
    if (*argp == ')' || *argp == ',' || *argp == NUL) {
      break;
    }
    if (eval1(&argp, &argvars[argcount], funcexe->evaluate) == FAIL) {
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
    ret = call_func(name, len, rettv, argcount, argvars, funcexe);

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
        snprintf((char *)fname_buf + i, FLEN_FIXED + 1 - i, "%" PRId64 "_",
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

/// Find a function by name, return pointer to it in ufuncs.
/// @return NULL for unknown function.
ufunc_T *find_func(const char_u *name)
{
  hashitem_T  *hi;

  hi = hash_find(&func_hashtab, name);
  if (!HASHITEM_EMPTY(hi))
    return HI2UF(hi);
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

// Free "fc"
static void free_funccal(funccall_T *fc)
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

  func_ptr_unref(fc->func);
  xfree(fc);
}

// Free "fc" and what it contains.
// Can be called only when "fc" is kept beyond the period of it called,
// i.e. after cleanup_function_call(fc).
static void free_funccal_contents(funccall_T *fc)
{
  // Free all l: variables.
  vars_clear(&fc->l_vars.dv_hashtab);

  // Free all a: variables.
  vars_clear(&fc->l_avars.dv_hashtab);

  // Free the a:000 variables.
  TV_LIST_ITER(&fc->l_varlist, li, {
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

  current_funccal = fc->caller;

  // Free all l: variables if not referred.
  if (may_free_fc && fc->l_vars.dv_refcount == DO_NOT_FREE_CNT) {
    vars_clear(&fc->l_vars.dv_hashtab);
  } else {
    free_fc = false;
  }

  // If the a:000 list and the l: and a: dicts are not referenced and
  // there is no closure using it, we can free the funccall_T and what's
  // in it.
  if (may_free_fc && fc->l_avars.dv_refcount == DO_NOT_FREE_CNT) {
    vars_clear_ext(&fc->l_avars.dv_hashtab, false);
  } else {
    free_fc = false;

    // Make a copy of the a: variables, since we didn't do that above.
    TV_DICT_ITER(&fc->l_avars, di, {
      tv_copy(&di->di_tv, &di->di_tv);
    });
  }

  if (may_free_fc && fc->l_varlist.lv_refcount   // NOLINT(runtime/deprecated)
      == DO_NOT_FREE_CNT) {
    fc->l_varlist.lv_first = NULL;  // NOLINT(runtime/deprecated)

  } else {
    free_fc = false;

    // Make a copy of the a:000 items, since we didn't do that above.
    TV_LIST_ITER(&fc->l_varlist, li, {
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
    fc->caller = previous_funccal;
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
        free_funccal_contents(fc);
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
  ga_clear_strings(&(fp->uf_def_args));
  ga_clear_strings(&(fp->uf_lines));

  if (fp->uf_cb_free != NULL) {
    fp->uf_cb_free(fp->uf_cb_state);
    fp->uf_cb_free = NULL;
  }

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
  int fixvar_idx = 0;           // index in fixvar[]
  int ai;
  bool islambda = false;
  char_u numbuf[NUMBUFLEN];
  char_u      *name;
  typval_T *tv_to_free[MAX_FUNC_ARGS];
  int tv_to_free_len = 0;
  proftime_T wait_start;
  proftime_T call_start;
  int started_profiling = false;
  bool did_save_redo = false;
  save_redo_T save_redo;

  // If depth of calling is getting too high, don't execute the function
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
  fc = xcalloc(1, sizeof(funccall_T));
  fc->caller = current_funccal;
  current_funccal = fc;
  fc->func = fp;
  fc->rettv = rettv;
  fc->level = ex_nesting_level;
  // Check if this function has a breakpoint.
  fc->breakpoint = dbg_find_breakpoint(false, fp->uf_name, (linenr_T)0);
  fc->dbg_tick = debug_tick;

  // Set up fields for closure.
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
    v->di_tv.v_lock = VAR_UNLOCKED;
    v->di_tv.vval.v_dict = selfdict;
    ++selfdict->dv_refcount;
  }

  // Init a: variables, unless none found (in lambda).
  // Set a:0 to "argcount" less number of named arguments, if >= 0.
  // Set a:000 to a list with room for the "..." arguments.
  init_var_dict(&fc->l_avars, &fc->l_avars_var, VAR_SCOPE);
  if ((fp->uf_flags & FC_NOARGS) == 0) {
    add_nr_var(&fc->l_avars, (dictitem_T *)&fc->fixvar[fixvar_idx++], "0",
               (varnumber_T)(argcount >= fp->uf_args.ga_len
                             ? argcount - fp->uf_args.ga_len : 0));
  }
  fc->l_avars.dv_lock = VAR_FIXED;
  if ((fp->uf_flags & FC_NOARGS) == 0) {
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
  }
  tv_list_init_static(&fc->l_varlist);
  tv_list_set_lock(&fc->l_varlist, VAR_FIXED);

  // Set a:firstline to "firstline" and a:lastline to "lastline".
  // Set a:name to named arguments.
  // Set a:N to the "..." arguments.
  // Skipped when no a: variables used (in lambda).
  if ((fp->uf_flags & FC_NOARGS) == 0) {
    add_nr_var(&fc->l_avars, (dictitem_T *)&fc->fixvar[fixvar_idx++],
               "firstline", (varnumber_T)firstline);
    add_nr_var(&fc->l_avars, (dictitem_T *)&fc->fixvar[fixvar_idx++],
               "lastline", (varnumber_T)lastline);
  }
  bool default_arg_err = false;
  for (int i = 0; i < argcount || i < fp->uf_args.ga_len; i++) {
    bool addlocal = false;
    bool isdefault = false;
    typval_T def_rettv;

    ai = i - fp->uf_args.ga_len;
    if (ai < 0) {
      // named argument a:name
      name = FUNCARG(fp, i);
      if (islambda) {
        addlocal = true;
      }

      // evaluate named argument default expression
      isdefault = ai + fp->uf_def_args.ga_len >= 0 && i >= argcount;
      if (isdefault) {
        char_u *default_expr = NULL;
        def_rettv.v_type = VAR_NUMBER;
        def_rettv.vval.v_number = -1;

        default_expr = ((char_u **)(fp->uf_def_args.ga_data))
          [ai + fp->uf_def_args.ga_len];
        if (eval1(&default_expr, &def_rettv, true) == FAIL) {
          default_arg_err = true;
          break;
        }
      }
    } else {
      if ((fp->uf_flags & FC_NOARGS) != 0) {
        // Bail out if no a: arguments used (in lambda).
        break;
      }
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
      tv_dict_add(&fc->l_vars, v);
    } else {
      tv_dict_add(&fc->l_avars, v);
    }

    if (ai >= 0 && ai < MAX_FUNC_ARGS) {
      listitem_T *li = &fc->l_listitems[ai];

      *TV_LIST_ITEM_TV(li) = argvars[i];
      TV_LIST_ITEM_TV(li)->v_lock =  VAR_FIXED;
      tv_list_append(&fc->l_varlist, li);
    }
  }

  // Don't redraw while executing the function.
  RedrawingDisabled++;
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

  if (default_arg_err && (fp->uf_flags & FC_ABORT)) {
    did_emsg = true;
  } else if (islambda) {
    char_u *p = *(char_u **)fp->uf_lines.ga_data + 7;

    // A Lambda always has the command "return {expr}".  It is much faster
    // to evaluate {expr} directly.
    ex_nesting_level++;
    (void)eval1(&p, rettv, true);
    ex_nesting_level--;
  } else {
    // call do_cmdline() to execute the lines
    do_cmdline(NULL, get_func_line, (void *)fc,
               DOCMD_NOWAIT|DOCMD_VERBOSE|DOCMD_REPEAT);
  }

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

  // when being verbose, mention the return value
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
static bool func_name_refcount(char_u *name)
{
  return isdigit(*name) || *name == '<';
}

static funccal_entry_T *funccal_stack = NULL;

// Save the current function call pointer, and set it to NULL.
// Used when executing autocommands and for ":source".
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
    IEMSG("INTERNAL: restore_funccal()");
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
  hashitem_T  *hi;
  ufunc_T     *fp;
  uint64_t skipped = 0;
  uint64_t todo = 1;
  uint64_t used;

  // Clean up the current_funccal chain and the funccal stack.
  while (current_funccal != NULL) {
    tv_clear(current_funccal->rettv);
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

int func_call(char_u *name, typval_T *args, partial_T *partial,
              dict_T *selfdict, typval_T *rettv)
{
  typval_T argv[MAX_FUNC_ARGS + 1];
  int argc = 0;
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

  funcexe_T funcexe = FUNCEXE_INIT;
  funcexe.firstline = curwin->w_cursor.lnum;
  funcexe.lastline = curwin->w_cursor.lnum;
  funcexe.evaluate = true;
  funcexe.partial = partial;
  funcexe.selfdict = selfdict;
  r = call_func(name, -1, rettv, argc, argv, &funcexe);

func_call_skip_call:
  // Free the arguments.
  while (argc > 0) {
    tv_clear(&argv[--argc]);
  }

  return r;
}

// Give an error message for the result of a function.
// Nothing if "error" is FCERR_NONE.
static void user_func_error(int error, const char_u *name)
  FUNC_ATTR_NONNULL_ALL
{
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

/// Call a function with its resolved parameters
///
/// @return FAIL if function cannot be called, else OK (even if an error
///         occurred while executing the function! Set `msg_list` to capture
///         the error, see do_cmdline()).
int
call_func(
    const char_u *funcname,         // name of the function
    int len,                        // length of "name" or -1 to use strlen()
    typval_T *rettv,                // [out] value goes here
    int argcount_in,                // number of "argvars"
    typval_T *argvars_in,           // vars for arguments, must have "argcount"
                                    // PLUS ONE elements!
    funcexe_T *funcexe              // more arguments
)
  FUNC_ATTR_NONNULL_ARG(1, 3, 5, 6)
{
  int ret = FAIL;
  int error = ERROR_NONE;
  ufunc_T *fp = NULL;
  char_u fname_buf[FLEN_FIXED + 1];
  char_u *tofree = NULL;
  char_u *fname = NULL;
  char_u *name = NULL;
  int argcount = argcount_in;
  typval_T *argvars = argvars_in;
  dict_T *selfdict = funcexe->selfdict;
  typval_T argv[MAX_FUNC_ARGS + 1];  // used when "partial" or
                                     // "funcexe->basetv" is not NULL
  int argv_clear = 0;
  int argv_base = 0;
  partial_T *partial = funcexe->partial;

  // Initialize rettv so that it is safe for caller to invoke clear_tv(rettv)
  // even when call_func() returns FAIL.
  rettv->v_type = VAR_UNKNOWN;

  if (len <= 0) {
    len = (int)STRLEN(funcname);
  }
  if (partial != NULL) {
    fp = partial->pt_func;
  }
  if (fp == NULL) {
    // Make a copy of the name, if it comes from a funcref variable it could
    // be changed or deleted in the called function.
    name = vim_strnsave(funcname, len);
    fname = fname_trans_sid(name, fname_buf, &tofree, &error);
  }

  if (funcexe->doesrange != NULL) {
    *funcexe->doesrange = false;
  }

  if (partial != NULL) {
    // When the function has a partial with a dict and there is a dict
    // argument, use the dict argument. That is backwards compatible.
    // When the dict was bound explicitly use the one from the partial.
    if (partial->pt_dict != NULL && (selfdict == NULL || !partial->pt_auto)) {
      selfdict = partial->pt_dict;
    }
    if (error == ERROR_NONE && partial->pt_argc > 0) {
      for (argv_clear = 0; argv_clear < partial->pt_argc; argv_clear++) {
        if (argv_clear + argcount_in >= MAX_FUNC_ARGS) {
          error = ERROR_TOOMANY;
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

  if (error == ERROR_NONE && funcexe->evaluate) {
    char_u *rfname = fname;

    // Ignore "g:" before a function name.
    if (fp == NULL && fname[0] == 'g' && fname[1] == ':') {
      rfname = fname + 2;
    }

    rettv->v_type = VAR_NUMBER;         // default rettv is number zero
    rettv->vval.v_number = 0;
    error = ERROR_UNKNOWN;

    if (is_luafunc(partial)) {
      if (len > 0) {
        error = ERROR_NONE;
        nlua_typval_call((const char *)funcname, len, argvars, argcount, rettv);
      }
    } else if (fp != NULL || !builtin_function((const char *)rfname, -1)) {
      // User defined function.
      if (fp == NULL) {
        fp = find_func(rfname);
      }

      // Trigger FuncUndefined event, may load the function.
      if (fp == NULL
          && apply_autocmds(EVENT_FUNCUNDEFINED, rfname, rfname, TRUE, NULL)
          && !aborting()) {
        // executed an autocommand, search for the function again
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
      } else if (fp != NULL && (fp->uf_flags & FC_CFUNC)) {
        cfunc_T cb = fp->uf_cb;
        error = (*cb)(argcount, argvars, rettv, fp->uf_cb_state);
      } else if (fp != NULL) {
        if (funcexe->argv_func != NULL) {
          // postponed filling in the arguments, do it now
          argcount = funcexe->argv_func(argcount, argvars, argv_clear,
                                        fp->uf_args.ga_len);
        }

        if (funcexe->basetv != NULL) {
          // Method call: base->Method()
          memmove(&argv[1], argvars, sizeof(typval_T) * argcount);
          argv[0] = *funcexe->basetv;
          argcount++;
          argvars = argv;
          argv_base = 1;
        }

        if (fp->uf_flags & FC_RANGE && funcexe->doesrange != NULL) {
          *funcexe->doesrange = true;
        }
        if (argcount < fp->uf_args.ga_len - fp->uf_def_args.ga_len) {
          error = ERROR_TOOFEW;
        } else if (!fp->uf_varargs && argcount > fp->uf_args.ga_len) {
          error = ERROR_TOOMANY;
        } else if ((fp->uf_flags & FC_DICT) && selfdict == NULL) {
          error = ERROR_DICT;
        } else {
          // Call the user function.
          call_user_func(fp, argcount, argvars, rettv, funcexe->firstline,
                         funcexe->lastline,
                         (fp->uf_flags & FC_DICT) ? selfdict : NULL);
          error = ERROR_NONE;
        }
      }
    } else if (funcexe->basetv != NULL) {
      // expr->method(): Find the method name in the table, call its
      // implementation with the base as one of the arguments.
      error = call_internal_method(fname, argcount, argvars, rettv,
                                   funcexe->basetv);
    } else {
      // Find the function name in the table, call its implementation.
      error = call_internal_func(fname, argcount, argvars, rettv);
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

theend:
  // Report an error unless the argument evaluation or function call has been
  // cancelled due to an aborting error, an interrupt, or an exception.
  if (!aborting()) {
    user_func_error(error, (name != NULL) ? name : funcname);
  }

  // clear the copies made from the partial
  while (argv_clear > 0) {
    tv_clear(&argv[--argv_clear + argv_base]);
  }

  xfree(tofree);
  xfree(name);

  return ret;
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
}

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
char_u *
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
      if (is_luafunc(lv.ll_tv->vval.v_partial) && *end == '.') {
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
 * ":function"
 */
void ex_function(exarg_T *eap)
{
  char_u      *theline;
  char_u      *line_to_free = NULL;
  int c;
  int saved_did_emsg;
  bool saved_wait_return = need_wait_return;
  char_u      *name = NULL;
  char_u      *p;
  char_u      *arg;
  char_u      *line_arg = NULL;
  garray_T newargs;
  garray_T default_args;
  garray_T newlines;
  int varargs = false;
  int flags = 0;
  ufunc_T     *fp;
  bool overwrite = false;
  int indent;
  int nesting;
  dictitem_T  *v;
  funcdict_T fudi;
  static int func_nr = 0;           // number for nameless function
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
    // attempt to continue by skipping some text
    if (vim_strchr(p, '(') != NULL) {
      p = vim_strchr(p, '(');
    }
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
    // Disallow using the g: dict.
    if (fudi.fd_dict != NULL && fudi.fd_dict->dv_scope == VAR_DEF_SCOPE) {
      EMSG(_("E862: Cannot use g: here"));
    }
  }

  if (get_function_args(&p, ')', &newargs, &varargs,
                        &default_args, eap->skip) == FAIL) {
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
      // Use eap->arg, split up in parts by line breaks.
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
      // skip ':' and blanks
      for (p = theline; ascii_iswhite(*p) || *p == ':'; p++) {
      }

      // Check for "endfunction".
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

      // Check for defining a function inside this function.
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
                  && (!ASCII_ISALPHA(p[2]) || p[2] == 's')))) {
        // ":python <<" continues until a dot, like ":append"
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
              vim_strnsave(theline, skipwhite(theline) - theline);
          }
          skip_until = vim_strnsave(p, skiptowhite(p) - p);
          do_concat = false;
          is_heredoc = true;
        }
      }
    }

    // Add the line to the function.
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

    // Check for end of eap->arg.
    if (line_arg != NULL && *line_arg == NUL) {
      line_arg = NULL;
    }
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
      if (var_check_lock(fudi.fd_dict->dv_lock, (const char *)eap->arg,
                         TV_CSTRING)) {
        // Can't add a function to a locked dictionary
        goto erret;
      }
    } else if (var_check_lock(fudi.fd_di->di_tv.v_lock, (const char *)eap->arg,
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

      // Check that the autoload name matches the script name.
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

      // behave like "dict" was used
      flags |= FC_DICT;
    }

    // insert the new function in the function list
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

  goto ret_free;

erret:
  ga_clear_strings(&newargs);
  ga_clear_strings(&default_args);
errret_2:
  ga_clear_strings(&newlines);
ret_free:
  xfree(skip_until);
  xfree(heredoc_trimmed);
  xfree(line_to_free);
  xfree(fudi.fd_newkey);
  xfree(name);
  did_emsg |= saved_did_emsg;
  need_wait_return |= saved_wait_return;
  if (show_block) {
    ui_ext_cmdline_block_leave();
  }
}  // NOLINT(readability/fn_size)

/*
 * Return 5 if "p" starts with "<SID>" or "<SNR>" (ignoring case).
 * Return 2 if "p" starts with "s:".
 * Return 0 otherwise.
 */
int eval_fname_script(const char *const p)
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
  if (returning) {
    eap->nextcmd = NULL;
  } else if (eap->nextcmd == NULL) {          // no argument
    eap->nextcmd = check_nextcmd(arg);
  }

  if (eap->skip)
    --emsg_skip;
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
  bool doesrange;
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
    EMSG2(_(e_missingparen), eap->arg);
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

    funcexe_T funcexe = FUNCEXE_INIT;
    funcexe.firstline = eap->line1;
    funcexe.lastline = eap->line2;
    funcexe.doesrange = &doesrange;
    funcexe.evaluate = true;
    funcexe.partial = partial;
    funcexe.selfdict = fudi.fd_dict;
    if (get_func_tv(name, -1, &rettv, &arg, &funcexe) == FAIL) {
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

  // When inside :try we need to check for following "| catch".
  if (!failed || eap->cstack->cs_trylevel > 0) {
    // Check for trailing illegal characters and a following command.
    if (!ends_excmd(*arg)) {
      if (!failed) {
        emsg_severe = true;
        EMSG(_(e_trailing));
      }
    } else {
      eap->nextcmd = check_nextcmd(arg);
    }
  }

end:
  tv_dict_unref(fudi.fd_dict);
  xfree(tofree);
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

  if (reanimate) {
    // Undo the return.
    current_funccal->returned = false;
  }

  //
  // Cleanup (and deactivate) conditionals, but stop when a try conditional
  // not in its finally clause (which then is to be executed next) is found.
  // In this case, make the ":return" pending for execution at the ":endtry".
  // Otherwise, return normally.
  //
  idx = cleanup_conditionals(eap->cstack, 0, true);
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
        // Store the value of the pending return.
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
  garray_T    *gap;    // growarray with function lines

  // If breakpoints have been added/deleted need to check for it.
  if (fcp->dbg_tick != debug_tick) {
    fcp->breakpoint = dbg_find_breakpoint(FALSE, fp->uf_name,
        sourcing_lnum);
    fcp->dbg_tick = debug_tick;
  }
  if (do_profiling == PROF_YES)
    func_line_end(cookie);

  gap = &fp->uf_lines;
  if (((fp->uf_flags & FC_ABORT) && did_emsg && !aborted_in_try())
      || fcp->returned) {
    retval = NULL;
  } else {
    // Skip NULL lines (continuation lines).
    while (fcp->linenr < gap->ga_len
           && ((char_u **)(gap->ga_data))[fcp->linenr] == NULL) {
      fcp->linenr++;
    }
    if (fcp->linenr >= gap->ga_len) {
      retval = NULL;
    } else {
      retval = vim_strsave(((char_u **)(gap->ga_data))[fcp->linenr++]);
      sourcing_lnum = fcp->linenr;
      if (do_profiling == PROF_YES)
        func_line_start(cookie);
    }
  }

  // Did we encounter a breakpoint?
  if (fcp->breakpoint != 0 && fcp->breakpoint <= sourcing_lnum) {
    dbg_breakpoint(fp->uf_name, sourcing_lnum);
    // Find next breakpoint.
    fcp->breakpoint = dbg_find_breakpoint(false, fp->uf_name,
                                          sourcing_lnum);
    fcp->dbg_tick = debug_tick;
  }

  return retval;
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

/// Turn "dict.Func" into a partial for "Func" bound to "dict".
/// Changes "rettv" in-place.
void make_partial(dict_T *const selfdict, typval_T *const rettv)
{
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

/*
 * Return TRUE when a function was ended by a ":return" command.
 */
int current_func_returned(void)
{
  return current_funccal->returned;
}

bool free_unref_funccal(int copyID, int testing)
{
  bool did_free = false;
  bool did_free_funccal = false;

  for (funccall_T **pfc = &previous_funccal; *pfc != NULL;) {
    if (can_free_funccal(*pfc, copyID)) {
      funccall_T *fc = *pfc;
      *pfc = fc->caller;
      free_funccal_contents(fc);
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
  return did_free;
}

// Get function call environment based on backtrace debug level
funccall_T *get_funccal(void)
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

/// Return the hashtable used for local variables in the current funccal.
/// Return NULL if there is no current funccal.
hashtab_T *get_funccal_local_ht(void)
{
  if (current_funccal == NULL) {
    return NULL;
  }
  return &get_funccal()->l_vars.dv_hashtab;
}

/// Return the l: scope variable.
/// Return NULL if there is no current funccal.
dictitem_T *get_funccal_local_var(void)
{
  if (current_funccal == NULL) {
    return NULL;
  }
  return (dictitem_T *)&get_funccal()->l_vars_var;
}

/// Return the hashtable used for argument in the current funccal.
/// Return NULL if there is no current funccal.
hashtab_T *get_funccal_args_ht(void)
{
  if (current_funccal == NULL) {
    return NULL;
  }
  return &get_funccal()->l_avars.dv_hashtab;
}

/// Return the a: scope variable.
/// Return NULL if there is no current funccal.
dictitem_T *get_funccal_args_var(void)
{
  if (current_funccal == NULL) {
    return NULL;
  }
  return (dictitem_T *)&current_funccal->l_avars_var;
}

/*
 * List function variables, if there is a function.
 */
void list_func_vars(int *first)
{
  if (current_funccal != NULL) {
    list_hashtable_vars(&current_funccal->l_vars.dv_hashtab, "l:", false,
                        first);
  }
}

/// If "ht" is the hashtable for local variables in the current funccal, return
/// the dict that contains it.
/// Otherwise return NULL.
dict_T *get_current_funccal_dict(hashtab_T *ht)
{
  if (current_funccal != NULL && ht == &current_funccal->l_vars.dv_hashtab) {
    return &current_funccal->l_vars;
  }
  return NULL;
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

/// Set "copyID + 1" in previous_funccal and callers.
bool set_ref_in_previous_funccal(int copyID)
{
  for (funccall_T *fc = previous_funccal; fc != NULL;
       fc = fc->caller) {
    fc->fc_copyID = copyID + 1;
    if (set_ref_in_ht(&fc->l_vars.dv_hashtab, copyID + 1, NULL)
        || set_ref_in_ht(&fc->l_avars.dv_hashtab, copyID + 1, NULL)
        || set_ref_in_list(&fc->l_varlist, copyID + 1, NULL)) {
      return true;
    }
  }
  return false;
}

static bool set_ref_in_funccal(funccall_T *fc, int copyID)
{
  if (fc->fc_copyID != copyID) {
    fc->fc_copyID = copyID;
    if (set_ref_in_ht(&fc->l_vars.dv_hashtab, copyID, NULL)
        || set_ref_in_ht(&fc->l_avars.dv_hashtab, copyID, NULL)
        || set_ref_in_list(&fc->l_varlist, copyID, NULL)
        || set_ref_in_func(NULL, fc->func, copyID)) {
      return true;
    }
  }
  return false;
}

/// Set "copyID" in all local vars and arguments in the call stack.
bool set_ref_in_call_stack(int copyID)
{
  for (funccall_T *fc = current_funccal; fc != NULL;
       fc = fc->caller) {
    if (set_ref_in_funccal(fc, copyID)) {
      return true;
    }
  }

  // Also go through the funccal_stack.
  for (funccal_entry_T *entry = funccal_stack; entry != NULL;
       entry = entry->next) {
    for (funccall_T *fc = entry->top_funccal; fc != NULL;
         fc = fc->caller) {
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
  int todo;
  hashitem_T *hi = NULL;
  ufunc_T *fp;

  todo = (int)func_hashtab.ht_used;
  for (hi = func_hashtab.ht_array; todo > 0 && !got_int; hi++) {
    if (!HASHITEM_EMPTY(hi)) {
      todo--;
      fp = HI2UF(hi);
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

/// Registers a C extension user function.
char_u *register_cfunc(cfunc_T cb, cfunc_free_T cb_free, void *state)
{
  char_u *name = get_lambda_name();
  ufunc_T *fp = xcalloc(1, offsetof(ufunc_T, uf_name) + STRLEN(name) + 1);

  fp->uf_refcount = 1;
  fp->uf_varargs = true;
  fp->uf_flags = FC_CFUNC;
  fp->uf_calls = 0;
  fp->uf_script_ctx = current_sctx;
  fp->uf_cb = cb;
  fp->uf_cb_free = cb_free;
  fp->uf_cb_state = state;

  STRCPY(fp->uf_name, name);
  hash_add(&func_hashtab, UF2HIKEY(fp));

  return fp->uf_name;
}
