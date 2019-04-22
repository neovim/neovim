// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * quickfix.c: functions for quickfix mode, using a file with error messages
 */

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/quickfix.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_getln.h"
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
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/strings.h"
#include "nvim/ui.h"
#include "nvim/window.h"
#include "nvim/os/os.h"
#include "nvim/os/input.h"
#include "nvim/api/private/helpers.h"


struct dir_stack_T {
  struct dir_stack_T  *next;
  char_u              *dirname;
};

/*
 * For each error the next struct is allocated and linked in a list.
 */
typedef struct qfline_S qfline_T;
struct qfline_S {
  qfline_T    *qf_next;         /* pointer to next error in the list */
  qfline_T    *qf_prev;         /* pointer to previous error in the list */
  linenr_T qf_lnum;             /* line number where the error occurred */
  int qf_fnum;                  /* file number for the line */
  int qf_col;                   /* column where the error occurred */
  int qf_nr;                    /* error number */
  char_u      *qf_pattern;      /* search pattern for the error */
  char_u      *qf_text;         /* description of the error */
  char_u qf_viscol;             /* set to TRUE if qf_col is screen column */
  char_u qf_cleared;            /* set to TRUE if line has been deleted */
  char_u qf_type;               /* type of the error (mostly 'E'); 1 for
                                   :helpgrep */
  char_u qf_valid;              /* valid error message detected */
};

/*
 * There is a stack of error lists.
 */
#define LISTCOUNT   10

/// Quickfix/Location list definition
///
/// Usually the list contains one or more entries. But an empty list can be
/// created using setqflist()/setloclist() with a title and/or user context
/// information and entries can be added later using setqflist()/setloclist().
typedef struct qf_list_S {
  unsigned qf_id;               ///< Unique identifier for this list
  qfline_T    *qf_start;        ///< pointer to the first error
  qfline_T    *qf_last;         ///< pointer to the last error
  qfline_T    *qf_ptr;          ///< pointer to the current error
  int qf_count;                 ///< number of errors (0 means empty list)
  int qf_index;                 ///< current index in the error list
  int qf_nonevalid;             ///< TRUE if not a single valid entry found
  char_u      *qf_title;        ///< title derived from the command that created
                                ///< the error list or set by setqflist
  typval_T    *qf_ctx;          ///< context set by setqflist/setloclist

  struct dir_stack_T *qf_dir_stack;
  char_u *qf_directory;
  struct dir_stack_T *qf_file_stack;
  char_u *qf_currfile;
  bool qf_multiline;
  bool qf_multiignore;
  bool qf_multiscan;
} qf_list_T;

/// Quickfix/Location list stack definition
/// Contains a list of quickfix/location lists (qf_list_T)
struct qf_info_S {
  /*
   * Count of references to this list. Used only for location lists.
   * When a location list window reference this list, qf_refcount
   * will be 2. Otherwise, qf_refcount will be 1. When qf_refcount
   * reaches 0, the list is freed.
   */
  int qf_refcount;
  int qf_listcount;                 /* current number of lists */
  int qf_curlist;                   /* current error list */
  qf_list_T qf_lists[LISTCOUNT];
};

static qf_info_T ql_info;         // global quickfix list
static unsigned last_qf_id = 0;   // Last Used quickfix list id

#define FMT_PATTERNS 10         /* maximum number of % recognized */

/*
 * Structure used to hold the info of one part of 'errorformat'
 */
typedef struct efm_S efm_T;
struct efm_S {
  regprog_T       *prog;        /* pre-formatted part of 'errorformat' */
  efm_T           *next;        /* pointer to next (NULL if last) */
  char_u addr[FMT_PATTERNS];            /* indices of used % patterns */
  char_u prefix;                /* prefix of this format line: */
                                /*   'D' enter directory */
                                /*   'X' leave directory */
                                /*   'A' start of multi-line message */
                                /*   'E' error message */
                                /*   'W' warning message */
                                /*   'I' informational message */
                                /*   'C' continuation line */
                                /*   'Z' end of multi-line message */
                                /*   'G' general, unspecific message */
                                /*   'P' push file (partial) message */
                                /*   'Q' pop/quit file (partial) message */
                                /*   'O' overread (partial) message */
  char_u flags;                 /* additional flags given in prefix */
                                /*   '-' do not include this line */
                                /*   '+' include whole line in message */
  int conthere;                 /* %> used */
};

enum {
  QF_FAIL = 0,
  QF_OK = 1,
  QF_END_OF_INPUT = 2,
  QF_NOMEM = 3,
  QF_IGNORE_LINE = 4
};

typedef struct {
  char_u *linebuf;
  size_t linelen;
  char_u *growbuf;
  size_t growbufsiz;
  FILE   *fd;
  typval_T   *tv;
  char_u     *p_str;
  list_T     *p_list;
  listitem_T *p_li;
  buf_T      *buf;
  linenr_T buflnum;
  linenr_T lnumlast;
  vimconv_T vc;
} qfstate_T;

typedef struct {
  char_u *namebuf;
  char_u *errmsg;
  size_t errmsglen;
  long lnum;
  int  col;
  bool use_viscol;
  char_u *pattern;
  int    enr;
  char_u type;
  bool   valid;
} qffields_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "quickfix.c.generated.h"
#endif
/* Quickfix window check helper macro */
#define IS_QF_WINDOW(wp) (bt_quickfix(wp->w_buffer) && wp->w_llist_ref == NULL)
/* Location list window check helper macro */
#define IS_LL_WINDOW(wp) (bt_quickfix(wp->w_buffer) && wp->w_llist_ref != NULL)
/*
 * Return location list for window 'wp'
 * For location list window, return the referenced location list
 */
#define GET_LOC_LIST(wp) (IS_LL_WINDOW(wp) ? wp->w_llist_ref : wp->w_llist)

// Looking up a buffer can be slow if there are many.  Remember the last one
// to make this a lot faster if there are multiple matches in the same file.
static char_u *qf_last_bufname = NULL;
static bufref_T  qf_last_bufref = { NULL, 0, 0 };

/// Read the errorfile "efile" into memory, line by line, building the error
/// list. Set the error list's title to qf_title.
///
/// @params  wp  If non-NULL, make a location list
/// @params  efile  If non-NULL, errorfile to parse
/// @params  errorformat  'errorformat' string used to parse the error lines
/// @params  newlist  If true, create a new error list
/// @params  qf_title  If non-NULL, title of the error list
/// @params  enc  If non-NULL, encoding used to parse errors
///
/// @returns -1 for error, number of errors for success.
int qf_init(win_T *wp, char_u *efile, char_u *errorformat, int newlist,
            char_u *qf_title, char_u *enc)
{
  qf_info_T       *qi = &ql_info;

  if (wp != NULL) {
    qi = ll_get_or_alloc_list(wp);
  }

  return qf_init_ext(qi, qi->qf_curlist, efile, curbuf, NULL, errorformat,
                     newlist, (linenr_T)0, (linenr_T)0, qf_title, enc);
}

// Maximum number of bytes allowed per line while reading an errorfile.
static const size_t LINE_MAXLEN = 4096;

static struct fmtpattern
{
  char_u convchar;
  char *pattern;
} fmt_pat[FMT_PATTERNS] =
{
  { 'f', ".\\+" },  // only used when at end
  { 'n', "\\d\\+" },
  { 'l', "\\d\\+" },
  { 'c', "\\d\\+" },
  { 't', "." },
  { 'm', ".\\+" },
  { 'r', ".*" },
  { 'p', "[- 	.]*" },  // NOLINT(whitespace/tab)
  { 'v', "\\d\\+" },
  { 's', ".\\+" }
};

// Converts a 'errorformat' string to regular expression pattern
static int efm_to_regpat(char_u *efm, int len, efm_T *fmt_ptr,
                         char_u *regpat, char_u *errmsg)
{
  // Build regexp pattern from current 'errorformat' option
  char_u *ptr = regpat;
  *ptr++ = '^';
  int round = 0;
  for (char_u *efmp = efm; efmp < efm + len; efmp++) {
    if (*efmp == '%') {
      efmp++;
      int idx;
      for (idx = 0; idx < FMT_PATTERNS; idx++) {
        if (fmt_pat[idx].convchar == *efmp) {
          break;
        }
      }
      if (idx < FMT_PATTERNS) {
        if (fmt_ptr->addr[idx]) {
          snprintf((char *)errmsg, CMDBUFFSIZE + 1,
                   _("E372: Too many %%%c in format string"), *efmp);
          EMSG(errmsg);
          return -1;
        }
        if ((idx
             && idx < 6
             && vim_strchr((char_u *)"DXOPQ", fmt_ptr->prefix) != NULL)
            || (idx == 6
                && vim_strchr((char_u *)"OPQ", fmt_ptr->prefix) == NULL)) {
          snprintf((char *)errmsg, CMDBUFFSIZE + 1,
                   _("E373: Unexpected %%%c in format string"), *efmp);
          EMSG(errmsg);
          return -1;
        }
        round++;
        fmt_ptr->addr[idx] = (char_u)round;
        *ptr++ = '\\';
        *ptr++ = '(';
#ifdef BACKSLASH_IN_FILENAME
        if (*efmp == 'f') {
          // Also match "c:" in the file name, even when
          // checking for a colon next: "%f:".
          // "\%(\a:\)\="
          STRCPY(ptr, "\\%(\\a:\\)\\=");
          ptr += 10;
        }
#endif
        if (*efmp == 'f' && efmp[1] != NUL) {
          if (efmp[1] != '\\' && efmp[1] != '%') {
            // A file name may contain spaces, but this isn't
            // in "\f".  For "%f:%l:%m" there may be a ":" in
            // the file name.  Use ".\{-1,}x" instead (x is
            // the next character), the requirement that :999:
            // follows should work.
            STRCPY(ptr, ".\\{-1,}");
            ptr += 7;
          } else {
            // File name followed by '\\' or '%': include as
            // many file name chars as possible.
            STRCPY(ptr, "\\f\\+");
            ptr += 4;
          }
        } else {
          char_u *srcptr = (char_u *)fmt_pat[idx].pattern;
          while ((*ptr = *srcptr++) != NUL) {
            ptr++;
          }
        }
        *ptr++ = '\\';
        *ptr++ = ')';
      } else if (*efmp == '*') {
        if (*++efmp == '[' || *efmp == '\\') {
          if ((*ptr++ = *efmp) == '[') {  // %*[^a-z0-9] etc.
            if (efmp[1] == '^') {
              *ptr++ = *++efmp;
            }
            if (efmp < efm + len) {
              efmp++;
              *ptr++ = *efmp;    // could be ']'
              while (efmp < efm + len) {
                efmp++;
                if ((*ptr++ = *efmp) == ']') {
                  break;
                }
              }
              if (efmp == efm + len) {
                EMSG(_("E374: Missing ] in format string"));
                return -1;
              }
            }
          } else if (efmp < efm + len) {  // %*\D, %*\s etc.
            efmp++;
            *ptr++ = *efmp;
          }
          *ptr++ = '\\';
          *ptr++ = '+';
        } else {
          // TODO(vim): scanf()-like: %*ud, %*3c, %*f, ... ?
          snprintf((char *)errmsg, CMDBUFFSIZE + 1,
                   _("E375: Unsupported %%%c in format string"), *efmp);
          EMSG(errmsg);
          return -1;
        }
      } else if (vim_strchr((char_u *)"%\\.^$~[", *efmp) != NULL) {
        *ptr++ = *efmp;  // regexp magic characters
      } else if (*efmp == '#') {
        *ptr++ = '*';
      } else if (*efmp == '>') {
        fmt_ptr->conthere = true;
      } else if (efmp == efm + 1) {             // analyse prefix
        if (vim_strchr((char_u *)"+-", *efmp) != NULL) {
          fmt_ptr->flags = *efmp++;
        }
        if (vim_strchr((char_u *)"DXAEWICZGOPQ", *efmp) != NULL) {
          fmt_ptr->prefix = *efmp;
        } else {
          snprintf((char *)errmsg, CMDBUFFSIZE + 1,
                   _("E376: Invalid %%%c in format string prefix"), *efmp);
          EMSG(errmsg);
          return -1;
        }
      } else {
        snprintf((char *)errmsg, CMDBUFFSIZE + 1,
                 _("E377: Invalid %%%c in format string"), *efmp);
        EMSG(errmsg);
        return -1;
      }
    } else {                    // copy normal character
      if (*efmp == '\\' && efmp + 1 < efm + len) {
        efmp++;
      } else if (vim_strchr((char_u *)".*^$~[", *efmp) != NULL) {
        *ptr++ = '\\';  // escape regexp atoms
      }
      if (*efmp) {
        *ptr++ = *efmp;
      }
    }
  }
  *ptr++ = '$';
  *ptr = NUL;

  return 0;
}

static efm_T *fmt_start = NULL;  // cached across qf_parse_line() calls

static void free_efm_list(efm_T **efm_first)
{
  for (efm_T *efm_ptr = *efm_first; efm_ptr != NULL; efm_ptr = *efm_first) {
    *efm_first = efm_ptr->next;
    vim_regfree(efm_ptr->prog);
    xfree(efm_ptr);
  }

  fmt_start = NULL;
}

// Parse 'errorformat' option
static efm_T * parse_efm_option(char_u *efm)
{
  efm_T *fmt_ptr = NULL;
  efm_T *fmt_first = NULL;
  efm_T *fmt_last = NULL;
  int len;

  size_t errmsglen = CMDBUFFSIZE + 1;
  char_u *errmsg = xmalloc(errmsglen);

  // Get some space to modify the format string into.
  size_t i = (FMT_PATTERNS * 3) + (STRLEN(efm) << 2);
  for (int round = FMT_PATTERNS - 1; round >= 0; ) {
    i += STRLEN(fmt_pat[round--].pattern);
  }
  i += 2;   // "%f" can become two chars longer
  char_u *fmtstr = xmalloc(i);

  while (efm[0] != NUL) {
    // Allocate a new eformat structure and put it at the end of the list
    fmt_ptr = (efm_T *)xcalloc(1, sizeof(efm_T));
    if (fmt_first == NULL) {        // first one
      fmt_first = fmt_ptr;
    } else {
      fmt_last->next = fmt_ptr;
    }
    fmt_last = fmt_ptr;

    // Isolate one part in the 'errorformat' option
    for (len = 0; efm[len] != NUL && efm[len] != ','; len++) {
      if (efm[len] == '\\' && efm[len + 1] != NUL) {
        len++;
      }
    }

    if (efm_to_regpat(efm, len, fmt_ptr, fmtstr, errmsg) == -1) {
      goto parse_efm_error;
    }
    if ((fmt_ptr->prog = vim_regcomp(fmtstr, RE_MAGIC + RE_STRING)) == NULL) {
      goto parse_efm_error;
    }
    // Advance to next part
    efm = skip_to_option_part(efm + len);       // skip comma and spaces
  }

  if (fmt_first == NULL) {      // nothing found
    EMSG(_("E378: 'errorformat' contains no pattern"));
  }

  goto parse_efm_end;

parse_efm_error:
  free_efm_list(&fmt_first);

parse_efm_end:
  xfree(fmtstr);
  xfree(errmsg);

  return fmt_first;
}

static char_u *qf_grow_linebuf(qfstate_T *state, size_t newsz)
{
  // If the line exceeds LINE_MAXLEN exclude the last
  // byte since it's not a NL character.
  state->linelen = newsz > LINE_MAXLEN ? LINE_MAXLEN - 1 : newsz;
  if (state->growbuf == NULL) {
    state->growbuf = xmalloc(state->linelen + 1);
    state->growbufsiz = state->linelen;
  } else if (state->linelen > state->growbufsiz) {
    state->growbuf = xrealloc(state->growbuf, state->linelen + 1);
    state->growbufsiz = state->linelen;
  }
  return state->growbuf;
}

/// Get the next string (separated by newline) from state->p_str.
static int qf_get_next_str_line(qfstate_T *state)
{
  // Get the next line from the supplied string
  char_u *p_str = state->p_str;
  char_u *p;
  size_t len;

  if (*p_str == NUL) {  // Reached the end of the string
    return QF_END_OF_INPUT;
  }

  p = vim_strchr(p_str, '\n');
  if (p != NULL) {
    len = (size_t)(p - p_str) + 1;
  } else {
    len = STRLEN(p_str);
  }

  if (len > IOSIZE - 2) {
    state->linebuf = qf_grow_linebuf(state, len);
  } else {
    state->linebuf = IObuff;
    state->linelen = len;
  }
  STRLCPY(state->linebuf, p_str, state->linelen + 1);

  // Increment using len in order to discard the rest of the line if it
  // exceeds LINE_MAXLEN.
  p_str += len;
  state->p_str = p_str;

  return QF_OK;
}

/// Get the next string from state->p_Li.
static int qf_get_next_list_line(qfstate_T *state)
{
  listitem_T *p_li = state->p_li;
  size_t len;

  // Get the next line from the supplied list
  while (p_li != NULL
         && (TV_LIST_ITEM_TV(p_li)->v_type != VAR_STRING
             || TV_LIST_ITEM_TV(p_li)->vval.v_string == NULL)) {
    p_li = TV_LIST_ITEM_NEXT(state->p_list, p_li);  // Skip non-string items.
  }

  if (p_li == NULL) {  // End of the list.
    state->p_li = NULL;
    return QF_END_OF_INPUT;
  }

  len = STRLEN(TV_LIST_ITEM_TV(p_li)->vval.v_string);
  if (len > IOSIZE - 2) {
    state->linebuf = qf_grow_linebuf(state, len);
  } else {
    state->linebuf = IObuff;
    state->linelen = len;
  }

  STRLCPY(state->linebuf, TV_LIST_ITEM_TV(p_li)->vval.v_string,
          state->linelen + 1);

  state->p_li = TV_LIST_ITEM_NEXT(state->p_list, p_li);
  return QF_OK;
}

/// Get the next string from state->buf.
static int qf_get_next_buf_line(qfstate_T *state)
{
  char_u *p_buf = NULL;
  size_t len;

  // Get the next line from the supplied buffer
  if (state->buflnum > state->lnumlast) {
    return QF_END_OF_INPUT;
  }
  p_buf = ml_get_buf(state->buf, state->buflnum, false);
  state->buflnum += 1;

  len = STRLEN(p_buf);
  if (len > IOSIZE - 2) {
    state->linebuf = qf_grow_linebuf(state, len);
  } else {
    state->linebuf = IObuff;
    state->linelen = len;
  }
  STRLCPY(state->linebuf, p_buf, state->linelen + 1);

  return QF_OK;
}

/// Get the next string from file state->fd.
static int qf_get_next_file_line(qfstate_T *state)
{
  size_t growbuflen;

retry:
  errno = 0;
  if (fgets((char *)IObuff, IOSIZE, state->fd) == NULL) {
    if (errno == EINTR) {
        goto retry;
    }
    return QF_END_OF_INPUT;
  }

  bool discard = false;
  state->linelen = STRLEN(IObuff);
  if (state->linelen == IOSIZE - 1
      && !(IObuff[state->linelen - 1] == '\n')) {
    // The current line exceeds IObuff, continue reading using growbuf
    // until EOL or LINE_MAXLEN bytes is read.
    if (state->growbuf == NULL) {
      state->growbufsiz = 2 * (IOSIZE - 1);
      state->growbuf = xmalloc(state->growbufsiz);
    }

    // Copy the read part of the line, excluding null-terminator
    memcpy(state->growbuf, IObuff, IOSIZE - 1);
    growbuflen = state->linelen;

    for (;;) {
      errno = 0;
      if (fgets((char *)state->growbuf + growbuflen,
                (int)(state->growbufsiz - growbuflen), state->fd) == NULL) {
        if (errno == EINTR) {
          continue;
        }
        break;
      }
      state->linelen = STRLEN(state->growbuf + growbuflen);
      growbuflen += state->linelen;
      if (state->growbuf[growbuflen - 1] == '\n') {
        break;
      }
      if (state->growbufsiz == LINE_MAXLEN) {
        discard = true;
        break;
      }

      state->growbufsiz = (2 * state->growbufsiz < LINE_MAXLEN)
        ? 2 * state->growbufsiz : LINE_MAXLEN;
      state->growbuf = xrealloc(state->growbuf, state->growbufsiz);
    }

    while (discard) {
      // The current line is longer than LINE_MAXLEN, continue reading but
      // discard everything until EOL or EOF is reached.
      errno = 0;
      if (fgets((char *)IObuff, IOSIZE, state->fd) == NULL) {
        if (errno == EINTR) {
          continue;
        }
        break;
      }
      if (STRLEN(IObuff) < IOSIZE - 1 || IObuff[IOSIZE - 1] == '\n') {
        break;
      }
    }

    state->linebuf = state->growbuf;
    state->linelen = growbuflen;
  } else {
    state->linebuf = IObuff;
  }

  // Convert a line if it contains a non-ASCII character
  if (state->vc.vc_type != CONV_NONE && has_non_ascii(state->linebuf)) {
    char_u *line = string_convert(&state->vc, state->linebuf, &state->linelen);
    if (line != NULL) {
      if (state->linelen < IOSIZE) {
        STRLCPY(state->linebuf, line, state->linelen + 1);
        xfree(line);
      } else {
        xfree(state->growbuf);
        state->linebuf = state->growbuf = line;
        state->growbufsiz = state->linelen < LINE_MAXLEN
          ? state->linelen : LINE_MAXLEN;
      }
    }
  }
  return QF_OK;
}

/// Get the next string from a file/buffer/list/string.
static int qf_get_nextline(qfstate_T *state)
{
  int status = QF_FAIL;

  if (state->fd == NULL) {
    if (state->tv != NULL) {
      if (state->tv->v_type == VAR_STRING) {
        // Get the next line from the supplied string
        status = qf_get_next_str_line(state);
      } else if (state->tv->v_type == VAR_LIST) {
        // Get the next line from the supplied list
        status = qf_get_next_list_line(state);
      }
    } else {
      // Get the next line from the supplied buffer
      status = qf_get_next_buf_line(state);
    }
  } else {
    // Get the next line from the supplied file
    status = qf_get_next_file_line(state);
  }

  if (status != QF_OK) {
    return status;
  }

  if (state->linelen > 0 && state->linebuf[state->linelen - 1] == '\n') {
    state->linebuf[state->linelen - 1] = NUL;
#ifdef USE_CRNL
    if (state->linelen > 1 && state->linebuf[state->linelen - 2] == '\r') {
      state->linebuf[state->linelen - 2] = NUL;
    }
#endif
  }

  remove_bom(state->linebuf);

  return QF_OK;
}


/// Parse a line and get the quickfix fields.
/// Return the QF_ status.
static int qf_parse_line(qf_info_T *qi, int qf_idx, char_u *linebuf,
                         size_t linelen, efm_T *fmt_first, qffields_T *fields)
{
  efm_T *fmt_ptr;
  size_t len;
  int    i;
  int    idx = 0;
  char_u *tail = NULL;
  regmatch_T regmatch;
  qf_list_T *qfl = &qi->qf_lists[qf_idx];

  // Always ignore case when looking for a matching error.
  regmatch.rm_ic = true;

  // If there was no %> item start at the first pattern
  if (fmt_start == NULL) {
    fmt_ptr = fmt_first;
  } else {
    fmt_ptr = fmt_start;
    fmt_start = NULL;
  }

  // Try to match each part of 'errorformat' until we find a complete
  // match or no match.
  fields->valid = true;
restofline:
  for (; fmt_ptr != NULL; fmt_ptr = fmt_ptr->next) {
    idx = fmt_ptr->prefix;
    if (qfl->qf_multiscan && vim_strchr((char_u *)"OPQ", idx) == NULL) {
      continue;
    }
    fields->namebuf[0] = NUL;
    fields->pattern[0] = NUL;
    if (!qfl->qf_multiscan) {
      fields->errmsg[0] = NUL;
    }
    fields->lnum = 0;
    fields->col = 0;
    fields->use_viscol = false;
    fields->enr = -1;
    fields->type = 0;
    tail = NULL;

    regmatch.regprog = fmt_ptr->prog;
    int r = vim_regexec(&regmatch, linebuf, (colnr_T)0);
    fmt_ptr->prog = regmatch.regprog;
    if (r) {
      if ((idx == 'C' || idx == 'Z') && !qfl->qf_multiline) {
        continue;
      }
      if (vim_strchr((char_u *)"EWI", idx) != NULL) {
        fields->type = (char_u)idx;
      } else {
        fields->type = 0;
      }
      // Extract error message data from matched line.
      // We check for an actual submatch, because "\[" and "\]" in
      // the 'errorformat' may cause the wrong submatch to be used.
      if ((i = (int)fmt_ptr->addr[0]) > 0) {  // %f
        if (regmatch.startp[i] == NULL || regmatch.endp[i] == NULL) {
          continue;
        }
        // Expand ~/file and $HOME/file to full path.
        char_u c = *regmatch.endp[i];
        *regmatch.endp[i] = NUL;
        expand_env(regmatch.startp[i], fields->namebuf, CMDBUFFSIZE);
        *regmatch.endp[i] = c;

        if (vim_strchr((char_u *)"OPQ", idx) != NULL
            && !os_path_exists(fields->namebuf)) {
          continue;
        }
      }
      if ((i = (int)fmt_ptr->addr[1]) > 0) {                  // %n
        if (regmatch.startp[i] == NULL) {
          continue;
        }
        fields->enr = (int)atol((char *)regmatch.startp[i]);
      }
      if ((i = (int)fmt_ptr->addr[2]) > 0) {                  // %l
        if (regmatch.startp[i] == NULL) {
          continue;
        }
        fields->lnum = atol((char *)regmatch.startp[i]);
      }
      if ((i = (int)fmt_ptr->addr[3]) > 0) {                  // %c
        if (regmatch.startp[i] == NULL) {
          continue;
        }
        fields->col = (int)atol((char *)regmatch.startp[i]);
      }
      if ((i = (int)fmt_ptr->addr[4]) > 0) {                  // %t
        if (regmatch.startp[i] == NULL) {
          continue;
        }
        fields->type = *regmatch.startp[i];
      }
      if (fmt_ptr->flags == '+' && !qfl->qf_multiscan) {      // %+
        if (linelen >= fields->errmsglen) {
          // linelen + null terminator
          fields->errmsg = xrealloc(fields->errmsg, linelen + 1);
          fields->errmsglen = linelen + 1;
        }
        STRLCPY(fields->errmsg, linebuf, linelen + 1);
      } else if ((i = (int)fmt_ptr->addr[5]) > 0) {           // %m
        if (regmatch.startp[i] == NULL || regmatch.endp[i] == NULL) {
          continue;
        }
        len = (size_t)(regmatch.endp[i] - regmatch.startp[i]);
        if (len >= fields->errmsglen) {
          // len + null terminator
          fields->errmsg = xrealloc(fields->errmsg, len + 1);
          fields->errmsglen = len + 1;
        }
        STRLCPY(fields->errmsg, regmatch.startp[i], len + 1);
      }
      if ((i = (int)fmt_ptr->addr[6]) > 0) {                  // %r
        if (regmatch.startp[i] == NULL) {
          continue;
        }
        tail = regmatch.startp[i];
      }
      if ((i = (int)fmt_ptr->addr[7]) > 0) {                  // %p
        char_u      *match_ptr;

        if (regmatch.startp[i] == NULL || regmatch.endp[i] == NULL) {
          continue;
        }
        fields->col = 0;
        for (match_ptr = regmatch.startp[i];
             match_ptr != regmatch.endp[i]; match_ptr++) {
          fields->col++;
          if (*match_ptr == TAB) {
            fields->col += 7;
            fields->col -= fields->col % 8;
          }
        }
        fields->col++;
        fields->use_viscol = true;
      }
      if ((i = (int)fmt_ptr->addr[8]) > 0) {                  // %v
        if (regmatch.startp[i] == NULL) {
          continue;
        }
        fields->col = (int)atol((char *)regmatch.startp[i]);
        fields->use_viscol = true;
      }
      if ((i = (int)fmt_ptr->addr[9]) > 0) {                  // %s
        if (regmatch.startp[i] == NULL || regmatch.endp[i] == NULL) {
          continue;
        }
        len = (size_t)(regmatch.endp[i] - regmatch.startp[i]);
        if (len > CMDBUFFSIZE - 5) {
          len = CMDBUFFSIZE - 5;
        }
        STRCPY(fields->pattern, "^\\V");
        xstrlcat((char *)fields->pattern, (char *)regmatch.startp[i],
                 CMDBUFFSIZE+1);
        fields->pattern[len + 3] = '\\';
        fields->pattern[len + 4] = '$';
        fields->pattern[len + 5] = NUL;
      }
      break;
    }
  }
  qfl->qf_multiscan = false;

  if (fmt_ptr == NULL || idx == 'D' || idx == 'X') {
    if (fmt_ptr != NULL) {
      if (idx == 'D') {                               // enter directory
        if (*fields->namebuf == NUL) {
          EMSG(_("E379: Missing or empty directory name"));
          return QF_FAIL;
        }
        qfl->qf_directory = qf_push_dir(fields->namebuf, &qfl->qf_dir_stack,
                                        false);
        if (qfl->qf_directory == NULL) {
          return QF_FAIL;
        }
      } else if (idx == 'X') {                        // leave directory
        qfl->qf_directory = qf_pop_dir(&qfl->qf_dir_stack);
      }
    }
    fields->namebuf[0] = NUL;                // no match found, remove file name
    fields->lnum = 0;                        // don't jump to this line
    fields->valid = false;
    if (linelen >= fields->errmsglen) {
      // linelen + null terminator
      fields->errmsg = xrealloc(fields->errmsg, linelen + 1);
      fields->errmsglen = linelen + 1;
    }
    // copy whole line to error message
    STRLCPY(fields->errmsg, linebuf, linelen + 1);
    if (fmt_ptr == NULL) {
      qfl->qf_multiline = qfl->qf_multiignore = false;
    }
  } else {
    // honor %> item
    if (fmt_ptr->conthere) {
      fmt_start = fmt_ptr;
    }

    if (vim_strchr((char_u *)"AEWI", idx) != NULL) {
      qfl->qf_multiline = true;     // start of a multi-line message
      qfl->qf_multiignore = false;  // reset continuation
    } else if (vim_strchr((char_u *)"CZ", idx)
               != NULL) {  // continuation of multi-line msg
      if (!qfl->qf_multiignore) {
        qfline_T *qfprev = qfl->qf_last;
        if (qfprev == NULL) {
          return QF_FAIL;
        }
        if (*fields->errmsg) {
          size_t textlen = STRLEN(qfprev->qf_text);
          qfprev->qf_text = xrealloc(qfprev->qf_text,
                                     textlen + STRLEN(fields->errmsg) + 2);
          qfprev->qf_text[textlen] = '\n';
          STRCPY(qfprev->qf_text + textlen + 1, fields->errmsg);
        }
        if (qfprev->qf_nr == -1) {
          qfprev->qf_nr = fields->enr;
        }
        if (vim_isprintc(fields->type) && !qfprev->qf_type) {
          qfprev->qf_type = fields->type;  // only printable chars allowed
        }
        if (!qfprev->qf_lnum) {
          qfprev->qf_lnum = fields->lnum;
        }
        if (!qfprev->qf_col) {
          qfprev->qf_col = fields->col;
        }
        qfprev->qf_viscol = fields->use_viscol;
        if (!qfprev->qf_fnum) {
          qfprev->qf_fnum = qf_get_fnum(qi, qf_idx, qfl->qf_directory,
                                        *fields->namebuf || qfl->qf_directory
                                        ? fields->namebuf
                                        : qfl->qf_currfile && fields->valid
                                        ? qfl->qf_currfile : 0);
        }
      }
      if (idx == 'Z') {
        qfl->qf_multiline = qfl->qf_multiignore = false;
      }

      line_breakcheck();
      return QF_IGNORE_LINE;
    } else if (vim_strchr((char_u *)"OPQ", idx) != NULL) {
      // global file names
      fields->valid = false;
      if (*fields->namebuf == NUL || os_path_exists(fields->namebuf)) {
        if (*fields->namebuf && idx == 'P') {
          qfl->qf_currfile = qf_push_dir(fields->namebuf, &qfl->qf_file_stack,
                                         true);
        } else if (idx == 'Q') {
          qfl->qf_currfile = qf_pop_dir(&qfl->qf_file_stack);
        }
        *fields->namebuf = NUL;
        if (tail && *tail) {
          STRMOVE(IObuff, skipwhite(tail));
          qfl->qf_multiscan = true;
          goto restofline;
        }
      }
    }
    if (fmt_ptr->flags == '-') {  // generally exclude this line
      if (qfl->qf_multiline) {
        // also exclude continuation lines
        qfl->qf_multiignore = true;
      }
      return QF_IGNORE_LINE;
    }
  }

  return QF_OK;
}

// Read the errorfile "efile" into memory, line by line, building the error
// list.
// Alternative: when "efile" is NULL read errors from buffer "buf".
// Alternative: when "tv" is not NULL get errors from the string or list.
// Always use 'errorformat' from "buf" if there is a local value.
// Then "lnumfirst" and "lnumlast" specify the range of lines to use.
// Set the title of the list to "qf_title".
// Return -1 for error, number of errors for success.
static int
qf_init_ext(
    qf_info_T *qi,
    int qf_idx,
    char_u *efile,
    buf_T *buf,
    typval_T *tv,
    char_u *errorformat,
    int newlist,                            // TRUE: start a new error list
    linenr_T lnumfirst,                     // first line number to use
    linenr_T lnumlast,                      // last line number to use
    char_u *qf_title,
    char_u *enc
)
{
  qfstate_T state;
  qffields_T fields;
  qfline_T        *old_last = NULL;
  bool adding = false;
  static efm_T    *fmt_first = NULL;
  char_u          *efm;
  static char_u   *last_efm = NULL;
  int retval = -1;                      // default: return error flag
  int status;

  // Do not used the cached buffer, it may have been wiped out.
  xfree(qf_last_bufname);
  qf_last_bufname = NULL;

  memset(&state, 0, sizeof(state));
  memset(&fields, 0, sizeof(fields));
  state.vc.vc_type = CONV_NONE;
  if (enc != NULL && *enc != NUL) {
    convert_setup(&state.vc, enc, p_enc);
  }

  fields.namebuf = xmalloc(CMDBUFFSIZE + 1);
  fields.errmsglen = CMDBUFFSIZE + 1;
  fields.errmsg = xmalloc(fields.errmsglen);
  fields.pattern = xmalloc(CMDBUFFSIZE + 1);

  if (efile != NULL && (state.fd = mch_fopen((char *)efile, "r")) == NULL) {
    EMSG2(_(e_openerrf), efile);
    goto qf_init_end;
  }

  if (newlist || qf_idx == qi->qf_listcount) {
    // make place for a new list
    qf_new_list(qi, qf_title);
    qf_idx = qi->qf_curlist;
  } else {
    // Adding to existing list, use last entry.
    adding = true;
    if (qi->qf_lists[qf_idx].qf_count > 0) {
      old_last = qi->qf_lists[qf_idx].qf_last;
    }
  }

  qf_list_T *qfl = &qi->qf_lists[qf_idx];

  // Use the local value of 'errorformat' if it's set.
  if (errorformat == p_efm && tv == NULL && buf && *buf->b_p_efm != NUL) {
    efm = buf->b_p_efm;
  } else {
    efm = errorformat;
  }

  // If the errorformat didn't change between calls, then reuse the previously
  // parsed values.
  if (last_efm == NULL || (STRCMP(last_efm, efm) != 0)) {
    // free the previously parsed data
    xfree(last_efm);
    last_efm = NULL;
    free_efm_list(&fmt_first);

    // parse the current 'efm'
    fmt_first = parse_efm_option(efm);
    if (fmt_first != NULL) {
      last_efm = vim_strsave(efm);
    }
  }

  if (fmt_first == NULL) {      // nothing found
    goto error2;
  }

  /*
   * got_int is reset here, because it was probably set when killing the
   * ":make" command, but we still want to read the errorfile then.
   */
  got_int = FALSE;

  if (tv != NULL) {
    if (tv->v_type == VAR_STRING) {
      state.p_str = tv->vval.v_string;
    } else if (tv->v_type == VAR_LIST) {
      state.p_list = tv->vval.v_list;
      state.p_li = tv_list_first(tv->vval.v_list);
    }
    state.tv = tv;
  }
  state.buf = buf;
  state.buflnum  = lnumfirst;
  state.lnumlast = lnumlast;

  /*
   * Read the lines in the error file one by one.
   * Try to recognize one of the error formats in each line.
   */
  while (!got_int) {
    // Get the next line from a file/buffer/list/string
    status = qf_get_nextline(&state);
    if (status == QF_END_OF_INPUT) {  // end of input
      break;
    }

    status = qf_parse_line(qi, qf_idx, state.linebuf, state.linelen,
                           fmt_first, &fields);
    if (status == QF_FAIL) {
      goto error2;
    }
    if (status == QF_IGNORE_LINE) {
      continue;
    }

    if (qf_add_entry(qi,
                     qf_idx,
                     qfl->qf_directory,
                     (*fields.namebuf || qfl->qf_directory)
                     ? fields.namebuf : ((qfl->qf_currfile && fields.valid)
                                         ? qfl->qf_currfile : (char_u *)NULL),
                     0,
                     fields.errmsg,
                     fields.lnum,
                     fields.col,
                     fields.use_viscol,
                     fields.pattern,
                     fields.enr,
                     fields.type,
                     fields.valid) == FAIL) {
      goto error2;
    }
    line_breakcheck();
  }
  if (state.fd == NULL || !ferror(state.fd)) {
    if (qfl->qf_index == 0) {
      // no valid entry found
      qfl->qf_ptr = qfl->qf_start;
      qfl->qf_index = 1;
      qfl->qf_nonevalid = true;
    } else {
      qfl->qf_nonevalid = false;
      if (qfl->qf_ptr == NULL) {
        qfl->qf_ptr = qfl->qf_start;
      }
    }
    // return number of matches
    retval = qfl->qf_count;
    goto qf_init_end;
  }
  EMSG(_(e_readerrf));
error2:
  if (!adding) {
    // Error when creating a new list. Free the new list
    qf_free(qi, qi->qf_curlist);
    qi->qf_listcount--;
    if (qi->qf_curlist > 0) {
      qi->qf_curlist--;
    }
  }
qf_init_end:
  if (state.fd != NULL) {
    fclose(state.fd);
  }
  xfree(fields.namebuf);
  xfree(fields.errmsg);
  xfree(fields.pattern);
  xfree(state.growbuf);

  if (qf_idx == qi->qf_curlist) {
    qf_update_buffer(qi, old_last);
  }

  if (state.vc.vc_type != CONV_NONE) {
    convert_setup(&state.vc, NULL, NULL);
  }

  return retval;
}

static void qf_store_title(qf_info_T *qi, int qf_idx, char_u *title)
{
  xfree(qi->qf_lists[qf_idx].qf_title);
  qi->qf_lists[qf_idx].qf_title = NULL;

  if (title != NULL) {
    size_t len = STRLEN(title) + 1;
    char_u *p = xmallocz(len);

    qi->qf_lists[qf_idx].qf_title = p;
    snprintf((char *)p, len + 1, ":%s", (char *)title);
  }
}

// Prepare for adding a new quickfix list. If the current list is in the
// middle of the stack, then all the following lists are freed and then
// the new list is added.
static void qf_new_list(qf_info_T *qi, char_u *qf_title)
{
  int i;

  // If the current entry is not the last entry, delete entries beyond
  // the current entry.  This makes it possible to browse in a tree-like
  // way with ":grep'.
  while (qi->qf_listcount > qi->qf_curlist + 1)
    qf_free(qi, --qi->qf_listcount);

  /*
   * When the stack is full, remove to oldest entry
   * Otherwise, add a new entry.
   */
  if (qi->qf_listcount == LISTCOUNT) {
    qf_free(qi, 0);
    for (i = 1; i < LISTCOUNT; ++i)
      qi->qf_lists[i - 1] = qi->qf_lists[i];
    qi->qf_curlist = LISTCOUNT - 1;
  } else
    qi->qf_curlist = qi->qf_listcount++;
  memset(&qi->qf_lists[qi->qf_curlist], 0, (size_t)(sizeof(qf_list_T)));
  qf_store_title(qi, qi->qf_curlist, qf_title);
  qi->qf_lists[qi->qf_curlist].qf_id = ++last_qf_id;
}

/*
 * Free a location list
 */
static void ll_free_all(qf_info_T **pqi)
{
  int i;
  qf_info_T   *qi;

  qi = *pqi;
  if (qi == NULL)
    return;
  *pqi = NULL;          /* Remove reference to this list */

  qi->qf_refcount--;
  if (qi->qf_refcount < 1) {
    /* No references to this location list */
    for (i = 0; i < qi->qf_listcount; ++i)
      qf_free(qi, i);
    xfree(qi);
  }
}

void qf_free_all(win_T *wp)
{
  int i;
  qf_info_T   *qi = &ql_info;

  if (wp != NULL) {
    /* location list */
    ll_free_all(&wp->w_llist);
    ll_free_all(&wp->w_llist_ref);
  } else
    /* quickfix list */
    for (i = 0; i < qi->qf_listcount; ++i)
      qf_free(qi, i);
}

/// Add an entry to the end of the list of errors.
///
/// @param  qi       quickfix list
/// @param  qf_idx   list index
/// @param  dir      optional directory name
/// @param  fname    file name or NULL
/// @param  bufnum   buffer number or zero
/// @param  mesg     message
/// @param  lnum     line number
/// @param  col      column
/// @param  vis_col  using visual column
/// @param  pattern  search pattern
/// @param  nr       error number
/// @param  type     type character
/// @param  valid    valid entry
///
/// @returns OK or FAIL.
static int qf_add_entry(qf_info_T *qi, int qf_idx, char_u *dir, char_u *fname,
                        int bufnum, char_u *mesg, long lnum, int col,
                        char_u vis_col, char_u *pattern, int nr, char_u type,
                        char_u valid)
{
  qfline_T *qfp = xmalloc(sizeof(qfline_T));
  qfline_T **lastp;  // pointer to qf_last or NULL

  if (bufnum != 0) {
    buf_T *buf = buflist_findnr(bufnum);

    qfp->qf_fnum = bufnum;
    if (buf != NULL) {
      buf->b_has_qf_entry |=
        (qi == &ql_info) ? BUF_HAS_QF_ENTRY : BUF_HAS_LL_ENTRY;
    }
  } else {
    qfp->qf_fnum = qf_get_fnum(qi, qf_idx, dir, fname);
  }
  qfp->qf_text = vim_strsave(mesg);
  qfp->qf_lnum = lnum;
  qfp->qf_col = col;
  qfp->qf_viscol = vis_col;
  if (pattern == NULL || *pattern == NUL) {
    qfp->qf_pattern = NULL;
  } else {
    qfp->qf_pattern = vim_strsave(pattern);
  }
  qfp->qf_nr = nr;
  if (type != 1 && !vim_isprintc(type))   /* only printable chars allowed */
    type = 0;
  qfp->qf_type = (char_u)type;
  qfp->qf_valid = valid;

  lastp = &qi->qf_lists[qf_idx].qf_last;
  if (qi->qf_lists[qf_idx].qf_count == 0) {
    // first element in the list
    qi->qf_lists[qf_idx].qf_start = qfp;
    qi->qf_lists[qf_idx].qf_ptr = qfp;
    qi->qf_lists[qf_idx].qf_index = 0;
    qfp->qf_prev = NULL;
  } else {
    assert(*lastp);
    qfp->qf_prev = *lastp;
    (*lastp)->qf_next = qfp;
  }
  qfp->qf_next = NULL;
  qfp->qf_cleared = false;
  *lastp = qfp;
  qi->qf_lists[qf_idx].qf_count++;
  if (qi->qf_lists[qf_idx].qf_index == 0 && qfp->qf_valid) {
    // first valid entry
    qi->qf_lists[qf_idx].qf_index = qi->qf_lists[qf_idx].qf_count;
    qi->qf_lists[qf_idx].qf_ptr = qfp;
  }

  return OK;
}

/*
 * Allocate a new location list
 */
static qf_info_T *ll_new_list(void)
{
  qf_info_T *qi = xcalloc(1, sizeof(qf_info_T));
  qi->qf_refcount++;

  return qi;
}

/*
 * Return the location list for window 'wp'.
 * If not present, allocate a location list
 */
static qf_info_T *ll_get_or_alloc_list(win_T *wp)
{
  if (IS_LL_WINDOW(wp))
    /* For a location list window, use the referenced location list */
    return wp->w_llist_ref;

  /*
   * For a non-location list window, w_llist_ref should not point to a
   * location list.
   */
  ll_free_all(&wp->w_llist_ref);

  if (wp->w_llist == NULL)
    wp->w_llist = ll_new_list();            /* new location list */
  return wp->w_llist;
}

/*
 * Copy the location list from window "from" to window "to".
 */
void copy_loclist(win_T *from, win_T *to)
{
  qf_info_T   *qi;
  int idx;
  int i;

  /*
   * When copying from a location list window, copy the referenced
   * location list. For other windows, copy the location list for
   * that window.
   */
  if (IS_LL_WINDOW(from))
    qi = from->w_llist_ref;
  else
    qi = from->w_llist;

  if (qi == NULL)                   /* no location list to copy */
    return;

  /* allocate a new location list */
  to->w_llist = ll_new_list();

  to->w_llist->qf_listcount = qi->qf_listcount;

  /* Copy the location lists one at a time */
  for (idx = 0; idx < qi->qf_listcount; idx++) {
    qf_list_T   *from_qfl;
    qf_list_T   *to_qfl;

    to->w_llist->qf_curlist = idx;

    from_qfl = &qi->qf_lists[idx];
    to_qfl = &to->w_llist->qf_lists[idx];

    /* Some of the fields are populated by qf_add_entry() */
    to_qfl->qf_nonevalid = from_qfl->qf_nonevalid;
    to_qfl->qf_count = 0;
    to_qfl->qf_index = 0;
    to_qfl->qf_start = NULL;
    to_qfl->qf_last = NULL;
    to_qfl->qf_ptr = NULL;
    if (from_qfl->qf_title != NULL)
      to_qfl->qf_title = vim_strsave(from_qfl->qf_title);
    else
      to_qfl->qf_title = NULL;

    if (from_qfl->qf_ctx != NULL) {
      to_qfl->qf_ctx = xcalloc(1, sizeof(typval_T));
      tv_copy(from_qfl->qf_ctx, to_qfl->qf_ctx);
    } else {
      to_qfl->qf_ctx = NULL;
    }

    if (from_qfl->qf_count) {
      qfline_T    *from_qfp;
      qfline_T    *prevp;

      // copy all the location entries in this list
      for (i = 0, from_qfp = from_qfl->qf_start;
           i < from_qfl->qf_count && from_qfp != NULL;
           i++, from_qfp = from_qfp->qf_next) {
        if (qf_add_entry(to->w_llist,
                         to->w_llist->qf_curlist,
                         NULL,
                         NULL,
                         0,
                         from_qfp->qf_text,
                         from_qfp->qf_lnum,
                         from_qfp->qf_col,
                         from_qfp->qf_viscol,
                         from_qfp->qf_pattern,
                         from_qfp->qf_nr,
                         0,
                         from_qfp->qf_valid) == FAIL) {
          qf_free_all(to);
          return;
        }
        /*
         * qf_add_entry() will not set the qf_num field, as the
         * directory and file names are not supplied. So the qf_fnum
         * field is copied here.
         */
        prevp = to->w_llist->qf_lists[to->w_llist->qf_curlist].qf_last;
        prevp->qf_fnum = from_qfp->qf_fnum;         // file number
        prevp->qf_type = from_qfp->qf_type;         // error type
        if (from_qfl->qf_ptr == from_qfp) {
          to_qfl->qf_ptr = prevp;                   // current location
        }
      }
    }

    to_qfl->qf_index = from_qfl->qf_index;      /* current index in the list */

    // Assign a new ID for the location list
    to_qfl->qf_id = ++last_qf_id;

    /* When no valid entries are present in the list, qf_ptr points to
     * the first item in the list */
    if (to_qfl->qf_nonevalid) {
      to_qfl->qf_ptr = to_qfl->qf_start;
      to_qfl->qf_index = 1;
    }
  }

  to->w_llist->qf_curlist = qi->qf_curlist;     /* current list */
}

// Get buffer number for file "directory/fname".
// Also sets the b_has_qf_entry flag.
static int qf_get_fnum(qf_info_T *qi, int qf_idx, char_u *directory,
                       char_u *fname)
{
  char_u *ptr = NULL;
  char_u *bufname;
  buf_T *buf;
  if (fname == NULL || *fname == NUL) {         // no file name
    return 0;
  }

#ifdef BACKSLASH_IN_FILENAME
  if (directory != NULL) {
    slash_adjust(directory);
  }
  slash_adjust(fname);
#endif
  if (directory != NULL && !vim_isAbsName(fname)) {
    ptr = (char_u *)concat_fnames((char *)directory, (char *)fname, true);
    // Here we check if the file really exists.
    // This should normally be true, but if make works without
    // "leaving directory"-messages we might have missed a
    // directory change.
    if (!os_path_exists(ptr)) {
      xfree(ptr);
      directory = qf_guess_filepath(qi, qf_idx, fname);
      if (directory) {
        ptr = (char_u *)concat_fnames((char *)directory, (char *)fname, true);
      } else {
        ptr = vim_strsave(fname);
      }
    }
    // Use concatenated directory name and file name.
    bufname = ptr;
  } else {
    bufname = fname;
  }

  if (qf_last_bufname != NULL
      && STRCMP(bufname, qf_last_bufname) == 0
      && bufref_valid(&qf_last_bufref)) {
    buf = qf_last_bufref.br_buf;
    xfree(ptr);
  } else {
    xfree(qf_last_bufname);
    buf = buflist_new(bufname, NULL, (linenr_T)0, BLN_NOOPT);
    qf_last_bufname = (bufname == ptr) ? bufname : vim_strsave(bufname);
    set_bufref(&qf_last_bufref, buf);
  }
  if (buf == NULL) {
    return 0;
  }
  buf->b_has_qf_entry =
    (qi == &ql_info) ? BUF_HAS_QF_ENTRY : BUF_HAS_LL_ENTRY;
  return buf->b_fnum;
}

// Push dirbuf onto the directory stack and return pointer to actual dir or
// NULL on error.
static char_u *qf_push_dir(char_u *dirbuf, struct dir_stack_T **stackptr,
                           bool is_file_stack)
{
  struct dir_stack_T  *ds_ptr;

  /* allocate new stack element and hook it in */
  struct dir_stack_T *ds_new = xmalloc(sizeof(struct dir_stack_T));

  ds_new->next = *stackptr;
  *stackptr = ds_new;

  /* store directory on the stack */
  if (vim_isAbsName(dirbuf)
      || (*stackptr)->next == NULL
      || (*stackptr && is_file_stack))
    (*stackptr)->dirname = vim_strsave(dirbuf);
  else {
    /* Okay we don't have an absolute path.
     * dirbuf must be a subdir of one of the directories on the stack.
     * Let's search...
     */
    ds_new = (*stackptr)->next;
    (*stackptr)->dirname = NULL;
    while (ds_new) {
      xfree((*stackptr)->dirname);
      (*stackptr)->dirname = (char_u *)concat_fnames((char *)ds_new->dirname,
          (char *)dirbuf, TRUE);
      if (os_isdir((*stackptr)->dirname))
        break;

      ds_new = ds_new->next;
    }

    /* clean up all dirs we already left */
    while ((*stackptr)->next != ds_new) {
      ds_ptr = (*stackptr)->next;
      (*stackptr)->next = (*stackptr)->next->next;
      xfree(ds_ptr->dirname);
      xfree(ds_ptr);
    }

    /* Nothing found -> it must be on top level */
    if (ds_new == NULL) {
      xfree((*stackptr)->dirname);
      (*stackptr)->dirname = vim_strsave(dirbuf);
    }
  }

  if ((*stackptr)->dirname != NULL)
    return (*stackptr)->dirname;
  else {
    ds_ptr = *stackptr;
    *stackptr = (*stackptr)->next;
    xfree(ds_ptr);
    return NULL;
  }
}


/*
 * pop dirbuf from the directory stack and return previous directory or NULL if
 * stack is empty
 */
static char_u *qf_pop_dir(struct dir_stack_T **stackptr)
{
  struct dir_stack_T  *ds_ptr;

  /* TODO: Should we check if dirbuf is the directory on top of the stack?
   * What to do if it isn't? */

  /* pop top element and free it */
  if (*stackptr != NULL) {
    ds_ptr = *stackptr;
    *stackptr = (*stackptr)->next;
    xfree(ds_ptr->dirname);
    xfree(ds_ptr);
  }

  /* return NEW top element as current dir or NULL if stack is empty*/
  return *stackptr ? (*stackptr)->dirname : NULL;
}

/*
 * clean up directory stack
 */
static void qf_clean_dir_stack(struct dir_stack_T **stackptr)
{
  struct dir_stack_T  *ds_ptr;

  while ((ds_ptr = *stackptr) != NULL) {
    *stackptr = (*stackptr)->next;
    xfree(ds_ptr->dirname);
    xfree(ds_ptr);
  }
}

/*
 * Check in which directory of the directory stack the given file can be
 * found.
 * Returns a pointer to the directory name or NULL if not found.
 * Cleans up intermediate directory entries.
 *
 * TODO: How to solve the following problem?
 * If we have the this directory tree:
 *     ./
 *     ./aa
 *     ./aa/bb
 *     ./bb
 *     ./bb/x.c
 * and make says:
 *     making all in aa
 *     making all in bb
 *     x.c:9: Error
 * Then qf_push_dir thinks we are in ./aa/bb, but we are in ./bb.
 * qf_guess_filepath will return NULL.
 */
static char_u *qf_guess_filepath(qf_info_T *qi, int qf_idx, char_u *filename)
{
  struct dir_stack_T     *ds_ptr;
  struct dir_stack_T     *ds_tmp;
  char_u                 *fullname;
  qf_list_T *qfl = &qi->qf_lists[qf_idx];

  // no dirs on the stack - there's nothing we can do
  if (qfl->qf_dir_stack == NULL) {
    return NULL;
  }

  ds_ptr = qfl->qf_dir_stack->next;
  fullname = NULL;
  while (ds_ptr) {
    xfree(fullname);
    fullname = (char_u *)concat_fnames((char *)ds_ptr->dirname, (char *)filename, TRUE);

    if (os_path_exists(fullname)) {
      break;
    }

    ds_ptr = ds_ptr->next;
  }

  xfree(fullname);

  // clean up all dirs we already left
  while (qfl->qf_dir_stack->next != ds_ptr) {
    ds_tmp = qfl->qf_dir_stack->next;
    qfl->qf_dir_stack->next = qfl->qf_dir_stack->next->next;
    xfree(ds_tmp->dirname);
    xfree(ds_tmp);
  }

  return ds_ptr == NULL ? NULL : ds_ptr->dirname;
}

/// When loading a file from the quickfix, the auto commands may modify it.
/// This may invalidate the current quickfix entry.  This function checks
/// whether a entry is still present in the quickfix.
/// Similar to location list.
static bool is_qf_entry_present(qf_info_T *qi, qfline_T *qf_ptr)
{
  qf_list_T *qfl;
  qfline_T *qfp;
  int i;

  qfl = &qi->qf_lists[qi->qf_curlist];

  // Search for the entry in the current list
  for (i = 0, qfp = qfl->qf_start; i < qfl->qf_count; i++, qfp = qfp->qf_next) {
    if (qfp == NULL || qfp == qf_ptr) {
      break;
    }
  }

  if (i == qfl->qf_count) {  // Entry is not found
    return false;
  }

  return true;
}

/// Get the next valid entry in the current quickfix/location list. The search
/// starts from the current entry. Returns NULL on failure.
static qfline_T *get_next_valid_entry(qf_info_T *qi, qfline_T *qf_ptr,
                                      int *qf_index, int dir)
{
  int idx = *qf_index;
  int old_qf_fnum = qf_ptr->qf_fnum;

  do {
    if (idx == qi->qf_lists[qi->qf_curlist].qf_count
        || qf_ptr->qf_next == NULL) {
      return NULL;
    }
    idx++;
    qf_ptr = qf_ptr->qf_next;
  } while ((!qi->qf_lists[qi->qf_curlist].qf_nonevalid && !qf_ptr->qf_valid)
           || (dir == FORWARD_FILE && qf_ptr->qf_fnum == old_qf_fnum));

  *qf_index = idx;
  return qf_ptr;
}

/// Get the previous valid entry in the current quickfix/location list. The
/// search starts from the current entry. Returns NULL on failure.
static qfline_T *get_prev_valid_entry(qf_info_T *qi, qfline_T *qf_ptr,
                                      int *qf_index, int dir)
{
  int idx = *qf_index;
  int old_qf_fnum = qf_ptr->qf_fnum;

  do {
    if (idx == 1 || qf_ptr->qf_prev == NULL) {
      return NULL;
    }
    idx--;
    qf_ptr = qf_ptr->qf_prev;
  } while ((!qi->qf_lists[qi->qf_curlist].qf_nonevalid && !qf_ptr->qf_valid)
           || (dir == BACKWARD_FILE && qf_ptr->qf_fnum == old_qf_fnum));

  *qf_index = idx;
  return qf_ptr;
}

/// Get the n'th (errornr) previous/next valid entry from the current entry in
/// the quickfix list.
///   dir == FORWARD or FORWARD_FILE: next valid entry
///   dir == BACKWARD or BACKWARD_FILE: previous valid entry
static qfline_T *get_nth_valid_entry(qf_info_T *qi, int errornr,
                                     qfline_T *qf_ptr, int *qf_index, int dir)
{
  qfline_T *prev_qf_ptr;
  int prev_index;
  static char_u *e_no_more_items = (char_u *)N_("E553: No more items");
  char_u *err = e_no_more_items;

  while (errornr--) {
    prev_qf_ptr = qf_ptr;
    prev_index = *qf_index;

    if (dir == FORWARD || dir == FORWARD_FILE) {
      qf_ptr = get_next_valid_entry(qi, qf_ptr, qf_index, dir);
    } else {
      qf_ptr = get_prev_valid_entry(qi, qf_ptr, qf_index, dir);
    }

    if (qf_ptr == NULL) {
      qf_ptr = prev_qf_ptr;
      *qf_index = prev_index;
      if (err != NULL) {
        EMSG(_(err));
        return NULL;
      }
      break;
    }

    err = NULL;
  }

  return qf_ptr;
}

/// Get n'th (errornr) quickfix entry
static qfline_T *get_nth_entry(qf_info_T *qi, int errornr, qfline_T *qf_ptr,
                               int *cur_qfidx)
{
  int qf_idx = *cur_qfidx;

  // New error number is less than the current error number
  while (errornr < qf_idx && qf_idx > 1 && qf_ptr->qf_prev != NULL) {
    qf_idx--;
    qf_ptr = qf_ptr->qf_prev;
  }

  // New error number is greater than the current error number
  while (errornr > qf_idx
         && qf_idx < qi->qf_lists[qi->qf_curlist].qf_count
         && qf_ptr->qf_next != NULL) {
    qf_idx++;
    qf_ptr = qf_ptr->qf_next;
  }

  *cur_qfidx = qf_idx;
  return qf_ptr;
}

/// Find a help window or open one.
static int jump_to_help_window(qf_info_T *qi, int *opened_window)
{
  win_T *wp = NULL;

  if (cmdmod.tab != 0) {
    wp = NULL;
  } else {
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
    // Split off help window; put it at far top if no position
    // specified, the current window is vertically split and narrow.
    int flags = WSP_HELP;
    if (cmdmod.split == 0
        && curwin->w_width != Columns
        && curwin->w_width < 80) {
      flags |= WSP_TOP;
    }

    if (qi != &ql_info) {
      flags |= WSP_NEWLOC;  // don't copy the location list
    }

    if (win_split(0, flags) == FAIL) {
      return FAIL;
    }

    *opened_window = true;

    if (curwin->w_height < p_hh) {
      win_setheight((int)p_hh);
    }

    if (qi != &ql_info) {  // not a quickfix list
      // The new window should use the supplied location list
      curwin->w_llist = qi;
      qi->qf_refcount++;
    }
  }

  if (!p_im) {
    restart_edit = 0;  // don't want insert mode in help file
  }

  return OK;
}

/// Find a suitable window for opening a file (qf_fnum) and jump to it.
/// If the file is already opened in a window, jump to it.
static int qf_jump_to_usable_window(int qf_fnum, int *opened_window)
{
  win_T       *usable_win_ptr = NULL;
  int         usable_win;
  int         flags;
  win_T       *win = NULL;
  win_T       *altwin;

  usable_win = 0;

  qf_info_T *ll_ref = curwin->w_llist_ref;
  if (ll_ref != NULL) {
    // Find a window using the same location list that is not a
    // quickfix window.
    FOR_ALL_WINDOWS_IN_TAB(usable_win_ptr2, curtab) {
      if (usable_win_ptr2->w_llist == ll_ref
          && !bt_quickfix(usable_win_ptr2->w_buffer)) {
        usable_win_ptr = usable_win_ptr2;
        usable_win = 1;
        break;
      }
    }
  }

  if (!usable_win) {
    // Locate a window showing a normal buffer
    FOR_ALL_WINDOWS_IN_TAB(win2, curtab) {
      if (win2->w_buffer->b_p_bt[0] == NUL) {
        win = win2;
        usable_win = 1;
        break;
      }
    }
  }

  // If no usable window is found and 'switchbuf' contains "usetab"
  // then search in other tabs.
  if (!usable_win && (swb_flags & SWB_USETAB)) {
    FOR_ALL_TAB_WINDOWS(tp, wp) {
      if (wp->w_buffer->b_fnum == qf_fnum) {
        goto_tabpage_win(tp, wp);
        usable_win = 1;
        goto win_found;
      }
    }
  }
win_found:

  // If there is only one window and it is the quickfix window, create a
  // new one above the quickfix window.
  if ((ONE_WINDOW && bt_quickfix(curbuf)) || !usable_win) {
    flags = WSP_ABOVE;
    if (ll_ref != NULL) {
      flags |= WSP_NEWLOC;
    }
    if (win_split(0, flags) == FAIL) {
      return FAIL;  // not enough room for window
    }
    *opened_window = true;  // close it when fail
    p_swb = empty_option;   // don't split again
    swb_flags = 0;
    RESET_BINDING(curwin);
    if (ll_ref != NULL) {
      // The new window should use the location list from the
      // location list window
      curwin->w_llist = ll_ref;
      ll_ref->qf_refcount++;
    }
  } else {
    if (curwin->w_llist_ref != NULL) {
      // In a location window
      win = usable_win_ptr;
      if (win == NULL) {
        // Find the window showing the selected file
        FOR_ALL_WINDOWS_IN_TAB(win2, curtab) {
          if (win2->w_buffer->b_fnum == qf_fnum) {
            win = win2;
            break;
          }
        }
        if (win == NULL) {
          // Find a previous usable window
          win = curwin;
          do {
            if (win->w_buffer->b_p_bt[0] == NUL) {
              break;
            }
            if (win->w_prev == NULL) {
              win = lastwin;  // wrap around the top
            } else {
              win = win->w_prev;  // go to previous window
            }
          } while (win != curwin);
        }
      }
      win_goto(win);

      // If the location list for the window is not set, then set it
      // to the location list from the location window
      if (win->w_llist == NULL) {
        win->w_llist = ll_ref;
        ll_ref->qf_refcount++;
      }
    } else {
      // Try to find a window that shows the right buffer.
      // Default to the window just above the quickfix buffer.
      win = curwin;
      altwin = NULL;
      for (;;) {
        if (win->w_buffer->b_fnum == qf_fnum) {
          break;
        }
        if (win->w_prev == NULL) {
          win = lastwin;      // wrap around the top
        } else {
          win = win->w_prev;  // go to previous window
        }
        if (IS_QF_WINDOW(win)) {
          // Didn't find it, go to the window before the quickfix window.
          if (altwin != NULL) {
            win = altwin;
          } else if (curwin->w_prev != NULL) {
            win = curwin->w_prev;
          } else {
            win = curwin->w_next;
          }
          break;
        }

        // Remember a usable window.
        if (altwin == NULL && !win->w_p_pvw
            && win->w_buffer->b_p_bt[0] == NUL) {
          altwin = win;
        }
      }

      win_goto(win);
    }
  }

  return OK;
}

/// Edit the selected file or help file.
static int qf_jump_edit_buffer(qf_info_T *qi, qfline_T *qf_ptr, int forceit,
                               win_T *oldwin, int *opened_window, int *abort)
{
  int retval = OK;

  if (qf_ptr->qf_type == 1) {
    // Open help file (do_ecmd() will set b_help flag, readfile() will
    // set b_p_ro flag).
    if (!can_abandon(curbuf, forceit)) {
      EMSG(_(e_nowrtmsg));
      retval = false;
    } else {
      retval = do_ecmd(qf_ptr->qf_fnum, NULL, NULL, NULL, (linenr_T)1,
                       ECMD_HIDE + ECMD_SET_HELP,
                       oldwin == curwin ? curwin : NULL);
    }
  } else {
    int old_qf_curlist = qi->qf_curlist;

    retval = buflist_getfile(qf_ptr->qf_fnum, (linenr_T)1,
                             GETF_SETMARK | GETF_SWITCH, forceit);
    if (qi != &ql_info && !win_valid_any_tab(oldwin)) {
      EMSG(_("E924: Current window was closed"));
      *abort = true;
      *opened_window = false;
    } else if (old_qf_curlist != qi->qf_curlist
               || !is_qf_entry_present(qi, qf_ptr)) {
      if (qi == &ql_info) {
        EMSG(_("E925: Current quickfix was changed"));
      } else {
        EMSG(_("E926: Current location list was changed"));
      }
      *abort = true;
    }

    if (*abort) {
      retval = false;
    }
  }

  return retval;
}

/// Goto the error line in the current file using either line/column number or a
/// search pattern.
static void qf_jump_goto_line(linenr_T qf_lnum, int qf_col, char_u qf_viscol,
                              char_u *qf_pattern)
{
  linenr_T i;
  char_u *line;
  colnr_T screen_col;
  colnr_T char_col;

  if (qf_pattern == NULL) {
    // Go to line with error, unless qf_lnum is 0.
    i = qf_lnum;
    if (i > 0) {
      if (i > curbuf->b_ml.ml_line_count) {
        i = curbuf->b_ml.ml_line_count;
      }
      curwin->w_cursor.lnum = i;
    }
    if (qf_col > 0) {
      curwin->w_cursor.col = qf_col - 1;
      curwin->w_cursor.coladd = 0;
      if (qf_viscol == true) {
        // Check each character from the beginning of the error
        // line up to the error column.  For each tab character
        // found, reduce the error column value by the length of
        // a tab character.
        line = get_cursor_line_ptr();
        screen_col = 0;
        for (char_col = 0; char_col < curwin->w_cursor.col; char_col++) {
          if (*line == NUL) {
            break;
          }
          if (*line++ == '\t') {
            curwin->w_cursor.col -= 7 - (screen_col % 8);
            screen_col += 8 - (screen_col % 8);
          } else {
            screen_col++;
          }
        }
      }
      check_cursor();
    } else {
      beginline(BL_WHITE | BL_FIX);
    }
  } else {
    // Move the cursor to the first line in the buffer
    pos_T save_cursor = curwin->w_cursor;
    curwin->w_cursor.lnum = 0;
    if (!do_search(NULL, '/', qf_pattern, (long)1, SEARCH_KEEP, NULL, NULL)) {
      curwin->w_cursor = save_cursor;
    }
  }
}

/// Display quickfix list index and size message
static void qf_jump_print_msg(qf_info_T *qi, int qf_index, qfline_T *qf_ptr,
                              buf_T *old_curbuf, linenr_T old_lnum)
{
  // Update the screen before showing the message, unless the screen
  // scrolled up.
  if (!msg_scrolled) {
    update_topline_redraw();
  }
  snprintf((char *)IObuff, IOSIZE, _("(%d of %d)%s%s: "), qf_index,
           qi->qf_lists[qi->qf_curlist].qf_count,
           qf_ptr->qf_cleared ? _(" (line deleted)") : "",
           (char *)qf_types(qf_ptr->qf_type, qf_ptr->qf_nr));
  // Add the message, skipping leading whitespace and newlines.
  int len = (int)STRLEN(IObuff);
  qf_fmt_text(skipwhite(qf_ptr->qf_text), IObuff + len, IOSIZE - len);

  // Output the message.  Overwrite to avoid scrolling when the 'O'
  // flag is present in 'shortmess'; But when not jumping, print the
  // whole message.
  linenr_T i = msg_scroll;
  if (curbuf == old_curbuf && curwin->w_cursor.lnum == old_lnum) {
    msg_scroll = true;
  } else if (!msg_scrolled && shortmess(SHM_OVERALL)) {
    msg_scroll = false;
  }
  msg_attr_keep(IObuff, 0, true, false);
  msg_scroll = (int)i;
}

/// jump to a quickfix line
/// if dir == FORWARD go "errornr" valid entries forward
/// if dir == BACKWARD go "errornr" valid entries backward
/// if dir == FORWARD_FILE go "errornr" valid entries files backward
/// if dir == BACKWARD_FILE go "errornr" valid entries files backward
/// else if "errornr" is zero, redisplay the same line
/// else go to entry "errornr"
void qf_jump(qf_info_T *qi, int dir, int errornr, int forceit)
{
  qfline_T *qf_ptr;
  qfline_T *old_qf_ptr;
  int qf_index;
  int old_qf_index;
  buf_T *old_curbuf;
  linenr_T old_lnum;
  char_u *old_swb = p_swb;
  unsigned old_swb_flags = swb_flags;
  int opened_window = false;
  win_T *oldwin = curwin;
  int print_message = true;
  const bool old_KeyTyped = KeyTyped;           // getting file may reset it
  int retval = OK;

  if (qi == NULL)
    qi = &ql_info;

  if (qi->qf_curlist >= qi->qf_listcount
      || qi->qf_lists[qi->qf_curlist].qf_count == 0) {
    EMSG(_(e_quickfix));
    return;
  }

  qf_ptr = qi->qf_lists[qi->qf_curlist].qf_ptr;
  old_qf_ptr = qf_ptr;
  qf_index = qi->qf_lists[qi->qf_curlist].qf_index;
  old_qf_index = qf_index;
  if (dir != 0) {   // next/prev valid entry
    qf_ptr = get_nth_valid_entry(qi, errornr, qf_ptr, &qf_index, dir);
    if (qf_ptr == NULL) {
      qf_ptr = old_qf_ptr;
      qf_index = old_qf_index;
      goto theend;  // The horror... the horror...
    }
  } else if (errornr != 0) {  // go to specified number
    qf_ptr = get_nth_entry(qi, errornr, qf_ptr, &qf_index);
  }

  qi->qf_lists[qi->qf_curlist].qf_index = qf_index;
  if (qf_win_pos_update(qi, old_qf_index))
    /* No need to print the error message if it's visible in the error
     * window */
    print_message = FALSE;

  // For ":helpgrep" find a help window or open one.
  if (qf_ptr->qf_type == 1 && (!bt_help(curwin->w_buffer) || cmdmod.tab != 0)) {
    if (jump_to_help_window(qi, &opened_window) == FAIL) {
      goto theend;
    }
  }

  // If currently in the quickfix window, find another window to show the
  // file in.
  if (bt_quickfix(curbuf) && !opened_window) {
    // If there is no file specified, we don't know where to go.
    // But do advance, otherwise ":cn" gets stuck.
    if (qf_ptr->qf_fnum == 0) {
      goto theend;
    }
    if (qf_jump_to_usable_window(qf_ptr->qf_fnum, &opened_window) == FAIL) {
      goto failed;
    }
  }

  /*
   * If there is a file name,
   * read the wanted file if needed, and check autowrite etc.
   */
  old_curbuf = curbuf;
  old_lnum = curwin->w_cursor.lnum;

  if (qf_ptr->qf_fnum != 0) {
    int abort = false;
    retval = qf_jump_edit_buffer(qi, qf_ptr, forceit, oldwin, &opened_window,
                                 &abort);
    if (abort) {
      qi = NULL;
      qf_ptr = NULL;
    }
  }

  if (retval == OK) {
    // When not switched to another buffer, still need to set pc mark
    if (curbuf == old_curbuf) {
      setpcmark();
    }

    qf_jump_goto_line(qf_ptr->qf_lnum, qf_ptr->qf_col, qf_ptr->qf_viscol,
                      qf_ptr->qf_pattern);

    if ((fdo_flags & FDO_QUICKFIX) && old_KeyTyped)
      foldOpenCursor();
    if (print_message) {
      qf_jump_print_msg(qi, qf_index, qf_ptr, old_curbuf, old_lnum);
    }
  } else {
    if (opened_window) {
      win_close(curwin, true);          // Close opened window
    }
    if (qf_ptr != NULL && qf_ptr->qf_fnum != 0) {
       // Couldn't open file, so put index back where it was.  This could
       // happen if the file was readonly and we changed something.
failed:
      qf_ptr = old_qf_ptr;
      qf_index = old_qf_index;
    }
  }
theend:
  if (qi != NULL) {
    qi->qf_lists[qi->qf_curlist].qf_ptr = qf_ptr;
    qi->qf_lists[qi->qf_curlist].qf_index = qf_index;
  }
  if (p_swb != old_swb && opened_window) {
    /* Restore old 'switchbuf' value, but not when an autocommand or
     * modeline has changed the value. */
    if (p_swb == empty_option) {
      p_swb = old_swb;
      swb_flags = old_swb_flags;
    } else
      free_string_option(old_swb);
  }
}

/*
 * ":clist": list all errors
 * ":llist": list all locations
 */
void qf_list(exarg_T *eap)
{
  buf_T       *buf;
  char_u      *fname;
  qfline_T    *qfp;
  int i;
  int idx1 = 1;
  int idx2 = -1;
  char_u      *arg = eap->arg;
  int all = eap->forceit;               /* if not :cl!, only show
                                                   recognised errors */
  qf_info_T   *qi = &ql_info;

  if (eap->cmdidx == CMD_llist) {
    qi = GET_LOC_LIST(curwin);
    if (qi == NULL) {
      EMSG(_(e_loclist));
      return;
    }
  }

  if (qi->qf_curlist >= qi->qf_listcount
      || qi->qf_lists[qi->qf_curlist].qf_count == 0) {
    EMSG(_(e_quickfix));
    return;
  }

  bool plus = false;
  if (*arg == '+') {
    arg++;
    plus = true;
  }
  if (!get_list_range(&arg, &idx1, &idx2) || *arg != NUL) {
    EMSG(_(e_trailing));
    return;
  }
  if (plus) {
    i = qi->qf_lists[qi->qf_curlist].qf_index;
    idx2 = i + idx1;
    idx1 = i;
  } else {
    i = qi->qf_lists[qi->qf_curlist].qf_count;
    if (idx1 < 0) {
      idx1 = (-idx1 > i) ? 0 : idx1 + i + 1;
    }
    if (idx2 < 0) {
      idx2 = (-idx2 > i) ? 0 : idx2 + i + 1;
    }
  }

  // Shorten all the file names, so that it is easy to read.
  shorten_fnames(false);

  if (qi->qf_lists[qi->qf_curlist].qf_nonevalid) {
    all = true;
  }
  qfp = qi->qf_lists[qi->qf_curlist].qf_start;
  for (i = 1; !got_int && i <= qi->qf_lists[qi->qf_curlist].qf_count; ) {
    if ((qfp->qf_valid || all) && idx1 <= i && i <= idx2) {
      msg_putchar('\n');
      if (got_int)
        break;

      fname = NULL;
      if (qfp->qf_fnum != 0
          && (buf = buflist_findnr(qfp->qf_fnum)) != NULL) {
        fname = buf->b_fname;
        if (qfp->qf_type == 1)          /* :helpgrep */
          fname = path_tail(fname);
      }
      if (fname == NULL)
        sprintf((char *)IObuff, "%2d", i);
      else
        vim_snprintf((char *)IObuff, IOSIZE, "%2d %s",
            i, (char *)fname);
      msg_outtrans_attr(IObuff, i == qi->qf_lists[qi->qf_curlist].qf_index
                        ? HL_ATTR(HLF_QFL) : HL_ATTR(HLF_D));
      if (qfp->qf_lnum == 0) {
        IObuff[0] = NUL;
      } else if (qfp->qf_col == 0) {
        vim_snprintf((char *)IObuff, IOSIZE, ":%" PRIdLINENR, qfp->qf_lnum);
      } else {
        vim_snprintf((char *)IObuff, IOSIZE, ":%" PRIdLINENR " col %d",
                     qfp->qf_lnum, qfp->qf_col);
      }
      vim_snprintf((char *)IObuff + STRLEN(IObuff), IOSIZE, "%s:",
                   (char *)qf_types(qfp->qf_type, qfp->qf_nr));
      msg_puts_attr((const char *)IObuff, HL_ATTR(HLF_N));
      if (qfp->qf_pattern != NULL) {
        qf_fmt_text(qfp->qf_pattern, IObuff, IOSIZE);
        xstrlcat((char *)IObuff, ":", IOSIZE);
        msg_puts((const char *)IObuff);
      }
      msg_puts(" ");

      /* Remove newlines and leading whitespace from the text.  For an
       * unrecognized line keep the indent, the compiler may mark a word
       * with ^^^^. */
      qf_fmt_text((fname != NULL || qfp->qf_lnum != 0)
          ? skipwhite(qfp->qf_text) : qfp->qf_text,
          IObuff, IOSIZE);
      msg_prt_line(IObuff, FALSE);
      ui_flush();                      /* show one line at a time */
    }

    qfp = qfp->qf_next;
    if (qfp == NULL) {
      break;
    }
    i++;
    os_breakcheck();
  }
}

/*
 * Remove newlines and leading whitespace from an error message.
 * Put the result in "buf[bufsize]".
 */
static void qf_fmt_text(char_u *text, char_u *buf, int bufsize)
{
  int i;
  char_u      *p = text;

  for (i = 0; *p != NUL && i < bufsize - 1; ++i) {
    if (*p == '\n') {
      buf[i] = ' ';
      while (*++p != NUL)
        if (!ascii_iswhite(*p) && *p != '\n')
          break;
    } else
      buf[i] = *p++;
  }
  buf[i] = NUL;
}

static void qf_msg(qf_info_T *qi, int which, char *lead)
{
  char *title = (char *)qi->qf_lists[which].qf_title;
  int count = qi->qf_lists[which].qf_count;
  char_u buf[IOSIZE];

  vim_snprintf((char *)buf, IOSIZE, _("%serror list %d of %d; %d errors "),
               lead,
               which + 1,
               qi->qf_listcount,
               count);

  if (title != NULL) {
    size_t len = STRLEN(buf);

    if (len < 34) {
       memset(buf + len, ' ', 34 - len);
       buf[34] = NUL;
    }
    xstrlcat((char *)buf, title, IOSIZE);
  }
  trunc_string(buf, buf, (int)Columns - 1, IOSIZE);
  msg(buf);
}

/*
 * ":colder [count]": Up in the quickfix stack.
 * ":cnewer [count]": Down in the quickfix stack.
 * ":lolder [count]": Up in the location list stack.
 * ":lnewer [count]": Down in the location list stack.
 */
void qf_age(exarg_T *eap)
{
  qf_info_T   *qi = &ql_info;
  int count;

  if (eap->cmdidx == CMD_lolder || eap->cmdidx == CMD_lnewer) {
    qi = GET_LOC_LIST(curwin);
    if (qi == NULL) {
      EMSG(_(e_loclist));
      return;
    }
  }

  if (eap->addr_count != 0) {
    assert(eap->line2 <= INT_MAX);
    count = (int)eap->line2;
  } else {
    count = 1;
  }
  while (count--) {
    if (eap->cmdidx == CMD_colder || eap->cmdidx == CMD_lolder) {
      if (qi->qf_curlist == 0) {
        EMSG(_("E380: At bottom of quickfix stack"));
        break;
      }
      --qi->qf_curlist;
    } else {
      if (qi->qf_curlist >= qi->qf_listcount - 1) {
        EMSG(_("E381: At top of quickfix stack"));
        break;
      }
      ++qi->qf_curlist;
    }
  }
  qf_msg(qi, qi->qf_curlist, "");
  qf_update_buffer(qi, NULL);
}

void qf_history(exarg_T *eap)
{
  qf_info_T *qi = &ql_info;
  int i;

  if (eap->cmdidx == CMD_lhistory) {
    qi = GET_LOC_LIST(curwin);
  }
  if (qi == NULL || (qi->qf_listcount == 0
                     && qi->qf_lists[qi->qf_curlist].qf_count == 0)) {
    MSG(_("No entries"));
  } else {
    for (i = 0; i < qi->qf_listcount; i++) {
      qf_msg(qi, i, i == qi->qf_curlist ? "> " : "  ");
    }
  }
}

/// Free all the entries in the error list "idx". Note that other information
/// associated with the list like context and title are not freed.
static void qf_free_items(qf_info_T *qi, int idx)
{
  qfline_T    *qfp;
  qfline_T    *qfpnext;
  bool stop = false;
  qf_list_T *qfl = &qi->qf_lists[idx];

  while (qfl->qf_count && qfl->qf_start != NULL) {
    qfp = qfl->qf_start;
    qfpnext = qfp->qf_next;
    if (!stop) {
      xfree(qfp->qf_text);
      stop = (qfp == qfpnext);
      xfree(qfp->qf_pattern);
      xfree(qfp);
      if (stop) {
        // Somehow qf_count may have an incorrect value, set it to 1
        // to avoid crashing when it's wrong.
        // TODO(vim): Avoid qf_count being incorrect.
        qfl->qf_count = 1;
      }
    }
    qfl->qf_start = qfpnext;
    qfl->qf_count--;
  }

  qfl->qf_start = NULL;
  qfl->qf_ptr = NULL;
  qfl->qf_index = 0;
  qfl->qf_start = NULL;
  qfl->qf_last = NULL;
  qfl->qf_ptr = NULL;
  qfl->qf_nonevalid = true;

  qf_clean_dir_stack(&qfl->qf_dir_stack);
  qfl->qf_directory = NULL;
  qf_clean_dir_stack(&qfl->qf_file_stack);
  qfl->qf_currfile = NULL;
  qfl->qf_multiline = false;
  qfl->qf_multiignore = false;
  qfl->qf_multiscan = false;
}

/// Free error list "idx". Frees all the entries in the quickfix list,
/// associated context information and the title.
static void qf_free(qf_info_T *qi, int idx)
{
  qf_list_T *qfl = &qi->qf_lists[idx];
  qf_free_items(qi, idx);

  xfree(qfl->qf_title);
  qfl->qf_title = NULL;
  tv_free(qfl->qf_ctx);
  qfl->qf_ctx = NULL;
  qfl->qf_id = 0;
}

/*
 * qf_mark_adjust: adjust marks
 */
bool qf_mark_adjust(win_T *wp, linenr_T line1, linenr_T line2, long amount,
                    long amount_after)
{
  int i;
  qfline_T    *qfp;
  int idx;
  qf_info_T   *qi = &ql_info;
  bool found_one = false;
  int buf_has_flag = wp == NULL ? BUF_HAS_QF_ENTRY : BUF_HAS_LL_ENTRY;

  if (!(curbuf->b_has_qf_entry & buf_has_flag)) {
    return false;
  }
  if (wp != NULL) {
    if (wp->w_llist == NULL) {
      return false;
    }
    qi = wp->w_llist;
  }

  for (idx = 0; idx < qi->qf_listcount; ++idx)
    if (qi->qf_lists[idx].qf_count)
      for (i = 0, qfp = qi->qf_lists[idx].qf_start;
           i < qi->qf_lists[idx].qf_count && qfp != NULL;
           i++, qfp = qfp->qf_next) {
        if (qfp->qf_fnum == curbuf->b_fnum) {
          found_one = true;
          if (qfp->qf_lnum >= line1 && qfp->qf_lnum <= line2) {
            if (amount == MAXLNUM)
              qfp->qf_cleared = TRUE;
            else
              qfp->qf_lnum += amount;
          } else if (amount_after && qfp->qf_lnum > line2)
            qfp->qf_lnum += amount_after;
        }
      }

  return found_one;
}

/*
 * Make a nice message out of the error character and the error number:
 *  char    number	message
 *  e or E    0		" error"
 *  w or W    0		" warning"
 *  i or I    0		" info"
 *  0	      0		""
 *  other     0		" c"
 *  e or E    n		" error n"
 *  w or W    n		" warning n"
 *  i or I    n		" info n"
 *  0	      n		" error n"
 *  other     n		" c n"
 *  1	      x		""	:helpgrep
 */
static char_u *qf_types(int c, int nr)
{
  static char_u buf[20];
  static char_u cc[3];
  char_u              *p;

  if (c == 'W' || c == 'w')
    p = (char_u *)" warning";
  else if (c == 'I' || c == 'i')
    p = (char_u *)" info";
  else if (c == 'E' || c == 'e' || (c == 0 && nr > 0))
    p = (char_u *)" error";
  else if (c == 0 || c == 1)
    p = (char_u *)"";
  else {
    cc[0] = ' ';
    cc[1] = (char_u)c;
    cc[2] = NUL;
    p = cc;
  }

  if (nr <= 0)
    return p;

  sprintf((char *)buf, "%s %3d", (char *)p, nr);
  return buf;
}

/*
 * ":cwindow": open the quickfix window if we have errors to display,
 *	       close it if not.
 * ":lwindow": open the location list window if we have locations to display,
 *	       close it if not.
 */
void ex_cwindow(exarg_T *eap)
{
  qf_info_T   *qi = &ql_info;
  win_T       *win;

  if (eap->cmdidx == CMD_lwindow) {
    qi = GET_LOC_LIST(curwin);
    if (qi == NULL)
      return;
  }

  /* Look for an existing quickfix window.  */
  win = qf_find_win(qi);

  /*
   * If a quickfix window is open but we have no errors to display,
   * close the window.  If a quickfix window is not open, then open
   * it if we have errors; otherwise, leave it closed.
   */
  if (qi->qf_lists[qi->qf_curlist].qf_nonevalid
      || qi->qf_lists[qi->qf_curlist].qf_count == 0
      || qi->qf_curlist >= qi->qf_listcount) {
    if (win != NULL)
      ex_cclose(eap);
  } else if (win == NULL)
    ex_copen(eap);
}

/*
 * ":cclose": close the window showing the list of errors.
 * ":lclose": close the window showing the location list
 */
void ex_cclose(exarg_T *eap)
{
  win_T       *win = NULL;
  qf_info_T   *qi = &ql_info;

  if (eap->cmdidx == CMD_lclose || eap->cmdidx == CMD_lwindow) {
    qi = GET_LOC_LIST(curwin);
    if (qi == NULL)
      return;
  }

  /* Find existing quickfix window and close it. */
  win = qf_find_win(qi);
  if (win != NULL) {
    win_close(win, false);
  }
}

/*
 * ":copen": open a window that shows the list of errors.
 * ":lopen": open a window that shows the location list.
 */
void ex_copen(exarg_T *eap)
{
  qf_info_T   *qi = &ql_info;
  int height;
  win_T       *win;
  tabpage_T   *prevtab = curtab;
  buf_T       *qf_buf;
  win_T       *oldwin = curwin;

  if (eap->cmdidx == CMD_lopen || eap->cmdidx == CMD_lwindow) {
    qi = GET_LOC_LIST(curwin);
    if (qi == NULL) {
      EMSG(_(e_loclist));
      return;
    }
  }

  if (eap->addr_count != 0) {
    assert(eap->line2 <= INT_MAX);
    height = (int)eap->line2;
  } else {
    height = QF_WINHEIGHT;
  }
  reset_VIsual_and_resel();  // stop Visual mode

  /*
   * Find existing quickfix window, or open a new one.
   */
  win = qf_find_win(qi);

  if (win != NULL && cmdmod.tab == 0) {
    win_goto(win);
    if (eap->addr_count != 0) {
      if (cmdmod.split & WSP_VERT) {
        if (height != win->w_width) {
          win_setwidth(height);
        }
      } else {
        if (height != win->w_height) {
          win_setheight(height);
        }
      }
    }
  } else {
    int flags = 0;

    qf_buf = qf_find_buf(qi);

    /* The current window becomes the previous window afterwards. */
    win = curwin;

    if ((eap->cmdidx == CMD_copen || eap->cmdidx == CMD_cwindow)
        && cmdmod.split == 0)
      // Create the new quickfix window at the very bottom, except when
      // :belowright or :aboveleft is used.
      win_goto(lastwin);
    // Default is to open the window below the current window
    if (cmdmod.split == 0) {
      flags = WSP_BELOW;
    }
    flags |= WSP_NEWLOC;
    if (win_split(height, flags) == FAIL) {
      return;                   // not enough room for window
    }
    RESET_BINDING(curwin);

    if (eap->cmdidx == CMD_lopen || eap->cmdidx == CMD_lwindow) {
      /*
       * For the location list window, create a reference to the
       * location list from the window 'win'.
       */
      curwin->w_llist_ref = win->w_llist;
      win->w_llist->qf_refcount++;
    }

    if (oldwin != curwin)
      oldwin = NULL;        /* don't store info when in another window */
    if (qf_buf != NULL)
      /* Use the existing quickfix buffer */
      (void)do_ecmd(qf_buf->b_fnum, NULL, NULL, NULL, ECMD_ONE,
          ECMD_HIDE + ECMD_OLDBUF, oldwin);
    else {
      /* Create a new quickfix buffer */
      (void)do_ecmd(0, NULL, NULL, NULL, ECMD_ONE, ECMD_HIDE, oldwin);
      // Switch off 'swapfile'.
      set_option_value("swf", 0L, NULL, OPT_LOCAL);
      set_option_value("bt", 0L, "quickfix", OPT_LOCAL);
      set_option_value("bh", 0L, "wipe", OPT_LOCAL);
      RESET_BINDING(curwin);
      curwin->w_p_diff = false;
      set_option_value("fdm", 0L, "manual", OPT_LOCAL);
    }

    /* Only set the height when still in the same tab page and there is no
     * window to the side. */
    if (curtab == prevtab
        && curwin->w_width == Columns
        )
      win_setheight(height);
    curwin->w_p_wfh = TRUE;         /* set 'winfixheight' */
    if (win_valid(win))
      prevwin = win;
  }

  qf_set_title_var(qi);

  // Fill the buffer with the quickfix list.
  qf_fill_buffer(qi, curbuf, NULL);

  curwin->w_cursor.lnum = qi->qf_lists[qi->qf_curlist].qf_index;
  curwin->w_cursor.col = 0;
  check_cursor();
  update_topline();             /* scroll to show the line */
}

// Move the cursor in the quickfix window to "lnum".
static void qf_win_goto(win_T *win, linenr_T lnum)
{
  win_T *old_curwin = curwin;

  curwin = win;
  curbuf = win->w_buffer;
  curwin->w_cursor.lnum = lnum;
  curwin->w_cursor.col = 0;
  curwin->w_cursor.coladd = 0;
  curwin->w_curswant = 0;
  update_topline();              // scroll to show the line
  redraw_later(VALID);
  curwin->w_redr_status = true;  // update ruler
  curwin = old_curwin;
  curbuf = curwin->w_buffer;
}

// :cbottom/:lbottom command.
void ex_cbottom(exarg_T *eap)
{
  qf_info_T *qi = &ql_info;

  if (eap->cmdidx == CMD_lbottom) {
    qi = GET_LOC_LIST(curwin);
    if (qi == NULL) {
      EMSG(_(e_loclist));
      return;
    }
  }

  win_T *win = qf_find_win(qi);

  if (win != NULL && win->w_cursor.lnum != win->w_buffer->b_ml.ml_line_count) {
    qf_win_goto(win, win->w_buffer->b_ml.ml_line_count);
  }
}

/*
 * Return the number of the current entry (line number in the quickfix
 * window).
 */
linenr_T qf_current_entry(win_T *wp)
{
  qf_info_T   *qi = &ql_info;

  if (IS_LL_WINDOW(wp))
    /* In the location list window, use the referenced location list */
    qi = wp->w_llist_ref;

  return qi->qf_lists[qi->qf_curlist].qf_index;
}

/*
 * Update the cursor position in the quickfix window to the current error.
 * Return TRUE if there is a quickfix window.
 */
static int 
qf_win_pos_update (
    qf_info_T *qi,
    int old_qf_index               /* previous qf_index or zero */
)
{
  win_T       *win;
  int qf_index = qi->qf_lists[qi->qf_curlist].qf_index;

  /*
   * Put the cursor on the current error in the quickfix window, so that
   * it's viewable.
   */
  win = qf_find_win(qi);
  if (win != NULL
      && qf_index <= win->w_buffer->b_ml.ml_line_count
      && old_qf_index != qf_index) {
    if (qf_index > old_qf_index) {
      win->w_redraw_top = old_qf_index;
      win->w_redraw_bot = qf_index;
    } else {
      win->w_redraw_top = qf_index;
      win->w_redraw_bot = old_qf_index;
    }
    qf_win_goto(win, qf_index);
  }
  return win != NULL;
}

/*
 * Check whether the given window is displaying the specified quickfix/location
 * list buffer
 */
static int is_qf_win(win_T *win, qf_info_T *qi)
{
  /*
   * A window displaying the quickfix buffer will have the w_llist_ref field
   * set to NULL.
   * A window displaying a location list buffer will have the w_llist_ref
   * pointing to the location list.
   */
  if (bt_quickfix(win->w_buffer))
    if ((qi == &ql_info && win->w_llist_ref == NULL)
        || (qi != &ql_info && win->w_llist_ref == qi))
      return TRUE;

  return FALSE;
}

/*
 * Find a window displaying the quickfix/location list 'qi'
 * Searches in only the windows opened in the current tab.
 */
static win_T *qf_find_win(qf_info_T *qi)
{
  FOR_ALL_WINDOWS_IN_TAB(win, curtab) {
    if (is_qf_win(win, qi)) {
      return win;
    }
  }

  return NULL;
}

/*
 * Find a quickfix buffer.
 * Searches in windows opened in all the tabs.
 */
static buf_T *qf_find_buf(qf_info_T *qi)
{
  FOR_ALL_TAB_WINDOWS(tp, win) {
    if (is_qf_win(win, qi)) {
      return win->w_buffer;
    }
  }

  return NULL;
}

/// Update the w:quickfix_title variable in the quickfix/location list window
static void qf_update_win_titlevar(qf_info_T *qi)
{
  win_T *win;

  if ((win = qf_find_win(qi)) != NULL) {
    win_T *curwin_save = curwin;
    curwin = win;
    qf_set_title_var(qi);
    curwin = curwin_save;
  }
}

/*
 * Find the quickfix buffer.  If it exists, update the contents.
 */
static void qf_update_buffer(qf_info_T *qi, qfline_T *old_last)
{
  buf_T       *buf;
  win_T       *win;
  aco_save_T aco;

  /* Check if a buffer for the quickfix list exists.  Update it. */
  buf = qf_find_buf(qi);
  if (buf != NULL) {
    linenr_T old_line_count = buf->b_ml.ml_line_count;

    if (old_last == NULL) {
      // set curwin/curbuf to buf and save a few things
      aucmd_prepbuf(&aco, buf);
    }

    qf_update_win_titlevar(qi);

    qf_fill_buffer(qi, buf, old_last);
    buf_inc_changedtick(buf);

    if (old_last == NULL) {
      (void)qf_win_pos_update(qi, 0);

      // restore curwin/curbuf and a few other things
      aucmd_restbuf(&aco);
    }

    // Only redraw when added lines are visible.  This avoids flickering when
    // the added lines are not visible.
    if ((win = qf_find_win(qi)) != NULL && old_line_count < win->w_botline) {
      redraw_buf_later(buf, NOT_VALID);
    }
  }
}

// Set "w:quickfix_title" if "qi" has a title.
static void qf_set_title_var(qf_info_T *qi)
{
  if (qi->qf_lists[qi->qf_curlist].qf_title != NULL) {
      set_internal_string_var((char_u *)"w:quickfix_title",
                              qi->qf_lists[qi->qf_curlist].qf_title);
  }
}

// Fill current buffer with quickfix errors, replacing any previous contents.
// curbuf must be the quickfix buffer!
// If "old_last" is not NULL append the items after this one.
// When "old_last" is NULL then "buf" must equal "curbuf"!  Because ml_delete()
// is used and autocommands will be triggered.
static void qf_fill_buffer(qf_info_T *qi, buf_T *buf, qfline_T *old_last)
{
  linenr_T lnum;
  qfline_T    *qfp;
  buf_T       *errbuf;
  int len;
  const bool old_KeyTyped = KeyTyped;

  if (old_last == NULL) {
    if (buf != curbuf) {
      internal_error("qf_fill_buffer()");
      return;
    }

    // delete all existing lines
    while ((curbuf->b_ml.ml_flags & ML_EMPTY) == 0) {
      (void)ml_delete((linenr_T)1, false);
    }
  }

  /* Check if there is anything to display */
  if (qi->qf_curlist < qi->qf_listcount) {
     char_u dirname[MAXPATHL];

     *dirname = NUL;

    // Add one line for each error
    if (old_last == NULL) {
      qfp = qi->qf_lists[qi->qf_curlist].qf_start;
      lnum = 0;
    } else {
      qfp = old_last->qf_next;
      lnum = buf->b_ml.ml_line_count;
    }
    while (lnum < qi->qf_lists[qi->qf_curlist].qf_count) {
      if (qfp->qf_fnum != 0
          && (errbuf = buflist_findnr(qfp->qf_fnum)) != NULL
          && errbuf->b_fname != NULL) {
        if (qfp->qf_type == 1) {  // :helpgrep
          STRLCPY(IObuff, path_tail(errbuf->b_fname), sizeof(IObuff));
        } else {
          // shorten the file name if not done already
          if (errbuf->b_sfname == NULL
              || path_is_absolute(errbuf->b_sfname)) {
            if (*dirname == NUL) {
              os_dirname(dirname, MAXPATHL);
            }
            shorten_buf_fname(errbuf, dirname, false);
          }
          STRLCPY(IObuff, errbuf->b_fname, sizeof(IObuff));
        }
        len = (int)STRLEN(IObuff);
      } else {
        len = 0;
      }
      IObuff[len++] = '|';

      if (qfp->qf_lnum > 0) {
        sprintf((char *)IObuff + len, "%" PRId64, (int64_t)qfp->qf_lnum);
        len += (int)STRLEN(IObuff + len);

        if (qfp->qf_col > 0) {
          sprintf((char *)IObuff + len, " col %d", qfp->qf_col);
          len += (int)STRLEN(IObuff + len);
        }

        sprintf((char *)IObuff + len, "%s",
            (char *)qf_types(qfp->qf_type, qfp->qf_nr));
        len += (int)STRLEN(IObuff + len);
      } else if (qfp->qf_pattern != NULL) {
        qf_fmt_text(qfp->qf_pattern, IObuff + len, IOSIZE - len);
        len += (int)STRLEN(IObuff + len);
      }
      IObuff[len++] = '|';
      IObuff[len++] = ' ';

      /* Remove newlines and leading whitespace from the text.
       * For an unrecognized line keep the indent, the compiler may
       * mark a word with ^^^^. */
      qf_fmt_text(len > 3 ? skipwhite(qfp->qf_text) : qfp->qf_text,
          IObuff + len, IOSIZE - len);

      if (ml_append_buf(buf, lnum, IObuff, (colnr_T)STRLEN(IObuff) + 1, false)
          == FAIL) {
        break;
      }
      lnum++;
      qfp = qfp->qf_next;
      if (qfp == NULL) {
        break;
      }
    }
    if (old_last == NULL) {
      // Delete the empty line which is now at the end
      (void)ml_delete(lnum + 1, false);
    }
  }

  // Correct cursor position.
  check_lnums(true);

  if (old_last == NULL) {
    // Set the 'filetype' to "qf" each time after filling the buffer.  This
    // resembles reading a file into a buffer, it's more logical when using
    // autocommands.
    curbuf_lock++;
    set_option_value("ft", 0L, "qf", OPT_LOCAL);
    curbuf->b_p_ma = false;

    keep_filetype = true;                 // don't detect 'filetype'
    apply_autocmds(EVENT_BUFREADPOST, (char_u *)"quickfix", NULL,
                   false, curbuf);
    apply_autocmds(EVENT_BUFWINENTER, (char_u *)"quickfix", NULL,
                   false, curbuf);
    keep_filetype = false;
    curbuf_lock--;

    // make sure it will be redrawn
    redraw_curbuf_later(NOT_VALID);
  }

  /* Restore KeyTyped, setting 'filetype' may reset it. */
  KeyTyped = old_KeyTyped;
}

/*
 * Return TRUE when using ":vimgrep" for ":grep".
 */
int grep_internal(cmdidx_T cmdidx)
{
  return (cmdidx == CMD_grep
          || cmdidx == CMD_lgrep
          || cmdidx == CMD_grepadd
          || cmdidx == CMD_lgrepadd)
         && STRCMP("internal",
      *curbuf->b_p_gp == NUL ? p_gp : curbuf->b_p_gp) == 0;
}

/*
 * Used for ":make", ":lmake", ":grep", ":lgrep", ":grepadd", and ":lgrepadd"
 */
void ex_make(exarg_T *eap)
{
  char_u      *fname;
  win_T       *wp = NULL;
  qf_info_T   *qi = &ql_info;
  int res;
  char_u      *au_name = NULL;
  char_u *enc = (*curbuf->b_p_menc != NUL) ? curbuf->b_p_menc : p_menc;

  /* Redirect ":grep" to ":vimgrep" if 'grepprg' is "internal". */
  if (grep_internal(eap->cmdidx)) {
    ex_vimgrep(eap);
    return;
  }

  switch (eap->cmdidx) {
  case CMD_make:      au_name = (char_u *)"make"; break;
  case CMD_lmake:     au_name = (char_u *)"lmake"; break;
  case CMD_grep:      au_name = (char_u *)"grep"; break;
  case CMD_lgrep:     au_name = (char_u *)"lgrep"; break;
  case CMD_grepadd:   au_name = (char_u *)"grepadd"; break;
  case CMD_lgrepadd:  au_name = (char_u *)"lgrepadd"; break;
  default: break;
  }
  if (au_name != NULL && apply_autocmds(EVENT_QUICKFIXCMDPRE, au_name,
                                        curbuf->b_fname, true, curbuf)) {
    if (aborting()) {
      return;
    }
  }

  if (eap->cmdidx == CMD_lmake || eap->cmdidx == CMD_lgrep
      || eap->cmdidx == CMD_lgrepadd)
    wp = curwin;

  autowrite_all();
  fname = get_mef_name();
  if (fname == NULL)
    return;
  os_remove((char *)fname);  // in case it's not unique

  // If 'shellpipe' empty: don't redirect to 'errorfile'.
  const size_t len = (STRLEN(p_shq) * 2 + STRLEN(eap->arg) + 1
                      + (*p_sp == NUL
                         ? 0
                         : STRLEN(p_sp) + STRLEN(fname) + 3));
  char *const cmd = xmalloc(len);
  snprintf(cmd, len, "%s%s%s", (char *)p_shq, (char *)eap->arg,
           (char *)p_shq);
  if (*p_sp != NUL) {
    append_redir(cmd, len, (char *) p_sp, (char *) fname);
  }
  // Output a newline if there's something else than the :make command that
  // was typed (in which case the cursor is in column 0).
  if (msg_col == 0) {
    msg_didout = false;
  }
  msg_start();
  MSG_PUTS(":!");
  msg_outtrans((char_u *)cmd);  // show what we are doing

  do_shell((char_u *)cmd, 0);


  res = qf_init(wp, fname, (eap->cmdidx != CMD_make
                            && eap->cmdidx != CMD_lmake) ? p_gefm : p_efm,
                (eap->cmdidx != CMD_grepadd && eap->cmdidx != CMD_lgrepadd),
                *eap->cmdlinep, enc);
  if (wp != NULL) {
    qi = GET_LOC_LIST(wp);
  }
  if (au_name != NULL) {
    apply_autocmds(EVENT_QUICKFIXCMDPOST, au_name,
        curbuf->b_fname, TRUE, curbuf);
    if (qi->qf_curlist < qi->qf_listcount)
      res = qi->qf_lists[qi->qf_curlist].qf_count;
    else
      res = 0;
  }
  if (res > 0 && !eap->forceit)
    qf_jump(qi, 0, 0, FALSE);                   /* display first error */

  os_remove((char *)fname);
  xfree(fname);
  xfree(cmd);
}

/*
 * Return the name for the errorfile, in allocated memory.
 * Find a new unique name when 'makeef' contains "##".
 * Returns NULL for error.
 */
static char_u *get_mef_name(void)
{
  char_u      *p;
  char_u      *name;
  static int start = -1;
  static int off = 0;

  if (*p_mef == NUL) {
    name = vim_tempname();
    if (name == NULL)
      EMSG(_(e_notmp));
    return name;
  }

  for (p = p_mef; *p; ++p)
    if (p[0] == '#' && p[1] == '#')
      break;

  if (*p == NUL)
    return vim_strsave(p_mef);

  /* Keep trying until the name doesn't exist yet. */
  for (;; ) {
    if (start == -1) {
      start = (int)os_get_pid();
    } else {
      off += 19;
    }
    name = xmalloc(STRLEN(p_mef) + 30);
    STRCPY(name, p_mef);
    sprintf((char *)name + (p - p_mef), "%d%d", start, off);
    STRCAT(name, p + 2);
    // Don't accept a symbolic link, it's a security risk.
    FileInfo file_info;
    bool file_or_link_found = os_fileinfo_link((char *)name, &file_info);
    if (!file_or_link_found) {
      break;
    }
    xfree(name);
  }
  return name;
}

/// Returns the number of valid entries in the current quickfix/location list.
size_t qf_get_size(exarg_T *eap)
  FUNC_ATTR_NONNULL_ALL
{
  qf_info_T *qi = &ql_info;
  if (eap->cmdidx == CMD_ldo || eap->cmdidx == CMD_lfdo) {
    // Location list.
    qi = GET_LOC_LIST(curwin);
    if (qi == NULL) {
      return 0;
    }
  }

  int prev_fnum = 0;
  size_t sz = 0;
  qfline_T *qfp;
  size_t i;
  assert(qi->qf_lists[qi->qf_curlist].qf_count >= 0);
  for (i = 0, qfp = qi->qf_lists[qi->qf_curlist].qf_start;
       i < (size_t)qi->qf_lists[qi->qf_curlist].qf_count && qfp != NULL;
       i++, qfp = qfp->qf_next) {
    if (!qfp->qf_valid) {
      continue;
    }

    if (eap->cmdidx == CMD_cdo || eap->cmdidx == CMD_ldo) {
      // Count all valid entries.
      sz++;
    } else if (qfp->qf_fnum > 0 && qfp->qf_fnum != prev_fnum) {
      // Count the number of files.
      sz++;
      prev_fnum = qfp->qf_fnum;
    }
  }

  return sz;
}

/// Returns the current index of the quickfix/location list.
/// Returns 0 if there is an error.
size_t qf_get_cur_idx(exarg_T *eap)
  FUNC_ATTR_NONNULL_ALL
{
  qf_info_T *qi = &ql_info;

  if (eap->cmdidx == CMD_ldo || eap->cmdidx == CMD_lfdo) {
    // Location list.
    qi = GET_LOC_LIST(curwin);
    if (qi == NULL) {
      return 0;
    }
  }

  assert(qi->qf_lists[qi->qf_curlist].qf_index >= 0);
  return (size_t)qi->qf_lists[qi->qf_curlist].qf_index;
}

/// Returns the current index in the quickfix/location list,
/// counting only valid entries.
/// Returns 1 if there are no valid entries.
int qf_get_cur_valid_idx(exarg_T *eap)
  FUNC_ATTR_NONNULL_ALL
{
  qf_info_T *qi = &ql_info;

  if (eap->cmdidx == CMD_ldo || eap->cmdidx == CMD_lfdo) {
    // Location list.
    qi = GET_LOC_LIST(curwin);
    if (qi == NULL) {
      return 1;
    }
  }

  qf_list_T *qfl = &qi->qf_lists[qi->qf_curlist];

  // Check if the list has valid errors.
  if (qfl->qf_count <= 0 || qfl->qf_nonevalid) {
    return 1;
  }

  int prev_fnum = 0;
  int eidx = 0;
  qfline_T *qfp;
  size_t i;
  assert(qfl->qf_index >= 0);
  for (i = 1, qfp = qfl->qf_start;
       i <= (size_t)qfl->qf_index && qfp != NULL;
       i++, qfp = qfp->qf_next) {
    if (!qfp->qf_valid) {
      continue;
    }

    if (eap->cmdidx == CMD_cfdo || eap->cmdidx == CMD_lfdo) {
      if (qfp->qf_fnum > 0 && qfp->qf_fnum != prev_fnum) {
        // Count the number of files.
        eidx++;
        prev_fnum = qfp->qf_fnum;
      }
    } else {
      eidx++;
    }
  }

  return eidx != 0 ? eidx : 1;
}

/// Get the 'n'th valid error entry in the quickfix or location list.
///
/// Used by :cdo, :ldo, :cfdo and :lfdo commands.
/// For :cdo and :ldo, returns the 'n'th valid error entry.
/// For :cfdo and :lfdo, returns the 'n'th valid file entry.
static size_t qf_get_nth_valid_entry(qf_info_T *qi, size_t n, bool fdo)
  FUNC_ATTR_NONNULL_ALL
{
  qf_list_T *qfl = &qi->qf_lists[qi->qf_curlist];

  // Check if the list has valid errors.
  if (qfl->qf_count <= 0 || qfl->qf_nonevalid) {
    return 1;
  }

  int prev_fnum = 0;
  size_t eidx = 0;
  size_t i;
  qfline_T *qfp;
  assert(qfl->qf_count >= 0);
  for (i = 1, qfp = qfl->qf_start;
       i <= (size_t)qfl->qf_count && qfp != NULL;
       i++, qfp = qfp->qf_next) {
    if (qfp->qf_valid) {
      if (fdo) {
        if (qfp->qf_fnum > 0 && qfp->qf_fnum != prev_fnum) {
          // Count the number of files.
          eidx++;
          prev_fnum = qfp->qf_fnum;
        }
      } else {
        eidx++;
      }
    }

    if (eidx == n) {
      break;
    }
  }

  return i <= (size_t)qfl->qf_count ? i : 1;
}

/*
 * ":cc", ":crewind", ":cfirst" and ":clast".
 * ":ll", ":lrewind", ":lfirst" and ":llast".
 * ":cdo", ":ldo", ":cfdo" and ":lfdo".
 */
void ex_cc(exarg_T *eap)
{
  qf_info_T   *qi = &ql_info;

  if (eap->cmdidx == CMD_ll
      || eap->cmdidx == CMD_lrewind
      || eap->cmdidx == CMD_lfirst
      || eap->cmdidx == CMD_llast
      || eap->cmdidx == CMD_ldo
      || eap->cmdidx == CMD_lfdo) {
    qi = GET_LOC_LIST(curwin);
    if (qi == NULL) {
      EMSG(_(e_loclist));
      return;
    }
  }

  int errornr;
  if (eap->addr_count > 0) {
    errornr = (int)eap->line2;
  } else if (eap->cmdidx == CMD_cc || eap->cmdidx == CMD_ll) {
    errornr = 0;
  } else if (eap->cmdidx == CMD_crewind || eap->cmdidx == CMD_lrewind
           || eap->cmdidx == CMD_cfirst || eap->cmdidx == CMD_lfirst) {
    errornr = 1;
  } else {
    errornr = 32767;
  }

  // For cdo and ldo commands, jump to the nth valid error.
  // For cfdo and lfdo commands, jump to the nth valid file entry.
  if (eap->cmdidx == CMD_cdo || eap->cmdidx == CMD_ldo
      || eap->cmdidx == CMD_cfdo || eap->cmdidx == CMD_lfdo) {
    size_t n;
    if (eap->addr_count > 0) {
      assert(eap->line1 >= 0);
      n = (size_t)eap->line1;
    } else {
      n = 1;
    }
    size_t valid_entry = qf_get_nth_valid_entry(qi, n,
      eap->cmdidx == CMD_cfdo || eap->cmdidx == CMD_lfdo);
    assert(valid_entry <= INT_MAX);
    errornr = (int)valid_entry;
  }

  qf_jump(qi, 0, errornr, eap->forceit);
}

/*
 * ":cnext", ":cnfile", ":cNext" and ":cprevious".
 * ":lnext", ":lNext", ":lprevious", ":lnfile", ":lNfile" and ":lpfile".
 * ":cdo", ":ldo", ":cfdo" and ":lfdo".
 */
void ex_cnext(exarg_T *eap)
{
  qf_info_T   *qi = &ql_info;

  if (eap->cmdidx == CMD_lnext
      || eap->cmdidx == CMD_lNext
      || eap->cmdidx == CMD_lprevious
      || eap->cmdidx == CMD_lnfile
      || eap->cmdidx == CMD_lNfile
      || eap->cmdidx == CMD_lpfile
      || eap->cmdidx == CMD_ldo
      || eap->cmdidx == CMD_lfdo) {
    qi = GET_LOC_LIST(curwin);
    if (qi == NULL) {
      EMSG(_(e_loclist));
      return;
    }
  }

  int errornr;
  if (eap->addr_count > 0
      && (eap->cmdidx != CMD_cdo && eap->cmdidx != CMD_ldo
          && eap->cmdidx != CMD_cfdo && eap->cmdidx != CMD_lfdo)) {
    errornr = (int)eap->line2;
  } else {
    errornr = 1;
  }

  qf_jump(qi, (eap->cmdidx == CMD_cnext || eap->cmdidx == CMD_lnext
               || eap->cmdidx == CMD_cdo || eap->cmdidx == CMD_ldo)
      ? FORWARD
      : (eap->cmdidx == CMD_cnfile || eap->cmdidx == CMD_lnfile
        || eap->cmdidx == CMD_cfdo || eap->cmdidx == CMD_lfdo)
      ? FORWARD_FILE
      : (eap->cmdidx == CMD_cpfile || eap->cmdidx == CMD_lpfile
         || eap->cmdidx == CMD_cNfile || eap->cmdidx == CMD_lNfile)
      ? BACKWARD_FILE
      : BACKWARD,
      errornr, eap->forceit);
}

/*
 * ":cfile"/":cgetfile"/":caddfile" commands.
 * ":lfile"/":lgetfile"/":laddfile" commands.
 */
void ex_cfile(exarg_T *eap)
{
  win_T       *wp = NULL;
  qf_info_T   *qi = &ql_info;
  char_u      *au_name = NULL;

  if (eap->cmdidx == CMD_lfile || eap->cmdidx == CMD_lgetfile
      || eap->cmdidx == CMD_laddfile)
    wp = curwin;

  switch (eap->cmdidx) {
  case CMD_cfile:     au_name = (char_u *)"cfile"; break;
  case CMD_cgetfile:  au_name = (char_u *)"cgetfile"; break;
  case CMD_caddfile:  au_name = (char_u *)"caddfile"; break;
  case CMD_lfile:     au_name = (char_u *)"lfile"; break;
  case CMD_lgetfile:  au_name = (char_u *)"lgetfile"; break;
  case CMD_laddfile:  au_name = (char_u *)"laddfile"; break;
  default: break;
  }
  if (au_name != NULL)
    apply_autocmds(EVENT_QUICKFIXCMDPRE, au_name, NULL, FALSE, curbuf);
  if (*eap->arg != NUL)
    set_string_option_direct((char_u *)"ef", -1, eap->arg, OPT_FREE, 0);

  char_u *enc = (*curbuf->b_p_menc != NUL) ? curbuf->b_p_menc : p_menc;
  // This function is used by the :cfile, :cgetfile and :caddfile
  // commands.
  // :cfile always creates a new quickfix list and jumps to the
  // first error.
  // :cgetfile creates a new quickfix list but doesn't jump to the
  // first error.
  // :caddfile adds to an existing quickfix list. If there is no
  // quickfix list then a new list is created.
  if (qf_init(wp, p_ef, p_efm, (eap->cmdidx != CMD_caddfile
                                && eap->cmdidx != CMD_laddfile),
              *eap->cmdlinep, enc) > 0
      && (eap->cmdidx == CMD_cfile
          || eap->cmdidx == CMD_lfile)) {
    if (au_name != NULL)
      apply_autocmds(EVENT_QUICKFIXCMDPOST, au_name, NULL, FALSE, curbuf);
    if (wp != NULL)
      qi = GET_LOC_LIST(wp);
    qf_jump(qi, 0, 0, eap->forceit);            /* display first error */
  } else {
    if (au_name != NULL)
      apply_autocmds(EVENT_QUICKFIXCMDPOST, au_name, NULL, FALSE, curbuf);
  }
}

/*
 * ":vimgrep {pattern} file(s)"
 * ":vimgrepadd {pattern} file(s)"
 * ":lvimgrep {pattern} file(s)"
 * ":lvimgrepadd {pattern} file(s)"
 */
void ex_vimgrep(exarg_T *eap)
{
  regmmatch_T regmatch;
  int fcount;
  char_u      **fnames;
  char_u      *fname;
  char_u      *s;
  char_u      *p;
  int fi;
  qf_info_T   *qi = &ql_info;
  qfline_T    *cur_qf_start;
  long lnum;
  buf_T       *buf;
  int duplicate_name = FALSE;
  int using_dummy;
  int redraw_for_dummy = FALSE;
  int found_match;
  buf_T       *first_match_buf = NULL;
  time_t seconds = 0;
  long save_mls;
  char_u      *save_ei = NULL;
  aco_save_T aco;
  int flags = 0;
  colnr_T col;
  long tomatch;
  char_u      *dirname_start = NULL;
  char_u      *dirname_now = NULL;
  char_u      *target_dir = NULL;
  char_u      *au_name =  NULL;

  switch (eap->cmdidx) {
  case CMD_vimgrep:     au_name = (char_u *)"vimgrep"; break;
  case CMD_lvimgrep:    au_name = (char_u *)"lvimgrep"; break;
  case CMD_vimgrepadd:  au_name = (char_u *)"vimgrepadd"; break;
  case CMD_lvimgrepadd: au_name = (char_u *)"lvimgrepadd"; break;
  case CMD_grep:        au_name = (char_u *)"grep"; break;
  case CMD_lgrep:       au_name = (char_u *)"lgrep"; break;
  case CMD_grepadd:     au_name = (char_u *)"grepadd"; break;
  case CMD_lgrepadd:    au_name = (char_u *)"lgrepadd"; break;
  default: break;
  }
  if (au_name != NULL && apply_autocmds(EVENT_QUICKFIXCMDPRE, au_name,
                                        curbuf->b_fname, true, curbuf)) {
    if (aborting()) {
      return;
    }
  }

  if (eap->cmdidx == CMD_lgrep
      || eap->cmdidx == CMD_lvimgrep
      || eap->cmdidx == CMD_lgrepadd
      || eap->cmdidx == CMD_lvimgrepadd) {
    qi = ll_get_or_alloc_list(curwin);
  }

  if (eap->addr_count > 0)
    tomatch = eap->line2;
  else
    tomatch = MAXLNUM;

  /* Get the search pattern: either white-separated or enclosed in // */
  regmatch.regprog = NULL;
  char_u *title = vim_strsave(*eap->cmdlinep);
  p = skip_vimgrep_pat(eap->arg, &s, &flags);
  if (p == NULL) {
    EMSG(_(e_invalpat));
    goto theend;
  }

  if (s == NULL || *s == NUL) {
    // Pattern is empty, use last search pattern.
    if (last_search_pat() == NULL) {
      EMSG(_(e_noprevre));
      goto theend;
    }
    regmatch.regprog = vim_regcomp(last_search_pat(), RE_MAGIC);
  } else {
    regmatch.regprog = vim_regcomp(s, RE_MAGIC);
  }

  if (regmatch.regprog == NULL)
    goto theend;
  regmatch.rmm_ic = p_ic;
  regmatch.rmm_maxcol = 0;

  p = skipwhite(p);
  if (*p == NUL) {
    EMSG(_("E683: File name missing or invalid pattern"));
    goto theend;
  }

  if ((eap->cmdidx != CMD_grepadd && eap->cmdidx != CMD_lgrepadd
       && eap->cmdidx != CMD_vimgrepadd && eap->cmdidx != CMD_lvimgrepadd)
      || qi->qf_curlist == qi->qf_listcount) {
    // make place for a new list
    qf_new_list(qi, title);
  }

  /* parse the list of arguments */
  if (get_arglist_exp(p, &fcount, &fnames, true) == FAIL)
    goto theend;
  if (fcount == 0) {
    EMSG(_(e_nomatch));
    goto theend;
  }

  dirname_start = xmalloc(MAXPATHL);
  dirname_now = xmalloc(MAXPATHL);

  /* Remember the current directory, because a BufRead autocommand that does
   * ":lcd %:p:h" changes the meaning of short path names. */
  os_dirname(dirname_start, MAXPATHL);

  /* Remember the value of qf_start, so that we can check for autocommands
   * changing the current quickfix list. */
  cur_qf_start = qi->qf_lists[qi->qf_curlist].qf_start;

  seconds = (time_t)0;
  for (fi = 0; fi < fcount && !got_int && tomatch > 0; fi++) {
    fname = path_try_shorten_fname(fnames[fi]);
    if (time(NULL) > seconds) {
      /* Display the file name every second or so, show the user we are
       * working on it. */
      seconds = time(NULL);
      msg_start();
      p = msg_strtrunc(fname, TRUE);
      if (p == NULL)
        msg_outtrans(fname);
      else {
        msg_outtrans(p);
        xfree(p);
      }
      msg_clr_eos();
      msg_didout = FALSE;           /* overwrite this message */
      msg_nowait = TRUE;            /* don't wait for this message */
      msg_col = 0;
      ui_flush();
    }

    buf = buflist_findname_exp(fnames[fi]);
    if (buf == NULL || buf->b_ml.ml_mfp == NULL) {
      /* Remember that a buffer with this name already exists. */
      duplicate_name = (buf != NULL);
      using_dummy = TRUE;
      redraw_for_dummy = TRUE;

      /* Don't do Filetype autocommands to avoid loading syntax and
       * indent scripts, a great speed improvement. */
      save_ei = au_event_disable(",Filetype");
      /* Don't use modelines here, it's useless. */
      save_mls = p_mls;
      p_mls = 0;

      /* Load file into a buffer, so that 'fileencoding' is detected,
       * autocommands applied, etc. */
      buf = load_dummy_buffer(fname, dirname_start, dirname_now);

      p_mls = save_mls;
      au_event_restore(save_ei);
    } else
      /* Use existing, loaded buffer. */
      using_dummy = FALSE;

    if (cur_qf_start != qi->qf_lists[qi->qf_curlist].qf_start) {
      int idx;

      /* Autocommands changed the quickfix list.  Find the one we were
       * using and restore it. */
      for (idx = 0; idx < LISTCOUNT; ++idx)
        if (cur_qf_start == qi->qf_lists[idx].qf_start) {
          qi->qf_curlist = idx;
          break;
        }
      if (idx == LISTCOUNT) {
        /* List cannot be found, create a new one. */
        qf_new_list(qi, *eap->cmdlinep);
        cur_qf_start = qi->qf_lists[qi->qf_curlist].qf_start;
      }
    }

    if (buf == NULL) {
      if (!got_int)
        smsg(_("Cannot open file \"%s\""), fname);
    } else {
      /* Try for a match in all lines of the buffer.
       * For ":1vimgrep" look for first match only. */
      found_match = FALSE;
      for (lnum = 1; lnum <= buf->b_ml.ml_line_count && tomatch > 0;
           ++lnum) {
        col = 0;
        while (vim_regexec_multi(&regmatch, curwin, buf, lnum,
                                 col, NULL, NULL) > 0) {
          // Pass the buffer number so that it gets used even for a
          // dummy buffer, unless duplicate_name is set, then the
          // buffer will be wiped out below.
          if (qf_add_entry(qi,
                           qi->qf_curlist,
                           NULL,            // dir
                           fname,
                           duplicate_name ? 0 : buf->b_fnum,
                           ml_get_buf(buf,
                                      regmatch.startpos[0].lnum + lnum, false),
                           regmatch.startpos[0].lnum + lnum,
                           regmatch.startpos[0].col + 1,
                           false,           // vis_col
                           NULL,            // search pattern
                           0,               // nr
                           0,               // type
                           true)            // valid
              == FAIL) {
            got_int = true;
            break;
          }
          found_match = TRUE;
          if (--tomatch == 0)
            break;
          if ((flags & VGR_GLOBAL) == 0
              || regmatch.endpos[0].lnum > 0)
            break;
          col = regmatch.endpos[0].col
                + (col == regmatch.endpos[0].col);
          if (col > (colnr_T)STRLEN(ml_get_buf(buf, lnum, FALSE)))
            break;
        }
        line_breakcheck();
        if (got_int)
          break;
      }
      cur_qf_start = qi->qf_lists[qi->qf_curlist].qf_start;

      if (using_dummy) {
        if (found_match && first_match_buf == NULL)
          first_match_buf = buf;
        if (duplicate_name) {
          /* Never keep a dummy buffer if there is another buffer
           * with the same name. */
          wipe_dummy_buffer(buf, dirname_start);
          buf = NULL;
        } else if (!cmdmod.hide
                   || buf->b_p_bh[0] == 'u'             /* "unload" */
                   || buf->b_p_bh[0] == 'w'             /* "wipe" */
                   || buf->b_p_bh[0] == 'd') {          /* "delete" */
          /* When no match was found we don't need to remember the
           * buffer, wipe it out.  If there was a match and it
           * wasn't the first one or we won't jump there: only
           * unload the buffer.
           * Ignore 'hidden' here, because it may lead to having too
           * many swap files. */
          if (!found_match) {
            wipe_dummy_buffer(buf, dirname_start);
            buf = NULL;
          } else if (buf != first_match_buf || (flags & VGR_NOJUMP)) {
            unload_dummy_buffer(buf, dirname_start);
            // Keeping the buffer, remove the dummy flag.
            buf->b_flags &= ~BF_DUMMY;
            buf = NULL;
          }
        }

        if (buf != NULL) {
          // Keeping the buffer, remove the dummy flag.
          buf->b_flags &= ~BF_DUMMY;

          // If the buffer is still loaded we need to use the
          // directory we jumped to below.
          if (buf == first_match_buf
              && target_dir == NULL
              && STRCMP(dirname_start, dirname_now) != 0) {
            target_dir = vim_strsave(dirname_now);
          }

          /* The buffer is still loaded, the Filetype autocommands
           * need to be done now, in that buffer.  And the modelines
           * need to be done (again).  But not the window-local
           * options! */
          aucmd_prepbuf(&aco, buf);
          apply_autocmds(EVENT_FILETYPE, buf->b_p_ft,
              buf->b_fname, TRUE, buf);
          do_modelines(OPT_NOWIN);
          aucmd_restbuf(&aco);
        }
      }
    }
  }

  FreeWild(fcount, fnames);

  qi->qf_lists[qi->qf_curlist].qf_nonevalid = FALSE;
  qi->qf_lists[qi->qf_curlist].qf_ptr = qi->qf_lists[qi->qf_curlist].qf_start;
  qi->qf_lists[qi->qf_curlist].qf_index = 1;

  qf_update_buffer(qi, NULL);

  if (au_name != NULL)
    apply_autocmds(EVENT_QUICKFIXCMDPOST, au_name,
        curbuf->b_fname, TRUE, curbuf);

  /* Jump to first match. */
  if (qi->qf_lists[qi->qf_curlist].qf_count > 0) {
    if ((flags & VGR_NOJUMP) == 0) {
      buf = curbuf;
      qf_jump(qi, 0, 0, eap->forceit);
      if (buf != curbuf)
        /* If we jumped to another buffer redrawing will already be
         * taken care of. */
        redraw_for_dummy = FALSE;

      /* Jump to the directory used after loading the buffer. */
      if (curbuf == first_match_buf && target_dir != NULL) {
        exarg_T ea;

        ea.arg = target_dir;
        ea.cmdidx = CMD_lcd;
        ex_cd(&ea);
      }
    }
  } else
    EMSG2(_(e_nomatch2), s);

  /* If we loaded a dummy buffer into the current window, the autocommands
   * may have messed up things, need to redraw and recompute folds. */
  if (redraw_for_dummy) {
    foldUpdateAll(curwin);
  }

theend:
  xfree(title);
  xfree(dirname_now);
  xfree(dirname_start);
  xfree(target_dir);
  vim_regfree(regmatch.regprog);
}

/*
 * Restore current working directory to "dirname_start" if they differ, taking
 * into account whether it is set locally or globally.
 */
static void restore_start_dir(char_u *dirname_start)
{
  char_u *dirname_now = xmalloc(MAXPATHL);

  os_dirname(dirname_now, MAXPATHL);
  if (STRCMP(dirname_start, dirname_now) != 0) {
    /* If the directory has changed, change it back by building up an
     * appropriate ex command and executing it. */
    exarg_T ea;

    ea.arg = dirname_start;
    ea.cmdidx = (curwin->w_localdir == NULL) ? CMD_cd : CMD_lcd;
    ex_cd(&ea);
  }
  xfree(dirname_now);
}

/*
 * Load file "fname" into a dummy buffer and return the buffer pointer,
 * placing the directory resulting from the buffer load into the
 * "resulting_dir" pointer. "resulting_dir" must be allocated by the caller
 * prior to calling this function. Restores directory to "dirname_start" prior
 * to returning, if autocmds or the 'autochdir' option have changed it.
 *
 * If creating the dummy buffer does not fail, must call unload_dummy_buffer()
 * or wipe_dummy_buffer() later!
 *
 * Returns NULL if it fails.
 */
static buf_T *
load_dummy_buffer (
    char_u *fname,
    char_u *dirname_start,      /* in: old directory */
    char_u *resulting_dir      /* out: new directory */
)
{
  buf_T       *newbuf;
  bufref_T newbufref;
  bufref_T newbuf_to_wipe;
  int failed = true;
  aco_save_T aco;
  int readfile_result;

  // Allocate a buffer without putting it in the buffer list.
  newbuf = buflist_new(NULL, NULL, (linenr_T)1, BLN_DUMMY);
  if (newbuf == NULL) {
    return NULL;
  }
  set_bufref(&newbufref, newbuf);

  /* Init the options. */
  buf_copy_options(newbuf, BCO_ENTER | BCO_NOHELP);

  /* need to open the memfile before putting the buffer in a window */
  if (ml_open(newbuf) == OK) {
    // Make sure this buffer isn't wiped out by auto commands.
    newbuf->b_locked++;
    // set curwin/curbuf to buf and save a few things
    aucmd_prepbuf(&aco, newbuf);

    /* Need to set the filename for autocommands. */
    (void)setfname(curbuf, fname, NULL, FALSE);

    /* Create swap file now to avoid the ATTENTION message. */
    check_need_swap(TRUE);

    /* Remove the "dummy" flag, otherwise autocommands may not
     * work. */
    curbuf->b_flags &= ~BF_DUMMY;

    newbuf_to_wipe.br_buf = NULL;
    readfile_result = readfile(fname, NULL, (linenr_T)0, (linenr_T)0,
                               (linenr_T)MAXLNUM, NULL,
                               READ_NEW | READ_DUMMY);
    newbuf->b_locked--;
    if (readfile_result == OK
        && !got_int
        && !(curbuf->b_flags & BF_NEW)) {
      failed = FALSE;
      if (curbuf != newbuf) {
        // Bloody autocommands changed the buffer!  Can happen when
        // using netrw and editing a remote file.  Use the current
        // buffer instead, delete the dummy one after restoring the
        // window stuff.
        set_bufref(&newbuf_to_wipe, newbuf);
        newbuf = curbuf;
      }
    }

    // Restore curwin/curbuf and a few other things.
    aucmd_restbuf(&aco);
    if (newbuf_to_wipe.br_buf != NULL && bufref_valid(&newbuf_to_wipe)) {
      wipe_buffer(newbuf_to_wipe.br_buf, false);
    }

    // Add back the "dummy" flag, otherwise buflist_findname_file_id()
    // won't skip it.
    newbuf->b_flags |= BF_DUMMY;
  }

  /*
   * When autocommands/'autochdir' option changed directory: go back.
   * Let the caller know what the resulting dir was first, in case it is
   * important.
   */
  os_dirname(resulting_dir, MAXPATHL);
  restore_start_dir(dirname_start);

  if (!bufref_valid(&newbufref)) {
    return NULL;
  }
  if (failed) {
    wipe_dummy_buffer(newbuf, dirname_start);
    return NULL;
  }
  return newbuf;
}

/*
 * Wipe out the dummy buffer that load_dummy_buffer() created. Restores
 * directory to "dirname_start" prior to returning, if autocmds or the
 * 'autochdir' option have changed it.
 */
static void wipe_dummy_buffer(buf_T *buf, char_u *dirname_start)
{
  if (curbuf != buf) {          /* safety check */
    cleanup_T cs;

    /* Reset the error/interrupt/exception state here so that aborting()
     * returns FALSE when wiping out the buffer.  Otherwise it doesn't
     * work when got_int is set. */
    enter_cleanup(&cs);

    wipe_buffer(buf, FALSE);

    /* Restore the error/interrupt/exception state if not discarded by a
     * new aborting error, interrupt, or uncaught exception. */
    leave_cleanup(&cs);
    /* When autocommands/'autochdir' option changed directory: go back. */
    restore_start_dir(dirname_start);
  }
}

/*
 * Unload the dummy buffer that load_dummy_buffer() created. Restores
 * directory to "dirname_start" prior to returning, if autocmds or the
 * 'autochdir' option have changed it.
 */
static void unload_dummy_buffer(buf_T *buf, char_u *dirname_start)
{
  if (curbuf != buf) {          /* safety check */
    close_buffer(NULL, buf, DOBUF_UNLOAD, FALSE);

    /* When autocommands/'autochdir' option changed directory: go back. */
    restore_start_dir(dirname_start);
  }
}

/// Add each quickfix error to list "list" as a dictionary.
/// If qf_idx is -1, use the current list. Otherwise, use the specified list.
int get_errorlist(const qf_info_T *qi_arg, win_T *wp, int qf_idx, list_T *list)
{
  const qf_info_T *qi = qi_arg;
  char_u buf[2];
  qfline_T    *qfp;
  int i;
  int bufnum;

  if (qi == NULL) {
    qi = &ql_info;
    if (wp != NULL) {
      qi = GET_LOC_LIST(wp);
      if (qi == NULL) {
        return FAIL;
      }
    }
  }

  if (qf_idx == -1) {
    qf_idx = qi->qf_curlist;
  }

  if (qf_idx >= qi->qf_listcount
      || qi->qf_lists[qf_idx].qf_count == 0) {
    return FAIL;
  }

  qfp = qi->qf_lists[qf_idx].qf_start;
  for (i = 1; !got_int && i <= qi->qf_lists[qf_idx].qf_count; i++) {
    // Handle entries with a non-existing buffer number.
    bufnum = qfp->qf_fnum;
    if (bufnum != 0 && (buflist_findnr(bufnum) == NULL))
      bufnum = 0;

    dict_T *const dict = tv_dict_alloc();
    tv_list_append_dict(list, dict);

    buf[0] = qfp->qf_type;
    buf[1] = NUL;
    if (tv_dict_add_nr(dict, S_LEN("bufnr"), (varnumber_T)bufnum) == FAIL
        || (tv_dict_add_nr(dict, S_LEN("lnum"), (varnumber_T)qfp->qf_lnum)
            == FAIL)
        || (tv_dict_add_nr(dict, S_LEN("col"), (varnumber_T)qfp->qf_col)
            == FAIL)
        || (tv_dict_add_nr(dict, S_LEN("vcol"), (varnumber_T)qfp->qf_viscol)
            == FAIL)
        || (tv_dict_add_nr(dict, S_LEN("nr"), (varnumber_T)qfp->qf_nr) == FAIL)
        || tv_dict_add_str(dict, S_LEN("pattern"),
                           (qfp->qf_pattern == NULL
                            ? ""
                            : (const char *)qfp->qf_pattern)) == FAIL
        || tv_dict_add_str(dict, S_LEN("text"),
                           (qfp->qf_text == NULL
                            ? ""
                            : (const char *)qfp->qf_text)) == FAIL
        || tv_dict_add_str(dict, S_LEN("type"), (const char *)buf) == FAIL
        || (tv_dict_add_nr(dict, S_LEN("valid"), (varnumber_T)qfp->qf_valid)
            == FAIL)) {
      // tv_dict_add* fail only if key already exist, but this is a newly
      // allocated dictionary which is thus guaranteed to have no existing keys.
      assert(false);
    }

    qfp = qfp->qf_next;
    if (qfp == NULL) {
      break;
    }
  }
  return OK;
}

/// Flags used by getqflist()/getloclist() to determine which fields to return.
enum {
  QF_GETLIST_NONE = 0x0,
  QF_GETLIST_TITLE = 0x1,
  QF_GETLIST_ITEMS = 0x2,
  QF_GETLIST_NR = 0x4,
  QF_GETLIST_WINID = 0x8,
  QF_GETLIST_CONTEXT = 0x10,
  QF_GETLIST_ID = 0x20,
  QF_GETLIST_IDX = 0x40,
  QF_GETLIST_SIZE = 0x80,
  QF_GETLIST_ALL = 0xFF
};

// Parse text from 'di' and return the quickfix list items
static int qf_get_list_from_lines(dict_T *what, dictitem_T *di, dict_T *retdict)
{
  int status = FAIL;
  char_u *errorformat = p_efm;
  dictitem_T *efm_di;

  // Only a List value is supported
  if (di->di_tv.v_type == VAR_LIST && di->di_tv.vval.v_list != NULL) {
    // If errorformat is supplied then use it, otherwise use the 'efm'
    // option setting
    if ((efm_di = tv_dict_find(what, S_LEN("efm"))) != NULL) {
      if (efm_di->di_tv.v_type != VAR_STRING
          || efm_di->di_tv.vval.v_string == NULL) {
        return FAIL;
      }
      errorformat = efm_di->di_tv.vval.v_string;
    }

    list_T *l = tv_list_alloc(kListLenMayKnow);
    qf_info_T *qi = xmalloc(sizeof(*qi));
    memset(qi, 0, sizeof(*qi));
    qi->qf_refcount++;

    if (qf_init_ext(qi, 0, NULL, NULL, &di->di_tv, errorformat,
                    true, (linenr_T)0, (linenr_T)0, NULL, NULL) > 0) {
      (void)get_errorlist(qi, NULL, 0, l);
      qf_free(qi, 0);
    }
    xfree(qi);

    tv_dict_add_list(retdict, S_LEN("items"), l);
    status = OK;
  }

  return status;
}

// Return the quickfix/location list number with the given identifier.
// Returns -1 if list is not found.
static int qf_id2nr(const qf_info_T *const qi, const unsigned qfid)
{
  for (int qf_idx = 0; qf_idx < qi->qf_listcount; qf_idx++) {
    if (qi->qf_lists[qf_idx].qf_id == qfid) {
      return qf_idx;
    }
  }
  return -1;
}

/// Return quickfix/location list details (title) as a
/// dictionary. 'what' contains the details to return. If 'list_idx' is -1,
/// then current list is used. Otherwise the specified list is used.
int qf_get_properties(win_T *wp, dict_T *what, dict_T *retdict)
{
  qf_info_T *qi = &ql_info;
  dictitem_T *di;

  if ((di = tv_dict_find(what, S_LEN("lines"))) != NULL) {
    return qf_get_list_from_lines(what, di, retdict);
  }

  if (wp != NULL) {
    qi = GET_LOC_LIST(wp);
  }
  // List is not present or is empty
  if (qi == NULL || qi->qf_listcount == 0) {
    // If querying for the size of the list, return 0
    if (((di = tv_dict_find(what, S_LEN("nr"))) != NULL)
        && (di->di_tv.v_type == VAR_STRING)
        && (STRCMP(di->di_tv.vval.v_string, "$") == 0)) {
      return tv_dict_add_nr(retdict, S_LEN("nr"), 0);
    }
    return FAIL;
  }

  int status = OK;
  int flags = QF_GETLIST_NONE;

  int qf_idx = qi->qf_curlist;  // default is the current list
  if ((di = tv_dict_find(what, S_LEN("nr"))) != NULL) {
    // Use the specified quickfix/location list
    if (di->di_tv.v_type == VAR_NUMBER) {
      // for zero use the current list
      if (di->di_tv.vval.v_number != 0) {
        qf_idx = (int)di->di_tv.vval.v_number - 1;
        if (qf_idx < 0 || qf_idx >= qi->qf_listcount) {
          return FAIL;
        }
      }
    } else if (di->di_tv.v_type == VAR_STRING
               && strequal((const char *)di->di_tv.vval.v_string, "$")) {
      // Get the last quickfix list number
      qf_idx = qi->qf_listcount - 1;
    } else {
      return FAIL;
    }
    flags |= QF_GETLIST_NR;
  }

  if ((di = tv_dict_find(what, S_LEN("id"))) != NULL) {
    // Look for a list with the specified id
    if (di->di_tv.v_type == VAR_NUMBER) {
      // For zero, use the current list or the list specifed by 'nr'
      if (di->di_tv.vval.v_number != 0) {
        qf_idx = qf_id2nr(qi, (unsigned)di->di_tv.vval.v_number);
        if (qf_idx == -1) {
          return FAIL;      // List not found
        }
      }
      flags |= QF_GETLIST_ID;
    } else {
      return FAIL;
    }
  }

  if (tv_dict_find(what, S_LEN("all")) != NULL) {
    flags |= QF_GETLIST_ALL;
  }
  if (tv_dict_find(what, S_LEN("title")) != NULL) {
    flags |= QF_GETLIST_TITLE;
  }
  if (tv_dict_find(what, S_LEN("winid")) != NULL) {
    flags |= QF_GETLIST_WINID;
  }
  if (tv_dict_find(what, S_LEN("context")) != NULL) {
    flags |= QF_GETLIST_CONTEXT;
  }
  if (tv_dict_find(what, S_LEN("items")) != NULL) {
    flags |= QF_GETLIST_ITEMS;
  }
  if (tv_dict_find(what, S_LEN("idx")) != NULL) {
    flags |= QF_GETLIST_IDX;
  }
  if (tv_dict_find(what, S_LEN("size")) != NULL) {
    flags |= QF_GETLIST_SIZE;
  }


  if (flags & QF_GETLIST_TITLE) {
    char_u *t = qi->qf_lists[qf_idx].qf_title;
    if (t == NULL) {
      t = (char_u *)"";
    }
    status = tv_dict_add_str(retdict, S_LEN("title"), (const char *)t);
  }
  if ((status == OK) && (flags & QF_GETLIST_NR)) {
    status = tv_dict_add_nr(retdict, S_LEN("nr"), qf_idx + 1);
  }
  if ((status == OK) && (flags & QF_GETLIST_WINID)) {
    win_T *win = qf_find_win(qi);
    if (win != NULL) {
      status = tv_dict_add_nr(retdict, S_LEN("winid"), win->handle);
    }
  }
  if ((status == OK) && (flags & QF_GETLIST_ITEMS)) {
    list_T *l = tv_list_alloc(kListLenMayKnow);
    (void)get_errorlist(qi, NULL, qf_idx, l);
    tv_dict_add_list(retdict, S_LEN("items"), l);
  }

  if ((status == OK) && (flags & QF_GETLIST_CONTEXT)) {
    if (qi->qf_lists[qf_idx].qf_ctx != NULL) {
      di = tv_dict_item_alloc_len(S_LEN("context"));
      tv_copy(qi->qf_lists[qf_idx].qf_ctx, &di->di_tv);
      status = tv_dict_add(retdict, di);
      if (status == FAIL) {
        tv_dict_item_free(di);
      }
    } else {
      status = tv_dict_add_str(retdict, S_LEN("context"), "");
    }
  }

  if ((status == OK) && (flags & QF_GETLIST_ID)) {
    status = tv_dict_add_nr(retdict, S_LEN("id"), qi->qf_lists[qf_idx].qf_id);
  }

  if ((status == OK) && (flags & QF_GETLIST_IDX)) {
    int idx = qi->qf_lists[qf_idx].qf_index;
    if (qi->qf_lists[qf_idx].qf_count == 0) {
      // For empty lists, qf_index is set to 1
      idx = 0;
    }
    status = tv_dict_add_nr(retdict, S_LEN("idx"), idx);
  }

  if ((status == OK) && (flags & QF_GETLIST_SIZE)) {
    status = tv_dict_add_nr(retdict, S_LEN("size"),
                            qi->qf_lists[qf_idx].qf_count);
  }

  return status;
}

/// Add list of entries to quickfix/location list. Each list entry is
/// a dictionary with item information.
static int qf_add_entries(qf_info_T *qi, int qf_idx, list_T *list,
                          char_u *title, int action)
{
  dict_T *d;
  qfline_T *old_last = NULL;
  int retval = OK;
  bool did_bufnr_emsg = false;

  if (action == ' ' || qf_idx == qi->qf_listcount) {
    // make place for a new list
    qf_new_list(qi, title);
    qf_idx = qi->qf_curlist;
  } else if (action == 'a' && qi->qf_lists[qf_idx].qf_count > 0) {
    // Adding to existing list, use last entry.
    old_last = qi->qf_lists[qf_idx].qf_last;
  } else if (action == 'r') {
    qf_free_items(qi, qf_idx);
    qf_store_title(qi, qf_idx, title);
  }

  TV_LIST_ITER_CONST(list, li, {
    if (TV_LIST_ITEM_TV(li)->v_type != VAR_DICT) {
      continue;  // Skip non-dict items.
    }

    d = TV_LIST_ITEM_TV(li)->vval.v_dict;
    if (d == NULL) {
      continue;
    }

    char *const filename = tv_dict_get_string(d, "filename", true);
    int bufnum = (int)tv_dict_get_number(d, "bufnr");
    long lnum = (long)tv_dict_get_number(d, "lnum");
    int col = (int)tv_dict_get_number(d, "col");
    char_u vcol = (char_u)tv_dict_get_number(d, "vcol");
    int nr = (int)tv_dict_get_number(d, "nr");
    const char *type_str = tv_dict_get_string(d, "type", false);
    const char_u type = (char_u)(uint8_t)(type_str == NULL ? NUL : *type_str);
    char *const pattern = tv_dict_get_string(d, "pattern", true);
    char *text = tv_dict_get_string(d, "text", true);
    if (text == NULL) {
      text = xcalloc(1, 1);
    }
    bool valid = true;
    if ((filename == NULL && bufnum == 0) || (lnum == 0 && pattern == NULL)) {
      valid = false;
    }

    /* Mark entries with non-existing buffer number as not valid. Give the
     * error message only once. */
    if (bufnum != 0 && (buflist_findnr(bufnum) == NULL)) {
      if (!did_bufnr_emsg) {
        did_bufnr_emsg = TRUE;
        EMSGN(_("E92: Buffer %" PRId64 " not found"), bufnum);
      }
      valid = false;
      bufnum = 0;
    }

    // If the 'valid' field is present it overrules the detected value.
    if (tv_dict_find(d, "valid", -1) != NULL) {
      valid = (int)tv_dict_get_number(d, "valid");
    }

    int status = qf_add_entry(qi,
                              qf_idx,
                              NULL,      // dir
                              (char_u *)filename,
                              bufnum,
                              (char_u *)text,
                              lnum,
                              col,
                              vcol,      // vis_col
                              (char_u *)pattern,   // search pattern
                              nr,
                              type,
                              valid);

    xfree(filename);
    xfree(pattern);
    xfree(text);

    if (status == FAIL) {
      retval = FAIL;
      break;
    }
  });

  if (qi->qf_lists[qf_idx].qf_index == 0) {
    // no valid entry
    qi->qf_lists[qf_idx].qf_nonevalid = true;
  } else {
    qi->qf_lists[qf_idx].qf_nonevalid = false;
  }
  if (action != 'a') {
    qi->qf_lists[qf_idx].qf_ptr = qi->qf_lists[qf_idx].qf_start;
    if (qi->qf_lists[qf_idx].qf_count > 0) {
      qi->qf_lists[qf_idx].qf_index = 1;
    }
  }

  // Don't update the cursor in quickfix window when appending entries
  qf_update_buffer(qi, old_last);

  return retval;
}

static int qf_set_properties(qf_info_T *qi, dict_T *what, int action,
                             char_u *title)
{
  dictitem_T *di;
  int retval = FAIL;
  int newlist = false;
  char_u *errorformat = p_efm;

  if (action == ' ' || qi->qf_curlist == qi->qf_listcount) {
    newlist = true;
  }
  int qf_idx = qi->qf_curlist;  // default is the current list
  if ((di = tv_dict_find(what, S_LEN("nr"))) != NULL) {
    // Use the specified quickfix/location list
    if (di->di_tv.v_type == VAR_NUMBER) {
      // for zero use the current list
      if (di->di_tv.vval.v_number != 0) {
        qf_idx = (int)di->di_tv.vval.v_number - 1;
      }

      if ((action == ' ' || action == 'a') && qf_idx == qi->qf_listcount) {
        // When creating a new list, accept qf_idx pointing to the next
        // non-available list and add the new list at the end of the
        // stack.
        newlist = true;
        qf_idx = qi->qf_listcount - 1;
      } else if (qf_idx < 0 || qf_idx >= qi->qf_listcount) {
        return FAIL;
      } else if (action != ' ') {
        newlist = false;  // use the specified list
      }
    } else if (di->di_tv.v_type == VAR_STRING
               && strequal((const char *)di->di_tv.vval.v_string, "$")) {
      if (qi->qf_listcount > 0) {
        qf_idx = qi->qf_listcount - 1;
      } else if (newlist) {
        qf_idx = 0;
      } else {
        return FAIL;
      }
    } else {
      return FAIL;
    }
  }

  if (!newlist && (di = tv_dict_find(what, S_LEN("id"))) != NULL) {
    // Use the quickfix/location list with the specified id
    if (di->di_tv.v_type == VAR_NUMBER) {
      qf_idx = qf_id2nr(qi, (unsigned)di->di_tv.vval.v_number);
      if (qf_idx == -1) {
        return FAIL;      // List not found
      }
    } else {
      return FAIL;
    }
  }

  if (newlist) {
    qi->qf_curlist = qf_idx;
    qf_new_list(qi, title);
    qf_idx = qi->qf_curlist;
  }

  if ((di = tv_dict_find(what, S_LEN("title"))) != NULL) {
    if (di->di_tv.v_type == VAR_STRING) {
      xfree(qi->qf_lists[qf_idx].qf_title);
      qi->qf_lists[qf_idx].qf_title = (char_u *)tv_dict_get_string(
          what, "title", true);
      if (qf_idx == qi->qf_curlist) {
        qf_update_win_titlevar(qi);
      }
      retval = OK;
    }
  }
  if ((di = tv_dict_find(what, S_LEN("items"))) != NULL) {
    if (di->di_tv.v_type == VAR_LIST) {
      assert(qi->qf_lists[qf_idx].qf_title != NULL);
      char_u *title_save = vim_strsave(qi->qf_lists[qf_idx].qf_title);

      retval = qf_add_entries(qi, qf_idx, di->di_tv.vval.v_list,
                              title_save, action == ' ' ? 'a' : action);
      if (action == 'r') {
        // When replacing the quickfix list entries using
        // qf_add_entries(), the title is set with a ':' prefix.
        // Restore the title with the saved title.
        xfree(qi->qf_lists[qf_idx].qf_title);
        qi->qf_lists[qf_idx].qf_title = vim_strsave(title_save);
      }
      xfree(title_save);
    }
  }

  if ((di = tv_dict_find(what, S_LEN("efm"))) != NULL) {
    if (di->di_tv.v_type != VAR_STRING || di->di_tv.vval.v_string == NULL) {
      return FAIL;
    }
    errorformat = di->di_tv.vval.v_string;
  }

  if ((di = tv_dict_find(what, S_LEN("lines"))) != NULL) {
    // Only a List value is supported
    if (di->di_tv.v_type == VAR_LIST && di->di_tv.vval.v_list != NULL) {
      if (action == 'r') {
        qf_free_items(qi, qf_idx);
      }
      if (qf_init_ext(qi, qf_idx, NULL, NULL, &di->di_tv, errorformat,
                      false, (linenr_T)0, (linenr_T)0, NULL, NULL) > 0) {
        retval = OK;
      }
    } else {
      return FAIL;
    }
  }

  if ((di = tv_dict_find(what, S_LEN("context"))) != NULL) {
    tv_free(qi->qf_lists[qf_idx].qf_ctx);

    typval_T *ctx = xcalloc(1, sizeof(typval_T));
    tv_copy(&di->di_tv, ctx);
    qi->qf_lists[qf_idx].qf_ctx = ctx;
    retval = OK;
  }

  return retval;
}

// Find the non-location list window with the specified location list.
static win_T * find_win_with_ll(qf_info_T *qi)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if ((wp->w_llist == qi) && !bt_quickfix(wp->w_buffer)) {
      return wp;
    }
  }

  return NULL;
}

// Free the entire quickfix/location list stack.
// If the quickfix/location list window is open, then clear it.
static void qf_free_stack(win_T *wp, qf_info_T *qi)
{
  win_T *qfwin = qf_find_win(qi);

  if (qfwin != NULL) {
    // If the quickfix/location list window is open, then clear it
    if (qi->qf_curlist < qi->qf_listcount) {
      qf_free(qi, qi->qf_curlist);
    }
    qf_update_buffer(qi, NULL);
  }

  win_T *llwin = NULL;
  win_T *orig_wp = wp;
  if (wp != NULL && IS_LL_WINDOW(wp)) {
    // If in the location list window, then use the non-location list
    // window with this location list (if present)
    llwin = find_win_with_ll(qi);
    if (llwin != NULL) {
      wp = llwin;
    }
  }

  qf_free_all(wp);
  if (wp == NULL) {
    // quickfix list
    qi->qf_curlist = 0;
    qi->qf_listcount = 0;
  } else if (IS_LL_WINDOW(orig_wp)) {
    // If the location list window is open, then create a new empty location
    // list
    qf_info_T *new_ll = ll_new_list();

    // first free the list reference in the location list window
    ll_free_all(&orig_wp->w_llist_ref);

    orig_wp->w_llist_ref = new_ll;
    if (llwin != NULL) {
      llwin->w_llist = new_ll;
      new_ll->qf_refcount++;
    }
  }
}

// Populate the quickfix list with the items supplied in the list
// of dictionaries. "title" will be copied to w:quickfix_title
// "action" is 'a' for add, 'r' for replace.  Otherwise create a new list.
int set_errorlist(win_T *wp, list_T *list, int action, char_u *title,
                  dict_T *what)
{
  qf_info_T *qi = &ql_info;
  int retval = OK;

  if (wp != NULL) {
    qi = ll_get_or_alloc_list(wp);
  }

  if (action == 'f') {
    // Free the entire quickfix or location list stack
    qf_free_stack(wp, qi);
  } else if (what != NULL) {
    retval = qf_set_properties(qi, what, action, title);
  } else {
    retval = qf_add_entries(qi, qi->qf_curlist, list, title, action);
  }

  return retval;
}

static bool mark_quickfix_ctx(qf_info_T *qi, int copyID)
{
  bool abort = false;

  for (int i = 0; i < LISTCOUNT && !abort; i++) {
    typval_T *ctx = qi->qf_lists[i].qf_ctx;
    if (ctx != NULL && ctx->v_type != VAR_NUMBER
        && ctx->v_type != VAR_STRING && ctx->v_type != VAR_FLOAT) {
      abort = set_ref_in_item(ctx, copyID, NULL, NULL);
    }
  }

  return abort;
}

/// Mark the context of the quickfix list and the location lists (if present) as
/// "in use". So that garabage collection doesn't free the context.
bool set_ref_in_quickfix(int copyID)
{
  bool abort = mark_quickfix_ctx(&ql_info, copyID);
  if (abort) {
    return abort;
  }

  FOR_ALL_TAB_WINDOWS(tp, win) {
    if (win->w_llist != NULL) {
      abort = mark_quickfix_ctx(win->w_llist, copyID);
      if (abort) {
        return abort;
      }
    }
  }

  return abort;
}

/*
 * ":[range]cbuffer [bufnr]" command.
 * ":[range]caddbuffer [bufnr]" command.
 * ":[range]cgetbuffer [bufnr]" command.
 * ":[range]lbuffer [bufnr]" command.
 * ":[range]laddbuffer [bufnr]" command.
 * ":[range]lgetbuffer [bufnr]" command.
 */
void ex_cbuffer(exarg_T *eap)
{
  buf_T *buf = NULL;
  qf_info_T *qi = &ql_info;
  const char *au_name = NULL;

  switch (eap->cmdidx) {
    case CMD_cbuffer:
      au_name = "cbuffer";
      break;
    case CMD_cgetbuffer:
      au_name = "cgetbuffer";
      break;
    case CMD_caddbuffer:
      au_name = "caddbuffer";
      break;
    case CMD_lbuffer:
      au_name = "lbuffer";
      break;
    case CMD_lgetbuffer:
      au_name = "lgetbuffer";
      break;
    case CMD_laddbuffer:
      au_name = "laddbuffer";
      break;
    default:
      break;
  }

  if (au_name != NULL && apply_autocmds(EVENT_QUICKFIXCMDPRE, (char_u *)au_name,
                                        curbuf->b_fname, true, curbuf)) {
    if (aborting()) {
      return;
    }
  }

  // Must come after autocommands.
  if (eap->cmdidx == CMD_lbuffer
      || eap->cmdidx == CMD_lgetbuffer
      || eap->cmdidx == CMD_laddbuffer) {
    qi = ll_get_or_alloc_list(curwin);
  }

  if (*eap->arg == NUL)
    buf = curbuf;
  else if (*skipwhite(skipdigits(eap->arg)) == NUL)
    buf = buflist_findnr(atoi((char *)eap->arg));
  if (buf == NULL)
    EMSG(_(e_invarg));
  else if (buf->b_ml.ml_mfp == NULL)
    EMSG(_("E681: Buffer is not loaded"));
  else {
    if (eap->addr_count == 0) {
      eap->line1 = 1;
      eap->line2 = buf->b_ml.ml_line_count;
    }
    if (eap->line1 < 1 || eap->line1 > buf->b_ml.ml_line_count
        || eap->line2 < 1 || eap->line2 > buf->b_ml.ml_line_count)
      EMSG(_(e_invrange));
    else {
      char_u *qf_title = *eap->cmdlinep;

      if (buf->b_sfname) {
        vim_snprintf((char *)IObuff, IOSIZE, "%s (%s)",
            (char *)qf_title, (char *)buf->b_sfname);
        qf_title = IObuff;
      }

      if (qf_init_ext(qi, qi->qf_curlist, NULL, buf, NULL, p_efm,
                      (eap->cmdidx != CMD_caddbuffer
                       && eap->cmdidx != CMD_laddbuffer),
                      eap->line1, eap->line2, qf_title, NULL) > 0) {
        if (au_name != NULL) {
          apply_autocmds(EVENT_QUICKFIXCMDPOST, (char_u *)au_name,
                         curbuf->b_fname, true, curbuf);
        }
        if (eap->cmdidx == CMD_cbuffer || eap->cmdidx == CMD_lbuffer) {
          qf_jump(qi, 0, 0, eap->forceit);  // display first error
        }
      }
    }
  }
}

/*
 * ":cexpr {expr}", ":cgetexpr {expr}", ":caddexpr {expr}" command.
 * ":lexpr {expr}", ":lgetexpr {expr}", ":laddexpr {expr}" command.
 */
void ex_cexpr(exarg_T *eap)
{
  qf_info_T *qi = &ql_info;
  const char *au_name = NULL;

  if (eap->cmdidx == CMD_lexpr || eap->cmdidx == CMD_lgetexpr
      || eap->cmdidx == CMD_laddexpr) {
    qi = ll_get_or_alloc_list(curwin);
  }

  switch (eap->cmdidx) {
    case CMD_cexpr:
      au_name = "cexpr";
      break;
    case CMD_cgetexpr:
      au_name = "cgetexpr";
      break;
    case CMD_caddexpr:
      au_name = "caddexpr";
      break;
    case CMD_lexpr:
      au_name = "lexpr";
      break;
    case CMD_lgetexpr:
      au_name = "lgetexpr";
      break;
    case CMD_laddexpr:
      au_name = "laddexpr";
      break;
    default:
      break;
  }
  if (au_name != NULL && apply_autocmds(EVENT_QUICKFIXCMDPRE, (char_u *)au_name,
                                        curbuf->b_fname, true, curbuf)) {
    if (aborting()) {
      return;
    }
  }

  /* Evaluate the expression.  When the result is a string or a list we can
   * use it to fill the errorlist. */
  typval_T tv;
  if (eval0(eap->arg, &tv, NULL, true) != FAIL) {
    if ((tv.v_type == VAR_STRING && tv.vval.v_string != NULL)
        || tv.v_type == VAR_LIST) {
      if (qf_init_ext(qi, qi->qf_curlist, NULL, NULL, &tv, p_efm,
                      (eap->cmdidx != CMD_caddexpr
                       && eap->cmdidx != CMD_laddexpr),
                      (linenr_T)0, (linenr_T)0, *eap->cmdlinep, NULL) > 0) {
        if (au_name != NULL) {
          apply_autocmds(EVENT_QUICKFIXCMDPOST, (char_u *)au_name,
                         curbuf->b_fname, true, curbuf);
        }
        if (eap->cmdidx == CMD_cexpr || eap->cmdidx == CMD_lexpr) {
          qf_jump(qi, 0, 0, eap->forceit);  // display first error
        }
      }
    } else {
      EMSG(_("E777: String or List expected"));
    }
    tv_clear(&tv);
  }
}

/*
 * ":helpgrep {pattern}"
 */
void ex_helpgrep(exarg_T *eap)
{
  regmatch_T regmatch;
  char_u      *save_cpo;
  char_u      *p;
  int fcount;
  char_u      **fnames;
  FILE        *fd;
  int fi;
  long lnum;
  char_u      *lang;
  qf_info_T   *qi = &ql_info;
  int new_qi = FALSE;
  char_u      *au_name =  NULL;

  /* Check for a specified language */
  lang = check_help_lang(eap->arg);

  switch (eap->cmdidx) {
  case CMD_helpgrep:  au_name = (char_u *)"helpgrep"; break;
  case CMD_lhelpgrep: au_name = (char_u *)"lhelpgrep"; break;
  default: break;
  }
  if (au_name != NULL && apply_autocmds(EVENT_QUICKFIXCMDPRE, au_name,
                                        curbuf->b_fname, true, curbuf)) {
    if (aborting()) {
      return;
    }
  }

  /* Make 'cpoptions' empty, the 'l' flag should not be used here. */
  save_cpo = p_cpo;
  p_cpo = empty_option;

  if (eap->cmdidx == CMD_lhelpgrep) {
    win_T *wp = NULL;

    // If the current window is a help window, then use it
    if (bt_help(curwin->w_buffer)) {
      wp = curwin;
    } else {
      // Find an existing help window
      FOR_ALL_WINDOWS_IN_TAB(wp2, curtab) {
        if (bt_help(wp2->w_buffer)) {
          wp = wp2;
          break;
        }
      }
    }

    if (wp == NULL) {   // Help window not found
      qi = NULL;
    } else {
      qi = wp->w_llist;
    }
    if (qi == NULL) {
      /* Allocate a new location list for help text matches */
      qi = ll_new_list();
      new_qi = TRUE;
    }
  }

  // Autocommands may change the list. Save it for later comparison
  qf_info_T *save_qi = qi;

  regmatch.regprog = vim_regcomp(eap->arg, RE_MAGIC + RE_STRING);
  regmatch.rm_ic = FALSE;
  if (regmatch.regprog != NULL) {
    // Create a new quickfix list.
    qf_new_list(qi, *eap->cmdlinep);

    /* Go through all directories in 'runtimepath' */
    p = p_rtp;
    while (*p != NUL && !got_int) {
      copy_option_part(&p, NameBuff, MAXPATHL, ",");

      /* Find all "*.txt" and "*.??x" files in the "doc" directory. */
      add_pathsep((char *)NameBuff);
      STRCAT(NameBuff, "doc/*.\\(txt\\|??x\\)");

      // Note: We cannot just do `&NameBuff` because it is a statically sized array
      //       so `NameBuff == &NameBuff` according to C semantics.
      char_u *buff_list[1] = {NameBuff};
      if (gen_expand_wildcards(1, buff_list, &fcount,
              &fnames, EW_FILE|EW_SILENT) == OK
          && fcount > 0) {
        for (fi = 0; fi < fcount && !got_int; ++fi) {
          /* Skip files for a different language. */
          if (lang != NULL
              && STRNICMP(lang, fnames[fi]
                  + STRLEN(fnames[fi]) - 3, 2) != 0
              && !(STRNICMP(lang, "en", 2) == 0
                   && STRNICMP("txt", fnames[fi]
                       + STRLEN(fnames[fi]) - 3, 3) == 0))
            continue;
          fd = mch_fopen((char *)fnames[fi], "r");
          if (fd != NULL) {
            lnum = 1;
            while (!vim_fgets(IObuff, IOSIZE, fd) && !got_int) {
              char_u    *line = IObuff;
              if (vim_regexec(&regmatch, line, (colnr_T)0)) {
                int l = (int)STRLEN(line);

                /* remove trailing CR, LF, spaces, etc. */
                while (l > 0 && line[l - 1] <= ' ')
                  line[--l] = NUL;

                if (qf_add_entry(qi,
                                 qi->qf_curlist,
                                 NULL,                  // dir
                                 fnames[fi],
                                 0,
                                 line,
                                 lnum,
                                 (int)(regmatch.startp[0] - line)
                                 + 1,                   // col
                                 false,                 // vis_col
                                 NULL,                  // search pattern
                                 0,                     // nr
                                 1,                     // type
                                 true)                  // valid
                    == FAIL) {
                  got_int = true;
                  if (line != IObuff) {
                    xfree(line);
                  }
                  break;
                }
              }
              if (line != IObuff)
                xfree(line);
              ++lnum;
              line_breakcheck();
            }
            fclose(fd);
          }
        }
        FreeWild(fcount, fnames);
      }
    }

    vim_regfree(regmatch.regprog);

    qi->qf_lists[qi->qf_curlist].qf_nonevalid = FALSE;
    qi->qf_lists[qi->qf_curlist].qf_ptr =
      qi->qf_lists[qi->qf_curlist].qf_start;
    qi->qf_lists[qi->qf_curlist].qf_index = 1;
  }

  if (p_cpo == empty_option)
    p_cpo = save_cpo;
  else
    /* Darn, some plugin changed the value. */
    free_string_option(save_cpo);

  qf_update_buffer(qi, NULL);

  if (au_name != NULL) {
    apply_autocmds(EVENT_QUICKFIXCMDPOST, au_name,
                   curbuf->b_fname, true, curbuf);
    if (!new_qi && qi != save_qi && qf_find_buf(qi) == NULL) {
      // autocommands made "qi" invalid
      return;
    }
  }

  /* Jump to first match. */
  if (qi->qf_lists[qi->qf_curlist].qf_count > 0)
    qf_jump(qi, 0, 0, FALSE);
  else
    EMSG2(_(e_nomatch2), eap->arg);

  if (eap->cmdidx == CMD_lhelpgrep) {
    /* If the help window is not opened or if it already points to the
     * correct location list, then free the new location list. */
    if (!bt_help(curwin->w_buffer) || curwin->w_llist == qi) {
      if (new_qi) {
        ll_free_all(&qi);
      }
    } else if (curwin->w_llist == NULL) {
      curwin->w_llist = qi;
    }
  }
}

