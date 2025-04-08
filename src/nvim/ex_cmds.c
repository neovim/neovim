// ex_cmds.c: some functions for command line commands

#include <assert.h>
#include <ctype.h>
#include <float.h>
#include <inttypes.h>
#include <limits.h>
#include <math.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "auto/config.h"
#include "klib/kvec.h"
#include "nvim/api/private/helpers.h"
#include "nvim/arglist.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/buffer_updates.h"
#include "nvim/bufwrite.h"
#include "nvim/change.h"
#include "nvim/channel.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cmdhist.h"
#include "nvim/cursor.h"
#include "nvim/decoration.h"
#include "nvim/diff.h"
#include "nvim/digraph.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_getln.h"
#include "nvim/extmark.h"
#include "nvim/extmark_defs.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/help.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/indent.h"
#include "nvim/input.h"
#include "nvim/macros_defs.h"
#include "nvim/main.h"
#include "nvim/mark.h"
#include "nvim/mark_defs.h"
#include "nvim/mbyte.h"
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
#include "nvim/os/fs.h"
#include "nvim/os/fs_defs.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/shell.h"
#include "nvim/os/time.h"
#include "nvim/path.h"
#include "nvim/plines.h"
#include "nvim/pos_defs.h"
#include "nvim/profile.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/search.h"
#include "nvim/spell.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/terminal.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/undo.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

/// Case matching style to use for :substitute
typedef enum {
  kSubHonorOptions = 0,  ///< Honor the user's 'ignorecase'/'smartcase' options
  kSubIgnoreCase,        ///< Ignore case of the search
  kSubMatchCase,         ///< Match case of the search
} SubIgnoreType;

/// Flags kept between calls to :substitute.
typedef struct {
  bool do_all;          ///< do multiple substitutions per line
  bool do_ask;          ///< ask for confirmation
  bool do_count;        ///< count only
  bool do_error;        ///< if false, ignore errors
  bool do_print;        ///< print last line with subs
  bool do_list;         ///< list last line with subs
  bool do_number;       ///< list last line with line nr
  SubIgnoreType do_ic;  ///< ignore case flag
} subflags_T;

/// Partial result of a substitution during :substitute.
/// Numbers refer to the buffer _after_ substitution
typedef struct {
  lpos_T start;  // start of the match
  lpos_T end;    // end of the match
  linenr_T pre_match;  // where to begin showing lines before the match
} SubResult;

// Collected results of a substitution for showing them in
// the preview window
typedef struct {
  kvec_t(SubResult) subresults;
  linenr_T lines_needed;  // lines needed in the preview window
} PreviewLines;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_cmds.c.generated.h"
#endif

static const char e_non_numeric_argument_to_z[]
  = N_("E144: Non-numeric argument to :z");

/// ":ascii" and "ga" implementation
void do_ascii(exarg_T *eap)
{
  char *data = get_cursor_pos_ptr();
  size_t len = (size_t)utfc_ptr2len(data);

  if (len == 0) {
    msg("NUL", 0);
    return;
  }

  bool need_clear = true;
  msg_sb_eol();
  msg_start();

  int c = utf_ptr2char(data);
  size_t off = 0;

  // TODO(bfredl): merge this with the main loop
  if (c < 0x80) {
    if (c == NL) {  // NUL is stored as NL.
      c = NUL;
    }
    const int cval = (c == CAR && get_fileformat(curbuf) == EOL_MAC
                      ? NL  // NL is stored as CR.
                      : c);
    char buf1[20];
    if (vim_isprintc(c) && (c < ' ' || c > '~')) {
      char buf3[7];
      transchar_nonprint(curbuf, buf3, c);
      vim_snprintf(buf1, sizeof(buf1), "  <%s>", buf3);
    } else {
      buf1[0] = NUL;
    }
    char buf2[20];
    buf2[0] = NUL;

    char *dig = get_digraph_for_char(cval);
    if (dig != NULL) {
      vim_snprintf(IObuff, sizeof(IObuff),
                   _("<%s>%s%s  %d,  Hex %02x,  Oct %03o, Digr %s"),
                   transchar(c), buf1, buf2, cval, cval, cval, dig);
    } else {
      vim_snprintf(IObuff, sizeof(IObuff),
                   _("<%s>%s%s  %d,  Hex %02x,  Octal %03o"),
                   transchar(c), buf1, buf2, cval, cval, cval);
    }

    msg_multiline(cstr_as_string(IObuff), 0, true, false, &need_clear);

    off += (size_t)utf_ptr2len(data);  // needed for overlong ascii?
  }

  // Repeat for combining characters, also handle multiby here.
  while (off < len) {
    c = utf_ptr2char(data + off);

    size_t iobuff_len = 0;
    // This assumes every multi-byte char is printable...
    if (off > 0) {
      IObuff[iobuff_len++] = ' ';
    }
    IObuff[iobuff_len++] = '<';
    if (utf_iscomposing_first(c)) {
      IObuff[iobuff_len++] = ' ';  // Draw composing char on top of a space.
    }
    iobuff_len += (size_t)utf_char2bytes(c, IObuff + iobuff_len);

    char *dig = get_digraph_for_char(c);
    if (dig != NULL) {
      vim_snprintf(IObuff + iobuff_len, sizeof(IObuff) - iobuff_len,
                   (c < 0x10000
                    ? _("> %d, Hex %04x, Oct %o, Digr %s")
                    : _("> %d, Hex %08x, Oct %o, Digr %s")),
                   c, c, c, dig);
    } else {
      vim_snprintf(IObuff + iobuff_len, sizeof(IObuff) - iobuff_len,
                   (c < 0x10000
                    ? _("> %d, Hex %04x, Octal %o")
                    : _("> %d, Hex %08x, Octal %o")),
                   c, c, c);
    }

    msg_multiline(cstr_as_string(IObuff), 0, true, false, &need_clear);

    off += (size_t)utf_ptr2len(data + off);  // needed for overlong ascii?
  }

  if (need_clear) {
    msg_clr_eos();
  }
  msg_end();
}

/// ":left", ":center" and ":right": align text.
void ex_align(exarg_T *eap)
{
  int indent = 0;
  int new_indent;

  if (curwin->w_p_rl) {
    // switch left and right aligning
    if (eap->cmdidx == CMD_right) {
      eap->cmdidx = CMD_left;
    } else if (eap->cmdidx == CMD_left) {
      eap->cmdidx = CMD_right;
    }
  }

  int width = atoi(eap->arg);
  pos_T save_curpos = curwin->w_cursor;
  if (eap->cmdidx == CMD_left) {    // width is used for new indent
    if (width >= 0) {
      indent = width;
    }
  } else {
    // if 'textwidth' set, use it
    // else if 'wrapmargin' set, use it
    // if invalid value, use 80
    if (width <= 0) {
      width = (int)curbuf->b_p_tw;
    }
    if (width == 0 && curbuf->b_p_wm > 0) {
      width = curwin->w_width_inner - (int)curbuf->b_p_wm;
    }
    if (width <= 0) {
      width = 80;
    }
  }

  if (u_save((linenr_T)(eap->line1 - 1), (linenr_T)(eap->line2 + 1)) == FAIL) {
    return;
  }

  for (curwin->w_cursor.lnum = eap->line1;
       curwin->w_cursor.lnum <= eap->line2; curwin->w_cursor.lnum++) {
    if (eap->cmdidx == CMD_left) {              // left align
      new_indent = indent;
    } else {
      int has_tab = false;          // avoid uninit warnings
      int len = linelen(eap->cmdidx == CMD_right ? &has_tab : NULL) - get_indent();

      if (len <= 0) {                           // skip blank lines
        continue;
      }

      if (eap->cmdidx == CMD_center) {
        new_indent = (width - len) / 2;
      } else {
        new_indent = width - len;               // right align

        // Make sure that embedded TABs don't make the text go too far
        // to the right.
        if (has_tab) {
          while (new_indent > 0) {
            set_indent(new_indent, 0);
            if (linelen(NULL) <= width) {
              // Now try to move the line as much as possible to
              // the right.  Stop when it moves too far.
              do {
                set_indent(++new_indent, 0);
              } while (linelen(NULL) <= width);
              new_indent--;
              break;
            }
            new_indent--;
          }
        }
      }
    }
    new_indent = MAX(new_indent, 0);
    set_indent(new_indent, 0);                    // set indent
  }
  changed_lines(curbuf, eap->line1, 0, eap->line2 + 1, 0, true);
  curwin->w_cursor = save_curpos;
  beginline(BL_WHITE | BL_FIX);
}

/// @return  the length of the current line, excluding trailing white space.
static int linelen(int *has_tab)
{
  char *last;

  // Get the line.  If it's empty bail out early (could be the empty string
  // for an unloaded buffer).
  char *line = get_cursor_line_ptr();
  if (*line == NUL) {
    return 0;
  }
  // find the first non-blank character
  char *first = skipwhite(line);

  // find the character after the last non-blank character
  for (last = first + strlen(first);
       last > first && ascii_iswhite(last[-1]); last--) {}
  char save = *last;
  *last = NUL;
  int len = linetabsize_str(line);  // Get line length.
  if (has_tab != NULL) {        // Check for embedded TAB.
    *has_tab = vim_strchr(first, TAB) != NULL;
  }
  *last = save;

  return len;
}

// Buffer for two lines used during sorting.  They are allocated to
// contain the longest line being sorted.
static char *sortbuf1;
static char *sortbuf2;

static bool sort_lc;      ///< sort using locale
static bool sort_ic;      ///< ignore case
static bool sort_nr;      ///< sort on number
static bool sort_rx;      ///< sort on regex instead of skipping it
static bool sort_flt;     ///< sort on floating number

static bool sort_abort;   ///< flag to indicate if sorting has been interrupted

/// Struct to store info to be sorted.
typedef struct {
  linenr_T lnum;          ///< line number
  union {
    struct {
      varnumber_T start_col_nr;  ///< starting column number
      varnumber_T end_col_nr;    ///< ending column number
    } line;
    struct {
      varnumber_T value;         ///< value if sorting by integer
      bool is_number;            ///< true when line contains a number
    } num;
    float_T value_flt;    ///< value if sorting by float
  } st_u;
} sorti_T;

static int string_compare(const void *s1, const void *s2) FUNC_ATTR_NONNULL_ALL
{
  if (sort_lc) {
    return strcoll((const char *)s1, (const char *)s2);
  }
  return sort_ic ? STRICMP(s1, s2) : strcmp(s1, s2);
}

static int sort_compare(const void *s1, const void *s2)
{
  sorti_T l1 = *(sorti_T *)s1;
  sorti_T l2 = *(sorti_T *)s2;
  int result = 0;

  // If the user interrupts, there's no way to stop qsort() immediately, but
  // if we return 0 every time, qsort will assume it's done sorting and
  // exit.
  if (sort_abort) {
    return 0;
  }
  fast_breakcheck();
  if (got_int) {
    sort_abort = true;
  }

  // When sorting numbers "start_col_nr" is the number, not the column
  // number.
  if (sort_nr) {
    if (l1.st_u.num.is_number != l2.st_u.num.is_number) {
      result = l1.st_u.num.is_number > l2.st_u.num.is_number ? 1 : -1;
    } else {
      result = l1.st_u.num.value == l2.st_u.num.value
               ? 0
               : l1.st_u.num.value > l2.st_u.num.value ? 1 : -1;
    }
  } else if (sort_flt) {
    result = l1.st_u.value_flt == l2.st_u.value_flt
             ? 0
             : l1.st_u.value_flt > l2.st_u.value_flt ? 1 : -1;
  } else {
    // We need to copy one line into "sortbuf1", because there is no
    // guarantee that the first pointer becomes invalid when obtaining the
    // second one.
    memcpy(sortbuf1, ml_get(l1.lnum) + l1.st_u.line.start_col_nr,
           (size_t)(l1.st_u.line.end_col_nr - l1.st_u.line.start_col_nr + 1));
    sortbuf1[l1.st_u.line.end_col_nr - l1.st_u.line.start_col_nr] = NUL;
    memcpy(sortbuf2, ml_get(l2.lnum) + l2.st_u.line.start_col_nr,
           (size_t)(l2.st_u.line.end_col_nr - l2.st_u.line.start_col_nr + 1));
    sortbuf2[l2.st_u.line.end_col_nr - l2.st_u.line.start_col_nr] = NUL;

    result = string_compare(sortbuf1, sortbuf2);
  }

  // If two lines have the same value, preserve the original line order.
  if (result == 0) {
    return l1.lnum - l2.lnum;
  }
  return result;
}

/// ":sort".
void ex_sort(exarg_T *eap)
{
  regmatch_T regmatch;
  int maxlen = 0;
  size_t count = (size_t)(eap->line2 - eap->line1) + 1;
  size_t i;
  bool unique = false;
  int sort_what = 0;

  // Sorting one line is really quick!
  if (count <= 1) {
    return;
  }

  if (u_save((linenr_T)(eap->line1 - 1), (linenr_T)(eap->line2 + 1)) == FAIL) {
    return;
  }
  sortbuf1 = NULL;
  sortbuf2 = NULL;
  regmatch.regprog = NULL;
  sorti_T *nrs = xmalloc(count * sizeof(sorti_T));

  sort_abort = sort_ic = sort_lc = sort_rx = sort_nr = sort_flt = false;
  size_t format_found = 0;
  bool change_occurred = false;   // Buffer contents changed.

  for (char *p = eap->arg; *p != NUL; p++) {
    if (ascii_iswhite(*p)) {
      // Skip
    } else if (*p == 'i') {
      sort_ic = true;
    } else if (*p == 'l') {
      sort_lc = true;
    } else if (*p == 'r') {
      sort_rx = true;
    } else if (*p == 'n') {
      sort_nr = true;
      format_found++;
    } else if (*p == 'f') {
      sort_flt = true;
      format_found++;
    } else if (*p == 'b') {
      sort_what = STR2NR_BIN + STR2NR_FORCE;
      format_found++;
    } else if (*p == 'o') {
      sort_what = STR2NR_OCT + STR2NR_FORCE;
      format_found++;
    } else if (*p == 'x') {
      sort_what = STR2NR_HEX + STR2NR_FORCE;
      format_found++;
    } else if (*p == 'u') {
      unique = true;
    } else if (*p == '"') {
      // comment start
      break;
    } else if (check_nextcmd(p) != NULL) {
      eap->nextcmd = check_nextcmd(p);
      break;
    } else if (!ASCII_ISALPHA(*p) && regmatch.regprog == NULL) {
      char *s = skip_regexp_err(p + 1, *p, true);
      if (s == NULL) {
        goto sortend;
      }
      *s = NUL;
      // Use last search pattern if sort pattern is empty.
      if (s == p + 1) {
        if (last_search_pat() == NULL) {
          emsg(_(e_noprevre));
          goto sortend;
        }
        regmatch.regprog = vim_regcomp(last_search_pat(), RE_MAGIC);
      } else {
        regmatch.regprog = vim_regcomp(p + 1, RE_MAGIC);
      }
      if (regmatch.regprog == NULL) {
        goto sortend;
      }
      p = s;                    // continue after the regexp
      regmatch.rm_ic = p_ic;
    } else {
      semsg(_(e_invarg2), p);
      goto sortend;
    }
  }

  // Can only have one of 'n', 'b', 'o' and 'x'.
  if (format_found > 1) {
    emsg(_(e_invarg));
    goto sortend;
  }

  // From here on "sort_nr" is used as a flag for any integer number
  // sorting.
  sort_nr |= sort_what;

  // Make an array with all line numbers.  This avoids having to copy all
  // the lines into allocated memory.
  // When sorting on strings "start_col_nr" is the offset in the line, for
  // numbers sorting it's the number to sort on.  This means the pattern
  // matching and number conversion only has to be done once per line.
  // Also get the longest line length for allocating "sortbuf".
  for (linenr_T lnum = eap->line1; lnum <= eap->line2; lnum++) {
    char *s = ml_get(lnum);
    int len = ml_get_len(lnum);
    maxlen = MAX(maxlen, len);

    colnr_T start_col = 0;
    colnr_T end_col = len;
    if (regmatch.regprog != NULL && vim_regexec(&regmatch, s, 0)) {
      if (sort_rx) {
        start_col = (colnr_T)(regmatch.startp[0] - s);
        end_col = (colnr_T)(regmatch.endp[0] - s);
      } else {
        start_col = (colnr_T)(regmatch.endp[0] - s);
      }
    } else if (regmatch.regprog != NULL) {
      end_col = 0;
    }

    if (sort_nr || sort_flt) {
      // Make sure vim_str2nr() doesn't read any digits past the end
      // of the match, by temporarily terminating the string there
      char *s2 = s + end_col;
      char c = *s2;  // temporary character storage
      *s2 = NUL;
      // Sorting on number: Store the number itself.
      char *p = s + start_col;
      if (sort_nr) {
        if (sort_what & STR2NR_HEX) {
          s = skiptohex(p);
        } else if (sort_what & STR2NR_BIN) {
          s = (char *)skiptobin(p);
        } else {
          s = skiptodigit(p);
        }
        if (s > p && s[-1] == '-') {
          s--;  // include preceding negative sign
        }
        if (*s == NUL) {
          // line without number should sort before any number
          nrs[lnum - eap->line1].st_u.num.is_number = false;
          nrs[lnum - eap->line1].st_u.num.value = 0;
        } else {
          nrs[lnum - eap->line1].st_u.num.is_number = true;
          vim_str2nr(s, NULL, NULL, sort_what,
                     &nrs[lnum - eap->line1].st_u.num.value, NULL, 0, false, NULL);
        }
      } else {
        s = skipwhite(p);
        if (*s == '+') {
          s = skipwhite(s + 1);
        }

        if (*s == NUL) {
          // empty line should sort before any number
          nrs[lnum - eap->line1].st_u.value_flt = -DBL_MAX;
        } else {
          nrs[lnum - eap->line1].st_u.value_flt = strtod(s, NULL);
        }
      }
      *s2 = c;
    } else {
      // Store the column to sort at.
      nrs[lnum - eap->line1].st_u.line.start_col_nr = start_col;
      nrs[lnum - eap->line1].st_u.line.end_col_nr = end_col;
    }

    nrs[lnum - eap->line1].lnum = lnum;

    if (regmatch.regprog != NULL) {
      fast_breakcheck();
    }
    if (got_int) {
      goto sortend;
    }
  }

  // Allocate a buffer that can hold the longest line.
  sortbuf1 = xmalloc((size_t)maxlen + 1);
  sortbuf2 = xmalloc((size_t)maxlen + 1);

  // Sort the array of line numbers.  Note: can't be interrupted!
  qsort((void *)nrs, count, sizeof(sorti_T), sort_compare);

  if (sort_abort) {
    goto sortend;
  }

  bcount_t old_count = 0;
  bcount_t new_count = 0;

  // Insert the lines in the sorted order below the last one.
  linenr_T lnum = eap->line2;
  for (i = 0; i < count; i++) {
    const linenr_T get_lnum = nrs[eap->forceit ? count - i - 1 : i].lnum;

    // If the original line number of the line being placed is not the same
    // as "lnum" (accounting for offset), we know that the buffer changed.
    if (get_lnum + ((linenr_T)count - 1) != lnum) {
      change_occurred = true;
    }

    char *s = ml_get(get_lnum);
    colnr_T bytelen = ml_get_len(get_lnum) + 1;  // include EOL in bytelen
    old_count += bytelen;
    if (!unique || i == 0 || string_compare(s, sortbuf1) != 0) {
      // Copy the line into a buffer, it may become invalid in
      // ml_append(). And it's needed for "unique".
      STRCPY(sortbuf1, s);
      if (ml_append(lnum++, sortbuf1, 0, false) == FAIL) {
        break;
      }
      new_count += bytelen;
    }
    fast_breakcheck();
    if (got_int) {
      goto sortend;
    }
  }

  // delete the original lines if appending worked
  if (i == count) {
    for (i = 0; i < count; i++) {
      ml_delete(eap->line1, false);
    }
  } else {
    count = 0;
  }

  // Adjust marks for deleted (or added) lines and prepare for displaying.
  linenr_T deleted = (linenr_T)count - (lnum - eap->line2);
  if (deleted > 0) {
    mark_adjust(eap->line2 - deleted, eap->line2, MAXLNUM, -deleted, kExtmarkNOOP);
    msgmore(-deleted);
  } else if (deleted < 0) {
    mark_adjust(eap->line2, MAXLNUM, -deleted, 0, kExtmarkNOOP);
  }

  if (change_occurred || deleted != 0) {
    extmark_splice(curbuf, eap->line1 - 1, 0,
                   (int)count, 0, old_count,
                   lnum - eap->line2, 0, new_count, kExtmarkUndo);

    changed_lines(curbuf, eap->line1, 0, eap->line2 + 1, -deleted, true);
  }

  curwin->w_cursor.lnum = eap->line1;
  beginline(BL_WHITE | BL_FIX);

sortend:
  xfree(nrs);
  xfree(sortbuf1);
  xfree(sortbuf2);
  vim_regfree(regmatch.regprog);
  if (got_int) {
    emsg(_(e_interr));
  }
}

/// :move command - move lines line1-line2 to line dest
///
/// @return  FAIL for failure, OK otherwise
int do_move(linenr_T line1, linenr_T line2, linenr_T dest)
{
  if (dest >= line1 && dest < line2) {
    emsg(_("E134: Cannot move a range of lines into itself"));
    return FAIL;
  }

  // Do nothing if we are not actually moving any lines.  This will prevent
  // the 'modified' flag from being set without cause.
  if (dest == line1 - 1 || dest == line2) {
    // Move the cursor as if lines were moved (see below) to be backwards
    // compatible.
    curwin->w_cursor.lnum = dest >= line1
                            ? dest
                            : dest + (line2 - line1) + 1;
    return OK;
  }

  bcount_t start_byte = ml_find_line_or_offset(curbuf, line1, NULL, true);
  bcount_t end_byte = ml_find_line_or_offset(curbuf, line2 + 1, NULL, true);
  bcount_t extent_byte = end_byte - start_byte;
  bcount_t dest_byte = ml_find_line_or_offset(curbuf, dest + 1, NULL, true);

  linenr_T num_lines = line2 - line1 + 1;  // Num lines moved

  // First we copy the old text to its new location -- webb
  // Also copy the flag that ":global" command uses.
  if (u_save(dest, dest + 1) == FAIL) {
    return FAIL;
  }

  linenr_T l;
  linenr_T extra;      // Num lines added before line1
  for (extra = 0, l = line1; l <= line2; l++) {
    char *str = xstrnsave(ml_get(l + extra), (size_t)ml_get_len(l + extra));
    ml_append(dest + l - line1, str, 0, false);
    xfree(str);
    if (dest < line1) {
      extra++;
    }
  }

  // Now we must be careful adjusting our marks so that we don't overlap our
  // mark_adjust() calls.
  //
  // We adjust the marks within the old text so that they refer to the
  // last lines of the file (temporarily), because we know no other marks
  // will be set there since these line numbers did not exist until we added
  // our new lines.
  //
  // Then we adjust the marks on lines between the old and new text positions
  // (either forwards or backwards).
  //
  // And Finally we adjust the marks we put at the end of the file back to
  // their final destination at the new text position -- webb
  linenr_T last_line = curbuf->b_ml.ml_line_count;  // Last line in file after adding new text
  mark_adjust_nofold(line1, line2, last_line - line2, 0, kExtmarkNOOP);

  disable_fold_update++;
  changed_lines(curbuf, last_line - num_lines + 1, 0, last_line + 1, num_lines, false);
  disable_fold_update--;

  int line_off = 0;
  bcount_t byte_off = 0;
  if (dest >= line2) {
    mark_adjust_nofold(line2 + 1, dest, -num_lines, 0, kExtmarkNOOP);
    FOR_ALL_TAB_WINDOWS(tab, win) {
      if (win->w_buffer == curbuf) {
        foldMoveRange(win, &win->w_folds, line1, line2, dest);
      }
    }
    if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
      curbuf->b_op_start.lnum = dest - num_lines + 1;
      curbuf->b_op_end.lnum = dest;
    }
    line_off = -num_lines;
    byte_off = -extent_byte;
  } else {
    mark_adjust_nofold(dest + 1, line1 - 1, num_lines, 0, kExtmarkNOOP);
    FOR_ALL_TAB_WINDOWS(tab, win) {
      if (win->w_buffer == curbuf) {
        foldMoveRange(win, &win->w_folds, dest + 1, line1 - 1, line2);
      }
    }
    if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
      curbuf->b_op_start.lnum = dest + 1;
      curbuf->b_op_end.lnum = dest + num_lines;
    }
  }
  if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
    curbuf->b_op_start.col = curbuf->b_op_end.col = 0;
  }
  mark_adjust_nofold(last_line - num_lines + 1, last_line,
                     -(last_line - dest - extra), 0, kExtmarkNOOP);

  disable_fold_update++;
  changed_lines(curbuf, last_line - num_lines + 1, 0, last_line + 1, -extra, false);
  disable_fold_update--;

  // send update regarding the new lines that were added
  buf_updates_send_changes(curbuf, dest + 1, num_lines, 0);

  // Now we delete the original text -- webb
  if (u_save(line1 + extra - 1, line2 + extra + 1) == FAIL) {
    return FAIL;
  }

  for (l = line1; l <= line2; l++) {
    ml_delete(line1 + extra, true);
  }
  if (!global_busy && num_lines > p_report) {
    smsg(0, NGETTEXT("%" PRId64 " line moved",
                     "%" PRId64 " lines moved", num_lines),
         (int64_t)num_lines);
  }

  extmark_move_region(curbuf, line1 - 1, 0, start_byte,
                      line2 - line1 + 1, 0, extent_byte,
                      dest + line_off, 0, dest_byte + byte_off,
                      kExtmarkUndo);

  // Leave the cursor on the last of the moved lines.
  if (dest >= line1) {
    curwin->w_cursor.lnum = dest;
  } else {
    curwin->w_cursor.lnum = dest + (line2 - line1) + 1;
  }

  if (line1 < dest) {
    dest += num_lines + 1;
    last_line = curbuf->b_ml.ml_line_count;
    dest = MIN(dest, last_line + 1);
    changed_lines(curbuf, line1, 0, dest, 0, false);
  } else {
    changed_lines(curbuf, dest + 1, 0, line1 + num_lines, 0, false);
  }

  // send nvim_buf_lines_event regarding lines that were deleted
  buf_updates_send_changes(curbuf, line1 + extra, 0, num_lines);

  return OK;
}

/// ":copy"
void ex_copy(linenr_T line1, linenr_T line2, linenr_T n)
{
  linenr_T count = line2 - line1 + 1;
  if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
    curbuf->b_op_start.lnum = n + 1;
    curbuf->b_op_end.lnum = n + count;
    curbuf->b_op_start.col = curbuf->b_op_end.col = 0;
  }

  // there are three situations:
  // 1. destination is above line1
  // 2. destination is between line1 and line2
  // 3. destination is below line2
  //
  // n = destination (when starting)
  // curwin->w_cursor.lnum = destination (while copying)
  // line1 = start of source (while copying)
  // line2 = end of source (while copying)
  if (u_save(n, n + 1) == FAIL) {
    return;
  }

  curwin->w_cursor.lnum = n;
  while (line1 <= line2) {
    // need to make a copy because the line will be unlocked within ml_append()
    char *p = xstrnsave(ml_get(line1), (size_t)ml_get_len(line1));
    ml_append(curwin->w_cursor.lnum, p, 0, false);
    xfree(p);

    // situation 2: skip already copied lines
    if (line1 == n) {
      line1 = curwin->w_cursor.lnum;
    }
    line1++;
    if (curwin->w_cursor.lnum < line1) {
      line1++;
    }
    if (curwin->w_cursor.lnum < line2) {
      line2++;
    }
    curwin->w_cursor.lnum++;
  }

  appended_lines_mark(n, count);
  if (VIsual_active) {
    check_pos(curbuf, &VIsual);
  }

  msgmore(count);
}

static char *prevcmd = NULL;        // the previous command

#if defined(EXITFREE)
void free_prev_shellcmd(void)
{
  xfree(prevcmd);
}

#endif

/// Check that "prevcmd" is not NULL.  If it is NULL then give an error message
/// and return false.
static int prevcmd_is_set(void)
{
  if (prevcmd == NULL) {
    emsg(_(e_noprev));
    return false;
  }
  return true;
}

/// Handle the ":!cmd" command.  Also for ":r !cmd" and ":w !cmd"
/// Bangs in the argument are replaced with the previously entered command.
/// Remember the argument.
void do_bang(int addr_count, exarg_T *eap, bool forceit, bool do_in, bool do_out)
  FUNC_ATTR_NONNULL_ALL
{
  char *arg = eap->arg;             // command
  linenr_T line1 = eap->line1;        // start of range
  linenr_T line2 = eap->line2;        // end of range
  char *newcmd = NULL;              // the new command
  bool free_newcmd = false;           // need to free() newcmd
  int scroll_save = msg_scroll;

  // Disallow shell commands in secure mode
  if (check_secure()) {
    return;
  }

  if (addr_count == 0) {                // :!
    msg_scroll = false;             // don't scroll here
    autowrite_all();
    msg_scroll = scroll_save;
  }

  // Try to find an embedded bang, like in ":!<cmd> ! [args]"
  // ":!!" is indicated by the 'forceit' variable.
  bool ins_prevcmd = forceit;

  // Skip leading white space to avoid a strange error with some shells.
  char *trailarg = skipwhite(arg);
  do {
    size_t len = strlen(trailarg) + 1;
    if (newcmd != NULL) {
      len += strlen(newcmd);
    }
    if (ins_prevcmd) {
      if (!prevcmd_is_set()) {
        xfree(newcmd);
        return;
      }
      len += strlen(prevcmd);
    }
    char *t = xmalloc(len);
    *t = NUL;
    if (newcmd != NULL) {
      strcat(t, newcmd);
    }
    if (ins_prevcmd) {
      strcat(t, prevcmd);
    }
    char *p = t + strlen(t);
    strcat(t, trailarg);
    xfree(newcmd);
    newcmd = t;

    // Scan the rest of the argument for '!', which is replaced by the
    // previous command.  "\!" is replaced by "!" (this is vi compatible).
    trailarg = NULL;
    while (*p) {
      if (*p == '!') {
        if (p > newcmd && p[-1] == '\\') {
          STRMOVE(p - 1, p);
        } else {
          trailarg = p;
          *trailarg++ = NUL;
          ins_prevcmd = true;
          break;
        }
      }
      p++;
    }
  } while (trailarg != NULL);

  // Only set "prevcmd" if there is a command to run, otherwise keep te one
  // we have.
  if (strlen(newcmd) > 0) {
    xfree(prevcmd);
    prevcmd = newcmd;
  } else {
    free_newcmd = true;
  }

  if (bangredo) {  // put cmd in redo buffer for ! command
    if (!prevcmd_is_set()) {
      goto theend;
    }

    // If % or # appears in the command, it must have been escaped.
    // Reescape them, so that redoing them does not substitute them by the
    // buffername.
    char *cmd = vim_strsave_escaped(prevcmd, "%#");

    AppendToRedobuffLit(cmd, -1);
    xfree(cmd);
    AppendToRedobuff("\n");
    bangredo = false;
  }
  // Add quotes around the command, for shells that need them.
  if (*p_shq != NUL) {
    if (free_newcmd) {
      xfree(newcmd);
    }
    newcmd = xmalloc(strlen(prevcmd) + 2 * strlen(p_shq) + 1);
    STRCPY(newcmd, p_shq);
    strcat(newcmd, prevcmd);
    strcat(newcmd, p_shq);
    free_newcmd = true;
  }
  if (addr_count == 0) {                // :!
    // echo the command
    msg_start();
    msg_putchar(':');
    msg_putchar('!');
    msg_outtrans(newcmd, 0, false);
    msg_clr_eos();
    ui_cursor_goto(msg_row, msg_col);

    do_shell(newcmd, 0);
  } else {                            // :range!
    // Careful: This may recursively call do_bang() again! (because of
    // autocommands)
    do_filter(line1, line2, eap, newcmd, do_in, do_out);
    apply_autocmds(EVENT_SHELLFILTERPOST, NULL, NULL, false, curbuf);
  }

theend:
  if (free_newcmd) {
    xfree(newcmd);
  }
}

/// do_filter: filter lines through a command given by the user
///
/// We mostly use temp files and the call_shell() routine here. This would
/// normally be done using pipes on a Unix system, but this is more portable
/// to non-Unix systems. The call_shell() routine needs to be able
/// to deal with redirection somehow, and should handle things like looking
/// at the PATH env. variable, and adding reasonable extensions to the
/// command name given by the user. All reasonable versions of call_shell()
/// do this.
/// Alternatively, if on Unix and redirecting input or output, but not both,
/// and the 'shelltemp' option isn't set, use pipes.
/// We use input redirection if do_in is true.
/// We use output redirection if do_out is true.
///
/// @param eap  for forced 'ff' and 'fenc'
static void do_filter(linenr_T line1, linenr_T line2, exarg_T *eap, char *cmd, bool do_in,
                      bool do_out)
{
  char *itmp = NULL;
  char *otmp = NULL;
  buf_T *old_curbuf = curbuf;
  int shell_flags = 0;
  const pos_T orig_start = curbuf->b_op_start;
  const pos_T orig_end = curbuf->b_op_end;
  const int stmp = p_stmp;

  if (*cmd == NUL) {        // no filter command
    return;
  }

  const int save_cmod_flags = cmdmod.cmod_flags;
  // Temporarily disable lockmarks since that's needed to propagate changed
  // regions of the buffer for foldUpdate(), linecount, etc.
  cmdmod.cmod_flags &= ~CMOD_LOCKMARKS;

  pos_T cursor_save = curwin->w_cursor;
  linenr_T linecount = line2 - line1 + 1;
  curwin->w_cursor.lnum = line1;
  curwin->w_cursor.col = 0;
  changed_line_abv_curs();
  invalidate_botline(curwin);

  // When using temp files:
  // 1. * Form temp file names
  // 2. * Write the lines to a temp file
  // 3.   Run the filter command on the temp file
  // 4. * Read the output of the command into the buffer
  // 5. * Delete the original lines to be filtered
  // 6. * Remove the temp files
  //
  // When writing the input with a pipe or when catching the output with a
  // pipe only need to do 3.

  if (do_out) {
    shell_flags |= kShellOptDoOut;
  }

  if (!do_in && do_out && !stmp) {
    // Use a pipe to fetch stdout of the command, do not use a temp file.
    shell_flags |= kShellOptRead;
    curwin->w_cursor.lnum = line2;
  } else if (do_in && !do_out && !stmp) {
    // Use a pipe to write stdin of the command, do not use a temp file.
    shell_flags |= kShellOptWrite;
    curbuf->b_op_start.lnum = line1;
    curbuf->b_op_end.lnum = line2;
  } else if (do_in && do_out && !stmp) {
    // Use a pipe to write stdin and fetch stdout of the command, do not
    // use a temp file.
    shell_flags |= kShellOptRead | kShellOptWrite;
    curbuf->b_op_start.lnum = line1;
    curbuf->b_op_end.lnum = line2;
    curwin->w_cursor.lnum = line2;
  } else if ((do_in && (itmp = vim_tempname()) == NULL)
             || (do_out && (otmp = vim_tempname()) == NULL)) {
    emsg(_(e_notmp));
    goto filterend;
  }

  // The writing and reading of temp files will not be shown.
  // Vi also doesn't do this and the messages are not very informative.
  no_wait_return++;             // don't call wait_return() while busy
  if (itmp != NULL && buf_write(curbuf, itmp, NULL, line1, line2, eap,
                                false, false, false, true) == FAIL) {
    msg_putchar('\n');  // Keep message from buf_write().
    no_wait_return--;
    if (!aborting()) {
      // will call wait_return()
      semsg(_("E482: Can't create file %s"), itmp);
    }
    goto filterend;
  }
  if (curbuf != old_curbuf) {
    goto filterend;
  }

  if (!do_out) {
    msg_putchar('\n');
  }

  // Create the shell command in allocated memory.
  char *cmd_buf = make_filter_cmd(cmd, itmp, otmp);
  ui_cursor_goto(Rows - 1, 0);

  if (do_out) {
    if (u_save(line2, (linenr_T)(line2 + 1)) == FAIL) {
      xfree(cmd_buf);
      goto error;
    }
    redraw_curbuf_later(UPD_VALID);
  }
  linenr_T read_linecount = curbuf->b_ml.ml_line_count;

  // Pass on the kShellOptDoOut flag when the output is being redirected.
  call_shell(cmd_buf, kShellOptFilter | shell_flags, NULL);
  xfree(cmd_buf);

  did_check_timestamps = false;
  need_check_timestamps = true;

  // When interrupting the shell command, it may still have produced some
  // useful output.  Reset got_int here, so that readfile() won't cancel
  // reading.
  os_breakcheck();
  got_int = false;

  if (do_out) {
    if (otmp != NULL) {
      if (readfile(otmp, NULL, line2, 0, (linenr_T)MAXLNUM, eap,
                   READ_FILTER, false) != OK) {
        if (!aborting()) {
          msg_putchar('\n');
          semsg(_(e_notread), otmp);
        }
        goto error;
      }
      if (curbuf != old_curbuf) {
        goto filterend;
      }
    }

    read_linecount = curbuf->b_ml.ml_line_count - read_linecount;

    if (shell_flags & kShellOptRead) {
      curbuf->b_op_start.lnum = line2 + 1;
      curbuf->b_op_end.lnum = curwin->w_cursor.lnum;
      appended_lines_mark(line2, read_linecount);
    }

    if (do_in) {
      if ((cmdmod.cmod_flags & CMOD_KEEPMARKS)
          || vim_strchr(p_cpo, CPO_REMMARK) == NULL) {
        // TODO(bfredl): Currently not active for extmarks. What would we
        // do if columns don't match, assume added/deleted bytes at the
        // end of each line?
        if (read_linecount >= linecount) {
          // move all marks from old lines to new lines
          mark_adjust(line1, line2, linecount, 0, kExtmarkNOOP);
        } else {
          // move marks from old lines to new lines, delete marks
          // that are in deleted lines
          mark_adjust(line1, line1 + read_linecount - 1, linecount, 0,
                      kExtmarkNOOP);
          mark_adjust(line1 + read_linecount, line2, MAXLNUM, 0,
                      kExtmarkNOOP);
        }
      }

      // Put cursor on first filtered line for ":range!cmd".
      // Adjust '[ and '] (set by buf_write()).
      curwin->w_cursor.lnum = line1;
      del_lines(linecount, true);
      curbuf->b_op_start.lnum -= linecount;             // adjust '[
      curbuf->b_op_end.lnum -= linecount;               // adjust ']
      write_lnum_adjust(-linecount);                    // adjust last line
                                                        // for next write
      foldUpdate(curwin, curbuf->b_op_start.lnum, curbuf->b_op_end.lnum);
    } else {
      // Put cursor on last new line for ":r !cmd".
      linecount = curbuf->b_op_end.lnum - curbuf->b_op_start.lnum + 1;
      curwin->w_cursor.lnum = curbuf->b_op_end.lnum;
    }

    beginline(BL_WHITE | BL_FIX);           // cursor on first non-blank
    no_wait_return--;

    if (linecount > p_report) {
      if (do_in) {
        vim_snprintf(msg_buf, sizeof(msg_buf),
                     _("%" PRId64 " lines filtered"), (int64_t)linecount);
        if (msg(msg_buf, 0) && !msg_scroll) {
          // save message to display it after redraw
          set_keep_msg(msg_buf, 0);
        }
      } else {
        msgmore(linecount);
      }
    }
  } else {
error:
    // put cursor back in same position for ":w !cmd"
    curwin->w_cursor = cursor_save;
    no_wait_return--;
    wait_return(false);
  }

filterend:

  cmdmod.cmod_flags = save_cmod_flags;
  if (curbuf != old_curbuf) {
    no_wait_return--;
    emsg(_("E135: *Filter* Autocommands must not change current buffer"));
  } else if (cmdmod.cmod_flags & CMOD_LOCKMARKS) {
    curbuf->b_op_start = orig_start;
    curbuf->b_op_end = orig_end;
  }

  if (itmp != NULL) {
    os_remove(itmp);
  }
  if (otmp != NULL) {
    os_remove(otmp);
  }
  xfree(itmp);
  xfree(otmp);
}

/// Call a shell to execute a command.
/// When "cmd" is NULL start an interactive shell.
///
/// @param flags  may be SHELL_DOOUT when output is redirected
void do_shell(char *cmd, int flags)
{
  // Disallow shell commands in secure mode
  if (check_secure()) {
    msg_end();
    return;
  }

  // For autocommands we want to get the output on the current screen, to
  // avoid having to type return below.
  msg_putchar('\r');                    // put cursor at start of line
  msg_putchar('\n');                    // may shift screen one line up

  // warning message before calling the shell
  if (p_warn
      && !autocmd_busy
      && msg_silent == 0) {
    FOR_ALL_BUFFERS(buf) {
      if (bufIsChanged(buf)) {
        msg_puts(_("[No write since last change]\n"));
        break;
      }
    }
  }

  // This ui_cursor_goto is required for when the '\n' resulted in a "delete line
  // 1" command to the terminal.
  ui_cursor_goto(msg_row, msg_col);
  call_shell(cmd, flags, NULL);
  if (msg_silent == 0) {
    msg_didout = true;
  }
  did_check_timestamps = false;
  need_check_timestamps = true;

  // put the message cursor at the end of the screen, avoids wait_return()
  // to overwrite the text that the external command showed
  msg_row = Rows - 1;
  msg_col = 0;

  apply_autocmds(EVENT_SHELLCMDPOST, NULL, NULL, false, curbuf);
}

#if !defined(UNIX)
static char *find_pipe(const char *cmd)
{
  bool inquote = false;

  for (const char *p = cmd; *p != NUL; p++) {
    if (!inquote && *p == '|') {
      return (char *)p;
    }
    if (*p == '"') {
      inquote = !inquote;
    } else if (rem_backslash(p)) {
      p++;
    }
  }
  return NULL;
}
#endif

/// Create a shell command from a command string, input redirection file and
/// output redirection file.
///
/// @param cmd  Command to execute.
/// @param itmp NULL or the input file.
/// @param otmp NULL or the output file.
/// @returns an allocated string with the shell command.
char *make_filter_cmd(char *cmd, char *itmp, char *otmp)
{
  bool is_fish_shell =
#if defined(UNIX)
    strncmp(invocation_path_tail(p_sh, NULL), "fish", 4) == 0;
#else
    false;
#endif
  bool is_pwsh = strncmp(invocation_path_tail(p_sh, NULL), "pwsh", 4) == 0
                 || strncmp(invocation_path_tail(p_sh, NULL), "powershell",
                            10) == 0;

  size_t len = strlen(cmd) + 1;  // At least enough space for cmd + NULL.

  len += is_fish_shell ? sizeof("begin; " "; end") - 1
                       : !is_pwsh ? sizeof("(" ")") - 1
                                  : 0;

  if (itmp != NULL) {
    len += is_pwsh ? strlen(itmp) + sizeof("& { Get-Content " " | & " " }") - 1 + 6  // +6: #20530
                   : strlen(itmp) + sizeof(" { " " < " " } ") - 1;
  }
  if (otmp != NULL) {
    len += strlen(otmp) + strlen(p_srr) + 2;  // two extra spaces ("  "),
  }

  char *const buf = xmalloc(len);

  if (is_pwsh) {
    if (itmp != NULL) {
      xstrlcpy(buf, "& { Get-Content ", len - 1);  // FIXME: should we add "-Encoding utf8"?
      xstrlcat(buf, itmp, len - 1);
      xstrlcat(buf, " | & ", len - 1);  // FIXME: add `&` ourself or leave to user?
      xstrlcat(buf, cmd, len - 1);
      xstrlcat(buf, " }", len - 1);
    } else {
      xstrlcpy(buf, cmd, len - 1);
    }
  } else {
#if defined(UNIX)
    // Put delimiters around the command (for concatenated commands) when
    // redirecting input and/or output.
    if (itmp != NULL || otmp != NULL) {
      char *fmt = is_fish_shell ? "begin; %s; end"
                                : "(%s)";
      vim_snprintf(buf, len, fmt, cmd);
    } else {
      xstrlcpy(buf, cmd, len);
    }

    if (itmp != NULL) {
      xstrlcat(buf, " < ", len - 1);
      xstrlcat(buf, itmp, len - 1);
    }
#else
    // For shells that don't understand braces around commands, at least allow
    // the use of commands in a pipe.
    xstrlcpy(buf, cmd, len);
    if (itmp != NULL) {
      // If there is a pipe, we have to put the '<' in front of it.
      // Don't do this when 'shellquote' is not empty, otherwise the
      // redirection would be inside the quotes.
      if (*p_shq == NUL) {
        char *const p = find_pipe(buf);
        if (p != NULL) {
          *p = NUL;
        }
      }
      xstrlcat(buf, " < ", len);
      xstrlcat(buf, itmp, len);
      if (*p_shq == NUL) {
        const char *const p = find_pipe(cmd);
        if (p != NULL) {
          xstrlcat(buf, " ", len - 1);  // Insert a space before the '|' for DOS
          xstrlcat(buf, p, len - 1);
        }
      }
    }
#endif
  }
  if (otmp != NULL) {
    append_redir(buf, len, p_srr, otmp);
  }
  return buf;
}

/// Append output redirection for the given file to the end of the buffer
///
/// @param[out]  buf  Buffer to append to.
/// @param[in]  buflen  Buffer length.
/// @param[in]  opt  Separator or format string to append: will append
///                  `printf(' ' . opt, fname)` if `%s` is found in `opt` or
///                  a space, opt, a space and then fname if `%s` is not found
///                  there.
/// @param[in]  fname  File name to append.
void append_redir(char *const buf, const size_t buflen, const char *const opt,
                  const char *const fname)
{
  char *const end = buf + strlen(buf);
  // find "%s"
  const char *p = opt;
  for (; (p = strchr(p, '%')) != NULL; p++) {
    if (p[1] == 's') {  // found %s
      break;
    } else if (p[1] == '%') {  // skip %%
      p++;
    }
  }
  if (p != NULL) {
    *end = ' ';  // not really needed? Not with sh, ksh or bash
    vim_snprintf(end + 1, (size_t)((ptrdiff_t)buflen - (end + 1 - buf)), opt, fname);
  } else {
    vim_snprintf(end, (size_t)((ptrdiff_t)buflen - (end - buf)), " %s %s", opt, fname);
  }
}

void print_line_no_prefix(linenr_T lnum, int use_number, bool list)
{
  char numbuf[30];

  if (curwin->w_p_nu || use_number) {
    vim_snprintf(numbuf, sizeof(numbuf), "%*" PRIdLINENR " ",
                 number_width(curwin), lnum);
    msg_puts_hl(numbuf, HLF_N + 1, false);  // Highlight line nrs.
  }
  msg_prt_line(ml_get(lnum), list);
}

/// Print a text line.  Also in silent mode ("ex -s").
void print_line(linenr_T lnum, int use_number, bool list)
{
  bool save_silent = silent_mode;

  // apply :filter /pat/
  if (message_filtered(ml_get(lnum))) {
    return;
  }

  msg_start();
  silent_mode = false;
  info_message = true;  // use stdout, not stderr
  print_line_no_prefix(lnum, use_number, list);
  if (save_silent) {
    msg_putchar('\n');
    silent_mode = save_silent;
  }
  info_message = false;
}

int rename_buffer(char *new_fname)
{
  buf_T *buf = curbuf;
  apply_autocmds(EVENT_BUFFILEPRE, NULL, NULL, false, curbuf);
  // buffer changed, don't change name now
  if (buf != curbuf) {
    return FAIL;
  }
  if (aborting()) {         // autocmds may abort script processing
    return FAIL;
  }
  // The name of the current buffer will be changed.
  // A new (unlisted) buffer entry needs to be made to hold the old file
  // name, which will become the alternate file name.
  // But don't set the alternate file name if the buffer didn't have a
  // name.
  char *fname = curbuf->b_ffname;
  char *sfname = curbuf->b_sfname;
  char *xfname = curbuf->b_fname;
  curbuf->b_ffname = NULL;
  curbuf->b_sfname = NULL;
  if (setfname(curbuf, new_fname, NULL, true) == FAIL) {
    curbuf->b_ffname = fname;
    curbuf->b_sfname = sfname;
    return FAIL;
  }
  curbuf->b_flags |= BF_NOTEDITED;
  if (xfname != NULL && *xfname != NUL) {
    buf = buflist_new(fname, xfname, curwin->w_cursor.lnum, 0);
    if (buf != NULL && (cmdmod.cmod_flags & CMOD_KEEPALT) == 0) {
      curwin->w_alt_fnum = buf->b_fnum;
    }
  }
  xfree(fname);
  xfree(sfname);
  apply_autocmds(EVENT_BUFFILEPOST, NULL, NULL, false, curbuf);
  // Change directories when the 'acd' option is set.
  do_autochdir();
  return OK;
}

/// ":file[!] [fname]".
void ex_file(exarg_T *eap)
{
  // ":0file" removes the file name.  Check for illegal uses ":3file",
  // "0file name", etc.
  if (eap->addr_count > 0
      && (*eap->arg != NUL
          || eap->line2 > 0
          || eap->addr_count > 1)) {
    emsg(_(e_invarg));
    return;
  }

  if (*eap->arg != NUL || eap->addr_count == 1) {
    if (rename_buffer(eap->arg) == FAIL) {
      return;
    }
    redraw_tabline = true;
  }

  // print file name if no argument or 'F' is not in 'shortmess'
  if (*eap->arg == NUL || !shortmess(SHM_FILEINFO)) {
    fileinfo(false, false, eap->forceit);
  }
}

/// ":update".
void ex_update(exarg_T *eap)
{
  if (curbufIsChanged()) {
    do_write(eap);
  }
}

/// ":write" and ":saveas".
void ex_write(exarg_T *eap)
{
  if (eap->cmdidx == CMD_saveas) {
    // :saveas does not take a range, uses all lines.
    eap->line1 = 1;
    eap->line2 = curbuf->b_ml.ml_line_count;
  }

  if (eap->usefilter) {  // input lines to shell command
    do_bang(1, eap, false, true, false);
  } else {
    do_write(eap);
  }
}

#ifdef UNIX
static int check_writable(const char *fname)
{
  if (os_nodetype(fname) == NODE_OTHER) {
    semsg(_("E503: \"%s\" is not a file or writable device"), fname);
    return FAIL;
  }
  return OK;
}
#endif

/// Write current buffer to file "eap->arg".
/// If "eap->append" is true, append to the file.
///
/// If "*eap->arg == NUL" write to current file.
///
/// @return  FAIL for failure, OK otherwise.
int do_write(exarg_T *eap)
{
  bool other;
  char *fname = NULL;            // init to shut up gcc
  int retval = FAIL;
  char *free_fname = NULL;
  buf_T *alt_buf = NULL;

  if (not_writing()) {          // check 'write' option
    return FAIL;
  }

  char *ffname = eap->arg;
  if (*ffname == NUL) {
    if (eap->cmdidx == CMD_saveas) {
      emsg(_(e_argreq));
      goto theend;
    }
    other = false;
  } else {
    fname = ffname;
    free_fname = fix_fname(ffname);
    // When out-of-memory, keep unexpanded file name, because we MUST be
    // able to write the file in this situation.
    if (free_fname != NULL) {
      ffname = free_fname;
    }
    other = otherfile(ffname);
  }

  // If we have a new file, put its name in the list of alternate file names.
  if (other) {
    if (vim_strchr(p_cpo, CPO_ALTWRITE) != NULL
        || eap->cmdidx == CMD_saveas) {
      alt_buf = setaltfname(ffname, fname, 1);
    } else {
      alt_buf = buflist_findname(ffname);
    }
    if (alt_buf != NULL && alt_buf->b_ml.ml_mfp != NULL) {
      // Overwriting a file that is loaded in another buffer is not a
      // good idea.
      emsg(_(e_bufloaded));
      goto theend;
    }
  }

  // Writing to the current file is not allowed in readonly mode
  // and a file name is required.
  // "nofile" and "nowrite" buffers cannot be written implicitly either.
  if (!other && (bt_dontwrite_msg(curbuf)
                 || check_fname() == FAIL
#ifdef UNIX
                 || check_writable(curbuf->b_ffname) == FAIL
#endif
                 || check_readonly(&eap->forceit, curbuf))) {
    goto theend;
  }

  if (!other) {
    ffname = curbuf->b_ffname;
    fname = curbuf->b_fname;
    // Not writing the whole file is only allowed with '!'.
    if ((eap->line1 != 1
         || eap->line2 != curbuf->b_ml.ml_line_count)
        && !eap->forceit
        && !eap->append
        && !p_wa) {
      if (p_confirm || (cmdmod.cmod_flags & CMOD_CONFIRM)) {
        if (vim_dialog_yesno(VIM_QUESTION, NULL,
                             _("Write partial file?"), 2) != VIM_YES) {
          goto theend;
        }
        eap->forceit = true;
      } else {
        emsg(_("E140: Use ! to write partial buffer"));
        goto theend;
      }
    }
  }

  if (check_overwrite(eap, curbuf, fname, ffname, other) == OK) {
    if (eap->cmdidx == CMD_saveas && alt_buf != NULL) {
      buf_T *was_curbuf = curbuf;

      apply_autocmds(EVENT_BUFFILEPRE, NULL, NULL, false, curbuf);
      apply_autocmds(EVENT_BUFFILEPRE, NULL, NULL, false, alt_buf);
      if (curbuf != was_curbuf || aborting()) {
        // buffer changed, don't change name now
        retval = FAIL;
        goto theend;
      }
      // Exchange the file names for the current and the alternate
      // buffer.  This makes it look like we are now editing the buffer
      // under the new name.  Must be done before buf_write(), because
      // if there is no file name and 'cpo' contains 'F', it will set
      // the file name.
      fname = alt_buf->b_fname;
      alt_buf->b_fname = curbuf->b_fname;
      curbuf->b_fname = fname;
      fname = alt_buf->b_ffname;
      alt_buf->b_ffname = curbuf->b_ffname;
      curbuf->b_ffname = fname;
      fname = alt_buf->b_sfname;
      alt_buf->b_sfname = curbuf->b_sfname;
      curbuf->b_sfname = fname;
      buf_name_changed(curbuf);
      apply_autocmds(EVENT_BUFFILEPOST, NULL, NULL, false, curbuf);
      apply_autocmds(EVENT_BUFFILEPOST, NULL, NULL, false, alt_buf);
      if (!alt_buf->b_p_bl) {
        alt_buf->b_p_bl = true;
        apply_autocmds(EVENT_BUFADD, NULL, NULL, false, alt_buf);
      }
      if (curbuf != was_curbuf || aborting()) {
        // buffer changed, don't write the file
        retval = FAIL;
        goto theend;
      }

      // If 'filetype' was empty try detecting it now.
      if (*curbuf->b_p_ft == NUL) {
        if (augroup_exists("filetypedetect")) {
          do_doautocmd("filetypedetect BufRead", true, NULL);
        }
        do_modelines(0);
      }

      // Autocommands may have changed buffer names, esp. when
      // 'autochdir' is set.
      fname = curbuf->b_sfname;
    }

    if (eap->mkdir_p) {
      if (os_file_mkdir(fname, 0755) < 0) {
        retval = FAIL;
        goto theend;
      }
    }

    int name_was_missing = curbuf->b_ffname == NULL;
    retval = buf_write(curbuf, ffname, fname, eap->line1, eap->line2,
                       eap, eap->append, eap->forceit, true, false);

    // After ":saveas fname" reset 'readonly'.
    if (eap->cmdidx == CMD_saveas) {
      if (retval == OK) {
        curbuf->b_p_ro = false;
        redraw_tabline = true;
      }
    }

    // Change directories when the 'acd' option is set and the file name
    // got changed or set.
    if (eap->cmdidx == CMD_saveas || name_was_missing) {
      do_autochdir();
    }
  }

theend:
  xfree(free_fname);
  return retval;
}

/// Check if it is allowed to overwrite a file.  If b_flags has BF_NOTEDITED,
/// BF_NEW or BF_READERR, check for overwriting current file.
/// May set eap->forceit if a dialog says it's OK to overwrite.
///
/// @param fname   file name to be used (can differ from buf->ffname)
/// @param ffname  full path version of fname
/// @param other   writing under other name
///
/// @return  OK if it's OK, FAIL if it is not.
int check_overwrite(exarg_T *eap, buf_T *buf, char *fname, char *ffname, bool other)
{
  // Write to another file or b_flags set or not writing the whole file:
  // overwriting only allowed with '!'
  // If "other" is false and bt_nofilename(buf) is true, this must be
  // writing an "acwrite" buffer to the same file as its b_ffname, and
  // buf_write() will only allow writing with BufWriteCmd autocommands,
  // so there is no need for an overwrite check.
  if ((other
       || (!bt_nofilename(buf)
           && ((buf->b_flags & BF_NOTEDITED)
               || ((buf->b_flags & BF_NEW)
                   && vim_strchr(p_cpo, CPO_OVERNEW) == NULL)
               || (buf->b_flags & BF_READERR))))
      && !p_wa
      && os_path_exists(ffname)) {
    if (!eap->forceit && !eap->append) {
#ifdef UNIX
      // It is possible to open a directory on Unix.
      if (os_isdir(ffname)) {
        semsg(_(e_isadir2), ffname);
        return FAIL;
      }
#endif
      if (p_confirm || (cmdmod.cmod_flags & CMOD_CONFIRM)) {
        char buff[DIALOG_MSG_SIZE];

        dialog_msg(buff, _("Overwrite existing file \"%s\"?"), fname);
        if (vim_dialog_yesno(VIM_QUESTION, NULL, buff, 2) != VIM_YES) {
          return FAIL;
        }
        eap->forceit = true;
      } else {
        emsg(_(e_exists));
        return FAIL;
      }
    }

    // For ":w! filename" check that no swap file exists for "filename".
    if (other && !emsg_silent) {
      char *dir;

      // We only try the first entry in 'directory', without checking if
      // it's writable.  If the "." directory is not writable the write
      // will probably fail anyway.
      // Use 'shortname' of the current buffer, since there is no buffer
      // for the written file.
      if (*p_dir == NUL) {
        dir = xmalloc(5);
        STRCPY(dir, ".");
      } else {
        dir = xmalloc(MAXPATHL);
        char *p = p_dir;
        copy_option_part(&p, dir, MAXPATHL, ",");
      }
      char *swapname = makeswapname(fname, ffname, curbuf, dir);
      xfree(dir);
      if (os_path_exists(swapname)) {
        if (p_confirm || (cmdmod.cmod_flags & CMOD_CONFIRM)) {
          char buff[DIALOG_MSG_SIZE];

          dialog_msg(buff,
                     _("Swap file \"%s\" exists, overwrite anyway?"),
                     swapname);
          if (vim_dialog_yesno(VIM_QUESTION, NULL, buff, 2)
              != VIM_YES) {
            xfree(swapname);
            return FAIL;
          }
          eap->forceit = true;
        } else {
          semsg(_("E768: Swap file exists: %s (:silent! overrides)"),
                swapname);
          xfree(swapname);
          return FAIL;
        }
      }
      xfree(swapname);
    }
  }
  return OK;
}

/// Handle ":wnext", ":wNext" and ":wprevious" commands.
void ex_wnext(exarg_T *eap)
{
  int i;

  if (eap->cmd[1] == 'n') {
    i = curwin->w_arg_idx + (int)eap->line2;
  } else {
    i = curwin->w_arg_idx - (int)eap->line2;
  }
  eap->line1 = 1;
  eap->line2 = curbuf->b_ml.ml_line_count;
  if (do_write(eap) != FAIL) {
    do_argfile(eap, i);
  }
}

/// ":wall", ":wqall" and ":xall": Write all changed files (and exit).
void do_wqall(exarg_T *eap)
{
  int error = 0;
  int save_forceit = eap->forceit;

  if (eap->cmdidx == CMD_xall || eap->cmdidx == CMD_wqall) {
    if (before_quit_all(eap) == FAIL) {
      return;
    }
    exiting = true;
  }

  FOR_ALL_BUFFERS(buf) {
    if (exiting
        && buf->terminal
        && channel_job_running((uint64_t)buf->b_p_channel)) {
      no_write_message_nobang(buf);
      error++;
    } else if (!bufIsChanged(buf) || bt_dontwrite(buf)) {
      continue;
    }
    // Check if there is a reason the buffer cannot be written:
    // 1. if the 'write' option is set
    // 2. if there is no file name (even after browsing)
    // 3. if the 'readonly' is set (even after a dialog)
    // 4. if overwriting is allowed (even after a dialog)
    if (not_writing()) {
      error++;
      break;
    }
    if (buf->b_ffname == NULL) {
      semsg(_("E141: No file name for buffer %" PRId64), (int64_t)buf->b_fnum);
      error++;
    } else if (check_readonly(&eap->forceit, buf)
               || check_overwrite(eap, buf, buf->b_fname, buf->b_ffname, false) == FAIL) {
      error++;
    } else {
      bufref_T bufref;
      set_bufref(&bufref, buf);
      if (buf_write_all(buf, eap->forceit) == FAIL) {
        error++;
      }
      // An autocommand may have deleted the buffer.
      if (!bufref_valid(&bufref)) {
        buf = firstbuf;
      }
    }
    eap->forceit = save_forceit;          // check_overwrite() may set it
  }
  if (exiting) {
    if (!error) {
      getout(0);                // exit Vim
    }
    not_exiting();
  }
}

/// Check the 'write' option.
///
/// @return  true and give a message when it's not st.
bool not_writing(void)
{
  if (p_write) {
    return false;
  }
  emsg(_("E142: File not written: Writing is disabled by 'write' option"));
  return true;
}

/// Check if a buffer is read-only (either 'readonly' option is set or file is
/// read-only). Ask for overruling in a dialog. Return true and give an error
/// message when the buffer is readonly.
static int check_readonly(int *forceit, buf_T *buf)
{
  // Handle a file being readonly when the 'readonly' option is set or when
  // the file exists and permissions are read-only.
  if (!*forceit && (buf->b_p_ro
                    || (os_path_exists(buf->b_ffname)
                        && !os_file_is_writable(buf->b_ffname)))) {
    if ((p_confirm || (cmdmod.cmod_flags & CMOD_CONFIRM)) && buf->b_fname != NULL) {
      char buff[DIALOG_MSG_SIZE];

      if (buf->b_p_ro) {
        dialog_msg(buff,
                   _("'readonly' option is set for \"%s\".\nDo you wish to write anyway?"),
                   buf->b_fname);
      } else {
        dialog_msg(buff,
                   _("File permissions of \"%s\" are read-only.\nIt may still be possible to "
                     "write it.\nDo you wish to try?"),
                   buf->b_fname);
      }

      if (vim_dialog_yesno(VIM_QUESTION, NULL, buff, 2) == VIM_YES) {
        // Set forceit, to force the writing of a readonly file
        *forceit = true;
        return false;
      }
      return true;
    } else if (buf->b_p_ro) {
      emsg(_(e_readonly));
    } else {
      semsg(_("E505: \"%s\" is read-only (add ! to override)"),
            buf->b_fname);
    }
    return true;
  }

  return false;
}

/// Try to abandon the current file and edit a new or existing file.
///
/// @param fnum  the number of the file, if zero use "ffname_arg"/"sfname_arg".
/// @param lnum  the line number for the cursor in the new file (if non-zero).
///
/// @return:
///           GETFILE_ERROR for "normal" error,
///           GETFILE_NOT_WRITTEN for "not written" error,
///           GETFILE_SAME_FILE for success
///           GETFILE_OPEN_OTHER for successfully opening another file.
int getfile(int fnum, char *ffname_arg, char *sfname_arg, bool setpm, linenr_T lnum, bool forceit)
{
  if (!check_can_set_curbuf_forceit(forceit)) {
    return GETFILE_ERROR;
  }

  char *ffname = ffname_arg;
  char *sfname = sfname_arg;
  bool other;
  int retval;
  char *free_me = NULL;

  if (text_locked()) {
    return GETFILE_ERROR;
  }
  if (curbuf_locked()) {
    return GETFILE_ERROR;
  }

  if (fnum == 0) {
    // make ffname full path, set sfname
    fname_expand(curbuf, &ffname, &sfname);
    other = otherfile(ffname);
    free_me = ffname;                   // has been allocated, free() later
  } else {
    other = (fnum != curbuf->b_fnum);
  }

  if (other) {
    no_wait_return++;               // don't wait for autowrite message
  }
  if (other && !forceit && curbuf->b_nwindows == 1 && !buf_hide(curbuf)
      && curbufIsChanged() && autowrite(curbuf, forceit) == FAIL) {
    if (p_confirm && p_write) {
      dialog_changed(curbuf, false);
    }
    if (curbufIsChanged()) {
      no_wait_return--;
      no_write_message();
      retval = GETFILE_NOT_WRITTEN;     // File has been changed.
      goto theend;
    }
  }
  if (other) {
    no_wait_return--;
  }
  if (setpm) {
    setpcmark();
  }
  if (!other) {
    if (lnum != 0) {
      curwin->w_cursor.lnum = lnum;
    }
    check_cursor_lnum(curwin);
    beginline(BL_SOL | BL_FIX);
    retval = GETFILE_SAME_FILE;     // it's in the same file
  } else if (do_ecmd(fnum, ffname, sfname, NULL, lnum,
                     (buf_hide(curbuf) ? ECMD_HIDE : 0)
                     + (forceit ? ECMD_FORCEIT : 0), curwin) == OK) {
    retval = GETFILE_OPEN_OTHER;    // opened another file
  } else {
    retval = GETFILE_ERROR;         // error encountered
  }

theend:
  xfree(free_me);
  return retval;
}

/// set v:swapcommand for the SwapExists autocommands.
///
/// @param command  [+cmd] to be executed (e.g. +10).
/// @param newlnum  if > 0: put cursor on this line number (if possible)
//
/// @return 1 if swapcommand was actually set, 0 otherwise
bool set_swapcommand(char *command, linenr_T newlnum)
{
  if ((command == NULL && newlnum <= 0) || *get_vim_var_str(VV_SWAPCOMMAND) != NUL) {
    return false;
  }
  const size_t len = (command != NULL) ? strlen(command) + 3 : 30;
  char *const p = xmalloc(len);
  if (command != NULL) {
    vim_snprintf(p, len, ":%s\r", command);
  } else {
    vim_snprintf(p, len, "%" PRId64 "G", (int64_t)newlnum);
  }
  set_vim_var_string(VV_SWAPCOMMAND, p, -1);
  xfree(p);
  return true;
}

/// start editing a new file
///
/// @param fnum     file number; if zero use ffname/sfname
/// @param ffname   the file name
///                 - full path if sfname used,
///                 - any file name if sfname is NULL
///                 - empty string to re-edit with the same file name (but may
///                   be in a different directory)
///                 - NULL to start an empty buffer
/// @param sfname   the short file name (or NULL)
/// @param eap      contains the command to be executed after loading the file
///                 and forced 'ff' and 'fenc'. Can be NULL!
/// @param newlnum  if > 0: put cursor on this line number (if possible)
///                 ECMD_LASTL: use last position in loaded file
///                 ECMD_LAST: use last position in all files
///                 ECMD_ONE: use first line
/// @param flags    ECMD_HIDE: if true don't free the current buffer
///                 ECMD_SET_HELP: set b_help flag of (new) buffer before
///                 opening file
///                 ECMD_OLDBUF: use existing buffer if it exists
///                 ECMD_FORCEIT: ! used for Ex command
///                 ECMD_ADDBUF: don't edit, just add to buffer list
///                 ECMD_ALTBUF: like ECMD_ADDBUF and also set the alternate
///                 file
///                 ECMD_NOWINENTER: Do not trigger BufWinEnter
/// @param oldwin   Should be "curwin" when editing a new buffer in the current
///                 window, NULL when splitting the window first.  When not NULL
///                 info of the previous buffer for "oldwin" is stored.
///
/// @return FAIL for failure, OK otherwise
int do_ecmd(int fnum, char *ffname, char *sfname, exarg_T *eap, linenr_T newlnum, int flags,
            win_T *oldwin)
{
  bool other_file;                      // true if editing another file
  int oldbuf;                           // true if using existing buffer
  bool auto_buf = false;                // true if autocommands brought us
                                        // into the buffer unexpectedly
  char *new_name = NULL;
  bool did_set_swapcommand = false;
  buf_T *buf;
  bufref_T bufref;
  bufref_T old_curbuf;
  char *free_fname = NULL;
  int retval = FAIL;
  linenr_T topline = 0;
  int newcol = -1;
  int solcol = -1;
  char *command = NULL;
  bool did_get_winopts = false;
  int readfile_flags = 0;
  bool did_inc_redrawing_disabled = false;
  OptInt *so_ptr = curwin->w_p_so >= 0 ? &curwin->w_p_so : &p_so;

  if (eap != NULL) {
    command = eap->do_ecmd_cmd;
  }

  set_bufref(&old_curbuf, curbuf);

  if (fnum != 0) {
    if (fnum == curbuf->b_fnum) {       // file is already being edited
      return OK;                        // nothing to do
    }
    other_file = true;
  } else {
    // if no short name given, use ffname for short name
    if (sfname == NULL) {
      sfname = ffname;
    }
#ifdef CASE_INSENSITIVE_FILENAME
    if (sfname != NULL) {
      path_fix_case(sfname);             // set correct case for sfname
    }
#endif

    if ((flags & (ECMD_ADDBUF | ECMD_ALTBUF))
        && (ffname == NULL || *ffname == NUL)) {
      goto theend;
    }

    if (ffname == NULL) {
      other_file = true;
    } else if (*ffname == NUL && curbuf->b_ffname == NULL) {  // there is no file name
      other_file = false;
    } else {
      if (*ffname == NUL) {                 // re-edit with same file name
        ffname = curbuf->b_ffname;
        sfname = curbuf->b_fname;
      }
      free_fname = fix_fname(ffname);       // may expand to full path name
      if (free_fname != NULL) {
        ffname = free_fname;
      }
      other_file = otherfile(ffname);
    }
  }

  // Re-editing a terminal buffer: skip most buffer re-initialization.
  if (!other_file && curbuf->terminal) {
    check_arg_idx(curwin);  // Needed when called from do_argfile().
    maketitle();            // Title may show the arg index, e.g. "(2 of 5)".
    retval = OK;
    goto theend;
  }

  // If the file was changed we may not be allowed to abandon it:
  // - if we are going to re-edit the same file
  // - or if we are the only window on this file and if ECMD_HIDE is false
  if (((!other_file && !(flags & ECMD_OLDBUF))
       || (curbuf->b_nwindows == 1
           && !(flags & (ECMD_HIDE | ECMD_ADDBUF | ECMD_ALTBUF))))
      && check_changed(curbuf, (p_awa ? CCGD_AW : 0)
                       | (other_file ? 0 : CCGD_MULTWIN)
                       | ((flags & ECMD_FORCEIT) ? CCGD_FORCEIT : 0)
                       | (eap == NULL ? 0 : CCGD_EXCMD))) {
    if (fnum == 0 && other_file && ffname != NULL) {
      setaltfname(ffname, sfname, newlnum < 0 ? 0 : newlnum);
    }
    goto theend;
  }

  // End Visual mode before switching to another buffer, so the text can be
  // copied into the GUI selection buffer.
  // Careful: may trigger ModeChanged() autocommand

  // Should we block autocommands here?
  reset_VIsual();

  // autocommands freed window :(
  if (oldwin != NULL && !win_valid(oldwin)) {
    oldwin = NULL;
  }

  did_set_swapcommand = set_swapcommand(command, newlnum);

  // If we are starting to edit another file, open a (new) buffer.
  // Otherwise we re-use the current buffer.
  if (other_file) {
    const int prev_alt_fnum = curwin->w_alt_fnum;

    if (!(flags & (ECMD_ADDBUF | ECMD_ALTBUF))) {
      if ((cmdmod.cmod_flags & CMOD_KEEPALT) == 0) {
        curwin->w_alt_fnum = curbuf->b_fnum;
      }
      if (oldwin != NULL) {
        buflist_altfpos(oldwin);
      }
    }

    if (fnum) {
      buf = buflist_findnr(fnum);
    } else {
      if (flags & (ECMD_ADDBUF | ECMD_ALTBUF)) {
        // Default the line number to zero to avoid that a wininfo item
        // is added for the current window.
        linenr_T tlnum = 0;

        if (command != NULL) {
          tlnum = (linenr_T)atol(command);
          if (tlnum <= 0) {
            tlnum = 1;
          }
        }
        // Add BLN_NOCURWIN to avoid a new wininfo items are associated
        // with the current window.
        const buf_T *const newbuf
          = buflist_new(ffname, sfname, tlnum, BLN_LISTED | BLN_NOCURWIN);
        if (newbuf != NULL && (flags & ECMD_ALTBUF)) {
          curwin->w_alt_fnum = newbuf->b_fnum;
        }
        goto theend;
      }
      buf = buflist_new(ffname, sfname, 0,
                        BLN_CURBUF | (flags & ECMD_SET_HELP ? 0 : BLN_LISTED));
      // Autocmds may change curwin and curbuf.
      if (oldwin != NULL) {
        oldwin = curwin;
      }
      set_bufref(&old_curbuf, curbuf);
    }
    if (buf == NULL) {
      goto theend;
    }
    // autocommands try to edit a file that is going to be removed, abort
    if (buf_locked(buf)) {
      // window was split, but not editing the new buffer, reset b_nwindows again
      if (oldwin == NULL
          && curwin->w_buffer != NULL
          && curwin->w_buffer->b_nwindows > 1) {
        curwin->w_buffer->b_nwindows--;
      }
      goto theend;
    }
    if (curwin->w_alt_fnum == buf->b_fnum && prev_alt_fnum != 0) {
      // reusing the buffer, keep the old alternate file
      curwin->w_alt_fnum = prev_alt_fnum;
    }
    if (buf->b_ml.ml_mfp == NULL) {
      // No memfile yet.
      oldbuf = false;
    } else {
      // Existing memfile.
      oldbuf = true;
      set_bufref(&bufref, buf);
      buf_check_timestamp(buf);
      // Check if autocommands made buffer invalid or changed the current
      // buffer.
      if (!bufref_valid(&bufref) || curbuf != old_curbuf.br_buf) {
        goto theend;
      }
      if (aborting()) {
        // Autocmds may abort script processing.
        goto theend;
      }
    }

    // May jump to last used line number for a loaded buffer or when asked
    // for explicitly
    if ((oldbuf && newlnum == ECMD_LASTL) || newlnum == ECMD_LAST) {
      pos_T *pos = &buflist_findfmark(buf)->mark;
      newlnum = pos->lnum;
      solcol = pos->col;
    }

    // Make the (new) buffer the one used by the current window.
    // If the old buffer becomes unused, free it if ECMD_HIDE is false.
    // If the current buffer was empty and has no file name, curbuf
    // is returned by buflist_new(), nothing to do here.
    if (buf != curbuf) {
      // Should only be possible to get here if the cmdwin is closed, or
      // if it's opening and its buffer hasn't been set yet (the new
      // buffer is for it).
      assert(cmdwin_buf == NULL);

      const int save_cmdwin_type = cmdwin_type;
      win_T *const save_cmdwin_win = cmdwin_win;
      win_T *const save_cmdwin_old_curwin = cmdwin_old_curwin;

      // BufLeave applies to the old buffer.
      cmdwin_type = 0;
      cmdwin_win = NULL;
      cmdwin_old_curwin = NULL;

      // Be careful: The autocommands may delete any buffer and change
      // the current buffer.
      // - If the buffer we are going to edit is deleted, give up.
      // - If the current buffer is deleted, prefer to load the new
      //   buffer when loading a buffer is required.  This avoids
      //   loading another buffer which then must be closed again.
      // - If we ended up in the new buffer already, need to skip a few
      //         things, set auto_buf.
      if (buf->b_fname != NULL) {
        new_name = xstrdup(buf->b_fname);
      }
      const bufref_T save_au_new_curbuf = au_new_curbuf;
      set_bufref(&au_new_curbuf, buf);
      apply_autocmds(EVENT_BUFLEAVE, NULL, NULL, false, curbuf);

      cmdwin_type = save_cmdwin_type;
      cmdwin_win = save_cmdwin_win;
      cmdwin_old_curwin = save_cmdwin_old_curwin;

      if (!bufref_valid(&au_new_curbuf)) {
        // New buffer has been deleted.
        delbuf_msg(new_name);  // Frees new_name.
        au_new_curbuf = save_au_new_curbuf;
        goto theend;
      }
      if (aborting()) {             // autocmds may abort script processing
        xfree(new_name);
        au_new_curbuf = save_au_new_curbuf;
        goto theend;
      }
      if (buf == curbuf) {  // already in new buffer
        auto_buf = true;
      } else {
        win_T *the_curwin = curwin;
        buf_T *was_curbuf = curbuf;

        // Set w_locked to avoid that autocommands close the window.
        // Set b_locked for the same reason.
        the_curwin->w_locked = true;
        buf->b_locked++;

        if (curbuf == old_curbuf.br_buf) {
          buf_copy_options(buf, BCO_ENTER);
        }

        // Close the link to the current buffer. This will set
        // oldwin->w_buffer to NULL.
        u_sync(false);
        const bool did_decrement
          = close_buffer(oldwin, curbuf, (flags & ECMD_HIDE) || curbuf->terminal ? 0 : DOBUF_UNLOAD,
                         false, false);

        // Autocommands may have closed the window.
        if (win_valid(the_curwin)) {
          the_curwin->w_locked = false;
        }
        buf->b_locked--;

        // autocmds may abort script processing
        if (aborting() && curwin->w_buffer != NULL) {
          xfree(new_name);
          au_new_curbuf = save_au_new_curbuf;
          goto theend;
        }
        // Be careful again, like above.
        if (!bufref_valid(&au_new_curbuf)) {
          // New buffer has been deleted.
          delbuf_msg(new_name);  // Frees new_name.
          au_new_curbuf = save_au_new_curbuf;
          goto theend;
        }
        if (buf == curbuf) {  // already in new buffer
          // close_buffer() has decremented the window count,
          // increment it again here and restore w_buffer.
          if (did_decrement && buf_valid(was_curbuf)) {
            was_curbuf->b_nwindows++;
          }
          if (win_valid_any_tab(oldwin) && oldwin->w_buffer == NULL) {
            oldwin->w_buffer = was_curbuf;
          }
          auto_buf = true;
        } else {
          // <VN> We could instead free the synblock
          // and re-attach to buffer, perhaps.
          if (curwin->w_buffer == NULL
              || curwin->w_s == &(curwin->w_buffer->b_s)) {
            curwin->w_s = &(buf->b_s);
          }

          curwin->w_buffer = buf;
          curbuf = buf;
          curbuf->b_nwindows++;

          // Set 'fileformat', 'binary' and 'fenc' when forced.
          if (!oldbuf && eap != NULL) {
            set_file_options(true, eap);
            set_forced_fenc(eap);
          }
        }

        // May get the window options from the last time this buffer
        // was in this window (or another window).  If not used
        // before, reset the local window options to the global
        // values.  Also restores old folding stuff.
        get_winopts(curbuf);
        did_get_winopts = true;
      }
      xfree(new_name);
      au_new_curbuf = save_au_new_curbuf;
    }

    curwin->w_pcmark.lnum = 1;
    curwin->w_pcmark.col = 0;
  } else {  // !other_file
    if ((flags & (ECMD_ADDBUF | ECMD_ALTBUF)) || check_fname() == FAIL) {
      goto theend;
    }
    oldbuf = (flags & ECMD_OLDBUF);
  }

  // Don't redraw until the cursor is in the right line, otherwise
  // autocommands may cause ml_get errors.
  RedrawingDisabled++;
  did_inc_redrawing_disabled = true;

  buf = curbuf;
  if ((flags & ECMD_SET_HELP) || keep_help_flag) {
    prepare_help_buffer();
  } else if (!curbuf->b_help) {
    // Don't make a buffer listed if it's a help buffer.  Useful when using
    // CTRL-O to go back to a help file.
    set_buflisted(true);
  }

  // If autocommands change buffers under our fingers, forget about
  // editing the file.
  if (buf != curbuf) {
    goto theend;
  }
  if (aborting()) {         // autocmds may abort script processing
    goto theend;
  }

  // Since we are starting to edit a file, consider the filetype to be
  // unset.  Helps for when an autocommand changes files and expects syntax
  // highlighting to work in the other file.
  curbuf->b_did_filetype = false;

  // other_file oldbuf
  //  false     false       re-edit same file, buffer is re-used
  //  false     true        re-edit same file, nothing changes
  //  true      false       start editing new file, new buffer
  //  true      true        start editing in existing buffer (nothing to do)
  if (!other_file && !oldbuf) {         // re-use the buffer
    set_last_cursor(curwin);            // may set b_last_cursor
    if (newlnum == ECMD_LAST || newlnum == ECMD_LASTL) {
      newlnum = curwin->w_cursor.lnum;
      solcol = curwin->w_cursor.col;
    }
    buf = curbuf;
    if (buf->b_fname != NULL) {
      new_name = xstrdup(buf->b_fname);
    } else {
      new_name = NULL;
    }
    set_bufref(&bufref, buf);

    // If the buffer was used before, store the current contents so that
    // the reload can be undone.  Do not do this if the (empty) buffer is
    // being re-used for another file.
    if (!(curbuf->b_flags & BF_NEVERLOADED)
        && (p_ur < 0 || curbuf->b_ml.ml_line_count <= p_ur)) {
      // Sync first so that this is a separate undo-able action.
      u_sync(false);
      if (u_savecommon(curbuf, 0, curbuf->b_ml.ml_line_count + 1, 0, true)
          == FAIL) {
        xfree(new_name);
        goto theend;
      }
      u_unchanged(curbuf);
      buf_updates_unload(curbuf, false);
      buf_freeall(curbuf, BFA_KEEP_UNDO);

      // Tell readfile() not to clear or reload undo info.
      readfile_flags = READ_KEEP_UNDO;
    } else {
      buf_updates_unload(curbuf, false);
      buf_freeall(curbuf, 0);  // Free all things for buffer.
    }
    // If autocommands deleted the buffer we were going to re-edit, give
    // up and jump to the end.
    if (!bufref_valid(&bufref)) {
      delbuf_msg(new_name);  // Frees new_name.
      goto theend;
    }
    xfree(new_name);

    // If autocommands change buffers under our fingers, forget about
    // re-editing the file.  Should do the buf_clear_file(), but perhaps
    // the autocommands changed the buffer...
    if (buf != curbuf) {
      goto theend;
    }
    if (aborting()) {       // autocmds may abort script processing
      goto theend;
    }
    buf_clear_file(curbuf);
    curbuf->b_op_start.lnum = 0;        // clear '[ and '] marks
    curbuf->b_op_end.lnum = 0;
  }

  // If we get here we are sure to start editing

  // Assume success now
  retval = OK;

  // If the file name was changed, reset the not-edit flag so that ":write"
  // works.
  if (!other_file) {
    curbuf->b_flags &= ~BF_NOTEDITED;
  }

  // Check if we are editing the w_arg_idx file in the argument list.
  check_arg_idx(curwin);

  if (!auto_buf) {
    // Set cursor and init window before reading the file and executing
    // autocommands.  This allows for the autocommands to position the
    // cursor.
    curwin_init();

    // It's possible that all lines in the buffer changed.  Need to update
    // automatic folding for all windows where it's used.
    FOR_ALL_TAB_WINDOWS(tp, win) {
      if (win->w_buffer == curbuf) {
        foldUpdateAll(win);
      }
    }

    // Change directories when the 'acd' option is set.
    do_autochdir();

    // Careful: open_buffer() and apply_autocmds() may change the current
    // buffer and window.
    pos_T orig_pos = curwin->w_cursor;
    topline = curwin->w_topline;
    if (!oldbuf) {                          // need to read the file
      swap_exists_action = SEA_DIALOG;
      curbuf->b_flags |= BF_CHECK_RO;       // set/reset 'ro' flag

      // Open the buffer and read the file.
      if (flags & ECMD_NOWINENTER) {
        readfile_flags |= READ_NOWINENTER;
      }
      if (should_abort(open_buffer(false, eap, readfile_flags))) {
        retval = FAIL;
      }

      if (swap_exists_action == SEA_QUIT) {
        retval = FAIL;
      }
      handle_swap_exists(&old_curbuf);
    } else {
      // Read the modelines, but only to set window-local options.  Any
      // buffer-local options have already been set and may have been
      // changed by the user.
      do_modelines(OPT_WINONLY);

      apply_autocmds_retval(EVENT_BUFENTER, NULL, NULL, false, curbuf,
                            &retval);
      if ((flags & ECMD_NOWINENTER) == 0) {
        apply_autocmds_retval(EVENT_BUFWINENTER, NULL, NULL, false, curbuf,
                              &retval);
      }
    }
    check_arg_idx(curwin);

    // If autocommands change the cursor position or topline, we should
    // keep it.  Also when it moves within a line. But not when it moves
    // to the first non-blank.
    if (!equalpos(curwin->w_cursor, orig_pos)) {
      const char *text = get_cursor_line_ptr();

      if (curwin->w_cursor.lnum != orig_pos.lnum
          || curwin->w_cursor.col != (int)(skipwhite(text) - text)) {
        newlnum = curwin->w_cursor.lnum;
        newcol = curwin->w_cursor.col;
      }
    }
    if (curwin->w_topline == topline) {
      topline = 0;
    }

    // Even when cursor didn't move we need to recompute topline.
    changed_line_abv_curs();

    maketitle();
  }

  // Tell the diff stuff that this buffer is new and/or needs updating.
  // Also needed when re-editing the same buffer, because unloading will
  // have removed it as a diff buffer.
  if (curwin->w_p_diff) {
    diff_buf_add(curbuf);
    diff_invalidate(curbuf);
  }

  // If the window options were changed may need to set the spell language.
  // Can only do this after the buffer has been properly setup.
  if (did_get_winopts && curwin->w_p_spell && *curwin->w_s->b_p_spl != NUL) {
    parse_spelllang(curwin);
  }

  if (command == NULL) {
    if (newcol >= 0) {          // position set by autocommands
      curwin->w_cursor.lnum = newlnum;
      curwin->w_cursor.col = newcol;
      check_cursor(curwin);
    } else if (newlnum > 0) {  // line number from caller or old position
      curwin->w_cursor.lnum = newlnum;
      check_cursor_lnum(curwin);
      if (solcol >= 0 && !p_sol) {
        // 'sol' is off: Use last known column.
        curwin->w_cursor.col = solcol;
        check_cursor_col(curwin);
        curwin->w_cursor.coladd = 0;
        curwin->w_set_curswant = true;
      } else {
        beginline(BL_SOL | BL_FIX);
      }
    } else {                  // no line number, go to last line in Ex mode
      if (exmode_active) {
        curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
      }
      beginline(BL_WHITE | BL_FIX);
    }
  }

  // Check if cursors in other windows on the same buffer are still valid
  check_lnums(false);

  // Did not read the file, need to show some info about the file.
  // Do this after setting the cursor.
  if (oldbuf
      && !auto_buf) {
    int msg_scroll_save = msg_scroll;

    // Obey the 'O' flag in 'cpoptions': overwrite any previous file
    // message.
    if (shortmess(SHM_OVERALL) && !msg_listdo_overwrite && !exiting && p_verbose == 0) {
      msg_scroll = false;
    }
    if (!msg_scroll) {          // wait a bit when overwriting an error msg
      msg_check_for_delay(false);
    }
    msg_start();
    msg_scroll = msg_scroll_save;
    msg_scrolled_ign = true;

    if (!shortmess(SHM_FILEINFO)) {
      fileinfo(false, true, false);
    }

    msg_scrolled_ign = false;
  }

  curbuf->b_last_used = time(NULL);

  if (command != NULL) {
    do_cmdline(command, NULL, NULL, DOCMD_VERBOSE);
  }

  if (curbuf->b_kmap_state & KEYMAP_INIT) {
    keymap_init();
  }

  RedrawingDisabled--;
  did_inc_redrawing_disabled = false;
  if (!skip_redraw) {
    OptInt n = *so_ptr;
    if (topline == 0 && command == NULL) {
      *so_ptr = 999;    // force cursor to be vertically centered in the window
    }
    update_topline(curwin);
    curwin->w_scbind_pos = plines_m_win_fill(curwin, 1, curwin->w_topline);
    *so_ptr = n;
    redraw_curbuf_later(UPD_NOT_VALID);  // redraw this buffer later
  }

  // Change directories when the 'acd' option is set.
  do_autochdir();

theend:
  if (bufref_valid(&old_curbuf) && old_curbuf.br_buf->terminal != NULL) {
    terminal_check_size(old_curbuf.br_buf->terminal);
  }

  if (did_inc_redrawing_disabled) {
    RedrawingDisabled--;
  }
  if (did_set_swapcommand) {
    set_vim_var_string(VV_SWAPCOMMAND, NULL, -1);
  }
  xfree(free_fname);
  return retval;
}

static void delbuf_msg(char *name)
{
  semsg(_("E143: Autocommands unexpectedly deleted new buffer %s"),
        name == NULL ? "" : name);
  xfree(name);
  au_new_curbuf.br_buf = NULL;
  au_new_curbuf.br_buf_free_count = 0;
}

static int append_indent = 0;       // autoindent for first line

/// ":insert" and ":append", also used by ":change"
void ex_append(exarg_T *eap)
{
  char *theline;
  bool did_undo = false;
  linenr_T lnum = eap->line2;
  int indent = 0;
  char *p;
  bool empty = (curbuf->b_ml.ml_flags & ML_EMPTY);

  // the ! flag toggles autoindent
  if (eap->forceit) {
    curbuf->b_p_ai = !curbuf->b_p_ai;
  }

  // First autoindent comes from the line we start on
  if (eap->cmdidx != CMD_change && curbuf->b_p_ai && lnum > 0) {
    append_indent = get_indent_lnum(lnum);
  }

  if (eap->cmdidx != CMD_append) {
    lnum--;
  }

  // when the buffer is empty need to delete the dummy line
  if (empty && lnum == 1) {
    lnum = 0;
  }

  State = MODE_INSERT;                   // behave like in Insert mode
  if (curbuf->b_p_iminsert == B_IMODE_LMAP) {
    State |= MODE_LANGMAP;
  }

  while (true) {
    msg_scroll = true;
    need_wait_return = false;
    if (curbuf->b_p_ai) {
      if (append_indent >= 0) {
        indent = append_indent;
        append_indent = -1;
      } else if (lnum > 0) {
        indent = get_indent_lnum(lnum);
      }
    }
    if (*eap->arg == '|') {
      // Get the text after the trailing bar.
      theline = xstrdup(eap->arg + 1);
      *eap->arg = NUL;
    } else if (eap->ea_getline == NULL) {
      // No getline() function, use the lines that follow. This ends
      // when there is no more.
      if (eap->nextcmd == NULL) {
        break;
      }
      p = vim_strchr(eap->nextcmd, NL);
      if (p == NULL) {
        p = eap->nextcmd + strlen(eap->nextcmd);
      }
      theline = xmemdupz(eap->nextcmd, (size_t)(p - eap->nextcmd));
      if (*p != NUL) {
        p++;
      } else {
        p = NULL;
      }
      eap->nextcmd = p;
    } else {
      int save_State = State;
      // Set State to avoid the cursor shape to be set to MODE_INSERT
      // state when getline() returns.
      State = MODE_CMDLINE;
      theline = eap->ea_getline(eap->cstack->cs_looplevel > 0 ? -1 : NUL,
                                eap->cookie, indent, true);
      State = save_State;
    }
    lines_left = Rows - 1;
    if (theline == NULL) {
      break;
    }

    // Look for the "." after automatic indent.
    int vcol = 0;
    for (p = theline; indent > vcol; p++) {
      if (*p == ' ') {
        vcol++;
      } else if (*p == TAB) {
        vcol += 8 - vcol % 8;
      } else {
        break;
      }
    }
    if ((p[0] == '.' && p[1] == NUL)
        || (!did_undo && u_save(lnum, lnum + 1 + (empty ? 1 : 0))
            == FAIL)) {
      xfree(theline);
      break;
    }

    // don't use autoindent if nothing was typed.
    if (p[0] == NUL) {
      theline[0] = NUL;
    }

    did_undo = true;
    ml_append(lnum, theline, 0, false);
    if (empty) {
      // there are no marks below the inserted lines
      appended_lines(lnum, 1);
    } else {
      appended_lines_mark(lnum, 1);
    }

    xfree(theline);
    lnum++;

    if (empty) {
      ml_delete(2, false);
      empty = false;
    }
  }
  State = MODE_NORMAL;

  if (eap->forceit) {
    curbuf->b_p_ai = !curbuf->b_p_ai;
  }

  // "start" is set to eap->line2+1 unless that position is invalid (when
  // eap->line2 pointed to the end of the buffer and nothing was appended)
  // "end" is set to lnum when something has been appended, otherwise
  // it is the same as "start"  -- Acevedo
  if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
    curbuf->b_op_start.lnum
      = (eap->line2 < curbuf->b_ml.ml_line_count) ? eap->line2 + 1 : curbuf->b_ml.ml_line_count;
    if (eap->cmdidx != CMD_append) {
      curbuf->b_op_start.lnum--;
    }
    curbuf->b_op_end.lnum = (eap->line2 < lnum) ? lnum : curbuf->b_op_start.lnum;
    curbuf->b_op_start.col = curbuf->b_op_end.col = 0;
  }
  curwin->w_cursor.lnum = lnum;
  check_cursor_lnum(curwin);
  beginline(BL_SOL | BL_FIX);

  need_wait_return = false;     // don't use wait_return() now
  ex_no_reprint = true;
}

/// ":change"
void ex_change(exarg_T *eap)
{
  linenr_T lnum;

  if (eap->line2 >= eap->line1
      && u_save(eap->line1 - 1, eap->line2 + 1) == FAIL) {
    return;
  }

  // the ! flag toggles autoindent
  if (eap->forceit ? !curbuf->b_p_ai : curbuf->b_p_ai) {
    append_indent = get_indent_lnum(eap->line1);
  }

  for (lnum = eap->line2; lnum >= eap->line1; lnum--) {
    if (curbuf->b_ml.ml_flags & ML_EMPTY) {         // nothing to delete
      break;
    }
    ml_delete(eap->line1, false);
  }

  // make sure the cursor is not beyond the end of the file now
  check_cursor_lnum(curwin);
  deleted_lines_mark(eap->line1, (eap->line2 - lnum));

  // ":append" on the line above the deleted lines.
  eap->line2 = eap->line1;
  ex_append(eap);
}

void ex_z(exarg_T *eap)
{
  int64_t bigness;
  int minus = 0;
  linenr_T start, end, curs;
  linenr_T lnum = eap->line2;

  // Vi compatible: ":z!" uses display height, without a count uses
  // 'scroll'
  if (eap->forceit) {
    bigness = Rows - 1;
  } else if (ONE_WINDOW) {
    bigness = curwin->w_p_scr * 2;
  } else {
    bigness = curwin->w_height_inner - 3;
  }
  bigness = MAX(bigness, 1);

  char *x = eap->arg;
  char *kind = x;
  if (*kind == '-' || *kind == '+' || *kind == '='
      || *kind == '^' || *kind == '.') {
    x++;
  }
  while (*x == '-' || *x == '+') {
    x++;
  }

  if (*x != 0) {
    if (!ascii_isdigit(*x)) {
      emsg(_(e_non_numeric_argument_to_z));
      return;
    }
    bigness = atol(x);

    // bigness could be < 0 if atol(x) overflows.
    if (bigness > 2 * curbuf->b_ml.ml_line_count || bigness < 0) {
      bigness = 2 * curbuf->b_ml.ml_line_count;
    }

    p_window = (int)bigness;
    if (*kind == '=') {
      bigness += 2;
    }
  }

  // the number of '-' and '+' multiplies the distance
  if (*kind == '-' || *kind == '+') {
    for (x = kind + 1; *x == *kind; x++) {}
  }

  switch (*kind) {
  case '-':
    start = lnum - (linenr_T)bigness * (linenr_T)(x - kind) + 1;
    end = start + (linenr_T)bigness - 1;
    curs = end;
    break;

  case '=':
    start = lnum - ((linenr_T)bigness + 1) / 2 + 1;
    end = lnum + ((linenr_T)bigness + 1) / 2 - 1;
    curs = lnum;
    minus = 1;
    break;

  case '^':
    start = lnum - (linenr_T)bigness * 2;
    end = lnum - (linenr_T)bigness;
    curs = lnum - (linenr_T)bigness;
    break;

  case '.':
    start = lnum - ((linenr_T)bigness + 1) / 2 + 1;
    end = lnum + ((linenr_T)bigness + 1) / 2 - 1;
    curs = end;
    break;

  default:        // '+'
    start = lnum;
    if (*kind == '+') {
      start += (linenr_T)bigness * (linenr_T)(x - kind - 1) + 1;
    } else if (eap->addr_count == 0) {
      start++;
    }
    end = start + (linenr_T)bigness - 1;
    curs = end;
    break;
  }

  start = MAX(start, 1);
  end = MIN(end, curbuf->b_ml.ml_line_count);
  curs = MIN(MAX(curs, 1), curbuf->b_ml.ml_line_count);

  for (linenr_T i = start; i <= end; i++) {
    if (minus && i == lnum) {
      msg_putchar('\n');

      for (int j = 1; j < Columns; j++) {
        msg_putchar('-');
      }
    }

    print_line(i, eap->flags & EXFLAG_NR, eap->flags & EXFLAG_LIST);

    if (minus && i == lnum) {
      msg_putchar('\n');

      for (int j = 1; j < Columns; j++) {
        msg_putchar('-');
      }
    }
  }

  if (curwin->w_cursor.lnum != curs) {
    curwin->w_cursor.lnum = curs;
    curwin->w_cursor.col = 0;
  }
  ex_no_reprint = true;
}

/// @return  true if the secure flag is set and also give an error message.
///          Otherwise, return false.
bool check_secure(void)
{
  if (secure) {
    secure = 2;
    emsg(_(e_curdir));
    return true;
  }

  // In the sandbox more things are not allowed, including the things
  // disallowed in secure mode.
  if (sandbox != 0) {
    emsg(_(e_sandbox));
    return true;
  }
  return false;
}

/// Previous substitute replacement string
static SubReplacementString old_sub = { NULL, 0, NULL };

static int global_need_beginline;       // call beginline() after ":g"

/// Get old substitute replacement string
///
/// @param[out]  ret_sub    Location where old string will be saved.
void sub_get_replacement(SubReplacementString *const ret_sub)
  FUNC_ATTR_NONNULL_ALL
{
  *ret_sub = old_sub;
}

/// Set substitute string and timestamp
///
/// @warning `sub` must be in allocated memory. It is not copied.
///
/// @param[in]  sub  New replacement string.
void sub_set_replacement(SubReplacementString sub)
{
  xfree(old_sub.sub);
  if (sub.additional_data != old_sub.additional_data) {
    xfree(old_sub.additional_data);
  }
  old_sub = sub;
}

/// Recognize ":%s/\n//" and turn it into a join command, which is much
/// more efficient.
///
/// @param[in]  eap  Ex arguments
/// @param[in]  pat  Search pattern
/// @param[in]  sub  Replacement string
/// @param[in]  cmd  Command from :s_flags
/// @param[in]  save Save pattern to options, history
///
/// @returns true if :substitute can be replaced with a join command
static bool sub_joining_lines(exarg_T *eap, char *pat, size_t patlen, const char *sub,
                              const char *cmd, bool save, bool keeppatterns)
  FUNC_ATTR_NONNULL_ARG(1, 4, 5)
{
  // TODO(vim): find a generic solution to make line-joining operations more
  // efficient, avoid allocating a string that grows in size.
  if (pat != NULL
      && strcmp(pat, "\\n") == 0
      && *sub == NUL
      && (*cmd == NUL || (cmd[1] == NUL
                          && (*cmd == 'g'
                              || *cmd == 'l'
                              || *cmd == 'p'
                              || *cmd == '#')))) {
    if (eap->skip) {
      return true;
    }
    curwin->w_cursor.lnum = eap->line1;
    if (*cmd == 'l') {
      eap->flags = EXFLAG_LIST;
    } else if (*cmd == '#') {
      eap->flags = EXFLAG_NR;
    } else if (*cmd == 'p') {
      eap->flags = EXFLAG_PRINT;
    }

    // The number of lines joined is the number of lines in the range
    linenr_T joined_lines_count = eap->line2 - eap->line1 + 1
                                  // plus one extra line if not at the end of file.
                                  + (eap->line2 < curbuf->b_ml.ml_line_count ? 1 : 0);
    if (joined_lines_count > 1) {
      do_join((size_t)joined_lines_count, false, true, false, true);
      sub_nsubs = joined_lines_count - 1;
      sub_nlines = 1;
      do_sub_msg(false);
      ex_may_print(eap);
    }

    if (save) {
      if (!keeppatterns) {
        save_re_pat(RE_SUBST, pat, patlen, magic_isset());
      }
      // put pattern in history
      add_to_history(HIST_SEARCH, pat, patlen, true, NUL);
    }

    return true;
  }

  return false;
}

/// Allocate memory to store the replacement text for :substitute.
///
/// Slightly more memory that is strictly necessary is allocated to reduce the
/// frequency of memory (re)allocation.
///
/// @param[in,out]  new_start      pointer to the memory for the replacement text
/// @param[in,out]  new_start_len  pointer to length of new_start
/// @param[in]      needed_len     amount of memory needed
///
/// @returns pointer to the end of the allocated memory
static char *sub_grow_buf(char **new_start, int *new_start_len, int needed_len)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  char *new_end;
  if (*new_start == NULL) {
    // Get some space for a temporary buffer to do the
    // substitution into (and some extra space to avoid
    // too many calls to xmalloc()/free()).
    *new_start_len = needed_len + 50;
    *new_start = xcalloc(1, (size_t)(*new_start_len));
    **new_start = NUL;
    new_end = *new_start;
  } else {
    // Check if the temporary buffer is long enough to do the
    // substitution into.  If not, make it larger (with a bit
    // extra to avoid too many calls to xmalloc()/free()).
    size_t len = strlen(*new_start);
    needed_len += (int)len;
    if (needed_len > *new_start_len) {
      size_t prev_new_start_len = (size_t)(*new_start_len);
      *new_start_len = needed_len + 50;
      size_t added_len = (size_t)(*new_start_len) - prev_new_start_len;
      *new_start = xrealloc(*new_start, (size_t)(*new_start_len));
      memset(*new_start + prev_new_start_len, 0, added_len);
    }
    new_end = *new_start + len;
  }

  return new_end;
}

/// Parse cmd string for :substitute's {flags} and update subflags accordingly
///
/// @param[in]      cmd  command string
/// @param[in,out]  subflags  current flags defined for the :substitute command
/// @param[in,out]  which_pat  pattern type from which to get default search
///
/// @returns pointer to the end of the flags, which may be the end of the string
static char *sub_parse_flags(char *cmd, subflags_T *subflags, int *which_pat)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  // Find trailing options.  When '&' is used, keep old options.
  if (*cmd == '&') {
    cmd++;
  } else {
    subflags->do_all = p_gd;
    subflags->do_ask = false;
    subflags->do_error = true;
    subflags->do_print = false;
    subflags->do_list = false;
    subflags->do_count = false;
    subflags->do_number = false;
    subflags->do_ic = kSubHonorOptions;
  }
  while (*cmd) {
    // Note that 'g' and 'c' are always inverted.
    // 'r' is never inverted.
    if (*cmd == 'g') {
      subflags->do_all = !subflags->do_all;
    } else if (*cmd == 'c') {
      subflags->do_ask = !subflags->do_ask;
    } else if (*cmd == 'n') {
      subflags->do_count = true;
    } else if (*cmd == 'e') {
      subflags->do_error = !subflags->do_error;
    } else if (*cmd == 'r') {  // use last used regexp
      *which_pat = RE_LAST;
    } else if (*cmd == 'p') {
      subflags->do_print = true;
    } else if (*cmd == '#') {
      subflags->do_print = true;
      subflags->do_number = true;
    } else if (*cmd == 'l') {
      subflags->do_print = true;
      subflags->do_list = true;
    } else if (*cmd == 'i') {  // ignore case
      subflags->do_ic = kSubIgnoreCase;
    } else if (*cmd == 'I') {  // don't ignore case
      subflags->do_ic = kSubMatchCase;
    } else {
      break;
    }
    cmd++;
  }
  if (subflags->do_count) {
    subflags->do_ask = false;
  }

  return cmd;
}

/// Skip over the "sub" part in :s/pat/sub/ where "delimiter" is the separating
/// character.
static char *skip_substitute(char *start, int delimiter)
{
  char *p = start;

  while (p[0]) {
    if (p[0] == delimiter) {  // end delimiter found
      *p++ = NUL;  // replace it with a NUL
      break;
    }
    if (p[0] == '\\' && p[1] != 0) {  // skip escaped characters
      p++;
    }
    MB_PTR_ADV(p);
  }
  return p;
}

static int check_regexp_delim(int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (isalpha(c)) {
    emsg(_("E146: Regular expressions can't be delimited by letters"));
    return FAIL;
  }
  return OK;
}

/// Perform a substitution from line eap->line1 to line eap->line2 using the
/// command pointed to by eap->arg which should be of the form:
///
/// /pattern/substitution/{flags}
///
/// The usual escapes are supported as described in the regexp docs.
///
/// @param cmdpreview_ns  The namespace to show 'inccommand' preview highlights.
///                       If <= 0, preview shouldn't be shown.
/// @return  0, 1 or 2. See cmdpreview_may_show() for more information on the meaning.
static int do_sub(exarg_T *eap, const proftime_T timeout, const int cmdpreview_ns,
                  const handle_T cmdpreview_bufnr)
{
#define ADJUST_SUB_FIRSTLNUM() \
  do { \
    /* For a multi-line match, make a copy of the last matched */ \
    /* line and continue in that one. */ \
    if (nmatch > 1) { \
      sub_firstlnum += (linenr_T)nmatch - 1; \
      xfree(sub_firstline); \
      sub_firstline = xstrnsave(ml_get(sub_firstlnum), \
                                (size_t)ml_get_len(sub_firstlnum)); \
      /* When going beyond the last line, stop substituting. */ \
      if (sub_firstlnum <= line2) { \
        do_again = true; \
      } else { \
        subflags.do_all = false; \
      } \
    } \
    if (skip_match) { \
      /* Already hit end of the buffer, sub_firstlnum is one */ \
      /* less than what it ought to be. */ \
      xfree(sub_firstline); \
      sub_firstline = xstrdup(""); \
      copycol = 0; \
    } \
  } while (0)

  int i = 0;
  regmmatch_T regmatch;
  static subflags_T subflags = {
    .do_all = false,
    .do_ask = false,
    .do_count = false,
    .do_error = true,
    .do_print = false,
    .do_list = false,
    .do_number = false,
    .do_ic = kSubHonorOptions
  };
  char *pat = NULL;
  char *sub = NULL;  // init for GCC
  size_t patlen = 0;
  int delimiter;
  bool has_second_delim = false;
  int sublen;
  bool got_quit = false;
  bool got_match = false;
  int which_pat;
  char *cmd = eap->arg;
  linenr_T first_line = 0;  // first changed line
  linenr_T last_line = 0;    // below last changed line AFTER the change
  linenr_T old_line_count = curbuf->b_ml.ml_line_count;
  char *sub_firstline;    // allocated copy of first sub line
  bool endcolumn = false;   // cursor in last column when done
  const bool keeppatterns = cmdmod.cmod_flags & CMOD_KEEPPATTERNS;
  PreviewLines preview_lines = { KV_INITIAL_VALUE, 0 };
  static int pre_hl_id = 0;
  pos_T old_cursor = curwin->w_cursor;
  int start_nsubs;

  bool did_save = false;

  if (!global_busy) {
    sub_nsubs = 0;
    sub_nlines = 0;
  }
  start_nsubs = sub_nsubs;

  if (eap->cmdidx == CMD_tilde) {
    which_pat = RE_LAST;        // use last used regexp
  } else {
    which_pat = RE_SUBST;       // use last substitute regexp
  }
  // new pattern and substitution
  if (eap->cmd[0] == 's' && *cmd != NUL && !ascii_iswhite(*cmd)
      && vim_strchr("0123456789cegriIp|\"", (uint8_t)(*cmd)) == NULL) {
    // don't accept alphanumeric for separator
    if (check_regexp_delim(*cmd) == FAIL) {
      return 0;
    }

    // undocumented vi feature:
    //  "\/sub/" and "\?sub?" use last used search pattern (almost like
    //  //sub/r).  "\&sub&" use last substitute pattern (like //sub/).
    if (*cmd == '\\') {
      cmd++;
      if (vim_strchr("/?&", (uint8_t)(*cmd)) == NULL) {
        emsg(_(e_backslash));
        return 0;
      }
      if (*cmd != '&') {
        which_pat = RE_SEARCH;              // use last '/' pattern
      }
      pat = "";                   // empty search pattern
      patlen = 0;
      delimiter = (uint8_t)(*cmd++);                   // remember delimiter character
      has_second_delim = true;
    } else {          // find the end of the regexp
      which_pat = RE_LAST;                  // use last used regexp
      delimiter = (uint8_t)(*cmd++);                   // remember delimiter character
      pat = cmd;                            // remember start of search pat
      cmd = skip_regexp_ex(cmd, delimiter, magic_isset(), &eap->arg, NULL, NULL);
      if (cmd[0] == delimiter) {            // end delimiter found
        *cmd++ = NUL;                       // replace it with a NUL
        has_second_delim = true;
      }
      patlen = strlen(pat);
    }

    // Small incompatibility: vi sees '\n' as end of the command, but in
    // Vim we want to use '\n' to find/substitute a NUL.
    char *p = cmd;  // remember the start of the substitution
    cmd = skip_substitute(cmd, delimiter);
    sub = xstrdup(p);

    if (!eap->skip && !keeppatterns && cmdpreview_ns <= 0) {
      sub_set_replacement((SubReplacementString) {
        .sub = xstrdup(sub),
        .timestamp = os_time(),
        .additional_data = NULL,
      });
    }
  } else if (!eap->skip) {    // use previous pattern and substitution
    if (old_sub.sub == NULL) {      // there is no previous command
      emsg(_(e_nopresub));
      return 0;
    }
    pat = NULL;                 // search_regcomp() will use previous pattern
    patlen = 0;
    sub = xstrdup(old_sub.sub);

    // Vi compatibility quirk: repeating with ":s" keeps the cursor in the
    // last column after using "$".
    endcolumn = (curwin->w_curswant == MAXCOL);
  }

  if (sub != NULL && sub_joining_lines(eap, pat, patlen, sub, cmd, cmdpreview_ns <= 0,
                                       keeppatterns)) {
    xfree(sub);
    return 0;
  }

  cmd = sub_parse_flags(cmd, &subflags, &which_pat);

  bool save_do_all = subflags.do_all;  // remember user specified 'g' flag
  bool save_do_ask = subflags.do_ask;  // remember user specified 'c' flag

  // check for a trailing count
  cmd = skipwhite(cmd);
  if (ascii_isdigit(*cmd)) {
    i = getdigits_int(&cmd, true, INT_MAX);
    if (i <= 0 && !eap->skip && subflags.do_error) {
      emsg(_(e_zerocount));
      xfree(sub);
      return 0;
    } else if (i >= INT_MAX) {
      char buf[20];
      vim_snprintf(buf, sizeof(buf), "%d", i);
      semsg(_(e_val_too_large), buf);
      xfree(sub);
      return 0;
    }
    eap->line1 = eap->line2;
    eap->line2 += (linenr_T)i - 1;
    eap->line2 = MIN(eap->line2, curbuf->b_ml.ml_line_count);
  }

  // check for trailing command or garbage
  cmd = skipwhite(cmd);
  if (*cmd && *cmd != '"') {        // if not end-of-line or comment
    eap->nextcmd = check_nextcmd(cmd);
    if (eap->nextcmd == NULL) {
      semsg(_(e_trailing_arg), cmd);
      xfree(sub);
      return 0;
    }
  }

  if (eap->skip) {          // not executing commands, only parsing
    xfree(sub);
    return 0;
  }

  if (!subflags.do_count && !MODIFIABLE(curbuf)) {
    // Substitution is not allowed in non-'modifiable' buffer
    emsg(_(e_modifiable));
    xfree(sub);
    return 0;
  }

  if (search_regcomp(pat, patlen, NULL, RE_SUBST, which_pat,
                     (cmdpreview_ns > 0 ? 0 : SEARCH_HIS), &regmatch) == FAIL) {
    if (subflags.do_error) {
      emsg(_(e_invcmd));
    }
    xfree(sub);
    return 0;
  }

  // the 'i' or 'I' flag overrules 'ignorecase' and 'smartcase'
  if (subflags.do_ic == kSubIgnoreCase) {
    regmatch.rmm_ic = true;
  } else if (subflags.do_ic == kSubMatchCase) {
    regmatch.rmm_ic = false;
  }

  sub_firstline = NULL;

  assert(sub != NULL);

  // If the substitute pattern starts with "\=" then it's an expression.
  // Make a copy, a recursive function may free it.
  // Otherwise, '~' in the substitute pattern is replaced with the old
  // pattern.  We do it here once to avoid it to be replaced over and over
  // again.
  if (sub[0] == '\\' && sub[1] == '=') {
    char *p = xstrdup(sub);
    xfree(sub);
    sub = p;
  } else {
    char *p = regtilde(sub, magic_isset(), cmdpreview_ns > 0);
    if (p != sub) {
      xfree(sub);
      sub = p;
    }
  }

  // Check for a match on each line.
  // If preview: limit to max('cmdwinheight', viewport).
  linenr_T line2 = eap->line2;

  for (linenr_T lnum = eap->line1;
       lnum <= line2 && !got_quit && !aborting()
       && (cmdpreview_ns <= 0 || preview_lines.lines_needed <= (linenr_T)p_cwh
           || lnum <= curwin->w_botline);
       lnum++) {
    int nmatch = vim_regexec_multi(&regmatch, curwin, curbuf, lnum,
                                   0, NULL, NULL);
    if (nmatch) {
      colnr_T copycol;
      colnr_T matchcol;
      colnr_T prev_matchcol = MAXCOL;
      char *new_end;
      char *new_start = NULL;
      int new_start_len = 0;
      char *p1;
      bool did_sub = false;
      int lastone;
      linenr_T nmatch_tl = 0;               // nr of lines matched below lnum
      int do_again;                     // do it again after joining lines
      bool skip_match = false;
      linenr_T sub_firstlnum;           // nr of first sub line

      // The new text is build up step by step, to avoid too much
      // copying.  There are these pieces:
      // sub_firstline  The old text, unmodified.
      // copycol                Column in the old text where we started
      //                        looking for a match; from here old text still
      //                        needs to be copied to the new text.
      // matchcol               Column number of the old text where to look
      //                        for the next match.  It's just after the
      //                        previous match or one further.
      // prev_matchcol  Column just after the previous match (if any).
      //                        Mostly equal to matchcol, except for the first
      //                        match and after skipping an empty match.
      // regmatch.*pos  Where the pattern matched in the old text.
      // new_start      The new text, all that has been produced so
      //                        far.
      // new_end                The new text, where to append new text.
      //
      // lnum           The line number where we found the start of
      //                        the match.  Can be below the line we searched
      //                        when there is a \n before a \zs in the
      //                        pattern.
      // sub_firstlnum  The line number in the buffer where to look
      //                        for a match.  Can be different from "lnum"
      //                        when the pattern or substitute string contains
      //                        line breaks.
      //
      // Special situations:
      // - When the substitute string contains a line break, the part up
      //   to the line break is inserted in the text, but the copy of
      //   the original line is kept.  "sub_firstlnum" is adjusted for
      //   the inserted lines.
      // - When the matched pattern contains a line break, the old line
      //   is taken from the line at the end of the pattern.  The lines
      //   in the match are deleted later, "sub_firstlnum" is adjusted
      //   accordingly.
      //
      // The new text is built up in new_start[].  It has some extra
      // room to avoid using xmalloc()/free() too often.  new_start_len is
      // the length of the allocated memory at new_start.
      //
      // Make a copy of the old line, so it won't be taken away when
      // updating the screen or handling a multi-line match.  The "old_"
      // pointers point into this copy.
      sub_firstlnum = lnum;
      copycol = 0;
      matchcol = 0;

      // At first match, remember current cursor position.
      if (!got_match) {
        setpcmark();
        got_match = true;
      }

      // Loop until nothing more to replace in this line.
      // 1. Handle match with empty string.
      // 2. If subflags.do_ask is set, ask for confirmation.
      // 3. substitute the string.
      // 4. if subflags.do_all is set, find next match
      // 5. break if there isn't another match in this line
      while (true) {
        SubResult current_match = {
          .start = { 0, 0 },
          .end = { 0, 0 },
          .pre_match = 0,
        };
        // lnum is where the match start, but maybe not the pattern match,
        // since we can have \n before \zs in the pattern

        // Advance "lnum" to the line where the match starts.  The
        // match does not start in the first line when there is a line
        // break before \zs.
        if (regmatch.startpos[0].lnum > 0) {
          current_match.pre_match = lnum;
          lnum += regmatch.startpos[0].lnum;
          sub_firstlnum += regmatch.startpos[0].lnum;
          nmatch -= regmatch.startpos[0].lnum;
          XFREE_CLEAR(sub_firstline);
        }

        // Now we're at the line where the pattern match starts
        // Note: If not first match on a line, column can't be known here
        current_match.start.lnum = sub_firstlnum;

        // Match might be after the last line for "\n\zs" matching at
        // the end of the last line.
        if (lnum > curbuf->b_ml.ml_line_count) {
          break;
        }
        if (sub_firstline == NULL) {
          sub_firstline = xstrnsave(ml_get(sub_firstlnum),
                                    (size_t)ml_get_len(sub_firstlnum));
        }

        // Save the line number of the last change for the final
        // cursor position (just like Vi).
        curwin->w_cursor.lnum = lnum;
        do_again = false;

        // 1. Match empty string does not count, except for first
        // match.  This reproduces the strange vi behaviour.
        // This also catches endless loops.
        if (matchcol == prev_matchcol
            && regmatch.endpos[0].lnum == 0
            && matchcol == regmatch.endpos[0].col) {
          if (sub_firstline[matchcol] == NUL) {
            // We already were at the end of the line.  Don't look
            // for a match in this line again.
            skip_match = true;
          } else {
            // search for a match at next column
            matchcol += utfc_ptr2len(sub_firstline + matchcol);
          }
          // match will be pushed to preview_lines, bring it into a proper state
          current_match.start.col = matchcol;
          current_match.end.lnum = sub_firstlnum;
          current_match.end.col = matchcol;
          goto skip;
        }

        // Normally we continue searching for a match just after the
        // previous match.
        matchcol = regmatch.endpos[0].col;
        prev_matchcol = matchcol;

        // 2. If subflags.do_count is set only increase the counter.
        //    If do_ask is set, ask for confirmation.
        if (subflags.do_count) {
          // For a multi-line match, put matchcol at the NUL at
          // the end of the line and set nmatch to one, so that
          // we continue looking for a match on the next line.
          // Avoids that ":s/\nB\@=//gc" get stuck.
          if (nmatch > 1) {
            matchcol = (colnr_T)strlen(sub_firstline);
            nmatch = 1;
            skip_match = true;
          }
          sub_nsubs++;
          did_sub = true;
          // Skip the substitution, unless an expression is used,
          // then it is evaluated in the sandbox.
          if (!(sub[0] == '\\' && sub[1] == '=')) {
            goto skip;
          }
        }

        if (subflags.do_ask && cmdpreview_ns <= 0) {
          int typed = 0;

          // change State to MODE_CONFIRM, so that the mouse works
          // properly
          int save_State = State;
          State = MODE_CONFIRM;
          setmouse();                   // disable mouse in xterm
          curwin->w_cursor.col = regmatch.startpos[0].col;

          if (curwin->w_p_crb) {
            do_check_cursorbind();
          }

          // When 'cpoptions' contains "u" don't sync undo when
          // asking for confirmation.
          if (vim_strchr(p_cpo, CPO_UNDO) != NULL) {
            no_u_sync++;
          }

          // Loop until 'y', 'n', 'q', CTRL-E or CTRL-Y typed.
          while (subflags.do_ask) {
            if (exmode_active) {
              print_line_no_prefix(lnum, subflags.do_number, subflags.do_list);

              colnr_T sc, ec;
              getvcol(curwin, &curwin->w_cursor, &sc, NULL, NULL);
              curwin->w_cursor.col = MAX(regmatch.endpos[0].col - 1, 0);

              getvcol(curwin, &curwin->w_cursor, NULL, NULL, &ec);
              curwin->w_cursor.col = regmatch.startpos[0].col;
              if (subflags.do_number || curwin->w_p_nu) {
                int numw = number_width(curwin) + 1;
                sc += numw;
                ec += numw;
              }

              char *prompt = xmallocz((size_t)ec + 1);
              memset(prompt, ' ', (size_t)sc);
              memset(prompt + sc, '^', (size_t)(ec - sc) + 1);
              char *resp = getcmdline_prompt(-1, prompt, 0, EXPAND_NOTHING, NULL,
                                             CALLBACK_NONE, false, NULL);
              msg_putchar('\n');
              xfree(prompt);
              if (resp != NULL) {
                typed = (uint8_t)(*resp);
                xfree(resp);
              } else {
                // getcmdline_prompt() returns NULL if there is no command line to return.
                typed = NUL;
              }
              // When ":normal" runs out of characters we get
              // an empty line.  Use "q" to get out of the
              // loop.
              if (ex_normal_busy && typed == NUL) {
                typed = 'q';
              }
            } else {
              char *orig_line = NULL;
              int len_change = 0;
              const bool save_p_lz = p_lz;
              int save_p_fen = curwin->w_p_fen;

              curwin->w_p_fen = false;
              // Invert the matched string.
              // Remove the inversion afterwards.
              int temp = RedrawingDisabled;
              RedrawingDisabled = 0;

              // avoid calling update_screen() in vgetorpeek()
              p_lz = false;

              if (new_start != NULL) {
                // There already was a substitution, we would
                // like to show this to the user.  We cannot
                // really update the line, it would change
                // what matches.  Temporarily replace the line
                // and change it back afterwards.
                orig_line = xstrnsave(ml_get(lnum), (size_t)ml_get_len(lnum));
                char *new_line = concat_str(new_start, sub_firstline + copycol);

                // Position the cursor relative to the end of the line, the
                // previous substitute may have inserted or deleted characters
                // before the cursor.
                len_change = (int)strlen(new_line) - (int)strlen(orig_line);
                curwin->w_cursor.col += len_change;
                ml_replace(lnum, new_line, false);
              }

              search_match_lines = regmatch.endpos[0].lnum
                                   - regmatch.startpos[0].lnum;
              search_match_endcol = regmatch.endpos[0].col
                                    + len_change;
              if (search_match_lines == 0 && search_match_endcol == 0) {
                // highlight at least one character for /^/
                search_match_endcol = 1;
              }
              highlight_match = true;

              update_topline(curwin);
              validate_cursor(curwin);
              redraw_later(curwin, UPD_SOME_VALID);
              show_cursor_info_later(true);
              update_screen();
              redraw_later(curwin, UPD_SOME_VALID);

              curwin->w_p_fen = save_p_fen;

              char *p = _("replace with %s? (y)es/(n)o/(a)ll/(q)uit/(l)ast/scroll up(^E)/down(^Y)");
              snprintf(IObuff, IOSIZE, p, sub);
              p = xstrdup(IObuff);
              typed = prompt_for_input(p, HLF_R, true, NULL);
              highlight_match = false;
              xfree(p);

              msg_didout = false;                 // don't scroll up
              gotocmdline(true);
              p_lz = save_p_lz;
              RedrawingDisabled = temp;

              // restore the line
              if (orig_line != NULL) {
                ml_replace(lnum, orig_line, false);
              }
            }

            need_wait_return = false;             // no hit-return prompt
            if (typed == 'q' || typed == ESC || typed == Ctrl_C) {
              got_quit = true;
              break;
            }
            if (typed == 'n') {
              break;
            }
            if (typed == 'y') {
              break;
            }
            if (typed == 'l') {
              // last: replace and then stop
              subflags.do_all = false;
              line2 = lnum;
              break;
            }
            if (typed == 'a') {
              subflags.do_ask = false;
              break;
            }
            if (typed == Ctrl_E) {
              scrollup_clamp();
            } else if (typed == Ctrl_Y) {
              scrolldown_clamp();
            }
          }
          State = save_State;
          setmouse();
          if (vim_strchr(p_cpo, CPO_UNDO) != NULL) {
            no_u_sync--;
          }

          if (typed == 'n') {
            // For a multi-line match, put matchcol at the NUL at
            // the end of the line and set nmatch to one, so that
            // we continue looking for a match on the next line.
            // Avoids that ":%s/\nB\@=//gc" and ":%s/\n/,\r/gc"
            // get stuck when pressing 'n'.
            if (nmatch > 1) {
              matchcol = (colnr_T)strlen(sub_firstline);
              skip_match = true;
            }
            goto skip;
          }
          if (got_quit) {
            goto skip;
          }
        }

        // Move the cursor to the start of the match, so that we can
        // use "\=col(".").
        curwin->w_cursor.col = regmatch.startpos[0].col;

        // When the match included the "$" of the last line it may
        // go beyond the last line of the buffer.
        if (nmatch > curbuf->b_ml.ml_line_count - sub_firstlnum + 1) {
          nmatch = curbuf->b_ml.ml_line_count - sub_firstlnum + 1;
          current_match.end.lnum = sub_firstlnum + (linenr_T)nmatch;
          skip_match = true;
          // safety check
          if (nmatch < 0) {
            goto skip;
          }
        }

        // Save the line numbers for the preview buffer
        // NOTE: If the pattern matches a final newline, the next line will
        // be shown also, but should not be highlighted. Intentional for now.
        if (cmdpreview_ns > 0 && !has_second_delim) {
          current_match.start.col = regmatch.startpos[0].col;
          if (current_match.end.lnum == 0) {
            current_match.end.lnum = sub_firstlnum + (linenr_T)nmatch - 1;
          }
          current_match.end.col = regmatch.endpos[0].col;

          ADJUST_SUB_FIRSTLNUM();
          lnum += (linenr_T)nmatch - 1;

          goto skip;
        }

        // 3. Substitute the string. During 'inccommand' preview only do this if
        //    there is a replace pattern.
        if (cmdpreview_ns <= 0 || has_second_delim) {
          linenr_T lnum_start = lnum;  // save the start lnum
          int save_ma = curbuf->b_p_ma;
          int save_sandbox = sandbox;
          if (subflags.do_count) {
            // prevent accidentally changing the buffer by a function
            curbuf->b_p_ma = false;
            sandbox++;
          }
          // Save flags for recursion.  They can change for e.g.
          // :s/^/\=execute("s#^##gn")
          subflags_T subflags_save = subflags;

          // Disallow changing text or switching window in an expression.
          textlock++;
          // Get length of substitution part, including the NUL.
          // When it fails sublen is zero.
          sublen = vim_regsub_multi(&regmatch,
                                    sub_firstlnum - regmatch.startpos[0].lnum,
                                    sub, sub_firstline, 0,
                                    REGSUB_BACKSLASH
                                    | (magic_isset() ? REGSUB_MAGIC : 0));
          textlock--;

          // If getting the substitute string caused an error, don't do
          // the replacement.
          // Don't keep flags set by a recursive call
          subflags = subflags_save;
          if (sublen == 0 || aborting() || subflags.do_count) {
            curbuf->b_p_ma = save_ma;
            sandbox = save_sandbox;
            goto skip;
          }

          // Need room for:
          // - result so far in new_start (not for first sub in line)
          // - original text up to match
          // - length of substituted part
          // - original text after match
          if (nmatch == 1) {
            p1 = sub_firstline;
          } else {
            p1 = ml_get(sub_firstlnum + (linenr_T)nmatch - 1);
            nmatch_tl += nmatch - 1;
          }
          int copy_len = regmatch.startpos[0].col - copycol;
          new_end = sub_grow_buf(&new_start, &new_start_len,
                                 (colnr_T)strlen(p1) - regmatch.endpos[0].col
                                 + copy_len + sublen + 1);

          // copy the text up to the part that matched
          memmove(new_end, sub_firstline + copycol, (size_t)copy_len);
          new_end += copy_len;

          if (new_start_len - copy_len < sublen) {
            sublen = new_start_len - copy_len - 1;
          }

          // Finally, at this point we can know where the match actually will
          // start in the new text
          int start_col = (int)(new_end - new_start);
          current_match.start.col = start_col;

          textlock++;
          vim_regsub_multi(&regmatch,
                           sub_firstlnum - regmatch.startpos[0].lnum,
                           sub, new_end, sublen,
                           REGSUB_COPY | REGSUB_BACKSLASH
                           | (magic_isset() ? REGSUB_MAGIC : 0));
          textlock--;
          sub_nsubs++;
          did_sub = true;

          // Move the cursor to the start of the line, to avoid that it
          // is beyond the end of the line after the substitution.
          curwin->w_cursor.col = 0;

          // Remember next character to be copied.
          copycol = regmatch.endpos[0].col;

          ADJUST_SUB_FIRSTLNUM();

          // TODO(bfredl): this has some robustness issues, look into later.
          bcount_t replaced_bytes = 0;
          lpos_T start = regmatch.startpos[0];
          lpos_T end = regmatch.endpos[0];
          for (i = 0; i < nmatch - 1; i++) {
            replaced_bytes += (bcount_t)strlen(ml_get((linenr_T)(lnum_start + i))) + 1;
          }
          replaced_bytes += end.col - start.col;

          // Now the trick is to replace CTRL-M chars with a real line
          // break.  This would make it impossible to insert a CTRL-M in
          // the text.  The line break can be avoided by preceding the
          // CTRL-M with a backslash.  To be able to insert a backslash,
          // they must be doubled in the string and are halved here.
          // That is Vi compatible.
          for (p1 = new_end; *p1; p1++) {
            if (p1[0] == '\\' && p1[1] != NUL) {            // remove backslash
              sublen--;  // correct the byte counts for extmark_splice()
              STRMOVE(p1, p1 + 1);
            } else if (*p1 == CAR) {
              if (u_inssub(lnum) == OK) {             // prepare for undo
                *p1 = NUL;                            // truncate up to the CR
                ml_append(lnum - 1, new_start,
                          (colnr_T)(p1 - new_start + 1), false);
                mark_adjust(lnum + 1, (linenr_T)MAXLNUM, 1, 0, kExtmarkNOOP);

                if (subflags.do_ask) {
                  appended_lines(lnum - 1, 1);
                } else {
                  if (first_line == 0) {
                    first_line = lnum;
                  }
                  last_line = lnum + 1;
                }
                // All line numbers increase.
                sub_firstlnum++;
                lnum++;
                line2++;
                // move the cursor to the new line, like Vi
                curwin->w_cursor.lnum++;
                // copy the rest
                STRMOVE(new_start, p1 + 1);
                p1 = new_start - 1;
              }
            } else {
              p1 += utfc_ptr2len(p1) - 1;
            }
          }
          colnr_T new_endcol = (colnr_T)strlen(new_start);
          current_match.end.col = new_endcol;
          current_match.end.lnum = lnum;

          int matchcols = end.col - ((end.lnum == start.lnum)
                                     ? start.col : 0);
          int subcols = new_endcol - ((lnum == lnum_start) ? start_col : 0);
          if (!did_save) {
            // Required for Undo to work for extmarks.
            u_save_cursor();
            did_save = true;
          }
          extmark_splice(curbuf, (int)lnum_start - 1, start_col,
                         end.lnum - start.lnum, matchcols, replaced_bytes,
                         lnum - lnum_start, subcols, sublen - 1, kExtmarkUndo);
        }

        // 4. If subflags.do_all is set, find next match.
        // Prevent endless loop with patterns that match empty
        // strings, e.g. :s/$/pat/g or :s/[a-z]* /(&)/g.
        // But ":s/\n/#/" is OK.
skip:
        // We already know that we did the last subst when we are at
        // the end of the line, except that a pattern like
        // "bar\|\nfoo" may match at the NUL.  "lnum" can be below
        // "line2" when there is a \zs in the pattern after a line
        // break.
        lastone = (skip_match
                   || got_int
                   || got_quit
                   || lnum > line2
                   || !(subflags.do_all || do_again)
                   || (sub_firstline[matchcol] == NUL && nmatch <= 1
                       && !re_multiline(regmatch.regprog)));
        nmatch = -1;

        // Replace the line in the buffer when needed.  This is
        // skipped when there are more matches.
        // The check for nmatch_tl is needed for when multi-line
        // matching must replace the lines before trying to do another
        // match, otherwise "\@<=" won't work.
        // When the match starts below where we start searching also
        // need to replace the line first (using \zs after \n).
        if (lastone
            || nmatch_tl > 0
            || (nmatch = vim_regexec_multi(&regmatch, curwin,
                                           curbuf, sub_firstlnum,
                                           matchcol, NULL, NULL)) == 0
            || regmatch.startpos[0].lnum > 0) {
          if (new_start != NULL) {
            // Copy the rest of the line, that didn't match.
            // "matchcol" has to be adjusted, we use the end of
            // the line as reference, because the substitute may
            // have changed the number of characters.  Same for
            // "prev_matchcol".
            strcat(new_start, sub_firstline + copycol);
            matchcol = (colnr_T)strlen(sub_firstline) - matchcol;
            prev_matchcol = (colnr_T)strlen(sub_firstline)
                            - prev_matchcol;

            if (u_savesub(lnum) != OK) {
              break;
            }
            ml_replace(lnum, new_start, true);

            if (nmatch_tl > 0) {
              // Matched lines have now been substituted and are
              // useless, delete them.  The part after the match
              // has been appended to new_start, we don't need
              // it in the buffer.
              lnum++;
              if (u_savedel(lnum, nmatch_tl) != OK) {
                break;
              }
              for (i = 0; i < nmatch_tl; i++) {
                ml_delete(lnum, false);
              }
              mark_adjust(lnum, lnum + nmatch_tl - 1, MAXLNUM, -nmatch_tl, kExtmarkNOOP);
              if (subflags.do_ask) {
                deleted_lines(lnum, nmatch_tl);
              }
              lnum--;
              line2 -= nmatch_tl;  // nr of lines decreases
              nmatch_tl = 0;
            }

            // When asking, undo is saved each time, must also set
            // changed flag each time.
            if (subflags.do_ask) {
              changed_bytes(lnum, 0);
            } else {
              if (first_line == 0) {
                first_line = lnum;
              }
              last_line = lnum + 1;
            }

            sub_firstlnum = lnum;
            xfree(sub_firstline);                // free the temp buffer
            sub_firstline = new_start;
            new_start = NULL;
            matchcol = (colnr_T)strlen(sub_firstline) - matchcol;
            prev_matchcol = (colnr_T)strlen(sub_firstline)
                            - prev_matchcol;
            copycol = 0;
          }
          if (nmatch == -1 && !lastone) {
            nmatch = vim_regexec_multi(&regmatch, curwin, curbuf,
                                       sub_firstlnum, matchcol, NULL, NULL);
          }

          // 5. break if there isn't another match in this line
          if (nmatch <= 0) {
            // If the match found didn't start where we were
            // searching, do the next search in the line where we
            // found the match.
            if (nmatch == -1) {
              lnum -= regmatch.startpos[0].lnum;
            }

            // uncrustify:off

#define PUSH_PREVIEW_LINES() \
  do { \
    if (cmdpreview_ns > 0) { \
      linenr_T match_lines = current_match.end.lnum \
                             - current_match.start.lnum +1; \
      if (preview_lines.subresults.size > 0) { \
        linenr_T last = kv_last(preview_lines.subresults).end.lnum; \
        if (last == current_match.start.lnum) { \
          preview_lines.lines_needed += match_lines - 1; \
        } else { \
          preview_lines.lines_needed += match_lines; \
        } \
      } else { \
        preview_lines.lines_needed += match_lines; \
      } \
      kv_push(preview_lines.subresults, current_match); \
    } \
  } while (0)

            // uncrustify:on

            // Push the match to preview_lines.
            PUSH_PREVIEW_LINES();

            break;
          }
        }
        // Push the match to preview_lines.
        PUSH_PREVIEW_LINES();

        line_breakcheck();
      }

      if (did_sub) {
        sub_nlines++;
      }
      xfree(new_start);              // for when substitute was cancelled
      XFREE_CLEAR(sub_firstline);    // free the copy of the original line
    }

    line_breakcheck();

    if (profile_passed_limit(timeout)) {
      got_quit = true;
    }
  }

  curbuf->deleted_bytes2 = 0;

  if (first_line != 0) {
    // Need to subtract the number of added lines from "last_line" to get
    // the line number before the change (same as adding the number of
    // deleted lines).
    i = curbuf->b_ml.ml_line_count - old_line_count;
    changed_lines(curbuf, first_line, 0, last_line - (linenr_T)i, (linenr_T)i, false);

    int64_t num_added = last_line - first_line;
    int64_t num_removed = num_added - i;
    buf_updates_send_changes(curbuf, first_line, num_added, num_removed);
  }

  xfree(sub_firstline);   // may have to free allocated copy of the line

  // ":s/pat//n" doesn't move the cursor
  if (subflags.do_count) {
    curwin->w_cursor = old_cursor;
  }

  if (sub_nsubs > start_nsubs) {
    if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
      // Set the '[ and '] marks.
      curbuf->b_op_start.lnum = eap->line1;
      curbuf->b_op_end.lnum = line2;
      curbuf->b_op_start.col = curbuf->b_op_end.col = 0;
    }

    if (!global_busy) {
      // when interactive leave cursor on the match
      if (!subflags.do_ask) {
        if (endcolumn) {
          coladvance(curwin, MAXCOL);
        } else {
          beginline(BL_WHITE | BL_FIX);
        }
      }
      if (cmdpreview_ns <= 0 && !do_sub_msg(subflags.do_count) && subflags.do_ask && p_ch > 0) {
        msg("", 0);
      }
    } else {
      global_need_beginline = true;
    }
    if (subflags.do_print) {
      print_line(curwin->w_cursor.lnum, subflags.do_number, subflags.do_list);
    }
  } else if (!global_busy) {
    if (got_int) {
      // interrupted
      emsg(_(e_interr));
    } else if (got_match) {
      // did find something but nothing substituted
      if (p_ch > 0) {
        msg("", 0);
      }
    } else if (subflags.do_error) {
      // nothing found
      semsg(_(e_patnotf2), get_search_pat());
    }
  }

  if (subflags.do_ask && hasAnyFolding(curwin)) {
    // Cursor position may require updating
    changed_window_setting(curwin);
  }

  vim_regfree(regmatch.regprog);
  xfree(sub);

  // Restore the flag values, they can be used for ":&&".
  subflags.do_all = save_do_all;
  subflags.do_ask = save_do_ask;

  int retv = 0;

  // Show 'inccommand' preview if there are matched lines.
  if (cmdpreview_ns > 0 && !aborting()) {
    if (got_quit || profile_passed_limit(timeout)) {  // Too slow, disable.
      set_option_direct(kOptInccommand, STATIC_CSTR_AS_OPTVAL(""), 0, SID_NONE);
    } else if (*p_icm != NUL && pat != NULL) {
      if (pre_hl_id == 0) {
        pre_hl_id = syn_check_group(S_LEN("Substitute"));
      }
      retv = show_sub(eap, old_cursor, &preview_lines, pre_hl_id, cmdpreview_ns, cmdpreview_bufnr);
    }
  }

  kv_destroy(preview_lines.subresults);
  return retv;
#undef ADJUST_SUB_FIRSTLNUM
#undef PUSH_PREVIEW_LINES
}

/// Give message for number of substitutions.
/// Can also be used after a ":global" command.
///
/// @param count_only  used 'n' flag for ":s"
///
/// @return            true if a message was given.
bool do_sub_msg(bool count_only)
{
  // Only report substitutions when:
  // - more than 'report' substitutions
  // - command was typed by user, or number of changed lines > 'report'
  // - giving messages is not disabled by 'lazyredraw'
  if (((sub_nsubs > p_report && (KeyTyped || sub_nlines > 1 || p_report < 1))
       || count_only)
      && messaging()) {
    if (got_int) {
      STRCPY(msg_buf, _("(Interrupted) "));
    } else {
      *msg_buf = NUL;
    }

    char *msg_single = count_only
                       ? NGETTEXT("%" PRId64 " match on %" PRId64 " line",
                                  "%" PRId64 " matches on %" PRId64 " line", sub_nsubs)
                       : NGETTEXT("%" PRId64 " substitution on %" PRId64 " line",
                                  "%" PRId64 " substitutions on %" PRId64 " line", sub_nsubs);
    char *msg_plural = count_only
                       ? NGETTEXT("%" PRId64 " match on %" PRId64 " lines",
                                  "%" PRId64 " matches on %" PRId64 " lines", sub_nsubs)
                       : NGETTEXT("%" PRId64 " substitution on %" PRId64 " lines",
                                  "%" PRId64 " substitutions on %" PRId64 " lines", sub_nsubs);
    vim_snprintf_add(msg_buf, sizeof(msg_buf),
                     NGETTEXT(msg_single, msg_plural, sub_nlines),
                     (int64_t)sub_nsubs, (int64_t)sub_nlines);
    if (msg(msg_buf, 0)) {
      // save message to display it after redraw
      set_keep_msg(msg_buf, 0);
    }
    return true;
  }
  if (got_int) {
    emsg(_(e_interr));
    return true;
  }
  return false;
}

static void global_exe_one(char *const cmd, const linenr_T lnum)
{
  curwin->w_cursor.lnum = lnum;
  curwin->w_cursor.col = 0;
  if (*cmd == NUL || *cmd == '\n') {
    do_cmdline("p", NULL, NULL, DOCMD_NOWAIT);
  } else {
    do_cmdline(cmd, NULL, NULL, DOCMD_NOWAIT);
  }
}

/// Execute a global command of the form:
///
/// g/pattern/X : execute X on all lines where pattern matches
/// v/pattern/X : execute X on all lines where pattern does not match
///
/// where 'X' is an EX command
///
/// The command character (as well as the trailing slash) is optional, and
/// is assumed to be 'p' if missing.
///
/// This is implemented in two passes: first we scan the file for the pattern and
/// set a mark for each line that (not) matches. Secondly we execute the command
/// for each line that has a mark. This is required because after deleting
/// lines we do not know where to search for the next match.
void ex_global(exarg_T *eap)
{
  linenr_T lnum;                // line number according to old situation
  int type;                     // first char of cmd: 'v' or 'g'
  char *cmd;                    // command argument

  char delim;                 // delimiter, normally '/'
  char *pat;
  size_t patlen;
  regmmatch_T regmatch;

  // When nesting the command works on one line.  This allows for
  // ":g/found/v/notfound/command".
  if (global_busy && (eap->line1 != 1
                      || eap->line2 != curbuf->b_ml.ml_line_count)) {
    // will increment global_busy to break out of the loop
    emsg(_("E147: Cannot do :global recursive with a range"));
    return;
  }

  if (eap->forceit) {               // ":global!" is like ":vglobal"
    type = 'v';
  } else {
    type = (uint8_t)(*eap->cmd);
  }
  cmd = eap->arg;
  int which_pat = RE_LAST;              // default: use last used regexp

  // undocumented vi feature:
  //    "\/" and "\?": use previous search pattern.
  //             "\&": use previous substitute pattern.
  if (*cmd == '\\') {
    cmd++;
    if (vim_strchr("/?&", (uint8_t)(*cmd)) == NULL) {
      emsg(_(e_backslash));
      return;
    }
    if (*cmd == '&') {
      which_pat = RE_SUBST;             // use previous substitute pattern
    } else {
      which_pat = RE_SEARCH;            // use previous search pattern
    }
    cmd++;
    pat = "";
    patlen = 0;
  } else if (*cmd == NUL) {
    emsg(_("E148: Regular expression missing from global"));
    return;
  } else if (check_regexp_delim(*cmd) == FAIL) {
    return;
  } else {
    delim = *cmd;               // get the delimiter
    cmd++;                      // skip delimiter if there is one
    pat = cmd;                  // remember start of pattern
    cmd = skip_regexp_ex(cmd, delim, magic_isset(), &eap->arg, NULL, NULL);
    if (cmd[0] == delim) {                  // end delimiter found
      *cmd++ = NUL;                         // replace it with a NUL
    }
    patlen = strlen(pat);
  }

  char *used_pat;
  if (search_regcomp(pat, patlen, &used_pat, RE_BOTH, which_pat,
                     SEARCH_HIS, &regmatch) == FAIL) {
    emsg(_(e_invcmd));
    return;
  }

  if (global_busy) {
    lnum = curwin->w_cursor.lnum;
    int match = vim_regexec_multi(&regmatch, curwin, curbuf, lnum, 0, NULL, NULL);
    if ((type == 'g' && match) || (type == 'v' && !match)) {
      global_exe_one(cmd, lnum);
    }
  } else {
    int ndone = 0;
    // pass 1: set marks for each (not) matching line
    for (lnum = eap->line1; lnum <= eap->line2 && !got_int; lnum++) {
      // a match on this line?
      int match = vim_regexec_multi(&regmatch, curwin, curbuf, lnum, 0, NULL, NULL);
      if (regmatch.regprog == NULL) {
        break;  // re-compiling regprog failed
      }
      if ((type == 'g' && match) || (type == 'v' && !match)) {
        ml_setmarked(lnum);
        ndone++;
      }
      line_breakcheck();
    }

    // pass 2: execute the command for each line that has been marked
    if (got_int) {
      msg(_(e_interr), 0);
    } else if (ndone == 0) {
      if (type == 'v') {
        smsg(0, _("Pattern found in every line: %s"), used_pat);
      } else {
        smsg(0, _("Pattern not found: %s"), used_pat);
      }
    } else {
      global_exe(cmd);
    }
    ml_clearmarked();         // clear rest of the marks
  }
  vim_regfree(regmatch.regprog);
}

/// Execute `cmd` on lines marked with ml_setmarked().
void global_exe(char *cmd)
{
  linenr_T old_lcount;      // b_ml.ml_line_count before the command
  buf_T *old_buf = curbuf;  // remember what buffer we started in
  linenr_T lnum;            // line number according to old situation

  // Set current position only once for a global command.
  // If global_busy is set, setpcmark() will not do anything.
  // If there is an error, global_busy will be incremented.
  setpcmark();

  // When the command writes a message, don't overwrite the command.
  msg_didout = true;

  sub_nsubs = 0;
  sub_nlines = 0;
  global_need_beginline = false;
  global_busy = 1;
  old_lcount = curbuf->b_ml.ml_line_count;

  while (!got_int && (lnum = ml_firstmarked()) != 0 && global_busy == 1) {
    global_exe_one(cmd, lnum);
    os_breakcheck();
  }

  global_busy = 0;
  if (global_need_beginline) {
    beginline(BL_WHITE | BL_FIX);
  } else {
    check_cursor(curwin);  // cursor may be beyond the end of the line
  }

  // the cursor may not have moved in the text but a change in a previous
  // line may move it on the screen
  changed_line_abv_curs();

  // If it looks like no message was written, allow overwriting the
  // command with the report for number of changes.
  if (msg_col == 0 && msg_scrolled == 0) {
    msg_didout = false;
  }

  // If substitutes done, report number of substitutes, otherwise report
  // number of extra or deleted lines.
  // Don't report extra or deleted lines in the edge case where the buffer
  // we are in after execution is different from the buffer we started in.
  if (!do_sub_msg(false) && curbuf == old_buf) {
    msgmore(curbuf->b_ml.ml_line_count - old_lcount);
  }
}

#if defined(EXITFREE)
void free_old_sub(void)
{
  sub_set_replacement((SubReplacementString) { NULL, 0, NULL });
}

#endif

/// Set up for a tagpreview.
///
/// @param undo_sync  sync undo when leaving the window
///
/// @return           true when it was created.
bool prepare_tagpreview(bool undo_sync)
{
  if (curwin->w_p_pvw) {
    return false;
  }

  // If there is already a preview window open, use that one.
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_p_pvw) {
      win_enter(wp, undo_sync);
      return false;
    }
  }

  // There is no preview window open yet.  Create one.
  if (win_split(g_do_tagpreview > 0 ? g_do_tagpreview : 0, 0)
      == FAIL) {
    return false;
  }
  curwin->w_p_pvw = true;
  curwin->w_p_wfh = true;
  RESET_BINDING(curwin);                // don't take over 'scrollbind' and 'cursorbind'
  curwin->w_p_diff = false;             // no 'diff'

  set_option_direct(kOptFoldcolumn, STATIC_CSTR_AS_OPTVAL("0"), 0, SID_NONE);  // no 'foldcolumn'
  return true;
}

/// Shows the effects of the :substitute command being typed ('inccommand').
/// If inccommand=split, shows a preview window and later restores the layout.
///
/// @return 1 if preview window isn't needed, 2 if preview window is needed.
static int show_sub(exarg_T *eap, pos_T old_cusr, PreviewLines *preview_lines, int hl_id,
                    int cmdpreview_ns, handle_T cmdpreview_bufnr)
  FUNC_ATTR_NONNULL_ALL
{
  char *save_shm_p = xstrdup(p_shm);
  PreviewLines lines = *preview_lines;
  buf_T *orig_buf = curbuf;
  // We keep a special-purpose buffer around, but don't assume it exists.
  buf_T *cmdpreview_buf = NULL;

  // disable file info message
  set_option_direct(kOptShortmess, STATIC_CSTR_AS_OPTVAL("F"), 0, SID_NONE);

  // Place cursor on nearest matching line, to undo do_sub() cursor placement.
  for (size_t i = 0; i < lines.subresults.size; i++) {
    SubResult curres = lines.subresults.items[i];
    if (curres.start.lnum >= old_cusr.lnum) {
      curwin->w_cursor.lnum = curres.start.lnum;
      curwin->w_cursor.col = curres.start.col;
      break;
    }  // Else: All matches are above, do_sub() already placed cursor.
  }

  // Update the topline to ensure that main window is on the correct line
  update_topline(curwin);

  // Width of the "| lnum|..." column which displays the line numbers.
  int col_width = 0;
  // Use preview window only when inccommand=split and range is not just the current line
  bool preview = (*p_icm == 's') && (eap->line1 != old_cusr.lnum || eap->line2 != old_cusr.lnum);

  if (preview) {
    cmdpreview_buf = buflist_findnr(cmdpreview_bufnr);
    assert(cmdpreview_buf != NULL);

    if (lines.subresults.size > 0) {
      SubResult last_match = kv_last(lines.subresults);
      // `last_match.end.lnum` may be 0 when using 'n' flag.
      linenr_T highest_lnum = MAX(last_match.start.lnum, last_match.end.lnum);
      assert(highest_lnum > 0);
      col_width = (int)log10(highest_lnum) + 1 + 3;
    }
  }

  char *str = NULL;  // construct the line to show in here
  colnr_T old_line_size = 0;
  colnr_T line_size = 0;
  linenr_T linenr_preview = 0;  // last line added to preview buffer
  linenr_T linenr_origbuf = 0;  // last line added to original buffer
  linenr_T next_linenr = 0;     // next line to show for the match

  for (size_t matchidx = 0; matchidx < lines.subresults.size; matchidx++) {
    SubResult match = lines.subresults.items[matchidx];

    if (cmdpreview_buf) {
      lpos_T p_start = { 0, match.start.col };  // match starts here in preview
      lpos_T p_end = { 0, match.end.col };    // ... and ends here

      // You Might Gonna Need It
      buf_ensure_loaded(cmdpreview_buf);

      if (match.pre_match == 0) {
        next_linenr = match.start.lnum;
      } else {
        next_linenr = match.pre_match;
      }
      // Don't add a line twice
      if (next_linenr == linenr_origbuf) {
        next_linenr++;
        p_start.lnum = linenr_preview;  // might be redefined below
        p_end.lnum = linenr_preview;  // might be redefined below
      }

      for (; next_linenr <= match.end.lnum; next_linenr++) {
        if (next_linenr == match.start.lnum) {
          p_start.lnum = linenr_preview + 1;
        }
        if (next_linenr == match.end.lnum) {
          p_end.lnum = linenr_preview + 1;
        }
        char *line;
        if (next_linenr == orig_buf->b_ml.ml_line_count + 1) {
          line = "";
        } else {
          line = ml_get_buf(orig_buf, next_linenr);
          line_size = ml_get_buf_len(orig_buf, next_linenr) + col_width + 1;

          // Reallocate if line not long enough
          if (line_size > old_line_size) {
            str = xrealloc(str, (size_t)line_size * sizeof(char));
            old_line_size = line_size;
          }
        }
        // Put "|lnum| line" into `str` and append it to the preview buffer.
        snprintf(str, (size_t)line_size, "|%*" PRIdLINENR "| %s", col_width - 3,
                 next_linenr, line);
        if (linenr_preview == 0) {
          ml_replace_buf(cmdpreview_buf, 1, str, true, false);
        } else {
          ml_append_buf(cmdpreview_buf, linenr_preview, str, line_size, false);
        }
        linenr_preview += 1;
      }
      linenr_origbuf = match.end.lnum;

      bufhl_add_hl_pos_offset(cmdpreview_buf, cmdpreview_ns, hl_id, p_start, p_end, col_width);
    }
    bufhl_add_hl_pos_offset(orig_buf, cmdpreview_ns, hl_id, match.start, match.end, 0);
  }

  xfree(str);

  set_option_direct(kOptShortmess, CSTR_AS_OPTVAL(save_shm_p), 0, SID_NONE);
  xfree(save_shm_p);

  return preview ? 2 : 1;
}

/// :substitute command.
void ex_substitute(exarg_T *eap)
{
  do_sub(eap, profile_zero(), 0, 0);
}

/// :substitute command preview callback.
int ex_substitute_preview(exarg_T *eap, int cmdpreview_ns, handle_T cmdpreview_bufnr)
{
  // Only preview once the pattern delimiter has been typed
  if (*eap->arg && !ASCII_ISALNUM(*eap->arg)) {
    char *save_eap = eap->arg;
    int retv = do_sub(eap, profile_setlimit(p_rdt), cmdpreview_ns, cmdpreview_bufnr);
    eap->arg = save_eap;
    return retv;
  }

  return 0;
}

/// Skip over the pattern argument of ":vimgrep /pat/[g][j]".
/// Put the start of the pattern in "*s", unless "s" is NULL.
///
/// @param flags  if not NULL, put the flags in it: VGR_GLOBAL, VGR_NOJUMP.
/// @param s      if not NULL, terminate the pattern with a NUL.
///
/// @return  a pointer to the char just past the pattern plus flags.
char *skip_vimgrep_pat(char *p, char **s, int *flags)
{
  if (vim_isIDc((uint8_t)(*p))) {
    // ":vimgrep pattern fname"
    if (s != NULL) {
      *s = p;
    }
    p = skiptowhite(p);
    if (s != NULL && *p != NUL) {
      *p++ = NUL;
    }
  } else {
    // ":vimgrep /pattern/[g][j] fname"
    if (s != NULL) {
      *s = p + 1;
    }
    int c = (uint8_t)(*p);
    p = skip_regexp(p + 1, c, true);
    if (*p != c) {
      return NULL;
    }

    // Truncate the pattern.
    if (s != NULL) {
      *p = NUL;
    }
    p++;

    // Find the flags
    while (*p == 'g' || *p == 'j' || *p == 'f') {
      if (flags != NULL) {
        if (*p == 'g') {
          *flags |= VGR_GLOBAL;
        } else if (*p == 'j') {
          *flags |= VGR_NOJUMP;
        } else {
          *flags |= VGR_FUZZY;
        }
      }
      p++;
    }
  }
  return p;
}

/// List v:oldfiles in a nice way.
void ex_oldfiles(exarg_T *eap)
{
  list_T *l = get_vim_var_list(VV_OLDFILES);
  int nr = 0;

  if (l == NULL) {
    msg(_("No old files"), 0);
    return;
  }

  msg_start();
  msg_scroll = true;
  TV_LIST_ITER(l, li, {
    if (got_int) {
      break;
    }
    nr++;
    const char *fname = tv_get_string(TV_LIST_ITEM_TV(li));
    if (!message_filtered(fname)) {
      msg_outnum(nr);
      msg_puts(": ");
      msg_outtrans(tv_get_string(TV_LIST_ITEM_TV(li)), 0, false);
      msg_clr_eos();
      msg_putchar('\n');
      os_breakcheck();
    }
  });

  // Assume "got_int" was set to truncate the listing.
  got_int = false;

  // File selection prompt on ":browse oldfiles"
  if (cmdmod.cmod_flags & CMOD_BROWSE) {
    quit_more = false;
    nr = prompt_for_input(NULL, 0, false, NULL);
    msg_starthere();
    if (nr > 0 && nr <= tv_list_len(l)) {
      const char *const p = tv_list_find_str(l, nr - 1);
      if (p == NULL) {
        return;
      }
      char *const s = expand_env_save((char *)p);
      eap->arg = s;
      eap->cmdidx = CMD_edit;
      cmdmod.cmod_flags &= ~CMOD_BROWSE;
      do_exedit(eap, NULL);
      xfree(s);
    }
  }
}
