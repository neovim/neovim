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

#define NVIM_CONF_DIR "$XDG_CONFIG_HOME/nvim/"
#define NVIM_DATA_DIR "$XDG_DATA_HOME/nvim/"

#ifndef SYS_VIMRC_FILE
# define SYS_VIMRC_FILE "$VIM/nvimrc"
#endif
#ifndef DFLT_HELPFILE
# define DFLT_HELPFILE  "$VIMRUNTIME/doc/help.txt"
#endif
#ifndef SYNTAX_FNAME
# define SYNTAX_FNAME   "$VIMRUNTIME/syntax/%s.vim"
#endif
// Not used anymore ?
#ifndef USR_EXRC_FILE
# define USR_EXRC_FILE "~/.exrc"
#endif
#ifndef USR_VIMRC_FILE
# define USR_VIMRC_FILE NVIM_CONF_DIR "/init.vim"
#endif
// Not used anymore ?
#ifndef USR_VIMRC_FILE2
# define USR_VIMRC_FILE2     "~/.nvim/nvimrc"
#endif
// Not used anymore ?
#ifndef EXRC_FILE
# define EXRC_FILE      ".exrc"
#endif
// Not used anymore ?
#ifndef VIMRC_FILE
# define VIMRC_FILE     ".nvimrc"
#endif
#ifndef VIMINFO_FILE
# define VIMINFO_FILE NVIM_DATA_DIR "/viminfo"
#endif

// Default for 'backupdir'.
#ifndef DFLT_BDIR
# define DFLT_BDIR    ".,$XDG_DATA_HOME/nvim/backup/"
#endif

// Default for 'directory'.
#ifndef DFLT_DIR
# define DFLT_DIR     "$XDG_DATA_HOME/nvim/swap//"
#endif

// Default for 'viewdir'.
#ifndef DFLT_VDIR
# define DFLT_VDIR    "$XDG_DATA_HOME/nvim/view/"
#endif

#ifdef RUNTIME_GLOBAL
# define DFLT_RUNTIMEPATH NVIM_CONF_DIR "," RUNTIME_GLOBAL ",$VIMRUNTIME," \
                          RUNTIME_GLOBAL "/after," NVIM_CONF_DIR "/after"
#else
# define DFLT_RUNTIMEPATH \
  NVIM_CONF_DIR ",$VIM/vimfiles,$VIMRUNTIME,$VIM/vimfiles/after,"\
  NVIM_CONF_DIR "/after"
#endif

#endif  // NVIM_OS_UNIX_DEFS_H
