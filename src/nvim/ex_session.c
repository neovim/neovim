// Functions for creating a session file, i.e. implementing:
//   :mkexrc
//   :mkvimrc
//   :mkview
//   :mksession

#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#include "nvim/arglist.h"
#include "nvim/arglist_defs.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/ex_session.h"
#include "nvim/file_search.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/garray_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/macros_defs.h"
#include "nvim/mapping.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/path.h"
#include "nvim/pos_defs.h"
#include "nvim/runtime.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"
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

static int ses_winsizes(FILE *fd, bool restore_size, win_T *tab_firstwin)
{
  if (restore_size && (ssop_flags & kOptSsopFlagWinsize)) {
    int n = 0;
    for (win_T *wp = tab_firstwin; wp != NULL; wp = wp->w_next) {
      if (!ses_do_win(wp)) {
        continue;
      }
      n++;

      // restore height when not full height
      if (wp->w_height + wp->w_hsep_height + wp->w_status_height < topframe->fr_height
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

/// Write commands to "fd" to recursively create windows for frame "fr",
/// horizontally and vertically split.
/// After the commands the last window in the frame is the current window.
///
/// @return  FAIL when writing the commands to "fd" fails.
static int ses_win_rec(FILE *fd, frame_T *fr)
{
  int count = 0;

  if (fr->fr_layout == FR_LEAF) {
    return OK;
  }

  // Find first frame that's not skipped and then create a window for
  // each following one (first frame is already there).
  frame_T *frc = ses_skipframe(fr->fr_child);
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

  return OK;
}

/// Skip frames that don't contain windows we want to save in the Session.
///
/// @return  NULL when there none.
static frame_T *ses_skipframe(frame_T *fr)
{
  frame_T *frc;

  FOR_ALL_FRAMES(frc, fr) {
    if (ses_do_frame(frc)) {
      break;
    }
  }
  return frc;
}

/// @return  true if frame "fr" has a window somewhere that we want to save in
///          the Session.
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

/// @return  non-zero if window "wp" is to be stored in the Session.
static int ses_do_win(win_T *wp)
{
  // Skip floating windows to avoid issues when restoring the Session. #18432
  if (wp->w_floating) {
    return false;
  }
  if (wp->w_buffer->b_fname == NULL
      // When 'buftype' is "nofile" can't restore the window contents.
      || (!wp->w_buffer->terminal && bt_nofilename(wp->w_buffer))) {
    return ssop_flags & kOptSsopFlagBlank;
  }
  if (bt_help(wp->w_buffer)) {
    return ssop_flags & kOptSsopFlagHelp;
  }
  if (bt_terminal(wp->w_buffer)) {
    return ssop_flags & kOptSsopFlagTerminal;
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
static int ses_arglist(FILE *fd, char *cmd, garray_T *gap, bool fullname, unsigned *flagp)
{
  char *buf = NULL;

  if (fprintf(fd, "%s\n%s\n", cmd, "%argdel") < 0) {
    return FAIL;
  }
  for (int i = 0; i < gap->ga_len; i++) {
    // NULL file names are skipped (only happens when out of memory).
    char *s = alist_name(&((aentry_T *)gap->ga_data)[i]);
    if (s != NULL) {
      if (fullname) {
        buf = xmalloc(MAXPATHL);
        vim_FullName(s, buf, MAXPATHL, false);
        s = buf;
      }
      char *fname_esc = ses_escape_fname(s, flagp);
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

/// @return  the buffer name for `buf`.
static char *ses_get_fname(buf_T *buf, const unsigned *flagp)
{
  // Use the short file name if the current directory is known at the time
  // the session file will be sourced.
  // Don't do this for ":mkview", we don't know the current directory.
  // Don't do this after ":lcd", we don't keep track of what the current
  // directory is.
  if (buf->b_sfname != NULL
      && flagp == &ssop_flags
      && (ssop_flags & (kOptSsopFlagCurdir | kOptSsopFlagSesdir))
      && !p_acd
      && !did_lcd) {
    return buf->b_sfname;
  }
  return buf->b_ffname;
}

/// Write a buffer name to the session file.
/// Also ends the line, if "add_eol" is true.
///
/// @return  FAIL if writing fails.
static int ses_fname(FILE *fd, buf_T *buf, unsigned *flagp, bool add_eol)
{
  char *name = ses_get_fname(buf, flagp);
  if (ses_put_fname(fd, name, flagp) == FAIL
      || (add_eol && fprintf(fd, "\n") < 0)) {
    return FAIL;
  }
  return OK;
}

/// Escapes a filename for session writing.
/// Takes care of "slash" flag in 'sessionoptions' and escapes special
/// characters.
///
/// @return  allocated string or NULL.
static char *ses_escape_fname(char *name, unsigned *flagp)
{
  char *p;
  char *sname = home_replace_save(NULL, name);

  // Always kOptSsopFlagSlash: change all backslashes to forward slashes.
  for (p = sname; *p != NUL; MB_PTR_ADV(p)) {
    if (*p == '\\') {
      *p = '/';
    }
  }

  // Escape special characters.
  p = vim_strsave_fnameescape(sname, VSE_NONE);
  xfree(sname);
  return p;
}

/// Write a file name to the session file.
/// Takes care of the "slash" option in 'sessionoptions' and escapes special
/// characters.
///
/// @return  FAIL if writing fails.
static int ses_put_fname(FILE *fd, char *name, unsigned *flagp)
{
  char *p = ses_escape_fname(name, flagp);
  bool retval = fputs(p, fd) < 0 ? FAIL : OK;
  xfree(p);
  return retval;
}

/// Write commands to "fd" to restore the view of a window.
/// Caller must make sure 'scrolloff' is zero.
///
/// @param add_edit  add ":edit" command to view
/// @param flagp  vop_flags or ssop_flags
/// @param current_arg_idx  current argument index of the window, use -1 if unknown
static int put_view(FILE *fd, win_T *wp, int add_edit, unsigned *flagp, int current_arg_idx)
{
  int f;
  bool did_next = false;

  // Always restore cursor position for ":mksession".  For ":mkview" only
  // when 'viewoptions' contains "cursor".
  bool do_cursor = (flagp == &ssop_flags || *flagp & kOptSsopFlagCursor);

  // Local argument list.
  if (wp->w_alist == &global_alist) {
    PUTLINE_FAIL("argglobal");
  } else {
    if (ses_arglist(fd, "arglocal", &wp->w_alist->al_ga,
                    flagp == &vop_flags
                    || !(*flagp & kOptSsopFlagCurdir)
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
    char *fname_esc = ses_escape_fname(ses_get_fname(wp->w_buffer, flagp), flagp);
    if (bt_help(wp->w_buffer)) {
      char *curtag = "";

      // A help buffer needs some options to be set.
      // First, create a new empty buffer with "buftype=help".
      // Then ":help" will re-use both the buffer and the window and set
      // the options, even when "options" is not in 'sessionoptions'.
      if (0 < wp->w_tagstackidx && wp->w_tagstackidx <= wp->w_tagstacklen) {
        curtag = wp->w_tagstack[wp->w_tagstackidx - 1].tagname;
      }

      if (put_line(fd, "enew | setl bt=help") == FAIL
          || fprintf(fd, "help %s", curtag) < 0 || put_eol(fd) == FAIL) {
        xfree(fname_esc);
        return FAIL;
      }
    } else if (wp->w_buffer->b_ffname != NULL
               && (!bt_nofilename(wp->w_buffer) || wp->w_buffer->terminal)) {
      // Load the file.

      // Editing a file in this buffer: use ":edit file".
      // This may have side effects! (e.g., compressed or network file).
      //
      // Note, if a buffer for that file already exists, use :badd to
      // edit that buffer, to not lose folding information (:edit resets
      // folds in other buffers)
      if (fprintf(fd,
                  "if bufexists(fnamemodify(\"%s\", \":p\")) | buffer %s | else | edit %s | endif\n"
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
        // do not set balt if buffer is terminal and "terminal" is not set in options
        && !(bt_terminal(alt) && !(ssop_flags & kOptSsopFlagTerminal))
        && (fputs("balt ", fd) < 0
            || ses_fname(fd, alt, flagp, true) == FAIL)) {
      return FAIL;
    }
  }

  // Local mappings and abbreviations.
  if ((*flagp & (kOptSsopFlagOptions | kOptSsopFlagLocaloptions))
      && makemap(fd, wp->w_buffer) == FAIL) {
    return FAIL;
  }

  // Local options.  Need to go to the window temporarily.
  // Store only local values when using ":mkview" and when ":mksession" is
  // used and 'sessionoptions' doesn't include "nvim/options".
  // Some folding options are always stored when "folds" is included,
  // otherwise the folds would not be restored correctly.
  win_T *save_curwin = curwin;
  curwin = wp;
  curbuf = curwin->w_buffer;
  if (*flagp & (kOptSsopFlagOptions | kOptSsopFlagLocaloptions)) {
    f = makeset(fd, OPT_LOCAL,
                flagp == &vop_flags || !(*flagp & kOptSsopFlagOptions));
  } else if (*flagp & kOptSsopFlagFolds) {
    f = makefoldset(fd);
  } else {
    f = OK;
  }
  curwin = save_curwin;
  curbuf = curwin->w_buffer;
  if (f == FAIL) {
    return FAIL;
  }

  // Save Folds when 'buftype' is empty and for help files.
  if ((*flagp & kOptSsopFlagFolds)
      && wp->w_buffer->b_ffname != NULL
      && (bt_normal(wp->w_buffer)
          || bt_help(wp->w_buffer))) {
    if (put_folds(fd, wp) == FAIL) {
      return FAIL;
    }
  }

  // Set the cursor after creating folds, since that moves the cursor.
  if (do_cursor) {
    // Restore the cursor line in the file and relatively in the
    // window.  Don't use "G", it changes the jumplist.
    if (wp->w_height_inner <= 0) {
      if (fprintf(fd, "let s:l = %" PRIdLINENR "\n", wp->w_cursor.lnum) < 0) {
        return FAIL;
      }
    } else if (fprintf(fd,
                       "let s:l = %" PRIdLINENR " - ((%" PRIdLINENR
                       " * winheight(0) + %d) / %d)\n",
                       wp->w_cursor.lnum,
                       wp->w_cursor.lnum - wp->w_topline,
                       (wp->w_height_inner / 2),
                       wp->w_height_inner) < 0) {
      return FAIL;
    }
    if (fprintf(fd,
                "if s:l < 1 | let s:l = 1 | endif\n"
                "keepjumps exe s:l\n"
                "normal! zt\n"
                "keepjumps %" PRIdLINENR "\n",
                wp->w_cursor.lnum) < 0) {
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

  // Local directory, if the current flag is not view options or the "curdir"
  // option is included.
  if (wp->w_localdir != NULL
      && (flagp != &vop_flags || (*flagp & kOptSsopFlagCurdir))) {
    if (fputs("lcd ", fd) < 0
        || ses_put_fname(fd, wp->w_localdir, flagp) == FAIL
        || fprintf(fd, "\n") < 0) {
      return FAIL;
    }
    did_lcd = true;
  }

  return OK;
}

static int store_session_globals(FILE *fd)
{
  TV_DICT_ITER(&globvardict, this_var, {
    if ((this_var->di_tv.v_type == VAR_NUMBER
         || this_var->di_tv.v_type == VAR_STRING)
        && var_flavour(this_var->di_key) == VAR_FLAVOUR_SESSION) {
      // Escape special characters with a backslash.  Turn a LF and
      // CR into \n and \r.
      char *const p = vim_strsave_escaped(tv_get_string(&this_var->di_tv), "\\\"\n\r");
      for (char *t = p; *t != NUL; t++) {
        if (*t == '\n') {
          *t = 'n';
        } else if (*t == '\r') {
          *t = 'r';
        }
      }
      if ((fprintf(fd, "let %s = %c%s%c",
                   this_var->di_key,
                   ((this_var->di_tv.v_type == VAR_STRING) ? '"' : ' '),
                   p,
                   ((this_var->di_tv.v_type == VAR_STRING) ? '"' : ' ')) < 0)
          || put_eol(fd) == FAIL) {
        xfree(p);
        return FAIL;
      }
      xfree(p);
    } else if (this_var->di_tv.v_type == VAR_FLOAT
               && var_flavour(this_var->di_key) == VAR_FLAVOUR_SESSION) {
      float_T f = this_var->di_tv.vval.v_float;
      int sign = ' ';

      if (f < 0) {
        f = -f;
        sign = '-';
      }
      if ((fprintf(fd, "let %s = %c%f", this_var->di_key, sign, f) < 0)
          || put_eol(fd) == FAIL) {
        return FAIL;
      }
    }
  });
  return OK;
}

/// Writes commands for restoring the current buffers, for :mksession.
///
/// Legacy 'sessionoptions'/'viewoptions' flags kOptSsopFlagUnix, kOptSsopFlagSlash are
/// always enabled.
///
/// @param dirnow  Current directory name
/// @param fd  File descriptor to write to
///
/// @return FAIL on error, OK otherwise.
static int makeopens(FILE *fd, char *dirnow)
{
  bool only_save_windows = true;
  bool restore_size = true;
  win_T *edited_win = NULL;
  win_T *tab_firstwin;
  frame_T *tab_topframe;
  int cur_arg_idx = 0;
  int next_arg_idx = 0;

  if (ssop_flags & kOptSsopFlagBuffers) {
    only_save_windows = false;  // Save ALL buffers
  }

  // Begin by setting v:this_session, and then other sessionable variables.
  PUTLINE_FAIL("let v:this_session=expand(\"<sfile>:p\")");
  if (ssop_flags & kOptSsopFlagGlobals) {
    if (store_session_globals(fd) == FAIL) {
      return FAIL;
    }
  }

  // Close all windows and tabs but one.
  PUTLINE_FAIL("silent only");
  if ((ssop_flags & kOptSsopFlagTabpages)
      && put_line(fd, "silent tabonly") == FAIL) {
    return FAIL;
  }

  // Now a :cd command to the session directory or the current directory
  if (ssop_flags & kOptSsopFlagSesdir) {
    PUTLINE_FAIL("exe \"cd \" . escape(expand(\"<sfile>:p:h\"), ' ')");
  } else if (ssop_flags & kOptSsopFlagCurdir) {
    char *sname = home_replace_save(NULL, globaldir != NULL ? globaldir : dirnow);
    char *fname_esc = ses_escape_fname(sname, &ssop_flags);
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
              "endif\n") < 0) {
    return FAIL;
  }

  // save 'shortmess' if not storing options
  if ((ssop_flags & kOptSsopFlagOptions) == 0) {
    PUTLINE_FAIL("let s:shortmess_save = &shortmess");
  }

  // set 'shortmess' for the following.  Add the 'A' flag if it was there
  PUTLINE_FAIL("if &shortmess =~ 'A'");
  PUTLINE_FAIL("  set shortmess=aoOA");
  PUTLINE_FAIL("else");
  PUTLINE_FAIL("  set shortmess=aoO");
  PUTLINE_FAIL("endif");

  // Now save the current files, current buffer first.
  // Put all buffers into the buffer list.
  // Do it very early to preserve buffer order after loading session (which
  // can be disrupted by prior `edit` or `tabedit` calls).
  FOR_ALL_BUFFERS(buf) {
    if (!(only_save_windows && buf->b_nwindows == 0)
        && !(buf->b_help && !(ssop_flags & kOptSsopFlagHelp))
        && !(bt_terminal(buf) && !(ssop_flags & kOptSsopFlagTerminal))
        && buf->b_fname != NULL
        && buf->b_p_bl) {
      if (fprintf(fd, "badd +%" PRId64 " ",
                  buf->b_wininfo == NULL
                  ? 1
                  : (int64_t)buf->b_wininfo->wi_mark.mark.lnum) < 0
          || ses_fname(fd, buf, &ssop_flags, true) == FAIL) {
        return FAIL;
      }
    }
  }

  // the global argument list
  if (ses_arglist(fd, "argglobal", &global_alist.al_ga,
                  !(ssop_flags & kOptSsopFlagCurdir), &ssop_flags) == FAIL) {
    return FAIL;
  }

  if (ssop_flags & kOptSsopFlagResize) {
    // Note: after the restore we still check it worked!
    if (fprintf(fd, "set lines=%" PRId64 " columns=%" PRId64 "\n",
                (int64_t)Rows, (int64_t)Columns) < 0) {
      return FAIL;
    }
  }

  bool restore_stal = false;
  // When there are two or more tabpages and 'showtabline' is 1 the tabline
  // will be displayed when creating the next tab.  That resizes the windows
  // in the first tab, which may cause problems.  Set 'showtabline' to 2
  // temporarily to avoid that.
  if (p_stal == 1 && first_tabpage->tp_next != NULL) {
    PUTLINE_FAIL("set stal=2");
    restore_stal = true;
  }

  if ((ssop_flags & kOptSsopFlagTabpages)) {
    // "tabpages" is in 'sessionoptions': Similar to ses_win_rec() below,
    // populate the tab pages first so later local options won't be copied
    // to the new tabs.
    FOR_ALL_TABS(tp) {
      // Use `bufhidden=wipe` to remove empty "placeholder" buffers once
      // they are not needed. This prevents creating extra buffers (see
      // cause of Vim patch 8.1.0829)
      if (tp->tp_next != NULL && put_line(fd, "tabnew +setlocal\\ bufhidden=wipe") == FAIL) {
        return FAIL;
      }
    }

    if (first_tabpage->tp_next != NULL && put_line(fd, "tabrewind") == FAIL) {
      return FAIL;
    }
  }

  // Assume "tabpages" is in 'sessionoptions'.  If not then we only do
  // "curtab" and bail out of the loop.
  FOR_ALL_TABS(tp) {
    bool need_tabnext = false;
    int cnr = 1;

    // May repeat putting Windows for each tab, when "tabpages" is in
    // 'sessionoptions'.
    // Don't use goto_tabpage(), it may change directory and trigger
    // autocommands.
    if ((ssop_flags & kOptSsopFlagTabpages)) {
      if (tp == curtab) {
        tab_firstwin = firstwin;
        tab_topframe = topframe;
      } else {
        tab_firstwin = tp->tp_firstwin;
        tab_topframe = tp->tp_topframe;
      }
      if (tp != first_tabpage) {
        need_tabnext = true;
      }
    } else {
      tp = curtab;
      tab_firstwin = firstwin;
      tab_topframe = topframe;
    }

    // Before creating the window layout, try loading one file.  If this
    // is aborted we don't end up with a number of useless windows.
    // This may have side effects! (e.g., compressed or network file).
    for (win_T *wp = tab_firstwin; wp != NULL; wp = wp->w_next) {
      if (ses_do_win(wp)
          && wp->w_buffer->b_ffname != NULL
          && !bt_help(wp->w_buffer)
          && !bt_nofilename(wp->w_buffer)) {
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

    if (tab_topframe->fr_layout != FR_LEAF) {
      // Save current window layout.
      PUTLINE_FAIL("let s:save_splitbelow = &splitbelow");
      PUTLINE_FAIL("let s:save_splitright = &splitright");
      PUTLINE_FAIL("set splitbelow splitright");
      if (ses_win_rec(fd, tab_topframe) == FAIL) {
        return FAIL;
      }
      PUTLINE_FAIL("let &splitbelow = s:save_splitbelow");
      PUTLINE_FAIL("let &splitright = s:save_splitright");
    }

    // Check if window sizes can be restored (no windows omitted).
    // Remember the window number of the current window after restoring.
    int nr = 0;
    for (win_T *wp = tab_firstwin; wp != NULL; wp = wp->w_next) {
      if (ses_do_win(wp)) {
        nr++;
      } else {
        restore_size = false;
      }
      if (curwin == wp) {
        cnr = nr;
      }
    }

    if (tab_firstwin != NULL && tab_firstwin->w_next != NULL) {
      // Go to the first window.
      PUTLINE_FAIL("wincmd t");

      // If more than one window, see if sizes can be restored.
      // First set 'winheight' and 'winwidth' to 1 to avoid the windows
      // being resized when moving between windows.
      // Do this before restoring the view, so that the topline and the
      // cursor can be set.  This is done again below.
      // winminheight and winminwidth need to be set to avoid an error if
      // the user has set winheight or winwidth.
      PUTLINE_FAIL("let s:save_winminheight = &winminheight");
      PUTLINE_FAIL("let s:save_winminwidth = &winminwidth");
      if (fprintf(fd,
                  "set winminheight=0\n"
                  "set winheight=1\n"
                  "set winminwidth=0\n"
                  "set winwidth=1\n") < 0) {
        return FAIL;
      }
    }
    if (nr > 1 && ses_winsizes(fd, restore_size, tab_firstwin) == FAIL) {
      return FAIL;
    }

    // Restore the tab-local working directory if specified
    // Do this before the windows, so that the window-local directory can
    // override the tab-local directory.
    if ((ssop_flags & kOptSsopFlagCurdir) && tp->tp_localdir != NULL) {
      if (fputs("tcd ", fd) < 0
          || ses_put_fname(fd, tp->tp_localdir, &ssop_flags) == FAIL
          || put_eol(fd) == FAIL) {
        return FAIL;
      }
      did_lcd = true;
    }

    // Restore the view of the window (options, file, cursor, etc.).
    for (win_T *wp = tab_firstwin; wp != NULL; wp = wp->w_next) {
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

    // Restore cursor to the current window if it's not the first one.
    if (cnr > 1 && (fprintf(fd, "%dwincmd w\n", cnr) < 0)) {
      return FAIL;
    }

    // Restore window sizes again after jumping around in windows, because
    // the current window has a minimum size while others may not.
    if (nr > 1 && ses_winsizes(fd, restore_size, tab_firstwin) == FAIL) {
      return FAIL;
    }

    // Don't continue in another tab page when doing only the current one
    // or when at the last tab page.
    if (!(ssop_flags & kOptSsopFlagTabpages)) {
      break;
    }
  }

  if (ssop_flags & kOptSsopFlagTabpages) {
    if (fprintf(fd, "tabnext %d\n", tabpage_index(curtab)) < 0) {
      return FAIL;
    }
  }
  if (restore_stal && put_line(fd, "set stal=1") == FAIL) {
    return FAIL;
  }

  // Wipe out an empty unnamed buffer we started in.
  if (fprintf(fd, "%s",
              "if exists('s:wipebuf') "
              "&& len(win_findbuf(s:wipebuf)) == 0 "
              "&& getbufvar(s:wipebuf, '&buftype') isnot# 'terminal'\n"
              "  silent exe 'bwipe ' . s:wipebuf\n"
              "endif\n"
              "unlet! s:wipebuf\n") < 0) {
    return FAIL;
  }

  // Re-apply 'winheight' and 'winwidth'.
  if (fprintf(fd, "set winheight=%" PRId64 " winwidth=%" PRId64 "\n",
              (int64_t)p_wh, (int64_t)p_wiw) < 0) {
    return FAIL;
  }

  // Restore 'shortmess'.
  if (ssop_flags & kOptSsopFlagOptions) {
    if (fprintf(fd, "set shortmess=%s\n", p_shm) < 0) {
      return FAIL;
    }
  } else {
    PUTLINE_FAIL("let &shortmess = s:shortmess_save");
  }

  if (tab_firstwin != NULL && tab_firstwin->w_next != NULL) {
    // Restore 'winminheight' and 'winminwidth'.
    PUTLINE_FAIL("let &winminheight = s:save_winminheight");
    PUTLINE_FAIL("let &winminwidth = s:save_winminwidth");
  }

  // Lastly, execute the x.vim file if it exists.
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
  if (fname == NULL) {
    return;
  }

  if (do_source(fname, false, DOSO_NONE, NULL) == FAIL) {
    semsg(_(e_notopen), fname);
  }
  xfree(fname);
}

/// ":mkexrc", ":mkvimrc", ":mkview", ":mksession".
///
/// Legacy 'sessionoptions'/'viewoptions' flags are always enabled:
///   - kOptSsopFlagUnix: line-endings are LF
///   - kOptSsopFlagSlash: filenames are written with "/" slash
void ex_mkrc(exarg_T *eap)
{
  bool view_session = false;  // :mkview, :mksession
  int using_vdir = false;  // using 'viewdir'?
  char *viewFile = NULL;

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
    fname = eap->arg;
  } else if (eap->cmdidx == CMD_mkvimrc) {
    fname = VIMRC_FILE;
  } else if (eap->cmdidx == CMD_mksession) {
    fname = SESSION_FILE;
  } else {
    fname = EXRC_FILE;
  }

  // When using 'viewdir' may have to create the directory.
  if (using_vdir && !os_isdir(p_vdir)) {
    vim_mkdir_emsg(p_vdir, 0755);
  }

  FILE *fd = open_exfile(fname, eap->forceit, WRITEBIN);
  if (fd != NULL) {
    bool failed = false;
    unsigned *flagp;
    if (eap->cmdidx == CMD_mkview) {
      flagp = &vop_flags;
    } else {
      flagp = &ssop_flags;
    }

    // Write the version command for :mkvimrc
    if (eap->cmdidx == CMD_mkvimrc) {
      put_line(fd, "version 6.0");
    }

    if (eap->cmdidx == CMD_mksession) {
      if (put_line(fd, "let SessionLoad = 1") == FAIL) {
        failed = true;
      }
    }

    if (!view_session || (eap->cmdidx == CMD_mksession
                          && (*flagp & kOptSsopFlagOptions))) {
      int flags = OPT_GLOBAL;

      if (eap->cmdidx == CMD_mksession && (*flagp & kOptSsopFlagSkiprtp)) {
        flags |= OPT_SKIPRTP;
      }
      failed |= (makemap(fd, NULL) == FAIL
                 || makeset(fd, flags, false) == FAIL);
    }

    if (!failed && view_session) {
      if (put_line(fd,
                   "let s:so_save = &g:so | let s:siso_save = &g:siso"
                   " | setg so=0 siso=0 | setl so=-1 siso=-1") == FAIL) {
        failed = true;
      }
      if (eap->cmdidx == CMD_mksession) {
        char *dirnow;  // current directory

        dirnow = xmalloc(MAXPATHL);

        // Change to session file's dir.
        if (os_dirname(dirnow, MAXPATHL) == FAIL
            || os_chdir(dirnow) != 0) {
          *dirnow = NUL;
        }
        if (*dirnow != NUL && (ssop_flags & kOptSsopFlagSesdir)) {
          if (vim_chdirfile(fname, kCdCauseOther) == OK) {
            shorten_fnames(true);
          }
        } else if (*dirnow != NUL
                   && (ssop_flags & kOptSsopFlagCurdir) && globaldir != NULL) {
          if (os_chdir(globaldir) == 0) {
            shorten_fnames(true);
          }
        }

        failed |= (makeopens(fd, dirnow) == FAIL);

        // restore original dir
        if (*dirnow != NUL && ((ssop_flags & kOptSsopFlagSesdir)
                               || ((ssop_flags & kOptSsopFlagCurdir) && globaldir !=
                                   NULL))) {
          if (os_chdir(dirnow) != 0) {
            emsg(_(e_prev_dir));
          }
          shorten_fnames(true);
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
      if (p_hls && fprintf(fd, "%s", "set hlsearch\n") < 0) {
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
      emsg(_(e_write));
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

  apply_autocmds(EVENT_SESSIONWRITEPOST, NULL, NULL, false, curbuf);
}

/// @return  the name of the view file for the current buffer.
static char *get_view_file(char c)
{
  if (curbuf->b_ffname == NULL) {
    emsg(_(e_noname));
    return NULL;
  }
  char *sname = home_replace_save(NULL, curbuf->b_ffname);

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
  char *retval = xmalloc(strlen(sname) + len + strlen(p_vdir) + 9);
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
  *s++ = c;
  xmemcpyz(s, S_LEN(".vim"));

  xfree(sname);
  return retval;
}

/// TODO(justinmk): remove this, not needed after 5ba3cecb68cd.
int put_eol(FILE *fd)
{
  if (putc('\n', fd) < 0) {
    return FAIL;
  }
  return OK;
}

/// TODO(justinmk): remove this, not needed after 5ba3cecb68cd.
int put_line(FILE *fd, char *s)
{
  if (fprintf(fd, "%s\n", s) < 0) {
    return FAIL;
  }
  return OK;
}
