#ifndef TREE_SITTER_ALLOC_H_
#define TREE_SITTER_ALLOC_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>

#include "nvim/memory.h"

#if 1

static inline bool ts_toggle_allocation_recording(bool value) {
  return false;
}

#define ts_malloc xmalloc
#define ts_calloc xcalloc
#define ts_realloc xrealloc
#define ts_free xfree

#elif defined(TREE_SITTER_TEST)

void *ts_record_malloc(size_t);
void *ts_record_calloc(size_t, size_t);
void *ts_record_realloc(void *, size_t);
void ts_record_free(void *);
bool ts_toggle_allocation_recording(bool);

static inline void *ts_malloc(size_t size) {
  return ts_record_malloc(size);
}

static inline void *ts_calloc(size_t count, size_t size) {
  return ts_record_calloc(count, size);
}

static inline void *ts_realloc(void *buffer, size_t size) {
  return ts_record_realloc(buffer, size);
}

static inline void ts_free(void *buffer) {
  ts_record_free(buffer);
}

#else

#include <stdlib.h>

static inline bool ts_toggle_allocation_recording(bool value) {
  return false;
}

static inline void *ts_malloc(size_t size) {
  void *result = malloc(size);
  if (size > 0 && !result) {
    fprintf(stderr, "tree-sitter failed to allocate %lu bytes", size);
    exit(1);
  }
  return result;
}

static inline void *ts_calloc(size_t count, size_t size) {
  void *result = calloc(count, size);
  if (count > 0 && !result) {
    fprintf(stderr, "tree-sitter failed to allocate %lu bytes", count * size);
    exit(1);
  }
  return result;
}

static inline void *ts_realloc(void *buffer, size_t size) {
  void *result = realloc(buffer, size);
  if (size > 0 && !result) {
    fprintf(stderr, "tree-sitter failed to reallocate %lu bytes", size);
    exit(1);
  }
  return result;
}

static inline void ts_free(void *buffer) {
  free(buffer);
}

#endif

#ifdef __cplusplus
}
#endif

#endif  // TREE_SITTER_ALLOC_H_
