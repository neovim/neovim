
#include "nvim/lua/stdlib_gen.h"
#include "nvim/vim.h"

/// Compare two strings, ignoring case
///
/// Expects two values on the stack: compared strings. Returns one of the
/// following numbers: 0, -1 or 1.
///
/// Does no error handling: never call it with non-string or with some arguments
/// omitted.
Integer nlua_stdlib_stricmp(String _s1, String _s2)
{
  char *nul1;
  char *nul2;

  char *s1 = _s1.data;
  char *s2 = _s2.data;
  size_t s1_len = _s1.size;
  size_t s2_len = _s2.size;

  int ret = 0;
  assert(s1[s1_len] == NUL);
  assert(s2[s2_len] == NUL);
  do {
    nul1 = memchr(s1, NUL, s1_len);
    nul2 = memchr(s2, NUL, s2_len);
    ret = STRICMP(s1, s2);
    if (ret == 0) {
      // Compare "a\0" greater then "a".
      if ((nul1 == NULL) != (nul2 == NULL)) {
        ret = ((nul1 != NULL) - (nul2 != NULL));
        break;
      }
      if (nul1 != NULL) {
        assert(nul2 != NULL);
        // Can't shift both strings by the same amount of bytes: lowercase
        // letter may have different byte-length than uppercase.
        s1_len -= (size_t)(nul1 - s1) + 1;
        s2_len -= (size_t)(nul2 - s2) + 1;
        s1 = nul1 + 1;
        s2 = nul2 + 1;
      } else {
        break;
      }
    } else {
      break;
    }
  } while (true);
  return ((ret > 0) - (ret < 0));
}

