#ifndef NVIM_FOLD_H
#define NVIM_FOLD_H

/*
 * Info used to pass info about a fold from the fold-detection code to the
 * code that displays the foldcolumn.
 */
typedef struct foldinfo {
  int fi_level;                 /* level of the fold; when this is zero the
                                   other fields are invalid */
  int fi_lnum;                  /* line number where fold starts */
  int fi_low_level;             /* lowest fold level that starts in the same
                                   line */
} foldinfo_T;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "fold.h.generated.h"
#endif
#endif  // NVIM_FOLD_H
