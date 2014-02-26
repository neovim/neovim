/* Copyright Joyent, Inc. and other Node contributors. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

#include <assert.h>
#include <stdlib.h>
#include <malloc.h>
#include <direct.h>
#include <errno.h>
#include <fcntl.h>
#include <io.h>
#include <limits.h>
#include <sys/stat.h>
#include <sys/utime.h>
#include <stdio.h>

#include "uv.h"
#include "internal.h"
#include "req-inl.h"
#include "handle-inl.h"


#define UV_FS_FREE_PATHS         0x0002
#define UV_FS_FREE_PTR           0x0008
#define UV_FS_CLEANEDUP          0x0010


#define QUEUE_FS_TP_JOB(loop, req)                                          \
  do {                                                                      \
    if (!QueueUserWorkItem(&uv_fs_thread_proc,                              \
                           req,                                             \
                           WT_EXECUTEDEFAULT)) {                            \
      return uv_translate_sys_error(GetLastError());                        \
    }                                                                       \
    uv__req_register(loop, req);                                            \
  } while (0)

#define SET_REQ_RESULT(req, result_value)                                   \
  do {                                                                      \
    req->result = (result_value);                                           \
    if (req->result == -1) {                                                \
      req->sys_errno_ = _doserrno;                                          \
      req->result = uv_translate_sys_error(req->sys_errno_);                \
    }                                                                       \
  } while (0)

#define SET_REQ_WIN32_ERROR(req, sys_errno)                                 \
  do {                                                                      \
    req->sys_errno_ = (sys_errno);                                          \
    req->result = uv_translate_sys_error(req->sys_errno_);                  \
  } while (0)

#define SET_REQ_UV_ERROR(req, uv_errno, sys_errno)                          \
  do {                                                                      \
    req->result = (uv_errno);                                               \
    req->sys_errno_ = (sys_errno);                                          \
  } while (0)

#define VERIFY_FD(fd, req)                                                  \
  if (fd == -1) {                                                           \
    req->result = UV_EBADF;                                                 \
    req->sys_errno_ = ERROR_INVALID_HANDLE;                                 \
    return;                                                                 \
  }

#define FILETIME_TO_UINT(filetime)                                          \
   (*((uint64_t*) &(filetime)) - 116444736000000000ULL)

#define FILETIME_TO_TIME_T(filetime)                                        \
   (FILETIME_TO_UINT(filetime) / 10000000ULL)

#define FILETIME_TO_TIME_NS(filetime, secs)                                 \
   ((FILETIME_TO_UINT(filetime) - (secs * 10000000ULL)) * 100)

#define FILETIME_TO_TIMESPEC(ts, filetime)                                  \
   do {                                                                     \
     (ts).tv_sec = (long) FILETIME_TO_TIME_T(filetime);                     \
     (ts).tv_nsec = (long) FILETIME_TO_TIME_NS(filetime, (ts).tv_sec);      \
   } while(0)

#define TIME_T_TO_FILETIME(time, filetime_ptr)                              \
  do {                                                                      \
    *(uint64_t*) (filetime_ptr) = ((int64_t) (time) * 10000000LL) +         \
                                  116444736000000000ULL;                    \
  } while(0)

#define IS_SLASH(c) ((c) == L'\\' || (c) == L'/')
#define IS_LETTER(c) (((c) >= L'a' && (c) <= L'z') || \
  ((c) >= L'A' && (c) <= L'Z'))

const WCHAR JUNCTION_PREFIX[] = L"\\??\\";
const WCHAR JUNCTION_PREFIX_LEN = 4;

const WCHAR LONG_PATH_PREFIX[] = L"\\\\?\\";
const WCHAR LONG_PATH_PREFIX_LEN = 4;


void uv_fs_init() {
  _fmode = _O_BINARY;
}


INLINE static int fs__capture_path(uv_loop_t* loop, uv_fs_t* req,
    const char* path, const char* new_path, const int copy_path) {
  char* buf;
  char* pos;
  ssize_t buf_sz = 0, path_len, pathw_len, new_pathw_len;

  /* new_path can only be set if path is also set. */
  assert(new_path == NULL || path != NULL);

  if (path != NULL) {
    pathw_len = MultiByteToWideChar(CP_UTF8,
                                    0,
                                    path,
                                    -1,
                                    NULL,
                                    0);
    if (pathw_len == 0) {
      return GetLastError();
    }

    buf_sz += pathw_len * sizeof(WCHAR);
  }

  if (path != NULL && copy_path) {
    path_len = 1 + strlen(path);
    buf_sz += path_len;
  }

  if (new_path != NULL) {
    new_pathw_len = MultiByteToWideChar(CP_UTF8,
                                        0,
                                        new_path,
                                        -1,
                                        NULL,
                                        0);
    if (new_pathw_len == 0) {
      return GetLastError();
    }

    buf_sz += new_pathw_len * sizeof(WCHAR);
  }


  if (buf_sz == 0) {
    req->pathw = NULL;
    req->new_pathw = NULL;
    req->path = NULL;
    return 0;
  }

  buf = (char*) malloc(buf_sz);
  if (buf == NULL) {
    return ERROR_OUTOFMEMORY;
  }

  pos = buf;

  if (path != NULL) {
    DWORD r = MultiByteToWideChar(CP_UTF8,
                                  0,
                                  path,
                                  -1,
                                  (WCHAR*) pos,
                                  pathw_len);
    assert(r == pathw_len);
    req->pathw = (WCHAR*) pos;
    pos += r * sizeof(WCHAR);
  } else {
    req->pathw = NULL;
  }

  if (new_path != NULL) {
    DWORD r = MultiByteToWideChar(CP_UTF8,
                                  0,
                                  new_path,
                                  -1,
                                  (WCHAR*) pos,
                                  new_pathw_len);
    assert(r == new_pathw_len);
    req->new_pathw = (WCHAR*) pos;
    pos += r * sizeof(WCHAR);
  } else {
    req->new_pathw = NULL;
  }

  if (!copy_path) {
    req->path = path;
  } else if (path) {
    memcpy(pos, path, path_len);
    assert(path_len == buf_sz - (pos - buf));
    req->path = pos;
  } else {
    req->path = NULL;
  }

  req->flags |= UV_FS_FREE_PATHS;

  return 0;
}



INLINE static void uv_fs_req_init(uv_loop_t* loop, uv_fs_t* req,
    uv_fs_type fs_type, const uv_fs_cb cb) {
  uv_req_init(loop, (uv_req_t*) req);

  req->type = UV_FS;
  req->loop = loop;
  req->flags = 0;
  req->fs_type = fs_type;
  req->result = 0;
  req->ptr = NULL;
  req->path = NULL;

  if (cb != NULL) {
    req->cb = cb;
    memset(&req->overlapped, 0, sizeof(req->overlapped));
  }
}


INLINE static int fs__readlink_handle(HANDLE handle, char** target_ptr,
    uint64_t* target_len_ptr) {
  char buffer[MAXIMUM_REPARSE_DATA_BUFFER_SIZE];
  REPARSE_DATA_BUFFER* reparse_data = (REPARSE_DATA_BUFFER*) buffer;
  WCHAR *w_target;
  DWORD w_target_len;
  char* target;
  int target_len;
  DWORD bytes;

  if (!DeviceIoControl(handle,
                       FSCTL_GET_REPARSE_POINT,
                       NULL,
                       0,
                       buffer,
                       sizeof buffer,
                       &bytes,
                       NULL)) {
    return -1;
  }

  if (reparse_data->ReparseTag == IO_REPARSE_TAG_SYMLINK) {
    /* Real symlink */
    w_target = reparse_data->SymbolicLinkReparseBuffer.PathBuffer +
        (reparse_data->SymbolicLinkReparseBuffer.SubstituteNameOffset /
        sizeof(WCHAR));
    w_target_len =
        reparse_data->SymbolicLinkReparseBuffer.SubstituteNameLength /
        sizeof(WCHAR);

    /* Real symlinks can contain pretty much everything, but the only thing */
    /* we really care about is undoing the implicit conversion to an NT */
    /* namespaced path that CreateSymbolicLink will perform on absolute */
    /* paths. If the path is win32-namespaced then the user must have */
    /* explicitly made it so, and we better just return the unmodified */
    /* reparse data. */
    if (w_target_len >= 4 &&
        w_target[0] == L'\\' &&
        w_target[1] == L'?' &&
        w_target[2] == L'?' &&
        w_target[3] == L'\\') {
      /* Starts with \??\ */
      if (w_target_len >= 6 &&
          ((w_target[4] >= L'A' && w_target[4] <= L'Z') ||
           (w_target[4] >= L'a' && w_target[4] <= L'z')) &&
          w_target[5] == L':' &&
          (w_target_len == 6 || w_target[6] == L'\\')) {
        /* \??\�drive�:\ */
        w_target += 4;
        w_target_len -= 4;

      } else if (w_target_len >= 8 &&
                 (w_target[4] == L'U' || w_target[4] == L'u') &&
                 (w_target[5] == L'N' || w_target[5] == L'n') &&
                 (w_target[6] == L'C' || w_target[6] == L'c') &&
                 w_target[7] == L'\\') {
        /* \??\UNC\�server�\�share�\ - make sure the final path looks like */
        /* \\�server�\�share�\ */
        w_target += 6;
        w_target[0] = L'\\';
        w_target_len -= 6;
      }
    }

  } else if (reparse_data->ReparseTag == IO_REPARSE_TAG_MOUNT_POINT) {
    /* Junction. */
    w_target = reparse_data->MountPointReparseBuffer.PathBuffer +
        (reparse_data->MountPointReparseBuffer.SubstituteNameOffset /
        sizeof(WCHAR));
    w_target_len = reparse_data->MountPointReparseBuffer.SubstituteNameLength /
        sizeof(WCHAR);

    /* Only treat junctions that look like \??\�drive�:\ as symlink. */
    /* Junctions can also be used as mount points, like \??\Volume{�guid�}, */
    /* but that's confusing for programs since they wouldn't be able to */
    /* actually understand such a path when returned by uv_readlink(). */
    /* UNC paths are never valid for junctions so we don't care about them. */
    if (!(w_target_len >= 6 &&
          w_target[0] == L'\\' &&
          w_target[1] == L'?' &&
          w_target[2] == L'?' &&
          w_target[3] == L'\\' &&
          ((w_target[4] >= L'A' && w_target[4] <= L'Z') ||
           (w_target[4] >= L'a' && w_target[4] <= L'z')) &&
          w_target[5] == L':' &&
          (w_target_len == 6 || w_target[6] == L'\\'))) {
      SetLastError(ERROR_SYMLINK_NOT_SUPPORTED);
      return -1;
    }

    /* Remove leading \??\ */
    w_target += 4;
    w_target_len -= 4;

  } else {
    /* Reparse tag does not indicate a symlink. */
    SetLastError(ERROR_SYMLINK_NOT_SUPPORTED);
    return -1;
  }

  /* If needed, compute the length of the target. */
  if (target_ptr != NULL || target_len_ptr != NULL) {
    /* Compute the length of the target. */
    target_len = WideCharToMultiByte(CP_UTF8,
                                     0,
                                     w_target,
                                     w_target_len,
                                     NULL,
                                     0,
                                     NULL,
                                     NULL);
    if (target_len == 0) {
      return -1;
    }
  }

  /* If requested, allocate memory and convert to UTF8. */
  if (target_ptr != NULL) {
    int r;
    target = (char*) malloc(target_len + 1);
    if (target == NULL) {
      SetLastError(ERROR_OUTOFMEMORY);
      return -1;
    }

    r = WideCharToMultiByte(CP_UTF8,
                            0,
                            w_target,
                            w_target_len,
                            target,
                            target_len,
                            NULL,
                            NULL);
    assert(r == target_len);
    target[target_len] = '\0';

    *target_ptr = target;
  }

  if (target_len_ptr != NULL) {
    *target_len_ptr = target_len;
  }

  return 0;
}


void fs__open(uv_fs_t* req) {
  DWORD access;
  DWORD share;
  DWORD disposition;
  DWORD attributes = 0;
  HANDLE file;
  int fd, current_umask;
  int flags = req->file_flags;

  /* Obtain the active umask. umask() never fails and returns the previous */
  /* umask. */
  current_umask = umask(0);
  umask(current_umask);

  /* convert flags and mode to CreateFile parameters */
  switch (flags & (_O_RDONLY | _O_WRONLY | _O_RDWR)) {
  case _O_RDONLY:
    access = FILE_GENERIC_READ;
    attributes |= FILE_FLAG_BACKUP_SEMANTICS;
    break;
  case _O_WRONLY:
    access = FILE_GENERIC_WRITE;
    break;
  case _O_RDWR:
    access = FILE_GENERIC_READ | FILE_GENERIC_WRITE;
    break;
  default:
    goto einval;
  }

  if (flags & _O_APPEND) {
    access &= ~FILE_WRITE_DATA;
    access |= FILE_APPEND_DATA;
    attributes &= ~FILE_FLAG_BACKUP_SEMANTICS;
  }

  /*
   * Here is where we deviate significantly from what CRT's _open()
   * does. We indiscriminately use all the sharing modes, to match
   * UNIX semantics. In particular, this ensures that the file can
   * be deleted even whilst it's open, fixing issue #1449.
   */
  share = FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE;

  switch (flags & (_O_CREAT | _O_EXCL | _O_TRUNC)) {
  case 0:
  case _O_EXCL:
    disposition = OPEN_EXISTING;
    break;
  case _O_CREAT:
    disposition = OPEN_ALWAYS;
    break;
  case _O_CREAT | _O_EXCL:
  case _O_CREAT | _O_TRUNC | _O_EXCL:
    disposition = CREATE_NEW;
    break;
  case _O_TRUNC:
  case _O_TRUNC | _O_EXCL:
    disposition = TRUNCATE_EXISTING;
    break;
  case _O_CREAT | _O_TRUNC:
    disposition = CREATE_ALWAYS;
    break;
  default:
    goto einval;
  }

  attributes |= FILE_ATTRIBUTE_NORMAL;
  if (flags & _O_CREAT) {
    if (!((req->mode & ~current_umask) & _S_IWRITE)) {
      attributes |= FILE_ATTRIBUTE_READONLY;
    }
  }

  if (flags & _O_TEMPORARY ) {
    attributes |= FILE_FLAG_DELETE_ON_CLOSE | FILE_ATTRIBUTE_TEMPORARY;
    access |= DELETE;
  }

  if (flags & _O_SHORT_LIVED) {
    attributes |= FILE_ATTRIBUTE_TEMPORARY;
  }

  switch (flags & (_O_SEQUENTIAL | _O_RANDOM)) {
  case 0:
    break;
  case _O_SEQUENTIAL:
    attributes |= FILE_FLAG_SEQUENTIAL_SCAN;
    break;
  case _O_RANDOM:
    attributes |= FILE_FLAG_RANDOM_ACCESS;
    break;
  default:
    goto einval;
  }

  /* Setting this flag makes it possible to open a directory. */
  attributes |= FILE_FLAG_BACKUP_SEMANTICS;

  file = CreateFileW(req->pathw,
                     access,
                     share,
                     NULL,
                     disposition,
                     attributes,
                     NULL);
  if (file == INVALID_HANDLE_VALUE) {
    DWORD error = GetLastError();
    if (error == ERROR_FILE_EXISTS && (flags & _O_CREAT) &&
        !(flags & _O_EXCL)) {
      /* Special case: when ERROR_FILE_EXISTS happens and O_CREAT was */
      /* specified, it means the path referred to a directory. */
      SET_REQ_UV_ERROR(req, UV_EISDIR, error);
    } else {
      SET_REQ_WIN32_ERROR(req, GetLastError());
    }
    return;
  }

  fd = _open_osfhandle((intptr_t) file, flags);
  if (fd < 0) {
    /* The only known failure mode for _open_osfhandle() is EMFILE, in which
     * case GetLastError() will return zero. However we'll try to handle other
     * errors as well, should they ever occur.
     */
    if (errno == EMFILE)
      SET_REQ_UV_ERROR(req, UV_EMFILE, ERROR_TOO_MANY_OPEN_FILES);
    else if (GetLastError() != ERROR_SUCCESS)
      SET_REQ_WIN32_ERROR(req, GetLastError());
    else
      SET_REQ_WIN32_ERROR(req, UV_UNKNOWN);
    return;
  }

  SET_REQ_RESULT(req, fd);
  return;

 einval:
  SET_REQ_UV_ERROR(req, UV_EINVAL, ERROR_INVALID_PARAMETER);
}

void fs__close(uv_fs_t* req) {
  int fd = req->fd;
  int result;

  VERIFY_FD(fd, req);

  result = _close(fd);
  SET_REQ_RESULT(req, result);
}


void fs__read(uv_fs_t* req) {
  int fd = req->fd;
  size_t length = req->length;
  int64_t offset = req->offset;
  HANDLE handle;
  OVERLAPPED overlapped, *overlapped_ptr;
  LARGE_INTEGER offset_;
  DWORD bytes;
  DWORD error;

  VERIFY_FD(fd, req);

  handle = uv__get_osfhandle(fd);
  
  if (handle == INVALID_HANDLE_VALUE) {
    SET_REQ_WIN32_ERROR(req, ERROR_INVALID_HANDLE);
    return;
  }

  if (length > INT_MAX) {
    SET_REQ_WIN32_ERROR(req, ERROR_INSUFFICIENT_BUFFER);
    return;
  }

  if (offset != -1) {
    memset(&overlapped, 0, sizeof overlapped);

    offset_.QuadPart = offset;
    overlapped.Offset = offset_.LowPart;
    overlapped.OffsetHigh = offset_.HighPart;

    overlapped_ptr = &overlapped;
  } else {
    overlapped_ptr = NULL;
  }

  if (ReadFile(handle, req->buf, req->length, &bytes, overlapped_ptr)) {
    SET_REQ_RESULT(req, bytes);
  } else {
    error = GetLastError();
    if (error == ERROR_HANDLE_EOF) {
      SET_REQ_RESULT(req, bytes);
    } else {
      SET_REQ_WIN32_ERROR(req, error);
    }
  }
}


void fs__write(uv_fs_t* req) {
  int fd = req->fd;
  size_t length = req->length;
  int64_t offset = req->offset;
  HANDLE handle;
  OVERLAPPED overlapped, *overlapped_ptr;
  LARGE_INTEGER offset_;
  DWORD bytes;

  VERIFY_FD(fd, req);

  handle = uv__get_osfhandle(fd);
  if (handle == INVALID_HANDLE_VALUE) {
    SET_REQ_WIN32_ERROR(req, ERROR_INVALID_HANDLE);
    return;
  }

  if (length > INT_MAX) {
    SET_REQ_WIN32_ERROR(req, ERROR_INSUFFICIENT_BUFFER);
    return;
  }

  if (offset != -1) {
    memset(&overlapped, 0, sizeof overlapped);

    offset_.QuadPart = offset;
    overlapped.Offset = offset_.LowPart;
    overlapped.OffsetHigh = offset_.HighPart;

    overlapped_ptr = &overlapped;
  } else {
    overlapped_ptr = NULL;
  }

  if (WriteFile(handle, req->buf, length, &bytes, overlapped_ptr)) {
    SET_REQ_RESULT(req, bytes);
  } else {
    SET_REQ_WIN32_ERROR(req, GetLastError());
  }
}


void fs__rmdir(uv_fs_t* req) {
  int result = _wrmdir(req->pathw);
  SET_REQ_RESULT(req, result);
}


void fs__unlink(uv_fs_t* req) {
  const WCHAR* pathw = req->pathw;
  HANDLE handle;
  BY_HANDLE_FILE_INFORMATION info;
  FILE_DISPOSITION_INFORMATION disposition;
  IO_STATUS_BLOCK iosb;
  NTSTATUS status;

  handle = CreateFileW(pathw,
                       FILE_READ_ATTRIBUTES | DELETE,
                       FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                       NULL,
                       OPEN_EXISTING,
                       FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS,
                       NULL);

  if (handle == INVALID_HANDLE_VALUE) {
    SET_REQ_WIN32_ERROR(req, GetLastError());
    return;
  }

  if (!GetFileInformationByHandle(handle, &info)) {
    SET_REQ_WIN32_ERROR(req, GetLastError());
    CloseHandle(handle);
    return;
  }

  if (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
    /* Do not allow deletion of directories, unless it is a symlink. When */
    /* the path refers to a non-symlink directory, report EPERM as mandated */
    /* by POSIX.1. */

    /* Check if it is a reparse point. If it's not, it's a normal directory. */
    if (!(info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT)) {
      SET_REQ_WIN32_ERROR(req, ERROR_ACCESS_DENIED);
      CloseHandle(handle);
      return;
    }

    /* Read the reparse point and check if it is a valid symlink. */
    /* If not, don't unlink. */
    if (fs__readlink_handle(handle, NULL, NULL) < 0) {
      DWORD error = GetLastError();
      if (error == ERROR_SYMLINK_NOT_SUPPORTED)
        error = ERROR_ACCESS_DENIED;
      SET_REQ_WIN32_ERROR(req, error);
      CloseHandle(handle);
      return;
    }
  }

  /* Try to set the delete flag. */
  disposition.DeleteFile = TRUE;
  status = pNtSetInformationFile(handle,
                                 &iosb,
                                 &disposition,
                                 sizeof disposition,
                                 FileDispositionInformation);
  if (NT_SUCCESS(status)) {
    SET_REQ_SUCCESS(req);
  } else {
    SET_REQ_WIN32_ERROR(req, pRtlNtStatusToDosError(status));
  }

  CloseHandle(handle);
}


void fs__mkdir(uv_fs_t* req) {
  /* TODO: use req->mode. */
  int result = _wmkdir(req->pathw);
  SET_REQ_RESULT(req, result);
}


void fs__readdir(uv_fs_t* req) {
  WCHAR* pathw = req->pathw;
  size_t len = wcslen(pathw);
  int result, size;
  WCHAR* buf = NULL, *ptr, *name;
  HANDLE dir;
  WIN32_FIND_DATAW ent = { 0 };
  size_t buf_char_len = 4096;
  WCHAR* path2;
  const WCHAR* fmt;

  if (len == 0) {
    fmt = L"./*";
  } else if (pathw[len - 1] == L'/' || pathw[len - 1] == L'\\') {
    fmt = L"%s*";
  } else {
    fmt = L"%s\\*";
  }

  /* Figure out whether path is a file or a directory. */
  if (!(GetFileAttributesW(pathw) & FILE_ATTRIBUTE_DIRECTORY)) {
    req->result = UV_ENOTDIR;
    req->sys_errno_ = ERROR_SUCCESS;
    return;
  }

  path2 = (WCHAR*)malloc(sizeof(WCHAR) * (len + 4));
  if (!path2) {
    uv_fatal_error(ERROR_OUTOFMEMORY, "malloc");
  }

  _snwprintf(path2, len + 3, fmt, pathw);
  dir = FindFirstFileW(path2, &ent);
  free(path2);

  if(dir == INVALID_HANDLE_VALUE) {
    SET_REQ_WIN32_ERROR(req, GetLastError());
    return;
  }

  result = 0;

  do {
    name = ent.cFileName;

    if (name[0] != L'.' || (name[1] && (name[1] != L'.' || name[2]))) {
      len = wcslen(name);

      if (!buf) {
        buf = (WCHAR*)malloc(buf_char_len * sizeof(WCHAR));
        if (!buf) {
          uv_fatal_error(ERROR_OUTOFMEMORY, "malloc");
        }

        ptr = buf;
      }

      while ((ptr - buf) + len + 1 > buf_char_len) {
        buf_char_len *= 2;
        path2 = buf;
        buf = (WCHAR*)realloc(buf, buf_char_len * sizeof(WCHAR));
        if (!buf) {
          uv_fatal_error(ERROR_OUTOFMEMORY, "realloc");
        }

        ptr = buf + (ptr - path2);
      }

      wcscpy(ptr, name);
      ptr += len + 1;
      result++;
    }
  } while(FindNextFileW(dir, &ent));

  FindClose(dir);

  if (buf) {
    /* Convert result to UTF8. */
    size = uv_utf16_to_utf8(buf, buf_char_len, NULL, 0);
    if (!size) {
      SET_REQ_WIN32_ERROR(req, GetLastError());
      return;
    }

    req->ptr = (char*)malloc(size + 1);
    if (!req->ptr) {
      uv_fatal_error(ERROR_OUTOFMEMORY, "malloc");
    }

    size = uv_utf16_to_utf8(buf, buf_char_len, (char*)req->ptr, size);
    if (!size) {
      free(buf);
      free(req->ptr);
      req->ptr = NULL;
      SET_REQ_WIN32_ERROR(req, GetLastError());
      return;
    }
    free(buf);

    ((char*)req->ptr)[size] = '\0';
    req->flags |= UV_FS_FREE_PTR;
  } else {
    req->ptr = NULL;
  }

  SET_REQ_RESULT(req, result);
}


INLINE static int fs__stat_handle(HANDLE handle, uv_stat_t* statbuf) {
  FILE_ALL_INFORMATION file_info;
  FILE_FS_VOLUME_INFORMATION volume_info;
  NTSTATUS nt_status;
  IO_STATUS_BLOCK io_status;

  nt_status = pNtQueryInformationFile(handle,
                                      &io_status,
                                      &file_info,
                                      sizeof file_info,
                                      FileAllInformation);

  /* Buffer overflow (a warning status code) is expected here. */
  if (NT_ERROR(nt_status)) {
    SetLastError(pRtlNtStatusToDosError(nt_status));
    return -1;
  }

  nt_status = pNtQueryVolumeInformationFile(handle,
                                            &io_status,
                                            &volume_info,
                                            sizeof volume_info,
                                            FileFsVolumeInformation);

  /* Buffer overflow (a warning status code) is expected here. */
  if (NT_ERROR(nt_status)) {
    SetLastError(pRtlNtStatusToDosError(nt_status));
    return -1;
  }

  /* Todo: st_mode should probably always be 0666 for everyone. We might also
   * want to report 0777 if the file is a .exe or a directory.
   *
   * Currently it's based on whether the 'readonly' attribute is set, which
   * makes little sense because the semantics are so different: the 'read-only'
   * flag is just a way for a user to protect against accidental deleteion, and
   * serves no security purpose. Windows uses ACLs for that.
   *
   * Also people now use uv_fs_chmod() to take away the writable bit for good
   * reasons. Windows however just makes the file read-only, which makes it
   * impossible to delete the file afterwards, since read-only files can't be
   * deleted.
   *
   * IOW it's all just a clusterfuck and we should think of something that
   * makes slighty more sense.
   *
   * And uv_fs_chmod should probably just fail on windows or be a total no-op.
   * There's nothing sensible it can do anyway.
   */
  statbuf->st_mode = 0;

  if (file_info.BasicInformation.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) {
    statbuf->st_mode |= S_IFLNK;
    if (fs__readlink_handle(handle, NULL, &statbuf->st_size) != 0)
      return -1;

  } else if (file_info.BasicInformation.FileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
    statbuf->st_mode |= _S_IFDIR;
    statbuf->st_size = 0;

  } else {
    statbuf->st_mode |= _S_IFREG;
    statbuf->st_size = file_info.StandardInformation.EndOfFile.QuadPart;
  }

  if (file_info.BasicInformation.FileAttributes & FILE_ATTRIBUTE_READONLY)
    statbuf->st_mode |= _S_IREAD | (_S_IREAD >> 3) | (_S_IREAD >> 6);
  else
    statbuf->st_mode |= (_S_IREAD | _S_IWRITE) | ((_S_IREAD | _S_IWRITE) >> 3) |
                        ((_S_IREAD | _S_IWRITE) >> 6);

  FILETIME_TO_TIMESPEC(statbuf->st_atim, file_info.BasicInformation.LastAccessTime);
  FILETIME_TO_TIMESPEC(statbuf->st_ctim, file_info.BasicInformation.ChangeTime);
  FILETIME_TO_TIMESPEC(statbuf->st_mtim, file_info.BasicInformation.LastWriteTime);
  FILETIME_TO_TIMESPEC(statbuf->st_birthtim, file_info.BasicInformation.CreationTime);

  statbuf->st_ino = file_info.InternalInformation.IndexNumber.QuadPart;

  /* st_blocks contains the on-disk allocation size in 512-byte units. */
  statbuf->st_blocks =
      file_info.StandardInformation.AllocationSize.QuadPart >> 9ULL;

  statbuf->st_nlink = file_info.StandardInformation.NumberOfLinks;

  statbuf->st_dev = volume_info.VolumeSerialNumber;

  /* The st_blksize is supposed to be the 'optimal' number of bytes for reading
   * and writing to the disk. That is, for any definition of 'optimal' - it's
   * supposed to at least avoid read-update-write behavior when writing to the
   * disk.
   *
   * However nobody knows this and even fewer people actually use this value,
   * and in order to fill it out we'd have to make another syscall to query the
   * volume for FILE_FS_SECTOR_SIZE_INFORMATION.
   *
   * Therefore we'll just report a sensible value that's quite commonly okay
   * on modern hardware.
   */
  statbuf->st_blksize = 2048;

  /* Todo: set st_flags to something meaningful. Also provide a wrapper for
   * chattr(2).
   */
  statbuf->st_flags = 0;

  /* Windows has nothing sensible to say about these values, so they'll just
   * remain empty.
   */
  statbuf->st_gid = 0;
  statbuf->st_uid = 0;
  statbuf->st_rdev = 0;
  statbuf->st_gen = 0;

  return 0;
}


INLINE static void fs__stat_prepare_path(WCHAR* pathw) {
  size_t len = wcslen(pathw);

  /* TODO: ignore namespaced paths. */
  if (len > 1 && pathw[len - 2] != L':' &&
      (pathw[len - 1] == L'\\' || pathw[len - 1] == L'/')) {
    pathw[len - 1] = '\0';
  }
}


INLINE static void fs__stat_impl(uv_fs_t* req, int do_lstat) {
  HANDLE handle;
  DWORD flags;

  flags = FILE_FLAG_BACKUP_SEMANTICS;
  if (do_lstat) {
    flags |= FILE_FLAG_OPEN_REPARSE_POINT;
  }

  handle = CreateFileW(req->pathw,
                       FILE_READ_ATTRIBUTES,
                       FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                       NULL,
                       OPEN_EXISTING,
                       flags,
                       NULL);
  if (handle == INVALID_HANDLE_VALUE) {
    SET_REQ_WIN32_ERROR(req, GetLastError());
    return;
  }

  if (fs__stat_handle(handle, &req->statbuf) != 0) {
    DWORD error = GetLastError();
    if (do_lstat && error == ERROR_SYMLINK_NOT_SUPPORTED) {
      /* We opened a reparse point but it was not a symlink. Try again. */
      fs__stat_impl(req, 0);

    } else {
      /* Stat failed. */
      SET_REQ_WIN32_ERROR(req, GetLastError());
    }

    CloseHandle(handle);
    return;
  }

  req->ptr = &req->statbuf;
  req->result = 0;
  CloseHandle(handle);
}


static void fs__stat(uv_fs_t* req) {
  fs__stat_prepare_path(req->pathw);
  fs__stat_impl(req, 0);
}


static void fs__lstat(uv_fs_t* req) {
  fs__stat_prepare_path(req->pathw);
  fs__stat_impl(req, 1);
}


static void fs__fstat(uv_fs_t* req) {
  int fd = req->fd;
  HANDLE handle;

  VERIFY_FD(fd, req);

  handle = uv__get_osfhandle(fd);

  if (handle == INVALID_HANDLE_VALUE) {
    SET_REQ_WIN32_ERROR(req, ERROR_INVALID_HANDLE);
    return;
  }

  if (fs__stat_handle(handle, &req->statbuf) != 0) {
    SET_REQ_WIN32_ERROR(req, GetLastError());
    return;
  }

  req->ptr = &req->statbuf;
  req->result = 0;
}


static void fs__rename(uv_fs_t* req) {
  if (!MoveFileExW(req->pathw, req->new_pathw, MOVEFILE_REPLACE_EXISTING)) {
    SET_REQ_WIN32_ERROR(req, GetLastError());
    return;
  }

  SET_REQ_RESULT(req, 0);
}


INLINE static void fs__sync_impl(uv_fs_t* req) {
  int fd = req->fd;
  int result;

  VERIFY_FD(fd, req);

  result = FlushFileBuffers(uv__get_osfhandle(fd)) ? 0 : -1;
  if (result == -1) {
    SET_REQ_WIN32_ERROR(req, GetLastError());
  } else {
    SET_REQ_RESULT(req, result);
  }
}


static void fs__fsync(uv_fs_t* req) {
  fs__sync_impl(req);
}


static void fs__fdatasync(uv_fs_t* req) {
  fs__sync_impl(req);
}


static void fs__ftruncate(uv_fs_t* req) {
  int fd = req->fd;
  HANDLE handle;
  NTSTATUS status;
  IO_STATUS_BLOCK io_status;
  FILE_END_OF_FILE_INFORMATION eof_info;

  VERIFY_FD(fd, req);

  handle = uv__get_osfhandle(fd);

  eof_info.EndOfFile.QuadPart = req->offset;

  status = pNtSetInformationFile(handle,
                                 &io_status,
                                 &eof_info,
                                 sizeof eof_info,
                                 FileEndOfFileInformation);

  if (NT_SUCCESS(status)) {
    SET_REQ_RESULT(req, 0);
  } else {
    SET_REQ_WIN32_ERROR(req, pRtlNtStatusToDosError(status));
  }
}


static void fs__sendfile(uv_fs_t* req) {
  int fd_in = req->fd, fd_out = req->fd_out;
  size_t length = req->length;
  int64_t offset = req->offset;
  const size_t max_buf_size = 65536;
  size_t buf_size = length < max_buf_size ? length : max_buf_size;
  int n, result = 0;
  int64_t result_offset = 0;
  char* buf = (char*) malloc(buf_size);
  if (!buf) {
    uv_fatal_error(ERROR_OUTOFMEMORY, "malloc");
  }

  if (offset != -1) {
    result_offset = _lseeki64(fd_in, offset, SEEK_SET);
  }

  if (result_offset == -1) {
    result = -1;
  } else {
    while (length > 0) {
      n = _read(fd_in, buf, length < buf_size ? length : buf_size);
      if (n == 0) {
        break;
      } else if (n == -1) {
        result = -1;
        break;
      }

      length -= n;

      n = _write(fd_out, buf, n);
      if (n == -1) {
        result = -1;
        break;
      }

      result += n;
    }
  }

  free(buf);

  SET_REQ_RESULT(req, result);
}


static void fs__chmod(uv_fs_t* req) {
  int result = _wchmod(req->pathw, req->mode);
  SET_REQ_RESULT(req, result);
}


static void fs__fchmod(uv_fs_t* req) {
  int fd = req->fd;
  HANDLE handle;
  NTSTATUS nt_status;
  IO_STATUS_BLOCK io_status;
  FILE_BASIC_INFORMATION file_info;

  VERIFY_FD(fd, req);

  handle = uv__get_osfhandle(fd);

  nt_status = pNtQueryInformationFile(handle,
                                      &io_status,
                                      &file_info,
                                      sizeof file_info,
                                      FileBasicInformation);

  if (!NT_SUCCESS(nt_status)) {
    SET_REQ_WIN32_ERROR(req, pRtlNtStatusToDosError(nt_status));
    return;
  }

  if (req->mode & _S_IWRITE) {
    file_info.FileAttributes &= ~FILE_ATTRIBUTE_READONLY;
  } else {
    file_info.FileAttributes |= FILE_ATTRIBUTE_READONLY;
  }

  nt_status = pNtSetInformationFile(handle,
                                    &io_status,
                                    &file_info,
                                    sizeof file_info,
                                    FileBasicInformation);

  if (!NT_SUCCESS(nt_status)) {
    SET_REQ_WIN32_ERROR(req, pRtlNtStatusToDosError(nt_status));
    return;
  }

  SET_REQ_SUCCESS(req);
}


INLINE static int fs__utime_handle(HANDLE handle, double atime, double mtime) {
  FILETIME filetime_a, filetime_m;

  TIME_T_TO_FILETIME((time_t) atime, &filetime_a);
  TIME_T_TO_FILETIME((time_t) mtime, &filetime_m);

  if (!SetFileTime(handle, NULL, &filetime_a, &filetime_m)) {
    return -1;
  }

  return 0;
}


static void fs__utime(uv_fs_t* req) {
  HANDLE handle;

  handle = CreateFileW(req->pathw,
                       FILE_WRITE_ATTRIBUTES,
                       FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                       NULL,
                       OPEN_EXISTING,
                       FILE_FLAG_BACKUP_SEMANTICS,
                       NULL);

  if (handle == INVALID_HANDLE_VALUE) {
    SET_REQ_WIN32_ERROR(req, GetLastError());
    return;
  }

  if (fs__utime_handle(handle, req->atime, req->mtime) != 0) {
    SET_REQ_WIN32_ERROR(req, GetLastError());
    CloseHandle(handle);
    return;
  }

  CloseHandle(handle);

  req->result = 0;
}


static void fs__futime(uv_fs_t* req) {
  int fd = req->fd;
  HANDLE handle;
  VERIFY_FD(fd, req);

  handle = uv__get_osfhandle(fd);

  if (handle == INVALID_HANDLE_VALUE) {
    SET_REQ_WIN32_ERROR(req, ERROR_INVALID_HANDLE);
    return;
  }

  if (fs__utime_handle(handle, req->atime, req->mtime) != 0) {
    SET_REQ_WIN32_ERROR(req, GetLastError());
    return;
  }

  req->result = 0;
}


static void fs__link(uv_fs_t* req) {
  DWORD r = CreateHardLinkW(req->new_pathw, req->pathw, NULL);
  if (r == 0) {
    SET_REQ_WIN32_ERROR(req, GetLastError());
  } else {
    req->result = 0;
  }
}


static void fs__create_junction(uv_fs_t* req, const WCHAR* path,
    const WCHAR* new_path) {
  HANDLE handle = INVALID_HANDLE_VALUE;
  REPARSE_DATA_BUFFER *buffer = NULL;
  int created = 0;
  int target_len;
  int is_absolute, is_long_path;
  int needed_buf_size, used_buf_size, used_data_size, path_buf_len;
  int start, len, i;
  int add_slash;
  DWORD bytes;
  WCHAR* path_buf;

  target_len = wcslen(path);
  is_long_path = wcsncmp(path, LONG_PATH_PREFIX, LONG_PATH_PREFIX_LEN) == 0;

  if (is_long_path) {
    is_absolute = 1;
  } else {
    is_absolute = target_len >= 3 && IS_LETTER(path[0]) &&
      path[1] == L':' && IS_SLASH(path[2]);
  }

  if (!is_absolute) {
    /* Not supporting relative paths */
    SET_REQ_UV_ERROR(req, UV_EINVAL, ERROR_NOT_SUPPORTED);
    return;
  }

  // Do a pessimistic calculation of the required buffer size
  needed_buf_size =
      FIELD_OFFSET(REPARSE_DATA_BUFFER, MountPointReparseBuffer.PathBuffer) +
      JUNCTION_PREFIX_LEN * sizeof(WCHAR) +
      2 * (target_len + 2) * sizeof(WCHAR);

  // Allocate the buffer
  buffer = (REPARSE_DATA_BUFFER*)malloc(needed_buf_size);
  if (!buffer) {
    uv_fatal_error(ERROR_OUTOFMEMORY, "malloc");
  }

  // Grab a pointer to the part of the buffer where filenames go
  path_buf = (WCHAR*)&(buffer->MountPointReparseBuffer.PathBuffer);
  path_buf_len = 0;

  // Copy the substitute (internal) target path
  start = path_buf_len;

  wcsncpy((WCHAR*)&path_buf[path_buf_len], JUNCTION_PREFIX,
    JUNCTION_PREFIX_LEN);
  path_buf_len += JUNCTION_PREFIX_LEN;

  add_slash = 0;
  for (i = is_long_path ? LONG_PATH_PREFIX_LEN : 0; path[i] != L'\0'; i++) {
    if (IS_SLASH(path[i])) {
      add_slash = 1;
      continue;
    }

    if (add_slash) {
      path_buf[path_buf_len++] = L'\\';
      add_slash = 0;
    }

    path_buf[path_buf_len++] = path[i];
  }
  path_buf[path_buf_len++] = L'\\';
  len = path_buf_len - start;

  // Set the info about the substitute name
  buffer->MountPointReparseBuffer.SubstituteNameOffset = start * sizeof(WCHAR);
  buffer->MountPointReparseBuffer.SubstituteNameLength = len * sizeof(WCHAR);

  // Insert null terminator
  path_buf[path_buf_len++] = L'\0';

  // Copy the print name of the target path
  start = path_buf_len;
  add_slash = 0;
  for (i = is_long_path ? LONG_PATH_PREFIX_LEN : 0; path[i] != L'\0'; i++) {
    if (IS_SLASH(path[i])) {
      add_slash = 1;
      continue;
    }

    if (add_slash) {
      path_buf[path_buf_len++] = L'\\';
      add_slash = 0;
    }

    path_buf[path_buf_len++] = path[i];
  }
  len = path_buf_len - start;
  if (len == 2) {
    path_buf[path_buf_len++] = L'\\';
    len++;
  }

  // Set the info about the print name
  buffer->MountPointReparseBuffer.PrintNameOffset = start * sizeof(WCHAR);
  buffer->MountPointReparseBuffer.PrintNameLength = len * sizeof(WCHAR);

  // Insert another null terminator
  path_buf[path_buf_len++] = L'\0';

  // Calculate how much buffer space was actually used
  used_buf_size = FIELD_OFFSET(REPARSE_DATA_BUFFER, MountPointReparseBuffer.PathBuffer) +
    path_buf_len * sizeof(WCHAR);
  used_data_size = used_buf_size -
    FIELD_OFFSET(REPARSE_DATA_BUFFER, MountPointReparseBuffer);

  // Put general info in the data buffer
  buffer->ReparseTag = IO_REPARSE_TAG_MOUNT_POINT;
  buffer->ReparseDataLength = used_data_size;
  buffer->Reserved = 0;

  // Create a new directory
  if (!CreateDirectoryW(new_path, NULL)) {
    SET_REQ_WIN32_ERROR(req, GetLastError());
    goto error;
  }
  created = 1;

  // Open the directory
  handle = CreateFileW(new_path,
                       GENERIC_ALL,
                       0,
                       NULL,
                       OPEN_EXISTING,
                       FILE_FLAG_BACKUP_SEMANTICS |
                         FILE_FLAG_OPEN_REPARSE_POINT,
                       NULL);
  if (handle == INVALID_HANDLE_VALUE) {
    SET_REQ_WIN32_ERROR(req, GetLastError());
    goto error;
  }

  // Create the actual reparse point
  if (!DeviceIoControl(handle,
                       FSCTL_SET_REPARSE_POINT,
                       buffer,
                       used_buf_size,
                       NULL,
                       0,
                       &bytes,
                       NULL)) {
    SET_REQ_WIN32_ERROR(req, GetLastError());
    goto error;
  }

  // Clean up
  CloseHandle(handle);
  free(buffer);

  SET_REQ_RESULT(req, 0);
  return;

error:
  free(buffer);

  if (handle != INVALID_HANDLE_VALUE) {
    CloseHandle(handle);
  }

  if (created) {
    RemoveDirectoryW(new_path);
  }
}


static void fs__symlink(uv_fs_t* req) {
  WCHAR* pathw = req->pathw;
  WCHAR* new_pathw = req->new_pathw;
  int flags = req->file_flags;
  int result;


  if (flags & UV_FS_SYMLINK_JUNCTION) {
    fs__create_junction(req, pathw, new_pathw);
  } else if (pCreateSymbolicLinkW) {
    result = pCreateSymbolicLinkW(new_pathw,
                                  pathw,
                                  flags & UV_FS_SYMLINK_DIR ? SYMBOLIC_LINK_FLAG_DIRECTORY : 0) ? 0 : -1;
    if (result == -1) {
      SET_REQ_WIN32_ERROR(req, GetLastError());
    } else {
      SET_REQ_RESULT(req, result);
    }
  } else {
    SET_REQ_UV_ERROR(req, UV_ENOSYS, ERROR_NOT_SUPPORTED);
  }
}


static void fs__readlink(uv_fs_t* req) {
  HANDLE handle;

  handle = CreateFileW(req->pathw,
                       0,
                       0,
                       NULL,
                       OPEN_EXISTING,
                       FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS,
                       NULL);

  if (handle == INVALID_HANDLE_VALUE) {
    SET_REQ_WIN32_ERROR(req, GetLastError());
    return;
  }

  if (fs__readlink_handle(handle, (char**) &req->ptr, NULL) != 0) {
    SET_REQ_WIN32_ERROR(req, GetLastError());
    CloseHandle(handle);
    return;
  }

  req->flags |= UV_FS_FREE_PTR;
  SET_REQ_RESULT(req, 0);

  CloseHandle(handle);
}



static void fs__chown(uv_fs_t* req) {
  req->result = 0;
}


static void fs__fchown(uv_fs_t* req) {
  req->result = 0;
}


static DWORD WINAPI uv_fs_thread_proc(void* parameter) {
  uv_fs_t* req = (uv_fs_t*) parameter;
  uv_loop_t* loop = req->loop;

  assert(req != NULL);
  assert(req->type == UV_FS);

#define XX(uc, lc)  case UV_FS_##uc: fs__##lc(req); break;
  switch (req->fs_type) {
    XX(OPEN, open)
    XX(CLOSE, close)
    XX(READ, read)
    XX(WRITE, write)
    XX(SENDFILE, sendfile)
    XX(STAT, stat)
    XX(LSTAT, lstat)
    XX(FSTAT, fstat)
    XX(FTRUNCATE, ftruncate)
    XX(UTIME, utime)
    XX(FUTIME, futime)
    XX(CHMOD, chmod)
    XX(FCHMOD, fchmod)
    XX(FSYNC, fsync)
    XX(FDATASYNC, fdatasync)
    XX(UNLINK, unlink)
    XX(RMDIR, rmdir)
    XX(MKDIR, mkdir)
    XX(RENAME, rename)
    XX(READDIR, readdir)
    XX(LINK, link)
    XX(SYMLINK, symlink)
    XX(READLINK, readlink)
    XX(CHOWN, chown)
    XX(FCHOWN, fchown);
    default:
      assert(!"bad uv_fs_type");
  }

  POST_COMPLETION_FOR_REQ(loop, req);
  return 0;
}


int uv_fs_open(uv_loop_t* loop, uv_fs_t* req, const char* path, int flags,
    int mode, uv_fs_cb cb) {
  int err;

  uv_fs_req_init(loop, req, UV_FS_OPEN, cb);

  err = fs__capture_path(loop, req, path, NULL, cb != NULL);
  if (err) {
    return uv_translate_sys_error(err);
  }

  req->file_flags = flags;
  req->mode = mode;

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__open(req);
    return req->result;
  }
}


int uv_fs_close(uv_loop_t* loop, uv_fs_t* req, uv_file fd, uv_fs_cb cb) {
  uv_fs_req_init(loop, req, UV_FS_CLOSE, cb);
  req->fd = fd;

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__close(req);
    return req->result;
  }
}


int uv_fs_read(uv_loop_t* loop, uv_fs_t* req, uv_file fd, void* buf,
    size_t length, int64_t offset, uv_fs_cb cb) {
  uv_fs_req_init(loop, req, UV_FS_READ, cb);

  req->fd = fd;
  req->buf = buf;
  req->length = length;
  req->offset = offset;

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__read(req);
    return req->result;
  }
}


int uv_fs_write(uv_loop_t* loop, uv_fs_t* req, uv_file fd, const void* buf,
    size_t length, int64_t offset, uv_fs_cb cb) {
  uv_fs_req_init(loop, req, UV_FS_WRITE, cb);

  req->fd = fd;
  req->buf = (void*) buf;
  req->length = length;
  req->offset = offset;

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__write(req);
    return req->result;
  }
}


int uv_fs_unlink(uv_loop_t* loop, uv_fs_t* req, const char* path,
    uv_fs_cb cb) {
  int err;

  uv_fs_req_init(loop, req, UV_FS_UNLINK, cb);

  err = fs__capture_path(loop, req, path, NULL, cb != NULL);
  if (err) {
    return uv_translate_sys_error(err);
  }

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__unlink(req);
    return req->result;
  }
}


int uv_fs_mkdir(uv_loop_t* loop, uv_fs_t* req, const char* path, int mode,
    uv_fs_cb cb) {
  int err;

  uv_fs_req_init(loop, req, UV_FS_MKDIR, cb);

  err = fs__capture_path(loop, req, path, NULL, cb != NULL);
  if (err) {
    return uv_translate_sys_error(err);
  }

  req->mode = mode;

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__mkdir(req);
    return req->result;
  }
}


int uv_fs_rmdir(uv_loop_t* loop, uv_fs_t* req, const char* path, uv_fs_cb cb) {
  int err;

  uv_fs_req_init(loop, req, UV_FS_RMDIR, cb);

  err = fs__capture_path(loop, req, path, NULL, cb != NULL);
  if (err) {
    return uv_translate_sys_error(err);
  }

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__rmdir(req);
    return req->result;
  }
}


int uv_fs_readdir(uv_loop_t* loop, uv_fs_t* req, const char* path, int flags,
    uv_fs_cb cb) {
  int err;

  uv_fs_req_init(loop, req, UV_FS_READDIR, cb);

  err = fs__capture_path(loop, req, path, NULL, cb != NULL);
  if (err) {
    return uv_translate_sys_error(err);
  }

  req->file_flags = flags;

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__readdir(req);
    return req->result;
  }
}


int uv_fs_link(uv_loop_t* loop, uv_fs_t* req, const char* path,
    const char* new_path, uv_fs_cb cb) {
  int err;

  uv_fs_req_init(loop, req, UV_FS_LINK, cb);

  err = fs__capture_path(loop, req, path, new_path, cb != NULL);
  if (err) {
    return uv_translate_sys_error(err);
  }

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__link(req);
    return req->result;
  }
}


int uv_fs_symlink(uv_loop_t* loop, uv_fs_t* req, const char* path,
    const char* new_path, int flags, uv_fs_cb cb) {
  int err;

  uv_fs_req_init(loop, req, UV_FS_SYMLINK, cb);

  err = fs__capture_path(loop, req, path, new_path, cb != NULL);
  if (err) {
    return uv_translate_sys_error(err);
  }

  req->file_flags = flags;

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__symlink(req);
    return req->result;
  }
}


int uv_fs_readlink(uv_loop_t* loop, uv_fs_t* req, const char* path,
    uv_fs_cb cb) {
  int err;

  uv_fs_req_init(loop, req, UV_FS_READLINK, cb);

  err = fs__capture_path(loop, req, path, NULL, cb != NULL);
  if (err) {
    return uv_translate_sys_error(err);
  }

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__readlink(req);
    return req->result;
  }
}


int uv_fs_chown(uv_loop_t* loop, uv_fs_t* req, const char* path, uv_uid_t uid,
    uv_gid_t gid, uv_fs_cb cb) {
  int err;

  uv_fs_req_init(loop, req, UV_FS_CHOWN, cb);

  err = fs__capture_path(loop, req, path, NULL, cb != NULL);
  if (err) {
    return uv_translate_sys_error(err);
  }

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__chown(req);
    return req->result;
  }
}


int uv_fs_fchown(uv_loop_t* loop, uv_fs_t* req, uv_file fd, uv_uid_t uid,
    uv_gid_t gid, uv_fs_cb cb) {
  uv_fs_req_init(loop, req, UV_FS_FCHOWN, cb);

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__fchown(req);
    return req->result;
  }
}


int uv_fs_stat(uv_loop_t* loop, uv_fs_t* req, const char* path, uv_fs_cb cb) {
  int err;

  uv_fs_req_init(loop, req, UV_FS_STAT, cb);

  err = fs__capture_path(loop, req, path, NULL, cb != NULL);
  if (err) {
    return uv_translate_sys_error(err);
  }

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__stat(req);
    return req->result;
  }
}


int uv_fs_lstat(uv_loop_t* loop, uv_fs_t* req, const char* path, uv_fs_cb cb) {
  int err;

  uv_fs_req_init(loop, req, UV_FS_LSTAT, cb);

  err = fs__capture_path(loop, req, path, NULL, cb != NULL);
  if (err) {
    return uv_translate_sys_error(err);
  }

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__lstat(req);
    return req->result;
  }
}


int uv_fs_fstat(uv_loop_t* loop, uv_fs_t* req, uv_file fd, uv_fs_cb cb) {
  uv_fs_req_init(loop, req, UV_FS_FSTAT, cb);
  req->fd = fd;

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__fstat(req);
    return req->result;
  }
}


int uv_fs_rename(uv_loop_t* loop, uv_fs_t* req, const char* path,
    const char* new_path, uv_fs_cb cb) {
  int err;

  uv_fs_req_init(loop, req, UV_FS_RENAME, cb);

  err = fs__capture_path(loop, req, path, new_path, cb != NULL);
  if (err) {
    return uv_translate_sys_error(err);
  }

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__rename(req);
    return req->result;
  }
}


int uv_fs_fsync(uv_loop_t* loop, uv_fs_t* req, uv_file fd, uv_fs_cb cb) {
  uv_fs_req_init(loop, req, UV_FS_FSYNC, cb);
  req->fd = fd;

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__fsync(req);
    return req->result;
  }
}


int uv_fs_fdatasync(uv_loop_t* loop, uv_fs_t* req, uv_file fd, uv_fs_cb cb) {
  uv_fs_req_init(loop, req, UV_FS_FDATASYNC, cb);
  req->fd = fd;

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__fdatasync(req);
    return req->result;
  }
}


int uv_fs_ftruncate(uv_loop_t* loop, uv_fs_t* req, uv_file fd,
    int64_t offset, uv_fs_cb cb) {
  uv_fs_req_init(loop, req, UV_FS_FTRUNCATE, cb);

  req->fd = fd;
  req->offset = offset;

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__ftruncate(req);
    return req->result;
  }
}



int uv_fs_sendfile(uv_loop_t* loop, uv_fs_t* req, uv_file fd_out,
    uv_file fd_in, int64_t in_offset, size_t length, uv_fs_cb cb) {
  uv_fs_req_init(loop, req, UV_FS_SENDFILE, cb);

  req->fd = fd_in;
  req->fd_out = fd_out;
  req->offset = in_offset;
  req->length = length;

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__sendfile(req);
    return req->result;
  }
}


int uv_fs_chmod(uv_loop_t* loop, uv_fs_t* req, const char* path, int mode,
    uv_fs_cb cb) {
  int err;

  uv_fs_req_init(loop, req, UV_FS_CHMOD, cb);

  err = fs__capture_path(loop, req, path, NULL, cb != NULL);
  if (err) {
    return uv_translate_sys_error(err);
  }

  req->mode = mode;

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__chmod(req);
    return req->result;
  }
}


int uv_fs_fchmod(uv_loop_t* loop, uv_fs_t* req, uv_file fd, int mode,
    uv_fs_cb cb) {
  uv_fs_req_init(loop, req, UV_FS_FCHMOD, cb);

  req->fd = fd;
  req->mode = mode;

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__fchmod(req);
    return req->result;
  }
}


int uv_fs_utime(uv_loop_t* loop, uv_fs_t* req, const char* path, double atime,
    double mtime, uv_fs_cb cb) {
  int err;

  uv_fs_req_init(loop, req, UV_FS_UTIME, cb);

  err = fs__capture_path(loop, req, path, NULL, cb != NULL);
  if (err) {
    return uv_translate_sys_error(err);
  }

  req->atime = atime;
  req->mtime = mtime;

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__utime(req);
    return req->result;
  }
}


int uv_fs_futime(uv_loop_t* loop, uv_fs_t* req, uv_file fd, double atime,
    double mtime, uv_fs_cb cb) {
  uv_fs_req_init(loop, req, UV_FS_FUTIME, cb);

  req->fd = fd;
  req->atime = atime;
  req->mtime = mtime;

  if (cb) {
    QUEUE_FS_TP_JOB(loop, req);
    return 0;
  } else {
    fs__futime(req);
    return req->result;
  }
}


void uv_process_fs_req(uv_loop_t* loop, uv_fs_t* req) {
  assert(req->cb);
  uv__req_unregister(loop, req);
  req->cb(req);
}


void uv_fs_req_cleanup(uv_fs_t* req) {
  if (req->flags & UV_FS_CLEANEDUP)
    return;

  if (req->flags & UV_FS_FREE_PATHS)
    free(req->pathw);

  if (req->flags & UV_FS_FREE_PTR)
    free(req->ptr);

  req->path = NULL;
  req->pathw = NULL;
  req->new_pathw = NULL;
  req->ptr = NULL;

  req->flags |= UV_FS_CLEANEDUP;
}

