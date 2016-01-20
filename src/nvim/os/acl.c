#include <string.h>
#include <errno.h>

#include "nvim/types.h"
#include "nvim/log.h"
#include "nvim/os/acl.h"

#if defined(HAVE_SYS_ACL_H) && defined(__APPLE__)
// While OS X does have ACL with the same function signatures and behavior
// as Posix, it only supports this one type of ACL.
# define _ACL_TYPE ACL_TYPE_EXTENDED
#elif defined(HAVE_SYS_ACL_H)
// This is the default ACL type for Posix, which the functions that don't
// take an explicit type use.
# define _ACL_TYPE ACL_TYPE_ACCESS
#endif

/*
 * Return a pointer to the ACL of file "fname" in allocated memory.
 * Return NULL if the ACL is not available for whatever reason.
 */
vim_acl_T os_get_acl(char_u *fname)
{
  vim_acl_T ret = NULL;

#if defined(HAVE_SYS_ACL_H)
  ret = acl_get_file((char *)fname, _ACL_TYPE);
  if (ret == NULL && errno != 0) {
    ELOG("failed to get acl of a file: %s", strerror(errno));
  }
#endif

  return ret;
}

/*
 * Set the ACL of file "fname" to "acl" (unless it's NULL).
 */
void os_set_acl(char_u *fname, vim_acl_T aclent)
{
  if (aclent == NULL)
    return;

#if defined(HAVE_SYS_ACL_H)
  if (acl_set_file((char *)fname, _ACL_TYPE, aclent) != 0 && errno != 0) {
    ELOG("failed to set acl on a file: %s", strerror(errno));
  }
#endif
}

void os_free_acl(vim_acl_T aclent)
{
  if (aclent == NULL)
    return;

#if defined(HAVE_SYS_ACL_H)
  if (acl_free(aclent) != 0 && errno != 0) {
    ELOG("failed to free acl: %s", strerror(errno));
  }
#endif
}
