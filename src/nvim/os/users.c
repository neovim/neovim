// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// users.c -- operating system user information

#include <uv.h>

#include "nvim/ascii.h"
#include "nvim/os/os.h"
#include "nvim/garray.h"
#include "nvim/memory.h"
#include "nvim/strings.h"
#ifdef HAVE_PWD_H
# include <pwd.h>
#endif
#ifdef WIN32
# include <lm.h>
#endif

// Add a user name to the list of users in garray_T *users.
// Do nothing if user name is NULL or empty.
static void add_user(garray_T *users, char *user, bool need_copy)
{
  char *user_copy = (user != NULL && need_copy)
    ? xstrdup(user) : user;

  if (user_copy == NULL || *user_copy == NUL) {
    if (need_copy) {
      xfree(user);
    }
    return;
  }
  GA_APPEND(char *, users, user_copy);
}

// Initialize users garray and fill it with os usernames.
// Return Ok for success, FAIL for failure.
int os_get_usernames(garray_T *users)
{
  if (users == NULL) {
    return FAIL;
  }
  ga_init(users, sizeof(char *), 20);

# if defined(HAVE_GETPWENT) && defined(HAVE_PWD_H)
  {
    struct passwd *pw;

    setpwent();
    while ((pw = getpwent()) != NULL) {
      add_user(users, pw->pw_name, true);
    }
    endpwent();
  }
# elif defined(WIN32)
  {
    DWORD nusers = 0, ntotal = 0, i;
    PUSER_INFO_0 uinfo;

    if (NetUserEnum(NULL, 0, 0, (LPBYTE *)&uinfo, MAX_PREFERRED_LENGTH,
                    &nusers, &ntotal, NULL) == NERR_Success) {
      for (i = 0; i < nusers; i++) {
        char *user;
        int conversion_result = utf16_to_utf8(uinfo[i].usri0_name, -1, &user);
        if (conversion_result != 0) {
          EMSG2("utf16_to_utf8 failed: %d", conversion_result);
          break;
        }
        add_user(users, user, false);
      }

      NetApiBufferFree(uinfo);
    }
  }
# endif
# if defined(HAVE_GETPWNAM)
  {
    const char *user_env = os_getenv("USER");

    // The $USER environment variable may be a valid remote user name (NIS,
    // LDAP) not already listed by getpwent(), as getpwent() only lists
    // local user names.  If $USER is not already listed, check whether it
    // is a valid remote user name using getpwnam() and if it is, add it to
    // the list of user names.

    if (user_env != NULL && *user_env != NUL) {
      int i;

      for (i = 0; i < users->ga_len; i++) {
        char *local_user = ((char **)users->ga_data)[i];

        if (STRCMP(local_user, user_env) == 0) {
          break;
        }
      }

      if (i == users->ga_len) {
        struct passwd *pw = getpwnam(user_env);  // NOLINT

        if (pw != NULL) {
          add_user(users, pw->pw_name, true);
        }
      }
    }
  }
# endif

  return OK;
}

// Insert user name in s[len].
// Return OK if a name found.
int os_get_user_name(char *s, size_t len)
{
#ifdef UNIX
  return os_get_uname((uv_uid_t)getuid(), s, len);
#else
  // TODO(equalsraf): Windows GetUserName()
  return os_get_uname((uv_uid_t)0, s, len);
#endif
}

// Insert user name for "uid" in s[len].
// Return OK if a name found.
// If the name is not found, write the uid into s[len] and return FAIL.
int os_get_uname(uv_uid_t uid, char *s, size_t len)
{
#if defined(HAVE_PWD_H) && defined(HAVE_GETPWUID)
  struct passwd *pw;

  if ((pw = getpwuid(uid)) != NULL  // NOLINT(runtime/threadsafe_fn)
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
  if (name == NULL || *name == NUL) {
    return NULL;
  }
  struct passwd *pw = getpwnam(name);  // NOLINT(runtime/threadsafe_fn)
  if (pw != NULL) {
    // save the string from the static passwd entry into malloced memory
    return xstrdup(pw->pw_dir);
  }
#endif
  return NULL;
}

