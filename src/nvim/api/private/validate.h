#ifndef NVIM_API_PRIVATE_VALIDATE_H
#define NVIM_API_PRIVATE_VALIDATE_H

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"

#define VALIDATE_INT(cond, name, n_, code) \
  do { \
    if (!(cond)) { \
      api_set_error(err, kErrorTypeValidation, "Invalid " name ": %" PRId64, n_); \
      code; \
    } \
  } while (0)

#define VALIDATE_S(cond, name, str_, code) \
  do { \
    if (!(cond)) { \
      if (strequal(str_, "")) { \
        api_set_error(err, kErrorTypeValidation, "Invalid " name); \
      } else { \
        api_set_error(err, kErrorTypeValidation, "Invalid " name ": '%s'", str_); \
      } \
      code; \
    } \
  } while (0)

#define VALIDATE_T(name, expected_t, actual_t, code) \
  do { \
    if (expected_t != actual_t) { \
      api_set_error(err, kErrorTypeValidation, "Invalid '" name "' type: expected %s, got %s", \
                    api_typename(expected_t), api_typename(actual_t)); \
      code; \
    } \
  } while (0)

#define VALIDATE(cond, msg_, code) \
  do { \
    if (!(cond)) { \
      api_set_error(err, kErrorTypeValidation, "%s", msg_); \
      code; \
    } \
  } while (0)

#endif  // NVIM_API_PRIVATE_VALIDATE_H
