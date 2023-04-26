// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <limits.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/ascii.h"
#include "nvim/assert.h"
#include "nvim/buffer.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/extmark.h"
#include "nvim/gettext.h"
#include "nvim/globals.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/optionstr.h"
#include "nvim/os/input.h"
#include "nvim/plines.h"
#include "nvim/pos.h"
#include "nvim/regexp.h"
#include "nvim/search.h"
#include "nvim/strings.h"
#include "nvim/textformat.h"
#include "nvim/types.h"
#include "nvim/undo.h"
#include "nvim/vim.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "indent.c.generated.h"
#endif

/// Set the integer values corresponding to the string setting of 'vartabstop'.
/// "array" will be set, caller must free it if needed.
///
/// @return  false for an error.
bool tabstop_set(char *var, long **array)
{
  long valcount = 1;
  int t;
  char *cp;

  if (var[0] == NUL || (var[0] == '0' && var[1] == NUL)) {
    *array = NULL;
    return true;
  }

  for (cp = var; *cp != NUL; cp++) {
    if (cp == var || cp[-1] == ',') {
      char *end;

      if (strtol(cp, &end, 10) <= 0) {
        if (cp != end) {
          emsg(_(e_positive));
        } else {
          semsg(_(e_invarg2), cp);
        }
        return false;
      }
    }

    if (ascii_isdigit(*cp)) {
      continue;
    }
    if (cp[0] == ',' && cp > var && cp[-1] != ',' && cp[1] != NUL) {
      valcount++;
      continue;
    }
    semsg(_(e_invarg2), var);
    return false;
  }

  *array = (long *)xmalloc((unsigned)(valcount + 1) * sizeof(long));
  (*array)[0] = valcount;

  t = 1;
  for (cp = var; *cp != NUL;) {
    int n = atoi(cp);

    // Catch negative values, overflow and ridiculous big values.
    if (n <= 0 || n > TABSTOP_MAX) {
      semsg(_(e_invarg2), cp);
      XFREE_CLEAR(*array);
      return false;
    }
    (*array)[t++] = n;
    while (*cp != NUL && *cp != ',') {
      cp++;
    }
    if (*cp != NUL) {
      cp++;
    }
  }

  return true;
}

/// Calculate the number of screen spaces a tab will occupy.
/// If "vts" is set then the tab widths are taken from that array,
/// otherwise the value of ts is used.
int tabstop_padding(colnr_T col, long ts_arg, const long *vts)
{
  long ts = ts_arg == 0 ? 8 : ts_arg;
  colnr_T tabcol = 0;
  int t;
  long padding = 0;

  if (vts == NULL || vts[0] == 0) {
    return (int)(ts - (col % ts));
  }

  const long tabcount = vts[0];

  for (t = 1; t <= tabcount; t++) {
    tabcol += (colnr_T)vts[t];
    if (tabcol > col) {
      padding = tabcol - col;
      break;
    }
  }
  if (t > tabcount) {
    padding = vts[tabcount] - ((col - tabcol) % vts[tabcount]);
  }

  return (int)padding;
}

/// Find the size of the tab that covers a particular column.
int tabstop_at(colnr_T col, long ts, const long *vts)
{
  colnr_T tabcol = 0;
  int t;
  long tab_size = 0;

  if (vts == NULL || vts[0] == 0) {
    return (int)ts;
  }

  const long tabcount = vts[0];
  for (t = 1; t <= tabcount; t++) {
    tabcol += (colnr_T)vts[t];
    if (tabcol > col) {
      tab_size = vts[t];
      break;
    }
  }
  if (t > tabcount) {
    tab_size = vts[tabcount];
  }

  return (int)tab_size;
}

/// Find the column on which a tab starts.
colnr_T tabstop_start(colnr_T col, long ts, long *vts)
{
  colnr_T tabcol = 0;
  int t;

  if (vts == NULL || vts[0] == 0) {
    return (int)((col / ts) * ts);
  }

  const long tabcount = vts[0];
  for (t = 1; t <= tabcount; t++) {
    tabcol += (colnr_T)vts[t];
    if (tabcol > col) {
      return (int)(tabcol - vts[t]);
    }
  }

  const int excess = (int)(tabcol % vts[tabcount]);
  return (int)(excess + ((col - excess) / vts[tabcount]) * vts[tabcount]);
}

/// Find the number of tabs and spaces necessary to get from one column
/// to another.
void tabstop_fromto(colnr_T start_col, colnr_T end_col, long ts_arg, const long *vts, int *ntabs,
                    int *nspcs)
{
  int spaces = end_col - start_col;
  colnr_T tabcol = 0;
  long padding = 0;
  int t;
  long ts = ts_arg == 0 ? curbuf->b_p_ts : ts_arg;
  assert(ts != 0);  // suppress clang "Division by zero"

  if (vts == NULL || vts[0] == 0) {
    int tabs = 0;

    const int initspc = (int)(ts - (start_col % ts));
    if (spaces >= initspc) {
      spaces -= initspc;
      tabs++;
    }
    tabs += (int)(spaces / ts);
    spaces -= (int)((spaces / ts) * ts);

    *ntabs = tabs;
    *nspcs = spaces;
    return;
  }

  // Find the padding needed to reach the next tabstop.
  const long tabcount = vts[0];
  for (t = 1; t <= tabcount; t++) {
    tabcol += (colnr_T)vts[t];
    if (tabcol > start_col) {
      padding = tabcol - start_col;
      break;
    }
  }
  if (t > tabcount) {
    padding = vts[tabcount] - ((start_col - tabcol) % vts[tabcount]);
  }

  // If the space needed is less than the padding no tabs can be used.
  if (spaces < padding) {
    *ntabs = 0;
    *nspcs = spaces;
    return;
  }

  *ntabs = 1;
  spaces -= (int)padding;

  // At least one tab has been used. See if any more will fit.
  while (spaces != 0 && ++t <= tabcount) {
    padding = vts[t];
    if (spaces < padding) {
      *nspcs = spaces;
      return;
    }
    *ntabs += 1;
    spaces -= (int)padding;
  }

  *ntabs += spaces / (int)vts[tabcount];
  *nspcs = spaces % (int)vts[tabcount];
}

/// See if two tabstop arrays contain the same values.
bool tabstop_eq(const long *ts1, const long *ts2)
{
  int t;

  if ((ts1 == 0 && ts2) || (ts1 && ts2 == 0)) {
    return false;
  }
  if (ts1 == ts2) {
    return true;
  }
  if (ts1[0] != ts2[0]) {
    return false;
  }

  for (t = 1; t <= ts1[0]; t++) {
    if (ts1[t] != ts2[t]) {
      return false;
    }
  }

  return true;
}

/// Copy a tabstop array, allocating space for the new array.
int *tabstop_copy(const long *oldts)
{
  long *newts;
  int t;

  if (oldts == 0) {
    return 0;
  }

  newts = xmalloc((unsigned)(oldts[0] + 1) * sizeof(long));
  for (t = 0; t <= oldts[0]; t++) {
    newts[t] = oldts[t];
  }

  return (int *)newts;
}

/// Return a count of the number of tabstops.
int tabstop_count(long *ts)
{
  return ts != NULL ? (int)ts[0] : 0;
}

/// Return the first tabstop, or 8 if there are no tabstops defined.
int tabstop_first(long *ts)
{
  return ts != NULL ? (int)ts[1] : 8;
}

/// Return the effective shiftwidth value for current buffer, using the
/// 'tabstop' value when 'shiftwidth' is zero.
int get_sw_value(buf_T *buf)
{
  long result = get_sw_value_col(buf, 0);
  assert(result >= 0 && result <= INT_MAX);
  return (int)result;
}

/// Idem, using "pos".
long get_sw_value_pos(buf_T *buf, pos_T *pos)
{
  pos_T save_cursor = curwin->w_cursor;
  long sw_value;

  curwin->w_cursor = *pos;
  sw_value = get_sw_value_col(buf, get_nolist_virtcol());
  curwin->w_cursor = save_cursor;
  return sw_value;
}

/// Idem, using the first non-black in the current line.
long get_sw_value_indent(buf_T *buf)
{
  pos_T pos = curwin->w_cursor;

  pos.col = (colnr_T)getwhitecols_curline();
  return get_sw_value_pos(buf, &pos);
}

/// Idem, using virtual column "col".
long get_sw_value_col(buf_T *buf, colnr_T col)
{
  return buf->b_p_sw ? buf->b_p_sw
                     : tabstop_at(col, buf->b_p_ts, buf->b_p_vts_array);
}

/// Return the effective softtabstop value for the current buffer,
/// using the shiftwidth  value when 'softtabstop' is negative.
int get_sts_value(void)
{
  long result = curbuf->b_p_sts < 0 ? get_sw_value(curbuf) : curbuf->b_p_sts;
  assert(result >= 0 && result <= INT_MAX);
  return (int)result;
}

// Count the size (in window cells) of the indent in the current line.
int get_indent(void)
{
  return get_indent_str_vtab(get_cursor_line_ptr(),
                             curbuf->b_p_ts,
                             curbuf->b_p_vts_array,
                             false);
}

// Count the size (in window cells) of the indent in line "lnum".
int get_indent_lnum(linenr_T lnum)
{
  return get_indent_str_vtab(ml_get(lnum),
                             curbuf->b_p_ts,
                             curbuf->b_p_vts_array,
                             false);
}

// Count the size (in window cells) of the indent in line "lnum" of buffer
// "buf".
int get_indent_buf(buf_T *buf, linenr_T lnum)
{
  return get_indent_str_vtab(ml_get_buf(buf, lnum, false),
                             buf->b_p_ts,
                             buf->b_p_vts_array,
                             false);
}

/// Count the size (in window cells) of the indent in line "ptr", with
/// 'tabstop' at "ts".
/// If @param list is true, count only screen size for tabs.
int get_indent_str(const char *ptr, int ts, bool list)
  FUNC_ATTR_NONNULL_ALL
{
  int count = 0;

  for (; *ptr; ptr++) {
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

/// Count the size (in window cells) of the indent in line "ptr", using
/// variable tabstops.
/// if "list" is true, count only screen size for tabs.
int get_indent_str_vtab(const char *ptr, long ts, long *vts, bool list)
{
  int count = 0;

  for (; *ptr; ptr++) {
    if (*ptr == TAB) {  // count a tab for what it is worth
      if (!list || curwin->w_p_lcs_chars.tab1) {
        count += tabstop_padding(count, ts, vts);
      } else {
        // In list mode, when tab is not set, count screen char width
        // for Tab, displays: ^I
        count += ptr2cells(ptr);
      }
    } else if (*ptr == ' ') {
      count++;  // count a space for one
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
//  SIN_NOMARK: don't move extmarks (because just after ml_append or something)
//  @param size measured in spaces
// Returns true if the line was changed.
int set_indent(int size, int flags)
{
  char *p;
  char *newline;
  char *oldline;
  char *s;
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
    int ind_col = 0;
    // If 'preserveindent' is set then reuse as much as possible of
    // the existing indent structure for the new indent.
    if (!(flags & SIN_INSERT) && curbuf->b_p_pi) {
      ind_done = 0;

      // Count as many characters as we can use.
      while (todo > 0 && ascii_iswhite(*p)) {
        if (*p == TAB) {
          tab_pad = tabstop_padding(ind_done,
                                    curbuf->b_p_ts,
                                    curbuf->b_p_vts_array);

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

      // These diverge from this point.
      ind_col = ind_done;
      // Set initial number of whitespace chars to copy if we are
      // preserving indent but expandtab is set.
      if (curbuf->b_p_et) {
        orig_char_len = ind_len;
      }
      // Fill to next tabstop with a tab, if possible.
      tab_pad = tabstop_padding(ind_done,
                                curbuf->b_p_ts,
                                curbuf->b_p_vts_array);
      if ((todo >= tab_pad) && (orig_char_len == -1)) {
        doit = true;
        todo -= tab_pad;
        ind_len++;

        // ind_done += tab_pad;
        ind_col += tab_pad;
      }
    }

    // Count tabs required for indent.
    while (true) {
      tab_pad = tabstop_padding(ind_col, curbuf->b_p_ts, curbuf->b_p_vts_array);
      if (todo < tab_pad) {
        break;
      }
      if (*p != TAB) {
        doit = true;
      } else {
        p++;
      }
      todo -= tab_pad;
      ind_len++;
      ind_col += tab_pad;
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
  line_len = (int)strlen(p) + 1;

  // If 'preserveindent' and 'expandtab' are both set keep the original
  // characters and allocate accordingly.  We will fill the rest with spaces
  // after the if (!curbuf->b_p_et) below.
  int skipcols = 0;  // number of columns (in bytes) that were presved
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
    skipcols = orig_char_len;

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
          tab_pad = tabstop_padding(ind_done,
                                    curbuf->b_p_ts,
                                    curbuf->b_p_vts_array);

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
        skipcols++;
      }

      // Fill to next tabstop with a tab, if possible.
      tab_pad = tabstop_padding(ind_done,
                                curbuf->b_p_ts,
                                curbuf->b_p_vts_array);

      if (todo >= tab_pad) {
        *s++ = TAB;
        todo -= tab_pad;
        ind_done += tab_pad;
      }
      p = skipwhite(p);
    }

    while (true) {
      tab_pad = tabstop_padding(ind_done,
                                curbuf->b_p_ts,
                                curbuf->b_p_vts_array);
      if (todo < tab_pad) {
        break;
      }
      *s++ = TAB;
      todo -= tab_pad;
      ind_done += tab_pad;
    }
  }

  while (todo > 0) {
    *s++ = ' ';
    todo--;
  }
  memmove(s, p, (size_t)line_len);

  // Replace the line (unless undo fails).
  if (!(flags & SIN_UNDO) || (u_savesub(curwin->w_cursor.lnum) == OK)) {
    const colnr_T old_offset = (colnr_T)(p - oldline);
    const colnr_T new_offset = (colnr_T)(s - newline);

    // this may free "newline"
    ml_replace(curwin->w_cursor.lnum, newline, false);
    if (!(flags & SIN_NOMARK)) {
      extmark_splice_cols(curbuf,
                          (int)curwin->w_cursor.lnum - 1,
                          skipcols,
                          old_offset - skipcols,
                          new_offset - skipcols,
                          kExtmarkUndo);
    }

    if (flags & SIN_CHANGED) {
      changed_bytes(curwin->w_cursor.lnum, 0);
    }

    // Correct saved cursor position if it is in this line.
    if (saved_cursor.lnum == curwin->w_cursor.lnum) {
      if (saved_cursor.col >= old_offset) {
        // Cursor was after the indent, adjust for the number of
        // bytes added/removed.
        saved_cursor.col += ind_len - old_offset;
      } else if (saved_cursor.col >= new_offset) {
        // Cursor was in the indent, and is now after it, put it back
        // at the start of the indent (replacing spaces with TAB).
        saved_cursor.col = new_offset;
      }
    }
    retval = true;
  } else {
    xfree(newline);
  }
  curwin->w_cursor.col = ind_len;
  return retval;
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
  if ((State & MODE_INSERT) || has_format_option(FO_Q_COMS)) {
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

/// This is called when 'breakindentopt' is changed and when a window is
/// initialized
bool briopt_check(win_T *wp)
{
  int bri_shift = 0;
  int bri_min = 20;
  bool bri_sbr = false;
  int bri_list = 0;
  int bri_vcol = 0;

  char *p = wp->w_p_briopt;
  while (*p != NUL) {
    if (strncmp(p, "shift:", 6) == 0
        && ((p[6] == '-' && ascii_isdigit(p[7])) || ascii_isdigit(p[6]))) {
      p += 6;
      bri_shift = getdigits_int(&p, true, 0);
    } else if (strncmp(p, "min:", 4) == 0 && ascii_isdigit(p[4])) {
      p += 4;
      bri_min = getdigits_int(&p, true, 0);
    } else if (strncmp(p, "sbr", 3) == 0) {
      p += 3;
      bri_sbr = true;
    } else if (strncmp(p, "list:", 5) == 0) {
      p += 5;
      bri_list = (int)getdigits(&p, false, 0);
    } else if (strncmp(p, "column:", 7) == 0) {
      p += 7;
      bri_vcol = (int)getdigits(&p, false, 0);
    }
    if (*p != ',' && *p != NUL) {
      return false;
    }
    if (*p == ',') {
      p++;
    }
  }

  wp->w_briopt_shift = bri_shift;
  wp->w_briopt_min = bri_min;
  wp->w_briopt_sbr = bri_sbr;
  wp->w_briopt_list = bri_list;
  wp->w_briopt_vcol = bri_vcol;

  return true;
}

// Return appropriate space number for breakindent, taking influencing
// parameters into account. Window must be specified, since it is not
// necessarily always the current one.
int get_breakindent_win(win_T *wp, char *line)
  FUNC_ATTR_NONNULL_ALL
{
  static int prev_indent = 0;  // cached indent value
  static long prev_ts = 0L;  // cached tabstop value
  static int prev_fnum = 0;  // cached buffer number
  static char *prev_line = NULL;  // cached copy of "line"
  static varnumber_T prev_tick = 0;  // changedtick of cached value
  static long *prev_vts = NULL;  // cached vartabs values
  static int prev_list = 0;  // cached list value
  static int prev_listopt = 0;  // cached w_p_briopt_list value
  static char *prev_flp = NULL;  // cached formatlistpat value
  int bri = 0;
  // window width minus window margin space, i.e. what rests for text
  const int eff_wwidth = wp->w_width_inner -
                         ((wp->w_p_nu || wp->w_p_rnu)
                          && (vim_strchr(p_cpo, CPO_NUMCOL) == NULL) ? number_width(wp) + 1 : 0);

  // used cached indent, unless
  // - buffer changed
  // - 'tabstop' changed
  // - buffer was changed
  // - 'briopt_list changed' changed or
  // - 'formatlistpattern' changed
  // - line changed
  // - 'vartabs' changed
  if (prev_fnum != wp->w_buffer->b_fnum
      || prev_ts != wp->w_buffer->b_p_ts
      || prev_tick != buf_get_changedtick(wp->w_buffer)
      || prev_listopt != wp->w_briopt_list
      || prev_flp == NULL
      || strcmp(prev_flp, get_flp_value(wp->w_buffer)) != 0
      || prev_line == NULL || strcmp(prev_line, line) != 0
      || prev_vts != wp->w_buffer->b_p_vts_array) {
    prev_fnum = wp->w_buffer->b_fnum;
    xfree(prev_line);
    prev_line = xstrdup(line);
    prev_ts = wp->w_buffer->b_p_ts;
    prev_tick = buf_get_changedtick(wp->w_buffer);
    prev_vts = wp->w_buffer->b_p_vts_array;
    if (wp->w_briopt_vcol == 0) {
      prev_indent = get_indent_str_vtab(line,
                                        wp->w_buffer->b_p_ts,
                                        wp->w_buffer->b_p_vts_array,
                                        wp->w_p_list);
    }
    prev_listopt = wp->w_briopt_list;
    prev_list = 0;
    xfree(prev_flp);
    prev_flp = xstrdup(get_flp_value(wp->w_buffer));
    // add additional indent for numbered lists
    if (wp->w_briopt_list != 0 && wp->w_briopt_vcol == 0) {
      regmatch_T regmatch = {
        .regprog = vim_regcomp(prev_flp, RE_MAGIC + RE_STRING + RE_AUTO + RE_STRICT),
      };
      if (regmatch.regprog != NULL) {
        regmatch.rm_ic = false;
        if (vim_regexec(&regmatch, line, 0)) {
          if (wp->w_briopt_list > 0) {
            prev_list += wp->w_briopt_list;
          } else {
            prev_indent = (int)(*regmatch.endp - *regmatch.startp);
          }
        }
        vim_regfree(regmatch.regprog);
      }
    }
  }
  if (wp->w_briopt_vcol != 0) {
    // column value has priority
    bri = wp->w_briopt_vcol;
    prev_list = 0;
  } else {
    bri = prev_indent + wp->w_briopt_shift;
  }

  // Add offset for number column, if 'n' is in 'cpoptions'
  bri += win_col_off2(wp);

  // add additional indent for numbered lists
  if (wp->w_briopt_list > 0) {
    bri += prev_list;
  }

  // indent minus the length of the showbreak string
  if (wp->w_briopt_sbr) {
    bri -= vim_strsize(get_showbreak_value(wp));
  }

  // never indent past left window margin
  if (bri < 0) {
    bri = 0;
  } else if (bri > eff_wwidth - wp->w_briopt_min) {
    // always leave at least bri_min characters on the left,
    // if text width is sufficient
    bri = (eff_wwidth - wp->w_briopt_min < 0)
      ? 0 : eff_wwidth - wp->w_briopt_min;
  }

  return bri;
}

// When extra == 0: Return true if the cursor is before or on the first
// non-blank in the line.
// When extra == 1: Return true if the cursor is before the first non-blank in
// the line.
int inindent(int extra)
{
  char *ptr;
  colnr_T col;

  for (col = 0, ptr = get_cursor_line_ptr(); ascii_iswhite(*ptr); col++) {
    ptr++;
  }

  if (col >= curwin->w_cursor.col + extra) {
    return true;
  }
  return false;
}

/// @return  true if the conditions are OK for smart indenting.
bool may_do_si(void)
{
  return curbuf->b_p_si && !curbuf->b_p_cin && *curbuf->b_p_inde == NUL && !p_paste;
}

/// Give a "resulting text too long" error and maybe set got_int.
static void emsg_text_too_long(void)
{
  emsg(_(e_resulting_text_too_long));
  // when not inside a try/catch set got_int to break out of any loop
  if (trylevel == 0) {
    got_int = true;
  }
}

/// ":retab".
void ex_retab(exarg_T *eap)
{
  linenr_T lnum;
  bool got_tab = false;
  long num_spaces = 0;
  long num_tabs;
  long len;
  long start_col = 0;                   // For start of white-space string
  long start_vcol = 0;                  // For start of white-space string
  long old_len;
  char *new_line = (char *)1;  // init to non-NULL
  long *new_vts_array = NULL;
  char *new_ts_str;  // string value of tab argument

  int save_list;
  linenr_T first_line = 0;              // first changed line
  linenr_T last_line = 0;               // last changed line

  save_list = curwin->w_p_list;
  curwin->w_p_list = 0;             // don't want list mode here

  new_ts_str = eap->arg;
  if (!tabstop_set(eap->arg, &new_vts_array)) {
    return;
  }
  while (ascii_isdigit(*(eap->arg)) || *(eap->arg) == ',') {
    (eap->arg)++;
  }

  // This ensures that either new_vts_array and new_ts_str are freshly
  // allocated, or new_vts_array points to an existing array and new_ts_str
  // is null.
  if (new_vts_array == NULL) {
    new_vts_array = curbuf->b_p_vts_array;
    new_ts_str = NULL;
  } else {
    new_ts_str = xstrnsave(new_ts_str, (size_t)(eap->arg - new_ts_str));
  }
  for (lnum = eap->line1; !got_int && lnum <= eap->line2; lnum++) {
    char *ptr = ml_get(lnum);
    long col = 0;
    long vcol = 0;
    bool did_undo = false;  // called u_save for current line
    while (true) {
      if (ascii_iswhite(ptr[col])) {
        if (!got_tab && num_spaces == 0) {
          // First consecutive white-space
          start_vcol = vcol;
          start_col = col;
        }
        if (ptr[col] == ' ') {
          num_spaces++;
        } else {
          got_tab = true;
        }
      } else {
        if (got_tab || (eap->forceit && num_spaces > 1)) {
          // Retabulate this string of white-space

          // len is virtual length of white string
          len = num_spaces = vcol - start_vcol;
          num_tabs = 0;
          if (!curbuf->b_p_et) {
            int t, s;

            tabstop_fromto((colnr_T)start_vcol, (colnr_T)vcol,
                           curbuf->b_p_ts, new_vts_array, &t, &s);
            num_tabs = t;
            num_spaces = s;
          }
          if (curbuf->b_p_et || got_tab
              || (num_spaces + num_tabs < len)) {
            if (did_undo == false) {
              did_undo = true;
              if (u_save((linenr_T)(lnum - 1),
                         (linenr_T)(lnum + 1)) == FAIL) {
                new_line = NULL;  // flag out-of-memory
                break;
              }
            }

            // len is actual number of white characters used
            len = num_spaces + num_tabs;
            old_len = (long)strlen(ptr);
            const long new_len = old_len - col + start_col + len + 1;
            if (new_len <= 0 || new_len >= MAXCOL) {
              emsg_text_too_long();
              break;
            }
            new_line = xmalloc((size_t)new_len);

            if (start_col > 0) {
              memmove(new_line, ptr, (size_t)start_col);
            }
            memmove(new_line + start_col + len,
                    ptr + col, (size_t)(old_len - col + 1));
            ptr = new_line + start_col;
            for (col = 0; col < len; col++) {
              ptr[col] = (col < num_tabs) ? '\t' : ' ';
            }
            if (ml_replace(lnum, new_line, false) == OK) {
              // "new_line" may have been copied
              new_line = curbuf->b_ml.ml_line_ptr;
              extmark_splice_cols(curbuf, lnum - 1, 0, (colnr_T)old_len,
                                  (colnr_T)new_len - 1, kExtmarkUndo);
            }
            if (first_line == 0) {
              first_line = lnum;
            }
            last_line = lnum;
            ptr = new_line;
            col = start_col + len;
          }
        }
        got_tab = false;
        num_spaces = 0;
      }
      if (ptr[col] == NUL) {
        break;
      }
      vcol += win_chartabsize(curwin, ptr + col, (colnr_T)vcol);
      if (vcol >= MAXCOL) {
        emsg_text_too_long();
        break;
      }
      col += utfc_ptr2len(ptr + col);
    }
    if (new_line == NULL) {                 // out of memory
      break;
    }
    line_breakcheck();
  }
  if (got_int) {
    emsg(_(e_interr));
  }

  // If a single value was given then it can be considered equal to
  // either the value of 'tabstop' or the value of 'vartabstop'.
  if (tabstop_count(curbuf->b_p_vts_array) == 0
      && tabstop_count(new_vts_array) == 1
      && curbuf->b_p_ts == tabstop_first(new_vts_array)) {
    // not changed
  } else if (tabstop_count(curbuf->b_p_vts_array) > 0
             && tabstop_eq(curbuf->b_p_vts_array, new_vts_array)) {
    // not changed
  } else {
    redraw_curbuf_later(UPD_NOT_VALID);
  }
  if (first_line != 0) {
    changed_lines(first_line, 0, last_line + 1, 0L, true);
  }

  curwin->w_p_list = save_list;         // restore 'list'

  if (new_ts_str != NULL) {  // set the new tabstop
    // If 'vartabstop' is in use or if the value given to retab has more
    // than one tabstop then update 'vartabstop'.
    long *old_vts_ary = curbuf->b_p_vts_array;

    if (tabstop_count(old_vts_ary) > 0 || tabstop_count(new_vts_array) > 1) {
      set_string_option_direct("vts", -1, new_ts_str, OPT_FREE | OPT_LOCAL, 0);
      curbuf->b_p_vts_array = new_vts_array;
      xfree(old_vts_ary);
    } else {
      // 'vartabstop' wasn't in use and a single value was given to
      // retab then update 'tabstop'.
      curbuf->b_p_ts = tabstop_first(new_vts_array);
      xfree(new_vts_array);
    }
    xfree(new_ts_str);
  }
  coladvance(curwin->w_curswant);

  u_clearline();
}

/// Get indent level from 'indentexpr'.
int get_expr_indent(void)
{
  int indent = -1;
  pos_T save_pos;
  colnr_T save_curswant;
  int save_set_curswant;
  int save_State;
  int use_sandbox = was_set_insecurely(curwin, "indentexpr", OPT_LOCAL);
  const sctx_T save_sctx = current_sctx;

  // Save and restore cursor position and curswant, in case it was changed
  // * via :normal commands.
  save_pos = curwin->w_cursor;
  save_curswant = curwin->w_curswant;
  save_set_curswant = curwin->w_set_curswant;
  set_vim_var_nr(VV_LNUM, (varnumber_T)curwin->w_cursor.lnum);

  if (use_sandbox) {
    sandbox++;
  }
  textlock++;
  current_sctx = curbuf->b_p_script_ctx[BV_INDE].script_ctx;

  // Need to make a copy, the 'indentexpr' option could be changed while
  // evaluating it.
  char *inde_copy = xstrdup(curbuf->b_p_inde);
  indent = (int)eval_to_number(inde_copy);
  xfree(inde_copy);

  if (use_sandbox) {
    sandbox--;
  }
  textlock--;
  current_sctx = save_sctx;

  // Restore the cursor position so that 'indentexpr' doesn't need to.
  // Pretend to be in Insert mode, allow cursor past end of line for "o"
  // command.
  save_State = State;
  State = MODE_INSERT;
  curwin->w_cursor = save_pos;
  curwin->w_curswant = save_curswant;
  curwin->w_set_curswant = save_set_curswant;
  check_cursor();
  State = save_State;

  // Reset did_throw, unless 'debug' has "throw" and inside a try/catch.
  if (did_throw && (vim_strchr(p_debug, 't') == NULL || trylevel == 0)) {
    handle_did_throw();
    did_throw = false;
  }

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
  char *that;
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
    int parencount = 0;

    while (--curwin->w_cursor.lnum >= pos->lnum) {
      if (linewhite(curwin->w_cursor.lnum)) {
        continue;
      }

      for (that = get_cursor_line_ptr(); *that != NUL; that++) {
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
          if (*that == NUL) {
            break;
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
      colnr_T col = pos->col;

      that = get_cursor_line_ptr();

      if (vi_lisp && (get_indent() == 0)) {
        amount = 2;
      } else {
        char *line = that;
        chartabsize_T cts;
        init_chartabsize_arg(&cts, curwin, pos->lnum, 0, line, line);
        while (*cts.cts_ptr != NUL && col > 0) {
          cts.cts_vcol += lbr_chartabsize_adv(&cts);
          col--;
        }
        amount = cts.cts_vcol;
        that = cts.cts_ptr;
        clear_chartabsize_arg(&cts);

        // Some keywords require "body" indenting rules (the
        // non-standard-lisp ones are Scheme special forms):
        // (let ((a 1))    instead    (let ((a 1))
        //   (...))       of       (...))
        if (!vi_lisp && ((*that == '(') || (*that == '['))
            && lisp_match(that + 1)) {
          amount += 2;
        } else {
          if (*that != NUL) {
            that++;
            amount++;
          }
          colnr_T firsttry = amount;

          init_chartabsize_arg(&cts, curwin, (colnr_T)(that - line),
                               amount, line, that);
          while (ascii_iswhite(*cts.cts_ptr)) {
            cts.cts_vcol += lbr_chartabsize(&cts);
            cts.cts_ptr++;
          }
          that = cts.cts_ptr;
          amount = cts.cts_vcol;
          clear_chartabsize_arg(&cts);

          if (*that && (*that != ';')) {
            // Not a comment line.
            // Test *that != '(' to accommodate first let/do
            // argument if it is more than one line.
            if (!vi_lisp && (*that != '(') && (*that != '[')) {
              firsttry++;
            }

            parencount = 0;

            init_chartabsize_arg(&cts, curwin,
                                 (colnr_T)(that - line), amount, line, that);
            if (vi_lisp || ((*that != '"') && (*that != '\'')
                            && (*that != '#')
                            && (((uint8_t)(*that) < '0') || ((uint8_t)(*that) > '9')))) {
              int quotecount = 0;
              while (*cts.cts_ptr
                     && (!ascii_iswhite(*cts.cts_ptr) || quotecount || parencount)
                     && (!((*cts.cts_ptr == '(' || *cts.cts_ptr == '[')
                           && !quotecount && !parencount && vi_lisp))) {
                if (*cts.cts_ptr == '"') {
                  quotecount = !quotecount;
                }
                if (((*cts.cts_ptr == '(') || (*cts.cts_ptr == '[')) && !quotecount) {
                  parencount++;
                }
                if (((*cts.cts_ptr == ')') || (*cts.cts_ptr == ']')) && !quotecount) {
                  parencount--;
                }
                if ((*cts.cts_ptr == '\\') && (*(cts.cts_ptr + 1) != NUL)) {
                  cts.cts_vcol += lbr_chartabsize_adv(&cts);
                }

                cts.cts_vcol += lbr_chartabsize_adv(&cts);
              }
            }

            while (ascii_iswhite(*cts.cts_ptr)) {
              cts.cts_vcol += lbr_chartabsize(&cts);
              cts.cts_ptr++;
            }
            that = cts.cts_ptr;
            amount = cts.cts_vcol;
            clear_chartabsize_arg(&cts);

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

static int lisp_match(char *p)
{
  char buf[LSIZE];
  char *word = *curbuf->b_p_lw != NUL ? curbuf->b_p_lw : p_lispwords;

  while (*word != NUL) {
    (void)copy_option_part(&word, buf, LSIZE, ",");
    int len = (int)strlen(buf);

    if ((strncmp(buf, p, (size_t)len) == 0) && ascii_iswhite_or_nul(p[len])) {
      return true;
    }
  }
  return false;
}

/// Re-indent the current line, based on the current contents of it and the
/// surrounding lines. Fixing the cursor position seems really easy -- I'm very
/// confused what all the part that handles Control-T is doing that I'm not.
/// "get_the_indent" should be get_c_indent, get_expr_indent or get_lisp_indent.
void fixthisline(IndentGetter get_the_indent)
{
  int amount = get_the_indent();

  if (amount < 0) {
    return;
  }

  change_indent(INDENT_SET, amount, false, 0, true);
  if (linewhite(curwin->w_cursor.lnum)) {
    did_ai = true;  // delete the indent if the line stays empty
  }
}

/// Return true if 'indentexpr' should be used for Lisp indenting.
/// Caller may want to check 'autoindent'.
bool use_indentexpr_for_lisp(void)
{
  return curbuf->b_p_lisp
         && *curbuf->b_p_inde != NUL
         && strcmp(curbuf->b_p_lop, "expr:1") == 0;
}

/// Fix indent for 'lisp' and 'cindent'.
void fix_indent(void)
{
  if (p_paste) {
    return;  // no auto-indenting when 'paste' is set
  }
  if (curbuf->b_p_lisp && curbuf->b_p_ai) {
    if (use_indentexpr_for_lisp()) {
      do_c_expr_indent();
    } else {
      fixthisline(get_lisp_indent);
    }
  } else if (cindent_on()) {
    do_c_expr_indent();
  }
}
