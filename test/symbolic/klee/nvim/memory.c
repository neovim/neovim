#include <stdlib.h>
#include <assert.h>

#include "nvim/lib/ringbuf.h"

enum { RB_SIZE = 1024 };

typedef struct {
  void *ptr;
  size_t size;
} AllocRecord;

RINGBUF_TYPEDEF(AllocRecords, AllocRecord)
RINGBUF_INIT(AllocRecords, arecs, AllocRecord, RINGBUF_DUMMY_FREE)
RINGBUF_STATIC(static, AllocRecords, AllocRecord, arecs, RB_SIZE)

size_t allocated_memory = 0;
size_t ever_allocated_memory = 0;

size_t allocated_memory_limit = SIZE_MAX;

void *xmalloc(const size_t size)
{
  void *ret = malloc(size);
  allocated_memory += size;
  ever_allocated_memory += size;
  assert(allocated_memory <= allocated_memory_limit);
  assert(arecs_rb_length(&arecs) < RB_SIZE);
  arecs_rb_push(&arecs, (AllocRecord) {
    .ptr = ret,
    .size = size,
  });
  return ret;
}

void xfree(void *const p)
{
  if (p == NULL) {
    return;
  }
  RINGBUF_FORALL(&arecs, AllocRecord, arec) {
    if (arec->ptr == p) {
      allocated_memory -= arec->size;
      arecs_rb_remove(&arecs, arecs_rb_find_idx(&arecs, arec));
      return;
    }
  }
  assert(false);
}

void *xrealloc(void *const p, size_t new_size)
{
  void *ret = realloc(p, new_size);
  RINGBUF_FORALL(&arecs, AllocRecord, arec) {
    if (arec->ptr == p) {
      allocated_memory -= arec->size;
      allocated_memory += new_size;
      if (new_size > arec->size) {
        ever_allocated_memory += (new_size - arec->size);
      }
      arec->ptr = ret;
      arec->size = new_size;
      return ret;
    }
  }
  assert(false);
  return (void *)(intptr_t)1;
}

char *xstrdup(const char *str)
  FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET
  FUNC_ATTR_NONNULL_ALL
{
  return xmemdupz(str, strlen(str));
}

void *xmallocz(size_t size)
  FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t total_size = size + 1;
  assert(total_size > size);

  void *ret = xmalloc(total_size);
  ((char *)ret)[size] = 0;

  return ret;
}

char *xstpcpy(char *restrict dst, const char *restrict src)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  const size_t len = strlen(src);
  return (char *)memcpy(dst, src, len + 1) + len;
}

void *xmemdupz(const void *data, size_t len)
  FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
  FUNC_ATTR_NONNULL_ALL
{
  return memcpy(xmallocz(len), data, len);
}
