#pragma once

#include <uv.h>

#include "nvim/event/defs.h"

typedef struct {
  Proc proc;
  uv_process_t uv;
  uv_process_options_t uvopts;
  uv_stdio_container_t uvstdio[4];
} LibuvProc;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/libuv_proc.h.generated.h"
#endif
