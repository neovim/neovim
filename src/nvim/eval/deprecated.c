#include <stdbool.h>                // for true

#include "nvim/errors.h"
#include "nvim/eval/deprecated.h"
#include "nvim/eval/funcs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds.h"
#include "nvim/gettext_defs.h"      // for _
#include "nvim/macros_defs.h"       // for S_LEN
#include "nvim/message.h"           // for semsg
#include "nvim/types_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/deprecated.c.generated.h"
#endif

/// "termopen(cmd[, cwd])" function
void f_termopen(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (check_secure()) {
    return;
  }

  bool must_free = false;

  if (argvars[1].v_type == VAR_UNKNOWN) {
    must_free = true;
    argvars[1].v_type = VAR_DICT;
    argvars[1].vval.v_dict = tv_dict_alloc();
  }

  if (argvars[1].v_type != VAR_DICT) {
    // Wrong argument types
    semsg(_(e_invarg2), "expected dictionary");
    return;
  }

  tv_dict_add_bool(argvars[1].vval.v_dict, S_LEN("term"), true);
  f_jobstart(argvars, rettv, fptr);
  if (must_free) {
    tv_dict_free(argvars[1].vval.v_dict);
  }
}
