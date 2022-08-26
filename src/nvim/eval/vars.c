// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// eval/vars.c: functions for dealing with variables

#include "nvim/ascii.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/drawscreen.h"
#include "nvim/eval.h"
#include "nvim/eval/encode.h"
#include "nvim/eval/funcs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/userfunc.h"
#include "nvim/eval/vars.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/vars.c.generated.h"
#endif

// TODO(ZyX-I): Remove DICT_MAXNEST, make users be non-recursive instead

#define DICT_MAXNEST 100        // maximum nesting of lists and dicts

static char *e_letunexp = N_("E18: Unexpected characters in :let");
static char *e_lock_unlock = N_("E940: Cannot lock or unlock variable %s");

/// Get a list of lines from a HERE document. The here document is a list of
/// lines surrounded by a marker.
///     cmd << {marker}
///       {line1}
///       {line2}
///       ....
///     {marker}
///
/// The {marker} is a string. If the optional 'trim' word is supplied before the
/// marker, then the leading indentation before the lines (matching the
/// indentation in the 'cmd' line) is stripped.
///
/// @return  a List with {lines} or NULL.
static list_T *heredoc_get(exarg_T *eap, char *cmd)
{
  char *marker;
  char *p;
  int marker_indent_len = 0;
  int text_indent_len = 0;
  char *text_indent = NULL;

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
      semsg(_(e_trailing_arg), p);
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

    char *theline = eap->getline(NUL, eap->cookie, 0, false);
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
    if (strcmp(marker, theline + mi) == 0) {
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
      text_indent = xstrnsave(theline, (size_t)text_indent_len);
    }
    // with "trim": skip the indent matching the first line
    if (text_indent != NULL) {
      for (ti = 0; ti < text_indent_len; ti++) {
        if (theline[ti] != text_indent[ti]) {
          break;
        }
      }
    }

    tv_list_append_string(l, theline + ti, -1);
    xfree(theline);
  }
  xfree(text_indent);

  return l;
}

/// ":let" list all variable values
/// ":let var1 var2" list variable values
/// ":let var = expr" assignment command.
/// ":let var += expr" assignment command.
/// ":let var -= expr" assignment command.
/// ":let var *= expr" assignment command.
/// ":let var /= expr" assignment command.
/// ":let var %= expr" assignment command.
/// ":let var .= expr" assignment command.
/// ":let var ..= expr" assignment command.
/// ":let [var1, var2] = expr" unpack list.
/// ":let [name, ..., ; lastname] = expr" unpack list.
void ex_let(exarg_T *eap)
{
  ex_let_const(eap, false);
}

/// ":cons[t] var = expr1" define constant
/// ":cons[t] [name1, name2, ...] = expr1" define constants unpacking list
/// ":cons[t] [name, ..., ; lastname] = expr" define constants unpacking list
void ex_const(exarg_T *eap)
{
  ex_let_const(eap, true);
}

static void ex_let_const(exarg_T *eap, const bool is_const)
{
  char *arg = eap->arg;
  char *expr = NULL;
  typval_T rettv;
  int i;
  int var_count = 0;
  int semicolon = 0;
  char op[2];
  char *argend;
  int first = true;

  argend = (char *)skip_var_list(arg, &var_count, &semicolon);
  if (argend == NULL) {
    return;
  }
  if (argend > arg && argend[-1] == '.') {  // For var.='str'.
    argend--;
  }
  expr = skipwhite(argend);
  if (*expr != '=' && !((vim_strchr("+-*/%.", *expr) != NULL
                         && expr[1] == '=') || STRNCMP(expr, "..=", 3) == 0)) {
    // ":let" without "=": list variables
    if (*arg == '[') {
      emsg(_(e_invarg));
    } else if (!ends_excmd(*arg)) {
      // ":let var1 var2"
      arg = (char *)list_arg_vars(eap, (const char *)arg, &first);
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
                          is_const, (char *)op);
      }
      tv_clear(&rettv);
    }
  } else {
    op[0] = '=';
    op[1] = NUL;
    if (*expr != '=') {
      if (vim_strchr("+-*/%.", *expr) != NULL) {
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
      emsg_skip++;
    }
    i = eval0(expr, &rettv, &eap->nextcmd, !eap->skip);
    if (eap->skip) {
      if (i != FAIL) {
        tv_clear(&rettv);
      }
      emsg_skip--;
    } else if (i != FAIL) {
      (void)ex_let_vars(eap->arg, &rettv, false, semicolon, var_count,
                        is_const, (char *)op);
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
int ex_let_vars(char *arg_start, typval_T *tv, int copy, int semicolon, int var_count, int is_const,
                char *op)
{
  char *arg = arg_start;
  typval_T ltv;

  if (*arg != '[') {
    // ":let var = expr" or ":for var in list"
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
  size_t rest_len = (size_t)tv_list_len(l);
  while (*arg != ']') {
    arg = skipwhite(arg + 1);
    arg = ex_let_one(arg, TV_LIST_ITEM_TV(item), true, is_const, ",;]", op);
    if (arg == NULL) {
      return FAIL;
    }
    rest_len--;

    item = TV_LIST_ITEM_NEXT(l, item);
    arg = skipwhite(arg);
    if (*arg == ';') {
      // Put the rest of the list (may be empty) in the var after ';'.
      // Create a new list for this.
      list_T *const rest_list = tv_list_alloc((ptrdiff_t)rest_len);
      while (item != NULL) {
        tv_list_append_tv(rest_list, TV_LIST_ITEM_TV(item));
        item = TV_LIST_ITEM_NEXT(l, item);
      }

      ltv.v_type = VAR_LIST;
      ltv.v_lock = VAR_UNLOCKED;
      ltv.vval.v_list = rest_list;
      tv_list_ref(rest_list);

      arg = ex_let_one(skipwhite(arg + 1), &ltv, false, is_const, "]", op);
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

/// Skip over assignable variable "var" or list of variables "[var, var]".
/// Used for ":let varvar = expr" and ":for varvar in expr".
/// For "[var, var]" increment "*var_count" for each variable.
/// for "[var, var; var]" set "semicolon".
///
/// @return  NULL for an error.
const char *skip_var_list(const char *arg, int *var_count, int *semicolon)
{
  const char *p;
  const char *s;

  if (*arg == '[') {
    // "[var, var]": find the matching ']'.
    p = arg;
    for (;;) {
      p = skipwhite(p + 1);             // skip whites after '[', ';' or ','
      s = skip_var_one((char *)p);
      if (s == p) {
        semsg(_(e_invarg2), p);
        return NULL;
      }
      (*var_count)++;

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
    return skip_var_one((char *)arg);
  }
}

/// Skip one (assignable) variable name, including @r, $VAR, &option, d.key,
/// l[idx].
static const char *skip_var_one(const char *arg)
{
  if (*arg == '@' && arg[1] != NUL) {
    return arg + 2;
  }
  return (char *)find_name_end(*arg == '$' || *arg == '&' ? arg + 1 : arg,
                               NULL, NULL, FNE_INCL_BR | FNE_CHECK_START);
}

/// List variables for hashtab "ht" with prefix "prefix".
///
/// @param empty  if true also list NULL strings as empty strings.
void list_hashtable_vars(hashtab_T *ht, const char *prefix, int empty, int *first)
{
  hashitem_T *hi;
  dictitem_T *di;
  int todo;

  todo = (int)ht->ht_used;
  for (hi = ht->ht_array; todo > 0 && !got_int; hi++) {
    if (!HASHITEM_EMPTY(hi)) {
      todo--;
      di = TV_DICT_HI2DI(hi);
      char buf[IOSIZE];

      // apply :filter /pat/ to variable name
      xstrlcpy(buf, prefix, IOSIZE);
      xstrlcat(buf, (char *)di->di_key, IOSIZE);
      if (message_filtered(buf)) {
        continue;
      }

      if (empty || di->di_tv.v_type != VAR_STRING
          || di->di_tv.vval.v_string != NULL) {
        list_one_var(di, prefix, first);
      }
    }
  }
}

/// List global variables.
static void list_glob_vars(int *first)
{
  list_hashtable_vars(&globvarht, "", true, first);
}

/// List buffer variables.
static void list_buf_vars(int *first)
{
  list_hashtable_vars(&curbuf->b_vars->dv_hashtab, "b:", true, first);
}

/// List window variables.
static void list_win_vars(int *first)
{
  list_hashtable_vars(&curwin->w_vars->dv_hashtab, "w:", true, first);
}

/// List tab page variables.
static void list_tab_vars(int *first)
{
  list_hashtable_vars(&curtab->tp_vars->dv_hashtab, "t:", true, first);
}

/// List variables in "arg".
static const char *list_arg_vars(exarg_T *eap, const char *arg, int *first)
{
  int error = false;
  int len;
  const char *name;
  const char *name_start;
  typval_T tv;

  while (!ends_excmd(*arg) && !got_int) {
    if (error || eap->skip) {
      arg = find_name_end(arg, NULL, NULL, FNE_INCL_BR | FNE_CHECK_START);
      if (!ascii_iswhite(*arg) && !ends_excmd(*arg)) {
        emsg_severe = true;
        semsg(_(e_trailing_arg), arg);
        break;
      }
    } else {
      // get_name_len() takes care of expanding curly braces
      name_start = name = arg;
      char *tofree;
      len = get_name_len(&arg, &tofree, true, true);
      if (len <= 0) {
        // This is mainly to keep test 49 working: when expanding
        // curly braces fails overrule the exception error message.
        if (len < 0 && !aborting()) {
          emsg_severe = true;
          semsg(_(e_invarg2), arg);
          break;
        }
        error = true;
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
          if (handle_subscript(&arg, &tv, true, true, name, &name) == FAIL) {
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
              assert(used_name != NULL);
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

    arg = (const char *)skipwhite(arg);
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
static char *ex_let_one(char *arg, typval_T *const tv, const bool copy, const bool is_const,
                        const char *const endchars, const char *const op)
  FUNC_ATTR_NONNULL_ARG(1, 2) FUNC_ATTR_WARN_UNUSED_RESULT
{
  char *arg_end = NULL;
  int len;
  int opt_flags;
  char *tofree = NULL;

  // ":let $VAR = expr": Set environment variable.
  if (*arg == '$') {
    if (is_const) {
      emsg(_("E996: Cannot lock an environment variable"));
      return NULL;
    }
    // Find the end of the name.
    arg++;
    char *name = arg;
    len = get_env_len((const char **)&arg);
    if (len == 0) {
      semsg(_(e_invarg2), name - 1);
    } else {
      if (op != NULL && vim_strchr("+-*/%", *op) != NULL) {
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
            tofree = concat_str(s, p);
            p = (const char *)tofree;
            xfree(s);
          }
        }
        if (p != NULL) {
          vim_setenv_ext(name, p);
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
            && vim_strchr(endchars, *skipwhite(p)) == NULL)) {
      emsg(_(e_letunexp));
    } else {
      varnumber_T n = 0;
      getoption_T opt_type;
      long numval;
      char *stringval = NULL;
      const char *s = NULL;
      bool failed = false;

      const char c1 = *p;
      *p = NUL;

      opt_type = get_option_value(arg, &numval, &stringval, opt_flags);
      if (opt_type == gov_bool
          || opt_type == gov_number
          || opt_type == gov_hidden_bool
          || opt_type == gov_hidden_number) {
        // number, possibly hidden
        n = (long)tv_get_number(tv);
      }

      // Avoid setting a string option to the text "v:false" or similar.
      if (tv->v_type != VAR_BOOL && tv->v_type != VAR_SPECIAL) {
        s = tv_get_string_chk(tv);
      }

      if (op != NULL && *op != '=') {
        if (((opt_type == gov_bool || opt_type == gov_number) && *op == '.')
            || (opt_type == gov_string && *op != '.')) {
          semsg(_(e_letwrong), op);
          failed = true;  // don't set the value
        } else {
          // number or bool
          if (opt_type == gov_number || opt_type == gov_bool) {
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
            s = NULL;
          } else if (opt_type == gov_string && stringval != NULL && s != NULL) {
            // string
            char *const oldstringval = stringval;
            stringval = concat_str(stringval, s);
            xfree(oldstringval);
            s = stringval;
          }
        }
      }

      if (!failed) {
        if (opt_type != gov_string || s != NULL) {
          char *err = set_option_value(arg, n, s, opt_flags);
          arg_end = p;
          if (err != NULL) {
            emsg(_(err));
          }
        } else {
          emsg(_(e_stringreq));
        }
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
    if (op != NULL && vim_strchr("+-*/%", *op) != NULL) {
      semsg(_(e_letwrong), op);
    } else if (endchars != NULL
               && vim_strchr(endchars, *skipwhite(arg + 1)) == NULL) {
      emsg(_(e_letunexp));
    } else {
      char *s;

      char *ptofree = NULL;
      const char *p = tv_get_string_chk(tv);
      if (p != NULL && op != NULL && *op == '.') {
        s = get_reg_contents(*arg == '@' ? '"' : *arg, kGRegExprSrc);
        if (s != NULL) {
          ptofree = concat_str(s, p);
          p = (const char *)ptofree;
          xfree(s);
        }
      }
      if (p != NULL) {
        write_reg_contents(*arg == '@' ? '"' : *arg, p, (ssize_t)strlen(p), false);
        arg_end = arg + 1;
      }
      xfree(ptofree);
    }
    // ":let var = expr": Set internal variable.
    // ":let {expr} = expr": Idem, name made with curly braces
  } else if (eval_isnamec1(*arg) || *arg == '{') {
    lval_T lv;

    char *const p = get_lval(arg, tv, &lv, false, false, 0, FNE_CHECK_START);
    if (p != NULL && lv.ll_name != NULL) {
      if (endchars != NULL && vim_strchr(endchars, *skipwhite(p)) == NULL) {
        emsg(_(e_letunexp));
      } else {
        set_var_lval(&lv, p, tv, copy, is_const, op);
        arg_end = p;
      }
    }
    clear_lval(&lv);
  } else {
    semsg(_(e_invarg2), arg);
  }

  return arg_end;
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
  char *arg = eap->arg;
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
static void ex_unletlock(exarg_T *eap, char *argstart, int deep, ex_unletlock_callback callback)
  FUNC_ATTR_NONNULL_ALL
{
  char *arg = argstart;
  char *name_end;
  bool error = false;
  lval_T lv;

  do {
    if (*arg == '$') {
      lv.ll_name = (const char *)arg;
      lv.ll_tv = NULL;
      arg++;
      if (get_env_len((const char **)&arg) == 0) {
        semsg(_(e_invarg2), arg - 1);
        return;
      }
      assert(*lv.ll_name == '$');  // suppress clang "Uninitialized argument value"
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
          semsg(_(e_trailing_arg), name_end);
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
static int do_unlet_var(lval_T *lp, char *name_end, exarg_T *eap, int deep FUNC_ATTR_UNUSED)
  FUNC_ATTR_NONNULL_ALL
{
  int forceit = eap->forceit;
  int ret = OK;
  int cc;

  if (lp->ll_tv == NULL) {
    cc = (char_u)(*name_end);
    *name_end = NUL;

    // Environment variable, normal name or expanded name.
    if (*lp->ll_name == '$') {
      vim_unsetenv_ext(lp->ll_name + 1);
    } else if (do_unlet(lp->ll_name, lp->ll_name_len, forceit) == FAIL) {
      ret = FAIL;
    }
    *name_end = (char)cc;
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
      } else if (is_compatht(ht)) {
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

    hashitem_T *hi = hash_find(ht, varname);
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
static int do_lock_var(lval_T *lp, char *name_end FUNC_ATTR_UNUSED, exarg_T *eap, int deep)
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
          di->di_flags &= (uint8_t)(~DI_FLAGS_LOCK);
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

/// Get the value of internal variable "name".
/// Return OK or FAIL.  If OK is returned "rettv" must be cleared.
///
/// @param len  length of "name"
/// @param rettv  NULL when only checking existence
/// @param dip  non-NULL when typval's dict item is needed
/// @param verbose  may give error message
/// @param no_autoload  do not use script autoloading
int get_var_tv(const char *name, int len, typval_T *rettv, dictitem_T **dip, bool verbose,
               bool no_autoload)
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

/// @return  the string value of a (global/local) variable or
///          NULL when it doesn't exist.
///
/// @see  tv_get_string() for how long the pointer remains valid.
char_u *get_var_value(const char *const name)
{
  dictitem_T *v;

  v = find_var(name, strlen(name), NULL, false);
  if (v == NULL) {
    return NULL;
  }
  return (char_u *)tv_get_string(&v->di_tv);
}

/// Clean up a list of internal variables.
/// Frees all allocated variables and the value they contain.
/// Clears hashtab "ht", does not free it.
void vars_clear(hashtab_T *ht)
{
  vars_clear_ext(ht, true);
}

/// Like vars_clear(), but only free the value if "free_val" is true.
void vars_clear_ext(hashtab_T *ht, int free_val)
{
  int todo;
  hashitem_T *hi;
  dictitem_T *v;

  hash_lock(ht);
  todo = (int)ht->ht_used;
  for (hi = ht->ht_array; todo > 0; hi++) {
    if (!HASHITEM_EMPTY(hi)) {
      todo--;

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

/// Delete a variable from hashtab "ht" at item "hi".
/// Clear the variable value and free the dictitem.
void delete_var(hashtab_T *ht, hashitem_T *hi)
{
  dictitem_T *di = TV_DICT_HI2DI(hi);

  hash_remove(ht, hi);
  tv_clear(&di->di_tv);
  xfree(di);
}

/// List the value of one internal variable.
static void list_one_var(dictitem_T *v, const char *prefix, int *first)
{
  char *const s = encode_tv2echo(&v->di_tv, NULL);
  list_one_var_a(prefix, (const char *)v->di_key, (ptrdiff_t)STRLEN(v->di_key),
                 v->di_tv.v_type, (s == NULL ? "" : s), first);
  xfree(s);
}

/// @param[in]  name_len  Length of the name. May be -1, in this case strlen()
///                       will be used.
/// @param[in,out]  first  When true clear rest of screen and set to false.
static void list_one_var_a(const char *prefix, const char *name, const ptrdiff_t name_len,
                           const VarType type, const char *string, int *first)
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
      string++;
    }
  } else if (type == VAR_DICT) {
    msg_putchar('{');
    if (*string == '{') {
      string++;
    }
  } else {
    msg_putchar(' ');
  }

  msg_outtrans((char *)string);

  if (type == VAR_FUNC || type == VAR_PARTIAL) {
    msg_puts("()");
  }
  if (*first) {
    msg_clr_eos();
    *first = false;
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
void set_var_const(const char *name, const size_t name_len, typval_T *const tv, const bool copy,
                   const bool is_const)
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
    if (is_vimvarht(ht)) {
      if (v->di_tv.v_type == VAR_STRING) {
        XFREE_CLEAR(v->di_tv.vval.v_string);
        if (copy || tv->v_type != VAR_STRING) {
          const char *const val = tv_get_string(tv);

          // Careful: when assigning to v:errmsg and tv_get_string()
          // causes an error message the variable will already be set.
          if (v->di_tv.vval.v_string == NULL) {
            v->di_tv.vval.v_string = xstrdup(val);
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
          redraw_all_later(UPD_SOME_VALID);
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
    if (is_vimvarht(ht) || ht == get_funccal_args_ht()) {
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
  if (!(vim_strchr("wbst", name[0]) != NULL && name[1] == ':')
      && !ASCII_ISUPPER((name[0] != NUL && name[1] == ':')
                        ? name[2] : name[0])) {
    semsg(_("E704: Funcref variable name must start with a capital: %s"), name);
    return false;
  }
  // Don't allow hiding a function.  When "v" is not NULL we might be
  // assigning another function to the same var, the type is checked
  // below.
  if (new_var && function_exists(name, false)) {
    semsg(_("E705: Variable name conflicts with existing function: %s"), name);
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

/// Implements the logic to retrieve local variable and option values.
/// Used by "getwinvar()" "gettabvar()" "gettabwinvar()" "getbufvar()".
///
/// @param deftv   default value if not found
/// @param htname  't'ab, 'w'indow or 'b'uffer local
/// @param tp      can be NULL
/// @param buf     ignored if htname is not 'b'
static void get_var_from(const char *varname, typval_T *rettv, typval_T *deftv, int htname,
                         tabpage_T *tp, win_T *win, buf_T *buf)
{
  bool done = false;
  const bool do_change_curbuf = buf != NULL && htname == 'b';

  emsg_off++;

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;

  if (varname != NULL && tp != NULL && win != NULL && (htname != 'b' || buf != NULL)) {
    // Set curwin to be our win, temporarily.  Also set the tabpage,
    // otherwise the window is not valid. Only do this when needed,
    // autocommands get blocked.
    // If we have a buffer reference avoid the switching, we're saving and
    // restoring curbuf directly.
    const bool need_switch_win = !(tp == curtab && win == curwin) && !do_change_curbuf;
    switchwin_T switchwin;
    if (!need_switch_win || switch_win(&switchwin, win, tp, true) == OK) {
      if (*varname == '&' && htname != 't') {
        buf_T *const save_curbuf = curbuf;

        // Change curbuf so the option is read from the correct buffer.
        if (do_change_curbuf) {
          curbuf = buf;
        }

        if (varname[1] == NUL) {
          // get all window-local or buffer-local options in a dict
          dict_T *opts = get_winbuf_options(htname == 'b');

          if (opts != NULL) {
            tv_dict_set_ret(rettv, opts);
            done = true;
          }
        } else if (get_option_tv(&varname, rettv, true) == OK) {
          // Local option
          done = true;
        }

        curbuf = save_curbuf;
      } else if (*varname == NUL) {
        const ScopeDictDictItem *v;
        // Empty string: return a dict with all the local variables.
        if (htname == 'b') {
          v = &buf->b_bufvar;
        } else if (htname == 'w') {
          v = &win->w_winvar;
        } else {
          v = &tp->tp_winvar;
        }
        tv_copy(&v->di_tv, rettv);
        done = true;
      } else {
        hashtab_T *ht;

        if (htname == 'b') {
          ht = &buf->b_vars->dv_hashtab;
        } else if (htname == 'w') {
          ht = &win->w_vars->dv_hashtab;
        } else {
          ht = &tp->tp_vars->dv_hashtab;
        }

        // Look up the variable.
        const dictitem_T *const v = find_var_in_ht(ht, htname, varname, strlen(varname), false);
        if (v != NULL) {
          tv_copy(&v->di_tv, rettv);
          done = true;
        }
      }
    }

    if (need_switch_win) {
      // restore previous notion of curwin
      restore_win(&switchwin, true);
    }
  }

  if (!done && deftv->v_type != VAR_UNKNOWN) {
    // use the default value
    tv_copy(deftv, rettv);
  }

  emsg_off--;
}

/// getwinvar() and gettabwinvar()
///
/// @param off  1 for gettabwinvar()
static void getwinvar(typval_T *argvars, typval_T *rettv, int off)
{
  tabpage_T *tp;

  if (off == 1) {
    tp = find_tabpage((int)tv_get_number_chk(&argvars[0], NULL));
  } else {
    tp = curtab;
  }
  win_T *const win = find_win_by_nr(&argvars[off], tp);
  const char *const varname = tv_get_string_chk(&argvars[off + 1]);

  get_var_from(varname, rettv, &argvars[off + 2], 'w', tp, win, NULL);
}

/// Set option "varname" to the value of "varp" for the current buffer/window.
static void set_option_from_tv(const char *varname, typval_T *varp)
{
  long numval = 0;
  const char *strval;
  bool error = false;
  char nbuf[NUMBUFLEN];

  if (varp->v_type == VAR_BOOL) {
    if (is_string_option(varname)) {
      emsg(_(e_stringreq));
      return;
    }
    numval = (long)varp->vval.v_number;
    strval = "0";  // avoid using "false"
  } else {
    numval = (long)tv_get_number_chk(varp, &error);
    strval = tv_get_string_buf_chk(varp, nbuf);
  }
  if (!error && strval != NULL) {
    set_option_value_give_err(varname, numval, strval, OPT_LOCAL);
  }
}

/// "setwinvar()" and "settabwinvar()" functions
static void setwinvar(typval_T *argvars, typval_T *rettv, int off)
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
    bool need_switch_win = !(tp == curtab && win == curwin);
    switchwin_T switchwin;
    if (!need_switch_win || switch_win(&switchwin, win, tp, true) == OK) {
      if (*varname == '&') {
        set_option_from_tv(varname + 1, varp);
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
      restore_win(&switchwin, true);
    }
  }
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
      n = handle_subscript(&var, &tv, true, false, name, &name) == OK;
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

/// "gettabvar()" function
void f_gettabvar(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *const varname = tv_get_string_chk(&argvars[1]);
  tabpage_T *const tp = find_tabpage((int)tv_get_number_chk(&argvars[0], NULL));
  win_T *win = NULL;

  if (tp != NULL) {
    win = tp == curtab || tp->tp_firstwin == NULL ? firstwin : tp->tp_firstwin;
  }

  get_var_from(varname, rettv, &argvars[2], 't', tp, win, NULL);
}

/// "gettabwinvar()" function
void f_gettabwinvar(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  getwinvar(argvars, rettv, 1);
}

/// "getwinvar()" function
void f_getwinvar(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  getwinvar(argvars, rettv, 0);
}

/// "getbufvar()" function
void f_getbufvar(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *const varname = tv_get_string_chk(&argvars[1]);
  buf_T *const buf = tv_get_buf_from_arg(&argvars[0]);

  get_var_from(varname, rettv, &argvars[2], 'b', curtab, curwin, buf);
}

/// "settabvar()" function
void f_settabvar(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = 0;

  if (check_secure()) {
    return;
  }

  tabpage_T *const tp = find_tabpage((int)tv_get_number_chk(&argvars[0], NULL));
  const char *const varname = tv_get_string_chk(&argvars[1]);
  typval_T *const varp = &argvars[2];

  if (varname != NULL && tp != NULL) {
    tabpage_T *const save_curtab = curtab;
    goto_tabpage_tp(tp, false, false);

    const size_t varname_len = strlen(varname);
    char *const tabvarname = xmalloc(varname_len + 3);
    memcpy(tabvarname, "t:", 2);
    memcpy(tabvarname + 2, varname, varname_len + 1);
    set_var(tabvarname, varname_len + 2, varp, true);
    xfree(tabvarname);

    // Restore current tabpage.
    if (valid_tabpage(save_curtab)) {
      goto_tabpage_tp(save_curtab, false, false);
    }
  }
}

/// "settabwinvar()" function
void f_settabwinvar(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  setwinvar(argvars, rettv, 1);
}

/// "setwinvar()" function
void f_setwinvar(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  setwinvar(argvars, rettv, 0);
}

/// "setbufvar()" function
void f_setbufvar(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (check_secure()
      || !tv_check_str_or_nr(&argvars[0])) {
    return;
  }
  const char *varname = tv_get_string_chk(&argvars[1]);
  buf_T *const buf = tv_get_buf(&argvars[0], false);
  typval_T *varp = &argvars[2];

  if (buf != NULL && varname != NULL) {
    if (*varname == '&') {
      aco_save_T aco;

      // set curbuf to be our buf, temporarily
      aucmd_prepbuf(&aco, buf);

      set_option_from_tv(varname + 1, varp);

      // reset notion of buffer
      aucmd_restbuf(&aco);
    } else {
      const size_t varname_len = strlen(varname);
      char *const bufvarname = xmalloc(varname_len + 3);
      buf_T *const save_curbuf = curbuf;
      curbuf = buf;
      memcpy(bufvarname, "b:", 2);
      memcpy(bufvarname + 2, varname, varname_len + 1);
      set_var(bufvarname, varname_len + 2, varp, true);
      xfree(bufvarname);
      curbuf = save_curbuf;
    }
  }
}
