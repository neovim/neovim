#ifndef NVIM_OS_FCNTL_H
#define NVIM_OS_FCNTL_H

// Defining _GNU_SOURCE yields gnu-statement-expression warnings for assert()
// macros from assert.h, so make it as local as possible. _GNU_SOURCE is needed
// for O_NOFOLLOW on some systems (pre POSIX.1-2008; glibc 2.11 and earlier:
// #4042). Unfortunately, as features.h is using usual double-include guard it
// is not possible to just define _GNU_SOURCE here and be done, so here is
// a hack which is supposed to work around the problem: fcntl.h file only
// defines a global constant which is initialized in fcntl.c where it is
// possible to safely define _GNU_SOURCE without affecting other files.
#include <fcntl.h>

extern const int kO_NOFOLLOW;
#ifndef O_NOFOLLOW
# define O_NOFOLLOW kO_NOFOLLOW
#endif

#endif  // NVIM_OS_FCNTL_H
