#ifndef NVIM_EVENT_UV_PROCESS_H
#define NVIM_EVENT_UV_PROCESS_H

#include <uv.h>

#include "nvim/event/process.h"

typedef struct uv_process {
  Process process;
  uv_process_t uv;
  uv_process_options_t uvopts;
  uv_stdio_container_t uvstdio[3];
} UvProcess;

static inline UvProcess uv_process_init(void *data)
{
  UvProcess rv;
  rv.process = process_init(kProcessTypeUv, data);
  return rv;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/uv_process.h.generated.h"
#endif
#endif  // NVIM_EVENT_UV_PROCESS_H
