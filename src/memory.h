#ifndef NEOVIM_MEMORY_H
#define NEOVIM_MEMORY_H

#include "func_attr.h"
#include "types.h"
#include "vim.h"

char_u *alloc(unsigned size) FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1);

/// malloc() wrapper
///
/// try_malloc() is a malloc() wrapper that tries to free some memory before
/// trying again.
///
/// @see {try_to_free_memory}
/// @param size
/// @return pointer to allocated space. NULL if out of memory
void *try_malloc(size_t size) FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1);

/// try_malloc() wrapper that shows an out-of-memory error message to the user
/// before returning NULL
///
/// @see {try_malloc}
/// @param size
/// @return pointer to allocated space. NULL if out of memory
void *verbose_try_malloc(size_t size) FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1);

/// malloc() wrapper that never returns NULL
///
/// xmalloc() succeeds or gracefully aborts when out of memory.
/// Before aborting try to free some memory and call malloc again.
///
/// @see {try_to_free_memory}
/// @param size
/// @return pointer to allocated space. Never NULL
void *xmalloc(size_t size)
  FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1) FUNC_ATTR_NONNULL_RET;

/// calloc() wrapper
///
/// @see {xmalloc}
/// @param count
/// @param size
/// @return pointer to allocated space. Never NULL
void *xcalloc(size_t count, size_t size)
  FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE_PROD(1, 2) FUNC_ATTR_NONNULL_RET;

/// realloc() wrapper
///
/// @see {xmalloc}
/// @param size
/// @return pointer to reallocated space. Never NULL
void *xrealloc(void *ptr, size_t size)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_ALLOC_SIZE(2) FUNC_ATTR_NONNULL_RET;

/// xmalloc() wrapper that allocates size + 1 bytes and zeroes the last byte
///
/// @see {xmalloc}
/// @param size
/// @return pointer to allocated space. Never NULL
void *xmallocz(size_t size) FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_RET;

/// Allocates (len + 1) bytes of memory, duplicates `len` bytes of
/// `data` to the allocated memory, zero terminates the allocated memory,
/// and returns a pointer to the allocated memory. If the allocation fails,
/// the program dies.
///
/// @see {xmalloc}
/// @param data Pointer to the data that will be copied
/// @param len number of bytes that will be copied
void *xmemdupz(const void *data, size_t len) FUNC_ATTR_NONNULL_RET;

/// strdup() wrapper
///
/// @see {xmalloc}
/// @param str 0-terminated string that will be copied
/// @return pointer to a copy of the string
char * xstrdup(const char *str)
 FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET;

/// strndup() wrapper
///
/// @see {xmalloc}
/// @param str 0-terminated string that will be copied
/// @return pointer to a copy of the string
char * xstrndup(const char *str, size_t len)
 FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET;

/// The xstpcpy() function shall copy the string pointed to by src (including
/// the terminating NUL character) into the array pointed to by dst.
///
/// The xstpcpy() function shall return a pointer to the terminating NUL
/// character copied into the dst buffer. This is the only difference with
/// strcpy(), which returns dst.
///
/// WARNING: If copying takes place between objects that overlap, the behavior is
/// undefined.
///
/// This is the Neovim version of stpcpy(3) as defined in POSIX 2008. We
/// don't require that supported platforms implement POSIX 2008, so we
/// implement our own version.
///
/// @param dst
/// @param src
char *xstpcpy(char *restrict dst, const char *restrict src);

/// The xstpncpy() function shall copy not more than n bytes (bytes that follow
/// a NUL character are not copied) from the array pointed to by src to the
/// array pointed to by dst.
///
/// If a NUL character is written to the destination, the xstpncpy() function
/// shall return the address of the first such NUL character. Otherwise, it
/// shall return &dst[maxlen].
///
/// WARNING: If copying takes place between objects that overlap, the behavior is
/// undefined.
///
/// WARNING: xstpncpy will ALWAYS write maxlen bytes. If src is shorter than
/// maxlen, zeroes will be written to the remaining bytes.
///
/// TODO(aktau): I don't see a good reason to have this last behaviour, and
/// it is potentially wasteful. Could we perhaps deviate from the standard
/// and not zero the rest of the buffer?
///
/// @param dst
/// @param src
/// @param maxlen
char *xstpncpy(char *restrict dst, const char *restrict src, size_t maxlen);

/// Old low level memory allocation function.
///
/// @deprecated use xmalloc() directly instead
/// @param size
/// @return pointer to allocated space. Never NULL
char_u *lalloc(long_u size, int message) FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1);
void do_outofmem_msg(long_u size);
void free_all_mem(void);
#endif
