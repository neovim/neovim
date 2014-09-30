#ifndef NVIM_OS_UNIX_H
#define NVIM_OS_UNIX_H

#include "nvim/types.h"  // for vim_acl_T
#include "nvim/os/shell.h"

/* Values returned by mch_nodetype() */
#define NODE_NORMAL     0       /* file or directory, check with os_isdir()*/
#define NODE_WRITABLE   1       /* something we can write to (character
                                   device, fifo, socket, ..) */
#define NODE_OTHER      2       /* non-writable thing (e.g., block device) */

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os_unix.h.generated.h"
#endif
#endif  // NVIM_OS_UNIX_H
