#pragma once

#include <stddef.h>
#include <stdint.h>

// Max possible length: bytecode + 8 int/float bytes
// Ext objects are maximum 8=3+5 (nested uint32 payload)
#define MPACK_ITEM_SIZE 9

typedef struct packer_buffer_t PackerBuffer;

// Must ensure at least MPACK_ITEM_SIZE of space.
typedef void (*PackerBufferFlush)(PackerBuffer *self);

struct packer_buffer_t {
  char *startptr;
  char *ptr;
  char *endptr;

  // these are free to be used by packer_flush for any purpose, if want
  void *anydata;
  int64_t anyint;
  PackerBufferFlush packer_flush;
};
