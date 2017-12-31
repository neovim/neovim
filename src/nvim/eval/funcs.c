// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdio.h>
#include <stddef.h>
#include <nvim/eval.h>

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "funcs.generated.h"
#endif
/*
 * Function given to ExpandGeneric() to obtain the list of internal
 * or user defined function names.
 */
char_u *get_function_name(expand_T *xp, int idx)
{
  static int intidx = -1;
  char_u      *name;

  if (idx == 0)
    intidx = -1;
  if (intidx < 0) {
    name = get_user_func_name(xp, idx);
    if (name != NULL)
      return name;
  }
  while ( (size_t)++intidx < ARRAY_SIZE(functions)
         && functions[intidx].name[0] == '\0') {
  }

  if ((size_t)intidx >= ARRAY_SIZE(functions)) {
    return NULL;
  }

  const char *const key = functions[intidx].name;
  const size_t key_len = strlen(key);
  memcpy(IObuff, key, key_len);
  IObuff[key_len] = '(';
  if (functions[intidx].max_argc == 0) {
    IObuff[key_len + 1] = ')';
    IObuff[key_len + 2] = NUL;
  } else {
    IObuff[key_len + 1] = NUL;
  }
  return IObuff;
}

/*
 * Function given to ExpandGeneric() to obtain the list of internal
 * or user defined function names.
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

    if (STRLEN(fp->uf_name) + 4 >= IOSIZE)
      return fp->uf_name;       /* prevents overflow */

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

/*
 * Function given to ExpandGeneric() to obtain the list of internal or
 * user defined variable or function names.
 */
char_u *get_expr_name(expand_T *xp, int idx)
{
  static int intidx = -1;
  char_u      *name;

  if (idx == 0)
    intidx = -1;
  if (intidx < 0) {
    name = get_function_name(xp, idx);
    if (name != NULL)
      return name;
  }
  return get_user_var_name(xp, ++intidx);
}
