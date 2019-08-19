#ifndef NVIM_CONTEXT_H
#define NVIM_CONTEXT_H

#include <msgpack.h>
#include "nvim/eval/typval.h"
#include "nvim/api/private/defs.h"
#include "nvim/lib/kvec.h"

typedef struct {
  msgpack_sbuffer regs;     ///< Registers.
  msgpack_sbuffer jumps;    ///< Jumplist.
  msgpack_sbuffer bufs;     ///< Buffer list.
  msgpack_sbuffer vars;     ///< Variables.
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
  .bufs = MSGPACK_SBUFFER_INIT, \
  .vars = MSGPACK_SBUFFER_INIT, \
  .funcs = ARRAY_DICT_INIT, \
}

typedef enum {
  kCtxRegs    =   (1 << 0),  ///< Registers
  kCtxJumps   =   (1 << 1),  ///< Jumplist
  kCtxBufs    =   (1 << 2),  ///< Buffer list
  kCtxSVars   =   (1 << 3),  ///< Script-local variables
  kCtxGVars   =   (1 << 4),  ///< Global variables
  kCtxBVars   =   (1 << 5),  ///< Buffer variables
  kCtxWVars   =   (1 << 6),  ///< Window variables
  kCtxTVars   =   (1 << 7),  ///< Tab variables
  kCtxSFuncs  =   (1 << 8),  ///< Script functions
  kCtxFuncs   =   (1 << 9),  ///< All functions
} ContextTypeFlags;

extern int kCtxAll;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "context.h.generated.h"
#endif

#endif  // NVIM_CONTEXT_H
