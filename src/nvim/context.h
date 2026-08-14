#pragma once

#include <stddef.h>  // IWYU pragma: keep
#include <stdint.h>

#include "nvim/context_defs.h"  // IWYU pragma: export
#include "nvim/macros_defs.h"

/// Pool of temporary scratch windows (fka "autocmd windows"), for ctx_switch().
EXTERN kvec_t(CtxWin) ctx_win_vec INIT( = KV_INITIAL_VALUE);
#define ctx_win (ctx_win_vec.items)
#define CTX_WIN_COUNT ((int)ctx_win_vec.size)

#include "context.h.generated.h"
