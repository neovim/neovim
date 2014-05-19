#ifndef NVIM_MAP_DEFS_H
#define NVIM_MAP_DEFS_H


#include "nvim/lib/khash.h"

typedef const char * cstr_t;
typedef void * ptr_t;

#define Map(T) Map_##T


#endif  // NVIM_MAP_DEFS_H

