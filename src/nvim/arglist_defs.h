#pragma once

#include "nvim/garray_defs.h"

/// Argument list: Array of file names.
/// Used for the global argument list and the argument lists local to a window.
typedef struct {
  garray_T al_ga;   ///< growarray with the array of file names
  int al_refcount;  ///< number of windows using this arglist
  int id;           ///< id of this arglist
} alist_T;

/// For each argument remember the file name as it was given, and the buffer
/// number that contains the expanded file name (required for when ":cd" is
/// used).
typedef struct {
  char *ae_fname;  ///< file name as specified
  int ae_fnum;     ///< buffer number with expanded file name
} aentry_T;
