#pragma once

#include "nvim/ex_cmds_defs.h"

/// All recognized msgpack types
typedef enum {
  kMPNil,
  kMPBoolean,
  kMPInteger,
  kMPFloat,
  kMPString,
  kMPArray,
  kMPMap,
  kMPExt,
} MessagePackType;
#define NUM_MSGPACK_TYPES (kMPExt + 1)

/// Struct passed through eval() functions.
/// See EVALARG_EVALUATE for a fixed value with eval_flags set to EVAL_EVALUATE.
typedef struct {
  int eval_flags;     ///< EVAL_ flag values below

  /// copied from exarg_T when "getline" is "getsourceline". Can be NULL.
  LineGetter eval_getline;
  void *eval_cookie;  ///< argument for eval_getline()

  /// pointer to the last line obtained with getsourceline()
  char *eval_tofree;
} evalarg_T;
