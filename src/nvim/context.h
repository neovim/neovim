#pragma once

#include <stddef.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"

typedef struct {
  String regs;     ///< Registers.
  String jumps;    ///< Jumplist.
  String bufs;     ///< Buffer list.
  String gvars;    ///< Global variables.
  Array funcs;              ///< Functions.
} Context;
typedef kvec_t(Context) ContextVec;

#define CONTEXT_INIT (Context) { \
  .regs = STRING_INIT, \
  .jumps = STRING_INIT, \
  .bufs = STRING_INIT, \
  .gvars = STRING_INIT, \
  .funcs = ARRAY_DICT_INIT, \
}

typedef enum {
  kCtxRegs = 1,       ///< Registers
  kCtxJumps = 2,      ///< Jumplist
  kCtxBufs = 4,       ///< Buffer list
  kCtxGVars = 8,      ///< Global variables
  kCtxSFuncs = 16,    ///< Script functions
  kCtxFuncs = 32,     ///< Functions
} ContextTypeFlags;

extern int kCtxAll;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "context.h.generated.h"
#endif
