// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Functions for creating a session file, i.e. implementing:
//   :mkexrc
//   :mkvimrc
//   :mkview
//   :mksession

#include <assert.h>
#include <string.h>
#include <stdbool.h>
#include <stdlib.h>
#include <inttypes.h>

#include "nvim/vim.h"
#include "nvim/globals.h"
#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/cursor.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/ex_session.h"
#include "nvim/file_search.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/keymap.h"
#include "nvim/misc1.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"
#include "nvim/path.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_session.c.generated.h"
#endif

/// Whether ":lcd" or ":tcd" was produced for a session.
static int did_lcd;

#define PUTLINE_FAIL(s) \
  do { if (FAIL == put_line(fd, (s))) { return FAIL; } } while (0)

static int put_view_curpos(FILE *fd, const win_T *wp, char *spaces)
{
  int r;

  if (wp->w_curswant == MAXCOL) {
    r = fprintf(fd, "%snormal! $\n", spaces);
  } else {
    r = fprintf(fd, "%snormal! 0%d|\n", spaces, wp->w_virtcol + 1);
  }
  return r >= 0;
}

static int ses_winsizes(FILE *fd, int restore_size, win_T *tab_firstwin)
{
  int n = 0;
  win_T       *wp;

  if (restore_size && (ssop_flags & SSOP_WINSIZE)) {
    for (wp = tab_firstwin; wp != NULL; wp = wp->w_next) {
      if (!ses_do_win(wp)) {
        continue;
      }
      n++;

      // restore height when not full height
      if (wp->w_height + wp->w_status_height < topframe->fr_height
          && (fprintf(fd,
                      "exe '%dresize ' . ((&lines * %" PRId64
                      " + %" PRId64 ") / %" PRId64 ")\n",
                      n, (int64_t)wp->w_height,
                      (int64_t)Rows / 2, (int64_t)Rows) < 0)) {
        return FAIL;
      }

      // restore width when not full width
      if (wp->w_width < Columns
          && (fprintf(fd,
                      "exe 'vert %dresize ' . ((&columns * %" PRId64
                      " + %" PRId64 ") / %" PRId64 ")\n",
                      n, (int64_t)wp->w_width, (int64_t)Columns / 2,
                      (int64_t)Columns) < 0)) {
        return FAIL;
      }
    }
  } else {
    // Just equalize window sizes.
    PUTLINE_FAIL("wincmd =");
  }
  return OK;
}

// Write commands to "fd" to recursively create windows for frame "fr",
// horizontally and vertically split.
// After the commands the last window in the frame is the current window.
// Returns FAIL when writing the commands to "fd" fails.
static int ses_win_rec(FILE *fd, frame_T *fr)
{
  frame_T     *frc;
  int count = 0;

  if (fr->fr_layout != FR_LEAF) {
    // Find first frame that's not skipped and then create a window for
    // each following one (first frame is already there).
    frc = ses_skipframe(fr->fr_child);
    if (frc != NULL) {
      while ((frc = ses_skipframe(frc->fr_next)) != NULL) {
        // Make window as big as possible so that we have lots of room
        // to split.
        if (fprintf(fd, "%s%s",
                    "wincmd _ | wincmd |\n",
                    (fr->fr_layout == FR_COL ? "split\n" : "vsplit\n")) < 0) {
          return FAIL;
        }
        count++;
      }
    }

    // Go back to the first window.
    if (count > 0 && (fprintf(fd, fr->fr_layout == FR_COL
                              ? "%dwincmd k\n" : "%dwincmd h\n", count) < 0)) {
      return FAIL;
    }

    // Recursively create frames/windows in each window of this column or row.
    frc = ses_skipframe(fr->fr_child);
    while (frc != NULL) {
      ses_win_rec(fd, frc);
      frc = ses_skipframe(frc->fr_next);
      // Go to next window.
      if (frc != NULL && put_line(fd, "wincmd w") == FAIL) {
        return FAIL;
      }
    }
  }
  return OK;
}

// Skip frames that don't contain windows we want to save in the Session.
// Returns NULL when there none.
static frame_T *ses_skipframe(frame_T *fr)
{
  frame_T     *frc;

  FOR_ALL_FRAMES(frc, fr) {
    if (ses_do_frame(frc)) {
      break;
    }
  }
  return frc;
}

// Return true if frame "fr" has a window somewhere that we want to save in
// the Session.
static bool ses_do_frame(const frame_T *fr)
  FUNC_ATTR_NONNULL_ARG(1)
{
  const frame_T *frc;

  if (fr->fr_layout == FR_LEAF) {
    return ses_do_win(fr->fr_win);
  }
  FOR_ALL_FRAMES(frc, fr->fr_child) {
    if (ses_do_frame(frc)) {
      return true;
    }
  }
  return false;
}

/// Return non-zero if window "wp" is to be stored in the Session.
static int ses_do_win(win_T *wp)
{
  if (wp->w_buffer->b_fname == NULL
      // When 'buftype' is "nofile" can't restore the window contents.
      || (!wp->w_buffer->terminal && bt_nofile(wp->w_buffer))) {
    return ssop_flags & SSOP_BLANK;
  }
  if (bt_help(wp->w_buffer)) {
    return ssop_flags & SSOP_HELP;
  }
  return true;
}

/// Writes an :argument list to the session file.
///
/// @param fd
/// @param cmd
/// @param gap
/// @param fullname  true: use full path name
/// @param flagp
///
/// @returns FAIL if writing fails.
static int ses_arglist(FILE *fd, char *cmd, garray_T *gap, int fullname,
                       unsigned *flagp)
{
  char_u      *buf = NULL;
  char_u      *s;

  if (fprintf(fd, "%s\n%s\n", cmd, "%argdel") < 0) {
    return FAIL;
  }
  for (int i = 0; i < gap->ga_len; i++) {
    // NULL file names are skipped (only happens when out of memory).
    s = alist_name(&((aentry_T *)gap->ga_data)[i]);
    if (s != NULL) {
      if (fullname) {
        buf = xmalloc(MAXPATHL);
        (void)vim_FullName((char *)s, (char *)buf, MAXPATHL, false);
        s = buf;
      }
      char *fname_esc = ses_escape_fname((char *)s, flagp);
      if (fprintf(fd, "$argadd %s\n", fname_esc) < 0) {
        xfree(fname_esc);
        xfree(buf);
        return FAIL;
      }
      xfree(fname_esc);
      xfree(buf);
    }
  }
  return OK;
}

/// Gets the buffer name for `buf`.
static char *ses_get_fname(buf_T *buf, unsigned *flagp)
{
  // Use the short file name if the current directory is known at the time
  // the session file will be sourced.
  // Don't do this for ":mkview", we don't know the current directory.
  // Don't do this after ":lcd", we don't keep track of what the current
  // directory is.
  if (buf->b_sfname != NULL
      && flagp == &ssop_flags
      && (ssop_flags & (SSOP_CURDIR | SSOP_SESDIR))
      && !p_acd
      && !did_lcd) {
    return (char *)buf->b_sfname;
  }
  return (char *)buf->b_ffname;
}

/// Write a buffer name to the session file.
/// Also ends the line, if "add_eol" is true.
/// Returns FAIL if writing fails.
static int ses_fname(FILE *fd, buf_T *buf, unsigned *flagp, bool add_eol)
{
  char *name = ses_get_fname(buf, flagp);
  if (ses_put_fname(fd, (char_u *)name, flagp) == FAIL
      || (add_eol && fprintf(fd, "\n") < 0)) {
    return FAIL;
  }
  return OK;
}

// Escapes a filename for session writing.
// Takes care of "slash" flag in 'sessionoptions' and escapes special
// characters.
//
// Returns allocated string or NULL.
static char *ses_escape_fname(char *name, unsigned *flagp)
{
  char *p;
  char *sname = (char *)home_replace_save(NULL, (char_u *)name);

  // Always SSOP_SLASH: change all backslashes to forward slashes.
  for (p = sname; *p != NUL; MB_PTR_ADV(p)) {
    if (*p == '\\') {
      *p = '/';
    }
  }

  // Escape special characters.
  p = vim_strsave_fnameescape(sname, false);
  xfree(sname);
  return p;
}

// Write a file name to the session file.
// Takes care of the "slash" option in 'sessionoptions' and escapes special
// characters.
// Returns FAIL if writing fails.
static int ses_put_fname(FILE *fd, char_u *name, unsigned *flagp)
{
  char *p = ses_escape_fname((char *)name, flagp);
  bool retval = fputs(p, fd) < 0 ? FAIL : OK;
  xfree(p);
  return retval;
}

// Write commands to "fd" to restore the view of a window.
// Caller must make sure 'scrolloff' is zero.
static int put_view(
    FILE *fd,
    win_T *wp,
    int add_edit,                // add ":edit" command to view
    unsigned *flagp,             // vop_flags or ssop_flags
    int current_arg_idx          // current argument index of the window, use
)                                // -1 if unknown
{
  win_T       *save_curwin;
  int f;
  int do_cursor;
  int did_next = false;

  // Always restore cursor position for ":mksession".  For ":mkview" only
  // when 'viewoptions' contains "cursor".
  do_cursor = (flagp == &ssop_flags || *flagp & SSOP_CURSOR);

  //
  // Local argument list.
  //
  if (wp->w_alist == &global_alist) {
    PUTLINE_FAIL("argglobal");
  } else {
    if (ses_arglist(fd, "arglocal", &wp->w_alist->al_ga,
                    flagp == &vop_flags
                    || !(*flagp & SSOP_CURDIR)
                    || wp->w_localdir != NULL, flagp) == FAIL) {
      return FAIL;
    }
  }

  // Only when part of a session: restore the argument index.  Some
  // arguments may have been deleted, check if the index is valid.
  if (wp->w_arg_idx != current_arg_idx && wp->w_arg_idx < WARGCOUNT(wp)
      && flagp == &ssop_flags) {
    if (fprintf(fd, "%" PRId64 "argu\n", (int64_t)wp->w_arg_idx + 1) < 0) {
      return FAIL;
    }
    did_next = true;
  }

  // Edit the file.  Skip this when ":next" already did it.
  if (add_edit && (!did_next || wp->w_arg_idx_invalid)) {
    char *fname_esc =
      ses_escape_fname(ses_get_fname(wp->w_buffer, flagp), flagp);
    //
    // Load the file.
    //
    if (wp->w_buffer->b_ffname != NULL
        && (!bt_nofile(wp->w_buffer) || wp->w_buffer->terminal)
        ) {
      // Editing a file in this buffer: use ":edit file".
      // This may have side effects! (e.g., compressed or network file).
      //
      // Note, if a buffer for that file already exists, use :badd to
      // edit that buffer, to not lose folding information (:edit resets
      // folds in other buffers)
      if (fprintf(fd,
                  "if bufexists(\"%s\") | buffer %s | else | edit %s | endif\n"
                  // Fixup :terminal buffer name. #7836
                  "if &buftype ==# 'terminal'\n"
                  "  silent file %s\n"
                  "endif\n",
                  fname_esc,
                  fname_esc,
                  fname_esc,
                  fname_esc) < 0) {
        xfree(fname_esc);
        return FAIL;
      }
    } else {
      // No file in this buffer, just make it empty.
      PUTLINE_FAIL("enew");
      if (wp->w_buffer->b_ffname != NULL) {
        // The buffer does have a name, but it's not a file name.
        if (fprintf(fd, "file %s\n", fname_esc) < 0) {
          xfree(fname_esc);
          return FAIL;
        }
      }
      do_cursor = false;
    }
    xfree(fname_esc);
  }

  if (wp->w_alt_fnum) {
    buf_T *const alt = buflist_findnr(wp->w_alt_fnum);

    // Set the alternate file if the buffer is listed.
    if ((flagp == &ssop_flags) && alt != NULL && alt->b_fname != NULL
        && *alt->b_fname != NUL
        && alt->b_p_bl
        && (fputs("balt ", fd) < 0
            || ses_fname(fd, alt, flagp, true) == FAIL)) {
      return FAIL;
    }
  }

  //
  // Local mappings and abbreviations.
  //
  if ((*flagp & (SSOP_OPTIONS | SSOP_LOCALOPTIONS))
      && makemap(fd, wp->w_buffer) == FAIL) {
    return FAIL;
  }

  //
  // Local options.  Need to go to the window temporarily.
  // Store only local values when using ":mkview" and when ":mksession" is
  // used and 'sessionoptions' doesn't include "nvim/options".
  // Some folding options are always stored when "folds" is included,
  // otherwise the folds would not be restored correctly.
  //
  save_curwin = curwin;
  curwin = wp;
  curbuf = curwin->w_buffer;
  if (*flagp & (SSOP_OPTIONS | SSOP_LOCALOPTIONS)) {
    f = makeset(fd, OPT_LOCAL,
                flagp == &vop_flags || !(*flagp & SSOP_OPTIONS));
  } else if (*flagp & SSOP_FOLDS) {
    f = makefoldset(fd);
  } else {
    f = OK;
  }
  curwin = save_curwin;
  curbuf = curwin->w_buffer;
  if (f == FAIL) {
    return FAIL;
  }

  //
  // Save Folds when 'buftype' is empty and for help files.
  //
  if ((*flagp & SSOP_FOLDS)
      && wp->w_buffer->b_ffname != NULL
      && (bt_normal(wp->w_buffer) || bt_help(wp->w_buffer))
      ) {
    if (put_folds(fd, wp) == FAIL) {
      return FAIL;
    }
  }

  //
  // Set the cursor after creating folds, since that moves the cursor.
  //
  if (do_cursor) {
    // Restore the cursor line in the file and relatively in the
    // window.  Don't use "G", it changes the jumplist.
    if (fprintf(fd,
                "let s:l = %" PRId64 " - ((%" PRId64
                " * winheight(0) + %" PRId64 ") / %" PRId64 ")\n"
                "if s:l < 1 | let s:l = 1 | endif\n"
                "keepjumps exe s:l\n"
                "normal! zt\n"
                "keepjumps %" PRId64 "\n",
                (int64_t)wp->w_cursor.lnum,
                (int64_t)(wp->w_cursor.lnum - wp->w_topline),
                (int64_t)(wp->w_height_inner / 2),
                (int64_t)wp->w_height_inner,
                (int64_t)wp->w_cursor.lnum) < 0) {
      return FAIL;
    }
    // Restore the cursor column and left offset when not wrapping.
    if (wp->w_cursor.col == 0) {
      PUTLINE_FAIL("normal! 0");
    } else {
      if (!wp->w_p_wrap && wp->w_leftcol > 0 && wp->w_width > 0) {
        if (fprintf(fd,
                    "let s:c = %" PRId64 " - ((%" PRId64
                    " * winwidth(0) + %" PRId64 ") / %" PRId64 ")\n"
                    "if s:c > 0\n"
                    "  exe 'normal! ' . s:c . '|zs' . %" PRId64 " . '|'\n"
                    "else\n",
                    (int64_t)wp->w_virtcol + 1,
                    (int64_t)(wp->w_virtcol - wp->w_leftcol),
                    (int64_t)(wp->w_width / 2),
                    (int64_t)wp->w_width,
                    (int64_t)wp->w_virtcol + 1) < 0
            || put_view_curpos(fd, wp, "  ") == FAIL
            || put_line(fd, "endif") == FAIL) {
          return FAIL;
        }
      } else if (put_view_curpos(fd, wp, "") == FAIL) {
        return FAIL;
      }
    }
  }

  //
  // Local directory, if the current flag is not view options or the "curdir"
  // option is included.
  //
  if (wp->w_localdir != NULL
      && (flagp != &vop_flags || (*flagp & SSOP_CURDIR))) {
    if (fputs("lcd ", fd) < 0
        || ses_put_fname(fd, wp->w_localdir, flagp) == FAIL
        || fprintf(fd, "\n") < 0) {
      return FAIL;
    }
    did_lcd = true;
  }

  return OK;
}

/// Writes commands for restoring the current buffers, for :mksession.
///
/// Legacy 'sessionoptions'/'viewoptions' flags SSOP_UNIX, SSOP_SLASH are
/// always enabled.
///
/// @param dirnow  Current directory name
/// @param fd  File descriptor to write to
///
/// @return FAIL on error, OK otherwise.
static int makeopens(FILE *fd, char_u *dirnow)
{
  int only_save_windows = true;
  int nr;
  int restore_size = true;
  win_T       *wp;
  char_u      *sname;
  win_T       *edited_win = NULL;
  int tabnr;
  win_T       *tab_firstwin;
  frame_T     *tab_topframe;
  int cur_arg_idx = 0;
  int next_arg_idx = 0;

  if (ssop_flags & SSOP_BUFFERS) {
    only_save_windows = false;  // Save ALL buffers
  }

  // Begin by setting v:this_session, and then other sessionable variables.
  PUTLINE_FAIL("let v:this_session=expand(\"<sfile>:p\")");
  if (ssop_flags & SSOP_GLOBALS) {
    if (store_session_globals(fd) == FAIL) {
      return FAIL;
    }
  }

  // Close all windows and tabs but one.
  PUTLINE_FAIL("silent only");
  if ((ssop_flags & SSOP_TABPAGES)
      && put_line(fd, "silent tabonly") == FAIL) {
    return FAIL;
  }

  //
  // Now a :cd command to the session directory or the current directory
  //
  if (ssop_flags & SSOP_SESDIR) {
    PUTLINE_FAIL("exe \"cd \" . escape(expand(\"<sfile>:p:h\"), ' ')");
  } else if (ssop_flags & SSOP_CURDIR) {
    sname = home_replace_save(NULL, globaldir != NULL ? globaldir : dirnow);
    char *fname_esc = ses_escape_fname((char *)sname, &ssop_flags);
    if (fprintf(fd, "cd %s\n", fname_esc) < 0) {
      xfree(fname_esc);
      xfree(sname);
      return FAIL;
    }
    xfree(fname_esc);
    xfree(sname);
  }

  if (fprintf(fd,
              "%s",
              // If there is an empty, unnamed buffer we will wipe it out later.
              // Remember the buffer number.
              "if expand('%') == '' && !&modified && line('$') <= 1"
              " && getline(1) == ''\n"
              "  let s:wipebuf = bufnr('%')\n"
              "endif\n"
              // Now save the current files, current buffer first.
              "set shortmess=aoO\n") < 0) {
    return FAIL;
  }

  // Now put the other buffers into the buffer list.
  FOR_ALL_BUFFERS(buf) {
    if (!(only_save_windows && buf->b_nwindows == 0)
        && !(buf->b_help && !(ssop_flags & SSOP_HELP))
        && buf->b_fname != NULL
        && buf->b_p_bl) {
      if (fprintf(fd, "badd +%" PRId64 " ",
                  buf->b_wininfo == NULL
                  ? (int64_t)1L
                  : (int64_t)buf->b_wininfo->wi_fpos.lnum) < 0
          || ses_fname(fd, buf, &ssop_flags, true) == FAIL) {
        return FAIL;
      }
    }
  }

  // the global argument list
  if (ses_arglist(fd, "argglobal", &global_alist.al_ga,
                  !(ssop_flags & SSOP_CURDIR), &ssop_flags) == FAIL) {
    return FAIL;
  }

  if (ssop_flags & SSOP_RESIZE) {
    // Note: after the restore we still check it worked!
    if (fprintf(fd, "set lines=%" PRId64 " columns=%" PRId64 "\n",
                (int64_t)Rows, (int64_t)Columns) < 0) {
      return FAIL;
    }
  }

  int restore_stal = false;
  // When there are two or more tabpages and 'showtabline' is 1 the tabline
  // will be displayed when creating the next tab.  That resizes the windows
  // in the first tab, which may cause problems.  Set 'showtabline' to 2
  // temporarily to avoid that.
  if (p_stal == 1 && first_tabpage->tp_next != NULL) {
    PUTLINE_FAIL("set stal=2");
    restore_stal = true;
  }

  //
  // For each tab:
  // - Put windows for each tab, when "tabpages" is in 'sessionoptions'.
  // - Don't use goto_tabpage(), it may change CWD and trigger autocommands.
  //
  tab_firstwin = firstwin;      // First window in tab page "tabnr".
  tab_topframe = topframe;
  if ((ssop_flags & SSOP_TABPAGES)) {
    // Similar to ses_win_rec() below, populate the tab pages first so
    // later local options won't be copied to the new tabs.
    FOR_ALL_TABS(tp) {
      if (tp->tp_next != NULL && put_line(fd, "tabnew") == FAIL) {
        return FAIL;
      }
    }

    if (first_tabpage->tp_next != NULL && put_line(fd, "tabrewind") == FAIL) {
      return FAIL;
    }
  }
  for (tabnr = 1;; tabnr++) {
    tabpage_T *tp = find_tabpage(tabnr);
    if (tp == NULL) {
      break;  // done all tab pages
    }

    bool need_tabnext = false;
    int cnr = 1;

    if ((ssop_flags & SSOP_TABPAGES)) {
      if (tp == curtab) {
        tab_firstwin = firstwin;
        tab_topframe = topframe;
      } else {
        tab_firstwin = tp->tp_firstwin;
        tab_topframe = tp->tp_topframe;
      }
      if (tabnr > 1) {
        need_tabnext = true;
      }
    }

    //
    // Before creating the window layout, try loading one file.  If this
    // is aborted we don't end up with a number of useless windows.
    // This may have side effects! (e.g., compressed or network file).
    //
    for (wp = tab_firstwin; wp != NULL; wp = wp->w_next) {
      if (ses_do_win(wp)
          && wp->w_buffer->b_ffname != NULL
          && !bt_help(wp->w_buffer)
          && !bt_nofile(wp->w_buffer)
          ) {
        if (need_tabnext && put_line(fd, "tabnext") == FAIL) {
          return FAIL;
        }
        need_tabnext = false;

        if (fputs("edit ", fd) < 0
            || ses_fname(fd, wp->w_buffer, &ssop_flags, true) == FAIL) {
          return FAIL;
        }
        if (!wp->w_arg_idx_invalid) {
          edited_win = wp;
        }
        break;
      }
    }

    // If no file got edited create an empty tab page.
    if (need_tabnext && put_line(fd, "tabnext") == FAIL) {
      return FAIL;
    }

    //
    // Save current window layout.
    //
    PUTLINE_FAIL("set splitbelow splitright");
    if (ses_win_rec(fd, tab_topframe) == FAIL) {
      return FAIL;
    }
    if (!p_sb && put_line(fd, "set nosplitbelow") == FAIL) {
      return FAIL;
    }
    if (!p_spr && put_line(fd, "set nosplitright") == FAIL) {
      return FAIL;
    }

    //
    // Check if window sizes can be restored (no windows omitted).
    // Remember the window number of the current window after restoring.
    //
    nr = 0;
    for (wp = tab_firstwin; wp != NULL; wp = wp->w_next) {
      if (ses_do_win(wp)) {
        nr++;
      } else {
        restore_size = false;
      }
      if (curwin == wp) {
        cnr = nr;
      }
    }

    // Go to the first window.
    PUTLINE_FAIL("wincmd t");

    // If more than one window, see if sizes can be restored.
    // First set 'winheight' and 'winwidth' to 1 to avoid the windows being
    // resized when moving between windows.
    // Do this before restoring the view, so that the topline and the
    // cursor can be set.  This is done again below.
    // winminheight and winminwidth need to be set to avoid an error if the
    // user has set winheight or winwidth.
    if (fprintf(fd,
                "set winminheight=0\n"
                "set winheight=1\n"
                "set winminwidth=0\n"
                "set winwidth=1\n") < 0) {
      return FAIL;
    }
    if (nr > 1 && ses_winsizes(fd, restore_size, tab_firstwin) == FAIL) {
      return FAIL;
    }

    //
    // Restore the view of the window (options, file, cursor, etc.).
    //
    for (wp = tab_firstwin; wp != NULL; wp = wp->w_next) {
      if (!ses_do_win(wp)) {
        continue;
      }
      if (put_view(fd, wp, wp != edited_win, &ssop_flags, cur_arg_idx)
          == FAIL) {
        return FAIL;
      }
      if (nr > 1 && put_line(fd, "wincmd w") == FAIL) {
        return FAIL;
      }
      next_arg_idx = wp->w_arg_idx;
    }

    // The argument index in the first tab page is zero, need to set it in
    // each window.  For further tab pages it's the window where we do
    // "tabedit".
    cur_arg_idx = next_arg_idx;

    //
    // Restore cursor to the current window if it's not the first one.
    //
    if (cnr > 1 && (fprintf(fd, "%dwincmd w\n", cnr) < 0)) {
      return FAIL;
    }

    //
    // Restore window sizes again after jumping around in windows, because
    // the current window has a minimum size while others may not.
    //
    if (nr > 1 && ses_winsizes(fd, restore_size, tab_firstwin) == FAIL) {
      return FAIL;
    }

    // Take care of tab-local working directories if applicable
    if (tp->tp_localdir) {
      if (fputs("if exists(':tcd') == 2 | tcd ", fd) < 0
          || ses_put_fname(fd, tp->tp_localdir, &ssop_flags) == FAIL
          || fputs(" | endif\n", fd) < 0) {
        return FAIL;
      }
      did_lcd = true;
    }

    // Don't continue in another tab page when doing only the current one
    // or when at the last tab page.
    if (!(ssop_flags & SSOP_TABPAGES)) {
      break;
    }
  }

  if (ssop_flags & SSOP_TABPAGES) {
    if (fprintf(fd, "tabnext %d\n", tabpage_index(curtab)) < 0) {
      return FAIL;
    }
  }
  if (restore_stal && put_line(fd, "set stal=1") == FAIL) {
    return FAIL;
  }

  //
  // Wipe out an empty unnamed buffer we started in.
  //
  if (fprintf(fd, "%s",
              "if exists('s:wipebuf') "
              "&& len(win_findbuf(s:wipebuf)) == 0"
              "&& getbufvar(s:wipebuf, '&buftype') isnot# 'terminal'\n"
              "  silent exe 'bwipe ' . s:wipebuf\n"
              "endif\n"
              "unlet! s:wipebuf\n") < 0) {
    return FAIL;
  }

  // Re-apply options.
  if (fprintf(fd,
              "set winheight=%" PRId64 " winwidth=%" PRId64
              " winminheight=%" PRId64 " winminwidth=%" PRId64
              " shortmess=%s\n",
              (int64_t)p_wh,
              (int64_t)p_wiw,
              (int64_t)p_wmh,
              (int64_t)p_wmw,
              p_shm) < 0) {
    return FAIL;
  }

  //
  // Lastly, execute the x.vim file if it exists.
  //
  if (fprintf(fd, "%s",
              "let s:sx = expand(\"<sfile>:p:r\").\"x.vim\"\n"
              "if filereadable(s:sx)\n"
              "  exe \"source \" . fnameescape(s:sx)\n"
              "endif\n") < 0) {
    return FAIL;
  }

  return OK;
}

/// ":loadview [nr]"
void ex_loadview(exarg_T *eap)
{
  char *fname = get_view_file(*eap->arg);
  if (fname != NULL) {
    if (do_source((char_u *)fname, false, DOSO_NONE) == FAIL) {
      EMSG2(_(e_notopen), fname);
    }
    xfree(fname);
  }
}

/// ":mkexrc", ":mkvimrc", ":mkview", ":mksession".
///
/// Legacy 'sessionoptions'/'viewoptions' flags are always enabled:
///   - SSOP_UNIX: line-endings are LF
///   - SSOP_SLASH: filenames are written with "/" slash
void ex_mkrc(exarg_T *eap)
{
  FILE        *fd;
  int failed = false;
  int view_session = false;  // :mkview, :mksession
  int using_vdir = false;  // using 'viewdir'?
  char *viewFile = NULL;
  unsigned    *flagp;

  if (eap->cmdidx == CMD_mksession || eap->cmdidx == CMD_mkview) {
    view_session = true;
  }

  // Use the short file name until ":lcd" is used.  We also don't use the
  // short file name when 'acd' is set, that is checked later.
  did_lcd = false;

  char *fname;
  // ":mkview" or ":mkview 9": generate file name with 'viewdir'
  if (eap->cmdidx == CMD_mkview
      && (*eap->arg == NUL
          || (ascii_isdigit(*eap->arg) && eap->arg[1] == NUL))) {
    eap->forceit = true;
    fname = get_view_file(*eap->arg);
    if (fname == NULL) {
      return;
    }
    viewFile = fname;
    using_vdir = true;
  } else if (*eap->arg != NUL) {
    fname = (char *)eap->arg;
  } else if (eap->cmdidx == CMD_mkvimrc) {
    fname = VIMRC_FILE;
  } else if (eap->cmdidx == CMD_mksession) {
    fname = SESSION_FILE;
  } else {
    fname = EXRC_FILE;
  }

  // When using 'viewdir' may have to create the directory.
  if (using_vdir && !os_isdir(p_vdir)) {
    vim_mkdir_emsg((const char *)p_vdir, 0755);
  }

  fd = open_exfile((char_u *)fname, eap->forceit, WRITEBIN);
  if (fd != NULL) {
    if (eap->cmdidx == CMD_mkview) {
      flagp = &vop_flags;
    } else {
      flagp = &ssop_flags;
    }

    // Write the version command for :mkvimrc
    if (eap->cmdidx == CMD_mkvimrc) {
      (void)put_line(fd, "version 6.0");
    }

    if (eap->cmdidx == CMD_mksession) {
      if (put_line(fd, "let SessionLoad = 1") == FAIL) {
        failed = true;
      }
    }

    if (!view_session || (eap->cmdidx == CMD_mksession
                          && (*flagp & SSOP_OPTIONS))) {
      failed |= (makemap(fd, NULL) == FAIL
                 || makeset(fd, OPT_GLOBAL, false) == FAIL);
      if (p_hls && fprintf(fd, "%s", "set hlsearch\n") < 0) {
        failed = true;
      }
    }

    if (!failed && view_session) {
      if (put_line(fd,
                   "let s:so_save = &g:so | let s:siso_save = &g:siso"
                   " | setg so=0 siso=0 | setl so=-1 siso=-1") == FAIL) {
        failed = true;
      }
      if (eap->cmdidx == CMD_mksession) {
        char_u *dirnow;  // current directory

        dirnow = xmalloc(MAXPATHL);
        //
        // Change to session file's dir.
        //
        if (os_dirname(dirnow, MAXPATHL) == FAIL
            || os_chdir((char *)dirnow) != 0) {
          *dirnow = NUL;
        }
        if (*dirnow != NUL && (ssop_flags & SSOP_SESDIR)) {
          if (vim_chdirfile((char_u *)fname) == OK) {
            shorten_fnames(true);
          }
        } else if (*dirnow != NUL
                   && (ssop_flags & SSOP_CURDIR) && globaldir != NULL) {
          if (os_chdir((char *)globaldir) == 0) {
            shorten_fnames(true);
          }
        }

        failed |= (makeopens(fd, dirnow) == FAIL);

        // restore original dir
        if (*dirnow != NUL && ((ssop_flags & SSOP_SESDIR)
                               || ((ssop_flags & SSOP_CURDIR) && globaldir !=
                                   NULL))) {
          if (os_chdir((char *)dirnow) != 0) {
            EMSG(_(e_prev_dir));
          }
          shorten_fnames(true);
          // restore original dir
          if (*dirnow != NUL && ((ssop_flags & SSOP_SESDIR)
                                 || ((ssop_flags & SSOP_CURDIR) && globaldir !=
                                     NULL))) {
            if (os_chdir((char *)dirnow) != 0) {
              EMSG(_(e_prev_dir));
            }
            shorten_fnames(true);
          }
        }
        xfree(dirnow);
      } else {
        failed |= (put_view(fd, curwin, !using_vdir, flagp, -1) == FAIL);
      }
      if (fprintf(fd,
                  "%s",
                  "let &g:so = s:so_save | let &g:siso = s:siso_save\n")
          < 0) {
        failed = true;
      }
      if (no_hlsearch && fprintf(fd, "%s", "nohlsearch\n") < 0) {
        failed = true;
      }
      if (fprintf(fd, "%s", "doautoall SessionLoadPost\n") < 0) {
        failed = true;
      }
      if (eap->cmdidx == CMD_mksession) {
        if (fprintf(fd, "unlet SessionLoad\n") < 0) {
          failed = true;
        }
      }
    }
    if (put_line(fd, "\" vim: set ft=vim :") == FAIL) {
      failed = true;
    }

    failed |= fclose(fd);

    if (failed) {
      EMSG(_(e_write));
    } else if (eap->cmdidx == CMD_mksession) {
      // successful session write - set v:this_session
      char *const tbuf = xmalloc(MAXPATHL);
      if (vim_FullName(fname, tbuf, MAXPATHL, false) == OK) {
        set_vim_var_string(VV_THIS_SESSION, tbuf, -1);
      }
      xfree(tbuf);
    }
  }

  xfree(viewFile);
}

/// Get the name of the view file for the current buffer.
static char *get_view_file(int c)
{
  if (curbuf->b_ffname == NULL) {
    EMSG(_(e_noname));
    return NULL;
  }
  char *sname = (char *)home_replace_save(NULL, curbuf->b_ffname);

  // We want a file name without separators, because we're not going to make
  // a directory.
  //    "normal" path separator   -> "=+"
  //    "="                       -> "=="
  //    ":" path separator        -> "=-"
  size_t len = 0;
  for (char *p = sname; *p; p++) {
    if (*p == '=' || vim_ispathsep(*p)) {
      len++;
    }
  }
  char *retval = xmalloc(strlen(sname) + len + STRLEN(p_vdir) + 9);
  STRCPY(retval, p_vdir);
  add_pathsep(retval);
  char *s = retval + strlen(retval);
  for (char *p = sname; *p; p++) {
    if (*p == '=') {
      *s++ = '=';
      *s++ = '=';
    } else if (vim_ispathsep(*p)) {
      *s++ = '=';
#if defined(BACKSLASH_IN_FILENAME)
      *s++ = (*p == ':') ? '-' : '+';
#else
      *s++ = '+';
#endif
    } else {
      *s++ = *p;
    }
  }
  *s++ = '=';
  assert(c >= CHAR_MIN && c <= CHAR_MAX);
  *s++ = (char)c;
  xstrlcpy(s, ".vim", 5);

  xfree(sname);
  return retval;
}

// TODO(justinmk): remove this, not needed after 5ba3cecb68cd.
int put_eol(FILE *fd)
{
  if (putc('\n', fd) < 0) {
    return FAIL;
  }
  return OK;
}

// TODO(justinmk): remove this, not needed after 5ba3cecb68cd.
int put_line(FILE *fd, char *s)
{
  if (fprintf(fd, "%s\n", s) < 0) {
    return FAIL;
  }
  return OK;
}
