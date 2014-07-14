#include <inttypes.h>
#include <stdbool.h>
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

/// Name of Vim's own temp dir. Ends in a slash.
static char_u *vim_tempdir = NULL;

/// Create a directory for private use by this instance of Neovim.
/// This is done once, and the same directory is used for all temp files.
/// This method avoids security problems because of symlink attacks et al.
/// It's also a bit faster, because we only need to check for an existing
/// file when creating the directory and not for each temp file.
static void vim_maketempdir(void)
{
  static const char *temp_dirs[] = TEMP_DIR_NAMES;
  // Try the entries in `TEMP_DIR_NAMES` to create the temp directory.
  char_u itmp[TEMP_FILE_PATH_MAXLEN];
  for (size_t i = 0; i < sizeof(temp_dirs) / sizeof(char *); ++i) {
    // Expand environment variables, leave room for "/nvimXXXXXX/999999999"
    expand_env((char_u *)temp_dirs[i], itmp, TEMP_FILE_PATH_MAXLEN - 22);
    if (os_isdir(itmp)) {  // directory exists
      add_pathsep(itmp);

      // Concatenate with temporary directory name pattern
      STRCAT(itmp, "nvimXXXXXX");
      if (os_mkdtemp((char *)itmp) != NULL) {
        vim_settempdir(itmp);
      }
      if (vim_tempdir != NULL) {
        break;
      }
    }
  }
}

/// Delete the temp directory and all files it contains.
void vim_deltempdir(void)
{
  if (vim_tempdir != NULL) {
    snprintf((char *)NameBuff, MAXPATHL, "%s*", vim_tempdir);

    char_u **files;
    int file_count;
    if (gen_expand_wildcards(1, &NameBuff, &file_count, &files,
        EW_DIR|EW_FILE|EW_SILENT) == OK) {
      for (int i = 0; i < file_count; ++i) {
        os_remove((char *)files[i]);
      }
      FreeWild(file_count, files);
    }
    path_tail(NameBuff)[-1] = NUL;
    os_rmdir((char *)NameBuff);

    free(vim_tempdir);
    vim_tempdir = NULL;
  }
}

/// Get the name of temp directory. This directory would be created on the first
/// call to this function.
char_u *vim_gettempdir(void)
{
  if (vim_tempdir == NULL) {
    vim_maketempdir();
  }

  return vim_tempdir;
}

/// Set Neovim own temporary directory name to `tempdir`. This directory should
/// be already created. Expand this name to a full path and put it in
/// `vim_tempdir`. This avoids that using `:cd` would confuse us.
///
/// @param tempdir must be no longer than MAXPATHL.
static void vim_settempdir(char_u *tempdir)
{
  char_u *buf = verbose_try_malloc((size_t)MAXPATHL + 2);
  if (buf) {
    if (vim_FullName(tempdir, buf, MAXPATHL, false) == FAIL) {
      STRCPY(buf, tempdir);
    }
    add_pathsep(buf);
    vim_tempdir = vim_strsave(buf);
    free(buf);
  }
}

/// Return a unique name that can be used for a temp file.
///
/// @note The temp file is NOT created.
///
/// @return pointer to the temp file name or NULL if Neovim can't create
///         temporary directory for its own temporary files.
char_u *vim_tempname(void)
{
  // Temp filename counter.
  static uint32_t temp_count;

  char_u *tempdir = vim_gettempdir();
  if (!tempdir) {
    return NULL;
  }

  // There is no need to check if the file exists, because we own the directory
  // and nobody else creates a file in it.
  char_u itmp[TEMP_FILE_PATH_MAXLEN];
  snprintf((char *)itmp, TEMP_FILE_PATH_MAXLEN,
           "%s%" PRIu32, tempdir, temp_count++);
  return vim_strsave(itmp);
}
