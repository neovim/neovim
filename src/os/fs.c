/* vi:set ts=8 sts=4 sw=4:
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
  if ((errno = uv_cwd((char *)buf, len)) != 0) {
      STRCPY(buf, uv_strerror(errno));
      return FAIL;
  }
  return OK;
}

/*
 * Get absolute file name into "buf[len]".
 *
 * return FAIL for failure, OK for success
 */
int mch_FullName(
        char_u      *fname,
        char_u      *buf,
        int len,
        int force                       /* also expand when already absolute path */
        )
{
  int l;
  char_u olddir[MAXPATHL];
  char_u      *p;
  int retval = OK;



  /* expand it if forced or not an absolute path */
  if (force || !mch_isFullName(fname)) {
    /*
     * If the file name has a path, change to that directory for a moment,
     * and then do the getwd() (and get back to where we were).
     * This will get the correct path name with "../" things.
     */
    if ((p = vim_strrchr(fname, '/')) != NULL) {

      /* Only change directory when we are sure we can return to where
       * we are now.  After doing "su" chdir(".") might not work. */
      if ((mch_dirname(olddir, MAXPATHL) == FAIL
         || mch_chdir((char *)olddir) != 0)) {
        p = NULL;               /* can't get current dir: don't chdir */
        retval = FAIL;
      } else   {
        /* The directory is copied into buf[], to be able to remove
         * the file name without changing it (could be a string in
         * read-only memory) */
        if (p - fname >= len)
          retval = FAIL;
        else {
          vim_strncpy(buf, fname, p - fname);
          if (mch_chdir((char *)buf))
            retval = FAIL;
          else
            fname = p + 1;
          *buf = NUL;
        }
      }
    }
    if (mch_dirname(buf, len) == FAIL) {
      retval = FAIL;
      *buf = NUL;
    }
    if (p != NULL) {
      l = mch_chdir((char *)olddir);
      if (l != 0)
        EMSG(_(e_prev_dir));
    }

    l = STRLEN(buf);
    if (l >= len - 1)
      retval = FAIL;       /* no space for trailing "/" */
    else if (l > 0 && buf[l - 1] != '/' && *fname != NUL
             && STRCMP(fname, ".") != 0)
      STRCAT(buf, "/");
  }

  /* Catch file names which are too long. */
  if (retval == FAIL || (int)(STRLEN(buf) + STRLEN(fname)) >= len)
    return FAIL;

  /* Do not append ".", "/dir/." is equal to "/dir". */
  if (STRCMP(fname, ".") != 0)
    STRCAT(buf, fname);

  return OK;
}

/*
 * Return TRUE if "fname" does not depend on the current directory.
 */
int mch_isFullName(char_u *fname)
{
  return *fname == '/' || *fname == '~';
}

