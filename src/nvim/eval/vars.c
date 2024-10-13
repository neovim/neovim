// eval/vars.c: functions for dealing with variables

#include <assert.h>
#include <ctype.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <uv.h>

#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/encode.h"
#include "nvim/eval/funcs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/userfunc.h"
#include "nvim/eval/vars.h"
#include "nvim/eval/window.h"
#include "nvim/eval_defs.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/garray.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/hashtab.h"
#include "nvim/macros_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/os/os.h"
#include "nvim/search.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

typedef int (*ex_unletlock_callback)(lval_T *, char *, exarg_T *, int);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/vars.c.generated.h"
#endif

// TODO(ZyX-I): Remove DICT_MAXNEST, make users be non-recursive instead

#define DICT_MAXNEST 100        // maximum nesting of lists and dicts

static const char *e_letunexp = N_("E18: Unexpected characters in :let");
static const char e_double_semicolon_in_list_of_variables[]
  = N_("E452: Double ; in list of variables");
static const char *e_lock_unlock = N_("E940: Cannot lock or unlock variable %s");
static const char e_setting_v_str_to_value_with_wrong_type[]
  = N_("E963: Setting v:%s to value with wrong type");
static const char e_missing_end_marker_str[] = N_("E990: Missing end marker '%s'");
static const char e_cannot_use_heredoc_here[] = N_("E991: Cannot use =<< here");

/// Evaluate one Vim expression {expr} in string "p" and append the
/// resulting string to "gap".  "p" points to the opening "{".
/// When "evaluate" is false only skip over the expression.
/// Return a pointer to the character after "}", NULL for an error.
char *eval_one_expr_in_str(char *p, garray_T *gap, bool evaluate)
{
  char *block_start = skipwhite(p + 1);  // skip the opening {
  char *block_end = block_start;

  if (*block_start == NUL) {
    semsg(_(e_missing_close_curly_str), p);
    return NULL;
  }
  if (skip_expr(&block_end, NULL) == FAIL) {
    return NULL;
  }
  block_end = skipwhite(block_end);
  if (*block_end != '}') {
    semsg(_(e_missing_close_curly_str), p);
    return NULL;
  }
  if (evaluate) {
    *block_end = NUL;
    char *expr_val = eval_to_string(block_start, false, false);
    *block_end = '}';
    if (expr_val == NULL) {
      return NULL;
    }
    ga_concat(gap, expr_val);
    xfree(expr_val);
  }

  return block_end + 1;
}

/// Evaluate all the Vim expressions {expr} in "str" and return the resulting
/// string in allocated memory.  "{{" is reduced to "{" and "}}" to "}".
/// Used for a heredoc assignment.
/// Returns NULL for an error.
static char *eval_all_expr_in_str(char *str)
{
  garray_T ga;
  ga_init(&ga, 1, 80);
  char *p = str;

  while (*p != NUL) {
    bool escaped_brace = false;

    // Look for a block start.
    char *lit_start = p;
    while (*p != '{' && *p != '}' && *p != NUL) {
      p++;
    }

    if (*p != NUL && *p == p[1]) {
      // Escaped brace, unescape and continue.
      // Include the brace in the literal string.
      p++;
      escaped_brace = true;
    } else if (*p == '}') {
      semsg(_(e_stray_closing_curly_str), str);
      ga_clear(&ga);
      return NULL;
    }

    // Append the literal part.
    ga_concat_len(&ga, lit_start, (size_t)(p - lit_start));

    if (*p == NUL) {
      break;
    }

    if (escaped_brace) {
      // Skip the second brace.
      p++;
      continue;
    }

    // Evaluate the expression and append the result.
    p = eval_one_expr_in_str(p, &ga, true);
    if (p == NULL) {
      ga_clear(&ga);
      return NULL;
    }
  }
  ga_append(&ga, NUL);

  return ga.ga_data;
}

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
/// When getting lines for an embedded script (e.g. python, lua, perl, ruby,
/// tcl, mzscheme), "script_get" is set to true. In this case, if the marker is
/// missing, then '.' is accepted as a marker.
///
/// @return  a List with {lines} or NULL on failure.
list_T *heredoc_get(exarg_T *eap, char *cmd, bool script_get)
{
  char *marker;
  int marker_indent_len = 0;
  int text_indent_len = 0;
  char *text_indent = NULL;
  char dot[] = ".";
  bool heredoc_in_string = false;
  char *line_arg = NULL;
  char *nl_ptr = vim_strchr(cmd, '\n');

  if (nl_ptr != NULL) {
    heredoc_in_string = true;
    line_arg = nl_ptr + 1;
    *nl_ptr = NUL;
  } else if (eap->ea_getline == NULL) {
    emsg(_(e_cannot_use_heredoc_here));
    return NULL;
  }

  // Check for the optional 'trim' word before the marker
  cmd = skipwhite(cmd);
  bool evalstr = false;
  bool eval_failed = false;
  while (true) {
    if (strncmp(cmd, "trim", 4) == 0
        && (cmd[4] == NUL || ascii_iswhite(cmd[4]))) {
      cmd = skipwhite(cmd + 4);

      // Trim the indentation from all the lines in the here document.
      // The amount of indentation trimmed is the same as the indentation
      // of the first line after the :let command line.  To find the end
      // marker the indent of the :let command line is trimmed.
      char *p = *eap->cmdlinep;
      while (ascii_iswhite(*p)) {
        p++;
        marker_indent_len++;
      }
      text_indent_len = -1;

      continue;
    }
    if (strncmp(cmd, "eval", 4) == 0
        && (cmd[4] == NUL || ascii_iswhite(cmd[4]))) {
      cmd = skipwhite(cmd + 4);
      evalstr = true;
      continue;
    }
    break;
  }

  const char comment_char = '"';
  // The marker is the next word.
  if (*cmd != NUL && *cmd != comment_char) {
    marker = skipwhite(cmd);
    char *p = skiptowhite(marker);
    if (*skipwhite(p) != NUL && *skipwhite(p) != comment_char) {
      semsg(_(e_trailing_arg), p);
      return NULL;
    }
    *p = NUL;
    if (!script_get && islower((uint8_t)(*marker))) {
      emsg(_("E221: Marker cannot start with lower case letter"));
      return NULL;
    }
  } else {
    // When getting lines for an embedded script, if the marker is missing,
    // accept '.' as the marker.
    if (script_get) {
      marker = dot;
    } else {
      emsg(_("E172: Missing marker"));
      return NULL;
    }
  }

  char *theline = NULL;
  list_T *l = tv_list_alloc(0);
  while (true) {
    int mi = 0;
    int ti = 0;

    if (heredoc_in_string) {
      // heredoc in a string separated by newlines.  Get the next line
      // from the string.

      if (*line_arg == NUL) {
        if (!script_get) {
          semsg(_(e_missing_end_marker_str), marker);
        }
        break;
      }

      theline = line_arg;
      char *next_line = vim_strchr(theline, '\n');
      if (next_line == NULL) {
        line_arg += strlen(line_arg);
      } else {
        *next_line = NUL;
        line_arg = next_line + 1;
      }
    } else {
      xfree(theline);
      theline = eap->ea_getline(NUL, eap->cookie, 0, false);
      if (theline == NULL) {
        if (!script_get) {
          semsg(_(e_missing_end_marker_str), marker);
        }
        break;
      }
    }

    // with "trim": skip the indent matching the :let line to find the
    // marker
    if (marker_indent_len > 0
        && strncmp(theline, *eap->cmdlinep, (size_t)marker_indent_len) == 0) {
      mi = marker_indent_len;
    }
    if (strcmp(marker, theline + mi) == 0) {
      break;
    }

    // If expression evaluation failed in the heredoc, then skip till the
    // end marker.
    if (eval_failed) {
      continue;
    }

    if (text_indent_len == -1 && *theline != NUL) {
      // set the text indent from the first line.
      char *p = theline;
      text_indent_len = 0;
      while (ascii_iswhite(*p)) {
        p++;
        text_indent_len++;
      }
      text_indent = xmemdupz(theline, (size_t)text_indent_len);
    }
    // with "trim": skip the indent matching the first line
    if (text_indent != NULL) {
      for (ti = 0; ti < text_indent_len; ti++) {
        if (theline[ti] != text_indent[ti]) {
          break;
        }
      }
    }

    char *str = theline + ti;
    if (evalstr && !eap->skip) {
      str = eval_all_expr_in_str(str);
      if (str == NULL) {
        // expression evaluation failed
        eval_failed = true;
        continue;
      }
      tv_list_append_allocated_string(l, str);
    } else {
      tv_list_append_string(l, str, -1);
    }
  }
  if (heredoc_in_string) {
    // Next command follows the heredoc in the string.
    eap->nextcmd = line_arg;
  } else {
    xfree(theline);
  }
  xfree(text_indent);

  if (eval_failed) {
    // expression evaluation in the heredoc failed
    tv_list_free(l);
    return NULL;
  }
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
///
/// ":cons[t] var = expr1" define constant
/// ":cons[t] [name1, name2, ...] = expr1" define constants unpacking list
/// ":cons[t] [name, ..., ; lastname] = expr" define constants unpacking list
void ex_let(exarg_T *eap)
{
  const bool is_const = eap->cmdidx == CMD_const;
  char *arg = eap->arg;
  char *expr = NULL;
  typval_T rettv;
  int var_count = 0;
  int semicolon = 0;
  char op[2];
  const char *argend;
  int first = true;

  argend = skip_var_list(arg, &var_count, &semicolon, false);
  if (argend == NULL) {
    return;
  }
  if (argend > arg && argend[-1] == '.') {  // For var.='str'.
    argend--;
  }
  expr = skipwhite(argend);
  bool concat = strncmp(expr, "..=", 3) == 0;
  bool has_assign = *expr == '=' || (vim_strchr("+-*/%.", (uint8_t)(*expr)) != NULL
                                     && expr[1] == '=');
  if (!has_assign && !concat) {
    // ":let" without "=": list variables
    if (*arg == '[') {
      emsg(_(e_invarg));
    } else if (!ends_excmd(*arg)) {
      // ":let var1 var2"
      arg = (char *)list_arg_vars(eap, arg, &first);
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
    return;
  }

  if (expr[0] == '=' && expr[1] == '<' && expr[2] == '<') {
    // HERE document
    list_T *l = heredoc_get(eap, expr + 3, false);
    if (l != NULL) {
      tv_list_set_ret(&rettv, l);
      if (!eap->skip) {
        op[0] = '=';
        op[1] = NUL;
        ex_let_vars(eap->arg, &rettv, false, semicolon, var_count, is_const, op);
      }
      tv_clear(&rettv);
    }
    return;
  }

  rettv.v_type = VAR_UNKNOWN;

  op[0] = '=';
  op[1] = NUL;
  if (*expr != '=') {
    if (vim_strchr("+-*/%.", (uint8_t)(*expr)) != NULL) {
      op[0] = *expr;  // +=, -=, *=, /=, %= or .=
      if (expr[0] == '.' && expr[1] == '.') {  // ..=
        expr++;
      }
    }
    expr += 2;
  } else {
    expr += 1;
  }

  expr = skipwhite(expr);

  if (eap->skip) {
    emsg_skip++;
  }
  evalarg_T evalarg;
  fill_evalarg_from_eap(&evalarg, eap, eap->skip);
  int eval_res = eval0(expr, &rettv, eap, &evalarg);
  if (eap->skip) {
    emsg_skip--;
  }
  clear_evalarg(&evalarg, eap);

  if (!eap->skip && eval_res != FAIL) {
    ex_let_vars(eap->arg, &rettv, false, semicolon, var_count, is_const, op);
  }
  if (eval_res != FAIL) {
    tv_clear(&rettv);
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
/// for "[var, var; var]" set "semicolon" to 1.
/// If "silent" is true do not give an "invalid argument" error message.
///
/// @return  NULL for an error.
const char *skip_var_list(const char *arg, int *var_count, int *semicolon, bool silent)
{
  if (*arg == '[') {
    const char *s;
    // "[var, var]": find the matching ']'.
    const char *p = arg;
    while (true) {
      p = skipwhite(p + 1);             // skip whites after '[', ';' or ','
      s = skip_var_one(p);
      if (s == p) {
        if (!silent) {
          semsg(_(e_invarg2), p);
        }
        return NULL;
      }
      (*var_count)++;

      p = skipwhite(s);
      if (*p == ']') {
        break;
      } else if (*p == ';') {
        if (*semicolon == 1) {
          if (!silent) {
            emsg(_(e_double_semicolon_in_list_of_variables));
          }
          return NULL;
        }
        *semicolon = 1;
      } else if (*p != ',') {
        if (!silent) {
          semsg(_(e_invarg2), p);
        }
        return NULL;
      }
    }
    return p + 1;
  }
  return skip_var_one(arg);
}

/// Skip one (assignable) variable name, including @r, $VAR, &option, d.key,
/// l[idx].
static const char *skip_var_one(const char *arg)
{
  if (*arg == '@' && arg[1] != NUL) {
    return arg + 2;
  }
  return find_name_end(*arg == '$' || *arg == '&' ? arg + 1 : arg,
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
      xstrlcat(buf, di->di_key, IOSIZE);
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
  bool error = false;
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
        if (eval_variable(name, len, &tv, NULL, true, false) == FAIL) {
          error = true;
        } else {
          // handle d.key, l[idx], f(expr)
          const char *const arg_subsc = arg;
          if (handle_subscript(&arg, &tv, &EVALARG_EVALUATE, true) == FAIL) {
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

    arg = skipwhite(arg);
  }

  return arg;
}

/// Set an environment variable, part of ex_let_one().
static char *ex_let_env(char *arg, typval_T *const tv, const bool is_const,
                        const char *const endchars, const char *const op)
  FUNC_ATTR_NONNULL_ARG(1, 2) FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (is_const) {
    emsg(_("E996: Cannot lock an environment variable"));
    return NULL;
  }

  // Find the end of the name.
  char *arg_end = NULL;
  arg++;
  char *name = arg;
  int len = get_env_len((const char **)&arg);
  if (len == 0) {
    semsg(_(e_invarg2), name - 1);
  } else {
    if (op != NULL && vim_strchr("+-*/%", (uint8_t)(*op)) != NULL) {
      semsg(_(e_letwrong), op);
    } else if (endchars != NULL
               && vim_strchr(endchars, (uint8_t)(*skipwhite(arg))) == NULL) {
      emsg(_(e_letunexp));
    } else if (!check_secure()) {
      char *tofree = NULL;
      const char c1 = name[len];
      name[len] = NUL;
      const char *p = tv_get_string_chk(tv);
      if (p != NULL && op != NULL && *op == '.') {
        char *s = vim_getenv(name);
        if (s != NULL) {
          tofree = concat_str(s, p);
          p = tofree;
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
  return arg_end;
}

/// Set an option, part of ex_let_one().
static char *ex_let_option(char *arg, typval_T *const tv, const bool is_const,
                           const char *const endchars, const char *const op)
  FUNC_ATTR_NONNULL_ARG(1, 2) FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (is_const) {
    emsg(_("E996: Cannot lock an option"));
    return NULL;
  }

  // Find the end of the name.
  char *arg_end = NULL;
  OptIndex opt_idx;
  int scope;

  char *const p = (char *)find_option_var_end((const char **)&arg, &opt_idx, &scope);

  if (p == NULL || (endchars != NULL && vim_strchr(endchars, (uint8_t)(*skipwhite(p))) == NULL)) {
    emsg(_(e_letunexp));
    return NULL;
  }

  const char c1 = *p;
  *p = NUL;

  bool is_tty_opt = is_tty_option(arg);
  bool hidden = is_option_hidden(opt_idx);
  OptVal curval = is_tty_opt ? get_tty_option(arg) : get_option_value(opt_idx, scope);
  OptVal newval = NIL_OPTVAL;

  if (curval.type == kOptValTypeNil) {
    semsg(_(e_unknown_option2), arg);
    goto theend;
  }
  if (op != NULL && *op != '='
      && ((curval.type != kOptValTypeString && *op == '.')
          || (curval.type == kOptValTypeString && *op != '.'))) {
    semsg(_(e_letwrong), op);
    goto theend;
  }

  bool error;
  newval = tv_to_optval(tv, opt_idx, arg, &error);
  if (error) {
    goto theend;
  }

  // Don't assume current and new values are of the same type in order to future-proof the code for
  // when an option can have multiple types.
  const bool is_num = ((curval.type == kOptValTypeNumber || curval.type == kOptValTypeBoolean)
                       && (newval.type == kOptValTypeNumber || newval.type == kOptValTypeBoolean));
  const bool is_string = curval.type == kOptValTypeString && newval.type == kOptValTypeString;

  if (op != NULL && *op != '=') {
    if (!hidden && is_num) {  // number or bool
      OptInt cur_n = curval.type == kOptValTypeNumber ? curval.data.number : curval.data.boolean;
      OptInt new_n = newval.type == kOptValTypeNumber ? newval.data.number : newval.data.boolean;

      switch (*op) {
      case '+':
        new_n = cur_n + new_n; break;
      case '-':
        new_n = cur_n - new_n; break;
      case '*':
        new_n = cur_n * new_n; break;
      case '/':
        new_n = num_divide(cur_n, new_n); break;
      case '%':
        new_n = num_modulus(cur_n, new_n); break;
      }

      if (curval.type == kOptValTypeNumber) {
        newval = NUMBER_OPTVAL(new_n);
      } else {
        newval = BOOLEAN_OPTVAL(TRISTATE_FROM_INT(new_n));
      }
    } else if (!hidden && is_string
               && curval.data.string.data != NULL && newval.data.string.data != NULL) {  // string
      OptVal newval_old = newval;
      newval = CSTR_AS_OPTVAL(concat_str(curval.data.string.data, newval.data.string.data));
      optval_free(newval_old);
    }
  }

  const char *err = set_option_value_handle_tty(arg, opt_idx, newval, scope);
  arg_end = p;
  if (err != NULL) {
    emsg(_(err));
  }

theend:
  *p = c1;
  optval_free(curval);
  optval_free(newval);
  return arg_end;
}

/// Set a register, part of ex_let_one().
static char *ex_let_register(char *arg, typval_T *const tv, const bool is_const,
                             const char *const endchars, const char *const op)
  FUNC_ATTR_NONNULL_ARG(1, 2) FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (is_const) {
    emsg(_("E996: Cannot lock a register"));
    return NULL;
  }

  char *arg_end = NULL;
  arg++;
  if (op != NULL && vim_strchr("+-*/%", (uint8_t)(*op)) != NULL) {
    semsg(_(e_letwrong), op);
  } else if (endchars != NULL
             && vim_strchr(endchars, (uint8_t)(*skipwhite(arg + 1))) == NULL) {
    emsg(_(e_letunexp));
  } else {
    char *ptofree = NULL;
    const char *p = tv_get_string_chk(tv);
    if (p != NULL && op != NULL && *op == '.') {
      char *s = get_reg_contents(*arg == '@' ? '"' : *arg, kGRegExprSrc);
      if (s != NULL) {
        ptofree = concat_str(s, p);
        p = ptofree;
        xfree(s);
      }
    }
    if (p != NULL) {
      write_reg_contents(*arg == '@' ? '"' : *arg, p, (ssize_t)strlen(p), false);
      arg_end = arg + 1;
    }
    xfree(ptofree);
  }
  return arg_end;
}

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

  if (*arg == '$') {
    // ":let $VAR = expr": Set environment variable.
    return ex_let_env(arg, tv, is_const, endchars, op);
  } else if (*arg == '&') {
    // ":let &option = expr": Set option value.
    // ":let &l:option = expr": Set local option value.
    // ":let &g:option = expr": Set global option value.
    return ex_let_option(arg, tv, is_const, endchars, op);
  } else if (*arg == '@') {
    // ":let @r = expr": Set register contents.
    return ex_let_register(arg, tv, is_const, endchars, op);
  } else if (eval_isnamec1(*arg) || *arg == '{') {
    // ":let var = expr": Set internal variable.
    // ":let {expr} = expr": Idem, name made with curly braces
    lval_T lv;
    char *const p = get_lval(arg, tv, &lv, false, false, 0, FNE_CHECK_START);
    if (p != NULL && lv.ll_name != NULL) {
      if (endchars != NULL && vim_strchr(endchars, (uint8_t)(*skipwhite(p))) == NULL) {
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
      lv.ll_name = arg;
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

  if (lp->ll_tv == NULL) {
    int cc = (uint8_t)(*name_end);
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
              && value_check_lock(tv_list_locked(lp->ll_list),
                                  lp->ll_name,
                                  lp->ll_name_len))
             || (lp->ll_dict != NULL
                 && value_check_lock(lp->ll_dict->dv_lock,
                                     lp->ll_name,
                                     lp->ll_name_len))) {
    return FAIL;
  } else if (lp->ll_range) {
    tv_list_unlet_range(lp->ll_list, lp->ll_li, lp->ll_n1, !lp->ll_empty2, lp->ll_n2);
  } else if (lp->ll_list != NULL) {
    // unlet a List item.
    tv_list_item_remove(lp->ll_list, lp->ll_li);
  } else {
    // unlet a Dict item.
    dict_T *d = lp->ll_dict;
    assert(d != NULL);
    dictitem_T *di = lp->ll_di;
    bool watched = tv_dict_is_watched(d);
    char *key = NULL;
    typval_T oldtv;

    if (watched) {
      tv_copy(&di->di_tv, &oldtv);
      // need to save key because dictitem_remove will free it
      key = xstrdup(di->di_key);
    }

    tv_dict_item_remove(d, di);

    if (watched) {
      tv_dict_watcher_notify(d, key, NULL, &oldtv);
      tv_clear(&oldtv);
      xfree(key);
    }
  }

  return ret;
}

/// Unlet one item or a range of items from a list.
/// Return OK or FAIL.
static void tv_list_unlet_range(list_T *const l, listitem_T *const li_first, const int n1_arg,
                                const bool has_n2, const int n2)
{
  assert(l != NULL);
  // Delete a range of List items.
  listitem_T *li_last = li_first;
  int n1 = n1_arg;
  while (true) {
    listitem_T *const li = TV_LIST_ITEM_NEXT(l, li_last);
    n1++;
    if (li == NULL || (has_n2 && n2 < n1)) {
      break;
    }
    li_last = li;
  }
  tv_list_remove_items(l, li_first, li_last);
}

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
          || value_check_lock(d->dv_lock, name, TV_CSTRING)) {
        return FAIL;
      }

      if (value_check_lock(d->dv_lock, name, TV_CSTRING)) {
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
        if (deep != 0) {
          tv_item_lock(&di->di_tv, deep, lock, false);
        }
      }
    }
  } else if (deep == 0) {
    // nothing to do
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
    // (un)lock a Dict item.
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
int eval_variable(const char *name, int len, typval_T *rettv, dictitem_T **dip, bool verbose,
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
char *get_var_value(const char *const name)
{
  dictitem_T *v;

  v = find_var(name, strlen(name), NULL, false);
  if (v == NULL) {
    return NULL;
  }
  return (char *)tv_get_string(&v->di_tv);
}

/// Clean up a list of internal variables.
/// Frees all allocated variables and the value they contain.
/// Clears hashtab "ht", does not free it.
void vars_clear(hashtab_T *ht)
{
  vars_clear_ext(ht, true);
}

/// Like vars_clear(), but only free the value if "free_val" is true.
void vars_clear_ext(hashtab_T *ht, bool free_val)
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
  hash_init(ht);
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
  list_one_var_a(prefix, v->di_key, (ptrdiff_t)strlen(v->di_key),
                 v->di_tv.v_type, (s == NULL ? "" : s), first);
  xfree(s);
}

/// @param[in]  name_len  Length of the name. May be -1, in this case strlen()
///                       will be used.
/// @param[in,out]  first  When true clear rest of screen and set to false.
static void list_one_var_a(const char *prefix, const char *name, const ptrdiff_t name_len,
                           const VarType type, const char *string, int *first)
{
  // don't use msg() to avoid overwriting "v:statusmsg"
  msg_start();
  msg_puts(prefix);
  if (name != NULL) {  // "a:" vars don't have a name stored
    msg_puts_len(name, name_len, 0);
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

  msg_outtrans(string, 0);

  if (type == VAR_FUNC || type == VAR_PARTIAL) {
    msg_puts("()");
  }
  if (*first) {
    msg_clr_eos();
    *first = false;
  }
}

/// Additional handling for setting a v: variable.
///
/// @return  true if the variable should be set normally,
///          false if nothing else needs to be done.
bool before_set_vvar(const char *const varname, dictitem_T *const di, typval_T *const tv,
                     const bool copy, const bool watched, bool *const type_error)
{
  if (di->di_tv.v_type == VAR_STRING) {
    typval_T oldtv = TV_INITIAL_VALUE;
    if (watched) {
      tv_copy(&di->di_tv, &oldtv);
    }
    XFREE_CLEAR(di->di_tv.vval.v_string);
    if (copy || tv->v_type != VAR_STRING) {
      const char *const val = tv_get_string(tv);
      // Careful: when assigning to v:errmsg and tv_get_string()
      // causes an error message the variable will already be set.
      if (di->di_tv.vval.v_string == NULL) {
        di->di_tv.vval.v_string = xstrdup(val);
      }
    } else {
      // Take over the string to avoid an extra alloc/free.
      di->di_tv.vval.v_string = tv->vval.v_string;
      tv->vval.v_string = NULL;
    }
    // Notify watchers
    if (watched) {
      tv_dict_watcher_notify(&vimvardict, varname, &di->di_tv, &oldtv);
      tv_clear(&oldtv);
    }
    return false;
  } else if (di->di_tv.v_type == VAR_NUMBER) {
    typval_T oldtv = TV_INITIAL_VALUE;
    if (watched) {
      tv_copy(&di->di_tv, &oldtv);
    }
    di->di_tv.vval.v_number = tv_get_number(tv);
    if (strcmp(varname, "searchforward") == 0) {
      set_search_direction(di->di_tv.vval.v_number ? '/' : '?');
    } else if (strcmp(varname, "hlsearch") == 0) {
      no_hlsearch = !di->di_tv.vval.v_number;
      redraw_all_later(UPD_SOME_VALID);
    }
    // Notify watchers
    if (watched) {
      tv_dict_watcher_notify(&vimvardict, varname, &di->di_tv, &oldtv);
      tv_clear(&oldtv);
    }
    return false;
  } else if (di->di_tv.v_type != tv->v_type) {
    *type_error = true;
    return false;
  }
  return true;
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
  const char *varname;
  dict_T *dict;
  hashtab_T *ht = find_var_ht_dict(name, name_len, &varname, &dict);
  const bool watched = tv_dict_is_watched(dict);

  if (ht == NULL || *varname == NUL) {
    semsg(_(e_illvar), name);
    return;
  }
  const size_t varname_len = name_len - (size_t)(varname - name);
  dictitem_T *di = find_var_in_ht(ht, 0, varname, varname_len, true);

  // Search in parent scope which is possible to reference from lambda
  if (di == NULL) {
    di = find_var_in_scoped_ht(name, name_len, true);
  }

  if (tv_is_func(*tv) && var_wrong_func_name(name, di == NULL)) {
    return;
  }

  typval_T oldtv = TV_INITIAL_VALUE;
  if (di != NULL) {
    if (is_const) {
      emsg(_(e_cannot_mod));
      return;
    }

    // Check in this order for backwards compatibility:
    // - Whether the variable is read-only
    // - Whether the variable value is locked
    // - Whether the variable is locked
    if (var_check_ro(di->di_flags, name, name_len)
        || value_check_lock(di->di_tv.v_lock, name, name_len)
        || var_check_lock(di->di_flags, name, name_len)) {
      return;
    }

    // existing variable, need to clear the value

    // Handle setting internal v: variables separately where needed to
    // prevent changing the type.
    bool type_error = false;
    if (is_vimvarht(ht)
        && !before_set_vvar(varname, di, tv, copy, watched, &type_error)) {
      if (type_error) {
        semsg(_(e_setting_v_str_to_value_with_wrong_type), varname);
      }
      return;
    }

    if (watched) {
      tv_copy(&di->di_tv, &oldtv);
    }
    tv_clear(&di->di_tv);
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

    di = xmalloc(offsetof(dictitem_T, di_key) + varname_len + 1);
    memcpy(di->di_key, varname, varname_len + 1);
    if (hash_add(ht, di->di_key) == FAIL) {
      xfree(di);
      return;
    }
    di->di_flags = DI_FLAGS_ALLOC;
    if (is_const) {
      di->di_flags |= DI_FLAGS_LOCK;
    }
  }

  if (copy || tv->v_type == VAR_NUMBER || tv->v_type == VAR_FLOAT) {
    tv_copy(tv, &di->di_tv);
  } else {
    di->di_tv = *tv;
    di->di_tv.v_lock = VAR_UNLOCKED;
    tv_init(tv);
  }

  if (watched) {
    tv_dict_watcher_notify(dict, di->di_key, &di->di_tv, &oldtv);
    tv_clear(&oldtv);
  }

  if (is_const) {
    // Like :lockvar! name: lock the value and what it contains, but only
    // if the reference count is up to one.  That locks only literal
    // values.
    tv_item_lock(&di->di_tv, DICT_MAXNEST, true, true);
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

/// Return true if di_flags "flags" indicates variable "name" is locked.
/// Also give an error message.
bool var_check_lock(const int flags, const char *name, size_t name_len)
{
  if (!(flags & DI_FLAGS_LOCK)) {
    return false;
  }

  if (name_len == TV_TRANSLATE) {
    name = _(name);
    name_len = strlen(name);
  } else if (name_len == TV_CSTRING) {
    name_len = strlen(name);
  }

  semsg(_("E1122: Variable is locked: %*s"), (int)name_len, name);

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

/// Check if name is a valid name to assign funcref to
///
/// @param[in]  name  Possible function/funcref name.
/// @param[in]  new_var  True if it is a name for a variable.
///
/// @return false in case of success, true in case of failure. Also gives an
///         error message if appropriate.
bool var_wrong_func_name(const char *const name, const bool new_var)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  // Allow for w: b: s: and t:.
  // Allow autoload variable.
  if (!(vim_strchr("wbst", (uint8_t)name[0]) != NULL && name[1] == ':')
      && !ASCII_ISUPPER((name[0] != NUL && name[1] == ':') ? name[2] : name[0])
      && vim_strchr(name, '#') == NULL) {
    semsg(_("E704: Funcref variable name must start with a capital: %s"), name);
    return true;
  }
  // Don't allow hiding a function.  When "v" is not NULL we might be
  // assigning another function to the same var, the type is checked
  // below.
  if (new_var && function_exists(name, false)) {
    semsg(_("E705: Variable name conflicts with existing function: %s"), name);
    return true;
  }
  return false;
}

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
        } else if (eval_option(&varname, rettv, true) == OK) {
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

/// Convert typval to option value for a particular option.
///
/// @param[in]   tv      typval to convert.
/// @param[in]   option  Option name.
/// @param[in]   flags   Option flags.
/// @param[out]  error   Whether an error occurred.
///
/// @return  Typval converted to OptVal. Must be freed by caller.
///          Returns NIL_OPTVAL for invalid option name.
///
/// TODO(famiu): Refactor this to support multitype options.
static OptVal tv_to_optval(typval_T *tv, OptIndex opt_idx, const char *option, bool *error)
{
  OptVal value = NIL_OPTVAL;
  char nbuf[NUMBUFLEN];
  bool err = false;
  const bool is_tty_opt = is_tty_option(option);
  const bool option_has_bool = !is_tty_opt && option_has_type(opt_idx, kOptValTypeBoolean);
  const bool option_has_num = !is_tty_opt && option_has_type(opt_idx, kOptValTypeNumber);
  const bool option_has_str = is_tty_opt || option_has_type(opt_idx, kOptValTypeString);

  if (!is_tty_opt && (get_option(opt_idx)->flags & P_FUNC) && tv_is_func(*tv)) {
    // If the option can be set to a function reference or a lambda
    // and the passed value is a function reference, then convert it to
    // the name (string) of the function reference.
    char *strval = encode_tv2string(tv, NULL);
    err = strval == NULL;
    value = CSTR_AS_OPTVAL(strval);
  } else if (option_has_bool || option_has_num) {
    varnumber_T n = option_has_num ? tv_get_number_chk(tv, &err) : tv_get_bool_chk(tv, &err);
    // This could be either "0" or a string that's not a number.
    // So we need to check if it's actually a number.
    if (!err && tv->v_type == VAR_STRING && n == 0) {
      unsigned idx;
      for (idx = 0; tv->vval.v_string[idx] == '0'; idx++) {}
      if (tv->vval.v_string[idx] != NUL || idx == 0) {
        // There's another character after zeros or the string is empty.
        // In both cases, we are trying to set a num option using a string.
        err = true;
        semsg(_("E521: Number required: &%s = '%s'"), option, tv->vval.v_string);
      }
    }
    value = option_has_num ? NUMBER_OPTVAL((OptInt)n) : BOOLEAN_OPTVAL(TRISTATE_FROM_INT(n));
  } else if (option_has_str) {
    // Avoid setting string option to a boolean or a special value.
    if (tv->v_type != VAR_BOOL && tv->v_type != VAR_SPECIAL) {
      const char *strval = tv_get_string_buf_chk(tv, nbuf);
      err = strval == NULL;
      value = CSTR_TO_OPTVAL(strval);
    } else if (!is_tty_opt) {
      err = true;
      emsg(_(e_stringreq));
    }
  } else {
    abort();  // This should never happen.
  }

  if (error != NULL) {
    *error = err;
  }
  return value;
}

/// Convert an option value to typval.
///
/// @param[in]  value    Option value to convert.
/// @param      numbool  Whether to convert boolean values to number.
///                      Used for backwards compatibility.
///
/// @return  OptVal converted to typval.
typval_T optval_as_tv(OptVal value, bool numbool)
{
  typval_T rettv = { .v_type = VAR_SPECIAL, .vval = { .v_special = kSpecialVarNull } };

  switch (value.type) {
  case kOptValTypeNil:
    break;
  case kOptValTypeBoolean:
    if (numbool) {
      rettv.v_type = VAR_NUMBER;
      rettv.vval.v_number = value.data.boolean;
    } else if (value.data.boolean != kNone) {
      rettv.v_type = VAR_BOOL;
      rettv.vval.v_bool = value.data.boolean == kTrue;
    }
    break;  // return v:null for None boolean value.
  case kOptValTypeNumber:
    rettv.v_type = VAR_NUMBER;
    rettv.vval.v_number = value.data.number;
    break;
  case kOptValTypeString:
    rettv.v_type = VAR_STRING;
    rettv.vval.v_string = value.data.string.data;
    break;
  }

  return rettv;
}

/// Set option "varname" to the value of "varp" for the current buffer/window.
static void set_option_from_tv(const char *varname, typval_T *varp)
{
  OptIndex opt_idx = find_option(varname);
  if (opt_idx == kOptInvalid) {
    semsg(_(e_unknown_option2), varname);
    return;
  }

  bool error = false;
  OptVal value = tv_to_optval(varp, opt_idx, varname, &error);

  if (!error) {
    const char *errmsg = set_option_value_handle_tty(varname, opt_idx, value, OPT_LOCAL);

    if (errmsg) {
      emsg(errmsg);
    }
  }
  optval_free(value);
}

/// "setwinvar()" and "settabwinvar()" functions
static void setwinvar(typval_T *argvars, int off)
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

  if (win == NULL || varname == NULL) {
    return;
  }

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
    n = eval_variable(name, len, &tv, NULL, false, true) == OK;
    if (n) {
      // Handle d.key, l[idx], f(expr).
      n = handle_subscript(&var, &tv, &EVALARG_EVALUATE, false) == OK;
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
  if (check_secure()) {
    return;
  }

  tabpage_T *const tp = find_tabpage((int)tv_get_number_chk(&argvars[0], NULL));
  const char *const varname = tv_get_string_chk(&argvars[1]);
  typval_T *const varp = &argvars[2];

  if (varname == NULL || tp == NULL) {
    return;
  }

  tabpage_T *const save_curtab = curtab;
  tabpage_T *const save_lu_tp = lastused_tabpage;
  goto_tabpage_tp(tp, false, false);

  const size_t varname_len = strlen(varname);
  char *const tabvarname = xmalloc(varname_len + 3);
  memcpy(tabvarname, "t:", 2);
  memcpy(tabvarname + 2, varname, varname_len + 1);
  set_var(tabvarname, varname_len + 2, varp, true);
  xfree(tabvarname);

  // Restore current tabpage and last accessed tabpage.
  if (valid_tabpage(save_curtab)) {
    goto_tabpage_tp(save_curtab, false, false);
    if (valid_tabpage(save_lu_tp)) {
      lastused_tabpage = save_lu_tp;
    }
  }
}

/// "settabwinvar()" function
void f_settabwinvar(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  setwinvar(argvars, 1);
}

/// "setwinvar()" function
void f_setwinvar(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  setwinvar(argvars, 0);
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

  if (buf == NULL || varname == NULL) {
    return;
  }

  if (*varname == '&') {
    aco_save_T aco;

    // Set curbuf to be our buf, temporarily.
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
