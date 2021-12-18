#ifndef NVIM_CHANGE_H
#define NVIM_CHANGE_H

#include "nvim/buffer_defs.h"  // for buf_T
#include "nvim/pos.h"  // for linenr_T

// flags for open_line()
#define OPENLINE_DELSPACES  1   // delete spaces after cursor
#define OPENLINE_DO_COM     2   // format comments
#define OPENLINE_KEEPTRAIL  4   // keep trailing spaces
#define OPENLINE_MARKFIX    8   // fix mark positions
#define OPENLINE_COM_LIST  16   // format comments with list/2nd line indent

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "change.h.generated.h"
#endif

#endif  // NVIM_CHANGE_H
