// cmdhist.c: Functions for the history of the command-line.

#include <assert.h>
#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cmdhist.h"
#include "nvim/errors.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_getln.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/macros_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option_vars.h"
#include "nvim/os/time.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "cmdhist.c.generated.h"
#endif

static histentry_T *(history[HIST_COUNT]) = { NULL, NULL, NULL, NULL, NULL };
static int hisidx[HIST_COUNT] = { -1, -1, -1, -1, -1 };  ///< lastused entry
/// identifying (unique) number of newest history entry
static int hisnum[HIST_COUNT] = { 0, 0, 0, 0, 0 };
static int hislen = 0;  ///< actual length of history tables

/// Return the length of the history tables
int get_hislen(void)
{
  return hislen;
}

/// Return a pointer to a specified history table
histentry_T *get_histentry(int hist_type)
{
  return history[hist_type];
}

void set_histentry(int hist_type, histentry_T *entry)
{
  history[hist_type] = entry;
}

int *get_hisidx(int hist_type)
{
  return &hisidx[hist_type];
}

int *get_hisnum(int hist_type)
{
  return &hisnum[hist_type];
}

/// Translate a history character to the associated type number
HistoryType hist_char2type(const int c)
  FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  switch (c) {
  case ':':
    return HIST_CMD;
  case '=':
    return HIST_EXPR;
  case '@':
    return HIST_INPUT;
  case '>':
    return HIST_DEBUG;
  case NUL:
  case '/':
  case '?':
    return HIST_SEARCH;
  default:
    return HIST_INVALID;
  }
  // Silence -Wreturn-type
  return 0;
}

/// Table of history names.
/// These names are used in :history and various hist...() functions.
/// It is sufficient to give the significant prefix of a history name.
static char *(history_names[]) = {
  "cmd",
  "search",
  "expr",
  "input",
  "debug",
  NULL
};

/// Function given to ExpandGeneric() to obtain the possible first
/// arguments of the ":history command.
char *get_history_arg(expand_T *xp, int idx)
{
  const char *short_names = ":=@>?/";
  const int short_names_count = (int)strlen(short_names);
  const int history_name_count = ARRAY_SIZE(history_names) - 1;

  if (idx < short_names_count) {
    xp->xp_buf[0] = short_names[idx];
    xp->xp_buf[1] = NUL;
    return xp->xp_buf;
  }
  if (idx < short_names_count + history_name_count) {
    return history_names[idx - short_names_count];
  }
  if (idx == short_names_count + history_name_count) {
    return "all";
  }
  return NULL;
}

/// Initialize command line history.
/// Also used to re-allocate history tables when size changes.
void init_history(void)
{
  assert(p_hi >= 0 && p_hi <= INT_MAX);
  int newlen = (int)p_hi;
  int oldlen = hislen;

  if (newlen == oldlen) {  // history length didn't change
    return;
  }

  // If history tables size changed, reallocate them.
  // Tables are circular arrays (current position marked by hisidx[type]).
  // On copying them to the new arrays, we take the chance to reorder them.
  for (int type = 0; type < HIST_COUNT; type++) {
    histentry_T *temp = (newlen > 0
                         ? xmalloc((size_t)newlen * sizeof(*temp))
                         : NULL);

    int j = hisidx[type];
    if (j >= 0) {
      // old array gets partitioned this way:
      // [0       , i1     ) --> newest entries to be deleted
      // [i1      , i1 + l1) --> newest entries to be copied
      // [i1 + l1 , i2     ) --> oldest entries to be deleted
      // [i2      , i2 + l2) --> oldest entries to be copied
      int l1 = MIN(j + 1, newlen);             // how many newest to copy
      int l2 = MIN(newlen, oldlen) - l1;       // how many oldest to copy
      int i1 = j + 1 - l1;                     // copy newest from here
      int i2 = MAX(l1, oldlen - newlen + l1);  // copy oldest from here

      // copy as much entries as they fit to new table, reordering them
      if (newlen) {
        // copy oldest entries
        memcpy(&temp[0], &history[type][i2], (size_t)l2 * sizeof(*temp));
        // copy newest entries
        memcpy(&temp[l2], &history[type][i1], (size_t)l1 * sizeof(*temp));
      }

      // delete entries that don't fit in newlen, if any
      for (int i = 0; i < i1; i++) {
        hist_free_entry(history[type] + i);
      }
      for (int i = i1 + l1; i < i2; i++) {
        hist_free_entry(history[type] + i);
      }
    }

    // clear remaining space, if any
    int l3 = j < 0 ? 0 : MIN(newlen, oldlen);  // number of copied entries
    if (newlen > 0) {
      memset(temp + l3, 0, (size_t)(newlen - l3) * sizeof(*temp));
    }

    hisidx[type] = l3 - 1;
    xfree(history[type]);
    history[type] = temp;
  }
  hislen = newlen;
}

static inline void hist_free_entry(histentry_T *hisptr)
  FUNC_ATTR_NONNULL_ALL
{
  xfree(hisptr->hisstr);
  tv_list_unref(hisptr->additional_elements);
  clear_hist_entry(hisptr);
}

static inline void clear_hist_entry(histentry_T *hisptr)
  FUNC_ATTR_NONNULL_ALL
{
  CLEAR_POINTER(hisptr);
}

/// Check if command line 'str' is already in history.
/// If 'move_to_front' is true, matching entry is moved to end of history.
///
/// @param move_to_front  Move the entry to the front if it exists
static int in_history(int type, const char *str, int move_to_front, int sep)
{
  int last_i = -1;

  if (hisidx[type] < 0) {
    return false;
  }
  int i = hisidx[type];
  do {
    if (history[type][i].hisstr == NULL) {
      return false;
    }

    // For search history, check that the separator character matches as
    // well.
    char *p = history[type][i].hisstr;
    if (strcmp(str, p) == 0
        && (type != HIST_SEARCH || sep == p[strlen(p) + 1])) {
      if (!move_to_front) {
        return true;
      }
      last_i = i;
      break;
    }
    if (--i < 0) {
      i = hislen - 1;
    }
  } while (i != hisidx[type]);

  if (last_i < 0) {
    return false;
  }

  list_T *const list = history[type][i].additional_elements;
  char *const save_hisstr = history[type][i].hisstr;
  while (i != hisidx[type]) {
    if (++i >= hislen) {
      i = 0;
    }
    history[type][last_i] = history[type][i];
    last_i = i;
  }
  tv_list_unref(list);
  history[type][i].hisnum = ++hisnum[type];
  history[type][i].hisstr = save_hisstr;
  history[type][i].timestamp = os_time();
  history[type][i].additional_elements = NULL;
  return true;
}

/// Convert history name to its HIST_ equivalent
///
/// Names are taken from the table above. When `name` is empty returns currently
/// active history or HIST_DEFAULT, depending on `return_default` argument.
///
/// @param[in]  name            Converted name.
/// @param[in]  len             Name length.
/// @param[in]  return_default  Determines whether HIST_DEFAULT should be
///                             returned or value based on `ccline.cmdfirstc`.
///
/// @return Any value from HistoryType enum, including HIST_INVALID. May not
///         return HIST_DEFAULT unless return_default is true.
static HistoryType get_histtype(const char *const name, const size_t len, const bool return_default)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  // No argument: use current history.
  if (len == 0) {
    return return_default ? HIST_DEFAULT : hist_char2type(get_cmdline_firstc());
  }

  for (HistoryType i = 0; history_names[i] != NULL; i++) {
    if (STRNICMP(name, history_names[i], len) == 0) {
      return i;
    }
  }

  if (vim_strchr(":=@>?/", (uint8_t)name[0]) != NULL && len == 1) {
    return hist_char2type(name[0]);
  }

  return HIST_INVALID;
}

static int last_maptick = -1;           // last seen maptick

/// Add the given string to the given history.  If the string is already in the
/// history then it is moved to the front.
///
/// @param histype  may be one of the HIST_ values.
/// @param in_map   consider maptick when inside a mapping
/// @param sep      separator character used (search hist)
void add_to_history(int histype, const char *new_entry, size_t new_entrylen, bool in_map, int sep)
{
  histentry_T *hisptr;

  if (hislen == 0 || histype == HIST_INVALID) {  // no history
    return;
  }
  assert(histype != HIST_DEFAULT);

  if ((cmdmod.cmod_flags & CMOD_KEEPPATTERNS) && histype == HIST_SEARCH) {
    return;
  }

  // Searches inside the same mapping overwrite each other, so that only
  // the last line is kept.  Be careful not to remove a line that was moved
  // down, only lines that were added.
  if (histype == HIST_SEARCH && in_map) {
    if (maptick == last_maptick && hisidx[HIST_SEARCH] >= 0) {
      // Current line is from the same mapping, remove it
      hisptr = &history[HIST_SEARCH][hisidx[HIST_SEARCH]];
      hist_free_entry(hisptr);
      hisnum[histype]--;
      if (--hisidx[HIST_SEARCH] < 0) {
        hisidx[HIST_SEARCH] = hislen - 1;
      }
    }
    last_maptick = -1;
  }

  if (in_history(histype, new_entry, true, sep)) {
    return;
  }

  if (++hisidx[histype] == hislen) {
    hisidx[histype] = 0;
  }
  hisptr = &history[histype][hisidx[histype]];
  hist_free_entry(hisptr);

  // Store the separator after the NUL of the string.
  hisptr->hisstr = xstrnsave(new_entry, new_entrylen + 2);
  hisptr->timestamp = os_time();
  hisptr->additional_elements = NULL;
  hisptr->hisstr[new_entrylen + 1] = (char)sep;

  hisptr->hisnum = ++hisnum[histype];
  if (histype == HIST_SEARCH && in_map) {
    last_maptick = maptick;
  }
}

/// Get identifier of newest history entry.
///
/// @param histype  may be one of the HIST_ values.
static int get_history_idx(int histype)
{
  if (hislen == 0 || histype < 0 || histype >= HIST_COUNT
      || hisidx[histype] < 0) {
    return -1;
  }

  return history[histype][hisidx[histype]].hisnum;
}

/// Calculate history index from a number:
///
/// @param num      > 0: seen as identifying number of a history entry
///                 < 0: relative position in history wrt newest entry
/// @param histype  may be one of the HIST_ values.
static int calc_hist_idx(int histype, int num)
{
  int i;

  if (hislen == 0 || histype < 0 || histype >= HIST_COUNT
      || (i = hisidx[histype]) < 0 || num == 0) {
    return -1;
  }

  histentry_T *hist = history[histype];
  if (num > 0) {
    bool wrapped = false;
    while (hist[i].hisnum > num) {
      if (--i < 0) {
        if (wrapped) {
          break;
        }
        i += hislen;
        wrapped = true;
      }
    }
    if (i >= 0 && hist[i].hisnum == num && hist[i].hisstr != NULL) {
      return i;
    }
  } else if (-num <= hislen) {
    i += num + 1;
    if (i < 0) {
      i += hislen;
    }
    if (hist[i].hisstr != NULL) {
      return i;
    }
  }
  return -1;
}

/// Get a history entry by its index.
///
/// @param histype  may be one of the HIST_ values.
static char *get_history_entry(int histype, int idx)
{
  idx = calc_hist_idx(histype, idx);
  if (idx >= 0) {
    return history[histype][idx].hisstr;
  } else {
    return "";
  }
}

/// Clear all entries in a history
///
/// @param[in]  histype  One of the HIST_ values.
///
/// @return OK if there was something to clean and histype was one of HIST_
///         values, FAIL otherwise.
int clr_history(const int histype)
{
  if (hislen != 0 && histype >= 0 && histype < HIST_COUNT) {
    histentry_T *hisptr = history[histype];
    for (int i = hislen; i--; hisptr++) {
      hist_free_entry(hisptr);
    }
    hisidx[histype] = -1;  // mark history as cleared
    hisnum[histype] = 0;   // reset identifier counter
    return OK;
  }
  return FAIL;
}

/// Remove all entries matching {str} from a history.
///
/// @param histype  may be one of the HIST_ values.
static int del_history_entry(int histype, char *str)
{
  if (hislen == 0 || histype < 0 || histype >= HIST_COUNT || *str == NUL
      || hisidx[histype] < 0) {
    return false;
  }

  const int idx = hisidx[histype];
  regmatch_T regmatch;
  regmatch.regprog = vim_regcomp(str, RE_MAGIC + RE_STRING);
  if (regmatch.regprog == NULL) {
    return false;
  }

  regmatch.rm_ic = false;       // always match case

  bool found = false;
  int i = idx;
  int last = idx;
  do {
    histentry_T *hisptr = &history[histype][i];
    if (hisptr->hisstr == NULL) {
      break;
    }
    if (vim_regexec(&regmatch, hisptr->hisstr, 0)) {
      found = true;
      hist_free_entry(hisptr);
    } else {
      if (i != last) {
        history[histype][last] = *hisptr;
        clear_hist_entry(hisptr);
      }
      if (--last < 0) {
        last += hislen;
      }
    }
    if (--i < 0) {
      i += hislen;
    }
  } while (i != idx);

  if (history[histype][idx].hisstr == NULL) {
    hisidx[histype] = -1;
  }

  vim_regfree(regmatch.regprog);
  return found;
}

/// Remove an indexed entry from a history.
///
/// @param histype  may be one of the HIST_ values.
static int del_history_idx(int histype, int idx)
{
  int i = calc_hist_idx(histype, idx);
  if (i < 0) {
    return false;
  }
  idx = hisidx[histype];
  hist_free_entry(&history[histype][i]);

  // When deleting the last added search string in a mapping, reset
  // last_maptick, so that the last added search string isn't deleted again.
  if (histype == HIST_SEARCH && maptick == last_maptick && i == idx) {
    last_maptick = -1;
  }

  while (i != idx) {
    int j = (i + 1) % hislen;
    history[histype][i] = history[histype][j];
    i = j;
  }
  clear_hist_entry(&history[histype][idx]);
  if (--i < 0) {
    i += hislen;
  }
  hisidx[histype] = i;
  return true;
}

/// "histadd()" function
void f_histadd(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = false;
  if (check_secure()) {
    return;
  }
  const char *str = tv_get_string_chk(&argvars[0]);  // NULL on type error
  HistoryType histype = str != NULL ? get_histtype(str, strlen(str), false) : HIST_INVALID;
  if (histype == HIST_INVALID) {
    return;
  }

  char buf[NUMBUFLEN];
  str = tv_get_string_buf(&argvars[1], buf);
  if (*str == NUL) {
    return;
  }

  init_history();
  add_to_history(histype, str, strlen(str), false, NUL);
  rettv->vval.v_number = true;
}

/// "histdel()" function
void f_histdel(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  int n;
  const char *const str = tv_get_string_chk(&argvars[0]);  // NULL on type error
  if (str == NULL) {
    n = 0;
  } else if (argvars[1].v_type == VAR_UNKNOWN) {
    // only one argument: clear entire history
    n = clr_history(get_histtype(str, strlen(str), false));
  } else if (argvars[1].v_type == VAR_NUMBER) {
    // index given: remove that entry
    n = del_history_idx(get_histtype(str, strlen(str), false),
                        (int)tv_get_number(&argvars[1]));
  } else {
    // string given: remove all matching entries
    char buf[NUMBUFLEN];
    n = del_history_entry(get_histtype(str, strlen(str), false),
                          (char *)tv_get_string_buf(&argvars[1], buf));
  }
  rettv->vval.v_number = n;
}

/// "histget()" function
void f_histget(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *const str = tv_get_string_chk(&argvars[0]);  // NULL on type error
  if (str == NULL) {
    rettv->vval.v_string = NULL;
  } else {
    int idx;
    HistoryType type = get_histtype(str, strlen(str), false);
    if (argvars[1].v_type == VAR_UNKNOWN) {
      idx = get_history_idx(type);
    } else {
      idx = (int)tv_get_number_chk(&argvars[1], NULL);
    }
    // -1 on type error
    rettv->vval.v_string = xstrdup(get_history_entry(type, idx));
  }
  rettv->v_type = VAR_STRING;
}

/// "histnr()" function
void f_histnr(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *const histname = tv_get_string_chk(&argvars[0]);
  HistoryType i = histname == NULL
                  ? HIST_INVALID
                  : get_histtype(histname, strlen(histname), false);
  if (i != HIST_INVALID) {
    i = get_history_idx(i);
  }
  rettv->vval.v_number = i;
}

/// :history command - print a history
void ex_history(exarg_T *eap)
{
  int histype1 = HIST_CMD;
  int histype2 = HIST_CMD;
  int hisidx1 = 1;
  int hisidx2 = -1;
  char *end;
  char *arg = eap->arg;

  if (hislen == 0) {
    msg(_("'history' option is zero"), 0);
    return;
  }

  if (!(ascii_isdigit(*arg) || *arg == '-' || *arg == ',')) {
    end = arg;
    while (ASCII_ISALPHA(*end)
           || vim_strchr(":=@>/?", (uint8_t)(*end)) != NULL) {
      end++;
    }
    histype1 = get_histtype(arg, (size_t)(end - arg), false);
    if (histype1 == HIST_INVALID) {
      if (STRNICMP(arg, "all", end - arg) == 0) {
        histype1 = 0;
        histype2 = HIST_COUNT - 1;
      } else {
        semsg(_(e_trailing_arg), arg);
        return;
      }
    } else {
      histype2 = histype1;
    }
  } else {
    end = arg;
  }
  if (!get_list_range(&end, &hisidx1, &hisidx2) || *end != NUL) {
    if (*end != NUL) {
      semsg(_(e_trailing_arg), end);
    } else {
      semsg(_(e_val_too_large), arg);
    }
    return;
  }

  for (; !got_int && histype1 <= histype2; histype1++) {
    xstrlcpy(IObuff, "\n      #  ", IOSIZE);
    assert(history_names[histype1] != NULL);
    xstrlcat(IObuff, history_names[histype1], IOSIZE);
    xstrlcat(IObuff, " history", IOSIZE);
    msg_puts_title(IObuff);
    int idx = hisidx[histype1];
    histentry_T *hist = history[histype1];
    int j = hisidx1;
    int k = hisidx2;
    if (j < 0) {
      j = (-j > hislen) ? 0 : hist[(hislen + j + idx + 1) % hislen].hisnum;
    }
    if (k < 0) {
      k = (-k > hislen) ? 0 : hist[(hislen + k + idx + 1) % hislen].hisnum;
    }
    if (idx >= 0 && j <= k) {
      for (int i = idx + 1; !got_int; i++) {
        if (i == hislen) {
          i = 0;
        }
        if (hist[i].hisstr != NULL
            && hist[i].hisnum >= j && hist[i].hisnum <= k
            && !message_filtered(hist[i].hisstr)) {
          msg_putchar('\n');
          snprintf(IObuff, IOSIZE, "%c%6d  ", i == idx ? '>' : ' ',
                   hist[i].hisnum);
          if (vim_strsize(hist[i].hisstr) > Columns - 10) {
            trunc_string(hist[i].hisstr, IObuff + strlen(IObuff),
                         Columns - 10, IOSIZE - (int)strlen(IObuff));
          } else {
            xstrlcat(IObuff, hist[i].hisstr, IOSIZE);
          }
          msg_outtrans(IObuff, 0);
        }
        if (i == idx) {
          break;
        }
      }
    }
  }
}

/// Iterate over history items
///
/// @warning No history-editing functions must be run while iteration is in
///          progress.
///
/// @param[in]   iter          Pointer to the last history entry.
/// @param[in]   history_type  Type of the history (HIST_*). Ignored if iter
///                            parameter is not NULL.
/// @param[in]   zero          If true then zero (but not free) returned items.
///
///                            @warning When using this parameter user is
///                                     responsible for calling clr_history()
///                                     itself after iteration is over. If
///                                     clr_history() is not called behaviour is
///                                     undefined. No functions that work with
///                                     history must be called during iteration
///                                     in this case.
/// @param[out]  hist          Next history entry.
///
/// @return Pointer used in next iteration or NULL to indicate that iteration
///         was finished.
const void *hist_iter(const void *const iter, const uint8_t history_type, const bool zero,
                      histentry_T *const hist)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(4)
{
  *hist = (histentry_T) {
    .hisstr = NULL
  };
  if (hisidx[history_type] == -1) {
    return NULL;
  }
  histentry_T *const hstart = &(history[history_type][0]);
  histentry_T *const hlast = &(history[history_type][hisidx[history_type]]);
  const histentry_T *const hend = &(history[history_type][hislen - 1]);
  histentry_T *hiter;
  if (iter == NULL) {
    histentry_T *hfirst = hlast;
    do {
      hfirst++;
      if (hfirst > hend) {
        hfirst = hstart;
      }
      if (hfirst->hisstr != NULL) {
        break;
      }
    } while (hfirst != hlast);
    hiter = hfirst;
  } else {
    hiter = (histentry_T *)iter;
  }
  if (hiter == NULL) {
    return NULL;
  }
  *hist = *hiter;
  if (zero) {
    CLEAR_POINTER(hiter);
  }
  if (hiter == hlast) {
    return NULL;
  }
  hiter++;
  return (const void *)((hiter > hend) ? hstart : hiter);
}

/// Get array of history items
///
/// @param[in]   history_type  Type of the history to get array for.
/// @param[out]  new_hisidx    Location where last index in the new array should
///                            be saved.
/// @param[out]  new_hisnum    Location where last history number in the new
///                            history should be saved.
///
/// @return Pointer to the array or NULL.
histentry_T *hist_get_array(const uint8_t history_type, int **const new_hisidx,
                            int **const new_hisnum)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  init_history();
  *new_hisidx = &(hisidx[history_type]);
  *new_hisnum = &(hisnum[history_type]);
  return history[history_type];
}
