// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// @file ex_cmds2.c
///
/// Some more functions for command line commands

#include <assert.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/ascii.h"
#include "nvim/autocmd.h"
#include "nvim/globals.h"
#include "nvim/vim.h"
#ifdef HAVE_LOCALE_H
# include <locale.h>
#endif
#include "nvim/buffer.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/eval/vars.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/os/fs_defs.h"
#include "nvim/os/shell.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/runtime.h"
#include "nvim/strings.h"
#include "nvim/undo.h"
#include "nvim/version.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_cmds2.c.generated.h"
#endif

void ex_ruby(exarg_T *eap)
{
  script_host_execute("ruby", eap);
}

void ex_rubyfile(exarg_T *eap)
{
  script_host_execute_file("ruby", eap);
}

void ex_rubydo(exarg_T *eap)
{
  script_host_do_range("ruby", eap);
}

void ex_python3(exarg_T *eap)
{
  script_host_execute("python3", eap);
}

void ex_py3file(exarg_T *eap)
{
  script_host_execute_file("python3", eap);
}

void ex_pydo3(exarg_T *eap)
{
  script_host_do_range("python3", eap);
}

void ex_perl(exarg_T *eap)
{
  script_host_execute("perl", eap);
}

void ex_perlfile(exarg_T *eap)
{
  script_host_execute_file("perl", eap);
}

void ex_perldo(exarg_T *eap)
{
  script_host_do_range("perl", eap);
}

/// If 'autowrite' option set, try to write the file.
/// Careful: autocommands may make "buf" invalid!
///
/// @return FAIL for failure, OK otherwise
int autowrite(buf_T *buf, int forceit)
{
  int r;
  bufref_T bufref;

  if (!(p_aw || p_awa) || !p_write
      // never autowrite a "nofile" or "nowrite" buffer
      || bt_dontwrite(buf)
      || (!forceit && buf->b_p_ro) || buf->b_ffname == NULL) {
    return FAIL;
  }
  set_bufref(&bufref, buf);
  r = buf_write_all(buf, forceit);

  // Writing may succeed but the buffer still changed, e.g., when there is a
  // conversion error.  We do want to return FAIL then.
  if (bufref_valid(&bufref) && bufIsChanged(buf)) {
    r = FAIL;
  }
  return r;
}

/// Flush all buffers, except the ones that are readonly or are never written.
void autowrite_all(void)
{
  if (!(p_aw || p_awa) || !p_write) {
    return;
  }

  FOR_ALL_BUFFERS(buf) {
    if (bufIsChanged(buf) && !buf->b_p_ro && !bt_dontwrite(buf)) {
      bufref_T bufref;
      set_bufref(&bufref, buf);
      (void)buf_write_all(buf, false);
      // an autocommand may have deleted the buffer
      if (!bufref_valid(&bufref)) {
        buf = firstbuf;
      }
    }
  }
}

/// @return  true if buffer was changed and cannot be abandoned.
/// For flags use the CCGD_ values.
bool check_changed(buf_T *buf, int flags)
{
  int forceit = (flags & CCGD_FORCEIT);
  bufref_T bufref;
  set_bufref(&bufref, buf);

  if (!forceit
      && bufIsChanged(buf)
      && ((flags & CCGD_MULTWIN) || buf->b_nwindows <= 1)
      && (!(flags & CCGD_AW) || autowrite(buf, forceit) == FAIL)) {
    if ((p_confirm || (cmdmod.cmod_flags & CMOD_CONFIRM)) && p_write) {
      int count = 0;

      if (flags & CCGD_ALLBUF) {
        FOR_ALL_BUFFERS(buf2) {
          if (bufIsChanged(buf2) && (buf2->b_ffname != NULL)) {
            count++;
          }
        }
      }
      if (!bufref_valid(&bufref)) {
        // Autocommand deleted buffer, oops!  It's not changed now.
        return false;
      }
      dialog_changed(buf, count > 1);
      if (!bufref_valid(&bufref)) {
        // Autocommand deleted buffer, oops!  It's not changed now.
        return false;
      }
      return bufIsChanged(buf);
    }
    if (flags & CCGD_EXCMD) {
      no_write_message();
    } else {
      no_write_message_nobang(curbuf);
    }
    return true;
  }
  return false;
}

/// Ask the user what to do when abandoning a changed buffer.
/// Must check 'write' option first!
///
/// @param buf
/// @param checkall may abandon all changed buffers
void dialog_changed(buf_T *buf, bool checkall)
{
  char buff[DIALOG_MSG_SIZE];
  int ret;
  // Init ea pseudo-structure, this is needed for the check_overwrite()
  // function.
  exarg_T ea = {
    .append = false,
    .forceit = false,
  };

  dialog_msg((char *)buff, _("Save changes to \"%s\"?"), buf->b_fname);
  if (checkall) {
    ret = vim_dialog_yesnoallcancel(VIM_QUESTION, NULL, (char_u *)buff, 1);
  } else {
    ret = vim_dialog_yesnocancel(VIM_QUESTION, NULL, (char_u *)buff, 1);
  }

  if (ret == VIM_YES) {
    if (buf->b_fname != NULL
        && check_overwrite(&ea, buf, buf->b_fname, buf->b_ffname, false) == OK) {
      // didn't hit Cancel
      (void)buf_write_all(buf, false);
    }
  } else if (ret == VIM_NO) {
    unchanged(buf, true, false);
  } else if (ret == VIM_ALL) {
    // Write all modified files that can be written.
    // Skip readonly buffers, these need to be confirmed
    // individually.
    FOR_ALL_BUFFERS(buf2) {
      if (bufIsChanged(buf2) && (buf2->b_ffname != NULL) && !buf2->b_p_ro) {
        bufref_T bufref;
        set_bufref(&bufref, buf2);

        if (buf2->b_fname != NULL
            && check_overwrite(&ea, buf2, buf2->b_fname, buf2->b_ffname, false) == OK) {
          // didn't hit Cancel
          (void)buf_write_all(buf2, false);
        }
        // an autocommand may have deleted the buffer
        if (!bufref_valid(&bufref)) {
          buf2 = firstbuf;
        }
      }
    }
  } else if (ret == VIM_DISCARDALL) {
    // mark all buffers as unchanged
    FOR_ALL_BUFFERS(buf2) {
      unchanged(buf2, true, false);
    }
  }
}

/// Ask the user whether to close the terminal buffer or not.
///
/// @param buf The terminal buffer.
/// @return bool Whether to close the buffer or not.
bool dialog_close_terminal(buf_T *buf)
{
  char buff[DIALOG_MSG_SIZE];

  dialog_msg(buff, _("Close \"%s\"?"),
             (buf->b_fname != NULL) ? buf->b_fname : "?");

  int ret = vim_dialog_yesnocancel(VIM_QUESTION, NULL, (char_u *)buff, 1);

  return ret == VIM_YES;
}

/// @return true if the buffer "buf" can be abandoned, either by making it
/// hidden, autowriting it or unloading it.
bool can_abandon(buf_T *buf, int forceit)
{
  return buf_hide(buf)
         || !bufIsChanged(buf)
         || buf->b_nwindows > 1
         || autowrite(buf, forceit) == OK
         || forceit;
}

/// Add a buffer number to "bufnrs", unless it's already there.
static void add_bufnum(int *bufnrs, int *bufnump, int nr)
{
  int i;

  for (i = 0; i < *bufnump; i++) {
    if (bufnrs[i] == nr) {
      return;
    }
  }
  bufnrs[*bufnump] = nr;
  *bufnump = *bufnump + 1;
}

/// Check if any buffer was changed and cannot be abandoned.
/// That changed buffer becomes the current buffer.
/// When "unload" is true the current buffer is unloaded instead of making it
/// hidden.  This is used for ":q!".
///
/// @param[in] hidden specifies whether to check only hidden buffers.
/// @param[in] unload specifies whether to unload, instead of hide, the buffer.
///
/// @returns          true if any buffer is changed and cannot be abandoned
bool check_changed_any(bool hidden, bool unload)
{
  bool ret = false;
  int save;
  int i;
  int bufnum = 0;
  size_t bufcount = 0;
  int *bufnrs;

  // Make a list of all buffers, with the most important ones first.
  FOR_ALL_BUFFERS(buf) {
    bufcount++;
  }

  if (bufcount == 0) {
    return false;
  }

  bufnrs = xmalloc(sizeof(*bufnrs) * bufcount);

  // curbuf
  bufnrs[bufnum++] = curbuf->b_fnum;

  // buffers in current tab
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer != curbuf) {
      add_bufnum(bufnrs, &bufnum, wp->w_buffer->b_fnum);
    }
  }

  // buffers in other tabs
  FOR_ALL_TABS(tp) {
    if (tp != curtab) {
      FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
        add_bufnum(bufnrs, &bufnum, wp->w_buffer->b_fnum);
      }
    }
  }

  // any other buffer
  FOR_ALL_BUFFERS(buf) {
    add_bufnum(bufnrs, &bufnum, buf->b_fnum);
  }

  buf_T *buf = NULL;
  for (i = 0; i < bufnum; i++) {
    buf = buflist_findnr(bufnrs[i]);
    if (buf == NULL) {
      continue;
    }
    if ((!hidden || buf->b_nwindows == 0) && bufIsChanged(buf)) {
      bufref_T bufref;
      set_bufref(&bufref, buf);

      // Try auto-writing the buffer.  If this fails but the buffer no
      // longer exists it's not changed, that's OK.
      if (check_changed(buf, (p_awa ? CCGD_AW : 0)
                        | CCGD_MULTWIN
                        | CCGD_ALLBUF) && bufref_valid(&bufref)) {
        break;    // didn't save - still changes
      }
    }
  }

  if (i >= bufnum) {
    goto theend;
  }

  // Get here if "buf" cannot be abandoned.
  ret = true;
  exiting = false;
  // When ":confirm" used, don't give an error message.
  if (!(p_confirm || (cmdmod.cmod_flags & CMOD_CONFIRM))) {
    // There must be a wait_return for this message, do_buffer()
    // may cause a redraw.  But wait_return() is a no-op when vgetc()
    // is busy (Quit used from window menu), then make sure we don't
    // cause a scroll up.
    if (vgetc_busy > 0) {
      msg_row = cmdline_row;
      msg_col = 0;
      msg_didout = false;
    }
    if ((buf->terminal && channel_job_running((uint64_t)buf->b_p_channel))
        ? semsg(_("E947: Job still running in buffer \"%s\""), buf->b_fname)
        : semsg(_("E162: No write since last change for buffer \"%s\""),
                buf_spname(buf) != NULL ? buf_spname(buf) : buf->b_fname)) {
      save = no_wait_return;
      no_wait_return = false;
      wait_return(false);
      no_wait_return = save;
    }
  }

  // Try to find a window that contains the buffer.
  if (buf != curbuf) {
    FOR_ALL_TAB_WINDOWS(tp, wp) {
      if (wp->w_buffer == buf) {
        bufref_T bufref;
        set_bufref(&bufref, buf);
        goto_tabpage_win(tp, wp);
        // Paranoia: did autocmds wipe out the buffer with changes?
        if (!bufref_valid(&bufref)) {
          goto theend;
        }
        goto buf_found;
      }
    }
  }
buf_found:

  // Open the changed buffer in the current window.
  if (buf != curbuf) {
    set_curbuf(buf, unload ? DOBUF_UNLOAD : DOBUF_GOTO);
  }

theend:
  xfree(bufnrs);
  return ret;
}

/// @return  FAIL if there is no file name, OK if there is one.
///          Give error message for FAIL.
int check_fname(void)
{
  if (curbuf->b_ffname == NULL) {
    emsg(_(e_noname));
    return FAIL;
  }
  return OK;
}

/// Flush the contents of a buffer, unless it has no file name.
///
/// @return  FAIL for failure, OK otherwise
int buf_write_all(buf_T *buf, int forceit)
{
  int retval;
  buf_T *old_curbuf = curbuf;

  retval = (buf_write(buf, buf->b_ffname, buf->b_fname,
                      (linenr_T)1, buf->b_ml.ml_line_count, NULL,
                      false, forceit, true, false));
  if (curbuf != old_curbuf) {
    msg_source(HL_ATTR(HLF_W));
    msg(_("Warning: Entered other buffer unexpectedly (check autocommands)"));
  }
  return retval;
}

/// Code to handle the argument list.

#define AL_SET  1
#define AL_ADD  2
#define AL_DEL  3

/// Isolate one argument, taking backticks.
/// Changes the argument in-place, puts a NUL after it.  Backticks remain.
///
/// @return  a pointer to the start of the next argument.
static char *do_one_arg(char *str)
{
  char *p;
  bool inbacktick;

  inbacktick = false;
  for (p = str; *str; str++) {
    // When the backslash is used for escaping the special meaning of a
    // character we need to keep it until wildcard expansion.
    if (rem_backslash((char_u *)str)) {
      *p++ = *str++;
      *p++ = *str;
    } else {
      // An item ends at a space not in backticks
      if (!inbacktick && ascii_isspace(*str)) {
        break;
      }
      if (*str == '`') {
        inbacktick ^= true;
      }
      *p++ = *str;
    }
  }
  str = skipwhite(str);
  *p = NUL;

  return str;
}

/// Separate the arguments in "str" and return a list of pointers in the
/// growarray "gap".
static void get_arglist(garray_T *gap, char *str, int escaped)
{
  ga_init(gap, (int)sizeof(char_u *), 20);
  while (*str != NUL) {
    GA_APPEND(char *, gap, str);

    // If str is escaped, don't handle backslashes or spaces
    if (!escaped) {
      return;
    }

    // Isolate one argument, change it in-place, put a NUL after it.
    str = do_one_arg(str);
  }
}

/// Parse a list of arguments (file names), expand them and return in
/// "fnames[fcountp]".  When "wig" is true, removes files matching 'wildignore'.
///
/// @return  FAIL or OK.
int get_arglist_exp(char_u *str, int *fcountp, char ***fnamesp, bool wig)
{
  garray_T ga;
  int i;

  get_arglist(&ga, (char *)str, true);

  if (wig) {
    i = expand_wildcards(ga.ga_len, ga.ga_data,
                         fcountp, fnamesp, EW_FILE|EW_NOTFOUND|EW_NOTWILD);
  } else {
    i = gen_expand_wildcards(ga.ga_len, ga.ga_data,
                             fcountp, fnamesp, EW_FILE|EW_NOTFOUND|EW_NOTWILD);
  }

  ga_clear(&ga);
  return i;
}

/// @param str
/// @param what
///         AL_SET: Redefine the argument list to 'str'.
///         AL_ADD: add files in 'str' to the argument list after "after".
///         AL_DEL: remove files in 'str' from the argument list.
/// @param after
///         0 means before first one
/// @param will_edit  will edit added argument
///
/// @return  FAIL for failure, OK otherwise.
static int do_arglist(char *str, int what, int after, bool will_edit)
  FUNC_ATTR_NONNULL_ALL
{
  garray_T new_ga;
  int exp_count;
  char **exp_files;
  char *p;
  int match;
  int arg_escaped = true;

  // Set default argument for ":argadd" command.
  if (what == AL_ADD && *str == NUL) {
    if (curbuf->b_ffname == NULL) {
      return FAIL;
    }
    str = curbuf->b_fname;
    arg_escaped = false;
  }

  // Collect all file name arguments in "new_ga".
  get_arglist(&new_ga, str, arg_escaped);

  if (what == AL_DEL) {
    regmatch_T regmatch;
    bool didone;

    // Delete the items: use each item as a regexp and find a match in the
    // argument list.
    regmatch.rm_ic = p_fic;     // ignore case when 'fileignorecase' is set
    for (int i = 0; i < new_ga.ga_len && !got_int; i++) {
      p = ((char **)new_ga.ga_data)[i];
      p = file_pat_to_reg_pat(p, NULL, NULL, false);
      if (p == NULL) {
        break;
      }
      regmatch.regprog = vim_regcomp(p, p_magic ? RE_MAGIC : 0);
      if (regmatch.regprog == NULL) {
        xfree(p);
        break;
      }

      didone = false;
      for (match = 0; match < ARGCOUNT; match++) {
        if (vim_regexec(&regmatch, alist_name(&ARGLIST[match]), (colnr_T)0)) {
          didone = true;
          xfree(ARGLIST[match].ae_fname);
          memmove(ARGLIST + match, ARGLIST + match + 1,
                  (size_t)(ARGCOUNT - match - 1) * sizeof(aentry_T));
          ALIST(curwin)->al_ga.ga_len--;
          if (curwin->w_arg_idx > match) {
            curwin->w_arg_idx--;
          }
          match--;
        }
      }

      vim_regfree(regmatch.regprog);
      xfree(p);
      if (!didone) {
        semsg(_(e_nomatch2), ((char_u **)new_ga.ga_data)[i]);
      }
    }
    ga_clear(&new_ga);
  } else {
    int i = expand_wildcards(new_ga.ga_len, new_ga.ga_data,
                             &exp_count, &exp_files,
                             EW_DIR|EW_FILE|EW_ADDSLASH|EW_NOTFOUND);
    ga_clear(&new_ga);
    if (i == FAIL || exp_count == 0) {
      emsg(_(e_nomatch));
      return FAIL;
    }

    if (what == AL_ADD) {
      alist_add_list(exp_count, exp_files, after, will_edit);
      xfree(exp_files);
    } else {
      assert(what == AL_SET);
      alist_set(ALIST(curwin), exp_count, exp_files, will_edit, NULL, 0);
    }
  }

  alist_check_arg_idx();

  return OK;
}

/// Check the validity of the arg_idx for each other window.
static void alist_check_arg_idx(void)
{
  FOR_ALL_TAB_WINDOWS(tp, win) {
    if (win->w_alist == curwin->w_alist) {
      check_arg_idx(win);
    }
  }
}

/// @return  true if window "win" is editing the file at the current argument
///          index.
static bool editing_arg_idx(win_T *win)
{
  return !(win->w_arg_idx >= WARGCOUNT(win)
           || (win->w_buffer->b_fnum
               != WARGLIST(win)[win->w_arg_idx].ae_fnum
               && (win->w_buffer->b_ffname == NULL
                   || !(path_full_compare(alist_name(&WARGLIST(win)[win->w_arg_idx]),
                                          win->w_buffer->b_ffname, true,
                                          true) & kEqualFiles))));
}

/// Check if window "win" is editing the w_arg_idx file in its argument list.
void check_arg_idx(win_T *win)
{
  if (WARGCOUNT(win) > 1 && !editing_arg_idx(win)) {
    // We are not editing the current entry in the argument list.
    // Set "arg_had_last" if we are editing the last one.
    win->w_arg_idx_invalid = true;
    if (win->w_arg_idx != WARGCOUNT(win) - 1
        && arg_had_last == false
        && ALIST(win) == &global_alist
        && GARGCOUNT > 0
        && win->w_arg_idx < GARGCOUNT
        && (win->w_buffer->b_fnum == GARGLIST[GARGCOUNT - 1].ae_fnum
            || (win->w_buffer->b_ffname != NULL
                && (path_full_compare(alist_name(&GARGLIST[GARGCOUNT - 1]),
                                      win->w_buffer->b_ffname, true, true)
                    & kEqualFiles)))) {
      arg_had_last = true;
    }
  } else {
    // We are editing the current entry in the argument list.
    // Set "arg_had_last" if it's also the last one
    win->w_arg_idx_invalid = false;
    if (win->w_arg_idx == WARGCOUNT(win) - 1 && win->w_alist == &global_alist) {
      arg_had_last = true;
    }
  }
}

/// ":args", ":argslocal" and ":argsglobal".
void ex_args(exarg_T *eap)
{
  if (eap->cmdidx != CMD_args) {
    alist_unlink(ALIST(curwin));
    if (eap->cmdidx == CMD_argglobal) {
      ALIST(curwin) = &global_alist;
    } else {     // eap->cmdidx == CMD_arglocal
      alist_new();
    }
  }

  if (*eap->arg != NUL) {
    // ":args file ..": define new argument list, handle like ":next"
    // Also for ":argslocal file .." and ":argsglobal file ..".
    ex_next(eap);
  } else if (eap->cmdidx == CMD_args) {
    // ":args": list arguments.
    if (ARGCOUNT > 0) {
      char **items = xmalloc(sizeof(char_u *) * (size_t)ARGCOUNT);
      // Overwrite the command, for a short list there is no scrolling
      // required and no wait_return().
      gotocmdline(true);
      for (int i = 0; i < ARGCOUNT; i++) {
        items[i] = alist_name(&ARGLIST[i]);
      }
      list_in_columns(items, ARGCOUNT, curwin->w_arg_idx);
      xfree(items);
    }
  } else if (eap->cmdidx == CMD_arglocal) {
    garray_T *gap = &curwin->w_alist->al_ga;

    // ":argslocal": make a local copy of the global argument list.
    ga_grow(gap, GARGCOUNT);
    for (int i = 0; i < GARGCOUNT; i++) {
      if (GARGLIST[i].ae_fname != NULL) {
        AARGLIST(curwin->w_alist)[gap->ga_len].ae_fname =
          vim_strsave(GARGLIST[i].ae_fname);
        AARGLIST(curwin->w_alist)[gap->ga_len].ae_fnum =
          GARGLIST[i].ae_fnum;
        gap->ga_len++;
      }
    }
  }
}

/// ":previous", ":sprevious", ":Next" and ":sNext".
void ex_previous(exarg_T *eap)
{
  // If past the last one already, go to the last one.
  if (curwin->w_arg_idx - (int)eap->line2 >= ARGCOUNT) {
    do_argfile(eap, ARGCOUNT - 1);
  } else {
    do_argfile(eap, curwin->w_arg_idx - (int)eap->line2);
  }
}

/// ":rewind", ":first", ":sfirst" and ":srewind".
void ex_rewind(exarg_T *eap)
{
  do_argfile(eap, 0);
}

/// ":last" and ":slast".
void ex_last(exarg_T *eap)
{
  do_argfile(eap, ARGCOUNT - 1);
}

/// ":argument" and ":sargument".
void ex_argument(exarg_T *eap)
{
  int i;

  if (eap->addr_count > 0) {
    i = (int)eap->line2 - 1;
  } else {
    i = curwin->w_arg_idx;
  }
  do_argfile(eap, i);
}

/// Edit file "argn" of the argument lists.
void do_argfile(exarg_T *eap, int argn)
{
  int other;
  char *p;
  int old_arg_idx = curwin->w_arg_idx;

  if (argn < 0 || argn >= ARGCOUNT) {
    if (ARGCOUNT <= 1) {
      emsg(_("E163: There is only one file to edit"));
    } else if (argn < 0) {
      emsg(_("E164: Cannot go before first file"));
    } else {
      emsg(_("E165: Cannot go beyond last file"));
    }
  } else {
    setpcmark();

    // split window or create new tab page first
    if (*eap->cmd == 's' || cmdmod.cmod_tab != 0) {
      if (win_split(0, 0) == FAIL) {
        return;
      }
      RESET_BINDING(curwin);
    } else {
      // if 'hidden' set, only check for changed file when re-editing
      // the same buffer
      other = true;
      if (buf_hide(curbuf)) {
        p = fix_fname(alist_name(&ARGLIST[argn]));
        other = otherfile(p);
        xfree(p);
      }
      if ((!buf_hide(curbuf) || !other)
          && check_changed(curbuf, CCGD_AW
                           | (other ? 0 : CCGD_MULTWIN)
                           | (eap->forceit ? CCGD_FORCEIT : 0)
                           | CCGD_EXCMD)) {
        return;
      }
    }

    curwin->w_arg_idx = argn;
    if (argn == ARGCOUNT - 1 && curwin->w_alist == &global_alist) {
      arg_had_last = true;
    }

    // Edit the file; always use the last known line number.
    // When it fails (e.g. Abort for already edited file) restore the
    // argument index.
    if (do_ecmd(0, alist_name(&ARGLIST[curwin->w_arg_idx]), NULL,
                eap, ECMD_LAST,
                (buf_hide(curwin->w_buffer) ? ECMD_HIDE : 0)
                + (eap->forceit ? ECMD_FORCEIT : 0), curwin) == FAIL) {
      curwin->w_arg_idx = old_arg_idx;
    } else if (eap->cmdidx != CMD_argdo) {
      // like Vi: set the mark where the cursor is in the file.
      setmark('\'');
    }
  }
}

/// ":next", and commands that behave like it.
void ex_next(exarg_T *eap)
{
  int i;

  // check for changed buffer now, if this fails the argument list is not
  // redefined.
  if (buf_hide(curbuf)
      || eap->cmdidx == CMD_snext
      || !check_changed(curbuf, CCGD_AW
                        | (eap->forceit ? CCGD_FORCEIT : 0)
                        | CCGD_EXCMD)) {
    if (*eap->arg != NUL) {                 // redefine file list
      if (do_arglist(eap->arg, AL_SET, 0, true) == FAIL) {
        return;
      }
      i = 0;
    } else {
      i = curwin->w_arg_idx + (int)eap->line2;
    }
    do_argfile(eap, i);
  }
}

/// ":argedit"
void ex_argedit(exarg_T *eap)
{
  int i = eap->addr_count ? (int)eap->line2 : curwin->w_arg_idx + 1;
  // Whether curbuf will be reused, curbuf->b_ffname will be set.
  bool curbuf_is_reusable = curbuf_reusable();

  if (do_arglist(eap->arg, AL_ADD, i, true) == FAIL) {
    return;
  }
  maketitle();

  if (curwin->w_arg_idx == 0
      && (curbuf->b_ml.ml_flags & ML_EMPTY)
      && (curbuf->b_ffname == NULL || curbuf_is_reusable)) {
    i = 0;
  }
  // Edit the argument.
  if (i < ARGCOUNT) {
    do_argfile(eap, i);
  }
}

/// ":argadd"
void ex_argadd(exarg_T *eap)
{
  do_arglist(eap->arg, AL_ADD,
             eap->addr_count > 0 ? (int)eap->line2 : curwin->w_arg_idx + 1,
             false);
  maketitle();
}

/// ":argdelete"
void ex_argdelete(exarg_T *eap)
{
  if (eap->addr_count > 0 || *eap->arg == NUL) {
    // ":argdel" works like ":.argdel"
    if (eap->addr_count == 0) {
      if (curwin->w_arg_idx >= ARGCOUNT) {
        emsg(_("E610: No argument to delete"));
        return;
      }
      eap->line1 = eap->line2 = curwin->w_arg_idx + 1;
    } else if (eap->line2 > ARGCOUNT) {
      // ":1,4argdel": Delete all arguments in the range.
      eap->line2 = ARGCOUNT;
    }
    linenr_T n = eap->line2 - eap->line1 + 1;
    if (*eap->arg != NUL) {
      // Can't have both a range and an argument.
      emsg(_(e_invarg));
    } else if (n <= 0) {
      // Don't give an error for ":%argdel" if the list is empty.
      if (eap->line1 != 1 || eap->line2 != 0) {
        emsg(_(e_invrange));
      }
    } else {
      for (linenr_T i = eap->line1; i <= eap->line2; i++) {
        xfree(ARGLIST[i - 1].ae_fname);
      }
      memmove(ARGLIST + eap->line1 - 1, ARGLIST + eap->line2,
              (size_t)(ARGCOUNT - eap->line2) * sizeof(aentry_T));
      ALIST(curwin)->al_ga.ga_len -= (int)n;
      if (curwin->w_arg_idx >= eap->line2) {
        curwin->w_arg_idx -= (int)n;
      } else if (curwin->w_arg_idx > eap->line1) {
        curwin->w_arg_idx = (int)eap->line1;
      }
      if (ARGCOUNT == 0) {
        curwin->w_arg_idx = 0;
      } else if (curwin->w_arg_idx >= ARGCOUNT) {
        curwin->w_arg_idx = ARGCOUNT - 1;
      }
    }
  } else {
    do_arglist(eap->arg, AL_DEL, 0, false);
  }
  maketitle();
}

/// ":argdo", ":windo", ":bufdo", ":tabdo", ":cdo", ":ldo", ":cfdo" and ":lfdo"
void ex_listdo(exarg_T *eap)
{
  int i;
  win_T *wp;
  tabpage_T *tp;
  int next_fnum = 0;
  char *save_ei = NULL;
  char *p_shm_save;

  if (eap->cmdidx != CMD_windo && eap->cmdidx != CMD_tabdo) {
    // Don't do syntax HL autocommands.  Skipping the syntax file is a
    // great speed improvement.
    save_ei = au_event_disable(",Syntax");

    FOR_ALL_BUFFERS(buf) {
      buf->b_flags &= ~BF_SYN_SET;
    }
  }

  if (eap->cmdidx == CMD_windo
      || eap->cmdidx == CMD_tabdo
      || buf_hide(curbuf)
      || !check_changed(curbuf, CCGD_AW
                        | (eap->forceit ? CCGD_FORCEIT : 0)
                        | CCGD_EXCMD)) {
    i = 0;
    // start at the eap->line1 argument/window/buffer
    wp = firstwin;
    tp = first_tabpage;
    switch (eap->cmdidx) {
    case CMD_windo:
      for (; wp != NULL && i + 1 < eap->line1; wp = wp->w_next) {
        i++;
      }
      break;
    case CMD_tabdo:
      for (; tp != NULL && i + 1 < eap->line1; tp = tp->tp_next) {
        i++;
      }
      break;
    case CMD_argdo:
      i = (int)eap->line1 - 1;
      break;
    default:
      break;
    }

    buf_T *buf = curbuf;
    size_t qf_size = 0;

    // set pcmark now
    if (eap->cmdidx == CMD_bufdo) {
      // Advance to the first listed buffer after "eap->line1".
      for (buf = firstbuf;
           buf != NULL && (buf->b_fnum < eap->line1 || !buf->b_p_bl);
           buf = buf->b_next) {
        if (buf->b_fnum > eap->line2) {
          buf = NULL;
          break;
        }
      }
      if (buf != NULL) {
        goto_buffer(eap, DOBUF_FIRST, FORWARD, buf->b_fnum);
      }
    } else if (eap->cmdidx == CMD_cdo || eap->cmdidx == CMD_ldo
               || eap->cmdidx == CMD_cfdo || eap->cmdidx == CMD_lfdo) {
      qf_size = qf_get_valid_size(eap);
      assert(eap->line1 >= 0);
      if (qf_size == 0 || (size_t)eap->line1 > qf_size) {
        buf = NULL;
      } else {
        ex_cc(eap);

        buf = curbuf;
        i = (int)eap->line1 - 1;
        if (eap->addr_count <= 0) {
          // Default to all quickfix/location list entries.
          assert(qf_size < MAXLNUM);
          eap->line2 = (linenr_T)qf_size;
        }
      }
    } else {
      setpcmark();
    }
    listcmd_busy = true;            // avoids setting pcmark below

    while (!got_int && buf != NULL) {
      bool execute = true;
      if (eap->cmdidx == CMD_argdo) {
        // go to argument "i"
        if (i == ARGCOUNT) {
          break;
        }
        // Don't call do_argfile() when already there, it will try
        // reloading the file.
        if (curwin->w_arg_idx != i || !editing_arg_idx(curwin)) {
          // Clear 'shm' to avoid that the file message overwrites
          // any output from the command.
          p_shm_save = (char *)vim_strsave(p_shm);
          set_option_value("shm", 0L, "", 0);
          do_argfile(eap, i);
          set_option_value("shm", 0L, p_shm_save, 0);
          xfree(p_shm_save);
        }
        if (curwin->w_arg_idx != i) {
          break;
        }
      } else if (eap->cmdidx == CMD_windo) {
        // go to window "wp"
        if (!win_valid(wp)) {
          break;
        }
        assert(wp);
        execute = !wp->w_floating || wp->w_float_config.focusable;
        if (execute) {
          win_goto(wp);
          if (curwin != wp) {
            break;    // something must be wrong
          }
        }
        wp = wp->w_next;
      } else if (eap->cmdidx == CMD_tabdo) {
        // go to window "tp"
        if (!valid_tabpage(tp)) {
          break;
        }
        assert(tp);
        goto_tabpage_tp(tp, true, true);
        tp = tp->tp_next;
      } else if (eap->cmdidx == CMD_bufdo) {
        // Remember the number of the next listed buffer, in case
        // ":bwipe" is used or autocommands do something strange.
        next_fnum = -1;
        for (buf_T *bp = curbuf->b_next; bp != NULL; bp = bp->b_next) {
          if (bp->b_p_bl) {
            next_fnum = bp->b_fnum;
            break;
          }
        }
      }

      i++;
      // execute the command
      if (execute) {
        do_cmdline(eap->arg, eap->getline, eap->cookie, DOCMD_VERBOSE + DOCMD_NOWAIT);
      }

      if (eap->cmdidx == CMD_bufdo) {
        // Done?
        if (next_fnum < 0 || next_fnum > eap->line2) {
          break;
        }

        // Check if the buffer still exists.
        bool buf_still_exists = false;
        FOR_ALL_BUFFERS(bp) {
          if (bp->b_fnum == next_fnum) {
            buf_still_exists = true;
            break;
          }
        }
        if (!buf_still_exists) {
          break;
        }

        // Go to the next buffer.  Clear 'shm' to avoid that the file
        // message overwrites any output from the command.
        p_shm_save = (char *)vim_strsave(p_shm);
        set_option_value("shm", 0L, "", 0);
        goto_buffer(eap, DOBUF_FIRST, FORWARD, next_fnum);
        set_option_value("shm", 0L, p_shm_save, 0);
        xfree(p_shm_save);

        // If autocommands took us elsewhere, quit here.
        if (curbuf->b_fnum != next_fnum) {
          break;
        }
      }

      if (eap->cmdidx == CMD_cdo || eap->cmdidx == CMD_ldo
          || eap->cmdidx == CMD_cfdo || eap->cmdidx == CMD_lfdo) {
        assert(i >= 0);
        if ((size_t)i >= qf_size || i >= eap->line2) {
          break;
        }

        size_t qf_idx = qf_get_cur_idx(eap);

        // Clear 'shm' to avoid that the file message overwrites
        // any output from the command.
        p_shm_save = (char *)vim_strsave(p_shm);
        set_option_value("shm", 0L, "", 0);
        ex_cnext(eap);
        set_option_value("shm", 0L, p_shm_save, 0);
        xfree(p_shm_save);

        // If jumping to the next quickfix entry fails, quit here.
        if (qf_get_cur_idx(eap) == qf_idx) {
          break;
        }
      }

      if (eap->cmdidx == CMD_windo && execute) {
        validate_cursor();              // cursor may have moved
        // required when 'scrollbind' has been set
        if (curwin->w_p_scb) {
          do_check_scrollbind(true);
        }
      }
      if (eap->cmdidx == CMD_windo || eap->cmdidx == CMD_tabdo) {
        if (i + 1 > eap->line2) {
          break;
        }
      }
      if (eap->cmdidx == CMD_argdo && i >= eap->line2) {
        break;
      }
    }
    listcmd_busy = false;
  }

  if (save_ei != NULL) {
    buf_T *bnext;
    aco_save_T aco;

    au_event_restore(save_ei);

    for (buf_T *buf = firstbuf; buf != NULL; buf = bnext) {
      bnext = buf->b_next;
      if (buf->b_nwindows > 0 && (buf->b_flags & BF_SYN_SET)) {
        buf->b_flags &= ~BF_SYN_SET;

        // buffer was opened while Syntax autocommands were disabled,
        // need to trigger them now.
        if (buf == curbuf) {
          apply_autocmds(EVENT_SYNTAX, (char *)curbuf->b_p_syn, curbuf->b_fname, true,
                         curbuf);
        } else {
          aucmd_prepbuf(&aco, buf);
          apply_autocmds(EVENT_SYNTAX, (char *)buf->b_p_syn, buf->b_fname, true, buf);
          aucmd_restbuf(&aco);
        }

        // start over, in case autocommands messed things up.
        bnext = firstbuf;
      }
    }
  }
}

/// Add files[count] to the arglist of the current window after arg "after".
/// The file names in files[count] must have been allocated and are taken over.
/// Files[] itself is not taken over.
///
/// @param after: where to add: 0 = before first one
/// @param will_edit  will edit adding argument
static void alist_add_list(int count, char **files, int after, bool will_edit)
  FUNC_ATTR_NONNULL_ALL
{
  int old_argcount = ARGCOUNT;
  ga_grow(&ALIST(curwin)->al_ga, count);
  {
    if (after < 0) {
      after = 0;
    }
    if (after > ARGCOUNT) {
      after = ARGCOUNT;
    }
    if (after < ARGCOUNT) {
      memmove(&(ARGLIST[after + count]), &(ARGLIST[after]),
              (size_t)(ARGCOUNT - after) * sizeof(aentry_T));
    }
    for (int i = 0; i < count; i++) {
      const int flags = BLN_LISTED | (will_edit ? BLN_CURBUF : 0);
      ARGLIST[after + i].ae_fname = (char_u *)files[i];
      ARGLIST[after + i].ae_fnum = buflist_add(files[i], flags);
    }
    ALIST(curwin)->al_ga.ga_len += count;
    if (old_argcount > 0 && curwin->w_arg_idx >= after) {
      curwin->w_arg_idx += count;
    }
    return;
  }
}

// Function given to ExpandGeneric() to obtain the possible arguments of the
// argedit and argdelete commands.
char *get_arglist_name(expand_T *xp FUNC_ATTR_UNUSED, int idx)
{
  if (idx >= ARGCOUNT) {
    return NULL;
  }
  return alist_name(&ARGLIST[idx]);
}

/// ":compiler[!] {name}"
void ex_compiler(exarg_T *eap)
{
  char *buf;
  char *old_cur_comp = NULL;
  char *p;

  if (*eap->arg == NUL) {
    // List all compiler scripts.
    do_cmdline_cmd("echo globpath(&rtp, 'compiler/*.vim')");  // NOLINT
    do_cmdline_cmd("echo globpath(&rtp, 'compiler/*.lua')");  // NOLINT
  } else {
    size_t bufsize = STRLEN(eap->arg) + 14;
    buf = xmalloc(bufsize);
    if (eap->forceit) {
      // ":compiler! {name}" sets global options
      do_cmdline_cmd("command -nargs=* CompilerSet set <args>");
    } else {
      // ":compiler! {name}" sets local options.
      // To remain backwards compatible "current_compiler" is always
      // used.  A user's compiler plugin may set it, the distributed
      // plugin will then skip the settings.  Afterwards set
      // "b:current_compiler" and restore "current_compiler".
      // Explicitly prepend "g:" to make it work in a function.
      old_cur_comp = (char *)get_var_value("g:current_compiler");
      if (old_cur_comp != NULL) {
        old_cur_comp = xstrdup(old_cur_comp);
      }
      do_cmdline_cmd("command -nargs=* -keepscript CompilerSet setlocal <args>");
    }
    do_unlet(S_LEN("g:current_compiler"), true);
    do_unlet(S_LEN("b:current_compiler"), true);

    snprintf(buf, bufsize, "compiler/%s.vim", eap->arg);
    if (source_runtime(buf, DIP_ALL) == FAIL) {
      // Try lua compiler
      snprintf(buf, bufsize, "compiler/%s.lua", eap->arg);
      if (source_runtime(buf, DIP_ALL) == FAIL) {
        semsg(_("E666: compiler not supported: %s"), eap->arg);
      }
    }
    xfree(buf);

    do_cmdline_cmd(":delcommand CompilerSet");

    // Set "b:current_compiler" from "current_compiler".
    p = (char *)get_var_value("g:current_compiler");
    if (p != NULL) {
      set_internal_string_var("b:current_compiler", p);
    }

    // Restore "current_compiler" for ":compiler {name}".
    if (!eap->forceit) {
      if (old_cur_comp != NULL) {
        set_internal_string_var("g:current_compiler", old_cur_comp);
        xfree(old_cur_comp);
      } else {
        do_unlet(S_LEN("g:current_compiler"), true);
      }
    }
  }
}

/// ":checktime [buffer]"
void ex_checktime(exarg_T *eap)
{
  buf_T *buf;
  int save_no_check_timestamps = no_check_timestamps;

  no_check_timestamps = 0;
  if (eap->addr_count == 0) {    // default is all buffers
    check_timestamps(false);
  } else {
    buf = buflist_findnr((int)eap->line2);
    if (buf != NULL) {           // cannot happen?
      (void)buf_check_timestamp(buf);
    }
  }
  no_check_timestamps = save_no_check_timestamps;
}

#if defined(HAVE_LOCALE_H)
# define HAVE_GET_LOCALE_VAL

static char *get_locale_val(int what)
{
  // Obtain the locale value from the libraries.
  char *loc = setlocale(what, NULL);

  return loc;
}
#endif

/// @return  true when "lang" starts with a valid language name.
///          Rejects NULL, empty string, "C", "C.UTF-8" and others.
static bool is_valid_mess_lang(char *lang)
{
  return lang != NULL && ASCII_ISALPHA(lang[0]) && ASCII_ISALPHA(lang[1]);
}

/// Obtain the current messages language.  Used to set the default for
/// 'helplang'.  May return NULL or an empty string.
char *get_mess_lang(void)
{
  char *p;

#ifdef HAVE_GET_LOCALE_VAL
# if defined(LC_MESSAGES)
  p = get_locale_val(LC_MESSAGES);
# else
  // This is necessary for Win32, where LC_MESSAGES is not defined and $LANG
  // may be set to the LCID number.  LC_COLLATE is the best guess, LC_TIME
  // and LC_MONETARY may be set differently for a Japanese working in the
  // US.
  p = get_locale_val(LC_COLLATE);
# endif
#else
  p = os_getenv("LC_ALL");
  if (!is_valid_mess_lang(p)) {
    p = os_getenv("LC_MESSAGES");
    if (!is_valid_mess_lang(p)) {
      p = os_getenv("LANG");
    }
  }
#endif
  return is_valid_mess_lang(p) ? p : NULL;
}

// Complicated #if; matches with where get_mess_env() is used below.
#ifdef HAVE_WORKING_LIBINTL
/// Get the language used for messages from the environment.
static char *get_mess_env(void)
{
  char *p;

  p = (char *)os_getenv("LC_ALL");
  if (p == NULL) {
    p = (char *)os_getenv("LC_MESSAGES");
    if (p == NULL) {
      p = (char *)os_getenv("LANG");
      if (p != NULL && ascii_isdigit(*p)) {
        p = NULL;                       // ignore something like "1043"
      }
# ifdef HAVE_GET_LOCALE_VAL
      if (p == NULL) {
        p = get_locale_val(LC_CTYPE);
      }
# endif
    }
  }
  return p;
}

#endif

/// Set the "v:lang" variable according to the current locale setting.
/// Also do "v:lc_time"and "v:ctype".
void set_lang_var(void)
{
  const char *loc;

#ifdef HAVE_GET_LOCALE_VAL
  loc = get_locale_val(LC_CTYPE);
#else
  // setlocale() not supported: use the default value
  loc = "C";
#endif
  set_vim_var_string(VV_CTYPE, loc, -1);

  // When LC_MESSAGES isn't defined use the value from $LC_MESSAGES, fall
  // back to LC_CTYPE if it's empty.
#ifdef HAVE_WORKING_LIBINTL
  loc = get_mess_env();
#elif defined(LC_MESSAGES)
  loc = get_locale_val(LC_MESSAGES);
#else
  // In Windows LC_MESSAGES is not defined fallback to LC_CTYPE
  loc = get_locale_val(LC_CTYPE);
#endif
  set_vim_var_string(VV_LANG, loc, -1);

#ifdef HAVE_GET_LOCALE_VAL
  loc = get_locale_val(LC_TIME);
#endif
  set_vim_var_string(VV_LC_TIME, loc, -1);

#ifdef HAVE_GET_LOCALE_VAL
  loc = get_locale_val(LC_COLLATE);
#else
  // setlocale() not supported: use the default value
  loc = "C";
#endif
  set_vim_var_string(VV_COLLATE, loc, -1);
}

#ifdef HAVE_WORKING_LIBINTL

/// ":language":  Set the language (locale).
///
/// @param eap
void ex_language(exarg_T *eap)
{
  char *loc;
  char *p;
  char *name;
  int what = LC_ALL;
  char *whatstr = "";
# ifdef LC_MESSAGES
#  define VIM_LC_MESSAGES LC_MESSAGES
# else
#  define VIM_LC_MESSAGES 6789
# endif

  name = eap->arg;

  // Check for "messages {name}", "ctype {name}" or "time {name}" argument.
  // Allow abbreviation, but require at least 3 characters to avoid
  // confusion with a two letter language name "me" or "ct".
  p = (char *)skiptowhite((char_u *)eap->arg);
  if ((*p == NUL || ascii_iswhite(*p)) && p - eap->arg >= 3) {
    if (STRNICMP(eap->arg, "messages", p - eap->arg) == 0) {
      what = VIM_LC_MESSAGES;
      name = skipwhite(p);
      whatstr = "messages ";
    } else if (STRNICMP(eap->arg, "ctype", p - eap->arg) == 0) {
      what = LC_CTYPE;
      name = skipwhite(p);
      whatstr = "ctype ";
    } else if (STRNICMP(eap->arg, "time", p - eap->arg) == 0) {
      what = LC_TIME;
      name = skipwhite(p);
      whatstr = "time ";
    } else if (STRNICMP(eap->arg, "collate", p - eap->arg) == 0) {
      what = LC_COLLATE;
      name = skipwhite(p);
      whatstr = "collate ";
    }
  }

  if (*name == NUL) {
    if (what == VIM_LC_MESSAGES) {
      p = get_mess_env();
    } else {
      p = setlocale(what, NULL);
    }
    if (p == NULL || *p == NUL) {
      p = "Unknown";
    }
    smsg(_("Current %slanguage: \"%s\""), whatstr, p);
  } else {
# ifndef LC_MESSAGES
    if (what == VIM_LC_MESSAGES) {
      loc = "";
    } else {
# endif
    loc = setlocale(what, name);
# ifdef LC_NUMERIC
    // Make sure strtod() uses a decimal point, not a comma.
    setlocale(LC_NUMERIC, "C");
# endif
# ifndef LC_MESSAGES
  }
# endif
    if (loc == NULL) {
      semsg(_("E197: Cannot set language to \"%s\""), name);
    } else {
# ifdef HAVE_NL_MSG_CAT_CNTR
      // Need to do this for GNU gettext, otherwise cached translations
      // will be used again.
      extern int _nl_msg_cat_cntr;

      _nl_msg_cat_cntr++;
# endif
      // Reset $LC_ALL, otherwise it would overrule everything.
      os_setenv("LC_ALL", "", 1);

      if (what != LC_TIME && what != LC_COLLATE) {
        // Tell gettext() what to translate to.  It apparently doesn't
        // use the currently effective locale.
        if (what == LC_ALL) {
          os_setenv("LANG", name, 1);

          // Clear $LANGUAGE because GNU gettext uses it.
          os_setenv("LANGUAGE", "", 1);
        }
        if (what != LC_CTYPE) {
          os_setenv("LC_MESSAGES", name, 1);
          set_helplang_default(name);
        }
      }

      // Set v:lang, v:lc_time, v:collate and v:ctype to the final result.
      set_lang_var();
      maketitle();
    }
  }
}

static char **locales = NULL;       // Array of all available locales

# ifndef WIN32
static bool did_init_locales = false;

/// @return  an array of strings for all available locales + NULL for the
///          last element or,
///          NULL in case of error.
static char **find_locales(void)
{
  garray_T locales_ga;
  char *loc;
  char *saveptr = NULL;

  // Find all available locales by running command "locale -a".  If this
  // doesn't work we won't have completion.
  char *locale_a = (char *)get_cmd_output((char_u *)"locale -a", NULL,
                                          kShellOptSilent, NULL);
  if (locale_a == NULL) {
    return NULL;
  }
  ga_init(&locales_ga, sizeof(char_u *), 20);

  // Transform locale_a string where each locale is separated by "\n"
  // into an array of locale strings.
  loc = os_strtok(locale_a, "\n", &saveptr);

  while (loc != NULL) {
    loc = xstrdup(loc);
    GA_APPEND(char *, &locales_ga, loc);
    loc = os_strtok(NULL, "\n", &saveptr);
  }
  xfree(locale_a);
  // Guarantee that .ga_data is NULL terminated
  ga_grow(&locales_ga, 1);
  ((char_u **)locales_ga.ga_data)[locales_ga.ga_len] = NULL;
  return locales_ga.ga_data;
}
# endif

/// Lazy initialization of all available locales.
static void init_locales(void)
{
# ifndef WIN32
  if (!did_init_locales) {
    did_init_locales = true;
    locales = find_locales();
  }
# endif
}

# if defined(EXITFREE)
void free_locales(void)
{
  int i;
  if (locales != NULL) {
    for (i = 0; locales[i] != NULL; i++) {
      xfree(locales[i]);
    }
    XFREE_CLEAR(locales);
  }
}

# endif

/// Function given to ExpandGeneric() to obtain the possible arguments of the
/// ":language" command.
char *get_lang_arg(expand_T *xp, int idx)
{
  if (idx == 0) {
    return "messages";
  }
  if (idx == 1) {
    return "ctype";
  }
  if (idx == 2) {
    return "time";
  }
  if (idx == 3) {
    return "collate";
  }

  init_locales();
  if (locales == NULL) {
    return NULL;
  }
  return locales[idx - 4];
}

/// Function given to ExpandGeneric() to obtain the available locales.
char *get_locales(expand_T *xp, int idx)
{
  init_locales();
  if (locales == NULL) {
    return NULL;
  }
  return locales[idx];
}

#endif

static void script_host_execute(char *name, exarg_T *eap)
{
  size_t len;
  char *const script = script_get(eap, &len);

  if (script != NULL) {
    list_T *const args = tv_list_alloc(3);
    // script
    tv_list_append_allocated_string(args, script);
    // current range
    tv_list_append_number(args, (int)eap->line1);
    tv_list_append_number(args, (int)eap->line2);

    (void)eval_call_provider(name, "execute", args, true);
  }
}

static void script_host_execute_file(char *name, exarg_T *eap)
{
  if (!eap->skip) {
    uint8_t buffer[MAXPATHL];
    vim_FullName(eap->arg, (char *)buffer, sizeof(buffer), false);

    list_T *args = tv_list_alloc(3);
    // filename
    tv_list_append_string(args, (const char *)buffer, -1);
    // current range
    tv_list_append_number(args, (int)eap->line1);
    tv_list_append_number(args, (int)eap->line2);
    (void)eval_call_provider(name, "execute_file", args, true);
  }
}

static void script_host_do_range(char *name, exarg_T *eap)
{
  if (!eap->skip) {
    list_T *args = tv_list_alloc(3);
    tv_list_append_number(args, (int)eap->line1);
    tv_list_append_number(args, (int)eap->line2);
    tv_list_append_string(args, (const char *)eap->arg, -1);
    (void)eval_call_provider(name, "do_range", args, true);
  }
}

/// ":drop"
/// Opens the first argument in a window.  When there are two or more arguments
/// the argument list is redefined.
void ex_drop(exarg_T *eap)
{
  bool split = false;
  buf_T *buf;

  // Check if the first argument is already being edited in a window.  If
  // so, jump to that window.
  // We would actually need to check all arguments, but that's complicated
  // and mostly only one file is dropped.
  // This also ignores wildcards, since it is very unlikely the user is
  // editing a file name with a wildcard character.
  do_arglist(eap->arg, AL_SET, 0, false);

  // Expanding wildcards may result in an empty argument list.  E.g. when
  // editing "foo.pyc" and ".pyc" is in 'wildignore'.  Assume that we
  // already did an error message for this.
  if (ARGCOUNT == 0) {
    return;
  }

  if (cmdmod.cmod_tab) {
    // ":tab drop file ...": open a tab for each argument that isn't
    // edited in a window yet.  It's like ":tab all" but without closing
    // windows or tabs.
    ex_all(eap);
  } else {
    // ":drop file ...": Edit the first argument.  Jump to an existing
    // window if possible, edit in current window if the current buffer
    // can be abandoned, otherwise open a new window.
    buf = buflist_findnr(ARGLIST[0].ae_fnum);

    FOR_ALL_TAB_WINDOWS(tp, wp) {
      if (wp->w_buffer == buf) {
        goto_tabpage_win(tp, wp);
        curwin->w_arg_idx = 0;
        if (!bufIsChanged(curbuf)) {
          const int save_ar = curbuf->b_p_ar;

          // reload the file if it is newer
          curbuf->b_p_ar = 1;
          buf_check_timestamp(curbuf);
          curbuf->b_p_ar = save_ar;
        }
        return;
      }
    }

    // Check whether the current buffer is changed. If so, we will need
    // to split the current window or data could be lost.
    // Skip the check if the 'hidden' option is set, as in this case the
    // buffer won't be lost.
    if (!buf_hide(curbuf)) {
      emsg_off++;
      split = check_changed(curbuf, CCGD_AW | CCGD_EXCMD);
      emsg_off--;
    }

    // Fake a ":sfirst" or ":first" command edit the first argument.
    if (split) {
      eap->cmdidx = CMD_sfirst;
      eap->cmd[0] = 's';
    } else {
      eap->cmdidx = CMD_first;
    }
    ex_rewind(eap);
  }
}
