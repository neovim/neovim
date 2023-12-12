#pragma once

#include "nvim/ascii_defs.h"
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/func_attr.h"
#include "nvim/macros_defs.h"
#include "nvim/mark_defs.h"  // IWYU pragma: export

static inline int mark_global_index(char name)
  REAL_FATTR_CONST;

/// Convert mark name to the offset
static inline int mark_global_index(const char name)
{
  return (ASCII_ISUPPER(name)
          ? (name - 'A')
          : (ascii_isdigit(name)
             ? (NMARKS + (name - '0'))
             : -1));
}

static inline int mark_local_index(char name)
  REAL_FATTR_CONST;

/// Convert local mark name to the offset
static inline int mark_local_index(const char name)
{
  return (ASCII_ISLOWER(name)
          ? (name - 'a')
          : (name == '"'
             ? NMARKS
             : (name == '^'
                ? NMARKS + 1
                : (name == '.'
                   ? NMARKS + 2
                   : -1))));
}

/// Global marks (marks with file number or name)
EXTERN xfmark_T namedfm[NGLOBALMARKS] INIT( = { 0 });

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mark.h.generated.h"
#endif
