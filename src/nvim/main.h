#ifndef NVIM_MAIN_H
#define NVIM_MAIN_H

#include "nvim/normal.h"
#include "nvim/event/loop.h"

extern Loop main_loop;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "main.h.generated.h"
#endif
#endif  // NVIM_MAIN_H
