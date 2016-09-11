#ifndef NVIM_MEMORY_H
#define NVIM_MEMORY_H

#include <stdint.h>  // for uint8_t
#include <stddef.h>  // for size_t
#include <time.h>    // for time_t

typedef void *(*MemMalloc)(size_t);
typedef void (*MemFree)(void *);
typedef void *(*MemCalloc)(size_t, size_t);
typedef void *(*MemRealloc)(void *, size_t);

extern MemMalloc mem_malloc;
extern MemFree mem_free;
extern MemCalloc mem_calloc;
extern MemRealloc mem_realloc;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "memory.h.generated.h"
#endif
#endif  // NVIM_MEMORY_H
