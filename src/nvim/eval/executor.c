// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/eval/typval.h"
#include "nvim/eval/executor.h"
#include "nvim/eval.h"
#include "nvim/message.h"
#include "nvim/vim.h"
#include "nvim/globals.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/executor.c.generated.h"
#endif

static char *e_letwrong = N_("E734: Wrong variable type for %s=");

char *e_listidx = N_("E684: list index out of range: %" PRId64);

/// Hanle tv1 += tv2, -=, *=, /=,  %=, .=
///
/// @param[in,out]  tv1  First operand, modified typval.
/// @param[in]  tv2  Second operand.
/// @param[in]  op  Used operator.
///
/// @return OK or FAIL.
int eexe_mod_op(typval_T *const tv1, const typval_T *const tv2,
                const char *const op)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NO_SANITIZE_UNDEFINED
{
  // Can't do anything with a Funcref, a Dict or special value on the right.
  if (tv2->v_type != VAR_FUNC && tv2->v_type != VAR_DICT) {
    switch (tv1->v_type) {
      case VAR_DICT:
      case VAR_FUNC:
      case VAR_PARTIAL:
      case VAR_SPECIAL: {
        break;
      }
      case VAR_LIST: {
        if (*op != '+' || tv2->v_type != VAR_LIST) {
          break;
        }
        // List += List
        if (tv1->vval.v_list != NULL && tv2->vval.v_list != NULL) {
          tv_list_extend(tv1->vval.v_list, tv2->vval.v_list, NULL);
        }
        return OK;
      }
      case VAR_NUMBER:
      case VAR_STRING: {
        if (tv2->v_type == VAR_LIST) {
          break;
        }
        if (vim_strchr((char_u *)"+-*/%", *op) != NULL) {
          // nr += nr  or  nr -= nr, nr *= nr, nr /= nr, nr %= nr
          varnumber_T n = tv_get_number(tv1);
          if (tv2->v_type == VAR_FLOAT) {
            float_T f = (float_T)n;

            if (*op == '%') {
              break;
            }
            switch (*op) {
              case '+': f += tv2->vval.v_float; break;
              case '-': f -= tv2->vval.v_float; break;
              case '*': f *= tv2->vval.v_float; break;
              case '/': f /= tv2->vval.v_float; break;
            }
            tv_clear(tv1);
            tv1->v_type = VAR_FLOAT;
            tv1->vval.v_float = f;
          } else {
            switch (*op) {
              case '+': n += tv_get_number(tv2); break;
              case '-': n -= tv_get_number(tv2); break;
              case '*': n *= tv_get_number(tv2); break;
              case '/': n /= tv_get_number(tv2); break;
              case '%': n %= tv_get_number(tv2); break;
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
          char *const s = (char *)concat_str(
              (const char_u *)tvs, (const char_u *)tv_get_string_buf(tv2,
                                                                     numbuf));
          tv_clear(tv1);
          tv1->v_type = VAR_STRING;
          tv1->vval.v_string = (char_u *)s;
        }
        return OK;
      }
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
          case '+': tv1->vval.v_float += f; break;
          case '-': tv1->vval.v_float -= f; break;
          case '*': tv1->vval.v_float *= f; break;
          case '/': tv1->vval.v_float /= f; break;
        }
        return OK;
      }
      case VAR_UNKNOWN: {
        assert(false);
      }
    }
  }

  EMSG2(_(e_letwrong), op);
  return FAIL;
}
