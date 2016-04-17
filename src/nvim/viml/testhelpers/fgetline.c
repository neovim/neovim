#include <stdio.h>
#include <errno.h>

#include "nvim/types.h"
#include "nvim/ascii.h"
#include "nvim/garray.h"
#include "nvim/memory.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/testhelpers/fgetline.c.generated.h"
#endif

/// Get line from file
///
/// @param[in]  file  File from which line will be obtained.
///
/// @return String in allocated memory or NULL in case of error or when there
///         are no more lines.
char *fgetline_file(int _, FILE *file, int indent)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  int c;
  garray_T ga;

  ga_init(&ga, sizeof(char), 1);

  errno = 0;

  while ((c = fgetc(file)) != EOF) {
    if (c == '\n') {
      break;
    }
    ga_append(&ga, (char) c);
  }
  ga_append(&ga, NUL);

  if (c == EOF && errno != 0) {
    ga_clear(&ga);
    return NULL;
  } else if (ga.ga_len <= 1) {
    return NULL;
  } else {
    return (char *) ga.ga_data;
  }
}

/// Get line from a single NUL-terminated, NL-separated string
///
/// @param[in]  arg  Pointer to the next character.
///
/// @return String in allocated memory or NULL in case of error or when there
///         are no more lines.
char *fgetline_string(int c, char **arg, int indent)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t len = 0;
  char *result;

  if (**arg == '\0') {
    return NULL;
  }

  while ((*arg)[len] != '\n' && (*arg)[len] != '\0') {
    len++;
  }

  result = xstrndup(*arg, len);

  if ((*arg)[len] == '\0') {
    *arg += len;
  } else {
    *arg += len + 1;
  }

  return result;
}
