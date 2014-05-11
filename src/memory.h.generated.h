#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
char_u *alloc(unsigned size) FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1);
void *try_malloc(size_t size) FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1);
void *verbose_try_malloc(size_t size) FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1);
void *xmalloc(size_t size) FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1) FUNC_ATTR_NONNULL_RET;
void *xcalloc(size_t count, size_t size) FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE_PROD(1, 2) FUNC_ATTR_NONNULL_RET;
void *xrealloc(void *ptr, size_t size) FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_ALLOC_SIZE(2) FUNC_ATTR_NONNULL_RET;
void *xmallocz(size_t size);
void *xmemdupz(const void *data, size_t len);
char *xstpcpy(char *restrict dst, const char *restrict src);
char *xstpncpy(char *restrict dst, const char *restrict src, size_t maxlen);
char *xstrdup(const char *str) FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET;
char *xstrndup(const char *str, size_t len) FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET;
void do_outofmem_msg(long_u size);
void free_all_mem(void);
#include "func_attr.h"
