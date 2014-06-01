#ifndef NVIM_PATH_H
#define NVIM_PATH_H

#include "nvim/func_attr.h"
#include "nvim/types.h"
#include "nvim/garray.h"

/// Return value for the comparison of two files. Also @see path_full_compare.
typedef enum file_comparison {
  kEqualFiles = 1,        ///< Both exist and are the same file.
  kDifferentFiles = 2,    ///< Both exist and are different files.
  kBothFilesMissing = 4,  ///< Both don't exist.
  kOneFileMissing = 6,    ///< One of them doesn't exist.
  kEqualFileNames = 7     ///< Both don't exist and file names are same.
} FileComparison;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "path.h.generated.h"
#endif
#endif
