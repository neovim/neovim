#ifndef NVIM_OS_UNIX_DEFS_H
#define NVIM_OS_UNIX_DEFS_H

/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

/*
 * NextStep has a problem with configure, undefine a few things:
 */

#include <stdio.h>
#include <ctype.h>

# include <sys/types.h>
# include <sys/stat.h>

# include <stdlib.h>

#ifdef HAVE_UNISTD_H
# include <unistd.h>
#endif

#ifdef HAVE_SYS_PARAM_H
# include <sys/param.h>     /* defines BSD, if it's a BSD system */
#endif

/* The number of arguments to a signal handler is configured here. */
/* It used to be a long list of almost all systems. Any system that doesn't
 * have an argument??? */
#define SIGHASARG

/* List 3 arg systems here. I guess __sgi, please test and correct me. jw. */

#ifdef SIGHASARG
# ifdef SIGHAS3ARGS
#  define SIGDEFARG(s)  (int s, int sig2, struct sigcontext *scont)
#  define SIGDUMMYARG   0, 0, (struct sigcontext *)0
# else
#  define SIGDEFARG(s)  (int s)
#  define SIGDUMMYARG   0
# endif
#else
# define SIGDEFARG(s)  (void)
# define SIGDUMMYARG
#endif

#ifdef HAVE_DIRENT_H
# include <dirent.h>
# ifndef NAMLEN
#  define NAMLEN(dirent) strlen((dirent)->d_name)
# endif
#else
# define dirent direct
# define NAMLEN(dirent) (dirent)->d_namlen
# if HAVE_SYS_NDIR_H
#  include <sys/ndir.h>
# endif
# if HAVE_SYS_DIR_H
#  include <sys/dir.h>
# endif
# if HAVE_NDIR_H
#  include <ndir.h>
# endif
#endif

#if !defined(HAVE_SYS_TIME_H) || defined(TIME_WITH_SYS_TIME)
# include <time.h>          /* on some systems time.h should not be
                               included together with sys/time.h */
#endif
#ifdef HAVE_SYS_TIME_H
# include <sys/time.h>
#endif

#include <signal.h>

#if defined(DIRSIZ) && !defined(MAXNAMLEN)
# define MAXNAMLEN DIRSIZ
#endif

#if defined(UFS_MAXNAMLEN) && !defined(MAXNAMLEN)
# define MAXNAMLEN UFS_MAXNAMLEN    /* for dynix/ptx */
#endif

#if defined(NAME_MAX) && !defined(MAXNAMLEN)
# define MAXNAMLEN NAME_MAX         /* for Linux before .99p3 */
#endif

/*
 * Note: if MAXNAMLEN has the wrong value, you will get error messages
 *	 for not being able to open the swap file.
 */
#if !defined(MAXNAMLEN)
# define MAXNAMLEN 512              /* for all other Unix */
#endif

#define BASENAMELEN     (MAXNAMLEN - 5)

/*
 * Unix system-dependent file names
 */
#ifndef SYS_VIMRC_FILE
# define SYS_VIMRC_FILE "$VIM/nvimrc"
#endif
#ifndef SYS_GVIMRC_FILE
# define SYS_GVIMRC_FILE "$VIM/ngvimrc"
#endif
#ifndef DFLT_HELPFILE
# define DFLT_HELPFILE  "$VIMRUNTIME/doc/help.txt"
#endif
#ifndef FILETYPE_FILE
# define FILETYPE_FILE  "filetype.vim"
#endif
#ifndef FTPLUGIN_FILE
# define FTPLUGIN_FILE  "ftplugin.vim"
#endif
#ifndef INDENT_FILE
# define INDENT_FILE    "indent.vim"
#endif
#ifndef FTOFF_FILE
# define FTOFF_FILE     "ftoff.vim"
#endif
#ifndef FTPLUGOF_FILE
# define FTPLUGOF_FILE  "ftplugof.vim"
#endif
#ifndef INDOFF_FILE
# define INDOFF_FILE    "indoff.vim"
#endif
#ifndef SYS_MENU_FILE
# define SYS_MENU_FILE  "$VIMRUNTIME/menu.vim"
#endif

#ifndef USR_EXRC_FILE
#  define USR_EXRC_FILE "$HOME/.exrc"
#endif


#ifndef USR_VIMRC_FILE
#  define USR_VIMRC_FILE "$HOME/.nvimrc"
#endif


#if !defined(USR_EXRC_FILE2)
#    define USR_VIMRC_FILE2     "~/.nvim/nvimrc"
#endif


#ifndef USR_GVIMRC_FILE
#  define USR_GVIMRC_FILE "$HOME/.ngvimrc"
#endif

#ifndef USR_GVIMRC_FILE2
#   define USR_GVIMRC_FILE2     "~/.nvim/ngvimrc"
#endif


#ifndef EVIM_FILE
# define EVIM_FILE      "$VIMRUNTIME/evim.vim"
#endif

# ifndef VIMINFO_FILE
#   define VIMINFO_FILE "$HOME/.nviminfo"
# endif

#ifndef EXRC_FILE
# define EXRC_FILE      ".exrc"
#endif

#ifndef VIMRC_FILE
# define VIMRC_FILE     ".nvimrc"
#endif


#ifndef SYNTAX_FNAME
# define SYNTAX_FNAME   "$VIMRUNTIME/syntax/%s.vim"
#endif

#ifndef DFLT_BDIR
#   define DFLT_BDIR    ".,~/tmp,~/"    /* default for 'backupdir' */
#endif

#ifndef DFLT_DIR
#   define DFLT_DIR     ".,~/tmp,/var/tmp,/tmp" /* default for 'directory' */
#endif

#ifndef DFLT_VDIR
#   define DFLT_VDIR    "$HOME/.nvim/view"       /* default for 'viewdir' */
#endif

#define DFLT_ERRORFILE          "errors.err"

#  ifdef RUNTIME_GLOBAL
#   define DFLT_RUNTIMEPATH     "~/.nvim," RUNTIME_GLOBAL ",$VIMRUNTIME," \
  RUNTIME_GLOBAL "/after,~/.nvim/after"
#  else
#   define DFLT_RUNTIMEPATH \
  "~/.nvim,$VIM/vimfiles,$VIMRUNTIME,$VIM/vimfiles/after,~/.nvim/after"
#  endif

/* Special wildcards that need to be handled by the shell */
#define SPECIAL_WILDCHAR    "`'{"

#ifndef HAVE_OPENDIR
# define NO_EXPANDPATH
#endif

/*
 * Unix has plenty of memory, use large buffers
 */
#define CMDBUFFSIZE 1024        /* size of the command processing buffer */

/* Use the system path length if it makes sense. */
#if defined(PATH_MAX) && (PATH_MAX > 1000)
# define MAXPATHL       PATH_MAX
#else
# define MAXPATHL       1024
#endif

# ifndef DFLT_MAXMEM
#  define DFLT_MAXMEM   (5*1024)         /* use up to 5 Mbyte for a buffer */
# endif
# ifndef DFLT_MAXMEMTOT
#  define DFLT_MAXMEMTOT        (10*1024)    /* use up to 10 Mbyte for Vim */
# endif

#if !defined(S_ISDIR) && defined(S_IFDIR)
# define        S_ISDIR(m) (((m) & S_IFMT) == S_IFDIR)
#endif
#if !defined(S_ISREG) && defined(S_IFREG)
# define        S_ISREG(m) (((m) & S_IFMT) == S_IFREG)
#endif
#if !defined(S_ISBLK) && defined(S_IFBLK)
# define        S_ISBLK(m) (((m) & S_IFMT) == S_IFBLK)
#endif
#if !defined(S_ISSOCK) && defined(S_IFSOCK)
# define        S_ISSOCK(m) (((m) & S_IFMT) == S_IFSOCK)
#endif
#if !defined(S_ISFIFO) && defined(S_IFIFO)
# define        S_ISFIFO(m) (((m) & S_IFMT) == S_IFIFO)
#endif
#if !defined(S_ISCHR) && defined(S_IFCHR)
# define        S_ISCHR(m) (((m) & S_IFMT) == S_IFCHR)
#endif

/* Note: Some systems need both string.h and strings.h (Savage).  However,
 * some systems can't handle both, only use string.h in that case. */
# include <string.h>
#if defined(HAVE_STRINGS_H) && !defined(NO_STRINGS_WITH_STRING_H)
# include <strings.h>
#endif

#define HAVE_DUP                /* have dup() */

/* We have three kinds of ACL support. */
#define HAVE_ACL (HAVE_POSIX_ACL || HAVE_SOLARIS_ACL || HAVE_AIX_ACL)

#endif  // NVIM_OS_UNIX_DEFS_H
