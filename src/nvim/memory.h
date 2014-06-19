#ifndef NVIM_MEMORY_H
#define NVIM_MEMORY_H

#include <stddef.h>
#include <string.h>
#include <stdbool.h>

#include "nvim/vim.h"
#include "func_attr.h"

/// xmemcpyz - memcpy that always NUL-terminates the destination buffer
///
/// copies `len` bytes from `src` to `dst` and adds a NUL byte. `dst` must
/// large enough to hold `n` + 1 bytes.
///
/// @return the destination buffer
static inline char *xmemcpyz(char *restrict dst,
                             const char *restrict src,
                             size_t len)
    FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  memcpy(dst, src, len);
  dst[len] = '\0';
  return dst;
}

/// xstrucpy - copy min(`strsize`, `bufsize` - 1) bytes, NUL terminates
///
/// Returns the number of bytes written (not counting the NUL byte).  If the
/// string length is known, this function provides a few advantages over
/// `(x)strlcpy`:
///
/// 1. Usually we want to know if truncation happened, not by how much.
///    Truncation happens when the `src` string is larger than the `dst` buffer.
///    In this case, xstrucpy will return a number smaller than `strsize`.
/// 2. `(x)strlcpy` calculates `strlen`, which is sometimes already known.
/// 3. `xstrucpy` can be used with Pascal strings (non-NUL terminated strings).
/// 4. It saves one from having to manually type `if (strlen(str) > ...)`.
///
/// Example:
///
/// @code{.c}
///   if (xstrucpy(buf, str, bufsize, str_len) < str_len) {
///     // truncation happened, deal with it
///   }
/// @endcode
///
/// @return the number of bytes copied (without the NUL terminator)
///
/// @see xstrlcpy
static inline size_t xstrucpy(char *restrict dst,
                              const char *restrict src,
                              size_t bufsize,
                              size_t strsize)
    FUNC_ATTR_NONNULL_ALL
{
  if (bufsize) {
    size_t cpy = (strsize < bufsize) ? strsize : bufsize - 1;
    xmemcpyz(dst, src, cpy);
  }

  return cpy;
}

/// xstracpy - copies string `src` into `dst`, always NUL terminates `dst`
///
/// TODO(aktau): if this shows up in profiler traces, try to find a version
///              that doesn't read `src` memory twice. This implementation should
///              be plenty fast though. Glibc (among others) have a highly
///              optimized memchr and memcpy. I probably made an off-by-one
///              error here, implementation untested.
///
/// @note This function can also be used with non-NUL terminated strings as
///       long as the underlying buffer of `src` has at least `bufsize`
///       bytes. So even though this function will work in more cases than
///       `strlcpy`, it's still advisable to use proper Pascal string
///       functions for Pascal strings.
///
/// @return false if the string was truncated, true if not. In the case of a
///         non-NUL terminated string, will always report that the
///         string has been truncated.
static inline bool xstracpy(char *restrict dst,
                            const char *restrict src,
                            size_t bufsize)
    FUNC_ATTR_NONNULL_ALL
{
  // find the NUL byte, if it exists
  char *p = memchr(src, '\0', bufsize);

  // 1. If the NUL byte was not found, fill as much of the buffer as possible.
  //    p will be NULL and the comparison will always be false, signaling
  //    truncation.
  // 2. If the NUL-byte was found, fill strlen(src) bytes (plus NUL
  //    terminator) of the buffer and return true (truncation) as long as
  //    `src + min(strlen(src), bufsize) <= src + strlen(src)`, simplified:
  //    `bufsize < strlen(src)`.
  return src + xstrucpy(dst, src, bufsize, p ? (size_t)(p - src) : bufsize) <= p;
}
#define STRACPY(dst, src, bufsize) xstracpy((char *) dst, (char *) src, bufsize)

/// SSTRLCPY - macro version of `strlcpy` specialized for string literals
///
/// @see xstrlcpy
///
/// optimal on both smart and stupid compilers. Compiles down to a pure
/// `memcpy` if the size of the buffer is known at compile time. Otherwise
/// it's just a branch and a `memcpy`.  note that this contains a trick to
/// guard against using it with non-string literals (though this can be
/// circumvented).
///
/// @note Most of the efficiency gained by using this
///       macro can probably also be obtained by hoisting `xstrlcpy` into the
///       header and annotating it with `static inline`.
///
/// @return the number of characters in the string (strlen(str))
#define SSTRLCPY(dst, src, size)                                                \
  (                                                                             \
    xstrucpy((char *) (dst), "" src, (size), sizeof(src) - 1),                  \
    sizeof(src) - 1                                                             \
  )

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "memory.h.generated.h"
#endif
#endif  // NVIM_MEMORY_H
