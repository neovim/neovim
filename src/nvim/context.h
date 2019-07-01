#ifndef NVIM_CONTEXT_H
#define NVIM_CONTEXT_H

#include "nvim/ops.h"

typedef struct {
  pos_T  pos;         ///< Current cursor position.
  int mode;           ///< NORMAL, INSERT, …
  bufref_T buf;       ///< Current buffer.
  win_T *win;         ///< Current window.
  yankreg_T **reg;    ///< Registers.
} Context;
typedef kvec_t(Context) ContextVec;

typedef enum {
  kCtxReg = 1,        ///< Registers
  kCtxVimscript = 2,  ///< VimL variables: v:, g:, s:, …
  kCtxOptions = 4,    ///< Editor options
} ContextTypeFlags;
extern int kCtxAll;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "context.h.generated.h"
#endif

#endif  // NVIM_CONTEXT_H
