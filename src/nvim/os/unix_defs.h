#pragma once
// IWYU pragma: private, include "nvim/os/os_defs.h"

#include <sys/param.h>  // IWYU pragma: export
#include <sys/socket.h>  // IWYU pragma: export
#include <unistd.h>  // IWYU pragma: export
#if defined(HAVE_TERMIOS_H)
# include <termios.h>  // IWYU pragma: export
#endif

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
