#ifndef NVIM_RUNTIME_H
#define NVIM_RUNTIME_H

#include <stdbool.h>

#include "nvim/ex_docmd.h"

typedef void (*DoInRuntimepathCB)(char_u *, void *);

// last argument for do_source()
#define DOSO_NONE       0
#define DOSO_VIMRC      1       // loading vimrc file


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "runtime.h.generated.h"
#endif
#endif  // NVIM_RUNTIME_H
