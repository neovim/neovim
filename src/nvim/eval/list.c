// eval/list.c: List support and container (List, Dict, Blob) functions.

#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/list.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/vars.h"
#include "nvim/ex_docmd.h"
#include "nvim/garray.h"
#include "nvim/globals.h"
#include "nvim/mbyte.h"
#include "nvim/strings.h"
#include "nvim/vim_defs.h"

/// Enum used by filter(), map(), mapnew() and foreach()
typedef enum {
  FILTERMAP_FILTER,
  FILTERMAP_MAP,
  FILTERMAP_MAPNEW,
  FILTERMAP_FOREACH,
} filtermap_T;

#include "eval/list.c.generated.h"

static const char e_argument_of_str_must_be_list_string_or_dictionary[]
  = N_("E706: Argument of %s must be a List, String or Dictionary");
static const char e_argument_of_str_must_be_list_string_dictionary_or_blob[]
  = N_("E1250: Argument of %s must be a List, String, Dictionary or Blob");

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

  tv_copy(tv, get_vim_var_tv(VV_VAL));

  newtv->v_type = VAR_UNKNOWN;
  if (filtermap == FILTERMAP_FOREACH && expr->v_type == VAR_STRING) {
    // foreach() is not limited to an expression
    do_cmdline_cmd(expr->vval.v_string);
    if (!did_emsg) {
      retval = OK;
    }
    goto theend;
  }

  argv[0] = *get_vim_var_tv(VV_KEY);
  argv[1] = *get_vim_var_tv(VV_VAL);
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
  tv_clear(get_vim_var_tv(VV_VAL));
  return retval;
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
    set_vim_var_string(VV_KEY, di->di_key, -1);
    typval_T newtv;
    bool rem;
    int r = filter_map_one(&di->di_tv, expr, filtermap, &newtv, &rem);
    tv_clear(get_vim_var_tv(VV_KEY));
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

  // set_vim_var_nr() doesn't set the type
  set_vim_var_type(VV_KEY, VAR_NUMBER);

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
    set_vim_var_nr(VV_KEY, idx);
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

  // set_vim_var_nr() doesn't set the type
  set_vim_var_type(VV_KEY, VAR_NUMBER);

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

    set_vim_var_nr(VV_KEY, idx);
    typval_T newtv = {
      .v_type = VAR_UNKNOWN,
    };
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
        emsg(_(e_string_required));
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
  // set_vim_var_nr() doesn't set the type
  set_vim_var_type(VV_KEY, VAR_NUMBER);

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
    set_vim_var_nr(VV_KEY, idx);
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
  typval_T save_key;

  prepare_vimvar(VV_VAL, &save_val);
  prepare_vimvar(VV_KEY, &save_key);

  // We reset "did_emsg" to be able to detect whether an error
  // occurred during evaluation of the expression.
  int save_did_emsg = did_emsg;
  did_emsg = false;

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

/// "add(list, item)" function
void f_add(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = 1;  // Default: failed.
  if (argvars[0].v_type == VAR_LIST) {
    list_T *const l = argvars[0].vval.v_list;
    if (!value_check_lock(tv_list_locked(l), N_("add() argument"),
                          TV_TRANSLATE)) {
      tv_list_append_tv(l, &argvars[1]);
      tv_copy(&argvars[0], rettv);
    }
  } else if (argvars[0].v_type == VAR_BLOB) {
    blob_T *const b = argvars[0].vval.v_blob;
    if (b != NULL
        && !value_check_lock(b->bv_lock, N_("add() argument"), TV_TRANSLATE)) {
      bool error = false;
      const varnumber_T n = tv_get_number_chk(&argvars[1], &error);

      if (!error) {
        ga_append(&b->bv_ga, (uint8_t)n);
        tv_copy(&argvars[0], rettv);
      }
    }
  } else {
    emsg(_(e_listblobreq));
  }
}

/// Count the number of times "needle" occurs in string "haystack".
///
/// @param ic  ignore case
static varnumber_T count_string(const char *haystack, const char *needle, bool ic)
{
  varnumber_T n = 0;
  const char *p = haystack;

  if (p == NULL || needle == NULL || *needle == NUL) {
    return 0;
  }

  if (ic) {
    const size_t len = strlen(needle);

    while (*p != NUL) {
      if (mb_strnicmp(p, needle, len) == 0) {
        n++;
        p += len;
      } else {
        MB_PTR_ADV(p);
      }
    }
  } else {
    const char *next;
    while ((next = strstr(p, needle)) != NULL) {
      n++;
      p = next + strlen(needle);
    }
  }

  return n;
}

/// Count the number of times item "needle" occurs in List "l" starting at index "idx".
///
/// @param ic  ignore case
static varnumber_T count_list(list_T *l, typval_T *needle, int64_t idx, bool ic)
{
  if (tv_list_len(l) == 0) {
    return 0;
  }

  listitem_T *li = tv_list_find(l, (int)idx);
  if (li == NULL) {
    semsg(_(e_list_index_out_of_range_nr), idx);
    return 0;
  }

  varnumber_T n = 0;

  for (; li != NULL; li = TV_LIST_ITEM_NEXT(l, li)) {
    if (tv_equal(TV_LIST_ITEM_TV(li), needle, ic)) {
      n++;
    }
  }

  return n;
}

/// Count the number of times item "needle" occurs in Dict "d".
///
/// @param ic  ignore case
static varnumber_T count_dict(dict_T *d, typval_T *needle, bool ic)
{
  if (d == NULL) {
    return 0;
  }

  varnumber_T n = 0;

  TV_DICT_ITER(d, di, {
    if (tv_equal(&di->di_tv, needle, ic)) {
      n++;
    }
  });

  return n;
}

/// "count()" function
void f_count(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  varnumber_T n = 0;
  int ic = 0;
  bool error = false;

  if (argvars[2].v_type != VAR_UNKNOWN) {
    ic = (int)tv_get_number_chk(&argvars[2], &error);
  }

  if (!error && argvars[0].v_type == VAR_STRING) {
    n = count_string(argvars[0].vval.v_string, tv_get_string_chk(&argvars[1]), ic);
  } else if (!error && argvars[0].v_type == VAR_LIST) {
    int64_t idx = 0;
    if (argvars[2].v_type != VAR_UNKNOWN
        && argvars[3].v_type != VAR_UNKNOWN) {
      idx = (int64_t)tv_get_number_chk(&argvars[3], &error);
    }
    if (!error) {
      n = count_list(argvars[0].vval.v_list, &argvars[1], idx, ic);
    }
  } else if (!error && argvars[0].v_type == VAR_DICT) {
    dict_T *d = argvars[0].vval.v_dict;

    if (d != NULL) {
      if (argvars[2].v_type != VAR_UNKNOWN
          && argvars[3].v_type != VAR_UNKNOWN) {
        emsg(_(e_invarg));
      } else {
        n = count_dict(argvars[0].vval.v_dict, &argvars[1], ic);
      }
    }
  } else if (!error) {
    semsg(_(e_argument_of_str_must_be_list_string_or_dictionary), "count()");
  }
  rettv->vval.v_number = n;
}

/// extend() a Dict. Append Dict argvars[1] to Dict argvars[0] and return the
/// resulting Dict in "rettv".
///
/// @param is_new  true for extendnew()
static void extend_dict(typval_T *argvars, const char *arg_errmsg, bool is_new, typval_T *rettv)
{
  dict_T *d1 = argvars[0].vval.v_dict;
  if (d1 == NULL) {
    const bool locked = value_check_lock(VAR_FIXED, arg_errmsg, TV_TRANSLATE);
    (void)locked;
    assert(locked == true);
    return;
  }
  dict_T *const d2 = argvars[1].vval.v_dict;
  if (d2 == NULL) {
    // Do nothing
    tv_copy(&argvars[0], rettv);
    return;
  }

  if (!is_new && value_check_lock(d1->dv_lock, arg_errmsg, TV_TRANSLATE)) {
    return;
  }

  if (is_new) {
    d1 = tv_dict_copy(NULL, d1, false, get_copyID());
    if (d1 == NULL) {
      return;
    }
  }

  const char *action = "force";
  // Check the third argument.
  if (argvars[2].v_type != VAR_UNKNOWN) {
    const char *const av[] = { "keep", "force", "error" };

    action = tv_get_string_chk(&argvars[2]);
    if (action == NULL) {
      if (is_new) {
        tv_dict_unref(d1);
      }
      return;  // Type error; error message already given.
    }
    size_t i;
    for (i = 0; i < ARRAY_SIZE(av); i++) {
      if (strcmp(action, av[i]) == 0) {
        break;
      }
    }
    if (i == 3) {
      if (is_new) {
        tv_dict_unref(d1);
      }
      semsg(_(e_invarg2), action);
      return;
    }
  }

  tv_dict_extend(d1, d2, action);

  if (is_new) {
    *rettv = (typval_T){
      .v_type = VAR_DICT,
      .v_lock = VAR_UNLOCKED,
      .vval.v_dict = d1,
    };
  } else {
    tv_copy(&argvars[0], rettv);
  }
}

/// extend() a List. Append List argvars[1] to List argvars[0] before index
/// argvars[3] and return the resulting list in "rettv".
///
/// @param is_new  true for extendnew()
static void extend_list(typval_T *argvars, const char *arg_errmsg, bool is_new, typval_T *rettv)
{
  bool error = false;

  list_T *l1 = argvars[0].vval.v_list;
  list_T *const l2 = argvars[1].vval.v_list;

  if (!is_new && value_check_lock(tv_list_locked(l1), arg_errmsg, TV_TRANSLATE)) {
    return;
  }

  if (is_new) {
    l1 = tv_list_copy(NULL, l1, false, get_copyID());
    if (l1 == NULL) {
      return;
    }
  }

  listitem_T *item;
  if (argvars[2].v_type != VAR_UNKNOWN) {
    int before = (int)tv_get_number_chk(&argvars[2], &error);
    if (error) {
      return;  // Type error; errmsg already given.
    }

    if (before == tv_list_len(l1)) {
      item = NULL;
    } else {
      item = tv_list_find(l1, before);
      if (item == NULL) {
        semsg(_(e_list_index_out_of_range_nr), (int64_t)before);
        return;
      }
    }
  } else {
    item = NULL;
  }
  tv_list_extend(l1, l2, item);

  if (is_new) {
    *rettv = (typval_T){
      .v_type = VAR_LIST,
      .v_lock = VAR_UNLOCKED,
      .vval.v_list = l1,
    };
  } else {
    tv_copy(&argvars[0], rettv);
  }
}

/// "extend()" or "extendnew()" function.
///
/// @param is_new  true for extendnew()
static void extend(typval_T *argvars, typval_T *rettv, char *arg_errmsg, bool is_new)
{
  if (argvars[0].v_type == VAR_LIST && argvars[1].v_type == VAR_LIST) {
    extend_list(argvars, arg_errmsg, is_new, rettv);
  } else if (argvars[0].v_type == VAR_DICT && argvars[1].v_type == VAR_DICT) {
    extend_dict(argvars, arg_errmsg, is_new, rettv);
  } else {
    semsg(_(e_listdictarg), is_new ? "extendnew()" : "extend()");
  }
}

/// "extend(list, list [, idx])" function
/// "extend(dict, dict [, action])" function
void f_extend(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  char *errmsg = N_("extend() argument");
  extend(argvars, rettv, errmsg, false);
}

/// "extendnew(list, list [, idx])" function
/// "extendnew(dict, dict [, action])" function
void f_extendnew(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  char *errmsg = N_("extendnew() argument");
  extend(argvars, rettv, errmsg, true);
}

/// "insert()" function
void f_insert(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  bool error = false;

  if (argvars[0].v_type == VAR_BLOB) {
    blob_T *const b = argvars[0].vval.v_blob;

    if (b == NULL
        || value_check_lock(b->bv_lock, N_("insert() argument"),
                            TV_TRANSLATE)) {
      return;
    }

    int before = 0;
    const int len = tv_blob_len(b);

    if (argvars[2].v_type != VAR_UNKNOWN) {
      before = (int)tv_get_number_chk(&argvars[2], &error);
      if (error) {
        return;  // type error; errmsg already given
      }
      if (before < 0 || before > len) {
        semsg(_(e_invarg2), tv_get_string(&argvars[2]));
        return;
      }
    }
    const int val = (int)tv_get_number_chk(&argvars[1], &error);
    if (error) {
      return;
    }
    if (val < 0 || val > 255) {
      semsg(_(e_invarg2), tv_get_string(&argvars[1]));
      return;
    }

    ga_grow(&b->bv_ga, 1);
    uint8_t *const p = (uint8_t *)b->bv_ga.ga_data;
    memmove(p + before + 1, p + before, (size_t)(len - before));
    *(p + before) = (uint8_t)val;
    b->bv_ga.ga_len++;

    tv_copy(&argvars[0], rettv);
  } else if (argvars[0].v_type != VAR_LIST) {
    semsg(_(e_listblobarg), "insert()");
  } else {
    list_T *l = argvars[0].vval.v_list;
    if (value_check_lock(tv_list_locked(l), N_("insert() argument"), TV_TRANSLATE)) {
      return;
    }

    int64_t before = 0;
    if (argvars[2].v_type != VAR_UNKNOWN) {
      before = tv_get_number_chk(&argvars[2], &error);
    }
    if (error) {
      // type error; errmsg already given
      return;
    }

    listitem_T *item = NULL;
    if (before != tv_list_len(l)) {
      item = tv_list_find(l, (int)before);
      if (item == NULL) {
        semsg(_(e_list_index_out_of_range_nr), before);
        l = NULL;
      }
    }
    if (l != NULL) {
      tv_list_insert_tv(l, &argvars[1], item);
      tv_copy(&argvars[0], rettv);
    }
  }
}

/// "remove()" function
void f_remove(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *const arg_errmsg = N_("remove() argument");

  if (argvars[0].v_type == VAR_DICT) {
    tv_dict_remove(argvars, rettv, arg_errmsg);
  } else if (argvars[0].v_type == VAR_BLOB) {
    tv_blob_remove(argvars, rettv, arg_errmsg);
  } else if (argvars[0].v_type == VAR_LIST) {
    tv_list_remove(argvars, rettv, arg_errmsg);
  } else {
    semsg(_(e_listdictblobarg), "remove()");
  }
}

/// "reverse({list})" function
void f_reverse(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (tv_check_for_string_or_list_or_blob_arg(argvars, 0) == FAIL) {
    return;
  }

  if (argvars[0].v_type == VAR_BLOB) {
    blob_T *const b = argvars[0].vval.v_blob;
    const int len = tv_blob_len(b);

    for (int i = 0; i < len / 2; i++) {
      const uint8_t tmp = tv_blob_get(b, i);
      tv_blob_set(b, i, tv_blob_get(b, len - i - 1));
      tv_blob_set(b, len - i - 1, tmp);
    }
    tv_blob_set_ret(rettv, b);
  } else if (argvars[0].v_type == VAR_STRING) {
    rettv->v_type = VAR_STRING;
    if (argvars[0].vval.v_string != NULL) {
      rettv->vval.v_string = reverse_text(argvars[0].vval.v_string);
    } else {
      rettv->vval.v_string = NULL;
    }
  } else if (argvars[0].v_type == VAR_LIST) {
    list_T *const l = argvars[0].vval.v_list;
    if (!value_check_lock(tv_list_locked(l), N_("reverse() argument"),
                          TV_TRANSLATE)) {
      tv_list_reverse(l);
      tv_list_set_ret(rettv, l);
    }
  }
}
