// ops.c: implementation of various operators: op_shift, op_delete, op_tilde,
//        op_change, op_yank, do_put, do_join

#include <assert.h>
#include <ctype.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <uv.h>

#include "nvim/api/private/defs.h"
#include "nvim/ascii_defs.h"
#include "nvim/assert_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/buffer_updates.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_getln.h"
#include "nvim/extmark.h"
#include "nvim/fold.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/getchar_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/keycodes.h"
#include "nvim/macros_defs.h"
#include "nvim/mark.h"
#include "nvim/mark_defs.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memline.h"
#include "nvim/memline_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/os/input.h"
#include "nvim/os/time.h"
#include "nvim/plines.h"
#include "nvim/search.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/terminal.h"
#include "nvim/textformat.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/undo.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

static yankreg_T y_regs[NUM_REGISTERS] = { 0 };

static yankreg_T *y_previous = NULL;  // ptr to last written yankreg

// for behavior between start_batch_changes() and end_batch_changes())
static int batch_change_count = 0;           // inside a script
static bool clipboard_delay_update = false;  // delay clipboard update
static bool clipboard_needs_update = false;  // clipboard was updated
static bool clipboard_didwarn = false;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ops.c.generated.h"
#endif

static const char e_search_pattern_and_expression_register_may_not_contain_two_or_more_lines[]
  = N_("E883: Search pattern and expression register may not contain two or more lines");

// Flags for third item in "opchars".
#define OPF_LINES  1  // operator always works on lines
#define OPF_CHANGE 2  // operator changes text

/// The names of operators.
/// IMPORTANT: Index must correspond with defines in ops.h!!!
/// The third field indicates whether the operator always works on lines.
static char opchars[][3] = {
  { NUL, NUL, 0 },                       // OP_NOP
  { 'd', NUL, OPF_CHANGE },              // OP_DELETE
  { 'y', NUL, 0 },                       // OP_YANK
  { 'c', NUL, OPF_CHANGE },              // OP_CHANGE
  { '<', NUL, OPF_LINES | OPF_CHANGE },  // OP_LSHIFT
  { '>', NUL, OPF_LINES | OPF_CHANGE },  // OP_RSHIFT
  { '!', NUL, OPF_LINES | OPF_CHANGE },  // OP_FILTER
  { 'g', '~', OPF_CHANGE },              // OP_TILDE
  { '=', NUL, OPF_LINES | OPF_CHANGE },  // OP_INDENT
  { 'g', 'q', OPF_LINES | OPF_CHANGE },  // OP_FORMAT
  { ':', NUL, OPF_LINES },               // OP_COLON
  { 'g', 'U', OPF_CHANGE },              // OP_UPPER
  { 'g', 'u', OPF_CHANGE },              // OP_LOWER
  { 'J', NUL, OPF_LINES | OPF_CHANGE },  // DO_JOIN
  { 'g', 'J', OPF_LINES | OPF_CHANGE },  // DO_JOIN_NS
  { 'g', '?', OPF_CHANGE },              // OP_ROT13
  { 'r', NUL, OPF_CHANGE },              // OP_REPLACE
  { 'I', NUL, OPF_CHANGE },              // OP_INSERT
  { 'A', NUL, OPF_CHANGE },              // OP_APPEND
  { 'z', 'f', 0         },               // OP_FOLD
  { 'z', 'o', OPF_LINES },               // OP_FOLDOPEN
  { 'z', 'O', OPF_LINES },               // OP_FOLDOPENREC
  { 'z', 'c', OPF_LINES },               // OP_FOLDCLOSE
  { 'z', 'C', OPF_LINES },               // OP_FOLDCLOSEREC
  { 'z', 'd', OPF_LINES },               // OP_FOLDDEL
  { 'z', 'D', OPF_LINES },               // OP_FOLDDELREC
  { 'g', 'w', OPF_LINES | OPF_CHANGE },  // OP_FORMAT2
  { 'g', '@', OPF_CHANGE },              // OP_FUNCTION
  { Ctrl_A, NUL, OPF_CHANGE },           // OP_NR_ADD
  { Ctrl_X, NUL, OPF_CHANGE },           // OP_NR_SUB
};

yankreg_T *get_y_previous(void)
{
  return y_previous;
}

void set_y_previous(yankreg_T *yreg)
{
  y_previous = yreg;
}

/// Translate a command name into an operator type.
/// Must only be called with a valid operator name!
int get_op_type(int char1, int char2)
{
  int i;

  if (char1 == 'r') {
    // ignore second character
    return OP_REPLACE;
  }
  if (char1 == '~') {
    // when tilde is an operator
    return OP_TILDE;
  }
  if (char1 == 'g' && char2 == Ctrl_A) {
    // add
    return OP_NR_ADD;
  }
  if (char1 == 'g' && char2 == Ctrl_X) {
    // subtract
    return OP_NR_SUB;
  }
  if (char1 == 'z' && char2 == 'y') {  // OP_YANK
    return OP_YANK;
  }
  for (i = 0;; i++) {
    if (opchars[i][0] == char1 && opchars[i][1] == char2) {
      break;
    }
    if (i == (int)(ARRAY_SIZE(opchars) - 1)) {
      internal_error("get_op_type()");
      break;
    }
  }
  return i;
}

/// @return  true if operator "op" always works on whole lines.
int op_on_lines(int op)
{
  return opchars[op][2] & OPF_LINES;
}

/// @return  true if operator "op" changes text.
int op_is_change(int op)
{
  return opchars[op][2] & OPF_CHANGE;
}

/// Get first operator command character.
///
/// @return  'g' or 'z' if there is another command character.
int get_op_char(int optype)
{
  return opchars[optype][0];
}

/// Get second operator command character.
int get_extra_op_char(int optype)
{
  return opchars[optype][1];
}

/// handle a shift operation
void op_shift(oparg_T *oap, bool curs_top, int amount)
{
  int block_col = 0;

  if (u_save((linenr_T)(oap->start.lnum - 1),
             (linenr_T)(oap->end.lnum + 1)) == FAIL) {
    return;
  }

  if (oap->motion_type == kMTBlockWise) {
    block_col = curwin->w_cursor.col;
  }

  for (int i = oap->line_count - 1; i >= 0; i--) {
    int first_char = (uint8_t)(*get_cursor_line_ptr());
    if (first_char == NUL) {  // empty line
      curwin->w_cursor.col = 0;
    } else if (oap->motion_type == kMTBlockWise) {
      shift_block(oap, amount);
    } else if (first_char != '#' || !preprocs_left()) {
      // Move the line right if it doesn't start with '#', 'smartindent'
      // isn't set or 'cindent' isn't set or '#' isn't in 'cino'.
      shift_line(oap->op_type == OP_LSHIFT, p_sr, amount, false);
    }
    curwin->w_cursor.lnum++;
  }

  if (oap->motion_type == kMTBlockWise) {
    curwin->w_cursor.lnum = oap->start.lnum;
    curwin->w_cursor.col = block_col;
  } else if (curs_top) {  // put cursor on first line, for ">>"
    curwin->w_cursor.lnum = oap->start.lnum;
    beginline(BL_SOL | BL_FIX);       // shift_line() may have set cursor.col
  } else {
    curwin->w_cursor.lnum--;            // put cursor on last line, for ":>"
  }
  // The cursor line is not in a closed fold
  foldOpenCursor();

  if (oap->line_count > p_report) {
    char *op;
    if (oap->op_type == OP_RSHIFT) {
      op = ">";
    } else {
      op = "<";
    }

    char *msg_line_single = NGETTEXT("%" PRId64 " line %sed %d time",
                                     "%" PRId64 " line %sed %d times", amount);
    char *msg_line_plural = NGETTEXT("%" PRId64 " lines %sed %d time",
                                     "%" PRId64 " lines %sed %d times", amount);
    vim_snprintf(IObuff, IOSIZE,
                 NGETTEXT(msg_line_single, msg_line_plural, oap->line_count),
                 (int64_t)oap->line_count, op, amount);
    msg_attr_keep(IObuff, 0, true, false);
  }

  if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
    // Set "'[" and "']" marks.
    curbuf->b_op_start = oap->start;
    curbuf->b_op_end.lnum = oap->end.lnum;
    curbuf->b_op_end.col = ml_get_len(oap->end.lnum);
    if (curbuf->b_op_end.col > 0) {
      curbuf->b_op_end.col--;
    }
  }

  changed_lines(curbuf, oap->start.lnum, 0, oap->end.lnum + 1, 0, true);
}

/// Shift the current line one shiftwidth left (if left != 0) or right
/// leaves cursor on first blank in the line.
///
/// @param call_changed_bytes  call changed_bytes()
void shift_line(bool left, bool round, int amount, int call_changed_bytes)
{
  int sw_val = get_sw_value_indent(curbuf, left);
  if (sw_val == 0) {
    sw_val = 1;              // shouldn't happen, just in case
  }
  int count = get_indent();  // get current indent

  if (round) {  // round off indent
    int i = count / sw_val;  // number of 'shiftwidth' rounded down
    int j = count % sw_val;  // extra spaces
    if (j && left) {  // first remove extra spaces
      amount--;
    }
    if (left) {
      i -= amount;
      if (i < 0) {
        i = 0;
      }
    } else {
      i += amount;
    }
    count = i * sw_val;
  } else {  // original vi indent
    if (left) {
      count -= sw_val * amount;
      if (count < 0) {
        count = 0;
      }
    } else {
      count += sw_val * amount;
    }
  }

  // Set new indent
  if (State & VREPLACE_FLAG) {
    change_indent(INDENT_SET, count, false, NUL, call_changed_bytes);
  } else {
    set_indent(count, call_changed_bytes ? SIN_CHANGED : 0);
  }
}

/// Shift one line of the current block one shiftwidth right or left.
/// Leaves cursor on first character in block.
static void shift_block(oparg_T *oap, int amount)
{
  const bool left = (oap->op_type == OP_LSHIFT);
  const int oldstate = State;
  char *newp;
  const int oldcol = curwin->w_cursor.col;
  const int sw_val = get_sw_value_indent(curbuf, left);
  const int ts_val = (int)curbuf->b_p_ts;
  struct block_def bd;
  int incr;
  const int old_p_ri = p_ri;

  p_ri = 0;                     // don't want revins in indent

  State = MODE_INSERT;          // don't want MODE_REPLACE for State
  block_prep(oap, &bd, curwin->w_cursor.lnum, true);
  if (bd.is_short) {
    return;
  }

  // total is number of screen columns to be inserted/removed
  int total = (int)((unsigned)amount * (unsigned)sw_val);
  if ((total / sw_val) != amount) {
    return;   // multiplication overflow
  }

  char *const oldp = get_cursor_line_ptr();
  const int old_line_len = get_cursor_line_len();

  int startcol, oldlen, newlen;

  if (!left) {
    //  1. Get start vcol
    //  2. Total ws vcols
    //  3. Divvy into TABs & spp
    //  4. Construct new string
    total += bd.pre_whitesp;    // all virtual WS up to & incl a split TAB
    colnr_T ws_vcol = bd.start_vcol - bd.pre_whitesp;
    char *old_textstart = bd.textstart;
    if (bd.startspaces) {
      if (utfc_ptr2len(bd.textstart) == 1) {
        bd.textstart++;
      } else {
        ws_vcol = 0;
        bd.startspaces = 0;
      }
    }

    // TODO(vim): is passing bd.textstart for start of the line OK?
    CharsizeArg csarg;
    CSType cstype = init_charsize_arg(&csarg, curwin, curwin->w_cursor.lnum, bd.textstart);
    StrCharInfo ci = utf_ptr2StrCharInfo(bd.textstart);
    int vcol = bd.start_vcol;
    while (ascii_iswhite(ci.chr.value)) {
      incr = win_charsize(cstype, vcol, ci.ptr, ci.chr.value, &csarg).width;
      ci = utfc_next(ci);
      total += incr;
      vcol += incr;
    }
    bd.textstart = ci.ptr;
    bd.start_vcol = vcol;

    int tabs = 0;
    int spaces = 0;
    // OK, now total=all the VWS reqd, and textstart points at the 1st
    // non-ws char in the block.
    if (!curbuf->b_p_et) {
      tabstop_fromto(ws_vcol, ws_vcol + total,
                     ts_val, curbuf->b_p_vts_array, &tabs, &spaces);
    } else {
      spaces = total;
    }

    // if we're splitting a TAB, allow for it
    const int col_pre = bd.pre_whitesp_c - (bd.startspaces != 0);
    bd.textcol -= col_pre;

    const int new_line_len  // the length of the line after the block shift
      = bd.textcol + tabs + spaces + (old_line_len - (int)(bd.textstart - oldp));
    newp = xmalloc((size_t)new_line_len + 1);
    memmove(newp, oldp, (size_t)bd.textcol);
    startcol = bd.textcol;
    oldlen = (int)(bd.textstart - old_textstart) + col_pre;
    newlen = tabs + spaces;
    memset(newp + bd.textcol, TAB, (size_t)tabs);
    memset(newp + bd.textcol + tabs, ' ', (size_t)spaces);
    STRCPY(newp + bd.textcol + tabs + spaces, bd.textstart);
    assert(newlen - oldlen == new_line_len - old_line_len);
  } else {  // left
    char *verbatim_copy_end;      // end of the part of the line which is
                                  // copied verbatim
    colnr_T verbatim_copy_width;  // the (displayed) width of this part
                                  // of line
    char *non_white = bd.textstart;

    // Firstly, let's find the first non-whitespace character that is
    // displayed after the block's start column and the character's column
    // number. Also, let's calculate the width of all the whitespace
    // characters that are displayed in the block and precede the searched
    // non-whitespace character.

    // If "bd.startspaces" is set, "bd.textstart" points to the character,
    // the part of which is displayed at the block's beginning. Let's start
    // searching from the next character.
    if (bd.startspaces) {
      MB_PTR_ADV(non_white);
    }

    // The character's column is in "bd.start_vcol".
    colnr_T non_white_col = bd.start_vcol;

    CharsizeArg csarg;
    CSType cstype = init_charsize_arg(&csarg, curwin, curwin->w_cursor.lnum, bd.textstart);
    while (ascii_iswhite(*non_white)) {
      incr = win_charsize(cstype, non_white_col, non_white, (uint8_t)(*non_white), &csarg).width;
      non_white_col += incr;
      non_white++;
    }

    const colnr_T block_space_width = non_white_col - oap->start_vcol;
    // We will shift by "total" or "block_space_width", whichever is less.
    const colnr_T shift_amount = block_space_width < total
                                 ? block_space_width
                                 : total;
    // The column to which we will shift the text.
    const colnr_T destination_col = non_white_col - shift_amount;

    // Now let's find out how much of the beginning of the line we can
    // reuse without modification.
    verbatim_copy_end = bd.textstart;
    verbatim_copy_width = bd.start_vcol;

    // If "bd.startspaces" is set, "bd.textstart" points to the character
    // preceding the block. We have to subtract its width to obtain its
    // column number.
    if (bd.startspaces) {
      verbatim_copy_width -= bd.start_char_vcols;
    }
    cstype = init_charsize_arg(&csarg, curwin, 0, bd.textstart);
    StrCharInfo ci = utf_ptr2StrCharInfo(verbatim_copy_end);
    while (verbatim_copy_width < destination_col) {
      incr = win_charsize(cstype, verbatim_copy_width, ci.ptr, ci.chr.value, &csarg).width;
      if (verbatim_copy_width + incr > destination_col) {
        break;
      }
      verbatim_copy_width += incr;
      ci = utfc_next(ci);
    }
    verbatim_copy_end = ci.ptr;

    // If "destination_col" is different from the width of the initial
    // part of the line that will be copied, it means we encountered a tab
    // character, which we will have to partly replace with spaces.
    assert(destination_col - verbatim_copy_width >= 0);
    const int fill  // nr of spaces that replace a TAB
      = destination_col - verbatim_copy_width;

    assert(verbatim_copy_end - oldp >= 0);
    // length of string left of the shift position (ie the string not being shifted)
    const int fixedlen = (int)(verbatim_copy_end - oldp);
    // The replacement line will consist of:
    // - the beginning of the original line up to "verbatim_copy_end",
    // - "fill" number of spaces,
    // - the rest of the line, pointed to by non_white.
    const int new_line_len  // the length of the line after the block shift
      = fixedlen + fill + (old_line_len - (int)(non_white - oldp));

    newp = xmalloc((size_t)new_line_len + 1);
    startcol = fixedlen;
    oldlen = bd.textcol + (int)(non_white - bd.textstart) - fixedlen;
    newlen = fill;
    memmove(newp, oldp, (size_t)fixedlen);
    memset(newp + fixedlen, ' ', (size_t)fill);
    STRCPY(newp + fixedlen + fill, non_white);
    assert(newlen - oldlen == new_line_len - old_line_len);
  }
  // replace the line
  ml_replace(curwin->w_cursor.lnum, newp, false);
  changed_bytes(curwin->w_cursor.lnum, bd.textcol);
  extmark_splice_cols(curbuf, (int)curwin->w_cursor.lnum - 1, startcol,
                      oldlen, newlen,
                      kExtmarkUndo);
  State = oldstate;
  curwin->w_cursor.col = oldcol;
  p_ri = old_p_ri;
}

/// Insert string "s" (b_insert ? before : after) block :AKelly
/// Caller must prepare for undo.
static void block_insert(oparg_T *oap, const char *s, size_t slen, bool b_insert,
                         struct block_def *bdp)
{
  int ts_val;
  int count = 0;                // extra spaces to replace a cut TAB
  int spaces = 0;               // non-zero if cutting a TAB
  colnr_T offset;               // pointer along new line
  char *newp, *oldp;            // new, old lines
  int oldstate = State;
  State = MODE_INSERT;          // don't want MODE_REPLACE for State

  for (linenr_T lnum = oap->start.lnum + 1; lnum <= oap->end.lnum; lnum++) {
    block_prep(oap, bdp, lnum, true);
    if (bdp->is_short && b_insert) {
      continue;  // OP_INSERT, line ends before block start
    }

    oldp = ml_get(lnum);

    if (b_insert) {
      ts_val = bdp->start_char_vcols;
      spaces = bdp->startspaces;
      if (spaces != 0) {
        count = ts_val - 1;         // we're cutting a TAB
      }
      offset = bdp->textcol;
    } else {  // append
      ts_val = bdp->end_char_vcols;
      if (!bdp->is_short) {     // spaces = padding after block
        spaces = (bdp->endspaces ? ts_val - bdp->endspaces : 0);
        if (spaces != 0) {
          count = ts_val - 1;           // we're cutting a TAB
        }
        offset = bdp->textcol + bdp->textlen - (spaces != 0);
      } else {  // spaces = padding to block edge
                // if $ used, just append to EOL (ie spaces==0)
        if (!bdp->is_MAX) {
          spaces = (oap->end_vcol - bdp->end_vcol) + 1;
        }
        count = spaces;
        offset = bdp->textcol + bdp->textlen;
      }
    }

    if (spaces > 0) {
      // avoid copying part of a multi-byte character
      offset -= utf_head_off(oldp, oldp + offset);
    }
    if (spaces < 0) {  // can happen when the cursor was moved
      spaces = 0;
    }

    assert(count >= 0);
    // Make sure the allocated size matches what is actually copied below.
    newp = xmalloc((size_t)ml_get_len(lnum) + (size_t)spaces + slen
                   + (spaces > 0 && !bdp->is_short ? (size_t)(ts_val - spaces) : 0)
                   + (size_t)count + 1);

    // copy up to shifted part
    memmove(newp, oldp, (size_t)offset);
    oldp += offset;
    int startcol = offset;

    // insert pre-padding
    memset(newp + offset, ' ', (size_t)spaces);

    // copy the new text
    memmove(newp + offset + spaces, s, slen);
    offset += (int)slen;

    int skipped = 0;
    if (spaces > 0 && !bdp->is_short) {
      if (*oldp == TAB) {
        // insert post-padding
        memset(newp + offset + spaces, ' ', (size_t)(ts_val - spaces));
        // We're splitting a TAB, don't copy it.
        oldp++;
        // We allowed for that TAB, remember this now
        count++;
        skipped = 1;
      } else {
        // Not a TAB, no extra spaces
        count = spaces;
      }
    }

    if (spaces > 0) {
      offset += count;
    }
    STRCPY(newp + offset, oldp);

    ml_replace(lnum, newp, false);
    extmark_splice_cols(curbuf, (int)lnum - 1, startcol,
                        skipped, offset - startcol, kExtmarkUndo);

    if (lnum == oap->end.lnum) {
      // Set "']" mark to the end of the block instead of the end of
      // the insert in the first line.
      curbuf->b_op_end.lnum = oap->end.lnum;
      curbuf->b_op_end.col = offset;
    }
  }   // for all lnum

  State = oldstate;

  changed_lines(curbuf, oap->start.lnum + 1, 0, oap->end.lnum + 1, 0, true);
}

/// Handle reindenting a block of lines.
void op_reindent(oparg_T *oap, Indenter how)
{
  int i = 0;
  linenr_T first_changed = 0;
  linenr_T last_changed = 0;
  linenr_T start_lnum = curwin->w_cursor.lnum;

  // Don't even try when 'modifiable' is off.
  if (!MODIFIABLE(curbuf)) {
    emsg(_(e_modifiable));
    return;
  }

  // Save for undo.  Do this once for all lines, much faster than doing this
  // for each line separately, especially when undoing.
  if (u_savecommon(curbuf, start_lnum - 1, start_lnum + oap->line_count,
                   start_lnum + oap->line_count, false) == OK) {
    int amount;
    for (i = oap->line_count - 1; i >= 0 && !got_int; i--) {
      // it's a slow thing to do, so give feedback so there's no worry
      // that the computer's just hung.

      if (i > 1
          && (i % 50 == 0 || i == oap->line_count - 1)
          && oap->line_count > p_report) {
        smsg(0, _("%" PRId64 " lines to indent... "), (int64_t)i);
      }

      // Be vi-compatible: For lisp indenting the first line is not
      // indented, unless there is only one line.
      if (i != oap->line_count - 1 || oap->line_count == 1
          || how != get_lisp_indent) {
        char *l = skipwhite(get_cursor_line_ptr());
        if (*l == NUL) {                      // empty or blank line
          amount = 0;
        } else {
          amount = how();                     // get the indent for this line
        }
        if (amount >= 0 && set_indent(amount, 0)) {
          // did change the indent, call changed_lines() later
          if (first_changed == 0) {
            first_changed = curwin->w_cursor.lnum;
          }
          last_changed = curwin->w_cursor.lnum;
        }
      }
      curwin->w_cursor.lnum++;
      curwin->w_cursor.col = 0;      // make sure it's valid
    }
  }

  // put cursor on first non-blank of indented line
  curwin->w_cursor.lnum = start_lnum;
  beginline(BL_SOL | BL_FIX);

  // Mark changed lines so that they will be redrawn.  When Visual
  // highlighting was present, need to continue until the last line.  When
  // there is no change still need to remove the Visual highlighting.
  if (last_changed != 0) {
    changed_lines(curbuf, first_changed, 0,
                  oap->is_VIsual ? start_lnum + oap->line_count
                                 : last_changed + 1, 0, true);
  } else if (oap->is_VIsual) {
    redraw_curbuf_later(UPD_INVERTED);
  }

  if (oap->line_count > p_report) {
    i = oap->line_count - (i + 1);
    smsg(0, NGETTEXT("%" PRId64 " line indented ", "%" PRId64 " lines indented ", i), (int64_t)i);
  }
  if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
    // set '[ and '] marks
    curbuf->b_op_start = oap->start;
    curbuf->b_op_end = oap->end;
  }
}

// Keep the last expression line here, for repeating.
static char *expr_line = NULL;

/// Get an expression for the "\"=expr1" or "CTRL-R =expr1"
///
/// @return  '=' when OK, NUL otherwise.
int get_expr_register(void)
{
  char *new_line = getcmdline('=', 0, 0, true);
  if (new_line == NULL) {
    return NUL;
  }
  if (*new_line == NUL) {  // use previous line
    xfree(new_line);
  } else {
    set_expr_line(new_line);
  }
  return '=';
}

/// Set the expression for the '=' register.
/// Argument must be an allocated string.
void set_expr_line(char *new_line)
{
  xfree(expr_line);
  expr_line = new_line;
}

/// Get the result of the '=' register expression.
///
/// @return  a pointer to allocated memory, or NULL for failure.
char *get_expr_line(void)
{
  static int nested = 0;

  if (expr_line == NULL) {
    return NULL;
  }

  // Make a copy of the expression, because evaluating it may cause it to be
  // changed.
  char *expr_copy = xstrdup(expr_line);

  // When we are invoked recursively limit the evaluation to 10 levels.
  // Then return the string as-is.
  if (nested >= 10) {
    return expr_copy;
  }

  nested++;
  char *rv = eval_to_string(expr_copy, true);
  nested--;
  xfree(expr_copy);
  return rv;
}

/// Get the '=' register expression itself, without evaluating it.
char *get_expr_line_src(void)
{
  if (expr_line == NULL) {
    return NULL;
  }
  return xstrdup(expr_line);
}

/// @return  whether `regname` is a valid name of a yank register.
///
/// @note: There is no check for 0 (default register), caller should do this.
/// The black hole register '_' is regarded as valid.
///
/// @param regname name of register
/// @param writing allow only writable registers
bool valid_yank_reg(int regname, bool writing)
{
  if ((regname > 0 && ASCII_ISALNUM(regname))
      || (!writing && vim_strchr("/.%:=", regname) != NULL)
      || regname == '#'
      || regname == '"'
      || regname == '-'
      || regname == '_'
      || regname == '*'
      || regname == '+') {
    return true;
  }
  return false;
}

/// @return yankreg_T to use, according to the value of `regname`.
/// Cannot handle the '_' (black hole) register.
/// Must only be called with a valid register name!
///
/// @param regname The name of the register used or 0 for the unnamed register
/// @param mode One of the following three flags:
///
/// `YREG_PASTE`:
/// Prepare for pasting the register `regname`. With no regname specified,
/// read from last written register, or from unnamed clipboard (depending on the
/// `clipboard=unnamed` option). Queries the clipboard provider if necessary.
///
/// `YREG_YANK`:
/// Preparare for yanking into `regname`. With no regname specified,
/// yank into `"0` register. Update `y_previous` for next unnamed paste.
///
/// `YREG_PUT`:
/// Obtain the location that would be read when pasting `regname`.
yankreg_T *get_yank_register(int regname, int mode)
{
  yankreg_T *reg;

  if ((mode == YREG_PASTE || mode == YREG_PUT)
      && get_clipboard(regname, &reg, false)) {
    // reg is set to clipboard contents.
    return reg;
  } else if (mode == YREG_PUT && (regname == '*' || regname == '+')) {
    // in case clipboard not available and we aren't actually pasting,
    // return an empty register
    static yankreg_T empty_reg = { .y_array = NULL };
    return &empty_reg;
  } else if (mode != YREG_YANK
             && (regname == 0 || regname == '"' || regname == '*' || regname == '+')
             && y_previous != NULL) {
    // in case clipboard not available, paste from previous used register
    return y_previous;
  }

  int i = op_reg_index(regname);
  // when not 0-9, a-z, A-Z or '-'/'+'/'*': use register 0
  if (i == -1) {
    i = 0;
  }
  reg = &y_regs[i];

  if (mode == YREG_YANK) {
    // remember the written register for unnamed paste
    y_previous = reg;
  }
  return reg;
}

static bool is_append_register(int regname)
{
  return ASCII_ISUPPER(regname);
}

/// @return  a copy of contents in register `name` for use in do_put. Should be
///          freed by caller.
yankreg_T *copy_register(int name)
  FUNC_ATTR_NONNULL_RET
{
  yankreg_T *reg = get_yank_register(name, YREG_PASTE);

  yankreg_T *copy = xmalloc(sizeof(yankreg_T));
  *copy = *reg;
  if (copy->y_size == 0) {
    copy->y_array = NULL;
  } else {
    copy->y_array = xcalloc(copy->y_size, sizeof(char *));
    for (size_t i = 0; i < copy->y_size; i++) {
      copy->y_array[i] = xstrdup(reg->y_array[i]);
    }
  }
  return copy;
}

/// Check if the current yank register has kMTLineWise register type
bool yank_register_mline(int regname)
{
  if (regname != 0 && !valid_yank_reg(regname, false)) {
    return false;
  }
  if (regname == '_') {  // black hole is always empty
    return false;
  }
  yankreg_T *reg = get_yank_register(regname, YREG_PASTE);
  return reg->y_type == kMTLineWise;
}

/// Start or stop recording into a yank register.
///
/// @return  FAIL for failure, OK otherwise.
int do_record(int c)
{
  static int regname;
  int retval;

  if (reg_recording == 0) {
    // start recording
    // registers 0-9, a-z and " are allowed
    if (c < 0 || (!ASCII_ISALNUM(c) && c != '"')) {
      retval = FAIL;
    } else {
      reg_recording = c;
      // TODO(bfredl): showmode based messaging is currently missing with cmdheight=0
      showmode();
      regname = c;
      retval = OK;

      apply_autocmds(EVENT_RECORDINGENTER, NULL, NULL, false, curbuf);
    }
  } else {  // stop recording
    save_v_event_T save_v_event;
    // Set the v:event dictionary with information about the recording.
    dict_T *dict = get_v_event(&save_v_event);

    // The recorded text contents.
    char *p = get_recorded();
    if (p != NULL) {
      // Remove escaping for K_SPECIAL in multi-byte chars.
      vim_unescape_ks(p);
      tv_dict_add_str(dict, S_LEN("regcontents"), p);
    }

    // Name of requested register, or empty string for unnamed operation.
    char buf[NUMBUFLEN + 2];
    buf[0] = (char)regname;
    buf[1] = NUL;
    tv_dict_add_str(dict, S_LEN("regname"), buf);
    tv_dict_set_keys_readonly(dict);

    // Get the recorded key hits.  K_SPECIAL will be escaped, this
    // needs to be removed again to put it in a register.  exec_reg then
    // adds the escaping back later.
    apply_autocmds(EVENT_RECORDINGLEAVE, NULL, NULL, false, curbuf);
    restore_v_event(dict, &save_v_event);
    reg_recorded = reg_recording;
    reg_recording = 0;
    if (p_ch == 0 || ui_has(kUIMessages)) {
      showmode();
    } else {
      msg("", 0);
    }
    if (p == NULL) {
      retval = FAIL;
    } else {
      // We don't want to change the default register here, so save and
      // restore the current register name.
      yankreg_T *old_y_previous = y_previous;

      retval = stuff_yank(regname, p);

      y_previous = old_y_previous;
    }
  }
  return retval;
}

static void set_yreg_additional_data(yankreg_T *reg, dict_T *additional_data)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (reg->additional_data == additional_data) {
    return;
  }
  tv_dict_unref(reg->additional_data);
  reg->additional_data = additional_data;
}

/// Stuff string "p" into yank register "regname" as a single line (append if
/// uppercase). "p" must have been allocated.
///
/// @return  FAIL for failure, OK otherwise
static int stuff_yank(int regname, char *p)
{
  // check for read-only register
  if (regname != 0 && !valid_yank_reg(regname, true)) {
    xfree(p);
    return FAIL;
  }
  if (regname == '_') {             // black hole: don't do anything
    xfree(p);
    return OK;
  }
  yankreg_T *reg = get_yank_register(regname, YREG_YANK);
  if (is_append_register(regname) && reg->y_array != NULL) {
    char **pp = &(reg->y_array[reg->y_size - 1]);
    const size_t ppl = strlen(*pp);
    const size_t pl = strlen(p);
    char *lp = xmalloc(ppl + pl + 1);
    memcpy(lp, *pp, ppl);
    memcpy(lp + ppl, p, pl);
    *(lp + ppl + pl) = NUL;
    xfree(p);
    xfree(*pp);
    *pp = lp;
  } else {
    free_register(reg);
    set_yreg_additional_data(reg, NULL);
    reg->y_array = xmalloc(sizeof(char *));
    reg->y_array[0] = p;
    reg->y_size = 1;
    reg->y_type = kMTCharWise;
  }
  reg->timestamp = os_time();
  return OK;
}

static int execreg_lastc = NUL;

/// When executing a register as a series of ex-commands, if the
/// line-continuation character is used for a line, then join it with one or
/// more previous lines. Note that lines are processed backwards starting from
/// the last line in the register.
///
/// @param lines list of lines in the register
/// @param idx   index of the line starting with \ or "\. Join this line with all the immediate
///              predecessor lines that start with a \ and the first line that doesn't start
///              with a \. Lines that start with a comment "\ character are ignored.
/// @returns the concatenated line. The index of the line that should be
///          processed next is returned in idx.
static char *execreg_line_continuation(char **lines, size_t *idx)
{
  size_t i = *idx;
  assert(i > 0);
  const size_t cmd_end = i;

  garray_T ga;
  ga_init(&ga, (int)sizeof(char), 400);

  // search backwards to find the first line of this command.
  // Any line not starting with \ or "\ is the start of the
  // command.
  while (--i > 0) {
    char *p = skipwhite(lines[i]);
    if (*p != '\\' && (p[0] != '"' || p[1] != '\\' || p[2] != ' ')) {
      break;
    }
  }
  const size_t cmd_start = i;

  // join all the lines
  ga_concat(&ga, lines[cmd_start]);
  for (size_t j = cmd_start + 1; j <= cmd_end; j++) {
    char *p = skipwhite(lines[j]);
    if (*p == '\\') {
      // Adjust the growsize to the current length to
      // speed up concatenating many lines.
      if (ga.ga_len > 400) {
        ga_set_growsize(&ga, MIN(ga.ga_len, 8000));
      }
      ga_concat(&ga, p + 1);
    }
  }
  ga_append(&ga, NUL);
  char *str = xstrdup(ga.ga_data);
  ga_clear(&ga);

  *idx = i;
  return str;
}

/// Execute a yank register: copy it into the stuff buffer
///
/// @param colon   insert ':' before each line
/// @param addcr   always add '\n' to end of line
/// @param silent  set "silent" flag in typeahead buffer
///
/// @return FAIL for failure, OK otherwise
int do_execreg(int regname, int colon, int addcr, int silent)
{
  int retval = OK;

  if (regname == '@') {                 // repeat previous one
    if (execreg_lastc == NUL) {
      emsg(_("E748: No previously used register"));
      return FAIL;
    }
    regname = execreg_lastc;
  }
  // check for valid regname
  if (regname == '%' || regname == '#' || !valid_yank_reg(regname, false)) {
    emsg_invreg(regname);
    return FAIL;
  }
  execreg_lastc = regname;

  if (regname == '_') {                 // black hole: don't stuff anything
    return OK;
  }

  if (regname == ':') {                 // use last command line
    if (last_cmdline == NULL) {
      emsg(_(e_nolastcmd));
      return FAIL;
    }
    // don't keep the cmdline containing @:
    XFREE_CLEAR(new_last_cmdline);
    // Escape all control characters with a CTRL-V
    char *p = vim_strsave_escaped_ext(last_cmdline,
                                      "\001\002\003\004\005\006\007"
                                      "\010\011\012\013\014\015\016\017"
                                      "\020\021\022\023\024\025\026\027"
                                      "\030\031\032\033\034\035\036\037",
                                      Ctrl_V, false);
    // When in Visual mode "'<,'>" will be prepended to the command.
    // Remove it when it's already there.
    if (VIsual_active && strncmp(p, "'<,'>", 5) == 0) {
      retval = put_in_typebuf(p + 5, true, true, silent);
    } else {
      retval = put_in_typebuf(p, true, true, silent);
    }
    xfree(p);
  } else if (regname == '=') {
    char *p = get_expr_line();
    if (p == NULL) {
      return FAIL;
    }
    retval = put_in_typebuf(p, true, colon, silent);
    xfree(p);
  } else if (regname == '.') {        // use last inserted text
    char *p = get_last_insert_save();
    if (p == NULL) {
      emsg(_(e_noinstext));
      return FAIL;
    }
    retval = put_in_typebuf(p, false, colon, silent);
    xfree(p);
  } else {
    yankreg_T *reg = get_yank_register(regname, YREG_PASTE);
    if (reg->y_array == NULL) {
      return FAIL;
    }

    // Disallow remapping for ":@r".
    int remap = colon ? REMAP_NONE : REMAP_YES;

    // Insert lines into typeahead buffer, from last one to first one.
    put_reedit_in_typebuf(silent);
    for (size_t i = reg->y_size; i-- > 0;) {  // from y_size - 1 to 0 included
      // insert NL between lines and after last line if type is kMTLineWise
      if (reg->y_type == kMTLineWise || i < reg->y_size - 1 || addcr) {
        if (ins_typebuf("\n", remap, 0, true, silent) == FAIL) {
          return FAIL;
        }
      }

      // Handle line-continuation for :@<register>
      char *str = reg->y_array[i];
      bool free_str = false;
      if (colon && i > 0) {
        char *p = skipwhite(str);
        if (*p == '\\' || (p[0] == '"' && p[1] == '\\' && p[2] == ' ')) {
          str = execreg_line_continuation(reg->y_array, &i);
          free_str = true;
        }
      }
      char *escaped = vim_strsave_escape_ks(str);
      if (free_str) {
        xfree(str);
      }
      retval = ins_typebuf(escaped, remap, 0, true, silent);
      xfree(escaped);
      if (retval == FAIL) {
        return FAIL;
      }
      if (colon
          && ins_typebuf(":", remap, 0, true, silent) == FAIL) {
        return FAIL;
      }
    }
    reg_executing = regname == 0 ? '"' : regname;  // disable the 'q' command
    pending_end_reg_executing = false;
  }
  return retval;
}

/// If "restart_edit" is not zero, put it in the typeahead buffer, so that it's
/// used only after other typeahead has been processed.
static void put_reedit_in_typebuf(int silent)
{
  uint8_t buf[3];

  if (restart_edit == NUL) {
    return;
  }

  if (restart_edit == 'V') {
    buf[0] = 'g';
    buf[1] = 'R';
    buf[2] = NUL;
  } else {
    buf[0] = (uint8_t)(restart_edit == 'I' ? 'i' : restart_edit);
    buf[1] = NUL;
  }
  if (ins_typebuf((char *)buf, REMAP_NONE, 0, true, silent) == OK) {
    restart_edit = NUL;
  }
}

/// Insert register contents "s" into the typeahead buffer, so that it will be
/// executed again.
///
/// @param esc    when true then it is to be taken literally: Escape K_SPECIAL
///               characters and no remapping.
/// @param colon  add ':' before the line
static int put_in_typebuf(char *s, bool esc, bool colon, int silent)
{
  int retval = OK;

  put_reedit_in_typebuf(silent);
  if (colon) {
    retval = ins_typebuf("\n", REMAP_NONE, 0, true, silent);
  }
  if (retval == OK) {
    char *p;

    if (esc) {
      p = vim_strsave_escape_ks(s);
    } else {
      p = s;
    }
    if (p == NULL) {
      retval = FAIL;
    } else {
      retval = ins_typebuf(p, esc ? REMAP_NONE : REMAP_YES, 0, true, silent);
    }
    if (esc) {
      xfree(p);
    }
  }
  if (colon && retval == OK) {
    retval = ins_typebuf(":", REMAP_NONE, 0, true, silent);
  }
  return retval;
}

/// Insert a yank register: copy it into the Read buffer.
/// Used by CTRL-R command and middle mouse button in insert mode.
///
/// @param literally_arg  insert literally, not as if typed
///
/// @return FAIL for failure, OK otherwise
int insert_reg(int regname, bool literally_arg)
{
  int retval = OK;
  bool allocated;
  const bool literally = literally_arg || is_literal_register(regname);

  // It is possible to get into an endless loop by having CTRL-R a in
  // register a and then, in insert mode, doing CTRL-R a.
  // If you hit CTRL-C, the loop will be broken here.
  os_breakcheck();
  if (got_int) {
    return FAIL;
  }

  // check for valid regname
  if (regname != NUL && !valid_yank_reg(regname, false)) {
    return FAIL;
  }

  char *arg;
  if (regname == '.') {  // Insert last inserted text.
    retval = stuff_inserted(NUL, 1, true);
  } else if (get_spec_reg(regname, &arg, &allocated, true)) {
    if (arg == NULL) {
      return FAIL;
    }
    stuffescaped(arg, literally);
    if (allocated) {
      xfree(arg);
    }
  } else {  // Name or number register.
    yankreg_T *reg = get_yank_register(regname, YREG_PASTE);
    if (reg->y_array == NULL) {
      retval = FAIL;
    } else {
      for (size_t i = 0; i < reg->y_size; i++) {
        if (regname == '-') {
          Direction dir = BACKWARD;
          if ((State & REPLACE_FLAG) != 0) {
            pos_T curpos;
            if (u_save_cursor() == FAIL) {
              return FAIL;
            }
            del_chars(mb_charlen(reg->y_array[0]), true);
            curpos = curwin->w_cursor;
            if (oneright() == FAIL) {
              // hit end of line, need to put forward (after the current position)
              dir = FORWARD;
            }
            curwin->w_cursor = curpos;
          }

          AppendCharToRedobuff(Ctrl_R);
          AppendCharToRedobuff(regname);
          do_put(regname, NULL, dir, 1, PUT_CURSEND);
        } else {
          stuffescaped(reg->y_array[i], literally);
        }
        // Insert a newline between lines and after last line if
        // y_type is kMTLineWise.
        if (reg->y_type == kMTLineWise || i < reg->y_size - 1) {
          stuffcharReadbuff('\n');
        }
      }
    }
  }

  return retval;
}

/// If "regname" is a special register, return true and store a pointer to its
/// value in "argp".
///
/// @param allocated  return: true when value was allocated
/// @param errmsg     give error message when failing
///
/// @return  true if "regname" is a special register,
bool get_spec_reg(int regname, char **argp, bool *allocated, bool errmsg)
{
  *argp = NULL;
  *allocated = false;
  switch (regname) {
  case '%':                     // file name
    if (errmsg) {
      check_fname();            // will give emsg if not set
    }
    *argp = curbuf->b_fname;
    return true;

  case '#':                       // alternate file name
    *argp = getaltfname(errmsg);  // may give emsg if not set
    return true;

  case '=':                     // result of expression
    *argp = get_expr_line();
    *allocated = true;
    return true;

  case ':':                     // last command line
    if (last_cmdline == NULL && errmsg) {
      emsg(_(e_nolastcmd));
    }
    *argp = last_cmdline;
    return true;

  case '/':                     // last search-pattern
    if (last_search_pat() == NULL && errmsg) {
      emsg(_(e_noprevre));
    }
    *argp = last_search_pat();
    return true;

  case '.':                     // last inserted text
    *argp = get_last_insert_save();
    *allocated = true;
    if (*argp == NULL && errmsg) {
      emsg(_(e_noinstext));
    }
    return true;

  case Ctrl_F:                  // Filename under cursor
  case Ctrl_P:                  // Path under cursor, expand via "path"
    if (!errmsg) {
      return false;
    }
    *argp = file_name_at_cursor(FNAME_MESS | FNAME_HYP | (regname == Ctrl_P ? FNAME_EXP : 0),
                                1, NULL);
    *allocated = true;
    return true;

  case Ctrl_W:                  // word under cursor
  case Ctrl_A:                  // WORD (mnemonic All) under cursor
    if (!errmsg) {
      return false;
    }
    size_t cnt = find_ident_under_cursor(argp, (regname == Ctrl_W
                                                ? (FIND_IDENT|FIND_STRING)
                                                : FIND_STRING));
    *argp = cnt ? xmemdupz(*argp, cnt) : NULL;
    *allocated = true;
    return true;

  case Ctrl_L:                  // Line under cursor
    if (!errmsg) {
      return false;
    }

    *argp = ml_get_buf(curwin->w_buffer, curwin->w_cursor.lnum);
    return true;

  case '_':                     // black hole: always empty
    *argp = "";
    return true;
  }

  return false;
}

/// Paste a yank register into the command line.
/// Only for non-special registers.
/// Used by CTRL-R in command-line mode.
/// insert_reg() can't be used here, because special characters from the
/// register contents will be interpreted as commands.
///
/// @param regname   Register name.
/// @param literally_arg Insert text literally instead of "as typed".
/// @param remcr     When true, don't add CR characters.
///
/// @returns FAIL for failure, OK otherwise
bool cmdline_paste_reg(int regname, bool literally_arg, bool remcr)
{
  const bool literally = literally_arg || is_literal_register(regname);

  yankreg_T *reg = get_yank_register(regname, YREG_PASTE);
  if (reg->y_array == NULL) {
    return FAIL;
  }

  for (size_t i = 0; i < reg->y_size; i++) {
    cmdline_paste_str(reg->y_array[i], literally);

    // Insert ^M between lines, unless `remcr` is true.
    if (i < reg->y_size - 1 && !remcr) {
      cmdline_paste_str("\r", literally);
    }

    // Check for CTRL-C, in case someone tries to paste a few thousand
    // lines and gets bored.
    os_breakcheck();
    if (got_int) {
      return FAIL;
    }
  }
  return OK;
}

/// Shift the delete registers: "9 is cleared, "8 becomes "9, etc.
static void shift_delete_registers(bool y_append)
{
  free_register(&y_regs[9]);  // free register "9
  for (int n = 9; n > 1; n--) {
    y_regs[n] = y_regs[n - 1];
  }
  if (!y_append) {
    y_previous = &y_regs[1];
  }
  y_regs[1].y_array = NULL;  // set register "1 to empty
}

/// Handle a delete operation.
///
/// @return  FAIL if undo failed, OK otherwise.
int op_delete(oparg_T *oap)
{
  linenr_T lnum;
  struct block_def bd = { 0 };
  linenr_T old_lcount = curbuf->b_ml.ml_line_count;

  if (curbuf->b_ml.ml_flags & ML_EMPTY) {  // nothing to do
    return OK;
  }

  // Nothing to delete, return here. Do prepare undo, for op_change().
  if (oap->empty) {
    return u_save_cursor();
  }

  if (!MODIFIABLE(curbuf)) {
    emsg(_(e_modifiable));
    return FAIL;
  }

  if (VIsual_select && oap->is_VIsual) {
    // Use the register given with CTRL_R, defaults to zero
    oap->regname = VIsual_select_reg;
  }

  mb_adjust_opend(oap);

  // Imitate the strange Vi behaviour: If the delete spans more than one
  // line and motion_type == kMTCharWise and the result is a blank line, make the
  // delete linewise.  Don't do this for the change command or Visual mode.
  if (oap->motion_type == kMTCharWise
      && !oap->is_VIsual
      && oap->line_count > 1
      && oap->motion_force == NUL
      && oap->op_type == OP_DELETE) {
    char *ptr = ml_get(oap->end.lnum) + oap->end.col;
    if (*ptr != NUL) {
      ptr += oap->inclusive;
    }
    ptr = skipwhite(ptr);
    if (*ptr == NUL && inindent(0)) {
      oap->motion_type = kMTLineWise;
    }
  }

  // Check for trying to delete (e.g. "D") in an empty line.
  // Note: For the change operator it is ok.
  if (oap->motion_type != kMTLineWise
      && oap->line_count == 1
      && oap->op_type == OP_DELETE
      && *ml_get(oap->start.lnum) == NUL) {
    // It's an error to operate on an empty region, when 'E' included in
    // 'cpoptions' (Vi compatible).
    if (virtual_op) {
      // Virtual editing: Nothing gets deleted, but we set the '[ and ']
      // marks as if it happened.
      goto setmarks;
    }
    if (vim_strchr(p_cpo, CPO_EMPTYREGION) != NULL) {
      beep_flush();
    }
    return OK;
  }

  // Do a yank of whatever we're about to delete.
  // If a yank register was specified, put the deleted text into that
  // register.  For the black hole register '_' don't yank anything.
  if (oap->regname != '_') {
    yankreg_T *reg = NULL;
    bool did_yank = false;
    if (oap->regname != 0) {
      // check for read-only register
      if (!valid_yank_reg(oap->regname, true)) {
        beep_flush();
        return OK;
      }
      reg = get_yank_register(oap->regname, YREG_YANK);  // yank into specif'd reg
      op_yank_reg(oap, false, reg, is_append_register(oap->regname));  // yank without message
      did_yank = true;
    }

    // Put deleted text into register 1 and shift number registers if the
    // delete contains a line break, or when using a specific operator (Vi
    // compatible)

    if (oap->motion_type == kMTLineWise || oap->line_count > 1 || oap->use_reg_one) {
      shift_delete_registers(is_append_register(oap->regname));
      reg = &y_regs[1];
      op_yank_reg(oap, false, reg, false);
      did_yank = true;
    }

    // Yank into small delete register when no named register specified
    // and the delete is within one line.
    if (oap->regname == 0 && oap->motion_type != kMTLineWise
        && oap->line_count == 1) {
      reg = get_yank_register('-', YREG_YANK);
      op_yank_reg(oap, false, reg, false);
      did_yank = true;
    }

    if (did_yank || oap->regname == 0) {
      if (reg == NULL) {
        abort();
      }
      set_clipboard(oap->regname, reg);
      do_autocmd_textyankpost(oap, reg);
    }
  }

  // block mode delete
  if (oap->motion_type == kMTBlockWise) {
    if (u_save((linenr_T)(oap->start.lnum - 1),
               (linenr_T)(oap->end.lnum + 1)) == FAIL) {
      return FAIL;
    }

    for (lnum = curwin->w_cursor.lnum; lnum <= oap->end.lnum; lnum++) {
      block_prep(oap, &bd, lnum, true);
      if (bd.textlen == 0) {            // nothing to delete
        continue;
      }

      // Adjust cursor position for tab replaced by spaces and 'lbr'.
      if (lnum == curwin->w_cursor.lnum) {
        curwin->w_cursor.col = bd.textcol + bd.startspaces;
        curwin->w_cursor.coladd = 0;
      }

      // "n" == number of chars deleted
      // If we delete a TAB, it may be replaced by several characters.
      // Thus the number of characters may increase!
      int n = bd.textlen - bd.startspaces - bd.endspaces;
      char *oldp = ml_get(lnum);
      char *newp = xmalloc((size_t)ml_get_len(lnum) - (size_t)n + 1);
      // copy up to deleted part
      memmove(newp, oldp, (size_t)bd.textcol);
      // insert spaces
      memset(newp + bd.textcol, ' ', (size_t)bd.startspaces +
             (size_t)bd.endspaces);
      // copy the part after the deleted part
      STRCPY(newp + bd.textcol + bd.startspaces + bd.endspaces,
             oldp + bd.textcol + bd.textlen);
      // replace the line
      ml_replace(lnum, newp, false);

      extmark_splice_cols(curbuf, (int)lnum - 1, bd.textcol,
                          bd.textlen, bd.startspaces + bd.endspaces,
                          kExtmarkUndo);
    }

    check_cursor_col(curwin);
    changed_lines(curbuf, curwin->w_cursor.lnum, curwin->w_cursor.col,
                  oap->end.lnum + 1, 0, true);
    oap->line_count = 0;  // no lines deleted
  } else if (oap->motion_type == kMTLineWise) {
    if (oap->op_type == OP_CHANGE) {
      // Delete the lines except the first one.  Temporarily move the
      // cursor to the next line.  Save the current line number, if the
      // last line is deleted it may be changed.

      if (oap->line_count > 1) {
        lnum = curwin->w_cursor.lnum;
        curwin->w_cursor.lnum++;
        del_lines(oap->line_count - 1, true);
        curwin->w_cursor.lnum = lnum;
      }
      if (u_save_cursor() == FAIL) {
        return FAIL;
      }
      if (curbuf->b_p_ai) {                 // don't delete indent
        beginline(BL_WHITE);                // cursor on first non-white
        did_ai = true;                      // delete the indent when ESC hit
        ai_col = curwin->w_cursor.col;
      } else {
        beginline(0);                       // cursor in column 0
      }
      truncate_line(false);         // delete the rest of the line,
                                    // leaving cursor past last char in line
      if (oap->line_count > 1) {
        u_clearline(curbuf);  // "U" command not possible after "2cc"
      }
    } else {
      del_lines(oap->line_count, true);
      beginline(BL_WHITE | BL_FIX);
      u_clearline(curbuf);  //  "U" command not possible after "dd"
    }
  } else {
    if (virtual_op) {
      // For virtualedit: break the tabs that are partly included.
      if (gchar_pos(&oap->start) == '\t') {
        int endcol = 0;
        if (u_save_cursor() == FAIL) {          // save first line for undo
          return FAIL;
        }
        if (oap->line_count == 1) {
          endcol = getviscol2(oap->end.col, oap->end.coladd);
        }
        coladvance_force(getviscol2(oap->start.col, oap->start.coladd));
        oap->start = curwin->w_cursor;
        if (oap->line_count == 1) {
          coladvance(curwin, endcol);
          oap->end.col = curwin->w_cursor.col;
          oap->end.coladd = curwin->w_cursor.coladd;
          curwin->w_cursor = oap->start;
        }
      }

      // Break a tab only when it's included in the area.
      if (gchar_pos(&oap->end) == '\t'
          && oap->end.coladd == 0
          && oap->inclusive) {
        // save last line for undo
        if (u_save((linenr_T)(oap->end.lnum - 1),
                   (linenr_T)(oap->end.lnum + 1)) == FAIL) {
          return FAIL;
        }
        curwin->w_cursor = oap->end;
        coladvance_force(getviscol2(oap->end.col, oap->end.coladd));
        oap->end = curwin->w_cursor;
        curwin->w_cursor = oap->start;
      }
      mb_adjust_opend(oap);
    }

    if (oap->line_count == 1) {         // delete characters within one line
      if (u_save_cursor() == FAIL) {            // save line for undo
        return FAIL;
      }

      // if 'cpoptions' contains '$', display '$' at end of change
      if (vim_strchr(p_cpo, CPO_DOLLAR) != NULL
          && oap->op_type == OP_CHANGE
          && oap->end.lnum == curwin->w_cursor.lnum
          && !oap->is_VIsual) {
        display_dollar(oap->end.col - !oap->inclusive);
      }

      int n = oap->end.col - oap->start.col + 1 - !oap->inclusive;

      if (virtual_op) {
        // fix up things for virtualedit-delete:
        // break the tabs which are going to get in our way
        int len = get_cursor_line_len();

        if (oap->end.coladd != 0
            && (int)oap->end.col >= len - 1
            && !(oap->start.coladd && (int)oap->end.col >= len - 1)) {
          n++;
        }
        // Delete at least one char (e.g, when on a control char).
        if (n == 0 && oap->start.coladd != oap->end.coladd) {
          n = 1;
        }

        // When deleted a char in the line, reset coladd.
        if (gchar_cursor() != NUL) {
          curwin->w_cursor.coladd = 0;
        }
      }

      del_bytes((colnr_T)n, !virtual_op,
                oap->op_type == OP_DELETE && !oap->is_VIsual);
    } else {
      // delete characters between lines
      pos_T curpos;

      // save deleted and changed lines for undo
      if (u_save(curwin->w_cursor.lnum - 1,
                 curwin->w_cursor.lnum + oap->line_count) == FAIL) {
        return FAIL;
      }

      curbuf_splice_pending++;
      pos_T startpos = curwin->w_cursor;  // start position for delete
      bcount_t deleted_bytes = get_region_bytecount(curbuf, startpos.lnum, oap->end.lnum,
                                                    startpos.col,
                                                    oap->end.col) + oap->inclusive;
      truncate_line(true);        // delete from cursor to end of line

      curpos = curwin->w_cursor;  // remember curwin->w_cursor
      curwin->w_cursor.lnum++;

      del_lines(oap->line_count - 2, false);

      // delete from start of line until op_end
      int n = (oap->end.col + 1 - !oap->inclusive);
      curwin->w_cursor.col = 0;
      del_bytes((colnr_T)n, !virtual_op,
                oap->op_type == OP_DELETE && !oap->is_VIsual);
      curwin->w_cursor = curpos;  // restore curwin->w_cursor
      do_join(2, false, false, false, false);
      curbuf_splice_pending--;
      extmark_splice(curbuf, (int)startpos.lnum - 1, startpos.col,
                     (int)oap->line_count - 1, n, deleted_bytes,
                     0, 0, 0, kExtmarkUndo);
    }
    if (oap->op_type == OP_DELETE) {
      auto_format(false, true);
    }
  }

  msgmore(curbuf->b_ml.ml_line_count - old_lcount);

setmarks:
  if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
    if (oap->motion_type == kMTBlockWise) {
      curbuf->b_op_end.lnum = oap->end.lnum;
      curbuf->b_op_end.col = oap->start.col;
    } else {
      curbuf->b_op_end = oap->start;
    }
    curbuf->b_op_start = oap->start;
  }

  return OK;
}

/// Adjust end of operating area for ending on a multi-byte character.
/// Used for deletion.
static void mb_adjust_opend(oparg_T *oap)
{
  if (!oap->inclusive) {
    return;
  }

  const char *line = ml_get(oap->end.lnum);
  const char *ptr = line + oap->end.col;
  if (*ptr != NUL) {
    ptr -= utf_head_off(line, ptr);
    ptr += utfc_ptr2len(ptr) - 1;
    oap->end.col = (colnr_T)(ptr - line);
  }
}

/// Put character 'c' at position 'lp'
static inline void pbyte(pos_T lp, int c)
{
  assert(c <= UCHAR_MAX);
  *(ml_get_buf_mut(curbuf, lp.lnum) + lp.col) = (char)c;
  if (!curbuf_splice_pending) {
    extmark_splice_cols(curbuf, (int)lp.lnum - 1, lp.col, 1, 1, kExtmarkUndo);
  }
}

/// Replace the character under the cursor with "c".
/// This takes care of multi-byte characters.
static void replace_character(int c)
{
  const int n = State;

  State = MODE_REPLACE;
  ins_char(c);
  State = n;
  // Backup to the replaced character.
  dec_cursor();
}

/// Replace a whole area with one character.
static int op_replace(oparg_T *oap, int c)
{
  int n;
  struct block_def bd;
  char *after_p = NULL;
  bool had_ctrl_v_cr = false;

  if ((curbuf->b_ml.ml_flags & ML_EMPTY) || oap->empty) {
    return OK;              // nothing to do
  }
  if (c == REPLACE_CR_NCHAR) {
    had_ctrl_v_cr = true;
    c = CAR;
  } else if (c == REPLACE_NL_NCHAR) {
    had_ctrl_v_cr = true;
    c = NL;
  }

  mb_adjust_opend(oap);

  if (u_save((linenr_T)(oap->start.lnum - 1),
             (linenr_T)(oap->end.lnum + 1)) == FAIL) {
    return FAIL;
  }

  // block mode replace
  if (oap->motion_type == kMTBlockWise) {
    bd.is_MAX = (curwin->w_curswant == MAXCOL);
    for (; curwin->w_cursor.lnum <= oap->end.lnum; curwin->w_cursor.lnum++) {
      curwin->w_cursor.col = 0;       // make sure cursor position is valid
      block_prep(oap, &bd, curwin->w_cursor.lnum, true);
      if (bd.textlen == 0 && (!virtual_op || bd.is_MAX)) {
        continue;                     // nothing to replace
      }

      // n == number of extra chars required
      // If we split a TAB, it may be replaced by several characters.
      // Thus the number of characters may increase!
      // If the range starts in virtual space, count the initial
      // coladd offset as part of "startspaces"
      if (virtual_op && bd.is_short && *bd.textstart == NUL) {
        pos_T vpos;

        vpos.lnum = curwin->w_cursor.lnum;
        getvpos(curwin, &vpos, oap->start_vcol);
        bd.startspaces += vpos.coladd;
        n = bd.startspaces;
      } else {
        // allow for pre spaces
        n = (bd.startspaces ? bd.start_char_vcols - 1 : 0);
      }

      // allow for post spp
      n += (bd.endspaces
            && !bd.is_oneChar
            && bd.end_char_vcols > 0) ? bd.end_char_vcols - 1 : 0;
      // Figure out how many characters to replace.
      int numc = oap->end_vcol - oap->start_vcol + 1;
      if (bd.is_short && (!virtual_op || bd.is_MAX)) {
        numc -= (oap->end_vcol - bd.end_vcol) + 1;
      }

      // A double-wide character can be replaced only up to half the
      // times.
      if (utf_char2cells(c) > 1) {
        if ((numc & 1) && !bd.is_short) {
          bd.endspaces++;
          n++;
        }
        numc = numc / 2;
      }

      // Compute bytes needed, move character count to num_chars.
      int num_chars = numc;
      numc *= utf_char2len(c);

      char *oldp = get_cursor_line_ptr();
      colnr_T oldlen = get_cursor_line_len();

      size_t newp_size = (size_t)bd.textcol + (size_t)bd.startspaces;
      if (had_ctrl_v_cr || (c != '\r' && c != '\n')) {
        newp_size += (size_t)numc;
        if (!bd.is_short) {
          newp_size += (size_t)(bd.endspaces + oldlen
                                - bd.textcol - bd.textlen);
        }
      }
      char *newp = xmallocz(newp_size);
      // copy up to deleted part
      memmove(newp, oldp, (size_t)bd.textcol);
      oldp += bd.textcol + bd.textlen;
      // insert pre-spaces
      memset(newp + bd.textcol, ' ', (size_t)bd.startspaces);
      // insert replacement chars CHECK FOR ALLOCATED SPACE
      // REPLACE_CR_NCHAR/REPLACE_NL_NCHAR is used for entering CR literally.
      size_t after_p_len = 0;
      int col = oldlen - bd.textcol - bd.textlen + 1;
      assert(col >= 0);
      int newrows = 0;
      int newcols = 0;
      if (had_ctrl_v_cr || (c != '\r' && c != '\n')) {
        // strlen(newp) at this point
        int newp_len = bd.textcol + bd.startspaces;
        while (--num_chars >= 0) {
          newp_len += utf_char2bytes(c, newp + newp_len);
        }
        if (!bd.is_short) {
          // insert post-spaces
          memset(newp + newp_len, ' ', (size_t)bd.endspaces);
          newp_len += bd.endspaces;
          // copy the part after the changed part
          memmove(newp + newp_len, oldp, (size_t)col);
        }
        newcols = newp_len - bd.textcol;
      } else {
        // Replacing with \r or \n means splitting the line.
        after_p_len = (size_t)col;
        after_p = xmalloc(after_p_len);
        memmove(after_p, oldp, after_p_len);
        newrows = 1;
      }
      // replace the line
      ml_replace(curwin->w_cursor.lnum, newp, false);
      curbuf_splice_pending++;
      linenr_T baselnum = curwin->w_cursor.lnum;
      if (after_p != NULL) {
        ml_append(curwin->w_cursor.lnum++, after_p, (int)after_p_len, false);
        appended_lines_mark(curwin->w_cursor.lnum, 1);
        oap->end.lnum++;
        xfree(after_p);
      }
      curbuf_splice_pending--;
      extmark_splice(curbuf, (int)baselnum - 1, bd.textcol,
                     0, bd.textlen, bd.textlen,
                     newrows, newcols, newrows + newcols, kExtmarkUndo);
    }
  } else {
    // Characterwise or linewise motion replace.
    if (oap->motion_type == kMTLineWise) {
      oap->start.col = 0;
      curwin->w_cursor.col = 0;
      oap->end.col = ml_get_len(oap->end.lnum);
      if (oap->end.col) {
        oap->end.col--;
      }
    } else if (!oap->inclusive) {
      dec(&(oap->end));
    }

    // TODO(bfredl): we could batch all the splicing
    // done on the same line, at least
    while (ltoreq(curwin->w_cursor, oap->end)) {
      bool done = false;

      n = gchar_cursor();
      if (n != NUL) {
        int new_byte_len = utf_char2len(c);
        int old_byte_len = utfc_ptr2len(get_cursor_pos_ptr());

        if (new_byte_len > 1 || old_byte_len > 1) {
          // This is slow, but it handles replacing a single-byte
          // with a multi-byte and the other way around.
          if (curwin->w_cursor.lnum == oap->end.lnum) {
            oap->end.col += new_byte_len - old_byte_len;
          }
          replace_character(c);
          done = true;
        } else {
          if (n == TAB) {
            int end_vcol = 0;

            if (curwin->w_cursor.lnum == oap->end.lnum) {
              // oap->end has to be recalculated when
              // the tab breaks
              end_vcol = getviscol2(oap->end.col,
                                    oap->end.coladd);
            }
            coladvance_force(getviscol());
            if (curwin->w_cursor.lnum == oap->end.lnum) {
              getvpos(curwin, &oap->end, end_vcol);
            }
          }
          // with "coladd" set may move to just after a TAB
          if (gchar_cursor() != NUL) {
            pbyte(curwin->w_cursor, c);
            done = true;
          }
        }
      }
      if (!done && virtual_op && curwin->w_cursor.lnum == oap->end.lnum) {
        int virtcols = oap->end.coladd;

        if (curwin->w_cursor.lnum == oap->start.lnum
            && oap->start.col == oap->end.col && oap->start.coladd) {
          virtcols -= oap->start.coladd;
        }

        // oap->end has been trimmed so it's effectively inclusive;
        // as a result an extra +1 must be counted so we don't
        // trample the NUL byte.
        coladvance_force(getviscol2(oap->end.col, oap->end.coladd) + 1);
        curwin->w_cursor.col -= (virtcols + 1);
        for (; virtcols >= 0; virtcols--) {
          if (utf_char2len(c) > 1) {
            replace_character(c);
          } else {
            pbyte(curwin->w_cursor, c);
          }
          if (inc(&curwin->w_cursor) == -1) {
            break;
          }
        }
      }

      // Advance to next character, stop at the end of the file.
      if (inc_cursor() == -1) {
        break;
      }
    }
  }

  curwin->w_cursor = oap->start;
  check_cursor(curwin);
  changed_lines(curbuf, oap->start.lnum, oap->start.col, oap->end.lnum + 1, 0, true);

  if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
    // Set "'[" and "']" marks.
    curbuf->b_op_start = oap->start;
    curbuf->b_op_end = oap->end;
  }

  return OK;
}

/// Handle the (non-standard vi) tilde operator.  Also for "gu", "gU" and "g?".
void op_tilde(oparg_T *oap)
{
  struct block_def bd;
  bool did_change = false;

  if (u_save((linenr_T)(oap->start.lnum - 1),
             (linenr_T)(oap->end.lnum + 1)) == FAIL) {
    return;
  }

  pos_T pos = oap->start;
  if (oap->motion_type == kMTBlockWise) {  // Visual block mode
    for (; pos.lnum <= oap->end.lnum; pos.lnum++) {
      block_prep(oap, &bd, pos.lnum, false);
      pos.col = bd.textcol;
      bool one_change = swapchars(oap->op_type, &pos, bd.textlen);
      did_change |= one_change;
    }
    if (did_change) {
      changed_lines(curbuf, oap->start.lnum, 0, oap->end.lnum + 1, 0, true);
    }
  } else {  // not block mode
    if (oap->motion_type == kMTLineWise) {
      oap->start.col = 0;
      pos.col = 0;
      oap->end.col = ml_get_len(oap->end.lnum);
      if (oap->end.col) {
        oap->end.col--;
      }
    } else if (!oap->inclusive) {
      dec(&(oap->end));
    }

    if (pos.lnum == oap->end.lnum) {
      did_change = swapchars(oap->op_type, &pos,
                             oap->end.col - pos.col + 1);
    } else {
      while (true) {
        did_change |= swapchars(oap->op_type, &pos,
                                pos.lnum == oap->end.lnum ? oap->end.col + 1
                                                          : ml_get_pos_len(&pos));
        if (ltoreq(oap->end, pos) || inc(&pos) == -1) {
          break;
        }
      }
    }
    if (did_change) {
      changed_lines(curbuf, oap->start.lnum, oap->start.col, oap->end.lnum + 1,
                    0, true);
    }
  }

  if (!did_change && oap->is_VIsual) {
    // No change: need to remove the Visual selection
    redraw_curbuf_later(UPD_INVERTED);
  }

  if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
    // Set '[ and '] marks.
    curbuf->b_op_start = oap->start;
    curbuf->b_op_end = oap->end;
  }

  if (oap->line_count > p_report) {
    smsg(0, NGETTEXT("%" PRId64 " line changed", "%" PRId64 " lines changed", oap->line_count),
         (int64_t)oap->line_count);
  }
}

/// Invoke swapchar() on "length" bytes at position "pos".
///
/// @param pos     is advanced to just after the changed characters.
/// @param length  is rounded up to include the whole last multi-byte character.
/// Also works correctly when the number of bytes changes.
///
/// @return  true if some character was changed.
static int swapchars(int op_type, pos_T *pos, int length)
  FUNC_ATTR_NONNULL_ALL
{
  int did_change = 0;

  for (int todo = length; todo > 0; todo--) {
    const int len = utfc_ptr2len(ml_get_pos(pos));

    // we're counting bytes, not characters
    if (len > 0) {
      todo -= len - 1;
    }
    did_change |= swapchar(op_type, pos);
    if (inc(pos) == -1) {      // at end of file
      break;
    }
  }
  return did_change;
}

/// @param op_type
///                 == OP_UPPER: make uppercase,
///                 == OP_LOWER: make lowercase,
///                 == OP_ROT13: do rot13 encoding,
///                 else swap case of character at 'pos'
///
/// @return  true when something actually changed.
bool swapchar(int op_type, pos_T *pos)
  FUNC_ATTR_NONNULL_ARG(2)
{
  const int c = gchar_pos(pos);

  // Only do rot13 encoding for ASCII characters.
  if (c >= 0x80 && op_type == OP_ROT13) {
    return false;
  }

  int nc = c;
  if (mb_islower(c)) {
    if (op_type == OP_ROT13) {
      nc = ROT13(c, 'a');
    } else if (op_type != OP_LOWER) {
      nc = mb_toupper(c);
    }
  } else if (mb_isupper(c)) {
    if (op_type == OP_ROT13) {
      nc = ROT13(c, 'A');
    } else if (op_type != OP_UPPER) {
      nc = mb_tolower(c);
    }
  }
  if (nc != c) {
    if (c >= 0x80 || nc >= 0x80) {
      pos_T sp = curwin->w_cursor;

      curwin->w_cursor = *pos;
      // don't use del_char(), it also removes composing chars
      del_bytes(utf_ptr2len(get_cursor_pos_ptr()), false, false);
      ins_char(nc);
      curwin->w_cursor = sp;
    } else {
      pbyte(*pos, nc);
    }
    return true;
  }
  return false;
}

/// Insert and append operators for Visual mode.
void op_insert(oparg_T *oap, int count1)
{
  int pre_textlen = 0;
  colnr_T ind_pre_col = 0;
  int ind_pre_vcol = 0;
  struct block_def bd;

  // edit() changes this - record it for OP_APPEND
  bd.is_MAX = (curwin->w_curswant == MAXCOL);

  // vis block is still marked. Get rid of it now.
  curwin->w_cursor.lnum = oap->start.lnum;
  redraw_curbuf_later(UPD_INVERTED);
  update_screen();

  if (oap->motion_type == kMTBlockWise) {
    // When 'virtualedit' is used, need to insert the extra spaces before
    // doing block_prep().  When only "block" is used, virtual edit is
    // already disabled, but still need it when calling
    // coladvance_force().
    // coladvance_force() uses get_ve_flags() to get the 'virtualedit'
    // state for the current window.  To override that state, we need to
    // set the window-local value of ve_flags rather than the global value.
    if (curwin->w_cursor.coladd > 0) {
      unsigned old_ve_flags = curwin->w_ve_flags;

      if (u_save_cursor() == FAIL) {
        return;
      }
      curwin->w_ve_flags = VE_ALL;
      coladvance_force(oap->op_type == OP_APPEND
                       ? oap->end_vcol + 1 : getviscol());
      if (oap->op_type == OP_APPEND) {
        curwin->w_cursor.col--;
      }
      curwin->w_ve_flags = old_ve_flags;
    }
    // Get the info about the block before entering the text
    block_prep(oap, &bd, oap->start.lnum, true);
    // Get indent information
    ind_pre_col = (colnr_T)getwhitecols_curline();
    ind_pre_vcol = get_indent();
    pre_textlen = ml_get_len(oap->start.lnum) - bd.textcol;
    if (oap->op_type == OP_APPEND) {
      pre_textlen -= bd.textlen;
    }
  }

  if (oap->op_type == OP_APPEND) {
    if (oap->motion_type == kMTBlockWise
        && curwin->w_cursor.coladd == 0) {
      // Move the cursor to the character right of the block.
      curwin->w_set_curswant = true;
      while (*get_cursor_pos_ptr() != NUL
             && (curwin->w_cursor.col < bd.textcol + bd.textlen)) {
        curwin->w_cursor.col++;
      }
      if (bd.is_short && !bd.is_MAX) {
        // First line was too short, make it longer and adjust the
        // values in "bd".
        if (u_save_cursor() == FAIL) {
          return;
        }
        for (int i = 0; i < bd.endspaces; i++) {
          ins_char(' ');
        }
        bd.textlen += bd.endspaces;
      }
    } else {
      curwin->w_cursor = oap->end;
      check_cursor_col(curwin);

      // Works just like an 'i'nsert on the next character.
      if (!LINEEMPTY(curwin->w_cursor.lnum)
          && oap->start_vcol != oap->end_vcol) {
        inc_cursor();
      }
    }
  }

  pos_T t1 = oap->start;
  const pos_T start_insert = curwin->w_cursor;
  edit(NUL, false, (linenr_T)count1);

  // When a tab was inserted, and the characters in front of the tab
  // have been converted to a tab as well, the column of the cursor
  // might have actually been reduced, so need to adjust here.
  if (t1.lnum == curbuf->b_op_start_orig.lnum
      && lt(curbuf->b_op_start_orig, t1)) {
    oap->start = curbuf->b_op_start_orig;
  }

  // If user has moved off this line, we don't know what to do, so do
  // nothing.
  // Also don't repeat the insert when Insert mode ended with CTRL-C.
  if (curwin->w_cursor.lnum != oap->start.lnum || got_int) {
    return;
  }

  if (oap->motion_type == kMTBlockWise) {
    int ind_post_vcol = 0;
    struct block_def bd2;
    bool did_indent = false;

    // if indent kicked in, the firstline might have changed
    // but only do that, if the indent actually increased
    colnr_T ind_post_col = (colnr_T)getwhitecols_curline();
    if (curbuf->b_op_start.col > ind_pre_col && ind_post_col > ind_pre_col) {
      bd.textcol += ind_post_col - ind_pre_col;
      ind_post_vcol = get_indent();
      bd.start_vcol += ind_post_vcol - ind_pre_vcol;
      did_indent = true;
    }

    // The user may have moved the cursor before inserting something, try
    // to adjust the block for that.  But only do it, if the difference
    // does not come from indent kicking in.
    if (oap->start.lnum == curbuf->b_op_start_orig.lnum && !bd.is_MAX && !did_indent) {
      const int t = getviscol2(curbuf->b_op_start_orig.col, curbuf->b_op_start_orig.coladd);

      if (oap->op_type == OP_INSERT
          && oap->start.col + oap->start.coladd
          != curbuf->b_op_start_orig.col + curbuf->b_op_start_orig.coladd) {
        oap->start.col = curbuf->b_op_start_orig.col;
        pre_textlen -= t - oap->start_vcol;
        oap->start_vcol = t;
      } else if (oap->op_type == OP_APPEND
                 && oap->start.col + oap->start.coladd
                 >= curbuf->b_op_start_orig.col + curbuf->b_op_start_orig.coladd) {
        oap->start.col = curbuf->b_op_start_orig.col;
        // reset pre_textlen to the value of OP_INSERT
        pre_textlen += bd.textlen;
        pre_textlen -= t - oap->start_vcol;
        oap->start_vcol = t;
        oap->op_type = OP_INSERT;
      }
    }

    // Spaces and tabs in the indent may have changed to other spaces and
    // tabs.  Get the starting column again and correct the length.
    // Don't do this when "$" used, end-of-line will have changed.
    //
    // if indent was added and the inserted text was after the indent,
    // correct the selection for the new indent.
    if (did_indent && bd.textcol - ind_post_col > 0) {
      oap->start.col += ind_post_col - ind_pre_col;
      oap->start_vcol += ind_post_vcol - ind_pre_vcol;
      oap->end.col += ind_post_col - ind_pre_col;
      oap->end_vcol += ind_post_vcol - ind_pre_vcol;
    }
    block_prep(oap, &bd2, oap->start.lnum, true);
    if (did_indent && bd.textcol - ind_post_col > 0) {
      // undo for where "oap" is used below
      oap->start.col -= ind_post_col - ind_pre_col;
      oap->start_vcol -= ind_post_vcol - ind_pre_vcol;
      oap->end.col -= ind_post_col - ind_pre_col;
      oap->end_vcol -= ind_post_vcol - ind_pre_vcol;
    }
    if (!bd.is_MAX || bd2.textlen < bd.textlen) {
      if (oap->op_type == OP_APPEND) {
        pre_textlen += bd2.textlen - bd.textlen;
        if (bd2.endspaces) {
          bd2.textlen--;
        }
      }
      bd.textcol = bd2.textcol;
      bd.textlen = bd2.textlen;
    }

    // Subsequent calls to ml_get() flush the firstline data - take a
    // copy of the required string.
    char *firstline = ml_get(oap->start.lnum);
    colnr_T len = ml_get_len(oap->start.lnum);
    colnr_T add = bd.textcol;
    colnr_T offset = 0;  // offset when cursor was moved in insert mode
    if (oap->op_type == OP_APPEND) {
      add += bd.textlen;
      // account for pressing cursor in insert mode when '$' was used
      if (bd.is_MAX && start_insert.lnum == Insstart.lnum && start_insert.col > Insstart.col) {
        offset = start_insert.col - Insstart.col;
        add -= offset;
        if (oap->end_vcol > offset) {
          oap->end_vcol -= offset + 1;
        } else {
          // moved outside of the visual block, what to do?
          return;
        }
      }
    }
    if (add > len) {
      add = len;  // short line, point to the NUL
    }
    firstline += add;
    len -= add;
    int ins_len = len - pre_textlen - offset;
    if (pre_textlen >= 0 && ins_len > 0) {
      char *ins_text = xmemdupz(firstline, (size_t)ins_len);
      // block handled here
      if (u_save(oap->start.lnum, (linenr_T)(oap->end.lnum + 1)) == OK) {
        block_insert(oap, ins_text, (size_t)ins_len, (oap->op_type == OP_INSERT), &bd);
      }

      curwin->w_cursor.col = oap->start.col;
      check_cursor(curwin);
      xfree(ins_text);
    }
  }
}

/// handle a change operation
///
/// @return  true if edit() returns because of a CTRL-O command
int op_change(oparg_T *oap)
{
  int pre_textlen = 0;
  int pre_indent = 0;
  char *firstline;
  struct block_def bd;

  colnr_T l = oap->start.col;
  if (oap->motion_type == kMTLineWise) {
    l = 0;
    can_si = may_do_si();  // Like opening a new line, do smart indent
  }

  // First delete the text in the region.  In an empty buffer only need to
  // save for undo
  if (curbuf->b_ml.ml_flags & ML_EMPTY) {
    if (u_save_cursor() == FAIL) {
      return false;
    }
  } else if (op_delete(oap) == FAIL) {
    return false;
  }

  if ((l > curwin->w_cursor.col) && !LINEEMPTY(curwin->w_cursor.lnum)
      && !virtual_op) {
    inc_cursor();
  }

  // check for still on same line (<CR> in inserted text meaningless)
  // skip blank lines too
  if (oap->motion_type == kMTBlockWise) {
    // Add spaces before getting the current line length.
    if (virtual_op && (curwin->w_cursor.coladd > 0
                       || gchar_cursor() == NUL)) {
      coladvance_force(getviscol());
    }
    firstline = ml_get(oap->start.lnum);
    pre_textlen = ml_get_len(oap->start.lnum);
    pre_indent = (int)getwhitecols(firstline);
    bd.textcol = curwin->w_cursor.col;
  }

  if (oap->motion_type == kMTLineWise) {
    fix_indent();
  }

  // Reset finish_op now, don't want it set inside edit().
  const bool save_finish_op = finish_op;
  finish_op = false;

  int retval = edit(NUL, false, 1);

  finish_op = save_finish_op;

  // In Visual block mode, handle copying the new text to all lines of the
  // block.
  // Don't repeat the insert when Insert mode ended with CTRL-C.
  if (oap->motion_type == kMTBlockWise
      && oap->start.lnum != oap->end.lnum && !got_int) {
    // Auto-indenting may have changed the indent.  If the cursor was past
    // the indent, exclude that indent change from the inserted text.
    firstline = ml_get(oap->start.lnum);
    if (bd.textcol > (colnr_T)pre_indent) {
      int new_indent = (int)getwhitecols(firstline);

      pre_textlen += new_indent - pre_indent;
      bd.textcol += (colnr_T)(new_indent - pre_indent);
    }

    int ins_len = ml_get_len(oap->start.lnum) - pre_textlen;
    if (ins_len > 0) {
      // Subsequent calls to ml_get() flush the firstline data - take a
      // copy of the inserted text.
      char *ins_text = xmalloc((size_t)ins_len + 1);
      xmemcpyz(ins_text, firstline + bd.textcol, (size_t)ins_len);
      for (linenr_T linenr = oap->start.lnum + 1; linenr <= oap->end.lnum;
           linenr++) {
        block_prep(oap, &bd, linenr, true);
        if (!bd.is_short || virtual_op) {
          pos_T vpos;

          // If the block starts in virtual space, count the
          // initial coladd offset as part of "startspaces"
          if (bd.is_short) {
            vpos.lnum = linenr;
            getvpos(curwin, &vpos, oap->start_vcol);
          } else {
            vpos.coladd = 0;
          }
          char *oldp = ml_get(linenr);
          char *newp = xmalloc((size_t)ml_get_len(linenr)
                               + (size_t)vpos.coladd + (size_t)ins_len + 1);
          // copy up to block start
          memmove(newp, oldp, (size_t)bd.textcol);
          int newlen = bd.textcol;
          memset(newp + newlen, ' ', (size_t)vpos.coladd);
          newlen += vpos.coladd;
          memmove(newp + newlen, ins_text, (size_t)ins_len);
          newlen += ins_len;
          STRCPY(newp + newlen, oldp + bd.textcol);
          ml_replace(linenr, newp, false);
          extmark_splice_cols(curbuf, (int)linenr - 1, bd.textcol,
                              0, vpos.coladd + ins_len, kExtmarkUndo);
        }
      }
      check_cursor(curwin);
      changed_lines(curbuf, oap->start.lnum + 1, 0, oap->end.lnum + 1, 0, true);
      xfree(ins_text);
    }
  }
  auto_format(false, true);

  return retval;
}

#if defined(EXITFREE)
void clear_registers(void)
{
  for (int i = 0; i < NUM_REGISTERS; i++) {
    free_register(&y_regs[i]);
  }
}

#endif

/// Free contents of yankreg `reg`.
/// Called for normal freeing and in case of error.
///
/// @param reg  must not be NULL (but `reg->y_array` might be)
void free_register(yankreg_T *reg)
  FUNC_ATTR_NONNULL_ALL
{
  set_yreg_additional_data(reg, NULL);
  if (reg->y_array == NULL) {
    return;
  }

  for (size_t i = reg->y_size; i-- > 0;) {  // from y_size - 1 to 0 included
    xfree(reg->y_array[i]);
  }
  XFREE_CLEAR(reg->y_array);
}

/// Yanks the text between "oap->start" and "oap->end" into a yank register.
/// If we are to append (uppercase register), we first yank into a new yank
/// register and then concatenate the old and the new one.
/// Do not call this from a delete operation. Use op_yank_reg() instead.
///
/// @param oap operator arguments
/// @param message show message when more than `&report` lines are yanked.
/// @returns whether the operation register was writable.
bool op_yank(oparg_T *oap, bool message)
  FUNC_ATTR_NONNULL_ALL
{
  // check for read-only register
  if (oap->regname != 0 && !valid_yank_reg(oap->regname, true)) {
    beep_flush();
    return false;
  }
  if (oap->regname == '_') {
    return true;  // black hole: nothing to do
  }

  yankreg_T *reg = get_yank_register(oap->regname, YREG_YANK);
  op_yank_reg(oap, message, reg, is_append_register(oap->regname));
  set_clipboard(oap->regname, reg);
  do_autocmd_textyankpost(oap, reg);

  return true;
}

static void op_yank_reg(oparg_T *oap, bool message, yankreg_T *reg, bool append)
{
  yankreg_T newreg;  // new yank register when appending
  MotionType yank_type = oap->motion_type;
  size_t yanklines = (size_t)oap->line_count;
  linenr_T yankendlnum = oap->end.lnum;
  struct block_def bd;

  yankreg_T *curr = reg;  // copy of current register
  // append to existing contents
  if (append && reg->y_array != NULL) {
    reg = &newreg;
  } else {
    free_register(reg);  // free previously yanked lines
  }

  // If the cursor was in column 1 before and after the movement, and the
  // operator is not inclusive, the yank is always linewise.
  if (oap->motion_type == kMTCharWise
      && oap->start.col == 0
      && !oap->inclusive
      && (!oap->is_VIsual || *p_sel == 'o')
      && oap->end.col == 0
      && yanklines > 1) {
    yank_type = kMTLineWise;
    yankendlnum--;
    yanklines--;
  }

  reg->y_size = yanklines;
  reg->y_type = yank_type;  // set the yank register type
  reg->y_width = 0;
  reg->y_array = xcalloc(yanklines, sizeof(char *));
  reg->additional_data = NULL;
  reg->timestamp = os_time();

  size_t y_idx = 0;  // index in y_array[]
  linenr_T lnum = oap->start.lnum;  // current line number

  if (yank_type == kMTBlockWise) {
    // Visual block mode
    reg->y_width = oap->end_vcol - oap->start_vcol;

    if (curwin->w_curswant == MAXCOL && reg->y_width > 0) {
      reg->y_width--;
    }
  }

  for (; lnum <= yankendlnum; lnum++, y_idx++) {
    switch (reg->y_type) {
    case kMTBlockWise:
      block_prep(oap, &bd, lnum, false);
      yank_copy_line(reg, &bd, y_idx, oap->excl_tr_ws);
      break;

    case kMTLineWise:
      reg->y_array[y_idx] = xstrdup(ml_get(lnum));
      break;

    case kMTCharWise:
      charwise_block_prep(oap->start, oap->end, &bd, lnum, oap->inclusive);
      yank_copy_line(reg, &bd, y_idx, false);
      break;

    // NOTREACHED
    case kMTUnknown:
      abort();
    }
  }

  if (curr != reg) {      // append the new block to the old block
    size_t j;
    char **new_ptr = xmalloc(sizeof(char *) * (curr->y_size + reg->y_size));
    for (j = 0; j < curr->y_size; j++) {
      new_ptr[j] = curr->y_array[j];
    }
    xfree(curr->y_array);
    curr->y_array = new_ptr;

    if (yank_type == kMTLineWise) {
      // kMTLineWise overrides kMTCharWise and kMTBlockWise
      curr->y_type = kMTLineWise;
    }

    // Concatenate the last line of the old block with the first line of
    // the new block, unless being Vi compatible.
    if (curr->y_type == kMTCharWise
        && vim_strchr(p_cpo, CPO_REGAPPEND) == NULL) {
      char *pnew = xmalloc(strlen(curr->y_array[curr->y_size - 1])
                           + strlen(reg->y_array[0]) + 1);
      STRCPY(pnew, curr->y_array[--j]);
      strcat(pnew, reg->y_array[0]);
      xfree(curr->y_array[j]);
      xfree(reg->y_array[0]);
      curr->y_array[j++] = pnew;
      y_idx = 1;
    } else {
      y_idx = 0;
    }
    while (y_idx < reg->y_size) {
      curr->y_array[j++] = reg->y_array[y_idx++];
    }
    curr->y_size = j;
    xfree(reg->y_array);
  }

  if (message) {  // Display message about yank?
    if (yank_type == kMTCharWise && yanklines == 1) {
      yanklines = 0;
    }
    // Some versions of Vi use ">=" here, some don't...
    if (yanklines > (size_t)p_report) {
      char namebuf[100];

      if (oap->regname == NUL) {
        *namebuf = NUL;
      } else {
        vim_snprintf(namebuf, sizeof(namebuf), _(" into \"%c"), oap->regname);
      }

      // redisplay now, so message is not deleted
      update_topline(curwin);
      if (must_redraw) {
        update_screen();
      }
      if (yank_type == kMTBlockWise) {
        smsg(0, NGETTEXT("block of %" PRId64 " line yanked%s",
                         "block of %" PRId64 " lines yanked%s", yanklines),
             (int64_t)yanklines, namebuf);
      } else {
        smsg(0, NGETTEXT("%" PRId64 " line yanked%s",
                         "%" PRId64 " lines yanked%s", yanklines),
             (int64_t)yanklines, namebuf);
      }
    }
  }

  if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
    // Set "'[" and "']" marks.
    curbuf->b_op_start = oap->start;
    curbuf->b_op_end = oap->end;
    if (yank_type == kMTLineWise) {
      curbuf->b_op_start.col = 0;
      curbuf->b_op_end.col = MAXCOL;
    }
  }
}

/// Copy a block range into a register.
///
/// @param exclude_trailing_space  if true, do not copy trailing whitespaces.
static void yank_copy_line(yankreg_T *reg, struct block_def *bd, size_t y_idx,
                           bool exclude_trailing_space)
  FUNC_ATTR_NONNULL_ALL
{
  if (exclude_trailing_space) {
    bd->endspaces = 0;
  }
  int size = bd->startspaces + bd->endspaces + bd->textlen;
  assert(size >= 0);
  char *pnew = xmallocz((size_t)size);
  reg->y_array[y_idx] = pnew;
  memset(pnew, ' ', (size_t)bd->startspaces);
  pnew += bd->startspaces;
  memmove(pnew, bd->textstart, (size_t)bd->textlen);
  pnew += bd->textlen;
  memset(pnew, ' ', (size_t)bd->endspaces);
  pnew += bd->endspaces;
  if (exclude_trailing_space) {
    int s = bd->textlen + bd->endspaces;

    while (s > 0 && ascii_iswhite(*(bd->textstart + s - 1))) {
      s = s - utf_head_off(bd->textstart, bd->textstart + s - 1) - 1;
      pnew--;
    }
  }
  *pnew = NUL;
}

/// Execute autocommands for TextYankPost.
///
/// @param oap Operator arguments.
/// @param reg The yank register used.
static void do_autocmd_textyankpost(oparg_T *oap, yankreg_T *reg)
  FUNC_ATTR_NONNULL_ALL
{
  static bool recursive = false;

  if (recursive || !has_event(EVENT_TEXTYANKPOST)) {
    // No autocommand was defined, or we yanked from this autocommand.
    return;
  }

  recursive = true;

  save_v_event_T save_v_event;
  // Set the v:event dictionary with information about the yank.
  dict_T *dict = get_v_event(&save_v_event);

  // The yanked text contents.
  list_T *const list = tv_list_alloc((ptrdiff_t)reg->y_size);
  for (size_t i = 0; i < reg->y_size; i++) {
    tv_list_append_string(list, reg->y_array[i], -1);
  }
  tv_list_set_lock(list, VAR_FIXED);
  tv_dict_add_list(dict, S_LEN("regcontents"), list);

  // Register type.
  char buf[NUMBUFLEN + 2];
  format_reg_type(reg->y_type, reg->y_width, buf, ARRAY_SIZE(buf));
  tv_dict_add_str(dict, S_LEN("regtype"), buf);

  // Name of requested register, or empty string for unnamed operation.
  buf[0] = (char)oap->regname;
  buf[1] = NUL;
  tv_dict_add_str(dict, S_LEN("regname"), buf);

  // Motion type: inclusive or exclusive.
  tv_dict_add_bool(dict, S_LEN("inclusive"),
                   oap->inclusive ? kBoolVarTrue : kBoolVarFalse);

  // Kind of operation: yank, delete, change).
  buf[0] = (char)get_op_char(oap->op_type);
  buf[1] = NUL;
  tv_dict_add_str(dict, S_LEN("operator"), buf);

  // Selection type: visual or not.
  tv_dict_add_bool(dict, S_LEN("visual"),
                   oap->is_VIsual ? kBoolVarTrue : kBoolVarFalse);

  tv_dict_set_keys_readonly(dict);
  textlock++;
  apply_autocmds(EVENT_TEXTYANKPOST, NULL, NULL, false, curbuf);
  textlock--;
  restore_v_event(dict, &save_v_event);

  recursive = false;
}

/// Put contents of register "regname" into the text.
/// Caller must check "regname" to be valid!
///
/// @param flags  PUT_FIXINDENT     make indent look nice
///               PUT_CURSEND       leave cursor after end of new text
///               PUT_LINE          force linewise put (":put")
///               PUT_BLOCK_INNER   in block mode, do not add trailing spaces
/// @param dir    BACKWARD for 'P', FORWARD for 'p'
void do_put(int regname, yankreg_T *reg, int dir, int count, int flags)
{
  size_t totlen = 0;  // init for gcc
  linenr_T lnum = 0;
  MotionType y_type;
  size_t y_size;
  int y_width = 0;
  colnr_T vcol = 0;
  int incr = 0;
  struct block_def bd;
  char **y_array = NULL;
  linenr_T nr_lines = 0;
  int indent;
  int orig_indent = 0;                  // init for gcc
  int indent_diff = 0;                  // init for gcc
  bool first_indent = true;
  int lendiff = 0;
  char *insert_string = NULL;
  bool allocated = false;
  const pos_T orig_start = curbuf->b_op_start;
  const pos_T orig_end = curbuf->b_op_end;
  unsigned cur_ve_flags = get_ve_flags(curwin);

  if (flags & PUT_FIXINDENT) {
    orig_indent = get_indent();
  }

  curbuf->b_op_start = curwin->w_cursor;        // default for '[ mark
  curbuf->b_op_end = curwin->w_cursor;          // default for '] mark

  // Using inserted text works differently, because the register includes
  // special characters (newlines, etc.).
  if (regname == '.' && !reg) {
    bool non_linewise_vis = (VIsual_active && VIsual_mode != 'V');

    // PUT_LINE has special handling below which means we use 'i' to start.
    char command_start_char = non_linewise_vis
                              ? 'c'
                              : (flags & PUT_LINE ? 'i' : (dir == FORWARD ? 'a' : 'i'));

    // To avoid 'autoindent' on linewise puts, create a new line with `:put _`.
    if (flags & PUT_LINE) {
      do_put('_', NULL, dir, 1, PUT_LINE);
    }

    // If given a count when putting linewise, we stuff the readbuf with the
    // dot register 'count' times split by newlines.
    if (flags & PUT_LINE) {
      stuffcharReadbuff(command_start_char);
      for (; count > 0; count--) {
        stuff_inserted(NUL, 1, count != 1);
        if (count != 1) {
          // To avoid 'autoindent' affecting the text, use Ctrl_U to remove any
          // whitespace. Can't just insert Ctrl_U into readbuf1, this would go
          // back to the previous line in the case of 'noautoindent' and
          // 'backspace' includes "eol". So we insert a dummy space for Ctrl_U
          // to consume.
          stuffReadbuff("\n ");
          stuffcharReadbuff(Ctrl_U);
        }
      }
    } else {
      stuff_inserted(command_start_char, count, false);
    }

    // Putting the text is done later, so can't move the cursor to the next
    // character.  Simulate it with motion commands after the insert.
    if (flags & PUT_CURSEND) {
      if (flags & PUT_LINE) {
        stuffReadbuff("j0");
      } else {
        // Avoid ringing the bell from attempting to move into the space after
        // the current line. We can stuff the readbuffer with "l" if:
        // 1) 'virtualedit' is "all" or "onemore"
        // 2) We are not at the end of the line
        // 3) We are not  (one past the end of the line && on the last line)
        //    This allows a visual put over a selection one past the end of the
        //    line joining the current line with the one below.

        // curwin->w_cursor.col marks the byte position of the cursor in the
        // currunt line. It increases up to a max of
        // strlen(ml_get(curwin->w_cursor.lnum)). With 'virtualedit' and the
        // cursor past the end of the line, curwin->w_cursor.coladd is
        // incremented instead of curwin->w_cursor.col.
        char *cursor_pos = get_cursor_pos_ptr();
        bool one_past_line = (*cursor_pos == NUL);
        bool eol = false;
        if (!one_past_line) {
          eol = (*(cursor_pos + utfc_ptr2len(cursor_pos)) == NUL);
        }

        bool ve_allows = (cur_ve_flags == VE_ALL || cur_ve_flags == VE_ONEMORE);
        bool eof = curbuf->b_ml.ml_line_count == curwin->w_cursor.lnum
                   && one_past_line;
        if (ve_allows || !(eol || eof)) {
          stuffcharReadbuff('l');
        }
      }
    } else if (flags & PUT_LINE) {
      stuffReadbuff("g'[");
    }

    // So the 'u' command restores cursor position after ".p, save the cursor
    // position now (though not saving any text).
    if (command_start_char == 'a') {
      if (u_save(curwin->w_cursor.lnum, curwin->w_cursor.lnum + 1) == FAIL) {
        return;
      }
    }
    return;
  }

  // For special registers '%' (file name), '#' (alternate file name) and
  // ':' (last command line), etc. we have to create a fake yank register.
  if (!reg && get_spec_reg(regname, &insert_string, &allocated, true)) {
    if (insert_string == NULL) {
      return;
    }
  }

  if (!curbuf->terminal) {
    // Autocommands may be executed when saving lines for undo.  This might
    // make y_array invalid, so we start undo now to avoid that.
    if (u_save(curwin->w_cursor.lnum, curwin->w_cursor.lnum + 1) == FAIL) {
      return;
    }
  }

  if (insert_string != NULL) {
    y_type = kMTCharWise;
    if (regname == '=') {
      // For the = register we need to split the string at NL
      // characters.
      // Loop twice: count the number of lines and save them.
      while (true) {
        y_size = 0;
        char *ptr = insert_string;
        while (ptr != NULL) {
          if (y_array != NULL) {
            y_array[y_size] = ptr;
          }
          y_size++;
          ptr = vim_strchr(ptr, '\n');
          if (ptr != NULL) {
            if (y_array != NULL) {
              *ptr = NUL;
            }
            ptr++;
            // A trailing '\n' makes the register linewise.
            if (*ptr == NUL) {
              y_type = kMTLineWise;
              break;
            }
          }
        }
        if (y_array != NULL) {
          break;
        }
        y_array = xmalloc(y_size * sizeof(char *));
      }
    } else {
      y_size = 1;               // use fake one-line yank register
      y_array = &insert_string;
    }
  } else {
    // in case of replacing visually selected text
    // the yankreg might already have been saved to avoid
    // just restoring the deleted text.
    if (reg == NULL) {
      reg = get_yank_register(regname, YREG_PASTE);
    }

    y_type = reg->y_type;
    y_width = reg->y_width;
    y_size = reg->y_size;
    y_array = reg->y_array;
  }

  if (curbuf->terminal) {
    terminal_paste(count, y_array, y_size);
    return;
  }

  colnr_T split_pos = 0;
  if (y_type == kMTLineWise) {
    if (flags & PUT_LINE_SPLIT) {
      // "p" or "P" in Visual mode: split the lines to put the text in
      // between.
      if (u_save_cursor() == FAIL) {
        goto end;
      }
      char *curline = get_cursor_line_ptr();
      char *p = curline + curwin->w_cursor.col;
      if (dir == FORWARD && *p != NUL) {
        MB_PTR_ADV(p);
      }
      // we need this later for the correct extmark_splice() event
      split_pos = (colnr_T)(p - curline);

      char *ptr = xstrdup(p);
      ml_append(curwin->w_cursor.lnum, ptr, 0, false);
      xfree(ptr);

      ptr = xmemdupz(get_cursor_line_ptr(), (size_t)split_pos);
      ml_replace(curwin->w_cursor.lnum, ptr, false);
      nr_lines++;
      dir = FORWARD;

      buf_updates_send_changes(curbuf, curwin->w_cursor.lnum, 1, 1);
    }
    if (flags & PUT_LINE_FORWARD) {
      // Must be "p" for a Visual block, put lines below the block.
      curwin->w_cursor = curbuf->b_visual.vi_end;
      dir = FORWARD;
    }
    curbuf->b_op_start = curwin->w_cursor;      // default for '[ mark
    curbuf->b_op_end = curwin->w_cursor;        // default for '] mark
  }

  if (flags & PUT_LINE) {  // :put command or "p" in Visual line mode.
    y_type = kMTLineWise;
  }

  if (y_size == 0 || y_array == NULL) {
    semsg(_("E353: Nothing in register %s"),
          regname == 0 ? "\"" : transchar(regname));
    goto end;
  }

  if (y_type == kMTBlockWise) {
    lnum = curwin->w_cursor.lnum + (linenr_T)y_size + 1;
    if (lnum > curbuf->b_ml.ml_line_count) {
      lnum = curbuf->b_ml.ml_line_count + 1;
    }
    if (u_save(curwin->w_cursor.lnum - 1, lnum) == FAIL) {
      goto end;
    }
  } else if (y_type == kMTLineWise) {
    lnum = curwin->w_cursor.lnum;
    // Correct line number for closed fold.  Don't move the cursor yet,
    // u_save() uses it.
    if (dir == BACKWARD) {
      hasFolding(curwin, lnum, &lnum, NULL);
    } else {
      hasFolding(curwin, lnum, NULL, &lnum);
    }
    if (dir == FORWARD) {
      lnum++;
    }
    // In an empty buffer the empty line is going to be replaced, include
    // it in the saved lines.
    if ((buf_is_empty(curbuf)
         ? u_save(0, 2) : u_save(lnum - 1, lnum)) == FAIL) {
      goto end;
    }
    if (dir == FORWARD) {
      curwin->w_cursor.lnum = lnum - 1;
    } else {
      curwin->w_cursor.lnum = lnum;
    }
    curbuf->b_op_start = curwin->w_cursor;      // for mark_adjust()
  } else if (u_save_cursor() == FAIL) {
    goto end;
  }

  int yanklen = (int)strlen(y_array[0]);

  if (cur_ve_flags == VE_ALL && y_type == kMTCharWise) {
    if (gchar_cursor() == TAB) {
      int viscol = getviscol();
      OptInt ts = curbuf->b_p_ts;
      // Don't need to insert spaces when "p" on the last position of a
      // tab or "P" on the first position.
      if (dir == FORWARD
          ? tabstop_padding(viscol, ts, curbuf->b_p_vts_array) != 1
          : curwin->w_cursor.coladd > 0) {
        coladvance_force(viscol);
      } else {
        curwin->w_cursor.coladd = 0;
      }
    } else if (curwin->w_cursor.coladd > 0 || gchar_cursor() == NUL) {
      coladvance_force(getviscol() + (dir == FORWARD));
    }
  }

  lnum = curwin->w_cursor.lnum;
  colnr_T col = curwin->w_cursor.col;

  // Block mode
  if (y_type == kMTBlockWise) {
    int c = gchar_cursor();
    colnr_T endcol2 = 0;

    if (dir == FORWARD && c != NUL) {
      if (cur_ve_flags == VE_ALL) {
        getvcol(curwin, &curwin->w_cursor, &col, NULL, &endcol2);
      } else {
        getvcol(curwin, &curwin->w_cursor, NULL, NULL, &col);
      }

      // move to start of next multi-byte character
      curwin->w_cursor.col += utfc_ptr2len(get_cursor_pos_ptr());
      col++;
    } else {
      getvcol(curwin, &curwin->w_cursor, &col, NULL, &endcol2);
    }

    col += curwin->w_cursor.coladd;
    if (cur_ve_flags == VE_ALL
        && (curwin->w_cursor.coladd > 0 || endcol2 == curwin->w_cursor.col)) {
      if (dir == FORWARD && c == NUL) {
        col++;
      }
      if (dir != FORWARD && c != NUL && curwin->w_cursor.coladd > 0) {
        curwin->w_cursor.col++;
      }
      if (c == TAB) {
        if (dir == BACKWARD && curwin->w_cursor.col) {
          curwin->w_cursor.col--;
        }
        if (dir == FORWARD && col - 1 == endcol2) {
          curwin->w_cursor.col++;
        }
      }
    }
    curwin->w_cursor.coladd = 0;
    bd.textcol = 0;
    for (size_t i = 0; i < y_size; i++) {
      int spaces = 0;
      char shortline;
      // can just be 0 or 1, needed for blockwise paste beyond the current
      // buffer end
      int lines_appended = 0;

      bd.startspaces = 0;
      bd.endspaces = 0;
      vcol = 0;
      int delcount = 0;

      // add a new line
      if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count) {
        if (ml_append(curbuf->b_ml.ml_line_count, "", 1, false) == FAIL) {
          break;
        }
        nr_lines++;
        lines_appended = 1;
      }
      // get the old line and advance to the position to insert at
      char *oldp = get_cursor_line_ptr();
      colnr_T oldlen = get_cursor_line_len();

      CharsizeArg csarg;
      CSType cstype = init_charsize_arg(&csarg, curwin, curwin->w_cursor.lnum, oldp);
      StrCharInfo ci = utf_ptr2StrCharInfo(oldp);
      vcol = 0;
      while (vcol < col && *ci.ptr != NUL) {
        incr = win_charsize(cstype, vcol, ci.ptr, ci.chr.value, &csarg).width;
        vcol += incr;
        ci = utfc_next(ci);
      }
      char *ptr = ci.ptr;
      bd.textcol = (colnr_T)(ptr - oldp);

      shortline = (vcol < col) || (vcol == col && !*ptr);

      if (vcol < col) {     // line too short, pad with spaces
        bd.startspaces = col - vcol;
      } else if (vcol > col) {
        bd.endspaces = vcol - col;
        bd.startspaces = incr - bd.endspaces;
        bd.textcol--;
        delcount = 1;
        bd.textcol -= utf_head_off(oldp, oldp + bd.textcol);
        if (oldp[bd.textcol] != TAB) {
          // Only a Tab can be split into spaces.  Other
          // characters will have to be moved to after the
          // block, causing misalignment.
          delcount = 0;
          bd.endspaces = 0;
        }
      }

      yanklen = (int)strlen(y_array[i]);

      if ((flags & PUT_BLOCK_INNER) == 0) {
        // calculate number of spaces required to fill right side of block
        spaces = y_width + 1;

        cstype = init_charsize_arg(&csarg, curwin, 0, y_array[i]);
        ci = utf_ptr2StrCharInfo(y_array[i]);
        while (*ci.ptr != NUL) {
          spaces -= win_charsize(cstype, 0, ci.ptr, ci.chr.value, &csarg).width;
          ci = utfc_next(ci);
        }
        if (spaces < 0) {
          spaces = 0;
        }
      }

      // Insert the new text.
      // First check for multiplication overflow.
      if (yanklen + spaces != 0
          && count > ((INT_MAX - (bd.startspaces + bd.endspaces)) / (yanklen + spaces))) {
        emsg(_(e_resulting_text_too_long));
        break;
      }

      totlen = (size_t)count * (size_t)(yanklen + spaces) + (size_t)bd.startspaces +
               (size_t)bd.endspaces;
      char *newp = xmalloc(totlen + (size_t)oldlen + 1);

      // copy part up to cursor to new line
      ptr = newp;
      memmove(ptr, oldp, (size_t)bd.textcol);
      ptr += bd.textcol;

      // may insert some spaces before the new text
      memset(ptr, ' ', (size_t)bd.startspaces);
      ptr += bd.startspaces;

      // insert the new text
      for (int j = 0; j < count; j++) {
        memmove(ptr, y_array[i], (size_t)yanklen);
        ptr += yanklen;

        // insert block's trailing spaces only if there's text behind
        if ((j < count - 1 || !shortline) && spaces > 0) {
          memset(ptr, ' ', (size_t)spaces);
          ptr += spaces;
        } else {
          totlen -= (size_t)spaces;  // didn't use these spaces
        }
      }

      // may insert some spaces after the new text
      memset(ptr, ' ', (size_t)bd.endspaces);
      ptr += bd.endspaces;

      // move the text after the cursor to the end of the line.
      int columns = oldlen - bd.textcol - delcount + 1;
      assert(columns >= 0);
      memmove(ptr, oldp + bd.textcol + delcount, (size_t)columns);
      ml_replace(curwin->w_cursor.lnum, newp, false);
      extmark_splice_cols(curbuf, (int)curwin->w_cursor.lnum - 1, bd.textcol,
                          delcount, (int)totlen + lines_appended, kExtmarkUndo);

      curwin->w_cursor.lnum++;
      if (i == 0) {
        curwin->w_cursor.col += bd.startspaces;
      }
    }

    changed_lines(curbuf, lnum, 0, curbuf->b_op_start.lnum + (linenr_T)y_size
                  - nr_lines, nr_lines, true);

    // Set '[ mark.
    curbuf->b_op_start = curwin->w_cursor;
    curbuf->b_op_start.lnum = lnum;

    // adjust '] mark
    curbuf->b_op_end.lnum = curwin->w_cursor.lnum - 1;
    curbuf->b_op_end.col = bd.textcol + (colnr_T)totlen - 1;
    if (curbuf->b_op_end.col < 0) {
      curbuf->b_op_end.col = 0;
    }
    curbuf->b_op_end.coladd = 0;
    if (flags & PUT_CURSEND) {
      curwin->w_cursor = curbuf->b_op_end;
      curwin->w_cursor.col++;

      // in Insert mode we might be after the NUL, correct for that
      colnr_T len = get_cursor_line_len();
      if (curwin->w_cursor.col > len) {
        curwin->w_cursor.col = len;
      }
    } else {
      curwin->w_cursor.lnum = lnum;
    }
  } else {
    // Character or Line mode
    if (y_type == kMTCharWise) {
      // if type is kMTCharWise, FORWARD is the same as BACKWARD on the next
      // char
      if (dir == FORWARD && gchar_cursor() != NUL) {
        int bytelen = utfc_ptr2len(get_cursor_pos_ptr());

        // put it on the next of the multi-byte character.
        col += bytelen;
        if (yanklen) {
          curwin->w_cursor.col += bytelen;
          curbuf->b_op_end.col += bytelen;
        }
      }
      curbuf->b_op_start = curwin->w_cursor;
    } else if (dir == BACKWARD) {
      // Line mode: BACKWARD is the same as FORWARD on the previous line
      lnum--;
    }
    pos_T new_cursor = curwin->w_cursor;

    // simple case: insert into one line at a time
    if (y_type == kMTCharWise && y_size == 1) {
      linenr_T end_lnum = 0;  // init for gcc
      linenr_T start_lnum = lnum;
      int first_byte_off = 0;

      if (VIsual_active) {
        end_lnum = curbuf->b_visual.vi_end.lnum;
        if (end_lnum < curbuf->b_visual.vi_start.lnum) {
          end_lnum = curbuf->b_visual.vi_start.lnum;
        }
        if (end_lnum > start_lnum) {
          // "col" is valid for the first line, in following lines
          // the virtual column needs to be used.  Matters for
          // multi-byte characters.
          pos_T pos = {
            .lnum = lnum,
            .col = col,
            .coladd = 0,
          };
          getvcol(curwin, &pos, NULL, &vcol, NULL);
        }
      }

      if (count == 0 || yanklen == 0) {
        if (VIsual_active) {
          lnum = end_lnum;
        }
      } else if (count > INT_MAX / yanklen) {
        // multiplication overflow
        emsg(_(e_resulting_text_too_long));
      } else {
        totlen = (size_t)count * (size_t)yanklen;
        do {
          char *oldp = ml_get(lnum);
          colnr_T oldlen = ml_get_len(lnum);
          if (lnum > start_lnum) {
            pos_T pos = {
              .lnum = lnum,
            };
            if (getvpos(curwin, &pos, vcol) == OK) {
              col = pos.col;
            } else {
              col = MAXCOL;
            }
          }
          if (VIsual_active && col > oldlen) {
            lnum++;
            continue;
          }
          char *newp = xmalloc(totlen + (size_t)oldlen + 1);
          memmove(newp, oldp, (size_t)col);
          char *ptr = newp + col;
          for (size_t i = 0; i < (size_t)count; i++) {
            memmove(ptr, y_array[0], (size_t)yanklen);
            ptr += yanklen;
          }
          STRMOVE(ptr, oldp + col);
          ml_replace(lnum, newp, false);

          // compute the byte offset for the last character
          first_byte_off = utf_head_off(newp, ptr - 1);

          // Place cursor on last putted char.
          if (lnum == curwin->w_cursor.lnum) {
            // make sure curwin->w_virtcol is updated
            changed_cline_bef_curs(curwin);
            invalidate_botline(curwin);
            curwin->w_cursor.col += (colnr_T)(totlen - 1);
          }
          changed_bytes(lnum, col);
          extmark_splice_cols(curbuf, (int)lnum - 1, col,
                              0, (int)totlen, kExtmarkUndo);
          if (VIsual_active) {
            lnum++;
          }
        } while (VIsual_active && lnum <= end_lnum);

        if (VIsual_active) {  // reset lnum to the last visual line
          lnum--;
        }
      }

      // put '] at the first byte of the last character
      curbuf->b_op_end = curwin->w_cursor;
      curbuf->b_op_end.col -= first_byte_off;

      // For "CTRL-O p" in Insert mode, put cursor after last char
      if (totlen && (restart_edit != 0 || (flags & PUT_CURSEND))) {
        curwin->w_cursor.col++;
      } else {
        curwin->w_cursor.col -= first_byte_off;
      }
    } else {
      linenr_T new_lnum = new_cursor.lnum;

      // Insert at least one line.  When y_type is kMTCharWise, break the first
      // line in two.
      for (int cnt = 1; cnt <= count; cnt++) {
        size_t i = 0;
        if (y_type == kMTCharWise) {
          // Split the current line in two at the insert position.
          // First insert y_array[size - 1] in front of second line.
          // Then append y_array[0] to first line.
          lnum = new_cursor.lnum;
          char *ptr = ml_get(lnum) + col;
          totlen = strlen(y_array[y_size - 1]);
          char *newp = xmalloc((size_t)ml_get_len(lnum) - (size_t)col + totlen + 1);
          STRCPY(newp, y_array[y_size - 1]);
          strcat(newp, ptr);
          // insert second line
          ml_append(lnum, newp, 0, false);
          new_lnum++;
          xfree(newp);

          char *oldp = ml_get(lnum);
          newp = xmalloc((size_t)col + (size_t)yanklen + 1);
          // copy first part of line
          memmove(newp, oldp, (size_t)col);
          // append to first line
          memmove(newp + col, y_array[0], (size_t)yanklen + 1);
          ml_replace(lnum, newp, false);

          curwin->w_cursor.lnum = lnum;
          i = 1;
        }

        for (; i < y_size; i++) {
          if ((y_type != kMTCharWise || i < y_size - 1)) {
            if (ml_append(lnum, y_array[i], 0, false) == FAIL) {
              goto error;
            }
            new_lnum++;
          }
          lnum++;
          nr_lines++;
          if (flags & PUT_FIXINDENT) {
            pos_T old_pos = curwin->w_cursor;
            curwin->w_cursor.lnum = lnum;
            char *ptr = ml_get(lnum);
            if (cnt == count && i == y_size - 1) {
              lendiff = ml_get_len(lnum);
            }
            if (*ptr == '#' && preprocs_left()) {
              indent = 0;                   // Leave # lines at start
            } else if (*ptr == NUL) {
              indent = 0;                   // Ignore empty lines
            } else if (first_indent) {
              indent_diff = orig_indent - get_indent();
              indent = orig_indent;
              first_indent = false;
            } else if ((indent = get_indent() + indent_diff) < 0) {
              indent = 0;
            }
            set_indent(indent, SIN_NOMARK);
            curwin->w_cursor = old_pos;
            // remember how many chars were removed
            if (cnt == count && i == y_size - 1) {
              lendiff -= ml_get_len(lnum);
            }
          }
        }

        bcount_t totsize = 0;
        int lastsize = 0;
        if (y_type == kMTCharWise
            || (y_type == kMTLineWise && (flags & PUT_LINE_SPLIT))) {
          for (i = 0; i < y_size - 1; i++) {
            totsize += (bcount_t)strlen(y_array[i]) + 1;
          }
          lastsize = (int)strlen(y_array[y_size - 1]);
          totsize += lastsize;
        }
        if (y_type == kMTCharWise) {
          extmark_splice(curbuf, (int)new_cursor.lnum - 1, col, 0, 0, 0,
                         (int)y_size - 1, lastsize, totsize,
                         kExtmarkUndo);
        } else if (y_type == kMTLineWise && (flags & PUT_LINE_SPLIT)) {
          // Account for last pasted NL + last NL
          extmark_splice(curbuf, (int)new_cursor.lnum - 1, split_pos, 0, 0, 0,
                         (int)y_size + 1, 0, totsize + 2, kExtmarkUndo);
        }

        if (cnt == 1) {
          new_lnum = lnum;
        }
      }

error:
      // Adjust marks.
      if (y_type == kMTLineWise) {
        curbuf->b_op_start.col = 0;
        if (dir == FORWARD) {
          curbuf->b_op_start.lnum++;
        }
      }

      ExtmarkOp kind = (y_type == kMTLineWise && !(flags & PUT_LINE_SPLIT))
                       ? kExtmarkUndo : kExtmarkNOOP;
      mark_adjust(curbuf->b_op_start.lnum + (y_type == kMTCharWise),
                  (linenr_T)MAXLNUM, nr_lines, 0, kind);

      // note changed text for displaying and folding
      if (y_type == kMTCharWise) {
        changed_lines(curbuf, curwin->w_cursor.lnum, col,
                      curwin->w_cursor.lnum + 1, nr_lines, true);
      } else {
        changed_lines(curbuf, curbuf->b_op_start.lnum, 0,
                      curbuf->b_op_start.lnum, nr_lines, true);
      }

      // Put the '] mark on the first byte of the last inserted character.
      // Correct the length for change in indent.
      curbuf->b_op_end.lnum = new_lnum;
      size_t len = strlen(y_array[y_size - 1]);
      col = (colnr_T)len - lendiff;
      if (col > 1) {
        curbuf->b_op_end.col = col - 1;
        if (len > 0) {
          curbuf->b_op_end.col -= utf_head_off(y_array[y_size - 1],
                                               y_array[y_size - 1] + len - 1);
        }
      } else {
        curbuf->b_op_end.col = 0;
      }

      if (flags & PUT_CURSLINE) {
        // ":put": put cursor on last inserted line
        curwin->w_cursor.lnum = lnum;
        beginline(BL_WHITE | BL_FIX);
      } else if (flags & PUT_CURSEND) {
        // put cursor after inserted text
        if (y_type == kMTLineWise) {
          if (lnum >= curbuf->b_ml.ml_line_count) {
            curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
          } else {
            curwin->w_cursor.lnum = lnum + 1;
          }
          curwin->w_cursor.col = 0;
        } else {
          curwin->w_cursor.lnum = new_lnum;
          curwin->w_cursor.col = col;
          curbuf->b_op_end = curwin->w_cursor;
          if (col > 1) {
            curbuf->b_op_end.col = col - 1;
          }
        }
      } else if (y_type == kMTLineWise) {
        // put cursor on first non-blank in first inserted line
        curwin->w_cursor.col = 0;
        if (dir == FORWARD) {
          curwin->w_cursor.lnum++;
        }
        beginline(BL_WHITE | BL_FIX);
      } else {  // put cursor on first inserted character
        curwin->w_cursor = new_cursor;
      }
    }
  }

  msgmore(nr_lines);
  curwin->w_set_curswant = true;

  // Make sure the cursor is not after the NUL.
  int len = get_cursor_line_len();
  if (curwin->w_cursor.col > len) {
    if (cur_ve_flags == VE_ALL) {
      curwin->w_cursor.coladd = curwin->w_cursor.col - len;
    }
    curwin->w_cursor.col = len;
  }

end:
  if (cmdmod.cmod_flags & CMOD_LOCKMARKS) {
    curbuf->b_op_start = orig_start;
    curbuf->b_op_end = orig_end;
  }
  if (allocated) {
    xfree(insert_string);
  }
  if (regname == '=') {
    xfree(y_array);
  }

  VIsual_active = false;

  // If the cursor is past the end of the line put it at the end.
  adjust_cursor_eol();
}

/// When the cursor is on the NUL past the end of the line and it should not be
/// there move it left.
void adjust_cursor_eol(void)
{
  unsigned cur_ve_flags = get_ve_flags(curwin);

  const bool adj_cursor = (curwin->w_cursor.col > 0
                           && gchar_cursor() == NUL
                           && (cur_ve_flags & VE_ONEMORE) == 0
                           && !(restart_edit || (State & MODE_INSERT)));
  if (!adj_cursor) {
    return;
  }

  // Put the cursor on the last character in the line.
  dec_cursor();

  if (cur_ve_flags == VE_ALL) {
    colnr_T scol, ecol;

    // Coladd is set to the width of the last character.
    getvcol(curwin, &curwin->w_cursor, &scol, NULL, &ecol);
    curwin->w_cursor.coladd = ecol - scol + 1;
  }
}

/// @return  true if lines starting with '#' should be left aligned.
bool preprocs_left(void)
{
  return ((curbuf->b_p_si && !curbuf->b_p_cin)
          || (curbuf->b_p_cin && in_cinkeys('#', ' ', true)
              && curbuf->b_ind_hash_comment == 0));
}

/// @return  the character name of the register with the given number
int get_register_name(int num)
{
  if (num == -1) {
    return '"';
  } else if (num < 10) {
    return num + '0';
  } else if (num == DELETION_REGISTER) {
    return '-';
  } else if (num == STAR_REGISTER) {
    return '*';
  } else if (num == PLUS_REGISTER) {
    return '+';
  } else {
    return num + 'a' - 10;
  }
}

/// @return the index of the register "" points to.
int get_unname_register(void)
{
  return y_previous == NULL ? -1 : (int)(y_previous - &y_regs[0]);
}

/// ":dis" and ":registers": Display the contents of the yank registers.
void ex_display(exarg_T *eap)
{
  char *p;
  yankreg_T *yb;
  char *arg = eap->arg;
  int type;

  if (arg != NULL && *arg == NUL) {
    arg = NULL;
  }
  int attr = HL_ATTR(HLF_8);

  // Highlight title
  msg_puts_title(_("\nType Name Content"));
  for (int i = -1; i < NUM_REGISTERS && !got_int; i++) {
    int name = get_register_name(i);
    switch (get_reg_type(name, NULL)) {
    case kMTLineWise:
      type = 'l'; break;
    case kMTCharWise:
      type = 'c'; break;
    default:
      type = 'b'; break;
    }

    if (arg != NULL && vim_strchr(arg, name) == NULL) {
      continue;             // did not ask for this register
    }

    if (i == -1) {
      if (y_previous != NULL) {
        yb = y_previous;
      } else {
        yb = &(y_regs[0]);
      }
    } else {
      yb = &(y_regs[i]);
    }

    get_clipboard(name, &yb, true);

    if (name == mb_tolower(redir_reg)
        || (redir_reg == '"' && yb == y_previous)) {
      continue;  // do not list register being written to, the
                 // pointer can be freed
    }

    if (yb->y_array != NULL) {
      bool do_show = false;

      for (size_t j = 0; !do_show && j < yb->y_size; j++) {
        do_show = !message_filtered(yb->y_array[j]);
      }

      if (do_show || yb->y_size == 0) {
        msg_putchar('\n');
        msg_puts("  ");
        msg_putchar(type);
        msg_puts("  ");
        msg_putchar('"');
        msg_putchar(name);
        msg_puts("   ");

        int n = Columns - 11;
        for (size_t j = 0; j < yb->y_size && n > 1; j++) {
          if (j) {
            msg_puts_attr("^J", attr);
            n -= 2;
          }
          for (p = yb->y_array[j];
               *p != NUL && (n -= ptr2cells(p)) >= 0; p++) {
            int clen = utfc_ptr2len(p);
            msg_outtrans_len(p, clen, 0);
            p += clen - 1;
          }
        }
        if (n > 1 && yb->y_type == kMTLineWise) {
          msg_puts_attr("^J", attr);
        }
      }
      os_breakcheck();
    }
  }

  // display last inserted text
  if ((p = get_last_insert()) != NULL
      && (arg == NULL || vim_strchr(arg, '.') != NULL) && !got_int
      && !message_filtered(p)) {
    msg_puts("\n  c  \".   ");
    dis_msg(p, true);
  }

  // display last command line
  if (last_cmdline != NULL && (arg == NULL || vim_strchr(arg, ':') != NULL)
      && !got_int && !message_filtered(last_cmdline)) {
    msg_puts("\n  c  \":   ");
    dis_msg(last_cmdline, false);
  }

  // display current file name
  if (curbuf->b_fname != NULL
      && (arg == NULL || vim_strchr(arg, '%') != NULL) && !got_int
      && !message_filtered(curbuf->b_fname)) {
    msg_puts("\n  c  \"%   ");
    dis_msg(curbuf->b_fname, false);
  }

  // display alternate file name
  if ((arg == NULL || vim_strchr(arg, '%') != NULL) && !got_int) {
    char *fname;
    linenr_T dummy;

    if (buflist_name_nr(0, &fname, &dummy) != FAIL && !message_filtered(fname)) {
      msg_puts("\n  c  \"#   ");
      dis_msg(fname, false);
    }
  }

  // display last search pattern
  if (last_search_pat() != NULL
      && (arg == NULL || vim_strchr(arg, '/') != NULL) && !got_int
      && !message_filtered(last_search_pat())) {
    msg_puts("\n  c  \"/   ");
    dis_msg(last_search_pat(), false);
  }

  // display last used expression
  if (expr_line != NULL && (arg == NULL || vim_strchr(arg, '=') != NULL)
      && !got_int && !message_filtered(expr_line)) {
    msg_puts("\n  c  \"=   ");
    dis_msg(expr_line, false);
  }
}

/// display a string for do_dis()
/// truncate at end of screen line
///
/// @param skip_esc  if true, ignore trailing ESC
static void dis_msg(const char *p, bool skip_esc)
  FUNC_ATTR_NONNULL_ALL
{
  int n = Columns - 6;
  while (*p != NUL
         && !(*p == ESC && skip_esc && *(p + 1) == NUL)
         && (n -= ptr2cells(p)) >= 0) {
    int l;
    if ((l = utfc_ptr2len(p)) > 1) {
      msg_outtrans_len(p, l, 0);
      p += l;
    } else {
      msg_outtrans_len(p++, 1, 0);
    }
  }
  os_breakcheck();
}

/// If \p "process" is true and the line begins with a comment leader (possibly
/// after some white space), return a pointer to the text after it.
/// Put a boolean value indicating whether the line ends with an unclosed
/// comment in "is_comment".
///
/// @param line - line to be processed
/// @param process - if false, will only check whether the line ends
///         with an unclosed comment,
/// @param include_space - whether to skip space following the comment leader
/// @param[out] is_comment - whether the current line ends with an unclosed
///  comment.
char *skip_comment(char *line, bool process, bool include_space, bool *is_comment)
{
  char *comment_flags = NULL;
  int leader_offset = get_last_leader_offset(line, &comment_flags);

  *is_comment = false;
  if (leader_offset != -1) {
    // Let's check whether the line ends with an unclosed comment.
    // If the last comment leader has COM_END in flags, there's no comment.
    while (*comment_flags) {
      if (*comment_flags == COM_END
          || *comment_flags == ':') {
        break;
      }
      comment_flags++;
    }
    if (*comment_flags != COM_END) {
      *is_comment = true;
    }
  }

  if (process == false) {
    return line;
  }

  int lead_len = get_leader_len(line, &comment_flags, false, include_space);

  if (lead_len == 0) {
    return line;
  }

  // Find:
  // - COM_END,
  // - colon,
  // whichever comes first.
  while (*comment_flags) {
    if (*comment_flags == COM_END
        || *comment_flags == ':') {
      break;
    }
    comment_flags++;
  }

  // If we found a colon, it means that we are not processing a line
  // starting with a closing part of a three-part comment. That's good,
  // because we don't want to remove those as this would be annoying.
  if (*comment_flags == ':' || *comment_flags == NUL) {
    line += lead_len;
  }

  return line;
}

/// @param count              number of lines (minimal 2) to join at cursor position.
/// @param save_undo          when true, save lines for undo first.
/// @param use_formatoptions  set to false when e.g. processing backspace and comment
///                           leaders should not be removed.
/// @param setmark            when true, sets the '[ and '] mark, else, the caller is expected
///                           to set those marks.
///
/// @return  FAIL for failure, OK otherwise
int do_join(size_t count, bool insert_space, bool save_undo, bool use_formatoptions, bool setmark)
{
  char *curr = NULL;
  char *curr_start = NULL;
  char *cend;
  int endcurr1 = NUL;
  int endcurr2 = NUL;
  int currsize = 0;             // size of the current line
  int sumsize = 0;              // size of the long new line
  int ret = OK;
  int *comments = NULL;
  bool remove_comments = use_formatoptions && has_format_option(FO_REMOVE_COMS);
  bool prev_was_comment = false;
  assert(count >= 1);

  if (save_undo && u_save(curwin->w_cursor.lnum - 1,
                          curwin->w_cursor.lnum + (linenr_T)count) == FAIL) {
    return FAIL;
  }
  // Allocate an array to store the number of spaces inserted before each
  // line.  We will use it to pre-compute the length of the new line and the
  // proper placement of each original line in the new one.
  char *spaces = xcalloc(count, 1);  // number of spaces inserted before a line
  if (remove_comments) {
    comments = xcalloc(count, sizeof(*comments));
  }

  // Don't move anything yet, just compute the final line length
  // and setup the array of space strings lengths
  // This loops forward over joined lines.
  for (linenr_T t = 0; t < (linenr_T)count; t++) {
    curr_start = ml_get(curwin->w_cursor.lnum + t);
    curr = curr_start;
    if (t == 0 && setmark && (cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
      // Set the '[ mark.
      curwin->w_buffer->b_op_start.lnum = curwin->w_cursor.lnum;
      curwin->w_buffer->b_op_start.col = (colnr_T)strlen(curr);
    }
    if (remove_comments) {
      // We don't want to remove the comment leader if the
      // previous line is not a comment.
      if (t > 0 && prev_was_comment) {
        char *new_curr = skip_comment(curr, true, insert_space, &prev_was_comment);
        comments[t] = (int)(new_curr - curr);
        curr = new_curr;
      } else {
        curr = skip_comment(curr, false, insert_space, &prev_was_comment);
      }
    }

    if (insert_space && t > 0) {
      curr = skipwhite(curr);
      if (*curr != NUL
          && *curr != ')'
          && sumsize != 0
          && endcurr1 != TAB
          && (!has_format_option(FO_MBYTE_JOIN)
              || (utf_ptr2char(curr) < 0x100 && endcurr1 < 0x100))
          && (!has_format_option(FO_MBYTE_JOIN2)
              || (utf_ptr2char(curr) < 0x100 && !utf_eat_space(endcurr1))
              || (endcurr1 < 0x100
                  && !utf_eat_space(utf_ptr2char(curr))))) {
        // don't add a space if the line is ending in a space
        if (endcurr1 == ' ') {
          endcurr1 = endcurr2;
        } else {
          spaces[t]++;
        }
        // Extra space when 'joinspaces' set and line ends in '.', '?', or '!'.
        if (p_js && (endcurr1 == '.' || endcurr1 == '?' || endcurr1 == '!')) {
          spaces[t]++;
        }
      }
    }

    if (t > 0 && curbuf_splice_pending == 0) {
      colnr_T removed = (int)(curr - curr_start);
      extmark_splice(curbuf, (int)curwin->w_cursor.lnum - 1, sumsize,
                     1, removed, removed + 1,
                     0, spaces[t], spaces[t],
                     kExtmarkUndo);
    }
    currsize = (int)strlen(curr);
    sumsize += currsize + spaces[t];
    endcurr1 = endcurr2 = NUL;
    if (insert_space && currsize > 0) {
      cend = curr + currsize;
      MB_PTR_BACK(curr, cend);
      endcurr1 = utf_ptr2char(cend);
      if (cend > curr) {
        MB_PTR_BACK(curr, cend);
        endcurr2 = utf_ptr2char(cend);
      }
    }
    line_breakcheck();
    if (got_int) {
      ret = FAIL;
      goto theend;
    }
  }

  // store the column position before last line
  colnr_T col = sumsize - currsize - spaces[count - 1];

  // allocate the space for the new line
  char *newp = xmalloc((size_t)sumsize + 1);
  cend = newp + sumsize;
  *cend = 0;

  // Move affected lines to the new long one.
  // This loops backwards over the joined lines, including the original line.
  //
  // Move marks from each deleted line to the joined line, adjusting the
  // column.  This is not Vi compatible, but Vi deletes the marks, thus that
  // should not really be a problem.

  curbuf_splice_pending++;

  for (linenr_T t = (linenr_T)count - 1;; t--) {
    cend -= currsize;
    memmove(cend, curr, (size_t)currsize);
    if (spaces[t] > 0) {
      cend -= spaces[t];
      memset(cend, ' ', (size_t)(spaces[t]));
    }

    // If deleting more spaces than adding, the cursor moves no more than
    // what is added if it is inside these spaces.
    const int spaces_removed = (int)((curr - curr_start) - spaces[t]);
    linenr_T lnum = curwin->w_cursor.lnum + t;
    colnr_T mincol = 0;
    linenr_T lnum_amount = -t;
    colnr_T col_amount = (colnr_T)(cend - newp - spaces_removed);

    mark_col_adjust(lnum, mincol, lnum_amount, col_amount, spaces_removed);

    if (t == 0) {
      break;
    }

    curr_start = ml_get((linenr_T)(curwin->w_cursor.lnum + t - 1));
    curr = curr_start;
    if (remove_comments) {
      curr += comments[t - 1];
    }
    if (insert_space && t > 1) {
      curr = skipwhite(curr);
    }
    currsize = (int)strlen(curr);
  }

  ml_replace(curwin->w_cursor.lnum, newp, false);

  if (setmark && (cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
    // Set the '] mark.
    curwin->w_buffer->b_op_end.lnum = curwin->w_cursor.lnum;
    curwin->w_buffer->b_op_end.col = sumsize;
  }

  // Only report the change in the first line here, del_lines() will report
  // the deleted line.
  changed_lines(curbuf, curwin->w_cursor.lnum, currsize,
                curwin->w_cursor.lnum + 1, 0, true);

  // Delete following lines. To do this we move the cursor there
  // briefly, and then move it back. After del_lines() the cursor may
  // have moved up (last line deleted), so the current lnum is kept in t.
  linenr_T t = curwin->w_cursor.lnum;
  curwin->w_cursor.lnum++;
  del_lines((int)count - 1, false);
  curwin->w_cursor.lnum = t;
  curbuf_splice_pending--;
  curbuf->deleted_bytes2 = 0;

  // Set the cursor column:
  // Vi compatible: use the column of the first join
  // vim:             use the column of the last join
  curwin->w_cursor.col =
    (vim_strchr(p_cpo, CPO_JOINCOL) != NULL ? currsize : col);
  check_cursor_col(curwin);

  curwin->w_cursor.coladd = 0;
  curwin->w_set_curswant = true;

theend:
  xfree(spaces);
  if (remove_comments) {
    xfree(comments);
  }
  return ret;
}

/// Reset 'linebreak' and take care of side effects.
/// @return  the previous value, to be passed to restore_lbr().
static bool reset_lbr(void)
{
  if (!curwin->w_p_lbr) {
    return false;
  }
  // changing 'linebreak' may require w_virtcol to be updated
  curwin->w_p_lbr = false;
  curwin->w_valid &= ~(VALID_WROW|VALID_WCOL|VALID_VIRTCOL);
  return true;
}

/// Restore 'linebreak' and take care of side effects.
static void restore_lbr(bool lbr_saved)
{
  if (curwin->w_p_lbr || !lbr_saved) {
    return;
  }

  // changing 'linebreak' may require w_virtcol to be updated
  curwin->w_p_lbr = true;
  curwin->w_valid &= ~(VALID_WROW|VALID_WCOL|VALID_VIRTCOL);
}

/// prepare a few things for block mode yank/delete/tilde
///
/// for delete:
/// - textlen includes the first/last char to be (partly) deleted
/// - start/endspaces is the number of columns that are taken by the
///   first/last deleted char minus the number of columns that have to be
///   deleted.
/// for yank and tilde:
/// - textlen includes the first/last char to be wholly yanked
/// - start/endspaces is the number of columns of the first/last yanked char
///   that are to be yanked.
void block_prep(oparg_T *oap, struct block_def *bdp, linenr_T lnum, bool is_del)
{
  int incr = 0;
  // Avoid a problem with unwanted linebreaks in block mode.
  const bool lbr_saved = reset_lbr();

  bdp->startspaces = 0;
  bdp->endspaces = 0;
  bdp->textlen = 0;
  bdp->start_vcol = 0;
  bdp->end_vcol = 0;
  bdp->is_short = false;
  bdp->is_oneChar = false;
  bdp->pre_whitesp = 0;
  bdp->pre_whitesp_c = 0;
  bdp->end_char_vcols = 0;
  bdp->start_char_vcols = 0;

  char *line = ml_get(lnum);
  char *prev_pstart = line;

  CharsizeArg csarg;
  CSType cstype = init_charsize_arg(&csarg, curwin, lnum, line);
  StrCharInfo ci = utf_ptr2StrCharInfo(line);
  int vcol = bdp->start_vcol;
  while (vcol < oap->start_vcol && *ci.ptr != NUL) {
    incr = win_charsize(cstype, vcol, ci.ptr, ci.chr.value, &csarg).width;
    vcol += incr;
    if (ascii_iswhite(ci.chr.value)) {
      bdp->pre_whitesp += incr;
      bdp->pre_whitesp_c++;
    } else {
      bdp->pre_whitesp = 0;
      bdp->pre_whitesp_c = 0;
    }
    prev_pstart = ci.ptr;
    ci = utfc_next(ci);
  }
  bdp->start_vcol = vcol;
  char *pstart = ci.ptr;

  bdp->start_char_vcols = incr;
  if (bdp->start_vcol < oap->start_vcol) {      // line too short
    bdp->end_vcol = bdp->start_vcol;
    bdp->is_short = true;
    if (!is_del || oap->op_type == OP_APPEND) {
      bdp->endspaces = oap->end_vcol - oap->start_vcol + 1;
    }
  } else {
    // notice: this converts partly selected Multibyte characters to
    // spaces, too.
    bdp->startspaces = bdp->start_vcol - oap->start_vcol;
    if (is_del && bdp->startspaces) {
      bdp->startspaces = bdp->start_char_vcols - bdp->startspaces;
    }
    char *pend = pstart;
    bdp->end_vcol = bdp->start_vcol;
    if (bdp->end_vcol > oap->end_vcol) {  // it's all in one character
      bdp->is_oneChar = true;
      if (oap->op_type == OP_INSERT) {
        bdp->endspaces = bdp->start_char_vcols - bdp->startspaces;
      } else if (oap->op_type == OP_APPEND) {
        bdp->startspaces += oap->end_vcol - oap->start_vcol + 1;
        bdp->endspaces = bdp->start_char_vcols - bdp->startspaces;
      } else {
        bdp->startspaces = oap->end_vcol - oap->start_vcol + 1;
        if (is_del && oap->op_type != OP_LSHIFT) {
          // just putting the sum of those two into
          // bdp->startspaces doesn't work for Visual replace,
          // so we have to split the tab in two
          bdp->startspaces = bdp->start_char_vcols
                             - (bdp->start_vcol - oap->start_vcol);
          bdp->endspaces = bdp->end_vcol - oap->end_vcol - 1;
        }
      }
    } else {
      cstype = init_charsize_arg(&csarg, curwin, lnum, line);
      ci = utf_ptr2StrCharInfo(pend);
      vcol = bdp->end_vcol;
      char *prev_pend = pend;
      while (vcol <= oap->end_vcol && *ci.ptr != NUL) {
        prev_pend = ci.ptr;
        incr = win_charsize(cstype, vcol, ci.ptr, ci.chr.value, &csarg).width;
        vcol += incr;
        ci = utfc_next(ci);
      }
      bdp->end_vcol = vcol;
      pend = ci.ptr;

      if (bdp->end_vcol <= oap->end_vcol
          && (!is_del
              || oap->op_type == OP_APPEND
              || oap->op_type == OP_REPLACE)) {  // line too short
        bdp->is_short = true;
        // Alternative: include spaces to fill up the block.
        // Disadvantage: can lead to trailing spaces when the line is
        // short where the text is put
        // if (!is_del || oap->op_type == OP_APPEND)
        if (oap->op_type == OP_APPEND || virtual_op) {
          bdp->endspaces = oap->end_vcol - bdp->end_vcol
                           + oap->inclusive;
        }
      } else if (bdp->end_vcol > oap->end_vcol) {
        bdp->endspaces = bdp->end_vcol - oap->end_vcol - 1;
        if (!is_del && bdp->endspaces) {
          bdp->endspaces = incr - bdp->endspaces;
          if (pend != pstart) {
            pend = prev_pend;
          }
        }
      }
    }
    bdp->end_char_vcols = incr;
    if (is_del && bdp->startspaces) {
      pstart = prev_pstart;
    }
    bdp->textlen = (int)(pend - pstart);
  }
  bdp->textcol = (colnr_T)(pstart - line);
  bdp->textstart = pstart;
  restore_lbr(lbr_saved);
}

/// Get block text from "start" to "end"
void charwise_block_prep(pos_T start, pos_T end, struct block_def *bdp, linenr_T lnum,
                         bool inclusive)
{
  colnr_T startcol = 0;
  colnr_T endcol = MAXCOL;
  colnr_T cs, ce;
  char *p = ml_get(lnum);

  bdp->startspaces = 0;
  bdp->endspaces = 0;
  bdp->is_oneChar = false;
  bdp->start_char_vcols = 0;

  if (lnum == start.lnum) {
    startcol = start.col;
    if (virtual_op) {
      getvcol(curwin, &start, &cs, NULL, &ce);
      if (ce != cs && start.coladd > 0) {
        // Part of a tab selected -- but don't double-count it.
        bdp->start_char_vcols = ce - cs + 1;
        bdp->startspaces = bdp->start_char_vcols - start.coladd;
        if (bdp->startspaces < 0) {
          bdp->startspaces = 0;
        }
        startcol++;
      }
    }
  }

  if (lnum == end.lnum) {
    endcol = end.col;
    if (virtual_op) {
      getvcol(curwin, &end, &cs, NULL, &ce);
      if (p[endcol] == NUL || (cs + end.coladd < ce
                               // Don't add space for double-wide
                               // char; endcol will be on last byte
                               // of multi-byte char.
                               && utf_head_off(p, p + endcol) == 0)) {
        if (start.lnum == end.lnum && start.col == end.col) {
          // Special case: inside a single char
          bdp->is_oneChar = true;
          bdp->startspaces = end.coladd - start.coladd + inclusive;
          endcol = startcol;
        } else {
          bdp->endspaces = end.coladd + inclusive;
          endcol -= inclusive;
        }
      }
    }
  }
  if (endcol == MAXCOL) {
    endcol = ml_get_len(lnum);
  }
  if (startcol > endcol || bdp->is_oneChar) {
    bdp->textlen = 0;
  } else {
    bdp->textlen = endcol - startcol + inclusive;
  }
  bdp->textcol = startcol;
  bdp->textstart = p + startcol;
}

/// Handle the add/subtract operator.
///
/// @param[in]  oap      Arguments of operator.
/// @param[in]  Prenum1  Amount of addition or subtraction.
/// @param[in]  g_cmd    Prefixed with `g`.
void op_addsub(oparg_T *oap, linenr_T Prenum1, bool g_cmd)
{
  struct block_def bd;
  ssize_t change_cnt = 0;
  linenr_T amount = Prenum1;

  // do_addsub() might trigger re-evaluation of 'foldexpr' halfway, when the
  // buffer is not completely updated yet. Postpone updating folds until before
  // the call to changed_lines().
  disable_fold_update++;

  if (!VIsual_active) {
    pos_T pos = curwin->w_cursor;
    if (u_save_cursor() == FAIL) {
      disable_fold_update--;
      return;
    }
    change_cnt = do_addsub(oap->op_type, &pos, 0, amount);
    disable_fold_update--;
    if (change_cnt) {
      changed_lines(curbuf, pos.lnum, 0, pos.lnum + 1, 0, true);
    }
  } else {
    int length;
    pos_T startpos;

    if (u_save((linenr_T)(oap->start.lnum - 1),
               (linenr_T)(oap->end.lnum + 1)) == FAIL) {
      disable_fold_update--;
      return;
    }

    pos_T pos = oap->start;
    for (; pos.lnum <= oap->end.lnum; pos.lnum++) {
      if (oap->motion_type == kMTBlockWise) {
        // Visual block mode
        block_prep(oap, &bd, pos.lnum, false);
        pos.col = bd.textcol;
        length = bd.textlen;
      } else if (oap->motion_type == kMTLineWise) {
        curwin->w_cursor.col = 0;
        pos.col = 0;
        length = ml_get_len(pos.lnum);
      } else {
        // oap->motion_type == kMTCharWise
        if (pos.lnum == oap->start.lnum && !oap->inclusive) {
          dec(&(oap->end));
        }
        length = ml_get_len(pos.lnum);
        pos.col = 0;
        if (pos.lnum == oap->start.lnum) {
          pos.col += oap->start.col;
          length -= oap->start.col;
        }
        if (pos.lnum == oap->end.lnum) {
          length = ml_get_len(oap->end.lnum);
          if (oap->end.col >= length) {
            oap->end.col = length - 1;
          }
          length = oap->end.col - pos.col + 1;
        }
      }
      bool one_change = do_addsub(oap->op_type, &pos, length, amount);
      if (one_change) {
        // Remember the start position of the first change.
        if (change_cnt == 0) {
          startpos = curbuf->b_op_start;
        }
        change_cnt++;
      }

      if (g_cmd && one_change) {
        amount += Prenum1;
      }
    }

    disable_fold_update--;
    if (change_cnt) {
      changed_lines(curbuf, oap->start.lnum, 0, oap->end.lnum + 1, 0, true);
    }

    if (!change_cnt && oap->is_VIsual) {
      // No change: need to remove the Visual selection
      redraw_curbuf_later(UPD_INVERTED);
    }

    // Set '[ mark if something changed. Keep the last end
    // position from do_addsub().
    if (change_cnt > 0 && (cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
      curbuf->b_op_start = startpos;
    }

    if (change_cnt > p_report) {
      smsg(0, NGETTEXT("%" PRId64 " lines changed", "%" PRId64 " lines changed", change_cnt),
           (int64_t)change_cnt);
    }
  }
}

/// Add or subtract from a number in a line.
///
/// @param op_type OP_NR_ADD or OP_NR_SUB.
/// @param pos     Cursor position.
/// @param length  Target number length.
/// @param Prenum1 Amount of addition or subtraction.
///
/// @return true if some character was changed.
bool do_addsub(int op_type, pos_T *pos, int length, linenr_T Prenum1)
{
  char *buf1 = NULL;
  char buf2[NUMBUFLEN];
  int pre;  // 'X' or 'x': hex; '0': octal; 'B' or 'b': bin
  static bool hexupper = false;  // 0xABC
  uvarnumber_T n;
  bool blank_unsigned = false;  // blank: treat as unsigned?
  bool negative = false;
  bool was_positive = true;
  bool visual = VIsual_active;
  bool did_change = false;
  pos_T save_cursor = curwin->w_cursor;
  int maxlen = 0;
  pos_T startpos;
  pos_T endpos;
  colnr_T save_coladd = 0;

  const bool do_hex = vim_strchr(curbuf->b_p_nf, 'x') != NULL;       // "heX"
  const bool do_oct = vim_strchr(curbuf->b_p_nf, 'o') != NULL;       // "Octal"
  const bool do_bin = vim_strchr(curbuf->b_p_nf, 'b') != NULL;       // "Bin"
  const bool do_alpha = vim_strchr(curbuf->b_p_nf, 'p') != NULL;     // "alPha"
  const bool do_unsigned = vim_strchr(curbuf->b_p_nf, 'u') != NULL;  // "Unsigned"
  const bool do_blank = vim_strchr(curbuf->b_p_nf, 'k') != NULL;     // "blanK"

  if (virtual_active(curwin)) {
    save_coladd = pos->coladd;
    pos->coladd = 0;
  }

  curwin->w_cursor = *pos;
  char *ptr = ml_get(pos->lnum);
  int linelen = ml_get_len(pos->lnum);
  int col = pos->col;

  if (col + !!save_coladd >= linelen) {
    goto theend;
  }

  // First check if we are on a hexadecimal number, after the "0x".
  if (!VIsual_active) {
    if (do_bin) {
      while (col > 0 && ascii_isbdigit(ptr[col])) {
        col--;
        col -= utf_head_off(ptr, ptr + col);
      }
    }

    if (do_hex) {
      while (col > 0 && ascii_isxdigit(ptr[col])) {
        col--;
        col -= utf_head_off(ptr, ptr + col);
      }
    }
    if (do_bin
        && do_hex
        && !((col > 0
              && (ptr[col] == 'X' || ptr[col] == 'x')
              && ptr[col - 1] == '0'
              && !utf_head_off(ptr, ptr + col - 1)
              && ascii_isxdigit(ptr[col + 1])))) {
      // In case of binary/hexadecimal pattern overlap match, rescan

      col = curwin->w_cursor.col;

      while (col > 0 && ascii_isdigit(ptr[col])) {
        col--;
        col -= utf_head_off(ptr, ptr + col);
      }
    }

    if ((do_hex
         && col > 0
         && (ptr[col] == 'X' || ptr[col] == 'x')
         && ptr[col - 1] == '0'
         && !utf_head_off(ptr, ptr + col - 1)
         && ascii_isxdigit(ptr[col + 1]))
        || (do_bin
            && col > 0
            && (ptr[col] == 'B' || ptr[col] == 'b')
            && ptr[col - 1] == '0'
            && !utf_head_off(ptr, ptr + col - 1)
            && ascii_isbdigit(ptr[col + 1]))) {
      // Found hexadecimal or binary number, move to its start.
      col--;
      col -= utf_head_off(ptr, ptr + col);
    } else {
      // Search forward and then backward to find the start of number.
      col = pos->col;

      while (ptr[col] != NUL
             && !ascii_isdigit(ptr[col])
             && !(do_alpha && ASCII_ISALPHA(ptr[col]))) {
        col++;
      }

      while (col > 0
             && ascii_isdigit(ptr[col - 1])
             && !(do_alpha && ASCII_ISALPHA(ptr[col]))) {
        col--;
      }
    }
  }

  if (visual) {
    while (ptr[col] != NUL && length > 0 && !ascii_isdigit(ptr[col])
           && !(do_alpha && ASCII_ISALPHA(ptr[col]))) {
      int mb_len = utfc_ptr2len(ptr + col);

      col += mb_len;
      length -= mb_len;
    }

    if (length == 0) {
      goto theend;
    }

    if (col > pos->col && ptr[col - 1] == '-'
        && !utf_head_off(ptr, ptr + col - 1)
        && !do_unsigned) {
      if (do_blank && col >= 2 && !ascii_iswhite(ptr[col - 2])) {
        blank_unsigned = true;
      } else {
        negative = true;
        was_positive = false;
      }
    }
  }

  // If a number was found, and saving for undo works, replace the number.
  int firstdigit = (uint8_t)ptr[col];
  if (!ascii_isdigit(firstdigit) && !(do_alpha && ASCII_ISALPHA(firstdigit))) {
    beep_flush();
    goto theend;
  }

  if (do_alpha && ASCII_ISALPHA(firstdigit)) {
    // decrement or increment alphabetic character
    if (op_type == OP_NR_SUB) {
      if (CHAR_ORD(firstdigit) < Prenum1) {
        if (isupper(firstdigit)) {
          firstdigit = 'A';
        } else {
          firstdigit = 'a';
        }
      } else {
        firstdigit -= (int)Prenum1;
      }
    } else {
      if (26 - CHAR_ORD(firstdigit) - 1 < Prenum1) {
        if (isupper(firstdigit)) {
          firstdigit = 'Z';
        } else {
          firstdigit = 'z';
        }
      } else {
        firstdigit += (int)Prenum1;
      }
    }
    curwin->w_cursor.col = col;
    startpos = curwin->w_cursor;
    did_change = true;
    del_char(false);
    ins_char(firstdigit);
    endpos = curwin->w_cursor;
    curwin->w_cursor.col = col;
  } else {
    if (col > 0 && ptr[col - 1] == '-'
        && !utf_head_off(ptr, ptr + col - 1)
        && !visual
        && !do_unsigned) {
      if (do_blank && col >= 2 && !ascii_iswhite(ptr[col - 2])) {
        blank_unsigned = true;
      } else {
        // negative number
        col--;
        negative = true;
      }
    }

    // get the number value (unsigned)
    if (visual && VIsual_mode != 'V') {
      maxlen = curbuf->b_visual.vi_curswant == MAXCOL ? linelen - col : length;
    }

    bool overflow = false;
    vim_str2nr(ptr + col, &pre, &length,
               0 + (do_bin ? STR2NR_BIN : 0)
               + (do_oct ? STR2NR_OCT : 0)
               + (do_hex ? STR2NR_HEX : 0),
               NULL, &n, maxlen, false, &overflow);

    // ignore leading '-' for hex, octal and bin numbers
    if (pre && negative) {
      col++;
      length--;
      negative = false;
    }

    // add or subtract
    bool subtract = false;
    if (op_type == OP_NR_SUB) {
      subtract ^= true;
    }
    if (negative) {
      subtract ^= true;
    }

    uvarnumber_T oldn = n;

    if (!overflow) {  // if number is too big don't add/subtract
      n = subtract ? n - (uvarnumber_T)Prenum1
                   : n + (uvarnumber_T)Prenum1;
    }

    // handle wraparound for decimal numbers
    if (!pre) {
      if (subtract) {
        if (n > oldn) {
          n = 1 + (n ^ (uvarnumber_T)(-1));
          negative ^= true;
        }
      } else {
        // add
        if (n < oldn) {
          n = (n ^ (uvarnumber_T)(-1));
          negative ^= true;
        }
      }
      if (n == 0) {
        negative = false;
      }
    }

    if ((do_unsigned || blank_unsigned) && negative) {
      if (subtract) {
        // sticking at zero.
        n = 0;
      } else {
        // sticking at 2^64 - 1.
        n = (uvarnumber_T)(-1);
      }
      negative = false;
    }

    if (visual && !was_positive && !negative && col > 0) {
      // need to remove the '-'
      col--;
      length++;
    }

    // Delete the old number.
    curwin->w_cursor.col = col;
    startpos = curwin->w_cursor;
    did_change = true;
    int todel = length;
    int c = gchar_cursor();

    // Don't include the '-' in the length, only the length of the part
    // after it is kept the same.
    if (c == '-') {
      length--;
    }
    while (todel-- > 0) {
      if (c < 0x100 && isalpha(c)) {
        if (isupper(c)) {
          hexupper = true;
        } else {
          hexupper = false;
        }
      }
      // del_char() will mark line needing displaying
      del_char(false);
      c = gchar_cursor();
    }

    // Prepare the leading characters in buf1[].
    // When there are many leading zeros it could be very long.
    // Allocate a bit too much.
    buf1 = xmalloc((size_t)length + NUMBUFLEN);
    ptr = buf1;
    if (negative && (!visual || was_positive)) {
      *ptr++ = '-';
    }
    if (pre) {
      *ptr++ = '0';
      length--;
    }
    if (pre == 'b' || pre == 'B' || pre == 'x' || pre == 'X') {
      *ptr++ = (char)pre;
      length--;
    }

    // Put the number characters in buf2[].
    if (pre == 'b' || pre == 'B') {
      size_t bits = 0;
      size_t i = 0;

      // leading zeros
      for (bits = 8 * sizeof(n); bits > 0; bits--) {
        if ((n >> (bits - 1)) & 0x1) {
          break;
        }
      }

      while (bits > 0 && i < NUMBUFLEN - 1) {
        buf2[i++] = ((n >> --bits) & 0x1) ? '1' : '0';
      }

      buf2[i] = NUL;
    } else if (pre == 0) {
      vim_snprintf(buf2, ARRAY_SIZE(buf2), "%" PRIu64, (uint64_t)n);
    } else if (pre == '0') {
      vim_snprintf(buf2, ARRAY_SIZE(buf2), "%" PRIo64, (uint64_t)n);
    } else if (hexupper) {
      vim_snprintf(buf2, ARRAY_SIZE(buf2), "%" PRIX64, (uint64_t)n);
    } else {
      vim_snprintf(buf2, ARRAY_SIZE(buf2), "%" PRIx64, (uint64_t)n);
    }
    length -= (int)strlen(buf2);

    // Adjust number of zeros to the new number of digits, so the
    // total length of the number remains the same.
    // Don't do this when
    // the result may look like an octal number.
    if (firstdigit == '0' && !(do_oct && pre == 0)) {
      while (length-- > 0) {
        *ptr++ = '0';
      }
    }
    *ptr = NUL;
    strcat(buf1, buf2);
    ins_str(buf1);              // insert the new number
    endpos = curwin->w_cursor;
    if (curwin->w_cursor.col) {
      curwin->w_cursor.col--;
    }
  }

  if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
    // set the '[ and '] marks
    curbuf->b_op_start = startpos;
    curbuf->b_op_end = endpos;
    if (curbuf->b_op_end.col > 0) {
      curbuf->b_op_end.col--;
    }
  }

theend:
  xfree(buf1);
  if (visual) {
    curwin->w_cursor = save_cursor;
  } else if (did_change) {
    curwin->w_set_curswant = true;
  } else if (virtual_active(curwin)) {
    curwin->w_cursor.coladd = save_coladd;
  }

  return did_change;
}

/// Used for getregtype()
///
/// @return  the type of a register or
///          kMTUnknown for error.
MotionType get_reg_type(int regname, colnr_T *reg_width)
{
  switch (regname) {
  case '%':     // file name
  case '#':     // alternate file name
  case '=':     // expression
  case ':':     // last command line
  case '/':     // last search-pattern
  case '.':     // last inserted text
  case Ctrl_F:  // Filename under cursor
  case Ctrl_P:  // Path under cursor, expand via "path"
  case Ctrl_W:  // word under cursor
  case Ctrl_A:  // WORD (mnemonic All) under cursor
  case '_':     // black hole: always empty
    return kMTCharWise;
  }

  if (regname != NUL && !valid_yank_reg(regname, false)) {
    return kMTUnknown;
  }

  yankreg_T *reg = get_yank_register(regname, YREG_PASTE);

  if (reg->y_array != NULL) {
    if (reg_width != NULL && reg->y_type == kMTBlockWise) {
      *reg_width = reg->y_width;
    }
    return reg->y_type;
  }
  return kMTUnknown;
}

/// Format the register type as a string.
///
/// @param reg_type The register type.
/// @param reg_width The width, only used if "reg_type" is kMTBlockWise.
/// @param[out] buf Buffer to store formatted string. The allocated size should
///                 be at least NUMBUFLEN+2 to always fit the value.
/// @param buf_len The allocated size of the buffer.
void format_reg_type(MotionType reg_type, colnr_T reg_width, char *buf, size_t buf_len)
  FUNC_ATTR_NONNULL_ALL
{
  assert(buf_len > 1);
  switch (reg_type) {
  case kMTLineWise:
    buf[0] = 'V';
    buf[1] = NUL;
    break;
  case kMTCharWise:
    buf[0] = 'v';
    buf[1] = NUL;
    break;
  case kMTBlockWise:
    snprintf(buf, buf_len, CTRL_V_STR "%" PRIdCOLNR, reg_width + 1);
    break;
  case kMTUnknown:
    buf[0] = NUL;
    break;
  }
}

/// When `flags` has `kGRegList` return a list with text `s`.
/// Otherwise just return `s`.
///
/// @return  a void * for use in get_reg_contents().
static void *get_reg_wrap_one_line(char *s, int flags)
{
  if (!(flags & kGRegList)) {
    return s;
  }
  list_T *const list = tv_list_alloc(1);
  tv_list_append_allocated_string(list, s);
  return list;
}

/// Gets the contents of a register.
/// @remark Used for `@r` in expressions and for `getreg()`.
///
/// @param regname  The register.
/// @param flags    see @ref GRegFlags
///
/// @returns The contents of the register as an allocated string.
/// @returns A linked list when `flags` contains @ref kGRegList.
/// @returns NULL for error.
void *get_reg_contents(int regname, int flags)
{
  // Don't allow using an expression register inside an expression.
  if (regname == '=') {
    if (flags & kGRegNoExpr) {
      return NULL;
    }
    if (flags & kGRegExprSrc) {
      return get_reg_wrap_one_line(get_expr_line_src(), flags);
    }
    return get_reg_wrap_one_line(get_expr_line(), flags);
  }

  if (regname == '@') {     // "@@" is used for unnamed register
    regname = '"';
  }

  // check for valid regname
  if (regname != NUL && !valid_yank_reg(regname, false)) {
    return NULL;
  }

  char *retval;
  bool allocated;
  if (get_spec_reg(regname, &retval, &allocated, false)) {
    if (retval == NULL) {
      return NULL;
    }
    if (allocated) {
      return get_reg_wrap_one_line(retval, flags);
    }
    return get_reg_wrap_one_line(xstrdup(retval), flags);
  }

  yankreg_T *reg = get_yank_register(regname, YREG_PUT);
  if (reg->y_array == NULL) {
    return NULL;
  }

  if (flags & kGRegList) {
    list_T *const list = tv_list_alloc((ptrdiff_t)reg->y_size);
    for (size_t i = 0; i < reg->y_size; i++) {
      tv_list_append_string(list, reg->y_array[i], -1);
    }

    return list;
  }

  // Compute length of resulting string.
  size_t len = 0;
  for (size_t i = 0; i < reg->y_size; i++) {
    len += strlen(reg->y_array[i]);
    // Insert a newline between lines and after last line if
    // y_type is kMTLineWise.
    if (reg->y_type == kMTLineWise || i < reg->y_size - 1) {
      len++;
    }
  }

  retval = xmalloc(len + 1);

  // Copy the lines of the yank register into the string.
  len = 0;
  for (size_t i = 0; i < reg->y_size; i++) {
    STRCPY(retval + len, reg->y_array[i]);
    len += strlen(retval + len);

    // Insert a NL between lines and after the last line if y_type is
    // kMTLineWise.
    if (reg->y_type == kMTLineWise || i < reg->y_size - 1) {
      retval[len++] = '\n';
    }
  }
  retval[len] = NUL;

  return retval;
}

static yankreg_T *init_write_reg(int name, yankreg_T **old_y_previous, bool must_append)
{
  if (!valid_yank_reg(name, true)) {  // check for valid reg name
    emsg_invreg(name);
    return NULL;
  }

  // Don't want to change the current (unnamed) register.
  *old_y_previous = y_previous;

  yankreg_T *reg = get_yank_register(name, YREG_YANK);
  if (!is_append_register(name) && !must_append) {
    free_register(reg);
  }
  return reg;
}

static void finish_write_reg(int name, yankreg_T *reg, yankreg_T *old_y_previous)
{
  // Send text of clipboard register to the clipboard.
  set_clipboard(name, reg);

  // ':let @" = "val"' should change the meaning of the "" register
  if (name != '"') {
    y_previous = old_y_previous;
  }
}

/// store `str` in register `name`
///
/// @see write_reg_contents_ex
void write_reg_contents(int name, const char *str, ssize_t len, int must_append)
{
  write_reg_contents_ex(name, str, len, must_append, kMTUnknown, 0);
}

void write_reg_contents_lst(int name, char **strings, bool must_append, MotionType yank_type,
                            colnr_T block_len)
{
  if (name == '/' || name == '=') {
    char *s = strings[0];
    if (strings[0] == NULL) {
      s = "";
    } else if (strings[1] != NULL) {
      emsg(_(e_search_pattern_and_expression_register_may_not_contain_two_or_more_lines));
      return;
    }
    write_reg_contents_ex(name, s, -1, must_append, yank_type, block_len);
    return;
  }

  // black hole: nothing to do
  if (name == '_') {
    return;
  }

  yankreg_T *old_y_previous, *reg;
  if (!(reg = init_write_reg(name, &old_y_previous, must_append))) {
    return;
  }

  str_to_reg(reg, yank_type, (char *)strings, strlen((char *)strings),
             block_len, true);
  finish_write_reg(name, reg, old_y_previous);
}

/// write_reg_contents_ex - store `str` in register `name`
///
/// If `str` ends in '\n' or '\r', use linewise, otherwise use charwise.
///
/// @warning when `name` is '/', `len` and `must_append` are ignored. This
///          means that `str` MUST be NUL-terminated.
///
/// @param name The name of the register
/// @param str The contents to write
/// @param len If >= 0, write `len` bytes of `str`. Otherwise, write
///               `strlen(str)` bytes. If `len` is larger than the
///               allocated size of `src`, the behaviour is undefined.
/// @param must_append If true, append the contents of `str` to the current
///                    contents of the register. Note that regardless of
///                    `must_append`, this function will append when `name`
///                    is an uppercase letter.
/// @param yank_type The motion type (kMTUnknown to auto detect)
/// @param block_len width of visual block
void write_reg_contents_ex(int name, const char *str, ssize_t len, bool must_append,
                           MotionType yank_type, colnr_T block_len)
{
  if (len < 0) {
    len = (ssize_t)strlen(str);
  }

  // Special case: '/' search pattern
  if (name == '/') {
    set_last_search_pat(str, RE_SEARCH, true, true);
    return;
  }

  if (name == '#') {
    buf_T *buf;

    if (ascii_isdigit(*str)) {
      int num = atoi(str);

      buf = buflist_findnr(num);
      if (buf == NULL) {
        semsg(_(e_nobufnr), (int64_t)num);
      }
    } else {
      buf = buflist_findnr(buflist_findpat(str, str + strlen(str),
                                           true, false, false));
    }
    if (buf == NULL) {
      return;
    }
    curwin->w_alt_fnum = buf->b_fnum;
    return;
  }

  if (name == '=') {
    size_t offset = 0;
    size_t totlen = (size_t)len;

    if (must_append && expr_line) {
      // append has been specified and expr_line already exists, so we'll
      // append the new string to expr_line.
      size_t exprlen = strlen(expr_line);

      totlen += exprlen;
      offset = exprlen;
    }

    // modify the global expr_line, extend/shrink it if necessary (realloc).
    // Copy the input string into the adjusted memory at the specified
    // offset.
    expr_line = xrealloc(expr_line, totlen + 1);
    memcpy(expr_line + offset, str, (size_t)len);
    expr_line[totlen] = NUL;

    return;
  }

  if (name == '_') {        // black hole: nothing to do
    return;
  }

  yankreg_T *old_y_previous, *reg;
  if (!(reg = init_write_reg(name, &old_y_previous, must_append))) {
    return;
  }
  str_to_reg(reg, yank_type, str, (size_t)len, block_len, false);
  finish_write_reg(name, reg, old_y_previous);
}

/// str_to_reg - Put a string into a register.
///
/// When the register is not empty, the string is appended.
///
/// @param y_ptr pointer to yank register
/// @param yank_type The motion type (kMTUnknown to auto detect)
/// @param str string or list of strings to put in register
/// @param len length of the string (Ignored when str_list=true.)
/// @param blocklen width of visual block, or -1 for "I don't know."
/// @param str_list True if str is `char **`.
static void str_to_reg(yankreg_T *y_ptr, MotionType yank_type, const char *str, size_t len,
                       colnr_T blocklen, bool str_list)
  FUNC_ATTR_NONNULL_ALL
{
  if (y_ptr->y_array == NULL) {  // NULL means empty register
    y_ptr->y_size = 0;
  }

  if (yank_type == kMTUnknown) {
    yank_type = ((str_list
                  || (len > 0 && (str[len - 1] == NL || str[len - 1] == CAR)))
                 ? kMTLineWise : kMTCharWise);
  }

  size_t newlines = 0;
  bool extraline = false;  // extra line at the end
  bool append = false;     // append to last line in register

  // Count the number of lines within the string
  if (str_list) {
    for (char **ss = (char **)str; *ss != NULL; ss++) {
      newlines++;
    }
  } else {
    newlines = memcnt(str, '\n', len);
    if (yank_type == kMTCharWise || len == 0 || str[len - 1] != '\n') {
      extraline = 1;
      newlines++;         // count extra newline at the end
    }
    if (y_ptr->y_size > 0 && y_ptr->y_type == kMTCharWise) {
      append = true;
      newlines--;         // uncount newline when appending first line
    }
  }

  // Without any lines make the register empty.
  if (y_ptr->y_size + newlines == 0) {
    XFREE_CLEAR(y_ptr->y_array);
    return;
  }

  // Grow the register array to hold the pointers to the new lines.
  char **pp = xrealloc(y_ptr->y_array, (y_ptr->y_size + newlines) * sizeof(char *));
  y_ptr->y_array = pp;

  size_t lnum = y_ptr->y_size;  // The current line number.

  // If called with `blocklen < 0`, we have to update the yank reg's width.
  size_t maxlen = 0;

  // Find the end of each line and save it into the array.
  if (str_list) {
    for (char **ss = (char **)str; *ss != NULL; ss++, lnum++) {
      size_t ss_len = strlen(*ss);
      pp[lnum] = xmemdupz(*ss, ss_len);
      if (ss_len > maxlen) {
        maxlen = ss_len;
      }
    }
  } else {
    size_t line_len;
    for (const char *start = str, *end = str + len;
         start < end + extraline;
         start += line_len + 1, lnum++) {
      assert(end - start >= 0);
      line_len = (size_t)((char *)xmemscan(start, '\n', (size_t)(end - start)) - start);
      if (line_len > maxlen) {
        maxlen = line_len;
      }

      // When appending, copy the previous line and free it after.
      size_t extra = append ? strlen(pp[--lnum]) : 0;
      char *s = xmallocz(line_len + extra);
      if (extra > 0) {
        memcpy(s, pp[lnum], extra);
      }
      memcpy(s + extra, start, line_len);
      size_t s_len = extra + line_len;

      if (append) {
        xfree(pp[lnum]);
        append = false;  // only first line is appended
      }
      pp[lnum] = s;

      // Convert NULs to '\n' to prevent truncation.
      memchrsub(pp[lnum], NUL, '\n', s_len);
    }
  }
  y_ptr->y_type = yank_type;
  y_ptr->y_size = lnum;
  set_yreg_additional_data(y_ptr, NULL);
  y_ptr->timestamp = os_time();
  if (yank_type == kMTBlockWise) {
    y_ptr->y_width = (blocklen == -1 ? (colnr_T)maxlen - 1 : blocklen);
  } else {
    y_ptr->y_width = 0;
  }
}

void clear_oparg(oparg_T *oap)
{
  CLEAR_POINTER(oap);
}

///  Count the number of bytes, characters and "words" in a line.
///
///  "Words" are counted by looking for boundaries between non-space and
///  space characters.  (it seems to produce results that match 'wc'.)
///
///  Return value is byte count; word count for the line is added to "*wc".
///  Char count is added to "*cc".
///
///  The function will only examine the first "limit" characters in the
///  line, stopping if it encounters an end-of-line (NUL byte).  In that
///  case, eol_size will be added to the character count to account for
///  the size of the EOL character.
static varnumber_T line_count_info(char *line, varnumber_T *wc, varnumber_T *cc, varnumber_T limit,
                                   int eol_size)
{
  varnumber_T i;
  varnumber_T words = 0;
  varnumber_T chars = 0;
  bool is_word = false;

  for (i = 0; i < limit && line[i] != NUL;) {
    if (is_word) {
      if (ascii_isspace(line[i])) {
        words++;
        is_word = false;
      }
    } else if (!ascii_isspace(line[i])) {
      is_word = true;
    }
    chars++;
    i += utfc_ptr2len(line + i);
  }

  if (is_word) {
    words++;
  }
  *wc += words;

  // Add eol_size if the end of line was reached before hitting limit.
  if (i < limit && line[i] == NUL) {
    i += eol_size;
    chars += eol_size;
  }
  *cc += chars;
  return i;
}

/// Give some info about the position of the cursor (for "g CTRL-G").
/// In Visual mode, give some info about the selected region.  (In this case,
/// the *_count_cursor variables store running totals for the selection.)
///
/// @param dict  when not NULL, store the info there instead of showing it.
void cursor_pos_info(dict_T *dict)
{
  char buf1[50];
  char buf2[40];
  varnumber_T byte_count = 0;
  varnumber_T bom_count = 0;
  varnumber_T byte_count_cursor = 0;
  varnumber_T char_count = 0;
  varnumber_T char_count_cursor = 0;
  varnumber_T word_count = 0;
  varnumber_T word_count_cursor = 0;
  pos_T min_pos, max_pos;
  oparg_T oparg;
  struct block_def bd;
  const int l_VIsual_active = VIsual_active;
  const int l_VIsual_mode = VIsual_mode;

  // Compute the length of the file in characters.
  if (curbuf->b_ml.ml_flags & ML_EMPTY) {
    if (dict == NULL) {
      msg(_(no_lines_msg), 0);
      return;
    }
  } else {
    int eol_size;
    varnumber_T last_check = 100000;
    int line_count_selected = 0;
    if (get_fileformat(curbuf) == EOL_DOS) {
      eol_size = 2;
    } else {
      eol_size = 1;
    }

    if (l_VIsual_active) {
      if (lt(VIsual, curwin->w_cursor)) {
        min_pos = VIsual;
        max_pos = curwin->w_cursor;
      } else {
        min_pos = curwin->w_cursor;
        max_pos = VIsual;
      }
      if (*p_sel == 'e' && max_pos.col > 0) {
        max_pos.col--;
      }

      if (l_VIsual_mode == Ctrl_V) {
        char *const saved_sbr = p_sbr;
        char *const saved_w_sbr = curwin->w_p_sbr;

        // Make 'sbr' empty for a moment to get the correct size.
        p_sbr = empty_string_option;
        curwin->w_p_sbr = empty_string_option;
        oparg.is_VIsual = true;
        oparg.motion_type = kMTBlockWise;
        oparg.op_type = OP_NOP;
        getvcols(curwin, &min_pos, &max_pos, &oparg.start_vcol, &oparg.end_vcol);
        p_sbr = saved_sbr;
        curwin->w_p_sbr = saved_w_sbr;
        if (curwin->w_curswant == MAXCOL) {
          oparg.end_vcol = MAXCOL;
        }
        // Swap the start, end vcol if needed
        if (oparg.end_vcol < oparg.start_vcol) {
          oparg.end_vcol += oparg.start_vcol;
          oparg.start_vcol = oparg.end_vcol - oparg.start_vcol;
          oparg.end_vcol -= oparg.start_vcol;
        }
      }
      line_count_selected = max_pos.lnum - min_pos.lnum + 1;
    }

    for (linenr_T lnum = 1; lnum <= curbuf->b_ml.ml_line_count; lnum++) {
      // Check for a CTRL-C every 100000 characters.
      if (byte_count > last_check) {
        os_breakcheck();
        if (got_int) {
          return;
        }
        last_check = byte_count + 100000;
      }

      // Do extra processing for VIsual mode.
      if (l_VIsual_active
          && lnum >= min_pos.lnum && lnum <= max_pos.lnum) {
        char *s = NULL;
        int len = 0;

        switch (l_VIsual_mode) {
        case Ctrl_V:
          virtual_op = virtual_active(curwin);
          block_prep(&oparg, &bd, lnum, false);
          virtual_op = kNone;
          s = bd.textstart;
          len = bd.textlen;
          break;
        case 'V':
          s = ml_get(lnum);
          len = MAXCOL;
          break;
        case 'v': {
          colnr_T start_col = (lnum == min_pos.lnum)
                              ? min_pos.col : 0;
          colnr_T end_col = (lnum == max_pos.lnum)
                            ? max_pos.col - start_col + 1 : MAXCOL;

          s = ml_get(lnum) + start_col;
          len = end_col;
        }
        break;
        }
        if (s != NULL) {
          byte_count_cursor += line_count_info(s, &word_count_cursor,
                                               &char_count_cursor, len, eol_size);
          if (lnum == curbuf->b_ml.ml_line_count
              && !curbuf->b_p_eol
              && (curbuf->b_p_bin || !curbuf->b_p_fixeol)
              && (int)strlen(s) < len) {
            byte_count_cursor -= eol_size;
          }
        }
      } else {
        // In non-visual mode, check for the line the cursor is on
        if (lnum == curwin->w_cursor.lnum) {
          word_count_cursor += word_count;
          char_count_cursor += char_count;
          byte_count_cursor = byte_count
                              + line_count_info(ml_get(lnum), &word_count_cursor,
                                                &char_count_cursor,
                                                (varnumber_T)curwin->w_cursor.col + 1,
                                                eol_size);
        }
      }
      // Add to the running totals
      byte_count += line_count_info(ml_get(lnum), &word_count, &char_count,
                                    (varnumber_T)MAXCOL, eol_size);
    }

    // Correction for when last line doesn't have an EOL.
    if (!curbuf->b_p_eol && (curbuf->b_p_bin || !curbuf->b_p_fixeol)) {
      byte_count -= eol_size;
    }

    if (dict == NULL) {
      if (l_VIsual_active) {
        if (l_VIsual_mode == Ctrl_V && curwin->w_curswant < MAXCOL) {
          getvcols(curwin, &min_pos, &max_pos, &min_pos.col, &max_pos.col);
          int64_t cols;
          STRICT_SUB(oparg.end_vcol + 1, oparg.start_vcol, &cols, int64_t);
          vim_snprintf(buf1, sizeof(buf1), _("%" PRId64 " Cols; "),
                       cols);
        } else {
          buf1[0] = NUL;
        }

        if (char_count_cursor == byte_count_cursor
            && char_count == byte_count) {
          vim_snprintf(IObuff, IOSIZE,
                       _("Selected %s%" PRId64 " of %" PRId64 " Lines;"
                         " %" PRId64 " of %" PRId64 " Words;"
                         " %" PRId64 " of %" PRId64 " Bytes"),
                       buf1, (int64_t)line_count_selected,
                       (int64_t)curbuf->b_ml.ml_line_count,
                       (int64_t)word_count_cursor, (int64_t)word_count,
                       (int64_t)byte_count_cursor, (int64_t)byte_count);
        } else {
          vim_snprintf(IObuff, IOSIZE,
                       _("Selected %s%" PRId64 " of %" PRId64 " Lines;"
                         " %" PRId64 " of %" PRId64 " Words;"
                         " %" PRId64 " of %" PRId64 " Chars;"
                         " %" PRId64 " of %" PRId64 " Bytes"),
                       buf1, (int64_t)line_count_selected,
                       (int64_t)curbuf->b_ml.ml_line_count,
                       (int64_t)word_count_cursor, (int64_t)word_count,
                       (int64_t)char_count_cursor, (int64_t)char_count,
                       (int64_t)byte_count_cursor, (int64_t)byte_count);
        }
      } else {
        char *p = get_cursor_line_ptr();
        validate_virtcol(curwin);
        col_print(buf1, sizeof(buf1), (int)curwin->w_cursor.col + 1,
                  (int)curwin->w_virtcol + 1);
        col_print(buf2, sizeof(buf2), get_cursor_line_len(), linetabsize_str(p));

        if (char_count_cursor == byte_count_cursor
            && char_count == byte_count) {
          vim_snprintf(IObuff, IOSIZE,
                       _("Col %s of %s; Line %" PRId64 " of %" PRId64 ";"
                         " Word %" PRId64 " of %" PRId64 ";"
                         " Byte %" PRId64 " of %" PRId64 ""),
                       buf1, buf2,
                       (int64_t)curwin->w_cursor.lnum,
                       (int64_t)curbuf->b_ml.ml_line_count,
                       (int64_t)word_count_cursor, (int64_t)word_count,
                       (int64_t)byte_count_cursor, (int64_t)byte_count);
        } else {
          vim_snprintf(IObuff, IOSIZE,
                       _("Col %s of %s; Line %" PRId64 " of %" PRId64 ";"
                         " Word %" PRId64 " of %" PRId64 ";"
                         " Char %" PRId64 " of %" PRId64 ";"
                         " Byte %" PRId64 " of %" PRId64 ""),
                       buf1, buf2,
                       (int64_t)curwin->w_cursor.lnum,
                       (int64_t)curbuf->b_ml.ml_line_count,
                       (int64_t)word_count_cursor, (int64_t)word_count,
                       (int64_t)char_count_cursor, (int64_t)char_count,
                       (int64_t)byte_count_cursor, (int64_t)byte_count);
        }
      }
    }

    bom_count = bomb_size();
    if (dict == NULL && bom_count > 0) {
      const size_t len = strlen(IObuff);
      vim_snprintf(IObuff + len, IOSIZE - len,
                   _("(+%" PRId64 " for BOM)"), (int64_t)bom_count);
    }
    if (dict == NULL) {
      // Don't shorten this message, the user asked for it.
      char *p = p_shm;
      p_shm = "";
      if (p_ch < 1) {
        msg_start();
        msg_scroll = true;
      }
      msg(IObuff, 0);
      p_shm = p;
    }
  }

  if (dict != NULL) {
    // Don't shorten this message, the user asked for it.
    tv_dict_add_nr(dict, S_LEN("words"), word_count);
    tv_dict_add_nr(dict, S_LEN("chars"), char_count);
    tv_dict_add_nr(dict, S_LEN("bytes"), byte_count + bom_count);

    STATIC_ASSERT(sizeof("visual") == sizeof("cursor"),
                  "key_len argument in tv_dict_add_nr is wrong");
    tv_dict_add_nr(dict, l_VIsual_active ? "visual_bytes" : "cursor_bytes",
                   sizeof("visual_bytes") - 1, byte_count_cursor);
    tv_dict_add_nr(dict, l_VIsual_active ? "visual_chars" : "cursor_chars",
                   sizeof("visual_chars") - 1, char_count_cursor);
    tv_dict_add_nr(dict, l_VIsual_active ? "visual_words" : "cursor_words",
                   sizeof("visual_words") - 1, word_count_cursor);
  }
}

/// Handle indent and format operators and visual mode ":".
static void op_colon(oparg_T *oap)
{
  stuffcharReadbuff(':');
  if (oap->is_VIsual) {
    stuffReadbuff("'<,'>");
  } else {
    // Make the range look nice, so it can be repeated.
    if (oap->start.lnum == curwin->w_cursor.lnum) {
      stuffcharReadbuff('.');
    } else {
      stuffnumReadbuff(oap->start.lnum);
    }

    // When using !! on a closed fold the range ".!" works best to operate
    // on, it will be made the whole closed fold later.
    linenr_T endOfStartFold = oap->start.lnum;
    hasFolding(curwin, oap->start.lnum, NULL, &endOfStartFold);
    if (oap->end.lnum != oap->start.lnum && oap->end.lnum != endOfStartFold) {
      // Make it a range with the end line.
      stuffcharReadbuff(',');
      if (oap->end.lnum == curwin->w_cursor.lnum) {
        stuffcharReadbuff('.');
      } else if (oap->end.lnum == curbuf->b_ml.ml_line_count) {
        stuffcharReadbuff('$');
      } else if (oap->start.lnum == curwin->w_cursor.lnum
                 // do not use ".+number" for a closed fold, it would count
                 // folded lines twice
                 && !hasFolding(curwin, oap->end.lnum, NULL, NULL)) {
        stuffReadbuff(".+");
        stuffnumReadbuff(oap->line_count - 1);
      } else {
        stuffnumReadbuff(oap->end.lnum);
      }
    }
  }
  if (oap->op_type != OP_COLON) {
    stuffReadbuff("!");
  }
  if (oap->op_type == OP_INDENT) {
    stuffReadbuff(get_equalprg());
    stuffReadbuff("\n");
  } else if (oap->op_type == OP_FORMAT) {
    if (*curbuf->b_p_fp != NUL) {
      stuffReadbuff(curbuf->b_p_fp);
    } else if (*p_fp != NUL) {
      stuffReadbuff(p_fp);
    } else {
      stuffReadbuff("fmt");
    }
    stuffReadbuff("\n']");
  }

  // do_cmdline() does the rest
}

/// callback function for 'operatorfunc'
static Callback opfunc_cb;

/// Process the 'operatorfunc' option value.
const char *did_set_operatorfunc(optset_T *args FUNC_ATTR_UNUSED)
{
  if (option_set_callback_func(p_opfunc, &opfunc_cb) == FAIL) {
    return e_invarg;
  }
  return NULL;
}

#if defined(EXITFREE)
void free_operatorfunc_option(void)
{
  callback_free(&opfunc_cb);
}
#endif

/// Mark the global 'operatorfunc' callback with "copyID" so that it is not
/// garbage collected.
bool set_ref_in_opfunc(int copyID)
{
  return set_ref_in_callback(&opfunc_cb, copyID, NULL, NULL);
}

/// Handle the "g@" operator: call 'operatorfunc'.
static void op_function(const oparg_T *oap)
  FUNC_ATTR_NONNULL_ALL
{
  const pos_T orig_start = curbuf->b_op_start;
  const pos_T orig_end = curbuf->b_op_end;

  if (*p_opfunc == NUL) {
    emsg(_("E774: 'operatorfunc' is empty"));
  } else {
    // Set '[ and '] marks to text to be operated on.
    curbuf->b_op_start = oap->start;
    curbuf->b_op_end = oap->end;
    if (oap->motion_type != kMTLineWise && !oap->inclusive) {
      // Exclude the end position.
      decl(&curbuf->b_op_end);
    }

    typval_T argv[2];
    argv[0].v_type = VAR_STRING;
    argv[1].v_type = VAR_UNKNOWN;
    argv[0].vval.v_string =
      (char *)(((const char *const[]) {
      [kMTBlockWise] = "block",
      [kMTLineWise] = "line",
      [kMTCharWise] = "char",
    })[oap->motion_type]);

    // Reset virtual_op so that 'virtualedit' can be changed in the
    // function.
    const TriState save_virtual_op = virtual_op;
    virtual_op = kNone;

    // Reset finish_op so that mode() returns the right value.
    const bool save_finish_op = finish_op;
    finish_op = false;

    typval_T rettv;
    if (callback_call(&opfunc_cb, 1, argv, &rettv)) {
      tv_clear(&rettv);
    }

    virtual_op = save_virtual_op;
    finish_op = save_finish_op;
    if (cmdmod.cmod_flags & CMOD_LOCKMARKS) {
      curbuf->b_op_start = orig_start;
      curbuf->b_op_end = orig_end;
    }
  }
}

/// Calculate start/end virtual columns for operating in block mode.
///
/// @param initial  when true: adjust position for 'selectmode'
static void get_op_vcol(oparg_T *oap, colnr_T redo_VIsual_vcol, bool initial)
{
  colnr_T start;
  colnr_T end;

  if (VIsual_mode != Ctrl_V
      || (!initial && oap->end.col < curwin->w_width_inner)) {
    return;
  }

  oap->motion_type = kMTBlockWise;

  // prevent from moving onto a trail byte
  mark_mb_adjustpos(curwin->w_buffer, &oap->end);

  getvvcol(curwin, &(oap->start), &oap->start_vcol, NULL, &oap->end_vcol);
  if (!redo_VIsual_busy) {
    getvvcol(curwin, &(oap->end), &start, NULL, &end);

    if (start < oap->start_vcol) {
      oap->start_vcol = start;
    }
    if (end > oap->end_vcol) {
      if (initial && *p_sel == 'e'
          && start >= 1
          && start - 1 >= oap->end_vcol) {
        oap->end_vcol = start - 1;
      } else {
        oap->end_vcol = end;
      }
    }
  }

  // if '$' was used, get oap->end_vcol from longest line
  if (curwin->w_curswant == MAXCOL) {
    curwin->w_cursor.col = MAXCOL;
    oap->end_vcol = 0;
    for (curwin->w_cursor.lnum = oap->start.lnum;
         curwin->w_cursor.lnum <= oap->end.lnum; curwin->w_cursor.lnum++) {
      getvvcol(curwin, &curwin->w_cursor, NULL, NULL, &end);
      if (end > oap->end_vcol) {
        oap->end_vcol = end;
      }
    }
  } else if (redo_VIsual_busy) {
    oap->end_vcol = oap->start_vcol + redo_VIsual_vcol - 1;
  }

  // Correct oap->end.col and oap->start.col to be the
  // upper-left and lower-right corner of the block area.
  //
  // (Actually, this does convert column positions into character
  // positions)
  curwin->w_cursor.lnum = oap->end.lnum;
  coladvance(curwin, oap->end_vcol);
  oap->end = curwin->w_cursor;

  curwin->w_cursor = oap->start;
  coladvance(curwin, oap->start_vcol);
  oap->start = curwin->w_cursor;
}

/// Information for redoing the previous Visual selection.
typedef struct {
  int rv_mode;             ///< 'v', 'V', or Ctrl-V
  linenr_T rv_line_count;  ///< number of lines
  colnr_T rv_vcol;         ///< number of cols or end column
  int rv_count;            ///< count for Visual operator
  int rv_arg;              ///< extra argument
} redo_VIsual_T;

static bool is_ex_cmdchar(cmdarg_T *cap)
{
  return cap->cmdchar == ':' || cap->cmdchar == K_COMMAND;
}

/// Handle an operator after Visual mode or when the movement is finished.
/// "gui_yank" is true when yanking text for the clipboard.
void do_pending_operator(cmdarg_T *cap, int old_col, bool gui_yank)
{
  oparg_T *oap = cap->oap;
  int lbr_saved = curwin->w_p_lbr;

  // The visual area is remembered for redo
  static redo_VIsual_T redo_VIsual = { NUL, 0, 0, 0, 0 };

  pos_T old_cursor = curwin->w_cursor;

  // If an operation is pending, handle it...
  if ((finish_op
       || VIsual_active)
      && oap->op_type != OP_NOP) {
    bool empty_region_error;
    int restart_edit_save;
    bool include_line_break = false;
    // Yank can be redone when 'y' is in 'cpoptions', but not when yanking
    // for the clipboard.
    const bool redo_yank = vim_strchr(p_cpo, CPO_YANK) != NULL && !gui_yank;

    // Avoid a problem with unwanted linebreaks in block mode
    reset_lbr();
    oap->is_VIsual = VIsual_active;
    if (oap->motion_force == 'V') {
      oap->motion_type = kMTLineWise;
    } else if (oap->motion_force == 'v') {
      // If the motion was linewise, "inclusive" will not have been set.
      // Use "exclusive" to be consistent.  Makes "dvj" work nice.
      if (oap->motion_type == kMTLineWise) {
        oap->inclusive = false;
      } else if (oap->motion_type == kMTCharWise) {
        // If the motion already was charwise, toggle "inclusive"
        oap->inclusive = !oap->inclusive;
      }
      oap->motion_type = kMTCharWise;
    } else if (oap->motion_force == Ctrl_V) {
      // Change line- or charwise motion into Visual block mode.
      if (!VIsual_active) {
        VIsual_active = true;
        VIsual = oap->start;
      }
      VIsual_mode = Ctrl_V;
      VIsual_select = false;
      VIsual_reselect = false;
    }

    // Only redo yank when 'y' flag is in 'cpoptions'.
    // Never redo "zf" (define fold).
    if ((redo_yank || oap->op_type != OP_YANK)
        && ((!VIsual_active || oap->motion_force)
            // Also redo Operator-pending Visual mode mappings.
            || ((is_ex_cmdchar(cap) || cap->cmdchar == K_LUA)
                && oap->op_type != OP_COLON))
        && cap->cmdchar != 'D'
        && oap->op_type != OP_FOLD
        && oap->op_type != OP_FOLDOPEN
        && oap->op_type != OP_FOLDOPENREC
        && oap->op_type != OP_FOLDCLOSE
        && oap->op_type != OP_FOLDCLOSEREC
        && oap->op_type != OP_FOLDDEL
        && oap->op_type != OP_FOLDDELREC) {
      prep_redo(oap->regname, cap->count0,
                get_op_char(oap->op_type), get_extra_op_char(oap->op_type),
                oap->motion_force, cap->cmdchar, cap->nchar);
      if (cap->cmdchar == '/' || cap->cmdchar == '?') {     // was a search
        // If 'cpoptions' does not contain 'r', insert the search
        // pattern to really repeat the same command.
        if (vim_strchr(p_cpo, CPO_REDO) == NULL) {
          AppendToRedobuffLit(cap->searchbuf, -1);
        }
        AppendToRedobuff(NL_STR);
      } else if (is_ex_cmdchar(cap)) {
        // do_cmdline() has stored the first typed line in
        // "repeat_cmdline".  When several lines are typed repeating
        // won't be possible.
        if (repeat_cmdline == NULL) {
          ResetRedobuff();
        } else {
          if (cap->cmdchar == ':') {
            AppendToRedobuffLit(repeat_cmdline, -1);
          } else {
            AppendToRedobuffSpec(repeat_cmdline);
          }
          AppendToRedobuff(NL_STR);
          XFREE_CLEAR(repeat_cmdline);
        }
      } else if (cap->cmdchar == K_LUA) {
        AppendNumberToRedobuff(repeat_luaref);
        AppendToRedobuff(NL_STR);
      }
    }

    if (redo_VIsual_busy) {
      // Redo of an operation on a Visual area. Use the same size from
      // redo_VIsual.rv_line_count and redo_VIsual.rv_vcol.
      oap->start = curwin->w_cursor;
      curwin->w_cursor.lnum += redo_VIsual.rv_line_count - 1;
      if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count) {
        curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
      }
      VIsual_mode = redo_VIsual.rv_mode;
      if (redo_VIsual.rv_vcol == MAXCOL || VIsual_mode == 'v') {
        if (VIsual_mode == 'v') {
          if (redo_VIsual.rv_line_count <= 1) {
            validate_virtcol(curwin);
            curwin->w_curswant = curwin->w_virtcol + redo_VIsual.rv_vcol - 1;
          } else {
            curwin->w_curswant = redo_VIsual.rv_vcol;
          }
        } else {
          curwin->w_curswant = MAXCOL;
        }
        coladvance(curwin, curwin->w_curswant);
      }
      cap->count0 = redo_VIsual.rv_count;
      cap->count1 = (cap->count0 == 0 ? 1 : cap->count0);
    } else if (VIsual_active) {
      if (!gui_yank) {
        // Save the current VIsual area for '< and '> marks, and "gv"
        curbuf->b_visual.vi_start = VIsual;
        curbuf->b_visual.vi_end = curwin->w_cursor;
        curbuf->b_visual.vi_mode = VIsual_mode;
        restore_visual_mode();
        curbuf->b_visual.vi_curswant = curwin->w_curswant;
        curbuf->b_visual_mode_eval = VIsual_mode;
      }

      // In Select mode, a linewise selection is operated upon like a
      // charwise selection.
      // Special case: gH<Del> deletes the last line.
      if (VIsual_select && VIsual_mode == 'V'
          && cap->oap->op_type != OP_DELETE) {
        if (lt(VIsual, curwin->w_cursor)) {
          VIsual.col = 0;
          curwin->w_cursor.col = ml_get_len(curwin->w_cursor.lnum);
        } else {
          curwin->w_cursor.col = 0;
          VIsual.col = ml_get_len(VIsual.lnum);
        }
        VIsual_mode = 'v';
      } else if (VIsual_mode == 'v') {
        // If 'selection' is "exclusive", backup one character for
        // charwise selections.
        include_line_break = unadjust_for_sel();
      }

      oap->start = VIsual;
      if (VIsual_mode == 'V') {
        oap->start.col = 0;
        oap->start.coladd = 0;
      }
    }

    // Set oap->start to the first position of the operated text, oap->end
    // to the end of the operated text.  w_cursor is equal to oap->start.
    if (lt(oap->start, curwin->w_cursor)) {
      // Include folded lines completely.
      if (!VIsual_active) {
        if (hasFolding(curwin, oap->start.lnum, &oap->start.lnum, NULL)) {
          oap->start.col = 0;
        }
        if ((curwin->w_cursor.col > 0
             || oap->inclusive
             || oap->motion_type == kMTLineWise)
            && hasFolding(curwin, curwin->w_cursor.lnum, NULL,
                          &curwin->w_cursor.lnum)) {
          curwin->w_cursor.col = get_cursor_line_len();
        }
      }
      oap->end = curwin->w_cursor;
      curwin->w_cursor = oap->start;

      // w_virtcol may have been updated; if the cursor goes back to its
      // previous position w_virtcol becomes invalid and isn't updated
      // automatically.
      curwin->w_valid &= ~VALID_VIRTCOL;
    } else {
      // Include folded lines completely.
      if (!VIsual_active && oap->motion_type == kMTLineWise) {
        if (hasFolding(curwin, curwin->w_cursor.lnum, &curwin->w_cursor.lnum,
                       NULL)) {
          curwin->w_cursor.col = 0;
        }
        if (hasFolding(curwin, oap->start.lnum, NULL, &oap->start.lnum)) {
          oap->start.col = ml_get_len(oap->start.lnum);
        }
      }
      oap->end = oap->start;
      oap->start = curwin->w_cursor;
    }

    // Just in case lines were deleted that make the position invalid.
    check_pos(curwin->w_buffer, &oap->end);
    oap->line_count = oap->end.lnum - oap->start.lnum + 1;

    // Set "virtual_op" before resetting VIsual_active.
    virtual_op = virtual_active(curwin);

    if (VIsual_active || redo_VIsual_busy) {
      get_op_vcol(oap, redo_VIsual.rv_vcol, true);

      if (!redo_VIsual_busy && !gui_yank) {
        // Prepare to reselect and redo Visual: this is based on the
        // size of the Visual text
        resel_VIsual_mode = VIsual_mode;
        if (curwin->w_curswant == MAXCOL) {
          resel_VIsual_vcol = MAXCOL;
        } else {
          if (VIsual_mode != Ctrl_V) {
            getvvcol(curwin, &(oap->end),
                     NULL, NULL, &oap->end_vcol);
          }
          if (VIsual_mode == Ctrl_V || oap->line_count <= 1) {
            if (VIsual_mode != Ctrl_V) {
              getvvcol(curwin, &(oap->start),
                       &oap->start_vcol, NULL, NULL);
            }
            resel_VIsual_vcol = oap->end_vcol - oap->start_vcol + 1;
          } else {
            resel_VIsual_vcol = oap->end_vcol;
          }
        }
        resel_VIsual_line_count = oap->line_count;
      }

      // can't redo yank (unless 'y' is in 'cpoptions') and ":"
      if ((redo_yank || oap->op_type != OP_YANK)
          && oap->op_type != OP_COLON
          && oap->op_type != OP_FOLD
          && oap->op_type != OP_FOLDOPEN
          && oap->op_type != OP_FOLDOPENREC
          && oap->op_type != OP_FOLDCLOSE
          && oap->op_type != OP_FOLDCLOSEREC
          && oap->op_type != OP_FOLDDEL
          && oap->op_type != OP_FOLDDELREC
          && oap->motion_force == NUL) {
        // Prepare for redoing.  Only use the nchar field for "r",
        // otherwise it might be the second char of the operator.
        if (cap->cmdchar == 'g' && (cap->nchar == 'n'
                                    || cap->nchar == 'N')) {
          prep_redo(oap->regname, cap->count0,
                    get_op_char(oap->op_type), get_extra_op_char(oap->op_type),
                    oap->motion_force, cap->cmdchar, cap->nchar);
        } else if (!is_ex_cmdchar(cap) && cap->cmdchar != K_LUA) {
          int opchar = get_op_char(oap->op_type);
          int extra_opchar = get_extra_op_char(oap->op_type);
          int nchar = oap->op_type == OP_REPLACE ? cap->nchar : NUL;

          // reverse what nv_replace() did
          if (nchar == REPLACE_CR_NCHAR) {
            nchar = CAR;
          } else if (nchar == REPLACE_NL_NCHAR) {
            nchar = NL;
          }

          if (opchar == 'g' && extra_opchar == '@') {
            // also repeat the count for 'operatorfunc'
            prep_redo_num2(oap->regname, 0, NUL, 'v', cap->count0, opchar, extra_opchar, nchar);
          } else {
            prep_redo(oap->regname, 0, NUL, 'v', opchar, extra_opchar, nchar);
          }
        }
        if (!redo_VIsual_busy) {
          redo_VIsual.rv_mode = resel_VIsual_mode;
          redo_VIsual.rv_vcol = resel_VIsual_vcol;
          redo_VIsual.rv_line_count = resel_VIsual_line_count;
          redo_VIsual.rv_count = cap->count0;
          redo_VIsual.rv_arg = cap->arg;
        }
      }

      // oap->inclusive defaults to true.
      // If oap->end is on a NUL (empty line) oap->inclusive becomes
      // false.  This makes "d}P" and "v}dP" work the same.
      if (oap->motion_force == NUL || oap->motion_type == kMTLineWise) {
        oap->inclusive = true;
      }
      if (VIsual_mode == 'V') {
        oap->motion_type = kMTLineWise;
      } else if (VIsual_mode == 'v') {
        oap->motion_type = kMTCharWise;
        if (*ml_get_pos(&(oap->end)) == NUL
            && (include_line_break || !virtual_op)) {
          oap->inclusive = false;
          // Try to include the newline, unless it's an operator
          // that works on lines only.
          if (*p_sel != 'o'
              && !op_on_lines(oap->op_type)
              && oap->end.lnum < curbuf->b_ml.ml_line_count) {
            oap->end.lnum++;
            oap->end.col = 0;
            oap->end.coladd = 0;
            oap->line_count++;
          }
        }
      }

      redo_VIsual_busy = false;

      // Switch Visual off now, so screen updating does
      // not show inverted text when the screen is redrawn.
      // With OP_YANK and sometimes with OP_COLON and OP_FILTER there is
      // no screen redraw, so it is done here to remove the inverted
      // part.
      if (!gui_yank) {
        VIsual_active = false;
        setmouse();
        mouse_dragging = 0;
        may_clear_cmdline();
        if ((oap->op_type == OP_YANK
             || oap->op_type == OP_COLON
             || oap->op_type == OP_FUNCTION
             || oap->op_type == OP_FILTER)
            && oap->motion_force == NUL) {
          // Make sure redrawing is correct.
          restore_lbr(lbr_saved);
          redraw_curbuf_later(UPD_INVERTED);
        }
      }
    }

    // Include the trailing byte of a multi-byte char.
    if (oap->inclusive) {
      const int l = utfc_ptr2len(ml_get_pos(&oap->end));
      if (l > 1) {
        oap->end.col += l - 1;
      }
    }
    curwin->w_set_curswant = true;

    // oap->empty is set when start and end are the same.  The inclusive
    // flag affects this too, unless yanking and the end is on a NUL.
    oap->empty = (oap->motion_type != kMTLineWise
                  && (!oap->inclusive
                      || (oap->op_type == OP_YANK
                          && gchar_pos(&oap->end) == NUL))
                  && equalpos(oap->start, oap->end)
                  && !(virtual_op && oap->start.coladd != oap->end.coladd));
    // For delete, change and yank, it's an error to operate on an
    // empty region, when 'E' included in 'cpoptions' (Vi compatible).
    empty_region_error = (oap->empty
                          && vim_strchr(p_cpo, CPO_EMPTYREGION) != NULL);

    // Force a redraw when operating on an empty Visual region, when
    // 'modifiable is off or creating a fold.
    if (oap->is_VIsual && (oap->empty || !MODIFIABLE(curbuf)
                           || oap->op_type == OP_FOLD)) {
      restore_lbr(lbr_saved);
      redraw_curbuf_later(UPD_INVERTED);
    }

    // If the end of an operator is in column one while oap->motion_type
    // is kMTCharWise and oap->inclusive is false, we put op_end after the last
    // character in the previous line. If op_start is on or before the
    // first non-blank in the line, the operator becomes linewise
    // (strange, but that's the way vi does it).
    if (oap->motion_type == kMTCharWise
        && oap->inclusive == false
        && !(cap->retval & CA_NO_ADJ_OP_END)
        && oap->end.col == 0
        && (!oap->is_VIsual || *p_sel == 'o')
        && oap->line_count > 1) {
      oap->end_adjusted = true;  // remember that we did this
      oap->line_count--;
      oap->end.lnum--;
      if (inindent(0)) {
        oap->motion_type = kMTLineWise;
      } else {
        oap->end.col = ml_get_len(oap->end.lnum);
        if (oap->end.col) {
          oap->end.col--;
          oap->inclusive = true;
        }
      }
    } else {
      oap->end_adjusted = false;
    }

    switch (oap->op_type) {
    case OP_LSHIFT:
    case OP_RSHIFT:
      op_shift(oap, true, oap->is_VIsual ? cap->count1 : 1);
      auto_format(false, true);
      break;

    case OP_JOIN_NS:
    case OP_JOIN:
      if (oap->line_count < 2) {
        oap->line_count = 2;
      }
      if (curwin->w_cursor.lnum + oap->line_count - 1 >
          curbuf->b_ml.ml_line_count) {
        beep_flush();
      } else {
        do_join((size_t)oap->line_count, oap->op_type == OP_JOIN,
                true, true, true);
        auto_format(false, true);
      }
      break;

    case OP_DELETE:
      VIsual_reselect = false;              // don't reselect now
      if (empty_region_error) {
        vim_beep(BO_OPER);
        CancelRedo();
      } else {
        op_delete(oap);
        // save cursor line for undo if it wasn't saved yet
        if (oap->motion_type == kMTLineWise
            && has_format_option(FO_AUTO)
            && u_save_cursor() == OK) {
          auto_format(false, true);
        }
      }
      break;

    case OP_YANK:
      if (empty_region_error) {
        if (!gui_yank) {
          vim_beep(BO_OPER);
          CancelRedo();
        }
      } else {
        restore_lbr(lbr_saved);
        oap->excl_tr_ws = cap->cmdchar == 'z';
        op_yank(oap, !gui_yank);
      }
      check_cursor_col(curwin);
      break;

    case OP_CHANGE:
      VIsual_reselect = false;              // don't reselect now
      if (empty_region_error) {
        vim_beep(BO_OPER);
        CancelRedo();
      } else {
        // This is a new edit command, not a restart.  Need to
        // remember it to make i_CTRL-O work with mappings for
        // Visual mode.  But do this only once and not when typed.
        if (!KeyTyped) {
          restart_edit_save = restart_edit;
        } else {
          restart_edit_save = 0;
        }
        restart_edit = 0;

        // Restore linebreak, so that when the user edits it looks as before.
        restore_lbr(lbr_saved);

        // trigger TextChangedI
        curbuf->b_last_changedtick_i = buf_get_changedtick(curbuf);

        if (op_change(oap)) {           // will call edit()
          cap->retval |= CA_COMMAND_BUSY;
        }
        if (restart_edit == 0) {
          restart_edit = restart_edit_save;
        }
      }
      break;

    case OP_FILTER:
      if (vim_strchr(p_cpo, CPO_FILTER) != NULL) {
        AppendToRedobuff("!\r");  // Use any last used !cmd.
      } else {
        bangredo = true;  // do_bang() will put cmd in redo buffer.
      }
      FALLTHROUGH;

    case OP_INDENT:
    case OP_COLON:

      // If 'equalprg' is empty, do the indenting internally.
      if (oap->op_type == OP_INDENT && *get_equalprg() == NUL) {
        if (curbuf->b_p_lisp) {
          if (use_indentexpr_for_lisp()) {
            op_reindent(oap, get_expr_indent);
          } else {
            op_reindent(oap, get_lisp_indent);
          }
          break;
        }
        op_reindent(oap,
                    *curbuf->b_p_inde != NUL ? get_expr_indent
                                             : get_c_indent);
        break;
      }

      op_colon(oap);
      break;

    case OP_TILDE:
    case OP_UPPER:
    case OP_LOWER:
    case OP_ROT13:
      if (empty_region_error) {
        vim_beep(BO_OPER);
        CancelRedo();
      } else {
        op_tilde(oap);
      }
      check_cursor_col(curwin);
      break;

    case OP_FORMAT:
      if (*curbuf->b_p_fex != NUL) {
        op_formatexpr(oap);             // use expression
      } else {
        if (*p_fp != NUL || *curbuf->b_p_fp != NUL) {
          op_colon(oap);                // use external command
        } else {
          op_format(oap, false);        // use internal function
        }
      }
      break;

    case OP_FORMAT2:
      op_format(oap, true);             // use internal function
      break;

    case OP_FUNCTION: {
      redo_VIsual_T save_redo_VIsual = redo_VIsual;

      // Restore linebreak, so that when the user edits it looks as before.
      restore_lbr(lbr_saved);
      // call 'operatorfunc'
      op_function(oap);

      // Restore the info for redoing Visual mode, the function may
      // invoke another operator and unintentionally change it.
      redo_VIsual = save_redo_VIsual;
      break;
    }

    case OP_INSERT:
    case OP_APPEND:
      VIsual_reselect = false;          // don't reselect now
      if (empty_region_error) {
        vim_beep(BO_OPER);
        CancelRedo();
      } else {
        // This is a new edit command, not a restart.  Need to
        // remember it to make i_CTRL-O work with mappings for
        // Visual mode.  But do this only once.
        restart_edit_save = restart_edit;
        restart_edit = 0;

        // Restore linebreak, so that when the user edits it looks as before.
        restore_lbr(lbr_saved);

        // trigger TextChangedI
        curbuf->b_last_changedtick_i = buf_get_changedtick(curbuf);

        op_insert(oap, cap->count1);

        // Reset linebreak, so that formatting works correctly.
        reset_lbr();

        // TODO(brammool): when inserting in several lines, should format all
        // the lines.
        auto_format(false, true);

        if (restart_edit == 0) {
          restart_edit = restart_edit_save;
        } else {
          cap->retval |= CA_COMMAND_BUSY;
        }
      }
      break;

    case OP_REPLACE:
      VIsual_reselect = false;          // don't reselect now
      if (empty_region_error) {
        vim_beep(BO_OPER);
        CancelRedo();
      } else {
        // Restore linebreak, so that when the user edits it looks as before.
        restore_lbr(lbr_saved);

        op_replace(oap, cap->nchar);
      }
      break;

    case OP_FOLD:
      VIsual_reselect = false;          // don't reselect now
      foldCreate(curwin, oap->start, oap->end);
      break;

    case OP_FOLDOPEN:
    case OP_FOLDOPENREC:
    case OP_FOLDCLOSE:
    case OP_FOLDCLOSEREC:
      VIsual_reselect = false;          // don't reselect now
      opFoldRange(oap->start, oap->end,
                  oap->op_type == OP_FOLDOPEN
                  || oap->op_type == OP_FOLDOPENREC,
                  oap->op_type == OP_FOLDOPENREC
                  || oap->op_type == OP_FOLDCLOSEREC,
                  oap->is_VIsual);
      break;

    case OP_FOLDDEL:
    case OP_FOLDDELREC:
      VIsual_reselect = false;          // don't reselect now
      deleteFold(curwin, oap->start.lnum, oap->end.lnum,
                 oap->op_type == OP_FOLDDELREC, oap->is_VIsual);
      break;

    case OP_NR_ADD:
    case OP_NR_SUB:
      if (empty_region_error) {
        vim_beep(BO_OPER);
        CancelRedo();
      } else {
        VIsual_active = true;
        restore_lbr(lbr_saved);
        op_addsub(oap, (linenr_T)cap->count1, redo_VIsual.rv_arg);
        VIsual_active = false;
      }
      check_cursor_col(curwin);
      break;
    default:
      clearopbeep(oap);
    }
    virtual_op = kNone;
    if (!gui_yank) {
      // if 'sol' not set, go back to old column for some commands
      if (!p_sol && oap->motion_type == kMTLineWise && !oap->end_adjusted
          && (oap->op_type == OP_LSHIFT || oap->op_type == OP_RSHIFT
              || oap->op_type == OP_DELETE)) {
        reset_lbr();
        coladvance(curwin, curwin->w_curswant = old_col);
      }
    } else {
      curwin->w_cursor = old_cursor;
    }
    clearop(oap);
    motion_force = NUL;
  }
  restore_lbr(lbr_saved);
}

/// Check if the default register (used in an unnamed paste) should be a
/// clipboard register. This happens when `clipboard=unnamed[plus]` is set
/// and a provider is available.
///
/// @returns the name of of a clipboard register that should be used, or `NUL` if none.
int get_default_register_name(void)
{
  int name = NUL;
  adjust_clipboard_name(&name, true, false);
  return name;
}

/// Determine if register `*name` should be used as a clipboard.
/// In an unnamed operation, `*name` is `NUL` and will be adjusted to */+ if
/// `clipboard=unnamed[plus]` is set.
///
/// @param name The name of register, or `NUL` if unnamed.
/// @param quiet Suppress error messages
/// @param writing if we're setting the contents of the clipboard
///
/// @returns the yankreg that should be written into, or `NULL`
/// if the register isn't a clipboard or provider isn't available.
static yankreg_T *adjust_clipboard_name(int *name, bool quiet, bool writing)
{
#define MSG_NO_CLIP "clipboard: No provider. " \
  "Try \":checkhealth\" or \":h clipboard\"."

  yankreg_T *target = NULL;
  bool explicit_cb_reg = (*name == '*' || *name == '+');
  bool implicit_cb_reg = (*name == NUL) && (cb_flags & CB_UNNAMEDMASK);
  if (!explicit_cb_reg && !implicit_cb_reg) {
    goto end;
  }

  if (!eval_has_provider("clipboard", false)) {
    if (batch_change_count <= 1 && !quiet
        && (!clipboard_didwarn || (explicit_cb_reg && !redirecting()))) {
      clipboard_didwarn = true;
      // Do NOT error (emsg()) here--if it interrupts :redir we get into
      // a weird state, stuck in "redirect mode".
      msg(MSG_NO_CLIP, 0);
    }
    // ... else, be silent (don't flood during :while, :redir, etc.).
    goto end;
  }

  if (explicit_cb_reg) {
    target = &y_regs[*name == '*' ? STAR_REGISTER : PLUS_REGISTER];
    if (writing && (cb_flags & (*name == '*' ? CB_UNNAMED : CB_UNNAMEDPLUS))) {
      clipboard_needs_update = false;
    }
    goto end;
  } else {  // unnamed register: "implicit" clipboard
    if (writing && clipboard_delay_update) {
      // For "set" (copy), defer the clipboard call.
      clipboard_needs_update = true;
      goto end;
    } else if (!writing && clipboard_needs_update) {
      // For "get" (paste), use the internal value.
      goto end;
    }

    if (cb_flags & CB_UNNAMEDPLUS) {
      *name = (cb_flags & CB_UNNAMED && writing) ? '"' : '+';
      target = &y_regs[PLUS_REGISTER];
    } else {
      *name = '*';
      target = &y_regs[STAR_REGISTER];
    }
    goto end;
  }

end:
  return target;
}

/// @param[out] reg Expected to be empty
bool prepare_yankreg_from_object(yankreg_T *reg, String regtype, size_t lines)
{
  char type = regtype.data ? regtype.data[0] : NUL;

  switch (type) {
  case 0:
    reg->y_type = kMTUnknown;
    break;
  case 'v':
  case 'c':
    reg->y_type = kMTCharWise;
    break;
  case 'V':
  case 'l':
    reg->y_type = kMTLineWise;
    break;
  case 'b':
  case Ctrl_V:
    reg->y_type = kMTBlockWise;
    break;
  default:
    return false;
  }

  reg->y_width = 0;
  if (regtype.size > 1) {
    if (reg->y_type != kMTBlockWise) {
      return false;
    }

    // allow "b7" for a block at least 7 spaces wide
    if (!ascii_isdigit(regtype.data[1])) {
      return false;
    }
    const char *p = regtype.data + 1;
    reg->y_width = getdigits_int((char **)&p, false, 1) - 1;
    if (regtype.size > (size_t)(p - regtype.data)) {
      return false;
    }
  }

  reg->additional_data = NULL;
  reg->timestamp = 0;
  return true;
}

void finish_yankreg_from_object(yankreg_T *reg, bool clipboard_adjust)
{
  if (reg->y_size > 0 && strlen(reg->y_array[reg->y_size - 1]) == 0) {
    // a known-to-be charwise yank might have a final linebreak
    // but otherwise there is no line after the final newline
    if (reg->y_type != kMTCharWise) {
      if (reg->y_type == kMTUnknown || clipboard_adjust) {
        reg->y_size--;
      }
      if (reg->y_type == kMTUnknown) {
        reg->y_type = kMTLineWise;
      }
    }
  } else {
    if (reg->y_type == kMTUnknown) {
      reg->y_type = kMTCharWise;
    }
  }

  if (reg->y_type == kMTBlockWise) {
    size_t maxlen = 0;
    for (size_t i = 0; i < reg->y_size; i++) {
      size_t rowlen = strlen(reg->y_array[i]);
      if (rowlen > maxlen) {
        maxlen = rowlen;
      }
    }
    assert(maxlen <= INT_MAX);
    reg->y_width = MAX(reg->y_width, (int)maxlen - 1);
  }
}

static bool get_clipboard(int name, yankreg_T **target, bool quiet)
{
  // show message on error
  bool errmsg = true;

  yankreg_T *reg = adjust_clipboard_name(&name, quiet, false);
  if (reg == NULL) {
    return false;
  }
  free_register(reg);

  list_T *const args = tv_list_alloc(1);
  const char regname = (char)name;
  tv_list_append_string(args, &regname, 1);

  typval_T result = eval_call_provider("clipboard", "get", args, false);

  if (result.v_type != VAR_LIST) {
    if (result.v_type == VAR_NUMBER && result.vval.v_number == 0) {
      // failure has already been indicated by provider
      errmsg = false;
    }
    goto err;
  }

  list_T *res = result.vval.v_list;
  list_T *lines = NULL;
  if (tv_list_len(res) == 2
      && TV_LIST_ITEM_TV(tv_list_first(res))->v_type == VAR_LIST) {
    lines = TV_LIST_ITEM_TV(tv_list_first(res))->vval.v_list;
    if (TV_LIST_ITEM_TV(tv_list_last(res))->v_type != VAR_STRING) {
      goto err;
    }
    char *regtype = TV_LIST_ITEM_TV(tv_list_last(res))->vval.v_string;
    if (regtype == NULL || strlen(regtype) > 1) {
      goto err;
    }
    switch (regtype[0]) {
    case 0:
      reg->y_type = kMTUnknown;
      break;
    case 'v':
    case 'c':
      reg->y_type = kMTCharWise;
      break;
    case 'V':
    case 'l':
      reg->y_type = kMTLineWise;
      break;
    case 'b':
    case Ctrl_V:
      reg->y_type = kMTBlockWise;
      break;
    default:
      goto err;
    }
  } else {
    lines = res;
    // provider did not specify regtype, calculate it below
    reg->y_type = kMTUnknown;
  }

  reg->y_array = xcalloc((size_t)tv_list_len(lines), sizeof(char *));
  reg->y_size = (size_t)tv_list_len(lines);
  reg->additional_data = NULL;
  reg->timestamp = 0;
  // Timestamp is not saved for clipboard registers because clipboard registers
  // are not saved in the ShaDa file.

  size_t tv_idx = 0;
  TV_LIST_ITER_CONST(lines, li, {
    if (TV_LIST_ITEM_TV(li)->v_type != VAR_STRING) {
      goto err;
    }
    reg->y_array[tv_idx++] = xstrdupnul(TV_LIST_ITEM_TV(li)->vval.v_string);
  });

  if (reg->y_size > 0 && strlen(reg->y_array[reg->y_size - 1]) == 0) {
    // a known-to-be charwise yank might have a final linebreak
    // but otherwise there is no line after the final newline
    if (reg->y_type != kMTCharWise) {
      xfree(reg->y_array[reg->y_size - 1]);
      reg->y_size--;
      if (reg->y_type == kMTUnknown) {
        reg->y_type = kMTLineWise;
      }
    }
  } else {
    if (reg->y_type == kMTUnknown) {
      reg->y_type = kMTCharWise;
    }
  }

  if (reg->y_type == kMTBlockWise) {
    size_t maxlen = 0;
    for (size_t i = 0; i < reg->y_size; i++) {
      size_t rowlen = strlen(reg->y_array[i]);
      if (rowlen > maxlen) {
        maxlen = rowlen;
      }
    }
    assert(maxlen <= INT_MAX);
    reg->y_width = (int)maxlen - 1;
  }

  *target = reg;
  return true;

err:
  if (reg->y_array) {
    for (size_t i = 0; i < reg->y_size; i++) {
      xfree(reg->y_array[i]);
    }
    xfree(reg->y_array);
  }
  reg->y_array = NULL;
  reg->y_size = 0;
  reg->additional_data = NULL;
  reg->timestamp = 0;
  if (errmsg) {
    emsg("clipboard: provider returned invalid data");
  }
  *target = reg;
  return false;
}

static void set_clipboard(int name, yankreg_T *reg)
{
  if (!adjust_clipboard_name(&name, false, true)) {
    return;
  }

  list_T *const lines = tv_list_alloc((ptrdiff_t)reg->y_size + (reg->y_type != kMTCharWise));

  for (size_t i = 0; i < reg->y_size; i++) {
    tv_list_append_string(lines, reg->y_array[i], -1);
  }

  char regtype;
  switch (reg->y_type) {
  case kMTLineWise:
    regtype = 'V';
    tv_list_append_string(lines, NULL, 0);
    break;
  case kMTCharWise:
    regtype = 'v';
    break;
  case kMTBlockWise:
    regtype = 'b';
    tv_list_append_string(lines, NULL, 0);
    break;
  case kMTUnknown:
    abort();
  }

  list_T *args = tv_list_alloc(3);
  tv_list_append_list(args, lines);
  tv_list_append_string(args, &regtype, 1);
  tv_list_append_string(args, ((char[]) { (char)name }), 1);

  eval_call_provider("clipboard", "set", args, true);
}

/// Avoid slow things (clipboard) during batch operations (while/for-loops).
void start_batch_changes(void)
{
  if (++batch_change_count > 1) {
    return;
  }
  clipboard_delay_update = true;
}

/// Counterpart to start_batch_changes().
void end_batch_changes(void)
{
  if (--batch_change_count > 0) {
    // recursive
    return;
  }
  clipboard_delay_update = false;
  if (clipboard_needs_update) {
    // must be before, as set_clipboard will invoke
    // start/end_batch_changes recursively
    clipboard_needs_update = false;
    // unnamed ("implicit" clipboard)
    set_clipboard(NUL, y_previous);
  }
}

int save_batch_count(void)
{
  int save_count = batch_change_count;
  batch_change_count = 0;
  clipboard_delay_update = false;
  if (clipboard_needs_update) {
    clipboard_needs_update = false;
    // unnamed ("implicit" clipboard)
    set_clipboard(NUL, y_previous);
  }
  return save_count;
}

void restore_batch_count(int save_count)
{
  assert(batch_change_count == 0);
  batch_change_count = save_count;
  if (batch_change_count > 0) {
    clipboard_delay_update = true;
  }
}

/// Check whether register is empty
static inline bool reg_empty(const yankreg_T *const reg)
  FUNC_ATTR_PURE
{
  return (reg->y_array == NULL
          || reg->y_size == 0
          || (reg->y_size == 1
              && reg->y_type == kMTCharWise
              && *(reg->y_array[0]) == NUL));
}

/// Iterate over global registers.
///
/// @see op_register_iter
const void *op_global_reg_iter(const void *const iter, char *const name, yankreg_T *const reg,
                               bool *is_unnamed)
  FUNC_ATTR_NONNULL_ARG(2, 3, 4) FUNC_ATTR_WARN_UNUSED_RESULT
{
  return op_reg_iter(iter, y_regs, name, reg, is_unnamed);
}

/// Iterate over registers `regs`.
///
/// @param[in]   iter      Iterator. Pass NULL to start iteration.
/// @param[in]   regs      Registers list to be iterated.
/// @param[out]  name      Register name.
/// @param[out]  reg       Register contents.
///
/// @return Pointer that must be passed to next `op_register_iter` call or
///         NULL if iteration is over.
const void *op_reg_iter(const void *const iter, const yankreg_T *const regs, char *const name,
                        yankreg_T *const reg, bool *is_unnamed)
  FUNC_ATTR_NONNULL_ARG(3, 4, 5) FUNC_ATTR_WARN_UNUSED_RESULT
{
  *name = NUL;
  const yankreg_T *iter_reg = (iter == NULL
                               ? &(regs[0])
                               : (const yankreg_T *const)iter);
  while (iter_reg - &(regs[0]) < NUM_SAVED_REGISTERS && reg_empty(iter_reg)) {
    iter_reg++;
  }
  if (iter_reg - &(regs[0]) == NUM_SAVED_REGISTERS || reg_empty(iter_reg)) {
    return NULL;
  }
  int iter_off = (int)(iter_reg - &(regs[0]));
  *name = (char)get_register_name(iter_off);
  *reg = *iter_reg;
  *is_unnamed = (iter_reg == y_previous);
  while (++iter_reg - &(regs[0]) < NUM_SAVED_REGISTERS) {
    if (!reg_empty(iter_reg)) {
      return (void *)iter_reg;
    }
  }
  return NULL;
}

/// Get a number of non-empty registers
size_t op_reg_amount(void)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t ret = 0;
  for (size_t i = 0; i < NUM_SAVED_REGISTERS; i++) {
    if (!reg_empty(y_regs + i)) {
      ret++;
    }
  }
  return ret;
}

/// Set register to a given value
///
/// @param[in]  name  Register name.
/// @param[in]  reg  Register value.
/// @param[in]  is_unnamed  Whether to set the unnamed regiseter to reg
///
/// @return true on success, false on failure.
bool op_reg_set(const char name, const yankreg_T reg, bool is_unnamed)
{
  int i = op_reg_index(name);
  if (i == -1) {
    return false;
  }
  free_register(&y_regs[i]);
  y_regs[i] = reg;

  if (is_unnamed) {
    y_previous = &y_regs[i];
  }
  return true;
}

/// Get register with the given name
///
/// @param[in]  name  Register name.
///
/// @return Pointer to the register contents or NULL.
const yankreg_T *op_reg_get(const char name)
{
  int i = op_reg_index(name);
  if (i == -1) {
    return NULL;
  }
  return &y_regs[i];
}

/// Set the previous yank register
///
/// @param[in]  name  Register name.
///
/// @return true on success, false on failure.
bool op_reg_set_previous(const char name)
{
  int i = op_reg_index(name);
  if (i == -1) {
    return false;
  }

  y_previous = &y_regs[i];
  return true;
}

/// Get the byte count of buffer region. End-exclusive.
///
/// @return number of bytes
bcount_t get_region_bytecount(buf_T *buf, linenr_T start_lnum, linenr_T end_lnum, colnr_T start_col,
                              colnr_T end_col)
{
  linenr_T max_lnum = buf->b_ml.ml_line_count;
  if (start_lnum > max_lnum) {
    return 0;
  }
  if (start_lnum == end_lnum) {
    return end_col - start_col;
  }
  bcount_t deleted_bytes = ml_get_buf_len(buf, start_lnum) - start_col + 1;

  for (linenr_T i = 1; i <= end_lnum - start_lnum - 1; i++) {
    if (start_lnum + i > max_lnum) {
      return deleted_bytes;
    }
    deleted_bytes += ml_get_buf_len(buf, start_lnum + i) + 1;
  }
  if (end_lnum > max_lnum) {
    return deleted_bytes;
  }
  return deleted_bytes + end_col;
}
