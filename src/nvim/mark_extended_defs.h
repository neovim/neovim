#ifndef NVIM_MARK_EXTENDED_DEFS_H
#define NVIM_MARK_EXTENDED_DEFS_H

#include "nvim/pos.h"

struct ExtMarkLine;

typedef struct ExtendedMark
{
  uint64_t ns_id;
  uint64_t mark_id;
  struct ExtMarkLine *line;
  colnr_T col;
} ExtendedMark;


#endif  // NVIM_MARK_EXTENDED_DEFS_H
