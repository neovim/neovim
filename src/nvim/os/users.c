// users.c -- operating system user information

#include <uv.h>

#include "nvim/ascii.h"
#include "nvim/os/os.h"
#include "nvim/garray.h"
#include "nvim/memory.h"
#include "nvim/misc2.h"
#include "nvim/strings.h"
#ifdef HAVE_PWD_H
# include <pwd.h>
#endif

// Initialize users garray and fill it with os usernames.
// Return Ok for success, FAIL for failure.
int os_get_usernames(garray_T *users)
{
  if (users == NULL) {
    return FAIL;
  }
  ga_init(users, sizeof(char *), 20);

# if defined(HAVE_GETPWENT) && defined(HAVE_PWD_H)
  struct passwd *pw;

  setpwent();
  while ((pw = getpwent()) != NULL) {
    // pw->pw_name shouldn't be NULL but just in case...
    if (pw->pw_name != NULL) {
      GA_APPEND(char *, users, xstrdup(pw->pw_name));
    }
  }
  endpwent();
# endif

  return OK;
}

// Insert user name in s[len].
// Return OK if a name found.
int os_get_user_name(char *s, size_t len)
{
  return os_get_uname(getuid(), s, len);
}

// Insert user name for "uid" in s[len].
// Return OK if a name found.
// If the name is not found, write the uid into s[len] and return FAIL.
int os_get_uname(uid_t uid, char *s, size_t len)
{
#if defined(HAVE_PWD_H) && defined(HAVE_GETPWUID)
  struct passwd *pw;

  if ((pw = getpwuid(uid)) != NULL
      && pw->pw_name != NULL && *(pw->pw_name) != NUL) {
    STRLCPY(s, pw->pw_name, len);
    return OK;
  }
#endif
  snprintf(s, len, "%d", (int)uid);
  return FAIL;  // a number is not a name
}

// Returns the user directory for the given username.
// The caller has to free() the returned string.
// If the username is not found, NULL is returned.
char *os_get_user_directory(const char *name)
{
#if defined(HAVE_GETPWNAM) && defined(HAVE_PWD_H)
  struct passwd *pw;
  if (name == NULL) {
    return NULL;
  }
  pw = getpwnam(name);
  if (pw != NULL) {
    // save the string from the static passwd entry into malloced memory
    return xstrdup(pw->pw_dir);
  }
#endif
  return NULL;
}

