#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/list.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/vars.h"
#include "nvim/ex_docmd.h"
#include "nvim/garray.h"
#include "nvim/globals.h"
#include "nvim/mbyte.h"
#include "nvim/vim_defs.h"

/// Enum used by filter(), map(), mapnew() and foreach()
typedef enum {
  FILTERMAP_FILTER,
  FILTERMAP_MAP,
  FILTERMAP_MAPNEW,
  FILTERMAP_FOREACH,
} filtermap_T;

#include "eval/list.c.generated.h"

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
