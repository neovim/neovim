/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * misc2.c: Various functions.
 */
#include <string.h>

#include "nvim/vim.h"
#include "nvim/misc2.h"
#include "nvim/file_search.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memfile.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/ops.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/spell.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/tag.h"
#include "nvim/term.h"
#include "nvim/ui.h"
#include "nvim/window.h"
#include "nvim/os/os.h"
#include "nvim/os/shell.h"


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "misc2.c.generated.h"
#endif
/*
 * Return TRUE if in the current mode we need to use virtual.
 */
int virtual_active(void)
{
  /* While an operator is being executed we return "virtual_op", because
   * VIsual_active has already been reset, thus we can't check for "block"
   * being used. */
  if (virtual_op != MAYBE)
    return virtual_op;
  return ve_flags == VE_ALL
         || ((ve_flags & VE_BLOCK) && VIsual_active && VIsual_mode == Ctrl_V)
         || ((ve_flags & VE_INSERT) && (State & INSERT));
}

/*
 * Increment the line pointer "lp" crossing line boundaries as necessary.
 * Return 1 when going to the next line.
 * Return 2 when moving forward onto a NUL at the end of the line).
 * Return -1 when at the end of file.
 * Return 0 otherwise.
 */
int inc(pos_T *lp)
{
  char_u  *p = ml_get_pos(lp);

  if (*p != NUL) {      /* still within line, move to next char (may be NUL) */
    if (has_mbyte) {
      int l = (*mb_ptr2len)(p);

      lp->col += l;
      return (p[l] != NUL) ? 0 : 2;
    }
    lp->col++;
    lp->coladd = 0;
    return (p[1] != NUL) ? 0 : 2;
  }
  if (lp->lnum != curbuf->b_ml.ml_line_count) {     /* there is a next line */
    lp->col = 0;
    lp->lnum++;
    lp->coladd = 0;
    return 1;
  }
  return -1;
}

/*
 * incl(lp): same as inc(), but skip the NUL at the end of non-empty lines
 */
int incl(pos_T *lp)
{
  int r;

  if ((r = inc(lp)) >= 1 && lp->col)
    r = inc(lp);
  return r;
}

int dec(pos_T *lp)
{
  char_u      *p;

  lp->coladd = 0;
  if (lp->col > 0) {            /* still within line */
    lp->col--;
    if (has_mbyte) {
      p = ml_get(lp->lnum);
      lp->col -= (*mb_head_off)(p, p + lp->col);
    }
    return 0;
  }
  if (lp->lnum > 1) {           /* there is a prior line */
    lp->lnum--;
    p = ml_get(lp->lnum);
    lp->col = (colnr_T)STRLEN(p);
    if (has_mbyte)
      lp->col -= (*mb_head_off)(p, p + lp->col);
    return 1;
  }
  return -1;                    /* at start of file */
}

/*
 * decl(lp): same as dec(), but skip the NUL at the end of non-empty lines
 */
int decl(pos_T *lp)
{
  int r;

  if ((r = dec(lp)) == 1 && lp->col)
    r = dec(lp);
  return r;
}

/*
 * Return TRUE when 'shell' has "csh" in the tail.
 */
int csh_like_shell(void)
{
  return strstr((char *)path_tail(p_sh), "csh") != NULL;
}

/*
 * Isolate one part of a string option where parts are separated with
 * "sep_chars".
 * The part is copied into "buf[maxlen]".
 * "*option" is advanced to the next part.
 * The length is returned.
 */
int copy_option_part(char_u **option, char_u *buf, int maxlen, char *sep_chars)
{
  int len = 0;
  char_u  *p = *option;

  /* skip '.' at start of option part, for 'suffixes' */
  if (*p == '.')
    buf[len++] = *p++;
  while (*p != NUL && vim_strchr((char_u *)sep_chars, *p) == NULL) {
    /*
     * Skip backslash before a separator character and space.
     */
    if (p[0] == '\\' && vim_strchr((char_u *)sep_chars, p[1]) != NULL)
      ++p;
    if (len < maxlen - 1)
      buf[len++] = *p;
    ++p;
  }
  buf[len] = NUL;

  if (*p != NUL && *p != ',')   /* skip non-standard separator */
    ++p;
  p = skip_to_option_part(p);   /* p points to next file name */

  *option = p;
  return len;
}

/*
 * Return the current end-of-line type: EOL_DOS, EOL_UNIX or EOL_MAC.
 */
int get_fileformat(buf_T *buf)
{
  int c = *buf->b_p_ff;

  if (buf->b_p_bin || c == 'u')
    return EOL_UNIX;
  if (c == 'm')
    return EOL_MAC;
  return EOL_DOS;
}

/*
 * Like get_fileformat(), but override 'fileformat' with "p" for "++opt=val"
 * argument.
 */
int 
get_fileformat_force (
    buf_T *buf,
    exarg_T *eap           /* can be NULL! */
)
{
  int c;

  if (eap != NULL && eap->force_ff != 0)
    c = eap->cmd[eap->force_ff];
  else {
    if ((eap != NULL && eap->force_bin != 0)
        ? (eap->force_bin == FORCE_BIN) : buf->b_p_bin)
      return EOL_UNIX;
    c = *buf->b_p_ff;
  }
  if (c == 'u')
    return EOL_UNIX;
  if (c == 'm')
    return EOL_MAC;
  return EOL_DOS;
}

/// Set the current end-of-line type to EOL_UNIX, EOL_MAC, or EOL_DOS.
///
/// Sets 'fileformat'.
///
/// @param eol_style End-of-line style.
/// @param opt_flags OPT_LOCAL and/or OPT_GLOBAL
void set_fileformat(int eol_style, int opt_flags)
{
  char *p = NULL;

  switch (eol_style) {
      case EOL_UNIX:
          p = FF_UNIX;
          break;
      case EOL_MAC:
          p = FF_MAC;
          break;
      case EOL_DOS:
          p = FF_DOS;
          break;
  }

  // p is NULL if "eol_style" is EOL_UNKNOWN.
  if (p != NULL) {
    set_string_option_direct((char_u *)"ff",
                             -1,
                             (char_u *)p,
                             OPT_FREE | opt_flags,
                             0);
  }

  // This may cause the buffer to become (un)modified.
  check_status(curbuf);
  redraw_tabline = TRUE;
  need_maketitle = TRUE;  // Set window title later.
}

/*
 * Return the default fileformat from 'fileformats'.
 */
int default_fileformat(void)
{
  switch (*p_ffs) {
  case 'm':   return EOL_MAC;
  case 'd':   return EOL_DOS;
  }
  return EOL_UNIX;
}

/*
 * Call shell.	Calls mch_call_shell, with 'shellxquote' added.
 */
int call_shell(char_u *cmd, ShellOpts opts, char_u *extra_shell_arg)
{
  char_u      *ncmd;
  int retval;
  proftime_T wait_time;

  if (p_verbose > 3) {
    verbose_enter();
    smsg((char_u *)_("Calling shell to execute: \"%s\""),
        cmd == NULL ? p_sh : cmd);
    out_char('\n');
    cursor_on();
    verbose_leave();
  }

  if (do_profiling == PROF_YES)
    prof_child_enter(&wait_time);

  if (*p_sh == NUL) {
    EMSG(_(e_shellempty));
    retval = -1;
  } else {
    /* The external command may update a tags file, clear cached tags. */
    tag_freematch();

    if (cmd == NULL || *p_sxq == NUL)
      retval = os_call_shell(cmd, opts, extra_shell_arg);
    else {
      char_u *ecmd = cmd;

      if (*p_sxe != NUL && STRCMP(p_sxq, "(") == 0) {
        ecmd = vim_strsave_escaped_ext(cmd, p_sxe, '^', FALSE);
        if (ecmd == NULL)
          ecmd = cmd;
      }
      ncmd = xmalloc(STRLEN(ecmd) + STRLEN(p_sxq) * 2 + 1);
      STRCPY(ncmd, p_sxq);
      STRCAT(ncmd, ecmd);
      /* When 'shellxquote' is ( append ).
       * When 'shellxquote' is "( append )". */
      STRCAT(ncmd, STRCMP(p_sxq, "(") == 0 ? (char_u *)")"
          : STRCMP(p_sxq, "\"(") == 0 ? (char_u *)")\""
          : p_sxq);
      retval = os_call_shell(ncmd, opts, extra_shell_arg);
      free(ncmd);

      if (ecmd != cmd)
        free(ecmd);
    }
    /*
     * Check the window size, in case it changed while executing the
     * external command.
     */
    shell_resized_check();
  }

  set_vim_var_nr(VV_SHELL_ERROR, (long)retval);
  if (do_profiling == PROF_YES)
    prof_child_exit(&wait_time);

  return retval;
}

/*
 * VISUAL, SELECTMODE and OP_PENDING State are never set, they are equal to
 * NORMAL State with a condition.  This function returns the real State.
 */
int get_real_state(void)
{
  if (State & NORMAL) {
    if (VIsual_active) {
      if (VIsual_select)
        return SELECTMODE;
      return VISUAL;
    } else if (finish_op)
      return OP_PENDING;
  }
  return State;
}

/*
 * Change to a file's directory.
 * Caller must call shorten_fnames()!
 * Return OK or FAIL.
 */
int vim_chdirfile(char_u *fname)
{
  char_u dir[MAXPATHL];

  STRLCPY(dir, fname, MAXPATHL);
  *path_tail_with_sep(dir) = NUL;
  return os_chdir((char *)dir) == 0 ? OK : FAIL;
}

/*
 * Change directory to "new_dir". Search 'cdpath' for relative directory names.
 */
int vim_chdir(char_u *new_dir)
{
  char_u      *dir_name;
  int r;

  dir_name = find_directory_in_path(new_dir, (int)STRLEN(new_dir),
      FNAME_MESS, curbuf->b_ffname);
  if (dir_name == NULL)
    return -1;
  r = os_chdir((char *)dir_name);
  free(dir_name);
  return r;
}


/*
 * Print an error message with one or two "%s" and one or two string arguments.
 * This is not in message.c to avoid a warning for prototypes.
 */
int emsg3(char_u *s, char_u *a1, char_u *a2)
{
  if (emsg_not_now())
    return TRUE;                /* no error messages at the moment */
  vim_snprintf((char *)IObuff, IOSIZE, (char *)s, a1, a2);
  return emsg(IObuff);
}

/*
 * Print an error message with one "%" PRId64 and one (int64_t) argument.
 * This is not in message.c to avoid a warning for prototypes.
 */
int emsgn(char_u *s, int64_t n)
{
  if (emsg_not_now())
    return TRUE;                /* no error messages at the moment */
  vim_snprintf((char *)IObuff, IOSIZE, (char *)s, n);
  return emsg(IObuff);
}

/*
 * Print an error message with one "%" PRIu64 and one (uint64_t) argument.
 */
int emsgu(char_u *s, uint64_t n)
{
  if (emsg_not_now())
    return TRUE;                /* no error messages at the moment */
  vim_snprintf((char *)IObuff, IOSIZE, (char *)s, n);
  return emsg(IObuff);
}

/*
 * Read 2 bytes from "fd" and turn them into an int, MSB first.
 */
int get2c(FILE *fd)
{
  int n;

  n = getc(fd);
  n = (n << 8) + getc(fd);
  return n;
}

/*
 * Read 3 bytes from "fd" and turn them into an int, MSB first.
 */
int get3c(FILE *fd)
{
  int n;

  n = getc(fd);
  n = (n << 8) + getc(fd);
  n = (n << 8) + getc(fd);
  return n;
}

/*
 * Read 4 bytes from "fd" and turn them into an int, MSB first.
 */
int get4c(FILE *fd)
{
  /* Use unsigned rather than int otherwise result is undefined
   * when left-shift sets the MSB. */
  unsigned n;

  n = (unsigned)getc(fd);
  n = (n << 8) + (unsigned)getc(fd);
  n = (n << 8) + (unsigned)getc(fd);
  n = (n << 8) + (unsigned)getc(fd);
  return (int)n;
}

/*
 * Read 8 bytes from "fd" and turn them into a time_t, MSB first.
 */
time_t get8ctime(FILE *fd)
{
  time_t n = 0;
  int i;

  for (i = 0; i < 8; ++i)
    n = (n << 8) + getc(fd);
  return n;
}

/*
 * Read a string of length "cnt" from "fd" into allocated memory.
 * Returns NULL when unable to read that many bytes.
 */
char_u *read_string(FILE *fd, int cnt)
{
  int i;
  int c;

  char_u *str = xmallocz(cnt);
  /* Read the string.  Quit when running into the EOF. */
  for (i = 0; i < cnt; ++i) {
    c = getc(fd);
    if (c == EOF) {
      free(str);
      return NULL;
    }
    str[i] = c;
  }
  str[i] = NUL;

  return str;
}

/*
 * Write a number to file "fd", MSB first, in "len" bytes.
 */
int put_bytes(FILE *fd, long_u nr, int len)
{
  int i;

  for (i = len - 1; i >= 0; --i)
    if (putc((int)(nr >> (i * 8)), fd) == EOF)
      return FAIL;
  return OK;
}


/*
 * Write time_t to file "fd" in 8 bytes.
 */
void put_time(FILE *fd, time_t the_time)
{
  int c;
  int i;
  time_t wtime = the_time;

  /* time_t can be up to 8 bytes in size, more than long_u, thus we
   * can't use put_bytes() here.
   * Another problem is that ">>" may do an arithmetic shift that keeps the
   * sign.  This happens for large values of wtime.  A cast to long_u may
   * truncate if time_t is 8 bytes.  So only use a cast when it is 4 bytes,
   * it's safe to assume that long_u is 4 bytes or more and when using 8
   * bytes the top bit won't be set. */
  for (i = 7; i >= 0; --i) {
    if (i + 1 > (int)sizeof(time_t))
      /* ">>" doesn't work well when shifting more bits than avail */
      putc(0, fd);
    else {
#if defined(SIZEOF_TIME_T) && SIZEOF_TIME_T > 4
      c = (int)(wtime >> (i * 8));
#else
      c = (int)((long_u)wtime >> (i * 8));
#endif
      putc(c, fd);
    }
  }
}
