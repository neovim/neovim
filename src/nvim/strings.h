#ifndef NVIM_STRINGS_H
#define NVIM_STRINGS_H

#include <stdbool.h>
#include <stdarg.h>
#include <string.h>

#include "nvim/types.h"
#include "nvim/eval/typval.h"

/// Append string to string and return pointer to the next byte
///
/// Unlike strcat, this one does *not* add NUL byte and returns pointer to the
/// past of the added string.
///
/// @param[out]  dst  String to append to.
/// @param[in]  src  String to append.
///
/// @return pointer to the byte just past the appended byte.
static inline char *strappend(char *const dst, const char *const src)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
  FUNC_ATTR_NONNULL_RET
{
  const size_t src_len = strlen(src);
  return (char *)memmove(dst, src, src_len) + src_len;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "strings.h.generated.h"
#endif
#endif  // NVIM_STRINGS_H
