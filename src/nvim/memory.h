#ifndef NVIM_MEMORY_H
#define NVIM_MEMORY_H

#include <stddef.h>  // for size_t
#include <string.h>

#if defined(HAVE_STRCASECMP)
# include <strings.h>
#endif

#include "nvim/func_attr.h"

#ifdef HAVE_CONFIG_H
# include "auto/config.h"  // for the HAVE_* macros
#endif

// defines to avoid typecasts from (char_u *) to (char *) and back
#define STRLEN(s)           strlen((char *)(s))
#define STRCPY(d, s)        strcpy((char *)(d), (char *)(s))
#define STRNCPY(d, s, n)    strncpy((char *)(d), (char *)(s), (size_t)(n))
#define STRLCPY(d, s, n)    xstrlcpy((char *)(d), (char *)(s), (size_t)(n))
#define STRCMP(d, s)        strcmp((char *)(d), (char *)(s))
#define STRNCMP(d, s, n)    strncmp((char *)(d), (char *)(s), (size_t)(n))

#if defined(HAVE_STRCASECMP)
# define STRICMP(d, s)     strcasecmp((char *)(d), (char *)(s))
#elif defined(HAVE_STRICMP)
# define STRICMP(d, s)     stricmp((char *)(d), (char *)(s))
#elif defined(HAVE_U_STRICMP)
# define STRICMP(d, s)     _stricmp((char *)(d), (char *)(s))
#else
# error "strcasecmp/stricmp are undefined. Please file a bug report."
#endif

/// Like strcpy() but allows overlapped source and destination.
#define STRMOVE(d, s)       memmove((d), (s), STRLEN(s) + 1)

#if defined(HAVE_STRNCASECMP)
# define STRNICMP(d, s, n)  strncasecmp((char *)(d), (char *)(s), (size_t)(n))
#elif defined(HAVE_STRNICMP)
# define STRNICMP(d, s, n)  strnicmp((char *)(d), (char *)(s), (size_t)(n))
#elif defined(HAVE_U_STRNICMP)
# define STRINCMP(d, s)     _strnicmp((char *)(d), (char *)(s), (size_t)(n))
#else
# error "strncasecmp/strnicmp are undefined. Please file a bug report."
#endif

#define STRCAT(d, s)        strcat((char *)(d), (char *)(s))
#define STRNCAT(d, s, n)    strncat((char *)(d), (char *)(s), (size_t)(n))

#define vim_strpbrk(s, cs) (char_u *)strpbrk((char *)(s), (char *)(cs))

#ifdef HAVE_STRDUP
# define xstrdup(s)         strdup(s)
#endif
#ifdef HAVE_STRNDUP
# define xstrndup(s, size)  strndup(s, size)
#endif
#ifdef HAVE_STPCPY
# define xstpcpy(d, s)      stpcpy(d, s)
#endif
#ifdef HAVE_STPNCPY
# define xstpncpy(a, b, s)  stpncpy(a, b, s)
#endif
#ifdef HAVE_STRLCPY
# define xstrlcpy(a, b, s)  strlcpy(a, b, s)
#endif
#ifdef HAVE_MEMRCHR
# define xmemrchr(s, c)     memrchr(s, c)
#endif

/// Compares two strings for equality.
static inline bool strequal(const char *a, const char *b)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  return strcmp(a, b) == 0;
}

/// Compares two sized strings for equality.
static inline bool strnequal(const char *a, const char *b, size_t size)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  return strncmp(a, b, size) == 0;
}

/// Compares two strings for equality, ignoring case, and using the current
/// locale. Does not work for multi-byte characters.
static inline bool striequal(const char *a, const char *b)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  return STRICMP(a, b) == 0;
}

/// Compares two sized strings for equality, ignoring case, and using the
/// current locale. Does not work for multi-byte characters.
static inline bool strniequal(const char *a, const char *b, size_t size)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  return STRNICMP(a, b, size) == 0;
}

/// Checks a string for being NULL or empty.
static inline bool strempty(const char *s)
  FUNC_ATTR_PURE
{
  return s == NULL || s[0] == '\0';
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "memory.h.generated.h"
#endif
#endif  // NVIM_MEMORY_H
