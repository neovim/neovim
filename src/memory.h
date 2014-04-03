#ifndef NEOVIM_MEMORY_H
#define NEOVIM_MEMORY_H

#include "func_attr.h"

char_u *alloc(unsigned size) FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1);
char_u *alloc_clear(unsigned size) FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1);
char_u *alloc_check(unsigned size) FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1);
char_u *lalloc_clear(long_u size, int message) FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1);

/// malloc() wrapper
///
/// xmalloc() succeeds or gracefully aborts when out of memory.
/// Before aborting try to free some memory and call malloc again.
///
/// @see {try_to_free_memory}
/// @param size
/// @return pointer to allocated space. Never NULL
void *xmalloc(size_t size)
  FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1) FUNC_ATTR_NONNULL_RET;

/// realloc() wrapper
///
/// @see {xmalloc}
/// @param size
/// @return pointer to reallocated space. Never NULL
void *xrealloc(void *ptr, size_t size)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_ALLOC_SIZE(2) FUNC_ATTR_NONNULL_RET;

/// Old low level memory allocation function.
///
/// @deprecated use xmalloc() directly instead
/// @param size
/// @return pointer to allocated space. Never NULL
char_u *lalloc(long_u size, int message) FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1);
void do_outofmem_msg(long_u size);
void free_all_mem(void);
#endif
