#pragma once
// IWYU pragma: private, include "nvim/os/os_defs.h"

// IWYU pragma: begin_exports
#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/in.h>
#include <pthread.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <unistd.h>
#ifdef HAVE_TERMIOS_H
# include <termios.h>
#endif
// IWYU pragma: end_exports

#define TEMP_DIR_NAMES { "$TMPDIR", "/tmp", ".", "~" }
#define TEMP_FILE_PATH_MAXLEN 256

#define HAVE_ACL (HAVE_POSIX_ACL || HAVE_SOLARIS_ACL)

// Special wildcards that need to be handled by the shell.
#define SPECIAL_WILDCHAR "`'{"

// Character that separates entries in $PATH.
#define ENV_SEPCHAR ':'
#define ENV_SEPSTR  ":"
