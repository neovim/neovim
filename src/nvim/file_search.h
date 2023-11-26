#pragma once

#include <stdlib.h>

#include "nvim/globals.h"
#include "nvim/types.h"

// Flags for find_file_*() functions.
#define FINDFILE_FILE   0       // only files
#define FINDFILE_DIR    1       // only directories
#define FINDFILE_BOTH   2       // files and directories

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "file_search.h.generated.h"
#endif
