// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/validate.c.generated.h"
#endif

bool check_string_array(Array arr, char *name, bool disallow_nl, Error *err)
{
  snprintf(IObuff, sizeof(IObuff), "'%s' item", name);
  for (size_t i = 0; i < arr.size; i++) {
    VALIDATE_T(IObuff, kObjectTypeString, arr.items[i].type, {
      return false;
    });
    // Disallow newlines in the middle of the line.
    if (disallow_nl) {
      const String l = arr.items[i].data.string;
      VALIDATE(!memchr(l.data, NL, l.size), "'%s' item contains newlines", name, {
        return false;
      });
    }
  }
  return true;
}
