/* vi:set ts=2 sts=2 sw=2:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * env.c -- environment variable access
 */

#include <uv.h>

#include "os/os.h"
#include "misc2.h"

#ifdef HAVE_CRT_EXTERNS_H
#include <crt_externs.h>
#endif

const char *mch_getenv(const char *name)
{
  return getenv(name);
}

int mch_setenv(const char *name, const char *value, int overwrite)
{
  return setenv(name, value, overwrite);
}

char *mch_getenvname_at_index(size_t index)
{
# if defined(AMIGA) || defined(__MRC__) || defined(__SC__)
  /*
   * No environ[] on the Amiga and on the Mac (using MPW).
   */
  return NULL;
# else
# if defined(HAVE__NSGETENVIRON)
  char **environ = *_NSGetEnviron();
# elif !defined(__WIN32__)
  /* Borland C++ 5.2 has this in a header file. */
  extern char         **environ;
# endif
  // check if index is inside the environ array
  for (size_t i = 0; i < index; i++) {
    if (environ[i] == NULL) {
      return NULL;
    }
  }
  char *str = environ[index];
  if (str == NULL) {
    return NULL;
  }
  int namesize = 0;
  while (str[namesize] != '=' && str[namesize] != NUL) {
    namesize++;
  }
  char *name = (char *)vim_strnsave((char_u *)str, namesize);
  return name;
# endif
}

