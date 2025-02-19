// eval/fs.c: Filesystem related builtin functions

#include <assert.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include "auto/config.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/cmdexpand.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/fs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/userfunc.h"
#include "nvim/eval/window.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_docmd.h"
#include "nvim/file_search.h"
#include "nvim/fileio.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/macros_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option_vars.h"
#include "nvim/os/fileio.h"
#include "nvim/os/fileio_defs.h"
#include "nvim/os/fs.h"
#include "nvim/os/fs_defs.h"
#include "nvim/os/os_defs.h"
#include "nvim/path.h"
#include "nvim/pos_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/fs.c.generated.h"
#endif

static const char e_error_while_writing_str[] = N_("E80: Error while writing: %s");

/// "chdir(dir)" function
void f_chdir(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;

  if (argvars[0].v_type != VAR_STRING) {
    // Returning an empty string means it failed.
    // No error message, for historic reasons.
    return;
  }

  // Return the current directory
  char *cwd = xmalloc(MAXPATHL);
  if (os_dirname(cwd, MAXPATHL) != FAIL) {
#ifdef BACKSLASH_IN_FILENAME
    slash_adjust(cwd);
#endif
    rettv->vval.v_string = xstrdup(cwd);
  }
  xfree(cwd);

  CdScope scope = kCdScopeGlobal;
  if (curwin->w_localdir != NULL) {
    scope = kCdScopeWindow;
  } else if (curtab->tp_localdir != NULL) {
    scope = kCdScopeTabpage;
  }

  if (!changedir_func(argvars[0].vval.v_string, scope)) {
    // Directory change failed
    XFREE_CLEAR(rettv->vval.v_string);
  }
}

/// "delete()" function
void f_delete(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = -1;
  if (check_secure()) {
    return;
  }

  const char *const name = tv_get_string(&argvars[0]);
  if (*name == NUL) {
    emsg(_(e_invarg));
    return;
  }

  char nbuf[NUMBUFLEN];
  const char *flags;
  if (argvars[1].v_type != VAR_UNKNOWN) {
    flags = tv_get_string_buf(&argvars[1], nbuf);
  } else {
    flags = "";
  }

  if (*flags == NUL) {
    // delete a file
    rettv->vval.v_number = os_remove(name) == 0 ? 0 : -1;
  } else if (strcmp(flags, "d") == 0) {
    // delete an empty directory
    rettv->vval.v_number = os_rmdir(name) == 0 ? 0 : -1;
  } else if (strcmp(flags, "rf") == 0) {
    // delete a directory recursively
    rettv->vval.v_number = delete_recursive(name);
  } else {
    semsg(_(e_invexpr2), flags);
  }
}

/// "executable()" function
void f_executable(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (tv_check_for_string_arg(argvars, 0) == FAIL) {
    return;
  }

  // Check in $PATH and also check directly if there is a directory name
  rettv->vval.v_number = os_can_exe(tv_get_string(&argvars[0]), NULL, true);
}

/// "exepath()" function
void f_exepath(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (tv_check_for_nonempty_string_arg(argvars, 0) == FAIL) {
    return;
  }

  char *path = NULL;

  os_can_exe(tv_get_string(&argvars[0]), &path, true);

#ifdef BACKSLASH_IN_FILENAME
  if (path != NULL) {
    slash_adjust(path);
  }
#endif

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = path;
}

/// "filecopy()" function
void f_filecopy(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = false;

  if (check_secure()
      || tv_check_for_string_arg(argvars, 0) == FAIL
      || tv_check_for_string_arg(argvars, 1) == FAIL) {
    return;
  }

  const char *from = tv_get_string(&argvars[0]);

  FileInfo from_info;
  if (os_fileinfo_link(from, &from_info)
      && (S_ISREG(from_info.stat.st_mode) || S_ISLNK(from_info.stat.st_mode))) {
    rettv->vval.v_number
      = vim_copyfile(tv_get_string(&argvars[0]), tv_get_string(&argvars[1])) == OK;
  }
}

/// "filereadable()" function
void f_filereadable(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *const p = tv_get_string(&argvars[0]);
  rettv->vval.v_number = (*p && !os_isdir(p) && os_file_is_readable(p));
}

/// @return  0 for not writable
///          1 for writable file
///          2 for a dir which we have rights to write into.
void f_filewritable(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *filename = tv_get_string(&argvars[0]);
  rettv->vval.v_number = os_file_is_writable(filename);
}

static void findfilendir(typval_T *argvars, typval_T *rettv, int find_what)
{
  char *fresult = NULL;
  char *path = *curbuf->b_p_path == NUL ? p_path : curbuf->b_p_path;
  int count = 1;
  bool first = true;
  bool error = false;

  rettv->vval.v_string = NULL;
  rettv->v_type = VAR_STRING;

  const char *fname = tv_get_string(&argvars[0]);

  char pathbuf[NUMBUFLEN];
  if (argvars[1].v_type != VAR_UNKNOWN) {
    const char *p = tv_get_string_buf_chk(&argvars[1], pathbuf);
    if (p == NULL) {
      error = true;
    } else {
      if (*p != NUL) {
        path = (char *)p;
      }

      if (argvars[2].v_type != VAR_UNKNOWN) {
        count = (int)tv_get_number_chk(&argvars[2], &error);
      }
    }
  }

  if (count < 0) {
    tv_list_alloc_ret(rettv, kListLenUnknown);
  }

  if (*fname != NUL && !error) {
    char *file_to_find = NULL;
    char *search_ctx = NULL;

    do {
      if (rettv->v_type == VAR_STRING || rettv->v_type == VAR_LIST) {
        xfree(fresult);
      }
      fresult = find_file_in_path_option(first ? (char *)fname : NULL,
                                         first ? strlen(fname) : 0,
                                         0, first, path,
                                         find_what, curbuf->b_ffname,
                                         (find_what == FINDFILE_DIR
                                          ? ""
                                          : curbuf->b_p_sua),
                                         &file_to_find, &search_ctx);
      first = false;

      if (fresult != NULL && rettv->v_type == VAR_LIST) {
        tv_list_append_string(rettv->vval.v_list, fresult, -1);
      }
    } while ((rettv->v_type == VAR_LIST || --count > 0) && fresult != NULL);

    xfree(file_to_find);
    vim_findfile_cleanup(search_ctx);
  }

  if (rettv->v_type == VAR_STRING) {
    rettv->vval.v_string = fresult;
  }
}

/// "finddir({fname}[, {path}[, {count}]])" function
void f_finddir(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  findfilendir(argvars, rettv, FINDFILE_DIR);
}

/// "findfile({fname}[, {path}[, {count}]])" function
void f_findfile(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  findfilendir(argvars, rettv, FINDFILE_FILE);
}

/// `getcwd([{win}[, {tab}]])` function
///
/// Every scope not specified implies the currently selected scope object.
///
/// @pre  The arguments must be of type number.
/// @pre  There may not be more than two arguments.
/// @pre  An argument may not be -1 if preceding arguments are not all -1.
///
/// @post  The return value will be a string.
void f_getcwd(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  // Possible scope of working directory to return.
  CdScope scope = kCdScopeInvalid;

  // Numbers of the scope objects (window, tab) we want the working directory
  // of. A `-1` means to skip this scope, a `0` means the current object.
  int scope_number[] = {
    [kCdScopeWindow] = 0,   // Number of window to look at.
    [kCdScopeTabpage] = 0,  // Number of tab to look at.
  };

  char *cwd = NULL;    // Current working directory to print
  char *from = NULL;    // The original string to copy

  tabpage_T *tp = curtab;  // The tabpage to look at.
  win_T *win = curwin;     // The window to look at.

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;

  // Pre-conditions and scope extraction together
  for (int i = MIN_CD_SCOPE; i < MAX_CD_SCOPE; i++) {
    // If there is no argument there are no more scopes after it, break out.
    if (argvars[i].v_type == VAR_UNKNOWN) {
      break;
    }
    if (argvars[i].v_type != VAR_NUMBER) {
      emsg(_(e_invarg));
      return;
    }
    scope_number[i] = (int)argvars[i].vval.v_number;
    // It is an error for the scope number to be less than `-1`.
    if (scope_number[i] < -1) {
      emsg(_(e_invarg));
      return;
    }
    // Use the narrowest scope the user requested
    if (scope_number[i] >= 0 && scope == kCdScopeInvalid) {
      // The scope is the current iteration step.
      scope = i;
    } else if (scope_number[i] < 0) {
      scope = i + 1;
    }
  }

  // Find the tabpage by number
  if (scope_number[kCdScopeTabpage] > 0) {
    tp = find_tabpage(scope_number[kCdScopeTabpage]);
    if (!tp) {
      emsg(_("E5000: Cannot find tab number."));
      return;
    }
  }

  // Find the window in `tp` by number, `NULL` if none.
  if (scope_number[kCdScopeWindow] >= 0) {
    if (scope_number[kCdScopeTabpage] < 0) {
      emsg(_("E5001: Higher scope cannot be -1 if lower scope is >= 0."));
      return;
    }

    if (scope_number[kCdScopeWindow] > 0) {
      win = find_win_by_nr(&argvars[0], tp);
      if (!win) {
        emsg(_("E5002: Cannot find window number."));
        return;
      }
    }
  }

  cwd = xmalloc(MAXPATHL);

  switch (scope) {
  case kCdScopeWindow:
    assert(win);
    from = win->w_localdir;
    if (from) {
      break;
    }
    FALLTHROUGH;
  case kCdScopeTabpage:
    assert(tp);
    from = tp->tp_localdir;
    if (from) {
      break;
    }
    FALLTHROUGH;
  case kCdScopeGlobal:
    if (globaldir) {        // `globaldir` is not always set.
      from = globaldir;
      break;
    }
    FALLTHROUGH;            // In global directory, just need to get OS CWD.
  case kCdScopeInvalid:     // If called without any arguments, get OS CWD.
    if (os_dirname(cwd, MAXPATHL) == FAIL) {
      from = "";  // Return empty string on failure.
    }
  }

  if (from) {
    xstrlcpy(cwd, from, MAXPATHL);
  }

  rettv->vval.v_string = xstrdup(cwd);
#ifdef BACKSLASH_IN_FILENAME
  slash_adjust(rettv->vval.v_string);
#endif

  xfree(cwd);
}

/// "getfperm({fname})" function
void f_getfperm(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  char *perm = NULL;
  char flags[] = "rwx";

  const char *filename = tv_get_string(&argvars[0]);
  int32_t file_perm = os_getperm(filename);
  if (file_perm >= 0) {
    perm = xstrdup("---------");
    for (int i = 0; i < 9; i++) {
      if (file_perm & (1 << (8 - i))) {
        perm[i] = flags[i % 3];
      }
    }
  }
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = perm;
}

/// "getfsize({fname})" function
void f_getfsize(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *fname = tv_get_string(&argvars[0]);

  rettv->v_type = VAR_NUMBER;

  FileInfo file_info;
  if (os_fileinfo(fname, &file_info)) {
    uint64_t filesize = os_fileinfo_size(&file_info);
    if (os_isdir(fname)) {
      rettv->vval.v_number = 0;
    } else {
      rettv->vval.v_number = (varnumber_T)filesize;

      // non-perfect check for overflow
      if ((uint64_t)rettv->vval.v_number != filesize) {
        rettv->vval.v_number = -2;
      }
    }
  } else {
    rettv->vval.v_number = -1;
  }
}

/// "getftime({fname})" function
void f_getftime(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *fname = tv_get_string(&argvars[0]);

  FileInfo file_info;
  if (os_fileinfo(fname, &file_info)) {
    rettv->vval.v_number = (varnumber_T)file_info.stat.st_mtim.tv_sec;
  } else {
    rettv->vval.v_number = -1;
  }
}

/// "getftype({fname})" function
void f_getftype(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  char *type = NULL;
  char *t;

  const char *fname = tv_get_string(&argvars[0]);

  rettv->v_type = VAR_STRING;
  FileInfo file_info;
  if (os_fileinfo_link(fname, &file_info)) {
    uint64_t mode = file_info.stat.st_mode;
    if (S_ISREG(mode)) {
      t = "file";
    } else if (S_ISDIR(mode)) {
      t = "dir";
    } else if (S_ISLNK(mode)) {
      t = "link";
    } else if (S_ISBLK(mode)) {
      t = "bdev";
    } else if (S_ISCHR(mode)) {
      t = "cdev";
    } else if (S_ISFIFO(mode)) {
      t = "fifo";
    } else if (S_ISSOCK(mode)) {
      t = "socket";
    } else {
      t = "other";
    }
    type = xstrdup(t);
  }
  rettv->vval.v_string = type;
}

/// "glob()" function
void f_glob(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  int options = WILD_SILENT|WILD_USE_NL;
  expand_T xpc;
  bool error = false;

  // When the optional second argument is non-zero, don't remove matches
  // for 'wildignore' and don't put matches for 'suffixes' at the end.
  rettv->v_type = VAR_STRING;
  if (argvars[1].v_type != VAR_UNKNOWN) {
    if (tv_get_number_chk(&argvars[1], &error)) {
      options |= WILD_KEEP_ALL;
    }
    if (argvars[2].v_type != VAR_UNKNOWN) {
      if (tv_get_number_chk(&argvars[2], &error)) {
        tv_list_set_ret(rettv, NULL);
      }
      if (argvars[3].v_type != VAR_UNKNOWN
          && tv_get_number_chk(&argvars[3], &error)) {
        options |= WILD_ALLLINKS;
      }
    }
  }
  if (!error) {
    ExpandInit(&xpc);
    xpc.xp_context = EXPAND_FILES;
    if (p_wic) {
      options += WILD_ICASE;
    }
    if (rettv->v_type == VAR_STRING) {
      rettv->vval.v_string = ExpandOne(&xpc, (char *)
                                       tv_get_string(&argvars[0]), NULL, options,
                                       WILD_ALL);
    } else {
      ExpandOne(&xpc, (char *)tv_get_string(&argvars[0]), NULL, options,
                WILD_ALL_KEEP);
      tv_list_alloc_ret(rettv, xpc.xp_numfiles);
      for (int i = 0; i < xpc.xp_numfiles; i++) {
        tv_list_append_string(rettv->vval.v_list, xpc.xp_files[i], -1);
      }
      ExpandCleanup(&xpc);
    }
  } else {
    rettv->vval.v_string = NULL;
  }
}

/// "globpath()" function
void f_globpath(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  int flags = WILD_IGNORE_COMPLETESLASH;  // Flags for globpath.
  bool error = false;

  // Return a string, or a list if the optional third argument is non-zero.
  rettv->v_type = VAR_STRING;

  if (argvars[2].v_type != VAR_UNKNOWN) {
    // When the optional second argument is non-zero, don't remove matches
    // for 'wildignore' and don't put matches for 'suffixes' at the end.
    if (tv_get_number_chk(&argvars[2], &error)) {
      flags |= WILD_KEEP_ALL;
    }

    if (argvars[3].v_type != VAR_UNKNOWN) {
      if (tv_get_number_chk(&argvars[3], &error)) {
        tv_list_set_ret(rettv, NULL);
      }
      if (argvars[4].v_type != VAR_UNKNOWN
          && tv_get_number_chk(&argvars[4], &error)) {
        flags |= WILD_ALLLINKS;
      }
    }
  }

  char buf1[NUMBUFLEN];
  const char *const file = tv_get_string_buf_chk(&argvars[1], buf1);
  if (file != NULL && !error) {
    garray_T ga;
    ga_init(&ga, (int)sizeof(char *), 10);
    globpath((char *)tv_get_string(&argvars[0]), (char *)file, &ga, flags, false);

    if (rettv->v_type == VAR_STRING) {
      rettv->vval.v_string = ga_concat_strings_sep(&ga, "\n");
    } else {
      tv_list_alloc_ret(rettv, ga.ga_len);
      for (int i = 0; i < ga.ga_len; i++) {
        tv_list_append_string(rettv->vval.v_list,
                              ((const char **)(ga.ga_data))[i], -1);
      }
    }

    ga_clear_strings(&ga);
  } else {
    rettv->vval.v_string = NULL;
  }
}

/// "glob2regpat()" function
void f_glob2regpat(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *const pat = tv_get_string_chk(&argvars[0]);  // NULL on type error

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = pat == NULL ? NULL : file_pat_to_reg_pat(pat, NULL, NULL, false);
}

/// `haslocaldir([{win}[, {tab}]])` function
///
/// Returns `1` if the scope object has a local directory, `0` otherwise. If a
/// scope object is not specified the current one is implied. This function
/// share a lot of code with `f_getcwd`.
///
/// @pre  The arguments must be of type number.
/// @pre  There may not be more than two arguments.
/// @pre  An argument may not be -1 if preceding arguments are not all -1.
///
/// @post  The return value will be either the number `1` or `0`.
void f_haslocaldir(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  // Possible scope of working directory to return.
  CdScope scope = kCdScopeInvalid;

  // Numbers of the scope objects (window, tab) we want the working directory
  // of. A `-1` means to skip this scope, a `0` means the current object.
  int scope_number[] = {
    [kCdScopeWindow] = 0,  // Number of window to look at.
    [kCdScopeTabpage] = 0,  // Number of tab to look at.
  };

  tabpage_T *tp = curtab;  // The tabpage to look at.
  win_T *win = curwin;  // The window to look at.

  rettv->v_type = VAR_NUMBER;
  rettv->vval.v_number = 0;

  // Pre-conditions and scope extraction together
  for (int i = MIN_CD_SCOPE; i < MAX_CD_SCOPE; i++) {
    if (argvars[i].v_type == VAR_UNKNOWN) {
      break;
    }
    if (argvars[i].v_type != VAR_NUMBER) {
      emsg(_(e_invarg));
      return;
    }
    scope_number[i] = (int)argvars[i].vval.v_number;
    if (scope_number[i] < -1) {
      emsg(_(e_invarg));
      return;
    }
    // Use the narrowest scope the user requested
    if (scope_number[i] >= 0 && scope == kCdScopeInvalid) {
      // The scope is the current iteration step.
      scope = i;
    } else if (scope_number[i] < 0) {
      scope = i + 1;
    }
  }

  // If the user didn't specify anything, default to window scope
  if (scope == kCdScopeInvalid) {
    scope = MIN_CD_SCOPE;
  }

  // Find the tabpage by number
  if (scope_number[kCdScopeTabpage] > 0) {
    tp = find_tabpage(scope_number[kCdScopeTabpage]);
    if (!tp) {
      emsg(_("E5000: Cannot find tab number."));
      return;
    }
  }

  // Find the window in `tp` by number, `NULL` if none.
  if (scope_number[kCdScopeWindow] >= 0) {
    if (scope_number[kCdScopeTabpage] < 0) {
      emsg(_("E5001: Higher scope cannot be -1 if lower scope is >= 0."));
      return;
    }

    if (scope_number[kCdScopeWindow] > 0) {
      win = find_win_by_nr(&argvars[0], tp);
      if (!win) {
        emsg(_("E5002: Cannot find window number."));
        return;
      }
    }
  }

  switch (scope) {
  case kCdScopeWindow:
    assert(win);
    rettv->vval.v_number = win->w_localdir ? 1 : 0;
    break;
  case kCdScopeTabpage:
    assert(tp);
    rettv->vval.v_number = tp->tp_localdir ? 1 : 0;
    break;
  case kCdScopeGlobal:
    // The global scope never has a local directory
    break;
  case kCdScopeInvalid:
    // We should never get here
    abort();
  }
}

/// "isabsolutepath()" function
void f_isabsolutepath(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = path_is_absolute(tv_get_string(&argvars[0]));
}

/// "isdirectory()" function
void f_isdirectory(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = os_isdir(tv_get_string(&argvars[0]));
}

/// "mkdir()" function
void f_mkdir(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  int prot = 0755;

  rettv->vval.v_number = FAIL;
  if (check_secure()) {
    return;
  }

  char buf[NUMBUFLEN];
  const char *const dir = tv_get_string_buf(&argvars[0], buf);
  if (*dir == NUL) {
    return;
  }

  if (*path_tail(dir) == NUL) {
    // Remove trailing slashes.
    *path_tail_with_sep((char *)dir) = NUL;
  }

  bool defer = false;
  bool defer_recurse = false;
  char *created = NULL;
  if (argvars[1].v_type != VAR_UNKNOWN) {
    if (argvars[2].v_type != VAR_UNKNOWN) {
      prot = (int)tv_get_number_chk(&argvars[2], NULL);
      if (prot == -1) {
        return;
      }
    }
    const char *arg2 = tv_get_string(&argvars[1]);
    defer = vim_strchr(arg2, 'D') != NULL;
    defer_recurse = vim_strchr(arg2, 'R') != NULL;
    if ((defer || defer_recurse) && !can_add_defer()) {
      return;
    }

    if (vim_strchr(arg2, 'p') != NULL) {
      char *failed_dir;
      int ret = os_mkdir_recurse(dir, prot, &failed_dir,
                                 defer || defer_recurse ? &created : NULL);
      if (ret != 0) {
        semsg(_(e_mkdir), failed_dir, os_strerror(ret));
        xfree(failed_dir);
        rettv->vval.v_number = FAIL;
        return;
      }
      rettv->vval.v_number = OK;
    }
  }
  if (rettv->vval.v_number == FAIL) {
    rettv->vval.v_number = vim_mkdir_emsg(dir, prot);
  }

  // Handle "D" and "R": deferred deletion of the created directory.
  if (rettv->vval.v_number == OK
      && created == NULL && (defer || defer_recurse)) {
    created = FullName_save(dir, false);
  }
  if (created != NULL) {
    typval_T tv[2];
    tv[0].v_type = VAR_STRING;
    tv[0].v_lock = VAR_UNLOCKED;
    tv[0].vval.v_string = created;
    tv[1].v_type = VAR_STRING;
    tv[1].v_lock = VAR_UNLOCKED;
    tv[1].vval.v_string = xstrdup(defer_recurse ? "rf" : "d");
    add_defer("delete", 2, tv);
  }
}

/// "pathshorten()" function
void f_pathshorten(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  int trim_len = 1;

  if (argvars[1].v_type != VAR_UNKNOWN) {
    trim_len = (int)tv_get_number(&argvars[1]);
    if (trim_len < 1) {
      trim_len = 1;
    }
  }

  rettv->v_type = VAR_STRING;
  const char *p = tv_get_string_chk(&argvars[0]);
  if (p == NULL) {
    rettv->vval.v_string = NULL;
  } else {
    rettv->vval.v_string = xstrdup(p);
    shorten_dir_len(rettv->vval.v_string, trim_len);
  }
}

/// Evaluate "expr" (= "context") for readdir().
static varnumber_T readdir_checkitem(void *context, const char *name)
  FUNC_ATTR_NONNULL_ALL
{
  typval_T *expr = (typval_T *)context;
  typval_T argv[2];
  varnumber_T retval = 0;
  bool error = false;

  if (expr->v_type == VAR_UNKNOWN) {
    return 1;
  }

  typval_T save_val;
  prepare_vimvar(VV_VAL, &save_val);
  set_vim_var_string(VV_VAL, name, -1);
  argv[0].v_type = VAR_STRING;
  argv[0].vval.v_string = (char *)name;

  typval_T rettv;
  if (eval_expr_typval(expr, false, argv, 1, &rettv) == FAIL) {
    goto theend;
  }

  retval = tv_get_number_chk(&rettv, &error);
  if (error) {
    retval = -1;
  }

  tv_clear(&rettv);

theend:
  set_vim_var_string(VV_VAL, NULL, 0);
  restore_vimvar(VV_VAL, &save_val);
  return retval;
}

/// "readdir()" function
void f_readdir(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tv_list_alloc_ret(rettv, kListLenUnknown);

  const char *path = tv_get_string(&argvars[0]);
  typval_T *expr = &argvars[1];
  garray_T ga;
  int ret = readdir_core(&ga, path, (void *)expr, readdir_checkitem);
  if (ret == OK && ga.ga_len > 0) {
    for (int i = 0; i < ga.ga_len; i++) {
      const char *p = ((const char **)ga.ga_data)[i];
      tv_list_append_string(rettv->vval.v_list, p, -1);
    }
  }
  ga_clear_strings(&ga);
}

/// Read blob from file "fd".
/// Caller has allocated a blob in "rettv".
///
/// @param[in]  fd  File to read from.
/// @param[in,out]  rettv  Blob to write to.
/// @param[in]  offset  Read the file from the specified offset.
/// @param[in]  size  Read the specified size, or -1 if no limit.
///
/// @return  OK on success, or FAIL on failure.
static int read_blob(FILE *const fd, typval_T *rettv, off_T offset, off_T size_arg)
  FUNC_ATTR_NONNULL_ALL
{
  blob_T *const blob = rettv->vval.v_blob;
  FileInfo file_info;
  if (!os_fileinfo_fd(fileno(fd), &file_info)) {
    return FAIL;  // can't read the file, error
  }

  int whence;
  off_T size = size_arg;
  const off_T file_size = (off_T)os_fileinfo_size(&file_info);
  if (offset >= 0) {
    // The size defaults to the whole file.  If a size is given it is
    // limited to not go past the end of the file.
    if (size == -1 || (size > file_size - offset && !S_ISCHR(file_info.stat.st_mode))) {
      // size may become negative, checked below
      size = (off_T)os_fileinfo_size(&file_info) - offset;
    }
    whence = SEEK_SET;
  } else {
    // limit the offset to not go before the start of the file
    if (-offset > file_size && !S_ISCHR(file_info.stat.st_mode)) {
      offset = -file_size;
    }
    // Size defaults to reading until the end of the file.
    if (size == -1 || size > -offset) {
      size = -offset;
    }
    whence = SEEK_END;
  }
  if (size <= 0) {
    return OK;
  }
  if (offset != 0 && vim_fseek(fd, offset, whence) != 0) {
    return OK;
  }

  ga_grow(&blob->bv_ga, (int)size);
  blob->bv_ga.ga_len = (int)size;
  if (fread(blob->bv_ga.ga_data, 1, (size_t)blob->bv_ga.ga_len, fd)
      < (size_t)blob->bv_ga.ga_len) {
    // An empty blob is returned on error.
    tv_blob_free(rettv->vval.v_blob);
    rettv->vval.v_blob = NULL;
    return FAIL;
  }
  return OK;
}

/// "readfile()" or "readblob()" function
static void read_file_or_blob(typval_T *argvars, typval_T *rettv, bool always_blob)
{
  bool binary = false;
  bool blob = always_blob;
  FILE *fd;
  char buf[(IOSIZE/256) * 256];    // rounded to avoid odd + 1
  int io_size = sizeof(buf);
  char *prev = NULL;               // previously read bytes, if any
  ptrdiff_t prevlen = 0;               // length of data in prev
  ptrdiff_t prevsize = 0;               // size of prev buffer
  int64_t maxline = MAXLNUM;
  off_T offset = 0;
  off_T size = -1;

  if (argvars[1].v_type != VAR_UNKNOWN) {
    if (always_blob) {
      offset = (off_T)tv_get_number(&argvars[1]);
      if (argvars[2].v_type != VAR_UNKNOWN) {
        size = (off_T)tv_get_number(&argvars[2]);
      }
    } else {
      if (strcmp(tv_get_string(&argvars[1]), "b") == 0) {
        binary = true;
      } else if (strcmp(tv_get_string(&argvars[1]), "B") == 0) {
        blob = true;
      }
      if (argvars[2].v_type != VAR_UNKNOWN) {
        maxline = tv_get_number(&argvars[2]);
      }
    }
  }

  if (blob) {
    tv_blob_alloc_ret(rettv);
  } else {
    tv_list_alloc_ret(rettv, kListLenUnknown);
  }

  // Always open the file in binary mode, library functions have a mind of
  // their own about CR-LF conversion.
  const char *const fname = tv_get_string(&argvars[0]);

  if (os_isdir(fname)) {
    semsg(_(e_isadir2), fname);
    return;
  }
  if (*fname == NUL || (fd = os_fopen(fname, READBIN)) == NULL) {
    semsg(_(e_notopen), *fname == NUL ? _("<empty>") : fname);
    return;
  }

  if (blob) {
    if (read_blob(fd, rettv, offset, size) == FAIL) {
      semsg(_(e_notread), fname);
    }
    fclose(fd);
    return;
  }

  list_T *const l = rettv->vval.v_list;

  while (maxline < 0 || tv_list_len(l) < maxline) {
    int readlen = (int)fread(buf, 1, (size_t)io_size, fd);

    // This for loop processes what was read, but is also entered at end
    // of file so that either:
    // - an incomplete line gets written
    // - a "binary" file gets an empty line at the end if it ends in a
    //   newline.
    char *p;  // Position in buf.
    char *start;  // Start of current line.
    for (p = buf, start = buf;
         p < buf + readlen || (readlen <= 0 && (prevlen > 0 || binary));
         p++) {
      if (readlen <= 0 || *p == '\n') {
        char *s = NULL;
        size_t len = (size_t)(p - start);

        // Finished a line.  Remove CRs before NL.
        if (readlen > 0 && !binary) {
          while (len > 0 && start[len - 1] == '\r') {
            len--;
          }
          // removal may cross back to the "prev" string
          if (len == 0) {
            while (prevlen > 0 && prev[prevlen - 1] == '\r') {
              prevlen--;
            }
          }
        }
        if (prevlen == 0) {
          assert(len < INT_MAX);
          s = xmemdupz(start, len);
        } else {
          // Change "prev" buffer to be the right size.  This way
          // the bytes are only copied once, and very long lines are
          // allocated only once.
          s = xrealloc(prev, (size_t)prevlen + len + 1);
          memcpy(s + prevlen, start, len);
          s[(size_t)prevlen + len] = NUL;
          prev = NULL;             // the list will own the string
          prevlen = prevsize = 0;
        }

        tv_list_append_owned_tv(l, (typval_T) {
          .v_type = VAR_STRING,
          .v_lock = VAR_UNLOCKED,
          .vval.v_string = s,
        });

        start = p + 1;  // Step over newline.
        if (maxline < 0) {
          if (tv_list_len(l) > -maxline) {
            assert(tv_list_len(l) == 1 + (-maxline));
            tv_list_item_remove(l, tv_list_first(l));
          }
        } else if (tv_list_len(l) >= maxline) {
          assert(tv_list_len(l) == maxline);
          break;
        }
        if (readlen <= 0) {
          break;
        }
      } else if (*p == NUL) {
        *p = '\n';
        // Check for utf8 "bom"; U+FEFF is encoded as EF BB BF.  Do this
        // when finding the BF and check the previous two bytes.
      } else if ((uint8_t)(*p) == 0xbf && !binary) {
        // Find the two bytes before the 0xbf.  If p is at buf, or buf + 1,
        // these may be in the "prev" string.
        char back1 = p >= buf + 1 ? p[-1]
                                  : prevlen >= 1 ? prev[prevlen - 1] : NUL;
        char back2 = p >= buf + 2 ? p[-2]
                                  : (p == buf + 1 && prevlen >= 1
                                     ? prev[prevlen - 1]
                                     : prevlen >= 2 ? prev[prevlen - 2] : NUL);

        if ((uint8_t)back2 == 0xef && (uint8_t)back1 == 0xbb) {
          char *dest = p - 2;

          // Usually a BOM is at the beginning of a file, and so at
          // the beginning of a line; then we can just step over it.
          if (start == dest) {
            start = p + 1;
          } else {
            // have to shuffle buf to close gap
            int adjust_prevlen = 0;

            if (dest < buf) {
              // adjust_prevlen must be 1 or 2.
              adjust_prevlen = (int)(buf - dest);
              dest = buf;
            }
            if (readlen > p - buf + 1) {
              memmove(dest, p + 1, (size_t)readlen - (size_t)(p - buf) - 1);
            }
            readlen -= 3 - adjust_prevlen;
            prevlen -= adjust_prevlen;
            p = dest - 1;
          }
        }
      }
    }     // for

    if ((maxline >= 0 && tv_list_len(l) >= maxline) || readlen <= 0) {
      break;
    }
    if (start < p) {
      // There's part of a line in buf, store it in "prev".
      if (p - start + prevlen >= prevsize) {
        // A common use case is ordinary text files and "prev" gets a
        // fragment of a line, so the first allocation is made
        // small, to avoid repeatedly 'allocing' large and
        // 'reallocing' small.
        if (prevsize == 0) {
          prevsize = p - start;
        } else {
          ptrdiff_t grow50pc = (prevsize * 3) / 2;
          ptrdiff_t growmin = (p - start) * 2 + prevlen;
          prevsize = grow50pc > growmin ? grow50pc : growmin;
        }
        prev = xrealloc(prev, (size_t)prevsize);
      }
      // Add the line part to end of "prev".
      memmove(prev + prevlen, start, (size_t)(p - start));
      prevlen += p - start;
    }
  }   // while

  xfree(prev);
  fclose(fd);
}

/// "readblob()" function
void f_readblob(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  read_file_or_blob(argvars, rettv, true);
}

/// "readfile()" function
void f_readfile(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  read_file_or_blob(argvars, rettv, false);
}

/// "rename({from}, {to})" function
void f_rename(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (check_secure()) {
    rettv->vval.v_number = -1;
  } else {
    char buf[NUMBUFLEN];
    rettv->vval.v_number = vim_rename(tv_get_string(&argvars[0]),
                                      tv_get_string_buf(&argvars[1], buf));
  }
}

/// "resolve()" function
void f_resolve(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->v_type = VAR_STRING;
  const char *fname = tv_get_string(&argvars[0]);
#ifdef MSWIN
  char *v = os_resolve_shortcut(fname);
  if (v == NULL) {
    if (os_is_reparse_point_include(fname)) {
      v = os_realpath(fname, NULL, MAXPATHL + 1);
    }
  }
  rettv->vval.v_string = (v == NULL ? xstrdup(fname) : v);
#else
# ifdef HAVE_READLINK
  {
    bool is_relative_to_current = false;
    bool has_trailing_pathsep = false;
    int limit = 100;

    char *p = xstrdup(fname);

    if (p[0] == '.' && (vim_ispathsep(p[1])
                        || (p[1] == '.' && (vim_ispathsep(p[2]))))) {
      is_relative_to_current = true;
    }

    ptrdiff_t len = (ptrdiff_t)strlen(p);
    if (len > 1 && after_pathsep(p, p + len)) {
      has_trailing_pathsep = true;
      p[len - 1] = NUL;  // The trailing slash breaks readlink().
    }

    char *q = (char *)path_next_component(p);
    char *remain = NULL;
    if (*q != NUL) {
      // Separate the first path component in "p", and keep the
      // remainder (beginning with the path separator).
      remain = xstrdup(q - 1);
      q[-1] = NUL;
    }

    char *const buf = xmallocz(MAXPATHL);

    char *cpy;
    while (true) {
      while (true) {
        len = readlink(p, buf, MAXPATHL);
        if (len <= 0) {
          break;
        }
        buf[len] = NUL;

        if (limit-- == 0) {
          xfree(p);
          xfree(remain);
          emsg(_("E655: Too many symbolic links (cycle?)"));
          rettv->vval.v_string = NULL;
          xfree(buf);
          return;
        }

        // Ensure that the result will have a trailing path separator
        // if the argument has one.
        if (remain == NULL && has_trailing_pathsep) {
          add_pathsep(buf);
        }

        // Separate the first path component in the link value and
        // concatenate the remainders.
        q = (char *)path_next_component(vim_ispathsep(*buf) ? buf + 1 : buf);
        if (*q != NUL) {
          cpy = remain;
          remain = remain != NULL ? concat_str(q - 1, remain) : xstrdup(q - 1);
          xfree(cpy);
          q[-1] = NUL;
        }

        q = path_tail(p);
        if (q > p && *q == NUL) {
          // Ignore trailing path separator.
          p[q - p - 1] = NUL;
          q = path_tail(p);
        }
        if (q > p && !path_is_absolute(buf)) {
          // Symlink is relative to directory of argument. Replace the
          // symlink with the resolved name in the same directory.
          const size_t p_len = strlen(p);
          const size_t buf_len = strlen(buf);
          p = xrealloc(p, p_len + buf_len + 1);
          memcpy(path_tail(p), buf, buf_len + 1);
        } else {
          xfree(p);
          p = xstrdup(buf);
        }
      }

      if (remain == NULL) {
        break;
      }

      // Append the first path component of "remain" to "p".
      q = (char *)path_next_component(remain + 1);
      len = q - remain - (*q != NUL);
      const size_t p_len = strlen(p);
      cpy = xmallocz(p_len + (size_t)len);
      memcpy(cpy, p, p_len + 1);
      xstrlcat(cpy + p_len, remain, (size_t)len + 1);
      xfree(p);
      p = cpy;

      // Shorten "remain".
      if (*q != NUL) {
        STRMOVE(remain, q - 1);
      } else {
        XFREE_CLEAR(remain);
      }
    }

    // If the result is a relative path name, make it explicitly relative to
    // the current directory if and only if the argument had this form.
    if (!vim_ispathsep(*p)) {
      if (is_relative_to_current
          && *p != NUL
          && !(p[0] == '.'
               && (p[1] == NUL
                   || vim_ispathsep(p[1])
                   || (p[1] == '.'
                       && (p[2] == NUL
                           || vim_ispathsep(p[2])))))) {
        // Prepend "./".
        cpy = concat_str("./", p);
        xfree(p);
        p = cpy;
      } else if (!is_relative_to_current) {
        // Strip leading "./".
        q = p;
        while (q[0] == '.' && vim_ispathsep(q[1])) {
          q += 2;
        }
        if (q > p) {
          STRMOVE(p, p + 2);
        }
      }
    }

    // Ensure that the result will have no trailing path separator
    // if the argument had none.  But keep "/" or "//".
    if (!has_trailing_pathsep) {
      q = p + strlen(p);
      if (after_pathsep(p, q)) {
        *path_tail_with_sep(p) = NUL;
      }
    }

    rettv->vval.v_string = p;
    xfree(buf);
  }
# else
  char *v = os_realpath(fname, NULL, MAXPATHL + 1);
  rettv->vval.v_string = v == NULL ? xstrdup(fname) : v;
# endif
#endif

  simplify_filename(rettv->vval.v_string);
}

/// "simplify()" function
void f_simplify(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *const p = tv_get_string(&argvars[0]);
  rettv->vval.v_string = xstrdup(p);
  simplify_filename(rettv->vval.v_string);  // Simplify in place.
  rettv->v_type = VAR_STRING;
}

/// "tempname()" function
void f_tempname(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = vim_tempname();
}

/// Write "list" of strings to file "fd".
///
/// @param  fp  File to write to.
/// @param[in]  list  List to write.
/// @param[in]  binary  Whether to write in binary mode.
///
/// @return true in case of success, false otherwise.
static bool write_list(FileDescriptor *const fp, const list_T *const list, const bool binary)
  FUNC_ATTR_NONNULL_ARG(1)
{
  int error = 0;
  TV_LIST_ITER_CONST(list, li, {
    const char *const s = tv_get_string_chk(TV_LIST_ITEM_TV(li));
    if (s == NULL) {
      return false;
    }
    const char *hunk_start = s;
    for (const char *p = hunk_start;; p++) {
      if (*p == NUL || *p == NL) {
        if (p != hunk_start) {
          const ptrdiff_t written = file_write(fp, hunk_start,
                                               (size_t)(p - hunk_start));
          if (written < 0) {
            error = (int)written;
            goto write_list_error;
          }
        }
        if (*p == NUL) {
          break;
        } else {
          hunk_start = p + 1;
          const ptrdiff_t written = file_write(fp, (char[]){ NUL }, 1);
          if (written < 0) {
            error = (int)written;
            break;
          }
        }
      }
    }
    if (!binary || TV_LIST_ITEM_NEXT(list, li) != NULL) {
      const ptrdiff_t written = file_write(fp, "\n", 1);
      if (written < 0) {
        error = (int)written;
        goto write_list_error;
      }
    }
  });
  if ((error = file_flush(fp)) != 0) {
    goto write_list_error;
  }
  return true;
write_list_error:
  semsg(_(e_error_while_writing_str), os_strerror(error));
  return false;
}

/// Write a blob to file with descriptor `fp`.
///
/// @param[in]  fp  File to write to.
/// @param[in]  blob  Blob to write.
///
/// @return true on success, or false on failure.
static bool write_blob(FileDescriptor *const fp, const blob_T *const blob)
  FUNC_ATTR_NONNULL_ARG(1)
{
  int error = 0;
  const int len = tv_blob_len(blob);
  if (len > 0) {
    const ptrdiff_t written = file_write(fp, blob->bv_ga.ga_data, (size_t)len);
    if (written < (ptrdiff_t)len) {
      error = (int)written;
      goto write_blob_error;
    }
  }
  error = file_flush(fp);
  if (error != 0) {
    goto write_blob_error;
  }
  return true;
write_blob_error:
  semsg(_(e_error_while_writing_str), os_strerror(error));
  return false;
}

/// "writefile()" function
void f_writefile(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = -1;

  if (check_secure()) {
    return;
  }

  if (argvars[0].v_type == VAR_LIST) {
    TV_LIST_ITER_CONST(argvars[0].vval.v_list, li, {
      if (!tv_check_str_or_nr(TV_LIST_ITEM_TV(li))) {
        return;
      }
    });
  } else if (argvars[0].v_type != VAR_BLOB) {
    semsg(_(e_invarg2),
          _("writefile() first argument must be a List or a Blob"));
    return;
  }

  bool binary = false;
  bool append = false;
  bool defer = false;
  bool do_fsync = !!p_fs;
  bool mkdir_p = false;
  if (argvars[2].v_type != VAR_UNKNOWN) {
    const char *const flags = tv_get_string_chk(&argvars[2]);
    if (flags == NULL) {
      return;
    }
    for (const char *p = flags; *p; p++) {
      switch (*p) {
      case 'b':
        binary = true; break;
      case 'a':
        append = true; break;
      case 'D':
        defer = true; break;
      case 's':
        do_fsync = true; break;
      case 'S':
        do_fsync = false; break;
      case 'p':
        mkdir_p = true; break;
      default:
        // Using %s, p and not %c, *p to preserve multibyte characters
        semsg(_("E5060: Unknown flag: %s"), p);
        return;
      }
    }
  }

  char buf[NUMBUFLEN];
  const char *const fname = tv_get_string_buf_chk(&argvars[1], buf);
  if (fname == NULL) {
    return;
  }

  if (defer && !can_add_defer()) {
    return;
  }

  FileDescriptor fp;
  int error;
  if (*fname == NUL) {
    emsg(_("E482: Can't open file with an empty name"));
  } else if ((error = file_open(&fp, fname,
                                ((append ? kFileAppend : kFileTruncate)
                                 | (mkdir_p ? kFileMkDir : kFileCreate)
                                 | kFileCreate), 0666)) != 0) {
    semsg(_("E482: Can't open file %s for writing: %s"), fname, os_strerror(error));
  } else {
    if (defer) {
      typval_T tv = {
        .v_type = VAR_STRING,
        .v_lock = VAR_UNLOCKED,
        .vval.v_string = FullName_save(fname, false),
      };
      add_defer("delete", 1, &tv);
    }

    bool write_ok;
    if (argvars[0].v_type == VAR_BLOB) {
      write_ok = write_blob(&fp, argvars[0].vval.v_blob);
    } else {
      write_ok = write_list(&fp, argvars[0].vval.v_list, binary);
    }
    if (write_ok) {
      rettv->vval.v_number = 0;
    }
    if ((error = file_close(&fp, do_fsync)) != 0) {
      semsg(_("E80: Error when closing file %s: %s"),
            fname, os_strerror(error));
    }
  }
}
