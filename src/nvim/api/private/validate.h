#pragma once

#include <stdbool.h>
#include <stddef.h>

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/api/private/helpers.h"
#include "nvim/assert_defs.h"
#include "nvim/macros_defs.h"

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
    STATIC_ASSERT(expected_t != kObjectTypeDict, "use VALIDATE_T_DICT"); \
    if (expected_t != actual_t) { \
      api_err_exp(err, name, api_typename(expected_t), api_typename(actual_t)); \
      code; \
    } \
  } while (0)

/// Checks that `obj_` has type `expected_t`.
#define VALIDATE_T2(obj_, expected_t, code) \
  do { \
    STATIC_ASSERT(expected_t != kObjectTypeDict, "use VALIDATE_T_DICT"); \
    if ((obj_).type != expected_t) { \
      api_err_exp(err, STR(obj_), api_typename(expected_t), api_typename((obj_).type)); \
      code; \
    } \
  } while (0)

/// Checks that `obj_` has Dict type. Also allows empty Array in a Lua context.
#define VALIDATE_T_DICT(name, obj_, code) \
  do { \
    if ((obj_).type != kObjectTypeDict \
        && !(channel_id == LUA_INTERNAL_CALL \
             && (obj_).type == kObjectTypeArray \
             && (obj_).data.array.size == 0)) { \
      api_err_exp(err, name, api_typename(kObjectTypeDict), api_typename((obj_).type)); \
      code; \
    } \
  } while (0)

/// Checks that actual_t is either the correct handle type or a type erased handle (integer)
#define VALIDATE_T_HANDLE(name, expected_t, actual_t, code) \
  do { \
    if (expected_t != actual_t && kObjectTypeInteger != actual_t) { \
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
