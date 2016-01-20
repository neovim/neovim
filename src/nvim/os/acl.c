#include <string.h>
#include <errno.h>

#include "nvim/types.h"
#include "nvim/os/acl.h"

/*
 * Return a pointer to the ACL of file "fname" in allocated memory.
 * Return NULL if the ACL is not available for whatever reason.
 */
vim_acl_T os_get_acl(char_u *fname)
{
  vim_acl_T ret = NULL;
  return ret;
}

/*
 * Set the ACL of file "fname" to "acl" (unless it's NULL).
 */
void os_set_acl(char_u *fname, vim_acl_T aclent)
{
  if (aclent == NULL)
    return;
}

void os_free_acl(vim_acl_T aclent)
{
  if (aclent == NULL)
    return;
}
