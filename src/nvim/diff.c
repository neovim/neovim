// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// @file diff.c
///
/// Code for diff'ing two, three or four buffers.

#include <inttypes.h>
#include <stdbool.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/diff.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_docmd.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/path.h"
#include "nvim/screen.h"
#include "nvim/strings.h"
#include "nvim/undo.h"
#include "nvim/window.h"
#include "nvim/os/os.h"
#include "nvim/os/shell.h"

static int diff_busy = FALSE;    // ex_diffgetput() is busy

// Flags obtained from the 'diffopt' option
#define DIFF_FILLER     1        // display filler lines
#define DIFF_ICASE      2        // ignore case
#define DIFF_IWHITE     4        // ignore change in white space
#define DIFF_HORIZONTAL 8        // horizontal splits
#define DIFF_VERTICAL   16       // vertical splits
static int diff_flags = DIFF_FILLER;

#define LBUFLEN 50               // length of line in diff file

// TRUE when "diff -a" works, FALSE when it doesn't work, MAYBE when not
// checked yet
static int diff_a_works = MAYBE;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "diff.c.generated.h"
#endif

/// Called when deleting or unloading a buffer: No longer make a diff with it.
///
/// @param buf
void diff_buf_delete(buf_T *buf)
{
  FOR_ALL_TABS(tp) {
    int i = diff_buf_idx_tp(buf, tp);

    if (i != DB_COUNT) {
      tp->tp_diffbuf[i] = NULL;
      tp->tp_diff_invalid = TRUE;

      if (tp == curtab) {
        diff_redraw(TRUE);
      }
    }
  }
}

/// Check if the current buffer should be added to or removed from the list of
/// diff buffers.
///
/// @param win
void diff_buf_adjust(win_T *win)
{

  if (!win->w_p_diff) {
    // When there is no window showing a diff for this buffer, remove
    // it from the diffs.
    bool found_win = false;
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if ((wp->w_buffer == win->w_buffer) && wp->w_p_diff) {
        found_win = true;
      }
    }

    if (!found_win) {
      int i = diff_buf_idx(win->w_buffer);
      if (i != DB_COUNT) {
        curtab->tp_diffbuf[i] = NULL;
        curtab->tp_diff_invalid = TRUE;
        diff_redraw(TRUE);
      }
    }
  } else {
    diff_buf_add(win->w_buffer);
  }
}

/// Add a buffer to make diffs for.
///
/// Call this when a new buffer is being edited in the current window where
/// 'diff' is set.
/// Marks the current buffer as being part of the diff and requiring updating.
/// This must be done before any autocmd, because a command may use info
/// about the screen contents.
///
/// @param buf The buffer to add.
void diff_buf_add(buf_T *buf)
{
  if (diff_buf_idx(buf) != DB_COUNT) {
    // It's already there.
    return;
  }

  int i;
  for (i = 0; i < DB_COUNT; ++i) {
    if (curtab->tp_diffbuf[i] == NULL) {
      curtab->tp_diffbuf[i] = buf;
      curtab->tp_diff_invalid = TRUE;
      diff_redraw(TRUE);
      return;
    }
  }

  EMSGN(_("E96: Cannot diff more than %" PRId64 " buffers"), DB_COUNT);
}

///
/// Remove all buffers to make diffs for.
///
static void diff_buf_clear(void)
{
  for (int i = 0; i < DB_COUNT; i++) {
    if (curtab->tp_diffbuf[i] != NULL) {
      curtab->tp_diffbuf[i] = NULL;
      curtab->tp_diff_invalid = true;
      diff_redraw(true);
    }
  }
}

/// Find buffer "buf" in the list of diff buffers for the current tab page.
///
/// @param buf The buffer to find.
///
/// @return Its index or DB_COUNT if not found.
static int diff_buf_idx(buf_T *buf)
{
  int idx;
  for (idx = 0; idx < DB_COUNT; ++idx) {
    if (curtab->tp_diffbuf[idx] == buf) {
      break;
    }
  }
  return idx;
}

/// Find buffer "buf" in the list of diff buffers for tab page "tp".
///
/// @param buf
/// @param tp
///
/// @return its index or DB_COUNT if not found.
static int diff_buf_idx_tp(buf_T *buf, tabpage_T *tp)
{
  int idx;
  for (idx = 0; idx < DB_COUNT; ++idx) {
    if (tp->tp_diffbuf[idx] == buf) {
      break;
    }
  }
  return idx;
}

/// Mark the diff info involving buffer "buf" as invalid, it will be updated
/// when info is requested.
///
/// @param buf
void diff_invalidate(buf_T *buf)
{
  FOR_ALL_TABS(tp) {
    int i = diff_buf_idx_tp(buf, tp);
    if (i != DB_COUNT) {
      tp->tp_diff_invalid = TRUE;
      if (tp == curtab) {
        diff_redraw(TRUE);
      }
    }
  }
}

/// Called by mark_adjust(): update line numbers in "curbuf".
///
/// @param line1
/// @param line2
/// @param amount
/// @param amount_after
void diff_mark_adjust(linenr_T line1, linenr_T line2, long amount,
                      long amount_after)
{
  // Handle all tab pages that use the current buffer in a diff.
  FOR_ALL_TABS(tp) {
    int idx = diff_buf_idx_tp(curbuf, tp);
    if (idx != DB_COUNT) {
      diff_mark_adjust_tp(tp, idx, line1, line2, amount, amount_after);
    }
  }
}

/// Update line numbers in tab page "tp" for "curbuf" with index "idx".
///
/// This attempts to update the changes as much as possible:
/// When inserting/deleting lines outside of existing change blocks, create a
/// new change block and update the line numbers in following blocks.
/// When inserting/deleting lines in existing change blocks, update them.
///
/// @param tp
/// @param idx
/// @param line1
/// @param line2
/// @param amount
/// @amount_after
static void diff_mark_adjust_tp(tabpage_T *tp, int idx, linenr_T line1,
                                linenr_T line2, long amount, long amount_after)
{
  int inserted;
  int deleted;
  if (line2 == MAXLNUM) {
    // mark_adjust(99, MAXLNUM, 9, 0): insert lines
    inserted = amount;
    deleted = 0;
  } else if (amount_after > 0) {
    // mark_adjust(99, 98, MAXLNUM, 9): a change that inserts lines
    inserted = amount_after;
    deleted = 0;
  } else {
    // mark_adjust(98, 99, MAXLNUM, -2): delete lines
    inserted = 0;
    deleted = -amount_after;
  }

  diff_T *dprev = NULL;
  diff_T *dp = tp->tp_first_diff;

  linenr_T last;
  linenr_T lnum_deleted = line1; // lnum of remaining deletion
  int n;
  int off;
  for (;;) {
    // If the change is after the previous diff block and before the next
    // diff block, thus not touching an existing change, create a new diff
    // block.  Don't do this when ex_diffgetput() is busy.
    if (((dp == NULL)
         || (dp->df_lnum[idx] - 1 > line2)
         || ((line2 == MAXLNUM) && (dp->df_lnum[idx] > line1)))
        && ((dprev == NULL)
            || (dprev->df_lnum[idx] + dprev->df_count[idx] < line1))
        && !diff_busy) {
      diff_T *dnext = diff_alloc_new(tp, dprev, dp);

      dnext->df_lnum[idx] = line1;
      dnext->df_count[idx] = inserted;
      int i;
      for (i = 0; i < DB_COUNT; ++i) {
        if ((tp->tp_diffbuf[i] != NULL) && (i != idx)) {
          if (dprev == NULL) {
            dnext->df_lnum[i] = line1;
          } else {
            dnext->df_lnum[i] = line1
                + (dprev->df_lnum[i] + dprev->df_count[i])
                - (dprev->df_lnum[idx] + dprev->df_count[idx]);
          }
          dnext->df_count[i] = deleted;
        }
      }
    }

    // if at end of the list, quit
    if (dp == NULL) {
      break;
    }

    //
    // Check for these situations:
    //	  1  2	3
    //	  1  2	3
    // line1     2	3  4  5
    //	     2	3  4  5
    //	     2	3  4  5
    // line2     2	3  4  5
    //		3     5  6
    //		3     5  6

    // compute last line of this change
    last = dp->df_lnum[idx] + dp->df_count[idx] - 1;

    // 1. change completely above line1: nothing to do
    if (last >= line1 - 1) {
      // 6. change below line2: only adjust for amount_after; also when
      // "deleted" became zero when deleted all lines between two diffs.
      if (dp->df_lnum[idx] - (deleted + inserted != 0) > line2) {
        if (amount_after == 0) {
          // nothing left to change
          break;
        }
        dp->df_lnum[idx] += amount_after;
      } else {
        int check_unchanged = FALSE;

        // 2. 3. 4. 5.: inserted/deleted lines touching this diff.
        if (deleted > 0) {
          if (dp->df_lnum[idx] >= line1) {
            off = dp->df_lnum[idx] - lnum_deleted;

            if (last <= line2) {
              // 4. delete all lines of diff
              if ((dp->df_next != NULL)
                  && (dp->df_next->df_lnum[idx] - 1 <= line2)) {
                // delete continues in next diff, only do
                // lines until that one
                n = dp->df_next->df_lnum[idx] - lnum_deleted;
                deleted -= n;
                n -= dp->df_count[idx];
                lnum_deleted = dp->df_next->df_lnum[idx];
              } else {
                n = deleted - dp->df_count[idx];
              }
              dp->df_count[idx] = 0;
            } else {
              // 5. delete lines at or just before top of diff
              n = off;
              dp->df_count[idx] -= line2 - dp->df_lnum[idx] + 1;
              check_unchanged = TRUE;
            }
            dp->df_lnum[idx] = line1;
          } else {
            off = 0;

            if (last < line2) {
              // 2. delete at end of of diff
              dp->df_count[idx] -= last - lnum_deleted + 1;

              if ((dp->df_next != NULL)
                  && (dp->df_next->df_lnum[idx] - 1 <= line2)) {
                // delete continues in next diff, only do
                // lines until that one
                n = dp->df_next->df_lnum[idx] - 1 - last;
                deleted -= dp->df_next->df_lnum[idx] - lnum_deleted;
                lnum_deleted = dp->df_next->df_lnum[idx];
              } else {
                n = line2 - last;
              }
              check_unchanged = TRUE;
            } else {
              // 3. delete lines inside the diff
              n = 0;
              dp->df_count[idx] -= deleted;
            }
          }

          int i;
          for (i = 0; i < DB_COUNT; ++i) {
            if ((tp->tp_diffbuf[i] != NULL) && (i != idx)) {
              dp->df_lnum[i] -= off;
              dp->df_count[i] += n;
            }
          }
        } else {
          if (dp->df_lnum[idx] <= line1) {
            // inserted lines somewhere in this diff
            dp->df_count[idx] += inserted;
            check_unchanged = TRUE;
          } else {
            // inserted lines somewhere above this diff
            dp->df_lnum[idx] += inserted;
          }
        }

        if (check_unchanged) {
          // Check if inserted lines are equal, may reduce the size of the
          // diff.
          //
          // TODO: also check for equal lines in the middle and perhaps split
          // the block.
          diff_check_unchanged(tp, dp);
        }
      }
    }

    // check if this block touches the previous one, may merge them.
    if ((dprev != NULL)
        && (dprev->df_lnum[idx] + dprev->df_count[idx] == dp->df_lnum[idx])) {
      int i;
      for (i = 0; i < DB_COUNT; ++i) {
        if (tp->tp_diffbuf[i] != NULL) {
          dprev->df_count[i] += dp->df_count[i];
        }
      }
      dprev->df_next = dp->df_next;
      xfree(dp);
      dp = dprev->df_next;
    } else {
      // Advance to next entry.
      dprev = dp;
      dp = dp->df_next;
    }
  }

  dprev = NULL;
  dp = tp->tp_first_diff;

  while (dp != NULL) {
    // All counts are zero, remove this entry.
    int i;
    for (i = 0; i < DB_COUNT; ++i) {
      if ((tp->tp_diffbuf[i] != NULL) && (dp->df_count[i] != 0)) {
        break;
      }
    }

    if (i == DB_COUNT) {
      diff_T *dnext = dp->df_next;
      xfree(dp);
      dp = dnext;

      if (dprev == NULL) {
        tp->tp_first_diff = dnext;
      } else {
        dprev->df_next = dnext;
      }
    } else {
      // Advance to next entry.
      dprev = dp;
      dp = dp->df_next;
    }
  }

  if (tp == curtab) {
    diff_redraw(TRUE);

    // Need to recompute the scroll binding, may remove or add filler
    // lines (e.g., when adding lines above w_topline). But it's slow when
    // making many changes, postpone until redrawing.
    diff_need_scrollbind = TRUE;
  }
}

/// Allocate a new diff block and link it between "dprev" and "dp".
///
/// @param tp
/// @param dprev
/// @param dp
///
/// @return The new diff block.
static diff_T* diff_alloc_new(tabpage_T *tp, diff_T *dprev, diff_T *dp)
{
  diff_T *dnew = xmalloc(sizeof(*dnew));

  dnew->df_next = dp;
  if (dprev == NULL) {
    tp->tp_first_diff = dnew;
  } else {
    dprev->df_next = dnew;
  }

  return dnew;
}

/// Check if the diff block "dp" can be made smaller for lines at the start and
/// end that are equal.  Called after inserting lines.
///
/// This may result in a change where all buffers have zero lines, the caller
/// must take care of removing it.
///
/// @param tp
/// @param dp
static void diff_check_unchanged(tabpage_T *tp, diff_T *dp)
{
  // Find the first buffers, use it as the original, compare the other
  // buffer lines against this one.
  int i_org;
  for (i_org = 0; i_org < DB_COUNT; ++i_org) {
    if (tp->tp_diffbuf[i_org] != NULL) {
      break;
    }
  }

  // safety check
  if (i_org == DB_COUNT) {
    return;
  }

  if (diff_check_sanity(tp, dp) == FAIL) {
    return;
  }

  // First check lines at the top, then at the bottom.
  int off_org = 0;
  int off_new = 0;
  int dir = FORWARD;
  for (;;) {
    // Repeat until a line is found which is different or the number of
    // lines has become zero.
    while (dp->df_count[i_org] > 0) {
      // Copy the line, the next ml_get() will invalidate it.
      if (dir == BACKWARD) {
        off_org = dp->df_count[i_org] - 1;
      }
      char_u *line_org = vim_strsave(ml_get_buf(tp->tp_diffbuf[i_org],
                                                dp->df_lnum[i_org] + off_org,
                                                FALSE));

      int i_new;
      for (i_new = i_org + 1; i_new < DB_COUNT; ++i_new) {
        if (tp->tp_diffbuf[i_new] == NULL) {
          continue;
        }

        if (dir == BACKWARD) {
          off_new = dp->df_count[i_new] - 1;
        }

        // if other buffer doesn't have this line, it was inserted
        if ((off_new < 0) || (off_new >= dp->df_count[i_new])) {
          break;
        }

        if (diff_cmp(line_org, ml_get_buf(tp->tp_diffbuf[i_new],
                                          dp->df_lnum[i_new] + off_new,
                                          FALSE)) != 0) {
          break;
        }
      }
      xfree(line_org);

      // Stop when a line isn't equal in all diff buffers.
      if (i_new != DB_COUNT) {
        break;
      }

      // Line matched in all buffers, remove it from the diff.
      for (i_new = i_org; i_new < DB_COUNT; ++i_new) {
        if (tp->tp_diffbuf[i_new] != NULL) {
          if (dir == FORWARD) {
            dp->df_lnum[i_new]++;
          }
          dp->df_count[i_new]--;
        }
      }
    }

    if (dir == BACKWARD) {
      break;
    }
    dir = BACKWARD;
  }
}

/// Check if a diff block doesn't contain invalid line numbers.
/// This can happen when the diff program returns invalid results.
///
/// @param tp
/// @param dp
///
/// @return OK if the diff block doesn't contain invalid line numbers.
static int diff_check_sanity(tabpage_T *tp, diff_T *dp)
{
  int i;
  for (i = 0; i < DB_COUNT; ++i) {
    if (tp->tp_diffbuf[i] != NULL) {
      if (dp->df_lnum[i] + dp->df_count[i] - 1
          > tp->tp_diffbuf[i]->b_ml.ml_line_count) {
        return FAIL;
      }
    }
  }
  return OK;
}

/// Mark all diff buffers in the current tab page for redraw.
///
/// @param dofold Also recompute the folds
static void diff_redraw(int dofold)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (!wp->w_p_diff) {
      continue;
    }
    redraw_win_later(wp, SOME_VALID);
    if (dofold && foldmethodIsDiff(wp)) {
      foldUpdateAll(wp);
    }

    /* A change may have made filler lines invalid, need to take care
     * of that for other windows. */
    int n = diff_check(wp, wp->w_topline);

    if (((wp != curwin) && (wp->w_topfill > 0)) || (n > 0)) {
      if (wp->w_topfill > n) {
        wp->w_topfill = (n < 0 ? 0 : n);
      } else if ((n > 0) && (n > wp->w_topfill)) {
        wp->w_topfill = n;
      }
      check_topfill(wp, FALSE);
    }
  }
}

/// Write buffer "buf" to file "name".
///
/// Always use 'fileformat' set to "unix".
///
/// @param buf
/// @param fname
///
/// @return FAIL for failure
static int diff_write(buf_T *buf, char_u *fname)
{
  char_u *save_ff = buf->b_p_ff;
  buf->b_p_ff = vim_strsave((char_u *)FF_UNIX);
  int r = buf_write(buf, fname, NULL, (linenr_T)1, buf->b_ml.ml_line_count,
                    NULL, FALSE, FALSE, FALSE, TRUE);
  free_string_option(buf->b_p_ff);
  buf->b_p_ff = save_ff;
  return r;
}

/// Completely update the diffs for the buffers involved.
///
/// This uses the ordinary "diff" command.
/// The buffers are written to a file, also for unmodified buffers (the file
/// could have been produced by autocommands, e.g. the netrw plugin).
///
/// @param eap can be NULL
void ex_diffupdate(exarg_T *eap)
{
  // Delete all diffblocks.
  diff_clear(curtab);
  curtab->tp_diff_invalid = FALSE;

  // Use the first buffer as the original text.
  int idx_orig;
  for (idx_orig = 0; idx_orig < DB_COUNT; ++idx_orig) {
    if (curtab->tp_diffbuf[idx_orig] != NULL) {
      break;
    }
  }

  if (idx_orig == DB_COUNT) {
    return;
  }

  // Only need to do something when there is another buffer.
  int idx_new;
  for (idx_new = idx_orig + 1; idx_new < DB_COUNT; ++idx_new) {
    if (curtab->tp_diffbuf[idx_new] != NULL) {
      break;
    }
  }

  if (idx_new == DB_COUNT) {
    return;
  }

  // We need three temp file names.
  char *tmp_orig = (char *) vim_tempname();
  char *tmp_new = (char *) vim_tempname();
  char *tmp_diff = (char *) vim_tempname();

  if ((tmp_orig == NULL) || (tmp_new == NULL) || (tmp_diff == NULL)) {
    goto theend;
  }

  // Do a quick test if "diff" really works.  Otherwise it looks like there
  // are no differences.  Can't use the return value, it's non-zero when
  // there are differences.
  // May try twice, first with "-a" and then without.
  int io_error = false;
  bool ok = false;
  for (;;) {
    ok = false;
    FILE *fd = mch_fopen(tmp_orig, "w");

    if (fd == NULL) {
      io_error = TRUE;
    } else {
      if (fwrite("line1\n", (size_t)6, (size_t)1, fd) != 1) {
        io_error = TRUE;
      }
      fclose(fd);
      fd = mch_fopen(tmp_new, "w");

      if (fd == NULL) {
        io_error = TRUE;
      } else {
        if (fwrite("line2\n", (size_t)6, (size_t)1, fd) != 1) {
          io_error = TRUE;
        }
        fclose(fd);
        diff_file(tmp_orig, tmp_new, tmp_diff);
        fd = mch_fopen(tmp_diff, "r");

        if (fd == NULL) {
          io_error = TRUE;
        } else {
          char_u linebuf[LBUFLEN];

          for (;;) {
            // There must be a line that contains "1c1".
            if (vim_fgets(linebuf, LBUFLEN, fd)) {
              break;
            }

            if (STRNCMP(linebuf, "1c1", 3) == 0) {
              ok = TRUE;
            }
          }
          fclose(fd);
        }
        os_remove(tmp_diff);
        os_remove(tmp_new);
      }
      os_remove(tmp_orig);
    }

    // When using 'diffexpr' break here.
    if (*p_dex != NUL) {
      break;
    }

    // If we checked if "-a" works already, break here.
    if (diff_a_works != MAYBE) {
      break;
    }
    diff_a_works = ok;

    // If "-a" works break here, otherwise retry without "-a".
    if (ok) {
      break;
    }
  }

  if (!ok) {
    if (io_error) {
      EMSG(_("E810: Cannot read or write temp files"));
    }
    EMSG(_("E97: Cannot create diffs"));
    diff_a_works = MAYBE;
    goto theend;
  }

  // :diffupdate!
  if ((eap != NULL) && eap->forceit) {
    for (idx_new = idx_orig; idx_new < DB_COUNT; ++idx_new) {
      buf_T *buf = curtab->tp_diffbuf[idx_new];
      if (buf_valid(buf)) {
        buf_check_timestamp(buf, FALSE);
      }
    }
  }

  // Write the first buffer to a tempfile.
  buf_T *buf = curtab->tp_diffbuf[idx_orig];
  if (diff_write(buf, (char_u *) tmp_orig) == FAIL) {
    goto theend;
  }

  // Make a difference between the first buffer and every other.
  for (idx_new = idx_orig + 1; idx_new < DB_COUNT; ++idx_new) {
    buf_T *buf = curtab->tp_diffbuf[idx_new];
    if (buf == NULL || buf->b_ml.ml_mfp == NULL) {
      continue;  // skip buffer that isn't loaded
    }

    if (diff_write(buf, (char_u *) tmp_new) == FAIL) {
      continue;
    }
    diff_file(tmp_orig, tmp_new, tmp_diff);

    // Read the diff output and add each entry to the diff list.
    diff_read(idx_orig, idx_new, (char_u *) tmp_diff);
    os_remove(tmp_diff);
    os_remove(tmp_new);
  }
  os_remove(tmp_orig);

  // force updating cursor position on screen
  curwin->w_valid_cursor.lnum = 0;

  diff_redraw(TRUE);

theend:
  xfree(tmp_orig);
  xfree(tmp_new);
  xfree(tmp_diff);
}

/// Make a diff between files "tmp_orig" and "tmp_new", results in "tmp_diff".
///
/// @param tmp_orig
/// @param tmp_new
/// @param tmp_diff
static void diff_file(const char *const tmp_orig, const char *const tmp_new,
                      const char *const tmp_diff)
{
  if (*p_dex != NUL) {
    // Use 'diffexpr' to generate the diff file.
    eval_diff(tmp_orig, tmp_new, tmp_diff);
  } else {
    const size_t len = (strlen(tmp_orig) + strlen(tmp_new) + strlen(tmp_diff)
                        + STRLEN(p_srr) + 27);
    char *const cmd = xmalloc(len);

    /* We don't want $DIFF_OPTIONS to get in the way. */
    if (os_getenv("DIFF_OPTIONS")) {
      os_unsetenv("DIFF_OPTIONS");
    }

    /* Build the diff command and execute it.  Always use -a, binary
     * differences are of no use.  Ignore errors, diff returns
     * non-zero when differences have been found. */
    vim_snprintf(cmd, len, "diff %s%s%s%s%s %s",
                 diff_a_works ? "-a " : "",
                 "",
                 (diff_flags & DIFF_IWHITE) ? "-b " : "",
                 (diff_flags & DIFF_ICASE) ? "-i " : "",
                 tmp_orig, tmp_new);
    append_redir(cmd, len, (char *) p_srr, tmp_diff);
    block_autocmds();  // Avoid ShellCmdPost stuff
    (void)call_shell((char_u *) cmd,
                     kShellOptFilter | kShellOptSilent | kShellOptDoOut,
                     NULL);
    unblock_autocmds();
    xfree(cmd);
  }
}

/// Create a new version of a file from the current buffer and a diff file.
///
/// The buffer is written to a file, also for unmodified buffers (the file
/// could have been produced by autocommands, e.g. the netrw plugin).
///
/// @param eap
void ex_diffpatch(exarg_T *eap)
{
  char_u *buf = NULL;
  win_T *old_curwin = curwin;
  char_u *newname = NULL;  // name of patched file buffer
  char_u *esc_name = NULL;

#ifdef UNIX
  char_u dirbuf[MAXPATHL];
  char_u *fullname = NULL;
#endif
  // We need two temp file names.
  // Name of original temp file.
  char_u *tmp_orig = vim_tempname();
  // Name of patched temp file.
  char_u *tmp_new = vim_tempname();

  if ((tmp_orig == NULL) || (tmp_new == NULL)) {
    goto theend;
  }

  // Write the current buffer to "tmp_orig".
  if (buf_write(curbuf, tmp_orig, NULL,
                (linenr_T)1, curbuf->b_ml.ml_line_count,
                NULL, FALSE, FALSE, FALSE, TRUE) == FAIL) {
    goto theend;
  }

#ifdef UNIX
  // Get the absolute path of the patchfile, changing directory below.
  fullname = (char_u *)FullName_save((char *)eap->arg, false);
#endif

  esc_name = vim_strsave_shellescape(
#ifdef UNIX
                                     fullname != NULL ? fullname :
#endif
                                     eap->arg, true, true);
  if (esc_name == NULL) {
    goto theend;
  }
  size_t buflen = STRLEN(tmp_orig) + STRLEN(esc_name) + STRLEN(tmp_new) + 16;
  buf = xmalloc(buflen);

#ifdef UNIX
  // Temporarily chdir to /tmp, to avoid patching files in the current
  // directory when the patch file contains more than one patch.  When we
  // have our own temp dir use that instead, it will be cleaned up when we
  // exit (any .rej files created).  Don't change directory if we can't
  // return to the current.
  if ((os_dirname(dirbuf, MAXPATHL) != OK)
      || (os_chdir((char *)dirbuf) != 0)) {
    dirbuf[0] = NUL;
  } else {
    char *tempdir = (char *)vim_gettempdir();
    if (tempdir == NULL) {
      tempdir = "/tmp";
    }
    os_chdir(tempdir);
    shorten_fnames(TRUE);
  }
#endif

  if (*p_pex != NUL) {
    // Use 'patchexpr' to generate the new file.
#ifdef UNIX
    eval_patch((char *)tmp_orig,
               (char *)(fullname != NULL ? fullname : eap->arg),
               (char *)tmp_new);
#else
    eval_patch((char *)tmp_orig, (char *)eap->arg, (char *)tmp_new);
#endif
  } else {
    // Build the patch command and execute it. Ignore errors.
    vim_snprintf((char *)buf, buflen, "patch -o %s %s < %s",
                 tmp_new, tmp_orig, esc_name);
    block_autocmds();  // Avoid ShellCmdPost stuff
    (void)call_shell(buf, kShellOptFilter, NULL);
    unblock_autocmds();
  }

#ifdef UNIX
  if (dirbuf[0] != NUL) {
    if (os_chdir((char *)dirbuf) != 0) {
      EMSG(_(e_prev_dir));
    }
    shorten_fnames(TRUE);
  }
#endif

  // Delete any .orig or .rej file created.
  STRCPY(buf, tmp_new);
  STRCAT(buf, ".orig");
  os_remove((char *)buf);
  STRCPY(buf, tmp_new);
  STRCAT(buf, ".rej");
  os_remove((char *)buf);

  // Only continue if the output file was created.
  FileInfo file_info;
  bool info_ok = os_fileinfo((char *)tmp_new, &file_info);
  uint64_t filesize = os_fileinfo_size(&file_info);
  if (!info_ok || filesize == 0) {
    EMSG(_("E816: Cannot read patch output"));
  } else {
    if (curbuf->b_fname != NULL) {
      newname = vim_strnsave(curbuf->b_fname,
                             (int)(STRLEN(curbuf->b_fname) + 4));
      STRCAT(newname, ".new");
    }

    // don't use a new tab page, each tab page has its own diffs
    cmdmod.tab = 0;

    if (win_split(0, (diff_flags & DIFF_VERTICAL) ? WSP_VERT : 0) != FAIL) {
      // Pretend it was a ":split fname" command
      eap->cmdidx = CMD_split;
      eap->arg = tmp_new;
      do_exedit(eap, old_curwin);

      // check that split worked and editing tmp_new
      if ((curwin != old_curwin) && win_valid(old_curwin)) {
        // Set 'diff', 'scrollbind' on and 'wrap' off.
        diff_win_options(curwin, TRUE);
        diff_win_options(old_curwin, TRUE);

        if (newname != NULL) {
          // do a ":file filename.new" on the patched buffer
          eap->arg = newname;
          ex_file(eap);

          // Do filetype detection with the new name.
          if (au_has_group((char_u *)"filetypedetect")) {
            do_cmdline_cmd(":doau filetypedetect BufRead");
          }
        }
      }
    }
  }

theend:
  if (tmp_orig != NULL) {
    os_remove((char *)tmp_orig);
  }
  xfree(tmp_orig);

  if (tmp_new != NULL) {
    os_remove((char *)tmp_new);
  }
  xfree(tmp_new);
  xfree(newname);
  xfree(buf);
#ifdef UNIX
  xfree(fullname);
#endif
  xfree(esc_name);
}

/// Split the window and edit another file, setting options to show the diffs.
///
/// @param eap
void ex_diffsplit(exarg_T *eap)
{
  win_T *old_curwin = curwin;
  bufref_T old_curbuf;
  set_bufref(&old_curbuf, curbuf);

  // Need to compute w_fraction when no redraw happened yet.
  validate_cursor();
  set_fraction(curwin);

  // don't use a new tab page, each tab page has its own diffs
  cmdmod.tab = 0;

  if (win_split(0, (diff_flags & DIFF_VERTICAL) ? WSP_VERT : 0) != FAIL) {
    // Pretend it was a ":split fname" command
    eap->cmdidx = CMD_split;
    curwin->w_p_diff = TRUE;
    do_exedit(eap, old_curwin);

    // split must have worked
    if (curwin != old_curwin) {
      // Set 'diff', 'scrollbind' on and 'wrap' off.
      diff_win_options(curwin, true);
      if (win_valid(old_curwin)) {
        diff_win_options(old_curwin, true);

        if (bufref_valid(&old_curbuf)) {
          // Move the cursor position to that of the old window.
          curwin->w_cursor.lnum = diff_get_corresponding_line(
              old_curbuf.br_buf, old_curwin->w_cursor.lnum);
        }
      }
      // Now that lines are folded scroll to show the cursor at the same
      // relative position.
      scroll_to_fraction(curwin, curwin->w_height);
    }
  }
}

// Set options to show diffs for the current window.
void ex_diffthis(exarg_T *eap)
{
  // Set 'diff', 'scrollbind' on and 'wrap' off.
  diff_win_options(curwin, TRUE);
}

static void set_diff_option(win_T *wp, int value)
{
    win_T *old_curwin = curwin;

    curwin = wp;
    curbuf = curwin->w_buffer;
    curbuf_lock++;
    set_option_value("diff", (long)value, NULL, OPT_LOCAL);
    curbuf_lock--;
    curwin = old_curwin;
    curbuf = curwin->w_buffer;
}


/// Set options in window "wp" for diff mode.
///
/// @param addbuf Add buffer to diff.
void diff_win_options(win_T *wp, int addbuf)
{
  win_T *old_curwin = curwin;

  // close the manually opened folds
  curwin = wp;
  newFoldLevel();
  curwin = old_curwin;

  // Use 'scrollbind' and 'cursorbind' when available
  if (!wp->w_p_diff) {
    wp->w_p_scb_save = wp->w_p_scb;
  }
  wp->w_p_scb = TRUE;

  if (!wp->w_p_diff) {
    wp->w_p_crb_save = wp->w_p_crb;
  }
  wp->w_p_crb = TRUE;

  if (!wp->w_p_diff) {
    wp->w_p_wrap_save = wp->w_p_wrap;
  }
  wp->w_p_wrap = false;
  curwin = wp;  // -V519
  curbuf = curwin->w_buffer;

  if (!wp->w_p_diff) {
    if (wp->w_p_diff_saved) {
      free_string_option(wp->w_p_fdm_save);
    }
    wp->w_p_fdm_save = vim_strsave(wp->w_p_fdm);
  }
  set_string_option_direct((char_u *)"fdm", -1, (char_u *)"diff",
                           OPT_LOCAL | OPT_FREE, 0);
  curwin = old_curwin;
  curbuf = curwin->w_buffer;

  if (!wp->w_p_diff) {
    wp->w_p_fdc_save = wp->w_p_fdc;
    wp->w_p_fen_save = wp->w_p_fen;
    wp->w_p_fdl_save = wp->w_p_fdl;
  }
  wp->w_p_fdc = diff_foldcolumn;
  wp->w_p_fen = TRUE;
  wp->w_p_fdl = 0;
  foldUpdateAll(wp);

  // make sure topline is not halfway through a fold
  changed_window_setting_win(wp);
  if (vim_strchr(p_sbo, 'h') == NULL) {
    do_cmdline_cmd("set sbo+=hor");
  }

  // Save the current values, to be restored in ex_diffoff().
  wp->w_p_diff_saved = true;

  set_diff_option(wp, true);

  if (addbuf) {
    diff_buf_add(wp->w_buffer);
  }
  redraw_win_later(wp, NOT_VALID);
}

/// Set options not to show diffs.  For the current window or all windows.
/// Only in the current tab page.
///
/// @param eap
void ex_diffoff(exarg_T *eap)
{
  int diffwin = false;

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (eap->forceit ? wp->w_p_diff : (wp == curwin)) {
      // Set 'diff' off. If option values were saved in
      // diff_win_options(), restore the ones whose settings seem to have
      // been left over from diff mode.
      set_diff_option(wp, false);

      if (wp->w_p_diff_saved) {
        if (wp->w_p_scb) {
          wp->w_p_scb = wp->w_p_scb_save;
        }

        if (wp->w_p_crb) {
          wp->w_p_crb = wp->w_p_crb_save;
        }

        if (!wp->w_p_wrap) {
          wp->w_p_wrap = wp->w_p_wrap_save;
        }

        free_string_option(wp->w_p_fdm);
        wp->w_p_fdm = vim_strsave(*wp->w_p_fdm_save
                                  ? wp->w_p_fdm_save
                                  : (char_u *)"manual");
        if (wp->w_p_fdc == diff_foldcolumn) {
          wp->w_p_fdc = wp->w_p_fdc_save;
        }
        if (wp->w_p_fdl == 0) {
          wp->w_p_fdl = wp->w_p_fdl_save;
        }
        // Only restore 'foldenable' when 'foldmethod' is not
        // "manual", otherwise we continue to show the diff folds.
        if (wp->w_p_fen) {
          wp->w_p_fen = foldmethodIsManual(wp) ? false : wp->w_p_fen_save;
        }

        foldUpdateAll(wp);
      }
      // remove filler lines
      wp->w_topfill = 0;

      // make sure topline is not halfway a fold and cursor is
      // invalidated
      changed_window_setting_win(wp);

      // Note: 'sbo' is not restored, it's a global option.
      diff_buf_adjust(wp);
    }
    diffwin |= wp->w_p_diff;
  }

  // Also remove hidden buffers from the list.
  if (eap->forceit) {
    diff_buf_clear();
  }

  // Remove "hor" from from 'scrollopt' if there are no diff windows left.
  if (!diffwin && (vim_strchr(p_sbo, 'h') != NULL)) {
    do_cmdline_cmd("set sbo-=hor");
  }
}

/// Read the diff output and add each entry to the diff list.
///
/// @param idx_orig idx of original file
/// @param idx_new idx of new file
/// @param fname name of diff output file
static void diff_read(int idx_orig, int idx_new, char_u *fname)
{
  FILE *fd;
  diff_T *dprev = NULL;
  diff_T *dp = curtab->tp_first_diff;
  diff_T *dn, *dpl;
  long f1, l1, f2, l2;
  char_u linebuf[LBUFLEN]; // only need to hold the diff line
  int difftype;
  char_u *p;
  long off;
  int i;
  linenr_T lnum_orig, lnum_new;
  long count_orig, count_new;
  int notset = TRUE; // block "*dp" not set yet

  fd = mch_fopen((char *)fname, "r");

  if (fd == NULL) {
    EMSG(_("E98: Cannot read diff output"));
    return;
  }

  for (;;) {
    if (vim_fgets(linebuf, LBUFLEN, fd)) {
      // end of file
      break;
    }

    if (!isdigit(*linebuf)) {
      // not the start of a diff block
      continue;
    }

    // This line must be one of three formats:
    // {first}[,{last}]c{first}[,{last}]
    // {first}a{first}[,{last}]
    // {first}[,{last}]d{first}
    p = linebuf;
    f1 = getdigits_long(&p);

    if (*p == ',') {
      ++p;
      l1 = getdigits_long(&p);
    } else {
      l1 = f1;
    }

    if ((*p != 'a') && (*p != 'c') && (*p != 'd')) {
      // invalid diff format
      continue;
    }
    difftype = *p++;
    f2 = getdigits_long(&p);

    if (*p == ',') {
      ++p;
      l2 = getdigits_long(&p);
    } else {
      l2 = f2;
    }

    if ((l1 < f1) || (l2 < f2)) {
      // invalid line range
      continue;
    }

    if (difftype == 'a') {
      lnum_orig = f1 + 1;
      count_orig = 0;
    } else {
      lnum_orig = f1;
      count_orig = l1 - f1 + 1;
    }

    if (difftype == 'd') {
      lnum_new = f2 + 1;
      count_new = 0;
    } else {
      lnum_new = f2;
      count_new = l2 - f2 + 1;
    }

    // Go over blocks before the change, for which orig and new are equal.
    // Copy blocks from orig to new.
    while (dp != NULL
           && lnum_orig > dp->df_lnum[idx_orig] + dp->df_count[idx_orig]) {
      if (notset) {
        diff_copy_entry(dprev, dp, idx_orig, idx_new);
      }
      dprev = dp;
      dp = dp->df_next;
      notset = TRUE;
    }

    if ((dp != NULL)
        && (lnum_orig <= dp->df_lnum[idx_orig] + dp->df_count[idx_orig])
        && (lnum_orig + count_orig >= dp->df_lnum[idx_orig])) {
      // New block overlaps with existing block(s).
      // First find last block that overlaps.
      for (dpl = dp; dpl->df_next != NULL; dpl = dpl->df_next) {
        if (lnum_orig + count_orig < dpl->df_next->df_lnum[idx_orig]) {
          break;
        }
      }

      // If the newly found block starts before the old one, set the
      // start back a number of lines.
      off = dp->df_lnum[idx_orig] - lnum_orig;

      if (off > 0) {
        for (i = idx_orig; i < idx_new; ++i) {
          if (curtab->tp_diffbuf[i] != NULL) {
            dp->df_lnum[i] -= off;
          }
        }
        dp->df_lnum[idx_new] = lnum_new;
        dp->df_count[idx_new] = count_new;
      } else if (notset) {
        // new block inside existing one, adjust new block
        dp->df_lnum[idx_new] = lnum_new + off;
        dp->df_count[idx_new] = count_new - off;
      } else {
        // second overlap of new block with existing block
        dp->df_count[idx_new] += count_new - count_orig
                                 + dpl->df_lnum[idx_orig] +
                                 dpl->df_count[idx_orig]
                                 - (dp->df_lnum[idx_orig] +
                                    dp->df_count[idx_orig]);
      }

      // Adjust the size of the block to include all the lines to the
      // end of the existing block or the new diff, whatever ends last.
      off = (lnum_orig + count_orig)
            - (dpl->df_lnum[idx_orig] + dpl->df_count[idx_orig]);

      if (off < 0) {
        // new change ends in existing block, adjust the end if not
        // done already
        if (notset) {
          dp->df_count[idx_new] += -off;
        }
        off = 0;
      }

      for (i = idx_orig; i < idx_new; ++i) {
        if (curtab->tp_diffbuf[i] != NULL) {
          dp->df_count[i] = dpl->df_lnum[i] + dpl->df_count[i]
                            - dp->df_lnum[i] + off;
        }
      }

      // Delete the diff blocks that have been merged into one.
      dn = dp->df_next;
      dp->df_next = dpl->df_next;

      while (dn != dp->df_next) {
        dpl = dn->df_next;
        xfree(dn);
        dn = dpl;
      }
    } else {
      // Allocate a new diffblock.
      dp = diff_alloc_new(curtab, dprev, dp);

      dp->df_lnum[idx_orig] = lnum_orig;
      dp->df_count[idx_orig] = count_orig;
      dp->df_lnum[idx_new] = lnum_new;
      dp->df_count[idx_new] = count_new;

      // Set values for other buffers, these must be equal to the
      // original buffer, otherwise there would have been a change
      // already.
      for (i = idx_orig + 1; i < idx_new; ++i) {
        if (curtab->tp_diffbuf[i] != NULL) {
          diff_copy_entry(dprev, dp, idx_orig, i);
        }
      }
    }
    notset = FALSE; // "*dp" has been set
  }

  // for remaining diff blocks orig and new are equal
  while (dp != NULL) {
    if (notset) {
      diff_copy_entry(dprev, dp, idx_orig, idx_new);
    }
    dprev = dp;
    dp = dp->df_next;
    notset = TRUE;
  }

  fclose(fd);
}

/// Copy an entry at "dp" from "idx_orig" to "idx_new".
///
/// @param dprev
/// @param dp
/// @param idx_orig
/// @param idx_new
static void diff_copy_entry(diff_T *dprev, diff_T *dp, int idx_orig,
                            int idx_new)
{
  long off;

  if (dprev == NULL) {
    off = 0;
  } else {
    off = (dprev->df_lnum[idx_orig] + dprev->df_count[idx_orig])
          - (dprev->df_lnum[idx_new] + dprev->df_count[idx_new]);
  }
  dp->df_lnum[idx_new] = dp->df_lnum[idx_orig] - off;
  dp->df_count[idx_new] = dp->df_count[idx_orig];
}

/// Clear the list of diffblocks for tab page "tp".
///
/// @param tp
void diff_clear(tabpage_T *tp)
{
  diff_T *p;
  diff_T *next_p;
  for (p = tp->tp_first_diff; p != NULL; p = next_p) {
    next_p = p->df_next;
    xfree(p);
  }
  tp->tp_first_diff = NULL;
}

/// Check diff status for line "lnum" in buffer "buf":
///
/// Returns 0 for nothing special
/// Returns -1 for a line that should be highlighted as changed.
/// Returns -2 for a line that should be highlighted as added/deleted.
/// Returns > 0 for inserting that many filler lines above it (never happens
/// when 'diffopt' doesn't contain "filler").
/// This should only be used for windows where 'diff' is set.
///
/// @param wp
/// @param lnum
///
/// @return diff status.
int diff_check(win_T *wp, linenr_T lnum)
{
  int idx; // index in tp_diffbuf[] for this buffer
  diff_T *dp;
  int maxcount;
  int i;
  buf_T *buf = wp->w_buffer;
  int cmp;

  if (curtab->tp_diff_invalid) {
    // update after a big change
    ex_diffupdate(NULL);
  }

  // no diffs at all
  if ((curtab->tp_first_diff == NULL) || !wp->w_p_diff) {
    return 0;
  }

  // safety check: "lnum" must be a buffer line
  if ((lnum < 1) || (lnum > buf->b_ml.ml_line_count + 1)) {
    return 0;
  }

  idx = diff_buf_idx(buf);

  if (idx == DB_COUNT) {
    // no diffs for buffer "buf"
    return 0;
  }

  // A closed fold never has filler lines.
  if (hasFoldingWin(wp, lnum, NULL, NULL, TRUE, NULL)) {
    return 0;
  }

  // search for a change that includes "lnum" in the list of diffblocks.
  for (dp = curtab->tp_first_diff; dp != NULL; dp = dp->df_next) {
    if (lnum <= dp->df_lnum[idx] + dp->df_count[idx]) {
      break;
    }
  }

  if ((dp == NULL) || (lnum < dp->df_lnum[idx])) {
    return 0;
  }

  if (lnum < dp->df_lnum[idx] + dp->df_count[idx]) {
    int zero = FALSE;

    // Changed or inserted line.  If the other buffers have a count of
    // zero, the lines were inserted.  If the other buffers have the same
    // count, check if the lines are identical.
    cmp = FALSE;

    for (i = 0; i < DB_COUNT; ++i) {
      if ((i != idx) && (curtab->tp_diffbuf[i] != NULL)) {
        if (dp->df_count[i] == 0) {
          zero = TRUE;
        } else {
          if (dp->df_count[i] != dp->df_count[idx]) {
            // nr of lines changed.
            return -1;
          }
          cmp = TRUE;
        }
      }
    }

    if (cmp) {
      // Compare all lines.  If they are equal the lines were inserted
      // in some buffers, deleted in others, but not changed.
      for (i = 0; i < DB_COUNT; ++i) {
        if ((i != idx)
            && (curtab->tp_diffbuf[i] != NULL)
            && (dp->df_count[i] != 0)) {
          if (!diff_equal_entry(dp, idx, i)) {
            return -1;
          }
        }
      }
    }

    // If there is no buffer with zero lines then there is no difference
    // any longer.  Happens when making a change (or undo) that removes
    // the difference.  Can't remove the entry here, we might be halfway
    // through updating the window.  Just report the text as unchanged.
    // Other windows might still show the change though.
    if (zero == FALSE) {
      return 0;
    }
    return -2;
  }

  // If 'diffopt' doesn't contain "filler", return 0.
  if (!(diff_flags & DIFF_FILLER)) {
    return 0;
  }

  // Insert filler lines above the line just below the change.  Will return
  // 0 when this buf had the max count.
  maxcount = 0;
  for (i = 0; i < DB_COUNT; ++i) {
    if ((curtab->tp_diffbuf[i] != NULL) && (dp->df_count[i] > maxcount)) {
      maxcount = dp->df_count[i];
    }
  }
  return maxcount - dp->df_count[idx];
}

/// Compare two entries in diff "dp" and return true if they are equal.
///
/// @param  dp    diff
/// @param  idx1  first entry in diff "dp"
/// @param  idx2  second entry in diff "dp"
///
/// @return true if two entires are equal.
static bool diff_equal_entry(diff_T *dp, int idx1, int idx2)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1)
{
  if (dp->df_count[idx1] != dp->df_count[idx2]) {
    return false;
  }

  if (diff_check_sanity(curtab, dp) == FAIL) {
    return false;
  }

  for (int i = 0; i < dp->df_count[idx1]; i++) {
    char_u *line = vim_strsave(ml_get_buf(curtab->tp_diffbuf[idx1],
                                          dp->df_lnum[idx1] + i, false));

    int cmp = diff_cmp(line, ml_get_buf(curtab->tp_diffbuf[idx2],
                                        dp->df_lnum[idx2] + i, false));
    xfree(line);

    if (cmp != 0) {
      return false;
    }
  }
  return true;
}

/// Compare strings "s1" and "s2" according to 'diffopt'.
/// Return non-zero when they are different.
///
/// @param s1 The first string
/// @param s2 The second string
///
/// @return on-zero if the two strings are different.
static int diff_cmp(char_u *s1, char_u *s2)
{
  if ((diff_flags & (DIFF_ICASE | DIFF_IWHITE)) == 0) {
    return STRCMP(s1, s2);
  }

  if ((diff_flags & DIFF_ICASE) && !(diff_flags & DIFF_IWHITE)) {
    return mb_stricmp((const char *)s1, (const char *)s2);
  }

  // Ignore white space changes and possibly ignore case.
  char_u *p1 = s1;
  char_u *p2 = s2;

  while (*p1 != NUL && *p2 != NUL) {
    if (ascii_iswhite(*p1) && ascii_iswhite(*p2)) {
      p1 = skipwhite(p1);
      p2 = skipwhite(p2);
    } else {
      int l  = (*mb_ptr2len)(p1);
      if (l != (*mb_ptr2len)(p2)) {
        break;
      }

      if (l > 1) {
        if ((STRNCMP(p1, p2, l) != 0)
            && (!enc_utf8
                || !(diff_flags & DIFF_ICASE)
                || (utf_fold(utf_ptr2char(p1))
                    != utf_fold(utf_ptr2char(p2))))) {
          break;
        }
        p1 += l;
        p2 += l;
      } else {
        if ((*p1 != *p2)
            && (!(diff_flags & DIFF_ICASE)
                || (TOLOWER_LOC(*p1) != TOLOWER_LOC(*p2)))) {
          break;
        }
        ++p1;
        ++p2;
      }
    }
  }

  // Ignore trailing white space.
  p1 = skipwhite(p1);
  p2 = skipwhite(p2);

  if ((*p1 != NUL) || (*p2 != NUL)) {
    return 1;
  }
  return 0;
}

/// Return the number of filler lines above "lnum".
///
/// @param wp
/// @param lnum
///
/// @return Number of filler lines above lnum
int diff_check_fill(win_T *wp, linenr_T lnum)
{
  // be quick when there are no filler lines
  if (!(diff_flags & DIFF_FILLER)) {
    return 0;
  }
  int n = diff_check(wp, lnum);

  if (n <= 0) {
    return 0;
  }
  return n;
}

/// Set the topline of "towin" to match the position in "fromwin", so that they
/// show the same diff'ed lines.
///
/// @param fromwin
/// @param towin
void diff_set_topline(win_T *fromwin, win_T *towin)
{
  buf_T *frombuf = fromwin->w_buffer;
  linenr_T lnum = fromwin->w_topline;
  diff_T *dp;
  int max_count;
  int i;

  int fromidx = diff_buf_idx(frombuf);
  if (fromidx == DB_COUNT) {
    // safety check
    return;
  }

  if (curtab->tp_diff_invalid) {
    // update after a big change
    ex_diffupdate(NULL);
  }
  towin->w_topfill = 0;

  // search for a change that includes "lnum" in the list of diffblocks.
  for (dp = curtab->tp_first_diff; dp != NULL; dp = dp->df_next) {
    if (lnum <= dp->df_lnum[fromidx] + dp->df_count[fromidx]) {
      break;
    }
  }

  if (dp == NULL) {
    // After last change, compute topline relative to end of file; no
    // filler lines.
    towin->w_topline = towin->w_buffer->b_ml.ml_line_count
                       - (frombuf->b_ml.ml_line_count - lnum);
  } else {
    // Find index for "towin".
    int toidx = diff_buf_idx(towin->w_buffer);

    if (toidx == DB_COUNT) {
      // safety check
      return;
    }
    towin->w_topline = lnum + (dp->df_lnum[toidx] - dp->df_lnum[fromidx]);

    if (lnum >= dp->df_lnum[fromidx]) {
      // Inside a change: compute filler lines. With three or more
      // buffers we need to know the largest count.
      max_count = 0;

      for (i = 0; i < DB_COUNT; ++i) {
        if ((curtab->tp_diffbuf[i] != NULL) && (max_count < dp->df_count[i])) {
          max_count = dp->df_count[i];
        }
      }

      if (dp->df_count[toidx] == dp->df_count[fromidx]) {
        // same number of lines: use same filler count
        towin->w_topfill = fromwin->w_topfill;
      } else if (dp->df_count[toidx] > dp->df_count[fromidx]) {
        if (lnum == dp->df_lnum[fromidx] + dp->df_count[fromidx]) {
          // more lines in towin and fromwin doesn't show diff
          // lines, only filler lines
          if (max_count - fromwin->w_topfill >= dp->df_count[toidx]) {
            // towin also only shows filler lines
            towin->w_topline = dp->df_lnum[toidx] + dp->df_count[toidx];
            towin->w_topfill = fromwin->w_topfill;
          } else {
            // towin still has some diff lines to show
            towin->w_topline = dp->df_lnum[toidx]
                               + max_count - fromwin->w_topfill;
          }
        }
      } else if (towin->w_topline >= dp->df_lnum[toidx]
                 + dp->df_count[toidx]) {
        // less lines in towin and no diff lines to show: compute
        // filler lines
        towin->w_topline = dp->df_lnum[toidx] + dp->df_count[toidx];

        if (diff_flags & DIFF_FILLER) {
          if (lnum == dp->df_lnum[fromidx] + dp->df_count[fromidx]) {
            // fromwin is also out of diff lines
            towin->w_topfill = fromwin->w_topfill;
          } else {
            // fromwin has some diff lines
            towin->w_topfill = dp->df_lnum[fromidx] + max_count - lnum;
          }
        }
      }
    }
  }

  // safety check (if diff info gets outdated strange things may happen)
  towin->w_botfill = false;

  if (towin->w_topline > towin->w_buffer->b_ml.ml_line_count) {
    towin->w_topline = towin->w_buffer->b_ml.ml_line_count;
    towin->w_botfill = true;
  }

  if (towin->w_topline < 1) {
    towin->w_topline = 1;
    towin->w_topfill = 0;
  }

  // When w_topline changes need to recompute w_botline and cursor position
  invalidate_botline_win(towin);
  changed_line_abv_curs_win(towin);

  check_topfill(towin, false);
  (void)hasFoldingWin(towin, towin->w_topline, &towin->w_topline,
                      NULL, TRUE, NULL);
}

/// This is called when 'diffopt' is changed.
///
/// @return
int diffopt_changed(void)
{
  int diff_context_new = 6;
  int diff_flags_new = 0;
  int diff_foldcolumn_new = 2;

  char_u *p = p_dip;
  while (*p != NUL) {
    if (STRNCMP(p, "filler", 6) == 0) {
      p += 6;
      diff_flags_new |= DIFF_FILLER;
    } else if ((STRNCMP(p, "context:", 8) == 0) && ascii_isdigit(p[8])) {
      p += 8;
      diff_context_new = getdigits_int(&p);
    } else if (STRNCMP(p, "icase", 5) == 0) {
      p += 5;
      diff_flags_new |= DIFF_ICASE;
    } else if (STRNCMP(p, "iwhite", 6) == 0) {
      p += 6;
      diff_flags_new |= DIFF_IWHITE;
    } else if (STRNCMP(p, "horizontal", 10) == 0) {
      p += 10;
      diff_flags_new |= DIFF_HORIZONTAL;
    } else if (STRNCMP(p, "vertical", 8) == 0) {
      p += 8;
      diff_flags_new |= DIFF_VERTICAL;
    } else if ((STRNCMP(p, "foldcolumn:", 11) == 0) && ascii_isdigit(p[11])) {
      p += 11;
      diff_foldcolumn_new = getdigits_int(&p);
    }

    if ((*p != ',') && (*p != NUL)) {
      return FAIL;
    }

    if (*p == ',') {
      ++p;
    }
  }

  // Can't have both "horizontal" and "vertical".
  if ((diff_flags_new & DIFF_HORIZONTAL) && (diff_flags_new & DIFF_VERTICAL)) {
    return FAIL;
  }

  // If "icase" or "iwhite" was added or removed, need to update the diff.
  if (diff_flags != diff_flags_new) {
    FOR_ALL_TABS(tp) {
      tp->tp_diff_invalid = TRUE;
    }
  }

  diff_flags = diff_flags_new;
  diff_context = diff_context_new;
  diff_foldcolumn = diff_foldcolumn_new;

  diff_redraw(TRUE);

  // recompute the scroll binding with the new option value, may
  // remove or add filler lines
  check_scrollbind((linenr_T)0, 0L);
  return OK;
}

/// Check that "diffopt" contains "horizontal".
bool diffopt_horizontal(void)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return (diff_flags & DIFF_HORIZONTAL) != 0;
}

/// Find the difference within a changed line.
///
/// @param  wp      window whose current buffer to check
/// @param  lnum    line number to check within the buffer
/// @param  startp  first char of the change
/// @param  endp    last char of the change
///
/// @return true if the line was added, no other buffer has it.
bool diff_find_change(win_T *wp, linenr_T lnum, int *startp, int *endp)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  char_u *line_new;
  int si_org;
  int si_new;
  int ei_org;
  int ei_new;
  bool added = true;

  // Make a copy of the line, the next ml_get() will invalidate it.
  char_u *line_org = vim_strsave(ml_get_buf(wp->w_buffer, lnum, FALSE));

  int idx = diff_buf_idx(wp->w_buffer);
  if (idx == DB_COUNT) {
    // cannot happen
    xfree(line_org);
    return false;
  }

  // search for a change that includes "lnum" in the list of diffblocks.
  diff_T *dp;
  for (dp = curtab->tp_first_diff; dp != NULL; dp = dp->df_next) {
    if (lnum <= dp->df_lnum[idx] + dp->df_count[idx]) {
      break;
    }
  }

  if ((dp == NULL) || (diff_check_sanity(curtab, dp) == FAIL)) {
    xfree(line_org);
    return false;
  }

  int off = lnum - dp->df_lnum[idx];
  int i;
  for (i = 0; i < DB_COUNT; ++i) {
    if ((curtab->tp_diffbuf[i] != NULL) && (i != idx)) {
      // Skip lines that are not in the other change (filler lines).
      if (off >= dp->df_count[i]) {
        continue;
      }
      added = false;
      line_new = ml_get_buf(curtab->tp_diffbuf[i],
                            dp->df_lnum[i] + off, FALSE);

      // Search for start of difference
      si_org = si_new = 0;

      while (line_org[si_org] != NUL) {
        if ((diff_flags & DIFF_IWHITE)
            && ascii_iswhite(line_org[si_org])
            && ascii_iswhite(line_new[si_new])) {
          si_org = (int)(skipwhite(line_org + si_org) - line_org);
          si_new = (int)(skipwhite(line_new + si_new) - line_new);
        } else {
          if (line_org[si_org] != line_new[si_new]) {
            break;
          }
          ++si_org;
          ++si_new;
        }
      }

      if (has_mbyte) {
        // Move back to first byte of character in both lines (may
        // have "nn^" in line_org and "n^ in line_new).
        si_org -= (*mb_head_off)(line_org, line_org + si_org);
        si_new -= (*mb_head_off)(line_new, line_new + si_new);
      }

      if (*startp > si_org) {
        *startp = si_org;
      }

      // Search for end of difference, if any.
      if ((line_org[si_org] != NUL) || (line_new[si_new] != NUL)) {
        ei_org = (int)STRLEN(line_org);
        ei_new = (int)STRLEN(line_new);

        while (ei_org >= *startp
               && ei_new >= si_new
               && ei_org >= 0
               && ei_new >= 0) {
          if ((diff_flags & DIFF_IWHITE)
              && ascii_iswhite(line_org[ei_org])
              && ascii_iswhite(line_new[ei_new])) {
            while (ei_org >= *startp && ascii_iswhite(line_org[ei_org])) {
              ei_org--;
            }

            while (ei_new >= si_new && ascii_iswhite(line_new[ei_new])) {
              ei_new--;
            }
          } else {
            if (line_org[ei_org] != line_new[ei_new]) {
              break;
            }
            ei_org--;
            ei_new--;
          }
        }

        if (*endp < ei_org) {
          *endp = ei_org;
        }
      }
    }
  }

  xfree(line_org);
  return added;
}

/// Check that line "lnum" is not close to a diff block, this line should
/// be in a fold.
///
/// @param  wp    window containing the buffer to check
/// @param  lnum  line number to check within the buffer
///
/// @return false if there are no diff blocks at all in this window.
bool diff_infold(win_T *wp, linenr_T lnum)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1)
{
  bool other = false;
  diff_T *dp;

  // Return if 'diff' isn't set.
  if (!wp->w_p_diff) {
    return false;
  }

  int idx = -1;
  int i;
  for (i = 0; i < DB_COUNT; ++i) {
    if (curtab->tp_diffbuf[i] == wp->w_buffer) {
      idx = i;
    } else if (curtab->tp_diffbuf[i] != NULL) {
      other = true;
    }
  }

  // return here if there are no diffs in the window
  if ((idx == -1) || !other) {
    return false;
  }

  if (curtab->tp_diff_invalid) {
    // update after a big change
    ex_diffupdate(NULL);
  }

  // Return if there are no diff blocks.  All lines will be folded.
  if (curtab->tp_first_diff == NULL) {
    return true;
  }

  for (dp = curtab->tp_first_diff; dp != NULL; dp = dp->df_next) {
    // If this change is below the line there can't be any further match.
    if (dp->df_lnum[idx] - diff_context > lnum) {
      break;
    }

    // If this change ends before the line we have a match.
    if (dp->df_lnum[idx] + dp->df_count[idx] + diff_context > lnum) {
      return false;
    }
  }
  return true;
}

/// "dp" and "do" commands.
void nv_diffgetput(bool put, size_t count)
{
  exarg_T ea;
  char buf[30];

  if (count == 0) {
    ea.arg = (char_u *)"";
  } else {
    vim_snprintf(buf, 30, "%zu", count);
    ea.arg = (char_u *)buf;
  }

  if (put) {
    ea.cmdidx = CMD_diffput;
  } else {
    ea.cmdidx = CMD_diffget;
  }

  ea.addr_count = 0;
  ea.line1 = curwin->w_cursor.lnum;
  ea.line2 = curwin->w_cursor.lnum;
  ex_diffgetput(&ea);
}

/// ":diffget" and ":diffput"
///
/// @param eap
void ex_diffgetput(exarg_T *eap)
{
  linenr_T lnum;
  int count;
  linenr_T off = 0;
  diff_T *dp;
  diff_T *dprev;
  diff_T *dfree;
  int i;
  int added;
  char_u *p;
  aco_save_T aco;
  buf_T *buf;
  int start_skip, end_skip;
  int new_count;
  int buf_empty;
  int found_not_ma = FALSE;
  int idx_other;
  int idx_from;
  int idx_to;

  // Find the current buffer in the list of diff buffers.
  int idx_cur = diff_buf_idx(curbuf);
  if (idx_cur == DB_COUNT) {
    EMSG(_("E99: Current buffer is not in diff mode"));
    return;
  }

  if (*eap->arg == NUL) {
    // No argument: Find the other buffer in the list of diff buffers.
    for (idx_other = 0; idx_other < DB_COUNT; ++idx_other) {
      if ((curtab->tp_diffbuf[idx_other] != curbuf)
          && (curtab->tp_diffbuf[idx_other] != NULL)) {
        if ((eap->cmdidx != CMD_diffput)
            || MODIFIABLE(curtab->tp_diffbuf[idx_other])) {
          break;
        }
        found_not_ma = TRUE;
      }
    }

    if (idx_other == DB_COUNT) {
      if (found_not_ma) {
        EMSG(_("E793: No other buffer in diff mode is modifiable"));
      } else {
        EMSG(_("E100: No other buffer in diff mode"));
      }
      return;
    }

    // Check that there isn't a third buffer in the list
    for (i = idx_other + 1; i < DB_COUNT; ++i) {
      if ((curtab->tp_diffbuf[i] != curbuf)
          && (curtab->tp_diffbuf[i] != NULL)
          && ((eap->cmdidx != CMD_diffput)
            || MODIFIABLE(curtab->tp_diffbuf[i]))) {
        EMSG(_("E101: More than two buffers in diff mode, don't know "
               "which one to use"));
        return;
      }
    }
  } else {
    // Buffer number or pattern given. Ignore trailing white space.
    p = eap->arg + STRLEN(eap->arg);
    while (p > eap->arg && ascii_iswhite(p[-1])) {
      p--;
    }

    for (i = 0; ascii_isdigit(eap->arg[i]) && eap->arg + i < p; ++i) {
    }

    if (eap->arg + i == p) {
      // digits only
      i = atol((char *)eap->arg);
    } else {
      i = buflist_findpat(eap->arg, p, FALSE, TRUE, FALSE);

      if (i < 0) {
        // error message already given
        return;
      }
    }
    buf = buflist_findnr(i);

    if (buf == NULL) {
      EMSG2(_("E102: Can't find buffer \"%s\""), eap->arg);
      return;
    }

    if (buf == curbuf) {
      // nothing to do
      return;
    }
    idx_other = diff_buf_idx(buf);

    if (idx_other == DB_COUNT) {
      EMSG2(_("E103: Buffer \"%s\" is not in diff mode"), eap->arg);
      return;
    }
  }

  diff_busy = TRUE;

  // When no range given include the line above or below the cursor.
  if (eap->addr_count == 0) {
    // Make it possible that ":diffget" on the last line gets line below
    // the cursor line when there is no difference above the cursor.
    if ((eap->cmdidx == CMD_diffget)
        && (eap->line1 == curbuf->b_ml.ml_line_count)
        && (diff_check(curwin, eap->line1) == 0)
        && ((eap->line1 == 1) || (diff_check(curwin, eap->line1 - 1) == 0))) {
      ++eap->line2;
    } else if (eap->line1 > 0) {
      --eap->line1;
    }
  }

  if (eap->cmdidx == CMD_diffget) {
    idx_from = idx_other;
    idx_to = idx_cur;
  } else {
    idx_from = idx_cur;
    idx_to = idx_other;

    // Need to make the other buffer the current buffer to be able to make
    // changes in it.

    // set curwin/curbuf to buf and save a few things
    aucmd_prepbuf(&aco, curtab->tp_diffbuf[idx_other]);
  }

  // May give the warning for a changed buffer here, which can trigger the
  // FileChangedRO autocommand, which may do nasty things and mess
  // everything up.
  if (!curbuf->b_changed) {
    change_warning(0);
    if (diff_buf_idx(curbuf) != idx_to) {
      EMSG(_("E787: Buffer changed unexpectedly"));
      return;
    }
  }

  dprev = NULL;

  for (dp = curtab->tp_first_diff; dp != NULL;) {
    if (dp->df_lnum[idx_cur] > eap->line2 + off) {
      // past the range that was specified
      break;
    }
    dfree = NULL;
    lnum = dp->df_lnum[idx_to];
    count = dp->df_count[idx_to];

    if ((dp->df_lnum[idx_cur] + dp->df_count[idx_cur] > eap->line1 + off)
        && (u_save(lnum - 1, lnum + count) != FAIL)) {
      // Inside the specified range and saving for undo worked.
      start_skip = 0;
      end_skip = 0;

      if (eap->addr_count > 0) {
        // A range was specified: check if lines need to be skipped.
        start_skip = eap->line1 + off - dp->df_lnum[idx_cur];
        if (start_skip > 0) {
          // range starts below start of current diff block
          if (start_skip > count) {
            lnum += count;
            count = 0;
          } else {
            count -= start_skip;
            lnum += start_skip;
          }
        } else {
          start_skip = 0;
        }

        end_skip = dp->df_lnum[idx_cur] + dp->df_count[idx_cur] - 1
                   - (eap->line2 + off);

        if (end_skip > 0) {
          // range ends above end of current/from diff block
          if (idx_cur == idx_from) {
            // :diffput
            i = dp->df_count[idx_cur] - start_skip - end_skip;

            if (count > i) {
              count = i;
            }
          } else {
            // :diffget
            count -= end_skip;
            end_skip = dp->df_count[idx_from] - start_skip - count;

            if (end_skip < 0) {
              end_skip = 0;
            }
          }
        } else {
          end_skip = 0;
        }
      }

      buf_empty = BUFEMPTY();
      added = 0;

      for (i = 0; i < count; ++i) {
        // remember deleting the last line of the buffer
        buf_empty = curbuf->b_ml.ml_line_count == 1;
        ml_delete(lnum, FALSE);
        added--;
      }

      for (i = 0; i < dp->df_count[idx_from] - start_skip - end_skip; ++i) {
        linenr_T nr = dp->df_lnum[idx_from] + start_skip + i;
        if (nr > curtab->tp_diffbuf[idx_from]->b_ml.ml_line_count) {
          break;
        }
        p = vim_strsave(ml_get_buf(curtab->tp_diffbuf[idx_from], nr, FALSE));
        ml_append(lnum + i - 1, p, 0, FALSE);
        xfree(p);
        added++;
        if (buf_empty && (curbuf->b_ml.ml_line_count == 2)) {
          // Added the first line into an empty buffer, need to
          // delete the dummy empty line.
          buf_empty = FALSE;
          ml_delete((linenr_T)2, FALSE);
        }
      }
      new_count = dp->df_count[idx_to] + added;
      dp->df_count[idx_to] = new_count;

      if ((start_skip == 0) && (end_skip == 0)) {
        // Check if there are any other buffers and if the diff is
        // equal in them.
        for (i = 0; i < DB_COUNT; ++i) {
          if ((curtab->tp_diffbuf[i] != NULL)
              && (i != idx_from)
              && (i != idx_to)
              && !diff_equal_entry(dp, idx_from, i)) {
            break;
          }
        }

        if (i == DB_COUNT) {
          // delete the diff entry, the buffers are now equal here
          dfree = dp;
          dp = dp->df_next;

          if (dprev == NULL) {
            curtab->tp_first_diff = dp;
          } else {
            dprev->df_next = dp;
          }
        }
      }

      // Adjust marks.  This will change the following entries!
      if (added != 0) {
        mark_adjust(lnum, lnum + count - 1, (long)MAXLNUM, (long)added, false);
        if (curwin->w_cursor.lnum >= lnum) {
          // Adjust the cursor position if it's in/after the changed
          // lines.
          if (curwin->w_cursor.lnum >= lnum + count) {
            curwin->w_cursor.lnum += added;
          } else if (added < 0) {
            curwin->w_cursor.lnum = lnum;
          }
        }
      }
      changed_lines(lnum, 0, lnum + count, (long)added);

      if (dfree != NULL) {
        // Diff is deleted, update folds in other windows.
        diff_fold_update(dfree, idx_to);
        xfree(dfree);
      } else {
        // mark_adjust() may have changed the count in a wrong way
        dp->df_count[idx_to] = new_count;
      }

      // When changing the current buffer, keep track of line numbers
      if (idx_cur == idx_to) {
        off += added;
      }
    }

    // If before the range or not deleted, go to next diff.
    if (dfree == NULL) {
      dprev = dp;
      dp = dp->df_next;
    }
  }

  // restore curwin/curbuf and a few other things
  if (eap->cmdidx != CMD_diffget) {
    // Syncing undo only works for the current buffer, but we change
    // another buffer.  Sync undo if the command was typed.  This isn't
    // 100% right when ":diffput" is used in a function or mapping.
    if (KeyTyped) {
      u_sync(FALSE);
    }
    aucmd_restbuf(&aco);
  }

  diff_busy = FALSE;

  // Check that the cursor is on a valid character and update it's position.
  // When there were filler lines the topline has become invalid.
  check_cursor();
  changed_line_abv_curs();

  // Also need to redraw the other buffers.
  diff_redraw(FALSE);
}

/// Update folds for all diff buffers for entry "dp".
///
/// Skip buffer with index "skip_idx".
/// When there are no diffs, all folds are removed.
///
/// @param dp
/// @param skip_idx
static void diff_fold_update(diff_T *dp, int skip_idx)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    for (int i = 0; i < DB_COUNT; ++i) {
      if ((curtab->tp_diffbuf[i] == wp->w_buffer) && (i != skip_idx)) {
        foldUpdate(wp, dp->df_lnum[i], dp->df_lnum[i] + dp->df_count[i]);
      }
    }
  }
}

/// Checks that the buffer is in diff-mode.
///
/// @param  buf  buffer to check.
bool diff_mode_buf(buf_T *buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1)
{
  FOR_ALL_TABS(tp) {
    if (diff_buf_idx_tp(buf, tp) != DB_COUNT) {
      return true;
    }
  }
  return false;
}

/// Move "count" times in direction "dir" to the next diff block.
///
/// @param dir
/// @param count
///
/// @return FAIL if there isn't such a diff block.
int diff_move_to(int dir, long count)
{
  linenr_T lnum = curwin->w_cursor.lnum;
  int idx = diff_buf_idx(curbuf);
  if ((idx == DB_COUNT) || (curtab->tp_first_diff == NULL)) {
    return FAIL;
  }

  if (curtab->tp_diff_invalid) {
    // update after a big change
    ex_diffupdate(NULL);
  }

  if (curtab->tp_first_diff == NULL) {
    // no diffs today
    return FAIL;
  }

  while (--count >= 0) {
    // Check if already before first diff.
    if ((dir == BACKWARD) && (lnum <= curtab->tp_first_diff->df_lnum[idx])) {
      break;
    }

    diff_T *dp;
    for (dp = curtab->tp_first_diff;; dp = dp->df_next) {
      if (dp == NULL) {
        break;
      }

      if (((dir == FORWARD) && (lnum < dp->df_lnum[idx]))
          || ((dir == BACKWARD)
              && ((dp->df_next == NULL)
                  || (lnum <= dp->df_next->df_lnum[idx])))) {
        lnum = dp->df_lnum[idx];
        break;
      }
    }
  }

  // don't end up past the end of the file
  if (lnum > curbuf->b_ml.ml_line_count) {
    lnum = curbuf->b_ml.ml_line_count;
  }

  // When the cursor didn't move at all we fail.
  if (lnum == curwin->w_cursor.lnum) {
    return FAIL;
  }

  setpcmark();
  curwin->w_cursor.lnum = lnum;
  curwin->w_cursor.col = 0;

  return OK;
}

/// Return the line number in the current window that is closest to "lnum1" in
/// "buf1" in diff mode.
static linenr_T diff_get_corresponding_line_int(buf_T *buf1, linenr_T lnum1)
{
  int idx1;
  int idx2;
  diff_T *dp;
  int baseline = 0;

  idx1 = diff_buf_idx(buf1);
  idx2 = diff_buf_idx(curbuf);

  if ((idx1 == DB_COUNT)
      || (idx2 == DB_COUNT)
      || (curtab->tp_first_diff == NULL)) {
    return lnum1;
  }

  if (curtab->tp_diff_invalid) {
    // update after a big change
    ex_diffupdate(NULL);
  }

  if (curtab->tp_first_diff == NULL) {
    // no diffs today
    return lnum1;
  }

  for (dp = curtab->tp_first_diff; dp != NULL; dp = dp->df_next) {
    if (dp->df_lnum[idx1] > lnum1) {
      return lnum1 - baseline;
    }
    if ((dp->df_lnum[idx1] + dp->df_count[idx1]) > lnum1) {
      // Inside the diffblock
      baseline = lnum1 - dp->df_lnum[idx1];

      if (baseline > dp->df_count[idx2]) {
        baseline = dp->df_count[idx2];
      }

      return dp->df_lnum[idx2] + baseline;
    }
    if ((dp->df_lnum[idx1] == lnum1)
        && (dp->df_count[idx1] == 0)
        && (dp->df_lnum[idx2] <= curwin->w_cursor.lnum)
        && ((dp->df_lnum[idx2] + dp->df_count[idx2])
            > curwin->w_cursor.lnum)) {
      // Special case: if the cursor is just after a zero-count
      // block (i.e. all filler) and the target cursor is already
      // inside the corresponding block, leave the target cursor
      // unmoved. This makes repeated CTRL-W W operations work
      // as expected.
      return curwin->w_cursor.lnum;
    }
    baseline = (dp->df_lnum[idx1] + dp->df_count[idx1])
                - (dp->df_lnum[idx2] + dp->df_count[idx2]);
  }

  // If we get here then the cursor is after the last diff
  return lnum1 - baseline;
}

/// Finds the corresponding line in a diff.
///
/// @param buf1
/// @param lnum1
///
/// @return The corresponding line.
linenr_T diff_get_corresponding_line(buf_T *buf1, linenr_T lnum1)
{
  linenr_T lnum = diff_get_corresponding_line_int(buf1, lnum1);

  // don't end up past the end of the file
  if (lnum > curbuf->b_ml.ml_line_count) {
    return curbuf->b_ml.ml_line_count;
  }
  return lnum;
}

/// For line "lnum" in the current window find the equivalent lnum in window
/// "wp", compensating for inserted/deleted lines.
linenr_T diff_lnum_win(linenr_T lnum, win_T *wp)
{
  diff_T *dp;
  int idx;
  int i;
  linenr_T n;

  idx = diff_buf_idx(curbuf);

  if (idx == DB_COUNT) {
    // safety check
    return (linenr_T)0;
  }

  if (curtab->tp_diff_invalid) {
    // update after a big change
    ex_diffupdate(NULL);
  }

  // search for a change that includes "lnum" in the list of diffblocks.
  for (dp = curtab->tp_first_diff; dp != NULL; dp = dp->df_next) {
    if (lnum <= dp->df_lnum[idx] + dp->df_count[idx]) {
      break;
    }
  }

  // When after the last change, compute relative to the last line number.
  if (dp == NULL) {
    return wp->w_buffer->b_ml.ml_line_count
           - (curbuf->b_ml.ml_line_count - lnum);
  }

  // Find index for "wp".
  i = diff_buf_idx(wp->w_buffer);

  if (i == DB_COUNT) {
    // safety check
    return (linenr_T)0;
  }

  n = lnum + (dp->df_lnum[i] - dp->df_lnum[idx]);
  if (n > dp->df_lnum[i] + dp->df_count[i]) {
    n = dp->df_lnum[i] + dp->df_count[i];
  }
  return n;
}
