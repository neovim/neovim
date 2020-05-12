#ifndef NVIM_FOLD_H
#define NVIM_FOLD_H

#include <stdio.h>

#include "nvim/pos.h"
#include "nvim/garray.h"
#include "nvim/types.h"
#include "nvim/buffer_defs.h"

/*
 * Info used to pass info about a fold from the fold-detection code to the
 * code that displays the foldcolumn.
 */
typedef struct foldinfo {
  linenr_T fi_lnum;             /* line number where fold starts */
  int fi_level;                 /* level of the fold; when this is zero the
                                   other fields are invalid */
  int fi_low_level;             /* lowest fold level that starts in the same
                                   line */
} foldinfo_T;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "fold.h.generated.h"
#endif
#endif  // NVIM_FOLD_H
