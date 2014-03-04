/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * ex_cmds2.c: some more functions for command line commands
 */

#include "vim.h"
#include "version_defs.h"
#include "ex_cmds2.h"
#include "buffer.h"
#include "charset.h"
#include "eval.h"
#include "ex_cmds.h"
#include "ex_docmd.h"
#include "ex_eval.h"
#include "ex_getln.h"
#include "fileio.h"
#include "getchar.h"
#include "mark.h"
#include "mbyte.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"
#include "garray.h"
#include "move.h"
#include "normal.h"
#include "option.h"
#include "os_unix.h"
#include "quickfix.h"
#include "regexp.h"
#include "screen.h"
#include "term.h"
#include "undo.h"
#include "window.h"
#include "os/os.h"

static void cmd_source(char_u *fname, exarg_T *eap);

/* Growarray to store info about already sourced scripts.
 * For Unix also store the dev/ino, so that we don't have to stat() each
 * script when going through the list. */
typedef struct scriptitem_S {
  char_u      *sn_name;
# ifdef UNIX
  int sn_dev_valid;
  dev_t sn_dev;
  ino_t sn_ino;
# endif
  int sn_prof_on;               /* TRUE when script is/was profiled */
  int sn_pr_force;              /* forceit: profile functions in this script */
  proftime_T sn_pr_child;       /* time set when going into first child */
  int sn_pr_nest;               /* nesting for sn_pr_child */
  /* profiling the script as a whole */
  int sn_pr_count;              /* nr of times sourced */
  proftime_T sn_pr_total;       /* time spent in script + children */
  proftime_T sn_pr_self;        /* time spent in script itself */
  proftime_T sn_pr_start;       /* time at script start */
  proftime_T sn_pr_children;    /* time in children after script start */
  /* profiling the script per line */
  garray_T sn_prl_ga;           /* things stored for every line */
  proftime_T sn_prl_start;      /* start time for current line */
  proftime_T sn_prl_children;    /* time spent in children for this line */
  proftime_T sn_prl_wait;       /* wait start time for current line */
  int sn_prl_idx;               /* index of line being timed; -1 if none */
  int sn_prl_execed;            /* line being timed was executed */
} scriptitem_T;

static garray_T script_items = {0, 0, sizeof(scriptitem_T), 4, NULL};
#define SCRIPT_ITEM(id) (((scriptitem_T *)script_items.ga_data)[(id) - 1])

/* Struct used in sn_prl_ga for every line of a script. */
typedef struct sn_prl_S {
  int snp_count;                /* nr of times line was executed */
  proftime_T sn_prl_total;      /* time spent in a line + children */
  proftime_T sn_prl_self;       /* time spent in a line itself */
} sn_prl_T;

#  define PRL_ITEM(si, idx)     (((sn_prl_T *)(si)->sn_prl_ga.ga_data)[(idx)])

static int debug_greedy = FALSE;        /* batch mode debugging: don't save
                                           and restore typeahead. */

/*
 * do_debug(): Debug mode.
 * Repeatedly get Ex commands, until told to continue normal execution.
 */
void do_debug(char_u *cmd)
{
  int save_msg_scroll = msg_scroll;
  int save_State = State;
  int save_did_emsg = did_emsg;
  int save_cmd_silent = cmd_silent;
  int save_msg_silent = msg_silent;
  int save_emsg_silent = emsg_silent;
  int save_redir_off = redir_off;
  tasave_T typeaheadbuf;
  int typeahead_saved = FALSE;
  int save_ignore_script = 0;
  int save_ex_normal_busy;
  int n;
  char_u      *cmdline = NULL;
  char_u      *p;
  char        *tail = NULL;
  static int last_cmd = 0;
#define CMD_CONT        1
#define CMD_NEXT        2
#define CMD_STEP        3
#define CMD_FINISH      4
#define CMD_QUIT        5
#define CMD_INTERRUPT   6


  /* Make sure we are in raw mode and start termcap mode.  Might have side
   * effects... */
  settmode(TMODE_RAW);
  starttermcap();

  ++RedrawingDisabled;          /* don't redisplay the window */
  ++no_wait_return;             /* don't wait for return */
  did_emsg = FALSE;             /* don't use error from debugged stuff */
  cmd_silent = FALSE;           /* display commands */
  msg_silent = FALSE;           /* display messages */
  emsg_silent = FALSE;          /* display error messages */
  redir_off = TRUE;             /* don't redirect debug commands */

  State = NORMAL;

  if (!debug_did_msg)
    MSG(_("Entering Debug mode.  Type \"cont\" to continue."));
  if (sourcing_name != NULL)
    msg(sourcing_name);
  if (sourcing_lnum != 0)
    smsg((char_u *)_("line %ld: %s"), (long)sourcing_lnum, cmd);
  else
    smsg((char_u *)_("cmd: %s"), cmd);

  /*
   * Repeat getting a command and executing it.
   */
  for (;; ) {
    msg_scroll = TRUE;
    need_wait_return = FALSE;
    /* Save the current typeahead buffer and replace it with an empty one.
     * This makes sure we get input from the user here and don't interfere
     * with the commands being executed.  Reset "ex_normal_busy" to avoid
     * the side effects of using ":normal". Save the stuff buffer and make
     * it empty. Set ignore_script to avoid reading from script input. */
    save_ex_normal_busy = ex_normal_busy;
    ex_normal_busy = 0;
    if (!debug_greedy) {
      save_typeahead(&typeaheadbuf);
      typeahead_saved = TRUE;
      save_ignore_script = ignore_script;
      ignore_script = TRUE;
    }

    cmdline = getcmdline_prompt('>', NULL, 0, EXPAND_NOTHING, NULL);

    if (typeahead_saved) {
      restore_typeahead(&typeaheadbuf);
      ignore_script = save_ignore_script;
    }
    ex_normal_busy = save_ex_normal_busy;

    cmdline_row = msg_row;
    if (cmdline != NULL) {
      /* If this is a debug command, set "last_cmd".
       * If not, reset "last_cmd".
       * For a blank line use previous command. */
      p = skipwhite(cmdline);
      if (*p != NUL) {
        switch (*p) {
        case 'c': last_cmd = CMD_CONT;
          tail = "ont";
          break;
        case 'n': last_cmd = CMD_NEXT;
          tail = "ext";
          break;
        case 's': last_cmd = CMD_STEP;
          tail = "tep";
          break;
        case 'f': last_cmd = CMD_FINISH;
          tail = "inish";
          break;
        case 'q': last_cmd = CMD_QUIT;
          tail = "uit";
          break;
        case 'i': last_cmd = CMD_INTERRUPT;
          tail = "nterrupt";
          break;
        default: last_cmd = 0;
        }
        if (last_cmd != 0) {
          /* Check that the tail matches. */
          ++p;
          while (*p != NUL && *p == *tail) {
            ++p;
            ++tail;
          }
          if (ASCII_ISALPHA(*p))
            last_cmd = 0;
        }
      }

      if (last_cmd != 0) {
        /* Execute debug command: decided where to break next and
         * return. */
        switch (last_cmd) {
        case CMD_CONT:
          debug_break_level = -1;
          break;
        case CMD_NEXT:
          debug_break_level = ex_nesting_level;
          break;
        case CMD_STEP:
          debug_break_level = 9999;
          break;
        case CMD_FINISH:
          debug_break_level = ex_nesting_level - 1;
          break;
        case CMD_QUIT:
          got_int = TRUE;
          debug_break_level = -1;
          break;
        case CMD_INTERRUPT:
          got_int = TRUE;
          debug_break_level = 9999;
          /* Do not repeat ">interrupt" cmd, continue stepping. */
          last_cmd = CMD_STEP;
          break;
        }
        break;
      }

      /* don't debug this command */
      n = debug_break_level;
      debug_break_level = -1;
      (void)do_cmdline(cmdline, getexline, NULL,
          DOCMD_VERBOSE|DOCMD_EXCRESET);
      debug_break_level = n;

      vim_free(cmdline);
    }
    lines_left = Rows - 1;
  }
  vim_free(cmdline);

  --RedrawingDisabled;
  --no_wait_return;
  redraw_all_later(NOT_VALID);
  need_wait_return = FALSE;
  msg_scroll = save_msg_scroll;
  lines_left = Rows - 1;
  State = save_State;
  did_emsg = save_did_emsg;
  cmd_silent = save_cmd_silent;
  msg_silent = save_msg_silent;
  emsg_silent = save_emsg_silent;
  redir_off = save_redir_off;

  /* Only print the message again when typing a command before coming back
   * here. */
  debug_did_msg = TRUE;
}

/*
 * ":debug".
 */
void ex_debug(exarg_T *eap)
{
  int debug_break_level_save = debug_break_level;

  debug_break_level = 9999;
  do_cmdline_cmd(eap->arg);
  debug_break_level = debug_break_level_save;
}

static char_u   *debug_breakpoint_name = NULL;
static linenr_T debug_breakpoint_lnum;

/*
 * When debugging or a breakpoint is set on a skipped command, no debug prompt
 * is shown by do_one_cmd().  This situation is indicated by debug_skipped, and
 * debug_skipped_name is then set to the source name in the breakpoint case.  If
 * a skipped command decides itself that a debug prompt should be displayed, it
 * can do so by calling dbg_check_skipped().
 */
static int debug_skipped;
static char_u   *debug_skipped_name;

/*
 * Go to debug mode when a breakpoint was encountered or "ex_nesting_level" is
 * at or below the break level.  But only when the line is actually
 * executed.  Return TRUE and set breakpoint_name for skipped commands that
 * decide to execute something themselves.
 * Called from do_one_cmd() before executing a command.
 */
void dbg_check_breakpoint(exarg_T *eap)
{
  char_u      *p;

  debug_skipped = FALSE;
  if (debug_breakpoint_name != NULL) {
    if (!eap->skip) {
      /* replace K_SNR with "<SNR>" */
      if (debug_breakpoint_name[0] == K_SPECIAL
          && debug_breakpoint_name[1] == KS_EXTRA
          && debug_breakpoint_name[2] == (int)KE_SNR)
        p = (char_u *)"<SNR>";
      else
        p = (char_u *)"";
      smsg((char_u *)_("Breakpoint in \"%s%s\" line %ld"),
          p,
          debug_breakpoint_name + (*p == NUL ? 0 : 3),
          (long)debug_breakpoint_lnum);
      debug_breakpoint_name = NULL;
      do_debug(eap->cmd);
    } else   {
      debug_skipped = TRUE;
      debug_skipped_name = debug_breakpoint_name;
      debug_breakpoint_name = NULL;
    }
  } else if (ex_nesting_level <= debug_break_level)   {
    if (!eap->skip)
      do_debug(eap->cmd);
    else {
      debug_skipped = TRUE;
      debug_skipped_name = NULL;
    }
  }
}

/*
 * Go to debug mode if skipped by dbg_check_breakpoint() because eap->skip was
 * set.  Return TRUE when the debug mode is entered this time.
 */
int dbg_check_skipped(exarg_T *eap)
{
  int prev_got_int;

  if (debug_skipped) {
    /*
     * Save the value of got_int and reset it.  We don't want a previous
     * interruption cause flushing the input buffer.
     */
    prev_got_int = got_int;
    got_int = FALSE;
    debug_breakpoint_name = debug_skipped_name;
    /* eap->skip is TRUE */
    eap->skip = FALSE;
    (void)dbg_check_breakpoint(eap);
    eap->skip = TRUE;
    got_int |= prev_got_int;
    return TRUE;
  }
  return FALSE;
}

/*
 * The list of breakpoints: dbg_breakp.
 * This is a grow-array of structs.
 */
struct debuggy {
  int dbg_nr;                   /* breakpoint number */
  int dbg_type;                 /* DBG_FUNC or DBG_FILE */
  char_u      *dbg_name;        /* function or file name */
  regprog_T   *dbg_prog;        /* regexp program */
  linenr_T dbg_lnum;            /* line number in function or file */
  int dbg_forceit;              /* ! used */
};

static garray_T dbg_breakp = {0, 0, sizeof(struct debuggy), 4, NULL};
#define BREAKP(idx)             (((struct debuggy *)dbg_breakp.ga_data)[idx])
#define DEBUGGY(gap, idx)       (((struct debuggy *)gap->ga_data)[idx])
static int last_breakp = 0;     /* nr of last defined breakpoint */

/* Profiling uses file and func names similar to breakpoints. */
static garray_T prof_ga = {0, 0, sizeof(struct debuggy), 4, NULL};
#define DBG_FUNC        1
#define DBG_FILE        2

static int dbg_parsearg(char_u *arg, garray_T *gap);
static linenr_T debuggy_find(int file,char_u *fname, linenr_T after,
                             garray_T *gap,
                             int *fp);

/*
 * Parse the arguments of ":profile", ":breakadd" or ":breakdel" and put them
 * in the entry just after the last one in dbg_breakp.  Note that "dbg_name"
 * is allocated.
 * Returns FAIL for failure.
 */
static int 
dbg_parsearg (
    char_u *arg,
    garray_T *gap           /* either &dbg_breakp or &prof_ga */
)
{
  char_u      *p = arg;
  char_u      *q;
  struct debuggy *bp;
  int here = FALSE;

  if (ga_grow(gap, 1) == FAIL)
    return FAIL;
  bp = &DEBUGGY(gap, gap->ga_len);

  /* Find "func" or "file". */
  if (STRNCMP(p, "func", 4) == 0)
    bp->dbg_type = DBG_FUNC;
  else if (STRNCMP(p, "file", 4) == 0)
    bp->dbg_type = DBG_FILE;
  else if (
    gap != &prof_ga &&
    STRNCMP(p, "here", 4) == 0) {
    if (curbuf->b_ffname == NULL) {
      EMSG(_(e_noname));
      return FAIL;
    }
    bp->dbg_type = DBG_FILE;
    here = TRUE;
  } else   {
    EMSG2(_(e_invarg2), p);
    return FAIL;
  }
  p = skipwhite(p + 4);

  /* Find optional line number. */
  if (here)
    bp->dbg_lnum = curwin->w_cursor.lnum;
  else if (
    gap != &prof_ga &&
    VIM_ISDIGIT(*p)) {
    bp->dbg_lnum = getdigits(&p);
    p = skipwhite(p);
  } else
    bp->dbg_lnum = 0;

  /* Find the function or file name.  Don't accept a function name with (). */
  if ((!here && *p == NUL)
      || (here && *p != NUL)
      || (bp->dbg_type == DBG_FUNC && strstr((char *)p, "()") != NULL)) {
    EMSG2(_(e_invarg2), arg);
    return FAIL;
  }

  if (bp->dbg_type == DBG_FUNC)
    bp->dbg_name = vim_strsave(p);
  else if (here)
    bp->dbg_name = vim_strsave(curbuf->b_ffname);
  else {
    /* Expand the file name in the same way as do_source().  This means
     * doing it twice, so that $DIR/file gets expanded when $DIR is
     * "~/dir". */
    q = expand_env_save(p);
    if (q == NULL)
      return FAIL;
    p = expand_env_save(q);
    vim_free(q);
    if (p == NULL)
      return FAIL;
    if (*p != '*') {
      bp->dbg_name = fix_fname(p);
      vim_free(p);
    } else
      bp->dbg_name = p;
  }

  if (bp->dbg_name == NULL)
    return FAIL;
  return OK;
}

/*
 * ":breakadd".
 */
void ex_breakadd(exarg_T *eap)
{
  struct debuggy *bp;
  char_u      *pat;
  garray_T    *gap;

  gap = &dbg_breakp;
  if (eap->cmdidx == CMD_profile)
    gap = &prof_ga;

  if (dbg_parsearg(eap->arg, gap) == OK) {
    bp = &DEBUGGY(gap, gap->ga_len);
    bp->dbg_forceit = eap->forceit;

    pat = file_pat_to_reg_pat(bp->dbg_name, NULL, NULL, FALSE);
    if (pat != NULL) {
      bp->dbg_prog = vim_regcomp(pat, RE_MAGIC + RE_STRING);
      vim_free(pat);
    }
    if (pat == NULL || bp->dbg_prog == NULL)
      vim_free(bp->dbg_name);
    else {
      if (bp->dbg_lnum == 0)            /* default line number is 1 */
        bp->dbg_lnum = 1;
      if (eap->cmdidx != CMD_profile) {
        DEBUGGY(gap, gap->ga_len).dbg_nr = ++last_breakp;
        ++debug_tick;
      }
      ++gap->ga_len;
    }
  }
}

/*
 * ":debuggreedy".
 */
void ex_debuggreedy(exarg_T *eap)
{
  if (eap->addr_count == 0 || eap->line2 != 0)
    debug_greedy = TRUE;
  else
    debug_greedy = FALSE;
}

/*
 * ":breakdel" and ":profdel".
 */
void ex_breakdel(exarg_T *eap)
{
  struct debuggy *bp, *bpi;
  int nr;
  int todel = -1;
  int del_all = FALSE;
  int i;
  linenr_T best_lnum = 0;
  garray_T    *gap;

  gap = &dbg_breakp;
  if (eap->cmdidx == CMD_profdel) {
    gap = &prof_ga;
  }

  if (vim_isdigit(*eap->arg)) {
    /* ":breakdel {nr}" */
    nr = atol((char *)eap->arg);
    for (i = 0; i < gap->ga_len; ++i)
      if (DEBUGGY(gap, i).dbg_nr == nr) {
        todel = i;
        break;
      }
  } else if (*eap->arg == '*')   {
    todel = 0;
    del_all = TRUE;
  } else   {
    /* ":breakdel {func|file} [lnum] {name}" */
    if (dbg_parsearg(eap->arg, gap) == FAIL)
      return;
    bp = &DEBUGGY(gap, gap->ga_len);
    for (i = 0; i < gap->ga_len; ++i) {
      bpi = &DEBUGGY(gap, i);
      if (bp->dbg_type == bpi->dbg_type
          && STRCMP(bp->dbg_name, bpi->dbg_name) == 0
          && (bp->dbg_lnum == bpi->dbg_lnum
              || (bp->dbg_lnum == 0
                  && (best_lnum == 0
                      || bpi->dbg_lnum < best_lnum)))) {
        todel = i;
        best_lnum = bpi->dbg_lnum;
      }
    }
    vim_free(bp->dbg_name);
  }

  if (todel < 0)
    EMSG2(_("E161: Breakpoint not found: %s"), eap->arg);
  else {
    while (gap->ga_len > 0) {
      vim_free(DEBUGGY(gap, todel).dbg_name);
      vim_regfree(DEBUGGY(gap, todel).dbg_prog);
      --gap->ga_len;
      if (todel < gap->ga_len)
        mch_memmove(&DEBUGGY(gap, todel), &DEBUGGY(gap, todel + 1),
            (gap->ga_len - todel) * sizeof(struct debuggy));
      if (eap->cmdidx == CMD_breakdel)
        ++debug_tick;
      if (!del_all)
        break;
    }

    /* If all breakpoints were removed clear the array. */
    if (gap->ga_len == 0)
      ga_clear(gap);
  }
}

/*
 * ":breaklist".
 */
void ex_breaklist(exarg_T *eap)
{
  struct debuggy *bp;
  int i;

  if (dbg_breakp.ga_len == 0)
    MSG(_("No breakpoints defined"));
  else
    for (i = 0; i < dbg_breakp.ga_len; ++i) {
      bp = &BREAKP(i);
      if (bp->dbg_type == DBG_FILE)
        home_replace(NULL, bp->dbg_name, NameBuff, MAXPATHL, TRUE);
      smsg((char_u *)_("%3d  %s %s  line %ld"),
          bp->dbg_nr,
          bp->dbg_type == DBG_FUNC ? "func" : "file",
          bp->dbg_type == DBG_FUNC ? bp->dbg_name : NameBuff,
          (long)bp->dbg_lnum);
    }
}

/*
 * Find a breakpoint for a function or sourced file.
 * Returns line number at which to break; zero when no matching breakpoint.
 */
linenr_T 
dbg_find_breakpoint (
    int file,                   /* TRUE for a file, FALSE for a function */
    char_u *fname,         /* file or function name */
    linenr_T after             /* after this line number */
)
{
  return debuggy_find(file, fname, after, &dbg_breakp, NULL);
}

/*
 * Return TRUE if profiling is on for a function or sourced file.
 */
int 
has_profiling (
    int file,                   /* TRUE for a file, FALSE for a function */
    char_u *fname,         /* file or function name */
    int *fp            /* return: forceit */
)
{
  return debuggy_find(file, fname, (linenr_T)0, &prof_ga, fp)
         != (linenr_T)0;
}

/*
 * Common code for dbg_find_breakpoint() and has_profiling().
 */
static linenr_T 
debuggy_find (
    int file,                   /* TRUE for a file, FALSE for a function */
    char_u *fname,         /* file or function name */
    linenr_T after,             /* after this line number */
    garray_T *gap,           /* either &dbg_breakp or &prof_ga */
    int *fp            /* if not NULL: return forceit */
)
{
  struct debuggy *bp;
  int i;
  linenr_T lnum = 0;
  regmatch_T regmatch;
  char_u      *name = fname;
  int prev_got_int;

  /* Return quickly when there are no breakpoints. */
  if (gap->ga_len == 0)
    return (linenr_T)0;

  /* Replace K_SNR in function name with "<SNR>". */
  if (!file && fname[0] == K_SPECIAL) {
    name = alloc((unsigned)STRLEN(fname) + 3);
    if (name == NULL)
      name = fname;
    else {
      STRCPY(name, "<SNR>");
      STRCPY(name + 5, fname + 3);
    }
  }

  for (i = 0; i < gap->ga_len; ++i) {
    /* Skip entries that are not useful or are for a line that is beyond
     * an already found breakpoint. */
    bp = &DEBUGGY(gap, i);
    if (((bp->dbg_type == DBG_FILE) == file && (
           gap == &prof_ga ||
           (bp->dbg_lnum > after && (lnum == 0 || bp->dbg_lnum < lnum))))) {
      regmatch.regprog = bp->dbg_prog;
      regmatch.rm_ic = FALSE;
      /*
       * Save the value of got_int and reset it.  We don't want a
       * previous interruption cancel matching, only hitting CTRL-C
       * while matching should abort it.
       */
      prev_got_int = got_int;
      got_int = FALSE;
      if (vim_regexec(&regmatch, name, (colnr_T)0)) {
        lnum = bp->dbg_lnum;
        if (fp != NULL)
          *fp = bp->dbg_forceit;
      }
      got_int |= prev_got_int;
    }
  }
  if (name != fname)
    vim_free(name);

  return lnum;
}

/*
 * Called when a breakpoint was encountered.
 */
void dbg_breakpoint(char_u *name, linenr_T lnum)
{
  /* We need to check if this line is actually executed in do_one_cmd() */
  debug_breakpoint_name = name;
  debug_breakpoint_lnum = lnum;
}


/*
 * Store the current time in "tm".
 */
void profile_start(tm)
proftime_T *tm;
{
  gettimeofday(tm, NULL);
}

/*
 * Compute the elapsed time from "tm" till now and store in "tm".
 */
void profile_end(tm)
proftime_T *tm;
{
  proftime_T now;

  gettimeofday(&now, NULL);
  tm->tv_usec = now.tv_usec - tm->tv_usec;
  tm->tv_sec = now.tv_sec - tm->tv_sec;
  if (tm->tv_usec < 0) {
    tm->tv_usec += 1000000;
    --tm->tv_sec;
  }
}

/*
 * Subtract the time "tm2" from "tm".
 */
void profile_sub(tm, tm2)
proftime_T *tm, *tm2;
{
  tm->tv_usec -= tm2->tv_usec;
  tm->tv_sec -= tm2->tv_sec;
  if (tm->tv_usec < 0) {
    tm->tv_usec += 1000000;
    --tm->tv_sec;
  }
}

/*
 * Return a string that represents the time in "tm".
 * Uses a static buffer!
 */
char * profile_msg(tm)
proftime_T *tm;
{
  static char buf[50];

  sprintf(buf, "%3ld.%06ld", (long)tm->tv_sec, (long)tm->tv_usec);
  return buf;
}

/*
 * Put the time "msec" past now in "tm".
 */
void profile_setlimit(msec, tm)
long msec;
proftime_T  *tm;
{
  if (msec <= 0)     /* no limit */
    profile_zero(tm);
  else {
    long usec;

    gettimeofday(tm, NULL);
    usec = (long)tm->tv_usec + (long)msec * 1000;
    tm->tv_usec = usec % 1000000L;
    tm->tv_sec += usec / 1000000L;
  }
}

/*
 * Return TRUE if the current time is past "tm".
 */
int profile_passed_limit(tm)
proftime_T  *tm;
{
  proftime_T now;

  if (tm->tv_sec == 0)      /* timer was not set */
    return FALSE;
  gettimeofday(&now, NULL);
  return now.tv_sec > tm->tv_sec
         || (now.tv_sec == tm->tv_sec && now.tv_usec > tm->tv_usec);
}

/*
 * Set the time in "tm" to zero.
 */
void profile_zero(tm)
proftime_T *tm;
{
  tm->tv_usec = 0;
  tm->tv_sec = 0;
}


# if defined(HAVE_MATH_H)
#  include <math.h>
# endif

/*
 * Divide the time "tm" by "count" and store in "tm2".
 */
void profile_divide(tm, count, tm2)
proftime_T  *tm;
proftime_T  *tm2;
int count;
{
  if (count == 0)
    profile_zero(tm2);
  else {
    double usec = (tm->tv_sec * 1000000.0 + tm->tv_usec) / count;

    tm2->tv_sec = floor(usec / 1000000.0);
    tm2->tv_usec = vim_round(usec - (tm2->tv_sec * 1000000.0));
  }
}

/*
 * Functions for profiling.
 */
static void script_do_profile(scriptitem_T *si);
static void script_dump_profile(FILE *fd);
static proftime_T prof_wait_time;

/*
 * Add the time "tm2" to "tm".
 */
void profile_add(tm, tm2)
proftime_T *tm, *tm2;
{
  tm->tv_usec += tm2->tv_usec;
  tm->tv_sec += tm2->tv_sec;
  if (tm->tv_usec >= 1000000) {
    tm->tv_usec -= 1000000;
    ++tm->tv_sec;
  }
}

/*
 * Add the "self" time from the total time and the children's time.
 */
void profile_self(self, total, children)
proftime_T *self, *total, *children;
{
  /* Check that the result won't be negative.  Can happen with recursive
   * calls. */
  if (total->tv_sec < children->tv_sec
      || (total->tv_sec == children->tv_sec
          && total->tv_usec <= children->tv_usec))
    return;
  profile_add(self, total);
  profile_sub(self, children);
}

/*
 * Get the current waittime.
 */
void profile_get_wait(tm)
proftime_T *tm;
{
  *tm = prof_wait_time;
}

/*
 * Subtract the passed waittime since "tm" from "tma".
 */
void profile_sub_wait(tm, tma)
proftime_T *tm, *tma;
{
  proftime_T tm3 = prof_wait_time;

  profile_sub(&tm3, tm);
  profile_sub(tma, &tm3);
}

/*
 * Return TRUE if "tm1" and "tm2" are equal.
 */
int profile_equal(tm1, tm2)
proftime_T *tm1, *tm2;
{
  return tm1->tv_usec == tm2->tv_usec && tm1->tv_sec == tm2->tv_sec;
}

/*
 * Return <0, 0 or >0 if "tm1" < "tm2", "tm1" == "tm2" or "tm1" > "tm2"
 */
int profile_cmp(tm1, tm2)
const proftime_T *tm1, *tm2;
{
  if (tm1->tv_sec == tm2->tv_sec)
    return tm2->tv_usec - tm1->tv_usec;
  return tm2->tv_sec - tm1->tv_sec;
}

static char_u   *profile_fname = NULL;
static proftime_T pause_time;

/*
 * ":profile cmd args"
 */
void ex_profile(exarg_T *eap)
{
  char_u      *e;
  int len;

  e = skiptowhite(eap->arg);
  len = (int)(e - eap->arg);
  e = skipwhite(e);

  if (len == 5 && STRNCMP(eap->arg, "start", 5) == 0 && *e != NUL) {
    vim_free(profile_fname);
    profile_fname = vim_strsave(e);
    do_profiling = PROF_YES;
    profile_zero(&prof_wait_time);
    set_vim_var_nr(VV_PROFILING, 1L);
  } else if (do_profiling == PROF_NONE)
    EMSG(_("E750: First use \":profile start {fname}\""));
  else if (STRCMP(eap->arg, "pause") == 0) {
    if (do_profiling == PROF_YES)
      profile_start(&pause_time);
    do_profiling = PROF_PAUSED;
  } else if (STRCMP(eap->arg, "continue") == 0)   {
    if (do_profiling == PROF_PAUSED) {
      profile_end(&pause_time);
      profile_add(&prof_wait_time, &pause_time);
    }
    do_profiling = PROF_YES;
  } else   {
    /* The rest is similar to ":breakadd". */
    ex_breakadd(eap);
  }
}

/* Command line expansion for :profile. */
static enum {
  PEXP_SUBCMD,          /* expand :profile sub-commands */
  PEXP_FUNC             /* expand :profile func {funcname} */
} pexpand_what;

static char *pexpand_cmds[] = {
  "start",
#define PROFCMD_START   0
  "pause",
#define PROFCMD_PAUSE   1
  "continue",
#define PROFCMD_CONTINUE 2
  "func",
#define PROFCMD_FUNC    3
  "file",
#define PROFCMD_FILE    4
  NULL
#define PROFCMD_LAST    5
};

/*
 * Function given to ExpandGeneric() to obtain the profile command
 * specific expansion.
 */
char_u *get_profile_name(expand_T *xp, int idx)
{
  switch (pexpand_what) {
  case PEXP_SUBCMD:
    return (char_u *)pexpand_cmds[idx];
  /* case PEXP_FUNC: TODO */
  default:
    return NULL;
  }
}

/*
 * Handle command line completion for :profile command.
 */
void set_context_in_profile_cmd(expand_T *xp, char_u *arg)
{
  char_u      *end_subcmd;

  /* Default: expand subcommands. */
  xp->xp_context = EXPAND_PROFILE;
  pexpand_what = PEXP_SUBCMD;
  xp->xp_pattern = arg;

  end_subcmd = skiptowhite(arg);
  if (*end_subcmd == NUL)
    return;

  if (end_subcmd - arg == 5 && STRNCMP(arg, "start", 5) == 0) {
    xp->xp_context = EXPAND_FILES;
    xp->xp_pattern = skipwhite(end_subcmd);
    return;
  }

  /* TODO: expand function names after "func" */
  xp->xp_context = EXPAND_NOTHING;
}

/*
 * Dump the profiling info.
 */
void profile_dump(void)          {
  FILE        *fd;

  if (profile_fname != NULL) {
    fd = mch_fopen((char *)profile_fname, "w");
    if (fd == NULL)
      EMSG2(_(e_notopen), profile_fname);
    else {
      script_dump_profile(fd);
      func_dump_profile(fd);
      fclose(fd);
    }
  }
}

/*
 * Start profiling script "fp".
 */
static void script_do_profile(scriptitem_T *si)
{
  si->sn_pr_count = 0;
  profile_zero(&si->sn_pr_total);
  profile_zero(&si->sn_pr_self);

  ga_init2(&si->sn_prl_ga, sizeof(sn_prl_T), 100);
  si->sn_prl_idx = -1;
  si->sn_prof_on = TRUE;
  si->sn_pr_nest = 0;
}

/*
 * save time when starting to invoke another script or function.
 */
void script_prof_save(tm)
proftime_T  *tm;            /* place to store wait time */
{
  scriptitem_T    *si;

  if (current_SID > 0 && current_SID <= script_items.ga_len) {
    si = &SCRIPT_ITEM(current_SID);
    if (si->sn_prof_on && si->sn_pr_nest++ == 0)
      profile_start(&si->sn_pr_child);
  }
  profile_get_wait(tm);
}

/*
 * Count time spent in children after invoking another script or function.
 */
void script_prof_restore(tm)
proftime_T  *tm;
{
  scriptitem_T    *si;

  if (current_SID > 0 && current_SID <= script_items.ga_len) {
    si = &SCRIPT_ITEM(current_SID);
    if (si->sn_prof_on && --si->sn_pr_nest == 0) {
      profile_end(&si->sn_pr_child);
      profile_sub_wait(tm, &si->sn_pr_child);       /* don't count wait time */
      profile_add(&si->sn_pr_children, &si->sn_pr_child);
      profile_add(&si->sn_prl_children, &si->sn_pr_child);
    }
  }
}

static proftime_T inchar_time;

/*
 * Called when starting to wait for the user to type a character.
 */
void prof_inchar_enter(void)          {
  profile_start(&inchar_time);
}

/*
 * Called when finished waiting for the user to type a character.
 */
void prof_inchar_exit(void)          {
  profile_end(&inchar_time);
  profile_add(&prof_wait_time, &inchar_time);
}

/*
 * Dump the profiling results for all scripts in file "fd".
 */
static void script_dump_profile(FILE *fd)
{
  int id;
  scriptitem_T    *si;
  int i;
  FILE            *sfd;
  sn_prl_T        *pp;

  for (id = 1; id <= script_items.ga_len; ++id) {
    si = &SCRIPT_ITEM(id);
    if (si->sn_prof_on) {
      fprintf(fd, "SCRIPT  %s\n", si->sn_name);
      if (si->sn_pr_count == 1)
        fprintf(fd, "Sourced 1 time\n");
      else
        fprintf(fd, "Sourced %d times\n", si->sn_pr_count);
      fprintf(fd, "Total time: %s\n", profile_msg(&si->sn_pr_total));
      fprintf(fd, " Self time: %s\n", profile_msg(&si->sn_pr_self));
      fprintf(fd, "\n");
      fprintf(fd, "count  total (s)   self (s)\n");

      sfd = mch_fopen((char *)si->sn_name, "r");
      if (sfd == NULL)
        fprintf(fd, "Cannot open file!\n");
      else {
        for (i = 0; i < si->sn_prl_ga.ga_len; ++i) {
          if (vim_fgets(IObuff, IOSIZE, sfd))
            break;
          pp = &PRL_ITEM(si, i);
          if (pp->snp_count > 0) {
            fprintf(fd, "%5d ", pp->snp_count);
            if (profile_equal(&pp->sn_prl_total, &pp->sn_prl_self))
              fprintf(fd, "           ");
            else
              fprintf(fd, "%s ", profile_msg(&pp->sn_prl_total));
            fprintf(fd, "%s ", profile_msg(&pp->sn_prl_self));
          } else
            fprintf(fd, "                            ");
          fprintf(fd, "%s", IObuff);
        }
        fclose(sfd);
      }
      fprintf(fd, "\n");
    }
  }
}

/*
 * Return TRUE when a function defined in the current script should be
 * profiled.
 */
int prof_def_func(void)         {
  if (current_SID > 0)
    return SCRIPT_ITEM(current_SID).sn_pr_force;
  return FALSE;
}

/*
 * If 'autowrite' option set, try to write the file.
 * Careful: autocommands may make "buf" invalid!
 *
 * return FAIL for failure, OK otherwise
 */
int autowrite(buf_T *buf, int forceit)
{
  int r;

  if (!(p_aw || p_awa) || !p_write
      /* never autowrite a "nofile" or "nowrite" buffer */
      || bt_dontwrite(buf)
      || (!forceit && buf->b_p_ro) || buf->b_ffname == NULL)
    return FAIL;
  r = buf_write_all(buf, forceit);

  /* Writing may succeed but the buffer still changed, e.g., when there is a
   * conversion error.  We do want to return FAIL then. */
  if (buf_valid(buf) && bufIsChanged(buf))
    r = FAIL;
  return r;
}

/*
 * flush all buffers, except the ones that are readonly
 */
void autowrite_all(void)          {
  buf_T       *buf;

  if (!(p_aw || p_awa) || !p_write)
    return;
  for (buf = firstbuf; buf; buf = buf->b_next)
    if (bufIsChanged(buf) && !buf->b_p_ro) {
      (void)buf_write_all(buf, FALSE);
      /* an autocommand may have deleted the buffer */
      if (!buf_valid(buf))
        buf = firstbuf;
    }
}

/*
 * Return TRUE if buffer was changed and cannot be abandoned.
 * For flags use the CCGD_ values.
 */
int check_changed(buf_T *buf, int flags)
{
  int forceit = (flags & CCGD_FORCEIT);

  if (       !forceit
             && bufIsChanged(buf)
             && ((flags & CCGD_MULTWIN) || buf->b_nwindows <= 1)
             && (!(flags & CCGD_AW) || autowrite(buf, forceit) == FAIL)) {
    if ((p_confirm || cmdmod.confirm) && p_write) {
      buf_T       *buf2;
      int count = 0;

      if (flags & CCGD_ALLBUF)
        for (buf2 = firstbuf; buf2 != NULL; buf2 = buf2->b_next)
          if (bufIsChanged(buf2)
              && (buf2->b_ffname != NULL
                  ))
            ++count;
      if (!buf_valid(buf))
        /* Autocommand deleted buffer, oops!  It's not changed now. */
        return FALSE;
      dialog_changed(buf, count > 1);
      if (!buf_valid(buf))
        /* Autocommand deleted buffer, oops!  It's not changed now. */
        return FALSE;
      return bufIsChanged(buf);
    }
    if (flags & CCGD_EXCMD)
      EMSG(_(e_nowrtmsg));
    else
      EMSG(_(e_nowrtmsg_nobang));
    return TRUE;
  }
  return FALSE;
}



/*
 * Ask the user what to do when abandoning a changed buffer.
 * Must check 'write' option first!
 */
void 
dialog_changed (
    buf_T *buf,
    int checkall                   /* may abandon all changed buffers */
)
{
  char_u buff[DIALOG_MSG_SIZE];
  int ret;
  buf_T       *buf2;
  exarg_T ea;

  dialog_msg(buff, _("Save changes to \"%s\"?"),
      (buf->b_fname != NULL) ?
      buf->b_fname : (char_u *)_("Untitled"));
  if (checkall)
    ret = vim_dialog_yesnoallcancel(VIM_QUESTION, NULL, buff, 1);
  else
    ret = vim_dialog_yesnocancel(VIM_QUESTION, NULL, buff, 1);

  /* Init ea pseudo-structure, this is needed for the check_overwrite()
   * function. */
  ea.append = ea.forceit = FALSE;

  if (ret == VIM_YES) {
    if (buf->b_fname != NULL && check_overwrite(&ea, buf,
            buf->b_fname, buf->b_ffname, FALSE) == OK)
      /* didn't hit Cancel */
      (void)buf_write_all(buf, FALSE);
  } else if (ret == VIM_NO)   {
    unchanged(buf, TRUE);
  } else if (ret == VIM_ALL)   {
    /*
     * Write all modified files that can be written.
     * Skip readonly buffers, these need to be confirmed
     * individually.
     */
    for (buf2 = firstbuf; buf2 != NULL; buf2 = buf2->b_next) {
      if (bufIsChanged(buf2)
          && (buf2->b_ffname != NULL
              )
          && !buf2->b_p_ro) {
        if (buf2->b_fname != NULL && check_overwrite(&ea, buf2,
                buf2->b_fname, buf2->b_ffname, FALSE) == OK)
          /* didn't hit Cancel */
          (void)buf_write_all(buf2, FALSE);
        /* an autocommand may have deleted the buffer */
        if (!buf_valid(buf2))
          buf2 = firstbuf;
      }
    }
  } else if (ret == VIM_DISCARDALL)   {
    /*
     * mark all buffers as unchanged
     */
    for (buf2 = firstbuf; buf2 != NULL; buf2 = buf2->b_next)
      unchanged(buf2, TRUE);
  }
}

/*
 * Return TRUE if the buffer "buf" can be abandoned, either by making it
 * hidden, autowriting it or unloading it.
 */
int can_abandon(buf_T *buf, int forceit)
{
  return P_HID(buf)
         || !bufIsChanged(buf)
         || buf->b_nwindows > 1
         || autowrite(buf, forceit) == OK
         || forceit;
}

static void add_bufnum(int *bufnrs, int *bufnump, int nr);

/*
 * Add a buffer number to "bufnrs", unless it's already there.
 */
static void add_bufnum(int *bufnrs, int *bufnump, int nr)
{
  int i;

  for (i = 0; i < *bufnump; ++i)
    if (bufnrs[i] == nr)
      return;
  bufnrs[*bufnump] = nr;
  *bufnump = *bufnump + 1;
}

/*
 * Return TRUE if any buffer was changed and cannot be abandoned.
 * That changed buffer becomes the current buffer.
 */
int 
check_changed_any (
    int hidden                     /* Only check hidden buffers */
)
{
  int ret = FALSE;
  buf_T       *buf;
  int save;
  int i;
  int bufnum = 0;
  int bufcount = 0;
  int         *bufnrs;
  tabpage_T   *tp;
  win_T       *wp;

  for (buf = firstbuf; buf != NULL; buf = buf->b_next)
    ++bufcount;

  if (bufcount == 0)
    return FALSE;

  bufnrs = (int *)alloc(sizeof(int) * bufcount);
  if (bufnrs == NULL)
    return FALSE;

  /* curbuf */
  bufnrs[bufnum++] = curbuf->b_fnum;
  /* buf in curtab */
  FOR_ALL_WINDOWS(wp)
  if (wp->w_buffer != curbuf)
    add_bufnum(bufnrs, &bufnum, wp->w_buffer->b_fnum);

  /* buf in other tab */
  for (tp = first_tabpage; tp != NULL; tp = tp->tp_next)
    if (tp != curtab)
      for (wp = tp->tp_firstwin; wp != NULL; wp = wp->w_next)
        add_bufnum(bufnrs, &bufnum, wp->w_buffer->b_fnum);
  /* any other buf */
  for (buf = firstbuf; buf != NULL; buf = buf->b_next)
    add_bufnum(bufnrs, &bufnum, buf->b_fnum);

  for (i = 0; i < bufnum; ++i) {
    buf = buflist_findnr(bufnrs[i]);
    if (buf == NULL)
      continue;
    if ((!hidden || buf->b_nwindows == 0) && bufIsChanged(buf)) {
      /* Try auto-writing the buffer.  If this fails but the buffer no
       * longer exists it's not changed, that's OK. */
      if (check_changed(buf, (p_awa ? CCGD_AW : 0)
              | CCGD_MULTWIN
              | CCGD_ALLBUF) && buf_valid(buf))
        break;              /* didn't save - still changes */
    }
  }

  if (i >= bufnum)
    goto theend;

  ret = TRUE;
  exiting = FALSE;
  /*
   * When ":confirm" used, don't give an error message.
   */
  if (!(p_confirm || cmdmod.confirm)) {
    /* There must be a wait_return for this message, do_buffer()
     * may cause a redraw.  But wait_return() is a no-op when vgetc()
     * is busy (Quit used from window menu), then make sure we don't
     * cause a scroll up. */
    if (vgetc_busy > 0) {
      msg_row = cmdline_row;
      msg_col = 0;
      msg_didout = FALSE;
    }
    if (EMSG2(_("E162: No write since last change for buffer \"%s\""),
            buf_spname(buf) != NULL ? buf_spname(buf) : buf->b_fname)) {
      save = no_wait_return;
      no_wait_return = FALSE;
      wait_return(FALSE);
      no_wait_return = save;
    }
  }

  /* Try to find a window that contains the buffer. */
  if (buf != curbuf)
    FOR_ALL_TAB_WINDOWS(tp, wp)
    if (wp->w_buffer == buf) {
      goto_tabpage_win(tp, wp);
      /* Paranoia: did autocms wipe out the buffer with changes? */
      if (!buf_valid(buf)) {
        goto theend;
      }
      goto buf_found;
    }
buf_found:

  /* Open the changed buffer in the current window. */
  if (buf != curbuf)
    set_curbuf(buf, DOBUF_GOTO);

theend:
  vim_free(bufnrs);
  return ret;
}

/*
 * return FAIL if there is no file name, OK if there is one
 * give error message for FAIL
 */
int check_fname(void)         {
  if (curbuf->b_ffname == NULL) {
    EMSG(_(e_noname));
    return FAIL;
  }
  return OK;
}

/*
 * flush the contents of a buffer, unless it has no file name
 *
 * return FAIL for failure, OK otherwise
 */
int buf_write_all(buf_T *buf, int forceit)
{
  int retval;
  buf_T       *old_curbuf = curbuf;

  retval = (buf_write(buf, buf->b_ffname, buf->b_fname,
                (linenr_T)1, buf->b_ml.ml_line_count, NULL,
                FALSE, forceit, TRUE, FALSE));
  if (curbuf != old_curbuf) {
    msg_source(hl_attr(HLF_W));
    MSG(_("Warning: Entered other buffer unexpectedly (check autocommands)"));
  }
  return retval;
}

/*
 * Code to handle the argument list.
 */

static char_u   *do_one_arg(char_u *str);
static int do_arglist(char_u *str, int what, int after);
static void alist_check_arg_idx(void);
static int editing_arg_idx(win_T *win);
static int alist_add_list(int count, char_u **files, int after);
#define AL_SET  1
#define AL_ADD  2
#define AL_DEL  3

/*
 * Isolate one argument, taking backticks.
 * Changes the argument in-place, puts a NUL after it.  Backticks remain.
 * Return a pointer to the start of the next argument.
 */
static char_u *do_one_arg(char_u *str)
{
  char_u      *p;
  int inbacktick;

  inbacktick = FALSE;
  for (p = str; *str; ++str) {
    /* When the backslash is used for escaping the special meaning of a
     * character we need to keep it until wildcard expansion. */
    if (rem_backslash(str)) {
      *p++ = *str++;
      *p++ = *str;
    } else   {
      /* An item ends at a space not in backticks */
      if (!inbacktick && vim_isspace(*str))
        break;
      if (*str == '`')
        inbacktick ^= TRUE;
      *p++ = *str;
    }
  }
  str = skipwhite(str);
  *p = NUL;

  return str;
}

/*
 * Separate the arguments in "str" and return a list of pointers in the
 * growarray "gap".
 */
int get_arglist(garray_T *gap, char_u *str)
{
  ga_init2(gap, (int)sizeof(char_u *), 20);
  while (*str != NUL) {
    if (ga_grow(gap, 1) == FAIL) {
      ga_clear(gap);
      return FAIL;
    }
    ((char_u **)gap->ga_data)[gap->ga_len++] = str;

    /* Isolate one argument, change it in-place, put a NUL after it. */
    str = do_one_arg(str);
  }
  return OK;
}

/*
 * Parse a list of arguments (file names), expand them and return in
 * "fnames[fcountp]".  When "wig" is TRUE, removes files matching 'wildignore'.
 * Return FAIL or OK.
 */
int get_arglist_exp(char_u *str, int *fcountp, char_u ***fnamesp, int wig)
{
  garray_T ga;
  int i;

  if (get_arglist(&ga, str) == FAIL)
    return FAIL;
  if (wig == TRUE)
    i = expand_wildcards(ga.ga_len, (char_u **)ga.ga_data,
        fcountp, fnamesp, EW_FILE|EW_NOTFOUND);
  else
    i = gen_expand_wildcards(ga.ga_len, (char_u **)ga.ga_data,
        fcountp, fnamesp, EW_FILE|EW_NOTFOUND);

  ga_clear(&ga);
  return i;
}


/*
 * "what" == AL_SET: Redefine the argument list to 'str'.
 * "what" == AL_ADD: add files in 'str' to the argument list after "after".
 * "what" == AL_DEL: remove files in 'str' from the argument list.
 *
 * Return FAIL for failure, OK otherwise.
 */
static int 
do_arglist (
    char_u *str,
    int what,
    int after                       /* 0 means before first one */
)
{
  garray_T new_ga;
  int exp_count;
  char_u      **exp_files;
  int i;
  char_u      *p;
  int match;

  /*
   * Collect all file name arguments in "new_ga".
   */
  if (get_arglist(&new_ga, str) == FAIL)
    return FAIL;

  if (what == AL_DEL) {
    regmatch_T regmatch;
    int didone;

    /*
     * Delete the items: use each item as a regexp and find a match in the
     * argument list.
     */
    regmatch.rm_ic = p_fic;     /* ignore case when 'fileignorecase' is set */
    for (i = 0; i < new_ga.ga_len && !got_int; ++i) {
      p = ((char_u **)new_ga.ga_data)[i];
      p = file_pat_to_reg_pat(p, NULL, NULL, FALSE);
      if (p == NULL)
        break;
      regmatch.regprog = vim_regcomp(p, p_magic ? RE_MAGIC : 0);
      if (regmatch.regprog == NULL) {
        vim_free(p);
        break;
      }

      didone = FALSE;
      for (match = 0; match < ARGCOUNT; ++match)
        if (vim_regexec(&regmatch, alist_name(&ARGLIST[match]),
                (colnr_T)0)) {
          didone = TRUE;
          vim_free(ARGLIST[match].ae_fname);
          mch_memmove(ARGLIST + match, ARGLIST + match + 1,
              (ARGCOUNT - match - 1) * sizeof(aentry_T));
          --ALIST(curwin)->al_ga.ga_len;
          if (curwin->w_arg_idx > match)
            --curwin->w_arg_idx;
          --match;
        }

      vim_regfree(regmatch.regprog);
      vim_free(p);
      if (!didone)
        EMSG2(_(e_nomatch2), ((char_u **)new_ga.ga_data)[i]);
    }
    ga_clear(&new_ga);
  } else   {
    i = expand_wildcards(new_ga.ga_len, (char_u **)new_ga.ga_data,
        &exp_count, &exp_files, EW_DIR|EW_FILE|EW_ADDSLASH|EW_NOTFOUND);
    ga_clear(&new_ga);
    if (i == FAIL)
      return FAIL;
    if (exp_count == 0) {
      EMSG(_(e_nomatch));
      return FAIL;
    }

    if (what == AL_ADD) {
      (void)alist_add_list(exp_count, exp_files, after);
      vim_free(exp_files);
    } else   /* what == AL_SET */
      alist_set(ALIST(curwin), exp_count, exp_files, FALSE, NULL, 0);
  }

  alist_check_arg_idx();

  return OK;
}

/*
 * Check the validity of the arg_idx for each other window.
 */
static void alist_check_arg_idx(void)                 {
  win_T       *win;
  tabpage_T   *tp;

  FOR_ALL_TAB_WINDOWS(tp, win)
  if (win->w_alist == curwin->w_alist)
    check_arg_idx(win);
}

/*
 * Return TRUE if window "win" is editing the file at the current argument
 * index.
 */
static int editing_arg_idx(win_T *win)
{
  return !(win->w_arg_idx >= WARGCOUNT(win)
           || (win->w_buffer->b_fnum
               != WARGLIST(win)[win->w_arg_idx].ae_fnum
               && (win->w_buffer->b_ffname == NULL
                   || !(fullpathcmp(
                            alist_name(&WARGLIST(win)[win->w_arg_idx]),
                            win->w_buffer->b_ffname, TRUE) & FPC_SAME))));
}

/*
 * Check if window "win" is editing the w_arg_idx file in its argument list.
 */
void check_arg_idx(win_T *win)
{
  if (WARGCOUNT(win) > 1 && !editing_arg_idx(win)) {
    /* We are not editing the current entry in the argument list.
     * Set "arg_had_last" if we are editing the last one. */
    win->w_arg_idx_invalid = TRUE;
    if (win->w_arg_idx != WARGCOUNT(win) - 1
        && arg_had_last == FALSE
        && ALIST(win) == &global_alist
        && GARGCOUNT > 0
        && win->w_arg_idx < GARGCOUNT
        && (win->w_buffer->b_fnum == GARGLIST[GARGCOUNT - 1].ae_fnum
            || (win->w_buffer->b_ffname != NULL
                && (fullpathcmp(alist_name(&GARGLIST[GARGCOUNT - 1]),
                        win->w_buffer->b_ffname, TRUE) & FPC_SAME))))
      arg_had_last = TRUE;
  } else   {
    /* We are editing the current entry in the argument list.
     * Set "arg_had_last" if it's also the last one */
    win->w_arg_idx_invalid = FALSE;
    if (win->w_arg_idx == WARGCOUNT(win) - 1
        && win->w_alist == &global_alist
        )
      arg_had_last = TRUE;
  }
}

/*
 * ":args", ":argslocal" and ":argsglobal".
 */
void ex_args(exarg_T *eap)
{
  int i;

  if (eap->cmdidx != CMD_args) {
    alist_unlink(ALIST(curwin));
    if (eap->cmdidx == CMD_argglobal)
      ALIST(curwin) = &global_alist;
    else     /* eap->cmdidx == CMD_arglocal */
      alist_new();
  }

  if (!ends_excmd(*eap->arg)) {
    /*
     * ":args file ..": define new argument list, handle like ":next"
     * Also for ":argslocal file .." and ":argsglobal file ..".
     */
    ex_next(eap);
  } else if (eap->cmdidx == CMD_args)    {
    /*
     * ":args": list arguments.
     */
    if (ARGCOUNT > 0) {
      /* Overwrite the command, for a short list there is no scrolling
       * required and no wait_return(). */
      gotocmdline(TRUE);
      for (i = 0; i < ARGCOUNT; ++i) {
        if (i == curwin->w_arg_idx)
          msg_putchar('[');
        msg_outtrans(alist_name(&ARGLIST[i]));
        if (i == curwin->w_arg_idx)
          msg_putchar(']');
        msg_putchar(' ');
      }
    }
  } else if (eap->cmdidx == CMD_arglocal)   {
    garray_T        *gap = &curwin->w_alist->al_ga;

    /*
     * ":argslocal": make a local copy of the global argument list.
     */
    if (ga_grow(gap, GARGCOUNT) == OK)
      for (i = 0; i < GARGCOUNT; ++i)
        if (GARGLIST[i].ae_fname != NULL) {
          AARGLIST(curwin->w_alist)[gap->ga_len].ae_fname =
            vim_strsave(GARGLIST[i].ae_fname);
          AARGLIST(curwin->w_alist)[gap->ga_len].ae_fnum =
            GARGLIST[i].ae_fnum;
          ++gap->ga_len;
        }
  }
}

/*
 * ":previous", ":sprevious", ":Next" and ":sNext".
 */
void ex_previous(exarg_T *eap)
{
  /* If past the last one already, go to the last one. */
  if (curwin->w_arg_idx - (int)eap->line2 >= ARGCOUNT)
    do_argfile(eap, ARGCOUNT - 1);
  else
    do_argfile(eap, curwin->w_arg_idx - (int)eap->line2);
}

/*
 * ":rewind", ":first", ":sfirst" and ":srewind".
 */
void ex_rewind(exarg_T *eap)
{
  do_argfile(eap, 0);
}

/*
 * ":last" and ":slast".
 */
void ex_last(exarg_T *eap)
{
  do_argfile(eap, ARGCOUNT - 1);
}

/*
 * ":argument" and ":sargument".
 */
void ex_argument(exarg_T *eap)
{
  int i;

  if (eap->addr_count > 0)
    i = eap->line2 - 1;
  else
    i = curwin->w_arg_idx;
  do_argfile(eap, i);
}

/*
 * Edit file "argn" of the argument lists.
 */
void do_argfile(exarg_T *eap, int argn)
{
  int other;
  char_u      *p;
  int old_arg_idx = curwin->w_arg_idx;

  if (argn < 0 || argn >= ARGCOUNT) {
    if (ARGCOUNT <= 1)
      EMSG(_("E163: There is only one file to edit"));
    else if (argn < 0)
      EMSG(_("E164: Cannot go before first file"));
    else
      EMSG(_("E165: Cannot go beyond last file"));
  } else   {
    setpcmark();

    /* split window or create new tab page first */
    if (*eap->cmd == 's' || cmdmod.tab != 0) {
      if (win_split(0, 0) == FAIL)
        return;
      RESET_BINDING(curwin);
    } else   {
      /*
       * if 'hidden' set, only check for changed file when re-editing
       * the same buffer
       */
      other = TRUE;
      if (P_HID(curbuf)) {
        p = fix_fname(alist_name(&ARGLIST[argn]));
        other = otherfile(p);
        vim_free(p);
      }
      if ((!P_HID(curbuf) || !other)
          && check_changed(curbuf, CCGD_AW
              | (other ? 0 : CCGD_MULTWIN)
              | (eap->forceit ? CCGD_FORCEIT : 0)
              | CCGD_EXCMD))
        return;
    }

    curwin->w_arg_idx = argn;
    if (argn == ARGCOUNT - 1
        && curwin->w_alist == &global_alist
        )
      arg_had_last = TRUE;

    /* Edit the file; always use the last known line number.
     * When it fails (e.g. Abort for already edited file) restore the
     * argument index. */
    if (do_ecmd(0, alist_name(&ARGLIST[curwin->w_arg_idx]), NULL,
            eap, ECMD_LAST,
            (P_HID(curwin->w_buffer) ? ECMD_HIDE : 0)
            + (eap->forceit ? ECMD_FORCEIT : 0), curwin) == FAIL)
      curwin->w_arg_idx = old_arg_idx;
    /* like Vi: set the mark where the cursor is in the file. */
    else if (eap->cmdidx != CMD_argdo)
      setmark('\'');
  }
}

/*
 * ":next", and commands that behave like it.
 */
void ex_next(exarg_T *eap)
{
  int i;

  /*
   * check for changed buffer now, if this fails the argument list is not
   * redefined.
   */
  if (       P_HID(curbuf)
             || eap->cmdidx == CMD_snext
             || !check_changed(curbuf, CCGD_AW
                 | (eap->forceit ? CCGD_FORCEIT : 0)
                 | CCGD_EXCMD)) {
    if (*eap->arg != NUL) {                 /* redefine file list */
      if (do_arglist(eap->arg, AL_SET, 0) == FAIL)
        return;
      i = 0;
    } else
      i = curwin->w_arg_idx + (int)eap->line2;
    do_argfile(eap, i);
  }
}

/*
 * ":argedit"
 */
void ex_argedit(exarg_T *eap)
{
  int fnum;
  int i;
  char_u      *s;

  /* Add the argument to the buffer list and get the buffer number. */
  fnum = buflist_add(eap->arg, BLN_LISTED);

  /* Check if this argument is already in the argument list. */
  for (i = 0; i < ARGCOUNT; ++i)
    if (ARGLIST[i].ae_fnum == fnum)
      break;
  if (i == ARGCOUNT) {
    /* Can't find it, add it to the argument list. */
    s = vim_strsave(eap->arg);
    if (s == NULL)
      return;
    i = alist_add_list(1, &s,
        eap->addr_count > 0 ? (int)eap->line2 : curwin->w_arg_idx + 1);
    if (i < 0)
      return;
    curwin->w_arg_idx = i;
  }

  alist_check_arg_idx();

  /* Edit the argument. */
  do_argfile(eap, i);
}

/*
 * ":argadd"
 */
void ex_argadd(exarg_T *eap)
{
  do_arglist(eap->arg, AL_ADD,
      eap->addr_count > 0 ? (int)eap->line2 : curwin->w_arg_idx + 1);
  maketitle();
}

/*
 * ":argdelete"
 */
void ex_argdelete(exarg_T *eap)
{
  int i;
  int n;

  if (eap->addr_count > 0) {
    /* ":1,4argdel": Delete all arguments in the range. */
    if (eap->line2 > ARGCOUNT)
      eap->line2 = ARGCOUNT;
    n = eap->line2 - eap->line1 + 1;
    if (*eap->arg != NUL || n <= 0)
      EMSG(_(e_invarg));
    else {
      for (i = eap->line1; i <= eap->line2; ++i)
        vim_free(ARGLIST[i - 1].ae_fname);
      mch_memmove(ARGLIST + eap->line1 - 1, ARGLIST + eap->line2,
          (size_t)((ARGCOUNT - eap->line2) * sizeof(aentry_T)));
      ALIST(curwin)->al_ga.ga_len -= n;
      if (curwin->w_arg_idx >= eap->line2)
        curwin->w_arg_idx -= n;
      else if (curwin->w_arg_idx > eap->line1)
        curwin->w_arg_idx = eap->line1;
    }
  } else if (*eap->arg == NUL)
    EMSG(_(e_argreq));
  else
    do_arglist(eap->arg, AL_DEL, 0);
  maketitle();
}

/*
 * ":argdo", ":windo", ":bufdo", ":tabdo"
 */
void ex_listdo(exarg_T *eap)
{
  int i;
  win_T       *wp;
  tabpage_T   *tp;
  buf_T       *buf;
  int next_fnum = 0;
  char_u      *save_ei = NULL;
  char_u      *p_shm_save;


  if (eap->cmdidx != CMD_windo && eap->cmdidx != CMD_tabdo)
    /* Don't do syntax HL autocommands.  Skipping the syntax file is a
     * great speed improvement. */
    save_ei = au_event_disable(",Syntax");

  if (eap->cmdidx == CMD_windo
      || eap->cmdidx == CMD_tabdo
      || P_HID(curbuf)
      || !check_changed(curbuf, CCGD_AW
          | (eap->forceit ? CCGD_FORCEIT : 0)
          | CCGD_EXCMD)) {
    /* start at the first argument/window/buffer */
    i = 0;
    wp = firstwin;
    tp = first_tabpage;
    /* set pcmark now */
    if (eap->cmdidx == CMD_bufdo)
      goto_buffer(eap, DOBUF_FIRST, FORWARD, 0);
    else
      setpcmark();
    listcmd_busy = TRUE;            /* avoids setting pcmark below */

    while (!got_int) {
      if (eap->cmdidx == CMD_argdo) {
        /* go to argument "i" */
        if (i == ARGCOUNT)
          break;
        /* Don't call do_argfile() when already there, it will try
         * reloading the file. */
        if (curwin->w_arg_idx != i || !editing_arg_idx(curwin)) {
          /* Clear 'shm' to avoid that the file message overwrites
           * any output from the command. */
          p_shm_save = vim_strsave(p_shm);
          set_option_value((char_u *)"shm", 0L, (char_u *)"", 0);
          do_argfile(eap, i);
          set_option_value((char_u *)"shm", 0L, p_shm_save, 0);
          vim_free(p_shm_save);
        }
        if (curwin->w_arg_idx != i)
          break;
        ++i;
      } else if (eap->cmdidx == CMD_windo)   {
        /* go to window "wp" */
        if (!win_valid(wp))
          break;
        win_goto(wp);
        if (curwin != wp)
          break;            /* something must be wrong */
        wp = curwin->w_next;
      } else if (eap->cmdidx == CMD_tabdo)   {
        /* go to window "tp" */
        if (!valid_tabpage(tp))
          break;
        goto_tabpage_tp(tp, TRUE, TRUE);
        tp = tp->tp_next;
      } else if (eap->cmdidx == CMD_bufdo)   {
        /* Remember the number of the next listed buffer, in case
         * ":bwipe" is used or autocommands do something strange. */
        next_fnum = -1;
        for (buf = curbuf->b_next; buf != NULL; buf = buf->b_next)
          if (buf->b_p_bl) {
            next_fnum = buf->b_fnum;
            break;
          }
      }

      /* execute the command */
      do_cmdline(eap->arg, eap->getline, eap->cookie,
          DOCMD_VERBOSE + DOCMD_NOWAIT);

      if (eap->cmdidx == CMD_bufdo) {
        /* Done? */
        if (next_fnum < 0)
          break;
        /* Check if the buffer still exists. */
        for (buf = firstbuf; buf != NULL; buf = buf->b_next)
          if (buf->b_fnum == next_fnum)
            break;
        if (buf == NULL)
          break;

        /* Go to the next buffer.  Clear 'shm' to avoid that the file
         * message overwrites any output from the command. */
        p_shm_save = vim_strsave(p_shm);
        set_option_value((char_u *)"shm", 0L, (char_u *)"", 0);
        goto_buffer(eap, DOBUF_FIRST, FORWARD, next_fnum);
        set_option_value((char_u *)"shm", 0L, p_shm_save, 0);
        vim_free(p_shm_save);

        /* If autocommands took us elsewhere, quit here */
        if (curbuf->b_fnum != next_fnum)
          break;
      }

      if (eap->cmdidx == CMD_windo) {
        validate_cursor();              /* cursor may have moved */
        /* required when 'scrollbind' has been set */
        if (curwin->w_p_scb)
          do_check_scrollbind(TRUE);
      }
    }
    listcmd_busy = FALSE;
  }

  if (save_ei != NULL) {
    au_event_restore(save_ei);
    apply_autocmds(EVENT_SYNTAX, curbuf->b_p_syn,
        curbuf->b_fname, TRUE, curbuf);
  }
}

/*
 * Add files[count] to the arglist of the current window after arg "after".
 * The file names in files[count] must have been allocated and are taken over.
 * Files[] itself is not taken over.
 * Returns index of first added argument.  Returns -1 when failed (out of mem).
 */
static int 
alist_add_list (
    int count,
    char_u **files,
    int after                  /* where to add: 0 = before first one */
)
{
  int i;

  if (ga_grow(&ALIST(curwin)->al_ga, count) == OK) {
    if (after < 0)
      after = 0;
    if (after > ARGCOUNT)
      after = ARGCOUNT;
    if (after < ARGCOUNT)
      mch_memmove(&(ARGLIST[after + count]), &(ARGLIST[after]),
          (ARGCOUNT - after) * sizeof(aentry_T));
    for (i = 0; i < count; ++i) {
      ARGLIST[after + i].ae_fname = files[i];
      ARGLIST[after + i].ae_fnum = buflist_add(files[i], BLN_LISTED);
    }
    ALIST(curwin)->al_ga.ga_len += count;
    if (curwin->w_arg_idx >= after)
      ++curwin->w_arg_idx;
    return after;
  }

  for (i = 0; i < count; ++i)
    vim_free(files[i]);
  return -1;
}


/*
 * ":compiler[!] {name}"
 */
void ex_compiler(exarg_T *eap)
{
  char_u      *buf;
  char_u      *old_cur_comp = NULL;
  char_u      *p;

  if (*eap->arg == NUL) {
    /* List all compiler scripts. */
    do_cmdline_cmd((char_u *)"echo globpath(&rtp, 'compiler/*.vim')");
    /* ) keep the indenter happy... */
  } else   {
    buf = alloc((unsigned)(STRLEN(eap->arg) + 14));
    if (buf != NULL) {
      if (eap->forceit) {
        /* ":compiler! {name}" sets global options */
        do_cmdline_cmd((char_u *)
            "command -nargs=* CompilerSet set <args>");
      } else   {
        /* ":compiler! {name}" sets local options.
         * To remain backwards compatible "current_compiler" is always
         * used.  A user's compiler plugin may set it, the distributed
         * plugin will then skip the settings.  Afterwards set
         * "b:current_compiler" and restore "current_compiler".
         * Explicitly prepend "g:" to make it work in a function. */
        old_cur_comp = get_var_value((char_u *)"g:current_compiler");
        if (old_cur_comp != NULL)
          old_cur_comp = vim_strsave(old_cur_comp);
        do_cmdline_cmd((char_u *)
            "command -nargs=* CompilerSet setlocal <args>");
      }
      do_unlet((char_u *)"g:current_compiler", TRUE);
      do_unlet((char_u *)"b:current_compiler", TRUE);

      sprintf((char *)buf, "compiler/%s.vim", eap->arg);
      if (source_runtime(buf, TRUE) == FAIL)
        EMSG2(_("E666: compiler not supported: %s"), eap->arg);
      vim_free(buf);

      do_cmdline_cmd((char_u *)":delcommand CompilerSet");

      /* Set "b:current_compiler" from "current_compiler". */
      p = get_var_value((char_u *)"g:current_compiler");
      if (p != NULL)
        set_internal_string_var((char_u *)"b:current_compiler", p);

      /* Restore "current_compiler" for ":compiler {name}". */
      if (!eap->forceit) {
        if (old_cur_comp != NULL) {
          set_internal_string_var((char_u *)"g:current_compiler",
              old_cur_comp);
          vim_free(old_cur_comp);
        } else
          do_unlet((char_u *)"g:current_compiler", TRUE);
      }
    }
  }
}

/*
 * ":runtime {name}"
 */
void ex_runtime(exarg_T *eap)
{
  source_runtime(eap->arg, eap->forceit);
}

static void source_callback(char_u *fname, void *cookie);

static void source_callback(char_u *fname, void *cookie)
{
  (void)do_source(fname, FALSE, DOSO_NONE);
}

/*
 * Source the file "name" from all directories in 'runtimepath'.
 * "name" can contain wildcards.
 * When "all" is TRUE, source all files, otherwise only the first one.
 * return FAIL when no file could be sourced, OK otherwise.
 */
int source_runtime(char_u *name, int all)
{
  return do_in_runtimepath(name, all, source_callback, NULL);
}

/*
 * Find "name" in 'runtimepath'.  When found, invoke the callback function for
 * it: callback(fname, "cookie")
 * When "all" is TRUE repeat for all matches, otherwise only the first one is
 * used.
 * Returns OK when at least one match found, FAIL otherwise.
 *
 * If "name" is NULL calls callback for each entry in runtimepath. Cookie is
 * passed by reference in this case, setting it to NULL indicates that callback
 * has done its job.
 */
int do_in_runtimepath(name, all, callback, cookie)
char_u      *name;
int all;
void        (*callback)(char_u *fname, void *ck);
void        *cookie;
{
  char_u      *rtp;
  char_u      *np;
  char_u      *buf;
  char_u      *rtp_copy;
  char_u      *tail;
  int num_files;
  char_u      **files;
  int i;
  int did_one = FALSE;

  /* Make a copy of 'runtimepath'.  Invoking the callback may change the
   * value. */
  rtp_copy = vim_strsave(p_rtp);
  buf = alloc(MAXPATHL);
  if (buf != NULL && rtp_copy != NULL) {
    if (p_verbose > 1 && name != NULL) {
      verbose_enter();
      smsg((char_u *)_("Searching for \"%s\" in \"%s\""),
          (char *)name, (char *)p_rtp);
      verbose_leave();
    }

    /* Loop over all entries in 'runtimepath'. */
    rtp = rtp_copy;
    while (*rtp != NUL && (all || !did_one)) {
      /* Copy the path from 'runtimepath' to buf[]. */
      copy_option_part(&rtp, buf, MAXPATHL, ",");
      if (name == NULL) {
        (*callback)(buf, (void *) &cookie);
        if (!did_one)
          did_one = (cookie == NULL);
      } else if (STRLEN(buf) + STRLEN(name) + 2 < MAXPATHL)   {
        add_pathsep(buf);
        tail = buf + STRLEN(buf);

        /* Loop over all patterns in "name" */
        np = name;
        while (*np != NUL && (all || !did_one)) {
          /* Append the pattern from "name" to buf[]. */
          copy_option_part(&np, tail, (int)(MAXPATHL - (tail - buf)),
              "\t ");

          if (p_verbose > 2) {
            verbose_enter();
            smsg((char_u *)_("Searching for \"%s\""), buf);
            verbose_leave();
          }

          /* Expand wildcards, invoke the callback for each match. */
          if (gen_expand_wildcards(1, &buf, &num_files, &files,
                  EW_FILE) == OK) {
            for (i = 0; i < num_files; ++i) {
              (*callback)(files[i], cookie);
              did_one = TRUE;
              if (!all)
                break;
            }
            FreeWild(num_files, files);
          }
        }
      }
    }
  }
  vim_free(buf);
  vim_free(rtp_copy);
  if (p_verbose > 0 && !did_one && name != NULL) {
    verbose_enter();
    smsg((char_u *)_("not found in 'runtimepath': \"%s\""), name);
    verbose_leave();
  }


  return did_one ? OK : FAIL;
}

/*
 * ":options"
 */
void ex_options(exarg_T *eap)
{
  cmd_source((char_u *)SYS_OPTWIN_FILE, NULL);
}

/*
 * ":source {fname}"
 */
void ex_source(exarg_T *eap)
{
  cmd_source(eap->arg, eap);
}

static void cmd_source(char_u *fname, exarg_T *eap)
{
  if (*fname == NUL)
    EMSG(_(e_argreq));

  else if (eap != NULL && eap->forceit)
    /* ":source!": read Normal mode commands
     * Need to execute the commands directly.  This is required at least
     * for:
     * - ":g" command busy
     * - after ":argdo", ":windo" or ":bufdo"
     * - another command follows
     * - inside a loop
     */
    openscript(fname, global_busy || listcmd_busy || eap->nextcmd != NULL
        || eap->cstack->cs_idx >= 0
        );

  /* ":source" read ex commands */
  else if (do_source(fname, FALSE, DOSO_NONE) == FAIL)
    EMSG2(_(e_notopen), fname);
}

/*
 * ":source" and associated commands.
 */
/*
 * Structure used to store info for each sourced file.
 * It is shared between do_source() and getsourceline().
 * This is required, because it needs to be handed to do_cmdline() and
 * sourcing can be done recursively.
 */
struct source_cookie {
  FILE        *fp;              /* opened file for sourcing */
  char_u      *nextline;        /* if not NULL: line that was read ahead */
  int finished;                 /* ":finish" used */
#if defined(USE_CRNL) || defined(USE_CR)
  int fileformat;               /* EOL_UNKNOWN, EOL_UNIX or EOL_DOS */
  int error;                    /* TRUE if LF found after CR-LF */
#endif
  linenr_T breakpoint;          /* next line with breakpoint or zero */
  char_u      *fname;           /* name of sourced file */
  int dbg_tick;                 /* debug_tick when breakpoint was set */
  int level;                    /* top nesting level of sourced file */
  vimconv_T conv;               /* type of conversion */
};

/*
 * Return the address holding the next breakpoint line for a source cookie.
 */
linenr_T *source_breakpoint(void *cookie)
{
  return &((struct source_cookie *)cookie)->breakpoint;
}

/*
 * Return the address holding the debug tick for a source cookie.
 */
int *source_dbg_tick(void *cookie)
{
  return &((struct source_cookie *)cookie)->dbg_tick;
}

/*
 * Return the nesting level for a source cookie.
 */
int source_level(void *cookie)
{
  return ((struct source_cookie *)cookie)->level;
}

static char_u *get_one_sourceline(struct source_cookie *sp);

#if (defined(WIN32) && defined(FEAT_CSCOPE)) || defined(HAVE_FD_CLOEXEC)
# define USE_FOPEN_NOINH
static FILE *fopen_noinh_readbin(char *filename);

/*
 * Special function to open a file without handle inheritance.
 * When possible the handle is closed on exec().
 */
static FILE *fopen_noinh_readbin(char *filename)
{
  int fd_tmp = mch_open(filename, O_RDONLY, 0);

  if (fd_tmp == -1)
    return NULL;

# ifdef HAVE_FD_CLOEXEC
  {
    int fdflags = fcntl(fd_tmp, F_GETFD);
    if (fdflags >= 0 && (fdflags & FD_CLOEXEC) == 0)
      fcntl(fd_tmp, F_SETFD, fdflags | FD_CLOEXEC);
  }
# endif

  return fdopen(fd_tmp, READBIN);
}
#endif


/*
 * do_source: Read the file "fname" and execute its lines as EX commands.
 *
 * This function may be called recursively!
 *
 * return FAIL if file could not be opened, OK otherwise
 */
int 
do_source (
    char_u *fname,
    int check_other,                    /* check for .vimrc and _vimrc */
    int is_vimrc                       /* DOSO_ value */
)
{
  struct source_cookie cookie;
  char_u                  *save_sourcing_name;
  linenr_T save_sourcing_lnum;
  char_u                  *p;
  char_u                  *fname_exp;
  char_u                  *firstline = NULL;
  int retval = FAIL;
  scid_T save_current_SID;
  static scid_T last_current_SID = 0;
  void                    *save_funccalp;
  int save_debug_break_level = debug_break_level;
  scriptitem_T            *si = NULL;
# ifdef UNIX
  struct stat st;
  int stat_ok;
# endif
#ifdef STARTUPTIME
  struct timeval tv_rel;
  struct timeval tv_start;
#endif
  proftime_T wait_start;

  p = expand_env_save(fname);
  if (p == NULL)
    return retval;
  fname_exp = fix_fname(p);
  vim_free(p);
  if (fname_exp == NULL)
    return retval;
  if (mch_isdir(fname_exp)) {
    smsg((char_u *)_("Cannot source a directory: \"%s\""), fname);
    goto theend;
  }

  /* Apply SourceCmd autocommands, they should get the file and source it. */
  if (has_autocmd(EVENT_SOURCECMD, fname_exp, NULL)
      && apply_autocmds(EVENT_SOURCECMD, fname_exp, fname_exp,
          FALSE, curbuf)) {
    retval = aborting() ? FAIL : OK;
    goto theend;
  }

  /* Apply SourcePre autocommands, they may get the file. */
  apply_autocmds(EVENT_SOURCEPRE, fname_exp, fname_exp, FALSE, curbuf);

#ifdef USE_FOPEN_NOINH
  cookie.fp = fopen_noinh_readbin((char *)fname_exp);
#else
  cookie.fp = mch_fopen((char *)fname_exp, READBIN);
#endif
  if (cookie.fp == NULL && check_other) {
    /*
     * Try again, replacing file name ".vimrc" by "_vimrc" or vice versa,
     * and ".exrc" by "_exrc" or vice versa.
     */
    p = gettail(fname_exp);
    if ((*p == '.' || *p == '_')
        && (STRICMP(p + 1, "vimrc") == 0
            || STRICMP(p + 1, "gvimrc") == 0
            || STRICMP(p + 1, "exrc") == 0)) {
      if (*p == '_')
        *p = '.';
      else
        *p = '_';
#ifdef USE_FOPEN_NOINH
      cookie.fp = fopen_noinh_readbin((char *)fname_exp);
#else
      cookie.fp = mch_fopen((char *)fname_exp, READBIN);
#endif
    }
  }

  if (cookie.fp == NULL) {
    if (p_verbose > 0) {
      verbose_enter();
      if (sourcing_name == NULL)
        smsg((char_u *)_("could not source \"%s\""), fname);
      else
        smsg((char_u *)_("line %ld: could not source \"%s\""),
            sourcing_lnum, fname);
      verbose_leave();
    }
    goto theend;
  }

  /*
   * The file exists.
   * - In verbose mode, give a message.
   * - For a vimrc file, may want to set 'compatible', call vimrc_found().
   */
  if (p_verbose > 1) {
    verbose_enter();
    if (sourcing_name == NULL)
      smsg((char_u *)_("sourcing \"%s\""), fname);
    else
      smsg((char_u *)_("line %ld: sourcing \"%s\""),
          sourcing_lnum, fname);
    verbose_leave();
  }
  if (is_vimrc == DOSO_VIMRC)
    vimrc_found(fname_exp, (char_u *)"MYVIMRC");
  else if (is_vimrc == DOSO_GVIMRC)
    vimrc_found(fname_exp, (char_u *)"MYGVIMRC");

#ifdef USE_CRNL
  /* If no automatic file format: Set default to CR-NL. */
  if (*p_ffs == NUL)
    cookie.fileformat = EOL_DOS;
  else
    cookie.fileformat = EOL_UNKNOWN;
  cookie.error = FALSE;
#endif

#ifdef USE_CR
  /* If no automatic file format: Set default to CR. */
  if (*p_ffs == NUL)
    cookie.fileformat = EOL_MAC;
  else
    cookie.fileformat = EOL_UNKNOWN;
  cookie.error = FALSE;
#endif

  cookie.nextline = NULL;
  cookie.finished = FALSE;

  /*
   * Check if this script has a breakpoint.
   */
  cookie.breakpoint = dbg_find_breakpoint(TRUE, fname_exp, (linenr_T)0);
  cookie.fname = fname_exp;
  cookie.dbg_tick = debug_tick;

  cookie.level = ex_nesting_level;

  /*
   * Keep the sourcing name/lnum, for recursive calls.
   */
  save_sourcing_name = sourcing_name;
  sourcing_name = fname_exp;
  save_sourcing_lnum = sourcing_lnum;
  sourcing_lnum = 0;

  cookie.conv.vc_type = CONV_NONE;              /* no conversion */

  /* Read the first line so we can check for a UTF-8 BOM. */
  firstline = getsourceline(0, (void *)&cookie, 0);
  if (firstline != NULL && STRLEN(firstline) >= 3 && firstline[0] == 0xef
      && firstline[1] == 0xbb && firstline[2] == 0xbf) {
    /* Found BOM; setup conversion, skip over BOM and recode the line. */
    convert_setup(&cookie.conv, (char_u *)"utf-8", p_enc);
    p = string_convert(&cookie.conv, firstline + 3, NULL);
    if (p == NULL)
      p = vim_strsave(firstline + 3);
    if (p != NULL) {
      vim_free(firstline);
      firstline = p;
    }
  }

#ifdef STARTUPTIME
  if (time_fd != NULL)
    time_push(&tv_rel, &tv_start);
#endif

  if (do_profiling == PROF_YES)
    prof_child_enter(&wait_start);              /* entering a child now */

  /* Don't use local function variables, if called from a function.
   * Also starts profiling timer for nested script. */
  save_funccalp = save_funccal();

  /*
   * Check if this script was sourced before to finds its SID.
   * If it's new, generate a new SID.
   */
  save_current_SID = current_SID;
# ifdef UNIX
  stat_ok = (mch_stat((char *)fname_exp, &st) >= 0);
# endif
  for (current_SID = script_items.ga_len; current_SID > 0; --current_SID) {
    si = &SCRIPT_ITEM(current_SID);
    if (si->sn_name != NULL
        && (
# ifdef UNIX
          /* Compare dev/ino when possible, it catches symbolic
           * links.  Also compare file names, the inode may change
           * when the file was edited. */
          ((stat_ok && si->sn_dev_valid)
           && (si->sn_dev == st.st_dev
               && si->sn_ino == st.st_ino)) ||
# endif
          fnamecmp(si->sn_name, fname_exp) == 0))
      break;
  }
  if (current_SID == 0) {
    current_SID = ++last_current_SID;
    if (ga_grow(&script_items, (int)(current_SID - script_items.ga_len))
        == FAIL)
      goto almosttheend;
    while (script_items.ga_len < current_SID) {
      ++script_items.ga_len;
      SCRIPT_ITEM(script_items.ga_len).sn_name = NULL;
      SCRIPT_ITEM(script_items.ga_len).sn_prof_on = FALSE;
    }
    si = &SCRIPT_ITEM(current_SID);
    si->sn_name = fname_exp;
    fname_exp = NULL;
# ifdef UNIX
    if (stat_ok) {
      si->sn_dev_valid = TRUE;
      si->sn_dev = st.st_dev;
      si->sn_ino = st.st_ino;
    } else
      si->sn_dev_valid = FALSE;
# endif

    /* Allocate the local script variables to use for this script. */
    new_script_vars(current_SID);
  }

  if (do_profiling == PROF_YES) {
    int forceit;

    /* Check if we do profiling for this script. */
    if (!si->sn_prof_on && has_profiling(TRUE, si->sn_name, &forceit)) {
      script_do_profile(si);
      si->sn_pr_force = forceit;
    }
    if (si->sn_prof_on) {
      ++si->sn_pr_count;
      profile_start(&si->sn_pr_start);
      profile_zero(&si->sn_pr_children);
    }
  }

  /*
   * Call do_cmdline, which will call getsourceline() to get the lines.
   */
  do_cmdline(firstline, getsourceline, (void *)&cookie,
      DOCMD_VERBOSE|DOCMD_NOWAIT|DOCMD_REPEAT);
  retval = OK;

  if (do_profiling == PROF_YES) {
    /* Get "si" again, "script_items" may have been reallocated. */
    si = &SCRIPT_ITEM(current_SID);
    if (si->sn_prof_on) {
      profile_end(&si->sn_pr_start);
      profile_sub_wait(&wait_start, &si->sn_pr_start);
      profile_add(&si->sn_pr_total, &si->sn_pr_start);
      profile_self(&si->sn_pr_self, &si->sn_pr_start,
          &si->sn_pr_children);
    }
  }

  if (got_int)
    EMSG(_(e_interr));
  sourcing_name = save_sourcing_name;
  sourcing_lnum = save_sourcing_lnum;
  if (p_verbose > 1) {
    verbose_enter();
    smsg((char_u *)_("finished sourcing %s"), fname);
    if (sourcing_name != NULL)
      smsg((char_u *)_("continuing in %s"), sourcing_name);
    verbose_leave();
  }
#ifdef STARTUPTIME
  if (time_fd != NULL) {
    vim_snprintf((char *)IObuff, IOSIZE, "sourcing %s", fname);
    time_msg((char *)IObuff, &tv_start);
    time_pop(&tv_rel);
  }
#endif

  /*
   * After a "finish" in debug mode, need to break at first command of next
   * sourced file.
   */
  if (save_debug_break_level > ex_nesting_level
      && debug_break_level == ex_nesting_level)
    ++debug_break_level;

almosttheend:
  current_SID = save_current_SID;
  restore_funccal(save_funccalp);
  if (do_profiling == PROF_YES)
    prof_child_exit(&wait_start);               /* leaving a child now */
  fclose(cookie.fp);
  vim_free(cookie.nextline);
  vim_free(firstline);
  convert_setup(&cookie.conv, NULL, NULL);

theend:
  vim_free(fname_exp);
  return retval;
}


/*
 * ":scriptnames"
 */
void ex_scriptnames(exarg_T *eap)
{
  int i;

  for (i = 1; i <= script_items.ga_len && !got_int; ++i)
    if (SCRIPT_ITEM(i).sn_name != NULL) {
      home_replace(NULL, SCRIPT_ITEM(i).sn_name,
          NameBuff, MAXPATHL, TRUE);
      smsg((char_u *)"%3d: %s", i, NameBuff);
    }
}

# if defined(BACKSLASH_IN_FILENAME) || defined(PROTO)
/*
 * Fix slashes in the list of script names for 'shellslash'.
 */
void scriptnames_slash_adjust(void)          {
  int i;

  for (i = 1; i <= script_items.ga_len; ++i)
    if (SCRIPT_ITEM(i).sn_name != NULL)
      slash_adjust(SCRIPT_ITEM(i).sn_name);
}

# endif

/*
 * Get a pointer to a script name.  Used for ":verbose set".
 */
char_u *get_scriptname(scid_T id)
{
  if (id == SID_MODELINE)
    return (char_u *)_("modeline");
  if (id == SID_CMDARG)
    return (char_u *)_("--cmd argument");
  if (id == SID_CARG)
    return (char_u *)_("-c argument");
  if (id == SID_ENV)
    return (char_u *)_("environment variable");
  if (id == SID_ERROR)
    return (char_u *)_("error handler");
  return SCRIPT_ITEM(id).sn_name;
}

# if defined(EXITFREE) || defined(PROTO)
void free_scriptnames(void)          {
  int i;

  for (i = script_items.ga_len; i > 0; --i)
    vim_free(SCRIPT_ITEM(i).sn_name);
  ga_clear(&script_items);
}

# endif


#if defined(USE_CR) || defined(PROTO)

# if defined(__MSL__) && (__MSL__ >= 22)
/*
 * Newer version of the Metrowerks library handle DOS and UNIX files
 * without help.
 * Test with earlier versions, MSL 2.2 is the library supplied with
 * Codewarrior Pro 2.
 */
char *fgets_cr(char *s, int n, FILE *stream)
{
  return fgets(s, n, stream);
}
# else
/*
 * Version of fgets() which also works for lines ending in a <CR> only
 * (Macintosh format).
 * For older versions of the Metrowerks library.
 * At least CodeWarrior 9 needed this code.
 */
char *fgets_cr(char *s, int n, FILE *stream)
{
  int c = 0;
  int char_read = 0;

  while (!feof(stream) && c != '\r' && c != '\n' && char_read < n - 1) {
    c = fgetc(stream);
    s[char_read++] = c;
    /* If the file is in DOS format, we need to skip a NL after a CR.  I
     * thought it was the other way around, but this appears to work... */
    if (c == '\n') {
      c = fgetc(stream);
      if (c != '\r')
        ungetc(c, stream);
    }
  }

  s[char_read] = 0;
  if (char_read == 0)
    return NULL;

  if (feof(stream) && char_read == 1)
    return NULL;

  return s;
}
# endif
#endif

/*
 * Get one full line from a sourced file.
 * Called by do_cmdline() when it's called from do_source().
 *
 * Return a pointer to the line in allocated memory.
 * Return NULL for end-of-file or some error.
 */
char_u *getsourceline(int c, void *cookie, int indent)
{
  struct source_cookie *sp = (struct source_cookie *)cookie;
  char_u              *line;
  char_u              *p;

  /* If breakpoints have been added/deleted need to check for it. */
  if (sp->dbg_tick < debug_tick) {
    sp->breakpoint = dbg_find_breakpoint(TRUE, sp->fname, sourcing_lnum);
    sp->dbg_tick = debug_tick;
  }
  if (do_profiling == PROF_YES)
    script_line_end();
  /*
   * Get current line.  If there is a read-ahead line, use it, otherwise get
   * one now.
   */
  if (sp->finished)
    line = NULL;
  else if (sp->nextline == NULL)
    line = get_one_sourceline(sp);
  else {
    line = sp->nextline;
    sp->nextline = NULL;
    ++sourcing_lnum;
  }
  if (line != NULL && do_profiling == PROF_YES)
    script_line_start();

  /* Only concatenate lines starting with a \ when 'cpoptions' doesn't
   * contain the 'C' flag. */
  if (line != NULL && (vim_strchr(p_cpo, CPO_CONCAT) == NULL)) {
    /* compensate for the one line read-ahead */
    --sourcing_lnum;

    /* Get the next line and concatenate it when it starts with a
     * backslash. We always need to read the next line, keep it in
     * sp->nextline. */
    sp->nextline = get_one_sourceline(sp);
    if (sp->nextline != NULL && *(p = skipwhite(sp->nextline)) == '\\') {
      garray_T ga;

      ga_init2(&ga, (int)sizeof(char_u), 400);
      ga_concat(&ga, line);
      ga_concat(&ga, p + 1);
      for (;; ) {
        vim_free(sp->nextline);
        sp->nextline = get_one_sourceline(sp);
        if (sp->nextline == NULL)
          break;
        p = skipwhite(sp->nextline);
        if (*p != '\\')
          break;
        /* Adjust the growsize to the current length to speed up
         * concatenating many lines. */
        if (ga.ga_len > 400) {
          if (ga.ga_len > 8000)
            ga.ga_growsize = 8000;
          else
            ga.ga_growsize = ga.ga_len;
        }
        ga_concat(&ga, p + 1);
      }
      ga_append(&ga, NUL);
      vim_free(line);
      line = ga.ga_data;
    }
  }

  if (line != NULL && sp->conv.vc_type != CONV_NONE) {
    char_u  *s;

    /* Convert the encoding of the script line. */
    s = string_convert(&sp->conv, line, NULL);
    if (s != NULL) {
      vim_free(line);
      line = s;
    }
  }

  /* Did we encounter a breakpoint? */
  if (sp->breakpoint != 0 && sp->breakpoint <= sourcing_lnum) {
    dbg_breakpoint(sp->fname, sourcing_lnum);
    /* Find next breakpoint. */
    sp->breakpoint = dbg_find_breakpoint(TRUE, sp->fname, sourcing_lnum);
    sp->dbg_tick = debug_tick;
  }

  return line;
}

static char_u *get_one_sourceline(struct source_cookie *sp)
{
  garray_T ga;
  int len;
  int c;
  char_u              *buf;
#ifdef USE_CRNL
  int has_cr;                           /* CR-LF found */
#endif
#ifdef USE_CR
  char_u              *scan;
#endif
  int have_read = FALSE;

  /* use a growarray to store the sourced line */
  ga_init2(&ga, 1, 250);

  /*
   * Loop until there is a finished line (or end-of-file).
   */
  sourcing_lnum++;
  for (;; ) {
    /* make room to read at least 120 (more) characters */
    if (ga_grow(&ga, 120) == FAIL)
      break;
    buf = (char_u *)ga.ga_data;

#ifdef USE_CR
    if (sp->fileformat == EOL_MAC) {
      if (fgets_cr((char *)buf + ga.ga_len, ga.ga_maxlen - ga.ga_len,
              sp->fp) == NULL)
        break;
    } else
#endif
    if (fgets((char *)buf + ga.ga_len, ga.ga_maxlen - ga.ga_len,
            sp->fp) == NULL)
      break;
    len = ga.ga_len + (int)STRLEN(buf + ga.ga_len);
#ifdef USE_CRNL
    /* Ignore a trailing CTRL-Z, when in Dos mode.	Only recognize the
     * CTRL-Z by its own, or after a NL. */
    if (       (len == 1 || (len >= 2 && buf[len - 2] == '\n'))
               && sp->fileformat == EOL_DOS
               && buf[len - 1] == Ctrl_Z) {
      buf[len - 1] = NUL;
      break;
    }
#endif

#ifdef USE_CR
    /* If the read doesn't stop on a new line, and there's
     * some CR then we assume a Mac format */
    if (sp->fileformat == EOL_UNKNOWN) {
      if (buf[len - 1] != '\n' && vim_strchr(buf, '\r') != NULL)
        sp->fileformat = EOL_MAC;
      else
        sp->fileformat = EOL_UNIX;
    }

    if (sp->fileformat == EOL_MAC) {
      scan = vim_strchr(buf, '\r');

      if (scan != NULL) {
        *scan = '\n';
        if (*(scan + 1) != 0) {
          *(scan + 1) = 0;
          fseek(sp->fp, (long)(scan - buf - len + 1), SEEK_CUR);
        }
      }
      len = STRLEN(buf);
    }
#endif

    have_read = TRUE;
    ga.ga_len = len;

    /* If the line was longer than the buffer, read more. */
    if (ga.ga_maxlen - ga.ga_len == 1 && buf[len - 1] != '\n')
      continue;

    if (len >= 1 && buf[len - 1] == '\n') {     /* remove trailing NL */
#ifdef USE_CRNL
      has_cr = (len >= 2 && buf[len - 2] == '\r');
      if (sp->fileformat == EOL_UNKNOWN) {
        if (has_cr)
          sp->fileformat = EOL_DOS;
        else
          sp->fileformat = EOL_UNIX;
      }

      if (sp->fileformat == EOL_DOS) {
        if (has_cr) {               /* replace trailing CR */
          buf[len - 2] = '\n';
          --len;
          --ga.ga_len;
        } else   {          /* lines like ":map xx yy^M" will have failed */
          if (!sp->error) {
            msg_source(hl_attr(HLF_W));
            EMSG(_("W15: Warning: Wrong line separator, ^M may be missing"));
          }
          sp->error = TRUE;
          sp->fileformat = EOL_UNIX;
        }
      }
#endif
      /* The '\n' is escaped if there is an odd number of ^V's just
       * before it, first set "c" just before the 'V's and then check
       * len&c parities (is faster than ((len-c)%2 == 0)) -- Acevedo */
      for (c = len - 2; c >= 0 && buf[c] == Ctrl_V; c--)
        ;
      if ((len & 1) != (c & 1)) {       /* escaped NL, read more */
        sourcing_lnum++;
        continue;
      }

      buf[len - 1] = NUL;               /* remove the NL */
    }

    /*
     * Check for ^C here now and then, so recursive :so can be broken.
     */
    line_breakcheck();
    break;
  }

  if (have_read)
    return (char_u *)ga.ga_data;

  vim_free(ga.ga_data);
  return NULL;
}

/*
 * Called when starting to read a script line.
 * "sourcing_lnum" must be correct!
 * When skipping lines it may not actually be executed, but we won't find out
 * until later and we need to store the time now.
 */
void script_line_start(void)          {
  scriptitem_T    *si;
  sn_prl_T        *pp;

  if (current_SID <= 0 || current_SID > script_items.ga_len)
    return;
  si = &SCRIPT_ITEM(current_SID);
  if (si->sn_prof_on && sourcing_lnum >= 1) {
    /* Grow the array before starting the timer, so that the time spent
     * here isn't counted. */
    ga_grow(&si->sn_prl_ga, (int)(sourcing_lnum - si->sn_prl_ga.ga_len));
    si->sn_prl_idx = sourcing_lnum - 1;
    while (si->sn_prl_ga.ga_len <= si->sn_prl_idx
           && si->sn_prl_ga.ga_len < si->sn_prl_ga.ga_maxlen) {
      /* Zero counters for a line that was not used before. */
      pp = &PRL_ITEM(si, si->sn_prl_ga.ga_len);
      pp->snp_count = 0;
      profile_zero(&pp->sn_prl_total);
      profile_zero(&pp->sn_prl_self);
      ++si->sn_prl_ga.ga_len;
    }
    si->sn_prl_execed = FALSE;
    profile_start(&si->sn_prl_start);
    profile_zero(&si->sn_prl_children);
    profile_get_wait(&si->sn_prl_wait);
  }
}

/*
 * Called when actually executing a function line.
 */
void script_line_exec(void)          {
  scriptitem_T    *si;

  if (current_SID <= 0 || current_SID > script_items.ga_len)
    return;
  si = &SCRIPT_ITEM(current_SID);
  if (si->sn_prof_on && si->sn_prl_idx >= 0)
    si->sn_prl_execed = TRUE;
}

/*
 * Called when done with a function line.
 */
void script_line_end(void)          {
  scriptitem_T    *si;
  sn_prl_T        *pp;

  if (current_SID <= 0 || current_SID > script_items.ga_len)
    return;
  si = &SCRIPT_ITEM(current_SID);
  if (si->sn_prof_on && si->sn_prl_idx >= 0
      && si->sn_prl_idx < si->sn_prl_ga.ga_len) {
    if (si->sn_prl_execed) {
      pp = &PRL_ITEM(si, si->sn_prl_idx);
      ++pp->snp_count;
      profile_end(&si->sn_prl_start);
      profile_sub_wait(&si->sn_prl_wait, &si->sn_prl_start);
      profile_add(&pp->sn_prl_total, &si->sn_prl_start);
      profile_self(&pp->sn_prl_self, &si->sn_prl_start,
          &si->sn_prl_children);
    }
    si->sn_prl_idx = -1;
  }
}

/*
 * ":scriptencoding": Set encoding conversion for a sourced script.
 * Without the multi-byte feature it's simply ignored.
 */
void ex_scriptencoding(exarg_T *eap)
{
  struct source_cookie        *sp;
  char_u                      *name;

  if (!getline_equal(eap->getline, eap->cookie, getsourceline)) {
    EMSG(_("E167: :scriptencoding used outside of a sourced file"));
    return;
  }

  if (*eap->arg != NUL) {
    name = enc_canonize(eap->arg);
    if (name == NULL)           /* out of memory */
      return;
  } else
    name = eap->arg;

  /* Setup for conversion from the specified encoding to 'encoding'. */
  sp = (struct source_cookie *)getline_cookie(eap->getline, eap->cookie);
  convert_setup(&sp->conv, name, p_enc);

  if (name != eap->arg)
    vim_free(name);
}

/*
 * ":finish": Mark a sourced file as finished.
 */
void ex_finish(exarg_T *eap)
{
  if (getline_equal(eap->getline, eap->cookie, getsourceline))
    do_finish(eap, FALSE);
  else
    EMSG(_("E168: :finish used outside of a sourced file"));
}

/*
 * Mark a sourced file as finished.  Possibly makes the ":finish" pending.
 * Also called for a pending finish at the ":endtry" or after returning from
 * an extra do_cmdline().  "reanimate" is used in the latter case.
 */
void do_finish(exarg_T *eap, int reanimate)
{
  int idx;

  if (reanimate)
    ((struct source_cookie *)getline_cookie(eap->getline,
         eap->cookie))->finished = FALSE;

  /*
   * Cleanup (and inactivate) conditionals, but stop when a try conditional
   * not in its finally clause (which then is to be executed next) is found.
   * In this case, make the ":finish" pending for execution at the ":endtry".
   * Otherwise, finish normally.
   */
  idx = cleanup_conditionals(eap->cstack, 0, TRUE);
  if (idx >= 0) {
    eap->cstack->cs_pending[idx] = CSTP_FINISH;
    report_make_pending(CSTP_FINISH, NULL);
  } else
    ((struct source_cookie *)getline_cookie(eap->getline,
         eap->cookie))->finished = TRUE;
}


/*
 * Return TRUE when a sourced file had the ":finish" command: Don't give error
 * message for missing ":endif".
 * Return FALSE when not sourcing a file.
 */
int source_finished(fgetline, cookie)
char_u      *(*fgetline)(int, void *, int);
void        *cookie;
{
  return getline_equal(fgetline, cookie, getsourceline)
         && ((struct source_cookie *)getline_cookie(
                 fgetline, cookie))->finished;
}

/*
 * ":checktime [buffer]"
 */
void ex_checktime(exarg_T *eap)
{
  buf_T       *buf;
  int save_no_check_timestamps = no_check_timestamps;

  no_check_timestamps = 0;
  if (eap->addr_count == 0)     /* default is all buffers */
    check_timestamps(FALSE);
  else {
    buf = buflist_findnr((int)eap->line2);
    if (buf != NULL)            /* cannot happen? */
      (void)buf_check_timestamp(buf, FALSE);
  }
  no_check_timestamps = save_no_check_timestamps;
}

#if (defined(HAVE_LOCALE_H) || defined(X_LOCALE)) \
  && (defined(FEAT_EVAL) || defined(FEAT_MULTI_LANG))
# define HAVE_GET_LOCALE_VAL
static char *get_locale_val(int what);

static char *get_locale_val(int what)
{
  char        *loc;

  /* Obtain the locale value from the libraries.  For DJGPP this is
   * redefined and it doesn't use the arguments. */
  loc = setlocale(what, NULL);


  return loc;
}
#endif



/*
 * Obtain the current messages language.  Used to set the default for
 * 'helplang'.  May return NULL or an empty string.
 */
char_u *get_mess_lang(void)              {
  char_u *p;

# ifdef HAVE_GET_LOCALE_VAL
#  if defined(LC_MESSAGES)
  p = (char_u *)get_locale_val(LC_MESSAGES);
#  else
  /* This is necessary for Win32, where LC_MESSAGES is not defined and $LANG
   * may be set to the LCID number.  LC_COLLATE is the best guess, LC_TIME
   * and LC_MONETARY may be set differently for a Japanese working in the
   * US. */
  p = (char_u *)get_locale_val(LC_COLLATE);
#  endif
# else
  p = mch_getenv((char_u *)"LC_ALL");
  if (p == NULL || *p == NUL) {
    p = mch_getenv((char_u *)"LC_MESSAGES");
    if (p == NULL || *p == NUL)
      p = mch_getenv((char_u *)"LANG");
  }
# endif
  return p;
}

/* Complicated #if; matches with where get_mess_env() is used below. */
#ifdef HAVE_WORKING_LIBINTL
static char_u *get_mess_env(void);

/*
 * Get the language used for messages from the environment.
 */
static char_u *get_mess_env(void)                     {
  char_u      *p;

  p = mch_getenv((char_u *)"LC_ALL");
  if (p == NULL || *p == NUL) {
    p = mch_getenv((char_u *)"LC_MESSAGES");
    if (p == NULL || *p == NUL) {
      p = mch_getenv((char_u *)"LANG");
      if (p != NULL && VIM_ISDIGIT(*p))
        p = NULL;                       /* ignore something like "1043" */
# ifdef HAVE_GET_LOCALE_VAL
      if (p == NULL || *p == NUL)
        p = (char_u *)get_locale_val(LC_CTYPE);
# endif
    }
  }
  return p;
}

#endif


/*
 * Set the "v:lang" variable according to the current locale setting.
 * Also do "v:lc_time"and "v:ctype".
 */
void set_lang_var(void)          {
  char_u      *loc;

# ifdef HAVE_GET_LOCALE_VAL
  loc = (char_u *)get_locale_val(LC_CTYPE);
# else
  /* setlocale() not supported: use the default value */
  loc = (char_u *)"C";
# endif
  set_vim_var_string(VV_CTYPE, loc, -1);

  /* When LC_MESSAGES isn't defined use the value from $LC_MESSAGES, fall
   * back to LC_CTYPE if it's empty. */
# ifdef HAVE_WORKING_LIBINTL
  loc = get_mess_env();
# else
  loc = (char_u *)get_locale_val(LC_MESSAGES);
# endif
  set_vim_var_string(VV_LANG, loc, -1);

# ifdef HAVE_GET_LOCALE_VAL
  loc = (char_u *)get_locale_val(LC_TIME);
# endif
  set_vim_var_string(VV_LC_TIME, loc, -1);
}

#ifdef HAVE_WORKING_LIBINTL
/*
 * ":language":  Set the language (locale).
 */
void ex_language(exarg_T *eap)
{
  char        *loc;
  char_u      *p;
  char_u      *name;
  int what = LC_ALL;
  char        *whatstr = "";
#ifdef LC_MESSAGES
# define VIM_LC_MESSAGES LC_MESSAGES
#else
# define VIM_LC_MESSAGES 6789
#endif

  name = eap->arg;

  /* Check for "messages {name}", "ctype {name}" or "time {name}" argument.
   * Allow abbreviation, but require at least 3 characters to avoid
   * confusion with a two letter language name "me" or "ct". */
  p = skiptowhite(eap->arg);
  if ((*p == NUL || vim_iswhite(*p)) && p - eap->arg >= 3) {
    if (STRNICMP(eap->arg, "messages", p - eap->arg) == 0) {
      what = VIM_LC_MESSAGES;
      name = skipwhite(p);
      whatstr = "messages ";
    } else if (STRNICMP(eap->arg, "ctype", p - eap->arg) == 0)   {
      what = LC_CTYPE;
      name = skipwhite(p);
      whatstr = "ctype ";
    } else if (STRNICMP(eap->arg, "time", p - eap->arg) == 0)   {
      what = LC_TIME;
      name = skipwhite(p);
      whatstr = "time ";
    }
  }

  if (*name == NUL) {
#ifdef HAVE_WORKING_LIBINTL
    if (what == VIM_LC_MESSAGES)
      p = get_mess_env();
    else
#endif
    p = (char_u *)setlocale(what, NULL);
    if (p == NULL || *p == NUL)
      p = (char_u *)"Unknown";
    smsg((char_u *)_("Current %slanguage: \"%s\""), whatstr, p);
  } else   {
#ifndef LC_MESSAGES
    if (what == VIM_LC_MESSAGES)
      loc = "";
    else
#endif
    {
      loc = setlocale(what, (char *)name);
#if defined(FEAT_FLOAT) && defined(LC_NUMERIC)
      /* Make sure strtod() uses a decimal point, not a comma. */
      setlocale(LC_NUMERIC, "C");
#endif
    }
    if (loc == NULL)
      EMSG2(_("E197: Cannot set language to \"%s\""), name);
    else {
#ifdef HAVE_NL_MSG_CAT_CNTR
      /* Need to do this for GNU gettext, otherwise cached translations
       * will be used again. */
      extern int _nl_msg_cat_cntr;

      ++_nl_msg_cat_cntr;
#endif
      /* Reset $LC_ALL, otherwise it would overrule everything. */
      vim_setenv((char_u *)"LC_ALL", (char_u *)"");

      if (what != LC_TIME) {
        /* Tell gettext() what to translate to.  It apparently doesn't
         * use the currently effective locale.  Also do this when
         * FEAT_GETTEXT isn't defined, so that shell commands use this
         * value. */
        if (what == LC_ALL) {
          vim_setenv((char_u *)"LANG", name);

          /* Clear $LANGUAGE because GNU gettext uses it. */
          vim_setenv((char_u *)"LANGUAGE", (char_u *)"");
        }
        if (what != LC_CTYPE) {
          char_u      *mname;
          mname = name;
          vim_setenv((char_u *)"LC_MESSAGES", mname);
          set_helplang_default(mname);
        }
      }

      /* Set v:lang, v:lc_time and v:ctype to the final result. */
      set_lang_var();
      maketitle();
    }
  }
}


static char_u   **locales = NULL;       /* Array of all available locales */
static int did_init_locales = FALSE;

static void init_locales(void);
static char_u **find_locales(void);

/*
 * Lazy initialization of all available locales.
 */
static void init_locales(void)                 {
  if (!did_init_locales) {
    did_init_locales = TRUE;
    locales = find_locales();
  }
}

/* Return an array of strings for all available locales + NULL for the
 * last element.  Return NULL in case of error. */
static char_u **find_locales(void)                      {
  garray_T locales_ga;
  char_u      *loc;

  /* Find all available locales by running command "locale -a".  If this
   * doesn't work we won't have completion. */
  char_u *locale_a = get_cmd_output((char_u *)"locale -a",
      NULL, SHELL_SILENT);
  if (locale_a == NULL)
    return NULL;
  ga_init2(&locales_ga, sizeof(char_u *), 20);

  /* Transform locale_a string where each locale is separated by "\n"
   * into an array of locale strings. */
  loc = (char_u *)strtok((char *)locale_a, "\n");

  while (loc != NULL) {
    if (ga_grow(&locales_ga, 1) == FAIL)
      break;
    loc = vim_strsave(loc);
    if (loc == NULL)
      break;

    ((char_u **)locales_ga.ga_data)[locales_ga.ga_len++] = loc;
    loc = (char_u *)strtok(NULL, "\n");
  }
  vim_free(locale_a);
  if (ga_grow(&locales_ga, 1) == FAIL) {
    ga_clear(&locales_ga);
    return NULL;
  }
  ((char_u **)locales_ga.ga_data)[locales_ga.ga_len] = NULL;
  return (char_u **)locales_ga.ga_data;
}

#  if defined(EXITFREE) || defined(PROTO)
void free_locales(void)          {
  int i;
  if (locales != NULL) {
    for (i = 0; locales[i] != NULL; i++)
      vim_free(locales[i]);
    vim_free(locales);
    locales = NULL;
  }
}

#  endif

/*
 * Function given to ExpandGeneric() to obtain the possible arguments of the
 * ":language" command.
 */
char_u *get_lang_arg(expand_T *xp, int idx)
{
  if (idx == 0)
    return (char_u *)"messages";
  if (idx == 1)
    return (char_u *)"ctype";
  if (idx == 2)
    return (char_u *)"time";

  init_locales();
  if (locales == NULL)
    return NULL;
  return locales[idx - 3];
}

/*
 * Function given to ExpandGeneric() to obtain the available locales.
 */
char_u *get_locales(expand_T *xp, int idx)
{
  init_locales();
  if (locales == NULL)
    return NULL;
  return locales[idx];
}

#endif
