#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <string.h>
#include <inttypes.h>
#include <fcntl.h>

#include "nvim/vim.h"
#include "nvim/api/private/handle.h"
#include "nvim/ascii.h"
#include "nvim/backup_utils.h"
#include "nvim/fileio.h"
#include "nvim/buffer.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/fold.h"
#include "nvim/func_attr.h"
#include "nvim/getchar.h"
#include "nvim/hashtab.h"
#include "nvim/iconv.h"
#include "nvim/mbyte.h"
#include "nvim/memfile.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/garray.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/sha256.h"
#include "nvim/state.h"
#include "nvim/strings.h"
#include "nvim/ui.h"
#include "nvim/ui_compositor.h"
#include "nvim/types.h"
#include "nvim/undo.h"
#include "nvim/window.h"
#include "nvim/shada.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/time.h"
#include "nvim/os/input.h"

/*
 * Creates a backup of the file fname by creating a copy of the file.
 * @param[in]   fname         The name of the file whose backup is needed.
 * @param[in]   original_file The stat file info of the original file.
 * @param[in]   forceit       True if `:w!`
 */
int create_backup_copy(char_u *fname, FileInfo *original_file, int forceit) {
  char *errmsg = NULL;
  char_u *backup;
  char_u *dirp = p_bdir;
  int some_error = false;
  while(dirp) {
    backup = create_bname(fname, dirp, original_file, &some_error);
    if (backup != NULL) {
      if (create_bfile(backup, fname, original_file, errmsg) == OK) {
        XFREE_CLEAR(backup);
        return OK;
      }
    }
  }
  return after_backup(errmsg, some_error, backup, forceit);
}

int after_backup(char_u *errmsg, int some_error, char_u *backup, int forceit) {
  int retval;
  if(backup == NULL && errmsg == NULL) {
    errmsg = _("E509: Cannot create backup file (add ! to override");
  }
  if ((some_error || errmsg != NULL) && !forceit) {
    retval = FAIL;
  }
  if(forceit) {
    XFREE_CLEAR(errmsg);
    retval = OK;
  }
  if(errmsg != NULL) {
    EMSG(errmsg);
    XFREE_CLEAR(errmsg);
  }
  return retval;
}

/*
 * Creates a backup of the file fname by renaming the original file.
 * @param[in]   fname         The name of the file whose backup is needed.
 * @param[in]   original_file The stat file info of the original file.
 * @param[in]   forceit       True if `:w!`
 */
int create_backup_rename(char_u *fname, FileInfo *original_file, int forceit) {
  char_u *backup;
  int retval;
  char_u *dirp = p_bdir;
  char_u *errmsg = NULL;
  int some_error = false;
  while(dirp) {
    backup = create_bname(fname, dirp, original_file, &some_error);
    if(backup != NULL) {
      // if the renaming of the original file to the backup file
      // works quit here.
      if(vim_rename(fname, backup) == 0) {
        XFREE_CLEAR(backup);
        return OK;
      }
      XFREE_CLEAR(backup);
    }
  }
  if(backup == NULL && !forceit) {
    errmsg = _("E510: Can't make backup file (add ! to override)");
  }
  return after_backup(errmsg, some_error, backup, forceit);
}


char_u *create_bname(char_u *fname, char_u *dirp, FileInfo *original_file, int *some_error) {
  char_u      *wp;
  char_u      *rootname;
  char_u      *backup = NULL;
  char_u      *backup_ext;
  if (*p_bex == NUL)
    backup_ext = (char_u *)".bak";
  else
    backup_ext = p_bex;
  const bool no_prepend_dot = false;

  /*
   * Try to make the backup in each directory in the 'bdir' option.
   *
   * Unix semantics has it, that we may have a writable file,
   * that cannot be recreated with a simple open(..., O_CREAT, ) e.g:
   *  - the directory is not writable,
   *  - the file may be a symbolic link,
   *  - the file may belong to another user/group, etc.
   *
   * For these reasons, the existing writable file must be truncated
   * and reused. Creation of a backup COPY will be attempted.
   */
  while (*dirp) {
    /*
     * Isolate one directory name,nusing an entry in 'bdir'.
     */
    (void)copy_option_part(&dirp, IObuff, IOSIZE, ",");
    char_u *p = IObuff + STRLEN(IObuff);
    if (after_pathsep((char *)IObuff, (char *)p) && p[-1] == p[-2]) {
      // Ends with '//', Use Full path
      backup = get_full_bname(fname, backup_ext, no_prepend_dot);
      if(backup != NULL) {
        if(need_temp_bname(backup, original_file)) {
          if(get_temp_bname(backup, backup_ext) == FAIL) {
            XFREE_CLEAR(backup);
          }
        }
      }
    }

    rootname = get_file_in_dir(fname, IObuff);
    if (rootname == NULL) {
      *some_error = TRUE;                /* out of memory */
      return NULL;
    }

    // Make the backup file name if still NULL.
    if (backup == NULL) {
      backup = (char_u *)modname((char *)rootname, (char *)backup_ext,
                                 no_prepend_dot);
    }

    if (backup == NULL) {
      xfree(rootname);
      *some_error = TRUE;                          /* out of memory */
      return NULL;
    }

    if(need_temp_bname(backup, original_file)) {
      if(get_temp_bname(backup, backup_ext) == FAIL) {
        XFREE_CLEAR(backup);
      }
    }
    xfree(rootname);

    if(backup == NULL)
      continue;
    return backup;
  }
  return NULL;
}

int create_bfile(char_u *backup, char_u *fname, FileInfo *original_file, char_u *errmsg) {
  /*
   * Try to create the backup file
   */
  FileInfo backup_file;
  vim_acl_T acl = mch_get_acl(fname);
  os_fileinfo((char *)backup, &backup_file);
  int perm = original_file->stat.st_mode;
  /* remove old backup, if present */
  os_remove((char *)backup);

  // set file protection same as original file, but
  // strip s-bit.
  (void)os_setperm((const char *)backup, perm & 0777);

#ifdef UNIX
  //
  // Try to set the group of the backup same as the original file. If
  // this fails, set the protection bits for the group same as the
  // protection bits for others.
  //
  if (backup_file.stat.st_gid != original_file->stat.st_gid
      && os_chown((char *)backup, -1, original_file->stat.st_gid) != 0) {
    os_setperm((const char *)backup,
               (perm & 0707) | ((perm & 07) << 3));
  }
#endif

  // copy the file
  if (os_copy((char *)fname, (char *)backup, UV_FS_COPYFILE_FICLONE)
      != 0) {
    errmsg = _("E506: Can't write to backup file "
                 "(add ! to override)");
  }

#ifdef UNIX
  os_file_settime((char *)backup,
                  original_file->stat.st_atim.tv_sec,
                  original_file->stat.st_mtim.tv_sec);
#endif
#ifdef HAVE_ACL
  mch_set_acl(backup, acl);
#endif
  if(errmsg != NULL) {
    return FAIL;
  }
  return OK;
}

/*
 * Get a temporary backup name by replacing one character just before the extension
 */
int get_temp_bname(char_u *backup, char_u *backup_ext) {
  FileInfo backup_file;
  char_u *wp = backup + STRLEN(backup) - 1 - STRLEN(backup_ext);
  if (wp < backup) {                // empty file name ???
    wp = backup;
  }
  *wp = 'z';
  while (*wp > 'a'
         && os_fileinfo((char *)backup, &backup_file)) {
    --*wp;
  }
  // They all exist??? Must be something wrong.
  if (*wp == 'a') {
    return FAIL;
  }
  return OK;
}

/*
 * Get backup name using the full path.
 */
char_u *get_full_bname(char_u *fname, char_u *backup_ext, bool no_prepend_dot) {
  char_u *p = IObuff + STRLEN(IObuff);
  char_u *backup = NULL;
  if ((p = (char_u *)make_percent_swname((char *)IObuff, (char *)fname))
      != NULL) {
    backup = (char_u *)modname((char *)p, (char *)backup_ext,
                               no_prepend_dot);
    xfree(p);
    return backup;
  }
  return NULL;
}

/*
 * Checks if a temporary backup name is needed.
 * A temporary backup name is needed if a backup already exists, and
 * we are not supposed to keep a backup copy.
 */
bool need_temp_bname(char_u * backup, FileInfo *original_file) {
  FileInfo backup_file;
  /*
   * Check if backup file already exists.
   */
  if (os_fileinfo((char *)backup, &backup_file)) {
    if (os_fileinfo_id_equal(&backup_file, original_file)) {
      //
      // Backup file is same as original file.
      // May happen when modname() gave the same file back (e.g. silly
      // link). If we don't check here, we either ruin the file when
      // copying or erase it after writing.
      //
      return false;
    } else if (!p_bk) {
      // We are not going to keep the backup file, so don't
      // delete an existing one, and try to use another name instead.
      // Change one character, just before the extension.
      //
      return true;
    }
  }
  return false;
}
