#pragma once

#include <uv.h>

#include "nvim/event/loop.h"
#include "nvim/event/process.h"

typedef struct libuv_process {
  Process process;
  uv_process_t uv;
  uv_process_options_t uvopts;
  uv_stdio_container_t uvstdio[4];
} LibuvProcess;

static inline LibuvProcess libuv_process_init(Loop *loop, void *data)
{
  LibuvProcess rv = {
    .process = process_init(loop, kProcessTypeUv, data)
  };
  return rv;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/libuv_process.h.generated.h"
#endif
