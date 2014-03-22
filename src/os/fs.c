/* vi:set ts=2 sts=2 sw=2:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * fs.c -- filesystem access
 */

#include <uv.h>

#include "os/os.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"

int mch_chdir(char *path) {
  if (p_verbose >= 5) {
    verbose_enter();
    smsg((char_u *)"chdir(%s)", path);
    verbose_leave();
  }
  return uv_chdir(path);
}

/*
 * Get name of current directory into buffer 'buf' of length 'len' bytes.
 * Return OK for success, FAIL for failure.
 */
int mch_dirname(char_u *buf, size_t len)
{
  assert(buf && len);

  int errno;
  if ((errno = uv_cwd((char *)buf, &len)) != 0) {
    vim_strncpy(buf, (char_u *)uv_strerror(errno), len - 1);
    return FAIL;
  }
  return OK;
}

/*
 * Get the absolute name of the given relative directory.
 *
 * parameter directory: Directory name, relative to current directory.
 * return FAIL for failure, OK for success
 */
int mch_full_dir_name(char *directory, char *buffer, int len)
{
  int retval = OK;

  if(STRLEN(directory) == 0) {
    return mch_dirname((char_u *) buffer, len);
  }

  char old_dir[MAXPATHL];

  /* Get current directory name. */
  if (mch_dirname((char_u *) old_dir, MAXPATHL) == FAIL) {
    return FAIL;
  }

  /* We have to get back to the current dir at the end, check if that works. */
  if (mch_chdir(old_dir) != 0) {
    return FAIL;
  }

  if (mch_chdir(directory) != 0) {
    /* Do not return immediatly since we may be in the wrong directory. */
    retval = FAIL;
  }

  if (retval == FAIL || mch_dirname((char_u *) buffer, len) == FAIL) {
    /* Do not return immediatly since we are in the wrong directory. */
    retval = FAIL;
  }
   
  if (mch_chdir(old_dir) != 0) {
    /* That shouldn't happen, since we've tested if it works. */
    retval = FAIL;
    EMSG(_(e_prev_dir));
  }

  return retval;
}

/*
 * Append to_append to path with a slash in between.
 */
int append_path(char *path, const char *to_append, int max_len)
{
  int current_length = STRLEN(path);
  int to_append_length = STRLEN(to_append);

  /* Do not append empty strings. */
  if (to_append_length == 0) {
    return OK;
  }

  /* Do not append a dot. */
  if (STRCMP(to_append, ".") == 0) {
    return OK;
  }

  /* Glue both paths with a slash. */
  if (current_length > 0 && path[current_length-1] != '/') {
    current_length += 1; /* Count the trailing slash. */

    /* +1 for the NUL at the end. */
    if (current_length +1 > max_len) {
      return FAIL;
    }

    STRCAT(path, "/");
  }

  /* +1 for the NUL at the end. */
  if (current_length + to_append_length +1 > max_len) {
    return FAIL;
  }

  STRCAT(path, to_append);
  return OK;
}

/*
 * Get absolute file name into "buf[len]".
 *
 * parameter force: Also expand when the given path in fname is already
 * absolute.
 *
 * return FAIL for failure, OK for success
 */
int mch_get_absolute_path(char_u *fname, char_u *buf, int len, int force)
{
  char_u *p;
  *buf = NUL;

  char relative_directory[len];
  char *end_of_path = (char *) fname;

  /* expand it if forced or not an absolute path */
  if (force || !mch_is_absolute_path(fname)) {
    if ((p = vim_strrchr(fname, '/')) != NULL) {

      STRNCPY(relative_directory, fname, p-fname);
      relative_directory[p-fname] = NUL;
      end_of_path = (char *) (p + 1);
    } else {
      relative_directory[0] = NUL;
      end_of_path = (char *) fname;
    }

    if (FAIL == mch_full_dir_name(relative_directory, (char *) buf, len)) {
      return FAIL;
    }
  }
  return append_path((char *) buf, (char *) end_of_path, len);
}

/*
 * Return TRUE if "fname" does not depend on the current directory.
 */
int mch_is_absolute_path(const char_u *fname)
{
  return *fname == '/' || *fname == '~';
}

/*
 * return TRUE if "name" is a directory
 * return FALSE if "name" is not a directory
 * return FALSE for error
 */
int mch_isdir(const char_u *name)
{
  long mode = mch_getperm(name);
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

/*
 * Return TRUE if "name" is executable and can be found in $PATH, is absolute
 * or relative to current dir, FALSE if not.
 */
int mch_can_exe(const char_u *name)
{
  /* If it's an absolute or relative path don't need to use $PATH. */
  if (mch_is_absolute_path(name) ||
     (name[0] == '.' && (name[1] == '/' ||
                        (name[1] == '.' && name[2] == '/')))) {
    return is_executable(name);
  }

  return is_executable_in_path(name);
}

/*
 * Return TRUE if "name" is an executable file, FALSE if not or it doesn't
 * exist.
 */
static int is_executable(const char_u *name)
{
  long mode = mch_getperm(name);

  if (mode < 0) {
    return FALSE;
  }

  if (S_ISREG(mode) && (S_IEXEC & mode)) {
    return TRUE;
  }

  return FALSE;
}

/*
 * Return TRUE if "name" can be found in $PATH and executed, FALSE if not or an
 * error occurs.
 */
static int is_executable_in_path(const char_u *name)
{
  const char *path = getenv("PATH");
  /* PATH environment variable does not exist or is empty. */
  if (path == NULL || *path == NUL) {
    return FALSE;
  }

  int buf_len = STRLEN(name) + STRLEN(path) + 2;
  char_u *buf = alloc((unsigned)(buf_len));
  if (buf == NULL) {
    return FALSE;
  }

  /*
   * Walk through all entries in $PATH to check if "name" exists there and
   * is an executable file.
   */
  for (;; ) {
    const char *e = strchr(path, ':');
    if (e == NULL) {
      e = path + STRLEN(path);
    }

    /* Glue together the given directory from $PATH with name and save into
     * buf. */
    vim_strncpy(buf, (char_u *) path, e - path);
    append_path((char *) buf, (const char *) name, buf_len);

    if (is_executable(buf)) {
      /* Found our executable. Free buf and return. */
      vim_free(buf);
      return OK;
    }

    if (*e != ':') {
      /* End of $PATH without finding any executable called name. */
      vim_free(buf);
      return FALSE;
    }

    path = e + 1;
  }

  /* We should never get to this point. */
  assert(false);
  return FALSE;
}

/*
 * Get file permissions for 'name'.
 * Returns -1 when it doesn't exist.
 */
long mch_getperm(const char_u *name)
{
  uv_fs_t request;
  int result = uv_fs_stat(uv_default_loop(), &request, (const char*) name, NULL);
  uint64_t mode = request.statbuf.st_mode;
  uv_fs_req_cleanup(&request);

  if (result != 0) {
    return -1;
  } else {
    return (long) mode;
  }
}

/*
 * Set file permission for 'name' to 'perm'.
 * Returns FAIL for failure, OK otherwise.
 */
int mch_setperm(const char_u *name, int perm)
{
  uv_fs_t request;
  int result = uv_fs_chmod(uv_default_loop(), &request,
                           (const char*)name, perm, NULL);
  uv_fs_req_cleanup(&request);

  if (result != 0) {
    return FAIL;
  } else {
    return OK;
  }
}

/*
 * return TRUE if "name" exists.
 */
int os_file_exists(char_u *name)
{
  uv_fs_t request;
  int result = uv_fs_stat(uv_default_loop(), &request, (const char*) name, NULL);
  uv_fs_req_cleanup(&request);

  if (result != 0) {
    return FALSE;
  } else {
    return TRUE;
  }
}

