// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/os/os_defs.h"
#include "nvim/os_unix.h"
#include "nvim/types.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os_unix.c.generated.h"  // IWYU pragma: export
#endif

#if defined(HAVE_ACL)
# ifdef HAVE_SYS_ACL_H
#  include <sys/acl.h>
# endif
# ifdef HAVE_SYS_ACCESS_H
#  include <sys/access.h>
# endif

// Return a pointer to the ACL of file "fname" in allocated memory.
// Return NULL if the ACL is not available for whatever reason.
vim_acl_T mch_get_acl(const char_u *fname)
{
  vim_acl_T ret = NULL;
  return ret;
}

// Set the ACL of file "fname" to "acl" (unless it's NULL).
void mch_set_acl(const char_u *fname, vim_acl_T aclent)
{
  if (aclent == NULL) {
    return;
  }
}

void mch_free_acl(vim_acl_T aclent)
{
  if (aclent == NULL) {
    return;
  }
}
#endif
