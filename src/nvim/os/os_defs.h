#ifndef NVIM_OS_OS_DEFS_H
#define NVIM_OS_OS_DEFS_H

#ifdef WIN32
# include "nvim/os/win_defs.h"
#else
# include "nvim/os/unix_defs.h"
#endif

#endif  // NVIM_OS_DEFS_H
