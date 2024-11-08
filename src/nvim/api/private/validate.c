#include <inttypes.h>
#include <stdio.h>
#include <string.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/ascii_defs.h"
#include "nvim/globals.h"

/// Creates "Invalid …" message and sets it on `err`.
void api_err_invalid(Error *err, const char *name, const char *val_s, int64_t val_n, bool quote_val)
{
  ErrorType errtype = kErrorTypeValidation;
  // Treat `name` without whitespace as a parameter (surround in quotes).
  // Treat `name` with whitespace as a description (no quotes).
  char *has_space = strchr(name, ' ');

  // No value.
  if (val_s && val_s[0] == NUL) {
    api_set_error(err, errtype, has_space ? "Invalid %s" : "Invalid '%s'", name);
    return;
  }

  // Number value.
  if (val_s == NULL) {
    api_set_error(err, errtype, has_space ? "Invalid %s: %" PRId64 : "Invalid '%s': %" PRId64,
                  name, val_n);
    return;
  }

  // String value.
  if (has_space) {
    api_set_error(err, errtype, quote_val ? "Invalid %s: '%s'" : "Invalid %s: %s", name, val_s);
  } else {
    api_set_error(err, errtype, quote_val ? "Invalid '%s': '%s'" : "Invalid '%s': %s", name, val_s);
  }
}

/// Creates "Invalid …: expected …" message and sets it on `err`.
void api_err_exp(Error *err, const char *name, const char *expected, const char *actual)
{
  ErrorType errtype = kErrorTypeValidation;
  // Treat `name` without whitespace as a parameter (surround in quotes).
  // Treat `name` with whitespace as a description (no quotes).
  char *has_space = strchr(name, ' ');

  if (!actual) {
    api_set_error(err, errtype,
                  has_space ? "Invalid %s: expected %s" : "Invalid '%s': expected %s",
                  name, expected);
    return;
  }

  api_set_error(err, errtype,
                has_space ? "Invalid %s: expected %s, got %s" : "Invalid '%s': expected %s, got %s",
                name, expected, actual);
}

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
