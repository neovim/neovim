// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * ex_cmds.c: some functions for command line commands
 */

#include <assert.h>
#include <float.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>
#include <inttypes.h>
#include <math.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/buffer.h"
#include "nvim/log.h"
#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/ex_cmds.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/digraph.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_getln.h"
#include "nvim/farsi.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/highlight.h"
#include "nvim/indent.h"
#include "nvim/buffer_updates.h"
#include "nvim/main.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/garray.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/mouse.h"
#include "nvim/normal.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/spell.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/tag.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/window.h"
#include "nvim/os/os.h"
#include "nvim/os/shell.h"
#include "nvim/os/input.h"
#include "nvim/os/time.h"

/*
 * Struct to hold the sign properties.
 */
typedef struct sign sign_T;

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
  linenr_T lines_needed;  // lines neede in the preview window
} PreviewLines;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_cmds.c.generated.h"
#endif

/// ":ascii" and "ga" implementation
void do_ascii(const exarg_T *const eap)
{
  int cc[MAX_MCO];
  int c = utfc_ptr2char(get_cursor_pos_ptr(), cc);
  if (c == NUL) {
    MSG("NUL");
    return;
  }

  size_t iobuff_len = 0;

  int ci = 0;
  if (c < 0x80) {
    if (c == NL) {  // NUL is stored as NL.
      c = NUL;
    }
    const int cval = (c == CAR && get_fileformat(curbuf) == EOL_MAC
                      ? NL  // NL is stored as CR.
                      : c);
    char buf1[20];
    if (vim_isprintc_strict(c) && (c < ' ' || c > '~')) {
      char_u buf3[7];
      transchar_nonprint(buf3, c);
      vim_snprintf(buf1, sizeof(buf1), "  <%s>", (char *)buf3);
    } else {
      buf1[0] = NUL;
    }
    char buf2[20];
    buf2[0] = NUL;
    iobuff_len += (
        vim_snprintf((char *)IObuff + iobuff_len, sizeof(IObuff) - iobuff_len,
                     _("<%s>%s%s  %d,  Hex %02x,  Octal %03o"),
                     transchar(c), buf1, buf2, cval, cval, cval));
    c = cc[ci++];
  }

#define SPACE_FOR_DESC (1 + 1 + 1 + MB_MAXBYTES + 16 + 4 + 3 + 3 + 1)
  // Space for description:
  // - 1 byte for separator (starting from second entry)
  // - 1 byte for "<"
  // - 1 byte for space to draw composing character on (optional, but really
  //   mostly required)
  // - up to MB_MAXBYTES bytes for character itself
  // - 16 bytes for raw text ("> , Hex , Octal ").
  // - at least 4 bytes for hexadecimal representation
  // - at least 3 bytes for decimal representation
  // - at least 3 bytes for octal representation
  // - 1 byte for NUL
  //
  // Taking into account MAX_MCO and characters which need 8 bytes for
  // hexadecimal representation, but not taking translation into account:
  // resulting string will occupy less then 400 bytes (conservative estimate).
  //
  // Less then 1000 bytes if translation multiplies number of bytes needed for
  // raw text by 6, so it should always fit into 1025 bytes reserved for IObuff.

  // Repeat for combining characters, also handle multiby here.
  while (c >= 0x80 && iobuff_len < sizeof(IObuff) - SPACE_FOR_DESC) {
    // This assumes every multi-byte char is printable...
    if (iobuff_len > 0) {
      IObuff[iobuff_len++] = ' ';
    }
    IObuff[iobuff_len++] = '<';
    if (utf_iscomposing(c)) {
      IObuff[iobuff_len++] = ' ';  // Draw composing char on top of a space.
    }
    iobuff_len += utf_char2bytes(c, IObuff + iobuff_len);
    iobuff_len += (
        vim_snprintf((char *)IObuff + iobuff_len, sizeof(IObuff) - iobuff_len,
                     (c < 0x10000
                      ? _("> %d, Hex %04x, Octal %o")
                      : _("> %d, Hex %08x, Octal %o")), c, c, c));
    if (ci == MAX_MCO) {
      break;
    }
    c = cc[ci++];
  }
  if (ci != MAX_MCO && c != 0) {
    xstrlcpy((char *)IObuff + iobuff_len, " ...", sizeof(IObuff) - iobuff_len);
  }

  msg(IObuff);
}

/*
 * ":left", ":center" and ":right": align text.
 */
void ex_align(exarg_T *eap)
{
  pos_T save_curpos;
  int len;
  int indent = 0;
  int new_indent;
  int has_tab;
  int width;

  if (curwin->w_p_rl) {
    /* switch left and right aligning */
    if (eap->cmdidx == CMD_right)
      eap->cmdidx = CMD_left;
    else if (eap->cmdidx == CMD_left)
      eap->cmdidx = CMD_right;
  }

  width = atoi((char *)eap->arg);
  save_curpos = curwin->w_cursor;
  if (eap->cmdidx == CMD_left) {    /* width is used for new indent */
    if (width >= 0)
      indent = width;
  } else {
    /*
     * if 'textwidth' set, use it
     * else if 'wrapmargin' set, use it
     * if invalid value, use 80
     */
    if (width <= 0)
      width = curbuf->b_p_tw;
    if (width == 0 && curbuf->b_p_wm > 0)
      width = curwin->w_width - curbuf->b_p_wm;
    if (width <= 0)
      width = 80;
  }

  if (u_save((linenr_T)(eap->line1 - 1), (linenr_T)(eap->line2 + 1)) == FAIL)
    return;

  for (curwin->w_cursor.lnum = eap->line1;
       curwin->w_cursor.lnum <= eap->line2; ++curwin->w_cursor.lnum) {
    if (eap->cmdidx == CMD_left)                /* left align */
      new_indent = indent;
    else {
      has_tab = FALSE;          /* avoid uninit warnings */
      len = linelen(eap->cmdidx == CMD_right ? &has_tab
          : NULL) - get_indent();

      if (len <= 0)                             /* skip blank lines */
        continue;

      if (eap->cmdidx == CMD_center)
        new_indent = (width - len) / 2;
      else {
        new_indent = width - len;               /* right align */

        /*
         * Make sure that embedded TABs don't make the text go too far
         * to the right.
         */
        if (has_tab)
          while (new_indent > 0) {
            (void)set_indent(new_indent, 0);
            if (linelen(NULL) <= width) {
              /*
               * Now try to move the line as much as possible to
               * the right.  Stop when it moves too far.
               */
              do
                (void)set_indent(++new_indent, 0);
              while (linelen(NULL) <= width);
              --new_indent;
              break;
            }
            --new_indent;
          }
      }
    }
    if (new_indent < 0)
      new_indent = 0;
    (void)set_indent(new_indent, 0);                    /* set indent */
  }
  changed_lines(eap->line1, 0, eap->line2 + 1, 0L, true);
  curwin->w_cursor = save_curpos;
  beginline(BL_WHITE | BL_FIX);
}

/*
 * Get the length of the current line, excluding trailing white space.
 */
static int linelen(int *has_tab)
{
  char_u  *line;
  char_u  *first;
  char_u  *last;
  int save;
  int len;

  /* find the first non-blank character */
  line = get_cursor_line_ptr();
  first = skipwhite(line);

  /* find the character after the last non-blank character */
  for (last = first + STRLEN(first);
       last > first && ascii_iswhite(last[-1]); --last)
    ;
  save = *last;
  *last = NUL;
  // Get line length.
  len = linetabsize(line);
  // Check for embedded TAB.
  if (has_tab != NULL) {
    *has_tab = STRRCHR(first, TAB) != NULL;
  }
  *last = save;

  return len;
}

/* Buffer for two lines used during sorting.  They are allocated to
 * contain the longest line being sorted. */
static char_u   *sortbuf1;
static char_u   *sortbuf2;

static int sort_ic;       ///< ignore case
static int sort_nr;       ///< sort on number
static int sort_rx;       ///< sort on regex instead of skipping it
static int sort_flt;      ///< sort on floating number

static int sort_abort;    ///< flag to indicate if sorting has been interrupted

/// Struct to store info to be sorted.
typedef struct {
  linenr_T lnum;          ///< line number
  union {
    struct {
      varnumber_T start_col_nr;  ///< starting column number
      varnumber_T end_col_nr;    ///< ending column number
    } line;
    varnumber_T value;           ///< value if sorting by integer
    float_T value_flt;    ///< value if sorting by float
  } st_u;
} sorti_T;


static int sort_compare(const void *s1, const void *s2)
{
  sorti_T l1 = *(sorti_T *)s1;
  sorti_T l2 = *(sorti_T *)s2;
  int result = 0;

  /* If the user interrupts, there's no way to stop qsort() immediately, but
   * if we return 0 every time, qsort will assume it's done sorting and
   * exit. */
  if (sort_abort)
    return 0;
  fast_breakcheck();
  if (got_int)
    sort_abort = TRUE;

  // When sorting numbers "start_col_nr" is the number, not the column
  // number.
  if (sort_nr) {
    result = l1.st_u.value == l2.st_u.value
             ? 0 : l1.st_u.value > l2.st_u.value
             ? 1 : -1;
  } else if (sort_flt) {
    result = l1.st_u.value_flt == l2.st_u.value_flt
             ? 0 : l1.st_u.value_flt > l2.st_u.value_flt
             ? 1 : -1;
  } else {
    // We need to copy one line into "sortbuf1", because there is no
    // guarantee that the first pointer becomes invalid when obtaining the
    // second one.
    memcpy(sortbuf1, ml_get(l1.lnum) + l1.st_u.line.start_col_nr,
           l1.st_u.line.end_col_nr - l1.st_u.line.start_col_nr + 1);
    sortbuf1[l1.st_u.line.end_col_nr - l1.st_u.line.start_col_nr] = NUL;
    memcpy(sortbuf2, ml_get(l2.lnum) + l2.st_u.line.start_col_nr,
           l2.st_u.line.end_col_nr - l2.st_u.line.start_col_nr + 1);
    sortbuf2[l2.st_u.line.end_col_nr - l2.st_u.line.start_col_nr] = NUL;

    result = sort_ic ? STRICMP(sortbuf1, sortbuf2)
             : STRCMP(sortbuf1, sortbuf2);
  }

  /* If two lines have the same value, preserve the original line order. */
  if (result == 0)
    return (int)(l1.lnum - l2.lnum);
  return result;
}

// ":sort".
void ex_sort(exarg_T *eap)
{
  regmatch_T regmatch;
  int len;
  linenr_T lnum;
  long maxlen = 0;
  size_t count = (size_t)(eap->line2 - eap->line1 + 1);
  size_t i;
  char_u      *p;
  char_u      *s;
  char_u      *s2;
  char_u c;                             // temporary character storage
  bool unique = false;
  long deleted;
  colnr_T start_col;
  colnr_T end_col;
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

  sort_abort = sort_ic = sort_rx = sort_nr = sort_flt = 0;
  size_t format_found = 0;

  for (p = eap->arg; *p != NUL; ++p) {
    if (ascii_iswhite(*p)) {
    } else if (*p == 'i') {
      sort_ic = true;
    } else if (*p == 'r') {
      sort_rx = true;
    } else if (*p == 'n') {
      sort_nr = 1;
      format_found++;
    } else if (*p == 'f') {
      sort_flt = 1;
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
      s = skip_regexp(p + 1, *p, true, NULL);
      if (*s != *p) {
        EMSG(_(e_invalpat));
        goto sortend;
      }
      *s = NUL;
      // Use last search pattern if sort pattern is empty.
      if (s == p + 1) {
        if (last_search_pat() == NULL) {
          EMSG(_(e_noprevre));
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
      EMSG2(_(e_invarg2), p);
      goto sortend;
    }
  }

  // Can only have one of 'n', 'b', 'o' and 'x'.
  if (format_found > 1) {
    EMSG(_(e_invarg));
    goto sortend;
  }

  // From here on "sort_nr" is used as a flag for any integer number
  // sorting.
  sort_nr += sort_what;

  // Make an array with all line numbers.  This avoids having to copy all
  // the lines into allocated memory.
  // When sorting on strings "start_col_nr" is the offset in the line, for
  // numbers sorting it's the number to sort on.  This means the pattern
  // matching and number conversion only has to be done once per line.
  // Also get the longest line length for allocating "sortbuf".
  for (lnum = eap->line1; lnum <= eap->line2; ++lnum) {
    s = ml_get(lnum);
    len = (int)STRLEN(s);
    if (maxlen < len) {
      maxlen = len;
    }

    start_col = 0;
    end_col = len;
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
      // Make sure vim_str2nr doesn't read any digits past the end
      // of the match, by temporarily terminating the string there
      s2 = s + end_col;
      c = *s2;
      *s2 = NUL;
      // Sorting on number: Store the number itself.
      p = s + start_col;
      if (sort_nr) {
        if (sort_what & STR2NR_HEX) {
          s = skiptohex(p);
        } else if (sort_what & STR2NR_BIN) {
          s = (char_u *)skiptobin((char *)p);
        } else {
          s = skiptodigit(p);
        }
        if (s > p && s[-1] == '-') {
          s--;  // include preceding negative sign
        }
        if (*s == NUL) {
          // empty line should sort before any number
          nrs[lnum - eap->line1].st_u.value = -MAXLNUM;
        } else {
          vim_str2nr(s, NULL, NULL, sort_what,
                     &nrs[lnum - eap->line1].st_u.value, NULL, 0);
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
          nrs[lnum - eap->line1].st_u.value_flt = strtod((char *)s, NULL);
        }
      }
      *s2 = c;
    } else {
      // Store the column to sort at.
      nrs[lnum - eap->line1].st_u.line.start_col_nr = start_col;
      nrs[lnum - eap->line1].st_u.line.end_col_nr = end_col;
    }

    nrs[lnum - eap->line1].lnum = lnum;

    if (regmatch.regprog != NULL)
      fast_breakcheck();
    if (got_int)
      goto sortend;
  }

  // Allocate a buffer that can hold the longest line.
  sortbuf1 = xmalloc(maxlen + 1);
  sortbuf2 = xmalloc(maxlen + 1);

  // Sort the array of line numbers.  Note: can't be interrupted!
  qsort((void *)nrs, count, sizeof(sorti_T), sort_compare);

  if (sort_abort)
    goto sortend;

  // Insert the lines in the sorted order below the last one.
  lnum = eap->line2;
  for (i = 0; i < count; ++i) {
    s = ml_get(nrs[eap->forceit ? count - i - 1 : i].lnum);
    if (!unique || i == 0
        || (sort_ic ? STRICMP(s, sortbuf1) : STRCMP(s, sortbuf1)) != 0) {
      // Copy the line into a buffer, it may become invalid in
      // ml_append(). And it's needed for "unique".
      STRCPY(sortbuf1, s);
      if (ml_append(lnum++, sortbuf1, (colnr_T)0, false) == FAIL) {
        break;
      }
    }
    fast_breakcheck();
    if (got_int)
      goto sortend;
  }

  // delete the original lines if appending worked
  if (i == count) {
    for (i = 0; i < count; ++i) {
      ml_delete(eap->line1, false);
    }
  } else {
    count = 0;
  }

  // Adjust marks for deleted (or added) lines and prepare for displaying.
  deleted = (long)(count - (lnum - eap->line2));
  if (deleted > 0) {
    mark_adjust(eap->line2 - deleted, eap->line2, (long)MAXLNUM, -deleted,
                false);
  } else if (deleted < 0) {
    mark_adjust(eap->line2, MAXLNUM, -deleted, 0L, false);
  }
  changed_lines(eap->line1, 0, eap->line2 + 1, -deleted, true);

  curwin->w_cursor.lnum = eap->line1;
  beginline(BL_WHITE | BL_FIX);

sortend:
  xfree(nrs);
  xfree(sortbuf1);
  xfree(sortbuf2);
  vim_regfree(regmatch.regprog);
  if (got_int) {
    EMSG(_(e_interr));
  }
}

/*
 * ":retab".
 */
void ex_retab(exarg_T *eap)
{
  linenr_T lnum;
  int got_tab = FALSE;
  long num_spaces = 0;
  long num_tabs;
  long len;
  long col;
  long vcol;
  long start_col = 0;                   /* For start of white-space string */
  long start_vcol = 0;                  /* For start of white-space string */
  int temp;
  long old_len;
  char_u      *ptr;
  char_u      *new_line = (char_u *)1;      /* init to non-NULL */
  int did_undo;                         /* called u_save for current line */
  int new_ts;
  int save_list;
  linenr_T first_line = 0;              /* first changed line */
  linenr_T last_line = 0;               /* last changed line */

  save_list = curwin->w_p_list;
  curwin->w_p_list = 0;             /* don't want list mode here */

  new_ts = getdigits_int(&(eap->arg));
  if (new_ts < 0) {
    EMSG(_(e_positive));
    return;
  }
  if (new_ts == 0)
    new_ts = curbuf->b_p_ts;
  for (lnum = eap->line1; !got_int && lnum <= eap->line2; ++lnum) {
    ptr = ml_get(lnum);
    col = 0;
    vcol = 0;
    did_undo = FALSE;
    for (;; ) {
      if (ascii_iswhite(ptr[col])) {
        if (!got_tab && num_spaces == 0) {
          /* First consecutive white-space */
          start_vcol = vcol;
          start_col = col;
        }
        if (ptr[col] == ' ')
          num_spaces++;
        else
          got_tab = TRUE;
      } else {
        if (got_tab || (eap->forceit && num_spaces > 1)) {
          /* Retabulate this string of white-space */

          /* len is virtual length of white string */
          len = num_spaces = vcol - start_vcol;
          num_tabs = 0;
          if (!curbuf->b_p_et) {
            temp = new_ts - (start_vcol % new_ts);
            if (num_spaces >= temp) {
              num_spaces -= temp;
              num_tabs++;
            }
            num_tabs += num_spaces / new_ts;
            num_spaces -= (num_spaces / new_ts) * new_ts;
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

            /* len is actual number of white characters used */
            len = num_spaces + num_tabs;
            old_len = (long)STRLEN(ptr);
            new_line = xmalloc(old_len - col + start_col + len + 1);

            if (start_col > 0)
              memmove(new_line, ptr, (size_t)start_col);
            memmove(new_line + start_col + len,
                ptr + col, (size_t)(old_len - col + 1));
            ptr = new_line + start_col;
            for (col = 0; col < len; col++) {
              ptr[col] = (col < num_tabs) ? '\t' : ' ';
            }
            ml_replace(lnum, new_line, false);
            if (first_line == 0) {
              first_line = lnum;
            }
            last_line = lnum;
            ptr = new_line;
            col = start_col + len;
          }
        }
        got_tab = FALSE;
        num_spaces = 0;
      }
      if (ptr[col] == NUL)
        break;
      vcol += chartabsize(ptr + col, (colnr_T)vcol);
      if (has_mbyte)
        col += (*mb_ptr2len)(ptr + col);
      else
        ++col;
    }
    if (new_line == NULL)                   /* out of memory */
      break;
    line_breakcheck();
  }
  if (got_int)
    EMSG(_(e_interr));

  if (curbuf->b_p_ts != new_ts)
    redraw_curbuf_later(NOT_VALID);
  if (first_line != 0) {
    changed_lines(first_line, 0, last_line + 1, 0L, true);
  }

  curwin->w_p_list = save_list;         /* restore 'list' */

  curbuf->b_p_ts = new_ts;
  coladvance(curwin->w_curswant);

  u_clearline();
}

/*
 * :move command - move lines line1-line2 to line dest
 *
 * return FAIL for failure, OK otherwise
 */
int do_move(linenr_T line1, linenr_T line2, linenr_T dest)
{
  char_u      *str;
  linenr_T l;
  linenr_T extra;      // Num lines added before line1
  linenr_T num_lines;  // Num lines moved
  linenr_T last_line;  // Last line in file after adding new text

  if (dest >= line1 && dest < line2) {
    EMSG(_("E134: Move lines into themselves"));
    return FAIL;
  }

  num_lines = line2 - line1 + 1;

  /*
   * First we copy the old text to its new location -- webb
   * Also copy the flag that ":global" command uses.
   */
  if (u_save(dest, dest + 1) == FAIL)
    return FAIL;
  for (extra = 0, l = line1; l <= line2; l++) {
    str = vim_strsave(ml_get(l + extra));
    ml_append(dest + l - line1, str, (colnr_T)0, FALSE);
    xfree(str);
    if (dest < line1)
      extra++;
  }

  /*
   * Now we must be careful adjusting our marks so that we don't overlap our
   * mark_adjust() calls.
   *
   * We adjust the marks within the old text so that they refer to the
   * last lines of the file (temporarily), because we know no other marks
   * will be set there since these line numbers did not exist until we added
   * our new lines.
   *
   * Then we adjust the marks on lines between the old and new text positions
   * (either forwards or backwards).
   *
   * And Finally we adjust the marks we put at the end of the file back to
   * their final destination at the new text position -- webb
   */
  last_line = curbuf->b_ml.ml_line_count;
  mark_adjust_nofold(line1, line2, last_line - line2, 0L, true);
  changed_lines(last_line - num_lines + 1, 0, last_line + 1, num_lines, false);
  if (dest >= line2) {
    mark_adjust_nofold(line2 + 1, dest, -num_lines, 0L, false);
    FOR_ALL_TAB_WINDOWS(tab, win) {
      if (win->w_buffer == curbuf) {
        foldMoveRange(&win->w_folds, line1, line2, dest);
      }
    }
    curbuf->b_op_start.lnum = dest - num_lines + 1;
    curbuf->b_op_end.lnum = dest;
  } else {
    mark_adjust_nofold(dest + 1, line1 - 1, num_lines, 0L, false);
    FOR_ALL_TAB_WINDOWS(tab, win) {
      if (win->w_buffer == curbuf) {
        foldMoveRange(&win->w_folds, dest + 1, line1 - 1, line2);
      }
    }
    curbuf->b_op_start.lnum = dest + 1;
    curbuf->b_op_end.lnum = dest + num_lines;
  }
  curbuf->b_op_start.col = curbuf->b_op_end.col = 0;
  mark_adjust_nofold(last_line - num_lines + 1, last_line,
                     -(last_line - dest - extra), 0L, true);
  changed_lines(last_line - num_lines + 1, 0, last_line + 1, -extra, false);

  // send update regarding the new lines that were added
  if (kv_size(curbuf->update_channels)) {
    buf_updates_send_changes(curbuf, dest + 1, num_lines, 0, true);
  }

  /*
   * Now we delete the original text -- webb
   */
  if (u_save(line1 + extra - 1, line2 + extra + 1) == FAIL)
    return FAIL;

  for (l = line1; l <= line2; l++)
    ml_delete(line1 + extra, TRUE);

  if (!global_busy && num_lines > p_report) {
    if (num_lines == 1)
      MSG(_("1 line moved"));
    else
      smsg(_("%" PRId64 " lines moved"), (int64_t)num_lines);
  }

  /*
   * Leave the cursor on the last of the moved lines.
   */
  if (dest >= line1)
    curwin->w_cursor.lnum = dest;
  else
    curwin->w_cursor.lnum = dest + (line2 - line1) + 1;

  if (line1 < dest) {
    dest += num_lines + 1;
    last_line = curbuf->b_ml.ml_line_count;
    if (dest > last_line + 1)
      dest = last_line + 1;
    changed_lines(line1, 0, dest, 0L, false);
  } else {
    changed_lines(dest + 1, 0, line1 + num_lines, 0L, false);
  }

  // send nvim_buf_lines_event regarding lines that were deleted
  if (kv_size(curbuf->update_channels)) {
    buf_updates_send_changes(curbuf, line1 + extra, 0, num_lines, true);
  }

  return OK;
}

/*
 * ":copy"
 */
void ex_copy(linenr_T line1, linenr_T line2, linenr_T n)
{
  linenr_T count;
  char_u      *p;

  count = line2 - line1 + 1;
  curbuf->b_op_start.lnum = n + 1;
  curbuf->b_op_end.lnum = n + count;
  curbuf->b_op_start.col = curbuf->b_op_end.col = 0;

  /*
   * there are three situations:
   * 1. destination is above line1
   * 2. destination is between line1 and line2
   * 3. destination is below line2
   *
   * n = destination (when starting)
   * curwin->w_cursor.lnum = destination (while copying)
   * line1 = start of source (while copying)
   * line2 = end of source (while copying)
   */
  if (u_save(n, n + 1) == FAIL)
    return;

  curwin->w_cursor.lnum = n;
  while (line1 <= line2) {
    /* need to use vim_strsave() because the line will be unlocked within
     * ml_append() */
    p = vim_strsave(ml_get(line1));
    ml_append(curwin->w_cursor.lnum, p, (colnr_T)0, FALSE);
    xfree(p);

    /* situation 2: skip already copied lines */
    if (line1 == n)
      line1 = curwin->w_cursor.lnum;
    ++line1;
    if (curwin->w_cursor.lnum < line1)
      ++line1;
    if (curwin->w_cursor.lnum < line2)
      ++line2;
    ++curwin->w_cursor.lnum;
  }

  appended_lines_mark(n, count);

  msgmore((long)count);
}

static char_u   *prevcmd = NULL;        /* the previous command */

#if defined(EXITFREE)
void free_prev_shellcmd(void)
{
  xfree(prevcmd);
}

#endif

/*
 * Handle the ":!cmd" command.	Also for ":r !cmd" and ":w !cmd"
 * Bangs in the argument are replaced with the previously entered command.
 * Remember the argument.
 */
void do_bang(int addr_count, exarg_T *eap, int forceit, int do_in, int do_out)
{
  char_u              *arg = eap->arg;          /* command */
  linenr_T line1 = eap->line1;                  /* start of range */
  linenr_T line2 = eap->line2;                  /* end of range */
  char_u              *newcmd = NULL;           /* the new command */
  int free_newcmd = FALSE;                      /* need to free() newcmd */
  int ins_prevcmd;
  char_u              *t;
  char_u              *p;
  char_u              *trailarg;
  int len;
  int scroll_save = msg_scroll;

  /*
   * Disallow shell commands in restricted mode (-Z)
   * Disallow shell commands from .exrc and .vimrc in current directory for
   * security reasons.
   */
  if (check_restricted() || check_secure())
    return;

  if (addr_count == 0) {                /* :! */
    msg_scroll = FALSE;             /* don't scroll here */
    autowrite_all();
    msg_scroll = scroll_save;
  }

  /*
   * Try to find an embedded bang, like in :!<cmd> ! [args]
   * (:!! is indicated by the 'forceit' variable)
   */
  ins_prevcmd = forceit;
  trailarg = arg;
  do {
    len = (int)STRLEN(trailarg) + 1;
    if (newcmd != NULL)
      len += (int)STRLEN(newcmd);
    if (ins_prevcmd) {
      if (prevcmd == NULL) {
        EMSG(_(e_noprev));
        xfree(newcmd);
        return;
      }
      len += (int)STRLEN(prevcmd);
    }
    t = xmalloc(len);
    *t = NUL;
    if (newcmd != NULL)
      STRCAT(t, newcmd);
    if (ins_prevcmd)
      STRCAT(t, prevcmd);
    p = t + STRLEN(t);
    STRCAT(t, trailarg);
    xfree(newcmd);
    newcmd = t;

    /*
     * Scan the rest of the argument for '!', which is replaced by the
     * previous command.  "\!" is replaced by "!" (this is vi compatible).
     */
    trailarg = NULL;
    while (*p) {
      if (*p == '!') {
        if (p > newcmd && p[-1] == '\\')
          STRMOVE(p - 1, p);
        else {
          trailarg = p;
          *trailarg++ = NUL;
          ins_prevcmd = TRUE;
          break;
        }
      }
      ++p;
    }
  } while (trailarg != NULL);

  xfree(prevcmd);
  prevcmd = newcmd;

  if (bangredo) { /* put cmd in redo buffer for ! command */
    /* If % or # appears in the command, it must have been escaped.
     * Reescape them, so that redoing them does not substitute them by the
     * buffername. */
    char_u *cmd = vim_strsave_escaped(prevcmd, (char_u *)"%#");

    AppendToRedobuffLit(cmd, -1);
    xfree(cmd);
    AppendToRedobuff("\n");
    bangredo = false;
  }
  /*
   * Add quotes around the command, for shells that need them.
   */
  if (*p_shq != NUL) {
    newcmd = xmalloc(STRLEN(prevcmd) + 2 * STRLEN(p_shq) + 1);
    STRCPY(newcmd, p_shq);
    STRCAT(newcmd, prevcmd);
    STRCAT(newcmd, p_shq);
    free_newcmd = TRUE;
  }
  if (addr_count == 0) {                /* :! */
    /* echo the command */
    msg_start();
    msg_putchar(':');
    msg_putchar('!');
    msg_outtrans(newcmd);
    msg_clr_eos();
    ui_cursor_goto(msg_row, msg_col);

    do_shell(newcmd, 0);
  } else {                            /* :range! */
    /* Careful: This may recursively call do_bang() again! (because of
     * autocommands) */
    do_filter(line1, line2, eap, newcmd, do_in, do_out);
    apply_autocmds(EVENT_SHELLFILTERPOST, NULL, NULL, FALSE, curbuf);
  }
  if (free_newcmd)
    xfree(newcmd);
}

// do_filter: filter lines through a command given by the user
//
// We mostly use temp files and the call_shell() routine here. This would
// normally be done using pipes on a Unix system, but this is more portable
// to non-Unix systems. The call_shell() routine needs to be able
// to deal with redirection somehow, and should handle things like looking
// at the PATH env. variable, and adding reasonable extensions to the
// command name given by the user. All reasonable versions of call_shell()
// do this.
// Alternatively, if on Unix and redirecting input or output, but not both,
// and the 'shelltemp' option isn't set, use pipes.
// We use input redirection if do_in is TRUE.
// We use output redirection if do_out is TRUE.
static void do_filter(
    linenr_T line1,
    linenr_T line2,
    exarg_T *eap,               /* for forced 'ff' and 'fenc' */
    char_u *cmd,
    int do_in,
    int do_out)
{
  char_u      *itmp = NULL;
  char_u      *otmp = NULL;
  linenr_T linecount;
  linenr_T read_linecount;
  pos_T cursor_save;
  char_u      *cmd_buf;
  buf_T       *old_curbuf = curbuf;
  int shell_flags = 0;

  if (*cmd == NUL)          /* no filter command */
    return;


  cursor_save = curwin->w_cursor;
  linecount = line2 - line1 + 1;
  curwin->w_cursor.lnum = line1;
  curwin->w_cursor.col = 0;
  changed_line_abv_curs();
  invalidate_botline();

  /*
   * When using temp files:
   * 1. * Form temp file names
   * 2. * Write the lines to a temp file
   * 3.   Run the filter command on the temp file
   * 4. * Read the output of the command into the buffer
   * 5. * Delete the original lines to be filtered
   * 6. * Remove the temp files
   *
   * When writing the input with a pipe or when catching the output with a
   * pipe only need to do 3.
   */

  if (do_out)
    shell_flags |= kShellOptDoOut;

  if (!do_in && do_out && !p_stmp) {
    // Use a pipe to fetch stdout of the command, do not use a temp file.
    shell_flags |= kShellOptRead;
    curwin->w_cursor.lnum = line2;
  } else if (do_in && !do_out && !p_stmp) {
    // Use a pipe to write stdin of the command, do not use a temp file.
    shell_flags |= kShellOptWrite;
    curbuf->b_op_start.lnum = line1;
    curbuf->b_op_end.lnum = line2;
  } else if (do_in && do_out && !p_stmp) {
    // Use a pipe to write stdin and fetch stdout of the command, do not
    // use a temp file.
    shell_flags |= kShellOptRead | kShellOptWrite;
    curbuf->b_op_start.lnum = line1;
    curbuf->b_op_end.lnum = line2;
    curwin->w_cursor.lnum = line2;
  } else if ((do_in && (itmp = vim_tempname()) == NULL)
      || (do_out && (otmp = vim_tempname()) == NULL)) {
    EMSG(_(e_notmp));
    goto filterend;
  }

  /*
   * The writing and reading of temp files will not be shown.
   * Vi also doesn't do this and the messages are not very informative.
   */
  ++no_wait_return;             /* don't call wait_return() while busy */
  if (itmp != NULL && buf_write(curbuf, itmp, NULL, line1, line2, eap,
                                false, false, false, true) == FAIL) {
    msg_putchar('\n');  // Keep message from buf_write().
    no_wait_return--;
    if (!aborting()) {
      EMSG2(_("E482: Can't create file %s"), itmp);  // Will call wait_return.
    }
    goto filterend;
  }
  if (curbuf != old_curbuf)
    goto filterend;

  if (!do_out)
    msg_putchar('\n');

  /* Create the shell command in allocated memory. */
  cmd_buf = make_filter_cmd(cmd, itmp, otmp);
  ui_cursor_goto((int)Rows - 1, 0);

  /*
   * When not redirecting the output the command can write anything to the
   * screen. If 'shellredir' is equal to ">", screen may be messed up by
   * stderr output of external command. Clear the screen later.
   * If do_in is FALSE, this could be something like ":r !cat", which may
   * also mess up the screen, clear it later.
   */
  if (!do_out || STRCMP(p_srr, ">") == 0 || !do_in)
    redraw_later_clear();

  if (do_out) {
    if (u_save((linenr_T)(line2), (linenr_T)(line2 + 1)) == FAIL) {
      xfree(cmd_buf);
      goto error;
    }
    redraw_curbuf_later(VALID);
  }
  read_linecount = curbuf->b_ml.ml_line_count;

  // When call_shell() fails wait_return() is called to give the user a chance
  // to read the error messages. Otherwise errors are ignored, so you can see
  // the error messages from the command that appear on stdout; use 'u' to fix
  // the text.
  // Pass on the kShellOptDoOut flag when the output is being redirected.
  if (call_shell(
        cmd_buf,
        kShellOptFilter | shell_flags,
        NULL
        )) {
    redraw_later_clear();
    wait_return(FALSE);
  }
  xfree(cmd_buf);

  did_check_timestamps = FALSE;
  need_check_timestamps = TRUE;

  /* When interrupting the shell command, it may still have produced some
   * useful output.  Reset got_int here, so that readfile() won't cancel
   * reading. */
  os_breakcheck();
  got_int = FALSE;

  if (do_out) {
    if (otmp != NULL) {
      if (readfile(otmp, NULL, line2, (linenr_T)0, (linenr_T)MAXLNUM, eap,
                   READ_FILTER) != OK) {
        if (!aborting()) {
          msg_putchar('\n');
          EMSG2(_(e_notread), otmp);
        }
        goto error;
      }
      if (curbuf != old_curbuf)
        goto filterend;
    }

    read_linecount = curbuf->b_ml.ml_line_count - read_linecount;

    if (shell_flags & kShellOptRead) {
      curbuf->b_op_start.lnum = line2 + 1;
      curbuf->b_op_end.lnum = curwin->w_cursor.lnum;
      appended_lines_mark(line2, read_linecount);
    }

    if (do_in) {
      if (cmdmod.keepmarks || vim_strchr(p_cpo, CPO_REMMARK) == NULL) {
        if (read_linecount >= linecount) {
          // move all marks from old lines to new lines
          mark_adjust(line1, line2, linecount, 0L, false);
        } else {
          // move marks from old lines to new lines, delete marks
          // that are in deleted lines
          mark_adjust(line1, line1 + read_linecount - 1, linecount, 0L, false);
          mark_adjust(line1 + read_linecount, line2, MAXLNUM, 0L, false);
        }
      }

      /*
       * Put cursor on first filtered line for ":range!cmd".
       * Adjust '[ and '] (set by buf_write()).
       */
      curwin->w_cursor.lnum = line1;
      del_lines(linecount, TRUE);
      curbuf->b_op_start.lnum -= linecount;             /* adjust '[ */
      curbuf->b_op_end.lnum -= linecount;               /* adjust '] */
      write_lnum_adjust(-linecount);                    /* adjust last line
                                                           for next write */
      foldUpdate(curwin, curbuf->b_op_start.lnum, curbuf->b_op_end.lnum);
    } else {
      /*
       * Put cursor on last new line for ":r !cmd".
       */
      linecount = curbuf->b_op_end.lnum - curbuf->b_op_start.lnum + 1;
      curwin->w_cursor.lnum = curbuf->b_op_end.lnum;
    }

    beginline(BL_WHITE | BL_FIX);           /* cursor on first non-blank */
    --no_wait_return;

    if (linecount > p_report) {
      if (do_in) {
        vim_snprintf((char *)msg_buf, sizeof(msg_buf),
            _("%" PRId64 " lines filtered"), (int64_t)linecount);
        if (msg(msg_buf) && !msg_scroll)
          /* save message to display it after redraw */
          set_keep_msg(msg_buf, 0);
      } else
        msgmore((long)linecount);
    }
  } else {
error:
    /* put cursor back in same position for ":w !cmd" */
    curwin->w_cursor = cursor_save;
    --no_wait_return;
    wait_return(FALSE);
  }

filterend:

  if (curbuf != old_curbuf) {
    --no_wait_return;
    EMSG(_("E135: *Filter* Autocommands must not change current buffer"));
  }
  if (itmp != NULL)
    os_remove((char *)itmp);
  if (otmp != NULL)
    os_remove((char *)otmp);
  xfree(itmp);
  xfree(otmp);
}

/*
 * Call a shell to execute a command.
 * When "cmd" is NULL start an interactive shell.
 */
void
do_shell(
    char_u *cmd,
    int flags             // may be SHELL_DOOUT when output is redirected
)
{
  int save_nwr;

  /*
   * Disallow shell commands in restricted mode (-Z)
   * Disallow shell commands from .exrc and .vimrc in current directory for
   * security reasons.
   */
  if (check_restricted() || check_secure()) {
    msg_end();
    return;
  }


  /*
   * For autocommands we want to get the output on the current screen, to
   * avoid having to type return below.
   */
  msg_putchar('\r');                    /* put cursor at start of line */
  msg_putchar('\n');                    /* may shift screen one line up */

  /* warning message before calling the shell */
  if (p_warn
      && !autocmd_busy
      && msg_silent == 0)
    FOR_ALL_BUFFERS(buf) {
      if (bufIsChanged(buf)) {
        MSG_PUTS(_("[No write since last change]\n"));
        break;
      }
    }

  // This ui_cursor_goto is required for when the '\n' resulted in a "delete line
  // 1" command to the terminal.
  ui_cursor_goto(msg_row, msg_col);
  (void)call_shell(cmd, flags, NULL);
  msg_didout = true;
  did_check_timestamps = false;
  need_check_timestamps = true;

  // put the message cursor at the end of the screen, avoids wait_return()
  // to overwrite the text that the external command showed
  msg_row = Rows - 1;
  msg_col = 0;

  if (autocmd_busy) {
    if (msg_silent == 0)
      redraw_later_clear();
  } else {
    /*
     * For ":sh" there is no need to call wait_return(), just redraw.
     * Also for the Win32 GUI (the output is in a console window).
     * Otherwise there is probably text on the screen that the user wants
     * to read before redrawing, so call wait_return().
     */
    if (cmd == NULL
        ) {
      if (msg_silent == 0)
        redraw_later_clear();
      need_wait_return = FALSE;
    } else {
      /*
       * If we switch screens when starttermcap() is called, we really
       * want to wait for "hit return to continue".
       */
      save_nwr = no_wait_return;
      wait_return(msg_silent == 0);
      no_wait_return = save_nwr;
    }
  }

  /* display any error messages now */
  display_errors();

  apply_autocmds(EVENT_SHELLCMDPOST, NULL, NULL, FALSE, curbuf);
}

/// Create a shell command from a command string, input redirection file and
/// output redirection file.
///
/// @param cmd  Command to execute.
/// @param itmp NULL or the input file.
/// @param otmp NULL or the output file.
/// @returns an allocated string with the shell command.
char_u *make_filter_cmd(char_u *cmd, char_u *itmp, char_u *otmp)
{
  bool is_fish_shell =
#if defined(UNIX)
    STRNCMP(invocation_path_tail(p_sh, NULL), "fish", 4) == 0;
#else
    false;
#endif

  size_t len = STRLEN(cmd) + 1;  // At least enough space for cmd + NULL.

  len += is_fish_shell ?  sizeof("begin; ""; end") - 1
                       :  sizeof("("")") - 1;

  if (itmp != NULL) {
    len += STRLEN(itmp) + sizeof(" { "" < "" } ") - 1;
  }
  if (otmp != NULL) {
    len += STRLEN(otmp) + STRLEN(p_srr) + 2;  // two extra spaces ("  "),
  }
  char *const buf = xmalloc(len);

#if defined(UNIX)
  // Put delimiters around the command (for concatenated commands) when
  // redirecting input and/or output.
  if (itmp != NULL || otmp != NULL) {
    char *fmt = is_fish_shell ? "begin; %s; end"
                              :       "(%s)";
    vim_snprintf(buf, len, fmt, (char *)cmd);
  } else {
    xstrlcpy(buf, (char *)cmd, len);
  }

  if (itmp != NULL) {
    xstrlcat(buf, " < ", len - 1);
    xstrlcat(buf, (const char *)itmp, len - 1);
  }
#else
  // For shells that don't understand braces around commands, at least allow
  // the use of commands in a pipe.
  xstrlcpy(buf, (char *)cmd, len);
  if (itmp != NULL) {
    // If there is a pipe, we have to put the '<' in front of it.
    // Don't do this when 'shellquote' is not empty, otherwise the
    // redirection would be inside the quotes.
    if (*p_shq == NUL) {
      char *const p = strchr(buf, '|');
      if (p != NULL) {
        *p = NUL;
      }
    }
    xstrlcat(buf, " < ", len);
    xstrlcat(buf, (const char *)itmp, len);
    if (*p_shq == NUL) {
      const char *const p = strchr((const char *)cmd, '|');
      if (p != NULL) {
        xstrlcat(buf, " ", len - 1);  // Insert a space before the '|' for DOS
        xstrlcat(buf, p, len - 1);
      }
    }
  }
#endif
  if (otmp != NULL) {
    append_redir(buf, len, (char *) p_srr, (char *) otmp);
  }
  return (char_u *) buf;
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
void append_redir(char *const buf, const size_t buflen,
                  const char *const opt, const char *const fname)
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
    vim_snprintf(end + 1, (size_t) (buflen - (end + 1 - buf)), opt, fname);
  } else {
    vim_snprintf(end, (size_t) (buflen - (end - buf)), " %s %s", opt, fname);
  }
}

void print_line_no_prefix(linenr_T lnum, int use_number, int list)
{
  char numbuf[30];

  if (curwin->w_p_nu || use_number) {
    vim_snprintf(numbuf, sizeof(numbuf), "%*" PRIdLINENR " ",
                 number_width(curwin), lnum);
    msg_puts_attr(numbuf, HL_ATTR(HLF_N));  // Highlight line nrs.
  }
  msg_prt_line(ml_get(lnum), list);
}

/*
 * Print a text line.  Also in silent mode ("ex -s").
 */
void print_line(linenr_T lnum, int use_number, int list)
{
  int save_silent = silent_mode;

  // apply :filter /pat/
  if (message_filtered(ml_get(lnum))) {
    return;
  }

  msg_start();
  silent_mode = FALSE;
  info_message = TRUE;          /* use mch_msg(), not mch_errmsg() */
  print_line_no_prefix(lnum, use_number, list);
  if (save_silent) {
    msg_putchar('\n');
    ui_flush();
    silent_mode = save_silent;
  }
  info_message = FALSE;
}

int rename_buffer(char_u *new_fname)
{
  char_u      *fname, *sfname, *xfname;
  buf_T       *buf;

  buf = curbuf;
  apply_autocmds(EVENT_BUFFILEPRE, NULL, NULL, FALSE, curbuf);
  /* buffer changed, don't change name now */
  if (buf != curbuf)
    return FAIL;
  if (aborting())           /* autocmds may abort script processing */
    return FAIL;
  /*
   * The name of the current buffer will be changed.
   * A new (unlisted) buffer entry needs to be made to hold the old file
   * name, which will become the alternate file name.
   * But don't set the alternate file name if the buffer didn't have a
   * name.
   */
  fname = curbuf->b_ffname;
  sfname = curbuf->b_sfname;
  xfname = curbuf->b_fname;
  curbuf->b_ffname = NULL;
  curbuf->b_sfname = NULL;
  if (setfname(curbuf, new_fname, NULL, TRUE) == FAIL) {
    curbuf->b_ffname = fname;
    curbuf->b_sfname = sfname;
    return FAIL;
  }
  curbuf->b_flags |= BF_NOTEDITED;
  if (xfname != NULL && *xfname != NUL) {
    buf = buflist_new(fname, xfname, curwin->w_cursor.lnum, 0);
    if (buf != NULL && !cmdmod.keepalt) {
      curwin->w_alt_fnum = buf->b_fnum;
    }
  }
  xfree(fname);
  xfree(sfname);
  apply_autocmds(EVENT_BUFFILEPOST, NULL, NULL, FALSE, curbuf);
  /* Change directories when the 'acd' option is set. */
  do_autochdir();
  return OK;
}

/*
 * ":file[!] [fname]".
 */
void ex_file(exarg_T *eap)
{
  /* ":0file" removes the file name.  Check for illegal uses ":3file",
   * "0file name", etc. */
  if (eap->addr_count > 0
      && (*eap->arg != NUL
          || eap->line2 > 0
          || eap->addr_count > 1)) {
    EMSG(_(e_invarg));
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

/*
 * ":update".
 */
void ex_update(exarg_T *eap)
{
  if (curbufIsChanged())
    (void)do_write(eap);
}

/*
 * ":write" and ":saveas".
 */
void ex_write(exarg_T *eap)
{
  if (eap->usefilter)           /* input lines to shell command */
    do_bang(1, eap, FALSE, TRUE, FALSE);
  else
    (void)do_write(eap);
}

/*
 * write current buffer to file 'eap->arg'
 * if 'eap->append' is TRUE, append to the file
 *
 * if *eap->arg == NUL write to current file
 *
 * return FAIL for failure, OK otherwise
 */
int do_write(exarg_T *eap)
{
  int other;
  char_u      *fname = NULL;            /* init to shut up gcc */
  char_u      *ffname;
  int retval = FAIL;
  char_u      *free_fname = NULL;
  buf_T       *alt_buf = NULL;
  int          name_was_missing;

  if (not_writing())            /* check 'write' option */
    return FAIL;

  ffname = eap->arg;
  if (*ffname == NUL) {
    if (eap->cmdidx == CMD_saveas) {
      EMSG(_(e_argreq));
      goto theend;
    }
    other = FALSE;
  } else {
    fname = ffname;
    free_fname = (char_u *)fix_fname((char *)ffname);
    /*
     * When out-of-memory, keep unexpanded file name, because we MUST be
     * able to write the file in this situation.
     */
    if (free_fname != NULL)
      ffname = free_fname;
    other = otherfile(ffname);
  }

  /*
   * If we have a new file, put its name in the list of alternate file names.
   */
  if (other) {
    if (vim_strchr(p_cpo, CPO_ALTWRITE) != NULL
        || eap->cmdidx == CMD_saveas)
      alt_buf = setaltfname(ffname, fname, (linenr_T)1);
    else
      alt_buf = buflist_findname(ffname);
    if (alt_buf != NULL && alt_buf->b_ml.ml_mfp != NULL) {
      /* Overwriting a file that is loaded in another buffer is not a
       * good idea. */
      EMSG(_(e_bufloaded));
      goto theend;
    }
  }

  // Writing to the current file is not allowed in readonly mode
  // and a file name is required.
  // "nofile" and "nowrite" buffers cannot be written implicitly either.
  if (!other && (bt_dontwrite_msg(curbuf)
                 || check_fname() == FAIL
                 || check_readonly(&eap->forceit, curbuf))) {
    goto theend;
  }

  if (!other) {
    ffname = curbuf->b_ffname;
    fname = curbuf->b_fname;
    /*
     * Not writing the whole file is only allowed with '!'.
     */
    if (       (eap->line1 != 1
                || eap->line2 != curbuf->b_ml.ml_line_count)
               && !eap->forceit
               && !eap->append
               && !p_wa) {
      if (p_confirm || cmdmod.confirm) {
        if (vim_dialog_yesno(VIM_QUESTION, NULL,
                (char_u *)_("Write partial file?"), 2) != VIM_YES)
          goto theend;
        eap->forceit = TRUE;
      } else {
        EMSG(_("E140: Use ! to write partial buffer"));
        goto theend;
      }
    }
  }

  if (check_overwrite(eap, curbuf, fname, ffname, other) == OK) {
    if (eap->cmdidx == CMD_saveas && alt_buf != NULL) {
      buf_T       *was_curbuf = curbuf;

      apply_autocmds(EVENT_BUFFILEPRE, NULL, NULL, FALSE, curbuf);
      apply_autocmds(EVENT_BUFFILEPRE, NULL, NULL, FALSE, alt_buf);
      if (curbuf != was_curbuf || aborting()) {
        /* buffer changed, don't change name now */
        retval = FAIL;
        goto theend;
      }
      /* Exchange the file names for the current and the alternate
       * buffer.  This makes it look like we are now editing the buffer
       * under the new name.  Must be done before buf_write(), because
       * if there is no file name and 'cpo' contains 'F', it will set
       * the file name. */
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
      apply_autocmds(EVENT_BUFFILEPOST, NULL, NULL, FALSE, curbuf);
      apply_autocmds(EVENT_BUFFILEPOST, NULL, NULL, FALSE, alt_buf);
      if (!alt_buf->b_p_bl) {
        alt_buf->b_p_bl = TRUE;
        apply_autocmds(EVENT_BUFADD, NULL, NULL, FALSE, alt_buf);
      }
      if (curbuf != was_curbuf || aborting()) {
        /* buffer changed, don't write the file */
        retval = FAIL;
        goto theend;
      }

      // If 'filetype' was empty try detecting it now.
      if (*curbuf->b_p_ft == NUL) {
        if (au_has_group((char_u *)"filetypedetect")) {
          (void)do_doautocmd((char_u *)"filetypedetect BufRead", true, NULL);
        }
        do_modelines(0);
      }

      /* Autocommands may have changed buffer names, esp. when
       * 'autochdir' is set. */
      fname = curbuf->b_sfname;
    }

    name_was_missing = curbuf->b_ffname == NULL;
    retval = buf_write(curbuf, ffname, fname, eap->line1, eap->line2,
        eap, eap->append, eap->forceit, TRUE, FALSE);

    /* After ":saveas fname" reset 'readonly'. */
    if (eap->cmdidx == CMD_saveas) {
      if (retval == OK) {
        curbuf->b_p_ro = FALSE;
        redraw_tabline = TRUE;
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

/*
 * Check if it is allowed to overwrite a file.  If b_flags has BF_NOTEDITED,
 * BF_NEW or BF_READERR, check for overwriting current file.
 * May set eap->forceit if a dialog says it's OK to overwrite.
 * Return OK if it's OK, FAIL if it is not.
 */
int
check_overwrite(
    exarg_T *eap,
    buf_T *buf,
    char_u *fname,         // file name to be used (can differ from
                           //   buf->ffname)
    char_u *ffname,        // full path version of fname
    int other              // writing under other name
)
{
  /*
   * write to other file or b_flags set or not writing the whole file:
   * overwriting only allowed with '!'
   */
  if ((other
       || (buf->b_flags & BF_NOTEDITED)
       || ((buf->b_flags & BF_NEW)
           && vim_strchr(p_cpo, CPO_OVERNEW) == NULL)
       || (buf->b_flags & BF_READERR))
      && !p_wa
      && !bt_nofile(buf)
      && os_path_exists(ffname)) {
    if (!eap->forceit && !eap->append) {
#ifdef UNIX
      // It is possible to open a directory on Unix.
      if (os_isdir(ffname)) {
        EMSG2(_(e_isadir2), ffname);
        return FAIL;
      }
#endif
      if (p_confirm || cmdmod.confirm) {
        char_u buff[DIALOG_MSG_SIZE];

        dialog_msg(buff, _("Overwrite existing file \"%s\"?"), fname);
        if (vim_dialog_yesno(VIM_QUESTION, NULL, buff, 2) != VIM_YES)
          return FAIL;
        eap->forceit = TRUE;
      } else {
        EMSG(_(e_exists));
        return FAIL;
      }
    }

    /* For ":w! filename" check that no swap file exists for "filename". */
    if (other && !emsg_silent) {
      char_u      *dir;
      char_u      *p;
      char_u      *swapname;

      /* We only try the first entry in 'directory', without checking if
       * it's writable.  If the "." directory is not writable the write
       * will probably fail anyway.
       * Use 'shortname' of the current buffer, since there is no buffer
       * for the written file. */
      if (*p_dir == NUL) {
        dir = xmalloc(5);
        STRCPY(dir, ".");
      } else {
        dir = xmalloc(MAXPATHL);
        p = p_dir;
        copy_option_part(&p, dir, MAXPATHL, ",");
      }
      swapname = makeswapname(fname, ffname, curbuf, dir);
      xfree(dir);
      if (os_path_exists(swapname)) {
        if (p_confirm || cmdmod.confirm) {
          char_u buff[DIALOG_MSG_SIZE];

          dialog_msg(buff,
              _("Swap file \"%s\" exists, overwrite anyway?"),
              swapname);
          if (vim_dialog_yesno(VIM_QUESTION, NULL, buff, 2)
              != VIM_YES) {
            xfree(swapname);
            return FAIL;
          }
          eap->forceit = TRUE;
        } else {
          EMSG2(_("E768: Swap file exists: %s (:silent! overrides)"),
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

/*
 * Handle ":wnext", ":wNext" and ":wprevious" commands.
 */
void ex_wnext(exarg_T *eap)
{
  int i;

  if (eap->cmd[1] == 'n')
    i = curwin->w_arg_idx + (int)eap->line2;
  else
    i = curwin->w_arg_idx - (int)eap->line2;
  eap->line1 = 1;
  eap->line2 = curbuf->b_ml.ml_line_count;
  if (do_write(eap) != FAIL)
    do_argfile(eap, i);
}

/*
 * ":wall", ":wqall" and ":xall": Write all changed files (and exit).
 */
void do_wqall(exarg_T *eap)
{
  int error = 0;
  int save_forceit = eap->forceit;

  if (eap->cmdidx == CMD_xall || eap->cmdidx == CMD_wqall)
    exiting = TRUE;

  FOR_ALL_BUFFERS(buf) {
    if (!bufIsChanged(buf)) {
      continue;
    }
    /*
     * Check if there is a reason the buffer cannot be written:
     * 1. if the 'write' option is set
     * 2. if there is no file name (even after browsing)
     * 3. if the 'readonly' is set (even after a dialog)
     * 4. if overwriting is allowed (even after a dialog)
     */
    if (not_writing()) {
      ++error;
      break;
    }
    if (buf->b_ffname == NULL) {
      EMSGN(_("E141: No file name for buffer %" PRId64), buf->b_fnum);
      ++error;
    } else if (check_readonly(&eap->forceit, buf)
               || check_overwrite(eap, buf, buf->b_fname, buf->b_ffname,
                   FALSE) == FAIL) {
      ++error;
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
    eap->forceit = save_forceit;          /* check_overwrite() may set it */
  }
  if (exiting) {
    if (!error)
      getout(0);                /* exit Vim */
    not_exiting();
  }
}

/*
 * Check the 'write' option.
 * Return TRUE and give a message when it's not st.
 */
int not_writing(void)
{
  if (p_write)
    return FALSE;
  EMSG(_("E142: File not written: Writing is disabled by 'write' option"));
  return TRUE;
}

/*
 * Check if a buffer is read-only (either 'readonly' option is set or file is
 * read-only). Ask for overruling in a dialog. Return TRUE and give an error
 * message when the buffer is readonly.
 */
static int check_readonly(int *forceit, buf_T *buf)
{
  /* Handle a file being readonly when the 'readonly' option is set or when
   * the file exists and permissions are read-only. */
  if (!*forceit && (buf->b_p_ro
                    || (os_path_exists(buf->b_ffname)
                        && !os_file_is_writable((char *)buf->b_ffname)))) {
    if ((p_confirm || cmdmod.confirm) && buf->b_fname != NULL) {
      char_u buff[DIALOG_MSG_SIZE];

      if (buf->b_p_ro)
        dialog_msg(buff,
            _(
                "'readonly' option is set for \"%s\".\nDo you wish to write anyway?"),
            buf->b_fname);
      else
        dialog_msg(buff,
            _(
                "File permissions of \"%s\" are read-only.\nIt may still be possible to write it.\nDo you wish to try?"),
            buf->b_fname);

      if (vim_dialog_yesno(VIM_QUESTION, NULL, buff, 2) == VIM_YES) {
        /* Set forceit, to force the writing of a readonly file */
        *forceit = TRUE;
        return FALSE;
      } else
        return TRUE;
    } else if (buf->b_p_ro)
      EMSG(_(e_readonly));
    else
      EMSG2(_("E505: \"%s\" is read-only (add ! to override)"),
          buf->b_fname);
    return TRUE;
  }

  return FALSE;
}

/*
 * Try to abandon current file and edit a new or existing file.
 * "fnum" is the number of the file, if zero use ffname/sfname.
 * "lnum" is the line number for the cursor in the new file (if non-zero).
 *
 * Return:
 * GETFILE_ERROR for "normal" error,
 * GETFILE_NOT_WRITTEN for "not written" error,
 * GETFILE_SAME_FILE for success
 * GETFILE_OPEN_OTHER for successfully opening another file.
 */
int getfile(int fnum, char_u *ffname, char_u *sfname, int setpm, linenr_T lnum, int forceit)
{
  int other;
  int retval;
  char_u      *free_me = NULL;

  if (text_locked()) {
    return GETFILE_ERROR;
  }
  if (curbuf_locked()) {
    return GETFILE_ERROR;
  }

  if (fnum == 0) {
    /* make ffname full path, set sfname */
    fname_expand(curbuf, &ffname, &sfname);
    other = otherfile(ffname);
    free_me = ffname;                   /* has been allocated, free() later */
  } else
    other = (fnum != curbuf->b_fnum);

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
      EMSG(_(e_nowrtmsg));
      retval = GETFILE_NOT_WRITTEN;     // File has been changed.
      goto theend;
    }
  }
  if (other)
    --no_wait_return;
  if (setpm)
    setpcmark();
  if (!other) {
    if (lnum != 0) {
      curwin->w_cursor.lnum = lnum;
    }
    check_cursor_lnum();
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
///                 and forced 'ff' and 'fenc'
/// @param newlnum  if > 0: put cursor on this line number (if possible)
///                 ECMD_LASTL: use last position in loaded file
///                 ECMD_LAST: use last position in all files
///                 ECMD_ONE: use first line
/// @param flags    ECMD_HIDE: if TRUE don't free the current buffer
///                 ECMD_SET_HELP: set b_help flag of (new) buffer before
///                 opening file
///                 ECMD_OLDBUF: use existing buffer if it exists
///                 ECMD_FORCEIT: ! used for Ex command
///                 ECMD_ADDBUF: don't edit, just add to buffer list
/// @param oldwin   Should be "curwin" when editing a new buffer in the current
///                 window, NULL when splitting the window first.  When not NULL
///                 info of the previous buffer for "oldwin" is stored.
///
/// @return FAIL for failure, OK otherwise
int do_ecmd(
    int fnum,
    char_u *ffname,
    char_u *sfname,
    exarg_T *eap,                       /* can be NULL! */
    linenr_T newlnum,
    int flags,
    win_T *oldwin
)
{
  int other_file;                       /* TRUE if editing another file */
  int oldbuf;                           /* TRUE if using existing buffer */
  int auto_buf = FALSE;                 /* TRUE if autocommands brought us
                                           into the buffer unexpectedly */
  char_u      *new_name = NULL;
  int did_set_swapcommand = FALSE;
  buf_T       *buf;
  bufref_T     bufref;
  bufref_T     old_curbuf;
  char_u      *free_fname = NULL;
  int retval = FAIL;
  long n;
  pos_T orig_pos;
  linenr_T topline = 0;
  int newcol = -1;
  int solcol = -1;
  pos_T       *pos;
  char_u      *command = NULL;
  int did_get_winopts = FALSE;
  int readfile_flags = 0;
  bool did_inc_redrawing_disabled = false;

  if (eap != NULL)
    command = eap->do_ecmd_cmd;

  set_bufref(&old_curbuf, curbuf);

  if (fnum != 0) {
    if (fnum == curbuf->b_fnum)         /* file is already being edited */
      return OK;                        /* nothing to do */
    other_file = TRUE;
  } else {
    /* if no short name given, use ffname for short name */
    if (sfname == NULL)
      sfname = ffname;
#ifdef USE_FNAME_CASE
    if (sfname != NULL)
      path_fix_case(sfname);             // set correct case for sfname
#endif

    if ((flags & ECMD_ADDBUF) && (ffname == NULL || *ffname == NUL))
      goto theend;

    if (ffname == NULL)
      other_file = TRUE;
    /* there is no file name */
    else if (*ffname == NUL && curbuf->b_ffname == NULL)
      other_file = FALSE;
    else {
      if (*ffname == NUL) {                 /* re-edit with same file name */
        ffname = curbuf->b_ffname;
        sfname = curbuf->b_fname;
      }
      free_fname = (char_u *)fix_fname((char *)ffname);       /* may expand to full path name */
      if (free_fname != NULL)
        ffname = free_fname;
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

  /*
   * if the file was changed we may not be allowed to abandon it
   * - if we are going to re-edit the same file
   * - or if we are the only window on this file and if ECMD_HIDE is FALSE
   */
  if (  ((!other_file && !(flags & ECMD_OLDBUF))
         || (curbuf->b_nwindows == 1
             && !(flags & (ECMD_HIDE | ECMD_ADDBUF))))
        && check_changed(curbuf, (p_awa ? CCGD_AW : 0)
            | (other_file ? 0 : CCGD_MULTWIN)
            | ((flags & ECMD_FORCEIT) ? CCGD_FORCEIT : 0)
            | (eap == NULL ? 0 : CCGD_EXCMD))) {
    if (fnum == 0 && other_file && ffname != NULL)
      (void)setaltfname(ffname, sfname, newlnum < 0 ? 0 : newlnum);
    goto theend;
  }

  /*
   * End Visual mode before switching to another buffer, so the text can be
   * copied into the GUI selection buffer.
   */
  reset_VIsual();

  if ((command != NULL || newlnum > (linenr_T)0)
      && *get_vim_var_str(VV_SWAPCOMMAND) == NUL) {
    // Set v:swapcommand for the SwapExists autocommands.
    const size_t len = (command != NULL) ? STRLEN(command) + 3 : 30;
    char *const p = xmalloc(len);
    if (command != NULL) {
      vim_snprintf(p, len, ":%s\r", command);
    } else {
      vim_snprintf(p, len, "%" PRId64 "G", (int64_t)newlnum);
    }
    set_vim_var_string(VV_SWAPCOMMAND, p, -1);
    did_set_swapcommand = TRUE;
    xfree(p);
  }

  /*
   * If we are starting to edit another file, open a (new) buffer.
   * Otherwise we re-use the current buffer.
   */
  if (other_file) {
    if (!(flags & ECMD_ADDBUF)) {
      if (!cmdmod.keepalt)
        curwin->w_alt_fnum = curbuf->b_fnum;
      if (oldwin != NULL)
        buflist_altfpos(oldwin);
    }

    if (fnum) {
      buf = buflist_findnr(fnum);
    } else {
      if (flags & ECMD_ADDBUF) {
        linenr_T tlnum = 1L;

        if (command != NULL) {
          tlnum = atol((char *)command);
          if (tlnum <= 0)
            tlnum = 1L;
        }
        (void)buflist_new(ffname, sfname, tlnum, BLN_LISTED);
        goto theend;
      }
      buf = buflist_new(ffname, sfname, 0L,
                        BLN_CURBUF | (flags & ECMD_SET_HELP ? 0 : BLN_LISTED));
      // Autocmds may change curwin and curbuf.
      if (oldwin != NULL) {
        oldwin = curwin;
      }
      set_bufref(&old_curbuf, curbuf);
    }
    if (buf == NULL)
      goto theend;
    if (buf->b_ml.ml_mfp == NULL) {
      // No memfile yet.
      oldbuf = false;
    } else {
      // Existing memfile.
      oldbuf = true;
      set_bufref(&bufref, buf);
      (void)buf_check_timestamp(buf, false);
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

    /* May jump to last used line number for a loaded buffer or when asked
     * for explicitly */
    if ((oldbuf && newlnum == ECMD_LASTL) || newlnum == ECMD_LAST) {
      pos = buflist_findfpos(buf);
      newlnum = pos->lnum;
      solcol = pos->col;
    }

    /*
     * Make the (new) buffer the one used by the current window.
     * If the old buffer becomes unused, free it if ECMD_HIDE is FALSE.
     * If the current buffer was empty and has no file name, curbuf
     * is returned by buflist_new(), nothing to do here.
     */
    if (buf != curbuf) {
      /*
       * Be careful: The autocommands may delete any buffer and change
       * the current buffer.
       * - If the buffer we are going to edit is deleted, give up.
       * - If the current buffer is deleted, prefer to load the new
       *   buffer when loading a buffer is required.  This avoids
       *   loading another buffer which then must be closed again.
       * - If we ended up in the new buffer already, need to skip a few
       *	 things, set auto_buf.
       */
      if (buf->b_fname != NULL) {
        new_name = vim_strsave(buf->b_fname);
      }
      set_bufref(&au_new_curbuf, buf);
      apply_autocmds(EVENT_BUFLEAVE, NULL, NULL, false, curbuf);
      if (!bufref_valid(&au_new_curbuf)) {
        // New buffer has been deleted.
        delbuf_msg(new_name);  // Frees new_name.
        goto theend;
      }
      if (aborting()) {             /* autocmds may abort script processing */
        xfree(new_name);
        goto theend;
      }
      if (buf == curbuf) {  // already in new buffer
        auto_buf = true;
      } else {
        win_T *the_curwin = curwin;

        // Set w_closing to avoid that autocommands close the window.
        // Set b_locked for the same reason.
        the_curwin->w_closing = true;
        buf->b_locked++;

        if (curbuf == old_curbuf.br_buf) {
          buf_copy_options(buf, BCO_ENTER);
        }

        // Close the link to the current buffer. This will set
        // oldwin->w_buffer to NULL.
        u_sync(false);
        close_buffer(oldwin, curbuf,
                     (flags & ECMD_HIDE) || curbuf->terminal ? 0 : DOBUF_UNLOAD,
                     false);

        the_curwin->w_closing = false;
        buf->b_locked--;

        // autocmds may abort script processing
        if (aborting() && curwin->w_buffer != NULL) {
          xfree(new_name);
          goto theend;
        }
        // Be careful again, like above.
        if (!bufref_valid(&au_new_curbuf)) {
          // New buffer has been deleted.
          delbuf_msg(new_name);  // Frees new_name.
          goto theend;
        }
        if (buf == curbuf) {  // already in new buffer
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
          ++curbuf->b_nwindows;

          /* Set 'fileformat', 'binary' and 'fenc' when forced. */
          if (!oldbuf && eap != NULL) {
            set_file_options(TRUE, eap);
            set_forced_fenc(eap);
          }
        }

        /* May get the window options from the last time this buffer
         * was in this window (or another window).  If not used
         * before, reset the local window options to the global
         * values.  Also restores old folding stuff. */
        get_winopts(curbuf);
        did_get_winopts = TRUE;

      }
      xfree(new_name);
      au_new_curbuf.br_buf = NULL;
      au_new_curbuf.br_buf_free_count = 0;
    }

    curwin->w_pcmark.lnum = 1;
    curwin->w_pcmark.col = 0;
  } else {  // !other_file
    if ((flags & ECMD_ADDBUF)
        || check_fname() == FAIL) {
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
    set_buflisted(TRUE);
  }

  /* If autocommands change buffers under our fingers, forget about
   * editing the file. */
  if (buf != curbuf)
    goto theend;
  if (aborting())           /* autocmds may abort script processing */
    goto theend;

  /* Since we are starting to edit a file, consider the filetype to be
   * unset.  Helps for when an autocommand changes files and expects syntax
   * highlighting to work in the other file. */
  did_filetype = FALSE;

  /*
   * other_file	oldbuf
   *  FALSE	FALSE	    re-edit same file, buffer is re-used
   *  FALSE	TRUE	    re-edit same file, nothing changes
   *  TRUE	FALSE	    start editing new file, new buffer
   *  TRUE	TRUE	    start editing in existing buffer (nothing to do)
   */
  if (!other_file && !oldbuf) {         /* re-use the buffer */
    set_last_cursor(curwin);            /* may set b_last_cursor */
    if (newlnum == ECMD_LAST || newlnum == ECMD_LASTL) {
      newlnum = curwin->w_cursor.lnum;
      solcol = curwin->w_cursor.col;
    }
    buf = curbuf;
    if (buf->b_fname != NULL) {
      new_name = vim_strsave(buf->b_fname);
    } else {
      new_name = NULL;
    }
    set_bufref(&bufref, buf);
    if (p_ur < 0 || curbuf->b_ml.ml_line_count <= p_ur) {
      /* Save all the text, so that the reload can be undone.
       * Sync first so that this is a separate undo-able action. */
      u_sync(false);
      if (u_savecommon(0, curbuf->b_ml.ml_line_count + 1, 0, true)
          == FAIL) {
        xfree(new_name);
        goto theend;
      }
      u_unchanged(curbuf);
      buf_updates_unregister_all(curbuf);
      buf_freeall(curbuf, BFA_KEEP_UNDO);

      // Tell readfile() not to clear or reload undo info.
      readfile_flags = READ_KEEP_UNDO;
    } else {
      buf_freeall(curbuf, 0);  // Free all things for buffer.
    }
    // If autocommands deleted the buffer we were going to re-edit, give
    // up and jump to the end.
    if (!bufref_valid(&bufref)) {
      delbuf_msg(new_name);  // Frees new_name.
      goto theend;
    }
    xfree(new_name);

    /* If autocommands change buffers under our fingers, forget about
     * re-editing the file.  Should do the buf_clear_file(), but perhaps
     * the autocommands changed the buffer... */
    if (buf != curbuf)
      goto theend;
    if (aborting())         /* autocmds may abort script processing */
      goto theend;
    buf_clear_file(curbuf);
    curbuf->b_op_start.lnum = 0;        /* clear '[ and '] marks */
    curbuf->b_op_end.lnum = 0;
  }

  /*
   * If we get here we are sure to start editing
   */

  /* Assume success now */
  retval = OK;

  /*
   * Check if we are editing the w_arg_idx file in the argument list.
   */
  check_arg_idx(curwin);

  if (!auto_buf) {
    /*
     * Set cursor and init window before reading the file and executing
     * autocommands.  This allows for the autocommands to position the
     * cursor.
     */
    curwin_init();

    /* It's possible that all lines in the buffer changed.  Need to update
     * automatic folding for all windows where it's used. */
    FOR_ALL_TAB_WINDOWS(tp, win) {
      if (win->w_buffer == curbuf) {
        foldUpdateAll(win);
      }
    }

    /* Change directories when the 'acd' option is set. */
    do_autochdir();

    /*
     * Careful: open_buffer() and apply_autocmds() may change the current
     * buffer and window.
     */
    orig_pos = curwin->w_cursor;
    topline = curwin->w_topline;
    if (!oldbuf) {                          /* need to read the file */
      swap_exists_action = SEA_DIALOG;
      curbuf->b_flags |= BF_CHECK_RO;       /* set/reset 'ro' flag */

      /*
       * Open the buffer and read the file.
       */
      if (should_abort(open_buffer(FALSE, eap, readfile_flags)))
        retval = FAIL;

      if (swap_exists_action == SEA_QUIT)
        retval = FAIL;
      handle_swap_exists(&old_curbuf);
    } else {
      /* Read the modelines, but only to set window-local options.  Any
       * buffer-local options have already been set and may have been
       * changed by the user. */
      do_modelines(OPT_WINONLY);

      apply_autocmds_retval(EVENT_BUFENTER, NULL, NULL, FALSE, curbuf,
          &retval);
      apply_autocmds_retval(EVENT_BUFWINENTER, NULL, NULL, FALSE, curbuf,
          &retval);
    }
    check_arg_idx(curwin);

    // If autocommands change the cursor position or topline, we should keep
    // it.  Also when it moves within a line.
    if (!equalpos(curwin->w_cursor, orig_pos)) {
      newlnum = curwin->w_cursor.lnum;
      newcol = curwin->w_cursor.col;
    }
    if (curwin->w_topline == topline)
      topline = 0;

    /* Even when cursor didn't move we need to recompute topline. */
    changed_line_abv_curs();

    maketitle();
  }

  /* Tell the diff stuff that this buffer is new and/or needs updating.
   * Also needed when re-editing the same buffer, because unloading will
   * have removed it as a diff buffer. */
  if (curwin->w_p_diff) {
    diff_buf_add(curbuf);
    diff_invalidate(curbuf);
  }

  /* If the window options were changed may need to set the spell language.
   * Can only do this after the buffer has been properly setup. */
  if (did_get_winopts && curwin->w_p_spell && *curwin->w_s->b_p_spl != NUL)
    (void)did_set_spelllang(curwin);

  if (command == NULL) {
    if (newcol >= 0) {          /* position set by autocommands */
      curwin->w_cursor.lnum = newlnum;
      curwin->w_cursor.col = newcol;
      check_cursor();
    } else if (newlnum > 0) { /* line number from caller or old position */
      curwin->w_cursor.lnum = newlnum;
      check_cursor_lnum();
      if (solcol >= 0 && !p_sol) {
        /* 'sol' is off: Use last known column. */
        curwin->w_cursor.col = solcol;
        check_cursor_col();
        curwin->w_cursor.coladd = 0;
        curwin->w_set_curswant = TRUE;
      } else
        beginline(BL_SOL | BL_FIX);
    } else {                  /* no line number, go to last line in Ex mode */
      if (exmode_active)
        curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
      beginline(BL_WHITE | BL_FIX);
    }
  }

  /* Check if cursors in other windows on the same buffer are still valid */
  check_lnums(FALSE);

  /*
   * Did not read the file, need to show some info about the file.
   * Do this after setting the cursor.
   */
  if (oldbuf
      && !auto_buf
      ) {
    int msg_scroll_save = msg_scroll;

    /* Obey the 'O' flag in 'cpoptions': overwrite any previous file
     * message. */
    if (shortmess(SHM_OVERALL) && !exiting && p_verbose == 0)
      msg_scroll = FALSE;
    if (!msg_scroll)            /* wait a bit when overwriting an error msg */
      check_for_delay(FALSE);
    msg_start();
    msg_scroll = msg_scroll_save;
    msg_scrolled_ign = TRUE;

    if (!shortmess(SHM_FILEINFO)) {
      fileinfo(false, true, false);
    }

    msg_scrolled_ign = FALSE;
  }

  if (command != NULL)
    do_cmdline(command, NULL, NULL, DOCMD_VERBOSE);

  if (curbuf->b_kmap_state & KEYMAP_INIT)
    (void)keymap_init();

  RedrawingDisabled--;
  did_inc_redrawing_disabled = false;
  if (!skip_redraw) {
    n = p_so;
    if (topline == 0 && command == NULL)
      p_so = 999;        // force cursor to be vertically centered in the window
    update_topline();
    curwin->w_scbind_pos = curwin->w_topline;
    p_so = n;
    redraw_curbuf_later(NOT_VALID);     /* redraw this buffer later */
  }

  if (p_im)
    need_start_insertmode = TRUE;

  /* Change directories when the 'acd' option is set. */
  do_autochdir();


theend:
  if (did_inc_redrawing_disabled) {
    RedrawingDisabled--;
  }
  if (did_set_swapcommand) {
    set_vim_var_string(VV_SWAPCOMMAND, NULL, -1);
  }
  xfree(free_fname);
  return retval;
}

static void delbuf_msg(char_u *name)
{
  EMSG2(_("E143: Autocommands unexpectedly deleted new buffer %s"),
      name == NULL ? (char_u *)"" : name);
  xfree(name);
  au_new_curbuf.br_buf = NULL;
  au_new_curbuf.br_buf_free_count = 0;
}

static int append_indent = 0;       /* autoindent for first line */

/*
 * ":insert" and ":append", also used by ":change"
 */
void ex_append(exarg_T *eap)
{
  char_u      *theline;
  int did_undo = FALSE;
  linenr_T lnum = eap->line2;
  int indent = 0;
  char_u      *p;
  int vcol;
  int empty = (curbuf->b_ml.ml_flags & ML_EMPTY);

  /* the ! flag toggles autoindent */
  if (eap->forceit)
    curbuf->b_p_ai = !curbuf->b_p_ai;

  /* First autoindent comes from the line we start on */
  if (eap->cmdidx != CMD_change && curbuf->b_p_ai && lnum > 0)
    append_indent = get_indent_lnum(lnum);

  if (eap->cmdidx != CMD_append)
    --lnum;

  // when the buffer is empty need to delete the dummy line
  if (empty && lnum == 1)
    lnum = 0;

  State = INSERT;                   /* behave like in Insert mode */
  if (curbuf->b_p_iminsert == B_IMODE_LMAP)
    State |= LANGMAP;

  for (;; ) {
    msg_scroll = TRUE;
    need_wait_return = FALSE;
    if (curbuf->b_p_ai) {
      if (append_indent >= 0) {
        indent = append_indent;
        append_indent = -1;
      } else if (lnum > 0)
        indent = get_indent_lnum(lnum);
    }
    ex_keep_indent = FALSE;
    if (eap->getline == NULL) {
      /* No getline() function, use the lines that follow. This ends
       * when there is no more. */
      if (eap->nextcmd == NULL || *eap->nextcmd == NUL)
        break;
      p = vim_strchr(eap->nextcmd, NL);
      if (p == NULL)
        p = eap->nextcmd + STRLEN(eap->nextcmd);
      theline = vim_strnsave(eap->nextcmd, (int)(p - eap->nextcmd));
      if (*p != NUL)
        ++p;
      eap->nextcmd = p;
    } else {
      // Set State to avoid the cursor shape to be set to INSERT mode
      // when getline() returns.
      int save_State = State;
      State = CMDLINE;
      theline = eap->getline(
          eap->cstack->cs_looplevel > 0 ? -1 :
          NUL, eap->cookie, indent);
      State = save_State;
    }
    lines_left = Rows - 1;
    if (theline == NULL)
      break;

    /* Using ^ CTRL-D in getexmodeline() makes us repeat the indent. */
    if (ex_keep_indent)
      append_indent = indent;

    /* Look for the "." after automatic indent. */
    vcol = 0;
    for (p = theline; indent > vcol; ++p) {
      if (*p == ' ')
        ++vcol;
      else if (*p == TAB)
        vcol += 8 - vcol % 8;
      else
        break;
    }
    if ((p[0] == '.' && p[1] == NUL)
        || (!did_undo && u_save(lnum, lnum + 1 + (empty ? 1 : 0))
            == FAIL)) {
      xfree(theline);
      break;
    }

    /* don't use autoindent if nothing was typed. */
    if (p[0] == NUL)
      theline[0] = NUL;

    did_undo = TRUE;
    ml_append(lnum, theline, (colnr_T)0, FALSE);
    appended_lines_mark(lnum + (empty ? 1 : 0), 1L);

    xfree(theline);
    ++lnum;

    if (empty) {
      ml_delete(2L, FALSE);
      empty = FALSE;
    }
  }
  State = NORMAL;

  if (eap->forceit)
    curbuf->b_p_ai = !curbuf->b_p_ai;

  /* "start" is set to eap->line2+1 unless that position is invalid (when
   * eap->line2 pointed to the end of the buffer and nothing was appended)
   * "end" is set to lnum when something has been appended, otherwise
   * it is the same than "start"  -- Acevedo */
  curbuf->b_op_start.lnum = (eap->line2 < curbuf->b_ml.ml_line_count) ?
                            eap->line2 + 1 : curbuf->b_ml.ml_line_count;
  if (eap->cmdidx != CMD_append)
    --curbuf->b_op_start.lnum;
  curbuf->b_op_end.lnum = (eap->line2 < lnum)
                          ? lnum : curbuf->b_op_start.lnum;
  curbuf->b_op_start.col = curbuf->b_op_end.col = 0;
  curwin->w_cursor.lnum = lnum;
  check_cursor_lnum();
  beginline(BL_SOL | BL_FIX);

  need_wait_return = FALSE;     /* don't use wait_return() now */
  ex_no_reprint = TRUE;
}

/*
 * ":change"
 */
void ex_change(exarg_T *eap)
{
  linenr_T lnum;

  if (eap->line2 >= eap->line1
      && u_save(eap->line1 - 1, eap->line2 + 1) == FAIL)
    return;

  /* the ! flag toggles autoindent */
  if (eap->forceit ? !curbuf->b_p_ai : curbuf->b_p_ai)
    append_indent = get_indent_lnum(eap->line1);

  for (lnum = eap->line2; lnum >= eap->line1; --lnum) {
    if (curbuf->b_ml.ml_flags & ML_EMPTY)           /* nothing to delete */
      break;
    ml_delete(eap->line1, FALSE);
  }

  /* make sure the cursor is not beyond the end of the file now */
  check_cursor_lnum();
  deleted_lines_mark(eap->line1, (long)(eap->line2 - lnum));

  /* ":append" on the line above the deleted lines. */
  eap->line2 = eap->line1;
  ex_append(eap);
}

void ex_z(exarg_T *eap)
{
  char_u      *x;
  int64_t     bigness;
  char_u      *kind;
  int minus = 0;
  linenr_T start, end, curs, i;
  int j;
  linenr_T lnum = eap->line2;

  // Vi compatible: ":z!" uses display height, without a count uses
  // 'scroll'
  if (eap->forceit) {
    bigness = curwin->w_height;
  } else if (ONE_WINDOW) {
    bigness = curwin->w_p_scr * 2;
  } else {
    bigness = curwin->w_height - 3;
  }
  if (bigness < 1) {
    bigness = 1;
  }

  x = eap->arg;
  kind = x;
  if (*kind == '-' || *kind == '+' || *kind == '='
      || *kind == '^' || *kind == '.')
    ++x;
  while (*x == '-' || *x == '+')
    ++x;

  if (*x != 0) {
    if (!ascii_isdigit(*x)) {
      EMSG(_("E144: non-numeric argument to :z"));
      return;
    }
    bigness = atol((char *)x);

    // bigness could be < 0 if atol(x) overflows.
    if (bigness > 2 * curbuf->b_ml.ml_line_count || bigness < 0) {
      bigness = 2 * curbuf->b_ml.ml_line_count;
    }

    p_window = bigness;
    if (*kind == '=') {
      bigness += 2;
    }
  }

  /* the number of '-' and '+' multiplies the distance */
  if (*kind == '-' || *kind == '+')
    for (x = kind + 1; *x == *kind; ++x)
      ;

  switch (*kind) {
  case '-':
    start = lnum - bigness * (linenr_T)(x - kind) + 1;
    end = start + bigness - 1;
    curs = end;
    break;

  case '=':
    start = lnum - (bigness + 1) / 2 + 1;
    end = lnum + (bigness + 1) / 2 - 1;
    curs = lnum;
    minus = 1;
    break;

  case '^':
    start = lnum - bigness * 2;
    end = lnum - bigness;
    curs = lnum - bigness;
    break;

  case '.':
    start = lnum - (bigness + 1) / 2 + 1;
    end = lnum + (bigness + 1) / 2 - 1;
    curs = end;
    break;

  default:        /* '+' */
    start = lnum;
    if (*kind == '+')
      start += bigness * (linenr_T)(x - kind - 1) + 1;
    else if (eap->addr_count == 0)
      ++start;
    end = start + bigness - 1;
    curs = end;
    break;
  }

  if (start < 1)
    start = 1;

  if (end > curbuf->b_ml.ml_line_count)
    end = curbuf->b_ml.ml_line_count;

  if (curs > curbuf->b_ml.ml_line_count) {
    curs = curbuf->b_ml.ml_line_count;
  } else if (curs < 1) {
    curs = 1;
  }

  for (i = start; i <= end; i++) {
    if (minus && i == lnum) {
      msg_putchar('\n');

      for (j = 1; j < Columns; j++)
        msg_putchar('-');
    }

    print_line(i, eap->flags & EXFLAG_NR, eap->flags & EXFLAG_LIST);

    if (minus && i == lnum) {
      msg_putchar('\n');

      for (j = 1; j < Columns; j++)
        msg_putchar('-');
    }
  }

  if (curwin->w_cursor.lnum != curs) {
    curwin->w_cursor.lnum = curs;
    curwin->w_cursor.col = 0;
  }
  ex_no_reprint = true;
}

/*
 * Check if the restricted flag is set.
 * If so, give an error message and return TRUE.
 * Otherwise, return FALSE.
 */
int check_restricted(void)
{
  if (restricted) {
    EMSG(_("E145: Shell commands not allowed in restricted mode"));
    return TRUE;
  }
  return FALSE;
}

/*
 * Check if the secure flag is set (.exrc or .vimrc in current directory).
 * If so, give an error message and return TRUE.
 * Otherwise, return FALSE.
 */
int check_secure(void)
{
  if (secure) {
    secure = 2;
    EMSG(_(e_curdir));
    return TRUE;
  }

  // In the sandbox more things are not allowed, including the things
  // disallowed in secure mode.
  if (sandbox != 0) {
    EMSG(_(e_sandbox));
    return TRUE;
  }
  return FALSE;
}

/// Previous substitute replacement string
static SubReplacementString old_sub = {NULL, 0, NULL};

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
  if (sub.additional_elements != old_sub.additional_elements) {
    tv_list_unref(old_sub.additional_elements);
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
static bool sub_joining_lines(exarg_T *eap, char_u *pat, char_u *sub,
                              char_u *cmd, bool save)
  FUNC_ATTR_NONNULL_ARG(1, 3, 4)
{
  // TODO(vim): find a generic solution to make line-joining operations more
  // efficient, avoid allocating a string that grows in size.
  if (pat != NULL
      && strcmp((const char *)pat, "\\n") == 0
      && *sub == NUL
      && (*cmd == NUL || (cmd[1] == NUL
                          && (*cmd == 'g'
                              || *cmd == 'l'
                              || *cmd == 'p'
                              || *cmd == '#')))) {
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
      do_join(joined_lines_count, FALSE, TRUE, FALSE, true);
      sub_nsubs = joined_lines_count - 1;
      sub_nlines = 1;
      do_sub_msg(false);
      ex_may_print(eap);
    }

    if (save) {
      if (!cmdmod.keeppatterns) {
        save_re_pat(RE_SUBST, pat, p_magic);
      }
      add_to_history(HIST_SEARCH, pat, true, NUL);
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
/// @param[in,out]  new_start   pointer to the memory for the replacement text
/// @param[in]      needed_len  amount of memory needed
///
/// @returns pointer to the end of the allocated memory
static char_u *sub_grow_buf(char_u **new_start, int needed_len)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_NONNULL_RET
{
  int new_start_len = 0;
  char_u *new_end;
  if (*new_start == NULL) {
    // Get some space for a temporary buffer to do the
    // substitution into (and some extra space to avoid
    // too many calls to xmalloc()/free()).
    new_start_len = needed_len + 50;
    *new_start = xmalloc(new_start_len);
    **new_start = NUL;
    new_end = *new_start;
  } else {
    // Check if the temporary buffer is long enough to do the
    // substitution into.  If not, make it larger (with a bit
    // extra to avoid too many calls to xmalloc()/free()).
    size_t len = STRLEN(*new_start);
    needed_len += len;
    if (needed_len > new_start_len) {
      new_start_len = needed_len + 50;
      *new_start = xrealloc(*new_start, new_start_len);
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
static char_u *sub_parse_flags(char_u *cmd, subflags_T *subflags,
                               int *which_pat)
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

/// Perform a substitution from line eap->line1 to line eap->line2 using the
/// command pointed to by eap->arg which should be of the form:
///
/// /pattern/substitution/{flags}
///
/// The usual escapes are supported as described in the regexp docs.
///
/// @param do_buf_event If `true`, send buffer updates.
/// @return buffer used for 'inccommand' preview
static buf_T *do_sub(exarg_T *eap, proftime_T timeout,
                     bool do_buf_event)
{
  long i = 0;
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
  char_u *pat = NULL, *sub = NULL;  // init for GCC
  int delimiter;
  bool has_second_delim = false;
  int sublen;
  int got_quit = false;
  int got_match = false;
  int which_pat;
  char_u *cmd = eap->arg;
  linenr_T first_line = 0;  // first changed line
  linenr_T last_line= 0;    // below last changed line AFTER the change
  linenr_T old_line_count = curbuf->b_ml.ml_line_count;
  char_u *sub_firstline;    // allocated copy of first sub line
  bool endcolumn = false;   // cursor in last column when done
  PreviewLines preview_lines = { KV_INITIAL_VALUE, 0 };
  static int pre_src_id = 0;  // Source id for the preview highlight
  static int pre_hl_id = 0;
  buf_T *orig_buf = curbuf;  // save to reset highlighting
  pos_T old_cursor = curwin->w_cursor;
  int start_nsubs;
  int save_ma = 0;
  int save_b_changed = curbuf->b_changed;
  bool preview = (State & CMDPREVIEW);

  if (!global_busy) {
    sub_nsubs = 0;
    sub_nlines = 0;
  }
  start_nsubs = sub_nsubs;

  if (eap->cmdidx == CMD_tilde)
    which_pat = RE_LAST;        /* use last used regexp */
  else
    which_pat = RE_SUBST;       /* use last substitute regexp */

  /* new pattern and substitution */
  if (eap->cmd[0] == 's' && *cmd != NUL && !ascii_iswhite(*cmd)
      && vim_strchr((char_u *)"0123456789cegriIp|\"", *cmd) == NULL) {
    /* don't accept alphanumeric for separator */
    if (isalpha(*cmd)) {
      EMSG(_("E146: Regular expressions can't be delimited by letters"));
      return NULL;
    }
    /*
     * undocumented vi feature:
     *  "\/sub/" and "\?sub?" use last used search pattern (almost like
     *  //sub/r).  "\&sub&" use last substitute pattern (like //sub/).
     */
    if (*cmd == '\\') {
      ++cmd;
      if (vim_strchr((char_u *)"/?&", *cmd) == NULL) {
        EMSG(_(e_backslash));
        return NULL;
      }
      if (*cmd != '&') {
        which_pat = RE_SEARCH;              // use last '/' pattern
      }
      pat = (char_u *)"";                   // empty search pattern
      delimiter = *cmd++;                   // remember delimiter character
      has_second_delim = true;
    } else {          // find the end of the regexp
      if (p_altkeymap && curwin->w_p_rl) {
        lrF_sub(cmd);
      }
      which_pat = RE_LAST;                  // use last used regexp
      delimiter = *cmd++;                   // remember delimiter character
      pat = cmd;                            // remember start of search pat
      cmd = skip_regexp(cmd, delimiter, p_magic, &eap->arg);
      if (cmd[0] == delimiter) {            // end delimiter found
        *cmd++ = NUL;                       // replace it with a NUL
        has_second_delim = true;
      }
    }

    /*
     * Small incompatibility: vi sees '\n' as end of the command, but in
     * Vim we want to use '\n' to find/substitute a NUL.
     */
    sub = cmd;              /* remember the start of the substitution */

    while (cmd[0]) {
      if (cmd[0] == delimiter) {                /* end delimiter found */
        *cmd++ = NUL;                           /* replace it with a NUL */
        break;
      }
      if (cmd[0] == '\\' && cmd[1] != 0) {      // skip escaped characters
        cmd++;
      }
      MB_PTR_ADV(cmd);
    }

    if (!eap->skip && !preview) {
      sub_set_replacement((SubReplacementString) {
        .sub = xstrdup((char *) sub),
        .timestamp = os_time(),
        .additional_elements = NULL,
      });
    }
  } else if (!eap->skip) {    /* use previous pattern and substitution */
    if (old_sub.sub == NULL) {      /* there is no previous command */
      EMSG(_(e_nopresub));
      return NULL;
    }
    pat = NULL;                 /* search_regcomp() will use previous pattern */
    sub = (char_u *) old_sub.sub;

    /* Vi compatibility quirk: repeating with ":s" keeps the cursor in the
     * last column after using "$". */
    endcolumn = (curwin->w_curswant == MAXCOL);
  }

  if (sub_joining_lines(eap, pat, sub, cmd, !preview)) {
    return NULL;
  }

  cmd = sub_parse_flags(cmd, &subflags, &which_pat);

  bool save_do_all = subflags.do_all;  // remember user specified 'g' flag
  bool save_do_ask = subflags.do_ask;  // remember user specified 'c' flag

  // check for a trailing count
  cmd = skipwhite(cmd);
  if (ascii_isdigit(*cmd)) {
    i = getdigits_long(&cmd);
    if (i <= 0 && !eap->skip && subflags.do_error) {
      EMSG(_(e_zerocount));
      return NULL;
    }
    eap->line1 = eap->line2;
    eap->line2 += i - 1;
    if (eap->line2 > curbuf->b_ml.ml_line_count)
      eap->line2 = curbuf->b_ml.ml_line_count;
  }

  /*
   * check for trailing command or garbage
   */
  cmd = skipwhite(cmd);
  if (*cmd && *cmd != '"') {        /* if not end-of-line or comment */
    eap->nextcmd = check_nextcmd(cmd);
    if (eap->nextcmd == NULL) {
      EMSG(_(e_trailing));
      return NULL;
    }
  }

  if (eap->skip) {          // not executing commands, only parsing
    return NULL;
  }

  if (!subflags.do_count && !MODIFIABLE(curbuf)) {
    // Substitution is not allowed in non-'modifiable' buffer
    EMSG(_(e_modifiable));
    return NULL;
  }

  if (search_regcomp(pat, RE_SUBST, which_pat, (preview ? 0 : SEARCH_HIS),
                     &regmatch) == FAIL) {
    if (subflags.do_error) {
      EMSG(_(e_invcmd));
    }
    return NULL;
  }

  // the 'i' or 'I' flag overrules 'ignorecase' and 'smartcase'
  if (subflags.do_ic == kSubIgnoreCase) {
    regmatch.rmm_ic = true;
  } else if (subflags.do_ic == kSubMatchCase) {
    regmatch.rmm_ic = false;
  }

  sub_firstline = NULL;

  /*
   * ~ in the substitute pattern is replaced with the old pattern.
   * We do it here once to avoid it to be replaced over and over again.
   * But don't do it when it starts with "\=", then it's an expression.
   */
  if (!(sub[0] == '\\' && sub[1] == '='))
    sub = regtilde(sub, p_magic);

  // Check for a match on each line.
  // If preview: limit to max('cmdwinheight', viewport).
  linenr_T line2 = eap->line2;
  for (linenr_T lnum = eap->line1;
       lnum <= line2 && !got_quit && !aborting()
       && (!preview || preview_lines.lines_needed <= (linenr_T)p_cwh
           || lnum <= curwin->w_botline);
       lnum++) {
    long nmatch = vim_regexec_multi(&regmatch, curwin, curbuf, lnum,
                                    (colnr_T)0, NULL);
    if (nmatch) {
      colnr_T copycol;
      colnr_T matchcol;
      colnr_T prev_matchcol = MAXCOL;
      char_u      *new_end, *new_start = NULL;
      char_u      *p1;
      int did_sub = FALSE;
      int lastone;
      long nmatch_tl = 0;               // nr of lines matched below lnum
      int do_again;                     // do it again after joining lines
      int skip_match = false;
      linenr_T sub_firstlnum;           // nr of first sub line

      /*
       * The new text is build up step by step, to avoid too much
       * copying.  There are these pieces:
       * sub_firstline	The old text, unmodified.
       * copycol		Column in the old text where we started
       *			looking for a match; from here old text still
       *			needs to be copied to the new text.
       * matchcol		Column number of the old text where to look
       *			for the next match.  It's just after the
       *			previous match or one further.
       * prev_matchcol	Column just after the previous match (if any).
       *			Mostly equal to matchcol, except for the first
       *			match and after skipping an empty match.
       * regmatch.*pos	Where the pattern matched in the old text.
       * new_start	The new text, all that has been produced so
       *			far.
       * new_end		The new text, where to append new text.
       *
       * lnum		The line number where we found the start of
       *			the match.  Can be below the line we searched
       *			when there is a \n before a \zs in the
       *			pattern.
       * sub_firstlnum	The line number in the buffer where to look
       *			for a match.  Can be different from "lnum"
       *			when the pattern or substitute string contains
       *			line breaks.
       *
       * Special situations:
       * - When the substitute string contains a line break, the part up
       *   to the line break is inserted in the text, but the copy of
       *   the original line is kept.  "sub_firstlnum" is adjusted for
       *   the inserted lines.
       * - When the matched pattern contains a line break, the old line
       *   is taken from the line at the end of the pattern.  The lines
       *   in the match are deleted later, "sub_firstlnum" is adjusted
       *   accordingly.
       *
       * The new text is built up in new_start[].  It has some extra
       * room to avoid using xmalloc()/free() too often.
       *
       * Make a copy of the old line, so it won't be taken away when
       * updating the screen or handling a multi-line match.  The "old_"
       * pointers point into this copy.
       */
      sub_firstlnum = lnum;
      copycol = 0;
      matchcol = 0;

      /* At first match, remember current cursor position. */
      if (!got_match) {
        setpcmark();
        got_match = TRUE;
      }

      /*
       * Loop until nothing more to replace in this line.
       * 1. Handle match with empty string.
       * 2. If subflags.do_ask is set, ask for confirmation.
       * 3. substitute the string.
       * 4. if subflags.do_all is set, find next match
       * 5. break if there isn't another match in this line
       */
      for (;; ) {
        SubResult current_match = {
          .start = { 0, 0 },
          .end   = { 0, 0 },
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
          xfree(sub_firstline);
          sub_firstline = NULL;
        }

        // Now we're at the line where the pattern match starts
        // Note: If not first match on a line, column can't be known here
        current_match.start.lnum = sub_firstlnum;

        if (sub_firstline == NULL) {
          sub_firstline = vim_strsave(ml_get(sub_firstlnum));
        }

        /* Save the line number of the last change for the final
         * cursor position (just like Vi). */
        curwin->w_cursor.lnum = lnum;
        do_again = FALSE;

        /*
         * 1. Match empty string does not count, except for first
         * match.  This reproduces the strange vi behaviour.
         * This also catches endless loops.
         */
        if (matchcol == prev_matchcol
            && regmatch.endpos[0].lnum == 0
            && matchcol == regmatch.endpos[0].col) {
          if (sub_firstline[matchcol] == NUL)
            /* We already were at the end of the line.  Don't look
             * for a match in this line again. */
            skip_match = TRUE;
          else {
            /* search for a match at next column */
            if (has_mbyte)
              matchcol += mb_ptr2len(sub_firstline + matchcol);
            else
              ++matchcol;
          }
          // match will be pushed to preview_lines, bring it into a proper state
          current_match.start.col = matchcol;
          current_match.end.lnum = sub_firstlnum;
          current_match.end.col = matchcol;
          goto skip;
        }

        /* Normally we continue searching for a match just after the
         * previous match. */
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
            matchcol = (colnr_T)STRLEN(sub_firstline);
            nmatch = 1;
            skip_match = TRUE;
          }
          sub_nsubs++;
          did_sub = TRUE;
          /* Skip the substitution, unless an expression is used,
           * then it is evaluated in the sandbox. */
          if (!(sub[0] == '\\' && sub[1] == '='))
            goto skip;
        }

        if (subflags.do_ask && !preview) {
          int typed = 0;

          /* change State to CONFIRM, so that the mouse works
           * properly */
          int save_State = State;
          State = CONFIRM;
          setmouse();                   /* disable mouse in xterm */
          curwin->w_cursor.col = regmatch.startpos[0].col;

          if (curwin->w_p_crb) {
            do_check_cursorbind();
          }

          /* When 'cpoptions' contains "u" don't sync undo when
           * asking for confirmation. */
          if (vim_strchr(p_cpo, CPO_UNDO) != NULL)
            ++no_u_sync;

          /*
           * Loop until 'y', 'n', 'q', CTRL-E or CTRL-Y typed.
           */
          while (subflags.do_ask) {
            if (exmode_active) {
              char_u      *resp;
              colnr_T sc, ec;

              print_line_no_prefix(lnum, subflags.do_number, subflags.do_list);

              getvcol(curwin, &curwin->w_cursor, &sc, NULL, NULL);
              curwin->w_cursor.col = regmatch.endpos[0].col - 1;
              if (curwin->w_cursor.col < 0) {
                curwin->w_cursor.col = 0;
              }
              getvcol(curwin, &curwin->w_cursor, NULL, NULL, &ec);
              if (subflags.do_number || curwin->w_p_nu) {
                int numw = number_width(curwin) + 1;
                sc += numw;
                ec += numw;
              }
              msg_start();
              for (i = 0; i < (long)sc; ++i)
                msg_putchar(' ');
              for (; i <= (long)ec; ++i)
                msg_putchar('^');

              resp = getexmodeline('?', NULL, 0);
              if (resp != NULL) {
                typed = *resp;
                xfree(resp);
              }
            } else {
              char_u *orig_line = NULL;
              int len_change = 0;
              int save_p_fen = curwin->w_p_fen;

              curwin->w_p_fen = FALSE;
              /* Invert the matched string.
               * Remove the inversion afterwards. */
              int temp = RedrawingDisabled;
              RedrawingDisabled = 0;

              if (new_start != NULL) {
                /* There already was a substitution, we would
                 * like to show this to the user.  We cannot
                 * really update the line, it would change
                 * what matches.  Temporarily replace the line
                 * and change it back afterwards. */
                orig_line = vim_strsave(ml_get(lnum));
                char_u *new_line = concat_str(new_start, sub_firstline + copycol);

                // Position the cursor relative to the end of the line, the
                // previous substitute may have inserted or deleted characters
                // before the cursor.
                len_change = (int)STRLEN(new_line) - (int)STRLEN(orig_line);
                curwin->w_cursor.col += len_change;
                ml_replace(lnum, new_line, false);
              }

              search_match_lines = regmatch.endpos[0].lnum
                                   - regmatch.startpos[0].lnum;
              search_match_endcol = regmatch.endpos[0].col
                                    + len_change;
              highlight_match = TRUE;

              update_topline();
              validate_cursor();
              update_screen(SOME_VALID);
              highlight_match = FALSE;
              redraw_later(SOME_VALID);

              curwin->w_p_fen = save_p_fen;
              if (msg_row == Rows - 1)
                msg_didout = FALSE;                     /* avoid a scroll-up */
              msg_starthere();
              i = msg_scroll;
              msg_scroll = 0;                           /* truncate msg when
                                                           needed */
              msg_no_more = TRUE;
              /* write message same highlighting as for
               * wait_return */
              smsg_attr(HL_ATTR(HLF_R),
                        _("replace with %s (y/n/a/q/l/^E/^Y)?"), sub);
              msg_no_more = FALSE;
              msg_scroll = i;
              showruler(TRUE);
              ui_cursor_goto(msg_row, msg_col);
              RedrawingDisabled = temp;

              no_mapping++;                     // don't map this key
              typed = plain_vgetc();
              no_mapping--;

              /* clear the question */
              msg_didout = FALSE;               /* don't scroll up */
              msg_col = 0;
              gotocmdline(TRUE);

              // restore the line
              if (orig_line != NULL) {
                ml_replace(lnum, orig_line, false);
              }
            }

            need_wait_return = FALSE;             /* no hit-return prompt */
            if (typed == 'q' || typed == ESC || typed == Ctrl_C
#ifdef UNIX
                || typed == intr_char
#endif
                ) {
              got_quit = true;
              break;
            }
            if (typed == 'n')
              break;
            if (typed == 'y')
              break;
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
            if (typed == Ctrl_E)
              scrollup_clamp();
            else if (typed == Ctrl_Y)
              scrolldown_clamp();
          }
          State = save_State;
          setmouse();
          if (vim_strchr(p_cpo, CPO_UNDO) != NULL)
            --no_u_sync;

          if (typed == 'n') {
            /* For a multi-line match, put matchcol at the NUL at
             * the end of the line and set nmatch to one, so that
             * we continue looking for a match on the next line.
             * Avoids that ":%s/\nB\@=//gc" and ":%s/\n/,\r/gc"
             * get stuck when pressing 'n'. */
            if (nmatch > 1) {
              matchcol = (colnr_T)STRLEN(sub_firstline);
              skip_match = TRUE;
            }
            goto skip;
          }
          if (got_quit)
            goto skip;
        }

        /* Move the cursor to the start of the match, so that we can
         * use "\=col("."). */
        curwin->w_cursor.col = regmatch.startpos[0].col;

        // When the match included the "$" of the last line it may
        // go beyond the last line of the buffer.
        if (nmatch > curbuf->b_ml.ml_line_count - sub_firstlnum + 1) {
          nmatch = curbuf->b_ml.ml_line_count - sub_firstlnum + 1;
          current_match.end.lnum = sub_firstlnum + nmatch;
          skip_match = true;
        }

#define ADJUST_SUB_FIRSTLNUM() \
        do { \
          /* For a multi-line match, make a copy of the last matched */ \
          /* line and continue in that one. */ \
          if (nmatch > 1) { \
            sub_firstlnum += nmatch - 1; \
            xfree(sub_firstline); \
            sub_firstline = vim_strsave(ml_get(sub_firstlnum)); \
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
            sub_firstline = vim_strsave((char_u *)""); \
            copycol = 0; \
          } \
        } while (0)

        // Save the line numbers for the preview buffer
        // NOTE: If the pattern matches a final newline, the next line will
        // be shown also, but should not be highlighted. Intentional for now.
        if (preview && !has_second_delim) {
          current_match.start.col = regmatch.startpos[0].col;
          if (current_match.end.lnum == 0) {
            current_match.end.lnum = sub_firstlnum + nmatch - 1;
          }
          current_match.end.col  = regmatch.endpos[0].col;

          ADJUST_SUB_FIRSTLNUM();
          lnum += nmatch - 1;

          goto skip;
        }

        // 3. Substitute the string. During 'inccommand' preview only do this if
        //    there is a replace pattern.
        if (!preview || has_second_delim) {
          if (subflags.do_count) {
            // prevent accidentally changing the buffer by a function
            save_ma = curbuf->b_p_ma;
            curbuf->b_p_ma = false;
            sandbox++;
          }
          // Save flags for recursion.  They can change for e.g.
          // :s/^/\=execute("s#^##gn")
          subflags_T subflags_save = subflags;
          // get length of substitution part
          sublen = vim_regsub_multi(&regmatch,
                                    sub_firstlnum - regmatch.startpos[0].lnum,
                                    sub, sub_firstline, false, p_magic, true);
          // Don't keep flags set by a recursive call
          subflags = subflags_save;
          if (subflags.do_count) {
            curbuf->b_p_ma = save_ma;
            if (sandbox > 0) {
              sandbox--;
            }
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
            p1 = ml_get(sub_firstlnum + nmatch - 1);
            nmatch_tl += nmatch - 1;
          }
          size_t copy_len = regmatch.startpos[0].col - copycol;
          new_end = sub_grow_buf(&new_start,
                                 (STRLEN(p1) - regmatch.endpos[0].col)
                                 + copy_len + sublen + 1);

          // copy the text up to the part that matched
          memmove(new_end, sub_firstline + copycol, (size_t)copy_len);
          new_end += copy_len;

          // Finally, at this point we can know where the match actually will
          // start in the new text
          current_match.start.col = new_end - new_start;

          (void)vim_regsub_multi(&regmatch,
                                 sub_firstlnum - regmatch.startpos[0].lnum,
                                 sub, new_end, true, p_magic, true);
          sub_nsubs++;
          did_sub = true;

          // Move the cursor to the start of the line, to avoid that it
          // is beyond the end of the line after the substitution.
          curwin->w_cursor.col = 0;

          // Remember next character to be copied.
          copycol = regmatch.endpos[0].col;

          ADJUST_SUB_FIRSTLNUM();

          // Now the trick is to replace CTRL-M chars with a real line
          // break.  This would make it impossible to insert a CTRL-M in
          // the text.  The line break can be avoided by preceding the
          // CTRL-M with a backslash.  To be able to insert a backslash,
          // they must be doubled in the string and are halved here.
          // That is Vi compatible.
          for (p1 = new_end; *p1; p1++) {
            if (p1[0] == '\\' && p1[1] != NUL) {            // remove backslash
              STRMOVE(p1, p1 + 1);
            } else if (*p1 == CAR) {
              if (u_inssub(lnum) == OK) {             // prepare for undo
                *p1 = NUL;                            // truncate up to the CR
                ml_append(lnum - 1, new_start,
                          (colnr_T)(p1 - new_start + 1), false);
                mark_adjust(lnum + 1, (linenr_T)MAXLNUM, 1L, 0L, false);
                if (subflags.do_ask) {
                  appended_lines(lnum - 1, 1L);
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
            } else if (has_mbyte) {
              p1 += (*mb_ptr2len)(p1) - 1;
            }
          }
          current_match.end.col = STRLEN(new_start);
          current_match.end.lnum = lnum;
        }

        // 4. If subflags.do_all is set, find next match.
        // Prevent endless loop with patterns that match empty
        // strings, e.g. :s/$/pat/g or :s/[a-z]* /(&)/g.
        // But ":s/\n/#/" is OK.
skip:
        /* We already know that we did the last subst when we are at
         * the end of the line, except that a pattern like
         * "bar\|\nfoo" may match at the NUL.  "lnum" can be below
         * "line2" when there is a \zs in the pattern after a line
         * break. */
        lastone = (skip_match
                   || got_int
                   || got_quit
                   || lnum > line2
                   || !(subflags.do_all || do_again)
                   || (sub_firstline[matchcol] == NUL && nmatch <= 1
                       && !re_multiline(regmatch.regprog)));
        nmatch = -1;

        /*
         * Replace the line in the buffer when needed.  This is
         * skipped when there are more matches.
         * The check for nmatch_tl is needed for when multi-line
         * matching must replace the lines before trying to do another
         * match, otherwise "\@<=" won't work.
         * When the match starts below where we start searching also
         * need to replace the line first (using \zs after \n).
         */
        if (lastone
            || nmatch_tl > 0
            || (nmatch = vim_regexec_multi(&regmatch, curwin,
                    curbuf, sub_firstlnum,
                    matchcol, NULL)) == 0
            || regmatch.startpos[0].lnum > 0) {
          if (new_start != NULL) {
            /*
             * Copy the rest of the line, that didn't match.
             * "matchcol" has to be adjusted, we use the end of
             * the line as reference, because the substitute may
             * have changed the number of characters.  Same for
             * "prev_matchcol".
             */
            STRCAT(new_start, sub_firstline + copycol);
            matchcol = (colnr_T)STRLEN(sub_firstline) - matchcol;
            prev_matchcol = (colnr_T)STRLEN(sub_firstline)
                            - prev_matchcol;

            if (u_savesub(lnum) != OK) {
              break;
            }
            ml_replace(lnum, new_start, true);

            if (nmatch_tl > 0) {
              /*
               * Matched lines have now been substituted and are
               * useless, delete them.  The part after the match
               * has been appended to new_start, we don't need
               * it in the buffer.
               */
              ++lnum;
              if (u_savedel(lnum, nmatch_tl) != OK)
                break;
              for (i = 0; i < nmatch_tl; ++i)
                ml_delete(lnum, (int)FALSE);
              mark_adjust(lnum, lnum + nmatch_tl - 1,
                          (long)MAXLNUM, -nmatch_tl, false);
              if (subflags.do_ask) {
                deleted_lines(lnum, nmatch_tl);
              }
              lnum--;
              line2 -= nmatch_tl;  // nr of lines decreases
              nmatch_tl = 0;
            }

            /* When asking, undo is saved each time, must also set
             * changed flag each time. */
            if (subflags.do_ask) {
              changed_bytes(lnum, 0);
            } else {
              if (first_line == 0) {
                first_line = lnum;
              }
              last_line = lnum + 1;
            }

            sub_firstlnum = lnum;
            xfree(sub_firstline);                /* free the temp buffer */
            sub_firstline = new_start;
            new_start = NULL;
            matchcol = (colnr_T)STRLEN(sub_firstline) - matchcol;
            prev_matchcol = (colnr_T)STRLEN(sub_firstline)
                            - prev_matchcol;
            copycol = 0;
          }
          if (nmatch == -1 && !lastone)
            nmatch = vim_regexec_multi(&regmatch, curwin, curbuf,
                sub_firstlnum, matchcol, NULL);

          /*
           * 5. break if there isn't another match in this line
           */
          if (nmatch <= 0) {
            /* If the match found didn't start where we were
             * searching, do the next search in the line where we
             * found the match. */
            if (nmatch == -1)
              lnum -= regmatch.startpos[0].lnum;

#define PUSH_PREVIEW_LINES() \
            do { \
              linenr_T match_lines = current_match.end.lnum \
                                     - current_match.start.lnum +1; \
              if (preview_lines.subresults.size > 0) { \
                linenr_T last = kv_last(preview_lines.subresults).end.lnum; \
                if (last == current_match.start.lnum) { \
                  preview_lines.lines_needed += match_lines - 1; \
                } \
              } else { \
                preview_lines.lines_needed += match_lines; \
              } \
              kv_push(preview_lines.subresults, current_match); \
            } while (0)

            // Push the match to preview_lines.
            PUSH_PREVIEW_LINES();

            break;
          }
        }
        // Push the match to preview_lines.
        PUSH_PREVIEW_LINES();

        line_breakcheck();
      }

      if (did_sub)
        ++sub_nlines;
      xfree(new_start);              /* for when substitute was cancelled */
      xfree(sub_firstline);          /* free the copy of the original line */
      sub_firstline = NULL;
    }

    line_breakcheck();

    if (profile_passed_limit(timeout)) {
      got_quit = true;
    }
  }

  if (first_line != 0) {
    /* Need to subtract the number of added lines from "last_line" to get
     * the line number before the change (same as adding the number of
     * deleted lines). */
    i = curbuf->b_ml.ml_line_count - old_line_count;
    changed_lines(first_line, 0, last_line - i, i, false);

    if (kv_size(curbuf->update_channels)) {
      int64_t num_added = last_line - first_line;
      int64_t num_removed = num_added - i;
      buf_updates_send_changes(curbuf, first_line, num_added, num_removed,
                               do_buf_event);
    }
  }

  xfree(sub_firstline);   /* may have to free allocated copy of the line */

  // ":s/pat//n" doesn't move the cursor
  if (subflags.do_count) {
    curwin->w_cursor = old_cursor;
  }

  if (sub_nsubs > start_nsubs) {
    /* Set the '[ and '] marks. */
    curbuf->b_op_start.lnum = eap->line1;
    curbuf->b_op_end.lnum = line2;
    curbuf->b_op_start.col = curbuf->b_op_end.col = 0;

    if (!global_busy) {
      // when interactive leave cursor on the match
      if (!subflags.do_ask) {
        if (endcolumn) {
          coladvance((colnr_T)MAXCOL);
        } else {
          beginline(BL_WHITE | BL_FIX);
        }
      }
      if (!preview && !do_sub_msg(subflags.do_count) && subflags.do_ask) {
        MSG("");
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
      EMSG(_(e_interr));
    } else if (got_match) {
      // did find something but nothing substituted
      MSG("");
    } else if (subflags.do_error) {
      // nothing found
      EMSG2(_(e_patnotf2), get_search_pat());
    }
  }

  if (subflags.do_ask && hasAnyFolding(curwin)) {
    // Cursor position may require updating
    changed_window_setting();
  }

  vim_regfree(regmatch.regprog);

  // Restore the flag values, they can be used for ":&&".
  subflags.do_all = save_do_all;
  subflags.do_ask = save_do_ask;

  // Show 'inccommand' preview if there are matched lines.
  buf_T *preview_buf = NULL;
  size_t subsize = preview_lines.subresults.size;
  if (preview && !aborting()) {
    if (got_quit) {  // Substitution is too slow, disable 'inccommand'.
      set_string_option_direct((char_u *)"icm", -1, (char_u *)"", OPT_FREE,
                               SID_NONE);
    } else if (*p_icm != NUL &&  pat != NULL) {
      if (pre_src_id == 0) {
        // Get a unique new src_id, saved in a static
        pre_src_id = bufhl_add_hl(NULL, 0, -1, 0, 0, 0);
      }
      if (pre_hl_id == 0) {
        pre_hl_id = syn_check_group((char_u *)S_LEN("Substitute"));
      }
      curbuf->b_changed = save_b_changed;  // preserve 'modified' during preview
      preview_buf = show_sub(eap, old_cursor, &preview_lines,
                             pre_hl_id, pre_src_id);
      if (subsize > 0) {
        bufhl_clear_line_range(orig_buf, pre_src_id, eap->line1,
                               kv_last(preview_lines.subresults).end.lnum);
      }
    }
  }

  kv_destroy(preview_lines.subresults);

  return preview_buf;
#undef ADJUST_SUB_FIRSTLNUM
#undef PUSH_PREVIEW_LINES
}  // NOLINT(readability/fn_size)

/*
 * Give message for number of substitutions.
 * Can also be used after a ":global" command.
 * Return TRUE if a message was given.
 */
bool
do_sub_msg (
    bool count_only                /* used 'n' flag for ":s" */
)
{
  /*
   * Only report substitutions when:
   * - more than 'report' substitutions
   * - command was typed by user, or number of changed lines > 'report'
   * - giving messages is not disabled by 'lazyredraw'
   */
  if (((sub_nsubs > p_report && (KeyTyped || sub_nlines > 1 || p_report < 1))
       || count_only)
      && messaging()) {
    if (got_int)
      STRCPY(msg_buf, _("(Interrupted) "));
    else
      *msg_buf = NUL;
    if (sub_nsubs == 1)
      vim_snprintf_add((char *)msg_buf, sizeof(msg_buf),
          "%s", count_only ? _("1 match") : _("1 substitution"));
    else
      vim_snprintf_add((char *)msg_buf, sizeof(msg_buf),
          count_only ? _("%" PRId64 " matches")
                     : _("%" PRId64 " substitutions"),
          (int64_t)sub_nsubs);
    if (sub_nlines == 1)
      vim_snprintf_add((char *)msg_buf, sizeof(msg_buf),
          "%s", _(" on 1 line"));
    else
      vim_snprintf_add((char *)msg_buf, sizeof(msg_buf),
          _(" on %" PRId64 " lines"), (int64_t)sub_nlines);
    if (msg(msg_buf))
      /* save message to display it after redraw */
      set_keep_msg(msg_buf, 0);
    return true;
  }
  if (got_int) {
    EMSG(_(e_interr));
    return true;
  }
  return false;
}

static void global_exe_one(char_u *const cmd, const linenr_T lnum)
{
  curwin->w_cursor.lnum = lnum;
  curwin->w_cursor.col = 0;
  if (*cmd == NUL || *cmd == '\n') {
    do_cmdline((char_u *)"p", NULL, NULL, DOCMD_NOWAIT);
  } else {
    do_cmdline(cmd, NULL, NULL, DOCMD_NOWAIT);
  }
}

/*
 * Execute a global command of the form:
 *
 * g/pattern/X : execute X on all lines where pattern matches
 * v/pattern/X : execute X on all lines where pattern does not match
 *
 * where 'X' is an EX command
 *
 * The command character (as well as the trailing slash) is optional, and
 * is assumed to be 'p' if missing.
 *
 * This is implemented in two passes: first we scan the file for the pattern and
 * set a mark for each line that (not) matches. Secondly we execute the command
 * for each line that has a mark. This is required because after deleting
 * lines we do not know where to search for the next match.
 */
void ex_global(exarg_T *eap)
{
  linenr_T lnum;                /* line number according to old situation */
  int ndone = 0;
  int type;                     /* first char of cmd: 'v' or 'g' */
  char_u      *cmd;             /* command argument */

  char_u delim;                 /* delimiter, normally '/' */
  char_u      *pat;
  regmmatch_T regmatch;
  int match;
  int which_pat;

  // When nesting the command works on one line.  This allows for
  // ":g/found/v/notfound/command".
  if (global_busy && (eap->line1 != 1
                      || eap->line2 != curbuf->b_ml.ml_line_count)) {
    // will increment global_busy to break out of the loop
    EMSG(_("E147: Cannot do :global recursive with a range"));
    return;
  }

  if (eap->forceit)                 /* ":global!" is like ":vglobal" */
    type = 'v';
  else
    type = *eap->cmd;
  cmd = eap->arg;
  which_pat = RE_LAST;              /* default: use last used regexp */

  /*
   * undocumented vi feature:
   *	"\/" and "\?": use previous search pattern.
   *		 "\&": use previous substitute pattern.
   */
  if (*cmd == '\\') {
    ++cmd;
    if (vim_strchr((char_u *)"/?&", *cmd) == NULL) {
      EMSG(_(e_backslash));
      return;
    }
    if (*cmd == '&')
      which_pat = RE_SUBST;             /* use previous substitute pattern */
    else
      which_pat = RE_SEARCH;            /* use previous search pattern */
    ++cmd;
    pat = (char_u *)"";
  } else if (*cmd == NUL) {
    EMSG(_("E148: Regular expression missing from global"));
    return;
  } else {
    delim = *cmd;               /* get the delimiter */
    if (delim)
      ++cmd;                    /* skip delimiter if there is one */
    pat = cmd;                  /* remember start of pattern */
    cmd = skip_regexp(cmd, delim, p_magic, &eap->arg);
    if (cmd[0] == delim)                    /* end delimiter found */
      *cmd++ = NUL;                         /* replace it with a NUL */
  }

  if (p_altkeymap && curwin->w_p_rl)
    lrFswap(pat,0);

  if (search_regcomp(pat, RE_BOTH, which_pat, SEARCH_HIS, &regmatch) == FAIL) {
    EMSG(_(e_invcmd));
    return;
  }

  if (global_busy) {
    lnum = curwin->w_cursor.lnum;
    match = vim_regexec_multi(&regmatch, curwin, curbuf, lnum,
                              (colnr_T)0, NULL);
    if ((type == 'g' && match) || (type == 'v' && !match)) {
      global_exe_one(cmd, lnum);
    }
  } else {
    // pass 1: set marks for each (not) matching line
    for (lnum = eap->line1; lnum <= eap->line2 && !got_int; lnum++) {
      // a match on this line?
      match = vim_regexec_multi(&regmatch, curwin, curbuf, lnum,
                                (colnr_T)0, NULL);
      if ((type == 'g' && match) || (type == 'v' && !match)) {
        ml_setmarked(lnum);
        ndone++;
      }
      line_breakcheck();
    }

    // pass 2: execute the command for each line that has been marked
    if (got_int) {
      MSG(_(e_interr));
    } else if (ndone == 0) {
      if (type == 'v') {
        smsg(_("Pattern found in every line: %s"), pat);
      } else {
        smsg(_("Pattern not found: %s"), pat);
      }
    } else {
      global_exe(cmd);
    }
    ml_clearmarked();         // clear rest of the marks
  }
  vim_regfree(regmatch.regprog);
}

/// Execute `cmd` on lines marked with ml_setmarked().
void global_exe(char_u *cmd)
{
  linenr_T old_lcount;      // b_ml.ml_line_count before the command
  buf_T *old_buf = curbuf;  // remember what buffer we started in
  linenr_T lnum;            // line number according to old situation
  int save_mapped_ctrl_c = mapped_ctrl_c;

  // Set current position only once for a global command.
  // If global_busy is set, setpcmark() will not do anything.
  // If there is an error, global_busy will be incremented.
  setpcmark();

  // When the command writes a message, don't overwrite the command.
  msg_didout = true;
  // Disable CTRL-C mapping, let it interrupt (potentially long output).
  mapped_ctrl_c = 0;

  sub_nsubs = 0;
  sub_nlines = 0;
  global_need_beginline = false;
  global_busy = 1;
  old_lcount = curbuf->b_ml.ml_line_count;

  while (!got_int && (lnum = ml_firstmarked()) != 0 && global_busy == 1) {
    global_exe_one(cmd, lnum);
    os_breakcheck();
  }

  mapped_ctrl_c = save_mapped_ctrl_c;
  global_busy = 0;
  if (global_need_beginline) {
    beginline(BL_WHITE | BL_FIX);
  } else {
    check_cursor();  // cursor may be beyond the end of the line
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
  sub_set_replacement((SubReplacementString) {NULL, 0, NULL});
}

#endif

/*
 * Set up for a tagpreview.
 * Return TRUE when it was created.
 */
bool
prepare_tagpreview (
    bool undo_sync                  /* sync undo when leaving the window */
)
{
  /*
   * If there is already a preview window open, use that one.
   */
  if (!curwin->w_p_pvw) {
    bool found_win = false;
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp->w_p_pvw) {
        win_enter(wp, undo_sync);
        found_win = true;
        break;
      }
    }
    if (!found_win) {
      /*
       * There is no preview window open yet.  Create one.
       */
      if (win_split(g_do_tagpreview > 0 ? g_do_tagpreview : 0, 0)
          == FAIL)
        return false;
      curwin->w_p_pvw = TRUE;
      curwin->w_p_wfh = TRUE;
      RESET_BINDING(curwin);                /* don't take over 'scrollbind'
                                               and 'cursorbind' */
      curwin->w_p_diff = FALSE;             /* no 'diff' */
      curwin->w_p_fdc = 0;                  /* no 'foldcolumn' */
      return true;
    }
  }
  return false;
}



/*
 * ":help": open a read-only window on a help file
 */
void ex_help(exarg_T *eap)
{
  char_u      *arg;
  char_u      *tag;
  FILE        *helpfd;          /* file descriptor of help file */
  int n;
  int i;
  win_T       *wp;
  int num_matches;
  char_u      **matches;
  char_u      *p;
  int empty_fnum = 0;
  int alt_fnum = 0;
  buf_T       *buf;
  int len;
  char_u      *lang;
  int old_KeyTyped = KeyTyped;

  if (eap != NULL) {
    /*
     * A ":help" command ends at the first LF, or at a '|' that is
     * followed by some text.  Set nextcmd to the following command.
     */
    for (arg = eap->arg; *arg; ++arg) {
      if (*arg == '\n' || *arg == '\r'
          || (*arg == '|' && arg[1] != NUL && arg[1] != '|')) {
        *arg++ = NUL;
        eap->nextcmd = arg;
        break;
      }
    }
    arg = eap->arg;

    if (eap->forceit && *arg == NUL && !curbuf->b_help) {
      EMSG(_("E478: Don't panic!"));
      return;
    }

    if (eap->skip)          /* not executing commands */
      return;
  } else
    arg = (char_u *)"";

  /* remove trailing blanks */
  p = arg + STRLEN(arg) - 1;
  while (p > arg && ascii_iswhite(*p) && p[-1] != '\\')
    *p-- = NUL;

  /* Check for a specified language */
  lang = check_help_lang(arg);

  /* When no argument given go to the index. */
  if (*arg == NUL)
    arg = (char_u *)"help.txt";

  /*
   * Check if there is a match for the argument.
   */
  n = find_help_tags(arg, &num_matches, &matches,
      eap != NULL && eap->forceit);

  i = 0;
  if (n != FAIL && lang != NULL)
    /* Find first item with the requested language. */
    for (i = 0; i < num_matches; ++i) {
      len = (int)STRLEN(matches[i]);
      if (len > 3 && matches[i][len - 3] == '@'
          && STRICMP(matches[i] + len - 2, lang) == 0)
        break;
    }
  if (i >= num_matches || n == FAIL) {
    if (lang != NULL)
      EMSG3(_("E661: Sorry, no '%s' help for %s"), lang, arg);
    else
      EMSG2(_("E149: Sorry, no help for %s"), arg);
    if (n != FAIL)
      FreeWild(num_matches, matches);
    return;
  }

  /* The first match (in the requested language) is the best match. */
  tag = vim_strsave(matches[i]);
  FreeWild(num_matches, matches);

  /*
   * Re-use an existing help window or open a new one.
   * Always open a new one for ":tab help".
   */
  if (!bt_help(curwin->w_buffer)
      || cmdmod.tab != 0
      ) {
    if (cmdmod.tab != 0) {
      wp = NULL;
    } else {
      wp = NULL;
      FOR_ALL_WINDOWS_IN_TAB(wp2, curtab) {
        if (bt_help(wp2->w_buffer)) {
          wp = wp2;
          break;
        }
      }
    }
    if (wp != NULL && wp->w_buffer->b_nwindows > 0) {
      win_enter(wp, true);
    } else {
      // There is no help window yet.
      // Try to open the file specified by the "helpfile" option.
      if ((helpfd = mch_fopen((char *)p_hf, READBIN)) == NULL) {
        smsg(_("Sorry, help file \"%s\" not found"), p_hf);
        goto erret;
      }
      fclose(helpfd);

      /* Split off help window; put it at far top if no position
       * specified, the current window is vertically split and
       * narrow. */
      n = WSP_HELP;
      if (cmdmod.split == 0 && curwin->w_width != Columns
          && curwin->w_width < 80)
        n |= WSP_TOP;
      if (win_split(0, n) == FAIL)
        goto erret;

      if (curwin->w_height < p_hh)
        win_setheight((int)p_hh);

      /*
       * Open help file (do_ecmd() will set b_help flag, readfile() will
       * set b_p_ro flag).
       * Set the alternate file to the previously edited file.
       */
      alt_fnum = curbuf->b_fnum;
      (void)do_ecmd(0, NULL, NULL, NULL, ECMD_LASTL,
          ECMD_HIDE + ECMD_SET_HELP,
          NULL                  /* buffer is still open, don't store info */
          );
      if (!cmdmod.keepalt)
        curwin->w_alt_fnum = alt_fnum;
      empty_fnum = curbuf->b_fnum;
    }
  }

  if (!p_im)
    restart_edit = 0;               /* don't want insert mode in help file */

  /* Restore KeyTyped, setting 'filetype=help' may reset it.
   * It is needed for do_tag top open folds under the cursor. */
  KeyTyped = old_KeyTyped;

  do_tag(tag, DT_HELP, 1, FALSE, TRUE);

  /* Delete the empty buffer if we're not using it.  Careful: autocommands
   * may have jumped to another window, check that the buffer is not in a
   * window. */
  if (empty_fnum != 0 && curbuf->b_fnum != empty_fnum) {
    buf = buflist_findnr(empty_fnum);
    if (buf != NULL && buf->b_nwindows == 0)
      wipe_buffer(buf, TRUE);
  }

  /* keep the previous alternate file */
  if (alt_fnum != 0 && curwin->w_alt_fnum == empty_fnum && !cmdmod.keepalt)
    curwin->w_alt_fnum = alt_fnum;

erret:
  xfree(tag);
}


/*
 * In an argument search for a language specifiers in the form "@xx".
 * Changes the "@" to NUL if found, and returns a pointer to "xx".
 * Returns NULL if not found.
 */
char_u *check_help_lang(char_u *arg)
{
  int len = (int)STRLEN(arg);

  if (len >= 3 && arg[len - 3] == '@' && ASCII_ISALPHA(arg[len - 2])
      && ASCII_ISALPHA(arg[len - 1])) {
    arg[len - 3] = NUL;                 /* remove the '@' */
    return arg + len - 2;
  }
  return NULL;
}

/*
 * Return a heuristic indicating how well the given string matches.  The
 * smaller the number, the better the match.  This is the order of priorities,
 * from best match to worst match:
 *	- Match with least alpha-numeric characters is better.
 *	- Match with least total characters is better.
 *	- Match towards the start is better.
 *	- Match starting with "+" is worse (feature instead of command)
 * Assumption is made that the matched_string passed has already been found to
 * match some string for which help is requested.  webb.
 */
int
help_heuristic(
    char_u *matched_string,
    int offset,                             // offset for match
    int wrong_case                          // no matching case
)
{
  int num_letters;
  char_u      *p;

  num_letters = 0;
  for (p = matched_string; *p; p++)
    if (ASCII_ISALNUM(*p))
      num_letters++;

  /*
   * Multiply the number of letters by 100 to give it a much bigger
   * weighting than the number of characters.
   * If there only is a match while ignoring case, add 5000.
   * If the match starts in the middle of a word, add 10000 to put it
   * somewhere in the last half.
   * If the match is more than 2 chars from the start, multiply by 200 to
   * put it after matches at the start.
   */
  if (ASCII_ISALNUM(matched_string[offset]) && offset > 0
      && ASCII_ISALNUM(matched_string[offset - 1]))
    offset += 10000;
  else if (offset > 2)
    offset *= 200;
  if (wrong_case)
    offset += 5000;
  /* Features are less interesting than the subjects themselves, but "+"
   * alone is not a feature. */
  if (matched_string[0] == '+' && matched_string[1] != NUL)
    offset += 100;
  return (int)(100 * num_letters + STRLEN(matched_string) + offset);
}

/*
 * Compare functions for qsort() below, that checks the help heuristics number
 * that has been put after the tagname by find_tags().
 */
static int help_compare(const void *s1, const void *s2)
{
  char    *p1;
  char    *p2;

  p1 = *(char **)s1 + strlen(*(char **)s1) + 1;
  p2 = *(char **)s2 + strlen(*(char **)s2) + 1;
  return strcmp(p1, p2);
}

// Find all help tags matching "arg", sort them and return in matches[], with
// the number of matches in num_matches.
// The matches will be sorted with a "best" match algorithm.
// When "keep_lang" is true try keeping the language of the current buffer.
int find_help_tags(const char_u *arg, int *num_matches, char_u ***matches,
                   bool keep_lang)
{
  int i;
  static const char *(mtable[]) = {
      "*", "g*", "[*", "]*",
      "/*", "/\\*", "\"*", "**",
      "/\\(\\)", "/\\%(\\)",
      "?", ":?", "?<CR>", "g?", "g?g?", "g??",
      "-?", "q?", "v_g?",
      "/\\?", "/\\z(\\)", "\\=", ":s\\=",
      "[count]", "[quotex]",
      "[range]", ":[range]",
      "[pattern]", "\\|", "\\%$",
      "s/\\~", "s/\\U", "s/\\L",
      "s/\\1", "s/\\2", "s/\\3", "s/\\9"
  };
  static const char *(rtable[]) = {
      "star", "gstar", "[star", "]star",
      "/star", "/\\\\star", "quotestar", "starstar",
      "/\\\\(\\\\)", "/\\\\%(\\\\)",
      "?", ":?", "?<CR>", "g?", "g?g?", "g??",
      "-?", "q?", "v_g?",
      "/\\\\?", "/\\\\z(\\\\)", "\\\\=", ":s\\\\=",
      "\\[count]", "\\[quotex]",
      "\\[range]", ":\\[range]",
      "\\[pattern]", "\\\\bar", "/\\\\%\\$",
      "s/\\\\\\~", "s/\\\\U", "s/\\\\L",
      "s/\\\\1", "s/\\\\2", "s/\\\\3", "s/\\\\9"
  };
  static const char *(expr_table[]) = {
      "!=?", "!~?", "<=?", "<?", "==?", "=~?",
      ">=?", ">?", "is?", "isnot?"
  };
  char_u *d = IObuff;       // assume IObuff is long enough!

  if (STRNICMP(arg, "expr-", 5) == 0) {
    // When the string starting with "expr-" and containing '?' and matches
    // the table, it is taken literally.  Otherwise '?' is recognized as a
    // wildcard.
    for (i = (int)ARRAY_SIZE(expr_table); --i >= 0; ) {
      if (STRCMP(arg + 5, expr_table[i]) == 0) {
        STRCPY(d, arg);
        break;
      }
    }
  } else {
    // Recognize a few exceptions to the rule.  Some strings that contain
    // '*' with "star".  Otherwise '*' is recognized as a wildcard.
    for (i = (int)ARRAY_SIZE(mtable); --i >= 0; ) {
      if (STRCMP(arg, mtable[i]) == 0) {
        STRCPY(d, rtable[i]);
        break;
      }
    }
  }

  if (i < 0) {  /* no match in table */
    /* Replace "\S" with "/\\S", etc.  Otherwise every tag is matched.
     * Also replace "\%^" and "\%(", they match every tag too.
     * Also "\zs", "\z1", etc.
     * Also "\@<", "\@=", "\@<=", etc.
     * And also "\_$" and "\_^". */
    if (arg[0] == '\\'
        && ((arg[1] != NUL && arg[2] == NUL)
            || (vim_strchr((char_u *)"%_z@", arg[1]) != NULL
                && arg[2] != NUL))) {
      STRCPY(d, "/\\\\");
      STRCPY(d + 3, arg + 1);
      /* Check for "/\\_$", should be "/\\_\$" */
      if (d[3] == '_' && d[4] == '$')
        STRCPY(d + 4, "\\$");
    } else {
      /* Replace:
       * "[:...:]" with "\[:...:]"
       * "[++...]" with "\[++...]"
       * "\{" with "\\{"               -- matching "} \}"
       */
      if ((arg[0] == '[' && (arg[1] == ':'
                             || (arg[1] == '+' && arg[2] == '+')))
          || (arg[0] == '\\' && arg[1] == '{'))
        *d++ = '\\';

      // If tag starts with "('", skip the "(". Fixes CTRL-] on ('option'.
      if (*arg == '(' && arg[1] == '\'') {
          arg++;
      }
      for (const char_u *s = arg; *s; s++) {
        // Replace "|" with "bar" and '"' with "quote" to match the name of
        // the tags for these commands.
        // Replace "*" with ".*" and "?" with "." to match command line
        // completion.
        // Insert a backslash before '~', '$' and '.' to avoid their
        // special meaning.
        if (d - IObuff > IOSIZE - 10) {           // getting too long!?
          break;
        }
        switch (*s) {
        case '|':   STRCPY(d, "bar");
          d += 3;
          continue;
        case '"':   STRCPY(d, "quote");
          d += 5;
          continue;
        case '*':   *d++ = '.';
          break;
        case '?':   *d++ = '.';
          continue;
        case '$':
        case '.':
        case '~':   *d++ = '\\';
          break;
        }

        /*
         * Replace "^x" by "CTRL-X". Don't do this for "^_" to make
         * ":help i_^_CTRL-D" work.
         * Insert '-' before and after "CTRL-X" when applicable.
         */
        if (*s < ' ' || (*s == '^' && s[1] && (ASCII_ISALPHA(s[1])
                                               || vim_strchr((char_u *)
                                                   "?@[\\]^",
                                                   s[1]) != NULL))) {
          if (d > IObuff && d[-1] != '_' && d[-1] != '\\')
            *d++ = '_';                 /* prepend a '_' to make x_CTRL-x */
          STRCPY(d, "CTRL-");
          d += 5;
          if (*s < ' ') {
            *d++ = *s + '@';
            if (d[-1] == '\\')
              *d++ = '\\';              /* double a backslash */
          } else
            *d++ = *++s;
          if (s[1] != NUL && s[1] != '_')
            *d++ = '_';                 /* append a '_' */
          continue;
        } else if (*s == '^')           /* "^" or "CTRL-^" or "^_" */
          *d++ = '\\';

        /*
         * Insert a backslash before a backslash after a slash, for search
         * pattern tags: "/\|" --> "/\\|".
         */
        else if (s[0] == '\\' && s[1] != '\\'
                 && *arg == '/' && s == arg + 1)
          *d++ = '\\';

        /* "CTRL-\_" -> "CTRL-\\_" to avoid the special meaning of "\_" in
         * "CTRL-\_CTRL-N" */
        if (STRNICMP(s, "CTRL-\\_", 7) == 0) {
          STRCPY(d, "CTRL-\\\\");
          d += 7;
          s += 6;
        }

        *d++ = *s;

        // If tag contains "({" or "([", tag terminates at the "(".
        // This is for help on functions, e.g.: abs({expr}).
        if (*s == '(' && (s[1] == '{' || s[1] =='[')) {
          break;
        }

        // If tag starts with ', toss everything after a second '. Fixes
        // CTRL-] on 'option'. (would include the trailing '.').
        if (*s == '\'' && s > arg && *arg == '\'') {
          break;
        }
        // Also '{' and '}'. Fixes CTRL-] on '{address}'.
        if (*s == '}' && s > arg && *arg == '{') {
          break;
        }
      }
      *d = NUL;

      if (*IObuff == '`') {
        if (d > IObuff + 2 && d[-1] == '`') {
          /* remove the backticks from `command` */
          memmove(IObuff, IObuff + 1, STRLEN(IObuff));
          d[-2] = NUL;
        } else if (d > IObuff + 3 && d[-2] == '`' && d[-1] == ',') {
          /* remove the backticks and comma from `command`, */
          memmove(IObuff, IObuff + 1, STRLEN(IObuff));
          d[-3] = NUL;
        } else if (d > IObuff + 4 && d[-3] == '`'
                   && d[-2] == '\\' && d[-1] == '.') {
          /* remove the backticks and dot from `command`\. */
          memmove(IObuff, IObuff + 1, STRLEN(IObuff));
          d[-4] = NUL;
        }
      }
    }
  }

  *matches = (char_u **)"";
  *num_matches = 0;
  int flags = TAG_HELP | TAG_REGEXP | TAG_NAMES | TAG_VERBOSE;
  if (keep_lang) {
    flags |= TAG_KEEP_LANG;
  }
  if (find_tags(IObuff, num_matches, matches, flags, (int)MAXCOL, NULL) == OK
      && *num_matches > 0) {
    /* Sort the matches found on the heuristic number that is after the
     * tag name. */
    qsort((void *)*matches, (size_t)*num_matches,
        sizeof(char_u *), help_compare);
    /* Delete more than TAG_MANY to reduce the size of the listing. */
    while (*num_matches > TAG_MANY)
      xfree((*matches)[--*num_matches]);
  }
  return OK;
}

/// Called when starting to edit a buffer for a help file.
static void prepare_help_buffer(void)
{
  curbuf->b_help = true;
  set_string_option_direct((char_u *)"buftype", -1, (char_u *)"help",
                           OPT_FREE|OPT_LOCAL, 0);

  // Always set these options after jumping to a help tag, because the
  // user may have an autocommand that gets in the way.
  // Accept all ASCII chars for keywords, except ' ', '*', '"', '|', and
  // latin1 word characters (for translated help files).
  // Only set it when needed, buf_init_chartab() is some work.
  char_u *p = (char_u *)"!-~,^*,^|,^\",192-255";
  if (STRCMP(curbuf->b_p_isk, p) != 0) {
    set_string_option_direct((char_u *)"isk", -1, p, OPT_FREE|OPT_LOCAL, 0);
    check_buf_options(curbuf);
    (void)buf_init_chartab(curbuf, FALSE);
  }

  // Don't use the global foldmethod.
  set_string_option_direct((char_u *)"fdm", -1, (char_u *)"manual",
                           OPT_FREE|OPT_LOCAL, 0);

  curbuf->b_p_ts = 8;         // 'tabstop' is 8.
  curwin->w_p_list = FALSE;   // No list mode.

  curbuf->b_p_ma = FALSE;     // Not modifiable.
  curbuf->b_p_bin = FALSE;    // Reset 'bin' before reading file.
  curwin->w_p_nu = 0;         // No line numbers.
  curwin->w_p_rnu = 0;        // No relative line numbers.
  RESET_BINDING(curwin);      // No scroll or cursor binding.
  curwin->w_p_arab = FALSE;   // No arabic mode.
  curwin->w_p_rl  = FALSE;    // Help window is left-to-right.
  curwin->w_p_fen = FALSE;    // No folding in the help window.
  curwin->w_p_diff = FALSE;   // No 'diff'.
  curwin->w_p_spell = FALSE;  // No spell checking.

  set_buflisted(FALSE);
}

/*
 * After reading a help file: May cleanup a help buffer when syntax
 * highlighting is not used.
 */
void fix_help_buffer(void)
{
  linenr_T lnum;
  char_u      *line;
  bool in_example = false;

  // Set filetype to "help".
  if (STRCMP(curbuf->b_p_ft, "help") != 0) {
    curbuf_lock++;
    set_option_value("ft", 0L, "help", OPT_LOCAL);
    curbuf_lock--;
  }

  if (!syntax_present(curwin)) {
    for (lnum = 1; lnum <= curbuf->b_ml.ml_line_count; lnum++) {
      line = ml_get_buf(curbuf, lnum, false);
      const size_t len = STRLEN(line);
      if (in_example && len > 0 && !ascii_iswhite(line[0])) {
        /* End of example: non-white or '<' in first column. */
        if (line[0] == '<') {
          /* blank-out a '<' in the first column */
          line = ml_get_buf(curbuf, lnum, TRUE);
          line[0] = ' ';
        }
        in_example = false;
      }
      if (!in_example && len > 0) {
        if (line[len - 1] == '>' && (len == 1 || line[len - 2] == ' ')) {
          /* blank-out a '>' in the last column (start of example) */
          line = ml_get_buf(curbuf, lnum, TRUE);
          line[len - 1] = ' ';
          in_example = true;
        } else if (line[len - 1] == '~') {
          /* blank-out a '~' at the end of line (header marker) */
          line = ml_get_buf(curbuf, lnum, TRUE);
          line[len - 1] = ' ';
        }
      }
    }
  }

  /*
   * In the "help.txt" and "help.abx" file, add the locally added help
   * files.  This uses the very first line in the help file.
   */
  char_u *const fname = path_tail(curbuf->b_fname);
  if (fnamecmp(fname, "help.txt") == 0
      || (fnamencmp(fname, "help.", 5) == 0
          && ASCII_ISALPHA(fname[5])
          && ASCII_ISALPHA(fname[6])
          && TOLOWER_ASC(fname[7]) == 'x'
          && fname[8] == NUL)
      ) {
    for (lnum = 1; lnum < curbuf->b_ml.ml_line_count; ++lnum) {
      line = ml_get_buf(curbuf, lnum, FALSE);
      if (strstr((char *)line, "*local-additions*") == NULL)
        continue;

      /* Go through all directories in 'runtimepath', skipping
       * $VIMRUNTIME. */
      char_u *p = p_rtp;
      while (*p != NUL) {
        copy_option_part(&p, NameBuff, MAXPATHL, ",");
        char_u *const rt = (char_u *)vim_getenv("VIMRUNTIME");
        if (rt != NULL
            && path_full_compare(rt, NameBuff, false) != kEqualFiles) {
          int fcount;
          char_u      **fnames;
          char_u      *s;
          vimconv_T vc;
          char_u      *cp;

          // Find all "doc/ *.txt" files in this directory.
          if (!add_pathsep((char *)NameBuff)
              || STRLCAT(NameBuff, "doc/*.??[tx]",
                         sizeof(NameBuff)) >= MAXPATHL) {
            EMSG(_(e_fnametoolong));
            continue;
          }

          // Note: We cannot just do `&NameBuff` because it is a statically sized array
          //       so `NameBuff == &NameBuff` according to C semantics.
          char_u *buff_list[1] = {NameBuff};
          if (gen_expand_wildcards(1, buff_list, &fcount,
                  &fnames, EW_FILE|EW_SILENT) == OK
              && fcount > 0) {
            // If foo.abx is found use it instead of foo.txt in
            // the same directory.
            for (int i1 = 0; i1 < fcount; i1++) {
              for (int i2 = 0; i2 < fcount; i2++) {
                if (i1 == i2) {
                  continue;
                }
                if (fnames[i1] == NULL || fnames[i2] == NULL) {
                  continue;
                }
                const char_u *const f1 = fnames[i1];
                const char_u *const f2 = fnames[i2];
                const char_u *const t1 = path_tail(f1);
                const char_u *const t2 = path_tail(f2);
                const char_u *const e1 = STRRCHR(t1, '.');
                const char_u *const e2 = STRRCHR(t2, '.');
                if (e1 == NULL || e2 == NULL) {
                  continue;
                }
                if (fnamecmp(e1, ".txt") != 0
                    && fnamecmp(e1, fname + 4) != 0) {
                  /* Not .txt and not .abx, remove it. */
                  xfree(fnames[i1]);
                  fnames[i1] = NULL;
                  continue;
                }
                if (e1 - f1 != e2 - f2
                    || fnamencmp(f1, f2, e1 - f1) != 0) {
                  continue;
                }
                if (fnamecmp(e1, ".txt") == 0
                    && fnamecmp(e2, fname + 4) == 0) {
                  /* use .abx instead of .txt */
                  xfree(fnames[i1]);
                  fnames[i1] = NULL;
                }
              }
            }
            for (int fi = 0; fi < fcount; fi++) {
              if (fnames[fi] == NULL) {
                continue;
              }

              FILE *const fd = mch_fopen((char *)fnames[fi], "r");
              if (fd == NULL) {
                continue;
              }
              vim_fgets(IObuff, IOSIZE, fd);
              if (IObuff[0] == '*'
                  && (s = vim_strchr(IObuff + 1, '*'))
                  != NULL) {
                TriState this_utf = kNone;
                // Change tag definition to a
                // reference and remove <CR>/<NL>.
                IObuff[0] = '|';
                *s = '|';
                while (*s != NUL) {
                  if (*s == '\r' || *s == '\n')
                    *s = NUL;
                  /* The text is utf-8 when a byte
                   * above 127 is found and no
                   * illegal byte sequence is found.
                   */
                  if (*s >= 0x80 && this_utf != kFalse) {
                    this_utf = kTrue;
                    const int l = utf_ptr2len(s);
                    if (l == 1) {
                      this_utf = kFalse;
                    }
                    s += l - 1;
                  }
                  ++s;
                }
                /* The help file is latin1 or utf-8;
                 * conversion to the current
                 * 'encoding' may be required. */
                vc.vc_type = CONV_NONE;
                convert_setup(
                    &vc,
                    (char_u *)(this_utf == kTrue ? "utf-8" : "latin1"),
                    p_enc);
                if (vc.vc_type == CONV_NONE) {
                  // No conversion needed.
                  cp = IObuff;
                } else {
                  // Do the conversion.  If it fails
                  // use the unconverted text.
                  cp = string_convert(&vc, IObuff, NULL);
                  if (cp == NULL) {
                    cp = IObuff;
                  }
                }
                convert_setup(&vc, NULL, NULL);

                ml_append(lnum, cp, (colnr_T)0, FALSE);
                if (cp != IObuff)
                  xfree(cp);
                ++lnum;
              }
              fclose(fd);
            }
            FreeWild(fcount, fnames);
          }
        }
        xfree(rt);
      }
      break;
    }
  }
}

/*
 * ":exusage"
 */
void ex_exusage(exarg_T *eap)
{
  do_cmdline_cmd("help ex-cmd-index");
}

/*
 * ":viusage"
 */
void ex_viusage(exarg_T *eap)
{
  do_cmdline_cmd("help normal-index");
}


/// Generate tags in one help directory
///
/// @param dir  Path to the doc directory
/// @param ext  Suffix of the help files (".txt", ".itx", ".frx", etc.)
/// @param tagname  Name of the tags file ("tags" for English, "tags-fr" for
///                 French)
/// @param add_help_tags  Whether to add the "help-tags" tag
static void helptags_one(char_u *const dir, const char_u *const ext,
                         const char_u *const tagfname, const bool add_help_tags)
{
  garray_T ga;
  int filecount;
  char_u      **files;
  char_u      *p1, *p2;
  char_u      *s;
  TriState utf8 = kNone;
  bool mix = false;             // detected mixed encodings

  // Find all *.txt files.
  size_t dirlen = STRLCPY(NameBuff, dir, sizeof(NameBuff));
  if (dirlen >= MAXPATHL
      || STRLCAT(NameBuff, "/**/*", sizeof(NameBuff)) >= MAXPATHL  // NOLINT
      || STRLCAT(NameBuff, ext, sizeof(NameBuff)) >= MAXPATHL) {
    EMSG(_(e_fnametoolong));
    return;
  }

  // Note: We cannot just do `&NameBuff` because it is a statically sized array
  //       so `NameBuff == &NameBuff` according to C semantics.
  char_u *buff_list[1] = {NameBuff};
  if (gen_expand_wildcards(1, buff_list, &filecount, &files,
          EW_FILE|EW_SILENT) == FAIL
      || filecount == 0) {
    if (!got_int) {
      EMSG2(_("E151: No match: %s"), NameBuff);
    }
    return;
  }

  //
  // Open the tags file for writing.
  // Do this before scanning through all the files.
  //
  memcpy(NameBuff, dir, dirlen + 1);
  if (!add_pathsep((char *)NameBuff)
      || STRLCAT(NameBuff, tagfname, sizeof(NameBuff)) >= MAXPATHL) {
    EMSG(_(e_fnametoolong));
    return;
  }

  FILE *const fd_tags = mch_fopen((char *)NameBuff, "w");
  if (fd_tags == NULL) {
    EMSG2(_("E152: Cannot open %s for writing"), NameBuff);
    FreeWild(filecount, files);
    return;
  }

  /*
   * If using the "++t" argument or generating tags for "$VIMRUNTIME/doc"
   * add the "help-tags" tag.
   */
  ga_init(&ga, (int)sizeof(char_u *), 100);
  if (add_help_tags
      || path_full_compare((char_u *)"$VIMRUNTIME/doc",
                           dir, false) == kEqualFiles) {
    s = xmalloc(18 + STRLEN(tagfname));
    sprintf((char *)s, "help-tags\t%s\t1\n", tagfname);
    GA_APPEND(char_u *, &ga, s);
  }

  /*
   * Go over all the files and extract the tags.
   */
  for (int fi = 0; fi < filecount && !got_int; fi++) {
    FILE *const fd = mch_fopen((char *)files[fi], "r");
    if (fd == NULL) {
      EMSG2(_("E153: Unable to open %s for reading"), files[fi]);
      continue;
    }
    const char_u *const fname = files[fi] + dirlen + 1;

    bool firstline = true;
    while (!vim_fgets(IObuff, IOSIZE, fd) && !got_int) {
      if (firstline) {
        // Detect utf-8 file by a non-ASCII char in the first line.
        TriState this_utf8 = kNone;
        for (s = IObuff; *s != NUL; s++) {
          if (*s >= 0x80) {
            this_utf8 = kTrue;
            const int l = utf_ptr2len(s);
            if (l == 1) {
              // Illegal UTF-8 byte sequence.
              this_utf8 = kFalse;
              break;
            }
            s += l - 1;
          }
        }
        if (this_utf8 == kNone) {           // only ASCII characters found
          this_utf8 = kFalse;
        }
        if (utf8 == kNone) {                // first file
          utf8 = this_utf8;
        } else if (utf8 != this_utf8) {
          EMSG2(_(
                  "E670: Mix of help file encodings within a language: %s"),
              files[fi]);
          mix = !got_int;
          got_int = TRUE;
        }
        firstline = false;
      }
      p1 = vim_strchr(IObuff, '*');             /* find first '*' */
      while (p1 != NULL) {
        p2 = (char_u *)strchr((const char *)p1 + 1, '*');  // Find second '*'.
        if (p2 != NULL && p2 > p1 + 1) {  // Skip "*" and "**".
          for (s = p1 + 1; s < p2; s++) {
            if (*s == ' ' || *s == '\t' || *s == '|') {
              break;
            }
          }

          /*
           * Only accept a *tag* when it consists of valid
           * characters, there is white space before it and is
           * followed by a white character or end-of-line.
           */
          if (s == p2
              && (p1 == IObuff || p1[-1] == ' ' || p1[-1] == '\t')
              && (vim_strchr((char_u *)" \t\n\r", s[1]) != NULL
                  || s[1] == '\0')) {
            *p2 = '\0';
            ++p1;
            s = xmalloc((p2 - p1) + STRLEN(fname) + 2);
            GA_APPEND(char_u *, &ga, s);
            sprintf((char *)s, "%s\t%s", p1, fname);

            /* find next '*' */
            p2 = vim_strchr(p2 + 1, '*');
          }
        }
        p1 = p2;
      }
      line_breakcheck();
    }

    fclose(fd);
  }

  FreeWild(filecount, files);

  if (!got_int) {
    /*
     * Sort the tags.
     */
    if (ga.ga_data != NULL) {
      sort_strings((char_u **)ga.ga_data, ga.ga_len);
    }

    /*
     * Check for duplicates.
     */
    for (int i = 1; i < ga.ga_len; ++i) {
      p1 = ((char_u **)ga.ga_data)[i - 1];
      p2 = ((char_u **)ga.ga_data)[i];
      while (*p1 == *p2) {
        if (*p2 == '\t') {
          *p2 = NUL;
          vim_snprintf((char *)NameBuff, MAXPATHL,
              _("E154: Duplicate tag \"%s\" in file %s/%s"),
              ((char_u **)ga.ga_data)[i], dir, p2 + 1);
          EMSG(NameBuff);
          *p2 = '\t';
          break;
        }
        ++p1;
        ++p2;
      }
    }

    if (utf8 == kTrue) {
      fprintf(fd_tags, "!_TAG_FILE_ENCODING\tutf-8\t//\n");
    }

    /*
     * Write the tags into the file.
     */
    for (int i = 0; i < ga.ga_len; ++i) {
      s = ((char_u **)ga.ga_data)[i];
      if (STRNCMP(s, "help-tags\t", 10) == 0)
        /* help-tags entry was added in formatted form */
        fputs((char *)s, fd_tags);
      else {
        fprintf(fd_tags, "%s\t/*", s);
        for (p1 = s; *p1 != '\t'; ++p1) {
          /* insert backslash before '\\' and '/' */
          if (*p1 == '\\' || *p1 == '/')
            putc('\\', fd_tags);
          putc(*p1, fd_tags);
        }
        fprintf(fd_tags, "*\n");
      }
    }
  }
  if (mix)
    got_int = FALSE;        /* continue with other languages */

  GA_DEEP_CLEAR_PTR(&ga);
  fclose(fd_tags);          /* there is no check for an error... */
}

/// Generate tags in one help directory, taking care of translations.
static void do_helptags(char_u *dirname, bool add_help_tags)
{
  int len;
  garray_T ga;
  char_u lang[2];
  char_u ext[5];
  char_u fname[8];
  int filecount;
  char_u **files;

  // Get a list of all files in the help directory and in subdirectories.
  STRLCPY(NameBuff, dirname, sizeof(NameBuff));
  if (!add_pathsep((char *)NameBuff)
      || STRLCAT(NameBuff, "**", sizeof(NameBuff)) >= MAXPATHL) {
    EMSG(_(e_fnametoolong));
    return;
  }

  // Note: We cannot just do `&NameBuff` because it is a statically sized array
  //       so `NameBuff == &NameBuff` according to C semantics.
  char_u *buff_list[1] = {NameBuff};
  if (gen_expand_wildcards(1, buff_list, &filecount, &files,
                           EW_FILE|EW_SILENT) == FAIL
      || filecount == 0) {
    EMSG2(_("E151: No match: %s"), NameBuff);
    return;
  }

  /* Go over all files in the directory to find out what languages are
   * present. */
  int j;
  ga_init(&ga, 1, 10);
  for (int i = 0; i < filecount; i++) {
    len = (int)STRLEN(files[i]);
    if (len <= 4) {
      continue;
    }
    if (STRICMP(files[i] + len - 4, ".txt") == 0) {
      /* ".txt" -> language "en" */
      lang[0] = 'e';
      lang[1] = 'n';
    } else if (files[i][len - 4] == '.'
               && ASCII_ISALPHA(files[i][len - 3])
               && ASCII_ISALPHA(files[i][len - 2])
               && TOLOWER_ASC(files[i][len - 1]) == 'x') {
      /* ".abx" -> language "ab" */
      lang[0] = TOLOWER_ASC(files[i][len - 3]);
      lang[1] = TOLOWER_ASC(files[i][len - 2]);
    } else
      continue;

    // Did we find this language already?
    for (j = 0; j < ga.ga_len; j += 2) {
      if (STRNCMP(lang, ((char_u *)ga.ga_data) + j, 2) == 0) {
        break;
      }
    }
    if (j == ga.ga_len) {
      // New language, add it.
      ga_grow(&ga, 2);
      ((char_u *)ga.ga_data)[ga.ga_len++] = lang[0];
      ((char_u *)ga.ga_data)[ga.ga_len++] = lang[1];
    }
  }

  /*
   * Loop over the found languages to generate a tags file for each one.
   */
  for (j = 0; j < ga.ga_len; j += 2) {
    STRCPY(fname, "tags-xx");
    fname[5] = ((char_u *)ga.ga_data)[j];
    fname[6] = ((char_u *)ga.ga_data)[j + 1];
    if (fname[5] == 'e' && fname[6] == 'n') {
      /* English is an exception: use ".txt" and "tags". */
      fname[4] = NUL;
      STRCPY(ext, ".txt");
    } else {
      /* Language "ab" uses ".abx" and "tags-ab". */
      STRCPY(ext, ".xxx");
      ext[1] = fname[5];
      ext[2] = fname[6];
    }
    helptags_one(dirname, ext, fname, add_help_tags);
  }

  ga_clear(&ga);
  FreeWild(filecount, files);
}

    static void
helptags_cb(char_u *fname, void *cookie)
{
    do_helptags(fname, *(bool *)cookie);
}

/*
 * ":helptags"
 */
void ex_helptags(exarg_T *eap)
{
  expand_T xpc;
  char_u *dirname;
  bool add_help_tags = false;

  /* Check for ":helptags ++t {dir}". */
  if (STRNCMP(eap->arg, "++t", 3) == 0 && ascii_iswhite(eap->arg[3])) {
    add_help_tags = true;
    eap->arg = skipwhite(eap->arg + 3);
  }

  if (STRCMP(eap->arg, "ALL") == 0) {
    do_in_path(p_rtp, (char_u *)"doc", DIP_ALL + DIP_DIR,
               helptags_cb, &add_help_tags);
  } else {
    ExpandInit(&xpc);
    xpc.xp_context = EXPAND_DIRECTORIES;
    dirname = ExpandOne(&xpc, eap->arg, NULL,
                        WILD_LIST_NOTFOUND|WILD_SILENT, WILD_EXPAND_FREE);
    if (dirname == NULL || !os_isdir(dirname)) {
      EMSG2(_("E150: Not a directory: %s"), eap->arg);
    } else {
      do_helptags(dirname, add_help_tags);
    }
    xfree(dirname);
  }
}

struct sign
{
    sign_T      *sn_next;       /* next sign in list */
    int         sn_typenr;      /* type number of sign */
    char_u      *sn_name;       /* name of sign */
    char_u      *sn_icon;       /* name of pixmap */
    char_u      *sn_text;       /* text used instead of pixmap */
    int         sn_line_hl;     /* highlight ID for line */
    int         sn_text_hl;     /* highlight ID for text */
};

static sign_T   *first_sign = NULL;
static int      next_sign_typenr = 1;

/*
 * ":helpclose": Close one help window
 */
void ex_helpclose(exarg_T *eap)
{
  FOR_ALL_WINDOWS_IN_TAB(win, curtab) {
    if (bt_help(win->w_buffer)) {
      win_close(win, false);
      return;
    }
  }
}

static char *cmds[] = {
			"define",
#define SIGNCMD_DEFINE	0
			"undefine",
#define SIGNCMD_UNDEFINE 1
			"list",
#define SIGNCMD_LIST	2
			"place",
#define SIGNCMD_PLACE	3
			"unplace",
#define SIGNCMD_UNPLACE	4
			"jump",
#define SIGNCMD_JUMP	5
			NULL
#define SIGNCMD_LAST	6
};

/*
 * Find index of a ":sign" subcmd from its name.
 * "*end_cmd" must be writable.
 */
static int sign_cmd_idx(
    char_u      *begin_cmd,     /* begin of sign subcmd */
    char_u      *end_cmd        /* just after sign subcmd */
    )
{
    int  idx;
    char save = *end_cmd;

    *end_cmd = NUL;
    for (idx = 0; ; ++idx) {
        if (cmds[idx] == NULL || STRCMP(begin_cmd, cmds[idx]) == 0) {
            break;
        }
    }
    *end_cmd = save;
    return idx;
}

/*
 * ":sign" command
 */
void ex_sign(exarg_T *eap)
{
  char_u *arg = eap->arg;
  char_u *p;
  int idx;
  sign_T *sp;
  sign_T *sp_prev;

  // Parse the subcommand.
  p = skiptowhite(arg);
  idx = sign_cmd_idx(arg, p);
  if (idx == SIGNCMD_LAST) {
    EMSG2(_("E160: Unknown sign command: %s"), arg);
    return;
  }
  arg = skipwhite(p);

  if (idx <= SIGNCMD_LIST) {
    // Define, undefine or list signs.
    if (idx == SIGNCMD_LIST && *arg == NUL) {
      // ":sign list": list all defined signs
      for (sp = first_sign; sp != NULL && !got_int; sp = sp->sn_next) {
        sign_list_defined(sp);
      }
    } else if (*arg == NUL) {
      EMSG(_("E156: Missing sign name"));
    } else {
      // Isolate the sign name.  If it's a number skip leading zeroes,
      // so that "099" and "99" are the same sign.  But keep "0".
      p = skiptowhite(arg);
      if (*p != NUL) {
        *p++ = NUL;
      }
      while (arg[0] == '0' && arg[1] != NUL) {
        arg++;
      }

      sp_prev = NULL;
      for (sp = first_sign; sp != NULL; sp = sp->sn_next) {
        if (STRCMP(sp->sn_name, arg) == 0) {
          break;
        }
        sp_prev = sp;
      }
      if (idx == SIGNCMD_DEFINE) {
        // ":sign define {name} ...": define a sign
        if (sp == NULL) {
          sign_T *lp;
          int start = next_sign_typenr;

          // Allocate a new sign.
          sp = xcalloc(1, sizeof(sign_T));

          // Check that next_sign_typenr is not already being used.
          // This only happens after wrapping around.  Hopefully
          // another one got deleted and we can use its number.
          for (lp = first_sign; lp != NULL; ) {
            if (lp->sn_typenr == next_sign_typenr) {
              next_sign_typenr++;
              if (next_sign_typenr == MAX_TYPENR) {
                next_sign_typenr = 1;
              }
              if (next_sign_typenr == start) {
                xfree(sp);
                EMSG(_("E612: Too many signs defined"));
                return;
              }
              lp = first_sign;  // start all over
              continue;
            }
            lp = lp->sn_next;
          }

          sp->sn_typenr = next_sign_typenr;
          if (++next_sign_typenr == MAX_TYPENR) {
            next_sign_typenr = 1;  // wrap around
          }

          sp->sn_name = vim_strsave(arg);

          // add the new sign to the list of signs
          if (sp_prev == NULL) {
            first_sign = sp;
          } else {
            sp_prev->sn_next = sp;
          }
        }

        // set values for a defined sign.
        for (;;) {
          arg = skipwhite(p);
          if (*arg == NUL) {
            break;
          }
          p = skiptowhite_esc(arg);
          if (STRNCMP(arg, "icon=", 5) == 0) {
            arg += 5;
            xfree(sp->sn_icon);
            sp->sn_icon = vim_strnsave(arg, (int)(p - arg));
            backslash_halve(sp->sn_icon);
          } else if (STRNCMP(arg, "text=", 5) == 0) {
            char_u *s;
            int cells;
            int len;

            arg += 5;

            // Count cells and check for non-printable chars
            cells = 0;
            for (s = arg; s < p; s += utfc_ptr2len(s)) {
              if (!vim_isprintc(utf_ptr2char(s))) {
                break;
              }
              cells += utf_ptr2cells(s);
            }
            // Currently must be one or two display cells
            if (s != p || cells < 1 || cells > 2) {
              *p = NUL;
              EMSG2(_("E239: Invalid sign text: %s"), arg);
              return;
            }

            xfree(sp->sn_text);
            // Allocate one byte more if we need to pad up
            // with a space.
            len = (int)(p - arg + ((cells == 1) ? 1 : 0));
            sp->sn_text = vim_strnsave(arg, len);

            if (cells == 1) {
              STRCPY(sp->sn_text + len - 1, " ");
            }
          } else if (STRNCMP(arg, "linehl=", 7) == 0) {
            arg += 7;
            sp->sn_line_hl = syn_check_group(arg, (int)(p - arg));
          } else if (STRNCMP(arg, "texthl=", 7) == 0) {
            arg += 7;
            sp->sn_text_hl = syn_check_group(arg, (int)(p - arg));
          } else {
            EMSG2(_(e_invarg2), arg);
            return;
          }
        }
      } else if (sp == NULL) {
        EMSG2(_("E155: Unknown sign: %s"), arg);
      } else if (idx == SIGNCMD_LIST) {
        // ":sign list {name}"
        sign_list_defined(sp);
      } else {
        // ":sign undefine {name}"
        sign_undefine(sp, sp_prev);
      }
    }
  } else {
    int id = -1;
    linenr_T lnum = -1;
    char_u *sign_name = NULL;
    char_u *arg1;

    if (*arg == NUL) {
      if (idx == SIGNCMD_PLACE) {
        // ":sign place": list placed signs in all buffers
        sign_list_placed(NULL);
      } else if (idx == SIGNCMD_UNPLACE) {
        // ":sign unplace": remove placed sign at cursor
        id = buf_findsign_id(curwin->w_buffer, curwin->w_cursor.lnum);
        if (id > 0) {
          buf_delsign(curwin->w_buffer, id);
          update_debug_sign(curwin->w_buffer, curwin->w_cursor.lnum);
        } else {
          EMSG(_("E159: Missing sign number"));
        }
      } else {
        EMSG(_(e_argreq));
      }
      return;
    }

    if (idx == SIGNCMD_UNPLACE && arg[0] == '*' && arg[1] == NUL) {
      // ":sign unplace *": remove all placed signs
      buf_delete_all_signs();
      return;
    }

    // first arg could be placed sign id
    arg1 = arg;
    if (ascii_isdigit(*arg)) {
      id = getdigits_int(&arg);
      if (!ascii_iswhite(*arg) && *arg != NUL) {
        id = -1;
        arg = arg1;
      } else {
        arg = skipwhite(arg);
        if (idx == SIGNCMD_UNPLACE && *arg == NUL) {
          // ":sign unplace {id}": remove placed sign by number
          FOR_ALL_BUFFERS(buf) {
            if ((lnum = buf_delsign(buf, id)) != 0) {
              update_debug_sign(buf, lnum);
            }
          }
          return;
        }
      }
    }

    // Check for line={lnum} name={name} and file={fname} or buffer={nr}.
    // Leave "arg" pointing to {fname}.

    buf_T *buf = NULL;
    for (;;) {
      if (STRNCMP(arg, "line=", 5) == 0) {
        arg += 5;
        lnum = atoi((char *)arg);
        arg = skiptowhite(arg);
      } else if (STRNCMP(arg, "*", 1) == 0 && idx == SIGNCMD_UNPLACE) {
        if (id != -1) {
          EMSG(_(e_invarg));
          return;
        }
        id = -2;
        arg = skiptowhite(arg + 1);
      } else if (STRNCMP(arg, "name=", 5) == 0) {
        arg += 5;
        sign_name = arg;
        arg = skiptowhite(arg);
        if (*arg != NUL) {
          *arg++ = NUL;
        }
        while (sign_name[0] == '0' && sign_name[1] != NUL) {
          sign_name++;
        }
      } else if (STRNCMP(arg, "file=", 5) == 0) {
        arg += 5;
        buf = buflist_findname(arg);
        break;
      } else if (STRNCMP(arg, "buffer=", 7) == 0) {
        arg += 7;
        buf = buflist_findnr(getdigits_int(&arg));
        if (*skipwhite(arg) != NUL) {
          EMSG(_(e_trailing));
        }
        break;
      } else {
        EMSG(_(e_invarg));
        return;
      }
      arg = skipwhite(arg);
    }

    if (buf == NULL) {
      EMSG2(_("E158: Invalid buffer name: %s"), arg);
    } else if (id <= 0 && !(idx == SIGNCMD_UNPLACE && id == -2)) {
      if (lnum >= 0 || sign_name != NULL) {
        EMSG(_(e_invarg));
      } else {
        // ":sign place file={fname}": list placed signs in one file
        sign_list_placed(buf);
      }
    } else if (idx == SIGNCMD_JUMP) {
      // ":sign jump {id} file={fname}"
      if (lnum >= 0 || sign_name != NULL) {
        EMSG(_(e_invarg));
      } else if ((lnum = buf_findsign(buf, id)) > 0) {
        // goto a sign ...
        if (buf_jump_open_win(buf) != NULL) {
          // ... in a current window
          curwin->w_cursor.lnum = lnum;
          check_cursor_lnum();
          beginline(BL_WHITE);
        } else {
          // ... not currently in a window
          if (buf->b_fname == NULL) {
            EMSG(_("E934: Cannot jump to a buffer that does not have a name"));
            return;
          }
          size_t cmdlen = STRLEN(buf->b_fname) + 24;
          char *cmd = xmallocz(cmdlen);
          snprintf(cmd, cmdlen, "e +%" PRId64 " %s",
                   (int64_t)lnum, buf->b_fname);
          do_cmdline_cmd(cmd);
          xfree(cmd);
        }

        foldOpenCursor();
      } else {
        EMSGN(_("E157: Invalid sign ID: %" PRId64), id);
      }
    } else if (idx == SIGNCMD_UNPLACE) {
      if (lnum >= 0 || sign_name != NULL) {
        EMSG(_(e_invarg));
      } else if (id == -2) {
        // ":sign unplace * file={fname}"
        redraw_buf_later(buf, NOT_VALID);
        buf_delete_signs(buf);
      } else {
        // ":sign unplace {id} file={fname}"
        lnum = buf_delsign(buf, id);
        update_debug_sign(buf, lnum);
      }
    } else if (sign_name != NULL) {
      // idx == SIGNCMD_PLACE
      for (sp = first_sign; sp != NULL; sp = sp->sn_next) {
        if (STRCMP(sp->sn_name, sign_name) == 0) {
          break;
        }
      }
      if (sp == NULL) {
        EMSG2(_("E155: Unknown sign: %s"), sign_name);
        return;
      }
      if (lnum > 0) {
        // ":sign place {id} line={lnum} name={name} file={fname}":
        // place a sign
        buf_addsign(buf, id, lnum, sp->sn_typenr);
      } else {
        // ":sign place {id} file={fname}": change sign type
        lnum = buf_change_sign_type(buf, id, sp->sn_typenr);
      }
      if (lnum > 0) {
        update_debug_sign(buf, lnum);
      } else {
        EMSG2(_("E885: Not possible to change sign %s"), sign_name);
      }
    } else {
      EMSG(_(e_invarg));
    }
  }
}

/*
 * List one sign.
 */
static void sign_list_defined(sign_T *sp)
{
  smsg("sign %s", sp->sn_name);
  if (sp->sn_icon != NULL) {
    msg_puts(" icon=");
    msg_outtrans(sp->sn_icon);
    msg_puts(_(" (not supported)"));
  }
  if (sp->sn_text != NULL) {
    msg_puts(" text=");
    msg_outtrans(sp->sn_text);
  }
  if (sp->sn_line_hl > 0) {
    msg_puts(" linehl=");
    const char *const p = get_highlight_name_ext(NULL,
                                                 sp->sn_line_hl - 1, false);
    if (p == NULL) {
      msg_puts("NONE");
    } else {
      msg_puts(p);
    }
  }
  if (sp->sn_text_hl > 0) {
    msg_puts(" texthl=");
    const char *const p = get_highlight_name_ext(NULL,
                                                 sp->sn_text_hl - 1, false);
    if (p == NULL) {
      msg_puts("NONE");
    } else {
      msg_puts(p);
    }
  }
}

/*
 * Undefine a sign and free its memory.
 */
static void sign_undefine(sign_T *sp, sign_T *sp_prev)
{
  xfree(sp->sn_name);
  xfree(sp->sn_icon);
  xfree(sp->sn_text);
  if (sp_prev == NULL)
    first_sign = sp->sn_next;
  else
    sp_prev->sn_next = sp->sn_next;
  xfree(sp);
}

/*
 * Get highlighting attribute for sign "typenr".
 * If "line" is TRUE: line highl, if FALSE: text highl.
 */
int sign_get_attr(int typenr, int line)
{
  sign_T  *sp;

  for (sp = first_sign; sp != NULL; sp = sp->sn_next)
    if (sp->sn_typenr == typenr) {
      if (line) {
        if (sp->sn_line_hl > 0)
          return syn_id2attr(sp->sn_line_hl);
      } else {
        if (sp->sn_text_hl > 0)
          return syn_id2attr(sp->sn_text_hl);
      }
      break;
    }
  return 0;
}

/*
 * Get text mark for sign "typenr".
 * Returns NULL if there isn't one.
 */
char_u * sign_get_text(int typenr)
{
    sign_T  *sp;

    for (sp = first_sign; sp != NULL; sp = sp->sn_next)
      if (sp->sn_typenr == typenr)
        return sp->sn_text;
    return NULL;
}


/*
 * Get the name of a sign by its typenr.
 */
char_u * sign_typenr2name(int typenr)
{
  sign_T  *sp;

  for (sp = first_sign; sp != NULL; sp = sp->sn_next)
    if (sp->sn_typenr == typenr)
      return sp->sn_name;
  return (char_u *)_("[Deleted]");
}

#if defined(EXITFREE)
/*
 * Undefine/free all signs.
 */
void free_signs(void)
{
  while (first_sign != NULL)
    sign_undefine(first_sign, NULL);
}
#endif

static enum
{
    EXP_SUBCMD,		/* expand :sign sub-commands */
    EXP_DEFINE,		/* expand :sign define {name} args */
    EXP_PLACE,		/* expand :sign place {id} args */
    EXP_UNPLACE,	/* expand :sign unplace" */
    EXP_SIGN_NAMES	/* expand with name of placed signs */
} expand_what;

/// Function given to ExpandGeneric() to obtain the sign command
/// expansion.
char_u * get_sign_name(expand_T *xp, int idx)
{
  switch (expand_what)
  {
    case EXP_SUBCMD:
      return (char_u *)cmds[idx];
    case EXP_DEFINE: {
        char *define_arg[] = { "icon=", "linehl=", "text=", "texthl=", NULL };
        return (char_u *)define_arg[idx];
      }
    case EXP_PLACE: {
        char *place_arg[] = { "line=", "name=", "file=", "buffer=", NULL };
        return (char_u *)place_arg[idx];
      }
    case EXP_UNPLACE: {
        char *unplace_arg[] = { "file=", "buffer=", NULL };
        return (char_u *)unplace_arg[idx];
      }
    case EXP_SIGN_NAMES: {
        // Complete with name of signs already defined
        int current_idx = 0;
        for (sign_T *sp = first_sign; sp != NULL; sp = sp->sn_next) {
          if (current_idx++ == idx) {
            return sp->sn_name;
          }
        }
      }
      return NULL;
    default:
      return NULL;
  }
}

/*
 * Handle command line completion for :sign command.
 */
void set_context_in_sign_cmd(expand_T *xp, char_u *arg)
{
  char_u  *p;
  char_u  *end_subcmd;
  char_u  *last;
  int    cmd_idx;
  char_u  *begin_subcmd_args;

  /* Default: expand subcommands. */
  xp->xp_context = EXPAND_SIGN;
  expand_what = EXP_SUBCMD;
  xp->xp_pattern = arg;

  end_subcmd = skiptowhite(arg);
  if (*end_subcmd == NUL)
    /* expand subcmd name
     * :sign {subcmd}<CTRL-D>*/
    return;

  cmd_idx = sign_cmd_idx(arg, end_subcmd);

  // :sign {subcmd} {subcmd_args}
  //                |
  //                begin_subcmd_args
  begin_subcmd_args = skipwhite(end_subcmd);
  p = skiptowhite(begin_subcmd_args);
  if (*p == NUL)
  {
    /*
     * Expand first argument of subcmd when possible.
     * For ":jump {id}" and ":unplace {id}", we could
     * possibly expand the ids of all signs already placed.
     */
    xp->xp_pattern = begin_subcmd_args;
    switch (cmd_idx)
    {
      case SIGNCMD_LIST:
      case SIGNCMD_UNDEFINE:
        /* :sign list <CTRL-D>
         * :sign undefine <CTRL-D> */
        expand_what = EXP_SIGN_NAMES;
        break;
      default:
        xp->xp_context = EXPAND_NOTHING;
    }
    return;
  }

  // Expand last argument of subcmd.
  //
  // :sign define {name} {args}...
  //              |
  //              p

  // Loop until reaching last argument.
  do
  {
    p = skipwhite(p);
    last = p;
    p = skiptowhite(p);
  } while (*p != NUL);

  p = vim_strchr(last, '=');

  // :sign define {name} {args}... {last}=
  //                               |     |
  //                            last     p
  if (p == NULL) {
    // Expand last argument name (before equal sign).
    xp->xp_pattern = last;
    switch (cmd_idx)
    {
      case SIGNCMD_DEFINE:
        expand_what = EXP_DEFINE;
        break;
      case SIGNCMD_PLACE:
        expand_what = EXP_PLACE;
        break;
      case SIGNCMD_JUMP:
      case SIGNCMD_UNPLACE:
        expand_what = EXP_UNPLACE;
        break;
      default:
        xp->xp_context = EXPAND_NOTHING;
    }
  }
  else
  {
    /* Expand last argument value (after equal sign). */
    xp->xp_pattern = p + 1;
    switch (cmd_idx)
    {
      case SIGNCMD_DEFINE:
        if (STRNCMP(last, "texthl", p - last) == 0
            || STRNCMP(last, "linehl", p - last) == 0) {
          xp->xp_context = EXPAND_HIGHLIGHT;
        } else if (STRNCMP(last, "icon", p - last) == 0) {
          xp->xp_context = EXPAND_FILES;
        } else {
          xp->xp_context = EXPAND_NOTHING;
        }
        break;
      case SIGNCMD_PLACE:
        if (STRNCMP(last, "name", p - last) == 0)
          expand_what = EXP_SIGN_NAMES;
        else
          xp->xp_context = EXPAND_NOTHING;
        break;
      default:
        xp->xp_context = EXPAND_NOTHING;
    }
  }
}

/// Shows the effects of the :substitute command being typed ('inccommand').
/// If inccommand=split, shows a preview window and later restores the layout.
static buf_T *show_sub(exarg_T *eap, pos_T old_cusr,
                       PreviewLines *preview_lines, int hl_id, int src_id)
  FUNC_ATTR_NONNULL_ALL
{
  static handle_T bufnr = 0;  // special buffer, re-used on each visit

  win_T *save_curwin = curwin;
  cmdmod_T save_cmdmod = cmdmod;
  char_u *save_shm_p = vim_strsave(p_shm);
  PreviewLines lines = *preview_lines;
  buf_T *orig_buf = curbuf;

  // We keep a special-purpose buffer around, but don't assume it exists.
  buf_T *preview_buf = bufnr ? buflist_findnr(bufnr) : 0;
  cmdmod.tab = 0;                 // disable :tab modifier
  cmdmod.noswapfile = true;       // disable swap for preview buffer
  // disable file info message
  set_string_option_direct((char_u *)"shm", -1, (char_u *)"F", OPT_FREE,
                           SID_NONE);

  bool outside_curline = (eap->line1 != old_cusr.lnum
                          || eap->line2 != old_cusr.lnum);
  bool split = outside_curline && (*p_icm != 'n');
  if (preview_buf == curbuf) {  // Preview buffer cannot preview itself!
    split = false;
    preview_buf = NULL;
  }

  // Place cursor on nearest matching line, to undo do_sub() cursor placement.
  for (size_t i = 0; i < lines.subresults.size; i++) {
    SubResult curres = lines.subresults.items[i];
    if (curres.start.lnum >= old_cusr.lnum) {
      curwin->w_cursor.lnum = curres.start.lnum;
      curwin->w_cursor.col = curres.start.col;
      break;
    }  // Else: All matches are above, do_sub() already placed cursor.
  }

  // Width of the "| lnum|..." column which displays the line numbers.
  linenr_T highest_num_line = 0;
  int col_width = 0;

  if (split && win_split((int)p_cwh, WSP_BOT) != FAIL) {
    buf_open_scratch(preview_buf ? bufnr : 0, "[Preview]");
    buf_clear();
    preview_buf = curbuf;
    bufnr = preview_buf->handle;
    curbuf->b_p_bl = false;
    curbuf->b_p_ma = true;
    curbuf->b_p_ul = -1;
    curbuf->b_p_tw = 0;         // Reset 'textwidth' (was set by ftplugin)
    curwin->w_p_cul = false;
    curwin->w_p_cuc = false;
    curwin->w_p_spell = false;
    curwin->w_p_fen = false;

    if (lines.subresults.size > 0) {
      highest_num_line = kv_last(lines.subresults).end.lnum;
      col_width = log10(highest_num_line) + 1 + 3;
    }
  }

  char *str = NULL;  // construct the line to show in here
  size_t old_line_size = 0;
  size_t line_size = 0;
  linenr_T linenr_preview = 0;  // last line added to preview buffer
  linenr_T linenr_origbuf = 0;  // last line added to original buffer
  linenr_T next_linenr = 0;     // next line to show for the match

  for (size_t matchidx = 0; matchidx < lines.subresults.size; matchidx++) {
    SubResult match = lines.subresults.items[matchidx];

    if (split && preview_buf) {
      lpos_T p_start = { 0, match.start.col };  // match starts here in preview
      lpos_T p_end   = { 0, match.end.col };    // ... and ends here

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
          line = (char *)ml_get_buf(orig_buf, next_linenr, false);
          line_size = strlen(line) + col_width + 1;

          // Reallocate if line not long enough
          if (line_size > old_line_size) {
            str = xrealloc(str, line_size * sizeof(char));
            old_line_size = line_size;
          }
        }
        // Put "|lnum| line" into `str` and append it to the preview buffer.
        snprintf(str, line_size, "|%*ld| %s", col_width - 3,
                 next_linenr, line);
        if (linenr_preview == 0) {
          ml_replace(1, (char_u *)str, true);
        } else {
          ml_append(linenr_preview, (char_u *)str, (colnr_T)line_size, false);
        }
        linenr_preview += 1;
      }
      linenr_origbuf = match.end.lnum;

      bufhl_add_hl_pos_offset(preview_buf, src_id, hl_id, p_start,
                              p_end, col_width);
    }
    bufhl_add_hl_pos_offset(orig_buf, src_id, hl_id, match.start,
                            match.end, 0);
  }
  xfree(str);

  redraw_later(SOME_VALID);
  win_enter(save_curwin, false);  // Return to original window
  update_topline();

  // Update screen now. Must do this _before_ close_windows().
  int save_rd = RedrawingDisabled;
  RedrawingDisabled = 0;
  update_screen(SOME_VALID);
  RedrawingDisabled = save_rd;

  set_string_option_direct((char_u *)"shm", -1, save_shm_p, OPT_FREE, SID_NONE);
  xfree(save_shm_p);

  cmdmod = save_cmdmod;

  return preview_buf;
}

/// :substitute command
///
/// If 'inccommand' is empty: calls do_sub().
/// If 'inccommand' is set: shows a "live" preview then removes the changes.
/// from undo history.
void ex_substitute(exarg_T *eap)
{
  bool preview = (State & CMDPREVIEW);
  if (*p_icm == NUL || !preview) {  // 'inccommand' is disabled
    (void)do_sub(eap, profile_zero(), true);
    return;
  }

  block_autocmds();           // Disable events during command preview.

  char_u *save_eap = eap->arg;
  garray_T save_view;
  win_size_save(&save_view);  // Save current window sizes.
  save_search_patterns();
  int save_changedtick = buf_get_changedtick(curbuf);
  time_t save_b_u_time_cur = curbuf->b_u_time_cur;
  u_header_T *save_b_u_newhead = curbuf->b_u_newhead;
  long save_b_p_ul = curbuf->b_p_ul;
  int save_w_p_cul = curwin->w_p_cul;
  int save_w_p_cuc = curwin->w_p_cuc;

  curbuf->b_p_ul = LONG_MAX;  // make sure we can undo all changes
  curwin->w_p_cul = false;    // Disable 'cursorline'
  curwin->w_p_cuc = false;    // Disable 'cursorcolumn'

  // Don't show search highlighting during live substitution
  bool save_hls = p_hls;
  p_hls = false;
  buf_T *preview_buf = do_sub(eap, profile_setlimit(p_rdt), false);
  p_hls = save_hls;

  if (save_changedtick != buf_get_changedtick(curbuf)) {
    // Undo invisibly. This also moves the cursor!
    if (!u_undo_and_forget(1)) { abort(); }
    // Restore newhead. It is meaningless when curhead is valid, but we must
    // restore it so that undotree() is identical before/after the preview.
    curbuf->b_u_newhead = save_b_u_newhead;
    curbuf->b_u_time_cur = save_b_u_time_cur;
    buf_set_changedtick(curbuf, save_changedtick);
  }
  if (buf_valid(preview_buf)) {
    // XXX: Must do this *after* u_undo_and_forget(), why?
    close_windows(preview_buf, false);
  }
  curbuf->b_p_ul = save_b_p_ul;
  curwin->w_p_cul = save_w_p_cul;   // Restore 'cursorline'
  curwin->w_p_cuc = save_w_p_cuc;   // Restore 'cursorcolumn'
  eap->arg = save_eap;
  restore_search_patterns();
  win_size_restore(&save_view);
  ga_clear(&save_view);
  unblock_autocmds();
}

/// Skip over the pattern argument of ":vimgrep /pat/[g][j]".
/// Put the start of the pattern in "*s", unless "s" is NULL.
/// If "flags" is not NULL put the flags in it: VGR_GLOBAL, VGR_NOJUMP.
/// If "s" is not NULL terminate the pattern with a NUL.
/// Return a pointer to the char just past the pattern plus flags.
char_u *skip_vimgrep_pat(char_u *p, char_u **s, int *flags)
{
  int c;

  if (vim_isIDc(*p)) {
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
    c = *p;
    p = skip_regexp(p + 1, c, true, NULL);
    if (*p != c) {
      return NULL;
    }

    // Truncate the pattern.
    if (s != NULL) {
      *p = NUL;
    }
    p++;

    // Find the flags
    while (*p == 'g' || *p == 'j') {
      if (flags != NULL) {
        if (*p == 'g') {
          *flags |= VGR_GLOBAL;
        } else {
          *flags |= VGR_NOJUMP;
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
  list_T      *l = get_vim_var_list(VV_OLDFILES);
  long nr = 0;

  if (l == NULL) {
    msg((char_u *)_("No old files"));
  } else {
    msg_start();
    msg_scroll = true;
    TV_LIST_ITER(l, li, {
      if (got_int) {
        break;
      }
      nr++;
      const char *fname = tv_get_string(TV_LIST_ITEM_TV(li));
      if (!message_filtered((char_u *)fname)) {
        msg_outnum(nr);
        MSG_PUTS(": ");
        msg_outtrans((char_u *)tv_get_string(TV_LIST_ITEM_TV(li)));
        msg_clr_eos();
        msg_putchar('\n');
        ui_flush();                  // output one line at a time
        os_breakcheck();
      }
    });

    // Assume "got_int" was set to truncate the listing.
    got_int = false;

    // File selection prompt on ":browse oldfiles"
    if (cmdmod.browse) {
      quit_more = false;
      nr = prompt_for_number(false);
      msg_starthere();
      if (nr > 0 && nr <= tv_list_len(l)) {
        const char *const p = tv_list_find_str(l, nr - 1);
        if (p == NULL) {
          return;
        }
        char *const s = (char *)expand_env_save((char_u *)p);
        eap->arg = (char_u *)s;
        eap->cmdidx = CMD_edit;
        cmdmod.browse = false;
        do_exedit(eap, NULL);
        xfree(s);
      }
    }
  }
}
