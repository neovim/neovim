#include <string.h>
#include <errno.h>

#include "nvim/types.h"
#include "nvim/log.h"
#include "nvim/os/acl.h"

#ifdef WIN32
# include <aclapi.h>
#endif

#if defined(HAVE_ACL) && defined(__APPLE__)
// While OS X does have ACL with the same function signatures and behavior
// as Posix, it only supports this one type of ACL.
# define _ACL_TYPE ACL_TYPE_EXTENDED
#elif defined(HAVE_ACL) && !defined(WIN32)
// This is the default ACL type for Posix, which the functions that don't
// take an explicit type use.
# define _ACL_TYPE ACL_TYPE_ACCESS
#endif

#ifdef WIN32
struct win_acl
{
  PSECURITY_DESCRIPTOR pSecurityDescriptor;
  PSID pSidOwner;
  PSID pSidGroup;
  PACL pDacl;
  PACL pSacl;
};
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/acl.c.generated.h"
#endif


//
// Return a pointer to the ACL of file "fname" in allocated memory.
// Return NULL if the ACL is not available for whatever reason.
//
vim_acl_T os_get_acl(const char_u *fname)
{
  vim_acl_T ret = NULL;

#ifdef HAVE_ACL
# ifdef WIN32
    DWORD err;

    ret = (vim_acl_T)xcalloc(1, (unsigned)sizeof(*ret));
    wchar_t *wn = NULL;

    int conversion_result = utf8_to_utf16(fname, &wn);
    if (conversion_result  == 0) {
      // Try to retrieve the entire security descriptor.
      err = GetNamedSecurityInfoW(
          wn,  // Abstract filename
          SE_FILE_OBJECT,  // File Object
          OWNER_SECURITY_INFORMATION |
          GROUP_SECURITY_INFORMATION |
          DACL_SECURITY_INFORMATION |
          SACL_SECURITY_INFORMATION,
          &ret->pSidOwner,  // Ownership information.
          &ret->pSidGroup,  // Group membership.
          &ret->pDacl,  // Discretionary information.
          &ret->pSacl,  // For auditing purposes.
          &ret->pSecurityDescriptor);
      if (err == ERROR_ACCESS_DENIED
          || err == ERROR_PRIVILEGE_NOT_HELD) {
        // Retrieve only DACL.
        err = GetNamedSecurityInfoW(
            wn,
            SE_FILE_OBJECT,
            DACL_SECURITY_INFORMATION,
            NULL,
            NULL,
            &ret->pDacl,
            NULL,
            &ret->pSecurityDescriptor);
      }
      if (ret->pSecurityDescriptor == NULL) {
        ELOG("failed to get acl of a file: %s",
             uv_strerror(os_translate_sys_error(err)));
        os_free_acl(ret);
        ret = NULL;
      }
      xfree(wn);
    } else {
      ELOG("utf8_to_utf16 failed: %d", conversion_result);
    }
# else  // WIN32
  ret = acl_get_file((char *)fname, _ACL_TYPE);
  if (ret == NULL && errno != 0) {
    ELOG("failed to get acl of a file: %s", strerror(errno));
  }
# endif
#endif

  return ret;
}

//
// Set the ACL of file "fname" to "acl" (unless it's NULL).
//
void os_set_acl(const char_u *fname, vim_acl_T aclent)
{
  if (aclent == NULL) {
    return;
  }

#ifdef HAVE_ACL
# ifdef WIN32
    SECURITY_INFORMATION sec_info = 0;

    wchar_t *wn = NULL;

  // Set security flags
  if (aclent->pSidOwner) {
    sec_info |= OWNER_SECURITY_INFORMATION;
  }
  if (aclent->pSidGroup) {
    sec_info |= GROUP_SECURITY_INFORMATION;
  }
  if (aclent->pDacl) {
    sec_info |= DACL_SECURITY_INFORMATION;
    // Do not inherit its parent's DACL.
    // If the DACL is inherited, Cygwin permissions would be changed.
    //
    if (!is_acl_inherited(aclent->pDacl)) {
      sec_info |= PROTECTED_DACL_SECURITY_INFORMATION;
    }
  }
  if (aclent->pSacl) {
    sec_info |= SACL_SECURITY_INFORMATION;
  }

  int conversion_result = utf8_to_utf16(fname, &wn);
  if (conversion_result == 0) {
    DWORD err = SetNamedSecurityInfoW(
        wn,  // Abstract filename
        SE_FILE_OBJECT,  // File Object
        sec_info,
        aclent->pSidOwner,  // Ownership information.
        aclent->pSidGroup,  // Group membership.
        aclent->pDacl,  // Discretionary information.
        aclent->pSacl);  // For auditing purposes.
    if (err != ERROR_SUCCESS) {
      ELOG("failed to set acl on a file: %s",
           uv_strerror(os_translate_sys_error(err)));
    }
    xfree(wn);
  } else {
    EMSG2("utf8_to_utf16 failed: %d", conversion_result);
  }
# else  // WIN32
  if (acl_set_file((char *)fname, _ACL_TYPE, aclent) != 0 && errno != 0) {
    ELOG("failed to set acl on a file: %s", strerror(errno));
  }
# endif
#endif
}

void os_free_acl(vim_acl_T aclent)
{
  if (aclent == NULL) {
    return;
  }

#ifdef HAVE_ACL
# ifdef WIN32
  // Free the memory just in case
  LocalFree((struct win_acl *)aclent->pSecurityDescriptor);
  xfree(aclent);
# else
  if (acl_free(aclent) != 0 && errno != 0) {
    ELOG("failed to free acl: %s", strerror(errno));
  }
# endif
#endif
}

#ifdef WIN32
// Check if "acl" contains inherited ACE.
static bool is_acl_inherited(PACL acl)
{
  DWORD i;
  ACL_SIZE_INFORMATION acl_info;
  PACCESS_ALLOWED_ACE ace;

  acl_info.AceCount = 0;
  GetAclInformation(acl, &acl_info, sizeof(acl_info), AclSizeInformation);
  for (i = 0; i < acl_info.AceCount; i++) {
    GetAce(acl, i, (LPVOID *)&ace);
    if (ace->Header.AceFlags & INHERITED_ACE) {
      return true;
    }
  }
  return false;
}
#endif
