#pragma once

#include <stddef.h>

typedef struct consumed_blk {
  struct consumed_blk *prev;
} *ArenaMem;

typedef struct {
  char *cur_blk;
  size_t pos, size;
} Arena;

// inits an empty arena.
#define ARENA_EMPTY { .cur_blk = NULL, .pos = 0, .size = 0 }
