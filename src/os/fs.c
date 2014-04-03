// fs.c -- filesystem access

#include "os/os.h"
#include "memory.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"
#include "path.h"

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

