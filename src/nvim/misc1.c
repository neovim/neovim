// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * misc1.c: functions that didn't seem to fit elsewhere
 */

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>
#include <limits.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/misc1.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/func_attr.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/buffer_updates.h"
#include "nvim/main.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/garray.h"
#include "nvim/move.h"
#include "nvim/mouse.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/state.h"
#include "nvim/strings.h"
#include "nvim/tag.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/window.h"
#include "nvim/os/os.h"
#include "nvim/os/shell.h"
#include "nvim/os/signal.h"
#include "nvim/os/input.h"
#include "nvim/os/time.h"
#include "nvim/event/stream.h"
#include "nvim/buffer.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "misc1.c.generated.h"
#endif
/* All user names (for ~user completion as done by shell). */
static garray_T ga_users = GA_EMPTY_INIT_VALUE;

/*
 * open_line: Add a new line below or above the current line.
 *
 * For VREPLACE mode, we only add a new line when we get to the end of the
 * file, otherwise we just start replacing the next line.
 *
 * Caller must take care of undo.  Since VREPLACE may affect any number of
 * lines however, it may call u_save_cursor() again when starting to change a
 * new line.
 * "flags": OPENLINE_DELSPACES	delete spaces after cursor
 *	    OPENLINE_DO_COM	format comments
 *	    OPENLINE_KEEPTRAIL	keep trailing spaces
 *	    OPENLINE_MARKFIX	adjust mark positions after the line break
 *	    OPENLINE_COM_LIST	format comments with list or 2nd line indent
 *
 * "second_line_indent": indent for after ^^D in Insert mode or if flag
 *			  OPENLINE_COM_LIST
 *
 * Return TRUE for success, FALSE for failure
 */
int 
open_line (
    int dir,                        /* FORWARD or BACKWARD */
    int flags,
    int second_line_indent
)
{
  char_u *next_line = NULL;       // copy of the next line
  char_u *p_extra = NULL;         // what goes to next line
  colnr_T less_cols = 0;          // less columns for mark in new line
  colnr_T less_cols_off = 0;      // columns to skip for mark adjust
  pos_T old_cursor;               // old cursor position
  colnr_T newcol = 0;             // new cursor column
  int newindent = 0;              // auto-indent of the new line
  bool trunc_line = false;        // truncate current line afterwards
  bool retval = false;            // return value
  int extra_len = 0;              // length of p_extra string
  int lead_len;                   // length of comment leader
  char_u *lead_flags;             // position in 'comments' for comment leader
  char_u *leader = NULL;          // copy of comment leader
  char_u *allocated = NULL;       // allocated memory
  char_u *p;
  char_u saved_char = NUL;        // init for GCC
  pos_T *pos;
  bool do_si = (!p_paste && curbuf->b_p_si && !curbuf->b_p_cin
                && *curbuf->b_p_inde == NUL);
  bool no_si = false;             // reset did_si afterwards
  int first_char = NUL;           // init for GCC
  int vreplace_mode;
  bool did_append;                // appended a new line
  int saved_pi = curbuf->b_p_pi;  // copy of preserveindent setting

  // make a copy of the current line so we can mess with it
  char_u *saved_line = vim_strsave(get_cursor_line_ptr());

  if (State & VREPLACE_FLAG) {
    /*
     * With VREPLACE we make a copy of the next line, which we will be
     * starting to replace.  First make the new line empty and let vim play
     * with the indenting and comment leader to its heart's content.  Then
     * we grab what it ended up putting on the new line, put back the
     * original line, and call ins_char() to put each new character onto
     * the line, replacing what was there before and pushing the right
     * stuff onto the replace stack.  -- webb.
     */
    if (curwin->w_cursor.lnum < orig_line_count)
      next_line = vim_strsave(ml_get(curwin->w_cursor.lnum + 1));
    else
      next_line = vim_strsave((char_u *)"");

    /*
     * In VREPLACE mode, a NL replaces the rest of the line, and starts
     * replacing the next line, so push all of the characters left on the
     * line onto the replace stack.  We'll push any other characters that
     * might be replaced at the start of the next line (due to autoindent
     * etc) a bit later.
     */
    replace_push(NUL);      /* Call twice because BS over NL expects it */
    replace_push(NUL);
    p = saved_line + curwin->w_cursor.col;
    while (*p != NUL) {
      if (has_mbyte)
        p += replace_push_mb(p);
      else
        replace_push(*p++);
    }
    saved_line[curwin->w_cursor.col] = NUL;
  }

  if ((State & INSERT)
      && !(State & VREPLACE_FLAG)
      ) {
    p_extra = saved_line + curwin->w_cursor.col;
    if (do_si) {                /* need first char after new line break */
      p = skipwhite(p_extra);
      first_char = *p;
    }
    extra_len = (int)STRLEN(p_extra);
    saved_char = *p_extra;
    *p_extra = NUL;
  }

  u_clearline();                // cannot do "U" command when adding lines
  did_si = false;
  ai_col = 0;

  /*
   * If we just did an auto-indent, then we didn't type anything on
   * the prior line, and it should be truncated.  Do this even if 'ai' is not
   * set because automatically inserting a comment leader also sets did_ai.
   */
  if (dir == FORWARD && did_ai)
    trunc_line = TRUE;

  /*
   * If 'autoindent' and/or 'smartindent' is set, try to figure out what
   * indent to use for the new line.
   */
  if (curbuf->b_p_ai
      || do_si
      ) {
    // count white space on current line
    newindent = get_indent_str(saved_line, (int)curbuf->b_p_ts, false);
    if (newindent == 0 && !(flags & OPENLINE_COM_LIST)) {
      newindent = second_line_indent;  // for ^^D command in insert mode
    }

    /*
     * Do smart indenting.
     * In insert/replace mode (only when dir == FORWARD)
     * we may move some text to the next line. If it starts with '{'
     * don't add an indent. Fixes inserting a NL before '{' in line
     *	"if (condition) {"
     */
    if (!trunc_line && do_si && *saved_line != NUL
        && (p_extra == NULL || first_char != '{')) {
      char_u  *ptr;
      char_u last_char;

      old_cursor = curwin->w_cursor;
      ptr = saved_line;
      if (flags & OPENLINE_DO_COM)
        lead_len = get_leader_len(ptr, NULL, FALSE, TRUE);
      else
        lead_len = 0;
      if (dir == FORWARD) {
        // Skip preprocessor directives, unless they are
        // recognised as comments.
        if (lead_len == 0 && ptr[0] == '#') {
          while (ptr[0] == '#' && curwin->w_cursor.lnum > 1) {
            ptr = ml_get(--curwin->w_cursor.lnum);
          }
          newindent = get_indent();
        }
        if (flags & OPENLINE_DO_COM)
          lead_len = get_leader_len(ptr, NULL, FALSE, TRUE);
        else
          lead_len = 0;
        if (lead_len > 0) {
          /*
           * This case gets the following right:
           *	    \*
           *	     * A comment (read '\' as '/').
           *	     *\
           * #define IN_THE_WAY
           *	    This should line up here;
           */
          p = skipwhite(ptr);
          if (p[0] == '/' && p[1] == '*')
            p++;
          if (p[0] == '*') {
            for (p++; *p; p++) {
              if (p[0] == '/' && p[-1] == '*') {
                /*
                 * End of C comment, indent should line up
                 * with the line containing the start of
                 * the comment
                 */
                curwin->w_cursor.col = (colnr_T)(p - ptr);
                if ((pos = findmatch(NULL, NUL)) != NULL) {
                  curwin->w_cursor.lnum = pos->lnum;
                  newindent = get_indent();
                }
              }
            }
          }
        } else {      /* Not a comment line */
          /* Find last non-blank in line */
          p = ptr + STRLEN(ptr) - 1;
          while (p > ptr && ascii_iswhite(*p))
            --p;
          last_char = *p;

          /*
           * find the character just before the '{' or ';'
           */
          if (last_char == '{' || last_char == ';') {
            if (p > ptr)
              --p;
            while (p > ptr && ascii_iswhite(*p))
              --p;
          }
          /*
           * Try to catch lines that are split over multiple
           * lines.  eg:
           *	    if (condition &&
           *			condition) {
           *		Should line up here!
           *	    }
           */
          if (*p == ')') {
            curwin->w_cursor.col = (colnr_T)(p - ptr);
            if ((pos = findmatch(NULL, '(')) != NULL) {
              curwin->w_cursor.lnum = pos->lnum;
              newindent = get_indent();
              ptr = get_cursor_line_ptr();
            }
          }
          /*
           * If last character is '{' do indent, without
           * checking for "if" and the like.
           */
          if (last_char == '{') {
            did_si = true;              // do indent
            no_si = true;               // don't delete it when '{' typed
          }
          /*
           * Look for "if" and the like, use 'cinwords'.
           * Don't do this if the previous line ended in ';' or
           * '}'.
           */
          else if (last_char != ';' && last_char != '}'
                   && cin_is_cinword(ptr))
            did_si = true;
        }
      } else {  // dir == BACKWARD
        // Skip preprocessor directives, unless they are
        // recognised as comments.
        if (lead_len == 0 && ptr[0] == '#') {
          bool was_backslashed = false;

          while ((ptr[0] == '#' || was_backslashed)
                 && curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count) {
            if (*ptr && ptr[STRLEN(ptr) - 1] == '\\') {
              was_backslashed = true;
            } else {
              was_backslashed = false;
            }
            ptr = ml_get(++curwin->w_cursor.lnum);
          }
          if (was_backslashed) {
            newindent = 0;  // Got to end of file
          } else {
            newindent = get_indent();
          }
        }
        p = skipwhite(ptr);
        if (*p == '}') {            // if line starts with '}': do indent
          did_si = true;
        } else {                    // can delete indent when '{' typed
          can_si_back = true;
        }
      }
      curwin->w_cursor = old_cursor;
    }
    if (do_si) {
      can_si = true;
    }

    did_ai = true;
  }

  /*
   * Find out if the current line starts with a comment leader.
   * This may then be inserted in front of the new line.
   */
  end_comment_pending = NUL;
  if (flags & OPENLINE_DO_COM)
    lead_len = get_leader_len(saved_line, &lead_flags, dir == BACKWARD, TRUE);
  else
    lead_len = 0;
  if (lead_len > 0) {
    char_u  *lead_repl = NULL;              /* replaces comment leader */
    int lead_repl_len = 0;                  /* length of *lead_repl */
    char_u lead_middle[COM_MAX_LEN];        /* middle-comment string */
    char_u lead_end[COM_MAX_LEN];           /* end-comment string */
    char_u  *comment_end = NULL;            /* where lead_end has been found */
    int extra_space = FALSE;                /* append extra space */
    int current_flag;
    int require_blank = FALSE;              /* requires blank after middle */
    char_u  *p2;

    /*
     * If the comment leader has the start, middle or end flag, it may not
     * be used or may be replaced with the middle leader.
     */
    for (p = lead_flags; *p && *p != ':'; ++p) {
      if (*p == COM_BLANK) {
        require_blank = TRUE;
        continue;
      }
      if (*p == COM_START || *p == COM_MIDDLE) {
        current_flag = *p;
        if (*p == COM_START) {
          /*
           * Doing "O" on a start of comment does not insert leader.
           */
          if (dir == BACKWARD) {
            lead_len = 0;
            break;
          }

          /* find start of middle part */
          (void)copy_option_part(&p, lead_middle, COM_MAX_LEN, ",");
          require_blank = FALSE;
        }

        /*
         * Isolate the strings of the middle and end leader.
         */
        while (*p && p[-1] != ':') {            /* find end of middle flags */
          if (*p == COM_BLANK)
            require_blank = TRUE;
          ++p;
        }
        (void)copy_option_part(&p, lead_middle, COM_MAX_LEN, ",");

        while (*p && p[-1] != ':') {            /* find end of end flags */
          /* Check whether we allow automatic ending of comments */
          if (*p == COM_AUTO_END)
            end_comment_pending = -1;             /* means we want to set it */
          ++p;
        }
        size_t n = copy_option_part(&p, lead_end, COM_MAX_LEN, ",");

        if (end_comment_pending == -1)          /* we can set it now */
          end_comment_pending = lead_end[n - 1];

        /*
         * If the end of the comment is in the same line, don't use
         * the comment leader.
         */
        if (dir == FORWARD) {
          for (p = saved_line + lead_len; *p; ++p)
            if (STRNCMP(p, lead_end, n) == 0) {
              comment_end = p;
              lead_len = 0;
              break;
            }
        }

        /*
         * Doing "o" on a start of comment inserts the middle leader.
         */
        if (lead_len > 0) {
          if (current_flag == COM_START) {
            lead_repl = lead_middle;
            lead_repl_len = (int)STRLEN(lead_middle);
          }

          /*
           * If we have hit RETURN immediately after the start
           * comment leader, then put a space after the middle
           * comment leader on the next line.
           */
          if (!ascii_iswhite(saved_line[lead_len - 1])
              && ((p_extra != NULL
                   && (int)curwin->w_cursor.col == lead_len)
                  || (p_extra == NULL
                      && saved_line[lead_len] == NUL)
                  || require_blank))
            extra_space = TRUE;
        }
        break;
      }
      if (*p == COM_END) {
        /*
         * Doing "o" on the end of a comment does not insert leader.
         * Remember where the end is, might want to use it to find the
         * start (for C-comments).
         */
        if (dir == FORWARD) {
          comment_end = skipwhite(saved_line);
          lead_len = 0;
          break;
        }

        /*
         * Doing "O" on the end of a comment inserts the middle leader.
         * Find the string for the middle leader, searching backwards.
         */
        while (p > curbuf->b_p_com && *p != ',')
          --p;
        for (lead_repl = p; lead_repl > curbuf->b_p_com
             && lead_repl[-1] != ':'; --lead_repl)
          ;
        lead_repl_len = (int)(p - lead_repl);

        /* We can probably always add an extra space when doing "O" on
         * the comment-end */
        extra_space = TRUE;

        /* Check whether we allow automatic ending of comments */
        for (p2 = p; *p2 && *p2 != ':'; p2++) {
          if (*p2 == COM_AUTO_END)
            end_comment_pending = -1;             /* means we want to set it */
        }
        if (end_comment_pending == -1) {
          /* Find last character in end-comment string */
          while (*p2 && *p2 != ',')
            p2++;
          end_comment_pending = p2[-1];
        }
        break;
      }
      if (*p == COM_FIRST) {
        /*
         * Comment leader for first line only:	Don't repeat leader
         * when using "O", blank out leader when using "o".
         */
        if (dir == BACKWARD)
          lead_len = 0;
        else {
          lead_repl = (char_u *)"";
          lead_repl_len = 0;
        }
        break;
      }
    }
    if (lead_len > 0) {
      // allocate buffer (may concatenate p_extra later)
      int bytes = lead_len
          + lead_repl_len
          + extra_space
          + extra_len
          + (second_line_indent > 0 ? second_line_indent : 0)
          + 1;
      assert(bytes >= 0);
      leader = xmalloc((size_t)bytes);
      allocated = leader;  // remember to free it later

      STRLCPY(leader, saved_line, lead_len + 1);

      /*
       * Replace leader with lead_repl, right or left adjusted
       */
      if (lead_repl != NULL) {
        int c = 0;
        int off = 0;

        for (p = lead_flags; *p != NUL && *p != ':'; ) {
          if (*p == COM_RIGHT || *p == COM_LEFT)
            c = *p++;
          else if (ascii_isdigit(*p) || *p == '-')
            off = getdigits_int(&p);
          else
            ++p;
        }
        if (c == COM_RIGHT) {            /* right adjusted leader */
          /* find last non-white in the leader to line up with */
          for (p = leader + lead_len - 1; p > leader
               && ascii_iswhite(*p); --p)
            ;
          ++p;

          /* Compute the length of the replaced characters in
           * screen characters, not bytes. */
          {
            int repl_size = vim_strnsize(lead_repl,
                lead_repl_len);
            int old_size = 0;
            char_u  *endp = p;
            int l;

            while (old_size < repl_size && p > leader) {
              MB_PTR_BACK(leader, p);
              old_size += ptr2cells(p);
            }
            l = lead_repl_len - (int)(endp - p);
            if (l != 0)
              memmove(endp + l, endp,
                  (size_t)((leader + lead_len) - endp));
            lead_len += l;
          }
          memmove(p, lead_repl, (size_t)lead_repl_len);
          if (p + lead_repl_len > leader + lead_len)
            p[lead_repl_len] = NUL;

          /* blank-out any other chars from the old leader. */
          while (--p >= leader) {
            int l = utf_head_off(leader, p);

            if (l > 1) {
              p -= l;
              if (ptr2cells(p) > 1) {
                p[1] = ' ';
                --l;
              }
              memmove(p + 1, p + l + 1,
                  (size_t)((leader + lead_len) - (p + l + 1)));
              lead_len -= l;
              *p = ' ';
            } else if (!ascii_iswhite(*p))
              *p = ' ';
          }
        } else {                        /* left adjusted leader */
          p = skipwhite(leader);
          /* Compute the length of the replaced characters in
           * screen characters, not bytes. Move the part that is
           * not to be overwritten. */
          {
            int repl_size = vim_strnsize(lead_repl,
                lead_repl_len);
            int i;
            int l;

            for (i = 0; i < lead_len && p[i] != NUL; i += l) {
              l = (*mb_ptr2len)(p + i);
              if (vim_strnsize(p, i + l) > repl_size)
                break;
            }
            if (i != lead_repl_len) {
              memmove(p + lead_repl_len, p + i,
                  (size_t)(lead_len - i - (p - leader)));
              lead_len += lead_repl_len - i;
            }
          }
          memmove(p, lead_repl, (size_t)lead_repl_len);

          /* Replace any remaining non-white chars in the old
           * leader by spaces.  Keep Tabs, the indent must
           * remain the same. */
          for (p += lead_repl_len; p < leader + lead_len; ++p)
            if (!ascii_iswhite(*p)) {
              /* Don't put a space before a TAB. */
              if (p + 1 < leader + lead_len && p[1] == TAB) {
                lead_len--;
                memmove(p, p + 1, (size_t)(leader + lead_len - p));
              } else {
                int l = (*mb_ptr2len)(p);

                if (l > 1) {
                  if (ptr2cells(p) > 1) {
                    /* Replace a double-wide char with
                     * two spaces */
                    --l;
                    *p++ = ' ';
                  }
                  memmove(p + 1, p + l, (size_t)(leader + lead_len - p));
                  lead_len -= l - 1;
                }
                *p = ' ';
              }
            }
          *p = NUL;
        }

        /* Recompute the indent, it may have changed. */
        if (curbuf->b_p_ai
            || do_si
            )
          newindent = get_indent_str(leader, (int)curbuf->b_p_ts, false);

        /* Add the indent offset */
        if (newindent + off < 0) {
          off = -newindent;
          newindent = 0;
        } else
          newindent += off;

        /* Correct trailing spaces for the shift, so that
         * alignment remains equal. */
        while (off > 0 && lead_len > 0
               && leader[lead_len - 1] == ' ') {
          /* Don't do it when there is a tab before the space */
          if (vim_strchr(skipwhite(leader), '\t') != NULL)
            break;
          --lead_len;
          --off;
        }

        /* If the leader ends in white space, don't add an
         * extra space */
        if (lead_len > 0 && ascii_iswhite(leader[lead_len - 1]))
          extra_space = FALSE;
        leader[lead_len] = NUL;
      }

      if (extra_space) {
        leader[lead_len++] = ' ';
        leader[lead_len] = NUL;
      }

      newcol = lead_len;

      /*
       * if a new indent will be set below, remove the indent that
       * is in the comment leader
       */
      if (newindent
          || did_si
          ) {
        while (lead_len && ascii_iswhite(*leader)) {
          --lead_len;
          --newcol;
          ++leader;
        }
      }

      did_si = can_si = false;
    } else if (comment_end != NULL) {
      // We have finished a comment, so we don't use the leader.
      // If this was a C-comment and 'ai' or 'si' is set do a normal
      // indent to align with the line containing the start of the
      // comment.
      if (comment_end[0] == '*' && comment_end[1] == '/'
          && (curbuf->b_p_ai || do_si)) {
        old_cursor = curwin->w_cursor;
        curwin->w_cursor.col = (colnr_T)(comment_end - saved_line);
        if ((pos = findmatch(NULL, NUL)) != NULL) {
          curwin->w_cursor.lnum = pos->lnum;
          newindent = get_indent();
        }
        curwin->w_cursor = old_cursor;
      }
    }
  }

  /* (State == INSERT || State == REPLACE), only when dir == FORWARD */
  if (p_extra != NULL) {
    *p_extra = saved_char;              /* restore char that NUL replaced */

    /*
     * When 'ai' set or "flags" has OPENLINE_DELSPACES, skip to the first
     * non-blank.
     *
     * When in REPLACE mode, put the deleted blanks on the replace stack,
     * preceded by a NUL, so they can be put back when a BS is entered.
     */
    if (REPLACE_NORMAL(State))
      replace_push(NUL);            /* end of extra blanks */
    if (curbuf->b_p_ai || (flags & OPENLINE_DELSPACES)) {
      while ((*p_extra == ' ' || *p_extra == '\t')
             && !utf_iscomposing(utf_ptr2char(p_extra + 1))) {
        if (REPLACE_NORMAL(State)) {
          replace_push(*p_extra);
        }
        p_extra++;
        less_cols_off++;
      }
    }

    /* columns for marks adjusted for removed columns */
    less_cols = (int)(p_extra - saved_line);
  }

  if (p_extra == NULL)
    p_extra = (char_u *)"";                 /* append empty line */

  /* concatenate leader and p_extra, if there is a leader */
  if (lead_len > 0) {
    if (flags & OPENLINE_COM_LIST && second_line_indent > 0) {
      int i;
      int padding = second_line_indent
                    - (newindent + (int)STRLEN(leader));

      /* Here whitespace is inserted after the comment char.
       * Below, set_indent(newindent, SIN_INSERT) will insert the
       * whitespace needed before the comment char. */
      for (i = 0; i < padding; i++) {
        STRCAT(leader, " ");
        less_cols--;
        newcol++;
      }
    }
    STRCAT(leader, p_extra);
    p_extra = leader;
    did_ai = true;          // So truncating blanks works with comments
    less_cols -= lead_len;
  } else
    end_comment_pending = NUL;      /* turns out there was no leader */

  old_cursor = curwin->w_cursor;
  if (dir == BACKWARD)
    --curwin->w_cursor.lnum;
  if (!(State & VREPLACE_FLAG) || old_cursor.lnum >= orig_line_count) {
    if (ml_append(curwin->w_cursor.lnum, p_extra, (colnr_T)0, false) == FAIL) {
      goto theend;
    }
    // Postpone calling changed_lines(), because it would mess up folding
    // with markers.
    // Skip mark_adjust when adding a line after the last one, there can't
    // be marks there. But still needed in diff mode.
    if (curwin->w_cursor.lnum + 1 < curbuf->b_ml.ml_line_count
        || curwin->w_p_diff) {
      mark_adjust(curwin->w_cursor.lnum + 1, (linenr_T)MAXLNUM, 1L, 0L, false);
    }
    did_append = true;
  } else {
    /*
     * In VREPLACE mode we are starting to replace the next line.
     */
    curwin->w_cursor.lnum++;
    if (curwin->w_cursor.lnum >= Insstart.lnum + vr_lines_changed) {
      /* In case we NL to a new line, BS to the previous one, and NL
       * again, we don't want to save the new line for undo twice.
       */
      (void)u_save_cursor();                        /* errors are ignored! */
      vr_lines_changed++;
    }
    ml_replace(curwin->w_cursor.lnum, p_extra, true);
    changed_bytes(curwin->w_cursor.lnum, 0);
    curwin->w_cursor.lnum--;
    did_append = FALSE;
  }

  inhibit_delete_count++;
  if (newindent
      || did_si
      ) {
    ++curwin->w_cursor.lnum;
    if (did_si) {
      int sw = get_sw_value(curbuf);

      if (p_sr)
        newindent -= newindent % sw;
      newindent += sw;
    }
    /* Copy the indent */
    if (curbuf->b_p_ci) {
      (void)copy_indent(newindent, saved_line);

      /*
       * Set the 'preserveindent' option so that any further screwing
       * with the line doesn't entirely destroy our efforts to preserve
       * it.  It gets restored at the function end.
       */
      curbuf->b_p_pi = TRUE;
    } else
      (void)set_indent(newindent, SIN_INSERT);
    less_cols -= curwin->w_cursor.col;

    ai_col = curwin->w_cursor.col;

    /*
     * In REPLACE mode, for each character in the new indent, there must
     * be a NUL on the replace stack, for when it is deleted with BS
     */
    if (REPLACE_NORMAL(State)) {
      for (colnr_T n = 0; n < curwin->w_cursor.col; n++) {
        replace_push(NUL);
      }
    }
    newcol += curwin->w_cursor.col;
    if (no_si) {
      did_si = false;
    }
  }
  inhibit_delete_count--;

  /*
   * In REPLACE mode, for each character in the extra leader, there must be
   * a NUL on the replace stack, for when it is deleted with BS.
   */
  if (REPLACE_NORMAL(State))
    while (lead_len-- > 0)
      replace_push(NUL);

  curwin->w_cursor = old_cursor;

  if (dir == FORWARD) {
    if (trunc_line || (State & INSERT)) {
      // truncate current line at cursor
      saved_line[curwin->w_cursor.col] = NUL;
      // Remove trailing white space, unless OPENLINE_KEEPTRAIL used.
      if (trunc_line && !(flags & OPENLINE_KEEPTRAIL)) {
        truncate_spaces(saved_line);
      }
      ml_replace(curwin->w_cursor.lnum, saved_line, false);
      saved_line = NULL;
      if (did_append) {
        changed_lines(curwin->w_cursor.lnum, curwin->w_cursor.col,
                      curwin->w_cursor.lnum + 1, 1L, true);
        did_append = false;

        /* Move marks after the line break to the new line. */
        if (flags & OPENLINE_MARKFIX)
          mark_col_adjust(curwin->w_cursor.lnum,
                          curwin->w_cursor.col + less_cols_off,
                          1L, (long)-less_cols, 0);
      } else {
        changed_bytes(curwin->w_cursor.lnum, curwin->w_cursor.col);
      }
    }

    /*
     * Put the cursor on the new line.  Careful: the scrollup() above may
     * have moved w_cursor, we must use old_cursor.
     */
    curwin->w_cursor.lnum = old_cursor.lnum + 1;
  }
  if (did_append) {
    changed_lines(curwin->w_cursor.lnum, 0, curwin->w_cursor.lnum, 1L, true);
  }

  curwin->w_cursor.col = newcol;
  curwin->w_cursor.coladd = 0;

  /*
   * In VREPLACE mode, we are handling the replace stack ourselves, so stop
   * fixthisline() from doing it (via change_indent()) by telling it we're in
   * normal INSERT mode.
   */
  if (State & VREPLACE_FLAG) {
    vreplace_mode = State;      /* So we know to put things right later */
    State = INSERT;
  } else
    vreplace_mode = 0;
  /*
   * May do lisp indenting.
   */
  if (!p_paste
      && leader == NULL
      && curbuf->b_p_lisp
      && curbuf->b_p_ai) {
    fixthisline(get_lisp_indent);
    ai_col = (colnr_T)getwhitecols_curline();
  }
  /*
   * May do indenting after opening a new line.
   */
  if (!p_paste
      && (curbuf->b_p_cin
          || *curbuf->b_p_inde != NUL
          )
      && in_cinkeys(dir == FORWARD
          ? KEY_OPEN_FORW
          : KEY_OPEN_BACK, ' ', linewhite(curwin->w_cursor.lnum))) {
    do_c_expr_indent();
    ai_col = (colnr_T)getwhitecols_curline();
  }
  if (vreplace_mode != 0)
    State = vreplace_mode;

  /*
   * Finally, VREPLACE gets the stuff on the new line, then puts back the
   * original line, and inserts the new stuff char by char, pushing old stuff
   * onto the replace stack (via ins_char()).
   */
  if (State & VREPLACE_FLAG) {
    /* Put new line in p_extra */
    p_extra = vim_strsave(get_cursor_line_ptr());

    // Put back original line
    ml_replace(curwin->w_cursor.lnum, next_line, false);

    /* Insert new stuff into line again */
    curwin->w_cursor.col = 0;
    curwin->w_cursor.coladd = 0;
    ins_bytes(p_extra);         /* will call changed_bytes() */
    xfree(p_extra);
    next_line = NULL;
  }

  retval = true;                // success!
theend:
  curbuf->b_p_pi = saved_pi;
  xfree(saved_line);
  xfree(next_line);
  xfree(allocated);
  return retval;
}

/*
 * get_leader_len() returns the length in bytes of the prefix of the given
 * string which introduces a comment.  If this string is not a comment then
 * 0 is returned.
 * When "flags" is not NULL, it is set to point to the flags of the recognized
 * comment leader.
 * "backward" must be true for the "O" command.
 * If "include_space" is set, include trailing whitespace while calculating the
 * length.
 */
int get_leader_len(char_u *line, char_u **flags, int backward, int include_space)
{
  int i, j;
  int result;
  int got_com = FALSE;
  int found_one;
  char_u part_buf[COM_MAX_LEN];         /* buffer for one option part */
  char_u      *string;                  /* pointer to comment string */
  char_u      *list;
  int middle_match_len = 0;
  char_u      *prev_list;
  char_u      *saved_flags = NULL;

  result = i = 0;
  while (ascii_iswhite(line[i]))      /* leading white space is ignored */
    ++i;

  /*
   * Repeat to match several nested comment strings.
   */
  while (line[i] != NUL) {
    /*
     * scan through the 'comments' option for a match
     */
    found_one = FALSE;
    for (list = curbuf->b_p_com; *list; ) {
      /* Get one option part into part_buf[].  Advance "list" to next
       * one.  Put "string" at start of string.  */
      if (!got_com && flags != NULL)
        *flags = list;              /* remember where flags started */
      prev_list = list;
      (void)copy_option_part(&list, part_buf, COM_MAX_LEN, ",");
      string = vim_strchr(part_buf, ':');
      if (string == NULL)           /* missing ':', ignore this part */
        continue;
      *string++ = NUL;              /* isolate flags from string */

      /* If we found a middle match previously, use that match when this
       * is not a middle or end. */
      if (middle_match_len != 0
          && vim_strchr(part_buf, COM_MIDDLE) == NULL
          && vim_strchr(part_buf, COM_END) == NULL)
        break;

      /* When we already found a nested comment, only accept further
       * nested comments. */
      if (got_com && vim_strchr(part_buf, COM_NEST) == NULL)
        continue;

      /* When 'O' flag present and using "O" command skip this one. */
      if (backward && vim_strchr(part_buf, COM_NOBACK) != NULL)
        continue;

      /* Line contents and string must match.
       * When string starts with white space, must have some white space
       * (but the amount does not need to match, there might be a mix of
       * TABs and spaces). */
      if (ascii_iswhite(string[0])) {
        if (i == 0 || !ascii_iswhite(line[i - 1]))
          continue;            /* missing white space */
        while (ascii_iswhite(string[0]))
          ++string;
      }
      for (j = 0; string[j] != NUL && string[j] == line[i + j]; ++j)
        ;
      if (string[j] != NUL)
        continue;          /* string doesn't match */

      /* When 'b' flag used, there must be white space or an
       * end-of-line after the string in the line. */
      if (vim_strchr(part_buf, COM_BLANK) != NULL
          && !ascii_iswhite(line[i + j]) && line[i + j] != NUL)
        continue;

      /* We have found a match, stop searching unless this is a middle
       * comment. The middle comment can be a substring of the end
       * comment in which case it's better to return the length of the
       * end comment and its flags.  Thus we keep searching with middle
       * and end matches and use an end match if it matches better. */
      if (vim_strchr(part_buf, COM_MIDDLE) != NULL) {
        if (middle_match_len == 0) {
          middle_match_len = j;
          saved_flags = prev_list;
        }
        continue;
      }
      if (middle_match_len != 0 && j > middle_match_len)
        /* Use this match instead of the middle match, since it's a
         * longer thus better match. */
        middle_match_len = 0;

      if (middle_match_len == 0)
        i += j;
      found_one = TRUE;
      break;
    }

    if (middle_match_len != 0) {
      /* Use the previously found middle match after failing to find a
       * match with an end. */
      if (!got_com && flags != NULL)
        *flags = saved_flags;
      i += middle_match_len;
      found_one = TRUE;
    }

    /* No match found, stop scanning. */
    if (!found_one)
      break;

    result = i;

    /* Include any trailing white space. */
    while (ascii_iswhite(line[i]))
      ++i;

    if (include_space)
      result = i;

    /* If this comment doesn't nest, stop here. */
    got_com = TRUE;
    if (vim_strchr(part_buf, COM_NEST) == NULL)
      break;
  }
  return result;
}

/*
 * Return the offset at which the last comment in line starts. If there is no
 * comment in the whole line, -1 is returned.
 *
 * When "flags" is not null, it is set to point to the flags describing the
 * recognized comment leader.
 */
int get_last_leader_offset(char_u *line, char_u **flags)
{
  int result = -1;
  int i, j;
  int lower_check_bound = 0;
  char_u      *string;
  char_u      *com_leader;
  char_u      *com_flags;
  char_u      *list;
  int found_one;
  char_u part_buf[COM_MAX_LEN];         /* buffer for one option part */

  /*
   * Repeat to match several nested comment strings.
   */
  i = (int)STRLEN(line);
  while (--i >= lower_check_bound) {
    /*
     * scan through the 'comments' option for a match
     */
    found_one = FALSE;
    for (list = curbuf->b_p_com; *list; ) {
      char_u *flags_save = list;

      /*
       * Get one option part into part_buf[].  Advance list to next one.
       * put string at start of string.
       */
      (void)copy_option_part(&list, part_buf, COM_MAX_LEN, ",");
      string = vim_strchr(part_buf, ':');
      if (string == NULL) {     /* If everything is fine, this cannot actually
                                 * happen. */
        continue;
      }
      *string++ = NUL;          /* Isolate flags from string. */
      com_leader = string;

      /*
       * Line contents and string must match.
       * When string starts with white space, must have some white space
       * (but the amount does not need to match, there might be a mix of
       * TABs and spaces).
       */
      if (ascii_iswhite(string[0])) {
        if (i == 0 || !ascii_iswhite(line[i - 1]))
          continue;
        while (ascii_iswhite(*string)) {
          string++;
        }
      }
      for (j = 0; string[j] != NUL && string[j] == line[i + j]; ++j)
        /* do nothing */;
      if (string[j] != NUL)
        continue;

      /*
       * When 'b' flag used, there must be white space or an
       * end-of-line after the string in the line.
       */
      if (vim_strchr(part_buf, COM_BLANK) != NULL
          && !ascii_iswhite(line[i + j]) && line[i + j] != NUL) {
        continue;
      }

      if (vim_strchr(part_buf, COM_MIDDLE) != NULL) {
        // For a middlepart comment, only consider it to match if
        // everything before the current position in the line is
        // whitespace.  Otherwise we would think we are inside a
        // comment if the middle part appears somewhere in the middle
        // of the line.  E.g. for C the "*" appears often.
        for (j = 0; ascii_iswhite(line[j]) && j <= i; j++) {
        }
        if (j < i) {
          continue;
        }
      }

      /*
       * We have found a match, stop searching.
       */
      found_one = TRUE;

      if (flags)
        *flags = flags_save;
      com_flags = flags_save;

      break;
    }

    if (found_one) {
      char_u part_buf2[COM_MAX_LEN];            /* buffer for one option part */
      int len1, len2, off;

      result = i;
      /*
       * If this comment nests, continue searching.
       */
      if (vim_strchr(part_buf, COM_NEST) != NULL)
        continue;

      lower_check_bound = i;

      /* Let's verify whether the comment leader found is a substring
       * of other comment leaders. If it is, let's adjust the
       * lower_check_bound so that we make sure that we have determined
       * the comment leader correctly.
       */

      while (ascii_iswhite(*com_leader))
        ++com_leader;
      len1 = (int)STRLEN(com_leader);

      for (list = curbuf->b_p_com; *list; ) {
        char_u *flags_save = list;

        (void)copy_option_part(&list, part_buf2, COM_MAX_LEN, ",");
        if (flags_save == com_flags)
          continue;
        string = vim_strchr(part_buf2, ':');
        ++string;
        while (ascii_iswhite(*string))
          ++string;
        len2 = (int)STRLEN(string);
        if (len2 == 0)
          continue;

        /* Now we have to verify whether string ends with a substring
         * beginning the com_leader. */
        for (off = (len2 > i ? i : len2); off > 0 && off + len1 > len2; ) {
          --off;
          if (!STRNCMP(string + off, com_leader, len2 - off)) {
            if (i - off < lower_check_bound)
              lower_check_bound = i - off;
          }
        }
      }
    }
  }
  return result;
}

/*
 * Return the number of window lines occupied by buffer line "lnum".
 */
int plines(const linenr_T lnum)
{
  return plines_win(curwin, lnum, true);
}

int plines_win(
    win_T *const wp,
    const linenr_T lnum,
    const bool winheight          // when true limit to window height
)
{
  /* Check for filler lines above this buffer line.  When folded the result
   * is one line anyway. */
  return plines_win_nofill(wp, lnum, winheight) + diff_check_fill(wp, lnum);
}

int plines_nofill(const linenr_T lnum)
{
  return plines_win_nofill(curwin, lnum, true);
}

int plines_win_nofill(
    win_T *const wp,
    const linenr_T lnum,
    const bool winheight          // when true limit to window height
)
{
  if (!wp->w_p_wrap) {
    return 1;
  }

  if (wp->w_width_inner == 0) {
    return 1;
  }

  // A folded lines is handled just like an empty line.
  if (lineFolded(wp, lnum)) {
    return 1;
  }

  const int lines = plines_win_nofold(wp, lnum);
  if (winheight && lines > wp->w_height_inner) {
    return wp->w_height_inner;
  }
  return lines;
}

/*
 * Return number of window lines physical line "lnum" will occupy in window
 * "wp".  Does not care about folding, 'wrap' or 'diff'.
 */
int plines_win_nofold(win_T *wp, linenr_T lnum)
{
  char_u      *s;
  unsigned int col;
  int width;

  s = ml_get_buf(wp->w_buffer, lnum, FALSE);
  if (*s == NUL)                /* empty line */
    return 1;
  col = win_linetabsize(wp, s, (colnr_T)MAXCOL);

  // If list mode is on, then the '$' at the end of the line may take up one
  // extra column.
  if (wp->w_p_list && wp->w_p_lcs_chars.eol != NUL) {
    col += 1;
  }

  /*
   * Add column offset for 'number', 'relativenumber' and 'foldcolumn'.
   */
  width = wp->w_width_inner - win_col_off(wp);
  if (width <= 0 || col > 32000) {
    return 32000;  // bigger than the number of screen columns
  }
  if (col <= (unsigned int)width) {
    return 1;
  }
  col -= (unsigned int)width;
  width += win_col_off2(wp);
  assert(col <= INT_MAX && (int)col < INT_MAX - (width -1));
  return ((int)col + (width - 1)) / width + 1;
}

/*
 * Like plines_win(), but only reports the number of physical screen lines
 * used from the start of the line to the given column number.
 */
int plines_win_col(win_T *wp, linenr_T lnum, long column)
{
  // Check for filler lines above this buffer line.  When folded the result
  // is one line anyway.
  int lines = diff_check_fill(wp, lnum);

  if (!wp->w_p_wrap)
    return lines + 1;

  if (wp->w_width_inner == 0) {
    return lines + 1;
  }

  char_u *line = ml_get_buf(wp->w_buffer, lnum, false);
  char_u *s = line;

  colnr_T col = 0;
  while (*s != NUL && --column >= 0) {
    col += win_lbr_chartabsize(wp, line, s, col, NULL);
    MB_PTR_ADV(s);
  }

  // If *s is a TAB, and the TAB is not displayed as ^I, and we're not in
  // INSERT mode, then col must be adjusted so that it represents the last
  // screen position of the TAB.  This only fixes an error when the TAB wraps
  // from one screen line to the next (when 'columns' is not a multiple of
  // 'ts') -- webb.
  if (*s == TAB && (State & NORMAL)
      && (!wp->w_p_list || wp->w_p_lcs_chars.tab1)) {
    col += win_lbr_chartabsize(wp, line, s, col, NULL) - 1;
  }

  // Add column offset for 'number', 'relativenumber', 'foldcolumn', etc.
  int width = wp->w_width_inner - win_col_off(wp);
  if (width <= 0) {
    return 9999;
  }

  lines += 1;
  if (col > width)
    lines += (col - width) / (width + win_col_off2(wp)) + 1;
  return lines;
}

int plines_m_win(win_T *wp, linenr_T first, linenr_T last)
{
  int count = 0;

  while (first <= last) {
    // Check if there are any really folded lines, but also included lines
    // that are maybe folded.
    linenr_T x = foldedCount(wp, first, NULL);
    if (x > 0) {
      ++count;              /* count 1 for "+-- folded" line */
      first += x;
    } else {
      if (first == wp->w_topline) {
        count += plines_win_nofill(wp, first, true) + wp->w_topfill;
      } else {
        count += plines_win(wp, first, true);
      }
      first++;
    }
  }
  return count;
}

/// Insert or replace a single character at the cursor position.
/// When in REPLACE or VREPLACE mode, replace any existing character.
/// Caller must have prepared for undo.
/// For multi-byte characters we get the whole character, the caller must
/// convert bytes to a character.
void ins_char(int c)
{
  char_u buf[MB_MAXBYTES + 1];
  size_t n = (size_t)utf_char2bytes(c, buf);

  // When "c" is 0x100, 0x200, etc. we don't want to insert a NUL byte.
  // Happens for CTRL-Vu9900.
  if (buf[0] == 0) {
    buf[0] = '\n';
  }
  ins_char_bytes(buf, n);
}

/*
 * Delete from cursor to end of line.
 * Caller must have prepared for undo.
 */
void
truncate_line (
    int fixpos                 /* if TRUE fix the cursor position when done */
)
{
  char_u      *newp;
  linenr_T lnum = curwin->w_cursor.lnum;
  colnr_T col = curwin->w_cursor.col;

  if (col == 0) {
    newp = vim_strsave((char_u *)"");
  } else {
    newp = vim_strnsave(ml_get(lnum), (size_t)col);
  }
  ml_replace(lnum, newp, false);

  /* mark the buffer as changed and prepare for displaying */
  changed_bytes(lnum, curwin->w_cursor.col);

  /*
   * If "fixpos" is TRUE we don't want to end up positioned at the NUL.
   */
  if (fixpos && curwin->w_cursor.col > 0)
    --curwin->w_cursor.col;
}

/*
 * Delete "nlines" lines at the cursor.
 * Saves the lines for undo first if "undo" is TRUE.
 */
void 
del_lines (
    long nlines,                    /* number of lines to delete */
    int undo                       /* if TRUE, prepare for undo */
)
{
  long n;
  linenr_T first = curwin->w_cursor.lnum;

  if (nlines <= 0)
    return;

  /* save the deleted lines for undo */
  if (undo && u_savedel(first, nlines) == FAIL)
    return;

  for (n = 0; n < nlines; ) {
    if (curbuf->b_ml.ml_flags & ML_EMPTY)           /* nothing to delete */
      break;

    ml_delete(first, true);
    n++;

    /* If we delete the last line in the file, stop */
    if (first > curbuf->b_ml.ml_line_count)
      break;
  }

  /* Correct the cursor position before calling deleted_lines_mark(), it may
   * trigger a callback to display the cursor. */
  curwin->w_cursor.col = 0;
  check_cursor_lnum();

  /* adjust marks, mark the buffer as changed and prepare for displaying */
  deleted_lines_mark(first, n);
}

int gchar_pos(pos_T *pos)
  FUNC_ATTR_NONNULL_ARG(1)
{
  // When searching columns is sometimes put at the end of a line.
  if (pos->col == MAXCOL) {
    return NUL;
  }
  return utf_ptr2char(ml_get_pos(pos));
}

/*
 * check_status: called when the status bars for the buffer 'buf'
 *		 need to be updated
 */
void check_status(buf_T *buf)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer == buf && wp->w_status_height) {
      wp->w_redr_status = TRUE;
      if (must_redraw < VALID) {
        must_redraw = VALID;
      }
    }
  }
}

/// Ask for a reply from the user, 'y' or 'n'
///
/// No other characters are accepted, the message is repeated until a valid
/// reply is entered or <C-c> is hit.
///
/// @param[in]  str  Prompt: question to ask user. Is always followed by
///                  " (y/n)?".
/// @param[in]  direct  Determines what function to use to get user input. If
///                     true then ui_inchar() will be used, otherwise vgetc().
///                     I.e. when direct is true then characters are obtained
///                     directly from the user without buffers involved.
///
/// @return 'y' or 'n'. Last is also what will be returned in case of interrupt.
int ask_yesno(const char *const str, const bool direct)
{
  const int save_State = State;

  no_wait_return++;
  State = CONFIRM;  // Mouse behaves like with :confirm.
  setmouse();  // Disable mouse in xterm.
  no_mapping++;

  int r = ' ';
  while (r != 'y' && r != 'n') {
    // Same highlighting as for wait_return.
    smsg_attr(HL_ATTR(HLF_R), "%s (y/n)?", str);
    if (direct) {
      r = get_keystroke();
    } else {
      r = plain_vgetc();
    }
    if (r == Ctrl_C || r == ESC) {
      r = 'n';
    }
    msg_putchar(r);  // Show what you typed.
    ui_flush();
  }
  no_wait_return--;
  State = save_State;
  setmouse();
  no_mapping--;

  return r;
}

/*
 * Return TRUE if "c" is a mouse key.
 */
int is_mouse_key(int c)
{
  return c == K_LEFTMOUSE
         || c == K_LEFTMOUSE_NM
         || c == K_LEFTDRAG
         || c == K_LEFTRELEASE
         || c == K_LEFTRELEASE_NM
         || c == K_MIDDLEMOUSE
         || c == K_MIDDLEDRAG
         || c == K_MIDDLERELEASE
         || c == K_RIGHTMOUSE
         || c == K_RIGHTDRAG
         || c == K_RIGHTRELEASE
         || c == K_MOUSEDOWN
         || c == K_MOUSEUP
         || c == K_MOUSELEFT
         || c == K_MOUSERIGHT
         || c == K_X1MOUSE
         || c == K_X1DRAG
         || c == K_X1RELEASE
         || c == K_X2MOUSE
         || c == K_X2DRAG
         || c == K_X2RELEASE;
}

/*
 * Get a key stroke directly from the user.
 * Ignores mouse clicks and scrollbar events, except a click for the left
 * button (used at the more prompt).
 * Doesn't use vgetc(), because it syncs undo and eats mapped characters.
 * Disadvantage: typeahead is ignored.
 * Translates the interrupt character for unix to ESC.
 */
int get_keystroke(void)
{
  char_u      *buf = NULL;
  int buflen = 150;
  int maxlen;
  int len = 0;
  int n;
  int save_mapped_ctrl_c = mapped_ctrl_c;
  int waited = 0;

  mapped_ctrl_c = 0;        // mappings are not used here
  for (;; ) {
    // flush output before waiting
    ui_flush();
    /* Leave some room for check_termcode() to insert a key code into (max
     * 5 chars plus NUL).  And fix_input_buffer() can triple the number of
     * bytes. */
    maxlen = (buflen - 6 - len) / 3;
    if (buf == NULL) {
      buf = xmalloc((size_t)buflen);
    } else if (maxlen < 10) {
      // Need some more space. This might happen when receiving a long
      // escape sequence.
      buflen += 100;
      buf = xrealloc(buf, (size_t)buflen);
      maxlen = (buflen - 6 - len) / 3;
    }

    /* First time: blocking wait.  Second time: wait up to 100ms for a
     * terminal code to complete. */
    n = os_inchar(buf + len, maxlen, len == 0 ? -1L : 100L, 0);
    if (n > 0) {
      // Replace zero and CSI by a special key code.
      n = fix_input_buffer(buf + len, n);
      len += n;
      waited = 0;
    } else if (len > 0)
      ++waited;             /* keep track of the waiting time */

    if (n == KEYLEN_REMOVED) {    /* key code removed */
      if (must_redraw != 0 && !need_wait_return && (State & CMDLINE) == 0) {
        /* Redrawing was postponed, do it now. */
        update_screen(0);
        setcursor();         /* put cursor back where it belongs */
      }
      continue;
    }
    if (n > 0)                  /* found a termcode: adjust length */
      len = n;
    if (len == 0)               /* nothing typed yet */
      continue;

    /* Handle modifier and/or special key code. */
    n = buf[0];
    if (n == K_SPECIAL) {
      n = TO_SPECIAL(buf[1], buf[2]);
      if (buf[1] == KS_MODIFIER
          || n == K_IGNORE
          || (is_mouse_key(n) && n != K_LEFTMOUSE)
          ) {
        if (buf[1] == KS_MODIFIER)
          mod_mask = buf[2];
        len -= 3;
        if (len > 0)
          memmove(buf, buf + 3, (size_t)len);
        continue;
      }
      break;
    }
    if (MB_BYTE2LEN(n) > len) {
      // more bytes to get.
      continue;
    }
    buf[len >= buflen ? buflen - 1 : len] = NUL;
    n = utf_ptr2char(buf);
    break;
  }
  xfree(buf);

  mapped_ctrl_c = save_mapped_ctrl_c;
  return n;
}

/*
 * Get a number from the user.
 * When "mouse_used" is not NULL allow using the mouse.
 */
int 
get_number (
    int colon,                              /* allow colon to abort */
    int *mouse_used
)
{
  int n = 0;
  int c;
  int typed = 0;

  if (mouse_used != NULL)
    *mouse_used = FALSE;

  /* When not printing messages, the user won't know what to type, return a
   * zero (as if CR was hit). */
  if (msg_silent != 0)
    return 0;

  no_mapping++;
  for (;; ) {
    ui_cursor_goto(msg_row, msg_col);
    c = safe_vgetc();
    if (ascii_isdigit(c)) {
      n = n * 10 + c - '0';
      msg_putchar(c);
      ++typed;
    } else if (c == K_DEL || c == K_KDEL || c == K_BS || c == Ctrl_H) {
      if (typed > 0) {
        MSG_PUTS("\b \b");
        --typed;
      }
      n /= 10;
    } else if (mouse_used != NULL && c == K_LEFTMOUSE) {
      *mouse_used = TRUE;
      n = mouse_row + 1;
      break;
    } else if (n == 0 && c == ':' && colon) {
      stuffcharReadbuff(':');
      if (!exmode_active)
        cmdline_row = msg_row;
      skip_redraw = TRUE;           /* skip redraw once */
      do_redraw = FALSE;
      break;
    } else if (c == CAR || c == NL || c == Ctrl_C || c == ESC)
      break;
  }
  no_mapping--;
  return n;
}

/*
 * Ask the user to enter a number.
 * When "mouse_used" is not NULL allow using the mouse and in that case return
 * the line number.
 */
int prompt_for_number(int *mouse_used)
{
  int i;
  int save_cmdline_row;
  int save_State;

  /* When using ":silent" assume that <CR> was entered. */
  if (mouse_used != NULL)
    MSG_PUTS(_("Type number and <Enter> or click with mouse (empty cancels): "));
  else
    MSG_PUTS(_("Type number and <Enter> (empty cancels): "));

  /* Set the state such that text can be selected/copied/pasted and we still
   * get mouse events. */
  save_cmdline_row = cmdline_row;
  cmdline_row = 0;
  save_State = State;
  State = ASKMORE;  // prevents a screen update when using a timer
  // May show different mouse shape.
  setmouse();

  i = get_number(TRUE, mouse_used);
  if (KeyTyped) {
    // don't call wait_return() now
    if (msg_row > 0) {
      cmdline_row = msg_row - 1;
    }
    need_wait_return = false;
    msg_didany = false;
    msg_didout = false;
  } else {
    cmdline_row = save_cmdline_row;
  }
  State = save_State;
  // May need to restore mouse shape.
  setmouse();

  return i;
}

void msgmore(long n)
{
  long pn;

  if (global_busy           /* no messages now, wait until global is finished */
      || !messaging())        /* 'lazyredraw' set, don't do messages now */
    return;

  /* We don't want to overwrite another important message, but do overwrite
   * a previous "more lines" or "fewer lines" message, so that "5dd" and
   * then "put" reports the last action. */
  if (keep_msg != NULL && !keep_msg_more)
    return;

  if (n > 0)
    pn = n;
  else
    pn = -n;

  if (pn > p_report) {
    if (pn == 1) {
      if (n > 0)
        STRLCPY(msg_buf, _("1 more line"), MSG_BUF_LEN);
      else
        STRLCPY(msg_buf, _("1 line less"), MSG_BUF_LEN);
    } else {
      if (n > 0)
        vim_snprintf((char *)msg_buf, MSG_BUF_LEN,
            _("%" PRId64 " more lines"), (int64_t)pn);
      else
        vim_snprintf((char *)msg_buf, MSG_BUF_LEN,
            _("%" PRId64 " fewer lines"), (int64_t)pn);
    }
    if (got_int) {
      xstrlcat((char *)msg_buf, _(" (Interrupted)"), MSG_BUF_LEN);
    }
    if (msg(msg_buf)) {
      set_keep_msg(msg_buf, 0);
      keep_msg_more = TRUE;
    }
  }
}

/*
 * flush map and typeahead buffers and give a warning for an error
 */
void beep_flush(void)
{
  if (emsg_silent == 0) {
    flush_buffers(FLUSH_MINIMAL);
    vim_beep(BO_ERROR);
  }
}

// Give a warning for an error
// val is one of the BO_ values, e.g., BO_OPER
void vim_beep(unsigned val)
{
  called_vim_beep = true;

  if (emsg_silent == 0) {
    if (!((bo_flags & val) || (bo_flags & BO_ALL))) {
      static int beeps = 0;
      static uint64_t start_time = 0;

      // Only beep up to three times per half a second,
      // otherwise a sequence of beeps would freeze Vim.
      if (start_time == 0 || os_hrtime() - start_time > 500000000u) {
        beeps = 0;
        start_time = os_hrtime();
      }
      beeps++;
      if (beeps <= 3) {
        if (p_vb) {
          ui_call_visual_bell();
        } else {
          ui_call_bell();
        }
      }
    }

    // When 'debug' contains "beep" produce a message.  If we are sourcing
    // a script or executing a function give the user a hint where the beep
    // comes from.
    if (vim_strchr(p_debug, 'e') != NULL) {
      msg_source(HL_ATTR(HLF_W));
      msg_attr(_("Beep!"), HL_ATTR(HLF_W));
    }
  }
}

#if defined(EXITFREE)

void free_users(void)
{
  ga_clear_strings(&ga_users);
}

#endif

/*
 * Find all user names for user completion.
 * Done only once and then cached.
 */
static void init_users(void)
{
  static int lazy_init_done = FALSE;

  if (lazy_init_done) {
    return;
  }

  lazy_init_done = TRUE;
  
  os_get_usernames(&ga_users);
}

/*
 * Function given to ExpandGeneric() to obtain an user names.
 */
char_u *get_users(expand_T *xp, int idx)
{
  init_users();
  if (idx < ga_users.ga_len)
    return ((char_u **)ga_users.ga_data)[idx];
  return NULL;
}

/*
 * Check whether name matches a user name. Return:
 * 0 if name does not match any user name.
 * 1 if name partially matches the beginning of a user name.
 * 2 is name fully matches a user name.
 */
int match_user(char_u *name)
{
  int n = (int)STRLEN(name);
  int result = 0;

  init_users();
  for (int i = 0; i < ga_users.ga_len; i++) {
    if (STRCMP(((char_u **)ga_users.ga_data)[i], name) == 0)
      return 2;       /* full match */
    if (STRNCMP(((char_u **)ga_users.ga_data)[i], name, n) == 0)
      result = 1;       /* partial match */
  }
  return result;
}

/// Preserve files and exit.
/// @note IObuff must contain a message.
/// @note This may be called from deadly_signal() in a signal handler, avoid
///       unsafe functions, such as allocating memory.
void preserve_exit(void)
  FUNC_ATTR_NORETURN
{
  // 'true' when we are sure to exit, e.g., after a deadly signal
  static bool really_exiting = false;

  // Prevent repeated calls into this method.
  if (really_exiting) {
    if (input_global_fd() >= 0) {
      // normalize stream (#2598)
      stream_set_blocking(input_global_fd(), true);
    }
    exit(2);
  }

  really_exiting = true;
  // Ignore SIGHUP while we are already exiting. #9274
  signal_reject_deadly();
  mch_errmsg(IObuff);
  mch_errmsg("\n");
  ui_flush();

  ml_close_notmod();                // close all not-modified buffers

  FOR_ALL_BUFFERS(buf) {
    if (buf->b_ml.ml_mfp != NULL && buf->b_ml.ml_mfp->mf_fname != NULL) {
      mch_errmsg((uint8_t *)"Vim: preserving files...\n");
      ui_flush();
      ml_sync_all(false, false, true);  // preserve all swap files
      break;
    }
  }

  ml_close_all(false);              // close all memfiles, without deleting

  mch_errmsg("Vim: Finished.\n");

  getout(1);
}

/*
 * Check for CTRL-C pressed, but only once in a while.
 * Should be used instead of os_breakcheck() for functions that check for
 * each line in the file.  Calling os_breakcheck() each time takes too much
 * time, because it can be a system call.
 */

#ifndef BREAKCHECK_SKIP
#  define BREAKCHECK_SKIP 1000
#endif

static int breakcheck_count = 0;

void line_breakcheck(void)
{
  if (++breakcheck_count >= BREAKCHECK_SKIP) {
    breakcheck_count = 0;
    os_breakcheck();
  }
}

/*
 * Like line_breakcheck() but check 10 times less often.
 */
void fast_breakcheck(void)
{
  if (++breakcheck_count >= BREAKCHECK_SKIP * 10) {
    breakcheck_count = 0;
    os_breakcheck();
  }
}

/// os_call_shell() wrapper. Handles 'verbose', :profile, and v:shell_error.
/// Invalidates cached tags.
///
/// @return shell command exit code
int call_shell(char_u *cmd, ShellOpts opts, char_u *extra_shell_arg)
{
  int retval;
  proftime_T wait_time;

  if (p_verbose > 3) {
    verbose_enter();
    smsg(_("Executing command: \"%s\""), cmd == NULL ? p_sh : cmd);
    msg_putchar('\n');
    verbose_leave();
  }

  if (do_profiling == PROF_YES) {
    prof_child_enter(&wait_time);
  }

  if (*p_sh == NUL) {
    EMSG(_(e_shellempty));
    retval = -1;
  } else {
    // The external command may update a tags file, clear cached tags.
    tag_freematch();

    retval = os_call_shell(cmd, opts, extra_shell_arg);
  }

  set_vim_var_nr(VV_SHELL_ERROR, (varnumber_T)retval);
  if (do_profiling == PROF_YES) {
    prof_child_exit(&wait_time);
  }

  return retval;
}

/// Get the stdout of an external command.
/// If "ret_len" is NULL replace NUL characters with NL. When "ret_len" is not
/// NULL store the length there.
///
/// @param  cmd      command to execute
/// @param  infile   optional input file name
/// @param  flags    can be kShellOptSilent or 0
/// @param  ret_len  length of the stdout
///
/// @return an allocated string, or NULL for error.
char_u *get_cmd_output(char_u *cmd, char_u *infile, ShellOpts flags,
                       size_t *ret_len)
{
  char_u *buffer = NULL;

  if (check_restricted() || check_secure())
    return NULL;

  // get a name for the temp file
  char_u *tempname = vim_tempname();
  if (tempname == NULL) {
    EMSG(_(e_notmp));
    return NULL;
  }

  // Add the redirection stuff
  char_u *command = make_filter_cmd(cmd, infile, tempname);

  /*
   * Call the shell to execute the command (errors are ignored).
   * Don't check timestamps here.
   */
  ++no_check_timestamps;
  call_shell(command, kShellOptDoOut | kShellOptExpand | flags, NULL);
  --no_check_timestamps;

  xfree(command);

  // read the names from the file into memory
  FILE *fd = os_fopen((char *)tempname, READBIN);

  if (fd == NULL) {
    EMSG2(_(e_notopen), tempname);
    goto done;
  }

  fseek(fd, 0L, SEEK_END);
  size_t len = (size_t)ftell(fd);  // get size of temp file
  fseek(fd, 0L, SEEK_SET);

  buffer = xmalloc(len + 1);
  size_t i = fread((char *)buffer, 1, len, fd);
  fclose(fd);
  os_remove((char *)tempname);
  if (i != len) {
    EMSG2(_(e_notread), tempname);
    XFREE_CLEAR(buffer);
  } else if (ret_len == NULL) {
    /* Change NUL into SOH, otherwise the string is truncated. */
    for (i = 0; i < len; ++i)
      if (buffer[i] == NUL)
        buffer[i] = 1;

    buffer[len] = NUL;          /* make sure the buffer is terminated */
  } else {
    *ret_len = len;
  }

done:
  xfree(tempname);
  return buffer;
}

/*
 * Free the list of files returned by expand_wildcards() or other expansion
 * functions.
 */
void FreeWild(int count, char_u **files)
{
  if (count <= 0 || files == NULL)
    return;
  while (count--)
    xfree(files[count]);
  xfree(files);
}

/*
 * Return TRUE when need to go to Insert mode because of 'insertmode'.
 * Don't do this when still processing a command or a mapping.
 * Don't do this when inside a ":normal" command.
 */
int goto_im(void)
{
  return p_im && stuff_empty() && typebuf_typed();
}
