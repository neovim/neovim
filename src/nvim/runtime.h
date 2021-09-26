#ifndef NVIM_RUNTIME_H
#define NVIM_RUNTIME_H

#include <stdbool.h>

#include "nvim/ex_docmd.h"

typedef void (*DoInRuntimepathCB)(char_u *, void *);

typedef struct {
  char *path;
  bool after;
} SearchPathItem;

typedef kvec_t(SearchPathItem) RuntimeSearchPath;
typedef kvec_t(char *) CharVec;

// last argument for do_source()
#define DOSO_NONE       0
#define DOSO_VIMRC      1       // loading vimrc file

// Used for flags in do_in_path()
#define DIP_ALL 0x01    // all matches, not just the first one
#define DIP_DIR 0x02    // find directories instead of files
#define DIP_ERR 0x04    // give an error message when none found
#define DIP_START 0x08  // also use "start" directory in 'packpath'
#define DIP_OPT 0x10    // also use "opt" directory in 'packpath'
#define DIP_NORTP 0x20  // do not use 'runtimepath'
#define DIP_NOAFTER 0x40  // skip "after" directories
#define DIP_AFTER   0x80  // only use "after" directories
#define DIP_LUA  0x100    // also use ".lua" files
#define DIP_DIRFILE 0x200  // find both files and directories


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "runtime.h.generated.h"
#endif
#endif  // NVIM_RUNTIME_H
