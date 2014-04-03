// fs.c -- filesystem access

#include "os/os.h"
#include "memory.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"

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

/// Get the absolute name of the given relative directory.
///
/// @param directory Directory name, relative to current directory.
/// @return `FAIL` for failure, `OK` for success.
int os_full_dir_name(char *directory, char *buffer, int len)
{
  int retval = OK;

  if (STRLEN(directory) == 0) {
    return os_dirname((char_u *) buffer, len);
  }

  char old_dir[MAXPATHL];

  // Get current directory name.
  if (os_dirname((char_u *) old_dir, MAXPATHL) == FAIL) {
    return FAIL;
  }

  // We have to get back to the current dir at the end, check if that works.
  if (os_chdir(old_dir) != kLibuvSuccess) {
    return FAIL;
  }

  if (os_chdir(directory) != kLibuvSuccess) {
    // Do not return immediatly since we may be in the wrong directory.
    retval = FAIL;
  }

  if (retval == FAIL || os_dirname((char_u *) buffer, len) == FAIL) {
    // Do not return immediatly since we are in the wrong directory.
    retval = FAIL;
  }

  if (os_chdir(old_dir) != kLibuvSuccess) {
    // That shouldn't happen, since we've tested if it works.
    retval = FAIL;
    EMSG(_(e_prev_dir));
  }

  return retval;
}

// Append to_append to path with a slash in between.
int append_path(char *path, const char *to_append, int max_len)
{
  int current_length = STRLEN(path);
  int to_append_length = STRLEN(to_append);

  // Do not append empty strings.
  if (to_append_length == 0) {
    return OK;
  }

  // Do not append a dot.
  if (STRCMP(to_append, ".") == 0) {
    return OK;
  }

  // Glue both paths with a slash.
  if (current_length > 0 && path[current_length-1] != '/') {
    current_length += 1;  // Count the trailing slash.

    // +1 for the NUL at the end.
    if (current_length + 1 > max_len) {
      return FAIL;
    }

    STRCAT(path, "/");
  }

  // +1 for the NUL at the end.
  if (current_length + to_append_length + 1 > max_len) {
    return FAIL;
  }

  STRCAT(path, to_append);
  return OK;
}

int os_get_absolute_path(char_u *fname, char_u *buf, int len, int force)
{
  char_u *p;
  *buf = NUL;

  char relative_directory[len];
  char *end_of_path = (char *) fname;

  // expand it if forced or not an absolute path
  if (force || !os_is_absolute_path(fname)) {
    if ((p = vim_strrchr(fname, '/')) != NULL) {
      STRNCPY(relative_directory, fname, p-fname);
      relative_directory[p-fname] = NUL;
      end_of_path = (char *) (p + 1);
    } else {
      relative_directory[0] = NUL;
      end_of_path = (char *) fname;
    }

    if (FAIL == os_full_dir_name(relative_directory, (char *) buf, len)) {
      return FAIL;
    }
  }
  return append_path((char *) buf, (char *) end_of_path, len);
}

int os_is_absolute_path(const char_u *fname)
{
  return *fname == '/' || *fname == '~';
}

int os_isdir(const char_u *name)
{
  int32_t mode = os_getperm(name);
  if (mode < 0) {
    return FALSE;
  }

  if (!S_ISDIR(mode)) {
    return FALSE;
  }

  return TRUE;
}

static int is_executable(const char_u *name);
static int is_executable_in_path(const char_u *name);

int os_can_exe(const char_u *name)
{
  // If it's an absolute or relative path don't need to use $PATH.
  if (os_is_absolute_path(name) ||
     (name[0] == '.' && (name[1] == '/' ||
                        (name[1] == '.' && name[2] == '/')))) {
    return is_executable(name);
  }

  return is_executable_in_path(name);
}

// Return TRUE if "name" is an executable file, FALSE if not or it doesn't
// exist.
static int is_executable(const char_u *name)
{
  int32_t mode = os_getperm(name);

  if (mode < 0) {
    return FALSE;
  }

  if (S_ISREG(mode) && (S_IEXEC & mode)) {
    return TRUE;
  }

  return FALSE;
}

/// Check if a file is inside the $PATH and is executable.
///
/// @return `TRUE` if `name` is an executable inside $PATH.
static int is_executable_in_path(const char_u *name)
{
  const char *path = getenv("PATH");
  // PATH environment variable does not exist or is empty.
  if (path == NULL || *path == NUL) {
    return FALSE;
  }

  int buf_len = STRLEN(name) + STRLEN(path) + 2;
  char_u *buf = alloc((unsigned)(buf_len));
  if (buf == NULL) {
    return FALSE;
  }

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
      return OK;
    }

    if (*e != ':') {
      // End of $PATH without finding any executable called name.
      vim_free(buf);
      return FALSE;
    }

    path = e + 1;
  }

  // We should never get to this point.
  assert(false);
  return FALSE;
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

int os_file_exists(const char_u *name)
{
  uv_stat_t statbuf;
  if (os_stat(name, &statbuf) == OK) {
    return TRUE;
  }

  return FALSE;
}

int os_file_is_readonly(const char *name)
{
  if (access(name, W_OK) == 0) {
    return FALSE;
  }

  return TRUE;
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

