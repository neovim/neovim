#ifndef NVIM_EDIT_H
#define NVIM_EDIT_H

#include "nvim/vim.h"

/*
 * Array indexes used for cptext argument of ins_compl_add().
 */
#define CPT_ABBR    0   /* "abbr" */
#define CPT_MENU    1   /* "menu" */
#define CPT_KIND    2   /* "kind" */
#define CPT_INFO    3   /* "info" */
#define CPT_COUNT   4   /* Number of entries */

typedef int (*IndentGetter)(void);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "edit.h.generated.h"
#endif
#endif  // NVIM_EDIT_H
