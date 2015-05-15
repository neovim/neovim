#ifndef NVIM_OS_WIN_DEFS_H
#define NVIM_OS_WIN_DEFS_H

// winsock2.h must be before windows.h - or so says Mingw
#include <winsock2.h>
#include <windows.h>
#include <uv.h>

#include <stdio.h>
#include <time.h>

#define TEMP_DIR_NAMES {"$TMP", "$TEMP", "$USERPROFILE", ""}
#define TEMP_FILE_PATH_MAXLEN _MAX_PATH

#define BASENAMELEN    _MAX_PATH
#define TEMPNAMELEN    _MAX_PATH

typedef uv_uid_t uid_t;

// defs

#ifndef VIMINFO_FILE
#  define VIMINFO_FILE "$HOME\\_nviminfo"
#endif

#ifndef VIMRC_FILE
# define VIMRC_FILE     "_nvimrc"
#endif

#ifndef USR_VIMRC_FILE
#  define USR_VIMRC_FILE "$HOME\\_nvimrc"
#endif

#ifndef EXRC_FILE
# define EXRC_FILE      "_exrc"
#endif

#ifndef EVIM_FILE
# define EVIM_FILE      "$VIMRUNTIME\\evim.vim"
#endif

#ifndef SYNTAX_FNAME
# define SYNTAX_FNAME   "$VIMRUNTIME\\syntax\\%s.vim"
#endif

#ifndef FILETYPE_FILE
# define FILETYPE_FILE  "filetype.vim"
#endif
#ifndef FTPLUGIN_FILE
# define FTPLUGIN_FILE  "ftplugin.vim"
#endif
#ifndef INDENT_FILE
# define INDENT_FILE    "indent.vim"
#endif
#ifndef FTOFF_FILE
# define FTOFF_FILE     "ftoff.vim"
#endif
#ifndef FTPLUGOF_FILE
# define FTPLUGOF_FILE  "ftplugof.vim"
#endif
#ifndef INDOFF_FILE
# define INDOFF_FILE    "indoff.vim"
#endif

#ifndef USR_EXRC_FILE
#  define USR_EXRC_FILE "$HOME\\_exrc"
#endif

#ifndef DFLT_BDIR
# define DFLT_BDIR      ".,$TEMP,c:\\tmp,c:\\temp" /* default for 'backupdir' */
#endif

#ifndef DFLT_VDIR
#   define DFLT_VDIR    "$HOME\\_nvim\\view"       /* default for 'viewdir' */
#endif

#ifndef DFLT_DIR
# define DFLT_DIR       ".,$TEMP,c:\\tmp,c:\\temp" /* default for 'directory' */
#endif

#define DFLT_ERRORFILE  "errors.err"

#ifndef DFLT_HELPFILE
# define DFLT_HELPFILE  "$VIMRUNTIME\\doc\\help.txt"
#endif

#ifdef RUNTIME_GLOBAL
# define DFLT_RUNTIMEPATH     "~\\.nvim," RUNTIME_GLOBAL ",$VIMRUNTIME," \
  RUNTIME_GLOBAL "\\after,~\\_nvim/after"
#else
# define DFLT_RUNTIMEPATH \
  "~\\.nvim,$VIM\\vimfiles,$VIMRUNTIME,$VIM\\vimfiles\\after,~\\.nvim\\after"
#endif


#endif  // NVIM_OS_WIN_DEFS_H
