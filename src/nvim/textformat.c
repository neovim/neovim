// textformat.c: text formatting functions

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/getchar.h"
#include "nvim/globals.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/macros_defs.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/os/input.h"
#include "nvim/pos_defs.h"
#include "nvim/search.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/textformat.h"
#include "nvim/textobject.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "textformat.c.generated.h"
#endif

static bool did_add_space = false;  ///< auto_format() added an extra space
                                    ///< under the cursor

#define WHITECHAR(cc) (ascii_iswhite(cc) \
                       && !utf_iscomposing_first(utf_ptr2char((char *)get_cursor_pos_ptr() + 1)))

/// Return true if format option 'x' is in effect.
/// Take care of no formatting when 'paste' is set.
bool has_format_option(int x)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (p_paste) {
    return false;
  }
  return vim_strchr(curbuf->b_p_fo, x) != NULL;
}

/// Format text at the current insert position.
///
/// If the INSCHAR_COM_LIST flag is present, then the value of second_indent
/// will be the comment leader length sent to open_line().
///
/// @param c  character to be inserted (can be NUL)
void internal_format(int textwidth, int second_indent, int flags, bool format_only, int c)
{
  int cc;
  char save_char = NUL;
  bool haveto_redraw = false;
  const bool fo_ins_blank = has_format_option(FO_INS_BLANK);
  const bool fo_multibyte = has_format_option(FO_MBYTE_BREAK);
  const bool fo_rigor_tw = has_format_option(FO_RIGOROUS_TW);
  const bool fo_white_par = has_format_option(FO_WHITE_PAR);
  bool first_line = true;
  colnr_T leader_len;
  bool no_leader = false;
  bool do_comments = (flags & INSCHAR_DO_COM);
  int has_lbr = curwin->w_p_lbr;

  // make sure win_charsize() counts correctly
  curwin->w_p_lbr = false;

  // When 'ai' is off we don't want a space under the cursor to be
  // deleted.  Replace it with an 'x' temporarily.
  if (!curbuf->b_p_ai && !(State & VREPLACE_FLAG)) {
    cc = gchar_cursor();
    if (ascii_iswhite(cc)) {
      save_char = (char)cc;
      pchar_cursor('x');
    }
  }

  // Repeat breaking lines, until the current line is not too long.
  while (!got_int) {
    int startcol;                       // Cursor column at entry
    int wantcol;                        // column at textwidth border
    int foundcol;                       // column for start of spaces
    int end_foundcol = 0;               // column for start of word
    int orig_col = 0;
    char *saved_text = NULL;
    colnr_T col;
    bool did_do_comment = false;

    colnr_T virtcol = get_nolist_virtcol() + char2cells(c != NUL ? c : gchar_cursor());
    if (virtcol <= (colnr_T)textwidth) {
      break;
    }

    if (no_leader) {
      do_comments = false;
    } else if (!(flags & INSCHAR_FORMAT)
               && has_format_option(FO_WRAP_COMS)) {
      do_comments = true;
    }

    // Don't break until after the comment leader
    if (do_comments) {
      char *line = get_cursor_line_ptr();
      leader_len = get_leader_len(line, NULL, false, true);
      if (leader_len == 0 && curbuf->b_p_cin) {
        // Check for a line comment after code.
        int comment_start = check_linecomment(line);
        if (comment_start != MAXCOL) {
          leader_len = get_leader_len(line + comment_start, NULL, false, true);
          if (leader_len != 0) {
            leader_len += comment_start;
          }
        }
      }
    } else {
      leader_len = 0;
    }

    // If the line doesn't start with a comment leader, then don't
    // start one in a following broken line.  Avoids that a %word
    // moved to the start of the next line causes all following lines
    // to start with %.
    if (leader_len == 0) {
      no_leader = true;
    }
    if (!(flags & INSCHAR_FORMAT)
        && leader_len == 0
        && !has_format_option(FO_WRAP)) {
      break;
    }
    if ((startcol = curwin->w_cursor.col) == 0) {
      break;
    }

    // find column of textwidth border
    coladvance(curwin, (colnr_T)textwidth);
    wantcol = curwin->w_cursor.col;

    curwin->w_cursor.col = startcol;
    foundcol = 0;
    int skip_pos = 0;

    // Find position to break at.
    // Stop at first entered white when 'formatoptions' has 'v'
    while ((!fo_ins_blank && !has_format_option(FO_INS_VI))
           || (flags & INSCHAR_FORMAT)
           || curwin->w_cursor.lnum != Insstart.lnum
           || curwin->w_cursor.col >= Insstart.col) {
      if (curwin->w_cursor.col == startcol && c != NUL) {
        cc = c;
      } else {
        cc = gchar_cursor();
      }
      if (WHITECHAR(cc)) {
        // remember position of blank just before text
        colnr_T end_col = curwin->w_cursor.col;

        // find start of sequence of blanks
        int wcc = 0;  // counter for whitespace chars
        while (curwin->w_cursor.col > 0 && WHITECHAR(cc)) {
          dec_cursor();
          cc = gchar_cursor();

          // Increment count of how many whitespace chars in this
          // group; we only need to know if it's more than one.
          if (wcc < 2) {
            wcc++;
          }
        }
        if (curwin->w_cursor.col == 0 && WHITECHAR(cc)) {
          break;                        // only spaces in front of text
        }

        // Don't break after a period when 'formatoptions' has 'p' and
        // there are less than two spaces.
        if (has_format_option(FO_PERIOD_ABBR) && cc == '.' && wcc < 2) {
          continue;
        }

        // Don't break until after the comment leader
        if (curwin->w_cursor.col < leader_len) {
          break;
        }

        if (has_format_option(FO_ONE_LETTER)) {
          // do not break after one-letter words
          if (curwin->w_cursor.col == 0) {
            break;              // one-letter word at begin
          }
          // do not break "#a b" when 'tw' is 2
          if (curwin->w_cursor.col <= leader_len) {
            break;
          }
          col = curwin->w_cursor.col;
          dec_cursor();
          cc = gchar_cursor();

          if (WHITECHAR(cc)) {
            continue;                   // one-letter, continue
          }
          curwin->w_cursor.col = col;
        }

        inc_cursor();

        end_foundcol = end_col + 1;
        foundcol = curwin->w_cursor.col;
        if (curwin->w_cursor.col <= (colnr_T)wantcol) {
          break;
        }
      } else if ((cc >= 0x100 || !utf_allow_break_before(cc)) && fo_multibyte) {
        int ncc;
        bool allow_break;

        // Break after or before a multi-byte character.
        if (curwin->w_cursor.col != startcol) {
          // Don't break until after the comment leader
          if (curwin->w_cursor.col < leader_len) {
            break;
          }
          col = curwin->w_cursor.col;
          inc_cursor();
          ncc = gchar_cursor();
          allow_break = utf_allow_break(cc, ncc);

          // If we have already checked this position, skip!
          if (curwin->w_cursor.col != skip_pos && allow_break) {
            foundcol = curwin->w_cursor.col;
            end_foundcol = foundcol;
            if (curwin->w_cursor.col <= (colnr_T)wantcol) {
              break;
            }
          }
          curwin->w_cursor.col = col;
        }

        if (curwin->w_cursor.col == 0) {
          break;
        }

        ncc = cc;
        col = curwin->w_cursor.col;

        dec_cursor();
        cc = gchar_cursor();

        if (WHITECHAR(cc)) {
          continue;                     // break with space
        }
        // Don't break until after the comment leader.
        if (curwin->w_cursor.col < leader_len) {
          break;
        }

        curwin->w_cursor.col = col;
        skip_pos = curwin->w_cursor.col;

        allow_break = utf_allow_break(cc, ncc);

        // Must handle this to respect line break prohibition.
        if (allow_break) {
          foundcol = curwin->w_cursor.col;
          end_foundcol = foundcol;
        }
        if (curwin->w_cursor.col <= (colnr_T)wantcol) {
          const bool ncc_allow_break = utf_allow_break_before(ncc);

          if (allow_break) {
            break;
          }
          if (!ncc_allow_break && !fo_rigor_tw) {
            // Enable at most 1 punct hang outside of textwidth.
            if (curwin->w_cursor.col == startcol) {
              // We are inserting a non-breakable char, postpone
              // line break check to next insert.
              end_foundcol = foundcol = 0;
              break;
            }

            // Neither cc nor ncc is NUL if we are here, so
            // it's safe to inc_cursor.
            col = curwin->w_cursor.col;

            inc_cursor();
            cc = ncc;
            ncc = gchar_cursor();
            // handle insert
            ncc = (ncc != NUL) ? ncc : c;

            allow_break = utf_allow_break(cc, ncc);

            if (allow_break) {
              // Break only when we are not at end of line.
              end_foundcol = foundcol = ncc == NUL ? 0 : curwin->w_cursor.col;
              break;
            }
            curwin->w_cursor.col = col;
          }
        }
      }
      if (curwin->w_cursor.col == 0) {
        break;
      }
      dec_cursor();
    }

    if (foundcol == 0) {                // no spaces, cannot break line
      curwin->w_cursor.col = startcol;
      break;
    }

    // Going to break the line, remove any "$" now.
    undisplay_dollar();

    // Offset between cursor position and line break is used by replace
    // stack functions.  MODE_VREPLACE does not use this, and backspaces
    // over the text instead.
    if (State & VREPLACE_FLAG) {
      orig_col = startcol;              // Will start backspacing from here
    } else {
      replace_offset = startcol - end_foundcol;
    }

    // adjust startcol for spaces that will be deleted and
    // characters that will remain on top line
    curwin->w_cursor.col = foundcol;
    while ((cc = gchar_cursor(), WHITECHAR(cc))
           && (!fo_white_par || curwin->w_cursor.col < startcol)) {
      inc_cursor();
    }
    startcol -= curwin->w_cursor.col;
    startcol = MAX(startcol, 0);

    if (State & VREPLACE_FLAG) {
      // In MODE_VREPLACE state, we will backspace over the text to be
      // wrapped, so save a copy now to put on the next line.
      saved_text = xstrnsave(get_cursor_pos_ptr(), (size_t)get_cursor_pos_len());
      curwin->w_cursor.col = orig_col;
      saved_text[startcol] = NUL;

      // Backspace over characters that will move to the next line
      if (!fo_white_par) {
        backspace_until_column(foundcol);
      }
    } else {
      // put cursor after pos. to break line
      if (!fo_white_par) {
        curwin->w_cursor.col = foundcol;
      }
    }

    // Split the line just before the margin.
    // Only insert/delete lines, but don't really redraw the window.
    open_line(FORWARD, OPENLINE_DELSPACES + OPENLINE_MARKFIX
              + (fo_white_par ? OPENLINE_KEEPTRAIL : 0)
              + (do_comments ? OPENLINE_DO_COM : 0)
              + OPENLINE_FORMAT
              + ((flags & INSCHAR_COM_LIST) ? OPENLINE_COM_LIST : 0),
              ((flags & INSCHAR_COM_LIST) ? second_indent : old_indent),
              &did_do_comment);
    if (!(flags & INSCHAR_COM_LIST)) {
      old_indent = 0;
    }

    // If a comment leader was inserted, may also do this on a following
    // line.
    if (did_do_comment) {
      no_leader = false;
    }

    replace_offset = 0;
    if (first_line) {
      if (!(flags & INSCHAR_COM_LIST)) {
        // This section is for auto-wrap of numeric lists.  When not
        // in insert mode (i.e. format_lines()), the INSCHAR_COM_LIST
        // flag will be set and open_line() will handle it (as seen
        // above).  The code here (and in get_number_indent()) will
        // recognize comments if needed...
        if (second_indent < 0 && has_format_option(FO_Q_NUMBER)) {
          second_indent = get_number_indent(curwin->w_cursor.lnum - 1);
        }
        if (second_indent >= 0) {
          if (State & VREPLACE_FLAG) {
            change_indent(INDENT_SET, second_indent, false, true);
          } else if (leader_len > 0 && second_indent - leader_len > 0) {
            int padding = second_indent - leader_len;

            // We started at the first_line of a numbered list
            // that has a comment.  the open_line() function has
            // inserted the proper comment leader and positioned
            // the cursor at the end of the split line.  Now we
            // add the additional whitespace needed after the
            // comment leader for the numbered list.
            for (int i = 0; i < padding; i++) {
              ins_str(S_LEN(" "));
            }
          } else {
            set_indent(second_indent, SIN_CHANGED);
          }
        }
      }
      first_line = false;
    }

    if (State & VREPLACE_FLAG) {
      // In MODE_VREPLACE state we have backspaced over the text to be
      // moved, now we re-insert it into the new line.
      ins_bytes(saved_text);
      xfree(saved_text);
    } else {
      // Check if cursor is not past the NUL off the line, cindent
      // may have added or removed indent.
      curwin->w_cursor.col += startcol;
      colnr_T len = get_cursor_line_len();
      curwin->w_cursor.col = MIN(curwin->w_cursor.col, len);
    }

    haveto_redraw = true;
    set_can_cindent(true);
    // moved the cursor, don't autoindent or cindent now
    did_ai = false;
    did_si = false;
    can_si = false;
    can_si_back = false;
    line_breakcheck();
  }

  if (save_char != NUL) {               // put back space after cursor
    pchar_cursor(save_char);
  }

  curwin->w_p_lbr = has_lbr;

  if (!format_only && haveto_redraw) {
    update_topline(curwin);
    redraw_curbuf_later(UPD_VALID);
  }
}

/// Blank lines, and lines containing only the comment leader, are left
/// untouched by the formatting.  The function returns true in this
/// case.  It also returns true when a line starts with the end of a comment
/// ('e' in comment flags), so that this line is skipped, and not joined to the
/// previous line.  A new paragraph starts after a blank line, or when the
/// comment leader changes.
static int fmt_check_par(linenr_T lnum, int *leader_len, char **leader_flags, bool do_comments)
{
  char *flags = NULL;        // init for GCC
  char *ptr = ml_get(lnum);
  if (do_comments) {
    *leader_len = get_leader_len(ptr, leader_flags, false, true);
  } else {
    *leader_len = 0;
  }

  if (*leader_len > 0) {
    // Search for 'e' flag in comment leader flags.
    flags = *leader_flags;
    while (*flags && *flags != ':' && *flags != COM_END) {
      flags++;
    }
  }

  return *skipwhite(ptr + *leader_len) == NUL
         || (*leader_len > 0 && *flags == COM_END)
         || startPS(lnum, NUL, false);
}

/// @return  true if line "lnum" ends in a white character.
static bool ends_in_white(linenr_T lnum)
{
  char *s = ml_get(lnum);

  if (*s == NUL) {
    return false;
  }
  colnr_T l = ml_get_len(lnum) - 1;
  return ascii_iswhite((uint8_t)s[l]);
}

/// @return  true if the two comment leaders given are the same.
///
/// @param lnum  The first line.  White-space is ignored.
///
/// @note the whole of 'leader1' must match 'leader2_len' characters from 'leader2'.
static bool same_leader(linenr_T lnum, int leader1_len, char *leader1_flags, int leader2_len,
                        char *leader2_flags)
{
  int idx1 = 0;
  int idx2 = 0;

  if (leader1_len == 0) {
    return leader2_len == 0;
  }

  // If first leader has 'f' flag, the lines can be joined only if the
  // second line does not have a leader.
  // If first leader has 'e' flag, the lines can never be joined.
  // If first leader has 's' flag, the lines can only be joined if there is
  // some text after it and the second line has the 'm' flag.
  if (leader1_flags != NULL) {
    for (char *p = leader1_flags; *p && *p != ':'; p++) {
      if (*p == COM_FIRST) {
        return leader2_len == 0;
      }
      if (*p == COM_END) {
        return false;
      }
      if (*p == COM_START) {
        int line_len = ml_get_len(lnum);
        if (line_len <= leader1_len) {
          return false;
        }
        if (leader2_flags == NULL || leader2_len == 0) {
          return false;
        }
        for (p = leader2_flags; *p && *p != ':'; p++) {
          if (*p == COM_MIDDLE) {
            return true;
          }
        }
        return false;
      }
    }
  }

  // Get current line and next line, compare the leaders.
  // The first line has to be saved, only one line can be locked at a time.
  char *line1 = xstrnsave(ml_get(lnum), (size_t)ml_get_len(lnum));
  for (idx1 = 0; ascii_iswhite(line1[idx1]); idx1++) {}
  char *line2 = ml_get(lnum + 1);
  for (idx2 = 0; idx2 < leader2_len; idx2++) {
    if (!ascii_iswhite(line2[idx2])) {
      if (line1[idx1++] != line2[idx2]) {
        break;
      }
    } else {
      while (ascii_iswhite(line1[idx1])) {
        idx1++;
      }
    }
  }
  xfree(line1);

  return idx2 == leader2_len && idx1 == leader1_len;
}

/// Used for auto-formatting.
///
/// @return  true when a paragraph starts in line "lnum".
///          false when the previous line is in the same paragraph.
static bool paragraph_start(linenr_T lnum)
{
  int leader_len = 0;                // leader len of current line
  char *leader_flags = NULL;         // flags for leader of current line
  int next_leader_len = 0;           // leader len of next line
  char *next_leader_flags = NULL;    // flags for leader of next line

  if (lnum <= 1) {
    return true;                // start of the file
  }
  char *p = ml_get(lnum - 1);
  if (*p == NUL) {
    return true;                // after empty line
  }
  const bool do_comments = has_format_option(FO_Q_COMS);  // format comments
  if (fmt_check_par(lnum - 1, &leader_len, &leader_flags, do_comments)) {
    return true;  // after non-paragraph line
  }

  if (fmt_check_par(lnum, &next_leader_len, &next_leader_flags, do_comments)) {
    return true;  // "lnum" is not a paragraph line
  }

  if (has_format_option(FO_WHITE_PAR) && !ends_in_white(lnum - 1)) {
    return true;                // missing trailing space in previous line.
  }
  if (has_format_option(FO_Q_NUMBER) && (get_number_indent(lnum) > 0)) {
    return true;                // numbered item starts in "lnum".
  }
  if (!same_leader(lnum - 1, leader_len, leader_flags,
                   next_leader_len, next_leader_flags)) {
    return true;                // change of comment leader.
  }
  return false;
}

/// Called after inserting or deleting text: When 'formatoptions' includes the
/// 'a' flag format from the current line until the end of the paragraph.
/// Keep the cursor at the same position relative to the text.
/// The caller must have saved the cursor line for undo, following ones will be
/// saved here.
///
/// @param trailblank  when true also format with trailing blank
/// @param prev_line   may start in previous line
void auto_format(bool trailblank, bool prev_line)
{
  if (!has_format_option(FO_AUTO)) {
    return;
  }

  pos_T pos = curwin->w_cursor;
  char *old = get_cursor_line_ptr();

  // may remove added space
  check_auto_format(false);

  // Don't format in Insert mode when the cursor is on a trailing blank, the
  // user might insert normal text next.  Also skip formatting when "1" is
  // in 'formatoptions' and there is a single character before the cursor.
  // Otherwise the line would be broken and when typing another non-white
  // next they are not joined back together.
  bool wasatend = (pos.col == get_cursor_line_len());
  if (*old != NUL && !trailblank && wasatend) {
    dec_cursor();
    int cc = gchar_cursor();
    if (!WHITECHAR(cc) && curwin->w_cursor.col > 0
        && has_format_option(FO_ONE_LETTER)) {
      dec_cursor();
    }
    cc = gchar_cursor();
    if (WHITECHAR(cc)) {
      curwin->w_cursor = pos;
      return;
    }
    curwin->w_cursor = pos;
  }

  // With the 'c' flag in 'formatoptions' and 't' missing: only format
  // comments.
  if (has_format_option(FO_WRAP_COMS) && !has_format_option(FO_WRAP)
      && get_leader_len(old, NULL, false, true) == 0) {
    return;
  }

  // May start formatting in a previous line, so that after "x" a word is
  // moved to the previous line if it fits there now.  Only when this is not
  // the start of a paragraph.
  if (prev_line && !paragraph_start(curwin->w_cursor.lnum)) {
    curwin->w_cursor.lnum--;
    if (u_save_cursor() == FAIL) {
      return;
    }
  }

  // Do the formatting and restore the cursor position.  "saved_cursor" will
  // be adjusted for the text formatting.
  saved_cursor = pos;
  format_lines(-1, false);
  curwin->w_cursor = saved_cursor;
  saved_cursor.lnum = 0;

  if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count) {
    // "cannot happen"
    curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
    coladvance(curwin, MAXCOL);
  } else {
    check_cursor_col(curwin);
  }

  // Insert mode: If the cursor is now after the end of the line while it
  // previously wasn't, the line was broken.  Because of the rule above we
  // need to add a space when 'w' is in 'formatoptions' to keep a paragraph
  // formatted.
  if (!wasatend && has_format_option(FO_WHITE_PAR)) {
    char *linep = get_cursor_line_ptr();
    colnr_T len = get_cursor_line_len();
    if (curwin->w_cursor.col == len) {
      char *plinep = xstrnsave(linep, (size_t)len + 2);
      plinep[len] = ' ';
      plinep[len + 1] = NUL;
      ml_replace(curwin->w_cursor.lnum, plinep, false);
      // remove the space later
      did_add_space = true;
    } else {
      // may remove added space
      check_auto_format(false);
    }
  }

  check_cursor(curwin);
}

/// When an extra space was added to continue a paragraph for auto-formatting,
/// delete it now.  The space must be under the cursor, just after the insert
/// position.
///
/// @param end_insert  true when ending Insert mode
void check_auto_format(bool end_insert)
{
  if (!did_add_space) {
    return;
  }

  int cc = gchar_cursor();
  if (!WHITECHAR(cc)) {
    // Somehow the space was removed already.
    did_add_space = false;
  } else {
    int c = ' ';
    if (!end_insert) {
      inc_cursor();
      c = gchar_cursor();
      dec_cursor();
    }
    if (c != NUL) {
      // The space is no longer at the end of the line, delete it.
      del_char(false);
      did_add_space = false;
    }
  }
}

/// Find out textwidth to be used for formatting:
///      if 'textwidth' option is set, use it
///      else if 'wrapmargin' option is set, use curwin->w_view_width-'wrapmargin'
///      if invalid value, use 0.
///      Set default to window width (maximum 79) for "gq" operator.
///
/// @param ff  force formatting (for "gq" command)
int comp_textwidth(bool ff)
{
  int textwidth = (int)curbuf->b_p_tw;
  if (textwidth == 0 && curbuf->b_p_wm) {
    // The width is the window width minus 'wrapmargin' minus all the
    // things that add to the margin.
    textwidth = curwin->w_view_width - (int)curbuf->b_p_wm;
    if (curbuf == cmdwin_buf) {
      textwidth -= 1;
    }
    textwidth -= win_fdccol_count(curwin);
    textwidth -= curwin->w_scwidth;

    if (curwin->w_p_nu || curwin->w_p_rnu) {
      textwidth -= 8;
    }
  }
  textwidth = MAX(textwidth, 0);
  if (ff && textwidth == 0) {
    textwidth = MIN(curwin->w_view_width - 1, 79);
  }
  return textwidth;
}

/// Implementation of the format operator 'gq'.
///
/// @param keep_cursor  keep cursor on same text char
void op_format(oparg_T *oap, bool keep_cursor)
{
  linenr_T old_line_count = curbuf->b_ml.ml_line_count;

  // Place the cursor where the "gq" or "gw" command was given, so that "u"
  // can put it back there.
  curwin->w_cursor = oap->cursor_start;

  if (u_save((linenr_T)(oap->start.lnum - 1),
             (linenr_T)(oap->end.lnum + 1)) == FAIL) {
    return;
  }
  curwin->w_cursor = oap->start;

  if (oap->is_VIsual) {
    // When there is no change: need to remove the Visual selection
    redraw_curbuf_later(UPD_INVERTED);
  }

  if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
    // Set '[ mark at the start of the formatted area
    curbuf->b_op_start = oap->start;
  }

  // For "gw" remember the cursor position and put it back below (adjusted
  // for joined and split lines).
  if (keep_cursor) {
    saved_cursor = oap->cursor_start;
  }

  format_lines(oap->line_count, keep_cursor);

  // Leave the cursor at the first non-blank of the last formatted line.
  // If the cursor was moved one line back (e.g. with "Q}") go to the next
  // line, so "." will do the next lines.
  if (oap->end_adjusted && curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count) {
    curwin->w_cursor.lnum++;
  }
  beginline(BL_WHITE | BL_FIX);
  old_line_count = curbuf->b_ml.ml_line_count - old_line_count;
  msgmore(old_line_count);

  if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
    // put '] mark on the end of the formatted area
    curbuf->b_op_end = curwin->w_cursor;
  }

  if (keep_cursor) {
    curwin->w_cursor = saved_cursor;
    saved_cursor.lnum = 0;

    // formatting may have made the cursor position invalid
    check_cursor(curwin);
  }

  if (oap->is_VIsual) {
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp->w_old_cursor_lnum != 0) {
        // When lines have been inserted or deleted, adjust the end of
        // the Visual area to be redrawn.
        if (wp->w_old_cursor_lnum > wp->w_old_visual_lnum) {
          wp->w_old_cursor_lnum += old_line_count;
        } else {
          wp->w_old_visual_lnum += old_line_count;
        }
      }
    }
  }
}

/// Implementation of the format operator 'gq' for when using 'formatexpr'.
void op_formatexpr(oparg_T *oap)
{
  if (oap->is_VIsual) {
    // When there is no change: need to remove the Visual selection
    redraw_curbuf_later(UPD_INVERTED);
  }

  if (fex_format(oap->start.lnum, oap->line_count, NUL) != 0) {
    // As documented: when 'formatexpr' returns non-zero fall back to
    // internal formatting.
    op_format(oap, false);
  }
}

/// @param c  character to be inserted
int fex_format(linenr_T lnum, long count, int c)
{
  bool use_sandbox = was_set_insecurely(curwin, kOptFormatexpr, OPT_LOCAL);
  const sctx_T save_sctx = current_sctx;

  // Set v:lnum to the first line number and v:count to the number of lines.
  // Set v:char to the character to be inserted (can be NUL).
  set_vim_var_nr(VV_LNUM, (varnumber_T)lnum);
  set_vim_var_nr(VV_COUNT, (varnumber_T)count);
  set_vim_var_char(c);

  // Make a copy, the option could be changed while calling it.
  char *fex = xstrdup(curbuf->b_p_fex);
  current_sctx = curbuf->b_p_script_ctx[kBufOptFormatexpr];

  // Evaluate the function.
  if (use_sandbox) {
    sandbox++;
  }
  int r = (int)eval_to_number(fex, true);
  if (use_sandbox) {
    sandbox--;
  }

  set_vim_var_string(VV_CHAR, NULL, -1);
  xfree(fex);
  current_sctx = save_sctx;

  return r;
}

/// @param line_count  number of lines to format, starting at the cursor position.
///                    when negative, format until the end of the paragraph.
///
/// Lines after the cursor line are saved for undo, caller must have saved the
/// first line.
///
/// @param avoid_fex  don't use 'formatexpr'
void format_lines(linenr_T line_count, bool avoid_fex)
{
  bool is_not_par;                  // current line not part of parag.
  bool next_is_not_par;             // next line not part of paragraph
  bool is_end_par;                  // at end of paragraph
  bool prev_is_end_par = false;     // prev. line not part of parag.
  bool next_is_start_par = false;
  int leader_len = 0;               // leader len of current line
  int next_leader_len;              // leader len of next line
  char *leader_flags = NULL;        // flags for leader of current line
  char *next_leader_flags = NULL;   // flags for leader of next line
  bool advance = true;
  int second_indent = -1;           // indent for second line (comment aware)
  bool first_par_line = true;
  int smd_save;
  long count;
  bool need_set_indent = true;      // set indent of next paragraph
  linenr_T first_line = curwin->w_cursor.lnum;
  bool force_format = false;
  const int old_State = State;

  // length of a line to force formatting: 3 * 'tw'
  const int max_len = comp_textwidth(true) * 3;

  // check for 'q', '2', 'n' and 'w' in 'formatoptions'
  const bool do_comments = has_format_option(FO_Q_COMS);  // format comments
  int do_comments_list = 0;  // format comments with 'n' or '2'
  const bool do_second_indent = has_format_option(FO_Q_SECOND);
  const bool do_number_indent = has_format_option(FO_Q_NUMBER);
  const bool do_trail_white = has_format_option(FO_WHITE_PAR);

  // Get info about the previous and current line.
  if (curwin->w_cursor.lnum > 1) {
    is_not_par = fmt_check_par(curwin->w_cursor.lnum - 1,
                               &leader_len, &leader_flags, do_comments);
  } else {
    is_not_par = true;
  }
  next_is_not_par = fmt_check_par(curwin->w_cursor.lnum,
                                  &next_leader_len, &next_leader_flags, do_comments);
  is_end_par = (is_not_par || next_is_not_par);
  if (!is_end_par && do_trail_white) {
    is_end_par = !ends_in_white(curwin->w_cursor.lnum - 1);
  }

  curwin->w_cursor.lnum--;
  for (count = line_count; count != 0 && !got_int; count--) {
    // Advance to next paragraph.
    if (advance) {
      curwin->w_cursor.lnum++;
      prev_is_end_par = is_end_par;
      is_not_par = next_is_not_par;
      leader_len = next_leader_len;
      leader_flags = next_leader_flags;
    }

    // The last line to be formatted.
    if (count == 1 || curwin->w_cursor.lnum == curbuf->b_ml.ml_line_count) {
      next_is_not_par = true;
      next_leader_len = 0;
      next_leader_flags = NULL;
    } else {
      next_is_not_par = fmt_check_par(curwin->w_cursor.lnum + 1,
                                      &next_leader_len, &next_leader_flags, do_comments);
      if (do_number_indent) {
        next_is_start_par =
          (get_number_indent(curwin->w_cursor.lnum + 1) > 0);
      }
    }
    advance = true;
    is_end_par = (is_not_par || next_is_not_par || next_is_start_par);
    if (!is_end_par && do_trail_white) {
      is_end_par = !ends_in_white(curwin->w_cursor.lnum);
    }

    // Skip lines that are not in a paragraph.
    if (is_not_par) {
      if (line_count < 0) {
        break;
      }
    } else {
      // For the first line of a paragraph, check indent of second line.
      // Don't do this for comments and empty lines.
      if (first_par_line
          && (do_second_indent || do_number_indent)
          && prev_is_end_par
          && curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count) {
        if (do_second_indent && !LINEEMPTY(curwin->w_cursor.lnum + 1)) {
          if (leader_len == 0 && next_leader_len == 0) {
            // no comment found
            second_indent =
              get_indent_lnum(curwin->w_cursor.lnum + 1);
          } else {
            second_indent = next_leader_len;
            do_comments_list = 1;
          }
        } else if (do_number_indent) {
          if (leader_len == 0 && next_leader_len == 0) {
            // no comment found
            second_indent =
              get_number_indent(curwin->w_cursor.lnum);
          } else {
            // get_number_indent() is now "comment aware"...
            second_indent =
              get_number_indent(curwin->w_cursor.lnum);
            do_comments_list = 1;
          }
        }
      }

      // When the comment leader changes, it's the end of the paragraph.
      if (curwin->w_cursor.lnum >= curbuf->b_ml.ml_line_count
          || !same_leader(curwin->w_cursor.lnum,
                          leader_len, leader_flags,
                          next_leader_len,
                          next_leader_flags)) {
        // Special case: If the next line starts with a line comment
        // and this line has a line comment after some text, the
        // paragraph doesn't really end.
        if (next_leader_flags == NULL
            || strncmp(next_leader_flags, "://", 3) != 0
            || check_linecomment(get_cursor_line_ptr()) == MAXCOL) {
          is_end_par = true;
        }
      }

      // If we have got to the end of a paragraph, or the line is
      // getting long, format it.
      if (is_end_par || force_format) {
        if (need_set_indent) {
          int indent = 0;  // amount of indent needed

          // Replace indent in first line of a paragraph with minimal
          // number of tabs and spaces, according to current options.
          // For the very first formatted line keep the current
          // indent.
          if (curwin->w_cursor.lnum == first_line) {
            indent = get_indent();
          } else if (curbuf->b_p_lisp) {
            indent = get_lisp_indent();
          } else {
            if (cindent_on()) {
              indent = *curbuf->b_p_inde != NUL ? get_expr_indent() : get_c_indent();
            } else {
              indent = get_indent();
            }
          }
          set_indent(indent, SIN_CHANGED);
        }

        // put cursor on last non-space
        State = MODE_NORMAL;  // don't go past end-of-line
        coladvance(curwin, MAXCOL);
        while (curwin->w_cursor.col && ascii_isspace(gchar_cursor())) {
          dec_cursor();
        }

        // do the formatting, without 'showmode'
        State = MODE_INSERT;         // for open_line()
        smd_save = p_smd;
        p_smd = false;

        insertchar(NUL, INSCHAR_FORMAT
                   + (do_comments ? INSCHAR_DO_COM : 0)
                   + (do_comments && do_comments_list ? INSCHAR_COM_LIST : 0)
                   + (avoid_fex ? INSCHAR_NO_FEX : 0), second_indent);

        State = old_State;
        p_smd = smd_save;
        // Cursor shape may have been updated (e.g. by :normal) in insertchar(),
        // so it needs to be updated here.
        ui_cursor_shape();

        second_indent = -1;
        // at end of par.: need to set indent of next par.
        need_set_indent = is_end_par;
        if (is_end_par) {
          // When called with a negative line count, break at the
          // end of the paragraph.
          if (line_count < 0) {
            break;
          }
          first_par_line = true;
        }
        force_format = false;
      }

      // When still in same paragraph, join the lines together.  But
      // first delete the leader from the second line.
      if (!is_end_par) {
        advance = false;
        curwin->w_cursor.lnum++;
        curwin->w_cursor.col = 0;
        if (line_count < 0 && u_save_cursor() == FAIL) {
          break;
        }
        if (next_leader_len > 0) {
          del_bytes(next_leader_len, false, false);
          mark_col_adjust(curwin->w_cursor.lnum, 0, 0, -next_leader_len, 0);
        } else if (second_indent > 0) {   // the "leader" for FO_Q_SECOND
          int indent = (int)getwhitecols_curline();

          if (indent > 0) {
            del_bytes(indent, false, false);
            mark_col_adjust(curwin->w_cursor.lnum, 0, 0, -indent, 0);
          }
        }
        curwin->w_cursor.lnum--;
        if (do_join(2, true, false, false, false) == FAIL) {
          beep_flush();
          break;
        }
        first_par_line = false;
        // If the line is getting long, format it next time
        force_format = get_cursor_line_len() > max_len;
      }
    }
    line_breakcheck();
  }
}
