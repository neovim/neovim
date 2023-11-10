#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <uv.h>

#include "nvim/event/loop.h"
#include "nvim/event/stream.h"

struct wbuffer;

typedef struct wbuffer WBuffer;
typedef void (*wbuffer_data_finalizer)(void *data);

struct wbuffer {
  size_t size, refcount;
  char *data;
  wbuffer_data_finalizer cb;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/wstream.h.generated.h"
#endif
