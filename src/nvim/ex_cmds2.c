/// @file ex_cmds2.c
///
/// Some more functions for command line commands

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#include "nvim/arglist.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/bufwrite.h"
#include "nvim/change.h"
#include "nvim/channel.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/vars.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/mark.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/option_vars.h"
#include "nvim/os/os_defs.h"
#include "nvim/path.h"
#include "nvim/pos_defs.h"
#include "nvim/quickfix.h"
#include "nvim/runtime.h"
#include "nvim/types_defs.h"
#include "nvim/undo.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_cmds2.c.generated.h"
#endif

static const char e_compiler_not_supported_str[]
  = N_("E666: Compiler not supported: %s");

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
int autowrite(buf_T *buf, bool forceit)
{
  bufref_T bufref;

  if (!(p_aw || p_awa) || !p_write
      // never autowrite a "nofile" or "nowrite" buffer
      || bt_dontwrite(buf)
      || (!forceit && buf->b_p_ro) || buf->b_ffname == NULL) {
    return FAIL;
  }
  set_bufref(&bufref, buf);
  int r = buf_write_all(buf, forceit);

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
      buf_write_all(buf, false);
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
  bool forceit = (flags & CCGD_FORCEIT);
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

  dialog_msg(buff, _("Save changes to \"%s\"?"), buf->b_fname);
  if (checkall) {
    ret = vim_dialog_yesnoallcancel(VIM_QUESTION, NULL, buff, 1);
  } else {
    ret = vim_dialog_yesnocancel(VIM_QUESTION, NULL, buff, 1);
  }

  if (ret == VIM_YES) {
    bool empty_bufname = buf->b_fname == NULL;
    if (empty_bufname) {
      buf_set_name(buf->b_fnum, "Untitled");
    }

    if (check_overwrite(&ea, buf, buf->b_fname, buf->b_ffname, false) == OK) {
      // didn't hit Cancel
      if (buf_write_all(buf, false) == OK) {
        return;
      }
    }

    // restore to empty when write failed
    if (empty_bufname) {
      XFREE_CLEAR(buf->b_fname);
      XFREE_CLEAR(buf->b_ffname);
      XFREE_CLEAR(buf->b_sfname);
      unchanged(buf, true, false);
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
          buf_write_all(buf2, false);
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

  int ret = vim_dialog_yesnocancel(VIM_QUESTION, NULL, buff, 1);

  return ret == VIM_YES;
}

/// @return true if the buffer "buf" can be abandoned, either by making it
/// hidden, autowriting it or unloading it.
bool can_abandon(buf_T *buf, bool forceit)
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
  for (int i = 0; i < *bufnump; i++) {
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
  int i;
  int bufnum = 0;
  size_t bufcount = 0;

  // Make a list of all buffers, with the most important ones first.
  FOR_ALL_BUFFERS(buf) {
    bufcount++;
  }

  if (bufcount == 0) {
    return false;
  }

  int *bufnrs = xmalloc(sizeof(*bufnrs) * bufcount);

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
    // There must be a wait_return() for this message, do_buffer()
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
      int save = no_wait_return;
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
    set_curbuf(buf, unload ? DOBUF_UNLOAD : DOBUF_GOTO, true);
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
int buf_write_all(buf_T *buf, bool forceit)
{
  buf_T *old_curbuf = curbuf;

  int retval = (buf_write(buf, buf->b_ffname, buf->b_fname,
                          1, buf->b_ml.ml_line_count, NULL,
                          false, forceit, true, false));
  if (curbuf != old_curbuf) {
    msg_source(HL_ATTR(HLF_W));
    msg(_("Warning: Entered other buffer unexpectedly (check autocommands)"), 0);
  }
  return retval;
}

/// ":argdo", ":windo", ":bufdo", ":tabdo", ":cdo", ":ldo", ":cfdo" and ":lfdo"
void ex_listdo(exarg_T *eap)
{
  if (curwin->w_p_wfb) {
    if ((eap->cmdidx == CMD_ldo || eap->cmdidx == CMD_lfdo) && !eap->forceit) {
      // Disallow :ldo if 'winfixbuf' is applied
      emsg(_(e_winfixbuf_cannot_go_to_buffer));
      return;
    }

    if (win_valid(prevwin) && !prevwin->w_p_wfb) {
      // 'winfixbuf' is set; attempt to change to a window without it.
      win_goto(prevwin);
    }
    if (curwin->w_p_wfb) {
      // Split the window, which will be 'nowinfixbuf', and set curwin to that
      (void)win_split(0, 0);

      if (curwin->w_p_wfb) {
        // Autocommands set 'winfixbuf' or sent us to another window
        // with it set, or we failed to split the window. Give up.
        emsg(_(e_winfixbuf_cannot_go_to_buffer));
        return;
      }
    }
  }

  char *save_ei = NULL;

  // Temporarily override SHM_OVER and SHM_OVERALL to avoid that file
  // message overwrites output from the command.
  msg_listdo_overwrite++;

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
    int next_fnum = 0;
    int i = 0;
    // start at the eap->line1 argument/window/buffer
    win_T *wp = firstwin;
    tabpage_T *tp = first_tabpage;
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
          do_argfile(eap, i);
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
        execute = !wp->w_floating || wp->w_config.focusable;
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
        do_cmdline(eap->arg, eap->ea_getline, eap->cookie, DOCMD_VERBOSE + DOCMD_NOWAIT);
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

        // Go to the next buffer.
        goto_buffer(eap, DOBUF_FIRST, FORWARD, next_fnum);

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

        ex_cnext(eap);

        // If jumping to the next quickfix entry fails, quit here.
        if (qf_get_cur_idx(eap) == qf_idx) {
          break;
        }
      }

      if (eap->cmdidx == CMD_windo && execute) {
        validate_cursor(curwin);              // cursor may have moved
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

  msg_listdo_overwrite--;
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
          apply_autocmds(EVENT_SYNTAX, curbuf->b_p_syn, curbuf->b_fname, true,
                         curbuf);
        } else {
          aucmd_prepbuf(&aco, buf);
          apply_autocmds(EVENT_SYNTAX, buf->b_p_syn, buf->b_fname, true, buf);
          aucmd_restbuf(&aco);
        }

        // start over, in case autocommands messed things up.
        bnext = firstbuf;
      }
    }
  }
}

/// ":compiler[!] {name}"
void ex_compiler(exarg_T *eap)
{
  char *old_cur_comp = NULL;

  if (*eap->arg == NUL) {
    // List all compiler scripts.
    do_cmdline_cmd("echo globpath(&rtp, 'compiler/*.vim')");  // NOLINT
    do_cmdline_cmd("echo globpath(&rtp, 'compiler/*.lua')");  // NOLINT
    return;
  }

  size_t bufsize = strlen(eap->arg) + 14;
  char *buf = xmalloc(bufsize);

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
    old_cur_comp = get_var_value("g:current_compiler");
    if (old_cur_comp != NULL) {
      old_cur_comp = xstrdup(old_cur_comp);
    }
    do_cmdline_cmd("command -nargs=* -keepscript CompilerSet setlocal <args>");
  }
  do_unlet(S_LEN("g:current_compiler"), true);
  do_unlet(S_LEN("b:current_compiler"), true);

  snprintf(buf, bufsize, "compiler/%s.*", eap->arg);
  if (source_runtime_vim_lua(buf, DIP_ALL) == FAIL) {
    semsg(_(e_compiler_not_supported_str), eap->arg);
  }
  xfree(buf);

  do_cmdline_cmd(":delcommand CompilerSet");

  // Set "b:current_compiler" from "current_compiler".
  char *p = get_var_value("g:current_compiler");
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

/// ":checktime [buffer]"
void ex_checktime(exarg_T *eap)
{
  int save_no_check_timestamps = no_check_timestamps;

  no_check_timestamps = 0;
  if (eap->addr_count == 0) {    // default is all buffers
    check_timestamps(false);
  } else {
    buf_T *buf = buflist_findnr((int)eap->line2);
    if (buf != NULL) {           // cannot happen?
      buf_check_timestamp(buf);
    }
  }
  no_check_timestamps = save_no_check_timestamps;
}

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

    eval_call_provider(name, "execute", args, true);
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
    eval_call_provider(name, "execute_file", args, true);
  }
}

static void script_host_do_range(char *name, exarg_T *eap)
{
  if (!eap->skip) {
    list_T *args = tv_list_alloc(3);
    tv_list_append_number(args, (int)eap->line1);
    tv_list_append_number(args, (int)eap->line2);
    tv_list_append_string(args, eap->arg, -1);
    eval_call_provider(name, "do_range", args, true);
  }
}

/// ":drop"
/// Opens the first argument in a window, and the argument list is redefined.
void ex_drop(exarg_T *eap)
{
  bool split = false;

  // Check if the first argument is already being edited in a window.  If
  // so, jump to that window.
  // We would actually need to check all arguments, but that's complicated
  // and mostly only one file is dropped.
  // This also ignores wildcards, since it is very unlikely the user is
  // editing a file name with a wildcard character.
  set_arglist(eap->arg);

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
    cmdmod.cmod_tab = 0;
    ex_rewind(eap);
    return;
  }

  // ":drop file ...": Edit the first argument.  Jump to an existing
  // window if possible, edit in current window if the current buffer
  // can be abandoned, otherwise open a new window.
  buf_T *buf = buflist_findnr(ARGLIST[0].ae_fnum);

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->w_buffer == buf) {
      goto_tabpage_win(tp, wp);
      curwin->w_arg_idx = 0;
      if (!bufIsChanged(curbuf)) {
        const int save_ar = curbuf->b_p_ar;

        // reload the file if it is newer
        curbuf->b_p_ar = true;
        buf_check_timestamp(curbuf);
        curbuf->b_p_ar = save_ar;
      }
      if (curbuf->b_ml.ml_flags & ML_EMPTY) {
        ex_rewind(eap);
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
