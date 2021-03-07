// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * CSCOPE support for Vim added by Andy Kahn <kahn@zk3.dec.com>
 * Ported to Win32 by Sergey Khorev <sergey.khorev@gmail.com>
 *
 * The basic idea/structure of cscope for Vim was borrowed from Nvi.  There
 * might be a few lines of code that look similar to what Nvi has.
 */

#include <stdbool.h>

#include <assert.h>
#include <errno.h>
#include <inttypes.h>
#include <fcntl.h>

#include "nvim/buffer.h"
#include "nvim/ascii.h"
#include "nvim/if_cscope.h"
#include "nvim/charset.h"
#include "nvim/fileio.h"
#include "nvim/message.h"
#include "nvim/memory.h"
#include "nvim/os/time.h"
#include "nvim/path.h"
#include "nvim/quickfix.h"
#include "nvim/strings.h"
#include "nvim/tag.h"
#include "nvim/os/os.h"
#include "nvim/os/input.h"
#include "nvim/event/stream.h"

#include <sys/types.h>
#include <sys/stat.h>
#if defined(UNIX)
# include <sys/wait.h>
#endif
#include "nvim/if_cscope_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "if_cscope.c.generated.h"
#endif

static csinfo_T *   csinfo = NULL;
static size_t csinfo_size = 0;    // number of items allocated in csinfo[]

static int eap_arg_len;           // length of eap->arg, set in cs_lookup_cmd()
static cscmd_T cs_cmds[] =
{
  { "add",    cs_add,
    N_("Add a new database"),     "add file|dir [pre-path] [flags]", 0 },
  { "find",   cs_find,
    N_("Query for a pattern"),    "find a|c|d|e|f|g|i|s|t name", 1 },
  { "help",   cs_help,
    N_("Show this message"),      "help", 0 },
  { "kill",   cs_kill,
    N_("Kill a connection"),      "kill #", 0 },
  { "reset",  cs_reset,
    N_("Reinit all connections"), "reset", 0 },
  { "show",   cs_show,
    N_("Show connections"),       "show", 0 },
  { NULL, NULL, NULL, NULL, 0 }
};

static void cs_usage_msg(csid_e x)
{
  (void)EMSG2(_("E560: Usage: cs[cope] %s"), cs_cmds[(int)x].usage);
}


static enum {
  EXP_CSCOPE_SUBCMD,    // expand ":cscope" sub-commands
  EXP_SCSCOPE_SUBCMD,   // expand ":scscope" sub-commands
  EXP_CSCOPE_FIND,      // expand ":cscope find" arguments
  EXP_CSCOPE_KILL       // expand ":cscope kill" arguments
} expand_what;

/*
 * Function given to ExpandGeneric() to obtain the cscope command
 * expansion.
 */
char_u *get_cscope_name(expand_T *xp, int idx)
{
  int current_idx;

  switch (expand_what) {
  case EXP_CSCOPE_SUBCMD:
    // Complete with sub-commands of ":cscope":
    // add, find, help, kill, reset, show
    return (char_u *)cs_cmds[idx].name;
  case EXP_SCSCOPE_SUBCMD:
  {
    // Complete with sub-commands of ":scscope": same sub-commands as
    // ":cscope" but skip commands which don't support split windows
    int i;
    for (i = 0, current_idx = 0; cs_cmds[i].name != NULL; i++)
      if (cs_cmds[i].cansplit)
        if (current_idx++ == idx)
          break;
    return (char_u *)cs_cmds[i].name;
  }
  case EXP_CSCOPE_FIND:
  {
    const char *query_type[] =
    {
      "a", "c", "d", "e", "f", "g", "i", "s", "t", NULL
    };

    // Complete with query type of ":cscope find {query_type}".
    // {query_type} can be letters (c, d, ... a) or numbers (0, 1,
    // ..., 9) but only complete with letters, since numbers are
    // redundant.
    return (char_u *)query_type[idx];
  }
  case EXP_CSCOPE_KILL:
  {
    static char connection[5];

    // ":cscope kill" accepts connection numbers or partial names of
    // the pathname of the cscope database as argument.  Only complete
    // with connection numbers. -1 can also be used to kill all
    // connections.
    size_t i;
    for (i = 0, current_idx = 0; i < csinfo_size; i++) {
      if (csinfo[i].fname == NULL)
        continue;
      if (current_idx++ == idx) {
        vim_snprintf(connection, sizeof(connection), "%zu", i);
        return (char_u *)connection;
      }
    }
    return (current_idx == idx && idx > 0) ? (char_u *)"-1" : NULL;
  }
  default:
    return NULL;
  }
}

/*
 * Handle command line completion for :cscope command.
 */
void set_context_in_cscope_cmd(expand_T *xp, const char *arg, cmdidx_T cmdidx)
{
  // Default: expand subcommands.
  xp->xp_context = EXPAND_CSCOPE;
  xp->xp_pattern = (char_u *)arg;
  expand_what = ((cmdidx == CMD_scscope)
                 ? EXP_SCSCOPE_SUBCMD : EXP_CSCOPE_SUBCMD);

  // (part of) subcommand already typed
  if (*arg != NUL) {
    const char *p = (const char *)skiptowhite((const char_u *)arg);
    if (*p != NUL) {  // Past first word.
      xp->xp_pattern = skipwhite((const char_u *)p);
      if (*skiptowhite(xp->xp_pattern) != NUL) {
        xp->xp_context = EXPAND_NOTHING;
      } else if (STRNICMP(arg, "add", p - arg) == 0) {
        xp->xp_context = EXPAND_FILES;
      } else if (STRNICMP(arg, "kill", p - arg) == 0) {
        expand_what = EXP_CSCOPE_KILL;
      } else if (STRNICMP(arg, "find", p - arg) == 0) {
        expand_what = EXP_CSCOPE_FIND;
      } else {
        xp->xp_context = EXPAND_NOTHING;
      }
    }
  }
}


/// Find the command, print help if invalid, and then call the corresponding
/// command function.
static void
do_cscope_general(
    exarg_T *eap,
    int make_split             // whether to split window
)
{
  cscmd_T *cmdp;

  if ((cmdp = cs_lookup_cmd(eap)) == NULL) {
    cs_help(eap);
    return;
  }

  if (make_split) {
    if (!cmdp->cansplit) {
      (void)MSG_PUTS(_(
              "This cscope command does not support splitting the window.\n"));
      return;
    }
    postponed_split = -1;
    postponed_split_flags = cmdmod.split;
    postponed_split_tab = cmdmod.tab;
  }

  cmdp->func(eap);

  postponed_split_flags = 0;
  postponed_split_tab = 0;
}

/// Implementation of ":cscope" and ":lcscope"
void ex_cscope(exarg_T *eap)
{
  do_cscope_general(eap, FALSE);
}

/// Implementation of ":scscope". Same as ex_cscope(), but splits window, too.
void ex_scscope(exarg_T *eap)
{
  do_cscope_general(eap, TRUE);
}

/// Implementation of ":cstag"
void ex_cstag(exarg_T *eap)
{
  int ret = FALSE;

  if (*eap->arg == NUL) {
    (void)EMSG(_("E562: Usage: cstag <ident>"));
    return;
  }

  switch (p_csto) {
  case 0:
    if (cs_check_for_connections()) {
      ret = cs_find_common("g", (char *)(eap->arg), eap->forceit, FALSE,
          FALSE, *eap->cmdlinep);
      if (ret == FALSE) {
        cs_free_tags();
        if (msg_col)
          msg_putchar('\n');

        if (cs_check_for_tags())
          ret = do_tag(eap->arg, DT_JUMP, 0, eap->forceit, FALSE);
      }
    } else if (cs_check_for_tags()) {
      ret = do_tag(eap->arg, DT_JUMP, 0, eap->forceit, FALSE);
    }
    break;
  case 1:
    if (cs_check_for_tags()) {
      ret = do_tag(eap->arg, DT_JUMP, 0, eap->forceit, FALSE);
      if (ret == FALSE) {
        if (msg_col)
          msg_putchar('\n');

        if (cs_check_for_connections()) {
          ret = cs_find_common("g", (char *)(eap->arg), eap->forceit,
              FALSE, FALSE, *eap->cmdlinep);
          if (ret == FALSE)
            cs_free_tags();
        }
      }
    } else if (cs_check_for_connections()) {
      ret = cs_find_common("g", (char *)(eap->arg), eap->forceit, FALSE,
          FALSE, *eap->cmdlinep);
      if (ret == FALSE)
        cs_free_tags();
    }
    break;
  default:
    break;
  }

  if (!ret) {
    (void)EMSG(_("E257: cstag: tag not found"));
    g_do_tagpreview = 0;
  }
}


/// This simulates a vim_fgets(), but for cscope, returns the next line
/// from the cscope output.  should only be called from find_tags()
///
/// @return true if eof, FALSE otherwise
bool cs_fgets(char_u *buf, int size)
  FUNC_ATTR_NONNULL_ALL
{
  char *p;

  if ((p = cs_manage_matches(NULL, NULL, 0, Get)) == NULL) {
    return true;
  }
  STRLCPY(buf, p, size);

  return false;
}


/// Called only from do_tag(), when popping the tag stack.
void cs_free_tags(void)
{
  cs_manage_matches(NULL, NULL, 0, Free);
}

/// Called from do_tag().
void cs_print_tags(void)
{
  cs_manage_matches(NULL, NULL, 0, Print);
}

/*
 * "cscope_connection([{num} , {dbpath} [, {prepend}]])" function
 *
 *		Checks for the existence of a |cscope| connection.  If no
 *		parameters are specified, then the function returns:
 *
 *		0, if cscope was not available (not compiled in), or if there
 *		are no cscope connections; or
 *		1, if there is at least one cscope connection.
 *
 *		If parameters are specified, then the value of {num}
 *		determines how existence of a cscope connection is checked:
 *
 *		{num}	Description of existence check
 *		-----	------------------------------
 *		0	Same as no parameters (e.g., "cscope_connection()").
 *		1	Ignore {prepend}, and use partial string matches for
 *			{dbpath}.
 *		2	Ignore {prepend}, and use exact string matches for
 *			{dbpath}.
 *		3	Use {prepend}, use partial string matches for both
 *			{dbpath} and {prepend}.
 *		4	Use {prepend}, use exact string matches for both
 *			{dbpath} and {prepend}.
 *
 *		Note: All string comparisons are case sensitive!
 */
bool cs_connection(int num, char_u *dbpath, char_u *ppath)
{
  if (num < 0 || num > 4 || (num > 0 && !dbpath)) {
    return false;
  }

  for (size_t i = 0; i < csinfo_size; i++) {
    if (!csinfo[i].fname) {
      continue;
    }
    if (num == 0) {
      return true;
    }
    switch (num) {
    case 1:
      if (strstr(csinfo[i].fname, (char *)dbpath)) {
        return true;
      }
      break;
    case 2:
      if (strcmp(csinfo[i].fname, (char *)dbpath) == 0) {
        return true;
      }
      break;
    case 3:
      if (strstr(csinfo[i].fname, (char *)dbpath)
          && ((!ppath && !csinfo[i].ppath)
              || (ppath
                  && csinfo[i].ppath
                  && strstr(csinfo[i].ppath, (char *)ppath)))) {
        return true;
      }
      break;
    case 4:
      if ((strcmp(csinfo[i].fname, (char *)dbpath) == 0)
          && ((!ppath && !csinfo[i].ppath)
              || (ppath
                  && csinfo[i].ppath
                  && (strcmp(csinfo[i].ppath, (char *)ppath) == 0)))) {
        return true;
      }
      break;
    }
  }

  return false;
}  // cs_connection


/*
 * PRIVATE functions
 ****************************************************************************/

/// Add cscope database or a directory name (to look for cscope.out)
/// to the cscope connection list.
static int cs_add(exarg_T *eap)
{
  char *fname, *ppath, *flags = NULL;

  if ((fname = strtok((char *)NULL, (const char *)" ")) == NULL) {
    cs_usage_msg(Add);
    return CSCOPE_FAILURE;
  }
  if ((ppath = strtok((char *)NULL, (const char *)" ")) != NULL)
    flags = strtok((char *)NULL, (const char *)" ");

  return cs_add_common(fname, ppath, flags);
}

static void cs_stat_emsg(char *fname)
{
  char *stat_emsg = _("E563: stat(%s) error: %d");
  char *buf = xmalloc(strlen(stat_emsg) + MAXPATHL + 10);

  (void)sprintf(buf, stat_emsg, fname, errno);
  (void)EMSG(buf);
  xfree(buf);
}


/// The common routine to add a new cscope connection.  Called by
/// cs_add() and cs_reset().  I really don't like to do this, but this
/// routine uses a number of goto statements.
static int
cs_add_common(
    char *arg1,         // filename - may contain environment variables
    char *arg2,         // prepend path - may contain environment variables
    char *flags
)
{
  char        *fname = NULL;
  char        *fname2 = NULL;
  char        *ppath = NULL;
  size_t usedlen = 0;
  char_u      *fbuf = NULL;

  // get the filename (arg1), expand it, and try to stat it
  fname = xmalloc(MAXPATHL + 1);

  expand_env((char_u *)arg1, (char_u *)fname, MAXPATHL);
  size_t len = STRLEN(fname);
  fbuf = (char_u *)fname;
  (void)modify_fname((char_u *)":p", false, &usedlen,
                     (char_u **)&fname, &fbuf, &len);
  if (fname == NULL) {
    goto add_err;
  }
  fname = (char *)vim_strnsave((char_u *)fname, len);
  xfree(fbuf);
  FileInfo file_info;
  bool file_info_ok  = os_fileinfo(fname, &file_info);
  if (!file_info_ok) {
staterr:
    if (p_csverbose)
      cs_stat_emsg(fname);
    goto add_err;
  }

  // get the prepend path (arg2), expand it, and see if it exists
  if (arg2 != NULL) {
    ppath = xmalloc(MAXPATHL + 1);
    expand_env((char_u *)arg2, (char_u *)ppath, MAXPATHL);
    if (!os_path_exists((char_u *)ppath)) {
      goto staterr;
    }
  }

  int i;
  // if filename is a directory, append the cscope database name to it
  if (S_ISDIR(file_info.stat.st_mode)) {
    fname2 = (char *)xmalloc(strlen(CSCOPE_DBFILE) + strlen(fname) + 2);

    while (fname[strlen(fname)-1] == '/'
           ) {
      fname[strlen(fname)-1] = '\0';
      if (fname[0] == '\0')
        break;
    }
    if (fname[0] == '\0')
      (void)sprintf(fname2, "/%s", CSCOPE_DBFILE);
    else
      (void)sprintf(fname2, "%s/%s", fname, CSCOPE_DBFILE);

    file_info_ok = os_fileinfo(fname2, &file_info);
    if (!file_info_ok) {
      if (p_csverbose)
        cs_stat_emsg(fname2);
      goto add_err;
    }

    i = cs_insert_filelist(fname2, ppath, flags, &file_info);
  }
  else if (S_ISREG(file_info.stat.st_mode) || S_ISLNK(file_info.stat.st_mode))
  {
    i = cs_insert_filelist(fname, ppath, flags, &file_info);
  } else {
    if (p_csverbose)
      (void)EMSG2(
          _("E564: %s is not a directory or a valid cscope database"),
          fname);
    goto add_err;
  }

  if (i != -1) {
    assert(i >= 0);
    if (cs_create_connection((size_t)i) == CSCOPE_FAILURE
        || cs_read_prompt((size_t)i) == CSCOPE_FAILURE) {
      cs_release_csp((size_t)i, true);
      goto add_err;
    }

    if (p_csverbose) {
      msg_clr_eos();
      (void)smsg_attr(HL_ATTR(HLF_R),
                      _("Added cscope database %s"),
                      csinfo[i].fname);
    }
  }

  xfree(fname);
  xfree(fname2);
  xfree(ppath);
  return CSCOPE_SUCCESS;

add_err:
  xfree(fname2);
  xfree(fname);
  xfree(ppath);
  return CSCOPE_FAILURE;
}


static int cs_check_for_connections(void)
{
  return cs_cnt_connections() > 0;
}

static int cs_check_for_tags(void)
{
  return p_tags[0] != NUL && curbuf->b_p_tags != NULL;
}

/// Count the number of cscope connections.
static size_t cs_cnt_connections(void)
{
  size_t cnt = 0;

  for (size_t i = 0; i < csinfo_size; i++) {
    if (csinfo[i].fname != NULL)
      cnt++;
  }
  return cnt;
}

static void cs_reading_emsg(
    size_t idx        // connection index
)
{
  EMSGU(_("E262: error reading cscope connection %" PRIu64), idx);
}

#define CSREAD_BUFSIZE  2048
/// Count the number of matches for a given cscope connection.
static int cs_cnt_matches(size_t idx)
{
  char *stok;
  int nlines = 0;

  char *buf = xmalloc(CSREAD_BUFSIZE);
  for (;; ) {
    errno = 0;
    if (!fgets(buf, CSREAD_BUFSIZE, csinfo[idx].fr_fp)) {
      if (errno == EINTR) {
        continue;
      }

      if (feof(csinfo[idx].fr_fp)) {
        errno = EIO;
      }

      cs_reading_emsg(idx);

      xfree(buf);
      return CSCOPE_FAILURE;
    }

    // If the database is out of date, or there's some other problem,
    // cscope will output error messages before the number-of-lines output.
    // Display/discard any output that doesn't match what we want.
    // Accept "\S*cscope: X lines", also matches "mlcscope".
    // Bail out for the "Unable to search" error.
    if (strstr((const char *)buf, "Unable to search database") != NULL) {
        break;
    }
    if ((stok = strtok(buf, (const char *)" ")) == NULL) {
      continue;
    }
    if (strstr((const char *)stok, "cscope:") == NULL) {
      continue;
    }

    if ((stok = strtok(NULL, (const char *)" ")) == NULL)
      continue;
    nlines = atoi(stok);
    if (nlines < 0) {
      nlines = 0;
      break;
    }

    if ((stok = strtok(NULL, (const char *)" ")) == NULL)
      continue;
    if (strncmp((const char *)stok, "lines", 5))
      continue;

    break;
  }

  xfree(buf);
  return nlines;
}


/// Creates the actual cscope command query from what the user entered.
static char *cs_create_cmd(char *csoption, char *pattern)
{
  char *cmd;
  short search;
  char *pat;

  switch (csoption[0]) {
  case '0': case 's':
    search = 0;
    break;
  case '1': case 'g':
    search = 1;
    break;
  case '2': case 'd':
    search = 2;
    break;
  case '3': case 'c':
    search = 3;
    break;
  case '4': case 't':
    search = 4;
    break;
  case '6': case 'e':
    search = 6;
    break;
  case '7': case 'f':
    search = 7;
    break;
  case '8': case 'i':
    search = 8;
    break;
  case '9': case 'a':
    search = 9;
    break;
  default:
    (void)EMSG(_("E561: unknown cscope search type"));
    cs_usage_msg(Find);
    return NULL;
  }

  // Skip white space before the patter, except for text and pattern search,
  // they may want to use the leading white space.
  pat = pattern;
  if (search != 4 && search != 6)
    while (ascii_iswhite(*pat))
      ++pat;

  cmd = xmalloc(strlen(pat) + 2);

  (void)sprintf(cmd, "%d%s", search, pat);

  return cmd;
}


/// This piece of code was taken/adapted from nvi.  do we need to add
/// the BSD license notice?
static int cs_create_connection(size_t i)
{
#ifdef UNIX
  int to_cs[2], from_cs[2];
#endif
  char        *prog, *cmd, *ppath = NULL;

#if defined(UNIX)
  /*
   * Cscope reads from to_cs[0] and writes to from_cs[1]; vi reads from
   * from_cs[0] and writes to to_cs[1].
   */
  to_cs[0] = to_cs[1] = from_cs[0] = from_cs[1] = -1;
  if (pipe(to_cs) < 0 || pipe(from_cs) < 0) {
    (void)EMSG(_("E566: Could not create cscope pipes"));
err_closing:
    if (to_cs[0] != -1)
      (void)close(to_cs[0]);
    if (to_cs[1] != -1)
      (void)close(to_cs[1]);
    if (from_cs[0] != -1)
      (void)close(from_cs[0]);
    if (from_cs[1] != -1)
      (void)close(from_cs[1]);
    return CSCOPE_FAILURE;
  }

  switch (csinfo[i].pid = fork()) {
  case -1:
    (void)EMSG(_("E622: Could not fork for cscope"));
    goto err_closing;
  case 0:                               // child: run cscope.
    if (dup2(to_cs[0], STDIN_FILENO) == -1) {
      PERROR("cs_create_connection 1");
    }
    if (dup2(from_cs[1], STDOUT_FILENO) == -1) {
      PERROR("cs_create_connection 2");
    }
    if (dup2(from_cs[1], STDERR_FILENO) == -1) {
      PERROR("cs_create_connection 3");
    }

    // close unused
    (void)close(to_cs[1]);
    (void)close(from_cs[0]);
#else
  // Create pipes to communicate with cscope
  int fd;
  SECURITY_ATTRIBUTES sa;
  PROCESS_INFORMATION pi;
  BOOL pipe_stdin = FALSE, pipe_stdout = FALSE;  // NOLINT(readability/bool)
  STARTUPINFO si;
  HANDLE stdin_rd, stdout_rd;
  HANDLE stdout_wr, stdin_wr;
  BOOL created;

  sa.nLength = sizeof(SECURITY_ATTRIBUTES);
  sa.bInheritHandle = TRUE;
  sa.lpSecurityDescriptor = NULL;

  if (!(pipe_stdin = CreatePipe(&stdin_rd, &stdin_wr, &sa, 0))
      || !(pipe_stdout = CreatePipe(&stdout_rd, &stdout_wr, &sa, 0))) {
    (void)EMSG(_("E566: Could not create cscope pipes"));
err_closing:
    if (pipe_stdin) {
      CloseHandle(stdin_rd);
      CloseHandle(stdin_wr);
    }
    if (pipe_stdout) {
      CloseHandle(stdout_rd);
      CloseHandle(stdout_wr);
    }
    return CSCOPE_FAILURE;
  }
#endif
    // expand the cscope exec for env var's
    prog = xmalloc(MAXPATHL + 1);
    expand_env(p_csprg, (char_u *)prog, MAXPATHL);

    // alloc space to hold the cscope command
    size_t len = strlen(prog) + strlen(csinfo[i].fname) + 32;
    if (csinfo[i].ppath) {
      // expand the prepend path for env var's
      ppath = xmalloc(MAXPATHL + 1);
      expand_env((char_u *)csinfo[i].ppath, (char_u *)ppath, MAXPATHL);

      len += strlen(ppath);
    }

    if (csinfo[i].flags)
      len += strlen(csinfo[i].flags);

    cmd = xmalloc(len);

    // run the cscope command; is there execl for non-unix systems?
#if defined(UNIX)
    (void)snprintf(cmd, len, "exec %s -dl -f %s", prog, csinfo[i].fname);
#else
    // WIN32
    (void)snprintf(cmd, len, "%s -dl -f %s", prog, csinfo[i].fname);
#endif
    if (csinfo[i].ppath != NULL) {
      (void)strcat(cmd, " -P");
      (void)strcat(cmd, csinfo[i].ppath);
    }
    if (csinfo[i].flags != NULL) {
      (void)strcat(cmd, " ");
      (void)strcat(cmd, csinfo[i].flags);
    }
# ifdef UNIX
    // on Win32 we still need prog
    xfree(prog);
# endif
    xfree(ppath);

#if defined(UNIX)
# if defined(HAVE_SETSID) || defined(HAVE_SETPGID)
    // Change our process group to avoid cscope receiving SIGWINCH.
#  if defined(HAVE_SETSID)
    (void)setsid();
#  else
    if (setpgid(0, 0) == -1)
      PERROR(_("cs_create_connection setpgid failed"));
#  endif
# endif
    if (execl("/bin/sh", "sh", "-c", cmd, (char *)NULL) == -1)
      PERROR(_("cs_create_connection exec failed"));

    exit(127);
  // NOTREACHED
  default:      // parent.
    // Save the file descriptors for later duplication, and
    // reopen as streams.
    if ((csinfo[i].to_fp = fdopen(to_cs[1], "w")) == NULL) {
      PERROR(_("cs_create_connection: fdopen for to_fp failed"));
    }
    if ((csinfo[i].fr_fp = fdopen(from_cs[0], "r")) == NULL) {
      PERROR(_("cs_create_connection: fdopen for fr_fp failed"));
    }

    // close unused
    (void)close(to_cs[0]);
    (void)close(from_cs[1]);

    break;
  }

#else
    // WIN32
    // Create a new process to run cscope and use pipes to talk with it
    GetStartupInfo(&si);
    si.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;  // Hide child application window
    si.hStdOutput = stdout_wr;
    si.hStdError  = stdout_wr;
    si.hStdInput  = stdin_rd;
    created = CreateProcess(NULL, cmd, NULL, NULL, TRUE, CREATE_NEW_CONSOLE,
        NULL, NULL, &si, &pi);
    xfree(prog);
    xfree(cmd);

    if (!created) {
      PERROR(_("cs_create_connection exec failed"));
      (void)EMSG(_("E623: Could not spawn cscope process"));
      goto err_closing;
    }
    // else
    csinfo[i].pid = pi.dwProcessId;
    csinfo[i].hProc = pi.hProcess;
    CloseHandle(pi.hThread);

    // TODO(neovim): tidy up after failure to create files on pipe handles.
    if (((fd = _open_osfhandle((intptr_t)stdin_wr, _O_TEXT|_O_APPEND)) < 0)
        || ((csinfo[i].to_fp = _fdopen(fd, "w")) == NULL)) {
      PERROR(_("cs_create_connection: fdopen for to_fp failed"));
    }
    if (((fd = _open_osfhandle((intptr_t)stdout_rd,  _O_TEXT|_O_RDONLY)) < 0)
        || ((csinfo[i].fr_fp = _fdopen(fd, "r")) == NULL)) {
      PERROR(_("cs_create_connection: fdopen for fr_fp failed"));
    }
    // Close handles for file descriptors inherited by the cscope process.
    CloseHandle(stdin_rd);
    CloseHandle(stdout_wr);

#endif  // !UNIX

  return CSCOPE_SUCCESS;
}


/// Query cscope using command line interface.  Parse the output and use tselect
/// to allow choices.  Like Nvi, creates a pipe to send to/from query/cscope.
///
/// @return TRUE if we jump to a tag or abort, FALSE if not.
static int cs_find(exarg_T *eap)
{
  char *opt, *pat;

  if (cs_check_for_connections() == FALSE) {
    (void)EMSG(_("E567: no cscope connections"));
    return FALSE;
  }

  if ((opt = strtok((char *)NULL, (const char *)" ")) == NULL) {
    cs_usage_msg(Find);
    return FALSE;
  }

  pat = opt + strlen(opt) + 1;
  if (pat >= (char *)eap->arg + eap_arg_len) {
    cs_usage_msg(Find);
    return FALSE;
  }

  /*
   * Let's replace the NULs written by strtok() with spaces - we need the
   * spaces to correctly display the quickfix/location list window's title.
   */
  for (int i = 0; i < eap_arg_len; ++i)
    if (NUL == eap->arg[i])
      eap->arg[i] = ' ';

  return cs_find_common(opt, pat, eap->forceit, true,
                        eap->cmdidx == CMD_lcscope, *eap->cmdlinep);
}


/// Common code for cscope find, shared by cs_find() and ex_cstag().
static int cs_find_common(char *opt, char *pat, int forceit, int verbose,
                          int use_ll, char_u *cmdline)
{
  char *cmd;
  int *nummatches;
  size_t totmatches;
  char cmdletter;
  char *qfpos;

  // get cmd letter
  switch (opt[0]) {
  case '0':
    cmdletter = 's';
    break;
  case '1':
    cmdletter = 'g';
    break;
  case '2':
    cmdletter = 'd';
    break;
  case '3':
    cmdletter = 'c';
    break;
  case '4':
    cmdletter = 't';
    break;
  case '6':
    cmdletter = 'e';
    break;
  case '7':
    cmdletter = 'f';
    break;
  case '8':
    cmdletter = 'i';
    break;
  case '9':
    cmdletter = 'a';
    break;
  default:
    cmdletter = opt[0];
  }

  qfpos = (char *)vim_strchr(p_csqf, cmdletter);
  if (qfpos != NULL) {
    qfpos++;
    // next symbol must be + or -
    if (strchr(CSQF_FLAGS, *qfpos) == NULL) {
      char *nf = _("E469: invalid cscopequickfix flag %c for %c");
      // strlen will be enough because we use chars
      char *buf = xmalloc(strlen(nf));

      sprintf(buf, nf, *qfpos, *(qfpos-1));
      (void)EMSG(buf);
      xfree(buf);
      return FALSE;
    }

    if (*qfpos != '0'
        && apply_autocmds(EVENT_QUICKFIXCMDPRE, (char_u *)"cscope",
                          curbuf->b_fname, true, curbuf)) {
      if (aborting()) {
        return false;
      }
    }
  }

  // create the actual command to send to cscope
  cmd = cs_create_cmd(opt, pat);
  if (cmd == NULL)
    return FALSE;

  nummatches = xmalloc(sizeof(int) * csinfo_size);

  // Send query to all open connections, then count the total number
  // of matches so we can alloc all in one swell foop.
  for (size_t i = 0; i < csinfo_size; i++) {
    nummatches[i] = 0;
  }
  totmatches = 0;
  for (size_t i = 0; i < csinfo_size; i++) {
    if (csinfo[i].fname == NULL || csinfo[i].to_fp == NULL)
      continue;

    // send cmd to cscope
    (void)fprintf(csinfo[i].to_fp, "%s\n", cmd);
    (void)fflush(csinfo[i].to_fp);

    nummatches[i] = cs_cnt_matches(i);

    if (nummatches[i] > -1)
      totmatches += (size_t)nummatches[i];

    if (nummatches[i] == 0)
      (void)cs_read_prompt(i);
  }
  xfree(cmd);

  if (totmatches == 0) {
    char *nf = _("E259: no matches found for cscope query %s of %s");
    char *buf;

    if (!verbose) {
      xfree(nummatches);
      return FALSE;
    }

    buf = xmalloc(strlen(opt) + strlen(pat) + strlen(nf));
    sprintf(buf, nf, opt, pat);
    (void)EMSG(buf);
    xfree(buf);
    xfree(nummatches);
    return FALSE;
  }

  if (qfpos != NULL && *qfpos != '0') {
    // Fill error list.
    FILE        *f;
    char_u      *tmp = vim_tempname();
    qf_info_T   *qi = NULL;
    win_T       *wp = NULL;

    f = os_fopen((char *)tmp, "w");
    if (f == NULL) {
      EMSG2(_(e_notopen), tmp);
    } else {
      cs_file_results(f, nummatches);
      fclose(f);
      if (use_ll) {         // Use location list
        wp = curwin;
      }
      // '-' starts a new error list
      if (qf_init(wp, tmp, (char_u *)"%f%*\\t%l%*\\t%m",
                  *qfpos == '-', cmdline, NULL) > 0) {
        if (postponed_split != 0) {
          (void)win_split(postponed_split > 0 ? postponed_split : 0,
                          postponed_split_flags);
          RESET_BINDING(curwin);
          postponed_split = 0;
        }

        apply_autocmds(EVENT_QUICKFIXCMDPOST, (char_u *)"cscope",
            curbuf->b_fname, TRUE, curbuf);
        if (use_ll)
          /*
           * In the location list window, use the displayed location
           * list. Otherwise, use the location list for the window.
           */
          qi = (bt_quickfix(wp->w_buffer) && wp->w_llist_ref != NULL)
               ?  wp->w_llist_ref : wp->w_llist;
        qf_jump(qi, 0, 0, forceit);
      }
    }
    os_remove((char *)tmp);
    xfree(tmp);
    xfree(nummatches);
    return TRUE;
  } else {
    char **matches = NULL, **contexts = NULL;
    size_t matched = 0;

    // read output
    cs_fill_results((char *)pat, totmatches, nummatches, &matches,
        &contexts, &matched);
    xfree(nummatches);
    if (matches == NULL)
      return FALSE;

    (void)cs_manage_matches(matches, contexts, matched, Store);

    return do_tag((char_u *)pat, DT_CSCOPE, 0, forceit, verbose);
  }
}

/// Print help.
static int cs_help(exarg_T *eap)
{
  cscmd_T *cmdp = cs_cmds;

  (void)MSG_PUTS(_("cscope commands:\n"));
  while (cmdp->name != NULL) {
    char *help = _(cmdp->help);
    int space_cnt = 30 - vim_strsize((char_u *)help);

    // Use %*s rather than %30s to ensure proper alignment in utf-8
    if (space_cnt < 0) {
      space_cnt = 0;
    }
    (void)smsg(_("%-5s: %s%*s (Usage: %s)"),
        cmdp->name,
        help, space_cnt, " ",
        cmdp->usage);
    if (strcmp(cmdp->name, "find") == 0)
      MSG_PUTS(_("\n"
                 "       a: Find assignments to this symbol\n"
                 "       c: Find functions calling this function\n"
                 "       d: Find functions called by this function\n"
                 "       e: Find this egrep pattern\n"
                 "       f: Find this file\n"
                 "       g: Find this definition\n"
                 "       i: Find files #including this file\n"
                 "       s: Find this C symbol\n"
                 "       t: Find this text string\n"));

    cmdp++;
  }

  wait_return(TRUE);
  return CSCOPE_SUCCESS;
}


static void clear_csinfo(size_t i)
{
  csinfo[i].fname  = NULL;
  csinfo[i].ppath  = NULL;
  csinfo[i].flags  = NULL;
  csinfo[i].file_id = FILE_ID_EMPTY;
  csinfo[i].pid    = 0;
  csinfo[i].fr_fp  = NULL;
  csinfo[i].to_fp  = NULL;
}

/// Insert a new cscope database filename into the filelist.
static int cs_insert_filelist(char *fname, char *ppath, char *flags,
                              FileInfo *file_info)
{
  size_t i = 0;
  bool empty_found = false;

  for (size_t j = 0; j < csinfo_size; j++) {
    if (csinfo[j].fname != NULL
        && os_fileid_equal_fileinfo(&(csinfo[j].file_id), file_info)) {
      if (p_csverbose)
        (void)EMSG(_("E568: duplicate cscope database not added"));
      return CSCOPE_FAILURE;
    }

    if (csinfo[j].fname == NULL && !empty_found) {
      i = j;       // remember first empty entry
      empty_found = true;
    }
  }

  if (!empty_found) {
    i = csinfo_size;
    if (csinfo_size == 0) {
      // First time allocation: allocate only 1 connection. It should
      // be enough for most users.  If more is needed, csinfo will be
      // reallocated.
      csinfo_size = 1;
      csinfo = xcalloc(1, sizeof(csinfo_T));
    } else {
      // Reallocate space for more connections.
      csinfo_size *= 2;
      csinfo = xrealloc(csinfo, sizeof(csinfo_T)*csinfo_size);
    }
    for (size_t j = csinfo_size/2; j < csinfo_size; j++)
      clear_csinfo(j);
  }

  csinfo[i].fname = xmalloc(strlen(fname) + 1);

  (void)strcpy(csinfo[i].fname, (const char *)fname);

  if (ppath != NULL) {
    csinfo[i].ppath = xmalloc(strlen(ppath) + 1);
    (void)strcpy(csinfo[i].ppath, (const char *)ppath);
  } else
    csinfo[i].ppath = NULL;

  if (flags != NULL) {
    csinfo[i].flags = xmalloc(strlen(flags) + 1);
    (void)strcpy(csinfo[i].flags, (const char *)flags);
  } else
    csinfo[i].flags = NULL;

  os_fileinfo_id(file_info, &(csinfo[i].file_id));
  assert(i <= INT_MAX);
  return (int)i;
}


/// Find cscope command in command table.
static cscmd_T * cs_lookup_cmd(exarg_T *eap)
{
  cscmd_T *cmdp;
  char *stok;
  size_t len;

  if (eap->arg == NULL)
    return NULL;

  // Store length of eap->arg before it gets modified by strtok().
  eap_arg_len = (int)STRLEN(eap->arg);

  if ((stok = strtok((char *)(eap->arg), (const char *)" ")) == NULL)
    return NULL;

  len = strlen(stok);
  for (cmdp = cs_cmds; cmdp->name != NULL; ++cmdp) {
    if (strncmp((const char *)(stok), cmdp->name, len) == 0)
      return cmdp;
  }
  return NULL;
}


/// Nuke em.
static int cs_kill(exarg_T *eap)
{
  char *stok;
  int num;
  size_t i = 0;
  bool killall = false;

  if ((stok = strtok((char *)NULL, (const char *)" ")) == NULL) {
    cs_usage_msg(Kill);
    return CSCOPE_FAILURE;
  }

  // Check if string is a number, only single digit
  // positive and negative integers are allowed
  if ((strlen(stok) < 2 && ascii_isdigit((int)(stok[0])))
      || (strlen(stok) < 3 && stok[0] == '-'
          && ascii_isdigit((int)(stok[1])))) {
    num = atoi(stok);
    if (num == -1)
      killall = true;
    else if (num >= 0) {
      i = (size_t)num;
    } else {      // All negative values besides -1 are invalid.
      if (p_csverbose)
        (void)EMSG2(_("E261: cscope connection %s not found"), stok);
      return CSCOPE_FAILURE;
    }
  } else {
    // Else it must be part of a name.  We will try to find a match
    // within all the names in the csinfo data structure
    for (i = 0; i < csinfo_size; i++) {
      if (csinfo[i].fname != NULL && strstr(csinfo[i].fname, stok))
        break;
    }
  }

  if (!killall && (i >= csinfo_size || csinfo[i].fname == NULL)) {
    if (p_csverbose) {
      (void)EMSG2(_("E261: cscope connection %s not found"), stok);
    }
    return CSCOPE_FAILURE;
  } else {
    if (killall) {
      for (i = 0; i < csinfo_size; i++) {
        if (csinfo[i].fname)
          cs_kill_execute(i, csinfo[i].fname);
      }
    } else {
      cs_kill_execute((size_t)i, stok);
    }
  }

  return CSCOPE_SUCCESS;
}


/// Actually kills a specific cscope connection.
static void cs_kill_execute(
    size_t i,              // cscope table index
    char *cname        // cscope database name
)
{
  if (p_csverbose) {
    msg_clr_eos();
    (void)smsg_attr(HL_ATTR(HLF_R) | MSG_HIST,
                    _("cscope connection %s closed"), cname);
  }
  cs_release_csp(i, TRUE);
}


/// Convert the cscope output into a ctags style entry (as might be found
/// in a ctags tags file).  there's one catch though: cscope doesn't tell you
/// the type of the tag you are looking for.  for example, in Darren Hiebert's
/// ctags (the one that comes with vim), #define's use a line number to find the
/// tag in a file while function definitions use a regexp search pattern.
///
/// I'm going to always use the line number because cscope does something
/// quirky (and probably other things i don't know about):
///
///     if you have "#  define" in your source file, which is
///     perfectly legal, cscope thinks you have "#define".  this
///     will result in a failed regexp search. :(
///
/// Besides, even if this particular case didn't happen, the search pattern
/// would still have to be modified to escape all the special regular expression
/// characters to comply with ctags formatting.
static char *cs_make_vim_style_matches(char *fname, char *slno, char *search,
                                       char *tagstr)
{
  // vim style is ctags:
  //
  //        <tagstr>\t<filename>\t<linenum_or_search>"\t<extra>
  //
  // but as mentioned above, we'll always use the line number and
  // put the search pattern (if one exists) as "extra"
  //
  // buf is used as part of vim's method of handling tags, and
  // (i think) vim frees it when you pop your tags and get replaced
  // by new ones on the tag stack.
  char *buf;
  size_t amt;

  if (search != NULL) {
    amt = strlen(fname) + strlen(slno) + strlen(tagstr) + strlen(search) + 6;
    buf = xmalloc(amt);

    (void)sprintf(buf, "%s\t%s\t%s;\"\t%s", tagstr, fname, slno, search);
  } else {
    amt = strlen(fname) + strlen(slno) + strlen(tagstr) + 5;
    buf = xmalloc(amt);

    (void)sprintf(buf, "%s\t%s\t%s;\"", tagstr, fname, slno);
  }

  return buf;
}


/// This is kind of hokey, but i don't see an easy way round this.
///
/// Store: keep a ptr to the (malloc'd) memory of matches originally
/// generated from cs_find().  the matches are originally lines directly
/// from cscope output, but transformed to look like something out of a
/// ctags.  see cs_make_vim_style_matches for more details.
///
/// Get: used only from cs_fgets(), this simulates a vim_fgets() to return
/// the next line from the cscope output.  it basically keeps track of which
/// lines have been "used" and returns the next one.
///
/// Free: frees up everything and resets
///
/// Print: prints the tags
static char *cs_manage_matches(char **matches, char **contexts,
                               size_t totmatches, mcmd_e cmd)
{
  static char **mp = NULL;
  static char **cp = NULL;
  static size_t cnt = 0;
  static size_t next = 0;
  char *p = NULL;

  switch (cmd) {
  case Store:
    assert(matches != NULL);
    assert(totmatches > 0);
    if (mp != NULL || cp != NULL)
      (void)cs_manage_matches(NULL, NULL, 0, Free);
    mp = matches;
    cp = contexts;
    cnt = totmatches;
    next = 0;
    break;
  case Get:
    if (next >= cnt)
      return NULL;

    p = mp[next];
    next++;
    break;
  case Free:
    if (mp != NULL) {
      while (cnt--) {
        xfree(mp[cnt]);
        if (cp != NULL)
          xfree(cp[cnt]);
      }
      xfree(mp);
      xfree(cp);
    }
    mp = NULL;
    cp = NULL;
    cnt = 0;
    next = 0;
    break;
  case Print:
    assert(mp != NULL);
    assert(cp != NULL);
    cs_print_tags_priv(mp, cp, cnt);
    break;
  default:      // should not reach here
    IEMSG(_("E570: fatal error in cs_manage_matches"));
    return NULL;
  }

  return p;
}


/// Parse cscope output.
static char *cs_parse_results(size_t cnumber, char *buf, int bufsize,
                              char **context, char **linenumber, char **search)
{
  int ch;
  char *p;
  char *name;

retry:
  errno = 0;
  if (fgets(buf, bufsize, csinfo[cnumber].fr_fp) == NULL) {
    if (errno == EINTR) {
      goto retry;
    }

    if (feof(csinfo[cnumber].fr_fp)) {
      errno = EIO;
    }

    cs_reading_emsg(cnumber);

    return NULL;
  }

  // If the line's too long for the buffer, discard it.
  if ((p = strchr(buf, '\n')) == NULL) {
    while ((ch = getc(csinfo[cnumber].fr_fp)) != EOF && ch != '\n')
      ;
    return NULL;
  }
  *p = '\0';

  /*
   * cscope output is in the following format:
   *
   *	<filename> <context> <line number> <pattern>
   */
  if ((name = strtok((char *)buf, (const char *)" ")) == NULL)
    return NULL;
  if ((*context = strtok(NULL, (const char *)" ")) == NULL)
    return NULL;
  if ((*linenumber = strtok(NULL, (const char *)" ")) == NULL)
    return NULL;
  *search = *linenumber + strlen(*linenumber) + 1;      // +1 to skip \0

  // --- nvi ---
  // If the file is older than the cscope database, that is,
  // the database was built since the file was last modified,
  // or there wasn't a search string, use the line number.
  if (strcmp(*search, "<unknown>") == 0) {
    *search = NULL;
  }

  name = cs_resolve_file(cnumber, name);
  return name;
}

/// Write cscope find results to file.
static void cs_file_results(FILE *f, int *nummatches_a)
{
  char *search, *slno;
  char *fullname;
  char *cntx;
  char *context;

  char *buf = xmalloc(CSREAD_BUFSIZE);

  for (size_t i = 0; i < csinfo_size; i++) {
    if (nummatches_a[i] < 1)
      continue;

    for (int j = 0; j < nummatches_a[i]; j++) {
      if ((fullname = cs_parse_results(i, buf, CSREAD_BUFSIZE, &cntx,
               &slno, &search)) == NULL)
        continue;

      context = xmalloc(strlen(cntx) + 5);

      if (strcmp(cntx, "<global>")==0)
        strcpy(context, "<<global>>");
      else
        sprintf(context, "<<%s>>", cntx);

      if (search == NULL)
        fprintf(f, "%s\t%s\t%s\n", fullname, slno, context);
      else
        fprintf(f, "%s\t%s\t%s %s\n", fullname, slno, context, search);

      xfree(context);
      xfree(fullname);
    }     // for all matches

    (void)cs_read_prompt(i);
  }   // for all cscope connections
  xfree(buf);
}

/// Get parsed cscope output and calls cs_make_vim_style_matches to convert
/// into ctags format.
/// When there are no matches sets "*matches_p" to NULL.
static void cs_fill_results(char *tagstr, size_t totmatches, int *nummatches_a,
                            char ***matches_p, char ***cntxts_p,
                            size_t *matched)
{
  char *buf;
  char *search, *slno;
  size_t totsofar = 0;
  char **matches = NULL;
  char **cntxts = NULL;
  char *fullname;
  char *cntx;

  assert(totmatches > 0);

  buf = xmalloc(CSREAD_BUFSIZE);
  matches = xmalloc(sizeof(char *) * (size_t)totmatches);
  cntxts = xmalloc(sizeof(char *) * (size_t)totmatches);

  for (size_t i = 0; i < csinfo_size; i++) {
    if (nummatches_a[i] < 1)
      continue;

    for (int j = 0; j < nummatches_a[i]; j++) {
      if ((fullname = cs_parse_results(i, buf, CSREAD_BUFSIZE, &cntx,
               &slno, &search)) == NULL)
        continue;

      matches[totsofar] = cs_make_vim_style_matches(fullname, slno, search,
                                                    tagstr);

      xfree(fullname);

      if (strcmp(cntx, "<global>") == 0)
        cntxts[totsofar] = NULL;
      else {
        cntxts[totsofar] = xstrdup(cntx);
      }

      totsofar++;
    }     // for all matches

    (void)cs_read_prompt(i);
  }   // for all cscope connections

  if (totsofar == 0) {
    // No matches, free the arrays and return NULL in "*matches_p".
    XFREE_CLEAR(matches);
    XFREE_CLEAR(cntxts);
  }
  *matched = totsofar;
  *matches_p = matches;
  *cntxts_p = cntxts;

  xfree(buf);
}


// get the requested path components
static char *cs_pathcomponents(char *path)
{
  if (p_cspc == 0) {
    return path;
  }

  char *s = path + strlen(path) - 1;
  for (int i = 0; i < p_cspc; i++) {
    while (s > path && *--s != '/') {
      continue;
    }
  }
  if ((s > path && *s == '/')) {
    s++;
  }
  return s;
}

/// Print cscope output that was converted into ctags style entries.
///
/// Only called from cs_manage_matches().
///
/// @param matches     Array of cscope lines in ctags style. Every entry was
//                     produced with a format string of the form
//                          "%s\t%s\t%s;\"\t%s" or
//                          "%s\t%s\t%s;\""
//                     by cs_make_vim_style_matches().
/// @param cntxts      Context for matches.
/// @param num_matches Number of entries in matches/cntxts, always greater 0.
static void cs_print_tags_priv(char **matches, char **cntxts,
                               size_t num_matches) FUNC_ATTR_NONNULL_ALL
{
  char *globalcntx = "GLOBAL";
  char *cstag_msg = _("Cscope tag: %s");

  assert(num_matches > 0);
  assert(strcnt(matches[0], '\t') >= 2);

  char *ptag = matches[0];
  char *ptag_end = strchr(ptag, '\t');
  assert(ptag_end >= ptag);
  // NUL terminate tag string in matches[0].
  *ptag_end = NUL;

  // The "%s" in cstag_msg won't appear in the result string, so we don't need
  // extra memory for terminating NUL.
  size_t newsize = strlen(cstag_msg) + (size_t)(ptag_end - ptag);
  char *buf = xmalloc(newsize);
  size_t bufsize = newsize;  // Track available bufsize
  (void)snprintf(buf, bufsize, cstag_msg, ptag);
  MSG_PUTS_ATTR(buf, HL_ATTR(HLF_T));
  msg_clr_eos();

  // restore matches[0]
  *ptag_end = '\t';

  // Column headers for match number, line number and filename.
  MSG_PUTS_ATTR(_("\n   #   line"), HL_ATTR(HLF_T));
  msg_advance(msg_col + 2);
  MSG_PUTS_ATTR(_("filename / context / line\n"), HL_ATTR(HLF_T));

  for (size_t i = 0; i < num_matches; i++) {
    assert(strcnt(matches[i], '\t') >= 2);

    // Parse filename, line number and optional part.
    char *fname = strchr(matches[i], '\t') + 1;
    char *fname_end = strchr(fname, '\t');
    // Replace second '\t' in matches[i] with NUL to terminate fname.
    *fname_end = NUL;

    char *lno = fname_end + 1;
    char *extra = xstrchrnul(lno, '\t');
    // Ignore ;" at the end of lno.
    char *lno_end = extra - 2;
    *lno_end = NUL;
    // Do we have an optional part?
    extra = *extra ? extra + 1 : NULL;

    const char *csfmt_str = "%4zu %6s  ";
    // hopefully num_matches will be less than 10^16
    newsize = strlen(csfmt_str) + 16 + (size_t)(lno_end - lno);
    if (bufsize < newsize) {
      buf = xrealloc(buf, newsize);
      bufsize = newsize;
    }
    (void)snprintf(buf, bufsize, csfmt_str, i + 1, lno);
    MSG_PUTS_ATTR(buf, HL_ATTR(HLF_CM));
    MSG_PUTS_LONG_ATTR(cs_pathcomponents(fname), HL_ATTR(HLF_CM));

    // compute the required space for the context
    char *context = cntxts[i] ? cntxts[i] : globalcntx;

    const char *cntxformat = " <<%s>>";
    // '%s' won't appear in result string, so:
    // newsize = len(cntxformat) - 2 + len(context) + 1 (for NUL).
    newsize = strlen(context) + strlen(cntxformat) - 1;

    if (bufsize < newsize) {
      buf = xrealloc(buf, newsize);
      bufsize = newsize;
    }
    int buf_len = snprintf(buf, bufsize, cntxformat, context);
    assert(buf_len >= 0);

    // Print the context only if it fits on the same line.
    if (msg_col + buf_len >= Columns) {
      msg_putchar('\n');
    }
    msg_advance(12);
    MSG_PUTS_LONG(buf);
    msg_putchar('\n');
    if (extra != NULL) {
      msg_advance(13);
      MSG_PUTS_LONG(extra);
    }

    // restore matches[i]
    *fname_end = '\t';
    *lno_end = ';';

    if (msg_col) {
      msg_putchar('\n');
    }

    os_breakcheck();
    if (got_int) {
      got_int = false;  // don't print any more matches
      break;
    }
  }

  xfree(buf);
}

/// Read a cscope prompt (basically, skip over the ">> ").
static int cs_read_prompt(size_t i)
{
  int ch;
  char        *buf = NULL;   // buffer for possible error message from cscope
  size_t bufpos = 0;
  char   *cs_emsg = _("E609: Cscope error: %s");
  size_t cs_emsg_len = strlen(cs_emsg);
  static char *eprompt = "Press the RETURN key to continue:";
  size_t epromptlen = strlen(eprompt);

  // compute maximum allowed len for Cscope error message
  assert(IOSIZE >= cs_emsg_len);
  size_t maxlen = IOSIZE - cs_emsg_len;

  while (1) {
    while (1) {
      do {
        errno = 0;
        ch = fgetc(csinfo[i].fr_fp);
      } while (ch == EOF && errno == EINTR && ferror(csinfo[i].fr_fp));
      if (ch == EOF || ch == CSCOPE_PROMPT[0]) {
        break;
      }
      // if there is room and char is printable
      if (bufpos < maxlen - 1 && vim_isprintc(ch)) {
        // lazy buffer allocation
        if (buf == NULL) {
          buf = xmalloc(maxlen);
        }
        // append character to the message
        buf[bufpos++] = (char)ch;
        buf[bufpos] = NUL;
        if (bufpos >= epromptlen
            && strcmp(&buf[bufpos - epromptlen], eprompt) == 0) {
          // remove eprompt from buf
          buf[bufpos - epromptlen] = NUL;

          // print message to user
          (void)EMSG2(cs_emsg, buf);

          // send RETURN to cscope
          (void)putc('\n', csinfo[i].to_fp);
          (void)fflush(csinfo[i].to_fp);

          // clear buf
          bufpos = 0;
          buf[bufpos] = NUL;
        }
      }
    }

    for (size_t n = 0; n < strlen(CSCOPE_PROMPT); n++) {
      if (n > 0) {
        do {
          errno = 0;
          ch = fgetc(csinfo[i].fr_fp);
        } while (ch == EOF && errno == EINTR && ferror(csinfo[i].fr_fp));
      }
      if (ch == EOF) {
        PERROR("cs_read_prompt EOF");
        if (buf != NULL && buf[0] != NUL) {
          (void)EMSG2(cs_emsg, buf);
        } else if (p_csverbose) {
          cs_reading_emsg(i);           // don't have additional information
        }
        cs_release_csp(i, true);
        xfree(buf);
        return CSCOPE_FAILURE;
      }

      if (ch != CSCOPE_PROMPT[n]) {
        ch = EOF;
        break;
      }
    }

    if (ch == EOF) {
      continue;             // didn't find the prompt
    }
    break;                  // did find the prompt
  }

  xfree(buf);
  return CSCOPE_SUCCESS;
}

#if defined(UNIX) && defined(SIGALRM)
/*
 * Used to catch and ignore SIGALRM below.
 */
static void sig_handler(int s)
{
  // do nothing
  return;
}

#endif

/// Does the actual free'ing for the cs ptr with an optional flag of whether
/// or not to free the filename.  Called by cs_kill and cs_reset.
static void cs_release_csp(size_t i, bool freefnpp)
{
  // Trying to exit normally (not sure whether it is fit to Unix cscope)
  if (csinfo[i].to_fp != NULL) {
    (void)fputs("q\n", csinfo[i].to_fp);
    (void)fflush(csinfo[i].to_fp);
  }
#if defined(UNIX)
  {
    int waitpid_errno;
    int pstat;
    pid_t pid;

# if defined(HAVE_SIGACTION)
    struct sigaction sa, old;

    // Use sigaction() to limit the waiting time to two seconds.
    sigemptyset(&sa.sa_mask);
    sa.sa_handler = sig_handler;
#  ifdef SA_NODEFER
    sa.sa_flags = SA_NODEFER;
#  else
    sa.sa_flags = 0;
#  endif
    sigaction(SIGALRM, &sa, &old);
    alarm(2);     // 2 sec timeout

    // Block until cscope exits or until timer expires
    pid = waitpid(csinfo[i].pid, &pstat, 0);
    waitpid_errno = errno;

    // cancel pending alarm if still there and restore signal
    alarm(0);
    sigaction(SIGALRM, &old, NULL);
# else
    int waited;

    // Can't use sigaction(), loop for two seconds.  First yield the CPU
    // to give cscope a chance to exit quickly.
    sleep(0);
    for (waited = 0; waited < 40; ++waited) {
      pid = waitpid(csinfo[i].pid, &pstat, WNOHANG);
      waitpid_errno = errno;
      if (pid != 0) {
        break;          // break unless the process is still running
      }
      os_delay(50L, false);       // sleep 50 ms
    }
# endif
    /*
     * If the cscope process is still running: kill it.
     * Safety check: If the PID would be zero here, the entire X session
     * would be killed.  -1 and 1 are dangerous as well.
     */
    if (pid < 0 && csinfo[i].pid > 1) {
# ifdef ECHILD
      bool alive = true;

      if (waitpid_errno == ECHILD) {
        /*
         * When using 'vim -g', vim is forked and cscope process is
         * no longer a child process but a sibling.  So waitpid()
         * fails with errno being ECHILD (No child processes).
         * Don't send SIGKILL to cscope immediately but wait
         * (polling) for it to exit normally as result of sending
         * the "q" command, hence giving it a chance to clean up
         * its temporary files.
         */
        int waited;

        sleep(0);
        for (waited = 0; waited < 40; waited++) {
          // Check whether cscope process is still alive
          if (kill(csinfo[i].pid, 0) != 0) {
            alive = false;             // cscope process no longer exists
            break;
          }
          os_delay(50L, false);  // sleep 50 ms
        }
      }
      if (alive)
# endif
      {
        kill(csinfo[i].pid, SIGKILL);
        (void)waitpid(csinfo[i].pid, &pstat, 0);
      }
    }
  }
#else  // !UNIX
  if (csinfo[i].hProc != NULL) {
    // Give cscope a chance to exit normally
    if (WaitForSingleObject(csinfo[i].hProc, 1000) == WAIT_TIMEOUT) {
      TerminateProcess(csinfo[i].hProc, 0);
    }
    CloseHandle(csinfo[i].hProc);
  }
#endif

  if (csinfo[i].fr_fp != NULL)
    (void)fclose(csinfo[i].fr_fp);
  if (csinfo[i].to_fp != NULL)
    (void)fclose(csinfo[i].to_fp);

  if (freefnpp) {
    xfree(csinfo[i].fname);
    xfree(csinfo[i].ppath);
    xfree(csinfo[i].flags);
  }

  clear_csinfo(i);
}


/// Calls cs_kill on all cscope connections then reinits.
static int cs_reset(exarg_T *eap)
{
  char        **dblist = NULL, **pplist = NULL, **fllist = NULL;
  char buf[25];  // for snprintf " (#%zu)"

  if (csinfo_size == 0)
    return CSCOPE_SUCCESS;

  // malloc our db and ppath list
  dblist = xmalloc(csinfo_size * sizeof(char *));
  pplist = xmalloc(csinfo_size * sizeof(char *));
  fllist = xmalloc(csinfo_size * sizeof(char *));

  for (size_t i = 0; i < csinfo_size; i++) {
    dblist[i] = csinfo[i].fname;
    pplist[i] = csinfo[i].ppath;
    fllist[i] = csinfo[i].flags;
    if (csinfo[i].fname != NULL)
      cs_release_csp(i, FALSE);
  }

  // rebuild the cscope connection list
  for (size_t i = 0; i < csinfo_size; i++) {
    if (dblist[i] != NULL) {
      cs_add_common(dblist[i], pplist[i], fllist[i]);
      if (p_csverbose) {
        // don't use smsg_attr() because we want to display the
        // connection number in the same line as
        // "Added cscope database..."
        snprintf(buf, ARRAY_SIZE(buf), " (#%zu)", i);
        MSG_PUTS_ATTR(buf, HL_ATTR(HLF_R));
      }
    }
    xfree(dblist[i]);
    xfree(pplist[i]);
    xfree(fllist[i]);
  }
  xfree(dblist);
  xfree(pplist);
  xfree(fllist);

  if (p_csverbose) {
    msg_attr(_("All cscope databases reset"), HL_ATTR(HLF_R) | MSG_HIST);
  }
  return CSCOPE_SUCCESS;
}


/// Construct the full pathname to a file found in the cscope database.
/// (Prepends ppath, if there is one and if it's not already prepended,
/// otherwise just uses the name found.)
///
/// We need to prepend the prefix because on some cscope's (e.g., the one that
/// ships with Solaris 2.6), the output never has the prefix prepended.
/// Contrast this with my development system (Digital Unix), which does.
static char *cs_resolve_file(size_t i, char *name)
{
  char        *fullname;
  char_u      *csdir = NULL;

  /*
   * Ppath is freed when we destroy the cscope connection.
   * Fullname is freed after cs_make_vim_style_matches, after it's been
   * copied into the tag buffer used by Vim.
   */
  size_t len = strlen(name) + 2;
  if (csinfo[i].ppath != NULL) {
    len += strlen(csinfo[i].ppath);
  } else if (p_csre && csinfo[i].fname != NULL) {
    // If 'cscoperelative' is set and ppath is not set, use cscope.out
    // path in path resolution.
    csdir = xmalloc(MAXPATHL);
    STRLCPY(csdir, csinfo[i].fname,
        path_tail((char_u *)csinfo[i].fname)
        - (char_u *)csinfo[i].fname + 1);
    len += STRLEN(csdir);
  }

  // Note/example: this won't work if the cscope output already starts
  // "../.." and the prefix path is also "../..".  if something like this
  // happens, you are screwed up and need to fix how you're using cscope.
  if (csinfo[i].ppath != NULL
      && (strncmp(name, csinfo[i].ppath, strlen(csinfo[i].ppath)) != 0)
      && (name[0] != '/')
      ) {
    fullname = xmalloc(len);
    (void)sprintf(fullname, "%s/%s", csinfo[i].ppath, name);
  } else if (csdir != NULL && csinfo[i].fname != NULL && *csdir != NUL) {
    // Check for csdir to be non empty to avoid empty path concatenated to
    // cscope output.
    fullname = concat_fnames((char *)csdir, name, true);
  } else {
    fullname = xstrdup(name);
  }

  xfree(csdir);
  return fullname;
}


/// Show all cscope connections.
static int cs_show(exarg_T *eap)
{
  if (cs_cnt_connections() == 0)
    MSG_PUTS(_("no cscope connections\n"));
  else {
    MSG_PUTS_ATTR(
        _(" # pid    database name                       prepend path\n"),
        HL_ATTR(HLF_T));
    for (size_t i = 0; i < csinfo_size; i++) {
      if (csinfo[i].fname == NULL)
        continue;

      if (csinfo[i].ppath != NULL) {
        (void)smsg("%2zu %-5" PRId64 "  %-34s  %-32s", i,
                   (int64_t)csinfo[i].pid, csinfo[i].fname, csinfo[i].ppath);
      } else {
        (void)smsg("%2zu %-5" PRId64 "  %-34s  <none>", i,
                   (int64_t)csinfo[i].pid, csinfo[i].fname);
      }
    }
  }

  wait_return(TRUE);
  return CSCOPE_SUCCESS;
}


/// Only called when VIM exits to quit any cscope sessions.
void cs_end(void)
{
  for (size_t i = 0; i < csinfo_size; i++)
    cs_release_csp(i, true);
  xfree(csinfo);
  csinfo_size = 0;
}

// the end
