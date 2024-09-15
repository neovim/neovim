#include <assert.h>
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/debugger.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/userfunc.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/fileio.h"
#include "nvim/garray.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/hashtab.h"
#include "nvim/hashtab_defs.h"
#include "nvim/keycodes.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/os/fs.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"
#include "nvim/pos_defs.h"
#include "nvim/profile.h"
#include "nvim/runtime.h"
#include "nvim/types_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "profile.c.generated.h"
#endif

/// Struct used in sn_prl_ga for every line of a script.
typedef struct {
  int snp_count;                ///< nr of times line was executed
  proftime_T sn_prl_total;      ///< time spent in a line + children
  proftime_T sn_prl_self;       ///< time spent in a line itself
} sn_prl_T;

#define PRL_ITEM(si, idx)     (((sn_prl_T *)(si)->sn_prl_ga.ga_data)[(idx)])

static proftime_T prof_wait_time;
static char *startuptime_buf = NULL;  // --startuptime buffer

/// Gets the current time.
///
/// @return the current time
proftime_T profile_start(void) FUNC_ATTR_WARN_UNUSED_RESULT
{
  return os_hrtime();
}

/// Computes the time elapsed.
///
/// @return Elapsed time from `tm` until now.
proftime_T profile_end(proftime_T tm) FUNC_ATTR_WARN_UNUSED_RESULT
{
  return profile_sub(os_hrtime(), tm);
}

/// Gets a string representing time `tm`.
///
/// @warning Do not modify or free this string, not multithread-safe.
///
/// @param tm Time
/// @return Static string representing `tm` in the form "seconds.microseconds".
const char *profile_msg(proftime_T tm) FUNC_ATTR_WARN_UNUSED_RESULT
{
  static char buf[50];
  snprintf(buf, sizeof(buf), "%10.6lf",
           (double)profile_signed(tm) / 1000000000.0);
  return buf;
}

/// Gets the time `msec` into the future.
///
/// @param msec milliseconds, the maximum number of milliseconds is
///             (2^63 / 10^6) - 1 = 9.223372e+12.
/// @return if msec > 0, returns the time msec past now. Otherwise returns
///         the zero time.
proftime_T profile_setlimit(int64_t msec) FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (msec <= 0) {
    // no limit
    return profile_zero();
  }
  assert(msec <= (INT64_MAX / 1000000LL) - 1);
  proftime_T nsec = (proftime_T)msec * 1000000ULL;
  return os_hrtime() + nsec;
}

/// Checks if current time has passed `tm`.
///
/// @return true if the current time is past `tm`, false if not or if the
///         timer was not set.
bool profile_passed_limit(proftime_T tm) FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (tm == 0) {
    // timer was not set
    return false;
  }

  return profile_cmp(os_hrtime(), tm) < 0;
}

/// Gets the zero time.
///
/// @return the zero time
proftime_T profile_zero(void) FUNC_ATTR_CONST
{
  return 0;
}

/// Divides time `tm` by `count`.
///
/// @return 0 if count <= 0, otherwise tm / count
proftime_T profile_divide(proftime_T tm, int count) FUNC_ATTR_CONST
{
  if (count <= 0) {
    return profile_zero();
  }

  return (proftime_T)round((double)tm / (double)count);
}

/// Adds time `tm2` to `tm1`.
///
/// @return `tm1` + `tm2`
proftime_T profile_add(proftime_T tm1, proftime_T tm2) FUNC_ATTR_CONST
{
  return tm1 + tm2;
}

/// Subtracts time `tm2` from `tm1`.
///
/// Unsigned overflow (wraparound) occurs if `tm2` is greater than `tm1`.
/// Use `profile_signed()` to get the signed integer value.
///
/// @see profile_signed
///
/// @return `tm1` - `tm2`
proftime_T profile_sub(proftime_T tm1, proftime_T tm2) FUNC_ATTR_CONST
{
  return tm1 - tm2;
}

/// Adds the `self` time from the total time and the `children` time.
///
/// @return if `total` <= `children`, then self, otherwise `self` + `total` -
///         `children`
proftime_T profile_self(proftime_T self, proftime_T total, proftime_T children)
  FUNC_ATTR_CONST
{
  // check that the result won't be negative, which can happen with
  // recursive calls.
  if (total <= children) {
    return self;
  }

  // add the total time to self and subtract the children's time from self
  return profile_sub(profile_add(self, total), children);
}

/// Gets the current waittime.
///
/// @return the current waittime
proftime_T profile_get_wait(void) FUNC_ATTR_PURE
{
  return prof_wait_time;
}

/// Sets the current waittime.
void profile_set_wait(proftime_T wait)
{
  prof_wait_time = wait;
}

/// Subtracts the passed waittime since `tm`.
///
/// @return `tma` - (waittime - `tm`)
proftime_T profile_sub_wait(proftime_T tm, proftime_T tma) FUNC_ATTR_PURE
{
  proftime_T tm3 = profile_sub(profile_get_wait(), tm);
  return profile_sub(tma, tm3);
}

/// Checks if time `tm1` is equal to `tm2`.
///
/// @return true if `tm1` == `tm2`
bool profile_equal(proftime_T tm1, proftime_T tm2) FUNC_ATTR_CONST
{
  return tm1 == tm2;
}

/// Converts time duration `tm` (`profile_sub` result) to a signed integer.
///
/// @return signed representation of the given time value
int64_t profile_signed(proftime_T tm)
  FUNC_ATTR_CONST
{
  // (tm > INT64_MAX) is >=150 years, so we can assume it was produced by
  // arithmetic of two proftime_T values.  For human-readable representation
  // (and Vim-compat) we want the difference after unsigned wraparound. #10452
  return (tm <= INT64_MAX) ? (int64_t)tm : -(int64_t)(UINT64_MAX - tm);
}

/// Compares profiling times.
///
/// Times `tm1` and `tm2` must be less than 150 years apart.
///
/// @return <0: `tm2` < `tm1`
///          0: `tm2` == `tm1`
///         >0: `tm2` > `tm1`
int profile_cmp(proftime_T tm1, proftime_T tm2) FUNC_ATTR_CONST
{
  if (tm1 == tm2) {
    return 0;
  }
  return profile_signed(tm2 - tm1) < 0 ? -1 : 1;
}

static char *profile_fname = NULL;

/// Reset all profiling information.
void profile_reset(void)
{
  // Reset sourced files.
  for (int id = 1; id <= script_items.ga_len; id++) {
    scriptitem_T *si = SCRIPT_ITEM(id);
    if (si->sn_prof_on) {
      si->sn_prof_on = false;
      si->sn_pr_force = false;
      si->sn_pr_child = profile_zero();
      si->sn_pr_nest = 0;
      si->sn_pr_count = 0;
      si->sn_pr_total = profile_zero();
      si->sn_pr_self = profile_zero();
      si->sn_pr_start = profile_zero();
      si->sn_pr_children = profile_zero();
      ga_clear(&si->sn_prl_ga);
      si->sn_prl_start = profile_zero();
      si->sn_prl_children = profile_zero();
      si->sn_prl_wait = profile_zero();
      si->sn_prl_idx = -1;
      si->sn_prl_execed = 0;
    }
  }

  // Reset functions.
  hashtab_T *const functbl = func_tbl_get();
  size_t todo = functbl->ht_used;
  hashitem_T *hi = functbl->ht_array;

  for (; todo > 0; hi++) {
    if (!HASHITEM_EMPTY(hi)) {
      todo--;
      ufunc_T *uf = HI2UF(hi);
      if (uf->uf_prof_initialized) {
        uf->uf_profiling = 0;
        uf->uf_tm_count = 0;
        uf->uf_tm_total = profile_zero();
        uf->uf_tm_self = profile_zero();
        uf->uf_tm_children = profile_zero();

        for (int i = 0; i < uf->uf_lines.ga_len; i++) {
          uf->uf_tml_count[i] = 0;
          uf->uf_tml_total[i] = uf->uf_tml_self[i] = 0;
        }

        uf->uf_tml_start = profile_zero();
        uf->uf_tml_children = profile_zero();
        uf->uf_tml_wait = profile_zero();
        uf->uf_tml_idx = -1;
        uf->uf_tml_execed = 0;
      }
    }
  }

  XFREE_CLEAR(profile_fname);
}

/// ":profile cmd args"
void ex_profile(exarg_T *eap)
{
  static proftime_T pause_time;

  char *e = skiptowhite(eap->arg);
  int len = (int)(e - eap->arg);
  e = skipwhite(e);

  if (len == 5 && strncmp(eap->arg, "start", 5) == 0 && *e != NUL) {
    xfree(profile_fname);
    profile_fname = expand_env_save_opt(e, true);
    do_profiling = PROF_YES;
    profile_set_wait(profile_zero());
    set_vim_var_nr(VV_PROFILING, 1);
  } else if (do_profiling == PROF_NONE) {
    emsg(_("E750: First use \":profile start {fname}\""));
  } else if (strcmp(eap->arg, "stop") == 0) {
    profile_dump();
    do_profiling = PROF_NONE;
    set_vim_var_nr(VV_PROFILING, 0);
    profile_reset();
  } else if (strcmp(eap->arg, "pause") == 0) {
    if (do_profiling == PROF_YES) {
      pause_time = profile_start();
    }
    do_profiling = PROF_PAUSED;
  } else if (strcmp(eap->arg, "continue") == 0) {
    if (do_profiling == PROF_PAUSED) {
      pause_time = profile_end(pause_time);
      profile_set_wait(profile_add(profile_get_wait(), pause_time));
    }
    do_profiling = PROF_YES;
  } else if (strcmp(eap->arg, "dump") == 0) {
    profile_dump();
  } else {
    // The rest is similar to ":breakadd".
    ex_breakadd(eap);
  }
}

/// Command line expansion for :profile.
static enum {
  PEXP_SUBCMD,          ///< expand :profile sub-commands
  PEXP_FUNC,  ///< expand :profile func {funcname}
} pexpand_what;

static char *pexpand_cmds[] = {
  "continue",
  "dump",
  "file",
  "func",
  "pause",
  "start",
  "stop",
  NULL
};

/// Function given to ExpandGeneric() to obtain the profile command
/// specific expansion.
char *get_profile_name(expand_T *xp, int idx)
  FUNC_ATTR_PURE
{
  switch (pexpand_what) {
  case PEXP_SUBCMD:
    return pexpand_cmds[idx];
  default:
    return NULL;
  }
}

/// Handle command line completion for :profile command.
void set_context_in_profile_cmd(expand_T *xp, const char *arg)
{
  // Default: expand subcommands.
  xp->xp_context = EXPAND_PROFILE;
  pexpand_what = PEXP_SUBCMD;
  xp->xp_pattern = (char *)arg;

  char *const end_subcmd = skiptowhite(arg);
  if (*end_subcmd == NUL) {
    return;
  }

  if ((end_subcmd - arg == 5 && strncmp(arg, "start", 5) == 0)
      || (end_subcmd - arg == 4 && strncmp(arg, "file", 4) == 0)) {
    xp->xp_context = EXPAND_FILES;
    xp->xp_pattern = skipwhite(end_subcmd);
    return;
  } else if (end_subcmd - arg == 4 && strncmp(arg, "func", 4) == 0) {
    xp->xp_context = EXPAND_USER_FUNC;
    xp->xp_pattern = skipwhite(end_subcmd);
    return;
  }

  xp->xp_context = EXPAND_NOTHING;
}

static proftime_T wait_time;

/// Called when starting to wait for the user to type a character.
void prof_input_start(void)
{
  wait_time = profile_start();
}

/// Called when finished waiting for the user to type a character.
void prof_input_end(void)
{
  wait_time = profile_end(wait_time);
  profile_set_wait(profile_add(profile_get_wait(), wait_time));
}

/// @return  true when a function defined in the current script should be
///          profiled.
bool prof_def_func(void)
  FUNC_ATTR_PURE
{
  if (current_sctx.sc_sid > 0) {
    return SCRIPT_ITEM(current_sctx.sc_sid)->sn_pr_force;
  }
  return false;
}

/// Print the count and times for one function or function line.
///
/// @param prefer_self  when equal print only self time
static void prof_func_line(FILE *fd, int count, const proftime_T *total, const proftime_T *self,
                           bool prefer_self)
{
  if (count > 0) {
    fprintf(fd, "%5d ", count);
    if (prefer_self && profile_equal(*total, *self)) {
      fprintf(fd, "           ");
    } else {
      fprintf(fd, "%s ", profile_msg(*total));
    }
    if (!prefer_self && profile_equal(*total, *self)) {
      fprintf(fd, "           ");
    } else {
      fprintf(fd, "%s ", profile_msg(*self));
    }
  } else {
    fprintf(fd, "                            ");
  }
}

/// @param prefer_self  when equal print only self time
static void prof_sort_list(FILE *fd, ufunc_T **sorttab, int st_len, char *title, bool prefer_self)
{
  fprintf(fd, "FUNCTIONS SORTED ON %s TIME\n", title);
  fprintf(fd, "count  total (s)   self (s)  function\n");
  for (int i = 0; i < 20 && i < st_len; i++) {
    ufunc_T *fp = sorttab[i];
    prof_func_line(fd, fp->uf_tm_count, &fp->uf_tm_total, &fp->uf_tm_self,
                   prefer_self);
    if ((uint8_t)fp->uf_name[0] == K_SPECIAL) {
      fprintf(fd, " <SNR>%s()\n", fp->uf_name + 3);
    } else {
      fprintf(fd, " %s()\n", fp->uf_name);
    }
  }
  fprintf(fd, "\n");
}

/// Compare function for total time sorting.
static int prof_total_cmp(const void *s1, const void *s2)
{
  ufunc_T *p1 = *(ufunc_T **)s1;
  ufunc_T *p2 = *(ufunc_T **)s2;
  return profile_cmp(p1->uf_tm_total, p2->uf_tm_total);
}

/// Compare function for self time sorting.
static int prof_self_cmp(const void *s1, const void *s2)
{
  ufunc_T *p1 = *(ufunc_T **)s1;
  ufunc_T *p2 = *(ufunc_T **)s2;
  return profile_cmp(p1->uf_tm_self, p2->uf_tm_self);
}

/// Start profiling function "fp".
void func_do_profile(ufunc_T *fp)
{
  int len = fp->uf_lines.ga_len;

  if (!fp->uf_prof_initialized) {
    if (len == 0) {
      len = 1;  // avoid getting error for allocating zero bytes
    }
    fp->uf_tm_count = 0;
    fp->uf_tm_self = profile_zero();
    fp->uf_tm_total = profile_zero();

    if (fp->uf_tml_count == NULL) {
      fp->uf_tml_count = xcalloc((size_t)len, sizeof(int));
    }

    if (fp->uf_tml_total == NULL) {
      fp->uf_tml_total = xcalloc((size_t)len, sizeof(proftime_T));
    }

    if (fp->uf_tml_self == NULL) {
      fp->uf_tml_self = xcalloc((size_t)len, sizeof(proftime_T));
    }

    fp->uf_tml_idx = -1;
    fp->uf_prof_initialized = true;
  }

  fp->uf_profiling = true;
}

/// Prepare profiling for entering a child or something else that is not
/// counted for the script/function itself.
/// Should always be called in pair with prof_child_exit().
///
/// @param tm  place to store waittime
void prof_child_enter(proftime_T *tm)
{
  funccall_T *fc = get_current_funccal();

  if (fc != NULL && fc->fc_func->uf_profiling) {
    fc->fc_prof_child = profile_start();
  }

  script_prof_save(tm);
}

/// Take care of time spent in a child.
/// Should always be called after prof_child_enter().
///
/// @param tm  where waittime was stored
void prof_child_exit(proftime_T *tm)
{
  funccall_T *fc = get_current_funccal();

  if (fc != NULL && fc->fc_func->uf_profiling) {
    fc->fc_prof_child = profile_end(fc->fc_prof_child);
    // don't count waiting time
    fc->fc_prof_child = profile_sub_wait(*tm, fc->fc_prof_child);
    fc->fc_func->uf_tm_children =
      profile_add(fc->fc_func->uf_tm_children, fc->fc_prof_child);
    fc->fc_func->uf_tml_children =
      profile_add(fc->fc_func->uf_tml_children, fc->fc_prof_child);
  }
  script_prof_restore(tm);
}

/// Called when starting to read a function line.
/// "sourcing_lnum" must be correct!
/// When skipping lines it may not actually be executed, but we won't find out
/// until later and we need to store the time now.
void func_line_start(void *cookie)
{
  funccall_T *fcp = (funccall_T *)cookie;
  ufunc_T *fp = fcp->fc_func;

  if (fp->uf_profiling && SOURCING_LNUM >= 1 && SOURCING_LNUM <= fp->uf_lines.ga_len) {
    fp->uf_tml_idx = SOURCING_LNUM - 1;
    // Skip continuation lines.
    while (fp->uf_tml_idx > 0 && FUNCLINE(fp, fp->uf_tml_idx) == NULL) {
      fp->uf_tml_idx--;
    }
    fp->uf_tml_execed = false;
    fp->uf_tml_start = profile_start();
    fp->uf_tml_children = profile_zero();
    fp->uf_tml_wait = profile_get_wait();
  }
}

/// Called when actually executing a function line.
void func_line_exec(void *cookie)
{
  funccall_T *fcp = (funccall_T *)cookie;
  ufunc_T *fp = fcp->fc_func;

  if (fp->uf_profiling && fp->uf_tml_idx >= 0) {
    fp->uf_tml_execed = true;
  }
}

/// Called when done with a function line.
void func_line_end(void *cookie)
{
  funccall_T *fcp = (funccall_T *)cookie;
  ufunc_T *fp = fcp->fc_func;

  if (fp->uf_profiling && fp->uf_tml_idx >= 0) {
    if (fp->uf_tml_execed) {
      fp->uf_tml_count[fp->uf_tml_idx]++;
      fp->uf_tml_start = profile_end(fp->uf_tml_start);
      fp->uf_tml_start = profile_sub_wait(fp->uf_tml_wait, fp->uf_tml_start);
      fp->uf_tml_total[fp->uf_tml_idx] =
        profile_add(fp->uf_tml_total[fp->uf_tml_idx], fp->uf_tml_start);
      fp->uf_tml_self[fp->uf_tml_idx] =
        profile_self(fp->uf_tml_self[fp->uf_tml_idx], fp->uf_tml_start,
                     fp->uf_tml_children);
    }
    fp->uf_tml_idx = -1;
  }
}

/// Dump the profiling results for all functions in file "fd".
static void func_dump_profile(FILE *fd)
{
  hashtab_T *const functbl = func_tbl_get();
  int st_len = 0;

  int todo = (int)functbl->ht_used;
  if (todo == 0) {
    return;         // nothing to dump
  }

  ufunc_T **sorttab = xmalloc(sizeof(ufunc_T *) * (size_t)todo);

  for (hashitem_T *hi = functbl->ht_array; todo > 0; hi++) {
    if (!HASHITEM_EMPTY(hi)) {
      todo--;
      ufunc_T *fp = HI2UF(hi);
      if (fp->uf_prof_initialized) {
        sorttab[st_len++] = fp;

        if ((uint8_t)fp->uf_name[0] == K_SPECIAL) {
          fprintf(fd, "FUNCTION  <SNR>%s()\n", fp->uf_name + 3);
        } else {
          fprintf(fd, "FUNCTION  %s()\n", fp->uf_name);
        }
        if (fp->uf_script_ctx.sc_sid != 0) {
          bool should_free;
          const LastSet last_set = (LastSet){
            .script_ctx = fp->uf_script_ctx,
            .channel_id = 0,
          };
          char *p = get_scriptname(last_set, &should_free);
          fprintf(fd, "    Defined: %s:%" PRIdLINENR "\n",
                  p, fp->uf_script_ctx.sc_lnum);
          if (should_free) {
            xfree(p);
          }
        }
        if (fp->uf_tm_count == 1) {
          fprintf(fd, "Called 1 time\n");
        } else {
          fprintf(fd, "Called %d times\n", fp->uf_tm_count);
        }
        fprintf(fd, "Total time: %s\n", profile_msg(fp->uf_tm_total));
        fprintf(fd, " Self time: %s\n", profile_msg(fp->uf_tm_self));
        fprintf(fd, "\n");
        fprintf(fd, "count  total (s)   self (s)\n");

        for (int i = 0; i < fp->uf_lines.ga_len; i++) {
          if (FUNCLINE(fp, i) == NULL) {
            continue;
          }
          prof_func_line(fd, fp->uf_tml_count[i],
                         &fp->uf_tml_total[i], &fp->uf_tml_self[i], true);
          fprintf(fd, "%s\n", FUNCLINE(fp, i));
        }
        fprintf(fd, "\n");
      }
    }
  }

  if (st_len > 0) {
    qsort((void *)sorttab, (size_t)st_len, sizeof(ufunc_T *),
          prof_total_cmp);
    prof_sort_list(fd, sorttab, st_len, "TOTAL", false);
    qsort((void *)sorttab, (size_t)st_len, sizeof(ufunc_T *),
          prof_self_cmp);
    prof_sort_list(fd, sorttab, st_len, "SELF", true);
  }

  xfree(sorttab);
}

/// Start profiling a script.
void profile_init(scriptitem_T *si)
{
  si->sn_pr_count = 0;
  si->sn_pr_total = profile_zero();
  si->sn_pr_self = profile_zero();

  ga_init(&si->sn_prl_ga, sizeof(sn_prl_T), 100);
  si->sn_prl_idx = -1;
  si->sn_prof_on = true;
  si->sn_pr_nest = 0;
}

/// Save time when starting to invoke another script or function.
///
/// @param tm  place to store wait time
void script_prof_save(proftime_T *tm)
{
  if (current_sctx.sc_sid > 0 && current_sctx.sc_sid <= script_items.ga_len) {
    scriptitem_T *si = SCRIPT_ITEM(current_sctx.sc_sid);
    if (si->sn_prof_on && si->sn_pr_nest++ == 0) {
      si->sn_pr_child = profile_start();
    }
  }
  *tm = profile_get_wait();
}

/// Count time spent in children after invoking another script or function.
void script_prof_restore(const proftime_T *tm)
{
  if (!SCRIPT_ID_VALID(current_sctx.sc_sid)) {
    return;
  }

  scriptitem_T *si = SCRIPT_ITEM(current_sctx.sc_sid);
  if (si->sn_prof_on && --si->sn_pr_nest == 0) {
    si->sn_pr_child = profile_end(si->sn_pr_child);
    // don't count wait time
    si->sn_pr_child = profile_sub_wait(*tm, si->sn_pr_child);
    si->sn_pr_children = profile_add(si->sn_pr_children, si->sn_pr_child);
    si->sn_prl_children = profile_add(si->sn_prl_children, si->sn_pr_child);
  }
}

/// Dump the profiling results for all scripts in file "fd".
static void script_dump_profile(FILE *fd)
{
  sn_prl_T *pp;

  for (int id = 1; id <= script_items.ga_len; id++) {
    scriptitem_T *si = SCRIPT_ITEM(id);
    if (si->sn_prof_on) {
      fprintf(fd, "SCRIPT  %s\n", si->sn_name);
      if (si->sn_pr_count == 1) {
        fprintf(fd, "Sourced 1 time\n");
      } else {
        fprintf(fd, "Sourced %d times\n", si->sn_pr_count);
      }
      fprintf(fd, "Total time: %s\n", profile_msg(si->sn_pr_total));
      fprintf(fd, " Self time: %s\n", profile_msg(si->sn_pr_self));
      fprintf(fd, "\n");
      fprintf(fd, "count  total (s)   self (s)\n");

      FILE *sfd = os_fopen(si->sn_name, "r");
      if (sfd == NULL) {
        fprintf(fd, "Cannot open file!\n");
      } else {
        // Keep going till the end of file, so that trailing
        // continuation lines are listed.
        for (int i = 0;; i++) {
          if (vim_fgets(IObuff, IOSIZE, sfd)) {
            break;
          }
          // When a line has been truncated, append NL, taking care
          // of multi-byte characters .
          if (IObuff[IOSIZE - 2] != NUL && IObuff[IOSIZE - 2] != NL) {
            int n = IOSIZE - 2;

            // Move to the first byte of this char.
            // utf_head_off() doesn't work, because it checks
            // for a truncated character.
            while (n > 0 && (IObuff[n] & 0xc0) == 0x80) {
              n--;
            }

            IObuff[n] = NL;
            IObuff[n + 1] = NUL;
          }
          if (i < si->sn_prl_ga.ga_len
              && (pp = &PRL_ITEM(si, i))->snp_count > 0) {
            fprintf(fd, "%5d ", pp->snp_count);
            if (profile_equal(pp->sn_prl_total, pp->sn_prl_self)) {
              fprintf(fd, "           ");
            } else {
              fprintf(fd, "%s ", profile_msg(pp->sn_prl_total));
            }
            fprintf(fd, "%s ", profile_msg(pp->sn_prl_self));
          } else {
            fprintf(fd, "                            ");
          }
          fprintf(fd, "%s", IObuff);
        }
        fclose(sfd);
      }
      fprintf(fd, "\n");
    }
  }
}

/// Dump the profiling info.
void profile_dump(void)
{
  if (profile_fname == NULL) {
    return;
  }

  FILE *fd = os_fopen(profile_fname, "w");
  if (fd == NULL) {
    semsg(_(e_notopen), profile_fname);
  } else {
    script_dump_profile(fd);
    func_dump_profile(fd);
    fclose(fd);
  }
}

/// Called when starting to read a script line.
/// "sourcing_lnum" must be correct!
/// When skipping lines it may not actually be executed, but we won't find out
/// until later and we need to store the time now.
void script_line_start(void)
{
  if (current_sctx.sc_sid <= 0 || current_sctx.sc_sid > script_items.ga_len) {
    return;
  }
  scriptitem_T *si = SCRIPT_ITEM(current_sctx.sc_sid);
  if (si->sn_prof_on && SOURCING_LNUM >= 1) {
    // Grow the array before starting the timer, so that the time spent
    // here isn't counted.
    ga_grow(&si->sn_prl_ga, SOURCING_LNUM - si->sn_prl_ga.ga_len);
    si->sn_prl_idx = SOURCING_LNUM - 1;
    while (si->sn_prl_ga.ga_len <= si->sn_prl_idx
           && si->sn_prl_ga.ga_len < si->sn_prl_ga.ga_maxlen) {
      // Zero counters for a line that was not used before.
      sn_prl_T *pp = &PRL_ITEM(si, si->sn_prl_ga.ga_len);
      pp->snp_count = 0;
      pp->sn_prl_total = profile_zero();
      pp->sn_prl_self = profile_zero();
      si->sn_prl_ga.ga_len++;
    }
    si->sn_prl_execed = false;
    si->sn_prl_start = profile_start();
    si->sn_prl_children = profile_zero();
    si->sn_prl_wait = profile_get_wait();
  }
}

/// Called when actually executing a function line.
void script_line_exec(void)
{
  if (current_sctx.sc_sid <= 0 || current_sctx.sc_sid > script_items.ga_len) {
    return;
  }
  scriptitem_T *si = SCRIPT_ITEM(current_sctx.sc_sid);
  if (si->sn_prof_on && si->sn_prl_idx >= 0) {
    si->sn_prl_execed = true;
  }
}

/// Called when done with a function line.
void script_line_end(void)
{
  if (current_sctx.sc_sid <= 0 || current_sctx.sc_sid > script_items.ga_len) {
    return;
  }
  scriptitem_T *si = SCRIPT_ITEM(current_sctx.sc_sid);
  if (si->sn_prof_on && si->sn_prl_idx >= 0
      && si->sn_prl_idx < si->sn_prl_ga.ga_len) {
    if (si->sn_prl_execed) {
      sn_prl_T *pp = &PRL_ITEM(si, si->sn_prl_idx);
      pp->snp_count++;
      si->sn_prl_start = profile_end(si->sn_prl_start);
      si->sn_prl_start = profile_sub_wait(si->sn_prl_wait, si->sn_prl_start);
      pp->sn_prl_total = profile_add(pp->sn_prl_total, si->sn_prl_start);
      pp->sn_prl_self = profile_self(pp->sn_prl_self, si->sn_prl_start,
                                     si->sn_prl_children);
    }
    si->sn_prl_idx = -1;
  }
}

/// globals for use in the startuptime related functionality (time_*).
static proftime_T g_start_time;
static proftime_T g_prev_time;

/// Saves the previous time before doing something that could nest.
///
/// After calling this function, the static global `g_prev_time` will
/// contain the current time.
///
/// @param[out] rel to the time elapsed so far
/// @param[out] start the current time
void time_push(proftime_T *rel, proftime_T *start)
{
  proftime_T now = profile_start();

  // subtract the previous time from now, store it in `rel`
  *rel = profile_sub(now, g_prev_time);
  *start = now;

  // reset global `g_prev_time` for the next call
  g_prev_time = now;
}

/// Computes the prev time after doing something that could nest.
///
/// Subtracts `tp` from the static global `g_prev_time`.
///
/// @param tp the time to subtract
void time_pop(proftime_T tp)
{
  g_prev_time -= tp;
}

/// Prints the difference between `then` and `now`.
///
/// the format is "msec.usec".
static void time_diff(proftime_T then, proftime_T now)
{
  proftime_T diff = profile_sub(now, then);
  fprintf(time_fd, "%07.3lf", (double)diff / 1.0E6);
}

/// Initializes the startuptime code.
///
/// Must be called once before calling other startuptime code (such as
/// time_{push,pop,msg,...}).
///
/// @param message the message that will be displayed
void time_start(const char *message)
{
  if (time_fd == NULL) {
    return;
  }

  // initialize the global variables
  g_prev_time = g_start_time = profile_start();

  fprintf(time_fd, "\ntimes in msec\n");
  fprintf(time_fd, " clock   self+sourced   self:  sourced script\n");
  fprintf(time_fd, " clock   elapsed:              other lines\n\n");

  time_msg(message, NULL);
}

/// Prints out timing info.
///
/// @warning don't forget to call `time_start()` once before calling this.
///
/// @param mesg the message to display next to the timing information
/// @param start only for do_source: start time
void time_msg(const char *mesg, const proftime_T *start)
{
  if (time_fd == NULL) {
    return;
  }

  // print out the difference between `start` (init earlier) and `now`
  proftime_T now = profile_start();
  time_diff(g_start_time, now);

  // if `start` was supplied, print the diff between `start` and `now`
  if (start != NULL) {
    fprintf(time_fd, "  ");
    time_diff(*start, now);
  }

  // print the difference between the global `g_prev_time` and `now`
  fprintf(time_fd, "  ");
  time_diff(g_prev_time, now);

  // reset `g_prev_time` and print the message
  g_prev_time = now;
  fprintf(time_fd, ": %s\n", mesg);
}

/// Initializes the `time_fd` stream for the --startuptime report.
///
/// @param fname startuptime report file path
/// @param proc_name name of the current Nvim process to write in the report.
void time_init(const char *fname, const char *proc_name)
{
  const size_t bufsize = 8192;  // Big enough for the entire --startuptime report.
  time_fd = fopen(fname, "a");
  if (time_fd == NULL) {
    semsg(_(e_notopen), fname);
    return;
  }
  startuptime_buf = xmalloc(sizeof(char) * (bufsize + 1));
  // The startuptime file is (potentially) written by multiple Nvim processes concurrently. So each
  // report is buffered, and flushed to disk (`time_finish`) once after startup. `_IOFBF` mode
  // ensures the buffer is not auto-flushed ("controlled buffering").
  int r = setvbuf(time_fd, startuptime_buf, _IOFBF, bufsize + 1);
  if (r != 0) {
    XFREE_CLEAR(startuptime_buf);
    fclose(time_fd);
    time_fd = NULL;
    ELOG("time_init: setvbuf failed: %d %s", r, uv_err_name(r));
    semsg("time_init: setvbuf failed: %d %s", r, uv_err_name(r));
    return;
  }
  fprintf(time_fd, "--- Startup times for process: %s ---\n", proc_name);
}

/// Flushes the startuptimes to disk for the current process
void time_finish(void)
{
  if (time_fd == NULL) {
    return;
  }
  assert(startuptime_buf != NULL);
  TIME_MSG("--- NVIM STARTED ---\n");

  // flush buffer to disk
  fclose(time_fd);
  time_fd = NULL;

  XFREE_CLEAR(startuptime_buf);
}
