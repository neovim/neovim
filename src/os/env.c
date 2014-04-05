// env.c -- environment variable access

#include <uv.h>

#include "os/os.h"
#include "misc2.h"

#ifdef HAVE__NSGETENVIRON
#include <crt_externs.h>
#endif

#ifdef HAVE_SYS_UTSNAME_H
#include <sys/utsname.h>
#endif

const char *os_getenv(const char *name)
{
  return getenv(name);
}

int os_setenv(const char *name, const char *value, int overwrite)
{
  return setenv(name, value, overwrite);
}

char *os_getenvname_at_index(size_t index)
{
# if defined(AMIGA) || defined(__MRC__) || defined(__SC__)
  // No environ[] on the Amiga and on the Mac (using MPW).
  return NULL;
# else
# if defined(HAVE__NSGETENVIRON)
  char **environ = *_NSGetEnviron();
# elif !defined(__WIN32__)
  // Borland C++ 5.2 has this in a header file.
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


long os_get_pid()
{
#ifdef _WIN32
  return (long)GetCurrentProcessId();
#else
  return (long)getpid();
#endif
}

void os_get_hostname(char *hostname, size_t len)
{
#ifdef HAVE_SYS_UTSNAME_H
  struct utsname vutsname;

  if (uname(&vutsname) < 0) {
    *hostname = '\0';
  } else {
    strncpy(hostname, vutsname.nodename, len - 1);
    hostname[len - 1] = '\0';
  }
#else
  // TODO: Implement this for windows. See the implementation used in vim:
  // https://code.google.com/p/vim/source/browse/src/os_win32.c?r=6b69d8dde19e32909f4ee3a6337e6a2ecfbb6f72#2899
  *hostname = '\0';
#endif
}

