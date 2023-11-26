#pragma once

#include "nvim/cmdexpand_defs.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/os/time.h"

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

/// History entry definition
typedef struct hist_entry {
  int hisnum;           ///< Entry identifier number.
  char *hisstr;         ///< Actual entry, separator char after the NUL.
  Timestamp timestamp;  ///< Time when entry was added.
  list_T *additional_elements;  ///< Additional entries from ShaDa file.
} histentry_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "cmdhist.h.generated.h"
#endif
