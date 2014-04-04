#include "indent.h"
#include "eval.h"
#include "charset.h"
#include "memline.h"
#include "memory.h"
#include "misc1.h"
#include "misc2.h"
#include "option.h"
#include "regexp.h"
#include "search.h"
#include "undo.h"

static int lisp_match(char_u *p);


// Count the size (in window cells) of the indent in the current line.
int get_indent(void)
{
  return get_indent_str(ml_get_curline(), (int)curbuf->b_p_ts);
}


// Count the size (in window cells) of the indent in line "lnum".
int get_indent_lnum(linenr_T lnum)
{
  return get_indent_str(ml_get(lnum), (int)curbuf->b_p_ts);
}


// Count the size (in window cells) of the indent in line "lnum" of buffer
// "buf".
int get_indent_buf(buf_T *buf, linenr_T lnum)
{
  return get_indent_str(ml_get_buf(buf, lnum, FALSE), (int)buf->b_p_ts);
}


// Count the size (in window cells) of the indent in line "ptr", with
// 'tabstop' at "ts".
int get_indent_str(char_u *ptr, int ts)
{
  int count = 0;

  for (; *ptr; ++ptr) {
    // Count a tab for what it is worth.
    if (*ptr == TAB) {
      count += ts - (count % ts);
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
// Returns TRUE if the line was changed.
int set_indent(int size, int flags)
{
  char_u *p;
  char_u *newline;
  char_u *oldline;
  char_u *s;
  int todo;
  int ind_len;  // Measured in characters.
  int line_len;
  int doit = FALSE;
  int ind_done = 0;  // Measured in spaces.
  int tab_pad;
  int retval = FALSE;

  // Number of initial whitespace chars when 'et' and 'pi' are both set.
  int orig_char_len = -1;

  // First check if there is anything to do and compute the number of
  // characters needed for the indent.
  todo = size;
  ind_len = 0;
  p = oldline = ml_get_curline();

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
      while (todo > 0 && vim_iswhite(*p)) {
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
        doit = TRUE;
        todo -= tab_pad;
        ind_len++;

        // ind_done += tab_pad;
      }
    }

    // Count tabs required for indent.
    while (todo >= (int)curbuf->b_p_ts) {
      if (*p != TAB) {
        doit = TRUE;
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
      doit = TRUE;
    } else {
      p++;
    }
    todo--;
    ind_len++;

    // ind_done++;
  }

  // Return if the indent is OK already.
  if (!doit && !vim_iswhite(*p) && !(flags & SIN_INSERT)) {
    return FALSE;
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
    newline = alloc(orig_char_len + size - ind_done + line_len);

    if (newline == NULL) {
      return FALSE;
    }
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
    while (vim_iswhite(*p)) {
      p++;
    }
  } else {
    todo = size;
    newline = alloc(ind_len + line_len);

    if (newline == NULL) {
      return FALSE;
    }
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

      while (todo > 0 && vim_iswhite(*p)) {
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
    ml_replace(curwin->w_cursor.lnum, newline, FALSE);

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
    retval = TRUE;
  } else {
    vim_free(newline);
  }
  curwin->w_cursor.col = ind_len;
  return retval;
}


// Copy the indent from ptr to the current line (and fill to size).
// Leaves the cursor on the first non-blank in the line.
// @return TRUE if the line was changed.
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
    while (todo > 0 && vim_iswhite(*s)) {
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
      line_len = (int)STRLEN(ml_get_curline()) + 1;
      line = alloc(ind_len + line_len);

      if (line == NULL) {
        return FALSE;
      }
      p = line;
    }
  }

  // Append the original line
  memmove(p, ml_get_curline(), (size_t)line_len);

  // Replace the line
  ml_replace(curwin->w_cursor.lnum, line, FALSE);

  // Put the cursor after the indent.
  curwin->w_cursor.col = ind_len;
  return TRUE;
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
    lead_len = get_leader_len(ml_get(lnum), NULL, FALSE, TRUE);
  }
  regmatch.regprog = vim_regcomp(curbuf->b_p_flp, RE_MAGIC);

  if (regmatch.regprog != NULL) {
    regmatch.rm_ic = FALSE;

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


// When extra == 0: Return TRUE if the cursor is before or on the first
// non-blank in the line.
// When extra == 1: Return TRUE if the cursor is before the first non-blank in
// the line.
int inindent(int extra)
{
  char_u      *ptr;
  colnr_T col;

  for (col = 0, ptr = ml_get_curline(); vim_iswhite(*ptr); ++col) {
    ptr++;
  }

  if (col >= curwin->w_cursor.col + extra) {
    return TRUE;
  } else {
    return FALSE;
  }
}


// Get indent level from 'indentexpr'.
int get_expr_indent(void)
{
  int indent;
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
  set_vim_var_nr(VV_LNUM, curwin->w_cursor.lnum);

  if (use_sandbox) {
    sandbox++;
  }
  textlock++;
  indent = eval_to_number(curbuf->b_p_inde);

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

// TODO:
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

    if ((pos == NULL) || ltp(pos, &paren)) {
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

      for (that = ml_get_curline(); *that != NUL; ++that) {
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

      that = ml_get_curline();

      if (vi_lisp && (get_indent() == 0)) {
        amount = 2;
      } else {
        amount = 0;

        while (*that && col) {
          amount += lbr_chartabsize_adv(&that, (colnr_T)amount);
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

          while (vim_iswhite(*that)) {
            amount += lbr_chartabsize(that, (colnr_T)amount);
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

              while (*that && (!vim_iswhite(*that) || quotecount || parencount)
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
                  amount += lbr_chartabsize_adv(&that, (colnr_T)amount);
                }

                amount += lbr_chartabsize_adv(&that, (colnr_T)amount);
              }
            }

            while (vim_iswhite(*that)) {
              amount += lbr_chartabsize(that, (colnr_T)amount);
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
  char_u *word = p_lispwords;

  while (*word != NUL) {
    (void)copy_option_part(&word, buf, LSIZE, ",");
    len = (int)STRLEN(buf);

    if ((STRNCMP(buf, p, len) == 0) && (p[len] == ' ')) {
      return TRUE;
    }
  }
  return FALSE;
}
