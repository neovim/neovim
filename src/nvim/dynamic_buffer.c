
#include <stddef.h>

#include "nvim/dynamic_buffer.h"
#include "nvim/func_attr.h"
#include "nvim/lib/kvec.h"
#include "nvim/vim.h"

///  - ensures at least `desired` bytes in buffer
///
/// TODO(aktau): fold with kvec/garray
void dynamic_buffer_ensure(DynamicBuffer *buf, size_t desired)
  FUNC_ATTR_NONNULL_ALL
{
  if (buf->cap >= desired) {
    return;
  }

  buf->cap = desired;
  kv_roundup32(buf->cap);
  buf->data = xrealloc(buf->data, buf->cap);
}

void dynamic_buffer_clear(DynamicBuffer *buf)
{
  free(buf->data);
  buf->data = NULL;
  buf->len = buf->cap = 0;
}

/// Makes room for at least `n` more bytes.
void dynamic_buffer_grow(DynamicBuffer *buf, size_t n)
  FUNC_ATTR_NONNULL_ALL
{
  dynamic_buffer_ensure(buf, buf->len + n);
}

/// Appends one character, `c`, to `buf`.
void dynamic_buffer_append(DynamicBuffer *buf, char c)
  FUNC_ATTR_NONNULL_ALL
{
  dynamic_buffer_grow(buf, 1);
  buf->data[buf->len++] = c;
}

/// Concatenates a string, `s`, of length `len`, to `buf`. Use -1 for the
/// length if unknown.
void dynamic_buffer_concat(DynamicBuffer *buf, char_u *restrict s,
                           ptrdiff_t len)
  FUNC_ATTR_NONNULL_ALL
{
  if (len == -1) {
    len = STRLEN(s);
  }

  dynamic_buffer_grow(buf, len);
  memcpy(buf->data + buf->len, s, len);
  buf->len += len;
}
