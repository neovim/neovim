/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * quickfix.c: functions for quickfix mode, using a file with error messages
 */

#include "vim.h"
#include "quickfix.h"
#include "buffer.h"
#include "charset.h"
#include "edit.h"
#include "eval.h"
#include "ex_cmds.h"
#include "ex_cmds2.h"
#include "ex_docmd.h"
#include "ex_eval.h"
#include "ex_getln.h"
#include "fileio.h"
#include "fold.h"
#include "mark.h"
#include "mbyte.h"
#include "memline.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"
#include "move.h"
#include "normal.h"
#include "option.h"
#include "os_unix.h"
#include "regexp.h"
#include "screen.h"
#include "search.h"
#include "term.h"
#include "ui.h"
#include "window.h"
#include "os/os.h"


struct dir_stack_T {
  struct dir_stack_T  *next;
  char_u              *dirname;
};

static struct dir_stack_T   *dir_stack = NULL;

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

typedef struct qf_list_S {
  qfline_T    *qf_start;        /* pointer to the first error */
  qfline_T    *qf_ptr;          /* pointer to the current error */
  int qf_count;                 /* number of errors (0 means no error list) */
  int qf_index;                 /* current index in the error list */
  int qf_nonevalid;             /* TRUE if not a single valid entry found */
  char_u      *qf_title;        /* title derived from the command that created
                                 * the error list */
} qf_list_T;

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

static qf_info_T ql_info;       /* global quickfix list */

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

static int qf_init_ext(qf_info_T *qi, char_u *efile, buf_T *buf,
                       typval_T *tv, char_u *errorformat, int newlist,
                       linenr_T lnumfirst,
                       linenr_T lnumlast,
                       char_u *qf_title);
static void qf_new_list(qf_info_T *qi, char_u *qf_title);
static void ll_free_all(qf_info_T **pqi);
static int qf_add_entry(qf_info_T *qi, qfline_T **prevp, char_u *dir,
                        char_u *fname, int bufnum, char_u *mesg,
                        long lnum, int col, int vis_col,
                        char_u *pattern, int nr, int type,
                        int valid);
static qf_info_T *ll_new_list(void);
static void qf_msg(qf_info_T *qi);
static void qf_free(qf_info_T *qi, int idx);
static char_u   *qf_types(int, int);
static int qf_get_fnum(char_u *, char_u *);
static char_u   *qf_push_dir(char_u *, struct dir_stack_T **);
static char_u   *qf_pop_dir(struct dir_stack_T **);
static char_u   *qf_guess_filepath(char_u *);
static void qf_fmt_text(char_u *text, char_u *buf, int bufsize);
static void qf_clean_dir_stack(struct dir_stack_T **);
static int qf_win_pos_update(qf_info_T *qi, int old_qf_index);
static int is_qf_win(win_T *win, qf_info_T *qi);
static win_T    *qf_find_win(qf_info_T *qi);
static buf_T    *qf_find_buf(qf_info_T *qi);
static void qf_update_buffer(qf_info_T *qi);
static void qf_set_title(qf_info_T *qi);
static void qf_fill_buffer(qf_info_T *qi);
static char_u   *get_mef_name(void);
static void restore_start_dir(char_u *dirname_start);
static buf_T    *load_dummy_buffer(char_u *fname, char_u *dirname_start,
                                           char_u *resulting_dir);
static void wipe_dummy_buffer(buf_T *buf, char_u *dirname_start);
static void unload_dummy_buffer(buf_T *buf, char_u *dirname_start);
static qf_info_T *ll_get_or_alloc_list(win_T *);

/* Quickfix window check helper macro */
#define IS_QF_WINDOW(wp) (bt_quickfix(wp->w_buffer) && wp->w_llist_ref == NULL)
/* Location list window check helper macro */
#define IS_LL_WINDOW(wp) (bt_quickfix(wp->w_buffer) && wp->w_llist_ref != NULL)
/*
 * Return location list for window 'wp'
 * For location list window, return the referenced location list
 */
#define GET_LOC_LIST(wp) (IS_LL_WINDOW(wp) ? wp->w_llist_ref : wp->w_llist)

/*
 * Read the errorfile "efile" into memory, line by line, building the error
 * list. Set the error list's title to qf_title.
 * Return -1 for error, number of errors for success.
 */
int 
qf_init (
    win_T *wp,
    char_u *efile,
    char_u *errorformat,
    int newlist,                            /* TRUE: start a new error list */
    char_u *qf_title
)
{
  qf_info_T       *qi = &ql_info;

  if (efile == NULL)
    return FAIL;

  if (wp != NULL) {
    qi = ll_get_or_alloc_list(wp);
    if (qi == NULL)
      return FAIL;
  }

  return qf_init_ext(qi, efile, curbuf, NULL, errorformat, newlist,
      (linenr_T)0, (linenr_T)0,
      qf_title);
}

/*
 * Read the errorfile "efile" into memory, line by line, building the error
 * list.
 * Alternative: when "efile" is null read errors from buffer "buf".
 * Always use 'errorformat' from "buf" if there is a local value.
 * Then "lnumfirst" and "lnumlast" specify the range of lines to use.
 * Set the title of the list to "qf_title".
 * Return -1 for error, number of errors for success.
 */
static int 
qf_init_ext (
    qf_info_T *qi,
    char_u *efile,
    buf_T *buf,
    typval_T *tv,
    char_u *errorformat,
    int newlist,                            /* TRUE: start a new error list */
    linenr_T lnumfirst,                     /* first line number to use */
    linenr_T lnumlast,                      /* last line number to use */
    char_u *qf_title
)
{
  char_u          *namebuf;
  char_u          *errmsg;
  char_u          *pattern;
  char_u          *fmtstr = NULL;
  int col = 0;
  char_u use_viscol = FALSE;
  int type = 0;
  int valid;
  linenr_T buflnum = lnumfirst;
  long lnum = 0L;
  int enr = 0;
  FILE            *fd = NULL;
  qfline_T        *qfprev = NULL;       /* init to make SASC shut up */
  char_u          *efmp;
  efm_T           *fmt_first = NULL;
  efm_T           *fmt_last = NULL;
  efm_T           *fmt_ptr;
  efm_T           *fmt_start = NULL;
  char_u          *efm;
  char_u          *ptr;
  char_u          *srcptr;
  int len;
  int i;
  int round;
  int idx = 0;
  int multiline = FALSE;
  int multiignore = FALSE;
  int multiscan = FALSE;
  int retval = -1;                      /* default: return error flag */
  char_u          *directory = NULL;
  char_u          *currfile = NULL;
  char_u          *tail = NULL;
  char_u          *p_str = NULL;
  listitem_T      *p_li = NULL;
  struct dir_stack_T  *file_stack = NULL;
  regmatch_T regmatch;
  static struct fmtpattern {
    char_u convchar;
    char    *pattern;
  }               fmt_pat[FMT_PATTERNS] =
  {
    {'f', ".\\+"},                          /* only used when at end */
    {'n', "\\d\\+"},
    {'l', "\\d\\+"},
    {'c', "\\d\\+"},
    {'t', "."},
    {'m', ".\\+"},
    {'r', ".*"},
    {'p', "[- 	.]*"},
    {'v', "\\d\\+"},
    {'s', ".\\+"}
  };

  namebuf = alloc(CMDBUFFSIZE + 1);
  errmsg = alloc(CMDBUFFSIZE + 1);
  pattern = alloc(CMDBUFFSIZE + 1);
  if (namebuf == NULL || errmsg == NULL || pattern == NULL)
    goto qf_init_end;

  if (efile != NULL && (fd = mch_fopen((char *)efile, "r")) == NULL) {
    EMSG2(_(e_openerrf), efile);
    goto qf_init_end;
  }

  if (newlist || qi->qf_curlist == qi->qf_listcount)
    /* make place for a new list */
    qf_new_list(qi, qf_title);
  else if (qi->qf_lists[qi->qf_curlist].qf_count > 0)
    /* Adding to existing list, find last entry. */
    for (qfprev = qi->qf_lists[qi->qf_curlist].qf_start;
         qfprev->qf_next != qfprev; qfprev = qfprev->qf_next)
      ;

  /*
   * Each part of the format string is copied and modified from errorformat to
   * regex prog.  Only a few % characters are allowed.
   */
  /* Use the local value of 'errorformat' if it's set. */
  if (errorformat == p_efm && tv == NULL && *buf->b_p_efm != NUL)
    efm = buf->b_p_efm;
  else
    efm = errorformat;
  /*
   * Get some space to modify the format string into.
   */
  i = (FMT_PATTERNS * 3) + ((int)STRLEN(efm) << 2);
  for (round = FMT_PATTERNS; round > 0; )
    i += (int)STRLEN(fmt_pat[--round].pattern);
#ifdef COLON_IN_FILENAME
  i += 12;   /* "%f" can become twelve chars longer */
#else
  i += 2;   /* "%f" can become two chars longer */
#endif
  if ((fmtstr = alloc(i)) == NULL)
    goto error2;

  while (efm[0] != NUL) {
    /*
     * Allocate a new eformat structure and put it at the end of the list
     */
    fmt_ptr = (efm_T *)alloc_clear((unsigned)sizeof(efm_T));
    if (fmt_ptr == NULL)
      goto error2;
    if (fmt_first == NULL)          /* first one */
      fmt_first = fmt_ptr;
    else
      fmt_last->next = fmt_ptr;
    fmt_last = fmt_ptr;

    /*
     * Isolate one part in the 'errorformat' option
     */
    for (len = 0; efm[len] != NUL && efm[len] != ','; ++len)
      if (efm[len] == '\\' && efm[len + 1] != NUL)
        ++len;

    /*
     * Build regexp pattern from current 'errorformat' option
     */
    ptr = fmtstr;
    *ptr++ = '^';
    round = 0;
    for (efmp = efm; efmp < efm + len; ++efmp) {
      if (*efmp == '%') {
        ++efmp;
        for (idx = 0; idx < FMT_PATTERNS; ++idx)
          if (fmt_pat[idx].convchar == *efmp)
            break;
        if (idx < FMT_PATTERNS) {
          if (fmt_ptr->addr[idx]) {
            sprintf((char *)errmsg,
                _("E372: Too many %%%c in format string"), *efmp);
            EMSG(errmsg);
            goto error2;
          }
          if ((idx
               && idx < 6
               && vim_strchr((char_u *)"DXOPQ",
                   fmt_ptr->prefix) != NULL)
              || (idx == 6
                  && vim_strchr((char_u *)"OPQ",
                      fmt_ptr->prefix) == NULL)) {
            sprintf((char *)errmsg,
                _("E373: Unexpected %%%c in format string"), *efmp);
            EMSG(errmsg);
            goto error2;
          }
          fmt_ptr->addr[idx] = (char_u)++ round;
          *ptr++ = '\\';
          *ptr++ = '(';
#ifdef BACKSLASH_IN_FILENAME
          if (*efmp == 'f') {
            /* Also match "c:" in the file name, even when
             * checking for a colon next: "%f:".
             * "\%(\a:\)\=" */
            STRCPY(ptr, "\\%(\\a:\\)\\=");
            ptr += 10;
          }
#endif
          if (*efmp == 'f' && efmp[1] != NUL) {
            if (efmp[1] != '\\' && efmp[1] != '%') {
              /* A file name may contain spaces, but this isn't
               * in "\f".  For "%f:%l:%m" there may be a ":" in
               * the file name.  Use ".\{-1,}x" instead (x is
               * the next character), the requirement that :999:
               * follows should work. */
              STRCPY(ptr, ".\\{-1,}");
              ptr += 7;
            } else   {
              /* File name followed by '\\' or '%': include as
               * many file name chars as possible. */
              STRCPY(ptr, "\\f\\+");
              ptr += 4;
            }
          } else   {
            srcptr = (char_u *)fmt_pat[idx].pattern;
            while ((*ptr = *srcptr++) != NUL)
              ++ptr;
          }
          *ptr++ = '\\';
          *ptr++ = ')';
        } else if (*efmp == '*')   {
          if (*++efmp == '[' || *efmp == '\\') {
            if ((*ptr++ = *efmp) == '[') {              /* %*[^a-z0-9] etc. */
              if (efmp[1] == '^')
                *ptr++ = *++efmp;
              if (efmp < efm + len) {
                *ptr++ = *++efmp;                           /* could be ']' */
                while (efmp < efm + len
                       && (*ptr++ = *++efmp) != ']')
                  /* skip */;
                if (efmp == efm + len) {
                  EMSG(_("E374: Missing ] in format string"));
                  goto error2;
                }
              }
            } else if (efmp < efm + len)                /* %*\D, %*\s etc. */
              *ptr++ = *++efmp;
            *ptr++ = '\\';
            *ptr++ = '+';
          } else   {
            /* TODO: scanf()-like: %*ud, %*3c, %*f, ... ? */
            sprintf((char *)errmsg,
                _("E375: Unsupported %%%c in format string"), *efmp);
            EMSG(errmsg);
            goto error2;
          }
        } else if (vim_strchr((char_u *)"%\\.^$~[", *efmp) != NULL)
          *ptr++ = *efmp;                       /* regexp magic characters */
        else if (*efmp == '#')
          *ptr++ = '*';
        else if (*efmp == '>')
          fmt_ptr->conthere = TRUE;
        else if (efmp == efm + 1) {                     /* analyse prefix */
          if (vim_strchr((char_u *)"+-", *efmp) != NULL)
            fmt_ptr->flags = *efmp++;
          if (vim_strchr((char_u *)"DXAEWICZGOPQ", *efmp) != NULL)
            fmt_ptr->prefix = *efmp;
          else {
            sprintf((char *)errmsg,
                _("E376: Invalid %%%c in format string prefix"), *efmp);
            EMSG(errmsg);
            goto error2;
          }
        } else   {
          sprintf((char *)errmsg,
              _("E377: Invalid %%%c in format string"), *efmp);
          EMSG(errmsg);
          goto error2;
        }
      } else   {                        /* copy normal character */
        if (*efmp == '\\' && efmp + 1 < efm + len)
          ++efmp;
        else if (vim_strchr((char_u *)".*^$~[", *efmp) != NULL)
          *ptr++ = '\\';                /* escape regexp atoms */
        if (*efmp)
          *ptr++ = *efmp;
      }
    }
    *ptr++ = '$';
    *ptr = NUL;
    if ((fmt_ptr->prog = vim_regcomp(fmtstr, RE_MAGIC + RE_STRING)) == NULL)
      goto error2;
    /*
     * Advance to next part
     */
    efm = skip_to_option_part(efm + len);       /* skip comma and spaces */
  }
  if (fmt_first == NULL) {      /* nothing found */
    EMSG(_("E378: 'errorformat' contains no pattern"));
    goto error2;
  }

  /*
   * got_int is reset here, because it was probably set when killing the
   * ":make" command, but we still want to read the errorfile then.
   */
  got_int = FALSE;

  /* Always ignore case when looking for a matching error. */
  regmatch.rm_ic = TRUE;

  if (tv != NULL) {
    if (tv->v_type == VAR_STRING)
      p_str = tv->vval.v_string;
    else if (tv->v_type == VAR_LIST)
      p_li = tv->vval.v_list->lv_first;
  }

  /*
   * Read the lines in the error file one by one.
   * Try to recognize one of the error formats in each line.
   */
  while (!got_int) {
    /* Get the next line. */
    if (fd == NULL) {
      if (tv != NULL) {
        if (tv->v_type == VAR_STRING) {
          /* Get the next line from the supplied string */
          char_u *p;

          if (!*p_str)           /* Reached the end of the string */
            break;

          p = vim_strchr(p_str, '\n');
          if (p)
            len = (int)(p - p_str + 1);
          else
            len = (int)STRLEN(p_str);

          if (len > CMDBUFFSIZE - 2)
            vim_strncpy(IObuff, p_str, CMDBUFFSIZE - 2);
          else
            vim_strncpy(IObuff, p_str, len);

          p_str += len;
        } else if (tv->v_type == VAR_LIST)   {
          /* Get the next line from the supplied list */
          while (p_li && p_li->li_tv.v_type != VAR_STRING)
            p_li = p_li->li_next;               /* Skip non-string items */

          if (!p_li)                            /* End of the list */
            break;

          len = (int)STRLEN(p_li->li_tv.vval.v_string);
          if (len > CMDBUFFSIZE - 2)
            len = CMDBUFFSIZE - 2;

          vim_strncpy(IObuff, p_li->li_tv.vval.v_string, len);

          p_li = p_li->li_next;                 /* next item */
        }
      } else   {
        /* Get the next line from the supplied buffer */
        if (buflnum > lnumlast)
          break;
        vim_strncpy(IObuff, ml_get_buf(buf, buflnum++, FALSE),
            CMDBUFFSIZE - 2);
      }
    } else if (fgets((char *)IObuff, CMDBUFFSIZE - 2, fd) == NULL)
      break;

    IObuff[CMDBUFFSIZE - 2] = NUL;      /* for very long lines */
    remove_bom(IObuff);

    if ((efmp = vim_strrchr(IObuff, '\n')) != NULL)
      *efmp = NUL;
#ifdef USE_CRNL
    if ((efmp = vim_strrchr(IObuff, '\r')) != NULL)
      *efmp = NUL;
#endif

    /* If there was no %> item start at the first pattern */
    if (fmt_start == NULL)
      fmt_ptr = fmt_first;
    else {
      fmt_ptr = fmt_start;
      fmt_start = NULL;
    }

    /*
     * Try to match each part of 'errorformat' until we find a complete
     * match or no match.
     */
    valid = TRUE;
restofline:
    for (; fmt_ptr != NULL; fmt_ptr = fmt_ptr->next) {
      idx = fmt_ptr->prefix;
      if (multiscan && vim_strchr((char_u *)"OPQ", idx) == NULL)
        continue;
      namebuf[0] = NUL;
      pattern[0] = NUL;
      if (!multiscan)
        errmsg[0] = NUL;
      lnum = 0;
      col = 0;
      use_viscol = FALSE;
      enr = -1;
      type = 0;
      tail = NULL;

      regmatch.regprog = fmt_ptr->prog;
      if (vim_regexec(&regmatch, IObuff, (colnr_T)0)) {
        if ((idx == 'C' || idx == 'Z') && !multiline)
          continue;
        if (vim_strchr((char_u *)"EWI", idx) != NULL)
          type = idx;
        else
          type = 0;
        /*
         * Extract error message data from matched line.
         * We check for an actual submatch, because "\[" and "\]" in
         * the 'errorformat' may cause the wrong submatch to be used.
         */
        if ((i = (int)fmt_ptr->addr[0]) > 0) {                  /* %f */
          int c;

          if (regmatch.startp[i] == NULL || regmatch.endp[i] == NULL)
            continue;

          /* Expand ~/file and $HOME/file to full path. */
          c = *regmatch.endp[i];
          *regmatch.endp[i] = NUL;
          expand_env(regmatch.startp[i], namebuf, CMDBUFFSIZE);
          *regmatch.endp[i] = c;

          if (vim_strchr((char_u *)"OPQ", idx) != NULL
              && mch_getperm(namebuf) == -1)
            continue;
        }
        if ((i = (int)fmt_ptr->addr[1]) > 0) {                  /* %n */
          if (regmatch.startp[i] == NULL)
            continue;
          enr = (int)atol((char *)regmatch.startp[i]);
        }
        if ((i = (int)fmt_ptr->addr[2]) > 0) {                  /* %l */
          if (regmatch.startp[i] == NULL)
            continue;
          lnum = atol((char *)regmatch.startp[i]);
        }
        if ((i = (int)fmt_ptr->addr[3]) > 0) {                  /* %c */
          if (regmatch.startp[i] == NULL)
            continue;
          col = (int)atol((char *)regmatch.startp[i]);
        }
        if ((i = (int)fmt_ptr->addr[4]) > 0) {                  /* %t */
          if (regmatch.startp[i] == NULL)
            continue;
          type = *regmatch.startp[i];
        }
        if (fmt_ptr->flags == '+' && !multiscan)                /* %+ */
          STRCPY(errmsg, IObuff);
        else if ((i = (int)fmt_ptr->addr[5]) > 0) {             /* %m */
          if (regmatch.startp[i] == NULL || regmatch.endp[i] == NULL)
            continue;
          len = (int)(regmatch.endp[i] - regmatch.startp[i]);
          vim_strncpy(errmsg, regmatch.startp[i], len);
        }
        if ((i = (int)fmt_ptr->addr[6]) > 0) {                  /* %r */
          if (regmatch.startp[i] == NULL)
            continue;
          tail = regmatch.startp[i];
        }
        if ((i = (int)fmt_ptr->addr[7]) > 0) {                  /* %p */
          char_u      *match_ptr;

          if (regmatch.startp[i] == NULL || regmatch.endp[i] == NULL)
            continue;
          col = 0;
          for (match_ptr = regmatch.startp[i];
               match_ptr != regmatch.endp[i]; ++match_ptr) {
            ++col;
            if (*match_ptr == TAB) {
              col += 7;
              col -= col % 8;
            }
          }
          ++col;
          use_viscol = TRUE;
        }
        if ((i = (int)fmt_ptr->addr[8]) > 0) {                  /* %v */
          if (regmatch.startp[i] == NULL)
            continue;
          col = (int)atol((char *)regmatch.startp[i]);
          use_viscol = TRUE;
        }
        if ((i = (int)fmt_ptr->addr[9]) > 0) {                  /* %s */
          if (regmatch.startp[i] == NULL || regmatch.endp[i] == NULL)
            continue;
          len = (int)(regmatch.endp[i] - regmatch.startp[i]);
          if (len > CMDBUFFSIZE - 5)
            len = CMDBUFFSIZE - 5;
          STRCPY(pattern, "^\\V");
          STRNCAT(pattern, regmatch.startp[i], len);
          pattern[len + 3] = '\\';
          pattern[len + 4] = '$';
          pattern[len + 5] = NUL;
        }
        break;
      }
    }
    multiscan = FALSE;

    if (fmt_ptr == NULL || idx == 'D' || idx == 'X') {
      if (fmt_ptr != NULL) {
        if (idx == 'D') {                               /* enter directory */
          if (*namebuf == NUL) {
            EMSG(_("E379: Missing or empty directory name"));
            goto error2;
          }
          if ((directory = qf_push_dir(namebuf, &dir_stack)) == NULL)
            goto error2;
        } else if (idx == 'X')                          /* leave directory */
          directory = qf_pop_dir(&dir_stack);
      }
      namebuf[0] = NUL;                 /* no match found, remove file name */
      lnum = 0;                         /* don't jump to this line */
      valid = FALSE;
      STRCPY(errmsg, IObuff);           /* copy whole line to error message */
      if (fmt_ptr == NULL)
        multiline = multiignore = FALSE;
    } else if (fmt_ptr != NULL)   {
      /* honor %> item */
      if (fmt_ptr->conthere)
        fmt_start = fmt_ptr;

      if (vim_strchr((char_u *)"AEWI", idx) != NULL)
        multiline = TRUE;               /* start of a multi-line message */
      else if (vim_strchr((char_u *)"CZ", idx) != NULL) { /* continuation of multi-line msg */
        if (qfprev == NULL)
          goto error2;
        if (*errmsg && !multiignore) {
          len = (int)STRLEN(qfprev->qf_text);
          if ((ptr = alloc((unsigned)(len + STRLEN(errmsg) + 2)))
              == NULL)
            goto error2;
          STRCPY(ptr, qfprev->qf_text);
          vim_free(qfprev->qf_text);
          qfprev->qf_text = ptr;
          *(ptr += len) = '\n';
          STRCPY(++ptr, errmsg);
        }
        if (qfprev->qf_nr == -1)
          qfprev->qf_nr = enr;
        if (vim_isprintc(type) && !qfprev->qf_type)
          qfprev->qf_type = type;            /* only printable chars allowed */
        if (!qfprev->qf_lnum)
          qfprev->qf_lnum = lnum;
        if (!qfprev->qf_col)
          qfprev->qf_col = col;
        qfprev->qf_viscol = use_viscol;
        if (!qfprev->qf_fnum)
          qfprev->qf_fnum = qf_get_fnum(directory,
              *namebuf || directory ? namebuf
              : currfile && valid ? currfile : 0);
        if (idx == 'Z')
          multiline = multiignore = FALSE;
        line_breakcheck();
        continue;
      } else if (vim_strchr((char_u *)"OPQ", idx) != NULL)   {
        /* global file names */
        valid = FALSE;
        if (*namebuf == NUL || mch_getperm(namebuf) >= 0) {
          if (*namebuf && idx == 'P')
            currfile = qf_push_dir(namebuf, &file_stack);
          else if (idx == 'Q')
            currfile = qf_pop_dir(&file_stack);
          *namebuf = NUL;
          if (tail && *tail) {
            STRMOVE(IObuff, skipwhite(tail));
            multiscan = TRUE;
            goto restofline;
          }
        }
      }
      if (fmt_ptr->flags == '-') {      /* generally exclude this line */
        if (multiline)
          multiignore = TRUE;           /* also exclude continuation lines */
        continue;
      }
    }

    if (qf_add_entry(qi, &qfprev,
            directory,
            (*namebuf || directory)
            ? namebuf
            : ((currfile && valid) ? currfile : (char_u *)NULL),
            0,
            errmsg,
            lnum,
            col,
            use_viscol,
            pattern,
            enr,
            type,
            valid) == FAIL)
      goto error2;
    line_breakcheck();
  }
  if (fd == NULL || !ferror(fd)) {
    if (qi->qf_lists[qi->qf_curlist].qf_index == 0) {
      /* no valid entry found */
      qi->qf_lists[qi->qf_curlist].qf_ptr =
        qi->qf_lists[qi->qf_curlist].qf_start;
      qi->qf_lists[qi->qf_curlist].qf_index = 1;
      qi->qf_lists[qi->qf_curlist].qf_nonevalid = TRUE;
    } else   {
      qi->qf_lists[qi->qf_curlist].qf_nonevalid = FALSE;
      if (qi->qf_lists[qi->qf_curlist].qf_ptr == NULL)
        qi->qf_lists[qi->qf_curlist].qf_ptr =
          qi->qf_lists[qi->qf_curlist].qf_start;
    }
    /* return number of matches */
    retval = qi->qf_lists[qi->qf_curlist].qf_count;
    goto qf_init_ok;
  }
  EMSG(_(e_readerrf));
error2:
  qf_free(qi, qi->qf_curlist);
  qi->qf_listcount--;
  if (qi->qf_curlist > 0)
    --qi->qf_curlist;
qf_init_ok:
  if (fd != NULL)
    fclose(fd);
  for (fmt_ptr = fmt_first; fmt_ptr != NULL; fmt_ptr = fmt_first) {
    fmt_first = fmt_ptr->next;
    vim_regfree(fmt_ptr->prog);
    vim_free(fmt_ptr);
  }
  qf_clean_dir_stack(&dir_stack);
  qf_clean_dir_stack(&file_stack);
qf_init_end:
  vim_free(namebuf);
  vim_free(errmsg);
  vim_free(pattern);
  vim_free(fmtstr);

  qf_update_buffer(qi);

  return retval;
}

/*
 * Prepare for adding a new quickfix list.
 */
static void qf_new_list(qf_info_T *qi, char_u *qf_title)
{
  int i;

  /*
   * If the current entry is not the last entry, delete entries below
   * the current entry.  This makes it possible to browse in a tree-like
   * way with ":grep'.
   */
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
  vim_memset(&qi->qf_lists[qi->qf_curlist], 0, (size_t)(sizeof(qf_list_T)));
  if (qf_title != NULL) {
    char_u *p = alloc((int)STRLEN(qf_title) + 2);

    qi->qf_lists[qi->qf_curlist].qf_title = p;
    if (p != NULL)
      sprintf((char *)p, ":%s", (char *)qf_title);
  }
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
    vim_free(qi);
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

/*
 * Add an entry to the end of the list of errors.
 * Returns OK or FAIL.
 */
static int 
qf_add_entry (
    qf_info_T *qi,                /* quickfix list */
    qfline_T **prevp,            /* pointer to previously added entry or NULL */
    char_u *dir,               /* optional directory name */
    char_u *fname,             /* file name or NULL */
    int bufnum,                     /* buffer number or zero */
    char_u *mesg,              /* message */
    long lnum,                      /* line number */
    int col,                        /* column */
    int vis_col,                    /* using visual column */
    char_u *pattern,           /* search pattern */
    int nr,                         /* error number */
    int type,                       /* type character */
    int valid                      /* valid entry */
)
{
  qfline_T    *qfp;

  if ((qfp = (qfline_T *)alloc((unsigned)sizeof(qfline_T))) == NULL)
    return FAIL;
  if (bufnum != 0)
    qfp->qf_fnum = bufnum;
  else
    qfp->qf_fnum = qf_get_fnum(dir, fname);
  if ((qfp->qf_text = vim_strsave(mesg)) == NULL) {
    vim_free(qfp);
    return FAIL;
  }
  qfp->qf_lnum = lnum;
  qfp->qf_col = col;
  qfp->qf_viscol = vis_col;
  if (pattern == NULL || *pattern == NUL)
    qfp->qf_pattern = NULL;
  else if ((qfp->qf_pattern = vim_strsave(pattern)) == NULL) {
    vim_free(qfp->qf_text);
    vim_free(qfp);
    return FAIL;
  }
  qfp->qf_nr = nr;
  if (type != 1 && !vim_isprintc(type))   /* only printable chars allowed */
    type = 0;
  qfp->qf_type = type;
  qfp->qf_valid = valid;

  if (qi->qf_lists[qi->qf_curlist].qf_count == 0) {
    /* first element in the list */
    qi->qf_lists[qi->qf_curlist].qf_start = qfp;
    qfp->qf_prev = qfp;         /* first element points to itself */
  } else   {
    qfp->qf_prev = *prevp;
    (*prevp)->qf_next = qfp;
  }
  qfp->qf_next = qfp;   /* last element points to itself */
  qfp->qf_cleared = FALSE;
  *prevp = qfp;
  ++qi->qf_lists[qi->qf_curlist].qf_count;
  if (qi->qf_lists[qi->qf_curlist].qf_index == 0 && qfp->qf_valid) {
    /* first valid entry */
    qi->qf_lists[qi->qf_curlist].qf_index =
      qi->qf_lists[qi->qf_curlist].qf_count;
    qi->qf_lists[qi->qf_curlist].qf_ptr = qfp;
  }

  return OK;
}

/*
 * Allocate a new location list
 */
static qf_info_T *ll_new_list(void)                        {
  qf_info_T *qi;

  qi = (qf_info_T *)alloc((unsigned)sizeof(qf_info_T));
  if (qi != NULL) {
    vim_memset(qi, 0, (size_t)(sizeof(qf_info_T)));
    qi->qf_refcount++;
  }

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
  if ((to->w_llist = ll_new_list()) == NULL)
    return;

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
    to_qfl->qf_ptr = NULL;
    if (from_qfl->qf_title != NULL)
      to_qfl->qf_title = vim_strsave(from_qfl->qf_title);
    else
      to_qfl->qf_title = NULL;

    if (from_qfl->qf_count) {
      qfline_T    *from_qfp;
      qfline_T    *prevp = NULL;

      /* copy all the location entries in this list */
      for (i = 0, from_qfp = from_qfl->qf_start; i < from_qfl->qf_count;
           ++i, from_qfp = from_qfp->qf_next) {
        if (qf_add_entry(to->w_llist, &prevp,
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
        prevp->qf_fnum = from_qfp->qf_fnum;         /* file number */
        prevp->qf_type = from_qfp->qf_type;         /* error type */
        if (from_qfl->qf_ptr == from_qfp)
          to_qfl->qf_ptr = prevp;                   /* current location */
      }
    }

    to_qfl->qf_index = from_qfl->qf_index;      /* current index in the list */

    /* When no valid entries are present in the list, qf_ptr points to
     * the first item in the list */
    if (to_qfl->qf_nonevalid) {
      to_qfl->qf_ptr = to_qfl->qf_start;
      to_qfl->qf_index = 1;
    }
  }

  to->w_llist->qf_curlist = qi->qf_curlist;     /* current list */
}

/*
 * get buffer number for file "dir.name"
 */
static int qf_get_fnum(char_u *directory, char_u *fname)
{
  if (fname == NULL || *fname == NUL)           /* no file name */
    return 0;
  {
    char_u      *ptr;
    int fnum;

#ifdef BACKSLASH_IN_FILENAME
    if (directory != NULL)
      slash_adjust(directory);
    slash_adjust(fname);
#endif
    if (directory != NULL && !vim_isAbsName(fname)
        && (ptr = concat_fnames(directory, fname, TRUE)) != NULL) {
      /*
       * Here we check if the file really exists.
       * This should normally be true, but if make works without
       * "leaving directory"-messages we might have missed a
       * directory change.
       */
      if (mch_getperm(ptr) < 0) {
        vim_free(ptr);
        directory = qf_guess_filepath(fname);
        if (directory)
          ptr = concat_fnames(directory, fname, TRUE);
        else
          ptr = vim_strsave(fname);
      }
      /* Use concatenated directory name and file name */
      fnum = buflist_add(ptr, 0);
      vim_free(ptr);
      return fnum;
    }
    return buflist_add(fname, 0);
  }
}

/*
 * push dirbuf onto the directory stack and return pointer to actual dir or
 * NULL on error
 */
static char_u *qf_push_dir(char_u *dirbuf, struct dir_stack_T **stackptr)
{
  struct dir_stack_T  *ds_new;
  struct dir_stack_T  *ds_ptr;

  /* allocate new stack element and hook it in */
  ds_new = (struct dir_stack_T *)alloc((unsigned)sizeof(struct dir_stack_T));
  if (ds_new == NULL)
    return NULL;

  ds_new->next = *stackptr;
  *stackptr = ds_new;

  /* store directory on the stack */
  if (vim_isAbsName(dirbuf)
      || (*stackptr)->next == NULL
      || (*stackptr && dir_stack != *stackptr))
    (*stackptr)->dirname = vim_strsave(dirbuf);
  else {
    /* Okay we don't have an absolute path.
     * dirbuf must be a subdir of one of the directories on the stack.
     * Let's search...
     */
    ds_new = (*stackptr)->next;
    (*stackptr)->dirname = NULL;
    while (ds_new) {
      vim_free((*stackptr)->dirname);
      (*stackptr)->dirname = concat_fnames(ds_new->dirname, dirbuf,
          TRUE);
      if (mch_isdir((*stackptr)->dirname) == TRUE)
        break;

      ds_new = ds_new->next;
    }

    /* clean up all dirs we already left */
    while ((*stackptr)->next != ds_new) {
      ds_ptr = (*stackptr)->next;
      (*stackptr)->next = (*stackptr)->next->next;
      vim_free(ds_ptr->dirname);
      vim_free(ds_ptr);
    }

    /* Nothing found -> it must be on top level */
    if (ds_new == NULL) {
      vim_free((*stackptr)->dirname);
      (*stackptr)->dirname = vim_strsave(dirbuf);
    }
  }

  if ((*stackptr)->dirname != NULL)
    return (*stackptr)->dirname;
  else {
    ds_ptr = *stackptr;
    *stackptr = (*stackptr)->next;
    vim_free(ds_ptr);
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
    vim_free(ds_ptr->dirname);
    vim_free(ds_ptr);
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
    vim_free(ds_ptr->dirname);
    vim_free(ds_ptr);
  }
}

/*
 * Check in which directory of the directory stack the given file can be
 * found.
 * Returns a pointer to the directory name or NULL if not found
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
static char_u *qf_guess_filepath(char_u *filename)
{
  struct dir_stack_T     *ds_ptr;
  struct dir_stack_T     *ds_tmp;
  char_u                 *fullname;

  /* no dirs on the stack - there's nothing we can do */
  if (dir_stack == NULL)
    return NULL;

  ds_ptr = dir_stack->next;
  fullname = NULL;
  while (ds_ptr) {
    vim_free(fullname);
    fullname = concat_fnames(ds_ptr->dirname, filename, TRUE);

    /* If concat_fnames failed, just go on. The worst thing that can happen
     * is that we delete the entire stack.
     */
    if ((fullname != NULL) && (mch_getperm(fullname) >= 0))
      break;

    ds_ptr = ds_ptr->next;
  }

  vim_free(fullname);

  /* clean up all dirs we already left */
  while (dir_stack->next != ds_ptr) {
    ds_tmp = dir_stack->next;
    dir_stack->next = dir_stack->next->next;
    vim_free(ds_tmp->dirname);
    vim_free(ds_tmp);
  }

  return ds_ptr==NULL ? NULL : ds_ptr->dirname;

}

/*
 * jump to a quickfix line
 * if dir == FORWARD go "errornr" valid entries forward
 * if dir == BACKWARD go "errornr" valid entries backward
 * if dir == FORWARD_FILE go "errornr" valid entries files backward
 * if dir == BACKWARD_FILE go "errornr" valid entries files backward
 * else if "errornr" is zero, redisplay the same line
 * else go to entry "errornr"
 */
void qf_jump(qf_info_T *qi, int dir, int errornr, int forceit)
{
  qf_info_T           *ll_ref;
  qfline_T            *qf_ptr;
  qfline_T            *old_qf_ptr;
  int qf_index;
  int old_qf_fnum;
  int old_qf_index;
  int prev_index;
  static char_u       *e_no_more_items = (char_u *)N_("E553: No more items");
  char_u              *err = e_no_more_items;
  linenr_T i;
  buf_T               *old_curbuf;
  linenr_T old_lnum;
  colnr_T screen_col;
  colnr_T char_col;
  char_u              *line;
  char_u              *old_swb = p_swb;
  unsigned old_swb_flags = swb_flags;
  int opened_window = FALSE;
  win_T               *win;
  win_T               *altwin;
  int flags;
  win_T               *oldwin = curwin;
  int print_message = TRUE;
  int len;
  int old_KeyTyped = KeyTyped;                   /* getting file may reset it */
  int ok = OK;
  int usable_win;

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
  if (dir == FORWARD || dir == FORWARD_FILE) {      /* next valid entry */
    while (errornr--) {
      old_qf_ptr = qf_ptr;
      prev_index = qf_index;
      old_qf_fnum = qf_ptr->qf_fnum;
      do {
        if (qf_index == qi->qf_lists[qi->qf_curlist].qf_count
            || qf_ptr->qf_next == NULL) {
          qf_ptr = old_qf_ptr;
          qf_index = prev_index;
          if (err != NULL) {
            EMSG(_(err));
            goto theend;
          }
          errornr = 0;
          break;
        }
        ++qf_index;
        qf_ptr = qf_ptr->qf_next;
      } while ((!qi->qf_lists[qi->qf_curlist].qf_nonevalid
                && !qf_ptr->qf_valid)
               || (dir == FORWARD_FILE && qf_ptr->qf_fnum == old_qf_fnum));
      err = NULL;
    }
  } else if (dir == BACKWARD || dir == BACKWARD_FILE)   { /* prev. valid entry */
    while (errornr--) {
      old_qf_ptr = qf_ptr;
      prev_index = qf_index;
      old_qf_fnum = qf_ptr->qf_fnum;
      do {
        if (qf_index == 1 || qf_ptr->qf_prev == NULL) {
          qf_ptr = old_qf_ptr;
          qf_index = prev_index;
          if (err != NULL) {
            EMSG(_(err));
            goto theend;
          }
          errornr = 0;
          break;
        }
        --qf_index;
        qf_ptr = qf_ptr->qf_prev;
      } while ((!qi->qf_lists[qi->qf_curlist].qf_nonevalid
                && !qf_ptr->qf_valid)
               || (dir == BACKWARD_FILE && qf_ptr->qf_fnum == old_qf_fnum));
      err = NULL;
    }
  } else if (errornr != 0)   {  /* go to specified number */
    while (errornr < qf_index && qf_index > 1 && qf_ptr->qf_prev != NULL) {
      --qf_index;
      qf_ptr = qf_ptr->qf_prev;
    }
    while (errornr > qf_index && qf_index <
           qi->qf_lists[qi->qf_curlist].qf_count
           && qf_ptr->qf_next != NULL) {
      ++qf_index;
      qf_ptr = qf_ptr->qf_next;
    }
  }

  qi->qf_lists[qi->qf_curlist].qf_index = qf_index;
  if (qf_win_pos_update(qi, old_qf_index))
    /* No need to print the error message if it's visible in the error
     * window */
    print_message = FALSE;

  /*
   * For ":helpgrep" find a help window or open one.
   */
  if (qf_ptr->qf_type == 1 && (!curwin->w_buffer->b_help || cmdmod.tab != 0)) {
    win_T   *wp;

    if (cmdmod.tab != 0)
      wp = NULL;
    else
      for (wp = firstwin; wp != NULL; wp = wp->w_next)
        if (wp->w_buffer != NULL && wp->w_buffer->b_help)
          break;
    if (wp != NULL && wp->w_buffer->b_nwindows > 0)
      win_enter(wp, TRUE);
    else {
      /*
       * Split off help window; put it at far top if no position
       * specified, the current window is vertically split and narrow.
       */
      flags = WSP_HELP;
      if (cmdmod.split == 0 && curwin->w_width != Columns
          && curwin->w_width < 80)
        flags |= WSP_TOP;
      if (qi != &ql_info)
        flags |= WSP_NEWLOC;          /* don't copy the location list */

      if (win_split(0, flags) == FAIL)
        goto theend;
      opened_window = TRUE;             /* close it when fail */

      if (curwin->w_height < p_hh)
        win_setheight((int)p_hh);

      if (qi != &ql_info) {         /* not a quickfix list */
        /* The new window should use the supplied location list */
        curwin->w_llist = qi;
        qi->qf_refcount++;
      }
    }

    if (!p_im)
      restart_edit = 0;             /* don't want insert mode in help file */
  }

  /*
   * If currently in the quickfix window, find another window to show the
   * file in.
   */
  if (bt_quickfix(curbuf) && !opened_window) {
    win_T *usable_win_ptr = NULL;

    /*
     * If there is no file specified, we don't know where to go.
     * But do advance, otherwise ":cn" gets stuck.
     */
    if (qf_ptr->qf_fnum == 0)
      goto theend;

    usable_win = 0;

    ll_ref = curwin->w_llist_ref;
    if (ll_ref != NULL) {
      /* Find a window using the same location list that is not a
       * quickfix window. */
      FOR_ALL_WINDOWS(usable_win_ptr)
      if (usable_win_ptr->w_llist == ll_ref
          && usable_win_ptr->w_buffer->b_p_bt[0] != 'q') {
        usable_win = 1;
        break;
      }
    }

    if (!usable_win) {
      /* Locate a window showing a normal buffer */
      FOR_ALL_WINDOWS(win)
      if (win->w_buffer->b_p_bt[0] == NUL) {
        usable_win = 1;
        break;
      }
    }

    /*
     * If no usable window is found and 'switchbuf' contains "usetab"
     * then search in other tabs.
     */
    if (!usable_win && (swb_flags & SWB_USETAB)) {
      tabpage_T   *tp;
      win_T       *wp;

      FOR_ALL_TAB_WINDOWS(tp, wp)
      {
        if (wp->w_buffer->b_fnum == qf_ptr->qf_fnum) {
          goto_tabpage_win(tp, wp);
          usable_win = 1;
          goto win_found;
        }
      }
    }
win_found:

    /*
     * If there is only one window and it is the quickfix window, create a
     * new one above the quickfix window.
     */
    if (((firstwin == lastwin) && bt_quickfix(curbuf)) || !usable_win) {
      flags = WSP_ABOVE;
      if (ll_ref != NULL)
        flags |= WSP_NEWLOC;
      if (win_split(0, flags) == FAIL)
        goto failed;                    /* not enough room for window */
      opened_window = TRUE;             /* close it when fail */
      p_swb = empty_option;             /* don't split again */
      swb_flags = 0;
      RESET_BINDING(curwin);
      if (ll_ref != NULL) {
        /* The new window should use the location list from the
         * location list window */
        curwin->w_llist = ll_ref;
        ll_ref->qf_refcount++;
      }
    } else   {
      if (curwin->w_llist_ref != NULL) {
        /* In a location window */
        win = usable_win_ptr;
        if (win == NULL) {
          /* Find the window showing the selected file */
          FOR_ALL_WINDOWS(win)
          if (win->w_buffer->b_fnum == qf_ptr->qf_fnum)
            break;
          if (win == NULL) {
            /* Find a previous usable window */
            win = curwin;
            do {
              if (win->w_buffer->b_p_bt[0] == NUL)
                break;
              if (win->w_prev == NULL)
                win = lastwin;                  /* wrap around the top */
              else
                win = win->w_prev;                 /* go to previous window */
            } while (win != curwin);
          }
        }
        win_goto(win);

        /* If the location list for the window is not set, then set it
         * to the location list from the location window */
        if (win->w_llist == NULL) {
          win->w_llist = ll_ref;
          ll_ref->qf_refcount++;
        }
      } else   {

        /*
         * Try to find a window that shows the right buffer.
         * Default to the window just above the quickfix buffer.
         */
        win = curwin;
        altwin = NULL;
        for (;; ) {
          if (win->w_buffer->b_fnum == qf_ptr->qf_fnum)
            break;
          if (win->w_prev == NULL)
            win = lastwin;              /* wrap around the top */
          else
            win = win->w_prev;          /* go to previous window */

          if (IS_QF_WINDOW(win)) {
            /* Didn't find it, go to the window before the quickfix
             * window. */
            if (altwin != NULL)
              win = altwin;
            else if (curwin->w_prev != NULL)
              win = curwin->w_prev;
            else
              win = curwin->w_next;
            break;
          }

          /* Remember a usable window. */
          if (altwin == NULL && !win->w_p_pvw
              && win->w_buffer->b_p_bt[0] == NUL)
            altwin = win;
        }

        win_goto(win);
      }
    }
  }

  /*
   * If there is a file name,
   * read the wanted file if needed, and check autowrite etc.
   */
  old_curbuf = curbuf;
  old_lnum = curwin->w_cursor.lnum;

  if (qf_ptr->qf_fnum != 0) {
    if (qf_ptr->qf_type == 1) {
      /* Open help file (do_ecmd() will set b_help flag, readfile() will
       * set b_p_ro flag). */
      if (!can_abandon(curbuf, forceit)) {
        EMSG(_(e_nowrtmsg));
        ok = FALSE;
      } else
        ok = do_ecmd(qf_ptr->qf_fnum, NULL, NULL, NULL, (linenr_T)1,
            ECMD_HIDE + ECMD_SET_HELP,
            oldwin == curwin ? curwin : NULL);
    } else
      ok = buflist_getfile(qf_ptr->qf_fnum,
          (linenr_T)1, GETF_SETMARK | GETF_SWITCH, forceit);
  }

  if (ok == OK) {
    /* When not switched to another buffer, still need to set pc mark */
    if (curbuf == old_curbuf)
      setpcmark();

    if (qf_ptr->qf_pattern == NULL) {
      /*
       * Go to line with error, unless qf_lnum is 0.
       */
      i = qf_ptr->qf_lnum;
      if (i > 0) {
        if (i > curbuf->b_ml.ml_line_count)
          i = curbuf->b_ml.ml_line_count;
        curwin->w_cursor.lnum = i;
      }
      if (qf_ptr->qf_col > 0) {
        curwin->w_cursor.col = qf_ptr->qf_col - 1;
        if (qf_ptr->qf_viscol == TRUE) {
          /*
           * Check each character from the beginning of the error
           * line up to the error column.  For each tab character
           * found, reduce the error column value by the length of
           * a tab character.
           */
          line = ml_get_curline();
          screen_col = 0;
          for (char_col = 0; char_col < curwin->w_cursor.col; ++char_col) {
            if (*line == NUL)
              break;
            if (*line++ == '\t') {
              curwin->w_cursor.col -= 7 - (screen_col % 8);
              screen_col += 8 - (screen_col % 8);
            } else
              ++screen_col;
          }
        }
        check_cursor();
      } else
        beginline(BL_WHITE | BL_FIX);
    } else   {
      pos_T save_cursor;

      /* Move the cursor to the first line in the buffer */
      save_cursor = curwin->w_cursor;
      curwin->w_cursor.lnum = 0;
      if (!do_search(NULL, '/', qf_ptr->qf_pattern, (long)1,
              SEARCH_KEEP, NULL))
        curwin->w_cursor = save_cursor;
    }

    if ((fdo_flags & FDO_QUICKFIX) && old_KeyTyped)
      foldOpenCursor();
    if (print_message) {
      /* Update the screen before showing the message, unless the screen
       * scrolled up. */
      if (!msg_scrolled)
        update_topline_redraw();
      sprintf((char *)IObuff, _("(%d of %d)%s%s: "), qf_index,
          qi->qf_lists[qi->qf_curlist].qf_count,
          qf_ptr->qf_cleared ? _(" (line deleted)") : "",
          (char *)qf_types(qf_ptr->qf_type, qf_ptr->qf_nr));
      /* Add the message, skipping leading whitespace and newlines. */
      len = (int)STRLEN(IObuff);
      qf_fmt_text(skipwhite(qf_ptr->qf_text), IObuff + len, IOSIZE - len);

      /* Output the message.  Overwrite to avoid scrolling when the 'O'
       * flag is present in 'shortmess'; But when not jumping, print the
       * whole message. */
      i = msg_scroll;
      if (curbuf == old_curbuf && curwin->w_cursor.lnum == old_lnum)
        msg_scroll = TRUE;
      else if (!msg_scrolled && shortmess(SHM_OVERALL))
        msg_scroll = FALSE;
      msg_attr_keep(IObuff, 0, TRUE);
      msg_scroll = i;
    }
  } else   {
    if (opened_window)
      win_close(curwin, TRUE);          /* Close opened window */
    if (qf_ptr->qf_fnum != 0) {
      /*
       * Couldn't open file, so put index back where it was.  This could
       * happen if the file was readonly and we changed something.
       */
failed:
      qf_ptr = old_qf_ptr;
      qf_index = old_qf_index;
    }
  }
theend:
  qi->qf_lists[qi->qf_curlist].qf_ptr = qf_ptr;
  qi->qf_lists[qi->qf_curlist].qf_index = qf_index;
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
  if (!get_list_range(&arg, &idx1, &idx2) || *arg != NUL) {
    EMSG(_(e_trailing));
    return;
  }
  i = qi->qf_lists[qi->qf_curlist].qf_count;
  if (idx1 < 0)
    idx1 = (-idx1 > i) ? 0 : idx1 + i + 1;
  if (idx2 < 0)
    idx2 = (-idx2 > i) ? 0 : idx2 + i + 1;

  if (qi->qf_lists[qi->qf_curlist].qf_nonevalid)
    all = TRUE;
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
          fname = gettail(fname);
      }
      if (fname == NULL)
        sprintf((char *)IObuff, "%2d", i);
      else
        vim_snprintf((char *)IObuff, IOSIZE, "%2d %s",
            i, (char *)fname);
      msg_outtrans_attr(IObuff, i == qi->qf_lists[qi->qf_curlist].qf_index
          ? hl_attr(HLF_L) : hl_attr(HLF_D));
      if (qfp->qf_lnum == 0)
        IObuff[0] = NUL;
      else if (qfp->qf_col == 0)
        sprintf((char *)IObuff, ":%ld", qfp->qf_lnum);
      else
        sprintf((char *)IObuff, ":%ld col %d",
            qfp->qf_lnum, qfp->qf_col);
      sprintf((char *)IObuff + STRLEN(IObuff), "%s:",
          (char *)qf_types(qfp->qf_type, qfp->qf_nr));
      msg_puts_attr(IObuff, hl_attr(HLF_N));
      if (qfp->qf_pattern != NULL) {
        qf_fmt_text(qfp->qf_pattern, IObuff, IOSIZE);
        STRCAT(IObuff, ":");
        msg_puts(IObuff);
      }
      msg_puts((char_u *)" ");

      /* Remove newlines and leading whitespace from the text.  For an
       * unrecognized line keep the indent, the compiler may mark a word
       * with ^^^^. */
      qf_fmt_text((fname != NULL || qfp->qf_lnum != 0)
          ? skipwhite(qfp->qf_text) : qfp->qf_text,
          IObuff, IOSIZE);
      msg_prt_line(IObuff, FALSE);
      out_flush();                      /* show one line at a time */
    }

    qfp = qfp->qf_next;
    ++i;
    ui_breakcheck();
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
        if (!vim_iswhite(*p) && *p != '\n')
          break;
    } else
      buf[i] = *p++;
  }
  buf[i] = NUL;
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

  if (eap->addr_count != 0)
    count = eap->line2;
  else
    count = 1;
  while (count--) {
    if (eap->cmdidx == CMD_colder || eap->cmdidx == CMD_lolder) {
      if (qi->qf_curlist == 0) {
        EMSG(_("E380: At bottom of quickfix stack"));
        break;
      }
      --qi->qf_curlist;
    } else   {
      if (qi->qf_curlist >= qi->qf_listcount - 1) {
        EMSG(_("E381: At top of quickfix stack"));
        break;
      }
      ++qi->qf_curlist;
    }
  }
  qf_msg(qi);
}

static void qf_msg(qf_info_T *qi)
{
  smsg((char_u *)_("error list %d of %d; %d errors"),
      qi->qf_curlist + 1, qi->qf_listcount,
      qi->qf_lists[qi->qf_curlist].qf_count);
  qf_update_buffer(qi);
}

/*
 * Free error list "idx".
 */
static void qf_free(qf_info_T *qi, int idx)
{
  qfline_T    *qfp;
  int stop = FALSE;

  while (qi->qf_lists[idx].qf_count) {
    qfp = qi->qf_lists[idx].qf_start->qf_next;
    if (qi->qf_lists[idx].qf_title != NULL && !stop) {
      vim_free(qi->qf_lists[idx].qf_start->qf_text);
      stop = (qi->qf_lists[idx].qf_start == qfp);
      vim_free(qi->qf_lists[idx].qf_start->qf_pattern);
      vim_free(qi->qf_lists[idx].qf_start);
      if (stop)
        /* Somehow qf_count may have an incorrect value, set it to 1
         * to avoid crashing when it's wrong.
         * TODO: Avoid qf_count being incorrect. */
        qi->qf_lists[idx].qf_count = 1;
    }
    qi->qf_lists[idx].qf_start = qfp;
    --qi->qf_lists[idx].qf_count;
  }
  vim_free(qi->qf_lists[idx].qf_title);
  qi->qf_lists[idx].qf_title = NULL;
}

/*
 * qf_mark_adjust: adjust marks
 */
void qf_mark_adjust(win_T *wp, linenr_T line1, linenr_T line2, long amount, long amount_after)
{
  int i;
  qfline_T    *qfp;
  int idx;
  qf_info_T   *qi = &ql_info;

  if (wp != NULL) {
    if (wp->w_llist == NULL)
      return;
    qi = wp->w_llist;
  }

  for (idx = 0; idx < qi->qf_listcount; ++idx)
    if (qi->qf_lists[idx].qf_count)
      for (i = 0, qfp = qi->qf_lists[idx].qf_start;
           i < qi->qf_lists[idx].qf_count; ++i, qfp = qfp->qf_next)
        if (qfp->qf_fnum == curbuf->b_fnum) {
          if (qfp->qf_lnum >= line1 && qfp->qf_lnum <= line2) {
            if (amount == MAXLNUM)
              qfp->qf_cleared = TRUE;
            else
              qfp->qf_lnum += amount;
          } else if (amount_after && qfp->qf_lnum > line2)
            qfp->qf_lnum += amount_after;
        }
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
    cc[1] = c;
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
  if (win != NULL)
    win_close(win, FALSE);
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

  if (eap->addr_count != 0)
    height = eap->line2;
  else
    height = QF_WINHEIGHT;

  reset_VIsual_and_resel();                     /* stop Visual mode */

  /*
   * Find existing quickfix window, or open a new one.
   */
  win = qf_find_win(qi);

  if (win != NULL && cmdmod.tab == 0)
    win_goto(win);
  else {
    qf_buf = qf_find_buf(qi);

    /* The current window becomes the previous window afterwards. */
    win = curwin;

    if ((eap->cmdidx == CMD_copen || eap->cmdidx == CMD_cwindow)
        && cmdmod.split == 0)
      /* Create the new window at the very bottom, except when
       * :belowright or :aboveleft is used. */
      win_goto(lastwin);
    if (win_split(height, WSP_BELOW | WSP_NEWLOC) == FAIL)
      return;                   /* not enough room for window */
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
      /* switch off 'swapfile' */
      set_option_value((char_u *)"swf", 0L, NULL, OPT_LOCAL);
      set_option_value((char_u *)"bt", 0L, (char_u *)"quickfix",
          OPT_LOCAL);
      set_option_value((char_u *)"bh", 0L, (char_u *)"wipe", OPT_LOCAL);
      RESET_BINDING(curwin);
      curwin->w_p_diff = FALSE;
      set_option_value((char_u *)"fdm", 0L, (char_u *)"manual",
          OPT_LOCAL);
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

  /*
   * Fill the buffer with the quickfix list.
   */
  qf_fill_buffer(qi);

  if (qi->qf_lists[qi->qf_curlist].qf_title != NULL)
    qf_set_title(qi);

  curwin->w_cursor.lnum = qi->qf_lists[qi->qf_curlist].qf_index;
  curwin->w_cursor.col = 0;
  check_cursor();
  update_topline();             /* scroll to show the line */
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
    win_T   *old_curwin = curwin;

    curwin = win;
    curbuf = win->w_buffer;
    if (qf_index > old_qf_index) {
      curwin->w_redraw_top = old_qf_index;
      curwin->w_redraw_bot = qf_index;
    } else   {
      curwin->w_redraw_top = qf_index;
      curwin->w_redraw_bot = old_qf_index;
    }
    curwin->w_cursor.lnum = qf_index;
    curwin->w_cursor.col = 0;
    update_topline();                   /* scroll to show the line */
    redraw_later(VALID);
    curwin->w_redr_status = TRUE;       /* update ruler */
    curwin = old_curwin;
    curbuf = curwin->w_buffer;
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
  win_T       *win;

  FOR_ALL_WINDOWS(win)
  if (is_qf_win(win, qi))
    break;

  return win;
}

/*
 * Find a quickfix buffer.
 * Searches in windows opened in all the tabs.
 */
static buf_T *qf_find_buf(qf_info_T *qi)
{
  tabpage_T   *tp;
  win_T       *win;

  FOR_ALL_TAB_WINDOWS(tp, win)
  if (is_qf_win(win, qi))
    return win->w_buffer;

  return NULL;
}

/*
 * Find the quickfix buffer.  If it exists, update the contents.
 */
static void qf_update_buffer(qf_info_T *qi)
{
  buf_T       *buf;
  win_T       *win;
  win_T       *curwin_save;
  aco_save_T aco;

  /* Check if a buffer for the quickfix list exists.  Update it. */
  buf = qf_find_buf(qi);
  if (buf != NULL) {
    /* set curwin/curbuf to buf and save a few things */
    aucmd_prepbuf(&aco, buf);

    qf_fill_buffer(qi);

    if (qi->qf_lists[qi->qf_curlist].qf_title != NULL
        && (win = qf_find_win(qi)) != NULL) {
      curwin_save = curwin;
      curwin = win;
      qf_set_title(qi);
      curwin = curwin_save;

    }

    /* restore curwin/curbuf and a few other things */
    aucmd_restbuf(&aco);

    (void)qf_win_pos_update(qi, 0);
  }
}

static void qf_set_title(qf_info_T *qi)
{
  set_internal_string_var((char_u *)"w:quickfix_title",
      qi->qf_lists[qi->qf_curlist].qf_title);
}

/*
 * Fill current buffer with quickfix errors, replacing any previous contents.
 * curbuf must be the quickfix buffer!
 */
static void qf_fill_buffer(qf_info_T *qi)
{
  linenr_T lnum;
  qfline_T    *qfp;
  buf_T       *errbuf;
  int len;
  int old_KeyTyped = KeyTyped;

  /* delete all existing lines */
  while ((curbuf->b_ml.ml_flags & ML_EMPTY) == 0)
    (void)ml_delete((linenr_T)1, FALSE);

  /* Check if there is anything to display */
  if (qi->qf_curlist < qi->qf_listcount) {
    /* Add one line for each error */
    qfp = qi->qf_lists[qi->qf_curlist].qf_start;
    for (lnum = 0; lnum < qi->qf_lists[qi->qf_curlist].qf_count; ++lnum) {
      if (qfp->qf_fnum != 0
          && (errbuf = buflist_findnr(qfp->qf_fnum)) != NULL
          && errbuf->b_fname != NULL) {
        if (qfp->qf_type == 1)          /* :helpgrep */
          STRCPY(IObuff, gettail(errbuf->b_fname));
        else
          STRCPY(IObuff, errbuf->b_fname);
        len = (int)STRLEN(IObuff);
      } else
        len = 0;
      IObuff[len++] = '|';

      if (qfp->qf_lnum > 0) {
        sprintf((char *)IObuff + len, "%ld", qfp->qf_lnum);
        len += (int)STRLEN(IObuff + len);

        if (qfp->qf_col > 0) {
          sprintf((char *)IObuff + len, " col %d", qfp->qf_col);
          len += (int)STRLEN(IObuff + len);
        }

        sprintf((char *)IObuff + len, "%s",
            (char *)qf_types(qfp->qf_type, qfp->qf_nr));
        len += (int)STRLEN(IObuff + len);
      } else if (qfp->qf_pattern != NULL)   {
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

      if (ml_append(lnum, IObuff, (colnr_T)STRLEN(IObuff) + 1, FALSE)
          == FAIL)
        break;
      qfp = qfp->qf_next;
    }
    /* Delete the empty line which is now at the end */
    (void)ml_delete(lnum + 1, FALSE);
  }

  /* correct cursor position */
  check_lnums(TRUE);

  /* Set the 'filetype' to "qf" each time after filling the buffer.  This
   * resembles reading a file into a buffer, it's more logical when using
   * autocommands. */
  set_option_value((char_u *)"ft", 0L, (char_u *)"qf", OPT_LOCAL);
  curbuf->b_p_ma = FALSE;

  keep_filetype = TRUE;                 /* don't detect 'filetype' */
  apply_autocmds(EVENT_BUFREADPOST, (char_u *)"quickfix", NULL,
      FALSE, curbuf);
  apply_autocmds(EVENT_BUFWINENTER, (char_u *)"quickfix", NULL,
      FALSE, curbuf);
  keep_filetype = FALSE;

  /* make sure it will be redrawn */
  redraw_curbuf_later(NOT_VALID);

  /* Restore KeyTyped, setting 'filetype' may reset it. */
  KeyTyped = old_KeyTyped;
}


/*
 * Return TRUE if "buf" is the quickfix buffer.
 */
int bt_quickfix(buf_T *buf)
{
  return buf != NULL && buf->b_p_bt[0] == 'q';
}

/*
 * Return TRUE if "buf" is a "nofile" or "acwrite" buffer.
 * This means the buffer name is not a file name.
 */
int bt_nofile(buf_T *buf)
{
  return buf != NULL && ((buf->b_p_bt[0] == 'n' && buf->b_p_bt[2] == 'f')
                         || buf->b_p_bt[0] == 'a');
}

/*
 * Return TRUE if "buf" is a "nowrite" or "nofile" buffer.
 */
int bt_dontwrite(buf_T *buf)
{
  return buf != NULL && buf->b_p_bt[0] == 'n';
}

int bt_dontwrite_msg(buf_T *buf)
{
  if (bt_dontwrite(buf)) {
    EMSG(_("E382: Cannot write, 'buftype' option is set"));
    return TRUE;
  }
  return FALSE;
}

/*
 * Return TRUE if the buffer should be hidden, according to 'hidden', ":hide"
 * and 'bufhidden'.
 */
int buf_hide(buf_T *buf)
{
  /* 'bufhidden' overrules 'hidden' and ":hide", check it first */
  switch (buf->b_p_bh[0]) {
  case 'u':                         /* "unload" */
  case 'w':                         /* "wipe" */
  case 'd': return FALSE;           /* "delete" */
  case 'h': return TRUE;            /* "hide" */
  }
  return p_hid || cmdmod.hide;
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
  char_u      *cmd;
  unsigned len;
  win_T       *wp = NULL;
  qf_info_T   *qi = &ql_info;
  int res;
  char_u      *au_name = NULL;

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
  if (au_name != NULL) {
    apply_autocmds(EVENT_QUICKFIXCMDPRE, au_name,
        curbuf->b_fname, TRUE, curbuf);
    if (did_throw || force_abort)
      return;
  }

  if (eap->cmdidx == CMD_lmake || eap->cmdidx == CMD_lgrep
      || eap->cmdidx == CMD_lgrepadd)
    wp = curwin;

  autowrite_all();
  fname = get_mef_name();
  if (fname == NULL)
    return;
  mch_remove(fname);        /* in case it's not unique */

  /*
   * If 'shellpipe' empty: don't redirect to 'errorfile'.
   */
  len = (unsigned)STRLEN(p_shq) * 2 + (unsigned)STRLEN(eap->arg) + 1;
  if (*p_sp != NUL)
    len += (unsigned)STRLEN(p_sp) + (unsigned)STRLEN(fname) + 3;
  cmd = alloc(len);
  if (cmd == NULL)
    return;
  sprintf((char *)cmd, "%s%s%s", (char *)p_shq, (char *)eap->arg,
      (char *)p_shq);
  if (*p_sp != NUL)
    append_redir(cmd, len, p_sp, fname);
  /*
   * Output a newline if there's something else than the :make command that
   * was typed (in which case the cursor is in column 0).
   */
  if (msg_col == 0)
    msg_didout = FALSE;
  msg_start();
  MSG_PUTS(":!");
  msg_outtrans(cmd);            /* show what we are doing */

  /* let the shell know if we are redirecting output or not */
  do_shell(cmd, *p_sp != NUL ? SHELL_DOOUT : 0);


  res = qf_init(wp, fname, (eap->cmdidx != CMD_make
                            && eap->cmdidx != CMD_lmake) ? p_gefm : p_efm,
      (eap->cmdidx != CMD_grepadd
       && eap->cmdidx != CMD_lgrepadd),
      *eap->cmdlinep);
  if (wp != NULL)
    qi = GET_LOC_LIST(wp);
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

  mch_remove(fname);
  vim_free(fname);
  vim_free(cmd);
}

/*
 * Return the name for the errorfile, in allocated memory.
 * Find a new unique name when 'makeef' contains "##".
 * Returns NULL for error.
 */
static char_u *get_mef_name(void)                     {
  char_u      *p;
  char_u      *name;
  static int start = -1;
  static int off = 0;
#ifdef HAVE_LSTAT
  struct stat sb;
#endif

  if (*p_mef == NUL) {
    name = vim_tempname('e');
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
    if (start == -1)
      start = mch_get_pid();
    else
      off += 19;

    name = alloc((unsigned)STRLEN(p_mef) + 30);
    if (name == NULL)
      break;
    STRCPY(name, p_mef);
    sprintf((char *)name + (p - p_mef), "%d%d", start, off);
    STRCAT(name, p + 2);
    if (mch_getperm(name) < 0
#ifdef HAVE_LSTAT
        /* Don't accept a symbolic link, its a security risk. */
        && mch_lstat((char *)name, &sb) < 0
#endif
        )
      break;
    vim_free(name);
  }
  return name;
}

/*
 * ":cc", ":crewind", ":cfirst" and ":clast".
 * ":ll", ":lrewind", ":lfirst" and ":llast".
 */
void ex_cc(exarg_T *eap)
{
  qf_info_T   *qi = &ql_info;

  if (eap->cmdidx == CMD_ll
      || eap->cmdidx == CMD_lrewind
      || eap->cmdidx == CMD_lfirst
      || eap->cmdidx == CMD_llast) {
    qi = GET_LOC_LIST(curwin);
    if (qi == NULL) {
      EMSG(_(e_loclist));
      return;
    }
  }

  qf_jump(qi, 0,
      eap->addr_count > 0
      ? (int)eap->line2
      : (eap->cmdidx == CMD_cc || eap->cmdidx == CMD_ll)
      ? 0
      : (eap->cmdidx == CMD_crewind || eap->cmdidx == CMD_lrewind
         || eap->cmdidx == CMD_cfirst || eap->cmdidx == CMD_lfirst)
      ? 1
      : 32767,
      eap->forceit);
}

/*
 * ":cnext", ":cnfile", ":cNext" and ":cprevious".
 * ":lnext", ":lNext", ":lprevious", ":lnfile", ":lNfile" and ":lpfile".
 */
void ex_cnext(exarg_T *eap)
{
  qf_info_T   *qi = &ql_info;

  if (eap->cmdidx == CMD_lnext
      || eap->cmdidx == CMD_lNext
      || eap->cmdidx == CMD_lprevious
      || eap->cmdidx == CMD_lnfile
      || eap->cmdidx == CMD_lNfile
      || eap->cmdidx == CMD_lpfile) {
    qi = GET_LOC_LIST(curwin);
    if (qi == NULL) {
      EMSG(_(e_loclist));
      return;
    }
  }

  qf_jump(qi, (eap->cmdidx == CMD_cnext || eap->cmdidx == CMD_lnext)
      ? FORWARD
      : (eap->cmdidx == CMD_cnfile || eap->cmdidx == CMD_lnfile)
      ? FORWARD_FILE
      : (eap->cmdidx == CMD_cpfile || eap->cmdidx == CMD_lpfile
         || eap->cmdidx == CMD_cNfile || eap->cmdidx == CMD_lNfile)
      ? BACKWARD_FILE
      : BACKWARD,
      eap->addr_count > 0 ? (int)eap->line2 : 1, eap->forceit);
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

  /*
   * This function is used by the :cfile, :cgetfile and :caddfile
   * commands.
   * :cfile always creates a new quickfix list and jumps to the
   * first error.
   * :cgetfile creates a new quickfix list but doesn't jump to the
   * first error.
   * :caddfile adds to an existing quickfix list. If there is no
   * quickfix list then a new list is created.
   */
  if (qf_init(wp, p_ef, p_efm, (eap->cmdidx != CMD_caddfile
                                && eap->cmdidx != CMD_laddfile),
          *eap->cmdlinep) > 0
      && (eap->cmdidx == CMD_cfile
          || eap->cmdidx == CMD_lfile)) {
    if (au_name != NULL)
      apply_autocmds(EVENT_QUICKFIXCMDPOST, au_name, NULL, FALSE, curbuf);
    if (wp != NULL)
      qi = GET_LOC_LIST(wp);
    qf_jump(qi, 0, 0, eap->forceit);            /* display first error */
  } else   {
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
  qfline_T    *prevp = NULL;
  long lnum;
  buf_T       *buf;
  int duplicate_name = FALSE;
  int using_dummy;
  int redraw_for_dummy = FALSE;
  int found_match;
  buf_T       *first_match_buf = NULL;
  time_t seconds = 0;
  int save_mls;
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
  if (au_name != NULL) {
    apply_autocmds(EVENT_QUICKFIXCMDPRE, au_name,
        curbuf->b_fname, TRUE, curbuf);
    if (did_throw || force_abort)
      return;
  }

  if (eap->cmdidx == CMD_lgrep
      || eap->cmdidx == CMD_lvimgrep
      || eap->cmdidx == CMD_lgrepadd
      || eap->cmdidx == CMD_lvimgrepadd) {
    qi = ll_get_or_alloc_list(curwin);
    if (qi == NULL)
      return;
  }

  if (eap->addr_count > 0)
    tomatch = eap->line2;
  else
    tomatch = MAXLNUM;

  /* Get the search pattern: either white-separated or enclosed in // */
  regmatch.regprog = NULL;
  p = skip_vimgrep_pat(eap->arg, &s, &flags);
  if (p == NULL) {
    EMSG(_(e_invalpat));
    goto theend;
  }

  if (s != NULL && *s == NUL) {
    /* Pattern is empty, use last search pattern. */
    if (last_search_pat() == NULL) {
      EMSG(_(e_noprevre));
      goto theend;
    }
    regmatch.regprog = vim_regcomp(last_search_pat(), RE_MAGIC);
  } else
    regmatch.regprog = vim_regcomp(s, RE_MAGIC);

  if (regmatch.regprog == NULL)
    goto theend;
  regmatch.rmm_ic = p_ic;
  regmatch.rmm_maxcol = 0;

  p = skipwhite(p);
  if (*p == NUL) {
    EMSG(_("E683: File name missing or invalid pattern"));
    goto theend;
  }

  if ((eap->cmdidx != CMD_grepadd && eap->cmdidx != CMD_lgrepadd &&
       eap->cmdidx != CMD_vimgrepadd && eap->cmdidx != CMD_lvimgrepadd)
      || qi->qf_curlist == qi->qf_listcount)
    /* make place for a new list */
    qf_new_list(qi, *eap->cmdlinep);
  else if (qi->qf_lists[qi->qf_curlist].qf_count > 0)
    /* Adding to existing list, find last entry. */
    for (prevp = qi->qf_lists[qi->qf_curlist].qf_start;
         prevp->qf_next != prevp; prevp = prevp->qf_next)
      ;

  /* parse the list of arguments */
  if (get_arglist_exp(p, &fcount, &fnames, TRUE) == FAIL)
    goto theend;
  if (fcount == 0) {
    EMSG(_(e_nomatch));
    goto theend;
  }

  dirname_start = alloc(MAXPATHL);
  dirname_now = alloc(MAXPATHL);
  if (dirname_start == NULL || dirname_now == NULL)
    goto theend;

  /* Remember the current directory, because a BufRead autocommand that does
   * ":lcd %:p:h" changes the meaning of short path names. */
  mch_dirname(dirname_start, MAXPATHL);

  /* Remember the value of qf_start, so that we can check for autocommands
   * changing the current quickfix list. */
  cur_qf_start = qi->qf_lists[qi->qf_curlist].qf_start;

  seconds = (time_t)0;
  for (fi = 0; fi < fcount && !got_int && tomatch > 0; ++fi) {
    fname = shorten_fname1(fnames[fi]);
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
        vim_free(p);
      }
      msg_clr_eos();
      msg_didout = FALSE;           /* overwrite this message */
      msg_nowait = TRUE;            /* don't wait for this message */
      msg_col = 0;
      out_flush();
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
        smsg((char_u *)_("Cannot open file \"%s\""), fname);
    } else   {
      /* Try for a match in all lines of the buffer.
       * For ":1vimgrep" look for first match only. */
      found_match = FALSE;
      for (lnum = 1; lnum <= buf->b_ml.ml_line_count && tomatch > 0;
           ++lnum) {
        col = 0;
        while (vim_regexec_multi(&regmatch, curwin, buf, lnum,
                   col, NULL) > 0) {
          ;
          if (qf_add_entry(qi, &prevp,
                  NULL,                     /* dir */
                  fname,
                  0,
                  ml_get_buf(buf,
                      regmatch.startpos[0].lnum + lnum, FALSE),
                  regmatch.startpos[0].lnum + lnum,
                  regmatch.startpos[0].col + 1,
                  FALSE,                    /* vis_col */
                  NULL,                     /* search pattern */
                  0,                        /* nr */
                  0,                        /* type */
                  TRUE                      /* valid */
                  ) == FAIL) {
            got_int = TRUE;
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
          } else if (buf != first_match_buf || (flags & VGR_NOJUMP))   {
            unload_dummy_buffer(buf, dirname_start);
            buf = NULL;
          }
        }

        if (buf != NULL) {
          /* If the buffer is still loaded we need to use the
           * directory we jumped to below. */
          if (buf == first_match_buf
              && target_dir == NULL
              && STRCMP(dirname_start, dirname_now) != 0)
            target_dir = vim_strsave(dirname_now);

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

  qf_update_buffer(qi);

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
  vim_free(dirname_now);
  vim_free(dirname_start);
  vim_free(target_dir);
  vim_regfree(regmatch.regprog);
}

/*
 * Skip over the pattern argument of ":vimgrep /pat/[g][j]".
 * Put the start of the pattern in "*s", unless "s" is NULL.
 * If "flags" is not NULL put the flags in it: VGR_GLOBAL, VGR_NOJUMP.
 * If "s" is not NULL terminate the pattern with a NUL.
 * Return a pointer to the char just past the pattern plus flags.
 */
char_u *skip_vimgrep_pat(char_u *p, char_u **s, int *flags)
{
  int c;

  if (vim_isIDc(*p)) {
    /* ":vimgrep pattern fname" */
    if (s != NULL)
      *s = p;
    p = skiptowhite(p);
    if (s != NULL && *p != NUL)
      *p++ = NUL;
  } else   {
    /* ":vimgrep /pattern/[g][j] fname" */
    if (s != NULL)
      *s = p + 1;
    c = *p;
    p = skip_regexp(p + 1, c, TRUE, NULL);
    if (*p != c)
      return NULL;

    /* Truncate the pattern. */
    if (s != NULL)
      *p = NUL;
    ++p;

    /* Find the flags */
    while (*p == 'g' || *p == 'j') {
      if (flags != NULL) {
        if (*p == 'g')
          *flags |= VGR_GLOBAL;
        else
          *flags |= VGR_NOJUMP;
      }
      ++p;
    }
  }
  return p;
}

/*
 * Restore current working directory to "dirname_start" if they differ, taking
 * into account whether it is set locally or globally.
 */
static void restore_start_dir(char_u *dirname_start)
{
  char_u *dirname_now = alloc(MAXPATHL);

  if (NULL != dirname_now) {
    mch_dirname(dirname_now, MAXPATHL);
    if (STRCMP(dirname_start, dirname_now) != 0) {
      /* If the directory has changed, change it back by building up an
       * appropriate ex command and executing it. */
      exarg_T ea;

      ea.arg = dirname_start;
      ea.cmdidx = (curwin->w_localdir == NULL) ? CMD_cd : CMD_lcd;
      ex_cd(&ea);
    }
    vim_free(dirname_now);
  }
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
  buf_T       *newbuf_to_wipe = NULL;
  int failed = TRUE;
  aco_save_T aco;

  /* Allocate a buffer without putting it in the buffer list. */
  newbuf = buflist_new(NULL, NULL, (linenr_T)1, BLN_DUMMY);
  if (newbuf == NULL)
    return NULL;

  /* Init the options. */
  buf_copy_options(newbuf, BCO_ENTER | BCO_NOHELP);

  /* need to open the memfile before putting the buffer in a window */
  if (ml_open(newbuf) == OK) {
    /* set curwin/curbuf to buf and save a few things */
    aucmd_prepbuf(&aco, newbuf);

    /* Need to set the filename for autocommands. */
    (void)setfname(curbuf, fname, NULL, FALSE);

    /* Create swap file now to avoid the ATTENTION message. */
    check_need_swap(TRUE);

    /* Remove the "dummy" flag, otherwise autocommands may not
     * work. */
    curbuf->b_flags &= ~BF_DUMMY;

    if (readfile(fname, NULL,
            (linenr_T)0, (linenr_T)0, (linenr_T)MAXLNUM,
            NULL, READ_NEW | READ_DUMMY) == OK
        && !got_int
        && !(curbuf->b_flags & BF_NEW)) {
      failed = FALSE;
      if (curbuf != newbuf) {
        /* Bloody autocommands changed the buffer!  Can happen when
         * using netrw and editing a remote file.  Use the current
         * buffer instead, delete the dummy one after restoring the
         * window stuff. */
        newbuf_to_wipe = newbuf;
        newbuf = curbuf;
      }
    }

    /* restore curwin/curbuf and a few other things */
    aucmd_restbuf(&aco);
    if (newbuf_to_wipe != NULL && buf_valid(newbuf_to_wipe))
      wipe_buffer(newbuf_to_wipe, FALSE);
  }

  /*
   * When autocommands/'autochdir' option changed directory: go back.
   * Let the caller know what the resulting dir was first, in case it is
   * important.
   */
  mch_dirname(resulting_dir, MAXPATHL);
  restore_start_dir(dirname_start);

  if (!buf_valid(newbuf))
    return NULL;
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

/*
 * Add each quickfix error to list "list" as a dictionary.
 */
int get_errorlist(win_T *wp, list_T *list)
{
  qf_info_T   *qi = &ql_info;
  dict_T      *dict;
  char_u buf[2];
  qfline_T    *qfp;
  int i;
  int bufnum;

  if (wp != NULL) {
    qi = GET_LOC_LIST(wp);
    if (qi == NULL)
      return FAIL;
  }

  if (qi->qf_curlist >= qi->qf_listcount
      || qi->qf_lists[qi->qf_curlist].qf_count == 0)
    return FAIL;

  qfp = qi->qf_lists[qi->qf_curlist].qf_start;
  for (i = 1; !got_int && i <= qi->qf_lists[qi->qf_curlist].qf_count; ++i) {
    /* Handle entries with a non-existing buffer number. */
    bufnum = qfp->qf_fnum;
    if (bufnum != 0 && (buflist_findnr(bufnum) == NULL))
      bufnum = 0;

    if ((dict = dict_alloc()) == NULL)
      return FAIL;
    if (list_append_dict(list, dict) == FAIL)
      return FAIL;

    buf[0] = qfp->qf_type;
    buf[1] = NUL;
    if ( dict_add_nr_str(dict, "bufnr", (long)bufnum, NULL) == FAIL
         || dict_add_nr_str(dict, "lnum",  (long)qfp->qf_lnum, NULL) == FAIL
         || dict_add_nr_str(dict, "col",   (long)qfp->qf_col, NULL) == FAIL
         || dict_add_nr_str(dict, "vcol",  (long)qfp->qf_viscol, NULL) == FAIL
         || dict_add_nr_str(dict, "nr",    (long)qfp->qf_nr, NULL) == FAIL
         || dict_add_nr_str(dict, "pattern",  0L,
             qfp->qf_pattern == NULL ? (char_u *)"" : qfp->qf_pattern) == FAIL
         || dict_add_nr_str(dict, "text",  0L,
             qfp->qf_text == NULL ? (char_u *)"" : qfp->qf_text) == FAIL
         || dict_add_nr_str(dict, "type",  0L, buf) == FAIL
         || dict_add_nr_str(dict, "valid", (long)qfp->qf_valid, NULL) == FAIL)
      return FAIL;

    qfp = qfp->qf_next;
  }
  return OK;
}

/*
 * Populate the quickfix list with the items supplied in the list
 * of dictionaries. "title" will be copied to w:quickfix_title
 */
int set_errorlist(win_T *wp, list_T *list, int action, char_u *title)
{
  listitem_T  *li;
  dict_T      *d;
  char_u      *filename, *pattern, *text, *type;
  int bufnum;
  long lnum;
  int col, nr;
  int vcol;
  qfline_T    *prevp = NULL;
  int valid, status;
  int retval = OK;
  qf_info_T   *qi = &ql_info;
  int did_bufnr_emsg = FALSE;

  if (wp != NULL) {
    qi = ll_get_or_alloc_list(wp);
    if (qi == NULL)
      return FAIL;
  }

  if (action == ' ' || qi->qf_curlist == qi->qf_listcount)
    /* make place for a new list */
    qf_new_list(qi, title);
  else if (action == 'a' && qi->qf_lists[qi->qf_curlist].qf_count > 0)
    /* Adding to existing list, find last entry. */
    for (prevp = qi->qf_lists[qi->qf_curlist].qf_start;
         prevp->qf_next != prevp; prevp = prevp->qf_next)
      ;
  else if (action == 'r')
    qf_free(qi, qi->qf_curlist);

  for (li = list->lv_first; li != NULL; li = li->li_next) {
    if (li->li_tv.v_type != VAR_DICT)
      continue;       /* Skip non-dict items */

    d = li->li_tv.vval.v_dict;
    if (d == NULL)
      continue;

    filename = get_dict_string(d, (char_u *)"filename", TRUE);
    bufnum = get_dict_number(d, (char_u *)"bufnr");
    lnum = get_dict_number(d, (char_u *)"lnum");
    col = get_dict_number(d, (char_u *)"col");
    vcol = get_dict_number(d, (char_u *)"vcol");
    nr = get_dict_number(d, (char_u *)"nr");
    type = get_dict_string(d, (char_u *)"type", TRUE);
    pattern = get_dict_string(d, (char_u *)"pattern", TRUE);
    text = get_dict_string(d, (char_u *)"text", TRUE);
    if (text == NULL)
      text = vim_strsave((char_u *)"");

    valid = TRUE;
    if ((filename == NULL && bufnum == 0) || (lnum == 0 && pattern == NULL))
      valid = FALSE;

    /* Mark entries with non-existing buffer number as not valid. Give the
     * error message only once. */
    if (bufnum != 0 && (buflist_findnr(bufnum) == NULL)) {
      if (!did_bufnr_emsg) {
        did_bufnr_emsg = TRUE;
        EMSGN(_("E92: Buffer %ld not found"), bufnum);
      }
      valid = FALSE;
      bufnum = 0;
    }

    status =  qf_add_entry(qi, &prevp,
        NULL,                               /* dir */
        filename,
        bufnum,
        text,
        lnum,
        col,
        vcol,                               /* vis_col */
        pattern,                            /* search pattern */
        nr,
        type == NULL ? NUL : *type,
        valid);

    vim_free(filename);
    vim_free(pattern);
    vim_free(text);
    vim_free(type);

    if (status == FAIL) {
      retval = FAIL;
      break;
    }
  }

  if (qi->qf_lists[qi->qf_curlist].qf_index == 0)
    /* no valid entry */
    qi->qf_lists[qi->qf_curlist].qf_nonevalid = TRUE;
  else
    qi->qf_lists[qi->qf_curlist].qf_nonevalid = FALSE;
  qi->qf_lists[qi->qf_curlist].qf_ptr = qi->qf_lists[qi->qf_curlist].qf_start;
  qi->qf_lists[qi->qf_curlist].qf_index = 1;

  qf_update_buffer(qi);

  return retval;
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
  buf_T       *buf = NULL;
  qf_info_T   *qi = &ql_info;

  if (eap->cmdidx == CMD_lbuffer || eap->cmdidx == CMD_lgetbuffer
      || eap->cmdidx == CMD_laddbuffer) {
    qi = ll_get_or_alloc_list(curwin);
    if (qi == NULL)
      return;
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

      if (qf_init_ext(qi, NULL, buf, NULL, p_efm,
              (eap->cmdidx != CMD_caddbuffer
               && eap->cmdidx != CMD_laddbuffer),
              eap->line1, eap->line2,
              qf_title) > 0
          && (eap->cmdidx == CMD_cbuffer
              || eap->cmdidx == CMD_lbuffer))
        qf_jump(qi, 0, 0, eap->forceit);          /* display first error */
    }
  }
}

/*
 * ":cexpr {expr}", ":cgetexpr {expr}", ":caddexpr {expr}" command.
 * ":lexpr {expr}", ":lgetexpr {expr}", ":laddexpr {expr}" command.
 */
void ex_cexpr(exarg_T *eap)
{
  typval_T    *tv;
  qf_info_T   *qi = &ql_info;

  if (eap->cmdidx == CMD_lexpr || eap->cmdidx == CMD_lgetexpr
      || eap->cmdidx == CMD_laddexpr) {
    qi = ll_get_or_alloc_list(curwin);
    if (qi == NULL)
      return;
  }

  /* Evaluate the expression.  When the result is a string or a list we can
   * use it to fill the errorlist. */
  tv = eval_expr(eap->arg, NULL);
  if (tv != NULL) {
    if ((tv->v_type == VAR_STRING && tv->vval.v_string != NULL)
        || (tv->v_type == VAR_LIST && tv->vval.v_list != NULL)) {
      if (qf_init_ext(qi, NULL, NULL, tv, p_efm,
              (eap->cmdidx != CMD_caddexpr
               && eap->cmdidx != CMD_laddexpr),
              (linenr_T)0, (linenr_T)0, *eap->cmdlinep) > 0
          && (eap->cmdidx == CMD_cexpr
              || eap->cmdidx == CMD_lexpr))
        qf_jump(qi, 0, 0, eap->forceit);          /* display first error */
    } else
      EMSG(_("E777: String or List expected"));
    free_tv(tv);
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
  qfline_T    *prevp = NULL;
  long lnum;
  char_u      *lang;
  qf_info_T   *qi = &ql_info;
  int new_qi = FALSE;
  win_T       *wp;
  char_u      *au_name =  NULL;

  /* Check for a specified language */
  lang = check_help_lang(eap->arg);

  switch (eap->cmdidx) {
  case CMD_helpgrep:  au_name = (char_u *)"helpgrep"; break;
  case CMD_lhelpgrep: au_name = (char_u *)"lhelpgrep"; break;
  default: break;
  }
  if (au_name != NULL) {
    apply_autocmds(EVENT_QUICKFIXCMDPRE, au_name,
        curbuf->b_fname, TRUE, curbuf);
    if (did_throw || force_abort)
      return;
  }

  /* Make 'cpoptions' empty, the 'l' flag should not be used here. */
  save_cpo = p_cpo;
  p_cpo = empty_option;

  if (eap->cmdidx == CMD_lhelpgrep) {
    /* Find an existing help window */
    FOR_ALL_WINDOWS(wp)
    if (wp->w_buffer != NULL && wp->w_buffer->b_help)
      break;

    if (wp == NULL)         /* Help window not found */
      qi = NULL;
    else
      qi = wp->w_llist;

    if (qi == NULL) {
      /* Allocate a new location list for help text matches */
      if ((qi = ll_new_list()) == NULL)
        return;
      new_qi = TRUE;
    }
  }

  regmatch.regprog = vim_regcomp(eap->arg, RE_MAGIC + RE_STRING);
  regmatch.rm_ic = FALSE;
  if (regmatch.regprog != NULL) {
    vimconv_T vc;

    /* Help files are in utf-8 or latin1, convert lines when 'encoding'
     * differs. */
    vc.vc_type = CONV_NONE;
    if (!enc_utf8)
      convert_setup(&vc, (char_u *)"utf-8", p_enc);

    /* create a new quickfix list */
    qf_new_list(qi, *eap->cmdlinep);

    /* Go through all directories in 'runtimepath' */
    p = p_rtp;
    while (*p != NUL && !got_int) {
      copy_option_part(&p, NameBuff, MAXPATHL, ",");

      /* Find all "*.txt" and "*.??x" files in the "doc" directory. */
      add_pathsep(NameBuff);
      STRCAT(NameBuff, "doc/*.\\(txt\\|??x\\)");
      if (gen_expand_wildcards(1, &NameBuff, &fcount,
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
              /* Convert a line if 'encoding' is not utf-8 and
               * the line contains a non-ASCII character. */
              if (vc.vc_type != CONV_NONE
                  && has_non_ascii(IObuff)) {
                line = string_convert(&vc, IObuff, NULL);
                if (line == NULL)
                  line = IObuff;
              }

              if (vim_regexec(&regmatch, line, (colnr_T)0)) {
                int l = (int)STRLEN(line);

                /* remove trailing CR, LF, spaces, etc. */
                while (l > 0 && line[l - 1] <= ' ')
                  line[--l] = NUL;

                if (qf_add_entry(qi, &prevp,
                        NULL,                           /* dir */
                        fnames[fi],
                        0,
                        line,
                        lnum,
                        (int)(regmatch.startp[0] - line)
                        + 1,                                         /* col */
                        FALSE,                          /* vis_col */
                        NULL,                           /* search pattern */
                        0,                              /* nr */
                        1,                              /* type */
                        TRUE                            /* valid */
                        ) == FAIL) {
                  got_int = TRUE;
                  if (line != IObuff)
                    vim_free(line);
                  break;
                }
              }
              if (line != IObuff)
                vim_free(line);
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
    if (vc.vc_type != CONV_NONE)
      convert_setup(&vc, NULL, NULL);

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

  qf_update_buffer(qi);

  if (au_name != NULL) {
    apply_autocmds(EVENT_QUICKFIXCMDPOST, au_name,
        curbuf->b_fname, TRUE, curbuf);
    if (!new_qi && qi != &ql_info && qf_find_buf(qi) == NULL)
      /* autocommands made "qi" invalid */
      return;
  }

  /* Jump to first match. */
  if (qi->qf_lists[qi->qf_curlist].qf_count > 0)
    qf_jump(qi, 0, 0, FALSE);
  else
    EMSG2(_(e_nomatch2), eap->arg);

  if (eap->cmdidx == CMD_lhelpgrep) {
    /* If the help window is not opened or if it already points to the
     * correct location list, then free the new location list. */
    if (!curwin->w_buffer->b_help || curwin->w_llist == qi) {
      if (new_qi)
        ll_free_all(&qi);
    } else if (curwin->w_llist == NULL)
      curwin->w_llist = qi;
  }
}

