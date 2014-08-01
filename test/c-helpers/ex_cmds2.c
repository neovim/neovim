#include "nvim/os/shell.h"

char *find_locale_helper(int idx)
{
  char **locales = (char **)find_locales();
  return locales[idx];
}
