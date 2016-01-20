#ifndef NVIM_OS_ACL_H
#define NVIM_OS_ACL_H

#include "nvim/vim.h"

#if defined(HAVE_SYS_ACL_H)

// For features, not guarding calls to ACL fns.
#define HAVE_ACL

#include <sys/types.h>
#include <sys/acl.h>

typedef acl_t vim_acl_T;

#else

typedef void *vim_acl_T;

#endif

vim_acl_T os_get_acl(char_u *fname);

void os_set_acl(char_u *fname, vim_acl_T aclent);

void os_free_acl(vim_acl_T aclent);

#endif  // NVIM_OS_ACL_H
