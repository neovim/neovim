#include <stdbool.h>

#include "nvim/ascii.h"
#include "nvim/macros.h"
#include "nvim/charset.h"

bool vim_isIDc(int c)
{
  return ASCII_ISALNUM(c);
}
