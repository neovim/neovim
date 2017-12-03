#ifndef NVIM_EX_GETLN_H
#define NVIM_EX_GETLN_H

#include "nvim/eval/typval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/os/time.h"
#include "nvim/regexp_defs.h"

/* Values for nextwild() and ExpandOne().  See ExpandOne() for meaning. */
#define WILD_FREE               1
#define WILD_EXPAND_FREE        2
#define WILD_EXPAND_KEEP        3
#define WILD_NEXT               4
#define WILD_PREV               5
#define WILD_ALL                6
#define WILD_LONGEST            7
#define WILD_ALL_KEEP           8

#define WILD_LIST_NOTFOUND      0x01
#define WILD_HOME_REPLACE       0x02
#define WILD_USE_NL             0x04
#define WILD_NO_BEEP            0x08
#define WILD_ADD_SLASH          0x10
#define WILD_KEEP_ALL           0x20
#define WILD_SILENT             0x40
#define WILD_ESCAPE             0x80
#define WILD_ICASE              0x100
#define WILD_ALLLINKS           0x200

/// Present history tables
typedef enum {
  HIST_DEFAULT = -2,  ///< Default (current) history.
  HIST_INVALID = -1,  ///< Unknown history.
  HIST_CMD = 0,       ///< Colon commands.
  HIST_SEARCH,        ///< Search commands.
  HIST_EXPR,          ///< Expressions (e.g. from entering = register).
  HIST_INPUT,         ///< input() lines.
  HIST_DEBUG,         ///< Debug commands.
} HistoryType;

/// Number of history tables
#define HIST_COUNT      (HIST_DEBUG + 1)

typedef char_u *(*CompleteListItemGetter)(expand_T *, int);

/// History entry definition
typedef struct hist_entry {
  int hisnum;           ///< Entry identifier number.
  char_u *hisstr;       ///< Actual entry, separator char after the NUL.
  Timestamp timestamp;  ///< Time when entry was added.
  list_T *additional_elements;  ///< Additional entries from ShaDa file.
} histentry_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_getln.h.generated.h"
#endif
#endif  // NVIM_EX_GETLN_H
