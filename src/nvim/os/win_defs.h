#ifndef NVIM_OS_WIN_DEFS_H
#define NVIM_OS_WIN_DEFS_H

// winsock2.h must be first to avoid incompatibilities
// with winsock.h (included by windows.h)
#include <winsock2.h>
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

#define BACKSLASH_IN_FILENAME

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

/// TODO(equalsraf): libuv does not yet expose uv_translate_sys_error()
/// in its public API, include a version here until it can be used.
/// See https://github.com/libuv/libuv/issues/79

#ifndef ERROR_SYMLINK_NOT_SUPPORTED
# define ERROR_SYMLINK_NOT_SUPPORTED 1464
#endif

inline int win32_translate_sys_error(int sys_errno) {
  if (sys_errno <= 0) {
    return sys_errno;  // If < 0 then it's already a libuv error
  }

  switch (sys_errno) {
    case ERROR_NOACCESS:                    return UV_EACCES;
    case WSAEACCES:                         return UV_EACCES;
    case ERROR_ADDRESS_ALREADY_ASSOCIATED:  return UV_EADDRINUSE;
    case WSAEADDRINUSE:                     return UV_EADDRINUSE;
    case WSAEADDRNOTAVAIL:                  return UV_EADDRNOTAVAIL;
    case WSAEAFNOSUPPORT:                   return UV_EAFNOSUPPORT;
    case WSAEWOULDBLOCK:                    return UV_EAGAIN;
    case WSAEALREADY:                       return UV_EALREADY;
    case ERROR_INVALID_FLAGS:               return UV_EBADF;
    case ERROR_INVALID_HANDLE:              return UV_EBADF;
    case ERROR_LOCK_VIOLATION:              return UV_EBUSY;
    case ERROR_PIPE_BUSY:                   return UV_EBUSY;
    case ERROR_SHARING_VIOLATION:           return UV_EBUSY;
    case ERROR_OPERATION_ABORTED:           return UV_ECANCELED;
    case WSAEINTR:                          return UV_ECANCELED;
    case ERROR_NO_UNICODE_TRANSLATION:      return UV_ECHARSET;
    case ERROR_CONNECTION_ABORTED:          return UV_ECONNABORTED;
    case WSAECONNABORTED:                   return UV_ECONNABORTED;
    case ERROR_CONNECTION_REFUSED:          return UV_ECONNREFUSED;
    case WSAECONNREFUSED:                   return UV_ECONNREFUSED;
    case ERROR_NETNAME_DELETED:             return UV_ECONNRESET;
    case WSAECONNRESET:                     return UV_ECONNRESET;
    case ERROR_ALREADY_EXISTS:              return UV_EEXIST;
    case ERROR_FILE_EXISTS:                 return UV_EEXIST;
    case ERROR_BUFFER_OVERFLOW:             return UV_EFAULT;
    case WSAEFAULT:                         return UV_EFAULT;
    case ERROR_HOST_UNREACHABLE:            return UV_EHOSTUNREACH;
    case WSAEHOSTUNREACH:                   return UV_EHOSTUNREACH;
    case ERROR_INSUFFICIENT_BUFFER:         return UV_EINVAL;
    case ERROR_INVALID_DATA:                return UV_EINVAL;
    case ERROR_INVALID_PARAMETER:           return UV_EINVAL;
    case ERROR_SYMLINK_NOT_SUPPORTED:       return UV_EINVAL;
    case WSAEINVAL:                         return UV_EINVAL;
    case WSAEPFNOSUPPORT:                   return UV_EINVAL;
    case WSAESOCKTNOSUPPORT:                return UV_EINVAL;
    case ERROR_BEGINNING_OF_MEDIA:          return UV_EIO;
    case ERROR_BUS_RESET:                   return UV_EIO;
    case ERROR_CRC:                         return UV_EIO;
    case ERROR_DEVICE_DOOR_OPEN:            return UV_EIO;
    case ERROR_DEVICE_REQUIRES_CLEANING:    return UV_EIO;
    case ERROR_DISK_CORRUPT:                return UV_EIO;
    case ERROR_EOM_OVERFLOW:                return UV_EIO;
    case ERROR_FILEMARK_DETECTED:           return UV_EIO;
    case ERROR_GEN_FAILURE:                 return UV_EIO;
    case ERROR_INVALID_BLOCK_LENGTH:        return UV_EIO;
    case ERROR_IO_DEVICE:                   return UV_EIO;
    case ERROR_NO_DATA_DETECTED:            return UV_EIO;
    case ERROR_NO_SIGNAL_SENT:              return UV_EIO;
    case ERROR_OPEN_FAILED:                 return UV_EIO;
    case ERROR_SETMARK_DETECTED:            return UV_EIO;
    case ERROR_SIGNAL_REFUSED:              return UV_EIO;
    case WSAEISCONN:                        return UV_EISCONN;
    case ERROR_CANT_RESOLVE_FILENAME:       return UV_ELOOP;
    case ERROR_TOO_MANY_OPEN_FILES:         return UV_EMFILE;
    case WSAEMFILE:                         return UV_EMFILE;
    case WSAEMSGSIZE:                       return UV_EMSGSIZE;
    case ERROR_FILENAME_EXCED_RANGE:        return UV_ENAMETOOLONG;
    case ERROR_NETWORK_UNREACHABLE:         return UV_ENETUNREACH;
    case WSAENETUNREACH:                    return UV_ENETUNREACH;
    case WSAENOBUFS:                        return UV_ENOBUFS;
    case ERROR_BAD_PATHNAME:                return UV_ENOENT;
    case ERROR_DIRECTORY:                   return UV_ENOENT;
    case ERROR_FILE_NOT_FOUND:              return UV_ENOENT;
    case ERROR_INVALID_NAME:                return UV_ENOENT;
    case ERROR_INVALID_DRIVE:               return UV_ENOENT;
    case ERROR_INVALID_REPARSE_DATA:        return UV_ENOENT;
    case ERROR_MOD_NOT_FOUND:               return UV_ENOENT;
    case ERROR_PATH_NOT_FOUND:              return UV_ENOENT;
    case WSAHOST_NOT_FOUND:                 return UV_ENOENT;
    case WSANO_DATA:                        return UV_ENOENT;
    case ERROR_NOT_ENOUGH_MEMORY:           return UV_ENOMEM;
    case ERROR_OUTOFMEMORY:                 return UV_ENOMEM;
    case ERROR_CANNOT_MAKE:                 return UV_ENOSPC;
    case ERROR_DISK_FULL:                   return UV_ENOSPC;
    case ERROR_EA_TABLE_FULL:               return UV_ENOSPC;
    case ERROR_END_OF_MEDIA:                return UV_ENOSPC;
    case ERROR_HANDLE_DISK_FULL:            return UV_ENOSPC;
    case ERROR_NOT_CONNECTED:               return UV_ENOTCONN;
    case WSAENOTCONN:                       return UV_ENOTCONN;
    case ERROR_DIR_NOT_EMPTY:               return UV_ENOTEMPTY;
    case WSAENOTSOCK:                       return UV_ENOTSOCK;
    case ERROR_NOT_SUPPORTED:               return UV_ENOTSUP;
    case ERROR_BROKEN_PIPE:                 return UV_EOF;
    case ERROR_ACCESS_DENIED:               return UV_EPERM;
    case ERROR_PRIVILEGE_NOT_HELD:          return UV_EPERM;
    case ERROR_BAD_PIPE:                    return UV_EPIPE;
    case ERROR_NO_DATA:                     return UV_EPIPE;
    case ERROR_PIPE_NOT_CONNECTED:          return UV_EPIPE;
    case WSAESHUTDOWN:                      return UV_EPIPE;
    case WSAEPROTONOSUPPORT:                return UV_EPROTONOSUPPORT;
    case ERROR_WRITE_PROTECT:               return UV_EROFS;
    case ERROR_SEM_TIMEOUT:                 return UV_ETIMEDOUT;
    case WSAETIMEDOUT:                      return UV_ETIMEDOUT;
    case ERROR_NOT_SAME_DEVICE:             return UV_EXDEV;
    case ERROR_INVALID_FUNCTION:            return UV_EISDIR;
    case ERROR_META_EXPANSION_TOO_LONG:     return UV_E2BIG;
    default:                                return UV_UNKNOWN;
  }
}

#endif  // NVIM_OS_WIN_DEFS_H
