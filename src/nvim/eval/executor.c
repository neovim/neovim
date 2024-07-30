#include <inttypes.h>
#include <stdlib.h>

#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/executor.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/garray.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/message.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/executor.c.generated.h"
#endif

char *e_list_index_out_of_range_nr
  = N_("E684: List index out of range: %" PRId64);

/// Handle "blob1 += blob2".
/// Returns OK or FAIL.
static int tv_op_blob(typval_T *tv1, const typval_T *tv2, const char *op)
  FUNC_ATTR_NONNULL_ALL
{
  if (*op != '+' || tv2->v_type != VAR_BLOB) {
    return FAIL;
  }

  // Blob += Blob
  if (tv2->vval.v_blob == NULL) {
    return OK;
  }

  if (tv1->vval.v_blob == NULL) {
    tv1->vval.v_blob = tv2->vval.v_blob;
    tv1->vval.v_blob->bv_refcount++;
    return OK;
  }

  blob_T *const b1 = tv1->vval.v_blob;
  blob_T *const b2 = tv2->vval.v_blob;
  const int len = tv_blob_len(b2);

  for (int i = 0; i < len; i++) {
    ga_append(&b1->bv_ga, tv_blob_get(b2, i));
  }

  return OK;
}

/// Handle "list1 += list2".
/// Returns OK or FAIL.
static int tv_op_list(typval_T *tv1, const typval_T *tv2, const char *op)
  FUNC_ATTR_NONNULL_ALL
{
  if (*op != '+' || tv2->v_type != VAR_LIST) {
    return FAIL;
  }

  // List += List
  if (tv2->vval.v_list == NULL) {
    return OK;
  }

  if (tv1->vval.v_list == NULL) {
    tv1->vval.v_list = tv2->vval.v_list;
    tv_list_ref(tv1->vval.v_list);
  } else {
    tv_list_extend(tv1->vval.v_list, tv2->vval.v_list, NULL);
  }

  return OK;
}

/// Handle number operations:
///      nr += nr , nr -= nr , nr *=nr , nr /= nr , nr %= nr
///
/// Returns OK or FAIL.
static int tv_op_number(typval_T *tv1, const typval_T *tv2, const char *op)
  FUNC_ATTR_NONNULL_ALL
{
  varnumber_T n = tv_get_number(tv1);
  if (tv2->v_type == VAR_FLOAT) {
    float_T f = (float_T)n;
    if (*op == '%') {
      return FAIL;
    }
    switch (*op) {
    case '+':
      f += tv2->vval.v_float; break;
    case '-':
      f -= tv2->vval.v_float; break;
    case '*':
      f *= tv2->vval.v_float; break;
    case '/':
      f /= tv2->vval.v_float; break;
    }
    tv_clear(tv1);
    tv1->v_type = VAR_FLOAT;
    tv1->vval.v_float = f;
  } else {
    switch (*op) {
    case '+':
      n += tv_get_number(tv2); break;
    case '-':
      n -= tv_get_number(tv2); break;
    case '*':
      n *= tv_get_number(tv2); break;
    case '/':
      n = num_divide(n, tv_get_number(tv2)); break;
    case '%':
      n = num_modulus(n, tv_get_number(tv2)); break;
    }
    tv_clear(tv1);
    tv1->v_type = VAR_NUMBER;
    tv1->vval.v_number = n;
  }

  return OK;
}

/// Handle "str1 .= str2"
/// Returns OK or FAIL.
static int tv_op_string(typval_T *tv1, const typval_T *tv2, const char *op)
  FUNC_ATTR_NONNULL_ALL
{
  if (tv2->v_type == VAR_FLOAT) {
    return FAIL;
  }

  // str .= str
  const char *tvs = tv_get_string(tv1);
  char numbuf[NUMBUFLEN];
  char *const s = concat_str(tvs, tv_get_string_buf(tv2, numbuf));
  tv_clear(tv1);
  tv1->v_type = VAR_STRING;
  tv1->vval.v_string = s;

  return OK;
}

/// Handle "tv1 += tv2", "tv1 -= tv2", "tv1 *= tv2", "tv1 /= tv2", "tv1 %= tv2"
/// and "tv1 .= tv2"
/// Returns OK or FAIL.
static int tv_op_nr_or_string(typval_T *tv1, const typval_T *tv2, const char *op)
  FUNC_ATTR_NONNULL_ALL
{
  if (tv2->v_type == VAR_LIST) {
    return FAIL;
  }

  if (vim_strchr("+-*/%", (uint8_t)(*op)) != NULL) {
    return tv_op_number(tv1, tv2, op);
  }

  return tv_op_string(tv1, tv2, op);
}

/// Handle "f1 += f2", "f1 -= f2", "f1 *= f2", "f1 /= f2".
/// Returns OK or FAIL.
static int tv_op_float(typval_T *tv1, const typval_T *tv2, const char *op)
  FUNC_ATTR_NONNULL_ALL
{
  if (*op == '%' || *op == '.'
      || (tv2->v_type != VAR_FLOAT
          && tv2->v_type != VAR_NUMBER
          && tv2->v_type != VAR_STRING)) {
    return FAIL;
  }

  const float_T f = (tv2->v_type == VAR_FLOAT
                     ? tv2->vval.v_float
                     : (float_T)tv_get_number(tv2));
  switch (*op) {
  case '+':
    tv1->vval.v_float += f; break;
  case '-':
    tv1->vval.v_float -= f; break;
  case '*':
    tv1->vval.v_float *= f; break;
  case '/':
    tv1->vval.v_float /= f; break;
  }

  return OK;
}

/// Handle tv1 += tv2, -=, *=, /=,  %=, .=
///
/// @param[in,out]  tv1  First operand, modified typval.
/// @param[in]  tv2  Second operand.
/// @param[in]  op  Used operator.
///
/// @return OK or FAIL.
int eexe_mod_op(typval_T *const tv1, const typval_T *const tv2, const char *const op)
  FUNC_ATTR_NONNULL_ALL
{
  // Can't do anything with a Funcref or Dict on the right.
  // v:true and friends only work with "..=".
  if (tv2->v_type == VAR_FUNC || tv2->v_type == VAR_DICT
      || ((tv2->v_type == VAR_BOOL || tv2->v_type == VAR_SPECIAL) && *op == '.')) {
    semsg(_(e_letwrong), op);
    return FAIL;
  }

  int retval = FAIL;

  switch (tv1->v_type) {
  case VAR_DICT:
  case VAR_FUNC:
  case VAR_PARTIAL:
  case VAR_BOOL:
  case VAR_SPECIAL:
    break;
  case VAR_BLOB:
    retval = tv_op_blob(tv1, tv2, op);
    break;
  case VAR_LIST:
    retval = tv_op_list(tv1, tv2, op);
    break;
  case VAR_NUMBER:
  case VAR_STRING:
    retval = tv_op_nr_or_string(tv1, tv2, op);
    break;
  case VAR_FLOAT:
    retval = tv_op_float(tv1, tv2, op);
    break;
  case VAR_UNKNOWN:
    abort();
  }

  if (retval != OK) {
    semsg(_(e_letwrong), op);
  }

  return retval;
}
