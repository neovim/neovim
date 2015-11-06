#ifndef NVIM_OS_OS_DEFS_H
#define NVIM_OS_OS_DEFS_H

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>

#ifdef WIN32
# include "nvim/os/win_defs.h"
#else
# include "nvim/os/unix_defs.h"
#endif

#if defined(DIRSIZ) && !defined(MAXNAMLEN)
# define MAXNAMLEN DIRSIZ
#endif

#if defined(UFS_MAXNAMLEN) && !defined(MAXNAMLEN)
# define MAXNAMLEN UFS_MAXNAMLEN    /* for dynix/ptx */
#endif

#if defined(NAME_MAX) && !defined(MAXNAMLEN)
# define MAXNAMLEN NAME_MAX         /* for Linux before .99p3 */
#endif

// Default value.
#ifndef MAXNAMLEN
# define MAXNAMLEN 512
#endif

#define BASENAMELEN (MAXNAMLEN - 5)

// Use the system path length if it makes sense.
#if defined(PATH_MAX) && (PATH_MAX > 1000)
# define MAXPATHL PATH_MAX
#else
# define MAXPATHL 1024
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

#define DFLT_ERRORFILE          "errors.err"

// Command-processing buffer. Use large buffers for all platforms.
#define CMDBUFFSIZE 1024

// Use up to 5 Mbyte for a buffer.
#ifndef DFLT_MAXMEM
# define DFLT_MAXMEM (5*1024)
#endif
// use up to 10 Mbyte for Vim.
#ifndef DFLT_MAXMEMTOT
# define DFLT_MAXMEMTOT (10*1024)
#endif

#if !defined(S_ISDIR) && defined(S_IFDIR)
# define S_ISDIR(m) (((m) & S_IFMT) == S_IFDIR)
#endif
#if !defined(S_ISREG) && defined(S_IFREG)
# define S_ISREG(m) (((m) & S_IFMT) == S_IFREG)
#endif
#if !defined(S_ISBLK) && defined(S_IFBLK)
# define S_ISBLK(m) (((m) & S_IFMT) == S_IFBLK)
#endif
#if !defined(S_ISSOCK) && defined(S_IFSOCK)
# define S_ISSOCK(m) (((m) & S_IFMT) == S_IFSOCK)
#endif
#if !defined(S_ISFIFO) && defined(S_IFIFO)
# define S_ISFIFO(m) (((m) & S_IFMT) == S_IFIFO)
#endif
#if !defined(S_ISCHR) && defined(S_IFCHR)
# define S_ISCHR(m) (((m) & S_IFMT) == S_IFCHR)
#endif

// Note: Some systems need both string.h and strings.h (Savage).  However,
// some systems can't handle both, only use string.h in that case.
#include <string.h>
#if defined(HAVE_STRINGS_H) && !defined(NO_STRINGS_WITH_STRING_H)
# include <strings.h>
#endif

/// Function to convert -errno error to char * error description
///
/// -errno errors are returned by a number of os functions.
#define os_strerror uv_strerror

#endif  // NVIM_OS_OS_DEFS_H
