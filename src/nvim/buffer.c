//
// buffer.c: functions for dealing with the buffer structure
//

//
// The buffer list is a double linked list of all buffers.
// Each buffer can be in one of these states:
// never loaded: BF_NEVERLOADED is set, only the file name is valid
//   not loaded: b_ml.ml_mfp == NULL, no memfile allocated
//       hidden: b_nwindows == 0, loaded but not displayed in a window
//       normal: loaded and displayed in a window
//
// Instead of storing file names all over the place, each file name is
// stored in the buffer list. It can be referenced by a number.
//
// The current implementation remembers all file names ever used.
//

#include <assert.h>
#include <ctype.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>

#include "auto/config.h"
#include "klib/kvec.h"
#include "nvim/api/private/helpers.h"
#include "nvim/arglist.h"
#include "nvim/ascii_defs.h"
#include "nvim/assert_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_updates.h"
#include "nvim/change.h"
#include "nvim/channel.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/digraph.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/vars.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_eval_defs.h"
#include "nvim/ex_getln.h"
#include "nvim/extmark.h"
#include "nvim/file_search.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/hashtab.h"
#include "nvim/hashtab_defs.h"
#include "nvim/help.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/main.h"
#include "nvim/map_defs.h"
#include "nvim/mapping.h"
#include "nvim/mark.h"
#include "nvim/mark_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memfile_defs.h"
#include "nvim/memline.h"
#include "nvim/memline_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/optionstr.h"
#include "nvim/os/fs.h"
#include "nvim/os/fs_defs.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/time.h"
#include "nvim/path.h"
#include "nvim/plines.h"
#include "nvim/pos_defs.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/runtime.h"
#include "nvim/runtime_defs.h"
#include "nvim/search.h"
#include "nvim/spell.h"
#include "nvim/state_defs.h"
#include "nvim/statusline.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/terminal.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/usercmd.h"
#include "nvim/version.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"
#include "nvim/winfloat.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "buffer.c.generated.h"
#endif

static const char e_attempt_to_delete_buffer_that_is_in_use_str[]
  = N_("E937: Attempt to delete a buffer that is in use: %s");

// Number of times free_buffer() was called.
static int buf_free_count = 0;

static int top_file_num = 1;            ///< highest file number

typedef enum {
  kBffClearWinInfo = 1,
  kBffInitChangedtick = 2,
} BufFreeFlags;

/// @return  the highest possible buffer number
int get_highest_fnum(void)
{
  return top_file_num - 1;
}

/// Read data from buffer for retrying.
///
/// @param read_stdin  read file from stdin, otherwise fifo
/// @param eap  for forced 'ff' and 'fenc' or NULL
/// @param flags  extra flags for readfile()
static int read_buffer(bool read_stdin, exarg_T *eap, int flags)
{
  int retval = OK;
  bool silent = shortmess(SHM_FILEINFO);

  // Read from the buffer which the text is already filled in and append at
  // the end.  This makes it possible to retry when 'fileformat' or
  // 'fileencoding' was guessed wrong.
  linenr_T line_count = curbuf->b_ml.ml_line_count;
  retval = readfile(read_stdin ? NULL : curbuf->b_ffname,
                    read_stdin ? NULL : curbuf->b_fname,
                    line_count, 0, (linenr_T)MAXLNUM, eap,
                    flags | READ_BUFFER, silent);
  if (retval == OK) {
    // Delete the binary lines.
    while (--line_count >= 0) {
      ml_delete(1, false);
    }
  } else {
    // Delete the converted lines.
    while (curbuf->b_ml.ml_line_count > line_count) {
      ml_delete(line_count, false);
    }
  }
  // Put the cursor on the first line.
  curwin->w_cursor.lnum = 1;
  curwin->w_cursor.col = 0;

  if (read_stdin) {
    // Set or reset 'modified' before executing autocommands, so that
    // it can be changed there.
    if (!readonlymode && !buf_is_empty(curbuf)) {
      changed(curbuf);
    } else if (retval != FAIL) {
      unchanged(curbuf, false, true);
    }

    apply_autocmds_retval(EVENT_STDINREADPOST, NULL, NULL, false,
                          curbuf, &retval);
  }
  return retval;
}

/// Ensure buffer "buf" is loaded.
bool buf_ensure_loaded(buf_T *buf)
{
  if (buf->b_ml.ml_mfp != NULL) {
    // already open (common case)
    return true;
  }

  aco_save_T aco;

  // Make sure the buffer is in a window.
  aucmd_prepbuf(&aco, buf);
  // status can be OK or NOTDONE (which also means ok/done)
  int status = open_buffer(false, NULL, 0);
  aucmd_restbuf(&aco);
  return (status != FAIL);
}

/// Open current buffer, that is: open the memfile and read the file into
/// memory.
///
/// @param read_stdin  read file from stdin
/// @param eap  for forced 'ff' and 'fenc' or NULL
/// @param flags_arg  extra flags for readfile()
///
/// @return  FAIL for failure, OK otherwise.
int open_buffer(bool read_stdin, exarg_T *eap, int flags_arg)
{
  int flags = flags_arg;
  int retval = OK;
  bufref_T old_curbuf;
  OptInt old_tw = curbuf->b_p_tw;
  bool read_fifo = false;
  bool silent = shortmess(SHM_FILEINFO);

  // The 'readonly' flag is only set when BF_NEVERLOADED is being reset.
  // When re-entering the same buffer, it should not change, because the
  // user may have reset the flag by hand.
  if (readonlymode && curbuf->b_ffname != NULL
      && (curbuf->b_flags & BF_NEVERLOADED)) {
    curbuf->b_p_ro = true;
  }

  if (ml_open(curbuf) == FAIL) {
    // There MUST be a memfile, otherwise we can't do anything
    // If we can't create one for the current buffer, take another buffer
    close_buffer(NULL, curbuf, 0, false, false);

    curbuf = NULL;
    FOR_ALL_BUFFERS(buf) {
      if (buf->b_ml.ml_mfp != NULL) {
        curbuf = buf;
        break;
      }
    }

    // If there is no memfile at all, exit.
    // This is OK, since there are no changes to lose.
    if (curbuf == NULL) {
      emsg(_("E82: Cannot allocate any buffer, exiting..."));

      // Don't try to do any saving, with "curbuf" NULL almost nothing
      // will work.
      v_dying = 2;
      getout(2);
    }

    emsg(_("E83: Cannot allocate buffer, using other one..."));
    enter_buffer(curbuf);
    if (old_tw != curbuf->b_p_tw) {
      check_colorcolumn(NULL, curwin);
    }
    return FAIL;
  }

  // Do not sync this buffer yet, may first want to read the file.
  if (curbuf->b_ml.ml_mfp != NULL) {
    curbuf->b_ml.ml_mfp->mf_dirty = MF_DIRTY_YES_NOSYNC;
  }

  // The autocommands in readfile() may change the buffer, but only AFTER
  // reading the file.
  set_bufref(&old_curbuf, curbuf);
  curbuf->b_modified_was_set = false;

  // mark cursor position as being invalid
  curwin->w_valid = 0;

  // A buffer without an actual file should not use the buffer name to read a
  // file.
  if (bt_nofileread(curbuf)) {
    flags |= READ_NOFILE;
  }

  // Read the file if there is one.
  if (curbuf->b_ffname != NULL) {
#ifdef UNIX
    int save_bin = curbuf->b_p_bin;
    int perm = os_getperm(curbuf->b_ffname);
    if (perm >= 0 && (0 || S_ISFIFO(perm)
                      || S_ISSOCK(perm)
# ifdef OPEN_CHR_FILES
                      || (S_ISCHR(perm)
                          && is_dev_fd_file(curbuf->b_ffname))
# endif
                      )) {
      read_fifo = true;
    }
    if (read_fifo) {
      curbuf->b_p_bin = true;
    }
#endif

    retval = readfile(curbuf->b_ffname, curbuf->b_fname,
                      0, 0, (linenr_T)MAXLNUM, eap,
                      flags | READ_NEW | (read_fifo ? READ_FIFO : 0), silent);
#ifdef UNIX
    if (read_fifo) {
      curbuf->b_p_bin = save_bin;
      if (retval == OK) {
        // don't add READ_FIFO here, otherwise we won't be able to
        // detect the encoding
        retval = read_buffer(false, eap, flags);
      }
    }
#endif

    // Help buffer: populate *local-additions* in help.txt
    if (bt_help(curbuf)) {
      get_local_additions();
    }
  } else if (read_stdin) {
    int save_bin = curbuf->b_p_bin;

    // First read the text in binary mode into the buffer.
    // Then read from that same buffer and append at the end.  This makes
    // it possible to retry when 'fileformat' or 'fileencoding' was
    // guessed wrong.
    curbuf->b_p_bin = true;
    retval = readfile(NULL, NULL, 0,
                      0, (linenr_T)MAXLNUM, NULL,
                      flags | (READ_NEW + READ_STDIN), silent);
    curbuf->b_p_bin = save_bin;
    if (retval == OK) {
      retval = read_buffer(true, eap, flags);
    }
  }

  // Can now sync this buffer in ml_sync_all().
  if (curbuf->b_ml.ml_mfp != NULL
      && curbuf->b_ml.ml_mfp->mf_dirty == MF_DIRTY_YES_NOSYNC) {
    curbuf->b_ml.ml_mfp->mf_dirty = MF_DIRTY_YES;
  }

  // if first time loading this buffer, init b_chartab[]
  if (curbuf->b_flags & BF_NEVERLOADED) {
    buf_init_chartab(curbuf, false);
    parse_cino(curbuf);
  }

  // Set/reset the Changed flag first, autocmds may change the buffer.
  // Apply the automatic commands, before processing the modelines.
  // So the modelines have priority over autocommands.

  // When reading stdin, the buffer contents always needs writing, so set
  // the changed flag.  Unless in readonly mode: "ls | nvim -R -".
  // When interrupted and 'cpoptions' contains 'i' set changed flag.
  if ((got_int && vim_strchr(p_cpo, CPO_INTMOD) != NULL)
      || curbuf->b_modified_was_set  // autocmd did ":set modified"
      || (aborting() && vim_strchr(p_cpo, CPO_INTMOD) != NULL)) {
    changed(curbuf);
  } else if (retval != FAIL && !read_stdin && !read_fifo) {
    unchanged(curbuf, false, true);
  }
  save_file_ff(curbuf);                 // keep this fileformat

  // Set last_changedtick to avoid triggering a TextChanged autocommand right
  // after it was added.
  curbuf->b_last_changedtick = buf_get_changedtick(curbuf);
  curbuf->b_last_changedtick_i = buf_get_changedtick(curbuf);
  curbuf->b_last_changedtick_pum = buf_get_changedtick(curbuf);

  // require "!" to overwrite the file, because it wasn't read completely
  if (aborting()) {
    curbuf->b_flags |= BF_READERR;
  }

  // Need to update automatic folding.  Do this before the autocommands,
  // they may use the fold info.
  foldUpdateAll(curwin);

  // need to set w_topline, unless some autocommand already did that.
  if (!(curwin->w_valid & VALID_TOPLINE)) {
    curwin->w_topline = 1;
    curwin->w_topfill = 0;
  }
  apply_autocmds_retval(EVENT_BUFENTER, NULL, NULL, false, curbuf, &retval);

  // if (retval != OK) {
  if (retval == FAIL) {
    return retval;
  }

  // The autocommands may have changed the current buffer.  Apply the
  // modelines to the correct buffer, if it still exists and is loaded.
  if (bufref_valid(&old_curbuf) && old_curbuf.br_buf->b_ml.ml_mfp != NULL) {
    aco_save_T aco;

    // Go to the buffer that was opened, make sure it is in a window.
    aucmd_prepbuf(&aco, old_curbuf.br_buf);
    do_modelines(0);
    curbuf->b_flags &= ~(BF_CHECK_RO | BF_NEVERLOADED);

    if ((flags & READ_NOWINENTER) == 0) {
      apply_autocmds_retval(EVENT_BUFWINENTER, NULL, NULL, false, curbuf,
                            &retval);
    }

    // restore curwin/curbuf and a few other things
    aucmd_restbuf(&aco);
  }

  return retval;
}

/// Store "buf" in "bufref" and set the free count.
///
/// @param bufref Reference to be used for the buffer.
/// @param buf    The buffer to reference.
void set_bufref(bufref_T *bufref, buf_T *buf)
{
  bufref->br_buf = buf;
  bufref->br_fnum = buf == NULL ? 0 : buf->b_fnum;
  bufref->br_buf_free_count = buf_free_count;
}

/// Return true if "bufref->br_buf" points to the same buffer as when
/// set_bufref() was called and it is a valid buffer.
/// Only goes through the buffer list if buf_free_count changed.
/// Also checks if b_fnum is still the same, a :bwipe followed by :new might get
/// the same allocated memory, but it's a different buffer.
///
/// @param bufref Buffer reference to check for.
bool bufref_valid(bufref_T *bufref)
  FUNC_ATTR_PURE
{
  return bufref->br_buf_free_count == buf_free_count
         ? true
         : buf_valid(bufref->br_buf) && bufref->br_fnum == bufref->br_buf->b_fnum;
}

/// Check that "buf" points to a valid buffer in the buffer list.
///
/// Can be slow if there are many buffers, prefer using bufref_valid().
///
/// @param buf The buffer to check for.
bool buf_valid(buf_T *buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (buf == NULL) {
    return false;
  }
  // Assume that we more often have a recent buffer,
  // start with the last one.
  for (buf_T *bp = lastbuf; bp != NULL; bp = bp->b_prev) {
    if (bp == buf) {
      return true;
    }
  }
  return false;
}

/// Return true when buffer "buf" can be unloaded.
/// Give an error message and return false when the buffer is locked or the
/// screen is being redrawn and the buffer is in a window.
static bool can_unload_buffer(buf_T *buf)
{
  bool can_unload = !buf->b_locked;

  if (can_unload && updating_screen) {
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp->w_buffer == buf) {
        can_unload = false;
        break;
      }
    }
  }
  if (!can_unload) {
    char *fname = buf->b_fname != NULL ? buf->b_fname : buf->b_ffname;
    semsg(_(e_attempt_to_delete_buffer_that_is_in_use_str),
          fname != NULL ? fname : "[No Name]");
  }
  return can_unload;
}

/// Close the link to a buffer.
///
/// @param win    If not NULL, set b_last_cursor.
/// @param buf
/// @param action Used when there is no longer a window for the buffer.
///               Possible values:
///                 0            buffer becomes hidden
///                 DOBUF_UNLOAD buffer is unloaded
///                 DOBUF_DEL    buffer is unloaded and removed from buffer list
///                 DOBUF_WIPE   buffer is unloaded and really deleted
///               When doing all but the first one on the current buffer, the
///               caller should get a new buffer very soon!
///               The 'bufhidden' option can force freeing and deleting.
/// @param abort_if_last
///               If true, do not close the buffer if autocommands cause
///               there to be only one window with this buffer. e.g. when
///               ":quit" is supposed to close the window but autocommands
///               close all other windows.
/// @param ignore_abort
///               If true, don't abort even when aborting() returns true.
/// @return  true when we got to the end and b_nwindows was decremented.
bool close_buffer(win_T *win, buf_T *buf, int action, bool abort_if_last, bool ignore_abort)
{
  bool unload_buf = (action != 0);
  bool del_buf = (action == DOBUF_DEL || action == DOBUF_WIPE);
  bool wipe_buf = (action == DOBUF_WIPE);

  bool is_curwin = (curwin != NULL && curwin->w_buffer == buf);
  win_T *the_curwin = curwin;
  tabpage_T *the_curtab = curtab;

  // Force unloading or deleting when 'bufhidden' says so, but not for terminal
  // buffers.
  // The caller must take care of NOT deleting/freeing when 'bufhidden' is
  // "hide" (otherwise we could never free or delete a buffer).
  if (!buf->terminal) {
    if (buf->b_p_bh[0] == 'd') {         // 'bufhidden' == "delete"
      del_buf = true;
      unload_buf = true;
    } else if (buf->b_p_bh[0] == 'w') {  // 'bufhidden' == "wipe"
      del_buf = true;
      unload_buf = true;
      wipe_buf = true;
    } else if (buf->b_p_bh[0] == 'u') {  // 'bufhidden' == "unload"
      unload_buf = true;
    }
  }

  if (buf->terminal && (unload_buf || del_buf || wipe_buf)) {
    // terminal buffers can only be wiped
    unload_buf = true;
    del_buf = true;
    wipe_buf = true;
  }

  // Disallow deleting the buffer when it is locked (already being closed or
  // halfway a command that relies on it). Unloading is allowed.
  if ((del_buf || wipe_buf) && !can_unload_buffer(buf)) {
    return false;
  }

  // check no autocommands closed the window
  if (win != NULL  // Avoid bogus clang warning.
      && win_valid_any_tab(win)) {
    // Set b_last_cursor when closing the last window for the buffer.
    // Remember the last cursor position and window options of the buffer.
    // This used to be only for the current window, but then options like
    // 'foldmethod' may be lost with a ":only" command.
    if (buf->b_nwindows == 1) {
      set_last_cursor(win);
    }
    buflist_setfpos(buf, win,
                    win->w_cursor.lnum == 1 ? 0 : win->w_cursor.lnum,
                    win->w_cursor.col, true);
  }

  bufref_T bufref;
  set_bufref(&bufref, buf);

  // When the buffer is no longer in a window, trigger BufWinLeave
  if (buf->b_nwindows == 1) {
    buf->b_locked++;
    buf->b_locked_split++;
    if (apply_autocmds(EVENT_BUFWINLEAVE, buf->b_fname, buf->b_fname, false,
                       buf) && !bufref_valid(&bufref)) {
      // Autocommands deleted the buffer.
      emsg(_(e_auabort));
      return false;
    }
    buf->b_locked--;
    buf->b_locked_split--;
    if (abort_if_last && one_window(win)) {
      // Autocommands made this the only window.
      emsg(_(e_auabort));
      return false;
    }

    // When the buffer becomes hidden, but is not unloaded, trigger
    // BufHidden
    if (!unload_buf) {
      buf->b_locked++;
      buf->b_locked_split++;
      if (apply_autocmds(EVENT_BUFHIDDEN, buf->b_fname, buf->b_fname, false,
                         buf) && !bufref_valid(&bufref)) {
        // Autocommands deleted the buffer.
        emsg(_(e_auabort));
        return false;
      }
      buf->b_locked--;
      buf->b_locked_split--;
      if (abort_if_last && one_window(win)) {
        // Autocommands made this the only window.
        emsg(_(e_auabort));
        return false;
      }
    }
    // autocmds may abort script processing
    if (!ignore_abort && aborting()) {
      return false;
    }
  }

  // If the buffer was in curwin and the window has changed, go back to that
  // window, if it still exists.  This avoids that ":edit x" triggering a
  // "tabnext" BufUnload autocmd leaves a window behind without a buffer.
  if (is_curwin && curwin != the_curwin && win_valid_any_tab(the_curwin)) {
    block_autocmds();
    goto_tabpage_win(the_curtab, the_curwin);
    unblock_autocmds();
  }

  int nwindows = buf->b_nwindows;

  // decrease the link count from windows (unless not in any window)
  if (buf->b_nwindows > 0) {
    buf->b_nwindows--;
  }

  if (diffopt_hiddenoff() && !unload_buf && buf->b_nwindows == 0) {
    diff_buf_delete(buf);   // Clear 'diff' for hidden buffer.
  }

  // Return when a window is displaying the buffer or when it's not
  // unloaded.
  if (buf->b_nwindows > 0 || !unload_buf) {
    return false;
  }

  if (buf->terminal) {
    buf->b_locked++;
    terminal_close(&buf->terminal, -1);
    buf->b_locked--;
  }

  // Always remove the buffer when there is no file name.
  if (buf->b_ffname == NULL) {
    del_buf = true;
  }

  // Free all things allocated for this buffer.
  // Also calls the "BufDelete" autocommands when del_buf is true.
  // Remember if we are closing the current buffer.  Restore the number of
  // windows, so that autocommands in buf_freeall() don't get confused.
  bool is_curbuf = (buf == curbuf);

  // When closing the current buffer stop Visual mode before freeing
  // anything.
  if (is_curbuf && VIsual_active
#if defined(EXITFREE)
      && !entered_free_all_mem
#endif
      ) {
    end_visual_mode();
  }

  buf->b_nwindows = nwindows;

  buf_freeall(buf, ((del_buf ? BFA_DEL : 0)
                    + (wipe_buf ? BFA_WIPE : 0)
                    + (ignore_abort ? BFA_IGNORE_ABORT : 0)));

  if (!bufref_valid(&bufref)) {
    // Autocommands may have deleted the buffer.
    return false;
  }
  // autocmds may abort script processing.
  if (!ignore_abort && aborting()) {
    return false;
  }

  // It's possible that autocommands change curbuf to the one being deleted.
  // This might cause the previous curbuf to be deleted unexpectedly.  But
  // in some cases it's OK to delete the curbuf, because a new one is
  // obtained anyway.  Therefore only return if curbuf changed to the
  // deleted buffer.
  if (buf == curbuf && !is_curbuf) {
    return false;
  }

  // Disable buffer-updates for the current buffer.
  // No need to check `unload_buf`: in that case the function returned above.
  buf_updates_unload(buf, false);

  if (win != NULL  // Avoid bogus clang warning.
      && win_valid_any_tab(win)
      && win->w_buffer == buf) {
    win->w_buffer = NULL;  // make sure we don't use the buffer now
  }

  // Autocommands may have opened or closed windows for this buffer.
  // Decrement the count for the close we do here.
  if (buf->b_nwindows > 0) {
    buf->b_nwindows--;
  }

  // Remove the buffer from the list.
  if (wipe_buf) {
    // Do not wipe out the buffer if it is used in a window.
    if (buf->b_nwindows > 0) {
      return false;
    }
    FOR_ALL_TAB_WINDOWS(tp, wp) {
      mark_forget_file(wp, buf->b_fnum);
    }
    if (buf->b_sfname != buf->b_ffname) {
      XFREE_CLEAR(buf->b_sfname);
    } else {
      buf->b_sfname = NULL;
    }
    XFREE_CLEAR(buf->b_ffname);
    if (buf->b_prev == NULL) {
      firstbuf = buf->b_next;
    } else {
      buf->b_prev->b_next = buf->b_next;
    }
    if (buf->b_next == NULL) {
      lastbuf = buf->b_prev;
    } else {
      buf->b_next->b_prev = buf->b_prev;
    }
    free_buffer(buf);
  } else {
    if (del_buf) {
      // Free all internal variables and reset option values, to make
      // ":bdel" compatible with Vim 5.7.
      free_buffer_stuff(buf, kBffClearWinInfo | kBffInitChangedtick);

      // Make it look like a new buffer.
      buf->b_flags = BF_CHECK_RO | BF_NEVERLOADED;

      // Init the options when loaded again.
      buf->b_p_initialized = false;
    }
    buf_clear_file(buf);
    if (del_buf) {
      buf->b_p_bl = false;
    }
  }
  // NOTE: at this point "curbuf" may be invalid!
  return true;
}

/// Make buffer not contain a file.
void buf_clear_file(buf_T *buf)
{
  buf->b_ml.ml_line_count = 1;
  unchanged(buf, true, true);
  buf->b_p_eof = false;
  buf->b_start_eof = false;
  buf->b_p_eol = true;
  buf->b_start_eol = true;
  buf->b_p_bomb = false;
  buf->b_start_bomb = false;
  buf->b_ml.ml_mfp = NULL;
  buf->b_ml.ml_flags = ML_EMPTY;                // empty buffer
}

/// Clears the current buffer contents.
void buf_clear(void)
{
  linenr_T line_count = curbuf->b_ml.ml_line_count;
  extmark_free_all(curbuf);   // delete any extmarks
  while (!(curbuf->b_ml.ml_flags & ML_EMPTY)) {
    ml_delete(1, false);
  }
  deleted_lines_mark(1, line_count);  // prepare for display
}

/// buf_freeall() - free all things allocated for a buffer that are related to
/// the file.  Careful: get here with "curwin" NULL when exiting.
///
/// @param flags BFA_DEL           buffer is going to be deleted
///              BFA_WIPE          buffer is going to be wiped out
///              BFA_KEEP_UNDO     do not free undo information
///              BFA_IGNORE_ABORT  don't abort even when aborting() returns true
void buf_freeall(buf_T *buf, int flags)
{
  bool is_curbuf = (buf == curbuf);
  int is_curwin = (curwin != NULL && curwin->w_buffer == buf);
  win_T *the_curwin = curwin;
  tabpage_T *the_curtab = curtab;

  // Make sure the buffer isn't closed by autocommands.
  buf->b_locked++;
  buf->b_locked_split++;

  bufref_T bufref;
  set_bufref(&bufref, buf);

  if ((buf->b_ml.ml_mfp != NULL)
      && apply_autocmds(EVENT_BUFUNLOAD, buf->b_fname, buf->b_fname, false, buf)
      && !bufref_valid(&bufref)) {
    // Autocommands deleted the buffer.
    return;
  }
  if ((flags & BFA_DEL)
      && buf->b_p_bl
      && apply_autocmds(EVENT_BUFDELETE, buf->b_fname, buf->b_fname, false, buf)
      && !bufref_valid(&bufref)) {
    // Autocommands may delete the buffer.
    return;
  }
  if ((flags & BFA_WIPE)
      && apply_autocmds(EVENT_BUFWIPEOUT, buf->b_fname, buf->b_fname, false,
                        buf)
      && !bufref_valid(&bufref)) {
    // Autocommands may delete the buffer.
    return;
  }
  buf->b_locked--;
  buf->b_locked_split--;

  // If the buffer was in curwin and the window has changed, go back to that
  // window, if it still exists.  This avoids that ":edit x" triggering a
  // "tabnext" BufUnload autocmd leaves a window behind without a buffer.
  if (is_curwin && curwin != the_curwin && win_valid_any_tab(the_curwin)) {
    block_autocmds();
    goto_tabpage_win(the_curtab, the_curwin);
    unblock_autocmds();
  }
  // autocmds may abort script processing
  if ((flags & BFA_IGNORE_ABORT) == 0 && aborting()) {
    return;
  }

  // It's possible that autocommands change curbuf to the one being deleted.
  // This might cause curbuf to be deleted unexpectedly.  But in some cases
  // it's OK to delete the curbuf, because a new one is obtained anyway.
  // Therefore only return if curbuf changed to the deleted buffer.
  if (buf == curbuf && !is_curbuf) {
    return;
  }
  diff_buf_delete(buf);             // Can't use 'diff' for unloaded buffer.
  // Remove any ownsyntax, unless exiting.
  if (curwin != NULL && curwin->w_buffer == buf) {
    reset_synblock(curwin);
  }

  // No folds in an empty buffer.
  FOR_ALL_TAB_WINDOWS(tp, win) {
    if (win->w_buffer == buf) {
      clearFolding(win);
    }
  }

  ml_close(buf, true);              // close and delete the memline/memfile
  buf->b_ml.ml_line_count = 0;      // no lines in buffer
  if ((flags & BFA_KEEP_UNDO) == 0) {
    // free the memory allocated for undo
    // and reset all undo information
    u_clearallandblockfree(buf);
  }
  syntax_clear(&buf->b_s);          // reset syntax info
  buf->b_flags &= ~BF_READERR;      // a read error is no longer relevant
}

/// Free a buffer structure and the things it contains related to the buffer
/// itself (not the file, that must have been done already).
static void free_buffer(buf_T *buf)
{
  pmap_del(int)(&buffer_handles, buf->b_fnum, NULL);
  buf_free_count++;
  // b:changedtick uses an item in buf_T.
  free_buffer_stuff(buf, kBffClearWinInfo);
  if (buf->b_vars->dv_refcount > DO_NOT_FREE_CNT) {
    tv_dict_add(buf->b_vars,
                tv_dict_item_copy((dictitem_T *)(&buf->changedtick_di)));
  }
  unref_var_dict(buf->b_vars);
  aubuflocal_remove(buf);
  xfree(buf->additional_data);
  xfree(buf->b_prompt_text);
  kv_destroy(buf->b_wininfo);
  callback_free(&buf->b_prompt_callback);
  callback_free(&buf->b_prompt_interrupt);
  clear_fmark(&buf->b_last_cursor, 0);
  clear_fmark(&buf->b_last_insert, 0);
  clear_fmark(&buf->b_last_change, 0);
  clear_fmark(&buf->b_prompt_start, 0);
  for (size_t i = 0; i < NMARKS; i++) {
    free_fmark(buf->b_namedm[i]);
  }
  for (int i = 0; i < buf->b_changelistlen; i++) {
    free_fmark(buf->b_changelist[i]);
  }
  if (autocmd_busy) {
    // Do not free the buffer structure while autocommands are executing,
    // it's still needed. Free it when autocmd_busy is reset.
    CLEAR_FIELD(buf->b_namedm);
    CLEAR_FIELD(buf->b_changelist);
    buf->b_next = au_pending_free_buf;
    au_pending_free_buf = buf;
  } else {
    xfree(buf);
  }
}

/// Free the b_wininfo list for buffer "buf".
static void clear_wininfo(buf_T *buf)
{
  for (size_t i = 0; i < kv_size(buf->b_wininfo); i++) {
    free_wininfo(kv_A(buf->b_wininfo, i), buf);
  }
  kv_size(buf->b_wininfo) = 0;
}

/// Free stuff in the buffer for ":bdel" and when wiping out the buffer.
///
/// @param buf  Buffer pointer
/// @param free_flags  BufFreeFlags
static void free_buffer_stuff(buf_T *buf, int free_flags)
{
  if (free_flags & kBffClearWinInfo) {
    clear_wininfo(buf);                 // including window-local options
    free_buf_options(buf, true);
    ga_clear(&buf->b_s.b_langp);
  }
  {
    // Avoid losing b:changedtick when deleting buffer: clearing variables
    // implies using clear_tv() on b:changedtick and that sets changedtick to
    // zero.
    hashitem_T *const changedtick_hi = hash_find(&buf->b_vars->dv_hashtab, "changedtick");
    assert(changedtick_hi != NULL);
    hash_remove(&buf->b_vars->dv_hashtab, changedtick_hi);
  }
  vars_clear(&buf->b_vars->dv_hashtab);   // free all internal variables
  hash_init(&buf->b_vars->dv_hashtab);
  if (free_flags & kBffInitChangedtick) {
    buf_init_changedtick(buf);
  }
  uc_clear(&buf->b_ucmds);               // clear local user commands
  extmark_free_all(buf);                 // delete any extmarks
  map_clear_mode(buf, MAP_ALL_MODES, true, false);  // clear local mappings
  map_clear_mode(buf, MAP_ALL_MODES, true, true);   // clear local abbrevs
  XFREE_CLEAR(buf->b_start_fenc);

  buf_updates_unload(buf, false);
}

/// Go to another buffer.  Handles the result of the ATTENTION dialog.
void goto_buffer(exarg_T *eap, int start, int dir, int count)
{
  const int save_sea = swap_exists_action;
  bool skip_help_buf;

  switch (eap->cmdidx) {
  case CMD_bnext:
  case CMD_sbnext:
  case CMD_bNext:
  case CMD_bprevious:
  case CMD_sbNext:
  case CMD_sbprevious:
    skip_help_buf = true;
    break;
  default:
    skip_help_buf = false;
    break;
  }

  bufref_T old_curbuf;
  set_bufref(&old_curbuf, curbuf);

  if (swap_exists_action == SEA_NONE) {
    swap_exists_action = SEA_DIALOG;
  }
  (void)do_buffer_ext(*eap->cmd == 's' ? DOBUF_SPLIT : DOBUF_GOTO, start, dir, count,
                      (eap->forceit ? DOBUF_FORCEIT : 0) |
                      (skip_help_buf ? DOBUF_SKIPHELP : 0));

  if (swap_exists_action == SEA_QUIT && *eap->cmd == 's') {
    cleanup_T cs;

    // Reset the error/interrupt/exception state here so that
    // aborting() returns false when closing a window.
    enter_cleanup(&cs);

    // Quitting means closing the split window, nothing else.
    win_close(curwin, true, false);
    swap_exists_action = save_sea;
    swap_exists_did_quit = true;

    // Restore the error/interrupt/exception state if not discarded by a
    // new aborting error, interrupt, or uncaught exception.
    leave_cleanup(&cs);
  } else {
    handle_swap_exists(&old_curbuf);
  }
}

/// Handle the situation of swap_exists_action being set.
///
/// It is allowed for "old_curbuf" to be NULL or invalid.
///
/// @param old_curbuf The buffer to check for.
void handle_swap_exists(bufref_T *old_curbuf)
{
  cleanup_T cs;
  OptInt old_tw = curbuf->b_p_tw;
  buf_T *buf;

  if (swap_exists_action == SEA_QUIT) {
    // Reset the error/interrupt/exception state here so that
    // aborting() returns false when closing a buffer.
    enter_cleanup(&cs);

    // User selected Quit at ATTENTION prompt.  Go back to previous
    // buffer.  If that buffer is gone or the same as the current one,
    // open a new, empty buffer.
    swap_exists_action = SEA_NONE;      // don't want it again
    swap_exists_did_quit = true;
    close_buffer(curwin, curbuf, DOBUF_UNLOAD, false, false);
    if (old_curbuf == NULL
        || !bufref_valid(old_curbuf)
        || old_curbuf->br_buf == curbuf) {
      // Block autocommands here because curwin->w_buffer is NULL.
      block_autocmds();
      buf = buflist_new(NULL, NULL, 1, BLN_CURBUF | BLN_LISTED);
      unblock_autocmds();
    } else {
      buf = old_curbuf->br_buf;
    }
    if (buf != NULL) {
      enter_buffer(buf);

      if (old_tw != curbuf->b_p_tw) {
        check_colorcolumn(NULL, curwin);
      }
    }
    // If "old_curbuf" is NULL we are in big trouble here...

    // Restore the error/interrupt/exception state if not discarded by a
    // new aborting error, interrupt, or uncaught exception.
    leave_cleanup(&cs);
  } else if (swap_exists_action == SEA_RECOVER) {
    // Reset the error/interrupt/exception state here so that
    // aborting() returns false when closing a buffer.
    enter_cleanup(&cs);

    // User selected Recover at ATTENTION prompt.
    msg_scroll = true;
    ml_recover(false);
    msg_puts("\n");     // don't overwrite the last message
    cmdline_row = msg_row;
    do_modelines(0);

    // Restore the error/interrupt/exception state if not discarded by a
    // new aborting error, interrupt, or uncaught exception.
    leave_cleanup(&cs);
  }
  swap_exists_action = SEA_NONE;
}

/// do_bufdel() - delete or unload buffer(s)
///
/// addr_count == 0: ":bdel" - delete current buffer
/// addr_count == 1: ":N bdel" or ":bdel N [N ..]" - first delete
///                  buffer "end_bnr", then any other arguments.
/// addr_count == 2: ":N,N bdel" - delete buffers in range
///
/// command can be DOBUF_UNLOAD (":bunload"), DOBUF_WIPE (":bwipeout") or
/// DOBUF_DEL (":bdel")
///
/// @param arg  pointer to extra arguments
/// @param start_bnr  first buffer number in a range
/// @param end_bnr  buffer nr or last buffer nr in a range
///
/// @return  error message or NULL
char *do_bufdel(int command, char *arg, int addr_count, int start_bnr, int end_bnr, int forceit)
{
  int do_current = 0;             // delete current buffer?
  int deleted = 0;                // number of buffers deleted
  char *errormsg = NULL;          // return value
  int bnr;                        // buffer number

  if (addr_count == 0) {
    do_buffer(command, DOBUF_CURRENT, FORWARD, 0, forceit);
  } else {
    if (addr_count == 2) {
      if (*arg) {               // both range and argument is not allowed
        return ex_errmsg(e_trailing_arg, arg);
      }
      bnr = start_bnr;
    } else {    // addr_count == 1
      bnr = end_bnr;
    }

    for (; !got_int; os_breakcheck()) {
      // delete the current buffer last, otherwise when the
      // current buffer is deleted, the next buffer becomes
      // the current one and will be loaded, which may then
      // also be deleted, etc.
      if (bnr == curbuf->b_fnum) {
        do_current = bnr;
      } else if (do_buffer(command, DOBUF_FIRST, FORWARD, bnr,
                           forceit) == OK) {
        deleted++;
      }

      // find next buffer number to delete/unload
      if (addr_count == 2) {
        if (++bnr > end_bnr) {
          break;
        }
      } else {    // addr_count == 1
        arg = skipwhite(arg);
        if (*arg == NUL) {
          break;
        }
        if (!ascii_isdigit(*arg)) {
          char *p = skiptowhite_esc(arg);
          bnr = buflist_findpat(arg, p, command == DOBUF_WIPE, false, false);
          if (bnr < 0) {                    // failed
            break;
          }
          arg = p;
        } else {
          bnr = getdigits_int(&arg, false, 0);
        }
      }
    }
    if (!got_int && do_current
        && do_buffer(command, DOBUF_FIRST,
                     FORWARD, do_current, forceit) == OK) {
      deleted++;
    }

    if (deleted == 0) {
      if (command == DOBUF_UNLOAD) {
        xstrlcpy(IObuff, _("E515: No buffers were unloaded"), IOSIZE);
      } else if (command == DOBUF_DEL) {
        xstrlcpy(IObuff, _("E516: No buffers were deleted"), IOSIZE);
      } else {
        xstrlcpy(IObuff, _("E517: No buffers were wiped out"), IOSIZE);
      }
      errormsg = IObuff;
    } else if (deleted >= p_report) {
      if (command == DOBUF_UNLOAD) {
        smsg(0, NGETTEXT("%d buffer unloaded", "%d buffers unloaded", deleted),
             deleted);
      } else if (command == DOBUF_DEL) {
        smsg(0, NGETTEXT("%d buffer deleted", "%d buffers deleted", deleted),
             deleted);
      } else {
        smsg(0, NGETTEXT("%d buffer wiped out", "%d buffers wiped out", deleted),
             deleted);
      }
    }
  }

  return errormsg;
}

/// Make the current buffer empty.
/// Used when it is wiped out and it's the last buffer.
static int empty_curbuf(bool close_others, int forceit, int action)
{
  buf_T *buf = curbuf;

  if (action == DOBUF_UNLOAD) {
    emsg(_("E90: Cannot unload last buffer"));
    return FAIL;
  }

  bufref_T bufref;
  set_bufref(&bufref, buf);

  if (close_others) {
    bool can_close_all_others = true;
    if (curwin->w_floating) {
      // Closing all other windows with this buffer may leave only floating windows.
      can_close_all_others = false;
      for (win_T *wp = firstwin; !wp->w_floating; wp = wp->w_next) {
        if (wp->w_buffer != curbuf) {
          // Found another non-floating window with a different (probably unlisted) buffer.
          // Closing all other windows with this buffer is fine in this case.
          can_close_all_others = true;
          break;
        }
      }
    }
    // If it is fine to close all other windows with this buffer, keep the current window and
    // close any other windows with this buffer, then make it empty.
    // Otherwise close_windows() will refuse to close the last non-floating window, so allow it
    // to close the current window instead.
    close_windows(buf, can_close_all_others);
  }

  setpcmark();
  int retval = do_ecmd(0, NULL, NULL, NULL, ECMD_ONE, forceit ? ECMD_FORCEIT : 0, curwin);

  // do_ecmd() may create a new buffer, then we have to delete
  // the old one.  But do_ecmd() may have done that already, check
  // if the buffer still exists.
  if (buf != curbuf && bufref_valid(&bufref) && buf->b_nwindows == 0) {
    close_buffer(NULL, buf, action, false, false);
  }

  if (!close_others) {
    need_fileinfo = false;
  }

  return retval;
}

/// Implementation of the commands for the buffer list.
///
/// action == DOBUF_GOTO     go to specified buffer
/// action == DOBUF_SPLIT    split window and go to specified buffer
/// action == DOBUF_UNLOAD   unload specified buffer(s)
/// action == DOBUF_DEL      delete specified buffer(s) from buffer list
/// action == DOBUF_WIPE     delete specified buffer(s) really
///
/// start == DOBUF_CURRENT   go to "count" buffer from current buffer
/// start == DOBUF_FIRST     go to "count" buffer from first buffer
/// start == DOBUF_LAST      go to "count" buffer from last buffer
/// start == DOBUF_MOD       go to "count" modified buffer from current buffer
///
/// @param dir  FORWARD or BACKWARD
/// @param count  buffer number or number of buffers
/// @param flags  see @ref dobuf_flags_value
///
/// @return  FAIL or OK.
static int do_buffer_ext(int action, int start, int dir, int count, int flags)
{
  buf_T *buf;
  buf_T *bp;
  bool update_jumplist = true;
  bool unload = (action == DOBUF_UNLOAD || action == DOBUF_DEL
                 || action == DOBUF_WIPE);

  switch (start) {
  case DOBUF_FIRST:
    buf = firstbuf; break;
  case DOBUF_LAST:
    buf = lastbuf;  break;
  default:
    buf = curbuf;   break;
  }
  if (start == DOBUF_MOD) {         // find next modified buffer
    while (count-- > 0) {
      do {
        buf = buf->b_next;
        if (buf == NULL) {
          buf = firstbuf;
        }
      } while (buf != curbuf && !bufIsChanged(buf));
    }
    if (!bufIsChanged(buf)) {
      emsg(_("E84: No modified buffer found"));
      return FAIL;
    }
  } else if (start == DOBUF_FIRST && count) {  // find specified buffer number
    while (buf != NULL && buf->b_fnum != count) {
      buf = buf->b_next;
    }
  } else {
    bp = NULL;
    while (count > 0 || (!unload && !buf->b_p_bl && bp != buf)) {
      // remember the buffer where we start, we come back there when all
      // buffers are unlisted.
      if (bp == NULL) {
        bp = buf;
      }
      buf = dir == FORWARD ? (buf->b_next != NULL ? buf->b_next : firstbuf)
                           : (buf->b_prev != NULL ? buf->b_prev : lastbuf);
      // Don't count unlisted buffers.
      // Avoid non-help buffers if the starting point was a non-help buffer and
      // vice-versa.
      if (unload
          || (buf->b_p_bl
              && ((flags & DOBUF_SKIPHELP) == 0 || buf->b_help == bp->b_help))) {
        count--;
        bp = NULL;              // use this buffer as new starting point
      }
      if (bp == buf) {
        // back where we started, didn't find anything.
        emsg(_("E85: There is no listed buffer"));
        return FAIL;
      }
    }
  }

  if (buf == NULL) {        // could not find it
    if (start == DOBUF_FIRST) {
      // don't warn when deleting
      if (!unload) {
        semsg(_(e_nobufnr), (int64_t)count);
      }
    } else if (dir == FORWARD) {
      emsg(_("E87: Cannot go beyond last buffer"));
    } else {
      emsg(_("E88: Cannot go before first buffer"));
    }
    return FAIL;
  }

  if (action == DOBUF_GOTO && buf != curbuf) {
    if (!check_can_set_curbuf_forceit((flags & DOBUF_FORCEIT) != 0)) {
      // disallow navigating to another buffer when 'winfixbuf' is applied
      return FAIL;
    }
    if (buf->b_locked_split) {
      // disallow navigating to a closing buffer, which like splitting,
      // can result in more windows displaying it
      emsg(_(e_cannot_switch_to_a_closing_buffer));
      return FAIL;
    }
  }

  if ((action == DOBUF_GOTO || action == DOBUF_SPLIT) && (buf->b_flags & BF_DUMMY)) {
    // disallow navigating to the dummy buffer
    semsg(_(e_nobufnr), count);
    return FAIL;
  }

  // delete buffer "buf" from memory and/or the list
  if (unload) {
    int forward;
    bufref_T bufref;
    if (!can_unload_buffer(buf)) {
      return FAIL;
    }
    set_bufref(&bufref, buf);

    // When unloading or deleting a buffer that's already unloaded and
    // unlisted: fail silently.
    if (action != DOBUF_WIPE && buf->b_ml.ml_mfp == NULL && !buf->b_p_bl) {
      return FAIL;
    }

    if ((flags & DOBUF_FORCEIT) == 0 && bufIsChanged(buf)) {
      if ((p_confirm || (cmdmod.cmod_flags & CMOD_CONFIRM)) && p_write) {
        dialog_changed(buf, false);
        if (!bufref_valid(&bufref)) {
          // Autocommand deleted buffer, oops! It's not changed now.
          return FAIL;
        }
        // If it's still changed fail silently, the dialog already
        // mentioned why it fails.
        if (bufIsChanged(buf)) {
          return FAIL;
        }
      } else {
        semsg(_("E89: No write since last change for buffer %" PRId64
                " (add ! to override)"),
              (int64_t)buf->b_fnum);
        return FAIL;
      }
    }

    if (!(flags & DOBUF_FORCEIT) && buf->terminal && terminal_running(buf->terminal)) {
      if (p_confirm || (cmdmod.cmod_flags & CMOD_CONFIRM)) {
        if (!dialog_close_terminal(buf)) {
          return FAIL;
        }
      } else {
        semsg(_("E89: %s will be killed (add ! to override)"), buf->b_fname);
        return FAIL;
      }
    }

    int buf_fnum = buf->b_fnum;

    // When closing the current buffer stop Visual mode.
    if (buf == curbuf && VIsual_active) {
      end_visual_mode();
    }

    // If deleting the last (listed) buffer, make it empty.
    // The last (listed) buffer cannot be unloaded.
    bp = NULL;
    FOR_ALL_BUFFERS(bp2) {
      if (bp2->b_p_bl && bp2 != buf) {
        bp = bp2;
        break;
      }
    }
    if (bp == NULL && buf == curbuf) {
      return empty_curbuf(true, (flags & DOBUF_FORCEIT), action);
    }

    // If the deleted buffer is the current one, close the current window
    // (unless it's the only non-floating window).
    // When the autocommand window is involved win_close() may need to print an error message.
    // Repeat this so long as we end up in a window with this buffer.
    while (buf == curbuf
           && !(win_locked(curwin) || curwin->w_buffer->b_locked > 0)
           && (is_aucmd_win(lastwin) || !last_window(curwin))) {
      if (win_close(curwin, false, false) == FAIL) {
        break;
      }
    }

    // If the buffer to be deleted is not the current one, delete it here.
    if (buf != curbuf) {
      if (jop_flags & kOptJopFlagClean) {
        // Remove the buffer to be deleted from the jump list.
        mark_jumplist_forget_file(curwin, buf_fnum);
      }

      close_windows(buf, false);

      if (buf != curbuf && bufref_valid(&bufref) && buf->b_nwindows <= 0) {
        close_buffer(NULL, buf, action, false, false);
      }
      return OK;
    }

    // Deleting the current buffer: Need to find another buffer to go to.
    // There should be another, otherwise it would have been handled
    // above.  However, autocommands may have deleted all buffers.
    // First use au_new_curbuf.br_buf, if it is valid.
    // Then prefer the buffer we most recently visited.
    // Else try to find one that is loaded, after the current buffer,
    // then before the current buffer.
    // Finally use any buffer.
    buf = NULL;  // Selected buffer.
    bp = NULL;   // Used when no loaded buffer found.
    if (au_new_curbuf.br_buf != NULL && bufref_valid(&au_new_curbuf)) {
      buf = au_new_curbuf.br_buf;
    } else if (curwin->w_jumplistlen > 0) {
      if (jop_flags & kOptJopFlagClean) {
        // Remove the buffer from the jump list.
        mark_jumplist_forget_file(curwin, buf_fnum);
      }

      // It's possible that we removed all jump list entries, in that case we need to try another
      // approach
      if (curwin->w_jumplistlen > 0) {
        int jumpidx = curwin->w_jumplistidx;

        if (jop_flags & kOptJopFlagClean) {
          // If the index is the same as the length, the current position was not yet added to the
          // jump list. So we can safely go back to the last entry and search from there.
          if (jumpidx == curwin->w_jumplistlen) {
            jumpidx = curwin->w_jumplistidx = curwin->w_jumplistlen - 1;
          }
        } else {
          jumpidx--;
          if (jumpidx < 0) {
            jumpidx = curwin->w_jumplistlen - 1;
          }
        }

        forward = jumpidx;
        while ((jop_flags & kOptJopFlagClean) || jumpidx != curwin->w_jumplistidx) {
          buf = buflist_findnr(curwin->w_jumplist[jumpidx].fmark.fnum);

          if (buf != NULL) {
            // Skip current and unlisted bufs.  Also skip a quickfix
            // buffer, it might be deleted soon.
            if (buf == curbuf || !buf->b_p_bl || bt_quickfix(buf)) {
              buf = NULL;
            } else if (buf->b_ml.ml_mfp == NULL) {
              // skip unloaded buf, but may keep it for later
              if (bp == NULL) {
                bp = buf;
              }
              buf = NULL;
            }
          }
          if (buf != NULL) {         // found a valid buffer: stop searching
            if (jop_flags & kOptJopFlagClean) {
              curwin->w_jumplistidx = jumpidx;
              update_jumplist = false;
            }
            break;
          }
          // advance to older entry in jump list
          if (!jumpidx && curwin->w_jumplistidx == curwin->w_jumplistlen) {
            break;
          }
          if (--jumpidx < 0) {
            jumpidx = curwin->w_jumplistlen - 1;
          }
          if (jumpidx == forward) {               // List exhausted for sure
            break;
          }
        }
      }
    }

    if (buf == NULL) {          // No previous buffer, Try 2'nd approach
      forward = true;
      buf = curbuf->b_next;
      while (true) {
        if (buf == NULL) {
          if (!forward) {               // tried both directions
            break;
          }
          buf = curbuf->b_prev;
          forward = false;
          continue;
        }
        // in non-help buffer, try to skip help buffers, and vv
        if (buf->b_help == curbuf->b_help && buf->b_p_bl && !bt_quickfix(buf)) {
          if (buf->b_ml.ml_mfp != NULL) {           // found loaded buffer
            break;
          }
          if (bp == NULL) {             // remember unloaded buf for later
            bp = buf;
          }
        }
        buf = forward ? buf->b_next : buf->b_prev;
      }
    }
    if (buf == NULL) {          // No loaded buffer, use unloaded one
      buf = bp;
    }
    if (buf == NULL) {          // No loaded buffer, find listed one
      FOR_ALL_BUFFERS(buf2) {
        if (buf2->b_p_bl && buf2 != curbuf && !bt_quickfix(buf2)) {
          buf = buf2;
          break;
        }
      }
    }
    if (buf == NULL) {          // Still no buffer, just take one
      buf = curbuf->b_next != NULL ? curbuf->b_next : curbuf->b_prev;
      if (bt_quickfix(buf)) {
        buf = NULL;
      }
    }
  }

  if (buf == NULL) {
    // Autocommands must have wiped out all other buffers.  Only option
    // now is to make the current buffer empty.
    return empty_curbuf(false, (flags & DOBUF_FORCEIT), action);
  }

  // make "buf" the current buffer
  if (action == DOBUF_SPLIT) {      // split window first
    // If 'switchbuf' is set jump to the window containing "buf".
    if (swbuf_goto_win_with_buf(buf) != NULL) {
      return OK;
    }

    if (win_split(0, 0) == FAIL) {
      return FAIL;
    }
  }

  // go to current buffer - nothing to do
  if (buf == curbuf) {
    return OK;
  }

  // Check if the current buffer may be abandoned.
  if (action == DOBUF_GOTO && !can_abandon(curbuf, (flags & DOBUF_FORCEIT))) {
    if ((p_confirm || (cmdmod.cmod_flags & CMOD_CONFIRM)) && p_write) {
      bufref_T bufref;
      set_bufref(&bufref, buf);
      dialog_changed(curbuf, false);
      if (!bufref_valid(&bufref)) {
        // Autocommand deleted buffer, oops!
        return FAIL;
      }
    }
    if (bufIsChanged(curbuf)) {
      no_write_message();
      return FAIL;
    }
  }

  // Go to the other buffer.
  set_curbuf(buf, action, update_jumplist);

  if (action == DOBUF_SPLIT) {
    RESET_BINDING(curwin);      // reset 'scrollbind' and 'cursorbind'
  }

  if (aborting()) {         // autocmds may abort script processing
    return FAIL;
  }

  return OK;
}

int do_buffer(int action, int start, int dir, int count, int forceit)
{
  return do_buffer_ext(action, start, dir, count, forceit ? DOBUF_FORCEIT : 0);
}

/// Set current buffer to "buf".  Executes autocommands and closes current
/// buffer.
///
/// @param action  tells how to close the current buffer:
///                DOBUF_GOTO       free or hide it
///                DOBUF_SPLIT      nothing
///                DOBUF_UNLOAD     unload it
///                DOBUF_DEL        delete it
///                DOBUF_WIPE       wipe it out
void set_curbuf(buf_T *buf, int action, bool update_jumplist)
{
  buf_T *prevbuf;
  int unload = (action == DOBUF_UNLOAD || action == DOBUF_DEL
                || action == DOBUF_WIPE);
  OptInt old_tw = curbuf->b_p_tw;
  const int last_winid = get_last_winid();

  if (update_jumplist) {
    setpcmark();
  }

  if ((cmdmod.cmod_flags & CMOD_KEEPALT) == 0) {
    curwin->w_alt_fnum = curbuf->b_fnum;     // remember alternate file
  }
  buflist_altfpos(curwin);                       // remember curpos

  // Don't restart Select mode after switching to another buffer.
  VIsual_reselect = false;

  // close_windows() or apply_autocmds() may change curbuf and wipe out "buf"
  prevbuf = curbuf;
  bufref_T newbufref;
  bufref_T prevbufref;
  set_bufref(&prevbufref, prevbuf);
  set_bufref(&newbufref, buf);

  // Autocommands may delete the current buffer and/or the buffer we want to
  // go to.  In those cases don't close the buffer.
  if (!apply_autocmds(EVENT_BUFLEAVE, NULL, NULL, false, curbuf)
      || (bufref_valid(&prevbufref) && bufref_valid(&newbufref)
          && !aborting())) {
    if (prevbuf == curwin->w_buffer) {
      reset_synblock(curwin);
    }
    // autocommands may have opened a new window
    // with prevbuf, grr
    if (unload
        || (last_winid != get_last_winid()
            && strchr("wdu", prevbuf->b_p_bh[0]) != NULL)) {
      close_windows(prevbuf, false);
    }
    if (bufref_valid(&prevbufref) && !aborting()) {
      win_T *previouswin = curwin;

      // Do not sync when in Insert mode and the buffer is open in
      // another window, might be a timer doing something in another
      // window.
      if (prevbuf == curbuf && ((State & MODE_INSERT) == 0 || curbuf->b_nwindows <= 1)) {
        u_sync(false);
      }
      close_buffer(prevbuf == curwin->w_buffer ? curwin : NULL,
                   prevbuf,
                   unload
                   ? action
                   : (action == DOBUF_GOTO && !buf_hide(prevbuf)
                      && !bufIsChanged(prevbuf)) ? DOBUF_UNLOAD : 0,
                   false, false);
      if (curwin != previouswin && win_valid(previouswin)) {
        // autocommands changed curwin, Grr!
        curwin = previouswin;
      }
    }
  }
  // An autocommand may have deleted "buf", already entered it (e.g., when
  // it did ":bunload") or aborted the script processing!
  // If curwin->w_buffer is null, enter_buffer() will make it valid again
  bool valid = buf_valid(buf);
  if ((valid && buf != curbuf && !aborting()) || curwin->w_buffer == NULL) {
    // autocommands changed curbuf and we will move to another
    // buffer soon, so decrement curbuf->b_nwindows
    if (curbuf != NULL && prevbuf != curbuf) {
      curbuf->b_nwindows--;
    }
    // If the buffer is not valid but curwin->w_buffer is NULL we must
    // enter some buffer.  Using the last one is hopefully OK.
    enter_buffer(valid ? buf : lastbuf);
    if (old_tw != curbuf->b_p_tw) {
      check_colorcolumn(NULL, curwin);
    }
  }

  if (bufref_valid(&prevbufref) && prevbuf->terminal != NULL) {
    terminal_check_size(prevbuf->terminal);
  }
}

/// Enter a new current buffer.
/// Old curbuf must have been abandoned already!  This also means "curbuf" may
/// be pointing to freed memory.
static void enter_buffer(buf_T *buf)
{
  // when closing the current buffer stop Visual mode
  if (VIsual_active
#if defined(EXITFREE)
      && !entered_free_all_mem
#endif
      ) {
    end_visual_mode();
  }

  // Get the buffer in the current window.
  curwin->w_buffer = buf;
  curbuf = buf;
  curbuf->b_nwindows++;

  // Copy buffer and window local option values.  Not for a help buffer.
  buf_copy_options(buf, BCO_ENTER | BCO_NOHELP);
  if (!buf->b_help) {
    get_winopts(buf);
  } else {
    // Remove all folds in the window.
    clearFolding(curwin);
  }
  foldUpdateAll(curwin);        // update folds (later).

  if (curwin->w_p_diff) {
    diff_buf_add(curbuf);
  }

  curwin->w_s = &(curbuf->b_s);

  // Cursor on first line by default.
  curwin->w_cursor.lnum = 1;
  curwin->w_cursor.col = 0;
  curwin->w_cursor.coladd = 0;
  curwin->w_set_curswant = true;
  curwin->w_topline_was_set = false;

  // mark cursor position as being invalid
  curwin->w_valid = 0;

  // Make sure the buffer is loaded.
  if (curbuf->b_ml.ml_mfp == NULL) {    // need to load the file
    // If there is no filetype, allow for detecting one.  Esp. useful for
    // ":ball" used in an autocommand.  If there already is a filetype we
    // might prefer to keep it.
    if (*curbuf->b_p_ft == NUL) {
      curbuf->b_did_filetype = false;
    }

    open_buffer(false, NULL, 0);
  } else {
    if (!msg_silent && !shortmess(SHM_FILEINFO)) {
      need_fileinfo = true;             // display file info after redraw
    }
    // check if file changed
    buf_check_timestamp(curbuf);

    curwin->w_topline = 1;
    curwin->w_topfill = 0;
    apply_autocmds(EVENT_BUFENTER, NULL, NULL, false, curbuf);
    apply_autocmds(EVENT_BUFWINENTER, NULL, NULL, false, curbuf);
  }

  // If autocommands did not change the cursor position, restore cursor lnum
  // and possibly cursor col.
  if (curwin->w_cursor.lnum == 1 && inindent(0)) {
    buflist_getfpos();
  }

  check_arg_idx(curwin);                // check for valid arg_idx
  maketitle();
  // when autocmds didn't change it
  if (curwin->w_topline == 1 && !curwin->w_topline_was_set) {
    scroll_cursor_halfway(curwin, false, false);  // redisplay at correct position
  }

  // Change directories when the 'acd' option is set.
  do_autochdir();

  if (curbuf->b_kmap_state & KEYMAP_INIT) {
    keymap_init();
  }
  // May need to set the spell language.  Can only do this after the buffer
  // has been properly setup.
  if (!curbuf->b_help && curwin->w_p_spell && *curwin->w_s->b_p_spl != NUL) {
    parse_spelllang(curwin);
  }
  curbuf->b_last_used = time(NULL);

  if (curbuf->terminal != NULL) {
    terminal_check_size(curbuf->terminal);
  }

  redraw_later(curwin, UPD_NOT_VALID);
}

/// Change to the directory of the current buffer.
/// Don't do this while still starting up.
void do_autochdir(void)
{
  if (p_acd) {
    if (starting == 0
        && curbuf->b_ffname != NULL
        && vim_chdirfile(curbuf->b_ffname, kCdCauseAuto) == OK) {
      last_chdir_reason = "autochdir";
      shorten_fnames(true);
    }
  }
}

void no_write_message(void)
{
  if (curbuf->terminal
      && channel_job_running((uint64_t)curbuf->b_p_channel)) {
    emsg(_("E948: Job still running (add ! to end the job)"));
  } else {
    emsg(_("E37: No write since last change (add ! to override)"));
  }
}

void no_write_message_nobang(const buf_T *const buf)
  FUNC_ATTR_NONNULL_ALL
{
  if (buf->terminal
      && channel_job_running((uint64_t)buf->b_p_channel)) {
    emsg(_("E948: Job still running"));
  } else {
    emsg(_("E37: No write since last change"));
  }
}

//
// functions for dealing with the buffer list
//

/// Initialize b:changedtick and changedtick_val attribute
///
/// @param[out]  buf  Buffer to initialize for.
static inline void buf_init_changedtick(buf_T *const buf)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  STATIC_ASSERT(sizeof("changedtick") <= sizeof(buf->changedtick_di.di_key),
                "buf->changedtick_di cannot hold large enough keys");
  buf->changedtick_di = (ChangedtickDictItem) {
    .di_flags = DI_FLAGS_RO|DI_FLAGS_FIX,  // Must not include DI_FLAGS_ALLOC.
    .di_tv = (typval_T) {
      .v_type = VAR_NUMBER,
      .v_lock = VAR_FIXED,
      .vval.v_number = buf_get_changedtick(buf),
    },
    .di_key = "changedtick",
  };
  tv_dict_add(buf->b_vars, (dictitem_T *)&buf->changedtick_di);
}

/// Add a file name to the buffer list.
/// If the same file name already exists return a pointer to that buffer.
/// If it does not exist, or if fname == NULL, a new entry is created.
/// If (flags & BLN_CURBUF) is true, may use current buffer.
/// If (flags & BLN_LISTED) is true, add new buffer to buffer list.
/// If (flags & BLN_DUMMY) is true, don't count it as a real buffer.
/// If (flags & BLN_NEW) is true, don't use an existing buffer.
/// If (flags & BLN_NOOPT) is true, don't copy options from the current buffer
///                                 if the buffer already exists.
/// This is the ONLY way to create a new buffer.
///
/// @param ffname_arg  full path of fname or relative
/// @param sfname_arg  short fname or NULL
/// @param lnum   preferred cursor line
/// @param flags  BLN_ defines
/// @param bufnr
///
/// @return  pointer to the buffer
buf_T *buflist_new(char *ffname_arg, char *sfname_arg, linenr_T lnum, int flags)
{
  char *ffname = ffname_arg;
  char *sfname = sfname_arg;
  buf_T *buf;

  fname_expand(curbuf, &ffname, &sfname);       // will allocate ffname

  // If the file name already exists in the list, update the entry.

  // We can use inode numbers when the file exists.  Works better
  // for hard links.
  FileID file_id;
  bool file_id_valid = (sfname != NULL && os_fileid(sfname, &file_id));
  if (ffname != NULL && !(flags & (BLN_DUMMY | BLN_NEW))
      && (buf = buflist_findname_file_id(ffname, &file_id, file_id_valid)) != NULL) {
    xfree(ffname);
    if (lnum != 0) {
      buflist_setfpos(buf, (flags & BLN_NOCURWIN) ? NULL : curwin,
                      lnum, 0, false);
    }
    if ((flags & BLN_NOOPT) == 0) {
      // Copy the options now, if 'cpo' doesn't have 's' and not done already.
      buf_copy_options(buf, 0);
    }
    if ((flags & BLN_LISTED) && !buf->b_p_bl) {
      buf->b_p_bl = true;
      bufref_T bufref;
      set_bufref(&bufref, buf);
      if (!(flags & BLN_DUMMY)) {
        if (apply_autocmds(EVENT_BUFADD, NULL, NULL, false, buf)
            && !bufref_valid(&bufref)) {
          return NULL;
        }
      }
    }
    return buf;
  }

  // If the current buffer has no name and no contents, use the current
  // buffer.    Otherwise: Need to allocate a new buffer structure.
  //
  // This is the ONLY place where a new buffer structure is allocated!
  // (A spell file buffer is allocated in spell.c, but that's not a normal
  // buffer.)
  buf = NULL;
  if ((flags & BLN_CURBUF) && curbuf_reusable()) {
    bufref_T bufref;

    assert(curbuf != NULL);
    buf = curbuf;
    set_bufref(&bufref, buf);
    // It's like this buffer is deleted.  Watch out for autocommands that
    // change curbuf!  If that happens, allocate a new buffer anyway.
    buf_freeall(buf, BFA_WIPE | BFA_DEL);
    if (aborting()) {           // autocmds may abort script processing
      xfree(ffname);
      return NULL;
    }
    if (!bufref_valid(&bufref)) {
      buf = NULL;  // buf was deleted; allocate a new buffer
    }
  }
  if (buf != curbuf || curbuf == NULL) {
    buf = xcalloc(1, sizeof(buf_T));
    // init b: variables
    buf->b_vars = tv_dict_alloc();
    init_var_dict(buf->b_vars, &buf->b_bufvar, VAR_SCOPE);
    buf_init_changedtick(buf);
  }

  if (ffname != NULL) {
    buf->b_ffname = ffname;
    buf->b_sfname = xstrdup(sfname);
  }

  clear_wininfo(buf);
  WinInfo *curwin_info = xcalloc(1, sizeof(WinInfo));
  kv_push(buf->b_wininfo, curwin_info);

  if (buf == curbuf) {
    free_buffer_stuff(buf, kBffInitChangedtick);  // delete local vars et al.

    // Init the options.
    buf->b_p_initialized = false;
    buf_copy_options(buf, BCO_ENTER);

    // need to reload lmaps and set b:keymap_name
    curbuf->b_kmap_state |= KEYMAP_INIT;
  } else {
    // put new buffer at the end of the buffer list
    buf->b_next = NULL;
    if (firstbuf == NULL) {             // buffer list is empty
      buf->b_prev = NULL;
      firstbuf = buf;
    } else {                            // append new buffer at end of list
      lastbuf->b_next = buf;
      buf->b_prev = lastbuf;
    }
    lastbuf = buf;

    buf->b_fnum = top_file_num++;
    pmap_put(int)(&buffer_handles, buf->b_fnum, buf);
    if (top_file_num < 0) {  // wrap around (may cause duplicates)
      emsg(_("W14: Warning: List of file names overflow"));
      if (emsg_silent == 0 && !in_assert_fails && !ui_has(kUIMessages)) {
        ui_flush();
        os_delay(3001, true);  // make sure it is noticed
      }
      top_file_num = 1;
    }

    // Always copy the options from the current buffer.
    buf_copy_options(buf, BCO_ALWAYS);
  }

  curwin_info->wi_mark = (fmark_T)INIT_FMARK;
  curwin_info->wi_mark.mark.lnum = lnum;
  curwin_info->wi_win = curwin;

  hash_init(&buf->b_s.b_keywtab);
  hash_init(&buf->b_s.b_keywtab_ic);

  buf->b_fname = buf->b_sfname;
  if (!file_id_valid) {
    buf->file_id_valid = false;
  } else {
    buf->file_id_valid = true;
    buf->file_id = file_id;
  }
  buf->b_u_synced = true;
  buf->b_flags = BF_CHECK_RO | BF_NEVERLOADED;
  if (flags & BLN_DUMMY) {
    buf->b_flags |= BF_DUMMY;
  }
  buf_clear_file(buf);
  clrallmarks(buf, 0);                  // clear marks
  fmarks_check_names(buf);              // check file marks for this file
  buf->b_p_bl = (flags & BLN_LISTED) ? true : false;    // init 'buflisted'
  kv_destroy(buf->update_channels);
  kv_init(buf->update_channels);
  kv_destroy(buf->update_callbacks);
  kv_init(buf->update_callbacks);
  if (!(flags & BLN_DUMMY)) {
    // Tricky: these autocommands may change the buffer list.  They could also
    // split the window with re-using the one empty buffer. This may result in
    // unexpectedly losing the empty buffer.
    bufref_T bufref;
    set_bufref(&bufref, buf);
    if (apply_autocmds(EVENT_BUFNEW, NULL, NULL, false, buf)
        && !bufref_valid(&bufref)) {
      return NULL;
    }
    if ((flags & BLN_LISTED)
        && apply_autocmds(EVENT_BUFADD, NULL, NULL, false, buf)
        && !bufref_valid(&bufref)) {
      return NULL;
    }
    if (aborting()) {
      // Autocmds may abort script processing.
      return NULL;
    }
  }

  buf->b_prompt_callback.type = kCallbackNone;
  buf->b_prompt_interrupt.type = kCallbackNone;
  buf->b_prompt_text = NULL;
  clear_fmark(&buf->b_prompt_start, 0);

  return buf;
}

/// Return true if the current buffer is empty, unnamed, unmodified and used in
/// only one window. That means it can be reused.
bool curbuf_reusable(void)
{
  return (curbuf != NULL
          && curbuf->b_ffname == NULL
          && curbuf->b_nwindows <= 1
          && (curbuf->b_ml.ml_mfp == NULL || buf_is_empty(curbuf))
          && !bt_quickfix(curbuf)
          && !curbufIsChanged());
}

/// Free the memory for the options of a buffer.
/// If "free_p_ff" is true also free 'fileformat', 'buftype' and
/// 'fileencoding'.
void free_buf_options(buf_T *buf, bool free_p_ff)
{
  if (free_p_ff) {
    clear_string_option(&buf->b_p_fenc);
    clear_string_option(&buf->b_p_ff);
    clear_string_option(&buf->b_p_bh);
    clear_string_option(&buf->b_p_bt);
  }
  clear_string_option(&buf->b_p_def);
  clear_string_option(&buf->b_p_inc);
  clear_string_option(&buf->b_p_inex);
  clear_string_option(&buf->b_p_inde);
  clear_string_option(&buf->b_p_indk);
  clear_string_option(&buf->b_p_fp);
  clear_string_option(&buf->b_p_fex);
  clear_string_option(&buf->b_p_kp);
  clear_string_option(&buf->b_p_mps);
  clear_string_option(&buf->b_p_fo);
  clear_string_option(&buf->b_p_flp);
  clear_string_option(&buf->b_p_isk);
  clear_string_option(&buf->b_p_vsts);
  XFREE_CLEAR(buf->b_p_vsts_nopaste);
  XFREE_CLEAR(buf->b_p_vsts_array);
  clear_string_option(&buf->b_p_vts);
  XFREE_CLEAR(buf->b_p_vts_array);
  clear_string_option(&buf->b_p_keymap);
  keymap_ga_clear(&buf->b_kmap_ga);
  ga_clear(&buf->b_kmap_ga);
  clear_string_option(&buf->b_p_com);
  clear_string_option(&buf->b_p_cms);
  clear_string_option(&buf->b_p_nf);
  clear_string_option(&buf->b_p_syn);
  clear_string_option(&buf->b_s.b_syn_isk);
  clear_string_option(&buf->b_s.b_p_spc);
  clear_string_option(&buf->b_s.b_p_spf);
  vim_regfree(buf->b_s.b_cap_prog);
  buf->b_s.b_cap_prog = NULL;
  clear_string_option(&buf->b_s.b_p_spl);
  clear_string_option(&buf->b_s.b_p_spo);
  clear_string_option(&buf->b_p_sua);
  clear_string_option(&buf->b_p_ft);
  clear_string_option(&buf->b_p_cink);
  clear_string_option(&buf->b_p_cino);
  clear_string_option(&buf->b_p_lop);
  clear_string_option(&buf->b_p_cinsd);
  clear_string_option(&buf->b_p_cinw);
  clear_string_option(&buf->b_p_cot);
  clear_string_option(&buf->b_p_cpt);
  clear_string_option(&buf->b_p_ise);
  clear_string_option(&buf->b_p_cfu);
  callback_free(&buf->b_cfu_cb);
  clear_string_option(&buf->b_p_ofu);
  callback_free(&buf->b_ofu_cb);
  clear_string_option(&buf->b_p_tsrfu);
  callback_free(&buf->b_tsrfu_cb);
  clear_string_option(&buf->b_p_gefm);
  clear_string_option(&buf->b_p_gp);
  clear_string_option(&buf->b_p_mp);
  clear_string_option(&buf->b_p_efm);
  clear_string_option(&buf->b_p_ep);
  clear_string_option(&buf->b_p_path);
  clear_string_option(&buf->b_p_tags);
  clear_string_option(&buf->b_p_tc);
  clear_string_option(&buf->b_p_tfu);
  callback_free(&buf->b_tfu_cb);
  clear_string_option(&buf->b_p_ffu);
  callback_free(&buf->b_ffu_cb);
  clear_string_option(&buf->b_p_dict);
  clear_string_option(&buf->b_p_dia);
  clear_string_option(&buf->b_p_tsr);
  clear_string_option(&buf->b_p_qe);
  buf->b_p_ar = -1;
  buf->b_p_ul = NO_LOCAL_UNDOLEVEL;
  clear_string_option(&buf->b_p_lw);
  clear_string_option(&buf->b_p_bkc);
  clear_string_option(&buf->b_p_menc);
}

/// Get alternate file "n".
/// Set linenr to "lnum" or altfpos.lnum if "lnum" == 0.
/// Also set cursor column to altfpos.col if 'startofline' is not set.
/// if (options & GETF_SETMARK) call setpcmark()
/// if (options & GETF_ALT) we are jumping to an alternate file.
/// if (options & GETF_SWITCH) respect 'switchbuf' settings when jumping
///
/// Return FAIL for failure, OK for success.
int buflist_getfile(int n, linenr_T lnum, int options, int forceit)
{
  win_T *wp = NULL;
  fmark_T *fm = NULL;

  buf_T *buf = buflist_findnr(n);
  if (buf == NULL) {
    if ((options & GETF_ALT) && n == 0) {
      emsg(_(e_noalt));
    } else {
      semsg(_("E92: Buffer %" PRId64 " not found"), (int64_t)n);
    }
    return FAIL;
  }

  // if alternate file is the current buffer, nothing to do
  if (buf == curbuf) {
    return OK;
  }

  if (text_or_buf_locked()) {
    return FAIL;
  }

  colnr_T col;
  bool restore_view = false;
  // altfpos may be changed by getfile(), get it now
  if (lnum == 0) {
    fm = buflist_findfmark(buf);
    lnum = fm->mark.lnum;
    col = fm->mark.col;
    restore_view = true;
  } else {
    col = 0;
  }

  if (options & GETF_SWITCH) {
    // If 'switchbuf' is set jump to the window containing "buf".
    wp = swbuf_goto_win_with_buf(buf);

    // If 'switchbuf' contains "split", "vsplit" or "newtab" and the
    // current buffer isn't empty: open new tab or window
    if (wp == NULL && (swb_flags & (kOptSwbFlagVsplit | kOptSwbFlagSplit | kOptSwbFlagNewtab))
        && !buf_is_empty(curbuf)) {
      if (swb_flags & kOptSwbFlagNewtab) {
        tabpage_new();
      } else if (win_split(0, (swb_flags & kOptSwbFlagVsplit) ? WSP_VERT : 0)
                 == FAIL) {
        return FAIL;
      }
      RESET_BINDING(curwin);
    }
  }

  RedrawingDisabled++;
  if (GETFILE_SUCCESS(getfile(buf->b_fnum, NULL, NULL,
                              (options & GETF_SETMARK), lnum, forceit))) {
    RedrawingDisabled--;

    // cursor is at to BOL and w_cursor.lnum is checked due to getfile()
    if (!p_sol && col != 0) {
      curwin->w_cursor.col = col;
      check_cursor_col(curwin);
      curwin->w_cursor.coladd = 0;
      curwin->w_set_curswant = true;
    }
    if (jop_flags & kOptJopFlagView && restore_view) {
      mark_view_restore(fm);
    }
    return OK;
  }
  RedrawingDisabled--;
  return FAIL;
}

/// Go to the last known line number for the current buffer.
static void buflist_getfpos(void)
{
  pos_T *fpos = &buflist_findfmark(curbuf)->mark;

  curwin->w_cursor.lnum = fpos->lnum;
  check_cursor_lnum(curwin);

  if (p_sol) {
    curwin->w_cursor.col = 0;
  } else {
    curwin->w_cursor.col = fpos->col;
    check_cursor_col(curwin);
    curwin->w_cursor.coladd = 0;
    curwin->w_set_curswant = true;
  }
}

/// Find file in buffer list by name (it has to be for the current window).
///
/// @return  buffer or NULL if not found
buf_T *buflist_findname_exp(char *fname)
{
  buf_T *buf = NULL;

  // First make the name into a full path name
  char *ffname = FullName_save(fname,
#ifdef UNIX
                               // force expansion, get rid of symbolic links
                               true
#else
                               false
#endif
                               );
  if (ffname != NULL) {
    buf = buflist_findname(ffname);
    xfree(ffname);
  }
  return buf;
}

/// Find file in buffer list by name (it has to be for the current window).
/// "ffname" must have a full path.
/// Skips dummy buffers.
///
/// @return  buffer or NULL if not found
buf_T *buflist_findname(char *ffname)
{
  FileID file_id;
  bool file_id_valid = os_fileid(ffname, &file_id);
  return buflist_findname_file_id(ffname, &file_id, file_id_valid);
}

/// Same as buflist_findname(), but pass the FileID structure to avoid
/// getting it twice for the same file.
///
/// @return  buffer or NULL if not found
static buf_T *buflist_findname_file_id(char *ffname, FileID *file_id, bool file_id_valid)
  FUNC_ATTR_PURE
{
  // Start at the last buffer, expect to find a match sooner.
  FOR_ALL_BUFFERS_BACKWARDS(buf) {
    if ((buf->b_flags & BF_DUMMY) == 0
        && !otherfile_buf(buf, ffname, file_id, file_id_valid)) {
      return buf;
    }
  }
  return NULL;
}

/// Find file in buffer list by a regexp pattern.
///
/// @param pattern_end  pointer to first char after pattern
/// @param unlisted  find unlisted buffers
/// @param diffmode  find diff-mode buffers only
/// @param curtab_only  find buffers in current tab only
///
/// @return  fnum of the found buffer or < 0 for error.
int buflist_findpat(const char *pattern, const char *pattern_end, bool unlisted, bool diffmode,
                    bool curtab_only)
  FUNC_ATTR_NONNULL_ARG(1)
{
  int match = -1;

  if (pattern_end == pattern + 1 && (*pattern == '%' || *pattern == '#')) {
    match = *pattern == '%' ? curbuf->b_fnum : curwin->w_alt_fnum;
    buf_T *found_buf = buflist_findnr(match);
    if (diffmode && !(found_buf && diff_mode_buf(found_buf))) {
      match = -1;
    }
  } else {
    // Try four ways of matching a listed buffer:
    // attempt == 0: without '^' or '$' (at any position)
    // attempt == 1: with '^' at start (only at position 0)
    // attempt == 2: with '$' at end (only match at end)
    // attempt == 3: with '^' at start and '$' at end (only full match)
    // Repeat this for finding an unlisted buffer if there was no matching
    // listed buffer.

    char *pat = file_pat_to_reg_pat(pattern, pattern_end, NULL, false);
    if (pat == NULL) {
      return -1;
    }
    char *patend = pat + strlen(pat) - 1;
    bool toggledollar = (patend > pat && *patend == '$');

    // First try finding a listed buffer.  If not found and "unlisted"
    // is true, try finding an unlisted buffer.

    int find_listed = true;
    while (true) {
      for (int attempt = 0; attempt <= 3; attempt++) {
        // may add '^' and '$'
        if (toggledollar) {
          *patend = (attempt < 2) ? NUL : '$';           // add/remove '$'
        }
        char *p = pat;
        if (*p == '^' && !(attempt & 1)) {               // add/remove '^'
          p++;
        }

        regmatch_T regmatch;
        regmatch.regprog = vim_regcomp(p, magic_isset() ? RE_MAGIC : 0);

        FOR_ALL_BUFFERS_BACKWARDS(buf) {
          if (regmatch.regprog == NULL) {
            // invalid pattern, possibly after switching engine
            xfree(pat);
            return -1;
          }
          if (buf->b_p_bl == find_listed
              && (!diffmode || diff_mode_buf(buf))
              && buflist_match(&regmatch, buf, false) != NULL) {
            if (curtab_only) {
              // Ignore the match if the buffer is not open in
              // the current tab.
              bool found_window = false;
              FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
                if (wp->w_buffer == buf) {
                  found_window = true;
                  break;
                }
              }
              if (!found_window) {
                continue;
              }
            }
            if (match >= 0) {                   // already found a match
              match = -2;
              break;
            }
            match = buf->b_fnum;                // remember first match
          }
        }

        vim_regfree(regmatch.regprog);
        if (match >= 0) {                       // found one match
          break;
        }
      }

      // Only search for unlisted buffers if there was no match with
      // a listed buffer.
      if (!unlisted || !find_listed || match != -1) {
        break;
      }
      find_listed = false;
    }

    xfree(pat);
  }

  if (match == -2) {
    semsg(_("E93: More than one match for %s"), pattern);
  } else if (match < 0) {
    semsg(_("E94: No matching buffer for %s"), pattern);
  }
  return match;
}

typedef struct {
  buf_T *buf;
  char *match;
} bufmatch_T;

/// Compare functions for qsort() below, that compares b_last_used.
static int buf_time_compare(const void *s1, const void *s2)
{
  buf_T *buf1 = *(buf_T **)s1;
  buf_T *buf2 = *(buf_T **)s2;

  if (buf1->b_last_used == buf2->b_last_used) {
    return 0;
  }
  return buf1->b_last_used > buf2->b_last_used ? -1 : 1;
}

/// Find all buffer names that match.
/// For command line expansion of ":buf" and ":sbuf".
///
/// @return  OK if matches found, FAIL otherwise.
int ExpandBufnames(char *pat, int *num_file, char ***file, int options)
{
  bufmatch_T *matches = NULL;
  bool to_free = false;

  *num_file = 0;                    // return values in case of FAIL
  *file = NULL;

  if ((options & BUF_DIFF_FILTER) && !curwin->w_p_diff) {
    return FAIL;
  }

  const bool fuzzy = cmdline_fuzzy_complete(pat);

  char *patc = NULL;
  fuzmatch_str_T *fuzmatch = NULL;
  regmatch_T regmatch;

  // Make a copy of "pat" and change "^" to "\(^\|[\/]\)" (if doing regular
  // expression matching)
  if (!fuzzy) {
    if (*pat == '^' && pat[1] != NUL) {
      patc = xstrdup(pat + 1);
      to_free = true;
    } else if (*pat == '^') {
      patc = "";
    } else {
      patc = pat;
    }
    regmatch.regprog = vim_regcomp(patc, RE_MAGIC);
  }

  int count = 0;
  int score = 0;
  // round == 1: Count the matches.
  // round == 2: Build the array to keep the matches.
  for (int round = 1; round <= 2; round++) {
    count = 0;
    FOR_ALL_BUFFERS(buf) {
      if (!buf->b_p_bl) {             // skip unlisted buffers
        continue;
      }
      if (options & BUF_DIFF_FILTER) {
        // Skip buffers not suitable for
        // :diffget or :diffput completion.
        if (buf == curbuf || !diff_mode_buf(buf)) {
          continue;
        }
      }

      char *p = NULL;
      if (!fuzzy) {
        if (regmatch.regprog == NULL) {
          // invalid pattern, possibly after recompiling
          if (to_free) {
            xfree(patc);
          }
          return FAIL;
        }
        p = buflist_match(&regmatch, buf, p_wic);
      } else {
        p = NULL;
        // first try matching with the short file name
        if ((score = fuzzy_match_str(buf->b_sfname, pat)) != 0) {
          p = buf->b_sfname;
        }
        if (p == NULL) {
          // next try matching with the full path file name
          if ((score = fuzzy_match_str(buf->b_ffname, pat)) != 0) {
            p = buf->b_ffname;
          }
        }
      }

      if (p == NULL) {
        continue;
      }

      if (round == 1) {
        count++;
        continue;
      }

      if (options & WILD_HOME_REPLACE) {
        p = home_replace_save(buf, p);
      } else {
        p = xstrdup(p);
      }

      if (!fuzzy) {
        if (matches != NULL) {
          matches[count].buf = buf;
          matches[count].match = p;
          count++;
        } else {
          (*file)[count++] = p;
        }
      } else {
        fuzmatch[count].idx = count;
        fuzmatch[count].str = p;
        fuzmatch[count].score = score;
        count++;
      }
    }
    if (count == 0) {         // no match found, break here
      break;
    }
    if (round == 1) {
      if (!fuzzy) {
        *file = xmalloc((size_t)count * sizeof(**file));
        if (options & WILD_BUFLASTUSED) {
          matches = xmalloc((size_t)count * sizeof(*matches));
        }
      } else {
        fuzmatch = xmalloc((size_t)count * sizeof(fuzmatch_str_T));
      }
    }
  }

  if (!fuzzy) {
    vim_regfree(regmatch.regprog);
    if (to_free) {
      xfree(patc);
    }
  }

  if (!fuzzy) {
    if (matches != NULL) {
      if (count > 1) {
        qsort(matches, (size_t)count, sizeof(bufmatch_T), buf_time_compare);
      }

      // if the current buffer is first in the list, place it at the end
      if (matches[0].buf == curbuf) {
        for (int i = 1; i < count; i++) {
          (*file)[i - 1] = matches[i].match;
        }
        (*file)[count - 1] = matches[0].match;
      } else {
        for (int i = 0; i < count; i++) {
          (*file)[i] = matches[i].match;
        }
      }
      xfree(matches);
    }
  } else {
    fuzzymatches_to_strmatches(fuzmatch, file, count, false);
  }

  *num_file = count;
  return count == 0 ? FAIL : OK;
}

/// Check for a match on the file name for buffer "buf" with regprog "prog".
/// Note that rmp->regprog may become NULL when switching regexp engine.
///
/// @param ignore_case  When true, ignore case. Use 'fic' otherwise.
static char *buflist_match(regmatch_T *rmp, buf_T *buf, bool ignore_case)
{
  // First try the short file name, then the long file name.
  char *match = fname_match(rmp, buf->b_sfname, ignore_case);
  if (match == NULL && rmp->regprog != NULL) {
    match = fname_match(rmp, buf->b_ffname, ignore_case);
  }
  return match;
}

/// Try matching the regexp in "rmp->regprog" with file name "name".
/// Note that rmp->regprog may become NULL when switching regexp engine.
///
/// @param ignore_case  When true, ignore case. Use 'fileignorecase' otherwise.
///
/// @return  "name" when there is a match, NULL when not.
static char *fname_match(regmatch_T *rmp, char *name, bool ignore_case)
{
  char *match = NULL;

  // extra check for valid arguments
  if (name == NULL || rmp->regprog == NULL) {
    return NULL;
  }

  // Ignore case when 'fileignorecase' or the argument is set.
  rmp->rm_ic = p_fic || ignore_case;
  if (vim_regexec(rmp, name, 0)) {
    match = name;
  } else if (rmp->regprog != NULL) {
    // Replace $(HOME) with '~' and try matching again.
    char *p = home_replace_save(NULL, name);
    if (vim_regexec(rmp, p, 0)) {
      match = name;
    }
    xfree(p);
  }

  return match;
}

/// Find a file in the buffer list by buffer number.
buf_T *buflist_findnr(int nr)
{
  if (nr == 0) {
    nr = curwin->w_alt_fnum;
  }

  return handle_get_buffer((handle_T)nr);
}

/// Get name of file 'n' in the buffer list.
/// When the file has no name an empty string is returned.
/// home_replace() is used to shorten the file name (used for marks).
///
/// @param helptail  for help buffers return tail only
///
/// @return  a pointer to allocated memory, of NULL when failed.
char *buflist_nr2name(int n, int fullname, int helptail)
{
  buf_T *buf = buflist_findnr(n);
  if (buf == NULL) {
    return NULL;
  }
  return home_replace_save(helptail ? buf : NULL,
                           fullname ? buf->b_ffname : buf->b_fname);
}

/// Set the line and column numbers for the given buffer and window
///
/// @param[in,out]  buf           Buffer for which line and column are set.
/// @param[in,out]  win           Window for which line and column are set.
///                               May be NULL when using :badd.
/// @param[in]      lnum          Line number to be set. If it is zero then only
///                               options are touched.
/// @param[in]      col           Column number to be set.
/// @param[in]      copy_options  If true save the local window option values.
void buflist_setfpos(buf_T *const buf, win_T *const win, linenr_T lnum, colnr_T col,
                     bool copy_options)
  FUNC_ATTR_NONNULL_ARG(1)
{
  WinInfo *wip;

  size_t i;
  for (i = 0; i < kv_size(buf->b_wininfo); i++) {
    wip = kv_A(buf->b_wininfo, i);
    if (wip->wi_win == win) {
      break;
    }
  }

  if (i == kv_size(buf->b_wininfo)) {
    // allocate a new entry
    wip = xcalloc(1, sizeof(WinInfo));
    wip->wi_win = win;
    if (lnum == 0) {            // set lnum even when it's 0
      lnum = 1;
    }
  } else {
    // remove the entry from the list
    kv_shift(buf->b_wininfo, i, 1);
    if (copy_options && wip->wi_optset) {
      clear_winopt(&wip->wi_opt);
      deleteFoldRecurse(buf, &wip->wi_folds);
    }
  }
  if (lnum != 0) {
    wip->wi_mark.mark.lnum = lnum;
    wip->wi_mark.mark.col = col;
    if (win != NULL) {
      wip->wi_mark.view = mark_view_make(win->w_topline, wip->wi_mark.mark);
    }
  }
  if (win != NULL) {
    wip->wi_changelistidx = win->w_changelistidx;
  }
  if (copy_options && win != NULL) {
    // Save the window-specific option values.
    copy_winopt(&win->w_onebuf_opt, &wip->wi_opt);
    wip->wi_fold_manual = win->w_fold_manual;
    cloneFoldGrowArray(&win->w_folds, &wip->wi_folds);
    wip->wi_optset = true;
  }

  // insert the entry in front of the list
  kv_pushp(buf->b_wininfo);
  memmove(&kv_A(buf->b_wininfo, 1), &kv_A(buf->b_wininfo, 0),
          (kv_size(buf->b_wininfo) - 1) * sizeof(kv_A(buf->b_wininfo, 0)));
  kv_A(buf->b_wininfo, 0) = wip;
}

/// Check that "wip" has 'diff' set and the diff is only for another tab page.
/// That's because a diff is local to a tab page.
static bool wininfo_other_tab_diff(WinInfo *wip)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (!wip->wi_opt.wo_diff) {
    return false;
  }

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    // return false when it's a window in the current tab page, thus
    // the buffer was in diff mode here
    if (wip->wi_win == wp) {
      return false;
    }
  }
  return true;
}

/// Find info for the current window in buffer "buf".
/// If not found, return the info for the most recently used window.
///
/// @param need_options      when true, skip entries where wi_optset is false.
/// @param skip_diff_buffer  when true, avoid windows with 'diff' set that is in another tab page.
///
/// @return  NULL when there isn't any info.
static WinInfo *find_wininfo(buf_T *buf, bool need_options, bool skip_diff_buffer)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  for (size_t i = 0; i < kv_size(buf->b_wininfo); i++) {
    WinInfo *wip = kv_A(buf->b_wininfo, i);
    if (wip->wi_win == curwin
        && (!skip_diff_buffer || !wininfo_other_tab_diff(wip))
        && (!need_options || wip->wi_optset)) {
      return wip;
    }
  }

  // If no wininfo for curwin, use the first in the list (that doesn't have
  // 'diff' set and is in another tab page).
  // If "need_options" is true skip entries that don't have options set,
  // unless the window is editing "buf", so we can copy from the window
  // itself.
  if (skip_diff_buffer) {
    for (size_t i = 0; i < kv_size(buf->b_wininfo); i++) {
      WinInfo *wip = kv_A(buf->b_wininfo, i);
      if (!wininfo_other_tab_diff(wip)
          && (!need_options
              || wip->wi_optset
              || (wip->wi_win != NULL
                  && wip->wi_win->w_buffer == buf))) {
        return wip;
      }
    }
  } else if (kv_size(buf->b_wininfo)) {
    return kv_A(buf->b_wininfo, 0);
  }
  return NULL;
}

/// Reset the local window options to the values last used in this window.
/// If the buffer wasn't used in this window before, use the values from
/// the most recently used window.  If the values were never set, use the
/// global values for the window.
void get_winopts(buf_T *buf)
{
  clear_winopt(&curwin->w_onebuf_opt);
  clearFolding(curwin);

  WinInfo *const wip = find_wininfo(buf, true, true);
  if (wip != NULL && wip->wi_win != curwin && wip->wi_win != NULL
      && wip->wi_win->w_buffer == buf) {
    win_T *wp = wip->wi_win;
    copy_winopt(&wp->w_onebuf_opt, &curwin->w_onebuf_opt);
    curwin->w_fold_manual = wp->w_fold_manual;
    curwin->w_foldinvalid = true;
    cloneFoldGrowArray(&wp->w_folds, &curwin->w_folds);
  } else if (wip != NULL && wip->wi_optset) {
    copy_winopt(&wip->wi_opt, &curwin->w_onebuf_opt);
    curwin->w_fold_manual = wip->wi_fold_manual;
    curwin->w_foldinvalid = true;
    cloneFoldGrowArray(&wip->wi_folds, &curwin->w_folds);
  } else {
    copy_winopt(&curwin->w_allbuf_opt, &curwin->w_onebuf_opt);
  }
  if (wip != NULL) {
    curwin->w_changelistidx = wip->wi_changelistidx;
  }

  if (curwin->w_config.style == kWinStyleMinimal) {
    didset_window_options(curwin, false);
    win_set_minimal_style(curwin);
  }

  // Set 'foldlevel' to 'foldlevelstart' if it's not negative.
  if (p_fdls >= 0) {
    curwin->w_p_fdl = p_fdls;
  }
  didset_window_options(curwin, false);
}

/// Find the mark for the buffer 'buf' for the current window.
///
/// @return  a pointer to no_position if no position is found.
fmark_T *buflist_findfmark(buf_T *buf)
  FUNC_ATTR_PURE
{
  static fmark_T no_position = { { 1, 0, 0 }, 0, 0, { 0 }, NULL };

  WinInfo *const wip = find_wininfo(buf, false, false);
  return (wip == NULL) ? &no_position : &(wip->wi_mark);
}

/// Find the lnum for the buffer 'buf' for the current window.
linenr_T buflist_findlnum(buf_T *buf)
  FUNC_ATTR_PURE
{
  return buflist_findfmark(buf)->mark.lnum;
}

/// List all known file names (for :files and :buffers command).
void buflist_list(exarg_T *eap)
{
  buf_T *buf = firstbuf;

  garray_T buflist;
  buf_T **buflist_data = NULL;

  msg_ext_set_kind("list_cmd");
  if (vim_strchr(eap->arg, 't')) {
    ga_init(&buflist, sizeof(buf_T *), 50);
    for (buf = firstbuf; buf != NULL; buf = buf->b_next) {
      ga_grow(&buflist, 1);
      ((buf_T **)buflist.ga_data)[buflist.ga_len++] = buf;
    }

    qsort(buflist.ga_data, (size_t)buflist.ga_len,
          sizeof(buf_T *), buf_time_compare);

    buflist_data = (buf_T **)buflist.ga_data;
    buf = *buflist_data;
  }
  buf_T **p = buflist_data;

  for (;
       buf != NULL && !got_int;
       buf = buflist_data != NULL
             ? (++p < buflist_data + buflist.ga_len ? *p : NULL) : buf->b_next) {
    const bool is_terminal = buf->terminal;
    const bool job_running = buf->terminal && terminal_running(buf->terminal);

    // skip unspecified buffers
    if ((!buf->b_p_bl && !eap->forceit && !vim_strchr(eap->arg, 'u'))
        || (vim_strchr(eap->arg, 'u') && buf->b_p_bl)
        || (vim_strchr(eap->arg, '+')
            && ((buf->b_flags & BF_READERR) || !bufIsChanged(buf)))
        || (vim_strchr(eap->arg, 'a')
            && (buf->b_ml.ml_mfp == NULL || buf->b_nwindows == 0))
        || (vim_strchr(eap->arg, 'h')
            && (buf->b_ml.ml_mfp == NULL || buf->b_nwindows != 0))
        || (vim_strchr(eap->arg, 'R') && (!is_terminal || !job_running))
        || (vim_strchr(eap->arg, 'F') && (!is_terminal || job_running))
        || (vim_strchr(eap->arg, '-') && buf->b_p_ma)
        || (vim_strchr(eap->arg, '=') && !buf->b_p_ro)
        || (vim_strchr(eap->arg, 'x') && !(buf->b_flags & BF_READERR))
        || (vim_strchr(eap->arg, '%') && buf != curbuf)
        || (vim_strchr(eap->arg, '#')
            && (buf == curbuf || curwin->w_alt_fnum != buf->b_fnum))) {
      continue;
    }
    if (buf_spname(buf) != NULL) {
      xstrlcpy(NameBuff, buf_spname(buf), MAXPATHL);
    } else {
      home_replace(buf, buf->b_fname, NameBuff, MAXPATHL, true);
    }

    if (message_filtered(NameBuff)) {
      continue;
    }

    const int changed_char = (buf->b_flags & BF_READERR)
                             ? 'x'
                             : (bufIsChanged(buf) ? '+' : ' ');
    int ro_char = !MODIFIABLE(buf) ? '-' : (buf->b_p_ro ? '=' : ' ');
    if (buf->terminal) {
      ro_char = channel_job_running((uint64_t)buf->b_p_channel) ? 'R' : 'F';
    }

    msg_putchar('\n');
    int len = vim_snprintf(IObuff, IOSIZE - 20, "%3d%c%c%c%c%c \"%s\"",
                           buf->b_fnum,
                           buf->b_p_bl ? ' ' : 'u',
                           buf == curbuf ? '%' : (curwin->w_alt_fnum == buf->b_fnum ? '#' : ' '),
                           buf->b_ml.ml_mfp == NULL ? ' ' : (buf->b_nwindows == 0 ? 'h' : 'a'),
                           ro_char,
                           changed_char,
                           NameBuff);

    len = MIN(len, IOSIZE - 20);

    // put "line 999" in column 40 or after the file name
    int i = 40 - vim_strsize(IObuff);
    do {
      IObuff[len++] = ' ';
    } while (--i > 0 && len < IOSIZE - 18);
    if (vim_strchr(eap->arg, 't') && buf->b_last_used) {
      undo_fmt_time(IObuff + len, (size_t)(IOSIZE - len), buf->b_last_used);
    } else {
      vim_snprintf(IObuff + len, (size_t)(IOSIZE - len), _("line %" PRId64),
                   buf == curbuf ? (int64_t)curwin->w_cursor.lnum : (int64_t)buflist_findlnum(buf));
    }

    msg_outtrans(IObuff, 0, false);
    line_breakcheck();
  }

  if (buflist_data) {
    ga_clear(&buflist);
  }
}

/// Get file name and line number for file 'fnum'.
/// Used by DoOneCmd() for translating '%' and '#'.
/// Used by insert_reg() and cmdline_paste() for '#' register.
///
/// @return  FAIL if not found, OK for success.
int buflist_name_nr(int fnum, char **fname, linenr_T *lnum)
{
  buf_T *buf = buflist_findnr(fnum);
  if (buf == NULL || buf->b_fname == NULL) {
    return FAIL;
  }

  *fname = buf->b_fname;
  *lnum = buflist_findlnum(buf);

  return OK;
}

/// Set the file name for "buf" to "ffname_arg", short file name to
/// "sfname_arg".
/// The file name with the full path is also remembered, for when :cd is used.
///
/// @param message  give message when buffer already exists
///
/// @return  FAIL for failure (file name already in use by other buffer) OK otherwise.
int setfname(buf_T *buf, char *ffname_arg, char *sfname_arg, bool message)
{
  char *ffname = ffname_arg;
  char *sfname = sfname_arg;
  buf_T *obuf = NULL;
  FileID file_id;
  bool file_id_valid = false;

  if (ffname == NULL || *ffname == NUL) {
    // Removing the name.
    if (buf->b_sfname != buf->b_ffname) {
      XFREE_CLEAR(buf->b_sfname);
    } else {
      buf->b_sfname = NULL;
    }
    XFREE_CLEAR(buf->b_ffname);
  } else {
    fname_expand(buf, &ffname, &sfname);    // will allocate ffname
    if (ffname == NULL) {                   // out of memory
      return FAIL;
    }

    // If the file name is already used in another buffer:
    // - if the buffer is loaded, fail
    // - if the buffer is not loaded, delete it from the list
    file_id_valid = os_fileid(ffname, &file_id);
    if (!(buf->b_flags & BF_DUMMY)) {
      obuf = buflist_findname_file_id(ffname, &file_id, file_id_valid);
    }
    if (obuf != NULL && obuf != buf) {
      bool in_use = false;

      // during startup a window may use a buffer that is not loaded yet
      FOR_ALL_TAB_WINDOWS(tab, win) {
        if (win->w_buffer == obuf) {
          in_use = true;
        }
      }

      // it's loaded or used in a window, fail
      if (obuf->b_ml.ml_mfp != NULL || in_use) {
        if (message) {
          emsg(_("E95: Buffer with this name already exists"));
        }
        xfree(ffname);
        return FAIL;
      }
      // delete from the list
      close_buffer(NULL, obuf, DOBUF_WIPE, false, false);
    }
    sfname = xstrdup(sfname);
#ifdef CASE_INSENSITIVE_FILENAME
    path_fix_case(sfname);            // set correct case for short file name
#endif
    if (buf->b_sfname != buf->b_ffname) {
      xfree(buf->b_sfname);
    }
    xfree(buf->b_ffname);
    buf->b_ffname = ffname;
    buf->b_sfname = sfname;
  }
  buf->b_fname = buf->b_sfname;
  if (!file_id_valid) {
    buf->file_id_valid = false;
  } else {
    buf->file_id_valid = true;
    buf->file_id = file_id;
  }

  buf_name_changed(buf);
  return OK;
}

/// Crude way of changing the name of a buffer.  Use with care!
/// The name should be relative to the current directory.
void buf_set_name(int fnum, char *name)
{
  buf_T *buf = buflist_findnr(fnum);
  if (buf == NULL) {
    return;
  }

  if (buf->b_sfname != buf->b_ffname) {
    xfree(buf->b_sfname);
  }
  xfree(buf->b_ffname);
  buf->b_ffname = xstrdup(name);
  buf->b_sfname = NULL;
  // Allocate ffname and expand into full path.  Also resolves .lnk
  // files on Win32.
  fname_expand(buf, &buf->b_ffname, &buf->b_sfname);
  buf->b_fname = buf->b_sfname;
}

/// Take care of what needs to be done when the name of buffer "buf" has changed.
void buf_name_changed(buf_T *buf)
{
  // If the file name changed, also change the name of the swapfile
  if (buf->b_ml.ml_mfp != NULL) {
    ml_setname(buf);
  }

  if (curwin->w_buffer == buf) {
    check_arg_idx(curwin);      // check file name for arg list
  }
  maketitle();                  // set window title
  status_redraw_all();          // status lines need to be redrawn
  fmarks_check_names(buf);      // check named file marks
  ml_timestamp(buf);            // reset timestamp
}

/// Set alternate file name for current window
///
/// Used by do_one_cmd(), do_write() and do_ecmd().
///
/// @return  the buffer.
buf_T *setaltfname(char *ffname, char *sfname, linenr_T lnum)
{
  // Create a buffer.  'buflisted' is not set if it's a new buffer
  buf_T *buf = buflist_new(ffname, sfname, lnum, 0);
  if (buf != NULL && (cmdmod.cmod_flags & CMOD_KEEPALT) == 0) {
    curwin->w_alt_fnum = buf->b_fnum;
  }
  return buf;
}

/// Get alternate file name for current window.
/// Return NULL if there isn't any, and give error message if requested.
///
/// @param errmsg  give error message
char *getaltfname(bool errmsg)
{
  char *fname;
  linenr_T dummy;

  if (buflist_name_nr(0, &fname, &dummy) == FAIL) {
    if (errmsg) {
      emsg(_(e_noalt));
    }
    return NULL;
  }
  return fname;
}

/// Add a file name to the buflist and return its number.
/// Uses same flags as buflist_new(), except BLN_DUMMY.
///
/// Used by qf_init(), main() and doarglist()
int buflist_add(char *fname, int flags)
{
  buf_T *buf = buflist_new(fname, NULL, 0, flags);
  if (buf != NULL) {
    return buf->b_fnum;
  }
  return 0;
}

#if defined(BACKSLASH_IN_FILENAME)
/// Adjust slashes in file names.  Called after 'shellslash' was set.
void buflist_slash_adjust(void)
{
  FOR_ALL_BUFFERS(bp) {
    if (bp->b_ffname != NULL) {
      slash_adjust(bp->b_ffname);
    }
    if (bp->b_sfname != NULL) {
      slash_adjust(bp->b_sfname);
    }
  }
}

#endif

/// Set alternate cursor position for the current buffer and window "win".
/// Also save the local window option values.
void buflist_altfpos(win_T *win)
{
  buflist_setfpos(curbuf, win, win->w_cursor.lnum, win->w_cursor.col, true);
}

/// Check that "ffname" is not the same file as current file.
/// Fname must have a full path (expanded by path_to_absolute()).
///
/// @param  ffname  full path name to check
bool otherfile(char *ffname)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  return otherfile_buf(curbuf, ffname, NULL, false);
}

/// Check that "ffname" is not the same file as the file loaded in "buf".
/// Fname must have a full path (expanded by path_to_absolute()).
///
/// @param  buf            buffer to check
/// @param  ffname         full path name to check
/// @param  file_id_p      information about the file at "ffname".
/// @param  file_id_valid  whether a valid "file_id_p" was passed in.
static bool otherfile_buf(buf_T *buf, char *ffname, FileID *file_id_p, bool file_id_valid)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  // no name is different
  if (ffname == NULL || *ffname == NUL || buf->b_ffname == NULL) {
    return true;
  }
  if (path_fnamecmp(ffname, buf->b_ffname) == 0) {
    return false;
  }
  {
    FileID file_id;
    // If no struct stat given, get it now
    if (file_id_p == NULL) {
      file_id_p = &file_id;
      file_id_valid = os_fileid(ffname, file_id_p);
    }
    if (!file_id_valid) {
      // file_id not valid, assume files are different.
      return true;
    }
    // Use dev/ino to check if the files are the same, even when the names
    // are different (possible with links).  Still need to compare the
    // name above, for when the file doesn't exist yet.
    // Problem: The dev/ino changes when a file is deleted (and created
    // again) and remains the same when renamed/moved.  We don't want to
    // stat() each buffer each time, that would be too slow.  Get the
    // dev/ino again when they appear to match, but not when they appear
    // to be different: Could skip a buffer when it's actually the same
    // file.
    if (buf_same_file_id(buf, file_id_p)) {
      buf_set_file_id(buf);
      if (buf_same_file_id(buf, file_id_p)) {
        return false;
      }
    }
  }
  return true;
}

/// Set file_id for a buffer.
/// Must always be called when b_fname is changed!
void buf_set_file_id(buf_T *buf)
{
  FileID file_id;
  if (buf->b_fname != NULL
      && os_fileid(buf->b_fname, &file_id)) {
    buf->file_id_valid = true;
    buf->file_id = file_id;
  } else {
    buf->file_id_valid = false;
  }
}

/// Check that file_id in buffer "buf" matches with "file_id".
///
/// @param  buf      buffer
/// @param  file_id  file id
static bool buf_same_file_id(buf_T *buf, FileID *file_id)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  return buf->file_id_valid && os_fileid_equal(&(buf->file_id), file_id);
}

/// Print info about the current buffer.
///
/// @param fullname  when non-zero print full path
void fileinfo(int fullname, int shorthelp, bool dont_truncate)
{
  char *p;

  char *buffer = xmalloc(IOSIZE);

  if (fullname > 1) {       // 2 CTRL-G: include buffer number
    vim_snprintf(buffer, IOSIZE, "buf %d: ", curbuf->b_fnum);
    p = buffer + strlen(buffer);
  } else {
    p = buffer;
  }

  *p++ = '"';
  if (buf_spname(curbuf) != NULL) {
    xstrlcpy(p, buf_spname(curbuf), (size_t)(IOSIZE - (p - buffer)));
  } else {
    char *name = (!fullname && curbuf->b_fname != NULL)
                 ? curbuf->b_fname
                 : curbuf->b_ffname;
    home_replace(shorthelp ? curbuf : NULL, name, p,
                 (size_t)(IOSIZE - (p - buffer)), true);
  }

  bool dontwrite = bt_dontwrite(curbuf);
  vim_snprintf_add(buffer, IOSIZE, "\"%s%s%s%s%s%s",
                   curbufIsChanged()
                   ? (shortmess(SHM_MOD) ? " [+]" : _(" [Modified]")) : " ",
                   (curbuf->b_flags & BF_NOTEDITED) && !dontwrite
                   ? _("[Not edited]") : "",
                   (curbuf->b_flags & BF_NEW) && !dontwrite
                   ? _("[New]") : "",
                   (curbuf->b_flags & BF_READERR)
                   ? _("[Read errors]") : "",
                   curbuf->b_p_ro
                   ? (shortmess(SHM_RO) ? _("[RO]") : _("[readonly]")) : "",
                   (curbufIsChanged()
                    || (curbuf->b_flags & BF_WRITE_MASK)
                    || curbuf->b_p_ro)
                   ? " " : "");
  int n;
  // With 32 bit longs and more than 21,474,836 lines multiplying by 100
  // causes an overflow, thus for large numbers divide instead.
  if (curwin->w_cursor.lnum > 1000000) {
    n = ((curwin->w_cursor.lnum) /
         (curbuf->b_ml.ml_line_count / 100));
  } else {
    n = ((curwin->w_cursor.lnum * 100) /
         curbuf->b_ml.ml_line_count);
  }
  if (curbuf->b_ml.ml_flags & ML_EMPTY) {
    vim_snprintf_add(buffer, IOSIZE, "%s", _(no_lines_msg));
  } else if (p_ru) {
    // Current line and column are already on the screen -- webb
    vim_snprintf_add(buffer, IOSIZE,
                     NGETTEXT("%" PRId64 " line --%d%%--",
                              "%" PRId64 " lines --%d%%--",
                              curbuf->b_ml.ml_line_count),
                     (int64_t)curbuf->b_ml.ml_line_count, n);
  } else {
    vim_snprintf_add(buffer, IOSIZE,
                     _("line %" PRId64 " of %" PRId64 " --%d%%-- col "),
                     (int64_t)curwin->w_cursor.lnum,
                     (int64_t)curbuf->b_ml.ml_line_count,
                     n);
    validate_virtcol(curwin);
    size_t len = strlen(buffer);
    (void)col_print(buffer + len, IOSIZE - len,
                    (int)curwin->w_cursor.col + 1, (int)curwin->w_virtcol + 1);
  }

  append_arg_number(curwin, buffer, IOSIZE);

  if (dont_truncate) {
    // Temporarily set msg_scroll to avoid the message being truncated.
    // First call msg_start() to get the message in the right place.
    msg_start();
    n = msg_scroll;
    msg_scroll = true;
    msg(buffer, 0);
    msg_scroll = n;
  } else {
    p = msg_trunc(buffer, false, 0);
    if (restart_edit != 0 || (msg_scrolled && !need_wait_return)) {
      // Need to repeat the message after redrawing when:
      // - When restart_edit is set (otherwise there will be a delay
      //   before redrawing).
      // - When the screen was scrolled but there is no wait-return
      //   prompt.
      set_keep_msg(p, 0);
    }
  }

  xfree(buffer);
}

int col_print(char *buf, size_t buflen, int col, int vcol)
{
  if (col == vcol) {
    return vim_snprintf(buf, buflen, "%d", col);
  }

  return vim_snprintf(buf, buflen, "%d-%d", col, vcol);
}

static char *lasttitle = NULL;
static char *lasticon = NULL;

/// Put the title name in the title bar and icon of the window.
void maketitle(void)
{
  char *title_str = NULL;
  char *icon_str = NULL;
  int maxlen = 0;
  char buf[IOSIZE];

  if (!redrawing()) {
    // Postpone updating the title when 'lazyredraw' is set.
    need_maketitle = true;
    return;
  }

  need_maketitle = false;
  if (!p_title && !p_icon && lasttitle == NULL && lasticon == NULL) {
    return;  // nothing to do
  }

  if (p_title) {
    if (p_titlelen > 0) {
      maxlen = MAX((int)(p_titlelen * Columns / 100), 10);
    }

    if (*p_titlestring != NUL) {
      if (stl_syntax & STL_IN_TITLE) {
        build_stl_str_hl(curwin, buf, sizeof(buf), p_titlestring,
                         kOptTitlestring, 0, 0, maxlen, NULL, NULL, NULL, NULL);
        title_str = buf;
      } else {
        title_str = p_titlestring;
      }
    } else {
      // Format: "fname + (path) (1 of 2) - Nvim".
      char *default_titlestring = "%t%( %M%)%( (%{expand(\"%:~:h\")})%)%a - Nvim";
      build_stl_str_hl(curwin, buf, sizeof(buf), default_titlestring,
                       kOptTitlestring, 0, 0, maxlen, NULL, NULL, NULL, NULL);
      title_str = buf;
    }
  }
  bool mustset = value_change(title_str, &lasttitle);

  if (p_icon) {
    icon_str = buf;
    if (*p_iconstring != NUL) {
      if (stl_syntax & STL_IN_ICON) {
        build_stl_str_hl(curwin, icon_str, sizeof(buf), p_iconstring,
                         kOptIconstring, 0, 0, 0, NULL, NULL, NULL, NULL);
      } else {
        icon_str = p_iconstring;
      }
    } else {
      char *buf_p = buf_spname(curbuf) != NULL
                    ? buf_spname(curbuf)
                    : path_tail(curbuf->b_ffname);  // use file name only in icon
      *icon_str = NUL;
      // Truncate name at 100 bytes.
      int len = (int)strlen(buf_p);
      if (len > 100) {
        len -= 100;
        len += utf_cp_bounds(buf_p, buf_p + len).end_off;
        buf_p += len;
      }
      STRCPY(icon_str, buf_p);
      trans_characters(icon_str, IOSIZE);
    }
  }

  mustset |= value_change(icon_str, &lasticon);

  if (mustset) {
    resettitle();
  }
}

/// Used for title and icon: Check if "str" differs from "*last".  Set "*last"
/// from "str" if it does by freeing the old value of "*last" and duplicating
/// "str".
///
/// @param          str   desired title string
/// @param[in,out]  last  current title string
///
/// @return  true if resettitle() is to be called.
static bool value_change(char *str, char **last)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if ((str == NULL) != (*last == NULL)
      || (str != NULL && *last != NULL && strcmp(str, *last) != 0)) {
    xfree(*last);
    if (str == NULL) {
      *last = NULL;
      resettitle();
    } else {
      *last = xstrdup(str);
      return true;
    }
  }
  return false;
}

/// Set current window title
void resettitle(void)
{
  ui_call_set_icon(cstr_as_string(lasticon));
  ui_call_set_title(cstr_as_string(lasttitle));
}

#if defined(EXITFREE)
void free_titles(void)
{
  xfree(lasttitle);
  xfree(lasticon);
}

#endif

/// Get relative cursor position in window into "buf[buflen]", in the localized
/// percentage form like %99, 99%; using "Top", "Bot" or "All" when appropriate.
int get_rel_pos(win_T *wp, char *buf, int buflen)
{
  // Need at least 3 chars for writing.
  if (buflen < 3) {
    return 0;
  }

  linenr_T above;          // number of lines above window
  linenr_T below;          // number of lines below window
  int len;

  above = wp->w_topline - 1;
  above += win_get_fill(wp, wp->w_topline) - wp->w_topfill;
  if (wp->w_topline == 1 && wp->w_topfill >= 1) {
    // All buffer lines are displayed and there is an indication
    // of filler lines, that can be considered seeing all lines.
    above = 0;
  }
  below = wp->w_buffer->b_ml.ml_line_count - wp->w_botline + 1;
  if (below <= 0) {
    len = vim_snprintf(buf, (size_t)buflen, "%s", (above == 0) ? _("All") : _("Bot"));
  } else if (above <= 0) {
    len = vim_snprintf(buf, (size_t)buflen, "%s", _("Top"));
  } else {
    int perc = (above > 1000000
                ? (above / ((above + below) / 100))
                : (above * 100 / (above + below)));
    // localized percentage value
    len = vim_snprintf(buf, (size_t)buflen, _("%s%d%%"), (perc < 10) ? " " : "", perc);
  }
  if (len < 0) {
    buf[0] = NUL;
    len = 0;
  } else if (len > buflen - 1) {
    len = buflen - 1;
  }

  return len;
}

/// Append (2 of 8) to "buf[buflen]", if editing more than one file.
///
/// @param          wp        window whose buffers to check
/// @param[in,out]  buf       string buffer to add the text to
/// @param          buflen    length of the string buffer
///
/// @return  true if it was appended.
bool append_arg_number(win_T *wp, char *buf, int buflen)
  FUNC_ATTR_NONNULL_ALL
{
  // Nothing to do
  if (ARGCOUNT <= 1) {
    return false;
  }

  const char *msg = wp->w_arg_idx_invalid ? _(" ((%d) of %d)") : _(" (%d of %d)");

  char *p = buf + strlen(buf);  // go to the end of the buffer
  vim_snprintf(p, (size_t)(buflen - (p - buf)), msg, wp->w_arg_idx + 1, ARGCOUNT);
  return true;
}

/// Make "*ffname" a full file name, set "*sfname" to "*ffname" if not NULL.
/// "*ffname" becomes a pointer to allocated memory (or NULL).
/// When resolving a link both "*sfname" and "*ffname" will point to the same
/// allocated memory.
/// The "*ffname" and "*sfname" pointer values on call will not be freed.
/// Note that the resulting "*ffname" pointer should be considered not allocated.
void fname_expand(buf_T *buf, char **ffname, char **sfname)
{
  if (*ffname == NULL) {  // no file name given, nothing to do
    return;
  }
  if (*sfname == NULL) {  // no short file name given, use ffname
    *sfname = *ffname;
  }
  *ffname = fix_fname((*ffname));     // expand to full path

#ifdef MSWIN
  if (!buf->b_p_bin) {
    // If the file name is a shortcut file, use the file it links to.
    char *rfname = os_resolve_shortcut(*ffname);
    if (rfname != NULL) {
      xfree(*ffname);
      *ffname = rfname;
      *sfname = rfname;
    }
  }
#endif
}

/// @return  true if "buf" is a prompt buffer.
bool bt_prompt(buf_T *buf)
  FUNC_ATTR_PURE
{
  return buf != NULL && buf->b_p_bt[0] == 'p';
}

/// Open a window for a number of buffers.
void ex_buffer_all(exarg_T *eap)
{
  win_T *wpnext;
  int split_ret = OK;
  int open_wins = 0;
  int had_tab = cmdmod.cmod_tab;

  // Maximum number of windows to open.
  linenr_T count = eap->addr_count == 0
                   ? 9999         // make as many windows as possible
                   : eap->line2;  // make as many windows as specified

  // When true also load inactive buffers.
  int all = eap->cmdidx != CMD_unhide && eap->cmdidx != CMD_sunhide;

  // Stop Visual mode, the cursor and "VIsual" may very well be invalid after
  // switching to another buffer.
  reset_VIsual_and_resel();

  setpcmark();

  // Close superfluous windows (two windows for the same buffer).
  // Also close windows that are not full-width.
  if (had_tab > 0) {
    goto_tabpage_tp(first_tabpage, true, true);
  }
  while (true) {
    tabpage_T *tpnext = curtab->tp_next;
    // Try to close floating windows first
    for (win_T *wp = lastwin->w_floating ? lastwin : firstwin; wp != NULL; wp = wpnext) {
      wpnext = wp->w_floating
               ? wp->w_prev->w_floating ? wp->w_prev : firstwin
               : (wp->w_next == NULL || wp->w_next->w_floating) ? NULL : wp->w_next;
      if ((wp->w_buffer->b_nwindows > 1
           || wp->w_floating
           || ((cmdmod.cmod_split & WSP_VERT)
               ? wp->w_height + wp->w_hsep_height + wp->w_status_height < Rows - p_ch
               - tabline_height() - global_stl_height()
               : wp->w_width != Columns)
           || (had_tab > 0 && wp != firstwin))
          && !ONE_WINDOW
          && !(win_locked(curwin) || wp->w_buffer->b_locked > 0)
          && !is_aucmd_win(wp)) {
        if (win_close(wp, false, false) == FAIL) {
          break;
        }
        // Just in case an autocommand does something strange with
        // windows: start all over...
        wpnext = lastwin->w_floating ? lastwin : firstwin;
        tpnext = first_tabpage;
        open_wins = 0;
      } else {
        open_wins++;
      }
    }

    // Without the ":tab" modifier only do the current tab page.
    if (had_tab == 0 || tpnext == NULL) {
      break;
    }
    goto_tabpage_tp(tpnext, true, true);
  }

  // Go through the buffer list.  When a buffer doesn't have a window yet,
  // open one.  Otherwise move the window to the right position.
  // Watch out for autocommands that delete buffers or windows!
  //
  // Don't execute Win/Buf Enter/Leave autocommands here.
  autocmd_no_enter++;
  // lastwin may be aucmd_win
  win_enter(lastwin_nofloating(), false);
  autocmd_no_leave++;
  for (buf_T *buf = firstbuf; buf != NULL && open_wins < count; buf = buf->b_next) {
    // Check if this buffer needs a window
    if ((!all && buf->b_ml.ml_mfp == NULL) || !buf->b_p_bl) {
      continue;
    }

    win_T *wp;
    if (had_tab != 0) {
      // With the ":tab" modifier don't move the window.
      wp = buf->b_nwindows > 0
           ? lastwin  // buffer has a window, skip it
           : NULL;
    } else {
      // Check if this buffer already has a window
      for (wp = firstwin; wp != NULL; wp = wp->w_next) {
        if (!wp->w_floating && wp->w_buffer == buf) {
          break;
        }
      }
      // If the buffer already has a window, move it
      if (wp != NULL) {
        win_move_after(wp, curwin);
      }
    }

    if (wp == NULL && split_ret == OK) {
      bufref_T bufref;
      set_bufref(&bufref, buf);
      // Split the window and put the buffer in it.
      bool p_ea_save = p_ea;
      p_ea = true;                      // use space from all windows
      split_ret = win_split(0, WSP_ROOM | WSP_BELOW);
      open_wins++;
      p_ea = p_ea_save;
      if (split_ret == FAIL) {
        continue;
      }

      // Open the buffer in this window.
      swap_exists_action = SEA_DIALOG;
      set_curbuf(buf, DOBUF_GOTO, !(jop_flags & kOptJopFlagClean));
      if (!bufref_valid(&bufref)) {
        // Autocommands deleted the buffer.
        swap_exists_action = SEA_NONE;
        break;
      }
      if (swap_exists_action == SEA_QUIT) {
        cleanup_T cs;

        // Reset the error/interrupt/exception state here so that
        // aborting() returns false when closing a window.
        enter_cleanup(&cs);

        // User selected Quit at ATTENTION prompt; close this window.
        win_close(curwin, true, false);
        open_wins--;
        swap_exists_action = SEA_NONE;
        swap_exists_did_quit = true;

        // Restore the error/interrupt/exception state if not
        // discarded by a new aborting error, interrupt, or uncaught
        // exception.
        leave_cleanup(&cs);
      } else {
        handle_swap_exists(NULL);
      }
    }

    os_breakcheck();
    if (got_int) {
      vgetc();            // only break the file loading, not the rest
      break;
    }
    // Autocommands deleted the buffer or aborted script processing!!!
    if (aborting()) {
      break;
    }
    // When ":tab" was used open a new tab for a new window repeatedly.
    if (had_tab > 0 && tabpage_index(NULL) <= p_tpm) {
      cmdmod.cmod_tab = 9999;
    }
  }
  autocmd_no_enter--;
  win_enter(firstwin, false);           // back to first window
  autocmd_no_leave--;

  // Close superfluous windows.
  for (win_T *wp = lastwin; open_wins > count;) {
    bool r = (buf_hide(wp->w_buffer) || !bufIsChanged(wp->w_buffer)
              || autowrite(wp->w_buffer, false) == OK) && !is_aucmd_win(wp);
    if (!win_valid(wp)) {
      // BufWrite Autocommands made the window invalid, start over
      wp = lastwin;
    } else if (r) {
      win_close(wp, !buf_hide(wp->w_buffer), false);
      open_wins--;
      wp = lastwin;
    } else {
      wp = wp->w_prev;
      if (wp == NULL) {
        break;
      }
    }
  }
}

/// do_modelines() - process mode lines for the current file
///
/// @param flags
///        OPT_WINONLY      only set options local to window
///        OPT_NOWIN        don't set options local to window
///
/// Returns immediately if the "ml" option isn't set.
void do_modelines(int flags)
{
  linenr_T lnum;
  int nmlines;
  static int entered = 0;

  if (!curbuf->b_p_ml || (nmlines = (int)p_mls) == 0) {
    return;
  }

  // Disallow recursive entry here.  Can happen when executing a modeline
  // triggers an autocommand, which reloads modelines with a ":do".
  if (entered) {
    return;
  }

  entered++;
  for (lnum = 1; curbuf->b_p_ml && lnum <= curbuf->b_ml.ml_line_count
       && lnum <= nmlines; lnum++) {
    if (chk_modeline(lnum, flags) == FAIL) {
      nmlines = 0;
    }
  }

  for (lnum = curbuf->b_ml.ml_line_count; curbuf->b_p_ml && lnum > 0
       && lnum > nmlines && lnum > curbuf->b_ml.ml_line_count - nmlines;
       lnum--) {
    if (chk_modeline(lnum, flags) == FAIL) {
      nmlines = 0;
    }
  }
  entered--;
}

/// chk_modeline() - check a single line for a mode string
/// Return FAIL if an error encountered.
///
/// @param flags  Same as for do_modelines().
static int chk_modeline(linenr_T lnum, int flags)
{
  char *s;
  char *e;
  intmax_t vers;
  int retval = OK;

  int prev = -1;
  for (s = ml_get(lnum); *s != NUL; s++) {
    if (prev == -1 || ascii_isspace(prev)) {
      if ((prev != -1 && strncmp(s, "ex:", 3) == 0)
          || strncmp(s, "vi:", 3) == 0) {
        break;
      }
      // Accept both "vim" and "Vim".
      if ((s[0] == 'v' || s[0] == 'V') && s[1] == 'i' && s[2] == 'm') {
        if (s[3] == '<' || s[3] == '=' || s[3] == '>') {
          e = s + 4;
        } else {
          e = s + 3;
        }
        if (!try_getdigits(&e, &vers)) {
          continue;
        }

        if (*e == ':'
            && (s[0] != 'V'
                || strncmp(skipwhite(e + 1), "set", 3) == 0)
            && (s[3] == ':'
                || (VIM_VERSION_100 >= vers && isdigit((uint8_t)s[3]))
                || (VIM_VERSION_100 < vers && s[3] == '<')
                || (VIM_VERSION_100 > vers && s[3] == '>')
                || (VIM_VERSION_100 == vers && s[3] == '='))) {
          break;
        }
      }
    }
    prev = (uint8_t)(*s);
  }

  if (!*s) {
    return retval;
  }

  do {                                // skip over "ex:", "vi:" or "vim:"
    s++;
  } while (s[-1] != ':');

  char *linecopy;                 // local copy of any modeline found
  s = linecopy = xstrdup(s);      // copy the line, it will change

  // prepare for emsg()
  estack_push(ETYPE_MODELINE, "modelines", lnum);

  bool end = false;
  while (end == false) {
    s = skipwhite(s);
    if (*s == NUL) {
      break;
    }

    // Find end of set command: ':' or end of line.
    // Skip over "\:", replacing it with ":".
    for (e = s; *e != ':' && *e != NUL; e++) {
      if (e[0] == '\\' && e[1] == ':') {
        STRMOVE(e, e + 1);
      }
    }
    if (*e == NUL) {
      end = true;
    }

    // If there is a "set" command, require a terminating ':' and
    // ignore the stuff after the ':'.
    // "vi:set opt opt opt: foo" -- foo not interpreted
    // "vi:opt opt opt: foo" -- foo interpreted
    // Accept "se" for compatibility with Elvis.
    if (strncmp(s, "set ", 4) == 0
        || strncmp(s, "se ", 3) == 0) {
      if (*e != ':') {                // no terminating ':'?
        break;
      }
      end = true;
      s = vim_strchr(s, ' ') + 1;
    }
    *e = NUL;                         // truncate the set command

    if (*s != NUL) {                  // skip over an empty "::"
      const int secure_save = secure;
      const sctx_T save_current_sctx = current_sctx;
      current_sctx.sc_sid = SID_MODELINE;
      current_sctx.sc_seq = 0;
      current_sctx.sc_lnum = lnum;
      // Make sure no risky things are executed as a side effect.
      secure = 1;

      retval = do_set(s, OPT_MODELINE | OPT_LOCAL | flags);

      secure = secure_save;
      current_sctx = save_current_sctx;
      if (retval == FAIL) {                   // stop if error found
        break;
      }
    }
    s = e + 1;                        // advance to next part
  }

  estack_pop();
  xfree(linecopy);

  return retval;
}

/// @return  true if "buf" is a help buffer.
bool bt_help(const buf_T *const buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return buf != NULL && buf->b_help;
}

/// @return  true if "buf" is a normal buffer, 'buftype' is empty.
bool bt_normal(const buf_T *const buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return buf != NULL && buf->b_p_bt[0] == NUL;
}

/// @return  true if "buf" is the quickfix buffer.
bool bt_quickfix(const buf_T *const buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return buf != NULL && buf->b_p_bt[0] == 'q';
}

/// @return  true if "buf" is a terminal buffer.
bool bt_terminal(const buf_T *const buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return buf != NULL && buf->b_p_bt[0] == 't';
}

/// @return  true if "buf" is a "nofile", "acwrite", "terminal" or "prompt"
///          buffer.  This means the buffer name may not be a file name,
///          at least not for writing the buffer.
bool bt_nofilename(const buf_T *const buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return buf != NULL && ((buf->b_p_bt[0] == 'n' && buf->b_p_bt[2] == 'f')
                         || buf->b_p_bt[0] == 'a'
                         || buf->terminal
                         || buf->b_p_bt[0] == 'p');
}

/// @return  true if "buf" is a "nofile", "quickfix", "terminal" or "prompt"
///          buffer.  This means the buffer is not to be read from a file.
static bool bt_nofileread(const buf_T *const buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return buf != NULL && ((buf->b_p_bt[0] == 'n' && buf->b_p_bt[2] == 'f')
                         || buf->b_p_bt[0] == 't'
                         || buf->b_p_bt[0] == 'q'
                         || buf->b_p_bt[0] == 'p');
}

/// @return  true if "buf" has 'buftype' set to "nofile".
bool bt_nofile(const buf_T *const buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return buf != NULL && buf->b_p_bt[0] == 'n' && buf->b_p_bt[2] == 'f';
}

/// @return  true if "buf" is a "nowrite", "nofile", "terminal" or "prompt"
///          buffer.
bool bt_dontwrite(const buf_T *const buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return buf != NULL && (buf->b_p_bt[0] == 'n'
                         || buf->terminal
                         || buf->b_p_bt[0] == 'p');
}

bool bt_dontwrite_msg(const buf_T *const buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (bt_dontwrite(buf)) {
    emsg(_("E382: Cannot write, 'buftype' option is set"));
    return true;
  }
  return false;
}

/// @return  true if the buffer should be hidden, according to 'hidden', ":hide"
///          and 'bufhidden'.
bool buf_hide(const buf_T *const buf)
  FUNC_ATTR_PURE
{
  // 'bufhidden' overrules 'hidden' and ":hide", check it first
  switch (buf->b_p_bh[0]) {
  case 'u':                         // "unload"
  case 'w':                         // "wipe"
  case 'd':
    return false;           // "delete"
  case 'h':
    return true;            // "hide"
  }
  return p_hid || (cmdmod.cmod_flags & CMOD_HIDE);
}

/// @return  special buffer name or
///          NULL when the buffer has a normal file name.
char *buf_spname(buf_T *buf)
{
  if (bt_quickfix(buf)) {
    // Differentiate between the quickfix and location list buffers using
    // the buffer number stored in the global quickfix stack.
    if (buf->b_fnum == qf_stack_get_bufnr()) {
      return _(msg_qflist);
    }
    return _(msg_loclist);
  }
  // There is no _file_ when 'buftype' is "nofile", b_sfname
  // contains the name as specified by the user.
  if (bt_nofilename(buf)) {
    if (buf->b_fname != NULL) {
      return buf->b_fname;
    }
    if (buf == cmdwin_buf) {
      return _("[Command Line]");
    }
    if (bt_prompt(buf)) {
      return _("[Prompt]");
    }
    return _("[Scratch]");
  }
  if (buf->b_fname == NULL) {
    return buf_get_fname(buf);
  }
  return NULL;
}

/// Get "buf->b_fname", use "[No Name]" if it is NULL.
char *buf_get_fname(const buf_T *buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (buf->b_fname == NULL) {
    return _("[No Name]");
  }
  return buf->b_fname;
}

/// Set 'buflisted' for curbuf to "on" and trigger autocommands if it changed.
void set_buflisted(int on)
{
  if (on == curbuf->b_p_bl) {
    return;
  }

  curbuf->b_p_bl = on;
  if (on) {
    apply_autocmds(EVENT_BUFADD, NULL, NULL, false, curbuf);
  } else {
    apply_autocmds(EVENT_BUFDELETE, NULL, NULL, false, curbuf);
  }
}

/// Read the file for "buf" again and check if the contents changed.
/// Return true if it changed or this could not be checked.
///
/// @param  buf  buffer to check
///
/// @return  true if the buffer's contents have changed
bool buf_contents_changed(buf_T *buf)
  FUNC_ATTR_NONNULL_ALL
{
  bool differ = true;

  // Allocate a buffer without putting it in the buffer list.
  buf_T *newbuf = buflist_new(NULL, NULL, 1, BLN_DUMMY);
  if (newbuf == NULL) {
    return true;
  }

  // Force the 'fileencoding' and 'fileformat' to be equal.
  exarg_T ea;
  prep_exarg(&ea, buf);

  // Set curwin/curbuf to buf and save a few things.
  aco_save_T aco;
  aucmd_prepbuf(&aco, newbuf);

  // We don't want to trigger autocommands now, they may have nasty
  // side-effects like wiping buffers
  block_autocmds();

  if (ml_open(curbuf) == OK
      && readfile(buf->b_ffname, buf->b_fname,
                  0, 0, (linenr_T)MAXLNUM,
                  &ea, READ_NEW | READ_DUMMY, false) == OK) {
    // compare the two files line by line
    if (buf->b_ml.ml_line_count == curbuf->b_ml.ml_line_count) {
      differ = false;
      for (linenr_T lnum = 1; lnum <= curbuf->b_ml.ml_line_count; lnum++) {
        if (strcmp(ml_get_buf(buf, lnum), ml_get(lnum)) != 0) {
          differ = true;
          break;
        }
      }
    }
  }
  xfree(ea.cmd);

  // restore curwin/curbuf and a few other things
  aucmd_restbuf(&aco);

  if (curbuf != newbuf) {  // safety check
    wipe_buffer(newbuf, false);
  }

  unblock_autocmds();

  return differ;
}

/// Wipe out a buffer and decrement the last buffer number if it was used for
/// this buffer.  Call this to wipe out a temp buffer that does not contain any
/// marks.
///
/// @param aucmd  When true trigger autocommands.
void wipe_buffer(buf_T *buf, bool aucmd)
{
  if (!aucmd) {
    // Don't trigger BufDelete autocommands here.
    block_autocmds();
  }
  close_buffer(NULL, buf, DOBUF_WIPE, false, true);
  if (!aucmd) {
    unblock_autocmds();
  }
}

/// Creates or switches to a scratch buffer. :h special-buffers
/// Scratch buffer is:
///   - buftype=nofile bufhidden=hide noswapfile
///   - Always considered 'nomodified'
///
/// @param bufnr     Buffer to switch to, or 0 to create a new buffer.
/// @param bufname   Buffer name, or NULL.
///
/// @see curbufIsChanged()
///
/// @return  FAIL for failure, OK otherwise
int buf_open_scratch(handle_T bufnr, char *bufname)
{
  if (do_ecmd((int)bufnr, NULL, NULL, NULL, ECMD_ONE, ECMD_HIDE, NULL) == FAIL) {
    return FAIL;
  }
  if (bufname != NULL) {
    apply_autocmds(EVENT_BUFFILEPRE, NULL, NULL, false, curbuf);
    setfname(curbuf, bufname, NULL, true);
    apply_autocmds(EVENT_BUFFILEPOST, NULL, NULL, false, curbuf);
  }
  set_option_value_give_err(kOptBufhidden, STATIC_CSTR_AS_OPTVAL("hide"), OPT_LOCAL);
  set_option_value_give_err(kOptBuftype, STATIC_CSTR_AS_OPTVAL("nofile"), OPT_LOCAL);
  set_option_value_give_err(kOptSwapfile, BOOLEAN_OPTVAL(false), OPT_LOCAL);
  RESET_BINDING(curwin);
  return OK;
}

bool buf_is_empty(buf_T *buf)
{
  return buf->b_ml.ml_line_count == 1 && *ml_get_buf(buf, 1) == NUL;
}

/// Increment b:changedtick value
///
/// Also checks b: for consistency in case of debug build.
///
/// @param[in,out]  buf  Buffer to increment value in.
void buf_inc_changedtick(buf_T *const buf)
  FUNC_ATTR_NONNULL_ALL
{
  buf_set_changedtick(buf, buf_get_changedtick(buf) + 1);
}

/// Set b:changedtick, also checking b: for consistency in debug build
///
/// @param[out]  buf  Buffer to set changedtick in.
/// @param[in]  changedtick  New value.
void buf_set_changedtick(buf_T *const buf, const varnumber_T changedtick)
  FUNC_ATTR_NONNULL_ALL
{
  typval_T old_val = buf->changedtick_di.di_tv;

#ifndef NDEBUG
  dictitem_T *const changedtick_di = tv_dict_find(buf->b_vars, S_LEN("changedtick"));
  assert(changedtick_di != NULL);
  assert(changedtick_di->di_tv.v_type == VAR_NUMBER);
  assert(changedtick_di->di_tv.v_lock == VAR_FIXED);
  // For some reason formatc does not like the below.
# ifndef UNIT_TESTING_LUA_PREPROCESSING
  assert(changedtick_di->di_flags == (DI_FLAGS_RO|DI_FLAGS_FIX));
# endif
  assert(changedtick_di == (dictitem_T *)&buf->changedtick_di);
#endif
  buf->changedtick_di.di_tv.vval.v_number = changedtick;

  if (tv_dict_is_watched(buf->b_vars)) {
    tv_dict_watcher_notify(buf->b_vars,
                           (char *)buf->changedtick_di.di_key,
                           &buf->changedtick_di.di_tv,
                           &old_val);
  }
}

/// Read the given buffer contents into a string.
void read_buffer_into(buf_T *buf, linenr_T start, linenr_T end, StringBuilder *sb)
  FUNC_ATTR_NONNULL_ALL
{
  assert(buf);
  assert(sb);

  if (buf->b_ml.ml_flags & ML_EMPTY) {
    return;
  }

  size_t written = 0;
  size_t len = 0;
  linenr_T lnum = start;
  char *lp = ml_get_buf(buf, lnum);
  size_t lplen = (size_t)ml_get_buf_len(buf, lnum);

  while (true) {
    if (lplen == 0) {
      len = 0;
    } else if (lp[written] == NL) {
      // NL -> NUL translation
      len = 1;
      kv_push(*sb, NUL);
    } else {
      char *s = vim_strchr(lp + written, NL);
      len = s == NULL ? lplen - written : (size_t)(s - (lp + written));
      kv_concat_len(*sb, lp + written, len);
    }

    if (len == lplen - written) {
      // Finished a line, add a NL, unless this line should not have one.
      if (lnum != end
          || (!buf->b_p_bin && buf->b_p_fixeol)
          || (lnum != buf->b_no_eol_lnum
              && (lnum != buf->b_ml.ml_line_count || buf->b_p_eol))) {
        kv_push(*sb, NL);
      }
      lnum++;
      if (lnum > end) {
        break;
      }
      lp = ml_get_buf(buf, lnum);
      lplen = (size_t)ml_get_buf_len(buf, lnum);
      written = 0;
    } else if (len > 0) {
      written += len;
    }
  }
}
