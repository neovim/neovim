#ifndef NVIM_API_PRIVATE_VALIDATE_H
#define NVIM_API_PRIVATE_VALIDATE_H

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"

#define VALIDATE(cond, fmt_, fmt_arg1, code) \
  do { \
    if (!(cond)) { \
      api_set_error(err, kErrorTypeValidation, fmt_, fmt_arg1); \
      code; \
    } \
  } while (0)

#define VALIDATE_INT(cond, name, val_, code) \
  do { \
    if (!(cond)) { \
      api_err_invalid(err, name, NULL, val_, false); \
      code; \
    } \
  } while (0)

#define VALIDATE_S(cond, name, val_, code) \
  do { \
    if (!(cond)) { \
      api_err_invalid(err, name, val_, 0, true); \
      code; \
    } \
  } while (0)

#define VALIDATE_EXP(cond, name, expected, actual, code) \
  do { \
    if (!(cond)) { \
      api_err_exp(err, name, expected, actual); \
      code; \
    } \
  } while (0)

#define VALIDATE_T(name, expected_t, actual_t, code) \
  do { \
    if (expected_t != actual_t) { \
      api_err_exp(err, name, api_typename(expected_t), api_typename(actual_t)); \
      code; \
    } \
  } while (0)

#define VALIDATE_RANGE(cond, name, code) \
  do { \
    if (!(cond)) { \
      api_err_invalid(err, name, "out of range", 0, false); \
      code; \
    } \
  } while (0)

#define VALIDATE_R(cond, name, code) \
  VALIDATE(cond, "Required: '%s'", name, code);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/validate.h.generated.h"
#endif

#endif  // NVIM_API_PRIVATE_VALIDATE_H
