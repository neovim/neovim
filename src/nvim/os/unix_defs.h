#ifndef NVIM_OS_UNIX_DEFS_H
#define NVIM_OS_UNIX_DEFS_H

// Windows doesn't have unistd.h, so we include it here to avoid numerous
// instances of `#ifdef WIN32'.
#include <unistd.h>

// POSIX.1-2008 says that NAME_MAX should be in here
#include <limits.h>

#define TEMP_DIR_NAMES { "$TMPDIR", "/tmp", ".", "~" }
#define TEMP_FILE_PATH_MAXLEN 256

#define HAVE_ACL (HAVE_POSIX_ACL || HAVE_SOLARIS_ACL)

// Special wildcards that need to be handled by the shell.
#define SPECIAL_WILDCHAR "`'{"

// Character that separates entries in $PATH.
#define ENV_SEPCHAR ':'
#define ENV_SEPSTR  ":"

#endif  // NVIM_OS_UNIX_DEFS_H
