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

/// Handle tv1 += tv2, -=, *=, /=,  %=, .=
///
/// @param[in,out]  tv1  First operand, modified typval.
/// @param[in]  tv2  Second operand.
/// @param[in]  op  Used operator.
///
/// @return OK or FAIL.
int eexe_mod_op(typval_T *const tv1, const typval_T *const tv2, const char *const op)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NO_SANITIZE_UNDEFINED
{
  // Can't do anything with a Funcref, a Dict or special value on the right.
  if (tv2->v_type != VAR_FUNC && tv2->v_type != VAR_DICT
      && tv2->v_type != VAR_BOOL && tv2->v_type != VAR_SPECIAL) {
    switch (tv1->v_type) {
    case VAR_DICT:
    case VAR_FUNC:
    case VAR_PARTIAL:
    case VAR_BOOL:
    case VAR_SPECIAL:
      break;
    case VAR_BLOB:
      if (*op != '+' || tv2->v_type != VAR_BLOB) {
        break;
      }
      // Blob += Blob
      if (tv1->vval.v_blob != NULL && tv2->vval.v_blob != NULL) {
        blob_T *const b1 = tv1->vval.v_blob;
        blob_T *const b2 = tv2->vval.v_blob;
        for (int i = 0; i < tv_blob_len(b2); i++) {
          ga_append(&b1->bv_ga, tv_blob_get(b2, i));
        }
      }
      return OK;
    case VAR_LIST:
      if (*op != '+' || tv2->v_type != VAR_LIST) {
        break;
      }
      // List += List
      if (tv1->vval.v_list != NULL && tv2->vval.v_list != NULL) {
        tv_list_extend(tv1->vval.v_list, tv2->vval.v_list, NULL);
      }
      return OK;
    case VAR_NUMBER:
    case VAR_STRING:
      if (tv2->v_type == VAR_LIST) {
        break;
      }
      if (vim_strchr("+-*/%", (uint8_t)(*op)) != NULL) {
        // nr += nr  or  nr -= nr, nr *= nr, nr /= nr, nr %= nr
        varnumber_T n = tv_get_number(tv1);
        if (tv2->v_type == VAR_FLOAT) {
          float_T f = (float_T)n;

          if (*op == '%') {
            break;
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
      } else {
        // str .= str
        if (tv2->v_type == VAR_FLOAT) {
          break;
        }
        const char *tvs = tv_get_string(tv1);
        char numbuf[NUMBUFLEN];
        char *const s =
          concat_str(tvs, tv_get_string_buf(tv2, numbuf));
        tv_clear(tv1);
        tv1->v_type = VAR_STRING;
        tv1->vval.v_string = s;
      }
      return OK;
    case VAR_FLOAT: {
      if (*op == '%' || *op == '.'
          || (tv2->v_type != VAR_FLOAT
              && tv2->v_type != VAR_NUMBER
              && tv2->v_type != VAR_STRING)) {
        break;
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
    case VAR_UNKNOWN:
      abort();
    }
  }

  semsg(_(e_letwrong), op);
  return FAIL;
}
