#ifndef NVIM_EX_CMDS2_H
#define NVIM_EX_CMDS2_H

#include <stdbool.h>

#include "nvim/ex_docmd.h"

typedef void (*DoInRuntimepathCB)(char_u *, void *);

//
// flags for check_changed()
//
#define CCGD_AW         1       // do autowrite if buffer was changed
#define CCGD_MULTWIN    2       // check also when several wins for the buf
#define CCGD_FORCEIT    4       // ! used
#define CCGD_ALLBUF     8       // may write all buffers
#define CCGD_EXCMD      16      // may suggest using !

// last argument for do_source()
#define DOSO_NONE       0
#define DOSO_VIMRC      1       // loading vimrc file

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_cmds2.h.generated.h"
#endif
#endif  // NVIM_EX_CMDS2_H
