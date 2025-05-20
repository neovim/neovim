#pragma once

#include <lua.h>  // IWYU pragma: keep
#include <stdint.h>  // IWYU pragma: keep

#include "nvim/api/keysets_defs.h"  // IWYU pragma: keep
#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

// positions are 0-indexed
typedef struct {
  buf_T *buf;
  lpos_T begin;
  lpos_T end;
  size_t len;
  char const *str;
} SearchParams;

typedef struct {
  bool found;
  lpos_T begin;
  lpos_T end;
} SearchResult;

typedef struct {
  char const *data;
  size_t length;
} StringView;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/buffer.h.generated.h"
#endif
