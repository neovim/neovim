/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * fileio.c: read from and write to a file
 */

#include "vim.h"
#include "fileio.h"
#include "blowfish.h"
#include "buffer.h"
#include "charset.h"
#include "diff.h"
#include "edit.h"
#include "eval.h"
#include "ex_cmds.h"
#include "ex_docmd.h"
#include "ex_eval.h"
#include "fold.h"
#include "getchar.h"
#include "hashtab.h"
#include "mbyte.h"
#include "memfile.h"
#include "memline.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"
#include "garray.h"
#include "move.h"
#include "option.h"
#include "os_unix.h"
#include "quickfix.h"
#include "regexp.h"
#include "screen.h"
#include "search.h"
#include "sha256.h"
#include "term.h"
#include "ui.h"
#include "undo.h"
#include "window.h"
#include "os/os.h"


#if defined(HAVE_UTIME) && defined(HAVE_UTIME_H)
# include <utime.h>             /* for struct utimbuf */
#endif

#define BUFSIZE         8192    /* size of normal write buffer */
#define SMBUFSIZE       256     /* size of emergency write buffer */

/* crypt_magic[0] is pkzip crypt, crypt_magic[1] is sha2+blowfish */
static char     *crypt_magic[] = {"VimCrypt~01!", "VimCrypt~02!"};
static char crypt_magic_head[] = "VimCrypt~";
# define CRYPT_MAGIC_LEN        12              /* must be multiple of 4! */

/* For blowfish, after the magic header, we store 8 bytes of salt and then 8
 * bytes of seed (initialisation vector). */
static int crypt_salt_len[] = {0, 8};
static int crypt_seed_len[] = {0, 8};
#define CRYPT_SALT_LEN_MAX 8
#define CRYPT_SEED_LEN_MAX 8

/* Is there any system that doesn't have access()? */
#define USE_MCH_ACCESS

static char_u *next_fenc(char_u **pp);
static char_u *readfile_charconvert(char_u *fname, char_u *fenc,
                                            int *fdp);
static void check_marks_read(void);
static int crypt_method_from_magic(char *ptr, int len);
static char_u *check_for_cryptkey(char_u *cryptkey, char_u *ptr,
                                  long *sizep, off_t *filesizep,
                                  int newfile, char_u *fname,
                                  int *did_ask);
#ifdef UNIX
static void set_file_time(char_u *fname, time_t atime, time_t mtime);
#endif
static int set_rw_fname(char_u *fname, char_u *sfname);
static int msg_add_fileformat(int eol_type);
static void msg_add_eol(void);
static int check_mtime(buf_T *buf, struct stat *s);
static int time_differs(long t1, long t2);
static int apply_autocmds_exarg(event_T event, char_u *fname, char_u *fname_io,
                                int force, buf_T *buf,
                                exarg_T *eap);
static int au_find_group(char_u *name);

# define AUGROUP_DEFAULT    -1      /* default autocmd group */
# define AUGROUP_ERROR      -2      /* erroneous autocmd group */
# define AUGROUP_ALL        -3      /* all autocmd groups */

# define HAS_BW_FLAGS
# define FIO_LATIN1     0x01    /* convert Latin1 */
# define FIO_UTF8       0x02    /* convert UTF-8 */
# define FIO_UCS2       0x04    /* convert UCS-2 */
# define FIO_UCS4       0x08    /* convert UCS-4 */
# define FIO_UTF16      0x10    /* convert UTF-16 */
# define FIO_ENDIAN_L   0x80    /* little endian */
# define FIO_ENCRYPTED  0x1000  /* encrypt written bytes */
# define FIO_NOCONVERT  0x2000  /* skip encoding conversion */
# define FIO_UCSBOM     0x4000  /* check for BOM at start of file */
# define FIO_ALL        -1      /* allow all formats */

/* When converting, a read() or write() may leave some bytes to be converted
 * for the next call.  The value is guessed... */
#define CONV_RESTLEN 30

/* We have to guess how much a sequence of bytes may expand when converting
 * with iconv() to be able to allocate a buffer. */
#define ICONV_MULT 8

/*
 * Structure to pass arguments from buf_write() to buf_write_bytes().
 */
struct bw_info {
  int bw_fd;                    /* file descriptor */
  char_u      *bw_buf;          /* buffer with data to be written */
  int bw_len;                   /* length of data */
#ifdef HAS_BW_FLAGS
  int bw_flags;                 /* FIO_ flags */
#endif
  char_u bw_rest[CONV_RESTLEN];        /* not converted bytes */
  int bw_restlen;               /* nr of bytes in bw_rest[] */
  int bw_first;                 /* first write call */
  char_u      *bw_conv_buf;     /* buffer for writing converted chars */
  int bw_conv_buflen;           /* size of bw_conv_buf */
  int bw_conv_error;            /* set for conversion error */
  linenr_T bw_conv_error_lnum;       /* first line with error or zero */
  linenr_T bw_start_lnum;       /* line number at start of buffer */
# ifdef USE_ICONV
  iconv_t bw_iconv_fd;          /* descriptor for iconv() or -1 */
# endif
};

static int buf_write_bytes(struct bw_info *ip);

static linenr_T readfile_linenr(linenr_T linecnt, char_u *p,
                                char_u *endp);
static int ucs2bytes(unsigned c, char_u **pp, int flags);
static int need_conversion(char_u *fenc);
static int get_fio_flags(char_u *ptr);
static char_u *check_for_bom(char_u *p, long size, int *lenp, int flags);
static int make_bom(char_u *buf, char_u *name);
static int move_lines(buf_T *frombuf, buf_T *tobuf);
#ifdef TEMPDIRNAMES
static void vim_settempdir(char_u *tempdir);
#endif
static char *e_auchangedbuf = N_(
    "E812: Autocommands changed buffer or buffer name");

void filemess(buf_T *buf, char_u *name, char_u *s, int attr)
{
  int msg_scroll_save;

  if (msg_silent != 0)
    return;
  msg_add_fname(buf, name);         /* put file name in IObuff with quotes */
  /* If it's extremely long, truncate it. */
  if (STRLEN(IObuff) > IOSIZE - 80)
    IObuff[IOSIZE - 80] = NUL;
  STRCAT(IObuff, s);
  /*
   * For the first message may have to start a new line.
   * For further ones overwrite the previous one, reset msg_scroll before
   * calling filemess().
   */
  msg_scroll_save = msg_scroll;
  if (shortmess(SHM_OVERALL) && !exiting && p_verbose == 0)
    msg_scroll = FALSE;
  if (!msg_scroll)      /* wait a bit when overwriting an error msg */
    check_for_delay(FALSE);
  msg_start();
  msg_scroll = msg_scroll_save;
  msg_scrolled_ign = TRUE;
  /* may truncate the message to avoid a hit-return prompt */
  msg_outtrans_attr(msg_may_trunc(FALSE, IObuff), attr);
  msg_clr_eos();
  out_flush();
  msg_scrolled_ign = FALSE;
}

/*
 * Read lines from file "fname" into the buffer after line "from".
 *
 * 1. We allocate blocks with lalloc, as big as possible.
 * 2. Each block is filled with characters from the file with a single read().
 * 3. The lines are inserted in the buffer with ml_append().
 *
 * (caller must check that fname != NULL, unless READ_STDIN is used)
 *
 * "lines_to_skip" is the number of lines that must be skipped
 * "lines_to_read" is the number of lines that are appended
 * When not recovering lines_to_skip is 0 and lines_to_read MAXLNUM.
 *
 * flags:
 * READ_NEW	starting to edit a new buffer
 * READ_FILTER	reading filter output
 * READ_STDIN	read from stdin instead of a file
 * READ_BUFFER	read from curbuf instead of a file (converting after reading
 *		stdin)
 * READ_DUMMY	read into a dummy buffer (to check if file contents changed)
 * READ_KEEP_UNDO  don't clear undo info or read it from a file
 *
 * return FAIL for failure, OK otherwise
 */
int 
readfile (
    char_u *fname,
    char_u *sfname,
    linenr_T from,
    linenr_T lines_to_skip,
    linenr_T lines_to_read,
    exarg_T *eap,                       /* can be NULL! */
    int flags
)
{
  int fd = 0;
  int newfile = (flags & READ_NEW);
  int check_readonly;
  int filtering = (flags & READ_FILTER);
  int read_stdin = (flags & READ_STDIN);
  int read_buffer = (flags & READ_BUFFER);
  int set_options = newfile || read_buffer
                    || (eap != NULL && eap->read_edit);
  linenr_T read_buf_lnum = 1;           /* next line to read from curbuf */
  colnr_T read_buf_col = 0;             /* next char to read from this line */
  char_u c;
  linenr_T lnum = from;
  char_u      *ptr = NULL;              /* pointer into read buffer */
  char_u      *buffer = NULL;           /* read buffer */
  char_u      *new_buffer = NULL;       /* init to shut up gcc */
  char_u      *line_start = NULL;       /* init to shut up gcc */
  int wasempty;                         /* buffer was empty before reading */
  colnr_T len;
  long size = 0;
  char_u      *p;
  off_t filesize = 0;
  int skip_read = FALSE;
  char_u      *cryptkey = NULL;
  int did_ask_for_key = FALSE;
  int crypt_method_used;
  context_sha256_T sha_ctx;
  int read_undo_file = FALSE;
  int split = 0;                        /* number of split lines */
#define UNKNOWN  0x0fffffff             /* file size is unknown */
  linenr_T linecnt;
  int error = FALSE;                    /* errors encountered */
  int ff_error = EOL_UNKNOWN;           /* file format with errors */
  long linerest = 0;                    /* remaining chars in line */
#ifdef UNIX
  int perm = 0;
  int swap_mode = -1;                   /* protection bits for swap file */
#else
  int perm;
#endif
  int fileformat = 0;                   /* end-of-line format */
  int keep_fileformat = FALSE;
  struct stat st;
  int file_readonly;
  linenr_T skip_count = 0;
  linenr_T read_count = 0;
  int msg_save = msg_scroll;
  linenr_T read_no_eol_lnum = 0;        /* non-zero lnum when last line of
                                        * last read was missing the eol */
  int try_mac = (vim_strchr(p_ffs, 'm') != NULL);
  int try_dos = (vim_strchr(p_ffs, 'd') != NULL);
  int try_unix = (vim_strchr(p_ffs, 'x') != NULL);
  int file_rewind = FALSE;
  int can_retry;
  linenr_T conv_error = 0;              /* line nr with conversion error */
  linenr_T illegal_byte = 0;            /* line nr with illegal byte */
  int keep_dest_enc = FALSE;            /* don't retry when char doesn't fit
                                           in destination encoding */
  int bad_char_behavior = BAD_REPLACE;
  /* BAD_KEEP, BAD_DROP or character to
   * replace with */
  char_u      *tmpname = NULL;          /* name of 'charconvert' output file */
  int fio_flags = 0;
  char_u      *fenc;                    /* fileencoding to use */
  int fenc_alloced;                     /* fenc_next is in allocated memory */
  char_u      *fenc_next = NULL;        /* next item in 'fencs' or NULL */
  int advance_fenc = FALSE;
  long real_size = 0;
# ifdef USE_ICONV
  iconv_t iconv_fd = (iconv_t)-1;       /* descriptor for iconv() or -1 */
  int did_iconv = FALSE;                /* TRUE when iconv() failed and trying
                                           'charconvert' next */
# endif
  int converted = FALSE;                /* TRUE if conversion done */
  int notconverted = FALSE;             /* TRUE if conversion wanted but it
                                           wasn't possible */
  char_u conv_rest[CONV_RESTLEN];
  int conv_restlen = 0;                 /* nr of bytes in conv_rest[] */
  buf_T       *old_curbuf;
  char_u      *old_b_ffname;
  char_u      *old_b_fname;
  int using_b_ffname;
  int using_b_fname;

  curbuf->b_no_eol_lnum = 0;    /* in case it was set by the previous read */

  /*
   * If there is no file name yet, use the one for the read file.
   * BF_NOTEDITED is set to reflect this.
   * Don't do this for a read from a filter.
   * Only do this when 'cpoptions' contains the 'f' flag.
   */
  if (curbuf->b_ffname == NULL
      && !filtering
      && fname != NULL
      && vim_strchr(p_cpo, CPO_FNAMER) != NULL
      && !(flags & READ_DUMMY)) {
    if (set_rw_fname(fname, sfname) == FAIL)
      return FAIL;
  }

  /* Remember the initial values of curbuf, curbuf->b_ffname and
   * curbuf->b_fname to detect whether they are altered as a result of
   * executing nasty autocommands.  Also check if "fname" and "sfname"
   * point to one of these values. */
  old_curbuf = curbuf;
  old_b_ffname = curbuf->b_ffname;
  old_b_fname = curbuf->b_fname;
  using_b_ffname = (fname == curbuf->b_ffname)
                   || (sfname == curbuf->b_ffname);
  using_b_fname = (fname == curbuf->b_fname) || (sfname == curbuf->b_fname);

  /* After reading a file the cursor line changes but we don't want to
   * display the line. */
  ex_no_reprint = TRUE;

  /* don't display the file info for another buffer now */
  need_fileinfo = FALSE;

  /*
   * For Unix: Use the short file name whenever possible.
   * Avoids problems with networks and when directory names are changed.
   * Don't do this for MS-DOS, a "cd" in a sub-shell may have moved us to
   * another directory, which we don't detect.
   */
  if (sfname == NULL)
    sfname = fname;
#if defined(UNIX) || defined(__EMX__)
  fname = sfname;
#endif

  /*
   * The BufReadCmd and FileReadCmd events intercept the reading process by
   * executing the associated commands instead.
   */
  if (!filtering && !read_stdin && !read_buffer) {
    pos_T pos;

    pos = curbuf->b_op_start;

    /* Set '[ mark to the line above where the lines go (line 1 if zero). */
    curbuf->b_op_start.lnum = ((from == 0) ? 1 : from);
    curbuf->b_op_start.col = 0;

    if (newfile) {
      if (apply_autocmds_exarg(EVENT_BUFREADCMD, NULL, sfname,
              FALSE, curbuf, eap))
        return aborting() ? FAIL : OK;
    } else if (apply_autocmds_exarg(EVENT_FILEREADCMD, sfname, sfname,
                   FALSE, NULL, eap))
      return aborting() ? FAIL : OK;

    curbuf->b_op_start = pos;
  }

  if ((shortmess(SHM_OVER) || curbuf->b_help) && p_verbose == 0)
    msg_scroll = FALSE;         /* overwrite previous file message */
  else
    msg_scroll = TRUE;          /* don't overwrite previous file message */

  /*
   * If the name ends in a path separator, we can't open it.  Check here,
   * because reading the file may actually work, but then creating the swap
   * file may destroy it!  Reported on MS-DOS and Win 95.
   * If the name is too long we might crash further on, quit here.
   */
  if (fname != NULL && *fname != NUL) {
    p = fname + STRLEN(fname);
    if (after_pathsep(fname, p) || STRLEN(fname) >= MAXPATHL) {
      filemess(curbuf, fname, (char_u *)_("Illegal file name"), 0);
      msg_end();
      msg_scroll = msg_save;
      return FAIL;
    }
  }

  if (!read_stdin && !read_buffer) {
#ifdef UNIX
    /*
     * On Unix it is possible to read a directory, so we have to
     * check for it before the mch_open().
     */
    perm = mch_getperm(fname);
    if (perm >= 0 && !S_ISREG(perm)                 /* not a regular file ... */
# ifdef S_ISFIFO
        && !S_ISFIFO(perm)                          /* ... or fifo */
# endif
# ifdef S_ISSOCK
        && !S_ISSOCK(perm)                          /* ... or socket */
# endif
# ifdef OPEN_CHR_FILES
        && !(S_ISCHR(perm) && is_dev_fd_file(fname))
        /* ... or a character special file named /dev/fd/<n> */
# endif
        ) {
      if (S_ISDIR(perm))
        filemess(curbuf, fname, (char_u *)_("is a directory"), 0);
      else
        filemess(curbuf, fname, (char_u *)_("is not a file"), 0);
      msg_end();
      msg_scroll = msg_save;
      return FAIL;
    }
#endif
  }

  /* Set default or forced 'fileformat' and 'binary'. */
  set_file_options(set_options, eap);

  /*
   * When opening a new file we take the readonly flag from the file.
   * Default is r/w, can be set to r/o below.
   * Don't reset it when in readonly mode
   * Only set/reset b_p_ro when BF_CHECK_RO is set.
   */
  check_readonly = (newfile && (curbuf->b_flags & BF_CHECK_RO));
  if (check_readonly && !readonlymode)
    curbuf->b_p_ro = FALSE;

  if (newfile && !read_stdin && !read_buffer) {
    /* Remember time of file. */
    if (mch_stat((char *)fname, &st) >= 0) {
      buf_store_time(curbuf, &st, fname);
      curbuf->b_mtime_read = curbuf->b_mtime;
#ifdef UNIX
      /*
       * Use the protection bits of the original file for the swap file.
       * This makes it possible for others to read the name of the
       * edited file from the swapfile, but only if they can read the
       * edited file.
       * Remove the "write" and "execute" bits for group and others
       * (they must not write the swapfile).
       * Add the "read" and "write" bits for the user, otherwise we may
       * not be able to write to the file ourselves.
       * Setting the bits is done below, after creating the swap file.
       */
      swap_mode = (st.st_mode & 0644) | 0600;
#endif
    } else   {
      curbuf->b_mtime = 0;
      curbuf->b_mtime_read = 0;
      curbuf->b_orig_size = 0;
      curbuf->b_orig_mode = 0;
    }

    /* Reset the "new file" flag.  It will be set again below when the
     * file doesn't exist. */
    curbuf->b_flags &= ~(BF_NEW | BF_NEW_W);
  }

  /*
   * for UNIX: check readonly with perm and mch_access()
   * for MSDOS and Amiga: check readonly by trying to open the file for writing
   */
  file_readonly = FALSE;
  if (read_stdin) {
  } else if (!read_buffer)   {
#ifdef USE_MCH_ACCESS
    if (
# ifdef UNIX
      !(perm & 0222) ||
# endif
      mch_access((char *)fname, W_OK))
      file_readonly = TRUE;
    fd = mch_open((char *)fname, O_RDONLY | O_EXTRA, 0);
#else
    if (!newfile
        || readonlymode
        || (fd = mch_open((char *)fname, O_RDWR | O_EXTRA, 0)) < 0) {
      file_readonly = TRUE;
      /* try to open ro */
      fd = mch_open((char *)fname, O_RDONLY | O_EXTRA, 0);
    }
#endif
  }

  if (fd < 0) {                     /* cannot open at all */
#ifndef UNIX
    int isdir_f;
#endif
    msg_scroll = msg_save;
#ifndef UNIX
    /*
     * On MSDOS and Amiga we can't open a directory, check here.
     */
    isdir_f = (mch_isdir(fname));
    perm = mch_getperm(fname);      /* check if the file exists */
    if (isdir_f) {
      filemess(curbuf, sfname, (char_u *)_("is a directory"), 0);
      curbuf->b_p_ro = TRUE;            /* must use "w!" now */
    } else
#endif
    if (newfile) {
      if (perm < 0
#ifdef ENOENT
          && errno == ENOENT
#endif
          ) {
        /*
         * Set the 'new-file' flag, so that when the file has
         * been created by someone else, a ":w" will complain.
         */
        curbuf->b_flags |= BF_NEW;

        /* Create a swap file now, so that other Vims are warned
         * that we are editing this file.  Don't do this for a
         * "nofile" or "nowrite" buffer type. */
        if (!bt_dontwrite(curbuf)) {
          check_need_swap(newfile);
          /* SwapExists autocommand may mess things up */
          if (curbuf != old_curbuf
              || (using_b_ffname
                  && (old_b_ffname != curbuf->b_ffname))
              || (using_b_fname
                  && (old_b_fname != curbuf->b_fname))) {
            EMSG(_(e_auchangedbuf));
            return FAIL;
          }
        }
        if (dir_of_file_exists(fname))
          filemess(curbuf, sfname, (char_u *)_("[New File]"), 0);
        else
          filemess(curbuf, sfname,
              (char_u *)_("[New DIRECTORY]"), 0);
        /* Even though this is a new file, it might have been
         * edited before and deleted.  Get the old marks. */
        check_marks_read();
        /* Set forced 'fileencoding'.  */
        if (eap != NULL)
          set_forced_fenc(eap);
        apply_autocmds_exarg(EVENT_BUFNEWFILE, sfname, sfname,
            FALSE, curbuf, eap);
        /* remember the current fileformat */
        save_file_ff(curbuf);

        if (aborting())               /* autocmds may abort script processing */
          return FAIL;
        return OK;                  /* a new file is not an error */
      } else   {
        filemess(curbuf, sfname, (char_u *)(
# ifdef EFBIG
              (errno == EFBIG) ? _("[File too big]") :
# endif
# ifdef EOVERFLOW
              (errno == EOVERFLOW) ? _("[File too big]") :
# endif
              _("[Permission Denied]")), 0);
        curbuf->b_p_ro = TRUE;                  /* must use "w!" now */
      }
    }

    return FAIL;
  }

  /*
   * Only set the 'ro' flag for readonly files the first time they are
   * loaded.	Help files always get readonly mode
   */
  if ((check_readonly && file_readonly) || curbuf->b_help)
    curbuf->b_p_ro = TRUE;

  if (set_options) {
    /* Don't change 'eol' if reading from buffer as it will already be
     * correctly set when reading stdin. */
    if (!read_buffer) {
      curbuf->b_p_eol = TRUE;
      curbuf->b_start_eol = TRUE;
    }
    curbuf->b_p_bomb = FALSE;
    curbuf->b_start_bomb = FALSE;
  }

  /* Create a swap file now, so that other Vims are warned that we are
   * editing this file.
   * Don't do this for a "nofile" or "nowrite" buffer type. */
  if (!bt_dontwrite(curbuf)) {
    check_need_swap(newfile);
    if (!read_stdin && (curbuf != old_curbuf
                        || (using_b_ffname && (old_b_ffname != curbuf->b_ffname))
                        || (using_b_fname &&
                            (old_b_fname != curbuf->b_fname)))) {
      EMSG(_(e_auchangedbuf));
      if (!read_buffer)
        close(fd);
      return FAIL;
    }
#ifdef UNIX
    /* Set swap file protection bits after creating it. */
    if (swap_mode > 0 && curbuf->b_ml.ml_mfp != NULL
        && curbuf->b_ml.ml_mfp->mf_fname != NULL)
      (void)mch_setperm(curbuf->b_ml.ml_mfp->mf_fname, (long)swap_mode);
#endif
  }

#if defined(HAS_SWAP_EXISTS_ACTION)
  /* If "Quit" selected at ATTENTION dialog, don't load the file */
  if (swap_exists_action == SEA_QUIT) {
    if (!read_buffer && !read_stdin)
      close(fd);
    return FAIL;
  }
#endif

  ++no_wait_return;         /* don't wait for return yet */

  /*
   * Set '[ mark to the line above where the lines go (line 1 if zero).
   */
  curbuf->b_op_start.lnum = ((from == 0) ? 1 : from);
  curbuf->b_op_start.col = 0;

  if (!read_buffer) {
    int m = msg_scroll;
    int n = msg_scrolled;

    /*
     * The file must be closed again, the autocommands may want to change
     * the file before reading it.
     */
    if (!read_stdin)
      close(fd);                /* ignore errors */

    /*
     * The output from the autocommands should not overwrite anything and
     * should not be overwritten: Set msg_scroll, restore its value if no
     * output was done.
     */
    msg_scroll = TRUE;
    if (filtering)
      apply_autocmds_exarg(EVENT_FILTERREADPRE, NULL, sfname,
          FALSE, curbuf, eap);
    else if (read_stdin)
      apply_autocmds_exarg(EVENT_STDINREADPRE, NULL, sfname,
          FALSE, curbuf, eap);
    else if (newfile)
      apply_autocmds_exarg(EVENT_BUFREADPRE, NULL, sfname,
          FALSE, curbuf, eap);
    else
      apply_autocmds_exarg(EVENT_FILEREADPRE, sfname, sfname,
          FALSE, NULL, eap);
    if (msg_scrolled == n)
      msg_scroll = m;

    if (aborting()) {       /* autocmds may abort script processing */
      --no_wait_return;
      msg_scroll = msg_save;
      curbuf->b_p_ro = TRUE;            /* must use "w!" now */
      return FAIL;
    }
    /*
     * Don't allow the autocommands to change the current buffer.
     * Try to re-open the file.
     *
     * Don't allow the autocommands to change the buffer name either
     * (cd for example) if it invalidates fname or sfname.
     */
    if (!read_stdin && (curbuf != old_curbuf
                        || (using_b_ffname && (old_b_ffname != curbuf->b_ffname))
                        || (using_b_fname && (old_b_fname != curbuf->b_fname))
                        || (fd =
                              mch_open((char *)fname, O_RDONLY | O_EXTRA,
                                  0)) < 0)) {
      --no_wait_return;
      msg_scroll = msg_save;
      if (fd < 0)
        EMSG(_("E200: *ReadPre autocommands made the file unreadable"));
      else
        EMSG(_("E201: *ReadPre autocommands must not change current buffer"));
      curbuf->b_p_ro = TRUE;            /* must use "w!" now */
      return FAIL;
    }
  }

  /* Autocommands may add lines to the file, need to check if it is empty */
  wasempty = (curbuf->b_ml.ml_flags & ML_EMPTY);

  if (!recoverymode && !filtering && !(flags & READ_DUMMY)) {
    /*
     * Show the user that we are busy reading the input.  Sometimes this
     * may take a while.  When reading from stdin another program may
     * still be running, don't move the cursor to the last line, unless
     * always using the GUI.
     */
    if (read_stdin) {
      mch_msg(_("Vim: Reading from stdin...\n"));
    } else if (!read_buffer)
      filemess(curbuf, sfname, (char_u *)"", 0);
  }

  msg_scroll = FALSE;                   /* overwrite the file message */

  /*
   * Set linecnt now, before the "retry" caused by a wrong guess for
   * fileformat, and after the autocommands, which may change them.
   */
  linecnt = curbuf->b_ml.ml_line_count;

  /* "++bad=" argument. */
  if (eap != NULL && eap->bad_char != 0) {
    bad_char_behavior = eap->bad_char;
    if (set_options)
      curbuf->b_bad_char = eap->bad_char;
  } else
    curbuf->b_bad_char = 0;

  /*
   * Decide which 'encoding' to use or use first.
   */
  if (eap != NULL && eap->force_enc != 0) {
    fenc = enc_canonize(eap->cmd + eap->force_enc);
    fenc_alloced = TRUE;
    keep_dest_enc = TRUE;
  } else if (curbuf->b_p_bin)   {
    fenc = (char_u *)"";                /* binary: don't convert */
    fenc_alloced = FALSE;
  } else if (curbuf->b_help)   {
    char_u firstline[80];
    int fc;

    /* Help files are either utf-8 or latin1.  Try utf-8 first, if this
     * fails it must be latin1.
     * Always do this when 'encoding' is "utf-8".  Otherwise only do
     * this when needed to avoid [converted] remarks all the time.
     * It is needed when the first line contains non-ASCII characters.
     * That is only in *.??x files. */
    fenc = (char_u *)"latin1";
    c = enc_utf8;
    if (!c && !read_stdin) {
      fc = fname[STRLEN(fname) - 1];
      if (TOLOWER_ASC(fc) == 'x') {
        /* Read the first line (and a bit more).  Immediately rewind to
         * the start of the file.  If the read() fails "len" is -1. */
        len = read_eintr(fd, firstline, 80);
        lseek(fd, (off_t)0L, SEEK_SET);
        for (p = firstline; p < firstline + len; ++p)
          if (*p >= 0x80) {
            c = TRUE;
            break;
          }
      }
    }

    if (c) {
      fenc_next = fenc;
      fenc = (char_u *)"utf-8";

      /* When the file is utf-8 but a character doesn't fit in
       * 'encoding' don't retry.  In help text editing utf-8 bytes
       * doesn't make sense. */
      if (!enc_utf8)
        keep_dest_enc = TRUE;
    }
    fenc_alloced = FALSE;
  } else if (*p_fencs == NUL)   {
    fenc = curbuf->b_p_fenc;            /* use format from buffer */
    fenc_alloced = FALSE;
  } else   {
    fenc_next = p_fencs;                /* try items in 'fileencodings' */
    fenc = next_fenc(&fenc_next);
    fenc_alloced = TRUE;
  }

  /*
   * Jump back here to retry reading the file in different ways.
   * Reasons to retry:
   * - encoding conversion failed: try another one from "fenc_next"
   * - BOM detected and fenc was set, need to setup conversion
   * - "fileformat" check failed: try another
   *
   * Variables set for special retry actions:
   * "file_rewind"	Rewind the file to start reading it again.
   * "advance_fenc"	Advance "fenc" using "fenc_next".
   * "skip_read"	Re-use already read bytes (BOM detected).
   * "did_iconv"	iconv() conversion failed, try 'charconvert'.
   * "keep_fileformat" Don't reset "fileformat".
   *
   * Other status indicators:
   * "tmpname"	When != NULL did conversion with 'charconvert'.
   *			Output file has to be deleted afterwards.
   * "iconv_fd"	When != -1 did conversion with iconv().
   */
retry:

  if (file_rewind) {
    if (read_buffer) {
      read_buf_lnum = 1;
      read_buf_col = 0;
    } else if (read_stdin || lseek(fd, (off_t)0L, SEEK_SET) != 0)   {
      /* Can't rewind the file, give up. */
      error = TRUE;
      goto failed;
    }
    /* Delete the previously read lines. */
    while (lnum > from)
      ml_delete(lnum--, FALSE);
    file_rewind = FALSE;
    if (set_options) {
      curbuf->b_p_bomb = FALSE;
      curbuf->b_start_bomb = FALSE;
    }
    conv_error = 0;
  }

  if (cryptkey != NULL)
    /* Need to reset the state, but keep the key, don't want to ask for it
     * again. */
    crypt_pop_state();

  /*
   * When retrying with another "fenc" and the first time "fileformat"
   * will be reset.
   */
  if (keep_fileformat)
    keep_fileformat = FALSE;
  else {
    if (eap != NULL && eap->force_ff != 0) {
      fileformat = get_fileformat_force(curbuf, eap);
      try_unix = try_dos = try_mac = FALSE;
    } else if (curbuf->b_p_bin)
      fileformat = EOL_UNIX;                    /* binary: use Unix format */
    else if (*p_ffs == NUL)
      fileformat = get_fileformat(curbuf);      /* use format from buffer */
    else
      fileformat = EOL_UNKNOWN;                 /* detect from file */
  }

# ifdef USE_ICONV
  if (iconv_fd != (iconv_t)-1) {
    /* aborted conversion with iconv(), close the descriptor */
    iconv_close(iconv_fd);
    iconv_fd = (iconv_t)-1;
  }
# endif

  if (advance_fenc) {
    /*
     * Try the next entry in 'fileencodings'.
     */
    advance_fenc = FALSE;

    if (eap != NULL && eap->force_enc != 0) {
      /* Conversion given with "++cc=" wasn't possible, read
       * without conversion. */
      notconverted = TRUE;
      conv_error = 0;
      if (fenc_alloced)
        vim_free(fenc);
      fenc = (char_u *)"";
      fenc_alloced = FALSE;
    } else   {
      if (fenc_alloced)
        vim_free(fenc);
      if (fenc_next != NULL) {
        fenc = next_fenc(&fenc_next);
        fenc_alloced = (fenc_next != NULL);
      } else   {
        fenc = (char_u *)"";
        fenc_alloced = FALSE;
      }
    }
    if (tmpname != NULL) {
      mch_remove(tmpname);                      /* delete converted file */
      vim_free(tmpname);
      tmpname = NULL;
    }
  }

  /*
   * Conversion may be required when the encoding of the file is different
   * from 'encoding' or 'encoding' is UTF-16, UCS-2 or UCS-4.
   */
  fio_flags = 0;
  converted = need_conversion(fenc);
  if (converted) {

    /* "ucs-bom" means we need to check the first bytes of the file
     * for a BOM. */
    if (STRCMP(fenc, ENC_UCSBOM) == 0)
      fio_flags = FIO_UCSBOM;

    /*
     * Check if UCS-2/4 or Latin1 to UTF-8 conversion needs to be
     * done.  This is handled below after read().  Prepare the
     * fio_flags to avoid having to parse the string each time.
     * Also check for Unicode to Latin1 conversion, because iconv()
     * appears not to handle this correctly.  This works just like
     * conversion to UTF-8 except how the resulting character is put in
     * the buffer.
     */
    else if (enc_utf8 || STRCMP(p_enc, "latin1") == 0)
      fio_flags = get_fio_flags(fenc);



# ifdef USE_ICONV
    /*
     * Try using iconv() if we can't convert internally.
     */
    if (fio_flags == 0
        && !did_iconv
        )
      iconv_fd = (iconv_t)my_iconv_open(
          enc_utf8 ? (char_u *)"utf-8" : p_enc, fenc);
# endif

    /*
     * Use the 'charconvert' expression when conversion is required
     * and we can't do it internally or with iconv().
     */
    if (fio_flags == 0 && !read_stdin && !read_buffer && *p_ccv != NUL
#  ifdef USE_ICONV
        && iconv_fd == (iconv_t)-1
#  endif
        ) {
#  ifdef USE_ICONV
      did_iconv = FALSE;
#  endif
      /* Skip conversion when it's already done (retry for wrong
       * "fileformat"). */
      if (tmpname == NULL) {
        tmpname = readfile_charconvert(fname, fenc, &fd);
        if (tmpname == NULL) {
          /* Conversion failed.  Try another one. */
          advance_fenc = TRUE;
          if (fd < 0) {
            /* Re-opening the original file failed! */
            EMSG(_("E202: Conversion made file unreadable!"));
            error = TRUE;
            goto failed;
          }
          goto retry;
        }
      }
    } else   {
      if (fio_flags == 0
# ifdef USE_ICONV
          && iconv_fd == (iconv_t)-1
# endif
          ) {
        /* Conversion wanted but we can't.
         * Try the next conversion in 'fileencodings' */
        advance_fenc = TRUE;
        goto retry;
      }
    }
  }

  /* Set "can_retry" when it's possible to rewind the file and try with
   * another "fenc" value.  It's FALSE when no other "fenc" to try, reading
   * stdin or fixed at a specific encoding. */
  can_retry = (*fenc != NUL && !read_stdin && !keep_dest_enc);

  if (!skip_read) {
    linerest = 0;
    filesize = 0;
    skip_count = lines_to_skip;
    read_count = lines_to_read;
    conv_restlen = 0;
    read_undo_file = (newfile && (flags & READ_KEEP_UNDO) == 0
                      && curbuf->b_ffname != NULL
                      && curbuf->b_p_udf
                      && !filtering
                      && !read_stdin
                      && !read_buffer);
    if (read_undo_file)
      sha256_start(&sha_ctx);
  }

  while (!error && !got_int) {
    /*
     * We allocate as much space for the file as we can get, plus
     * space for the old line plus room for one terminating NUL.
     * The amount is limited by the fact that read() only can read
     * upto max_unsigned characters (and other things).
     */
#if SIZEOF_INT <= 2
    if (linerest >= 0x7ff0) {
      ++split;
      *ptr = NL;                    /* split line by inserting a NL */
      size = 1;
    } else
#endif
    {
      if (!skip_read) {
#if SIZEOF_INT > 2
# if defined(SSIZE_MAX) && (SSIZE_MAX < 0x10000L)
        size = SSIZE_MAX;                           /* use max I/O size, 52K */
# else
        size = 0x10000L;                            /* use buffer >= 64K */
# endif
#else
        size = 0x7ff0L - linerest;                  /* limit buffer to 32K */
#endif

        for (; size >= 10; size = (long)((long_u)size >> 1)) {
          if ((new_buffer = lalloc((long_u)(size + linerest + 1),
                   FALSE)) != NULL)
            break;
        }
        if (new_buffer == NULL) {
          do_outofmem_msg((long_u)(size * 2 + linerest + 1));
          error = TRUE;
          break;
        }
        if (linerest)           /* copy characters from the previous buffer */
          mch_memmove(new_buffer, ptr - linerest, (size_t)linerest);
        vim_free(buffer);
        buffer = new_buffer;
        ptr = buffer + linerest;
        line_start = buffer;

        /* May need room to translate into.
         * For iconv() we don't really know the required space, use a
         * factor ICONV_MULT.
         * latin1 to utf-8: 1 byte becomes up to 2 bytes
         * utf-16 to utf-8: 2 bytes become up to 3 bytes, 4 bytes
         * become up to 4 bytes, size must be multiple of 2
         * ucs-2 to utf-8: 2 bytes become up to 3 bytes, size must be
         * multiple of 2
         * ucs-4 to utf-8: 4 bytes become up to 6 bytes, size must be
         * multiple of 4 */
        real_size = (int)size;
# ifdef USE_ICONV
        if (iconv_fd != (iconv_t)-1)
          size = size / ICONV_MULT;
        else
# endif
        if (fio_flags & FIO_LATIN1)
          size = size / 2;
        else if (fio_flags & (FIO_UCS2 | FIO_UTF16))
          size = (size * 2 / 3) & ~1;
        else if (fio_flags & FIO_UCS4)
          size = (size * 2 / 3) & ~3;
        else if (fio_flags == FIO_UCSBOM)
          size = size / ICONV_MULT;             /* worst case */

        if (conv_restlen > 0) {
          /* Insert unconverted bytes from previous line. */
          mch_memmove(ptr, conv_rest, conv_restlen);
          ptr += conv_restlen;
          size -= conv_restlen;
        }

        if (read_buffer) {
          /*
           * Read bytes from curbuf.  Used for converting text read
           * from stdin.
           */
          if (read_buf_lnum > from)
            size = 0;
          else {
            int n, ni;
            long tlen;

            tlen = 0;
            for (;; ) {
              p = ml_get(read_buf_lnum) + read_buf_col;
              n = (int)STRLEN(p);
              if ((int)tlen + n + 1 > size) {
                /* Filled up to "size", append partial line.
                 * Change NL to NUL to reverse the effect done
                 * below. */
                n = (int)(size - tlen);
                for (ni = 0; ni < n; ++ni) {
                  if (p[ni] == NL)
                    ptr[tlen++] = NUL;
                  else
                    ptr[tlen++] = p[ni];
                }
                read_buf_col += n;
                break;
              } else   {
                /* Append whole line and new-line.  Change NL
                * to NUL to reverse the effect done below. */
                for (ni = 0; ni < n; ++ni) {
                  if (p[ni] == NL)
                    ptr[tlen++] = NUL;
                  else
                    ptr[tlen++] = p[ni];
                }
                ptr[tlen++] = NL;
                read_buf_col = 0;
                if (++read_buf_lnum > from) {
                  /* When the last line didn't have an
                   * end-of-line don't add it now either. */
                  if (!curbuf->b_p_eol)
                    --tlen;
                  size = tlen;
                  break;
                }
              }
            }
          }
        } else   {
          /*
           * Read bytes from the file.
           */
          size = read_eintr(fd, ptr, size);
        }

        if (size <= 0) {
          if (size < 0)                             /* read error */
            error = TRUE;
          else if (conv_restlen > 0) {
            /*
             * Reached end-of-file but some trailing bytes could
             * not be converted.  Truncated file?
             */

            /* When we did a conversion report an error. */
            if (fio_flags != 0
# ifdef USE_ICONV
                || iconv_fd != (iconv_t)-1
# endif
                ) {
              if (can_retry)
                goto rewind_retry;
              if (conv_error == 0)
                conv_error = curbuf->b_ml.ml_line_count
                             - linecnt + 1;
            }
            /* Remember the first linenr with an illegal byte */
            else if (illegal_byte == 0)
              illegal_byte = curbuf->b_ml.ml_line_count
                             - linecnt + 1;
            if (bad_char_behavior == BAD_DROP) {
              *(ptr - conv_restlen) = NUL;
              conv_restlen = 0;
            } else   {
              /* Replace the trailing bytes with the replacement
               * character if we were converting; if we weren't,
               * leave the UTF8 checking code to do it, as it
               * works slightly differently. */
              if (bad_char_behavior != BAD_KEEP && (fio_flags != 0
# ifdef USE_ICONV
                                                    || iconv_fd != (iconv_t)-1
# endif
                                                    )) {
                while (conv_restlen > 0) {
                  *(--ptr) = bad_char_behavior;
                  --conv_restlen;
                }
              }
              fio_flags = 0;                    /* don't convert this */
# ifdef USE_ICONV
              if (iconv_fd != (iconv_t)-1) {
                iconv_close(iconv_fd);
                iconv_fd = (iconv_t)-1;
              }
# endif
            }
          }
        }

        /*
         * At start of file: Check for magic number of encryption.
         */
        if (filesize == 0)
          cryptkey = check_for_cryptkey(cryptkey, ptr, &size,
              &filesize, newfile, sfname,
              &did_ask_for_key);
        /*
         * Decrypt the read bytes.
         */
        if (cryptkey != NULL && size > 0)
          crypt_decode(ptr, size);
      }
      skip_read = FALSE;

      /*
       * At start of file (or after crypt magic number): Check for BOM.
       * Also check for a BOM for other Unicode encodings, but not after
       * converting with 'charconvert' or when a BOM has already been
       * found.
       */
      if ((filesize == 0
           || (filesize == (CRYPT_MAGIC_LEN
                            + crypt_salt_len[use_crypt_method]
                            + crypt_seed_len[use_crypt_method])
               && cryptkey != NULL)
           )
          && (fio_flags == FIO_UCSBOM
              || (!curbuf->b_p_bomb
                  && tmpname == NULL
                  && (*fenc == 'u' || (*fenc == NUL && enc_utf8))))) {
        char_u  *ccname;
        int blen;

        /* no BOM detection in a short file or in binary mode */
        if (size < 2 || curbuf->b_p_bin)
          ccname = NULL;
        else
          ccname = check_for_bom(ptr, size, &blen,
              fio_flags == FIO_UCSBOM ? FIO_ALL : get_fio_flags(fenc));
        if (ccname != NULL) {
          /* Remove BOM from the text */
          filesize += blen;
          size -= blen;
          mch_memmove(ptr, ptr + blen, (size_t)size);
          if (set_options) {
            curbuf->b_p_bomb = TRUE;
            curbuf->b_start_bomb = TRUE;
          }
        }

        if (fio_flags == FIO_UCSBOM) {
          if (ccname == NULL) {
            /* No BOM detected: retry with next encoding. */
            advance_fenc = TRUE;
          } else   {
            /* BOM detected: set "fenc" and jump back */
            if (fenc_alloced)
              vim_free(fenc);
            fenc = ccname;
            fenc_alloced = FALSE;
          }
          /* retry reading without getting new bytes or rewinding */
          skip_read = TRUE;
          goto retry;
        }
      }

      /* Include not converted bytes. */
      ptr -= conv_restlen;
      size += conv_restlen;
      conv_restlen = 0;
      /*
       * Break here for a read error or end-of-file.
       */
      if (size <= 0)
        break;


# ifdef USE_ICONV
      if (iconv_fd != (iconv_t)-1) {
        /*
         * Attempt conversion of the read bytes to 'encoding' using
         * iconv().
         */
        const char      *fromp;
        char            *top;
        size_t from_size;
        size_t to_size;

        fromp = (char *)ptr;
        from_size = size;
        ptr += size;
        top = (char *)ptr;
        to_size = real_size - size;

        /*
         * If there is conversion error or not enough room try using
         * another conversion.  Except for when there is no
         * alternative (help files).
         */
        while ((iconv(iconv_fd, (void *)&fromp, &from_size,
                    &top, &to_size)
                == (size_t)-1 && ICONV_ERRNO != ICONV_EINVAL)
               || from_size > CONV_RESTLEN) {
          if (can_retry)
            goto rewind_retry;
          if (conv_error == 0)
            conv_error = readfile_linenr(linecnt,
                ptr, (char_u *)top);

          /* Deal with a bad byte and continue with the next. */
          ++fromp;
          --from_size;
          if (bad_char_behavior == BAD_KEEP) {
            *top++ = *(fromp - 1);
            --to_size;
          } else if (bad_char_behavior != BAD_DROP)   {
            *top++ = bad_char_behavior;
            --to_size;
          }
        }

        if (from_size > 0) {
          /* Some remaining characters, keep them for the next
           * round. */
          mch_memmove(conv_rest, (char_u *)fromp, from_size);
          conv_restlen = (int)from_size;
        }

        /* move the linerest to before the converted characters */
        line_start = ptr - linerest;
        mch_memmove(line_start, buffer, (size_t)linerest);
        size = (long)((char_u *)top - ptr);
      }
# endif

# ifdef MACOS_CONVERT
      if (fio_flags & FIO_MACROMAN) {
        /*
         * Conversion from Apple MacRoman char encoding to UTF-8 or
         * latin1.  This is in os_mac_conv.c.
         */
        if (macroman2enc(ptr, &size, real_size) == FAIL)
          goto rewind_retry;
      } else
# endif
      if (fio_flags != 0) {
        int u8c;
        char_u  *dest;
        char_u  *tail = NULL;

        /*
         * "enc_utf8" set: Convert Unicode or Latin1 to UTF-8.
         * "enc_utf8" not set: Convert Unicode to Latin1.
         * Go from end to start through the buffer, because the number
         * of bytes may increase.
         * "dest" points to after where the UTF-8 bytes go, "p" points
         * to after the next character to convert.
         */
        dest = ptr + real_size;
        if (fio_flags == FIO_LATIN1 || fio_flags == FIO_UTF8) {
          p = ptr + size;
          if (fio_flags == FIO_UTF8) {
            /* Check for a trailing incomplete UTF-8 sequence */
            tail = ptr + size - 1;
            while (tail > ptr && (*tail & 0xc0) == 0x80)
              --tail;
            if (tail + utf_byte2len(*tail) <= ptr + size)
              tail = NULL;
            else
              p = tail;
          }
        } else if (fio_flags & (FIO_UCS2 | FIO_UTF16))   {
          /* Check for a trailing byte */
          p = ptr + (size & ~1);
          if (size & 1)
            tail = p;
          if ((fio_flags & FIO_UTF16) && p > ptr) {
            /* Check for a trailing leading word */
            if (fio_flags & FIO_ENDIAN_L) {
              u8c = (*--p << 8);
              u8c += *--p;
            } else   {
              u8c = *--p;
              u8c += (*--p << 8);
            }
            if (u8c >= 0xd800 && u8c <= 0xdbff)
              tail = p;
            else
              p += 2;
          }
        } else   {   /*  FIO_UCS4 */
                     /* Check for trailing 1, 2 or 3 bytes */
          p = ptr + (size & ~3);
          if (size & 3)
            tail = p;
        }

        /* If there is a trailing incomplete sequence move it to
         * conv_rest[]. */
        if (tail != NULL) {
          conv_restlen = (int)((ptr + size) - tail);
          mch_memmove(conv_rest, (char_u *)tail, conv_restlen);
          size -= conv_restlen;
        }


        while (p > ptr) {
          if (fio_flags & FIO_LATIN1)
            u8c = *--p;
          else if (fio_flags & (FIO_UCS2 | FIO_UTF16)) {
            if (fio_flags & FIO_ENDIAN_L) {
              u8c = (*--p << 8);
              u8c += *--p;
            } else   {
              u8c = *--p;
              u8c += (*--p << 8);
            }
            if ((fio_flags & FIO_UTF16)
                && u8c >= 0xdc00 && u8c <= 0xdfff) {
              int u16c;

              if (p == ptr) {
                /* Missing leading word. */
                if (can_retry)
                  goto rewind_retry;
                if (conv_error == 0)
                  conv_error = readfile_linenr(linecnt,
                      ptr, p);
                if (bad_char_behavior == BAD_DROP)
                  continue;
                if (bad_char_behavior != BAD_KEEP)
                  u8c = bad_char_behavior;
              }

              /* found second word of double-word, get the first
               * word and compute the resulting character */
              if (fio_flags & FIO_ENDIAN_L) {
                u16c = (*--p << 8);
                u16c += *--p;
              } else   {
                u16c = *--p;
                u16c += (*--p << 8);
              }
              u8c = 0x10000 + ((u16c & 0x3ff) << 10)
                    + (u8c & 0x3ff);

              /* Check if the word is indeed a leading word. */
              if (u16c < 0xd800 || u16c > 0xdbff) {
                if (can_retry)
                  goto rewind_retry;
                if (conv_error == 0)
                  conv_error = readfile_linenr(linecnt,
                      ptr, p);
                if (bad_char_behavior == BAD_DROP)
                  continue;
                if (bad_char_behavior != BAD_KEEP)
                  u8c = bad_char_behavior;
              }
            }
          } else if (fio_flags & FIO_UCS4)   {
            if (fio_flags & FIO_ENDIAN_L) {
              u8c = (*--p << 24);
              u8c += (*--p << 16);
              u8c += (*--p << 8);
              u8c += *--p;
            } else   {          /* big endian */
              u8c = *--p;
              u8c += (*--p << 8);
              u8c += (*--p << 16);
              u8c += (*--p << 24);
            }
          } else   {        /* UTF-8 */
            if (*--p < 0x80)
              u8c = *p;
            else {
              len = utf_head_off(ptr, p);
              p -= len;
              u8c = utf_ptr2char(p);
              if (len == 0) {
                /* Not a valid UTF-8 character, retry with
                 * another fenc when possible, otherwise just
                 * report the error. */
                if (can_retry)
                  goto rewind_retry;
                if (conv_error == 0)
                  conv_error = readfile_linenr(linecnt,
                      ptr, p);
                if (bad_char_behavior == BAD_DROP)
                  continue;
                if (bad_char_behavior != BAD_KEEP)
                  u8c = bad_char_behavior;
              }
            }
          }
          if (enc_utf8) {               /* produce UTF-8 */
            dest -= utf_char2len(u8c);
            (void)utf_char2bytes(u8c, dest);
          } else   {                    /* produce Latin1 */
            --dest;
            if (u8c >= 0x100) {
              /* character doesn't fit in latin1, retry with
               * another fenc when possible, otherwise just
               * report the error. */
              if (can_retry)
                goto rewind_retry;
              if (conv_error == 0)
                conv_error = readfile_linenr(linecnt, ptr, p);
              if (bad_char_behavior == BAD_DROP)
                ++dest;
              else if (bad_char_behavior == BAD_KEEP)
                *dest = u8c;
              else if (eap != NULL && eap->bad_char != 0)
                *dest = bad_char_behavior;
              else
                *dest = 0xBF;
            } else
              *dest = u8c;
          }
        }

        /* move the linerest to before the converted characters */
        line_start = dest - linerest;
        mch_memmove(line_start, buffer, (size_t)linerest);
        size = (long)((ptr + real_size) - dest);
        ptr = dest;
      } else if (enc_utf8 && !curbuf->b_p_bin)   {
        int incomplete_tail = FALSE;

        /* Reading UTF-8: Check if the bytes are valid UTF-8. */
        for (p = ptr;; ++p) {
          int todo = (int)((ptr + size) - p);
          int l;

          if (todo <= 0)
            break;
          if (*p >= 0x80) {
            /* A length of 1 means it's an illegal byte.  Accept
             * an incomplete character at the end though, the next
             * read() will get the next bytes, we'll check it
             * then. */
            l = utf_ptr2len_len(p, todo);
            if (l > todo && !incomplete_tail) {
              /* Avoid retrying with a different encoding when
               * a truncated file is more likely, or attempting
               * to read the rest of an incomplete sequence when
               * we have already done so. */
              if (p > ptr || filesize > 0)
                incomplete_tail = TRUE;
              /* Incomplete byte sequence, move it to conv_rest[]
               * and try to read the rest of it, unless we've
               * already done so. */
              if (p > ptr) {
                conv_restlen = todo;
                mch_memmove(conv_rest, p, conv_restlen);
                size -= conv_restlen;
                break;
              }
            }
            if (l == 1 || l > todo) {
              /* Illegal byte.  If we can try another encoding
               * do that, unless at EOF where a truncated
               * file is more likely than a conversion error. */
              if (can_retry && !incomplete_tail)
                break;
# ifdef USE_ICONV
              /* When we did a conversion report an error. */
              if (iconv_fd != (iconv_t)-1 && conv_error == 0)
                conv_error = readfile_linenr(linecnt, ptr, p);
# endif
              /* Remember the first linenr with an illegal byte */
              if (conv_error == 0 && illegal_byte == 0)
                illegal_byte = readfile_linenr(linecnt, ptr, p);

              /* Drop, keep or replace the bad byte. */
              if (bad_char_behavior == BAD_DROP) {
                mch_memmove(p, p + 1, todo - 1);
                --p;
                --size;
              } else if (bad_char_behavior != BAD_KEEP)
                *p = bad_char_behavior;
            } else
              p += l - 1;
          }
        }
        if (p < ptr + size && !incomplete_tail) {
          /* Detected a UTF-8 error. */
rewind_retry:
          /* Retry reading with another conversion. */
# if defined(FEAT_EVAL) && defined(USE_ICONV)
          if (*p_ccv != NUL && iconv_fd != (iconv_t)-1)
            /* iconv() failed, try 'charconvert' */
            did_iconv = TRUE;
          else
# endif
          /* use next item from 'fileencodings' */
          advance_fenc = TRUE;
          file_rewind = TRUE;
          goto retry;
        }
      }

      /* count the number of characters (after conversion!) */
      filesize += size;

      /*
       * when reading the first part of a file: guess EOL type
       */
      if (fileformat == EOL_UNKNOWN) {
        /* First try finding a NL, for Dos and Unix */
        if (try_dos || try_unix) {
          for (p = ptr; p < ptr + size; ++p) {
            if (*p == NL) {
              if (!try_unix
                  || (try_dos && p > ptr && p[-1] == CAR))
                fileformat = EOL_DOS;
              else
                fileformat = EOL_UNIX;
              break;
            }
          }

          /* Don't give in to EOL_UNIX if EOL_MAC is more likely */
          if (fileformat == EOL_UNIX && try_mac) {
            /* Need to reset the counters when retrying fenc. */
            try_mac = 1;
            try_unix = 1;
            for (; p >= ptr && *p != CAR; p--)
              ;
            if (p >= ptr) {
              for (p = ptr; p < ptr + size; ++p) {
                if (*p == NL)
                  try_unix++;
                else if (*p == CAR)
                  try_mac++;
              }
              if (try_mac > try_unix)
                fileformat = EOL_MAC;
            }
          }
        }

        /* No NL found: may use Mac format */
        if (fileformat == EOL_UNKNOWN && try_mac)
          fileformat = EOL_MAC;

        /* Still nothing found?  Use first format in 'ffs' */
        if (fileformat == EOL_UNKNOWN)
          fileformat = default_fileformat();

        /* if editing a new file: may set p_tx and p_ff */
        if (set_options)
          set_fileformat(fileformat, OPT_LOCAL);
      }
    }

    /*
     * This loop is executed once for every character read.
     * Keep it fast!
     */
    if (fileformat == EOL_MAC) {
      --ptr;
      while (++ptr, --size >= 0) {
        /* catch most common case first */
        if ((c = *ptr) != NUL && c != CAR && c != NL)
          continue;
        if (c == NUL)
          *ptr = NL;            /* NULs are replaced by newlines! */
        else if (c == NL)
          *ptr = CAR;           /* NLs are replaced by CRs! */
        else {
          if (skip_count == 0) {
            *ptr = NUL;                     /* end of line */
            len = (colnr_T) (ptr - line_start + 1);
            if (ml_append(lnum, line_start, len, newfile) == FAIL) {
              error = TRUE;
              break;
            }
            if (read_undo_file)
              sha256_update(&sha_ctx, line_start, len);
            ++lnum;
            if (--read_count == 0) {
              error = TRUE;                     /* break loop */
              line_start = ptr;                 /* nothing left to write */
              break;
            }
          } else
            --skip_count;
          line_start = ptr + 1;
        }
      }
    } else   {
      --ptr;
      while (++ptr, --size >= 0) {
        if ((c = *ptr) != NUL && c != NL)          /* catch most common case */
          continue;
        if (c == NUL)
          *ptr = NL;            /* NULs are replaced by newlines! */
        else {
          if (skip_count == 0) {
            *ptr = NUL;                         /* end of line */
            len = (colnr_T)(ptr - line_start + 1);
            if (fileformat == EOL_DOS) {
              if (ptr[-1] == CAR) {             /* remove CR */
                ptr[-1] = NUL;
                --len;
              }
              /*
               * Reading in Dos format, but no CR-LF found!
               * When 'fileformats' includes "unix", delete all
               * the lines read so far and start all over again.
               * Otherwise give an error message later.
               */
              else if (ff_error != EOL_DOS) {
                if (   try_unix
                       && !read_stdin
                       && (read_buffer
                           || lseek(fd, (off_t)0L, SEEK_SET) == 0)) {
                  fileformat = EOL_UNIX;
                  if (set_options)
                    set_fileformat(EOL_UNIX, OPT_LOCAL);
                  file_rewind = TRUE;
                  keep_fileformat = TRUE;
                  goto retry;
                }
                ff_error = EOL_DOS;
              }
            }
            if (ml_append(lnum, line_start, len, newfile) == FAIL) {
              error = TRUE;
              break;
            }
            if (read_undo_file)
              sha256_update(&sha_ctx, line_start, len);
            ++lnum;
            if (--read_count == 0) {
              error = TRUE;                         /* break loop */
              line_start = ptr;                 /* nothing left to write */
              break;
            }
          } else
            --skip_count;
          line_start = ptr + 1;
        }
      }
    }
    linerest = (long)(ptr - line_start);
    ui_breakcheck();
  }

failed:
  /* not an error, max. number of lines reached */
  if (error && read_count == 0)
    error = FALSE;

  /*
   * If we get EOF in the middle of a line, note the fact and
   * complete the line ourselves.
   * In Dos format ignore a trailing CTRL-Z, unless 'binary' set.
   */
  if (!error
      && !got_int
      && linerest != 0
      && !(!curbuf->b_p_bin
           && fileformat == EOL_DOS
           && *line_start == Ctrl_Z
           && ptr == line_start + 1)) {
    /* remember for when writing */
    if (set_options)
      curbuf->b_p_eol = FALSE;
    *ptr = NUL;
    len = (colnr_T)(ptr - line_start + 1);
    if (ml_append(lnum, line_start, len, newfile) == FAIL)
      error = TRUE;
    else {
      if (read_undo_file)
        sha256_update(&sha_ctx, line_start, len);
      read_no_eol_lnum = ++lnum;
    }
  }

  if (set_options)
    save_file_ff(curbuf);               /* remember the current file format */

  crypt_method_used = use_crypt_method;
  if (cryptkey != NULL) {
    crypt_pop_state();
    if (cryptkey != curbuf->b_p_key)
      free_crypt_key(cryptkey);
    /* don't set cryptkey to NULL, it's used below as a flag that
     * encryption was used */
  }

  /* If editing a new file: set 'fenc' for the current buffer.
   * Also for ":read ++edit file". */
  if (set_options)
    set_string_option_direct((char_u *)"fenc", -1, fenc,
        OPT_FREE|OPT_LOCAL, 0);
  if (fenc_alloced)
    vim_free(fenc);
# ifdef USE_ICONV
  if (iconv_fd != (iconv_t)-1) {
    iconv_close(iconv_fd);
    iconv_fd = (iconv_t)-1;
  }
# endif

  if (!read_buffer && !read_stdin)
    close(fd);                                  /* errors are ignored */
#ifdef HAVE_FD_CLOEXEC
  else {
    int fdflags = fcntl(fd, F_GETFD);
    if (fdflags >= 0 && (fdflags & FD_CLOEXEC) == 0)
      fcntl(fd, F_SETFD, fdflags | FD_CLOEXEC);
  }
#endif
  vim_free(buffer);

#ifdef HAVE_DUP
  if (read_stdin) {
    /* Use stderr for stdin, makes shell commands work. */
    close(0);
    ignored = dup(2);
  }
#endif

  if (tmpname != NULL) {
    mch_remove(tmpname);                /* delete converted file */
    vim_free(tmpname);
  }
  --no_wait_return;                     /* may wait for return now */

  /*
   * In recovery mode everything but autocommands is skipped.
   */
  if (!recoverymode) {
    /* need to delete the last line, which comes from the empty buffer */
    if (newfile && wasempty && !(curbuf->b_ml.ml_flags & ML_EMPTY)) {
      ml_delete(curbuf->b_ml.ml_line_count, FALSE);
      --linecnt;
    }
    linecnt = curbuf->b_ml.ml_line_count - linecnt;
    if (filesize == 0)
      linecnt = 0;
    if (newfile || read_buffer) {
      redraw_curbuf_later(NOT_VALID);
      /* After reading the text into the buffer the diff info needs to
       * be updated. */
      diff_invalidate(curbuf);
      /* All folds in the window are invalid now.  Mark them for update
       * before triggering autocommands. */
      foldUpdateAll(curwin);
    } else if (linecnt)                 /* appended at least one line */
      appended_lines_mark(from, linecnt);

    /*
     * If we were reading from the same terminal as where messages go,
     * the screen will have been messed up.
     * Switch on raw mode now and clear the screen.
     */
    if (read_stdin) {
      settmode(TMODE_RAW);              /* set to raw mode */
      starttermcap();
      screenclear();
    }

    if (got_int) {
      if (!(flags & READ_DUMMY)) {
        filemess(curbuf, sfname, (char_u *)_(e_interr), 0);
        if (newfile)
          curbuf->b_p_ro = TRUE;                /* must use "w!" now */
      }
      msg_scroll = msg_save;
      check_marks_read();
      return OK;                /* an interrupt isn't really an error */
    }

    if (!filtering && !(flags & READ_DUMMY)) {
      msg_add_fname(curbuf, sfname);         /* fname in IObuff with quotes */
      c = FALSE;

#ifdef UNIX
# ifdef S_ISFIFO
      if (S_ISFIFO(perm)) {                         /* fifo or socket */
        STRCAT(IObuff, _("[fifo/socket]"));
        c = TRUE;
      }
# else
#  ifdef S_IFIFO
      if ((perm & S_IFMT) == S_IFIFO) {             /* fifo */
        STRCAT(IObuff, _("[fifo]"));
        c = TRUE;
      }
#  endif
#  ifdef S_IFSOCK
      if ((perm & S_IFMT) == S_IFSOCK) {            /* or socket */
        STRCAT(IObuff, _("[socket]"));
        c = TRUE;
      }
#  endif
# endif
# ifdef OPEN_CHR_FILES
      if (S_ISCHR(perm)) {                          /* or character special */
        STRCAT(IObuff, _("[character special]"));
        c = TRUE;
      }
# endif
#endif
      if (curbuf->b_p_ro) {
        STRCAT(IObuff, shortmess(SHM_RO) ? _("[RO]") : _("[readonly]"));
        c = TRUE;
      }
      if (read_no_eol_lnum) {
        msg_add_eol();
        c = TRUE;
      }
      if (ff_error == EOL_DOS) {
        STRCAT(IObuff, _("[CR missing]"));
        c = TRUE;
      }
      if (split) {
        STRCAT(IObuff, _("[long lines split]"));
        c = TRUE;
      }
      if (notconverted) {
        STRCAT(IObuff, _("[NOT converted]"));
        c = TRUE;
      } else if (converted)   {
        STRCAT(IObuff, _("[converted]"));
        c = TRUE;
      }
      if (cryptkey != NULL) {
        if (crypt_method_used == 1)
          STRCAT(IObuff, _("[blowfish]"));
        else
          STRCAT(IObuff, _("[crypted]"));
        c = TRUE;
      }
      if (conv_error != 0) {
        sprintf((char *)IObuff + STRLEN(IObuff),
            _("[CONVERSION ERROR in line %ld]"), (long)conv_error);
        c = TRUE;
      } else if (illegal_byte > 0)   {
        sprintf((char *)IObuff + STRLEN(IObuff),
            _("[ILLEGAL BYTE in line %ld]"), (long)illegal_byte);
        c = TRUE;
      } else if (error)    {
        STRCAT(IObuff, _("[READ ERRORS]"));
        c = TRUE;
      }
      if (msg_add_fileformat(fileformat))
        c = TRUE;
      if (cryptkey != NULL)
        msg_add_lines(c, (long)linecnt, filesize
            - CRYPT_MAGIC_LEN
            - crypt_salt_len[use_crypt_method]
            - crypt_seed_len[use_crypt_method]);
      else
        msg_add_lines(c, (long)linecnt, filesize);

      vim_free(keep_msg);
      keep_msg = NULL;
      msg_scrolled_ign = TRUE;
      p = msg_trunc_attr(IObuff, FALSE, 0);
      if (read_stdin || read_buffer || restart_edit != 0
          || (msg_scrolled != 0 && !need_wait_return))
        /* Need to repeat the message after redrawing when:
         * - When reading from stdin (the screen will be cleared next).
         * - When restart_edit is set (otherwise there will be a delay
         *   before redrawing).
         * - When the screen was scrolled but there is no wait-return
         *   prompt. */
        set_keep_msg(p, 0);
      msg_scrolled_ign = FALSE;
    }

    /* with errors writing the file requires ":w!" */
    if (newfile && (error
                    || conv_error != 0
                    || (illegal_byte > 0 && bad_char_behavior != BAD_KEEP)
                    ))
      curbuf->b_p_ro = TRUE;

    u_clearline();          /* cannot use "U" command after adding lines */

    /*
     * In Ex mode: cursor at last new line.
     * Otherwise: cursor at first new line.
     */
    if (exmode_active)
      curwin->w_cursor.lnum = from + linecnt;
    else
      curwin->w_cursor.lnum = from + 1;
    check_cursor_lnum();
    beginline(BL_WHITE | BL_FIX);           /* on first non-blank */

    /*
     * Set '[ and '] marks to the newly read lines.
     */
    curbuf->b_op_start.lnum = from + 1;
    curbuf->b_op_start.col = 0;
    curbuf->b_op_end.lnum = from + linecnt;
    curbuf->b_op_end.col = 0;

  }
  msg_scroll = msg_save;

  /*
   * Get the marks before executing autocommands, so they can be used there.
   */
  check_marks_read();

  /*
   * Trick: We remember if the last line of the read didn't have
   * an eol even when 'binary' is off, for when writing it again with
   * 'binary' on.  This is required for
   * ":autocmd FileReadPost *.gz set bin|'[,']!gunzip" to work.
   */
  curbuf->b_no_eol_lnum = read_no_eol_lnum;

  /* When reloading a buffer put the cursor at the first line that is
   * different. */
  if (flags & READ_KEEP_UNDO)
    u_find_first_changed();

  /*
   * When opening a new file locate undo info and read it.
   */
  if (read_undo_file) {
    char_u hash[UNDO_HASH_SIZE];

    sha256_finish(&sha_ctx, hash);
    u_read_undo(NULL, hash, fname);
  }

  if (!read_stdin && !read_buffer) {
    int m = msg_scroll;
    int n = msg_scrolled;

    /* Save the fileformat now, otherwise the buffer will be considered
     * modified if the format/encoding was automatically detected. */
    if (set_options)
      save_file_ff(curbuf);

    /*
     * The output from the autocommands should not overwrite anything and
     * should not be overwritten: Set msg_scroll, restore its value if no
     * output was done.
     */
    msg_scroll = TRUE;
    if (filtering)
      apply_autocmds_exarg(EVENT_FILTERREADPOST, NULL, sfname,
          FALSE, curbuf, eap);
    else if (newfile)
      apply_autocmds_exarg(EVENT_BUFREADPOST, NULL, sfname,
          FALSE, curbuf, eap);
    else
      apply_autocmds_exarg(EVENT_FILEREADPOST, sfname, sfname,
          FALSE, NULL, eap);
    if (msg_scrolled == n)
      msg_scroll = m;
    if (aborting())         /* autocmds may abort script processing */
      return FAIL;
  }

  if (recoverymode && error)
    return FAIL;
  return OK;
}

#ifdef OPEN_CHR_FILES
/*
 * Returns TRUE if the file name argument is of the form "/dev/fd/\d\+",
 * which is the name of files used for process substitution output by
 * some shells on some operating systems, e.g., bash on SunOS.
 * Do not accept "/dev/fd/[012]", opening these may hang Vim.
 */
static int is_dev_fd_file(char_u *fname)
{
  return STRNCMP(fname, "/dev/fd/", 8) == 0
         && VIM_ISDIGIT(fname[8])
         && *skipdigits(fname + 9) == NUL
         && (fname[9] != NUL
             || (fname[8] != '0' && fname[8] != '1' && fname[8] != '2'));
}
#endif


/*
 * From the current line count and characters read after that, estimate the
 * line number where we are now.
 * Used for error messages that include a line number.
 */
static linenr_T 
readfile_linenr (
    linenr_T linecnt,               /* line count before reading more bytes */
    char_u *p,                 /* start of more bytes read */
    char_u *endp              /* end of more bytes read */
)
{
  char_u      *s;
  linenr_T lnum;

  lnum = curbuf->b_ml.ml_line_count - linecnt + 1;
  for (s = p; s < endp; ++s)
    if (*s == '\n')
      ++lnum;
  return lnum;
}

/*
 * Fill "*eap" to force the 'fileencoding', 'fileformat' and 'binary to be
 * equal to the buffer "buf".  Used for calling readfile().
 * Returns OK or FAIL.
 */
int prep_exarg(exarg_T *eap, buf_T *buf)
{
  eap->cmd = alloc((unsigned)(STRLEN(buf->b_p_ff)
                              + STRLEN(buf->b_p_fenc)
                              + 15));
  if (eap->cmd == NULL)
    return FAIL;

  sprintf((char *)eap->cmd, "e ++ff=%s ++enc=%s", buf->b_p_ff, buf->b_p_fenc);
  eap->force_enc = 14 + (int)STRLEN(buf->b_p_ff);
  eap->bad_char = buf->b_bad_char;
  eap->force_ff = 7;

  eap->force_bin = buf->b_p_bin ? FORCE_BIN : FORCE_NOBIN;
  eap->read_edit = FALSE;
  eap->forceit = FALSE;
  return OK;
}

/*
 * Set default or forced 'fileformat' and 'binary'.
 */
void set_file_options(int set_options, exarg_T *eap)
{
  /* set default 'fileformat' */
  if (set_options) {
    if (eap != NULL && eap->force_ff != 0)
      set_fileformat(get_fileformat_force(curbuf, eap), OPT_LOCAL);
    else if (*p_ffs != NUL)
      set_fileformat(default_fileformat(), OPT_LOCAL);
  }

  /* set or reset 'binary' */
  if (eap != NULL && eap->force_bin != 0) {
    int oldval = curbuf->b_p_bin;

    curbuf->b_p_bin = (eap->force_bin == FORCE_BIN);
    set_options_bin(oldval, curbuf->b_p_bin, OPT_LOCAL);
  }
}

/*
 * Set forced 'fileencoding'.
 */
void set_forced_fenc(exarg_T *eap)
{
  if (eap->force_enc != 0) {
    char_u *fenc = enc_canonize(eap->cmd + eap->force_enc);

    if (fenc != NULL)
      set_string_option_direct((char_u *)"fenc", -1,
          fenc, OPT_FREE|OPT_LOCAL, 0);
    vim_free(fenc);
  }
}

/*
 * Find next fileencoding to use from 'fileencodings'.
 * "pp" points to fenc_next.  It's advanced to the next item.
 * When there are no more items, an empty string is returned and *pp is set to
 * NULL.
 * When *pp is not set to NULL, the result is in allocated memory.
 */
static char_u *next_fenc(char_u **pp)
{
  char_u      *p;
  char_u      *r;

  if (**pp == NUL) {
    *pp = NULL;
    return (char_u *)"";
  }
  p = vim_strchr(*pp, ',');
  if (p == NULL) {
    r = enc_canonize(*pp);
    *pp += STRLEN(*pp);
  } else   {
    r = vim_strnsave(*pp, (int)(p - *pp));
    *pp = p + 1;
    if (r != NULL) {
      p = enc_canonize(r);
      vim_free(r);
      r = p;
    }
  }
  if (r == NULL) {      /* out of memory */
    r = (char_u *)"";
    *pp = NULL;
  }
  return r;
}

/*
 * Convert a file with the 'charconvert' expression.
 * This closes the file which is to be read, converts it and opens the
 * resulting file for reading.
 * Returns name of the resulting converted file (the caller should delete it
 * after reading it).
 * Returns NULL if the conversion failed ("*fdp" is not set) .
 */
static char_u *
readfile_charconvert (
    char_u *fname,             /* name of input file */
    char_u *fenc,              /* converted from */
    int *fdp               /* in/out: file descriptor of file */
)
{
  char_u      *tmpname;
  char_u      *errmsg = NULL;

  tmpname = vim_tempname('r');
  if (tmpname == NULL)
    errmsg = (char_u *)_("Can't find temp file for conversion");
  else {
    close(*fdp);                /* close the input file, ignore errors */
    *fdp = -1;
    if (eval_charconvert(fenc, enc_utf8 ? (char_u *)"utf-8" : p_enc,
            fname, tmpname) == FAIL)
      errmsg = (char_u *)_("Conversion with 'charconvert' failed");
    if (errmsg == NULL && (*fdp = mch_open((char *)tmpname,
                               O_RDONLY | O_EXTRA, 0)) < 0)
      errmsg = (char_u *)_("can't read output of 'charconvert'");
  }

  if (errmsg != NULL) {
    /* Don't use emsg(), it breaks mappings, the retry with
     * another type of conversion might still work. */
    MSG(errmsg);
    if (tmpname != NULL) {
      mch_remove(tmpname);              /* delete converted file */
      vim_free(tmpname);
      tmpname = NULL;
    }
  }

  /* If the input file is closed, open it (caller should check for error). */
  if (*fdp < 0)
    *fdp = mch_open((char *)fname, O_RDONLY | O_EXTRA, 0);

  return tmpname;
}


/*
 * Read marks for the current buffer from the viminfo file, when we support
 * buffer marks and the buffer has a name.
 */
static void check_marks_read(void)                 {
  if (!curbuf->b_marks_read && get_viminfo_parameter('\'') > 0
      && curbuf->b_ffname != NULL)
    read_viminfo(NULL, VIF_WANT_MARKS);

  /* Always set b_marks_read; needed when 'viminfo' is changed to include
   * the ' parameter after opening a buffer. */
  curbuf->b_marks_read = TRUE;
}

/*
 * Get the crypt method used for a file from "ptr[len]", the magic text at the
 * start of the file.
 * Returns -1 when no encryption used.
 */
static int crypt_method_from_magic(char *ptr, int len)
{
  int i;

  for (i = 0; i < (int)(sizeof(crypt_magic) / sizeof(crypt_magic[0])); i++) {
    if (len < (CRYPT_MAGIC_LEN + crypt_salt_len[i] + crypt_seed_len[i]))
      continue;
    if (memcmp(ptr, crypt_magic[i], CRYPT_MAGIC_LEN) == 0)
      return i;
  }

  i = (int)STRLEN(crypt_magic_head);
  if (len >= i && memcmp(ptr, crypt_magic_head, i) == 0)
    EMSG(_("E821: File is encrypted with unknown method"));

  return -1;
}

/*
 * Check for magic number used for encryption.  Applies to the current buffer.
 * If found, the magic number is removed from ptr[*sizep] and *sizep and
 * *filesizep are updated.
 * Return the (new) encryption key, NULL for no encryption.
 */
static char_u *
check_for_cryptkey (
    char_u *cryptkey,          /* previous encryption key or NULL */
    char_u *ptr,               /* pointer to read bytes */
    long *sizep,             /* length of read bytes */
    off_t *filesizep,         /* nr of bytes used from file */
    int newfile,                    /* editing a new buffer */
    char_u *fname,             /* file name to display */
    int *did_ask           /* flag: whether already asked for key */
)
{
  int method = crypt_method_from_magic((char *)ptr, *sizep);
  int b_p_ro = curbuf->b_p_ro;

  if (method >= 0) {
    /* Mark the buffer as read-only until the decryption has taken place.
     * Avoids accidentally overwriting the file with garbage. */
    curbuf->b_p_ro = TRUE;

    set_crypt_method(curbuf, method);
    if (method > 0)
      (void)blowfish_self_test();
    if (cryptkey == NULL && !*did_ask) {
      if (*curbuf->b_p_key)
        cryptkey = curbuf->b_p_key;
      else {
        /* When newfile is TRUE, store the typed key in the 'key'
         * option and don't free it.  bf needs hash of the key saved.
         * Don't ask for the key again when first time Enter was hit.
         * Happens when retrying to detect encoding. */
        smsg((char_u *)_(need_key_msg), fname);
        msg_scroll = TRUE;
        cryptkey = get_crypt_key(newfile, FALSE);
        *did_ask = TRUE;

        /* check if empty key entered */
        if (cryptkey != NULL && *cryptkey == NUL) {
          if (cryptkey != curbuf->b_p_key)
            vim_free(cryptkey);
          cryptkey = NULL;
        }
      }
    }

    if (cryptkey != NULL) {
      int seed_len = crypt_seed_len[method];
      int salt_len = crypt_salt_len[method];

      crypt_push_state();
      use_crypt_method = method;
      if (method == 0)
        crypt_init_keys(cryptkey);
      else {
        bf_key_init(cryptkey, ptr + CRYPT_MAGIC_LEN, salt_len);
        bf_ofb_init(ptr + CRYPT_MAGIC_LEN + salt_len, seed_len);
      }

      /* Remove magic number from the text */
      *filesizep += CRYPT_MAGIC_LEN + salt_len + seed_len;
      *sizep -= CRYPT_MAGIC_LEN + salt_len + seed_len;
      mch_memmove(ptr, ptr + CRYPT_MAGIC_LEN + salt_len + seed_len,
          (size_t)*sizep);
      /* Restore the read-only flag. */
      curbuf->b_p_ro = b_p_ro;
    }
  }
  /* When starting to edit a new file which does not have encryption, clear
   * the 'key' option, except when starting up (called with -x argument) */
  else if (newfile && *curbuf->b_p_key != NUL && !starting)
    set_option_value((char_u *)"key", 0L, (char_u *)"", OPT_LOCAL);

  return cryptkey;
}

/*
 * Check for magic number used for encryption.  Applies to the current buffer.
 * If found and decryption is possible returns OK;
 */
int prepare_crypt_read(FILE *fp)
{
  int method;
  char_u buffer[CRYPT_MAGIC_LEN + CRYPT_SALT_LEN_MAX
                + CRYPT_SEED_LEN_MAX + 2];

  if (fread(buffer, CRYPT_MAGIC_LEN, 1, fp) != 1)
    return FAIL;
  method = crypt_method_from_magic((char *)buffer,
      CRYPT_MAGIC_LEN +
      CRYPT_SEED_LEN_MAX +
      CRYPT_SALT_LEN_MAX);
  if (method < 0 || method != get_crypt_method(curbuf))
    return FAIL;

  crypt_push_state();
  if (method == 0)
    crypt_init_keys(curbuf->b_p_key);
  else {
    int salt_len = crypt_salt_len[method];
    int seed_len = crypt_seed_len[method];

    if (fread(buffer, salt_len + seed_len, 1, fp) != 1)
      return FAIL;
    bf_key_init(curbuf->b_p_key, buffer, salt_len);
    bf_ofb_init(buffer + salt_len, seed_len);
  }
  return OK;
}

/*
 * Prepare for writing encrypted bytes for buffer "buf".
 * Returns a pointer to an allocated header of length "*lenp".
 * When out of memory returns NULL.
 * Otherwise calls crypt_push_state(), call crypt_pop_state() later.
 */
char_u *prepare_crypt_write(buf_T *buf, int *lenp)
{
  char_u  *header;
  int seed_len = crypt_seed_len[get_crypt_method(buf)];
  int salt_len = crypt_salt_len[get_crypt_method(buf)];
  char_u  *salt;
  char_u  *seed;

  header = alloc_clear(CRYPT_MAGIC_LEN + CRYPT_SALT_LEN_MAX
      + CRYPT_SEED_LEN_MAX + 2);
  if (header != NULL) {
    crypt_push_state();
    use_crypt_method = get_crypt_method(buf);      /* select zip or blowfish */
    vim_strncpy(header, (char_u *)crypt_magic[use_crypt_method],
        CRYPT_MAGIC_LEN);
    if (use_crypt_method == 0)
      crypt_init_keys(buf->b_p_key);
    else {
      /* Using blowfish, add salt and seed. */
      salt = header + CRYPT_MAGIC_LEN;
      seed = salt + salt_len;
      sha2_seed(salt, salt_len, seed, seed_len);
      bf_key_init(buf->b_p_key, salt, salt_len);
      bf_ofb_init(seed, seed_len);
    }
  }
  *lenp = CRYPT_MAGIC_LEN + salt_len + seed_len;
  return header;
}


#ifdef UNIX
static void 
set_file_time (
    char_u *fname,
    time_t atime,               /* access time */
    time_t mtime               /* modification time */
)
{
# if defined(HAVE_UTIME) && defined(HAVE_UTIME_H)
  struct utimbuf buf;

  buf.actime  = atime;
  buf.modtime = mtime;
  (void)utime((char *)fname, &buf);
# else
#  if defined(HAVE_UTIMES)
  struct timeval tvp[2];

  tvp[0].tv_sec   = atime;
  tvp[0].tv_usec  = 0;
  tvp[1].tv_sec   = mtime;
  tvp[1].tv_usec  = 0;
  (void)utimes((char *)fname, (const struct timeval *)&tvp);
#  endif
# endif
}
#endif /* UNIX */


/*
 * Return TRUE if a file appears to be read-only from the file permissions.
 */
int 
check_file_readonly (
    char_u *fname,             /* full path to file */
    int perm                       /* known permissions on file */
)
{
#ifndef USE_MCH_ACCESS
  int fd = 0;
#endif

  return
#ifdef USE_MCH_ACCESS
# ifdef UNIX
    (perm & 0222) == 0 ||
# endif
    mch_access((char *)fname, W_OK)
#else
    (fd = mch_open((char *)fname, O_RDWR | O_EXTRA, 0)) < 0
    ? TRUE : (close(fd), FALSE)
#endif
  ;
}


/*
 * buf_write() - write to file "fname" lines "start" through "end"
 *
 * We do our own buffering here because fwrite() is so slow.
 *
 * If "forceit" is true, we don't care for errors when attempting backups.
 * In case of an error everything possible is done to restore the original
 * file.  But when "forceit" is TRUE, we risk losing it.
 *
 * When "reset_changed" is TRUE and "append" == FALSE and "start" == 1 and
 * "end" == curbuf->b_ml.ml_line_count, reset curbuf->b_changed.
 *
 * This function must NOT use NameBuff (because it's called by autowrite()).
 *
 * return FAIL for failure, OK otherwise
 */
int 
buf_write (
    buf_T *buf,
    char_u *fname,
    char_u *sfname,
    linenr_T start,
    linenr_T end,
    exarg_T *eap,                   /* for forced 'ff' and 'fenc', can be
                                           NULL! */
    int append,                             /* append to the file */
    int forceit,
    int reset_changed,
    int filtering
)
{
  int fd;
  char_u          *backup = NULL;
  int backup_copy = FALSE;               /* copy the original file? */
  int dobackup;
  char_u          *ffname;
  char_u          *wfname = NULL;       /* name of file to write to */
  char_u          *s;
  char_u          *ptr;
  char_u c;
  int len;
  linenr_T lnum;
  long nchars;
  char_u          *errmsg = NULL;
  int errmsg_allocated = FALSE;
  char_u          *errnum = NULL;
  char_u          *buffer;
  char_u smallbuf[SMBUFSIZE];
  char_u          *backup_ext;
  int bufsize;
  long perm;                                /* file permissions */
  int retval = OK;
  int newfile = FALSE;                      /* TRUE if file doesn't exist yet */
  int msg_save = msg_scroll;
  int overwriting;                          /* TRUE if writing over original */
  int no_eol = FALSE;                       /* no end-of-line written */
  int device = FALSE;                       /* writing to a device */
  struct stat st_old;
  int prev_got_int = got_int;
  int file_readonly = FALSE;                /* overwritten file is read-only */
  static char     *err_readonly =
    "is read-only (cannot override: \"W\" in 'cpoptions')";
#if defined(UNIX) || defined(__EMX__XX)     /*XXX fix me sometime? */
  int made_writable = FALSE;                /* 'w' bit has been set */
#endif
  /* writing everything */
  int whole = (start == 1 && end == buf->b_ml.ml_line_count);
  linenr_T old_line_count = buf->b_ml.ml_line_count;
  int attr;
  int fileformat;
  int write_bin;
  struct bw_info write_info;            /* info for buf_write_bytes() */
  int converted = FALSE;
  int notconverted = FALSE;
  char_u          *fenc;                /* effective 'fileencoding' */
  char_u          *fenc_tofree = NULL;   /* allocated "fenc" */
#ifdef HAS_BW_FLAGS
  int wb_flags = 0;
#endif
#ifdef HAVE_ACL
  vim_acl_T acl = NULL;                 /* ACL copied from original file to
                                           backup or new file */
#endif
  int write_undo_file = FALSE;
  context_sha256_T sha_ctx;
  int crypt_method_used;

  if (fname == NULL || *fname == NUL)   /* safety check */
    return FAIL;
  if (buf->b_ml.ml_mfp == NULL) {
    /* This can happen during startup when there is a stray "w" in the
     * vimrc file. */
    EMSG(_(e_emptybuf));
    return FAIL;
  }

  /*
   * Disallow writing from .exrc and .vimrc in current directory for
   * security reasons.
   */
  if (check_secure())
    return FAIL;

  /* Avoid a crash for a long name. */
  if (STRLEN(fname) >= MAXPATHL) {
    EMSG(_(e_longname));
    return FAIL;
  }

  /* must init bw_conv_buf and bw_iconv_fd before jumping to "fail" */
  write_info.bw_conv_buf = NULL;
  write_info.bw_conv_error = FALSE;
  write_info.bw_conv_error_lnum = 0;
  write_info.bw_restlen = 0;
# ifdef USE_ICONV
  write_info.bw_iconv_fd = (iconv_t)-1;
# endif

  /* After writing a file changedtick changes but we don't want to display
   * the line. */
  ex_no_reprint = TRUE;

  /*
   * If there is no file name yet, use the one for the written file.
   * BF_NOTEDITED is set to reflect this (in case the write fails).
   * Don't do this when the write is for a filter command.
   * Don't do this when appending.
   * Only do this when 'cpoptions' contains the 'F' flag.
   */
  if (buf->b_ffname == NULL
      && reset_changed
      && whole
      && buf == curbuf
      && !bt_nofile(buf)
      && !filtering
      && (!append || vim_strchr(p_cpo, CPO_FNAMEAPP) != NULL)
      && vim_strchr(p_cpo, CPO_FNAMEW) != NULL) {
    if (set_rw_fname(fname, sfname) == FAIL)
      return FAIL;
    buf = curbuf;           /* just in case autocmds made "buf" invalid */
  }

  if (sfname == NULL)
    sfname = fname;
  /*
   * For Unix: Use the short file name whenever possible.
   * Avoids problems with networks and when directory names are changed.
   * Don't do this for MS-DOS, a "cd" in a sub-shell may have moved us to
   * another directory, which we don't detect
   */
  ffname = fname;                           /* remember full fname */
#ifdef UNIX
  fname = sfname;
#endif

  if (buf->b_ffname != NULL && fnamecmp(ffname, buf->b_ffname) == 0)
    overwriting = TRUE;
  else
    overwriting = FALSE;

  if (exiting)
    settmode(TMODE_COOK);           /* when exiting allow typeahead now */

  ++no_wait_return;                 /* don't wait for return yet */

  /*
   * Set '[ and '] marks to the lines to be written.
   */
  buf->b_op_start.lnum = start;
  buf->b_op_start.col = 0;
  buf->b_op_end.lnum = end;
  buf->b_op_end.col = 0;

  {
    aco_save_T aco;
    int buf_ffname = FALSE;
    int buf_sfname = FALSE;
    int buf_fname_f = FALSE;
    int buf_fname_s = FALSE;
    int did_cmd = FALSE;
    int nofile_err = FALSE;
    int empty_memline = (buf->b_ml.ml_mfp == NULL);

    /*
     * Apply PRE autocommands.
     * Set curbuf to the buffer to be written.
     * Careful: The autocommands may call buf_write() recursively!
     */
    if (ffname == buf->b_ffname)
      buf_ffname = TRUE;
    if (sfname == buf->b_sfname)
      buf_sfname = TRUE;
    if (fname == buf->b_ffname)
      buf_fname_f = TRUE;
    if (fname == buf->b_sfname)
      buf_fname_s = TRUE;

    /* set curwin/curbuf to buf and save a few things */
    aucmd_prepbuf(&aco, buf);

    if (append) {
      if (!(did_cmd = apply_autocmds_exarg(EVENT_FILEAPPENDCMD,
                sfname, sfname, FALSE, curbuf, eap))) {
        if (overwriting && bt_nofile(curbuf))
          nofile_err = TRUE;
        else
          apply_autocmds_exarg(EVENT_FILEAPPENDPRE,
              sfname, sfname, FALSE, curbuf, eap);
      }
    } else if (filtering)   {
      apply_autocmds_exarg(EVENT_FILTERWRITEPRE,
          NULL, sfname, FALSE, curbuf, eap);
    } else if (reset_changed && whole)   {
      int was_changed = curbufIsChanged();

      did_cmd = apply_autocmds_exarg(EVENT_BUFWRITECMD,
          sfname, sfname, FALSE, curbuf, eap);
      if (did_cmd) {
        if (was_changed && !curbufIsChanged()) {
          /* Written everything correctly and BufWriteCmd has reset
           * 'modified': Correct the undo information so that an
           * undo now sets 'modified'. */
          u_unchanged(curbuf);
          u_update_save_nr(curbuf);
        }
      } else   {
        if (overwriting && bt_nofile(curbuf))
          nofile_err = TRUE;
        else
          apply_autocmds_exarg(EVENT_BUFWRITEPRE,
              sfname, sfname, FALSE, curbuf, eap);
      }
    } else   {
      if (!(did_cmd = apply_autocmds_exarg(EVENT_FILEWRITECMD,
                sfname, sfname, FALSE, curbuf, eap))) {
        if (overwriting && bt_nofile(curbuf))
          nofile_err = TRUE;
        else
          apply_autocmds_exarg(EVENT_FILEWRITEPRE,
              sfname, sfname, FALSE, curbuf, eap);
      }
    }

    /* restore curwin/curbuf and a few other things */
    aucmd_restbuf(&aco);

    /*
     * In three situations we return here and don't write the file:
     * 1. the autocommands deleted or unloaded the buffer.
     * 2. The autocommands abort script processing.
     * 3. If one of the "Cmd" autocommands was executed.
     */
    if (!buf_valid(buf))
      buf = NULL;
    if (buf == NULL || (buf->b_ml.ml_mfp == NULL && !empty_memline)
        || did_cmd || nofile_err
        || aborting()
        ) {
      --no_wait_return;
      msg_scroll = msg_save;
      if (nofile_err)
        EMSG(_("E676: No matching autocommands for acwrite buffer"));

      if (nofile_err
          || aborting()
          )
        /* An aborting error, interrupt or exception in the
         * autocommands. */
        return FAIL;
      if (did_cmd) {
        if (buf == NULL)
          /* The buffer was deleted.  We assume it was written
           * (can't retry anyway). */
          return OK;
        if (overwriting) {
          /* Assume the buffer was written, update the timestamp. */
          ml_timestamp(buf);
          if (append)
            buf->b_flags &= ~BF_NEW;
          else
            buf->b_flags &= ~BF_WRITE_MASK;
        }
        if (reset_changed && buf->b_changed && !append
            && (overwriting || vim_strchr(p_cpo, CPO_PLUS) != NULL))
          /* Buffer still changed, the autocommands didn't work
           * properly. */
          return FAIL;
        return OK;
      }
      if (!aborting())
        EMSG(_("E203: Autocommands deleted or unloaded buffer to be written"));
      return FAIL;
    }

    /*
     * The autocommands may have changed the number of lines in the file.
     * When writing the whole file, adjust the end.
     * When writing part of the file, assume that the autocommands only
     * changed the number of lines that are to be written (tricky!).
     */
    if (buf->b_ml.ml_line_count != old_line_count) {
      if (whole)                                                /* write all */
        end = buf->b_ml.ml_line_count;
      else if (buf->b_ml.ml_line_count > old_line_count)        /* more lines */
        end += buf->b_ml.ml_line_count - old_line_count;
      else {                                                    /* less lines */
        end -= old_line_count - buf->b_ml.ml_line_count;
        if (end < start) {
          --no_wait_return;
          msg_scroll = msg_save;
          EMSG(_("E204: Autocommand changed number of lines in unexpected way"));
          return FAIL;
        }
      }
    }

    /*
     * The autocommands may have changed the name of the buffer, which may
     * be kept in fname, ffname and sfname.
     */
    if (buf_ffname)
      ffname = buf->b_ffname;
    if (buf_sfname)
      sfname = buf->b_sfname;
    if (buf_fname_f)
      fname = buf->b_ffname;
    if (buf_fname_s)
      fname = buf->b_sfname;
  }


  if (shortmess(SHM_OVER) && !exiting)
    msg_scroll = FALSE;             /* overwrite previous file message */
  else
    msg_scroll = TRUE;              /* don't overwrite previous file message */
  if (!filtering)
    filemess(buf,
#ifndef UNIX
        sfname,
#else
        fname,
#endif
        (char_u *)"", 0);               /* show that we are busy */
  msg_scroll = FALSE;               /* always overwrite the file message now */

  buffer = alloc(BUFSIZE);
  if (buffer == NULL) {             /* can't allocate big buffer, use small
                                     * one (to be able to write when out of
                                     * memory) */
    buffer = smallbuf;
    bufsize = SMBUFSIZE;
  } else
    bufsize = BUFSIZE;

  /*
   * Get information about original file (if there is one).
   */
#if defined(UNIX) && !defined(ARCHIE)
  st_old.st_dev = 0;
  st_old.st_ino = 0;
  perm = -1;
  if (mch_stat((char *)fname, &st_old) < 0)
    newfile = TRUE;
  else {
    perm = st_old.st_mode;
    if (!S_ISREG(st_old.st_mode)) {             /* not a file */
      if (S_ISDIR(st_old.st_mode)) {
        errnum = (char_u *)"E502: ";
        errmsg = (char_u *)_("is a directory");
        goto fail;
      }
      if (mch_nodetype(fname) != NODE_WRITABLE) {
        errnum = (char_u *)"E503: ";
        errmsg = (char_u *)_("is not a file or writable device");
        goto fail;
      }
      /* It's a device of some kind (or a fifo) which we can write to
       * but for which we can't make a backup. */
      device = TRUE;
      newfile = TRUE;
      perm = -1;
    }
  }
#else /* !UNIX */
      /*
       * Check for a writable device name.
       */
  c = mch_nodetype(fname);
  if (c == NODE_OTHER) {
    errnum = (char_u *)"E503: ";
    errmsg = (char_u *)_("is not a file or writable device");
    goto fail;
  }
  if (c == NODE_WRITABLE) {
    device = TRUE;
    newfile = TRUE;
    perm = -1;
  } else   {
    perm = mch_getperm(fname);
    if (perm < 0)
      newfile = TRUE;
    else if (mch_isdir(fname)) {
      errnum = (char_u *)"E502: ";
      errmsg = (char_u *)_("is a directory");
      goto fail;
    }
    if (overwriting)
      (void)mch_stat((char *)fname, &st_old);
  }
#endif /* !UNIX */

  if (!device && !newfile) {
    /*
     * Check if the file is really writable (when renaming the file to
     * make a backup we won't discover it later).
     */
    file_readonly = check_file_readonly(fname, (int)perm);

    if (!forceit && file_readonly) {
      if (vim_strchr(p_cpo, CPO_FWRITE) != NULL) {
        errnum = (char_u *)"E504: ";
        errmsg = (char_u *)_(err_readonly);
      } else   {
        errnum = (char_u *)"E505: ";
        errmsg = (char_u *)_("is read-only (add ! to override)");
      }
      goto fail;
    }

    /*
     * Check if the timestamp hasn't changed since reading the file.
     */
    if (overwriting) {
      retval = check_mtime(buf, &st_old);
      if (retval == FAIL)
        goto fail;
    }
  }

#ifdef HAVE_ACL
  /*
   * For systems that support ACL: get the ACL from the original file.
   */
  if (!newfile)
    acl = mch_get_acl(fname);
#endif

  /*
   * If 'backupskip' is not empty, don't make a backup for some files.
   */
  dobackup = (p_wb || p_bk || *p_pm != NUL);
  if (dobackup && *p_bsk != NUL && match_file_list(p_bsk, sfname, ffname))
    dobackup = FALSE;

  /*
   * Save the value of got_int and reset it.  We don't want a previous
   * interruption cancel writing, only hitting CTRL-C while writing should
   * abort it.
   */
  prev_got_int = got_int;
  got_int = FALSE;

  /* Mark the buffer as 'being saved' to prevent changed buffer warnings */
  buf->b_saving = TRUE;

  /*
   * If we are not appending or filtering, the file exists, and the
   * 'writebackup', 'backup' or 'patchmode' option is set, need a backup.
   * When 'patchmode' is set also make a backup when appending.
   *
   * Do not make any backup, if 'writebackup' and 'backup' are both switched
   * off.  This helps when editing large files on almost-full disks.
   */
  if (!(append && *p_pm == NUL) && !filtering && perm >= 0 && dobackup) {
#if defined(UNIX) || defined(WIN32)
    struct stat st;
#endif

    if ((bkc_flags & BKC_YES) || append)        /* "yes" */
      backup_copy = TRUE;
#if defined(UNIX) || defined(WIN32)
    else if ((bkc_flags & BKC_AUTO)) {          /* "auto" */
      int i;

# ifdef UNIX
      /*
       * Don't rename the file when:
       * - it's a hard link
       * - it's a symbolic link
       * - we don't have write permission in the directory
       * - we can't set the owner/group of the new file
       */
      if (st_old.st_nlink > 1
          || mch_lstat((char *)fname, &st) < 0
          || st.st_dev != st_old.st_dev
          || st.st_ino != st_old.st_ino
#  ifndef HAVE_FCHOWN
          || st.st_uid != st_old.st_uid
          || st.st_gid != st_old.st_gid
#  endif
          )
        backup_copy = TRUE;
      else
# else
# endif
      {
        /*
         * Check if we can create a file and set the owner/group to
         * the ones from the original file.
         * First find a file name that doesn't exist yet (use some
         * arbitrary numbers).
         */
        STRCPY(IObuff, fname);
        for (i = 4913;; i += 123) {
          sprintf((char *)gettail(IObuff), "%d", i);
          if (mch_lstat((char *)IObuff, &st) < 0)
            break;
        }
        fd = mch_open((char *)IObuff,
            O_CREAT|O_WRONLY|O_EXCL|O_NOFOLLOW, perm);
        if (fd < 0)             /* can't write in directory */
          backup_copy = TRUE;
        else {
# ifdef UNIX
#  ifdef HAVE_FCHOWN
          ignored = fchown(fd, st_old.st_uid, st_old.st_gid);
#  endif
          if (mch_stat((char *)IObuff, &st) < 0
              || st.st_uid != st_old.st_uid
              || st.st_gid != st_old.st_gid
              || (long)st.st_mode != perm)
            backup_copy = TRUE;
# endif
          /* Close the file before removing it, on MS-Windows we
           * can't delete an open file. */
          close(fd);
          mch_remove(IObuff);
        }
      }
    }

    /*
     * Break symlinks and/or hardlinks if we've been asked to.
     */
    if ((bkc_flags & BKC_BREAKSYMLINK) || (bkc_flags & BKC_BREAKHARDLINK)) {
# ifdef UNIX
      int lstat_res;

      lstat_res = mch_lstat((char *)fname, &st);

      /* Symlinks. */
      if ((bkc_flags & BKC_BREAKSYMLINK)
          && lstat_res == 0
          && st.st_ino != st_old.st_ino)
        backup_copy = FALSE;

      /* Hardlinks. */
      if ((bkc_flags & BKC_BREAKHARDLINK)
          && st_old.st_nlink > 1
          && (lstat_res != 0 || st.st_ino == st_old.st_ino))
        backup_copy = FALSE;
# else
# endif
    }

#endif

    /* make sure we have a valid backup extension to use */
    if (*p_bex == NUL)
      backup_ext = (char_u *)".bak";
    else
      backup_ext = p_bex;

    if (backup_copy
        && (fd = mch_open((char *)fname, O_RDONLY | O_EXTRA, 0)) >= 0) {
      int bfd;
      char_u      *copybuf, *wp;
      int some_error = FALSE;
      struct stat st_new;
      char_u      *dirp;
      char_u      *rootname;
#if defined(UNIX) && !defined(SHORT_FNAME)
      int did_set_shortname;
#endif

      copybuf = alloc(BUFSIZE + 1);
      if (copybuf == NULL) {
        some_error = TRUE;                  /* out of memory */
        goto nobackup;
      }

      /*
       * Try to make the backup in each directory in the 'bdir' option.
       *
       * Unix semantics has it, that we may have a writable file,
       * that cannot be recreated with a simple open(..., O_CREAT, ) e.g:
       *  - the directory is not writable,
       *  - the file may be a symbolic link,
       *  - the file may belong to another user/group, etc.
       *
       * For these reasons, the existing writable file must be truncated
       * and reused. Creation of a backup COPY will be attempted.
       */
      dirp = p_bdir;
      while (*dirp) {
#ifdef UNIX
        st_new.st_ino = 0;
        st_new.st_dev = 0;
        st_new.st_gid = 0;
#endif

        /*
         * Isolate one directory name, using an entry in 'bdir'.
         */
        (void)copy_option_part(&dirp, copybuf, BUFSIZE, ",");
        rootname = get_file_in_dir(fname, copybuf);
        if (rootname == NULL) {
          some_error = TRUE;                /* out of memory */
          goto nobackup;
        }

#if defined(UNIX) && !defined(SHORT_FNAME)
        did_set_shortname = FALSE;
#endif

        /*
         * May try twice if 'shortname' not set.
         */
        for (;; ) {
          /*
           * Make backup file name.
           */
          backup = buf_modname(
#ifdef SHORT_FNAME
              TRUE,
#else
              (buf->b_p_sn || buf->b_shortname),
#endif
              rootname, backup_ext, FALSE);
          if (backup == NULL) {
            vim_free(rootname);
            some_error = TRUE;                          /* out of memory */
            goto nobackup;
          }

          /*
           * Check if backup file already exists.
           */
          if (mch_stat((char *)backup, &st_new) >= 0) {
#ifdef UNIX
            /*
             * Check if backup file is same as original file.
             * May happen when modname() gave the same file back.
             * E.g. silly link, or file name-length reached.
             * If we don't check here, we either ruin the file
             * when copying or erase it after writing. jw.
             */
            if (st_new.st_dev == st_old.st_dev
                && st_new.st_ino == st_old.st_ino) {
              vim_free(backup);
              backup = NULL;                    /* no backup file to delete */
# ifndef SHORT_FNAME
              /*
               * may try again with 'shortname' set
               */
              if (!(buf->b_shortname || buf->b_p_sn)) {
                buf->b_shortname = TRUE;
                did_set_shortname = TRUE;
                continue;
              }
              /* setting shortname didn't help */
              if (did_set_shortname)
                buf->b_shortname = FALSE;
# endif
              break;
            }
#endif

            /*
             * If we are not going to keep the backup file, don't
             * delete an existing one, try to use another name.
             * Change one character, just before the extension.
             */
            if (!p_bk) {
              wp = backup + STRLEN(backup) - 1
                   - STRLEN(backup_ext);
              if (wp < backup)                  /* empty file name ??? */
                wp = backup;
              *wp = 'z';
              while (*wp > 'a'
                     && mch_stat((char *)backup, &st_new) >= 0)
                --*wp;
              /* They all exist??? Must be something wrong. */
              if (*wp == 'a') {
                vim_free(backup);
                backup = NULL;
              }
            }
          }
          break;
        }
        vim_free(rootname);

        /*
         * Try to create the backup file
         */
        if (backup != NULL) {
          /* remove old backup, if present */
          mch_remove(backup);
          /* Open with O_EXCL to avoid the file being created while
           * we were sleeping (symlink hacker attack?) */
          bfd = mch_open((char *)backup,
              O_WRONLY|O_CREAT|O_EXTRA|O_EXCL|O_NOFOLLOW,
              perm & 0777);
          if (bfd < 0) {
            vim_free(backup);
            backup = NULL;
          } else   {
            /* set file protection same as original file, but
             * strip s-bit */
            (void)mch_setperm(backup, perm & 0777);

#ifdef UNIX
            /*
             * Try to set the group of the backup same as the
             * original file. If this fails, set the protection
             * bits for the group same as the protection bits for
             * others.
             */
            if (st_new.st_gid != st_old.st_gid
# ifdef HAVE_FCHOWN  /* sequent-ptx lacks fchown() */
                && fchown(bfd, (uid_t)-1, st_old.st_gid) != 0
# endif
                )
              mch_setperm(backup,
                  (perm & 0707) | ((perm & 07) << 3));
# ifdef HAVE_SELINUX
            mch_copy_sec(fname, backup);
# endif
#endif

            /*
             * copy the file.
             */
            write_info.bw_fd = bfd;
            write_info.bw_buf = copybuf;
#ifdef HAS_BW_FLAGS
            write_info.bw_flags = FIO_NOCONVERT;
#endif
            while ((write_info.bw_len = read_eintr(fd, copybuf,
                        BUFSIZE)) > 0) {
              if (buf_write_bytes(&write_info) == FAIL) {
                errmsg = (char_u *)_(
                    "E506: Can't write to backup file (add ! to override)");
                break;
              }
              ui_breakcheck();
              if (got_int) {
                errmsg = (char_u *)_(e_interr);
                break;
              }
            }

            if (close(bfd) < 0 && errmsg == NULL)
              errmsg = (char_u *)_(
                  "E507: Close error for backup file (add ! to override)");
            if (write_info.bw_len < 0)
              errmsg = (char_u *)_(
                  "E508: Can't read file for backup (add ! to override)");
#ifdef UNIX
            set_file_time(backup, st_old.st_atime, st_old.st_mtime);
#endif
#ifdef HAVE_ACL
            mch_set_acl(backup, acl);
#endif
#ifdef HAVE_SELINUX
            mch_copy_sec(fname, backup);
#endif
            break;
          }
        }
      }
nobackup:
      close(fd);                /* ignore errors for closing read file */
      vim_free(copybuf);

      if (backup == NULL && errmsg == NULL)
        errmsg = (char_u *)_(
            "E509: Cannot create backup file (add ! to override)");
      /* ignore errors when forceit is TRUE */
      if ((some_error || errmsg != NULL) && !forceit) {
        retval = FAIL;
        goto fail;
      }
      errmsg = NULL;
    } else   {
      char_u      *dirp;
      char_u      *p;
      char_u      *rootname;

      /*
       * Make a backup by renaming the original file.
       */
      /*
       * If 'cpoptions' includes the "W" flag, we don't want to
       * overwrite a read-only file.  But rename may be possible
       * anyway, thus we need an extra check here.
       */
      if (file_readonly && vim_strchr(p_cpo, CPO_FWRITE) != NULL) {
        errnum = (char_u *)"E504: ";
        errmsg = (char_u *)_(err_readonly);
        goto fail;
      }

      /*
       *
       * Form the backup file name - change path/fo.o.h to
       * path/fo.o.h.bak Try all directories in 'backupdir', first one
       * that works is used.
       */
      dirp = p_bdir;
      while (*dirp) {
        /*
         * Isolate one directory name and make the backup file name.
         */
        (void)copy_option_part(&dirp, IObuff, IOSIZE, ",");
        rootname = get_file_in_dir(fname, IObuff);
        if (rootname == NULL)
          backup = NULL;
        else {
          backup = buf_modname(
#ifdef SHORT_FNAME
              TRUE,
#else
              (buf->b_p_sn || buf->b_shortname),
#endif
              rootname, backup_ext, FALSE);
          vim_free(rootname);
        }

        if (backup != NULL) {
          /*
           * If we are not going to keep the backup file, don't
           * delete an existing one, try to use another name.
           * Change one character, just before the extension.
           */
          if (!p_bk && mch_getperm(backup) >= 0) {
            p = backup + STRLEN(backup) - 1 - STRLEN(backup_ext);
            if (p < backup)             /* empty file name ??? */
              p = backup;
            *p = 'z';
            while (*p > 'a' && mch_getperm(backup) >= 0)
              --*p;
            /* They all exist??? Must be something wrong! */
            if (*p == 'a') {
              vim_free(backup);
              backup = NULL;
            }
          }
        }
        if (backup != NULL) {
          /*
           * Delete any existing backup and move the current version
           * to the backup.	For safety, we don't remove the backup
           * until the write has finished successfully. And if the
           * 'backup' option is set, leave it around.
           */
          /*
           * If the renaming of the original file to the backup file
           * works, quit here.
           */
          if (vim_rename(fname, backup) == 0)
            break;

          vim_free(backup);             /* don't do the rename below */
          backup = NULL;
        }
      }
      if (backup == NULL && !forceit) {
        errmsg = (char_u *)_("E510: Can't make backup file (add ! to override)");
        goto fail;
      }
    }
  }

#if defined(UNIX) && !defined(ARCHIE)
  /* When using ":w!" and the file was read-only: make it writable */
  if (forceit && perm >= 0 && !(perm & 0200) && st_old.st_uid == getuid()
      && vim_strchr(p_cpo, CPO_FWRITE) == NULL) {
    perm |= 0200;
    (void)mch_setperm(fname, perm);
    made_writable = TRUE;
  }
#endif

  /* When using ":w!" and writing to the current file, 'readonly' makes no
   * sense, reset it, unless 'Z' appears in 'cpoptions'.  */
  if (forceit && overwriting && vim_strchr(p_cpo, CPO_KEEPRO) == NULL) {
    buf->b_p_ro = FALSE;
    need_maketitle = TRUE;          /* set window title later */
    status_redraw_all();            /* redraw status lines later */
  }

  if (end > buf->b_ml.ml_line_count)
    end = buf->b_ml.ml_line_count;
  if (buf->b_ml.ml_flags & ML_EMPTY)
    start = end + 1;

  /*
   * If the original file is being overwritten, there is a small chance that
   * we crash in the middle of writing. Therefore the file is preserved now.
   * This makes all block numbers positive so that recovery does not need
   * the original file.
   * Don't do this if there is a backup file and we are exiting.
   */
  if (reset_changed && !newfile && overwriting
      && !(exiting && backup != NULL)) {
    ml_preserve(buf, FALSE);
    if (got_int) {
      errmsg = (char_u *)_(e_interr);
      goto restore_backup;
    }
  }


  /* Default: write the file directly.  May write to a temp file for
   * multi-byte conversion. */
  wfname = fname;

  /* Check for forced 'fileencoding' from "++opt=val" argument. */
  if (eap != NULL && eap->force_enc != 0) {
    fenc = eap->cmd + eap->force_enc;
    fenc = enc_canonize(fenc);
    fenc_tofree = fenc;
  } else
    fenc = buf->b_p_fenc;

  /*
   * Check if the file needs to be converted.
   */
  converted = need_conversion(fenc);

  /*
   * Check if UTF-8 to UCS-2/4 or Latin1 conversion needs to be done.  Or
   * Latin1 to Unicode conversion.  This is handled in buf_write_bytes().
   * Prepare the flags for it and allocate bw_conv_buf when needed.
   */
  if (converted && (enc_utf8 || STRCMP(p_enc, "latin1") == 0)) {
    wb_flags = get_fio_flags(fenc);
    if (wb_flags & (FIO_UCS2 | FIO_UCS4 | FIO_UTF16 | FIO_UTF8)) {
      /* Need to allocate a buffer to translate into. */
      if (wb_flags & (FIO_UCS2 | FIO_UTF16 | FIO_UTF8))
        write_info.bw_conv_buflen = bufsize * 2;
      else       /* FIO_UCS4 */
        write_info.bw_conv_buflen = bufsize * 4;
      write_info.bw_conv_buf
        = lalloc((long_u)write_info.bw_conv_buflen, TRUE);
      if (write_info.bw_conv_buf == NULL)
        end = 0;
    }
  }



  if (converted && wb_flags == 0) {
#  ifdef USE_ICONV
    /*
     * Use iconv() conversion when conversion is needed and it's not done
     * internally.
     */
    write_info.bw_iconv_fd = (iconv_t)my_iconv_open(fenc,
        enc_utf8 ? (char_u *)"utf-8" : p_enc);
    if (write_info.bw_iconv_fd != (iconv_t)-1) {
      /* We're going to use iconv(), allocate a buffer to convert in. */
      write_info.bw_conv_buflen = bufsize * ICONV_MULT;
      write_info.bw_conv_buf
        = lalloc((long_u)write_info.bw_conv_buflen, TRUE);
      if (write_info.bw_conv_buf == NULL)
        end = 0;
      write_info.bw_first = TRUE;
    } else
#  endif

    /*
     * When the file needs to be converted with 'charconvert' after
     * writing, write to a temp file instead and let the conversion
     * overwrite the original file.
     */
    if (*p_ccv != NUL) {
      wfname = vim_tempname('w');
      if (wfname == NULL) {             /* Can't write without a tempfile! */
        errmsg = (char_u *)_("E214: Can't find temp file for writing");
        goto restore_backup;
      }
    }
  }
  if (converted && wb_flags == 0
#  ifdef USE_ICONV
      && write_info.bw_iconv_fd == (iconv_t)-1
#  endif
      && wfname == fname
      ) {
    if (!forceit) {
      errmsg = (char_u *)_(
          "E213: Cannot convert (add ! to write without conversion)");
      goto restore_backup;
    }
    notconverted = TRUE;
  }

  /*
   * Open the file "wfname" for writing.
   * We may try to open the file twice: If we can't write to the
   * file and forceit is TRUE we delete the existing file and try to create
   * a new one. If this still fails we may have lost the original file!
   * (this may happen when the user reached his quotum for number of files).
   * Appending will fail if the file does not exist and forceit is FALSE.
   */
  while ((fd = mch_open((char *)wfname, O_WRONLY | O_EXTRA | (append
                                                              ? (forceit ? (
                                                                   O_APPEND |
                                                                   O_CREAT) :
                                                                 O_APPEND)
                                                              : (O_CREAT |
                                                                 O_TRUNC))
              , perm < 0 ? 0666 : (perm & 0777))) < 0) {
    /*
     * A forced write will try to create a new file if the old one is
     * still readonly. This may also happen when the directory is
     * read-only. In that case the mch_remove() will fail.
     */
    if (errmsg == NULL) {
#ifdef UNIX
      struct stat st;

      /* Don't delete the file when it's a hard or symbolic link. */
      if ((!newfile && st_old.st_nlink > 1)
          || (mch_lstat((char *)fname, &st) == 0
              && (st.st_dev != st_old.st_dev
                  || st.st_ino != st_old.st_ino)))
        errmsg = (char_u *)_("E166: Can't open linked file for writing");
      else
#endif
      {
        errmsg = (char_u *)_("E212: Can't open file for writing");
        if (forceit && vim_strchr(p_cpo, CPO_FWRITE) == NULL
            && perm >= 0) {
#ifdef UNIX
          /* we write to the file, thus it should be marked
             writable after all */
          if (!(perm & 0200))
            made_writable = TRUE;
          perm |= 0200;
          if (st_old.st_uid != getuid() || st_old.st_gid != getgid())
            perm &= 0777;
#endif
          if (!append)                      /* don't remove when appending */
            mch_remove(wfname);
          continue;
        }
      }
    }

restore_backup:
    {
      struct stat st;

      /*
       * If we failed to open the file, we don't need a backup. Throw it
       * away.  If we moved or removed the original file try to put the
       * backup in its place.
       */
      if (backup != NULL && wfname == fname) {
        if (backup_copy) {
          /*
           * There is a small chance that we removed the original,
           * try to move the copy in its place.
           * This may not work if the vim_rename() fails.
           * In that case we leave the copy around.
           */
          /* If file does not exist, put the copy in its place */
          if (mch_stat((char *)fname, &st) < 0)
            vim_rename(backup, fname);
          /* if original file does exist throw away the copy */
          if (mch_stat((char *)fname, &st) >= 0)
            mch_remove(backup);
        } else   {
          /* try to put the original file back */
          vim_rename(backup, fname);
        }
      }

      /* if original file no longer exists give an extra warning */
      if (!newfile && mch_stat((char *)fname, &st) < 0)
        end = 0;
    }

    if (wfname != fname)
      vim_free(wfname);
    goto fail;
  }
  errmsg = NULL;


  write_info.bw_fd = fd;

  if (*buf->b_p_key != NUL && !filtering) {
    char_u *header;
    int header_len;

    header = prepare_crypt_write(buf, &header_len);
    if (header == NULL)
      end = 0;
    else {
      /* Write magic number, so that Vim knows that this file is
       * encrypted when reading it again.  This also undergoes utf-8 to
       * ucs-2/4 conversion when needed. */
      write_info.bw_buf = header;
      write_info.bw_len = header_len;
      write_info.bw_flags = FIO_NOCONVERT;
      if (buf_write_bytes(&write_info) == FAIL)
        end = 0;
      wb_flags |= FIO_ENCRYPTED;
      vim_free(header);
    }
  }

  write_info.bw_buf = buffer;
  nchars = 0;

  /* use "++bin", "++nobin" or 'binary' */
  if (eap != NULL && eap->force_bin != 0)
    write_bin = (eap->force_bin == FORCE_BIN);
  else
    write_bin = buf->b_p_bin;

  /*
   * The BOM is written just after the encryption magic number.
   * Skip it when appending and the file already existed, the BOM only makes
   * sense at the start of the file.
   */
  if (buf->b_p_bomb && !write_bin && (!append || perm < 0)) {
    write_info.bw_len = make_bom(buffer, fenc);
    if (write_info.bw_len > 0) {
      /* don't convert, do encryption */
      write_info.bw_flags = FIO_NOCONVERT | wb_flags;
      if (buf_write_bytes(&write_info) == FAIL)
        end = 0;
      else
        nchars += write_info.bw_len;
    }
  }
  write_info.bw_start_lnum = start;

  write_undo_file = (buf->b_p_udf && overwriting && !append
                     && !filtering && reset_changed);
  if (write_undo_file)
    /* Prepare for computing the hash value of the text. */
    sha256_start(&sha_ctx);

  write_info.bw_len = bufsize;
#ifdef HAS_BW_FLAGS
  write_info.bw_flags = wb_flags;
#endif
  fileformat = get_fileformat_force(buf, eap);
  s = buffer;
  len = 0;
  for (lnum = start; lnum <= end; ++lnum) {
    /*
     * The next while loop is done once for each character written.
     * Keep it fast!
     */
    ptr = ml_get_buf(buf, lnum, FALSE) - 1;
    if (write_undo_file)
      sha256_update(&sha_ctx, ptr + 1, (UINT32_T)(STRLEN(ptr + 1) + 1));
    while ((c = *++ptr) != NUL) {
      if (c == NL)
        *s = NUL;                       /* replace newlines with NULs */
      else if (c == CAR && fileformat == EOL_MAC)
        *s = NL;                        /* Mac: replace CRs with NLs */
      else
        *s = c;
      ++s;
      if (++len != bufsize)
        continue;
      if (buf_write_bytes(&write_info) == FAIL) {
        end = 0;                        /* write error: break loop */
        break;
      }
      nchars += bufsize;
      s = buffer;
      len = 0;
      write_info.bw_start_lnum = lnum;
    }
    /* write failed or last line has no EOL: stop here */
    if (end == 0
        || (lnum == end
            && write_bin
            && (lnum == buf->b_no_eol_lnum
                || (lnum == buf->b_ml.ml_line_count && !buf->b_p_eol)))) {
      ++lnum;                           /* written the line, count it */
      no_eol = TRUE;
      break;
    }
    if (fileformat == EOL_UNIX)
      *s++ = NL;
    else {
      *s++ = CAR;                       /* EOL_MAC or EOL_DOS: write CR */
      if (fileformat == EOL_DOS) {      /* write CR-NL */
        if (++len == bufsize) {
          if (buf_write_bytes(&write_info) == FAIL) {
            end = 0;                    /* write error: break loop */
            break;
          }
          nchars += bufsize;
          s = buffer;
          len = 0;
        }
        *s++ = NL;
      }
    }
    if (++len == bufsize && end) {
      if (buf_write_bytes(&write_info) == FAIL) {
        end = 0;                        /* write error: break loop */
        break;
      }
      nchars += bufsize;
      s = buffer;
      len = 0;

      ui_breakcheck();
      if (got_int) {
        end = 0;                        /* Interrupted, break loop */
        break;
      }
    }
  }
  if (len > 0 && end > 0) {
    write_info.bw_len = len;
    if (buf_write_bytes(&write_info) == FAIL)
      end = 0;                      /* write error */
    nchars += len;
  }

#if defined(UNIX) && defined(HAVE_FSYNC)
  /* On many journalling file systems there is a bug that causes both the
   * original and the backup file to be lost when halting the system right
   * after writing the file.  That's because only the meta-data is
   * journalled.  Syncing the file slows down the system, but assures it has
   * been written to disk and we don't lose it.
   * For a device do try the fsync() but don't complain if it does not work
   * (could be a pipe).
   * If the 'fsync' option is FALSE, don't fsync().  Useful for laptops. */
  if (p_fs && fsync(fd) != 0 && !device) {
    errmsg = (char_u *)_("E667: Fsync failed");
    end = 0;
  }
#endif

#ifdef HAVE_SELINUX
  /* Probably need to set the security context. */
  if (!backup_copy)
    mch_copy_sec(backup, wfname);
#endif

#ifdef UNIX
  /* When creating a new file, set its owner/group to that of the original
   * file.  Get the new device and inode number. */
  if (backup != NULL && !backup_copy) {
# ifdef HAVE_FCHOWN
    struct stat st;

    /* don't change the owner when it's already OK, some systems remove
     * permission or ACL stuff */
    if (mch_stat((char *)wfname, &st) < 0
        || st.st_uid != st_old.st_uid
        || st.st_gid != st_old.st_gid) {
      ignored = fchown(fd, st_old.st_uid, st_old.st_gid);
      if (perm >= 0)            /* set permission again, may have changed */
        (void)mch_setperm(wfname, perm);
    }
# endif
    buf_setino(buf);
  } else if (!buf->b_dev_valid)
    /* Set the inode when creating a new file. */
    buf_setino(buf);
#endif

  if (close(fd) != 0) {
    errmsg = (char_u *)_("E512: Close failed");
    end = 0;
  }

#ifdef UNIX
  if (made_writable)
    perm &= ~0200;              /* reset 'w' bit for security reasons */
#endif
  if (perm >= 0)                /* set perm. of new file same as old file */
    (void)mch_setperm(wfname, perm);
#ifdef HAVE_ACL
  /* Probably need to set the ACL before changing the user (can't set the
   * ACL on a file the user doesn't own). */
  if (!backup_copy)
    mch_set_acl(wfname, acl);
#endif
  crypt_method_used = use_crypt_method;
  if (wb_flags & FIO_ENCRYPTED)
    crypt_pop_state();


  if (wfname != fname) {
    /*
     * The file was written to a temp file, now it needs to be converted
     * with 'charconvert' to (overwrite) the output file.
     */
    if (end != 0) {
      if (eval_charconvert(enc_utf8 ? (char_u *)"utf-8" : p_enc, fenc,
              wfname, fname) == FAIL) {
        write_info.bw_conv_error = TRUE;
        end = 0;
      }
    }
    mch_remove(wfname);
    vim_free(wfname);
  }

  if (end == 0) {
    if (errmsg == NULL) {
      if (write_info.bw_conv_error) {
        if (write_info.bw_conv_error_lnum == 0)
          errmsg = (char_u *)_(
              "E513: write error, conversion failed (make 'fenc' empty to override)");
        else {
          errmsg_allocated = TRUE;
          errmsg = alloc(300);
          vim_snprintf((char *)errmsg, 300,
              _(
                  "E513: write error, conversion failed in line %ld (make 'fenc' empty to override)"),
              (long)write_info.bw_conv_error_lnum);
        }
      } else if (got_int)
        errmsg = (char_u *)_(e_interr);
      else
        errmsg = (char_u *)_("E514: write error (file system full?)");
    }

    /*
     * If we have a backup file, try to put it in place of the new file,
     * because the new file is probably corrupt.  This avoids losing the
     * original file when trying to make a backup when writing the file a
     * second time.
     * When "backup_copy" is set we need to copy the backup over the new
     * file.  Otherwise rename the backup file.
     * If this is OK, don't give the extra warning message.
     */
    if (backup != NULL) {
      if (backup_copy) {
        /* This may take a while, if we were interrupted let the user
         * know we got the message. */
        if (got_int) {
          MSG(_(e_interr));
          out_flush();
        }
        if ((fd = mch_open((char *)backup, O_RDONLY | O_EXTRA, 0)) >= 0) {
          if ((write_info.bw_fd = mch_open((char *)fname,
                   O_WRONLY | O_CREAT | O_TRUNC | O_EXTRA,
                   perm & 0777)) >= 0) {
            /* copy the file. */
            write_info.bw_buf = smallbuf;
#ifdef HAS_BW_FLAGS
            write_info.bw_flags = FIO_NOCONVERT;
#endif
            while ((write_info.bw_len = read_eintr(fd, smallbuf,
                        SMBUFSIZE)) > 0)
              if (buf_write_bytes(&write_info) == FAIL)
                break;

            if (close(write_info.bw_fd) >= 0
                && write_info.bw_len == 0)
              end = 1;                          /* success */
          }
          close(fd);            /* ignore errors for closing read file */
        }
      } else   {
        if (vim_rename(backup, fname) == 0)
          end = 1;
      }
    }
    goto fail;
  }

  lnum -= start;            /* compute number of written lines */
  --no_wait_return;         /* may wait for return now */

#if !(defined(UNIX) || defined(VMS))
  fname = sfname;           /* use shortname now, for the messages */
#endif
  if (!filtering) {
    msg_add_fname(buf, fname);          /* put fname in IObuff with quotes */
    c = FALSE;
    if (write_info.bw_conv_error) {
      STRCAT(IObuff, _(" CONVERSION ERROR"));
      c = TRUE;
      if (write_info.bw_conv_error_lnum != 0)
        vim_snprintf_add((char *)IObuff, IOSIZE, _(" in line %ld;"),
            (long)write_info.bw_conv_error_lnum);
    } else if (notconverted)   {
      STRCAT(IObuff, _("[NOT converted]"));
      c = TRUE;
    } else if (converted)   {
      STRCAT(IObuff, _("[converted]"));
      c = TRUE;
    }
    if (device) {
      STRCAT(IObuff, _("[Device]"));
      c = TRUE;
    } else if (newfile)   {
      STRCAT(IObuff, shortmess(SHM_NEW) ? _("[New]") : _("[New File]"));
      c = TRUE;
    }
    if (no_eol) {
      msg_add_eol();
      c = TRUE;
    }
    /* may add [unix/dos/mac] */
    if (msg_add_fileformat(fileformat))
      c = TRUE;
    if (wb_flags & FIO_ENCRYPTED) {
      if (crypt_method_used == 1)
        STRCAT(IObuff, _("[blowfish]"));
      else
        STRCAT(IObuff, _("[crypted]"));
      c = TRUE;
    }
    msg_add_lines(c, (long)lnum, nchars);       /* add line/char count */
    if (!shortmess(SHM_WRITE)) {
      if (append)
        STRCAT(IObuff, shortmess(SHM_WRI) ? _(" [a]") : _(" appended"));
      else
        STRCAT(IObuff, shortmess(SHM_WRI) ? _(" [w]") : _(" written"));
    }

    set_keep_msg(msg_trunc_attr(IObuff, FALSE, 0), 0);
  }

  /* When written everything correctly: reset 'modified'.  Unless not
   * writing to the original file and '+' is not in 'cpoptions'. */
  if (reset_changed && whole && !append
      && !write_info.bw_conv_error
      && (overwriting || vim_strchr(p_cpo, CPO_PLUS) != NULL)
      ) {
    unchanged(buf, TRUE);
    u_unchanged(buf);
    u_update_save_nr(buf);
  }

  /*
   * If written to the current file, update the timestamp of the swap file
   * and reset the BF_WRITE_MASK flags. Also sets buf->b_mtime.
   */
  if (overwriting) {
    ml_timestamp(buf);
    if (append)
      buf->b_flags &= ~BF_NEW;
    else
      buf->b_flags &= ~BF_WRITE_MASK;
  }

  /*
   * If we kept a backup until now, and we are in patch mode, then we make
   * the backup file our 'original' file.
   */
  if (*p_pm && dobackup) {
    char *org = (char *)buf_modname(
#ifdef SHORT_FNAME
        TRUE,
#else
        (buf->b_p_sn || buf->b_shortname),
#endif
        fname, p_pm, FALSE);

    if (backup != NULL) {
      struct stat st;

      /*
       * If the original file does not exist yet
       * the current backup file becomes the original file
       */
      if (org == NULL)
        EMSG(_("E205: Patchmode: can't save original file"));
      else if (mch_stat(org, &st) < 0) {
        vim_rename(backup, (char_u *)org);
        vim_free(backup);                   /* don't delete the file */
        backup = NULL;
#ifdef UNIX
        set_file_time((char_u *)org, st_old.st_atime, st_old.st_mtime);
#endif
      }
    }
    /*
     * If there is no backup file, remember that a (new) file was
     * created.
     */
    else {
      int empty_fd;

      if (org == NULL
          || (empty_fd = mch_open(org,
                  O_CREAT | O_EXTRA | O_EXCL | O_NOFOLLOW,
                  perm < 0 ? 0666 : (perm & 0777))) < 0)
        EMSG(_("E206: patchmode: can't touch empty original file"));
      else
        close(empty_fd);
    }
    if (org != NULL) {
      mch_setperm((char_u *)org, mch_getperm(fname) & 0777);
      vim_free(org);
    }
  }

  /*
   * Remove the backup unless 'backup' option is set
   */
  if (!p_bk && backup != NULL && mch_remove(backup) != 0)
    EMSG(_("E207: Can't delete backup file"));


  goto nofail;

  /*
   * Finish up.  We get here either after failure or success.
   */
fail:
  --no_wait_return;             /* may wait for return now */
nofail:

  /* Done saving, we accept changed buffer warnings again */
  buf->b_saving = FALSE;

  vim_free(backup);
  if (buffer != smallbuf)
    vim_free(buffer);
  vim_free(fenc_tofree);
  vim_free(write_info.bw_conv_buf);
# ifdef USE_ICONV
  if (write_info.bw_iconv_fd != (iconv_t)-1) {
    iconv_close(write_info.bw_iconv_fd);
    write_info.bw_iconv_fd = (iconv_t)-1;
  }
# endif
#ifdef HAVE_ACL
  mch_free_acl(acl);
#endif

  if (errmsg != NULL) {
    int numlen = errnum != NULL ? (int)STRLEN(errnum) : 0;

    attr = hl_attr(HLF_E);      /* set highlight for error messages */
    msg_add_fname(buf,
#ifndef UNIX
        sfname
#else
        fname
#endif
        );                      /* put file name in IObuff with quotes */
    if (STRLEN(IObuff) + STRLEN(errmsg) + numlen >= IOSIZE)
      IObuff[IOSIZE - STRLEN(errmsg) - numlen - 1] = NUL;
    /* If the error message has the form "is ...", put the error number in
     * front of the file name. */
    if (errnum != NULL) {
      STRMOVE(IObuff + numlen, IObuff);
      mch_memmove(IObuff, errnum, (size_t)numlen);
    }
    STRCAT(IObuff, errmsg);
    emsg(IObuff);
    if (errmsg_allocated)
      vim_free(errmsg);

    retval = FAIL;
    if (end == 0) {
      MSG_PUTS_ATTR(_("\nWARNING: Original file may be lost or damaged\n"),
          attr | MSG_HIST);
      MSG_PUTS_ATTR(_(
              "don't quit the editor until the file is successfully written!"),
          attr | MSG_HIST);

      /* Update the timestamp to avoid an "overwrite changed file"
       * prompt when writing again. */
      if (mch_stat((char *)fname, &st_old) >= 0) {
        buf_store_time(buf, &st_old, fname);
        buf->b_mtime_read = buf->b_mtime;
      }
    }
  }
  msg_scroll = msg_save;

  /*
   * When writing the whole file and 'undofile' is set, also write the undo
   * file.
   */
  if (retval == OK && write_undo_file) {
    char_u hash[UNDO_HASH_SIZE];

    sha256_finish(&sha_ctx, hash);
    u_write_undo(NULL, FALSE, buf, hash);
  }

  if (!should_abort(retval)) {
    aco_save_T aco;

    curbuf->b_no_eol_lnum = 0;      /* in case it was set by the previous read */

    /*
     * Apply POST autocommands.
     * Careful: The autocommands may call buf_write() recursively!
     */
    aucmd_prepbuf(&aco, buf);

    if (append)
      apply_autocmds_exarg(EVENT_FILEAPPENDPOST, fname, fname,
          FALSE, curbuf, eap);
    else if (filtering)
      apply_autocmds_exarg(EVENT_FILTERWRITEPOST, NULL, fname,
          FALSE, curbuf, eap);
    else if (reset_changed && whole)
      apply_autocmds_exarg(EVENT_BUFWRITEPOST, fname, fname,
          FALSE, curbuf, eap);
    else
      apply_autocmds_exarg(EVENT_FILEWRITEPOST, fname, fname,
          FALSE, curbuf, eap);

    /* restore curwin/curbuf and a few other things */
    aucmd_restbuf(&aco);

    if (aborting())         /* autocmds may abort script processing */
      retval = FALSE;
  }

  got_int |= prev_got_int;

  return retval;
}

/*
 * Set the name of the current buffer.  Use when the buffer doesn't have a
 * name and a ":r" or ":w" command with a file name is used.
 */
static int set_rw_fname(char_u *fname, char_u *sfname)
{
  buf_T       *buf = curbuf;

  /* It's like the unnamed buffer is deleted.... */
  if (curbuf->b_p_bl)
    apply_autocmds(EVENT_BUFDELETE, NULL, NULL, FALSE, curbuf);
  apply_autocmds(EVENT_BUFWIPEOUT, NULL, NULL, FALSE, curbuf);
  if (aborting())           /* autocmds may abort script processing */
    return FAIL;
  if (curbuf != buf) {
    /* We are in another buffer now, don't do the renaming. */
    EMSG(_(e_auchangedbuf));
    return FAIL;
  }

  if (setfname(curbuf, fname, sfname, FALSE) == OK)
    curbuf->b_flags |= BF_NOTEDITED;

  /* ....and a new named one is created */
  apply_autocmds(EVENT_BUFNEW, NULL, NULL, FALSE, curbuf);
  if (curbuf->b_p_bl)
    apply_autocmds(EVENT_BUFADD, NULL, NULL, FALSE, curbuf);
  if (aborting())           /* autocmds may abort script processing */
    return FAIL;

  /* Do filetype detection now if 'filetype' is empty. */
  if (*curbuf->b_p_ft == NUL) {
    if (au_has_group((char_u *)"filetypedetect"))
      (void)do_doautocmd((char_u *)"filetypedetect BufRead", FALSE);
    do_modelines(0);
  }

  return OK;
}

/*
 * Put file name into IObuff with quotes.
 */
void msg_add_fname(buf_T *buf, char_u *fname)
{
  if (fname == NULL)
    fname = (char_u *)"-stdin-";
  home_replace(buf, fname, IObuff + 1, IOSIZE - 4, TRUE);
  IObuff[0] = '"';
  STRCAT(IObuff, "\" ");
}

/*
 * Append message for text mode to IObuff.
 * Return TRUE if something appended.
 */
static int msg_add_fileformat(int eol_type)
{
#ifndef USE_CRNL
  if (eol_type == EOL_DOS) {
    STRCAT(IObuff, shortmess(SHM_TEXT) ? _("[dos]") : _("[dos format]"));
    return TRUE;
  }
#endif
#ifndef USE_CR
  if (eol_type == EOL_MAC) {
    STRCAT(IObuff, shortmess(SHM_TEXT) ? _("[mac]") : _("[mac format]"));
    return TRUE;
  }
#endif
#if defined(USE_CRNL) || defined(USE_CR)
  if (eol_type == EOL_UNIX) {
    STRCAT(IObuff, shortmess(SHM_TEXT) ? _("[unix]") : _("[unix format]"));
    return TRUE;
  }
#endif
  return FALSE;
}

/*
 * Append line and character count to IObuff.
 */
void msg_add_lines(int insert_space, long lnum, off_t nchars)
{
  char_u  *p;

  p = IObuff + STRLEN(IObuff);

  if (insert_space)
    *p++ = ' ';
  if (shortmess(SHM_LINES)) {
#ifdef LONG_LONG_OFF_T
     sprintf((char *)p, "%ldL, %lldC", lnum, nchars);
#else
     /* Explicit typecast avoids warning on Mac OS X 10.6 */
     sprintf((char *)p, "%ldL, %ldC", lnum, (long)nchars);
#endif
  }
  else {
    if (lnum == 1)
      STRCPY(p, _("1 line, "));
    else
      sprintf((char *)p, _("%ld lines, "), lnum);
    p += STRLEN(p);
    if (nchars == 1)
      STRCPY(p, _("1 character"));
    else {
#ifdef LONG_LONG_OFF_T
      sprintf((char *)p, _("%lld characters"), nchars);
#else
      sprintf((char *)p, _("%ld characters"), (long)nchars);
#endif
    }
  }
}

/*
 * Append message for missing line separator to IObuff.
 */
static void msg_add_eol(void)                 {
  STRCAT(IObuff,
      shortmess(SHM_LAST) ? _("[noeol]") : _("[Incomplete last line]"));
}

/*
 * Check modification time of file, before writing to it.
 * The size isn't checked, because using a tool like "gzip" takes care of
 * using the same timestamp but can't set the size.
 */
static int check_mtime(buf_T *buf, struct stat *st)
{
  if (buf->b_mtime_read != 0
      && time_differs((long)st->st_mtime, buf->b_mtime_read)) {
    msg_scroll = TRUE;              /* don't overwrite messages here */
    msg_silent = 0;                 /* must give this prompt */
    /* don't use emsg() here, don't want to flush the buffers */
    MSG_ATTR(_("WARNING: The file has been changed since reading it!!!"),
        hl_attr(HLF_E));
    if (ask_yesno((char_u *)_("Do you really want to write to it"),
            TRUE) == 'n')
      return FAIL;
    msg_scroll = FALSE;             /* always overwrite the file message now */
  }
  return OK;
}

static int time_differs(long t1, long t2)
{
#if defined(__linux__) || defined(MSDOS) || defined(MSWIN)
  /* On a FAT filesystem, esp. under Linux, there are only 5 bits to store
   * the seconds.  Since the roundoff is done when flushing the inode, the
   * time may change unexpectedly by one second!!! */
  return t1 - t2 > 1 || t2 - t1 > 1;
#else
  return t1 != t2;
#endif
}

/*
 * Call write() to write a number of bytes to the file.
 * Handles encryption and 'encoding' conversion.
 *
 * Return FAIL for failure, OK otherwise.
 */
static int buf_write_bytes(struct bw_info *ip)
{
  int wlen;
  char_u      *buf = ip->bw_buf;        /* data to write */
  int len = ip->bw_len;                 /* length of data */
#ifdef HAS_BW_FLAGS
  int flags = ip->bw_flags;             /* extra flags */
#endif

  /*
   * Skip conversion when writing the crypt magic number or the BOM.
   */
  if (!(flags & FIO_NOCONVERT)) {
    char_u          *p;
    unsigned c;
    int n;

    if (flags & FIO_UTF8) {
      /*
       * Convert latin1 in the buffer to UTF-8 in the file.
       */
      p = ip->bw_conv_buf;              /* translate to buffer */
      for (wlen = 0; wlen < len; ++wlen)
        p += utf_char2bytes(buf[wlen], p);
      buf = ip->bw_conv_buf;
      len = (int)(p - ip->bw_conv_buf);
    } else if (flags & (FIO_UCS4 | FIO_UTF16 | FIO_UCS2 | FIO_LATIN1))   {
      /*
       * Convert UTF-8 bytes in the buffer to UCS-2, UCS-4, UTF-16 or
       * Latin1 chars in the file.
       */
      if (flags & FIO_LATIN1)
        p = buf;                /* translate in-place (can only get shorter) */
      else
        p = ip->bw_conv_buf;            /* translate to buffer */
      for (wlen = 0; wlen < len; wlen += n) {
        if (wlen == 0 && ip->bw_restlen != 0) {
          int l;

          /* Use remainder of previous call.  Append the start of
           * buf[] to get a full sequence.  Might still be too
           * short! */
          l = CONV_RESTLEN - ip->bw_restlen;
          if (l > len)
            l = len;
          mch_memmove(ip->bw_rest + ip->bw_restlen, buf, (size_t)l);
          n = utf_ptr2len_len(ip->bw_rest, ip->bw_restlen + l);
          if (n > ip->bw_restlen + len) {
            /* We have an incomplete byte sequence at the end to
             * be written.  We can't convert it without the
             * remaining bytes.  Keep them for the next call. */
            if (ip->bw_restlen + len > CONV_RESTLEN)
              return FAIL;
            ip->bw_restlen += len;
            break;
          }
          if (n > 1)
            c = utf_ptr2char(ip->bw_rest);
          else
            c = ip->bw_rest[0];
          if (n >= ip->bw_restlen) {
            n -= ip->bw_restlen;
            ip->bw_restlen = 0;
          } else   {
            ip->bw_restlen -= n;
            mch_memmove(ip->bw_rest, ip->bw_rest + n,
                (size_t)ip->bw_restlen);
            n = 0;
          }
        } else   {
          n = utf_ptr2len_len(buf + wlen, len - wlen);
          if (n > len - wlen) {
            /* We have an incomplete byte sequence at the end to
             * be written.  We can't convert it without the
             * remaining bytes.  Keep them for the next call. */
            if (len - wlen > CONV_RESTLEN)
              return FAIL;
            ip->bw_restlen = len - wlen;
            mch_memmove(ip->bw_rest, buf + wlen,
                (size_t)ip->bw_restlen);
            break;
          }
          if (n > 1)
            c = utf_ptr2char(buf + wlen);
          else
            c = buf[wlen];
        }

        if (ucs2bytes(c, &p, flags) && !ip->bw_conv_error) {
          ip->bw_conv_error = TRUE;
          ip->bw_conv_error_lnum = ip->bw_start_lnum;
        }
        if (c == NL)
          ++ip->bw_start_lnum;
      }
      if (flags & FIO_LATIN1)
        len = (int)(p - buf);
      else {
        buf = ip->bw_conv_buf;
        len = (int)(p - ip->bw_conv_buf);
      }
    }


# ifdef MACOS_CONVERT
    else if (flags & FIO_MACROMAN) {
      /*
       * Convert UTF-8 or latin1 to Apple MacRoman.
       */
      char_u      *from;
      size_t fromlen;

      if (ip->bw_restlen > 0) {
        /* Need to concatenate the remainder of the previous call and
         * the bytes of the current call.  Use the end of the
         * conversion buffer for this. */
        fromlen = len + ip->bw_restlen;
        from = ip->bw_conv_buf + ip->bw_conv_buflen - fromlen;
        mch_memmove(from, ip->bw_rest, (size_t)ip->bw_restlen);
        mch_memmove(from + ip->bw_restlen, buf, (size_t)len);
      } else   {
        from = buf;
        fromlen = len;
      }

      if (enc2macroman(from, fromlen,
              ip->bw_conv_buf, &len, ip->bw_conv_buflen,
              ip->bw_rest, &ip->bw_restlen) == FAIL) {
        ip->bw_conv_error = TRUE;
        return FAIL;
      }
      buf = ip->bw_conv_buf;
    }
# endif

# ifdef USE_ICONV
    if (ip->bw_iconv_fd != (iconv_t)-1) {
      const char  *from;
      size_t fromlen;
      char        *to;
      size_t tolen;

      /* Convert with iconv(). */
      if (ip->bw_restlen > 0) {
        char *fp;

        /* Need to concatenate the remainder of the previous call and
         * the bytes of the current call.  Use the end of the
         * conversion buffer for this. */
        fromlen = len + ip->bw_restlen;
        fp = (char *)ip->bw_conv_buf + ip->bw_conv_buflen - fromlen;
        mch_memmove(fp, ip->bw_rest, (size_t)ip->bw_restlen);
        mch_memmove(fp + ip->bw_restlen, buf, (size_t)len);
        from = fp;
        tolen = ip->bw_conv_buflen - fromlen;
      } else   {
        from = (const char *)buf;
        fromlen = len;
        tolen = ip->bw_conv_buflen;
      }
      to = (char *)ip->bw_conv_buf;

      if (ip->bw_first) {
        size_t save_len = tolen;

        /* output the initial shift state sequence */
        (void)iconv(ip->bw_iconv_fd, NULL, NULL, &to, &tolen);

        /* There is a bug in iconv() on Linux (which appears to be
         * wide-spread) which sets "to" to NULL and messes up "tolen".
         */
        if (to == NULL) {
          to = (char *)ip->bw_conv_buf;
          tolen = save_len;
        }
        ip->bw_first = FALSE;
      }

      /*
       * If iconv() has an error or there is not enough room, fail.
       */
      if ((iconv(ip->bw_iconv_fd, (void *)&from, &fromlen, &to, &tolen)
           == (size_t)-1 && ICONV_ERRNO != ICONV_EINVAL)
          || fromlen > CONV_RESTLEN) {
        ip->bw_conv_error = TRUE;
        return FAIL;
      }

      /* copy remainder to ip->bw_rest[] to be used for the next call. */
      if (fromlen > 0)
        mch_memmove(ip->bw_rest, (void *)from, fromlen);
      ip->bw_restlen = (int)fromlen;

      buf = ip->bw_conv_buf;
      len = (int)((char_u *)to - ip->bw_conv_buf);
    }
# endif
  }

  if (flags & FIO_ENCRYPTED)            /* encrypt the data */
    crypt_encode(buf, len, buf);

  wlen = write_eintr(ip->bw_fd, buf, len);
  return (wlen < len) ? FAIL : OK;
}

/*
 * Convert a Unicode character to bytes.
 * Return TRUE for an error, FALSE when it's OK.
 */
static int 
ucs2bytes (
    unsigned c,                     /* in: character */
    char_u **pp,               /* in/out: pointer to result */
    int flags                      /* FIO_ flags */
)
{
  char_u      *p = *pp;
  int error = FALSE;
  int cc;


  if (flags & FIO_UCS4) {
    if (flags & FIO_ENDIAN_L) {
      *p++ = c;
      *p++ = (c >> 8);
      *p++ = (c >> 16);
      *p++ = (c >> 24);
    } else   {
      *p++ = (c >> 24);
      *p++ = (c >> 16);
      *p++ = (c >> 8);
      *p++ = c;
    }
  } else if (flags & (FIO_UCS2 | FIO_UTF16))   {
    if (c >= 0x10000) {
      if (flags & FIO_UTF16) {
        /* Make two words, ten bits of the character in each.  First
         * word is 0xd800 - 0xdbff, second one 0xdc00 - 0xdfff */
        c -= 0x10000;
        if (c >= 0x100000)
          error = TRUE;
        cc = ((c >> 10) & 0x3ff) + 0xd800;
        if (flags & FIO_ENDIAN_L) {
          *p++ = cc;
          *p++ = ((unsigned)cc >> 8);
        } else   {
          *p++ = ((unsigned)cc >> 8);
          *p++ = cc;
        }
        c = (c & 0x3ff) + 0xdc00;
      } else
        error = TRUE;
    }
    if (flags & FIO_ENDIAN_L) {
      *p++ = c;
      *p++ = (c >> 8);
    } else   {
      *p++ = (c >> 8);
      *p++ = c;
    }
  } else   { /* Latin1 */
    if (c >= 0x100) {
      error = TRUE;
      *p++ = 0xBF;
    } else
      *p++ = c;
  }

  *pp = p;
  return error;
}

/*
 * Return TRUE if file encoding "fenc" requires conversion from or to
 * 'encoding'.
 */
static int need_conversion(char_u *fenc)
{
  int same_encoding;
  int enc_flags;
  int fenc_flags;

  if (*fenc == NUL || STRCMP(p_enc, fenc) == 0) {
    same_encoding = TRUE;
    fenc_flags = 0;
  } else   {
    /* Ignore difference between "ansi" and "latin1", "ucs-4" and
     * "ucs-4be", etc. */
    enc_flags = get_fio_flags(p_enc);
    fenc_flags = get_fio_flags(fenc);
    same_encoding = (enc_flags != 0 && fenc_flags == enc_flags);
  }
  if (same_encoding) {
    /* Specified encoding matches with 'encoding'.  This requires
     * conversion when 'encoding' is Unicode but not UTF-8. */
    return enc_unicode != 0;
  }

  /* Encodings differ.  However, conversion is not needed when 'enc' is any
   * Unicode encoding and the file is UTF-8. */
  return !(enc_utf8 && fenc_flags == FIO_UTF8);
}

/*
 * Check "ptr" for a unicode encoding and return the FIO_ flags needed for the
 * internal conversion.
 * if "ptr" is an empty string, use 'encoding'.
 */
static int get_fio_flags(char_u *ptr)
{
  int prop;

  if (*ptr == NUL)
    ptr = p_enc;

  prop = enc_canon_props(ptr);
  if (prop & ENC_UNICODE) {
    if (prop & ENC_2BYTE) {
      if (prop & ENC_ENDIAN_L)
        return FIO_UCS2 | FIO_ENDIAN_L;
      return FIO_UCS2;
    }
    if (prop & ENC_4BYTE) {
      if (prop & ENC_ENDIAN_L)
        return FIO_UCS4 | FIO_ENDIAN_L;
      return FIO_UCS4;
    }
    if (prop & ENC_2WORD) {
      if (prop & ENC_ENDIAN_L)
        return FIO_UTF16 | FIO_ENDIAN_L;
      return FIO_UTF16;
    }
    return FIO_UTF8;
  }
  if (prop & ENC_LATIN1)
    return FIO_LATIN1;
  /* must be ENC_DBCS, requires iconv() */
  return 0;
}



/*
 * Check for a Unicode BOM (Byte Order Mark) at the start of p[size].
 * "size" must be at least 2.
 * Return the name of the encoding and set "*lenp" to the length.
 * Returns NULL when no BOM found.
 */
static char_u *check_for_bom(char_u *p, long size, int *lenp, int flags)
{
  char        *name = NULL;
  int len = 2;

  if (p[0] == 0xef && p[1] == 0xbb && size >= 3 && p[2] == 0xbf
      && (flags == FIO_ALL || flags == FIO_UTF8 || flags == 0)) {
    name = "utf-8";             /* EF BB BF */
    len = 3;
  } else if (p[0] == 0xff && p[1] == 0xfe)   {
    if (size >= 4 && p[2] == 0 && p[3] == 0
        && (flags == FIO_ALL || flags == (FIO_UCS4 | FIO_ENDIAN_L))) {
      name = "ucs-4le";         /* FF FE 00 00 */
      len = 4;
    } else if (flags == (FIO_UCS2 | FIO_ENDIAN_L))
      name = "ucs-2le";         /* FF FE */
    else if (flags == FIO_ALL || flags == (FIO_UTF16 | FIO_ENDIAN_L))
      /* utf-16le is preferred, it also works for ucs-2le text */
      name = "utf-16le";        /* FF FE */
  } else if (p[0] == 0xfe && p[1] == 0xff
             && (flags == FIO_ALL || flags == FIO_UCS2 || flags ==
                 FIO_UTF16)) {
    /* Default to utf-16, it works also for ucs-2 text. */
    if (flags == FIO_UCS2)
      name = "ucs-2";           /* FE FF */
    else
      name = "utf-16";          /* FE FF */
  } else if (size >= 4 && p[0] == 0 && p[1] == 0 && p[2] == 0xfe
             && p[3] == 0xff && (flags == FIO_ALL || flags == FIO_UCS4)) {
    name = "ucs-4";             /* 00 00 FE FF */
    len = 4;
  }

  *lenp = len;
  return (char_u *)name;
}

/*
 * Generate a BOM in "buf[4]" for encoding "name".
 * Return the length of the BOM (zero when no BOM).
 */
static int make_bom(char_u *buf, char_u *name)
{
  int flags;
  char_u      *p;

  flags = get_fio_flags(name);

  /* Can't put a BOM in a non-Unicode file. */
  if (flags == FIO_LATIN1 || flags == 0)
    return 0;

  if (flags == FIO_UTF8) {      /* UTF-8 */
    buf[0] = 0xef;
    buf[1] = 0xbb;
    buf[2] = 0xbf;
    return 3;
  }
  p = buf;
  (void)ucs2bytes(0xfeff, &p, flags);
  return (int)(p - buf);
}

#if defined(FEAT_VIMINFO) || defined(FEAT_BROWSE) || \
  defined(FEAT_QUICKFIX) || defined(FEAT_AUTOCMD) || defined(PROTO)
/*
 * Try to find a shortname by comparing the fullname with the current
 * directory.
 * Returns "full_path" or pointer into "full_path" if shortened.
 */
char_u *shorten_fname1(char_u *full_path)
{
  char_u      *dirname;
  char_u      *p = full_path;

  dirname = alloc(MAXPATHL);
  if (dirname == NULL)
    return full_path;
  if (mch_dirname(dirname, MAXPATHL) == OK) {
    p = shorten_fname(full_path, dirname);
    if (p == NULL || *p == NUL)
      p = full_path;
  }
  vim_free(dirname);
  return p;
}
#endif

/*
 * Try to find a shortname by comparing the fullname with the current
 * directory.
 * Returns NULL if not shorter name possible, pointer into "full_path"
 * otherwise.
 */
char_u *shorten_fname(char_u *full_path, char_u *dir_name)
{
  int len;
  char_u      *p;

  if (full_path == NULL)
    return NULL;
  len = (int)STRLEN(dir_name);
  if (fnamencmp(dir_name, full_path, len) == 0) {
    p = full_path + len;
    {
      if (vim_ispathsep(*p))
        ++p;
      else
        p = NULL;
    }
  } else
    p = NULL;
  return p;
}

/*
 * Shorten filenames for all buffers.
 * When "force" is TRUE: Use full path from now on for files currently being
 * edited, both for file name and swap file name.  Try to shorten the file
 * names a bit, if safe to do so.
 * When "force" is FALSE: Only try to shorten absolute file names.
 * For buffers that have buftype "nofile" or "scratch": never change the file
 * name.
 */
void shorten_fnames(int force)
{
  char_u dirname[MAXPATHL];
  buf_T       *buf;
  char_u      *p;

  mch_dirname(dirname, MAXPATHL);
  for (buf = firstbuf; buf != NULL; buf = buf->b_next) {
    if (buf->b_fname != NULL
        && !bt_nofile(buf)
        && !path_with_url(buf->b_fname)
        && (force
            || buf->b_sfname == NULL
            || mch_is_full_name(buf->b_sfname))) {
      vim_free(buf->b_sfname);
      buf->b_sfname = NULL;
      p = shorten_fname(buf->b_ffname, dirname);
      if (p != NULL) {
        buf->b_sfname = vim_strsave(p);
        buf->b_fname = buf->b_sfname;
      }
      if (p == NULL || buf->b_fname == NULL)
        buf->b_fname = buf->b_ffname;
    }

    /* Always make the swap file name a full path, a "nofile" buffer may
     * also have a swap file. */
    mf_fullname(buf->b_ml.ml_mfp);
  }
  status_redraw_all();
  redraw_tabline = TRUE;
}

#if (defined(FEAT_DND) && defined(FEAT_GUI_GTK)) \
  || defined(FEAT_GUI_MSWIN) \
  || defined(FEAT_GUI_MAC) \
  || defined(PROTO)
/*
 * Shorten all filenames in "fnames[count]" by current directory.
 */
void shorten_filenames(char_u **fnames, int count)
{
  int i;
  char_u dirname[MAXPATHL];
  char_u      *p;

  if (fnames == NULL || count < 1)
    return;
  mch_dirname(dirname, sizeof(dirname));
  for (i = 0; i < count; ++i) {
    if ((p = shorten_fname(fnames[i], dirname)) != NULL) {
      /* shorten_fname() returns pointer in given "fnames[i]".  If free
       * "fnames[i]" first, "p" becomes invalid.  So we need to copy
       * "p" first then free fnames[i]. */
      p = vim_strsave(p);
      vim_free(fnames[i]);
      fnames[i] = p;
    }
  }
}
#endif

/*
 * add extension to file name - change path/fo.o.h to path/fo.o.h.ext or
 * fo_o_h.ext for MSDOS or when shortname option set.
 *
 * Assumed that fname is a valid name found in the filesystem we assure that
 * the return value is a different name and ends in 'ext'.
 * "ext" MUST be at most 4 characters long if it starts with a dot, 3
 * characters otherwise.
 * Space for the returned name is allocated, must be freed later.
 * Returns NULL when out of memory.
 */
char_u *
modname (
    char_u *fname,
    char_u *ext,
    int prepend_dot                /* may prepend a '.' to file name */
)
{
  return buf_modname(
#ifdef SHORT_FNAME
      TRUE,
#else
      (curbuf->b_p_sn || curbuf->b_shortname),
#endif
      fname, ext, prepend_dot);
}

char_u *
buf_modname (
    int shortname,                  /* use 8.3 file name */
    char_u *fname,
    char_u *ext,
    int prepend_dot                /* may prepend a '.' to file name */
)
{
  char_u      *retval;
  char_u      *s;
  char_u      *e;
  char_u      *ptr;
  int fnamelen, extlen;

  extlen = (int)STRLEN(ext);

  /*
   * If there is no file name we must get the name of the current directory
   * (we need the full path in case :cd is used).
   */
  if (fname == NULL || *fname == NUL) {
    retval = alloc((unsigned)(MAXPATHL + extlen + 3));
    if (retval == NULL)
      return NULL;
    if (mch_dirname(retval, MAXPATHL) == FAIL ||
        (fnamelen = (int)STRLEN(retval)) == 0) {
      vim_free(retval);
      return NULL;
    }
    if (!after_pathsep(retval, retval + fnamelen)) {
      retval[fnamelen++] = PATHSEP;
      retval[fnamelen] = NUL;
    }
#ifndef SHORT_FNAME
    prepend_dot = FALSE;            /* nothing to prepend a dot to */
#endif
  } else   {
    fnamelen = (int)STRLEN(fname);
    retval = alloc((unsigned)(fnamelen + extlen + 3));
    if (retval == NULL)
      return NULL;
    STRCPY(retval, fname);
  }

  /*
   * search backwards until we hit a '/', '\' or ':' replacing all '.'
   * by '_' for MSDOS or when shortname option set and ext starts with a dot.
   * Then truncate what is after the '/', '\' or ':' to 8 characters for
   * MSDOS and 26 characters for AMIGA, a lot more for UNIX.
   */
  for (ptr = retval + fnamelen; ptr > retval; mb_ptr_back(retval, ptr)) {
    if (*ext == '.'
#ifdef USE_LONG_FNAME
        && (!USE_LONG_FNAME || shortname)
#else
# ifndef SHORT_FNAME
        && shortname
# endif
#endif
        )
      if (*ptr == '.')          /* replace '.' by '_' */
        *ptr = '_';
    if (vim_ispathsep(*ptr)) {
      ++ptr;
      break;
    }
  }

  /* the file name has at most BASENAMELEN characters. */
#ifndef SHORT_FNAME
  if (STRLEN(ptr) > (unsigned)BASENAMELEN)
    ptr[BASENAMELEN] = '\0';
#endif

  s = ptr + STRLEN(ptr);

  /*
   * For 8.3 file names we may have to reduce the length.
   */
#ifdef USE_LONG_FNAME
  if (!USE_LONG_FNAME || shortname)
#else
# ifndef SHORT_FNAME
  if (shortname)
# endif
#endif
  {
    /*
     * If there is no file name, or the file name ends in '/', and the
     * extension starts with '.', put a '_' before the dot, because just
     * ".ext" is invalid.
     */
    if (fname == NULL || *fname == NUL
        || vim_ispathsep(fname[STRLEN(fname) - 1])) {
      if (*ext == '.')
        *s++ = '_';
    }
    /*
     * If the extension starts with '.', truncate the base name at 8
     * characters
     */
    else if (*ext == '.') {
      if ((size_t)(s - ptr) > (size_t)8) {
        s = ptr + 8;
        *s = '\0';
      }
    }
    /*
     * If the extension doesn't start with '.', and the file name
     * doesn't have an extension yet, append a '.'
     */
    else if ((e = vim_strchr(ptr, '.')) == NULL)
      *s++ = '.';
    /*
     * If the extension doesn't start with '.', and there already is an
     * extension, it may need to be truncated
     */
    else if ((int)STRLEN(e) + extlen > 4)
      s = e + 4 - extlen;
  }
#if defined(OS2) || defined(USE_LONG_FNAME) || defined(WIN3264)
  /*
   * If there is no file name, and the extension starts with '.', put a
   * '_' before the dot, because just ".ext" may be invalid if it's on a
   * FAT partition, and on HPFS it doesn't matter.
   */
  else if ((fname == NULL || *fname == NUL) && *ext == '.')
    *s++ = '_';
#endif

  /*
   * Append the extension.
   * ext can start with '.' and cannot exceed 3 more characters.
   */
  STRCPY(s, ext);

#ifndef SHORT_FNAME
  /*
   * Prepend the dot.
   */
  if (prepend_dot && !shortname && *(e = gettail(retval)) != '.'
#ifdef USE_LONG_FNAME
      && USE_LONG_FNAME
#endif
      ) {
    STRMOVE(e + 1, e);
    *e = '.';
  }
#endif

  /*
   * Check that, after appending the extension, the file name is really
   * different.
   */
  if (fname != NULL && STRCMP(fname, retval) == 0) {
    /* we search for a character that can be replaced by '_' */
    while (--s >= ptr) {
      if (*s != '_') {
        *s = '_';
        break;
      }
    }
    if (s < ptr)        /* fname was "________.<ext>", how tricky! */
      *ptr = 'v';
  }
  return retval;
}

/*
 * Like fgets(), but if the file line is too long, it is truncated and the
 * rest of the line is thrown away.  Returns TRUE for end-of-file.
 */
int vim_fgets(char_u *buf, int size, FILE *fp)
{
  char        *eof;
#define FGETS_SIZE 200
  char tbuf[FGETS_SIZE];

  buf[size - 2] = NUL;
#ifdef USE_CR
  eof = fgets_cr((char *)buf, size, fp);
#else
  eof = fgets((char *)buf, size, fp);
#endif
  if (buf[size - 2] != NUL && buf[size - 2] != '\n') {
    buf[size - 1] = NUL;            /* Truncate the line */

    /* Now throw away the rest of the line: */
    do {
      tbuf[FGETS_SIZE - 2] = NUL;
#ifdef USE_CR
      ignoredp = fgets_cr((char *)tbuf, FGETS_SIZE, fp);
#else
      ignoredp = fgets((char *)tbuf, FGETS_SIZE, fp);
#endif
    } while (tbuf[FGETS_SIZE - 2] != NUL && tbuf[FGETS_SIZE - 2] != '\n');
  }
  return eof == NULL;
}

#if defined(USE_CR) || defined(PROTO)
/*
 * Like vim_fgets(), but accept any line terminator: CR, CR-LF or LF.
 * Returns TRUE for end-of-file.
 * Only used for the Mac, because it's much slower than vim_fgets().
 */
int tag_fgets(char_u *buf, int size, FILE *fp)
{
  int i = 0;
  int c;
  int eof = FALSE;

  for (;; ) {
    c = fgetc(fp);
    if (c == EOF) {
      eof = TRUE;
      break;
    }
    if (c == '\r') {
      /* Always store a NL for end-of-line. */
      if (i < size - 1)
        buf[i++] = '\n';
      c = fgetc(fp);
      if (c != '\n')            /* Macintosh format: single CR. */
        ungetc(c, fp);
      break;
    }
    if (i < size - 1)
      buf[i++] = c;
    if (c == '\n')
      break;
  }
  buf[i] = NUL;
  return eof;
}
#endif

/*
 * rename() only works if both files are on the same file system, this
 * function will (attempts to?) copy the file across if rename fails -- webb
 * Return -1 for failure, 0 for success.
 */
int vim_rename(char_u *from, char_u *to)
{
  int fd_in;
  int fd_out;
  int n;
  char        *errmsg = NULL;
  char        *buffer;
  struct stat st;
  long perm;
#ifdef HAVE_ACL
  vim_acl_T acl;                /* ACL from original file */
#endif
  int use_tmp_file = FALSE;

  /*
   * When the names are identical, there is nothing to do.  When they refer
   * to the same file (ignoring case and slash/backslash differences) but
   * the file name differs we need to go through a temp file.
   */
  if (fnamecmp(from, to) == 0) {
    if (p_fic && STRCMP(gettail(from), gettail(to)) != 0)
      use_tmp_file = TRUE;
    else
      return 0;
  }

  /*
   * Fail if the "from" file doesn't exist.  Avoids that "to" is deleted.
   */
  if (mch_stat((char *)from, &st) < 0)
    return -1;

#ifdef UNIX
  {
    struct stat st_to;

    /* It's possible for the source and destination to be the same file.
     * This happens when "from" and "to" differ in case and are on a FAT32
     * filesystem.  In that case go through a temp file name. */
    if (mch_stat((char *)to, &st_to) >= 0
        && st.st_dev == st_to.st_dev
        && st.st_ino == st_to.st_ino)
      use_tmp_file = TRUE;
  }
#endif

  if (use_tmp_file) {
    char tempname[MAXPATHL + 1];

    /*
     * Find a name that doesn't exist and is in the same directory.
     * Rename "from" to "tempname" and then rename "tempname" to "to".
     */
    if (STRLEN(from) >= MAXPATHL - 5)
      return -1;
    STRCPY(tempname, from);
    for (n = 123; n < 99999; ++n) {
      sprintf((char *)gettail((char_u *)tempname), "%d", n);
      if (mch_stat(tempname, &st) < 0) {
        if (mch_rename((char *)from, tempname) == 0) {
          if (mch_rename(tempname, (char *)to) == 0)
            return 0;
          /* Strange, the second step failed.  Try moving the
           * file back and return failure. */
          mch_rename(tempname, (char *)from);
          return -1;
        }
        /* If it fails for one temp name it will most likely fail
         * for any temp name, give up. */
        return -1;
      }
    }
    return -1;
  }

  /*
   * Delete the "to" file, this is required on some systems to make the
   * mch_rename() work, on other systems it makes sure that we don't have
   * two files when the mch_rename() fails.
   */

  mch_remove(to);

  /*
   * First try a normal rename, return if it works.
   */
  if (mch_rename((char *)from, (char *)to) == 0)
    return 0;

  /*
   * Rename() failed, try copying the file.
   */
  perm = mch_getperm(from);
#ifdef HAVE_ACL
  /* For systems that support ACL: get the ACL from the original file. */
  acl = mch_get_acl(from);
#endif
  fd_in = mch_open((char *)from, O_RDONLY|O_EXTRA, 0);
  if (fd_in == -1) {
#ifdef HAVE_ACL
    mch_free_acl(acl);
#endif
    return -1;
  }

  /* Create the new file with same permissions as the original. */
  fd_out = mch_open((char *)to,
      O_CREAT|O_EXCL|O_WRONLY|O_EXTRA|O_NOFOLLOW, (int)perm);
  if (fd_out == -1) {
    close(fd_in);
#ifdef HAVE_ACL
    mch_free_acl(acl);
#endif
    return -1;
  }

  buffer = (char *)alloc(BUFSIZE);
  if (buffer == NULL) {
    close(fd_out);
    close(fd_in);
#ifdef HAVE_ACL
    mch_free_acl(acl);
#endif
    return -1;
  }

  while ((n = read_eintr(fd_in, buffer, BUFSIZE)) > 0)
    if (write_eintr(fd_out, buffer, n) != n) {
      errmsg = _("E208: Error writing to \"%s\"");
      break;
    }

  vim_free(buffer);
  close(fd_in);
  if (close(fd_out) < 0)
    errmsg = _("E209: Error closing \"%s\"");
  if (n < 0) {
    errmsg = _("E210: Error reading \"%s\"");
    to = from;
  }
#ifndef UNIX        /* for Unix mch_open() already set the permission */
  mch_setperm(to, perm);
#endif
#ifdef HAVE_ACL
  mch_set_acl(to, acl);
  mch_free_acl(acl);
#endif
#ifdef HAVE_SELINUX
  mch_copy_sec(from, to);
#endif
  if (errmsg != NULL) {
    EMSG2(errmsg, to);
    return -1;
  }
  mch_remove(from);
  return 0;
}

static int already_warned = FALSE;

/*
 * Check if any not hidden buffer has been changed.
 * Postpone the check if there are characters in the stuff buffer, a global
 * command is being executed, a mapping is being executed or an autocommand is
 * busy.
 * Returns TRUE if some message was written (screen should be redrawn and
 * cursor positioned).
 */
int 
check_timestamps (
    int focus                      /* called for GUI focus event */
)
{
  buf_T       *buf;
  int didit = 0;
  int n;

  /* Don't check timestamps while system() or another low-level function may
   * cause us to lose and gain focus. */
  if (no_check_timestamps > 0)
    return FALSE;

  /* Avoid doing a check twice.  The OK/Reload dialog can cause a focus
   * event and we would keep on checking if the file is steadily growing.
   * Do check again after typing something. */
  if (focus && did_check_timestamps) {
    need_check_timestamps = TRUE;
    return FALSE;
  }

  if (!stuff_empty() || global_busy || !typebuf_typed()
      || autocmd_busy || curbuf_lock > 0 || allbuf_lock > 0
      )
    need_check_timestamps = TRUE;               /* check later */
  else {
    ++no_wait_return;
    did_check_timestamps = TRUE;
    already_warned = FALSE;
    for (buf = firstbuf; buf != NULL; ) {
      /* Only check buffers in a window. */
      if (buf->b_nwindows > 0) {
        n = buf_check_timestamp(buf, focus);
        if (didit < n)
          didit = n;
        if (n > 0 && !buf_valid(buf)) {
          /* Autocommands have removed the buffer, start at the
           * first one again. */
          buf = firstbuf;
          continue;
        }
      }
      buf = buf->b_next;
    }
    --no_wait_return;
    need_check_timestamps = FALSE;
    if (need_wait_return && didit == 2) {
      /* make sure msg isn't overwritten */
      msg_puts((char_u *)"\n");
      out_flush();
    }
  }
  return didit;
}

/*
 * Move all the lines from buffer "frombuf" to buffer "tobuf".
 * Return OK or FAIL.  When FAIL "tobuf" is incomplete and/or "frombuf" is not
 * empty.
 */
static int move_lines(buf_T *frombuf, buf_T *tobuf)
{
  buf_T       *tbuf = curbuf;
  int retval = OK;
  linenr_T lnum;
  char_u      *p;

  /* Copy the lines in "frombuf" to "tobuf". */
  curbuf = tobuf;
  for (lnum = 1; lnum <= frombuf->b_ml.ml_line_count; ++lnum) {
    p = vim_strsave(ml_get_buf(frombuf, lnum, FALSE));
    if (p == NULL || ml_append(lnum - 1, p, 0, FALSE) == FAIL) {
      vim_free(p);
      retval = FAIL;
      break;
    }
    vim_free(p);
  }

  /* Delete all the lines in "frombuf". */
  if (retval != FAIL) {
    curbuf = frombuf;
    for (lnum = curbuf->b_ml.ml_line_count; lnum > 0; --lnum)
      if (ml_delete(lnum, FALSE) == FAIL) {
        /* Oops!  We could try putting back the saved lines, but that
         * might fail again... */
        retval = FAIL;
        break;
      }
  }

  curbuf = tbuf;
  return retval;
}

/*
 * Check if buffer "buf" has been changed.
 * Also check if the file for a new buffer unexpectedly appeared.
 * return 1 if a changed buffer was found.
 * return 2 if a message has been displayed.
 * return 0 otherwise.
 */
int 
buf_check_timestamp (
    buf_T *buf,
    int focus               /* called for GUI focus event */
)
{
  struct stat st;
  int stat_res;
  int retval = 0;
  char_u      *path;
  char_u      *tbuf;
  char        *mesg = NULL;
  char        *mesg2 = "";
  int helpmesg = FALSE;
  int reload = FALSE;
  int can_reload = FALSE;
  off_t orig_size = buf->b_orig_size;
  int orig_mode = buf->b_orig_mode;
  static int busy = FALSE;
  int n;
  char_u      *s;
  char        *reason;

  /* If there is no file name, the buffer is not loaded, 'buftype' is
   * set, we are in the middle of a save or being called recursively: ignore
   * this buffer. */
  if (buf->b_ffname == NULL
      || buf->b_ml.ml_mfp == NULL
      || *buf->b_p_bt != NUL
      || buf->b_saving
      || busy
      )
    return 0;

  if (       !(buf->b_flags & BF_NOTEDITED)
             && buf->b_mtime != 0
             && ((stat_res = mch_stat((char *)buf->b_ffname, &st)) < 0
                 || time_differs((long)st.st_mtime, buf->b_mtime)
#ifdef HAVE_ST_MODE
                 || (int)st.st_mode != buf->b_orig_mode
#else
                 || mch_getperm(buf->b_ffname) != buf->b_orig_mode
#endif
                 )) {
    retval = 1;

    /* set b_mtime to stop further warnings (e.g., when executing
     * FileChangedShell autocmd) */
    if (stat_res < 0) {
      buf->b_mtime = 0;
      buf->b_orig_size = 0;
      buf->b_orig_mode = 0;
    } else
      buf_store_time(buf, &st, buf->b_ffname);

    /* Don't do anything for a directory.  Might contain the file
     * explorer. */
    if (mch_isdir(buf->b_fname))
      ;

    /*
     * If 'autoread' is set, the buffer has no changes and the file still
     * exists, reload the buffer.  Use the buffer-local option value if it
     * was set, the global option value otherwise.
     */
    else if ((buf->b_p_ar >= 0 ? buf->b_p_ar : p_ar)
             && !bufIsChanged(buf) && stat_res >= 0)
      reload = TRUE;
    else {
      if (stat_res < 0)
        reason = "deleted";
      else if (bufIsChanged(buf))
        reason = "conflict";
      else if (orig_size != buf->b_orig_size || buf_contents_changed(buf))
        reason = "changed";
      else if (orig_mode != buf->b_orig_mode)
        reason = "mode";
      else
        reason = "time";

      /*
       * Only give the warning if there are no FileChangedShell
       * autocommands.
       * Avoid being called recursively by setting "busy".
       */
      busy = TRUE;
      set_vim_var_string(VV_FCS_REASON, (char_u *)reason, -1);
      set_vim_var_string(VV_FCS_CHOICE, (char_u *)"", -1);
      ++allbuf_lock;
      n = apply_autocmds(EVENT_FILECHANGEDSHELL,
          buf->b_fname, buf->b_fname, FALSE, buf);
      --allbuf_lock;
      busy = FALSE;
      if (n) {
        if (!buf_valid(buf))
          EMSG(_("E246: FileChangedShell autocommand deleted buffer"));
        s = get_vim_var_str(VV_FCS_CHOICE);
        if (STRCMP(s, "reload") == 0 && *reason != 'd')
          reload = TRUE;
        else if (STRCMP(s, "ask") == 0)
          n = FALSE;
        else
          return 2;
      }
      if (!n) {
        if (*reason == 'd')
          mesg = _("E211: File \"%s\" no longer available");
        else {
          helpmesg = TRUE;
          can_reload = TRUE;
          /*
           * Check if the file contents really changed to avoid
           * giving a warning when only the timestamp was set (e.g.,
           * checked out of CVS).  Always warn when the buffer was
           * changed.
           */
          if (reason[2] == 'n') {
            mesg = _(
                "W12: Warning: File \"%s\" has changed and the buffer was changed in Vim as well");
            mesg2 = _("See \":help W12\" for more info.");
          } else if (reason[1] == 'h')   {
            mesg = _(
                "W11: Warning: File \"%s\" has changed since editing started");
            mesg2 = _("See \":help W11\" for more info.");
          } else if (*reason == 'm')   {
            mesg = _(
                "W16: Warning: Mode of file \"%s\" has changed since editing started");
            mesg2 = _("See \":help W16\" for more info.");
          } else
            /* Only timestamp changed, store it to avoid a warning
             * in check_mtime() later. */
            buf->b_mtime_read = buf->b_mtime;
        }
      }
    }

  } else if ((buf->b_flags & BF_NEW) && !(buf->b_flags & BF_NEW_W)
             && vim_fexists(buf->b_ffname)) {
    retval = 1;
    mesg = _("W13: Warning: File \"%s\" has been created after editing started");
    buf->b_flags |= BF_NEW_W;
    can_reload = TRUE;
  }

  if (mesg != NULL) {
    path = home_replace_save(buf, buf->b_fname);
    if (path != NULL) {
      if (!helpmesg)
        mesg2 = "";
      tbuf = alloc((unsigned)(STRLEN(path) + STRLEN(mesg)
                              + STRLEN(mesg2) + 2));
      sprintf((char *)tbuf, mesg, path);
      /* Set warningmsg here, before the unimportant and output-specific
       * mesg2 has been appended. */
      set_vim_var_string(VV_WARNINGMSG, tbuf, -1);
      if (can_reload) {
        if (*mesg2 != NUL) {
          STRCAT(tbuf, "\n");
          STRCAT(tbuf, mesg2);
        }
        if (do_dialog(VIM_WARNING, (char_u *)_("Warning"), tbuf,
                (char_u *)_("&OK\n&Load File"), 1, NULL, TRUE) == 2)
          reload = TRUE;
      } else if (State > NORMAL_BUSY || (State & CMDLINE) ||
                 already_warned)        {
        if (*mesg2 != NUL) {
          STRCAT(tbuf, "; ");
          STRCAT(tbuf, mesg2);
        }
        EMSG(tbuf);
        retval = 2;
      } else   {
        if (!autocmd_busy) {
          msg_start();
          msg_puts_attr(tbuf, hl_attr(HLF_E) + MSG_HIST);
          if (*mesg2 != NUL)
            msg_puts_attr((char_u *)mesg2,
                hl_attr(HLF_W) + MSG_HIST);
          msg_clr_eos();
          (void)msg_end();
          if (emsg_silent == 0) {
            out_flush();
            /* give the user some time to think about it */
            ui_delay(1000L, TRUE);

            /* don't redraw and erase the message */
            redraw_cmdline = FALSE;
          }
        }
        already_warned = TRUE;
      }

      vim_free(path);
      vim_free(tbuf);
    }
  }

  if (reload) {
    /* Reload the buffer. */
    buf_reload(buf, orig_mode);
    if (buf->b_p_udf && buf->b_ffname != NULL) {
      char_u hash[UNDO_HASH_SIZE];
      buf_T           *save_curbuf = curbuf;

      /* Any existing undo file is unusable, write it now. */
      curbuf = buf;
      u_compute_hash(hash);
      u_write_undo(NULL, FALSE, buf, hash);
      curbuf = save_curbuf;
    }
  }

  /* Trigger FileChangedShell when the file was changed in any way. */
  if (buf_valid(buf) && retval != 0)
    (void)apply_autocmds(EVENT_FILECHANGEDSHELLPOST,
        buf->b_fname, buf->b_fname, FALSE, buf);

  return retval;
}

/*
 * Reload a buffer that is already loaded.
 * Used when the file was changed outside of Vim.
 * "orig_mode" is buf->b_orig_mode before the need for reloading was detected.
 * buf->b_orig_mode may have been reset already.
 */
void buf_reload(buf_T *buf, int orig_mode)
{
  exarg_T ea;
  pos_T old_cursor;
  linenr_T old_topline;
  int old_ro = buf->b_p_ro;
  buf_T       *savebuf;
  int saved = OK;
  aco_save_T aco;
  int flags = READ_NEW;

  /* set curwin/curbuf for "buf" and save some things */
  aucmd_prepbuf(&aco, buf);

  /* We only want to read the text from the file, not reset the syntax
   * highlighting, clear marks, diff status, etc.  Force the fileformat
   * and encoding to be the same. */
  if (prep_exarg(&ea, buf) == OK) {
    old_cursor = curwin->w_cursor;
    old_topline = curwin->w_topline;

    if (p_ur < 0 || curbuf->b_ml.ml_line_count <= p_ur) {
      /* Save all the text, so that the reload can be undone.
       * Sync first so that this is a separate undo-able action. */
      u_sync(FALSE);
      saved = u_savecommon(0, curbuf->b_ml.ml_line_count + 1, 0, TRUE);
      flags |= READ_KEEP_UNDO;
    }

    /*
     * To behave like when a new file is edited (matters for
     * BufReadPost autocommands) we first need to delete the current
     * buffer contents.  But if reading the file fails we should keep
     * the old contents.  Can't use memory only, the file might be
     * too big.  Use a hidden buffer to move the buffer contents to.
     */
    if (bufempty() || saved == FAIL)
      savebuf = NULL;
    else {
      /* Allocate a buffer without putting it in the buffer list. */
      savebuf = buflist_new(NULL, NULL, (linenr_T)1, BLN_DUMMY);
      if (savebuf != NULL && buf == curbuf) {
        /* Open the memline. */
        curbuf = savebuf;
        curwin->w_buffer = savebuf;
        saved = ml_open(curbuf);
        curbuf = buf;
        curwin->w_buffer = buf;
      }
      if (savebuf == NULL || saved == FAIL || buf != curbuf
          || move_lines(buf, savebuf) == FAIL) {
        EMSG2(_("E462: Could not prepare for reloading \"%s\""),
            buf->b_fname);
        saved = FAIL;
      }
    }

    if (saved == OK) {
      curbuf->b_flags |= BF_CHECK_RO;           /* check for RO again */
      keep_filetype = TRUE;                     /* don't detect 'filetype' */
      if (readfile(buf->b_ffname, buf->b_fname, (linenr_T)0,
              (linenr_T)0,
              (linenr_T)MAXLNUM, &ea, flags) == FAIL) {
        if (!aborting())
          EMSG2(_("E321: Could not reload \"%s\""), buf->b_fname);
        if (savebuf != NULL && buf_valid(savebuf) && buf == curbuf) {
          /* Put the text back from the save buffer.  First
           * delete any lines that readfile() added. */
          while (!bufempty())
            if (ml_delete(buf->b_ml.ml_line_count, FALSE) == FAIL)
              break;
          (void)move_lines(savebuf, buf);
        }
      } else if (buf == curbuf)   {  /* "buf" still valid */
        /* Mark the buffer as unmodified and free undo info. */
        unchanged(buf, TRUE);
        if ((flags & READ_KEEP_UNDO) == 0) {
          u_blockfree(buf);
          u_clearall(buf);
        } else   {
          /* Mark all undo states as changed. */
          u_unchanged(curbuf);
        }
      }
    }
    vim_free(ea.cmd);

    if (savebuf != NULL && buf_valid(savebuf))
      wipe_buffer(savebuf, FALSE);

    /* Invalidate diff info if necessary. */
    diff_invalidate(curbuf);

    /* Restore the topline and cursor position and check it (lines may
     * have been removed). */
    if (old_topline > curbuf->b_ml.ml_line_count)
      curwin->w_topline = curbuf->b_ml.ml_line_count;
    else
      curwin->w_topline = old_topline;
    curwin->w_cursor = old_cursor;
    check_cursor();
    update_topline();
    keep_filetype = FALSE;
    {
      win_T       *wp;
      tabpage_T   *tp;

      /* Update folds unless they are defined manually. */
      FOR_ALL_TAB_WINDOWS(tp, wp)
      if (wp->w_buffer == curwin->w_buffer
          && !foldmethodIsManual(wp))
        foldUpdateAll(wp);
    }
    /* If the mode didn't change and 'readonly' was set, keep the old
     * value; the user probably used the ":view" command.  But don't
     * reset it, might have had a read error. */
    if (orig_mode == curbuf->b_orig_mode)
      curbuf->b_p_ro |= old_ro;

    /* Modelines must override settings done by autocommands. */
    do_modelines(0);
  }

  /* restore curwin/curbuf and a few other things */
  aucmd_restbuf(&aco);
  /* Careful: autocommands may have made "buf" invalid! */
}

void buf_store_time(buf_T *buf, struct stat *st, char_u *fname)
{
  buf->b_mtime = (long)st->st_mtime;
  buf->b_orig_size = st->st_size;
#ifdef HAVE_ST_MODE
  buf->b_orig_mode = (int)st->st_mode;
#else
  buf->b_orig_mode = mch_getperm(fname);
#endif
}

/*
 * Adjust the line with missing eol, used for the next write.
 * Used for do_filter(), when the input lines for the filter are deleted.
 */
void write_lnum_adjust(linenr_T offset)
{
  if (curbuf->b_no_eol_lnum != 0)       /* only if there is a missing eol */
    curbuf->b_no_eol_lnum += offset;
}

#if defined(TEMPDIRNAMES) || defined(PROTO)
static long temp_count = 0;             /* Temp filename counter. */

/*
 * Delete the temp directory and all files it contains.
 */
void vim_deltempdir(void)          {
  char_u      **files;
  int file_count;
  int i;

  if (vim_tempdir != NULL) {
    sprintf((char *)NameBuff, "%s*", vim_tempdir);
    if (gen_expand_wildcards(1, &NameBuff, &file_count, &files,
            EW_DIR|EW_FILE|EW_SILENT) == OK) {
      for (i = 0; i < file_count; ++i)
        mch_remove(files[i]);
      FreeWild(file_count, files);
    }
    gettail(NameBuff)[-1] = NUL;
    (void)mch_rmdir(NameBuff);

    vim_free(vim_tempdir);
    vim_tempdir = NULL;
  }
}

#endif

#ifdef TEMPDIRNAMES
/*
 * Directory "tempdir" was created.  Expand this name to a full path and put
 * it in "vim_tempdir".  This avoids that using ":cd" would confuse us.
 * "tempdir" must be no longer than MAXPATHL.
 */
static void vim_settempdir(char_u *tempdir)
{
  char_u      *buf;

  buf = alloc((unsigned)MAXPATHL + 2);
  if (buf != NULL) {
    if (vim_FullName(tempdir, buf, MAXPATHL, FALSE) == FAIL)
      STRCPY(buf, tempdir);
    add_pathsep(buf);
    vim_tempdir = vim_strsave(buf);
    vim_free(buf);
  }
}
#endif

/*
 * vim_tempname(): Return a unique name that can be used for a temp file.
 *
 * The temp file is NOT created.
 *
 * The returned pointer is to allocated memory.
 * The returned pointer is NULL if no valid name was found.
 */
char_u *
vim_tempname (
    int extra_char          /* char to use in the name instead of '?' */
)
{
#ifdef USE_TMPNAM
  char_u itmp[L_tmpnam];        /* use tmpnam() */
#else
  char_u itmp[TEMPNAMELEN];
#endif

#ifdef TEMPDIRNAMES
  static char *(tempdirs[]) = {TEMPDIRNAMES};
  int i;
# ifndef EEXIST
  struct stat st;
# endif

  /*
   * This will create a directory for private use by this instance of Vim.
   * This is done once, and the same directory is used for all temp files.
   * This method avoids security problems because of symlink attacks et al.
   * It's also a bit faster, because we only need to check for an existing
   * file when creating the directory and not for each temp file.
   */
  if (vim_tempdir == NULL) {
    /*
     * Try the entries in TEMPDIRNAMES to create the temp directory.
     */
    for (i = 0; i < (int)(sizeof(tempdirs) / sizeof(char *)); ++i) {
# ifndef HAVE_MKDTEMP
      size_t itmplen;
      long nr;
      long off;
# endif

      /* expand $TMP, leave room for "/v1100000/999999999" */
      expand_env((char_u *)tempdirs[i], itmp, TEMPNAMELEN - 20);
      if (mch_isdir(itmp)) {                    /* directory exists */
        add_pathsep(itmp);

# ifdef HAVE_MKDTEMP
        /* Leave room for filename */
        STRCAT(itmp, "vXXXXXX");
        if (mkdtemp((char *)itmp) != NULL)
          vim_settempdir(itmp);
# else
        /* Get an arbitrary number of up to 6 digits.  When it's
         * unlikely that it already exists it will be faster,
         * otherwise it doesn't matter.  The use of mkdir() avoids any
         * security problems because of the predictable number. */
        nr = (mch_get_pid() + (long)time(NULL)) % 1000000L;
        itmplen = STRLEN(itmp);

        /* Try up to 10000 different values until we find a name that
         * doesn't exist. */
        for (off = 0; off < 10000L; ++off) {
          int r;
#  if defined(UNIX) || defined(VMS)
          mode_t umask_save;
#  endif

          sprintf((char *)itmp + itmplen, "v%ld", nr + off);
#  ifndef EEXIST
          /* If mkdir() does not set errno to EEXIST, check for
           * existing file here.  There is a race condition then,
           * although it's fail-safe. */
          if (mch_stat((char *)itmp, &st) >= 0)
            continue;
#  endif
#  if defined(UNIX) || defined(VMS)
          /* Make sure the umask doesn't remove the executable bit.
           * "repl" has been reported to use "177". */
          umask_save = umask(077);
#  endif
          r = vim_mkdir(itmp, 0700);
#  if defined(UNIX) || defined(VMS)
          (void)umask(umask_save);
#  endif
          if (r == 0) {
            vim_settempdir(itmp);
            break;
          }
#  ifdef EEXIST
          /* If the mkdir() didn't fail because the file/dir exists,
           * we probably can't create any dir here, try another
           * place. */
          if (errno != EEXIST)
#  endif
          break;
        }
# endif /* HAVE_MKDTEMP */
        if (vim_tempdir != NULL)
          break;
      }
    }
  }

  if (vim_tempdir != NULL) {
    /* There is no need to check if the file exists, because we own the
     * directory and nobody else creates a file in it. */
    sprintf((char *)itmp, "%s%ld", vim_tempdir, temp_count++);
    return vim_strsave(itmp);
  }

  return NULL;

#else /* TEMPDIRNAMES */


#  ifdef USE_TMPNAM
  char_u      *p;

  /* tmpnam() will make its own name */
  p = tmpnam((char *)itmp);
  if (p == NULL || *p == NUL)
    return NULL;
#  else
  char_u      *p;

#   ifdef VMS_TEMPNAM
  /* mktemp() is not working on VMS.  It seems to be
   * a do-nothing function. Therefore we use tempnam().
   */
  sprintf((char *)itmp, "VIM%c", extra_char);
  p = (char_u *)tempnam("tmp:", (char *)itmp);
  if (p != NULL) {
    /* VMS will use '.LOG' if we don't explicitly specify an extension,
     * and VIM will then be unable to find the file later */
    STRCPY(itmp, p);
    STRCAT(itmp, ".txt");
    free(p);
  } else
    return NULL;
#   else
  STRCPY(itmp, TEMPNAME);
  if ((p = vim_strchr(itmp, '?')) != NULL)
    *p = extra_char;
  if (mktemp((char *)itmp) == NULL)
    return NULL;
#   endif
#  endif

  return vim_strsave(itmp);
#endif /* TEMPDIRNAMES */
}

#if defined(BACKSLASH_IN_FILENAME) || defined(PROTO)
/*
 * Convert all backslashes in fname to forward slashes in-place.
 */
void forward_slash(char_u *fname)
{
  char_u      *p;

  for (p = fname; *p != NUL; ++p)
    /* The Big5 encoding can have '\' in the trail byte. */
    if (enc_dbcs != 0 && (*mb_ptr2len)(p) > 1)
      ++p;
    else if (*p == '\\')
      *p = '/';
}
#endif


/*
 * Code for automatic commands.
 *
 * Only included when "FEAT_AUTOCMD" has been defined.
 */


/*
 * The autocommands are stored in a list for each event.
 * Autocommands for the same pattern, that are consecutive, are joined
 * together, to avoid having to match the pattern too often.
 * The result is an array of Autopat lists, which point to AutoCmd lists:
 *
 * first_autopat[0] --> Autopat.next  -->  Autopat.next -->  NULL
 *			Autopat.cmds	   Autopat.cmds
 *			    |			 |
 *			    V			 V
 *			AutoCmd.next	   AutoCmd.next
 *			    |			 |
 *			    V			 V
 *			AutoCmd.next		NULL
 *			    |
 *			    V
 *			   NULL
 *
 * first_autopat[1] --> Autopat.next  -->  NULL
 *			Autopat.cmds
 *			    |
 *			    V
 *			AutoCmd.next
 *			    |
 *			    V
 *			   NULL
 *   etc.
 *
 *   The order of AutoCmds is important, this is the order in which they were
 *   defined and will have to be executed.
 */
typedef struct AutoCmd {
  char_u          *cmd;                 /* The command to be executed (NULL
                                           when command has been removed) */
  char nested;                          /* If autocommands nest here */
  char last;                            /* last command in list */
  scid_T scriptID;                      /* script ID where defined */
  struct AutoCmd  *next;                /* Next AutoCmd in list */
} AutoCmd;

typedef struct AutoPat {
  char_u          *pat;                 /* pattern as typed (NULL when pattern
                                           has been removed) */
  regprog_T       *reg_prog;            /* compiled regprog for pattern */
  AutoCmd         *cmds;                /* list of commands to do */
  struct AutoPat  *next;                /* next AutoPat in AutoPat list */
  int group;                            /* group ID */
  int patlen;                           /* strlen() of pat */
  int buflocal_nr;                      /* !=0 for buffer-local AutoPat */
  char allow_dirs;                      /* Pattern may match whole path */
  char last;                            /* last pattern for apply_autocmds() */
} AutoPat;

static struct event_name {
  char        *name;    /* event name */
  event_T event;        /* event number */
} event_names[] =
{
  {"BufAdd",          EVENT_BUFADD},
  {"BufCreate",       EVENT_BUFADD},
  {"BufDelete",       EVENT_BUFDELETE},
  {"BufEnter",        EVENT_BUFENTER},
  {"BufFilePost",     EVENT_BUFFILEPOST},
  {"BufFilePre",      EVENT_BUFFILEPRE},
  {"BufHidden",       EVENT_BUFHIDDEN},
  {"BufLeave",        EVENT_BUFLEAVE},
  {"BufNew",          EVENT_BUFNEW},
  {"BufNewFile",      EVENT_BUFNEWFILE},
  {"BufRead",         EVENT_BUFREADPOST},
  {"BufReadCmd",      EVENT_BUFREADCMD},
  {"BufReadPost",     EVENT_BUFREADPOST},
  {"BufReadPre",      EVENT_BUFREADPRE},
  {"BufUnload",       EVENT_BUFUNLOAD},
  {"BufWinEnter",     EVENT_BUFWINENTER},
  {"BufWinLeave",     EVENT_BUFWINLEAVE},
  {"BufWipeout",      EVENT_BUFWIPEOUT},
  {"BufWrite",        EVENT_BUFWRITEPRE},
  {"BufWritePost",    EVENT_BUFWRITEPOST},
  {"BufWritePre",     EVENT_BUFWRITEPRE},
  {"BufWriteCmd",     EVENT_BUFWRITECMD},
  {"CmdwinEnter",     EVENT_CMDWINENTER},
  {"CmdwinLeave",     EVENT_CMDWINLEAVE},
  {"ColorScheme",     EVENT_COLORSCHEME},
  {"CompleteDone",    EVENT_COMPLETEDONE},
  {"CursorHold",      EVENT_CURSORHOLD},
  {"CursorHoldI",     EVENT_CURSORHOLDI},
  {"CursorMoved",     EVENT_CURSORMOVED},
  {"CursorMovedI",    EVENT_CURSORMOVEDI},
  {"EncodingChanged", EVENT_ENCODINGCHANGED},
  {"FileEncoding",    EVENT_ENCODINGCHANGED},
  {"FileAppendPost",  EVENT_FILEAPPENDPOST},
  {"FileAppendPre",   EVENT_FILEAPPENDPRE},
  {"FileAppendCmd",   EVENT_FILEAPPENDCMD},
  {"FileChangedShell",EVENT_FILECHANGEDSHELL},
  {"FileChangedShellPost",EVENT_FILECHANGEDSHELLPOST},
  {"FileChangedRO",   EVENT_FILECHANGEDRO},
  {"FileReadPost",    EVENT_FILEREADPOST},
  {"FileReadPre",     EVENT_FILEREADPRE},
  {"FileReadCmd",     EVENT_FILEREADCMD},
  {"FileType",        EVENT_FILETYPE},
  {"FileWritePost",   EVENT_FILEWRITEPOST},
  {"FileWritePre",    EVENT_FILEWRITEPRE},
  {"FileWriteCmd",    EVENT_FILEWRITECMD},
  {"FilterReadPost",  EVENT_FILTERREADPOST},
  {"FilterReadPre",   EVENT_FILTERREADPRE},
  {"FilterWritePost", EVENT_FILTERWRITEPOST},
  {"FilterWritePre",  EVENT_FILTERWRITEPRE},
  {"FocusGained",     EVENT_FOCUSGAINED},
  {"FocusLost",       EVENT_FOCUSLOST},
  {"FuncUndefined",   EVENT_FUNCUNDEFINED},
  {"GUIEnter",        EVENT_GUIENTER},
  {"GUIFailed",       EVENT_GUIFAILED},
  {"InsertChange",    EVENT_INSERTCHANGE},
  {"InsertEnter",     EVENT_INSERTENTER},
  {"InsertLeave",     EVENT_INSERTLEAVE},
  {"InsertCharPre",   EVENT_INSERTCHARPRE},
  {"MenuPopup",       EVENT_MENUPOPUP},
  {"QuickFixCmdPost", EVENT_QUICKFIXCMDPOST},
  {"QuickFixCmdPre",  EVENT_QUICKFIXCMDPRE},
  {"QuitPre",         EVENT_QUITPRE},
  {"RemoteReply",     EVENT_REMOTEREPLY},
  {"SessionLoadPost", EVENT_SESSIONLOADPOST},
  {"ShellCmdPost",    EVENT_SHELLCMDPOST},
  {"ShellFilterPost", EVENT_SHELLFILTERPOST},
  {"SourcePre",       EVENT_SOURCEPRE},
  {"SourceCmd",       EVENT_SOURCECMD},
  {"SpellFileMissing",EVENT_SPELLFILEMISSING},
  {"StdinReadPost",   EVENT_STDINREADPOST},
  {"StdinReadPre",    EVENT_STDINREADPRE},
  {"SwapExists",      EVENT_SWAPEXISTS},
  {"Syntax",          EVENT_SYNTAX},
  {"TabEnter",        EVENT_TABENTER},
  {"TabLeave",        EVENT_TABLEAVE},
  {"TermChanged",     EVENT_TERMCHANGED},
  {"TermResponse",    EVENT_TERMRESPONSE},
  {"TextChanged",     EVENT_TEXTCHANGED},
  {"TextChangedI",    EVENT_TEXTCHANGEDI},
  {"User",            EVENT_USER},
  {"VimEnter",        EVENT_VIMENTER},
  {"VimLeave",        EVENT_VIMLEAVE},
  {"VimLeavePre",     EVENT_VIMLEAVEPRE},
  {"WinEnter",        EVENT_WINENTER},
  {"WinLeave",        EVENT_WINLEAVE},
  {"VimResized",      EVENT_VIMRESIZED},
  {NULL,              (event_T)0}
};

static AutoPat *first_autopat[NUM_EVENTS] =
{
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
};

/*
 * struct used to keep status while executing autocommands for an event.
 */
typedef struct AutoPatCmd {
  AutoPat     *curpat;          /* next AutoPat to examine */
  AutoCmd     *nextcmd;         /* next AutoCmd to execute */
  int group;                    /* group being used */
  char_u      *fname;           /* fname to match with */
  char_u      *sfname;          /* sfname to match with */
  char_u      *tail;            /* tail of fname */
  event_T event;                /* current event */
  int arg_bufnr;                /* initially equal to <abuf>, set to zero when
                                   buf is deleted */
  struct AutoPatCmd   *next;    /* chain of active apc-s for auto-invalidation*/
} AutoPatCmd;

static AutoPatCmd *active_apc_list = NULL; /* stack of active autocommands */

/*
 * augroups stores a list of autocmd group names.
 */
static garray_T augroups = {0, 0, sizeof(char_u *), 10, NULL};
#define AUGROUP_NAME(i) (((char_u **)augroups.ga_data)[i])

/*
 * The ID of the current group.  Group 0 is the default one.
 */
static int current_augroup = AUGROUP_DEFAULT;

static int au_need_clean = FALSE;   /* need to delete marked patterns */

static void show_autocmd(AutoPat *ap, event_T event);
static void au_remove_pat(AutoPat *ap);
static void au_remove_cmds(AutoPat *ap);
static void au_cleanup(void);
static int au_new_group(char_u *name);
static void au_del_group(char_u *name);
static event_T event_name2nr(char_u *start, char_u **end);
static char_u *event_nr2name(event_T event);
static char_u *find_end_event(char_u *arg, int have_group);
static int event_ignored(event_T event);
static int au_get_grouparg(char_u **argp);
static int do_autocmd_event(event_T event, char_u *pat, int nested,
                            char_u *cmd, int forceit,
                            int group);
static int apply_autocmds_group(event_T event, char_u *fname, char_u *fname_io,
                                int force, int group, buf_T *buf,
                                exarg_T *eap);
static void auto_next_pat(AutoPatCmd *apc, int stop_at_last);


static event_T last_event;
static int last_group;
static int autocmd_blocked = 0;         /* block all autocmds */

/*
 * Show the autocommands for one AutoPat.
 */
static void show_autocmd(AutoPat *ap, event_T event)
{
  AutoCmd *ac;

  /* Check for "got_int" (here and at various places below), which is set
   * when "q" has been hit for the "--more--" prompt */
  if (got_int)
    return;
  if (ap->pat == NULL)                  /* pattern has been removed */
    return;

  msg_putchar('\n');
  if (got_int)
    return;
  if (event != last_event || ap->group != last_group) {
    if (ap->group != AUGROUP_DEFAULT) {
      if (AUGROUP_NAME(ap->group) == NULL)
        msg_puts_attr((char_u *)_("--Deleted--"), hl_attr(HLF_E));
      else
        msg_puts_attr(AUGROUP_NAME(ap->group), hl_attr(HLF_T));
      msg_puts((char_u *)"  ");
    }
    msg_puts_attr(event_nr2name(event), hl_attr(HLF_T));
    last_event = event;
    last_group = ap->group;
    msg_putchar('\n');
    if (got_int)
      return;
  }
  msg_col = 4;
  msg_outtrans(ap->pat);

  for (ac = ap->cmds; ac != NULL; ac = ac->next) {
    if (ac->cmd != NULL) {              /* skip removed commands */
      if (msg_col >= 14)
        msg_putchar('\n');
      msg_col = 14;
      if (got_int)
        return;
      msg_outtrans(ac->cmd);
      if (p_verbose > 0)
        last_set_msg(ac->scriptID);
      if (got_int)
        return;
      if (ac->next != NULL) {
        msg_putchar('\n');
        if (got_int)
          return;
      }
    }
  }
}

/*
 * Mark an autocommand pattern for deletion.
 */
static void au_remove_pat(AutoPat *ap)
{
  vim_free(ap->pat);
  ap->pat = NULL;
  ap->buflocal_nr = -1;
  au_need_clean = TRUE;
}

/*
 * Mark all commands for a pattern for deletion.
 */
static void au_remove_cmds(AutoPat *ap)
{
  AutoCmd *ac;

  for (ac = ap->cmds; ac != NULL; ac = ac->next) {
    vim_free(ac->cmd);
    ac->cmd = NULL;
  }
  au_need_clean = TRUE;
}

/*
 * Cleanup autocommands and patterns that have been deleted.
 * This is only done when not executing autocommands.
 */
static void au_cleanup(void)                 {
  AutoPat     *ap, **prev_ap;
  AutoCmd     *ac, **prev_ac;
  event_T event;

  if (autocmd_busy || !au_need_clean)
    return;

  /* loop over all events */
  for (event = (event_T)0; (int)event < (int)NUM_EVENTS;
       event = (event_T)((int)event + 1)) {
    /* loop over all autocommand patterns */
    prev_ap = &(first_autopat[(int)event]);
    for (ap = *prev_ap; ap != NULL; ap = *prev_ap) {
      /* loop over all commands for this pattern */
      prev_ac = &(ap->cmds);
      for (ac = *prev_ac; ac != NULL; ac = *prev_ac) {
        /* remove the command if the pattern is to be deleted or when
         * the command has been marked for deletion */
        if (ap->pat == NULL || ac->cmd == NULL) {
          *prev_ac = ac->next;
          vim_free(ac->cmd);
          vim_free(ac);
        } else
          prev_ac = &(ac->next);
      }

      /* remove the pattern if it has been marked for deletion */
      if (ap->pat == NULL) {
        *prev_ap = ap->next;
        vim_regfree(ap->reg_prog);
        vim_free(ap);
      } else
        prev_ap = &(ap->next);
    }
  }

  au_need_clean = FALSE;
}

/*
 * Called when buffer is freed, to remove/invalidate related buffer-local
 * autocmds.
 */
void aubuflocal_remove(buf_T *buf)
{
  AutoPat     *ap;
  event_T event;
  AutoPatCmd  *apc;

  /* invalidate currently executing autocommands */
  for (apc = active_apc_list; apc; apc = apc->next)
    if (buf->b_fnum == apc->arg_bufnr)
      apc->arg_bufnr = 0;

  /* invalidate buflocals looping through events */
  for (event = (event_T)0; (int)event < (int)NUM_EVENTS;
       event = (event_T)((int)event + 1))
    /* loop over all autocommand patterns */
    for (ap = first_autopat[(int)event]; ap != NULL; ap = ap->next)
      if (ap->buflocal_nr == buf->b_fnum) {
        au_remove_pat(ap);
        if (p_verbose >= 6) {
          verbose_enter();
          smsg((char_u *)
              _("auto-removing autocommand: %s <buffer=%d>"),
              event_nr2name(event), buf->b_fnum);
          verbose_leave();
        }
      }
  au_cleanup();
}

/*
 * Add an autocmd group name.
 * Return it's ID.  Returns AUGROUP_ERROR (< 0) for error.
 */
static int au_new_group(char_u *name)
{
  int i;

  i = au_find_group(name);
  if (i == AUGROUP_ERROR) {     /* the group doesn't exist yet, add it */
    /* First try using a free entry. */
    for (i = 0; i < augroups.ga_len; ++i)
      if (AUGROUP_NAME(i) == NULL)
        break;
    if (i == augroups.ga_len && ga_grow(&augroups, 1) == FAIL)
      return AUGROUP_ERROR;

    AUGROUP_NAME(i) = vim_strsave(name);
    if (AUGROUP_NAME(i) == NULL)
      return AUGROUP_ERROR;
    if (i == augroups.ga_len)
      ++augroups.ga_len;
  }

  return i;
}

static void au_del_group(char_u *name)
{
  int i;

  i = au_find_group(name);
  if (i == AUGROUP_ERROR)       /* the group doesn't exist */
    EMSG2(_("E367: No such group: \"%s\""), name);
  else {
    vim_free(AUGROUP_NAME(i));
    AUGROUP_NAME(i) = NULL;
  }
}

/*
 * Find the ID of an autocmd group name.
 * Return it's ID.  Returns AUGROUP_ERROR (< 0) for error.
 */
static int au_find_group(char_u *name)
{
  int i;

  for (i = 0; i < augroups.ga_len; ++i)
    if (AUGROUP_NAME(i) != NULL && STRCMP(AUGROUP_NAME(i), name) == 0)
      return i;
  return AUGROUP_ERROR;
}

/*
 * Return TRUE if augroup "name" exists.
 */
int au_has_group(char_u *name)
{
  return au_find_group(name) != AUGROUP_ERROR;
}

/*
 * ":augroup {name}".
 */
void do_augroup(char_u *arg, int del_group)
{
  int i;

  if (del_group) {
    if (*arg == NUL)
      EMSG(_(e_argreq));
    else
      au_del_group(arg);
  } else if (STRICMP(arg, "end") == 0)   /* ":aug end": back to group 0 */
    current_augroup = AUGROUP_DEFAULT;
  else if (*arg) {                  /* ":aug xxx": switch to group xxx */
    i = au_new_group(arg);
    if (i != AUGROUP_ERROR)
      current_augroup = i;
  } else   {                        /* ":aug": list the group names */
    msg_start();
    for (i = 0; i < augroups.ga_len; ++i) {
      if (AUGROUP_NAME(i) != NULL) {
        msg_puts(AUGROUP_NAME(i));
        msg_puts((char_u *)"  ");
      }
    }
    msg_clr_eos();
    msg_end();
  }
}

#if defined(EXITFREE) || defined(PROTO)
void free_all_autocmds(void)          {
  for (current_augroup = -1; current_augroup < augroups.ga_len;
       ++current_augroup)
    do_autocmd((char_u *)"", TRUE);
  ga_clear_strings(&augroups);
}

#endif

/*
 * Return the event number for event name "start".
 * Return NUM_EVENTS if the event name was not found.
 * Return a pointer to the next event name in "end".
 */
static event_T event_name2nr(char_u *start, char_u **end)
{
  char_u      *p;
  int i;
  int len;

  /* the event name ends with end of line, a blank or a comma */
  for (p = start; *p && !vim_iswhite(*p) && *p != ','; ++p)
    ;
  for (i = 0; event_names[i].name != NULL; ++i) {
    len = (int)STRLEN(event_names[i].name);
    if (len == p - start && STRNICMP(event_names[i].name, start, len) == 0)
      break;
  }
  if (*p == ',')
    ++p;
  *end = p;
  if (event_names[i].name == NULL)
    return NUM_EVENTS;
  return event_names[i].event;
}

/*
 * Return the name for event "event".
 */
static char_u *event_nr2name(event_T event)
{
  int i;

  for (i = 0; event_names[i].name != NULL; ++i)
    if (event_names[i].event == event)
      return (char_u *)event_names[i].name;
  return (char_u *)"Unknown";
}

/*
 * Scan over the events.  "*" stands for all events.
 */
static char_u *
find_end_event (
    char_u *arg,
    int have_group             /* TRUE when group name was found */
)
{
  char_u  *pat;
  char_u  *p;

  if (*arg == '*') {
    if (arg[1] && !vim_iswhite(arg[1])) {
      EMSG2(_("E215: Illegal character after *: %s"), arg);
      return NULL;
    }
    pat = arg + 1;
  } else   {
    for (pat = arg; *pat && !vim_iswhite(*pat); pat = p) {
      if ((int)event_name2nr(pat, &p) >= (int)NUM_EVENTS) {
        if (have_group)
          EMSG2(_("E216: No such event: %s"), pat);
        else
          EMSG2(_("E216: No such group or event: %s"), pat);
        return NULL;
      }
    }
  }
  return pat;
}

/*
 * Return TRUE if "event" is included in 'eventignore'.
 */
static int event_ignored(event_T event)
{
  char_u      *p = p_ei;

  while (*p != NUL) {
    if (STRNICMP(p, "all", 3) == 0 && (p[3] == NUL || p[3] == ','))
      return TRUE;
    if (event_name2nr(p, &p) == event)
      return TRUE;
  }

  return FALSE;
}

/*
 * Return OK when the contents of p_ei is valid, FAIL otherwise.
 */
int check_ei(void)         {
  char_u      *p = p_ei;

  while (*p) {
    if (STRNICMP(p, "all", 3) == 0 && (p[3] == NUL || p[3] == ',')) {
      p += 3;
      if (*p == ',')
        ++p;
    } else if (event_name2nr(p, &p) == NUM_EVENTS)
      return FAIL;
  }

  return OK;
}

/*
 * Add "what" to 'eventignore' to skip loading syntax highlighting for every
 * buffer loaded into the window.  "what" must start with a comma.
 * Returns the old value of 'eventignore' in allocated memory.
 */
char_u *au_event_disable(char *what)
{
  char_u      *new_ei;
  char_u      *save_ei;

  save_ei = vim_strsave(p_ei);
  if (save_ei != NULL) {
    new_ei = vim_strnsave(p_ei, (int)(STRLEN(p_ei) + STRLEN(what)));
    if (new_ei != NULL) {
      if (*what == ',' && *p_ei == NUL)
        STRCPY(new_ei, what + 1);
      else
        STRCAT(new_ei, what);
      set_string_option_direct((char_u *)"ei", -1, new_ei,
          OPT_FREE, SID_NONE);
      vim_free(new_ei);
    }
  }
  return save_ei;
}

void au_event_restore(char_u *old_ei)
{
  if (old_ei != NULL) {
    set_string_option_direct((char_u *)"ei", -1, old_ei,
        OPT_FREE, SID_NONE);
    vim_free(old_ei);
  }
}

/*
 * do_autocmd() -- implements the :autocmd command.  Can be used in the
 *  following ways:
 *
 * :autocmd <event> <pat> <cmd>	    Add <cmd> to the list of commands that
 *				    will be automatically executed for <event>
 *				    when editing a file matching <pat>, in
 *				    the current group.
 * :autocmd <event> <pat>	    Show the auto-commands associated with
 *				    <event> and <pat>.
 * :autocmd <event>		    Show the auto-commands associated with
 *				    <event>.
 * :autocmd			    Show all auto-commands.
 * :autocmd! <event> <pat> <cmd>    Remove all auto-commands associated with
 *				    <event> and <pat>, and add the command
 *				    <cmd>, for the current group.
 * :autocmd! <event> <pat>	    Remove all auto-commands associated with
 *				    <event> and <pat> for the current group.
 * :autocmd! <event>		    Remove all auto-commands associated with
 *				    <event> for the current group.
 * :autocmd!			    Remove ALL auto-commands for the current
 *				    group.
 *
 *  Multiple events and patterns may be given separated by commas.  Here are
 *  some examples:
 * :autocmd bufread,bufenter *.c,*.h	set tw=0 smartindent noic
 * :autocmd bufleave	     *		set tw=79 nosmartindent ic infercase
 *
 * :autocmd * *.c		show all autocommands for *.c files.
 *
 * Mostly a {group} argument can optionally appear before <event>.
 */
void do_autocmd(char_u *arg, int forceit)
{
  char_u      *pat;
  char_u      *envpat = NULL;
  char_u      *cmd;
  event_T event;
  int need_free = FALSE;
  int nested = FALSE;
  int group;

  /*
   * Check for a legal group name.  If not, use AUGROUP_ALL.
   */
  group = au_get_grouparg(&arg);
  if (arg == NULL)          /* out of memory */
    return;

  /*
   * Scan over the events.
   * If we find an illegal name, return here, don't do anything.
   */
  pat = find_end_event(arg, group != AUGROUP_ALL);
  if (pat == NULL)
    return;

  /*
   * Scan over the pattern.  Put a NUL at the end.
   */
  pat = skipwhite(pat);
  cmd = pat;
  while (*cmd && (!vim_iswhite(*cmd) || cmd[-1] == '\\'))
    cmd++;
  if (*cmd)
    *cmd++ = NUL;

  /* Expand environment variables in the pattern.  Set 'shellslash', we want
   * forward slashes here. */
  if (vim_strchr(pat, '$') != NULL || vim_strchr(pat, '~') != NULL) {
#ifdef BACKSLASH_IN_FILENAME
    int p_ssl_save = p_ssl;

    p_ssl = TRUE;
#endif
    envpat = expand_env_save(pat);
#ifdef BACKSLASH_IN_FILENAME
    p_ssl = p_ssl_save;
#endif
    if (envpat != NULL)
      pat = envpat;
  }

  /*
   * Check for "nested" flag.
   */
  cmd = skipwhite(cmd);
  if (*cmd != NUL && STRNCMP(cmd, "nested", 6) == 0 && vim_iswhite(cmd[6])) {
    nested = TRUE;
    cmd = skipwhite(cmd + 6);
  }

  /*
   * Find the start of the commands.
   * Expand <sfile> in it.
   */
  if (*cmd != NUL) {
    cmd = expand_sfile(cmd);
    if (cmd == NULL)                /* some error */
      return;
    need_free = TRUE;
  }

  /*
   * Print header when showing autocommands.
   */
  if (!forceit && *cmd == NUL) {
    /* Highlight title */
    MSG_PUTS_TITLE(_("\n--- Auto-Commands ---"));
  }

  /*
   * Loop over the events.
   */
  last_event = (event_T)-1;             /* for listing the event name */
  last_group = AUGROUP_ERROR;           /* for listing the group name */
  if (*arg == '*' || *arg == NUL) {
    for (event = (event_T)0; (int)event < (int)NUM_EVENTS;
         event = (event_T)((int)event + 1))
      if (do_autocmd_event(event, pat,
              nested, cmd, forceit, group) == FAIL)
        break;
  } else   {
    while (*arg && !vim_iswhite(*arg))
      if (do_autocmd_event(event_name2nr(arg, &arg), pat,
              nested, cmd, forceit, group) == FAIL)
        break;
  }

  if (need_free)
    vim_free(cmd);
  vim_free(envpat);
}

/*
 * Find the group ID in a ":autocmd" or ":doautocmd" argument.
 * The "argp" argument is advanced to the following argument.
 *
 * Returns the group ID, AUGROUP_ERROR for error (out of memory).
 */
static int au_get_grouparg(char_u **argp)
{
  char_u      *group_name;
  char_u      *p;
  char_u      *arg = *argp;
  int group = AUGROUP_ALL;

  p = skiptowhite(arg);
  if (p > arg) {
    group_name = vim_strnsave(arg, (int)(p - arg));
    if (group_name == NULL)             /* out of memory */
      return AUGROUP_ERROR;
    group = au_find_group(group_name);
    if (group == AUGROUP_ERROR)
      group = AUGROUP_ALL;              /* no match, use all groups */
    else
      *argp = skipwhite(p);             /* match, skip over group name */
    vim_free(group_name);
  }
  return group;
}

/*
 * do_autocmd() for one event.
 * If *pat == NUL do for all patterns.
 * If *cmd == NUL show entries.
 * If forceit == TRUE delete entries.
 * If group is not AUGROUP_ALL, only use this group.
 */
static int do_autocmd_event(event_T event, char_u *pat, int nested, char_u *cmd, int forceit, int group)
{
  AutoPat     *ap;
  AutoPat     **prev_ap;
  AutoCmd     *ac;
  AutoCmd     **prev_ac;
  int brace_level;
  char_u      *endpat;
  int findgroup;
  int allgroups;
  int patlen;
  int is_buflocal;
  int buflocal_nr;
  char_u buflocal_pat[25];              /* for "<buffer=X>" */

  if (group == AUGROUP_ALL)
    findgroup = current_augroup;
  else
    findgroup = group;
  allgroups = (group == AUGROUP_ALL && !forceit && *cmd == NUL);

  /*
   * Show or delete all patterns for an event.
   */
  if (*pat == NUL) {
    for (ap = first_autopat[(int)event]; ap != NULL; ap = ap->next) {
      if (forceit) {      /* delete the AutoPat, if it's in the current group */
        if (ap->group == findgroup)
          au_remove_pat(ap);
      } else if (group == AUGROUP_ALL || ap->group == group)
        show_autocmd(ap, event);
    }
  }

  /*
   * Loop through all the specified patterns.
   */
  for (; *pat; pat = (*endpat == ',' ? endpat + 1 : endpat)) {
    /*
     * Find end of the pattern.
     * Watch out for a comma in braces, like "*.\{obj,o\}".
     */
    brace_level = 0;
    for (endpat = pat; *endpat && (*endpat != ',' || brace_level
                                   || endpat[-1] == '\\'); ++endpat) {
      if (*endpat == '{')
        brace_level++;
      else if (*endpat == '}')
        brace_level--;
    }
    if (pat == endpat)                  /* ignore single comma */
      continue;
    patlen = (int)(endpat - pat);

    /*
     * detect special <buflocal[=X]> buffer-local patterns
     */
    is_buflocal = FALSE;
    buflocal_nr = 0;

    if (patlen >= 7 && STRNCMP(pat, "<buffer", 7) == 0
        && pat[patlen - 1] == '>') {
      /* Error will be printed only for addition. printing and removing
       * will proceed silently. */
      is_buflocal = TRUE;
      if (patlen == 8)
        buflocal_nr = curbuf->b_fnum;
      else if (patlen > 9 && pat[7] == '=') {
        /* <buffer=abuf> */
        if (patlen == 13 && STRNICMP(pat, "<buffer=abuf>", 13))
          buflocal_nr = autocmd_bufnr;
        /* <buffer=123> */
        else if (skipdigits(pat + 8) == pat + patlen - 1)
          buflocal_nr = atoi((char *)pat + 8);
      }
    }

    if (is_buflocal) {
      /* normalize pat into standard "<buffer>#N" form */
      sprintf((char *)buflocal_pat, "<buffer=%d>", buflocal_nr);
      pat = buflocal_pat;                       /* can modify pat and patlen */
      patlen = (int)STRLEN(buflocal_pat);       /*   but not endpat */
    }

    /*
     * Find AutoPat entries with this pattern.
     */
    prev_ap = &first_autopat[(int)event];
    while ((ap = *prev_ap) != NULL) {
      if (ap->pat != NULL) {
        /* Accept a pattern when:
         * - a group was specified and it's that group, or a group was
         *   not specified and it's the current group, or a group was
         *   not specified and we are listing
         * - the length of the pattern matches
         * - the pattern matches.
         * For <buffer[=X]>, this condition works because we normalize
         * all buffer-local patterns.
         */
        if ((allgroups || ap->group == findgroup)
            && ap->patlen == patlen
            && STRNCMP(pat, ap->pat, patlen) == 0) {
          /*
           * Remove existing autocommands.
           * If adding any new autocmd's for this AutoPat, don't
           * delete the pattern from the autopat list, append to
           * this list.
           */
          if (forceit) {
            if (*cmd != NUL && ap->next == NULL) {
              au_remove_cmds(ap);
              break;
            }
            au_remove_pat(ap);
          }
          /*
           * Show autocmd's for this autopat, or buflocals <buffer=X>
           */
          else if (*cmd == NUL)
            show_autocmd(ap, event);

          /*
           * Add autocmd to this autopat, if it's the last one.
           */
          else if (ap->next == NULL)
            break;
        }
      }
      prev_ap = &ap->next;
    }

    /*
     * Add a new command.
     */
    if (*cmd != NUL) {
      /*
       * If the pattern we want to add a command to does appear at the
       * end of the list (or not is not in the list at all), add the
       * pattern at the end of the list.
       */
      if (ap == NULL) {
        /* refuse to add buffer-local ap if buffer number is invalid */
        if (is_buflocal && (buflocal_nr == 0
                            || buflist_findnr(buflocal_nr) == NULL)) {
          EMSGN(_("E680: <buffer=%d>: invalid buffer number "),
              buflocal_nr);
          return FAIL;
        }

        ap = (AutoPat *)alloc((unsigned)sizeof(AutoPat));
        if (ap == NULL)
          return FAIL;
        ap->pat = vim_strnsave(pat, patlen);
        ap->patlen = patlen;
        if (ap->pat == NULL) {
          vim_free(ap);
          return FAIL;
        }

        if (is_buflocal) {
          ap->buflocal_nr = buflocal_nr;
          ap->reg_prog = NULL;
        } else   {
          char_u      *reg_pat;

          ap->buflocal_nr = 0;
          reg_pat = file_pat_to_reg_pat(pat, endpat,
              &ap->allow_dirs, TRUE);
          if (reg_pat != NULL)
            ap->reg_prog = vim_regcomp(reg_pat, RE_MAGIC);
          vim_free(reg_pat);
          if (reg_pat == NULL || ap->reg_prog == NULL) {
            vim_free(ap->pat);
            vim_free(ap);
            return FAIL;
          }
        }
        ap->cmds = NULL;
        *prev_ap = ap;
        ap->next = NULL;
        if (group == AUGROUP_ALL)
          ap->group = current_augroup;
        else
          ap->group = group;
      }

      /*
       * Add the autocmd at the end of the AutoCmd list.
       */
      prev_ac = &(ap->cmds);
      while ((ac = *prev_ac) != NULL)
        prev_ac = &ac->next;
      ac = (AutoCmd *)alloc((unsigned)sizeof(AutoCmd));
      if (ac == NULL)
        return FAIL;
      ac->cmd = vim_strsave(cmd);
      ac->scriptID = current_SID;
      if (ac->cmd == NULL) {
        vim_free(ac);
        return FAIL;
      }
      ac->next = NULL;
      *prev_ac = ac;
      ac->nested = nested;
    }
  }

  au_cleanup();         /* may really delete removed patterns/commands now */
  return OK;
}

/*
 * Implementation of ":doautocmd [group] event [fname]".
 * Return OK for success, FAIL for failure;
 */
int 
do_doautocmd (
    char_u *arg,
    int do_msg                 /* give message for no matching autocmds? */
)
{
  char_u      *fname;
  int nothing_done = TRUE;
  int group;

  /*
   * Check for a legal group name.  If not, use AUGROUP_ALL.
   */
  group = au_get_grouparg(&arg);
  if (arg == NULL)          /* out of memory */
    return FAIL;

  if (*arg == '*') {
    EMSG(_("E217: Can't execute autocommands for ALL events"));
    return FAIL;
  }

  /*
   * Scan over the events.
   * If we find an illegal name, return here, don't do anything.
   */
  fname = find_end_event(arg, group != AUGROUP_ALL);
  if (fname == NULL)
    return FAIL;

  fname = skipwhite(fname);

  /*
   * Loop over the events.
   */
  while (*arg && !vim_iswhite(*arg))
    if (apply_autocmds_group(event_name2nr(arg, &arg),
            fname, NULL, TRUE, group, curbuf, NULL))
      nothing_done = FALSE;

  if (nothing_done && do_msg)
    MSG(_("No matching autocommands"));

  return aborting() ? FAIL : OK;
}

/*
 * ":doautoall": execute autocommands for each loaded buffer.
 */
void ex_doautoall(exarg_T *eap)
{
  int retval;
  aco_save_T aco;
  buf_T       *buf;
  char_u      *arg = eap->arg;
  int call_do_modelines = check_nomodeline(&arg);

  /*
   * This is a bit tricky: For some commands curwin->w_buffer needs to be
   * equal to curbuf, but for some buffers there may not be a window.
   * So we change the buffer for the current window for a moment.  This
   * gives problems when the autocommands make changes to the list of
   * buffers or windows...
   */
  for (buf = firstbuf; buf != NULL; buf = buf->b_next) {
    if (buf->b_ml.ml_mfp != NULL) {
      /* find a window for this buffer and save some values */
      aucmd_prepbuf(&aco, buf);

      /* execute the autocommands for this buffer */
      retval = do_doautocmd(arg, FALSE);

      if (call_do_modelines) {
        /* Execute the modeline settings, but don't set window-local
         * options if we are using the current window for another
         * buffer. */
        do_modelines(curwin == aucmd_win ? OPT_NOWIN : 0);
      }

      /* restore the current window */
      aucmd_restbuf(&aco);

      /* stop if there is some error or buffer was deleted */
      if (retval == FAIL || !buf_valid(buf))
        break;
    }
  }

  check_cursor();           /* just in case lines got deleted */
}

/*
 * Check *argp for <nomodeline>.  When it is present return FALSE, otherwise
 * return TRUE and advance *argp to after it.
 * Thus return TRUE when do_modelines() should be called.
 */
int check_nomodeline(char_u **argp)
{
  if (STRNCMP(*argp, "<nomodeline>", 12) == 0) {
    *argp = skipwhite(*argp + 12);
    return FALSE;
  }
  return TRUE;
}

/*
 * Prepare for executing autocommands for (hidden) buffer "buf".
 * Search for a visible window containing the current buffer.  If there isn't
 * one then use "aucmd_win".
 * Set "curbuf" and "curwin" to match "buf".
 * When FEAT_AUTOCMD is not defined another version is used, see below.
 */
void 
aucmd_prepbuf (
    aco_save_T *aco,               /* structure to save values in */
    buf_T *buf               /* new curbuf */
)
{
  win_T       *win;
  int save_ea;
  int save_acd;

  /* Find a window that is for the new buffer */
  if (buf == curbuf)            /* be quick when buf is curbuf */
    win = curwin;
  else
    for (win = firstwin; win != NULL; win = win->w_next)
      if (win->w_buffer == buf)
        break;

  /* Allocate "aucmd_win" when needed.  If this fails (out of memory) fall
   * back to using the current window. */
  if (win == NULL && aucmd_win == NULL) {
    win_alloc_aucmd_win();
    if (aucmd_win == NULL)
      win = curwin;
  }
  if (win == NULL && aucmd_win_used)
    /* Strange recursive autocommand, fall back to using the current
     * window.  Expect a few side effects... */
    win = curwin;

  aco->save_curwin = curwin;
  aco->save_curbuf = curbuf;
  if (win != NULL) {
    /* There is a window for "buf" in the current tab page, make it the
     * curwin.  This is preferred, it has the least side effects (esp. if
     * "buf" is curbuf). */
    aco->use_aucmd_win = FALSE;
    curwin = win;
  } else   {
    /* There is no window for "buf", use "aucmd_win".  To minimize the side
     * effects, insert it in the current tab page.
     * Anything related to a window (e.g., setting folds) may have
     * unexpected results. */
    aco->use_aucmd_win = TRUE;
    aucmd_win_used = TRUE;
    aucmd_win->w_buffer = buf;
    aucmd_win->w_s = &buf->b_s;
    ++buf->b_nwindows;
    win_init_empty(aucmd_win);     /* set cursor and topline to safe values */

    /* Make sure w_localdir and globaldir are NULL to avoid a chdir() in
     * win_enter_ext(). */
    vim_free(aucmd_win->w_localdir);
    aucmd_win->w_localdir = NULL;
    aco->globaldir = globaldir;
    globaldir = NULL;


    /* Split the current window, put the aucmd_win in the upper half.
     * We don't want the BufEnter or WinEnter autocommands. */
    block_autocmds();
    make_snapshot(SNAP_AUCMD_IDX);
    save_ea = p_ea;
    p_ea = FALSE;

    /* Prevent chdir() call in win_enter_ext(), through do_autochdir(). */
    save_acd = p_acd;
    p_acd = FALSE;

    (void)win_split_ins(0, WSP_TOP, aucmd_win, 0);
    (void)win_comp_pos();       /* recompute window positions */
    p_ea = save_ea;
    p_acd = save_acd;
    unblock_autocmds();
    curwin = aucmd_win;
  }
  curbuf = buf;
  aco->new_curwin = curwin;
  aco->new_curbuf = curbuf;
}

/*
 * Cleanup after executing autocommands for a (hidden) buffer.
 * Restore the window as it was (if possible).
 * When FEAT_AUTOCMD is not defined another version is used, see below.
 */
void 
aucmd_restbuf (
    aco_save_T *aco               /* structure holding saved values */
)
{
  int dummy;

  if (aco->use_aucmd_win) {
    --curbuf->b_nwindows;
    /* Find "aucmd_win", it can't be closed, but it may be in another tab
     * page. Do not trigger autocommands here. */
    block_autocmds();
    if (curwin != aucmd_win) {
      tabpage_T   *tp;
      win_T       *wp;

      FOR_ALL_TAB_WINDOWS(tp, wp)
      {
        if (wp == aucmd_win) {
          if (tp != curtab)
            goto_tabpage_tp(tp, TRUE, TRUE);
          win_goto(aucmd_win);
          goto win_found;
        }
      }
    }
win_found:

    /* Remove the window and frame from the tree of frames. */
    (void)winframe_remove(curwin, &dummy, NULL);
    win_remove(curwin, NULL);
    aucmd_win_used = FALSE;
    last_status(FALSE);             /* may need to remove last status line */
    restore_snapshot(SNAP_AUCMD_IDX, FALSE);
    (void)win_comp_pos();       /* recompute window positions */
    unblock_autocmds();

    if (win_valid(aco->save_curwin))
      curwin = aco->save_curwin;
    else
      /* Hmm, original window disappeared.  Just use the first one. */
      curwin = firstwin;
    vars_clear(&aucmd_win->w_vars->dv_hashtab);      /* free all w: variables */
    hash_init(&aucmd_win->w_vars->dv_hashtab);       /* re-use the hashtab */
    curbuf = curwin->w_buffer;

    vim_free(globaldir);
    globaldir = aco->globaldir;

    /* the buffer contents may have changed */
    check_cursor();
    if (curwin->w_topline > curbuf->b_ml.ml_line_count) {
      curwin->w_topline = curbuf->b_ml.ml_line_count;
      curwin->w_topfill = 0;
    }
  } else   {
    /* restore curwin */
    if (win_valid(aco->save_curwin)) {
      /* Restore the buffer which was previously edited by curwin, if
       * it was changed, we are still the same window and the buffer is
       * valid. */
      if (curwin == aco->new_curwin
          && curbuf != aco->new_curbuf
          && buf_valid(aco->new_curbuf)
          && aco->new_curbuf->b_ml.ml_mfp != NULL) {
        if (curwin->w_s == &curbuf->b_s)
          curwin->w_s = &aco->new_curbuf->b_s;
        --curbuf->b_nwindows;
        curbuf = aco->new_curbuf;
        curwin->w_buffer = curbuf;
        ++curbuf->b_nwindows;
      }

      curwin = aco->save_curwin;
      curbuf = curwin->w_buffer;
    }
  }
}

static int autocmd_nested = FALSE;

/*
 * Execute autocommands for "event" and file name "fname".
 * Return TRUE if some commands were executed.
 */
int 
apply_autocmds (
    event_T event,
    char_u *fname,         /* NULL or empty means use actual file name */
    char_u *fname_io,      /* fname to use for <afile> on cmdline */
    int force,                  /* when TRUE, ignore autocmd_busy */
    buf_T *buf           /* buffer for <abuf> */
)
{
  return apply_autocmds_group(event, fname, fname_io, force,
      AUGROUP_ALL, buf, NULL);
}

/*
 * Like apply_autocmds(), but with extra "eap" argument.  This takes care of
 * setting v:filearg.
 */
static int apply_autocmds_exarg(event_T event, char_u *fname, char_u *fname_io, int force, buf_T *buf, exarg_T *eap)
{
  return apply_autocmds_group(event, fname, fname_io, force,
      AUGROUP_ALL, buf, eap);
}

/*
 * Like apply_autocmds(), but handles the caller's retval.  If the script
 * processing is being aborted or if retval is FAIL when inside a try
 * conditional, no autocommands are executed.  If otherwise the autocommands
 * cause the script to be aborted, retval is set to FAIL.
 */
int 
apply_autocmds_retval (
    event_T event,
    char_u *fname,         /* NULL or empty means use actual file name */
    char_u *fname_io,      /* fname to use for <afile> on cmdline */
    int force,                  /* when TRUE, ignore autocmd_busy */
    buf_T *buf,           /* buffer for <abuf> */
    int *retval        /* pointer to caller's retval */
)
{
  int did_cmd;

  if (should_abort(*retval))
    return FALSE;

  did_cmd = apply_autocmds_group(event, fname, fname_io, force,
      AUGROUP_ALL, buf, NULL);
  if (did_cmd
      && aborting()
      )
    *retval = FAIL;
  return did_cmd;
}

/*
 * Return TRUE when there is a CursorHold autocommand defined.
 */
int has_cursorhold(void)         {
  return first_autopat[(int)(get_real_state() == NORMAL_BUSY
                             ? EVENT_CURSORHOLD : EVENT_CURSORHOLDI)] != NULL;
}

/*
 * Return TRUE if the CursorHold event can be triggered.
 */
int trigger_cursorhold(void)         {
  int state;

  if (!did_cursorhold
      && has_cursorhold()
      && !Recording
      && typebuf.tb_len == 0
      && !ins_compl_active()
      ) {
    state = get_real_state();
    if (state == NORMAL_BUSY || (state & INSERT) != 0)
      return TRUE;
  }
  return FALSE;
}

/*
 * Return TRUE when there is a CursorMoved autocommand defined.
 */
int has_cursormoved(void)         {
  return first_autopat[(int)EVENT_CURSORMOVED] != NULL;
}

/*
 * Return TRUE when there is a CursorMovedI autocommand defined.
 */
int has_cursormovedI(void)         {
  return first_autopat[(int)EVENT_CURSORMOVEDI] != NULL;
}

/*
 * Return TRUE when there is a TextChanged autocommand defined.
 */
int has_textchanged(void)         {
  return first_autopat[(int)EVENT_TEXTCHANGED] != NULL;
}

/*
 * Return TRUE when there is a TextChangedI autocommand defined.
 */
int has_textchangedI(void)         {
  return first_autopat[(int)EVENT_TEXTCHANGEDI] != NULL;
}

/*
 * Return TRUE when there is an InsertCharPre autocommand defined.
 */
int has_insertcharpre(void)         {
  return first_autopat[(int)EVENT_INSERTCHARPRE] != NULL;
}

static int 
apply_autocmds_group (
    event_T event,
    char_u *fname,         /* NULL or empty means use actual file name */
    char_u *fname_io,      /* fname to use for <afile> on cmdline, NULL means
                               use fname */
    int force,                  /* when TRUE, ignore autocmd_busy */
    int group,                  /* group ID, or AUGROUP_ALL */
    buf_T *buf,           /* buffer for <abuf> */
    exarg_T *eap           /* command arguments */
)
{
  char_u      *sfname = NULL;   /* short file name */
  char_u      *tail;
  int save_changed;
  buf_T       *old_curbuf;
  int retval = FALSE;
  char_u      *save_sourcing_name;
  linenr_T save_sourcing_lnum;
  char_u      *save_autocmd_fname;
  int save_autocmd_fname_full;
  int save_autocmd_bufnr;
  char_u      *save_autocmd_match;
  int save_autocmd_busy;
  int save_autocmd_nested;
  static int nesting = 0;
  AutoPatCmd patcmd;
  AutoPat     *ap;
  scid_T save_current_SID;
  void        *save_funccalp;
  char_u      *save_cmdarg;
  long save_cmdbang;
  static int filechangeshell_busy = FALSE;
  proftime_T wait_time;

  /*
   * Quickly return if there are no autocommands for this event or
   * autocommands are blocked.
   */
  if (first_autopat[(int)event] == NULL || autocmd_blocked > 0)
    goto BYPASS_AU;

  /*
   * When autocommands are busy, new autocommands are only executed when
   * explicitly enabled with the "nested" flag.
   */
  if (autocmd_busy && !(force || autocmd_nested))
    goto BYPASS_AU;

  /*
   * Quickly return when immediately aborting on error, or when an interrupt
   * occurred or an exception was thrown but not caught.
   */
  if (aborting())
    goto BYPASS_AU;

  /*
   * FileChangedShell never nests, because it can create an endless loop.
   */
  if (filechangeshell_busy && (event == EVENT_FILECHANGEDSHELL
                               || event == EVENT_FILECHANGEDSHELLPOST))
    goto BYPASS_AU;

  /*
   * Ignore events in 'eventignore'.
   */
  if (event_ignored(event))
    goto BYPASS_AU;

  /*
   * Allow nesting of autocommands, but restrict the depth, because it's
   * possible to create an endless loop.
   */
  if (nesting == 10) {
    EMSG(_("E218: autocommand nesting too deep"));
    goto BYPASS_AU;
  }

  /*
   * Check if these autocommands are disabled.  Used when doing ":all" or
   * ":ball".
   */
  if (       (autocmd_no_enter
              && (event == EVENT_WINENTER || event == EVENT_BUFENTER))
             || (autocmd_no_leave
                 && (event == EVENT_WINLEAVE || event == EVENT_BUFLEAVE)))
    goto BYPASS_AU;

  /*
   * Save the autocmd_* variables and info about the current buffer.
   */
  save_autocmd_fname = autocmd_fname;
  save_autocmd_fname_full = autocmd_fname_full;
  save_autocmd_bufnr = autocmd_bufnr;
  save_autocmd_match = autocmd_match;
  save_autocmd_busy = autocmd_busy;
  save_autocmd_nested = autocmd_nested;
  save_changed = curbuf->b_changed;
  old_curbuf = curbuf;

  /*
   * Set the file name to be used for <afile>.
   * Make a copy to avoid that changing a buffer name or directory makes it
   * invalid.
   */
  if (fname_io == NULL) {
    if (event == EVENT_COLORSCHEME)
      autocmd_fname = NULL;
    else if (fname != NULL && *fname != NUL)
      autocmd_fname = fname;
    else if (buf != NULL)
      autocmd_fname = buf->b_ffname;
    else
      autocmd_fname = NULL;
  } else
    autocmd_fname = fname_io;
  if (autocmd_fname != NULL)
    autocmd_fname = vim_strsave(autocmd_fname);
  autocmd_fname_full = FALSE;   /* call FullName_save() later */

  /*
   * Set the buffer number to be used for <abuf>.
   */
  if (buf == NULL)
    autocmd_bufnr = 0;
  else
    autocmd_bufnr = buf->b_fnum;

  /*
   * When the file name is NULL or empty, use the file name of buffer "buf".
   * Always use the full path of the file name to match with, in case
   * "allow_dirs" is set.
   */
  if (fname == NULL || *fname == NUL) {
    if (buf == NULL)
      fname = NULL;
    else {
      if (event == EVENT_SYNTAX)
        fname = buf->b_p_syn;
      else if (event == EVENT_FILETYPE)
        fname = buf->b_p_ft;
      else {
        if (buf->b_sfname != NULL)
          sfname = vim_strsave(buf->b_sfname);
        fname = buf->b_ffname;
      }
    }
    if (fname == NULL)
      fname = (char_u *)"";
    fname = vim_strsave(fname);         /* make a copy, so we can change it */
  } else   {
    sfname = vim_strsave(fname);
    /* Don't try expanding FileType, Syntax, FuncUndefined, WindowID,
     * ColorScheme or QuickFixCmd* */
    if (event == EVENT_FILETYPE
        || event == EVENT_SYNTAX
        || event == EVENT_FUNCUNDEFINED
        || event == EVENT_REMOTEREPLY
        || event == EVENT_SPELLFILEMISSING
        || event == EVENT_QUICKFIXCMDPRE
        || event == EVENT_COLORSCHEME
        || event == EVENT_QUICKFIXCMDPOST)
      fname = vim_strsave(fname);
    else
      fname = FullName_save(fname, FALSE);
  }
  if (fname == NULL) {      /* out of memory */
    vim_free(sfname);
    retval = FALSE;
    goto BYPASS_AU;
  }

#ifdef BACKSLASH_IN_FILENAME
  /*
   * Replace all backslashes with forward slashes.  This makes the
   * autocommand patterns portable between Unix and MS-DOS.
   */
  if (sfname != NULL)
    forward_slash(sfname);
  forward_slash(fname);
#endif


  /*
   * Set the name to be used for <amatch>.
   */
  autocmd_match = fname;


  /* Don't redraw while doing auto commands. */
  ++RedrawingDisabled;
  save_sourcing_name = sourcing_name;
  sourcing_name = NULL;         /* don't free this one */
  save_sourcing_lnum = sourcing_lnum;
  sourcing_lnum = 0;            /* no line number here */

  save_current_SID = current_SID;

  if (do_profiling == PROF_YES)
    prof_child_enter(&wait_time);     /* doesn't count for the caller itself */

  /* Don't use local function variables, if called from a function */
  save_funccalp = save_funccal();

  /*
   * When starting to execute autocommands, save the search patterns.
   */
  if (!autocmd_busy) {
    save_search_patterns();
    saveRedobuff();
    did_filetype = keep_filetype;
  }

  /*
   * Note that we are applying autocmds.  Some commands need to know.
   */
  autocmd_busy = TRUE;
  filechangeshell_busy = (event == EVENT_FILECHANGEDSHELL);
  ++nesting;            /* see matching decrement below */

  /* Remember that FileType was triggered.  Used for did_filetype(). */
  if (event == EVENT_FILETYPE)
    did_filetype = TRUE;

  tail = gettail(fname);

  /* Find first autocommand that matches */
  patcmd.curpat = first_autopat[(int)event];
  patcmd.nextcmd = NULL;
  patcmd.group = group;
  patcmd.fname = fname;
  patcmd.sfname = sfname;
  patcmd.tail = tail;
  patcmd.event = event;
  patcmd.arg_bufnr = autocmd_bufnr;
  patcmd.next = NULL;
  auto_next_pat(&patcmd, FALSE);

  /* found one, start executing the autocommands */
  if (patcmd.curpat != NULL) {
    /* add to active_apc_list */
    patcmd.next = active_apc_list;
    active_apc_list = &patcmd;

    /* set v:cmdarg (only when there is a matching pattern) */
    save_cmdbang = get_vim_var_nr(VV_CMDBANG);
    if (eap != NULL) {
      save_cmdarg = set_cmdarg(eap, NULL);
      set_vim_var_nr(VV_CMDBANG, (long)eap->forceit);
    } else
      save_cmdarg = NULL;       /* avoid gcc warning */
    retval = TRUE;
    /* mark the last pattern, to avoid an endless loop when more patterns
     * are added when executing autocommands */
    for (ap = patcmd.curpat; ap->next != NULL; ap = ap->next)
      ap->last = FALSE;
    ap->last = TRUE;
    check_lnums(TRUE);          /* make sure cursor and topline are valid */
    do_cmdline(NULL, getnextac, (void *)&patcmd,
        DOCMD_NOWAIT|DOCMD_VERBOSE|DOCMD_REPEAT);
    if (eap != NULL) {
      (void)set_cmdarg(NULL, save_cmdarg);
      set_vim_var_nr(VV_CMDBANG, save_cmdbang);
    }
    /* delete from active_apc_list */
    if (active_apc_list == &patcmd)         /* just in case */
      active_apc_list = patcmd.next;
  }

  --RedrawingDisabled;
  autocmd_busy = save_autocmd_busy;
  filechangeshell_busy = FALSE;
  autocmd_nested = save_autocmd_nested;
  vim_free(sourcing_name);
  sourcing_name = save_sourcing_name;
  sourcing_lnum = save_sourcing_lnum;
  vim_free(autocmd_fname);
  autocmd_fname = save_autocmd_fname;
  autocmd_fname_full = save_autocmd_fname_full;
  autocmd_bufnr = save_autocmd_bufnr;
  autocmd_match = save_autocmd_match;
  current_SID = save_current_SID;
  restore_funccal(save_funccalp);
  if (do_profiling == PROF_YES)
    prof_child_exit(&wait_time);
  vim_free(fname);
  vim_free(sfname);
  --nesting;            /* see matching increment above */

  /*
   * When stopping to execute autocommands, restore the search patterns and
   * the redo buffer.
   */
  if (!autocmd_busy) {
    restore_search_patterns();
    restoreRedobuff();
    did_filetype = FALSE;
  }

  /*
   * Some events don't set or reset the Changed flag.
   * Check if still in the same buffer!
   */
  if (curbuf == old_curbuf
      && (event == EVENT_BUFREADPOST
          || event == EVENT_BUFWRITEPOST
          || event == EVENT_FILEAPPENDPOST
          || event == EVENT_VIMLEAVE
          || event == EVENT_VIMLEAVEPRE)) {
    if (curbuf->b_changed != save_changed)
      need_maketitle = TRUE;
    curbuf->b_changed = save_changed;
  }

  au_cleanup();         /* may really delete removed patterns/commands now */

BYPASS_AU:
  /* When wiping out a buffer make sure all its buffer-local autocommands
   * are deleted. */
  if (event == EVENT_BUFWIPEOUT && buf != NULL)
    aubuflocal_remove(buf);

  return retval;
}

static char_u   *old_termresponse = NULL;

/*
 * Block triggering autocommands until unblock_autocmd() is called.
 * Can be used recursively, so long as it's symmetric.
 */
void block_autocmds(void)          {
  /* Remember the value of v:termresponse. */
  if (autocmd_blocked == 0)
    old_termresponse = get_vim_var_str(VV_TERMRESPONSE);
  ++autocmd_blocked;
}

void unblock_autocmds(void)          {
  --autocmd_blocked;

  /* When v:termresponse was set while autocommands were blocked, trigger
   * the autocommands now.  Esp. useful when executing a shell command
   * during startup (vimdiff). */
  if (autocmd_blocked == 0
      && get_vim_var_str(VV_TERMRESPONSE) != old_termresponse)
    apply_autocmds(EVENT_TERMRESPONSE, NULL, NULL, FALSE, curbuf);
}

int is_autocmd_blocked(void)         {
  return autocmd_blocked != 0;
}

/*
 * Find next autocommand pattern that matches.
 */
static void 
auto_next_pat (
    AutoPatCmd *apc,
    int stop_at_last                   /* stop when 'last' flag is set */
)
{
  AutoPat     *ap;
  AutoCmd     *cp;
  char_u      *name;
  char        *s;

  vim_free(sourcing_name);
  sourcing_name = NULL;

  for (ap = apc->curpat; ap != NULL && !got_int; ap = ap->next) {
    apc->curpat = NULL;

    /* Only use a pattern when it has not been removed, has commands and
     * the group matches. For buffer-local autocommands only check the
     * buffer number. */
    if (ap->pat != NULL && ap->cmds != NULL
        && (apc->group == AUGROUP_ALL || apc->group == ap->group)) {
      /* execution-condition */
      if (ap->buflocal_nr == 0
          ? (match_file_pat(NULL, ap->reg_prog, apc->fname,
                 apc->sfname, apc->tail, ap->allow_dirs))
          : ap->buflocal_nr == apc->arg_bufnr) {
        name = event_nr2name(apc->event);
        s = _("%s Auto commands for \"%s\"");
        sourcing_name = alloc((unsigned)(STRLEN(s)
                                         + STRLEN(name) + ap->patlen + 1));
        if (sourcing_name != NULL) {
          sprintf((char *)sourcing_name, s,
              (char *)name, (char *)ap->pat);
          if (p_verbose >= 8) {
            verbose_enter();
            smsg((char_u *)_("Executing %s"), sourcing_name);
            verbose_leave();
          }
        }

        apc->curpat = ap;
        apc->nextcmd = ap->cmds;
        /* mark last command */
        for (cp = ap->cmds; cp->next != NULL; cp = cp->next)
          cp->last = FALSE;
        cp->last = TRUE;
      }
      line_breakcheck();
      if (apc->curpat != NULL)              /* found a match */
        break;
    }
    if (stop_at_last && ap->last)
      break;
  }
}

/*
 * Get next autocommand command.
 * Called by do_cmdline() to get the next line for ":if".
 * Returns allocated string, or NULL for end of autocommands.
 */
char_u *getnextac(int c, void *cookie, int indent)
{
  AutoPatCmd      *acp = (AutoPatCmd *)cookie;
  char_u          *retval;
  AutoCmd         *ac;

  /* Can be called again after returning the last line. */
  if (acp->curpat == NULL)
    return NULL;

  /* repeat until we find an autocommand to execute */
  for (;; ) {
    /* skip removed commands */
    while (acp->nextcmd != NULL && acp->nextcmd->cmd == NULL)
      if (acp->nextcmd->last)
        acp->nextcmd = NULL;
      else
        acp->nextcmd = acp->nextcmd->next;

    if (acp->nextcmd != NULL)
      break;

    /* at end of commands, find next pattern that matches */
    if (acp->curpat->last)
      acp->curpat = NULL;
    else
      acp->curpat = acp->curpat->next;
    if (acp->curpat != NULL)
      auto_next_pat(acp, TRUE);
    if (acp->curpat == NULL)
      return NULL;
  }

  ac = acp->nextcmd;

  if (p_verbose >= 9) {
    verbose_enter_scroll();
    smsg((char_u *)_("autocommand %s"), ac->cmd);
    msg_puts((char_u *)"\n");       /* don't overwrite this either */
    verbose_leave_scroll();
  }
  retval = vim_strsave(ac->cmd);
  autocmd_nested = ac->nested;
  current_SID = ac->scriptID;
  if (ac->last)
    acp->nextcmd = NULL;
  else
    acp->nextcmd = ac->next;
  return retval;
}

/*
 * Return TRUE if there is a matching autocommand for "fname".
 * To account for buffer-local autocommands, function needs to know
 * in which buffer the file will be opened.
 */
int has_autocmd(event_T event, char_u *sfname, buf_T *buf)
{
  AutoPat     *ap;
  char_u      *fname;
  char_u      *tail = gettail(sfname);
  int retval = FALSE;

  fname = FullName_save(sfname, FALSE);
  if (fname == NULL)
    return FALSE;

#ifdef BACKSLASH_IN_FILENAME
  /*
   * Replace all backslashes with forward slashes.  This makes the
   * autocommand patterns portable between Unix and MS-DOS.
   */
  sfname = vim_strsave(sfname);
  if (sfname != NULL)
    forward_slash(sfname);
  forward_slash(fname);
#endif

  for (ap = first_autopat[(int)event]; ap != NULL; ap = ap->next)
    if (ap->pat != NULL && ap->cmds != NULL
        && (ap->buflocal_nr == 0
            ? match_file_pat(NULL, ap->reg_prog,
                fname, sfname, tail, ap->allow_dirs)
            : buf != NULL && ap->buflocal_nr == buf->b_fnum
            )) {
      retval = TRUE;
      break;
    }

  vim_free(fname);
#ifdef BACKSLASH_IN_FILENAME
  vim_free(sfname);
#endif

  return retval;
}

/*
 * Function given to ExpandGeneric() to obtain the list of autocommand group
 * names.
 */
char_u *get_augroup_name(expand_T *xp, int idx)
{
  if (idx == augroups.ga_len)           /* add "END" add the end */
    return (char_u *)"END";
  if (idx >= augroups.ga_len)           /* end of list */
    return NULL;
  if (AUGROUP_NAME(idx) == NULL)        /* skip deleted entries */
    return (char_u *)"";
  return AUGROUP_NAME(idx);             /* return a name */
}

static int include_groups = FALSE;

char_u *
set_context_in_autocmd (
    expand_T *xp,
    char_u *arg,
    int doautocmd                  /* TRUE for :doauto*, FALSE for :autocmd */
)
{
  char_u      *p;
  int group;

  /* check for a group name, skip it if present */
  include_groups = FALSE;
  p = arg;
  group = au_get_grouparg(&arg);
  if (group == AUGROUP_ERROR)
    return NULL;
  /* If there only is a group name that's what we expand. */
  if (*arg == NUL && group != AUGROUP_ALL && !vim_iswhite(arg[-1])) {
    arg = p;
    group = AUGROUP_ALL;
  }

  /* skip over event name */
  for (p = arg; *p != NUL && !vim_iswhite(*p); ++p)
    if (*p == ',')
      arg = p + 1;
  if (*p == NUL) {
    if (group == AUGROUP_ALL)
      include_groups = TRUE;
    xp->xp_context = EXPAND_EVENTS;         /* expand event name */
    xp->xp_pattern = arg;
    return NULL;
  }

  /* skip over pattern */
  arg = skipwhite(p);
  while (*arg && (!vim_iswhite(*arg) || arg[-1] == '\\'))
    arg++;
  if (*arg)
    return arg;                             /* expand (next) command */

  if (doautocmd)
    xp->xp_context = EXPAND_FILES;          /* expand file names */
  else
    xp->xp_context = EXPAND_NOTHING;        /* pattern is not expanded */
  return NULL;
}

/*
 * Function given to ExpandGeneric() to obtain the list of event names.
 */
char_u *get_event_name(expand_T *xp, int idx)
{
  if (idx < augroups.ga_len) {          /* First list group names, if wanted */
    if (!include_groups || AUGROUP_NAME(idx) == NULL)
      return (char_u *)"";              /* skip deleted entries */
    return AUGROUP_NAME(idx);           /* return a name */
  }
  return (char_u *)event_names[idx - augroups.ga_len].name;
}


/*
 * Return TRUE if autocmd is supported.
 */
int autocmd_supported(char_u *name)
{
  char_u *p;

  return event_name2nr(name, &p) != NUM_EVENTS;
}

/*
 * Return TRUE if an autocommand is defined for a group, event and
 * pattern:  The group can be omitted to accept any group. "event" and "pattern"
 * can be NULL to accept any event and pattern. "pattern" can be NULL to accept
 * any pattern. Buffer-local patterns <buffer> or <buffer=N> are accepted.
 * Used for:
 *	exists("#Group") or
 *	exists("#Group#Event") or
 *	exists("#Group#Event#pat") or
 *	exists("#Event") or
 *	exists("#Event#pat")
 */
int au_exists(char_u *arg)
{
  char_u      *arg_save;
  char_u      *pattern = NULL;
  char_u      *event_name;
  char_u      *p;
  event_T event;
  AutoPat     *ap;
  buf_T       *buflocal_buf = NULL;
  int group;
  int retval = FALSE;

  /* Make a copy so that we can change the '#' chars to a NUL. */
  arg_save = vim_strsave(arg);
  if (arg_save == NULL)
    return FALSE;
  p = vim_strchr(arg_save, '#');
  if (p != NULL)
    *p++ = NUL;

  /* First, look for an autocmd group name */
  group = au_find_group(arg_save);
  if (group == AUGROUP_ERROR) {
    /* Didn't match a group name, assume the first argument is an event. */
    group = AUGROUP_ALL;
    event_name = arg_save;
  } else   {
    if (p == NULL) {
      /* "Group": group name is present and it's recognized */
      retval = TRUE;
      goto theend;
    }

    /* Must be "Group#Event" or "Group#Event#pat". */
    event_name = p;
    p = vim_strchr(event_name, '#');
    if (p != NULL)
      *p++ = NUL;           /* "Group#Event#pat" */
  }

  pattern = p;              /* "pattern" is NULL when there is no pattern */

  /* find the index (enum) for the event name */
  event = event_name2nr(event_name, &p);

  /* return FALSE if the event name is not recognized */
  if (event == NUM_EVENTS)
    goto theend;

  /* Find the first autocommand for this event.
   * If there isn't any, return FALSE;
   * If there is one and no pattern given, return TRUE; */
  ap = first_autopat[(int)event];
  if (ap == NULL)
    goto theend;

  /* if pattern is "<buffer>", special handling is needed which uses curbuf */
  /* for pattern "<buffer=N>, fnamecmp() will work fine */
  if (pattern != NULL && STRICMP(pattern, "<buffer>") == 0)
    buflocal_buf = curbuf;

  /* Check if there is an autocommand with the given pattern. */
  for (; ap != NULL; ap = ap->next)
    /* only use a pattern when it has not been removed and has commands. */
    /* For buffer-local autocommands, fnamecmp() works fine. */
    if (ap->pat != NULL && ap->cmds != NULL
        && (group == AUGROUP_ALL || ap->group == group)
        && (pattern == NULL
            || (buflocal_buf == NULL
                ? fnamecmp(ap->pat, pattern) == 0
                : ap->buflocal_nr == buflocal_buf->b_fnum))) {
      retval = TRUE;
      break;
    }

theend:
  vim_free(arg_save);
  return retval;
}



/*
 * Try matching a filename with a "pattern" ("prog" is NULL), or use the
 * precompiled regprog "prog" ("pattern" is NULL).  That avoids calling
 * vim_regcomp() often.
 * Used for autocommands and 'wildignore'.
 * Returns TRUE if there is a match, FALSE otherwise.
 */
int 
match_file_pat (
    char_u *pattern,                   /* pattern to match with */
    regprog_T *prog,                      /* pre-compiled regprog or NULL */
    char_u *fname,                     /* full path of file name */
    char_u *sfname,                    /* short file name or NULL */
    char_u *tail,                      /* tail of path */
    int allow_dirs                         /* allow matching with dir */
)
{
  regmatch_T regmatch;
  int result = FALSE;
#ifdef FEAT_OSFILETYPE
  int no_pattern = FALSE;           /* TRUE if check is filetype only */
  char_u      *type_start;
  char_u c;
  int match = FALSE;
#endif

  regmatch.rm_ic = p_fic;   /* ignore case if 'fileignorecase' is set */
#ifdef FEAT_OSFILETYPE
  if (*pattern == '<') {
    /* There is a filetype condition specified with this pattern.
     * Check the filetype matches first. If not, don't bother with the
     * pattern (set regprog to NULL).
     * Always use magic for the regexp.
     */

    for (type_start = pattern + 1; (c = *pattern); pattern++) {
      if ((c == ';' || c == '>') && match == FALSE) {
        *pattern = NUL;             /* Terminate the string */
        /* TODO: match with 'filetype' of buffer that "fname" comes
         * from. */
        match = mch_check_filetype(fname, type_start);
        *pattern = c;               /* Restore the terminator */
        type_start = pattern + 1;
      }
      if (c == '>')
        break;
    }

    /* (c should never be NUL, but check anyway) */
    if (match == FALSE || c == NUL)
      regmatch.regprog = NULL;          /* Doesn't match - don't check pat. */
    else if (*pattern == NUL) {
      regmatch.regprog = NULL;          /* Vim will try to free regprog later */
      no_pattern = TRUE;        /* Always matches - don't check pat. */
    } else
      regmatch.regprog = vim_regcomp(pattern + 1, RE_MAGIC);
  } else
#endif
  {
    if (prog != NULL)
      regmatch.regprog = prog;
    else
      regmatch.regprog = vim_regcomp(pattern, RE_MAGIC);
  }

  /*
   * Try for a match with the pattern with:
   * 1. the full file name, when the pattern has a '/'.
   * 2. the short file name, when the pattern has a '/'.
   * 3. the tail of the file name, when the pattern has no '/'.
   */
  if (
#ifdef FEAT_OSFILETYPE
    /* If the check is for a filetype only and we don't care
     * about the path then skip all the regexp stuff.
     */
    no_pattern ||
#endif
    (regmatch.regprog != NULL
     && ((allow_dirs
          && (vim_regexec(&regmatch, fname, (colnr_T)0)
              || (sfname != NULL
                  && vim_regexec(&regmatch, sfname, (colnr_T)0))))
         || (!allow_dirs && vim_regexec(&regmatch, tail, (colnr_T)0)))))
    result = TRUE;

  if (prog == NULL)
    vim_regfree(regmatch.regprog);
  return result;
}

/*
 * Return TRUE if a file matches with a pattern in "list".
 * "list" is a comma-separated list of patterns, like 'wildignore'.
 * "sfname" is the short file name or NULL, "ffname" the long file name.
 */
int match_file_list(char_u *list, char_u *sfname, char_u *ffname)
{
  char_u buf[100];
  char_u      *tail;
  char_u      *regpat;
  char allow_dirs;
  int match;
  char_u      *p;

  tail = gettail(sfname);

  /* try all patterns in 'wildignore' */
  p = list;
  while (*p) {
    copy_option_part(&p, buf, 100, ",");
    regpat = file_pat_to_reg_pat(buf, NULL, &allow_dirs, FALSE);
    if (regpat == NULL)
      break;
    match = match_file_pat(regpat, NULL, ffname, sfname,
        tail, (int)allow_dirs);
    vim_free(regpat);
    if (match)
      return TRUE;
  }
  return FALSE;
}

/*
 * Convert the given pattern "pat" which has shell style wildcards in it, into
 * a regular expression, and return the result in allocated memory.  If there
 * is a directory path separator to be matched, then TRUE is put in
 * allow_dirs, otherwise FALSE is put there -- webb.
 * Handle backslashes before special characters, like "\*" and "\ ".
 *
 * If FEAT_OSFILETYPE defined then pass initial <type> through unchanged. Eg:
 * '<html>myfile' becomes '<html>^myfile$' -- leonard.
 *
 * Returns NULL when out of memory.
 */
char_u *
file_pat_to_reg_pat (
    char_u *pat,
    char_u *pat_end,           /* first char after pattern or NULL */
    char *allow_dirs,        /* Result passed back out in here */
    int no_bslash             /* Don't use a backward slash as pathsep */
)
{
  int size;
  char_u      *endp;
  char_u      *reg_pat;
  char_u      *p;
  int i;
  int nested = 0;
  int add_dollar = TRUE;
#ifdef FEAT_OSFILETYPE
  int check_length = 0;
#endif

  if (allow_dirs != NULL)
    *allow_dirs = FALSE;
  if (pat_end == NULL)
    pat_end = pat + STRLEN(pat);

#ifdef FEAT_OSFILETYPE
  /* Find out how much of the string is the filetype check */
  if (*pat == '<') {
    /* Count chars until the next '>' */
    for (p = pat + 1; p < pat_end && *p != '>'; p++)
      ;
    if (p < pat_end) {
      /* Pattern is of the form <.*>.*  */
      check_length = p - pat + 1;
      if (p + 1 >= pat_end) {
        /* The 'pattern' is a filetype check ONLY */
        reg_pat = (char_u *)alloc(check_length + 1);
        if (reg_pat != NULL) {
          mch_memmove(reg_pat, pat, (size_t)check_length);
          reg_pat[check_length] = NUL;
        }
        return reg_pat;
      }
    }
    /* else: there was no closing '>' - assume it was a normal pattern */

  }
  pat += check_length;
  size = 2 + check_length;
#else
  size = 2;             /* '^' at start, '$' at end */
#endif

  for (p = pat; p < pat_end; p++) {
    switch (*p) {
    case '*':
    case '.':
    case ',':
    case '{':
    case '}':
    case '~':
      size += 2;                /* extra backslash */
      break;
#ifdef BACKSLASH_IN_FILENAME
    case '\\':
    case '/':
      size += 4;                /* could become "[\/]" */
      break;
#endif
    default:
      size++;
      if (enc_dbcs != 0 && (*mb_ptr2len)(p) > 1) {
        ++p;
        ++size;
      }
      break;
    }
  }
  reg_pat = alloc(size + 1);
  if (reg_pat == NULL)
    return NULL;

#ifdef FEAT_OSFILETYPE
  /* Copy the type check in to the start. */
  if (check_length)
    mch_memmove(reg_pat, pat - check_length, (size_t)check_length);
  i = check_length;
#else
  i = 0;
#endif

  if (pat[0] == '*')
    while (pat[0] == '*' && pat < pat_end - 1)
      pat++;
  else
    reg_pat[i++] = '^';
  endp = pat_end - 1;
  if (*endp == '*') {
    while (endp - pat > 0 && *endp == '*')
      endp--;
    add_dollar = FALSE;
  }
  for (p = pat; *p && nested >= 0 && p <= endp; p++) {
    switch (*p) {
    case '*':
      reg_pat[i++] = '.';
      reg_pat[i++] = '*';
      while (p[1] == '*')               /* "**" matches like "*" */
        ++p;
      break;
    case '.':
    case '~':
      reg_pat[i++] = '\\';
      reg_pat[i++] = *p;
      break;
    case '?':
      reg_pat[i++] = '.';
      break;
    case '\\':
      if (p[1] == NUL)
        break;
#ifdef BACKSLASH_IN_FILENAME
      if (!no_bslash) {
        /* translate:
         * "\x" to "\\x"  e.g., "dir\file"
         * "\*" to "\\.*" e.g., "dir\*.c"
         * "\?" to "\\."  e.g., "dir\??.c"
         * "\+" to "\+"   e.g., "fileX\+.c"
         */
        if ((vim_isfilec(p[1]) || p[1] == '*' || p[1] == '?')
            && p[1] != '+') {
          reg_pat[i++] = '[';
          reg_pat[i++] = '\\';
          reg_pat[i++] = '/';
          reg_pat[i++] = ']';
          if (allow_dirs != NULL)
            *allow_dirs = TRUE;
          break;
        }
      }
#endif
      /* Undo escaping from ExpandEscape():
       * foo\?bar -> foo?bar
       * foo\%bar -> foo%bar
       * foo\,bar -> foo,bar
       * foo\ bar -> foo bar
       * Don't unescape \, * and others that are also special in a
       * regexp.
       * An escaped { must be unescaped since we use magic not
       * verymagic.  Use "\\\{n,m\}"" to get "\{n,m}".
       */
      if (*++p == '?'
#ifdef BACKSLASH_IN_FILENAME
          && no_bslash
#endif
          )
        reg_pat[i++] = '?';
      else if (*p == ',' || *p == '%' || *p == '#'
               || *p == ' ' || *p == '{' || *p == '}')
        reg_pat[i++] = *p;
      else if (*p == '\\' && p[1] == '\\' && p[2] == '{') {
        reg_pat[i++] = '\\';
        reg_pat[i++] = '{';
        p += 2;
      } else   {
        if (allow_dirs != NULL && vim_ispathsep(*p)
#ifdef BACKSLASH_IN_FILENAME
            && (!no_bslash || *p != '\\')
#endif
            )
          *allow_dirs = TRUE;
        reg_pat[i++] = '\\';
        reg_pat[i++] = *p;
      }
      break;
#ifdef BACKSLASH_IN_FILENAME
    case '/':
      reg_pat[i++] = '[';
      reg_pat[i++] = '\\';
      reg_pat[i++] = '/';
      reg_pat[i++] = ']';
      if (allow_dirs != NULL)
        *allow_dirs = TRUE;
      break;
#endif
    case '{':
      reg_pat[i++] = '\\';
      reg_pat[i++] = '(';
      nested++;
      break;
    case '}':
      reg_pat[i++] = '\\';
      reg_pat[i++] = ')';
      --nested;
      break;
    case ',':
      if (nested) {
        reg_pat[i++] = '\\';
        reg_pat[i++] = '|';
      } else
        reg_pat[i++] = ',';
      break;
    default:
      if (enc_dbcs != 0 && (*mb_ptr2len)(p) > 1)
        reg_pat[i++] = *p++;
      else if (allow_dirs != NULL && vim_ispathsep(*p))
        *allow_dirs = TRUE;
      reg_pat[i++] = *p;
      break;
    }
  }
  if (add_dollar)
    reg_pat[i++] = '$';
  reg_pat[i] = NUL;
  if (nested != 0) {
    if (nested < 0)
      EMSG(_("E219: Missing {."));
    else
      EMSG(_("E220: Missing }."));
    vim_free(reg_pat);
    reg_pat = NULL;
  }
  return reg_pat;
}

#if defined(EINTR) || defined(PROTO)
/*
 * Version of read() that retries when interrupted by EINTR (possibly
 * by a SIGWINCH).
 */
long read_eintr(fd, buf, bufsize)
int fd;
void    *buf;
size_t bufsize;
{
  long ret;

  for (;; ) {
    ret = vim_read(fd, buf, bufsize);
    if (ret >= 0 || errno != EINTR)
      break;
  }
  return ret;
}

/*
 * Version of write() that retries when interrupted by EINTR (possibly
 * by a SIGWINCH).
 */
long write_eintr(fd, buf, bufsize)
int fd;
void    *buf;
size_t bufsize;
{
  long ret = 0;
  long wlen;

  /* Repeat the write() so long it didn't fail, other than being interrupted
   * by a signal. */
  while (ret < (long)bufsize) {
    wlen = vim_write(fd, (char *)buf + ret, bufsize - ret);
    if (wlen < 0) {
      if (errno != EINTR)
        break;
    } else
      ret += wlen;
  }
  return ret;
}
#endif
