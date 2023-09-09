#ifndef NVIM_EX_CMDS2_H
#define NVIM_EX_CMDS2_H

#include "nvim/ex_cmds_defs.h"

//
// flags for check_changed()
//
#define CCGD_AW         1       // do autowrite if buffer was changed
#define CCGD_MULTWIN    2       // check also when several wins for the buf
#define CCGD_FORCEIT    4       // ! used
#define CCGD_ALLBUF     8       // may write all buffers
#define CCGD_EXCMD      16      // may suggest using !

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_cmds2.h.generated.h"
#endif
#endif  // NVIM_EX_CMDS2_H
