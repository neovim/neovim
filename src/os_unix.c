/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *	      OS/2 port by Paul Slootman
 *	      VMS merge by Zoltan Arpadffy
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * os_unix.c -- code for all flavors of Unix (BSD, SYSV, SVR4, POSIX, ...)
 *	     Also for OS/2, using the excellent EMX package!!!
 *	     Also for BeOS and Atari MiNT.
 *
 * A lot of this file was originally written by Juergen Weigert and later
 * changed beyond recognition.
 */

/*
 * Some systems have a prototype for select() that has (int *) instead of
 * (fd_set *), which is wrong. This define removes that prototype. We define
 * our own prototype below.
 * Don't use it for the Mac, it causes a warning for precompiled headers.
 * TODO: use a configure check for precompiled headers?
 */
# define select select_declared_wrong

#include "vim.h"
#include "os_unix.h"
#include "buffer.h"
#include "charset.h"
#include "eval.h"
#include "ex_cmds.h"
#include "fileio.h"
#include "getchar.h"
#include "main.h"
#include "mbyte.h"
#include "memline.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"
#include "garray.h"
#include "screen.h"
#include "syntax.h"
#include "term.h"
#include "ui.h"
#include "os/os.h"

#include "os_unixx.h"       /* unix includes for os_unix.c only */

#ifdef HAVE_SELINUX
# include <selinux/selinux.h>
static int selinux_enabled = -1;
#endif

/*
 * Use this prototype for select, some include files have a wrong prototype
 */
# undef select


#if defined(HAVE_SELECT)
extern int select(int, fd_set *, fd_set *, fd_set *, struct timeval *);
#endif



/*
 * end of autoconf section. To be extended...
 */

/* Are the following #ifdefs still required? And why? Is that for X11? */

#if defined(ESIX) || defined(M_UNIX) && !defined(SCO)
# ifdef SIGWINCH
#  undef SIGWINCH
# endif
# ifdef TIOCGWINSZ
#  undef TIOCGWINSZ
# endif
#endif

#if defined(SIGWINDOW) && !defined(SIGWINCH)    /* hpux 9.01 has it */
# define SIGWINCH SIGWINDOW
#endif


static int get_x11_title(int);
static int get_x11_icon(int);

static char_u   *oldtitle = NULL;
static int did_set_title = FALSE;
static char_u   *oldicon = NULL;
static int did_set_icon = FALSE;

static void may_core_dump(void);

#ifdef HAVE_UNION_WAIT
typedef union wait waitstatus;
#else
typedef int waitstatus;
#endif
static pid_t wait4pid(pid_t, waitstatus *);

static int WaitForChar(long);
static int RealWaitForChar(int, long, int *);


static void handle_resize(void);

#if defined(SIGWINCH)
static RETSIGTYPE sig_winch SIGPROTOARG;
#endif
#if defined(SIGINT)
static RETSIGTYPE catch_sigint SIGPROTOARG;
#endif
#if defined(SIGPWR)
static RETSIGTYPE catch_sigpwr SIGPROTOARG;
#endif
static RETSIGTYPE deathtrap SIGPROTOARG;

static void catch_int_signal(void);
static void set_signals(void);
static void catch_signals
    (RETSIGTYPE (*func_deadly)(), RETSIGTYPE (*func_other)());
static int have_wildcard(int, char_u **);
static int have_dollars(int, char_u **);

static int save_patterns(int num_pat, char_u **pat, int *num_file,
                         char_u ***file);

#ifndef SIG_ERR
# define SIG_ERR        ((RETSIGTYPE (*)())-1)
#endif

/* volatile because it is used in signal handler sig_winch(). */
static volatile int do_resize = FALSE;
static char_u   *extra_shell_arg = NULL;
static int show_shell_mess = TRUE;
/* volatile because it is used in signal handler deathtrap(). */
static volatile int deadly_signal = 0;      /* The signal we caught */
/* volatile because it is used in signal handler deathtrap(). */
static volatile int in_mch_delay = FALSE;    /* sleeping in mch_delay() */

static int curr_tmode = TMODE_COOK;     /* contains current terminal mode */


#ifdef SYS_SIGLIST_DECLARED
/*
 * I have seen
 *  extern char *_sys_siglist[NSIG];
 * on Irix, Linux, NetBSD and Solaris. It contains a nice list of strings
 * that describe the signals. That is nearly what we want here.  But
 * autoconf does only check for sys_siglist (without the underscore), I
 * do not want to change everything today.... jw.
 * This is why AC_DECL_SYS_SIGLIST is commented out in configure.in
 */
#endif

static struct signalinfo {
  int sig;              /* Signal number, eg. SIGSEGV etc */
  char    *name;        /* Signal name (not char_u!). */
  char deadly;          /* Catch as a deadly signal? */
} signal_info[] =
{
#ifdef SIGHUP
  {SIGHUP,        "HUP",      TRUE},
#endif
#ifdef SIGQUIT
  {SIGQUIT,       "QUIT",     TRUE},
#endif
#ifdef SIGILL
  {SIGILL,        "ILL",      TRUE},
#endif
#ifdef SIGTRAP
  {SIGTRAP,       "TRAP",     TRUE},
#endif
#ifdef SIGABRT
  {SIGABRT,       "ABRT",     TRUE},
#endif
#ifdef SIGEMT
  {SIGEMT,        "EMT",      TRUE},
#endif
#ifdef SIGFPE
  {SIGFPE,        "FPE",      TRUE},
#endif
#ifdef SIGBUS
  {SIGBUS,        "BUS",      TRUE},
#endif
#if defined(SIGSEGV)
  /* MzScheme uses SEGV in its garbage collector */
  {SIGSEGV,       "SEGV",     TRUE},
#endif
#ifdef SIGSYS
  {SIGSYS,        "SYS",      TRUE},
#endif
#ifdef SIGALRM
  {SIGALRM,       "ALRM",     FALSE},   /* Perl's alarm() can trigger it */
#endif
#ifdef SIGTERM
  {SIGTERM,       "TERM",     TRUE},
#endif
#if defined(SIGVTALRM)
  {SIGVTALRM,     "VTALRM",   TRUE},
#endif
#if defined(SIGPROF) && !defined(WE_ARE_PROFILING)
  /* MzScheme uses SIGPROF for its own needs; On Linux with profiling
   * this makes Vim exit.  WE_ARE_PROFILING is defined in Makefile.  */
  {SIGPROF,       "PROF",     TRUE},
#endif
#ifdef SIGXCPU
  {SIGXCPU,       "XCPU",     TRUE},
#endif
#ifdef SIGXFSZ
  {SIGXFSZ,       "XFSZ",     TRUE},
#endif
#ifdef SIGUSR1
  {SIGUSR1,       "USR1",     TRUE},
#endif
#if defined(SIGUSR2) && !defined(FEAT_SYSMOUSE)
  /* Used for sysmouse handling */
  {SIGUSR2,       "USR2",     TRUE},
#endif
#ifdef SIGINT
  {SIGINT,        "INT",      FALSE},
#endif
#ifdef SIGWINCH
  {SIGWINCH,      "WINCH",    FALSE},
#endif
#ifdef SIGTSTP
  {SIGTSTP,       "TSTP",     FALSE},
#endif
#ifdef SIGPIPE
  {SIGPIPE,       "PIPE",     FALSE},
#endif
  {-1,            "Unknown!", FALSE}
};

/*
 * Write s[len] to the screen.
 */
void mch_write(char_u *s, int len)
{
  ignored = (int)write(1, (char *)s, len);
  if (p_wd)             /* Unix is too fast, slow down a bit more */
    RealWaitForChar(read_cmd_fd, p_wd, NULL);
}

/*
 * mch_inchar(): low level input function.
 * Get a characters from the keyboard.
 * Return the number of characters that are available.
 * If wtime == 0 do not wait for characters.
 * If wtime == n wait a short time for characters.
 * If wtime == -1 wait forever for characters.
 */
int mch_inchar(
        char_u      *buf,
        int maxlen,
        long wtime,                 /* don't use "time", MIPS cannot handle it */
        int tb_change_cnt
        )
{
    int len;


    /* Check if window changed size while we were busy, perhaps the ":set
     * columns=99" command was used. */
    while (do_resize)
        handle_resize();

    if (wtime >= 0) {
        while (WaitForChar(wtime) == 0) {           /* no character available */
            if (!do_resize)           /* return if not interrupted by resize */
                return 0;
            handle_resize();
        }
    } else   {    /* wtime == -1 */
        /*
         * If there is no character available within 'updatetime' seconds
         * flush all the swap files to disk.
         * Also done when interrupted by SIGWINCH.
         */
        if (WaitForChar(p_ut) == 0) {
            if (trigger_cursorhold() && maxlen >= 3
                    && !typebuf_changed(tb_change_cnt)) {
                buf[0] = K_SPECIAL;
                buf[1] = KS_EXTRA;
                buf[2] = (int)KE_CURSORHOLD;
                return 3;
            }
            before_blocking();
        }
    }

    for (;; ) {   /* repeat until we got a character */
        while (do_resize)        /* window changed size */
            handle_resize();

        /*
         * We want to be interrupted by the winch signal
         * or by an event on the monitored file descriptors.
         */
        if (WaitForChar(-1L) == 0) {
            if (do_resize)                /* interrupted by SIGWINCH signal */
                handle_resize();
            return 0;
        }

        /* If input was put directly in typeahead buffer bail out here. */
        if (typebuf_changed(tb_change_cnt))
            return 0;

        /*
         * For some terminals we only get one character at a time.
         * We want the get all available characters, so we could keep on
         * trying until none is available
         * For some other terminals this is quite slow, that's why we don't do
         * it.
         */
        len = read_from_input_buf(buf, (long)maxlen);
        if (len > 0) {
            return len;
        }
    }
}

static void handle_resize()                 {
  do_resize = FALSE;
  shell_resized();
}

/*
 * return non-zero if a character is available
 */
int mch_char_avail()         {
  return WaitForChar(0L);
}

void mch_delay(long msec, int ignoreinput)
{
  int old_tmode;

  if (ignoreinput) {
    /* Go to cooked mode without echo, to allow SIGINT interrupting us
     * here.  But we don't want QUIT to kill us (CTRL-\ used in a
     * shell may produce SIGQUIT). */
    in_mch_delay = TRUE;
    old_tmode = curr_tmode;
    if (curr_tmode == TMODE_RAW)
      settmode(TMODE_SLEEP);

    /*
     * Everybody sleeps in a different way...
     * Prefer nanosleep(), some versions of usleep() can only sleep up to
     * one second.
     */
#ifdef HAVE_NANOSLEEP
    {
      struct timespec ts;

      ts.tv_sec = msec / 1000;
      ts.tv_nsec = (msec % 1000) * 1000000;
      (void)nanosleep(&ts, NULL);
    }
#else
# ifdef HAVE_USLEEP
    while (msec >= 1000) {
      usleep((unsigned int)(999 * 1000));
      msec -= 999;
    }
    usleep((unsigned int)(msec * 1000));
# else
#  ifndef HAVE_SELECT
    poll(NULL, 0, (int)msec);
#  else
    {
      struct timeval tv;

      tv.tv_sec = msec / 1000;
      tv.tv_usec = (msec % 1000) * 1000;
      /*
       * NOTE: Solaris 2.6 has a bug that makes select() hang here.  Get
       * a patch from Sun to fix this.  Reported by Gunnar Pedersen.
       */
      select(0, NULL, NULL, NULL, &tv);
    }
#  endif /* HAVE_SELECT */
# endif /* HAVE_NANOSLEEP */
#endif /* HAVE_USLEEP */

    settmode(old_tmode);
    in_mch_delay = FALSE;
  } else
    WaitForChar(msec);
}

#if defined(HAVE_SIGALTSTACK) || defined(HAVE_SIGSTACK)
/*
 * Support for using the signal stack.
 * This helps when we run out of stack space, which causes a SIGSEGV.  The
 * signal handler then must run on another stack, since the normal stack is
 * completely full.
 */


#ifndef SIGSTKSZ
# define SIGSTKSZ 8000    /* just a guess of how much stack is needed... */
#endif

# ifdef HAVE_SIGALTSTACK
static stack_t sigstk;                  /* for sigaltstack() */
# else
static struct sigstack sigstk;          /* for sigstack() */
# endif

static void init_signal_stack(void);
static char *signal_stack;

static void init_signal_stack()                 {
  if (signal_stack != NULL) {
# ifdef HAVE_SIGALTSTACK
    sigstk.ss_sp = signal_stack;
    sigstk.ss_size = SIGSTKSZ;
    sigstk.ss_flags = 0;
    (void)sigaltstack(&sigstk, NULL);
# else
    sigstk.ss_sp = signal_stack;
    if (stack_grows_downwards)
      sigstk.ss_sp += SIGSTKSZ - 1;
    sigstk.ss_onstack = 0;
    (void)sigstack(&sigstk, NULL);
# endif
  }
}

#endif

/*
 * We need correct prototypes for a signal function, otherwise mean compilers
 * will barf when the second argument to signal() is ``wrong''.
 * Let me try it with a few tricky defines from my own osdef.h	(jw).
 */
#if defined(SIGWINCH)
static RETSIGTYPE
sig_winch SIGDEFARG(sigarg) {
  /* this is not required on all systems, but it doesn't hurt anybody */
  signal(SIGWINCH, (RETSIGTYPE (*)())sig_winch);
  do_resize = TRUE;
  SIGRETURN;
}

#endif

#if defined(SIGINT)
static RETSIGTYPE
catch_sigint SIGDEFARG(sigarg) {
  /* this is not required on all systems, but it doesn't hurt anybody */
  signal(SIGINT, (RETSIGTYPE (*)())catch_sigint);
  got_int = TRUE;
  SIGRETURN;
}

#endif

#if defined(SIGPWR)
static RETSIGTYPE
catch_sigpwr SIGDEFARG(sigarg) {
  /* this is not required on all systems, but it doesn't hurt anybody */
  signal(SIGPWR, (RETSIGTYPE (*)())catch_sigpwr);
  /*
   * I'm not sure we get the SIGPWR signal when the system is really going
   * down or when the batteries are almost empty.  Just preserve the swap
   * files and don't exit, that can't do any harm.
   */
  ml_sync_all(FALSE, FALSE);
  SIGRETURN;
}

#endif

#if (defined(HAVE_SETJMP_H) && defined(FEAT_LIBCALL)) || defined(PROTO)
/*
 * A simplistic version of setjmp() that only allows one level of using.
 * Don't call twice before calling mch_endjmp()!.
 * Usage:
 *	mch_startjmp();
 *	if (SETJMP(lc_jump_env) != 0)
 *	{
 *	    mch_didjmp();
 *	    EMSG("crash!");
 *	}
 *	else
 *	{
 *	    do_the_work;
 *	    mch_endjmp();
 *	}
 * Note: Can't move SETJMP() here, because a function calling setjmp() must
 * not return before the saved environment is used.
 * Returns OK for normal return, FAIL when the protected code caused a
 * problem and LONGJMP() was used.
 */
void mch_startjmp()          {
#ifdef SIGHASARG
  lc_signal = 0;
#endif
  lc_active = TRUE;
}

void mch_endjmp()          {
  lc_active = FALSE;
}

void mch_didjmp()          {
# if defined(HAVE_SIGALTSTACK) || defined(HAVE_SIGSTACK)
  /* On FreeBSD the signal stack has to be reset after using siglongjmp(),
   * otherwise catching the signal only works once. */
  init_signal_stack();
# endif
}

#endif

/*
 * This function handles deadly signals.
 * It tries to preserve any swap files and exit properly.
 * (partly from Elvis).
 * NOTE: Avoid unsafe functions, such as allocating memory, they can result in
 * a deadlock.
 */
static RETSIGTYPE
deathtrap SIGDEFARG(sigarg) {
  static int entered = 0;           /* count the number of times we got here.
                                       Note: when memory has been corrupted
                                       this may get an arbitrary value! */
#ifdef SIGHASARG
  int i;
#endif

#if defined(HAVE_SETJMP_H)
  /*
   * Catch a crash in protected code.
   * Restores the environment saved in lc_jump_env, which looks like
   * SETJMP() returns 1.
   */
  if (lc_active) {
# if defined(SIGHASARG)
    lc_signal = sigarg;
# endif
    lc_active = FALSE;          /* don't jump again */
    LONGJMP(lc_jump_env, 1);
    /* NOTREACHED */
  }
#endif

#ifdef SIGHASARG
# ifdef SIGQUIT
  /* While in mch_delay() we go to cooked mode to allow a CTRL-C to
   * interrupt us.  But in cooked mode we may also get SIGQUIT, e.g., when
   * pressing CTRL-\, but we don't want Vim to exit then. */
  if (in_mch_delay && sigarg == SIGQUIT)
    SIGRETURN;
# endif

  /* When SIGHUP, SIGQUIT, etc. are blocked: postpone the effect and return
   * here.  This avoids that a non-reentrant function is interrupted, e.g.,
   * free().  Calling free() again may then cause a crash. */
  if (entered == 0
      && (0
# ifdef SIGHUP
          || sigarg == SIGHUP
# endif
# ifdef SIGQUIT
          || sigarg == SIGQUIT
# endif
# ifdef SIGTERM
          || sigarg == SIGTERM
# endif
# ifdef SIGPWR
          || sigarg == SIGPWR
# endif
# ifdef SIGUSR1
          || sigarg == SIGUSR1
# endif
# ifdef SIGUSR2
          || sigarg == SIGUSR2
# endif
          )
      && !vim_handle_signal(sigarg))
    SIGRETURN;
#endif

  /* Remember how often we have been called. */
  ++entered;

  /* Set the v:dying variable. */
  set_vim_var_nr(VV_DYING, (long)entered);

#ifdef SIGHASARG
  /* try to find the name of this signal */
  for (i = 0; signal_info[i].sig != -1; i++)
    if (sigarg == signal_info[i].sig)
      break;
  deadly_signal = sigarg;
#endif

  full_screen = FALSE;          /* don't write message to the GUI, it might be
                                 * part of the problem... */
  /*
   * If something goes wrong after entering here, we may get here again.
   * When this happens, give a message and try to exit nicely (resetting the
   * terminal mode, etc.)
   * When this happens twice, just exit, don't even try to give a message,
   * stack may be corrupt or something weird.
   * When this still happens again (or memory was corrupted in such a way
   * that "entered" was clobbered) use _exit(), don't try freeing resources.
   */
  if (entered >= 3) {
    reset_signals();            /* don't catch any signals anymore */
    may_core_dump();
    if (entered >= 4)
      _exit(8);
    exit(7);
  }
  if (entered == 2) {
    /* No translation, it may call malloc(). */
    OUT_STR("Vim: Double signal, exiting\n");
    out_flush();
    getout(1);
  }

  /* No translation, it may call malloc(). */
#ifdef SIGHASARG
  sprintf((char *)IObuff, "Vim: Caught deadly signal %s\n",
      signal_info[i].name);
#else
  sprintf((char *)IObuff, "Vim: Caught deadly signal\n");
#endif

  /* Preserve files and exit.  This sets the really_exiting flag to prevent
   * calling free(). */
  preserve_exit();


  SIGRETURN;
}

#if defined(_REENTRANT) && defined(SIGCONT)
/*
 * On Solaris with multi-threading, suspending might not work immediately.
 * Catch the SIGCONT signal, which will be used as an indication whether the
 * suspending has been done or not.
 *
 * On Linux, signal is not always handled immediately either.
 * See https://bugs.launchpad.net/bugs/291373
 *
 * volatile because it is used in signal handler sigcont_handler().
 */
static volatile int sigcont_received;
static RETSIGTYPE sigcont_handler SIGPROTOARG;

/*
 * signal handler for SIGCONT
 */
static RETSIGTYPE
sigcont_handler SIGDEFARG(sigarg) {
  sigcont_received = TRUE;
  SIGRETURN;
}

#endif


/*
 * If the machine has job control, use it to suspend the program,
 * otherwise fake it by starting a new shell.
 */
void mch_suspend()          {
  /* BeOS does have SIGTSTP, but it doesn't work. */
#if defined(SIGTSTP) && !defined(__BEOS__)
  out_flush();              /* needed to make cursor visible on some systems */
  settmode(TMODE_COOK);
  out_flush();              /* needed to disable mouse on some systems */


# if defined(_REENTRANT) && defined(SIGCONT)
  sigcont_received = FALSE;
# endif
  kill(0, SIGTSTP);         /* send ourselves a STOP signal */
# if defined(_REENTRANT) && defined(SIGCONT)
  /*
   * Wait for the SIGCONT signal to be handled. It generally happens
   * immediately, but somehow not all the time. Do not call pause()
   * because there would be race condition which would hang Vim if
   * signal happened in between the test of sigcont_received and the
   * call to pause(). If signal is not yet received, call sleep(0)
   * to just yield CPU. Signal should then be received. If somehow
   * it's still not received, sleep 1, 2, 3 ms. Don't bother waiting
   * further if signal is not received after 1+2+3+4 ms (not expected
   * to happen).
   */
  {
    long wait_time;
    for (wait_time = 0; !sigcont_received && wait_time <= 3L; wait_time++)
      /* Loop is not entered most of the time */
      mch_delay(wait_time, FALSE);
  }
# endif

  /*
   * Set oldtitle to NULL, so the current title is obtained again.
   */
  vim_free(oldtitle);
  oldtitle = NULL;
  settmode(TMODE_RAW);
  need_check_timestamps = TRUE;
  did_check_timestamps = FALSE;
#else
  suspend_shell();
#endif
}

void mch_init()          {
  Columns = 80;
  Rows = 24;

  out_flush();
  set_signals();

#ifdef MACOS_CONVERT
  mac_conv_init();
#endif
}

static void set_signals()                 {
#if defined(SIGWINCH)
  /*
   * WINDOW CHANGE signal is handled with sig_winch().
   */
  signal(SIGWINCH, (RETSIGTYPE (*)())sig_winch);
#endif

  /*
   * We want the STOP signal to work, to make mch_suspend() work.
   * For "rvim" the STOP signal is ignored.
   */
#ifdef SIGTSTP
  signal(SIGTSTP, restricted ? SIG_IGN : SIG_DFL);
#endif
#if defined(_REENTRANT) && defined(SIGCONT)
  signal(SIGCONT, sigcont_handler);
#endif

  /*
   * We want to ignore breaking of PIPEs.
   */
#ifdef SIGPIPE
  signal(SIGPIPE, SIG_IGN);
#endif

#ifdef SIGINT
  catch_int_signal();
#endif

  /*
   * Ignore alarm signals (Perl's alarm() generates it).
   */
#ifdef SIGALRM
  signal(SIGALRM, SIG_IGN);
#endif

  /*
   * Catch SIGPWR (power failure?) to preserve the swap files, so that no
   * work will be lost.
   */
#ifdef SIGPWR
  signal(SIGPWR, (RETSIGTYPE (*)())catch_sigpwr);
#endif

  /*
   * Arrange for other signals to gracefully shutdown Vim.
   */
  catch_signals(deathtrap, SIG_ERR);

}

#if defined(SIGINT) || defined(PROTO)
/*
 * Catch CTRL-C (only works while in Cooked mode).
 */
static void catch_int_signal()                 {
  signal(SIGINT, (RETSIGTYPE (*)())catch_sigint);
}

#endif

void reset_signals()          {
  catch_signals(SIG_DFL, SIG_DFL);
#if defined(_REENTRANT) && defined(SIGCONT)
  /* SIGCONT isn't in the list, because its default action is ignore */
  signal(SIGCONT, SIG_DFL);
#endif
}

static void catch_signals(
        RETSIGTYPE (*func_deadly)(),
        RETSIGTYPE (*func_other)()
        )
{
  int i;

  for (i = 0; signal_info[i].sig != -1; i++)
    if (signal_info[i].deadly) {
#if defined(HAVE_SIGALTSTACK) && defined(HAVE_SIGACTION)
      struct sigaction sa;

      /* Setup to use the alternate stack for the signal function. */
      sa.sa_handler = func_deadly;
      sigemptyset(&sa.sa_mask);
# if defined(__linux__) && defined(_REENTRANT)
      /* On Linux, with glibc compiled for kernel 2.2, there is a bug in
       * thread handling in combination with using the alternate stack:
       * pthread library functions try to use the stack pointer to
       * identify the current thread, causing a SEGV signal, which
       * recursively calls deathtrap() and hangs. */
      sa.sa_flags = 0;
# else
      sa.sa_flags = SA_ONSTACK;
# endif
      sigaction(signal_info[i].sig, &sa, NULL);
#else
# if defined(HAVE_SIGALTSTACK) && defined(HAVE_SIGVEC)
      struct sigvec sv;

      /* Setup to use the alternate stack for the signal function. */
      sv.sv_handler = func_deadly;
      sv.sv_mask = 0;
      sv.sv_flags = SV_ONSTACK;
      sigvec(signal_info[i].sig, &sv, NULL);
# else
      signal(signal_info[i].sig, func_deadly);
# endif
#endif
    } else if (func_other != SIG_ERR)
      signal(signal_info[i].sig, func_other);
}

/*
 * Handling of SIGHUP, SIGQUIT and SIGTERM:
 * "when" == a signal:       when busy, postpone and return FALSE, otherwise
 *			     return TRUE
 * "when" == SIGNAL_BLOCK:   Going to be busy, block signals
 * "when" == SIGNAL_UNBLOCK: Going to wait, unblock signals, use postponed
 *			     signal
 * Returns TRUE when Vim should exit.
 */
int vim_handle_signal(int sig)
{
  static int got_signal = 0;
  static int blocked = TRUE;

  switch (sig) {
  case SIGNAL_BLOCK:   blocked = TRUE;
    break;

  case SIGNAL_UNBLOCK: blocked = FALSE;
    if (got_signal != 0) {
      kill(getpid(), got_signal);
      got_signal = 0;
    }
    break;

  default:             if (!blocked)
      return TRUE;                              /* exit! */
    got_signal = sig;
#ifdef SIGPWR
    if (sig != SIGPWR)
#endif
    got_int = TRUE;                                 /* break any loops */
    break;
  }
  return FALSE;
}

/*
 * Check_win checks whether we have an interactive stdout.
 */
int mch_check_win(int argc, char **argv)
{
  if (isatty(1))
    return OK;
  return FAIL;
}

/*
 * Return TRUE if the input comes from a terminal, FALSE otherwise.
 */
int mch_input_isatty()         {
  if (isatty(read_cmd_fd))
    return TRUE;
  return FALSE;
}

static int get_x11_title(int test_only)
{
  return FALSE;
}

static int get_x11_icon(int test_only)
{
  if (!test_only) {
    if (STRNCMP(T_NAME, "builtin_", 8) == 0)
      oldicon = vim_strsave(T_NAME + 8);
    else
      oldicon = vim_strsave(T_NAME);
  }
  return FALSE;
}


int mch_can_restore_title()         {
  return get_x11_title(TRUE);
}

int mch_can_restore_icon()         {
  return get_x11_icon(TRUE);
}

/*
 * Set the window title and icon.
 */
void mch_settitle(char_u *title, char_u *icon)
{
  int type = 0;
  static int recursive = 0;

  if (T_NAME == NULL)       /* no terminal name (yet) */
    return;
  if (title == NULL && icon == NULL)        /* nothing to do */
    return;

  /* When one of the X11 functions causes a deadly signal, we get here again
   * recursively.  Avoid hanging then (something is probably locked). */
  if (recursive)
    return;
  ++recursive;

  /*
   * if the window ID and the display is known, we may use X11 calls
   */

  /*
   * Note: if "t_ts" is set, title is set with escape sequence rather
   *	     than x11 calls, because the x11 calls don't always work
   */
  if ((type || *T_TS != NUL) && title != NULL) {
    if (oldtitle == NULL
        )                       /* first call but not in GUI, save title */
      (void)get_x11_title(FALSE);

    if (*T_TS != NUL)                   /* it's OK if t_fs is empty */
      term_settitle(title);
    did_set_title = TRUE;
  }

  if ((type || *T_CIS != NUL) && icon != NULL) {
    if (oldicon == NULL
        )                       /* first call, save icon */
      get_x11_icon(FALSE);

    if (*T_CIS != NUL) {
      out_str(T_CIS);                           /* set icon start */
      out_str_nf(icon);
      out_str(T_CIE);                           /* set icon end */
      out_flush();
    }
    did_set_icon = TRUE;
  }
  --recursive;
}

/*
 * Restore the window/icon title.
 * "which" is one of:
 *  1  only restore title
 *  2  only restore icon
 *  3  restore title and icon
 */
void mch_restore_title(int which)
{
  /* only restore the title or icon when it has been set */
  mch_settitle(((which & 1) && did_set_title) ?
      (oldtitle ? oldtitle : p_titleold) : NULL,
      ((which & 2) && did_set_icon) ? oldicon : NULL);
}


/*
 * Return TRUE if "name" looks like some xterm name.
 * Seiichi Sato mentioned that "mlterm" works like xterm.
 */
int vim_is_xterm(char_u *name)
{
  if (name == NULL)
    return FALSE;
  return STRNICMP(name, "xterm", 5) == 0
         || STRNICMP(name, "nxterm", 6) == 0
         || STRNICMP(name, "kterm", 5) == 0
         || STRNICMP(name, "mlterm", 6) == 0
         || STRNICMP(name, "rxvt", 4) == 0
         || STRCMP(name, "builtin_xterm") == 0;
}

/*
 * Return TRUE if "name" appears to be that of a terminal
 * known to support the xterm-style mouse protocol.
 * Relies on term_is_xterm having been set to its correct value.
 */
int use_xterm_like_mouse(char_u *name)
{
  return name != NULL
         && (term_is_xterm || STRNICMP(name, "screen", 6) == 0);
}

/*
 * Return non-zero when using an xterm mouse, according to 'ttymouse'.
 * Return 1 for "xterm".
 * Return 2 for "xterm2".
 * Return 3 for "urxvt".
 * Return 4 for "sgr".
 */
int use_xterm_mouse()         {
  if (ttym_flags == TTYM_SGR)
    return 4;
  if (ttym_flags == TTYM_URXVT)
    return 3;
  if (ttym_flags == TTYM_XTERM2)
    return 2;
  if (ttym_flags == TTYM_XTERM)
    return 1;
  return 0;
}

int vim_is_iris(char_u *name)
{
  if (name == NULL)
    return FALSE;
  return STRNICMP(name, "iris-ansi", 9) == 0
         || STRCMP(name, "builtin_iris-ansi") == 0;
}

int vim_is_vt300(char_u *name)
{
  if (name == NULL)
    return FALSE;              /* actually all ANSI comp. terminals should be here  */
  /* catch VT100 - VT5xx */
  return (STRNICMP(name, "vt", 2) == 0
          && vim_strchr((char_u *)"12345", name[2]) != NULL)
         || STRCMP(name, "builtin_vt320") == 0;
}

/*
 * Return TRUE if "name" is a terminal for which 'ttyfast' should be set.
 * This should include all windowed terminal emulators.
 */
int vim_is_fastterm(char_u *name)
{
  if (name == NULL)
    return FALSE;
  if (vim_is_xterm(name) || vim_is_vt300(name) || vim_is_iris(name))
    return TRUE;
  return STRNICMP(name, "hpterm", 6) == 0
         || STRNICMP(name, "sun-cmd", 7) == 0
         || STRNICMP(name, "screen", 6) == 0
         || STRNICMP(name, "dtterm", 6) == 0;
}

/*
 * Insert user name in s[len].
 * Return OK if a name found.
 */
int mch_get_user_name(char_u *s, int len)
{
  return mch_get_uname(getuid(), s, len);
}

/*
 * Insert user name for "uid" in s[len].
 * Return OK if a name found.
 */
int mch_get_uname(uid_t uid, char_u *s, int len)
{
#if defined(HAVE_PWD_H) && defined(HAVE_GETPWUID)
  struct passwd   *pw;

  if ((pw = getpwuid(uid)) != NULL
      && pw->pw_name != NULL && *(pw->pw_name) != NUL) {
    vim_strncpy(s, (char_u *)pw->pw_name, len - 1);
    return OK;
  }
#endif
  sprintf((char *)s, "%d", (int)uid);       /* assumes s is long enough */
  return FAIL;                              /* a number is not a name */
}

/*
 * Insert host name is s[len].
 */

#ifdef HAVE_SYS_UTSNAME_H
void mch_get_host_name(char_u *s, int len)
{
  struct utsname vutsname;

  if (uname(&vutsname) < 0)
    *s = NUL;
  else
    vim_strncpy(s, (char_u *)vutsname.nodename, len - 1);
}
#else /* HAVE_SYS_UTSNAME_H */

# ifdef HAVE_SYS_SYSTEMINFO_H
#  define gethostname(nam, len) sysinfo(SI_HOSTNAME, nam, len)
# endif

void mch_get_host_name(char_u *s, int len)
{
  gethostname((char *)s, len);
  s[len - 1] = NUL;     /* make sure it's terminated */
}
#endif /* HAVE_SYS_UTSNAME_H */

/*
 * return process ID
 */
long mch_get_pid()          {
  return (long)getpid();
}

#if defined(USE_FNAME_CASE) || defined(PROTO)
/*
 * Set the case of the file name, if it already exists.  This will cause the
 * file name to remain exactly the same.
 * Only required for file systems where case is ignored and preserved.
 */
void fname_case(
char_u      *name,
int len;              /* buffer size, only used when name gets longer */
)
{
  struct stat st;
  char_u      *slash, *tail;
  DIR         *dirp;
  struct dirent *dp;

  if (lstat((char *)name, &st) >= 0) {
    /* Open the directory where the file is located. */
    slash = vim_strrchr(name, '/');
    if (slash == NULL) {
      dirp = opendir(".");
      tail = name;
    } else   {
      *slash = NUL;
      dirp = opendir((char *)name);
      *slash = '/';
      tail = slash + 1;
    }

    if (dirp != NULL) {
      while ((dp = readdir(dirp)) != NULL) {
        /* Only accept names that differ in case and are the same byte
         * length. TODO: accept different length name. */
        if (STRICMP(tail, dp->d_name) == 0
            && STRLEN(tail) == STRLEN(dp->d_name)) {
          char_u newname[MAXPATHL + 1];
          struct stat st2;

          /* Verify the inode is equal. */
          vim_strncpy(newname, name, MAXPATHL);
          vim_strncpy(newname + (tail - name), (char_u *)dp->d_name,
              MAXPATHL - (tail - name));
          if (lstat((char *)newname, &st2) >= 0
              && st.st_ino == st2.st_ino
              && st.st_dev == st2.st_dev) {
            STRCPY(tail, dp->d_name);
            break;
          }
        }
      }

      closedir(dirp);
    }
  }
}
#endif

/*
 * Get file permissions for 'name'.
 * Returns -1 when it doesn't exist.
 */
long mch_getperm(char_u *name)
{
  struct stat statb;

  /* Keep the #ifdef outside of stat(), it may be a macro. */
  if (stat((char *)name, &statb))
    return -1;
#ifdef __INTERIX
  /* The top bit makes the value negative, which means the file doesn't
   * exist.  Remove the bit, we don't use it. */
  return statb.st_mode & ~S_ADDACE;
#else
  return statb.st_mode;
#endif
}

/*
 * set file permission for 'name' to 'perm'
 *
 * return FAIL for failure, OK otherwise
 */
int mch_setperm(char_u *name, long perm)
{
  return chmod((char *)
      name,
      (mode_t)perm) == 0 ? OK : FAIL;
}

#if defined(HAVE_ACL) || defined(PROTO)
# ifdef HAVE_SYS_ACL_H
#  include <sys/acl.h>
# endif
# ifdef HAVE_SYS_ACCESS_H
#  include <sys/access.h>
# endif


#if defined(HAVE_SELINUX) || defined(PROTO)
/*
 * Copy security info from "from_file" to "to_file".
 */
void mch_copy_sec(char_u *from_file, char_u *to_file)
{
  if (from_file == NULL)
    return;

  if (selinux_enabled == -1)
    selinux_enabled = is_selinux_enabled();

  if (selinux_enabled > 0) {
    security_context_t from_context = NULL;
    security_context_t to_context = NULL;

    if (getfilecon((char *)from_file, &from_context) < 0) {
      /* If the filesystem doesn't support extended attributes,
         the original had no special security context and the
         target cannot have one either.  */
      if (errno == EOPNOTSUPP)
        return;

      MSG_PUTS(_("\nCould not get security context for "));
      msg_outtrans(from_file);
      msg_putchar('\n');
      return;
    }
    if (getfilecon((char *)to_file, &to_context) < 0) {
      MSG_PUTS(_("\nCould not get security context for "));
      msg_outtrans(to_file);
      msg_putchar('\n');
      freecon (from_context);
      return;
    }
    if (strcmp(from_context, to_context) != 0) {
      if (setfilecon((char *)to_file, from_context) < 0) {
        MSG_PUTS(_("\nCould not set security context for "));
        msg_outtrans(to_file);
        msg_putchar('\n');
      }
    }
    freecon(to_context);
    freecon(from_context);
  }
}
#endif /* HAVE_SELINUX */

/*
 * Return a pointer to the ACL of file "fname" in allocated memory.
 * Return NULL if the ACL is not available for whatever reason.
 */
vim_acl_T mch_get_acl(char_u *fname)
{
  vim_acl_T ret = NULL;
  return ret;
}

/*
 * Set the ACL of file "fname" to "acl" (unless it's NULL).
 */
void mch_set_acl(char_u *fname, vim_acl_T aclent)
{
  if (aclent == NULL)
    return;
}

void mch_free_acl(vim_acl_T aclent)
{
  if (aclent == NULL)
    return;
}
#endif

/*
 * Set hidden flag for "name".
 */
void mch_hide(char_u *name)
{
  /* can't hide a file */
}

int executable_file(char_u *name);

/*
 * Return 1 if "name" is an executable file, 0 if not or it doesn't exist.
 */
int executable_file(char_u *name)
{
  struct stat st;

  if (stat((char *)name, &st))
    return 0;
  return S_ISREG(st.st_mode) && mch_access((char *)name, X_OK) == 0;
}

/*
 * Return 1 if "name" can be found in $PATH and executed, 0 if not.
 * Return -1 if unknown.
 */
int mch_can_exe(char_u *name)
{
  char_u      *buf;
  char_u      *p, *e;
  int retval;

  /* If it's an absolute or relative path don't need to use $PATH. */
  if (mch_is_full_name(name) || (name[0] == '.' && (name[1] == '/'
                                                  || (name[1] == '.' &&
                                                      name[2] == '/'))))
    return executable_file(name);

  p = (char_u *)getenv("PATH");
  if (p == NULL || *p == NUL)
    return -1;
  buf = alloc((unsigned)(STRLEN(name) + STRLEN(p) + 2));
  if (buf == NULL)
    return -1;

  /*
   * Walk through all entries in $PATH to check if "name" exists there and
   * is an executable file.
   */
  for (;; ) {
    e = (char_u *)strchr((char *)p, ':');
    if (e == NULL)
      e = p + STRLEN(p);
    if (e - p <= 1)             /* empty entry means current dir */
      STRCPY(buf, "./");
    else {
      vim_strncpy(buf, p, e - p);
      add_pathsep(buf);
    }
    STRCAT(buf, name);
    retval = executable_file(buf);
    if (retval == 1)
      break;

    if (*e != ':')
      break;
    p = e + 1;
  }

  vim_free(buf);
  return retval;
}

/*
 * Check what "name" is:
 * NODE_NORMAL: file or directory (or doesn't exist)
 * NODE_WRITABLE: writable device, socket, fifo, etc.
 * NODE_OTHER: non-writable things
 */
int mch_nodetype(char_u *name)
{
  struct stat st;

  if (stat((char *)name, &st))
    return NODE_NORMAL;
  if (S_ISREG(st.st_mode) || S_ISDIR(st.st_mode))
    return NODE_NORMAL;
  if (S_ISBLK(st.st_mode))      /* block device isn't writable */
    return NODE_OTHER;
  /* Everything else is writable? */
  return NODE_WRITABLE;
}

void mch_early_init()          {
  /*
   * Setup an alternative stack for signals.  Helps to catch signals when
   * running out of stack space.
   * Use of sigaltstack() is preferred, it's more portable.
   * Ignore any errors.
   */
#if defined(HAVE_SIGALTSTACK) || defined(HAVE_SIGSTACK)
  signal_stack = (char *)alloc(SIGSTKSZ);
  init_signal_stack();
#endif
}

#if defined(EXITFREE) || defined(PROTO)
void mch_free_mem()          {
# if defined(HAVE_SIGALTSTACK) || defined(HAVE_SIGSTACK)
  vim_free(signal_stack);
  signal_stack = NULL;
# endif
  vim_free(oldtitle);
  vim_free(oldicon);
}

#endif

static void exit_scroll(void);

/*
 * Output a newline when exiting.
 * Make sure the newline goes to the same stream as the text.
 */
static void exit_scroll()                 {
  if (silent_mode)
    return;
  if (newline_on_exit || msg_didout) {
    if (msg_use_printf()) {
      if (info_message)
        mch_msg("\n");
      else
        mch_errmsg("\r\n");
    } else
      out_char('\n');
  } else   {
    restore_cterm_colors();             /* get original colors back */
    msg_clr_eos_force();                /* clear the rest of the display */
    windgoto((int)Rows - 1, 0);         /* may have moved the cursor */
  }
}

void mch_exit(int r)
{
  exiting = TRUE;


  {
    settmode(TMODE_COOK);
    mch_restore_title(3);       /* restore xterm title and icon name */
    /*
     * When t_ti is not empty but it doesn't cause swapping terminal
     * pages, need to output a newline when msg_didout is set.  But when
     * t_ti does swap pages it should not go to the shell page.  Do this
     * before stoptermcap().
     */
    if (swapping_screen() && !newline_on_exit)
      exit_scroll();

    /* Stop termcap: May need to check for T_CRV response, which
     * requires RAW mode. */
    stoptermcap();

    /*
     * A newline is only required after a message in the alternate screen.
     * This is set to TRUE by wait_return().
     */
    if (!swapping_screen() || newline_on_exit)
      exit_scroll();

    /* Cursor may have been switched off without calling starttermcap()
     * when doing "vim -u vimrc" and vimrc contains ":q". */
    if (full_screen)
      cursor_on();
  }
  out_flush();
  ml_close_all(TRUE);           /* remove all memfiles */
  may_core_dump();

#ifdef MACOS_CONVERT
  mac_conv_cleanup();
#endif



#ifdef EXITFREE
  free_all_mem();
#endif

  exit(r);
}

static void may_core_dump()                 {
  if (deadly_signal != 0) {
    signal(deadly_signal, SIG_DFL);
    kill(getpid(), deadly_signal);      /* Die using the signal we caught */
  }
}

void mch_settmode(int tmode)
{
  static int first = TRUE;

  /* Why is NeXT excluded here (and not in os_unixx.h)? */
#if defined(ECHOE) && defined(ICANON) && (defined(HAVE_TERMIO_H) || \
  defined(HAVE_TERMIOS_H)) && !defined(__NeXT__)
  /*
   * for "new" tty systems
   */
# ifdef HAVE_TERMIOS_H
  static struct termios told;
  struct termios tnew;
# else
  static struct termio told;
  struct termio tnew;
# endif

  if (first) {
    first = FALSE;
# if defined(HAVE_TERMIOS_H)
    tcgetattr(read_cmd_fd, &told);
# else
    ioctl(read_cmd_fd, TCGETA, &told);
# endif
  }

  tnew = told;
  if (tmode == TMODE_RAW) {
    /*
     * ~ICRNL enables typing ^V^M
     */
    tnew.c_iflag &= ~ICRNL;
    tnew.c_lflag &= ~(ICANON | ECHO | ISIG | ECHOE
# if defined(IEXTEN) && !defined(__MINT__)
                      | IEXTEN      /* IEXTEN enables typing ^V on SOLARIS */
                                    /* but it breaks function keys on MINT */
# endif
                      );
# ifdef ONLCR       /* don't map NL -> CR NL, we do it ourselves */
    tnew.c_oflag &= ~ONLCR;
# endif
    tnew.c_cc[VMIN] = 1;                /* return after 1 char */
    tnew.c_cc[VTIME] = 0;               /* don't wait */
  } else if (tmode == TMODE_SLEEP)
    tnew.c_lflag &= ~(ECHO);

# if defined(HAVE_TERMIOS_H)
  {
    int n = 10;

    /* A signal may cause tcsetattr() to fail (e.g., SIGCONT).  Retry a
     * few times. */
    while (tcsetattr(read_cmd_fd, TCSANOW, &tnew) == -1
           && errno == EINTR && n > 0)
      --n;
  }
# else
  ioctl(read_cmd_fd, TCSETA, &tnew);
# endif

#else

  /*
   * for "old" tty systems
   */
# ifndef TIOCSETN
#  define TIOCSETN TIOCSETP     /* for hpux 9.0 */
# endif
  static struct sgttyb ttybold;
  struct sgttyb ttybnew;

  if (first) {
    first = FALSE;
    ioctl(read_cmd_fd, TIOCGETP, &ttybold);
  }

  ttybnew = ttybold;
  if (tmode == TMODE_RAW) {
    ttybnew.sg_flags &= ~(CRMOD | ECHO);
    ttybnew.sg_flags |= RAW;
  } else if (tmode == TMODE_SLEEP)
    ttybnew.sg_flags &= ~(ECHO);
  ioctl(read_cmd_fd, TIOCSETN, &ttybnew);
#endif
  curr_tmode = tmode;
}

/*
 * Try to get the code for "t_kb" from the stty setting
 *
 * Even if termcap claims a backspace key, the user's setting *should*
 * prevail.  stty knows more about reality than termcap does, and if
 * somebody's usual erase key is DEL (which, for most BSD users, it will
 * be), they're going to get really annoyed if their erase key starts
 * doing forward deletes for no reason. (Eric Fischer)
 */
void get_stty()          {
  char_u buf[2];
  char_u  *p;

  /* Why is NeXT excluded here (and not in os_unixx.h)? */
#if defined(ECHOE) && defined(ICANON) && (defined(HAVE_TERMIO_H) || \
  defined(HAVE_TERMIOS_H)) && !defined(__NeXT__)
  /* for "new" tty systems */
# ifdef HAVE_TERMIOS_H
  struct termios keys;
# else
  struct termio keys;
# endif

# if defined(HAVE_TERMIOS_H)
  if (tcgetattr(read_cmd_fd, &keys) != -1)
# else
  if (ioctl(read_cmd_fd, TCGETA, &keys) != -1)
# endif
  {
    buf[0] = keys.c_cc[VERASE];
    intr_char = keys.c_cc[VINTR];
#else
  /* for "old" tty systems */
  struct sgttyb keys;

  if (ioctl(read_cmd_fd, TIOCGETP, &keys) != -1) {
    buf[0] = keys.sg_erase;
    intr_char = keys.sg_kill;
#endif
    buf[1] = NUL;
    add_termcode((char_u *)"kb", buf, FALSE);

    /*
     * If <BS> and <DEL> are now the same, redefine <DEL>.
     */
    p = find_termcode((char_u *)"kD");
    if (p != NULL && p[0] == buf[0] && p[1] == buf[1])
      do_fixdel(NULL);
  }
}

/*
 * Set mouse clicks on or off.
 */
void mch_setmouse(on)
int on;
{
  static int ison = FALSE;
  int xterm_mouse_vers;

  if (on == ison)       /* return quickly if nothing to do */
    return;

  xterm_mouse_vers = use_xterm_mouse();

  if (ttym_flags == TTYM_URXVT) {
    out_str_nf((char_u *)
        (on
         ? IF_EB("\033[?1015h", ESC_STR "[?1015h")
         : IF_EB("\033[?1015l", ESC_STR "[?1015l")));
    ison = on;
  }

  if (ttym_flags == TTYM_SGR) {
    out_str_nf((char_u *)
        (on
         ? IF_EB("\033[?1006h", ESC_STR "[?1006h")
         : IF_EB("\033[?1006l", ESC_STR "[?1006l")));
    ison = on;
  }

  if (xterm_mouse_vers > 0) {
    if (on)     /* enable mouse events, use mouse tracking if available */
      out_str_nf((char_u *)
          (xterm_mouse_vers > 1
           ? IF_EB("\033[?1002h", ESC_STR "[?1002h")
           : IF_EB("\033[?1000h", ESC_STR "[?1000h")));
    else        /* disable mouse events, could probably always send the same */
      out_str_nf((char_u *)
          (xterm_mouse_vers > 1
           ? IF_EB("\033[?1002l", ESC_STR "[?1002l")
           : IF_EB("\033[?1000l", ESC_STR "[?1000l")));
    ison = on;
  } else if (ttym_flags == TTYM_DEC)   {
    if (on)     /* enable mouse events */
      out_str_nf((char_u *)"\033[1;2'z\033[1;3'{");
    else        /* disable mouse events */
      out_str_nf((char_u *)"\033['z");
    ison = on;
  }

}

/*
 * Set the mouse termcode, depending on the 'term' and 'ttymouse' options.
 */
void check_mouse_termcode()          {
  if (use_xterm_mouse()
      && use_xterm_mouse() != 3
      ) {
    set_mouse_termcode(KS_MOUSE, (char_u *)(term_is_8bit(T_NAME)
                                            ? IF_EB("\233M", CSI_STR "M")
                                            : IF_EB("\033[M", ESC_STR "[M")));
    if (*p_mouse != NUL) {
      /* force mouse off and maybe on to send possibly new mouse
       * activation sequence to the xterm, with(out) drag tracing. */
      mch_setmouse(FALSE);
      setmouse();
    }
  } else
    del_mouse_termcode(KS_MOUSE);


  /* There is no conflict, but one may type "ESC }" from Insert mode.  Don't
   * define it in the GUI or when using an xterm. */
  if (!use_xterm_mouse()
      )
    set_mouse_termcode(KS_NETTERM_MOUSE,
        (char_u *)IF_EB("\033}", ESC_STR "}"));
  else
    del_mouse_termcode(KS_NETTERM_MOUSE);

  /* conflicts with xterm mouse: "\033[" and "\033[M" */
  if (!use_xterm_mouse()
      )
    set_mouse_termcode(KS_DEC_MOUSE, (char_u *)(term_is_8bit(T_NAME)
                                                ? IF_EB("\233",
                                                    CSI_STR) : IF_EB("\033[",
                                                    ESC_STR "[")));
  else
    del_mouse_termcode(KS_DEC_MOUSE);
  /* same as the dec mouse */
  if (use_xterm_mouse() == 3
      ) {
    set_mouse_termcode(KS_URXVT_MOUSE, (char_u *)(term_is_8bit(T_NAME)
                                                  ? IF_EB("\233", CSI_STR)
                                                  : IF_EB("\033[", ESC_STR "[")));

    if (*p_mouse != NUL) {
      mch_setmouse(FALSE);
      setmouse();
    }
  } else
    del_mouse_termcode(KS_URXVT_MOUSE);
  /* same as the dec mouse */
  if (use_xterm_mouse() == 4
      ) {
    set_mouse_termcode(KS_SGR_MOUSE, (char_u *)(term_is_8bit(T_NAME)
                                                ? IF_EB("\233<", CSI_STR "<")
                                                : IF_EB("\033[<", ESC_STR "[<")));

    if (*p_mouse != NUL) {
      mch_setmouse(FALSE);
      setmouse();
    }
  } else
    del_mouse_termcode(KS_SGR_MOUSE);
}

/*
 * set screen mode, always fails.
 */
int mch_screenmode(arg)
char_u   *arg;
{
  EMSG(_(e_screenmode));
  return FAIL;
}


/*
 * Try to get the current window size:
 * 1. with an ioctl(), most accurate method
 * 2. from the environment variables LINES and COLUMNS
 * 3. from the termcap
 * 4. keep using the old values
 * Return OK when size could be determined, FAIL otherwise.
 */
int mch_get_shellsize()         {
  long rows = 0;
  long columns = 0;
  char_u      *p;

  /*
   * For OS/2 use _scrsize().
   */

  /*
   * 1. try using an ioctl. It is the most accurate method.
   *
   * Try using TIOCGWINSZ first, some systems that have it also define
   * TIOCGSIZE but don't have a struct ttysize.
   */
# ifdef TIOCGWINSZ
  {
    struct winsize ws;
    int fd = 1;

    /* When stdout is not a tty, use stdin for the ioctl(). */
    if (!isatty(fd) && isatty(read_cmd_fd))
      fd = read_cmd_fd;
    if (ioctl(fd, TIOCGWINSZ, &ws) == 0) {
      columns = ws.ws_col;
      rows = ws.ws_row;
    }
  }
# else /* TIOCGWINSZ */
#  ifdef TIOCGSIZE
  {
    struct ttysize ts;
    int fd = 1;

    /* When stdout is not a tty, use stdin for the ioctl(). */
    if (!isatty(fd) && isatty(read_cmd_fd))
      fd = read_cmd_fd;
    if (ioctl(fd, TIOCGSIZE, &ts) == 0) {
      columns = ts.ts_cols;
      rows = ts.ts_lines;
    }
  }
#  endif /* TIOCGSIZE */
# endif /* TIOCGWINSZ */

  /*
   * 2. get size from environment
   *    When being POSIX compliant ('|' flag in 'cpoptions') this overrules
   *    the ioctl() values!
   */
  if (columns == 0 || rows == 0 || vim_strchr(p_cpo, CPO_TSIZE) != NULL) {
    if ((p = (char_u *)getenv("LINES")))
      rows = atoi((char *)p);
    if ((p = (char_u *)getenv("COLUMNS")))
      columns = atoi((char *)p);
  }

#ifdef HAVE_TGETENT
  /*
   * 3. try reading "co" and "li" entries from termcap
   */
  if (columns == 0 || rows == 0)
    getlinecol(&columns, &rows);
#endif

  /*
   * 4. If everything fails, use the old values
   */
  if (columns <= 0 || rows <= 0)
    return FAIL;

  Rows = rows;
  Columns = columns;
  limit_screen_size();
  return OK;
}

/*
 * Try to set the window size to Rows and Columns.
 */
void mch_set_shellsize()          {
  if (*T_CWS) {
    /*
     * NOTE: if you get an error here that term_set_winsize() is
     * undefined, check the output of configure.  It could probably not
     * find a ncurses, termcap or termlib library.
     */
    term_set_winsize((int)Rows, (int)Columns);
    out_flush();
    screen_start();                     /* don't know where cursor is now */
  }
}

/*
 * Rows and/or Columns has changed.
 */
void mch_new_shellsize()          {
  /* Nothing to do. */
}

/*
 * Wait for process "child" to end.
 * Return "child" if it exited properly, <= 0 on error.
 */
static pid_t wait4pid(child, status)
pid_t child;
waitstatus  *status;
{
  pid_t wait_pid = 0;

  while (wait_pid != child) {
    /* When compiled with Python threads are probably used, in which case
     * wait() sometimes hangs for no obvious reason.  Use waitpid()
     * instead and loop (like the GUI). Also needed for other interfaces,
     * they might call system(). */
# ifdef __NeXT__
    wait_pid = wait4(child, status, WNOHANG, (struct rusage *)0);
# else
    wait_pid = waitpid(child, status, WNOHANG);
# endif
    if (wait_pid == 0) {
      /* Wait for 10 msec before trying again. */
      mch_delay(10L, TRUE);
      continue;
    }
    if (wait_pid <= 0
# ifdef ECHILD
        && errno == ECHILD
# endif
        )
      break;
  }
  return wait_pid;
}

int mch_call_shell(cmd, options)
char_u      *cmd;
int options;                    /* SHELL_*, see vim.h */
{
  int tmode = cur_tmode;

# define EXEC_FAILED 122    /* Exit code when shell didn't execute.  Don't use
                               127, some shells use that already */

  char_u      *newcmd = NULL;
  pid_t pid;
  pid_t wpid = 0;
  pid_t wait_pid = 0;
# ifdef HAVE_UNION_WAIT
  union wait status;
# else
  int status = -1;
# endif
  int retval = -1;
  char        **argv = NULL;
  int argc;
  char_u      *p_shcf_copy = NULL;
  int i;
  char_u      *p;
  int inquote;
  int pty_master_fd = -1;                   /* for pty's */
  int fd_toshell[2];                    /* for pipes */
  int fd_fromshell[2];
  int pipe_error = FALSE;
# ifdef HAVE_SETENV
  char envbuf[50];
# else
  static char envbuf_Rows[20];
  static char envbuf_Columns[20];
# endif
  int did_settmode = FALSE;             /* settmode(TMODE_RAW) called */

  newcmd = vim_strsave(p_sh);
  if (newcmd == NULL)           /* out of memory */
    goto error;

  out_flush();
  if (options & SHELL_COOKED)
    settmode(TMODE_COOK);               /* set to normal mode */

  /*
   * Do this loop twice:
   * 1: find number of arguments
   * 2: separate them and build argv[]
   */
  for (i = 0; i < 2; ++i) {
    p = newcmd;
    inquote = FALSE;
    argc = 0;
    for (;; ) {
      if (i == 1)
        argv[argc] = (char *)p;
      ++argc;
      while (*p && (inquote || (*p != ' ' && *p != TAB))) {
        if (*p == '"')
          inquote = !inquote;
        ++p;
      }
      if (*p == NUL)
        break;
      if (i == 1)
        *p++ = NUL;
      p = skipwhite(p);
    }
    if (argv == NULL) {
      /*
       * Account for possible multiple args in p_shcf.
       */
      p = p_shcf;
      for (;; ) {
        p = skiptowhite(p);
        if (*p == NUL)
          break;
        ++argc;
        p = skipwhite(p);
      }

      argv = (char **)alloc((unsigned)((argc + 4) * sizeof(char *)));
      if (argv == NULL)             /* out of memory */
        goto error;
    }
  }
  if (cmd != NULL) {
    char_u  *s;

    if (extra_shell_arg != NULL)
      argv[argc++] = (char *)extra_shell_arg;

    /* Break 'shellcmdflag' into white separated parts.  This doesn't
     * handle quoted strings, they are very unlikely to appear. */
    p_shcf_copy = alloc((unsigned)STRLEN(p_shcf) + 1);
    if (p_shcf_copy == NULL)        /* out of memory */
      goto error;
    s = p_shcf_copy;
    p = p_shcf;
    while (*p != NUL) {
      argv[argc++] = (char *)s;
      while (*p && *p != ' ' && *p != TAB)
        *s++ = *p++;
      *s++ = NUL;
      p = skipwhite(p);
    }

    argv[argc++] = (char *)cmd;
  }
  argv[argc] = NULL;

  /*
   * For the GUI, when writing the output into the buffer and when reading
   * input from the buffer: Try using a pseudo-tty to get the stdin/stdout
   * of the executed command into the Vim window.  Or use a pipe.
   */
  if ((options & (SHELL_READ|SHELL_WRITE))
      ) {
    {
      pipe_error = (pipe(fd_toshell) < 0);
      if (!pipe_error) {                            /* pipe create OK */
        pipe_error = (pipe(fd_fromshell) < 0);
        if (pipe_error) {                           /* pipe create failed */
          close(fd_toshell[0]);
          close(fd_toshell[1]);
        }
      }
      if (pipe_error) {
        MSG_PUTS(_("\nCannot create pipes\n"));
        out_flush();
      }
    }
  }

  if (!pipe_error) {                    /* pty or pipe opened or not used */

    if ((pid = fork()) == -1) {         /* maybe we should use vfork() */
      MSG_PUTS(_("\nCannot fork\n"));
      if ((options & (SHELL_READ|SHELL_WRITE))
          ) {
        {
          close(fd_toshell[0]);
          close(fd_toshell[1]);
          close(fd_fromshell[0]);
          close(fd_fromshell[1]);
        }
      }
    } else if (pid == 0)   {    /* child */
      reset_signals();                  /* handle signals normally */

      if (!show_shell_mess || (options & SHELL_EXPAND)) {
        int fd;

        /*
         * Don't want to show any message from the shell.  Can't just
         * close stdout and stderr though, because some systems will
         * break if you try to write to them after that, so we must
         * use dup() to replace them with something else -- webb
         * Connect stdin to /dev/null too, so ":n `cat`" doesn't hang,
         * waiting for input.
         */
        fd = open("/dev/null", O_RDWR | O_EXTRA, 0);
        fclose(stdin);
        fclose(stdout);
        fclose(stderr);

        /*
         * If any of these open()'s and dup()'s fail, we just continue
         * anyway.  It's not fatal, and on most systems it will make
         * no difference at all.  On a few it will cause the execvp()
         * to exit with a non-zero status even when the completion
         * could be done, which is nothing too serious.  If the open()
         * or dup() failed we'd just do the same thing ourselves
         * anyway -- webb
         */
        if (fd >= 0) {
          ignored = dup(fd);           /* To replace stdin  (fd 0) */
          ignored = dup(fd);           /* To replace stdout (fd 1) */
          ignored = dup(fd);           /* To replace stderr (fd 2) */

          /* Don't need this now that we've duplicated it */
          close(fd);
        }
      } else if ((options & (SHELL_READ|SHELL_WRITE))
                 ) {

# ifdef HAVE_SETSID
        /* Create our own process group, so that the child and all its
         * children can be kill()ed.  Don't do this when using pipes,
         * because stdin is not a tty, we would lose /dev/tty. */
        if (p_stmp) {
          (void)setsid();
#  if defined(SIGHUP)
          /* When doing "!xterm&" and 'shell' is bash: the shell
           * will exit and send SIGHUP to all processes in its
           * group, killing the just started process.  Ignore SIGHUP
           * to avoid that. (suggested by Simon Schubert)
           */
          signal(SIGHUP, SIG_IGN);
#  endif
        }
# endif
        /* Simulate to have a dumb terminal (for now) */
# ifdef HAVE_SETENV
        setenv("TERM", "dumb", 1);
        sprintf((char *)envbuf, "%ld", Rows);
        setenv("ROWS", (char *)envbuf, 1);
        sprintf((char *)envbuf, "%ld", Rows);
        setenv("LINES", (char *)envbuf, 1);
        sprintf((char *)envbuf, "%ld", Columns);
        setenv("COLUMNS", (char *)envbuf, 1);
# else
        /*
         * Putenv does not copy the string, it has to remain valid.
         * Use a static array to avoid losing allocated memory.
         */
        putenv("TERM=dumb");
        sprintf(envbuf_Rows, "ROWS=%ld", Rows);
        putenv(envbuf_Rows);
        sprintf(envbuf_Rows, "LINES=%ld", Rows);
        putenv(envbuf_Rows);
        sprintf(envbuf_Columns, "COLUMNS=%ld", Columns);
        putenv(envbuf_Columns);
# endif

        /*
         * stderr is only redirected when using the GUI, so that a
         * program like gpg can still access the terminal to get a
         * passphrase using stderr.
         */
        {
          /* set up stdin for the child */
          close(fd_toshell[1]);
          close(0);
          ignored = dup(fd_toshell[0]);
          close(fd_toshell[0]);

          /* set up stdout for the child */
          close(fd_fromshell[0]);
          close(1);
          ignored = dup(fd_fromshell[1]);
          close(fd_fromshell[1]);

        }
      }

      /*
       * There is no type cast for the argv, because the type may be
       * different on different machines. This may cause a warning
       * message with strict compilers, don't worry about it.
       * Call _exit() instead of exit() to avoid closing the connection
       * to the X server (esp. with GTK, which uses atexit()).
       */
      execvp(argv[0], argv);
      _exit(EXEC_FAILED);           /* exec failed, return failure code */
    } else   {                  /* parent */
      /*
       * While child is running, ignore terminating signals.
       * Do catch CTRL-C, so that "got_int" is set.
       */
      catch_signals(SIG_IGN, SIG_ERR);
      catch_int_signal();

      /*
       * For the GUI we redirect stdin, stdout and stderr to our window.
       * This is also used to pipe stdin/stdout to/from the external
       * command.
       */
      if ((options & (SHELL_READ|SHELL_WRITE))
          ) {
# define BUFLEN 100             /* length for buffer, pseudo tty limit is 128 */
        char_u buffer[BUFLEN + 1];
        int buffer_off = 0;                     /* valid bytes in buffer[] */
        char_u ta_buf[BUFLEN + 1];              /* TypeAHead */
        int ta_len = 0;                         /* valid bytes in ta_buf[] */
        int len;
        int p_more_save;
        int old_State;
        int c;
        int toshell_fd;
        int fromshell_fd;
        garray_T ga;
        int noread_cnt;
# if defined(HAVE_GETTIMEOFDAY) && defined(HAVE_SYS_TIME_H)
        struct timeval start_tv;
# endif

        {
          close(fd_toshell[0]);
          close(fd_fromshell[1]);
          toshell_fd = fd_toshell[1];
          fromshell_fd = fd_fromshell[0];
        }

        /*
         * Write to the child if there are typed characters.
         * Read from the child if there are characters available.
         *   Repeat the reading a few times if more characters are
         *   available. Need to check for typed keys now and then, but
         *   not too often (delays when no chars are available).
         * This loop is quit if no characters can be read from the pty
         * (WaitForChar detected special condition), or there are no
         * characters available and the child has exited.
         * Only check if the child has exited when there is no more
         * output. The child may exit before all the output has
         * been printed.
         *
         * Currently this busy loops!
         * This can probably dead-lock when the write blocks!
         */
        p_more_save = p_more;
        p_more = FALSE;
        old_State = State;
        State = EXTERNCMD;              /* don't redraw at window resize */

        if ((options & SHELL_WRITE) && toshell_fd >= 0) {
          /* Fork a process that will write the lines to the
           * external program. */
          if ((wpid = fork()) == -1) {
            MSG_PUTS(_("\nCannot fork\n"));
          } else if (wpid == 0)   {     /* child */
            linenr_T lnum = curbuf->b_op_start.lnum;
            int written = 0;
            char_u      *lp = ml_get(lnum);
            size_t l;

            close(fromshell_fd);
            for (;; ) {
              l = STRLEN(lp + written);
              if (l == 0)
                len = 0;
              else if (lp[written] == NL)
                /* NL -> NUL translation */
                len = write(toshell_fd, "", (size_t)1);
              else {
                char_u  *s = vim_strchr(lp + written, NL);

                len = write(toshell_fd, (char *)lp + written,
                    s == NULL ? l
                    : (size_t)(s - (lp + written)));
              }
              if (len == (int)l) {
                /* Finished a line, add a NL, unless this line
                 * should not have one. */
                if (lnum != curbuf->b_op_end.lnum
                    || !curbuf->b_p_bin
                    || (lnum != curbuf->b_no_eol_lnum
                        && (lnum !=
                            curbuf->b_ml.ml_line_count
                            || curbuf->b_p_eol)))
                  ignored = write(toshell_fd, "\n",
                      (size_t)1);
                ++lnum;
                if (lnum > curbuf->b_op_end.lnum) {
                  /* finished all the lines, close pipe */
                  close(toshell_fd);
                  toshell_fd = -1;
                  break;
                }
                lp = ml_get(lnum);
                written = 0;
              } else if (len > 0)
                written += len;
            }
            _exit(0);
          } else   {     /* parent */
            close(toshell_fd);
            toshell_fd = -1;
          }
        }

        if (options & SHELL_READ)
          ga_init2(&ga, 1, BUFLEN);

        noread_cnt = 0;
# if defined(HAVE_GETTIMEOFDAY) && defined(HAVE_SYS_TIME_H)
        gettimeofday(&start_tv, NULL);
# endif
        for (;; ) {
          /*
           * Check if keys have been typed, write them to the child
           * if there are any.
           * Don't do this if we are expanding wild cards (would eat
           * typeahead).
           * Don't do this when filtering and terminal is in cooked
           * mode, the shell command will handle the I/O.  Avoids
           * that a typed password is echoed for ssh or gpg command.
           * Don't get characters when the child has already
           * finished (wait_pid == 0).
           * Don't read characters unless we didn't get output for a
           * while (noread_cnt > 4), avoids that ":r !ls" eats
           * typeahead.
           */
          len = 0;
          if (!(options & SHELL_EXPAND)
              && ((options &
                   (SHELL_READ|SHELL_WRITE|SHELL_COOKED))
                  != (SHELL_READ|SHELL_WRITE|SHELL_COOKED)
                  )
              && wait_pid == 0
              && (ta_len > 0 || noread_cnt > 4)) {
            if (ta_len == 0) {
              /* Get extra characters when we don't have any.
               * Reset the counter and timer. */
              noread_cnt = 0;
# if defined(HAVE_GETTIMEOFDAY) && defined(HAVE_SYS_TIME_H)
              gettimeofday(&start_tv, NULL);
# endif
              len = ui_inchar(ta_buf, BUFLEN, 10L, 0);
            }
            if (ta_len > 0 || len > 0) {
              /*
               * For pipes:
               * Check for CTRL-C: send interrupt signal to child.
               * Check for CTRL-D: EOF, close pipe to child.
               */
              if (len == 1 && (pty_master_fd < 0 || cmd != NULL)) {
# ifdef SIGINT
                /*
                 * Send SIGINT to the child's group or all
                 * processes in our group.
                 */
                if (ta_buf[ta_len] == Ctrl_C
                    || ta_buf[ta_len] == intr_char) {
#  ifdef HAVE_SETSID
                  kill(-pid, SIGINT);
#  else
                  kill(0, SIGINT);
#  endif
                  if (wpid > 0)
                    kill(wpid, SIGINT);
                }
# endif
                if (pty_master_fd < 0 && toshell_fd >= 0
                    && ta_buf[ta_len] == Ctrl_D) {
                  close(toshell_fd);
                  toshell_fd = -1;
                }
              }

              /* replace K_BS by <BS> and K_DEL by <DEL> */
              for (i = ta_len; i < ta_len + len; ++i) {
                if (ta_buf[i] == CSI && len - i > 2) {
                  c = TERMCAP2KEY(ta_buf[i + 1], ta_buf[i + 2]);
                  if (c == K_DEL || c == K_KDEL || c == K_BS) {
                    mch_memmove(ta_buf + i + 1, ta_buf + i + 3,
                        (size_t)(len - i - 2));
                    if (c == K_DEL || c == K_KDEL)
                      ta_buf[i] = DEL;
                    else
                      ta_buf[i] = Ctrl_H;
                    len -= 2;
                  }
                } else if (ta_buf[i] == '\r')
                  ta_buf[i] = '\n';
                if (has_mbyte)
                  i += (*mb_ptr2len_len)(ta_buf + i,
                                         ta_len + len - i) - 1;
              }

              /*
               * For pipes: echo the typed characters.
               * For a pty this does not seem to work.
               */
              if (pty_master_fd < 0) {
                for (i = ta_len; i < ta_len + len; ++i) {
                  if (ta_buf[i] == '\n' || ta_buf[i] == '\b')
                    msg_putchar(ta_buf[i]);
                  else if (has_mbyte) {
                    int l = (*mb_ptr2len)(ta_buf + i);

                    msg_outtrans_len(ta_buf + i, l);
                    i += l - 1;
                  } else
                    msg_outtrans_len(ta_buf + i, 1);
                }
                windgoto(msg_row, msg_col);
                out_flush();
              }

              ta_len += len;

              /*
               * Write the characters to the child, unless EOF has
               * been typed for pipes.  Write one character at a
               * time, to avoid losing too much typeahead.
               * When writing buffer lines, drop the typed
               * characters (only check for CTRL-C).
               */
              if (options & SHELL_WRITE)
                ta_len = 0;
              else if (toshell_fd >= 0) {
                len = write(toshell_fd, (char *)ta_buf, (size_t)1);
                if (len > 0) {
                  ta_len -= len;
                  mch_memmove(ta_buf, ta_buf + len, ta_len);
                }
              }
            }
          }

          if (got_int) {
            /* CTRL-C sends a signal to the child, we ignore it
             * ourselves */
#  ifdef HAVE_SETSID
            kill(-pid, SIGINT);
#  else
            kill(0, SIGINT);
#  endif
            if (wpid > 0)
              kill(wpid, SIGINT);
            got_int = FALSE;
          }

          /*
           * Check if the child has any characters to be printed.
           * Read them and write them to our window.	Repeat this as
           * long as there is something to do, avoid the 10ms wait
           * for mch_inchar(), or sending typeahead characters to
           * the external process.
           * TODO: This should handle escape sequences, compatible
           * to some terminal (vt52?).
           */
          ++noread_cnt;
          while (RealWaitForChar(fromshell_fd, 10L, NULL)) {
            len = read_eintr(fromshell_fd, buffer
                + buffer_off, (size_t)(BUFLEN - buffer_off)
                );
            if (len <= 0)                           /* end of file or error */
              goto finished;

            noread_cnt = 0;
            if (options & SHELL_READ) {
              /* Do NUL -> NL translation, append NL separated
               * lines to the current buffer. */
              for (i = 0; i < len; ++i) {
                if (buffer[i] == NL)
                  append_ga_line(&ga);
                else if (buffer[i] == NUL)
                  ga_append(&ga, NL);
                else
                  ga_append(&ga, buffer[i]);
              }
            } else if (has_mbyte)   {
              int l;

              len += buffer_off;
              buffer[len] = NUL;

              /* Check if the last character in buffer[] is
               * incomplete, keep these bytes for the next
               * round. */
              for (p = buffer; p < buffer + len; p += l) {
                l = mb_cptr2len(p);
                if (l == 0)
                  l = 1;                    /* NUL byte? */
                else if (MB_BYTE2LEN(*p) != l)
                  break;
              }
              if (p == buffer) {                /* no complete character */
                /* avoid getting stuck at an illegal byte */
                if (len >= 12)
                  ++p;
                else {
                  buffer_off = len;
                  continue;
                }
              }
              c = *p;
              *p = NUL;
              msg_puts(buffer);
              if (p < buffer + len) {
                *p = c;
                buffer_off = (buffer + len) - p;
                mch_memmove(buffer, p, buffer_off);
                continue;
              }
              buffer_off = 0;
            } else   {
              buffer[len] = NUL;
              msg_puts(buffer);
            }

            windgoto(msg_row, msg_col);
            cursor_on();
            out_flush();
            if (got_int)
              break;

# if defined(HAVE_GETTIMEOFDAY) && defined(HAVE_SYS_TIME_H)
            {
              struct timeval now_tv;
              long msec;

              /* Avoid that we keep looping here without
               * checking for a CTRL-C for a long time.  Don't
               * break out too often to avoid losing typeahead. */
              gettimeofday(&now_tv, NULL);
              msec = (now_tv.tv_sec - start_tv.tv_sec) * 1000L
                     + (now_tv.tv_usec - start_tv.tv_usec) / 1000L;
              if (msec > 2000) {
                noread_cnt = 5;
                break;
              }
            }
# endif
          }

          /* If we already detected the child has finished break the
           * loop now. */
          if (wait_pid == pid)
            break;

          /*
           * Check if the child still exists, before checking for
           * typed characters (otherwise we would lose typeahead).
           */
# ifdef __NeXT__
          wait_pid = wait4(pid, &status, WNOHANG, (struct rusage *)0);
# else
          wait_pid = waitpid(pid, &status, WNOHANG);
# endif
          if ((wait_pid == (pid_t)-1 && errno == ECHILD)
              || (wait_pid == pid && WIFEXITED(status))) {
            /* Don't break the loop yet, try reading more
             * characters from "fromshell_fd" first.  When using
             * pipes there might still be something to read and
             * then we'll break the loop at the "break" above. */
            wait_pid = pid;
          } else
            wait_pid = 0;

        }
finished:
        p_more = p_more_save;
        if (options & SHELL_READ) {
          if (ga.ga_len > 0) {
            append_ga_line(&ga);
            /* remember that the NL was missing */
            curbuf->b_no_eol_lnum = curwin->w_cursor.lnum;
          } else
            curbuf->b_no_eol_lnum = 0;
          ga_clear(&ga);
        }

        /*
         * Give all typeahead that wasn't used back to ui_inchar().
         */
        if (ta_len)
          ui_inchar_undo(ta_buf, ta_len);
        State = old_State;
        if (toshell_fd >= 0)
          close(toshell_fd);
        close(fromshell_fd);
      }

      /*
       * Wait until our child has exited.
       * Ignore wait() returning pids of other children and returning
       * because of some signal like SIGWINCH.
       * Don't wait if wait_pid was already set above, indicating the
       * child already exited.
       */
      if (wait_pid != pid)
        wait_pid = wait4pid(pid, &status);


      /* Make sure the child that writes to the external program is
       * dead. */
      if (wpid > 0) {
        kill(wpid, SIGKILL);
        wait4pid(wpid, NULL);
      }

      /*
       * Set to raw mode right now, otherwise a CTRL-C after
       * catch_signals() will kill Vim.
       */
      if (tmode == TMODE_RAW)
        settmode(TMODE_RAW);
      did_settmode = TRUE;
      set_signals();

      if (WIFEXITED(status)) {
        /* LINTED avoid "bitwise operation on signed value" */
        retval = WEXITSTATUS(status);
        if (retval != 0 && !emsg_silent) {
          if (retval == EXEC_FAILED) {
            MSG_PUTS(_("\nCannot execute shell "));
            msg_outtrans(p_sh);
            msg_putchar('\n');
          } else if (!(options & SHELL_SILENT))   {
            MSG_PUTS(_("\nshell returned "));
            msg_outnum((long)retval);
            msg_putchar('\n');
          }
        }
      } else
        MSG_PUTS(_("\nCommand terminated\n"));
    }
  }
  vim_free(argv);
  vim_free(p_shcf_copy);

error:
  if (!did_settmode)
    if (tmode == TMODE_RAW)
      settmode(TMODE_RAW);              /* set to raw mode */
  resettitle();
  vim_free(newcmd);

  return retval;
}

/*
 * Check for CTRL-C typed by reading all available characters.
 * In cooked mode we should get SIGINT, no need to check.
 */
void mch_breakcheck()          {
  if (curr_tmode == TMODE_RAW && RealWaitForChar(read_cmd_fd, 0L, NULL))
    fill_input_buf(FALSE);
}

/*
 * Wait "msec" msec until a character is available from the keyboard or from
 * inbuf[]. msec == -1 will block forever.
 * When a GUI is being used, this will never get called -- webb
 */
static int WaitForChar(msec)
long msec;
{
  int avail;

  if (input_available())            /* something in inbuf[] */
    return 1;

  /* May need to query the mouse position. */
  if (WantQueryMouse) {
    WantQueryMouse = FALSE;
    mch_write((char_u *)IF_EB("\033[1'|", ESC_STR "[1'|"), 5);
  }

  /*
   * For FEAT_MOUSE_GPM and FEAT_XCLIPBOARD we loop here to process mouse
   * events.  This is a bit complicated, because they might both be defined.
   */
  avail = RealWaitForChar(read_cmd_fd, msec, NULL);
  return avail;
}

/*
 * Wait "msec" msec until a character is available from file descriptor "fd".
 * "msec" == 0 will check for characters once.
 * "msec" == -1 will block until a character is available.
 * When a GUI is being used, this will not be used for input -- webb
 * Returns also, when a request from Sniff is waiting -- toni.
 * Or when a Linux GPM mouse event is waiting.
 */
static int RealWaitForChar(fd, msec, check_for_gpm)
int fd;
long msec;
int         *check_for_gpm;
{
  int ret;

#ifdef MAY_LOOP
  for (;; )
#endif
  {
#ifdef MAY_LOOP
    int finished = TRUE;                 /* default is to 'loop' just once */
#endif
#ifndef HAVE_SELECT
    struct pollfd fds[6];
    int nfd;
    int towait = (int)msec;

    fds[0].fd = fd;
    fds[0].events = POLLIN;
    nfd = 1;


    ret = poll(fds, nfd, towait);



#else /* HAVE_SELECT */

    struct timeval tv;
    struct timeval  *tvp;
    fd_set rfds, efds;
    int maxfd;
    long towait = msec;


    if (towait >= 0) {
      tv.tv_sec = towait / 1000;
      tv.tv_usec = (towait % 1000) * (1000000/1000);
      tvp = &tv;
    } else
      tvp = NULL;

    /*
     * Select on ready for reading and exceptional condition (end of file).
     */
select_eintr:
    FD_ZERO(&rfds);
    FD_ZERO(&efds);
    FD_SET(fd, &rfds);
    /* For QNX select() always returns 1 if this is set.  Why? */
    FD_SET(fd, &efds);
    maxfd = fd;


    ret = select(maxfd + 1, &rfds, NULL, &efds, tvp);
# ifdef EINTR
    if (ret == -1 && errno == EINTR) {
      /* Check whether window has been resized, EINTR may be caused by
       * SIGWINCH. */
      if (do_resize)
        handle_resize();

      /* Interrupted by a signal, need to try again.  We ignore msec
       * here, because we do want to check even after a timeout if
       * characters are available.  Needed for reading output of an
       * external command after the process has finished. */
      goto select_eintr;
    }
# endif


#endif /* HAVE_SELECT */

#ifdef MAY_LOOP
    if (finished || msec == 0)
      break;

    /* We're going to loop around again, find out for how long */
    if (msec > 0) {
# ifdef USE_START_TV
      struct timeval mtv;

      /* Compute remaining wait time. */
      gettimeofday(&mtv, NULL);
      msec -= (mtv.tv_sec - start_tv.tv_sec) * 1000L
              + (mtv.tv_usec - start_tv.tv_usec) / 1000L;
# else
      /* Guess we got interrupted halfway. */
      msec = msec / 2;
# endif
      if (msec <= 0)
        break;          /* waited long enough */
    }
#endif
  }

  return ret > 0;
}

#ifndef NO_EXPANDPATH
/*
 * Expand a path into all matching files and/or directories.  Handles "*",
 * "?", "[a-z]", "**", etc.
 * "path" has backslashes before chars that are not to be expanded.
 * Returns the number of matches found.
 */
int mch_expandpath(gap, path, flags)
garray_T    *gap;
char_u      *path;
int flags;                      /* EW_* flags */
{
  return unix_expandpath(gap, path, 0, flags, FALSE);
}
#endif

/*
 * mch_expand_wildcards() - this code does wild-card pattern matching using
 * the shell
 *
 * return OK for success, FAIL for error (you may lose some memory) and put
 * an error message in *file.
 *
 * num_pat is number of input patterns
 * pat is array of pointers to input patterns
 * num_file is pointer to number of matched file names
 * file is pointer to array of pointers to matched file names
 */

#ifndef SEEK_SET
# define SEEK_SET 0
#endif
#ifndef SEEK_END
# define SEEK_END 2
#endif

#define SHELL_SPECIAL (char_u *)"\t \"&'$;<>()\\|"

int mch_expand_wildcards(num_pat, pat, num_file, file, flags)
int num_pat;
char_u       **pat;
int           *num_file;
char_u      ***file;
int flags;                      /* EW_* flags */
{
  int i;
  size_t len;
  char_u      *p;
  int dir;
  /*
   * This is the non-OS/2 implementation (really Unix).
   */
  int j;
  char_u      *tempname;
  char_u      *command;
  FILE        *fd;
  char_u      *buffer;
#define STYLE_ECHO      0       /* use "echo", the default */
#define STYLE_GLOB      1       /* use "glob", for csh */
#define STYLE_VIMGLOB   2       /* use "vimglob", for Posix sh */
#define STYLE_PRINT     3       /* use "print -N", for zsh */
#define STYLE_BT        4       /* `cmd` expansion, execute the pattern
                                 * directly */
  int shell_style = STYLE_ECHO;
  int check_spaces;
  static int did_find_nul = FALSE;
  int ampersent = FALSE;
  /* vimglob() function to define for Posix shell */
  static char *sh_vimglob_func =
    "vimglob() { while [ $# -ge 1 ]; do echo \"$1\"; shift; done }; vimglob >";

  *num_file = 0;        /* default: no files found */
  *file = NULL;

  /*
   * If there are no wildcards, just copy the names to allocated memory.
   * Saves a lot of time, because we don't have to start a new shell.
   */
  if (!have_wildcard(num_pat, pat))
    return save_patterns(num_pat, pat, num_file, file);

# ifdef HAVE_SANDBOX
  /* Don't allow any shell command in the sandbox. */
  if (sandbox != 0 && check_secure())
    return FAIL;
# endif

  /*
   * Don't allow the use of backticks in secure and restricted mode.
   */
  if (secure || restricted)
    for (i = 0; i < num_pat; ++i)
      if (vim_strchr(pat[i], '`') != NULL
          && (check_restricted() || check_secure()))
        return FAIL;

  /*
   * get a name for the temp file
   */
  if ((tempname = vim_tempname('o')) == NULL) {
    EMSG(_(e_notmp));
    return FAIL;
  }

  /*
   * Let the shell expand the patterns and write the result into the temp
   * file.
   * STYLE_BT:	NL separated
   *	    If expanding `cmd` execute it directly.
   * STYLE_GLOB:	NUL separated
   *	    If we use *csh, "glob" will work better than "echo".
   * STYLE_PRINT:	NL or NUL separated
   *	    If we use *zsh, "print -N" will work better than "glob".
   * STYLE_VIMGLOB:	NL separated
   *	    If we use *sh*, we define "vimglob()".
   * STYLE_ECHO:	space separated.
   *	    A shell we don't know, stay safe and use "echo".
   */
  if (num_pat == 1 && *pat[0] == '`'
      && (len = STRLEN(pat[0])) > 2
      && *(pat[0] + len - 1) == '`')
    shell_style = STYLE_BT;
  else if ((len = STRLEN(p_sh)) >= 3) {
    if (STRCMP(p_sh + len - 3, "csh") == 0)
      shell_style = STYLE_GLOB;
    else if (STRCMP(p_sh + len - 3, "zsh") == 0)
      shell_style = STYLE_PRINT;
  }
  if (shell_style == STYLE_ECHO && strstr((char *)gettail(p_sh),
          "sh") != NULL)
    shell_style = STYLE_VIMGLOB;

  /* Compute the length of the command.  We need 2 extra bytes: for the
   * optional '&' and for the NUL.
   * Worst case: "unset nonomatch; print -N >" plus two is 29 */
  len = STRLEN(tempname) + 29;
  if (shell_style == STYLE_VIMGLOB)
    len += STRLEN(sh_vimglob_func);

  for (i = 0; i < num_pat; ++i) {
    /* Count the length of the patterns in the same way as they are put in
     * "command" below. */
    ++len;                              /* add space */
    for (j = 0; pat[i][j] != NUL; ++j) {
      if (vim_strchr(SHELL_SPECIAL, pat[i][j]) != NULL)
        ++len;                  /* may add a backslash */
      ++len;
    }
  }
  command = alloc(len);
  if (command == NULL) {
    /* out of memory */
    vim_free(tempname);
    return FAIL;
  }

  /*
   * Build the shell command:
   * - Set $nonomatch depending on EW_NOTFOUND (hopefully the shell
   *	 recognizes this).
   * - Add the shell command to print the expanded names.
   * - Add the temp file name.
   * - Add the file name patterns.
   */
  if (shell_style == STYLE_BT) {
    /* change `command; command& ` to (command; command ) */
    STRCPY(command, "(");
    STRCAT(command, pat[0] + 1);                /* exclude first backtick */
    p = command + STRLEN(command) - 1;
    *p-- = ')';                                 /* remove last backtick */
    while (p > command && vim_iswhite(*p))
      --p;
    if (*p == '&') {                            /* remove trailing '&' */
      ampersent = TRUE;
      *p = ' ';
    }
    STRCAT(command, ">");
  } else   {
    if (flags & EW_NOTFOUND)
      STRCPY(command, "set nonomatch; ");
    else
      STRCPY(command, "unset nonomatch; ");
    if (shell_style == STYLE_GLOB)
      STRCAT(command, "glob >");
    else if (shell_style == STYLE_PRINT)
      STRCAT(command, "print -N >");
    else if (shell_style == STYLE_VIMGLOB)
      STRCAT(command, sh_vimglob_func);
    else
      STRCAT(command, "echo >");
  }

  STRCAT(command, tempname);

  if (shell_style != STYLE_BT)
    for (i = 0; i < num_pat; ++i) {
      /* Put a backslash before special
       * characters, except inside ``. */
      int intick = FALSE;

      p = command + STRLEN(command);
      *p++ = ' ';
      for (j = 0; pat[i][j] != NUL; ++j) {
        if (pat[i][j] == '`')
          intick = !intick;
        else if (pat[i][j] == '\\' && pat[i][j + 1] != NUL) {
          /* Remove a backslash, take char literally.  But keep
           * backslash inside backticks, before a special character
           * and before a backtick. */
          if (intick
              || vim_strchr(SHELL_SPECIAL, pat[i][j + 1]) != NULL
              || pat[i][j + 1] == '`')
            *p++ = '\\';
          ++j;
        } else if (!intick && vim_strchr(SHELL_SPECIAL,
                       pat[i][j]) != NULL)
          /* Put a backslash before a special character, but not
           * when inside ``. */
          *p++ = '\\';

        /* Copy one character. */
        *p++ = pat[i][j];
      }
      *p = NUL;
    }
  if (flags & EW_SILENT)
    show_shell_mess = FALSE;
  if (ampersent)
    STRCAT(command, "&");               /* put the '&' after the redirection */

  /*
   * Using zsh -G: If a pattern has no matches, it is just deleted from
   * the argument list, otherwise zsh gives an error message and doesn't
   * expand any other pattern.
   */
  if (shell_style == STYLE_PRINT)
    extra_shell_arg = (char_u *)"-G";       /* Use zsh NULL_GLOB option */

  /*
   * If we use -f then shell variables set in .cshrc won't get expanded.
   * vi can do it, so we will too, but it is only necessary if there is a "$"
   * in one of the patterns, otherwise we can still use the fast option.
   */
  else if (shell_style == STYLE_GLOB && !have_dollars(num_pat, pat))
    extra_shell_arg = (char_u *)"-f";           /* Use csh fast option */

  /*
   * execute the shell command
   */
  i = call_shell(command, SHELL_EXPAND | SHELL_SILENT);

  /* When running in the background, give it some time to create the temp
   * file, but don't wait for it to finish. */
  if (ampersent)
    mch_delay(10L, TRUE);

  extra_shell_arg = NULL;               /* cleanup */
  show_shell_mess = TRUE;
  vim_free(command);

  if (i != 0) {                         /* mch_call_shell() failed */
    mch_remove(tempname);
    vim_free(tempname);
    /*
     * With interactive completion, the error message is not printed.
     */
    if (!(flags & EW_SILENT))
    {
      redraw_later_clear();             /* probably messed up screen */
      msg_putchar('\n');                /* clear bottom line quickly */
      cmdline_row = Rows - 1;           /* continue on last line */
      MSG(_(e_wildexpand));
      msg_start();                    /* don't overwrite this message */
    }

    /* If a `cmd` expansion failed, don't list `cmd` as a match, even when
     * EW_NOTFOUND is given */
    if (shell_style == STYLE_BT)
      return FAIL;
    goto notfound;
  }

  /*
   * read the names from the file into memory
   */
  fd = fopen((char *)tempname, READBIN);
  if (fd == NULL) {
    /* Something went wrong, perhaps a file name with a special char. */
    if (!(flags & EW_SILENT)) {
      MSG(_(e_wildexpand));
      msg_start();                      /* don't overwrite this message */
    }
    vim_free(tempname);
    goto notfound;
  }
  fseek(fd, 0L, SEEK_END);
  len = ftell(fd);                      /* get size of temp file */
  fseek(fd, 0L, SEEK_SET);
  buffer = alloc(len + 1);
  if (buffer == NULL) {
    /* out of memory */
    mch_remove(tempname);
    vim_free(tempname);
    fclose(fd);
    return FAIL;
  }
  i = fread((char *)buffer, 1, len, fd);
  fclose(fd);
  mch_remove(tempname);
  if (i != (int)len) {
    /* unexpected read error */
    EMSG2(_(e_notread), tempname);
    vim_free(tempname);
    vim_free(buffer);
    return FAIL;
  }
  vim_free(tempname);



  /* file names are separated with Space */
  if (shell_style == STYLE_ECHO) {
    buffer[len] = '\n';                 /* make sure the buffer ends in NL */
    p = buffer;
    for (i = 0; *p != '\n'; ++i) {      /* count number of entries */
      while (*p != ' ' && *p != '\n')
        ++p;
      p = skipwhite(p);                 /* skip to next entry */
    }
  }
  /* file names are separated with NL */
  else if (shell_style == STYLE_BT || shell_style == STYLE_VIMGLOB) {
    buffer[len] = NUL;                  /* make sure the buffer ends in NUL */
    p = buffer;
    for (i = 0; *p != NUL; ++i) {       /* count number of entries */
      while (*p != '\n' && *p != NUL)
        ++p;
      if (*p != NUL)
        ++p;
      p = skipwhite(p);                 /* skip leading white space */
    }
  }
  /* file names are separated with NUL */
  else {
    /*
     * Some versions of zsh use spaces instead of NULs to separate
     * results.  Only do this when there is no NUL before the end of the
     * buffer, otherwise we would never be able to use file names with
     * embedded spaces when zsh does use NULs.
     * When we found a NUL once, we know zsh is OK, set did_find_nul and
     * don't check for spaces again.
     */
    check_spaces = FALSE;
    if (shell_style == STYLE_PRINT && !did_find_nul) {
      /* If there is a NUL, set did_find_nul, else set check_spaces */
      buffer[len] = NUL;
      if (len && (int)STRLEN(buffer) < (int)len)
        did_find_nul = TRUE;
      else
        check_spaces = TRUE;
    }

    /*
     * Make sure the buffer ends with a NUL.  For STYLE_PRINT there
     * already is one, for STYLE_GLOB it needs to be added.
     */
    if (len && buffer[len - 1] == NUL)
      --len;
    else
      buffer[len] = NUL;
    i = 0;
    for (p = buffer; p < buffer + len; ++p)
      if (*p == NUL || (*p == ' ' && check_spaces)) {       /* count entry */
        ++i;
        *p = NUL;
      }
    if (len)
      ++i;                              /* count last entry */
  }
  if (i == 0) {
    /*
     * Can happen when using /bin/sh and typing ":e $NO_SUCH_VAR^I".
     * /bin/sh will happily expand it to nothing rather than returning an
     * error; and hey, it's good to check anyway -- webb.
     */
    vim_free(buffer);
    goto notfound;
  }
  *num_file = i;
  *file = (char_u **)alloc(sizeof(char_u *) * i);
  if (*file == NULL) {
    /* out of memory */
    vim_free(buffer);
    return FAIL;
  }

  /*
   * Isolate the individual file names.
   */
  p = buffer;
  for (i = 0; i < *num_file; ++i) {
    (*file)[i] = p;
    /* Space or NL separates */
    if (shell_style == STYLE_ECHO || shell_style == STYLE_BT
        || shell_style == STYLE_VIMGLOB) {
      while (!(shell_style == STYLE_ECHO && *p == ' ')
             && *p != '\n' && *p != NUL)
        ++p;
      if (p == buffer + len)                    /* last entry */
        *p = NUL;
      else {
        *p++ = NUL;
        p = skipwhite(p);                       /* skip to next entry */
      }
    } else   {          /* NUL separates */
      while (*p && p < buffer + len)            /* skip entry */
        ++p;
      ++p;                                      /* skip NUL */
    }
  }

  /*
   * Move the file names to allocated memory.
   */
  for (j = 0, i = 0; i < *num_file; ++i) {
    /* Require the files to exist.	Helps when using /bin/sh */
    if (!(flags & EW_NOTFOUND) && mch_getperm((*file)[i]) < 0)
      continue;

    /* check if this entry should be included */
    dir = (mch_isdir((*file)[i]));
    if ((dir && !(flags & EW_DIR)) || (!dir && !(flags & EW_FILE)))
      continue;

    /* Skip files that are not executable if we check for that. */
    if (!dir && (flags & EW_EXEC) && !mch_can_exe((*file)[i]))
      continue;

    p = alloc((unsigned)(STRLEN((*file)[i]) + 1 + dir));
    if (p) {
      STRCPY(p, (*file)[i]);
      if (dir)
        add_pathsep(p);             /* add '/' to a directory name */
      (*file)[j++] = p;
    }
  }
  vim_free(buffer);
  *num_file = j;

  if (*num_file == 0) {     /* rejected all entries */
    vim_free(*file);
    *file = NULL;
    goto notfound;
  }

  return OK;

notfound:
  if (flags & EW_NOTFOUND)
    return save_patterns(num_pat, pat, num_file, file);
  return FAIL;

}


static int save_patterns(num_pat, pat, num_file, file)
int num_pat;
char_u      **pat;
int         *num_file;
char_u      ***file;
{
  int i;
  char_u      *s;

  *file = (char_u **)alloc(num_pat * sizeof(char_u *));
  if (*file == NULL)
    return FAIL;
  for (i = 0; i < num_pat; i++) {
    s = vim_strsave(pat[i]);
    if (s != NULL)
      /* Be compatible with expand_filename(): halve the number of
       * backslashes. */
      backslash_halve(s);
    (*file)[i] = s;
  }
  *num_file = num_pat;
  return OK;
}

/*
 * Return TRUE if the string "p" contains a wildcard that mch_expandpath() can
 * expand.
 */
int mch_has_exp_wildcard(p)
char_u  *p;
{
  for (; *p; mb_ptr_adv(p)) {
    if (*p == '\\' && p[1] != NUL)
      ++p;
    else if (vim_strchr((char_u *)
                 "*?[{'"
                 , *p) != NULL)
      return TRUE;
  }
  return FALSE;
}

/*
 * Return TRUE if the string "p" contains a wildcard.
 * Don't recognize '~' at the end as a wildcard.
 */
int mch_has_wildcard(p)
char_u  *p;
{
  for (; *p; mb_ptr_adv(p)) {
    if (*p == '\\' && p[1] != NUL)
      ++p;
    else if (vim_strchr((char_u *)
                 "*?[{`'$"
                 , *p) != NULL
             || (*p == '~' && p[1] != NUL))
      return TRUE;
  }
  return FALSE;
}

static int have_wildcard(num, file)
int num;
char_u  **file;
{
  int i;

  for (i = 0; i < num; i++)
    if (mch_has_wildcard(file[i]))
      return 1;
  return 0;
}

static int have_dollars(num, file)
int num;
char_u  **file;
{
  int i;

  for (i = 0; i < num; i++)
    if (vim_strchr(file[i], '$') != NULL)
      return TRUE;
  return FALSE;
}

#ifndef HAVE_RENAME
/*
 * Scaled-down version of rename(), which is missing in Xenix.
 * This version can only move regular files and will fail if the
 * destination exists.
 */
int mch_rename(src, dest)
const char *src, *dest;
{
  struct stat st;

  if (stat(dest, &st) >= 0)         /* fail if destination exists */
    return -1;
  if (link(src, dest) != 0)         /* link file to new name */
    return -1;
  if (mch_remove(src) == 0)         /* delete link to old name */
    return 0;
  return -1;
}
#endif /* !HAVE_RENAME */



#if defined(FEAT_LIBCALL) || defined(PROTO)
typedef char_u * (*STRPROCSTR)(char_u *);
typedef char_u * (*INTPROCSTR)(int);
typedef int (*STRPROCINT)(char_u *);
typedef int (*INTPROCINT)(int);

/*
 * Call a DLL routine which takes either a string or int param
 * and returns an allocated string.
 */
int mch_libcall(libname, funcname, argstring, argint, string_result,
    number_result)
char_u      *libname;
char_u      *funcname;
char_u      *argstring;         /* NULL when using a argint */
int argint;
char_u      **string_result;    /* NULL when using number_result */
int         *number_result;
{
# if defined(USE_DLOPEN)
  void        *hinstLib;
  char        *dlerr = NULL;
# else
  shl_t hinstLib;
# endif
  STRPROCSTR ProcAdd;
  INTPROCSTR ProcAddI;
  char_u      *retval_str = NULL;
  int retval_int = 0;
  int success = FALSE;

  /*
   * Get a handle to the DLL module.
   */
# if defined(USE_DLOPEN)
  /* First clear any error, it's not cleared by the dlopen() call. */
  (void)dlerror();

  hinstLib = dlopen((char *)libname, RTLD_LAZY
#  ifdef RTLD_LOCAL
      | RTLD_LOCAL
#  endif
      );
  if (hinstLib == NULL) {
    /* "dlerr" must be used before dlclose() */
    dlerr = (char *)dlerror();
    if (dlerr != NULL)
      EMSG2(_("dlerror = \"%s\""), dlerr);
  }
# else
  hinstLib = shl_load((const char*)libname, BIND_IMMEDIATE|BIND_VERBOSE, 0L);
# endif

  /* If the handle is valid, try to get the function address. */
  if (hinstLib != NULL) {
# ifdef HAVE_SETJMP_H
    /*
     * Catch a crash when calling the library function.  For example when
     * using a number where a string pointer is expected.
     */
    mch_startjmp();
    if (SETJMP(lc_jump_env) != 0) {
      success = FALSE;
#  if defined(USE_DLOPEN)
      dlerr = NULL;
#  endif
      mch_didjmp();
    } else
# endif
    {
      retval_str = NULL;
      retval_int = 0;

      if (argstring != NULL) {
# if defined(USE_DLOPEN)
        ProcAdd = (STRPROCSTR)dlsym(hinstLib, (const char *)funcname);
        dlerr = (char *)dlerror();
# else
        if (shl_findsym(&hinstLib, (const char *)funcname,
                TYPE_PROCEDURE, (void *)&ProcAdd) < 0)
          ProcAdd = NULL;
# endif
        if ((success = (ProcAdd != NULL
# if defined(USE_DLOPEN)
                        && dlerr == NULL
# endif
                        ))) {
          if (string_result == NULL)
            retval_int = ((STRPROCINT)ProcAdd)(argstring);
          else
            retval_str = (ProcAdd)(argstring);
        }
      } else   {
# if defined(USE_DLOPEN)
        ProcAddI = (INTPROCSTR)dlsym(hinstLib, (const char *)funcname);
        dlerr = (char *)dlerror();
# else
        if (shl_findsym(&hinstLib, (const char *)funcname,
                TYPE_PROCEDURE, (void *)&ProcAddI) < 0)
          ProcAddI = NULL;
# endif
        if ((success = (ProcAddI != NULL
# if defined(USE_DLOPEN)
                        && dlerr == NULL
# endif
                        ))) {
          if (string_result == NULL)
            retval_int = ((INTPROCINT)ProcAddI)(argint);
          else
            retval_str = (ProcAddI)(argint);
        }
      }

      /* Save the string before we free the library. */
      /* Assume that a "1" or "-1" result is an illegal pointer. */
      if (string_result == NULL)
        *number_result = retval_int;
      else if (retval_str != NULL
               && retval_str != (char_u *)1
               && retval_str != (char_u *)-1)
        *string_result = vim_strsave(retval_str);
    }

# ifdef HAVE_SETJMP_H
    mch_endjmp();
#  ifdef SIGHASARG
    if (lc_signal != 0) {
      int i;

      /* try to find the name of this signal */
      for (i = 0; signal_info[i].sig != -1; i++)
        if (lc_signal == signal_info[i].sig)
          break;
      EMSG2("E368: got SIG%s in libcall()", signal_info[i].name);
    }
#  endif
# endif

# if defined(USE_DLOPEN)
    /* "dlerr" must be used before dlclose() */
    if (dlerr != NULL)
      EMSG2(_("dlerror = \"%s\""), dlerr);

    /* Free the DLL module. */
    (void)dlclose(hinstLib);
# else
    (void)shl_unload(hinstLib);
# endif
  }

  if (!success) {
    EMSG2(_(e_libcall), funcname);
    return FAIL;
  }

  return OK;
}
#endif





