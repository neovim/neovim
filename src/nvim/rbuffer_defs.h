#pragma once

#include <stddef.h>

#include "nvim/func_attr.h"

typedef struct rbuffer RBuffer;
/// Type of function invoked during certain events:
///   - When the RBuffer switches to the full state
///   - When the RBuffer switches to the non-full state
typedef void (*rbuffer_callback)(RBuffer *buf, void *data);

struct rbuffer {
  rbuffer_callback full_cb, nonfull_cb;
  void *data;
  size_t size;
  // helper memory used to by rbuffer_reset if required
  char *temp;
  char *end_ptr, *read_ptr, *write_ptr;
  char start_ptr[];
};

static inline size_t rbuffer_size(RBuffer *buf)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_NONNULL_ALL;

static inline size_t rbuffer_size(RBuffer *buf)
{
  return buf->size;
}

static inline size_t rbuffer_capacity(RBuffer *buf)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_NONNULL_ALL;

static inline size_t rbuffer_capacity(RBuffer *buf)
{
  return (size_t)(buf->end_ptr - buf->start_ptr);
}

static inline size_t rbuffer_space(RBuffer *buf)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_NONNULL_ALL;

static inline size_t rbuffer_space(RBuffer *buf)
{
  return rbuffer_capacity(buf) - buf->size;
}
