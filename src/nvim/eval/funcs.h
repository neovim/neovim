#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"

/// Prototype of C function that implements Vimscript function
typedef void (*VimLFunc)(typval_T *args, typval_T *rvar, EvalFuncData data);

/// Special flags for base_arg @see EvalFuncDef
enum {
  BASE_NONE = 0,          ///< Not a method (no base argument).
  BASE_LAST = UINT8_MAX,  ///< Use the last argument as the method base.
};

/// Structure holding Vimscript function definition
typedef struct {
  char *name;         ///< Name of the function.
  uint8_t min_argc;   ///< Minimal number of arguments.
  uint8_t max_argc;   ///< Maximal number of arguments.
  uint8_t base_arg;   ///< Method base arg # (1-indexed), BASE_NONE or BASE_LAST.
  bool fast;          ///< Can be run in |api-fast| events
  VimLFunc func;      ///< Function implementation.
  EvalFuncData data;  ///< Userdata for function implementation.
} EvalFuncDef;

#include "eval/funcs.h.generated.h"
