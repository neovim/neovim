/* vi:set ts=2 sts=2 sw=2:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * users.c -- operating system user information
 */

#include <uv.h>

#include "os.h"
#include "../garray.h"
#include "../misc2.h"
#ifdef HAVE_PWD_H
# include <pwd.h>
#endif

/*
 * Initialize users garray and fill it with os usernames.
 * Return Ok for success, FAIL for failure.
 */
int mch_get_usernames(garray_T *users)
{
  if (users == NULL) {
    return FALSE;
  }
  ga_init2(users, sizeof(char *), 20);

# if defined(HAVE_GETPWENT) && defined(HAVE_PWD_H)
  char *user;
  struct passwd *pw;

  setpwent();
  while ((pw = getpwent()) != NULL) {
    /* pw->pw_name shouldn't be NULL but just in case... */
    if (pw->pw_name != NULL) {
      if (ga_grow(users, 1) == FAIL) {
        return FAIL;
      }
      user = (char *)vim_strsave((char_u*)pw->pw_name);
      if (user == NULL) {
        return FAIL;
      }
      ((char **)(users->ga_data))[users->ga_len++] = user;
    }
  }
  endpwent();
# endif

  return OK;
}

