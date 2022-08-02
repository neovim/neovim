#ifndef NVIM_FILE_SEARCH_H
#define NVIM_FILE_SEARCH_H

#include <stdlib.h>  // for size_t

#include "nvim/globals.h"  // for CdScope
#include "nvim/types.h"  // for char_u

// Flags for find_file_*() functions.
#define FINDFILE_FILE   0       // only files
#define FINDFILE_DIR    1       // only directories
#define FINDFILE_BOTH   2       // files and directories

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "file_search.h.generated.h"
#endif
#endif  // NVIM_FILE_SEARCH_H
