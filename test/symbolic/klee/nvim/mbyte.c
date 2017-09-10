#include <stddef.h>

#include "nvim/types.h"
#include "nvim/mbyte.h"
#include "nvim/ascii.h"

char_u *string_convert(const vimconv_T *conv, char_u *data, size_t *size)
{
  return NULL;
}

int utfc_ptr2len_len(const char_u *p, int size)
{
  if (size < 1 || *p == NUL) {
    return 0;
  }
  return 1;
}
