#ifndef NVIM_API_PRIVATE_VALIDATE_H
#define NVIM_API_PRIVATE_VALIDATE_H

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"

#define VALIDATE_INT(cond, name, val_, code) \
  do { \
    if (!(cond)) { \
      api_set_error(err, kErrorTypeValidation, "Invalid " name ": %" PRId64, val_); \
      code; \
    } \
  } while (0)

#define VALIDATE_S(cond, name, val_, code) \
  do { \
    if (!(cond)) { \
      if (strequal(val_, "")) { \
        api_set_error(err, kErrorTypeValidation, "Invalid " name); \
      } else { \
        api_set_error(err, kErrorTypeValidation, "Invalid " name ": '%s'", val_); \
      } \
      code; \
    } \
  } while (0)

#define VALIDATE_EXP(cond, name, expected, actual, code) \
  do { \
    if (!(cond)) { \
      api_set_error(err, kErrorTypeValidation, "Invalid %s: expected %s, got %s", \
                    name, expected, actual); \
      code; \
    } \
  } while (0)

#define VALIDATE_T(name, expected_t, actual_t, code) \
  do { \
    if (expected_t != actual_t) { \
      api_set_error(err, kErrorTypeValidation, "Invalid %s: expected %s, got %s", \
                    name, api_typename(expected_t), api_typename(actual_t)); \
      code; \
    } \
  } while (0)

#define VALIDATE(cond, fmt_, fmt_arg1, code) \
  do { \
    if (!(cond)) { \
      api_set_error(err, kErrorTypeValidation, fmt_, fmt_arg1); \
      code; \
    } \
  } while (0)

#define VALIDATE_RANGE(cond, name, code) \
  do { \
    if (!(cond)) { \
      api_set_error(err, kErrorTypeValidation, "Invalid '%s': out of range", name); \
      code; \
    } \
  } while (0)

#define VALIDATE_R(cond, name, code) \
  VALIDATE(cond, "Required: '%s'", name, code);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/validate.h.generated.h"
#endif

#endif  // NVIM_API_PRIVATE_VALIDATE_H
