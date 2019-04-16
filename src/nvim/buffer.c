// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

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

#include <stdbool.h>
#include <string.h>
#include <inttypes.h>
#include <assert.h>

#include "nvim/api/private/handle.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/ascii.h"
#include "nvim/assert.h"
#include "nvim/vim.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/digraph.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/file_search.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/hashtab.h"
#include "nvim/highlight.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/main.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/garray.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/spell.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/version.h"
#include "nvim/window.h"
#include "nvim/shada.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"
#include "nvim/os/input.h"
#include "nvim/buffer_updates.h"

typedef enum {
  kBLSUnchanged = 0,
  kBLSChanged = 1,
  kBLSDeleted = 2,
} BufhlLineStatus;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "buffer.c.generated.h"
#endif

static char *msg_loclist = N_("[Location List]");
static char *msg_qflist = N_("[Quickfix List]");
static char *e_auabort = N_("E855: Autocommands caused command to abort");

// Number of times free_buffer() was called.
static int buf_free_count = 0;

// Read data from buffer for retrying.
static int
read_buffer(
    int     read_stdin,     // read file from stdin, otherwise fifo
    exarg_T *eap,           // for forced 'ff' and 'fenc' or NULL
    int     flags)          // extra flags for readfile()
{
  int       retval = OK;
  linenr_T  line_count;

  //
  // Read from the buffer which the text is already filled in and append at
  // the end.  This makes it possible to retry when 'fileformat' or
  // 'fileencoding' was guessed wrong.
  //
  line_count = curbuf->b_ml.ml_line_count;
  retval = readfile(
      read_stdin ? NULL : curbuf->b_ffname,
      read_stdin ? NULL : curbuf->b_fname,
      (linenr_T)line_count, (linenr_T)0, (linenr_T)MAXLNUM, eap,
      flags | READ_BUFFER);
  if (retval == OK) {
    // Delete the binary lines.
    while (--line_count >= 0) {
      ml_delete((linenr_T)1, false);
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
    if (!readonlymode && !BUFEMPTY()) {
      changed();
    } else if (retval != FAIL) {
      unchanged(curbuf, false);
    }

    apply_autocmds_retval(EVENT_STDINREADPOST, NULL, NULL, false,
                          curbuf, &retval);
  }
  return retval;
}

// Open current buffer, that is: open the memfile and read the file into
// memory.
// Return FAIL for failure, OK otherwise.
int open_buffer(
    int read_stdin,   // read file from stdin
    exarg_T *eap,     // for forced 'ff' and 'fenc' or NULL
    int flags         // extra flags for readfile()
)
{
  int retval = OK;
  bufref_T       old_curbuf;
  long old_tw = curbuf->b_p_tw;
  int read_fifo = false;

  /*
   * The 'readonly' flag is only set when BF_NEVERLOADED is being reset.
   * When re-entering the same buffer, it should not change, because the
   * user may have reset the flag by hand.
   */
  if (readonlymode && curbuf->b_ffname != NULL
      && (curbuf->b_flags & BF_NEVERLOADED))
    curbuf->b_p_ro = true;

  if (ml_open(curbuf) == FAIL) {
    /*
     * There MUST be a memfile, otherwise we can't do anything
     * If we can't create one for the current buffer, take another buffer
     */
    close_buffer(NULL, curbuf, 0, false);

    curbuf = NULL;
    FOR_ALL_BUFFERS(buf) {
      if (buf->b_ml.ml_mfp != NULL) {
        curbuf = buf;
        break;
      }
    }

    /*
     * if there is no memfile at all, exit
     * This is OK, since there are no changes to lose.
     */
    if (curbuf == NULL) {
      EMSG(_("E82: Cannot allocate any buffer, exiting..."));
      getout(2);
    }
    EMSG(_("E83: Cannot allocate buffer, using other one..."));
    enter_buffer(curbuf);
    if (old_tw != curbuf->b_p_tw) {
      check_colorcolumn(curwin);
    }
    return FAIL;
  }

  // The autocommands in readfile() may change the buffer, but only AFTER
  // reading the file.
  set_bufref(&old_curbuf, curbuf);
  modified_was_set = false;

  // mark cursor position as being invalid
  curwin->w_valid = 0;

  if (curbuf->b_ffname != NULL) {
    int old_msg_silent = msg_silent;
#ifdef UNIX
    int save_bin = curbuf->b_p_bin;
    int perm;

    perm = os_getperm((const char *)curbuf->b_ffname);
    if (perm >= 0 && (0
# ifdef S_ISFIFO
                      || S_ISFIFO(perm)
# endif
# ifdef S_ISSOCK
                      || S_ISSOCK(perm)
# endif
# ifdef OPEN_CHR_FILES
                      || (S_ISCHR(perm)
                          && is_dev_fd_file(curbuf->b_ffname))
# endif
                      )
        ) {
      read_fifo = true;
    }
    if (read_fifo) {
      curbuf->b_p_bin = true;
    }
#endif
    if (shortmess(SHM_FILEINFO)) {
      msg_silent = 1;
    }

    retval = readfile(curbuf->b_ffname, curbuf->b_fname,
                      (linenr_T)0, (linenr_T)0, (linenr_T)MAXLNUM, eap,
                      flags | READ_NEW | (read_fifo ? READ_FIFO : 0));
#ifdef UNIX
    if (read_fifo) {
      curbuf->b_p_bin = save_bin;
      if (retval == OK) {
        retval = read_buffer(false, eap, flags);
      }
    }
#endif
    msg_silent = old_msg_silent;

    // Help buffer is filtered.
    if (bt_help(curbuf)) {
      fix_help_buffer();
    }
  } else if (read_stdin) {
    int save_bin = curbuf->b_p_bin;

    /*
     * First read the text in binary mode into the buffer.
     * Then read from that same buffer and append at the end.  This makes
     * it possible to retry when 'fileformat' or 'fileencoding' was
     * guessed wrong.
     */
    curbuf->b_p_bin = true;
    retval = readfile(NULL, NULL, (linenr_T)0,
        (linenr_T)0, (linenr_T)MAXLNUM, NULL,
        flags | (READ_NEW + READ_STDIN));
    curbuf->b_p_bin = save_bin;
    if (retval == OK) {
      retval = read_buffer(true, eap, flags);
    }
  }

  // if first time loading this buffer, init b_chartab[]
  if (curbuf->b_flags & BF_NEVERLOADED) {
    (void)buf_init_chartab(curbuf, false);
    parse_cino(curbuf);
  }

  // Set/reset the Changed flag first, autocmds may change the buffer.
  // Apply the automatic commands, before processing the modelines.
  // So the modelines have priority over auto commands.

  // When reading stdin, the buffer contents always needs writing, so set
  // the changed flag.  Unless in readonly mode: "ls | nvim -R -".
  // When interrupted and 'cpoptions' contains 'i' set changed flag.
  if ((got_int && vim_strchr(p_cpo, CPO_INTMOD) != NULL)
      || modified_was_set               // ":set modified" used in autocmd
      || (aborting() && vim_strchr(p_cpo, CPO_INTMOD) != NULL)) {
    changed();
  } else if (retval != FAIL && !read_stdin && !read_fifo) {
    unchanged(curbuf, false);
  }
  save_file_ff(curbuf);                 // keep this fileformat

  // Set last_changedtick to avoid triggering a TextChanged autocommand right
  // after it was added.
  curbuf->b_last_changedtick = buf_get_changedtick(curbuf);
  curbuf->b_last_changedtick_pum = buf_get_changedtick(curbuf);

  // require "!" to overwrite the file, because it wasn't read completely
  if (aborting()) {
    curbuf->b_flags |= BF_READERR;
  }

  /* Need to update automatic folding.  Do this before the autocommands,
   * they may use the fold info. */
  foldUpdateAll(curwin);

  // need to set w_topline, unless some autocommand already did that.
  if (!(curwin->w_valid & VALID_TOPLINE)) {
    curwin->w_topline = 1;
    curwin->w_topfill = 0;
  }
  apply_autocmds_retval(EVENT_BUFENTER, NULL, NULL, false, curbuf, &retval);

  if (retval == FAIL) {
    return FAIL;
  }

  /*
   * The autocommands may have changed the current buffer.  Apply the
   * modelines to the correct buffer, if it still exists and is loaded.
   */
  if (bufref_valid(&old_curbuf) && old_curbuf.br_buf->b_ml.ml_mfp != NULL) {
    aco_save_T aco;

    // Go to the buffer that was opened.
    aucmd_prepbuf(&aco, old_curbuf.br_buf);
    do_modelines(0);
    curbuf->b_flags &= ~(BF_CHECK_RO | BF_NEVERLOADED);

    apply_autocmds_retval(EVENT_BUFWINENTER, NULL, NULL, false, curbuf,
                          &retval);

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

/// Close the link to a buffer.
///
/// @param win    If not NULL, set b_last_cursor.
/// @param buf
/// @param action Used when there is no longer a window for the buffer.
///               Possible values:
///                 0            buffer becomes hidden
///                 DOBUF_UNLOAD buffer is unloaded
///                 DOBUF_DELETE buffer is unloaded and removed from buffer list
///                 DOBUF_WIPE   buffer is unloaded and really deleted
///               When doing all but the first one on the current buffer, the
///               caller should get a new buffer very soon!
///               The 'bufhidden' option can force freeing and deleting.
/// @param abort_if_last
///               If TRUE, do not close the buffer if autocommands cause
///               there to be only one window with this buffer. e.g. when
///               ":quit" is supposed to close the window but autocommands
///               close all other windows.
void close_buffer(win_T *win, buf_T *buf, int action, int abort_if_last)
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
    } else if (buf->b_p_bh[0] == 'u')    // 'bufhidden' == "unload"
      unload_buf = true;
  }

  if (buf->terminal && (unload_buf || del_buf || wipe_buf)) {
    // terminal buffers can only be wiped
    unload_buf = true;
    del_buf = true;
    wipe_buf = true;
  }

  // Disallow deleting the buffer when it is locked (already being closed or
  // halfway a command that relies on it). Unloading is allowed.
  if (buf->b_locked > 0 && (del_buf || wipe_buf)) {
    EMSG(_("E937: Attempt to delete a buffer that is in use"));
    return;
  }

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
    if (apply_autocmds(EVENT_BUFWINLEAVE, buf->b_fname, buf->b_fname, false,
                       buf) && !bufref_valid(&bufref)) {
      // Autocommands deleted the buffer.
      EMSG(_(e_auabort));
      return;
    }
    buf->b_locked--;
    if (abort_if_last && last_nonfloat(win)) {
      // Autocommands made this the only window.
      EMSG(_(e_auabort));
      return;
    }

    // When the buffer becomes hidden, but is not unloaded, trigger
    // BufHidden
    if (!unload_buf) {
      buf->b_locked++;
      if (apply_autocmds(EVENT_BUFHIDDEN, buf->b_fname, buf->b_fname, false,
                         buf) && !bufref_valid(&bufref)) {
        // Autocommands deleted the buffer.
        EMSG(_(e_auabort));
        return;
      }
      buf->b_locked--;
      if (abort_if_last && last_nonfloat(win)) {
        // Autocommands made this the only window.
        EMSG(_(e_auabort));
        return;
      }
    }
    if (aborting()) {       // autocmds may abort script processing
      return;
    }
  }

  // If the buffer was in curwin and the window has changed, go back to that
  // window, if it still exists.  This avoids that ":edit x" triggering a
  // "tabnext" BufUnload autocmd leaves a window behind without a buffer.
  if (is_curwin && curwin != the_curwin &&  win_valid_any_tab(the_curwin)) {
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

  /* Return when a window is displaying the buffer or when it's not
   * unloaded. */
  if (buf->b_nwindows > 0 || !unload_buf) {
    return;
  }

  if (buf->terminal) {
    terminal_close(buf->terminal, NULL);
  }

  // Always remove the buffer when there is no file name.
  if (buf->b_ffname == NULL) {
    del_buf = true;
  }

  /*
   * Free all things allocated for this buffer.
   * Also calls the "BufDelete" autocommands when del_buf is TRUE.
   */
  /* Remember if we are closing the current buffer.  Restore the number of
   * windows, so that autocommands in buf_freeall() don't get confused. */
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

  buf_freeall(buf, (del_buf ? BFA_DEL : 0) + (wipe_buf ? BFA_WIPE : 0));

  if (!bufref_valid(&bufref)) {
    // Autocommands may have deleted the buffer.
    return;
  }
  if (aborting()) {
    // Autocmds may abort script processing.
    return;
  }

  /*
   * It's possible that autocommands change curbuf to the one being deleted.
   * This might cause the previous curbuf to be deleted unexpectedly.  But
   * in some cases it's OK to delete the curbuf, because a new one is
   * obtained anyway.  Therefore only return if curbuf changed to the
   * deleted buffer.
   */
  if (buf == curbuf && !is_curbuf) {
    return;
  }

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

  // Change directories when the 'acd' option is set.
  do_autochdir();

  // Disable buffer-updates for the current buffer.
  // No need to check `unload_buf`: in that case the function returned above.
  buf_updates_unregister_all(buf);

  /*
   * Remove the buffer from the list.
   */
  if (wipe_buf) {
    xfree(buf->b_ffname);
    xfree(buf->b_sfname);
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
      /* Free all internal variables and reset option values, to make
       * ":bdel" compatible with Vim 5.7. */
      free_buffer_stuff(buf, true);

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
}

/*
 * Make buffer not contain a file.
 */
void buf_clear_file(buf_T *buf)
{
  buf->b_ml.ml_line_count = 1;
  unchanged(buf, true);
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
  while (!(curbuf->b_ml.ml_flags & ML_EMPTY)) {
    ml_delete((linenr_T)1, false);
  }
  deleted_lines_mark(1, line_count);  // prepare for display
  ml_close(curbuf, true);             // free memline_T
  buf_clear_file(curbuf);
}

/// buf_freeall() - free all things allocated for a buffer that are related to
/// the file.  Careful: get here with "curwin" NULL when exiting.
///
/// @param flags BFA_DEL buffer is going to be deleted
///              BFA_WIPE buffer is going to be wiped out
///              BFA_KEEP_UNDO  do not free undo information
void buf_freeall(buf_T *buf, int flags)
{
  bool is_curbuf = (buf == curbuf);
  int is_curwin = (curwin != NULL && curwin->w_buffer == buf);
  win_T *the_curwin = curwin;
  tabpage_T *the_curtab = curtab;

  // Make sure the buffer isn't closed by autocommands.
  buf->b_locked++;

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

  // If the buffer was in curwin and the window has changed, go back to that
  // window, if it still exists.  This avoids that ":edit x" triggering a
  // "tabnext" BufUnload autocmd leaves a window behind without a buffer.
  if (is_curwin && curwin != the_curwin &&  win_valid_any_tab(the_curwin)) {
    block_autocmds();
    goto_tabpage_win(the_curtab, the_curwin);
    unblock_autocmds();
  }
  if (aborting()) {  // autocmds may abort script processing
    return;
  }

  /*
   * It's possible that autocommands change curbuf to the one being deleted.
   * This might cause curbuf to be deleted unexpectedly.  But in some cases
   * it's OK to delete the curbuf, because a new one is obtained anyway.
   * Therefore only return if curbuf changed to the deleted buffer.
   */
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
    u_blockfree(buf);               // free the memory allocated for undo
    u_clearall(buf);                // reset all undo information
  }
  syntax_clear(&buf->b_s);          // reset syntax info
  buf->b_flags &= ~BF_READERR;      // a read error is no longer relevant
}

/*
 * Free a buffer structure and the things it contains related to the buffer
 * itself (not the file, that must have been done already).
 */
static void free_buffer(buf_T *buf)
{
  handle_unregister_buffer(buf);
  buf_free_count++;
  free_buffer_stuff(buf, true);
  unref_var_dict(buf->b_vars);
  aubuflocal_remove(buf);
  tv_dict_unref(buf->additional_data);
  clear_fmark(&buf->b_last_cursor);
  clear_fmark(&buf->b_last_insert);
  clear_fmark(&buf->b_last_change);
  for (size_t i = 0; i < NMARKS; i++) {
    free_fmark(buf->b_namedm[i]);
  }
  for (int i = 0; i < buf->b_changelistlen; i++) {
    free_fmark(buf->b_changelist[i]);
  }
  if (autocmd_busy) {
    // Do not free the buffer structure while autocommands are executing,
    // it's still needed. Free it when autocmd_busy is reset.
    memset(&buf->b_namedm[0], 0, sizeof(buf->b_namedm));
    memset(&buf->b_changelist[0], 0, sizeof(buf->b_changelist));
    buf->b_next = au_pending_free_buf;
    au_pending_free_buf = buf;
  } else {
    xfree(buf);
  }
}

/*
 * Free stuff in the buffer for ":bdel" and when wiping out the buffer.
 */
static void
free_buffer_stuff(
    buf_T *buf,
    int free_options                       // free options as well
)
{
  if (free_options) {
    clear_wininfo(buf);                 // including window-local options
    free_buf_options(buf, true);
    ga_clear(&buf->b_s.b_langp);
  }
  {
    // Avoid loosing b:changedtick when deleting buffer: clearing variables
    // implies using clear_tv() on b:changedtick and that sets changedtick to
    // zero.
    hashitem_T *const changedtick_hi = hash_find(
        &buf->b_vars->dv_hashtab, (const char_u *)"changedtick");
    assert(changedtick_hi != NULL);
    hash_remove(&buf->b_vars->dv_hashtab, changedtick_hi);
  }
  vars_clear(&buf->b_vars->dv_hashtab);   // free all internal variables
  hash_init(&buf->b_vars->dv_hashtab);
  buf_init_changedtick(buf);
  uc_clear(&buf->b_ucmds);              // clear local user commands
  buf_delete_signs(buf);                // delete any signs
  bufhl_clear_all(buf);                // delete any highligts
  map_clear_int(buf, MAP_ALL_MODES, true, false);    // clear local mappings
  map_clear_int(buf, MAP_ALL_MODES, true, true);     // clear local abbrevs
  xfree(buf->b_start_fenc);
  buf->b_start_fenc = NULL;

  buf_updates_unregister_all(buf);
}

/*
 * Free the b_wininfo list for buffer "buf".
 */
static void clear_wininfo(buf_T *buf)
{
  wininfo_T   *wip;

  while (buf->b_wininfo != NULL) {
    wip = buf->b_wininfo;
    buf->b_wininfo = wip->wi_next;
    if (wip->wi_optset) {
      clear_winopt(&wip->wi_opt);
      deleteFoldRecurse(&wip->wi_folds);
    }
    xfree(wip);
  }
}

/*
 * Go to another buffer.  Handles the result of the ATTENTION dialog.
 */
void goto_buffer(exarg_T *eap, int start, int dir, int count)
{
  bufref_T old_curbuf;
  set_bufref(&old_curbuf, curbuf);
  swap_exists_action = SEA_DIALOG;

  (void)do_buffer(*eap->cmd == 's' ? DOBUF_SPLIT : DOBUF_GOTO,
                  start, dir, count, eap->forceit);

  if (swap_exists_action == SEA_QUIT && *eap->cmd == 's') {
    cleanup_T cs;

    // Reset the error/interrupt/exception state here so that
    // aborting() returns false when closing a window.
    enter_cleanup(&cs);

    // Quitting means closing the split window, nothing else.
    win_close(curwin, true);
    swap_exists_action = SEA_NONE;
    swap_exists_did_quit = true;

    /* Restore the error/interrupt/exception state if not discarded by a
     * new aborting error, interrupt, or uncaught exception. */
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
  long old_tw = curbuf->b_p_tw;
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
    close_buffer(curwin, curbuf, DOBUF_UNLOAD, false);
    if (old_curbuf == NULL
        || !bufref_valid(old_curbuf)
        || old_curbuf->br_buf == curbuf) {
      buf = buflist_new(NULL, NULL, 1L, BLN_CURBUF | BLN_LISTED);
    } else {
      buf = old_curbuf->br_buf;
    }
    if (buf != NULL) {
      int old_msg_silent = msg_silent;

      if (shortmess(SHM_FILEINFO)) {
        msg_silent = 1;  // prevent fileinfo message
      }
      enter_buffer(buf);
      // restore msg_silent, so that the command line will be shown
      msg_silent = old_msg_silent;

      if (old_tw != curbuf->b_p_tw) {
        check_colorcolumn(curwin);
      }
    }
    // If "old_curbuf" is NULL we are in big trouble here...

    /* Restore the error/interrupt/exception state if not discarded by a
     * new aborting error, interrupt, or uncaught exception. */
    leave_cleanup(&cs);
  } else if (swap_exists_action == SEA_RECOVER) {
    // Reset the error/interrupt/exception state here so that
    // aborting() returns false when closing a buffer.
    enter_cleanup(&cs);

    // User selected Recover at ATTENTION prompt.
    msg_scroll = true;
    ml_recover();
    MSG_PUTS("\n");     // don't overwrite the last message
    cmdline_row = msg_row;
    do_modelines(0);

    /* Restore the error/interrupt/exception state if not discarded by a
     * new aborting error, interrupt, or uncaught exception. */
    leave_cleanup(&cs);
  }
  swap_exists_action = SEA_NONE;  // -V519
}

/*
 * do_bufdel() - delete or unload buffer(s)
 *
 * addr_count == 0: ":bdel" - delete current buffer
 * addr_count == 1: ":N bdel" or ":bdel N [N ..]" - first delete
 *		    buffer "end_bnr", then any other arguments.
 * addr_count == 2: ":N,N bdel" - delete buffers in range
 *
 * command can be DOBUF_UNLOAD (":bunload"), DOBUF_WIPE (":bwipeout") or
 * DOBUF_DEL (":bdel")
 *
 * Returns error message or NULL
 */
char_u *
do_bufdel(
    int command,
    char_u *arg,               // pointer to extra arguments
    int addr_count,
    int start_bnr,             // first buffer number in a range
    int end_bnr,               // buffer nr or last buffer nr in a range
    int forceit
)
{
  int do_current = 0;             // delete current buffer?
  int deleted = 0;                // number of buffers deleted
  char_u      *errormsg = NULL;   // return value
  int bnr;                        // buffer number
  char_u      *p;

  if (addr_count == 0) {
    (void)do_buffer(command, DOBUF_CURRENT, FORWARD, 0, forceit);
  } else {
    if (addr_count == 2) {
      if (*arg) {               // both range and argument is not allowed
        return (char_u *)_(e_trailing);
      }
      bnr = start_bnr;
    } else {    // addr_count == 1
      bnr = end_bnr;
    }

    for (; !got_int; os_breakcheck()) {
      /*
       * delete the current buffer last, otherwise when the
       * current buffer is deleted, the next buffer becomes
       * the current one and will be loaded, which may then
       * also be deleted, etc.
       */
      if (bnr == curbuf->b_fnum) {
        do_current = bnr;
      } else if (do_buffer(command, DOBUF_FIRST, FORWARD, bnr,
                           forceit) == OK) {
        deleted++;
      }

      /*
       * find next buffer number to delete/unload
       */
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
          p = skiptowhite_esc(arg);
          bnr = buflist_findpat(arg, p, command == DOBUF_WIPE,
                                false, false);
          if (bnr < 0) {                    // failed
            break;
          }
          arg = p;
        } else
          bnr = getdigits_int(&arg);
      }
    }
    if (!got_int && do_current
        && do_buffer(command, DOBUF_FIRST,
                     FORWARD, do_current, forceit) == OK) {
      deleted++;
    }

    if (deleted == 0) {
      if (command == DOBUF_UNLOAD) {
        STRCPY(IObuff, _("E515: No buffers were unloaded"));
      } else if (command == DOBUF_DEL) {
        STRCPY(IObuff, _("E516: No buffers were deleted"));
      } else {
        STRCPY(IObuff, _("E517: No buffers were wiped out"));
      }
      errormsg = IObuff;
    } else if (deleted >= p_report) {
      if (command == DOBUF_UNLOAD) {
        if (deleted == 1) {
          MSG(_("1 buffer unloaded"));
        } else {
          smsg(_("%d buffers unloaded"), deleted);
        }
      } else if (command == DOBUF_DEL) {
        if (deleted == 1) {
          MSG(_("1 buffer deleted"));
        } else {
          smsg(_("%d buffers deleted"), deleted);
        }
      } else {
        if (deleted == 1) {
          MSG(_("1 buffer wiped out"));
        } else {
          smsg(_("%d buffers wiped out"), deleted);
        }
      }
    }
  }


  return errormsg;
}



/*
 * Make the current buffer empty.
 * Used when it is wiped out and it's the last buffer.
 */
static int empty_curbuf(int close_others, int forceit, int action)
{
  int retval;
  buf_T   *buf = curbuf;

  if (action == DOBUF_UNLOAD) {
    EMSG(_("E90: Cannot unload last buffer"));
    return FAIL;
  }

  bufref_T bufref;
  set_bufref(&bufref, buf);

  if (close_others) {
    // Close any other windows on this buffer, then make it empty.
    close_windows(buf, true);
  }

  setpcmark();
  retval = do_ecmd(0, NULL, NULL, NULL, ECMD_ONE,
      forceit ? ECMD_FORCEIT : 0, curwin);

  // do_ecmd() may create a new buffer, then we have to delete
  // the old one.  But do_ecmd() may have done that already, check
  // if the buffer still exists.
  if (buf != curbuf && bufref_valid(&bufref) && buf->b_nwindows == 0) {
    close_buffer(NULL, buf, action, false);
  }

  if (!close_others) {
    need_fileinfo = false;
  }

  return retval;
}
/*
 * Implementation of the commands for the buffer list.
 *
 * action == DOBUF_GOTO	    go to specified buffer
 * action == DOBUF_SPLIT    split window and go to specified buffer
 * action == DOBUF_UNLOAD   unload specified buffer(s)
 * action == DOBUF_DEL	    delete specified buffer(s) from buffer list
 * action == DOBUF_WIPE	    delete specified buffer(s) really
 *
 * start == DOBUF_CURRENT   go to "count" buffer from current buffer
 * start == DOBUF_FIRST	    go to "count" buffer from first buffer
 * start == DOBUF_LAST	    go to "count" buffer from last buffer
 * start == DOBUF_MOD	    go to "count" modified buffer from current buffer
 *
 * Return FAIL or OK.
 */
int
do_buffer(
    int action,
    int start,
    int dir,                        // FORWARD or BACKWARD
    int count,                      // buffer number or number of buffers
    int forceit                     // true for :...!
)
{
  buf_T       *buf;
  buf_T       *bp;
  int unload = (action == DOBUF_UNLOAD || action == DOBUF_DEL
                || action == DOBUF_WIPE);

  switch (start) {
  case DOBUF_FIRST:   buf = firstbuf; break;
  case DOBUF_LAST:    buf = lastbuf;  break;
  default:            buf = curbuf;   break;
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
      EMSG(_("E84: No modified buffer found"));
      return FAIL;
    }
  } else if (start == DOBUF_FIRST && count) {  // find specified buffer number
    while (buf != NULL && buf->b_fnum != count) {
      buf = buf->b_next;
    }
  } else {
    bp = NULL;
    while (count > 0 || (!unload && !buf->b_p_bl && bp != buf)) {
      /* remember the buffer where we start, we come back there when all
       * buffers are unlisted. */
      if (bp == NULL) {
        bp = buf;
      }
      if (dir == FORWARD) {
        buf = buf->b_next;
        if (buf == NULL) {
          buf = firstbuf;
        }
      } else {
        buf = buf->b_prev;
        if (buf == NULL) {
          buf = lastbuf;
        }
      }
      // don't count unlisted buffers
      if (unload || buf->b_p_bl) {
        count--;
        bp = NULL;              // use this buffer as new starting point
      }
      if (bp == buf) {
        // back where we started, didn't find anything.
        EMSG(_("E85: There is no listed buffer"));
        return FAIL;
      }
    }
  }

  if (buf == NULL) {        // could not find it
    if (start == DOBUF_FIRST) {
      // don't warn when deleting
      if (!unload) {
        EMSGN(_(e_nobufnr), count);
      }
    } else if (dir == FORWARD) {
      EMSG(_("E87: Cannot go beyond last buffer"));
    } else {
      EMSG(_("E88: Cannot go before first buffer"));
    }
    return FAIL;
  }


  /*
   * delete buffer buf from memory and/or the list
   */
  if (unload) {
    int forward;
    bufref_T bufref;
    set_bufref(&bufref, buf);

    /* When unloading or deleting a buffer that's already unloaded and
     * unlisted: fail silently. */
    if (action != DOBUF_WIPE && buf->b_ml.ml_mfp == NULL && !buf->b_p_bl) {
      return FAIL;
    }

    if (!forceit && (buf->terminal || bufIsChanged(buf))) {
      if ((p_confirm || cmdmod.confirm) && p_write && !buf->terminal) {
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
        if (buf->terminal) {
          if (p_confirm || cmdmod.confirm) {
            if (!dialog_close_terminal(buf)) {
              return FAIL;
            }
          } else {
            EMSG2(_("E89: %s will be killed(add ! to override)"),
                  (char *)buf->b_fname);
            return FAIL;
          }
        } else {
          EMSGN(_("E89: No write since last change for buffer %" PRId64
                  " (add ! to override)"),
                buf->b_fnum);
          return FAIL;
        }
      }
    }

    // When closing the current buffer stop Visual mode.
    if (buf == curbuf && VIsual_active) {
      end_visual_mode();
    }

    /*
     * If deleting the last (listed) buffer, make it empty.
     * The last (listed) buffer cannot be unloaded.
     */
    bp = NULL;
    FOR_ALL_BUFFERS(bp2) {
      if (bp2->b_p_bl && bp2 != buf) {
        bp = bp2;
        break;
      }
    }
    if (bp == NULL && buf == curbuf) {
      return empty_curbuf(true, forceit, action);
    }

    /*
     * If the deleted buffer is the current one, close the current window
     * (unless it's the only window).  Repeat this so long as we end up in
     * a window with this buffer.
     */
    while (buf == curbuf
           && !(curwin->w_closing || curwin->w_buffer->b_locked > 0)
           && (!ONE_WINDOW || first_tabpage->tp_next != NULL)) {
      if (win_close(curwin, false) == FAIL) {
        break;
      }
    }

    /*
     * If the buffer to be deleted is not the current one, delete it here.
     */
    if (buf != curbuf) {
      close_windows(buf, false);
      if (buf != curbuf && bufref_valid(&bufref) && buf->b_nwindows <= 0) {
        close_buffer(NULL, buf, action, false);
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
      int jumpidx;

      jumpidx = curwin->w_jumplistidx - 1;
      if (jumpidx < 0) {
        jumpidx = curwin->w_jumplistlen - 1;
      }

      forward = jumpidx;
      while (jumpidx != curwin->w_jumplistidx) {
        buf = buflist_findnr(curwin->w_jumplist[jumpidx].fmark.fnum);
        if (buf != NULL) {
          if (buf == curbuf || !buf->b_p_bl) {
            buf = NULL;                 // skip current and unlisted bufs
          } else if (buf->b_ml.ml_mfp == NULL) {
            // skip unloaded buf, but may keep it for later
            if (bp == NULL) {
              bp = buf;
            }
            buf = NULL;
          }
        }
        if (buf != NULL) {         // found a valid buffer: stop searching
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

    if (buf == NULL) {          // No previous buffer, Try 2'nd approach
      forward = true;
      buf = curbuf->b_next;
      for (;; ) {
        if (buf == NULL) {
          if (!forward) {               // tried both directions
            break;
          }
          buf = curbuf->b_prev;
          forward = false;
          continue;
        }
        // in non-help buffer, try to skip help buffers, and vv
        if (buf->b_help == curbuf->b_help && buf->b_p_bl) {
          if (buf->b_ml.ml_mfp != NULL) {           // found loaded buffer
            break;
          }
          if (bp == NULL) {             // remember unloaded buf for later
            bp = buf;
          }
        }
        if (forward) {
          buf = buf->b_next;
        } else {
          buf = buf->b_prev;
        }
      }
    }
    if (buf == NULL) {          // No loaded buffer, use unloaded one
      buf = bp;
    }
    if (buf == NULL) {          // No loaded buffer, find listed one
      FOR_ALL_BUFFERS(buf2) {
        if (buf2->b_p_bl && buf2 != curbuf) {
          buf = buf2;
          break;
        }
      }
    }
    if (buf == NULL) {          // Still no buffer, just take one
      if (curbuf->b_next != NULL) {
        buf = curbuf->b_next;
      } else {
        buf = curbuf->b_prev;
      }
    }
  }

  if (buf == NULL) {
    /* Autocommands must have wiped out all other buffers.  Only option
     * now is to make the current buffer empty. */
    return empty_curbuf(false, forceit, action);
  }

  /*
   * make buf current buffer
   */
  if (action == DOBUF_SPLIT) {      // split window first
    // If 'switchbuf' contains "useopen": jump to first window containing
    // "buf" if one exists
    if ((swb_flags & SWB_USEOPEN) && buf_jump_open_win(buf)) {
      return OK;
    }
    // If 'switchbuf' contains "usetab": jump to first window in any tab
    // page containing "buf" if one exists
    if ((swb_flags & SWB_USETAB) && buf_jump_open_tab(buf)) {
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

  /*
   * Check if the current buffer may be abandoned.
   */
  if (action == DOBUF_GOTO && !can_abandon(curbuf, forceit)) {
    if ((p_confirm || cmdmod.confirm) && p_write) {
      bufref_T bufref;
      set_bufref(&bufref, buf);
      dialog_changed(curbuf, false);
      if (!bufref_valid(&bufref)) {
        // Autocommand deleted buffer, oops!
        return FAIL;
      }
    }
    if (bufIsChanged(curbuf)) {
      EMSG(_(e_nowrtmsg));
      return FAIL;
    }
  }

  // Go to the other buffer.
  set_curbuf(buf, action);

  if (action == DOBUF_SPLIT) {
    RESET_BINDING(curwin);      // reset 'scrollbind' and 'cursorbind'
  }

  if (aborting()) {         // autocmds may abort script processing
    return FAIL;
  }

  return OK;
}


/*
 * Set current buffer to "buf".  Executes autocommands and closes current
 * buffer.  "action" tells how to close the current buffer:
 * DOBUF_GOTO	    free or hide it
 * DOBUF_SPLIT	    nothing
 * DOBUF_UNLOAD	    unload it
 * DOBUF_DEL	    delete it
 * DOBUF_WIPE	    wipe it out
 */
void set_curbuf(buf_T *buf, int action)
{
  buf_T       *prevbuf;
  int unload = (action == DOBUF_UNLOAD || action == DOBUF_DEL
                || action == DOBUF_WIPE);
  long old_tw = curbuf->b_p_tw;

  setpcmark();
  if (!cmdmod.keepalt) {
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

  // Autocommands may delete the curren buffer and/or the buffer we wan to go
  // to.  In those cases don't close the buffer.
  if (!apply_autocmds(EVENT_BUFLEAVE, NULL, NULL, false, curbuf)
      || (bufref_valid(&prevbufref) && bufref_valid(&newbufref)
          && !aborting())) {
    if (prevbuf == curwin->w_buffer) {
      reset_synblock(curwin);
    }
    if (unload) {
      close_windows(prevbuf, false);
    }
    if (bufref_valid(&prevbufref) && !aborting()) {
      win_T  *previouswin = curwin;
      if (prevbuf == curbuf) {
        u_sync(false);
      }
      close_buffer(prevbuf == curwin->w_buffer ? curwin : NULL,
                   prevbuf,
                   unload
                   ? action
                   : (action == DOBUF_GOTO && !buf_hide(prevbuf)
                      && !bufIsChanged(prevbuf)) ? DOBUF_UNLOAD : 0,
                   false);
      if (curwin != previouswin && win_valid(previouswin)) {
        // autocommands changed curwin, Grr!
        curwin = previouswin;
      }
    }
  }
  /* An autocommand may have deleted "buf", already entered it (e.g., when
   * it did ":bunload") or aborted the script processing!
   * If curwin->w_buffer is null, enter_buffer() will make it valid again */
  if ((buf_valid(buf) && buf != curbuf
       && !aborting()
       ) || curwin->w_buffer == NULL
      ) {
    enter_buffer(buf);
    if (old_tw != curbuf->b_p_tw) {
      check_colorcolumn(curwin);
    }
  }

  if (bufref_valid(&prevbufref) && prevbuf->terminal != NULL) {
    terminal_check_size(prevbuf->terminal);
  }
}

/*
 * Enter a new current buffer.
 * Old curbuf must have been abandoned already!  This also means "curbuf" may
 * be pointing to freed memory.
 */
void enter_buffer(buf_T *buf)
{
  // Copy buffer and window local option values.  Not for a help buffer.
  buf_copy_options(buf, BCO_ENTER | BCO_NOHELP);
  if (!buf->b_help) {
    get_winopts(buf);
  } else {
    // Remove all folds in the window.
    clearFolding(curwin);
  }
  foldUpdateAll(curwin);        // update folds (later).

  // Get the buffer in the current window.
  curwin->w_buffer = buf;
  curbuf = buf;
  curbuf->b_nwindows++;

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
      did_filetype = false;
    }

    open_buffer(false, NULL, 0);
  } else {
    if (!msg_silent) {
      need_fileinfo = true;             // display file info after redraw
    }
    (void)buf_check_timestamp(curbuf, false);     // check if file changed
    curwin->w_topline = 1;
    curwin->w_topfill = 0;
    apply_autocmds(EVENT_BUFENTER, NULL, NULL, false, curbuf);
    apply_autocmds(EVENT_BUFWINENTER, NULL, NULL, false, curbuf);
  }

  /* If autocommands did not change the cursor position, restore cursor lnum
   * and possibly cursor col. */
  if (curwin->w_cursor.lnum == 1 && inindent(0)) {
    buflist_getfpos();
  }

  check_arg_idx(curwin);                // check for valid arg_idx
  maketitle();
  // when autocmds didn't change it
  if (curwin->w_topline == 1 && !curwin->w_topline_was_set) {
    scroll_cursor_halfway(false);       // redisplay at correct position
  }


  // Change directories when the 'acd' option is set.
  do_autochdir();

  if (curbuf->b_kmap_state & KEYMAP_INIT) {
    (void)keymap_init();
  }
  // May need to set the spell language.  Can only do this after the buffer
  // has been properly setup.
  if (!curbuf->b_help && curwin->w_p_spell && *curwin->w_s->b_p_spl != NUL) {
    (void)did_set_spelllang(curwin);
  }

  redraw_later(NOT_VALID);
}

// Change to the directory of the current buffer.
// Don't do this while still starting up.
void do_autochdir(void)
{
  if (p_acd) {
    if (starting == 0
        && curbuf->b_ffname != NULL
        && vim_chdirfile(curbuf->b_ffname) == OK) {
      post_chdir(kCdScopeGlobal, false);
      shorten_fnames(true);
    }
  }
}

//
// functions for dealing with the buffer list
//

static int top_file_num = 1;            ///< highest file number

/// Initialize b:changedtick and changedtick_val attribute
///
/// @param[out]  buf  Buffer to intialize for.
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
/// @param ffname full path of fname or relative
/// @param sfname short fname or NULL
/// @param lnum   preferred cursor line
/// @param flags  BLN_ defines
/// @param bufnr
///
/// @return pointer to the buffer
buf_T * buflist_new(char_u *ffname, char_u *sfname, linenr_T lnum, int flags)
{
  buf_T       *buf;

  fname_expand(curbuf, &ffname, &sfname);       // will allocate ffname

  /*
   * If file name already exists in the list, update the entry.
   */
  /* We can use inode numbers when the file exists.  Works better
   * for hard links. */
  FileID file_id;
  bool file_id_valid = (sfname != NULL
                        && os_fileid((char *)sfname, &file_id));
  if (ffname != NULL && !(flags & (BLN_DUMMY | BLN_NEW))
      && (buf = buflist_findname_file_id(ffname, &file_id,
                                         file_id_valid)) != NULL) {
    xfree(ffname);
    if (lnum != 0) {
      buflist_setfpos(buf, curwin, lnum, (colnr_T)0, false);
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

  /*
   * If the current buffer has no name and no contents, use the current
   * buffer.	Otherwise: Need to allocate a new buffer structure.
   *
   * This is the ONLY place where a new buffer structure is allocated!
   * (A spell file buffer is allocated in spell.c, but that's not a normal
   * buffer.)
   */
  buf = NULL;
  if ((flags & BLN_CURBUF) && curbuf_reusable()) {
    assert(curbuf != NULL);
    buf = curbuf;
    /* It's like this buffer is deleted.  Watch out for autocommands that
     * change curbuf!  If that happens, allocate a new buffer anyway. */
    if (curbuf->b_p_bl) {
      apply_autocmds(EVENT_BUFDELETE, NULL, NULL, false, curbuf);
    }
    if (buf == curbuf) {
      apply_autocmds(EVENT_BUFWIPEOUT, NULL, NULL, false, curbuf);
    }
    if (aborting()) {           // autocmds may abort script processing
      return NULL;
    }
    if (buf == curbuf) {
      // Make sure 'bufhidden' and 'buftype' are empty
      clear_string_option(&buf->b_p_bh);
      clear_string_option(&buf->b_p_bt);
    }
  }
  if (buf != curbuf || curbuf == NULL) {
    buf = xcalloc(1, sizeof(buf_T));
    // init b: variables
    buf->b_vars = tv_dict_alloc();
    buf->b_signcols_max = -1;
    init_var_dict(buf->b_vars, &buf->b_bufvar, VAR_SCOPE);
    buf_init_changedtick(buf);
  }

  if (ffname != NULL) {
    buf->b_ffname = ffname;
    buf->b_sfname = vim_strsave(sfname);
  }

  clear_wininfo(buf);
  buf->b_wininfo = xcalloc(1, sizeof(wininfo_T));

  if (ffname != NULL && (buf->b_ffname == NULL || buf->b_sfname == NULL)) {
    xfree(buf->b_ffname);
    buf->b_ffname = NULL;
    xfree(buf->b_sfname);
    buf->b_sfname = NULL;
    if (buf != curbuf) {
      free_buffer(buf);
    }
    return NULL;
  }

  if (buf == curbuf) {
    // free all things allocated for this buffer
    buf_freeall(buf, 0);
    if (buf != curbuf) {         // autocommands deleted the buffer!
      return NULL;
    }
    if (aborting()) {           // autocmds may abort script processing
      return NULL;
    }
    free_buffer_stuff(buf, false);      // delete local variables et al.

    // Init the options.
    buf->b_p_initialized = false;
    buf_copy_options(buf, BCO_ENTER);

    // need to reload lmaps and set b:keymap_name
    curbuf->b_kmap_state |= KEYMAP_INIT;
  } else {
    /*
     * put new buffer at the end of the buffer list
     */
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
    handle_register_buffer(buf);
    if (top_file_num < 0) {  // wrap around (may cause duplicates)
      EMSG(_("W14: Warning: List of file names overflow"));
      if (emsg_silent == 0) {
        ui_flush();
        os_delay(3000L, true);  // make sure it is noticed
      }
      top_file_num = 1;
    }

    /*
     * Always copy the options from the current buffer.
     */
    buf_copy_options(buf, BCO_ALWAYS);
  }

  buf->b_wininfo->wi_fpos.lnum = lnum;
  buf->b_wininfo->wi_win = curwin;

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
  clrallmarks(buf);                     // clear marks
  fmarks_check_names(buf);              // check file marks for this file
  buf->b_p_bl = (flags & BLN_LISTED) ? true : false;    // init 'buflisted'
  kv_destroy(buf->update_channels);
  kv_init(buf->update_channels);
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

  return buf;
}

/// Return true if the current buffer is empty, unnamed, unmodified and used in
/// only one window. That means it can be reused.
bool curbuf_reusable(void)
{
  return (curbuf != NULL
          && curbuf->b_ffname == NULL
          && curbuf->b_nwindows <= 1
          && (curbuf->b_ml.ml_mfp == NULL || BUFEMPTY())
          && !bt_quickfix(curbuf)
          && !curbufIsChanged());
}

/*
 * Free the memory for the options of a buffer.
 * If "free_p_ff" is true also free 'fileformat', 'buftype' and
 * 'fileencoding'.
 */
void free_buf_options(buf_T *buf, int free_p_ff)
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
  clear_string_option(&buf->b_p_sua);
  clear_string_option(&buf->b_p_ft);
  clear_string_option(&buf->b_p_cink);
  clear_string_option(&buf->b_p_cino);
  clear_string_option(&buf->b_p_cinw);
  clear_string_option(&buf->b_p_cpt);
  clear_string_option(&buf->b_p_cfu);
  clear_string_option(&buf->b_p_ofu);
  clear_string_option(&buf->b_p_gp);
  clear_string_option(&buf->b_p_mp);
  clear_string_option(&buf->b_p_efm);
  clear_string_option(&buf->b_p_ep);
  clear_string_option(&buf->b_p_path);
  clear_string_option(&buf->b_p_tags);
  clear_string_option(&buf->b_p_tc);
  clear_string_option(&buf->b_p_dict);
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
  buf_T       *buf;
  win_T       *wp = NULL;
  pos_T       *fpos;
  colnr_T col;

  buf = buflist_findnr(n);
  if (buf == NULL) {
    if ((options & GETF_ALT) && n == 0) {
      EMSG(_(e_noalt));
    } else {
      EMSGN(_("E92: Buffer %" PRId64 " not found"), n);
    }
    return FAIL;
  }

  // if alternate file is the current buffer, nothing to do
  if (buf == curbuf) {
    return OK;
  }

  if (text_locked()) {
    text_locked_msg();
    return FAIL;
  }
  if (curbuf_locked()) {
    return FAIL;
  }

  // altfpos may be changed by getfile(), get it now
  if (lnum == 0) {
    fpos = buflist_findfpos(buf);
    lnum = fpos->lnum;
    col = fpos->col;
  } else
    col = 0;

  if (options & GETF_SWITCH) {
    // If 'switchbuf' contains "useopen": jump to first window containing
    // "buf" if one exists
    if (swb_flags & SWB_USEOPEN) {
      wp = buf_jump_open_win(buf);
    }

    // If 'switchbuf' contains "usetab": jump to first window in any tab
    // page containing "buf" if one exists
    if (wp == NULL && (swb_flags & SWB_USETAB)) {
      wp = buf_jump_open_tab(buf);
    }

    // If 'switchbuf' contains "split", "vsplit" or "newtab" and the
    // current buffer isn't empty: open new tab or window
    if (wp == NULL && (swb_flags & (SWB_VSPLIT | SWB_SPLIT | SWB_NEWTAB))
        && !BUFEMPTY()) {
      if (swb_flags & SWB_NEWTAB) {
        tabpage_new();
      } else if (win_split(0, (swb_flags & SWB_VSPLIT) ? WSP_VERT : 0)
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
      check_cursor_col();
      curwin->w_cursor.coladd = 0;
      curwin->w_set_curswant = true;
    }
    return OK;
  }
  RedrawingDisabled--;
  return FAIL;
}

// Go to the last known line number for the current buffer.
void buflist_getfpos(void)
{
  pos_T       *fpos;

  fpos = buflist_findfpos(curbuf);

  curwin->w_cursor.lnum = fpos->lnum;
  check_cursor_lnum();

  if (p_sol) {
    curwin->w_cursor.col = 0;
  } else {
    curwin->w_cursor.col = fpos->col;
    check_cursor_col();
    curwin->w_cursor.coladd = 0;
    curwin->w_set_curswant = true;
  }
}

/*
 * Find file in buffer list by name (it has to be for the current window).
 * Returns NULL if not found.
 */
buf_T *buflist_findname_exp(char_u *fname)
{
  char_u      *ffname;
  buf_T       *buf = NULL;

  // First make the name into a full path name
  ffname = (char_u *)FullName_save((char *)fname,
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

/*
 * Find file in buffer list by name (it has to be for the current window).
 * "ffname" must have a full path.
 * Skips dummy buffers.
 * Returns NULL if not found.
 */
buf_T *buflist_findname(char_u *ffname)
{
  FileID file_id;
  bool file_id_valid = os_fileid((char *)ffname, &file_id);
  return buflist_findname_file_id(ffname, &file_id, file_id_valid);
}

/*
 * Same as buflist_findname(), but pass the FileID structure to avoid
 * getting it twice for the same file.
 * Returns NULL if not found.
 */
static buf_T *buflist_findname_file_id(char_u *ffname, FileID *file_id,
                                       bool file_id_valid)
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
/// Return fnum of the found buffer.
/// Return < 0 for error.
int buflist_findpat(
    const char_u *pattern,
    const char_u *pattern_end,  // pointer to first char after pattern
    int unlisted,               // find unlisted buffers
    int diffmode,               // find diff-mode buffers only
    int curtab_only             // find buffers in current tab only
)
{
  int match = -1;
  int find_listed;
  char_u      *pat;
  char_u      *patend;
  int attempt;
  char_u      *p;
  int toggledollar;

  if (pattern_end == pattern + 1 && (*pattern == '%' || *pattern == '#')) {
    if (*pattern == '%') {
      match = curbuf->b_fnum;
    } else {
      match = curwin->w_alt_fnum;
    }
    buf_T *found_buf = buflist_findnr(match);
    if (diffmode && !(found_buf && diff_mode_buf(found_buf))) {
      match = -1;
    }
  } else {
    //
    // Try four ways of matching a listed buffer:
    // attempt == 0: without '^' or '$' (at any position)
    // attempt == 1: with '^' at start (only at position 0)
    // attempt == 2: with '$' at end (only match at end)
    // attempt == 3: with '^' at start and '$' at end (only full match)
    // Repeat this for finding an unlisted buffer if there was no matching
    // listed buffer.
    //

    pat = file_pat_to_reg_pat(pattern, pattern_end, NULL, false);
    if (pat == NULL) {
      return -1;
    }
    patend = pat + STRLEN(pat) - 1;
    toggledollar = (patend > pat && *patend == '$');

    // First try finding a listed buffer.  If not found and "unlisted"
    // is true, try finding an unlisted buffer.
    find_listed = true;
    for (;; ) {
      for (attempt = 0; attempt <= 3; attempt++) {
        // may add '^' and '$'
        if (toggledollar) {
          *patend = (attempt < 2) ? NUL : '$';           // add/remove '$'
        }
        p = pat;
        if (*p == '^' && !(attempt & 1)) {               // add/remove '^'
          p++;
        }

        regmatch_T regmatch;
        regmatch.regprog = vim_regcomp(p, p_magic ? RE_MAGIC : 0);
        if (regmatch.regprog == NULL) {
          xfree(pat);
          return -1;
        }

        FOR_ALL_BUFFERS_BACKWARDS(buf) {
          if (buf->b_p_bl == find_listed
              && (!diffmode || diff_mode_buf(buf))
              && buflist_match(&regmatch, buf, false) != NULL) {
            if (curtab_only) {
              /* Ignore the match if the buffer is not open in
               * the current tab. */
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

      /* Only search for unlisted buffers if there was no match with
       * a listed buffer. */
      if (!unlisted || !find_listed || match != -1) {
        break;
      }
      find_listed = false;
    }

    xfree(pat);
  }

  if (match == -2) {
    EMSG2(_("E93: More than one match for %s"), pattern);
  } else if (match < 0) {
    EMSG2(_("E94: No matching buffer for %s"), pattern);
  }
  return match;
}


/*
 * Find all buffer names that match.
 * For command line expansion of ":buf" and ":sbuf".
 * Return OK if matches found, FAIL otherwise.
 */
int ExpandBufnames(char_u *pat, int *num_file, char_u ***file, int options)
{
  int count = 0;
  int round;
  char_u      *p;
  int attempt;
  char_u      *patc;

  *num_file = 0;                    // return values in case of FAIL
  *file = NULL;

  // Make a copy of "pat" and change "^" to "\(^\|[\/]\)".
  if (*pat == '^') {
    patc = xmalloc(STRLEN(pat) + 11);
    STRCPY(patc, "\\(^\\|[\\/]\\)");
    STRCPY(patc + 11, pat + 1);
  } else
    patc = pat;

  /*
   * attempt == 0: try match with    '\<', match at start of word
   * attempt == 1: try match without '\<', match anywhere
   */
  for (attempt = 0; attempt <= 1; attempt++) {
    if (attempt > 0 && patc == pat) {
      break;            // there was no anchor, no need to try again
    }

    regmatch_T regmatch;
    regmatch.regprog = vim_regcomp(patc + attempt * 11, RE_MAGIC);
    if (regmatch.regprog == NULL) {
      if (patc != pat) {
        xfree(patc);
      }
      return FAIL;
    }

    /*
     * round == 1: Count the matches.
     * round == 2: Build the array to keep the matches.
     */
    for (round = 1; round <= 2; round++) {
      count = 0;
      FOR_ALL_BUFFERS(buf) {
        if (!buf->b_p_bl) {             // skip unlisted buffers
          continue;
        }
        p = buflist_match(&regmatch, buf, p_wic);
        if (p != NULL) {
          if (round == 1) {
            count++;
          } else {
            if (options & WILD_HOME_REPLACE) {
              p = home_replace_save(buf, p);
            } else {
              p = vim_strsave(p);
            }
            (*file)[count++] = p;
          }
        }
      }
      if (count == 0) {         // no match found, break here
        break;
      }
      if (round == 1) {
        *file = xmalloc((size_t)count * sizeof(**file));
      }
    }
    vim_regfree(regmatch.regprog);
    if (count) {                // match(es) found, break here
      break;
    }
  }

  if (patc != pat) {
    xfree(patc);
  }

  *num_file = count;
  return count == 0 ? FAIL : OK;
}


/// Check for a match on the file name for buffer "buf" with regprog "prog".
///
/// @param ignore_case When true, ignore case. Use 'fic' otherwise.
static char_u *buflist_match(regmatch_T *rmp, buf_T *buf, bool ignore_case)
{
  // First try the short file name, then the long file name.
  char_u *match = fname_match(rmp, buf->b_sfname, ignore_case);
  if (match == NULL) {
    match = fname_match(rmp, buf->b_ffname, ignore_case);
  }
  return match;
}

/// Try matching the regexp in "prog" with file name "name".
///
/// @param ignore_case When true, ignore case. Use 'fileignorecase' otherwise.
/// @return "name" when there is a match, NULL when not.
static char_u *fname_match(regmatch_T *rmp, char_u *name, bool ignore_case)
{
  char_u      *match = NULL;
  char_u      *p;

  if (name != NULL) {
    // Ignore case when 'fileignorecase' or the argument is set.
    rmp->rm_ic = p_fic || ignore_case;
    if (vim_regexec(rmp, name, (colnr_T)0)) {
      match = name;
    } else {
      // Replace $(HOME) with '~' and try matching again.
      p = home_replace_save(NULL, name);
      if (vim_regexec(rmp, p, (colnr_T)0)) {
        match = name;
      }
      xfree(p);
    }
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

/*
 * Get name of file 'n' in the buffer list.
 * When the file has no name an empty string is returned.
 * home_replace() is used to shorten the file name (used for marks).
 * Returns a pointer to allocated memory, of NULL when failed.
 */
char_u *
buflist_nr2name(
    int n,
    int fullname,
    int helptail                   // for help buffers return tail only
)
{
  buf_T       *buf;

  buf = buflist_findnr(n);
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
/// @param[in]      lnum          Line number to be set. If it is zero then only
///                               options are touched.
/// @param[in]      col           Column number to be set.
/// @param[in]      copy_options  If true save the local window option values.
void buflist_setfpos(buf_T *const buf, win_T *const win,
                     linenr_T lnum, colnr_T col,
                     bool copy_options)
  FUNC_ATTR_NONNULL_ALL
{
  wininfo_T   *wip;

  for (wip = buf->b_wininfo; wip != NULL; wip = wip->wi_next) {
    if (wip->wi_win == win) {
      break;
    }
  }
  if (wip == NULL) {
    // allocate a new entry
    wip = xcalloc(1, sizeof(wininfo_T));
    wip->wi_win = win;
    if (lnum == 0) {            // set lnum even when it's 0
      lnum = 1;
    }
  } else {
    // remove the entry from the list
    if (wip->wi_prev) {
      wip->wi_prev->wi_next = wip->wi_next;
    } else {
      buf->b_wininfo = wip->wi_next;
    }
    if (wip->wi_next) {
      wip->wi_next->wi_prev = wip->wi_prev;
    }
    if (copy_options && wip->wi_optset) {
      clear_winopt(&wip->wi_opt);
      deleteFoldRecurse(&wip->wi_folds);
    }
  }
  if (lnum != 0) {
    wip->wi_fpos.lnum = lnum;
    wip->wi_fpos.col = col;
  }
  if (copy_options) {
    // Save the window-specific option values.
    copy_winopt(&win->w_onebuf_opt, &wip->wi_opt);
    wip->wi_fold_manual = win->w_fold_manual;
    cloneFoldGrowArray(&win->w_folds, &wip->wi_folds);
    wip->wi_optset = true;
  }

  // insert the entry in front of the list
  wip->wi_next = buf->b_wininfo;
  buf->b_wininfo = wip;
  wip->wi_prev = NULL;
  if (wip->wi_next) {
    wip->wi_next->wi_prev = wip;
  }

  return;
}


/// Check that "wip" has 'diff' set and the diff is only for another tab page.
/// That's because a diff is local to a tab page.
static bool wininfo_other_tab_diff(wininfo_T *wip)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (wip->wi_opt.wo_diff) {
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      // return false when it's a window in the current tab page, thus
      // the buffer was in diff mode here
      if (wip->wi_win == wp) {
        return false;
      }
    }
    return true;
  }
  return false;
}

/*
 * Find info for the current window in buffer "buf".
 * If not found, return the info for the most recently used window.
 * When "skip_diff_buffer" is true avoid windows with 'diff' set that is in
 * another tab page.
 * Returns NULL when there isn't any info.
 */
static wininfo_T *find_wininfo(buf_T *buf, int skip_diff_buffer)
{
  wininfo_T   *wip;

  for (wip = buf->b_wininfo; wip != NULL; wip = wip->wi_next)
    if (wip->wi_win == curwin
        && (!skip_diff_buffer || !wininfo_other_tab_diff(wip))
        )
      break;

  /* If no wininfo for curwin, use the first in the list (that doesn't have
   * 'diff' set and is in another tab page). */
  if (wip == NULL) {
    if (skip_diff_buffer) {
      for (wip = buf->b_wininfo; wip != NULL; wip = wip->wi_next) {
        if (!wininfo_other_tab_diff(wip)) {
          break;
        }
      }
    } else {
      wip = buf->b_wininfo;
    }
  }
  return wip;
}

/*
 * Reset the local window options to the values last used in this window.
 * If the buffer wasn't used in this window before, use the values from
 * the most recently used window.  If the values were never set, use the
 * global values for the window.
 */
void get_winopts(buf_T *buf)
{
  wininfo_T   *wip;

  clear_winopt(&curwin->w_onebuf_opt);
  clearFolding(curwin);

  wip = find_wininfo(buf, true);
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
  } else
    copy_winopt(&curwin->w_allbuf_opt, &curwin->w_onebuf_opt);

  // Set 'foldlevel' to 'foldlevelstart' if it's not negative.
  if (p_fdls >= 0) {
    curwin->w_p_fdl = p_fdls;
  }
  didset_window_options(curwin);
}

/*
 * Find the position (lnum and col) for the buffer 'buf' for the current
 * window.
 * Returns a pointer to no_position if no position is found.
 */
pos_T *buflist_findfpos(buf_T *buf)
{
  static pos_T no_position = { 1, 0, 0 };

  wininfo_T *wip = find_wininfo(buf, false);
  return (wip == NULL) ? &no_position : &(wip->wi_fpos);
}

/*
 * Find the lnum for the buffer 'buf' for the current window.
 */
linenr_T buflist_findlnum(buf_T *buf)
{
  return buflist_findfpos(buf)->lnum;
}

// List all known file names (for :files and :buffers command).
void buflist_list(exarg_T *eap)
{
  buf_T       *buf;
  int len;
  int i;

  for (buf = firstbuf; buf != NULL && !got_int; buf = buf->b_next) {
    // skip unspecified buffers
    if ((!buf->b_p_bl && !eap->forceit && !strchr((char *)eap->arg, 'u'))
        || (strchr((char *)eap->arg, 'u') && buf->b_p_bl)
        || (strchr((char *)eap->arg, '+')
            && ((buf->b_flags & BF_READERR) || !bufIsChanged(buf)))
        || (strchr((char *)eap->arg, 'a')
            && (buf->b_ml.ml_mfp == NULL || buf->b_nwindows == 0))
        || (strchr((char *)eap->arg, 'h')
            && (buf->b_ml.ml_mfp == NULL || buf->b_nwindows != 0))
        || (strchr((char *)eap->arg, '-') && buf->b_p_ma)
        || (strchr((char *)eap->arg, '=') && !buf->b_p_ro)
        || (strchr((char *)eap->arg, 'x') && !(buf->b_flags & BF_READERR))
        || (strchr((char *)eap->arg, '%') && buf != curbuf)
        || (strchr((char *)eap->arg, '#')
            && (buf == curbuf || curwin->w_alt_fnum != buf->b_fnum))) {
      continue;
    }
    if (buf_spname(buf) != NULL) {
      STRLCPY(NameBuff, buf_spname(buf), MAXPATHL);
    } else {
      home_replace(buf, buf->b_fname, NameBuff, MAXPATHL, true);
    }

    if (message_filtered(NameBuff)) {
      continue;
    }

    msg_putchar('\n');
    len = vim_snprintf((char *)IObuff, IOSIZE - 20, "%3d%c%c%c%c%c \"%s\"",
        buf->b_fnum,
        buf->b_p_bl ? ' ' : 'u',
        buf == curbuf ? '%' : (curwin->w_alt_fnum == buf->b_fnum ? '#' : ' '),
        buf->b_ml.ml_mfp == NULL ? ' ' : (buf->b_nwindows == 0 ? 'h' : 'a'),
        !MODIFIABLE(buf) ? '-' : (buf->b_p_ro ? '=' : ' '),
        (buf->b_flags & BF_READERR) ? 'x' : (bufIsChanged(buf) ? '+' : ' '),
        NameBuff);

    if (len > IOSIZE - 20) {
        len = IOSIZE - 20;
    }

    // put "line 999" in column 40 or after the file name
    i = 40 - vim_strsize(IObuff);
    do {
      IObuff[len++] = ' ';
    } while (--i > 0 && len < IOSIZE - 18);
    vim_snprintf((char *)IObuff + len, (size_t)(IOSIZE - len),
        _("line %" PRId64),
        buf == curbuf ? (int64_t)curwin->w_cursor.lnum
                      : (int64_t)buflist_findlnum(buf));
    msg_outtrans(IObuff);
    ui_flush();            // output one line at a time
    os_breakcheck();
  }
}

/*
 * Get file name and line number for file 'fnum'.
 * Used by DoOneCmd() for translating '%' and '#'.
 * Used by insert_reg() and cmdline_paste() for '#' register.
 * Return FAIL if not found, OK for success.
 */
int buflist_name_nr(int fnum, char_u **fname, linenr_T *lnum)
{
  buf_T       *buf;

  buf = buflist_findnr(fnum);
  if (buf == NULL || buf->b_fname == NULL) {
    return FAIL;
  }

  *fname = buf->b_fname;
  *lnum = buflist_findlnum(buf);

  return OK;
}

/*
 * Set the file name for "buf"' to 'ffname', short file name to 'sfname'.
 * The file name with the full path is also remembered, for when :cd is used.
 * Returns FAIL for failure (file name already in use by other buffer)
 *	OK otherwise.
 */
int
setfname(
    buf_T *buf,
    char_u *ffname,
    char_u *sfname,
    int message                    // give message when buffer already exists
)
{
  buf_T       *obuf = NULL;
  FileID file_id;
  bool file_id_valid = false;

  if (ffname == NULL || *ffname == NUL) {
    // Removing the name.
    xfree(buf->b_ffname);
    xfree(buf->b_sfname);
    buf->b_ffname = NULL;
    buf->b_sfname = NULL;
  } else {
    fname_expand(buf, &ffname, &sfname);    // will allocate ffname
    if (ffname == NULL) {                   // out of memory
      return FAIL;
    }

    /*
     * if the file name is already used in another buffer:
     * - if the buffer is loaded, fail
     * - if the buffer is not loaded, delete it from the list
     */
    file_id_valid = os_fileid((char *)ffname, &file_id);
    if (!(buf->b_flags & BF_DUMMY)) {
      obuf = buflist_findname_file_id(ffname, &file_id, file_id_valid);
    }
    if (obuf != NULL && obuf != buf) {
      if (obuf->b_ml.ml_mfp != NULL) {          // it's loaded, fail
        if (message) {
          EMSG(_("E95: Buffer with this name already exists"));
        }
        xfree(ffname);
        return FAIL;
      }
      // delete from the list
      close_buffer(NULL, obuf, DOBUF_WIPE, false);
    }
    sfname = vim_strsave(sfname);
#ifdef USE_FNAME_CASE
    path_fix_case(sfname);            // set correct case for short file name
#endif
    xfree(buf->b_ffname);
    xfree(buf->b_sfname);
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

/*
 * Crude way of changing the name of a buffer.  Use with care!
 * The name should be relative to the current directory.
 */
void buf_set_name(int fnum, char_u *name)
{
  buf_T       *buf;

  buf = buflist_findnr(fnum);
  if (buf != NULL) {
    xfree(buf->b_sfname);
    xfree(buf->b_ffname);
    buf->b_ffname = vim_strsave(name);
    buf->b_sfname = NULL;
    /* Allocate ffname and expand into full path.  Also resolves .lnk
     * files on Win32. */
    fname_expand(buf, &buf->b_ffname, &buf->b_sfname);
    buf->b_fname = buf->b_sfname;
  }
}

/*
 * Take care of what needs to be done when the name of buffer "buf" has
 * changed.
 */
void buf_name_changed(buf_T *buf)
{
  /*
   * If the file name changed, also change the name of the swapfile
   */
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

/*
 * set alternate file name for current window
 *
 * Used by do_one_cmd(), do_write() and do_ecmd().
 * Return the buffer.
 */
buf_T *setaltfname(char_u *ffname, char_u *sfname, linenr_T lnum)
{
  buf_T       *buf;

  // Create a buffer.  'buflisted' is not set if it's a new buffer
  buf = buflist_new(ffname, sfname, lnum, 0);
  if (buf != NULL && !cmdmod.keepalt) {
    curwin->w_alt_fnum = buf->b_fnum;
  }
  return buf;
}

/*
 * Get alternate file name for current window.
 * Return NULL if there isn't any, and give error message if requested.
 */
char_u * getaltfname(
    bool errmsg                   // give error message
)
{
  char_u      *fname;
  linenr_T dummy;

  if (buflist_name_nr(0, &fname, &dummy) == FAIL) {
    if (errmsg) {
      EMSG(_(e_noalt));
    }
    return NULL;
  }
  return fname;
}

/*
 * Add a file name to the buflist and return its number.
 * Uses same flags as buflist_new(), except BLN_DUMMY.
 *
 * used by qf_init(), main() and doarglist()
 */
int buflist_add(char_u *fname, int flags)
{
  buf_T       *buf;

  buf = buflist_new(fname, NULL, (linenr_T)0, flags);
  if (buf != NULL) {
    return buf->b_fnum;
  }
  return 0;
}

#if defined(BACKSLASH_IN_FILENAME)
/*
 * Adjust slashes in file names.  Called after 'shellslash' was set.
 */
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

/*
 * Set alternate cursor position for the current buffer and window "win".
 * Also save the local window option values.
 */
void buflist_altfpos(win_T *win)
{
  buflist_setfpos(curbuf, win, win->w_cursor.lnum, win->w_cursor.col, true);
}

/// Check that "ffname" is not the same file as current file.
/// Fname must have a full path (expanded by path_to_absolute()).
///
/// @param  ffname  full path name to check
bool otherfile(char_u *ffname)
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
static bool otherfile_buf(buf_T *buf, char_u *ffname, FileID *file_id_p,
                          bool file_id_valid)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  // no name is different
  if (ffname == NULL || *ffname == NUL || buf->b_ffname == NULL) {
    return true;
  }
  if (fnamecmp(ffname, buf->b_ffname) == 0) {
    return false;
  }
  {
    FileID file_id;
    // If no struct stat given, get it now
    if (file_id_p == NULL) {
      file_id_p = &file_id;
      file_id_valid = os_fileid((char *)ffname, file_id_p);
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

// Set file_id for a buffer.
// Must always be called when b_fname is changed!
void buf_set_file_id(buf_T *buf)
{
  FileID file_id;
  if (buf->b_fname != NULL
      && os_fileid((char *)buf->b_fname, &file_id)) {
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

/*
 * Print info about the current buffer.
 */
void
fileinfo(
    int fullname,               // when non-zero print full path
    int shorthelp,
    int dont_truncate
)
{
  char_u      *name;
  int n;
  char_u      *p;
  char_u      *buffer;
  size_t len;

  buffer = xmalloc(IOSIZE);

  if (fullname > 1) {       // 2 CTRL-G: include buffer number
    vim_snprintf((char *)buffer, IOSIZE, "buf %d: ", curbuf->b_fnum);
    p = buffer + STRLEN(buffer);
  } else
    p = buffer;

  *p++ = '"';
  if (buf_spname(curbuf) != NULL) {
    STRLCPY(p, buf_spname(curbuf), IOSIZE - (p - buffer));
  } else {
    if (!fullname && curbuf->b_fname != NULL) {
      name = curbuf->b_fname;
    } else {
      name = curbuf->b_ffname;
    }
    home_replace(shorthelp ? curbuf : NULL, name, p,
                 (size_t)(IOSIZE - (p - buffer)), true);
  }

  vim_snprintf_add((char *)buffer, IOSIZE, "\"%s%s%s%s%s%s",
      curbufIsChanged() ? (shortmess(SHM_MOD)
                           ?  " [+]" : _(" [Modified]")) : " ",
      (curbuf->b_flags & BF_NOTEDITED)
      && !bt_dontwrite(curbuf)
      ? _("[Not edited]") : "",
      (curbuf->b_flags & BF_NEW)
      && !bt_dontwrite(curbuf)
      ? _("[New file]") : "",
      (curbuf->b_flags & BF_READERR) ? _("[Read errors]") : "",
      curbuf->b_p_ro ? (shortmess(SHM_RO) ? _("[RO]")
                        : _("[readonly]")) : "",
      (curbufIsChanged() || (curbuf->b_flags & BF_WRITE_MASK)
       || curbuf->b_p_ro) ?
      " " : "");
  /* With 32 bit longs and more than 21,474,836 lines multiplying by 100
   * causes an overflow, thus for large numbers divide instead. */
  if (curwin->w_cursor.lnum > 1000000L)
    n = (int)(((long)curwin->w_cursor.lnum) /
              ((long)curbuf->b_ml.ml_line_count / 100L));
  else
    n = (int)(((long)curwin->w_cursor.lnum * 100L) /
              (long)curbuf->b_ml.ml_line_count);
  if (curbuf->b_ml.ml_flags & ML_EMPTY) {
    vim_snprintf_add((char *)buffer, IOSIZE, "%s", _(no_lines_msg));
  } else if (p_ru) {
    // Current line and column are already on the screen -- webb
    if (curbuf->b_ml.ml_line_count == 1) {
      vim_snprintf_add((char *)buffer, IOSIZE, _("1 line --%d%%--"), n);
    } else {
      vim_snprintf_add((char *)buffer, IOSIZE, _("%" PRId64 " lines --%d%%--"),
                       (int64_t)curbuf->b_ml.ml_line_count, n);
    }
  } else {
    vim_snprintf_add((char *)buffer, IOSIZE,
        _("line %" PRId64 " of %" PRId64 " --%d%%-- col "),
        (int64_t)curwin->w_cursor.lnum,
        (int64_t)curbuf->b_ml.ml_line_count,
        n);
    validate_virtcol();
    len = STRLEN(buffer);
    col_print(buffer + len, IOSIZE - len,
        (int)curwin->w_cursor.col + 1, (int)curwin->w_virtcol + 1);
  }

  (void)append_arg_number(curwin, buffer, IOSIZE, !shortmess(SHM_FILE));

  if (dont_truncate) {
    /* Temporarily set msg_scroll to avoid the message being truncated.
     * First call msg_start() to get the message in the right place. */
    msg_start();
    n = msg_scroll;
    msg_scroll = true;
    msg(buffer);
    msg_scroll = n;
  } else {
    p = msg_trunc_attr(buffer, false, 0);
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

void col_print(char_u *buf, size_t buflen, int col, int vcol)
{
  if (col == vcol) {
    vim_snprintf((char *)buf, buflen, "%d", col);
  } else {
    vim_snprintf((char *)buf, buflen, "%d-%d", col, vcol);
  }
}

/*
 * put file name in title bar of window and in icon title
 */

static char_u *lasttitle = NULL;
static char_u *lasticon = NULL;

void maketitle(void)
{
  char_u      *t_str = NULL;
  char_u      *i_name;
  char_u      *i_str = NULL;
  int maxlen = 0;
  int len;
  int mustset;
  char buf[IOSIZE];

  if (!redrawing()) {
    // Postpone updating the title when 'lazyredraw' is set.
    need_maketitle = true;
    return;
  }

  need_maketitle = false;
  if (!p_title && !p_icon && lasttitle == NULL && lasticon == NULL) {
    return;
  }

  if (p_title) {
    if (p_titlelen > 0) {
      maxlen = (int)(p_titlelen * Columns / 100);
      if (maxlen < 10) {
        maxlen = 10;
      }
    }

    if (*p_titlestring != NUL) {
      if (stl_syntax & STL_IN_TITLE) {
        int use_sandbox = false;
        int save_called_emsg = called_emsg;

        use_sandbox = was_set_insecurely((char_u *)"titlestring", 0);
        called_emsg = false;
        build_stl_str_hl(curwin, (char_u *)buf, sizeof(buf),
                         p_titlestring, use_sandbox,
                         0, maxlen, NULL, NULL);
        t_str = (char_u *)buf;
        if (called_emsg) {
          set_string_option_direct((char_u *)"titlestring", -1, (char_u *)"",
                                   OPT_FREE, SID_ERROR);
        }
        called_emsg |= save_called_emsg;
      } else {
        t_str = p_titlestring;
      }
    } else {
      // Format: "fname + (path) (1 of 2) - VIM".

#define SPACE_FOR_FNAME (sizeof(buf) - 100)
#define SPACE_FOR_DIR   (sizeof(buf) - 20)
#define SPACE_FOR_ARGNR (sizeof(buf) - 10)  // At least room for " - NVIM".
      char *buf_p = buf;
      if (curbuf->b_fname == NULL) {
        const size_t size = xstrlcpy(buf_p, _("[No Name]"),
                                     SPACE_FOR_FNAME + 1);
        buf_p += MIN(size, SPACE_FOR_FNAME);
      } else {
        buf_p += transstr_buf((const char *)path_tail(curbuf->b_fname),
                              buf_p, SPACE_FOR_FNAME + 1);
      }

      switch (bufIsChanged(curbuf)
              | (curbuf->b_p_ro << 1)
              | (!MODIFIABLE(curbuf) << 2)) {
        case 0: break;
        case 1: buf_p = strappend(buf_p, " +"); break;
        case 2: buf_p = strappend(buf_p, " ="); break;
        case 3: buf_p = strappend(buf_p, " =+"); break;
        case 4:
        case 6: buf_p = strappend(buf_p, " -"); break;
        case 5:
        case 7: buf_p = strappend(buf_p, " -+"); break;
        default: assert(false);
      }

      if (curbuf->b_fname != NULL) {
        // Get path of file, replace home dir with ~.
        *buf_p++ = ' ';
        *buf_p++ = '(';
        home_replace(curbuf, curbuf->b_ffname, (char_u *)buf_p,
                     (SPACE_FOR_DIR - (size_t)(buf_p - buf)), true);
#ifdef BACKSLASH_IN_FILENAME
        // Avoid "c:/name" to be reduced to "c".
        if (isalpha((uint8_t)buf_p) && *(buf_p + 1) == ':') {
          buf_p += 2;
        }
#endif
        // Remove the file name.
        char *p = (char *)path_tail_with_sep((char_u *)buf_p);
        if (p == buf_p) {
          // Must be a help buffer.
          xstrlcpy(buf_p, _("help"), SPACE_FOR_DIR - (size_t)(buf_p - buf));
        } else {
          *p = NUL;
        }

        // Translate unprintable chars and concatenate.  Keep some
        // room for the server name.  When there is no room (very long
        // file name) use (...).
        if ((size_t)(buf_p - buf) < SPACE_FOR_DIR) {
          char *const tbuf = transstr(buf_p);
          const size_t free_space = SPACE_FOR_DIR - (size_t)(buf_p - buf) + 1;
          const size_t dir_len = xstrlcpy(buf_p, tbuf, free_space);
          buf_p += MIN(dir_len, free_space - 1);
          xfree(tbuf);
        } else {
          const size_t free_space = SPACE_FOR_ARGNR - (size_t)(buf_p - buf) + 1;
          const size_t dots_len = xstrlcpy(buf_p, "...", free_space);
          buf_p += MIN(dots_len, free_space - 1);
        }
        *buf_p++ = ')';
        *buf_p = NUL;
      } else {
        *buf_p = NUL;
      }

      append_arg_number(curwin, (char_u *)buf_p,
                        (int)(SPACE_FOR_ARGNR - (size_t)(buf_p - buf)), false);

      xstrlcat(buf_p, " - NVIM", (sizeof(buf) - (size_t)(buf_p - buf)));

      if (maxlen > 0) {
        // Make it shorter by removing a bit in the middle.
        if (vim_strsize((char_u *)buf) > maxlen) {
          trunc_string((char_u *)buf, (char_u *)buf, maxlen, sizeof(buf));
        }
      }
      t_str = (char_u *)buf;
#undef SPACE_FOR_FNAME
#undef SPACE_FOR_DIR
#undef SPACE_FOR_ARGNR
    }
  }
  mustset = ti_change(t_str, &lasttitle);

  if (p_icon) {
    i_str = (char_u *)buf;
    if (*p_iconstring != NUL) {
      if (stl_syntax & STL_IN_ICON) {
        int use_sandbox = false;
        int save_called_emsg = called_emsg;

        use_sandbox = was_set_insecurely((char_u *)"iconstring", 0);
        called_emsg = false;
        build_stl_str_hl(curwin, i_str, sizeof(buf),
            p_iconstring, use_sandbox,
            0, 0, NULL, NULL);
        if (called_emsg)
          set_string_option_direct((char_u *)"iconstring", -1,
              (char_u *)"", OPT_FREE, SID_ERROR);
        called_emsg |= save_called_emsg;
      } else
        i_str = p_iconstring;
    } else {
      if (buf_spname(curbuf) != NULL) {
        i_name = buf_spname(curbuf);
      } else {                        // use file name only in icon
        i_name = path_tail(curbuf->b_ffname);
      }
      *i_str = NUL;
      // Truncate name at 100 bytes.
      len = (int)STRLEN(i_name);
      if (len > 100) {
        len -= 100;
        if (has_mbyte) {
          len += (*mb_tail_off)(i_name, i_name + len) + 1;
        }
        i_name += len;
      }
      STRCPY(i_str, i_name);
      trans_characters(i_str, IOSIZE);
    }
  }

  mustset |= ti_change(i_str, &lasticon);

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
//
/// @return true when "*last" changed.
static bool ti_change(char_u *str, char_u **last)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if ((str == NULL) != (*last == NULL)
      || (str != NULL && *last != NULL && STRCMP(str, *last) != 0)) {
    xfree(*last);
    if (str == NULL) {
      *last = NULL;
    } else {
      *last = vim_strsave(str);
    }
    return true;
  }
  return false;
}


/// Set current window title
void resettitle(void)
{
  ui_call_set_icon(cstr_as_string((char *)lasticon));
  ui_call_set_title(cstr_as_string((char *)lasttitle));
  ui_flush();
}

# if defined(EXITFREE)
void free_titles(void)
{
  xfree(lasttitle);
  xfree(lasticon);
}

# endif

/// Enumeration specifying the valid numeric bases that can
/// be used when printing numbers in the status line.
typedef enum {
  kNumBaseDecimal = 10,
  kNumBaseHexadecimal = 16
} NumberBase;


/// Build a string from the status line items in "fmt".
/// Return length of string in screen cells.
///
/// Normally works for window "wp", except when working for 'tabline' then it
/// is "curwin".
///
/// Items are drawn interspersed with the text that surrounds it
/// Specials: %-<wid>(xxx%) => group, %= => separation marker, %< => truncation
/// Item: %-<minwid>.<maxwid><itemch> All but <itemch> are optional
///
/// If maxwidth is not zero, the string will be filled at any middle marker
/// or truncated if too long, fillchar is used for all whitespace.
///
/// @param wp The window to build a statusline for
/// @param out The output buffer to write the statusline to
///            Note: This should not be NameBuff
/// @param outlen The length of the output buffer
/// @param fmt The statusline format string
/// @param use_sandbox Use a sandboxed environment when evaluating fmt
/// @param fillchar Character to use when filling empty space in the statusline
/// @param maxwidth The maximum width to make the statusline
/// @param hltab HL attributes (can be NULL)
/// @param tabtab Tab clicks definition (can be NULL).
///
/// @return The final width of the statusline
int build_stl_str_hl(
    win_T *wp,
    char_u *out,
    size_t outlen,
    char_u *fmt,
    int use_sandbox,
    char_u fillchar,
    int maxwidth,
    struct stl_hlrec *hltab,
    StlClickRecord *tabtab
)
{
  int groupitems[STL_MAX_ITEM];
  struct stl_item {
    // Where the item starts in the status line output buffer
    char_u *start;
    // Function to run for ClickFunc items.
    char *cmd;
    // The minimum width of the item
    int minwid;
    // The maximum width of the item
    int maxwid;
    enum {
      Normal,
      Empty,
      Group,
      Separate,
      Highlight,
      TabPage,
      ClickFunc,
      Trunc
    } type;
  } items[STL_MAX_ITEM];
#define TMPLEN 70
  char_u tmp[TMPLEN];
  char_u      *usefmt = fmt;
  const int save_must_redraw = must_redraw;
  const int save_redr_type = curwin->w_redr_type;
  const int save_highlight_shcnaged = need_highlight_changed;

  // When the format starts with "%!" then evaluate it as an expression and
  // use the result as the actual format string.
  if (fmt[0] == '%' && fmt[1] == '!') {
    usefmt = eval_to_string_safe(fmt + 2, NULL, use_sandbox);
    if (usefmt == NULL) {
      usefmt = fmt;
    }
  }

  if (fillchar == 0) {
    fillchar = ' ';
  } else if (mb_char2len(fillchar) > 1) {
    // Can't handle a multi-byte fill character yet.
    fillchar = '-';
  }

  // Get line & check if empty (cursorpos will show "0-1").
  char_u *line_ptr = ml_get_buf(wp->w_buffer, wp->w_cursor.lnum, false);
  bool empty_line = (*line_ptr == NUL);

  // Get the byte value now, in case we need it below. This is more
  // efficient than making a copy of the line.
  int byteval;
  if (wp->w_cursor.col > (colnr_T)STRLEN(line_ptr)) {
    byteval = 0;
  } else {
    byteval = utf_ptr2char(line_ptr + wp->w_cursor.col);
  }

  int groupdepth = 0;

  int curitem = 0;
  bool prevchar_isflag = true;
  bool prevchar_isitem = false;

  // out_p is the current position in the output buffer
  char_u *out_p = out;

  // out_end_p is the last valid character in the output buffer
  // Note: The null termination character must occur here or earlier,
  //       so any user-visible characters must occur before here.
  char_u *out_end_p = (out + outlen) - 1;


  // Proceed character by character through the statusline format string
  // fmt_p is the current positon in the input buffer
  for (char_u *fmt_p = usefmt; *fmt_p; ) {
    if (curitem == STL_MAX_ITEM) {
      // There are too many items.  Add the error code to the statusline
      // to give the user a hint about what went wrong.
      if (out_p + 5 < out_end_p) {
        memmove(out_p, " E541", (size_t)5);
        out_p += 5;
      }
      break;
    }

    if (*fmt_p != NUL && *fmt_p != '%') {
      prevchar_isflag = prevchar_isitem = false;
    }

    // Copy the formatting verbatim until we reach the end of the string
    // or find a formatting item (denoted by `%`)
    // or run out of room in our output buffer.
    while (*fmt_p != NUL && *fmt_p != '%' && out_p < out_end_p)
      *out_p++ = *fmt_p++;

    // If we have processed the entire format string or run out of
    // room in our output buffer, exit the loop.
    if (*fmt_p == NUL || out_p >= out_end_p) {
      break;
    }

    // The rest of this loop will handle a single `%` item.
    // Note: We increment here to skip over the `%` character we are currently
    //       on so we can process the item's contents.
    fmt_p++;

    // Ignore `%` at the end of the format string
    if (*fmt_p == NUL) {
      break;
    }

    // Two `%` in a row is the escape sequence to print a
    // single `%` in the output buffer.
    if (*fmt_p == '%') {
      *out_p++ = *fmt_p++;
      prevchar_isflag = prevchar_isitem = false;
      continue;
    }

    // STL_SEPARATE: Separation place between left and right aligned items.
    if (*fmt_p == STL_SEPARATE) {
      fmt_p++;
      // Ignored when we are inside of a grouping
      if (groupdepth > 0) {
        continue;
      }
      items[curitem].type = Separate;
      items[curitem++].start = out_p;
      continue;
    }

    // STL_TRUNCMARK: Where to begin truncating if the statusline is too long.
    if (*fmt_p == STL_TRUNCMARK) {
      fmt_p++;
      items[curitem].type = Trunc;
      items[curitem++].start = out_p;
      continue;
    }

    // The end of a grouping
    if (*fmt_p == ')') {
      fmt_p++;
      // Ignore if we are not actually inside a group currently
      if (groupdepth < 1) {
        continue;
      }
      groupdepth--;

      // Determine how long the group is.
      // Note: We set the current output position to null
      //       so `vim_strsize` will work.
      char_u *t = items[groupitems[groupdepth]].start;
      *out_p = NUL;
      long group_len = vim_strsize(t);

      // If the group contained internal items
      // and the group did not have a minimum width,
      // and if there were no normal items in the group,
      // move the output pointer back to where the group started.
      // Note: This erases any non-item characters that were in the group.
      //       Otherwise there would be no reason to do this step.
      if (curitem > groupitems[groupdepth] + 1
          && items[groupitems[groupdepth]].minwid == 0) {
        bool has_normal_items = false;
        for (long n = groupitems[groupdepth] + 1; n < curitem; n++) {
          if (items[n].type == Normal || items[n].type == Highlight) {
            has_normal_items = true;
            break;
          }
        }

        if (!has_normal_items) {
          out_p = t;
          group_len = 0;
        }
      }

      // If the group is longer than it is allowed to be
      // truncate by removing bytes from the start of the group text.
      if (group_len > items[groupitems[groupdepth]].maxwid) {
        // { Determine the number of bytes to remove
        long n;
        if (has_mbyte) {
          // Find the first character that should be included.
          n = 0;
          while (group_len >= items[groupitems[groupdepth]].maxwid) {
            group_len -= ptr2cells(t + n);
            n += (*mb_ptr2len)(t + n);
          }
        } else {
          n = (long)(out_p - t) - items[groupitems[groupdepth]].maxwid + 1;
        }
        // }

        // Prepend the `<` to indicate that the output was truncated.
        *t = '<';

        // { Move the truncated output
        memmove(t + 1, t + n, (size_t)(out_p - (t + n)));
        out_p = out_p - n + 1;
        // Fill up space left over by half a double-wide char.
        while (++group_len < items[groupitems[groupdepth]].minwid) {
          *out_p++ = fillchar;
        }
        // }

        // correct the start of the items for the truncation
        for (int idx = groupitems[groupdepth] + 1; idx < curitem; idx++) {
          // Shift everything back by the number of removed bytes
          items[idx].start -= n;

          // If the item was partially or completely truncated, set its
          // start to the start of the group
          if (items[idx].start < t) {
            items[idx].start = t;
          }
        }
      // If the group is shorter than the minimum width, add padding characters.
      } else if (abs(items[groupitems[groupdepth]].minwid) > group_len) {
        long min_group_width = items[groupitems[groupdepth]].minwid;
        // If the group is left-aligned, add characters to the right.
        if (min_group_width < 0) {
          min_group_width = 0 - min_group_width;
          while (group_len++ < min_group_width && out_p < out_end_p)
            *out_p++ = fillchar;
        // If the group is right-aligned, shift everything to the right and
        // prepend with filler characters.
        } else {
          // { Move the group to the right
          memmove(t + min_group_width - group_len, t, (size_t)(out_p - t));
          group_len = min_group_width - group_len;
          if (out_p + group_len >= (out_end_p + 1)) {
            group_len = (long)(out_end_p - out_p);
          }
          out_p += group_len;
          // }

          // Adjust item start positions
          for (int n = groupitems[groupdepth] + 1; n < curitem; n++) {
            items[n].start += group_len;
          }

          // Prepend the fill characters
          for (; group_len > 0; group_len--) {
            *t++ = fillchar;
          }
        }
      }
      continue;
    }
    int minwid = 0;
    int maxwid = 9999;
    bool left_align = false;

    // Denotes that numbers should be left-padded with zeros
    bool zeropad = (*fmt_p == '0');
    if (zeropad) {
      fmt_p++;
    }

    // Denotes that the item should be left-aligned.
    // This is tracked by using a negative length.
    if (*fmt_p == '-') {
      fmt_p++;
      left_align = true;
    }

    // The first digit group is the item's min width
    if (ascii_isdigit(*fmt_p)) {
      minwid = getdigits_int(&fmt_p);
      if (minwid < 0) {         // overflow
        minwid = 0;
      }
    }

    // User highlight groups override the min width field
    // to denote the styling to use.
    if (*fmt_p == STL_USER_HL) {
      items[curitem].type = Highlight;
      items[curitem].start = out_p;
      items[curitem].minwid = minwid > 9 ? 1 : minwid;
      fmt_p++;
      curitem++;
      continue;
    }

    // TABPAGE pairs are used to denote a region that when clicked will
    // either switch to or close a tab.
    //
    // Ex: tabline=%0Ttab\ zero%X
    //   This tabline has a TABPAGENR item with minwid `0`,
    //   which is then closed with a TABCLOSENR item.
    //   Clicking on this region with mouse enabled will switch to tab 0.
    //   Setting the minwid to a different value will switch
    //   to that tab, if it exists
    //
    // Ex: tabline=%1Xtab\ one%X
    //   This tabline has a TABCLOSENR item with minwid `1`,
    //   which is then closed with a TABCLOSENR item.
    //   Clicking on this region with mouse enabled will close tab 0.
    //   This is determined by the following formula:
    //      tab to close = (1 - minwid)
    //   This is because for TABPAGENR we use `minwid` = `tab number`.
    //   For TABCLOSENR we store the tab number as a negative value.
    //   Because 0 is a valid TABPAGENR value, we have to
    //   start our numbering at `-1`.
    //   So, `-1` corresponds to us wanting to close tab `0`
    //
    // Note: These options are only valid when creating a tabline.
    if (*fmt_p == STL_TABPAGENR || *fmt_p == STL_TABCLOSENR) {
      if (*fmt_p == STL_TABCLOSENR) {
        if (minwid == 0) {
          // %X ends the close label, go back to the previous tab label nr.
          for (long n = curitem - 1; n >= 0; n--) {
            if (items[n].type == TabPage && items[n].minwid >= 0) {
              minwid = items[n].minwid;
              break;
            }
          }
        } else {
          // close nrs are stored as negative values
          minwid = -minwid;
        }
      }
      items[curitem].type = TabPage;
      items[curitem].start = out_p;
      items[curitem].minwid = minwid;
      fmt_p++;
      curitem++;
      continue;
    }

    if (*fmt_p == STL_CLICK_FUNC) {
      fmt_p++;
      char *t = (char *) fmt_p;
      while (*fmt_p != STL_CLICK_FUNC && *fmt_p) {
        fmt_p++;
      }
      if (*fmt_p != STL_CLICK_FUNC) {
        break;
      }
      items[curitem].type = ClickFunc;
      items[curitem].start = out_p;
      items[curitem].cmd = xmemdupz(t, (size_t)(((char *)fmt_p - t)));
      items[curitem].minwid = minwid;
      fmt_p++;
      curitem++;
      continue;
    }

    // Denotes the end of the minwid
    // the maxwid may follow immediately after
    if (*fmt_p == '.') {
      fmt_p++;
      if (ascii_isdigit(*fmt_p)) {
        maxwid = getdigits_int(&fmt_p);
        if (maxwid <= 0) {              // overflow
          maxwid = 50;
        }
      }
    }

    // Bound the minimum width at 50.
    // Make the number negative to denote left alignment of the item
    minwid = (minwid > 50 ? 50 : minwid) * (left_align ? -1 : 1);

    // Denotes the start of a new group
    if (*fmt_p == '(') {
      groupitems[groupdepth++] = curitem;
      items[curitem].type = Group;
      items[curitem].start = out_p;
      items[curitem].minwid = minwid;
      items[curitem].maxwid = maxwid;
      fmt_p++;
      curitem++;
      continue;
    }

    // An invalid item was specified.
    // Continue processing on the next character of the format string.
    if (vim_strchr(STL_ALL, *fmt_p) == NULL) {
      fmt_p++;
      continue;
    }

    // The status line item type
    char_u opt = *fmt_p++;

    // OK - now for the real work
    NumberBase base = kNumBaseDecimal;
    bool itemisflag = false;
    bool fillable = true;
    long num = -1;
    char_u *str = NULL;
    switch (opt) {
    case STL_FILEPATH:
    case STL_FULLPATH:
    case STL_FILENAME:
    {
      // Set fillable to false so that ' ' in the filename will not
      // get replaced with the fillchar
      fillable = false;
      if (buf_spname(wp->w_buffer) != NULL) {
        STRLCPY(NameBuff, buf_spname(wp->w_buffer), MAXPATHL);
      } else {
        char_u *t = (opt == STL_FULLPATH) ? wp->w_buffer->b_ffname
                     : wp->w_buffer->b_fname;
        home_replace(wp->w_buffer, t, NameBuff, MAXPATHL, true);
      }
      trans_characters(NameBuff, MAXPATHL);
      if (opt != STL_FILENAME) {
        str = NameBuff;
      } else {
        str = path_tail(NameBuff);
      }
      break;
    }
    case STL_VIM_EXPR:     // '{'
    {
      itemisflag = true;

      // Attempt to copy the expression to evaluate into
      // the output buffer as a null-terminated string.
      char_u *t = out_p;
      while (*fmt_p != '}' && *fmt_p != NUL && out_p < out_end_p)
        *out_p++ = *fmt_p++;
      if (*fmt_p != '}') {          // missing '}' or out of space
        break;
      }
      fmt_p++;
      *out_p = 0;

      // Move our position in the output buffer
      // to the beginning of the expression
      out_p = t;

      // { Evaluate the expression

      // Store the current buffer number as a string variable
      vim_snprintf((char *)tmp, sizeof(tmp), "%d", curbuf->b_fnum);
      set_internal_string_var((char_u *)"g:actual_curbuf", tmp);

      buf_T *const save_curbuf = curbuf;
      win_T *const save_curwin = curwin;
      curwin = wp;
      curbuf = wp->w_buffer;

      // Note: The result stored in `t` is unused.
      str = eval_to_string_safe(out_p, &t, use_sandbox);

      curwin = save_curwin;
      curbuf = save_curbuf;

      // Remove the variable we just stored
      do_unlet(S_LEN("g:actual_curbuf"), true);

      // }

      // Check if the evaluated result is a number.
      // If so, convert the number to an int and free the string.
      if (str != NULL && *str != 0) {
        if (*skipdigits(str) == NUL) {
          num = atoi((char *)str);
          xfree(str);
          str = NULL;
          itemisflag = false;
        }
      }
      break;
    }

    case STL_LINE:
      num = (wp->w_buffer->b_ml.ml_flags & ML_EMPTY)
            ? 0L : (long)(wp->w_cursor.lnum);
      break;

    case STL_NUMLINES:
      num = wp->w_buffer->b_ml.ml_line_count;
      break;

    case STL_COLUMN:
      num = !(State & INSERT) && empty_line
            ? 0 : (int)wp->w_cursor.col + 1;
      break;

    case STL_VIRTCOL:
    case STL_VIRTCOL_ALT:
    {
      // In list mode virtcol needs to be recomputed
      colnr_T virtcol = wp->w_virtcol;
      if (wp->w_p_list && wp->w_p_lcs_chars.tab1 == NUL) {
        wp->w_p_list = false;
        getvcol(wp, &wp->w_cursor, NULL, &virtcol, NULL);
        wp->w_p_list = true;
      }
      virtcol++;
      // Don't display %V if it's the same as %c.
      if (opt == STL_VIRTCOL_ALT
          && (virtcol == (colnr_T)(!(State & INSERT) && empty_line
                                   ? 0 : (int)wp->w_cursor.col + 1)))
        break;
      num = (long)virtcol;
      break;
    }

    case STL_PERCENTAGE:
      num = (int)(((long)wp->w_cursor.lnum * 100L) /
                  (long)wp->w_buffer->b_ml.ml_line_count);
      break;

    case STL_ALTPERCENT:
      // Store the position percentage in our temporary buffer.
      // Note: We cannot store the value in `num` because
      //       `get_rel_pos` can return a named position. Ex: "Top"
      get_rel_pos(wp, tmp, TMPLEN);
      str = tmp;
      break;

    case STL_ARGLISTSTAT:
      fillable = false;

      // Note: This is important because `append_arg_number` starts appending
      //       at the end of the null-terminated string.
      //       Setting the first byte to null means it will place the argument
      //       number string at the beginning of the buffer.
      tmp[0] = 0;

      // Note: The call will only return true if it actually
      //       appended data to the `tmp` buffer.
      if (append_arg_number(wp, tmp, (int)sizeof(tmp), false)) {
        str = tmp;
      }
      break;

    case STL_KEYMAP:
      fillable = false;
      if (get_keymap_str(wp, (char_u *)"<%s>", tmp, TMPLEN)) {
        str = tmp;
      }
      break;
    case STL_PAGENUM:
      num = printer_page_num;
      break;

    case STL_BUFNO:
      num = wp->w_buffer->b_fnum;
      break;

    case STL_OFFSET_X:
      base = kNumBaseHexadecimal;
      FALLTHROUGH;
    case STL_OFFSET:
    {
      long l = ml_find_line_or_offset(wp->w_buffer, wp->w_cursor.lnum, NULL,
                                      false);
      num = (wp->w_buffer->b_ml.ml_flags & ML_EMPTY) || l < 0 ?
            0L : l + 1 + (!(State & INSERT) && empty_line ?
                          0 : (int)wp->w_cursor.col);
      break;
    }
    case STL_BYTEVAL_X:
      base = kNumBaseHexadecimal;
      FALLTHROUGH;
    case STL_BYTEVAL:
      num = byteval;
      if (num == NL) {
        num = 0;
      } else if (num == CAR && get_fileformat(wp->w_buffer) == EOL_MAC) {
        num = NL;
      }
      break;

    case STL_ROFLAG:
    case STL_ROFLAG_ALT:
      itemisflag = true;
      if (wp->w_buffer->b_p_ro) {
        str = (char_u *)((opt == STL_ROFLAG_ALT) ? ",RO" : _("[RO]"));
      }
      break;

    case STL_HELPFLAG:
    case STL_HELPFLAG_ALT:
      itemisflag = true;
      if (wp->w_buffer->b_help)
        str = (char_u *)((opt == STL_HELPFLAG_ALT) ? ",HLP"
                         : _("[Help]"));
      break;

    case STL_FILETYPE:
      // Copy the filetype if it is not null and the formatted string will fit
      // in the temporary buffer
      // (including the brackets and null terminating character)
      if (*wp->w_buffer->b_p_ft != NUL
          && STRLEN(wp->w_buffer->b_p_ft) < TMPLEN - 3) {
        vim_snprintf((char *)tmp, sizeof(tmp), "[%s]",
            wp->w_buffer->b_p_ft);
        str = tmp;
      }
      break;

    case STL_FILETYPE_ALT:
    {
      itemisflag = true;
      // Copy the filetype if it is not null and the formatted string will fit
      // in the temporary buffer
      // (including the comma and null terminating character)
      if (*wp->w_buffer->b_p_ft != NUL
          && STRLEN(wp->w_buffer->b_p_ft) < TMPLEN - 2) {
        vim_snprintf((char *)tmp, sizeof(tmp), ",%s",
            wp->w_buffer->b_p_ft);
        // Uppercase the file extension
        for (char_u *t = tmp; *t != 0; t++) {
          *t = (char_u)TOUPPER_LOC(*t);
        }
        str = tmp;
      }
      break;
    }
    case STL_PREVIEWFLAG:
    case STL_PREVIEWFLAG_ALT:
      itemisflag = true;
      if (wp->w_p_pvw)
        str = (char_u *)((opt == STL_PREVIEWFLAG_ALT) ? ",PRV"
                         : _("[Preview]"));
      break;

    case STL_QUICKFIX:
      if (bt_quickfix(wp->w_buffer))
        str = (char_u *)(wp->w_llist_ref
                         ? _(msg_loclist)
                         : _(msg_qflist));
      break;

    case STL_MODIFIED:
    case STL_MODIFIED_ALT:
      itemisflag = true;
      switch ((opt == STL_MODIFIED_ALT)
              + bufIsChanged(wp->w_buffer) * 2
              + (!MODIFIABLE(wp->w_buffer)) * 4) {
      case 2: str = (char_u *)"[+]"; break;
      case 3: str = (char_u *)",+"; break;
      case 4: str = (char_u *)"[-]"; break;
      case 5: str = (char_u *)",-"; break;
      case 6: str = (char_u *)"[+-]"; break;
      case 7: str = (char_u *)",+-"; break;
      }
      break;

    case STL_HIGHLIGHT:
    {
      // { The name of the highlight is surrounded by `#`
      char_u *t = fmt_p;
      while (*fmt_p != '#' && *fmt_p != NUL) {
        fmt_p++;
      }
      // }

      // Create a highlight item based on the name
      if (*fmt_p == '#') {
        items[curitem].type = Highlight;
        items[curitem].start = out_p;
        items[curitem].minwid = -syn_namen2id(t, (int)(fmt_p - t));
        curitem++;
        fmt_p++;
      }
      continue;
    }
    }

    // If we made it this far, the item is normal and starts at
    // our current position in the output buffer.
    // Non-normal items would have `continued`.
    items[curitem].start = out_p;
    items[curitem].type = Normal;

    // Copy the item string into the output buffer
    if (str != NULL && *str) {
      // { Skip the leading `,` or ` ` if the item is a flag
      //  and the proper conditions are met
      char_u *t = str;
      if (itemisflag) {
        if ((t[0] && t[1])
            && ((!prevchar_isitem && *t == ',')
                || (prevchar_isflag && *t == ' ')))
          t++;
        prevchar_isflag = true;
      }
      // }

      long l = vim_strsize(t);

      // If this item is non-empty, record that the last thing
      // we put in the output buffer was an item
      if (l > 0) {
        prevchar_isitem = true;
      }

      // If the item is too wide, truncate it from the beginning
      if (l > maxwid) {
        while (l >= maxwid)
          if (has_mbyte) {
            l -= ptr2cells(t);
            t += (*mb_ptr2len)(t);
          } else {
            l -= byte2cells(*t++);
          }

        // Early out if there isn't enough room for the truncation marker
        if (out_p >= out_end_p) {
          break;
        }

        // Add the truncation marker
        *out_p++ = '<';
      }

      // If the item is right aligned and not wide enough,
      // pad with fill characters.
      if (minwid > 0) {
        for (; l < minwid && out_p < out_end_p; l++) {
          // Don't put a "-" in front of a digit.
          if (l + 1 == minwid && fillchar == '-' && ascii_isdigit(*t)) {
            *out_p++ = ' ';
          } else {
            *out_p++ = fillchar;
          }
        }
        minwid = 0;
      } else {
        // Note: The negative value denotes a left aligned item.
        //       Here we switch the minimum width back to a positive value.
        minwid *= -1;
      }

      // { Copy the string text into the output buffer
      while (*t && out_p < out_end_p) {
        *out_p++ = *t++;
        // Change a space by fillchar, unless fillchar is '-' and a
        // digit follows.
        if (fillable && out_p[-1] == ' '
            && (!ascii_isdigit(*t) || fillchar != '-'))
          out_p[-1] = fillchar;
      }
      // }

      // For left-aligned items, fill any remaining space with the fillchar
      for (; l < minwid && out_p < out_end_p; l++) {
        *out_p++ = fillchar;
      }

    // Otherwise if the item is a number, copy that to the output buffer.
    } else if (num >= 0) {
      if (out_p + 20 > out_end_p) {
        break;                  // not sufficient space
      }
      prevchar_isitem = true;

      // { Build the formatting string
      char_u nstr[20];
      char_u *t = nstr;
      if (opt == STL_VIRTCOL_ALT) {
        *t++ = '-';
        minwid--;
      }
      *t++ = '%';
      if (zeropad) {
        *t++ = '0';
      }

      // Note: The `*` means we take the width as one of the arguments
      *t++ = '*';
      *t++ = (char_u)(base == kNumBaseHexadecimal ? 'X' : 'd');
      *t = 0;
      // }

      // { Determine how many characters the number will take up when printed
      //  Note: We have to cast the base because the compiler uses
      //        unsigned ints for the enum values.
      long num_chars = 1;
      for (long n = num; n >= (int) base; n /= (int) base) {
        num_chars++;
      }

      // VIRTCOL_ALT takes up an extra character because
      // of the `-` we added above.
      if (opt == STL_VIRTCOL_ALT) {
        num_chars++;
      }
      // }

      assert(out_end_p >= out_p);
      size_t remaining_buf_len = (size_t)(out_end_p - out_p) + 1;

      // If the number is going to take up too much room
      // Figure out the approximate number in "scientific" type notation.
      // Ex: 14532 with maxwid of 4 -> '14>3'
      if (num_chars > maxwid) {
        // Add two to the width because the power piece will take
        // two extra characters
        num_chars += 2;

        // How many extra characters there are
        long n = num_chars - maxwid;

        // { Reduce the number by base^n
        while (num_chars-- > maxwid) {
          num /= (long)base;
        }
        // }

        // { Add the format string for the exponent bit
        *t++ = '>';
        *t++ = '%';
        // Use the same base as the first number
        *t = t[-3];
        *++t = 0;
        // }

        vim_snprintf((char *)out_p, remaining_buf_len, (char *)nstr,
            0, num, n);
      } else {
        vim_snprintf((char *)out_p, remaining_buf_len, (char *)nstr,
            minwid, num);
      }

      // Advance the output buffer position to the end of the
      // number we just printed
      out_p += STRLEN(out_p);

    // Otherwise, there was nothing to print so mark the item as empty
    } else {
      items[curitem].type = Empty;
    }

    // Only free the string buffer if we allocated it.
    // Note: This is not needed if `str` is pointing at `tmp`
    if (opt == STL_VIM_EXPR) {
      xfree(str);
    }

    if (num >= 0 || (!itemisflag && str && *str)) {
      prevchar_isflag = false;              // Item not NULL, but not a flag
    }

    // Item processed, move to the next
    curitem++;
  }

  *out_p = NUL;
  int itemcnt = curitem;

  // Free the format buffer if we allocated it internally
  if (usefmt != fmt) {
    xfree(usefmt);
  }

  // We have now processed the entire statusline format string.
  // What follows is post-processing to handle alignment and highlighting.

  int width = vim_strsize(out);
  if (maxwidth > 0 && width > maxwidth) {
    // Result is too long, must truncate somewhere.
    int item_idx = 0;
    char_u *trunc_p;

    // If there are no items, truncate from beginning
    if (itemcnt == 0) {
      trunc_p = out;

    // Otherwise, look for the truncation item
    } else {
      // Default to truncating at the first item
      trunc_p = items[0].start;
      item_idx = 0;

      for (int i = 0; i < itemcnt; i++) {
        if (items[i].type == Trunc) {
          // Truncate at %< items.
          trunc_p = items[i].start;
          item_idx = i;
          break;
        }
      }
    }

    // If the truncation point we found is beyond the maximum
    // length of the string, truncate the end of the string.
    if (width - vim_strsize(trunc_p) >= maxwidth) {
      // If we are using a multi-byte encoding, walk from the beginning of the
      // string to find the last character that will fit.
      if (has_mbyte) {
        trunc_p = out;
        width = 0;
        for (;; ) {
          width += ptr2cells(trunc_p);
          if (width >= maxwidth) {
            break;
          }

          // Note: Only advance the pointer if the next
          //       character will fit in the available output space
          trunc_p += (*mb_ptr2len)(trunc_p);
        }

      // Otherwise put the truncation point at the end, leaving enough room
      // for a single-character truncation marker
      } else {
        trunc_p = out + maxwidth - 1;
      }

      // Ignore any items in the statusline that occur after
      // the truncation point
      for (int i = 0; i < itemcnt; i++) {
        if (items[i].start > trunc_p) {
          itemcnt = i;
          break;
        }
      }

      // Truncate the output
      *trunc_p++ = '>';
      *trunc_p = 0;

    // Truncate at the truncation point we found
    } else {
      // { Determine how many bytes to remove
      long trunc_len;
      if (has_mbyte) {
        trunc_len = 0;
        while (width >= maxwidth) {
          width     -= ptr2cells(trunc_p + trunc_len);
          trunc_len += (*mb_ptr2len)(trunc_p + trunc_len);
        }
      } else {
        // Truncate an extra character so we can insert our `<`.
        trunc_len = (width - maxwidth) + 1;
      }
      // }

      // { Truncate the string
      char_u *trunc_end_p = trunc_p + trunc_len;
      STRMOVE(trunc_p + 1, trunc_end_p);

      // Put a `<` to mark where we truncated at
      *trunc_p = '<';

      if (width + 1 < maxwidth) {
        // Advance the pointer to the end of the string
        trunc_p = trunc_p + STRLEN(trunc_p);
      }

      // Fill up for half a double-wide character.
      while (++width < maxwidth) {
        *trunc_p++ = fillchar;
        *trunc_p = NUL;
      }
      // }

      // { Change the start point for items based on
      //  their position relative to our truncation point

      // Note: The offset is one less than the truncation length because
      //       the truncation marker `<` is not counted.
      long item_offset = trunc_len - 1;

      for (int i = item_idx; i < itemcnt; i++) {
        // Items starting at or after the end of the truncated section need
        // to be moved backwards.
        if (items[i].start >= trunc_end_p) {
          items[i].start -= item_offset;
        // Anything inside the truncated area is set to start
        // at the `<` truncation character.
        } else {
          items[i].start = trunc_p;
        }
      }
      // }
    }
    width = maxwidth;

  // If there is room left in our statusline, and room left in our buffer,
  // add characters at the separate marker (if there is one) to
  // fill up the available space.
  } else if (width < maxwidth
             && STRLEN(out) + (size_t)(maxwidth - width) + 1 < outlen) {
    // Find how many separators there are, which we will use when
    // figuring out how many groups there are.
    int num_separators = 0;
    for (int i = 0; i < itemcnt; i++) {
      if (items[i].type == Separate) {
        num_separators++;
      }
    }

    // If we have separated groups, then we deal with it now
    if (num_separators) {
      // Create an array of the start location for each
      // separator mark.
      int separator_locations[STL_MAX_ITEM];
      int index = 0;
      for (int i = 0; i < itemcnt; i++) {
        if (items[i].type == Separate) {
          separator_locations[index] = i;
          index++;
        }
      }

      int standard_spaces = (maxwidth - width) / num_separators;
      int final_spaces = (maxwidth - width) -
        standard_spaces * (num_separators - 1);

      for (int i = 0; i < num_separators; i++) {
        int dislocation = (i == (num_separators - 1))
                          ? final_spaces : standard_spaces;
        char_u *seploc = items[separator_locations[i]].start + dislocation;
        STRMOVE(seploc, items[separator_locations[i]].start);
        for (char_u *s = items[separator_locations[i]].start; s < seploc; s++) {
          *s = fillchar;
        }

        for (int item_idx = separator_locations[i] + 1;
             item_idx < itemcnt;
             item_idx++) {
          items[item_idx].start += dislocation;
        }
      }

      width = maxwidth;
    }
  }

  // Store the info about highlighting.
  if (hltab != NULL) {
    struct stl_hlrec *sp = hltab;
    for (long l = 0; l < itemcnt; l++) {
      if (items[l].type == Highlight) {
        sp->start = items[l].start;
        sp->userhl = items[l].minwid;
        sp++;
      }
    }
    sp->start = NULL;
    sp->userhl = 0;
  }

  // Store the info about tab pages labels.
  if (tabtab != NULL) {
    StlClickRecord *cur_tab_rec = tabtab;
    for (long l = 0; l < itemcnt; l++) {
      if (items[l].type == TabPage) {
        cur_tab_rec->start = (char *)items[l].start;
        if (items[l].minwid == 0) {
          cur_tab_rec->def.type = kStlClickDisabled;
          cur_tab_rec->def.tabnr = 0;
        } else {
          int tabnr = items[l].minwid;
          if (items[l].minwid > 0) {
            cur_tab_rec->def.type = kStlClickTabSwitch;
          } else {
            cur_tab_rec->def.type = kStlClickTabClose;
            tabnr = -tabnr;
          }
          cur_tab_rec->def.tabnr = tabnr;
        }
        cur_tab_rec->def.func = NULL;
        cur_tab_rec++;
      } else if (items[l].type == ClickFunc) {
        cur_tab_rec->start = (char *)items[l].start;
        cur_tab_rec->def.type = kStlClickFuncRun;
        cur_tab_rec->def.tabnr = items[l].minwid;
        cur_tab_rec->def.func = items[l].cmd;
        cur_tab_rec++;
      }
    }
    cur_tab_rec->start = NULL;
    cur_tab_rec->def.type = kStlClickDisabled;
    cur_tab_rec->def.tabnr = 0;
    cur_tab_rec->def.func = NULL;
  }

  // We do not want redrawing a stausline, ruler, title, etc. to trigger
  // another redraw, it may cause an endless loop.  This happens when a
  // statusline changes a highlight group.
  must_redraw = save_must_redraw;
  curwin->w_redr_type = save_redr_type;
  need_highlight_changed = save_highlight_shcnaged;

  return width;
}

/*
 * Get relative cursor position in window into "buf[buflen]", in the form 99%,
 * using "Top", "Bot" or "All" when appropriate.
 */
void get_rel_pos(win_T *wp, char_u *buf, int buflen)
{
  // Need at least 3 chars for writing.
  if (buflen < 3) {
    return;
  }

  long above;          // number of lines above window
  long below;          // number of lines below window

  above = wp->w_topline - 1;
  above += diff_check_fill(wp, wp->w_topline) - wp->w_topfill;
  if (wp->w_topline == 1 && wp->w_topfill >= 1) {
    // All buffer lines are displayed and there is an indication
    // of filler lines, that can be considered seeing all lines.
    above = 0;
  }
  below = wp->w_buffer->b_ml.ml_line_count - wp->w_botline + 1;
  if (below <= 0) {
    STRLCPY(buf, (above == 0 ? _("All") : _("Bot")), buflen);
  } else if (above <= 0) {
    STRLCPY(buf, _("Top"), buflen);
  } else {
    vim_snprintf((char *)buf, (size_t)buflen, "%2d%%", above > 1000000L
                 ? (int)(above / ((above + below) / 100L))
                 : (int)(above * 100L / (above + below)));
  }
}

/// Append (file 2 of 8) to "buf[buflen]", if editing more than one file.
///
/// @param          wp        window whose buffers to check
/// @param[in,out]  buf       string buffer to add the text to
/// @param          buflen    length of the string buffer
/// @param          add_file  if true, add "file" before the arg number
///
/// @return true if it was appended.
static bool append_arg_number(win_T *wp, char_u *buf, int buflen, bool add_file)
  FUNC_ATTR_NONNULL_ALL
{
  // Nothing to do
  if (ARGCOUNT <= 1) {
    return false;
  }

  char_u *p = buf + STRLEN(buf);  // go to the end of the buffer

  // Early out if the string is getting too long
  if (p - buf + 35 >= buflen) {
    return false;
  }

  *p++ = ' ';
  *p++ = '(';
  if (add_file) {
    STRCPY(p, "file ");
    p += 5;
  }
  vim_snprintf((char *)p, (size_t)(buflen - (p - buf)),
               wp->w_arg_idx_invalid
               ? "(%d) of %d)"
               : "%d of %d)", wp->w_arg_idx + 1, ARGCOUNT);
  return true;
}

/*
 * Make "ffname" a full file name, set "sfname" to "ffname" if not NULL.
 * "ffname" becomes a pointer to allocated memory (or NULL).
 */
void fname_expand(buf_T *buf, char_u **ffname, char_u **sfname)
{
  if (*ffname == NULL) {        // if no file name given, nothing to do
    return;
  }
  if (*sfname == NULL) {        // if no short file name given, use ffname
    *sfname = *ffname;
  }
  *ffname = (char_u *)fix_fname((char *)*ffname);     // expand to full path

#ifdef WIN32
  if (!buf->b_p_bin) {
    // If the file name is a shortcut file, use the file it links to.
    char *rfname = os_resolve_shortcut((const char *)(*ffname));
    if (rfname != NULL) {
      xfree(*ffname);
      *ffname = (char_u *)rfname;
      *sfname = (char_u *)rfname;
    }
  }
#endif
}

/*
 * Get the file name for an argument list entry.
 */
char_u *alist_name(aentry_T *aep)
{
  buf_T       *bp;

  // Use the name from the associated buffer if it exists.
  bp = buflist_findnr(aep->ae_fnum);
  if (bp == NULL || bp->b_fname == NULL) {
    return aep->ae_fname;
  }
  return bp->b_fname;
}

/*
 * do_arg_all(): Open up to 'count' windows, one for each argument.
 */
void
do_arg_all(
    int count,
    int forceit,                  // hide buffers in current windows
    int keep_tabs                 // keep current tabs, for ":tab drop file"
)
{
  int i;
  char_u      *opened;          // Array of weight for which args are open:
                                //  0: not opened
                                //  1: opened in other tab
                                //  2: opened in curtab
                                //  3: opened in curtab and curwin

  int opened_len;               // length of opened[]
  int use_firstwin = false;     // use first window for arglist
  int split_ret = OK;
  bool p_ea_save;
  alist_T     *alist;           // argument list to be used
  buf_T       *buf;
  tabpage_T   *tpnext;
  int had_tab = cmdmod.tab;
  win_T       *old_curwin, *last_curwin;
  tabpage_T   *old_curtab, *last_curtab;
  win_T       *new_curwin = NULL;
  tabpage_T   *new_curtab = NULL;

  assert(firstwin != NULL);  // satisfy coverity

  if (ARGCOUNT <= 0) {
    /* Don't give an error message.  We don't want it when the ":all"
     * command is in the .vimrc. */
    return;
  }
  setpcmark();

  opened_len = ARGCOUNT;
  opened = xcalloc((size_t)opened_len, 1);

  /* Autocommands may do anything to the argument list.  Make sure it's not
   * freed while we are working here by "locking" it.  We still have to
   * watch out for its size to be changed. */
  alist = curwin->w_alist;
  alist->al_refcount++;

  old_curwin = curwin;
  old_curtab = curtab;


  /*
   * Try closing all windows that are not in the argument list.
   * Also close windows that are not full width;
   * When 'hidden' or "forceit" set the buffer becomes hidden.
   * Windows that have a changed buffer and can't be hidden won't be closed.
   * When the ":tab" modifier was used do this for all tab pages.
   */
  if (had_tab > 0) {
    goto_tabpage_tp(first_tabpage, true, true);
  }
  for (;; ) {
    win_T *wpnext = NULL;
    tpnext = curtab->tp_next;
    for (win_T *wp = firstwin; wp != NULL; wp = wpnext) {
      wpnext = wp->w_next;
      buf = wp->w_buffer;
      if (buf->b_ffname == NULL
          || (!keep_tabs && (buf->b_nwindows > 1 || wp->w_width != Columns))) {
        i = opened_len;
      } else {
        // check if the buffer in this window is in the arglist
        for (i = 0; i < opened_len; i++) {
          if (i < alist->al_ga.ga_len
              && (AARGLIST(alist)[i].ae_fnum == buf->b_fnum
                  || path_full_compare(alist_name(&AARGLIST(alist)[i]),
                                       buf->b_ffname, true) & kEqualFiles)) {
            int weight = 1;

            if (old_curtab == curtab) {
              weight++;
              if (old_curwin == wp) {
                weight++;
              }
            }

            if (weight > (int)opened[i]) {
              opened[i] = (char_u)weight;
              if (i == 0) {
                if (new_curwin != NULL) {
                  new_curwin->w_arg_idx = opened_len;
                }
                new_curwin = wp;
                new_curtab = curtab;
              }
            } else if (keep_tabs) {
              i = opened_len;
            }

            if (wp->w_alist != alist) {
              /* Use the current argument list for all windows
               * containing a file from it. */
              alist_unlink(wp->w_alist);
              wp->w_alist = alist;
              wp->w_alist->al_refcount++;
            }
            break;
          }
        }
      }
      wp->w_arg_idx = i;

      if (i == opened_len && !keep_tabs) {    // close this window
        if (buf_hide(buf) || forceit || buf->b_nwindows > 1
            || !bufIsChanged(buf)) {
          /* If the buffer was changed, and we would like to hide it,
           * try autowriting. */
          if (!buf_hide(buf) && buf->b_nwindows <= 1 && bufIsChanged(buf)) {
            bufref_T bufref;
            set_bufref(&bufref, buf);
            (void)autowrite(buf, false);
            // Check if autocommands removed the window.
            if (!win_valid(wp) || !bufref_valid(&bufref)) {
              wpnext = firstwin;  // Start all over...
              continue;
            }
          }
          // don't close last window
          if (ONE_WINDOW
              && (first_tabpage->tp_next == NULL || !had_tab)) {
            use_firstwin = true;
          } else {
            win_close(wp, !buf_hide(buf) && !bufIsChanged(buf));
            // check if autocommands removed the next window
            if (!win_valid(wpnext)) {
              // start all over...
              wpnext = firstwin;
            }
          }
        }
      }
    }

    // Without the ":tab" modifier only do the current tab page.
    if (had_tab == 0 || tpnext == NULL) {
      break;
    }

    // check if autocommands removed the next tab page
    if (!valid_tabpage(tpnext)) {
      tpnext = first_tabpage;           // start all over...
    }
    goto_tabpage_tp(tpnext, true, true);
  }

  /*
   * Open a window for files in the argument list that don't have one.
   * ARGCOUNT may change while doing this, because of autocommands.
   */
  if (count > opened_len || count <= 0) {
    count = opened_len;
  }

  // Don't execute Win/Buf Enter/Leave autocommands here.
  autocmd_no_enter++;
  autocmd_no_leave++;
  last_curwin = curwin;
  last_curtab = curtab;
  win_enter(lastwin, false);
  // ":drop all" should re-use an empty window to avoid "--remote-tab"
  // leaving an empty tab page when executed locally.
  if (keep_tabs && BUFEMPTY() && curbuf->b_nwindows == 1
      && curbuf->b_ffname == NULL && !curbuf->b_changed) {
    use_firstwin = true;
  }

  for (i = 0; i < count && i < opened_len && !got_int; i++) {
    if (alist == &global_alist && i == global_alist.al_ga.ga_len - 1) {
      arg_had_last = true;
    }
    if (opened[i] > 0) {
      // Move the already present window to below the current window
      if (curwin->w_arg_idx != i) {
        FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
          if (wp->w_arg_idx == i) {
            if (keep_tabs) {
              new_curwin = wp;
              new_curtab = curtab;
            } else {
              win_move_after(wp, curwin);
            }
            break;
          }
        }
      }
    } else if (split_ret == OK) {
      if (!use_firstwin) {              // split current window
        p_ea_save = p_ea;
        p_ea = true;                    // use space from all windows
        split_ret = win_split(0, WSP_ROOM | WSP_BELOW);
        p_ea = p_ea_save;
        if (split_ret == FAIL) {
          continue;
        }
      } else {      // first window: do autocmd for leaving this buffer
        autocmd_no_leave--;
      }

      /*
       * edit file "i"
       */
      curwin->w_arg_idx = i;
      if (i == 0) {
        new_curwin = curwin;
        new_curtab = curtab;
      }
      (void)do_ecmd(0, alist_name(&AARGLIST(alist)[i]), NULL, NULL, ECMD_ONE,
                    ((buf_hide(curwin->w_buffer)
                      || bufIsChanged(curwin->w_buffer))
                     ? ECMD_HIDE : 0) + ECMD_OLDBUF,
                    curwin);
      if (use_firstwin) {
        autocmd_no_leave++;
      }
      use_firstwin = false;
    }
    os_breakcheck();

    // When ":tab" was used open a new tab for a new window repeatedly.
    if (had_tab > 0 && tabpage_index(NULL) <= p_tpm) {
      cmdmod.tab = 9999;
    }
  }

  // Remove the "lock" on the argument list.
  alist_unlink(alist);

  autocmd_no_enter--;
  // restore last referenced tabpage's curwin
  if (last_curtab != new_curtab) {
    if (valid_tabpage(last_curtab)) {
      goto_tabpage_tp(last_curtab, true, true);
    }
    if (win_valid(last_curwin)) {
      win_enter(last_curwin, false);
    }
  }
  // to window with first arg
  if (valid_tabpage(new_curtab)) {
    goto_tabpage_tp(new_curtab, true, true);
  }
  if (win_valid(new_curwin)) {
    win_enter(new_curwin, false);
  }

  autocmd_no_leave--;
  xfree(opened);
}

/*
 * Open a window for a number of buffers.
 */
void ex_buffer_all(exarg_T *eap)
{
  buf_T       *buf;
  win_T       *wp, *wpnext;
  int split_ret = OK;
  bool p_ea_save;
  int open_wins = 0;
  int r;
  long count;                   // Maximum number of windows to open.
  int all;                      // When true also load inactive buffers.
  int had_tab = cmdmod.tab;
  tabpage_T   *tpnext;

  if (eap->addr_count == 0) {   // make as many windows as possible
    count = 9999;
  } else {
    count = eap->line2;         // make as many windows as specified
  }
  if (eap->cmdidx == CMD_unhide || eap->cmdidx == CMD_sunhide) {
    all = false;
  } else {
    all = true;
  }

  setpcmark();


  /*
   * Close superfluous windows (two windows for the same buffer).
   * Also close windows that are not full-width.
   */
  if (had_tab > 0) {
    goto_tabpage_tp(first_tabpage, true, true);
  }
  for (;; ) {
    tpnext = curtab->tp_next;
    for (wp = firstwin; wp != NULL; wp = wpnext) {
      wpnext = wp->w_next;
      if ((wp->w_buffer->b_nwindows > 1
           || ((cmdmod.split & WSP_VERT)
               ? wp->w_height + wp->w_status_height < Rows - p_ch
               - tabline_height()
               : wp->w_width != Columns)
           || (had_tab > 0 && wp != firstwin))
          && !ONE_WINDOW
          && !(wp->w_closing || wp->w_buffer->b_locked > 0)
          ) {
        win_close(wp, false);
        wpnext = firstwin;              // just in case an autocommand does
                                        // something strange with windows
        tpnext = first_tabpage;         // start all over...
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

  //
  // Go through the buffer list.  When a buffer doesn't have a window yet,
  // open one.  Otherwise move the window to the right position.
  // Watch out for autocommands that delete buffers or windows!
  //
  // Don't execute Win/Buf Enter/Leave autocommands here.
  autocmd_no_enter++;
  win_enter(lastwin, false);
  autocmd_no_leave++;
  for (buf = firstbuf; buf != NULL && open_wins < count; buf = buf->b_next) {
    // Check if this buffer needs a window
    if ((!all && buf->b_ml.ml_mfp == NULL) || !buf->b_p_bl) {
      continue;
    }

    if (had_tab != 0) {
      // With the ":tab" modifier don't move the window.
      if (buf->b_nwindows > 0) {
        wp = lastwin;               // buffer has a window, skip it
      } else {
        wp = NULL;
      }
    } else {
      // Check if this buffer already has a window
      for (wp = firstwin; wp != NULL; wp = wp->w_next) {
        if (wp->w_buffer == buf) {
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
      p_ea_save = p_ea;
      p_ea = true;                      // use space from all windows
      split_ret = win_split(0, WSP_ROOM | WSP_BELOW);
      open_wins++;
      p_ea = p_ea_save;
      if (split_ret == FAIL) {
        continue;
      }

      // Open the buffer in this window.
      swap_exists_action = SEA_DIALOG;
      set_curbuf(buf, DOBUF_GOTO);
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
        win_close(curwin, true);
        open_wins--;
        swap_exists_action = SEA_NONE;
        swap_exists_did_quit = true;

        /* Restore the error/interrupt/exception state if not
         * discarded by a new aborting error, interrupt, or uncaught
         * exception. */
        leave_cleanup(&cs);
      } else
        handle_swap_exists(NULL);
    }

    os_breakcheck();
    if (got_int) {
      (void)vgetc();            // only break the file loading, not the rest
      break;
    }
    // Autocommands deleted the buffer or aborted script processing!!!
    if (aborting()) {
      break;
    }
    // When ":tab" was used open a new tab for a new window repeatedly.
    if (had_tab > 0 && tabpage_index(NULL) <= p_tpm) {
      cmdmod.tab = 9999;
    }
  }
  autocmd_no_enter--;
  win_enter(firstwin, false);           // back to first window
  autocmd_no_leave--;

  /*
   * Close superfluous windows.
   */
  for (wp = lastwin; open_wins > count; ) {
    r = (buf_hide(wp->w_buffer) || !bufIsChanged(wp->w_buffer)
         || autowrite(wp->w_buffer, false) == OK);
    if (!win_valid(wp)) {
      // BufWrite Autocommands made the window invalid, start over
      wp = lastwin;
    } else if (r) {
      win_close(wp, !buf_hide(wp->w_buffer));
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



/*
 * do_modelines() - process mode lines for the current file
 *
 * "flags" can be:
 * OPT_WINONLY	    only set options local to window
 * OPT_NOWIN	    don't set options local to window
 *
 * Returns immediately if the "ml" option isn't set.
 */
void do_modelines(int flags)
{
  linenr_T lnum;
  int nmlines;
  static int entered = 0;

  if (!curbuf->b_p_ml || (nmlines = (int)p_mls) == 0) {
    return;
  }

  /* Disallow recursive entry here.  Can happen when executing a modeline
   * triggers an autocommand, which reloads modelines with a ":do". */
  if (entered) {
    return;
  }

  entered++;
  for (lnum = 1; lnum <= curbuf->b_ml.ml_line_count && lnum <= nmlines;
       lnum++) {
    if (chk_modeline(lnum, flags) == FAIL) {
      nmlines = 0;
    }
  }

  for (lnum = curbuf->b_ml.ml_line_count; lnum > 0 && lnum > nmlines
       && lnum > curbuf->b_ml.ml_line_count - nmlines; lnum--) {
    if (chk_modeline(lnum, flags) == FAIL) {
      nmlines = 0;
    }
  }
  entered--;
}

/*
 * chk_modeline() - check a single line for a mode string
 * Return FAIL if an error encountered.
 */
static int
chk_modeline(
    linenr_T lnum,
    int flags                      // Same as for do_modelines().
)
{
  char_u      *s;
  char_u      *e;
  char_u      *linecopy;                // local copy of any modeline found
  int prev;
  intmax_t vers;
  int end;
  int retval = OK;
  char_u      *save_sourcing_name;
  linenr_T save_sourcing_lnum;
  scid_T save_SID;

  prev = -1;
  for (s = ml_get(lnum); *s != NUL; s++) {
    if (prev == -1 || ascii_isspace(prev)) {
      if ((prev != -1 && STRNCMP(s, "ex:", (size_t)3) == 0)
          || STRNCMP(s, "vi:", (size_t)3) == 0)
        break;
      // Accept both "vim" and "Vim".
      if ((s[0] == 'v' || s[0] == 'V') && s[1] == 'i' && s[2] == 'm') {
        if (s[3] == '<' || s[3] == '=' || s[3] == '>') {
          e = s + 4;
        } else {
          e = s + 3;
        }
        if (getdigits_safe(&e, &vers) != OK) {
          continue;
        }

        if (*e == ':'
            && (s[0] != 'V'
                || STRNCMP(skipwhite(e + 1), "set", 3) == 0)
            && (s[3] == ':'
                || (VIM_VERSION_100 >= vers && isdigit(s[3]))
                || (VIM_VERSION_100 < vers && s[3] == '<')
                || (VIM_VERSION_100 > vers && s[3] == '>')
                || (VIM_VERSION_100 == vers && s[3] == '='))) {
          break;
        }
      }
    }
    prev = *s;
  }

  if (!*s) {
    return retval;
  }

  do {                                // skip over "ex:", "vi:" or "vim:"
    s++;
  } while (s[-1] != ':');

  s = linecopy = vim_strsave(s);      // copy the line, it will change

  save_sourcing_lnum = sourcing_lnum;
  save_sourcing_name = sourcing_name;
  sourcing_lnum = lnum;               // prepare for emsg()
  sourcing_name = (char_u *)"modelines";

  end = false;
  while (end == false) {
    s = skipwhite(s);
    if (*s == NUL) {
      break;
    }

    /*
     * Find end of set command: ':' or end of line.
     * Skip over "\:", replacing it with ":".
     */
    for (e = s; *e != ':' && *e != NUL; e++) {
      if (e[0] == '\\' && e[1] == ':') {
        STRMOVE(e, e + 1);
      }
    }
    if (*e == NUL) {
      end = true;
    }

    /*
     * If there is a "set" command, require a terminating ':' and
     * ignore the stuff after the ':'.
     * "vi:set opt opt opt: foo" -- foo not interpreted
     * "vi:opt opt opt: foo" -- foo interpreted
     * Accept "se" for compatibility with Elvis.
     */
    if (STRNCMP(s, "set ", (size_t)4) == 0
        || STRNCMP(s, "se ", (size_t)3) == 0) {
      if (*e != ':') {                // no terminating ':'?
        break;
      }
      end = true;
      s = vim_strchr(s, ' ') + 1;
    }
    *e = NUL;                         // truncate the set command

    if (*s != NUL) {                  // skip over an empty "::"
      save_SID = current_SID;
      current_SID = SID_MODELINE;
      // Make sure no risky things are executed as a side effect.
      secure++;

      retval = do_set(s, OPT_MODELINE | OPT_LOCAL | flags);

      secure--;
      current_SID = save_SID;
      if (retval == FAIL) {                   // stop if error found
        break;
      }
    }
    s = e + 1;                        // advance to next part
  }

  sourcing_lnum = save_sourcing_lnum;
  sourcing_name = save_sourcing_name;

  xfree(linecopy);

  return retval;
}

// Return true if "buf" is a help buffer.
bool bt_help(const buf_T *const buf)
{
  return buf != NULL && buf->b_help;
}

// Return true if "buf" is the quickfix buffer.
bool bt_quickfix(const buf_T *const buf)
{
  return buf != NULL && buf->b_p_bt[0] == 'q';
}

// Return true if "buf" is a terminal buffer.
bool bt_terminal(const buf_T *const buf)
{
  return buf != NULL && buf->b_p_bt[0] == 't';
}

// Return true if "buf" is a "nofile", "acwrite" or "terminal" buffer.
// This means the buffer name is not a file name.
bool bt_nofile(const buf_T *const buf)
{
  return buf != NULL && ((buf->b_p_bt[0] == 'n' && buf->b_p_bt[2] == 'f')
                         || buf->b_p_bt[0] == 'a' || buf->terminal);
}

// Return true if "buf" is a "nowrite", "nofile" or "terminal" buffer.
bool bt_dontwrite(const buf_T *const buf)
{
  return buf != NULL && (buf->b_p_bt[0] == 'n' || buf->terminal);
}

bool bt_dontwrite_msg(const buf_T *const buf)
{
  if (bt_dontwrite(buf)) {
    EMSG(_("E382: Cannot write, 'buftype' option is set"));
    return true;
  }
  return false;
}

// Return true if the buffer should be hidden, according to 'hidden', ":hide"
// and 'bufhidden'.
bool buf_hide(const buf_T *const buf)
{
  // 'bufhidden' overrules 'hidden' and ":hide", check it first
  switch (buf->b_p_bh[0]) {
  case 'u':                         // "unload"
  case 'w':                         // "wipe"
  case 'd': return false;           // "delete"
  case 'h': return true;            // "hide"
  }
  return p_hid || cmdmod.hide;
}

/*
 * Return special buffer name.
 * Returns NULL when the buffer has a normal file name.
 */
char_u *buf_spname(buf_T *buf)
{
  if (bt_quickfix(buf)) {
    win_T       *win;
    tabpage_T   *tp;

    /*
     * For location list window, w_llist_ref points to the location list.
     * For quickfix window, w_llist_ref is NULL.
     */
    if (find_win_for_buf(buf, &win, &tp) && win->w_llist_ref != NULL) {
      return (char_u *)_(msg_loclist);
    } else {
      return (char_u *)_(msg_qflist);
    }
  }
  // There is no _file_ when 'buftype' is "nofile", b_sfname
  // contains the name as specified by the user.
  if (bt_nofile(buf)) {
    if (buf->b_sfname != NULL) {
      return buf->b_sfname;
    }
    return (char_u *)_("[Scratch]");
  }
  if (buf->b_fname == NULL) {
    return (char_u *)_("[No Name]");
  }
  return NULL;
}

/// Find a window for buffer "buf".
/// If found true is returned and "wp" and "tp" are set to
/// the window and tabpage.
/// If not found, false is returned.
///
/// @param       buf  buffer to find a window for
/// @param[out]  wp   stores the found window
/// @param[out]  tp   stores the found tabpage
///
/// @return true if a window was found for the buffer.
bool find_win_for_buf(buf_T *buf, win_T **wp, tabpage_T **tp)
{
  *wp = NULL;
  *tp = NULL;
  FOR_ALL_TAB_WINDOWS(tp2, wp2) {
    if (wp2->w_buffer == buf) {
      *tp = tp2;
      *wp = wp2;
      return true;
    }
  }
  return false;
}

/*
 * Insert the sign into the signlist.
 */
static void insert_sign(
    buf_T *buf,             // buffer to store sign in
    signlist_T *prev,       // previous sign entry
    signlist_T *next,       // next sign entry
    int id,                 // sign ID
    linenr_T lnum,          // line number which gets the mark
    int typenr              // typenr of sign we are adding
)
{
    signlist_T *newsign = xmalloc(sizeof(signlist_T));
    newsign->id = id;
    newsign->lnum = lnum;
    newsign->typenr = typenr;
    newsign->next = next;
    newsign->prev = prev;
    if (next != NULL) {
      next->prev = newsign;
    }
    buf->b_signcols_max = -1;

    if (prev == NULL) {
        /* When adding first sign need to redraw the windows to create the
         * column for signs. */
        if (buf->b_signlist == NULL) {
            redraw_buf_later(buf, NOT_VALID);
            changed_cline_bef_curs();
        }

        // first sign in signlist
        buf->b_signlist = newsign;
    }
    else {
        prev->next = newsign;
    }
}

static int sign_compare(const void *a1, const void *a2)
{
    const signlist_T *s1 = *(const signlist_T **)a1;
    const signlist_T *s2 = *(const signlist_T **)a2;

    // Sort by line number and the by id

    if (s1->lnum > s2->lnum) {
        return 1;
    }
    if (s1->lnum < s2->lnum) {
        return -1;
    }
    if (s1->id > s2->id) {
        return 1;
    }
    if (s1->id < s2->id) {
        return -1;
    }

    return 0;
}

int buf_signcols(buf_T *buf)
{
    if (buf->b_signcols_max == -1) {
        signlist_T *sign;  // a sign in the signlist
        signlist_T **signs_array;
        signlist_T **prev_sign;
        int nr_signs = 0, i = 0, same;

        // Count the number of signs
        for (sign = buf->b_signlist; sign != NULL; sign = sign->next) {
            nr_signs++;
        }

        // Make an array of all the signs
        signs_array = xcalloc((size_t)nr_signs, sizeof(*sign));
        for (sign = buf->b_signlist; sign != NULL; sign = sign->next) {
            signs_array[i] = sign;
            i++;
        }

        // Sort the array
        qsort(signs_array, (size_t)nr_signs, sizeof(signlist_T *),
              sign_compare);

        // Find the maximum amount of signs existing in a single line
        buf->b_signcols_max = 0;

        same = 1;
        for (i = 1; i < nr_signs; i++) {
            if (signs_array[i - 1]->lnum != signs_array[i]->lnum) {
                if (buf->b_signcols_max < same) {
                    buf->b_signcols_max = same;
                }
                same = 1;
            } else {
                same++;
            }
        }

        if (nr_signs > 0 && buf->b_signcols_max < same) {
            buf->b_signcols_max = same;
        }

        // Recreate the linked list with the sorted order of the array
        buf->b_signlist = NULL;
        prev_sign = &buf->b_signlist;

        for (i = 0; i < nr_signs; i++) {
            sign = signs_array[i];
            sign->next = NULL;
            *prev_sign = sign;

            prev_sign = &sign->next;
        }

        xfree(signs_array);

        // Check if we need to redraw
        if (buf->b_signcols_max != buf->b_signcols) {
            buf->b_signcols = buf->b_signcols_max;
            redraw_buf_later(buf, NOT_VALID);
        }
    }

    return buf->b_signcols;
}

/*
 * Add the sign into the signlist. Find the right spot to do it though.
 */
void buf_addsign(
    buf_T *buf,     // buffer to store sign in
    int id,         // sign ID
    linenr_T lnum,  // line number which gets the mark
    int typenr      // typenr of sign we are adding
)
{
    signlist_T **lastp;  // pointer to pointer to current sign
    signlist_T *sign;    // a sign in the signlist
    signlist_T *prev;    // the previous sign

    prev = NULL;
    for (sign = buf->b_signlist; sign != NULL; sign = sign->next) {
        if (lnum == sign->lnum && id == sign->id) {
            sign->typenr = typenr;
            return;
        } else if ((lnum == sign->lnum && id != sign->id)
                   || (id < 0 && lnum < sign->lnum)) {
          // keep signs sorted by lnum: insert new sign at head of list for
          // this lnum
          while (prev != NULL && prev->lnum == lnum) {
            prev = prev->prev;
          }
          if (prev == NULL) {
            sign = buf->b_signlist;
          } else {
            sign = prev->next;
          }
          insert_sign(buf, prev, sign, id, lnum, typenr);
          return;
        }
        prev = sign;
    }

    // insert new sign at head of list for this lnum
    while (prev != NULL && prev->lnum == lnum) {
      prev = prev->prev;
    }
    if (prev == NULL) {
      sign = buf->b_signlist;
    } else {
      sign = prev->next;
    }
    insert_sign(buf, prev, sign, id, lnum, typenr);

    // Having more than one sign with _the same type_ and on the _same line_ is
    // unwanted, let's prevent it.

    lastp = &buf->b_signlist;
    for (sign = buf->b_signlist; sign != NULL; sign = sign->next) {
        if (lnum == sign->lnum && sign->typenr == typenr && id != sign->id) {
            *lastp = sign->next;
            xfree(sign);
        } else {
            lastp = &sign->next;
        }
    }
}

// For an existing, placed sign "markId" change the type to "typenr".
// Returns the line number of the sign, or zero if the sign is not found.
linenr_T buf_change_sign_type(
    buf_T *buf,         // buffer to store sign in
    int markId,         // sign ID
    int typenr          // typenr of sign we are adding
)
{
    signlist_T *sign;  // a sign in the signlist

    for (sign = buf->b_signlist; sign != NULL; sign = sign->next) {
        if (sign->id == markId) {
            sign->typenr = typenr;
            return sign->lnum;
        }
    }

    return (linenr_T)0;
}


/// Gets a sign from a given line.
///
/// @param buf Buffer in which to search
/// @param lnum Line in which to search
/// @param type Type of sign to look for
/// @param idx if there multiple signs, this index will pick the n-th
//          out of the most `max_signs` sorted ascending by Id.
/// @param max_signs the number of signs, with priority for the ones
//         with the highest Ids.
/// @return Identifier of the matching sign, or 0
int buf_getsigntype(buf_T *buf, linenr_T lnum, SignType type,
                    int idx, int max_signs)
{
    signlist_T *sign;  // a sign in a b_signlist
    signlist_T *matches[9];
    int nr_matches = 0;

    for (sign = buf->b_signlist; sign != NULL; sign = sign->next) {
        if (sign->lnum == lnum
                && (type == SIGN_ANY
                    || (type == SIGN_TEXT
                        && sign_get_text(sign->typenr) != NULL)
                    || (type == SIGN_LINEHL
                        && sign_get_attr(sign->typenr, SIGN_LINEHL) != 0)
                    || (type == SIGN_NUMHL
                        && sign_get_attr(sign->typenr, SIGN_NUMHL) != 0))) {
            matches[nr_matches] = sign;
            nr_matches++;

            if (nr_matches == ARRAY_SIZE(matches)) {
                break;
            }
        }
    }

    if (nr_matches > 0) {
        if (nr_matches > max_signs) {
            idx += nr_matches - max_signs;
        }

        if (idx >= nr_matches) {
            return 0;
        }

        return matches[idx]->typenr;
    }

    return 0;
}

linenr_T buf_delsign(
    buf_T *buf,  // buffer sign is stored in
    int id       // sign id
)
{
    signlist_T **lastp;  // pointer to pointer to current sign
    signlist_T *sign;    // a sign in a b_signlist
    signlist_T *next;    // the next sign in a b_signlist
    linenr_T lnum;       // line number whose sign was deleted

    buf->b_signcols_max = -1;
    lastp = &buf->b_signlist;
    lnum = 0;
    for (sign = buf->b_signlist; sign != NULL; sign = next) {
        next = sign->next;
        if (sign->id == id) {
            *lastp = next;
            if (next != NULL) {
              next->prev = sign->prev;
            }
            lnum = sign->lnum;
            xfree(sign);
            break;
        } else {
            lastp = &sign->next;
        }
    }

    /* When deleted the last sign needs to redraw the windows to remove the
     * sign column. */
    if (buf->b_signlist == NULL) {
        redraw_buf_later(buf, NOT_VALID);
        changed_cline_bef_curs();
    }

    return lnum;
}


/*
 * Find the line number of the sign with the requested id. If the sign does
 * not exist, return 0 as the line number. This will still let the correct file
 * get loaded.
 */
int buf_findsign(
    buf_T *buf,     // buffer to store sign in
    int id          // sign ID
)
{
    signlist_T *sign;  // a sign in the signlist

    for (sign = buf->b_signlist; sign != NULL; sign = sign->next) {
        if (sign->id == id) {
            return (int)sign->lnum;
        }
    }

    return 0;
}

int buf_findsign_id(
    buf_T *buf,         // buffer whose sign we are searching for
    linenr_T lnum       // line number of sign
)
{
    signlist_T *sign;   // a sign in the signlist

    for (sign = buf->b_signlist; sign != NULL; sign = sign->next) {
        if (sign->lnum == lnum) {
            return sign->id;
        }
    }

    return 0;
}


/*
 * Delete signs in buffer "buf".
 */
void buf_delete_signs(buf_T *buf)
{
    signlist_T *next;

    // When deleting the last sign need to redraw the windows to remove the
    // sign column. Not when curwin is NULL (this means we're exiting).
    if (buf->b_signlist != NULL && curwin != NULL){
      redraw_buf_later(buf, NOT_VALID);
      changed_cline_bef_curs();
    }

    while (buf->b_signlist != NULL) {
        next = buf->b_signlist->next;
        xfree(buf->b_signlist);
        buf->b_signlist = next;
    }
    buf->b_signcols_max = -1;
}

/*
 * Delete all signs in all buffers.
 */
void buf_delete_all_signs(void)
{
  FOR_ALL_BUFFERS(buf) {
    if (buf->b_signlist != NULL) {
      buf_delete_signs(buf);
    }
  }
}

/*
 * List placed signs for "rbuf".  If "rbuf" is NULL do it for all buffers.
 */
void sign_list_placed(buf_T *rbuf)
{
    buf_T *buf;
    signlist_T *p;
    char lbuf[BUFSIZ];

    MSG_PUTS_TITLE(_("\n--- Signs ---"));
    msg_putchar('\n');
    if (rbuf == NULL) {
        buf = firstbuf;
    } else {
        buf = rbuf;
    }
    while (buf != NULL && !got_int) {
        if (buf->b_signlist != NULL) {
            vim_snprintf(lbuf, BUFSIZ, _("Signs for %s:"), buf->b_fname);
            MSG_PUTS_ATTR(lbuf, HL_ATTR(HLF_D));
            msg_putchar('\n');
        }
        for (p = buf->b_signlist; p != NULL && !got_int; p = p->next) {
            vim_snprintf(lbuf, BUFSIZ, _("    line=%" PRId64 "  id=%d  name=%s"),
                    (int64_t)p->lnum, p->id, sign_typenr2name(p->typenr));
            MSG_PUTS(lbuf);
            msg_putchar('\n');
        }
        if (rbuf != NULL) {
            break;
        }
        buf = buf->b_next;
    }
}

/*
 * Adjust a placed sign for inserted/deleted lines.
 */
void sign_mark_adjust(linenr_T line1, linenr_T line2, long amount, long amount_after)
{
    signlist_T *sign;    // a sign in a b_signlist
    signlist_T *next;    // the next sign in a b_signlist
    signlist_T **lastp;  // pointer to pointer to current sign

    curbuf->b_signcols_max = -1;
    lastp = &curbuf->b_signlist;

    for (sign = curbuf->b_signlist; sign != NULL; sign = next) {
        next = sign->next;
        if (sign->lnum >= line1 && sign->lnum <= line2) {
            if (amount == MAXLNUM) {
                *lastp = next;
                xfree(sign);
                continue;
            } else {
                sign->lnum += amount;
            }
        } else if (sign->lnum > line2) {
            sign->lnum += amount_after;
        }
        lastp = &sign->next;
    }
}

// bufhl: plugin highlights associated with a buffer

/// Get reference to line in kbtree_t
///
/// @param b the three
/// @param line the linenumber to lookup
/// @param put if true, put a new line when not found
///            if false, return NULL when not found
BufhlLine *bufhl_tree_ref(BufhlInfo *b, linenr_T line, bool put)
{
  BufhlLine t = BUFHLLINE_INIT(line);

  // kp_put() only works if key is absent, try get first
  BufhlLine **pp = kb_get(bufhl, b, &t);
  if (pp) {
    return *pp;
  } else if (!put) {
    return NULL;
  }

  BufhlLine *p = xmalloc(sizeof(*p));
  *p = (BufhlLine)BUFHLLINE_INIT(line);
  kb_put(bufhl, b, p);
  return p;
}

/// Adds a highlight to buffer.
///
/// Unlike matchaddpos() highlights follow changes to line numbering (as lines
/// are inserted/removed above the highlighted line), like signs and marks do.
///
/// When called with "src_id" set to 0, a unique source id is generated and
/// returned. Succesive calls can pass it in as "src_id" to add new highlights
/// to the same source group. All highlights in the same group can be cleared
/// at once. If the highlight never will be manually deleted pass in -1 for
/// "src_id"
///
/// if "hl_id" or "lnum" is invalid no highlight is added, but a new src_id
/// is still returned.
///
/// @param buf The buffer to add highlights to
/// @param src_id src_id to use or 0 to use a new src_id group,
///               or -1 for ungrouped highlight.
/// @param hl_id Id of the highlight group to use
/// @param lnum The line to highlight
/// @param col_start First column to highlight
/// @param col_end The last column to highlight,
///                or -1 to highlight to end of line
/// @return The src_id that was used
int bufhl_add_hl(buf_T *buf,
                 int src_id,
                 int hl_id,
                 linenr_T lnum,
                 colnr_T col_start,
                 colnr_T col_end)
{
  if (src_id == 0) {
    src_id = (int)nvim_create_namespace((String)STRING_INIT);
  }
  if (hl_id <= 0) {
      // no highlight group or invalid line, just return src_id
      return src_id;
  }

  BufhlLine *lineinfo = bufhl_tree_ref(&buf->b_bufhl_info, lnum, true);

  BufhlItem *hlentry = kv_pushp(lineinfo->items);
  hlentry->src_id = src_id;
  hlentry->hl_id = hl_id;
  hlentry->start = col_start;
  hlentry->stop = col_end;

  if (0 < lnum && lnum <= buf->b_ml.ml_line_count) {
    redraw_buf_line_later(buf, lnum);
  }
  return src_id;
}

/// Add highlighting to a buffer, bounded by two cursor positions,
/// with an offset.
///
/// @param buf Buffer to add highlights to
/// @param src_id src_id to use or 0 to use a new src_id group,
///               or -1 for ungrouped highlight.
/// @param hl_id Highlight group id
/// @param pos_start Cursor position to start the hightlighting at
/// @param pos_end Cursor position to end the highlighting at
/// @param offset Move the whole highlighting this many columns to the right
void bufhl_add_hl_pos_offset(buf_T *buf,
                             int src_id,
                             int hl_id,
                             lpos_T pos_start,
                             lpos_T pos_end,
                             colnr_T offset)
{
  colnr_T hl_start = 0;
  colnr_T hl_end = 0;

  for (linenr_T lnum = pos_start.lnum; lnum <= pos_end.lnum; lnum ++) {
    if (pos_start.lnum < lnum && lnum < pos_end.lnum) {
      hl_start = offset;
      hl_end = MAXCOL;
    } else if (lnum == pos_start.lnum && lnum < pos_end.lnum) {
      hl_start = pos_start.col + offset + 1;
      hl_end = MAXCOL;
    } else if (pos_start.lnum < lnum && lnum == pos_end.lnum) {
      hl_start = offset;
      hl_end = pos_end.col + offset;
    } else if (pos_start.lnum == lnum && pos_end.lnum == lnum) {
      hl_start = pos_start.col + offset + 1;
      hl_end = pos_end.col + offset;
    }
    (void)bufhl_add_hl(buf, src_id, hl_id, lnum, hl_start, hl_end);
  }
}

int bufhl_add_virt_text(buf_T *buf,
                        int src_id,
                        linenr_T lnum,
                        VirtText virt_text)
{
  if (src_id == 0) {
    src_id = (int)nvim_create_namespace((String)STRING_INIT);
  }

  BufhlLine *lineinfo = bufhl_tree_ref(&buf->b_bufhl_info, lnum, true);

  bufhl_clear_virttext(&lineinfo->virt_text);
  if (kv_size(virt_text) > 0) {
    lineinfo->virt_text_src = src_id;
    lineinfo->virt_text = virt_text;
  } else {
    lineinfo->virt_text_src = 0;
    // currently not needed, but allow a future caller with
    // 0 size and non-zero capacity
    kv_destroy(virt_text);
  }

  if (0 < lnum && lnum <= buf->b_ml.ml_line_count) {
    redraw_buf_line_later(buf, lnum);
  }
  return src_id;
}

static void bufhl_clear_virttext(VirtText *text)
{
  for (size_t i = 0; i < kv_size(*text); i++) {
    xfree(kv_A(*text, i).text);
  }
  kv_destroy(*text);
  *text = (VirtText)KV_INITIAL_VALUE;
}

/// Clear bufhl highlights from a given source group and range of lines.
///
/// @param buf The buffer to remove highlights from
/// @param src_id highlight source group to clear, or -1 to clear all groups.
/// @param line_start first line to clear
/// @param line_end last line to clear or MAXLNUM to clear to end of file.
void bufhl_clear_line_range(buf_T *buf,
                            int src_id,
                            linenr_T line_start,
                            linenr_T line_end)
{
  kbitr_t(bufhl) itr;
  BufhlLine *l, t = BUFHLLINE_INIT(line_start);
  if (!kb_itr_get(bufhl, &buf->b_bufhl_info, &t, &itr)) {
    kb_itr_next(bufhl, &buf->b_bufhl_info, &itr);
  }
  for (; kb_itr_valid(&itr); kb_itr_next(bufhl, &buf->b_bufhl_info, &itr)) {
    l = kb_itr_key(&itr);
    linenr_T line = l->line;
    if (line > line_end) {
      break;
    }
    if (line_start <= line) {
      BufhlLineStatus status = bufhl_clear_line(l, src_id, line);
      if (status != kBLSUnchanged) {
        redraw_buf_line_later(buf, line);
      }
      if (status == kBLSDeleted) {
        kb_del_itr(bufhl, &buf->b_bufhl_info, &itr);
        xfree(l);
      }
    }
  }
}

/// Clear bufhl highlights from a given source group and given line
///
/// @param bufhl_info The highlight info for the buffer
/// @param src_id Highlight source group to clear, or -1 to clear all groups.
/// @param lnum Linenr where the highlight should be cleared
static BufhlLineStatus bufhl_clear_line(BufhlLine *lineinfo, int src_id,
                                        linenr_T lnum)
{
  BufhlLineStatus changed = kBLSUnchanged;
  size_t oldsize = kv_size(lineinfo->items);
  if (src_id < 0) {
    kv_size(lineinfo->items) = 0;
  } else {
    size_t newidx = 0;
    for (size_t i = 0; i < kv_size(lineinfo->items); i++) {
      if (kv_A(lineinfo->items, i).src_id != src_id) {
        if (i != newidx) {
          kv_A(lineinfo->items, newidx) = kv_A(lineinfo->items, i);
        }
        newidx++;
      }
    }
    kv_size(lineinfo->items) = newidx;
  }
  if (kv_size(lineinfo->items) != oldsize) {
    changed = kBLSChanged;
  }

  if (kv_size(lineinfo->virt_text) != 0
      && (src_id < 0 || src_id == lineinfo->virt_text_src)) {
    bufhl_clear_virttext(&lineinfo->virt_text);
    lineinfo->virt_text_src = 0;
    changed = kBLSChanged;
  }

  if (kv_size(lineinfo->items) == 0 && kv_size(lineinfo->virt_text) == 0) {
    kv_destroy(lineinfo->items);
    return kBLSDeleted;
  }
  return changed;
}


/// Remove all highlights and free the highlight data
void bufhl_clear_all(buf_T *buf)
{
  bufhl_clear_line_range(buf, -1, 1, MAXLNUM);
  kb_destroy(bufhl, (&buf->b_bufhl_info));
  kb_init(&buf->b_bufhl_info);
  kv_destroy(buf->b_bufhl_move_space);
  kv_init(buf->b_bufhl_move_space);
}

/// Adjust a placed highlight for inserted/deleted lines.
void bufhl_mark_adjust(buf_T* buf,
                       linenr_T line1,
                       linenr_T line2,
                       long amount,
                       long amount_after,
                       bool end_temp)
{
  kbitr_t(bufhl) itr;
  BufhlLine *l, t = BUFHLLINE_INIT(line1);
  if (end_temp && amount < 0) {
    // Move all items from b_bufhl_move_space to the btree.
    for (size_t i = 0; i < kv_size(buf->b_bufhl_move_space); i++) {
      l = kv_A(buf->b_bufhl_move_space, i);
      l->line += amount;
      kb_put(bufhl, &buf->b_bufhl_info, l);
    }
    kv_size(buf->b_bufhl_move_space) = 0;
    return;
  }

  if (!kb_itr_get(bufhl, &buf->b_bufhl_info, &t, &itr)) {
    kb_itr_next(bufhl, &buf->b_bufhl_info, &itr);
  }
  for (; kb_itr_valid(&itr); kb_itr_next(bufhl, &buf->b_bufhl_info, &itr)) {
    l = kb_itr_key(&itr);
    if (l->line >= line1 && l->line <= line2) {
      if (end_temp && amount > 0) {
        kb_del_itr(bufhl, &buf->b_bufhl_info, &itr);
        kv_push(buf->b_bufhl_move_space, l);
      }
      if (amount == MAXLNUM) {
        if (bufhl_clear_line(l, -1, l->line) == kBLSDeleted) {
          kb_del_itr(bufhl, &buf->b_bufhl_info, &itr);
          xfree(l);
        } else {
          assert(false);
        }
      } else {
        l->line += amount;
      }
    } else if (l->line > line2) {
      if (amount_after == 0) {
        break;
      }
      l->line += amount_after;
    }
  }
}


/// Get highlights to display at a specific line
///
/// @param buf The buffer handle
/// @param lnum The line number
/// @param[out] info The highligts for the line
/// @return true if there was highlights to display
bool bufhl_start_line(buf_T *buf, linenr_T lnum, BufhlLineInfo *info)
{
  BufhlLine *lineinfo = bufhl_tree_ref(&buf->b_bufhl_info, lnum, false);
  if (!lineinfo) {
    return false;
  }
  info->valid_to = -1;
  info->line = lineinfo;
  return true;
}

/// get highlighting at column col
///
/// It is is assumed this will be called with
/// non-decreasing column nrs, so that it is
/// possible to only recalculate highlights
/// at endpoints.
///
/// @param info The info returned by bufhl_start_line
/// @param col The column to get the attr for
/// @return The highilight attr to display at the column
int bufhl_get_attr(BufhlLineInfo *info, colnr_T col)
{
  if (col <= info->valid_to) {
    return info->current;
  }
  int attr = 0;
  info->valid_to = MAXCOL;
  for (size_t i = 0; i < kv_size(info->line->items); i++) {
    BufhlItem entry = kv_A(info->line->items, i);
    if (entry.start <= col && col <= entry.stop) {
      int entry_attr = syn_id2attr(entry.hl_id);
      attr = hl_combine_attr(attr, entry_attr);
      if (entry.stop < info->valid_to) {
        info->valid_to = entry.stop;
      }
    } else if (col < entry.start && entry.start-1 < info->valid_to) {
      info->valid_to = entry.start-1;
    }
  }
  info->current = attr;
  return attr;
}


/*
 * Set 'buflisted' for curbuf to "on" and trigger autocommands if it changed.
 */
void set_buflisted(int on)
{
  if (on != curbuf->b_p_bl) {
    curbuf->b_p_bl = on;
    if (on) {
      apply_autocmds(EVENT_BUFADD, NULL, NULL, false, curbuf);
    } else {
      apply_autocmds(EVENT_BUFDELETE, NULL, NULL, false, curbuf);
    }
  }
}

/// Read the file for "buf" again and check if the contents changed.
/// Return true if it changed or this could not be checked.
///
/// @param  buf  buffer to check
///
/// @return true if the buffer's contents have changed
bool buf_contents_changed(buf_T *buf)
  FUNC_ATTR_NONNULL_ALL
{
  bool differ = true;

  // Allocate a buffer without putting it in the buffer list.
  buf_T *newbuf = buflist_new(NULL, NULL, (linenr_T)1, BLN_DUMMY);
  if (newbuf == NULL) {
    return true;
  }

  // Force the 'fileencoding' and 'fileformat' to be equal.
  exarg_T ea;
  prep_exarg(&ea, buf);

  // set curwin/curbuf to buf and save a few things
  aco_save_T aco;
  aucmd_prepbuf(&aco, newbuf);

  if (ml_open(curbuf) == OK
      && readfile(buf->b_ffname, buf->b_fname,
                  (linenr_T)0, (linenr_T)0, (linenr_T)MAXLNUM,
                  &ea, READ_NEW | READ_DUMMY) == OK) {
    // compare the two files line by line
    if (buf->b_ml.ml_line_count == curbuf->b_ml.ml_line_count) {
      differ = false;
      for (linenr_T lnum = 1; lnum <= curbuf->b_ml.ml_line_count; lnum++) {
        if (STRCMP(ml_get_buf(buf, lnum, false), ml_get(lnum)) != 0) {
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

  return differ;
}

/*
 * Wipe out a buffer and decrement the last buffer number if it was used for
 * this buffer.  Call this to wipe out a temp buffer that does not contain any
 * marks.
 */
void
wipe_buffer(
    buf_T *buf,
    int aucmd                   // When true trigger autocommands.
)
{
  if (!aucmd) {
    // Don't trigger BufDelete autocommands here.
    block_autocmds();
  }
  close_buffer(NULL, buf, DOBUF_WIPE, false);
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
///
/// @see curbufIsChanged()
void buf_open_scratch(handle_T bufnr, char *bufname)
{
  (void)do_ecmd((int)bufnr, NULL, NULL, NULL, ECMD_ONE, ECMD_HIDE, NULL);
  (void)setfname(curbuf, (char_u *)bufname, NULL, true);
  set_option_value("bh", 0L, "hide", OPT_LOCAL);
  set_option_value("bt", 0L, "nofile", OPT_LOCAL);
  set_option_value("swf", 0L, NULL, OPT_LOCAL);
  RESET_BINDING(curwin);
}
