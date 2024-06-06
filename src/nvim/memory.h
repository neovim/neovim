#pragma once

#include <stdbool.h>
#include <stdint.h>  // IWYU pragma: keep
#include <time.h>  // IWYU pragma: keep

#include "auto/config.h"
#include "nvim/ascii_defs.h"
#include "nvim/func_attr.h"
#include "nvim/macros_defs.h"
#include "nvim/memory_defs.h"  // IWYU pragma: keep

/// `malloc()` function signature
typedef void *(*MemMalloc)(size_t);

/// `free()` function signature
typedef void (*MemFree)(void *);

/// `calloc()` function signature
typedef void *(*MemCalloc)(size_t, size_t);

/// `realloc()` function signature
typedef void *(*MemRealloc)(void *, size_t);

#ifdef UNIT_TESTING
/// When unit testing: pointer to the `malloc()` function, may be altered
extern MemMalloc mem_malloc;

/// When unit testing: pointer to the `free()` function, may be altered
extern MemFree mem_free;

/// When unit testing: pointer to the `calloc()` function, may be altered
extern MemCalloc mem_calloc;

/// When unit testing: pointer to the `realloc()` function, may be altered
extern MemRealloc mem_realloc;
#endif

#ifdef EXITFREE
/// Indicates that free_all_mem function was or is running
extern bool entered_free_all_mem;
#endif

EXTERN size_t arena_alloc_count INIT( = 0);

#define kv_fixsize_arena(a, v, s) \
  ((v).capacity = (s), \
   (v).items = (void *)arena_alloc(a, sizeof((v).items[0]) * (v).capacity, true))

#define ARENA_BLOCK_SIZE 4096

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "memory.h.generated.h"
#endif

#define XFREE_CLEAR(ptr) \
  do { \
    /* Take the address to avoid double evaluation. #1375 */ \
    void **ptr_ = (void **)&(ptr); \
    xfree(*ptr_); \
    /* coverity[dead-store] */ \
    *ptr_ = NULL; \
    (void)(*ptr_); \
  } while (0)

#define CLEAR_FIELD(field)  memset(&(field), 0, sizeof(field))
#define CLEAR_POINTER(ptr)  memset((ptr), 0, sizeof(*(ptr)))

#ifndef HAVE_STRNLEN
# define strnlen xstrnlen  // Older versions of SunOS may not have strnlen
REAL_FATTR_NONNULL_ALL REAL_FATTR_PURE
static inline size_t xstrnlen(const char *s, size_t n)
{
  const char *end = memchr(s, NUL, n);
  if (end == NULL) {
    return n;
  }
  return (size_t)(end - s);
}
#endif

#define STRCPY(d, s)        strcpy((char *)(d), (char *)(s))  // NOLINT(runtime/printf)

// Like strcpy() but allows overlapped source and destination.
#define STRMOVE(d, s)       memmove((d), (s), strlen(s) + 1)

#define STRCAT(d, s)        strcat((char *)(d), (char *)(s))  // NOLINT(runtime/printf)

/// Copies `len` bytes of `src` to `dst` and zero terminates it.
///
/// @see {xstrlcpy}
/// @param[out]  dst  Buffer to store the result.
/// @param[in]  src  Buffer to be copied.
/// @param[in]  len  Number of bytes to be copied.
REAL_FATTR_NONNULL_ALL REAL_FATTR_NONNULL_RET
static inline void *xmemcpyz(void *dst, const void *src, size_t len)
{
  memcpy(dst, src, len);
  ((char *)dst)[len] = NUL;
  return dst;
}

/// A version of memchr() that returns a pointer one past the end
/// if it doesn't find `c`.
///
/// @param addr The address of the memory object.
/// @param c    The char to look for.
/// @param size The size of the memory object.
/// @returns a pointer to the first instance of `c`, or one past the end if not
///          found.
REAL_FATTR_NONNULL_RET REAL_FATTR_NONNULL_ALL REAL_FATTR_PURE
static inline void *xmemscan(const void *addr, char c, size_t size)
{
  char *p = memchr(addr, c, size);
  return p ? p : (char *)addr + size;
}

/// A version of strchr() that returns a pointer to the terminating NUL if it
/// doesn't find `c`.
///
/// @param str The string to search.
/// @param c   The char to look for.
/// @returns a pointer to the first instance of `c`, or to the NUL terminator
///          if not found.
REAL_FATTR_NONNULL_RET REAL_FATTR_NONNULL_ALL REAL_FATTR_PURE
static inline char *xstrchrnul(const char *str, char c)
{
  char *p = strchr(str, c);
  return p ? p : (char *)(str + strlen(str));
}
