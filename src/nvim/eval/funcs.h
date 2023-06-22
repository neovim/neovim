#ifndef NVIM_EVAL_FUNCS_H
#define NVIM_EVAL_FUNCS_H

#include <stdbool.h>
#include <stdint.h>

#include "nvim/api/private/dispatch.h"
#include "nvim/buffer_defs.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/types.h"

/// Prototype of C function that implements Vimscript function
typedef void (*VimLFunc)(typval_T *args, typval_T *rvar, EvalFuncData data);

/// Special flags for base_arg @see EvalFuncDef
#define BASE_NONE 0          ///< Not a method (no base argument).
#define BASE_LAST UINT8_MAX  ///< Use the last argument as the method base.

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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/funcs.h.generated.h"
#endif
#endif  // NVIM_EVAL_FUNCS_H
