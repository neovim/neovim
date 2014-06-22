#include <inttypes.h>
#include <stdlib.h>
#include <stdio.h>

#include "nvim/ascii.h"
#include "nvim/memory.h"
#include "nvim/misc1.h"
#include "nvim/os/os.h"
#include "nvim/path.h"
#include "nvim/strings.h"
#include "nvim/tempfile.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tempfile.c.generated.h"
#endif

/* Name of Vim's own temp dir. Ends in a slash. */
static char_u *vim_tempdir = NULL;
static uint32_t temp_count = 0;             /* Temp filename counter. */

/*
 * This will create a directory for private use by this instance of Vim.
 * This is done once, and the same directory is used for all temp files.
 * This method avoids security problems because of symlink attacks et al.
 * It's also a bit faster, because we only need to check for an existing
 * file when creating the directory and not for each temp file.
 */
static void vim_maketempdir(void)
{
  static const char *temp_dirs[] = TEMP_DIR_NAMES;
  int i;
  /*
   * Try the entries in `TEMP_DIR_NAMES` to create the temp directory.
   */
  char_u itmp[TEMP_FILE_PATH_MAXLEN];
  for (i = 0; i < (int)(sizeof(temp_dirs) / sizeof(char *)); ++i) {
    /* expand $TMP, leave room for "/nvimXXXXXX/999999999" */
    expand_env((char_u *)temp_dirs[i], itmp, TEMP_FILE_PATH_MAXLEN - 22);
    if (os_isdir(itmp)) {                    /* directory exists */
      add_pathsep(itmp);

      /* Leave room for filename */
      STRCAT(itmp, "nvimXXXXXX");
      if (os_mkdtemp((char *)itmp) != NULL)
        vim_settempdir(itmp);
      if (vim_tempdir != NULL)
        break;
    }
  }
}

/*
 * Delete the temp directory and all files it contains.
 */
void vim_deltempdir(void)
{
  char_u      **files;
  int file_count;
  int i;

  if (vim_tempdir != NULL) {
    sprintf((char *)NameBuff, "%s*", vim_tempdir);
    if (gen_expand_wildcards(1, &NameBuff, &file_count, &files,
            EW_DIR|EW_FILE|EW_SILENT) == OK) {
      for (i = 0; i < file_count; ++i)
        os_remove((char *)files[i]);
      FreeWild(file_count, files);
    }
    path_tail(NameBuff)[-1] = NUL;
    os_rmdir((char *)NameBuff);

    free(vim_tempdir);
    vim_tempdir = NULL;
  }
}

char_u *vim_gettempdir(void)
{
  if (vim_tempdir == NULL) {
    vim_maketempdir();
  }

  return vim_tempdir;
}

/*
 * Directory "tempdir" was created.  Expand this name to a full path and put
 * it in "vim_tempdir".  This avoids that using ":cd" would confuse us.
 * "tempdir" must be no longer than MAXPATHL.
 */
static void vim_settempdir(char_u *tempdir)
{
  char_u *buf = verbose_try_malloc((size_t)MAXPATHL + 2);
  if (buf) {
    if (vim_FullName(tempdir, buf, MAXPATHL, FALSE) == FAIL)
      STRCPY(buf, tempdir);
    add_pathsep(buf);
    vim_tempdir = vim_strsave(buf);
    free(buf);
  }
}

/*
 * vim_tempname(): Return a unique name that can be used for a temp file.
 *
 * The temp file is NOT created.
 *
 * The returned pointer is to allocated memory.
 * The returned pointer is NULL if no valid name was found.
 */
char_u *vim_tempname(void)
{
  char_u itmp[TEMP_FILE_PATH_MAXLEN];

  char_u *tempdir = vim_gettempdir();
  if (tempdir != NULL) {
    /* There is no need to check if the file exists, because we own the
     * directory and nobody else creates a file in it. */
    sprintf((char *)itmp, "%s%" PRIu32, tempdir, temp_count++);
    return vim_strsave(itmp);
  }

  return NULL;
}
