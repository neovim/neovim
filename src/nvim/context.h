#ifndef NVIM_CONTEXT_H
#define NVIM_CONTEXT_H

#include <msgpack.h>
#include "nvim/api/private/defs.h"
#include "nvim/lib/kvec.h"

typedef struct {
  msgpack_sbuffer regs;     ///< Registers.
  msgpack_sbuffer jumps;    ///< Jumplist.
  msgpack_sbuffer buflist;  ///< Buffer list.
  msgpack_sbuffer gvars;    ///< Global variables.
  Array funcs;              ///< Functions.
} Context;
typedef kvec_t(Context) ContextVec;

#define MSGPACK_SBUFFER_INIT (msgpack_sbuffer) { \
  .size = 0, \
  .data = NULL, \
  .alloc = 0, \
}

#define CONTEXT_INIT (Context) { \
  .regs = MSGPACK_SBUFFER_INIT, \
  .jumps = MSGPACK_SBUFFER_INIT, \
  .buflist = MSGPACK_SBUFFER_INIT, \
  .gvars = MSGPACK_SBUFFER_INIT, \
  .funcs = ARRAY_DICT_INIT, \
}

typedef enum {
  kCtxRegs = 1,       ///< Registers
  kCtxJumps = 2,      ///< Jumplist
  kCtxBuflist = 4,    ///< Buffer list
  kCtxGVars = 8,      ///< Global variables
  kCtxSFuncs = 16,    ///< Script functions
  kCtxFuncs = 32,     ///< Functions
} ContextTypeFlags;

extern int kCtxAll;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "context.h.generated.h"
#endif

#endif  // NVIM_CONTEXT_H
