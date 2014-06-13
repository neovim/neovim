/*
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

#include <string.h>

#include "nvim/api/private/handle.h"
#include "nvim/vim.h"
#include "nvim/os_unix.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/fileio.h"
#include "nvim/getchar.h"
#include "nvim/main.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/misc2.h"
#include "nvim/garray.h"
#include "nvim/path.h"
#include "nvim/screen.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/term.h"
#include "nvim/ui.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"
#include "nvim/os/event.h"
#include "nvim/os/input.h"
#include "nvim/os/shell.h"
#include "nvim/os/signal.h"
#include "nvim/os/job.h"

#if defined(HAVE_SYS_IOCTL_H)
# include <sys/ioctl.h>
#endif

#ifdef HAVE_STROPTS_H
# include <stropts.h>
#endif

#if defined(HAVE_TERMIOS_H)
# include <termios.h>
#endif

/* shared library access */
#if defined(HAVE_DLFCN_H) && defined(USE_DLOPEN)
# include <dlfcn.h>
#endif

#ifdef HAVE_SELINUX
# include <selinux/selinux.h>
static int selinux_enabled = -1;
#endif


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os_unix.c.generated.h"
#endif
static char_u   *oldtitle = NULL;
static int did_set_title = FALSE;
static char_u   *oldicon = NULL;
static int did_set_icon = FALSE;



/*
 * Write s[len] to the screen.
 */
void mch_write(char_u *s, int len)
{
  ignored = (int)write(1, (char *)s, len);
  if (p_wd)             /* Unix is too fast, slow down a bit more */
    os_microdelay(p_wd, false);
}

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
void mch_startjmp()
{
  lc_active = TRUE;
}

void mch_endjmp()
{
  lc_active = FALSE;
}

/*
 * If the machine has job control, use it to suspend the program,
 * otherwise fake it by starting a new shell.
 */
void mch_suspend()
{
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
      os_delay(wait_time, FALSE);
  }
# endif

  /*
   * Set oldtitle to NULL, so the current title is obtained again.
   */
  free(oldtitle);
  oldtitle = NULL;
  settmode(TMODE_RAW);
  need_check_timestamps = TRUE;
  did_check_timestamps = FALSE;
#endif
}

void mch_init()
{
  Columns = 80;
  Rows = 24;

  out_flush();

#ifdef MACOS_CONVERT
  mac_conv_init();
#endif

  event_init();
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


int mch_can_restore_title()
{
  return get_x11_title(TRUE);
}

int mch_can_restore_icon()
{
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
int use_xterm_mouse()
{
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

#if defined(USE_FNAME_CASE) || defined(PROTO)
/*
 * Set the case of the file name, if it already exists.  This will cause the
 * file name to remain exactly the same.
 * Only required for file systems where case is ignored and preserved.
 */
void fname_case(
char_u      *name,
int len               /* buffer size, only used when name gets longer */
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
    } else {
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
          STRLCPY(newname, name, MAXPATHL + 1);
          STRLCPY(newname + (tail - name), dp->d_name,
              MAXPATHL - (tail - name) + 1);
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

void mch_early_init()
{
  handle_init();
  time_init();
}

#if defined(EXITFREE) || defined(PROTO)
void mch_free_mem()          {
  free(oldtitle);
  free(oldicon);
}

#endif


/*
 * Output a newline when exiting.
 * Make sure the newline goes to the same stream as the text.
 */
static void exit_scroll()
{
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
  } else {
    restore_cterm_colors();             /* get original colors back */
    msg_clr_eos_force();                /* clear the rest of the display */
    windgoto((int)Rows - 1, 0);         /* may have moved the cursor */
  }
}

void mch_exit(int r)
{
  exiting = TRUE;

  event_teardown();

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

#ifdef MACOS_CONVERT
  mac_conv_cleanup();
#endif



#ifdef EXITFREE
  free_all_mem();
#endif

  exit(r);
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
void get_stty()
{
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
void mch_setmouse(int on)
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
  } else if (ttym_flags == TTYM_DEC) {
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
void check_mouse_termcode()
{
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
 * Try to get the current window size:
 * 1. with an ioctl(), most accurate method
 * 2. from the environment variables LINES and COLUMNS
 * 3. from the termcap
 * 4. keep using the old values
 * Return OK when size could be determined, FAIL otherwise.
 */
int mch_get_shellsize()
{
  long rows = 0;
  long columns = 0;
  char_u      *p;

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
    if ((p = (char_u *)os_getenv("LINES")))
      rows = atoi((char *)p);
    if ((p = (char_u *)os_getenv("COLUMNS")))
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
void mch_set_shellsize()
{
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

int mch_expand_wildcards(int num_pat, char_u **pat, int *num_file,
                         char_u ***file,
                         int flags /* EW_* flags */
                         )
{
  int i;
  size_t len;
  char_u      *p;
  bool dir;
  char_u *extra_shell_arg = NULL;
  ShellOpts shellopts = kShellOptExpand | kShellOptSilent;
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
  if (!have_wildcard(num_pat, pat)) {
    save_patterns(num_pat, pat, num_file, file);
    return OK;
  }

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
  if (shell_style == STYLE_ECHO && strstr((char *)path_tail(p_sh),
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
  command = xmalloc(len);

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
  } else {
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

  if (flags & EW_SILENT) {
    shellopts |= kShellOptHideMess;
  }

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
  i = call_shell(
      command,
      shellopts,
      extra_shell_arg
      );

  /* When running in the background, give it some time to create the temp
   * file, but don't wait for it to finish. */
  if (ampersent)
    os_delay(10L, TRUE);

  free(command);

  if (i != 0) {                         /* mch_call_shell() failed */
    os_remove((char *)tempname);
    free(tempname);
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
    free(tempname);
    goto notfound;
  }
  fseek(fd, 0L, SEEK_END);
  len = ftell(fd);                      /* get size of temp file */
  fseek(fd, 0L, SEEK_SET);
  buffer = xmalloc(len + 1);
  i = fread((char *)buffer, 1, len, fd);
  fclose(fd);
  os_remove((char *)tempname);
  if (i != (int)len) {
    /* unexpected read error */
    EMSG2(_(e_notread), tempname);
    free(tempname);
    free(buffer);
    return FAIL;
  }
  free(tempname);



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
    free(buffer);
    goto notfound;
  }
  *num_file = i;
  *file = (char_u **)xmalloc(sizeof(char_u *) * i);

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
    } else {          /* NUL separates */
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
    if (!(flags & EW_NOTFOUND) && !os_file_exists((*file)[i]))
      continue;

    /* check if this entry should be included */
    dir = (os_isdir((*file)[i]));
    if ((dir && !(flags & EW_DIR)) || (!dir && !(flags & EW_FILE)))
      continue;

    /* Skip files that are not executable if we check for that. */
    if (!dir && (flags & EW_EXEC) && !os_can_exe((*file)[i]))
      continue;

    p = xmalloc(STRLEN((*file)[i]) + 1 + dir);
    STRCPY(p, (*file)[i]);
    if (dir)
      add_pathsep(p);             /* add '/' to a directory name */
    (*file)[j++] = p;
  }
  free(buffer);
  *num_file = j;

  if (*num_file == 0) {     /* rejected all entries */
    free(*file);
    *file = NULL;
    goto notfound;
  }

  return OK;

notfound:
  if (flags & EW_NOTFOUND) {
    save_patterns(num_pat, pat, num_file, file);
    return OK;
  }
  return FAIL;

}


static void save_patterns(int num_pat, char_u **pat, int *num_file,
                          char_u ***file)
{
  int i;
  char_u      *s;

  *file = xmalloc((size_t)num_pat * sizeof(char_u *));

  for (i = 0; i < num_pat; i++) {
    s = vim_strsave(pat[i]);
    /* Be compatible with expand_filename(): halve the number of
     * backslashes. */
    backslash_halve(s);
    (*file)[i] = s;
  }
  *num_file = num_pat;
}

/*
 * Return TRUE if the string "p" contains a wildcard that mch_expandpath() can
 * expand.
 */
int mch_has_exp_wildcard(char_u *p)
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
int mch_has_wildcard(char_u *p)
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

static int have_wildcard(int num, char_u **file)
{
  int i;

  for (i = 0; i < num; i++)
    if (mch_has_wildcard(file[i]))
      return 1;
  return 0;
}

static int have_dollars(int num, char_u **file)
{
  int i;

  for (i = 0; i < num; i++)
    if (vim_strchr(file[i], '$') != NULL)
      return TRUE;
  return FALSE;
}

#if defined(FEAT_LIBCALL) || defined(PROTO)
typedef char_u * (*STRPROCSTR)(char_u *);
typedef char_u * (*INTPROCSTR)(int);
typedef int (*STRPROCINT)(char_u *);
typedef int (*INTPROCINT)(int);

/*
 * Call a DLL routine which takes either a string or int param
 * and returns an allocated string.
 */
int mch_libcall(char_u *libname,
                char_u *funcname,
                char_u *argstring,         /* NULL when using an argint */
                int argint,
                char_u **string_result,    /* NULL when using number_result */
                int *number_result)
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
    /*
     * Catch a crash when calling the library function.  For example when
     * using a number where a string pointer is expected.
     */
    mch_startjmp();
    if (SETJMP(lc_jump_env) != 0) {
      success = FALSE;
# if defined(USE_DLOPEN)
      dlerr = NULL;
# endif
    } else
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
      } else {
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

    mch_endjmp();
# ifdef SIGHASARG
    if (lc_signal != 0) {
      int i;

      /* try to find the name of this signal */
      for (i = 0; signal_info[i].sig != -1; i++)
        if (lc_signal == signal_info[i].sig)
          break;
      EMSG2("E368: got SIG%s in libcall()", signal_info[i].name);
    }
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



