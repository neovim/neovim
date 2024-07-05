// testing.c: Support for tests

#include <inttypes.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/encode.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/hashtab.h"
#include "nvim/hashtab_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/os/fs.h"
#include "nvim/runtime.h"
#include "nvim/runtime_defs.h"
#include "nvim/strings.h"
#include "nvim/testing.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"

/// Type of assert_* check being performed
typedef enum {
  ASSERT_EQUAL,
  ASSERT_NOTEQUAL,
  ASSERT_MATCH,
  ASSERT_NOTMATCH,
  ASSERT_FAILS,
  ASSERT_OTHER,
} assert_type_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "testing.c.generated.h"
#endif

static const char e_assert_fails_second_arg[]
  = N_(
      "E856: \"assert_fails()\" second argument must be a string or a list with one or two strings");
static const char e_assert_fails_fourth_argument[]
  = N_("E1115: \"assert_fails()\" fourth argument must be a number");
static const char e_assert_fails_fifth_argument[]
  = N_("E1116: \"assert_fails()\" fifth argument must be a string");
static const char e_calling_test_garbagecollect_now_while_v_testing_is_not_set[]
  = N_("E1142: Calling test_garbagecollect_now() while v:testing is not set");

/// Prepare "gap" for an assert error and add the sourcing position.
static void prepare_assert_error(garray_T *gap)
{
  char buf[NUMBUFLEN];
  char *sname = estack_sfile(ESTACK_NONE);

  ga_init(gap, 1, 100);
  if (sname != NULL) {
    ga_concat(gap, sname);
    if (SOURCING_LNUM > 0) {
      ga_concat(gap, " ");
    }
  }
  if (SOURCING_LNUM > 0) {
    vim_snprintf(buf, ARRAY_SIZE(buf), "line %" PRId64, (int64_t)SOURCING_LNUM);
    ga_concat(gap, buf);
  }
  if (sname != NULL || SOURCING_LNUM > 0) {
    ga_concat(gap, ": ");
  }
  xfree(sname);
}

/// Append "p[clen]" to "gap", escaping unprintable characters.
/// Changes NL to \n, CR to \r, etc.
static void ga_concat_esc(garray_T *gap, const char *p, int clen)
  FUNC_ATTR_NONNULL_ALL
{
  char buf[NUMBUFLEN];

  if (clen > 1) {
    memmove(buf, p, (size_t)clen);
    buf[clen] = NUL;
    ga_concat(gap, buf);
    return;
  }

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
    if ((uint8_t)(*p) < ' ' || *p == 0x7f) {
      vim_snprintf(buf, NUMBUFLEN, "\\x%02x", *p);
      ga_concat(gap, buf);
    } else {
      ga_append(gap, (uint8_t)(*p));
    }
    break;
  }
}

/// Append "str" to "gap", escaping unprintable characters.
/// Changes NL to \n, CR to \r, etc.
static void ga_concat_shorten_esc(garray_T *gap, const char *str)
  FUNC_ATTR_NONNULL_ARG(1)
{
  char buf[NUMBUFLEN];

  if (str == NULL) {
    ga_concat(gap, "NULL");
    return;
  }

  for (const char *p = str; *p != NUL; p++) {
    int same_len = 1;
    const char *s = p;
    const int c = mb_cptr2char_adv(&s);
    const int clen = (int)(s - p);
    while (*s != NUL && c == utf_ptr2char(s)) {
      same_len++;
      s += clen;
    }
    if (same_len > 20) {
      ga_concat(gap, "\\[");
      ga_concat_esc(gap, p, clen);
      ga_concat(gap, " occurs ");
      vim_snprintf(buf, NUMBUFLEN, "%d", same_len);
      ga_concat(gap, buf);
      ga_concat(gap, " times]");
      p = s - 1;
    } else {
      ga_concat_esc(gap, p, clen);
    }
  }
}

/// Fill "gap" with information about an assert error.
static void fill_assert_error(garray_T *gap, typval_T *opt_msg_tv, const char *exp_str,
                              typval_T *exp_tv_arg, typval_T *got_tv_arg, assert_type_T atype)
{
  typval_T *exp_tv = exp_tv_arg;
  typval_T *got_tv = got_tv_arg;
  bool did_copy = false;
  int omitted = 0;

  if (opt_msg_tv->v_type != VAR_UNKNOWN
      && !(opt_msg_tv->v_type == VAR_STRING
           && (opt_msg_tv->vval.v_string == NULL
               || *opt_msg_tv->vval.v_string == NUL))) {
    char *tofree = encode_tv2echo(opt_msg_tv, NULL);
    ga_concat(gap, tofree);
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
    // When comparing dictionaries, drop the items that are equal, so that
    // it's a lot easier to see what differs.
    if (atype != ASSERT_NOTEQUAL
        && exp_tv->v_type == VAR_DICT && got_tv->v_type == VAR_DICT
        && exp_tv->vval.v_dict != NULL && got_tv->vval.v_dict != NULL) {
      dict_T *exp_d = exp_tv->vval.v_dict;
      dict_T *got_d = got_tv->vval.v_dict;

      did_copy = true;
      exp_tv->vval.v_dict = tv_dict_alloc();
      got_tv->vval.v_dict = tv_dict_alloc();

      int todo = (int)exp_d->dv_hashtab.ht_used;
      for (const hashitem_T *hi = exp_d->dv_hashtab.ht_array; todo > 0; hi++) {
        if (!HASHITEM_EMPTY(hi)) {
          dictitem_T *item2 = tv_dict_find(got_d, hi->hi_key, -1);
          if (item2 == NULL
              || !tv_equal(&TV_DICT_HI2DI(hi)->di_tv, &item2->di_tv, false)) {
            // item of exp_d not present in got_d or values differ.
            const size_t key_len = strlen(hi->hi_key);
            tv_dict_add_tv(exp_tv->vval.v_dict, hi->hi_key, key_len, &TV_DICT_HI2DI(hi)->di_tv);
            if (item2 != NULL) {
              tv_dict_add_tv(got_tv->vval.v_dict, hi->hi_key, key_len, &item2->di_tv);
            }
          } else {
            omitted++;
          }
          todo--;
        }
      }

      // Add items only present in got_d.
      todo = (int)got_d->dv_hashtab.ht_used;
      for (const hashitem_T *hi = got_d->dv_hashtab.ht_array; todo > 0; hi++) {
        if (!HASHITEM_EMPTY(hi)) {
          dictitem_T *item2 = tv_dict_find(exp_d, hi->hi_key, -1);
          if (item2 == NULL) {
            // item of got_d not present in exp_d
            const size_t key_len = strlen(hi->hi_key);
            tv_dict_add_tv(got_tv->vval.v_dict, hi->hi_key, key_len, &TV_DICT_HI2DI(hi)->di_tv);
          }
          todo--;
        }
      }
    }

    char *tofree = encode_tv2string(exp_tv, NULL);
    ga_concat_shorten_esc(gap, tofree);
    xfree(tofree);
  } else {
    if (atype == ASSERT_FAILS) {
      ga_concat(gap, "'");
    }
    ga_concat_shorten_esc(gap, exp_str);
    if (atype == ASSERT_FAILS) {
      ga_concat(gap, "'");
    }
  }

  if (atype != ASSERT_NOTEQUAL) {
    if (atype == ASSERT_MATCH) {
      ga_concat(gap, " does not match ");
    } else if (atype == ASSERT_NOTMATCH) {
      ga_concat(gap, " does match ");
    } else {
      ga_concat(gap, " but got ");
    }
    char *tofree = encode_tv2string(got_tv, NULL);
    ga_concat_shorten_esc(gap, tofree);
    xfree(tofree);

    if (omitted != 0) {
      char buf[100];
      vim_snprintf(buf, sizeof(buf), " - %d equal item%s omitted", omitted,
                   omitted == 1 ? "" : "s");
      ga_concat(gap, buf);
    }
  }

  if (did_copy) {
    tv_clear(exp_tv);
    tv_clear(got_tv);
  }
}

static int assert_equal_common(typval_T *argvars, assert_type_T atype)
  FUNC_ATTR_NONNULL_ALL
{
  garray_T ga;

  if (tv_equal(&argvars[0], &argvars[1], false) != (atype == ASSERT_EQUAL)) {
    prepare_assert_error(&ga);
    fill_assert_error(&ga, &argvars[2], NULL,
                      &argvars[0], &argvars[1], atype);
    assert_error(&ga);
    ga_clear(&ga);
    return 1;
  }
  return 0;
}

static int assert_match_common(typval_T *argvars, assert_type_T atype)
  FUNC_ATTR_NONNULL_ALL
{
  char buf1[NUMBUFLEN];
  char buf2[NUMBUFLEN];
  const char *const pat = tv_get_string_buf_chk(&argvars[0], buf1);
  const char *const text = tv_get_string_buf_chk(&argvars[1], buf2);

  if (pat != NULL && text != NULL
      && pattern_match(pat, text, false) != (atype == ASSERT_MATCH)) {
    garray_T ga;
    prepare_assert_error(&ga);
    fill_assert_error(&ga, &argvars[2], NULL, &argvars[0], &argvars[1], atype);
    assert_error(&ga);
    ga_clear(&ga);
    return 1;
  }
  return 0;
}

/// Common for assert_true() and assert_false().
static int assert_bool(typval_T *argvars, bool is_true)
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
                      is_true ? "True" : "False",
                      NULL, &argvars[0], ASSERT_OTHER);
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

static int assert_beeps(typval_T *argvars, bool no_beep)
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

/// "assert_beeps(cmd [, error])" function
void f_assert_beeps(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = assert_beeps(argvars, false);
}

/// "assert_nobeep(cmd [, error])" function
void f_assert_nobeep(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = assert_beeps(argvars, true);
}

/// "assert_equal(expected, actual[, msg])" function
void f_assert_equal(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = assert_equal_common(argvars, ASSERT_EQUAL);
}

static int assert_equalfile(typval_T *argvars)
  FUNC_ATTR_NONNULL_ALL
{
  char buf1[NUMBUFLEN];
  char buf2[NUMBUFLEN];
  const char *const fname1 = tv_get_string_buf_chk(&argvars[0], buf1);
  const char *const fname2 = tv_get_string_buf_chk(&argvars[1], buf2);

  if (fname1 == NULL || fname2 == NULL) {
    return 0;
  }

  IObuff[0] = NUL;
  FILE *const fd1 = os_fopen(fname1, READBIN);
  char line1[200];
  char line2[200];
  ptrdiff_t lineidx = 0;
  if (fd1 == NULL) {
    snprintf(IObuff, IOSIZE, e_notread, fname1);
  } else {
    FILE *const fd2 = os_fopen(fname2, READBIN);
    if (fd2 == NULL) {
      fclose(fd1);
      snprintf(IObuff, IOSIZE, e_notread, fname2);
    } else {
      int64_t linecount = 1;
      for (int64_t count = 0;; count++) {
        const int c1 = fgetc(fd1);
        const int c2 = fgetc(fd2);
        if (c1 == EOF) {
          if (c2 != EOF) {
            xstrlcpy(IObuff, "first file is shorter", IOSIZE);
          }
          break;
        } else if (c2 == EOF) {
          xstrlcpy(IObuff, "second file is shorter", IOSIZE);
          break;
        } else {
          line1[lineidx] = (char)c1;
          line2[lineidx] = (char)c2;
          lineidx++;
          if (c1 != c2) {
            snprintf(IObuff, IOSIZE,
                     "difference at byte %" PRId64 ", line %" PRId64,
                     count, linecount);
            break;
          }
        }
        if (c1 == NL) {
          linecount++;
          lineidx = 0;
        } else if (lineidx + 2 == (ptrdiff_t)sizeof(line1)) {
          memmove(line1, line1 + 100, (size_t)(lineidx - 100));
          memmove(line2, line2 + 100, (size_t)(lineidx - 100));
          lineidx -= 100;
        }
      }
      fclose(fd1);
      fclose(fd2);
    }
  }

  if (IObuff[0] != NUL) {
    garray_T ga;
    prepare_assert_error(&ga);
    if (argvars[2].v_type != VAR_UNKNOWN) {
      char *const tofree = encode_tv2echo(&argvars[2], NULL);
      ga_concat(&ga, tofree);
      xfree(tofree);
      ga_concat(&ga, ": ");
    }
    ga_concat(&ga, IObuff);
    if (lineidx > 0) {
      line1[lineidx] = NUL;
      line2[lineidx] = NUL;
      ga_concat(&ga, " after \"");
      ga_concat(&ga, line1);
      if (strcmp(line1, line2) != 0) {
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

/// "assert_equalfile(fname-one, fname-two[, msg])" function
void f_assert_equalfile(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = assert_equalfile(argvars);
}

/// "assert_notequal(expected, actual[, msg])" function
void f_assert_notequal(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = assert_equal_common(argvars, ASSERT_NOTEQUAL);
}

/// "assert_exception(string[, msg])" function
void f_assert_exception(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  garray_T ga;

  const char *const error = tv_get_string_chk(&argvars[0]);
  if (*get_vim_var_str(VV_EXCEPTION) == NUL) {
    prepare_assert_error(&ga);
    ga_concat(&ga, "v:exception is not set");
    assert_error(&ga);
    ga_clear(&ga);
    rettv->vval.v_number = 1;
  } else if (error != NULL
             && strstr(get_vim_var_str(VV_EXCEPTION), error) == NULL) {
    prepare_assert_error(&ga);
    fill_assert_error(&ga, &argvars[1], NULL, &argvars[0],
                      get_vim_var_tv(VV_EXCEPTION), ASSERT_OTHER);
    assert_error(&ga);
    ga_clear(&ga);
    rettv->vval.v_number = 1;
  }
}

/// "assert_fails(cmd [, error [, msg]])" function
void f_assert_fails(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  garray_T ga;
  const int save_trylevel = trylevel;
  const int called_emsg_before = called_emsg;
  const char *wrong_arg_msg = NULL;
  char *tofree = NULL;

  if (tv_check_for_string_or_number_arg(argvars, 0) == FAIL
      || tv_check_for_opt_string_or_list_arg(argvars, 1) == FAIL
      || (argvars[1].v_type != VAR_UNKNOWN
          && (argvars[2].v_type != VAR_UNKNOWN
              && (tv_check_for_opt_number_arg(argvars, 3) == FAIL
                  || (argvars[3].v_type != VAR_UNKNOWN
                      && tv_check_for_opt_string_arg(argvars, 4) == FAIL))))) {
    return;
  }

  // trylevel must be zero for a ":throw" command to be considered failed
  trylevel = 0;
  suppress_errthrow = true;
  in_assert_fails = true;
  no_wait_return++;

  const char *const cmd = tv_get_string_chk(&argvars[0]);
  do_cmdline_cmd(cmd);

  // reset here for any errors reported below
  trylevel = save_trylevel;
  suppress_errthrow = false;

  if (called_emsg == called_emsg_before) {
    prepare_assert_error(&ga);
    ga_concat(&ga, "command did not fail: ");
    assert_append_cmd_or_arg(&ga, argvars, cmd);
    assert_error(&ga);
    ga_clear(&ga);
    rettv->vval.v_number = 1;
  } else if (argvars[1].v_type != VAR_UNKNOWN) {
    char buf[NUMBUFLEN];
    const char *expected;
    const char *expected_str = NULL;
    bool error_found = false;
    int error_found_index = 1;
    char *actual = emsg_assert_fails_msg == NULL ? "[unknown]" : emsg_assert_fails_msg;

    if (argvars[1].v_type == VAR_STRING) {
      expected = tv_get_string_buf_chk(&argvars[1], buf);
      error_found = expected == NULL || strstr(actual, expected) == NULL;
    } else if (argvars[1].v_type == VAR_LIST) {
      const list_T *const list = argvars[1].vval.v_list;
      if (list == NULL || tv_list_len(list) < 1 || tv_list_len(list) > 2) {
        wrong_arg_msg = e_assert_fails_second_arg;
        goto theend;
      }
      const typval_T *tv = TV_LIST_ITEM_TV(tv_list_first(list));
      expected = tv_get_string_buf_chk(tv, buf);
      if (expected == NULL) {
        goto theend;
      }
      if (!pattern_match(expected, actual, false)) {
        error_found = true;
        expected_str = expected;
      } else if (tv_list_len(list) == 2) {
        // make a copy, an error in pattern_match() may free it
        tofree = actual = xstrdup(get_vim_var_str(VV_ERRMSG));
        tv = TV_LIST_ITEM_TV(tv_list_last(list));
        expected = tv_get_string_buf_chk(tv, buf);
        if (expected == NULL) {
          goto theend;
        }
        if (!pattern_match(expected, actual, false)) {
          error_found = true;
          expected_str = expected;
        }
      }
    } else {
      wrong_arg_msg = e_assert_fails_second_arg;
      goto theend;
    }

    if (!error_found && argvars[2].v_type != VAR_UNKNOWN
        && argvars[3].v_type != VAR_UNKNOWN) {
      if (argvars[3].v_type != VAR_NUMBER) {
        wrong_arg_msg = e_assert_fails_fourth_argument;
        goto theend;
      } else if (argvars[3].vval.v_number >= 0
                 && argvars[3].vval.v_number != emsg_assert_fails_lnum) {
        error_found = true;
        error_found_index = 3;
      }
      if (!error_found && argvars[4].v_type != VAR_UNKNOWN) {
        if (argvars[4].v_type != VAR_STRING) {
          wrong_arg_msg = e_assert_fails_fifth_argument;
          goto theend;
        } else if (argvars[4].vval.v_string != NULL
                   && !pattern_match(argvars[4].vval.v_string,
                                     emsg_assert_fails_context, false)) {
          error_found = true;
          error_found_index = 4;
        }
      }
    }

    if (error_found) {
      typval_T actual_tv;
      prepare_assert_error(&ga);
      if (error_found_index == 3) {
        actual_tv.v_type = VAR_NUMBER;
        actual_tv.vval.v_number = emsg_assert_fails_lnum;
      } else if (error_found_index == 4) {
        actual_tv.v_type = VAR_STRING;
        actual_tv.vval.v_string = emsg_assert_fails_context;
      } else {
        actual_tv.v_type = VAR_STRING;
        actual_tv.vval.v_string = actual;
      }
      fill_assert_error(&ga, &argvars[2], expected_str,
                        &argvars[error_found_index], &actual_tv, ASSERT_FAILS);
      ga_concat(&ga, ": ");
      assert_append_cmd_or_arg(&ga, argvars, cmd);
      assert_error(&ga);
      ga_clear(&ga);
      rettv->vval.v_number = 1;
    }
  }

theend:
  trylevel = save_trylevel;
  suppress_errthrow = false;
  in_assert_fails = false;
  did_emsg = false;
  got_int = false;
  msg_col = 0;
  no_wait_return--;
  need_wait_return = false;
  emsg_on_display = false;
  msg_reset_scroll();
  lines_left = Rows;
  XFREE_CLEAR(emsg_assert_fails_msg);
  xfree(tofree);
  set_vim_var_string(VV_ERRMSG, NULL, 0);
  if (wrong_arg_msg != NULL) {
    emsg(_(wrong_arg_msg));
  }
}

// "assert_false(actual[, msg])" function
void f_assert_false(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = assert_bool(argvars, false);
}

static int assert_inrange(typval_T *argvars)
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
      char expected_str[200];
      vim_snprintf(expected_str, sizeof(expected_str), "range %g - %g,", flower, fupper);
      fill_assert_error(&ga, &argvars[3], expected_str, NULL, &argvars[2], ASSERT_OTHER);
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
      char expected_str[200];
      vim_snprintf(expected_str, sizeof(expected_str),
                   "range %" PRIdVARNUMBER " - %" PRIdVARNUMBER ",",
                   lower, upper);
      fill_assert_error(&ga, &argvars[3], expected_str, NULL, &argvars[2], ASSERT_OTHER);
      assert_error(&ga);
      ga_clear(&ga);
      return 1;
    }
  }
  return 0;
}

/// "assert_inrange(lower, upper[, msg])" function
void f_assert_inrange(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (tv_check_for_float_or_nr_arg(argvars, 0) == FAIL
      || tv_check_for_float_or_nr_arg(argvars, 1) == FAIL
      || tv_check_for_float_or_nr_arg(argvars, 2) == FAIL
      || tv_check_for_opt_string_arg(argvars, 3) == FAIL) {
    return;
  }

  rettv->vval.v_number = assert_inrange(argvars);
}

/// "assert_match(pattern, actual[, msg])" function
void f_assert_match(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = assert_match_common(argvars, ASSERT_MATCH);
}

/// "assert_notmatch(pattern, actual[, msg])" function
void f_assert_notmatch(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = assert_match_common(argvars, ASSERT_NOTMATCH);
}

/// "assert_report(msg)" function
void f_assert_report(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  garray_T ga;

  prepare_assert_error(&ga);
  ga_concat(&ga, tv_get_string(&argvars[0]));
  assert_error(&ga);
  ga_clear(&ga);
  rettv->vval.v_number = 1;
}

/// "assert_true(actual[, msg])" function
void f_assert_true(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = assert_bool(argvars, true);
}

/// "test_garbagecollect_now()" function
void f_test_garbagecollect_now(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  // This is dangerous, any Lists and Dicts used internally may be freed
  // while still in use.
  if (!get_vim_var_nr(VV_TESTING)) {
    emsg(_(e_calling_test_garbagecollect_now_while_v_testing_is_not_set));
  } else {
    garbage_collect(true);
  }
}

/// "test_write_list_log()" function
void f_test_write_list_log(typval_T *const argvars, typval_T *const rettv, EvalFuncData fptr)
{
  const char *const fname = tv_get_string_chk(&argvars[0]);
  if (fname == NULL) {
    return;
  }
}
