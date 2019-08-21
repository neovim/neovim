#ifndef NVIM_CONTEXT_H
#define NVIM_CONTEXT_H

#include <msgpack.h>
#include "nvim/eval/typval.h"
#include "nvim/api/private/defs.h"
#include "nvim/lib/kvec.h"

typedef struct {
  msgpack_sbuffer regs;     ///< Registers.
  msgpack_sbuffer jumps;    ///< Jumplist.
  msgpack_sbuffer buflist;  ///< Buffer list.
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
  .buflist = MSGPACK_SBUFFER_INIT, \
  .vars = MSGPACK_SBUFFER_INIT, \
  .funcs = ARRAY_DICT_INIT, \
}

typedef enum {
  kCtxRegs    =   (1 <<  0),  ///< Registers
  kCtxJumps   =   (1 <<  1),  ///< Jumplist
  kCtxBuflist =   (1 <<  2),  ///< Buffer list
  kCtxSVars   =   (1 <<  3),  ///< Script-local variables
  kCtxGVars   =   (1 <<  4),  ///< Global variables
  kCtxBVars   =   (1 <<  5),  ///< Buffer variables
  kCtxWVars   =   (1 <<  6),  ///< Window variables
  kCtxTVars   =   (1 <<  7),  ///< Tab variables
  kCtxLVars   =   (1 <<  8),  ///< Function-local variables
  kCtxSFuncs  =   (1 <<  9),  ///< Script functions
  kCtxFuncs   =   (1 << 10),  ///< All functions
} ContextTypeFlags;

extern int kCtxAll;

#define CONTEXT_TYPE_FROM_STR(types, str) \
  if (strequal((str), "regs")) { \
    (types) |= kCtxRegs; \
  } else if (strequal((str), "jumps")) { \
    (types) |= kCtxJumps; \
  } else if (strequal((str), "buflist")) { \
    (types) |= kCtxBuflist; \
  } else if (strequal((str), "svars")) { \
    (types) |= kCtxSVars; \
  } else if (strequal((str), "gvars")) { \
    (types) |= kCtxGVars; \
  } else if (strequal((str), "bvars")) { \
    (types) |= kCtxBVars; \
  } else if (strequal((str), "wvars")) { \
    (types) |= kCtxWVars; \
  } else if (strequal((str), "tvars")) { \
    (types) |= kCtxTVars; \
  } else if (strequal((str), "lvars")) { \
    (types) |= kCtxLVars; \
  } else if (strequal((str), "sfuncs")) { \
    (types) |= kCtxSFuncs; \
  } else if (strequal((str), "funcs")) { \
    (types) |= kCtxFuncs; \
  }

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "context.h.generated.h"
#endif

#endif  // NVIM_CONTEXT_H
