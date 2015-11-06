#ifndef NVIM_OS_UNIX_DEFS_H
#define NVIM_OS_UNIX_DEFS_H

#include <unistd.h>
#include <signal.h>

// Defines BSD, if it's a BSD system.
#ifdef HAVE_SYS_PARAM_H
# include <sys/param.h>
#endif


#define TEMP_DIR_NAMES {"$TMPDIR", "/tmp", ".", "~"}
#define TEMP_FILE_PATH_MAXLEN 256

#define HAVE_ACL (HAVE_POSIX_ACL || HAVE_SOLARIS_ACL)

// Special wildcards that need to be handled by the shell.
#define SPECIAL_WILDCHAR "`'{"

// Unix system-dependent file names
#ifndef SYS_VIMRC_FILE
# define SYS_VIMRC_FILE "$VIM/sysinit.vim"
#endif
#ifndef DFLT_HELPFILE
# define DFLT_HELPFILE  "$VIMRUNTIME/doc/help.txt"
#endif
#ifndef SYNTAX_FNAME
# define SYNTAX_FNAME   "$VIMRUNTIME/syntax/%s.vim"
#endif
#ifndef EXRC_FILE
# define EXRC_FILE      ".exrc"
#endif
#ifndef VIMRC_FILE
# define VIMRC_FILE     ".nvimrc"
#endif

#endif  // NVIM_OS_UNIX_DEFS_H
