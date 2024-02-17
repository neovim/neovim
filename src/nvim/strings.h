#pragma once

#include <stdarg.h>  // IWYU pragma: keep
#include <string.h>

#include "auto/config.h"
#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/func_attr.h"
#include "nvim/os/os_defs.h"
#include "nvim/types_defs.h"  // IWYU pragma: keep

static inline char *strappend(char *dst, const char *src)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_NONNULL_ALL
    REAL_FATTR_NONNULL_RET REAL_FATTR_WARN_UNUSED_RESULT;

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
{
  const size_t src_len = strlen(src);
  return (char *)memmove(dst, src, src_len) + src_len;
}

typedef kvec_t(char) StringBuilder;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "strings.h.generated.h"
#endif

#ifdef HAVE_STRCASECMP
# define STRICMP(d, s)      strcasecmp((char *)(d), (char *)(s))
#else
# ifdef HAVE_STRICMP
#  define STRICMP(d, s)     stricmp((char *)(d), (char *)(s))
# else
#  define STRICMP(d, s)     vim_stricmp((char *)(d), (char *)(s))
# endif
#endif

#ifdef HAVE_STRNCASECMP
# define STRNICMP(d, s, n)  strncasecmp((char *)(d), (char *)(s), (size_t)(n))
#else
# ifdef HAVE_STRNICMP
#  define STRNICMP(d, s, n) strnicmp((char *)(d), (char *)(s), (size_t)(n))
# else
#  define STRNICMP(d, s, n) vim_strnicmp((char *)(d), (char *)(s), (size_t)(n))
# endif
#endif
