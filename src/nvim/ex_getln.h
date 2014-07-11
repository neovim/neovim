#ifndef NVIM_EX_GETLN_H
#define NVIM_EX_GETLN_H

#include "nvim/ex_cmds.h"

/* Values for nextwild() and ExpandOne().  See ExpandOne() for meaning. */
#define WILD_FREE               1
#define WILD_EXPAND_FREE        2
#define WILD_EXPAND_KEEP        3
#define WILD_NEXT               4
#define WILD_PREV               5
#define WILD_ALL                6
#define WILD_LONGEST            7
#define WILD_ALL_KEEP           8

#define WILD_LIST_NOTFOUND      1
#define WILD_HOME_REPLACE       2
#define WILD_USE_NL             4
#define WILD_NO_BEEP            8
#define WILD_ADD_SLASH          16
#define WILD_KEEP_ALL           32
#define WILD_SILENT             64
#define WILD_ESCAPE             128
#define WILD_ICASE              256

/*
 * There are four history tables:
 */
#define HIST_CMD        0       /* colon commands */
#define HIST_SEARCH     1       /* search commands */
#define HIST_EXPR       2       /* expressions (from entering = register) */
#define HIST_INPUT      3       /* input() lines */
#define HIST_DEBUG      4       /* debug commands */
#define HIST_COUNT      5       /* number of history tables */

typedef char_u *(*CompleteListItemGetter)(expand_T *, int);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_getln.h.generated.h"
#endif
#endif  // NVIM_EX_GETLN_H
