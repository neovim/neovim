#ifndef NVIM_MEMORY_H
#define NVIM_MEMORY_H

#include <stdbool.h>  // for bool
#include <stdint.h>  // for uint8_t
#include <stddef.h>  // for size_t
#include <time.h>  // for time_t

/// `malloc()` function signature
typedef void *(*MemMalloc)(size_t);

/// `free()` function signature
typedef void (*MemFree)(void *);

/// `calloc()` function signature
typedef void *(*MemCalloc)(size_t, size_t);

/// `realloc()` function signature
typedef void *(*MemRealloc)(void *, size_t);

#ifdef UNIT_TESTING
/// When unit testing: pointer to the `malloc()` function, may be altered
extern MemMalloc mem_malloc;

/// When unit testing: pointer to the `free()` function, may be altered
extern MemFree mem_free;

/// When unit testing: pointer to the `calloc()` function, may be altered
extern MemCalloc mem_calloc;

/// When unit testing: pointer to the `realloc()` function, may be altered
extern MemRealloc mem_realloc;
#endif

#ifdef EXITFREE
/// Indicates that free_all_mem function was or is running
extern bool entered_free_all_mem;
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "memory.h.generated.h"
#endif

#define XFREE_CLEAR(ptr) \
  do { \
    /* Take the address to avoid double evaluation. #1375 */ \
    void **ptr_ = (void **)&(ptr); \
    xfree(*ptr_); \
    /* coverity[dead-store] */ \
    *ptr_ = NULL; \
    (void)(*ptr_); \
  } while (0)

#endif  // NVIM_MEMORY_H
