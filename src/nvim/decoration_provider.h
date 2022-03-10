#ifndef NVIM_DECORATION_PROVIDER_H
#define NVIM_DECORATION_PROVIDER_H

#include "nvim/buffer_defs.h"
#include "nvim/extmark_defs.h"

typedef struct {
  NS ns_id;
  bool active;
  LuaRef redraw_start;
  LuaRef redraw_buf;
  LuaRef redraw_win;
  LuaRef redraw_line;
  LuaRef redraw_end;
  LuaRef hl_def;
  int hl_valid;
} DecorProvider;

#define DECORATION_PROVIDER_INIT(ns_id) (DecorProvider) \
  { ns_id, false, LUA_NOREF, LUA_NOREF, \
    LUA_NOREF, LUA_NOREF, LUA_NOREF, \
    LUA_NOREF, -1 }

typedef kvec_withinit_t(DecorProvider *, 4) DecorProviders;

EXTERN kvec_t(DecorProvider) decor_providers INIT(= KV_INITIAL_VALUE);
EXTERN bool provider_active INIT(= false);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "decoration_provider.h.generated.h"
#endif

#endif  // NVIM_DECORATION_PROVIDER_H
