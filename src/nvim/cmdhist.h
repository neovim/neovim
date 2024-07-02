#pragma once

#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/os/time_defs.h"
#include "nvim/types_defs.h"  // IWYU pragma: keep

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

enum { HIST_COUNT = HIST_DEBUG + 1, };  ///< Number of history tables

/// History entry definition
typedef struct {
  int hisnum;           ///< Entry identifier number.
  char *hisstr;         ///< Actual entry, separator char after the NUL.
  Timestamp timestamp;  ///< Time when entry was added.
  AdditionalData *additional_data;  ///< Additional entries from ShaDa file.
} histentry_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "cmdhist.h.generated.h"
#endif
