#ifndef NVIM_EVAL_FUNCS_H
#define NVIM_EVAL_FUNCS_H

#include "nvim/buffer_defs.h"
#include "nvim/eval/typval.h"

typedef void (*FunPtr)(void);

/// Prototype of C function that implements VimL function
typedef void (*VimLFunc)(typval_T *args, typval_T *rvar, FunPtr data);

/// Special flags for base_arg @see VimLFuncDef
#define BASE_NONE 0          ///< Not a method (no base argument).
#define BASE_LAST UINT8_MAX  ///< Use the last argument as the method base.

/// Structure holding VimL function definition
typedef struct fst {
  char *name;        ///< Name of the function.
  uint8_t min_argc;  ///< Minimal number of arguments.
  uint8_t max_argc;  ///< Maximal number of arguments.
  uint8_t base_arg;  ///< Method base arg # (1-indexed), BASE_NONE or BASE_LAST.
  VimLFunc func;     ///< Function implementation.
  FunPtr data;       ///< Userdata for function implementation.
} VimLFuncDef;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/funcs.h.generated.h"
#endif
#endif  // NVIM_EVAL_FUNCS_H
