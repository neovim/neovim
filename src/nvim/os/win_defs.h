#ifndef NVIM_OS_WIN_DEFS_H
#define NVIM_OS_WIN_DEFS_H

#include <windows.h>
#include <sys/stat.h>
#include <io.h>
#include <stdio.h>

// Windows does not have S_IFLNK but libuv defines it
// and sets the flag for us when calling uv_fs_stat.
#include <uv.h>

#define NAME_MAX _MAX_PATH

#define TEMP_DIR_NAMES {"$TMP", "$TEMP", "$USERPROFILE", ""}
#define TEMP_FILE_PATH_MAXLEN _MAX_PATH

#define FNAME_ILLEGAL "\"*?><|"

// Separator character for environment variables.
#define ENV_SEPCHAR ';'

#define USE_CRNL

// We have our own RGB macro in macros.h.
#undef RGB

#ifdef _MSC_VER
# ifndef inline
#  define inline __inline
# endif
# ifndef restrict
#  define restrict __restrict
# endif
# ifndef STDOUT_FILENO
#  define STDOUT_FILENO _fileno(stdout)
# endif
# ifndef STDERR_FILENO
#  define STDERR_FILENO _fileno(stderr)
# endif
# ifndef S_IXUSR
#  define S_IXUSR S_IEXEC
# endif
#endif

#ifdef _MSC_VER
typedef SSIZE_T ssize_t;
#endif

#ifndef SSIZE_MAX
# ifdef _WIN64
#  define SSIZE_MAX _I64_MAX
# else
#  define SSIZE_MAX LONG_MAX
# endif
#endif

#ifndef O_NOFOLLOW
# define O_NOFOLLOW 0
#endif

#if !defined(S_ISDIR) && defined(S_IFDIR)
# define S_ISDIR(m) (((m) & S_IFMT) == S_IFDIR)
#endif
#if !defined(S_ISREG) && defined(S_IFREG)
# define S_ISREG(m) (((m) & S_IFMT) == S_IFREG)
#endif
#if !defined(S_ISLNK) && defined(S_IFLNK)
# define S_ISLNK(m) (((m) & S_IFMT) == S_IFLNK)
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

#endif  // NVIM_OS_WIN_DEFS_H
