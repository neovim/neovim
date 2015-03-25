#ifndef NVIM_FSWATCH_H
#define NVIM_FSWATCH_H

#include <uv.h>

#include <stdbool.h>

#include "nvim/buffer_defs.h"

typedef struct _watcher Watcher;

struct _watcher {
  buf_T* buffer;
  uv_fs_event_t* handle;
};


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/fsnotification.h.generated.h"
#endif

#endif  // NVIM_FSWATCH_H
