#ifndef NVIM_OS_ACL_H
#define NVIM_OS_ACL_H

#include "nvim/vim.h"

#ifdef HAVE_SYS_ACL_H
#include <sys/acl.h>
#endif

#ifdef HAVE_ACL
# ifdef WIN32
typedef struct win_acl *vim_acl_T;
# else
typedef acl_t vim_acl_T;
# endif
#else
typedef void *vim_acl_T;
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/acl.h.generated.h"
#endif
#endif  // NVIM_OS_ACL_H
