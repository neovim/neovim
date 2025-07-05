#pragma once

#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/ex_getln_defs.h"  // IWYU pragma: keep
#include "nvim/garray_defs.h"  // IWYU pragma: keep
#include "nvim/regexp_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

// Values for nextwild() and ExpandOne().  See ExpandOne() for meaning.

enum {
  WILD_FREE        = 1,
  WILD_EXPAND_FREE = 2,
  WILD_EXPAND_KEEP = 3,
  WILD_NEXT        = 4,
  WILD_PREV        = 5,
  WILD_ALL         = 6,
  WILD_LONGEST     = 7,
  WILD_ALL_KEEP    = 8,
  WILD_CANCEL      = 9,
  WILD_APPLY       = 10,
  WILD_PAGEUP      = 11,
  WILD_PAGEDOWN    = 12,
  WILD_PUM_WANT    = 13,
};

enum {
  WILD_LIST_NOTFOUND        = 0x01,
  WILD_HOME_REPLACE         = 0x02,
  WILD_USE_NL               = 0x04,
  WILD_NO_BEEP              = 0x08,
  WILD_ADD_SLASH            = 0x10,
  WILD_KEEP_ALL             = 0x20,
  WILD_SILENT               = 0x40,
  WILD_ESCAPE               = 0x80,
  WILD_ICASE                = 0x100,
  WILD_ALLLINKS             = 0x200,
  WILD_IGNORE_COMPLETESLASH = 0x400,
  WILD_NOERROR              = 0x800,  ///< sets EW_NOERROR
  WILD_BUFLASTUSED          = 0x1000,
  BUF_DIFF_FILTER           = 0x2000,
  WILD_KEEP_SOLE_ITEM       = 0x4000,
  WILD_MAY_EXPAND_PATTERN   = 0x8000,
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "cmdexpand.h.generated.h"
#endif
