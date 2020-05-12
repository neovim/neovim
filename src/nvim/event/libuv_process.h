#ifndef NVIM_EVENT_LIBUV_PROCESS_H
#define NVIM_EVENT_LIBUV_PROCESS_H

#include <uv.h>

#include "nvim/event/process.h"

typedef struct libuv_process {
  Process process;
  uv_process_t uv;
  uv_process_options_t uvopts;
  uv_stdio_container_t uvstdio[3];
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
#endif  // NVIM_EVENT_LIBUV_PROCESS_H
