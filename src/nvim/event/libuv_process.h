#pragma once

#include <uv.h>

#include "nvim/event/defs.h"

typedef struct {
  Process process;
  uv_process_t uv;
  uv_process_options_t uvopts;
  uv_stdio_container_t uvstdio[4];
} LibuvProcess;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/libuv_process.h.generated.h"
#endif
