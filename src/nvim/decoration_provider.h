#ifndef NVIM_DECORATION_PROVIDER_H
#define NVIM_DECORATION_PROVIDER_H

#include "nvim/buffer_defs.h"

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
  bool hl_cached;
} DecorProvider;

typedef kvec_withinit_t(DecorProvider *, 4) DecorProviders;

EXTERN bool provider_active INIT(= false);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "decoration_provider.h.generated.h"
#endif

#endif  // NVIM_DECORATION_PROVIDER_H
