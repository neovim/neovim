// users.c -- operating system user information

#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <uv.h>

#include "auto/config.h"
#include "nvim/ascii_defs.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/memory.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/vim_defs.h"
#ifdef HAVE_PWD_FUNCS
# include <pwd.h>
#endif
#ifdef MSWIN
# include <lm.h>

# include "nvim/mbyte.h"
# include "nvim/message.h"
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/users.c.generated.h"
#endif

// All user names (for ~user completion as done by shell).
static garray_T ga_users = GA_EMPTY_INIT_VALUE;

// Add a user name to the list of users in garray_T *users.
// Do nothing if user name is NULL or empty.
static void add_user(garray_T *users, char *user, bool need_copy)
{
  char *user_copy = (user != NULL && need_copy)
                    ? xstrdup(user) : user;

  if (user_copy == NULL || *user_copy == NUL) {
    if (need_copy) {
      xfree(user_copy);
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

#ifdef HAVE_PWD_FUNCS
  {
    struct passwd *pw;

    setpwent();
    while ((pw = getpwent()) != NULL) {
      add_user(users, pw->pw_name, true);
    }
    endpwent();
  }
#elif defined(MSWIN)
  {
    DWORD nusers = 0, ntotal = 0, i;
    PUSER_INFO_0 uinfo;

    if (NetUserEnum(NULL, 0, 0, (LPBYTE *)&uinfo, MAX_PREFERRED_LENGTH,
                    &nusers, &ntotal, NULL) == NERR_Success) {
      for (i = 0; i < nusers; i++) {
        char *user;
        int conversion_result = utf16_to_utf8(uinfo[i].usri0_name, -1, &user);
        if (conversion_result != 0) {
          semsg("utf16_to_utf8 failed: %d", conversion_result);
          break;
        }
        add_user(users, user, false);
      }

      NetApiBufferFree(uinfo);
    }
  }
#endif
#ifdef HAVE_PWD_FUNCS
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

        if (strcmp(local_user, user_env) == 0) {
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
#endif

  return OK;
}

/// Gets the username that owns the current Nvim process.
///
/// @param s[out] Username.
/// @param len Length of `s`.
///
/// @return OK if a name found.
int os_get_username(char *s, size_t len)
{
#ifdef UNIX
  return os_get_uname((uv_uid_t)getuid(), s, len);
#else
  // TODO(equalsraf): Windows GetUserName()
  return os_get_uname((uv_uid_t)0, s, len);
#endif
}

/// Gets the username associated with `uid`.
///
/// @param uid User id.
/// @param s[out] Username, or `uid` on failure.
/// @param len Length of `s`.
///
/// @return OK if a username was found, else FAIL.
int os_get_uname(uv_uid_t uid, char *s, size_t len)
{
#ifdef HAVE_PWD_FUNCS
  struct passwd *pw;

  if ((pw = getpwuid(uid)) != NULL  // NOLINT(runtime/threadsafe_fn)
      && pw->pw_name != NULL && *(pw->pw_name) != NUL) {
    xstrlcpy(s, pw->pw_name, len);
    return OK;
  }
#endif
  snprintf(s, len, "%d", (int)uid);
  return FAIL;  // a number is not a name
}

/// Gets the user directory for the given username, or NULL on failure.
///
/// Caller must free() the returned string.
char *os_get_userdir(const char *name)
{
#ifdef HAVE_PWD_FUNCS
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

#if defined(EXITFREE)

void free_users(void)
{
  ga_clear_strings(&ga_users);
}

#endif

/// Find all user names for user completion.
///
/// Done only once and then cached.
static void init_users(void)
{
  static bool lazy_init_done = false;

  if (lazy_init_done) {
    return;
  }

  lazy_init_done = true;

  os_get_usernames(&ga_users);
}

/// Given to ExpandGeneric() to obtain user names.
char *get_users(expand_T *xp, int idx)
{
  init_users();
  if (idx < ga_users.ga_len) {
    return ((char **)ga_users.ga_data)[idx];
  }
  return NULL;
}

/// Check whether name matches a user name.
///
/// @return 0 if name does not match any user name.
///         1 if name partially matches the beginning of a user name.
///         2 is name fully matches a user name.
int match_user(char *name)
{
  int n = (int)strlen(name);
  int result = 0;

  init_users();
  for (int i = 0; i < ga_users.ga_len; i++) {
    if (strcmp(((char **)ga_users.ga_data)[i], name) == 0) {
      return 2;       // full match
    }
    if (strncmp(((char **)ga_users.ga_data)[i], name, (size_t)n) == 0) {
      result = 1;       // partial match
    }
  }
  return result;
}
