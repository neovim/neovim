/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * ops.c: implementation of various operators: op_shift, op_delete, op_tilde,
 *	  op_change, op_yank, do_put, do_join
 */

#include "vim.h"
#include "ops.h"
#include "buffer.h"
#include "charset.h"
#include "edit.h"
#include "eval.h"
#include "ex_cmds.h"
#include "ex_cmds2.h"
#include "ex_getln.h"
#include "fold.h"
#include "getchar.h"
#include "indent.h"
#include "mark.h"
#include "mbyte.h"
#include "memline.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"
#include "move.h"
#include "normal.h"
#include "option.h"
#include "screen.h"
#include "search.h"
#include "term.h"
#include "ui.h"
#include "undo.h"
#include "window.h"

/*
 * Number of registers.
 *	0 = unnamed register, for normal yanks and puts
 *   1..9 = registers '1' to '9', for deletes
 * 10..35 = registers 'a' to 'z'
 *     36 = delete register '-'
 *     37 = Selection register '*'. Only if FEAT_CLIPBOARD defined
 *     38 = Clipboard register '+'. Only if FEAT_CLIPBOARD and FEAT_X11 defined
 */
/*
 * Symbolic names for some registers.
 */
#define DELETION_REGISTER       36

# define NUM_REGISTERS          37

/*
 * Each yank register is an array of pointers to lines.
 */
static struct yankreg {
  char_u      **y_array;        /* pointer to array of line pointers */
  linenr_T y_size;              /* number of lines in y_array */
  char_u y_type;                /* MLINE, MCHAR or MBLOCK */
  colnr_T y_width;              /* only set if y_type == MBLOCK */
} y_regs[NUM_REGISTERS];

static struct yankreg   *y_current;         /* ptr to current yankreg */
static int y_append;                        /* TRUE when appending */
static struct yankreg   *y_previous = NULL; /* ptr to last written yankreg */

/*
 * structure used by block_prep, op_delete and op_yank for blockwise operators
 * also op_change, op_shift, op_insert, op_replace - AKelly
 */
struct block_def {
  int startspaces;              /* 'extra' cols before first char */
  int endspaces;                /* 'extra' cols after last char */
  int textlen;                  /* chars in block */
  char_u      *textstart;       /* pointer to 1st char (partially) in block */
  colnr_T textcol;              /* index of chars (partially) in block */
  colnr_T start_vcol;           /* start col of 1st char wholly inside block */
  colnr_T end_vcol;             /* start col of 1st char wholly after block */
  int is_short;                 /* TRUE if line is too short to fit in block */
  int is_MAX;                   /* TRUE if curswant==MAXCOL when starting */
  int is_oneChar;               /* TRUE if block within one character */
  int pre_whitesp;              /* screen cols of ws before block */
  int pre_whitesp_c;            /* chars of ws before block */
  colnr_T end_char_vcols;       /* number of vcols of post-block char */
  colnr_T start_char_vcols;       /* number of vcols of pre-block char */
};

static void shift_block(oparg_T *oap, int amount);
static void block_insert(oparg_T *oap, char_u *s, int b_insert,
                         struct block_def*bdp);
static int stuff_yank(int, char_u *);
static void put_reedit_in_typebuf(int silent);
static int put_in_typebuf(char_u *s, int esc, int colon,
                          int silent);
static void stuffescaped(char_u *arg, int literally);
static void mb_adjust_opend(oparg_T *oap);
static void free_yank(long);
static void free_yank_all(void);
static int yank_copy_line(struct block_def *bd, long y_idx);
static void dis_msg(char_u *p, int skip_esc);
static char_u   *skip_comment(char_u *line, int process,
                              int include_space,
                              int *is_comment);
static void block_prep(oparg_T *oap, struct block_def *, linenr_T, int);
static void str_to_reg(struct yankreg *y_ptr, int type, char_u *str,
                       long len,
                       long blocklen);
static int ends_in_white(linenr_T lnum);
static int same_leader(linenr_T lnum, int, char_u *, int, char_u *);
static int fmt_check_par(linenr_T, int *, char_u **, int do_comments);

/*
 * The names of operators.
 * IMPORTANT: Index must correspond with defines in vim.h!!!
 * The third field indicates whether the operator always works on lines.
 */
static char opchars[][3] =
{
  {NUL, NUL, FALSE},    /* OP_NOP */
  {'d', NUL, FALSE},    /* OP_DELETE */
  {'y', NUL, FALSE},    /* OP_YANK */
  {'c', NUL, FALSE},    /* OP_CHANGE */
  {'<', NUL, TRUE},     /* OP_LSHIFT */
  {'>', NUL, TRUE},     /* OP_RSHIFT */
  {'!', NUL, TRUE},     /* OP_FILTER */
  {'g', '~', FALSE},    /* OP_TILDE */
  {'=', NUL, TRUE},     /* OP_INDENT */
  {'g', 'q', TRUE},     /* OP_FORMAT */
  {':', NUL, TRUE},     /* OP_COLON */
  {'g', 'U', FALSE},    /* OP_UPPER */
  {'g', 'u', FALSE},    /* OP_LOWER */
  {'J', NUL, TRUE},     /* DO_JOIN */
  {'g', 'J', TRUE},     /* DO_JOIN_NS */
  {'g', '?', FALSE},    /* OP_ROT13 */
  {'r', NUL, FALSE},    /* OP_REPLACE */
  {'I', NUL, FALSE},    /* OP_INSERT */
  {'A', NUL, FALSE},    /* OP_APPEND */
  {'z', 'f', TRUE},     /* OP_FOLD */
  {'z', 'o', TRUE},     /* OP_FOLDOPEN */
  {'z', 'O', TRUE},     /* OP_FOLDOPENREC */
  {'z', 'c', TRUE},     /* OP_FOLDCLOSE */
  {'z', 'C', TRUE},     /* OP_FOLDCLOSEREC */
  {'z', 'd', TRUE},     /* OP_FOLDDEL */
  {'z', 'D', TRUE},     /* OP_FOLDDELREC */
  {'g', 'w', TRUE},     /* OP_FORMAT2 */
  {'g', '@', FALSE},    /* OP_FUNCTION */
};

/*
 * Translate a command name into an operator type.
 * Must only be called with a valid operator name!
 */
int get_op_type(int char1, int char2)
{
  int i;

  if (char1 == 'r')             /* ignore second character */
    return OP_REPLACE;
  if (char1 == '~')             /* when tilde is an operator */
    return OP_TILDE;
  for (i = 0;; ++i)
    if (opchars[i][0] == char1 && opchars[i][1] == char2)
      break;
  return i;
}

/*
 * Return TRUE if operator "op" always works on whole lines.
 */
int op_on_lines(int op)
{
  return opchars[op][2];
}

/*
 * Get first operator command character.
 * Returns 'g' or 'z' if there is another command character.
 */
int get_op_char(int optype)
{
  return opchars[optype][0];
}

/*
 * Get second operator command character.
 */
int get_extra_op_char(int optype)
{
  return opchars[optype][1];
}

/*
 * op_shift - handle a shift operation
 */
void op_shift(oparg_T *oap, int curs_top, int amount)
{
  long i;
  int first_char;
  char_u          *s;
  int block_col = 0;

  if (u_save((linenr_T)(oap->start.lnum - 1),
          (linenr_T)(oap->end.lnum + 1)) == FAIL)
    return;

  if (oap->block_mode)
    block_col = curwin->w_cursor.col;

  for (i = oap->line_count; --i >= 0; ) {
    first_char = *ml_get_curline();
    if (first_char == NUL)                              /* empty line */
      curwin->w_cursor.col = 0;
    else if (oap->block_mode)
      shift_block(oap, amount);
    else
    /* Move the line right if it doesn't start with '#', 'smartindent'
     * isn't set or 'cindent' isn't set or '#' isn't in 'cino'. */
    if (first_char != '#' || !preprocs_left()) {
      shift_line(oap->op_type == OP_LSHIFT, p_sr, amount, FALSE);
    }
    ++curwin->w_cursor.lnum;
  }

  changed_lines(oap->start.lnum, 0, oap->end.lnum + 1, 0L);
  /* The cursor line is not in a closed fold */
  foldOpenCursor();

  if (oap->block_mode) {
    curwin->w_cursor.lnum = oap->start.lnum;
    curwin->w_cursor.col = block_col;
  } else if (curs_top)    { /* put cursor on first line, for ">>" */
    curwin->w_cursor.lnum = oap->start.lnum;
    beginline(BL_SOL | BL_FIX);       /* shift_line() may have set cursor.col */
  } else
    --curwin->w_cursor.lnum;            /* put cursor on last line, for ":>" */

  if (oap->line_count > p_report) {
    if (oap->op_type == OP_RSHIFT)
      s = (char_u *)">";
    else
      s = (char_u *)"<";
    if (oap->line_count == 1) {
      if (amount == 1)
        sprintf((char *)IObuff, _("1 line %sed 1 time"), s);
      else
        sprintf((char *)IObuff, _("1 line %sed %d times"), s, amount);
    } else   {
      if (amount == 1)
        sprintf((char *)IObuff, _("%ld lines %sed 1 time"),
            oap->line_count, s);
      else
        sprintf((char *)IObuff, _("%ld lines %sed %d times"),
            oap->line_count, s, amount);
    }
    msg(IObuff);
  }

  /*
   * Set "'[" and "']" marks.
   */
  curbuf->b_op_start = oap->start;
  curbuf->b_op_end.lnum = oap->end.lnum;
  curbuf->b_op_end.col = (colnr_T)STRLEN(ml_get(oap->end.lnum));
  if (curbuf->b_op_end.col > 0)
    --curbuf->b_op_end.col;
}

/*
 * shift the current line one shiftwidth left (if left != 0) or right
 * leaves cursor on first blank in the line
 */
void 
shift_line (
    int left,
    int round,
    int amount,
    int call_changed_bytes         /* call changed_bytes() */
)
{
  int count;
  int i, j;
  int p_sw = (int)get_sw_value(curbuf);

  count = get_indent();         /* get current indent */

  if (round) {                  /* round off indent */
    i = count / p_sw;           /* number of p_sw rounded down */
    j = count % p_sw;           /* extra spaces */
    if (j && left)              /* first remove extra spaces */
      --amount;
    if (left) {
      i -= amount;
      if (i < 0)
        i = 0;
    } else
      i += amount;
    count = i * p_sw;
  } else   {            /* original vi indent */
    if (left) {
      count -= p_sw * amount;
      if (count < 0)
        count = 0;
    } else
      count += p_sw * amount;
  }

  /* Set new indent */
  if (State & VREPLACE_FLAG)
    change_indent(INDENT_SET, count, FALSE, NUL, call_changed_bytes);
  else
    (void)set_indent(count, call_changed_bytes ? SIN_CHANGED : 0);
}

/*
 * Shift one line of the current block one shiftwidth right or left.
 * Leaves cursor on first character in block.
 */
static void shift_block(oparg_T *oap, int amount)
{
  int left = (oap->op_type == OP_LSHIFT);
  int oldstate = State;
  int total;
  char_u              *newp, *oldp;
  int oldcol = curwin->w_cursor.col;
  int p_sw = (int)get_sw_value(curbuf);
  int p_ts = (int)curbuf->b_p_ts;
  struct block_def bd;
  int incr;
  colnr_T ws_vcol;
  int i = 0, j = 0;
  int len;
  int old_p_ri = p_ri;

  p_ri = 0;                     /* don't want revins in indent */

  State = INSERT;               /* don't want REPLACE for State */
  block_prep(oap, &bd, curwin->w_cursor.lnum, TRUE);
  if (bd.is_short)
    return;

  /* total is number of screen columns to be inserted/removed */
  total = amount * p_sw;
  oldp = ml_get_curline();

  if (!left) {
    /*
     *  1. Get start vcol
     *  2. Total ws vcols
     *  3. Divvy into TABs & spp
     *  4. Construct new string
     */
    total += bd.pre_whitesp;     /* all virtual WS upto & incl a split TAB */
    ws_vcol = bd.start_vcol - bd.pre_whitesp;
    if (bd.startspaces) {
      if (has_mbyte)
        bd.textstart += (*mb_ptr2len)(bd.textstart);
      else
        ++bd.textstart;
    }
    for (; vim_iswhite(*bd.textstart); ) {
      incr = lbr_chartabsize_adv(&bd.textstart, (colnr_T)(bd.start_vcol));
      total += incr;
      bd.start_vcol += incr;
    }
    /* OK, now total=all the VWS reqd, and textstart points at the 1st
     * non-ws char in the block. */
    if (!curbuf->b_p_et)
      i = ((ws_vcol % p_ts) + total) / p_ts;       /* number of tabs */
    if (i)
      j = ((ws_vcol % p_ts) + total) % p_ts;       /* number of spp */
    else
      j = total;
    /* if we're splitting a TAB, allow for it */
    bd.textcol -= bd.pre_whitesp_c - (bd.startspaces != 0);
    len = (int)STRLEN(bd.textstart) + 1;
    newp = alloc_check((unsigned)(bd.textcol + i + j + len));
    if (newp == NULL)
      return;
    vim_memset(newp, NUL, (size_t)(bd.textcol + i + j + len));
    mch_memmove(newp, oldp, (size_t)bd.textcol);
    copy_chars(newp + bd.textcol, (size_t)i, TAB);
    copy_spaces(newp + bd.textcol + i, (size_t)j);
    /* the end */
    mch_memmove(newp + bd.textcol + i + j, bd.textstart, (size_t)len);
  } else   { /* left */
    colnr_T destination_col;            /* column to which text in block will
                                           be shifted */
    char_u      *verbatim_copy_end;     /* end of the part of the line which is
                                           copied verbatim */
    colnr_T verbatim_copy_width;        /* the (displayed) width of this part
                                           of line */
    unsigned fill;                      /* nr of spaces that replace a TAB */
    unsigned new_line_len;              /* the length of the line after the
                                           block shift */
    size_t block_space_width;
    size_t shift_amount;
    char_u      *non_white = bd.textstart;
    colnr_T non_white_col;

    /*
     * Firstly, let's find the first non-whitespace character that is
     * displayed after the block's start column and the character's column
     * number. Also, let's calculate the width of all the whitespace
     * characters that are displayed in the block and precede the searched
     * non-whitespace character.
     */

    /* If "bd.startspaces" is set, "bd.textstart" points to the character,
     * the part of which is displayed at the block's beginning. Let's start
     * searching from the next character. */
    if (bd.startspaces)
      mb_ptr_adv(non_white);

    /* The character's column is in "bd.start_vcol".  */
    non_white_col = bd.start_vcol;

    while (vim_iswhite(*non_white)) {
      incr = lbr_chartabsize_adv(&non_white, non_white_col);
      non_white_col += incr;
    }

    block_space_width = non_white_col - oap->start_vcol;
    /* We will shift by "total" or "block_space_width", whichever is less.
     */
    shift_amount = (block_space_width < (size_t)total
                    ? block_space_width : (size_t)total);

    /* The column to which we will shift the text.  */
    destination_col = (colnr_T)(non_white_col - shift_amount);

    /* Now let's find out how much of the beginning of the line we can
     * reuse without modification.  */
    verbatim_copy_end = bd.textstart;
    verbatim_copy_width = bd.start_vcol;

    /* If "bd.startspaces" is set, "bd.textstart" points to the character
     * preceding the block. We have to subtract its width to obtain its
     * column number.  */
    if (bd.startspaces)
      verbatim_copy_width -= bd.start_char_vcols;
    while (verbatim_copy_width < destination_col) {
      incr = lbr_chartabsize(verbatim_copy_end, verbatim_copy_width);
      if (verbatim_copy_width + incr > destination_col)
        break;
      verbatim_copy_width += incr;
      mb_ptr_adv(verbatim_copy_end);
    }

    /* If "destination_col" is different from the width of the initial
    * part of the line that will be copied, it means we encountered a tab
    * character, which we will have to partly replace with spaces.  */
    fill = destination_col - verbatim_copy_width;

    /* The replacement line will consist of:
     * - the beginning of the original line up to "verbatim_copy_end",
     * - "fill" number of spaces,
     * - the rest of the line, pointed to by non_white.  */
    new_line_len = (unsigned)(verbatim_copy_end - oldp)
                   + fill
                   + (unsigned)STRLEN(non_white) + 1;

    newp = alloc_check(new_line_len);
    if (newp == NULL)
      return;
    mch_memmove(newp, oldp, (size_t)(verbatim_copy_end - oldp));
    copy_spaces(newp + (verbatim_copy_end - oldp), (size_t)fill);
    STRMOVE(newp + (verbatim_copy_end - oldp) + fill, non_white);
  }
  /* replace the line */
  ml_replace(curwin->w_cursor.lnum, newp, FALSE);
  changed_bytes(curwin->w_cursor.lnum, (colnr_T)bd.textcol);
  State = oldstate;
  curwin->w_cursor.col = oldcol;
  p_ri = old_p_ri;
}

/*
 * Insert string "s" (b_insert ? before : after) block :AKelly
 * Caller must prepare for undo.
 */
static void block_insert(oparg_T *oap, char_u *s, int b_insert, struct block_def *bdp)
{
  int p_ts;
  int count = 0;                /* extra spaces to replace a cut TAB */
  int spaces = 0;               /* non-zero if cutting a TAB */
  colnr_T offset;               /* pointer along new line */
  unsigned s_len;               /* STRLEN(s) */
  char_u      *newp, *oldp;     /* new, old lines */
  linenr_T lnum;                /* loop var */
  int oldstate = State;

  State = INSERT;               /* don't want REPLACE for State */
  s_len = (unsigned)STRLEN(s);

  for (lnum = oap->start.lnum + 1; lnum <= oap->end.lnum; lnum++) {
    block_prep(oap, bdp, lnum, TRUE);
    if (bdp->is_short && b_insert)
      continue;         /* OP_INSERT, line ends before block start */

    oldp = ml_get(lnum);

    if (b_insert) {
      p_ts = bdp->start_char_vcols;
      spaces = bdp->startspaces;
      if (spaces != 0)
        count = p_ts - 1;         /* we're cutting a TAB */
      offset = bdp->textcol;
    } else   { /* append */
      p_ts = bdp->end_char_vcols;
      if (!bdp->is_short) {     /* spaces = padding after block */
        spaces = (bdp->endspaces ? p_ts - bdp->endspaces : 0);
        if (spaces != 0)
          count = p_ts - 1;           /* we're cutting a TAB */
        offset = bdp->textcol + bdp->textlen - (spaces != 0);
      } else   { /* spaces = padding to block edge */
                 /* if $ used, just append to EOL (ie spaces==0) */
        if (!bdp->is_MAX)
          spaces = (oap->end_vcol - bdp->end_vcol) + 1;
        count = spaces;
        offset = bdp->textcol + bdp->textlen;
      }
    }

    newp = alloc_check((unsigned)(STRLEN(oldp)) + s_len + count + 1);
    if (newp == NULL)
      continue;

    /* copy up to shifted part */
    mch_memmove(newp, oldp, (size_t)(offset));
    oldp += offset;

    /* insert pre-padding */
    copy_spaces(newp + offset, (size_t)spaces);

    /* copy the new text */
    mch_memmove(newp + offset + spaces, s, (size_t)s_len);
    offset += s_len;

    if (spaces && !bdp->is_short) {
      /* insert post-padding */
      copy_spaces(newp + offset + spaces, (size_t)(p_ts - spaces));
      /* We're splitting a TAB, don't copy it. */
      oldp++;
      /* We allowed for that TAB, remember this now */
      count++;
    }

    if (spaces > 0)
      offset += count;
    STRMOVE(newp + offset, oldp);

    ml_replace(lnum, newp, FALSE);

    if (lnum == oap->end.lnum) {
      /* Set "']" mark to the end of the block instead of the end of
       * the insert in the first line.  */
      curbuf->b_op_end.lnum = oap->end.lnum;
      curbuf->b_op_end.col = offset;
    }
  }   /* for all lnum */

  changed_lines(oap->start.lnum + 1, 0, oap->end.lnum + 1, 0L);

  State = oldstate;
}

/*
 * op_reindent - handle reindenting a block of lines.
 */
void op_reindent(oap, how)
oparg_T     *oap;
int         (*how)(void);
{
  long i;
  char_u      *l;
  int count;
  linenr_T first_changed = 0;
  linenr_T last_changed = 0;
  linenr_T start_lnum = curwin->w_cursor.lnum;

  /* Don't even try when 'modifiable' is off. */
  if (!curbuf->b_p_ma) {
    EMSG(_(e_modifiable));
    return;
  }

  for (i = oap->line_count; --i >= 0 && !got_int; ) {
    /* it's a slow thing to do, so give feedback so there's no worry that
     * the computer's just hung. */

    if (i > 1
        && (i % 50 == 0 || i == oap->line_count - 1)
        && oap->line_count > p_report)
      smsg((char_u *)_("%ld lines to indent... "), i);

    /*
     * Be vi-compatible: For lisp indenting the first line is not
     * indented, unless there is only one line.
     */
    if (i != oap->line_count - 1 || oap->line_count == 1
        || how != get_lisp_indent) {
      l = skipwhite(ml_get_curline());
      if (*l == NUL)                        /* empty or blank line */
        count = 0;
      else
        count = how();                      /* get the indent for this line */

      if (set_indent(count, SIN_UNDO)) {
        /* did change the indent, call changed_lines() later */
        if (first_changed == 0)
          first_changed = curwin->w_cursor.lnum;
        last_changed = curwin->w_cursor.lnum;
      }
    }
    ++curwin->w_cursor.lnum;
    curwin->w_cursor.col = 0;      /* make sure it's valid */
  }

  /* put cursor on first non-blank of indented line */
  curwin->w_cursor.lnum = start_lnum;
  beginline(BL_SOL | BL_FIX);

  /* Mark changed lines so that they will be redrawn.  When Visual
   * highlighting was present, need to continue until the last line.  When
   * there is no change still need to remove the Visual highlighting. */
  if (last_changed != 0)
    changed_lines(first_changed, 0,
        oap->is_VIsual ? start_lnum + oap->line_count :
        last_changed + 1, 0L);
  else if (oap->is_VIsual)
    redraw_curbuf_later(INVERTED);

  if (oap->line_count > p_report) {
    i = oap->line_count - (i + 1);
    if (i == 1)
      MSG(_("1 line indented "));
    else
      smsg((char_u *)_("%ld lines indented "), i);
  }
  /* set '[ and '] marks */
  curbuf->b_op_start = oap->start;
  curbuf->b_op_end = oap->end;
}

/*
 * Keep the last expression line here, for repeating.
 */
static char_u   *expr_line = NULL;

/*
 * Get an expression for the "\"=expr1" or "CTRL-R =expr1"
 * Returns '=' when OK, NUL otherwise.
 */
int get_expr_register(void)         {
  char_u      *new_line;

  new_line = getcmdline('=', 0L, 0);
  if (new_line == NULL)
    return NUL;
  if (*new_line == NUL)         /* use previous line */
    vim_free(new_line);
  else
    set_expr_line(new_line);
  return '=';
}

/*
 * Set the expression for the '=' register.
 * Argument must be an allocated string.
 */
void set_expr_line(char_u *new_line)
{
  vim_free(expr_line);
  expr_line = new_line;
}

/*
 * Get the result of the '=' register expression.
 * Returns a pointer to allocated memory, or NULL for failure.
 */
char_u *get_expr_line(void)              {
  char_u      *expr_copy;
  char_u      *rv;
  static int nested = 0;

  if (expr_line == NULL)
    return NULL;

  /* Make a copy of the expression, because evaluating it may cause it to be
   * changed. */
  expr_copy = vim_strsave(expr_line);
  if (expr_copy == NULL)
    return NULL;

  /* When we are invoked recursively limit the evaluation to 10 levels.
   * Then return the string as-is. */
  if (nested >= 10)
    return expr_copy;

  ++nested;
  rv = eval_to_string(expr_copy, NULL, TRUE);
  --nested;
  vim_free(expr_copy);
  return rv;
}

/*
 * Get the '=' register expression itself, without evaluating it.
 */
char_u *get_expr_line_src(void)              {
  if (expr_line == NULL)
    return NULL;
  return vim_strsave(expr_line);
}

/*
 * Check if 'regname' is a valid name of a yank register.
 * Note: There is no check for 0 (default register), caller should do this
 */
int 
valid_yank_reg (
    int regname,
    int writing                /* if TRUE check for writable registers */
)
{
  if (       (regname > 0 && ASCII_ISALNUM(regname))
             || (!writing && vim_strchr((char_u *)
                     "/.%#:="
                     , regname) != NULL)
             || regname == '"'
             || regname == '-'
             || regname == '_'
             )
    return TRUE;
  return FALSE;
}

/*
 * Set y_current and y_append, according to the value of "regname".
 * Cannot handle the '_' register.
 * Must only be called with a valid register name!
 *
 * If regname is 0 and writing, use register 0
 * If regname is 0 and reading, use previous register
 */
void get_yank_register(int regname, int writing)
{
  int i;

  y_append = FALSE;
  if ((regname == 0 || regname == '"') && !writing && y_previous != NULL) {
    y_current = y_previous;
    return;
  }
  i = regname;
  if (VIM_ISDIGIT(i))
    i -= '0';
  else if (ASCII_ISLOWER(i))
    i = CharOrdLow(i) + 10;
  else if (ASCII_ISUPPER(i)) {
    i = CharOrdUp(i) + 10;
    y_append = TRUE;
  } else if (regname == '-')
    i = DELETION_REGISTER;
  else                  /* not 0-9, a-z, A-Z or '-': use register 0 */
    i = 0;
  y_current = &(y_regs[i]);
  if (writing)          /* remember the register we write into for do_put() */
    y_previous = y_current;
}


/*
 * Obtain the contents of a "normal" register. The register is made empty.
 * The returned pointer has allocated memory, use put_register() later.
 */
void *
get_register (
    int name,
    int copy               /* make a copy, if FALSE make register empty. */
)
{
  struct yankreg      *reg;
  int i;


  get_yank_register(name, 0);
  reg = (struct yankreg *)alloc((unsigned)sizeof(struct yankreg));
  if (reg != NULL) {
    *reg = *y_current;
    if (copy) {
      /* If we run out of memory some or all of the lines are empty. */
      if (reg->y_size == 0)
        reg->y_array = NULL;
      else
        reg->y_array = (char_u **)alloc((unsigned)(sizeof(char_u *)
                                                   * reg->y_size));
      if (reg->y_array != NULL) {
        for (i = 0; i < reg->y_size; ++i)
          reg->y_array[i] = vim_strsave(y_current->y_array[i]);
      }
    } else
      y_current->y_array = NULL;
  }
  return (void *)reg;
}

/*
 * Put "reg" into register "name".  Free any previous contents and "reg".
 */
void put_register(int name, void *reg)
{
  get_yank_register(name, 0);
  free_yank_all();
  *y_current = *(struct yankreg *)reg;
  vim_free(reg);

}

void free_register(void *reg)
{
  struct yankreg tmp;

  tmp = *y_current;
  *y_current = *(struct yankreg *)reg;
  free_yank_all();
  vim_free(reg);
  *y_current = tmp;
}

/*
 * return TRUE if the current yank register has type MLINE
 */
int yank_register_mline(int regname)
{
  if (regname != 0 && !valid_yank_reg(regname, FALSE))
    return FALSE;
  if (regname == '_')           /* black hole is always empty */
    return FALSE;
  get_yank_register(regname, FALSE);
  return y_current->y_type == MLINE;
}

/*
 * Start or stop recording into a yank register.
 *
 * Return FAIL for failure, OK otherwise.
 */
int do_record(int c)
{
  char_u          *p;
  static int regname;
  struct yankreg  *old_y_previous, *old_y_current;
  int retval;

  if (Recording == FALSE) {         /* start recording */
    /* registers 0-9, a-z and " are allowed */
    if (c < 0 || (!ASCII_ISALNUM(c) && c != '"'))
      retval = FAIL;
    else {
      Recording = TRUE;
      showmode();
      regname = c;
      retval = OK;
    }
  } else   {                        /* stop recording */
    /*
     * Get the recorded key hits.  K_SPECIAL and CSI will be escaped, this
     * needs to be removed again to put it in a register.  exec_reg then
     * adds the escaping back later.
     */
    Recording = FALSE;
    MSG("");
    p = get_recorded();
    if (p == NULL)
      retval = FAIL;
    else {
      /* Remove escaping for CSI and K_SPECIAL in multi-byte chars. */
      vim_unescape_csi(p);

      /*
       * We don't want to change the default register here, so save and
       * restore the current register name.
       */
      old_y_previous = y_previous;
      old_y_current = y_current;

      retval = stuff_yank(regname, p);

      y_previous = old_y_previous;
      y_current = old_y_current;
    }
  }
  return retval;
}

/*
 * Stuff string "p" into yank register "regname" as a single line (append if
 * uppercase).	"p" must have been alloced.
 *
 * return FAIL for failure, OK otherwise
 */
static int stuff_yank(int regname, char_u *p)
{
  char_u      *lp;
  char_u      **pp;

  /* check for read-only register */
  if (regname != 0 && !valid_yank_reg(regname, TRUE)) {
    vim_free(p);
    return FAIL;
  }
  if (regname == '_') {             /* black hole: don't do anything */
    vim_free(p);
    return OK;
  }
  get_yank_register(regname, TRUE);
  if (y_append && y_current->y_array != NULL) {
    pp = &(y_current->y_array[y_current->y_size - 1]);
    lp = lalloc((long_u)(STRLEN(*pp) + STRLEN(p) + 1), TRUE);
    if (lp == NULL) {
      vim_free(p);
      return FAIL;
    }
    STRCPY(lp, *pp);
    STRCAT(lp, p);
    vim_free(p);
    vim_free(*pp);
    *pp = lp;
  } else   {
    free_yank_all();
    if ((y_current->y_array =
           (char_u **)alloc((unsigned)sizeof(char_u *))) == NULL) {
      vim_free(p);
      return FAIL;
    }
    y_current->y_array[0] = p;
    y_current->y_size = 1;
    y_current->y_type = MCHAR;      /* used to be MLINE, why? */
  }
  return OK;
}

static int execreg_lastc = NUL;

/*
 * execute a yank register: copy it into the stuff buffer
 *
 * return FAIL for failure, OK otherwise
 */
int 
do_execreg (
    int regname,
    int colon,                      /* insert ':' before each line */
    int addcr,                      /* always add '\n' to end of line */
    int silent                     /* set "silent" flag in typeahead buffer */
)
{
  long i;
  char_u      *p;
  int retval = OK;
  int remap;

  if (regname == '@') {                 /* repeat previous one */
    if (execreg_lastc == NUL) {
      EMSG(_("E748: No previously used register"));
      return FAIL;
    }
    regname = execreg_lastc;
  }
  /* check for valid regname */
  if (regname == '%' || regname == '#' || !valid_yank_reg(regname, FALSE)) {
    emsg_invreg(regname);
    return FAIL;
  }
  execreg_lastc = regname;


  if (regname == '_')                   /* black hole: don't stuff anything */
    return OK;

  if (regname == ':') {                 /* use last command line */
    if (last_cmdline == NULL) {
      EMSG(_(e_nolastcmd));
      return FAIL;
    }
    vim_free(new_last_cmdline);     /* don't keep the cmdline containing @: */
    new_last_cmdline = NULL;
    /* Escape all control characters with a CTRL-V */
    p = vim_strsave_escaped_ext(
        last_cmdline,
        (char_u *)
        "\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037",
        Ctrl_V, FALSE);
    if (p != NULL) {
      /* When in Visual mode "'<,'>" will be prepended to the command.
       * Remove it when it's already there. */
      if (VIsual_active && STRNCMP(p, "'<,'>", 5) == 0)
        retval = put_in_typebuf(p + 5, TRUE, TRUE, silent);
      else
        retval = put_in_typebuf(p, TRUE, TRUE, silent);
    }
    vim_free(p);
  } else if (regname == '=')   {
    p = get_expr_line();
    if (p == NULL)
      return FAIL;
    retval = put_in_typebuf(p, TRUE, colon, silent);
    vim_free(p);
  } else if (regname == '.')   {        /* use last inserted text */
    p = get_last_insert_save();
    if (p == NULL) {
      EMSG(_(e_noinstext));
      return FAIL;
    }
    retval = put_in_typebuf(p, FALSE, colon, silent);
    vim_free(p);
  } else   {
    get_yank_register(regname, FALSE);
    if (y_current->y_array == NULL)
      return FAIL;

    /* Disallow remaping for ":@r". */
    remap = colon ? REMAP_NONE : REMAP_YES;

    /*
     * Insert lines into typeahead buffer, from last one to first one.
     */
    put_reedit_in_typebuf(silent);
    for (i = y_current->y_size; --i >= 0; ) {
      char_u *escaped;

      /* insert NL between lines and after last line if type is MLINE */
      if (y_current->y_type == MLINE || i < y_current->y_size - 1
          || addcr) {
        if (ins_typebuf((char_u *)"\n", remap, 0, TRUE, silent) == FAIL)
          return FAIL;
      }
      escaped = vim_strsave_escape_csi(y_current->y_array[i]);
      if (escaped == NULL)
        return FAIL;
      retval = ins_typebuf(escaped, remap, 0, TRUE, silent);
      vim_free(escaped);
      if (retval == FAIL)
        return FAIL;
      if (colon && ins_typebuf((char_u *)":", remap, 0, TRUE, silent)
          == FAIL)
        return FAIL;
    }
    Exec_reg = TRUE;            /* disable the 'q' command */
  }
  return retval;
}

/*
 * If "restart_edit" is not zero, put it in the typeahead buffer, so that it's
 * used only after other typeahead has been processed.
 */
static void put_reedit_in_typebuf(int silent)
{
  char_u buf[3];

  if (restart_edit != NUL) {
    if (restart_edit == 'V') {
      buf[0] = 'g';
      buf[1] = 'R';
      buf[2] = NUL;
    } else   {
      buf[0] = restart_edit == 'I' ? 'i' : restart_edit;
      buf[1] = NUL;
    }
    if (ins_typebuf(buf, REMAP_NONE, 0, TRUE, silent) == OK)
      restart_edit = NUL;
  }
}

/*
 * Insert register contents "s" into the typeahead buffer, so that it will be
 * executed again.
 * When "esc" is TRUE it is to be taken literally: Escape CSI characters and
 * no remapping.
 */
static int 
put_in_typebuf (
    char_u *s,
    int esc,
    int colon,                  /* add ':' before the line */
    int silent
)
{
  int retval = OK;

  put_reedit_in_typebuf(silent);
  if (colon)
    retval = ins_typebuf((char_u *)"\n", REMAP_NONE, 0, TRUE, silent);
  if (retval == OK) {
    char_u  *p;

    if (esc)
      p = vim_strsave_escape_csi(s);
    else
      p = s;
    if (p == NULL)
      retval = FAIL;
    else
      retval = ins_typebuf(p, esc ? REMAP_NONE : REMAP_YES,
          0, TRUE, silent);
    if (esc)
      vim_free(p);
  }
  if (colon && retval == OK)
    retval = ins_typebuf((char_u *)":", REMAP_NONE, 0, TRUE, silent);
  return retval;
}

/*
 * Insert a yank register: copy it into the Read buffer.
 * Used by CTRL-R command and middle mouse button in insert mode.
 *
 * return FAIL for failure, OK otherwise
 */
int 
insert_reg (
    int regname,
    int literally                  /* insert literally, not as if typed */
)
{
  long i;
  int retval = OK;
  char_u      *arg;
  int allocated;

  /*
   * It is possible to get into an endless loop by having CTRL-R a in
   * register a and then, in insert mode, doing CTRL-R a.
   * If you hit CTRL-C, the loop will be broken here.
   */
  ui_breakcheck();
  if (got_int)
    return FAIL;

  /* check for valid regname */
  if (regname != NUL && !valid_yank_reg(regname, FALSE))
    return FAIL;


  if (regname == '.')                   /* insert last inserted text */
    retval = stuff_inserted(NUL, 1L, TRUE);
  else if (get_spec_reg(regname, &arg, &allocated, TRUE)) {
    if (arg == NULL)
      return FAIL;
    stuffescaped(arg, literally);
    if (allocated)
      vim_free(arg);
  } else   {                            /* name or number register */
    get_yank_register(regname, FALSE);
    if (y_current->y_array == NULL)
      retval = FAIL;
    else {
      for (i = 0; i < y_current->y_size; ++i) {
        stuffescaped(y_current->y_array[i], literally);
        /*
         * Insert a newline between lines and after last line if
         * y_type is MLINE.
         */
        if (y_current->y_type == MLINE || i < y_current->y_size - 1)
          stuffcharReadbuff('\n');
      }
    }
  }

  return retval;
}

/*
 * Stuff a string into the typeahead buffer, such that edit() will insert it
 * literally ("literally" TRUE) or interpret is as typed characters.
 */
static void stuffescaped(char_u *arg, int literally)
{
  int c;
  char_u      *start;

  while (*arg != NUL) {
    /* Stuff a sequence of normal ASCII characters, that's fast.  Also
     * stuff K_SPECIAL to get the effect of a special key when "literally"
     * is TRUE. */
    start = arg;
    while ((*arg >= ' '
            && *arg < DEL         /* EBCDIC: chars above space are normal */
            )
           || (*arg == K_SPECIAL && !literally))
      ++arg;
    if (arg > start)
      stuffReadbuffLen(start, (long)(arg - start));

    /* stuff a single special character */
    if (*arg != NUL) {
      if (has_mbyte)
        c = mb_cptr2char_adv(&arg);
      else
        c = *arg++;
      if (literally && ((c < ' ' && c != TAB) || c == DEL))
        stuffcharReadbuff(Ctrl_V);
      stuffcharReadbuff(c);
    }
  }
}

/*
 * If "regname" is a special register, return TRUE and store a pointer to its
 * value in "argp".
 */
int 
get_spec_reg (
    int regname,
    char_u **argp,
    int *allocated,         /* return: TRUE when value was allocated */
    int errmsg                     /* give error message when failing */
)
{
  int cnt;

  *argp = NULL;
  *allocated = FALSE;
  switch (regname) {
  case '%':                     /* file name */
    if (errmsg)
      check_fname();            /* will give emsg if not set */
    *argp = curbuf->b_fname;
    return TRUE;

  case '#':                     /* alternate file name */
    *argp = getaltfname(errmsg);                /* may give emsg if not set */
    return TRUE;

  case '=':                     /* result of expression */
    *argp = get_expr_line();
    *allocated = TRUE;
    return TRUE;

  case ':':                     /* last command line */
    if (last_cmdline == NULL && errmsg)
      EMSG(_(e_nolastcmd));
    *argp = last_cmdline;
    return TRUE;

  case '/':                     /* last search-pattern */
    if (last_search_pat() == NULL && errmsg)
      EMSG(_(e_noprevre));
    *argp = last_search_pat();
    return TRUE;

  case '.':                     /* last inserted text */
    *argp = get_last_insert_save();
    *allocated = TRUE;
    if (*argp == NULL && errmsg)
      EMSG(_(e_noinstext));
    return TRUE;

  case Ctrl_F:                  /* Filename under cursor */
  case Ctrl_P:                  /* Path under cursor, expand via "path" */
    if (!errmsg)
      return FALSE;
    *argp = file_name_at_cursor(FNAME_MESS | FNAME_HYP
        | (regname == Ctrl_P ? FNAME_EXP : 0), 1L, NULL);
    *allocated = TRUE;
    return TRUE;

  case Ctrl_W:                  /* word under cursor */
  case Ctrl_A:                  /* WORD (mnemonic All) under cursor */
    if (!errmsg)
      return FALSE;
    cnt = find_ident_under_cursor(argp, regname == Ctrl_W
        ?  (FIND_IDENT|FIND_STRING) : FIND_STRING);
    *argp = cnt ? vim_strnsave(*argp, cnt) : NULL;
    *allocated = TRUE;
    return TRUE;

  case '_':                     /* black hole: always empty */
    *argp = (char_u *)"";
    return TRUE;
  }

  return FALSE;
}

/*
 * Paste a yank register into the command line.
 * Only for non-special registers.
 * Used by CTRL-R command in command-line mode
 * insert_reg() can't be used here, because special characters from the
 * register contents will be interpreted as commands.
 *
 * return FAIL for failure, OK otherwise
 */
int 
cmdline_paste_reg (
    int regname,
    int literally,          /* Insert text literally instead of "as typed" */
    int remcr              /* don't add trailing CR */
)
{
  long i;

  get_yank_register(regname, FALSE);
  if (y_current->y_array == NULL)
    return FAIL;

  for (i = 0; i < y_current->y_size; ++i) {
    cmdline_paste_str(y_current->y_array[i], literally);

    /* Insert ^M between lines and after last line if type is MLINE.
     * Don't do this when "remcr" is TRUE and the next line is empty. */
    if (y_current->y_type == MLINE
        || (i < y_current->y_size - 1
            && !(remcr
                 && i == y_current->y_size - 2
                 && *y_current->y_array[i + 1] == NUL)))
      cmdline_paste_str((char_u *)"\r", literally);

    /* Check for CTRL-C, in case someone tries to paste a few thousand
     * lines and gets bored. */
    ui_breakcheck();
    if (got_int)
      return FAIL;
  }
  return OK;
}


/*
 * Handle a delete operation.
 *
 * Return FAIL if undo failed, OK otherwise.
 */
int op_delete(oparg_T *oap)
{
  int n;
  linenr_T lnum;
  char_u              *ptr;
  char_u              *newp, *oldp;
  struct block_def bd;
  linenr_T old_lcount = curbuf->b_ml.ml_line_count;
  int did_yank = FALSE;
  int orig_regname = oap->regname;

  if (curbuf->b_ml.ml_flags & ML_EMPTY)             /* nothing to do */
    return OK;

  /* Nothing to delete, return here.	Do prepare undo, for op_change(). */
  if (oap->empty)
    return u_save_cursor();

  if (!curbuf->b_p_ma) {
    EMSG(_(e_modifiable));
    return FAIL;
  }


  if (has_mbyte)
    mb_adjust_opend(oap);

  /*
   * Imitate the strange Vi behaviour: If the delete spans more than one
   * line and motion_type == MCHAR and the result is a blank line, make the
   * delete linewise.  Don't do this for the change command or Visual mode.
   */
  if (       oap->motion_type == MCHAR
             && !oap->is_VIsual
             && !oap->block_mode
             && oap->line_count > 1
             && oap->motion_force == NUL
             && oap->op_type == OP_DELETE) {
    ptr = ml_get(oap->end.lnum) + oap->end.col;
    if (*ptr != NUL)
      ptr += oap->inclusive;
    ptr = skipwhite(ptr);
    if (*ptr == NUL && inindent(0))
      oap->motion_type = MLINE;
  }

  /*
   * Check for trying to delete (e.g. "D") in an empty line.
   * Note: For the change operator it is ok.
   */
  if (       oap->motion_type == MCHAR
             && oap->line_count == 1
             && oap->op_type == OP_DELETE
             && *ml_get(oap->start.lnum) == NUL) {
    /*
     * It's an error to operate on an empty region, when 'E' included in
     * 'cpoptions' (Vi compatible).
     */
    if (virtual_op)
      /* Virtual editing: Nothing gets deleted, but we set the '[ and ']
       * marks as if it happened. */
      goto setmarks;
    if (vim_strchr(p_cpo, CPO_EMPTYREGION) != NULL)
      beep_flush();
    return OK;
  }

  /*
   * Do a yank of whatever we're about to delete.
   * If a yank register was specified, put the deleted text into that
   * register.  For the black hole register '_' don't yank anything.
   */
  if (oap->regname != '_') {
    if (oap->regname != 0) {
      /* check for read-only register */
      if (!valid_yank_reg(oap->regname, TRUE)) {
        beep_flush();
        return OK;
      }
      get_yank_register(oap->regname, TRUE);       /* yank into specif'd reg. */
      if (op_yank(oap, TRUE, FALSE) == OK)         /* yank without message */
        did_yank = TRUE;
    }

    /*
     * Put deleted text into register 1 and shift number registers if the
     * delete contains a line break, or when a regname has been specified.
     * Use the register name from before adjust_clip_reg() may have
     * changed it.
     */
    if (orig_regname != 0 || oap->motion_type == MLINE
        || oap->line_count > 1 || oap->use_reg_one) {
      y_current = &y_regs[9];
      free_yank_all();                          /* free register nine */
      for (n = 9; n > 1; --n)
        y_regs[n] = y_regs[n - 1];
      y_previous = y_current = &y_regs[1];
      y_regs[1].y_array = NULL;                 /* set register one to empty */
      if (op_yank(oap, TRUE, FALSE) == OK)
        did_yank = TRUE;
    }

    /* Yank into small delete register when no named register specified
     * and the delete is within one line. */
    if ((
          oap->regname == 0) && oap->motion_type != MLINE
        && oap->line_count == 1) {
      oap->regname = '-';
      get_yank_register(oap->regname, TRUE);
      if (op_yank(oap, TRUE, FALSE) == OK)
        did_yank = TRUE;
      oap->regname = 0;
    }

    /*
     * If there's too much stuff to fit in the yank register, then get a
     * confirmation before doing the delete. This is crude, but simple.
     * And it avoids doing a delete of something we can't put back if we
     * want.
     */
    if (!did_yank) {
      int msg_silent_save = msg_silent;

      msg_silent = 0;           /* must display the prompt */
      n = ask_yesno((char_u *)_("cannot yank; delete anyway"), TRUE);
      msg_silent = msg_silent_save;
      if (n != 'y') {
        EMSG(_(e_abort));
        return FAIL;
      }
    }
  }

  /*
   * block mode delete
   */
  if (oap->block_mode) {
    if (u_save((linenr_T)(oap->start.lnum - 1),
            (linenr_T)(oap->end.lnum + 1)) == FAIL)
      return FAIL;

    for (lnum = curwin->w_cursor.lnum; lnum <= oap->end.lnum; ++lnum) {
      block_prep(oap, &bd, lnum, TRUE);
      if (bd.textlen == 0)              /* nothing to delete */
        continue;

      /* Adjust cursor position for tab replaced by spaces and 'lbr'. */
      if (lnum == curwin->w_cursor.lnum) {
        curwin->w_cursor.col = bd.textcol + bd.startspaces;
        curwin->w_cursor.coladd = 0;
      }

      /* n == number of chars deleted
       * If we delete a TAB, it may be replaced by several characters.
       * Thus the number of characters may increase!
       */
      n = bd.textlen - bd.startspaces - bd.endspaces;
      oldp = ml_get(lnum);
      newp = alloc_check((unsigned)STRLEN(oldp) + 1 - n);
      if (newp == NULL)
        continue;
      /* copy up to deleted part */
      mch_memmove(newp, oldp, (size_t)bd.textcol);
      /* insert spaces */
      copy_spaces(newp + bd.textcol,
          (size_t)(bd.startspaces + bd.endspaces));
      /* copy the part after the deleted part */
      oldp += bd.textcol + bd.textlen;
      STRMOVE(newp + bd.textcol + bd.startspaces + bd.endspaces, oldp);
      /* replace the line */
      ml_replace(lnum, newp, FALSE);
    }

    check_cursor_col();
    changed_lines(curwin->w_cursor.lnum, curwin->w_cursor.col,
        oap->end.lnum + 1, 0L);
    oap->line_count = 0;            /* no lines deleted */
  } else if (oap->motion_type == MLINE)    {
    if (oap->op_type == OP_CHANGE) {
      /* Delete the lines except the first one.  Temporarily move the
       * cursor to the next line.  Save the current line number, if the
       * last line is deleted it may be changed.
       */
      if (oap->line_count > 1) {
        lnum = curwin->w_cursor.lnum;
        ++curwin->w_cursor.lnum;
        del_lines((long)(oap->line_count - 1), TRUE);
        curwin->w_cursor.lnum = lnum;
      }
      if (u_save_cursor() == FAIL)
        return FAIL;
      if (curbuf->b_p_ai) {                 /* don't delete indent */
        beginline(BL_WHITE);                /* cursor on first non-white */
        did_ai = TRUE;                      /* delete the indent when ESC hit */
        ai_col = curwin->w_cursor.col;
      } else
        beginline(0);                       /* cursor in column 0 */
      truncate_line(FALSE);         /* delete the rest of the line */
                                    /* leave cursor past last char in line */
      if (oap->line_count > 1)
        u_clearline();              /* "U" command not possible after "2cc" */
    } else   {
      del_lines(oap->line_count, TRUE);
      beginline(BL_WHITE | BL_FIX);
      u_clearline();            /* "U" command not possible after "dd" */
    }
  } else   {
    if (virtual_op) {
      int endcol = 0;

      /* For virtualedit: break the tabs that are partly included. */
      if (gchar_pos(&oap->start) == '\t') {
        if (u_save_cursor() == FAIL)            /* save first line for undo */
          return FAIL;
        if (oap->line_count == 1)
          endcol = getviscol2(oap->end.col, oap->end.coladd);
        coladvance_force(getviscol2(oap->start.col, oap->start.coladd));
        oap->start = curwin->w_cursor;
        if (oap->line_count == 1) {
          coladvance(endcol);
          oap->end.col = curwin->w_cursor.col;
          oap->end.coladd = curwin->w_cursor.coladd;
          curwin->w_cursor = oap->start;
        }
      }

      /* Break a tab only when it's included in the area. */
      if (gchar_pos(&oap->end) == '\t'
          && (int)oap->end.coladd < oap->inclusive) {
        /* save last line for undo */
        if (u_save((linenr_T)(oap->end.lnum - 1),
                (linenr_T)(oap->end.lnum + 1)) == FAIL)
          return FAIL;
        curwin->w_cursor = oap->end;
        coladvance_force(getviscol2(oap->end.col, oap->end.coladd));
        oap->end = curwin->w_cursor;
        curwin->w_cursor = oap->start;
      }
    }

    if (oap->line_count == 1) {         /* delete characters within one line */
      if (u_save_cursor() == FAIL)              /* save line for undo */
        return FAIL;

      /* if 'cpoptions' contains '$', display '$' at end of change */
      if (           vim_strchr(p_cpo, CPO_DOLLAR) != NULL
                     && oap->op_type == OP_CHANGE
                     && oap->end.lnum == curwin->w_cursor.lnum
                     && !oap->is_VIsual
                     )
        display_dollar(oap->end.col - !oap->inclusive);

      n = oap->end.col - oap->start.col + 1 - !oap->inclusive;

      if (virtual_op) {
        /* fix up things for virtualedit-delete:
         * break the tabs which are going to get in our way
         */
        char_u          *curline = ml_get_curline();
        int len = (int)STRLEN(curline);

        if (oap->end.coladd != 0
            && (int)oap->end.col >= len - 1
            && !(oap->start.coladd && (int)oap->end.col >= len - 1))
          n++;
        /* Delete at least one char (e.g, when on a control char). */
        if (n == 0 && oap->start.coladd != oap->end.coladd)
          n = 1;

        /* When deleted a char in the line, reset coladd. */
        if (gchar_cursor() != NUL)
          curwin->w_cursor.coladd = 0;
      }
      if (oap->op_type == OP_DELETE
          && oap->inclusive
          && oap->end.lnum == curbuf->b_ml.ml_line_count
          && n > (int)STRLEN(ml_get(oap->end.lnum))) {
        /* Special case: gH<Del> deletes the last line. */
        del_lines(1L, FALSE);
      } else   {
        (void)del_bytes((long)n, !virtual_op, oap->op_type == OP_DELETE
            && !oap->is_VIsual
            );
      }
    } else   {                          /* delete characters between lines */
      pos_T curpos;
      int delete_last_line;

      /* save deleted and changed lines for undo */
      if (u_save((linenr_T)(curwin->w_cursor.lnum - 1),
              (linenr_T)(curwin->w_cursor.lnum + oap->line_count)) == FAIL)
        return FAIL;

      delete_last_line = (oap->end.lnum == curbuf->b_ml.ml_line_count);
      truncate_line(TRUE);              /* delete from cursor to end of line */

      curpos = curwin->w_cursor;        /* remember curwin->w_cursor */
      ++curwin->w_cursor.lnum;
      del_lines((long)(oap->line_count - 2), FALSE);

      if (delete_last_line)
        oap->end.lnum = curbuf->b_ml.ml_line_count;

      n = (oap->end.col + 1 - !oap->inclusive);
      if (oap->inclusive && delete_last_line
          && n > (int)STRLEN(ml_get(oap->end.lnum))) {
        /* Special case: gH<Del> deletes the last line. */
        del_lines(1L, FALSE);
        curwin->w_cursor = curpos;              /* restore curwin->w_cursor */
        if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count)
          curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
      } else   {
        /* delete from start of line until op_end */
        curwin->w_cursor.col = 0;
        (void)del_bytes((long)n, !virtual_op, oap->op_type == OP_DELETE
            && !oap->is_VIsual
            );
        curwin->w_cursor = curpos;              /* restore curwin->w_cursor */
      }
      if (curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count)
        (void)do_join(2, FALSE, FALSE, FALSE);
    }
  }

  msgmore(curbuf->b_ml.ml_line_count - old_lcount);

setmarks:
  if (oap->block_mode) {
    curbuf->b_op_end.lnum = oap->end.lnum;
    curbuf->b_op_end.col = oap->start.col;
  } else
    curbuf->b_op_end = oap->start;
  curbuf->b_op_start = oap->start;

  return OK;
}

/*
 * Adjust end of operating area for ending on a multi-byte character.
 * Used for deletion.
 */
static void mb_adjust_opend(oparg_T *oap)
{
  char_u      *p;

  if (oap->inclusive) {
    p = ml_get(oap->end.lnum);
    oap->end.col += mb_tail_off(p, p + oap->end.col);
  }
}

/*
 * Replace a whole area with one character.
 */
int op_replace(oparg_T *oap, int c)
{
  int n, numc;
  int num_chars;
  char_u              *newp, *oldp;
  size_t oldlen;
  struct block_def bd;
  char_u              *after_p = NULL;
  int had_ctrl_v_cr = (c == -1 || c == -2);

  if ((curbuf->b_ml.ml_flags & ML_EMPTY ) || oap->empty)
    return OK;              /* nothing to do */

  if (had_ctrl_v_cr)
    c = (c == -1 ? '\r' : '\n');

  if (has_mbyte)
    mb_adjust_opend(oap);

  if (u_save((linenr_T)(oap->start.lnum - 1),
          (linenr_T)(oap->end.lnum + 1)) == FAIL)
    return FAIL;

  /*
   * block mode replace
   */
  if (oap->block_mode) {
    bd.is_MAX = (curwin->w_curswant == MAXCOL);
    for (; curwin->w_cursor.lnum <= oap->end.lnum; ++curwin->w_cursor.lnum) {
      curwin->w_cursor.col = 0;        /* make sure cursor position is valid */
      block_prep(oap, &bd, curwin->w_cursor.lnum, TRUE);
      if (bd.textlen == 0 && (!virtual_op || bd.is_MAX))
        continue;                   /* nothing to replace */

      /* n == number of extra chars required
       * If we split a TAB, it may be replaced by several characters.
       * Thus the number of characters may increase!
       */
      /* If the range starts in virtual space, count the initial
       * coladd offset as part of "startspaces" */
      if (virtual_op && bd.is_short && *bd.textstart == NUL) {
        pos_T vpos;

        vpos.lnum = curwin->w_cursor.lnum;
        getvpos(&vpos, oap->start_vcol);
        bd.startspaces += vpos.coladd;
        n = bd.startspaces;
      } else
        /* allow for pre spaces */
        n = (bd.startspaces ? bd.start_char_vcols - 1 : 0);

      /* allow for post spp */
      n += (bd.endspaces
            && !bd.is_oneChar
            && bd.end_char_vcols > 0) ? bd.end_char_vcols - 1 : 0;
      /* Figure out how many characters to replace. */
      numc = oap->end_vcol - oap->start_vcol + 1;
      if (bd.is_short && (!virtual_op || bd.is_MAX))
        numc -= (oap->end_vcol - bd.end_vcol) + 1;

      /* A double-wide character can be replaced only up to half the
       * times. */
      if ((*mb_char2cells)(c) > 1) {
        if ((numc & 1) && !bd.is_short) {
          ++bd.endspaces;
          ++n;
        }
        numc = numc / 2;
      }

      /* Compute bytes needed, move character count to num_chars. */
      num_chars = numc;
      numc *= (*mb_char2len)(c);
      /* oldlen includes textlen, so don't double count */
      n += numc - bd.textlen;

      oldp = ml_get_curline();
      oldlen = STRLEN(oldp);
      newp = alloc_check((unsigned)oldlen + 1 + n);
      if (newp == NULL)
        continue;
      vim_memset(newp, NUL, (size_t)(oldlen + 1 + n));
      /* copy up to deleted part */
      mch_memmove(newp, oldp, (size_t)bd.textcol);
      oldp += bd.textcol + bd.textlen;
      /* insert pre-spaces */
      copy_spaces(newp + bd.textcol, (size_t)bd.startspaces);
      /* insert replacement chars CHECK FOR ALLOCATED SPACE */
      /* -1/-2 is used for entering CR literally. */
      if (had_ctrl_v_cr || (c != '\r' && c != '\n')) {
        if (has_mbyte) {
          n = (int)STRLEN(newp);
          while (--num_chars >= 0)
            n += (*mb_char2bytes)(c, newp + n);
        } else
          copy_chars(newp + STRLEN(newp), (size_t)numc, c);
        if (!bd.is_short) {
          /* insert post-spaces */
          copy_spaces(newp + STRLEN(newp), (size_t)bd.endspaces);
          /* copy the part after the changed part */
          STRMOVE(newp + STRLEN(newp), oldp);
        }
      } else   {
        /* Replacing with \r or \n means splitting the line. */
        after_p = alloc_check(
            (unsigned)(oldlen + 1 + n - STRLEN(newp)));
        if (after_p != NULL)
          STRMOVE(after_p, oldp);
      }
      /* replace the line */
      ml_replace(curwin->w_cursor.lnum, newp, FALSE);
      if (after_p != NULL) {
        ml_append(curwin->w_cursor.lnum++, after_p, 0, FALSE);
        appended_lines_mark(curwin->w_cursor.lnum, 1L);
        oap->end.lnum++;
        vim_free(after_p);
      }
    }
  } else   {
    /*
     * MCHAR and MLINE motion replace.
     */
    if (oap->motion_type == MLINE) {
      oap->start.col = 0;
      curwin->w_cursor.col = 0;
      oap->end.col = (colnr_T)STRLEN(ml_get(oap->end.lnum));
      if (oap->end.col)
        --oap->end.col;
    } else if (!oap->inclusive)
      dec(&(oap->end));

    while (ltoreq(curwin->w_cursor, oap->end)) {
      n = gchar_cursor();
      if (n != NUL) {
        if ((*mb_char2len)(c) > 1 || (*mb_char2len)(n) > 1) {
          /* This is slow, but it handles replacing a single-byte
           * with a multi-byte and the other way around. */
          if (curwin->w_cursor.lnum == oap->end.lnum)
            oap->end.col += (*mb_char2len)(c) - (*mb_char2len)(n);
          n = State;
          State = REPLACE;
          ins_char(c);
          State = n;
          /* Backup to the replaced character. */
          dec_cursor();
        } else   {
          if (n == TAB) {
            int end_vcol = 0;

            if (curwin->w_cursor.lnum == oap->end.lnum) {
              /* oap->end has to be recalculated when
               * the tab breaks */
              end_vcol = getviscol2(oap->end.col,
                  oap->end.coladd);
            }
            coladvance_force(getviscol());
            if (curwin->w_cursor.lnum == oap->end.lnum)
              getvpos(&oap->end, end_vcol);
          }
          pchar(curwin->w_cursor, c);
        }
      } else if (virtual_op && curwin->w_cursor.lnum == oap->end.lnum)   {
        int virtcols = oap->end.coladd;

        if (curwin->w_cursor.lnum == oap->start.lnum
            && oap->start.col == oap->end.col && oap->start.coladd)
          virtcols -= oap->start.coladd;

        /* oap->end has been trimmed so it's effectively inclusive;
         * as a result an extra +1 must be counted so we don't
         * trample the NUL byte. */
        coladvance_force(getviscol2(oap->end.col, oap->end.coladd) + 1);
        curwin->w_cursor.col -= (virtcols + 1);
        for (; virtcols >= 0; virtcols--) {
          pchar(curwin->w_cursor, c);
          if (inc(&curwin->w_cursor) == -1)
            break;
        }
      }

      /* Advance to next character, stop at the end of the file. */
      if (inc_cursor() == -1)
        break;
    }
  }

  curwin->w_cursor = oap->start;
  check_cursor();
  changed_lines(oap->start.lnum, oap->start.col, oap->end.lnum + 1, 0L);

  /* Set "'[" and "']" marks. */
  curbuf->b_op_start = oap->start;
  curbuf->b_op_end = oap->end;

  return OK;
}

static int swapchars(int op_type, pos_T *pos, int length);

/*
 * Handle the (non-standard vi) tilde operator.  Also for "gu", "gU" and "g?".
 */
void op_tilde(oparg_T *oap)
{
  pos_T pos;
  struct block_def bd;
  int did_change = FALSE;

  if (u_save((linenr_T)(oap->start.lnum - 1),
          (linenr_T)(oap->end.lnum + 1)) == FAIL)
    return;

  pos = oap->start;
  if (oap->block_mode) {                    /* Visual block mode */
    for (; pos.lnum <= oap->end.lnum; ++pos.lnum) {
      int one_change;

      block_prep(oap, &bd, pos.lnum, FALSE);
      pos.col = bd.textcol;
      one_change = swapchars(oap->op_type, &pos, bd.textlen);
      did_change |= one_change;

    }
    if (did_change)
      changed_lines(oap->start.lnum, 0, oap->end.lnum + 1, 0L);
  } else   {                                /* not block mode */
    if (oap->motion_type == MLINE) {
      oap->start.col = 0;
      pos.col = 0;
      oap->end.col = (colnr_T)STRLEN(ml_get(oap->end.lnum));
      if (oap->end.col)
        --oap->end.col;
    } else if (!oap->inclusive)
      dec(&(oap->end));

    if (pos.lnum == oap->end.lnum)
      did_change = swapchars(oap->op_type, &pos,
          oap->end.col - pos.col + 1);
    else
      for (;; ) {
        did_change |= swapchars(oap->op_type, &pos,
            pos.lnum == oap->end.lnum ? oap->end.col + 1 :
            (int)STRLEN(ml_get_pos(&pos)));
        if (ltoreq(oap->end, pos) || inc(&pos) == -1)
          break;
      }
    if (did_change) {
      changed_lines(oap->start.lnum, oap->start.col, oap->end.lnum + 1,
          0L);
    }
  }

  if (!did_change && oap->is_VIsual)
    /* No change: need to remove the Visual selection */
    redraw_curbuf_later(INVERTED);

  /*
   * Set '[ and '] marks.
   */
  curbuf->b_op_start = oap->start;
  curbuf->b_op_end = oap->end;

  if (oap->line_count > p_report) {
    if (oap->line_count == 1)
      MSG(_("1 line changed"));
    else
      smsg((char_u *)_("%ld lines changed"), oap->line_count);
  }
}

/*
 * Invoke swapchar() on "length" bytes at position "pos".
 * "pos" is advanced to just after the changed characters.
 * "length" is rounded up to include the whole last multi-byte character.
 * Also works correctly when the number of bytes changes.
 * Returns TRUE if some character was changed.
 */
static int swapchars(int op_type, pos_T *pos, int length)
{
  int todo;
  int did_change = 0;

  for (todo = length; todo > 0; --todo) {
    if (has_mbyte) {
      int len = (*mb_ptr2len)(ml_get_pos(pos));

      /* we're counting bytes, not characters */
      if (len > 0)
        todo -= len - 1;
    }
    did_change |= swapchar(op_type, pos);
    if (inc(pos) == -1)        /* at end of file */
      break;
  }
  return did_change;
}

/*
 * If op_type == OP_UPPER: make uppercase,
 * if op_type == OP_LOWER: make lowercase,
 * if op_type == OP_ROT13: do rot13 encoding,
 * else swap case of character at 'pos'
 * returns TRUE when something actually changed.
 */
int swapchar(int op_type, pos_T *pos)
{
  int c;
  int nc;

  c = gchar_pos(pos);

  /* Only do rot13 encoding for ASCII characters. */
  if (c >= 0x80 && op_type == OP_ROT13)
    return FALSE;

  if (op_type == OP_UPPER && c == 0xdf
      && (enc_latin1like || STRCMP(p_enc, "iso-8859-2") == 0)) {
    pos_T sp = curwin->w_cursor;

    /* Special handling of German sharp s: change to "SS". */
    curwin->w_cursor = *pos;
    del_char(FALSE);
    ins_char('S');
    ins_char('S');
    curwin->w_cursor = sp;
    inc(pos);
  }

  if (enc_dbcs != 0 && c >= 0x100)      /* No lower/uppercase letter */
    return FALSE;
  nc = c;
  if (MB_ISLOWER(c)) {
    if (op_type == OP_ROT13)
      nc = ROT13(c, 'a');
    else if (op_type != OP_LOWER)
      nc = MB_TOUPPER(c);
  } else if (MB_ISUPPER(c))   {
    if (op_type == OP_ROT13)
      nc = ROT13(c, 'A');
    else if (op_type != OP_UPPER)
      nc = MB_TOLOWER(c);
  }
  if (nc != c) {
    if (enc_utf8 && (c >= 0x80 || nc >= 0x80)) {
      pos_T sp = curwin->w_cursor;

      curwin->w_cursor = *pos;
      /* don't use del_char(), it also removes composing chars */
      del_bytes(utf_ptr2len(ml_get_cursor()), FALSE, FALSE);
      ins_char(nc);
      curwin->w_cursor = sp;
    } else
      pchar(*pos, nc);
    return TRUE;
  }
  return FALSE;
}

/*
 * op_insert - Insert and append operators for Visual mode.
 */
void op_insert(oparg_T *oap, long count1)
{
  long ins_len, pre_textlen = 0;
  char_u              *firstline, *ins_text;
  struct block_def bd;
  int i;

  /* edit() changes this - record it for OP_APPEND */
  bd.is_MAX = (curwin->w_curswant == MAXCOL);

  /* vis block is still marked. Get rid of it now. */
  curwin->w_cursor.lnum = oap->start.lnum;
  update_screen(INVERTED);

  if (oap->block_mode) {
    /* When 'virtualedit' is used, need to insert the extra spaces before
     * doing block_prep().  When only "block" is used, virtual edit is
     * already disabled, but still need it when calling
     * coladvance_force(). */
    if (curwin->w_cursor.coladd > 0) {
      int old_ve_flags = ve_flags;

      ve_flags = VE_ALL;
      if (u_save_cursor() == FAIL)
        return;
      coladvance_force(oap->op_type == OP_APPEND
          ? oap->end_vcol + 1 : getviscol());
      if (oap->op_type == OP_APPEND)
        --curwin->w_cursor.col;
      ve_flags = old_ve_flags;
    }
    /* Get the info about the block before entering the text */
    block_prep(oap, &bd, oap->start.lnum, TRUE);
    firstline = ml_get(oap->start.lnum) + bd.textcol;
    if (oap->op_type == OP_APPEND)
      firstline += bd.textlen;
    pre_textlen = (long)STRLEN(firstline);
  }

  if (oap->op_type == OP_APPEND) {
    if (oap->block_mode
        && curwin->w_cursor.coladd == 0
        ) {
      /* Move the cursor to the character right of the block. */
      curwin->w_set_curswant = TRUE;
      while (*ml_get_cursor() != NUL
             && (curwin->w_cursor.col < bd.textcol + bd.textlen))
        ++curwin->w_cursor.col;
      if (bd.is_short && !bd.is_MAX) {
        /* First line was too short, make it longer and adjust the
         * values in "bd". */
        if (u_save_cursor() == FAIL)
          return;
        for (i = 0; i < bd.endspaces; ++i)
          ins_char(' ');
        bd.textlen += bd.endspaces;
      }
    } else   {
      curwin->w_cursor = oap->end;
      check_cursor_col();

      /* Works just like an 'i'nsert on the next character. */
      if (!lineempty(curwin->w_cursor.lnum)
          && oap->start_vcol != oap->end_vcol)
        inc_cursor();
    }
  }

  edit(NUL, FALSE, (linenr_T)count1);

  /* If user has moved off this line, we don't know what to do, so do
   * nothing.
   * Also don't repeat the insert when Insert mode ended with CTRL-C. */
  if (curwin->w_cursor.lnum != oap->start.lnum || got_int)
    return;

  if (oap->block_mode) {
    struct block_def bd2;

    /* The user may have moved the cursor before inserting something, try
     * to adjust the block for that. */
    if (oap->start.lnum == curbuf->b_op_start.lnum && !bd.is_MAX) {
      if (oap->op_type == OP_INSERT
          && oap->start.col != curbuf->b_op_start.col) {
        oap->start.col = curbuf->b_op_start.col;
        pre_textlen -= getviscol2(oap->start.col, oap->start.coladd)
                       - oap->start_vcol;
        oap->start_vcol = getviscol2(oap->start.col, oap->start.coladd);
      } else if (oap->op_type == OP_APPEND
                 && oap->end.col >= curbuf->b_op_start.col) {
        oap->start.col = curbuf->b_op_start.col;
        /* reset pre_textlen to the value of OP_INSERT */
        pre_textlen += bd.textlen;
        pre_textlen -= getviscol2(oap->start.col, oap->start.coladd)
                       - oap->start_vcol;
        oap->start_vcol = getviscol2(oap->start.col, oap->start.coladd);
        oap->op_type = OP_INSERT;
      }
    }

    /*
     * Spaces and tabs in the indent may have changed to other spaces and
     * tabs.  Get the starting column again and correct the length.
     * Don't do this when "$" used, end-of-line will have changed.
     */
    block_prep(oap, &bd2, oap->start.lnum, TRUE);
    if (!bd.is_MAX || bd2.textlen < bd.textlen) {
      if (oap->op_type == OP_APPEND) {
        pre_textlen += bd2.textlen - bd.textlen;
        if (bd2.endspaces)
          --bd2.textlen;
      }
      bd.textcol = bd2.textcol;
      bd.textlen = bd2.textlen;
    }

    /*
     * Subsequent calls to ml_get() flush the firstline data - take a
     * copy of the required string.
     */
    firstline = ml_get(oap->start.lnum) + bd.textcol;
    if (oap->op_type == OP_APPEND)
      firstline += bd.textlen;
    if (pre_textlen >= 0
        && (ins_len = (long)STRLEN(firstline) - pre_textlen) > 0) {
      ins_text = vim_strnsave(firstline, (int)ins_len);
      if (ins_text != NULL) {
        /* block handled here */
        if (u_save(oap->start.lnum,
                (linenr_T)(oap->end.lnum + 1)) == OK)
          block_insert(oap, ins_text, (oap->op_type == OP_INSERT),
              &bd);

        curwin->w_cursor.col = oap->start.col;
        check_cursor();
        vim_free(ins_text);
      }
    }
  }
}

/*
 * op_change - handle a change operation
 *
 * return TRUE if edit() returns because of a CTRL-O command
 */
int op_change(oparg_T *oap)
{
  colnr_T l;
  int retval;
  long offset;
  linenr_T linenr;
  long ins_len;
  long pre_textlen = 0;
  long pre_indent = 0;
  char_u              *firstline;
  char_u              *ins_text, *newp, *oldp;
  struct block_def bd;

  l = oap->start.col;
  if (oap->motion_type == MLINE) {
    l = 0;
    if (!p_paste && curbuf->b_p_si
        && !curbuf->b_p_cin
        )
      can_si = TRUE;            /* It's like opening a new line, do si */
  }

  /* First delete the text in the region.  In an empty buffer only need to
   * save for undo */
  if (curbuf->b_ml.ml_flags & ML_EMPTY) {
    if (u_save_cursor() == FAIL)
      return FALSE;
  } else if (op_delete(oap) == FAIL)
    return FALSE;

  if ((l > curwin->w_cursor.col) && !lineempty(curwin->w_cursor.lnum)
      && !virtual_op)
    inc_cursor();

  /* check for still on same line (<CR> in inserted text meaningless) */
  /* skip blank lines too */
  if (oap->block_mode) {
    /* Add spaces before getting the current line length. */
    if (virtual_op && (curwin->w_cursor.coladd > 0
                       || gchar_cursor() == NUL))
      coladvance_force(getviscol());
    firstline = ml_get(oap->start.lnum);
    pre_textlen = (long)STRLEN(firstline);
    pre_indent = (long)(skipwhite(firstline) - firstline);
    bd.textcol = curwin->w_cursor.col;
  }

  if (oap->motion_type == MLINE)
    fix_indent();

  retval = edit(NUL, FALSE, (linenr_T)1);

  /*
   * In Visual block mode, handle copying the new text to all lines of the
   * block.
   * Don't repeat the insert when Insert mode ended with CTRL-C.
   */
  if (oap->block_mode && oap->start.lnum != oap->end.lnum && !got_int) {
    /* Auto-indenting may have changed the indent.  If the cursor was past
     * the indent, exclude that indent change from the inserted text. */
    firstline = ml_get(oap->start.lnum);
    if (bd.textcol > (colnr_T)pre_indent) {
      long new_indent = (long)(skipwhite(firstline) - firstline);

      pre_textlen += new_indent - pre_indent;
      bd.textcol += new_indent - pre_indent;
    }

    ins_len = (long)STRLEN(firstline) - pre_textlen;
    if (ins_len > 0) {
      /* Subsequent calls to ml_get() flush the firstline data - take a
       * copy of the inserted text.  */
      if ((ins_text = alloc_check((unsigned)(ins_len + 1))) != NULL) {
        vim_strncpy(ins_text, firstline + bd.textcol, (size_t)ins_len);
        for (linenr = oap->start.lnum + 1; linenr <= oap->end.lnum;
             linenr++) {
          block_prep(oap, &bd, linenr, TRUE);
          if (!bd.is_short || virtual_op) {
            pos_T vpos;

            /* If the block starts in virtual space, count the
             * initial coladd offset as part of "startspaces" */
            if (bd.is_short) {
              vpos.lnum = linenr;
              (void)getvpos(&vpos, oap->start_vcol);
            } else
              vpos.coladd = 0;
            oldp = ml_get(linenr);
            newp = alloc_check((unsigned)(STRLEN(oldp)
                                          + vpos.coladd
                                          + ins_len + 1));
            if (newp == NULL)
              continue;
            /* copy up to block start */
            mch_memmove(newp, oldp, (size_t)bd.textcol);
            offset = bd.textcol;
            copy_spaces(newp + offset, (size_t)vpos.coladd);
            offset += vpos.coladd;
            mch_memmove(newp + offset, ins_text, (size_t)ins_len);
            offset += ins_len;
            oldp += bd.textcol;
            STRMOVE(newp + offset, oldp);
            ml_replace(linenr, newp, FALSE);
          }
        }
        check_cursor();

        changed_lines(oap->start.lnum + 1, 0, oap->end.lnum + 1, 0L);
      }
      vim_free(ins_text);
    }
  }

  return retval;
}

/*
 * set all the yank registers to empty (called from main())
 */
void init_yank(void)          {
  int i;

  for (i = 0; i < NUM_REGISTERS; ++i)
    y_regs[i].y_array = NULL;
}

#if defined(EXITFREE) || defined(PROTO)
void clear_registers(void)          {
  int i;

  for (i = 0; i < NUM_REGISTERS; ++i) {
    y_current = &y_regs[i];
    if (y_current->y_array != NULL)
      free_yank_all();
  }
}

#endif

/*
 * Free "n" lines from the current yank register.
 * Called for normal freeing and in case of error.
 */
static void free_yank(long n)
{
  if (y_current->y_array != NULL) {
    long i;

    for (i = n; --i >= 0; ) {
      vim_free(y_current->y_array[i]);
    }
    vim_free(y_current->y_array);
    y_current->y_array = NULL;
  }
}

static void free_yank_all(void)                 {
  free_yank(y_current->y_size);
}

/*
 * Yank the text between "oap->start" and "oap->end" into a yank register.
 * If we are to append (uppercase register), we first yank into a new yank
 * register and then concatenate the old and the new one (so we keep the old
 * one in case of out-of-memory).
 *
 * Return FAIL for failure, OK otherwise.
 */
int op_yank(oparg_T *oap, int deleting, int mess)
{
  long y_idx;                           /* index in y_array[] */
  struct yankreg      *curr;            /* copy of y_current */
  struct yankreg newreg;                /* new yank register when appending */
  char_u              **new_ptr;
  linenr_T lnum;                        /* current line number */
  long j;
  int yanktype = oap->motion_type;
  long yanklines = oap->line_count;
  linenr_T yankendlnum = oap->end.lnum;
  char_u              *p;
  char_u              *pnew;
  struct block_def bd;

  /* check for read-only register */
  if (oap->regname != 0 && !valid_yank_reg(oap->regname, TRUE)) {
    beep_flush();
    return FAIL;
  }
  if (oap->regname == '_')          /* black hole: nothing to do */
    return OK;


  if (!deleting)                    /* op_delete() already set y_current */
    get_yank_register(oap->regname, TRUE);

  curr = y_current;
  /* append to existing contents */
  if (y_append && y_current->y_array != NULL)
    y_current = &newreg;
  else
    free_yank_all();                /* free previously yanked lines */

  /*
   * If the cursor was in column 1 before and after the movement, and the
   * operator is not inclusive, the yank is always linewise.
   */
  if (       oap->motion_type == MCHAR
             && oap->start.col == 0
             && !oap->inclusive
             && (!oap->is_VIsual || *p_sel == 'o')
             && !oap->block_mode
             && oap->end.col == 0
             && yanklines > 1) {
    yanktype = MLINE;
    --yankendlnum;
    --yanklines;
  }

  y_current->y_size = yanklines;
  y_current->y_type = yanktype;     /* set the yank register type */
  y_current->y_width = 0;
  y_current->y_array = (char_u **)lalloc_clear((long_u)(sizeof(char_u *) *
                                                        yanklines), TRUE);

  if (y_current->y_array == NULL) {
    y_current = curr;
    return FAIL;
  }

  y_idx = 0;
  lnum = oap->start.lnum;

  if (oap->block_mode) {
    /* Visual block mode */
    y_current->y_type = MBLOCK;             /* set the yank register type */
    y_current->y_width = oap->end_vcol - oap->start_vcol;

    if (curwin->w_curswant == MAXCOL && y_current->y_width > 0)
      y_current->y_width--;
  }

  for (; lnum <= yankendlnum; lnum++, y_idx++) {
    switch (y_current->y_type) {
    case MBLOCK:
      block_prep(oap, &bd, lnum, FALSE);
      if (yank_copy_line(&bd, y_idx) == FAIL)
        goto fail;
      break;

    case MLINE:
      if ((y_current->y_array[y_idx] =
             vim_strsave(ml_get(lnum))) == NULL)
        goto fail;
      break;

    case MCHAR:
    {
      colnr_T startcol = 0, endcol = MAXCOL;
      int is_oneChar = FALSE;
      colnr_T cs, ce;
      p = ml_get(lnum);
      bd.startspaces = 0;
      bd.endspaces = 0;

      if (lnum == oap->start.lnum) {
        startcol = oap->start.col;
        if (virtual_op) {
          getvcol(curwin, &oap->start, &cs, NULL, &ce);
          if (ce != cs && oap->start.coladd > 0) {
            /* Part of a tab selected -- but don't
             * double-count it. */
            bd.startspaces = (ce - cs + 1)
                             - oap->start.coladd;
            startcol++;
          }
        }
      }

      if (lnum == oap->end.lnum) {
        endcol = oap->end.col;
        if (virtual_op) {
          getvcol(curwin, &oap->end, &cs, NULL, &ce);
          if (p[endcol] == NUL || (cs + oap->end.coladd < ce
                                   /* Don't add space for double-wide
                                    * char; endcol will be on last byte
                                    * of multi-byte char. */
                                   && (*mb_head_off)(p, p + endcol) == 0
                                   )) {
            if (oap->start.lnum == oap->end.lnum
                && oap->start.col == oap->end.col) {
              /* Special case: inside a single char */
              is_oneChar = TRUE;
              bd.startspaces = oap->end.coladd
                               - oap->start.coladd + oap->inclusive;
              endcol = startcol;
            } else   {
              bd.endspaces = oap->end.coladd
                             + oap->inclusive;
              endcol -= oap->inclusive;
            }
          }
        }
      }
      if (endcol == MAXCOL)
        endcol = (colnr_T)STRLEN(p);
      if (startcol > endcol
          || is_oneChar
          )
        bd.textlen = 0;
      else {
        bd.textlen = endcol - startcol + oap->inclusive;
      }
      bd.textstart = p + startcol;
      if (yank_copy_line(&bd, y_idx) == FAIL)
        goto fail;
      break;
    }
      /* NOTREACHED */
    }
  }

  if (curr != y_current) {      /* append the new block to the old block */
    new_ptr = (char_u **)lalloc(
        (long_u)(sizeof(char_u *) *
                 (curr->y_size + y_current->y_size)),
        TRUE);
    if (new_ptr == NULL)
      goto fail;
    for (j = 0; j < curr->y_size; ++j)
      new_ptr[j] = curr->y_array[j];
    vim_free(curr->y_array);
    curr->y_array = new_ptr;

    if (yanktype == MLINE)      /* MLINE overrides MCHAR and MBLOCK */
      curr->y_type = MLINE;

    /* Concatenate the last line of the old block with the first line of
     * the new block, unless being Vi compatible. */
    if (curr->y_type == MCHAR && vim_strchr(p_cpo, CPO_REGAPPEND) == NULL) {
      pnew = lalloc((long_u)(STRLEN(curr->y_array[curr->y_size - 1])
                             + STRLEN(y_current->y_array[0]) + 1), TRUE);
      if (pnew == NULL) {
        y_idx = y_current->y_size - 1;
        goto fail;
      }
      STRCPY(pnew, curr->y_array[--j]);
      STRCAT(pnew, y_current->y_array[0]);
      vim_free(curr->y_array[j]);
      vim_free(y_current->y_array[0]);
      curr->y_array[j++] = pnew;
      y_idx = 1;
    } else
      y_idx = 0;
    while (y_idx < y_current->y_size)
      curr->y_array[j++] = y_current->y_array[y_idx++];
    curr->y_size = j;
    vim_free(y_current->y_array);
    y_current = curr;
  }
  if (mess) {                   /* Display message about yank? */
    if (yanktype == MCHAR
        && !oap->block_mode
        && yanklines == 1)
      yanklines = 0;
    /* Some versions of Vi use ">=" here, some don't...  */
    if (yanklines > p_report) {
      /* redisplay now, so message is not deleted */
      update_topline_redraw();
      if (yanklines == 1) {
        if (oap->block_mode)
          MSG(_("block of 1 line yanked"));
        else
          MSG(_("1 line yanked"));
      } else if (oap->block_mode)
        smsg((char_u *)_("block of %ld lines yanked"), yanklines);
      else
        smsg((char_u *)_("%ld lines yanked"), yanklines);
    }
  }

  /*
   * Set "'[" and "']" marks.
   */
  curbuf->b_op_start = oap->start;
  curbuf->b_op_end = oap->end;
  if (yanktype == MLINE
      && !oap->block_mode
      ) {
    curbuf->b_op_start.col = 0;
    curbuf->b_op_end.col = MAXCOL;
  }


  return OK;

fail:           /* free the allocated lines */
  free_yank(y_idx + 1);
  y_current = curr;
  return FAIL;
}

static int yank_copy_line(struct block_def *bd, long y_idx)
{
  char_u      *pnew;

  if ((pnew = alloc(bd->startspaces + bd->endspaces + bd->textlen + 1))
      == NULL)
    return FAIL;
  y_current->y_array[y_idx] = pnew;
  copy_spaces(pnew, (size_t)bd->startspaces);
  pnew += bd->startspaces;
  mch_memmove(pnew, bd->textstart, (size_t)bd->textlen);
  pnew += bd->textlen;
  copy_spaces(pnew, (size_t)bd->endspaces);
  pnew += bd->endspaces;
  *pnew = NUL;
  return OK;
}


/*
 * Put contents of register "regname" into the text.
 * Caller must check "regname" to be valid!
 * "flags": PUT_FIXINDENT	make indent look nice
 *	    PUT_CURSEND		leave cursor after end of new text
 *	    PUT_LINE		force linewise put (":put")
 */
void 
do_put (
    int regname,
    int dir,                        /* BACKWARD for 'P', FORWARD for 'p' */
    long count,
    int flags
)
{
  char_u      *ptr;
  char_u      *newp, *oldp;
  int yanklen;
  int totlen = 0;                       /* init for gcc */
  linenr_T lnum;
  colnr_T col;
  long i;                               /* index in y_array[] */
  int y_type;
  long y_size;
  int oldlen;
  long y_width = 0;
  colnr_T vcol;
  int delcount;
  int incr = 0;
  long j;
  struct block_def bd;
  char_u      **y_array = NULL;
  long nr_lines = 0;
  pos_T new_cursor;
  int indent;
  int orig_indent = 0;                  /* init for gcc */
  int indent_diff = 0;                  /* init for gcc */
  int first_indent = TRUE;
  int lendiff = 0;
  pos_T old_pos;
  char_u      *insert_string = NULL;
  int allocated = FALSE;
  long cnt;


  if (flags & PUT_FIXINDENT)
    orig_indent = get_indent();

  curbuf->b_op_start = curwin->w_cursor;        /* default for '[ mark */
  curbuf->b_op_end = curwin->w_cursor;          /* default for '] mark */

  /*
   * Using inserted text works differently, because the register includes
   * special characters (newlines, etc.).
   */
  if (regname == '.') {
    (void)stuff_inserted((dir == FORWARD ? (count == -1 ? 'o' : 'a') :
                          (count == -1 ? 'O' : 'i')), count, FALSE);
    /* Putting the text is done later, so can't really move the cursor to
     * the next character.  Use "l" to simulate it. */
    if ((flags & PUT_CURSEND) && gchar_cursor() != NUL)
      stuffcharReadbuff('l');
    return;
  }

  /*
   * For special registers '%' (file name), '#' (alternate file name) and
   * ':' (last command line), etc. we have to create a fake yank register.
   */
  if (get_spec_reg(regname, &insert_string, &allocated, TRUE)) {
    if (insert_string == NULL)
      return;
  }

  /* Autocommands may be executed when saving lines for undo, which may make
   * y_array invalid.  Start undo now to avoid that. */
  u_save(curwin->w_cursor.lnum, curwin->w_cursor.lnum + 1);

  if (insert_string != NULL) {
    y_type = MCHAR;
    if (regname == '=') {
      /* For the = register we need to split the string at NL
       * characters.
       * Loop twice: count the number of lines and save them. */
      for (;; ) {
        y_size = 0;
        ptr = insert_string;
        while (ptr != NULL) {
          if (y_array != NULL)
            y_array[y_size] = ptr;
          ++y_size;
          ptr = vim_strchr(ptr, '\n');
          if (ptr != NULL) {
            if (y_array != NULL)
              *ptr = NUL;
            ++ptr;
            /* A trailing '\n' makes the register linewise. */
            if (*ptr == NUL) {
              y_type = MLINE;
              break;
            }
          }
        }
        if (y_array != NULL)
          break;
        y_array = (char_u **)alloc((unsigned)
            (y_size * sizeof(char_u *)));
        if (y_array == NULL)
          goto end;
      }
    } else   {
      y_size = 1;               /* use fake one-line yank register */
      y_array = &insert_string;
    }
  } else   {
    get_yank_register(regname, FALSE);

    y_type = y_current->y_type;
    y_width = y_current->y_width;
    y_size = y_current->y_size;
    y_array = y_current->y_array;
  }

  if (y_type == MLINE) {
    if (flags & PUT_LINE_SPLIT) {
      /* "p" or "P" in Visual mode: split the lines to put the text in
       * between. */
      if (u_save_cursor() == FAIL)
        goto end;
      ptr = vim_strsave(ml_get_cursor());
      if (ptr == NULL)
        goto end;
      ml_append(curwin->w_cursor.lnum, ptr, (colnr_T)0, FALSE);
      vim_free(ptr);

      ptr = vim_strnsave(ml_get_curline(), curwin->w_cursor.col);
      if (ptr == NULL)
        goto end;
      ml_replace(curwin->w_cursor.lnum, ptr, FALSE);
      ++nr_lines;
      dir = FORWARD;
    }
    if (flags & PUT_LINE_FORWARD) {
      /* Must be "p" for a Visual block, put lines below the block. */
      curwin->w_cursor = curbuf->b_visual.vi_end;
      dir = FORWARD;
    }
    curbuf->b_op_start = curwin->w_cursor;      /* default for '[ mark */
    curbuf->b_op_end = curwin->w_cursor;        /* default for '] mark */
  }

  if (flags & PUT_LINE)         /* :put command or "p" in Visual line mode. */
    y_type = MLINE;

  if (y_size == 0 || y_array == NULL) {
    EMSG2(_("E353: Nothing in register %s"),
        regname == 0 ? (char_u *)"\"" : transchar(regname));
    goto end;
  }

  if (y_type == MBLOCK) {
    lnum = curwin->w_cursor.lnum + y_size + 1;
    if (lnum > curbuf->b_ml.ml_line_count)
      lnum = curbuf->b_ml.ml_line_count + 1;
    if (u_save(curwin->w_cursor.lnum - 1, lnum) == FAIL)
      goto end;
  } else if (y_type == MLINE)    {
    lnum = curwin->w_cursor.lnum;
    /* Correct line number for closed fold.  Don't move the cursor yet,
     * u_save() uses it. */
    if (dir == BACKWARD)
      (void)hasFolding(lnum, &lnum, NULL);
    else
      (void)hasFolding(lnum, NULL, &lnum);
    if (dir == FORWARD)
      ++lnum;
    /* In an empty buffer the empty line is going to be replaced, include
     * it in the saved lines. */
    if ((bufempty() ? u_save(0, 2) : u_save(lnum - 1, lnum)) == FAIL)
      goto end;
    if (dir == FORWARD)
      curwin->w_cursor.lnum = lnum - 1;
    else
      curwin->w_cursor.lnum = lnum;
    curbuf->b_op_start = curwin->w_cursor;      /* for mark_adjust() */
  } else if (u_save_cursor() == FAIL)
    goto end;

  yanklen = (int)STRLEN(y_array[0]);

  if (ve_flags == VE_ALL && y_type == MCHAR) {
    if (gchar_cursor() == TAB) {
      /* Don't need to insert spaces when "p" on the last position of a
       * tab or "P" on the first position. */
      if (dir == FORWARD
          ? (int)curwin->w_cursor.coladd < curbuf->b_p_ts - 1
          : curwin->w_cursor.coladd > 0)
        coladvance_force(getviscol());
      else
        curwin->w_cursor.coladd = 0;
    } else if (curwin->w_cursor.coladd > 0 || gchar_cursor() == NUL)
      coladvance_force(getviscol() + (dir == FORWARD));
  }

  lnum = curwin->w_cursor.lnum;
  col = curwin->w_cursor.col;

  /*
   * Block mode
   */
  if (y_type == MBLOCK) {
    char c = gchar_cursor();
    colnr_T endcol2 = 0;

    if (dir == FORWARD && c != NUL) {
      if (ve_flags == VE_ALL)
        getvcol(curwin, &curwin->w_cursor, &col, NULL, &endcol2);
      else
        getvcol(curwin, &curwin->w_cursor, NULL, NULL, &col);

      if (has_mbyte)
        /* move to start of next multi-byte character */
        curwin->w_cursor.col += (*mb_ptr2len)(ml_get_cursor());
      else if (c != TAB || ve_flags != VE_ALL)
        ++curwin->w_cursor.col;
      ++col;
    } else
      getvcol(curwin, &curwin->w_cursor, &col, NULL, &endcol2);

    col += curwin->w_cursor.coladd;
    if (ve_flags == VE_ALL
        && (curwin->w_cursor.coladd > 0
            || endcol2 == curwin->w_cursor.col)) {
      if (dir == FORWARD && c == NUL)
        ++col;
      if (dir != FORWARD && c != NUL)
        ++curwin->w_cursor.col;
      if (c == TAB) {
        if (dir == BACKWARD && curwin->w_cursor.col)
          curwin->w_cursor.col--;
        if (dir == FORWARD && col - 1 == endcol2)
          curwin->w_cursor.col++;
      }
    }
    curwin->w_cursor.coladd = 0;
    bd.textcol = 0;
    for (i = 0; i < y_size; ++i) {
      int spaces;
      char shortline;

      bd.startspaces = 0;
      bd.endspaces = 0;
      vcol = 0;
      delcount = 0;

      /* add a new line */
      if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count) {
        if (ml_append(curbuf->b_ml.ml_line_count, (char_u *)"",
                (colnr_T)1, FALSE) == FAIL)
          break;
        ++nr_lines;
      }
      /* get the old line and advance to the position to insert at */
      oldp = ml_get_curline();
      oldlen = (int)STRLEN(oldp);
      for (ptr = oldp; vcol < col && *ptr; ) {
        /* Count a tab for what it's worth (if list mode not on) */
        incr = lbr_chartabsize_adv(&ptr, (colnr_T)vcol);
        vcol += incr;
      }
      bd.textcol = (colnr_T)(ptr - oldp);

      shortline = (vcol < col) || (vcol == col && !*ptr);

      if (vcol < col)       /* line too short, padd with spaces */
        bd.startspaces = col - vcol;
      else if (vcol > col) {
        bd.endspaces = vcol - col;
        bd.startspaces = incr - bd.endspaces;
        --bd.textcol;
        delcount = 1;
        if (has_mbyte)
          bd.textcol -= (*mb_head_off)(oldp, oldp + bd.textcol);
        if (oldp[bd.textcol] != TAB) {
          /* Only a Tab can be split into spaces.  Other
           * characters will have to be moved to after the
           * block, causing misalignment. */
          delcount = 0;
          bd.endspaces = 0;
        }
      }

      yanklen = (int)STRLEN(y_array[i]);

      /* calculate number of spaces required to fill right side of block*/
      spaces = y_width + 1;
      for (j = 0; j < yanklen; j++)
        spaces -= lbr_chartabsize(&y_array[i][j], 0);
      if (spaces < 0)
        spaces = 0;

      /* insert the new text */
      totlen = count * (yanklen + spaces) + bd.startspaces + bd.endspaces;
      newp = alloc_check((unsigned)totlen + oldlen + 1);
      if (newp == NULL)
        break;
      /* copy part up to cursor to new line */
      ptr = newp;
      mch_memmove(ptr, oldp, (size_t)bd.textcol);
      ptr += bd.textcol;
      /* may insert some spaces before the new text */
      copy_spaces(ptr, (size_t)bd.startspaces);
      ptr += bd.startspaces;
      /* insert the new text */
      for (j = 0; j < count; ++j) {
        mch_memmove(ptr, y_array[i], (size_t)yanklen);
        ptr += yanklen;

        /* insert block's trailing spaces only if there's text behind */
        if ((j < count - 1 || !shortline) && spaces) {
          copy_spaces(ptr, (size_t)spaces);
          ptr += spaces;
        }
      }
      /* may insert some spaces after the new text */
      copy_spaces(ptr, (size_t)bd.endspaces);
      ptr += bd.endspaces;
      /* move the text after the cursor to the end of the line. */
      mch_memmove(ptr, oldp + bd.textcol + delcount,
          (size_t)(oldlen - bd.textcol - delcount + 1));
      ml_replace(curwin->w_cursor.lnum, newp, FALSE);

      ++curwin->w_cursor.lnum;
      if (i == 0)
        curwin->w_cursor.col += bd.startspaces;
    }

    changed_lines(lnum, 0, curwin->w_cursor.lnum, nr_lines);

    /* Set '[ mark. */
    curbuf->b_op_start = curwin->w_cursor;
    curbuf->b_op_start.lnum = lnum;

    /* adjust '] mark */
    curbuf->b_op_end.lnum = curwin->w_cursor.lnum - 1;
    curbuf->b_op_end.col = bd.textcol + totlen - 1;
    curbuf->b_op_end.coladd = 0;
    if (flags & PUT_CURSEND) {
      colnr_T len;

      curwin->w_cursor = curbuf->b_op_end;
      curwin->w_cursor.col++;

      /* in Insert mode we might be after the NUL, correct for that */
      len = (colnr_T)STRLEN(ml_get_curline());
      if (curwin->w_cursor.col > len)
        curwin->w_cursor.col = len;
    } else
      curwin->w_cursor.lnum = lnum;
  } else   {
    /*
     * Character or Line mode
     */
    if (y_type == MCHAR) {
      /* if type is MCHAR, FORWARD is the same as BACKWARD on the next
       * char */
      if (dir == FORWARD && gchar_cursor() != NUL) {
        if (has_mbyte) {
          int bytelen = (*mb_ptr2len)(ml_get_cursor());

          /* put it on the next of the multi-byte character. */
          col += bytelen;
          if (yanklen) {
            curwin->w_cursor.col += bytelen;
            curbuf->b_op_end.col += bytelen;
          }
        } else   {
          ++col;
          if (yanklen) {
            ++curwin->w_cursor.col;
            ++curbuf->b_op_end.col;
          }
        }
      }
      curbuf->b_op_start = curwin->w_cursor;
    }
    /*
     * Line mode: BACKWARD is the same as FORWARD on the previous line
     */
    else if (dir == BACKWARD)
      --lnum;
    new_cursor = curwin->w_cursor;

    /*
     * simple case: insert into current line
     */
    if (y_type == MCHAR && y_size == 1) {
      do {
        totlen = count * yanklen;
        if (totlen > 0) {
          oldp = ml_get(lnum);
          newp = alloc_check((unsigned)(STRLEN(oldp) + totlen + 1));
          if (newp == NULL)
            goto end;                   /* alloc() gave an error message */
          mch_memmove(newp, oldp, (size_t)col);
          ptr = newp + col;
          for (i = 0; i < count; ++i) {
            mch_memmove(ptr, y_array[0], (size_t)yanklen);
            ptr += yanklen;
          }
          STRMOVE(ptr, oldp + col);
          ml_replace(lnum, newp, FALSE);
          /* Place cursor on last putted char. */
          if (lnum == curwin->w_cursor.lnum) {
            /* make sure curwin->w_virtcol is updated */
            changed_cline_bef_curs();
            curwin->w_cursor.col += (colnr_T)(totlen - 1);
          }
        }
        if (VIsual_active)
          lnum++;
      } while (
        VIsual_active && lnum <= curbuf->b_visual.vi_end.lnum
        );

      curbuf->b_op_end = curwin->w_cursor;
      /* For "CTRL-O p" in Insert mode, put cursor after last char */
      if (totlen && (restart_edit != 0 || (flags & PUT_CURSEND)))
        ++curwin->w_cursor.col;
      changed_bytes(lnum, col);
    } else   {
      /*
       * Insert at least one line.  When y_type is MCHAR, break the first
       * line in two.
       */
      for (cnt = 1; cnt <= count; ++cnt) {
        i = 0;
        if (y_type == MCHAR) {
          /*
           * Split the current line in two at the insert position.
           * First insert y_array[size - 1] in front of second line.
           * Then append y_array[0] to first line.
           */
          lnum = new_cursor.lnum;
          ptr = ml_get(lnum) + col;
          totlen = (int)STRLEN(y_array[y_size - 1]);
          newp = alloc_check((unsigned)(STRLEN(ptr) + totlen + 1));
          if (newp == NULL)
            goto error;
          STRCPY(newp, y_array[y_size - 1]);
          STRCAT(newp, ptr);
          /* insert second line */
          ml_append(lnum, newp, (colnr_T)0, FALSE);
          vim_free(newp);

          oldp = ml_get(lnum);
          newp = alloc_check((unsigned)(col + yanklen + 1));
          if (newp == NULL)
            goto error;
          /* copy first part of line */
          mch_memmove(newp, oldp, (size_t)col);
          /* append to first line */
          mch_memmove(newp + col, y_array[0], (size_t)(yanklen + 1));
          ml_replace(lnum, newp, FALSE);

          curwin->w_cursor.lnum = lnum;
          i = 1;
        }

        for (; i < y_size; ++i) {
          if ((y_type != MCHAR || i < y_size - 1)
              && ml_append(lnum, y_array[i], (colnr_T)0, FALSE)
              == FAIL)
            goto error;
          lnum++;
          ++nr_lines;
          if (flags & PUT_FIXINDENT) {
            old_pos = curwin->w_cursor;
            curwin->w_cursor.lnum = lnum;
            ptr = ml_get(lnum);
            if (cnt == count && i == y_size - 1)
              lendiff = (int)STRLEN(ptr);
            if (*ptr == '#' && preprocs_left())
              indent = 0;                   /* Leave # lines at start */
            else if (*ptr == NUL)
              indent = 0;                   /* Ignore empty lines */
            else if (first_indent) {
              indent_diff = orig_indent - get_indent();
              indent = orig_indent;
              first_indent = FALSE;
            } else if ((indent = get_indent() + indent_diff) < 0)
              indent = 0;
            (void)set_indent(indent, 0);
            curwin->w_cursor = old_pos;
            /* remember how many chars were removed */
            if (cnt == count && i == y_size - 1)
              lendiff -= (int)STRLEN(ml_get(lnum));
          }
        }
      }

error:
      /* Adjust marks. */
      if (y_type == MLINE) {
        curbuf->b_op_start.col = 0;
        if (dir == FORWARD)
          curbuf->b_op_start.lnum++;
      }
      mark_adjust(curbuf->b_op_start.lnum + (y_type == MCHAR),
          (linenr_T)MAXLNUM, nr_lines, 0L);

      /* note changed text for displaying and folding */
      if (y_type == MCHAR)
        changed_lines(curwin->w_cursor.lnum, col,
            curwin->w_cursor.lnum + 1, nr_lines);
      else
        changed_lines(curbuf->b_op_start.lnum, 0,
            curbuf->b_op_start.lnum, nr_lines);

      /* put '] mark at last inserted character */
      curbuf->b_op_end.lnum = lnum;
      /* correct length for change in indent */
      col = (colnr_T)STRLEN(y_array[y_size - 1]) - lendiff;
      if (col > 1)
        curbuf->b_op_end.col = col - 1;
      else
        curbuf->b_op_end.col = 0;

      if (flags & PUT_CURSLINE) {
        /* ":put": put cursor on last inserted line */
        curwin->w_cursor.lnum = lnum;
        beginline(BL_WHITE | BL_FIX);
      } else if (flags & PUT_CURSEND)   {
        /* put cursor after inserted text */
        if (y_type == MLINE) {
          if (lnum >= curbuf->b_ml.ml_line_count)
            curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
          else
            curwin->w_cursor.lnum = lnum + 1;
          curwin->w_cursor.col = 0;
        } else   {
          curwin->w_cursor.lnum = lnum;
          curwin->w_cursor.col = col;
        }
      } else if (y_type == MLINE)   {
        /* put cursor on first non-blank in first inserted line */
        curwin->w_cursor.col = 0;
        if (dir == FORWARD)
          ++curwin->w_cursor.lnum;
        beginline(BL_WHITE | BL_FIX);
      } else            /* put cursor on first inserted character */
        curwin->w_cursor = new_cursor;
    }
  }

  msgmore(nr_lines);
  curwin->w_set_curswant = TRUE;

end:
  if (allocated)
    vim_free(insert_string);
  if (regname == '=')
    vim_free(y_array);

  VIsual_active = FALSE;

  /* If the cursor is past the end of the line put it at the end. */
  adjust_cursor_eol();
}

/*
 * When the cursor is on the NUL past the end of the line and it should not be
 * there move it left.
 */
void adjust_cursor_eol(void)          {
  if (curwin->w_cursor.col > 0
      && gchar_cursor() == NUL
      && (ve_flags & VE_ONEMORE) == 0
      && !(restart_edit || (State & INSERT))) {
    /* Put the cursor on the last character in the line. */
    dec_cursor();

    if (ve_flags == VE_ALL) {
      colnr_T scol, ecol;

      /* Coladd is set to the width of the last character. */
      getvcol(curwin, &curwin->w_cursor, &scol, NULL, &ecol);
      curwin->w_cursor.coladd = ecol - scol + 1;
    }
  }
}

/*
 * Return TRUE if lines starting with '#' should be left aligned.
 */
int preprocs_left(void)         {
  return
    (curbuf->b_p_si && !curbuf->b_p_cin) ||
    (curbuf->b_p_cin && in_cinkeys('#', ' ', TRUE)
     && curbuf->b_ind_hash_comment == 0)
  ;
}

/* Return the character name of the register with the given number */
int get_register_name(int num)
{
  if (num == -1)
    return '"';
  else if (num < 10)
    return num + '0';
  else if (num == DELETION_REGISTER)
    return '-';
  else {
    return num + 'a' - 10;
  }
}

/*
 * ":dis" and ":registers": Display the contents of the yank registers.
 */
void ex_display(exarg_T *eap)
{
  int i, n;
  long j;
  char_u              *p;
  struct yankreg      *yb;
  int name;
  int attr;
  char_u              *arg = eap->arg;
  int clen;

  if (arg != NULL && *arg == NUL)
    arg = NULL;
  attr = hl_attr(HLF_8);

  /* Highlight title */
  MSG_PUTS_TITLE(_("\n--- Registers ---"));
  for (i = -1; i < NUM_REGISTERS && !got_int; ++i) {
    name = get_register_name(i);
    if (arg != NULL && vim_strchr(arg, name) == NULL
#ifdef ONE_CLIPBOARD
        /* Star register and plus register contain the same thing. */
        && (name != '*' || vim_strchr(arg, '+') == NULL)
#endif
        )
      continue;             /* did not ask for this register */


    if (i == -1) {
      if (y_previous != NULL)
        yb = y_previous;
      else
        yb = &(y_regs[0]);
    } else
      yb = &(y_regs[i]);

    if (name == MB_TOLOWER(redir_reg)
        || (redir_reg == '"' && yb == y_previous))
      continue;             /* do not list register being written to, the
                             * pointer can be freed */

    if (yb->y_array != NULL) {
      msg_putchar('\n');
      msg_putchar('"');
      msg_putchar(name);
      MSG_PUTS("   ");

      n = (int)Columns - 6;
      for (j = 0; j < yb->y_size && n > 1; ++j) {
        if (j) {
          MSG_PUTS_ATTR("^J", attr);
          n -= 2;
        }
        for (p = yb->y_array[j]; *p && (n -= ptr2cells(p)) >= 0; ++p) {
          clen = (*mb_ptr2len)(p);
          msg_outtrans_len(p, clen);
          p += clen - 1;
        }
      }
      if (n > 1 && yb->y_type == MLINE)
        MSG_PUTS_ATTR("^J", attr);
      out_flush();                          /* show one line at a time */
    }
    ui_breakcheck();
  }

  /*
   * display last inserted text
   */
  if ((p = get_last_insert()) != NULL
      && (arg == NULL || vim_strchr(arg, '.') != NULL) && !got_int) {
    MSG_PUTS("\n\".   ");
    dis_msg(p, TRUE);
  }

  /*
   * display last command line
   */
  if (last_cmdline != NULL && (arg == NULL || vim_strchr(arg, ':') != NULL)
      && !got_int) {
    MSG_PUTS("\n\":   ");
    dis_msg(last_cmdline, FALSE);
  }

  /*
   * display current file name
   */
  if (curbuf->b_fname != NULL
      && (arg == NULL || vim_strchr(arg, '%') != NULL) && !got_int) {
    MSG_PUTS("\n\"%   ");
    dis_msg(curbuf->b_fname, FALSE);
  }

  /*
   * display alternate file name
   */
  if ((arg == NULL || vim_strchr(arg, '%') != NULL) && !got_int) {
    char_u      *fname;
    linenr_T dummy;

    if (buflist_name_nr(0, &fname, &dummy) != FAIL) {
      MSG_PUTS("\n\"#   ");
      dis_msg(fname, FALSE);
    }
  }

  /*
   * display last search pattern
   */
  if (last_search_pat() != NULL
      && (arg == NULL || vim_strchr(arg, '/') != NULL) && !got_int) {
    MSG_PUTS("\n\"/   ");
    dis_msg(last_search_pat(), FALSE);
  }

  /*
   * display last used expression
   */
  if (expr_line != NULL && (arg == NULL || vim_strchr(arg, '=') != NULL)
      && !got_int) {
    MSG_PUTS("\n\"=   ");
    dis_msg(expr_line, FALSE);
  }
}

/*
 * display a string for do_dis()
 * truncate at end of screen line
 */
static void 
dis_msg (
    char_u *p,
    int skip_esc                       /* if TRUE, ignore trailing ESC */
)
{
  int n;
  int l;

  n = (int)Columns - 6;
  while (*p != NUL
         && !(*p == ESC && skip_esc && *(p + 1) == NUL)
         && (n -= ptr2cells(p)) >= 0) {
    if (has_mbyte && (l = (*mb_ptr2len)(p)) > 1) {
      msg_outtrans_len(p, l);
      p += l;
    } else
      msg_outtrans_len(p++, 1);
  }
  ui_breakcheck();
}

/*
 * If "process" is TRUE and the line begins with a comment leader (possibly
 * after some white space), return a pointer to the text after it. Put a boolean
 * value indicating whether the line ends with an unclosed comment in
 * "is_comment".
 * line - line to be processed,
 * process - if FALSE, will only check whether the line ends with an unclosed
 *	     comment,
 * include_space - whether to also skip space following the comment leader,
 * is_comment - will indicate whether the current line ends with an unclosed
 *		comment.
 */
static char_u *skip_comment(char_u *line, int process, int include_space, int *is_comment)
{
  char_u *comment_flags = NULL;
  int lead_len;
  int leader_offset = get_last_leader_offset(line, &comment_flags);

  *is_comment = FALSE;
  if (leader_offset != -1) {
    /* Let's check whether the line ends with an unclosed comment.
     * If the last comment leader has COM_END in flags, there's no comment.
     */
    while (*comment_flags) {
      if (*comment_flags == COM_END
          || *comment_flags == ':')
        break;
      ++comment_flags;
    }
    if (*comment_flags != COM_END)
      *is_comment = TRUE;
  }

  if (process == FALSE)
    return line;

  lead_len = get_leader_len(line, &comment_flags, FALSE, include_space);

  if (lead_len == 0)
    return line;

  /* Find:
   * - COM_END,
   * - colon,
   * whichever comes first.
   */
  while (*comment_flags) {
    if (*comment_flags == COM_END
        || *comment_flags == ':') {
      break;
    }
    ++comment_flags;
  }

  /* If we found a colon, it means that we are not processing a line
   * starting with a closing part of a three-part comment. That's good,
   * because we don't want to remove those as this would be annoying.
   */
  if (*comment_flags == ':' || *comment_flags == NUL)
    line += lead_len;

  return line;
}

/*
 * Join 'count' lines (minimal 2) at cursor position.
 * When "save_undo" is TRUE save lines for undo first.
 * Set "use_formatoptions" to FALSE when e.g. processing
 * backspace and comment leaders should not be removed.
 *
 * return FAIL for failure, OK otherwise
 */
int do_join(long count, int insert_space, int save_undo, int use_formatoptions)
{
  char_u      *curr = NULL;
  char_u      *curr_start = NULL;
  char_u      *cend;
  char_u      *newp;
  char_u      *spaces;          /* number of spaces inserted before a line */
  int endcurr1 = NUL;
  int endcurr2 = NUL;
  int currsize = 0;             /* size of the current line */
  int sumsize = 0;              /* size of the long new line */
  linenr_T t;
  colnr_T col = 0;
  int ret = OK;
  int         *comments = NULL;
  int remove_comments = (use_formatoptions == TRUE)
                        && has_format_option(FO_REMOVE_COMS);
  int prev_was_comment;


  if (save_undo && u_save((linenr_T)(curwin->w_cursor.lnum - 1),
          (linenr_T)(curwin->w_cursor.lnum + count)) == FAIL)
    return FAIL;

  /* Allocate an array to store the number of spaces inserted before each
   * line.  We will use it to pre-compute the length of the new line and the
   * proper placement of each original line in the new one. */
  spaces = lalloc_clear((long_u)count, TRUE);
  if (spaces == NULL)
    return FAIL;
  if (remove_comments) {
    comments = (int *)lalloc_clear((long_u)count * sizeof(int), TRUE);
    if (comments == NULL) {
      vim_free(spaces);
      return FAIL;
    }
  }

  /*
   * Don't move anything, just compute the final line length
   * and setup the array of space strings lengths
   */
  for (t = 0; t < count; ++t) {
    curr = curr_start = ml_get((linenr_T)(curwin->w_cursor.lnum + t));
    if (remove_comments) {
      /* We don't want to remove the comment leader if the
       * previous line is not a comment. */
      if (t > 0 && prev_was_comment) {

        char_u *new_curr = skip_comment(curr, TRUE, insert_space,
            &prev_was_comment);
        comments[t] = (int)(new_curr - curr);
        curr = new_curr;
      } else
        curr = skip_comment(curr, FALSE, insert_space,
            &prev_was_comment);
    }

    if (insert_space && t > 0) {
      curr = skipwhite(curr);
      if (*curr != ')' && currsize != 0 && endcurr1 != TAB
          && (!has_format_option(FO_MBYTE_JOIN)
              || (mb_ptr2char(curr) < 0x100 && endcurr1 < 0x100))
          && (!has_format_option(FO_MBYTE_JOIN2)
              || mb_ptr2char(curr) < 0x100 || endcurr1 < 0x100)
          ) {
        /* don't add a space if the line is ending in a space */
        if (endcurr1 == ' ')
          endcurr1 = endcurr2;
        else
          ++spaces[t];
        /* extra space when 'joinspaces' set and line ends in '.' */
        if (       p_js
                   && (endcurr1 == '.'
                       || (vim_strchr(p_cpo, CPO_JOINSP) == NULL
                           && (endcurr1 == '?' || endcurr1 == '!'))))
          ++spaces[t];
      }
    }
    currsize = (int)STRLEN(curr);
    sumsize += currsize + spaces[t];
    endcurr1 = endcurr2 = NUL;
    if (insert_space && currsize > 0) {
      if (has_mbyte) {
        cend = curr + currsize;
        mb_ptr_back(curr, cend);
        endcurr1 = (*mb_ptr2char)(cend);
        if (cend > curr) {
          mb_ptr_back(curr, cend);
          endcurr2 = (*mb_ptr2char)(cend);
        }
      } else   {
        endcurr1 = *(curr + currsize - 1);
        if (currsize > 1)
          endcurr2 = *(curr + currsize - 2);
      }
    }
    line_breakcheck();
    if (got_int) {
      ret = FAIL;
      goto theend;
    }
  }

  /* store the column position before last line */
  col = sumsize - currsize - spaces[count - 1];

  /* allocate the space for the new line */
  newp = alloc_check((unsigned)(sumsize + 1));
  cend = newp + sumsize;
  *cend = 0;

  /*
   * Move affected lines to the new long one.
   *
   * Move marks from each deleted line to the joined line, adjusting the
   * column.  This is not Vi compatible, but Vi deletes the marks, thus that
   * should not really be a problem.
   */
  for (t = count - 1;; --t) {
    cend -= currsize;
    mch_memmove(cend, curr, (size_t)currsize);
    if (spaces[t] > 0) {
      cend -= spaces[t];
      copy_spaces(cend, (size_t)(spaces[t]));
    }
    mark_col_adjust(curwin->w_cursor.lnum + t, (colnr_T)0, (linenr_T)-t,
        (long)(cend - newp + spaces[t] - (curr - curr_start)));
    if (t == 0)
      break;
    curr = curr_start = ml_get((linenr_T)(curwin->w_cursor.lnum + t - 1));
    if (remove_comments)
      curr += comments[t - 1];
    if (insert_space && t > 1)
      curr = skipwhite(curr);
    currsize = (int)STRLEN(curr);
  }
  ml_replace(curwin->w_cursor.lnum, newp, FALSE);

  /* Only report the change in the first line here, del_lines() will report
   * the deleted line. */
  changed_lines(curwin->w_cursor.lnum, currsize,
      curwin->w_cursor.lnum + 1, 0L);

  /*
   * Delete following lines. To do this we move the cursor there
   * briefly, and then move it back. After del_lines() the cursor may
   * have moved up (last line deleted), so the current lnum is kept in t.
   */
  t = curwin->w_cursor.lnum;
  ++curwin->w_cursor.lnum;
  del_lines(count - 1, FALSE);
  curwin->w_cursor.lnum = t;

  /*
   * Set the cursor column:
   * Vi compatible: use the column of the first join
   * vim:	      use the column of the last join
   */
  curwin->w_cursor.col =
    (vim_strchr(p_cpo, CPO_JOINCOL) != NULL ? currsize : col);
  check_cursor_col();

  curwin->w_cursor.coladd = 0;
  curwin->w_set_curswant = TRUE;

theend:
  vim_free(spaces);
  if (remove_comments)
    vim_free(comments);
  return ret;
}

/*
 * Return TRUE if the two comment leaders given are the same.  "lnum" is
 * the first line.  White-space is ignored.  Note that the whole of
 * 'leader1' must match 'leader2_len' characters from 'leader2' -- webb
 */
static int same_leader(linenr_T lnum, int leader1_len, char_u *leader1_flags, int leader2_len, char_u *leader2_flags)
{
  int idx1 = 0, idx2 = 0;
  char_u  *p;
  char_u  *line1;
  char_u  *line2;

  if (leader1_len == 0)
    return leader2_len == 0;

  /*
   * If first leader has 'f' flag, the lines can be joined only if the
   * second line does not have a leader.
   * If first leader has 'e' flag, the lines can never be joined.
   * If fist leader has 's' flag, the lines can only be joined if there is
   * some text after it and the second line has the 'm' flag.
   */
  if (leader1_flags != NULL) {
    for (p = leader1_flags; *p && *p != ':'; ++p) {
      if (*p == COM_FIRST)
        return leader2_len == 0;
      if (*p == COM_END)
        return FALSE;
      if (*p == COM_START) {
        if (*(ml_get(lnum) + leader1_len) == NUL)
          return FALSE;
        if (leader2_flags == NULL || leader2_len == 0)
          return FALSE;
        for (p = leader2_flags; *p && *p != ':'; ++p)
          if (*p == COM_MIDDLE)
            return TRUE;
        return FALSE;
      }
    }
  }

  /*
   * Get current line and next line, compare the leaders.
   * The first line has to be saved, only one line can be locked at a time.
   */
  line1 = vim_strsave(ml_get(lnum));
  if (line1 != NULL) {
    for (idx1 = 0; vim_iswhite(line1[idx1]); ++idx1)
      ;
    line2 = ml_get(lnum + 1);
    for (idx2 = 0; idx2 < leader2_len; ++idx2) {
      if (!vim_iswhite(line2[idx2])) {
        if (line1[idx1++] != line2[idx2])
          break;
      } else
        while (vim_iswhite(line1[idx1]))
          ++idx1;
    }
    vim_free(line1);
  }
  return idx2 == leader2_len && idx1 == leader1_len;
}

/*
 * Implementation of the format operator 'gq'.
 */
void 
op_format (
    oparg_T *oap,
    int keep_cursor                        /* keep cursor on same text char */
)
{
  long old_line_count = curbuf->b_ml.ml_line_count;

  /* Place the cursor where the "gq" or "gw" command was given, so that "u"
   * can put it back there. */
  curwin->w_cursor = oap->cursor_start;

  if (u_save((linenr_T)(oap->start.lnum - 1),
          (linenr_T)(oap->end.lnum + 1)) == FAIL)
    return;
  curwin->w_cursor = oap->start;

  if (oap->is_VIsual)
    /* When there is no change: need to remove the Visual selection */
    redraw_curbuf_later(INVERTED);

  /* Set '[ mark at the start of the formatted area */
  curbuf->b_op_start = oap->start;

  /* For "gw" remember the cursor position and put it back below (adjusted
   * for joined and split lines). */
  if (keep_cursor)
    saved_cursor = oap->cursor_start;

  format_lines(oap->line_count, keep_cursor);

  /*
   * Leave the cursor at the first non-blank of the last formatted line.
   * If the cursor was moved one line back (e.g. with "Q}") go to the next
   * line, so "." will do the next lines.
   */
  if (oap->end_adjusted && curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count)
    ++curwin->w_cursor.lnum;
  beginline(BL_WHITE | BL_FIX);
  old_line_count = curbuf->b_ml.ml_line_count - old_line_count;
  msgmore(old_line_count);

  /* put '] mark on the end of the formatted area */
  curbuf->b_op_end = curwin->w_cursor;

  if (keep_cursor) {
    curwin->w_cursor = saved_cursor;
    saved_cursor.lnum = 0;
  }

  if (oap->is_VIsual) {
    win_T   *wp;

    FOR_ALL_WINDOWS(wp)
    {
      if (wp->w_old_cursor_lnum != 0) {
        /* When lines have been inserted or deleted, adjust the end of
         * the Visual area to be redrawn. */
        if (wp->w_old_cursor_lnum > wp->w_old_visual_lnum)
          wp->w_old_cursor_lnum += old_line_count;
        else
          wp->w_old_visual_lnum += old_line_count;
      }
    }
  }
}

/*
 * Implementation of the format operator 'gq' for when using 'formatexpr'.
 */
void op_formatexpr(oparg_T *oap)
{
  if (oap->is_VIsual)
    /* When there is no change: need to remove the Visual selection */
    redraw_curbuf_later(INVERTED);

  if (fex_format(oap->start.lnum, oap->line_count, NUL) != 0)
    /* As documented: when 'formatexpr' returns non-zero fall back to
     * internal formatting. */
    op_format(oap, FALSE);
}

int 
fex_format (
    linenr_T lnum,
    long count,
    int c                  /* character to be inserted */
)
{
  int use_sandbox = was_set_insecurely((char_u *)"formatexpr",
      OPT_LOCAL);
  int r;

  /*
   * Set v:lnum to the first line number and v:count to the number of lines.
   * Set v:char to the character to be inserted (can be NUL).
   */
  set_vim_var_nr(VV_LNUM, lnum);
  set_vim_var_nr(VV_COUNT, count);
  set_vim_var_char(c);

  /*
   * Evaluate the function.
   */
  if (use_sandbox)
    ++sandbox;
  r = eval_to_number(curbuf->b_p_fex);
  if (use_sandbox)
    --sandbox;

  set_vim_var_string(VV_CHAR, NULL, -1);

  return r;
}

/*
 * Format "line_count" lines, starting at the cursor position.
 * When "line_count" is negative, format until the end of the paragraph.
 * Lines after the cursor line are saved for undo, caller must have saved the
 * first line.
 */
void 
format_lines (
    linenr_T line_count,
    int avoid_fex                          /* don't use 'formatexpr' */
)
{
  int max_len;
  int is_not_par;                       /* current line not part of parag. */
  int next_is_not_par;                  /* next line not part of paragraph */
  int is_end_par;                       /* at end of paragraph */
  int prev_is_end_par = FALSE;          /* prev. line not part of parag. */
  int next_is_start_par = FALSE;
  int leader_len = 0;                   /* leader len of current line */
  int next_leader_len;                  /* leader len of next line */
  char_u      *leader_flags = NULL;     /* flags for leader of current line */
  char_u      *next_leader_flags;       /* flags for leader of next line */
  int do_comments;                      /* format comments */
  int do_comments_list = 0;             /* format comments with 'n' or '2' */
  int advance = TRUE;
  int second_indent = -1;               /* indent for second line (comment
                                         * aware) */
  int do_second_indent;
  int do_number_indent;
  int do_trail_white;
  int first_par_line = TRUE;
  int smd_save;
  long count;
  int need_set_indent = TRUE;           /* set indent of next paragraph */
  int force_format = FALSE;
  int old_State = State;

  /* length of a line to force formatting: 3 * 'tw' */
  max_len = comp_textwidth(TRUE) * 3;

  /* check for 'q', '2' and '1' in 'formatoptions' */
  do_comments = has_format_option(FO_Q_COMS);
  do_second_indent = has_format_option(FO_Q_SECOND);
  do_number_indent = has_format_option(FO_Q_NUMBER);
  do_trail_white = has_format_option(FO_WHITE_PAR);

  /*
   * Get info about the previous and current line.
   */
  if (curwin->w_cursor.lnum > 1)
    is_not_par = fmt_check_par(curwin->w_cursor.lnum - 1
        , &leader_len, &leader_flags, do_comments
        );
  else
    is_not_par = TRUE;
  next_is_not_par = fmt_check_par(curwin->w_cursor.lnum
      , &next_leader_len, &next_leader_flags, do_comments
      );
  is_end_par = (is_not_par || next_is_not_par);
  if (!is_end_par && do_trail_white)
    is_end_par = !ends_in_white(curwin->w_cursor.lnum - 1);

  curwin->w_cursor.lnum--;
  for (count = line_count; count != 0 && !got_int; --count) {
    /*
     * Advance to next paragraph.
     */
    if (advance) {
      curwin->w_cursor.lnum++;
      prev_is_end_par = is_end_par;
      is_not_par = next_is_not_par;
      leader_len = next_leader_len;
      leader_flags = next_leader_flags;
    }

    /*
     * The last line to be formatted.
     */
    if (count == 1 || curwin->w_cursor.lnum == curbuf->b_ml.ml_line_count) {
      next_is_not_par = TRUE;
      next_leader_len = 0;
      next_leader_flags = NULL;
    } else   {
      next_is_not_par = fmt_check_par(curwin->w_cursor.lnum + 1
          , &next_leader_len, &next_leader_flags, do_comments
          );
      if (do_number_indent)
        next_is_start_par =
          (get_number_indent(curwin->w_cursor.lnum + 1) > 0);
    }
    advance = TRUE;
    is_end_par = (is_not_par || next_is_not_par || next_is_start_par);
    if (!is_end_par && do_trail_white)
      is_end_par = !ends_in_white(curwin->w_cursor.lnum);

    /*
     * Skip lines that are not in a paragraph.
     */
    if (is_not_par) {
      if (line_count < 0)
        break;
    } else   {
      /*
       * For the first line of a paragraph, check indent of second line.
       * Don't do this for comments and empty lines.
       */
      if (first_par_line
          && (do_second_indent || do_number_indent)
          && prev_is_end_par
          && curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count) {
        if (do_second_indent && !lineempty(curwin->w_cursor.lnum + 1)) {
          if (leader_len == 0 && next_leader_len == 0) {
            /* no comment found */
            second_indent =
              get_indent_lnum(curwin->w_cursor.lnum + 1);
          } else   {
            second_indent = next_leader_len;
            do_comments_list = 1;
          }
        } else if (do_number_indent)   {
          if (leader_len == 0 && next_leader_len == 0) {
            /* no comment found */
            second_indent =
              get_number_indent(curwin->w_cursor.lnum);
          } else   {
            /* get_number_indent() is now "comment aware"... */
            second_indent =
              get_number_indent(curwin->w_cursor.lnum);
            do_comments_list = 1;
          }
        }
      }

      /*
       * When the comment leader changes, it's the end of the paragraph.
       */
      if (curwin->w_cursor.lnum >= curbuf->b_ml.ml_line_count
          || !same_leader(curwin->w_cursor.lnum,
              leader_len, leader_flags,
              next_leader_len, next_leader_flags)
          )
        is_end_par = TRUE;

      /*
       * If we have got to the end of a paragraph, or the line is
       * getting long, format it.
       */
      if (is_end_par || force_format) {
        if (need_set_indent)
          /* replace indent in first line with minimal number of
           * tabs and spaces, according to current options */
          (void)set_indent(get_indent(), SIN_CHANGED);

        /* put cursor on last non-space */
        State = NORMAL;         /* don't go past end-of-line */
        coladvance((colnr_T)MAXCOL);
        while (curwin->w_cursor.col && vim_isspace(gchar_cursor()))
          dec_cursor();

        /* do the formatting, without 'showmode' */
        State = INSERT;         /* for open_line() */
        smd_save = p_smd;
        p_smd = FALSE;
        insertchar(NUL, INSCHAR_FORMAT
            + (do_comments ? INSCHAR_DO_COM : 0)
            + (do_comments && do_comments_list
               ? INSCHAR_COM_LIST : 0)
            + (avoid_fex ? INSCHAR_NO_FEX : 0), second_indent);
        State = old_State;
        p_smd = smd_save;
        second_indent = -1;
        /* at end of par.: need to set indent of next par. */
        need_set_indent = is_end_par;
        if (is_end_par) {
          /* When called with a negative line count, break at the
           * end of the paragraph. */
          if (line_count < 0)
            break;
          first_par_line = TRUE;
        }
        force_format = FALSE;
      }

      /*
       * When still in same paragraph, join the lines together.  But
       * first delete the leader from the second line.
       */
      if (!is_end_par) {
        advance = FALSE;
        curwin->w_cursor.lnum++;
        curwin->w_cursor.col = 0;
        if (line_count < 0 && u_save_cursor() == FAIL)
          break;
        if (next_leader_len > 0) {
          (void)del_bytes((long)next_leader_len, FALSE, FALSE);
          mark_col_adjust(curwin->w_cursor.lnum, (colnr_T)0, 0L,
              (long)-next_leader_len);
        } else if (second_indent > 0)    {  /* the "leader" for FO_Q_SECOND */
          char_u *p = ml_get_curline();
          int indent = (int)(skipwhite(p) - p);

          if (indent > 0) {
            (void)del_bytes(indent, FALSE, FALSE);
            mark_col_adjust(curwin->w_cursor.lnum,
                (colnr_T)0, 0L, (long)-indent);
          }
        }
        curwin->w_cursor.lnum--;
        if (do_join(2, TRUE, FALSE, FALSE) == FAIL) {
          beep_flush();
          break;
        }
        first_par_line = FALSE;
        /* If the line is getting long, format it next time */
        if (STRLEN(ml_get_curline()) > (size_t)max_len)
          force_format = TRUE;
        else
          force_format = FALSE;
      }
    }
    line_breakcheck();
  }
}

/*
 * Return TRUE if line "lnum" ends in a white character.
 */
static int ends_in_white(linenr_T lnum)
{
  char_u      *s = ml_get(lnum);
  size_t l;

  if (*s == NUL)
    return FALSE;
  /* Don't use STRLEN() inside vim_iswhite(), SAS/C complains: "macro
   * invocation may call function multiple times". */
  l = STRLEN(s) - 1;
  return vim_iswhite(s[l]);
}

/*
 * Blank lines, and lines containing only the comment leader, are left
 * untouched by the formatting.  The function returns TRUE in this
 * case.  It also returns TRUE when a line starts with the end of a comment
 * ('e' in comment flags), so that this line is skipped, and not joined to the
 * previous line.  A new paragraph starts after a blank line, or when the
 * comment leader changes -- webb.
 */
static int fmt_check_par(linenr_T lnum, int *leader_len, char_u **leader_flags, int do_comments)
{
  char_u      *flags = NULL;        /* init for GCC */
  char_u      *ptr;

  ptr = ml_get(lnum);
  if (do_comments)
    *leader_len = get_leader_len(ptr, leader_flags, FALSE, TRUE);
  else
    *leader_len = 0;

  if (*leader_len > 0) {
    /*
     * Search for 'e' flag in comment leader flags.
     */
    flags = *leader_flags;
    while (*flags && *flags != ':' && *flags != COM_END)
      ++flags;
  }

  return *skipwhite(ptr + *leader_len) == NUL
         || (*leader_len > 0 && *flags == COM_END)
         || startPS(lnum, NUL, FALSE);
}

/*
 * Return TRUE when a paragraph starts in line "lnum".  Return FALSE when the
 * previous line is in the same paragraph.  Used for auto-formatting.
 */
int paragraph_start(linenr_T lnum)
{
  char_u *p;
  int leader_len = 0;                   /* leader len of current line */
  char_u *leader_flags = NULL;          /* flags for leader of current line */
  int next_leader_len = 0;              /* leader len of next line */
  char_u *next_leader_flags = NULL;     /* flags for leader of next line */
  int do_comments;                      /* format comments */

  if (lnum <= 1)
    return TRUE;                /* start of the file */

  p = ml_get(lnum - 1);
  if (*p == NUL)
    return TRUE;                /* after empty line */

  do_comments = has_format_option(FO_Q_COMS);
  if (fmt_check_par(lnum - 1
          , &leader_len, &leader_flags, do_comments
          ))
    return TRUE;                /* after non-paragraph line */

  if (fmt_check_par(lnum
          , &next_leader_len, &next_leader_flags, do_comments
          ))
    return TRUE;                /* "lnum" is not a paragraph line */

  if (has_format_option(FO_WHITE_PAR) && !ends_in_white(lnum - 1))
    return TRUE;                /* missing trailing space in previous line. */

  if (has_format_option(FO_Q_NUMBER) && (get_number_indent(lnum) > 0))
    return TRUE;                /* numbered item starts in "lnum". */

  if (!same_leader(lnum - 1, leader_len, leader_flags,
          next_leader_len, next_leader_flags))
    return TRUE;                /* change of comment leader. */

  return FALSE;
}

/*
 * prepare a few things for block mode yank/delete/tilde
 *
 * for delete:
 * - textlen includes the first/last char to be (partly) deleted
 * - start/endspaces is the number of columns that are taken by the
 *   first/last deleted char minus the number of columns that have to be
 *   deleted.
 * for yank and tilde:
 * - textlen includes the first/last char to be wholly yanked
 * - start/endspaces is the number of columns of the first/last yanked char
 *   that are to be yanked.
 */
static void block_prep(oparg_T *oap, struct block_def *bdp, linenr_T lnum, int is_del)
{
  int incr = 0;
  char_u      *pend;
  char_u      *pstart;
  char_u      *line;
  char_u      *prev_pstart;
  char_u      *prev_pend;

  bdp->startspaces = 0;
  bdp->endspaces = 0;
  bdp->textlen = 0;
  bdp->start_vcol = 0;
  bdp->end_vcol = 0;
  bdp->is_short = FALSE;
  bdp->is_oneChar = FALSE;
  bdp->pre_whitesp = 0;
  bdp->pre_whitesp_c = 0;
  bdp->end_char_vcols = 0;
  bdp->start_char_vcols = 0;

  line = ml_get(lnum);
  pstart = line;
  prev_pstart = line;
  while (bdp->start_vcol < oap->start_vcol && *pstart) {
    /* Count a tab for what it's worth (if list mode not on) */
    incr = lbr_chartabsize(pstart, (colnr_T)bdp->start_vcol);
    bdp->start_vcol += incr;
    if (vim_iswhite(*pstart)) {
      bdp->pre_whitesp += incr;
      bdp->pre_whitesp_c++;
    } else   {
      bdp->pre_whitesp = 0;
      bdp->pre_whitesp_c = 0;
    }
    prev_pstart = pstart;
    mb_ptr_adv(pstart);
  }
  bdp->start_char_vcols = incr;
  if (bdp->start_vcol < oap->start_vcol) {      /* line too short */
    bdp->end_vcol = bdp->start_vcol;
    bdp->is_short = TRUE;
    if (!is_del || oap->op_type == OP_APPEND)
      bdp->endspaces = oap->end_vcol - oap->start_vcol + 1;
  } else   {
    /* notice: this converts partly selected Multibyte characters to
     * spaces, too. */
    bdp->startspaces = bdp->start_vcol - oap->start_vcol;
    if (is_del && bdp->startspaces)
      bdp->startspaces = bdp->start_char_vcols - bdp->startspaces;
    pend = pstart;
    bdp->end_vcol = bdp->start_vcol;
    if (bdp->end_vcol > oap->end_vcol) {        /* it's all in one character */
      bdp->is_oneChar = TRUE;
      if (oap->op_type == OP_INSERT)
        bdp->endspaces = bdp->start_char_vcols - bdp->startspaces;
      else if (oap->op_type == OP_APPEND) {
        bdp->startspaces += oap->end_vcol - oap->start_vcol + 1;
        bdp->endspaces = bdp->start_char_vcols - bdp->startspaces;
      } else   {
        bdp->startspaces = oap->end_vcol - oap->start_vcol + 1;
        if (is_del && oap->op_type != OP_LSHIFT) {
          /* just putting the sum of those two into
           * bdp->startspaces doesn't work for Visual replace,
           * so we have to split the tab in two */
          bdp->startspaces = bdp->start_char_vcols
                             - (bdp->start_vcol - oap->start_vcol);
          bdp->endspaces = bdp->end_vcol - oap->end_vcol - 1;
        }
      }
    } else   {
      prev_pend = pend;
      while (bdp->end_vcol <= oap->end_vcol && *pend != NUL) {
        /* Count a tab for what it's worth (if list mode not on) */
        prev_pend = pend;
        incr = lbr_chartabsize_adv(&pend, (colnr_T)bdp->end_vcol);
        bdp->end_vcol += incr;
      }
      if (bdp->end_vcol <= oap->end_vcol
          && (!is_del
              || oap->op_type == OP_APPEND
              || oap->op_type == OP_REPLACE)) {         /* line too short */
        bdp->is_short = TRUE;
        /* Alternative: include spaces to fill up the block.
         * Disadvantage: can lead to trailing spaces when the line is
         * short where the text is put */
        /* if (!is_del || oap->op_type == OP_APPEND) */
        if (oap->op_type == OP_APPEND || virtual_op)
          bdp->endspaces = oap->end_vcol - bdp->end_vcol
                           + oap->inclusive;
        else
          bdp->endspaces = 0;           /* replace doesn't add characters */
      } else if (bdp->end_vcol > oap->end_vcol)   {
        bdp->endspaces = bdp->end_vcol - oap->end_vcol - 1;
        if (!is_del && bdp->endspaces) {
          bdp->endspaces = incr - bdp->endspaces;
          if (pend != pstart)
            pend = prev_pend;
        }
      }
    }
    bdp->end_char_vcols = incr;
    if (is_del && bdp->startspaces)
      pstart = prev_pstart;
    bdp->textlen = (int)(pend - pstart);
  }
  bdp->textcol = (colnr_T) (pstart - line);
  bdp->textstart = pstart;
}

static void reverse_line(char_u *s);

static void reverse_line(char_u *s)
{
  int i, j;
  char_u c;

  if ((i = (int)STRLEN(s) - 1) <= 0)
    return;

  curwin->w_cursor.col = i - curwin->w_cursor.col;
  for (j = 0; j < i; j++, i--) {
    c = s[i]; s[i] = s[j]; s[j] = c;
  }
}

# define RLADDSUBFIX(ptr) if (curwin->w_p_rl) reverse_line(ptr);

/*
 * add or subtract 'Prenum1' from a number in a line
 * 'command' is CTRL-A for add, CTRL-X for subtract
 *
 * return FAIL for failure, OK otherwise
 */
int do_addsub(int command, linenr_T Prenum1)
{
  int col;
  char_u      *buf1;
  char_u buf2[NUMBUFLEN];
  int hex;                      /* 'X' or 'x': hex; '0': octal */
  static int hexupper = FALSE;          /* 0xABC */
  unsigned long n;
  long_u oldn;
  char_u      *ptr;
  int c;
  int length = 0;                       /* character length of the number */
  int todel;
  int dohex;
  int dooct;
  int doalp;
  int firstdigit;
  int negative;
  int subtract;

  dohex = (vim_strchr(curbuf->b_p_nf, 'x') != NULL);    /* "heX" */
  dooct = (vim_strchr(curbuf->b_p_nf, 'o') != NULL);    /* "Octal" */
  doalp = (vim_strchr(curbuf->b_p_nf, 'p') != NULL);    /* "alPha" */

  ptr = ml_get_curline();
  RLADDSUBFIX(ptr);

  /*
   * First check if we are on a hexadecimal number, after the "0x".
   */
  col = curwin->w_cursor.col;
  if (dohex)
    while (col > 0 && vim_isxdigit(ptr[col]))
      --col;
  if (       dohex
             && col > 0
             && (ptr[col] == 'X'
                 || ptr[col] == 'x')
             && ptr[col - 1] == '0'
             && vim_isxdigit(ptr[col + 1])) {
    /*
     * Found hexadecimal number, move to its start.
     */
    --col;
  } else   {
    /*
     * Search forward and then backward to find the start of number.
     */
    col = curwin->w_cursor.col;

    while (ptr[col] != NUL
           && !vim_isdigit(ptr[col])
           && !(doalp && ASCII_ISALPHA(ptr[col])))
      ++col;

    while (col > 0
           && vim_isdigit(ptr[col - 1])
           && !(doalp && ASCII_ISALPHA(ptr[col])))
      --col;
  }

  /*
   * If a number was found, and saving for undo works, replace the number.
   */
  firstdigit = ptr[col];
  RLADDSUBFIX(ptr);
  if ((!VIM_ISDIGIT(firstdigit) && !(doalp && ASCII_ISALPHA(firstdigit)))
      || u_save_cursor() != OK) {
    beep_flush();
    return FAIL;
  }

  /* get ptr again, because u_save() may have changed it */
  ptr = ml_get_curline();
  RLADDSUBFIX(ptr);

  if (doalp && ASCII_ISALPHA(firstdigit)) {
    /* decrement or increment alphabetic character */
    if (command == Ctrl_X) {
      if (CharOrd(firstdigit) < Prenum1) {
        if (isupper(firstdigit))
          firstdigit = 'A';
        else
          firstdigit = 'a';
      } else
        firstdigit -= Prenum1;
    } else   {
      if (26 - CharOrd(firstdigit) - 1 < Prenum1) {
        if (isupper(firstdigit))
          firstdigit = 'Z';
        else
          firstdigit = 'z';
      } else
        firstdigit += Prenum1;
    }
    curwin->w_cursor.col = col;
    (void)del_char(FALSE);
    ins_char(firstdigit);
  } else   {
    negative = FALSE;
    if (col > 0 && ptr[col - 1] == '-') {           /* negative number */
      --col;
      negative = TRUE;
    }

    /* get the number value (unsigned) */
    vim_str2nr(ptr + col, &hex, &length, dooct, dohex, NULL, &n);

    /* ignore leading '-' for hex and octal numbers */
    if (hex && negative) {
      ++col;
      --length;
      negative = FALSE;
    }

    /* add or subtract */
    subtract = FALSE;
    if (command == Ctrl_X)
      subtract ^= TRUE;
    if (negative)
      subtract ^= TRUE;

    oldn = n;
    if (subtract)
      n -= (unsigned long)Prenum1;
    else
      n += (unsigned long)Prenum1;

    /* handle wraparound for decimal numbers */
    if (!hex) {
      if (subtract) {
        if (n > oldn) {
          n = 1 + (n ^ (unsigned long)-1);
          negative ^= TRUE;
        }
      } else   { /* add */
        if (n < oldn) {
          n = (n ^ (unsigned long)-1);
          negative ^= TRUE;
        }
      }
      if (n == 0)
        negative = FALSE;
    }

    /*
     * Delete the old number.
     */
    curwin->w_cursor.col = col;
    todel = length;
    c = gchar_cursor();
    /*
     * Don't include the '-' in the length, only the length of the part
     * after it is kept the same.
     */
    if (c == '-')
      --length;
    while (todel-- > 0) {
      if (c < 0x100 && isalpha(c)) {
        if (isupper(c))
          hexupper = TRUE;
        else
          hexupper = FALSE;
      }
      /* del_char() will mark line needing displaying */
      (void)del_char(FALSE);
      c = gchar_cursor();
    }

    /*
     * Prepare the leading characters in buf1[].
     * When there are many leading zeros it could be very long.  Allocate
     * a bit too much.
     */
    buf1 = alloc((unsigned)length + NUMBUFLEN);
    if (buf1 == NULL)
      return FAIL;
    ptr = buf1;
    if (negative) {
      *ptr++ = '-';
    }
    if (hex) {
      *ptr++ = '0';
      --length;
    }
    if (hex == 'x' || hex == 'X') {
      *ptr++ = hex;
      --length;
    }

    /*
     * Put the number characters in buf2[].
     */
    if (hex == 0)
      sprintf((char *)buf2, "%lu", n);
    else if (hex == '0')
      sprintf((char *)buf2, "%lo", n);
    else if (hex && hexupper)
      sprintf((char *)buf2, "%lX", n);
    else
      sprintf((char *)buf2, "%lx", n);
    length -= (int)STRLEN(buf2);

    /*
     * Adjust number of zeros to the new number of digits, so the
     * total length of the number remains the same.
     * Don't do this when
     * the result may look like an octal number.
     */
    if (firstdigit == '0' && !(dooct && hex == 0))
      while (length-- > 0)
        *ptr++ = '0';
    *ptr = NUL;
    STRCAT(buf1, buf2);
    ins_str(buf1);              /* insert the new number */
    vim_free(buf1);
  }
  --curwin->w_cursor.col;
  curwin->w_set_curswant = TRUE;
  ptr = ml_get_buf(curbuf, curwin->w_cursor.lnum, TRUE);
  RLADDSUBFIX(ptr);
  return OK;
}

int read_viminfo_register(vir_T *virp, int force)
{
  int eof;
  int do_it = TRUE;
  int size;
  int limit;
  int i;
  int set_prev = FALSE;
  char_u      *str;
  char_u      **array = NULL;

  /* We only get here (hopefully) if line[0] == '"' */
  str = virp->vir_line + 1;

  /* If the line starts with "" this is the y_previous register. */
  if (*str == '"') {
    set_prev = TRUE;
    str++;
  }

  if (!ASCII_ISALNUM(*str) && *str != '-') {
    if (viminfo_error("E577: ", _("Illegal register name"), virp->vir_line))
      return TRUE;              /* too many errors, pretend end-of-file */
    do_it = FALSE;
  }
  get_yank_register(*str++, FALSE);
  if (!force && y_current->y_array != NULL)
    do_it = FALSE;

  if (*str == '@') {
    /* "x@: register x used for @@ */
    if (force || execreg_lastc == NUL)
      execreg_lastc = str[-1];
  }

  size = 0;
  limit = 100;          /* Optimized for registers containing <= 100 lines */
  if (do_it) {
    if (set_prev)
      y_previous = y_current;
    vim_free(y_current->y_array);
    array = y_current->y_array =
              (char_u **)alloc((unsigned)(limit * sizeof(char_u *)));
    str = skipwhite(skiptowhite(str));
    if (STRNCMP(str, "CHAR", 4) == 0)
      y_current->y_type = MCHAR;
    else if (STRNCMP(str, "BLOCK", 5) == 0)
      y_current->y_type = MBLOCK;
    else
      y_current->y_type = MLINE;
    /* get the block width; if it's missing we get a zero, which is OK */
    str = skipwhite(skiptowhite(str));
    y_current->y_width = getdigits(&str);
  }

  while (!(eof = viminfo_readline(virp))
         && (virp->vir_line[0] == TAB || virp->vir_line[0] == '<')) {
    if (do_it) {
      if (size >= limit) {
        y_current->y_array = (char_u **)
                             alloc((unsigned)(limit * 2 * sizeof(char_u *)));
        for (i = 0; i < limit; i++)
          y_current->y_array[i] = array[i];
        vim_free(array);
        limit *= 2;
        array = y_current->y_array;
      }
      str = viminfo_readstring(virp, 1, TRUE);
      if (str != NULL)
        array[size++] = str;
      else
        do_it = FALSE;
    }
  }
  if (do_it) {
    if (size == 0) {
      vim_free(array);
      y_current->y_array = NULL;
    } else if (size < limit)   {
      y_current->y_array =
        (char_u **)alloc((unsigned)(size * sizeof(char_u *)));
      for (i = 0; i < size; i++)
        y_current->y_array[i] = array[i];
      vim_free(array);
    }
    y_current->y_size = size;
  }
  return eof;
}

void write_viminfo_registers(FILE *fp)
{
  int i, j;
  char_u  *type;
  char_u c;
  int num_lines;
  int max_num_lines;
  int max_kbyte;
  long len;

  fputs(_("\n# Registers:\n"), fp);

  /* Get '<' value, use old '"' value if '<' is not found. */
  max_num_lines = get_viminfo_parameter('<');
  if (max_num_lines < 0)
    max_num_lines = get_viminfo_parameter('"');
  if (max_num_lines == 0)
    return;
  max_kbyte = get_viminfo_parameter('s');
  if (max_kbyte == 0)
    return;

  for (i = 0; i < NUM_REGISTERS; i++) {
    if (y_regs[i].y_array == NULL)
      continue;
    /* Skip empty registers. */
    num_lines = y_regs[i].y_size;
    if (num_lines == 0
        || (num_lines == 1 && y_regs[i].y_type == MCHAR
            && *y_regs[i].y_array[0] == NUL))
      continue;

    if (max_kbyte > 0) {
      /* Skip register if there is more text than the maximum size. */
      len = 0;
      for (j = 0; j < num_lines; j++)
        len += (long)STRLEN(y_regs[i].y_array[j]) + 1L;
      if (len > (long)max_kbyte * 1024L)
        continue;
    }

    switch (y_regs[i].y_type) {
    case MLINE:
      type = (char_u *)"LINE";
      break;
    case MCHAR:
      type = (char_u *)"CHAR";
      break;
    case MBLOCK:
      type = (char_u *)"BLOCK";
      break;
    default:
      sprintf((char *)IObuff, _("E574: Unknown register type %d"),
          y_regs[i].y_type);
      emsg(IObuff);
      type = (char_u *)"LINE";
      break;
    }
    if (y_previous == &y_regs[i])
      fprintf(fp, "\"");
    c = get_register_name(i);
    fprintf(fp, "\"%c", c);
    if (c == execreg_lastc)
      fprintf(fp, "@");
    fprintf(fp, "\t%s\t%d\n", type,
        (int)y_regs[i].y_width
        );

    /* If max_num_lines < 0, then we save ALL the lines in the register */
    if (max_num_lines > 0 && num_lines > max_num_lines)
      num_lines = max_num_lines;
    for (j = 0; j < num_lines; j++) {
      putc('\t', fp);
      viminfo_writestring(fp, y_regs[i].y_array[j]);
    }
  }
}





/*
 * Return the type of a register.
 * Used for getregtype()
 * Returns MAUTO for error.
 */
char_u get_reg_type(int regname, long *reglen)
{
  switch (regname) {
  case '%':                     /* file name */
  case '#':                     /* alternate file name */
  case '=':                     /* expression */
  case ':':                     /* last command line */
  case '/':                     /* last search-pattern */
  case '.':                     /* last inserted text */
  case Ctrl_F:                  /* Filename under cursor */
  case Ctrl_P:                  /* Path under cursor, expand via "path" */
  case Ctrl_W:                  /* word under cursor */
  case Ctrl_A:                  /* WORD (mnemonic All) under cursor */
  case '_':                     /* black hole: always empty */
    return MCHAR;
  }


  if (regname != NUL && !valid_yank_reg(regname, FALSE))
    return MAUTO;

  get_yank_register(regname, FALSE);

  if (y_current->y_array != NULL) {
    if (reglen != NULL && y_current->y_type == MBLOCK)
      *reglen = y_current->y_width;
    return y_current->y_type;
  }
  return MAUTO;
}

/*
 * Return the contents of a register as a single allocated string.
 * Used for "@r" in expressions and for getreg().
 * Returns NULL for error.
 */
char_u *
get_reg_contents (
    int regname,
    int allowexpr,                  /* allow "=" register */
    int expr_src                   /* get expression for "=" register */
)
{
  long i;
  char_u      *retval;
  int allocated;
  long len;

  /* Don't allow using an expression register inside an expression */
  if (regname == '=') {
    if (allowexpr) {
      if (expr_src)
        return get_expr_line_src();
      return get_expr_line();
    }
    return NULL;
  }

  if (regname == '@')       /* "@@" is used for unnamed register */
    regname = '"';

  /* check for valid regname */
  if (regname != NUL && !valid_yank_reg(regname, FALSE))
    return NULL;


  if (get_spec_reg(regname, &retval, &allocated, FALSE)) {
    if (retval == NULL)
      return NULL;
    if (!allocated)
      retval = vim_strsave(retval);
    return retval;
  }

  get_yank_register(regname, FALSE);
  if (y_current->y_array == NULL)
    return NULL;

  /*
   * Compute length of resulting string.
   */
  len = 0;
  for (i = 0; i < y_current->y_size; ++i) {
    len += (long)STRLEN(y_current->y_array[i]);
    /*
     * Insert a newline between lines and after last line if
     * y_type is MLINE.
     */
    if (y_current->y_type == MLINE || i < y_current->y_size - 1)
      ++len;
  }

  retval = lalloc(len + 1, TRUE);

  /*
   * Copy the lines of the yank register into the string.
   */
  if (retval != NULL) {
    len = 0;
    for (i = 0; i < y_current->y_size; ++i) {
      STRCPY(retval + len, y_current->y_array[i]);
      len += (long)STRLEN(retval + len);

      /*
       * Insert a NL between lines and after the last line if y_type is
       * MLINE.
       */
      if (y_current->y_type == MLINE || i < y_current->y_size - 1)
        retval[len++] = '\n';
    }
    retval[len] = NUL;
  }

  return retval;
}

/*
 * Store string "str" in register "name".
 * "maxlen" is the maximum number of bytes to use, -1 for all bytes.
 * If "must_append" is TRUE, always append to the register.  Otherwise append
 * if "name" is an uppercase letter.
 * Note: "maxlen" and "must_append" don't work for the "/" register.
 * Careful: 'str' is modified, you may have to use a copy!
 * If "str" ends in '\n' or '\r', use linewise, otherwise use characterwise.
 */
void write_reg_contents(int name, char_u *str, int maxlen, int must_append)
{
  write_reg_contents_ex(name, str, maxlen, must_append, MAUTO, 0L);
}

void write_reg_contents_ex(int name, char_u *str, int maxlen, int must_append, int yank_type, long block_len)
{
  struct yankreg  *old_y_previous, *old_y_current;
  long len;

  if (maxlen >= 0)
    len = maxlen;
  else
    len = (long)STRLEN(str);

  /* Special case: '/' search pattern */
  if (name == '/') {
    set_last_search_pat(str, RE_SEARCH, TRUE, TRUE);
    return;
  }

  if (name == '=') {
    char_u      *p, *s;

    p = vim_strnsave(str, (int)len);
    if (p == NULL)
      return;
    if (must_append) {
      s = concat_str(get_expr_line_src(), p);
      vim_free(p);
      p = s;

    }
    set_expr_line(p);
    return;
  }

  if (!valid_yank_reg(name, TRUE)) {        /* check for valid reg name */
    emsg_invreg(name);
    return;
  }

  if (name == '_')          /* black hole: nothing to do */
    return;

  /* Don't want to change the current (unnamed) register */
  old_y_previous = y_previous;
  old_y_current = y_current;

  get_yank_register(name, TRUE);
  if (!y_append && !must_append)
    free_yank_all();
  str_to_reg(y_current, yank_type, str, len, block_len);


  /* ':let @" = "val"' should change the meaning of the "" register */
  if (name != '"')
    y_previous = old_y_previous;
  y_current = old_y_current;
}

/*
 * Put a string into a register.  When the register is not empty, the string
 * is appended.
 */
static void 
str_to_reg (
    struct yankreg *y_ptr,             /* pointer to yank register */
    int yank_type,                          /* MCHAR, MLINE, MBLOCK, MAUTO */
    char_u *str,               /* string to put in register */
    long len,                               /* length of string */
    long blocklen                          /* width of Visual block */
)
{
  int type;                             /* MCHAR, MLINE or MBLOCK */
  int lnum;
  long start;
  long i;
  int extra;
  int newlines;                         /* number of lines added */
  int extraline = 0;                    /* extra line at the end */
  int append = FALSE;                   /* append to last line in register */
  char_u      *s;
  char_u      **pp;
  long maxlen;

  if (y_ptr->y_array == NULL)           /* NULL means empty register */
    y_ptr->y_size = 0;

  if (yank_type == MAUTO)
    type = ((len > 0 && (str[len - 1] == NL || str[len - 1] == CAR))
            ? MLINE : MCHAR);
  else
    type = yank_type;

  /*
   * Count the number of lines within the string
   */
  newlines = 0;
  for (i = 0; i < len; i++)
    if (str[i] == '\n')
      ++newlines;
  if (type == MCHAR || len == 0 || str[len - 1] != '\n') {
    extraline = 1;
    ++newlines;         /* count extra newline at the end */
  }
  if (y_ptr->y_size > 0 && y_ptr->y_type == MCHAR) {
    append = TRUE;
    --newlines;         /* uncount newline when appending first line */
  }

  /*
   * Allocate an array to hold the pointers to the new register lines.
   * If the register was not empty, move the existing lines to the new array.
   */
  pp = (char_u **)lalloc_clear((y_ptr->y_size + newlines)
      * sizeof(char_u *), TRUE);
  if (pp == NULL)       /* out of memory */
    return;
  for (lnum = 0; lnum < y_ptr->y_size; ++lnum)
    pp[lnum] = y_ptr->y_array[lnum];
  vim_free(y_ptr->y_array);
  y_ptr->y_array = pp;
  maxlen = 0;

  /*
   * Find the end of each line and save it into the array.
   */
  for (start = 0; start < len + extraline; start += i + 1) {
    for (i = start; i < len; ++i)       /* find the end of the line */
      if (str[i] == '\n')
        break;
    i -= start;                         /* i is now length of line */
    if (i > maxlen)
      maxlen = i;
    if (append) {
      --lnum;
      extra = (int)STRLEN(y_ptr->y_array[lnum]);
    } else
      extra = 0;
    s = alloc((unsigned)(i + extra + 1));
    if (s == NULL)
      break;
    if (extra)
      mch_memmove(s, y_ptr->y_array[lnum], (size_t)extra);
    if (append)
      vim_free(y_ptr->y_array[lnum]);
    if (i)
      mch_memmove(s + extra, str + start, (size_t)i);
    extra += i;
    s[extra] = NUL;
    y_ptr->y_array[lnum++] = s;
    while (--extra >= 0) {
      if (*s == NUL)
        *s = '\n';                  /* replace NUL with newline */
      ++s;
    }
    append = FALSE;                 /* only first line is appended */
  }
  y_ptr->y_type = type;
  y_ptr->y_size = lnum;
  if (type == MBLOCK)
    y_ptr->y_width = (blocklen < 0 ? maxlen - 1 : blocklen);
  else
    y_ptr->y_width = 0;
}

void clear_oparg(oparg_T *oap)
{
  vim_memset(oap, 0, sizeof(oparg_T));
}

static long line_count_info(char_u *line, long *wc, long *cc,
                            long limit,
                            int eol_size);

/*
 *  Count the number of bytes, characters and "words" in a line.
 *
 *  "Words" are counted by looking for boundaries between non-space and
 *  space characters.  (it seems to produce results that match 'wc'.)
 *
 *  Return value is byte count; word count for the line is added to "*wc".
 *  Char count is added to "*cc".
 *
 *  The function will only examine the first "limit" characters in the
 *  line, stopping if it encounters an end-of-line (NUL byte).  In that
 *  case, eol_size will be added to the character count to account for
 *  the size of the EOL character.
 */
static long line_count_info(char_u *line, long *wc, long *cc, long limit, int eol_size)
{
  long i;
  long words = 0;
  long chars = 0;
  int is_word = 0;

  for (i = 0; i < limit && line[i] != NUL; ) {
    if (is_word) {
      if (vim_isspace(line[i])) {
        words++;
        is_word = 0;
      }
    } else if (!vim_isspace(line[i]))
      is_word = 1;
    ++chars;
    i += (*mb_ptr2len)(line + i);
  }

  if (is_word)
    words++;
  *wc += words;

  /* Add eol_size if the end of line was reached before hitting limit. */
  if (i < limit && line[i] == NUL) {
    i += eol_size;
    chars += eol_size;
  }
  *cc += chars;
  return i;
}

/*
 * Give some info about the position of the cursor (for "g CTRL-G").
 * In Visual mode, give some info about the selected region.  (In this case,
 * the *_count_cursor variables store running totals for the selection.)
 */
void cursor_pos_info(void)          {
  char_u      *p;
  char_u buf1[50];
  char_u buf2[40];
  linenr_T lnum;
  long byte_count = 0;
  long byte_count_cursor = 0;
  long char_count = 0;
  long char_count_cursor = 0;
  long word_count = 0;
  long word_count_cursor = 0;
  int eol_size;
  long last_check = 100000L;
  long line_count_selected = 0;
  pos_T min_pos, max_pos;
  oparg_T oparg;
  struct block_def bd;

  /*
   * Compute the length of the file in characters.
   */
  if (curbuf->b_ml.ml_flags & ML_EMPTY) {
    MSG(_(no_lines_msg));
  } else   {
    if (get_fileformat(curbuf) == EOL_DOS)
      eol_size = 2;
    else
      eol_size = 1;

    if (VIsual_active) {
      if (lt(VIsual, curwin->w_cursor)) {
        min_pos = VIsual;
        max_pos = curwin->w_cursor;
      } else   {
        min_pos = curwin->w_cursor;
        max_pos = VIsual;
      }
      if (*p_sel == 'e' && max_pos.col > 0)
        --max_pos.col;

      if (VIsual_mode == Ctrl_V) {
        char_u * saved_sbr = p_sbr;

        /* Make 'sbr' empty for a moment to get the correct size. */
        p_sbr = empty_option;
        oparg.is_VIsual = 1;
        oparg.block_mode = TRUE;
        oparg.op_type = OP_NOP;
        getvcols(curwin, &min_pos, &max_pos,
            &oparg.start_vcol, &oparg.end_vcol);
        p_sbr = saved_sbr;
        if (curwin->w_curswant == MAXCOL)
          oparg.end_vcol = MAXCOL;
        /* Swap the start, end vcol if needed */
        if (oparg.end_vcol < oparg.start_vcol) {
          oparg.end_vcol += oparg.start_vcol;
          oparg.start_vcol = oparg.end_vcol - oparg.start_vcol;
          oparg.end_vcol -= oparg.start_vcol;
        }
      }
      line_count_selected = max_pos.lnum - min_pos.lnum + 1;
    }

    for (lnum = 1; lnum <= curbuf->b_ml.ml_line_count; ++lnum) {
      /* Check for a CTRL-C every 100000 characters. */
      if (byte_count > last_check) {
        ui_breakcheck();
        if (got_int)
          return;
        last_check = byte_count + 100000L;
      }

      /* Do extra processing for VIsual mode. */
      if (VIsual_active
          && lnum >= min_pos.lnum && lnum <= max_pos.lnum) {
        char_u      *s = NULL;
        long len = 0L;

        switch (VIsual_mode) {
        case Ctrl_V:
          virtual_op = virtual_active();
          block_prep(&oparg, &bd, lnum, 0);
          virtual_op = MAYBE;
          s = bd.textstart;
          len = (long)bd.textlen;
          break;
        case 'V':
          s = ml_get(lnum);
          len = MAXCOL;
          break;
        case 'v':
        {
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
              && curbuf->b_p_bin
              && (long)STRLEN(s) < len)
            byte_count_cursor -= eol_size;
        }
      } else   {
        /* In non-visual mode, check for the line the cursor is on */
        if (lnum == curwin->w_cursor.lnum) {
          word_count_cursor += word_count;
          char_count_cursor += char_count;
          byte_count_cursor = byte_count +
                              line_count_info(ml_get(lnum),
              &word_count_cursor, &char_count_cursor,
              (long)(curwin->w_cursor.col + 1), eol_size);
        }
      }
      /* Add to the running totals */
      byte_count += line_count_info(ml_get(lnum), &word_count,
          &char_count, (long)MAXCOL, eol_size);
    }

    /* Correction for when last line doesn't have an EOL. */
    if (!curbuf->b_p_eol && curbuf->b_p_bin)
      byte_count -= eol_size;

    if (VIsual_active) {
      if (VIsual_mode == Ctrl_V && curwin->w_curswant < MAXCOL) {
        getvcols(curwin, &min_pos, &max_pos, &min_pos.col,
            &max_pos.col);
        vim_snprintf((char *)buf1, sizeof(buf1), _("%ld Cols; "),
            (long)(oparg.end_vcol - oparg.start_vcol + 1));
      } else
        buf1[0] = NUL;

      if (char_count_cursor == byte_count_cursor
          && char_count == byte_count)
        vim_snprintf((char *)IObuff, IOSIZE,
            _("Selected %s%ld of %ld Lines; %ld of %ld Words; %ld of %ld Bytes"),
            buf1, line_count_selected,
            (long)curbuf->b_ml.ml_line_count,
            word_count_cursor, word_count,
            byte_count_cursor, byte_count);
      else
        vim_snprintf((char *)IObuff, IOSIZE,
            _(
                "Selected %s%ld of %ld Lines; %ld of %ld Words; %ld of %ld Chars; %ld of %ld Bytes"),
            buf1, line_count_selected,
            (long)curbuf->b_ml.ml_line_count,
            word_count_cursor, word_count,
            char_count_cursor, char_count,
            byte_count_cursor, byte_count);
    } else   {
      p = ml_get_curline();
      validate_virtcol();
      col_print(buf1, sizeof(buf1), (int)curwin->w_cursor.col + 1,
          (int)curwin->w_virtcol + 1);
      col_print(buf2, sizeof(buf2), (int)STRLEN(p), linetabsize(p));

      if (char_count_cursor == byte_count_cursor
          && char_count == byte_count)
        vim_snprintf((char *)IObuff, IOSIZE,
            _("Col %s of %s; Line %ld of %ld; Word %ld of %ld; Byte %ld of %ld"),
            (char *)buf1, (char *)buf2,
            (long)curwin->w_cursor.lnum,
            (long)curbuf->b_ml.ml_line_count,
            word_count_cursor, word_count,
            byte_count_cursor, byte_count);
      else
        vim_snprintf((char *)IObuff, IOSIZE,
            _(
                "Col %s of %s; Line %ld of %ld; Word %ld of %ld; Char %ld of %ld; Byte %ld of %ld"),
            (char *)buf1, (char *)buf2,
            (long)curwin->w_cursor.lnum,
            (long)curbuf->b_ml.ml_line_count,
            word_count_cursor, word_count,
            char_count_cursor, char_count,
            byte_count_cursor, byte_count);
    }

    byte_count = bomb_size();
    if (byte_count > 0)
      sprintf((char *)IObuff + STRLEN(IObuff), _("(+%ld for BOM)"),
          byte_count);
    /* Don't shorten this message, the user asked for it. */
    p = p_shm;
    p_shm = (char_u *)"";
    msg(IObuff);
    p_shm = p;
  }
}

