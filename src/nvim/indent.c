// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>

#include "nvim/ascii.h"
#include "nvim/assert.h"
#include "nvim/indent.h"
#include "nvim/eval.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/mark.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/misc1.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/strings.h"
#include "nvim/undo.h"
#include "nvim/buffer.h"


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "indent.c.generated.h"
#endif

// Count the size (in window cells) of the indent in the current line.
int get_indent(void)
{
  return get_indent_str(get_cursor_line_ptr(), (int)curbuf->b_p_ts, false);
}


// Count the size (in window cells) of the indent in line "lnum".
int get_indent_lnum(linenr_T lnum)
{
  return get_indent_str(ml_get(lnum), (int)curbuf->b_p_ts, false);
}


// Count the size (in window cells) of the indent in line "lnum" of buffer
// "buf".
int get_indent_buf(buf_T *buf, linenr_T lnum)
{
  return get_indent_str(ml_get_buf(buf, lnum, false), (int)buf->b_p_ts, false);
}


// Count the size (in window cells) of the indent in line "ptr", with
// 'tabstop' at "ts".
// If @param list is TRUE, count only screen size for tabs.
int get_indent_str(char_u *ptr, int ts, int list)
{
  int count = 0;

  for (; *ptr; ++ptr) {
    // Count a tab for what it is worth.
    if (*ptr == TAB) {
      if (!list || curwin->w_p_lcs_chars.tab1) {
        // count a tab for what it is worth
        count += ts - (count % ts);
      } else {
        // In list mode, when tab is not set, count screen char width
        // for Tab, displays: ^I
        count += ptr2cells(ptr);
      }
    } else if (*ptr == ' ') {
      // Count a space for one.
      count++;
    } else {
      break;
    }
  }
  return count;
}


// Set the indent of the current line.
// Leaves the cursor on the first non-blank in the line.
// Caller must take care of undo.
// "flags":
//  SIN_CHANGED:    call changed_bytes() if the line was changed.
//  SIN_INSERT: insert the indent in front of the line.
//  SIN_UNDO:   save line for undo before changing it.
//  @param size measured in spaces
// Returns true if the line was changed.
int set_indent(int size, int flags)
{
  char_u *p;
  char_u *newline;
  char_u *oldline;
  char_u *s;
  int todo;
  int ind_len;  // Measured in characters.
  int line_len;
  int doit = false;
  int ind_done = 0;  // Measured in spaces.
  int tab_pad;
  int retval = false;

  // Number of initial whitespace chars when 'et' and 'pi' are both set.
  int orig_char_len = -1;

  // First check if there is anything to do and compute the number of
  // characters needed for the indent.
  todo = size;
  ind_len = 0;
  p = oldline = get_cursor_line_ptr();

  // Calculate the buffer size for the new indent, and check to see if it
  // isn't already set.
  // If 'expandtab' isn't set: use TABs; if both 'expandtab' and
  // 'preserveindent' are set count the number of characters at the
  // beginning of the line to be copied.
  if (!curbuf->b_p_et || (!(flags & SIN_INSERT) && curbuf->b_p_pi)) {
    // If 'preserveindent' is set then reuse as much as possible of
    // the existing indent structure for the new indent.
    if (!(flags & SIN_INSERT) && curbuf->b_p_pi) {
      ind_done = 0;

      // Count as many characters as we can use.
      while (todo > 0 && ascii_iswhite(*p)) {
        if (*p == TAB) {
          tab_pad = (int)curbuf->b_p_ts - (ind_done % (int)curbuf->b_p_ts);

          // Stop if this tab will overshoot the target.
          if (todo < tab_pad) {
            break;
          }
          todo -= tab_pad;
          ind_len++;
          ind_done += tab_pad;
        } else {
          todo--;
          ind_len++;
          ind_done++;
        }
        p++;
      }

      // Set initial number of whitespace chars to copy if we are
      // preserving indent but expandtab is set.
      if (curbuf->b_p_et) {
        orig_char_len = ind_len;
      }

      // Fill to next tabstop with a tab, if possible.
      tab_pad = (int)curbuf->b_p_ts - (ind_done % (int)curbuf->b_p_ts);

      if ((todo >= tab_pad) && (orig_char_len == -1)) {
        doit = true;
        todo -= tab_pad;
        ind_len++;

        // ind_done += tab_pad;
      }
    }

    // Count tabs required for indent.
    while (todo >= (int)curbuf->b_p_ts) {
      if (*p != TAB) {
        doit = true;
      } else {
        p++;
      }
      todo -= (int)curbuf->b_p_ts;
      ind_len++;

      // ind_done += (int)curbuf->b_p_ts;
    }
  }

  // Count spaces required for indent.
  while (todo > 0) {
    if (*p != ' ') {
      doit = true;
    } else {
      p++;
    }
    todo--;
    ind_len++;

    // ind_done++;
  }

  // Return if the indent is OK already.
  if (!doit && !ascii_iswhite(*p) && !(flags & SIN_INSERT)) {
    return false;
  }

  // Allocate memory for the new line.
  if (flags & SIN_INSERT) {
    p = oldline;
  } else {
    p = skipwhite(p);
  }
  line_len = (int)STRLEN(p) + 1;

  // If 'preserveindent' and 'expandtab' are both set keep the original
  // characters and allocate accordingly.  We will fill the rest with spaces
  // after the if (!curbuf->b_p_et) below.
  if (orig_char_len != -1) {
    int newline_size;  // = orig_char_len + size - ind_done + line_len
    STRICT_ADD(orig_char_len, size, &newline_size, int);
    STRICT_SUB(newline_size, ind_done, &newline_size, int);
    STRICT_ADD(newline_size, line_len, &newline_size, int);
    assert(newline_size >= 0);
    newline = xmalloc((size_t)newline_size);
    todo = size - ind_done;

    // Set total length of indent in characters, which may have been
    // undercounted until now.
    ind_len = orig_char_len + todo;
    p = oldline;
    s = newline;

    while (orig_char_len > 0) {
      *s++ = *p++;
      orig_char_len--;
    }

    // Skip over any additional white space (useful when newindent is less
    // than old).
    while (ascii_iswhite(*p)) {
      p++;
    }
  } else {
    todo = size;
    assert(ind_len + line_len >= 0);
    size_t newline_size;
    STRICT_ADD(ind_len, line_len, &newline_size, size_t);
    newline = xmalloc(newline_size);
    s = newline;
  }

  // Put the characters in the new line.
  // if 'expandtab' isn't set: use TABs
  if (!curbuf->b_p_et) {
    // If 'preserveindent' is set then reuse as much as possible of
    // the existing indent structure for the new indent.
    if (!(flags & SIN_INSERT) && curbuf->b_p_pi) {
      p = oldline;
      ind_done = 0;

      while (todo > 0 && ascii_iswhite(*p)) {
        if (*p == TAB) {
          tab_pad = (int)curbuf->b_p_ts - (ind_done % (int)curbuf->b_p_ts);

          // Stop if this tab will overshoot the target.
          if (todo < tab_pad) {
            break;
          }
          todo -= tab_pad;
          ind_done += tab_pad;
        } else {
          todo--;
          ind_done++;
        }
        *s++ = *p++;
      }

      // Fill to next tabstop with a tab, if possible.
      tab_pad = (int)curbuf->b_p_ts - (ind_done % (int)curbuf->b_p_ts);

      if (todo >= tab_pad) {
        *s++ = TAB;
        todo -= tab_pad;
      }
      p = skipwhite(p);
    }

    while (todo >= (int)curbuf->b_p_ts) {
      *s++ = TAB;
      todo -= (int)curbuf->b_p_ts;
    }
  }

  while (todo > 0) {
    *s++ = ' ';
    todo--;
  }
  memmove(s, p, (size_t)line_len);

  // Replace the line (unless undo fails).
  if (!(flags & SIN_UNDO) || (u_savesub(curwin->w_cursor.lnum) == OK)) {
    ml_replace(curwin->w_cursor.lnum, newline, false);

    if (flags & SIN_CHANGED) {
      changed_bytes(curwin->w_cursor.lnum, 0);
    }

    // Correct saved cursor position if it is in this line.
    if (saved_cursor.lnum == curwin->w_cursor.lnum) {
      if (saved_cursor.col >= (colnr_T)(p - oldline)) {
        // Cursor was after the indent, adjust for the number of
        // bytes added/removed.
        saved_cursor.col += ind_len - (colnr_T)(p - oldline);

      } else if (saved_cursor.col >= (colnr_T)(s - newline)) {
        // Cursor was in the indent, and is now after it, put it back
        // at the start of the indent (replacing spaces with TAB).
        saved_cursor.col = (colnr_T)(s - newline);
      }
    }
    retval = true;
  } else {
    xfree(newline);
  }
  curwin->w_cursor.col = ind_len;
  return retval;
}


// Copy the indent from ptr to the current line (and fill to size).
// Leaves the cursor on the first non-blank in the line.
// @return true if the line was changed.
int copy_indent(int size, char_u *src)
{
  char_u *p = NULL;
  char_u *line = NULL;
  char_u *s;
  int todo;
  int ind_len;
  int line_len = 0;
  int tab_pad;
  int ind_done;
  int round;

  // Round 1: compute the number of characters needed for the indent
  // Round 2: copy the characters.
  for (round = 1; round <= 2; ++round) {
    todo = size;
    ind_len = 0;
    ind_done = 0;
    s = src;

    // Count/copy the usable portion of the source line.
    while (todo > 0 && ascii_iswhite(*s)) {
      if (*s == TAB) {
        tab_pad = (int)curbuf->b_p_ts
                  - (ind_done % (int)curbuf->b_p_ts);

        // Stop if this tab will overshoot the target.
        if (todo < tab_pad) {
          break;
        }
        todo -= tab_pad;
        ind_done += tab_pad;
      } else {
        todo--;
        ind_done++;
      }
      ind_len++;

      if (p != NULL) {
        *p++ = *s;
      }
      s++;
    }

    // Fill to next tabstop with a tab, if possible.
    tab_pad = (int)curbuf->b_p_ts - (ind_done % (int)curbuf->b_p_ts);

    if ((todo >= tab_pad) && !curbuf->b_p_et) {
      todo -= tab_pad;
      ind_len++;

      if (p != NULL) {
        *p++ = TAB;
      }
    }

    // Add tabs required for indent.
    while (todo >= (int)curbuf->b_p_ts && !curbuf->b_p_et) {
      todo -= (int)curbuf->b_p_ts;
      ind_len++;

      if (p != NULL) {
        *p++ = TAB;
      }
    }

    // Count/add spaces required for indent.
    while (todo > 0) {
      todo--;
      ind_len++;

      if (p != NULL) {
        *p++ = ' ';
      }
    }

    if (p == NULL) {
      // Allocate memory for the result: the copied indent, new indent
      // and the rest of the line.
      line_len = (int)STRLEN(get_cursor_line_ptr()) + 1;
      assert(ind_len + line_len >= 0);
      size_t line_size;
      STRICT_ADD(ind_len, line_len, &line_size, size_t);
      line = xmalloc(line_size);
      p = line;
    }
  }

  // Append the original line
  memmove(p, get_cursor_line_ptr(), (size_t)line_len);

  // Replace the line
  ml_replace(curwin->w_cursor.lnum, line, false);

  // Put the cursor after the indent.
  curwin->w_cursor.col = ind_len;
  return true;
}


// Return the indent of the current line after a number.  Return -1 if no
// number was found.  Used for 'n' in 'formatoptions': numbered list.
// Since a pattern is used it can actually handle more than numbers.
int get_number_indent(linenr_T lnum)
{
  colnr_T col;
  pos_T pos;
  regmatch_T regmatch;
  int lead_len = 0;  // Length of comment leader.

  if (lnum > curbuf->b_ml.ml_line_count) {
    return -1;
  }
  pos.lnum = 0;

  // In format_lines() (i.e. not insert mode), fo+=q is needed too...
  if ((State & INSERT) || has_format_option(FO_Q_COMS)) {
    lead_len = get_leader_len(ml_get(lnum), NULL, false, true);
  }
  regmatch.regprog = vim_regcomp(curbuf->b_p_flp, RE_MAGIC);

  if (regmatch.regprog != NULL) {
    regmatch.rm_ic = false;

    // vim_regexec() expects a pointer to a line.  This lets us
    // start matching for the flp beyond any comment leader...
    if (vim_regexec(&regmatch, ml_get(lnum) + lead_len, (colnr_T)0)) {
      pos.lnum = lnum;
      pos.col = (colnr_T)(*regmatch.endp - ml_get(lnum));
      pos.coladd = 0;
    }
    vim_regfree(regmatch.regprog);
  }

  if ((pos.lnum == 0) || (*ml_get_pos(&pos) == NUL)) {
    return -1;
  }
  getvcol(curwin, &pos, &col, NULL, NULL);
  return (int)col;
}

/*
 * Return appropriate space number for breakindent, taking influencing
 * parameters into account. Window must be specified, since it is not
 * necessarily always the current one.
 */
int get_breakindent_win(win_T *wp, char_u *line)
  FUNC_ATTR_NONNULL_ARG(1)
{
  static int prev_indent = 0;  // Cached indent value.
  static long prev_ts = 0;  // Cached tabstop value.
  static char_u *prev_line = NULL;  // cached pointer to line.
  static varnumber_T prev_tick = 0;  // Changedtick of cached value.
  int bri = 0;
  // window width minus window margin space, i.e. what rests for text
  const int eff_wwidth = wp->w_width_inner
    - ((wp->w_p_nu || wp->w_p_rnu)
        && (vim_strchr(p_cpo, CPO_NUMCOL) == NULL)
        ? number_width(wp) + 1 : 0);

  /* used cached indent, unless pointer or 'tabstop' changed */
  if (prev_line != line || prev_ts != wp->w_buffer->b_p_ts
      || prev_tick != buf_get_changedtick(wp->w_buffer)) {
    prev_line = line;
    prev_ts = wp->w_buffer->b_p_ts;
    prev_tick = buf_get_changedtick(wp->w_buffer);
    prev_indent = get_indent_str(line, (int)wp->w_buffer->b_p_ts, wp->w_p_list);
  }
  bri = prev_indent + wp->w_p_brishift;

  /* indent minus the length of the showbreak string */
  if (wp->w_p_brisbr)
    bri -= vim_strsize(p_sbr);

  /* Add offset for number column, if 'n' is in 'cpoptions' */
  bri += win_col_off2(wp);

  /* never indent past left window margin */
  if (bri < 0)
    bri = 0;
  /* always leave at least bri_min characters on the left,
   * if text width is sufficient */
  else if (bri > eff_wwidth - wp->w_p_brimin)
    bri = (eff_wwidth - wp->w_p_brimin < 0)
      ? 0 : eff_wwidth - wp->w_p_brimin;

  return bri;
}

// When extra == 0: Return true if the cursor is before or on the first
// non-blank in the line.
// When extra == 1: Return true if the cursor is before the first non-blank in
// the line.
int inindent(int extra)
{
  char_u      *ptr;
  colnr_T col;

  for (col = 0, ptr = get_cursor_line_ptr(); ascii_iswhite(*ptr); ++col) {
    ptr++;
  }

  if (col >= curwin->w_cursor.col + extra) {
    return true;
  } else {
    return false;
  }
}


// Get indent level from 'indentexpr'.
int get_expr_indent(void)
{
  int indent = -1;
  pos_T save_pos;
  colnr_T save_curswant;
  int save_set_curswant;
  int save_State;
  int use_sandbox = was_set_insecurely((char_u *)"indentexpr", OPT_LOCAL);

  // Save and restore cursor position and curswant, in case it was changed
  // * via :normal commands.
  save_pos = curwin->w_cursor;
  save_curswant = curwin->w_curswant;
  save_set_curswant = curwin->w_set_curswant;
  set_vim_var_nr(VV_LNUM, (varnumber_T) curwin->w_cursor.lnum);

  if (use_sandbox) {
    sandbox++;
  }
  textlock++;

  // Need to make a copy, the 'indentexpr' option could be changed while
  // evaluating it.
  char_u *inde_copy = vim_strsave(curbuf->b_p_inde);
  indent = (int)eval_to_number(inde_copy);
  xfree(inde_copy);

  if (use_sandbox) {
    sandbox--;
  }
  textlock--;

  // Restore the cursor position so that 'indentexpr' doesn't need to.
  // Pretend to be in Insert mode, allow cursor past end of line for "o"
  // command.
  save_State = State;
  State = INSERT;
  curwin->w_cursor = save_pos;
  curwin->w_curswant = save_curswant;
  curwin->w_set_curswant = save_set_curswant;
  check_cursor();
  State = save_State;

  // If there is an error, just keep the current indent.
  if (indent < 0) {
    indent = get_indent();
  }

  return indent;
}


// When 'p' is present in 'cpoptions, a Vi compatible method is used.
// The incompatible newer method is quite a bit better at indenting
// code in lisp-like languages than the traditional one; it's still
// mostly heuristics however -- Dirk van Deun, dirk@rave.org

// TODO(unknown):
// Findmatch() should be adapted for lisp, also to make showmatch
// work correctly: now (v5.3) it seems all C/C++ oriented:
// - it does not recognize the #\( and #\) notations as character literals
// - it doesn't know about comments starting with a semicolon
// - it incorrectly interprets '(' as a character literal
// All this messes up get_lisp_indent in some rare cases.
// Update from Sergey Khorev:
// I tried to fix the first two issues.
int get_lisp_indent(void)
{
  pos_T *pos, realpos, paren;
  int amount;
  char_u *that;
  colnr_T col;
  colnr_T firsttry;
  int parencount;
  int quotecount;
  int vi_lisp;

  // Set vi_lisp to use the vi-compatible method.
  vi_lisp = (vim_strchr(p_cpo, CPO_LISP) != NULL);

  realpos = curwin->w_cursor;
  curwin->w_cursor.col = 0;

  if ((pos = findmatch(NULL, '(')) == NULL) {
    pos = findmatch(NULL, '[');
  } else {
    paren = *pos;
    pos = findmatch(NULL, '[');

    if ((pos == NULL) || lt(*pos, paren)) {
      pos = &paren;
    }
  }

  if (pos != NULL) {
    // Extra trick: Take the indent of the first previous non-white
    // line that is at the same () level.
    amount = -1;
    parencount = 0;

    while (--curwin->w_cursor.lnum >= pos->lnum) {
      if (linewhite(curwin->w_cursor.lnum)) {
        continue;
      }

      for (that = get_cursor_line_ptr(); *that != NUL; ++that) {
        if (*that == ';') {
          while (*(that + 1) != NUL) {
            that++;
          }
          continue;
        }

        if (*that == '\\') {
          if (*(that + 1) != NUL) {
            that++;
          }
          continue;
        }

        if ((*that == '"') && (*(that + 1) != NUL)) {
          while (*++that && *that != '"') {
            // Skipping escaped characters in the string
            if (*that == '\\') {
              if (*++that == NUL) {
                break;
              }
              if (that[1] == NUL) {
                that++;
                break;
              }
            }
          }
        }
        if ((*that == '(') || (*that == '[')) {
          parencount++;
        } else if ((*that == ')') || (*that == ']')) {
          parencount--;
        }
      }

      if (parencount == 0) {
        amount = get_indent();
        break;
      }
    }

    if (amount == -1) {
      curwin->w_cursor.lnum = pos->lnum;
      curwin->w_cursor.col = pos->col;
      col = pos->col;

      that = get_cursor_line_ptr();

      if (vi_lisp && (get_indent() == 0)) {
        amount = 2;
      } else {
        char_u *line = that;

        amount = 0;

        while (*that && col) {
          amount += lbr_chartabsize_adv(line, &that, (colnr_T)amount);
          col--;
        }

        // Some keywords require "body" indenting rules (the
        // non-standard-lisp ones are Scheme special forms):
        // (let ((a 1))    instead    (let ((a 1))
        //   (...))       of       (...))
        if (!vi_lisp && ((*that == '(') || (*that == '['))
            && lisp_match(that + 1)) {
          amount += 2;
        } else {
          that++;
          amount++;
          firsttry = amount;

          while (ascii_iswhite(*that)) {
            amount += lbr_chartabsize(line, that, (colnr_T)amount);
            that++;
          }

          if (*that && (*that != ';')) {
            // Not a comment line.
            // Test *that != '(' to accommodate first let/do
            // argument if it is more than one line.
            if (!vi_lisp && (*that != '(') && (*that != '[')) {
              firsttry++;
            }

            parencount = 0;
            quotecount = 0;

            if (vi_lisp || ((*that != '"') && (*that != '\'')
                && (*that != '#') && ((*that < '0') || (*that > '9')))) {
              while (*that
                     && (!ascii_iswhite(*that) || quotecount || parencount)
                     && (!((*that == '(' || *that == '[')
                     && !quotecount && !parencount && vi_lisp))) {
                if (*that == '"') {
                  quotecount = !quotecount;
                }
                if (((*that == '(') || (*that == '[')) && !quotecount) {
                  parencount++;
                }
                if (((*that == ')') || (*that == ']')) && !quotecount) {
                  parencount--;
                }
                if ((*that == '\\') && (*(that + 1) != NUL)) {
                  amount += lbr_chartabsize_adv(line, &that, (colnr_T)amount);
                }

                amount += lbr_chartabsize_adv(line, &that, (colnr_T)amount);
              }
            }

            while (ascii_iswhite(*that)) {
              amount += lbr_chartabsize(line, that, (colnr_T)amount);
              that++;
            }

            if (!*that || (*that == ';')) {
              amount = firsttry;
            }
          }
        }
      }
    }
  } else {
    amount = 0;  // No matching '(' or '[' found, use zero indent.
  }
  curwin->w_cursor = realpos;

  return amount;
}


static int lisp_match(char_u *p)
{
  char_u buf[LSIZE];
  int len;
  char_u *word = *curbuf->b_p_lw != NUL ? curbuf->b_p_lw : p_lispwords;

  while (*word != NUL) {
    (void)copy_option_part(&word, buf, LSIZE, ",");
    len = (int)STRLEN(buf);

    if ((STRNCMP(buf, p, len) == 0) && (p[len] == ' ')) {
      return true;
    }
  }
  return false;
}
