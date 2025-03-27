// quickfix.c: functions for quickfix mode, using a file with error messages

#include <assert.h>
#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "nvim/arglist.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/window.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_eval_defs.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/help.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/macros_defs.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memline.h"
#include "nvim/memline_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/optionstr.h"
#include "nvim/os/fs.h"
#include "nvim/os/fs_defs.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/path.h"
#include "nvim/pos_defs.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/search.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

struct dir_stack_T {
  struct dir_stack_T *next;
  char *dirname;
};

// For each error the next struct is allocated and linked in a list.
typedef struct qfline_S qfline_T;
struct qfline_S {
  qfline_T *qf_next;      ///< pointer to next error in the list
  qfline_T *qf_prev;      ///< pointer to previous error in the list
  linenr_T qf_lnum;       ///< line number where the error occurred
  linenr_T qf_end_lnum;   ///< line number when the error has range or zero

  int qf_fnum;            ///< file number for the line
  int qf_col;             ///< column where the error occurred
  int qf_end_col;         ///< column when the error has range or zero
  int qf_nr;              ///< error number
  char *qf_module;        ///< module name for this error
  char *qf_fname;         ///< different filename if there're hard links
  char *qf_pattern;       ///< search pattern for the error
  char *qf_text;          ///< description of the error
  char qf_viscol;         ///< set to true if qf_col and qf_end_col is screen column
  char qf_cleared;        ///< set to true if line has been deleted
  char qf_type;           ///< type of the error (mostly 'E'); 1 for :helpgrep
  typval_T qf_user_data;  ///< custom user data associated with this item
  char qf_valid;          ///< valid error message detected
};

// There is a stack of error lists.
#define LISTCOUNT   10
#define INVALID_QFIDX (-1)
#define INVALID_QFBUFNR (0)

/// Quickfix list type.
typedef enum {
  QFLT_QUICKFIX,  ///< Quickfix list - global list
  QFLT_LOCATION,  ///< Location list - per window list
  QFLT_INTERNAL,  ///< Internal - Temporary list used by
  //   getqflist()/getloclist()
} qfltype_T;

/// Quickfix/Location list definition
///
/// Usually the list contains one or more entries. But an empty list can be
/// created using setqflist()/setloclist() with a title and/or user context
/// information and entries can be added later using setqflist()/setloclist().
typedef struct {
  unsigned qf_id;         ///< Unique identifier for this list
  qfltype_T qfl_type;
  qfline_T *qf_start;     ///< pointer to the first error
  qfline_T *qf_last;      ///< pointer to the last error
  qfline_T *qf_ptr;       ///< pointer to the current error
  int qf_count;           ///< number of errors (0 means empty list)
  int qf_index;           ///< current index in the error list
  bool qf_nonevalid;      ///< true if not a single valid entry found
  bool qf_has_user_data;  ///< true if at least one item has user_data attached
  char *qf_title;         ///< title derived from the command that created
                          ///< the error list or set by setqflist
  typval_T *qf_ctx;       ///< context set by setqflist/setloclist
  Callback qf_qftf_cb;    ///< 'quickfixtextfunc' callback function

  struct dir_stack_T *qf_dir_stack;
  char *qf_directory;
  struct dir_stack_T *qf_file_stack;
  char *qf_currfile;
  bool qf_multiline;
  bool qf_multiignore;
  bool qf_multiscan;
  int qf_changedtick;
} qf_list_T;

/// Quickfix/Location list stack definition
/// Contains a list of quickfix/location lists (qf_list_T)
struct qf_info_S {
  // Count of references to this list. Used only for location lists.
  // When a location list window reference this list, qf_refcount
  // will be 2. Otherwise, qf_refcount will be 1. When qf_refcount
  // reaches 0, the list is freed.
  int qf_refcount;
  int qf_listcount;                 // current number of lists
  int qf_curlist;                   // current error list
  qf_list_T qf_lists[LISTCOUNT];
  qfltype_T qfl_type;  // type of list
  int qf_bufnr;                     // quickfix window buffer number
};

static qf_info_T ql_info;         // global quickfix list
static unsigned last_qf_id = 0;   // Last Used quickfix list id

#define FMT_PATTERNS 14           // maximum number of % recognized

// Structure used to hold the info of one part of 'errorformat'
typedef struct efm_S efm_T;
struct efm_S {
  regprog_T *prog;        // pre-formatted part of 'errorformat'
  efm_T *next;        // pointer to next (NULL if last)
  char addr[FMT_PATTERNS];    // indices of used % patterns
  char prefix;                // prefix of this format line:
                              // 'D' enter directory
                              // 'X' leave directory
                              // 'A' start of multi-line message
                              // 'E' error message
                              // 'W' warning message
                              // 'I' informational message
                              // 'N' note message
                              // 'C' continuation line
                              // 'Z' end of multi-line message
                              // 'G' general, unspecific message
                              // 'P' push file (partial) message
                              // 'Q' pop/quit file (partial) message
                              // 'O' overread (partial) message
  char flags;                 // additional flags given in prefix
                              // '-' do not include this line
                              // '+' include whole line in message
  int conthere;                 // %> used
};

/// List of location lists to be deleted.
/// Used to delay the deletion of locations lists by autocmds.
typedef struct qf_delq_S {
  struct qf_delq_S *next;
  qf_info_T *qi;
} qf_delq_T;

enum {
  QF_FAIL = 0,
  QF_OK = 1,
  QF_END_OF_INPUT = 2,
  QF_NOMEM = 3,
  QF_IGNORE_LINE = 4,
  QF_MULTISCAN = 5,
  QF_ABORT = 6,
};

/// State information used to parse lines and add entries to a quickfix/location
/// list.
typedef struct {
  char *linebuf;
  size_t linelen;
  char *growbuf;
  size_t growbufsiz;
  FILE *fd;
  typval_T *tv;
  char *p_str;
  list_T *p_list;
  listitem_T *p_li;
  buf_T *buf;
  linenr_T buflnum;
  linenr_T lnumlast;
  vimconv_T vc;
} qfstate_T;

typedef struct {
  char *namebuf;
  int bnr;
  char *module;
  char *errmsg;
  size_t errmsglen;
  linenr_T lnum;
  linenr_T end_lnum;
  int col;
  int end_col;
  bool use_viscol;
  char *pattern;
  int enr;
  char type;
  typval_T *user_data;
  bool valid;
} qffields_T;

/// :vimgrep command arguments
typedef struct {
  int tomatch;          ///< maximum number of matches to find
  char *spat;          ///< search pattern
  int flags;             ///< search modifier
  char **fnames;       ///< list of files to search
  int fcount;            ///< number of files
  regmmatch_T regmatch;  ///< compiled search pattern
  char *qf_title;      ///< quickfix list title
} vgr_args_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "quickfix.c.generated.h"
#endif

static const char *e_no_more_items = N_("E553: No more items");
static const char *e_current_quickfix_list_was_changed =
  N_("E925: Current quickfix list was changed");
static const char *e_current_location_list_was_changed =
  N_("E926: Current location list was changed");

enum { QF_WINHEIGHT = 10, };  ///< default height for quickfix window

// Quickfix window check helper macro
#define IS_QF_WINDOW(wp) (bt_quickfix((wp)->w_buffer) && (wp)->w_llist_ref == NULL)
// Location list window check helper macro
#define IS_LL_WINDOW(wp) (bt_quickfix((wp)->w_buffer) && (wp)->w_llist_ref != NULL)

// Quickfix and location list stack check helper macros
#define IS_QF_STACK(qi)       ((qi)->qfl_type == QFLT_QUICKFIX)
#define IS_LL_STACK(qi)       ((qi)->qfl_type == QFLT_LOCATION)
#define IS_QF_LIST(qfl)       ((qfl)->qfl_type == QFLT_QUICKFIX)
#define IS_LL_LIST(qfl)       ((qfl)->qfl_type == QFLT_LOCATION)

// Return location list for window 'wp'
// For location list window, return the referenced location list
#define GET_LOC_LIST(wp) (IS_LL_WINDOW(wp) ? (wp)->w_llist_ref : (wp)->w_llist)

// Macro to loop through all the items in a quickfix list
// Quickfix item index starts from 1, so i below starts at 1
#define FOR_ALL_QFL_ITEMS(qfl, qfp, i) \
  for ((i) = 1, (qfp) = (qfl)->qf_start; \
       !got_int && (i) <= (qfl)->qf_count && (qfp) != NULL; \
       (i)++, (qfp) = (qfp)->qf_next)

// Looking up a buffer can be slow if there are many.  Remember the last one
// to make this a lot faster if there are multiple matches in the same file.
static char *qf_last_bufname = NULL;
static bufref_T qf_last_bufref = { NULL, 0, 0 };

static garray_T qfga;

/// Get a growarray to buffer text in.  Shared between various commands to avoid
/// many alloc/free calls.
static garray_T *qfga_get(void)
{
  static bool initialized = false;

  if (!initialized) {
    initialized = true;
    ga_init(&qfga, 1, 256);
  }

  // Reset the length to zero.  Retain ga_data from previous use to avoid
  // many alloc/free calls.
  qfga.ga_len = 0;

  return &qfga;
}

/// The "qfga" grow array buffer is reused across multiple quickfix commands as
/// a temporary buffer to reduce the number of alloc/free calls.  But if the
/// buffer size is large, then to avoid holding on to that memory, clear the
/// grow array.  Otherwise just reset the grow array length.
static void qfga_clear(void)
{
  if (qfga.ga_maxlen > 1000) {
    ga_clear(&qfga);
  } else {
    qfga.ga_len = 0;
  }
}

// Counter to prevent autocmds from freeing up location lists when they are
// still being used.
static int quickfix_busy = 0;
static qf_delq_T *qf_delq_head = NULL;

/// Process the next line from a file/buffer/list/string and add it
/// to the quickfix list 'qfl'.
static int qf_init_process_nextline(qf_list_T *qfl, efm_T *fmt_first, qfstate_T *state,
                                    qffields_T *fields)
{
  // Get the next line from a file/buffer/list/string
  int status = qf_get_nextline(state);
  if (status != QF_OK) {
    return status;
  }

  status = qf_parse_line(qfl, state->linebuf, state->linelen,
                         fmt_first, fields);
  if (status != QF_OK) {
    return status;
  }

  return qf_add_entry(qfl,
                      qfl->qf_directory,
                      (*fields->namebuf || qfl->qf_directory != NULL)
                      ? fields->namebuf
                      : ((qfl->qf_currfile != NULL && fields->valid)
                         ? qfl->qf_currfile : NULL),
                      fields->module,
                      fields->bnr,
                      fields->errmsg,
                      fields->lnum,
                      fields->end_lnum,
                      fields->col,
                      fields->end_col,
                      fields->use_viscol,
                      fields->pattern,
                      fields->enr,
                      fields->type,
                      fields->user_data,
                      fields->valid);
}

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
int qf_init(win_T *wp, const char *restrict efile, char *restrict errorformat, int newlist,
            const char *restrict qf_title, char *restrict enc)
{
  qf_info_T *qi = wp == NULL ? &ql_info : ll_get_or_alloc_list(wp);

  return qf_init_ext(qi, qi->qf_curlist, efile, curbuf, NULL, errorformat,
                     newlist, 0, 0, qf_title, enc);
}

// Maximum number of bytes allowed per line while reading an errorfile.
static const size_t LINE_MAXLEN = 4096;

/// Patterns used.  Keep in sync with qf_parse_fmt[].
static struct fmtpattern {
  char convchar;
  char *pattern;
} fmt_pat[FMT_PATTERNS] = {
  { 'f', ".\\+" },      // only used when at end
  { 'b', "\\d\\+" },    // 1
  { 'n', "\\d\\+" },    // 2
  { 'l', "\\d\\+" },    // 3
  { 'e', "\\d\\+" },    // 4
  { 'c', "\\d\\+" },    // 5
  { 'k', "\\d\\+" },    // 6
  { 't', "." },         // 7
#define FMT_PATTERN_M 8
  { 'm', ".\\+" },      // 8
#define FMT_PATTERN_R 9
  { 'r', ".*" },        // 9
  { 'p', "[-\t .]*" },  // 10
  { 'v', "\\d\\+" },    // 11
  { 's', ".\\+" },      // 12
  { 'o', ".\\+" }       // 13
};

/// Convert an errorformat pattern to a regular expression pattern.
/// See fmt_pat definition above for the list of supported patterns.  The
/// pattern specifier is supplied in "efmpat".  The converted pattern is stored
/// in "regpat".  Returns a pointer to the location after the pattern.
static char *efmpat_to_regpat(const char *efmpat, char *regpat, efm_T *efminfo, int idx, int round)
  FUNC_ATTR_NONNULL_ALL
{
  if (efminfo->addr[idx]) {
    // Each errorformat pattern can occur only once
    semsg(_("E372: Too many %%%c in format string"), *efmpat);
    return NULL;
  }
  if ((idx && idx < FMT_PATTERN_R
       && vim_strchr("DXOPQ", (uint8_t)efminfo->prefix) != NULL)
      || (idx == FMT_PATTERN_R
          && vim_strchr("OPQ", (uint8_t)efminfo->prefix) == NULL)) {
    semsg(_("E373: Unexpected %%%c in format string"), *efmpat);
    return NULL;
  }
  efminfo->addr[idx] = (char)++round;
  *regpat++ = '\\';
  *regpat++ = '(';
#ifdef BACKSLASH_IN_FILENAME
  if (*efmpat == 'f') {
    // Also match "c:" in the file name, even when
    // checking for a colon next: "%f:".
    // "\%(\a:\)\="
    STRCPY(regpat, "\\%(\\a:\\)\\=");
    regpat += 10;
  }
#endif
  if (*efmpat == 'f' && efmpat[1] != NUL) {
    if (efmpat[1] != '\\' && efmpat[1] != '%') {
      // A file name may contain spaces, but this isn't
      // in "\f".  For "%f:%l:%m" there may be a ":" in
      // the file name.  Use ".\{-1,}x" instead (x is
      // the next character), the requirement that :999:
      // follows should work.
      STRCPY(regpat, ".\\{-1,}");
      regpat += 7;
    } else {
      // File name followed by '\\' or '%': include as
      // many file name chars as possible.
      STRCPY(regpat, "\\f\\+");
      regpat += 4;
    }
  } else {
    char *srcptr = fmt_pat[idx].pattern;
    while ((*regpat = *srcptr++) != NUL) {
      regpat++;
    }
  }
  *regpat++ = '\\';
  *regpat++ = ')';

  return regpat;
}

/// Convert a scanf like format in 'errorformat' to a regular expression.
/// Returns a pointer to the location after the pattern.
static char *scanf_fmt_to_regpat(const char **pefmp, const char *efm, int len, char *regpat)
  FUNC_ATTR_NONNULL_ALL
{
  const char *efmp = *pefmp;

  if (*efmp == '[' || *efmp == '\\') {
    if ((*regpat++ = *efmp) == '[') {  // %*[^a-z0-9] etc.
      if (efmp[1] == '^') {
        *regpat++ = *++efmp;
      }
      if (efmp < efm + len) {
        *regpat++ = *++efmp;  // could be ']'
        while (efmp < efm + len && (*regpat++ = *++efmp) != ']') {}
        if (efmp == efm + len) {
          emsg(_("E374: Missing ] in format string"));
          return NULL;
        }
      }
    } else if (efmp < efm + len) {  // %*\D, %*\s etc.
      *regpat++ = *++efmp;
    }
    *regpat++ = '\\';
    *regpat++ = '+';
  } else {
    semsg(_("E375: Unsupported %%%c in format string"), *efmp);
    return NULL;
  }

  *pefmp = efmp;

  return regpat;
}

/// Analyze/parse an errorformat prefix.
static const char *efm_analyze_prefix(const char *efmp, efm_T *efminfo)
  FUNC_ATTR_NONNULL_ALL
{
  if (vim_strchr("+-", (uint8_t)(*efmp)) != NULL) {
    efminfo->flags = *efmp++;
  }
  if (vim_strchr("DXAEWINCZGOPQ", (uint8_t)(*efmp)) != NULL) {
    efminfo->prefix = *efmp;
  } else {
    semsg(_("E376: Invalid %%%c in format string prefix"), *efmp);
    return NULL;
  }

  return efmp;
}

// Converts a 'errorformat' string to regular expression pattern
static int efm_to_regpat(const char *efm, int len, efm_T *fmt_ptr, char *regpat)
  FUNC_ATTR_NONNULL_ALL
{
  // Build regexp pattern from current 'errorformat' option
  char *ptr = regpat;
  *ptr++ = '^';
  int round = 0;
  for (const char *efmp = efm; efmp < efm + len; efmp++) {
    if (*efmp == '%') {
      efmp++;
      int idx;
      for (idx = 0; idx < FMT_PATTERNS; idx++) {
        if (fmt_pat[idx].convchar == *efmp) {
          break;
        }
      }
      if (idx < FMT_PATTERNS) {
        ptr = efmpat_to_regpat(efmp, ptr, fmt_ptr, idx, round);
        if (ptr == NULL) {
          return FAIL;
        }
        round++;
      } else if (*efmp == '*') {
        efmp++;
        ptr = scanf_fmt_to_regpat(&efmp, efm, len, ptr);
        if (ptr == NULL) {
          return FAIL;
        }
      } else if (vim_strchr("%\\.^$~[", (uint8_t)(*efmp)) != NULL) {
        *ptr++ = *efmp;  // regexp magic characters
      } else if (*efmp == '#') {
        *ptr++ = '*';
      } else if (*efmp == '>') {
        fmt_ptr->conthere = true;
      } else if (efmp == efm + 1) {             // analyse prefix
        // prefix is allowed only at the beginning of the errorformat
        // option part
        efmp = efm_analyze_prefix(efmp, fmt_ptr);
        if (efmp == NULL) {
          return FAIL;
        }
      } else {
        semsg(_("E377: Invalid %%%c in format string"), *efmp);
        return FAIL;
      }
    } else {                    // copy normal character
      if (*efmp == '\\' && efmp + 1 < efm + len) {
        efmp++;
      } else if (vim_strchr(".*^$~[", (uint8_t)(*efmp)) != NULL) {
        *ptr++ = '\\';  // escape regexp atoms
      }
      if (*efmp) {
        *ptr++ = *efmp;
      }
    }
  }
  *ptr++ = '$';
  *ptr = NUL;

  return OK;
}

static efm_T *fmt_start = NULL;  // cached across qf_parse_line() calls

// callback function for 'quickfixtextfunc'
static Callback qftf_cb;

static void free_efm_list(efm_T **efm_first)
{
  for (efm_T *efm_ptr = *efm_first; efm_ptr != NULL; efm_ptr = *efm_first) {
    *efm_first = efm_ptr->next;
    vim_regfree(efm_ptr->prog);
    xfree(efm_ptr);
  }

  fmt_start = NULL;
}

/// Compute the size of the buffer used to convert a 'errorformat' pattern into
/// a regular expression pattern.
static size_t efm_regpat_bufsz(char *efm)
{
  size_t sz = (FMT_PATTERNS * 3) + (strlen(efm) << 2);
  for (int i = FMT_PATTERNS - 1; i >= 0;) {
    sz += strlen(fmt_pat[i--].pattern);
  }
#ifdef BACKSLASH_IN_FILENAME
  sz += 12;  // "%f" can become twelve chars longer (see efm_to_regpat)
#else
  sz += 2;  // "%f" can become two chars longer
#endif

  return sz;
}

/// Return the length of a 'errorformat' option part (separated by ",").
static int efm_option_part_len(const char *efm)
{
  int len;

  for (len = 0; efm[len] != NUL && efm[len] != ','; len++) {
    if (efm[len] == '\\' && efm[len + 1] != NUL) {
      len++;
    }
  }

  return len;
}

/// Parse the 'errorformat' option. Multiple parts in the 'errorformat' option
/// are parsed and converted to regular expressions. Returns information about
/// the parsed 'errorformat' option.
static efm_T *parse_efm_option(char *efm)
{
  efm_T *fmt_first = NULL;
  efm_T *fmt_last = NULL;

  // Get some space to modify the format string into.
  size_t sz = efm_regpat_bufsz(efm);
  char *fmtstr = xmalloc(sz);

  while (efm[0] != NUL) {
    // Allocate a new eformat structure and put it at the end of the list
    efm_T *fmt_ptr = (efm_T *)xcalloc(1, sizeof(efm_T));
    if (fmt_first == NULL) {        // first one
      fmt_first = fmt_ptr;
    } else {
      fmt_last->next = fmt_ptr;
    }
    fmt_last = fmt_ptr;

    // Isolate one part in the 'errorformat' option
    int len = efm_option_part_len(efm);

    if (efm_to_regpat(efm, len, fmt_ptr, fmtstr) == FAIL) {
      goto parse_efm_error;
    }
    if ((fmt_ptr->prog = vim_regcomp(fmtstr, RE_MAGIC + RE_STRING)) == NULL) {
      goto parse_efm_error;
    }
    // Advance to next part
    efm = skip_to_option_part(efm + len);       // skip comma and spaces
  }

  if (fmt_first == NULL) {      // nothing found
    emsg(_("E378: 'errorformat' contains no pattern"));
  }

  goto parse_efm_end;

parse_efm_error:
  free_efm_list(&fmt_first);

parse_efm_end:
  xfree(fmtstr);

  return fmt_first;
}

/// Allocate more memory for the line buffer used for parsing lines.
static char *qf_grow_linebuf(qfstate_T *state, size_t newsz)
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
  char *p_str = state->p_str;

  if (*p_str == NUL) {  // Reached the end of the string
    return QF_END_OF_INPUT;
  }

  char *p = vim_strchr(p_str, '\n');
  size_t len = (p != NULL) ? (size_t)(p - p_str) + 1 : strlen(p_str);

  if (len > IOSIZE - 2) {
    state->linebuf = qf_grow_linebuf(state, len);
  } else {
    state->linebuf = IObuff;
    state->linelen = len;
  }
  memcpy(state->linebuf, p_str, state->linelen);
  state->linebuf[state->linelen] = NUL;

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

  size_t len = strlen(TV_LIST_ITEM_TV(p_li)->vval.v_string);
  if (len > IOSIZE - 2) {
    state->linebuf = qf_grow_linebuf(state, len);
  } else {
    state->linebuf = IObuff;
    state->linelen = len;
  }

  xstrlcpy(state->linebuf, TV_LIST_ITEM_TV(p_li)->vval.v_string,
           state->linelen + 1);

  state->p_li = TV_LIST_ITEM_NEXT(state->p_list, p_li);
  return QF_OK;
}

/// Get the next string from state->buf.
static int qf_get_next_buf_line(qfstate_T *state)
{
  // Get the next line from the supplied buffer
  if (state->buflnum > state->lnumlast) {
    return QF_END_OF_INPUT;
  }
  char *p_buf = ml_get_buf(state->buf, state->buflnum);
  size_t len = (size_t)ml_get_buf_len(state->buf, state->buflnum);
  state->buflnum += 1;

  if (len > IOSIZE - 2) {
    state->linebuf = qf_grow_linebuf(state, len);
  } else {
    state->linebuf = IObuff;
    state->linelen = len;
  }
  xstrlcpy(state->linebuf, p_buf, state->linelen + 1);

  return QF_OK;
}

/// Get the next string from file state->fd.
static int qf_get_next_file_line(qfstate_T *state)
{
retry:
  errno = 0;
  if (fgets(IObuff, IOSIZE, state->fd) == NULL) {
    if (errno == EINTR) {
      goto retry;
    }
    return QF_END_OF_INPUT;
  }

  bool discard = false;
  state->linelen = strlen(IObuff);
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
    size_t growbuflen = state->linelen;

    while (true) {
      errno = 0;
      if (fgets(state->growbuf + growbuflen,
                (int)(state->growbufsiz - growbuflen), state->fd) == NULL) {
        if (errno == EINTR) {
          continue;
        }
        break;
      }
      state->linelen = strlen(state->growbuf + growbuflen);
      growbuflen += state->linelen;
      if (state->growbuf[growbuflen - 1] == '\n') {
        break;
      }
      if (state->growbufsiz == LINE_MAXLEN) {
        discard = true;
        break;
      }

      state->growbufsiz = MIN(2 * state->growbufsiz, LINE_MAXLEN);
      state->growbuf = xrealloc(state->growbuf, state->growbufsiz);
    }

    while (discard) {
      // The current line is longer than LINE_MAXLEN, continue reading but
      // discard everything until EOL or EOF is reached.
      errno = 0;
      if (fgets(IObuff, IOSIZE, state->fd) == NULL) {
        if (errno == EINTR) {
          continue;
        }
        break;
      }
      if (strlen(IObuff) < IOSIZE - 1 || IObuff[IOSIZE - 2] == '\n') {
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
    char *line = string_convert(&state->vc, state->linebuf, &state->linelen);
    if (line != NULL) {
      if (state->linelen < IOSIZE) {
        xstrlcpy(state->linebuf, line, state->linelen + 1);
        xfree(line);
      } else {
        xfree(state->growbuf);
        state->linebuf = line;
        state->growbuf = line;
        state->growbufsiz = MIN(state->linelen, LINE_MAXLEN);
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

/// Returns true if the specified quickfix/location stack is empty
static bool qf_stack_empty(const qf_info_T *qi)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return qi == NULL || qi->qf_listcount <= 0;
}

/// Returns true if the specified quickfix/location list is empty.
static bool qf_list_empty(qf_list_T *qfl)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return qfl == NULL || qfl->qf_count <= 0;
}

/// Returns true if the specified quickfix/location list is not empty and
/// has valid entries.
static bool qf_list_has_valid_entries(qf_list_T *qfl)
{
  return !qf_list_empty(qfl) && !qfl->qf_nonevalid;
}

/// Return a pointer to a list in the specified quickfix stack
static qf_list_T *qf_get_list(qf_info_T *qi, int idx)
  FUNC_ATTR_NONNULL_ALL
{
  return &qi->qf_lists[idx];
}

/// Parse a line and get the quickfix fields.
/// Return the QF_ status.
static int qf_parse_line(qf_list_T *qfl, char *linebuf, size_t linelen, efm_T *fmt_first,
                         qffields_T *fields)
{
  efm_T *fmt_ptr;
  int idx = 0;
  char *tail = NULL;
  int status;

restofline:
  // If there was no %> item start at the first pattern
  if (fmt_start == NULL) {
    fmt_ptr = fmt_first;
  } else {
    // Otherwise start from the last used pattern.
    fmt_ptr = fmt_start;
    fmt_start = NULL;
  }

  // Try to match each part of 'errorformat' until we find a complete
  // match or no match.
  fields->valid = true;
  for (; fmt_ptr != NULL; fmt_ptr = fmt_ptr->next) {
    idx = (uint8_t)fmt_ptr->prefix;
    status = qf_parse_get_fields(linebuf, linelen, fmt_ptr, fields,
                                 qfl->qf_multiline, qfl->qf_multiscan,
                                 &tail);
    if (status == QF_NOMEM) {
      return status;
    }
    if (status == QF_OK) {
      break;
    }
  }
  qfl->qf_multiscan = false;

  if (fmt_ptr == NULL || idx == 'D' || idx == 'X') {
    if (fmt_ptr != NULL) {
      // 'D' and 'X' directory specifiers.
      status = qf_parse_dir_pfx(idx, fields, qfl);
      if (status != QF_OK) {
        return status;
      }
    }
    status = qf_parse_line_nomatch(linebuf, linelen, fields);
    if (status != QF_OK) {
      return status;
    }
    if (fmt_ptr == NULL) {
      qfl->qf_multiline = qfl->qf_multiignore = false;
    }
  } else {
    // honor %> item
    if (fmt_ptr->conthere) {
      fmt_start = fmt_ptr;
    }

    if (vim_strchr("AEWIN", idx) != NULL) {
      qfl->qf_multiline = true;     // start of a multi-line message
      qfl->qf_multiignore = false;  // reset continuation
    } else if (vim_strchr("CZ", idx) != NULL) {
      // continuation of multi-line msg
      status = qf_parse_multiline_pfx(idx, qfl, fields);
      if (status != QF_OK) {
        return status;
      }
    } else if (vim_strchr("OPQ", idx) != NULL) {
      // global file names
      status = qf_parse_file_pfx(idx, fields, qfl, tail);
      if (status == QF_MULTISCAN) {
        goto restofline;
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

// Allocate the fields used for parsing lines and populating a quickfix list.
static void qf_alloc_fields(qffields_T *pfields)
  FUNC_ATTR_NONNULL_ALL
{
  pfields->namebuf = xmalloc(CMDBUFFSIZE + 1);
  pfields->module = xmalloc(CMDBUFFSIZE + 1);
  pfields->errmsglen = CMDBUFFSIZE + 1;
  pfields->errmsg = xmalloc(pfields->errmsglen);
  pfields->pattern = xmalloc(CMDBUFFSIZE + 1);
}

// Free the fields used for parsing lines and populating a quickfix list.
static void qf_free_fields(qffields_T *pfields)
  FUNC_ATTR_NONNULL_ALL
{
  xfree(pfields->namebuf);
  xfree(pfields->module);
  xfree(pfields->errmsg);
  xfree(pfields->pattern);
}

// Setup the state information used for parsing lines and populating a
// quickfix list.
static int qf_setup_state(qfstate_T *pstate, char *restrict enc, const char *restrict efile,
                          typval_T *tv, buf_T *buf, linenr_T lnumfirst, linenr_T lnumlast)
  FUNC_ATTR_NONNULL_ARG(1)
{
  pstate->vc.vc_type = CONV_NONE;
  if (enc != NULL && *enc != NUL) {
    convert_setup(&pstate->vc, enc, p_enc);
  }

  if (efile != NULL
      && (pstate->fd = (strequal(efile, "-")
                        ? fdopen(os_open_stdin_fd(), "r")
                        : os_fopen(efile, "r"))) == NULL) {
    semsg(_(e_openerrf), efile);
    return FAIL;
  }

  if (tv != NULL) {
    if (tv->v_type == VAR_STRING) {
      pstate->p_str = tv->vval.v_string;
    } else if (tv->v_type == VAR_LIST) {
      pstate->p_li = tv_list_first(tv->vval.v_list);
    }
    pstate->tv = tv;
  }
  pstate->buf = buf;
  pstate->buflnum = lnumfirst;
  pstate->lnumlast = lnumlast;

  return OK;
}

// Cleanup the state information used for parsing lines and populating a
// quickfix list.
static void qf_cleanup_state(qfstate_T *pstate)
  FUNC_ATTR_NONNULL_ALL
{
  if (pstate->fd != NULL) {
    fclose(pstate->fd);
  }
  xfree(pstate->growbuf);
  if (pstate->vc.vc_type != CONV_NONE) {
    convert_setup(&pstate->vc, NULL, NULL);
  }
}

/// Read the errorfile "efile" into memory, line by line, building the error
/// list.
/// Alternative: when "efile" is NULL read errors from buffer "buf".
/// Alternative: when "tv" is not NULL get errors from the string or list.
/// Always use 'errorformat' from "buf" if there is a local value.
/// Then "lnumfirst" and "lnumlast" specify the range of lines to use.
/// Set the title of the list to "qf_title".
///
/// @param newlist  true: start a new error list
/// @param lnumfirst  first line number to use
/// @param lnumlast  last line number to use
///
/// @return  -1 for error, number of errors for success.
static int qf_init_ext(qf_info_T *qi, int qf_idx, const char *restrict efile, buf_T *buf,
                       typval_T *tv, char *restrict errorformat, bool newlist, linenr_T lnumfirst,
                       linenr_T lnumlast, const char *restrict qf_title, char *restrict enc)
  FUNC_ATTR_NONNULL_ARG(1)
{
  qfstate_T state = { 0 };
  qffields_T fields = { 0 };
  qfline_T *old_last = NULL;
  static efm_T *fmt_first = NULL;
  static char *last_efm = NULL;
  int retval = -1;                      // default: return error flag

  // Do not used the cached buffer, it may have been wiped out.
  XFREE_CLEAR(qf_last_bufname);

  qf_alloc_fields(&fields);
  if (qf_setup_state(&state, enc, efile, tv, buf, lnumfirst, lnumlast) == FAIL) {
    goto qf_init_end;
  }

  qf_list_T *qfl;
  bool adding = false;
  if (newlist || qf_idx == qi->qf_listcount) {
    // make place for a new list
    qf_new_list(qi, qf_title);
    qf_idx = qi->qf_curlist;
    qfl = qf_get_list(qi, qf_idx);
  } else {
    // Adding to existing list, use last entry.
    adding = true;
    qfl = qf_get_list(qi, qf_idx);
    if (!qf_list_empty(qfl)) {
      old_last = qfl->qf_last;
    }
  }

  // Use the local value of 'errorformat' if it's set.
  char *efm = (errorformat == p_efm && tv == NULL && buf && *buf->b_p_efm != NUL)
              ? buf->b_p_efm
              : errorformat;

  // If the errorformat didn't change between calls, then reuse the previously
  // parsed values.
  if (last_efm == NULL || (strcmp(last_efm, efm) != 0)) {
    // free the previously parsed data
    XFREE_CLEAR(last_efm);
    free_efm_list(&fmt_first);

    // parse the current 'efm'
    fmt_first = parse_efm_option(efm);
    if (fmt_first != NULL) {
      last_efm = xstrdup(efm);
    }
  }

  if (fmt_first == NULL) {      // nothing found
    goto error2;
  }

  // got_int is reset here, because it was probably set when killing the
  // ":make" command, but we still want to read the errorfile then.
  got_int = false;

  // Read the lines in the error file one by one.
  // Try to recognize one of the error formats in each line.
  while (!got_int) {
    int status = qf_init_process_nextline(qfl, fmt_first, &state, &fields);
    if (status == QF_END_OF_INPUT) {  // end of input
      break;
    }
    if (status == QF_FAIL) {
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
  emsg(_(e_readerrf));
error2:
  if (!adding) {
    // Error when creating a new list. Free the new list
    qf_free(qfl);
    qi->qf_listcount--;
    if (qi->qf_curlist > 0) {
      qi->qf_curlist--;
    }
  }
qf_init_end:
  if (qf_idx == qi->qf_curlist) {
    qf_update_buffer(qi, old_last);
  }
  qf_cleanup_state(&state);
  qf_free_fields(&fields);

  return retval;
}

/// Set the title of the specified quickfix list. Frees the previous title.
/// Prepends ':' to the title.
static void qf_store_title(qf_list_T *qfl, const char *title)
  FUNC_ATTR_NONNULL_ARG(1)
{
  XFREE_CLEAR(qfl->qf_title);

  if (title == NULL) {
    return;
  }

  size_t len = strlen(title) + 1;
  char *p = xmallocz(len);

  qfl->qf_title = p;
  xstrlcpy(p, title, len + 1);
}

/// The title of a quickfix/location list is set, by default, to the command
/// that created the quickfix list with the ":" prefix.
/// Create a quickfix list title string by prepending ":" to a user command.
/// Returns a pointer to a static buffer with the title.
static char *qf_cmdtitle(char *cmd)
{
  static char qftitle_str[IOSIZE];

  snprintf(qftitle_str, IOSIZE, ":%s", cmd);

  return qftitle_str;
}

/// Return a pointer to the current list in the specified quickfix stack
static qf_list_T *qf_get_curlist(qf_info_T *qi)
  FUNC_ATTR_NONNULL_ALL
{
  return qf_get_list(qi, qi->qf_curlist);
}

/// Prepare for adding a new quickfix list. If the current list is in the
/// middle of the stack, then all the following lists are freed and then
/// the new list is added.
static void qf_new_list(qf_info_T *qi, const char *qf_title)
{
  // If the current entry is not the last entry, delete entries beyond
  // the current entry.  This makes it possible to browse in a tree-like
  // way with ":grep".
  while (qi->qf_listcount > qi->qf_curlist + 1) {
    qf_free(&qi->qf_lists[--qi->qf_listcount]);
  }

  // When the stack is full, remove to oldest entry
  // Otherwise, add a new entry.
  if (qi->qf_listcount == LISTCOUNT) {
    qf_free(&qi->qf_lists[0]);
    for (int i = 1; i < LISTCOUNT; i++) {
      qi->qf_lists[i - 1] = qi->qf_lists[i];
    }
    qi->qf_curlist = LISTCOUNT - 1;
  } else {
    qi->qf_curlist = qi->qf_listcount++;
  }
  qf_list_T *qfl = qf_get_curlist(qi);
  CLEAR_POINTER(qfl);
  qf_store_title(qfl, qf_title);
  qfl->qfl_type = qi->qfl_type;
  qfl->qf_id = ++last_qf_id;
  qfl->qf_has_user_data = false;
}

/// Parse the match for filename ('%f') pattern in regmatch.
/// Return the matched value in "fields->namebuf".
static int qf_parse_fmt_f(regmatch_T *rmp, int midx, qffields_T *fields, int prefix)
{
  if (rmp->startp[midx] == NULL || rmp->endp[midx] == NULL) {
    return QF_FAIL;
  }

  // Expand ~/file and $HOME/file to full path.
  char c = *rmp->endp[midx];
  *rmp->endp[midx] = NUL;
  expand_env(rmp->startp[midx], fields->namebuf, CMDBUFFSIZE);
  *rmp->endp[midx] = c;

  // For separate filename patterns (%O, %P and %Q), the specified file
  // should exist.
  if (vim_strchr("OPQ", prefix) != NULL
      && !os_path_exists(fields->namebuf)) {
    return QF_FAIL;
  }

  return QF_OK;
}

/// Parse the match for buffer number ('%b') pattern in regmatch.
/// Return the matched value in "fields->bnr".
static int qf_parse_fmt_b(regmatch_T *rmp, int midx, qffields_T *fields)
{
  if (rmp->startp[midx] == NULL) {
    return QF_FAIL;
  }
  int bnr = (int)atol(rmp->startp[midx]);
  if (buflist_findnr(bnr) == NULL) {
    return QF_FAIL;
  }
  fields->bnr = bnr;
  return QF_OK;
}

/// Parse the match for error number ('%n') pattern in regmatch.
/// Return the matched value in "fields->enr".
static int qf_parse_fmt_n(regmatch_T *rmp, int midx, qffields_T *fields)
{
  if (rmp->startp[midx] == NULL) {
    return QF_FAIL;
  }
  fields->enr = (int)atol(rmp->startp[midx]);
  return QF_OK;
}

/// Parse the match for line number ('%l') pattern in regmatch.
/// Return the matched value in "fields->lnum".
static int qf_parse_fmt_l(regmatch_T *rmp, int midx, qffields_T *fields)
{
  if (rmp->startp[midx] == NULL) {
    return QF_FAIL;
  }
  fields->lnum = (linenr_T)atol(rmp->startp[midx]);
  return QF_OK;
}

/// Parse the match for end line number ('%e') pattern in regmatch.
/// Return the matched value in "fields->end_lnum".
static int qf_parse_fmt_e(regmatch_T *rmp, int midx, qffields_T *fields)
{
  if (rmp->startp[midx] == NULL) {
    return QF_FAIL;
  }
  fields->end_lnum = (linenr_T)atol(rmp->startp[midx]);
  return QF_OK;
}

/// Parse the match for column number ('%c') pattern in regmatch.
/// Return the matched value in "fields->col".
static int qf_parse_fmt_c(regmatch_T *rmp, int midx, qffields_T *fields)
{
  if (rmp->startp[midx] == NULL) {
    return QF_FAIL;
  }
  fields->col = (int)atol(rmp->startp[midx]);
  return QF_OK;
}

/// Parse the match for end line number ('%e') pattern in regmatch.
/// Return the matched value in "fields->end_lnum".
static int qf_parse_fmt_k(regmatch_T *rmp, int midx, qffields_T *fields)
{
  if (rmp->startp[midx] == NULL) {
    return QF_FAIL;
  }
  fields->end_col = (int)atol(rmp->startp[midx]);
  return QF_OK;
}

/// Parse the match for error type ('%t') pattern in regmatch.
/// Return the matched value in "fields->type".
static int qf_parse_fmt_t(regmatch_T *rmp, int midx, qffields_T *fields)
{
  if (rmp->startp[midx] == NULL) {
    return QF_FAIL;
  }
  fields->type = *rmp->startp[midx];
  return QF_OK;
}

/// Copy a non-error line into the error string.  Return the matched line in
/// "fields->errmsg".
static int copy_nonerror_line(const char *linebuf, size_t linelen, qffields_T *fields)
  FUNC_ATTR_NONNULL_ALL
{
  if (linelen >= fields->errmsglen) {
    // linelen + null terminator
    fields->errmsg = xrealloc(fields->errmsg, linelen + 1);
    fields->errmsglen = linelen + 1;
  }
  // copy whole line to error message
  xstrlcpy(fields->errmsg, linebuf, linelen + 1);

  return QF_OK;
}

/// Parse the match for error message ('%m') pattern in regmatch.
/// Return the matched value in "fields->errmsg".
static int qf_parse_fmt_m(regmatch_T *rmp, int midx, qffields_T *fields)
{
  if (rmp->startp[midx] == NULL || rmp->endp[midx] == NULL) {
    return QF_FAIL;
  }
  size_t len = (size_t)(rmp->endp[midx] - rmp->startp[midx]);
  if (len >= fields->errmsglen) {
    // len + null terminator
    fields->errmsg = xrealloc(fields->errmsg, len + 1);
    fields->errmsglen = len + 1;
  }
  xstrlcpy(fields->errmsg, rmp->startp[midx], len + 1);
  return QF_OK;
}

/// Parse the match for rest of a single-line file message ('%r') pattern.
/// Return the matched value in "tail".
static int qf_parse_fmt_r(regmatch_T *rmp, int midx, char **tail)
{
  if (rmp->startp[midx] == NULL) {
    return QF_FAIL;
  }
  *tail = rmp->startp[midx];
  return QF_OK;
}

/// Parse the match for the pointer line ('%p') pattern in regmatch.
/// Return the matched value in "fields->col".
static int qf_parse_fmt_p(regmatch_T *rmp, int midx, qffields_T *fields)
{
  if (rmp->startp[midx] == NULL || rmp->endp[midx] == NULL) {
    return QF_FAIL;
  }
  fields->col = 0;
  for (char *match_ptr = rmp->startp[midx]; match_ptr != rmp->endp[midx];
       match_ptr++) {
    fields->col++;
    if (*match_ptr == TAB) {
      fields->col += 7;
      fields->col -= fields->col % 8;
    }
  }
  fields->col++;
  fields->use_viscol = true;
  return QF_OK;
}

/// Parse the match for the virtual column number ('%v') pattern in regmatch.
/// Return the matched value in "fields->col".
static int qf_parse_fmt_v(regmatch_T *rmp, int midx, qffields_T *fields)
{
  if (rmp->startp[midx] == NULL) {
    return QF_FAIL;
  }
  fields->col = (int)atol(rmp->startp[midx]);
  fields->use_viscol = true;
  return QF_OK;
}

/// Parse the match for the search text ('%s') pattern in regmatch.
/// Return the matched value in "fields->pattern".
static int qf_parse_fmt_s(regmatch_T *rmp, int midx, qffields_T *fields)
{
  if (rmp->startp[midx] == NULL || rmp->endp[midx] == NULL) {
    return QF_FAIL;
  }
  size_t len = (size_t)(rmp->endp[midx] - rmp->startp[midx]);
  len = MIN(len, CMDBUFFSIZE - 5);
  STRCPY(fields->pattern, "^\\V");
  xstrlcat(fields->pattern, rmp->startp[midx], len + 4);
  fields->pattern[len + 3] = '\\';
  fields->pattern[len + 4] = '$';
  fields->pattern[len + 5] = NUL;
  return QF_OK;
}

/// Parse the match for the module ('%o') pattern in regmatch.
/// Return the matched value in "fields->module".
static int qf_parse_fmt_o(regmatch_T *rmp, int midx, qffields_T *fields)
{
  if (rmp->startp[midx] == NULL || rmp->endp[midx] == NULL) {
    return QF_FAIL;
  }
  size_t len = (size_t)(rmp->endp[midx] - rmp->startp[midx]);
  size_t dsize = strlen(fields->module) + len + 1;
  dsize = MIN(dsize, CMDBUFFSIZE);
  xstrlcat(fields->module, rmp->startp[midx], dsize);
  return QF_OK;
}

/// 'errorformat' format pattern parser functions.
/// The '%f' and '%r' formats are parsed differently from other formats.
/// See qf_parse_match() for details.
/// Keep in sync with fmt_pat[].
static int (*qf_parse_fmt[FMT_PATTERNS])(regmatch_T *, int, qffields_T *) = {
  NULL,  // %f
  qf_parse_fmt_b,
  qf_parse_fmt_n,
  qf_parse_fmt_l,
  qf_parse_fmt_e,
  qf_parse_fmt_c,
  qf_parse_fmt_k,
  qf_parse_fmt_t,
  qf_parse_fmt_m,
  NULL,  // %r
  qf_parse_fmt_p,
  qf_parse_fmt_v,
  qf_parse_fmt_s,
  qf_parse_fmt_o
};

/// Parse the error format matches in 'regmatch' and set the values in 'fields'.
/// fmt_ptr contains the 'efm' format specifiers/prefixes that have a match.
/// Returns QF_OK if all the matches are successfully parsed. On failure,
/// returns QF_FAIL or QF_NOMEM.
static int qf_parse_match(char *linebuf, size_t linelen, efm_T *fmt_ptr, regmatch_T *regmatch,
                          qffields_T *fields, int qf_multiline, int qf_multiscan, char **tail)
{
  char idx = fmt_ptr->prefix;

  if ((idx == 'C' || idx == 'Z') && !qf_multiline) {
    return QF_FAIL;
  }
  if (vim_strchr("EWIN", (uint8_t)idx) != NULL) {
    fields->type = idx;
  } else {
    fields->type = 0;
  }

  // Extract error message data from matched line.
  // We check for an actual submatch, because "\[" and "\]" in
  // the 'errorformat' may cause the wrong submatch to be used.
  for (int i = 0; i < FMT_PATTERNS; i++) {
    int status = QF_OK;
    int midx = (int)fmt_ptr->addr[i];
    if (i == 0 && midx > 0) {  // %f
      status = qf_parse_fmt_f(regmatch, midx, fields, idx);
    } else if (i == FMT_PATTERN_M) {
      if (fmt_ptr->flags == '+' && !qf_multiscan) {  // %+
        status = copy_nonerror_line(linebuf, linelen, fields);
      } else if (midx > 0) {  // %m
        status = qf_parse_fmt_m(regmatch, midx, fields);
      }
    } else if (i == FMT_PATTERN_R && midx > 0) {  // %r
      status = qf_parse_fmt_r(regmatch, midx, tail);
    } else if (midx > 0) {  // others
      status = (qf_parse_fmt[i])(regmatch, midx, fields);
    }

    if (status != QF_OK) {
      return status;
    }
  }

  return QF_OK;
}

/// Parse an error line in 'linebuf' using a single error format string in
/// 'fmt_ptr->prog' and return the matching values in 'fields'.
/// Returns QF_OK if the efm format matches completely and the fields are
/// successfully copied. Otherwise returns QF_FAIL or QF_NOMEM.
static int qf_parse_get_fields(char *linebuf, size_t linelen, efm_T *fmt_ptr, qffields_T *fields,
                               int qf_multiline, int qf_multiscan, char **tail)
{
  if (qf_multiscan && vim_strchr("OPQ", (uint8_t)fmt_ptr->prefix) == NULL) {
    return QF_FAIL;
  }

  fields->namebuf[0] = NUL;
  fields->bnr = 0;
  fields->module[0] = NUL;
  fields->pattern[0] = NUL;
  if (!qf_multiscan) {
    fields->errmsg[0] = NUL;
  }
  fields->lnum = 0;
  fields->end_lnum = 0;
  fields->col = 0;
  fields->end_col = 0;
  fields->use_viscol = false;
  fields->enr = -1;
  fields->type = 0;
  *tail = NULL;

  regmatch_T regmatch;
  // Always ignore case when looking for a matching error.
  regmatch.rm_ic = true;
  regmatch.regprog = fmt_ptr->prog;
  bool r = vim_regexec(&regmatch, linebuf, 0);
  fmt_ptr->prog = regmatch.regprog;
  int status = QF_FAIL;
  if (r) {
    status = qf_parse_match(linebuf, linelen, fmt_ptr, &regmatch, fields,
                            qf_multiline, qf_multiscan, tail);
  }

  return status;
}

/// Parse directory error format prefixes (%D and %X).
/// Push and pop directories from the directory stack when scanning directory
/// names.
static int qf_parse_dir_pfx(int idx, qffields_T *fields, qf_list_T *qfl)
{
  if (idx == 'D') {  // enter directory
    if (*fields->namebuf == NUL) {
      emsg(_("E379: Missing or empty directory name"));
      return QF_FAIL;
    }
    qfl->qf_directory = qf_push_dir(fields->namebuf, &qfl->qf_dir_stack, false);
    if (qfl->qf_directory == NULL) {
      return QF_FAIL;
    }
  } else if (idx == 'X') {  // leave directory
    qfl->qf_directory = qf_pop_dir(&qfl->qf_dir_stack);
  }

  return QF_OK;
}

/// Parse global file name error format prefixes (%O, %P and %Q).
static int qf_parse_file_pfx(int idx, qffields_T *fields, qf_list_T *qfl, char *tail)
{
  fields->valid = false;
  if (*fields->namebuf == NUL || os_path_exists(fields->namebuf)) {
    if (*fields->namebuf && idx == 'P') {
      qfl->qf_currfile = qf_push_dir(fields->namebuf, &qfl->qf_file_stack, true);
    } else if (idx == 'Q') {
      qfl->qf_currfile = qf_pop_dir(&qfl->qf_file_stack);
    }
    *fields->namebuf = NUL;
    if (tail && *tail) {
      STRMOVE(IObuff, skipwhite(tail));
      qfl->qf_multiscan = true;
      return QF_MULTISCAN;
    }
  }

  return QF_OK;
}

/// Parse a non-error line (a line which doesn't match any of the error
/// format in 'efm').
static int qf_parse_line_nomatch(char *linebuf, size_t linelen, qffields_T *fields)
{
  fields->namebuf[0] = NUL;   // no match found, remove file name
  fields->lnum = 0;           // don't jump to this line
  fields->valid = false;

  return copy_nonerror_line(linebuf, linelen, fields);
}

/// Parse multi-line error format prefixes (%C and %Z)
static int qf_parse_multiline_pfx(int idx, qf_list_T *qfl, qffields_T *fields)
{
  if (!qfl->qf_multiignore) {
    qfline_T *qfprev = qfl->qf_last;

    if (qfprev == NULL) {
      return QF_FAIL;
    }
    if (*fields->errmsg) {
      size_t textlen = strlen(qfprev->qf_text);
      size_t errlen = strlen(fields->errmsg);
      qfprev->qf_text = xrealloc(qfprev->qf_text, textlen + errlen + 2);
      qfprev->qf_text[textlen] = '\n';
      STRCPY(qfprev->qf_text + textlen + 1, fields->errmsg);
    }
    if (qfprev->qf_nr == -1) {
      qfprev->qf_nr = fields->enr;
    }
    if (vim_isprintc(fields->type) && !qfprev->qf_type) {
      // only printable chars allowed
      qfprev->qf_type = fields->type;
    }

    if (!qfprev->qf_lnum) {
      qfprev->qf_lnum = fields->lnum;
    }
    if (!qfprev->qf_end_lnum) {
      qfprev->qf_end_lnum = fields->end_lnum;
    }
    if (!qfprev->qf_col) {
      qfprev->qf_col = fields->col;
      qfprev->qf_viscol = fields->use_viscol;
    }
    if (!qfprev->qf_end_col) {
      qfprev->qf_end_col = fields->end_col;
    }
    if (!qfprev->qf_fnum) {
      qfprev->qf_fnum = qf_get_fnum(qfl, qfl->qf_directory,
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
}

/// Queue location list stack delete request.
static void locstack_queue_delreq(qf_info_T *qi)
{
  qf_delq_T *q = xmalloc(sizeof(qf_delq_T));
  q->qi = qi;
  q->next = qf_delq_head;
  qf_delq_head = q;
}

/// Return the global quickfix stack window buffer number.
int qf_stack_get_bufnr(void)
{
  return ql_info.qf_bufnr;
}

/// Wipe the quickfix window buffer (if present) for the specified
/// quickfix/location list.
static void wipe_qf_buffer(qf_info_T *qi)
  FUNC_ATTR_NONNULL_ALL
{
  if (qi->qf_bufnr == INVALID_QFBUFNR) {
    return;
  }

  buf_T *const qfbuf = buflist_findnr(qi->qf_bufnr);
  if (qfbuf != NULL && qfbuf->b_nwindows == 0) {
    // If the quickfix buffer is not loaded in any window, then
    // wipe the buffer.
    close_buffer(NULL, qfbuf, DOBUF_WIPE, false, false);
    qi->qf_bufnr = INVALID_QFBUFNR;
  }
}

/// Free a location list stack
static void ll_free_all(qf_info_T **pqi)
{
  qf_info_T *qi = *pqi;
  if (qi == NULL) {
    return;
  }
  *pqi = NULL;          // Remove reference to this list

  // If the location list is still in use, then queue the delete request
  // to be processed later.
  if (quickfix_busy > 0) {
    locstack_queue_delreq(qi);
    return;
  }

  qi->qf_refcount--;
  if (qi->qf_refcount < 1) {
    // No references to this location list.
    // If the quickfix window buffer is loaded, then wipe it
    wipe_qf_buffer(qi);

    for (int i = 0; i < qi->qf_listcount; i++) {
      qf_free(qf_get_list(qi, i));
    }
    xfree(qi);
  }
}

/// Free all the quickfix/location lists in the stack.
void qf_free_all(win_T *wp)
{
  if (wp != NULL) {
    // location list
    ll_free_all(&wp->w_llist);
    ll_free_all(&wp->w_llist_ref);
  } else {
    // quickfix list
    qf_info_T *qi = &ql_info;
    for (int i = 0; i < qi->qf_listcount; i++) {
      qf_free(qf_get_list(qi, i));
    }
  }
}

/// Delay freeing of location list stacks when the quickfix code is running.
/// Used to avoid problems with autocmds freeing location list stacks when the
/// quickfix code is still referencing the stack.
/// Must always call decr_quickfix_busy() exactly once after this.
static void incr_quickfix_busy(void)
{
  quickfix_busy++;
}

/// Safe to free location list stacks. Process any delayed delete requests.
static void decr_quickfix_busy(void)
{
  quickfix_busy--;
  if (quickfix_busy == 0) {
    // No longer referencing the location lists. Process all the pending
    // delete requests.
    while (qf_delq_head != NULL) {
      qf_delq_T *q = qf_delq_head;

      qf_delq_head = q->next;
      ll_free_all(&q->qi);
      xfree(q);
    }
  }
#ifdef ABORT_ON_INTERNAL_ERROR
  if (quickfix_busy < 0) {
    emsg("quickfix_busy has become negative");
    abort();
  }
#endif
}

#if defined(EXITFREE)
void check_quickfix_busy(void)
{
  if (quickfix_busy != 0) {
    semsg("quickfix_busy not zero on exit: %" PRId64, (int64_t)quickfix_busy);
# ifdef ABORT_ON_INTERNAL_ERROR
    abort();
# endif
  }
}
#endif

/// Add an entry to the end of the list of errors.
///
/// @param  qfl      quickfix list entry
/// @param  dir      optional directory name
/// @param  fname    file name or NULL
/// @param  module   module name or NULL
/// @param  bufnum   buffer number or zero
/// @param  mesg     message
/// @param  lnum     line number
/// @param  end_lnum  line number for end
/// @param  col      column
/// @param  end_col  column for end
/// @param  vis_col  using visual column
/// @param  pattern  search pattern
/// @param  nr       error number
/// @param  type     type character
/// @param  user_data  custom user data or NULL
/// @param  valid    valid entry
///
/// @return  QF_OK on success or QF_FAIL on failure.
static int qf_add_entry(qf_list_T *qfl, char *dir, char *fname, char *module, int bufnum,
                        char *mesg, linenr_T lnum, linenr_T end_lnum, int col, int end_col,
                        char vis_col, char *pattern, int nr, char type, typval_T *user_data,
                        char valid)
{
  buf_T *buf;
  qfline_T *qfp = xmalloc(sizeof(qfline_T));
  char *fullname = NULL;
  char *p = NULL;

  if (bufnum != 0) {
    buf = buflist_findnr(bufnum);
    qfp->qf_fnum = bufnum;
    if (buf != NULL) {
      buf->b_has_qf_entry |=
        IS_QF_LIST(qfl) ? BUF_HAS_QF_ENTRY : BUF_HAS_LL_ENTRY;
    }
  } else {
    qfp->qf_fnum = qf_get_fnum(qfl, dir, fname);
    buf = buflist_findnr(qfp->qf_fnum);
  }
  if (fname != NULL) {
    fullname = fix_fname(fname);
  }
  qfp->qf_fname = NULL;
  if (buf != NULL && buf->b_ffname != NULL && fullname != NULL) {
    if (path_fnamecmp(fullname, buf->b_ffname) != 0) {
      p = path_try_shorten_fname(fullname);
      if (p != NULL) {
        qfp->qf_fname = xstrdup(p);
      }
    }
  }
  xfree(fullname);
  qfp->qf_text = xstrdup(mesg);
  qfp->qf_lnum = lnum;
  qfp->qf_end_lnum = end_lnum;
  qfp->qf_col = col;
  qfp->qf_end_col = end_col;
  qfp->qf_viscol = vis_col;
  if (user_data == NULL || user_data->v_type == VAR_UNKNOWN) {
    qfp->qf_user_data.v_type = VAR_UNKNOWN;
  } else {
    tv_copy(user_data, &qfp->qf_user_data);
    qfl->qf_has_user_data = true;
  }
  if (pattern == NULL || *pattern == NUL) {
    qfp->qf_pattern = NULL;
  } else {
    qfp->qf_pattern = xstrdup(pattern);
  }
  if (module == NULL || *module == NUL) {
    qfp->qf_module = NULL;
  } else {
    qfp->qf_module = xstrdup(module);
  }
  qfp->qf_nr = nr;
  if (type != 1 && !vim_isprintc(type)) {  // only printable chars allowed
    type = 0;
  }
  qfp->qf_type = type;
  qfp->qf_valid = valid;

  qfline_T **lastp = &qfl->qf_last;
  if (qf_list_empty(qfl)) {
    // first element in the list
    qfl->qf_start = qfp;
    qfl->qf_ptr = qfp;
    qfl->qf_index = 0;
    qfp->qf_prev = NULL;
  } else {
    assert(*lastp);
    qfp->qf_prev = *lastp;
    (*lastp)->qf_next = qfp;
  }
  qfp->qf_next = NULL;
  qfp->qf_cleared = false;
  *lastp = qfp;
  qfl->qf_count++;
  if (qfl->qf_index == 0 && qfp->qf_valid) {
    // first valid entry
    qfl->qf_index = qfl->qf_count;
    qfl->qf_ptr = qfp;
  }

  return QF_OK;
}

/// Allocate a new quickfix/location list stack
static qf_info_T *qf_alloc_stack(qfltype_T qfltype)
  FUNC_ATTR_NONNULL_RET
{
  qf_info_T *qi = xcalloc(1, sizeof(qf_info_T));
  qi->qf_refcount++;
  qi->qfl_type = qfltype;
  qi->qf_bufnr = INVALID_QFBUFNR;

  return qi;
}

/// Return the location list stack for window 'wp'.
/// If not present, allocate a location list stack
static qf_info_T *ll_get_or_alloc_list(win_T *wp)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  if (IS_LL_WINDOW(wp)) {
    // For a location list window, use the referenced location list
    return wp->w_llist_ref;
  }

  // For a non-location list window, w_llist_ref should not point to a
  // location list.
  ll_free_all(&wp->w_llist_ref);

  if (wp->w_llist == NULL) {
    wp->w_llist = qf_alloc_stack(QFLT_LOCATION);  // new location list
  }
  return wp->w_llist;
}

/// Get the quickfix/location list stack to use for the specified Ex command.
/// For a location list command, returns the stack for the current window.  If
/// the location list is not found, then returns NULL and prints an error
/// message if 'print_emsg' is true.
static qf_info_T *qf_cmd_get_stack(exarg_T *eap, bool print_emsg)
{
  qf_info_T *qi = &ql_info;

  if (is_loclist_cmd(eap->cmdidx)) {
    qi = GET_LOC_LIST(curwin);
    if (qi == NULL) {
      if (print_emsg) {
        emsg(_(e_loclist));
      }
      return NULL;
    }
  }

  return qi;
}

/// Get the quickfix/location list stack to use for the specified Ex command.
/// For a location list command, returns the stack for the current window.
/// If the location list is not present, then allocates a new one.
/// For a location list command, sets 'pwinp' to curwin.
static qf_info_T *qf_cmd_get_or_alloc_stack(const exarg_T *eap, win_T **pwinp)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  qf_info_T *qi = &ql_info;

  if (is_loclist_cmd(eap->cmdidx)) {
    qi = ll_get_or_alloc_list(curwin);
    *pwinp = curwin;
  }

  return qi;
}

/// Copy location list entries from 'from_qfl' to 'to_qfl'.
static int copy_loclist_entries(const qf_list_T *from_qfl, qf_list_T *to_qfl)
  FUNC_ATTR_NONNULL_ALL
{
  int i;
  qfline_T *from_qfp;

  // copy all the location entries in this list
  FOR_ALL_QFL_ITEMS(from_qfl, from_qfp, i) {
    if (qf_add_entry(to_qfl,
                     NULL,
                     NULL,
                     from_qfp->qf_module,
                     0,
                     from_qfp->qf_text,
                     from_qfp->qf_lnum,
                     from_qfp->qf_end_lnum,
                     from_qfp->qf_col,
                     from_qfp->qf_end_col,
                     from_qfp->qf_viscol,
                     from_qfp->qf_pattern,
                     from_qfp->qf_nr,
                     0,
                     &from_qfp->qf_user_data,
                     from_qfp->qf_valid) == QF_FAIL) {
      return FAIL;
    }

    // qf_add_entry() will not set the qf_num field, as the
    // directory and file names are not supplied. So the qf_fnum
    // field is copied here.
    qfline_T *const prevp = to_qfl->qf_last;
    prevp->qf_fnum = from_qfp->qf_fnum;  // file number
    prevp->qf_type = from_qfp->qf_type;  // error type
    if (from_qfl->qf_ptr == from_qfp) {
      to_qfl->qf_ptr = prevp;  // current location
    }
  }

  return OK;
}

/// Copy the specified location list 'from_qfl' to 'to_qfl'.
static int copy_loclist(qf_list_T *from_qfl, qf_list_T *to_qfl)
  FUNC_ATTR_NONNULL_ALL
{
  // Some of the fields are populated by qf_add_entry()
  to_qfl->qfl_type = from_qfl->qfl_type;
  to_qfl->qf_nonevalid = from_qfl->qf_nonevalid;
  to_qfl->qf_has_user_data = from_qfl->qf_has_user_data;
  to_qfl->qf_count = 0;
  to_qfl->qf_index = 0;
  to_qfl->qf_start = NULL;
  to_qfl->qf_last = NULL;
  to_qfl->qf_ptr = NULL;
  if (from_qfl->qf_title != NULL) {
    to_qfl->qf_title = xstrdup(from_qfl->qf_title);
  } else {
    to_qfl->qf_title = NULL;
  }
  if (from_qfl->qf_ctx != NULL) {
    to_qfl->qf_ctx = xcalloc(1, sizeof(*to_qfl->qf_ctx));
    tv_copy(from_qfl->qf_ctx, to_qfl->qf_ctx);
  } else {
    to_qfl->qf_ctx = NULL;
  }
  callback_copy(&to_qfl->qf_qftf_cb, &from_qfl->qf_qftf_cb);

  if (from_qfl->qf_count) {
    if (copy_loclist_entries(from_qfl, to_qfl) == FAIL) {
      return FAIL;
    }
  }

  to_qfl->qf_index = from_qfl->qf_index;  // current index in the list

  // Assign a new ID for the location list
  to_qfl->qf_id = ++last_qf_id;
  to_qfl->qf_changedtick = 0;

  // When no valid entries are present in the list, qf_ptr points to
  // the first item in the list
  if (to_qfl->qf_nonevalid) {
    to_qfl->qf_ptr = to_qfl->qf_start;
    to_qfl->qf_index = 1;
  }

  return OK;
}

// Copy the location list stack 'from' window to 'to' window.
void copy_loclist_stack(win_T *from, win_T *to)
  FUNC_ATTR_NONNULL_ALL
{
  // When copying from a location list window, copy the referenced
  // location list. For other windows, copy the location list for
  // that window.
  qf_info_T *qi = IS_LL_WINDOW(from) ? from->w_llist_ref : from->w_llist;

  if (qi == NULL) {                 // no location list to copy
    return;
  }

  // allocate a new location list
  to->w_llist = qf_alloc_stack(QFLT_LOCATION);

  to->w_llist->qf_listcount = qi->qf_listcount;

  // Copy the location lists one at a time
  for (int idx = 0; idx < qi->qf_listcount; idx++) {
    to->w_llist->qf_curlist = idx;

    if (copy_loclist(qf_get_list(qi, idx),
                     qf_get_list(to->w_llist, idx)) == FAIL) {
      qf_free_all(to);
      return;
    }
  }

  to->w_llist->qf_curlist = qi->qf_curlist;  // current list
}

/// Get buffer number for file "directory/fname".
/// Also sets the b_has_qf_entry flag.
static int qf_get_fnum(qf_list_T *qfl, char *directory, char *fname)
{
  char *ptr = NULL;
  char *bufname;
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
    ptr = concat_fnames(directory, fname, true);
    // Here we check if the file really exists.
    // This should normally be true, but if make works without
    // "leaving directory"-messages we might have missed a
    // directory change.
    if (!os_path_exists(ptr)) {
      xfree(ptr);
      directory = qf_guess_filepath(qfl, fname);
      if (directory) {
        ptr = concat_fnames(directory, fname, true);
      } else {
        ptr = xstrdup(fname);
      }
    }
    // Use concatenated directory name and file name.
    bufname = ptr;
  } else {
    bufname = fname;
  }

  if (qf_last_bufname != NULL
      && strcmp(bufname, qf_last_bufname) == 0
      && bufref_valid(&qf_last_bufref)) {
    buf = qf_last_bufref.br_buf;
    xfree(ptr);
  } else {
    xfree(qf_last_bufname);
    buf = buflist_new(bufname, NULL, 0, BLN_NOOPT);
    qf_last_bufname = (bufname == ptr) ? bufname : xstrdup(bufname);
    set_bufref(&qf_last_bufref, buf);
  }
  if (buf == NULL) {
    return 0;
  }
  buf->b_has_qf_entry =
    IS_QF_LIST(qfl) ? BUF_HAS_QF_ENTRY : BUF_HAS_LL_ENTRY;
  return buf->b_fnum;
}

// Push dirbuf onto the directory stack and return pointer to actual dir or
// NULL on error.
static char *qf_push_dir(char *dirbuf, struct dir_stack_T **stackptr, bool is_file_stack)
{
  struct dir_stack_T *ds_ptr;

  // allocate new stack element and hook it in
  struct dir_stack_T *ds_new = xmalloc(sizeof(struct dir_stack_T));

  ds_new->next = *stackptr;
  *stackptr = ds_new;

  // store directory on the stack
  if (vim_isAbsName(dirbuf)
      || (*stackptr)->next == NULL
      || is_file_stack) {
    (*stackptr)->dirname = xstrdup(dirbuf);
  } else {
    // Okay we don't have an absolute path.
    // dirbuf must be a subdir of one of the directories on the stack.
    // Let's search...
    ds_new = (*stackptr)->next;
    (*stackptr)->dirname = NULL;
    while (ds_new) {
      xfree((*stackptr)->dirname);
      (*stackptr)->dirname = concat_fnames(ds_new->dirname, dirbuf, true);
      if (os_isdir((*stackptr)->dirname)) {
        break;
      }

      ds_new = ds_new->next;
    }

    // clean up all dirs we already left
    while ((*stackptr)->next != ds_new) {
      ds_ptr = (*stackptr)->next;
      (*stackptr)->next = (*stackptr)->next->next;
      xfree(ds_ptr->dirname);
      xfree(ds_ptr);
    }

    // Nothing found -> it must be on top level
    if (ds_new == NULL) {
      xfree((*stackptr)->dirname);
      (*stackptr)->dirname = xstrdup(dirbuf);
    }
  }

  if ((*stackptr)->dirname != NULL) {
    return (*stackptr)->dirname;
  }
  ds_ptr = *stackptr;
  *stackptr = (*stackptr)->next;
  xfree(ds_ptr);
  return NULL;
}

// pop dirbuf from the directory stack and return previous directory or NULL if
// stack is empty
static char *qf_pop_dir(struct dir_stack_T **stackptr)
{
  // TODO(vim): Should we check if dirbuf is the directory on top of the stack?
  // What to do if it isn't?

  // pop top element and free it
  if (*stackptr != NULL) {
    struct dir_stack_T *ds_ptr = *stackptr;
    *stackptr = (*stackptr)->next;
    xfree(ds_ptr->dirname);
    xfree(ds_ptr);
  }

  // return NEW top element as current dir or NULL if stack is empty
  return *stackptr ? (*stackptr)->dirname : NULL;
}

// clean up directory stack
static void qf_clean_dir_stack(struct dir_stack_T **stackptr)
{
  struct dir_stack_T *ds_ptr;

  while ((ds_ptr = *stackptr) != NULL) {
    *stackptr = (*stackptr)->next;
    xfree(ds_ptr->dirname);
    xfree(ds_ptr);
  }
}

/// Check in which directory of the directory stack the given file can be
/// found.
/// Returns a pointer to the directory name or NULL if not found.
/// Cleans up intermediate directory entries.
///
/// TODO(vim): How to solve the following problem?
/// If we have this directory tree:
///     ./
///     ./aa
///     ./aa/bb
///     ./bb
///     ./bb/x.c
/// and make says:
///     making all in aa
///     making all in bb
///     x.c:9: Error
/// Then qf_push_dir thinks we are in ./aa/bb, but we are in ./bb.
/// qf_guess_filepath will return NULL.
static char *qf_guess_filepath(qf_list_T *qfl, char *filename)
{
  // no dirs on the stack - there's nothing we can do
  if (qfl->qf_dir_stack == NULL) {
    return NULL;
  }

  struct dir_stack_T *ds_ptr = qfl->qf_dir_stack->next;
  char *fullname = NULL;
  while (ds_ptr) {
    xfree(fullname);
    fullname = concat_fnames(ds_ptr->dirname, filename, true);

    if (os_path_exists(fullname)) {
      break;
    }

    ds_ptr = ds_ptr->next;
  }

  xfree(fullname);

  // clean up all dirs we already left
  while (qfl->qf_dir_stack->next != ds_ptr) {
    struct dir_stack_T *ds_tmp = qfl->qf_dir_stack->next;
    qfl->qf_dir_stack->next = qfl->qf_dir_stack->next->next;
    xfree(ds_tmp->dirname);
    xfree(ds_tmp);
  }

  return ds_ptr == NULL ? NULL : ds_ptr->dirname;
}

/// Returns true, if a quickfix/location list with the given identifier exists.
static bool qflist_valid(win_T *wp, unsigned qf_id)
{
  qf_info_T *qi = &ql_info;

  if (wp) {
    if (!win_valid(wp)) {
      return false;
    }
    qi = GET_LOC_LIST(wp);  // Location list
    if (!qi) {
      return false;
    }
  }

  for (int i = 0; i < qi->qf_listcount; i++) {
    if (qi->qf_lists[i].qf_id == qf_id) {
      return true;
    }
  }

  return false;
}

/// When loading a file from the quickfix, the autocommands may modify it.
/// This may invalidate the current quickfix entry.  This function checks
/// whether an entry is still present in the quickfix list.
/// Similar to location list.
static bool is_qf_entry_present(qf_list_T *qfl, qfline_T *qf_ptr)
{
  qfline_T *qfp;
  int i;

  // Search for the entry in the current list
  FOR_ALL_QFL_ITEMS(qfl, qfp, i) {
    if (qfp == qf_ptr) {
      break;
    }
  }

  if (i > qfl->qf_count) {  // Entry is not found
    return false;
  }

  return true;
}

/// Get the next valid entry in the current quickfix/location list. The search
/// starts from the current entry. Returns NULL on failure.
static qfline_T *get_next_valid_entry(qf_list_T *qfl, qfline_T *qf_ptr, int *qf_index, int dir)
{
  int idx = *qf_index;
  int old_qf_fnum = qf_ptr->qf_fnum;

  do {
    if (idx == qfl->qf_count || qf_ptr->qf_next == NULL) {
      return NULL;
    }
    idx++;
    qf_ptr = qf_ptr->qf_next;
  } while ((!qfl->qf_nonevalid && !qf_ptr->qf_valid)
           || (dir == FORWARD_FILE && qf_ptr->qf_fnum == old_qf_fnum));

  *qf_index = idx;
  return qf_ptr;
}

/// Get the previous valid entry in the current quickfix/location list. The
/// search starts from the current entry. Returns NULL on failure.
static qfline_T *get_prev_valid_entry(qf_list_T *qfl, qfline_T *qf_ptr, int *qf_index, int dir)
{
  int idx = *qf_index;
  int old_qf_fnum = qf_ptr->qf_fnum;

  do {
    if (idx == 1 || qf_ptr->qf_prev == NULL) {
      return NULL;
    }
    idx--;
    qf_ptr = qf_ptr->qf_prev;
  } while ((!qfl->qf_nonevalid && !qf_ptr->qf_valid)
           || (dir == BACKWARD_FILE && qf_ptr->qf_fnum == old_qf_fnum));

  *qf_index = idx;
  return qf_ptr;
}

/// Get the n'th (errornr) previous/next valid entry from the current entry in
/// the quickfix list.
///   dir == FORWARD or FORWARD_FILE: next valid entry
///   dir == BACKWARD or BACKWARD_FILE: previous valid entry
static qfline_T *get_nth_valid_entry(qf_list_T *qfl, int errornr, int dir, int *new_qfidx)
{
  qfline_T *qf_ptr = qfl->qf_ptr;
  int qf_idx = qfl->qf_index;
  const char *err = e_no_more_items;

  while (errornr--) {
    qfline_T *prev_qf_ptr = qf_ptr;
    int prev_index = qf_idx;

    if (dir == FORWARD || dir == FORWARD_FILE) {
      qf_ptr = get_next_valid_entry(qfl, qf_ptr, &qf_idx, dir);
    } else {
      qf_ptr = get_prev_valid_entry(qfl, qf_ptr, &qf_idx, dir);
    }

    if (qf_ptr == NULL) {
      qf_ptr = prev_qf_ptr;
      qf_idx = prev_index;
      if (err != NULL) {
        emsg(_(err));
        return NULL;
      }
      break;
    }

    err = NULL;
  }

  *new_qfidx = qf_idx;
  return qf_ptr;
}

/// Get n'th (errornr) quickfix entry from the current entry in the quickfix
/// list 'qfl'. Returns a pointer to the new entry and the index in 'new_qfidx'
static qfline_T *get_nth_entry(qf_list_T *qfl, int errornr, int *new_qfidx)
{
  qfline_T *qf_ptr = qfl->qf_ptr;
  int qf_idx = qfl->qf_index;

  // New error number is less than the current error number
  while (errornr < qf_idx && qf_idx > 1 && qf_ptr->qf_prev != NULL) {
    qf_idx--;
    qf_ptr = qf_ptr->qf_prev;
  }

  // New error number is greater than the current error number
  while (errornr > qf_idx
         && qf_idx < qfl->qf_count
         && qf_ptr->qf_next != NULL) {
    qf_idx++;
    qf_ptr = qf_ptr->qf_next;
  }

  *new_qfidx = qf_idx;
  return qf_ptr;
}

/// Get a entry specified by 'errornr' and 'dir' from the current
/// quickfix/location list. 'errornr' specifies the index of the entry and 'dir'
/// specifies the direction (FORWARD/BACKWARD/FORWARD_FILE/BACKWARD_FILE).
/// Returns a pointer to the entry and the index of the new entry is stored in
/// 'new_qfidx'.
static qfline_T *qf_get_entry(qf_list_T *qfl, int errornr, int dir, int *new_qfidx)
{
  qfline_T *qf_ptr = qfl->qf_ptr;
  int qfidx = qfl->qf_index;

  if (dir != 0) {  // next/prev valid entry
    qf_ptr = get_nth_valid_entry(qfl, errornr, dir, &qfidx);
  } else if (errornr != 0) {  // go to specified number
    qf_ptr = get_nth_entry(qfl, errornr, &qfidx);
  }

  *new_qfidx = qfidx;
  return qf_ptr;
}

// Find a window displaying a Vim help file in the current tab page.
static win_T *qf_find_help_win(void)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (bt_help(wp->w_buffer)) {
      return wp;
    }
  }
  return NULL;
}

/// Set the location list for the specified window to 'qi'.
static void win_set_loclist(win_T *wp, qf_info_T *qi)
{
  wp->w_llist = qi;
  qi->qf_refcount++;
}

/// Find a help window or open one. If 'newwin' is true, then open a new help
/// window.
static int jump_to_help_window(qf_info_T *qi, bool newwin, bool *opened_window)
{
  win_T *wp = (cmdmod.cmod_tab != 0 || newwin) ? NULL : qf_find_help_win();

  if (wp != NULL && wp->w_buffer->b_nwindows > 0) {
    win_enter(wp, true);
  } else {
    // Split off help window; put it at far top if no position
    // specified, the current window is vertically split and narrow.
    int flags = WSP_HELP;
    if (cmdmod.cmod_split == 0
        && curwin->w_width != Columns
        && curwin->w_width < 80) {
      flags |= WSP_TOP;
    }

    // If the user asks to open a new window, then copy the location list.
    // Otherwise, don't copy the location list.
    if (IS_LL_STACK(qi) && !newwin) {
      flags |= WSP_NEWLOC;
    }

    if (win_split(0, flags) == FAIL) {
      return FAIL;
    }

    *opened_window = true;

    if (curwin->w_height < p_hh) {
      win_setheight((int)p_hh);
    }

    // When using location list, the new window should use the supplied
    // location list. If the user asks to open a new window, then the new
    // window will get a copy of the location list.
    if (IS_LL_STACK(qi) && !newwin) {
      win_set_loclist(curwin, qi);
    }
  }

  restart_edit = 0;  // don't want insert mode in help file

  return OK;
}

/// Find a non-quickfix window using the given location list stack in the
/// current tabpage.
/// Returns NULL if a matching window is not found.
static win_T *qf_find_win_with_loclist(const qf_info_T *ll)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_llist == ll && !bt_quickfix(wp->w_buffer)) {
      return wp;
    }
  }
  return NULL;
}

/// Find a window containing a normal buffer in the current tab page.
static win_T *qf_find_win_with_normal_buf(void)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (bt_normal(wp->w_buffer)) {
      return wp;
    }
  }
  return NULL;
}

// Go to a window in any tabpage containing the specified file.  Returns true
// if successfully jumped to the window. Otherwise returns false.
static bool qf_goto_tabwin_with_file(int fnum)
{
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->w_buffer->b_fnum == fnum) {
      goto_tabpage_win(tp, wp);
      return true;
    }
  }
  return false;
}

// Create a new window to show a file above the quickfix window. Called when
// only the quickfix window is present.
static int qf_open_new_file_win(qf_info_T *ll_ref)
{
  int flags = WSP_ABOVE;
  if (ll_ref != NULL) {
    flags |= WSP_NEWLOC;
  }
  if (win_split(0, flags) == FAIL) {
    return FAIL;  // not enough room for window
  }
  p_swb = empty_string_option;  // don't split again
  swb_flags = 0;
  RESET_BINDING(curwin);
  if (ll_ref != NULL) {
    // The new window should use the location list from the
    // location list window
    win_set_loclist(curwin, ll_ref);
  }
  return OK;
}

// Go to a window that shows the right buffer. If the window is not found, go
// to the window just above the location list window. This is used for opening
// a file from a location window and not from a quickfix window. If some usable
// window is previously found, then it is supplied in 'use_win'.
static void qf_goto_win_with_ll_file(win_T *use_win, int qf_fnum, qf_info_T *ll_ref)
{
  win_T *win = use_win;

  if (win == NULL) {
    // Find the window showing the selected file in the current tab page.
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
        if (bt_normal(win->w_buffer)) {
          break;
        }
        if (win->w_prev == NULL) {
          win = lastwin;      // wrap around the top
        } else {
          win = win->w_prev;  // go to previous window
        }
      } while (win != curwin);
    }
  }
  win_goto(win);

  // If the location list for the window is not set, then set it
  // to the location list from the location window
  if (win->w_llist == NULL && ll_ref != NULL) {
    // The new window should use the location list from the
    // location list window
    win_set_loclist(win, ll_ref);
  }
}

// Go to a window that shows the specified file. If a window is not found, go
// to the window just above the quickfix window. This is used for opening a
// file from a quickfix window and not from a location window.
static void qf_goto_win_with_qfl_file(int qf_fnum)
{
  win_T *win = curwin;
  win_T *altwin = NULL;
  while (true) {
    if (win->w_buffer->b_fnum == qf_fnum) {
      break;
    }
    if (win->w_prev == NULL) {
      win = lastwin;      // wrap around the top
    } else {
      win = win->w_prev;  // go to previous window
    }

    if (IS_QF_WINDOW(win)) {
      // Didn't find it, go to the window before the quickfix
      // window, unless 'switchbuf' contains 'uselast': in this case we
      // try to jump to the previously used window first.
      if ((swb_flags & kOptSwbFlagUselast) && win_valid(prevwin)
          && !prevwin->w_p_wfb) {
        win = prevwin;
      } else if (altwin != NULL) {
        win = altwin;
      } else if (curwin->w_prev != NULL) {
        win = curwin->w_prev;
      } else {
        win = curwin->w_next;
      }
      break;
    }

    // Remember a usable window.
    if (altwin == NULL
        && !win->w_p_pvw
        && !win->w_p_wfb
        && bt_normal(win->w_buffer)) {
      altwin = win;
    }
  }

  win_goto(win);
}

// Find a suitable window for opening a file (qf_fnum) from the
// quickfix/location list and jump to it.  If the file is already opened in a
// window, jump to it. Otherwise open a new window to display the file. If
// 'newwin' is true, then always open a new window. This is called from either
// a quickfix or a location list window.
static int qf_jump_to_usable_window(int qf_fnum, bool newwin, bool *opened_window)
{
  win_T *usable_wp = NULL;
  bool usable_win = false;

  // If opening a new window, then don't use the location list referred by
  // the current window.  Otherwise two windows will refer to the same
  // location list.
  qf_info_T *ll_ref = newwin ? NULL : curwin->w_llist_ref;
  if (ll_ref != NULL) {
    // Find a non-quickfix window with this location list
    usable_wp = qf_find_win_with_loclist(ll_ref);
    if (usable_wp != NULL) {
      usable_win = true;
    }
  }

  if (!usable_win) {
    // Locate a window showing a normal buffer
    win_T *win = qf_find_win_with_normal_buf();
    if (win != NULL) {
      usable_win = true;
    }
  }

  // If no usable window is found and 'switchbuf' contains "usetab"
  // then search in other tabs.
  if (!usable_win && (swb_flags & kOptSwbFlagUsetab)) {
    usable_win = qf_goto_tabwin_with_file(qf_fnum);
  }

  // If there is only one window and it is the quickfix window, create a
  // new one above the quickfix window.
  if ((ONE_WINDOW && bt_quickfix(curbuf)) || !usable_win || newwin) {
    if (qf_open_new_file_win(ll_ref) != OK) {
      return FAIL;
    }
    *opened_window = true;  // close it when fail
  } else {
    if (curwin->w_llist_ref != NULL) {  // In a location window
      qf_goto_win_with_ll_file(usable_wp, qf_fnum, ll_ref);
    } else {  // In a quickfix window
      qf_goto_win_with_qfl_file(qf_fnum);
    }
  }

  return OK;
}

/// Edit the selected file or help file.
/// @return  OK if successfully edited the file.
///          FAIL on failing to open the buffer.
///          QF_ABORT if the quickfix/location list was freed by an autocmd
///          when opening the buffer.
static int qf_jump_edit_buffer(qf_info_T *qi, qfline_T *qf_ptr, int forceit, int prev_winid,
                               bool *opened_window)
{
  qf_list_T *qfl = qf_get_curlist(qi);
  int old_changetick = qfl->qf_changedtick;
  int old_qf_curlist = qi->qf_curlist;
  qfltype_T qfl_type = qfl->qfl_type;
  int retval = OK;
  unsigned save_qfid = qfl->qf_id;

  if (qf_ptr->qf_type == 1) {
    // Open help file (do_ecmd() will set b_help flag, readfile() will
    // set b_p_ro flag).
    if (!can_abandon(curbuf, forceit)) {
      no_write_message();
      return FAIL;
    }
    retval = do_ecmd(qf_ptr->qf_fnum, NULL, NULL, NULL, 1,
                     ECMD_HIDE + ECMD_SET_HELP,
                     prev_winid == curwin->handle ? curwin : NULL);
  } else {
    int fnum = qf_ptr->qf_fnum;

    if (!forceit && curwin->w_p_wfb && curbuf->b_fnum != fnum) {
      if (qi->qfl_type == QFLT_LOCATION) {
        // Location lists cannot split or reassign their window
        // so 'winfixbuf' windows must fail
        emsg(_(e_winfixbuf_cannot_go_to_buffer));
        return FAIL;
      }

      if (win_valid(prevwin) && !prevwin->w_p_wfb
          && !bt_quickfix(prevwin->w_buffer)) {
        // 'winfixbuf' is set; attempt to change to a window without it
        // that isn't a quickfix/location list window.
        win_goto(prevwin);
      }
      if (curwin->w_p_wfb) {
        // Split the window, which will be 'nowinfixbuf', and set curwin
        // to that
        if (win_split(0, 0) == OK) {
          *opened_window = true;
        }
        if (curwin->w_p_wfb) {
          // Autocommands set 'winfixbuf' or sent us to another window
          // with it set, or we failed to split the window.  Give up,
          // but don't return immediately, as they may have messed
          // with the list.
          emsg(_(e_winfixbuf_cannot_go_to_buffer));
          retval = FAIL;
        }
      }
    }

    if (retval == OK) {
      retval = buflist_getfile(fnum, 1,
                               GETF_SETMARK | GETF_SWITCH, forceit);
    }
  }
  // If a location list, check whether the associated window is still
  // present.
  if (qfl_type == QFLT_LOCATION) {
    win_T *wp = win_id2wp(prev_winid);

    if (wp == NULL && curwin->w_llist != qi) {
      emsg(_("E924: Current window was closed"));
      *opened_window = false;
      return QF_ABORT;
    }
  }

  if (qfl_type == QFLT_QUICKFIX && !qflist_valid(NULL, save_qfid)) {
    emsg(_(e_current_quickfix_list_was_changed));
    return QF_ABORT;
  }

  if (old_qf_curlist != qi->qf_curlist
      || old_changetick != qfl->qf_changedtick
      || !is_qf_entry_present(qfl, qf_ptr)) {
    if (qfl_type == QFLT_QUICKFIX) {
      emsg(_(e_current_quickfix_list_was_changed));
    } else {
      emsg(_(e_current_location_list_was_changed));
    }
    return QF_ABORT;
  }

  return retval;
}

/// Go to the error line in the current file using either line/column number or
/// a search pattern.
static void qf_jump_goto_line(linenr_T qf_lnum, int qf_col, char qf_viscol, char *qf_pattern)
{
  if (qf_pattern == NULL) {
    // Go to line with error, unless qf_lnum is 0.
    linenr_T i = qf_lnum;
    if (i > 0) {
      i = MIN(i, curbuf->b_ml.ml_line_count);
      curwin->w_cursor.lnum = i;
    }
    if (qf_col > 0) {
      curwin->w_cursor.coladd = 0;
      if (qf_viscol == true) {
        coladvance(curwin, qf_col - 1);
      } else {
        curwin->w_cursor.col = qf_col - 1;
      }
      curwin->w_set_curswant = true;
      check_cursor(curwin);
    } else {
      beginline(BL_WHITE | BL_FIX);
    }
  } else {
    // Move the cursor to the first line in the buffer
    pos_T save_cursor = curwin->w_cursor;
    curwin->w_cursor.lnum = 0;
    if (!do_search(NULL, '/', '/', qf_pattern, strlen(qf_pattern), 1, SEARCH_KEEP, NULL)) {
      curwin->w_cursor = save_cursor;
    }
  }
}

/// Display quickfix list index and size message
static void qf_jump_print_msg(qf_info_T *qi, int qf_index, qfline_T *qf_ptr, buf_T *old_curbuf,
                              linenr_T old_lnum)
{
  garray_T *const gap = qfga_get();

  // Update the screen before showing the message, unless messages scrolled.
  if (!msg_scrolled) {
    update_topline(curwin);
    if (must_redraw) {
      update_screen();
    }
  }
  vim_snprintf(IObuff, IOSIZE, _("(%d of %d)%s%s: "), qf_index,
               qf_get_curlist(qi)->qf_count,
               qf_ptr->qf_cleared ? _(" (line deleted)") : "",
               qf_types(qf_ptr->qf_type, qf_ptr->qf_nr));
  // Add the message, skipping leading whitespace and newlines.
  ga_concat(gap, IObuff);
  qf_fmt_text(gap, skipwhite(qf_ptr->qf_text));
  ga_append(gap, NUL);

  // Output the message.  Overwrite to avoid scrolling when the 'O'
  // flag is present in 'shortmess'; But when not jumping, print the
  // whole message.
  linenr_T i = msg_scroll;
  if (curbuf == old_curbuf && curwin->w_cursor.lnum == old_lnum) {
    msg_scroll = true;
  } else if ((msg_scrolled == 0 || (p_ch == 0 && msg_scrolled == 1))
             && shortmess(SHM_OVERALL)) {
    msg_scroll = false;
  }
  msg_ext_set_kind("quickfix");
  msg_keep(gap->ga_data, 0, true, false);
  msg_scroll = (int)i;

  qfga_clear();
}

/// Find a usable window for opening a file from the quickfix/location list. If
/// a window is not found then open a new window. If 'newwin' is true, then open
/// a new window.
/// @return  OK if successfully jumped or opened a window.
///          FAIL if not able to jump/open a window.
///          NOTDONE if a file is not associated with the entry.
///          QF_ABORT if the quickfix/location list was modified by an autocmd.
static int qf_jump_open_window(qf_info_T *qi, qfline_T *qf_ptr, bool newwin, bool *opened_window)
{
  qf_list_T *qfl = qf_get_curlist(qi);
  int old_changetick = qfl->qf_changedtick;
  int old_qf_curlist = qi->qf_curlist;
  qfltype_T qfl_type = qfl->qfl_type;

  // For ":helpgrep" find a help window or open one.
  if (qf_ptr->qf_type == 1 && (!bt_help(curwin->w_buffer) || cmdmod.cmod_tab != 0)) {
    if (jump_to_help_window(qi, newwin, opened_window) == FAIL) {
      return FAIL;
    }
  }
  if (old_qf_curlist != qi->qf_curlist
      || old_changetick != qfl->qf_changedtick
      || !is_qf_entry_present(qfl, qf_ptr)) {
    if (qfl_type == QFLT_QUICKFIX) {
      emsg(_(e_current_quickfix_list_was_changed));
    } else {
      emsg(_(e_current_location_list_was_changed));
    }
    return QF_ABORT;
  }

  // If currently in the quickfix window, find another window to show the
  // file in.
  if (bt_quickfix(curbuf) && !*opened_window) {
    // If there is no file specified, we don't know where to go.
    // But do advance, otherwise ":cn" gets stuck.
    if (qf_ptr->qf_fnum == 0) {
      return NOTDONE;
    }

    if (qf_jump_to_usable_window(qf_ptr->qf_fnum, newwin, opened_window)
        == FAIL) {
      return FAIL;
    }
  }
  if (old_qf_curlist != qi->qf_curlist
      || old_changetick != qfl->qf_changedtick
      || !is_qf_entry_present(qfl, qf_ptr)) {
    if (qfl_type == QFLT_QUICKFIX) {
      emsg(_(e_current_quickfix_list_was_changed));
    } else {
      emsg(_(e_current_location_list_was_changed));
    }
    return QF_ABORT;
  }

  return OK;
}

/// Edit a selected file from the quickfix/location list and jump to a
/// particular line/column, adjust the folds and display a message about the
/// jump.
/// @return  OK on success and FAIL on failing to open the file/buffer.
///          QF_ABORT if the quickfix/location list is freed by an autocmd when opening
///          the file.
static int qf_jump_to_buffer(qf_info_T *qi, int qf_index, qfline_T *qf_ptr, int forceit,
                             int prev_winid, bool *opened_window, int openfold, bool print_message)
{
  // If there is a file name, read the wanted file if needed, and check
  // autowrite etc.
  buf_T *old_curbuf = curbuf;
  linenr_T old_lnum = curwin->w_cursor.lnum;
  int retval = OK;

  if (qf_ptr->qf_fnum != 0) {
    retval = qf_jump_edit_buffer(qi, qf_ptr, forceit, prev_winid,
                                 opened_window);
    if (retval != OK) {
      return retval;
    }
  }

  // When not switched to another buffer, still need to set pc mark
  if (curbuf == old_curbuf) {
    setpcmark();
  }

  qf_jump_goto_line(qf_ptr->qf_lnum, qf_ptr->qf_col, qf_ptr->qf_viscol, qf_ptr->qf_pattern);

  if ((fdo_flags & kOptFdoFlagQuickfix) && openfold) {
    foldOpenCursor();
  }
  if (print_message) {
    qf_jump_print_msg(qi, qf_index, qf_ptr, old_curbuf, old_lnum);
  }

  return retval;
}

/// Jump to a quickfix line and try to use an existing window.
void qf_jump(qf_info_T *qi, int dir, int errornr, int forceit)
{
  qf_jump_newwin(qi, dir, errornr, forceit, false);
}

// Jump to a quickfix line.
// If dir == 0 go to entry "errornr".
// If dir == FORWARD go "errornr" valid entries forward.
// If dir == BACKWARD go "errornr" valid entries backward.
// If dir == FORWARD_FILE go "errornr" valid entries files backward.
// If dir == BACKWARD_FILE go "errornr" valid entries files backward
// else if "errornr" is zero, redisplay the same line
// If 'forceit' is true, then can discard changes to the current buffer.
// If 'newwin' is true, then open the file in a new window.
static void qf_jump_newwin(qf_info_T *qi, int dir, int errornr, int forceit, bool newwin)
{
  char *old_swb = p_swb;
  unsigned old_swb_flags = swb_flags;
  const bool old_KeyTyped = KeyTyped;           // getting file may reset it

  if (qi == NULL) {
    qi = &ql_info;
  }

  if (qf_stack_empty(qi) || qf_list_empty(qf_get_curlist(qi))) {
    emsg(_(e_no_errors));
    return;
  }

  incr_quickfix_busy();

  qf_list_T *qfl = qf_get_curlist(qi);

  qfline_T *qf_ptr = qfl->qf_ptr;
  qfline_T *old_qf_ptr = qf_ptr;
  int qf_index = qfl->qf_index;
  int old_qf_index = qf_index;

  qf_ptr = qf_get_entry(qfl, errornr, dir, &qf_index);
  if (qf_ptr == NULL) {
    qf_ptr = old_qf_ptr;
    qf_index = old_qf_index;
    goto theend;
  }

  qfl->qf_index = qf_index;
  qfl->qf_ptr = qf_ptr;

  // No need to print the error message if it's visible in the error window
  bool print_message = !qf_win_pos_update(qi, old_qf_index);

  int prev_winid = curwin->handle;

  bool opened_window = false;
  int retval = qf_jump_open_window(qi, qf_ptr, newwin, &opened_window);
  if (retval == FAIL) {
    goto failed;
  }
  if (retval == QF_ABORT) {
    qi = NULL;
    qf_ptr = NULL;
    goto theend;
  }
  if (retval == NOTDONE) {
    goto theend;
  }

  retval = qf_jump_to_buffer(qi, qf_index, qf_ptr, forceit, prev_winid,
                             &opened_window, old_KeyTyped, print_message);
  if (retval == QF_ABORT) {
    // Quickfix/location list was modified by an autocmd
    qi = NULL;
    qf_ptr = NULL;
  }

  if (retval != OK) {
    if (opened_window) {
      win_close(curwin, true, false);          // Close opened window
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
    qfl->qf_ptr = qf_ptr;
    qfl->qf_index = qf_index;
  }
  if (p_swb != old_swb && p_swb == empty_string_option) {
    // Restore old 'switchbuf' value, but not when an autocommand or
    // modeline has changed the value.
    p_swb = old_swb;
    swb_flags = old_swb_flags;
  }
  decr_quickfix_busy();
}

// Highlight ids used for displaying entries from the quickfix list.
static int qfFile_hl_id;
static int qfSep_hl_id;
static int qfLine_hl_id;

/// Display information about a single entry from the quickfix/location list.
/// Used by ":clist/:llist" commands.
/// 'cursel' will be set to true for the currently selected entry in the
/// quickfix list.
static void qf_list_entry(qfline_T *qfp, int qf_idx, bool cursel)
{
  char *fname = NULL;
  if (qfp->qf_module != NULL && *qfp->qf_module != NUL) {
    vim_snprintf(IObuff, IOSIZE, "%2d %s", qf_idx, qfp->qf_module);
  } else {
    buf_T *buf;
    if (qfp->qf_fnum != 0
        && (buf = buflist_findnr(qfp->qf_fnum)) != NULL) {
      fname = qfp->qf_fname == NULL ? buf->b_fname : qfp->qf_fname;
      if (qfp->qf_type == 1) {  // :helpgrep
        fname = path_tail(fname);
      }
    }
    if (fname == NULL) {
      snprintf(IObuff, IOSIZE, "%2d", qf_idx);
    } else {
      vim_snprintf(IObuff, IOSIZE, "%2d %s", qf_idx, fname);
    }
  }

  // Support for filtering entries using :filter /pat/ clist
  // Match against the module name, file name, search pattern and
  // text of the entry.
  bool filter_entry = true;
  if (qfp->qf_module != NULL && *qfp->qf_module != NUL) {
    filter_entry &= message_filtered(qfp->qf_module);
  }
  if (filter_entry && fname != NULL) {
    filter_entry &= message_filtered(fname);
  }
  if (filter_entry && qfp->qf_pattern != NULL) {
    filter_entry &= message_filtered(qfp->qf_pattern);
  }
  if (filter_entry) {
    filter_entry &= message_filtered(qfp->qf_text);
  }
  if (filter_entry) {
    return;
  }

  msg_putchar('\n');
  msg_outtrans(IObuff, cursel ? HLF_QFL : qfFile_hl_id, false);

  if (qfp->qf_lnum != 0) {
    msg_puts_hl(":", qfSep_hl_id, false);
  }
  garray_T *gap = qfga_get();
  if (qfp->qf_lnum != 0) {
    qf_range_text(gap, qfp);
  }
  ga_concat(gap, qf_types(qfp->qf_type, qfp->qf_nr));
  ga_append(gap, NUL);
  msg_puts_hl(gap->ga_data, qfLine_hl_id, false);
  msg_puts_hl(":", qfSep_hl_id, false);
  if (qfp->qf_pattern != NULL) {
    gap = qfga_get();
    qf_fmt_text(gap, qfp->qf_pattern);
    ga_append(gap, NUL);
    msg_puts(gap->ga_data);
    msg_puts_hl(":", qfSep_hl_id, false);
  }
  msg_puts(" ");

  // Remove newlines and leading whitespace from the text.  For an
  // unrecognized line keep the indent, the compiler may mark a word
  // with ^^^^.
  gap = qfga_get();
  qf_fmt_text(gap, (fname != NULL || qfp->qf_lnum != 0) ? skipwhite(qfp->qf_text) : qfp->qf_text);
  ga_append(gap, NUL);
  msg_prt_line(gap->ga_data, false);
}

// ":clist": list all errors
// ":llist": list all locations
void qf_list(exarg_T *eap)
{
  char *arg = eap->arg;
  int all = eap->forceit;     // if not :cl!, only show recognised errors
  qf_info_T *qi = qf_cmd_get_stack(eap, true);

  if (qi == NULL) {
    return;
  }

  if (qf_stack_empty(qi) || qf_list_empty(qf_get_curlist(qi))) {
    emsg(_(e_no_errors));
    return;
  }

  bool plus = false;
  if (*arg == '+') {
    arg++;
    plus = true;
  }
  int idx1 = 1;
  int idx2 = -1;
  if (!get_list_range(&arg, &idx1, &idx2) || *arg != NUL) {
    semsg(_(e_trailing_arg), arg);
    return;
  }
  qf_list_T *qfl = qf_get_curlist(qi);
  int i;
  if (plus) {
    i = qfl->qf_index;
    idx2 = i + idx1;
    idx1 = i;
  } else {
    i = qfl->qf_count;
    if (idx1 < 0) {
      idx1 = (-idx1 > i) ? 0 : idx1 + i + 1;
    }
    if (idx2 < 0) {
      idx2 = (-idx2 > i) ? 0 : idx2 + i + 1;
    }
  }

  // Shorten all the file names, so that it is easy to read.
  shorten_fnames(false);

  // Get the attributes for the different quickfix highlight items.  Note
  // that this depends on syntax items defined in the qf.vim syntax file
  qfFile_hl_id = syn_name2id("qfFileName");
  if (qfFile_hl_id == 0) {
    qfFile_hl_id = HLF_D;
  }
  qfSep_hl_id = syn_name2id("qfSeparator");
  if (qfSep_hl_id == 0) {
    qfSep_hl_id = HLF_D;
  }
  qfLine_hl_id = syn_name2id("qfLineNr");
  if (qfLine_hl_id == 0) {
    qfLine_hl_id = HLF_N;
  }

  if (qfl->qf_nonevalid) {
    all = true;
  }
  qfline_T *qfp;
  FOR_ALL_QFL_ITEMS(qfl, qfp, i) {
    if ((qfp->qf_valid || all) && idx1 <= i && i <= idx2) {
      qf_list_entry(qfp, i, i == qfl->qf_index);
    }
    os_breakcheck();
  }
  qfga_clear();
}

/// Remove newlines and leading whitespace from an error message.
/// Add the result to the grow array "gap".
static void qf_fmt_text(garray_T *gap, const char *restrict text)
  FUNC_ATTR_NONNULL_ALL
{
  const char *p = text;
  while (*p != NUL) {
    if (*p == '\n') {
      ga_append(gap, ' ');
      while (*++p != NUL) {
        if (!ascii_iswhite(*p) && *p != '\n') {
          break;
        }
      }
    } else {
      ga_append(gap, (uint8_t)(*p++));
    }
  }
}

/// Add the range information from the lnum, col, end_lnum, and end_col values
/// of a quickfix entry to the grow array "gap".
static void qf_range_text(garray_T *gap, const qfline_T *qfp)
{
  char *const buf = IObuff;
  const size_t bufsize = IOSIZE;

  vim_snprintf(buf, bufsize, "%" PRIdLINENR, qfp->qf_lnum);
  size_t len = strlen(buf);

  if (qfp->qf_end_lnum > 0 && qfp->qf_lnum != qfp->qf_end_lnum) {
    vim_snprintf(buf + len, bufsize - len, "-%" PRIdLINENR, qfp->qf_end_lnum);
    len += strlen(buf + len);
  }
  if (qfp->qf_col > 0) {
    vim_snprintf(buf + len, bufsize - len, " col %d", qfp->qf_col);
    len += strlen(buf + len);
    if (qfp->qf_end_col > 0 && qfp->qf_col != qfp->qf_end_col) {
      vim_snprintf(buf + len, bufsize - len, "-%d", qfp->qf_end_col);
      len += strlen(buf + len);
    }
  }

  ga_concat_len(gap, buf, len);
}

/// Display information (list number, list size and the title) about a
/// quickfix/location list.
static void qf_msg(qf_info_T *qi, int which, char *lead)
{
  char *title = qi->qf_lists[which].qf_title;
  int count = qi->qf_lists[which].qf_count;
  char buf[IOSIZE];

  vim_snprintf(buf, IOSIZE, _("%serror list %d of %d; %d errors "),
               lead,
               which + 1,
               qi->qf_listcount,
               count);

  if (title != NULL) {
    size_t len = strlen(buf);

    if (len < 34) {
      memset(buf + len, ' ', 34 - len);
      buf[34] = NUL;
    }
    xstrlcat(buf, title, IOSIZE);
  }
  trunc_string(buf, buf, Columns - 1, IOSIZE);
  msg(buf, 0);
}

/// ":colder [count]": Up in the quickfix stack.
/// ":cnewer [count]": Down in the quickfix stack.
/// ":lolder [count]": Up in the location list stack.
/// ":lnewer [count]": Down in the location list stack.
void qf_age(exarg_T *eap)
{
  qf_info_T *qi;

  if ((qi = qf_cmd_get_stack(eap, true)) == NULL) {
    return;
  }

  int count = (eap->addr_count != 0) ? (int)eap->line2 : 1;
  while (count--) {
    if (eap->cmdidx == CMD_colder || eap->cmdidx == CMD_lolder) {
      if (qi->qf_curlist == 0) {
        emsg(_("E380: At bottom of quickfix stack"));
        break;
      }
      qi->qf_curlist--;
    } else {
      if (qi->qf_curlist >= qi->qf_listcount - 1) {
        emsg(_("E381: At top of quickfix stack"));
        break;
      }
      qi->qf_curlist++;
    }
  }
  qf_msg(qi, qi->qf_curlist, "");
  qf_update_buffer(qi, NULL);
}

/// Display the information about all the quickfix/location lists in the stack.
void qf_history(exarg_T *eap)
{
  qf_info_T *qi = qf_cmd_get_stack(eap, false);

  if (eap->addr_count > 0) {
    if (qi == NULL) {
      emsg(_(e_loclist));
      return;
    }

    // Jump to the specified quickfix list
    if (eap->line2 > 0 && eap->line2 <= qi->qf_listcount) {
      qi->qf_curlist = eap->line2 - 1;
      qf_msg(qi, qi->qf_curlist, "");
      qf_update_buffer(qi, NULL);
    } else {
      emsg(_(e_invrange));
    }

    return;
  }

  if (qf_stack_empty(qi)) {
    msg(_("No entries"), 0);
  } else {
    for (int i = 0; i < qi->qf_listcount; i++) {
      qf_msg(qi, i, i == qi->qf_curlist ? "> " : "  ");
    }
  }
}

/// Free all the entries in the error list "idx". Note that other information
/// associated with the list like context and title are not freed.
static void qf_free_items(qf_list_T *qfl)
{
  bool stop = false;

  while (qfl->qf_count && qfl->qf_start != NULL) {
    qfline_T *qfp = qfl->qf_start;
    qfline_T *qfpnext = qfp->qf_next;
    if (!stop) {
      xfree(qfp->qf_fname);
      xfree(qfp->qf_module);
      xfree(qfp->qf_text);
      xfree(qfp->qf_pattern);
      tv_clear(&qfp->qf_user_data);
      stop = (qfp == qfpnext);
      xfree(qfp);
      if (stop) {
        // Somehow qf_count may have an incorrect value, set it to 1
        // to avoid crashing when it's wrong.
        // TODO(vim): Avoid qf_count being incorrect.
        qfl->qf_count = 1;
      } else {
        qfl->qf_start = qfpnext;
      }
    }
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
static void qf_free(qf_list_T *qfl)
{
  qf_free_items(qfl);

  XFREE_CLEAR(qfl->qf_title);
  tv_free(qfl->qf_ctx);
  qfl->qf_ctx = NULL;
  callback_free(&qfl->qf_qftf_cb);
  qfl->qf_id = 0;
  qfl->qf_changedtick = 0;
}

/// Adjust error list entries for changed line numbers
///
/// Note: `buf` is the changed buffer, but `wp` is a potential location list
/// into that buffer, or NULL to check the quickfix list.
bool qf_mark_adjust(buf_T *buf, win_T *wp, linenr_T line1, linenr_T line2, linenr_T amount,
                    linenr_T amount_after)
{
  qf_info_T *qi = &ql_info;
  int buf_has_flag = wp == NULL ? BUF_HAS_QF_ENTRY : BUF_HAS_LL_ENTRY;

  if (!(buf->b_has_qf_entry & buf_has_flag)) {
    return false;
  }
  if (wp != NULL) {
    if (wp->w_llist == NULL) {
      return false;
    }
    qi = wp->w_llist;
  }

  int i;
  qfline_T *qfp;
  bool found_one = false;
  for (int idx = 0; idx < qi->qf_listcount; idx++) {
    qf_list_T *qfl = qf_get_list(qi, idx);
    if (!qf_list_empty(qfl)) {
      FOR_ALL_QFL_ITEMS(qfl, qfp, i) {
        if (qfp->qf_fnum == buf->b_fnum) {
          found_one = true;
          if (qfp->qf_lnum >= line1 && qfp->qf_lnum <= line2) {
            if (amount == MAXLNUM) {
              qfp->qf_cleared = true;
            } else {
              qfp->qf_lnum += amount;
            }
          } else if (amount_after && qfp->qf_lnum > line2) {
            qfp->qf_lnum += amount_after;
          }
        }
      }
    }
  }

  return found_one;
}

// Make a nice message out of the error character and the error number:
//  char    number  message
//  e or E    0     " error"
//  w or W    0     " warning"
//  i or I    0     " info"
//  n or N    0     " note"
//  0         0     ""
//  other     0     " c"
//  e or E    n     " error n"
//  w or W    n     " warning n"
//  i or I    n     " info n"
//  n or N    n     " note n"
//  0         n     " error n"
//  other     n     " c n"
//  1         x     ""          :helpgrep
static char *qf_types(int c, int nr)
{
  static char cc[3];
  char *p;

  if (c == 'W' || c == 'w') {
    p = " warning";
  } else if (c == 'I' || c == 'i') {
    p = " info";
  } else if (c == 'N' || c == 'n') {
    p = " note";
  } else if (c == 'E' || c == 'e' || (c == 0 && nr > 0)) {
    p = " error";
  } else if (c == 0 || c == 1) {
    p = "";
  } else {
    cc[0] = ' ';
    cc[1] = (char)c;
    cc[2] = NUL;
    p = cc;
  }

  if (nr <= 0) {
    return p;
  }

  static char buf[20];
  snprintf(buf, sizeof(buf), "%s %3d", p, nr);
  return buf;
}

// When "split" is false: Open the entry/result under the cursor.
// When "split" is true: Open the entry/result under the cursor in a new window.
void qf_view_result(bool split)
{
  qf_info_T *qi = &ql_info;

  if (IS_LL_WINDOW(curwin)) {
    qi = GET_LOC_LIST(curwin);
  }

  if (qf_list_empty(qf_get_curlist(qi))) {
    emsg(_(e_no_errors));
    return;
  }

  if (split) {
    // Open the selected entry in a new window
    qf_jump_newwin(qi, 0, (int)curwin->w_cursor.lnum, false, true);
    do_cmdline_cmd("clearjumps");
    return;
  }

  do_cmdline_cmd((IS_LL_WINDOW(curwin) ? ".ll" : ".cc"));
}

// ":cwindow": open the quickfix window if we have errors to display,
//             close it if not.
// ":lwindow": open the location list window if we have locations to display,
//             close it if not.
void ex_cwindow(exarg_T *eap)
{
  qf_info_T *qi;

  if ((qi = qf_cmd_get_stack(eap, true)) == NULL) {
    return;
  }

  qf_list_T *qfl = qf_get_curlist(qi);

  // Look for an existing quickfix window.
  win_T *win = qf_find_win(qi);

  // If a quickfix window is open but we have no errors to display,
  // close the window.  If a quickfix window is not open, then open
  // it if we have errors; otherwise, leave it closed.
  if (qf_stack_empty(qi)
      || qfl->qf_nonevalid
      || qf_list_empty(qfl)) {
    if (win != NULL) {
      ex_cclose(eap);
    }
  } else if (win == NULL) {
    ex_copen(eap);
  }
}

// ":cclose": close the window showing the list of errors.
// ":lclose": close the window showing the location list
void ex_cclose(exarg_T *eap)
{
  qf_info_T *qi;

  if ((qi = qf_cmd_get_stack(eap, false)) == NULL) {
    return;
  }

  // Find existing quickfix window and close it.
  win_T *win = qf_find_win(qi);
  if (win != NULL) {
    win_close(win, false, false);
  }
}

// Goto a quickfix or location list window (if present).
// Returns OK if the window is found, FAIL otherwise.
static int qf_goto_cwindow(const qf_info_T *qi, bool resize, int sz, bool vertsplit)
{
  win_T *const win = qf_find_win(qi);
  if (win == NULL) {
    return FAIL;
  }

  win_goto(win);
  if (resize) {
    if (vertsplit) {
      if (sz != win->w_width) {
        win_setwidth(sz);
      }
    } else if (sz != win->w_height
               && (win->w_height + win->w_hsep_height + win->w_status_height + tabline_height()
                   < cmdline_row)) {
      win_setheight(sz);
    }
  }

  return OK;
}

// Set options for the buffer in the quickfix or location list window.
static void qf_set_cwindow_options(void)
{
  // switch off 'swapfile'
  set_option_value_give_err(kOptSwapfile, BOOLEAN_OPTVAL(false), OPT_LOCAL);
  set_option_value_give_err(kOptBuftype, STATIC_CSTR_AS_OPTVAL("quickfix"), OPT_LOCAL);
  set_option_value_give_err(kOptBufhidden, STATIC_CSTR_AS_OPTVAL("hide"), OPT_LOCAL);
  RESET_BINDING(curwin);
  curwin->w_p_diff = false;
  set_option_value_give_err(kOptFoldmethod, STATIC_CSTR_AS_OPTVAL("manual"), OPT_LOCAL);
}

// Open a new quickfix or location list window, load the quickfix buffer and
// set the appropriate options for the window.
// Returns FAIL if the window could not be opened.
static int qf_open_new_cwindow(qf_info_T *qi, int height)
  FUNC_ATTR_NONNULL_ALL
{
  win_T *oldwin = curwin;
  const tabpage_T *const prevtab = curtab;
  int flags = 0;

  const buf_T *const qf_buf = qf_find_buf(qi);

  // The current window becomes the previous window afterwards.
  win_T *const win = curwin;

  if (IS_QF_STACK(qi) && cmdmod.cmod_split == 0) {
    // Create the new quickfix window at the very bottom, except when
    // :belowright or :aboveleft is used.
    win_goto(lastwin);
  }
  // Default is to open the window below the current window
  if (cmdmod.cmod_split == 0) {
    flags = WSP_BELOW;
  }
  flags |= WSP_NEWLOC;
  if (win_split(height, flags) == FAIL) {
    return FAIL;  // not enough room for window
  }
  RESET_BINDING(curwin);

  if (IS_LL_STACK(qi)) {
    // For the location list window, create a reference to the
    // location list stack from the window 'win'.
    curwin->w_llist_ref = qi;
    qi->qf_refcount++;
  }

  if (oldwin != curwin) {
    oldwin = NULL;  // don't store info when in another window
  }
  if (qf_buf != NULL) {
    // Use the existing quickfix buffer
    if (do_ecmd(qf_buf->b_fnum, NULL, NULL, NULL, ECMD_ONE,
                ECMD_HIDE + ECMD_OLDBUF + ECMD_NOWINENTER, oldwin) == FAIL) {
      return FAIL;
    }
  } else {
    // Create a new quickfix buffer
    if (do_ecmd(0, NULL, NULL, NULL, ECMD_ONE, ECMD_HIDE + ECMD_NOWINENTER, oldwin) == FAIL) {
      return FAIL;
    }
    // save the number of the new buffer
    qi->qf_bufnr = curbuf->b_fnum;
  }

  // Set the options for the quickfix buffer/window (if not already done)
  // Do this even if the quickfix buffer was already present, as an autocmd
  // might have previously deleted (:bdelete) the quickfix buffer.
  if (!bt_quickfix(curbuf)) {
    qf_set_cwindow_options();
  }

  // Only set the height when still in the same tab page and there is no
  // window to the side.
  if (curtab == prevtab && curwin->w_width == Columns) {
    win_setheight(height);
  }
  curwin->w_p_wfh = true;  // set 'winfixheight'
  if (win_valid(win)) {
    prevwin = win;
  }
  return OK;
}

/// Set "w:quickfix_title" if "qi" has a title.
static void qf_set_title_var(qf_list_T *qfl)
{
  if (qfl->qf_title != NULL) {
    set_internal_string_var("w:quickfix_title", qfl->qf_title);
  }
}

/// ":copen": open a window that shows the list of errors.
/// ":lopen": open a window that shows the location list.
void ex_copen(exarg_T *eap)
{
  qf_info_T *qi;

  if ((qi = qf_cmd_get_stack(eap, true)) == NULL) {
    return;
  }

  incr_quickfix_busy();

  int height;
  if (eap->addr_count != 0) {
    height = (int)eap->line2;
  } else {
    height = QF_WINHEIGHT;
  }
  reset_VIsual_and_resel();  // stop Visual mode

  // Find an existing quickfix window, or open a new one.
  int status = FAIL;
  if (cmdmod.cmod_tab == 0) {
    status = qf_goto_cwindow(qi, eap->addr_count != 0, height,
                             cmdmod.cmod_split & WSP_VERT);
  }
  if (status == FAIL) {
    if (qf_open_new_cwindow(qi, height) == FAIL) {
      decr_quickfix_busy();
      return;
    }
  }

  qf_list_T *qfl = qf_get_curlist(qi);
  qf_set_title_var(qfl);
  // Save the current index here, as updating the quickfix buffer may free
  // the quickfix list
  int lnum = qfl->qf_index;

  // Fill the buffer with the quickfix list.
  qf_fill_buffer(qfl, curbuf, NULL, curwin->handle);

  decr_quickfix_busy();

  curwin->w_cursor.lnum = lnum;
  curwin->w_cursor.col = 0;
  check_cursor(curwin);
  update_topline(curwin);             // scroll to show the line
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
  update_topline(curwin);              // scroll to show the line
  redraw_later(curwin, UPD_VALID);
  curwin->w_redr_status = true;  // update ruler
  curwin = old_curwin;
  curbuf = curwin->w_buffer;
}

/// :cbottom/:lbottom command.
void ex_cbottom(exarg_T *eap)
{
  qf_info_T *qi;

  if ((qi = qf_cmd_get_stack(eap, true)) == NULL) {
    return;
  }

  win_T *win = qf_find_win(qi);

  if (win != NULL && win->w_cursor.lnum != win->w_buffer->b_ml.ml_line_count) {
    qf_win_goto(win, win->w_buffer->b_ml.ml_line_count);
  }
}

// Return the number of the current entry (line number in the quickfix
// window).
linenr_T qf_current_entry(win_T *wp)
{
  qf_info_T *qi = &ql_info;

  if (IS_LL_WINDOW(wp)) {
    // In the location list window, use the referenced location list
    qi = wp->w_llist_ref;
  }

  return qf_get_curlist(qi)->qf_index;
}

/// Update the cursor position in the quickfix window to the current error.
/// Return true if there is a quickfix window.
///
/// @param old_qf_index  previous qf_index or zero
static bool qf_win_pos_update(qf_info_T *qi, int old_qf_index)
{
  int qf_index = qf_get_curlist(qi)->qf_index;

  // Put the cursor on the current error in the quickfix window, so that
  // it's viewable.
  win_T *win = qf_find_win(qi);
  if (win != NULL
      && qf_index <= win->w_buffer->b_ml.ml_line_count
      && old_qf_index != qf_index) {
    win->w_redraw_top = MIN(old_qf_index, qf_index);
    win->w_redraw_bot = MAX(old_qf_index, qf_index);
    qf_win_goto(win, qf_index);
  }
  return win != NULL;
}

/// Checks whether the given window is displaying the specified
/// quickfix/location stack.
static int is_qf_win(const win_T *win, const qf_info_T *qi)
  FUNC_ATTR_NONNULL_ARG(2) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  // A window displaying the quickfix buffer will have the w_llist_ref field
  // set to NULL.
  // A window displaying a location list buffer will have the w_llist_ref
  // pointing to the location list.
  if (buf_valid(win->w_buffer) && bt_quickfix(win->w_buffer)) {
    if ((IS_QF_STACK(qi) && win->w_llist_ref == NULL)
        || (IS_LL_STACK(qi) && win->w_llist_ref == qi)) {
      return true;
    }
  }

  return false;
}

/// Find a window displaying the quickfix/location stack 'qi' in the current tab
/// page.
static win_T *qf_find_win(const qf_info_T *qi)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  FOR_ALL_WINDOWS_IN_TAB(win, curtab) {
    if (is_qf_win(win, qi)) {
      return win;
    }
  }

  return NULL;
}

/// Find a quickfix buffer.
/// Searches in windows opened in all the tab pages.
static buf_T *qf_find_buf(qf_info_T *qi)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (qi->qf_bufnr != INVALID_QFBUFNR) {
    buf_T *const qfbuf = buflist_findnr(qi->qf_bufnr);
    if (qfbuf != NULL) {
      return qfbuf;
    }
    // buffer is no longer present
    qi->qf_bufnr = INVALID_QFBUFNR;
  }

  FOR_ALL_TAB_WINDOWS(tp, win) {
    if (is_qf_win(win, qi)) {
      return win->w_buffer;
    }
  }

  return NULL;
}

/// Process the 'quickfixtextfunc' option value.
const char *did_set_quickfixtextfunc(optset_T *args FUNC_ATTR_UNUSED)
{
  if (option_set_callback_func(p_qftf, &qftf_cb) == FAIL) {
    return e_invarg;
  }
  return NULL;
}

/// Update the w:quickfix_title variable in the quickfix/location list window in
/// all the tab pages.
static void qf_update_win_titlevar(qf_info_T *qi)
  FUNC_ATTR_NONNULL_ALL
{
  qf_list_T *const qfl = qf_get_curlist(qi);
  win_T *const save_curwin = curwin;

  FOR_ALL_TAB_WINDOWS(tp, win) {
    if (is_qf_win(win, qi)) {
      curwin = win;
      qf_set_title_var(qfl);
    }
  }
  curwin = save_curwin;
}

// Find the quickfix buffer.  If it exists, update the contents.
static void qf_update_buffer(qf_info_T *qi, qfline_T *old_last)
{
  // Check if a buffer for the quickfix list exists.  Update it.
  buf_T *buf = qf_find_buf(qi);
  if (buf == NULL) {
    return;
  }

  linenr_T old_line_count = buf->b_ml.ml_line_count;
  int qf_winid = 0;

  win_T *win;
  if (IS_LL_STACK(qi)) {
    if (curwin->w_llist == qi) {
      win = curwin;
    } else {
      // Find the file window (non-quickfix) with this location list
      win = qf_find_win_with_loclist(qi);
      if (win == NULL) {
        // File window is not found. Find the location list window.
        win = qf_find_win(qi);
      }
      if (win == NULL) {
        return;
      }
    }
    qf_winid = (int)win->handle;
  }

  // autocommands may cause trouble
  incr_quickfix_busy();

  aco_save_T aco;

  if (old_last == NULL) {
    // set curwin/curbuf to buf and save a few things
    aucmd_prepbuf(&aco, buf);
  }

  qf_update_win_titlevar(qi);

  qf_fill_buffer(qf_get_curlist(qi), buf, old_last, qf_winid);
  buf_inc_changedtick(buf);

  if (old_last == NULL) {
    qf_win_pos_update(qi, 0);

    // restore curwin/curbuf and a few other things
    aucmd_restbuf(&aco);
  }

  // Only redraw when added lines are visible.  This avoids flickering when
  // the added lines are not visible.
  if ((win = qf_find_win(qi)) != NULL && old_line_count < win->w_botline) {
    redraw_buf_later(buf, UPD_NOT_VALID);
  }

  // always called after incr_quickfix_busy()
  decr_quickfix_busy();
}

// Add an error line to the quickfix buffer.
static int qf_buf_add_line(qf_list_T *qfl, buf_T *buf, linenr_T lnum, const qfline_T *qfp,
                           char *dirname, char *qftf_str, bool first_bufline)
  FUNC_ATTR_NONNULL_ARG(1, 2, 4, 5)
{
  garray_T *gap = qfga_get();

  // If the 'quickfixtextfunc' function returned a non-empty custom string
  // for this entry, then use it.
  if (qftf_str != NULL && *qftf_str != NUL) {
    ga_concat(gap, qftf_str);
  } else {
    buf_T *errbuf;
    if (qfp->qf_module != NULL) {
      ga_concat(gap, qfp->qf_module);
    } else if (qfp->qf_fnum != 0
               && (errbuf = buflist_findnr(qfp->qf_fnum)) != NULL
               && errbuf->b_fname != NULL) {
      if (qfp->qf_type == 1) {  // :helpgrep
        ga_concat(gap, path_tail(errbuf->b_fname));
      } else {
        // Shorten the file name if not done already.
        // For optimization, do this only for the first entry in a
        // buffer.
        if (first_bufline
            && (errbuf->b_sfname == NULL
                || path_is_absolute(errbuf->b_sfname))) {
          if (*dirname == NUL) {
            os_dirname(dirname, MAXPATHL);
          }
          shorten_buf_fname(errbuf, dirname, false);
        }
        ga_concat(gap, qfp->qf_fname == NULL ? errbuf->b_fname : qfp->qf_fname);
      }
    }

    ga_append(gap, '|');

    if (qfp->qf_lnum > 0) {
      qf_range_text(gap, qfp);
      ga_concat(gap, qf_types(qfp->qf_type, qfp->qf_nr));
    } else if (qfp->qf_pattern != NULL) {
      qf_fmt_text(gap, qfp->qf_pattern);
    }
    ga_append(gap, '|');
    ga_append(gap, ' ');

    // Remove newlines and leading whitespace from the text.
    // For an unrecognized line keep the indent, the compiler may
    // mark a word with ^^^^.
    qf_fmt_text(gap, gap->ga_len > 3 ? skipwhite(qfp->qf_text) : qfp->qf_text);
  }

  ga_append(gap, NUL);
  if (ml_append_buf(buf, lnum, gap->ga_data, gap->ga_len, false) == FAIL) {
    return FAIL;
  }

  return OK;
}

// Call the 'quickfixtextfunc' function to get the list of lines to display in
// the quickfix window for the entries 'start_idx' to 'end_idx'.
static list_T *call_qftf_func(qf_list_T *qfl, int qf_winid, int start_idx, int end_idx)
{
  Callback *cb = &qftf_cb;
  list_T *qftf_list = NULL;
  static bool recursive = false;

  if (recursive) {
    return NULL;  // this doesn't work properly recursively
  }
  recursive = true;

  // If 'quickfixtextfunc' is set, then use the user-supplied function to get
  // the text to display. Use the local value of 'quickfixtextfunc' if it is
  // set.
  if (qfl->qf_qftf_cb.type != kCallbackNone) {
    cb = &qfl->qf_qftf_cb;
  }
  if (cb->type != kCallbackNone) {
    typval_T args[1];
    typval_T rettv;

    // create the dict argument
    dict_T *const dict = tv_dict_alloc_lock(VAR_FIXED);

    tv_dict_add_nr(dict, S_LEN("quickfix"), IS_QF_LIST(qfl));
    tv_dict_add_nr(dict, S_LEN("winid"), qf_winid);
    tv_dict_add_nr(dict, S_LEN("id"), qfl->qf_id);
    tv_dict_add_nr(dict, S_LEN("start_idx"), start_idx);
    tv_dict_add_nr(dict, S_LEN("end_idx"), end_idx);
    dict->dv_refcount++;
    args[0].v_type = VAR_DICT;
    args[0].vval.v_dict = dict;

    if (callback_call(cb, 1, args, &rettv)) {
      if (rettv.v_type == VAR_LIST) {
        qftf_list = rettv.vval.v_list;
        tv_list_ref(qftf_list);
      }
      tv_clear(&rettv);
    }
    tv_dict_unref(dict);
  }

  recursive = false;
  return qftf_list;
}

/// Fill current buffer with quickfix errors, replacing any previous contents.
/// curbuf must be the quickfix buffer!
/// If "old_last" is not NULL append the items after this one.
/// When "old_last" is NULL then "buf" must equal "curbuf"!  Because ml_delete()
/// is used and autocommands will be triggered.
static void qf_fill_buffer(qf_list_T *qfl, buf_T *buf, qfline_T *old_last, int qf_winid)
  FUNC_ATTR_NONNULL_ARG(2)
{
  const bool old_KeyTyped = KeyTyped;

  if (old_last == NULL) {
    if (buf != curbuf) {
      internal_error("qf_fill_buffer()");
      return;
    }

    // delete all existing lines
    //
    // Note: we cannot store undo information, because
    // qf buffer is usually not allowed to be modified.
    //
    // So we need to clean up undo information
    // otherwise autocommands may invalidate the undo stack
    while ((curbuf->b_ml.ml_flags & ML_EMPTY) == 0) {
      // If deletion fails, this loop may run forever, so
      // signal error and return.
      if (ml_delete(1, false) == FAIL) {
        internal_error("qf_fill_buffer()");
        return;
      }
    }

    FOR_ALL_TAB_WINDOWS(tp, wp) {
      if (wp->w_buffer == curbuf) {
        wp->w_skipcol = 0;
      }
    }

    // Remove all undo information
    u_clearallandblockfree(curbuf);
  }

  // Check if there is anything to display
  if (qfl != NULL && qfl->qf_start != NULL) {
    char dirname[MAXPATHL];

    *dirname = NUL;

    linenr_T lnum;
    qfline_T *qfp;

    // Add one line for each error
    if (old_last == NULL) {
      qfp = qfl->qf_start;
      lnum = 0;
    } else {
      qfp = old_last->qf_next != NULL ? old_last->qf_next : old_last;
      lnum = buf->b_ml.ml_line_count;
    }

    list_T *qftf_list = call_qftf_func(qfl, qf_winid, lnum + 1, qfl->qf_count);
    listitem_T *qftf_li = tv_list_first(qftf_list);

    int prev_bufnr = -1;
    bool invalid_val = false;

    while (lnum < qfl->qf_count) {
      char *qftf_str = NULL;

      // Use the text supplied by the user defined function (if any).
      // If the returned value is not string, then ignore the rest
      // of the returned values and use the default.
      if (qftf_li != NULL && !invalid_val) {
        qftf_str = (char *)tv_get_string_chk(TV_LIST_ITEM_TV(qftf_li));
        if (qftf_str == NULL) {
          invalid_val = true;
        }
      }

      if (qf_buf_add_line(qfl, buf, lnum, qfp, dirname, qftf_str,
                          prev_bufnr != qfp->qf_fnum) == FAIL) {
        break;
      }
      prev_bufnr = qfp->qf_fnum;
      lnum++;
      qfp = qfp->qf_next;
      if (qfp == NULL) {
        break;
      }

      if (qftf_li != NULL) {
        qftf_li = TV_LIST_ITEM_NEXT(qftf_list, qftf_li);
      }
    }
    if (old_last == NULL) {
      // Delete the empty line which is now at the end
      ml_delete(lnum + 1, false);
    }

    qfga_clear();
  }

  // Correct cursor position.
  check_lnums(true);

  if (old_last == NULL) {
    // Set the 'filetype' to "qf" each time after filling the buffer.  This
    // resembles reading a file into a buffer, it's more logical when using
    // autocommands.
    curbuf->b_ro_locked++;
    set_option_value_give_err(kOptFiletype, STATIC_CSTR_AS_OPTVAL("qf"), OPT_LOCAL);
    curbuf->b_p_ma = false;

    curbuf->b_keep_filetype = true;  // don't detect 'filetype'
    apply_autocmds(EVENT_BUFREADPOST, "quickfix", NULL, false, curbuf);
    apply_autocmds(EVENT_BUFWINENTER, "quickfix", NULL, false, curbuf);
    curbuf->b_keep_filetype = false;
    curbuf->b_ro_locked--;

    // make sure it will be redrawn
    redraw_curbuf_later(UPD_NOT_VALID);
  }

  // Restore KeyTyped, setting 'filetype' may reset it.
  KeyTyped = old_KeyTyped;
}

static void qf_list_changed(qf_list_T *qfl)
{
  qfl->qf_changedtick++;
}

/// Return the quickfix/location list number with the given identifier.
///
/// @returns -1 if list is not found.
static int qf_id2nr(const qf_info_T *const qi, const unsigned qfid)
{
  for (int qf_idx = 0; qf_idx < qi->qf_listcount; qf_idx++) {
    if (qi->qf_lists[qf_idx].qf_id == qfid) {
      return qf_idx;
    }
  }
  return INVALID_QFIDX;
}

/// If the current list is not "save_qfid" and we can find the list with that ID
/// then make it the current list.
/// This is used when autocommands may have changed the current list.
/// Returns OK if successfully restored the list. Returns FAIL if the list with
/// the specified identifier (save_qfid) is not found in the stack.
static int qf_restore_list(qf_info_T *qi, unsigned save_qfid)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (qf_get_curlist(qi)->qf_id == save_qfid) {
    return OK;
  }

  const int curlist = qf_id2nr(qi, save_qfid);
  if (curlist < 0) {
    // list is not present
    return FAIL;
  }
  qi->qf_curlist = curlist;
  return OK;
}

// Jump to the first entry if there is one.
static void qf_jump_first(qf_info_T *qi, unsigned save_qfid, int forceit)
  FUNC_ATTR_NONNULL_ALL
{
  if (qf_restore_list(qi, save_qfid) == FAIL) {
    return;
  }

  if (!check_can_set_curbuf_forceit(forceit)) {
    return;
  }

  // Autocommands might have cleared the list, check for that
  if (!qf_list_empty(qf_get_curlist(qi))) {
    qf_jump(qi, 0, 0, forceit);
  }
}

// Return true when using ":vimgrep" for ":grep".
int grep_internal(cmdidx_T cmdidx)
{
  return (cmdidx == CMD_grep
          || cmdidx == CMD_lgrep
          || cmdidx == CMD_grepadd
          || cmdidx == CMD_lgrepadd)
         && strcmp("internal", *curbuf->b_p_gp == NUL ? p_gp : curbuf->b_p_gp) == 0;
}

// Return the make/grep autocmd name.
static char *make_get_auname(cmdidx_T cmdidx)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  switch (cmdidx) {
  case CMD_make:
    return "make";
  case CMD_lmake:
    return "lmake";
  case CMD_grep:
    return "grep";
  case CMD_lgrep:
    return "lgrep";
  case CMD_grepadd:
    return "grepadd";
  case CMD_lgrepadd:
    return "lgrepadd";
  default:
    return NULL;
  }
}

// Form the complete command line to invoke 'make'/'grep'. Quote the command
// using 'shellquote' and append 'shellpipe'. Echo the fully formed command.
static char *make_get_fullcmd(const char *makecmd, const char *fname)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  size_t len = strlen(p_shq) * 2 + strlen(makecmd) + 1;
  if (*p_sp != NUL) {
    len += strlen(p_sp) + strlen(fname) + 3;
  }
  char *const cmd = xmalloc(len);
  snprintf(cmd, len, "%s%s%s", p_shq, makecmd, p_shq);

  // If 'shellpipe' empty: don't redirect to 'errorfile'.
  if (*p_sp != NUL) {
    append_redir(cmd, len, p_sp, fname);
  }

  // Display the fully formed command.  Output a newline if there's something
  // else than the :make command that was typed (in which case the cursor is
  // in column 0).
  if (msg_col == 0) {
    msg_didout = false;
  }
  msg_start();
  msg_puts(":!");
  msg_outtrans(cmd, 0, false);  // show what we are doing

  return cmd;
}

// Used for ":make", ":lmake", ":grep", ":lgrep", ":grepadd", and ":lgrepadd"
void ex_make(exarg_T *eap)
{
  char *enc = (*curbuf->b_p_menc != NUL) ? curbuf->b_p_menc : p_menc;

  // Redirect ":grep" to ":vimgrep" if 'grepprg' is "internal".
  if (grep_internal(eap->cmdidx)) {
    ex_vimgrep(eap);
    return;
  }

  char *const au_name = make_get_auname(eap->cmdidx);
  if (au_name != NULL && apply_autocmds(EVENT_QUICKFIXCMDPRE, au_name,
                                        curbuf->b_fname, true, curbuf)) {
    if (aborting()) {
      return;
    }
  }

  win_T *wp = NULL;
  if (is_loclist_cmd(eap->cmdidx)) {
    wp = curwin;
  }

  autowrite_all();
  char *fname = get_mef_name();
  if (fname == NULL) {
    return;
  }
  os_remove(fname);  // in case it's not unique

  char *const cmd = make_get_fullcmd(eap->arg, fname);

  do_shell(cmd, 0);

  incr_quickfix_busy();

  char *errorformat = (eap->cmdidx != CMD_make && eap->cmdidx != CMD_lmake)
                      ? p_gefm
                      : p_efm;

  bool newlist = eap->cmdidx != CMD_grepadd && eap->cmdidx != CMD_lgrepadd;

  int res = qf_init(wp, fname, errorformat, newlist, qf_cmdtitle(*eap->cmdlinep), enc);

  qf_info_T *qi = &ql_info;
  if (wp != NULL) {
    qi = GET_LOC_LIST(wp);
    if (qi == NULL) {
      goto cleanup;
    }
  }
  if (res >= 0) {
    qf_list_changed(qf_get_curlist(qi));
  }
  // Remember the current quickfix list identifier, so that we can
  // check for autocommands changing the current quickfix list.
  unsigned save_qfid = qf_get_curlist(qi)->qf_id;
  if (au_name != NULL) {
    apply_autocmds(EVENT_QUICKFIXCMDPOST, au_name, curbuf->b_fname, true,
                   curbuf);
  }
  if (res > 0 && !eap->forceit && qflist_valid(wp, save_qfid)) {
    // display the first error
    qf_jump_first(qi, save_qfid, false);
  }

cleanup:
  decr_quickfix_busy();
  os_remove(fname);
  xfree(fname);
  xfree(cmd);
}

// Return the name for the errorfile, in allocated memory.
// Find a new unique name when 'makeef' contains "##".
// Returns NULL for error.
static char *get_mef_name(void)
{
  char *name;
  static int start = -1;
  static int off = 0;

  if (*p_mef == NUL) {
    name = vim_tempname();
    if (name == NULL) {
      emsg(_(e_notmp));
    }
    return name;
  }

  char *p;

  for (p = p_mef; *p; p++) {
    if (p[0] == '#' && p[1] == '#') {
      break;
    }
  }

  if (*p == NUL) {
    return xstrdup(p_mef);
  }

  // Keep trying until the name doesn't exist yet.
  while (true) {
    if (start == -1) {
      start = (int)os_get_pid();
    } else {
      off += 19;
    }
    name = xmalloc(strlen(p_mef) + 30);
    STRCPY(name, p_mef);
    snprintf(name + (p - p_mef), strlen(name), "%d%d", start, off);
    strcat(name, p + 2);
    // Don't accept a symbolic link, it's a security risk.
    FileInfo file_info;
    bool file_or_link_found = os_fileinfo_link(name, &file_info);
    if (!file_or_link_found) {
      break;
    }
    xfree(name);
  }
  return name;
}

/// Returns the number of entries in the current quickfix/location list.
size_t qf_get_size(exarg_T *eap)
  FUNC_ATTR_NONNULL_ALL
{
  qf_info_T *qi;

  if ((qi = qf_cmd_get_stack(eap, false)) == NULL) {
    return 0;
  }
  return (size_t)qf_get_curlist(qi)->qf_count;
}

/// Returns the number of valid entries in the current quickfix/location list.
size_t qf_get_valid_size(exarg_T *eap)
{
  qf_info_T *qi;

  if ((qi = qf_cmd_get_stack(eap, false)) == NULL) {
    return 0;
  }

  int prev_fnum = 0;
  size_t sz = 0;
  qfline_T *qfp;
  int i;
  assert(qf_get_curlist(qi)->qf_count >= 0);
  qf_list_T *qfl = qf_get_curlist(qi);
  FOR_ALL_QFL_ITEMS(qfl, qfp, i) {
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
  qf_info_T *qi;

  if ((qi = qf_cmd_get_stack(eap, false)) == NULL) {
    return 0;
  }

  assert(qf_get_curlist(qi)->qf_index >= 0);
  return (size_t)qf_get_curlist(qi)->qf_index;
}

/// Returns the current index in the quickfix/location list,
/// counting only valid entries.
/// Returns 1 if there are no valid entries.
int qf_get_cur_valid_idx(exarg_T *eap)
  FUNC_ATTR_NONNULL_ALL
{
  qf_info_T *qi;

  if ((qi = qf_cmd_get_stack(eap, false)) == NULL) {
    return 1;
  }

  qf_list_T *qfl = qf_get_curlist(qi);

  // Check if the list has valid errors.
  if (!qf_list_has_valid_entries(qfl)) {
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
static size_t qf_get_nth_valid_entry(qf_list_T *qfl, size_t n, bool fdo)
  FUNC_ATTR_NONNULL_ALL
{
  // Check if the list has valid errors.
  if (!qf_list_has_valid_entries(qfl)) {
    return 1;
  }

  int prev_fnum = 0;
  size_t eidx = 0;
  int i;
  qfline_T *qfp;
  assert(qfl->qf_count >= 0);
  FOR_ALL_QFL_ITEMS(qfl, qfp, i) {
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

  return i <= qfl->qf_count ? (size_t)i : 1;
}

/// ":cc", ":crewind", ":cfirst" and ":clast".
/// ":ll", ":lrewind", ":lfirst" and ":llast".
/// ":cdo", ":ldo", ":cfdo" and ":lfdo".
void ex_cc(exarg_T *eap)
{
  qf_info_T *qi;

  if ((qi = qf_cmd_get_stack(eap, true)) == NULL) {
    return;
  }

  int errornr;
  if (eap->addr_count > 0) {
    errornr = (int)eap->line2;
  } else {
    switch (eap->cmdidx) {
    case CMD_cc:
    case CMD_ll:
      errornr = 0;
      break;
    case CMD_crewind:
    case CMD_lrewind:
    case CMD_cfirst:
    case CMD_lfirst:
      errornr = 1;
      break;
    default:
      errornr = 32767;
      break;
    }
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
    size_t valid_entry = qf_get_nth_valid_entry(qf_get_curlist(qi), n,
                                                eap->cmdidx == CMD_cfdo || eap->cmdidx == CMD_lfdo);
    assert(valid_entry <= INT_MAX);
    errornr = (int)valid_entry;
  }

  qf_jump(qi, 0, errornr, eap->forceit);
}

/// ":cnext", ":cnfile", ":cNext" and ":cprevious".
/// ":lnext", ":lNext", ":lprevious", ":lnfile", ":lNfile" and ":lpfile".
/// ":cdo", ":ldo", ":cfdo" and ":lfdo".
void ex_cnext(exarg_T *eap)
{
  qf_info_T *qi;

  if ((qi = qf_cmd_get_stack(eap, true)) == NULL) {
    return;
  }

  int errornr;
  if (eap->addr_count > 0
      && (eap->cmdidx != CMD_cdo && eap->cmdidx != CMD_ldo
          && eap->cmdidx != CMD_cfdo && eap->cmdidx != CMD_lfdo)) {
    errornr = (int)eap->line2;
  } else {
    errornr = 1;
  }

  // Depending on the command jump to either next or previous entry/file.
  Direction dir;
  switch (eap->cmdidx) {
  case CMD_cprevious:
  case CMD_lprevious:
  case CMD_cNext:
  case CMD_lNext:
    dir = BACKWARD;
    break;
  case CMD_cnfile:
  case CMD_lnfile:
  case CMD_cfdo:
  case CMD_lfdo:
    dir = FORWARD_FILE;
    break;
  case CMD_cpfile:
  case CMD_lpfile:
  case CMD_cNfile:
  case CMD_lNfile:
    dir = BACKWARD_FILE;
    break;
  case CMD_cnext:
  case CMD_lnext:
  case CMD_cdo:
  case CMD_ldo:
  default:
    dir = FORWARD;
    break;
  }

  qf_jump(qi, dir, errornr, eap->forceit);
}

/// Find the first entry in the quickfix list 'qfl' from buffer 'bnr'.
/// The index of the entry is stored in 'errornr'.
/// Returns NULL if an entry is not found.
static qfline_T *qf_find_first_entry_in_buf(qf_list_T *qfl, int bnr, int *errornr)
{
  qfline_T *qfp = NULL;
  int idx = 0;

  // Find the first entry in this file
  FOR_ALL_QFL_ITEMS(qfl, qfp, idx) {
    if (qfp->qf_fnum == bnr) {
      break;
    }
  }

  *errornr = idx;
  return qfp;
}

/// Find the first quickfix entry on the same line as 'entry'. Updates 'errornr'
/// with the error number for the first entry. Assumes the entries are sorted in
/// the quickfix list by line number.
static qfline_T *qf_find_first_entry_on_line(qfline_T *entry, int *errornr)
{
  while (!got_int
         && entry->qf_prev != NULL
         && entry->qf_fnum == entry->qf_prev->qf_fnum
         && entry->qf_lnum == entry->qf_prev->qf_lnum) {
    entry = entry->qf_prev;
    (*errornr)--;
  }

  return entry;
}

/// Find the last quickfix entry on the same line as 'entry'. Updates 'errornr'
/// with the error number for the last entry. Assumes the entries are sorted in
/// the quickfix list by line number.
static qfline_T *qf_find_last_entry_on_line(qfline_T *entry, int *errornr)
{
  while (!got_int
         && entry->qf_next != NULL
         && entry->qf_fnum == entry->qf_next->qf_fnum
         && entry->qf_lnum == entry->qf_next->qf_lnum) {
    entry = entry->qf_next;
    (*errornr)++;
  }

  return entry;
}

// Returns true if the specified quickfix entry is
// after the given line (linewise is true)
// or after the line and column.
static bool qf_entry_after_pos(const qfline_T *qfp, const pos_T *pos, bool linewise)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (linewise) {
    return qfp->qf_lnum > pos->lnum;
  }
  return qfp->qf_lnum > pos->lnum
         || (qfp->qf_lnum == pos->lnum && qfp->qf_col > pos->col);
}

// Returns true if the specified quickfix entry is
// before the given line (linewise is true)
// or before the line and column.
static bool qf_entry_before_pos(const qfline_T *qfp, const pos_T *pos, bool linewise)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (linewise) {
    return qfp->qf_lnum < pos->lnum;
  }
  return qfp->qf_lnum < pos->lnum
         || (qfp->qf_lnum == pos->lnum && qfp->qf_col < pos->col);
}

// Returns true if the specified quickfix entry is
// on or after the given line (linewise is true)
// or on or after the line and column.
static bool qf_entry_on_or_after_pos(const qfline_T *qfp, const pos_T *pos, bool linewise)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (linewise) {
    return qfp->qf_lnum >= pos->lnum;
  }
  return qfp->qf_lnum > pos->lnum
         || (qfp->qf_lnum == pos->lnum && qfp->qf_col >= pos->col);
}

// Returns true if the specified quickfix entry is
// on or before the given line (linewise is true)
// or on or before the line and column.
static bool qf_entry_on_or_before_pos(const qfline_T *qfp, const pos_T *pos, bool linewise)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (linewise) {
    return qfp->qf_lnum <= pos->lnum;
  }
  return qfp->qf_lnum < pos->lnum
         || (qfp->qf_lnum == pos->lnum && qfp->qf_col <= pos->col);
}

/// Find the first quickfix entry after position 'pos' in buffer 'bnr'.
/// If 'linewise' is true, returns the entry after the specified line and treats
/// multiple entries on a single line as one. Otherwise returns the entry after
/// the specified line and column.
/// 'qfp' points to the very first entry in the buffer and 'errornr' is the
/// index of the very first entry in the quickfix list.
/// Returns NULL if an entry is not found after 'pos'.
static qfline_T *qf_find_entry_after_pos(int bnr, const pos_T *pos, bool linewise, qfline_T *qfp,
                                         int *errornr)
  FUNC_ATTR_NONNULL_ALL
{
  if (qf_entry_after_pos(qfp, pos, linewise)) {
    // First entry is after position 'pos'
    return qfp;
  }

  // Find the entry just before or at the position 'pos'
  while (qfp->qf_next != NULL
         && qfp->qf_next->qf_fnum == bnr
         && qf_entry_on_or_before_pos(qfp->qf_next, pos, linewise)) {
    qfp = qfp->qf_next;
    (*errornr)++;
  }

  if (qfp->qf_next == NULL || qfp->qf_next->qf_fnum != bnr) {
    // No entries found after position 'pos'
    return NULL;
  }

  // Use the entry just after position 'pos'
  qfp = qfp->qf_next;
  (*errornr)++;

  return qfp;
}

/// Find the first quickfix entry before position 'pos' in buffer 'bnr'.
/// If 'linewise' is true, returns the entry before the specified line and
/// treats multiple entries on a single line as one. Otherwise returns the entry
/// before the specified line and column.
/// 'qfp' points to the very first entry in the buffer and 'errornr' is the
/// index of the very first entry in the quickfix list.
/// Returns NULL if an entry is not found before 'pos'.
static qfline_T *qf_find_entry_before_pos(int bnr, const pos_T *pos, bool linewise, qfline_T *qfp,
                                          int *errornr)
  FUNC_ATTR_NONNULL_ALL
{
  // Find the entry just before the position 'pos'
  while (qfp->qf_next != NULL
         && qfp->qf_next->qf_fnum == bnr
         && qf_entry_before_pos(qfp->qf_next, pos, linewise)) {
    qfp = qfp->qf_next;
    (*errornr)++;
  }

  if (qf_entry_on_or_after_pos(qfp, pos, linewise)) {
    return NULL;
  }

  if (linewise) {
    // If multiple entries are on the same line, then use the first entry
    qfp = qf_find_first_entry_on_line(qfp, errornr);
  }

  return qfp;
}

/// Find a quickfix entry in 'qfl' closest to position 'pos' in buffer 'bnr' in
/// the direction 'dir'.
static qfline_T *qf_find_closest_entry(qf_list_T *qfl, int bnr, const pos_T *pos, Direction dir,
                                       bool linewise, int *errornr)
  FUNC_ATTR_NONNULL_ALL
{
  *errornr = 0;

  // Find the first entry in this file
  qfline_T *qfp = qf_find_first_entry_in_buf(qfl, bnr, errornr);
  if (qfp == NULL) {
    return NULL;  // no entry in this file
  }

  if (dir == FORWARD) {
    qfp = qf_find_entry_after_pos(bnr, pos, linewise, qfp, errornr);
  } else {
    qfp = qf_find_entry_before_pos(bnr, pos, linewise, qfp, errornr);
  }

  return qfp;
}

/// Get the nth quickfix entry below the specified entry.  Searches forward in
/// the list. If linewise is true, then treat multiple entries on a single line
/// as one.
static void qf_get_nth_below_entry(qfline_T *entry_arg, linenr_T n, bool linewise, int *errornr)
  FUNC_ATTR_NONNULL_ALL
{
  qfline_T *entry = entry_arg;

  while (n-- > 0 && !got_int) {
    int first_errornr = *errornr;

    if (linewise) {
      // Treat all the entries on the same line in this file as one
      entry = qf_find_last_entry_on_line(entry, errornr);
    }

    if (entry->qf_next == NULL
        || entry->qf_next->qf_fnum != entry->qf_fnum) {
      if (linewise) {
        *errornr = first_errornr;
      }
      break;
    }

    entry = entry->qf_next;
    (*errornr)++;
  }
}

/// Get the nth quickfix entry above the specified entry.  Searches backwards in
/// the list. If linewise is true, then treat multiple entries on a single line
/// as one.
static void qf_get_nth_above_entry(qfline_T *entry, linenr_T n, bool linewise, int *errornr)
  FUNC_ATTR_NONNULL_ALL
{
  while (n-- > 0 && !got_int) {
    if (entry->qf_prev == NULL
        || entry->qf_prev->qf_fnum != entry->qf_fnum) {
      break;
    }

    entry = entry->qf_prev;
    (*errornr)--;

    if (linewise) {
      entry = qf_find_first_entry_on_line(entry, errornr);
    }
  }
}

/// Find the n'th quickfix entry adjacent to position 'pos' in buffer 'bnr' in
/// the specified direction.  Returns the error number in the quickfix list or 0
/// if an entry is not found.
static int qf_find_nth_adj_entry(qf_list_T *qfl, int bnr, pos_T *pos, linenr_T n, Direction dir,
                                 bool linewise)
  FUNC_ATTR_NONNULL_ALL
{
  int errornr;

  // Find an entry closest to the specified position
  qfline_T *const adj_entry = qf_find_closest_entry(qfl, bnr, pos, dir,
                                                    linewise, &errornr);
  if (adj_entry == NULL) {
    return 0;
  }

  if (--n > 0) {
    // Go to the n'th entry in the current buffer
    if (dir == FORWARD) {
      qf_get_nth_below_entry(adj_entry, n, linewise, &errornr);
    } else {
      qf_get_nth_above_entry(adj_entry, n, linewise, &errornr);
    }
  }

  return errornr;
}

/// Jump to a quickfix entry in the current file nearest to the current line or
/// current line/col.
/// ":cabove", ":cbelow", ":labove", ":lbelow", ":cafter", ":cbefore",
/// ":lafter" and ":lbefore" commands
void ex_cbelow(exarg_T *eap)
{
  if (eap->addr_count > 0 && eap->line2 <= 0) {
    emsg(_(e_invrange));
    return;
  }

  // Check whether the current buffer has any quickfix entries
  int buf_has_flag = (eap->cmdidx == CMD_cabove
                      || eap->cmdidx == CMD_cbelow
                      || eap->cmdidx == CMD_cbefore
                      || eap->cmdidx == CMD_cafter) ? BUF_HAS_QF_ENTRY : BUF_HAS_LL_ENTRY;

  if (!(curbuf->b_has_qf_entry & buf_has_flag)) {
    emsg(_(e_no_errors));
    return;
  }

  qf_info_T *qi;
  if ((qi = qf_cmd_get_stack(eap, true)) == NULL) {
    return;
  }

  qf_list_T *qfl = qf_get_curlist(qi);
  // check if the list has valid errors
  if (!qf_list_has_valid_entries(qfl)) {
    emsg(_(e_no_errors));
    return;
  }

  // Forward motion commands
  int dir = (eap->cmdidx == CMD_cbelow
             || eap->cmdidx == CMD_lbelow
             || eap->cmdidx == CMD_cafter
             || eap->cmdidx == CMD_lafter) ? FORWARD : BACKWARD;

  pos_T pos = curwin->w_cursor;
  // A quickfix entry column number is 1 based whereas cursor column
  // number is 0 based. Adjust the column number.
  pos.col++;
  const int errornr = qf_find_nth_adj_entry(qfl,
                                            curbuf->b_fnum,
                                            &pos,
                                            eap->addr_count > 0 ? eap->line2 : 0,
                                            dir,
                                            eap->cmdidx == CMD_cbelow
                                            || eap->cmdidx == CMD_lbelow
                                            || eap->cmdidx == CMD_cabove
                                            || eap->cmdidx == CMD_labove);

  if (errornr > 0) {
    qf_jump(qi, 0, errornr, false);
  } else {
    emsg(_(e_no_more_items));
  }
}

/// Return the autocmd name for the :cfile Ex commands
static char *cfile_get_auname(cmdidx_T cmdidx)
{
  switch (cmdidx) {
  case CMD_cfile:
    return "cfile";
  case CMD_cgetfile:
    return "cgetfile";
  case CMD_caddfile:
    return "caddfile";
  case CMD_lfile:
    return "lfile";
  case CMD_lgetfile:
    return "lgetfile";
  case CMD_laddfile:
    return "laddfile";
  default:
    return NULL;
  }
}

// ":cfile"/":cgetfile"/":caddfile" commands.
// ":lfile"/":lgetfile"/":laddfile" commands.
void ex_cfile(exarg_T *eap)
{
  win_T *wp = NULL;
  qf_info_T *qi = &ql_info;
  char *au_name = NULL;

  au_name = cfile_get_auname(eap->cmdidx);
  if (au_name != NULL
      && apply_autocmds(EVENT_QUICKFIXCMDPRE, au_name, NULL, false, curbuf)) {
    if (aborting()) {
      return;
    }
  }
  if (*eap->arg != NUL) {
    set_option_direct(kOptErrorfile, CSTR_AS_OPTVAL(eap->arg), 0, 0);
  }

  char *enc = (*curbuf->b_p_menc != NUL) ? curbuf->b_p_menc : p_menc;

  if (is_loclist_cmd(eap->cmdidx)) {
    wp = curwin;
  }

  incr_quickfix_busy();

  // This function is used by the :cfile, :cgetfile and :caddfile
  // commands.
  // :cfile always creates a new quickfix list and may jump to the
  // first error.
  // :cgetfile creates a new quickfix list but doesn't jump to the
  // first error.
  // :caddfile adds to an existing quickfix list. If there is no
  // quickfix list then a new list is created.
  int res = qf_init(wp, p_ef, p_efm, (eap->cmdidx != CMD_caddfile
                                      && eap->cmdidx != CMD_laddfile),
                    qf_cmdtitle(*eap->cmdlinep), enc);
  if (wp != NULL) {
    qi = GET_LOC_LIST(wp);
    if (qi == NULL) {
      decr_quickfix_busy();
      return;
    }
  }
  if (res >= 0) {
    qf_list_changed(qf_get_curlist(qi));
  }
  unsigned save_qfid = qf_get_curlist(qi)->qf_id;
  if (au_name != NULL) {
    apply_autocmds(EVENT_QUICKFIXCMDPOST, au_name, NULL, false, curbuf);
  }
  // Jump to the first error for a new list and if autocmds didn't free the
  // list.
  if (res > 0 && (eap->cmdidx == CMD_cfile || eap->cmdidx == CMD_lfile)
      && qflist_valid(wp, save_qfid)) {
    // display the first error
    qf_jump_first(qi, save_qfid, eap->forceit);
  }

  decr_quickfix_busy();
}

/// Return the vimgrep autocmd name.
static char *vgr_get_auname(cmdidx_T cmdidx)
{
  switch (cmdidx) {
  case CMD_vimgrep:
    return "vimgrep";
  case CMD_lvimgrep:
    return "lvimgrep";
  case CMD_vimgrepadd:
    return "vimgrepadd";
  case CMD_lvimgrepadd:
    return "lvimgrepadd";
  case CMD_grep:
    return "grep";
  case CMD_lgrep:
    return "lgrep";
  case CMD_grepadd:
    return "grepadd";
  case CMD_lgrepadd:
    return "lgrepadd";
  default:
    return NULL;
  }
}

/// Initialize the regmatch used by vimgrep for pattern "s".
static void vgr_init_regmatch(regmmatch_T *regmatch, char *s)
{
  // Get the search pattern: either white-separated or enclosed in //.
  regmatch->regprog = NULL;

  if (s == NULL || *s == NUL) {
    // Pattern is empty, use last search pattern.
    if (last_search_pat() == NULL) {
      emsg(_(e_noprevre));
      return;
    }
    regmatch->regprog = vim_regcomp(last_search_pat(), RE_MAGIC);
  } else {
    regmatch->regprog = vim_regcomp(s, RE_MAGIC);
  }

  regmatch->rmm_ic = p_ic;
  regmatch->rmm_maxcol = 0;
}

/// Display a file name when vimgrep is running.
static void vgr_display_fname(char *fname)
{
  msg_start();
  char *p = msg_strtrunc(fname, true);
  if (p == NULL) {
    msg_outtrans(fname, 0, false);
  } else {
    msg_outtrans(p, 0, false);
    xfree(p);
  }
  msg_clr_eos();
  msg_didout = false;  // overwrite this message
  msg_nowait = true;   // don't wait for this message
  msg_col = 0;
  ui_flush();
}

/// Load a dummy buffer to search for a pattern using vimgrep.
static buf_T *vgr_load_dummy_buf(char *fname, char *dirname_start, char *dirname_now)
{
  // Don't do Filetype autocommands to avoid loading syntax and
  // indent scripts, a great speed improvement.
  char *save_ei = au_event_disable(",Filetype");

  OptInt save_mls = p_mls;
  p_mls = 0;

  // Load file into a buffer, so that 'fileencoding' is detected,
  // autocommands applied, etc.
  buf_T *buf = load_dummy_buffer(fname, dirname_start, dirname_now);

  p_mls = save_mls;
  au_event_restore(save_ei);

  return buf;
}

/// Check whether a quickfix/location list is valid. Autocmds may remove or
/// change a quickfix list when vimgrep is running. If the list is not found,
/// create a new list.
static bool vgr_qflist_valid(win_T *wp, qf_info_T *qi, unsigned qfid, char *title)
{
  // Verify that the quickfix/location list was not freed by an autocmd
  if (!qflist_valid(wp, qfid)) {
    if (wp != NULL) {
      // An autocmd has freed the location list
      emsg(_(e_current_location_list_was_changed));
      return false;
    }
    // Quickfix list is not found, create a new one.
    qf_new_list(qi, title);
    return true;
  }
  if (qf_restore_list(qi, qfid) == FAIL) {
    return false;
  }

  return true;
}

/// Search for a pattern in all the lines in a buffer and add the matching lines
/// to a quickfix list.
static bool vgr_match_buflines(qf_list_T *qfl, char *fname, buf_T *buf, char *spat,
                               regmmatch_T *regmatch, int *tomatch, int duplicate_name, int flags)
  FUNC_ATTR_NONNULL_ARG(1, 3, 4, 5, 6)
{
  bool found_match = false;
  size_t pat_len = strlen(spat);
  pat_len = MIN(pat_len, MAX_FUZZY_MATCHES);

  for (linenr_T lnum = 1; lnum <= buf->b_ml.ml_line_count && *tomatch > 0; lnum++) {
    colnr_T col = 0;
    if (!(flags & VGR_FUZZY)) {
      // Regular expression match
      while (vim_regexec_multi(regmatch, curwin, buf, lnum, col, NULL, NULL) > 0) {
        // Pass the buffer number so that it gets used even for a
        // dummy buffer, unless duplicate_name is set, then the
        // buffer will be wiped out below.
        if (qf_add_entry(qfl,
                         NULL,   // dir
                         fname,
                         NULL,
                         duplicate_name ? 0 : buf->b_fnum,
                         ml_get_buf(buf, regmatch->startpos[0].lnum + lnum),
                         regmatch->startpos[0].lnum + lnum,
                         regmatch->endpos[0].lnum + lnum,
                         regmatch->startpos[0].col + 1,
                         regmatch->endpos[0].col + 1,
                         false,  // vis_col
                         NULL,   // search pattern
                         0,      // nr
                         0,      // type
                         NULL,   // user_data
                         true)   // valid
            == QF_FAIL) {
          got_int = true;
          break;
        }
        found_match = true;
        if (--*tomatch == 0) {
          break;
        }
        if ((flags & VGR_GLOBAL) == 0 || regmatch->endpos[0].lnum > 0) {
          break;
        }
        col = regmatch->endpos[0].col + (col == regmatch->endpos[0].col);
        if (col > ml_get_buf_len(buf, lnum)) {
          break;
        }
      }
    } else {
      char *const str = ml_get_buf(buf, lnum);
      const colnr_T linelen = ml_get_buf_len(buf, lnum);
      int score;
      uint32_t matches[MAX_FUZZY_MATCHES];
      const size_t sz = sizeof(matches) / sizeof(matches[0]);

      // Fuzzy string match
      CLEAR_FIELD(matches);
      while (fuzzy_match(str + col, spat, false, &score, matches, (int)sz, true) > 0) {
        // Pass the buffer number so that it gets used even for a
        // dummy buffer, unless duplicate_name is set, then the
        // buffer will be wiped out below.
        if (qf_add_entry(qfl,
                         NULL,   // dir
                         fname,
                         NULL,
                         duplicate_name ? 0 : buf->b_fnum,
                         str,
                         lnum,
                         0,
                         (colnr_T)matches[0] + col + 1,
                         0,
                         false,  // vis_col
                         NULL,   // search pattern
                         0,      // nr
                         0,      // type
                         NULL,   // user_data
                         true)   // valid
            == QF_FAIL) {
          got_int = true;
          break;
        }
        found_match = true;
        if (--*tomatch == 0) {
          break;
        }
        if ((flags & VGR_GLOBAL) == 0) {
          break;
        }
        col = (colnr_T)matches[pat_len - 1] + col + 1;
        if (col > linelen) {
          break;
        }
      }
    }
    line_breakcheck();
    if (got_int) {
      break;
    }
  }

  return found_match;
}

/// Jump to the first match and update the directory.
static void vgr_jump_to_match(qf_info_T *qi, int forceit, bool *redraw_for_dummy,
                              buf_T *first_match_buf, char *target_dir)  // NOLINT(readability-non-const-parameter)
{
  buf_T *buf = curbuf;
  qf_jump(qi, 0, 0, forceit);
  if (buf != curbuf) {
    // If we jumped to another buffer redrawing will already be
    // taken care of.
    *redraw_for_dummy = false;
  }

  // Jump to the directory used after loading the buffer.
  if (curbuf == first_match_buf && target_dir != NULL) {
    exarg_T ea = {
      .arg = target_dir,
      .cmdidx = CMD_lcd,
    };
    ex_cd(&ea);
  }
}

// Return true if "buf" had an existing swap file, the current swap file does
// not end in ".swp".
static bool existing_swapfile(const buf_T *buf)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (buf->b_ml.ml_mfp != NULL && buf->b_ml.ml_mfp->mf_fname != NULL) {
    const char *const fname = buf->b_ml.ml_mfp->mf_fname;
    const size_t len = strlen(fname);

    return fname[len - 1] != 'p' || fname[len - 2] != 'w';
  }
  return false;
}

/// Process :vimgrep command arguments. The command syntax is:
///
/// :{count}vimgrep /{pattern}/[g][j] {file} ...
static int vgr_process_args(exarg_T *eap, vgr_args_T *args)
{
  CLEAR_POINTER(args);

  args->regmatch.regprog = NULL;
  args->qf_title = xstrdup(qf_cmdtitle(*eap->cmdlinep));
  args->tomatch = eap->addr_count > 0 ? eap->line2 : MAXLNUM;

  // Get the search pattern: either white-separated or enclosed in //
  char *p = skip_vimgrep_pat(eap->arg, &args->spat, &args->flags);
  if (p == NULL) {
    emsg(_(e_invalpat));
    return FAIL;
  }

  vgr_init_regmatch(&args->regmatch, args->spat);
  if (args->regmatch.regprog == NULL) {
    return FAIL;
  }

  p = skipwhite(p);
  if (*p == NUL) {
    emsg(_("E683: File name missing or invalid pattern"));
    return FAIL;
  }

  // Parse the list of arguments, wildcards have already been expanded.
  if (get_arglist_exp(p, &args->fcount, &args->fnames, true) == FAIL
      || args->fcount == 0) {
    emsg(_(e_nomatch));
    return FAIL;
  }

  return OK;
}

/// Search for a pattern in a list of files and populate the quickfix list with
/// the matches.
static int vgr_process_files(win_T *wp, qf_info_T *qi, vgr_args_T *cmd_args, bool *redraw_for_dummy,
                             buf_T **first_match_buf, char **target_dir)
{
  int status = FAIL;
  unsigned save_qfid = qf_get_curlist(qi)->qf_id;
  bool duplicate_name = false;

  char *dirname_start = xmalloc(MAXPATHL);
  char *dirname_now = xmalloc(MAXPATHL);

  // Remember the current directory, because a BufRead autocommand that does
  // ":lcd %:p:h" changes the meaning of short path names.
  os_dirname(dirname_start, MAXPATHL);

  time_t seconds = 0;
  for (int fi = 0; fi < cmd_args->fcount && !got_int && cmd_args->tomatch > 0; fi++) {
    char *fname = path_try_shorten_fname(cmd_args->fnames[fi]);
    if (time(NULL) > seconds) {
      // Display the file name every second or so, show the user we are
      // working on it.
      seconds = time(NULL);
      vgr_display_fname(fname);
    }

    buf_T *buf = buflist_findname_exp(cmd_args->fnames[fi]);
    bool using_dummy;
    if (buf == NULL || buf->b_ml.ml_mfp == NULL) {
      // Remember that a buffer with this name already exists.
      duplicate_name = (buf != NULL);
      using_dummy = true;
      *redraw_for_dummy = true;
      buf = vgr_load_dummy_buf(fname, dirname_start, dirname_now);
    } else {
      // Use existing, loaded buffer.
      using_dummy = false;
    }

    // Check whether the quickfix list is still valid. When loading a
    // buffer above, autocommands might have changed the quickfix list.
    if (!vgr_qflist_valid(wp, qi, save_qfid, cmd_args->qf_title)) {
      goto theend;
    }

    save_qfid = qf_get_curlist(qi)->qf_id;

    if (buf == NULL) {
      if (!got_int) {
        smsg(0, _("Cannot open file \"%s\""), fname);
      }
    } else {
      // Try for a match in all lines of the buffer.
      // For ":1vimgrep" look for first match only.
      bool found_match = vgr_match_buflines(qf_get_curlist(qi),
                                            fname,
                                            buf,
                                            cmd_args->spat,
                                            &cmd_args->regmatch,
                                            &cmd_args->tomatch,
                                            duplicate_name,
                                            cmd_args->flags);

      if (using_dummy) {
        if (found_match && *first_match_buf == NULL) {
          *first_match_buf = buf;
        }
        if (duplicate_name) {
          // Never keep a dummy buffer if there is another buffer
          // with the same name.
          wipe_dummy_buffer(buf, dirname_start);
          buf = NULL;
        } else if ((cmdmod.cmod_flags & CMOD_HIDE) == 0
                   || buf->b_p_bh[0] == 'u'             // "unload"
                   || buf->b_p_bh[0] == 'w'             // "wipe"
                   || buf->b_p_bh[0] == 'd') {          // "delete"
          // When no match was found we don't need to remember the
          // buffer, wipe it out.  If there was a match and it
          // wasn't the first one or we won't jump there: only
          // unload the buffer.
          // Ignore 'hidden' here, because it may lead to having too
          // many swap files.
          if (!found_match) {
            wipe_dummy_buffer(buf, dirname_start);
            buf = NULL;
          } else if (buf != *first_match_buf
                     || (cmd_args->flags & VGR_NOJUMP)
                     || existing_swapfile(buf)) {
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
          if (buf == *first_match_buf
              && *target_dir == NULL
              && strcmp(dirname_start, dirname_now) != 0) {
            *target_dir = xstrdup(dirname_now);
          }

          // The buffer is still loaded, the Filetype autocommands
          // need to be done now, in that buffer.  And the modelines
          // need to be done (again).  But not the window-local
          // options!
          aco_save_T aco;
          aucmd_prepbuf(&aco, buf);
          apply_autocmds(EVENT_FILETYPE, buf->b_p_ft, buf->b_fname, true, buf);
          do_modelines(OPT_NOWIN);
          aucmd_restbuf(&aco);
        }
      }
    }
  }

  status = OK;

theend:
  xfree(dirname_now);
  xfree(dirname_start);
  return status;
}

/// ":vimgrep {pattern} file(s)"
/// ":vimgrepadd {pattern} file(s)"
/// ":lvimgrep {pattern} file(s)"
/// ":lvimgrepadd {pattern} file(s)"
void ex_vimgrep(exarg_T *eap)
{
  if (!check_can_set_curbuf_forceit(eap->forceit)) {
    return;
  }

  char *au_name = vgr_get_auname(eap->cmdidx);
  if (au_name != NULL && apply_autocmds(EVENT_QUICKFIXCMDPRE, au_name,
                                        curbuf->b_fname, true, curbuf)) {
    if (aborting()) {
      return;
    }
  }

  win_T *wp = NULL;
  qf_info_T *qi = qf_cmd_get_or_alloc_stack(eap, &wp);
  char *target_dir = NULL;
  vgr_args_T args;
  if (vgr_process_args(eap, &args) == FAIL) {
    goto theend;
  }

  if ((eap->cmdidx != CMD_grepadd && eap->cmdidx != CMD_lgrepadd
       && eap->cmdidx != CMD_vimgrepadd && eap->cmdidx != CMD_lvimgrepadd)
      || qf_stack_empty(qi)) {
    // make place for a new list
    qf_new_list(qi, args.qf_title);
  }

  incr_quickfix_busy();

  bool redraw_for_dummy = false;
  buf_T *first_match_buf = NULL;
  int status = vgr_process_files(wp, qi, &args, &redraw_for_dummy, &first_match_buf, &target_dir);

  if (status != OK) {
    FreeWild(args.fcount, args.fnames);
    decr_quickfix_busy();
    goto theend;
  }

  FreeWild(args.fcount, args.fnames);

  qf_list_T *qfl = qf_get_curlist(qi);
  qfl->qf_nonevalid = false;
  qfl->qf_ptr = qfl->qf_start;
  qfl->qf_index = 1;
  qf_list_changed(qfl);

  qf_update_buffer(qi, NULL);

  // Remember the current quickfix list identifier, so that we can check for
  // autocommands changing the current quickfix list.
  unsigned save_qfid = qf_get_curlist(qi)->qf_id;

  if (au_name != NULL) {
    apply_autocmds(EVENT_QUICKFIXCMDPOST, au_name, curbuf->b_fname, true, curbuf);
  }

  // The QuickFixCmdPost autocmd may free the quickfix list. Check the list
  // is still valid.
  if (!qflist_valid(wp, save_qfid) || qf_restore_list(qi, save_qfid) == FAIL) {
    decr_quickfix_busy();
    goto theend;
  }

  // Jump to first match.
  if (!qf_list_empty(qf_get_curlist(qi))) {
    if ((args.flags & VGR_NOJUMP) == 0) {
      vgr_jump_to_match(qi, eap->forceit, &redraw_for_dummy, first_match_buf, target_dir);
    }
  } else {
    semsg(_(e_nomatch2), args.spat);
  }

  decr_quickfix_busy();

  // If we loaded a dummy buffer into the current window, the autocommands
  // may have messed up things, need to redraw and recompute folds.
  if (redraw_for_dummy) {
    foldUpdateAll(curwin);
  }

theend:
  xfree(args.qf_title);
  xfree(target_dir);
  vim_regfree(args.regmatch.regprog);
}

// Restore current working directory to "dirname_start" if they differ, taking
// into account whether it is set locally or globally.
static void restore_start_dir(char *dirname_start)
  FUNC_ATTR_NONNULL_ALL
{
  char *dirname_now = xmalloc(MAXPATHL);

  os_dirname(dirname_now, MAXPATHL);
  if (strcmp(dirname_start, dirname_now) != 0) {
    // If the directory has changed, change it back by building up an
    // appropriate ex command and executing it.
    exarg_T ea = {
      .arg = dirname_start,
      .cmdidx = (curwin->w_localdir == NULL) ? CMD_cd : CMD_lcd,
    };
    ex_cd(&ea);
  }
  xfree(dirname_now);
}

/// Load file "fname" into a dummy buffer and return the buffer pointer,
/// placing the directory resulting from the buffer load into the
/// "resulting_dir" pointer. "resulting_dir" must be allocated by the caller
/// prior to calling this function. Restores directory to "dirname_start" prior
/// to returning, if autocmds or the 'autochdir' option have changed it.
///
/// If creating the dummy buffer does not fail, must call unload_dummy_buffer()
/// or wipe_dummy_buffer() later!
///
/// @param dirname_start  in: old directory
/// @param resulting_dir  out: new directory
///
/// @return  NULL if it fails.
static buf_T *load_dummy_buffer(char *fname, char *dirname_start, char *resulting_dir)
{
  // Allocate a buffer without putting it in the buffer list.
  buf_T *newbuf = buflist_new(NULL, NULL, 1, BLN_DUMMY);
  if (newbuf == NULL) {
    return NULL;
  }

  bool failed = true;
  bufref_T newbufref;
  set_bufref(&newbufref, newbuf);

  // Init the options.
  buf_copy_options(newbuf, BCO_ENTER | BCO_NOHELP);

  // need to open the memfile before putting the buffer in a window
  if (ml_open(newbuf) == OK) {
    // Make sure this buffer isn't wiped out by autocommands.
    newbuf->b_locked++;
    // set curwin/curbuf to buf and save a few things
    aco_save_T aco;
    aucmd_prepbuf(&aco, newbuf);

    // Need to set the filename for autocommands.
    setfname(curbuf, fname, NULL, false);

    // Create swap file now to avoid the ATTENTION message.
    check_need_swap(true);

    // Remove the "dummy" flag, otherwise autocommands may not
    // work.
    curbuf->b_flags &= ~BF_DUMMY;

    bufref_T newbuf_to_wipe;
    newbuf_to_wipe.br_buf = NULL;
    int readfile_result = readfile(fname, NULL, 0, 0,
                                   (linenr_T)MAXLNUM, NULL,
                                   READ_NEW | READ_DUMMY, false);
    newbuf->b_locked--;
    if (readfile_result == OK
        && !got_int
        && !(curbuf->b_flags & BF_NEW)) {
      failed = false;
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

  // When autocommands/'autochdir' option changed directory: go back.
  // Let the caller know what the resulting dir was first, in case it is
  // important.
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

// Wipe out the dummy buffer that load_dummy_buffer() created. Restores
// directory to "dirname_start" prior to returning, if autocmds or the
// 'autochdir' option have changed it.
static void wipe_dummy_buffer(buf_T *buf, char *dirname_start)
  FUNC_ATTR_NONNULL_ALL
{
  // If any autocommand opened a window on the dummy buffer, close that
  // window.  If we can't close them all then give up.
  while (buf->b_nwindows > 0) {
    bool did_one = false;

    if (firstwin->w_next != NULL) {
      for (win_T *wp = firstwin; wp != NULL; wp = wp->w_next) {
        if (wp->w_buffer == buf) {
          if (win_close(wp, false, false) == OK) {
            did_one = true;
          }
          break;
        }
      }
    }
    if (!did_one) {
      return;
    }
  }

  if (curbuf != buf && buf->b_nwindows == 0) {  // safety check
    cleanup_T cs;

    // Reset the error/interrupt/exception state here so that aborting()
    // returns false when wiping out the buffer.  Otherwise it doesn't
    // work when got_int is set.
    enter_cleanup(&cs);

    wipe_buffer(buf, true);

    // Restore the error/interrupt/exception state if not discarded by a
    // new aborting error, interrupt, or uncaught exception.
    leave_cleanup(&cs);
    // When autocommands/'autochdir' option changed directory: go back.
    restore_start_dir(dirname_start);
  }
}

// Unload the dummy buffer that load_dummy_buffer() created. Restores
// directory to "dirname_start" prior to returning, if autocmds or the
// 'autochdir' option have changed it.
static void unload_dummy_buffer(buf_T *buf, char *dirname_start)
{
  if (curbuf == buf) {          // safety check
    return;
  }

  close_buffer(NULL, buf, DOBUF_UNLOAD, false, true);

  // When autocommands/'autochdir' option changed directory: go back.
  restore_start_dir(dirname_start);
}

/// Copy the specified quickfix entry items into a new dict and append the dict
/// to 'list'.  Returns OK on success.
static int get_qfline_items(qfline_T *qfp, list_T *list)
{
  // Handle entries with a non-existing buffer number.
  int bufnum = qfp->qf_fnum;
  if (bufnum != 0 && (buflist_findnr(bufnum) == NULL)) {
    bufnum = 0;
  }

  dict_T *const dict = tv_dict_alloc();
  tv_list_append_dict(list, dict);

  char buf[2];
  buf[0] = qfp->qf_type;
  buf[1] = NUL;
  if (tv_dict_add_nr(dict, S_LEN("bufnr"), (varnumber_T)bufnum) == FAIL
      || (tv_dict_add_nr(dict, S_LEN("lnum"), (varnumber_T)qfp->qf_lnum) == FAIL)
      || (tv_dict_add_nr(dict, S_LEN("end_lnum"), (varnumber_T)qfp->qf_end_lnum) == FAIL)
      || (tv_dict_add_nr(dict, S_LEN("col"), (varnumber_T)qfp->qf_col) == FAIL)
      || (tv_dict_add_nr(dict, S_LEN("end_col"), (varnumber_T)qfp->qf_end_col) == FAIL)
      || (tv_dict_add_nr(dict, S_LEN("vcol"), (varnumber_T)qfp->qf_viscol) == FAIL)
      || (tv_dict_add_nr(dict, S_LEN("nr"), (varnumber_T)qfp->qf_nr) == FAIL)
      || (tv_dict_add_str(dict, S_LEN("module"), (qfp->qf_module == NULL ? "" : qfp->qf_module))
          == FAIL)
      || (tv_dict_add_str(dict, S_LEN("pattern"), (qfp->qf_pattern == NULL ? "" : qfp->qf_pattern))
          == FAIL)
      || (tv_dict_add_str(dict, S_LEN("text"), (qfp->qf_text == NULL ? "" : qfp->qf_text)) == FAIL)
      || (tv_dict_add_str(dict, S_LEN("type"), buf) == FAIL)
      || (qfp->qf_user_data.v_type != VAR_UNKNOWN
          && tv_dict_add_tv(dict, S_LEN("user_data"), &qfp->qf_user_data) == FAIL)
      || (tv_dict_add_nr(dict, S_LEN("valid"), (varnumber_T)qfp->qf_valid) == FAIL)) {
    // tv_dict_add* fail only if key already exist, but this is a newly
    // allocated dictionary which is thus guaranteed to have no existing keys.
    abort();
  }

  return OK;
}

/// Add each quickfix error to list "list" as a dictionary.
/// If qf_idx is -1, use the current list. Otherwise, use the specified list.
/// If eidx is not 0, then return only the specified entry. Otherwise return
/// all the entries.
static int get_errorlist(qf_info_T *qi_arg, win_T *wp, int qf_idx, int eidx, list_T *list)
{
  qf_info_T *qi = qi_arg;

  if (qi == NULL) {
    qi = &ql_info;
    if (wp != NULL) {
      qi = GET_LOC_LIST(wp);
      if (qi == NULL) {
        return FAIL;
      }
    }
  }

  if (eidx < 0) {
    return OK;
  }

  if (qf_idx == INVALID_QFIDX) {
    qf_idx = qi->qf_curlist;
  }

  if (qf_idx >= qi->qf_listcount) {
    return FAIL;
  }

  qf_list_T *qfl = qf_get_list(qi, qf_idx);
  if (qf_list_empty(qfl)) {
    return FAIL;
  }

  qfline_T *qfp;
  int i;
  FOR_ALL_QFL_ITEMS(qfl, qfp, i) {
    if (eidx > 0) {
      if (eidx == i) {
        return get_qfline_items(qfp, list);
      }
    } else if (get_qfline_items(qfp, list) == FAIL) {
      return FAIL;
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
  QF_GETLIST_TICK = 0x100,
  QF_GETLIST_FILEWINID = 0x200,
  QF_GETLIST_QFBUFNR = 0x400,
  QF_GETLIST_QFTF = 0x800,
  QF_GETLIST_ALL = 0xFFF,
};

/// Parse text from 'di' and return the quickfix list items.
/// Existing quickfix lists are not modified.
static int qf_get_list_from_lines(dict_T *what, dictitem_T *di, dict_T *retdict)
{
  int status = FAIL;

  // Only a List value is supported
  if (di->di_tv.v_type != VAR_LIST || di->di_tv.vval.v_list == NULL) {
    return FAIL;
  }

  char *errorformat = p_efm;
  dictitem_T *efm_di;
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
  qf_info_T *const qi = qf_alloc_stack(QFLT_INTERNAL);

  if (qf_init_ext(qi, 0, NULL, NULL, &di->di_tv, errorformat,
                  true, 0, 0, NULL, NULL) > 0) {
    get_errorlist(qi, NULL, 0, 0, l);
    qf_free(&qi->qf_lists[0]);
  }
  xfree(qi);

  tv_dict_add_list(retdict, S_LEN("items"), l);
  status = OK;

  return status;
}

/// Return the quickfix/location list window identifier in the current tabpage.
static int qf_winid(qf_info_T *qi)
{
  // The quickfix window can be opened even if the quickfix list is not set
  // using ":copen". This is not true for location lists.
  if (qi == NULL) {
    return 0;
  }
  win_T *win = qf_find_win(qi);
  if (win != NULL) {
    return win->handle;
  }
  return 0;
}

/// Returns the number of the buffer displayed in the quickfix/location list
/// window. If there is no buffer associated with the list or the buffer is
/// wiped out, then returns 0.
static int qf_getprop_qfbufnr(const qf_info_T *qi, dict_T *retdict)
  FUNC_ATTR_NONNULL_ARG(2)
{
  int bufnum = 0;

  if (qi != NULL && buflist_findnr(qi->qf_bufnr) != NULL) {
    bufnum = qi->qf_bufnr;
  }

  return tv_dict_add_nr(retdict, S_LEN("qfbufnr"), bufnum);
}

/// Convert the keys in 'what' to quickfix list property flags.
static int qf_getprop_keys2flags(const dict_T *what, bool loclist)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  int flags = QF_GETLIST_NONE;

  if (tv_dict_find(what, S_LEN("all")) != NULL) {
    flags |= QF_GETLIST_ALL;
    if (!loclist) {
      // File window ID is applicable only to location list windows
      flags &= ~QF_GETLIST_FILEWINID;
    }
  }
  if (tv_dict_find(what, S_LEN("title")) != NULL) {
    flags |= QF_GETLIST_TITLE;
  }
  if (tv_dict_find(what, S_LEN("nr")) != NULL) {
    flags |= QF_GETLIST_NR;
  }
  if (tv_dict_find(what, S_LEN("winid")) != NULL) {
    flags |= QF_GETLIST_WINID;
  }
  if (tv_dict_find(what, S_LEN("context")) != NULL) {
    flags |= QF_GETLIST_CONTEXT;
  }
  if (tv_dict_find(what, S_LEN("id")) != NULL) {
    flags |= QF_GETLIST_ID;
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
  if (tv_dict_find(what, S_LEN("changedtick")) != NULL) {
    flags |= QF_GETLIST_TICK;
  }
  if (loclist && tv_dict_find(what, S_LEN("filewinid")) != NULL) {
    flags |= QF_GETLIST_FILEWINID;
  }
  if (tv_dict_find(what, S_LEN("qfbufnr")) != NULL) {
    flags |= QF_GETLIST_QFBUFNR;
  }
  if (tv_dict_find(what, S_LEN("quickfixtextfunc")) != NULL) {
    flags |= QF_GETLIST_QFTF;
  }

  return flags;
}

/// Return the quickfix list index based on 'nr' or 'id' in 'what'.
///
/// If 'nr' and 'id' are not present in 'what' then return the current
/// quickfix list index.
/// If 'nr' is zero then return the current quickfix list index.
/// If 'nr' is '$' then return the last quickfix list index.
/// If 'id' is present then return the index of the quickfix list with that id.
/// If 'id' is zero then return the quickfix list index specified by 'nr'.
/// Return -1, if quickfix list is not present or if the stack is empty.
static int qf_getprop_qfidx(qf_info_T *qi, dict_T *what)
{
  dictitem_T *di = NULL;

  int qf_idx = qi->qf_curlist;  // default is the current list
  if ((di = tv_dict_find(what, S_LEN("nr"))) != NULL) {
    // Use the specified quickfix/location list
    if (di->di_tv.v_type == VAR_NUMBER) {
      // for zero use the current list
      if (di->di_tv.vval.v_number != 0) {
        qf_idx = (int)di->di_tv.vval.v_number - 1;
        if (qf_idx < 0 || qf_idx >= qi->qf_listcount) {
          qf_idx = INVALID_QFIDX;
        }
      }
    } else if (di->di_tv.v_type == VAR_STRING && strequal(di->di_tv.vval.v_string, "$")) {
      // Get the last quickfix list number
      qf_idx = qi->qf_listcount - 1;
    } else {
      qf_idx = INVALID_QFIDX;
    }
  }

  if ((di = tv_dict_find(what, S_LEN("id"))) != NULL) {
    // Look for a list with the specified id
    if (di->di_tv.v_type == VAR_NUMBER) {
      // For zero, use the current list or the list specified by 'nr'
      if (di->di_tv.vval.v_number != 0) {
        qf_idx = qf_id2nr(qi, (unsigned)di->di_tv.vval.v_number);
      }
    } else {
      qf_idx = INVALID_QFIDX;
    }
  }

  return qf_idx;
}

/// Return default values for quickfix list properties in retdict.
static int qf_getprop_defaults(qf_info_T *qi, int flags, int locstack, dict_T *retdict)
{
  int status = OK;

  if (flags & QF_GETLIST_TITLE) {
    status = tv_dict_add_str(retdict, S_LEN("title"), "");
  }
  if ((status == OK) && (flags & QF_GETLIST_ITEMS)) {
    list_T *l = tv_list_alloc(kListLenMayKnow);
    status = tv_dict_add_list(retdict, S_LEN("items"), l);
  }
  if ((status == OK) && (flags & QF_GETLIST_NR)) {
    status = tv_dict_add_nr(retdict, S_LEN("nr"), 0);
  }
  if ((status == OK) && (flags & QF_GETLIST_WINID)) {
    status = tv_dict_add_nr(retdict, S_LEN("winid"), qf_winid(qi));
  }
  if ((status == OK) && (flags & QF_GETLIST_CONTEXT)) {
    status = tv_dict_add_str(retdict, S_LEN("context"), "");
  }
  if ((status == OK) && (flags & QF_GETLIST_ID)) {
    status = tv_dict_add_nr(retdict, S_LEN("id"), 0);
  }
  if ((status == OK) && (flags & QF_GETLIST_IDX)) {
    status = tv_dict_add_nr(retdict, S_LEN("idx"), 0);
  }
  if ((status == OK) && (flags & QF_GETLIST_SIZE)) {
    status = tv_dict_add_nr(retdict, S_LEN("size"), 0);
  }
  if ((status == OK) && (flags & QF_GETLIST_TICK)) {
    status = tv_dict_add_nr(retdict, S_LEN("changedtick"), 0);
  }
  if ((status == OK) && locstack && (flags & QF_GETLIST_FILEWINID)) {
    status = tv_dict_add_nr(retdict, S_LEN("filewinid"), 0);
  }
  if ((status == OK) && (flags & QF_GETLIST_QFBUFNR)) {
    status = qf_getprop_qfbufnr(qi, retdict);
  }
  if ((status == OK) && (flags & QF_GETLIST_QFTF)) {
    status = tv_dict_add_str(retdict, S_LEN("quickfixtextfunc"), "");
  }

  return status;
}

/// Return the quickfix list title as 'title' in retdict
static int qf_getprop_title(qf_list_T *qfl, dict_T *retdict)
{
  return tv_dict_add_str(retdict, S_LEN("title"), qfl->qf_title);
}

// Returns the identifier of the window used to display files from a location
// list.  If there is no associated window, then returns 0. Useful only when
// called from a location list window.
static int qf_getprop_filewinid(const win_T *wp, const qf_info_T *qi, dict_T *retdict)
  FUNC_ATTR_NONNULL_ARG(3)
{
  handle_T winid = 0;

  if (wp != NULL && IS_LL_WINDOW(wp)) {
    win_T *ll_wp = qf_find_win_with_loclist(qi);
    if (ll_wp != NULL) {
      winid = ll_wp->handle;
    }
  }

  return tv_dict_add_nr(retdict, S_LEN("filewinid"), winid);
}

/// Return the quickfix list items/entries as 'items' in retdict.
/// If eidx is not 0, then return the item at the specified index.
static int qf_getprop_items(qf_info_T *qi, int qf_idx, int eidx, dict_T *retdict)
{
  list_T *l = tv_list_alloc(kListLenMayKnow);
  get_errorlist(qi, NULL, qf_idx, eidx, l);
  tv_dict_add_list(retdict, S_LEN("items"), l);

  return OK;
}

/// Return the quickfix list context (if any) as 'context' in retdict.
static int qf_getprop_ctx(qf_list_T *qfl, dict_T *retdict)
{
  int status;

  if (qfl->qf_ctx != NULL) {
    dictitem_T *di = tv_dict_item_alloc_len(S_LEN("context"));
    tv_copy(qfl->qf_ctx, &di->di_tv);
    status = tv_dict_add(retdict, di);
    if (status == FAIL) {
      tv_dict_item_free(di);
    }
  } else {
    status = tv_dict_add_str(retdict, S_LEN("context"), "");
  }

  return status;
}

/// Return the current quickfix list index as 'idx' in retdict.
/// If a specific entry index (eidx) is supplied, then use that.
static int qf_getprop_idx(qf_list_T *qfl, int eidx, dict_T *retdict)
{
  if (eidx == 0) {
    eidx = qfl->qf_index;
    if (qf_list_empty(qfl)) {
      // For empty lists, current index is set to 0
      eidx = 0;
    }
  }
  return tv_dict_add_nr(retdict, S_LEN("idx"), eidx);
}

/// Return the 'quickfixtextfunc' function of a quickfix/location list
/// @return OK or FAIL
static int qf_getprop_qftf(qf_list_T *qfl, dict_T *retdict)
  FUNC_ATTR_NONNULL_ALL
{
  int status;

  if (qfl->qf_qftf_cb.type != kCallbackNone) {
    typval_T tv;

    callback_put(&qfl->qf_qftf_cb, &tv);
    status = tv_dict_add_tv(retdict, S_LEN("quickfixtextfunc"), &tv);
    tv_clear(&tv);
  } else {
    status = tv_dict_add_str(retdict, S_LEN("quickfixtextfunc"), "");
  }

  return status;
}

/// Return quickfix/location list details (title) as a dictionary.
/// 'what' contains the details to return. If 'list_idx' is -1,
/// then current list is used. Otherwise the specified list is used.
static int qf_get_properties(win_T *wp, dict_T *what, dict_T *retdict)
{
  qf_info_T *qi = &ql_info;
  dictitem_T *di = NULL;
  int status = OK;
  int qf_idx = INVALID_QFIDX;

  if ((di = tv_dict_find(what, S_LEN("lines"))) != NULL) {
    return qf_get_list_from_lines(what, di, retdict);
  }

  if (wp != NULL) {
    qi = GET_LOC_LIST(wp);
  }

  const int flags = qf_getprop_keys2flags(what, wp != NULL);

  if (!qf_stack_empty(qi)) {
    qf_idx = qf_getprop_qfidx(qi, what);
  }

  // List is not present or is empty
  if (qf_stack_empty(qi) || qf_idx == INVALID_QFIDX) {
    return qf_getprop_defaults(qi, flags, wp != NULL, retdict);
  }

  qf_list_T *qfl = qf_get_list(qi, qf_idx);
  int eidx = 0;

  // If an entry index is specified, use that
  if ((di = tv_dict_find(what, S_LEN("idx"))) != NULL) {
    if (di->di_tv.v_type != VAR_NUMBER) {
      return FAIL;
    }
    eidx = (int)di->di_tv.vval.v_number;
  }

  if (flags & QF_GETLIST_TITLE) {
    status = qf_getprop_title(qfl, retdict);
  }
  if ((status == OK) && (flags & QF_GETLIST_NR)) {
    status = tv_dict_add_nr(retdict, S_LEN("nr"), qf_idx + 1);
  }
  if ((status == OK) && (flags & QF_GETLIST_WINID)) {
    status = tv_dict_add_nr(retdict, S_LEN("winid"), qf_winid(qi));
  }
  if ((status == OK) && (flags & QF_GETLIST_ITEMS)) {
    status = qf_getprop_items(qi, qf_idx, eidx, retdict);
  }
  if ((status == OK) && (flags & QF_GETLIST_CONTEXT)) {
    status = qf_getprop_ctx(qfl, retdict);
  }
  if ((status == OK) && (flags & QF_GETLIST_ID)) {
    status = tv_dict_add_nr(retdict, S_LEN("id"), qfl->qf_id);
  }
  if ((status == OK) && (flags & QF_GETLIST_IDX)) {
    status = qf_getprop_idx(qfl, eidx, retdict);
  }
  if ((status == OK) && (flags & QF_GETLIST_SIZE)) {
    status = tv_dict_add_nr(retdict, S_LEN("size"),
                            qfl->qf_count);
  }
  if ((status == OK) && (flags & QF_GETLIST_TICK)) {
    status = tv_dict_add_nr(retdict, S_LEN("changedtick"),
                            qfl->qf_changedtick);
  }
  if ((status == OK) && (wp != NULL) && (flags & QF_GETLIST_FILEWINID)) {
    status = qf_getprop_filewinid(wp, qi, retdict);
  }
  if ((status == OK) && (flags & QF_GETLIST_QFBUFNR)) {
    status = qf_getprop_qfbufnr(qi, retdict);
  }
  if ((status == OK) && (flags & QF_GETLIST_QFTF)) {
    status = qf_getprop_qftf(qfl, retdict);
  }

  return status;
}

/// Set the current index in the specified quickfix list
/// @return OK
static int qf_setprop_qftf(qf_list_T *qfl, dictitem_T *di)
  FUNC_ATTR_NONNULL_ALL
{
  Callback cb;

  callback_free(&qfl->qf_qftf_cb);
  if (callback_from_typval(&cb, &di->di_tv)) {
    qfl->qf_qftf_cb = cb;
  }
  return OK;
}

/// Add a new quickfix entry to list at 'qf_idx' in the stack 'qi' from the
/// items in the dict 'd'. If it is a valid error entry, then set 'valid_entry'
/// to true.
static int qf_add_entry_from_dict(qf_list_T *qfl, dict_T *d, bool first_entry, bool *valid_entry)
  FUNC_ATTR_NONNULL_ALL
{
  static bool did_bufnr_emsg;

  if (first_entry) {
    did_bufnr_emsg = false;
  }

  char *const filename = tv_dict_get_string(d, "filename", true);
  char *const module = tv_dict_get_string(d, "module", true);
  int bufnum = (int)tv_dict_get_number(d, "bufnr");
  const linenr_T lnum = (linenr_T)tv_dict_get_number(d, "lnum");
  const linenr_T end_lnum = (linenr_T)tv_dict_get_number(d, "end_lnum");
  const int col = (int)tv_dict_get_number(d, "col");
  const int end_col = (int)tv_dict_get_number(d, "end_col");
  const char vcol = (char)tv_dict_get_number(d, "vcol");
  const int nr = (int)tv_dict_get_number(d, "nr");
  const char *const type = tv_dict_get_string(d, "type", false);
  char *const pattern = tv_dict_get_string(d, "pattern", true);
  char *text = tv_dict_get_string(d, "text", true);
  if (text == NULL) {
    text = xcalloc(1, 1);
  }
  typval_T user_data = { .v_type = VAR_UNKNOWN };
  tv_dict_get_tv(d, "user_data", &user_data);

  bool valid = true;
  if ((filename == NULL && bufnum == 0)
      || (lnum == 0 && pattern == NULL)) {
    valid = false;
  }

  // Mark entries with non-existing buffer number as not valid. Give the
  // error message only once.
  if (bufnum != 0 && (buflist_findnr(bufnum) == NULL)) {
    if (!did_bufnr_emsg) {
      did_bufnr_emsg = true;
      semsg(_("E92: Buffer %" PRId64 " not found"), (int64_t)bufnum);
    }
    valid = false;
    bufnum = 0;
  }

  // If the 'valid' field is present it overrules the detected value.
  if (tv_dict_find(d, "valid", -1) != NULL) {
    valid = tv_dict_get_number(d, "valid");
  }

  const int status = qf_add_entry(qfl,
                                  NULL,      // dir
                                  filename,
                                  module,
                                  bufnum,
                                  text,
                                  lnum,
                                  end_lnum,
                                  col,
                                  end_col,
                                  vcol,      // vis_col
                                  pattern,   // search pattern
                                  nr,
                                  type == NULL ? NUL : *type,
                                  &user_data,
                                  valid);

  xfree(filename);
  xfree(module);
  xfree(pattern);
  xfree(text);
  tv_clear(&user_data);

  if (valid) {
    *valid_entry = true;
  }

  return status;
}

/// Check if `entry` is closer to the target than `other_entry`.
///
/// Only returns true if `entry` is definitively closer. If it's further
/// away, or there's not enough information to tell, return false.
static bool entry_is_closer_to_target(qfline_T *entry, qfline_T *other_entry, int target_fnum,
                                      int target_lnum, int target_col)
{
  // First, compare entries to target file.
  if (!target_fnum) {
    // Without a target file, we can't know which is closer.
    return false;
  }

  bool is_target_file = entry->qf_fnum && entry->qf_fnum == target_fnum;
  bool other_is_target_file = other_entry->qf_fnum && other_entry->qf_fnum == target_fnum;
  if (!is_target_file && other_is_target_file) {
    return false;
  } else if (is_target_file && !other_is_target_file) {
    return true;
  }

  // Both entries are pointing at the exact same file. Now compare line numbers.
  if (!target_lnum) {
    // Without a target line number, we can't know which is closer.
    return false;
  }

  int line_distance = entry->qf_lnum
                      ? abs(entry->qf_lnum - target_lnum) : INT_MAX;
  int other_line_distance = other_entry->qf_lnum
                            ? abs(other_entry->qf_lnum - target_lnum) : INT_MAX;
  if (line_distance > other_line_distance) {
    return false;
  } else if (line_distance < other_line_distance) {
    return true;
  }

  // Both entries are pointing at the exact same line number (or no line
  // number at all). Now compare columns.
  if (!target_col) {
    // Without a target column, we can't know which is closer.
    return false;
  }

  int column_distance = entry->qf_col
                        ? abs(entry->qf_col - target_col) : INT_MAX;
  int other_column_distance = other_entry->qf_col
                              ? abs(other_entry->qf_col - target_col) : INT_MAX;
  if (column_distance > other_column_distance) {
    return false;
  } else if (column_distance < other_column_distance) {
    return true;
  }

  // It's a complete tie! The exact same file, line, and column.
  return false;
}

/// Add list of entries to quickfix/location list. Each list entry is
/// a dictionary with item information.
static int qf_add_entries(qf_info_T *qi, int qf_idx, list_T *list, char *title, int action)
{
  qf_list_T *qfl = qf_get_list(qi, qf_idx);
  qfline_T *old_last = NULL;
  int retval = OK;
  bool valid_entry = false;

  // If there's an entry selected in the quickfix list, remember its location
  // (file, line, column), so we can select the nearest entry in the updated
  // quickfix list.
  int prev_fnum = 0;
  int prev_lnum = 0;
  int prev_col = 0;
  if (qfl->qf_ptr) {
    prev_fnum = qfl->qf_ptr->qf_fnum;
    prev_lnum = qfl->qf_ptr->qf_lnum;
    prev_col = qfl->qf_ptr->qf_col;
  }

  bool select_first_entry = false;
  bool select_nearest_entry = false;

  if (action == ' ' || qf_idx == qi->qf_listcount) {
    select_first_entry = true;
    // make place for a new list
    qf_new_list(qi, title);
    qf_idx = qi->qf_curlist;
    qfl = qf_get_list(qi, qf_idx);
  } else if (action == 'a') {
    if (qf_list_empty(qfl)) {
      // Appending to empty list, select first entry.
      select_first_entry = true;
    } else {
      // Adding to existing list, use last entry.
      old_last = qfl->qf_last;
    }
  } else if (action == 'r') {
    select_first_entry = true;
    qf_free_items(qfl);
    qf_store_title(qfl, title);
  } else if (action == 'u') {
    select_nearest_entry = true;
    qf_free_items(qfl);
    qf_store_title(qfl, title);
  }

  qfline_T *entry_to_select = NULL;
  int entry_to_select_index = 0;

  TV_LIST_ITER_CONST(list, li, {
    if (TV_LIST_ITEM_TV(li)->v_type != VAR_DICT) {
      continue;  // Skip non-dict items.
    }

    dict_T *const d = TV_LIST_ITEM_TV(li)->vval.v_dict;
    if (d == NULL) {
      continue;
    }

    retval = qf_add_entry_from_dict(qfl, d, li == tv_list_first(list), &valid_entry);
    if (retval == QF_FAIL) {
      break;
    }

    qfline_T *entry = qfl->qf_last;
    if ((select_first_entry && entry_to_select == NULL)
        || (select_nearest_entry
            && (entry_to_select == NULL
                || entry_is_closer_to_target(entry, entry_to_select, prev_fnum,
                                             prev_lnum, prev_col)))) {
      entry_to_select = entry;
      entry_to_select_index = qfl->qf_count;
    }
  });

  // Check if any valid error entries are added to the list.
  if (valid_entry) {
    qfl->qf_nonevalid = false;
  } else if (qfl->qf_index == 0) {
    qfl->qf_nonevalid = true;
  }

  // Set the current error.
  if (entry_to_select) {
    qfl->qf_ptr = entry_to_select;
    qfl->qf_index = entry_to_select_index;
  }

  // Don't update the cursor in quickfix window when appending entries
  qf_update_buffer(qi, old_last);

  return retval;
}

/// Get the quickfix list index from 'nr' or 'id'
static int qf_setprop_get_qfidx(const qf_info_T *qi, const dict_T *what, int action, bool *newlist)
  FUNC_ATTR_NONNULL_ALL
{
  dictitem_T *di;
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
        *newlist = true;
        qf_idx = qf_stack_empty(qi) ? 0 : qi->qf_listcount - 1;
      } else if (qf_idx < 0 || qf_idx >= qi->qf_listcount) {
        return INVALID_QFIDX;
      } else if (action != ' ') {
        *newlist = false;  // use the specified list
      }
    } else if (di->di_tv.v_type == VAR_STRING && strequal(di->di_tv.vval.v_string, "$")) {
      if (!qf_stack_empty(qi)) {
        qf_idx = qi->qf_listcount - 1;
      } else if (*newlist) {
        qf_idx = 0;
      } else {
        return INVALID_QFIDX;
      }
    } else {
      return INVALID_QFIDX;
    }
  }

  if (!*newlist && (di = tv_dict_find(what, S_LEN("id"))) != NULL) {
    // Use the quickfix/location list with the specified id
    if (di->di_tv.v_type != VAR_NUMBER) {
      return INVALID_QFIDX;
    }
    return qf_id2nr(qi, (unsigned)di->di_tv.vval.v_number);
  }

  return qf_idx;
}

// Set the quickfix list title.
static int qf_setprop_title(qf_info_T *qi, int qf_idx, const dict_T *what, const dictitem_T *di)
  FUNC_ATTR_NONNULL_ALL
{
  qf_list_T *qfl = qf_get_list(qi, qf_idx);
  if (di->di_tv.v_type != VAR_STRING) {
    return FAIL;
  }

  xfree(qfl->qf_title);
  qfl->qf_title = tv_dict_get_string(what, "title", true);
  if (qf_idx == qi->qf_curlist) {
    qf_update_win_titlevar(qi);
  }

  return OK;
}

// Set quickfix list items/entries.
static int qf_setprop_items(qf_info_T *qi, int qf_idx, dictitem_T *di, int action)
  FUNC_ATTR_NONNULL_ALL
{
  if (di->di_tv.v_type != VAR_LIST) {
    return FAIL;
  }

  char *title_save = xstrdup(qi->qf_lists[qf_idx].qf_title);
  const int retval = qf_add_entries(qi, qf_idx, di->di_tv.vval.v_list, title_save,
                                    action == ' ' ? 'a' : action);
  xfree(title_save);

  return retval;
}

// Set quickfix list items/entries from a list of lines.
static int qf_setprop_items_from_lines(qf_info_T *qi, int qf_idx, const dict_T *what,
                                       dictitem_T *di, int action)
  FUNC_ATTR_NONNULL_ALL
{
  char *errorformat = p_efm;
  dictitem_T *efm_di;
  int retval = FAIL;

  // Use the user supplied errorformat settings (if present)
  if ((efm_di = tv_dict_find(what, S_LEN("efm"))) != NULL) {
    if (efm_di->di_tv.v_type != VAR_STRING
        || efm_di->di_tv.vval.v_string == NULL) {
      return FAIL;
    }
    errorformat = efm_di->di_tv.vval.v_string;
  }

  // Only a List value is supported
  if (di->di_tv.v_type != VAR_LIST || di->di_tv.vval.v_list == NULL) {
    return FAIL;
  }

  if (action == 'r' || action == 'u') {
    qf_free_items(&qi->qf_lists[qf_idx]);
  }
  if (qf_init_ext(qi, qf_idx, NULL, NULL, &di->di_tv, errorformat,
                  false, 0, 0, NULL, NULL) >= 0) {
    retval = OK;
  }

  return retval;
}

// Set quickfix list context.
static int qf_setprop_context(qf_list_T *qfl, dictitem_T *di)
  FUNC_ATTR_NONNULL_ALL
{
  tv_free(qfl->qf_ctx);
  typval_T *ctx = xcalloc(1, sizeof(typval_T));
  tv_copy(&di->di_tv, ctx);
  qfl->qf_ctx = ctx;

  return OK;
}

// Set the current index in the specified quickfix list
static int qf_setprop_curidx(qf_info_T *qi, qf_list_T *qfl, const dictitem_T *di)
  FUNC_ATTR_NONNULL_ALL
{
  int newidx;

  // If the specified index is '$', then use the last entry
  if (di->di_tv.v_type == VAR_STRING
      && di->di_tv.vval.v_string != NULL
      && strcmp(di->di_tv.vval.v_string, "$") == 0) {
    newidx = qfl->qf_count;
  } else {
    // Otherwise use the specified index
    bool denote = false;
    newidx = (int)tv_get_number_chk(&di->di_tv, &denote);
    if (denote) {
      return FAIL;
    }
  }

  if (newidx < 1) {  // sanity check
    return FAIL;
  }
  newidx = MIN(newidx, qfl->qf_count);
  const int old_qfidx = qfl->qf_index;
  qfline_T *const qf_ptr = get_nth_entry(qfl, newidx, &newidx);
  if (qf_ptr == NULL) {
    return FAIL;
  }
  qfl->qf_ptr = qf_ptr;
  qfl->qf_index = newidx;

  // If the current list is modified and it is displayed in the quickfix
  // window, then Update it.
  if (qi->qf_lists[qi->qf_curlist].qf_id == qfl->qf_id) {
    qf_win_pos_update(qi, old_qfidx);
  }
  return OK;
}

/// Set quickfix/location list properties (title, items, context).
/// Also used to add items from parsing a list of lines.
/// Used by the setqflist() and setloclist() Vim script functions.
static int qf_set_properties(qf_info_T *qi, const dict_T *what, int action, char *title)
  FUNC_ATTR_NONNULL_ALL
{
  bool newlist = action == ' ' || qf_stack_empty(qi);
  int qf_idx = qf_setprop_get_qfidx(qi, what, action, &newlist);
  if (qf_idx == INVALID_QFIDX) {  // List not found
    return FAIL;
  }

  if (newlist) {
    qi->qf_curlist = qf_idx;
    qf_new_list(qi, title);
    qf_idx = qi->qf_curlist;
  }

  qf_list_T *qfl = qf_get_list(qi, qf_idx);
  dictitem_T *di;
  int retval = FAIL;
  if ((di = tv_dict_find(what, S_LEN("title"))) != NULL) {
    retval = qf_setprop_title(qi, qf_idx, what, di);
  }
  if ((di = tv_dict_find(what, S_LEN("items"))) != NULL) {
    retval = qf_setprop_items(qi, qf_idx, di, action);
  }
  if ((di = tv_dict_find(what, S_LEN("lines"))) != NULL) {
    retval = qf_setprop_items_from_lines(qi, qf_idx, what, di, action);
  }
  if ((di = tv_dict_find(what, S_LEN("context"))) != NULL) {
    retval = qf_setprop_context(qfl, di);
  }
  if ((di = tv_dict_find(what, S_LEN("idx"))) != NULL) {
    retval = qf_setprop_curidx(qi, qfl, di);
  }
  if ((di = tv_dict_find(what, S_LEN("quickfixtextfunc"))) != NULL) {
    retval = qf_setprop_qftf(qfl, di);
  }

  if (newlist || retval == OK) {
    qf_list_changed(qfl);
  }
  if (newlist) {
    qf_update_buffer(qi, NULL);
  }

  return retval;
}

// Free the entire quickfix/location list stack.
// If the quickfix/location list window is open, then clear it.
static void qf_free_stack(win_T *wp, qf_info_T *qi)
{
  win_T *qfwin = qf_find_win(qi);

  if (qfwin != NULL) {
    // If the quickfix/location list window is open, then clear it
    if (qi->qf_curlist < qi->qf_listcount) {
      qf_free(qf_get_curlist(qi));
    }
    qf_update_buffer(qi, NULL);
  }

  if (wp != NULL && IS_LL_WINDOW(wp)) {
    // If in the location list window, then use the non-location list
    // window with this location list (if present)
    win_T *const llwin = qf_find_win_with_loclist(qi);
    if (llwin != NULL) {
      wp = llwin;
    }
  }

  qf_free_all(wp);
  if (wp == NULL) {
    // quickfix list
    qi->qf_curlist = 0;
    qi->qf_listcount = 0;
  } else if (qfwin != NULL) {
    // If the location list window is open, then create a new empty location
    // list
    qf_info_T *new_ll = qf_alloc_stack(QFLT_LOCATION);
    new_ll->qf_bufnr = qfwin->w_buffer->b_fnum;

    // first free the list reference in the location list window
    ll_free_all(&qfwin->w_llist_ref);

    qfwin->w_llist_ref = new_ll;
    if (wp != qfwin) {
      win_set_loclist(wp, new_ll);
    }
  }
}

/// Populate the quickfix list with the items supplied in the list
/// of dictionaries. "title" will be copied to w:quickfix_title
/// "action" is 'a' for add, 'r' for replace, 'u' for update.  Otherwise
/// create a new list.
/// When "what" is not NULL then only set some properties.
int set_errorlist(win_T *wp, list_T *list, int action, char *title, dict_T *what)
{
  qf_info_T *qi = &ql_info;

  if (wp != NULL) {
    qi = ll_get_or_alloc_list(wp);
  }

  if (action == 'f') {
    // Free the entire quickfix or location list stack
    qf_free_stack(wp, qi);
    return OK;
  }

  // A dict argument cannot be specified with a non-empty list argument
  if (list != NULL && tv_list_len(list) != 0 && what != NULL) {
    semsg(_(e_invarg2), _("cannot have both a list and a \"what\" argument"));
    return FAIL;
  }

  incr_quickfix_busy();

  int retval = OK;
  if (what != NULL) {
    retval = qf_set_properties(qi, what, action, title);
  } else {
    retval = qf_add_entries(qi, qi->qf_curlist, list, title, action);
    if (retval == OK) {
      qf_list_changed(qf_get_curlist(qi));
    }
  }

  decr_quickfix_busy();

  return retval;
}

static bool mark_quickfix_user_data(qf_info_T *qi, int copyID)
{
  bool abort = false;
  for (int i = 0; i < LISTCOUNT && !abort; i++) {
    qf_list_T *qfl = &qi->qf_lists[i];
    if (!qfl->qf_has_user_data) {
      continue;
    }
    qfline_T *qfp;
    int j;
    FOR_ALL_QFL_ITEMS(qfl, qfp, j) {
      typval_T *user_data = &qfp->qf_user_data;
      if (user_data != NULL && user_data->v_type != VAR_NUMBER
          && user_data->v_type != VAR_STRING && user_data->v_type != VAR_FLOAT) {
        abort = abort || set_ref_in_item(user_data, copyID, NULL, NULL);
      }
    }
  }
  return abort;
}

/// Mark the quickfix context and callback function as in use for all the lists
/// in a quickfix stack.
static bool mark_quickfix_ctx(qf_info_T *qi, int copyID)
{
  bool abort = false;

  for (int i = 0; i < LISTCOUNT && !abort; i++) {
    typval_T *ctx = qi->qf_lists[i].qf_ctx;
    if (ctx != NULL && ctx->v_type != VAR_NUMBER
        && ctx->v_type != VAR_STRING && ctx->v_type != VAR_FLOAT) {
      abort = set_ref_in_item(ctx, copyID, NULL, NULL);
    }

    Callback *cb = &qi->qf_lists[i].qf_qftf_cb;
    abort = abort || set_ref_in_callback(cb, copyID, NULL, NULL);
  }

  return abort;
}

/// Mark the context of the quickfix list and the location lists (if present) as
/// "in use". So that garbage collection doesn't free the context.
bool set_ref_in_quickfix(int copyID)
{
  if (mark_quickfix_ctx(&ql_info, copyID)
      || mark_quickfix_user_data(&ql_info, copyID)
      || set_ref_in_callback(&qftf_cb, copyID, NULL, NULL)) {
    return true;
  }

  FOR_ALL_TAB_WINDOWS(tp, win) {
    if (win->w_llist != NULL) {
      if (mark_quickfix_ctx(win->w_llist, copyID)
          || mark_quickfix_user_data(win->w_llist, copyID)) {
        return true;
      }
    }

    if (IS_LL_WINDOW(win) && (win->w_llist_ref->qf_refcount == 1)) {
      // In a location list window and none of the other windows is
      // referring to this location list. Mark the location list
      // context as still in use.
      if (mark_quickfix_ctx(win->w_llist_ref, copyID)
          || mark_quickfix_user_data(win->w_llist_ref, copyID)) {
        return true;
      }
    }
  }

  return false;
}

/// Return the autocmd name for the :cbuffer Ex commands
static char *cbuffer_get_auname(cmdidx_T cmdidx)
{
  switch (cmdidx) {
  case CMD_cbuffer:
    return "cbuffer";
  case CMD_cgetbuffer:
    return "cgetbuffer";
  case CMD_caddbuffer:
    return "caddbuffer";
  case CMD_lbuffer:
    return "lbuffer";
  case CMD_lgetbuffer:
    return "lgetbuffer";
  case CMD_laddbuffer:
    return "laddbuffer";
  default:
    return NULL;
  }
}

/// Process and validate the arguments passed to the :cbuffer, :caddbuffer,
/// :cgetbuffer, :lbuffer, :laddbuffer, :lgetbuffer Ex commands.
static int cbuffer_process_args(exarg_T *eap, buf_T **bufp, linenr_T *line1, linenr_T *line2)
{
  buf_T *buf = NULL;

  if (*eap->arg == NUL) {
    buf = curbuf;
  } else if (*skipwhite(skipdigits(eap->arg)) == NUL) {
    buf = buflist_findnr(atoi(eap->arg));
  }

  if (buf == NULL) {
    emsg(_(e_invarg));
    return FAIL;
  }

  if (buf->b_ml.ml_mfp == NULL) {
    emsg(_(e_buffer_is_not_loaded));
    return FAIL;
  }

  if (eap->addr_count == 0) {
    eap->line1 = 1;
    eap->line2 = buf->b_ml.ml_line_count;
  }

  if (eap->line1 < 1 || eap->line1 > buf->b_ml.ml_line_count
      || eap->line2 < 1 || eap->line2 > buf->b_ml.ml_line_count) {
    emsg(_(e_invrange));
    return FAIL;
  }

  *line1 = eap->line1;
  *line2 = eap->line2;
  *bufp = buf;

  return OK;
}

// ":[range]cbuffer [bufnr]" command.
// ":[range]caddbuffer [bufnr]" command.
// ":[range]cgetbuffer [bufnr]" command.
// ":[range]lbuffer [bufnr]" command.
// ":[range]laddbuffer [bufnr]" command.
// ":[range]lgetbuffer [bufnr]" command.
void ex_cbuffer(exarg_T *eap)
{
  char *au_name = cbuffer_get_auname(eap->cmdidx);
  if (au_name != NULL && apply_autocmds(EVENT_QUICKFIXCMDPRE, au_name,
                                        curbuf->b_fname, true, curbuf)) {
    if (aborting()) {
      return;
    }
  }

  // Must come after autocommands.
  win_T *wp = NULL;
  qf_info_T *qi = qf_cmd_get_or_alloc_stack(eap, &wp);

  buf_T *buf = NULL;
  linenr_T line1;
  linenr_T line2;
  if (cbuffer_process_args(eap, &buf, &line1, &line2) == FAIL) {
    return;
  }

  char *qf_title = qf_cmdtitle(*eap->cmdlinep);

  if (buf->b_sfname) {
    vim_snprintf(IObuff, IOSIZE, "%s (%s)", qf_title, buf->b_sfname);
    qf_title = IObuff;
  }

  incr_quickfix_busy();

  int res = qf_init_ext(qi, qi->qf_curlist, NULL, buf, NULL, p_efm,
                        (eap->cmdidx != CMD_caddbuffer
                         && eap->cmdidx != CMD_laddbuffer),
                        eap->line1, eap->line2, qf_title, NULL);
  if (qf_stack_empty(qi)) {
    decr_quickfix_busy();
    return;
  }
  if (res >= 0) {
    qf_list_changed(qf_get_curlist(qi));
  }
  // Remember the current quickfix list identifier, so that we can
  // check for autocommands changing the current quickfix list.
  unsigned save_qfid = qf_get_curlist(qi)->qf_id;
  if (au_name != NULL) {
    const buf_T *const curbuf_old = curbuf;
    apply_autocmds(EVENT_QUICKFIXCMDPOST, au_name, curbuf->b_fname, true, curbuf);
    if (curbuf != curbuf_old) {
      // Autocommands changed buffer, don't jump now, "qi" may
      // be invalid.
      res = 0;
    }
  }
  // Jump to the first error for new list and if autocmds didn't
  // free the list.
  if (res > 0 && (eap->cmdidx == CMD_cbuffer || eap->cmdidx == CMD_lbuffer)
      && qflist_valid(wp, save_qfid)) {
    // display the first error
    qf_jump_first(qi, save_qfid, eap->forceit);
  }

  decr_quickfix_busy();
}

/// Return the autocmd name for the :cexpr Ex commands.
static char *cexpr_get_auname(cmdidx_T cmdidx)
{
  switch (cmdidx) {
  case CMD_cexpr:
    return "cexpr";
  case CMD_cgetexpr:
    return "cgetexpr";
  case CMD_caddexpr:
    return "caddexpr";
  case CMD_lexpr:
    return "lexpr";
  case CMD_lgetexpr:
    return "lgetexpr";
  case CMD_laddexpr:
    return "laddexpr";
  default:
    return NULL;
  }
}

/// ":cexpr {expr}", ":cgetexpr {expr}", ":caddexpr {expr}" command.
/// ":lexpr {expr}", ":lgetexpr {expr}", ":laddexpr {expr}" command.
void ex_cexpr(exarg_T *eap)
{
  char *au_name = cexpr_get_auname(eap->cmdidx);
  if (au_name != NULL && apply_autocmds(EVENT_QUICKFIXCMDPRE, au_name,
                                        curbuf->b_fname, true, curbuf)) {
    if (aborting()) {
      return;
    }
  }

  win_T *wp = NULL;
  qf_info_T *qi = qf_cmd_get_or_alloc_stack(eap, &wp);

  // Evaluate the expression.  When the result is a string or a list we can
  // use it to fill the errorlist.
  typval_T *tv = eval_expr(eap->arg, eap);
  if (tv == NULL) {
    return;
  }

  if ((tv->v_type == VAR_STRING && tv->vval.v_string != NULL)
      || tv->v_type == VAR_LIST) {
    incr_quickfix_busy();
    int res = qf_init_ext(qi, qi->qf_curlist, NULL, NULL, tv, p_efm,
                          (eap->cmdidx != CMD_caddexpr
                           && eap->cmdidx != CMD_laddexpr),
                          0, 0,
                          qf_cmdtitle(*eap->cmdlinep), NULL);
    if (qf_stack_empty(qi)) {
      decr_quickfix_busy();
      goto cleanup;
    }
    if (res >= 0) {
      qf_list_changed(qf_get_curlist(qi));
    }
    // Remember the current quickfix list identifier, so that we can
    // check for autocommands changing the current quickfix list.
    unsigned save_qfid = qf_get_curlist(qi)->qf_id;
    if (au_name != NULL) {
      apply_autocmds(EVENT_QUICKFIXCMDPOST, au_name, curbuf->b_fname, true, curbuf);
    }
    // Jump to the first error for a new list and if autocmds didn't
    // free the list.
    if (res > 0
        && (eap->cmdidx == CMD_cexpr || eap->cmdidx == CMD_lexpr)
        && qflist_valid(wp, save_qfid)) {
      // display the first error
      qf_jump_first(qi, save_qfid, eap->forceit);
    }
    decr_quickfix_busy();
  } else {
    emsg(_("E777: String or List expected"));
  }
cleanup:
  tv_free(tv);
}

// Get the location list for ":lhelpgrep"
static qf_info_T *hgr_get_ll(bool *new_ll)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  // If the current window is a help window, then use it, else find an existing help window
  win_T *wp = bt_help(curwin->w_buffer) ? curwin : qf_find_help_win();

  qf_info_T *qi = wp == NULL ? NULL : wp->w_llist;
  if (qi == NULL) {
    // Allocate a new location list for help text matches
    qi = qf_alloc_stack(QFLT_LOCATION);
    *new_ll = true;
  }

  return qi;
}

// Search for a pattern in a help file.
static void hgr_search_file(qf_list_T *qfl, char *fname, regmatch_T *p_regmatch)
  FUNC_ATTR_NONNULL_ARG(1, 3)
{
  FILE *const fd = os_fopen(fname, "r");
  if (fd == NULL) {
    return;
  }

  linenr_T lnum = 1;
  while (!vim_fgets(IObuff, IOSIZE, fd) && !got_int) {
    char *line = IObuff;

    if (vim_regexec(p_regmatch, line, 0)) {
      int l = (int)strlen(line);

      // remove trailing CR, LF, spaces, etc.
      while (l > 0 && line[l - 1] <= ' ') {
        line[--l] = NUL;
      }

      if (qf_add_entry(qfl,
                       NULL,   // dir
                       fname,
                       NULL,
                       0,
                       line,
                       lnum,
                       0,
                       (int)(p_regmatch->startp[0] - line) + 1,  // col
                       (int)(p_regmatch->endp[0] - line)
                       + 1,    // end_col
                       false,  // vis_col
                       NULL,   // search pattern
                       0,      // nr
                       1,      // type
                       NULL,   // user_data
                       true)   // valid
          == QF_FAIL) {
        got_int = true;
        if (line != IObuff) {
          xfree(line);
        }
        break;
      }
    }
    if (line != IObuff) {
      xfree(line);
    }
    lnum++;
    line_breakcheck();
  }
  fclose(fd);
}

// Search for a pattern in all the help files in the doc directory under
// the given directory.
static void hgr_search_files_in_dir(qf_list_T *qfl, char *dirname, regmatch_T *p_regmatch,
                                    const char *lang)
  FUNC_ATTR_NONNULL_ARG(1, 2, 3)
{
  int fcount;
  char **fnames;

  // Find all "*.txt" and "*.??x" files in the "doc" directory.
  add_pathsep(dirname);
  strcat(dirname, "doc/*.\\(txt\\|??x\\)");  // NOLINT
  if (gen_expand_wildcards(1, &dirname, &fcount, &fnames, EW_FILE|EW_SILENT) == OK
      && fcount > 0) {
    for (int fi = 0; fi < fcount && !got_int; fi++) {
      // Skip files for a different language.
      if (lang != NULL
          && STRNICMP(lang, fnames[fi] + strlen(fnames[fi]) - 3, 2) != 0
          && !(STRNICMP(lang, "en", 2) == 0
               && STRNICMP("txt", fnames[fi] + strlen(fnames[fi]) - 3, 3)
               == 0)) {
        continue;
      }

      hgr_search_file(qfl, fnames[fi], p_regmatch);
    }
    FreeWild(fcount, fnames);
  }
}

// Search for a pattern in all the help files in the 'runtimepath'
// and add the matches to a quickfix list.
// 'lang' is the language specifier.  If supplied, then only matches in the
// specified language are found.
static void hgr_search_in_rtp(qf_list_T *qfl, regmatch_T *p_regmatch, const char *lang)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  // Go through all directories in 'runtimepath'
  char *p = p_rtp;
  while (*p != NUL && !got_int) {
    copy_option_part(&p, NameBuff, MAXPATHL, ",");

    hgr_search_files_in_dir(qfl, NameBuff, p_regmatch, lang);
  }
}

// ":helpgrep {pattern}"
void ex_helpgrep(exarg_T *eap)
{
  qf_info_T *qi = &ql_info;
  char *au_name = NULL;

  switch (eap->cmdidx) {
  case CMD_helpgrep:
    au_name = "helpgrep"; break;
  case CMD_lhelpgrep:
    au_name = "lhelpgrep"; break;
  default:
    break;
  }
  if (au_name != NULL && apply_autocmds(EVENT_QUICKFIXCMDPRE, au_name,
                                        curbuf->b_fname, true, curbuf)) {
    if (aborting()) {
      return;
    }
  }

  bool updated = false;
  // Make 'cpoptions' empty, the 'l' flag should not be used here.
  char *const save_cpo = p_cpo;
  p_cpo = empty_string_option;

  bool new_qi = false;
  if (is_loclist_cmd(eap->cmdidx)) {
    qi = hgr_get_ll(&new_qi);
  }

  incr_quickfix_busy();

  // Check for a specified language
  char *const lang = check_help_lang(eap->arg);
  regmatch_T regmatch = {
    .regprog = vim_regcomp(eap->arg, RE_MAGIC + RE_STRING),
    .rm_ic = false,
  };
  if (regmatch.regprog != NULL) {
    // Create a new quickfix list.
    qf_new_list(qi, qf_cmdtitle(*eap->cmdlinep));
    qf_list_T *const qfl = qf_get_curlist(qi);

    hgr_search_in_rtp(qfl, &regmatch, lang);

    vim_regfree(regmatch.regprog);

    qfl->qf_nonevalid = false;
    qfl->qf_ptr = qfl->qf_start;
    qfl->qf_index = 1;
    qf_list_changed(qfl);
    updated = true;
  }

  if (p_cpo == empty_string_option) {
    p_cpo = save_cpo;
  } else {
    // Darn, some plugin changed the value.  If it's still empty it was
    // changed and restored, need to restore in the complicated way.
    if (*p_cpo == NUL) {
      set_option_value_give_err(kOptCpoptions, CSTR_AS_OPTVAL(save_cpo), 0);
    }
    free_string_option(save_cpo);
  }

  if (updated) {
    // This may open a window and source scripts, do this after 'cpo' was
    // restored.
    qf_update_buffer(qi, NULL);
  }

  if (au_name != NULL) {
    apply_autocmds(EVENT_QUICKFIXCMDPOST, au_name, curbuf->b_fname, true, curbuf);
    // When adding a location list to an existing location list stack,
    // if the autocmd made the stack invalid, then just return.
    if (!new_qi && IS_LL_STACK(qi) && qf_find_win_with_loclist(qi) == NULL) {
      decr_quickfix_busy();
      return;
    }
  }

  // Jump to first match.
  if (!qf_list_empty(qf_get_curlist(qi))) {
    qf_jump(qi, 0, 0, false);
  } else {
    semsg(_(e_nomatch2), eap->arg);
  }

  decr_quickfix_busy();

  if (eap->cmdidx == CMD_lhelpgrep) {
    // If the help window is not opened or if it already points to the
    // correct location list, then free the new location list.
    if (!bt_help(curwin->w_buffer) || curwin->w_llist == qi) {
      if (new_qi) {
        ll_free_all(&qi);
      }
    } else if (curwin->w_llist == NULL && new_qi) {
      // current window didn't have a location list associated with it
      // before. Associate the new location list now.
      curwin->w_llist = qi;
    }
  }
}

#if defined(EXITFREE)
void free_quickfix(void)
{
  qf_free_all(NULL);
  // Free all location lists
  FOR_ALL_TAB_WINDOWS(tab, win) {
    qf_free_all(win);
  }

  ga_clear(&qfga);
}
#endif

static void get_qf_loc_list(bool is_qf, win_T *wp, typval_T *what_arg, typval_T *rettv)
{
  if (what_arg->v_type == VAR_UNKNOWN) {
    tv_list_alloc_ret(rettv, kListLenMayKnow);
    if (is_qf || wp != NULL) {
      get_errorlist(NULL, wp, -1, 0, rettv->vval.v_list);
    }
  } else {
    tv_dict_alloc_ret(rettv);
    if (is_qf || wp != NULL) {
      if (what_arg->v_type == VAR_DICT) {
        dict_T *d = what_arg->vval.v_dict;

        if (d != NULL) {
          qf_get_properties(wp, d, rettv->vval.v_dict);
        }
      } else {
        emsg(_(e_dictreq));
      }
    }
  }
}

/// "getloclist()" function
void f_getloclist(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  win_T *wp = find_win_by_nr_or_id(&argvars[0]);
  get_qf_loc_list(false, wp, &argvars[1], rettv);
}

/// "getqflist()" functions
void f_getqflist(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  get_qf_loc_list(true, NULL, &argvars[0], rettv);
}

/// Create quickfix/location list from Vimscript values
///
/// Used by `setqflist()` and `setloclist()` functions. Accepts invalid
/// args argument in which case errors out, including VAR_UNKNOWN parameters.
///
/// @param[in,out]  wp  Window to create location list for. May be NULL in
///                     which case quickfix list will be created.
/// @param[in]  args  [list, action, what]
/// @param[in]  args[0]  Quickfix list contents.
/// @param[in]  args[1]  Optional. Action to perform:
///                      append to an existing list, replace its content,
///                      or create a new one.
/// @param[in]  args[2]  Optional. Quickfix list properties or title.
///                      Defaults to caller function name.
/// @param[out]  rettv  Return value: 0 in case of success, -1 otherwise.
static void set_qf_ll_list(win_T *wp, typval_T *args, typval_T *rettv)
  FUNC_ATTR_NONNULL_ARG(2, 3)
{
  static const char *e_invact = N_("E927: Invalid action: '%s'");
  const char *title = NULL;
  char action = ' ';
  static int recursive = 0;
  rettv->vval.v_number = -1;
  dict_T *what = NULL;

  typval_T *list_arg = &args[0];
  if (list_arg->v_type != VAR_LIST) {
    emsg(_(e_listreq));
    return;
  } else if (recursive != 0) {
    emsg(_(e_au_recursive));
    return;
  }

  typval_T *action_arg = &args[1];
  if (action_arg->v_type == VAR_UNKNOWN) {
    // Option argument was not given.
    goto skip_args;
  } else if (action_arg->v_type != VAR_STRING) {
    emsg(_(e_stringreq));
    return;
  }
  const char *const act = tv_get_string_chk(action_arg);
  if ((*act == 'a' || *act == 'r' || *act == 'u' || *act == ' ' || *act == 'f')
      && act[1] == NUL) {
    action = *act;
  } else {
    semsg(_(e_invact), act);
    return;
  }

  typval_T *const what_arg = &args[2];
  if (what_arg->v_type == VAR_UNKNOWN) {
    // Option argument was not given.
    goto skip_args;
  } else if (what_arg->v_type == VAR_STRING) {
    title = tv_get_string_chk(what_arg);
    if (!title) {
      // Type error. Error already printed by tv_get_string_chk().
      return;
    }
  } else if (what_arg->v_type == VAR_DICT && what_arg->vval.v_dict != NULL) {
    what = what_arg->vval.v_dict;
  } else {
    emsg(_(e_dictreq));
    return;
  }

skip_args:
  if (!title) {
    title = (wp ? ":setloclist()" : ":setqflist()");
  }

  recursive++;
  list_T *const l = list_arg->vval.v_list;
  if (set_errorlist(wp, l, action, (char *)title, what) == OK) {
    rettv->vval.v_number = 0;
  }
  recursive--;
}

/// "setloclist()" function
void f_setloclist(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = -1;

  win_T *win = find_win_by_nr_or_id(&argvars[0]);
  if (win != NULL) {
    set_qf_ll_list(win, &argvars[1], rettv);
  }
}

/// "setqflist()" function
void f_setqflist(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  set_qf_ll_list(NULL, argvars, rettv);
}
