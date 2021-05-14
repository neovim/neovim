

#include "nvim/ex_docmd_utils.h"

#include "nvim/ex_cmds_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
#include "ex_docmd_utils.c.generated.h"
#endif

cstack_T cstack_get_initial(void)
{
  cstack_T cstack;                      // conditional stack
  cstack.cs_idx = -1;
  cstack.cs_looplevel = 0;
  cstack.cs_trylevel = 0;
  cstack.cs_emsg_silent_list = NULL;
  cstack.cs_lflags = 0;

  return cstack;
}
