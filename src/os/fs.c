// fs.c -- filesystem access

#include "os/os.h"
#include "memory.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"
#include "path.h"

static bool is_executable(const char_u *name);
static bool is_executable_in_path(const char_u *name);

// Many fs functions from libuv return that value on success.
static const int kLibuvSuccess = 0;

int os_chdir(const char *path) {
  if (p_verbose >= 5) {
    verbose_enter();
    smsg((char_u *)"chdir(%s)", path);
    verbose_leave();
  }
  return uv_chdir(path);
}

int os_dirname(char_u *buf, size_t len)
{
  assert(buf && len);

  int errno;
  if ((errno = uv_cwd((char *)buf, &len)) != kLibuvSuccess) {
    vim_strncpy(buf, (char_u *)uv_strerror(errno), len - 1);
    return FAIL;
  }
  return OK;
}

bool os_isdir(const char_u *name)
{
  int32_t mode = os_getperm(name);
  if (mode < 0) {
    return false;
  }

  if (!S_ISDIR(mode)) {
    return false;
  }

  return true;
}

bool os_can_exe(const char_u *name)
{
  // If it's an absolute or relative path don't need to use $PATH.
  if (path_is_absolute_path(name) ||
     (name[0] == '.' && (name[1] == '/' ||
                        (name[1] == '.' && name[2] == '/')))) {
    return is_executable(name);
  }

  return is_executable_in_path(name);
}

// Return true if "name" is an executable file, false if not or it doesn't
// exist.
static bool is_executable(const char_u *name)
{
  int32_t mode = os_getperm(name);

  if (mode < 0) {
    return false;
  }

  if (S_ISREG(mode) && (S_IEXEC & mode)) {
    return true;
  }

  return false;
}

/// Check if a file is inside the $PATH and is executable.
///
/// @return `true` if `name` is an executable inside $PATH.
static bool is_executable_in_path(const char_u *name)
{
  const char *path = getenv("PATH");
  // PATH environment variable does not exist or is empty.
  if (path == NULL || *path == '\0') {
    return false;
  }

  int buf_len = STRLEN(name) + STRLEN(path) + 2;
  char_u *buf = alloc((unsigned)(buf_len));

  // Walk through all entries in $PATH to check if "name" exists there and
  // is an executable file.
  for (;; ) {
    const char *e = strchr(path, ':');
    if (e == NULL) {
      e = path + STRLEN(path);
    }

    // Glue together the given directory from $PATH with name and save into
    // buf.
    vim_strncpy(buf, (char_u *) path, e - path);
    append_path((char *) buf, (const char *) name, buf_len);

    if (is_executable(buf)) {
      // Found our executable. Free buf and return.
      vim_free(buf);
      return true;
    }

    if (*e != ':') {
      // End of $PATH without finding any executable called name.
      vim_free(buf);
      return false;
    }

    path = e + 1;
  }

  // We should never get to this point.
  assert(false);
  return false;
}

int os_stat(const char_u *name, uv_stat_t *statbuf)
{
  uv_fs_t request;
  int result = uv_fs_stat(uv_default_loop(), &request,
                          (const char *)name, NULL);
  *statbuf = request.statbuf;
  uv_fs_req_cleanup(&request);

  if (result == kLibuvSuccess) {
    return OK;
  }

  return FAIL;
}

int32_t os_getperm(const char_u *name)
{
  uv_stat_t statbuf;
  if (os_stat(name, &statbuf) == FAIL) {
    return -1;
  } else {
    return (int32_t)statbuf.st_mode;
  }
}

int os_setperm(const char_u *name, int perm)
{
  uv_fs_t request;
  int result = uv_fs_chmod(uv_default_loop(), &request,
                           (const char*)name, perm, NULL);
  uv_fs_req_cleanup(&request);

  if (result == kLibuvSuccess) {
    return OK;
  }

  return FAIL;
}

bool os_file_exists(const char_u *name)
{
  uv_stat_t statbuf;
  if (os_stat(name, &statbuf) == OK) {
    return true;
  }

  return false;
}

bool os_file_is_readonly(const char *name)
{
  return access(name, W_OK) != 0;
}

int os_file_is_writable(const char *name)
{
  if (access(name, W_OK) == 0) {
    if (os_isdir((char_u *)name)) {
      return 2;
    }
    return 1;
  }
  return 0;
}

int os_rename(const char_u *path, const char_u *new_path)
{
  uv_fs_t request;
  int result = uv_fs_rename(uv_default_loop(), &request,
                            (const char *)path, (const char *)new_path, NULL);
  uv_fs_req_cleanup(&request);

  if (result == kLibuvSuccess) {
    return OK;
  }

  return FAIL;
}

int os_mkdir(const char *path, int32_t mode)
{
  uv_fs_t request;
  int result = uv_fs_mkdir(uv_default_loop(), &request, path, mode, NULL);
  uv_fs_req_cleanup(&request);
  return result;
}

int os_rmdir(const char *path)
{
  uv_fs_t request;
  int result = uv_fs_rmdir(uv_default_loop(), &request, path, NULL);
  uv_fs_req_cleanup(&request);
  return result;
}

int os_remove(const char *path)
{
  uv_fs_t request;
  int result = uv_fs_unlink(uv_default_loop(), &request, path, NULL);
  uv_fs_req_cleanup(&request);
  return result;
}

