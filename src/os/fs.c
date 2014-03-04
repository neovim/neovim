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

#include "os.h"
#include "../message.h"
#include "../misc2.h"

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
int mch_dirname(char_u *buf, int len)
{
  int errno;
  if ((errno = uv_cwd((char *) buf, len)) != 0) {
      STRCPY(buf, uv_strerror(errno));
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

  if(0 == STRLEN(directory)) {
    return mch_dirname((char_u *) buffer, len);
  }

  char old_dir[MAXPATHL];

  /* Get current directory name. */
  if (FAIL == mch_dirname((char_u *) old_dir, MAXPATHL)) {
    return FAIL;
  }

  /* We have to get back to the current dir at the end, check if that works. */
  if (0 != mch_chdir(old_dir)) {
    return FAIL;
  }

  if (0 != mch_chdir(directory)) {
    retval = FAIL;
  }

  if ((FAIL == retval) || (FAIL == mch_dirname((char_u *) buffer, len))) {
    retval = FAIL;
  }
   
  if (0 != mch_chdir(old_dir)) {
    /* That shouldn't happen, since we've tested if it works. */
    retval = FAIL;
    EMSG(_(e_prev_dir));
  }
  return retval;
}

/* 
 * Append to_append to path with a slash in between.
 */
int append_path(char *path, char *to_append, int max_len)
{
  int current_length = STRLEN(path);
  int to_append_length = STRLEN(to_append);

  /* Do not append empty strings. */
  if (0 == to_append_length)
    return OK;

  /* Do not append a dot. */
  if (STRCMP(to_append, ".") == 0)
    return OK;

  /* Glue both paths with a slash. */
  if (current_length > 0 && path[current_length-1] != '/') {
    current_length += 1; /* Count the trailing slash. */

    if (current_length > max_len)
      return FAIL;

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
int mch_full_name(char_u *fname, char_u *buf, int len, int force)
{
  char_u *p;
  *buf = NUL;

  char relative_directory[len];
  char *end_of_path = (char *) fname;

  /* expand it if forced or not an absolute path */
  if (force || !mch_is_full_name(fname)) {
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
int mch_is_full_name(char_u *fname)
{
  return *fname == '/' || *fname == '~';
}

/*
 * return TRUE if "name" is a directory
 * return FALSE if "name" is not a directory
 * return FALSE for error
 */
int mch_isdir(char_u *name)
{
  uv_fs_t request;
  if (0 != uv_fs_stat(uv_default_loop(), &request, (const char*) name, NULL)) {
    return FALSE;
  }

  if (!S_ISDIR(request.statbuf.st_mode)) {
    return FALSE;
  }

  return TRUE;
}

