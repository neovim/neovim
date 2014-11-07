
#ifndef NVIM_DYNAMIC_BUFFER_H
#define NVIM_DYNAMIC_BUFFER_H

#include "nvim/types.h"

#define DYNAMIC_BUFFER_INIT {NULL, 0, 0}

typedef struct {
  char *data;
  size_t cap, len;
} DynamicBuffer;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "dynamic_buffer.h.generated.h"
#endif

#endif
